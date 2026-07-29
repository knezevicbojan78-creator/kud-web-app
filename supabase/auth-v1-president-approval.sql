-- FOLKLORAS — AUTH V1 / PRESIDENT APPROVAL
--
-- Atomsko Master admin odobravanje predsednickog zahteva.
-- Licenca se dodeljuje kao PENDING_ONBOARDING i ne pocinje da tece
-- dok predsednik ne zavrsi obavezni onboarding.

begin;

do $$
declare
  v_constraint record;
begin
  for v_constraint in
    select c.conname
    from pg_constraint c
    where c.conrelid = 'public.societies'::regclass
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) ilike '%status%'
  loop
    execute format('alter table public.societies drop constraint %I', v_constraint.conname);
  end loop;
end;
$$;

alter table public.societies
  add constraint societies_status_check
  check (status in ('ONBOARDING', 'ACTIVE', 'SUSPENDED'));

create table if not exists public.president_license_assignments (
  id uuid primary key default gen_random_uuid(),
  president_reg_id uuid not null unique
    references public."PresidentReg"(id) on delete restrict,
  society_id uuid not null unique
    references public.societies(id) on delete restrict,
  license_plan_id uuid not null
    references public.platform_license_plans(id) on delete restrict,
  license_kind text not null
    check (license_kind in ('MONTHLY', 'ANNUAL', 'PROMOTIONAL_3', 'PROMOTIONAL_6', 'PROMOTIONAL_12')),
  status text not null default 'PENDING_ONBOARDING'
    check (status in ('PENDING_ONBOARDING', 'ACTIVE', 'CANCELLED')),
  paid_on date null,
  payment_method text null
    check (payment_method is null or payment_method in ('BANK_TRANSFER', 'CASH', 'OTHER')),
  payment_reference text null,
  reason text null,
  approved_by_user_id uuid not null,
  approved_at timestamptz not null default now(),
  activated_at timestamptz null,
  license_period_id uuid null
    references public.society_license_periods(id) on delete restrict,
  constraint president_license_assignment_terms_check check (
    (
      license_kind in ('MONTHLY', 'ANNUAL')
      and paid_on is not null
      and payment_method is not null
    )
    or
    (
      license_kind in ('PROMOTIONAL_3', 'PROMOTIONAL_6', 'PROMOTIONAL_12')
      and length(btrim(coalesce(reason, ''))) > 0
    )
  )
);

alter table public.president_license_assignments enable row level security;
revoke all on table public.president_license_assignments
  from public, anon, authenticated;

create unique index if not exists user_onboarding_state_president_reg_unique_idx
  on public.user_onboarding_state(president_reg_id)
  where president_reg_id is not null;

create or replace function public.master_admin_approve_president_request(
  p_request_id uuid,
  p_license_plan_id uuid,
  p_license_kind text,
  p_paid_on date default null,
  p_payment_method text default null,
  p_payment_reference text default null,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_request public."PresidentReg";
  v_plan public.platform_license_plans;
  v_society_id uuid;
  v_actor_user_id uuid := auth.uid();
  v_actor_email text;
  v_assignment_id uuid;
begin
  perform public.auth_assert_master_admin();

  select * into v_request
  from public."PresidentReg"
  where id = p_request_id
  for update;

  if not found then raise exception 'Zahtev nije pronađen.'; end if;
  if v_request."StatReg" <> 'PENDING' then
    raise exception 'Zahtev je već obrađen.';
  end if;

  select * into v_plan
  from public.platform_license_plans
  where id = p_license_plan_id and status = 'ACTIVE';
  if not found then raise exception 'Aktivan licencni paket nije pronađen.'; end if;

  if p_license_kind not in ('MONTHLY', 'ANNUAL', 'PROMOTIONAL_3', 'PROMOTIONAL_6', 'PROMOTIONAL_12') then
    raise exception 'Vrsta licence nije dozvoljena.';
  end if;

  if p_license_kind in ('MONTHLY', 'ANNUAL') then
    if p_paid_on is null then raise exception 'Datum uplate je obavezan.'; end if;
    if p_paid_on > current_date then raise exception 'Datum uplate ne može biti u budućnosti.'; end if;
    if p_payment_method not in ('BANK_TRANSFER', 'CASH', 'OTHER') then
      raise exception 'Način uplate nije dozvoljen.';
    end if;
  elsif length(btrim(coalesce(p_reason, ''))) = 0 then
    raise exception 'Razlog promotivne licence je obavezan.';
  end if;

  if exists (
    select 1 from public.societies s
    where btrim(s.pib) = btrim(v_request."PIB")
       or btrim(s.registration_number) = btrim(v_request."registrationNumber")
  ) then
    raise exception 'Društvo sa ovim PIB-om ili matičnim brojem već postoji.';
  end if;

  select pa.email into v_actor_email
  from public.platform_admins pa
  where pa.user_id = v_actor_user_id and pa.status = 'ACTIVE';

  insert into public.societies (
    name, address, city, postal_code, country, pib, registration_number,
    bank_account, license_type, license_price, base_currency,
    default_membership_fee_amount, finance_start_month, status
  )
  values (
    v_request."societyName", v_request.address, v_request.city,
    v_request."postalCode", v_request.country, v_request."PIB",
    v_request."registrationNumber", v_request."bankAccount",
    v_plan.name,
    case when p_license_kind = 'MONTHLY' then v_plan.monthly_price
         when p_license_kind = 'ANNUAL' then v_plan.annual_price
         else 0 end,
    coalesce(v_request."baseCurrency", 'RSD'),
    v_request."membershipFeeAmount",
    (date_trunc('month', current_date) + interval '1 month')::date,
    'ONBOARDING'
  )
  returning id into v_society_id;

  insert into public.president_license_assignments (
    president_reg_id, society_id, license_plan_id, license_kind,
    paid_on, payment_method, payment_reference, reason, approved_by_user_id
  )
  values (
    v_request.id, v_society_id, v_plan.id, p_license_kind,
    case when p_license_kind in ('MONTHLY', 'ANNUAL') then p_paid_on else null end,
    case when p_license_kind in ('MONTHLY', 'ANNUAL') then p_payment_method else null end,
    nullif(btrim(coalesce(p_payment_reference, '')), ''),
    case when p_license_kind like 'PROMOTIONAL_%' then btrim(p_reason) else null end,
    v_actor_user_id
  )
  returning id into v_assignment_id;

  update public."PresidentReg"
  set
    "StatReg" = 'APPROVED',
    "approvedAt" = now(),
    "approvedByEmail" = v_actor_email,
    "societyId" = v_society_id,
    "licenseType" = v_plan.name,
    "licensePrice" = case
      when p_license_kind = 'MONTHLY' then v_plan.monthly_price
      when p_license_kind = 'ANNUAL' then v_plan.annual_price
      else 0
    end
  where id = v_request.id;

  insert into public.master_admin_audit_log (
    action, entity_type, entity_id, society_id, new_values, reason,
    actor_user_id, actor_email
  )
  values (
    'PRESIDENT_REQUEST_APPROVED', 'PRESIDENT_REGISTRATION', v_request.id,
    v_society_id,
    jsonb_build_object(
      'license_assignment_id', v_assignment_id,
      'license_plan_id', v_plan.id,
      'license_kind', p_license_kind,
      'society_status', 'ONBOARDING'
    ),
    nullif(btrim(coalesce(p_reason, '')), ''),
    v_actor_user_id, v_actor_email
  );

  return jsonb_build_object(
    'request_id', v_request.id,
    'society_id', v_society_id,
    'president_email', lower(btrim(v_request."presidentEmail")),
    'society_name', v_request."societyName",
    'license_assignment_id', v_assignment_id,
    'status', 'APPROVED'
  );
end;
$$;

revoke all on function public.master_admin_approve_president_request(
  uuid, uuid, text, date, text, text, text
) from public, anon;
grant execute on function public.master_admin_approve_president_request(
  uuid, uuid, text, date, text, text, text
) to authenticated;

create or replace function public.auth_activate_approved_president()
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_request public."PresidentReg";
begin
  if v_user_id is null then raise exception 'Prijava je obavezna.'; end if;

  select lower(btrim(u.email)) into v_email
  from auth.users u
  where u.id = v_user_id and u.email_confirmed_at is not null;
  if v_email is null then raise exception 'Email naloga mora biti potvrđen.'; end if;

  if exists (
    select 1 from public.platform_admins pa where pa.user_id = v_user_id
  ) then
    raise exception 'Master admin ne može biti predsednik društva.';
  end if;

  select * into v_request
  from public."PresidentReg" pr
  where lower(btrim(pr."presidentEmail")) = v_email
    and pr."StatReg" = 'APPROVED'
    and pr."societyId" is not null
    and (pr."presidentUserId" is null or pr."presidentUserId" = v_user_id)
  order by pr."approvedAt" desc
  limit 1
  for update;

  if not found then
    raise exception 'Odobren predsednički zahtev nije pronađen za ovaj email.';
  end if;

  update public."PresidentReg"
  set "presidentUserId" = v_user_id
  where id = v_request.id;

  insert into public.user_onboarding_state (
    user_id, society_id, president_reg_id,
    president_profile_completed, president_permissions_bootstrapped
  )
  values (
    v_user_id, v_request."societyId", v_request.id, false, false
  )
  on conflict do nothing;

  return jsonb_build_object(
    'request_id', v_request.id,
    'society_id', v_request."societyId",
    'society_name', v_request."societyName",
    'onboarding_required', true
  );
end;
$$;

revoke all on function public.auth_activate_approved_president()
  from public, anon;
grant execute on function public.auth_activate_approved_president()
  to authenticated;

select pg_notify('pgrst', 'reload schema');

commit;
