-- FOLKLORAS DEV/V1
-- FINANSIJE: numeracija, evidentiranje i ponistavanje uplata.
-- Pokrenuti nakon finance-v1-membership-workflows.sql.

begin;

create or replace function public.finance_next_document_number(
  p_society_id uuid,
  p_counter_type text
) returns table(counter_year integer, sequence_number integer, document_number text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_year integer := extract(year from current_date)::integer;
  v_sequence integer;
  v_prefix text;
begin
  if p_counter_type not in ('PAYMENT', 'REFUND') then
    raise exception 'Nepoznat tip finansijskog dokumenta.';
  end if;
  v_prefix := case when p_counter_type = 'PAYMENT' then 'UPL' else 'POV' end;

  insert into financial_number_counters (
    society_id, counter_year, counter_type, last_number
  ) values (p_society_id, v_year, p_counter_type, 1)
  on conflict on constraint financial_number_counters_pkey do update set
    last_number = financial_number_counters.last_number + 1,
    updated_at = now()
  returning last_number into v_sequence;

  counter_year := v_year;
  sequence_number := v_sequence;
  document_number := v_prefix || '-' || v_year::text || '-' || lpad(v_sequence::text, 6, '0');
  return next;
end;
$$;

create or replace function public.finance_refresh_obligation_status(
  p_obligation_id uuid
) returns public.financial_obligations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_obligation financial_obligations;
  v_paid numeric(12,2);
begin
  select * into v_obligation
  from financial_obligations where id = p_obligation_id for update;
  if not found then raise exception 'Obaveza nije pronadjena.'; end if;
  if v_obligation.status = 'CANCELLED' then return v_obligation; end if;

  select coalesce(sum(foa.amount), 0) into v_paid
  from financial_obligation_allocations foa
  where foa.obligation_id = p_obligation_id and foa.status = 'ACTIVE';

  if v_paid > v_obligation.current_amount then
    raise exception 'Rasporedjeni iznos je veci od obaveze.';
  end if;

  update financial_obligations set
    status = case
      when v_paid = 0 then 'OPEN'
      when v_paid < current_amount then 'PARTIALLY_PAID'
      else 'PAID'
    end,
    updated_at = now()
  where id = p_obligation_id
  returning * into v_obligation;
  return v_obligation;
end;
$$;

create or replace function public.finance_record_payment(
  p_society_id uuid,
  p_amount numeric,
  p_currency text,
  p_payment_method text,
  p_allocations jsonb,
  p_credit_to_person_id uuid,
  p_credit_use_person_id uuid,
  p_credit_use_amount numeric,
  p_actor_user_id uuid,
  p_actor_member_id uuid
) returns public.financial_payments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
  v_currency text := upper(trim(p_currency));
  v_method text := upper(trim(p_payment_method));
  v_payment financial_payments;
  v_number record;
  v_item jsonb;
  v_obligation financial_obligations;
  v_allocation_amount numeric(12,2);
  v_total_allocations numeric(12,2) := 0;
  v_payment_remaining numeric(12,2) := p_amount;
  v_credit_requested numeric(12,2) := coalesce(p_credit_use_amount, 0);
  v_credit_remaining numeric(12,2) := coalesce(p_credit_use_amount, 0);
  v_credit_balance numeric(12,2) := 0;
  v_from_payment numeric(12,2);
  v_from_credit numeric(12,2);
  v_paid_before numeric(12,2);
  v_surplus numeric(12,2);
  v_credit_entry financial_credit_entries;
  v_credit_target_member_id uuid;
  v_actor_person_id uuid;
begin
  if p_actor_user_id is not null and p_actor_user_id <> auth.uid() then
    raise exception 'Identitet korisnika nije ispravan.';
  end if;
  select member.person_id into v_actor_person_id
  from society_members member
  join people person on person.id = member.person_id
  where member.id = p_actor_member_id
    and member.society_id = p_society_id
    and member.status = 'ACTIVE'
    and coalesce(member.user_id, person.user_id) = auth.uid();
  if v_actor_person_id is null or not public.permissions_has_scope(
    p_society_id, p_actor_member_id, v_actor_person_id,
    'finance.record_payment', array['SOCIETY']::text[]
  ) then raise exception 'Nemate pravo evidentiranja uplate.'; end if;
  v_role := 'Ovlašćeni korisnik';
  if p_amount is null or p_amount <= 0 then
    raise exception 'Iznos nove uplate mora biti veci od nule.';
  end if;
  if v_currency !~ '^[A-Z]{3}$' then
    raise exception 'Valuta mora imati troslovni ISO kod.';
  end if;
  if v_method not in ('CASH', 'BANK_TRANSFER') then
    raise exception 'Dozvoljeni nacini placanja su gotovina i uplata na racun.';
  end if;
  if p_allocations is null or jsonb_typeof(p_allocations) <> 'array'
    or jsonb_array_length(p_allocations) = 0 then
    raise exception 'Izaberite najmanje jednu obavezu.';
  end if;
  if v_credit_requested < 0 then
    raise exception 'Iznos kredita za koriscenje nije ispravan.';
  end if;
  if v_credit_requested > 0 and p_credit_use_person_id is null then
    raise exception 'Izaberite clana ciji kredit se koristi.';
  end if;
  if v_credit_requested > 0 and not public.permissions_has_scope(
    p_society_id, p_actor_member_id, v_actor_person_id,
    'finance.use_credit_for_fee', array['SOCIETY']::text[]
  ) then raise exception 'Nemate pravo koriscenja kredita.'; end if;

  if v_credit_requested > 0 then
    select coalesce(sum(amount), 0) into v_credit_balance
    from financial_credit_entries
    where society_id = p_society_id
      and person_id = p_credit_use_person_id
      and currency = v_currency;
    if v_credit_balance < v_credit_requested then
      raise exception 'Raspolozivi kredit nije dovoljan.';
    end if;
  end if;

  for v_item in select value from jsonb_array_elements(p_allocations)
  loop
    if not (v_item ? 'obligation_id') or not (v_item ? 'amount') then
      raise exception 'Raspodela uplate nije ispravna.';
    end if;
    v_allocation_amount := (v_item->>'amount')::numeric;
    if v_allocation_amount <= 0 then
      raise exception 'Iznos raspodele mora biti veci od nule.';
    end if;
    v_total_allocations := v_total_allocations + v_allocation_amount;
  end loop;

  if v_total_allocations > p_amount + v_credit_requested then
    raise exception 'Raspodela je veca od nove uplate i izabranog kredita.';
  end if;

  select * into v_number from finance_next_document_number(p_society_id, 'PAYMENT');
  insert into financial_payments (
    society_id, receipt_year, receipt_sequence, receipt_number,
    amount, currency, payment_method, status,
    recorded_by_user_id, recorded_by_society_member_id
  ) values (
    p_society_id, v_number.counter_year, v_number.sequence_number,
    v_number.document_number, p_amount, v_currency, v_method, 'POSTED',
    auth.uid(), p_actor_member_id
  ) returning * into v_payment;

  for v_item in select value from jsonb_array_elements(p_allocations)
  loop
    select * into v_obligation
    from financial_obligations
    where id = (v_item->>'obligation_id')::uuid
    for update;
    if not found then raise exception 'Izabrana obaveza nije pronadjena.'; end if;
    if v_obligation.society_id <> p_society_id then
      raise exception 'Obaveza ne pripada izabranom drustvu.';
    end if;
    if v_obligation.currency <> v_currency then
      raise exception 'Uplata i obaveza moraju imati istu valutu.';
    end if;
    if v_obligation.status = 'CANCELLED' then
      raise exception 'Ponistena obaveza se ne moze platiti.';
    end if;

    v_allocation_amount := (v_item->>'amount')::numeric;
    select coalesce(sum(amount), 0) into v_paid_before
    from financial_obligation_allocations
    where obligation_id = v_obligation.id and status = 'ACTIVE';
    if v_paid_before + v_allocation_amount > v_obligation.current_amount then
      raise exception 'Raspodela prelazi preostali dug obaveze %.', v_obligation.title;
    end if;

    v_from_payment := least(v_payment_remaining, v_allocation_amount);
    if v_from_payment > 0 then
      insert into financial_obligation_allocations (
        society_id, obligation_id, source_type, payment_id,
        amount, currency, created_by_user_id, created_by_society_member_id
      ) values (
        p_society_id, v_obligation.id, 'PAYMENT', v_payment.id,
        v_from_payment, v_currency, auth.uid(), p_actor_member_id
      );
      v_payment_remaining := v_payment_remaining - v_from_payment;
    end if;

    v_from_credit := v_allocation_amount - v_from_payment;
    if v_from_credit > 0 then
      if v_from_credit > v_credit_remaining then
        raise exception 'Izabrani kredit nije dovoljan za raspodelu.';
      end if;
      if v_obligation.person_id <> p_credit_use_person_id then
        raise exception 'Kredit se moze koristiti samo za obavezu istog clana ili putnika.';
      end if;
      select sm.id into v_credit_target_member_id
      from society_members sm
      where sm.society_id = p_society_id and sm.person_id = p_credit_use_person_id
      limit 1;

      insert into financial_credit_entries (
        society_id, person_id, society_member_id, currency, amount,
        entry_type, source_payment_id, source_obligation_id,
        created_by_user_id, created_by_society_member_id, reason
      ) values (
        p_society_id, p_credit_use_person_id, v_credit_target_member_id,
        v_currency, -v_from_credit, 'EVENT_MANUAL_USE', v_payment.id,
        v_obligation.id, auth.uid(), p_actor_member_id,
        'Rucno koriscenje kredita pri uplati'
      ) returning * into v_credit_entry;

      insert into financial_obligation_allocations (
        society_id, obligation_id, source_type, credit_entry_id,
        amount, currency, created_by_user_id, created_by_society_member_id
      ) values (
        p_society_id, v_obligation.id, 'CREDIT', v_credit_entry.id,
        v_from_credit, v_currency, auth.uid(), p_actor_member_id
      );
      v_credit_remaining := v_credit_remaining - v_from_credit;
    end if;

    perform finance_refresh_obligation_status(v_obligation.id);
  end loop;

  -- Neiskorisceni deo postojeceg kredita ostaje netaknut.
  -- Samo visak nove novcane uplate postaje novi kredit.
  v_surplus := v_payment_remaining;
  if v_surplus > 0 then
    if p_credit_to_person_id is null then
      raise exception 'Izaberite clana ili putnika kome pripada visak uplate.';
    end if;
    if not exists (
      select 1 from people p where p.id = p_credit_to_person_id
    ) then
      raise exception 'Osoba za kredit nije pronadjena.';
    end if;
    select sm.id into v_credit_target_member_id
    from society_members sm
    where sm.society_id = p_society_id and sm.person_id = p_credit_to_person_id
    limit 1;

    insert into financial_credit_entries (
      society_id, person_id, society_member_id, currency, amount,
      entry_type, source_payment_id, created_by_user_id,
      created_by_society_member_id, reason
    ) values (
      p_society_id, p_credit_to_person_id, v_credit_target_member_id,
      v_currency, v_surplus, 'PAYMENT_SURPLUS', v_payment.id,
      auth.uid(), p_actor_member_id, 'Visak evidentirane uplate'
    );
  end if;

  insert into financial_audit_log (
    society_id, entity_type, entity_id, action, new_values,
    actor_user_id, actor_society_member_id, actor_role
  ) values (
    p_society_id, 'PAYMENT', v_payment.id, 'PAYMENT_RECORDED',
    jsonb_build_object(
      'receipt_number', v_payment.receipt_number,
      'amount', v_payment.amount,
      'currency', v_payment.currency,
      'payment_method', v_payment.payment_method,
      'allocations', p_allocations,
      'credit_used', v_credit_requested - v_credit_remaining,
      'new_credit', v_surplus
    ), auth.uid(), p_actor_member_id, v_role
  );

  return v_payment;
end;
$$;

create or replace function public.finance_void_payment(
  p_payment_id uuid,
  p_reason text,
  p_actor_user_id uuid,
  p_actor_member_id uuid
) returns public.financial_payments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment financial_payments;
  v_role text;
  v_allocation financial_obligation_allocations;
  v_credit financial_credit_entries;
  v_person_balance numeric(12,2);
  v_actor_person_id uuid;
begin
  select * into v_payment from financial_payments
  where id = p_payment_id for update;
  if not found then raise exception 'Uplata nije pronadjena.'; end if;
  if p_actor_user_id is not null and p_actor_user_id <> auth.uid() then
    raise exception 'Identitet korisnika nije ispravan.';
  end if;
  select member.person_id into v_actor_person_id
  from society_members member
  join people person on person.id = member.person_id
  where member.id = p_actor_member_id
    and member.society_id = v_payment.society_id
    and member.status = 'ACTIVE'
    and coalesce(member.user_id, person.user_id) = auth.uid();
  if v_actor_person_id is null or not public.permissions_has_scope(
    v_payment.society_id, p_actor_member_id, v_actor_person_id,
    'finance.void_payment', array['SOCIETY']::text[]
  ) then raise exception 'Nemate pravo ponistavanja uplate.'; end if;
  v_role := 'Ovlašćeni korisnik';
  if v_payment.status = 'VOIDED' then
    raise exception 'Uplata je vec ponistena.';
  end if;
  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'Razlog ponistavanja uplate je obavezan.';
  end if;

  -- Ako je visak ove uplate vec potrosen kroz kasnije transakcije, prvo se
  -- moraju ispraviti te kasnije transakcije da kredit ne postane negativan.
  for v_credit in
    select * from financial_credit_entries
    where source_payment_id = v_payment.id and entry_type = 'PAYMENT_SURPLUS'
    order by created_at, id
  loop
    select coalesce(sum(amount), 0) into v_person_balance
    from financial_credit_entries
    where society_id = v_credit.society_id
      and person_id = v_credit.person_id
      and currency = v_credit.currency;
    if v_person_balance < v_credit.amount then
      raise exception 'Kredit iz ove uplate je vec iskoriscen. Prvo ispravite kasnije transakcije.';
    end if;
  end loop;

  for v_allocation in
    select foa.*
    from financial_obligation_allocations foa
    left join financial_credit_entries fce on fce.id = foa.credit_entry_id
    where foa.status = 'ACTIVE'
      and (foa.payment_id = v_payment.id or fce.source_payment_id = v_payment.id)
    order by foa.created_at desc, foa.id desc
  loop
    update financial_obligation_allocations set
      status = 'REVERSED', reversed_at = now(),
      reversed_by_user_id = auth.uid(), reversal_reason = trim(p_reason)
    where id = v_allocation.id;

    if v_allocation.source_type = 'CREDIT' then
      select * into v_credit from financial_credit_entries
      where id = v_allocation.credit_entry_id;
      insert into financial_credit_entries (
        society_id, person_id, society_member_id, currency, amount,
        entry_type, source_payment_id, source_obligation_id,
        related_entry_id, created_by_user_id,
        created_by_society_member_id, reason
      ) values (
        v_credit.society_id, v_credit.person_id, v_credit.society_member_id,
        v_credit.currency, abs(v_credit.amount), 'PAYMENT_VOID_REVERSAL',
        v_payment.id, v_allocation.obligation_id, v_credit.id,
        auth.uid(), p_actor_member_id, trim(p_reason)
      );
    end if;
    perform finance_refresh_obligation_status(v_allocation.obligation_id);
  end loop;

  for v_credit in
    select * from financial_credit_entries
    where source_payment_id = v_payment.id and entry_type = 'PAYMENT_SURPLUS'
    order by created_at, id
  loop
    insert into financial_credit_entries (
      society_id, person_id, society_member_id, currency, amount,
      entry_type, source_payment_id, related_entry_id,
      created_by_user_id, created_by_society_member_id, reason
    ) values (
      v_credit.society_id, v_credit.person_id, v_credit.society_member_id,
      v_credit.currency, -v_credit.amount, 'PAYMENT_VOID_REVERSAL',
      v_payment.id, v_credit.id, auth.uid(), p_actor_member_id, trim(p_reason)
    );
  end loop;

  update financial_payments set
    status = 'VOIDED', voided_by_user_id = auth.uid(),
    voided_by_society_member_id = p_actor_member_id,
    voided_at = now(), void_reason = trim(p_reason)
  where id = v_payment.id
  returning * into v_payment;

  insert into financial_audit_log (
    society_id, entity_type, entity_id, action, new_values, reason,
    actor_user_id, actor_society_member_id, actor_role
  ) values (
    v_payment.society_id, 'PAYMENT', v_payment.id, 'PAYMENT_VOIDED',
    to_jsonb(v_payment), trim(p_reason), auth.uid(), p_actor_member_id, v_role
  );
  return v_payment;
end;
$$;

revoke all on function public.finance_next_document_number(uuid, text)
  from public, anon, authenticated;
revoke all on function public.finance_refresh_obligation_status(uuid)
  from public, anon, authenticated;
revoke all on function public.finance_record_payment(uuid, numeric, text, text, jsonb, uuid, uuid, numeric, uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.finance_void_payment(uuid, text, uuid, uuid)
  from public, anon, authenticated;

grant execute on function public.finance_record_payment(uuid, numeric, text, text, jsonb, uuid, uuid, numeric, uuid, uuid) to authenticated;
grant execute on function public.finance_void_payment(uuid, text, uuid, uuid) to authenticated;

select pg_notify('pgrst', 'reload schema');
commit;
