-- FOLKLORAS DEV/V1
-- READ-ONLY: stvarna sema tabela potrebnih za testni pristup Finansijama.
-- Upit ne menja podatke ni strukturu baze.

select
  table_name,
  ordinal_position,
  column_name,
  data_type,
  is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name in (
    'societies',
    'society_members',
    'society_member_functions',
    'society_member_function_assignments'
  )
order by table_name, ordinal_position;
