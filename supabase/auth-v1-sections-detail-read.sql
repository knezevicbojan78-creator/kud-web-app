begin;

create or replace function public.auth_get_section_detail(
  p_section_id uuid
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
  v_can_view_guardians boolean := false;
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception 'Prijava je obavezna.';
  end if;

  select section.society_id
  into v_society_id
  from public.sections section
  where section.id = p_section_id;

  if v_society_id is null then
    raise exception 'Sekcija nije pronadjena.';
  end if;

  select member.id, member.person_id
  into v_actor_member_id, v_actor_person_id
  from public.society_members member
  join public.people person on person.id = member.person_id
  where member.society_id = v_society_id
    and member.status = 'ACTIVE'
    and coalesce(member.user_id, person.user_id) = v_user_id
  order by member.id
  limit 1;

  if v_actor_member_id is null or not public.permissions_can_access_section(
    v_society_id, v_actor_member_id, v_actor_person_id,
    p_section_id, 'sections.view'
  ) then
    raise exception 'Nemate dozvolu za pregled ove sekcije.';
  end if;

  v_can_view_guardians := public.permissions_can_access_section(
    v_society_id, v_actor_member_id, v_actor_person_id,
    p_section_id, 'sections.manage_members'
  );

  select jsonb_build_object(
    'members', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'memberSectionId', member_section.id,
          'societyMemberId', society_member.id,
          'personId', person.id,
          'name', concat_ws(' ', person.first_name, person.last_name),
          'email', person.email,
          'phone', person.phone,
          'status', member_section.status,
          'guardians', case when v_can_view_guardians then coalesce((
            select jsonb_agg(
              jsonb_build_object(
                'name', concat_ws(' ', guardian_person.first_name, guardian_person.last_name),
                'email', guardian_person.email,
                'phone', guardian_person.phone
              )
              order by guardian_person.last_name, guardian_person.first_name
            )
            from public.person_guardians guardian
            join public.people guardian_person
              on guardian_person.id = guardian.guardian_person_id
            where guardian.child_person_id = person.id
          ), '[]'::jsonb) else '[]'::jsonb end
        )
        order by member_section.created_at
      )
      from public.member_sections member_section
      join public.society_members society_member
        on society_member.id = member_section.society_member_id
      join public.people person on person.id = society_member.person_id
      where member_section.section_id = p_section_id
        and member_section.status = 'ACTIVE'
        and society_member.society_id = v_society_id
    ), '[]'::jsonb),
    'accompanists', coalesce((
      select jsonb_agg(
        to_jsonb(accompanist) || jsonb_build_object(
          'name', concat_ws(' ', person.first_name, person.last_name),
          'email', person.email,
          'phone', person.phone
        )
        order by person.last_name, person.first_name
      )
      from public.section_accompanists accompanist
      join public.people person on person.id = accompanist.person_id
      where accompanist.section_id = p_section_id
        and accompanist.society_id = v_society_id
        and accompanist.status = 'ACTIVE'
    ), '[]'::jsonb),
    'repertoire', coalesce((
      select jsonb_agg(to_jsonb(item) order by item.name)
      from public.repertoire_item_sections link
      join public.repertoire_items item on item.id = link.repertoire_item_id
      where link.section_id = p_section_id
        and item.society_id = v_society_id
    ), '[]'::jsonb)
  )
  into v_result;

  return v_result;
end;
$$;

revoke all on function public.auth_get_section_detail(uuid)
  from public, anon, authenticated;
grant execute on function public.auth_get_section_detail(uuid)
  to authenticated;

commit;
