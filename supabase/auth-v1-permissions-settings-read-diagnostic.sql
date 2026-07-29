-- READ-ONLY provera nakon auth-v1-permissions-settings-read.sql

select
  to_regprocedure('public.auth_permissions_get_settings(uuid)')
    as permissions_settings_function,
  has_function_privilege(
    'authenticated',
    'public.auth_permissions_get_settings(uuid)',
    'EXECUTE'
  ) as authenticated_execute,
  has_function_privilege(
    'anon',
    'public.auth_permissions_get_settings(uuid)',
    'EXECUTE'
  ) as anon_execute,
  to_regprocedure('public.auth_permissions_save_function_rules(uuid,jsonb,text)')
    as permissions_save_function,
  has_function_privilege(
    'authenticated',
    'public.auth_permissions_save_function_rules(uuid,jsonb,text)',
    'EXECUTE'
  ) as authenticated_save_execute,
  has_function_privilege(
    'anon',
    'public.auth_permissions_save_function_rules(uuid,jsonb,text)',
    'EXECUTE'
  ) as anon_save_execute,
  to_regprocedure('public.auth_permissions_list_function_members(uuid,text)')
    as member_search_function,
  to_regprocedure('public.auth_permissions_get_member_configuration(uuid)')
    as member_configuration_function,
  to_regprocedure('public.auth_permissions_save_member_overrides(uuid,jsonb,text)')
    as member_save_function,
  has_function_privilege(
    'authenticated',
    'public.auth_permissions_save_member_overrides(uuid,jsonb,text)',
    'EXECUTE'
  ) as authenticated_member_save_execute,
  has_function_privilege(
    'anon',
    'public.auth_permissions_save_member_overrides(uuid,jsonb,text)',
    'EXECUTE'
  ) as anon_member_save_execute;
