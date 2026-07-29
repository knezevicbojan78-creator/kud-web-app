alter table public.member_sections
  add column if not exists status text not null default 'ACTIVE';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'member_sections_status_check'
  ) then
    alter table public.member_sections
      add constraint member_sections_status_check
      check (status in ('ACTIVE', 'INACTIVE'));
  end if;
end $$;
