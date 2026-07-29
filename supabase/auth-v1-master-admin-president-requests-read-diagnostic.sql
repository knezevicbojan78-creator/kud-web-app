select
  to_regprocedure(
    'public.master_admin_get_president_requests(text,uuid)'
  ) as president_requests_function,
  has_function_privilege(
    'authenticated',
    'public.master_admin_get_president_requests(text,uuid)',
    'EXECUTE'
  ) as authenticated_execute,
  has_function_privilege(
    'anon',
    'public.master_admin_get_president_requests(text,uuid)',
    'EXECUTE'
  ) as anon_execute;
