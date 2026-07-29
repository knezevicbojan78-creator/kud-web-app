select
  to_regprocedure('public.auth_get_wardrobe_page(uuid)') as page_function,
  to_regprocedure('public.auth_wardrobe_actor(uuid,boolean)') as actor_function,
  (select count(*) from public.permission_catalog
    where permission_key in ('wardrobe.view','wardrobe.manage','wardrobe.view_audit')
      and is_active) as active_permissions,
  exists(
    select 1 from public.system_function_permission_templates t
    join public.permission_catalog pc on pc.id=t.permission_id
    where t.function_name='Garderober' and pc.permission_key='wardrobe.manage'
  ) as garderober_manage_template,
  has_function_privilege(
    'authenticated','public.auth_get_wardrobe_page(uuid)','EXECUTE'
  ) as authenticated_execute,
  has_function_privilege(
    'anon','public.auth_get_wardrobe_page(uuid)','EXECUTE'
  ) as anon_execute;
