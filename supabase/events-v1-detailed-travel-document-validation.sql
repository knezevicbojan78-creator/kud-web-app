-- FOLKLORAS V1
-- Precizne poruke za putnu dokumentaciju i pravilo da pasos na dan polaska
-- mora imati najmanje jos tri meseca vazenja.

begin;

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
  v_participant public.event_participants;
  v_event public.society_events;
  v_person public.people;
  v_minimum_passport_expiry date;
begin
  if p_actor_role not in ('Predsednik', 'UR') then
    raise exception 'Status ucesnika menja samo predsednik ili UR.';
  end if;
  if p_new_status not in (
    'PLANNED', 'CONFIRMED', 'DECLINED', 'CANCELLED', 'ATTENDED', 'ABSENT'
  ) then
    raise exception 'Nepoznat status ucesnika.';
  end if;

  select * into v_participant
  from public.event_participants
  where id = p_event_participant_id
  for update;
  if not found then raise exception 'Ucesnik nije pronadjen.'; end if;

  select * into v_event
  from public.society_events
  where id = v_participant.event_id;

  select * into v_person
  from public.people
  where id = v_participant.person_id;

  if p_new_status = 'CONFIRMED'
    and v_participant.society_member_id is null
    and (
      length(trim(v_person.first_name)) = 0
      or length(trim(v_person.last_name)) = 0
      or (v_person.email is null and v_person.phone is null)
    ) then
    raise exception
      'Putnik mora imati ime, prezime i najmanje telefon ili email.';
  end if;

  if p_new_status = 'CONFIRMED'
    and v_event.event_type = 'TRIP'
    and lower(trim(v_event.country)) not in ('srbija', 'serbia') then

    if v_event.departure_at is null or v_event.return_at is null then
      raise exception
        'Datum polaska i povratka su obavezni za inostrano putovanje.';
    end if;
    if length(trim(v_person.first_name)) = 0
      or length(trim(v_person.last_name)) = 0 then
      raise exception 'Nedostaju ime ili prezime putnika.';
    end if;
    if v_person.birth_date is null then
      raise exception 'Nedostaje datum rodjenja putnika.';
    end if;
    if v_person.gender is null then
      raise exception 'Nedostaje pol putnika.';
    end if;
    if length(trim(coalesce(v_person.nationality, ''))) = 0 then
      raise exception 'Nedostaje drzavljanstvo putnika.';
    end if;
    if length(trim(coalesce(v_person.address, ''))) = 0
      or length(trim(coalesce(v_person.city, ''))) = 0
      or length(trim(coalesce(v_person.postal_code, ''))) = 0
      or length(trim(coalesce(v_person.country, ''))) = 0 then
      raise exception
        'Adresa putnika nije kompletna: adresa, grad, postanski broj i drzava su obavezni.';
    end if;
    if length(trim(coalesce(v_person.passport_number, ''))) = 0 then
      raise exception 'Nedostaje broj pasosa putnika.';
    end if;
    if length(trim(coalesce(v_person.passport_issuing_country, ''))) = 0 then
      raise exception 'Nedostaje drzava koja je izdala pasos.';
    end if;
    if v_person.passport_expiry_date is null then
      raise exception 'Nedostaje datum vazenja pasosa.';
    end if;
    if v_person.email is null
      and v_person.phone is null
      and not exists (
        select 1
        from public.person_guardians guardian_link
        join public.people guardian
          on guardian.id = guardian_link.guardian_person_id
        where guardian_link.child_person_id = v_person.id
          and guardian_link.is_primary = true
          and (guardian.email is not null or guardian.phone is not null)
      ) then
      raise exception
        'Nedostaje kontakt putnika ili kontakt primarnog roditelja/staratelja.';
    end if;

    if v_person.passport_expiry_date < v_event.return_at::date then
      raise exception 'Pasos ne vazi do datuma povratka.';
    end if;

    v_minimum_passport_expiry :=
      (v_event.departure_at::date + interval '3 months')::date;
    if v_person.passport_expiry_date < v_minimum_passport_expiry then
      raise exception
        'Pasos mora vaziti najmanje tri meseca od datuma polaska, odnosno najmanje do %.',
        to_char(v_minimum_passport_expiry, 'DD.MM.YYYY');
    end if;

    if v_person.birth_date >
      (v_event.departure_at::date - interval '18 years')::date then
      if not coalesce(v_person.parental_travel_consent, false) then
        raise exception
          'Nije evidentirana fizicki dostavljena saglasnost oba roditelja za put maloletnika u inostranstvo.';
      end if;
      if v_person.parental_travel_consent_valid_until is null then
        raise exception 'Nedostaje datum vazenja roditeljske saglasnosti.';
      end if;
      if v_person.parental_travel_consent_valid_until < v_event.return_at::date then
        raise exception
          'Roditeljska saglasnost ne vazi do datuma povratka.';
      end if;
    end if;
  end if;

  update public.event_participants
  set participation_status = p_new_status,
      updated_at = now()
  where id = p_event_participant_id
  returning * into v_participant;

  return v_participant;
end;
$$;

revoke all on function public.set_event_participant_status(uuid, text, text)
  from public, anon, authenticated;

commit;
