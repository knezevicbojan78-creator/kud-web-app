-- FOLKLORAS — AUTH V1 / SEKCIJE / DOZVOLE ZA RADNI PROSTOR

begin;

create or replace function public.permissions_can_access_section(
  p_society_id uuid,
  p_actor_member_id uuid,
  p_actor_person_id uuid,
  p_section_id uuid,
  p_permission_key text
) returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.sections section
    join public.permissions_get_effective_rules(
      p_society_id, p_actor_member_id, p_actor_person_id
    ) permission on permission.permission_key = p_permission_key
    where section.id = p_section_id
      and section.society_id = p_society_id
      and (
        permission.scope_key = 'SOCIETY'
        or (
          permission.scope_key in ('ASSIGNED_SECTIONS', 'SELF_ASSIGNED_SECTIONS')
          and exists (
            select 1 from public.section_role_assignments actor_role
            where actor_role.society_id = p_society_id
              and actor_role.section_id = section.id
              and actor_role.society_member_id = p_actor_member_id
              and actor_role.status = 'ACTIVE'
          )
        )
        or (
          permission.scope_key = 'MEMBER_SECTIONS'
          and exists (
            select 1 from public.member_sections membership
            where membership.society_id = p_society_id
              and membership.section_id = section.id
              and membership.society_member_id = p_actor_member_id
              and membership.status = 'ACTIVE'
          )
        )
        or (
          permission.scope_key = 'CHILDREN'
          and exists (
            select 1
            from public.person_guardians guardian
            join public.society_members child_member
              on child_member.person_id = guardian.child_person_id
             and child_member.society_id = p_society_id
             and child_member.status = 'ACTIVE'
            join public.member_sections child_section
              on child_section.society_member_id = child_member.id
             and child_section.society_id = p_society_id
             and child_section.section_id = section.id
             and child_section.status = 'ACTIVE'
            where guardian.guardian_person_id = p_actor_person_id
          )
        )
      )
  );
$$;

create or replace function public.auth_get_sections_workspace(
  p_society_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_actor_member_id uuid;
  v_actor_person_id uuid;
  v_result jsonb;
begin
  if v_user_id is null then raise exception 'Prijava je obavezna.'; end if;

  select member.id, member.person_id
  into v_actor_member_id, v_actor_person_id
  from public.society_members member
  join public.people person on person.id = member.person_id
  where member.society_id = p_society_id
    and member.status = 'ACTIVE'
    and coalesce(member.user_id, person.user_id) = v_user_id
  order by member.id
  limit 1;

  if v_actor_member_id is null then
    raise exception 'Korisnik nema aktivno clanstvo u izabranom drustvu.';
  end if;

  if not exists (
    select 1
    from public.permissions_get_effective_rules(
      p_society_id, v_actor_member_id, v_actor_person_id
    ) permission
    where permission.permission_key = 'sections.view'
  ) then
    raise exception 'Nemate dozvolu za pregled sekcija.';
  end if;

  select jsonb_build_object(
    'society', to_jsonb(society),
    'actor_society_member_id', v_actor_member_id,
    'access', jsonb_build_object(
      'can_create', public.permissions_has_scope(
        p_society_id, v_actor_member_id, v_actor_person_id,
        'sections.create', array['SOCIETY']::text[]
      ),
      'can_change_status', public.permissions_has_scope(
        p_society_id, v_actor_member_id, v_actor_person_id,
        'sections.change_status', array['SOCIETY']::text[]
      ),
      'can_manage_roles', public.permissions_has_scope(
        p_society_id, v_actor_member_id, v_actor_person_id,
        'sections.manage_roles', array['SOCIETY']::text[]
      )
    ),
    'sections', coalesce((
      select jsonb_agg(
        to_jsonb(section) || jsonb_build_object(
          'access', jsonb_build_object(
            'can_edit', public.permissions_can_access_section(
              p_society_id, v_actor_member_id, v_actor_person_id,
              section.id, 'sections.edit'
            ),
            'can_manage_members', public.permissions_can_access_section(
              p_society_id, v_actor_member_id, v_actor_person_id,
              section.id, 'sections.manage_members'
            ),
            'can_manage_roles', public.permissions_can_access_section(
              p_society_id, v_actor_member_id, v_actor_person_id,
              section.id, 'sections.manage_roles'
            ),
            'can_manage_repertoire', (
              public.permissions_can_access_section(
                p_society_id, v_actor_member_id, v_actor_person_id,
                section.id, 'repertoire.create'
              )
              or public.permissions_can_access_section(
                p_society_id, v_actor_member_id, v_actor_person_id,
                section.id, 'repertoire.change_status'
              )
            ),
            'can_manage_accompanists', public.permissions_can_access_section(
              p_society_id, v_actor_member_id, v_actor_person_id,
              section.id, 'sections.manage_accompanists'
            )
          ),
          'roles', case when public.permissions_can_access_section(
            p_society_id, v_actor_member_id, v_actor_person_id,
            section.id, 'sections.view_roles'
          ) then coalesce((
            select jsonb_agg(
              to_jsonb(role_assignment) || jsonb_build_object(
                'memberName', concat_ws(' ', person.first_name, person.last_name),
                'email', person.email,
                'phone', person.phone
              )
              order by role_assignment.role, person.last_name, person.first_name
            )
            from public.section_role_assignments role_assignment
            join public.society_members role_member on role_member.id = role_assignment.society_member_id
            join public.people person on person.id = role_member.person_id
            where role_assignment.section_id = section.id
          ), '[]'::jsonb) else '[]'::jsonb end
        )
        order by section.name
      )
      from public.sections section
      where section.society_id = p_society_id
        and public.permissions_can_access_section(
          p_society_id, v_actor_member_id, v_actor_person_id,
          section.id, 'sections.view'
        )
    ), '[]'::jsonb)
  )
  into v_result
  from public.societies society
  where society.id = p_society_id
    and society.status in ('ACTIVE', 'SUSPENDED');

  if v_result is null then raise exception 'Izabrano drustvo nije dostupno.'; end if;
  return v_result;
end;
$$;

revoke all on function public.permissions_can_access_section(uuid,uuid,uuid,uuid,text)
  from public, anon, authenticated;
revoke all on function public.auth_get_sections_workspace(uuid) from public, anon;
grant execute on function public.auth_get_sections_workspace(uuid) to authenticated;

commit;
