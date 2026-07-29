-- FOLKLORAS — READ-ONLY provera nakon permissions-v1-effective-read.sql
-- Ne menja podatke.

-- Pregled aktivnih clanova bez prikaza identiteta osobe.
select
  sm.society_id,
  sm.id as society_member_id,
  count(distinct smfa.function_id) filter (where smf.is_active = true) as active_function_count,
  (
    select count(*)
    from public.permissions_get_effective_rules(
      sm.society_id,
      sm.id,
      sm.person_id
    )
  ) as effective_rule_count
from public.society_members sm
left join public.society_member_function_assignments smfa
  on smfa.society_member_id = sm.id
 and smfa.society_id = sm.society_id
left join public.society_member_functions smf
  on smf.id = smfa.function_id
 and smf.is_active = true
where sm.status = 'ACTIVE'
group by sm.society_id, sm.id, sm.person_id
order by sm.society_id, sm.id;

-- Zbirni rezultat. Sve kolone sa suffixom _error_count treba da budu 0.
with active_members as (
  select sm.id, sm.society_id, sm.person_id
  from public.society_members sm
  where sm.status = 'ACTIVE'
),
member_function_counts as (
  select
    member.id as society_member_id,
    count(distinct smfa.function_id) filter (where smf.is_active = true) as function_count
  from active_members member
  left join public.society_member_function_assignments smfa
    on smfa.society_member_id = member.id
   and smfa.society_id = member.society_id
  left join public.society_member_functions smf
    on smf.id = smfa.function_id
  group by member.id
),
guardians_in_societies as (
  select distinct
    child_sm.society_id,
    pg.guardian_person_id
  from public.person_guardians pg
  join public.society_members child_sm
    on child_sm.person_id = pg.child_person_id
   and child_sm.status = 'ACTIVE'
),
missing_locked_function_grants as (
  select distinct
    member.id as society_member_id,
    rule.permission_id,
    rule.scope_key
  from active_members member
  join public.society_member_function_assignments smfa
    on smfa.society_member_id = member.id
   and smfa.society_id = member.society_id
  join public.society_member_functions smf
    on smf.id = smfa.function_id
   and smf.is_active = true
  join public.society_function_permission_rules rule
    on rule.function_id = smf.id
   and rule.society_id = member.society_id
   and rule.is_locked = true
  join public.permission_catalog pc
    on pc.id = rule.permission_id
   and pc.is_active = true
  where not exists (
    select 1
    from public.permissions_get_effective_rules(
      member.society_id,
      member.id,
      member.person_id
    ) effective
    where effective.permission_key = pc.permission_key
      and effective.scope_key = rule.scope_key
  )
)
select
  (select count(*) from active_members) as active_member_count,
  (
    select count(*)
    from member_function_counts
    where function_count > 0
  ) as member_with_function_count,
  (
    select count(*)
    from member_function_counts
    where function_count > 1
  ) as member_with_multiple_functions_count,
  (
    select count(*)
    from guardians_in_societies
  ) as guardian_context_count,
  (
    select count(*)
    from active_members member
    where (
      select count(*)
      from public.permissions_get_effective_rules(
        member.society_id,
        member.id,
        member.person_id
      ) effective
      where 'SYSTEM_MEMBER' = any(effective.source_types)
    ) <> 14
  ) as member_base_error_count,
  (
    select count(*)
    from guardians_in_societies guardian
    where (
      select count(*)
      from public.permissions_get_effective_rules(
        guardian.society_id,
        null,
        guardian.guardian_person_id
      ) effective
      where 'SYSTEM_GUARDIAN' = any(effective.source_types)
    ) <> 14
  ) as guardian_base_error_count,
  (
    select count(*)
    from missing_locked_function_grants
  ) as locked_function_grant_error_count,
  (
    select count(*)
    from active_members member
    where not exists (
      select 1
      from public.society_member_function_assignments smfa
      join public.society_member_functions smf
        on smf.id = smfa.function_id
       and smf.is_active = true
      where smfa.society_member_id = member.id
        and smfa.society_id = member.society_id
        and lower(trim(smf.name)) = lower('Predsednik')
    )
    and exists (
      select 1
      from public.permissions_get_effective_rules(
        member.society_id,
        member.id,
        member.person_id
      ) effective
      where effective.permission_key = 'permissions.manage'
    )
  ) as president_only_leak_error_count;
