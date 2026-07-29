-- FOLKLORAS V1
-- Uskladjuje novi sistem dozvola sa starijom validacijom statusa ucesnika.

begin;

create or replace function public.finance_actor_event_role(
  p_event_participant_id uuid,
  p_actor_member_id uuid
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_participant public.event_participants;
  v_event public.society_events;
  v_actor_person_id uuid;
  v_role text;
begin
  if auth.uid() is null or p_actor_member_id is null then
    raise exception 'Korisnik nije prijavljen.';
  end if;

  select * into v_participant
  from public.event_participants
  where id = p_event_participant_id;
  if not found then raise exception 'Ucesnik nije pronadjen.'; end if;

  select * into v_event
  from public.society_events
  where id = v_participant.event_id;

  select member.person_id into v_actor_person_id
  from public.society_members member
  join public.people person on person.id = member.person_id
  where member.id = p_actor_member_id
    and member.society_id = v_event.society_id
    and member.status = 'ACTIVE'
    and coalesce(member.user_id, person.user_id) = auth.uid();

  if v_actor_person_id is null or not public.permissions_can_access_event(
    v_event.society_id, p_actor_member_id, v_actor_person_id,
    v_event.id, 'events.change_participant_status'
  ) then
    raise exception 'Nemate pravo promene statusa ovog ucesnika.';
  end if;

  select 'Predsednik' into v_role
  from public.society_member_function_assignments assignment
  join public.society_member_functions function_row
    on function_row.id = assignment.function_id
  where assignment.society_member_id = p_actor_member_id
    and assignment.society_id = v_event.society_id
    and function_row.name = 'Predsednik'
    and function_row.is_active
  limit 1;

  if v_role is null then
    select 'UR' into v_role
    from public.event_sections event_section
    join public.section_role_assignments role_row
      on role_row.section_id = event_section.section_id
    where event_section.event_id = v_event.id
      and role_row.society_member_id = p_actor_member_id
      and role_row.role = 'UR'
      and role_row.status = 'ACTIVE'
    limit 1;
  end if;

  if v_role is null then
    raise exception 'Status ucesnika menja samo predsednik ili UR.';
  end if;

  return v_role;
end;
$$;

revoke all on function public.finance_actor_event_role(uuid, uuid) from public;
revoke all on function public.finance_actor_event_role(uuid, uuid) from anon;
revoke all on function public.finance_actor_event_role(uuid, uuid) from authenticated;

commit;
