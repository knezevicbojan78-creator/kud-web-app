create table if not exists public.member_section_history (
  id uuid primary key default gen_random_uuid(),
  member_section_id uuid not null references public.member_sections(id) on delete cascade,
  society_id uuid not null references public.societies(id) on delete cascade,
  section_id uuid not null references public.sections(id) on delete cascade,
  society_member_id uuid not null references public.society_members(id) on delete cascade,
  old_status text null,
  new_status text not null,
  effective_date date not null default current_date,
  changed_by_user_id uuid null,
  note text null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'member_section_history_new_status_check'
      and conrelid = 'public.member_section_history'::regclass
  ) then
    alter table public.member_section_history
      add constraint member_section_history_new_status_check
      check (new_status in ('ACTIVE', 'INACTIVE'));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'member_section_history_old_status_check'
      and conrelid = 'public.member_section_history'::regclass
  ) then
    alter table public.member_section_history
      add constraint member_section_history_old_status_check
      check (old_status is null or old_status in ('ACTIVE', 'INACTIVE'));
  end if;
end $$;

create index if not exists member_section_history_member_section_id_idx
  on public.member_section_history(member_section_id);

create index if not exists member_section_history_society_id_idx
  on public.member_section_history(society_id);

create index if not exists member_section_history_section_id_idx
  on public.member_section_history(section_id);

create index if not exists member_section_history_society_member_id_idx
  on public.member_section_history(society_member_id);

create index if not exists member_section_history_effective_date_idx
  on public.member_section_history(effective_date);

create index if not exists member_section_history_new_status_idx
  on public.member_section_history(new_status);
