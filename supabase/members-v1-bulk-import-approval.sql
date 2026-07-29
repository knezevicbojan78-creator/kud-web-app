begin;

create table if not exists public.member_import_candidates (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete cascade,
  profile jsonb not null,
  source_row integer not null,
  source_file_name text not null,
  status text not null default 'PENDING'
    check (status in ('PENDING', 'APPROVED', 'REJECTED')),
  created_by_user_id uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  reviewed_by_user_id uuid references auth.users(id),
  reviewed_at timestamptz,
  society_member_id uuid references public.society_members(id)
);

alter table public.member_import_candidates enable row level security;
revoke all on public.member_import_candidates from public, anon, authenticated;

create index if not exists member_import_candidates_pending_idx
  on public.member_import_candidates (society_id, created_at)
  where status = 'PENDING';

create extension if not exists pgcrypto;

create table if not exists public.member_data_drafts (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null unique
    references public.member_import_candidates(id) on delete cascade,
  society_id uuid not null references public.societies(id) on delete cascade,
  draft jsonb not null default '{}'::jsonb,
  draft_version integer not null default 1,
  last_saved_at timestamptz,
  active_section text,
  active_editor_role text check (active_editor_role in ('MEMBER', 'GUARDIAN', 'PRESIDENT')),
  active_editor_until timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.member_data_invitations (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null
    references public.member_import_candidates(id) on delete cascade,
  society_id uuid not null references public.societies(id) on delete cascade,
  recipient_role text not null check (recipient_role in ('MEMBER', 'GUARDIAN')),
  recipient_email text not null,
  token_hash text not null unique,
  status text not null default 'INVITED'
    check (status in (
      'INVITED', 'OPENED', 'IN_PROGRESS', 'SUBMITTED', 'CANCELLED', 'EXPIRED'
    )),
  expires_at timestamptz not null,
  opened_at timestamptz,
  last_saved_at timestamptz,
  submitted_at timestamptz,
  created_by_user_id uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (candidate_id, recipient_role)
);

-- Upgrade the earlier single-recipient invitation table without losing drafts.
alter table public.member_data_invitations
  add column if not exists recipient_role text;

update public.member_data_invitations
set recipient_role = 'MEMBER'
where recipient_role is null;

alter table public.member_data_invitations
  alter column recipient_role set not null;

alter table public.member_data_invitations
  drop constraint if exists member_data_invitations_candidate_id_key;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.member_data_invitations'::regclass
      and conname = 'member_data_invitations_recipient_role_check'
  ) then
    alter table public.member_data_invitations
      add constraint member_data_invitations_recipient_role_check
      check (recipient_role in ('MEMBER', 'GUARDIAN'));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.member_data_invitations'::regclass
      and conname = 'member_data_invitations_candidate_role_key'
  ) then
    alter table public.member_data_invitations
      add constraint member_data_invitations_candidate_role_key
      unique (candidate_id, recipient_role);
  end if;
end
$$;

alter table public.member_data_drafts enable row level security;
alter table public.member_data_invitations enable row level security;
revoke all on public.member_data_drafts from public, anon, authenticated;
revoke all on public.member_data_invitations from public, anon, authenticated;

create index if not exists member_data_invitations_candidate_idx
  on public.member_data_invitations(candidate_id, status);

create or replace function public.auth_prepare_bulk_member_import(
  p_society_id uuid,
  p_file_name text,
  p_rows jsonb
)
returns integer
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_row jsonb;
  v_person_id uuid;
  v_count integer := 0;
begin
  if v_user_id is null
     or not public.auth_can_bulk_import_members(p_society_id) then
    raise exception 'Nemate dozvolu za masovni unos clanova.';
  end if;
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) = 0 then
    raise exception 'Nema redova za pripremu.';
  end if;

  for v_row in select value from jsonb_array_elements(p_rows)
  loop
    if nullif(btrim(v_row ->> 'first_name'), '') is null
       or nullif(btrim(v_row ->> 'last_name'), '') is null
       or nullif(lower(btrim(v_row ->> 'email')), '') is null then
      raise exception 'Ime, prezime i email su obavezni u svakom redu.';
    end if;

    select id into v_person_id
    from public.people
    where lower(email) = lower(btrim(v_row ->> 'email'))
    limit 1;
    if v_person_id is not null then
      continue;
    end if;
    if exists (
      select 1
      from public.member_import_candidates candidate
      where candidate.society_id = p_society_id
        and candidate.status = 'PENDING'
        and lower(candidate.profile ->> 'email') =
          lower(btrim(v_row ->> 'email'))
    ) then
      continue;
    end if;

    if v_row ->> 'person_kind' = 'Roditelj/staratelj' then
      insert into public.people (
        first_name, last_name, email, phone, country
      ) values (
        btrim(v_row ->> 'first_name'),
        btrim(v_row ->> 'last_name'),
        lower(btrim(v_row ->> 'email')),
        nullif(btrim(v_row ->> 'phone'), ''),
        coalesce(nullif(btrim(v_row ->> 'country'), ''), 'Srbija')
      );
    elsif v_row ->> 'person_kind' = 'Član' then
      insert into public.member_import_candidates (
        society_id, profile, source_row, source_file_name, created_by_user_id
      ) values (
        p_society_id,
        v_row - 'row_number' - 'person_kind',
        (v_row ->> 'row_number')::integer,
        btrim(p_file_name),
        v_user_id
      );
    else
      raise exception 'Vrsta osobe nije dozvoljena.';
    end if;
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

create or replace function public.auth_get_pending_member_imports(
  p_society_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if auth.uid() is null
     or not public.auth_can_bulk_import_members(p_society_id) then
    raise exception 'Nemate dozvolu za pregled pripremljenih clanova.';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', candidate.id,
      'profile', candidate.profile,
      'source_row', candidate.source_row,
      'source_file_name', candidate.source_file_name,
      'created_at', candidate.created_at,
      'member_invitation_status', member_invitation.status,
      'guardian_invitation_status', guardian_invitation.status,
      'invitation_last_saved_at', greatest(
        member_invitation.last_saved_at,
        guardian_invitation.last_saved_at
      ),
      'draft', coalesce(data_draft.draft, candidate.profile),
      'missing_fields', (
        select coalesce(jsonb_agg(missing.field), '[]'::jsonb)
        from (values
          ('first_name', nullif(coalesce(data_draft.draft, candidate.profile) ->> 'first_name', '') is null),
          ('last_name', nullif(coalesce(data_draft.draft, candidate.profile) ->> 'last_name', '') is null),
          ('gender', nullif(coalesce(data_draft.draft, candidate.profile) ->> 'gender', '') is null),
          ('birth_date', nullif(coalesce(data_draft.draft, candidate.profile) ->> 'birth_date', '') is null),
          ('email', nullif(coalesce(data_draft.draft, candidate.profile) ->> 'email', '') is null),
          ('phone', nullif(coalesce(data_draft.draft, candidate.profile) ->> 'phone', '') is null),
          ('address', nullif(coalesce(data_draft.draft, candidate.profile) ->> 'address', '') is null),
          ('city', nullif(coalesce(data_draft.draft, candidate.profile) ->> 'city', '') is null),
          ('postal_code', nullif(coalesce(data_draft.draft, candidate.profile) ->> 'postal_code', '') is null),
          ('country', nullif(coalesce(data_draft.draft, candidate.profile) ->> 'country', '') is null),
          ('guardian1.first_name',
            coalesce((coalesce(data_draft.draft, candidate.profile) ->> 'is_minor_member')::boolean, false)
            and nullif(coalesce(data_draft.draft, candidate.profile) #>> '{guardian1,first_name}', '') is null),
          ('guardian1.last_name',
            coalesce((coalesce(data_draft.draft, candidate.profile) ->> 'is_minor_member')::boolean, false)
            and nullif(coalesce(data_draft.draft, candidate.profile) #>> '{guardian1,last_name}', '') is null),
          ('guardian1.email',
            coalesce((coalesce(data_draft.draft, candidate.profile) ->> 'is_minor_member')::boolean, false)
            and nullif(coalesce(data_draft.draft, candidate.profile) #>> '{guardian1,email}', '') is null),
          ('guardian1.phone',
            coalesce((coalesce(data_draft.draft, candidate.profile) ->> 'is_minor_member')::boolean, false)
            and nullif(coalesce(data_draft.draft, candidate.profile) #>> '{guardian1,phone}', '') is null)
        ) missing(field, is_missing)
        where missing.is_missing
      )
    ) order by candidate.created_at, candidate.source_row)
    from public.member_import_candidates candidate
    left join public.member_data_drafts data_draft
      on data_draft.candidate_id = candidate.id
    left join public.member_data_invitations member_invitation
      on member_invitation.candidate_id = candidate.id
     and member_invitation.recipient_role = 'MEMBER'
    left join public.member_data_invitations guardian_invitation
      on guardian_invitation.candidate_id = candidate.id
     and guardian_invitation.recipient_role = 'GUARDIAN'
    where candidate.society_id = p_society_id
      and candidate.status = 'PENDING'
  ), '[]'::jsonb);
end;
$$;

drop function if exists public.auth_approve_pending_member_import(uuid,uuid,date);

create or replace function public.auth_approve_pending_member_import(
  p_society_id uuid,
  p_candidate_id uuid,
  p_start_date date,
  p_profile_updates jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_candidate public.member_import_candidates%rowtype;
  v_data_draft public.member_data_drafts%rowtype;
  v_profile jsonb;
  v_guardians jsonb := '[]'::jsonb;
  v_created jsonb;
begin
  if auth.uid() is null
     or not public.auth_can_bulk_import_members(p_society_id) then
    raise exception 'Nemate dozvolu za potvrdu clana.';
  end if;
  if not exists (
    select 1
    from public.society_members member
    join public.people person on person.id = member.person_id
    join public.society_member_function_assignments assignment
      on assignment.society_member_id = member.id
     and assignment.society_id = member.society_id
    join public.society_member_functions member_function
      on member_function.id = assignment.function_id
     and member_function.society_id = member.society_id
    where member.society_id = p_society_id
      and member.status = 'ACTIVE'
      and coalesce(member.user_id, person.user_id) = auth.uid()
      and member_function.name = 'Predsednik'
      and member_function.is_active
  ) then
    raise exception 'Samo predsednik moze da potvrdi pripremljenog clana.';
  end if;
  if p_start_date is null then
    raise exception 'Datum pocetka clanstva je obavezan.';
  end if;

  select * into v_candidate
  from public.member_import_candidates
  where id = p_candidate_id
    and society_id = p_society_id
    and status = 'PENDING'
  for update;
  if v_candidate.id is null then
    raise exception 'Kandidat nije pronadjen ili je vec obradjen.';
  end if;
  select * into v_data_draft
  from public.member_data_drafts
  where candidate_id = v_candidate.id;
  v_profile := coalesce(v_data_draft.draft, v_candidate.profile);
  if nullif(btrim(v_profile ->> 'first_name'), '') is null
     or nullif(btrim(v_profile ->> 'last_name'), '') is null
     or nullif(btrim(v_profile ->> 'gender'), '') is null
     or nullif(v_profile ->> 'birth_date', '') is null
     or nullif(lower(btrim(v_profile ->> 'email')), '') is null
     or nullif(btrim(v_profile ->> 'phone'), '') is null
     or nullif(btrim(v_profile ->> 'address'), '') is null
     or nullif(btrim(v_profile ->> 'city'), '') is null
     or nullif(btrim(v_profile ->> 'postal_code'), '') is null
     or nullif(btrim(v_profile ->> 'country'), '') is null then
    raise exception 'Nisu uneti svi obavezni licni podaci clana.';
  end if;
  if (
    nullif(btrim(v_profile ->> 'passport_number'), '') is null
  ) <> (
    nullif(v_profile ->> 'passport_expiry_date', '') is null
  ) then
    raise exception 'Broj pasosa i datum vazenja moraju biti uneti zajedno.';
  end if;
  if coalesce((v_profile ->> 'is_minor_member')::boolean, false) then
    if nullif(btrim(v_profile #>> '{guardian1,first_name}'), '') is null
       or nullif(btrim(v_profile #>> '{guardian1,last_name}'), '') is null
       or nullif(lower(btrim(v_profile #>> '{guardian1,email}')), '') is null
       or nullif(btrim(v_profile #>> '{guardian1,phone}'), '') is null then
      raise exception 'Nedostaju podaci prvog roditelja ili staratelja.';
    end if;
    v_guardians := jsonb_build_array(
      (v_profile -> 'guardian1') || jsonb_build_object('is_primary', true)
    );
    if coalesce((v_profile ->> 'showGuardian2')::boolean, false) then
      v_guardians := v_guardians || jsonb_build_array(
        (v_profile -> 'guardian2') || jsonb_build_object('is_primary', false)
      );
    end if;
  end if;
  if not coalesce((v_profile ->> 'is_minor_member')::boolean, false)
     and nullif(btrim(coalesce(
    p_profile_updates ->> 'phone',
    v_profile ->> 'phone'
  )), '') is null then
    raise exception 'Telefon je obavezan za zavrsetak unosa clana.';
  end if;

  v_created := public.auth_create_society_member(
    p_society_id,
    v_profile || coalesce(p_profile_updates, '{}'::jsonb) || jsonb_build_object(
      'status', 'ACTIVE',
      'start_date', p_start_date,
      'membership_fee_required', true,
      'membership_fee_amount', 0
    ),
    v_guardians,
    array[]::uuid[],
    array[]::uuid[]
  );

  update public.member_import_candidates
  set status = 'APPROVED',
      reviewed_by_user_id = auth.uid(),
      reviewed_at = now(),
      society_member_id = (v_created ->> 'society_member_id')::uuid
  where id = v_candidate.id;

  update public.member_data_invitations
  set status = 'CANCELLED', updated_at = now()
  where candidate_id = v_candidate.id
    and status <> 'SUBMITTED';
  return v_created;
end;
$$;

create or replace function public.auth_reject_pending_member_import(
  p_society_id uuid,
  p_candidate_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_candidate public.member_import_candidates%rowtype;
  v_is_president boolean;
begin
  if auth.uid() is null
     or not public.auth_can_bulk_import_members(p_society_id) then
    raise exception 'Nemate dozvolu za otkazivanje masovnog unosa.';
  end if;

  select * into v_candidate
  from public.member_import_candidates
  where id = p_candidate_id
    and society_id = p_society_id
    and status = 'PENDING'
  for update;
  if v_candidate.id is null then
    raise exception 'Kandidat nije pronadjen ili je vec obradjen.';
  end if;

  select exists (
    select 1
    from public.society_members member
    join public.people person on person.id = member.person_id
    join public.society_member_function_assignments assignment
      on assignment.society_member_id = member.id
     and assignment.society_id = member.society_id
    join public.society_member_functions member_function
      on member_function.id = assignment.function_id
     and member_function.society_id = member.society_id
    where member.society_id = p_society_id
      and member.status = 'ACTIVE'
      and coalesce(member.user_id, person.user_id) = auth.uid()
      and member_function.name = 'Predsednik'
      and member_function.is_active
  ) into v_is_president;

  if not v_is_president and v_candidate.created_by_user_id <> auth.uid() then
    raise exception 'Samo predsednik ili korisnik koji je pripremio unos moze da ga otkaze.';
  end if;

  update public.member_import_candidates
  set status = 'REJECTED',
      reviewed_by_user_id = auth.uid(),
      reviewed_at = now()
  where id = v_candidate.id;

  update public.member_data_invitations
  set status = 'CANCELLED', updated_at = now()
  where candidate_id = v_candidate.id
    and status not in ('SUBMITTED', 'CANCELLED');
end;
$$;

create or replace function public.auth_update_pending_member_draft(
  p_society_id uuid,
  p_candidate_id uuid,
  p_draft jsonb
)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_candidate public.member_import_candidates%rowtype;
begin
  if auth.uid() is null or not exists (
    select 1
    from public.society_members member
    join public.people person on person.id = member.person_id
    join public.society_member_function_assignments assignment
      on assignment.society_member_id = member.id
     and assignment.society_id = member.society_id
    join public.society_member_functions member_function
      on member_function.id = assignment.function_id
    where member.society_id = p_society_id
      and member.status = 'ACTIVE'
      and coalesce(member.user_id, person.user_id) = auth.uid()
      and member_function.name = 'Predsednik'
      and member_function.is_active
  ) then
    raise exception 'Samo predsednik moze da dopuni podatke kandidata.';
  end if;

  select * into v_candidate
  from public.member_import_candidates
  where id = p_candidate_id
    and society_id = p_society_id
    and status = 'PENDING'
  for update;
  if v_candidate.id is null then
    raise exception 'Kandidat nije pronadjen.';
  end if;

  insert into public.member_data_drafts (
    candidate_id, society_id, draft, draft_version, last_saved_at
  ) values (
    v_candidate.id, p_society_id, coalesce(p_draft, '{}'::jsonb), 1, now()
  )
  on conflict (candidate_id) do update set
    draft = excluded.draft,
    draft_version = public.member_data_drafts.draft_version + 1,
    last_saved_at = now(),
    active_section = null,
    active_editor_role = null,
    active_editor_until = null,
    updated_at = now();

  update public.member_import_candidates
  set profile = coalesce(p_draft, '{}'::jsonb)
    - 'guardian1' - 'guardian2' - 'showGuardian2'
  where id = v_candidate.id;
end;
$$;

drop function if exists public.auth_cancel_member_data_invitation(uuid,uuid);

create or replace function public.auth_cancel_member_data_invitation(
  p_society_id uuid,
  p_candidate_id uuid,
  p_recipient_role text
)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if auth.uid() is null or not exists (
    select 1
    from public.society_members member
    join public.people person on person.id = member.person_id
    join public.society_member_function_assignments assignment
      on assignment.society_member_id = member.id
     and assignment.society_id = member.society_id
    join public.society_member_functions member_function
      on member_function.id = assignment.function_id
    where member.society_id = p_society_id
      and member.status = 'ACTIVE'
      and coalesce(member.user_id, person.user_id) = auth.uid()
      and member_function.name = 'Predsednik'
      and member_function.is_active
  ) then
    raise exception 'Samo predsednik moze da otkaze poziv.';
  end if;

  update public.member_data_invitations invitation
  set status = 'CANCELLED', updated_at = now()
  from public.member_import_candidates candidate
  where invitation.candidate_id = candidate.id
    and candidate.id = p_candidate_id
    and candidate.society_id = p_society_id
    and invitation.recipient_role = p_recipient_role
    and invitation.status <> 'SUBMITTED';
end;
$$;

drop function if exists public.auth_create_member_data_invitation(uuid,uuid);

create or replace function public.auth_create_member_data_invitation(
  p_society_id uuid,
  p_candidate_id uuid,
  p_recipient_role text,
  p_recipient_email text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_candidate public.member_import_candidates%rowtype;
  v_token text := encode(extensions.gen_random_bytes(32), 'hex');
  v_email text;
begin
  if auth.uid() is null or not exists (
    select 1
    from public.society_members member
    join public.people person on person.id = member.person_id
    join public.society_member_function_assignments assignment
      on assignment.society_member_id = member.id
     and assignment.society_id = member.society_id
    join public.society_member_functions member_function
      on member_function.id = assignment.function_id
     and member_function.society_id = member.society_id
    where member.society_id = p_society_id
      and member.status = 'ACTIVE'
      and coalesce(member.user_id, person.user_id) = auth.uid()
      and member_function.name = 'Predsednik'
      and member_function.is_active
  ) then
    raise exception 'Samo predsednik moze da posalje poziv za dopunu.';
  end if;

  select * into v_candidate
  from public.member_import_candidates
  where id = p_candidate_id
    and society_id = p_society_id
    and status = 'PENDING';
  if v_candidate.id is null then
    raise exception 'Kandidat nije pronadjen.';
  end if;
  if p_recipient_role not in ('MEMBER', 'GUARDIAN') then
    raise exception 'Vrsta primaoca nije dozvoljena.';
  end if;
  v_email := lower(btrim(coalesce(
    p_recipient_email,
    case when p_recipient_role = 'MEMBER'
      then v_candidate.profile ->> 'email' else null end
  )));
  if nullif(v_email, '') is null then
    raise exception 'Email primaoca je obavezan.';
  end if;

  insert into public.member_data_drafts (
    candidate_id, society_id, draft
  ) values (
    v_candidate.id, p_society_id,
    v_candidate.profile
      - 'parental_travel_consent'
      - 'parental_travel_consent_valid_until'
  )
  on conflict (candidate_id) do nothing;
  if p_recipient_role = 'GUARDIAN' then
    update public.member_data_drafts
    set draft = jsonb_set(
      draft,
      '{guardian1}',
      coalesce(draft -> 'guardian1', '{}'::jsonb)
        || jsonb_build_object('email', v_email),
      true
    ),
    updated_at = now()
    where candidate_id = v_candidate.id;
  end if;

  insert into public.member_data_invitations (
    candidate_id, society_id, recipient_role, recipient_email, token_hash, status,
    expires_at, created_by_user_id
  ) values (
    v_candidate.id, p_society_id, p_recipient_role, v_email,
    encode(extensions.digest(v_token, 'sha256'), 'hex'),
    'INVITED', now() + interval '7 days', auth.uid()
  )
  on conflict (candidate_id, recipient_role) do update set
    token_hash = excluded.token_hash,
    recipient_email = excluded.recipient_email,
    status = 'INVITED',
    expires_at = excluded.expires_at,
    created_by_user_id = excluded.created_by_user_id,
    updated_at = now();

  return jsonb_build_object(
    'token', v_token,
    'email', v_email,
    'recipient_role', p_recipient_role,
    'recipient_name', concat_ws(
      ' ', v_candidate.profile ->> 'first_name',
      v_candidate.profile ->> 'last_name'
    )
  );
end;
$$;

create or replace function public.public_get_member_data_invitation(
  p_token text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_invitation public.member_data_invitations%rowtype;
  v_draft public.member_data_drafts%rowtype;
  v_locked boolean := false;
begin
  select * into v_invitation
  from public.member_data_invitations
  where token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
  for update;
  if v_invitation.id is null or v_invitation.status = 'CANCELLED' then
    raise exception 'Link nije vazeci.';
  end if;
  if v_invitation.expires_at <= now() then
    update public.member_data_invitations
    set status = 'EXPIRED', updated_at = now()
    where id = v_invitation.id;
    raise exception 'Link je istekao.';
  end if;
  if v_invitation.status = 'INVITED' then
    update public.member_data_invitations
    set status = 'OPENED', opened_at = coalesce(opened_at, now()),
        updated_at = now()
    where id = v_invitation.id;
    v_invitation.status := 'OPENED';
  end if;

  select * into v_draft
  from public.member_data_drafts
  where candidate_id = v_invitation.candidate_id
  for update;
  if v_draft.id is null then
    raise exception 'Nacrt nije pronadjen.';
  end if;
  v_locked := v_draft.active_editor_until > now()
    and v_draft.active_editor_role is distinct from v_invitation.recipient_role;
  if not v_locked then
    update public.member_data_drafts
    set active_section = 'MEMBER_DATA',
        active_editor_role = v_invitation.recipient_role,
        active_editor_until = now() + interval '5 minutes',
        updated_at = now()
    where id = v_draft.id;
  end if;

  return jsonb_build_object(
    'status', v_invitation.status,
    'recipient_role', v_invitation.recipient_role,
    'draft', v_draft.draft,
    'draft_version', v_draft.draft_version,
    'last_saved_at', v_draft.last_saved_at,
    'expires_at', v_invitation.expires_at,
    'editing_locked', v_locked,
    'editing_by', case v_draft.active_editor_role
      when 'MEMBER' then 'dete'
      when 'GUARDIAN' then 'roditelj/staratelj'
      when 'PRESIDENT' then 'predsednik'
      else null end,
    'editing_until', v_draft.active_editor_until
  );
end;
$$;

create or replace function public.public_save_member_data_draft(
  p_token text,
  p_draft jsonb,
  p_expected_version integer
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_invitation public.member_data_invitations%rowtype;
  v_draft public.member_data_drafts%rowtype;
  v_next_draft jsonb;
begin
  select * into v_invitation
  from public.member_data_invitations
  where token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
  for update;
  if v_invitation.id is null
     or v_invitation.status in ('SUBMITTED', 'CANCELLED', 'EXPIRED')
     or v_invitation.expires_at <= now() then
    raise exception 'Nacrt vise nije moguce sacuvati.';
  end if;
  select * into v_draft
  from public.member_data_drafts
  where candidate_id = v_invitation.candidate_id
  for update;
  if v_draft.active_editor_until > now()
     and v_draft.active_editor_role is distinct from v_invitation.recipient_role then
    raise exception 'Podatke trenutno menja druga osoba.';
  end if;
  if v_draft.draft_version <> p_expected_version then
    raise exception 'Podaci su promenjeni u drugom prozoru. Osvezite stranicu.';
  end if;

  v_next_draft := coalesce(p_draft, '{}'::jsonb)
    - 'parental_travel_consent'
    - 'parental_travel_consent_valid_until';
  if v_invitation.recipient_role = 'MEMBER' then
    if nullif(v_next_draft ->> 'birth_date', '') is not null
       and (v_next_draft ->> 'birth_date')::date > current_date - interval '12 years' then
      raise exception 'Dete mladje od 12 godina ne moze samostalno dopunjavati podatke.';
    end if;
    v_next_draft := v_next_draft
      - 'guardian1' - 'guardian2' - 'showGuardian2';
    v_next_draft := v_next_draft || jsonb_build_object(
      'guardian1', coalesce(v_draft.draft -> 'guardian1', '{}'::jsonb),
      'guardian2', coalesce(v_draft.draft -> 'guardian2', '{}'::jsonb),
      'showGuardian2', coalesce((v_draft.draft ->> 'showGuardian2')::boolean, false)
    );
  end if;

  update public.member_data_drafts
  set draft = v_next_draft,
      draft_version = draft_version + 1,
      last_saved_at = now(),
      active_section = 'MEMBER_DATA',
      active_editor_role = v_invitation.recipient_role,
      active_editor_until = now() + interval '5 minutes',
      updated_at = now()
  where id = v_draft.id
  returning * into v_draft;

  update public.member_data_invitations
  set status = 'IN_PROGRESS', last_saved_at = now(), updated_at = now()
  where id = v_invitation.id;

  return jsonb_build_object(
    'draft_version', v_draft.draft_version,
    'last_saved_at', v_draft.last_saved_at
  );
end;
$$;

create or replace function public.public_submit_member_data(
  p_token text,
  p_draft jsonb,
  p_expected_version integer
)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_invitation public.member_data_invitations%rowtype;
  v_draft public.member_data_drafts%rowtype;
  v_next_draft jsonb;
  v_minor boolean := coalesce((p_draft ->> 'is_minor_member')::boolean, false);
begin
  select * into v_invitation
  from public.member_data_invitations
  where token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
  for update;
  if v_invitation.id is null
     or v_invitation.status in ('SUBMITTED', 'CANCELLED', 'EXPIRED')
     or v_invitation.expires_at <= now() then
    raise exception 'Podatke vise nije moguce poslati.';
  end if;
  select * into v_draft
  from public.member_data_drafts
  where candidate_id = v_invitation.candidate_id
  for update;
  if v_draft.active_editor_until > now()
     and v_draft.active_editor_role is distinct from v_invitation.recipient_role then
    raise exception 'Podatke trenutno menja druga osoba.';
  end if;
  if v_draft.draft_version <> p_expected_version then
    raise exception 'Podaci su promenjeni u drugom prozoru. Osvezite stranicu.';
  end if;
  if nullif(btrim(p_draft ->> 'first_name'), '') is null
     or nullif(btrim(p_draft ->> 'last_name'), '') is null
     or nullif(lower(btrim(p_draft ->> 'email')), '') is null then
    raise exception 'Ime, prezime i email su obavezni.';
  end if;
  if lower(btrim(p_draft ->> 'email')) <> lower(v_invitation.recipient_email) then
    if v_invitation.recipient_role = 'MEMBER' then
      raise exception 'Email clana iz poziva nije moguce promeniti.';
    end if;
  end if;
  if v_invitation.recipient_role = 'GUARDIAN'
     and lower(btrim(p_draft #>> '{guardian1,email}')) <>
       lower(v_invitation.recipient_email) then
    raise exception 'Email roditelja iz poziva nije moguce promeniti.';
  end if;
  if not v_minor and nullif(btrim(p_draft ->> 'phone'), '') is null then
    raise exception 'Telefon je obavezan za punoletnog clana.';
  end if;
  if v_invitation.recipient_role = 'MEMBER'
     and nullif(p_draft ->> 'birth_date', '') is not null
     and (p_draft ->> 'birth_date')::date > current_date - interval '12 years' then
    raise exception 'Dete mladje od 12 godina ne moze samostalno poslati podatke.';
  end if;
  if v_invitation.recipient_role = 'GUARDIAN' and v_minor and (
    nullif(p_draft ->> 'birth_date', '') is null
    or nullif(btrim(p_draft #>> '{guardian1,first_name}'), '') is null
    or nullif(btrim(p_draft #>> '{guardian1,last_name}'), '') is null
    or nullif(lower(btrim(p_draft #>> '{guardian1,email}')), '') is null
    or nullif(btrim(p_draft #>> '{guardian1,phone}'), '') is null
  ) then
    raise exception 'Za maloletnog clana obavezni su datum rodjenja i podaci prvog roditelja ili staratelja.';
  end if;

  v_next_draft := p_draft
    - 'parental_travel_consent'
    - 'parental_travel_consent_valid_until';
  if v_invitation.recipient_role = 'MEMBER' then
    v_next_draft := v_next_draft
      - 'guardian1' - 'guardian2' - 'showGuardian2';
    v_next_draft := v_next_draft || jsonb_build_object(
      'guardian1', coalesce(v_draft.draft -> 'guardian1', '{}'::jsonb),
      'guardian2', coalesce(v_draft.draft -> 'guardian2', '{}'::jsonb),
      'showGuardian2', coalesce((v_draft.draft ->> 'showGuardian2')::boolean, false)
    );
  end if;

  update public.member_data_drafts
  set draft = v_next_draft,
      draft_version = draft_version + 1,
      last_saved_at = now(),
      active_editor_until = null,
      updated_at = now()
  where id = v_draft.id;

  update public.member_data_invitations
  set status = 'SUBMITTED',
      last_saved_at = now(),
      submitted_at = now(),
      updated_at = now()
  where id = v_invitation.id;

  update public.member_import_candidates
  set profile = v_next_draft
    - 'guardian1' - 'guardian2' - 'showGuardian2'
    - 'parental_travel_consent'
    - 'parental_travel_consent_valid_until'
  where id = v_invitation.candidate_id and status = 'PENDING';
end;
$$;

revoke all on function public.auth_prepare_bulk_member_import(uuid,text,jsonb)
  from public, anon;
revoke all on function public.auth_get_pending_member_imports(uuid)
  from public, anon;
revoke all on function public.auth_approve_pending_member_import(uuid,uuid,date,jsonb)
  from public, anon;
revoke all on function public.auth_reject_pending_member_import(uuid,uuid)
  from public, anon;
revoke all on function public.auth_update_pending_member_draft(uuid,uuid,jsonb)
  from public, anon;
revoke all on function public.auth_create_member_data_invitation(uuid,uuid,text,text)
  from public, anon;
revoke all on function public.auth_cancel_member_data_invitation(uuid,uuid,text)
  from public, anon;
revoke all on function public.public_get_member_data_invitation(text)
  from public, anon;
revoke all on function public.public_save_member_data_draft(text,jsonb,integer)
  from public, anon;
revoke all on function public.public_submit_member_data(text,jsonb,integer)
  from public, anon;
grant execute on function public.auth_prepare_bulk_member_import(uuid,text,jsonb)
  to authenticated;
grant execute on function public.auth_get_pending_member_imports(uuid)
  to authenticated;
grant execute on function public.auth_approve_pending_member_import(uuid,uuid,date,jsonb)
  to authenticated;
grant execute on function public.auth_reject_pending_member_import(uuid,uuid)
  to authenticated;
grant execute on function public.auth_update_pending_member_draft(uuid,uuid,jsonb)
  to authenticated;
grant execute on function public.auth_create_member_data_invitation(uuid,uuid,text,text)
  to authenticated;
grant execute on function public.auth_cancel_member_data_invitation(uuid,uuid,text)
  to authenticated;
grant execute on function public.public_get_member_data_invitation(text)
  to anon, authenticated;
grant execute on function public.public_save_member_data_draft(text,jsonb,integer)
  to anon, authenticated;
grant execute on function public.public_submit_member_data(text,jsonb,integer)
  to anon, authenticated;

select pg_notify('pgrst', 'reload schema');
commit;
