select
  to_regclass('public.person_profile_change_history') as history_table,
  to_regprocedure('public.auth_update_my_profile(jsonb)') as update_function,
  has_function_privilege(
    'authenticated', 'public.auth_update_my_profile(jsonb)', 'EXECUTE'
  ) as authenticated_execute,
  has_function_privilege(
    'anon', 'public.auth_update_my_profile(jsonb)', 'EXECUTE'
  ) as anon_execute;
