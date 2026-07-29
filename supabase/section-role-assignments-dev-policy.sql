-- DEV WORKAROUND: temporary RLS policies for section_role_assignments.
--
-- Use this only while the application is still running in the DEV model
-- without the final Supabase Auth + role-based permission system.
-- Remove this file/policies when final Auth and role-based RLS rules are introduced.
--
-- Why this exists:
-- The local app currently uses NEXT_PUBLIC_SUPABASE_ANON_KEY. Until final
-- Supabase Auth/RLS is introduced, assigning UR/KOREPETITOR from the UI must
-- work for both anon and authenticated test sessions.
--
-- DEV reset note:
-- This script intentionally removes every existing policy on this table before
-- creating the temporary wide-open DEV policies below. Do not run this in
-- production and do not treat it as the final permission model.

alter table public.section_role_assignments enable row level security;

do $$
declare
  policy_record record;
begin
  for policy_record in
    select policyname
    from pg_policies
    where schemaname = 'public'
      and tablename = 'section_role_assignments'
  loop
    execute format(
      'drop policy if exists %I on public.section_role_assignments',
      policy_record.policyname
    );
  end loop;
end $$;

grant select, insert, update, delete
on table public.section_role_assignments
to anon, authenticated;

create policy "dev_section_role_assignments_select"
on public.section_role_assignments
for select
to anon, authenticated
using (true);

create policy "dev_section_role_assignments_insert"
on public.section_role_assignments
for insert
to anon, authenticated
with check (true);

create policy "dev_section_role_assignments_update"
on public.section_role_assignments
for update
to anon, authenticated
using (true)
with check (true);

create policy "dev_section_role_assignments_delete"
on public.section_role_assignments
for delete
to anon, authenticated
using (true);
