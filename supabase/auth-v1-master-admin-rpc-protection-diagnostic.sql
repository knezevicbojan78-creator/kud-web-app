-- Pokrenuti nakon auth-v1-master-admin-rpc-protection.sql.
-- Ocekivano: protected_rpc_count=8, anon_execute_count=0,
-- authenticated_execute_count=8, exposed_impl_count=0.

with protected(signature) as (
  values
    ('master_admin_get_society_summaries()'),
    ('master_admin_get_dashboard()'),
    ('master_admin_get_society_detail(uuid)'),
    ('master_admin_set_society_status(uuid,text,text,uuid,text)'),
    ('master_admin_get_license_management(uuid)'),
    ('master_admin_grant_license(uuid,uuid,text,date,date,text,text,text,text,boolean,uuid,text)'),
    ('master_admin_get_license_prices()'),
    ('master_admin_update_license_price(uuid,numeric,numeric,text,uuid,text)')
),
implementations(signature) as (
  values
    ('master_admin_get_society_summaries_impl()'),
    ('master_admin_get_dashboard_impl()'),
    ('master_admin_get_society_detail_impl(uuid)'),
    ('master_admin_set_society_status_impl(uuid,text,text,uuid,text)'),
    ('master_admin_get_license_management_impl(uuid)'),
    ('master_admin_grant_license_impl(uuid,uuid,text,date,date,text,text,text,text,boolean,uuid,text)'),
    ('master_admin_get_license_prices_impl()'),
    ('master_admin_update_license_price_impl(uuid,numeric,numeric,text,uuid,text)')
)
select
  count(*) filter (
    where to_regprocedure('public.' || p.signature) is not null
  ) as protected_rpc_count,
  count(*) filter (
    where has_function_privilege('anon', 'public.' || p.signature, 'EXECUTE')
  ) as anon_execute_count,
  count(*) filter (
    where has_function_privilege('authenticated', 'public.' || p.signature, 'EXECUTE')
  ) as authenticated_execute_count,
  (
    select count(*)
    from implementations i
    where has_function_privilege('anon', 'public.' || i.signature, 'EXECUTE')
       or has_function_privilege('authenticated', 'public.' || i.signature, 'EXECUTE')
  ) as exposed_impl_count
from protected p;
