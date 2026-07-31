-- Read-only verification after production-v1-clean-test-data.sql.

select
  (select count(*) from auth.users) as auth_users,
  (select count(*) from public.platform_admins) as platform_admins,
  (select count(*) from public.societies) as societies,
  (select count(*) from public."PresidentReg") as president_registrations,
  (select count(*) from public.people) as people,
  (select count(*) from public.society_members) as society_members,
  (select count(*) from public.sections) as sections,
  (select count(*) from public.society_events) as events,
  (select count(*) from public.financial_obligations) as financial_obligations,
  (select count(*) from public.wardrobe_items) as wardrobe_items,
  (select count(*) from public.member_import_candidates) as import_candidates,
  (select count(*) from public.society_email_outbox) as email_outbox;

select
  account.id,
  account.email,
  (account.id in (select user_id from public.platform_admins)) as is_platform_admin,
  (lower(account.email) = 'kud.mitance@gmail.com') as is_preserved_president
from auth.users account
order by account.email;

select
  society.id,
  society.name,
  society.status,
  registration."presidentEmail",
  membership.status as membership_status
from public.societies society
join public.user_onboarding_state onboarding on onboarding.society_id = society.id
join public."PresidentReg" registration on registration.id = onboarding.president_reg_id
join public.people person on person.user_id = onboarding.user_id
join public.society_members membership
  on membership.society_id = society.id
 and membership.person_id = person.id;
