select
  to_regprocedure(
    'public.auth_search_guardians_for_member(uuid,text,integer)'
  ) is not null as function_exists,
  has_function_privilege(
    'authenticated',
    'public.auth_search_guardians_for_member(uuid,text,integer)',
    'EXECUTE'
  ) as authenticated_can_execute,
  not has_function_privilege(
    'anon',
    'public.auth_search_guardians_for_member(uuid,text,integer)',
    'EXECUTE'
  ) as anon_cannot_execute;
