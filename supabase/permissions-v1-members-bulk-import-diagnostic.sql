select
  permission.permission_key,
  permission.label,
  permission.allowed_scopes,
  permission.is_president_only,
  permission.is_active
from public.permission_catalog permission
where permission.permission_key = 'members.bulk_import';

select
  template.function_name,
  template.scope_key,
  template.is_locked
from public.system_function_permission_templates template
join public.permission_catalog permission
  on permission.id = template.permission_id
where permission.permission_key = 'members.bulk_import'
  and template.function_name = 'Predsednik';

select
  to_regprocedure('public.auth_can_bulk_import_members(uuid)')
    as bulk_import_permission_function,
  has_function_privilege(
    'authenticated',
    'public.auth_can_bulk_import_members(uuid)',
    'EXECUTE'
  ) as authenticated_execute,
  has_function_privilege(
    'anon',
    'public.auth_can_bulk_import_members(uuid)',
    'EXECUTE'
  ) as anon_execute;

select
  count(*) filter (
    where function_row.name = 'Predsednik'
  ) as active_president_function_count,
  count(*) filter (
    where function_row.name = 'Predsednik'
      and rule.id is not null
      and rule.scope_key = 'SOCIETY'
      and rule.is_locked
  ) as president_locked_rule_count,
  count(*) filter (
    where function_row.name <> 'Predsednik'
      and rule.id is not null
      and rule.is_locked
  ) as invalid_locked_non_president_rule_count
from public.society_member_functions function_row
left join public.permission_catalog permission
  on permission.permission_key = 'members.bulk_import'
left join public.society_function_permission_rules rule
  on rule.society_id = function_row.society_id
 and rule.function_id = function_row.id
 and rule.permission_id = permission.id
where function_row.is_active;
