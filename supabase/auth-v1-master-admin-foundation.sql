-- FOLKLORAS — AUTH V1 / MASTER ADMIN FOUNDATION
--
-- Primeniti nakon auth-v1-readiness-diagnostic.sql.
-- Ovaj fajl:
--   * uvodi jedini platformski Master admin identitet;
--   * ne kreira Auth korisnika i ne cuva lozinku;
--   * zahteva potvrđen email i MFA nivo aal2 pre aktivacije;
--   * priprema Before User Created Auth hook za kontrolisane registracije;
--   * ne uklanja postojece DEV politike i grantove drugih modula.

begin;

create table if not exists public.platform_admins (
  id uuid primary key default gen_random_uuid(),
  singleton_key boolean not null default true,
  user_id uuid not null unique references auth.users(id) on delete restrict,
  email text not null,
  status text not null default 'ACTIVE',
  mfa_required boolean not null default true,
  activated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint platform_admins_singleton_check check (singleton_key = true),
  constraint platform_admins_singleton_unique unique (singleton_key),
  constraint platform_admins_email_normalized_check
    check (email = lower(btrim(email))),
  constraint platform_admins_status_check check (status in ('ACTIVE', 'DISABLED'))
);

alter table public.platform_admins enable row level security;

revoke all on table public.platform_admins from public, anon, authenticated;

create or replace function public.auth_get_bootstrap_status()
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    'master_admin_active',
    exists (
      select 1
      from public.platform_admins pa
      where pa.status = 'ACTIVE'
    ),
    'master_admin_registration_available',
    not exists (
      select 1
      from public.platform_admins pa
      where pa.status = 'ACTIVE'
    )
  );
$$;

revoke all on function public.auth_get_bootstrap_status() from public;
grant execute on function public.auth_get_bootstrap_status() to anon, authenticated;

create or replace function public.auth_is_master_admin()
returns boolean
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select
    auth.uid() is not null
    and coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2'
    and exists (
      select 1
      from public.platform_admins pa
      where pa.user_id = auth.uid()
        and pa.status = 'ACTIVE'
    );
$$;

revoke all on function public.auth_is_master_admin() from public, anon;
grant execute on function public.auth_is_master_admin() to authenticated;

create or replace function public.auth_get_session_context()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_email_confirmed boolean := false;
  v_aal text := coalesce(auth.jwt() ->> 'aal', 'aal1');
  v_is_master boolean := false;
begin
  if v_user_id is null then
    return jsonb_build_object(
      'authenticated', false,
      'email_confirmed', false,
      'is_master_admin', false,
      'aal', 'aal1'
    );
  end if;

  select lower(btrim(u.email)), u.email_confirmed_at is not null
    into v_email, v_email_confirmed
  from auth.users u
  where u.id = v_user_id;

  select exists (
    select 1
    from public.platform_admins pa
    where pa.user_id = v_user_id
      and pa.status = 'ACTIVE'
  ) into v_is_master;

  return jsonb_build_object(
    'authenticated', true,
    'user_id', v_user_id,
    'email', v_email,
    'email_confirmed', v_email_confirmed,
    'is_allowed_master_email',
      v_email = 'knezevic.bojan78@gmail.com',
    'is_master_admin', v_is_master,
    'aal', v_aal,
    'requires_master_mfa',
      v_email = 'knezevic.bojan78@gmail.com'
      and not v_is_master
      and v_aal <> 'aal2'
  );
end;
$$;

revoke all on function public.auth_get_session_context() from public, anon;
grant execute on function public.auth_get_session_context() to authenticated;

create or replace function public.auth_bootstrap_master_admin()
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_email_confirmed_at timestamptz;
  v_existing_user_id uuid;
begin
  if v_user_id is null then
    raise exception 'Prijava je obavezna.';
  end if;

  select lower(btrim(u.email)), u.email_confirmed_at
    into v_email, v_email_confirmed_at
  from auth.users u
  where u.id = v_user_id;

  if v_email is distinct from 'knezevic.bojan78@gmail.com' then
    raise exception 'Ovaj email nije dozvoljen za Master admin nalog.';
  end if;

  if v_email_confirmed_at is null then
    raise exception 'Email mora biti potvrđen pre aktivacije Master admina.';
  end if;

  if coalesce(auth.jwt() ->> 'aal', 'aal1') <> 'aal2' then
    raise exception 'Obavezna je potvrđena dvofaktorska autentifikacija.';
  end if;

  if exists (
    select 1 from public.people p where p.user_id = v_user_id
  ) or exists (
    select 1 from public.society_members sm where sm.user_id = v_user_id
  ) then
    raise exception 'Master admin ne može biti povezan sa identitetom društva.';
  end if;

  perform pg_advisory_xact_lock(hashtext('folkloras-master-admin-bootstrap'));

  select pa.user_id
    into v_existing_user_id
  from public.platform_admins pa
  where pa.singleton_key = true
  limit 1;

  if v_existing_user_id is not null and v_existing_user_id <> v_user_id then
    raise exception 'Master admin je već aktiviran.';
  end if;

  insert into public.platform_admins (
    singleton_key,
    user_id,
    email,
    status,
    mfa_required,
    activated_at
  )
  values (
    true,
    v_user_id,
    v_email,
    'ACTIVE',
    true,
    now()
  )
  on conflict (singleton_key) do update
  set
    status = 'ACTIVE',
    mfa_required = true,
    updated_at = now()
  where public.platform_admins.user_id = excluded.user_id;

  return jsonb_build_object(
    'master_admin_active', true,
    'user_id', v_user_id,
    'email', v_email,
    'aal', 'aal2'
  );
end;
$$;

revoke all on function public.auth_bootstrap_master_admin() from public, anon;
grant execute on function public.auth_bootstrap_master_admin() to authenticated;

-- Before User Created hook.
-- Nakon primene SQL-a funkciju treba izabrati u:
-- Supabase Dashboard -> Authentication -> Hooks -> Before User Created.
--
-- Pre aktivnog Master admina dozvoljen je samo njegov unapred potvrđeni email.
-- Nakon aktivacije novi Auth korisnik mora vec postojati kao odobren predsednik
-- ili kao osoba koju je drustvo prethodno evidentiralo.
create or replace function public.auth_before_user_created(event jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_email text := lower(btrim(event -> 'user' ->> 'email'));
  v_master_active boolean;
  v_is_eligible boolean := false;
begin
  select exists (
    select 1
    from public.platform_admins pa
    where pa.status = 'ACTIVE'
  ) into v_master_active;

  if not v_master_active then
    if v_email = 'knezevic.bojan78@gmail.com' then
      return '{}'::jsonb;
    end if;

    return jsonb_build_object(
      'error', jsonb_build_object(
        'http_code', 403,
        'message', 'Registracija još nije dostupna.'
      )
    );
  end if;

  select
    exists (
      select 1
      from public.people p
      where lower(btrim(p.email)) = v_email
    )
    or exists (
      select 1
      from public."PresidentReg" pr
      where lower(btrim(pr."presidentEmail")) = v_email
        and pr."StatReg" = 'APPROVED'
    )
  into v_is_eligible;

  if v_is_eligible then
    return '{}'::jsonb;
  end if;

  return jsonb_build_object(
    'error', jsonb_build_object(
      'http_code', 403,
      'message', 'Registracija nije odobrena za ovaj email.'
    )
  );
end;
$$;

grant usage on schema public to supabase_auth_admin;
grant execute on function public.auth_before_user_created(jsonb)
  to supabase_auth_admin;
revoke execute on function public.auth_before_user_created(jsonb)
  from public, anon, authenticated;

commit;

select
  to_regclass('public.platform_admins') as platform_admins_table,
  to_regprocedure('public.auth_get_bootstrap_status()') as bootstrap_status_function,
  to_regprocedure('public.auth_get_session_context()') as session_context_function,
  to_regprocedure('public.auth_bootstrap_master_admin()') as bootstrap_master_function,
  to_regprocedure('public.auth_before_user_created(jsonb)') as before_user_created_hook,
  (select count(*) from public.platform_admins) as platform_admin_count;
