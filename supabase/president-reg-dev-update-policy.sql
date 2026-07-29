-- DEV policy for approving or rejecting registration requests while Master
-- admin roles are not connected to Supabase Auth yet.
--
-- Run this only in development. The final policy should later check the
-- Master admin role explicitly and should not use anon updates.

alter table public."PresidentReg" enable row level security;

drop policy if exists "dev_anon_update_pending_president_reg_status"
on public."PresidentReg";

grant update ("StatReg", "approvedAt", "approvedByEmail", "societyId")
on table public."PresidentReg"
to anon;

create policy "dev_anon_update_pending_president_reg_status"
on public."PresidentReg"
for update
to anon
using ("StatReg" = 'PENDING')
with check (
  "StatReg" in ('APPROVED', 'REJECTED')
  and "approvedByEmail" = 'master@dev.local'
);
