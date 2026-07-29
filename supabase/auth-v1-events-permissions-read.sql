-- FOLKLORAS — AUTH V1 / DOGADJAJI I REPERTOAR / BEZBEDAN PREGLED

begin;

create or replace function public.permissions_can_access_event(
  p_society_id uuid,
  p_actor_member_id uuid,
  p_actor_person_id uuid,
  p_event_id uuid,
  p_permission_key text
) returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.society_events event_row
    join public.permissions_get_effective_rules(
      p_society_id, p_actor_member_id, p_actor_person_id
    ) permission on permission.permission_key = p_permission_key
    where event_row.id = p_event_id
      and event_row.society_id = p_society_id
      and (
        permission.scope_key = 'SOCIETY'
        or (
          permission.scope_key = 'CREATED_EVENTS'
          and event_row.created_by_society_member_id = p_actor_member_id
        )
        or (
          permission.scope_key = 'PARTICIPATING_EVENTS'
          and exists (
            select 1
            from public.event_participants participant
            where participant.event_id = event_row.id
              and (
                participant.society_member_id = p_actor_member_id
                or participant.person_id = p_actor_person_id
              )
          )
        )
        or (
          permission.scope_key = 'CHILD_PARTICIPATING_EVENTS'
          and exists (
            select 1
            from public.person_guardians guardian
            join public.event_participants participant
              on participant.person_id = guardian.child_person_id
             and participant.event_id = event_row.id
            where guardian.guardian_person_id = p_actor_person_id
          )
        )
        or (
          permission.scope_key = 'ASSIGNED_SECTIONS'
          and exists (
            select 1
            from public.event_sections event_section
            where event_section.event_id = event_row.id
              and public.permissions_can_access_section(
                p_society_id, p_actor_member_id, p_actor_person_id,
                event_section.section_id, p_permission_key
              )
          )
        )
      )
  );
$$;

create or replace function public.auth_get_events_workspace(
  p_society_id uuid,
  p_event_id uuid default null
) returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_actor_member_id uuid;
  v_actor_person_id uuid;
  v_result jsonb;
begin
  if v_user_id is null then raise exception 'Prijava je obavezna.'; end if;

  select member.id, member.person_id
  into v_actor_member_id, v_actor_person_id
  from public.society_members member
  join public.people person on person.id = member.person_id
  where member.society_id = p_society_id
    and member.status = 'ACTIVE'
    and coalesce(member.user_id, person.user_id) = v_user_id
  order by member.id
  limit 1;

  if v_actor_member_id is null then
    raise exception 'Korisnik nema aktivno clanstvo u izabranom drustvu.';
  end if;

  if p_event_id is not null and not public.permissions_can_access_event(
    p_society_id, v_actor_member_id, v_actor_person_id,
    p_event_id, 'events.view'
  ) then
    raise exception 'Nemate dozvolu za pregled izabranog dogadjaja.';
  end if;

  select jsonb_build_object(
    'society', to_jsonb(society),
    'actor_society_member_id', v_actor_member_id,
    'access', jsonb_build_object(
      'can_create', exists (
        select 1 from public.permissions_get_effective_rules(
          p_society_id, v_actor_member_id, v_actor_person_id
        ) rule where rule.permission_key = 'events.create_edit_draft'
      ),
      'can_manage_fee', exists (
        select 1 from public.permissions_get_effective_rules(
          p_society_id, v_actor_member_id, v_actor_person_id
        ) rule where rule.permission_key = 'events.manage_fee'
      )
    ),
    'sections', coalesce((
      select jsonb_agg(to_jsonb(section) order by section.name)
      from public.sections section
      where section.society_id = p_society_id
        and section.status = 'ACTIVE'
        and (
          public.permissions_can_access_section(
            p_society_id, v_actor_member_id, v_actor_person_id,
            section.id, 'events.create_edit_draft'
          )
          or public.permissions_can_access_section(
            p_society_id, v_actor_member_id, v_actor_person_id,
            section.id, 'events.view'
          )
        )
    ), '[]'::jsonb),
    'events', coalesce((
      select jsonb_agg(
        (
          to_jsonb(event_row)
          - array[
              'default_participation_fee_amount',
              'currency',
              'payment_due_date',
              'fee_note'
            ]::text[]
          || case when public.permissions_can_access_event(
            p_society_id, v_actor_member_id, v_actor_person_id,
            event_row.id, 'events.view_fees'
          ) then jsonb_build_object(
            'default_participation_fee_amount', event_row.default_participation_fee_amount,
            'currency', event_row.currency,
            'payment_due_date', event_row.payment_due_date,
            'fee_note', event_row.fee_note
          ) else '{}'::jsonb end
        ) || jsonb_build_object(
          'access', jsonb_build_object(
            'can_view_fees', public.permissions_can_access_event(
              p_society_id, v_actor_member_id, v_actor_person_id,
              event_row.id, 'events.view_fees'
            ),
            'can_edit_draft', public.permissions_can_access_event(
              p_society_id, v_actor_member_id, v_actor_person_id,
              event_row.id, 'events.create_edit_draft'
            ),
            'can_submit', public.permissions_can_access_event(
              p_society_id, v_actor_member_id, v_actor_person_id,
              event_row.id, 'events.submit'
            ),
            'can_review', public.permissions_can_access_event(
              p_society_id, v_actor_member_id, v_actor_person_id,
              event_row.id, 'events.review'
            ),
            'can_edit_approved', public.permissions_can_access_event(
              p_society_id, v_actor_member_id, v_actor_person_id,
              event_row.id, 'events.edit_approved'
            ),
            'can_cancel_approved', public.permissions_can_access_event(
              p_society_id, v_actor_member_id, v_actor_person_id,
              event_row.id, 'events.cancel_approved'
            ),
            'can_manage_sections', public.permissions_can_access_event(
              p_society_id, v_actor_member_id, v_actor_person_id,
              event_row.id, 'events.manage_sections'
            ),
            'can_manage_participants', public.permissions_can_access_event(
              p_society_id, v_actor_member_id, v_actor_person_id,
              event_row.id, 'events.manage_participants'
            ),
            'can_change_participant_status', public.permissions_can_access_event(
              p_society_id, v_actor_member_id, v_actor_person_id,
              event_row.id, 'events.change_participant_status'
            ),
            'can_manage_fee', public.permissions_can_access_event(
              p_society_id, v_actor_member_id, v_actor_person_id,
              event_row.id, 'events.manage_fee'
            ),
            'can_manage_program', public.permissions_can_access_event(
              p_society_id, v_actor_member_id, v_actor_person_id,
              event_row.id, 'events.manage_program'
            )
          )
        )
        order by event_row.created_at desc
      )
      from public.society_events event_row
      where event_row.society_id = p_society_id
        and public.permissions_can_access_event(
          p_society_id, v_actor_member_id, v_actor_person_id,
          event_row.id, 'events.view'
        )
    ), '[]'::jsonb),
    'repertoire', coalesce((
      select jsonb_agg(to_jsonb(item) order by item.name)
      from public.repertoire_items item
      where item.society_id = p_society_id
        and item.status = 'ACTIVE'
        and exists (
          select 1
          from public.permissions_get_effective_rules(
            p_society_id, v_actor_member_id, v_actor_person_id
          ) rule
          where rule.permission_key = 'repertoire.view'
            and (
              rule.scope_key = 'SOCIETY'
              or exists (
                select 1
                from public.repertoire_item_sections item_section
                where item_section.repertoire_item_id = item.id
                  and public.permissions_can_access_section(
                    p_society_id, v_actor_member_id, v_actor_person_id,
                    item_section.section_id, 'repertoire.view'
                  )
              )
            )
        )
    ), '[]'::jsonb),
    'repertoire_section_links', coalesce((
      select jsonb_agg(to_jsonb(link))
      from public.repertoire_item_sections link
      join public.repertoire_items item on item.id = link.repertoire_item_id
      where item.society_id = p_society_id
        and public.permissions_can_access_section(
          p_society_id, v_actor_member_id, v_actor_person_id,
          link.section_id, 'repertoire.view'
        )
    ), '[]'::jsonb),
    'detail', case when p_event_id is null then null else jsonb_build_object(
      'event_sections', coalesce((
        select jsonb_agg(to_jsonb(link))
        from public.event_sections link
        where link.event_id = p_event_id
      ), '[]'::jsonb),
      'participants', case when public.permissions_can_access_event(
        p_society_id, v_actor_member_id, v_actor_person_id,
        p_event_id, 'events.view_participants'
      ) then coalesce((
        select jsonb_agg(
          (to_jsonb(participant) - 'participation_fee_amount')
          || case when public.permissions_can_access_event(
            p_society_id, v_actor_member_id, v_actor_person_id,
            p_event_id, 'events.view_fees'
          ) then jsonb_build_object(
            'participation_fee_amount', participant.participation_fee_amount
          ) else '{}'::jsonb end
          || jsonb_build_object(
            'name', concat_ws(' ', person.first_name, person.last_name),
            'person', jsonb_build_object(
              'id', person.id,
              'first_name', person.first_name,
              'last_name', person.last_name,
              'gender', person.gender,
              'email', person.email,
              'phone', person.phone
            )
          )
          order by participant.created_at
        )
        from public.event_participants participant
        join public.people person on person.id = participant.person_id
        where participant.event_id = p_event_id
      ), '[]'::jsonb) else '[]'::jsonb end,
      'participant_section_links', case when public.permissions_can_access_event(
        p_society_id, v_actor_member_id, v_actor_person_id,
        p_event_id, 'events.view_participants'
      ) then coalesce((
        select jsonb_agg(to_jsonb(link))
        from public.event_participant_sections link
        join public.event_participants participant
          on participant.id = link.event_participant_id
        where participant.event_id = p_event_id
      ), '[]'::jsonb) else '[]'::jsonb end,
      'appearances', case when public.permissions_can_access_event(
        p_society_id, v_actor_member_id, v_actor_person_id,
        p_event_id, 'events.view_program'
      ) then coalesce((
        select jsonb_agg(to_jsonb(appearance) order by appearance.performance_order)
        from public.event_appearances appearance
        where appearance.event_id = p_event_id
      ), '[]'::jsonb) else '[]'::jsonb end,
      'program', case when public.permissions_can_access_event(
        p_society_id, v_actor_member_id, v_actor_person_id,
        p_event_id, 'events.view_program'
      ) then coalesce((
        select jsonb_agg(to_jsonb(program_row) order by program_row.performance_order)
        from public.event_appearance_repertoire program_row
        join public.event_appearances appearance
          on appearance.id = program_row.event_appearance_id
        where appearance.event_id = p_event_id
      ), '[]'::jsonb) else '[]'::jsonb end,
      'performer_links', case when public.permissions_can_access_event(
        p_society_id, v_actor_member_id, v_actor_person_id,
        p_event_id, 'events.view_program'
      ) then coalesce((
        select jsonb_agg(to_jsonb(link))
        from public.event_repertoire_participants link
        join public.event_appearance_repertoire program_row
          on program_row.id = link.event_appearance_repertoire_id
        join public.event_appearances appearance
          on appearance.id = program_row.event_appearance_id
        where appearance.event_id = p_event_id
      ), '[]'::jsonb) else '[]'::jsonb end
    ) end
  )
  into v_result
  from public.societies society
  where society.id = p_society_id
    and society.status in ('ACTIVE', 'SUSPENDED');

  if v_result is null then raise exception 'Izabrano drustvo nije dostupno.'; end if;
  return v_result;
end;
$$;

create or replace function public.auth_search_event_people(
  p_event_id uuid,
  p_query text
) returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_society_id uuid;
  v_actor_member_id uuid;
  v_actor_person_id uuid;
begin
  if auth.uid() is null then raise exception 'Prijava je obavezna.'; end if;
  if length(btrim(coalesce(p_query, ''))) < 2 then return '[]'::jsonb; end if;

  select society_id into v_society_id
  from public.society_events where id = p_event_id;

  select member.id, member.person_id
  into v_actor_member_id, v_actor_person_id
  from public.society_members member
  join public.people person on person.id = member.person_id
  where member.society_id = v_society_id
    and member.status = 'ACTIVE'
    and coalesce(member.user_id, person.user_id) = auth.uid()
  limit 1;

  if v_actor_member_id is null or not public.permissions_can_access_event(
    v_society_id, v_actor_member_id, v_actor_person_id,
    p_event_id, 'events.manage_participants'
  ) then raise exception 'Nemate pravo pretrage ucesnika.'; end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', person.id,
      'first_name', person.first_name,
      'last_name', person.last_name,
      'gender', person.gender,
      'email', person.email,
      'phone', person.phone
    ))
    from (
      select candidate.*
      from public.people candidate
      where candidate.email ilike '%' || btrim(p_query) || '%'
      order by candidate.email nulls last
      limit 6
    ) person
  ), '[]'::jsonb);
end;
$$;

create or replace function public.auth_list_event_section_candidates(
  p_event_section_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_event_id uuid;
  v_society_id uuid;
  v_section_id uuid;
  v_actor_member_id uuid;
  v_actor_person_id uuid;
begin
  if auth.uid() is null then raise exception 'Prijava je obavezna.'; end if;

  select event_row.id, event_row.society_id, event_section.section_id
  into v_event_id, v_society_id, v_section_id
  from public.event_sections event_section
  join public.society_events event_row on event_row.id = event_section.event_id
  where event_section.id = p_event_section_id;

  select member.id, member.person_id
  into v_actor_member_id, v_actor_person_id
  from public.society_members member
  join public.people person on person.id = member.person_id
  where member.society_id = v_society_id
    and member.status = 'ACTIVE'
    and coalesce(member.user_id, person.user_id) = auth.uid()
  limit 1;

  if v_actor_member_id is null
     or not public.permissions_can_access_event(
       v_society_id, v_actor_member_id, v_actor_person_id,
       v_event_id, 'events.manage_program'
     )
     or not public.permissions_can_access_section(
       v_society_id, v_actor_member_id, v_actor_person_id,
       v_section_id, 'events.manage_program'
     )
  then raise exception 'Nemate pravo izbora izvodjaca ove sekcije.'; end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'member', to_jsonb(member),
      'person', jsonb_build_object(
        'id', person.id,
        'first_name', person.first_name,
        'last_name', person.last_name,
        'gender', person.gender,
        'email', person.email,
        'phone', person.phone
      )
    ) order by person.last_name, person.first_name)
    from public.member_sections membership
    join public.society_members member
      on member.id = membership.society_member_id
     and member.status = 'ACTIVE'
    join public.people person on person.id = member.person_id
    where membership.section_id = v_section_id
      and membership.status = 'ACTIVE'
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.permissions_can_access_event(uuid,uuid,uuid,uuid,text)
  from public, anon, authenticated;
revoke all on function public.auth_get_events_workspace(uuid,uuid)
  from public, anon;
grant execute on function public.auth_get_events_workspace(uuid,uuid)
  to authenticated;
revoke all on function public.auth_search_event_people(uuid,text)
  from public, anon;
grant execute on function public.auth_search_event_people(uuid,text)
  to authenticated;
revoke all on function public.auth_list_event_section_candidates(uuid)
  from public, anon;
grant execute on function public.auth_list_event_section_candidates(uuid)
  to authenticated;

commit;
