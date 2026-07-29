-- DEV WORKAROUND: temporary RLS policies for sections.
--
-- Use this only while the application is still running in the DEV model
-- without the final Supabase Auth + role-based permission system.
-- Remove this file/policies when final Auth and role-based RLS rules are introduced.
--
-- The local app uses NEXT_PUBLIC_SUPABASE_ANON_KEY. Until final Auth/RLS is
-- introduced, MOJE SEKCIJE needs to rename, deactivate, reactivate and read
-- sections from local test sessions.
--
-- Do not run this in production and do not treat it as the final permission
-- model.

alter table public.sections enable row level security;

drop policy if exists "dev_sections_select"
on public.sections;

drop policy if exists "dev_sections_insert"
on public.sections;

drop policy if exists "dev_sections_update"
on public.sections;

drop policy if exists "dev_sections_delete"
on public.sections;

grant select, insert, update, delete
on table public.sections
to anon, authenticated;

create policy "dev_sections_select"
on public.sections
for select
to anon, authenticated
using (true);

create policy "dev_sections_insert"
on public.sections
for insert
to anon, authenticated
with check (true);

create policy "dev_sections_update"
on public.sections
for update
to anon, authenticated
using (true)
with check (true);

create policy "dev_sections_delete"
on public.sections
for delete
to anon, authenticated
using (true);
