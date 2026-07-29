select
  to_regprocedure(
    'public.auth_lookup_person_for_member(uuid,text,text,text)'
  ) as person_lookup_function,
  has_function_privilege(
    'authenticated',
    'public.auth_lookup_person_for_member(uuid,text,text,text)',
    'EXECUTE'
  ) as authenticated_execute,
  has_function_privilege(
    'anon',
    'public.auth_lookup_person_for_member(uuid,text,text,text)',
    'EXECUTE'
  ) as anon_execute;
