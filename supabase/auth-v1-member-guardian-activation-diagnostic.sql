select
  to_regclass('public.user_access_decisions') as decisions_table,
  to_regprocedure('public.auth_get_account_activation()') as activation_read,
  to_regprocedure('public.auth_complete_account_activation(jsonb)') as activation_complete,
  has_function_privilege('authenticated', 'public.auth_get_account_activation()', 'EXECUTE') as authenticated_read,
  has_function_privilege('anon', 'public.auth_get_account_activation()', 'EXECUTE') as anon_read,
  has_function_privilege('authenticated', 'public.auth_complete_account_activation(jsonb)', 'EXECUTE') as authenticated_complete,
  has_function_privilege('anon', 'public.auth_complete_account_activation(jsonb)', 'EXECUTE') as anon_complete;
