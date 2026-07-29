-- READ-ONLY provera dozvola Prisustva
select
  to_regprocedure('public.auth_get_attendance_workspace(uuid,uuid)')
    as attendance_workspace_function,
  to_regprocedure('public.auth_resolve_attendance_role(uuid,uuid,text)')
    as attendance_permission_function,
  has_function_privilege(
    'authenticated',
    'public.auth_get_attendance_workspace(uuid,uuid)',
    'EXECUTE'
  ) as authenticated_workspace_execute,
  has_function_privilege(
    'anon',
    'public.auth_get_attendance_workspace(uuid,uuid)',
    'EXECUTE'
  ) as anon_workspace_execute,
  has_function_privilege(
    'authenticated',
    'public.auth_resolve_attendance_role(uuid,uuid,text)',
    'EXECUTE'
  ) as direct_permission_execute_error,
  to_regprocedure('public.auth_get_attendance_history(uuid,uuid,text,date,date,uuid)')
    as attendance_history_function,
  has_function_privilege(
    'authenticated',
    'public.auth_get_attendance_history(uuid,uuid,text,date,date,uuid)',
    'EXECUTE'
  ) as authenticated_history_execute,
  has_function_privilege(
    'anon',
    'public.auth_get_attendance_history(uuid,uuid,text,date,date,uuid)',
    'EXECUTE'
  ) as anon_history_execute;
