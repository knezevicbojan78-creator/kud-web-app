-- READ-ONLY provera nakon auth-v1-sections-permissions-read.sql
select
  to_regprocedure('public.permissions_can_access_section(uuid,uuid,uuid,uuid,text)')
    as target_section_permission_function,
  to_regprocedure('public.auth_get_sections_workspace(uuid)')
    as sections_workspace_function,
  has_function_privilege(
    'authenticated', 'public.auth_get_sections_workspace(uuid)', 'EXECUTE'
  ) as authenticated_execute,
  has_function_privilege(
    'anon', 'public.auth_get_sections_workspace(uuid)', 'EXECUTE'
  ) as anon_execute,
  has_function_privilege(
    'authenticated',
    'public.permissions_can_access_section(uuid,uuid,uuid,uuid,text)',
    'EXECUTE'
  ) as direct_helper_execute_error;
