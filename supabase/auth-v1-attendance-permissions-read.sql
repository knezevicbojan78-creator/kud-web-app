-- FOLKLORAS — AUTH V1 / PRISUSTVO / RADNI PROSTOR

begin;

create or replace function public.auth_get_attendance_workspace(
  p_society_id uuid,
  p_section_id uuid default null
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
  v_session_id uuid;
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

  if p_section_id is not null and not public.permissions_can_access_section(
    p_society_id, v_actor_member_id, v_actor_person_id,
    p_section_id, 'attendance.view'
  ) then
    raise exception 'Nemate dozvolu za pregled prisustva ove sekcije.';
  end if;

  if p_section_id is not null then
    select session.id
    into v_session_id
    from public.attendance_sessions session
    where session.society_id = p_society_id
      and session.section_id = p_section_id
      and session.status = 'OPEN'
    order by session.opened_at desc
    limit 1;
  end if;

  select jsonb_build_object(
    'society', to_jsonb(society),
    'actor_society_member_id', v_actor_member_id,
    'sections', coalesce((
      select jsonb_agg(
        to_jsonb(section) || jsonb_build_object(
          'access', jsonb_build_object(
            'can_open', public.permissions_can_access_section(
              p_society_id, v_actor_member_id, v_actor_person_id,
              section.id, 'attendance.open'
            ),
            'can_record_open', public.permissions_can_access_section(
              p_society_id, v_actor_member_id, v_actor_person_id,
              section.id, 'attendance.record_open'
            ),
            'can_close', public.permissions_can_access_section(
              p_society_id, v_actor_member_id, v_actor_person_id,
              section.id, 'attendance.close'
            ),
            'can_cancel', public.permissions_can_access_section(
              p_society_id, v_actor_member_id, v_actor_person_id,
              section.id, 'attendance.cancel_open'
            ),
            'can_edit_closed', public.permissions_can_access_section(
              p_society_id, v_actor_member_id, v_actor_person_id,
              section.id, 'attendance.edit_closed'
            )
          )
        )
        order by section.name
      )
      from public.sections section
      where section.society_id = p_society_id
        and section.status = 'ACTIVE'
        and public.permissions_can_access_section(
          p_society_id, v_actor_member_id, v_actor_person_id,
          section.id, 'attendance.view'
        )
    ), '[]'::jsonb),
    'session', (
      select to_jsonb(session)
      from public.attendance_sessions session
      where session.id = v_session_id
    ),
    'members', coalesce((
      select jsonb_agg(
        to_jsonb(record) || jsonb_build_object(
          'name', concat_ws(' ', person.first_name, person.last_name),
          'gender', person.gender,
          'participantType', record.participant_type,
          'roleLabel', record.role_label
        )
        order by person.last_name, person.first_name
      )
      from public.attendance_records record
      join public.people person on person.id = record.person_id
      where record.attendance_session_id = v_session_id
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

create or replace function public.auth_get_attendance_history(
  p_society_id uuid,
  p_section_id uuid default null,
  p_status text default 'ALL',
  p_date_from date default null,
  p_date_to date default null,
  p_session_id uuid default null
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
  if p_status not in ('ALL', 'CLOSED', 'CANCELLED') then
    raise exception 'Filter statusa nije ispravan.';
  end if;

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

  if p_session_id is not null and not exists (
    select 1
    from public.attendance_sessions target_session
    where target_session.id = p_session_id
      and target_session.society_id = p_society_id
      and public.permissions_can_access_section(
        p_society_id, v_actor_member_id, v_actor_person_id,
        target_session.section_id, 'attendance.view'
      )
  ) then
    raise exception 'Nemate dozvolu za pregled izabrane probe.';
  end if;

  select jsonb_build_object(
    'sections', coalesce((
      select jsonb_agg(to_jsonb(section) order by section.name)
      from public.sections section
      where section.society_id = p_society_id
        and public.permissions_can_access_section(
          p_society_id, v_actor_member_id, v_actor_person_id,
          section.id, 'attendance.view'
        )
    ), '[]'::jsonb),
    'sessions', coalesce((
      select jsonb_agg(
        to_jsonb(session) || jsonb_build_object(
          'sectionName', section.name,
          'presentCount', (
            select count(*) from public.attendance_records record
            where record.attendance_session_id = session.id
              and record.participant_type = 'MEMBER'
              and record.status = 'PRESENT'
          ),
          'absentCount', (
            select count(*) from public.attendance_records record
            where record.attendance_session_id = session.id
              and record.participant_type = 'MEMBER'
              and record.status <> 'PRESENT'
          ),
          'accompanistPresentCount', (
            select count(*) from public.attendance_records record
            where record.attendance_session_id = session.id
              and record.participant_type = 'ACCOMPANIST'
              and record.status = 'PRESENT'
          ),
          'accompanistAbsentCount', (
            select count(*) from public.attendance_records record
            where record.attendance_session_id = session.id
              and record.participant_type = 'ACCOMPANIST'
              and record.status <> 'PRESENT'
          )
        )
        order by session.opened_at desc
      )
      from public.attendance_sessions session
      join public.sections section on section.id = session.section_id
      where session.society_id = p_society_id
        and session.status <> 'OPEN'
        and (p_section_id is null or session.section_id = p_section_id)
        and (p_status = 'ALL' or session.status = p_status)
        and (p_date_from is null or session.opened_at >= p_date_from::timestamptz)
        and (p_date_to is null or session.opened_at < (p_date_to + 1)::timestamptz)
        and public.permissions_can_access_section(
          p_society_id, v_actor_member_id, v_actor_person_id,
          session.section_id, 'attendance.view'
        )
      limit 200
    ), '[]'::jsonb),
    'detail_members', case when p_session_id is null then '[]'::jsonb else coalesce((
      select jsonb_agg(
        to_jsonb(record) || jsonb_build_object(
          'name', concat_ws(' ', person.first_name, person.last_name),
          'participantType', record.participant_type,
          'roleLabel', record.role_label
        )
        order by person.last_name, person.first_name
      )
      from public.attendance_records record
      join public.people person on person.id = record.person_id
      where record.attendance_session_id = p_session_id
    ), '[]'::jsonb) end,
    'can_edit_detail', case when p_session_id is null then false else exists (
      select 1
      from public.attendance_sessions target_session
      where target_session.id = p_session_id
        and target_session.status = 'CLOSED'
        and public.permissions_can_access_section(
          p_society_id, v_actor_member_id, v_actor_person_id,
          target_session.section_id, 'attendance.edit_closed'
        )
    ) end
  )
  into v_result;

  return v_result;
end;
$$;

revoke all on function public.auth_get_attendance_workspace(uuid,uuid)
  from public, anon;
grant execute on function public.auth_get_attendance_workspace(uuid,uuid)
  to authenticated;
revoke all on function public.auth_get_attendance_history(uuid,uuid,text,date,date,uuid)
  from public, anon;
grant execute on function public.auth_get_attendance_history(uuid,uuid,text,date,date,uuid)
  to authenticated;

commit;
