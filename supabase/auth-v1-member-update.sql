begin;

drop function if exists public.auth_update_society_member(
  uuid, jsonb, uuid[], uuid[]
);

create or replace function public.auth_update_society_member(
  p_society_member_id uuid,
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
  v_society_id uuid;
  v_person_id uuid;
  v_linked_user_id uuid;
  v_old_status text;
  v_row record;
  v_member_section_id uuid;
  v_guardian jsonb;
  v_guardian_person_id uuid;
  v_guardian_person_ids uuid[] := array[]::uuid[];
  v_actor_member_id uuid;
  v_actor_person_id uuid;
begin
  if v_user_id is null then
    raise exception 'Prijava je obavezna.';
  end if;

  select sm.society_id, sm.person_id, coalesce(sm.user_id, p.user_id), sm.status
  into v_society_id, v_person_id, v_linked_user_id, v_old_status
  from public.society_members sm
  join public.people p on p.id = sm.person_id
  where sm.id = p_society_member_id
  for update of sm, p;

  if v_society_id is null then
    raise exception 'Clan nije pronadjen.';
  end if;

  select actor.id, actor.person_id
  into v_actor_member_id, v_actor_person_id
  from public.society_members actor
  join public.people actor_person on actor_person.id = actor.person_id
  where actor.society_id = v_society_id
    and actor.status = 'ACTIVE'
    and coalesce(actor.user_id, actor_person.user_id) = v_user_id
  order by actor.id
  limit 1;

  if v_actor_member_id is null or not public.permissions_can_access_member(
    v_society_id, v_actor_member_id, v_actor_person_id,
    p_society_member_id, 'members.edit_basic'
  ) then
    raise exception 'Nemate dozvolu za izmenu osnovnih podataka ovog clana.';
  end if;

  if exists (
    select 1
    from public.people current_person
    where current_person.id = v_person_id
      and (
        current_person.gender is distinct from nullif(p_profile ->> 'gender', '')
        or current_person.birth_date::text is distinct from nullif(p_profile ->> 'birth_date', '')
        or current_person.address is distinct from nullif(p_profile ->> 'address', '')
        or current_person.city is distinct from nullif(p_profile ->> 'city', '')
        or current_person.postal_code is distinct from nullif(p_profile ->> 'postal_code', '')
        or current_person.country is distinct from nullif(p_profile ->> 'country', '')
        or current_person.jmbg is distinct from nullif(p_profile ->> 'jmbg', '')
        or current_person.passport_number is distinct from nullif(p_profile ->> 'passport_number', '')
        or current_person.passport_expiry_date::text is distinct from nullif(p_profile ->> 'passport_expiry_date', '')
      )
  ) and not public.permissions_can_access_member(
    v_society_id, v_actor_member_id, v_actor_person_id,
    p_society_member_id, 'members.edit_sensitive'
  ) then
    raise exception 'Nemate dozvolu za izmenu osetljivih podataka ovog clana.';
  end if;

  if v_old_status is distinct from coalesce(nullif(p_profile ->> 'status', ''), v_old_status)
     and not public.permissions_can_access_member(
       v_society_id, v_actor_member_id, v_actor_person_id,
       p_society_member_id, 'members.change_status'
     ) then
    raise exception 'Nemate dozvolu za promenu statusa clanstva.';
  end if;

  if jsonb_array_length(coalesce(p_guardians, '[]'::jsonb)) > 0
     and not public.permissions_can_access_member(
       v_society_id, v_actor_member_id, v_actor_person_id,
       p_society_member_id, 'members.manage_guardians'
     ) then
    raise exception 'Nemate dozvolu za upravljanje roditeljima i starateljima.';
  end if;

  if cardinality(coalesce(p_function_ids, array[]::uuid[])) > 0
     and not public.permissions_can_access_member(
       v_society_id, v_actor_member_id, v_actor_person_id,
       p_society_member_id, 'permissions.manage'
     ) then
    raise exception 'Nemate dozvolu za promenu funkcija clana.';
  end if;

  if cardinality(coalesce(p_section_ids, array[]::uuid[])) > 0
     and not public.permissions_can_access_member(
       v_society_id, v_actor_member_id, v_actor_person_id,
       p_society_member_id, 'members.manage_sections'
     ) then
    raise exception 'Nemate dozvolu za promenu sekcija clana.';
  end if;

  if nullif(btrim(p_profile ->> 'first_name'), '') is null
     or nullif(btrim(p_profile ->> 'last_name'), '') is null then
    raise exception 'Ime i prezime su obavezni.';
  end if;

  if exists (
    select 1
    from unnest(coalesce(p_function_ids, array[]::uuid[])) selected_id
    left join public.society_member_functions f
      on f.id = selected_id
     and f.society_id = v_society_id
     and f.is_active
    where f.id is null
  ) then
    raise exception 'Izabrana funkcija ne pripada ovom drustvu.';
  end if;

  if exists (
    select 1
    from unnest(coalesce(p_section_ids, array[]::uuid[])) selected_id
    left join public.sections s
      on s.id = selected_id
     and s.society_id = v_society_id
     and s.status = 'ACTIVE'
    where s.id is null
  ) then
    raise exception 'Izabrana sekcija ne pripada ovom drustvu.';
  end if;

  update public.people
  set first_name = btrim(p_profile ->> 'first_name'),
      last_name = btrim(p_profile ->> 'last_name'),
      gender = nullif(btrim(p_profile ->> 'gender'), ''),
      birth_date = nullif(p_profile ->> 'birth_date', '')::date,
      address = nullif(btrim(p_profile ->> 'address'), ''),
      city = nullif(btrim(p_profile ->> 'city'), ''),
      postal_code = nullif(btrim(p_profile ->> 'postal_code'), ''),
      country = coalesce(nullif(btrim(p_profile ->> 'country'), ''), 'Srbija'),
      jmbg = nullif(btrim(p_profile ->> 'jmbg'), ''),
      passport_number = nullif(btrim(p_profile ->> 'passport_number'), ''),
      passport_expiry_date =
        nullif(p_profile ->> 'passport_expiry_date', '')::date,
      parental_travel_consent =
        coalesce((p_profile ->> 'parental_travel_consent')::boolean, false),
      parental_travel_consent_valid_until = case
        when coalesce(
          (p_profile ->> 'parental_travel_consent')::boolean, false
        )
          then nullif(
            p_profile ->> 'parental_travel_consent_valid_until', ''
          )::date
        else null
      end,
      email = case
        when v_linked_user_id is not null then email
        else nullif(lower(btrim(p_profile ->> 'email')), '')
      end,
      phone = nullif(btrim(p_profile ->> 'phone'), '')
  where id = v_person_id;

  update public.society_members
  set status = p_profile ->> 'status',
      start_date = (p_profile ->> 'start_date')::date,
      membership_fee_required =
        coalesce((p_profile ->> 'membership_fee_required')::boolean, false),
      membership_fee_amount = case
        when coalesce(
          (p_profile ->> 'membership_fee_required')::boolean, false
        )
          then nullif(p_profile ->> 'membership_fee_amount', '')::numeric
        else null
      end
  where id = p_society_member_id;

  if jsonb_array_length(coalesce(p_guardians, '[]'::jsonb)) > 0 then
    for v_guardian in
      select value
      from jsonb_array_elements(coalesce(p_guardians, '[]'::jsonb))
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

      v_guardian_person_ids :=
        array_append(v_guardian_person_ids, v_guardian_person_id);

      insert into public.person_guardians (
        child_person_id, guardian_person_id, relationship, is_primary
      ) values (
        v_person_id, v_guardian_person_id, 'Roditelj/staratelj',
        coalesce((v_guardian ->> 'is_primary')::boolean, false)
      )
      on conflict do nothing;

      update public.person_guardians
      set is_primary =
        coalesce((v_guardian ->> 'is_primary')::boolean, false),
        updated_at = now()
      where child_person_id = v_person_id
        and guardian_person_id = v_guardian_person_id;
    end loop;

    delete from public.person_guardians
    where child_person_id = v_person_id
      and not (guardian_person_id = any(v_guardian_person_ids));
  end if;

  if v_old_status is distinct from (p_profile ->> 'status') then
    insert into public.member_status_history (
      society_member_id, status, effective_date
    )
    values (
      p_society_member_id, p_profile ->> 'status', current_date
    );
  end if;

  delete from public.society_member_function_assignments a
  using public.society_member_functions f
  where a.function_id = f.id
    and a.society_member_id = p_society_member_id
    and f.society_id = v_society_id
    and f.name <> 'Predsednik';

  insert into public.society_member_function_assignments (
    society_id, society_member_id, function_id
  )
  select distinct v_society_id, p_society_member_id, selected_id
  from unnest(coalesce(p_function_ids, array[]::uuid[])) selected_id
  join public.society_member_functions f on f.id = selected_id
  where f.name <> 'Predsednik'
  on conflict do nothing;

  for v_row in
    select id, section_id, status
    from public.member_sections
    where society_member_id = p_society_member_id
      and society_id = v_society_id
    for update
  loop
    if v_row.section_id = any(coalesce(p_section_ids, array[]::uuid[])) then
      if v_row.status <> 'ACTIVE' then
        update public.member_sections set status = 'ACTIVE'
        where id = v_row.id;
        insert into public.member_section_history (
          member_section_id, society_id, section_id, society_member_id,
          old_status, new_status, effective_date, changed_by_user_id, note
        ) values (
          v_row.id, v_society_id, v_row.section_id, p_society_member_id,
          v_row.status, 'ACTIVE', current_date, v_user_id,
          'Aktiviranje kroz Auth V1 izmenu clana'
        );
      end if;
    elsif v_row.status <> 'INACTIVE' then
      update public.member_sections set status = 'INACTIVE'
      where id = v_row.id;
      insert into public.member_section_history (
        member_section_id, society_id, section_id, society_member_id,
        old_status, new_status, effective_date, changed_by_user_id, note
      ) values (
        v_row.id, v_society_id, v_row.section_id, p_society_member_id,
        v_row.status, 'INACTIVE', current_date, v_user_id,
        'Deaktiviranje kroz Auth V1 izmenu clana'
      );
    end if;
  end loop;

  for v_row in
    select distinct selected_id as section_id
    from unnest(coalesce(p_section_ids, array[]::uuid[])) selected_id
    where not exists (
      select 1 from public.member_sections existing
      where existing.society_member_id = p_society_member_id
        and existing.section_id = selected_id
    )
  loop
    insert into public.member_sections (
      society_id, society_member_id, section_id, status
    ) values (
      v_society_id, p_society_member_id, v_row.section_id, 'ACTIVE'
    )
    returning id into v_member_section_id;

    insert into public.member_section_history (
      member_section_id, society_id, section_id, society_member_id,
      old_status, new_status, effective_date, changed_by_user_id, note
    ) values (
      v_member_section_id, v_society_id, v_row.section_id,
      p_society_member_id, null, 'ACTIVE', current_date, v_user_id,
      'Prvo dodavanje kroz Auth V1 izmenu clana'
    );
  end loop;

  return jsonb_build_object(
    'society_member_id', p_society_member_id,
    'updated', true
  );
end;
$$;

revoke all on function public.auth_update_society_member(
  uuid, jsonb, jsonb, uuid[], uuid[]
) from public, anon;
grant execute on function public.auth_update_society_member(
  uuid, jsonb, jsonb, uuid[], uuid[]
) to authenticated;

select pg_notify('pgrst', 'reload schema');
commit;

select
  to_regprocedure(
    'public.auth_update_society_member(uuid,jsonb,jsonb,uuid[],uuid[])'
  ) as member_update_function,
  has_function_privilege(
    'authenticated',
    'public.auth_update_society_member(uuid,jsonb,jsonb,uuid[],uuid[])',
    'EXECUTE'
  ) as authenticated_execute,
  has_function_privilege(
    'anon',
    'public.auth_update_society_member(uuid,jsonb,jsonb,uuid[],uuid[])',
    'EXECUTE'
  ) as anon_execute;
