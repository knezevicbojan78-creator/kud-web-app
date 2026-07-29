-- FOLKLORAS DEV/V1
-- Trajanje probe po sekciji i automatsko zatvaranje otvorenih proba.
-- Fajl je bezbedan za ponovno izvrsavanje.

begin;

alter table public.sections
  add column if not exists rehearsal_duration_minutes integer;

update public.sections
set rehearsal_duration_minutes = 120
where rehearsal_duration_minutes is null;

alter table public.sections
  alter column rehearsal_duration_minutes set default 120,
  alter column rehearsal_duration_minutes set not null;

alter table public.sections
  drop constraint if exists sections_rehearsal_duration_minutes_check;

alter table public.sections
  add constraint sections_rehearsal_duration_minutes_check check (
    rehearsal_duration_minutes between 30 and 240
    and rehearsal_duration_minutes % 15 = 0
  );

alter table public.attendance_sessions
  add column if not exists planned_end_at timestamptz,
  add column if not exists auto_close_at timestamptz,
  add column if not exists close_type text;

-- Postojecim probama zamrzava se rok prema trenutnom trajanju njihove sekcije.
update public.attendance_sessions session
set
  planned_end_at = session.opened_at
    + make_interval(mins => section.rehearsal_duration_minutes),
  auto_close_at = session.opened_at
    + make_interval(mins => section.rehearsal_duration_minutes + 30)
from public.sections section
where section.id = session.section_id
  and (session.planned_end_at is null or session.auto_close_at is null);

update public.attendance_sessions
set close_type = 'MANUAL'
where status = 'CLOSED' and close_type is null;

alter table public.attendance_sessions
  alter column planned_end_at set not null,
  alter column auto_close_at set not null;

alter table public.attendance_sessions
  drop constraint if exists attendance_sessions_schedule_check,
  drop constraint if exists attendance_sessions_close_type_check;

alter table public.attendance_sessions
  add constraint attendance_sessions_schedule_check check (
    planned_end_at > opened_at
    and auto_close_at = planned_end_at + interval '30 minutes'
  ),
  add constraint attendance_sessions_close_type_check check (
    (status = 'OPEN' and close_type is null)
    or (status = 'CLOSED' and close_type in ('MANUAL', 'AUTOMATIC'))
    or (status = 'CANCELLED' and close_type is null)
  );

create index if not exists attendance_sessions_auto_close_idx
  on public.attendance_sessions(auto_close_at)
  where status = 'OPEN';

create or replace function public.open_attendance_session(
  p_society_id uuid,
  p_section_id uuid,
  p_actor_role text,
  p_actor_user_id uuid default null
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session_id uuid;
  v_opened_at timestamptz := now();
  v_duration_minutes integer;
begin
  if p_actor_role not in ('Predsednik', 'UR') then
    raise exception 'Samo predsednik ili UR mogu otvoriti probu.';
  end if;

  select id into v_session_id
  from attendance_sessions
  where section_id = p_section_id and status = 'OPEN'
  limit 1;

  if v_session_id is not null then
    return v_session_id;
  end if;

  select rehearsal_duration_minutes into v_duration_minutes
  from sections
  where id = p_section_id
    and society_id = p_society_id
    and status = 'ACTIVE';

  if not found then
    raise exception 'Aktivna sekcija nije pronadjena u izabranom drustvu.';
  end if;

  insert into attendance_sessions (
    society_id,
    section_id,
    opened_at,
    planned_end_at,
    auto_close_at,
    opened_by_user_id,
    opened_by_role
  ) values (
    p_society_id,
    p_section_id,
    v_opened_at,
    v_opened_at + make_interval(mins => v_duration_minutes),
    v_opened_at + make_interval(mins => v_duration_minutes + 30),
    p_actor_user_id,
    p_actor_role
  ) returning id into v_session_id;

  insert into attendance_records (
    attendance_session_id,
    society_member_id,
    status,
    updated_by_user_id,
    updated_by_role
  )
  select
    v_session_id,
    ms.society_member_id,
    'ABSENT',
    p_actor_user_id,
    p_actor_role
  from member_sections ms
  join society_members sm on sm.id = ms.society_member_id
  where ms.section_id = p_section_id
    and ms.society_id = p_society_id
    and ms.status = 'ACTIVE'
    and sm.status = 'ACTIVE';

  return v_session_id;
end;
$$;

create or replace function public.close_attendance_session(
  p_session_id uuid,
  p_actor_role text,
  p_actor_user_id uuid default null
) returns public.attendance_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session attendance_sessions;
begin
  if p_actor_role not in ('Predsednik', 'UR') then
    raise exception 'Nemate pravo zatvaranja probe.';
  end if;

  update attendance_sessions set
    status = 'CLOSED',
    closed_at = now(),
    closed_by_user_id = p_actor_user_id,
    closed_by_role = p_actor_role,
    close_type = 'MANUAL',
    updated_at = now()
  where id = p_session_id and status = 'OPEN'
  returning * into v_session;

  if not found then
    raise exception 'Otvorena proba nije pronadjena.';
  end if;

  return v_session;
end;
$$;

create or replace function public.auto_close_attendance_sessions()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_closed_count integer;
begin
  update attendance_sessions
  set
    status = 'CLOSED',
    closed_at = auto_close_at,
    closed_by_user_id = null,
    closed_by_role = 'SYSTEM',
    close_type = 'AUTOMATIC',
    updated_at = now()
  where status = 'OPEN'
    and auto_close_at <= now();

  get diagnostics v_closed_count = row_count;
  return v_closed_count;
end;
$$;

revoke all on function public.auto_close_attendance_sessions() from public;
revoke all on function public.auto_close_attendance_sessions() from anon, authenticated;

grant execute on function public.open_attendance_session(uuid, uuid, text, uuid)
  to anon, authenticated;
grant execute on function public.close_attendance_session(uuid, text, uuid)
  to anon, authenticated;

commit;

-- Supabase Scheduled Job: provera na svakih pet minuta.
create extension if not exists pg_cron;

do $$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname = 'auto-close-attendance-sessions'
  limit 1;

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;
end;
$$;

select cron.schedule(
  'auto-close-attendance-sessions',
  '*/5 * * * *',
  'select public.auto_close_attendance_sessions();'
);

select pg_notify('pgrst', 'reload schema');

-- Kontrolna provera nakon uspesnog izvrsavanja.
select
  section.id,
  section.name,
  section.rehearsal_duration_minutes
from public.sections section
order by section.name;
