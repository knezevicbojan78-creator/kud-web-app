begin;

create or replace function public.auth_manage_event(
  p_action text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_society_id uuid := nullif(p_payload ->> 'society_id', '')::uuid;
  v_event_id uuid := nullif(p_payload ->> 'event_id', '')::uuid;
  v_section_id uuid := nullif(p_payload ->> 'section_id', '')::uuid;
  v_event_section_id uuid :=
    nullif(p_payload ->> 'event_section_id', '')::uuid;
  v_actor_member_id uuid;
  v_actor_person_id uuid;
  v_is_president boolean := false;
  v_is_ur boolean := false;
  v_created_id uuid;
  v_person_id uuid := nullif(p_payload ->> 'person_id', '')::uuid;
  v_participant_id uuid :=
    nullif(p_payload ->> 'event_participant_id', '')::uuid;
  v_program_id uuid :=
    nullif(p_payload ->> 'event_appearance_repertoire_id', '')::uuid;
  v_existing_link_id uuid;
  v_section_value jsonb;
  v_old_status text;
  v_new_status text;
  v_current_event public.society_events;
  v_can_manage_fee boolean := false;
begin
  if v_user_id is null then
    raise exception 'Prijava je obavezna.';
  end if;

  if v_event_id is not null then
    select society_id into v_society_id
    from public.society_events where id = v_event_id;
  elsif v_event_section_id is not null then
    select event_row.id, event_row.society_id, section_link.section_id
    into v_event_id, v_society_id, v_section_id
    from public.event_sections section_link
    join public.society_events event_row on event_row.id = section_link.event_id
    where section_link.id = v_event_section_id;
  elsif v_program_id is not null then
    select event_row.id, event_row.society_id, section_link.section_id
    into v_event_id, v_society_id, v_section_id
    from public.event_appearance_repertoire program_row
    join public.event_appearances appearance_row
      on appearance_row.id = program_row.event_appearance_id
    join public.society_events event_row
      on event_row.id = appearance_row.event_id
    join public.event_sections section_link
      on section_link.id = program_row.event_section_id
    where program_row.id = v_program_id;
  end if;

  select member_row.id, member_row.person_id
  into v_actor_member_id, v_actor_person_id
  from public.society_members member_row
  join public.people person_row on person_row.id = member_row.person_id
  where member_row.society_id = v_society_id
    and member_row.status = 'ACTIVE'
    and coalesce(member_row.user_id, person_row.user_id) = v_user_id
  limit 1;

  if v_actor_member_id is null then
    raise exception 'Aktivno clanstvo prijavljenog korisnika nije pronadjeno.';
  end if;

  select exists (
    select 1
    from public.society_member_function_assignments assignment
    join public.society_member_functions function_row
      on function_row.id = assignment.function_id
    where assignment.society_member_id = v_actor_member_id
      and assignment.society_id = v_society_id
      and function_row.name = 'Predsednik'
      and function_row.is_active
  ) into v_is_president;

  if v_section_id is not null then
    select exists (
      select 1 from public.section_role_assignments role_row
      where role_row.section_id = v_section_id
        and role_row.society_member_id = v_actor_member_id
        and role_row.role = 'UR'
        and role_row.status = 'ACTIVE'
    ) into v_is_ur;
  elsif v_event_id is not null then
    select exists (
      select 1
      from public.event_sections section_link
      join public.section_role_assignments role_row
        on role_row.section_id = section_link.section_id
      where section_link.event_id = v_event_id
        and role_row.society_member_id = v_actor_member_id
        and role_row.role = 'UR'
        and role_row.status = 'ACTIVE'
    ) into v_is_ur;
  end if;

  if p_action = 'CREATE_EVENT' then
    if jsonb_typeof(p_payload -> 'section_ids') <> 'array'
       or jsonb_array_length(p_payload -> 'section_ids') = 0 then
      raise exception 'Izaberite najmanje jednu sekciju dogadjaja.';
    end if;
    if not exists (
      select 1
      from public.permissions_get_effective_rules(
        v_society_id, v_actor_member_id, v_actor_person_id
      ) rule
      where rule.permission_key = 'events.create_edit_draft'
    ) or exists (
      select 1
      from jsonb_array_elements_text(p_payload -> 'section_ids') selected_id
      where not public.permissions_can_access_section(
        v_society_id, v_actor_member_id, v_actor_person_id,
        selected_id::uuid, 'events.create_edit_draft'
      )
    ) then
      raise exception 'Nemate pravo kreiranja dogadjaja.';
    end if;
    v_can_manage_fee := not exists (
      select 1
      from jsonb_array_elements_text(p_payload -> 'section_ids') selected_id
      where not public.permissions_can_access_section(
        v_society_id, v_actor_member_id, v_actor_person_id,
        selected_id::uuid, 'events.manage_fee'
      )
    );
    if coalesce((p_payload ->> 'has_participation_fee')::boolean, false)
       and not v_can_manage_fee then
      raise exception 'Nemate pravo odredjivanja planirane kotizacije.';
    end if;

    insert into public.society_events (
      society_id, event_type, title, description, country, city,
      venue_name, address, departure_at, return_at, meeting_point,
      meeting_at, organizer_name, organizer_contact, transport_type,
      transport_company, accommodation, has_participation_fee,
      default_participation_fee_amount, currency, payment_due_date,
      fee_note, created_by_user_id, created_by_society_member_id,
      created_by_role, status, submitted_at, reviewed_at,
      reviewed_by_user_id, reviewed_by_society_member_id
    ) values (
      v_society_id, p_payload ->> 'event_type',
      btrim(p_payload ->> 'title'),
      nullif(btrim(p_payload ->> 'description'), ''),
      coalesce(nullif(btrim(p_payload ->> 'country'), ''), 'Srbija'),
      nullif(btrim(p_payload ->> 'city'), ''),
      nullif(btrim(p_payload ->> 'venue_name'), ''),
      nullif(btrim(p_payload ->> 'address'), ''),
      nullif(p_payload ->> 'departure_at', '')::timestamptz,
      nullif(p_payload ->> 'return_at', '')::timestamptz,
      nullif(btrim(p_payload ->> 'meeting_point'), ''),
      nullif(p_payload ->> 'meeting_at', '')::timestamptz,
      nullif(btrim(p_payload ->> 'organizer_name'), ''),
      nullif(btrim(p_payload ->> 'organizer_contact'), ''),
      nullif(btrim(p_payload ->> 'transport_type'), ''),
      nullif(btrim(p_payload ->> 'transport_company'), ''),
      nullif(btrim(p_payload ->> 'accommodation'), ''),
      coalesce((p_payload ->> 'has_participation_fee')::boolean, false),
      nullif(p_payload ->> 'default_participation_fee_amount', '')::numeric,
      coalesce(nullif(p_payload ->> 'currency', ''), 'RSD'),
      nullif(p_payload ->> 'payment_due_date', '')::date,
      nullif(btrim(p_payload ->> 'fee_note'), ''),
      v_user_id, v_actor_member_id,
      case when v_is_president then 'Predsednik' else 'UR' end,
      case when v_is_president then 'APPROVED' else 'DRAFT' end,
      case when v_is_president then now() else null end,
      case when v_is_president then now() else null end,
      case when v_is_president then v_user_id else null end,
      case when v_is_president then v_actor_member_id else null end
    ) returning id into v_event_id;

    for v_section_value in
      select value from jsonb_array_elements(p_payload -> 'section_ids')
    loop
      v_section_id := trim(both '"' from v_section_value::text)::uuid;
      if not public.permissions_can_access_section(
        v_society_id, v_actor_member_id, v_actor_person_id,
        v_section_id, 'events.create_edit_draft'
      ) then
        raise exception 'Nemate pravo izbora ove sekcije.';
      end if;
      insert into public.event_sections (
        event_id, section_id, added_by_user_id,
        added_by_society_member_id
      ) values (
        v_event_id, v_section_id, v_user_id, v_actor_member_id
      );
    end loop;

    if p_payload ->> 'event_type' = 'CONCERT' then
      insert into public.event_appearances (
        event_id, title, starts_at, ends_at, country, city,
        performance_order
      ) values (
        v_event_id, 'Glavni nastup',
        nullif(p_payload ->> 'departure_at', '')::timestamptz,
        null,
        coalesce(nullif(btrim(p_payload ->> 'country'), ''), 'Srbija'),
        nullif(btrim(p_payload ->> 'city'), ''), 1
      );
    end if;
    v_created_id := v_event_id;

  elsif p_action = 'UPDATE_EVENT' then
    if not (
      public.permissions_can_access_event(
        v_society_id, v_actor_member_id, v_actor_person_id, v_event_id,
        case when exists (
          select 1 from public.society_events e
          where e.id = v_event_id and e.status = 'APPROVED'
        ) then 'events.edit_approved' else 'events.create_edit_draft' end
      )
    ) then
      raise exception 'Nemate pravo izmene ovog dogadjaja.';
    end if;
    select * into v_current_event
    from public.society_events where id = v_event_id;
    v_can_manage_fee := public.permissions_can_access_event(
      v_society_id, v_actor_member_id, v_actor_person_id,
      v_event_id, 'events.manage_fee'
    );
    update public.society_events
    set event_type = p_payload ->> 'event_type',
        title = btrim(p_payload ->> 'title'),
        description = nullif(btrim(p_payload ->> 'description'), ''),
        country = coalesce(
          nullif(btrim(p_payload ->> 'country'), ''), 'Srbija'
        ),
        city = nullif(btrim(p_payload ->> 'city'), ''),
        departure_at = nullif(
          p_payload ->> 'departure_at', ''
        )::timestamptz,
        return_at = nullif(p_payload ->> 'return_at', '')::timestamptz,
        has_participation_fee = case when v_can_manage_fee then coalesce(
          (p_payload ->> 'has_participation_fee')::boolean, false
        ) else v_current_event.has_participation_fee end,
        default_participation_fee_amount = case when v_can_manage_fee then
          nullif(p_payload ->> 'default_participation_fee_amount', '')::numeric
          else v_current_event.default_participation_fee_amount end,
        currency = case when v_can_manage_fee then
          coalesce(nullif(p_payload ->> 'currency', ''), 'RSD')
          else v_current_event.currency end,
        payment_due_date = case when v_can_manage_fee then
          nullif(p_payload ->> 'payment_due_date', '')::date
          else v_current_event.payment_due_date end,
        fee_note = case when v_can_manage_fee then
          nullif(btrim(p_payload ->> 'fee_note'), '')
          else v_current_event.fee_note end,
        updated_at = now()
    where id = v_event_id;

  elsif p_action = 'ADD_SECTION' then
    if not public.permissions_can_access_event(
      v_society_id, v_actor_member_id, v_actor_person_id,
      v_event_id, 'events.manage_sections'
    ) or not public.permissions_can_access_section(
      v_society_id, v_actor_member_id, v_actor_person_id,
      v_section_id, 'events.manage_sections'
    ) then
      raise exception 'Nemate pravo dodavanja ove sekcije.';
    end if;
    insert into public.event_sections (
      event_id, section_id, added_by_user_id, added_by_society_member_id
    ) values (
      v_event_id, v_section_id, v_user_id, v_actor_member_id
    ) returning id into v_event_section_id;

    insert into public.event_participants (
      event_id, person_id, society_member_id, participation_status,
      added_by_user_id, added_by_society_member_id
    )
    select v_event_id, member_row.person_id, member_row.id, 'PLANNED',
      v_user_id, v_actor_member_id
    from public.member_sections membership
    join public.society_members member_row
      on member_row.id = membership.society_member_id
    where membership.section_id = v_section_id
      and membership.status = 'ACTIVE'
      and member_row.status = 'ACTIVE'
      and not exists (
        select 1 from public.event_participants participant
        where participant.event_id = v_event_id
          and participant.person_id = member_row.person_id
      );

    insert into public.event_participant_sections (
      event_participant_id, event_section_id
    )
    select participant.id, v_event_section_id
    from public.event_participants participant
    join public.society_members member_row
      on member_row.id = participant.society_member_id
    join public.member_sections membership
      on membership.society_member_id = member_row.id
    where participant.event_id = v_event_id
      and membership.section_id = v_section_id
      and membership.status = 'ACTIVE'
    on conflict do nothing;

  elsif p_action = 'ADD_PERSON' then
    if not public.permissions_can_access_event(
      v_society_id, v_actor_member_id, v_actor_person_id,
      v_event_id, 'events.manage_participants'
    ) then
      raise exception 'Nemate pravo dodavanja ucesnika.';
    end if;
    if v_person_id is null then
      select id into v_person_id from public.people
      where lower(email) = lower(btrim(p_payload ->> 'email'))
      limit 1;
    end if;
    if v_person_id is null then
      insert into public.people (
        first_name, last_name, gender, birth_date, address, city,
        postal_code, country, jmbg, passport_number,
        passport_expiry_date, parental_travel_consent,
        parental_travel_consent_valid_until, email, phone
      ) values (
        btrim(p_payload ->> 'first_name'),
        btrim(p_payload ->> 'last_name'),
        nullif(p_payload ->> 'gender', ''),
        nullif(p_payload ->> 'birth_date', '')::date,
        nullif(btrim(p_payload ->> 'address'), ''),
        nullif(btrim(p_payload ->> 'city'), ''),
        nullif(btrim(p_payload ->> 'postal_code'), ''),
        coalesce(nullif(btrim(p_payload ->> 'country'), ''), 'Srbija'),
        nullif(btrim(p_payload ->> 'jmbg'), ''),
        nullif(btrim(p_payload ->> 'passport_number'), ''),
        nullif(p_payload ->> 'passport_expiry_date', '')::date,
        coalesce(
          (p_payload ->> 'parental_travel_consent')::boolean, false
        ),
        case when coalesce(
          (p_payload ->> 'parental_travel_consent')::boolean, false
        ) then nullif(
          p_payload ->> 'parental_travel_consent_valid_until', ''
        )::date else null end,
        nullif(lower(btrim(p_payload ->> 'email')), ''),
        nullif(btrim(p_payload ->> 'phone'), '')
      ) returning id into v_person_id;
    end if;

    insert into public.event_participants (
      event_id, person_id, society_member_id, participation_status,
      added_by_user_id, added_by_society_member_id
    ) values (
      v_event_id, v_person_id,
      nullif(p_payload ->> 'society_member_id', '')::uuid,
      'PLANNED', v_user_id, v_actor_member_id
    )
    on conflict do nothing
    returning id into v_created_id;

  elsif p_action = 'ADD_APPEARANCE' then
    if not public.permissions_can_access_event(
      v_society_id, v_actor_member_id, v_actor_person_id,
      v_event_id, 'events.manage_program'
    ) then
      raise exception 'Nemate pravo izmene programa.';
    end if;
    insert into public.event_appearances (
      event_id, title, starts_at, ends_at, country, city,
      venue_name, performance_order
    ) values (
      v_event_id, btrim(p_payload ->> 'title'),
      nullif(p_payload ->> 'starts_at', '')::timestamptz,
      nullif(p_payload ->> 'ends_at', '')::timestamptz,
      coalesce(nullif(p_payload ->> 'country', ''), 'Srbija'),
      nullif(btrim(p_payload ->> 'city'), ''),
      nullif(btrim(p_payload ->> 'venue_name'), ''),
      coalesce((p_payload ->> 'performance_order')::integer, 0)
    ) returning id into v_created_id;

  elsif p_action = 'ADD_PROGRAM_ITEM' then
    v_event_section_id := (p_payload ->> 'event_section_id')::uuid;
    select section_id into v_section_id
    from public.event_sections where id = v_event_section_id;
    if not public.permissions_can_access_event(
      v_society_id, v_actor_member_id, v_actor_person_id,
      v_event_id, 'events.manage_program'
    ) or not public.permissions_can_access_section(
      v_society_id, v_actor_member_id, v_actor_person_id,
      v_section_id, 'events.manage_program'
    ) then
      raise exception 'Nemate pravo izmene programa.';
    end if;
    insert into public.event_appearance_repertoire (
      event_appearance_id, event_section_id, repertoire_item_id,
      performance_order
    ) values (
      (p_payload ->> 'event_appearance_id')::uuid,
      (p_payload ->> 'event_section_id')::uuid,
      (p_payload ->> 'repertoire_item_id')::uuid,
      coalesce((p_payload ->> 'performance_order')::integer, 0)
    ) returning id into v_created_id;

  elsif p_action in ('SUBMIT', 'APPROVE', 'REJECT', 'COMPLETE') then
    if not public.permissions_can_access_event(
      v_society_id, v_actor_member_id, v_actor_person_id, v_event_id,
      case
        when p_action = 'SUBMIT' then 'events.submit'
        when p_action in ('APPROVE', 'REJECT') then 'events.review'
        else 'events.edit_approved'
      end
    ) then
      raise exception 'Nemate pravo promene statusa ovog dogadjaja.';
    end if;

    select status into v_old_status
    from public.society_events where id = v_event_id for update;

    if p_action = 'SUBMIT' then
      update public.society_events
      set status = 'PENDING', submitted_at = now(),
          reviewed_at = null, reviewed_by_user_id = null,
          reviewed_by_society_member_id = null,
          rejection_reason = null, updated_at = now()
      where id = v_event_id and status in ('DRAFT', 'REJECTED')
      returning id into v_created_id;
      v_new_status := 'PENDING';
    elsif p_action = 'APPROVE' then
      if not exists (
        select 1 from public.event_sections where event_id = v_event_id
      ) then
        raise exception 'Dogadjaj mora imati najmanje jednu sekciju.';
      end if;
      update public.society_events
      set status = 'APPROVED', reviewed_at = now(),
          reviewed_by_user_id = v_user_id,
          reviewed_by_society_member_id = v_actor_member_id,
          rejection_reason = null, updated_at = now()
      where id = v_event_id and status in ('DRAFT', 'PENDING', 'REJECTED')
      returning id into v_created_id;
      v_new_status := 'APPROVED';
    elsif p_action = 'REJECT' then
      if nullif(btrim(p_payload ->> 'reason'), '') is null then
        raise exception 'Razlog odbijanja je obavezan.';
      end if;
      update public.society_events
      set status = 'REJECTED', reviewed_at = now(),
          reviewed_by_user_id = v_user_id,
          reviewed_by_society_member_id = v_actor_member_id,
          rejection_reason = btrim(p_payload ->> 'reason'),
          updated_at = now()
      where id = v_event_id and status = 'PENDING'
      returning id into v_created_id;
      v_new_status := 'REJECTED';
    else
      update public.society_events
      set status = 'COMPLETED', completed_at = now(), updated_at = now()
      where id = v_event_id and status = 'APPROVED'
      returning id into v_created_id;
      v_new_status := 'COMPLETED';
    end if;

    if v_created_id is null then
      raise exception 'Promena statusa nije dozvoljena iz trenutnog statusa.';
    end if;

    insert into public.event_status_history (
      event_id, old_status, new_status, changed_by_user_id,
      changed_by_society_member_id, changed_by_role, reason
    )
    values (
      v_event_id, v_old_status,
      v_new_status, v_user_id, v_actor_member_id,
      case when v_is_president then 'Predsednik' else 'UR' end,
      nullif(btrim(p_payload ->> 'reason'), '')
    );

  elsif p_action = 'TOGGLE_PERFORMER' then
    if not public.permissions_can_access_event(
      v_society_id, v_actor_member_id, v_actor_person_id,
      v_event_id, 'events.manage_program'
    ) or (
      v_section_id is not null and not public.permissions_can_access_section(
        v_society_id, v_actor_member_id, v_actor_person_id,
        v_section_id, 'events.manage_program'
      )
    ) then
      raise exception 'Nemate pravo izmene izvodjaca.';
    end if;
    if v_participant_id is null then
      insert into public.event_participants (
        event_id, person_id, society_member_id, participation_status,
        added_by_user_id, added_by_society_member_id
      ) values (
        v_event_id, v_person_id,
        nullif(p_payload ->> 'society_member_id', '')::uuid,
        'PLANNED', v_user_id, v_actor_member_id
      )
      on conflict do nothing
      returning id into v_participant_id;
      if v_participant_id is null then
        select id into v_participant_id
        from public.event_participants
        where event_id = v_event_id and person_id = v_person_id;
      end if;
    end if;

    if v_event_section_id is not null then
      insert into public.event_participant_sections (
        event_participant_id, event_section_id
      ) values (v_participant_id, v_event_section_id)
      on conflict do nothing;
    end if;

    select id into v_existing_link_id
    from public.event_repertoire_participants
    where event_appearance_repertoire_id = v_program_id
      and event_participant_id = v_participant_id;

    if v_existing_link_id is null then
      insert into public.event_repertoire_participants (
        event_appearance_repertoire_id, event_participant_id
      ) values (v_program_id, v_participant_id);
    else
      delete from public.event_repertoire_participants
      where id = v_existing_link_id;
    end if;
  else
    raise exception 'Nepoznata akcija upravljanja dogadjajem.';
  end if;

  return jsonb_build_object(
    'success', true,
    'id', coalesce(v_created_id, v_event_id)
  );
end;
$$;

revoke all on function public.auth_manage_event(text, jsonb)
  from public, anon;
grant execute on function public.auth_manage_event(text, jsonb)
  to authenticated;

revoke all on function public.submit_event(uuid, text, uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.approve_event(uuid, uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.reject_event(uuid, text, uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.complete_event(uuid, text, uuid, uuid)
  from public, anon, authenticated;

select pg_notify('pgrst', 'reload schema');
commit;

select
  to_regprocedure('public.auth_manage_event(text,jsonb)')
    as event_management_function,
  has_function_privilege(
    'authenticated', 'public.auth_manage_event(text,jsonb)', 'EXECUTE'
  ) as authenticated_execute,
  has_function_privilege(
    'anon', 'public.auth_manage_event(text,jsonb)', 'EXECUTE'
  ) as anon_execute;
