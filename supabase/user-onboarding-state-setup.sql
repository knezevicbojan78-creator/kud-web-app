create table public.user_onboarding_state (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null,
  society_id uuid not null,
  president_reg_id uuid null,
  president_profile_completed boolean not null default false,
  president_permissions_bootstrapped boolean not null default false,
  completed_at timestamp with time zone null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint user_onboarding_state_pkey primary key (id),
  constraint user_onboarding_state_president_reg_id_fkey foreign KEY (president_reg_id) references "PresidentReg" (id),
  constraint user_onboarding_state_society_id_fkey foreign KEY (society_id) references societies (id)
) TABLESPACE pg_default;
