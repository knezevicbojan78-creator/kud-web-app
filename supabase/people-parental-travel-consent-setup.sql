begin;

alter table public.people
  add column if not exists parental_travel_consent boolean not null default false,
  add column if not exists parental_travel_consent_valid_until date null;

alter table public.people
  drop constraint if exists people_parental_travel_consent_validity_check;

alter table public.people
  add constraint people_parental_travel_consent_validity_check check (
    parental_travel_consent
    or parental_travel_consent_valid_until is null
  );

comment on column public.people.parental_travel_consent is
  'Da li postoji overena saglasnost oba roditelja za put maloletne osobe u inostranstvo.';
comment on column public.people.parental_travel_consent_valid_until is
  'Datum do kog saglasnost oba roditelja vazi.';

create or replace function public.set_event_participant_status(
  p_event_participant_id uuid,
  p_new_status text,
  p_actor_role text
) returns public.event_participants
language plpgsql
security definer
set search_path = public
as $$
declare
  v_participant event_participants;
  v_event society_events;
  v_person people;
begin
  if p_actor_role not in ('Predsednik', 'UR') then
    raise exception 'Status ucesnika menja samo predsednik ili UR.';
  end if;
  if p_new_status not in ('PLANNED', 'CONFIRMED', 'DECLINED', 'CANCELLED', 'ATTENDED', 'ABSENT') then
    raise exception 'Nepoznat status ucesnika.';
  end if;

  select * into v_participant from event_participants
  where id = p_event_participant_id for update;
  if not found then raise exception 'Ucesnik nije pronadjen.'; end if;

  select * into v_event from society_events where id = v_participant.event_id;
  select * into v_person from people where id = v_participant.person_id;

  if p_new_status = 'CONFIRMED'
    and v_participant.society_member_id is null
    and (
      length(trim(v_person.first_name)) = 0
      or length(trim(v_person.last_name)) = 0
      or (v_person.email is null and v_person.phone is null)
    ) then
    raise exception 'Putnik mora imati ime, prezime i najmanje telefon ili email.';
  end if;

  if p_new_status = 'CONFIRMED'
    and v_event.event_type = 'TRIP'
    and lower(trim(v_event.country)) not in ('srbija', 'serbia') then
    if v_event.departure_at is null or v_event.return_at is null then
      raise exception 'Datum polaska i povratka su obavezni za inostrano putovanje.';
    end if;
    if length(trim(v_person.first_name)) = 0
      or length(trim(v_person.last_name)) = 0
      or v_person.birth_date is null
      or v_person.gender is null
      or length(trim(coalesce(v_person.nationality, ''))) = 0
      or length(trim(coalesce(v_person.address, ''))) = 0
      or length(trim(coalesce(v_person.city, ''))) = 0
      or length(trim(coalesce(v_person.postal_code, ''))) = 0
      or length(trim(coalesce(v_person.country, ''))) = 0
      or length(trim(coalesce(v_person.passport_number, ''))) = 0
      or length(trim(coalesce(v_person.passport_issuing_country, ''))) = 0
      or v_person.passport_expiry_date is null
      or (
        v_person.email is null and v_person.phone is null
        and not exists (
          select 1 from person_guardians pg
          join people guardian on guardian.id = pg.guardian_person_id
          where pg.child_person_id = v_person.id
            and pg.is_primary = true
            and (guardian.email is not null or guardian.phone is not null)
        )
      ) then
      raise exception 'Putna dokumentacija osobe nije kompletna.';
    end if;
    if v_person.passport_expiry_date < v_event.return_at::date then
      raise exception 'Pasos ne vazi do datuma povratka.';
    end if;
    if v_person.birth_date > (v_event.departure_at::date - interval '18 years')::date
      and (
        not v_person.parental_travel_consent
        or v_person.parental_travel_consent_valid_until is null
        or v_person.parental_travel_consent_valid_until < v_event.return_at::date
      ) then
      raise exception 'Maloletni putnik nema vazecu saglasnost oba roditelja za put u inostranstvo.';
    end if;
  end if;

  update event_participants set participation_status = p_new_status, updated_at = now()
  where id = p_event_participant_id returning * into v_participant;
  return v_participant;
end;
$$;

grant execute on function public.set_event_participant_status(uuid, text, text) to anon, authenticated;

commit;
