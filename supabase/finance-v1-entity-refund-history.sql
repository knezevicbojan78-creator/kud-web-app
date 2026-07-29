-- FINANSIJE V1: bezbedan pregled istorije povracaja za finansijski profil.

begin;

create or replace function public.finance_list_entity_refunds(
  p_society_id uuid,
  p_entity_type text,
  p_entity_id uuid,
  p_actor_member_id uuid default null
) returns table (
  id uuid,
  person_id uuid,
  refund_number text,
  amount numeric,
  currency text,
  refund_method text,
  status text,
  reason text,
  recorded_at timestamptz,
  voided_at timestamptz,
  void_reason text
)
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_type text := upper(trim(p_entity_type));
  v_people_ids uuid[];
begin
  -- Postojeci profil obavlja istu proveru identiteta, drustva i prava pristupa.
  perform public.finance_get_entity_profile(
    p_society_id, v_type, p_entity_id, p_actor_member_id
  );

  if v_type = 'PERSON' then
    v_people_ids := array[p_entity_id];
  elsif v_type = 'GUARDIAN' then
    select coalesce(array_agg(distinct pg.child_person_id), array[]::uuid[])
    into v_people_ids
    from public.person_guardians pg
    where pg.guardian_person_id = p_entity_id
      and (
        exists (
          select 1 from public.society_members sm
          where sm.society_id = p_society_id
            and sm.person_id = pg.child_person_id
        )
        or exists (
          select 1
          from public.event_participants ep
          join public.society_events se on se.id = ep.event_id
          where se.society_id = p_society_id
            and ep.person_id = pg.child_person_id
        )
      );
  else
    raise exception 'Nepoznat tip finansijskog profila.';
  end if;

  return query
  select
    fr.id,
    fr.person_id,
    fr.refund_number,
    fr.amount,
    fr.currency,
    fr.refund_method,
    fr.status,
    fr.reason,
    fr.recorded_at,
    fr.voided_at,
    fr.void_reason
  from public.financial_refunds fr
  where fr.society_id = p_society_id
    and fr.person_id = any(v_people_ids)
  order by fr.recorded_at desc, fr.id desc;
end;
$$;

revoke all on function public.finance_list_entity_refunds(uuid, text, uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.finance_list_entity_refunds(uuid, text, uuid, uuid)
  to authenticated;

select pg_notify('pgrst', 'reload schema');

commit;
