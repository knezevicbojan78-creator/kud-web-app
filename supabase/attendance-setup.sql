create table if not exists public.attendance_sessions (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  section_id uuid not null references public.sections(id) on delete restrict,
  status text not null default 'OPEN' check (status in ('OPEN', 'CLOSED', 'CANCELLED')),
  opened_at timestamptz not null default now(),
  opened_by_user_id uuid null,
  opened_by_role text not null,
  closed_at timestamptz null,
  closed_by_user_id uuid null,
  closed_by_role text null,
  cancelled_at timestamptz null,
  cancelled_by_user_id uuid null,
  cancelled_by_role text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint attendance_sessions_closed_state_check check (
    (status = 'OPEN' and closed_at is null and cancelled_at is null) or
    (status = 'CLOSED' and closed_at is not null and cancelled_at is null) or
    (status = 'CANCELLED' and closed_at is null and cancelled_at is not null)
  )
);

-- Omogućava ponovno pokretanje setup fajla i nadogradnju ranije V1 verzije.
alter table public.attendance_sessions
  add column if not exists cancelled_at timestamptz null,
  add column if not exists cancelled_by_user_id uuid null,
  add column if not exists cancelled_by_role text null;

alter table public.attendance_sessions
  drop constraint if exists attendance_sessions_status_check,
  drop constraint if exists attendance_sessions_closed_state_check;

alter table public.attendance_sessions
  add constraint attendance_sessions_status_check
    check (status in ('OPEN', 'CLOSED', 'CANCELLED')),
  add constraint attendance_sessions_closed_state_check check (
    (status = 'OPEN' and closed_at is null and cancelled_at is null) or
    (status = 'CLOSED' and closed_at is not null and cancelled_at is null) or
    (status = 'CANCELLED' and closed_at is null and cancelled_at is not null)
  );

create unique index if not exists attendance_sessions_one_open_per_section
  on public.attendance_sessions(section_id)
  where status = 'OPEN';

create index if not exists attendance_sessions_society_section_idx
  on public.attendance_sessions(society_id, section_id, opened_at desc);

create table if not exists public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  attendance_session_id uuid not null references public.attendance_sessions(id) on delete restrict,
  society_member_id uuid not null references public.society_members(id) on delete restrict,
  status text not null default 'ABSENT' check (status in ('ABSENT', 'PRESENT')),
  updated_at timestamptz not null default now(),
  updated_by_user_id uuid null,
  updated_by_role text not null,
  unique (attendance_session_id, society_member_id)
);

create index if not exists attendance_records_session_idx
  on public.attendance_records(attendance_session_id);

create table if not exists public.attendance_record_history (
  id uuid primary key default gen_random_uuid(),
  attendance_record_id uuid not null references public.attendance_records(id) on delete restrict,
  old_status text null check (old_status is null or old_status in ('ABSENT', 'PRESENT')),
  new_status text not null check (new_status in ('ABSENT', 'PRESENT')),
  changed_at timestamptz not null default now(),
  changed_by_user_id uuid null,
  changed_by_role text not null,
  session_status_at_change text not null check (session_status_at_change in ('OPEN', 'CLOSED')),
  reason text null,
  constraint attendance_history_closed_reason_check check (
    session_status_at_change = 'OPEN' or length(trim(coalesce(reason, ''))) > 0
  )
);

create index if not exists attendance_record_history_record_idx
  on public.attendance_record_history(attendance_record_id, changed_at desc);

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

  insert into attendance_sessions (
    society_id, section_id, opened_by_user_id, opened_by_role
  ) values (
    p_society_id, p_section_id, p_actor_user_id, p_actor_role
  ) returning id into v_session_id;

  insert into attendance_records (
    attendance_session_id, society_member_id, status,
    updated_by_user_id, updated_by_role
  )
  select
    v_session_id, ms.society_member_id, 'ABSENT',
    p_actor_user_id, p_actor_role
  from member_sections ms
  join society_members sm on sm.id = ms.society_member_id
  where ms.section_id = p_section_id
    and ms.society_id = p_society_id
    and ms.status = 'ACTIVE'
    and sm.status = 'ACTIVE';

  return v_session_id;
end;
$$;

create or replace function public.set_attendance_status(
  p_record_id uuid,
  p_new_status text,
  p_actor_role text,
  p_reason text default null,
  p_actor_user_id uuid default null
) returns public.attendance_records
language plpgsql
security definer
set search_path = public
as $$
declare
  v_record attendance_records;
  v_session attendance_sessions;
  v_old_status text;
begin
  if p_new_status not in ('ABSENT', 'PRESENT') then
    raise exception 'Nepoznat status prisustva.';
  end if;

  select * into v_record from attendance_records where id = p_record_id for update;
  if not found then raise exception 'Evidencija člana nije pronađena.'; end if;

  select * into v_session from attendance_sessions
  where id = v_record.attendance_session_id;

  if v_session.status = 'CLOSED' and p_actor_role <> 'Predsednik' then
    raise exception 'Samo predsednik može menjati zatvorenu probu.';
  end if;
  if v_session.status = 'CLOSED' and length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'Razlog izmene je obavezan.';
  end if;
  if v_session.status = 'OPEN' and p_actor_role not in ('Predsednik', 'UR') then
    raise exception 'Nemate pravo izmene prisustva.';
  end if;

  v_old_status := v_record.status;
  if v_old_status = p_new_status then return v_record; end if;

  update attendance_records set
    status = p_new_status,
    updated_at = now(),
    updated_by_user_id = p_actor_user_id,
    updated_by_role = p_actor_role
  where id = p_record_id
  returning * into v_record;

  insert into attendance_record_history (
    attendance_record_id, old_status, new_status, changed_by_user_id,
    changed_by_role, session_status_at_change, reason
  ) values (
    p_record_id, v_old_status, p_new_status, p_actor_user_id,
    p_actor_role, v_session.status,
    case when v_session.status = 'CLOSED' then trim(p_reason) else null end
  );

  return v_record;
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
    updated_at = now()
  where id = p_session_id and status = 'OPEN'
  returning * into v_session;

  if not found then raise exception 'Otvorena proba nije pronađena.'; end if;
  return v_session;
end;
$$;

create or replace function public.cancel_attendance_session(
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
    raise exception 'Nemate pravo otkazivanja probe.';
  end if;

  update attendance_sessions set
    status = 'CANCELLED',
    cancelled_at = now(),
    cancelled_by_user_id = p_actor_user_id,
    cancelled_by_role = p_actor_role,
    updated_at = now()
  where id = p_session_id and status = 'OPEN'
  returning * into v_session;

  if not found then raise exception 'Otvorena proba nije pronađena.'; end if;
  return v_session;
end;
$$;

alter table public.attendance_sessions enable row level security;
alter table public.attendance_records enable row level security;
alter table public.attendance_record_history enable row level security;

drop policy if exists "DEV attendance sessions all" on public.attendance_sessions;
drop policy if exists "DEV attendance sessions read" on public.attendance_sessions;
create policy "DEV attendance sessions read" on public.attendance_sessions
  for select using (true);

drop policy if exists "DEV attendance records all" on public.attendance_records;
drop policy if exists "DEV attendance records read" on public.attendance_records;
create policy "DEV attendance records read" on public.attendance_records
  for select using (true);

drop policy if exists "DEV attendance history read" on public.attendance_record_history;
create policy "DEV attendance history read" on public.attendance_record_history
  for select using (true);

drop policy if exists "DEV attendance history insert" on public.attendance_record_history;

revoke insert, update, delete on public.attendance_sessions from anon, authenticated;
revoke insert, update, delete on public.attendance_records from anon, authenticated;
revoke insert, update, delete on public.attendance_record_history from anon, authenticated;

grant execute on function public.open_attendance_session(uuid, uuid, text, uuid) to anon, authenticated;
grant execute on function public.set_attendance_status(uuid, text, text, text, uuid) to anon, authenticated;
grant execute on function public.close_attendance_session(uuid, text, uuid) to anon, authenticated;
grant execute on function public.cancel_attendance_session(uuid, text, uuid) to anon, authenticated;

-- DEV/V1 policies only. Final Auth/RLS must derive society, section role and
-- president permissions from the authenticated user instead of client input.

-- Osvežava PostgREST schema cache da nove i izmenjene RPC funkcije odmah
-- postanu dostupne Supabase klijentu nakon izvršavanja ovog setup fajla.
select pg_notify('pgrst', 'reload schema');
