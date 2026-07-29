begin;

create or replace function public.auth_create_society_member(
  p_society_id uuid,
  p_profile jsonb,
  p_guardians jsonb default '[]'::jsonb,
  p_function_ids uuid[] default array[]::uuid[],
  p_section_ids uuid[] default array[]::uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_person_id uuid;
  v_email_person_id uuid;
  v_jmbg_person_id uuid;
  v_passport_person_id uuid;
  v_member_id uuid;
  v_guardian jsonb;
  v_guardian_person_id uuid;
  v_member_section_id uuid;
  v_function_id uuid;
  v_section_id uuid;
  v_reused_person boolean := false;
  v_actor_member_id uuid;
  v_actor_person_id uuid;
begin
  if v_user_id is null then
    raise exception 'Prijava je obavezna.';
  end if;

  select actor.id, actor.person_id
  into v_actor_member_id, v_actor_person_id
  from public.society_members actor
  join public.people actor_person on actor_person.id = actor.person_id
  where actor.society_id = p_society_id
    and actor.status = 'ACTIVE'
    and coalesce(actor.user_id, actor_person.user_id) = v_user_id
  order by actor.id
  limit 1;

  if v_actor_member_id is null or not public.permissions_has_scope(
    p_society_id, v_actor_member_id, v_actor_person_id,
    'members.create', array['SOCIETY']::text[]
  ) then
    raise exception 'Nemate dozvolu za unos clana.';
  end if;

  if jsonb_array_length(coalesce(p_guardians, '[]'::jsonb)) > 0
     and not public.permissions_has_scope(
       p_society_id, v_actor_member_id, v_actor_person_id,
       'members.manage_guardians', array['SOCIETY']::text[]
     ) then
    raise exception 'Nemate dozvolu za upravljanje roditeljima i starateljima.';
  end if;

  if cardinality(coalesce(p_function_ids, array[]::uuid[])) > 0
     and not public.permissions_has_scope(
       p_society_id, v_actor_member_id, v_actor_person_id,
       'permissions.manage', array['SOCIETY']::text[]
     ) then
    raise exception 'Nemate dozvolu za dodelu funkcija.';
  end if;

  if cardinality(coalesce(p_section_ids, array[]::uuid[])) > 0
     and not public.permissions_has_scope(
       p_society_id, v_actor_member_id, v_actor_person_id,
       'members.manage_sections', array['SOCIETY','ASSIGNED_SECTIONS']::text[]
     ) then
    raise exception 'Nemate dozvolu za rasporedjivanje clana po sekcijama.';
  end if;

  if nullif(btrim(p_profile ->> 'first_name'), '') is null
     or nullif(btrim(p_profile ->> 'last_name'), '') is null then
    raise exception 'Ime i prezime su obavezni.';
  end if;
  if nullif(p_profile ->> 'start_date', '') is null then
    raise exception 'Datum pocetka clanstva je obavezan.';
  end if;

  if nullif(lower(btrim(p_profile ->> 'email')), '') is not null then
    select id into v_email_person_id
    from public.people
    where lower(email) = lower(btrim(p_profile ->> 'email'))
    limit 1;
  end if;
  if nullif(btrim(p_profile ->> 'jmbg'), '') is not null then
    select id into v_jmbg_person_id
    from public.people
    where jmbg = btrim(p_profile ->> 'jmbg')
    limit 1;
  end if;
  if nullif(btrim(p_profile ->> 'passport_number'), '') is not null then
    select id into v_passport_person_id
    from public.people
    where passport_number = btrim(p_profile ->> 'passport_number')
    limit 1;
  end if;

  if (
    select count(distinct matched_id)
    from unnest(array[
      v_email_person_id, v_jmbg_person_id, v_passport_person_id
    ]) matched_id
    where matched_id is not null
  ) > 1 then
    raise exception 'Email, JMBG ili pasos pripadaju razlicitim osobama.';
  end if;

  v_person_id := coalesce(
    v_email_person_id, v_jmbg_person_id, v_passport_person_id
  );
  v_reused_person := v_person_id is not null;

  if v_person_id is null then
    insert into public.people (
      first_name, last_name, gender, birth_date, address, city,
      postal_code, country, jmbg, passport_number,
      passport_expiry_date, parental_travel_consent,
      parental_travel_consent_valid_until, email, phone, shoe_size
    ) values (
      btrim(p_profile ->> 'first_name'),
      btrim(p_profile ->> 'last_name'),
      nullif(btrim(p_profile ->> 'gender'), ''),
      nullif(p_profile ->> 'birth_date', '')::date,
      nullif(btrim(p_profile ->> 'address'), ''),
      nullif(btrim(p_profile ->> 'city'), ''),
      nullif(btrim(p_profile ->> 'postal_code'), ''),
      coalesce(nullif(btrim(p_profile ->> 'country'), ''), 'Srbija'),
      nullif(btrim(p_profile ->> 'jmbg'), ''),
      nullif(btrim(p_profile ->> 'passport_number'), ''),
      nullif(p_profile ->> 'passport_expiry_date', '')::date,
      coalesce(
        (p_profile ->> 'parental_travel_consent')::boolean, false
      ),
      case when coalesce(
        (p_profile ->> 'parental_travel_consent')::boolean, false
      ) then nullif(
        p_profile ->> 'parental_travel_consent_valid_until', ''
      )::date else null end,
      nullif(lower(btrim(p_profile ->> 'email')), ''),
      nullif(btrim(p_profile ->> 'phone'), ''),
      nullif(p_profile ->> 'shoe_size', '')::integer
    )
    returning id into v_person_id;
  end if;

  if exists (
    select 1 from public.society_members
    where society_id = p_society_id and person_id = v_person_id
  ) then
    raise exception 'Ova osoba je vec clan ovog drustva.';
  end if;

  if exists (
    select 1
    from unnest(coalesce(p_function_ids, array[]::uuid[])) selected_id
    left join public.society_member_functions function_row
      on function_row.id = selected_id
     and function_row.society_id = p_society_id
     and function_row.is_active
    where function_row.id is null
       or function_row.name = 'Predsednik'
  ) then
    raise exception 'Izabrana funkcija nije dozvoljena.';
  end if;

  if exists (
    select 1
    from unnest(coalesce(p_section_ids, array[]::uuid[])) selected_id
    left join public.sections section_row
      on section_row.id = selected_id
     and section_row.society_id = p_society_id
     and section_row.status = 'ACTIVE'
    where section_row.id is null
  ) then
    raise exception 'Izabrana sekcija ne pripada ovom drustvu.';
  end if;

  insert into public.society_members (
    society_id, person_id, user_id, status, start_date,
    membership_fee_required, membership_fee_amount
  ) values (
    p_society_id, v_person_id, null,
    coalesce(nullif(p_profile ->> 'status', ''), 'ACTIVE'),
    (p_profile ->> 'start_date')::date,
    coalesce(
      (p_profile ->> 'membership_fee_required')::boolean, false
    ),
    case when coalesce(
      (p_profile ->> 'membership_fee_required')::boolean, false
    ) then nullif(
      p_profile ->> 'membership_fee_amount', ''
    )::numeric else null end
  )
  returning id into v_member_id;

  insert into public.member_status_history (
    society_member_id, status, effective_date
  ) values (
    v_member_id,
    coalesce(nullif(p_profile ->> 'status', ''), 'ACTIVE'),
    (p_profile ->> 'start_date')::date
  );

  for v_guardian in
    select value from jsonb_array_elements(coalesce(p_guardians, '[]'::jsonb))
  loop
    if nullif(lower(btrim(v_guardian ->> 'email')), '') is null then
      raise exception 'Email roditelja ili staratelja je obavezan.';
    end if;
    select id into v_guardian_person_id
    from public.people
    where lower(email) = lower(btrim(v_guardian ->> 'email'))
    limit 1;

    if v_guardian_person_id is null then
      insert into public.people (
        first_name, last_name, country, email, phone
      ) values (
        btrim(v_guardian ->> 'first_name'),
        btrim(v_guardian ->> 'last_name'),
        'Srbija',
        lower(btrim(v_guardian ->> 'email')),
        nullif(btrim(v_guardian ->> 'phone'), '')
      )
      returning id into v_guardian_person_id;
    end if;

    insert into public.person_guardians (
      child_person_id, guardian_person_id, relationship, is_primary
    ) values (
      v_person_id, v_guardian_person_id, 'Roditelj/staratelj',
      coalesce((v_guardian ->> 'is_primary')::boolean, false)
    )
    on conflict do nothing;
  end loop;

  for v_function_id in
    select distinct selected_id
    from unnest(coalesce(p_function_ids, array[]::uuid[])) selected_id
  loop
    insert into public.society_member_function_assignments (
      society_id, society_member_id, function_id
    ) values (
      p_society_id, v_member_id, v_function_id
    );
  end loop;

  for v_section_id in
    select distinct selected_id
    from unnest(coalesce(p_section_ids, array[]::uuid[])) selected_id
  loop
    insert into public.member_sections (
      society_id, section_id, society_member_id, status
    ) values (
      p_society_id, v_section_id, v_member_id, 'ACTIVE'
    )
    returning id into v_member_section_id;

    insert into public.member_section_history (
      member_section_id, society_id, section_id, society_member_id,
      old_status, new_status, effective_date, changed_by_user_id, note
    ) values (
      v_member_section_id, p_society_id, v_section_id, v_member_id,
      null, 'ACTIVE', current_date, v_user_id,
      'Prvo dodavanje kroz Auth V1 kreiranje clana'
    );
  end loop;

  return jsonb_build_object(
    'society_member_id', v_member_id,
    'person_id', v_person_id,
    'reused_person', v_reused_person
  );
end;
$$;

revoke all on function public.auth_create_society_member(
  uuid, jsonb, jsonb, uuid[], uuid[]
) from public, anon;
grant execute on function public.auth_create_society_member(
  uuid, jsonb, jsonb, uuid[], uuid[]
) to authenticated;

select pg_notify('pgrst', 'reload schema');
commit;

select
  to_regprocedure(
    'public.auth_create_society_member(uuid,jsonb,jsonb,uuid[],uuid[])'
  ) as member_create_function,
  has_function_privilege(
    'authenticated',
    'public.auth_create_society_member(uuid,jsonb,jsonb,uuid[],uuid[])',
    'EXECUTE'
  ) as authenticated_execute,
  has_function_privilege(
    'anon',
    'public.auth_create_society_member(uuid,jsonb,jsonb,uuid[],uuid[])',
    'EXECUTE'
  ) as anon_execute;
