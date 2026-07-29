-- FOLKLORAS DEV/V1
-- FINANSIJE: bezbedna pretraga i read-only finansijski profil.
-- Pokrenuti nakon finance-v1-event-refund-workflows.sql.

begin;

create or replace function public.finance_can_manage_society(
  p_society_id uuid,
  p_actor_member_id uuid
) returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from society_member_function_assignments smfa
    join society_member_functions smf on smf.id = smfa.function_id
    join society_members sm on sm.id = smfa.society_member_id
    where smfa.society_id = p_society_id
      and smfa.society_member_id = p_actor_member_id
      and sm.society_id = p_society_id
      and sm.user_id = auth.uid()
      and sm.status = 'ACTIVE'
      and smf.name in ('Predsednik', 'Blagajnik')
  );
$$;

create or replace function public.finance_search_entities(
  p_society_id uuid,
  p_query text,
  p_actor_member_id uuid,
  p_limit integer default 12
) returns table (
  entity_type text,
  entity_id uuid,
  display_name text,
  subtitle text,
  related_count integer,
  open_obligation_count integer,
  overdue_obligation_count integer
)
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_query text := lower(trim(coalesce(p_query, '')));
begin
  if not finance_can_manage_society(p_society_id, p_actor_member_id) then
    raise exception 'Nemate pravo pretrage finansijskih podataka.';
  end if;
  if length(v_query) < 2 then return; end if;

  return query
  with eligible_people as (
    select distinct p.id, p.first_name, p.last_name, p.email, p.phone
    from people p
    where exists (
      select 1 from society_members sm
      where sm.person_id = p.id and sm.society_id = p_society_id
    ) or exists (
      select 1 from event_participants ep
      join society_events se on se.id = ep.event_id
      where ep.person_id = p.id and se.society_id = p_society_id
    )
  ),
  direct_matches as (
    select
      'PERSON'::text as entity_type,
      ep.id as entity_id,
      trim(ep.first_name || ' ' || ep.last_name) as display_name,
      concat_ws(' · ',
        nullif((select string_agg(distinct s.name, ', ' order by s.name)
          from society_members sm
          join member_sections ms on ms.society_member_id = sm.id and ms.status = 'ACTIVE'
          join sections s on s.id = ms.section_id
          where sm.person_id = ep.id and sm.society_id = p_society_id), ''),
        nullif(ep.email, ''), nullif(ep.phone, '')
      ) as subtitle,
      1::integer as related_count
    from eligible_people ep
    where lower(concat_ws(' ', ep.first_name, ep.last_name, ep.email, ep.phone)) like '%' || v_query || '%'
  ),
  guardian_matches as (
    select
      'GUARDIAN'::text as entity_type,
      guardian.id as entity_id,
      trim(guardian.first_name || ' ' || guardian.last_name) as display_name,
      'Roditelj/staratelj · ' || count(distinct child.id)::text ||
        case when count(distinct child.id) = 1 then ' dete' else ' dece' end as subtitle,
      count(distinct child.id)::integer as related_count
    from people guardian
    join person_guardians pg on pg.guardian_person_id = guardian.id
    join eligible_people child on child.id = pg.child_person_id
    where lower(concat_ws(' ', guardian.first_name, guardian.last_name, guardian.email, guardian.phone))
      like '%' || v_query || '%'
    group by guardian.id, guardian.first_name, guardian.last_name
  ),
  matches as (
    select * from direct_matches
    union all
    select * from guardian_matches
  ),
  scope_people as (
    select m.entity_type, m.entity_id, ep.id as person_id
    from matches m
    join eligible_people ep on m.entity_type = 'PERSON' and ep.id = m.entity_id
    union all
    select m.entity_type, m.entity_id, pg.child_person_id
    from matches m
    join person_guardians pg on m.entity_type = 'GUARDIAN' and pg.guardian_person_id = m.entity_id
    join eligible_people ep on ep.id = pg.child_person_id
  ),
  obligation_counts as (
    select sp.entity_type, sp.entity_id,
      count(distinct fo.id) filter (where fo.status in ('OPEN', 'PARTIALLY_PAID'))::integer as open_count,
      count(distinct fo.id) filter (
        where fo.status in ('OPEN', 'PARTIALLY_PAID') and fo.due_date < current_date
      )::integer as overdue_count
    from scope_people sp
    left join financial_obligations fo on fo.person_id = sp.person_id
      and fo.society_id = p_society_id
    group by sp.entity_type, sp.entity_id
  )
  select m.entity_type, m.entity_id, m.display_name, nullif(m.subtitle, ''),
    m.related_count, coalesce(oc.open_count, 0), coalesce(oc.overdue_count, 0)
  from matches m
  left join obligation_counts oc
    on oc.entity_type = m.entity_type and oc.entity_id = m.entity_id
  order by coalesce(oc.overdue_count, 0) desc, m.display_name
  limit greatest(1, least(coalesce(p_limit, 12), 30));
end;
$$;

create or replace function public.finance_get_entity_profile(
  p_society_id uuid,
  p_entity_type text,
  p_entity_id uuid,
  p_actor_member_id uuid default null
) returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_type text := upper(trim(p_entity_type));
  v_auth_person_id uuid;
  v_authorized boolean := false;
  v_people_ids uuid[];
  v_result jsonb;
begin
  if v_type not in ('PERSON', 'GUARDIAN') then
    raise exception 'Nepoznat tip finansijskog profila.';
  end if;

  v_authorized := finance_can_manage_society(p_society_id, p_actor_member_id);
  if not v_authorized then
    if auth.uid() is null then
      raise exception 'Korisnik nije prijavljen.';
    end if;
    select id into v_auth_person_id from people where user_id = auth.uid() limit 1;
    v_authorized := v_auth_person_id = p_entity_id;
  end if;
  if not v_authorized then raise exception 'Nemate pravo pregleda ovog profila.'; end if;

  if v_type = 'PERSON' then
    if not exists (
      select 1 from society_members sm
      where sm.society_id = p_society_id and sm.person_id = p_entity_id
      union all
      select 1 from event_participants ep
      join society_events se on se.id = ep.event_id
      where se.society_id = p_society_id and ep.person_id = p_entity_id
    ) then raise exception 'Osoba ne pripada ovom drustvu ili dogadjaju.'; end if;
    v_people_ids := array[p_entity_id];
  else
    select coalesce(array_agg(distinct pg.child_person_id), array[]::uuid[])
    into v_people_ids
    from person_guardians pg
    where pg.guardian_person_id = p_entity_id
      and (
        exists (select 1 from society_members sm where sm.society_id = p_society_id and sm.person_id = pg.child_person_id)
        or exists (
          select 1 from event_participants ep
          join society_events se on se.id = ep.event_id
          where se.society_id = p_society_id and ep.person_id = pg.child_person_id
        )
      );
  end if;

  with scoped_people as (
    select p.id, p.first_name, p.last_name, p.email, p.phone,
      sm.id as society_member_id, sm.status as member_status,
      sm.membership_fee_mode, sm.membership_fee_amount
    from people p
    left join society_members sm on sm.person_id = p.id and sm.society_id = p_society_id
    where p.id = any(v_people_ids)
  ),
  obligations as (
    select fo.*,
      coalesce((select sum(foa.amount) from financial_obligation_allocations foa
        where foa.obligation_id = fo.id and foa.status = 'ACTIVE'), 0) as paid_amount
    from financial_obligations fo
    where fo.society_id = p_society_id and fo.person_id = any(v_people_ids)
  ),
  relevant_payments as (
    select distinct fp.*
    from financial_payments fp
    join financial_obligation_allocations foa on foa.payment_id = fp.id
    join financial_obligations fo on fo.id = foa.obligation_id
    where fp.society_id = p_society_id and fo.person_id = any(v_people_ids)
  )
  select jsonb_build_object(
    'entity', case when v_type = 'GUARDIAN' then
      (select jsonb_build_object('type', 'GUARDIAN', 'id', p.id,
        'name', trim(p.first_name || ' ' || p.last_name), 'email', p.email)
       from people p where p.id = p_entity_id)
      else
      (select jsonb_build_object('type', 'PERSON', 'id', p.id,
        'name', trim(p.first_name || ' ' || p.last_name), 'email', p.email)
       from people p where p.id = p_entity_id)
    end,
    'people', coalesce((select jsonb_agg(jsonb_build_object(
      'person_id', sp.id,
      'society_member_id', sp.society_member_id,
      'name', trim(sp.first_name || ' ' || sp.last_name),
      'email', sp.email,
      'phone', sp.phone,
      'member_status', sp.member_status,
      'membership_fee_mode', sp.membership_fee_mode,
      'membership_fee_amount', sp.membership_fee_amount
    ) order by sp.first_name, sp.last_name) from scoped_people sp), '[]'::jsonb),
    'open_obligations', coalesce((select jsonb_agg(jsonb_build_object(
      'id', o.id,
      'person_id', o.person_id,
      'type', o.obligation_type,
      'title', o.title,
      'original_amount', o.original_amount,
      'current_amount', o.current_amount,
      'paid_amount', o.paid_amount,
      'remaining_amount', greatest(o.current_amount - o.paid_amount, 0),
      'currency', o.currency,
      'due_date', o.due_date,
      'is_overdue', o.due_date < current_date,
      'status', o.status,
      'event_id', o.event_id
    ) order by o.due_date, o.created_at)
    from obligations o where o.status in ('OPEN', 'PARTIALLY_PAID')), '[]'::jsonb),
    'credits', coalesce((select jsonb_agg(jsonb_build_object(
      'person_id', c.person_id, 'currency', c.currency, 'amount', c.amount
    ) order by c.currency)
    from (
      select fce.person_id, fce.currency, sum(fce.amount) as amount
      from financial_credit_entries fce
      where fce.society_id = p_society_id and fce.person_id = any(v_people_ids)
      group by fce.person_id, fce.currency having sum(fce.amount) <> 0
    ) c), '[]'::jsonb),
    'payments', coalesce((select jsonb_agg(jsonb_build_object(
      'id', rp.id,
      'receipt_number', rp.receipt_number,
      'amount', rp.amount,
      'currency', rp.currency,
      'payment_method', rp.payment_method,
      'status', rp.status,
      'recorded_at', rp.recorded_at,
      'recorded_by_member_id', rp.recorded_by_society_member_id
    ) order by rp.recorded_at desc) from relevant_payments rp), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.finance_can_manage_society(uuid, uuid) from public;
revoke all on function public.finance_search_entities(uuid, text, uuid, integer) from public;
revoke all on function public.finance_get_entity_profile(uuid, text, uuid, uuid) from public;

grant execute on function public.finance_search_entities(uuid, text, uuid, integer) to authenticated;
grant execute on function public.finance_get_entity_profile(uuid, text, uuid, uuid) to authenticated;

select pg_notify('pgrst', 'reload schema');
commit;
