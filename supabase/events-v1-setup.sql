-- FOLKLORAS DEV/V1
-- DOGADJAJI: koncerti, putovanja, repertoar, ucesnici i approval workflow.
-- Pokrenuti nakon people, sections, society_members i section_role_assignments setup-a.
-- Fajl je bezbedan za ponovno izvrsavanje.

begin;

alter table public.people
  add column if not exists nationality text null,
  add column if not exists passport_issuing_country text null,
  add column if not exists parental_travel_consent boolean not null default false,
  add column if not exists parental_travel_consent_valid_until date null;

alter table public.section_role_assignments
  add column if not exists can_manage_repertoire boolean not null default false;

create table if not exists public.society_events (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  event_type text not null check (event_type in ('CONCERT', 'TRIP')),
  title text not null,
  description text null,
  status text not null default 'DRAFT'
    check (status in ('DRAFT', 'PENDING', 'APPROVED', 'REJECTED', 'CANCELLED', 'COMPLETED')),
  organizer_name text null,
  organizer_contact text null,
  responsible_member_id uuid null references public.society_members(id) on delete restrict,
  country text not null default 'Srbija',
  city text null,
  venue_name text null,
  address text null,
  meeting_point text null,
  meeting_at timestamptz null,
  departure_at timestamptz null,
  return_at timestamptz null,
  confirmation_deadline timestamptz null,
  transport_type text null,
  transport_company text null,
  accommodation text null,
  meals_note text null,
  has_participation_fee boolean not null default false,
  default_participation_fee_amount numeric(12,2) null,
  currency text not null default 'RSD',
  payment_due_date date null,
  fee_note text null,
  created_by_user_id uuid null,
  created_by_society_member_id uuid null references public.society_members(id) on delete restrict,
  created_by_role text not null,
  submitted_at timestamptz null,
  reviewed_at timestamptz null,
  reviewed_by_user_id uuid null,
  reviewed_by_society_member_id uuid null references public.society_members(id) on delete restrict,
  rejection_reason text null,
  cancelled_at timestamptz null,
  cancellation_reason text null,
  completed_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint society_events_dates_check check (
    departure_at is null or return_at is null or return_at > departure_at
  ),
  constraint society_events_fee_check check (
    (has_participation_fee = false and default_participation_fee_amount is null)
    or
    (has_participation_fee = true and default_participation_fee_amount is not null
      and default_participation_fee_amount >= 0)
  ),
  constraint society_events_currency_check check (length(trim(currency)) = 3)
);

create index if not exists society_events_society_status_date_idx
  on public.society_events(society_id, status, departure_at, created_at desc);

create table if not exists public.event_status_history (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.society_events(id) on delete restrict,
  old_status text null,
  new_status text not null
    check (new_status in ('DRAFT', 'PENDING', 'APPROVED', 'REJECTED', 'CANCELLED', 'COMPLETED')),
  changed_by_user_id uuid null,
  changed_by_society_member_id uuid null references public.society_members(id) on delete restrict,
  changed_by_role text not null,
  reason text null,
  created_at timestamptz not null default now()
);

create index if not exists event_status_history_event_idx
  on public.event_status_history(event_id, created_at desc);

create table if not exists public.event_sections (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.society_events(id) on delete restrict,
  section_id uuid not null references public.sections(id) on delete restrict,
  added_by_user_id uuid null,
  added_by_society_member_id uuid null references public.society_members(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (event_id, section_id)
);

create index if not exists event_sections_section_idx
  on public.event_sections(section_id, event_id);

create table if not exists public.event_participants (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.society_events(id) on delete restrict,
  person_id uuid not null references public.people(id) on delete restrict,
  society_member_id uuid null references public.society_members(id) on delete restrict,
  participation_status text not null default 'PLANNED'
    check (participation_status in ('PLANNED', 'CONFIRMED', 'DECLINED', 'CANCELLED', 'ATTENDED', 'ABSENT')),
  participation_fee_amount numeric(12,2) null
    check (participation_fee_amount is null or participation_fee_amount >= 0),
  fee_is_overridden boolean not null default false,
  note text null,
  added_by_user_id uuid null,
  added_by_society_member_id uuid null references public.society_members(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (event_id, person_id)
);

create index if not exists event_participants_event_status_idx
  on public.event_participants(event_id, participation_status);

create table if not exists public.event_participant_sections (
  id uuid primary key default gen_random_uuid(),
  event_participant_id uuid not null references public.event_participants(id) on delete cascade,
  event_section_id uuid not null references public.event_sections(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (event_participant_id, event_section_id)
);

create table if not exists public.repertoire_items (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  name text not null,
  item_type text not null default 'CHOREOGRAPHY'
    check (item_type in ('CHOREOGRAPHY', 'SONG', 'INSTRUMENTAL', 'OTHER')),
  duration_minutes integer null check (duration_minutes is null or duration_minutes > 0),
  description text null,
  costume_note text null,
  status text not null default 'ACTIVE' check (status in ('ACTIVE', 'INACTIVE')),
  created_by_user_id uuid null,
  created_by_society_member_id uuid null references public.society_members(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists repertoire_items_society_name_unique
  on public.repertoire_items(society_id, lower(trim(name)));

create table if not exists public.repertoire_item_sections (
  id uuid primary key default gen_random_uuid(),
  repertoire_item_id uuid not null references public.repertoire_items(id) on delete restrict,
  section_id uuid not null references public.sections(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (repertoire_item_id, section_id)
);

create index if not exists repertoire_item_sections_section_idx
  on public.repertoire_item_sections(section_id, repertoire_item_id);

create table if not exists public.event_appearances (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.society_events(id) on delete restrict,
  title text not null,
  starts_at timestamptz null,
  ends_at timestamptz null,
  country text not null default 'Srbija',
  city text null,
  venue_name text null,
  address text null,
  performance_order integer not null default 0 check (performance_order >= 0),
  note text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint event_appearances_dates_check check (
    starts_at is null or ends_at is null or ends_at > starts_at
  )
);

create index if not exists event_appearances_event_order_idx
  on public.event_appearances(event_id, performance_order, starts_at);

create table if not exists public.event_appearance_repertoire (
  id uuid primary key default gen_random_uuid(),
  event_appearance_id uuid not null references public.event_appearances(id) on delete cascade,
  event_section_id uuid not null references public.event_sections(id) on delete restrict,
  repertoire_item_id uuid not null references public.repertoire_items(id) on delete restrict,
  performance_order integer not null default 0 check (performance_order >= 0),
  note text null,
  created_at timestamptz not null default now(),
  unique (event_appearance_id, event_section_id, repertoire_item_id)
);

create index if not exists event_appearance_repertoire_order_idx
  on public.event_appearance_repertoire(event_appearance_id, performance_order);

create table if not exists public.event_repertoire_participants (
  id uuid primary key default gen_random_uuid(),
  event_appearance_repertoire_id uuid not null
    references public.event_appearance_repertoire(id) on delete cascade,
  event_participant_id uuid not null references public.event_participants(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (event_appearance_repertoire_id, event_participant_id)
);

create table if not exists public.person_data_change_requests (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  person_id uuid not null references public.people(id) on delete restrict,
  event_id uuid null references public.society_events(id) on delete restrict,
  current_values jsonb not null default '{}'::jsonb,
  proposed_changes jsonb not null,
  status text not null default 'PENDING'
    check (status in ('PENDING', 'APPROVED', 'REJECTED')),
  requested_by_user_id uuid null,
  requested_by_society_member_id uuid null references public.society_members(id) on delete restrict,
  requested_by_role text not null,
  requested_at timestamptz not null default now(),
  reviewed_by_user_id uuid null,
  reviewed_by_society_member_id uuid null references public.society_members(id) on delete restrict,
  reviewed_at timestamptz null,
  rejection_reason text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint person_data_change_requests_json_check check (
    jsonb_typeof(current_values) = 'object'
    and jsonb_typeof(proposed_changes) = 'object'
    and proposed_changes <> '{}'::jsonb
  ),
  constraint person_data_change_requests_allowed_keys_check check (
    proposed_changes - array[
      'gender', 'birth_date', 'address', 'city', 'postal_code', 'country',
      'jmbg', 'nationality', 'passport_number', 'passport_issuing_country',
      'passport_expiry_date'
    ]::text[] = '{}'::jsonb
  )
);

create index if not exists person_data_change_requests_review_idx
  on public.person_data_change_requests(society_id, status, requested_at desc);

create unique index if not exists person_data_change_requests_one_pending_context
  on public.person_data_change_requests(
    society_id,
    person_id,
    coalesce(event_id, '00000000-0000-0000-0000-000000000000'::uuid)
  )
  where status = 'PENDING';

-- Proverava identitet clana ili gosta na dogadjaju.
create or replace function public.validate_event_participant()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_event society_events;
  v_member society_members;
begin
  select * into v_event
  from society_events
  where id = new.event_id;

  if not new.fee_is_overridden and new.participation_fee_amount is null then
    new.participation_fee_amount :=
      case
        when v_event.has_participation_fee
          then v_event.default_participation_fee_amount
        else null
      end;
  end if;

  if new.society_member_id is not null then
    select * into v_member
    from society_members
    where id = new.society_member_id;

    if not found
      or v_member.person_id <> new.person_id
      or v_member.society_id <> v_event.society_id then
      raise exception 'Clan ne pripada osobi ili drustvu izabranog dogadjaja.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists validate_event_participant_trigger on public.event_participants;
create trigger validate_event_participant_trigger
before insert or update of event_id, person_id, society_member_id
on public.event_participants
for each row execute function public.validate_event_participant();

-- Gost ne moze pripadati sekciji; clan i sekcija moraju biti sa istog dogadjaja.
create or replace function public.validate_event_participant_section()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_participant event_participants;
  v_event_section event_sections;
begin
  select * into v_participant from event_participants where id = new.event_participant_id;
  select * into v_event_section from event_sections where id = new.event_section_id;

  if v_participant.society_member_id is null then
    raise exception 'Gost ne moze biti povezan sa sekcijom dogadjaja.';
  end if;

  if v_participant.event_id <> v_event_section.event_id then
    raise exception 'Ucesnik i sekcija ne pripadaju istom dogadjaju.';
  end if;

  if not exists (
    select 1 from member_sections
    where society_member_id = v_participant.society_member_id
      and section_id = v_event_section.section_id
      and status = 'ACTIVE'
  ) then
    raise exception 'Clan nema aktivno clanstvo u izabranoj sekciji.';
  end if;

  return new;
end;
$$;

drop trigger if exists validate_event_participant_section_trigger
  on public.event_participant_sections;
create trigger validate_event_participant_section_trigger
before insert or update
on public.event_participant_sections
for each row execute function public.validate_event_participant_section();

-- Numera, sekcija i nastup moraju pripadati istom drustvu i dogadjaju.
create or replace function public.validate_event_appearance_repertoire()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_appearance event_appearances;
  v_event_section event_sections;
  v_event society_events;
  v_repertoire repertoire_items;
begin
  select * into v_appearance from event_appearances where id = new.event_appearance_id;
  select * into v_event_section from event_sections where id = new.event_section_id;
  select * into v_event from society_events where id = v_appearance.event_id;
  select * into v_repertoire from repertoire_items where id = new.repertoire_item_id;

  if v_appearance.event_id <> v_event_section.event_id then
    raise exception 'Nastup i sekcija ne pripadaju istom dogadjaju.';
  end if;

  if v_repertoire.society_id <> v_event.society_id then
    raise exception 'Numera ne pripada drustvu dogadjaja.';
  end if;

  if not exists (
    select 1 from repertoire_item_sections
    where repertoire_item_id = new.repertoire_item_id
      and section_id = v_event_section.section_id
  ) then
    raise exception 'Numera nije povezana sa izabranom sekcijom.';
  end if;

  return new;
end;
$$;

drop trigger if exists validate_event_appearance_repertoire_trigger
  on public.event_appearance_repertoire;
create trigger validate_event_appearance_repertoire_trigger
before insert or update
on public.event_appearance_repertoire
for each row execute function public.validate_event_appearance_repertoire();

-- Izvodjac mora biti clan, pripadati dogadjaju i sekciji koja izvodi numeru.
create or replace function public.validate_event_repertoire_participant()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_program event_appearance_repertoire;
  v_participant event_participants;
begin
  select * into v_program
  from event_appearance_repertoire
  where id = new.event_appearance_repertoire_id;

  select * into v_participant
  from event_participants
  where id = new.event_participant_id;

  if v_participant.society_member_id is null then
    raise exception 'Gost ne moze biti izvodjac numere.';
  end if;

  if not exists (
    select 1
    from event_participant_sections eps
    where eps.event_participant_id = v_participant.id
      and eps.event_section_id = v_program.event_section_id
  ) then
    raise exception 'Izvodjac nije povezan sa sekcijom koja izvodi numeru.';
  end if;

  return new;
end;
$$;

drop trigger if exists validate_event_repertoire_participant_trigger
  on public.event_repertoire_participants;
create trigger validate_event_repertoire_participant_trigger
before insert or update
on public.event_repertoire_participants
for each row execute function public.validate_event_repertoire_participant();

-- Statusni workflow dogadjaja.
create or replace function public.submit_event(
  p_event_id uuid,
  p_actor_role text,
  p_actor_user_id uuid default null,
  p_actor_member_id uuid default null
) returns public.society_events
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event society_events;
  v_old_status text;
begin
  if p_actor_role not in ('Predsednik', 'UR') then
    raise exception 'Nemate pravo slanja dogadjaja na odobravanje.';
  end if;

  select * into v_event from society_events where id = p_event_id for update;
  if not found then raise exception 'Dogadjaj nije pronadjen.'; end if;
  if v_event.status not in ('DRAFT', 'REJECTED') then
    raise exception 'Samo nacrt ili odbijen dogadjaj moze biti ponovo poslat.';
  end if;

  v_old_status := v_event.status;
  update society_events set
    status = 'PENDING',
    submitted_at = now(),
    reviewed_at = null,
    reviewed_by_user_id = null,
    reviewed_by_society_member_id = null,
    rejection_reason = null,
    updated_at = now()
  where id = p_event_id
  returning * into v_event;

  insert into event_status_history (
    event_id, old_status, new_status, changed_by_user_id,
    changed_by_society_member_id, changed_by_role
  ) values (
    p_event_id, v_old_status, 'PENDING', p_actor_user_id,
    p_actor_member_id, p_actor_role
  );

  return v_event;
end;
$$;

create or replace function public.approve_event(
  p_event_id uuid,
  p_actor_user_id uuid default null,
  p_actor_member_id uuid default null
) returns public.society_events
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event society_events;
  v_old_status text;
begin
  select * into v_event from society_events where id = p_event_id for update;
  if not found then raise exception 'Dogadjaj nije pronadjen.'; end if;
  if v_event.status not in ('DRAFT', 'PENDING', 'REJECTED') then
    raise exception 'Dogadjaj u ovom statusu ne moze biti odobren.';
  end if;
  if length(trim(v_event.title)) = 0
    or length(trim(v_event.country)) = 0
    or length(trim(coalesce(v_event.city, ''))) = 0 then
    raise exception 'Naziv, drzava i mesto su obavezni za odobravanje.';
  end if;
  if v_event.event_type = 'TRIP'
    and (v_event.departure_at is null or v_event.return_at is null) then
    raise exception 'Polazak i povratak su obavezni za putovanje.';
  end if;
  if not exists (select 1 from event_sections where event_id = p_event_id) then
    raise exception 'Dogadjaj mora imati najmanje jednu sekciju.';
  end if;

  v_old_status := v_event.status;
  update society_events set
    status = 'APPROVED',
    reviewed_at = now(),
    reviewed_by_user_id = p_actor_user_id,
    reviewed_by_society_member_id = p_actor_member_id,
    rejection_reason = null,
    updated_at = now()
  where id = p_event_id
  returning * into v_event;

  insert into event_status_history (
    event_id, old_status, new_status, changed_by_user_id,
    changed_by_society_member_id, changed_by_role
  ) values (
    p_event_id, v_old_status, 'APPROVED', p_actor_user_id,
    p_actor_member_id, 'Predsednik'
  );

  return v_event;
end;
$$;

create or replace function public.reject_event(
  p_event_id uuid,
  p_reason text,
  p_actor_user_id uuid default null,
  p_actor_member_id uuid default null
) returns public.society_events
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event society_events;
begin
  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'Razlog odbijanja je obavezan.';
  end if;

  update society_events set
    status = 'REJECTED',
    reviewed_at = now(),
    reviewed_by_user_id = p_actor_user_id,
    reviewed_by_society_member_id = p_actor_member_id,
    rejection_reason = trim(p_reason),
    updated_at = now()
  where id = p_event_id and status = 'PENDING'
  returning * into v_event;

  if not found then raise exception 'Zahtev na cekanju nije pronadjen.'; end if;

  insert into event_status_history (
    event_id, old_status, new_status, changed_by_user_id,
    changed_by_society_member_id, changed_by_role, reason
  ) values (
    p_event_id, 'PENDING', 'REJECTED', p_actor_user_id,
    p_actor_member_id, 'Predsednik', trim(p_reason)
  );

  return v_event;
end;
$$;

create or replace function public.cancel_event(
  p_event_id uuid,
  p_reason text,
  p_actor_role text,
  p_actor_user_id uuid default null,
  p_actor_member_id uuid default null
) returns public.society_events
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event society_events;
  v_old_status text;
begin
  if p_actor_role not in ('Predsednik', 'UR') then
    raise exception 'Nemate pravo otkazivanja dogadjaja.';
  end if;
  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'Razlog otkazivanja je obavezan.';
  end if;

  select * into v_event from society_events where id = p_event_id for update;
  if not found then raise exception 'Dogadjaj nije pronadjen.'; end if;
  if v_event.status in ('CANCELLED', 'COMPLETED') then
    raise exception 'Dogadjaj je vec zavrsen ili otkazan.';
  end if;
  if p_actor_role = 'UR' and v_event.status not in ('DRAFT', 'PENDING') then
    raise exception 'UR ne moze otkazati odobren dogadjaj.';
  end if;

  v_old_status := v_event.status;
  update society_events set
    status = 'CANCELLED',
    cancelled_at = now(),
    cancellation_reason = trim(p_reason),
    updated_at = now()
  where id = p_event_id
  returning * into v_event;

  insert into event_status_history (
    event_id, old_status, new_status, changed_by_user_id,
    changed_by_society_member_id, changed_by_role, reason
  ) values (
    p_event_id, v_old_status, 'CANCELLED', p_actor_user_id,
    p_actor_member_id, p_actor_role, trim(p_reason)
  );

  return v_event;
end;
$$;

create or replace function public.complete_event(
  p_event_id uuid,
  p_actor_role text,
  p_actor_user_id uuid default null,
  p_actor_member_id uuid default null
) returns public.society_events
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event society_events;
begin
  if p_actor_role not in ('Predsednik', 'UR') then
    raise exception 'Nemate pravo zavrsavanja dogadjaja.';
  end if;

  update society_events set
    status = 'COMPLETED',
    completed_at = now(),
    updated_at = now()
  where id = p_event_id and status = 'APPROVED'
  returning * into v_event;

  if not found then raise exception 'Odobren dogadjaj nije pronadjen.'; end if;

  insert into event_status_history (
    event_id, old_status, new_status, changed_by_user_id,
    changed_by_society_member_id, changed_by_role
  ) values (
    p_event_id, 'APPROVED', 'COMPLETED', p_actor_user_id,
    p_actor_member_id, p_actor_role
  );

  return v_event;
end;
$$;

-- Status ucesnika; za inostrano putovanje CONFIRMED zahteva kompletne podatke.
create or replace function public.set_event_participant_status(
  p_event_participant_id uuid,
  p_new_status text,
  p_actor_role text
) returns public.event_participants
language plpgsql
security definer
set search_path = public
as $$
declare
  v_participant event_participants;
  v_event society_events;
  v_person people;
begin
  if p_actor_role not in ('Predsednik', 'UR') then
    raise exception 'Status ucesnika menja samo predsednik ili UR.';
  end if;
  if p_new_status not in ('PLANNED', 'CONFIRMED', 'DECLINED', 'CANCELLED', 'ATTENDED', 'ABSENT') then
    raise exception 'Nepoznat status ucesnika.';
  end if;

  select * into v_participant
  from event_participants
  where id = p_event_participant_id
  for update;
  if not found then raise exception 'Ucesnik nije pronadjen.'; end if;

  select * into v_event from society_events where id = v_participant.event_id;
  select * into v_person from people where id = v_participant.person_id;

  if p_new_status = 'CONFIRMED'
    and v_participant.society_member_id is null
    and (
      length(trim(v_person.first_name)) = 0
      or length(trim(v_person.last_name)) = 0
      or (
        v_person.email is null
        and v_person.phone is null
      )
    ) then
    raise exception 'Gost mora imati ime, prezime i najmanje telefon ili email.';
  end if;

  if p_new_status = 'CONFIRMED'
    and v_event.event_type = 'TRIP'
    and lower(trim(v_event.country)) not in ('srbija', 'serbia') then
    if v_event.return_at is null then
      raise exception 'Datum povratka je obavezan za inostrano putovanje.';
    end if;
    if length(trim(v_person.first_name)) = 0
      or length(trim(v_person.last_name)) = 0
      or v_person.birth_date is null
      or v_person.gender is null
      or length(trim(coalesce(v_person.nationality, ''))) = 0
      or length(trim(coalesce(v_person.address, ''))) = 0
      or length(trim(coalesce(v_person.city, ''))) = 0
      or length(trim(coalesce(v_person.postal_code, ''))) = 0
      or length(trim(coalesce(v_person.country, ''))) = 0
      or length(trim(coalesce(v_person.passport_number, ''))) = 0
      or length(trim(coalesce(v_person.passport_issuing_country, ''))) = 0
      or v_person.passport_expiry_date is null
      or (
        v_person.email is null
        and v_person.phone is null
        and not exists (
          select 1
          from person_guardians pg
          join people guardian on guardian.id = pg.guardian_person_id
          where pg.child_person_id = v_person.id
            and pg.is_primary = true
            and (guardian.email is not null or guardian.phone is not null)
        )
      ) then
      raise exception 'Putna dokumentacija osobe nije kompletna.';
    end if;
    if v_person.passport_expiry_date < v_event.return_at::date then
      raise exception 'Pasos ne vazi do datuma povratka.';
    end if;
    if v_person.birth_date > (v_event.departure_at::date - interval '18 years')::date
      and (
        not v_person.parental_travel_consent
        or v_person.parental_travel_consent_valid_until is null
        or v_person.parental_travel_consent_valid_until < v_event.return_at::date
      ) then
      raise exception 'Maloletni putnik nema vazecu saglasnost oba roditelja za put u inostranstvo.';
    end if;
  end if;

  update event_participants set
    participation_status = p_new_status,
    updated_at = now()
  where id = p_event_participant_id
  returning * into v_participant;

  return v_participant;
end;
$$;

-- Predsednicko odobravanje zahteva atomarno menja people.
create or replace function public.approve_person_data_change_request(
  p_request_id uuid,
  p_actor_user_id uuid default null,
  p_actor_member_id uuid default null
) returns public.person_data_change_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request person_data_change_requests;
  v_changes jsonb;
begin
  select * into v_request
  from person_data_change_requests
  where id = p_request_id and status = 'PENDING'
  for update;
  if not found then raise exception 'Zahtev na cekanju nije pronadjen.'; end if;

  v_changes := v_request.proposed_changes;

  update people set
    gender = case when v_changes ? 'gender' then nullif(v_changes->>'gender', '') else gender end,
    birth_date = case when v_changes ? 'birth_date' then nullif(v_changes->>'birth_date', '')::date else birth_date end,
    address = case when v_changes ? 'address' then nullif(v_changes->>'address', '') else address end,
    city = case when v_changes ? 'city' then nullif(v_changes->>'city', '') else city end,
    postal_code = case when v_changes ? 'postal_code' then nullif(v_changes->>'postal_code', '') else postal_code end,
    country = case when v_changes ? 'country' then nullif(v_changes->>'country', '') else country end,
    jmbg = case when v_changes ? 'jmbg' then nullif(v_changes->>'jmbg', '') else jmbg end,
    nationality = case when v_changes ? 'nationality' then nullif(v_changes->>'nationality', '') else nationality end,
    passport_number = case when v_changes ? 'passport_number' then nullif(v_changes->>'passport_number', '') else passport_number end,
    passport_issuing_country = case when v_changes ? 'passport_issuing_country' then nullif(v_changes->>'passport_issuing_country', '') else passport_issuing_country end,
    passport_expiry_date = case when v_changes ? 'passport_expiry_date' then nullif(v_changes->>'passport_expiry_date', '')::date else passport_expiry_date end,
    updated_at = now()
  where id = v_request.person_id;

  update person_data_change_requests set
    status = 'APPROVED',
    reviewed_by_user_id = p_actor_user_id,
    reviewed_by_society_member_id = p_actor_member_id,
    reviewed_at = now(),
    rejection_reason = null,
    updated_at = now()
  where id = p_request_id
  returning * into v_request;

  return v_request;
end;
$$;

create or replace function public.reject_person_data_change_request(
  p_request_id uuid,
  p_reason text,
  p_actor_user_id uuid default null,
  p_actor_member_id uuid default null
) returns public.person_data_change_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request person_data_change_requests;
begin
  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'Razlog odbijanja je obavezan.';
  end if;

  update person_data_change_requests set
    status = 'REJECTED',
    reviewed_by_user_id = p_actor_user_id,
    reviewed_by_society_member_id = p_actor_member_id,
    reviewed_at = now(),
    rejection_reason = trim(p_reason),
    updated_at = now()
  where id = p_request_id and status = 'PENDING'
  returning * into v_request;

  if not found then raise exception 'Zahtev na cekanju nije pronadjen.'; end if;
  return v_request;
end;
$$;

-- DEV/V1 politike. Finalni Auth/RLS mora proveravati drustvo, predsednika,
-- UR sekcije i can_manage_repertoire na strani baze.
alter table public.society_events enable row level security;
alter table public.event_status_history enable row level security;
alter table public.event_sections enable row level security;
alter table public.event_participants enable row level security;
alter table public.event_participant_sections enable row level security;
alter table public.repertoire_items enable row level security;
alter table public.repertoire_item_sections enable row level security;
alter table public.event_appearances enable row level security;
alter table public.event_appearance_repertoire enable row level security;
alter table public.event_repertoire_participants enable row level security;
alter table public.person_data_change_requests enable row level security;

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'society_events', 'event_status_history', 'event_sections',
    'event_participants', 'event_participant_sections', 'repertoire_items',
    'repertoire_item_sections', 'event_appearances',
    'event_appearance_repertoire', 'event_repertoire_participants',
    'person_data_change_requests'
  ]
  loop
    execute format('drop policy if exists %I on public.%I', 'DEV ' || v_table || ' all', v_table);
    execute format(
      'create policy %I on public.%I for all using (true) with check (true)',
      'DEV ' || v_table || ' all',
      v_table
    );
    execute format(
      'grant select, insert, update, delete on public.%I to anon, authenticated',
      v_table
    );
  end loop;
end;
$$;

revoke update, delete on public.event_status_history from anon, authenticated;
revoke delete on public.society_events from anon, authenticated;

grant execute on function public.submit_event(uuid, text, uuid, uuid) to anon, authenticated;
grant execute on function public.approve_event(uuid, uuid, uuid) to anon, authenticated;
grant execute on function public.reject_event(uuid, text, uuid, uuid) to anon, authenticated;
grant execute on function public.cancel_event(uuid, text, text, uuid, uuid) to anon, authenticated;
grant execute on function public.complete_event(uuid, text, uuid, uuid) to anon, authenticated;
grant execute on function public.set_event_participant_status(uuid, text, text) to anon, authenticated;
grant execute on function public.approve_person_data_change_request(uuid, uuid, uuid) to anon, authenticated;
grant execute on function public.reject_person_data_change_request(uuid, text, uuid, uuid) to anon, authenticated;

commit;

select pg_notify('pgrst', 'reload schema');

-- Kontrolna provera kreiranih tabela.
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in (
    'society_events', 'event_status_history', 'event_sections',
    'event_participants', 'event_participant_sections', 'repertoire_items',
    'repertoire_item_sections', 'event_appearances',
    'event_appearance_repertoire', 'event_repertoire_participants',
    'person_data_change_requests'
  )
order by table_name;
