-- FOLKLORAS — AUTH V1 / PRESIDENT ONBOARDING
-- Dva koraka: dopuna drustva, zatim profil predsednika.
-- Zavrsetak atomski aktivira drustvo, predsednicko clanstvo i licencu.

begin;

alter table public.user_onboarding_state
  add column if not exists society_profile_completed boolean not null default false;

create unique index if not exists people_one_auth_user_idx
  on public.people(user_id)
  where user_id is not null;

create unique index if not exists society_members_one_person_per_society_idx
  on public.society_members(society_id, person_id);

create unique index if not exists society_member_function_assignment_unique_idx
  on public.society_member_function_assignments(society_member_id, function_id);

create or replace function public.auth_get_president_onboarding()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_result jsonb;
begin
  if v_user_id is null then raise exception 'Prijava je obavezna.'; end if;

  select jsonb_build_object(
    'society', jsonb_build_object(
      'id', s.id, 'name', s.name, 'address', s.address, 'city', s.city,
      'postal_code', s.postal_code, 'country', s.country, 'pib', s.pib,
      'registration_number', s.registration_number,
      'bank_account', s.bank_account, 'license_type', s.license_type,
      'status', s.status
    ),
    'president', jsonb_build_object(
      'first_name', pr."presidentFirstName",
      'last_name', pr."presidentLastName",
      'email', pr."presidentEmail",
      'phone', pr."presidentPhone"
    ),
    'state', jsonb_build_object(
      'society_profile_completed', uos.society_profile_completed,
      'president_profile_completed', uos.president_profile_completed,
      'completed', uos.completed_at is not null
    )
  ) into v_result
  from public.user_onboarding_state uos
  join public."PresidentReg" pr on pr.id = uos.president_reg_id
  join public.societies s on s.id = uos.society_id
  where uos.user_id = v_user_id
    and pr."presidentUserId" = v_user_id
    and pr."StatReg" = 'APPROVED'
  order by uos.created_at desc
  limit 1;

  if v_result is null then
    raise exception 'Predsednički onboarding nije pronađen.';
  end if;
  return v_result;
end;
$$;

create or replace function public.auth_save_president_society_onboarding(
  p_society jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_state public.user_onboarding_state;
begin
  select uos.* into v_state
  from public.user_onboarding_state uos
  join public."PresidentReg" pr on pr.id = uos.president_reg_id
  where uos.user_id = v_user_id
    and pr."presidentUserId" = v_user_id
    and pr."StatReg" = 'APPROVED'
    and uos.completed_at is null
  order by uos.created_at desc
  limit 1
  for update of uos;

  if not found then raise exception 'Aktivan onboarding nije pronađen.'; end if;

  if length(btrim(coalesce(p_society ->> 'name', ''))) < 2
    or length(btrim(coalesce(p_society ->> 'address', ''))) < 3
    or length(btrim(coalesce(p_society ->> 'city', ''))) < 2
    or length(btrim(coalesce(p_society ->> 'country', ''))) < 2
    or length(btrim(coalesce(p_society ->> 'pib', ''))) < 5
    or length(btrim(coalesce(p_society ->> 'registration_number', ''))) < 5
  then
    raise exception 'Popunite sva obavezna polja društva.';
  end if;

  if exists (
    select 1 from public.societies s
    where s.id <> v_state.society_id
      and (
        btrim(s.pib) = btrim(p_society ->> 'pib')
        or btrim(s.registration_number) = btrim(p_society ->> 'registration_number')
      )
  ) then
    raise exception 'PIB ili matični broj već koristi drugo društvo.';
  end if;

  update public.societies
  set
    name = btrim(p_society ->> 'name'),
    address = btrim(p_society ->> 'address'),
    city = btrim(p_society ->> 'city'),
    postal_code = nullif(btrim(coalesce(p_society ->> 'postal_code', '')), ''),
    country = btrim(p_society ->> 'country'),
    pib = btrim(p_society ->> 'pib'),
    registration_number = btrim(p_society ->> 'registration_number'),
    bank_account = nullif(btrim(coalesce(p_society ->> 'bank_account', '')), '')
  where id = v_state.society_id;

  update public.user_onboarding_state
  set society_profile_completed = true, updated_at = now()
  where id = v_state.id;

  return jsonb_build_object(
    'society_id', v_state.society_id,
    'society_profile_completed', true
  );
end;
$$;

create or replace function public.auth_complete_president_onboarding(
  p_profile jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_state public.user_onboarding_state;
  v_request public."PresidentReg";
  v_person_id uuid;
  v_member_id uuid;
  v_president_function_id uuid;
  v_assignment public.president_license_assignments;
  v_license_result jsonb;
  v_license_period_id uuid;
  v_actor_email text;
begin
  if v_user_id is null then raise exception 'Prijava je obavezna.'; end if;
  select lower(btrim(u.email)) into v_email from auth.users u where u.id = v_user_id;

  select uos.* into v_state
  from public.user_onboarding_state uos
  where uos.user_id = v_user_id
    and uos.completed_at is null
  order by uos.created_at desc
  limit 1
  for update;
  if not found then raise exception 'Aktivan onboarding nije pronađen.'; end if;
  if not v_state.society_profile_completed then
    raise exception 'Prvo završite podatke društva.';
  end if;

  select * into v_request
  from public."PresidentReg" pr
  where pr.id = v_state.president_reg_id
    and pr."presidentUserId" = v_user_id
    and pr."StatReg" = 'APPROVED'
  for update;
  if not found then raise exception 'Odobren predsednički zahtev nije pronađen.'; end if;

  if lower(btrim(coalesce(p_profile ->> 'email', ''))) <> v_email then
    raise exception 'Email predsednika mora odgovarati prijavljenom nalogu.';
  end if;
  if length(btrim(coalesce(p_profile ->> 'first_name', ''))) < 2
    or length(btrim(coalesce(p_profile ->> 'last_name', ''))) < 2
    or coalesce(p_profile ->> 'gender', '') not in ('Muško', 'Žensko')
    or length(btrim(coalesce(p_profile ->> 'phone', ''))) < 6
    or nullif(p_profile ->> 'start_date', '') is null
  then
    raise exception 'Popunite obavezne podatke predsednika.';
  end if;

  insert into public.people (
    first_name, last_name, gender, birth_date, address, city, postal_code,
    country, jmbg, passport_number, passport_expiry_date, email, phone, user_id
  )
  values (
    btrim(p_profile ->> 'first_name'), btrim(p_profile ->> 'last_name'),
    p_profile ->> 'gender', nullif(p_profile ->> 'birth_date', '')::date,
    nullif(btrim(coalesce(p_profile ->> 'address', '')), ''),
    nullif(btrim(coalesce(p_profile ->> 'city', '')), ''),
    nullif(btrim(coalesce(p_profile ->> 'postal_code', '')), ''),
    nullif(btrim(coalesce(p_profile ->> 'country', '')), ''),
    nullif(btrim(coalesce(p_profile ->> 'jmbg', '')), ''),
    nullif(btrim(coalesce(p_profile ->> 'passport_number', '')), ''),
    nullif(p_profile ->> 'passport_expiry_date', '')::date,
    v_email, btrim(p_profile ->> 'phone'), v_user_id
  )
  returning id into v_person_id;

  insert into public.society_members (
    society_id, person_id, user_id, status, start_date, funkcija,
    membership_fee_required, membership_fee_amount
  )
  values (
    v_state.society_id, v_person_id, v_user_id, 'ACTIVE',
    (p_profile ->> 'start_date')::date, 'Predsednik',
    coalesce((p_profile ->> 'membership_fee_required')::boolean, false),
    nullif(p_profile ->> 'membership_fee_amount', '')::numeric
  )
  returning id into v_member_id;

  insert into public.society_member_functions (
    society_id, name, is_system, is_active, sort_order
  )
  select v_state.society_id, defaults.name, true, true, defaults.sort_order
  from (values
    ('Predsednik', 1), ('Sekretar', 2), ('Blagajnik', 3),
    ('Upravnik', 4), ('UR', 5), ('Korepetitor', 6), ('Član', 7)
  ) as defaults(name, sort_order)
  where not exists (
    select 1 from public.society_member_functions smf
    where smf.society_id = v_state.society_id and smf.name = defaults.name
  );

  select id into v_president_function_id
  from public.society_member_functions
  where society_id = v_state.society_id and name = 'Predsednik' and is_active
  limit 1;

  insert into public.society_member_function_assignments (
    society_id, society_member_id, function_id
  )
  values (v_state.society_id, v_member_id, v_president_function_id);

  select * into v_assignment
  from public.president_license_assignments
  where president_reg_id = v_request.id and status = 'PENDING_ONBOARDING'
  for update;
  if not found then raise exception 'Dodeljena licenca nije pronađena.'; end if;

  select pa.email into v_actor_email
  from public.platform_admins pa
  where pa.user_id = v_assignment.approved_by_user_id;

  v_license_result := public.master_admin_grant_license_impl(
    v_state.society_id, v_assignment.license_plan_id, v_assignment.license_kind,
    current_date, v_assignment.paid_on, v_assignment.payment_method,
    v_assignment.payment_reference, v_assignment.reason,
    'Aktivirana završetkom predsedničkog onboardinga.', false,
    v_assignment.approved_by_user_id, v_actor_email
  );
  v_license_period_id := (v_license_result ->> 'license_period_id')::uuid;

  update public.president_license_assignments
  set status = 'ACTIVE', activated_at = now(), license_period_id = v_license_period_id
  where id = v_assignment.id;

  update public.societies set status = 'ACTIVE' where id = v_state.society_id;
  update public.user_onboarding_state
  set
    president_profile_completed = true,
    president_permissions_bootstrapped = true,
    completed_at = now(),
    updated_at = now()
  where id = v_state.id;

  return jsonb_build_object(
    'society_id', v_state.society_id,
    'person_id', v_person_id,
    'society_member_id', v_member_id,
    'license_period_id', v_license_period_id,
    'completed', true
  );
end;
$$;

revoke all on function public.auth_get_president_onboarding() from public, anon;
revoke all on function public.auth_save_president_society_onboarding(jsonb) from public, anon;
revoke all on function public.auth_complete_president_onboarding(jsonb) from public, anon;
grant execute on function public.auth_get_president_onboarding() to authenticated;
grant execute on function public.auth_save_president_society_onboarding(jsonb) to authenticated;
grant execute on function public.auth_complete_president_onboarding(jsonb) to authenticated;

select pg_notify('pgrst', 'reload schema');

commit;
