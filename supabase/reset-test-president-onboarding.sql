-- DEV/V1: kontrolisani reset zavrsenog predsednickog onboardinga.
-- Auth nalog, odobren zahtev, drustvo i izbor licence ostaju sacuvani.
-- Podaci drustva ostaju sacuvani, pa isti predsednik ponovo prolazi
-- korake Predsednik i Potvrda.
--
-- OVAJ FAJL JE SAMO ZA TEST PODATKE.
-- Pre pokretanja proverite vrednost v_target_email.

begin;

do $$
declare
  v_target_email constant text := 'kud.mitance@gmail.com';
  v_target_count integer;
  v_user_id uuid;
  v_society_id uuid;
  v_onboarding_id uuid;
  v_assignment_id uuid;
  v_license_period_id uuid;
  v_payment_id uuid;
  v_person_id uuid;
  v_member_id uuid;
begin
  select count(*)
  into v_target_count
  from public.user_onboarding_state uos
  join auth.users au on au.id = uos.user_id
  join public."PresidentReg" pr on pr.id = uos.president_reg_id
  where lower(btrim(au.email)) = lower(btrim(v_target_email))
    and lower(btrim(pr."presidentEmail")) = lower(btrim(v_target_email))
    and pr."StatReg" = 'APPROVED'
    and uos.completed_at is not null;

  if v_target_count <> 1 then
    raise exception
      'Reset nije izvrsen: za email % pronadjeno je % zavrsenih onboardinga, a ocekuje se tacno 1.',
      v_target_email,
      v_target_count;
  end if;

  select
    uos.id,
    uos.user_id,
    uos.society_id
  into
    v_onboarding_id,
    v_user_id,
    v_society_id
  from public.user_onboarding_state uos
  join auth.users au on au.id = uos.user_id
  join public."PresidentReg" pr on pr.id = uos.president_reg_id
  where lower(btrim(au.email)) = lower(btrim(v_target_email))
    and lower(btrim(pr."presidentEmail")) = lower(btrim(v_target_email))
    and pr."StatReg" = 'APPROVED'
    and uos.completed_at is not null
  for update of uos;

  select
    pla.id,
    pla.license_period_id
  into
    v_assignment_id,
    v_license_period_id
  from public.president_license_assignments pla
  where pla.society_id = v_society_id
    and pla.status = 'ACTIVE'
  for update;

  if v_assignment_id is null or v_license_period_id is null then
    raise exception 'Reset nije izvrsen: aktivirana predsednicka licenca nije pronadjena.';
  end if;

  if exists (
    select 1
    from public.platform_license_notifications pln
    where pln.license_period_id = v_license_period_id
  ) or exists (
    select 1
    from public.society_suspensions ss
    where ss.related_license_period_id = v_license_period_id
  ) then
    raise exception
      'Reset nije izvrsen: licenca vec ima dodatnu istoriju obavestenja ili suspenzije.';
  end if;

  select slp.payment_id
  into v_payment_id
  from public.society_license_periods slp
  where slp.id = v_license_period_id
    and slp.society_id = v_society_id
  for update;

  select p.id
  into v_person_id
  from public.people p
  where p.user_id = v_user_id;

  if v_person_id is null then
    raise exception 'Reset nije izvrsen: profil predsednika nije pronadjen.';
  end if;

  select sm.id
  into v_member_id
  from public.society_members sm
  where sm.society_id = v_society_id
    and sm.person_id = v_person_id;

  if v_member_id is null then
    raise exception 'Reset nije izvrsen: clanstvo predsednika nije pronadjeno.';
  end if;

  -- Uklanjaju se samo podaci koje je kreirao zavrsetak ovog onboardinga.
  delete from public.society_member_function_assignments
  where society_member_id = v_member_id;

  delete from public.member_status_history
  where society_member_id = v_member_id;

  delete from public.society_members
  where id = v_member_id;

  delete from public.people
  where id = v_person_id
    and user_id = v_user_id;

  -- Dodeljena licenca ostaje, ali se vraca na cekanje zavrsetka onboardinga.
  update public.president_license_assignments
  set
    status = 'PENDING_ONBOARDING',
    activated_at = null,
    license_period_id = null
  where id = v_assignment_id;

  delete from public.master_admin_audit_log
  where society_id = v_society_id
    and (
      (entity_type = 'LICENSE_PERIOD' and entity_id = v_license_period_id)
      or
      (entity_type = 'LICENSE_PAYMENT' and entity_id = v_payment_id)
    );

  delete from public.society_license_periods
  where id = v_license_period_id;

  if v_payment_id is not null then
    delete from public.platform_license_payments
    where id = v_payment_id;
  end if;

  update public.societies
  set status = 'ONBOARDING'
  where id = v_society_id;

  update public.user_onboarding_state
  set
    president_profile_completed = false,
    president_permissions_bootstrapped = false,
    completed_at = null,
    updated_at = now()
  where id = v_onboarding_id;

  raise notice
    'Reset zavrsen za %, society_id=%, user_id=%. Auth nalog i odobren zahtev su sacuvani.',
    v_target_email,
    v_society_id,
    v_user_id;
end;
$$;

commit;

-- Rezultat mora biti tacno jedan red:
-- completed = false, society_status = ONBOARDING,
-- assignment_status = PENDING_ONBOARDING, license_period_id = null.
select
  au.email,
  uos.completed_at is not null as completed,
  uos.society_profile_completed,
  uos.president_profile_completed,
  s.name as society_name,
  s.status as society_status,
  pla.status as assignment_status,
  pla.license_period_id
from public.user_onboarding_state uos
join auth.users au on au.id = uos.user_id
join public.societies s on s.id = uos.society_id
join public.president_license_assignments pla on pla.society_id = uos.society_id
where lower(btrim(au.email)) = 'kud.mitance@gmail.com';
