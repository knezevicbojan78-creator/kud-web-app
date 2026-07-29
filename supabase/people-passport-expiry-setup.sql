-- FOLKLORAS DEV/V1
-- Datum vazenja pasosa na identitetu osobe.
-- Fajl je bezbedan za ponovno izvrsavanje.

alter table public.people
  add column if not exists passport_expiry_date date null;

create index if not exists people_passport_expiry_date_idx
  on public.people(passport_expiry_date)
  where passport_expiry_date is not null;

select pg_notify('pgrst', 'reload schema');

select
  column_name,
  data_type,
  is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name = 'people'
  and column_name = 'passport_expiry_date';
