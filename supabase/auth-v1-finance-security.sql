begin;

drop function if exists public.finance_get_test_actor_context(text);

create or replace function public.finance_assert_society_role(
  p_society_id uuid,
  p_actor_member_id uuid,
  p_allowed_roles text[]
) returns text
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_role text;
begin
  if auth.uid() is null then
    raise exception 'Korisnik nije prijavljen.';
  end if;

  select function_row.name
  into v_role
  from public.society_members member_row
  join public.people person_row on person_row.id = member_row.person_id
  join public.society_member_function_assignments assignment
    on assignment.society_member_id = member_row.id
  join public.society_member_functions function_row
    on function_row.id = assignment.function_id
  where member_row.id = p_actor_member_id
    and member_row.society_id = p_society_id
    and member_row.status = 'ACTIVE'
    and coalesce(member_row.user_id, person_row.user_id) = auth.uid()
    and function_row.society_id = p_society_id
    and function_row.is_active
    and function_row.name = any(p_allowed_roles)
  order by array_position(p_allowed_roles, function_row.name)
  limit 1;

  if v_role is null then
    raise exception 'Nemate odgovarajuce finansijsko ovlascenje.';
  end if;

  return v_role;
end;
$$;

create or replace function public.finance_can_manage_society(
  p_society_id uuid,
  p_actor_member_id uuid
) returns boolean
language sql
security definer
stable
set search_path = public, auth, pg_temp
as $$
  select exists (
    select 1
    from public.society_members member_row
    join public.people person_row on person_row.id = member_row.person_id
    join public.society_member_function_assignments assignment
      on assignment.society_member_id = member_row.id
    join public.society_member_functions function_row
      on function_row.id = assignment.function_id
    where member_row.id = p_actor_member_id
      and member_row.society_id = p_society_id
      and member_row.status = 'ACTIVE'
      and coalesce(member_row.user_id, person_row.user_id) = auth.uid()
      and function_row.society_id = p_society_id
      and function_row.is_active
      and function_row.name in ('Predsednik', 'Blagajnik')
  );
$$;

revoke all on function public.finance_assert_society_role(
  uuid, uuid, text[]
) from public, anon, authenticated;
revoke all on function public.finance_can_manage_society(
  uuid, uuid
) from public, anon, authenticated;

revoke all on function public.finance_get_membership_settings(
  uuid, uuid
) from public, anon;
revoke all on function public.finance_update_membership_settings(
  uuid, numeric, integer[], text, uuid
) from public, anon;
revoke all on function public.finance_list_member_fee_settings(
  uuid, text, boolean, uuid
) from public, anon;
revoke all on function public.finance_set_event_participant_status(
  uuid, text, text, uuid
) from public, anon;
revoke all on function public.finance_cancel_event_section(
  uuid, text, uuid
) from public, anon;

grant execute on function public.finance_get_membership_settings(
  uuid, uuid
) to authenticated;
grant execute on function public.finance_update_membership_settings(
  uuid, numeric, integer[], text, uuid
) to authenticated;
grant execute on function public.finance_list_member_fee_settings(
  uuid, text, boolean, uuid
) to authenticated;
grant execute on function public.finance_set_event_participant_status(
  uuid, text, text, uuid
) to authenticated;
grant execute on function public.finance_cancel_event_section(
  uuid, text, uuid
) to authenticated;

select pg_notify('pgrst', 'reload schema');
commit;

select
  to_regprocedure(
    'public.finance_get_test_actor_context(text)'
  ) is null as test_context_removed,
  has_function_privilege(
    'anon',
    'public.finance_get_membership_settings(uuid,uuid)',
    'EXECUTE'
  ) as anon_settings_execute,
  has_function_privilege(
    'authenticated',
    'public.finance_get_membership_settings(uuid,uuid)',
    'EXECUTE'
  ) as authenticated_settings_execute;
