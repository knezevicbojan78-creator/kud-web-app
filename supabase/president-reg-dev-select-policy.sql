-- DEV policy for reading registration requests while roles are not connected
-- to Supabase Auth yet.
--
-- Run this only in development. The final policy should later check the
-- Master admin role explicitly.

alter table public."PresidentReg" enable row level security;

drop policy if exists "TEMP_DEBUG_SELECT"
on public."PresidentReg";

drop policy if exists "dev_authenticated_select_president_reg"
on public."PresidentReg";

grant select on table public."PresidentReg" to authenticated;

create policy "dev_authenticated_select_president_reg"
on public."PresidentReg"
for select
to authenticated
using (true);
