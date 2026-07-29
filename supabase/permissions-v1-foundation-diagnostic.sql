-- FOLKLORAS — READ-ONLY provera nakon permissions-v1-foundation.sql
-- Ovaj fajl ne menja podatke.

select
  to_regclass('public.permission_catalog') as permission_catalog,
  to_regclass('public.system_function_permission_templates') as system_templates,
  to_regclass('public.society_function_permission_rules') as function_rules,
  to_regclass('public.society_member_permission_overrides') as member_overrides,
  to_regclass('public.permission_change_audit') as permission_audit;

select
  module_key,
  count(*) as permission_count,
  count(*) filter (where is_sensitive) as sensitive_count,
  count(*) filter (where requires_reason) as reason_required_count,
  count(*) filter (where is_president_only) as president_only_count
from public.permission_catalog
where is_active = true
group by module_key
order by module_key;

select
  function_name,
  count(*) as template_count,
  count(*) filter (where is_locked) as locked_count
from public.system_function_permission_templates
group by function_name
order by function_name;

select
  s.id as society_id,
  s.name as society_name,
  smf.name as function_name,
  count(rule.id) as assigned_permission_count,
  count(rule.id) filter (where rule.is_locked) as locked_permission_count
from public.societies s
join public.society_member_functions smf
  on smf.society_id = s.id
left join public.society_function_permission_rules rule
  on rule.function_id = smf.id
where coalesce(smf.is_active, true) = true
group by s.id, s.name, smf.id, smf.name
order by s.name, smf.name;

-- Ovaj rezultat treba da bude prazan: pravilo mora koristiti opseg koji
-- dozvola podrzava.
select
  rule.id,
  rule.society_id,
  smf.name as function_name,
  pc.permission_key,
  rule.scope_key,
  pc.allowed_scopes
from public.society_function_permission_rules rule
join public.society_member_functions smf
  on smf.id = rule.function_id
join public.permission_catalog pc
  on pc.id = rule.permission_id
where not (rule.scope_key = any(pc.allowed_scopes));

-- Ovaj rezultat treba da bude prazan: funkcija i pravilo moraju pripadati
-- istom drustvu.
select
  rule.id,
  rule.society_id as rule_society_id,
  smf.society_id as function_society_id,
  smf.name as function_name
from public.society_function_permission_rules rule
join public.society_member_functions smf
  on smf.id = rule.function_id
where rule.society_id <> smf.society_id;

-- Ovaj rezultat treba da bude prazan: svako drustvo mora imati aktivnu
-- funkciju Predsednik i sva trenutno poznata predsednicka prava.
select
  s.id as society_id,
  s.name as society_name,
  count(distinct smf.id) filter (
    where lower(trim(smf.name)) = lower('Predsednik')
      and coalesce(smf.is_active, true) = true
  ) as active_president_function_count,
  count(rule.id) filter (
    where lower(trim(smf.name)) = lower('Predsednik')
      and rule.is_locked = true
  ) as locked_president_permission_count,
  (
    select count(*)
    from public.permission_catalog pc
    where pc.is_active = true
      and 'SOCIETY' = any(pc.allowed_scopes)
  ) as expected_president_permission_count
from public.societies s
left join public.society_member_functions smf
  on smf.society_id = s.id
left join public.society_function_permission_rules rule
  on rule.function_id = smf.id
group by s.id, s.name
having
  count(distinct smf.id) filter (
    where lower(trim(smf.name)) = lower('Predsednik')
      and coalesce(smf.is_active, true) = true
  ) <> 1
  or
  count(rule.id) filter (
    where lower(trim(smf.name)) = lower('Predsednik')
      and rule.is_locked = true
  ) <> (
    select count(*)
    from public.permission_catalog pc
    where pc.is_active = true
      and 'SOCIETY' = any(pc.allowed_scopes)
  );

select
  count(*) as individual_override_count,
  count(*) filter (where effect = 'ALLOW') as allow_count,
  count(*) filter (where effect = 'DENY') as deny_count
from public.society_member_permission_overrides;

select count(*) as permission_audit_count
from public.permission_change_audit;

-- Zbirni rezultat za Supabase SQL Editor, koji cesto prikaze samo poslednji
-- result set. Svaka stavka osim informacionih brojaca treba da bude 0.
select
  (select count(*) from public.permission_catalog where is_active = true)
    as active_permission_count,
  (select count(*) from public.system_function_permission_templates)
    as template_count,
  (select count(*) from public.society_function_permission_rules)
    as function_rule_count,
  (
    select count(*)
    from public.society_function_permission_rules rule
    join public.permission_catalog pc on pc.id = rule.permission_id
    where not (rule.scope_key = any(pc.allowed_scopes))
  ) as invalid_scope_count,
  (
    select count(*)
    from public.society_function_permission_rules rule
    join public.society_member_functions smf on smf.id = rule.function_id
    where rule.society_id <> smf.society_id
  ) as wrong_society_count,
  (
    select count(*)
    from public.societies s
    where not exists (
      select 1
      from public.society_member_functions smf
      where smf.society_id = s.id
        and lower(trim(smf.name)) = lower('Predsednik')
        and coalesce(smf.is_active, true) = true
    )
  ) as society_without_president_function_count,
  (
    select count(*)
    from public.society_member_permission_overrides
  ) as individual_override_count,
  (
    select count(*)
    from public.permission_change_audit
  ) as permission_audit_count;
