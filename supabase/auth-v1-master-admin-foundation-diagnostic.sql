-- FOLKLORAS — READ-ONLY provera Master admin Auth V1 osnove.

select
  to_regclass('public.platform_admins') as platform_admins_table,
  to_regprocedure('public.auth_get_bootstrap_status()') as bootstrap_status_function,
  to_regprocedure('public.auth_is_master_admin()') as is_master_function,
  to_regprocedure('public.auth_get_session_context()') as session_context_function,
  to_regprocedure('public.auth_bootstrap_master_admin()') as bootstrap_master_function,
  to_regprocedure('public.auth_before_user_created(jsonb)') as before_user_created_hook;

select
  count(*) as platform_admin_count,
  count(*) filter (
    where lower(btrim(email)) = 'knezevic.bojan78@gmail.com'
  ) as allowed_email_count,
  count(*) filter (where status = 'ACTIVE') as active_count,
  count(*) filter (where mfa_required) as mfa_required_count
from public.platform_admins;

select
  has_function_privilege(
    'anon',
    'public.auth_get_bootstrap_status()',
    'EXECUTE'
  ) as anon_can_read_bootstrap_status,
  not has_function_privilege(
    'anon',
    'public.auth_bootstrap_master_admin()',
    'EXECUTE'
  ) as anon_cannot_bootstrap_master,
  has_function_privilege(
    'authenticated',
    'public.auth_bootstrap_master_admin()',
    'EXECUTE'
  ) as authenticated_can_bootstrap_master,
  has_function_privilege(
    'supabase_auth_admin',
    'public.auth_before_user_created(jsonb)',
    'EXECUTE'
  ) as auth_admin_can_run_signup_hook;

select
  (select count(*) from public.platform_admins) as platform_admin_count,
  (select count(*) from auth.users) as auth_user_count,
  (
    select count(*)
    from public.platform_admins pa
    left join auth.users u on u.id = pa.user_id
    where u.id is null
       or lower(btrim(u.email)) <> lower(btrim(pa.email))
       or u.email_confirmed_at is null
  ) as invalid_platform_admin_count,
  (
    select count(*)
    from public.platform_admins pa
    where exists (
      select 1 from public.people p where p.user_id = pa.user_id
    )
    or exists (
      select 1
      from public.society_members sm
      where sm.user_id = pa.user_id
    )
  ) as master_society_identity_conflict_count;
