-- Ocekivano: authenticated_execute=true, anon_execute=false.

select
  has_function_privilege(
    'authenticated',
    'public.auth_get_login_destination()',
    'EXECUTE'
  ) as authenticated_execute,
  has_function_privilege(
    'anon',
    'public.auth_get_login_destination()',
    'EXECUTE'
  ) as anon_execute;
