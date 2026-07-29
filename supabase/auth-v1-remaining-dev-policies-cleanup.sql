-- FOLKLORAS — AUTH V1 / UKLANJANJE PREOSTALIH DEV POLITIKA
-- Primeniti nakon auth-v1-final-dev-cleanup.sql.

begin;

create or replace function public.auth_can_access_person(p_person_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select public.auth_is_master_admin()
    or exists (
      select 1
      from public.society_members sm
      where sm.person_id = p_person_id
        and public.auth_can_access_society(sm.society_id)
    )
    or exists (
      select 1
      from public.person_guardians pg
      join public.society_members sm on sm.person_id = pg.child_person_id
      where pg.guardian_person_id = p_person_id
        and public.auth_can_access_society(sm.society_id)
    );
$$;

create or replace function public.auth_can_access_event(p_event_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select exists (
    select 1
    from public.society_events se
    where se.id = p_event_id
      and public.auth_can_access_society(se.society_id)
  );
$$;

create or replace function public.auth_can_access_repertoire_item(
  p_repertoire_item_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select exists (
    select 1
    from public.repertoire_items ri
    where ri.id = p_repertoire_item_id
      and public.auth_can_access_society(ri.society_id)
  );
$$;

revoke all on function public.auth_can_access_person(uuid) from public, anon;
revoke all on function public.auth_can_access_event(uuid) from public, anon;
revoke all on function public.auth_can_access_repertoire_item(uuid)
  from public, anon;
grant execute on function public.auth_can_access_person(uuid) to authenticated;
grant execute on function public.auth_can_access_event(uuid) to authenticated;
grant execute on function public.auth_can_access_repertoire_item(uuid)
  to authenticated;

-- Uklanjamo sve preostale politike koje su izričito označene kao DEV.
do $$
declare
  v_policy record;
begin
  for v_policy in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and policyname ilike 'dev%'
  loop
    execute format(
      'drop policy if exists %I on %I.%I',
      v_policy.policyname,
      v_policy.schemaname,
      v_policy.tablename
    );
  end loop;
end;
$$;

-- Idempotentno obnavljanje Auth V1 read politika.
drop policy if exists "auth_master_president_reg_select"
  on public."PresidentReg";
create policy "auth_master_president_reg_select"
on public."PresidentReg"
for select to authenticated
using (public.auth_is_master_admin());

drop policy if exists "auth_societies_select" on public.societies;
create policy "auth_societies_select"
on public.societies
for select to authenticated
using (public.auth_can_access_society(id));

drop policy if exists "auth_people_select" on public.people;
create policy "auth_people_select"
on public.people
for select to authenticated
using (public.auth_can_access_person(id));

drop policy if exists "auth_society_members_select"
  on public.society_members;
create policy "auth_society_members_select"
on public.society_members
for select to authenticated
using (public.auth_can_access_society(society_id));

drop policy if exists "auth_member_status_history_select"
  on public.member_status_history;
create policy "auth_member_status_history_select"
on public.member_status_history
for select to authenticated
using (
  exists (
    select 1 from public.society_members sm
    where sm.id = society_member_id
      and public.auth_can_access_society(sm.society_id)
  )
);

drop policy if exists "auth_person_guardians_select"
  on public.person_guardians;
create policy "auth_person_guardians_select"
on public.person_guardians
for select to authenticated
using (
  public.auth_can_access_person(child_person_id)
  or public.auth_can_access_person(guardian_person_id)
);

drop policy if exists "auth_society_member_functions_select"
  on public.society_member_functions;
create policy "auth_society_member_functions_select"
on public.society_member_functions
for select to authenticated
using (public.auth_can_access_society(society_id));

drop policy if exists "auth_society_member_function_assignments_select"
  on public.society_member_function_assignments;
create policy "auth_society_member_function_assignments_select"
on public.society_member_function_assignments
for select to authenticated
using (public.auth_can_access_society(society_id));

drop policy if exists "auth_attendance_sessions_select"
  on public.attendance_sessions;
create policy "auth_attendance_sessions_select"
on public.attendance_sessions
for select to authenticated
using (public.auth_can_access_society(society_id));

drop policy if exists "auth_attendance_records_select"
  on public.attendance_records;
create policy "auth_attendance_records_select"
on public.attendance_records
for select to authenticated
using (
  exists (
    select 1 from public.attendance_sessions ats
    where ats.id = attendance_session_id
      and public.auth_can_access_society(ats.society_id)
  )
);

drop policy if exists "auth_attendance_record_history_select"
  on public.attendance_record_history;
create policy "auth_attendance_record_history_select"
on public.attendance_record_history
for select to authenticated
using (
  exists (
    select 1
    from public.attendance_records ar
    join public.attendance_sessions ats
      on ats.id = ar.attendance_session_id
    where ar.id = attendance_record_id
      and public.auth_can_access_society(ats.society_id)
  )
);

drop policy if exists "auth_society_events_select"
  on public.society_events;
create policy "auth_society_events_select"
on public.society_events
for select to authenticated
using (public.auth_can_access_society(society_id));

drop policy if exists "auth_event_status_history_select"
  on public.event_status_history;
create policy "auth_event_status_history_select"
on public.event_status_history
for select to authenticated
using (public.auth_can_access_event(event_id));

drop policy if exists "auth_event_sections_select"
  on public.event_sections;
create policy "auth_event_sections_select"
on public.event_sections
for select to authenticated
using (public.auth_can_access_event(event_id));

drop policy if exists "auth_event_participants_select"
  on public.event_participants;
create policy "auth_event_participants_select"
on public.event_participants
for select to authenticated
using (public.auth_can_access_event(event_id));

drop policy if exists "auth_event_participant_sections_select"
  on public.event_participant_sections;
create policy "auth_event_participant_sections_select"
on public.event_participant_sections
for select to authenticated
using (
  exists (
    select 1 from public.event_participants ep
    where ep.id = event_participant_id
      and public.auth_can_access_event(ep.event_id)
  )
);

drop policy if exists "auth_event_appearances_select"
  on public.event_appearances;
create policy "auth_event_appearances_select"
on public.event_appearances
for select to authenticated
using (public.auth_can_access_event(event_id));

drop policy if exists "auth_event_appearance_repertoire_select"
  on public.event_appearance_repertoire;
create policy "auth_event_appearance_repertoire_select"
on public.event_appearance_repertoire
for select to authenticated
using (
  exists (
    select 1 from public.event_appearances ea
    where ea.id = event_appearance_id
      and public.auth_can_access_event(ea.event_id)
  )
);

drop policy if exists "auth_event_repertoire_participants_select"
  on public.event_repertoire_participants;
create policy "auth_event_repertoire_participants_select"
on public.event_repertoire_participants
for select to authenticated
using (
  exists (
    select 1
    from public.event_appearance_repertoire ear
    join public.event_appearances ea on ea.id = ear.event_appearance_id
    where ear.id = event_appearance_repertoire_id
      and public.auth_can_access_event(ea.event_id)
  )
);

drop policy if exists "auth_person_data_change_requests_select"
  on public.person_data_change_requests;
create policy "auth_person_data_change_requests_select"
on public.person_data_change_requests
for select to authenticated
using (public.auth_can_access_society(society_id));

drop policy if exists "auth_repertoire_items_select"
  on public.repertoire_items;
create policy "auth_repertoire_items_select"
on public.repertoire_items
for select to authenticated
using (public.auth_can_access_society(society_id));

drop policy if exists "auth_repertoire_item_sections_select"
  on public.repertoire_item_sections;
create policy "auth_repertoire_item_sections_select"
on public.repertoire_item_sections
for select to authenticated
using (public.auth_can_access_repertoire_item(repertoire_item_id));

-- Browser više nema direktne upise; izmene prolaze kroz Auth V1 RPC funkcije.
revoke all on table public."PresidentReg" from anon;
revoke all on table public.people from anon;
revoke all on table public.person_guardians from anon;
revoke all on table public.societies from anon;
revoke all on table public.society_members from anon;
revoke all on table public.member_status_history from anon;
revoke all on table public.society_member_functions from anon;
revoke all on table public.society_member_function_assignments from anon;
revoke all on table public.attendance_sessions from anon;
revoke all on table public.attendance_records from anon;
revoke all on table public.attendance_record_history from anon;
revoke all on table public.society_events from anon;
revoke all on table public.event_status_history from anon;
revoke all on table public.event_sections from anon;
revoke all on table public.event_participants from anon;
revoke all on table public.event_participant_sections from anon;
revoke all on table public.event_appearances from anon;
revoke all on table public.event_appearance_repertoire from anon;
revoke all on table public.event_repertoire_participants from anon;
revoke all on table public.person_data_change_requests from anon;
revoke all on table public.repertoire_items from anon;
revoke all on table public.repertoire_item_sections from anon;

revoke insert, update, delete on public.people from authenticated;
revoke insert, update, delete on public.person_guardians from authenticated;
revoke insert, update, delete on public.societies from authenticated;
revoke insert, update, delete on public.society_members from authenticated;
revoke insert, update, delete on public.member_status_history from authenticated;
revoke insert, update, delete on public.society_member_functions
  from authenticated;
revoke insert, update, delete
  on public.society_member_function_assignments from authenticated;
revoke insert, update, delete on public.attendance_sessions from authenticated;
revoke insert, update, delete on public.attendance_records from authenticated;
revoke insert, update, delete on public.attendance_record_history
  from authenticated;
revoke insert, update, delete on public.society_events from authenticated;
revoke insert, update, delete on public.event_status_history from authenticated;
revoke insert, update, delete on public.event_sections from authenticated;
revoke insert, update, delete on public.event_participants from authenticated;
revoke insert, update, delete on public.event_participant_sections
  from authenticated;
revoke insert, update, delete on public.event_appearances from authenticated;
revoke insert, update, delete on public.event_appearance_repertoire
  from authenticated;
revoke insert, update, delete on public.event_repertoire_participants
  from authenticated;
revoke insert, update, delete on public.person_data_change_requests
  from authenticated;
revoke insert, update, delete on public.repertoire_items from authenticated;
revoke insert, update, delete on public.repertoire_item_sections
  from authenticated;

grant select on public."PresidentReg" to authenticated;
grant select on public.people to authenticated;
grant select on public.person_guardians to authenticated;
grant select on public.societies to authenticated;
grant select on public.society_members to authenticated;
grant select on public.member_status_history to authenticated;
grant select on public.society_member_functions to authenticated;
grant select on public.society_member_function_assignments to authenticated;
grant select on public.attendance_sessions to authenticated;
grant select on public.attendance_records to authenticated;
grant select on public.attendance_record_history to authenticated;
grant select on public.society_events to authenticated;
grant select on public.event_status_history to authenticated;
grant select on public.event_sections to authenticated;
grant select on public.event_participants to authenticated;
grant select on public.event_participant_sections to authenticated;
grant select on public.event_appearances to authenticated;
grant select on public.event_appearance_repertoire to authenticated;
grant select on public.event_repertoire_participants to authenticated;
grant select on public.person_data_change_requests to authenticated;
grant select on public.repertoire_items to authenticated;
grant select on public.repertoire_item_sections to authenticated;

select pg_notify('pgrst', 'reload schema');

commit;

select
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and policyname ilike 'dev%'
  ) as remaining_dev_policies,
  has_table_privilege('anon', 'public.people', 'SELECT')
    as anon_people_select,
  has_table_privilege('anon', 'public.society_members', 'SELECT')
    as anon_members_select,
  has_table_privilege('anon', 'public.society_events', 'INSERT,UPDATE,DELETE')
    as anon_events_write,
  has_table_privilege(
    'authenticated',
    'public.society_events',
    'INSERT,UPDATE,DELETE'
  ) as authenticated_direct_events_write,
  has_function_privilege(
    'authenticated',
    'public.auth_can_access_society(uuid)',
    'EXECUTE'
  ) as authenticated_society_scope;
