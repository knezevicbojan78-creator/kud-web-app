-- READ-ONLY provera zastite akcija u sekcijama
select
  to_regprocedure('public.auth_manage_section(text,jsonb)')
    as section_management_function,
  to_regprocedure('public.auth_search_society_members(uuid,text,uuid,boolean,text)')
    as section_member_search_function,
  has_function_privilege(
    'authenticated', 'public.auth_manage_section(text,jsonb)', 'EXECUTE'
  ) as authenticated_manage_execute,
  has_function_privilege(
    'anon', 'public.auth_manage_section(text,jsonb)', 'EXECUTE'
  ) as anon_manage_execute,
  has_function_privilege(
    'authenticated',
    'public.auth_search_society_members(uuid,text,uuid,boolean,text)',
    'EXECUTE'
  ) as authenticated_search_execute,
  has_function_privilege(
    'anon',
    'public.auth_search_society_members(uuid,text,uuid,boolean,text)',
    'EXECUTE'
  ) as anon_search_execute,
  has_function_privilege(
    'authenticated',
    'public.permissions_can_access_section(uuid,uuid,uuid,uuid,text)',
    'EXECUTE'
  ) as direct_helper_execute_error;
