-- FOLKLORAS — Dozvole V1, faza 1
-- Katalog, pocetni sabloni, pravila funkcija, pojedinacni izuzeci i audit.
-- Ovaj fajl NE uvodi jos centralne authorize RPC funkcije niti menja postojece
-- module. Pokrenuti ga tek nakon provere dijagnostike i postojecih zavisnosti.

begin;

create extension if not exists pgcrypto;

do $$
begin
  if to_regclass('public.societies') is null then
    raise exception 'Nedostaje public.societies.';
  end if;
  if to_regclass('public.society_members') is null then
    raise exception 'Nedostaje public.society_members.';
  end if;
  if to_regclass('public.society_member_functions') is null then
    raise exception 'Nedostaje public.society_member_functions.';
  end if;
  if to_regclass('public.society_member_function_assignments') is null then
    raise exception 'Nedostaje public.society_member_function_assignments.';
  end if;
end;
$$;

create table if not exists public.permission_catalog (
  id uuid primary key default gen_random_uuid(),
  permission_key text not null unique,
  module_key text not null,
  label text not null,
  description text null,
  action_type text not null,
  allowed_scopes text[] not null default array['SOCIETY']::text[],
  is_sensitive boolean not null default false,
  requires_reason boolean not null default false,
  is_president_only boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint permission_catalog_key_check
    check (permission_key ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'),
  constraint permission_catalog_module_check
    check (module_key ~ '^[a-z][a-z0-9_]*$'),
  constraint permission_catalog_action_check
    check (action_type in ('VIEW', 'CREATE', 'EDIT', 'CHANGE_STATUS', 'APPROVE', 'CANCEL', 'FINANCIAL', 'MANAGE')),
  constraint permission_catalog_scopes_not_empty_check
    check (cardinality(allowed_scopes) > 0),
  constraint permission_catalog_scopes_check
    check (
      allowed_scopes <@ array[
        'SELF',
        'CHILDREN',
        'SELF_ASSIGNED_SECTIONS',
        'MEMBER_SECTIONS',
        'ASSIGNED_SECTIONS',
        'CREATED_EVENTS',
        'PARTICIPATING_EVENTS',
        'CHILD_PARTICIPATING_EVENTS',
        'SOCIETY'
      ]::text[]
    )
);

create index if not exists permission_catalog_module_idx
  on public.permission_catalog(module_key, is_active);

create table if not exists public.system_function_permission_templates (
  id uuid primary key default gen_random_uuid(),
  function_name text not null,
  permission_id uuid not null
    references public.permission_catalog(id) on delete restrict,
  scope_key text not null,
  is_locked boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint system_function_permission_templates_name_check
    check (length(trim(function_name)) > 0),
  constraint system_function_permission_templates_unique
    unique (function_name, permission_id)
);

create index if not exists system_function_permission_templates_name_idx
  on public.system_function_permission_templates(function_name);

create table if not exists public.society_function_permission_rules (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null
    references public.societies(id) on delete restrict,
  function_id uuid not null
    references public.society_member_functions(id) on delete restrict,
  permission_id uuid not null
    references public.permission_catalog(id) on delete restrict,
  scope_key text not null,
  is_locked boolean not null default false,
  changed_by_society_member_id uuid null
    references public.society_members(id) on delete restrict,
  change_reason text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint society_function_permission_rules_unique
    unique (function_id, permission_id)
);

create index if not exists society_function_permission_rules_society_idx
  on public.society_function_permission_rules(society_id, function_id);

create table if not exists public.society_member_permission_overrides (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null
    references public.societies(id) on delete restrict,
  society_member_id uuid not null
    references public.society_members(id) on delete restrict,
  permission_id uuid not null
    references public.permission_catalog(id) on delete restrict,
  effect text not null,
  scope_key text null,
  reason text not null,
  changed_by_society_member_id uuid null
    references public.society_members(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint society_member_permission_overrides_effect_check
    check (effect in ('ALLOW', 'DENY')),
  constraint society_member_permission_overrides_scope_check
    check (
      (effect = 'ALLOW' and scope_key is not null)
      or
      (effect = 'DENY' and scope_key is null)
    ),
  constraint society_member_permission_overrides_reason_check
    check (length(trim(reason)) > 0),
  constraint society_member_permission_overrides_unique
    unique (society_member_id, permission_id)
);

create index if not exists society_member_permission_overrides_society_idx
  on public.society_member_permission_overrides(society_id, society_member_id);

create table if not exists public.permission_change_audit (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null
    references public.societies(id) on delete restrict,
  target_type text not null,
  target_function_id uuid null
    references public.society_member_functions(id) on delete restrict,
  target_society_member_id uuid null
    references public.society_members(id) on delete restrict,
  permission_id uuid null
    references public.permission_catalog(id) on delete restrict,
  action text not null,
  previous_value jsonb null,
  new_value jsonb null,
  reason text null,
  actor_user_id uuid null,
  actor_society_member_id uuid null
    references public.society_members(id) on delete restrict,
  actor_function_names text[] not null default array[]::text[],
  created_at timestamptz not null default now(),
  constraint permission_change_audit_target_type_check
    check (target_type in ('FUNCTION', 'MEMBER', 'FUNCTION_ASSIGNMENT', 'SECTION_ROLE')),
  constraint permission_change_audit_action_check
    check (action in ('CREATED', 'UPDATED', 'REMOVED', 'ACTIVATED', 'DEACTIVATED')),
  constraint permission_change_audit_target_check
    check (
      (target_type = 'FUNCTION' and target_function_id is not null)
      or
      (target_type = 'MEMBER' and target_society_member_id is not null)
      or
      (target_type in ('FUNCTION_ASSIGNMENT', 'SECTION_ROLE'))
    )
);

create index if not exists permission_change_audit_society_created_idx
  on public.permission_change_audit(society_id, created_at desc);

create or replace function public.permissions_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists permission_catalog_set_updated_at
  on public.permission_catalog;
create trigger permission_catalog_set_updated_at
before update on public.permission_catalog
for each row execute function public.permissions_set_updated_at();

drop trigger if exists system_function_permission_templates_set_updated_at
  on public.system_function_permission_templates;
create trigger system_function_permission_templates_set_updated_at
before update on public.system_function_permission_templates
for each row execute function public.permissions_set_updated_at();

drop trigger if exists society_function_permission_rules_set_updated_at
  on public.society_function_permission_rules;
create trigger society_function_permission_rules_set_updated_at
before update on public.society_function_permission_rules
for each row execute function public.permissions_set_updated_at();

drop trigger if exists society_member_permission_overrides_set_updated_at
  on public.society_member_permission_overrides;
create trigger society_member_permission_overrides_set_updated_at
before update on public.society_member_permission_overrides
for each row execute function public.permissions_set_updated_at();

create or replace function public.permissions_validate_scope()
returns trigger
language plpgsql
as $$
declare
  v_allowed_scopes text[];
  v_function_society_id uuid;
  v_member_society_id uuid;
begin
  select allowed_scopes
  into v_allowed_scopes
  from public.permission_catalog
  where id = new.permission_id
    and is_active = true;

  if v_allowed_scopes is null then
    raise exception 'Dozvola ne postoji ili nije aktivna.';
  end if;

  if tg_table_name = 'society_member_permission_overrides'
     and (to_jsonb(new) ->> 'effect') = 'DENY' then
    if new.scope_key is not null then
      raise exception 'DENY izuzetak ne koristi scope_key.';
    end if;
  elsif not (new.scope_key = any(v_allowed_scopes)) then
    raise exception 'Opseg % nije dozvoljen za izabranu dozvolu.', new.scope_key;
  end if;

  if tg_table_name = 'society_function_permission_rules' then
    select society_id into v_function_society_id
    from public.society_member_functions
    where id = new.function_id;

    if v_function_society_id is distinct from new.society_id then
      raise exception 'Funkcija ne pripada izabranom drustvu.';
    end if;
  elsif tg_table_name = 'society_member_permission_overrides' then
    select society_id into v_member_society_id
    from public.society_members
    where id = new.society_member_id;

    if v_member_society_id is distinct from new.society_id then
      raise exception 'Clan ne pripada izabranom drustvu.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists system_function_permission_templates_validate_scope
  on public.system_function_permission_templates;
create trigger system_function_permission_templates_validate_scope
before insert or update on public.system_function_permission_templates
for each row execute function public.permissions_validate_scope();

drop trigger if exists society_function_permission_rules_validate_scope
  on public.society_function_permission_rules;
create trigger society_function_permission_rules_validate_scope
before insert or update on public.society_function_permission_rules
for each row execute function public.permissions_validate_scope();

drop trigger if exists society_member_permission_overrides_validate_scope
  on public.society_member_permission_overrides;
create trigger society_member_permission_overrides_validate_scope
before insert or update on public.society_member_permission_overrides
for each row execute function public.permissions_validate_scope();

create or replace function public.permissions_prevent_audit_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'Audit dozvola se ne moze menjati niti brisati.';
end;
$$;

drop trigger if exists permission_change_audit_no_update
  on public.permission_change_audit;
create trigger permission_change_audit_no_update
before update on public.permission_change_audit
for each row execute function public.permissions_prevent_audit_mutation();

drop trigger if exists permission_change_audit_no_delete
  on public.permission_change_audit;
create trigger permission_change_audit_no_delete
before delete on public.permission_change_audit
for each row execute function public.permissions_prevent_audit_mutation();

insert into public.permission_catalog (
  permission_key, module_key, label, action_type, allowed_scopes,
  is_sensitive, requires_reason, is_president_only
)
values
  ('members.view_basic', 'members', 'Pregled osnovnih i kontakt podataka', 'VIEW', array['SELF','CHILDREN','ASSIGNED_SECTIONS','SOCIETY'], false, false, false),
  ('members.view_sensitive', 'members', 'Pregled osetljivih podataka', 'VIEW', array['SELF','CHILDREN','ASSIGNED_SECTIONS','SOCIETY'], true, false, false),
  ('members.view_guardians', 'members', 'Pregled roditelja i staratelja', 'VIEW', array['SELF','CHILDREN','ASSIGNED_SECTIONS','SOCIETY'], true, false, false),
  ('members.view_history', 'members', 'Pregled istorije clanstva', 'VIEW', array['SELF','CHILDREN','ASSIGNED_SECTIONS','SOCIETY'], true, false, false),
  ('members.view_sections', 'members', 'Pregled sekcija clana', 'VIEW', array['SELF','CHILDREN','ASSIGNED_SECTIONS','SOCIETY'], false, false, false),
  ('members.view_audit', 'members', 'Detaljni audit clanova', 'VIEW', array['SOCIETY'], true, false, false),
  ('members.request_change', 'members', 'Slanje zahteva za izmenu svojih podataka ili podataka deteta', 'EDIT', array['SELF','CHILDREN'], true, false, false),
  ('members.create', 'members', 'Unos novog clana', 'CREATE', array['SOCIETY'], true, false, false),
  ('members.edit_basic', 'members', 'Izmena osnovnih i kontakt podataka', 'EDIT', array['ASSIGNED_SECTIONS','SOCIETY'], true, false, false),
  ('members.edit_sensitive', 'members', 'Izmena osetljivih podataka', 'EDIT', array['ASSIGNED_SECTIONS','SOCIETY'], true, true, false),
  ('members.change_status', 'members', 'Promena statusa clanstva', 'CHANGE_STATUS', array['SOCIETY'], true, true, false),
  ('members.manage_sections', 'members', 'Promena pripadnosti sekcijama', 'MANAGE', array['ASSIGNED_SECTIONS','SOCIETY'], false, false, false),
  ('members.manage_guardians', 'members', 'Upravljanje roditeljima i starateljima', 'MANAGE', array['SOCIETY'], true, true, false),
  ('members.review_change_requests', 'members', 'Odluka o zahtevima za izmenu podataka', 'APPROVE', array['SOCIETY'], true, true, false),
  ('members.bulk_import', 'members', 'Masovni unos osoba i priprema novih clanova', 'CREATE', array['SOCIETY'], true, false, false),

  ('sections.view', 'sections', 'Pregled sekcija', 'VIEW', array['CHILDREN','MEMBER_SECTIONS','ASSIGNED_SECTIONS','SOCIETY'], false, false, false),
  ('sections.view_members', 'sections', 'Pregled clanova sekcije', 'VIEW', array['ASSIGNED_SECTIONS','SOCIETY'], true, false, false),
  ('sections.view_roles', 'sections', 'Pregled UR-ova i korepetitora', 'VIEW', array['CHILDREN','MEMBER_SECTIONS','ASSIGNED_SECTIONS','SOCIETY'], false, false, false),
  ('sections.view_audit', 'sections', 'Detaljni audit sekcija', 'VIEW', array['SOCIETY'], true, false, false),
  ('sections.create', 'sections', 'Kreiranje sekcije', 'CREATE', array['SOCIETY'], false, false, false),
  ('sections.edit', 'sections', 'Izmena podataka sekcije', 'EDIT', array['ASSIGNED_SECTIONS','SOCIETY'], false, false, false),
  ('sections.change_status', 'sections', 'Aktiviranje i deaktiviranje sekcije', 'CHANGE_STATUS', array['SOCIETY'], true, true, false),
  ('sections.manage_members', 'sections', 'Upravljanje clanovima sekcije', 'MANAGE', array['ASSIGNED_SECTIONS','SOCIETY'], false, false, false),
  ('sections.manage_roles', 'sections', 'Rasporedjivanje UR-a i korepetitora', 'MANAGE', array['SOCIETY'], true, true, false),

  ('attendance.view', 'attendance', 'Pregled prisustva', 'VIEW', array['SELF','CHILDREN','SELF_ASSIGNED_SECTIONS','ASSIGNED_SECTIONS','SOCIETY'], false, false, false),
  ('attendance.view_audit', 'attendance', 'Detaljni audit prisustva', 'VIEW', array['SOCIETY'], true, false, false),
  ('attendance.open', 'attendance', 'Otvaranje probe', 'CREATE', array['ASSIGNED_SECTIONS','SOCIETY'], false, false, false),
  ('attendance.record_open', 'attendance', 'Evidentiranje otvorene probe', 'EDIT', array['ASSIGNED_SECTIONS','SOCIETY'], false, false, false),
  ('attendance.close', 'attendance', 'Zatvaranje probe', 'CHANGE_STATUS', array['ASSIGNED_SECTIONS','SOCIETY'], false, false, false),
  ('attendance.cancel_open', 'attendance', 'Otkazivanje otvorene probe', 'CANCEL', array['ASSIGNED_SECTIONS','SOCIETY'], true, true, false),
  ('attendance.edit_closed', 'attendance', 'Ispravka zatvorene probe', 'EDIT', array['ASSIGNED_SECTIONS','SOCIETY'], true, true, false),
  ('attendance.change_duration', 'attendance', 'Promena trajanja probe', 'EDIT', array['ASSIGNED_SECTIONS','SOCIETY'], false, false, false),

  ('events.view', 'events', 'Pregled dogadjaja', 'VIEW', array['CREATED_EVENTS','PARTICIPATING_EVENTS','CHILD_PARTICIPATING_EVENTS','ASSIGNED_SECTIONS','SOCIETY'], false, false, false),
  ('events.view_participants', 'events', 'Pregled ucesnika i gostiju', 'VIEW', array['ASSIGNED_SECTIONS','SOCIETY'], true, false, false),
  ('events.view_program', 'events', 'Pregled programa i izvodjaca', 'VIEW', array['PARTICIPATING_EVENTS','CHILD_PARTICIPATING_EVENTS','ASSIGNED_SECTIONS','SOCIETY'], false, false, false),
  ('events.view_fees', 'events', 'Pregled planiranih kotizacija', 'VIEW', array['SELF','CHILDREN','ASSIGNED_SECTIONS','SOCIETY'], true, false, false),
  ('events.view_audit', 'events', 'Detaljni audit dogadjaja', 'VIEW', array['SOCIETY'], true, false, false),
  ('events.create_edit_draft', 'events', 'Kreiranje i izmena nacrta', 'CREATE', array['ASSIGNED_SECTIONS','SOCIETY'], false, false, false),
  ('events.submit', 'events', 'Slanje dogadjaja na odobrenje', 'CHANGE_STATUS', array['CREATED_EVENTS','ASSIGNED_SECTIONS','SOCIETY'], false, false, false),
  ('events.review', 'events', 'Odobravanje ili odbijanje dogadjaja', 'APPROVE', array['ASSIGNED_SECTIONS','SOCIETY'], true, true, false),
  ('events.edit_approved', 'events', 'Izmena odobrenog dogadjaja', 'EDIT', array['ASSIGNED_SECTIONS','SOCIETY'], true, true, false),
  ('events.cancel_approved', 'events', 'Otkazivanje odobrenog dogadjaja', 'CANCEL', array['ASSIGNED_SECTIONS','SOCIETY'], true, true, false),
  ('events.manage_sections', 'events', 'Upravljanje sekcijama dogadjaja', 'MANAGE', array['ASSIGNED_SECTIONS','SOCIETY'], false, false, false),
  ('events.manage_participants', 'events', 'Upravljanje ucesnicima i gostima', 'MANAGE', array['ASSIGNED_SECTIONS','SOCIETY'], true, false, false),
  ('events.change_participant_status', 'events', 'Promena statusa ucesnika', 'CHANGE_STATUS', array['ASSIGNED_SECTIONS','SOCIETY'], true, false, false),
  ('events.manage_fee', 'events', 'Odredjivanje planirane kotizacije', 'FINANCIAL', array['ASSIGNED_SECTIONS','SOCIETY'], true, true, false),
  ('events.manage_program', 'events', 'Upravljanje nastupima, programom i izvodjacima', 'MANAGE', array['ASSIGNED_SECTIONS','SOCIETY'], false, false, false),

  ('repertoire.view', 'repertoire', 'Pregled repertoara', 'VIEW', array['CHILDREN','MEMBER_SECTIONS','ASSIGNED_SECTIONS','SOCIETY'], false, false, false),
  ('repertoire.view_audit', 'repertoire', 'Detaljni audit repertoara', 'VIEW', array['SOCIETY'], true, false, false),
  ('repertoire.create', 'repertoire', 'Dodavanje numere', 'CREATE', array['ASSIGNED_SECTIONS','SOCIETY'], false, false, false),
  ('repertoire.edit', 'repertoire', 'Izmena numere', 'EDIT', array['ASSIGNED_SECTIONS','SOCIETY'], false, false, false),
  ('repertoire.change_status', 'repertoire', 'Aktiviranje i deaktiviranje numere', 'CHANGE_STATUS', array['ASSIGNED_SECTIONS','SOCIETY'], true, true, false),
  ('repertoire.link_program', 'repertoire', 'Povezivanje numere sa programom', 'MANAGE', array['ASSIGNED_SECTIONS','SOCIETY'], false, false, false),

  ('finance.view', 'finance', 'Pregled finansija', 'VIEW', array['SELF','CHILDREN','SOCIETY'], true, false, false),
  ('finance.view_audit', 'finance', 'Detaljni finansijski audit', 'VIEW', array['SOCIETY'], true, false, false),
  ('finance.record_payment', 'finance', 'Evidentiranje uplate', 'FINANCIAL', array['SOCIETY'], true, false, false),
  ('finance.use_credit_for_fee', 'finance', 'Koriscenje kredita za kotizaciju', 'FINANCIAL', array['SOCIETY'], true, false, false),
  ('finance.record_refund', 'finance', 'Evidentiranje povracaja', 'FINANCIAL', array['SOCIETY'], true, true, false),
  ('finance.send_reminders', 'finance', 'Slanje opomena', 'MANAGE', array['SOCIETY'], true, false, false),
  ('finance.retry_messages', 'finance', 'Ponovno slanje finansijske poruke', 'MANAGE', array['SOCIETY'], false, false, false),
  ('finance.void_payment', 'finance', 'Ponistavanje uplate', 'FINANCIAL', array['SOCIETY'], true, true, false),
  ('finance.void_refund', 'finance', 'Ponistavanje povracaja', 'FINANCIAL', array['SOCIETY'], true, true, false),
  ('finance.correct_history', 'finance', 'Kontrolisana ispravka ranijih podataka', 'EDIT', array['SOCIETY'], true, true, false),
  ('finance.settings_standard_fee', 'finance', 'Promena standardne clanarine', 'EDIT', array['SOCIETY'], true, true, false),
  ('finance.settings_member_fee', 'finance', 'Promena rezima i iznosa clana', 'EDIT', array['SOCIETY'], true, true, false),
  ('finance.settings_calendar', 'finance', 'Promena meseci naplate', 'EDIT', array['SOCIETY'], true, true, false),
  ('finance.settings_other', 'finance', 'Promena ostalih finansijskih pravila', 'EDIT', array['SOCIETY'], true, true, false),

  ('permissions.manage', 'permissions', 'Upravljanje funkcijama i dozvolama', 'MANAGE', array['SOCIETY'], true, true, true)
on conflict (permission_key) do update
set
  module_key = excluded.module_key,
  label = excluded.label,
  action_type = excluded.action_type,
  allowed_scopes = excluded.allowed_scopes,
  is_sensitive = excluded.is_sensitive,
  requires_reason = excluded.requires_reason,
  is_president_only = excluded.is_president_only,
  is_active = true,
  updated_at = now();

-- Predsednik dobija sva prava za celo drustvo i sva su zakljucana.
insert into public.system_function_permission_templates (
  function_name, permission_id, scope_key, is_locked
)
select 'Predsednik', id, 'SOCIETY', true
from public.permission_catalog
where is_active = true
  and 'SOCIETY' = any(allowed_scopes)
on conflict (function_name, permission_id) do update
set scope_key = excluded.scope_key,
    is_locked = excluded.is_locked,
    updated_at = now();

-- Sekretar i upravnik pocinju globalnim read-only pregledom bez detaljnog audita.
insert into public.system_function_permission_templates (
  function_name, permission_id, scope_key, is_locked
)
select function_name, pc.id, 'SOCIETY', true
from (values ('Sekretar'), ('Upravnik')) as f(function_name)
join public.permission_catalog pc
  on pc.permission_key in (
    'members.view_basic',
    'members.view_sensitive',
    'members.view_guardians',
    'members.view_history',
    'members.view_sections',
    'sections.view',
    'sections.view_members',
    'sections.view_roles',
    'attendance.view',
    'events.view',
    'events.view_participants',
    'events.view_program',
    'events.view_fees',
    'repertoire.view',
    'finance.view'
  )
on conflict (function_name, permission_id) do update
set scope_key = excluded.scope_key,
    is_locked = excluded.is_locked,
    updated_at = now();

-- Blagajnik: operativni finansijski minimum.
insert into public.system_function_permission_templates (
  function_name, permission_id, scope_key, is_locked
)
select 'Blagajnik', id, 'SOCIETY', true
from public.permission_catalog
where permission_key in (
  'members.view_basic',
  'finance.view',
  'finance.record_payment',
  'finance.use_credit_for_fee',
  'finance.send_reminders',
  'finance.retry_messages'
)
on conflict (function_name, permission_id) do update
set scope_key = excluded.scope_key,
    is_locked = excluded.is_locked,
    updated_at = now();

-- UR: pocetna prava samo za aktivno dodeljene sekcije.
insert into public.system_function_permission_templates (
  function_name, permission_id, scope_key, is_locked
)
select 'UR', id, 'ASSIGNED_SECTIONS', true
from public.permission_catalog
where permission_key in (
  'members.view_basic',
  'members.view_guardians',
  'members.view_sections',
  'members.manage_sections',
  'sections.view',
  'sections.view_members',
  'sections.view_roles',
  'attendance.view',
  'attendance.open',
  'attendance.record_open',
  'attendance.close',
  'attendance.cancel_open',
  'events.view',
  'events.view_participants',
  'events.view_program',
  'events.create_edit_draft',
  'events.submit',
  'events.manage_sections',
  'events.manage_participants',
  'events.change_participant_status',
  'events.manage_program',
  'repertoire.view',
  'repertoire.link_program'
)
on conflict (function_name, permission_id) do update
set scope_key = excluded.scope_key,
    is_locked = excluded.is_locked,
    updated_at = now();

-- Korepetitor vidi samo sopstveno prisustvo u sekcijama svoje dodele.
insert into public.system_function_permission_templates (
  function_name, permission_id, scope_key, is_locked
)
select 'Korepetitor', id, 'SELF_ASSIGNED_SECTIONS', true
from public.permission_catalog
where permission_key = 'attendance.view'
on conflict (function_name, permission_id) do update
set scope_key = excluded.scope_key,
    is_locked = excluded.is_locked,
    updated_at = now();

-- Clan: licni read-only pregled.
insert into public.system_function_permission_templates (
  function_name, permission_id, scope_key, is_locked
)
select 'Clan', pc.id, values_row.scope_key, true
from (
  values
    ('members.view_basic', 'SELF'),
    ('members.view_sensitive', 'SELF'),
    ('members.view_guardians', 'SELF'),
    ('members.view_history', 'SELF'),
    ('members.view_sections', 'SELF'),
    ('members.request_change', 'SELF'),
    ('sections.view', 'MEMBER_SECTIONS'),
    ('sections.view_roles', 'MEMBER_SECTIONS'),
    ('attendance.view', 'SELF'),
    ('events.view', 'PARTICIPATING_EVENTS'),
    ('events.view_program', 'PARTICIPATING_EVENTS'),
    ('events.view_fees', 'SELF'),
    ('repertoire.view', 'MEMBER_SECTIONS'),
    ('finance.view', 'SELF')
) as values_row(permission_key, scope_key)
join public.permission_catalog pc
  on pc.permission_key = values_row.permission_key
on conflict (function_name, permission_id) do update
set scope_key = excluded.scope_key,
    is_locked = excluded.is_locked,
    updated_at = now();

-- Aktivna baza koristi naziv sa dijakritikom; podrzati i njega.
insert into public.system_function_permission_templates (
  function_name, permission_id, scope_key, is_locked
)
select 'Član', permission_id, scope_key, is_locked
from public.system_function_permission_templates
where function_name = 'Clan'
on conflict (function_name, permission_id) do update
set scope_key = excluded.scope_key,
    is_locked = excluded.is_locked,
    updated_at = now();

-- Kopirati pocetna pravila u sva postojeca drustva. Postojeca pravila se ne
-- prepisuju pri ponovnom pokretanju migracije.
insert into public.society_function_permission_rules (
  society_id,
  function_id,
  permission_id,
  scope_key,
  is_locked
)
select
  smf.society_id,
  smf.id,
  template.permission_id,
  template.scope_key,
  template.is_locked
from public.society_member_functions smf
join public.system_function_permission_templates template
  on lower(trim(template.function_name)) = lower(trim(smf.name))
join public.permission_catalog pc
  on pc.id = template.permission_id
 and pc.is_active = true
where coalesce(smf.is_active, true) = true
on conflict (function_id, permission_id) do nothing;

create or replace function public.permissions_bootstrap_function_defaults()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if coalesce(new.is_active, true) = false then
    return new;
  end if;

  insert into public.society_function_permission_rules (
    society_id,
    function_id,
    permission_id,
    scope_key,
    is_locked
  )
  select
    new.society_id,
    new.id,
    template.permission_id,
    template.scope_key,
    template.is_locked
  from public.system_function_permission_templates template
  join public.permission_catalog pc
    on pc.id = template.permission_id
   and pc.is_active = true
  where lower(trim(template.function_name)) = lower(trim(new.name))
  on conflict (function_id, permission_id) do nothing;

  return new;
end;
$$;

drop trigger if exists society_member_functions_bootstrap_permissions
  on public.society_member_functions;
create trigger society_member_functions_bootstrap_permissions
after insert or update of name, is_active
on public.society_member_functions
for each row execute function public.permissions_bootstrap_function_defaults();

alter table public.permission_catalog enable row level security;
alter table public.system_function_permission_templates enable row level security;
alter table public.society_function_permission_rules enable row level security;
alter table public.society_member_permission_overrides enable row level security;
alter table public.permission_change_audit enable row level security;

revoke all on table public.permission_catalog from anon, authenticated;
revoke all on table public.system_function_permission_templates from anon, authenticated;
revoke all on table public.society_function_permission_rules from anon, authenticated;
revoke all on table public.society_member_permission_overrides from anon, authenticated;
revoke all on table public.permission_change_audit from anon, authenticated;

revoke all on function public.permissions_set_updated_at() from public;
revoke all on function public.permissions_validate_scope() from public;
revoke all on function public.permissions_prevent_audit_mutation() from public;
revoke all on function public.permissions_bootstrap_function_defaults() from public;

commit;
