-- FOLKLORAS — READ-ONLY provera nakon permissions-v1-management-workflows.sql
-- Ne menja pravila, izuzetke niti audit.

select
  to_regprocedure('public.permissions_assert_president(uuid,uuid,boolean)')
    as assert_president_function,
  to_regprocedure('public.permissions_list_function_configuration(uuid,uuid,uuid)')
    as function_configuration_function,
  to_regprocedure('public.permissions_list_function_members(uuid,uuid,text,uuid)')
    as function_members_function,
  to_regprocedure('public.permissions_get_member_configuration(uuid,uuid,uuid)')
    as member_configuration_function,
  to_regprocedure('public.permissions_save_function_rules(uuid,uuid,jsonb,text,uuid)')
    as save_function_rules_function,
  to_regprocedure('public.permissions_save_member_overrides(uuid,uuid,jsonb,text,uuid)')
    as save_member_overrides_function;

-- Zbirni rezultat. Sve kolone sa suffixom _error_count treba da budu 0.
with president_actors as (
  select distinct
    sm.society_id,
    sm.id as society_member_id
  from public.society_members sm
  join public.society_member_function_assignments smfa
    on smfa.society_member_id = sm.id
   and smfa.society_id = sm.society_id
  join public.society_member_functions smf
    on smf.id = smfa.function_id
   and smf.society_id = sm.society_id
   and smf.is_active = true
  where sm.status = 'ACTIVE'
    and lower(trim(smf.name)) = lower('Predsednik')
),
president_functions as (
  select
    actor.society_id,
    actor.society_member_id,
    smf.id as function_id
  from president_actors actor
  join public.society_member_functions smf
    on smf.society_id = actor.society_id
   and smf.is_active = true
   and lower(trim(smf.name)) = lower('Predsednik')
),
non_president_functions as (
  select distinct on (smf.society_id)
    actor.society_member_id as actor_member_id,
    smf.society_id,
    smf.id as function_id
  from public.society_member_functions smf
  join president_actors actor
    on actor.society_id = smf.society_id
  where smf.is_active = true
    and lower(trim(smf.name)) <> lower('Predsednik')
  order by smf.society_id, smf.sort_order, smf.name
)
select
  (
    select coalesce(
      jsonb_object_agg(summary.function_name, summary.assignment_count),
      '{}'::jsonb
    )
    from (
      select
        smf.name as function_name,
        count(distinct smfa.society_member_id) as assignment_count
      from public.society_member_functions smf
      left join public.society_member_function_assignments smfa
        on smfa.function_id = smf.id
       and smfa.society_id = smf.society_id
      where smf.is_active = true
      group by smf.name
      order by smf.name
    ) summary
  ) as active_assignment_counts_by_function,
  (select count(*) from president_actors) as president_actor_count,
  (
    select count(*)
    from president_functions context
    cross join lateral public.permissions_list_function_configuration(
      context.society_id,
      context.function_id,
      context.society_member_id
    ) configuration
  ) as president_configuration_row_count,
  (
    select count(*)
    from non_president_functions context
    cross join lateral public.permissions_list_function_configuration(
      context.society_id,
      context.function_id,
      context.actor_member_id
    ) configuration
  ) as sampled_non_president_configuration_row_count,
  (
    select count(*)
    from public.society_function_permission_rules rule
    join public.society_member_functions smf
      on smf.id = rule.function_id
    join public.permission_catalog pc
      on pc.id = rule.permission_id
    where pc.is_president_only = true
      and lower(trim(smf.name)) <> lower('Predsednik')
  ) as president_only_rule_leak_error_count,
  (
    select count(*)
    from public.society_member_permission_overrides override
    join public.permission_catalog pc
      on pc.id = override.permission_id
    where pc.is_president_only = true
  ) as president_only_override_leak_error_count,
  (
    select count(*)
    from public.society_member_permission_overrides override
    where override.effect = 'ALLOW'
      and override.scope_key is null
  ) as allow_without_scope_error_count,
  (
    select count(*)
    from public.society_member_permission_overrides override
    where override.effect = 'DENY'
      and override.scope_key is not null
  ) as deny_with_scope_error_count,
  (
    case when
      has_function_privilege(
        'anon',
        'public.permissions_save_function_rules(uuid,uuid,jsonb,text,uuid)',
        'EXECUTE'
      )
      or has_function_privilege(
        'anon',
        'public.permissions_save_member_overrides(uuid,uuid,jsonb,text,uuid)',
        'EXECUTE'
      )
    then 1 else 0 end
  ) as anon_execute_error_count,
  (
    case when
      has_function_privilege(
        'authenticated',
        'public.permissions_save_function_rules(uuid,uuid,jsonb,text,uuid)',
        'EXECUTE'
      )
      or has_function_privilege(
        'authenticated',
        'public.permissions_save_member_overrides(uuid,uuid,jsonb,text,uuid)',
        'EXECUTE'
      )
    then 1 else 0 end
  ) as authenticated_execute_error_count;
