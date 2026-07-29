-- FOLKLORAS DEV/V1 ONLY
-- Test pristup finansijama dok testne uloge jos nisu povezane sa Supabase Auth nalozima.
-- NE KORISTITI u produkciji. Zameniti finalnim Auth/RLS pravilima pre produkcije.

begin;

create or replace function public.finance_get_test_actor_context(p_role text)
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_context record;
begin
  if p_role not in ('Predsednik', 'Blagajnik') then
    return null;
  end if;

  select sm.society_id, sm.id as society_member_id
  into v_context
  from society_members sm
  join societies s on s.id = sm.society_id and s.status = 'ACTIVE'
  where sm.status = 'ACTIVE'
  order by s.name, sm.created_at
  limit 1;

  if v_context.society_member_id is null then return null; end if;
  return jsonb_build_object(
    'society_id', v_context.society_id,
    'society_member_id', v_context.society_member_id,
    'role', p_role
  );
end;
$$;

create or replace function public.finance_can_manage_society(
  p_society_id uuid,
  p_actor_member_id uuid
) returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from society_members sm
    where sm.id = p_actor_member_id
      and sm.society_id = p_society_id
      and sm.status = 'ACTIVE'
  );
$$;

create or replace function public.finance_assert_society_role(
  p_society_id uuid,
  p_actor_member_id uuid,
  p_allowed_roles text[]
) returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_actor_member_id is null or not exists (
    select 1
    from society_members sm
    where sm.id = p_actor_member_id
      and sm.society_id = p_society_id
      and sm.status = 'ACTIVE'
  ) then
    raise exception 'Nedostaje aktivni testni clan koji izvrsava finansijsku promenu.';
  end if;

  if coalesce(array_length(p_allowed_roles, 1), 0) = 0 then
    raise exception 'Nije zadata dozvoljena testna uloga.';
  end if;

  -- DEV/V1: stvarnu ulogu trenutno odredjuje frontend test login.
  -- Povratna vrednost se koristi samo za audit dok finalni Auth nije uveden.
  return p_allowed_roles[1];
end;
$$;

-- DEV/V1: dogadjaji koriste frontend testnu ulogu Predsednik, bez finalne
-- Supabase Auth sesije. Dozvoli finansijski status ucesnika samo kada je
-- prosledjeni tehnicki izvrsilac aktivan clan istog drustva kao dogadjaj.
create or replace function public.finance_actor_event_role(
  p_event_participant_id uuid,
  p_actor_member_id uuid
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event_society_id uuid;
begin
  select se.society_id
  into v_event_society_id
  from event_participants ep
  join society_events se on se.id = ep.event_id
  where ep.id = p_event_participant_id;

  if v_event_society_id is null then
    raise exception 'Ucesnik nije pronadjen.';
  end if;

  if p_actor_member_id is null or not exists (
    select 1
    from society_members sm
    where sm.id = p_actor_member_id
      and sm.society_id = v_event_society_id
      and sm.status = 'ACTIVE'
  ) then
    raise exception 'Nedostaje aktivni testni clan koji izvrsava promenu statusa.';
  end if;

  return 'Predsednik';
end;
$$;

revoke all on function public.finance_get_test_actor_context(text) from public;
grant execute on function public.finance_get_test_actor_context(text) to authenticated, anon;
revoke all on function public.finance_actor_event_role(uuid, uuid) from public;
grant execute on function public.finance_actor_event_role(uuid, uuid) to authenticated, anon;
grant execute on function public.finance_set_event_participant_status(uuid, text, text, uuid) to authenticated, anon;
grant execute on function public.finance_cancel_event_section(uuid, text, uuid) to authenticated, anon;

commit;
