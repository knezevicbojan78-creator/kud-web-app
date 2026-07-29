-- FOLKLORAS DEV/V1
-- Trajni godisnji obrazac meseci naplate i objedinjena podesavanja clanarine.
-- Pokrenuti pre ponovne primene finance-v1-membership-workflows.sql.

begin;

create table if not exists public.society_fee_month_rule_history (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  month_number smallint not null check (month_number between 1 and 12),
  is_chargeable boolean not null,
  effective_from date not null,
  reason text not null check (length(trim(reason)) > 0),
  changed_by_user_id uuid null,
  changed_by_society_member_id uuid null references public.society_members(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint society_fee_month_rule_effective_first_day_check
    check (effective_from = date_trunc('month', effective_from)::date),
  unique (society_id, month_number, effective_from)
);

create index if not exists society_fee_month_rule_lookup_idx
  on public.society_fee_month_rule_history(society_id, month_number, effective_from desc);

insert into public.society_fee_month_rule_history (
  society_id, month_number, is_chargeable, effective_from, reason
)
select s.id, gs.month_no, true,
  coalesce(s.finance_start_month, date_trunc('month', current_date)::date),
  'Početno pravilo: naplata svih 12 meseci'
from public.societies s
cross join generate_series(1, 12) as gs(month_no)
where not exists (
  select 1 from public.society_fee_month_rule_history h
  where h.society_id = s.id and h.month_number = gs.month_no
);

create or replace function public.finance_membership_month_is_chargeable(
  p_society_id uuid,
  p_month date
) returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce((
    select h.is_chargeable
    from society_fee_month_rule_history h
    where h.society_id = p_society_id
      and h.month_number = extract(month from p_month)::smallint
      and h.effective_from <= date_trunc('month', p_month)::date
    order by h.effective_from desc, h.created_at desc
    limit 1
  ), true);
$$;

create or replace function public.finance_get_membership_settings(
  p_society_id uuid,
  p_actor_member_id uuid
) returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_society societies;
  v_effective date := (date_trunc('month', current_date) + interval '1 month')::date;
begin
  if not finance_can_manage_society(p_society_id, p_actor_member_id) then
    raise exception 'Nemate pravo pregleda podešavanja članarine.';
  end if;
  select * into v_society from societies where id = p_society_id;
  if not found then raise exception 'Društvo nije pronađeno.'; end if;

  return jsonb_build_object(
    'society_id', v_society.id,
    'currency', v_society.base_currency,
    'standard_amount', v_society.default_membership_fee_amount,
    'finance_start_month', v_society.finance_start_month,
    'effective_from', v_effective,
    'chargeable_months', (
      select jsonb_agg(m order by m)
      from generate_series(1, 12) m
      where finance_membership_month_is_chargeable(v_society.id, make_date(
        extract(year from v_effective)::integer
          + case when m < extract(month from v_effective)::integer then 1 else 0 end,
        m, 1
      ))
    )
  );
end;
$$;

create or replace function public.finance_update_membership_settings(
  p_society_id uuid,
  p_standard_amount numeric,
  p_chargeable_months integer[],
  p_reason text,
  p_actor_member_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_effective date := (date_trunc('month', current_date) + interval '1 month')::date;
  v_role text;
  v_month integer;
  v_society societies;
  v_actor_person_id uuid;
  v_standard_changed boolean;
  v_calendar_changed boolean;
begin
  select * into v_society from societies where id = p_society_id;
  if not found then raise exception 'Drustvo nije pronadjeno.'; end if;
  select member.person_id into v_actor_person_id
  from society_members member
  join people person on person.id = member.person_id
  where member.id = p_actor_member_id
    and member.society_id = p_society_id
    and member.status = 'ACTIVE'
    and coalesce(member.user_id, person.user_id) = auth.uid();
  if v_actor_person_id is null then raise exception 'Korisnik nije ovlascen.'; end if;
  v_standard_changed :=
    v_society.default_membership_fee_amount is distinct from p_standard_amount;
  select exists (
    select 1 from generate_series(1, 12) as month_value(month_no)
    where finance_membership_month_is_chargeable(
      p_society_id,
      make_date(
        extract(year from v_effective)::integer
          + case when month_no < extract(month from v_effective)::integer then 1 else 0 end,
        month_no, 1
      )
    ) is distinct from (month_no = any(p_chargeable_months))
  ) into v_calendar_changed;
  if v_standard_changed and not public.permissions_has_scope(
    p_society_id, p_actor_member_id, v_actor_person_id,
    'finance.settings_standard_fee', array['SOCIETY']::text[]
  ) then raise exception 'Nemate pravo promene standardne clanarine.'; end if;
  if v_calendar_changed and not public.permissions_has_scope(
    p_society_id, p_actor_member_id, v_actor_person_id,
    'finance.settings_calendar', array['SOCIETY']::text[]
  ) then raise exception 'Nemate pravo promene kalendara naplate.'; end if;
  v_role := 'Ovlašćeni korisnik';
  if p_standard_amount is null or p_standard_amount <= 0 then
    raise exception 'Standardna članarina mora biti veća od nule.';
  end if;
  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'Razlog promene je obavezan.';
  end if;
  if p_chargeable_months is null
    or exists (select 1 from unnest(p_chargeable_months) m where m not between 1 and 12) then
    raise exception 'Meseci naplate nisu ispravni.';
  end if;

  if v_standard_changed then
    perform finance_schedule_standard_fee(
      p_society_id, p_standard_amount, p_reason, auth.uid(), p_actor_member_id
    );
  end if;

  if v_calendar_changed then
  for v_month in 1..12 loop
    insert into society_fee_month_rule_history (
      society_id, month_number, is_chargeable, effective_from, reason,
      changed_by_user_id, changed_by_society_member_id
    ) values (
      p_society_id, v_month, v_month = any(p_chargeable_months),
      v_effective, trim(p_reason), auth.uid(), p_actor_member_id
    )
    on conflict (society_id, month_number, effective_from) do update set
      is_chargeable = excluded.is_chargeable,
      reason = excluded.reason,
      changed_by_user_id = excluded.changed_by_user_id,
      changed_by_society_member_id = excluded.changed_by_society_member_id,
      created_at = now();
  end loop;
  end if;

  insert into financial_audit_log (
    society_id, entity_type, entity_id, action, new_values, reason,
    actor_user_id, actor_society_member_id, actor_role
  ) values (
    p_society_id, 'SOCIETY_MEMBERSHIP_SETTINGS', p_society_id,
    'MEMBERSHIP_SETTINGS_SCHEDULED',
    jsonb_build_object(
      'standard_amount', p_standard_amount,
      'chargeable_months', p_chargeable_months,
      'effective_from', v_effective
    ),
    trim(p_reason), auth.uid(), p_actor_member_id, v_role
  );

  return finance_get_membership_settings(p_society_id, p_actor_member_id);
end;
$$;

revoke all on function public.finance_membership_month_is_chargeable(uuid, date)
  from public, anon, authenticated;
revoke all on function public.finance_get_membership_settings(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.finance_update_membership_settings(uuid, numeric, integer[], text, uuid)
  from public, anon, authenticated;
grant execute on function public.finance_get_membership_settings(uuid, uuid)
  to authenticated;
grant execute on function public.finance_update_membership_settings(uuid, numeric, integer[], text, uuid)
  to authenticated;

select pg_notify('pgrst', 'reload schema');
commit;
