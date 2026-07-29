-- FOLKLORAŠ — AUTH V1 / ZAVRŠNA BEZBEDNOSNA PROVERA
-- Read-only: ne menja podatke, politike ni dozvole.

with allowed_anon_functions(function_name) as (
  values
    ('auth_get_bootstrap_status'),
    ('auth_bootstrap_master_admin'),
    ('auth_get_public_license_plans'),
    ('auth_submit_president_request')
),
anon_functions as (
  select distinct
    routine.routine_name,
    pg_get_function_identity_arguments(procedure.oid) as identity_arguments,
    routine.routine_name || '(' ||
      pg_get_function_identity_arguments(procedure.oid) || ')' as signature
  from information_schema.routine_privileges routine
  join pg_proc procedure on procedure.proname = routine.routine_name
  join pg_namespace namespace on namespace.oid = procedure.pronamespace
    and namespace.nspname = routine.routine_schema
  where routine.routine_schema = 'public'
    and routine.grantee in ('anon', 'PUBLIC')
    and routine.privilege_type = 'EXECUTE'
),
anon_table_access as (
  select distinct table_name, privilege_type
  from information_schema.role_table_grants
  where table_schema = 'public'
    and grantee = 'anon'
    and privilege_type in ('SELECT', 'INSERT', 'UPDATE', 'DELETE')
),
dev_policies as (
  select tablename, policyname
  from pg_policies
  where schemaname = 'public'
    and policyname ilike 'dev%'
)
select
  (select count(*) from dev_policies) as remaining_dev_policy_count,
  (select count(*) from anon_table_access) as anon_direct_table_privilege_count,
  (
    select count(*)
    from anon_functions function_row
    where not exists (
      select 1
      from allowed_anon_functions allowed
      where allowed.function_name = function_row.routine_name
    )
  ) as unexpected_anon_function_count,
  (
    select count(*)
    from anon_functions function_row
    where exists (
      select 1
      from allowed_anon_functions allowed
      where allowed.function_name = function_row.routine_name
    )
  ) as expected_public_function_count;

-- U aktivnoj V1 bazi očekuju se 3 anonimna javna toka:
-- bootstrap status, javni cenovnik i slanje predsedničkog zahteva.
-- Sam bootstrap Master admina zahteva već potvrđenu Auth sesiju i zato nije anon.

-- Ako je završna zaštita dobra, naredni upit ne vraća nijedan red.
with allowed_anon_functions(function_name) as (
  values
    ('auth_get_bootstrap_status'),
    ('auth_bootstrap_master_admin'),
    ('auth_get_public_license_plans'),
    ('auth_submit_president_request')
),
findings as (
  select
    'DEV_POLICY'::text as finding_type,
    tablename || ': ' || policyname as finding
  from pg_policies
  where schemaname = 'public'
    and policyname ilike 'dev%'

  union all

  select
    'ANON_TABLE_PRIVILEGE',
    table_name || ': ' || privilege_type
  from information_schema.role_table_grants
  where table_schema = 'public'
    and grantee = 'anon'
    and privilege_type in ('SELECT', 'INSERT', 'UPDATE', 'DELETE')

  union all

  select distinct
    'UNEXPECTED_ANON_FUNCTION',
    routine.routine_name || '(' ||
      pg_get_function_identity_arguments(procedure.oid) || ')'
  from information_schema.routine_privileges routine
  join pg_proc procedure on procedure.proname = routine.routine_name
  join pg_namespace namespace on namespace.oid = procedure.pronamespace
    and namespace.nspname = routine.routine_schema
  where routine.routine_schema = 'public'
    and routine.grantee in ('anon', 'PUBLIC')
    and routine.privilege_type = 'EXECUTE'
    and not exists (
      select 1
      from allowed_anon_functions allowed
      where allowed.function_name = routine.routine_name
    )
)
select finding_type, finding
from findings
order by finding_type, finding;
