-- FOLKLORAS — AUTH V1 / FINANSIJE / DOZVOLE ZA PREGLED

begin;

create or replace function public.finance_can_manage_society(
  p_society_id uuid,
  p_actor_member_id uuid
) returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.society_members member
    join public.people person on person.id = member.person_id
    where member.id = p_actor_member_id
      and member.society_id = p_society_id
      and member.status = 'ACTIVE'
      and coalesce(member.user_id, person.user_id) = auth.uid()
      and public.permissions_has_scope(
        p_society_id, member.id, member.person_id,
        'finance.view', array['SOCIETY']::text[]
      )
  );
$$;

create or replace function public.auth_get_finance_workspace(
  p_society_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_actor_member_id uuid;
  v_actor_person_id uuid;
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'Prijava je obavezna.'; end if;

  select member.id, member.person_id
  into v_actor_member_id, v_actor_person_id
  from public.society_members member
  join public.people person on person.id = member.person_id
  where member.society_id = p_society_id
    and member.status = 'ACTIVE'
    and coalesce(member.user_id, person.user_id) = auth.uid()
  order by member.id
  limit 1;

  if v_actor_member_id is null then
    raise exception 'Korisnik nema aktivno clanstvo u izabranom drustvu.';
  end if;

  if not exists (
    select 1 from public.permissions_get_effective_rules(
      p_society_id, v_actor_member_id, v_actor_person_id
    ) rule where rule.permission_key = 'finance.view'
  ) then raise exception 'Nemate dozvolu za pregled finansija.'; end if;

  select jsonb_build_object(
    'society', to_jsonb(society),
    'actor_society_member_id', v_actor_member_id,
    'access', jsonb_build_object(
      'can_search_society', public.permissions_has_scope(
        p_society_id, v_actor_member_id, v_actor_person_id,
        'finance.view', array['SOCIETY']::text[]
      ),
      'can_record_payment', public.permissions_has_scope(
        p_society_id, v_actor_member_id, v_actor_person_id,
        'finance.record_payment', array['SOCIETY']::text[]
      ),
      'can_use_credit', public.permissions_has_scope(
        p_society_id, v_actor_member_id, v_actor_person_id,
        'finance.use_credit_for_fee', array['SOCIETY']::text[]
      ),
      'can_view_audit', public.permissions_has_scope(
        p_society_id, v_actor_member_id, v_actor_person_id,
        'finance.view_audit', array['SOCIETY']::text[]
      ),
      'can_record_refund', public.permissions_has_scope(
        p_society_id, v_actor_member_id, v_actor_person_id,
        'finance.record_refund', array['SOCIETY']::text[]
      ),
      'can_void_payment', public.permissions_has_scope(
        p_society_id, v_actor_member_id, v_actor_person_id,
        'finance.void_payment', array['SOCIETY']::text[]
      ),
      'can_void_refund', public.permissions_has_scope(
        p_society_id, v_actor_member_id, v_actor_person_id,
        'finance.void_refund', array['SOCIETY']::text[]
      )
    ),
    'initial_entity', jsonb_build_object(
      'entity_type', case when exists (
        select 1 from public.person_guardians guardian
        join public.society_members child_member
          on child_member.person_id = guardian.child_person_id
         and child_member.society_id = p_society_id
        where guardian.guardian_person_id = v_actor_person_id
      ) then 'GUARDIAN' else 'PERSON' end,
      'entity_id', v_actor_person_id,
      'display_name', concat_ws(' ', actor.first_name, actor.last_name),
      'subtitle', 'Moj finansijski pregled',
      'related_count', 1,
      'open_obligation_count', 0,
      'overdue_obligation_count', 0
    )
  )
  into v_result
  from public.societies society
  join public.people actor on actor.id = v_actor_person_id
  where society.id = p_society_id
    and society.status in ('ACTIVE', 'SUSPENDED');

  if v_result is null then raise exception 'Izabrano drustvo nije dostupno.'; end if;
  return v_result;
end;
$$;

revoke all on function public.finance_can_manage_society(uuid,uuid)
  from public, anon, authenticated;
revoke all on function public.auth_get_finance_workspace(uuid)
  from public, anon;
grant execute on function public.auth_get_finance_workspace(uuid)
  to authenticated;
revoke all on function public.finance_search_entities(uuid,text,uuid,integer)
  from public, anon, authenticated;
grant execute on function public.finance_search_entities(uuid,text,uuid,integer)
  to authenticated;
revoke all on function public.finance_get_entity_profile(uuid,text,uuid,uuid)
  from public, anon, authenticated;
grant execute on function public.finance_get_entity_profile(uuid,text,uuid,uuid)
  to authenticated;

commit;
