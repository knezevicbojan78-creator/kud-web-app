create table public.people (
  id uuid not null default gen_random_uuid(),
  first_name text not null,
  last_name text not null,
  gender text null,
  address text null,
  city text null,
  postal_code text null,
  country text null default 'Srbija',
  jmbg text null,
  passport_number text null,
  passport_expiry_date date null,
  email text null,
  phone text null,
  birth_date date null,
  user_id uuid null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint people_pkey primary key (id)
) TABLESPACE pg_default;

create index if not exists people_passport_expiry_date_idx
  on public.people(passport_expiry_date)
  where passport_expiry_date is not null;
