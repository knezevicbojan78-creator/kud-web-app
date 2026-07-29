-- Supabase setup for public society registration requests.
-- Run this in the Supabase SQL editor for the target project.

create extension if not exists pgcrypto;

create table if not exists public."PresidentReg" (
  id uuid primary key default gen_random_uuid(),
  "societyName" text not null,
  address text not null,
  city text not null,
  "postalCode" text,
  country text not null,
  "PIB" text not null,
  "registrationNumber" text not null,
  "bankAccount" text,
  "presidentFirstName" text not null,
  "presidentLastName" text not null,
  "presidentGender" text not null,
  "presidentPhone" text not null,
  "presidentEmail" text not null,
  password text not null,
  "confirmPassword" text not null,
  "licenseType" text,
  "licensePrice" numeric,
  "StatReg" text not null default 'PENDING',
  "createdAt" timestamptz not null default now(),
  "approvedAt" timestamptz,
  "approvedByEmail" text,
  "presidentUserId" uuid,
  constraint "PresidentReg_StatReg_pending_or_admin_status"
    check ("StatReg" in ('PENDING', 'APPROVED', 'REJECTED'))
);

create or replace function public.set_president_reg_pending()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new."StatReg" := 'PENDING';
  new."createdAt" := coalesce(new."createdAt", now());
  new."approvedAt" := null;
  new."approvedByEmail" := null;
  new."presidentUserId" := null;
  return new;
end;
$$;

drop trigger if exists "set_president_reg_pending_before_insert"
on public."PresidentReg";

create trigger "set_president_reg_pending_before_insert"
before insert on public."PresidentReg"
for each row
execute function public.set_president_reg_pending();

alter table public."PresidentReg" enable row level security;

revoke all on table public."PresidentReg" from anon;
revoke all on table public."PresidentReg" from authenticated;
grant insert on table public."PresidentReg" to anon;

drop policy if exists "anon_insert_pending_president_reg"
on public."PresidentReg";

create policy "anon_insert_pending_president_reg"
on public."PresidentReg"
for insert
to anon
with check ("StatReg" = 'PENDING');

-- Intentionally do not create SELECT, UPDATE, or DELETE policies for anon.
-- With RLS enabled, anon cannot read, change, or delete submitted requests.
-- Master admin approval should be added later with separate authenticated policies.
