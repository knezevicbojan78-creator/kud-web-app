-- FOLKLORAS DEV/V1
-- Pocetna finansijska podesavanja u zahtevu za registraciju drustva.

begin;

alter table public."PresidentReg"
  add column if not exists "baseCurrency" text not null default 'RSD',
  add column if not exists "membershipFeeAmount" numeric(12,2) null,
  add column if not exists "chargeableMonths" integer[] not null
    default array[1,2,3,4,5,6,7,8,9,10,11,12];

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'president_reg_base_currency_check'
      and conrelid = 'public."PresidentReg"'::regclass
  ) then
    alter table public."PresidentReg"
      add constraint president_reg_base_currency_check
      check ("baseCurrency" ~ '^[A-Z]{3}$');
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'president_reg_membership_fee_positive_check'
      and conrelid = 'public."PresidentReg"'::regclass
  ) then
    alter table public."PresidentReg"
      add constraint president_reg_membership_fee_positive_check
      check ("membershipFeeAmount" is null or "membershipFeeAmount" > 0);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'president_reg_chargeable_months_check'
      and conrelid = 'public."PresidentReg"'::regclass
  ) then
    alter table public."PresidentReg"
      add constraint president_reg_chargeable_months_check
      check ("chargeableMonths" <@ array[1,2,3,4,5,6,7,8,9,10,11,12]);
  end if;
end $$;

commit;
