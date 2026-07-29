select
  to_regclass('public.section_accompanists') as accompanists_table,
  to_regprocedure('public.auth_manage_section_accompanist(text,jsonb)')
    as management_function,
  to_regprocedure('public.auth_search_accompanist_people(uuid,uuid,text)')
    as search_function,
  has_function_privilege(
    'authenticated',
    'public.auth_manage_section_accompanist(text,jsonb)',
    'EXECUTE'
  ) as authenticated_management_execute,
  has_function_privilege(
    'anon',
    'public.auth_manage_section_accompanist(text,jsonb)',
    'EXECUTE'
  ) as anon_management_execute,
  has_function_privilege(
    'authenticated',
    'public.auth_search_accompanist_people(uuid,uuid,text)',
    'EXECUTE'
  ) as authenticated_search_execute,
  has_function_privilege(
    'anon',
    'public.auth_search_accompanist_people(uuid,uuid,text)',
    'EXECUTE'
  ) as anon_search_execute,
  (
    select count(*)
    from public.permission_catalog
    where permission_key = 'sections.manage_accompanists'
      and is_active
  ) as permission_count,
  (
    select count(*)
    from public.society_function_permission_rules rule
    join public.society_member_functions function_row
      on function_row.id = rule.function_id
    join public.permission_catalog permission
      on permission.id = rule.permission_id
    where function_row.name = 'Predsednik'
      and permission.permission_key = 'sections.manage_accompanists'
      and rule.scope_key = 'SOCIETY'
      and rule.is_locked
  ) as president_rule_count,
  (
    select count(*)
    from public.attendance_records
    where person_id is null
  ) as invalid_attendance_person_count;
