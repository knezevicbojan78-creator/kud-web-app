-- FOLKLORAS — AUTH V1 / PUBLIC PRESIDENT REQUEST
--
-- Minimalan zahtev predsednika, bez lozinke, licence i detaljnog onboardinga.
-- Primeniti nakon auth-v1-master-admin-foundation.sql.

begin;

alter table public."PresidentReg"
  alter column "presidentGender" drop not null,
  alter column password drop not null,
  alter column "confirmPassword" drop not null;

alter table public."PresidentReg"
  add column if not exists "requestedLicensePlanId" uuid null
  references public.platform_license_plans(id) on delete restrict;

alter table public."PresidentReg"
  add column if not exists "requestedLicenseKind" text null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'president_reg_requested_license_kind_check'
      and conrelid = 'public."PresidentReg"'::regclass
  ) then
    alter table public."PresidentReg"
      add constraint president_reg_requested_license_kind_check
      check ("requestedLicenseKind" is null or "requestedLicenseKind" in ('MONTHLY', 'ANNUAL'));
  end if;
end;
$$;

update public."PresidentReg"
set "requestedLicenseKind" = 'MONTHLY'
where "requestedLicenseKind" is null
  and "StatReg" = 'PENDING'
  and "requestedLicensePlanId" is not null;

-- Javni klijent više ne upisuje direktno u tabelu.
revoke insert on table public."PresidentReg" from anon, authenticated;

drop policy if exists "anon_insert_pending_president_reg"
  on public."PresidentReg";

create unique index if not exists president_reg_one_pending_email_idx
  on public."PresidentReg" (lower(btrim("presidentEmail")))
  where "StatReg" = 'PENDING';

create unique index if not exists president_reg_one_pending_pib_idx
  on public."PresidentReg" (btrim("PIB"))
  where "StatReg" = 'PENDING';

create unique index if not exists president_reg_one_pending_registration_number_idx
  on public."PresidentReg" (btrim("registrationNumber"))
  where "StatReg" = 'PENDING';

create or replace function public.auth_get_public_license_plans()
returns table (
  id uuid,
  code text,
  name text,
  description text,
  monthly_price numeric,
  annual_price numeric,
  currency text,
  active_member_limit integer,
  active_section_limit integer
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    p.id, p.code, p.name, p.description, p.monthly_price, p.annual_price,
    p.currency, p.active_member_limit, p.active_section_limit
  from public.platform_license_plans p
  where p.status = 'ACTIVE'
  order by p.active_member_limit nulls last, p.name;
$$;

revoke all on function public.auth_get_public_license_plans() from public;
grant execute on function public.auth_get_public_license_plans()
  to anon, authenticated;

drop function if exists public.auth_submit_president_request(
  text, text, text, text, text, text, text, text, text, text
);
drop function if exists public.auth_submit_president_request(
  text, text, text, text, text, text, text, text, text, text, uuid
);

create or replace function public.auth_submit_president_request(
  p_society_name text,
  p_address text,
  p_city text,
  p_country text,
  p_pib text,
  p_registration_number text,
  p_president_first_name text,
  p_president_last_name text,
  p_president_email text,
  p_president_phone text,
  p_requested_license_plan_id uuid,
  p_requested_license_kind text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id uuid;
  v_email text := lower(btrim(p_president_email));
  v_plan public.platform_license_plans;
begin
  if not exists (
    select 1 from public.platform_admins where status = 'ACTIVE'
  ) then
    raise exception using
      errcode = '42501',
      message = 'Registracija još nije dostupna.';
  end if;

  if length(btrim(coalesce(p_society_name, ''))) < 2
    or length(btrim(coalesce(p_address, ''))) < 3
    or length(btrim(coalesce(p_city, ''))) < 2
    or length(btrim(coalesce(p_country, ''))) < 2
    or length(btrim(coalesce(p_pib, ''))) < 5
    or length(btrim(coalesce(p_registration_number, ''))) < 5
    or length(btrim(coalesce(p_president_first_name, ''))) < 2
    or length(btrim(coalesce(p_president_last_name, ''))) < 2
    or length(btrim(coalesce(p_president_phone, ''))) < 6
  then
    raise exception 'Popunite sva obavezna polja ispravnim podacima.';
  end if;

  if v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'Unesite ispravnu email adresu.';
  end if;

  if v_email = 'knezevic.bojan78@gmail.com' then
    raise exception 'Master admin email ne može biti predsednički nalog.';
  end if;

  select * into v_plan
  from public.platform_license_plans p
  where p.id = p_requested_license_plan_id
    and p.status = 'ACTIVE';

  if not found then
    raise exception 'Izaberite važeći licencni paket.';
  end if;

  if p_requested_license_kind not in ('MONTHLY', 'ANNUAL') then
    raise exception 'Izaberite mesečnu ili godišnju licencu.';
  end if;

  if exists (
    select 1 from public.societies s
    where btrim(s.pib) = btrim(p_pib)
       or btrim(s.registration_number) = btrim(p_registration_number)
  ) then
    raise exception 'Društvo sa ovim PIB-om ili matičnim brojem već postoji.';
  end if;

  insert into public."PresidentReg" (
    "societyName", address, city, country, "PIB", "registrationNumber",
    "presidentFirstName", "presidentLastName", "presidentPhone",
    "presidentEmail", "presidentGender", password, "confirmPassword",
    "licenseType", "licensePrice", "requestedLicensePlanId",
    "requestedLicenseKind", "StatReg"
  )
  values (
    btrim(p_society_name), btrim(p_address), btrim(p_city), btrim(p_country),
    btrim(p_pib), btrim(p_registration_number),
    btrim(p_president_first_name), btrim(p_president_last_name),
    btrim(p_president_phone), v_email, null, null, null,
    v_plan.name,
    case when p_requested_license_kind = 'ANNUAL'
      then v_plan.annual_price else v_plan.monthly_price end,
    p_requested_license_plan_id, p_requested_license_kind, 'PENDING'
  )
  returning id into v_id;

  return jsonb_build_object(
    'request_id', v_id,
    'status', 'PENDING'
  );
exception
  when unique_violation then
    raise exception 'Već postoji zahtev sa ovim emailom, PIB-om ili matičnim brojem.';
end;
$$;

revoke all on function public.auth_submit_president_request(
  text, text, text, text, text, text, text, text, text, text, uuid, text
) from public;

grant execute on function public.auth_submit_president_request(
  text, text, text, text, text, text, text, text, text, text, uuid, text
) to anon, authenticated;

select pg_notify('pgrst', 'reload schema');

commit;
