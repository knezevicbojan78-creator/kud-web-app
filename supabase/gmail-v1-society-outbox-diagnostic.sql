-- Read-only provera zajedničkog email outbox-a.
select
  to_regclass('public.society_email_outbox') is not null as outbox_exists,
  to_regclass('public.society_email_delivery_attempts') is not null as attempts_exist,
  to_regprocedure('public.auth_queue_member_data_invitation_email(uuid,uuid,text,text,text)') is not null
    as invitation_queue_exists,
  to_regprocedure('public.auth_queue_payment_confirmation_emails(uuid)') is not null
    as payment_queue_exists,
  to_regprocedure('public.auth_claim_society_email(uuid,text)') is not null
    as claim_exists,
  to_regprocedure('public.auth_complete_society_email_attempt(uuid,boolean,text,text)') is not null
    as completion_exists,
  to_regprocedure('public.auth_list_society_email_log(uuid,text,text,text,integer)') is not null
    as report_exists,
  exists (
    select 1 from public.permission_catalog
    where permission_key = 'reports.email_log.view' and is_active
  ) as permission_exists;

select
  count(*) as total_messages,
  count(*) filter (where status = 'PENDING') as pending,
  count(*) filter (where status = 'SENDING') as sending,
  count(*) filter (where status = 'SENT') as sent,
  count(*) filter (where status = 'FAILED') as failed,
  count(*) filter (where status = 'CANCELLED') as cancelled
from public.society_email_outbox;

select
  count(*) filter (where message_type in (
    'MEMBER_DATA_INVITATION', 'GUARDIAN_DATA_INVITATION'
  ) and member_invitation_id is null) as invitation_without_source,
  count(*) filter (
    where message_type in ('PAYMENT_CONFIRMATION', 'PAYMENT_VOIDED')
      and payment_id is null
  ) as payment_without_source,
  count(*) filter (where status = 'SENT' and sent_at is null) as sent_without_time,
  count(*) filter (where attempt_count < 0) as invalid_attempt_count
from public.society_email_outbox;
