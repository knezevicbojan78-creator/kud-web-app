begin;

-- Korepetitor je osoba, ali ne mora biti član društva.
create table if not exists public.section_accompanists (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  section_id uuid not null references public.sections(id) on delete restrict,
  person_id uuid not null references public.people(id) on delete restrict,
  attendance_enabled boolean not null default false,
  status text not null default 'ACTIVE'
    check (status in ('ACTIVE', 'INACTIVE')),
  active_from date not null default current_date,
  active_until date null,
  created_by_user_id uuid null,
  updated_by_user_id uuid null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint section_accompanists_dates_check
    check (active_until is null or active_until >= active_from),
  constraint section_accompanists_unique unique (section_id, person_id)
);

create index if not exists section_accompanists_society_section_idx
  on public.section_accompanists(society_id, section_id, status);

alter table public.section_accompanists enable row level security;
revoke all on table public.section_accompanists from public, anon, authenticated;

-- Postojeće članske dodele korepetitora se prenose bez brisanja stare istorije.
insert into public.section_accompanists (
  society_id, section_id, person_id, attendance_enabled, status,
  active_from, created_at, updated_at
)
select
  role_row.society_id,
  role_row.section_id,
  member.person_id,
  false,
  role_row.status,
  coalesce(role_row.created_at::date, current_date),
  coalesce(role_row.created_at, now()),
  coalesce(role_row.updated_at, now())
from public.section_role_assignments role_row
join public.society_members member on member.id = role_row.society_member_id
where role_row.role = 'KOREPETITOR'
on conflict (section_id, person_id) do nothing;

-- Novo pravo se automatski pojavljuje u Podešavanja -> Dozvole.
insert into public.permission_catalog (
  permission_key, module_key, label, action_type, allowed_scopes,
  is_sensitive, requires_reason, is_president_only
)
values (
  'sections.manage_accompanists',
  'sections',
  'Upravljanje korepetitorima i njihovom evidencijom prisustva',
  'MANAGE',
  array['ASSIGNED_SECTIONS','SOCIETY'],
  true,
  true,
  false
)
on conflict (permission_key) do update
set
  module_key = excluded.module_key,
  label = excluded.label,
  action_type = excluded.action_type,
  allowed_scopes = excluded.allowed_scopes,
  is_sensitive = excluded.is_sensitive,
  requires_reason = excluded.requires_reason,
  is_president_only = excluded.is_president_only,
  is_active = true,
  updated_at = now();

insert into public.system_function_permission_templates (
  function_name, permission_id, scope_key, is_locked
)
select 'Predsednik', permission.id, 'SOCIETY', true
from public.permission_catalog permission
where permission.permission_key = 'sections.manage_accompanists'
on conflict (function_name, permission_id) do update
set scope_key = excluded.scope_key,
    is_locked = excluded.is_locked,
    updated_at = now();

insert into public.society_function_permission_rules (
  society_id, function_id, permission_id, scope_key, is_locked
)
select
  function_row.society_id,
  function_row.id,
  permission.id,
  'SOCIETY',
  true
from public.society_member_functions function_row
join public.permission_catalog permission
  on permission.permission_key = 'sections.manage_accompanists'
where function_row.name = 'Predsednik'
  and function_row.is_active
on conflict (function_id, permission_id) do update
set scope_key = excluded.scope_key,
    is_locked = excluded.is_locked,
    updated_at = now();

-- Evidencija probe dobija stabilni person_id i vrstu učesnika.
alter table public.attendance_records
  add column if not exists person_id uuid null
    references public.people(id) on delete restrict,
  add column if not exists participant_type text not null default 'MEMBER',
  add column if not exists role_label text null;

update public.attendance_records record
set person_id = member.person_id
from public.society_members member
where member.id = record.society_member_id
  and record.person_id is null;

alter table public.attendance_records
  alter column person_id set not null,
  alter column society_member_id drop not null;

alter table public.attendance_records
  drop constraint if exists attendance_records_participant_type_check,
  drop constraint if exists attendance_records_source_check;

alter table public.attendance_records
  add constraint attendance_records_participant_type_check
    check (participant_type in ('MEMBER', 'ACCOMPANIST')),
  add constraint attendance_records_source_check check (
    (participant_type = 'MEMBER' and society_member_id is not null)
    or
    (participant_type = 'ACCOMPANIST' and society_member_id is null)
  );

create unique index if not exists attendance_records_session_person_unique
  on public.attendance_records(attendance_session_id, person_id);

-- Zamena privatne implementacije otvaranja probe. Spisak se snima u trenutku
-- otvaranja i kasnije promene podešavanja ne menjaju otvorenu probu.
create or replace function public.open_attendance_session_impl(
  p_society_id uuid,
  p_section_id uuid,
  p_actor_role text,
  p_actor_user_id uuid default null
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_session_id uuid;
  v_opened_at timestamptz := now();
  v_duration_minutes integer;
begin
  select id into v_session_id
  from public.attendance_sessions
  where section_id = p_section_id and status = 'OPEN'
  limit 1;

  if v_session_id is not null then
    return v_session_id;
  end if;

  select rehearsal_duration_minutes into v_duration_minutes
  from public.sections
  where id = p_section_id
    and society_id = p_society_id
    and status = 'ACTIVE';

  if not found then
    raise exception 'Aktivna sekcija nije pronadjena.';
  end if;

  insert into public.attendance_sessions (
    society_id, section_id, opened_at, planned_end_at, auto_close_at,
    opened_by_user_id, opened_by_role
  ) values (
    p_society_id, p_section_id, v_opened_at,
    v_opened_at + make_interval(mins => v_duration_minutes),
    v_opened_at + make_interval(mins => v_duration_minutes + 30),
    p_actor_user_id, p_actor_role
  ) returning id into v_session_id;

  insert into public.attendance_records (
    attendance_session_id, society_member_id, person_id, participant_type,
    role_label, status, updated_by_user_id, updated_by_role
  )
  select
    v_session_id, membership.society_member_id, member.person_id, 'MEMBER',
    case when exists (
      select 1
      from public.section_accompanists accompanist
      where accompanist.section_id = p_section_id
        and accompanist.person_id = member.person_id
        and accompanist.status = 'ACTIVE'
        and accompanist.attendance_enabled
        and accompanist.active_from <= current_date
        and (accompanist.active_until is null or accompanist.active_until >= current_date)
    ) then 'Korepetitor' else null end,
    'ABSENT', p_actor_user_id, p_actor_role
  from public.member_sections membership
  join public.society_members member
    on member.id = membership.society_member_id
  where membership.section_id = p_section_id
    and membership.society_id = p_society_id
    and membership.status = 'ACTIVE'
    and member.status = 'ACTIVE';

  insert into public.attendance_records (
    attendance_session_id, society_member_id, person_id, participant_type,
    role_label, status, updated_by_user_id, updated_by_role
  )
  select
    v_session_id, null, accompanist.person_id, 'ACCOMPANIST',
    'Korepetitor', 'ABSENT', p_actor_user_id, p_actor_role
  from public.section_accompanists accompanist
  where accompanist.section_id = p_section_id
    and accompanist.society_id = p_society_id
    and accompanist.status = 'ACTIVE'
    and accompanist.attendance_enabled
    and accompanist.active_from <= current_date
    and (accompanist.active_until is null or accompanist.active_until >= current_date)
  on conflict (attendance_session_id, person_id) do nothing;

  return v_session_id;
end;
$$;

revoke all on function public.open_attendance_session_impl(uuid,uuid,text,uuid)
  from public, anon, authenticated;

-- Upravljanje dodelama korepetitora.
create or replace function public.auth_manage_section_accompanist(
  p_action text,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_society_id uuid := nullif(p_payload ->> 'society_id', '')::uuid;
  v_section_id uuid := nullif(p_payload ->> 'section_id', '')::uuid;
  v_assignment_id uuid := nullif(p_payload ->> 'assignment_id', '')::uuid;
  v_person_id uuid := nullif(p_payload ->> 'person_id', '')::uuid;
  v_actor_member_id uuid;
  v_actor_person_id uuid;
  v_assignment public.section_accompanists;
begin
  if v_user_id is null then raise exception 'Prijava je obavezna.'; end if;

  if v_assignment_id is not null then
    select * into v_assignment
    from public.section_accompanists
    where id = v_assignment_id;
    if not found then raise exception 'Korepetitor nije pronadjen.'; end if;
    v_society_id := v_assignment.society_id;
    v_section_id := v_assignment.section_id;
    v_person_id := v_assignment.person_id;
  end if;

  if v_society_id is null or v_section_id is null then
    raise exception 'Drustvo i sekcija su obavezni.';
  end if;

  select member.id, member.person_id
  into v_actor_member_id, v_actor_person_id
  from public.society_members member
  join public.people person on person.id = member.person_id
  where member.society_id = v_society_id
    and member.status = 'ACTIVE'
    and coalesce(member.user_id, person.user_id) = v_user_id
  limit 1;

  if v_actor_member_id is null or not public.permissions_can_access_section(
    v_society_id, v_actor_member_id, v_actor_person_id,
    v_section_id, 'sections.manage_accompanists'
  ) then
    raise exception 'Nemate dozvolu za upravljanje korepetitorima ove sekcije.';
  end if;

  if p_action = 'ASSIGN' then
    if v_person_id is null then raise exception 'Osoba je obavezna.'; end if;
    insert into public.section_accompanists (
      society_id, section_id, person_id, attendance_enabled, status,
      active_from, active_until, created_by_user_id, updated_by_user_id
    ) values (
      v_society_id, v_section_id, v_person_id,
      coalesce((p_payload ->> 'attendance_enabled')::boolean, false),
      'ACTIVE', current_date, null, v_user_id, v_user_id
    )
    on conflict (section_id, person_id) do update
    set status = 'ACTIVE',
        attendance_enabled = excluded.attendance_enabled,
        active_until = null,
        updated_by_user_id = v_user_id,
        updated_at = now()
    returning * into v_assignment;
  elsif p_action = 'CREATE_AND_ASSIGN' then
    if nullif(btrim(p_payload ->> 'first_name'), '') is null
       or nullif(btrim(p_payload ->> 'last_name'), '') is null then
      raise exception 'Ime i prezime su obavezni.';
    end if;
    if nullif(lower(btrim(p_payload ->> 'email')), '') is not null then
      select id into v_person_id
      from public.people
      where lower(email) = lower(btrim(p_payload ->> 'email'))
      limit 1;
    end if;
    if v_person_id is null then
      insert into public.people (
        first_name, last_name, email, phone, country
      ) values (
        btrim(p_payload ->> 'first_name'),
        btrim(p_payload ->> 'last_name'),
        nullif(lower(btrim(p_payload ->> 'email')), ''),
        nullif(btrim(p_payload ->> 'phone'), ''),
        'Srbija'
      ) returning id into v_person_id;
    end if;
    return public.auth_manage_section_accompanist(
      'ASSIGN',
      p_payload || jsonb_build_object('person_id', v_person_id)
    );
  elsif p_action = 'SET_ATTENDANCE' then
    update public.section_accompanists
    set attendance_enabled = coalesce(
          (p_payload ->> 'attendance_enabled')::boolean, false
        ),
        updated_by_user_id = v_user_id,
        updated_at = now()
    where id = v_assignment_id
    returning * into v_assignment;
  elsif p_action = 'DEACTIVATE' then
    update public.section_accompanists
    set status = 'INACTIVE',
        attendance_enabled = false,
        active_until = current_date,
        updated_by_user_id = v_user_id,
        updated_at = now()
    where id = v_assignment_id
    returning * into v_assignment;
  else
    raise exception 'Nepoznata akcija.';
  end if;

  return to_jsonb(v_assignment);
end;
$$;

create or replace function public.auth_search_accompanist_people(
  p_society_id uuid,
  p_section_id uuid,
  p_query text
) returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_actor_member_id uuid;
  v_actor_person_id uuid;
  v_result jsonb;
begin
  select member.id, member.person_id
  into v_actor_member_id, v_actor_person_id
  from public.society_members member
  join public.people person on person.id = member.person_id
  where member.society_id = p_society_id
    and member.status = 'ACTIVE'
    and coalesce(member.user_id, person.user_id) = auth.uid()
  limit 1;

  if v_actor_member_id is null or not public.permissions_can_access_section(
    p_society_id, v_actor_member_id, v_actor_person_id,
    p_section_id, 'sections.manage_accompanists'
  ) then
    raise exception 'Nemate dozvolu za pretragu korepetitora.';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'personId', person.id,
    'name', concat_ws(' ', person.first_name, person.last_name),
    'email', person.email,
    'phone', person.phone
  ) order by person.last_name, person.first_name), '[]'::jsonb)
  into v_result
  from public.people person
  where length(btrim(coalesce(p_query, ''))) >= 2
    and concat_ws(
      ' ', person.first_name, person.last_name, person.email, person.phone
    ) ilike '%' || btrim(p_query) || '%'
    and not exists (
      select 1 from public.section_accompanists existing
      where existing.section_id = p_section_id
        and existing.person_id = person.id
        and existing.status = 'ACTIVE'
    );

  return v_result;
end;
$$;

revoke all on function public.auth_manage_section_accompanist(text,jsonb)
  from public, anon;
grant execute on function public.auth_manage_section_accompanist(text,jsonb)
  to authenticated;
revoke all on function public.auth_search_accompanist_people(uuid,uuid,text)
  from public, anon;
grant execute on function public.auth_search_accompanist_people(uuid,uuid,text)
  to authenticated;

commit;
