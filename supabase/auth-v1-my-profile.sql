begin;

create table if not exists public.person_profile_change_history (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  society_member_id uuid not null references public.society_members(id) on delete restrict,
  person_id uuid not null references public.people(id) on delete restrict,
  changed_fields text[] not null,
  changed_by_user_id uuid not null,
  changed_at timestamptz not null default now()
);

alter table public.person_profile_change_history enable row level security;
revoke all on table public.person_profile_change_history from public, anon, authenticated;

create or replace function public.auth_update_my_profile(p_profile jsonb)
returns public.people
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_member public.society_members;
  v_person public.people;
  v_result public.people;
  v_changed_fields text[] := array[]::text[];
  v_key text;
  v_allowed_keys constant text[] := array[
    'first_name', 'last_name', 'gender', 'birth_date', 'address', 'city',
    'postal_code', 'country', 'nationality', 'phone', 'shoe_size', 'jmbg',
    'passport_number', 'passport_issuing_country', 'passport_expiry_date'
  ];
begin
  if v_user_id is null then raise exception 'Prijava je obavezna.'; end if;

  select member.* into v_member
  from public.society_members member
  join public.people person on person.id = member.person_id
  join public.societies society on society.id = member.society_id
  where member.status = 'ACTIVE'
    and society.status = 'ACTIVE'
    and coalesce(member.user_id, person.user_id) = v_user_id
  order by member.created_at, member.id
  limit 1
  for update of member;

  if v_member.id is null then raise exception 'Aktivni članski profil nije pronađen.'; end if;
  select * into v_person from public.people where id = v_member.person_id for update;

  if nullif(btrim(p_profile->>'first_name'), '') is null
     or nullif(btrim(p_profile->>'last_name'), '') is null then
    raise exception 'Ime i prezime su obavezni.';
  end if;
  if (nullif(btrim(p_profile->>'passport_number'), '') is null)
     <> (nullif(p_profile->>'passport_expiry_date', '') is null) then
    raise exception 'Broj pasoša i datum važenja moraju biti uneti zajedno.';
  end if;

  foreach v_key in array v_allowed_keys loop
    if to_jsonb(v_person)->>v_key is distinct from nullif(btrim(coalesce(p_profile->>v_key, '')), '') then
      v_changed_fields := array_append(v_changed_fields, v_key);
    end if;
  end loop;

  update public.people set
    first_name = btrim(p_profile->>'first_name'),
    last_name = btrim(p_profile->>'last_name'),
    gender = nullif(btrim(p_profile->>'gender'), ''),
    birth_date = nullif(p_profile->>'birth_date', '')::date,
    address = nullif(btrim(p_profile->>'address'), ''),
    city = nullif(btrim(p_profile->>'city'), ''),
    postal_code = nullif(btrim(p_profile->>'postal_code'), ''),
    country = coalesce(nullif(btrim(p_profile->>'country'), ''), 'Srbija'),
    nationality = nullif(btrim(p_profile->>'nationality'), ''),
    phone = nullif(btrim(p_profile->>'phone'), ''),
    shoe_size = nullif(p_profile->>'shoe_size', '')::integer,
    jmbg = nullif(btrim(p_profile->>'jmbg'), ''),
    passport_number = nullif(btrim(p_profile->>'passport_number'), ''),
    passport_issuing_country = nullif(btrim(p_profile->>'passport_issuing_country'), ''),
    passport_expiry_date = nullif(p_profile->>'passport_expiry_date', '')::date,
    updated_at = now()
  where id = v_person.id
  returning * into v_result;

  if cardinality(v_changed_fields) > 0 then
    insert into public.person_profile_change_history (
      society_id, society_member_id, person_id, changed_fields, changed_by_user_id
    ) values (
      v_member.society_id, v_member.id, v_person.id, v_changed_fields, v_user_id
    );
  end if;

  return v_result;
end;
$$;

revoke all on function public.auth_update_my_profile(jsonb) from public, anon;
grant execute on function public.auth_update_my_profile(jsonb) to authenticated;
select pg_notify('pgrst', 'reload schema');
commit;
