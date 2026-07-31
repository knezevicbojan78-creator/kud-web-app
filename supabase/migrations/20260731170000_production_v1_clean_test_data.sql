-- Production V1 canonical migration: remove test business data while preserving:
--   * the approved president account kud.mitance@gmail.com;
--   * the connected KUD Mitance society and its active configuration/licence;
--   * every platform admin account;
--   * global permission catalogs, templates and licence plans.
--
-- The guards run before any delete. Every change is atomic.

begin;

do $$
declare
  v_target_user_count integer;
  v_registration_count integer;
  v_context_count integer;
  v_person_count integer;
  v_member_count integer;
  v_platform_admin_count integer;
begin
  select count(*) into v_target_user_count
  from auth.users
  where lower(email) = 'kud.mitance@gmail.com';

  if v_target_user_count <> 1 then
    raise exception
      'CISCENJE ODBIJENO: ocekivan je tacno jedan Auth nalog kud.mitance@gmail.com, pronadjeno: %.',
      v_target_user_count;
  end if;

  select count(*) into v_registration_count
  from public."PresidentReg" registration
  join auth.users account on account.id = registration."presidentUserId"
  where lower(account.email) = 'kud.mitance@gmail.com'
    and lower(registration."presidentEmail") = 'kud.mitance@gmail.com'
    and registration."StatReg" = 'APPROVED';

  if v_registration_count <> 1 then
    raise exception
      'CISCENJE ODBIJENO: ocekivan je tacno jedan odobren predsednicki zahtev, pronadjeno: %.',
      v_registration_count;
  end if;

  select count(*) into v_context_count
  from public.user_onboarding_state onboarding
  join auth.users account on account.id = onboarding.user_id
  join public."PresidentReg" registration on registration.id = onboarding.president_reg_id
  join public.societies society on society.id = onboarding.society_id
  where lower(account.email) = 'kud.mitance@gmail.com'
    and registration."presidentUserId" = account.id
    and registration."StatReg" = 'APPROVED'
    and lower(society.name) like '%mitan%';

  if v_context_count <> 1 then
    raise exception
      'CISCENJE ODBIJENO: KUD Mitance kontekst nije jednoznacan, pronadjeno: %.',
      v_context_count;
  end if;

  select count(*) into v_person_count
  from public.people person
  join auth.users account on account.id = person.user_id
  where lower(account.email) = 'kud.mitance@gmail.com';

  if v_person_count <> 1 then
    raise exception
      'CISCENJE ODBIJENO: profil predsednika nije jednoznacan, pronadjeno: %.',
      v_person_count;
  end if;

  select count(*) into v_member_count
  from public.society_members membership
  join public.people person on person.id = membership.person_id
  join auth.users account on account.id = person.user_id
  join public.user_onboarding_state onboarding
    on onboarding.user_id = account.id
   and onboarding.society_id = membership.society_id
  where lower(account.email) = 'kud.mitance@gmail.com'
    and membership.status = 'ACTIVE';

  if v_member_count <> 1 then
    raise exception
      'CISCENJE ODBIJENO: aktivno clanstvo predsednika nije jednoznacno, pronadjeno: %.',
      v_member_count;
  end if;

  select count(*) into v_platform_admin_count
  from public.platform_admins;

  if v_platform_admin_count < 1 then
    raise exception
      'CISCENJE ODBIJENO: Master Admin nalog nije pronadjen.';
  end if;
end
$$;

create temporary table cleanup_keep_context on commit drop as
select
  account.id as president_user_id,
  registration.id as president_reg_id,
  onboarding.society_id,
  person.id as president_person_id,
  membership.id as president_membership_id
from auth.users account
join public."PresidentReg" registration
  on registration."presidentUserId" = account.id
 and registration."StatReg" = 'APPROVED'
join public.user_onboarding_state onboarding
  on onboarding.user_id = account.id
 and onboarding.president_reg_id = registration.id
join public.societies society on society.id = onboarding.society_id
join public.people person on person.user_id = account.id
join public.society_members membership
  on membership.society_id = society.id
 and membership.person_id = person.id
 and membership.status = 'ACTIVE'
where lower(account.email) = 'kud.mitance@gmail.com'
  and lower(registration."presidentEmail") = 'kud.mitance@gmail.com'
  and lower(society.name) like '%mitan%';

-- Empty transactional/test areas. The list intentionally excludes society
-- configuration, Gmail connection credentials, active licensing, platform admins
-- and global catalogs. Missing legacy tables are safely ignored.
do $$
declare
  v_table text;
  v_tables text[] := array[
    'attendance_record_history', 'attendance_records', 'attendance_sessions',
    'event_repertoire_participants', 'event_appearance_repertoire',
    'event_participant_sections', 'event_participants', 'event_sections',
    'event_appearances', 'event_status_history', 'repertoire_item_sections',
    'repertoire_items', 'person_data_change_requests', 'society_events',
    'financial_obligation_allocations', 'financial_refunds',
    'financial_credit_entries', 'financial_payments', 'financial_obligations',
    'membership_fee_assessments', 'member_fee_setting_history',
    'member_fee_grants', 'society_fee_calendar',
    'society_fee_month_rule_history', 'financial_audit_log',
    'financial_reminder_runs', 'society_email_delivery_attempts',
    'society_email_outbox', 'financial_email_outbox',
    'member_data_drafts', 'member_data_invitations', 'member_import_candidates',
    'member_section_history', 'section_role_assignments', 'member_sections',
    'section_accompanists', 'sections', 'member_status_history',
    'person_guardians', 'person_profile_change_history',
    'guardian_profile_change_history', 'user_access_decisions',
    'society_member_permission_overrides', 'permission_change_audit',
    'wardrobe_luggage_handovers', 'wardrobe_loss_cases', 'wardrobe_repairs',
    'wardrobe_notifications', 'wardrobe_loans', 'wardrobe_luggage',
    'wardrobe_assignment_items', 'wardrobe_assignments', 'wardrobe_kit_items',
    'wardrobe_kits', 'wardrobe_item_repertoire', 'wardrobe_items',
    'wardrobe_categories', 'wardrobe_audit_log'
  ];
begin
  foreach v_table in array v_tables loop
    if to_regclass(format('public.%I', v_table)) is not null then
      execute format('truncate table public.%I cascade', v_table);
    end if;
  end loop;
end
$$;

-- Keep only the president's membership and its function assignments.
delete from public.society_member_function_assignments assignment
where assignment.society_member_id <>
  (select president_membership_id from cleanup_keep_context);

delete from public.society_member_functions function_row
where function_row.society_id <>
  (select society_id from cleanup_keep_context);

delete from public.society_members membership
where membership.id <>
  (select president_membership_id from cleanup_keep_context);

-- Remove non-target onboarding and preferences before deleting accounts/societies.
delete from public.user_onboarding_state onboarding
where onboarding.user_id <>
  (select president_user_id from cleanup_keep_context);

delete from public.user_society_preferences preference
where preference.user_id <>
  (select president_user_id from cleanup_keep_context)
  and preference.user_id not in (select user_id from public.platform_admins);

-- Remove licences and platform records belonging to test societies only.
delete from public.platform_license_notifications notification
where notification.society_id <>
    (select society_id from cleanup_keep_context)
   or notification.license_period_id in (
  select period.id
  from public.society_license_periods period
  where period.society_id <>
    (select society_id from cleanup_keep_context)
);

delete from public.president_license_assignments assignment
where assignment.society_id <>
  (select society_id from cleanup_keep_context);

delete from public.platform_license_payments payment
where payment.society_id <>
  (select society_id from cleanup_keep_context);

delete from public.society_license_periods period
where period.society_id <>
  (select society_id from cleanup_keep_context);

delete from public.society_suspensions suspension
where suspension.society_id <>
  (select society_id from cleanup_keep_context);

delete from public.financial_number_counters counter
where counter.society_id <>
  (select society_id from cleanup_keep_context);

delete from public.society_function_permission_rules permission_rule
where permission_rule.society_id <>
  (select society_id from cleanup_keep_context);

delete from public.society_email_connections email_connection
where email_connection.society_id <>
  (select society_id from cleanup_keep_context);

delete from public.wardrobe_settings wardrobe_setting
where wardrobe_setting.society_id <>
  (select society_id from cleanup_keep_context);

delete from public.master_admin_audit_log audit
where audit.society_id is not null
  and audit.society_id <>
    (select society_id from cleanup_keep_context);

-- Remove all non-target registration requests and societies.
delete from public."PresidentReg" registration
where registration.id <>
  (select president_reg_id from cleanup_keep_context);

delete from public.societies society
where society.id <>
  (select society_id from cleanup_keep_context);

-- Preserve the president profile and any profile owned by a platform admin.
delete from public.people person
where person.id <>
  (select president_person_id from cleanup_keep_context)
  and coalesce(person.user_id, '00000000-0000-0000-0000-000000000000'::uuid)
      not in (select user_id from public.platform_admins);

-- Auth cleanup is last. PostgreSQL cascades identities/sessions belonging to the
-- deleted test accounts. President and every platform admin remain.
delete from auth.users account
where account.id <>
  (select president_user_id from cleanup_keep_context)
  and account.id not in (select user_id from public.platform_admins);

-- Final invariants. Any failure rolls the entire transaction back.
do $$
declare
  v_auth_count integer;
  v_expected_auth_count integer;
begin
  select count(*) into v_auth_count from auth.users;
  select count(distinct user_id) + 1 into v_expected_auth_count
  from public.platform_admins
  where user_id <>
    (select president_user_id from cleanup_keep_context);

  if v_auth_count <> v_expected_auth_count then
    raise exception
      'CISCENJE NIJE POTPUNO: Auth naloga=%, ocekivano=%.',
      v_auth_count, v_expected_auth_count;
  end if;

  if (select count(*) from public.societies) <> 1
     or (select count(*) from public."PresidentReg") <> 1
     or (select count(*) from public.society_members) <> 1 then
    raise exception
      'CISCENJE NIJE POTPUNO: mora ostati jedno drustvo, jedan zahtev i jedno clanstvo.';
  end if;

  if not exists (
    select 1 from auth.users
    where lower(email) = 'kud.mitance@gmail.com'
  ) then
    raise exception 'PREDSEDNICKI NALOG NIJE SACUVAN.';
  end if;

  if exists (
    select 1
    from public.platform_admins admin
    left join auth.users account on account.id = admin.user_id
    where account.id is null
  ) then
    raise exception 'MASTER ADMIN NALOG NIJE SACUVAN.';
  end if;
end
$$;

commit;
