create table public.society_members (
  id uuid not null default gen_random_uuid(),
  society_id uuid not null,
  person_id uuid not null,
  user_id uuid null,
  status text not null default 'ACTIVE',
  start_date date null,
  funkcija text null,
  membership_fee_required boolean not null default true,
  membership_fee_amount numeric null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint society_members_pkey primary key (id),
  constraint society_members_society_id_fkey foreign key (society_id) references societies(id),
  constraint society_members_person_id_fkey foreign key (person_id) references people(id)
) TABLESPACE pg_default;
