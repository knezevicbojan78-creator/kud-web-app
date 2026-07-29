-- READ-ONLY provera nakon auth-v1-members-permissions-read.sql
select
  to_regprocedure('public.auth_get_members_page()') as members_page_function,
  has_function_privilege('authenticated', 'public.auth_get_members_page()', 'EXECUTE')
    as authenticated_execute,
  has_function_privilege('anon', 'public.auth_get_members_page()', 'EXECUTE')
    as anon_execute,
  to_regprocedure('public.auth_get_member_detail(uuid)') as member_detail_function,
  has_function_privilege('authenticated', 'public.auth_get_member_detail(uuid)', 'EXECUTE')
    as authenticated_detail_execute,
  has_function_privilege('anon', 'public.auth_get_member_detail(uuid)', 'EXECUTE')
    as anon_detail_execute;
