-- FOLKLORAS DEV/V1
-- FINANSIJE: osnovne tabele, ogranicenja, indeksi i DEV read politike.
-- Poslovni workflow/RPC funkcije se dodaju nakon primene i provere tabela.
-- Pokrenuti nakon societies, people, society_members, member_status_history,
-- person_guardians, society_events i event_participants setup-a.

begin;

alter table public.societies
  add column if not exists base_currency text not null default 'RSD',
  add column if not exists default_membership_fee_amount numeric(12,2) null,
  add column if not exists finance_start_month date null,
  add column if not exists payment_instructions text null,
  add column if not exists finance_last_reminder_at timestamptz null,
  add column if not exists finance_last_reminder_by_user_id uuid null;

alter table public.society_members
  add column if not exists membership_fee_mode text not null default 'STANDARD';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'societies_base_currency_check'
      and conrelid = 'public.societies'::regclass
  ) then
    alter table public.societies add constraint societies_base_currency_check
      check (base_currency ~ '^[A-Z]{3}$');
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'societies_default_fee_nonnegative_check'
      and conrelid = 'public.societies'::regclass
  ) then
    alter table public.societies add constraint societies_default_fee_nonnegative_check
      check (default_membership_fee_amount is null or default_membership_fee_amount >= 0);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'societies_finance_start_month_first_day_check'
      and conrelid = 'public.societies'::regclass
  ) then
    alter table public.societies add constraint societies_finance_start_month_first_day_check
      check (finance_start_month is null or finance_start_month = date_trunc('month', finance_start_month)::date);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'society_members_fee_mode_check'
      and conrelid = 'public.society_members'::regclass
  ) then
    alter table public.society_members add constraint society_members_fee_mode_check
      check (membership_fee_mode in ('STANDARD', 'CUSTOM', 'EXEMPT'));
  end if;
end $$;

create table if not exists public.member_fee_setting_history (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  society_member_id uuid not null references public.society_members(id) on delete restrict,
  fee_mode text not null check (fee_mode in ('STANDARD', 'CUSTOM', 'EXEMPT')),
  fee_amount numeric(12,2) null check (fee_amount is null or fee_amount >= 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  effective_from date not null,
  reason text not null check (length(trim(reason)) > 0),
  changed_by_user_id uuid null,
  changed_by_society_member_id uuid null references public.society_members(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint member_fee_setting_history_amount_check check (
    (fee_mode = 'EXEMPT' and fee_amount is null)
    or (fee_mode in ('STANDARD', 'CUSTOM') and fee_amount is not null)
  ),
  unique (society_member_id, effective_from)
);

create index if not exists member_fee_setting_history_effective_idx
  on public.member_fee_setting_history(society_member_id, effective_from desc);

create table if not exists public.society_fee_calendar (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  fee_month date not null,
  is_chargeable boolean not null default true,
  reason text null,
  changed_by_user_id uuid null,
  changed_by_society_member_id uuid null references public.society_members(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint society_fee_calendar_first_day_check
    check (fee_month = date_trunc('month', fee_month)::date),
  constraint society_fee_calendar_reason_check
    check (is_chargeable or length(trim(coalesce(reason, ''))) > 0),
  unique (society_id, fee_month)
);

create index if not exists society_fee_calendar_month_idx
  on public.society_fee_calendar(society_id, fee_month);

create table if not exists public.member_fee_grants (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  society_member_id uuid not null references public.society_members(id) on delete restrict,
  granted_months smallint not null check (granted_months between 1 and 3),
  effective_from date not null,
  reason text null,
  granted_by_user_id uuid null,
  granted_by_society_member_id uuid null references public.society_members(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (society_member_id)
);

create table if not exists public.financial_obligations (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  obligation_type text not null check (obligation_type in ('MEMBERSHIP_FEE', 'EVENT_FEE')),
  person_id uuid not null references public.people(id) on delete restrict,
  society_member_id uuid null references public.society_members(id) on delete restrict,
  event_id uuid null references public.society_events(id) on delete restrict,
  event_participant_id uuid null references public.event_participants(id) on delete restrict,
  obligation_month date null,
  title text not null check (length(trim(title)) > 0),
  original_amount numeric(12,2) not null check (original_amount >= 0),
  current_amount numeric(12,2) not null check (current_amount >= 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  due_date date not null,
  status text not null default 'OPEN'
    check (status in ('OPEN', 'PARTIALLY_PAID', 'PAID', 'CANCELLED')),
  cancellation_reason text null,
  cancelled_at timestamptz null,
  cancelled_by_user_id uuid null,
  created_by_user_id uuid null,
  created_by_society_member_id uuid null references public.society_members(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint financial_obligations_current_not_above_original_check
    check (current_amount <= original_amount),
  constraint financial_obligations_month_check
    check (obligation_month is null or obligation_month = date_trunc('month', obligation_month)::date),
  constraint financial_obligations_reference_check check (
    (obligation_type = 'MEMBERSHIP_FEE'
      and society_member_id is not null
      and event_id is null
      and event_participant_id is null
      and obligation_month is not null)
    or
    (obligation_type = 'EVENT_FEE'
      and event_id is not null
      and event_participant_id is not null
      and obligation_month is null)
  ),
  constraint financial_obligations_cancel_check check (
    (status = 'CANCELLED' and cancelled_at is not null and length(trim(coalesce(cancellation_reason, ''))) > 0)
    or (status <> 'CANCELLED')
  )
);

create unique index if not exists financial_obligations_membership_unique_idx
  on public.financial_obligations(society_member_id, obligation_month)
  where obligation_type = 'MEMBERSHIP_FEE';

create unique index if not exists financial_obligations_event_unique_idx
  on public.financial_obligations(event_participant_id)
  where obligation_type = 'EVENT_FEE';

create index if not exists financial_obligations_open_idx
  on public.financial_obligations(society_id, status, due_date);
create index if not exists financial_obligations_person_idx
  on public.financial_obligations(person_id, status, due_date);

create table if not exists public.membership_fee_assessments (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  society_member_id uuid not null references public.society_members(id) on delete restrict,
  assessment_month date not null,
  result text not null check (result in (
    'CHARGED', 'SOCIETY_FREE_MONTH', 'INDIVIDUAL_FREE_MONTH',
    'INACTIVE', 'EXEMPT', 'JOINED_AFTER_CUTOFF', 'BEFORE_FINANCE_START'
  )),
  obligation_id uuid null references public.financial_obligations(id) on delete restrict,
  member_fee_grant_id uuid null references public.member_fee_grants(id) on delete restrict,
  assessed_amount numeric(12,2) null check (assessed_amount is null or assessed_amount >= 0),
  currency text null check (currency is null or currency ~ '^[A-Z]{3}$'),
  processed_at timestamptz not null default now(),
  process_source text not null default 'AUTOMATIC'
    check (process_source in ('AUTOMATIC', 'MEMBER_CREATE', 'REACTIVATION', 'RECHECK')),
  initiated_by_user_id uuid null,
  note text null,
  unique (society_member_id, assessment_month),
  constraint membership_fee_assessments_first_day_check
    check (assessment_month = date_trunc('month', assessment_month)::date),
  constraint membership_fee_assessments_obligation_check check (
    (result = 'CHARGED' and obligation_id is not null and assessed_amount is not null and currency is not null)
    or (result <> 'CHARGED' and obligation_id is null)
  )
);

create index if not exists membership_fee_assessments_month_idx
  on public.membership_fee_assessments(society_id, assessment_month, result);

create table if not exists public.financial_number_counters (
  society_id uuid not null references public.societies(id) on delete restrict,
  counter_year integer not null check (counter_year between 2000 and 9999),
  counter_type text not null check (counter_type in ('PAYMENT', 'REFUND')),
  last_number integer not null default 0 check (last_number >= 0),
  updated_at timestamptz not null default now(),
  primary key (society_id, counter_year, counter_type)
);

create table if not exists public.financial_payments (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  receipt_year integer not null,
  receipt_sequence integer not null check (receipt_sequence > 0),
  receipt_number text not null,
  amount numeric(12,2) not null check (amount > 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  payment_method text not null default 'CASH'
    check (payment_method in ('CASH', 'BANK_TRANSFER')),
  status text not null default 'POSTED' check (status in ('POSTED', 'VOIDED')),
  recorded_by_user_id uuid null,
  recorded_by_society_member_id uuid null references public.society_members(id) on delete restrict,
  recorded_at timestamptz not null default now(),
  voided_by_user_id uuid null,
  voided_by_society_member_id uuid null references public.society_members(id) on delete restrict,
  voided_at timestamptz null,
  void_reason text null,
  constraint financial_payments_receipt_unique unique (society_id, receipt_year, receipt_sequence),
  constraint financial_payments_receipt_number_unique unique (society_id, receipt_number),
  constraint financial_payments_void_check check (
    (status = 'VOIDED' and voided_at is not null and length(trim(coalesce(void_reason, ''))) > 0)
    or (status = 'POSTED' and voided_at is null and void_reason is null)
  )
);

create index if not exists financial_payments_recorded_idx
  on public.financial_payments(society_id, recorded_at desc);

create table if not exists public.financial_credit_entries (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  person_id uuid not null references public.people(id) on delete restrict,
  society_member_id uuid null references public.society_members(id) on delete restrict,
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  amount numeric(12,2) not null check (amount <> 0),
  entry_type text not null check (entry_type in (
    'PAYMENT_SURPLUS', 'MEMBERSHIP_AUTO_USE', 'EVENT_MANUAL_USE',
    'EVENT_CANCELLATION', 'PAYMENT_VOID_REVERSAL',
    'REFUND', 'REFUND_VOID_REVERSAL'
  )),
  source_payment_id uuid null references public.financial_payments(id) on delete restrict,
  source_obligation_id uuid null references public.financial_obligations(id) on delete restrict,
  related_entry_id uuid null references public.financial_credit_entries(id) on delete restrict,
  created_by_user_id uuid null,
  created_by_society_member_id uuid null references public.society_members(id) on delete restrict,
  reason text null,
  created_at timestamptz not null default now()
);

create index if not exists financial_credit_balance_idx
  on public.financial_credit_entries(person_id, currency, created_at);

create table if not exists public.financial_obligation_allocations (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  obligation_id uuid not null references public.financial_obligations(id) on delete restrict,
  source_type text not null check (source_type in ('PAYMENT', 'CREDIT')),
  payment_id uuid null references public.financial_payments(id) on delete restrict,
  credit_entry_id uuid null references public.financial_credit_entries(id) on delete restrict,
  amount numeric(12,2) not null check (amount > 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  status text not null default 'ACTIVE' check (status in ('ACTIVE', 'REVERSED')),
  reversed_at timestamptz null,
  reversed_by_user_id uuid null,
  reversal_reason text null,
  created_by_user_id uuid null,
  created_by_society_member_id uuid null references public.society_members(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint financial_obligation_allocations_source_check check (
    (source_type = 'PAYMENT' and payment_id is not null and credit_entry_id is null)
    or (source_type = 'CREDIT' and payment_id is null and credit_entry_id is not null)
  ),
  constraint financial_obligation_allocations_reverse_check check (
    (status = 'REVERSED' and reversed_at is not null and length(trim(coalesce(reversal_reason, ''))) > 0)
    or (status = 'ACTIVE' and reversed_at is null)
  )
);

create index if not exists financial_obligation_allocations_obligation_idx
  on public.financial_obligation_allocations(obligation_id, status);
create index if not exists financial_obligation_allocations_payment_idx
  on public.financial_obligation_allocations(payment_id, status);

create table if not exists public.financial_refunds (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  person_id uuid not null references public.people(id) on delete restrict,
  society_member_id uuid null references public.society_members(id) on delete restrict,
  refund_year integer not null,
  refund_sequence integer not null check (refund_sequence > 0),
  refund_number text not null,
  amount numeric(12,2) not null check (amount > 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  refund_method text not null check (refund_method in ('CASH', 'BANK_TRANSFER')),
  credit_entry_id uuid not null references public.financial_credit_entries(id) on delete restrict,
  status text not null default 'POSTED' check (status in ('POSTED', 'VOIDED')),
  reason text not null check (length(trim(reason)) > 0),
  recorded_by_user_id uuid null,
  recorded_by_society_member_id uuid null references public.society_members(id) on delete restrict,
  recorded_at timestamptz not null default now(),
  voided_by_user_id uuid null,
  voided_at timestamptz null,
  void_reason text null,
  unique (society_id, refund_year, refund_sequence),
  unique (society_id, refund_number),
  constraint financial_refunds_void_check check (
    (status = 'VOIDED' and voided_at is not null and length(trim(coalesce(void_reason, ''))) > 0)
    or (status = 'POSTED' and voided_at is null and void_reason is null)
  )
);

create index if not exists financial_refunds_person_idx
  on public.financial_refunds(person_id, recorded_at desc);

create table if not exists public.financial_audit_log (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  entity_type text not null,
  entity_id uuid not null,
  action text not null,
  old_values jsonb null,
  new_values jsonb null,
  reason text null,
  actor_user_id uuid null,
  actor_society_member_id uuid null references public.society_members(id) on delete restrict,
  actor_role text null,
  source text not null default 'USER' check (source in ('USER', 'SYSTEM')),
  created_at timestamptz not null default now()
);

create index if not exists financial_audit_entity_idx
  on public.financial_audit_log(entity_type, entity_id, created_at desc);
create index if not exists financial_audit_society_idx
  on public.financial_audit_log(society_id, created_at desc);

create table if not exists public.society_email_connections (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict unique,
  provider text not null default 'GOOGLE' check (provider = 'GOOGLE'),
  email_address text not null,
  encrypted_refresh_token text not null,
  status text not null default 'CONNECTED'
    check (status in ('CONNECTED', 'ERROR', 'DISCONNECTED')),
  connected_by_user_id uuid null,
  connected_at timestamptz not null default now(),
  disconnected_by_user_id uuid null,
  disconnected_at timestamptz null,
  last_success_at timestamptz null,
  last_error_at timestamptz null,
  last_error text null,
  updated_at timestamptz not null default now()
);

create table if not exists public.financial_email_outbox (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  message_type text not null check (message_type in (
    'PAYMENT_CONFIRMATION', 'PAYMENT_VOIDED', 'PAYMENT_REMINDER'
  )),
  payment_id uuid null references public.financial_payments(id) on delete restrict,
  reminder_run_id uuid null,
  recipient_email text not null,
  subject text not null,
  payload jsonb not null default '{}'::jsonb,
  sender_source text not null check (sender_source in ('SOCIETY_GMAIL', 'FOLKLORAS_CENTRAL')),
  idempotency_key text not null unique,
  status text not null default 'PENDING'
    check (status in ('PENDING', 'SENDING', 'SENT', 'FAILED')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  provider_message_id text null,
  last_error text null,
  last_attempt_at timestamptz null,
  sent_at timestamptz null,
  created_at timestamptz not null default now()
);

create index if not exists financial_email_outbox_pending_idx
  on public.financial_email_outbox(status, created_at)
  where status in ('PENDING', 'FAILED');

create table if not exists public.financial_reminder_runs (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  status text not null default 'PREVIEW'
    check (status in ('PREVIEW', 'QUEUED', 'COMPLETED', 'PARTIALLY_FAILED', 'FAILED')),
  recipient_count integer not null default 0 check (recipient_count >= 0),
  missing_email_count integer not null default 0 check (missing_email_count >= 0),
  initiated_by_user_id uuid null,
  initiated_by_society_member_id uuid null references public.society_members(id) on delete restrict,
  created_at timestamptz not null default now(),
  completed_at timestamptz null
);

alter table public.financial_email_outbox
  drop constraint if exists financial_email_outbox_reminder_run_id_fkey;
alter table public.financial_email_outbox
  add constraint financial_email_outbox_reminder_run_id_fkey
  foreign key (reminder_run_id) references public.financial_reminder_runs(id) on delete restrict;

-- Finansijski zapisi se ne brisu direktno.
create or replace function public.prevent_financial_row_delete()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  raise exception 'Finansijski zapisi se ne brisu fizicki.';
end;
$$;

create or replace function public.prevent_financial_audit_change()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  raise exception 'Finansijski audit se ne menja niti brise.';
end;
$$;

drop trigger if exists prevent_financial_audit_change_trigger
  on public.financial_audit_log;
create trigger prevent_financial_audit_change_trigger
before update or delete on public.financial_audit_log
for each row execute function public.prevent_financial_audit_change();

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'member_fee_setting_history', 'member_fee_grants',
    'membership_fee_assessments', 'financial_obligations',
    'financial_payments', 'financial_credit_entries',
    'financial_obligation_allocations', 'financial_refunds',
    'financial_email_outbox',
    'financial_reminder_runs'
  ] loop
    execute format('drop trigger if exists prevent_delete_%I on public.%I', v_table, v_table);
    execute format(
      'create trigger prevent_delete_%I before delete on public.%I for each row execute function public.prevent_financial_row_delete()',
      v_table, v_table
    );
  end loop;
end $$;

alter table public.member_fee_setting_history enable row level security;
alter table public.society_fee_calendar enable row level security;
alter table public.member_fee_grants enable row level security;
alter table public.membership_fee_assessments enable row level security;
alter table public.financial_obligations enable row level security;
alter table public.financial_number_counters enable row level security;
alter table public.financial_payments enable row level security;
alter table public.financial_credit_entries enable row level security;
alter table public.financial_obligation_allocations enable row level security;
alter table public.financial_refunds enable row level security;
alter table public.financial_audit_log enable row level security;
alter table public.society_email_connections enable row level security;
alter table public.financial_email_outbox enable row level security;
alter table public.financial_reminder_runs enable row level security;

-- Nema privremenih "using (true)" politika. Finansijski podaci ostaju
-- zatvoreni dok kontrolisane RPC funkcije ne sprovedu prava predsednika,
-- blagajnika, clana i roditelja/staratelja.

revoke insert, update, delete on public.member_fee_setting_history from anon, authenticated;
revoke insert, update, delete on public.society_fee_calendar from anon, authenticated;
revoke insert, update, delete on public.member_fee_grants from anon, authenticated;
revoke insert, update, delete on public.membership_fee_assessments from anon, authenticated;
revoke insert, update, delete on public.financial_obligations from anon, authenticated;
revoke insert, update, delete on public.financial_number_counters from anon, authenticated;
revoke insert, update, delete on public.financial_payments from anon, authenticated;
revoke insert, update, delete on public.financial_credit_entries from anon, authenticated;
revoke insert, update, delete on public.financial_obligation_allocations from anon, authenticated;
revoke insert, update, delete on public.financial_refunds from anon, authenticated;
revoke insert, update, delete on public.financial_audit_log from anon, authenticated;
revoke insert, update, delete on public.society_email_connections from anon, authenticated;
revoke insert, update, delete on public.financial_email_outbox from anon, authenticated;
revoke insert, update, delete on public.financial_reminder_runs from anon, authenticated;

select pg_notify('pgrst', 'reload schema');

commit;
