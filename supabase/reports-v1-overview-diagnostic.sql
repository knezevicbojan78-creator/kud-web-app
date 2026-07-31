select
  to_regprocedure('public.auth_get_society_reports_overview(uuid)') as report_function,
  has_function_privilege('authenticated','public.auth_get_society_reports_overview(uuid)','EXECUTE') as authenticated_execute,
  has_function_privilege('anon','public.auth_get_society_reports_overview(uuid)','EXECUTE') as anon_execute;

select permission_key,label,is_sensitive,is_active
from public.permission_catalog
where permission_key in (
  'reports.membership.view','reports.finance.view','reports.attendance.view',
  'reports.events.view','reports.wardrobe.view','reports.data_completion.view',
  'reports.email_log.view','reports.activity.view'
)
order by permission_key;
