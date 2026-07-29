-- FOLKLORAS — AUTH V1 / ATTENDANCE SECURITY
-- Browser vise ne odredjuje stvarnu ulogu niti actor user id.

begin;

do $$
begin
  if to_regprocedure('public.open_attendance_session_impl(uuid,uuid,text,uuid)') is null
     and to_regprocedure('public.open_attendance_session(uuid,uuid,text,uuid)') is not null then
    alter function public.open_attendance_session(uuid, uuid, text, uuid)
      rename to open_attendance_session_impl;
  end if;

  if to_regprocedure('public.set_attendance_status_impl(uuid,text,text,text,uuid)') is null
     and to_regprocedure('public.set_attendance_status(uuid,text,text,text,uuid)') is not null then
    alter function public.set_attendance_status(uuid, text, text, text, uuid)
      rename to set_attendance_status_impl;
  end if;

  if to_regprocedure('public.close_attendance_session_impl(uuid,text,uuid)') is null
     and to_regprocedure('public.close_attendance_session(uuid,text,uuid)') is not null then
    alter function public.close_attendance_session(uuid, text, uuid)
      rename to close_attendance_session_impl;
  end if;

  if to_regprocedure('public.cancel_attendance_session_impl(uuid,text,uuid)') is null
     and to_regprocedure('public.cancel_attendance_session(uuid,text,uuid)') is not null then
    alter function public.cancel_attendance_session(uuid, text, uuid)
      rename to cancel_attendance_session_impl;
  end if;
end;
$$;

create or replace function public.auth_resolve_attendance_role(
  p_society_id uuid,
  p_section_id uuid,
  p_permission_key text
)
returns text
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_member_id uuid;
  v_person_id uuid;
  v_role text;
begin
  if v_user_id is null then
    raise exception 'Prijava je obavezna.';
  end if;

  if not exists (
    select 1
    from public.sections sec
    where sec.id = p_section_id and sec.society_id = p_society_id
  ) then
    raise exception 'Sekcija ne pripada izabranom drustvu.';
  end if;

  select sm.id, sm.person_id
  into v_member_id, v_person_id
  from public.society_members sm
  join public.people person on person.id = sm.person_id
  where coalesce(sm.user_id, person.user_id) = v_user_id
    and sm.society_id = p_society_id
    and sm.status = 'ACTIVE';

  if v_member_id is null then
    raise exception 'Korisnik nema aktivno clanstvo u drustvu.';
  end if;

  if not public.permissions_can_access_section(
    p_society_id, v_member_id, v_person_id,
    p_section_id, p_permission_key
  ) then
    raise exception 'Nemate potrebnu dozvolu za prisustvo u ovoj sekciji.';
  end if;

  if exists (
    select 1
    from public.society_member_function_assignments smfa
    join public.society_member_functions smf on smf.id = smfa.function_id
    where smfa.society_member_id = v_member_id
      and smf.society_id = p_society_id
      and smf.name = 'Predsednik'
      and smf.is_active
  ) then
    v_role := 'Predsednik';
  elsif exists (
    select 1
    from public.section_role_assignments sra
    where sra.society_id = p_society_id
      and sra.section_id = p_section_id
      and sra.society_member_id = v_member_id
      and sra.role = 'UR'
      and sra.status = 'ACTIVE'
  ) then
    v_role := 'UR';
  else
    v_role := 'Ovlašćeni korisnik';
  end if;

  return v_role;
end;
$$;

create or replace function public.open_attendance_session(
  p_society_id uuid,
  p_section_id uuid,
  p_actor_role text,
  p_actor_user_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_role text;
begin
  v_role := public.auth_resolve_attendance_role(
    p_society_id, p_section_id, 'attendance.open'
  );
  return public.open_attendance_session_impl(
    p_society_id, p_section_id, v_role, auth.uid()
  );
end;
$$;

create or replace function public.set_attendance_status(
  p_record_id uuid,
  p_new_status text,
  p_actor_role text,
  p_reason text default null,
  p_actor_user_id uuid default null
)
returns public.attendance_records
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_record public.attendance_records;
  v_session public.attendance_sessions;
  v_role text;
begin
  select * into v_record
  from public.attendance_records
  where id = p_record_id;
  if not found then raise exception 'Evidencija clana nije pronadjena.'; end if;

  select * into v_session
  from public.attendance_sessions
  where id = v_record.attendance_session_id;
  if not found then raise exception 'Proba nije pronadjena.'; end if;

  v_role := public.auth_resolve_attendance_role(
    v_session.society_id,
    v_session.section_id,
    case when v_session.status = 'OPEN'
      then 'attendance.record_open'
      else 'attendance.edit_closed'
    end
  );
  return public.set_attendance_status_impl(
    p_record_id, p_new_status, v_role, p_reason, auth.uid()
  );
end;
$$;

create or replace function public.close_attendance_session(
  p_session_id uuid,
  p_actor_role text,
  p_actor_user_id uuid default null
)
returns public.attendance_sessions
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_session public.attendance_sessions;
  v_role text;
begin
  select * into v_session
  from public.attendance_sessions
  where id = p_session_id;
  if not found then raise exception 'Proba nije pronadjena.'; end if;

  v_role := public.auth_resolve_attendance_role(
    v_session.society_id, v_session.section_id, 'attendance.close'
  );
  return public.close_attendance_session_impl(
    p_session_id, v_role, auth.uid()
  );
end;
$$;

create or replace function public.cancel_attendance_session(
  p_session_id uuid,
  p_actor_role text,
  p_actor_user_id uuid default null
)
returns public.attendance_sessions
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_session public.attendance_sessions;
  v_role text;
begin
  select * into v_session
  from public.attendance_sessions
  where id = p_session_id;
  if not found then raise exception 'Proba nije pronadjena.'; end if;

  v_role := public.auth_resolve_attendance_role(
    v_session.society_id, v_session.section_id, 'attendance.cancel_open'
  );
  return public.cancel_attendance_session_impl(
    p_session_id, v_role, auth.uid()
  );
end;
$$;

revoke all on function public.auth_resolve_attendance_role(uuid, uuid, text)
  from public, anon, authenticated;
revoke all on function public.open_attendance_session_impl(uuid, uuid, text, uuid)
  from public, anon, authenticated;
revoke all on function public.set_attendance_status_impl(uuid, text, text, text, uuid)
  from public, anon, authenticated;
revoke all on function public.close_attendance_session_impl(uuid, text, uuid)
  from public, anon, authenticated;
revoke all on function public.cancel_attendance_session_impl(uuid, text, uuid)
  from public, anon, authenticated;

revoke all on function public.open_attendance_session(uuid, uuid, text, uuid)
  from public, anon;
revoke all on function public.set_attendance_status(uuid, text, text, text, uuid)
  from public, anon;
revoke all on function public.close_attendance_session(uuid, text, uuid)
  from public, anon;
revoke all on function public.cancel_attendance_session(uuid, text, uuid)
  from public, anon;

grant execute on function public.open_attendance_session(uuid, uuid, text, uuid)
  to authenticated;
grant execute on function public.set_attendance_status(uuid, text, text, text, uuid)
  to authenticated;
grant execute on function public.close_attendance_session(uuid, text, uuid)
  to authenticated;
grant execute on function public.cancel_attendance_session(uuid, text, uuid)
  to authenticated;

select pg_notify('pgrst', 'reload schema');

commit;

select
  count(*) filter (
    where p.proname in (
      'open_attendance_session',
      'set_attendance_status',
      'close_attendance_session',
      'cancel_attendance_session'
    )
    and has_function_privilege('authenticated', p.oid, 'EXECUTE')
  ) as authenticated_secure_functions,
  count(*) filter (
    where p.proname in (
      'open_attendance_session',
      'set_attendance_status',
      'close_attendance_session',
      'cancel_attendance_session'
    )
    and has_function_privilege('anon', p.oid, 'EXECUTE')
  ) as anon_secure_functions,
  count(*) filter (
    where p.proname like '%attendance%_impl'
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')
  ) as exposed_implementations
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public';
