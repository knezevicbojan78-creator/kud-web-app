select
  to_regprocedure('public.auth_get_guardian_sections_workspace(uuid)') as sections_workspace,
  to_regprocedure('public.auth_get_guardian_section_detail(uuid)') as section_detail,
  to_regprocedure('public.auth_get_guardian_attendance_workspace(uuid,uuid)') as attendance_workspace,
  to_regprocedure('public.auth_get_guardian_attendance_history(uuid,uuid,text,date,date,uuid)') as attendance_history,
  to_regprocedure('public.auth_get_guardian_finance_workspace(uuid)') as finance_workspace,
  to_regprocedure('public.auth_get_guardian_events_workspace(uuid,uuid)') as events_workspace,
  to_regprocedure('public.auth_get_guardian_profile(uuid)') as guardian_profile,
  to_regprocedure('public.auth_update_guardian_profile(uuid,jsonb)') as guardian_profile_update,
  has_function_privilege(
    'authenticated', 'public.auth_get_guardian_profile(uuid)', 'EXECUTE'
  ) as authenticated_execute,
  has_function_privilege(
    'anon', 'public.auth_get_guardian_profile(uuid)', 'EXECUTE'
  ) as anon_execute;
