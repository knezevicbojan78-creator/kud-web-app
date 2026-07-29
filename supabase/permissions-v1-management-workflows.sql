-- FOLKLORAS — Dozvole V1, faza 2B
-- Kontrolisani President-only workflow-i za zajednicka pravila funkcije
-- i pojedinacne ALLOW/DENY izuzetke.

begin;

do $$
begin
  if to_regclass('public.permission_catalog') is null
     or to_regclass('public.society_function_permission_rules') is null
     or to_regclass('public.society_member_permission_overrides') is null
     or to_regclass('public.permission_change_audit') is null then
    raise exception 'Prvo pokrenite permissions-v1-foundation.sql.';
  end if;

  if to_regprocedure(
    'public.permissions_get_effective_rules(uuid,uuid,uuid)'
  ) is null then
    raise exception 'Prvo pokrenite permissions-v1-effective-read.sql.';
  end if;
end;
$$;

create or replace function public.permissions_assert_president(
  p_society_id uuid,
  p_actor_member_id uuid,
  p_require_writable boolean default false
) returns text[]
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
declare
  v_actor_user_id uuid;
  v_society_status text;
  v_function_names text[];
begin
  select sm.user_id
  into v_actor_user_id
  from public.society_members sm
  where sm.id = p_actor_member_id
    and sm.society_id = p_society_id
    and sm.status = 'ACTIVE';

  if not found then
    raise exception 'Aktivni clan izvrsilac nije pronadjen u drustvu.';
  end if;

  if auth.uid() is not null
     and v_actor_user_id is distinct from auth.uid() then
    raise exception 'Prijavljeni korisnik nije izabrani clan izvrsilac.';
  end if;

  select coalesce(
    array_agg(distinct smf.name order by smf.name),
    array[]::text[]
  )
  into v_function_names
  from public.society_member_function_assignments smfa
  join public.society_member_functions smf
    on smf.id = smfa.function_id
   and smf.society_id = p_society_id
   and smf.is_active = true
  where smfa.society_id = p_society_id
    and smfa.society_member_id = p_actor_member_id;

  if not exists (
    select 1
    from unnest(v_function_names) as function_name
    where lower(trim(function_name)) = lower('Predsednik')
  ) then
    raise exception 'Samo predsednik moze upravljati dozvolama.';
  end if;

  select status
  into v_society_status
  from public.societies
  where id = p_society_id;

  if v_society_status is null then
    raise exception 'Drustvo nije pronadjeno.';
  end if;

  if p_require_writable and v_society_status <> 'ACTIVE' then
    raise exception 'Suspendovano drustvo je u rezimu pregleda.';
  end if;

  return v_function_names;
end;
$$;

create or replace function public.permissions_list_function_configuration(
  p_society_id uuid,
  p_function_id uuid,
  p_actor_member_id uuid
) returns table (
  permission_key text,
  module_key text,
  label text,
  description text,
  action_type text,
  allowed_scopes text[],
  is_sensitive boolean,
  requires_reason boolean,
  is_enabled boolean,
  current_scope text,
  is_locked boolean
)
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
declare
  v_function_name text;
begin
  perform public.permissions_assert_president(
    p_society_id,
    p_actor_member_id,
    false
  );

  select smf.name
  into v_function_name
  from public.society_member_functions smf
  where smf.id = p_function_id
    and smf.society_id = p_society_id
    and smf.is_active = true;

  if v_function_name is null then
    raise exception 'Aktivna funkcija nije pronadjena u drustvu.';
  end if;

  return query
  select
    pc.permission_key,
    pc.module_key,
    pc.label,
    pc.description,
    pc.action_type,
    pc.allowed_scopes,
    pc.is_sensitive,
    pc.requires_reason,
    rule.id is not null as is_enabled,
    rule.scope_key as current_scope,
    coalesce(rule.is_locked, false) as is_locked
  from public.permission_catalog pc
  left join public.society_function_permission_rules rule
    on rule.permission_id = pc.id
   and rule.function_id = p_function_id
   and rule.society_id = p_society_id
  where pc.is_active = true
    and (
      pc.is_president_only = false
      or lower(trim(v_function_name)) = lower('Predsednik')
    )
  order by pc.module_key, pc.permission_key;
end;
$$;

create or replace function public.permissions_list_function_members(
  p_society_id uuid,
  p_function_id uuid,
  p_query text,
  p_actor_member_id uuid
) returns table (
  society_member_id uuid,
  display_name text,
  active_function_names text[],
  individual_override_count integer
)
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
declare
  v_query text := lower(trim(coalesce(p_query, '')));
begin
  perform public.permissions_assert_president(
    p_society_id,
    p_actor_member_id,
    false
  );

  if not exists (
    select 1
    from public.society_member_functions smf
    where smf.id = p_function_id
      and smf.society_id = p_society_id
      and smf.is_active = true
  ) then
    raise exception 'Aktivna funkcija nije pronadjena u drustvu.';
  end if;

  return query
  select
    sm.id,
    trim(person.first_name || ' ' || person.last_name),
    (
      select coalesce(
        array_agg(distinct assigned_function.name order by assigned_function.name),
        array[]::text[]
      )
      from public.society_member_function_assignments all_assignment
      join public.society_member_functions assigned_function
        on assigned_function.id = all_assignment.function_id
       and assigned_function.is_active = true
      where all_assignment.society_id = p_society_id
        and all_assignment.society_member_id = sm.id
    ),
    (
      select count(*)::integer
      from public.society_member_permission_overrides override
      where override.society_id = p_society_id
        and override.society_member_id = sm.id
    )
  from public.society_member_function_assignments selected_assignment
  join public.society_members sm
    on sm.id = selected_assignment.society_member_id
   and sm.society_id = p_society_id
   and sm.status = 'ACTIVE'
  join public.people person
    on person.id = sm.person_id
  where selected_assignment.society_id = p_society_id
    and selected_assignment.function_id = p_function_id
    and (
      v_query = ''
      or lower(concat_ws(
        ' ',
        person.first_name,
        person.last_name,
        person.email,
        person.phone
      )) like '%' || v_query || '%'
    )
  order by person.last_name, person.first_name, sm.id;
end;
$$;

create or replace function public.permissions_get_member_configuration(
  p_society_id uuid,
  p_target_member_id uuid,
  p_actor_member_id uuid
) returns table (
  permission_key text,
  module_key text,
  label text,
  action_type text,
  allowed_scopes text[],
  is_sensitive boolean,
  requires_reason boolean,
  override_effect text,
  override_scope text,
  effective_scopes text[],
  effective_is_locked boolean,
  effective_source_names text[]
)
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
begin
  perform public.permissions_assert_president(
    p_society_id,
    p_actor_member_id,
    false
  );

  if not exists (
    select 1
    from public.society_members sm
    where sm.id = p_target_member_id
      and sm.society_id = p_society_id
      and sm.status = 'ACTIVE'
  ) then
    raise exception 'Aktivni clan nije pronadjen u drustvu.';
  end if;

  return query
  with effective as (
    select *
    from public.permissions_get_effective_rules(
      p_society_id,
      p_target_member_id,
      (
        select sm.person_id
        from public.society_members sm
        where sm.id = p_target_member_id
      )
    )
  ),
  effective_grouped as (
    select
      e.permission_key,
      array_agg(distinct e.scope_key order by e.scope_key) as scopes,
      bool_or(e.is_locked) as locked,
      (
        select array_agg(
          distinct source_row.source_name
          order by source_row.source_name
        )
        from effective source_effective
        cross join unnest(source_effective.source_names)
          as source_row(source_name)
        where source_effective.permission_key = e.permission_key
      ) as sources
    from effective e
    group by e.permission_key
  )
  select
    pc.permission_key,
    pc.module_key,
    pc.label,
    pc.action_type,
    pc.allowed_scopes,
    pc.is_sensitive,
    pc.requires_reason,
    coalesce(override.effect, 'INHERIT') as override_effect,
    override.scope_key as override_scope,
    coalesce(grouped.scopes, array[]::text[]) as effective_scopes,
    coalesce(grouped.locked, false) as effective_is_locked,
    coalesce(grouped.sources, array[]::text[]) as effective_source_names
  from public.permission_catalog pc
  left join public.society_member_permission_overrides override
    on override.permission_id = pc.id
   and override.society_id = p_society_id
   and override.society_member_id = p_target_member_id
  left join effective_grouped grouped
    on grouped.permission_key = pc.permission_key
  where pc.is_active = true
    and pc.is_president_only = false
  order by pc.module_key, pc.permission_key;
end;
$$;

create or replace function public.permissions_save_function_rules(
  p_society_id uuid,
  p_function_id uuid,
  p_changes jsonb,
  p_reason text,
  p_actor_member_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor_function_names text[];
  v_function_name text;
  v_change jsonb;
  v_permission public.permission_catalog%rowtype;
  v_existing public.society_function_permission_rules%rowtype;
  v_enabled boolean;
  v_scope_key text;
  v_change_count integer := 0;
  v_previous jsonb;
  v_new jsonb;
begin
  v_actor_function_names := public.permissions_assert_president(
    p_society_id,
    p_actor_member_id,
    true
  );

  if jsonb_typeof(p_changes) <> 'array' then
    raise exception 'Promene dozvola funkcije moraju biti JSON niz.';
  end if;
  if coalesce(jsonb_array_length(p_changes), 0) = 0 then
    raise exception 'Nije prosledjena nijedna promena.';
  end if;
  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'Razlog promene dozvola je obavezan.';
  end if;
  if (
    select count(*)
    from jsonb_array_elements(p_changes) change_row
  ) <> (
    select count(distinct change_row ->> 'permission_key')
    from jsonb_array_elements(p_changes) change_row
  ) then
    raise exception 'Ista dozvola je poslata vise puta.';
  end if;

  select smf.name
  into v_function_name
  from public.society_member_functions smf
  where smf.id = p_function_id
    and smf.society_id = p_society_id
    and smf.is_active = true
  for update;

  if v_function_name is null then
    raise exception 'Aktivna funkcija nije pronadjena u drustvu.';
  end if;
  if lower(trim(v_function_name)) = lower('Predsednik') then
    raise exception 'Zakljucana prava predsednika se ne menjaju.';
  end if;

  for v_change in
    select value
    from jsonb_array_elements(p_changes)
  loop
    if not (v_change ? 'permission_key')
       or not (v_change ? 'enabled') then
      raise exception 'Svaka promena mora imati permission_key i enabled.';
    end if;

    begin
      v_enabled := (v_change ->> 'enabled')::boolean;
    exception when invalid_text_representation then
      raise exception 'enabled mora biti boolean vrednost.';
    end;

    select *
    into v_permission
    from public.permission_catalog
    where permission_key = trim(v_change ->> 'permission_key')
      and is_active = true;

    if not found then
      raise exception 'Dozvola % nije pronadjena.', v_change ->> 'permission_key';
    end if;
    if v_permission.is_president_only then
      raise exception 'Dozvola % je dostupna samo predsedniku.', v_permission.permission_key;
    end if;

    select *
    into v_existing
    from public.society_function_permission_rules
    where society_id = p_society_id
      and function_id = p_function_id
      and permission_id = v_permission.id
    for update;

    if found and v_existing.is_locked then
      if not v_enabled
         or v_existing.scope_key is distinct from nullif(trim(v_change ->> 'scope_key'), '') then
        raise exception 'Zakljucana dozvola % ne moze se menjati.', v_permission.permission_key;
      end if;
      continue;
    end if;

    if v_enabled then
      v_scope_key := nullif(trim(v_change ->> 'scope_key'), '');
      if v_scope_key is null then
        raise exception 'Opseg je obavezan za dozvolu %.', v_permission.permission_key;
      end if;
      if not (v_scope_key = any(v_permission.allowed_scopes)) then
        raise exception 'Opseg % nije dozvoljen za %.', v_scope_key, v_permission.permission_key;
      end if;

      v_previous := case
        when v_existing.id is null then null
        else jsonb_build_object(
          'enabled', true,
          'scope_key', v_existing.scope_key,
          'is_locked', v_existing.is_locked
        )
      end;
      v_new := jsonb_build_object(
        'enabled', true,
        'scope_key', v_scope_key,
        'is_locked', false
      );

      if v_previous is distinct from v_new then
        insert into public.society_function_permission_rules (
          society_id,
          function_id,
          permission_id,
          scope_key,
          is_locked,
          changed_by_society_member_id,
          change_reason
        ) values (
          p_society_id,
          p_function_id,
          v_permission.id,
          v_scope_key,
          false,
          p_actor_member_id,
          trim(p_reason)
        )
        on conflict (function_id, permission_id) do update
        set
          scope_key = excluded.scope_key,
          changed_by_society_member_id = excluded.changed_by_society_member_id,
          change_reason = excluded.change_reason,
          updated_at = now();

        insert into public.permission_change_audit (
          society_id,
          target_type,
          target_function_id,
          permission_id,
          action,
          previous_value,
          new_value,
          reason,
          actor_user_id,
          actor_society_member_id,
          actor_function_names
        ) values (
          p_society_id,
          'FUNCTION',
          p_function_id,
          v_permission.id,
          case when v_existing.id is null then 'CREATED' else 'UPDATED' end,
          v_previous,
          v_new,
          trim(p_reason),
          auth.uid(),
          p_actor_member_id,
          v_actor_function_names
        );

        v_change_count := v_change_count + 1;
      end if;
    elsif v_existing.id is not null then
      v_previous := jsonb_build_object(
        'enabled', true,
        'scope_key', v_existing.scope_key,
        'is_locked', v_existing.is_locked
      );

      delete from public.society_function_permission_rules
      where id = v_existing.id;

      insert into public.permission_change_audit (
        society_id,
        target_type,
        target_function_id,
        permission_id,
        action,
        previous_value,
        new_value,
        reason,
        actor_user_id,
        actor_society_member_id,
        actor_function_names
      ) values (
        p_society_id,
        'FUNCTION',
        p_function_id,
        v_permission.id,
        'REMOVED',
        v_previous,
        jsonb_build_object('enabled', false),
        trim(p_reason),
        auth.uid(),
        p_actor_member_id,
        v_actor_function_names
      );

      v_change_count := v_change_count + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'society_id', p_society_id,
    'function_id', p_function_id,
    'changed_count', v_change_count
  );
end;
$$;

create or replace function public.permissions_save_member_overrides(
  p_society_id uuid,
  p_target_member_id uuid,
  p_changes jsonb,
  p_reason text,
  p_actor_member_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor_function_names text[];
  v_change jsonb;
  v_permission public.permission_catalog%rowtype;
  v_existing public.society_member_permission_overrides%rowtype;
  v_effect text;
  v_scope_key text;
  v_change_count integer := 0;
  v_previous jsonb;
  v_new jsonb;
  v_target_person_id uuid;
begin
  v_actor_function_names := public.permissions_assert_president(
    p_society_id,
    p_actor_member_id,
    true
  );

  if jsonb_typeof(p_changes) <> 'array' then
    raise exception 'Pojedinacne promene moraju biti JSON niz.';
  end if;
  if coalesce(jsonb_array_length(p_changes), 0) = 0 then
    raise exception 'Nije prosledjena nijedna promena.';
  end if;
  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'Razlog pojedinacne promene je obavezan.';
  end if;
  if (
    select count(*)
    from jsonb_array_elements(p_changes) change_row
  ) <> (
    select count(distinct change_row ->> 'permission_key')
    from jsonb_array_elements(p_changes) change_row
  ) then
    raise exception 'Ista dozvola je poslata vise puta.';
  end if;

  select sm.person_id
  into v_target_person_id
  from public.society_members sm
  where sm.id = p_target_member_id
    and sm.society_id = p_society_id
    and sm.status = 'ACTIVE'
  for update;

  if v_target_person_id is null then
    raise exception 'Aktivni clan nije pronadjen u drustvu.';
  end if;

  for v_change in
    select value
    from jsonb_array_elements(p_changes)
  loop
    if not (v_change ? 'permission_key')
       or not (v_change ? 'effect') then
      raise exception 'Svaka promena mora imati permission_key i effect.';
    end if;

    v_effect := upper(trim(v_change ->> 'effect'));
    if v_effect not in ('INHERIT', 'ALLOW', 'DENY') then
      raise exception 'Effect mora biti INHERIT, ALLOW ili DENY.';
    end if;

    select *
    into v_permission
    from public.permission_catalog
    where permission_key = trim(v_change ->> 'permission_key')
      and is_active = true;

    if not found then
      raise exception 'Dozvola % nije pronadjena.', v_change ->> 'permission_key';
    end if;
    if v_permission.is_president_only then
      raise exception 'Dozvola % je dostupna samo predsedniku.', v_permission.permission_key;
    end if;

    select *
    into v_existing
    from public.society_member_permission_overrides
    where society_id = p_society_id
      and society_member_id = p_target_member_id
      and permission_id = v_permission.id
    for update;

    if v_effect = 'DENY' and exists (
      select 1
      from public.permissions_get_effective_rules(
        p_society_id,
        p_target_member_id,
        v_target_person_id
      ) effective
      where effective.permission_key = v_permission.permission_key
        and effective.is_locked = true
    ) then
      raise exception 'Obavezna dozvola % ne moze biti zabranjena.', v_permission.permission_key;
    end if;

    if v_effect = 'INHERIT' then
      if v_existing.id is not null then
        v_previous := jsonb_build_object(
          'effect', v_existing.effect,
          'scope_key', v_existing.scope_key
        );

        delete from public.society_member_permission_overrides
        where id = v_existing.id;

        insert into public.permission_change_audit (
          society_id,
          target_type,
          target_society_member_id,
          permission_id,
          action,
          previous_value,
          new_value,
          reason,
          actor_user_id,
          actor_society_member_id,
          actor_function_names
        ) values (
          p_society_id,
          'MEMBER',
          p_target_member_id,
          v_permission.id,
          'REMOVED',
          v_previous,
          jsonb_build_object('effect', 'INHERIT'),
          trim(p_reason),
          auth.uid(),
          p_actor_member_id,
          v_actor_function_names
        );

        v_change_count := v_change_count + 1;
      end if;
    else
      v_scope_key := case
        when v_effect = 'ALLOW'
          then nullif(trim(v_change ->> 'scope_key'), '')
        else null
      end;

      if v_effect = 'ALLOW' and v_scope_key is null then
        raise exception 'Opseg je obavezan za ALLOW dozvolu %.', v_permission.permission_key;
      end if;
      if v_effect = 'ALLOW'
         and not (v_scope_key = any(v_permission.allowed_scopes)) then
        raise exception 'Opseg % nije dozvoljen za %.', v_scope_key, v_permission.permission_key;
      end if;

      v_previous := case
        when v_existing.id is null then jsonb_build_object('effect', 'INHERIT')
        else jsonb_build_object(
          'effect', v_existing.effect,
          'scope_key', v_existing.scope_key
        )
      end;
      v_new := jsonb_build_object(
        'effect', v_effect,
        'scope_key', v_scope_key
      );

      if v_previous is distinct from v_new then
        insert into public.society_member_permission_overrides (
          society_id,
          society_member_id,
          permission_id,
          effect,
          scope_key,
          reason,
          changed_by_society_member_id
        ) values (
          p_society_id,
          p_target_member_id,
          v_permission.id,
          v_effect,
          v_scope_key,
          trim(p_reason),
          p_actor_member_id
        )
        on conflict (society_member_id, permission_id) do update
        set
          effect = excluded.effect,
          scope_key = excluded.scope_key,
          reason = excluded.reason,
          changed_by_society_member_id = excluded.changed_by_society_member_id,
          updated_at = now();

        insert into public.permission_change_audit (
          society_id,
          target_type,
          target_society_member_id,
          permission_id,
          action,
          previous_value,
          new_value,
          reason,
          actor_user_id,
          actor_society_member_id,
          actor_function_names
        ) values (
          p_society_id,
          'MEMBER',
          p_target_member_id,
          v_permission.id,
          case when v_existing.id is null then 'CREATED' else 'UPDATED' end,
          v_previous,
          v_new,
          trim(p_reason),
          auth.uid(),
          p_actor_member_id,
          v_actor_function_names
        );

        v_change_count := v_change_count + 1;
      end if;
    end if;
  end loop;

  return jsonb_build_object(
    'society_id', p_society_id,
    'society_member_id', p_target_member_id,
    'changed_count', v_change_count
  );
end;
$$;

comment on function public.permissions_save_function_rules(uuid, uuid, jsonb, text, uuid)
is 'Atomski cuva zajednicka prava funkcije. Dostupno samo predsedniku.';

comment on function public.permissions_save_member_overrides(uuid, uuid, jsonb, text, uuid)
is 'Atomski cuva pojedinacne INHERIT/ALLOW/DENY izuzetke. Dostupno samo predsedniku.';

revoke all on function public.permissions_assert_president(uuid, uuid, boolean)
  from public, anon, authenticated;
revoke all on function public.permissions_list_function_configuration(uuid, uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.permissions_list_function_members(uuid, uuid, text, uuid)
  from public, anon, authenticated;
revoke all on function public.permissions_get_member_configuration(uuid, uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.permissions_save_function_rules(uuid, uuid, jsonb, text, uuid)
  from public, anon, authenticated;
revoke all on function public.permissions_save_member_overrides(uuid, uuid, jsonb, text, uuid)
  from public, anon, authenticated;

commit;
