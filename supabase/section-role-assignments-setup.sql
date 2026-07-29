alter table public.sections
  add column if not exists status text not null default 'ACTIVE';

alter table public.member_sections
  add column if not exists status text not null default 'ACTIVE';

create table if not exists public.section_role_assignments (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete cascade,
  section_id uuid not null references public.sections(id) on delete cascade,
  society_member_id uuid not null references public.society_members(id) on delete cascade,
  role text not null,
  status text not null default 'ACTIVE',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conname = 'section_role_assignments_society_id_fkey'
      and conrelid = 'public.section_role_assignments'::regclass
      and confdeltype <> 'c'
  ) then
    alter table public.section_role_assignments
      drop constraint section_role_assignments_society_id_fkey;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'section_role_assignments_society_id_fkey'
      and conrelid = 'public.section_role_assignments'::regclass
  ) then
    alter table public.section_role_assignments
      add constraint section_role_assignments_society_id_fkey
      foreign key (society_id)
      references public.societies(id)
      on delete cascade;
  end if;

  if exists (
    select 1
    from pg_constraint
    where conname = 'section_role_assignments_section_id_fkey'
      and conrelid = 'public.section_role_assignments'::regclass
      and confdeltype <> 'c'
  ) then
    alter table public.section_role_assignments
      drop constraint section_role_assignments_section_id_fkey;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'section_role_assignments_section_id_fkey'
      and conrelid = 'public.section_role_assignments'::regclass
  ) then
    alter table public.section_role_assignments
      add constraint section_role_assignments_section_id_fkey
      foreign key (section_id)
      references public.sections(id)
      on delete cascade;
  end if;

  if exists (
    select 1
    from pg_constraint
    where conname = 'section_role_assignments_society_member_id_fkey'
      and conrelid = 'public.section_role_assignments'::regclass
      and confdeltype <> 'c'
  ) then
    alter table public.section_role_assignments
      drop constraint section_role_assignments_society_member_id_fkey;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'section_role_assignments_society_member_id_fkey'
      and conrelid = 'public.section_role_assignments'::regclass
  ) then
    alter table public.section_role_assignments
      add constraint section_role_assignments_society_member_id_fkey
      foreign key (society_member_id)
      references public.society_members(id)
      on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'sections_status_check'
  ) then
    alter table public.sections
      add constraint sections_status_check
      check (status in ('ACTIVE', 'INACTIVE'));
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'member_sections_status_check'
  ) then
    alter table public.member_sections
      add constraint member_sections_status_check
      check (status in ('ACTIVE', 'INACTIVE'));
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'section_role_assignments_role_check'
  ) then
    alter table public.section_role_assignments
      add constraint section_role_assignments_role_check
      check (role in ('UR', 'KOREPETITOR'));
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'section_role_assignments_status_check'
  ) then
    alter table public.section_role_assignments
      add constraint section_role_assignments_status_check
      check (status in ('ACTIVE', 'INACTIVE'));
  end if;
end $$;

create unique index if not exists member_sections_unique_member_section
  on public.member_sections(section_id, society_member_id);

create unique index if not exists section_role_assignments_unique_role
  on public.section_role_assignments(section_id, society_member_id, role);

create index if not exists section_role_assignments_society_id_idx
  on public.section_role_assignments(society_id);

create index if not exists section_role_assignments_section_id_idx
  on public.section_role_assignments(section_id);

create index if not exists section_role_assignments_society_member_id_idx
  on public.section_role_assignments(society_member_id);

create index if not exists section_role_assignments_role_idx
  on public.section_role_assignments(role);

create index if not exists section_role_assignments_status_idx
  on public.section_role_assignments(status);
