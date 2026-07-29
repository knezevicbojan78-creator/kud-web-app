-- READ-ONLY provera bezbednog pregleda dogadjaja
select
  to_regprocedure('public.auth_get_events_workspace(uuid,uuid)')
    as events_workspace_function,
  to_regprocedure('public.permissions_can_access_event(uuid,uuid,uuid,uuid,text)')
    as event_permission_function,
  has_function_privilege(
    'authenticated',
    'public.auth_get_events_workspace(uuid,uuid)',
    'EXECUTE'
  ) as authenticated_workspace_execute,
  has_function_privilege(
    'anon',
    'public.auth_get_events_workspace(uuid,uuid)',
    'EXECUTE'
  ) as anon_workspace_execute,
  has_function_privilege(
    'authenticated',
    'public.permissions_can_access_event(uuid,uuid,uuid,uuid,text)',
    'EXECUTE'
  ) as direct_permission_execute_error,
  to_regprocedure('public.auth_manage_event(text,jsonb)')
    as event_management_function,
  has_function_privilege(
    'authenticated',
    'public.auth_manage_event(text,jsonb)',
    'EXECUTE'
  ) as authenticated_management_execute,
  has_function_privilege(
    'anon',
    'public.auth_manage_event(text,jsonb)',
    'EXECUTE'
  ) as anon_management_execute,
  to_regprocedure('public.auth_search_event_people(uuid,text)')
    as event_people_search_function,
  to_regprocedure('public.auth_list_event_section_candidates(uuid)')
    as event_candidate_function,
  has_function_privilege(
    'authenticated',
    'public.auth_search_event_people(uuid,text)',
    'EXECUTE'
  ) as authenticated_search_execute,
  has_function_privilege(
    'anon',
    'public.auth_search_event_people(uuid,text)',
    'EXECUTE'
  ) as anon_search_execute,
  has_function_privilege(
    'authenticated',
    'public.finance_set_event_participant_status(uuid,text,text,uuid)',
    'EXECUTE'
  ) as authenticated_status_execute,
  has_function_privilege(
    'anon',
    'public.finance_set_event_participant_status(uuid,text,text,uuid)',
    'EXECUTE'
  ) as anon_status_execute,
  has_function_privilege(
    'authenticated',
    'public.finance_cancel_event(uuid,text,uuid)',
    'EXECUTE'
  ) as authenticated_cancel_execute,
  has_function_privilege(
    'anon',
    'public.finance_cancel_event(uuid,text,uuid)',
    'EXECUTE'
  ) as anon_cancel_execute,
  has_function_privilege(
    'authenticated',
    'public.finance_cancel_event_section(uuid,text,uuid)',
    'EXECUTE'
  ) as authenticated_section_cancel_execute,
  has_function_privilege(
    'anon',
    'public.finance_cancel_event_section(uuid,text,uuid)',
    'EXECUTE'
  ) as anon_section_cancel_execute;
