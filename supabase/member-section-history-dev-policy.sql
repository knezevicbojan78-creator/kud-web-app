-- DEV WORKAROUND: temporary RLS policies for member_section_history.
--
-- Use this only while the application is still running in the DEV model
-- without the final Supabase Auth + role-based permission system.
-- Remove this file/policies when final Auth and role-based RLS rules are introduced.

alter table public.member_section_history enable row level security;

drop policy if exists "dev_member_section_history_select"
on public.member_section_history;

drop policy if exists "dev_member_section_history_insert"
on public.member_section_history;

drop policy if exists "dev_member_section_history_update"
on public.member_section_history;

drop policy if exists "dev_member_section_history_delete"
on public.member_section_history;

grant select, insert, update, delete
on table public.member_section_history
to anon, authenticated;

create policy "dev_member_section_history_select"
on public.member_section_history
for select
to anon, authenticated
using (true);

create policy "dev_member_section_history_insert"
on public.member_section_history
for insert
to anon, authenticated
with check (true);

create policy "dev_member_section_history_update"
on public.member_section_history
for update
to anon, authenticated
using (true)
with check (true);

create policy "dev_member_section_history_delete"
on public.member_section_history
for delete
to anon, authenticated
using (true);
