-- FOLKLORAS V1
-- Razresava stvarnu poslovnu ulogu kada bezbedni finansijski omotac pozove
-- stariji tok otkazivanja sa oznakom "Ovlasceni korisnik".

begin;

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
  v_event public.society_events;
  v_old_status text;
  v_effective_role text := p_actor_role;
begin
  select *
  into v_event
  from public.society_events
  where id = p_event_id
  for update;

  if not found then
    raise exception 'Dogadjaj nije pronadjen.';
  end if;

  if v_effective_role = 'Ovlašćeni korisnik' then
    select 'Predsednik'
    into v_effective_role
    from public.society_member_function_assignments assignment
    join public.society_member_functions function_row
      on function_row.id = assignment.function_id
    where assignment.society_member_id = p_actor_member_id
      and assignment.society_id = v_event.society_id
      and function_row.name = 'Predsednik'
      and function_row.is_active
    limit 1;

    if v_effective_role is null then
      select 'UR'
      into v_effective_role
      from public.event_sections event_section
      join public.section_role_assignments role_row
        on role_row.section_id = event_section.section_id
      where event_section.event_id = v_event.id
        and role_row.society_member_id = p_actor_member_id
        and role_row.role = 'UR'
        and role_row.status = 'ACTIVE'
      limit 1;
    end if;
  end if;

  if v_effective_role not in ('Predsednik', 'UR') then
    raise exception 'Nemate pravo otkazivanja dogadjaja.';
  end if;
  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'Razlog otkazivanja je obavezan.';
  end if;
  if v_event.status in ('CANCELLED', 'COMPLETED') then
    raise exception 'Dogadjaj je vec zavrsen ili otkazan.';
  end if;
  if v_effective_role = 'UR' and v_event.status not in ('DRAFT', 'PENDING') then
    raise exception 'UR ne moze otkazati odobren dogadjaj.';
  end if;

  v_old_status := v_event.status;
  update public.society_events
  set status = 'CANCELLED',
      cancelled_at = now(),
      cancellation_reason = trim(p_reason),
      updated_at = now()
  where id = p_event_id
  returning * into v_event;

  insert into public.event_status_history (
    event_id, old_status, new_status, changed_by_user_id,
    changed_by_society_member_id, changed_by_role, reason
  ) values (
    p_event_id, v_old_status, 'CANCELLED', p_actor_user_id,
    p_actor_member_id, v_effective_role, trim(p_reason)
  );

  return v_event;
end;
$$;

revoke all on function public.cancel_event(uuid, text, text, uuid, uuid)
  from public, anon, authenticated;

commit;
