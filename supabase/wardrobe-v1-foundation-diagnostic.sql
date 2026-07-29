select
  to_regclass('public.wardrobe_items') as wardrobe_items,
  to_regclass('public.wardrobe_assignments') as wardrobe_assignments,
  to_regclass('public.wardrobe_audit_log') as wardrobe_audit,
  exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='people' and column_name='shoe_size'
  ) as people_has_shoe_size,
  to_regprocedure('public.auth_get_wardrobe_workspace(uuid)') as workspace_function,
  has_function_privilege(
    'authenticated','public.auth_get_wardrobe_workspace(uuid)','EXECUTE'
  ) as authenticated_can_read,
  has_function_privilege(
    'anon','public.auth_get_wardrobe_workspace(uuid)','EXECUTE'
  ) as anon_can_read;

select t.table_name, c.relrowsecurity as row_security
from information_schema.tables t
join pg_class c on c.relname=t.table_name
join pg_namespace n on n.oid=c.relnamespace and n.nspname=t.table_schema
where t.table_schema='public' and t.table_name like 'wardrobe_%'
order by table_name;
