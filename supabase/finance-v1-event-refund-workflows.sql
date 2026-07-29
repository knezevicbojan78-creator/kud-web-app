-- FOLKLORAS DEV/V1
-- FINANSIJE: kotizacije dogadjaja, otkazivanje i povracaji kredita.
-- Pokrenuti nakon finance-v1-payment-workflows.sql.

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
  v_participant event_participants;
  v_event society_events;
  v_actor_person_id uuid;
begin
  if auth.uid() is null or p_actor_member_id is null then
    raise exception 'Korisnik nije prijavljen.';
  end if;
  select * into v_participant from event_participants
  where id = p_event_participant_id;
  if not found then raise exception 'Ucesnik nije pronadjen.'; end if;
  select * into v_event from society_events where id = v_participant.event_id;

  select member.person_id into v_actor_person_id
  from society_members member
  join people person on person.id = member.person_id
  where member.id = p_actor_member_id
    and member.society_id = v_event.society_id
    and member.status = 'ACTIVE'
    and coalesce(member.user_id, person.user_id) = auth.uid();

  if v_actor_person_id is not null and public.permissions_can_access_event(
    v_event.society_id, p_actor_member_id, v_actor_person_id,
    v_event.id, 'events.change_participant_status'
  ) then
    return 'Ovlašćeni korisnik';
  end if;

  raise exception 'Nemate pravo promene statusa ovog ucesnika.';
end;
$$;

create or replace function public.finance_cancel_event_obligation(
  p_obligation_id uuid,
  p_reason text,
  p_actor_member_id uuid,
  p_audit_role text
) returns public.financial_obligations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_obligation financial_obligations;
  v_paid numeric(12,2);
  v_allocation financial_obligation_allocations;
begin
  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'Razlog ponistavanja kotizacije je obavezan.';
  end if;
  select * into v_obligation from financial_obligations
  where id = p_obligation_id for update;
  if not found then raise exception 'Kotizacija nije pronadjena.'; end if;
  if v_obligation.obligation_type <> 'EVENT_FEE' then
    raise exception 'Izabrana obaveza nije kotizacija.';
  end if;
  if v_obligation.status = 'CANCELLED' then return v_obligation; end if;

  select coalesce(sum(amount), 0) into v_paid
  from financial_obligation_allocations
  where obligation_id = v_obligation.id and status = 'ACTIVE';

  for v_allocation in
    select * from financial_obligation_allocations
    where obligation_id = v_obligation.id and status = 'ACTIVE'
    order by created_at, id
  loop
    update financial_obligation_allocations set
      status = 'REVERSED', reversed_at = now(),
      reversed_by_user_id = auth.uid(),
      reversal_reason = trim(p_reason)
    where id = v_allocation.id;
  end loop;

  if v_paid > 0 then
    insert into financial_credit_entries (
      society_id, person_id, society_member_id, currency, amount,
      entry_type, source_obligation_id, created_by_user_id,
      created_by_society_member_id, reason
    ) values (
      v_obligation.society_id, v_obligation.person_id,
      v_obligation.society_member_id, v_obligation.currency, v_paid,
      'EVENT_CANCELLATION', v_obligation.id, auth.uid(),
      p_actor_member_id, trim(p_reason)
    );
  end if;

  update financial_obligations set
    status = 'CANCELLED', cancellation_reason = trim(p_reason),
    cancelled_at = now(), cancelled_by_user_id = auth.uid(), updated_at = now()
  where id = v_obligation.id
  returning * into v_obligation;

  insert into financial_audit_log (
    society_id, entity_type, entity_id, action, new_values, reason,
    actor_user_id, actor_society_member_id, actor_role
  ) values (
    v_obligation.society_id, 'FINANCIAL_OBLIGATION', v_obligation.id,
    'EVENT_FEE_CANCELLED',
    jsonb_build_object('obligation', to_jsonb(v_obligation), 'credit_created', v_paid),
    trim(p_reason), auth.uid(), p_actor_member_id, p_audit_role
  );
  return v_obligation;
end;
$$;

create or replace function public.finance_set_event_participant_status(
  p_event_participant_id uuid,
  p_new_status text,
  p_reason text,
  p_actor_member_id uuid
) returns public.event_participants
language plpgsql
security definer
set search_path = public
as $$
declare
  v_participant event_participants;
  v_event society_events;
  v_role text;
  v_obligation financial_obligations;
  v_old_status text;
begin
  v_role := finance_actor_event_role(p_event_participant_id, p_actor_member_id);
  select * into v_participant from event_participants
  where id = p_event_participant_id for update;
  select * into v_event from society_events where id = v_participant.event_id;
  v_old_status := v_participant.participation_status;

  if p_new_status = 'CANCELLED' then
    if v_old_status <> 'CONFIRMED' then
      raise exception 'CANCELLED se koristi za prethodno potvrdjenog ucesnika.';
    end if;
    if length(trim(coalesce(p_reason, ''))) = 0 then
      raise exception 'Razlog otkazivanja ucesca je obavezan.';
    end if;
  elsif p_new_status = 'DECLINED' and v_old_status = 'CONFIRMED' then
    raise exception 'Potvrdjeno ucesce se otkazuje statusom CANCELLED.';
  end if;

  -- Zadrzava postojecu validaciju dokumenata i statusa iz DOGADJAJI V1.
  select * into v_participant
  from set_event_participant_status(p_event_participant_id, p_new_status, v_role);

  if p_new_status = 'CONFIRMED' and v_event.has_participation_fee then
    if v_participant.participation_fee_amount is null then
      raise exception 'Iznos kotizacije ucesnika nije definisan.';
    end if;
    if v_event.payment_due_date is null then
      raise exception 'Krajnji rok placanja kotizacije nije definisan.';
    end if;

    insert into financial_obligations (
      society_id, obligation_type, person_id, society_member_id,
      event_id, event_participant_id, title, original_amount,
      current_amount, currency, due_date, status,
      created_by_user_id, created_by_society_member_id
    ) values (
      v_event.society_id, 'EVENT_FEE', v_participant.person_id,
      v_participant.society_member_id, v_event.id, v_participant.id,
      'Kotizacija - ' || v_event.title, v_participant.participation_fee_amount,
      v_participant.participation_fee_amount, v_event.currency,
      v_event.payment_due_date,
      case when v_participant.participation_fee_amount = 0 then 'PAID' else 'OPEN' end,
      auth.uid(), p_actor_member_id
    )
    on conflict (event_participant_id) where obligation_type = 'EVENT_FEE'
    do nothing;

    select * into v_obligation from financial_obligations
    where event_participant_id = v_participant.id
      and obligation_type = 'EVENT_FEE';

    insert into financial_audit_log (
      society_id, entity_type, entity_id, action, new_values,
      actor_user_id, actor_society_member_id, actor_role
    ) values (
      v_event.society_id, 'FINANCIAL_OBLIGATION', v_obligation.id,
      'EVENT_FEE_CREATED', to_jsonb(v_obligation),
      auth.uid(), p_actor_member_id, v_role
    );
  elsif p_new_status = 'CANCELLED' then
    select * into v_obligation from financial_obligations
    where event_participant_id = v_participant.id
      and obligation_type = 'EVENT_FEE';
    if found then
      perform finance_cancel_event_obligation(
        v_obligation.id, p_reason, p_actor_member_id, v_role
      );
    end if;
  end if;

  insert into financial_audit_log (
    society_id, entity_type, entity_id, action, old_values, new_values,
    reason, actor_user_id, actor_society_member_id, actor_role
  ) values (
    v_event.society_id, 'EVENT_PARTICIPANT', v_participant.id,
    'PARTICIPATION_STATUS_CHANGED',
    jsonb_build_object('status', v_old_status),
    jsonb_build_object('status', v_participant.participation_status),
    nullif(trim(p_reason), ''), auth.uid(), p_actor_member_id, v_role
  );
  return v_participant;
end;
$$;

create or replace function public.finance_cancel_event(
  p_event_id uuid,
  p_reason text,
  p_actor_member_id uuid
) returns public.society_events
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event society_events;
  v_participant event_participants;
  v_obligation financial_obligations;
  v_actor_person_id uuid;
begin
  select * into v_event from society_events where id = p_event_id for update;
  if not found then raise exception 'Dogadjaj nije pronadjen.'; end if;
  select member.person_id into v_actor_person_id
  from society_members member
  join people person on person.id = member.person_id
  where member.id = p_actor_member_id
    and member.society_id = v_event.society_id
    and member.status = 'ACTIVE'
    and coalesce(member.user_id, person.user_id) = auth.uid();
  if v_actor_person_id is null or not public.permissions_can_access_event(
    v_event.society_id, p_actor_member_id, v_actor_person_id,
    v_event.id, 'events.cancel_approved'
  ) then raise exception 'Nemate pravo otkazivanja ovog dogadjaja.'; end if;
  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'Razlog otkazivanja dogadjaja je obavezan.';
  end if;

  select * into v_event
  from cancel_event(p_event_id, p_reason, 'Ovlašćeni korisnik', auth.uid(), p_actor_member_id);

  for v_participant in
    select * from event_participants
    where event_id = p_event_id and participation_status = 'CONFIRMED'
    order by created_at, id
  loop
    update event_participants set participation_status = 'CANCELLED', updated_at = now()
    where id = v_participant.id;
    select * into v_obligation from financial_obligations
    where event_participant_id = v_participant.id
      and obligation_type = 'EVENT_FEE';
    if found then
      perform finance_cancel_event_obligation(
        v_obligation.id, p_reason, p_actor_member_id, 'Ovlašćeni korisnik'
      );
    end if;
  end loop;
  return v_event;
end;
$$;

create or replace function public.finance_cancel_event_section(
  p_event_section_id uuid,
  p_reason text,
  p_actor_member_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event_section event_sections;
  v_event society_events;
  v_participant event_participants;
  v_obligation financial_obligations;
  v_exclusive_participant_ids uuid[] := array[]::uuid[];
  v_cancelled_obligations integer := 0;
  v_removed_planned integer := 0;
  v_actor_person_id uuid;
begin
  select * into v_event_section
  from event_sections
  where id = p_event_section_id
  for update;
  if not found then raise exception 'Sekcija dogadjaja nije pronadjena.'; end if;

  select * into v_event from society_events where id = v_event_section.event_id;
  select member.person_id into v_actor_person_id
  from society_members member
  join people person on person.id = member.person_id
  where member.id = p_actor_member_id
    and member.society_id = v_event.society_id
    and member.status = 'ACTIVE'
    and coalesce(member.user_id, person.user_id) = auth.uid();
  if v_actor_person_id is null
     or not public.permissions_can_access_event(
       v_event.society_id, p_actor_member_id, v_actor_person_id,
       v_event.id, 'events.manage_sections'
     )
     or not public.permissions_can_access_section(
       v_event.society_id, p_actor_member_id, v_actor_person_id,
       v_event_section.section_id, 'events.manage_sections'
     )
  then raise exception 'Nemate pravo uklanjanja ove sekcije.'; end if;
  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'Razlog otkazivanja sekcije je obavezan.';
  end if;

  for v_participant in
    select ep.*
    from event_participants ep
    join event_participant_sections eps
      on eps.event_participant_id = ep.id
     and eps.event_section_id = v_event_section.id
    where not exists (
      select 1
      from event_participant_sections other_eps
      join event_sections other_es on other_es.id = other_eps.event_section_id
      where other_eps.event_participant_id = ep.id
        and other_eps.event_section_id <> v_event_section.id
        and other_es.event_id = v_event.id
    )
    order by ep.created_at, ep.id
  loop
    v_exclusive_participant_ids := array_append(v_exclusive_participant_ids, v_participant.id);
    select * into v_obligation
    from financial_obligations
    where event_participant_id = v_participant.id
      and obligation_type = 'EVENT_FEE';

    if found and v_obligation.status <> 'CANCELLED' then
      perform finance_cancel_event_obligation(
        v_obligation.id, p_reason, p_actor_member_id, 'Ovlašćeni korisnik'
      );
      update event_participants
      set participation_status = 'CANCELLED', updated_at = now()
      where id = v_participant.id;
      v_cancelled_obligations := v_cancelled_obligations + 1;
    end if;
  end loop;

  delete from event_sections where id = v_event_section.id;

  delete from event_participants ep
  where ep.id = any(v_exclusive_participant_ids)
    and not exists (
      select 1 from financial_obligations fo
      where fo.event_participant_id = ep.id
    );
  get diagnostics v_removed_planned = row_count;

  insert into financial_audit_log (
    society_id, entity_type, entity_id, action, old_values, new_values,
    reason, actor_user_id, actor_society_member_id, actor_role
  ) values (
    v_event.society_id, 'EVENT_SECTION', v_event_section.id,
    'EVENT_SECTION_CANCELLED', to_jsonb(v_event_section),
    jsonb_build_object(
      'cancelled_obligations', v_cancelled_obligations,
      'removed_unconfirmed_participants', v_removed_planned
    ),
    trim(p_reason), auth.uid(), p_actor_member_id, 'Ovlašćeni korisnik'
  );

  return jsonb_build_object(
    'cancelled_obligations', v_cancelled_obligations,
    'removed_unconfirmed_participants', v_removed_planned
  );
end;
$$;

create or replace function public.finance_record_refund(
  p_society_id uuid,
  p_person_id uuid,
  p_amount numeric,
  p_currency text,
  p_refund_method text,
  p_reason text,
  p_actor_member_id uuid
) returns public.financial_refunds
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
  v_currency text := upper(trim(p_currency));
  v_method text := upper(trim(p_refund_method));
  v_balance numeric(12,2);
  v_number record;
  v_member_id uuid;
  v_credit_entry financial_credit_entries;
  v_refund financial_refunds;
  v_actor_person_id uuid;
begin
  select member.person_id into v_actor_person_id
  from society_members member
  join people person on person.id = member.person_id
  where member.id = p_actor_member_id
    and member.society_id = p_society_id
    and member.status = 'ACTIVE'
    and coalesce(member.user_id, person.user_id) = auth.uid();
  if v_actor_person_id is null or not public.permissions_has_scope(
    p_society_id, p_actor_member_id, v_actor_person_id,
    'finance.record_refund', array['SOCIETY']::text[]
  ) then raise exception 'Nemate pravo evidentiranja povracaja.'; end if;
  v_role := 'Ovlašćeni korisnik';
  if p_amount is null or p_amount <= 0 then
    raise exception 'Iznos povracaja mora biti veci od nule.';
  end if;
  if v_currency !~ '^[A-Z]{3}$' then
    raise exception 'Valuta nije ispravna.';
  end if;
  if v_method not in ('CASH', 'BANK_TRANSFER') then
    raise exception 'Nacin povracaja nije ispravan.';
  end if;
  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'Razlog povracaja je obavezan.';
  end if;

  select coalesce(sum(amount), 0) into v_balance
  from financial_credit_entries
  where society_id = p_society_id and person_id = p_person_id
    and currency = v_currency;
  if v_balance < p_amount then
    raise exception 'Raspolozivi kredit nije dovoljan za povracaj.';
  end if;
  select id into v_member_id from society_members
  where society_id = p_society_id and person_id = p_person_id limit 1;

  insert into financial_credit_entries (
    society_id, person_id, society_member_id, currency, amount,
    entry_type, created_by_user_id, created_by_society_member_id, reason
  ) values (
    p_society_id, p_person_id, v_member_id, v_currency, -p_amount,
    'REFUND', auth.uid(), p_actor_member_id, trim(p_reason)
  ) returning * into v_credit_entry;

  select * into v_number from finance_next_document_number(p_society_id, 'REFUND');
  insert into financial_refunds (
    society_id, person_id, society_member_id, refund_year,
    refund_sequence, refund_number, amount, currency, refund_method,
    credit_entry_id, status, reason, recorded_by_user_id,
    recorded_by_society_member_id
  ) values (
    p_society_id, p_person_id, v_member_id, v_number.counter_year,
    v_number.sequence_number, v_number.document_number, p_amount,
    v_currency, v_method, v_credit_entry.id, 'POSTED', trim(p_reason),
    auth.uid(), p_actor_member_id
  ) returning * into v_refund;

  insert into financial_audit_log (
    society_id, entity_type, entity_id, action, new_values, reason,
    actor_user_id, actor_society_member_id, actor_role
  ) values (
    p_society_id, 'REFUND', v_refund.id, 'REFUND_RECORDED',
    to_jsonb(v_refund), trim(p_reason), auth.uid(), p_actor_member_id, v_role
  );
  return v_refund;
end;
$$;

create or replace function public.finance_void_refund(
  p_refund_id uuid,
  p_reason text,
  p_actor_member_id uuid
) returns public.financial_refunds
language plpgsql
security definer
set search_path = public
as $$
declare
  v_refund financial_refunds;
  v_credit financial_credit_entries;
  v_role text;
  v_actor_person_id uuid;
begin
  select * into v_refund from financial_refunds where id = p_refund_id for update;
  if not found then raise exception 'Povracaj nije pronadjen.'; end if;
  select member.person_id into v_actor_person_id
  from society_members member
  join people person on person.id = member.person_id
  where member.id = p_actor_member_id
    and member.society_id = v_refund.society_id
    and member.status = 'ACTIVE'
    and coalesce(member.user_id, person.user_id) = auth.uid();
  if v_actor_person_id is null or not public.permissions_has_scope(
    v_refund.society_id, p_actor_member_id, v_actor_person_id,
    'finance.void_refund', array['SOCIETY']::text[]
  ) then raise exception 'Nemate pravo ponistavanja povracaja.'; end if;
  v_role := 'Ovlašćeni korisnik';
  if v_refund.status = 'VOIDED' then raise exception 'Povracaj je vec ponisten.'; end if;
  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'Razlog ponistavanja povracaja je obavezan.';
  end if;
  select * into v_credit from financial_credit_entries
  where id = v_refund.credit_entry_id;

  insert into financial_credit_entries (
    society_id, person_id, society_member_id, currency, amount,
    entry_type, related_entry_id, created_by_user_id,
    created_by_society_member_id, reason
  ) values (
    v_refund.society_id, v_refund.person_id, v_refund.society_member_id,
    v_refund.currency, v_refund.amount, 'REFUND_VOID_REVERSAL',
    v_credit.id, auth.uid(), p_actor_member_id, trim(p_reason)
  );

  update financial_refunds set
    status = 'VOIDED', voided_by_user_id = auth.uid(), voided_at = now(),
    void_reason = trim(p_reason)
  where id = v_refund.id returning * into v_refund;

  insert into financial_audit_log (
    society_id, entity_type, entity_id, action, new_values, reason,
    actor_user_id, actor_society_member_id, actor_role
  ) values (
    v_refund.society_id, 'REFUND', v_refund.id, 'REFUND_VOIDED',
    to_jsonb(v_refund), trim(p_reason), auth.uid(), p_actor_member_id, v_role
  );
  return v_refund;
end;
$$;

revoke all on function public.finance_actor_event_role(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.finance_cancel_event_obligation(uuid, text, uuid, text)
  from public, anon, authenticated;
revoke all on function public.finance_set_event_participant_status(uuid, text, text, uuid)
  from public, anon, authenticated;
revoke all on function public.finance_cancel_event(uuid, text, uuid)
  from public, anon, authenticated;
revoke all on function public.finance_cancel_event_section(uuid, text, uuid)
  from public, anon, authenticated;
revoke all on function public.finance_record_refund(uuid, uuid, numeric, text, text, text, uuid)
  from public, anon, authenticated;
revoke all on function public.finance_void_refund(uuid, text, uuid)
  from public, anon, authenticated;

grant execute on function public.finance_set_event_participant_status(uuid, text, text, uuid) to authenticated;
grant execute on function public.finance_cancel_event(uuid, text, uuid) to authenticated;
grant execute on function public.finance_cancel_event_section(uuid, text, uuid) to authenticated;
grant execute on function public.finance_record_refund(uuid, uuid, numeric, text, text, text, uuid) to authenticated;
grant execute on function public.finance_void_refund(uuid, text, uuid) to authenticated;

-- Finansijski statusi vise ne smeju da zaobidju kontrolisani workflow.
revoke execute on function public.set_event_participant_status(uuid, text, text) from anon, authenticated;
revoke execute on function public.cancel_event(uuid, text, text, uuid, uuid) from anon, authenticated;

select pg_notify('pgrst', 'reload schema');
commit;
