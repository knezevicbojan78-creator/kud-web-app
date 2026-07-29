select
  to_regclass('public.user_society_preferences') as preferences_table,
  to_regprocedure('public.auth_select_society(uuid)') as selection_function,
  has_function_privilege(
    'authenticated', 'public.auth_select_society(uuid)', 'EXECUTE'
  ) as authenticated_execute,
  has_function_privilege(
    'anon', 'public.auth_select_society(uuid)', 'EXECUTE'
  ) as anon_execute,
  (
    select count(*) from public.user_society_preferences preference
    where not exists (
      select 1 from public.society_members member
      where member.user_id = preference.user_id
        and member.society_id = preference.society_id
        and member.status = 'ACTIVE'
    )
    and not exists (
      select 1 from public.people guardian
      join public.person_guardians link on link.guardian_person_id = guardian.id
      join public.society_members child_member on child_member.person_id = link.child_person_id
      where guardian.user_id = preference.user_id
        and child_member.society_id = preference.society_id
        and child_member.status = 'ACTIVE'
    )
  ) as invalid_preferences;
