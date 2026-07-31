select jsonb_build_object(
  'function_exists',
    to_regprocedure(
      'public.auth_complete_accepted_member_data(uuid,uuid,date,jsonb)'
    ) is not null,
  'authenticated_execute',
    has_function_privilege(
      'authenticated',
      'public.auth_complete_accepted_member_data(uuid,uuid,date,jsonb)',
      'EXECUTE'
    ),
  'anon_execute',
    has_function_privilege(
      'anon',
      'public.auth_complete_accepted_member_data(uuid,uuid,date,jsonb)',
      'EXECUTE'
    )
);
