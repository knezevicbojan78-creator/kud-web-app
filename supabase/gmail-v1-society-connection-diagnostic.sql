select jsonb_build_object(
  'connection_table', to_regclass('public.society_gmail_connections') is not null,
  'history_table', to_regclass('public.society_gmail_connection_history') is not null,
  'status_function', to_regprocedure('public.auth_get_society_gmail_connection(uuid)') is not null,
  'save_function', to_regprocedure('public.auth_save_society_gmail_connection(uuid,text,text,text,text,timestamp with time zone,text)') is not null,
  'disconnect_function', to_regprocedure('public.auth_disconnect_society_gmail(uuid,text)') is not null,
  'authenticated_status_execute', has_function_privilege(
    'authenticated', 'public.auth_get_society_gmail_connection(uuid)', 'EXECUTE'
  ),
  'anon_status_execute', has_function_privilege(
    'anon', 'public.auth_get_society_gmail_connection(uuid)', 'EXECUTE'
  )
) as diagnostic;
