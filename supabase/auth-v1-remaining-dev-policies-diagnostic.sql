-- FOLKLORAS — AUTH V1 / PREOSTALE DEV POLITIKE
-- Read-only dijagnostika. Ne menja podatke ni dozvole.

select
  schemaname,
  tablename,
  policyname,
  cmd,
  permissive,
  roles,
  qual,
  with_check
from pg_policies
where schemaname = 'public'
  and policyname ilike 'dev%'
order by tablename, cmd, policyname;
