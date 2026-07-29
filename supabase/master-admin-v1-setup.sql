-- FOLKLORAS — Master admin V1 foundation
-- Priprema model licenci, suspenzija, obavestenja, audita i agregatnog read modela.
-- Paketi se namerno ne seed-uju dok se ne zavrsi prakticno testiranje sa vise drustava.
-- Finalni Auth/RLS model mora zameniti DEV anon execute grant pre produkcije.

begin;

create extension if not exists pgcrypto;

alter table public."PresidentReg"
  add column if not exists "societyId" uuid null
  references public.societies(id) on delete restrict;

-- V1 koristi samo ACTIVE i SUSPENDED. Postojeci status check, ako postoji,
-- zamenjuje se kontrolisanim check-om bez pretpostavljanja njegovog imena.
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
    execute format(
      'alter table public.societies drop constraint %I',
      v_constraint.conname
    );
  end loop;
end;
$$;

alter table public.societies
  alter column status set default 'ACTIVE';

alter table public.societies
  add constraint societies_status_check
  check (status in ('ACTIVE', 'SUSPENDED'));

create table if not exists public.platform_license_plans (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text null,
  monthly_price numeric(12,2) null check (monthly_price is null or monthly_price >= 0),
  annual_price numeric(12,2) null check (annual_price is null or annual_price >= 0),
  currency text not null default 'RSD' check (currency ~ '^[A-Z]{3}$'),
  active_member_limit integer null check (active_member_limit is null or active_member_limit > 0),
  active_section_limit integer null check (active_section_limit is null or active_section_limit > 0),
  status text not null default 'ACTIVE' check (status in ('ACTIVE', 'INACTIVE')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.platform_license_payments (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  license_plan_id uuid not null references public.platform_license_plans(id) on delete restrict,
  billing_cycle text not null check (billing_cycle in ('MONTHLY', 'ANNUAL')),
  amount numeric(12,2) not null check (amount > 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  paid_on date not null,
  payment_method text not null check (payment_method in ('BANK_TRANSFER', 'CASH', 'OTHER')),
  payment_reference text null,
  note text null,
  status text not null default 'RECORDED' check (status in ('RECORDED', 'VOIDED')),
  recorded_by_user_id uuid null,
  recorded_at timestamptz not null default now(),
  voided_by_user_id uuid null,
  voided_at timestamptz null,
  void_reason text null,
  created_at timestamptz not null default now(),
  constraint platform_license_payment_void_check check (
    (status = 'RECORDED' and voided_at is null and void_reason is null)
    or
    (status = 'VOIDED' and voided_at is not null and length(trim(void_reason)) > 0)
  )
);

create index if not exists platform_license_payments_society_date_idx
  on public.platform_license_payments(society_id, paid_on desc, recorded_at desc);

create table if not exists public.society_license_periods (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  license_plan_id uuid not null references public.platform_license_plans(id) on delete restrict,
  source text not null check (source in ('PAID', 'PROMOTIONAL')),
  billing_cycle text not null check (billing_cycle in ('MONTHLY', 'ANNUAL', 'PROMOTIONAL')),
  duration_months integer not null check (duration_months in (1, 3, 6, 12)),
  valid_from date not null,
  valid_until date not null,
  plan_name_snapshot text not null,
  price_snapshot numeric(12,2) not null check (price_snapshot >= 0),
  currency_snapshot text not null check (currency_snapshot ~ '^[A-Z]{3}$'),
  active_member_limit_snapshot integer null
    check (active_member_limit_snapshot is null or active_member_limit_snapshot > 0),
  active_section_limit_snapshot integer null
    check (active_section_limit_snapshot is null or active_section_limit_snapshot > 0),
  payment_id uuid null unique
    references public.platform_license_payments(id) on delete restrict,
  promotion_reason text null,
  internal_note text null,
  granted_by_user_id uuid null,
  created_at timestamptz not null default now(),
  constraint society_license_period_dates_check check (valid_until >= valid_from),
  constraint society_license_period_source_check check (
    (
      source = 'PAID'
      and billing_cycle in ('MONTHLY', 'ANNUAL')
      and duration_months in (1, 12)
      and payment_id is not null
      and promotion_reason is null
    )
    or
    (
      source = 'PROMOTIONAL'
      and billing_cycle = 'PROMOTIONAL'
      and duration_months in (3, 6, 12)
      and payment_id is null
      and length(trim(promotion_reason)) > 0
    )
  )
);

create index if not exists society_license_periods_society_validity_idx
  on public.society_license_periods(society_id, valid_until desc, valid_from desc);

create table if not exists public.society_suspensions (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  reason_type text not null check (reason_type in ('LICENSE_EXPIRED', 'ADMINISTRATIVE', 'OTHER')),
  reason text not null check (length(trim(reason)) > 0),
  related_license_period_id uuid null
    references public.society_license_periods(id) on delete restrict,
  suspended_at timestamptz not null default now(),
  suspended_by_user_id uuid null,
  lifted_at timestamptz null,
  lifted_by_user_id uuid null,
  lift_reason text null,
  related_reactivation_payment_id uuid null
    references public.platform_license_payments(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint society_suspension_lift_check check (
    (lifted_at is null and lift_reason is null)
    or
    (lifted_at is not null and length(trim(lift_reason)) > 0)
  )
);

create unique index if not exists society_suspensions_one_active_idx
  on public.society_suspensions(society_id)
  where lifted_at is null;

create table if not exists public.platform_license_notifications (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  license_period_id uuid null references public.society_license_periods(id) on delete restrict,
  notification_type text not null check (
    notification_type in (
      'MONTHLY_EXPIRY_5_DAYS',
      'ANNUAL_EXPIRY_30_DAYS',
      'ANNUAL_EXPIRY_7_DAYS',
      'PROMOTIONAL_EXPIRY_30_DAYS',
      'PROMOTIONAL_EXPIRY_7_DAYS',
      'LICENSE_SUSPENDED',
      'LICENSE_REACTIVATED'
    )
  ),
  channel text not null check (channel in ('IN_APP', 'EMAIL')),
  recipient_user_id uuid null,
  recipient_email text null,
  scheduled_for timestamptz not null,
  status text not null default 'PENDING'
    check (status in ('PENDING', 'SENT', 'FAILED', 'CANCELLED')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  last_error text null,
  sent_at timestamptz null,
  created_at timestamptz not null default now(),
  unique (license_period_id, notification_type, channel)
);

create index if not exists platform_license_notifications_pending_idx
  on public.platform_license_notifications(scheduled_for)
  where status = 'PENDING';

create table if not exists public.master_admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  action text not null,
  entity_type text not null,
  entity_id uuid null,
  society_id uuid null references public.societies(id) on delete restrict,
  old_values jsonb null,
  new_values jsonb null,
  reason text null,
  result text not null default 'SUCCESS' check (result in ('SUCCESS', 'FAILED')),
  actor_user_id uuid null,
  actor_email text null,
  created_at timestamptz not null default now()
);

create index if not exists master_admin_audit_society_date_idx
  on public.master_admin_audit_log(society_id, created_at desc);
create index if not exists master_admin_audit_action_date_idx
  on public.master_admin_audit_log(action, created_at desc);

-- Platformske tabele ostaju zatvorene za direktan klijentski pristup.
alter table public.platform_license_plans enable row level security;
alter table public.platform_license_payments enable row level security;
alter table public.society_license_periods enable row level security;
alter table public.society_suspensions enable row level security;
alter table public.platform_license_notifications enable row level security;
alter table public.master_admin_audit_log enable row level security;

revoke all on table public.platform_license_plans from anon, authenticated;
revoke all on table public.platform_license_payments from anon, authenticated;
revoke all on table public.society_license_periods from anon, authenticated;
revoke all on table public.society_suspensions from anon, authenticated;
revoke all on table public.platform_license_notifications from anon, authenticated;
revoke all on table public.master_admin_audit_log from anon, authenticated;

-- Agregatni read model nikada ne vraca identitete clanova ili nazive sekcija.
create or replace function public.master_admin_get_society_summaries()
returns table (
  id uuid,
  name text,
  city text,
  pib text,
  registration_number text,
  license_type text,
  status text,
  active_member_count bigint,
  inactive_member_count bigint,
  active_section_count bigint,
  inactive_section_count bigint,
  registered_at timestamptz
)
language sql
security definer
stable
set search_path = public
as $$
  select
    s.id,
    s.name,
    s.city,
    s.pib,
    s.registration_number,
    s.license_type,
    s.status,
    (select count(*) from society_members sm
      where sm.society_id = s.id and sm.status = 'ACTIVE') as active_member_count,
    (select count(*) from society_members sm
      where sm.society_id = s.id and sm.status <> 'ACTIVE') as inactive_member_count,
    (select count(*) from sections sec
      where sec.society_id = s.id and sec.status = 'ACTIVE') as active_section_count,
    (select count(*) from sections sec
      where sec.society_id = s.id and sec.status <> 'ACTIVE') as inactive_section_count,
    (
      select pr."approvedAt"
      from "PresidentReg" pr
      where pr."societyId" = s.id
        and pr."StatReg" = 'APPROVED'
      order by pr."approvedAt" desc nulls last
      limit 1
    ) as registered_at
  from societies s
  order by s.name;
$$;

create or replace function public.master_admin_get_dashboard()
returns jsonb
language sql
security definer
stable
set search_path = public
as $$
  select jsonb_build_object(
    'active_society_count',
      (select count(*) from societies where status = 'ACTIVE'),
    'suspended_society_count',
      (select count(*) from societies where status = 'SUSPENDED'),
    'pending_registration_count',
      (select count(*) from "PresidentReg" where "StatReg" = 'PENDING'),
    'expiring_license_count',
      (
        select count(distinct slp.society_id)
        from society_license_periods slp
        where slp.valid_until between current_date and current_date + 30
          and not exists (
            select 1
            from society_license_periods next_period
            where next_period.society_id = slp.society_id
              and next_period.valid_from > slp.valid_until
          )
      ),
    'license_distribution',
      coalesce((
        select jsonb_agg(jsonb_build_object(
          'license_type', distribution.license_type,
          'society_count', distribution.society_count
        ) order by distribution.license_type)
        from (
          select coalesce(license_type, 'Nije dodeljena') as license_type,
            count(*) as society_count
          from societies
          group by coalesce(license_type, 'Nije dodeljena')
        ) distribution
      ), '[]'::jsonb),
    'recent_actions',
      coalesce((
        select jsonb_agg(to_jsonb(recent_action) order by recent_action.created_at desc)
        from (
          select mal.id, mal.action, mal.entity_type, mal.society_id,
            mal.reason, mal.result, mal.created_at,
            s.name as society_name
          from master_admin_audit_log mal
          left join societies s on s.id = mal.society_id
          order by mal.created_at desc
          limit 10
        ) recent_action
      ), '[]'::jsonb)
  );
$$;

revoke all on function public.master_admin_get_society_summaries() from public;
revoke all on function public.master_admin_get_dashboard() from public;

-- DEV/V1: test login jos nije Supabase Auth. Ove grant-ove pre produkcije
-- zameniti finalnom proverom Master admin identiteta i authenticated-only pristupom.
grant execute on function public.master_admin_get_society_summaries() to anon, authenticated;
grant execute on function public.master_admin_get_dashboard() to anon, authenticated;

select pg_notify('pgrst', 'reload schema');
commit;
