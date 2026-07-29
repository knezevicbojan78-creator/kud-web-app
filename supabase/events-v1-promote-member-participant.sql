-- FOLKLORAS V1
-- Ako je postojeca osoba ranije dodata kao gost, a zatim izabrana kao aktivni
-- clan sekcije, dopuni isti zapis ucesnika umesto pravljenja duplikata.

begin;

create or replace function public.promote_event_guest_to_section_member()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_participant public.event_participants;
  v_event_section public.event_sections;
  v_society_member_id uuid;
begin
  select *
  into v_participant
  from public.event_participants
  where id = new.event_participant_id
  for update;

  if v_participant.society_member_id is not null then
    return new;
  end if;

  select *
  into v_event_section
  from public.event_sections
  where id = new.event_section_id;

  select member.id
  into v_society_member_id
  from public.society_members member
  join public.member_sections membership
    on membership.society_member_id = member.id
   and membership.section_id = v_event_section.section_id
   and membership.status = 'ACTIVE'
  join public.society_events event_row
    on event_row.id = v_participant.event_id
   and event_row.society_id = member.society_id
  where member.person_id = v_participant.person_id
    and member.status = 'ACTIVE'
  order by member.id
  limit 1;

  if v_society_member_id is not null then
    update public.event_participants
    set society_member_id = v_society_member_id
    where id = v_participant.id
      and society_member_id is null;
  end if;

  return new;
end;
$$;

drop trigger if exists a_promote_event_guest_to_section_member
  on public.event_participant_sections;
create trigger a_promote_event_guest_to_section_member
before insert on public.event_participant_sections
for each row execute function public.promote_event_guest_to_section_member();

revoke all on function public.promote_event_guest_to_section_member()
  from public, anon, authenticated;

commit;
