-- FOLKLORAS — Dozvole V1, faza 2A
-- Centralni READ obracun efektivnih dozvola.
-- Ne menja postojece module i ne daje klijentu direktan execute pristup.

begin;

do $$
begin
  if to_regclass('public.permission_catalog') is null
     or to_regclass('public.society_function_permission_rules') is null
     or to_regclass('public.society_member_permission_overrides') is null then
    raise exception 'Prvo pokrenite permissions-v1-foundation.sql.';
  end if;
  if to_regclass('public.person_guardians') is null then
    raise exception 'Nedostaje public.person_guardians.';
  end if;
end;
$$;

create or replace function public.permissions_get_effective_rules(
  p_society_id uuid,
  p_actor_member_id uuid default null,
  p_actor_person_id uuid default null
) returns table (
  permission_key text,
  module_key text,
  action_type text,
  scope_key text,
  is_sensitive boolean,
  requires_reason boolean,
  is_locked boolean,
  source_types text[],
  source_names text[]
)
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  with actor_context as (
    select
      sm.id as society_member_id,
      sm.person_id,
      sm.society_id,
      sm.status
    from public.society_members sm
    where p_actor_member_id is not null
      and sm.id = p_actor_member_id
      and sm.society_id = p_society_id
      and sm.status = 'ACTIVE'
      and (
        p_actor_person_id is null
        or p_actor_person_id = sm.person_id
      )

    union all

    select
      null::uuid,
      p_actor_person_id,
      p_society_id,
      'GUARDIAN'::text
    where p_actor_member_id is null
      and p_actor_person_id is not null
      and exists (
        select 1
        from public.person_guardians pg
        join public.society_members child_sm
          on child_sm.person_id = pg.child_person_id
         and child_sm.society_id = p_society_id
         and child_sm.status = 'ACTIVE'
        where pg.guardian_person_id = p_actor_person_id
      )
  ),
  denied_permissions as (
    select override.permission_id
    from public.society_member_permission_overrides override
    join actor_context actor
      on actor.society_member_id = override.society_member_id
    where override.society_id = p_society_id
      and override.effect = 'DENY'
  ),
  function_grants as (
    select
      rule.permission_id,
      rule.scope_key,
      rule.is_locked,
      'FUNCTION'::text as source_type,
      smf.name::text as source_name
    from actor_context actor
    join public.society_member_function_assignments assignment
      on assignment.society_member_id = actor.society_member_id
     and assignment.society_id = p_society_id
    join public.society_member_functions smf
      on smf.id = assignment.function_id
     and smf.society_id = p_society_id
     and smf.is_active = true
    join public.society_function_permission_rules rule
      on rule.function_id = smf.id
     and rule.society_id = p_society_id
    join public.permission_catalog permission
      on permission.id = rule.permission_id
     and permission.is_active = true
    where
      rule.is_locked = true
      or not exists (
        select 1
        from denied_permissions denied
        where denied.permission_id = rule.permission_id
      )
  ),
  individual_allows as (
    select
      override.permission_id,
      override.scope_key,
      false as is_locked,
      'MEMBER_OVERRIDE'::text as source_type,
      'Pojedinacni ALLOW'::text as source_name
    from public.society_member_permission_overrides override
    join actor_context actor
      on actor.society_member_id = override.society_member_id
    join public.permission_catalog permission
      on permission.id = override.permission_id
     and permission.is_active = true
     and permission.is_president_only = false
    where override.society_id = p_society_id
      and override.effect = 'ALLOW'
  ),
  member_base_values(permission_key, scope_key) as (
    values
      ('members.view_basic', 'SELF'),
      ('members.view_sensitive', 'SELF'),
      ('members.view_guardians', 'SELF'),
      ('members.view_history', 'SELF'),
      ('members.view_sections', 'SELF'),
      ('members.request_change', 'SELF'),
      ('sections.view', 'MEMBER_SECTIONS'),
      ('sections.view_roles', 'MEMBER_SECTIONS'),
      ('attendance.view', 'SELF'),
      ('events.view', 'PARTICIPATING_EVENTS'),
      ('events.view_program', 'PARTICIPATING_EVENTS'),
      ('events.view_fees', 'SELF'),
      ('repertoire.view', 'MEMBER_SECTIONS'),
      ('finance.view', 'SELF')
  ),
  member_base_grants as (
    select
      permission.id as permission_id,
      value.scope_key,
      true as is_locked,
      'SYSTEM_MEMBER'::text as source_type,
      'Obavezna prava clana'::text as source_name
    from actor_context actor
    cross join member_base_values value
    join public.permission_catalog permission
      on permission.permission_key = value.permission_key
     and permission.is_active = true
    where actor.society_member_id is not null
  ),
  guardian_base_values(permission_key, scope_key) as (
    values
      ('members.view_basic', 'CHILDREN'),
      ('members.view_sensitive', 'CHILDREN'),
      ('members.view_guardians', 'CHILDREN'),
      ('members.view_history', 'CHILDREN'),
      ('members.view_sections', 'CHILDREN'),
      ('members.request_change', 'CHILDREN'),
      ('sections.view', 'CHILDREN'),
      ('sections.view_roles', 'CHILDREN'),
      ('attendance.view', 'CHILDREN'),
      ('events.view', 'CHILD_PARTICIPATING_EVENTS'),
      ('events.view_program', 'CHILD_PARTICIPATING_EVENTS'),
      ('events.view_fees', 'CHILDREN'),
      ('repertoire.view', 'CHILDREN'),
      ('finance.view', 'CHILDREN')
  ),
  guardian_base_grants as (
    select
      permission.id as permission_id,
      value.scope_key,
      true as is_locked,
      'SYSTEM_GUARDIAN'::text as source_type,
      'Obavezna prava roditelja ili staratelja'::text as source_name
    from actor_context actor
    cross join guardian_base_values value
    join public.permission_catalog permission
      on permission.permission_key = value.permission_key
     and permission.is_active = true
    where exists (
      select 1
      from public.person_guardians pg
      join public.society_members child_sm
        on child_sm.person_id = pg.child_person_id
       and child_sm.society_id = p_society_id
       and child_sm.status = 'ACTIVE'
      where pg.guardian_person_id = actor.person_id
    )
  ),
  all_grants as (
    select * from function_grants
    union all
    select * from individual_allows
    union all
    select * from member_base_grants
    union all
    select * from guardian_base_grants
  ),
  grouped_grants as (
    select
      grant_row.permission_id,
      grant_row.scope_key,
      bool_or(grant_row.is_locked) as is_locked,
      array_agg(distinct grant_row.source_type order by grant_row.source_type) as source_types,
      array_agg(distinct grant_row.source_name order by grant_row.source_name) as source_names
    from all_grants grant_row
    group by grant_row.permission_id, grant_row.scope_key
  )
  select
    permission.permission_key,
    permission.module_key,
    permission.action_type,
    grouped.scope_key,
    permission.is_sensitive,
    permission.requires_reason,
    grouped.is_locked,
    grouped.source_types,
    grouped.source_names
  from grouped_grants grouped
  join public.permission_catalog permission
    on permission.id = grouped.permission_id
   and permission.is_active = true
  order by permission.module_key, permission.permission_key, grouped.scope_key;
$$;

create or replace function public.permissions_has_scope(
  p_society_id uuid,
  p_actor_member_id uuid,
  p_actor_person_id uuid,
  p_permission_key text,
  p_accepted_scopes text[]
) returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.permissions_get_effective_rules(
      p_society_id,
      p_actor_member_id,
      p_actor_person_id
    ) effective
    where effective.permission_key = p_permission_key
      and effective.scope_key = any(coalesce(p_accepted_scopes, array[]::text[]))
  );
$$;

comment on function public.permissions_get_effective_rules(uuid, uuid, uuid)
is 'Interni READ obracun efektivnih prava. Ne proverava jos ciljni zapis niti se direktno daje klijentu.';

comment on function public.permissions_has_scope(uuid, uuid, uuid, text, text[])
is 'Interna provera da li korisnik ima dozvolu u jednom od prosledjenih opsega.';

revoke all on function public.permissions_get_effective_rules(uuid, uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.permissions_has_scope(uuid, uuid, uuid, text, text[])
  from public, anon, authenticated;

commit;
