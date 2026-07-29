-- Ocekivano nakon migracije:
-- direct_anon_insert=false, direct_authenticated_insert=false,
-- anon_rpc_execute=true, authenticated_rpc_execute=true,
-- public_plan_rpc_execute=true.

select
  has_table_privilege('anon', 'public."PresidentReg"', 'INSERT')
    as direct_anon_insert,
  has_table_privilege('authenticated', 'public."PresidentReg"', 'INSERT')
    as direct_authenticated_insert,
  has_function_privilege(
    'anon',
    'public.auth_submit_president_request(text,text,text,text,text,text,text,text,text,text,uuid,text)',
    'EXECUTE'
  ) as anon_rpc_execute,
  has_function_privilege(
    'authenticated',
    'public.auth_submit_president_request(text,text,text,text,text,text,text,text,text,text,uuid,text)',
    'EXECUTE'
  ) as authenticated_rpc_execute,
  has_function_privilege(
    'anon',
    'public.auth_get_public_license_plans()',
    'EXECUTE'
  ) as public_plan_rpc_execute;
