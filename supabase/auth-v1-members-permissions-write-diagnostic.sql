-- READ-ONLY provera zastite unosa i izmene clanova
select
  to_regprocedure('public.permissions_can_access_member(uuid,uuid,uuid,uuid,text)')
    as target_permission_function,
  to_regprocedure('public.auth_create_society_member(uuid,jsonb,jsonb,uuid[],uuid[])')
    as create_member_function,
  to_regprocedure('public.auth_update_society_member(uuid,jsonb,jsonb,uuid[],uuid[])')
    as update_member_function,
  has_function_privilege(
    'authenticated',
    'public.auth_create_society_member(uuid,jsonb,jsonb,uuid[],uuid[])',
    'EXECUTE'
  ) as authenticated_create_execute,
  has_function_privilege(
    'anon',
    'public.auth_create_society_member(uuid,jsonb,jsonb,uuid[],uuid[])',
    'EXECUTE'
  ) as anon_create_execute,
  has_function_privilege(
    'authenticated',
    'public.auth_update_society_member(uuid,jsonb,jsonb,uuid[],uuid[])',
    'EXECUTE'
  ) as authenticated_update_execute,
  has_function_privilege(
    'anon',
    'public.auth_update_society_member(uuid,jsonb,jsonb,uuid[],uuid[])',
    'EXECUTE'
  ) as anon_update_execute,
  has_function_privilege(
    'authenticated',
    'public.permissions_can_access_member(uuid,uuid,uuid,uuid,text)',
    'EXECUTE'
  ) as direct_helper_execute_error;
