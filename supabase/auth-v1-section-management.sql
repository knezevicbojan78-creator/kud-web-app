begin;

create or replace function public.auth_manage_section(
  p_action text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_society_id uuid := nullif(p_payload ->> 'society_id', '')::uuid;
  v_section_id uuid := nullif(p_payload ->> 'section_id', '')::uuid;
  v_member_id uuid := nullif(p_payload ->> 'society_member_id', '')::uuid;
  v_assignment_id uuid := nullif(p_payload ->> 'assignment_id', '')::uuid;
  v_repertoire_id uuid := nullif(p_payload ->> 'repertoire_item_id', '')::uuid;
  v_actor_member_id uuid;
  v_actor_person_id uuid;
  v_is_president boolean := false;
  v_is_section_ur boolean := false;
  v_can_manage_repertoire boolean := false;
  v_existing public.member_sections;
  v_old_status text;
  v_new_status text;
  v_created_id uuid;
begin
  if v_user_id is null then
    raise exception 'Prijava je obavezna.';
  end if;

  if v_society_id is null and v_section_id is not null then
    select society_id into v_society_id
    from public.sections where id = v_section_id;
  end if;

  select member_row.id, member_row.person_id
  into v_actor_member_id, v_actor_person_id
  from public.society_members member_row
  join public.people person_row on person_row.id = member_row.person_id
  where member_row.society_id = v_society_id
    and member_row.status = 'ACTIVE'
    and coalesce(member_row.user_id, person_row.user_id) = v_user_id
  limit 1;

  if v_actor_member_id is null then
    raise exception 'Aktivno clanstvo prijavljenog korisnika nije pronadjeno.';
  end if;

  select exists (
    select 1
    from public.society_member_function_assignments assignment
    join public.society_member_functions function_row
      on function_row.id = assignment.function_id
    where assignment.society_member_id = v_actor_member_id
      and assignment.society_id = v_society_id
      and function_row.name = 'Predsednik'
      and function_row.is_active
  ) into v_is_president;

  if v_section_id is not null then
    select
      exists (
        select 1 from public.section_role_assignments role_row
        where role_row.section_id = v_section_id
          and role_row.society_member_id = v_actor_member_id
          and role_row.role = 'UR'
          and role_row.status = 'ACTIVE'
      ),
      exists (
        select 1 from public.section_role_assignments role_row
        where role_row.section_id = v_section_id
          and role_row.society_member_id = v_actor_member_id
          and role_row.role = 'UR'
          and role_row.status = 'ACTIVE'
          and role_row.can_manage_repertoire
      )
    into v_is_section_ur, v_can_manage_repertoire;
  end if;

  if p_action = 'CREATE_SECTION' then
    if not public.permissions_has_scope(
      v_society_id, v_actor_member_id, v_actor_person_id,
      'sections.create', array['SOCIETY']::text[]
    ) then
      raise exception 'Nemate dozvolu za kreiranje sekcije.';
    end if;
    insert into public.sections (
      society_id, name, rehearsal_duration_minutes, status
    ) values (
      v_society_id,
      btrim(p_payload ->> 'name'),
      coalesce((p_payload ->> 'rehearsal_duration_minutes')::integer, 120),
      'ACTIVE'
    ) returning id into v_created_id;

  elsif p_action = 'UPDATE_SECTION' then
    if not public.permissions_can_access_section(
      v_society_id, v_actor_member_id, v_actor_person_id,
      v_section_id, 'sections.edit'
    ) then
      raise exception 'Nemate dozvolu za izmenu ove sekcije.';
    end if;
    update public.sections
    set name = btrim(p_payload ->> 'name'),
        rehearsal_duration_minutes =
          (p_payload ->> 'rehearsal_duration_minutes')::integer,
        updated_at = now()
    where id = v_section_id and society_id = v_society_id;

  elsif p_action = 'SET_SECTION_STATUS' then
    if not public.permissions_can_access_section(
      v_society_id, v_actor_member_id, v_actor_person_id,
      v_section_id, 'sections.change_status'
    ) then
      raise exception 'Nemate dozvolu za promenu statusa sekcije.';
    end if;
    v_new_status := p_payload ->> 'status';
    if v_new_status not in ('ACTIVE', 'INACTIVE') then
      raise exception 'Status sekcije nije ispravan.';
    end if;
    update public.sections
    set status = v_new_status, updated_at = now()
    where id = v_section_id and society_id = v_society_id;

    if v_new_status = 'INACTIVE' then
      insert into public.member_section_history (
        member_section_id, society_id, section_id, society_member_id,
        old_status, new_status, effective_date, changed_by_user_id, note
      )
      select id, society_id, section_id, society_member_id,
        status, 'INACTIVE', current_date, v_user_id,
        'Deaktivacija zbog deaktivacije sekcije'
      from public.member_sections
      where section_id = v_section_id and status = 'ACTIVE';

      update public.member_sections set status = 'INACTIVE'
      where section_id = v_section_id and status = 'ACTIVE';
      update public.section_role_assignments set status = 'INACTIVE'
      where section_id = v_section_id and status = 'ACTIVE';
    end if;

  elsif p_action = 'ASSIGN_ROLE' then
    if not public.permissions_can_access_section(
      v_society_id, v_actor_member_id, v_actor_person_id,
      v_section_id, 'sections.manage_roles'
    ) then
      raise exception 'Nemate dozvolu za dodelu sekcijskih uloga.';
    end if;
    if p_payload ->> 'role' not in ('UR', 'KOREPETITOR') then
      raise exception 'Sekcijska uloga nije ispravna.';
    end if;
    if not exists (
      select 1 from public.society_members
      where id = v_member_id and society_id = v_society_id
    ) then
      raise exception 'Clan ne pripada ovom drustvu.';
    end if;
    if p_payload ->> 'role' = 'KOREPETITOR' then
      update public.section_role_assignments set status = 'INACTIVE'
      where section_id = v_section_id
        and role = 'KOREPETITOR' and status = 'ACTIVE';
    end if;
    insert into public.section_role_assignments (
      society_id, section_id, society_member_id, role, status
    ) values (
      v_society_id, v_section_id, v_member_id,
      p_payload ->> 'role', 'ACTIVE'
    )
    on conflict (section_id, society_member_id, role)
    do update set status = 'ACTIVE', updated_at = now();

  elsif p_action = 'DEACTIVATE_ROLE' then
    if not public.permissions_can_access_section(
      v_society_id, v_actor_member_id, v_actor_person_id,
      v_section_id, 'sections.manage_roles'
    ) then
      raise exception 'Nemate dozvolu za uklanjanje sekcijskih uloga.';
    end if;
    update public.section_role_assignments set status = 'INACTIVE'
    where id = v_assignment_id
      and society_id = v_society_id
      and section_id = v_section_id;

  elsif p_action = 'SET_REPERTOIRE_PERMISSION' then
    if not public.permissions_can_access_section(
      v_society_id, v_actor_member_id, v_actor_person_id,
      v_section_id, 'sections.manage_roles'
    ) then
      raise exception 'Nemate dozvolu za promenu prava sekcijske uloge.';
    end if;
    update public.section_role_assignments
    set can_manage_repertoire =
      coalesce((p_payload ->> 'enabled')::boolean, false),
      updated_at = now()
    where id = v_assignment_id
      and society_id = v_society_id
      and section_id = v_section_id;

  elsif p_action = 'CREATE_REPERTOIRE' then
    if not public.permissions_can_access_section(
      v_society_id, v_actor_member_id, v_actor_person_id,
      v_section_id, 'repertoire.create'
    ) then
      raise exception 'Nemate pravo izmene repertoara ove sekcije.';
    end if;
    insert into public.repertoire_items (
      society_id, name, item_type, duration_minutes, description,
      costume_note, created_by_user_id, created_by_society_member_id
    ) values (
      v_society_id, btrim(p_payload ->> 'name'),
      p_payload ->> 'item_type',
      nullif(p_payload ->> 'duration_minutes', '')::integer,
      nullif(btrim(p_payload ->> 'description'), ''),
      nullif(btrim(p_payload ->> 'costume_note'), ''),
      v_user_id, v_actor_member_id
    ) returning id into v_created_id;
    insert into public.repertoire_item_sections (
      repertoire_item_id, section_id
    ) values (v_created_id, v_section_id);

  elsif p_action = 'SET_REPERTOIRE_STATUS' then
    if not public.permissions_can_access_section(
      v_society_id, v_actor_member_id, v_actor_person_id,
      v_section_id, 'repertoire.change_status'
    ) then
      raise exception 'Nemate pravo izmene repertoara ove sekcije.';
    end if;
    if not exists (
      select 1 from public.repertoire_item_sections
      where repertoire_item_id = v_repertoire_id
        and section_id = v_section_id
    ) then
      raise exception 'Stavka repertoara ne pripada ovoj sekciji.';
    end if;
    update public.repertoire_items
    set status = p_payload ->> 'status', updated_at = now()
    where id = v_repertoire_id and society_id = v_society_id;

  elsif p_action = 'SET_MEMBER_STATUS' then
    if not public.permissions_can_access_section(
      v_society_id, v_actor_member_id, v_actor_person_id,
      v_section_id, 'sections.manage_members'
    ) then
      raise exception 'Nemate pravo izmene clanova ove sekcije.';
    end if;
    if not exists (
      select 1 from public.society_members
      where id = v_member_id and society_id = v_society_id
    ) then
      raise exception 'Clan ne pripada ovom drustvu.';
    end if;
    v_new_status := p_payload ->> 'status';
    if v_new_status not in ('ACTIVE', 'INACTIVE') then
      raise exception 'Status clanstva u sekciji nije ispravan.';
    end if;
    select * into v_existing
    from public.member_sections
    where section_id = v_section_id and society_member_id = v_member_id
    for update;

    if found then
      v_old_status := v_existing.status;
      if v_old_status is distinct from v_new_status then
        update public.member_sections set status = v_new_status
        where id = v_existing.id;
        insert into public.member_section_history (
          member_section_id, society_id, section_id, society_member_id,
          old_status, new_status, effective_date, changed_by_user_id, note
        ) values (
          v_existing.id, v_society_id, v_section_id, v_member_id,
          v_old_status, v_new_status, current_date, v_user_id,
          'Promena kroz Auth V1 upravljanje sekcijom'
        );
      end if;
      v_created_id := v_existing.id;
    else
      if v_new_status <> 'ACTIVE' then
        raise exception 'Nepostojece clanstvo moze samo da se aktivira.';
      end if;
      insert into public.member_sections (
        society_id, section_id, society_member_id, status
      ) values (
        v_society_id, v_section_id, v_member_id, 'ACTIVE'
      ) returning id into v_created_id;
      insert into public.member_section_history (
        member_section_id, society_id, section_id, society_member_id,
        old_status, new_status, effective_date, changed_by_user_id, note
      ) values (
        v_created_id, v_society_id, v_section_id, v_member_id,
        null, 'ACTIVE', current_date, v_user_id,
        'Prvo dodavanje kroz Auth V1 upravljanje sekcijom'
      );
    end if;
  else
    raise exception 'Nepoznata akcija upravljanja sekcijom.';
  end if;

  return jsonb_build_object(
    'success', true,
    'id', coalesce(v_created_id, v_section_id, v_assignment_id)
  );
end;
$$;

create or replace function public.auth_search_society_members(
  p_society_id uuid,
  p_query text,
  p_section_id uuid default null,
  p_exclude_active_section boolean default false,
  p_exclude_active_role text default null
)
returns jsonb
language plpgsql
security definer
stable
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_actor_member_id uuid;
  v_actor_person_id uuid;
  v_is_president boolean := false;
  v_is_section_ur boolean := false;
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception 'Prijava je obavezna.';
  end if;

  select member_row.id, member_row.person_id
  into v_actor_member_id, v_actor_person_id
  from public.society_members member_row
  join public.people person_row on person_row.id = member_row.person_id
  where member_row.society_id = p_society_id
    and member_row.status = 'ACTIVE'
    and coalesce(member_row.user_id, person_row.user_id) = v_user_id
  limit 1;

  select exists (
    select 1
    from public.society_member_function_assignments assignment
    join public.society_member_functions function_row
      on function_row.id = assignment.function_id
    where assignment.society_member_id = v_actor_member_id
      and assignment.society_id = p_society_id
      and function_row.name = 'Predsednik'
      and function_row.is_active
  ) into v_is_president;

  if p_section_id is not null then
    select exists (
      select 1 from public.section_role_assignments role_row
      where role_row.section_id = p_section_id
        and role_row.society_member_id = v_actor_member_id
        and role_row.role = 'UR'
        and role_row.status = 'ACTIVE'
    ) into v_is_section_ur;
  end if;

  if p_section_id is null then
    raise exception 'Sekcija je obavezna za pretragu clanova.';
  end if;

  if p_exclude_active_role is not null and not public.permissions_can_access_section(
    p_society_id, v_actor_member_id, v_actor_person_id,
    p_section_id, 'sections.manage_roles'
  ) then
    raise exception 'Nemate pravo pretrage clanova za sekcijsku ulogu.';
  elsif p_exclude_active_role is null and not public.permissions_can_access_section(
    p_society_id, v_actor_member_id, v_actor_person_id,
    p_section_id, 'sections.manage_members'
  ) then
    raise exception 'Nemate pravo pretrage clanova ovog drustva.';
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'societyMemberId', member_row.id,
      'personId', person_row.id,
      'name', concat_ws(
        ' ', person_row.first_name, person_row.last_name
      ),
      'email', person_row.email,
      'phone', person_row.phone
    )
    order by person_row.first_name, person_row.last_name
  ), '[]'::jsonb)
  into v_result
  from public.society_members member_row
  join public.people person_row on person_row.id = member_row.person_id
  where member_row.society_id = p_society_id
    and member_row.status = 'ACTIVE'
    and (
      coalesce(p_query, '') = ''
      or concat_ws(
        ' ', person_row.first_name, person_row.last_name,
        person_row.email, person_row.phone
      ) ilike '%' || btrim(p_query) || '%'
    )
    and (
      not p_exclude_active_section
      or p_section_id is null
      or not exists (
        select 1 from public.member_sections membership
        where membership.section_id = p_section_id
          and membership.society_member_id = member_row.id
          and membership.status = 'ACTIVE'
      )
    )
    and (
      p_exclude_active_role is null
      or p_section_id is null
      or not exists (
        select 1 from public.section_role_assignments role_row
        where role_row.section_id = p_section_id
          and role_row.society_member_id = member_row.id
          and role_row.role = p_exclude_active_role
          and role_row.status = 'ACTIVE'
      )
    );

  return v_result;
end;
$$;

revoke all on function public.auth_manage_section(text, jsonb)
  from public, anon;
grant execute on function public.auth_manage_section(text, jsonb)
  to authenticated;
revoke all on function public.auth_search_society_members(
  uuid, text, uuid, boolean, text
) from public, anon;
grant execute on function public.auth_search_society_members(
  uuid, text, uuid, boolean, text
) to authenticated;

select pg_notify('pgrst', 'reload schema');
commit;

select
  to_regprocedure('public.auth_manage_section(text,jsonb)')
    as section_management_function,
  has_function_privilege(
    'authenticated',
    'public.auth_manage_section(text,jsonb)',
    'EXECUTE'
  ) as authenticated_execute,
  has_function_privilege(
    'anon',
    'public.auth_manage_section(text,jsonb)',
    'EXECUTE'
  ) as anon_execute;
