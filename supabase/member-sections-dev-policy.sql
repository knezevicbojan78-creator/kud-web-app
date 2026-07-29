-- DEV WORKAROUND: temporary RLS policies for member_sections.
--
-- Use this only while the application is still running in the DEV model
-- without the final Supabase Auth + role-based permission system.
-- Remove this file/policies when final Auth and role-based RLS rules are introduced.

alter table public.member_sections enable row level security;

drop policy if exists "dev_member_sections_select"
on public.member_sections;

drop policy if exists "dev_member_sections_insert"
on public.member_sections;

drop policy if exists "dev_member_sections_update"
on public.member_sections;

drop policy if exists "dev_member_sections_delete"
on public.member_sections;

grant select, insert, update, delete
on table public.member_sections
to anon, authenticated;

create policy "dev_member_sections_select"
on public.member_sections
for select
to anon, authenticated
using (true);

create policy "dev_member_sections_insert"
on public.member_sections
for insert
to anon, authenticated
with check (true);

create policy "dev_member_sections_update"
on public.member_sections
for update
to anon, authenticated
using (true)
with check (true);

create policy "dev_member_sections_delete"
on public.member_sections
for delete
to anon, authenticated
using (true);
