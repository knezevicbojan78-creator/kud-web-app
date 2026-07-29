-- FOLKLORAS — AUTH V1 / GUARDIAN ACCESS THROUGH EXISTING PAGES
-- Dedicated read-only RPCs keep parent data scoped to linked children.
begin;

create or replace function public.auth_guardian_person_for_society(p_society_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare v_person_id uuid;
begin
  if auth.uid() is null then raise exception 'Prijava je obavezna.'; end if;
  select guardian.id into v_person_id
  from public.people guardian
  where guardian.user_id = auth.uid()
    and exists (
      select 1
      from public.person_guardians link
      join public.society_members child_member
        on child_member.person_id = link.child_person_id
       and child_member.society_id = p_society_id
       and child_member.status = 'ACTIVE'
      where link.guardian_person_id = guardian.id
    )
  order by guardian.id
  limit 1;
  if v_person_id is null then
    raise exception 'Nemate potvrđenu roditeljsku vezu u izabranom društvu.';
  end if;
  return v_person_id;
end;
$$;

create or replace function public.auth_get_guardian_sections_workspace(p_society_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_guardian_id uuid := public.auth_guardian_person_for_society(p_society_id);
  v_result jsonb;
begin
  select jsonb_build_object(
    'society', to_jsonb(society),
    'actor_society_member_id', null,
    'access', jsonb_build_object(
      'can_create', false, 'can_change_status', false, 'can_manage_roles', false
    ),
    'sections', coalesce((
      select jsonb_agg(
        to_jsonb(section) || jsonb_build_object(
          'access', jsonb_build_object(
            'can_edit', false, 'can_manage_members', false,
            'can_manage_roles', false, 'can_manage_repertoire', false,
            'can_manage_accompanists', false
          ),
          'roles', coalesce((
            select jsonb_agg(
              to_jsonb(role_assignment) || jsonb_build_object(
                'memberName', concat_ws(' ', role_person.first_name, role_person.last_name),
                'email', null, 'phone', null
              )
              order by role_assignment.role, role_person.last_name, role_person.first_name
            )
            from public.section_role_assignments role_assignment
            join public.society_members role_member on role_member.id = role_assignment.society_member_id
            join public.people role_person on role_person.id = role_member.person_id
            where role_assignment.section_id = section.id
              and role_assignment.status = 'ACTIVE'
          ), '[]'::jsonb)
        )
        order by section.name
      )
      from public.sections section
      where section.society_id = p_society_id
        and section.status = 'ACTIVE'
        and exists (
          select 1
          from public.person_guardians link
          join public.society_members child_member
            on child_member.person_id = link.child_person_id
           and child_member.society_id = p_society_id
           and child_member.status = 'ACTIVE'
          join public.member_sections child_section
            on child_section.society_member_id = child_member.id
           and child_section.section_id = section.id
           and child_section.status = 'ACTIVE'
          where link.guardian_person_id = v_guardian_id
        )
    ), '[]'::jsonb)
  ) into v_result
  from public.societies society
  where society.id = p_society_id and society.status in ('ACTIVE', 'SUSPENDED');
  if v_result is null then raise exception 'Izabrano društvo nije dostupno.'; end if;
  return v_result;
end;
$$;

create or replace function public.auth_get_guardian_section_detail(p_section_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_society_id uuid;
  v_guardian_id uuid;
begin
  select society_id into v_society_id from public.sections where id = p_section_id;
  if v_society_id is null then raise exception 'Sekcija nije pronađena.'; end if;
  v_guardian_id := public.auth_guardian_person_for_society(v_society_id);
  if not exists (
    select 1 from public.person_guardians link
    join public.society_members child_member
      on child_member.person_id = link.child_person_id
     and child_member.society_id = v_society_id and child_member.status = 'ACTIVE'
    join public.member_sections child_section
      on child_section.society_member_id = child_member.id
     and child_section.section_id = p_section_id and child_section.status = 'ACTIVE'
    where link.guardian_person_id = v_guardian_id
  ) then raise exception 'Nemate pristup ovoj sekciji.'; end if;

  return jsonb_build_object(
    'members', coalesce((
      select jsonb_agg(jsonb_build_object(
        'memberSectionId', child_section.id,
        'societyMemberId', child_member.id,
        'personId', child.id,
        'name', concat_ws(' ', child.first_name, child.last_name),
        'email', child.email, 'phone', child.phone,
        'status', child_section.status, 'guardians', '[]'::jsonb
      ) order by child.last_name, child.first_name)
      from public.person_guardians link
      join public.people child on child.id = link.child_person_id
      join public.society_members child_member
        on child_member.person_id = child.id
       and child_member.society_id = v_society_id and child_member.status = 'ACTIVE'
      join public.member_sections child_section
        on child_section.society_member_id = child_member.id
       and child_section.section_id = p_section_id and child_section.status = 'ACTIVE'
      where link.guardian_person_id = v_guardian_id
    ), '[]'::jsonb),
    'accompanists', coalesce((
      select jsonb_agg(to_jsonb(accompanist) || jsonb_build_object(
        'name', concat_ws(' ', person.first_name, person.last_name),
        'email', null, 'phone', null
      ) order by person.last_name, person.first_name)
      from public.section_accompanists accompanist
      join public.people person on person.id = accompanist.person_id
      where accompanist.section_id = p_section_id and accompanist.status = 'ACTIVE'
    ), '[]'::jsonb),
    'repertoire', coalesce((
      select jsonb_agg(to_jsonb(item) order by item.name)
      from public.repertoire_item_sections item_section
      join public.repertoire_items item on item.id = item_section.repertoire_item_id
      where item_section.section_id = p_section_id and item.status = 'ACTIVE'
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.auth_get_guardian_attendance_workspace(
  p_society_id uuid, p_section_id uuid default null
) returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_guardian_id uuid := public.auth_guardian_person_for_society(p_society_id);
  v_session_id uuid;
  v_result jsonb;
begin
  if p_section_id is not null and not exists (
    select 1 from public.person_guardians link
    join public.society_members child_member
      on child_member.person_id = link.child_person_id
     and child_member.society_id = p_society_id and child_member.status = 'ACTIVE'
    join public.member_sections child_section
      on child_section.society_member_id = child_member.id
     and child_section.section_id = p_section_id and child_section.status = 'ACTIVE'
    where link.guardian_person_id = v_guardian_id
  ) then raise exception 'Nemate pristup prisustvu ove sekcije.'; end if;

  if p_section_id is not null then
    select id into v_session_id from public.attendance_sessions
    where society_id = p_society_id and section_id = p_section_id and status = 'OPEN'
    order by opened_at desc limit 1;
  end if;

  select jsonb_build_object(
    'society', to_jsonb(society), 'actor_society_member_id', null,
    'sections', coalesce((
      select jsonb_agg(to_jsonb(section) || jsonb_build_object(
        'access', jsonb_build_object(
          'can_open', false, 'can_record_open', false, 'can_close', false,
          'can_cancel', false, 'can_edit_closed', false
        )
      ) order by section.name)
      from public.sections section
      where section.society_id = p_society_id and section.status = 'ACTIVE'
        and exists (
          select 1 from public.person_guardians link
          join public.society_members child_member
            on child_member.person_id = link.child_person_id
           and child_member.society_id = p_society_id and child_member.status = 'ACTIVE'
          join public.member_sections child_section
            on child_section.society_member_id = child_member.id
           and child_section.section_id = section.id and child_section.status = 'ACTIVE'
          where link.guardian_person_id = v_guardian_id
        )
    ), '[]'::jsonb),
    'session', (select to_jsonb(session) from public.attendance_sessions session
      where session.id = v_session_id),
    'members', coalesce((
      select jsonb_agg(to_jsonb(record) || jsonb_build_object(
        'name', concat_ws(' ', child.first_name, child.last_name),
        'gender', child.gender, 'participantType', record.participant_type,
        'roleLabel', record.role_label
      ) order by child.last_name, child.first_name)
      from public.attendance_records record
      join public.people child on child.id = record.person_id
      join public.person_guardians link
        on link.child_person_id = child.id and link.guardian_person_id = v_guardian_id
      where record.attendance_session_id = v_session_id
    ), '[]'::jsonb)
  ) into v_result
  from public.societies society
  where society.id = p_society_id and society.status in ('ACTIVE', 'SUSPENDED');
  if v_result is null then raise exception 'Izabrano društvo nije dostupno.'; end if;
  return v_result;
end;
$$;

create or replace function public.auth_get_guardian_attendance_history(
  p_society_id uuid, p_section_id uuid default null, p_status text default 'ALL',
  p_date_from date default null, p_date_to date default null,
  p_session_id uuid default null
) returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare v_guardian_id uuid := public.auth_guardian_person_for_society(p_society_id);
begin
  if p_status not in ('ALL', 'CLOSED', 'CANCELLED') then
    raise exception 'Filter statusa nije ispravan.';
  end if;
  if p_session_id is not null and not exists (
    select 1 from public.attendance_sessions session
    join public.attendance_records record on record.attendance_session_id = session.id
    join public.person_guardians link
      on link.child_person_id = record.person_id and link.guardian_person_id = v_guardian_id
    where session.id = p_session_id and session.society_id = p_society_id
  ) then raise exception 'Nemate pristup izabranoj probi.'; end if;

  return jsonb_build_object(
    'sections', coalesce((
      select jsonb_agg(to_jsonb(section) order by section.name)
      from public.sections section
      where section.society_id = p_society_id and exists (
        select 1 from public.person_guardians link
        join public.society_members child_member
          on child_member.person_id = link.child_person_id
         and child_member.society_id = p_society_id and child_member.status = 'ACTIVE'
        join public.member_sections child_section
          on child_section.society_member_id = child_member.id
         and child_section.section_id = section.id and child_section.status = 'ACTIVE'
        where link.guardian_person_id = v_guardian_id
      )
    ), '[]'::jsonb),
    'sessions', coalesce((
      select jsonb_agg(to_jsonb(session) || jsonb_build_object(
        'sectionName', section.name,
        'presentCount', (select count(*) from public.attendance_records record
          join public.person_guardians link on link.child_person_id = record.person_id
            and link.guardian_person_id = v_guardian_id
          where record.attendance_session_id = session.id and record.status = 'PRESENT'),
        'absentCount', (select count(*) from public.attendance_records record
          join public.person_guardians link on link.child_person_id = record.person_id
            and link.guardian_person_id = v_guardian_id
          where record.attendance_session_id = session.id and record.status <> 'PRESENT'),
        'accompanistPresentCount', 0, 'accompanistAbsentCount', 0
      ) order by session.opened_at desc)
      from public.attendance_sessions session
      join public.sections section on section.id = session.section_id
      where session.society_id = p_society_id and session.status <> 'OPEN'
        and (p_section_id is null or session.section_id = p_section_id)
        and (p_status = 'ALL' or session.status = p_status)
        and (p_date_from is null or session.opened_at >= p_date_from::timestamptz)
        and (p_date_to is null or session.opened_at < (p_date_to + 1)::timestamptz)
        and exists (
          select 1 from public.attendance_records record
          join public.person_guardians link on link.child_person_id = record.person_id
            and link.guardian_person_id = v_guardian_id
          where record.attendance_session_id = session.id
        )
      limit 200
    ), '[]'::jsonb),
    'detail_members', case when p_session_id is null then '[]'::jsonb else coalesce((
      select jsonb_agg(to_jsonb(record) || jsonb_build_object(
        'name', concat_ws(' ', child.first_name, child.last_name),
        'participantType', record.participant_type, 'roleLabel', record.role_label
      ) order by child.last_name, child.first_name)
      from public.attendance_records record
      join public.people child on child.id = record.person_id
      join public.person_guardians link
        on link.child_person_id = child.id and link.guardian_person_id = v_guardian_id
      where record.attendance_session_id = p_session_id
    ), '[]'::jsonb) end,
    'can_edit_detail', false
  );
end;
$$;

create or replace function public.auth_get_guardian_finance_workspace(p_society_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_guardian_id uuid := public.auth_guardian_person_for_society(p_society_id);
  v_result jsonb;
begin
  select jsonb_build_object(
    'society', to_jsonb(society), 'actor_society_member_id', null,
    'access', jsonb_build_object(
      'can_search_society', false, 'can_record_payment', false,
      'can_use_credit', false, 'can_view_audit', false,
      'can_record_refund', false, 'can_void_payment', false, 'can_void_refund', false
    ),
    'initial_entity', jsonb_build_object(
      'entity_type', 'GUARDIAN', 'entity_id', v_guardian_id,
      'display_name', concat_ws(' ', guardian.first_name, guardian.last_name),
      'subtitle', 'Finansije moje dece', 'related_count', (
        select count(distinct link.child_person_id)
        from public.person_guardians link
        join public.society_members child_member
          on child_member.person_id = link.child_person_id
         and child_member.society_id = p_society_id and child_member.status = 'ACTIVE'
        where link.guardian_person_id = v_guardian_id
      ), 'open_obligation_count', 0, 'overdue_obligation_count', 0
    )
  ) into v_result
  from public.societies society
  join public.people guardian on guardian.id = v_guardian_id
  where society.id = p_society_id and society.status in ('ACTIVE', 'SUSPENDED');
  return v_result;
end;
$$;

create or replace function public.auth_get_guardian_events_workspace(
  p_society_id uuid, p_event_id uuid default null
) returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_guardian_id uuid := public.auth_guardian_person_for_society(p_society_id);
  v_result jsonb;
begin
  if p_event_id is not null and not exists (
    select 1 from public.event_participants participant
    join public.person_guardians link
      on link.child_person_id = participant.person_id
     and link.guardian_person_id = v_guardian_id
    join public.society_events event_row on event_row.id = participant.event_id
    where participant.event_id = p_event_id and event_row.society_id = p_society_id
  ) then raise exception 'Nemate pristup izabranom događaju.'; end if;

  select jsonb_build_object(
    'society', to_jsonb(society), 'actor_society_member_id', null,
    'access', jsonb_build_object('can_create', false, 'can_manage_fee', false),
    'sections', coalesce((
      select jsonb_agg(to_jsonb(section) order by section.name)
      from public.sections section
      where section.society_id = p_society_id and section.status = 'ACTIVE'
        and exists (
          select 1 from public.person_guardians link
          join public.society_members child_member
            on child_member.person_id = link.child_person_id
           and child_member.society_id = p_society_id and child_member.status = 'ACTIVE'
          join public.member_sections child_section
            on child_section.society_member_id = child_member.id
           and child_section.section_id = section.id and child_section.status = 'ACTIVE'
          where link.guardian_person_id = v_guardian_id
        )
    ), '[]'::jsonb),
    'events', coalesce((
      select jsonb_agg(to_jsonb(event_row) || jsonb_build_object(
        'access', jsonb_build_object(
          'can_view_fees', true, 'can_edit_draft', false, 'can_submit', false,
          'can_review', false, 'can_edit_approved', false,
          'can_cancel_approved', false, 'can_manage_sections', false,
          'can_manage_participants', false, 'can_change_participant_status', false,
          'can_manage_fee', false, 'can_manage_program', false
        )
      ) order by event_row.created_at desc)
      from public.society_events event_row
      where event_row.society_id = p_society_id and exists (
        select 1 from public.event_participants participant
        join public.person_guardians link
          on link.child_person_id = participant.person_id
         and link.guardian_person_id = v_guardian_id
        where participant.event_id = event_row.id
      )
    ), '[]'::jsonb),
    'repertoire', coalesce((
      select jsonb_agg(distinct to_jsonb(item))
      from public.repertoire_items item
      join public.repertoire_item_sections item_section
        on item_section.repertoire_item_id = item.id
      join public.member_sections child_section
        on child_section.section_id = item_section.section_id and child_section.status = 'ACTIVE'
      join public.society_members child_member
        on child_member.id = child_section.society_member_id
       and child_member.society_id = p_society_id and child_member.status = 'ACTIVE'
      join public.person_guardians link
        on link.child_person_id = child_member.person_id
       and link.guardian_person_id = v_guardian_id
      where item.society_id = p_society_id and item.status = 'ACTIVE'
    ), '[]'::jsonb),
    'repertoire_section_links', coalesce((
      select jsonb_agg(distinct to_jsonb(item_section))
      from public.repertoire_item_sections item_section
      join public.repertoire_items item on item.id = item_section.repertoire_item_id
      join public.member_sections child_section
        on child_section.section_id = item_section.section_id and child_section.status = 'ACTIVE'
      join public.society_members child_member
        on child_member.id = child_section.society_member_id
       and child_member.society_id = p_society_id and child_member.status = 'ACTIVE'
      join public.person_guardians link
        on link.child_person_id = child_member.person_id
       and link.guardian_person_id = v_guardian_id
      where item.society_id = p_society_id
    ), '[]'::jsonb),
    'detail', case when p_event_id is null then null else jsonb_build_object(
      'event_sections', coalesce((
        select jsonb_agg(to_jsonb(event_section))
        from public.event_sections event_section where event_section.event_id = p_event_id
      ), '[]'::jsonb),
      'participants', coalesce((
        select jsonb_agg(to_jsonb(participant) || jsonb_build_object(
          'name', concat_ws(' ', child.first_name, child.last_name),
          'person', jsonb_build_object(
            'id', child.id, 'first_name', child.first_name,
            'last_name', child.last_name, 'gender', child.gender,
            'email', child.email, 'phone', child.phone
          )
        ) order by participant.created_at)
        from public.event_participants participant
        join public.people child on child.id = participant.person_id
        join public.person_guardians link
          on link.child_person_id = child.id and link.guardian_person_id = v_guardian_id
        where participant.event_id = p_event_id
      ), '[]'::jsonb),
      'participant_section_links', coalesce((
        select jsonb_agg(to_jsonb(participant_section))
        from public.event_participant_sections participant_section
        join public.event_participants participant
          on participant.id = participant_section.event_participant_id
        join public.person_guardians link
          on link.child_person_id = participant.person_id
         and link.guardian_person_id = v_guardian_id
        where participant.event_id = p_event_id
      ), '[]'::jsonb),
      'appearances', coalesce((
        select jsonb_agg(to_jsonb(appearance) order by appearance.performance_order)
        from public.event_appearances appearance where appearance.event_id = p_event_id
      ), '[]'::jsonb),
      'program', coalesce((
        select jsonb_agg(to_jsonb(program_row) order by program_row.performance_order)
        from public.event_appearance_repertoire program_row
        join public.event_appearances appearance
          on appearance.id = program_row.event_appearance_id
        where appearance.event_id = p_event_id
      ), '[]'::jsonb),
      'performer_links', coalesce((
        select jsonb_agg(to_jsonb(performer))
        from public.event_repertoire_participants performer
        join public.event_participants participant
          on participant.id = performer.event_participant_id
        join public.person_guardians link
          on link.child_person_id = participant.person_id
         and link.guardian_person_id = v_guardian_id
        join public.event_appearance_repertoire program_row
          on program_row.id = performer.event_appearance_repertoire_id
        join public.event_appearances appearance
          on appearance.id = program_row.event_appearance_id
        where appearance.event_id = p_event_id
      ), '[]'::jsonb)
    ) end
  ) into v_result
  from public.societies society
  where society.id = p_society_id and society.status in ('ACTIVE', 'SUSPENDED');
  return v_result;
end;
$$;

create or replace function public.auth_get_guardian_profile(p_society_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare v_guardian_id uuid := public.auth_guardian_person_for_society(p_society_id);
begin
  return jsonb_build_object(
    'person', (select to_jsonb(person) from public.people person where person.id = v_guardian_id),
    'society', (select jsonb_build_object('id', id, 'name', name, 'status', status)
      from public.societies where id = p_society_id),
    'sections', coalesce((
      select jsonb_agg(jsonb_build_object('id', section.id, 'name', section.name))
      from public.sections section where section.society_id = p_society_id
    ), '[]'::jsonb),
    'children', coalesce((
      select jsonb_agg(jsonb_build_object(
        'person', to_jsonb(child),
        'member', to_jsonb(child_member),
        'section_ids', coalesce((
          select jsonb_agg(child_section.section_id)
          from public.member_sections child_section
          where child_section.society_member_id = child_member.id
            and child_section.status = 'ACTIVE'
        ), '[]'::jsonb)
      ) order by child.last_name, child.first_name)
      from public.person_guardians link
      join public.people child on child.id = link.child_person_id
      join public.society_members child_member
        on child_member.person_id = child.id
       and child_member.society_id = p_society_id
       and child_member.status = 'ACTIVE'
      where link.guardian_person_id = v_guardian_id
    ), '[]'::jsonb)
  );
end;
$$;

create table if not exists public.guardian_profile_change_history (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  person_id uuid not null references public.people(id) on delete restrict,
  changed_fields text[] not null,
  changed_by_user_id uuid not null,
  changed_at timestamptz not null default now()
);
alter table public.guardian_profile_change_history enable row level security;
revoke all on table public.guardian_profile_change_history from public, anon, authenticated;

create or replace function public.auth_update_guardian_profile(
  p_society_id uuid, p_profile jsonb
) returns public.people
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_guardian_id uuid := public.auth_guardian_person_for_society(p_society_id);
  v_person public.people;
  v_result public.people;
  v_changed_fields text[] := array[]::text[];
  v_key text;
  v_allowed_keys constant text[] := array[
    'first_name', 'last_name', 'gender', 'birth_date', 'address', 'city',
    'postal_code', 'country', 'nationality', 'phone', 'shoe_size', 'jmbg',
    'passport_number', 'passport_issuing_country', 'passport_expiry_date'
  ];
begin
  select * into v_person from public.people where id = v_guardian_id for update;
  if nullif(btrim(p_profile->>'first_name'), '') is null
     or nullif(btrim(p_profile->>'last_name'), '') is null then
    raise exception 'Ime i prezime su obavezni.';
  end if;
  if (nullif(btrim(p_profile->>'passport_number'), '') is null)
     <> (nullif(p_profile->>'passport_expiry_date', '') is null) then
    raise exception 'Broj pasoša i datum važenja moraju biti uneti zajedno.';
  end if;
  if nullif(p_profile->>'shoe_size', '') is not null
     and (p_profile->>'shoe_size')::integer not between 15 and 55 then
    raise exception 'Broj obuće mora biti od 15 do 55.';
  end if;

  foreach v_key in array v_allowed_keys loop
    if to_jsonb(v_person)->>v_key is distinct from
       nullif(btrim(coalesce(p_profile->>v_key, '')), '') then
      v_changed_fields := array_append(v_changed_fields, v_key);
    end if;
  end loop;

  update public.people set
    first_name = btrim(p_profile->>'first_name'),
    last_name = btrim(p_profile->>'last_name'),
    gender = nullif(btrim(p_profile->>'gender'), ''),
    birth_date = nullif(p_profile->>'birth_date', '')::date,
    address = nullif(btrim(p_profile->>'address'), ''),
    city = nullif(btrim(p_profile->>'city'), ''),
    postal_code = nullif(btrim(p_profile->>'postal_code'), ''),
    country = coalesce(nullif(btrim(p_profile->>'country'), ''), 'Srbija'),
    nationality = nullif(btrim(p_profile->>'nationality'), ''),
    phone = nullif(btrim(p_profile->>'phone'), ''),
    shoe_size = nullif(p_profile->>'shoe_size', '')::integer,
    jmbg = nullif(btrim(p_profile->>'jmbg'), ''),
    passport_number = nullif(btrim(p_profile->>'passport_number'), ''),
    passport_issuing_country = nullif(btrim(p_profile->>'passport_issuing_country'), ''),
    passport_expiry_date = nullif(p_profile->>'passport_expiry_date', '')::date,
    updated_at = now()
  where id = v_guardian_id
  returning * into v_result;

  if cardinality(v_changed_fields) > 0 then
    insert into public.guardian_profile_change_history(
      society_id, person_id, changed_fields, changed_by_user_id
    ) values (p_society_id, v_guardian_id, v_changed_fields, auth.uid());
  end if;
  return v_result;
end;
$$;

revoke all on function public.auth_guardian_person_for_society(uuid) from public, anon, authenticated;
revoke all on function public.auth_get_guardian_sections_workspace(uuid) from public, anon;
revoke all on function public.auth_get_guardian_section_detail(uuid) from public, anon;
revoke all on function public.auth_get_guardian_attendance_workspace(uuid,uuid) from public, anon;
revoke all on function public.auth_get_guardian_attendance_history(uuid,uuid,text,date,date,uuid) from public, anon;
revoke all on function public.auth_get_guardian_finance_workspace(uuid) from public, anon;
revoke all on function public.auth_get_guardian_events_workspace(uuid,uuid) from public, anon;
revoke all on function public.auth_get_guardian_profile(uuid) from public, anon;
revoke all on function public.auth_update_guardian_profile(uuid,jsonb) from public, anon;

grant execute on function public.auth_get_guardian_sections_workspace(uuid) to authenticated;
grant execute on function public.auth_get_guardian_section_detail(uuid) to authenticated;
grant execute on function public.auth_get_guardian_attendance_workspace(uuid,uuid) to authenticated;
grant execute on function public.auth_get_guardian_attendance_history(uuid,uuid,text,date,date,uuid) to authenticated;
grant execute on function public.auth_get_guardian_finance_workspace(uuid) to authenticated;
grant execute on function public.auth_get_guardian_events_workspace(uuid,uuid) to authenticated;
grant execute on function public.auth_get_guardian_profile(uuid) to authenticated;
grant execute on function public.auth_update_guardian_profile(uuid,jsonb) to authenticated;

select pg_notify('pgrst', 'reload schema');
commit;
