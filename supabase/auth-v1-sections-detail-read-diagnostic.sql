select
  to_regprocedure('public.auth_get_section_detail(uuid)')
    as section_detail_function,
  has_function_privilege(
    'authenticated',
    'public.auth_get_section_detail(uuid)',
    'EXECUTE'
  ) as authenticated_execute,
  has_function_privilege(
    'anon',
    'public.auth_get_section_detail(uuid)',
    'EXECUTE'
  ) as anon_execute;
