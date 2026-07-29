-- FOLKLORAS — AUTH V1 / CLANOVI / DOZVOLE ZA CITANJE LISTE

begin;

create or replace function public.permissions_can_access_member(
  p_society_id uuid,
  p_actor_member_id uuid,
  p_actor_person_id uuid,
  p_target_member_id uuid,
  p_permission_key text
) returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.society_members target
    join public.permissions_get_effective_rules(
      p_society_id, p_actor_member_id, p_actor_person_id
    ) permission on permission.permission_key = p_permission_key
    where target.id = p_target_member_id
      and target.society_id = p_society_id
      and (
        permission.scope_key = 'SOCIETY'
        or (permission.scope_key = 'SELF' and target.id = p_actor_member_id)
        or (
          permission.scope_key = 'CHILDREN'
          and exists (
            select 1 from public.person_guardians guardian
            where guardian.guardian_person_id = p_actor_person_id
              and guardian.child_person_id = target.person_id
          )
        )
        or (
          permission.scope_key = 'ASSIGNED_SECTIONS'
          and exists (
            select 1
            from public.member_sections target_section
            join public.section_role_assignments actor_role
              on actor_role.section_id = target_section.section_id
             and actor_role.society_id = target_section.society_id
             and actor_role.society_member_id = p_actor_member_id
             and actor_role.status = 'ACTIVE'
            where target_section.society_id = p_society_id
              and target_section.society_member_id = target.id
              and target_section.status = 'ACTIVE'
          )
        )
      )
  );
$$;

create or replace function public.auth_get_members_page()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_society_id uuid;
  v_actor_member_id uuid;
  v_actor_person_id uuid;
  v_result jsonb;
begin
  if v_user_id is null then raise exception 'Prijava je obavezna.'; end if;

  select member.society_id, member.id, member.person_id
  into v_society_id, v_actor_member_id, v_actor_person_id
  from public.society_members member
  join public.people person on person.id = member.person_id
  join public.societies society on society.id = member.society_id and society.status = 'ACTIVE'
  where member.status = 'ACTIVE'
    and coalesce(member.user_id, person.user_id) = v_user_id
  order by member.id
  limit 1;

  if v_actor_member_id is null then
    raise exception 'Aktivno clanstvo prijavljenog korisnika nije pronadjeno.';
  end if;

  if not exists (
    select 1
    from public.permissions_get_effective_rules(v_society_id, v_actor_member_id, v_actor_person_id) permission
    where permission.permission_key = 'members.view_basic'
  ) then
    raise exception 'Nemate dozvolu za pregled clanova.';
  end if;

  with effective as materialized (
    select *
    from public.permissions_get_effective_rules(v_society_id, v_actor_member_id, v_actor_person_id)
  ),
  visible_members as materialized (
    select target.id, target.person_id
    from public.society_members target
    where target.society_id = v_society_id
      and exists (
        select 1 from effective permission
        where permission.permission_key = 'members.view_basic'
          and (
            permission.scope_key = 'SOCIETY'
            or (permission.scope_key = 'SELF' and target.id = v_actor_member_id)
            or (
              permission.scope_key = 'CHILDREN'
              and exists (
                select 1 from public.person_guardians guardian
                where guardian.guardian_person_id = v_actor_person_id
                  and guardian.child_person_id = target.person_id
              )
            )
            or (
              permission.scope_key = 'ASSIGNED_SECTIONS'
              and exists (
                select 1
                from public.member_sections target_section
                join public.section_role_assignments actor_role
                  on actor_role.section_id = target_section.section_id
                 and actor_role.society_id = target_section.society_id
                 and actor_role.society_member_id = v_actor_member_id
                 and actor_role.status = 'ACTIVE'
                where target_section.society_id = v_society_id
                  and target_section.society_member_id = target.id
                  and target_section.status = 'ACTIVE'
              )
            )
          )
      )
  )
  select jsonb_build_object(
    'society', to_jsonb(society),
    'access', jsonb_build_object(
      'can_create', exists (
        select 1 from effective permission
        where permission.permission_key = 'members.create'
          and permission.scope_key = 'SOCIETY'
      ),
      'can_manage_functions', exists (
        select 1 from effective permission
        where permission.permission_key = 'permissions.manage'
          and permission.scope_key = 'SOCIETY'
      ),
      'can_manage_sections', exists (
        select 1 from effective permission
        where permission.permission_key = 'members.manage_sections'
      )
    ),
    'functions', case when exists (
      select 1 from effective permission
      where permission.permission_key = 'permissions.manage'
        and permission.scope_key = 'SOCIETY'
    ) then coalesce((
      select jsonb_agg(to_jsonb(member_function) order by member_function.sort_order)
      from public.society_member_functions member_function
      where member_function.society_id = v_society_id and member_function.is_active
    ), '[]'::jsonb) else '[]'::jsonb end,
    'sections', coalesce((
      select jsonb_agg(to_jsonb(section) order by section.name)
      from public.sections section
      where section.society_id = v_society_id
        and section.status = 'ACTIVE'
        and (
          exists (select 1 from effective permission where permission.permission_key = 'members.manage_sections' and permission.scope_key = 'SOCIETY')
          or exists (
            select 1
            from public.section_role_assignments actor_role
            where actor_role.society_id = v_society_id
              and actor_role.section_id = section.id
              and actor_role.society_member_id = v_actor_member_id
              and actor_role.status = 'ACTIVE'
          )
        )
    ), '[]'::jsonb),
    'members', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', member.id,
          'person_id', member.person_id,
          'first_name', person.first_name,
          'last_name', person.last_name,
          'birth_date', case when exists (
            select 1 from effective permission
            where permission.permission_key = 'members.view_sensitive'
              and (
                permission.scope_key = 'SOCIETY'
                or (permission.scope_key = 'SELF' and member.id = v_actor_member_id)
                or (permission.scope_key = 'CHILDREN' and exists (
                  select 1 from public.person_guardians guardian
                  where guardian.guardian_person_id = v_actor_person_id
                    and guardian.child_person_id = member.person_id
                ))
                or (permission.scope_key = 'ASSIGNED_SECTIONS' and exists (
                  select 1 from public.member_sections target_section
                  join public.section_role_assignments actor_role
                    on actor_role.section_id = target_section.section_id
                   and actor_role.society_member_id = v_actor_member_id
                   and actor_role.status = 'ACTIVE'
                  where target_section.society_member_id = member.id
                    and target_section.society_id = v_society_id
                    and target_section.status = 'ACTIVE'
                ))
              )
          ) then person.birth_date else null end,
          'email', person.email,
          'phone', person.phone,
          'status', member.status,
          'start_date', member.start_date
        )
        order by person.last_name, person.first_name
      )
      from visible_members visible
      join public.society_members member on member.id = visible.id
      join public.people person on person.id = visible.person_id
    ), '[]'::jsonb)
  )
  into v_result
  from public.societies society
  where society.id = v_society_id;

  return v_result;
end;
$$;

create or replace function public.auth_get_member_detail(
  p_society_member_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_society_id uuid;
  v_actor_member_id uuid;
  v_actor_person_id uuid;
  v_target_person_id uuid;
  v_result jsonb;
  v_can_view_basic boolean := false;
  v_can_view_sensitive boolean := false;
  v_can_view_guardians boolean := false;
  v_can_view_sections boolean := false;
  v_can_edit_basic boolean := false;
  v_can_edit_sensitive boolean := false;
  v_can_change_status boolean := false;
  v_can_manage_guardians boolean := false;
  v_can_manage_sections boolean := false;
  v_can_manage_functions boolean := false;
begin
  if v_user_id is null then raise exception 'Prijava je obavezna.'; end if;

  select member.society_id, member.id, member.person_id
  into v_society_id, v_actor_member_id, v_actor_person_id
  from public.society_members member
  join public.people person on person.id = member.person_id
  join public.societies society on society.id = member.society_id and society.status = 'ACTIVE'
  where member.status = 'ACTIVE'
    and coalesce(member.user_id, person.user_id) = v_user_id
  order by member.id
  limit 1;

  select target.person_id
  into v_target_person_id
  from public.society_members target
  where target.id = p_society_member_id
    and target.society_id = v_society_id;

  if v_target_person_id is null then raise exception 'Clan nije pronadjen.'; end if;

  with effective as materialized (
    select *
    from public.permissions_get_effective_rules(v_society_id, v_actor_member_id, v_actor_person_id)
  ),
  matched as (
    select permission.permission_key
    from effective permission
    where
      permission.scope_key = 'SOCIETY'
      or (permission.scope_key = 'SELF' and p_society_member_id = v_actor_member_id)
      or (
        permission.scope_key = 'CHILDREN'
        and exists (
          select 1 from public.person_guardians guardian
          where guardian.guardian_person_id = v_actor_person_id
            and guardian.child_person_id = v_target_person_id
        )
      )
      or (
        permission.scope_key = 'ASSIGNED_SECTIONS'
        and exists (
          select 1
          from public.member_sections target_section
          join public.section_role_assignments actor_role
            on actor_role.section_id = target_section.section_id
           and actor_role.society_id = target_section.society_id
           and actor_role.society_member_id = v_actor_member_id
           and actor_role.status = 'ACTIVE'
          where target_section.society_id = v_society_id
            and target_section.society_member_id = p_society_member_id
            and target_section.status = 'ACTIVE'
        )
      )
  )
  select
    bool_or(permission_key = 'members.view_basic'),
    bool_or(permission_key = 'members.view_sensitive'),
    bool_or(permission_key = 'members.view_guardians'),
    bool_or(permission_key = 'members.view_sections'),
    bool_or(permission_key = 'members.edit_basic'),
    bool_or(permission_key = 'members.edit_sensitive'),
    bool_or(permission_key = 'members.change_status'),
    bool_or(permission_key = 'members.manage_guardians'),
    bool_or(permission_key = 'members.manage_sections'),
    bool_or(permission_key = 'permissions.manage')
  into
    v_can_view_basic, v_can_view_sensitive, v_can_view_guardians,
    v_can_view_sections, v_can_edit_basic, v_can_edit_sensitive,
    v_can_change_status, v_can_manage_guardians, v_can_manage_sections,
    v_can_manage_functions
  from matched;

  if not coalesce(v_can_view_basic, false) then
    raise exception 'Nemate dozvolu za pregled ovog clana.';
  end if;

  select jsonb_build_object(
    'member', to_jsonb(member),
    'person', case when v_can_view_sensitive
      then to_jsonb(person)
      else to_jsonb(person) - array[
        'gender', 'birth_date', 'address', 'city', 'postal_code', 'country',
        'jmbg', 'passport_number', 'passport_expiry_date',
        'parental_travel_consent', 'parental_travel_consent_valid_until'
      ]::text[]
    end,
    'guardians', case when v_can_view_guardians then coalesce((
      select jsonb_agg(jsonb_build_object('link', to_jsonb(link), 'person', to_jsonb(guardian_person))
        order by link.is_primary desc, link.created_at)
      from public.person_guardians link
      join public.people guardian_person on guardian_person.id = link.guardian_person_id
      where link.child_person_id = person.id
    ), '[]'::jsonb) else '[]'::jsonb end,
    'function_ids', case when v_can_manage_functions then coalesce((
      select jsonb_agg(assignment.function_id)
      from public.society_member_function_assignments assignment
      where assignment.society_member_id = member.id
        and assignment.society_id = v_society_id
    ), '[]'::jsonb) else '[]'::jsonb end,
    'section_ids', case when v_can_view_sections or v_can_manage_sections then coalesce((
      select jsonb_agg(member_section.section_id)
      from public.member_sections member_section
      where member_section.society_member_id = member.id
        and member_section.society_id = v_society_id
        and member_section.status = 'ACTIVE'
    ), '[]'::jsonb) else '[]'::jsonb end,
    'access', jsonb_build_object(
      'can_view_sensitive', v_can_view_sensitive,
      'can_view_guardians', v_can_view_guardians,
      'can_edit_basic', v_can_edit_basic,
      'can_edit_sensitive', v_can_edit_sensitive,
      'can_change_status', v_can_change_status,
      'can_manage_guardians', v_can_manage_guardians,
      'can_manage_sections', v_can_manage_sections,
      'can_manage_functions', v_can_manage_functions
    )
  )
  into v_result
  from public.society_members member
  join public.people person on person.id = member.person_id
  where member.id = p_society_member_id
    and member.society_id = v_society_id;

  return v_result;
end;
$$;

revoke all on function public.auth_get_members_page() from public, anon;
grant execute on function public.auth_get_members_page() to authenticated;
revoke all on function public.permissions_can_access_member(uuid, uuid, uuid, uuid, text)
  from public, anon, authenticated;
revoke all on function public.auth_get_member_detail(uuid) from public, anon;
grant execute on function public.auth_get_member_detail(uuid) to authenticated;

commit;
