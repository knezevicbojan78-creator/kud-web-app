-- FOLKLORAS DEV/V1
-- FINANSIJE: kontrolisane funkcije za podesavanja i mesecni obracun clanarine.
-- Pokrenuti nakon finance-v1-tables-setup.sql.

begin;

create or replace function public.finance_assert_society_role(
  p_society_id uuid,
  p_actor_member_id uuid,
  p_allowed_roles text[]
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
begin
  if p_actor_member_id is null then
    raise exception 'Nedostaje clan koji izvrsava finansijsku promenu.';
  end if;
  if auth.uid() is null then
    raise exception 'Korisnik nije prijavljen.';
  end if;

  select smf.name into v_role
  from society_member_function_assignments smfa
  join society_member_functions smf on smf.id = smfa.function_id
  join society_members sm on sm.id = smfa.society_member_id
  where smfa.society_id = p_society_id
    and smfa.society_member_id = p_actor_member_id
    and sm.society_id = p_society_id
    and sm.user_id = auth.uid()
    and sm.status = 'ACTIVE'
    and smf.name = any(p_allowed_roles)
  order by array_position(p_allowed_roles, smf.name)
  limit 1;

  if v_role is null then
    raise exception 'Nemate odgovarajuce finansijsko ovlascenje.';
  end if;

  return v_role;
end;
$$;

create or replace function public.finance_configure_society(
  p_society_id uuid,
  p_base_currency text,
  p_default_fee_amount numeric,
  p_finance_start_month date,
  p_payment_instructions text,
  p_actor_user_id uuid,
  p_actor_member_id uuid
) returns public.societies
language plpgsql
security definer
set search_path = public
as $$
declare
  v_society societies;
  v_old jsonb;
  v_role text;
  v_currency text := upper(trim(p_base_currency));
  v_start_month date := date_trunc('month', p_finance_start_month)::date;
begin
  v_role := finance_assert_society_role(
    p_society_id, p_actor_member_id, array['Predsednik']::text[]
  );

  if v_currency !~ '^[A-Z]{3}$' then
    raise exception 'Valuta mora imati troslovni ISO kod.';
  end if;
  if p_default_fee_amount is null or p_default_fee_amount < 0 then
    raise exception 'Standardna clanarina mora biti nula ili veca.';
  end if;
  if p_finance_start_month is null then
    raise exception 'Prvi obracunski mesec je obavezan.';
  end if;

  select * into v_society from societies where id = p_society_id for update;
  if not found then raise exception 'Drustvo nije pronadjeno.'; end if;

  if exists (
    select 1 from financial_obligations where society_id = p_society_id
  ) and v_society.base_currency <> v_currency then
    raise exception 'Osnovna valuta se ne moze menjati nakon prve finansijske obaveze.';
  end if;

  v_old := jsonb_build_object(
    'base_currency', v_society.base_currency,
    'default_membership_fee_amount', v_society.default_membership_fee_amount,
    'finance_start_month', v_society.finance_start_month,
    'payment_instructions', v_society.payment_instructions
  );

  update societies set
    base_currency = v_currency,
    default_membership_fee_amount = p_default_fee_amount,
    finance_start_month = v_start_month,
    payment_instructions = nullif(trim(p_payment_instructions), '')
  where id = p_society_id
  returning * into v_society;

  -- Pocetno prevodjenje postojecih polja clana u vremensku istoriju.
  -- Ne pravi dug niti pocetno stanje; samo definise pravilo od prvog
  -- obracunskog meseca aplikacije.
  update society_members sm set
    membership_fee_mode = case
      when not sm.membership_fee_required then 'EXEMPT'
      when sm.membership_fee_amount is null
        or sm.membership_fee_amount = p_default_fee_amount then 'STANDARD'
      else 'CUSTOM'
    end,
    membership_fee_amount = case
      when not sm.membership_fee_required then null
      when sm.membership_fee_amount is null then p_default_fee_amount
      else sm.membership_fee_amount
    end,
    updated_at = now()
  where sm.society_id = p_society_id;

  insert into member_fee_setting_history (
    society_id, society_member_id, fee_mode, fee_amount, currency,
    effective_from, reason, changed_by_user_id, changed_by_society_member_id
  )
  select
    sm.society_id, sm.id, sm.membership_fee_mode,
    case
      when sm.membership_fee_mode = 'EXEMPT' then null
      when sm.membership_fee_mode = 'STANDARD' then p_default_fee_amount
      else sm.membership_fee_amount
    end,
    v_currency, v_start_month, 'Pocetno podesavanje Finansija',
    auth.uid(), p_actor_member_id
  from society_members sm
  where sm.society_id = p_society_id
  on conflict (society_member_id, effective_from) do nothing;

  insert into financial_audit_log (
    society_id, entity_type, entity_id, action, old_values, new_values,
    actor_user_id, actor_society_member_id, actor_role
  ) values (
    p_society_id, 'SOCIETY_FINANCE_SETTINGS', p_society_id, 'CONFIGURED', v_old,
    jsonb_build_object(
      'base_currency', v_society.base_currency,
      'default_membership_fee_amount', v_society.default_membership_fee_amount,
      'finance_start_month', v_society.finance_start_month,
      'payment_instructions', v_society.payment_instructions
    ), auth.uid(), p_actor_member_id, v_role
  );

  return v_society;
end;
$$;

create or replace function public.finance_set_fee_calendar_month(
  p_society_id uuid,
  p_fee_month date,
  p_is_chargeable boolean,
  p_reason text,
  p_actor_user_id uuid,
  p_actor_member_id uuid
) returns public.society_fee_calendar
language plpgsql
security definer
set search_path = public
as $$
declare
  v_month date := date_trunc('month', p_fee_month)::date;
  v_row society_fee_calendar;
  v_old jsonb;
  v_role text;
begin
  v_role := finance_assert_society_role(
    p_society_id, p_actor_member_id, array['Predsednik']::text[]
  );

  if v_month <= date_trunc('month', current_date)::date then
    raise exception 'Kalendar clanarine moze se menjati samo za naredne mesece.';
  end if;
  if not p_is_chargeable and length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'Razlog nenaplativog meseca je obavezan.';
  end if;

  select to_jsonb(sfc.*) into v_old
  from society_fee_calendar sfc
  where society_id = p_society_id and fee_month = v_month;

  insert into society_fee_calendar (
    society_id, fee_month, is_chargeable, reason,
    changed_by_user_id, changed_by_society_member_id
  ) values (
    p_society_id, v_month, p_is_chargeable,
    case when p_is_chargeable then null else trim(p_reason) end,
    auth.uid(), p_actor_member_id
  )
  on conflict (society_id, fee_month) do update set
    is_chargeable = excluded.is_chargeable,
    reason = excluded.reason,
    changed_by_user_id = excluded.changed_by_user_id,
    changed_by_society_member_id = excluded.changed_by_society_member_id,
    updated_at = now()
  returning * into v_row;

  insert into financial_audit_log (
    society_id, entity_type, entity_id, action, old_values, new_values,
    reason, actor_user_id, actor_society_member_id, actor_role
  ) values (
    p_society_id, 'SOCIETY_FEE_CALENDAR', v_row.id, 'CALENDAR_CHANGED',
    v_old, to_jsonb(v_row), nullif(trim(p_reason), ''),
    auth.uid(), p_actor_member_id, v_role
  );

  return v_row;
end;
$$;

create or replace function public.finance_schedule_standard_fee(
  p_society_id uuid,
  p_new_amount numeric,
  p_reason text,
  p_actor_user_id uuid,
  p_actor_member_id uuid
) returns date
language plpgsql
security definer
set search_path = public
as $$
declare
  v_society societies;
  v_effective date := (date_trunc('month', current_date) + interval '1 month')::date;
  v_role text;
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
    'finance.settings_standard_fee', array['SOCIETY']::text[]
  ) then raise exception 'Nemate pravo promene standardne clanarine.'; end if;
  v_role := 'Ovlašćeni korisnik';
  if p_new_amount is null or p_new_amount < 0 then
    raise exception 'Novi standardni iznos nije ispravan.';
  end if;
  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'Razlog promene clanarine je obavezan.';
  end if;
  select * into v_society from societies where id = p_society_id for update;
  if not found then raise exception 'Drustvo nije pronadjeno.'; end if;

  update societies set default_membership_fee_amount = p_new_amount
  where id = p_society_id;

  insert into member_fee_setting_history (
    society_id, society_member_id, fee_mode, fee_amount, currency,
    effective_from, reason, changed_by_user_id, changed_by_society_member_id
  )
  select
    sm.society_id, sm.id, 'STANDARD', p_new_amount, v_society.base_currency,
    v_effective, trim(p_reason), auth.uid(), p_actor_member_id
  from society_members sm
  where sm.society_id = p_society_id and sm.membership_fee_mode = 'STANDARD'
  on conflict (society_member_id, effective_from) do update set
    fee_mode = excluded.fee_mode,
    fee_amount = excluded.fee_amount,
    currency = excluded.currency,
    reason = excluded.reason,
    changed_by_user_id = excluded.changed_by_user_id,
    changed_by_society_member_id = excluded.changed_by_society_member_id,
    created_at = now();

  insert into financial_audit_log (
    society_id, entity_type, entity_id, action, old_values, new_values,
    reason, actor_user_id, actor_society_member_id, actor_role
  ) values (
    p_society_id, 'STANDARD_MEMBERSHIP_FEE', p_society_id,
    'STANDARD_FEE_SCHEDULED',
    jsonb_build_object('amount', v_society.default_membership_fee_amount),
    jsonb_build_object('amount', p_new_amount, 'effective_from', v_effective),
    trim(p_reason), auth.uid(), p_actor_member_id, v_role
  );
  return v_effective;
end;
$$;

create or replace function public.finance_set_member_fee(
  p_society_member_id uuid,
  p_fee_mode text,
  p_custom_amount numeric,
  p_reason text,
  p_actor_user_id uuid,
  p_actor_member_id uuid
) returns public.member_fee_setting_history
language plpgsql
security definer
set search_path = public
as $$
declare
  v_member society_members;
  v_society societies;
  v_mode text := upper(trim(p_fee_mode));
  v_amount numeric(12,2);
  v_effective date := (date_trunc('month', current_date) + interval '1 month')::date;
  v_row member_fee_setting_history;
  v_role text;
  v_actor_person_id uuid;
begin
  select * into v_member from society_members where id = p_society_member_id for update;
  if not found then raise exception 'Clan nije pronadjen.'; end if;
  select * into v_society from societies where id = v_member.society_id;

  if p_actor_user_id is not null and p_actor_user_id <> auth.uid() then
    raise exception 'Identitet korisnika nije ispravan.';
  end if;
  select member.person_id into v_actor_person_id
  from society_members member
  join people person on person.id = member.person_id
  where member.id = p_actor_member_id
    and member.society_id = v_member.society_id
    and member.status = 'ACTIVE'
    and coalesce(member.user_id, person.user_id) = auth.uid();
  if v_actor_person_id is null or not public.permissions_has_scope(
    v_member.society_id, p_actor_member_id, v_actor_person_id,
    'finance.settings_member_fee', array['SOCIETY']::text[]
  ) then raise exception 'Nemate pravo promene clanarine clana.'; end if;
  v_role := 'Ovlašćeni korisnik';
  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'Razlog promene clanarine je obavezan.';
  end if;
  if v_mode not in ('STANDARD', 'CUSTOM', 'EXEMPT') then
    raise exception 'Nepoznat rezim clanarine.';
  end if;

  v_amount := case
    when v_mode = 'STANDARD' then v_society.default_membership_fee_amount
    when v_mode = 'CUSTOM' then p_custom_amount
    else null
  end;
  if v_mode <> 'EXEMPT' and (v_amount is null or v_amount < 0) then
    raise exception 'Iznos clanarine nije ispravan.';
  end if;

  insert into member_fee_setting_history (
    society_id, society_member_id, fee_mode, fee_amount, currency,
    effective_from, reason, changed_by_user_id, changed_by_society_member_id
  ) values (
    v_member.society_id, v_member.id, v_mode, v_amount,
    v_society.base_currency, v_effective, trim(p_reason),
    auth.uid(), p_actor_member_id
  )
  on conflict (society_member_id, effective_from) do update set
    fee_mode = excluded.fee_mode,
    fee_amount = excluded.fee_amount,
    currency = excluded.currency,
    reason = excluded.reason,
    changed_by_user_id = excluded.changed_by_user_id,
    changed_by_society_member_id = excluded.changed_by_society_member_id,
    created_at = now()
  returning * into v_row;

  -- Trenutna kolona oznacava izabrani rezim za dalje upravljanje, dok se
  -- stvarni obracun za konkretan mesec uvek cita iz effective history reda.
  update society_members set
    membership_fee_mode = v_mode,
    membership_fee_required = (v_mode <> 'EXEMPT'),
    membership_fee_amount = v_amount,
    updated_at = now()
  where id = v_member.id;

  insert into financial_audit_log (
    society_id, entity_type, entity_id, action, new_values, reason,
    actor_user_id, actor_society_member_id, actor_role
  ) values (
    v_member.society_id, 'MEMBER_FEE_SETTING', v_row.id, 'FEE_SETTING_SCHEDULED',
    to_jsonb(v_row), trim(p_reason), auth.uid(), p_actor_member_id, v_role
  );

  return v_row;
end;
$$;

create or replace function public.finance_grant_initial_free_months(
  p_society_member_id uuid,
  p_granted_months smallint,
  p_actor_user_id uuid,
  p_actor_member_id uuid
) returns public.member_fee_grants
language plpgsql
security definer
set search_path = public
as $$
declare
  v_member society_members;
  v_effective date;
  v_row member_fee_grants;
  v_role text;
begin
  if p_granted_months not between 1 and 3 then
    raise exception 'Gratis period moze biti 1, 2 ili 3 meseca.';
  end if;
  select * into v_member from society_members where id = p_society_member_id for update;
  if not found then raise exception 'Clan nije pronadjen.'; end if;
  v_role := finance_assert_society_role(
    v_member.society_id, p_actor_member_id, array['Predsednik']::text[]
  );
  if exists (
    select 1 from member_status_history
    where society_member_id = v_member.id and status = 'INACTIVE'
  ) then
    raise exception 'Gratis period nije dozvoljen pri reaktivaciji.';
  end if;
  if exists (select 1 from member_fee_grants where society_member_id = v_member.id) then
    raise exception 'Gratis period je vec dodeljen ovom clanu.';
  end if;

  v_effective := case
    when extract(day from v_member.start_date) <= 15
      then date_trunc('month', v_member.start_date)::date
    else (date_trunc('month', v_member.start_date) + interval '1 month')::date
  end;

  insert into member_fee_grants (
    society_id, society_member_id, granted_months, effective_from,
    reason, granted_by_user_id, granted_by_society_member_id
  ) values (
    v_member.society_id, v_member.id, p_granted_months, v_effective,
    'Pocetni gratis period', auth.uid(), p_actor_member_id
  ) returning * into v_row;

  insert into financial_audit_log (
    society_id, entity_type, entity_id, action, new_values,
    actor_user_id, actor_society_member_id, actor_role
  ) values (
    v_member.society_id, 'MEMBER_FEE_GRANT', v_row.id, 'FREE_MONTHS_GRANTED',
    to_jsonb(v_row), auth.uid(), p_actor_member_id, v_role
  );
  return v_row;
end;
$$;

create or replace function public.finance_generate_membership_fees(
  p_society_id uuid,
  p_assessment_month date default current_date,
  p_only_member_id uuid default null,
  p_process_source text default 'AUTOMATIC',
  p_initiated_by_user_id uuid default null
) returns table (
  society_member_id uuid,
  result text,
  obligation_id uuid,
  assessed_amount numeric,
  credit_applied numeric
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_society societies;
  v_member society_members;
  v_month date := date_trunc('month', p_assessment_month)::date;
  v_month_end date := (date_trunc('month', p_assessment_month) + interval '1 month - 1 day')::date;
  v_cutoff date := (date_trunc('month', p_assessment_month) + interval '14 days')::date;
  v_chargeable boolean;
  v_mode text;
  v_amount numeric(12,2);
  v_currency text;
  v_status text;
  v_grant member_fee_grants;
  v_used_free integer;
  v_obligation financial_obligations;
  v_credit numeric(12,2);
  v_apply numeric(12,2);
  v_credit_entry financial_credit_entries;
  v_result text;
begin
  select * into v_society from societies where id = p_society_id;
  if not found then raise exception 'Drustvo nije pronadjeno.'; end if;
  if p_process_source not in ('AUTOMATIC', 'MEMBER_CREATE', 'REACTIVATION', 'RECHECK') then
    raise exception 'Nepoznat izvor obracuna.';
  end if;

  for v_member in
    select sm.* from society_members sm
    where sm.society_id = p_society_id
      and (p_only_member_id is null or sm.id = p_only_member_id)
    order by sm.created_at, sm.id
  loop
    if exists (
      select 1 from membership_fee_assessments
      where membership_fee_assessments.society_member_id = v_member.id
        and assessment_month = v_month
    ) then
      select mfa.result, mfa.obligation_id, mfa.assessed_amount
      into v_result, v_obligation.id, v_amount
      from membership_fee_assessments mfa
      where mfa.society_member_id = v_member.id and mfa.assessment_month = v_month;
      society_member_id := v_member.id;
      result := v_result;
      obligation_id := v_obligation.id;
      assessed_amount := v_amount;
      credit_applied := 0;
      return next;
      continue;
    end if;

    if v_society.finance_start_month is null or v_month < v_society.finance_start_month then
      v_result := 'BEFORE_FINANCE_START';
    else
      v_chargeable := finance_membership_month_is_chargeable(p_society_id, v_month);
      if not v_chargeable then
        v_result := 'SOCIETY_FREE_MONTH';
      elsif v_member.start_date is null or v_member.start_date > v_month_end then
        v_result := 'INACTIVE';
      elsif date_trunc('month', v_member.start_date)::date = v_month
        and v_member.start_date > v_cutoff then
        v_result := 'JOINED_AFTER_CUTOFF';
      else
        select msh.status into v_status
        from member_status_history msh
        where msh.society_member_id = v_member.id
          and msh.effective_date <= v_cutoff
        order by msh.effective_date desc, msh.created_at desc
        limit 1;
        v_status := coalesce(v_status, v_member.status);
        if v_status <> 'ACTIVE' then
          v_result := 'INACTIVE';
        else
          select mfs.fee_mode, mfs.fee_amount, mfs.currency
          into v_mode, v_amount, v_currency
          from member_fee_setting_history mfs
          where mfs.society_member_id = v_member.id
            and mfs.effective_from <= v_month
          order by mfs.effective_from desc, mfs.created_at desc
          limit 1;
          v_mode := coalesce(v_mode, v_member.membership_fee_mode,
            case when v_member.membership_fee_required then 'CUSTOM' else 'EXEMPT' end);
          v_currency := coalesce(v_currency, v_society.base_currency);
          v_amount := case
            when v_mode = 'STANDARD' then coalesce(v_amount, v_society.default_membership_fee_amount)
            when v_mode = 'CUSTOM' then coalesce(v_amount, v_member.membership_fee_amount)
            else null
          end;

          if v_mode = 'EXEMPT' then
            v_result := 'EXEMPT';
          else
            select * into v_grant from member_fee_grants mfg
            where mfg.society_member_id = v_member.id
              and mfg.effective_from <= v_month;
            if found then
              select count(*) into v_used_free
              from membership_fee_assessments mfa
              where mfa.society_member_id = v_member.id
                and mfa.result = 'INDIVIDUAL_FREE_MONTH';
            else
              v_used_free := 0;
            end if;

            if v_grant.id is not null and v_used_free < v_grant.granted_months then
              v_result := 'INDIVIDUAL_FREE_MONTH';
            else
              if v_amount is null or v_amount < 0 then
                raise exception 'Clan % nema ispravno podesenu clanarinu.', v_member.id;
              end if;
              insert into financial_obligations (
                society_id, obligation_type, person_id, society_member_id,
                obligation_month, title, original_amount, current_amount,
                currency, due_date, status, created_by_user_id
              ) values (
                p_society_id, 'MEMBERSHIP_FEE', v_member.person_id, v_member.id,
                v_month, 'Clanarina ' || to_char(v_month, 'MM/YYYY'),
                v_amount, v_amount, v_currency,
                (v_month + interval '1 month')::date, 'OPEN', p_initiated_by_user_id
              ) returning * into v_obligation;

              select coalesce(sum(fce.amount), 0) into v_credit
              from financial_credit_entries fce
              where fce.society_id = p_society_id
                and fce.person_id = v_member.person_id
                and fce.currency = v_currency;
              v_apply := least(greatest(v_credit, 0), v_amount);
              if v_apply > 0 then
                insert into financial_credit_entries (
                  society_id, person_id, society_member_id, currency, amount,
                  entry_type, source_obligation_id, created_by_user_id,
                  reason
                ) values (
                  p_society_id, v_member.person_id, v_member.id, v_currency,
                  -v_apply, 'MEMBERSHIP_AUTO_USE', v_obligation.id,
                  p_initiated_by_user_id, 'Automatsko koriscenje kredita za clanarinu'
                ) returning * into v_credit_entry;

                insert into financial_obligation_allocations (
                  society_id, obligation_id, source_type, credit_entry_id,
                  amount, currency, created_by_user_id
                ) values (
                  p_society_id, v_obligation.id, 'CREDIT', v_credit_entry.id,
                  v_apply, v_currency, p_initiated_by_user_id
                );

                update financial_obligations set
                  status = case when v_apply >= v_amount then 'PAID' else 'PARTIALLY_PAID' end,
                  updated_at = now()
                where id = v_obligation.id
                returning * into v_obligation;
              else
                v_apply := 0;
              end if;
              v_result := 'CHARGED';
            end if;
          end if;
        end if;
      end if;
    end if;

    insert into membership_fee_assessments (
      society_id, society_member_id, assessment_month, result,
      obligation_id, member_fee_grant_id, assessed_amount, currency,
      process_source, initiated_by_user_id
    ) values (
      p_society_id, v_member.id, v_month, v_result,
      case when v_result = 'CHARGED' then v_obligation.id else null end,
      case when v_result = 'INDIVIDUAL_FREE_MONTH' then v_grant.id else null end,
      case when v_result = 'CHARGED' then v_amount else null end,
      case when v_result = 'CHARGED' then v_currency else null end,
      p_process_source, p_initiated_by_user_id
    );

    society_member_id := v_member.id;
    result := v_result;
    obligation_id := case when v_result = 'CHARGED' then v_obligation.id else null end;
    assessed_amount := case when v_result = 'CHARGED' then v_amount else null end;
    credit_applied := case when v_result = 'CHARGED' then coalesce(v_apply, 0) else 0 end;
    return next;

    v_grant := null;
    v_obligation := null;
    v_credit_entry := null;
    v_apply := 0;
    v_status := null;
    v_mode := null;
    v_amount := null;
    v_currency := null;
  end loop;
end;
$$;

create or replace function public.finance_generate_all_membership_fees(
  p_assessment_month date default current_date
) returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_society record;
  v_count integer := 0;
  v_rows integer;
begin
  for v_society in
    select id from societies
    where finance_start_month is not null
      and finance_start_month <= date_trunc('month', p_assessment_month)::date
  loop
    select count(*) into v_rows
    from finance_generate_membership_fees(v_society.id, p_assessment_month);
    v_count := v_count + v_rows;
  end loop;
  return v_count;
end;
$$;

revoke all on function public.finance_assert_society_role(uuid, uuid, text[]) from public;
revoke all on function public.finance_configure_society(uuid, text, numeric, date, text, uuid, uuid) from public;
revoke all on function public.finance_set_fee_calendar_month(uuid, date, boolean, text, uuid, uuid) from public;
revoke all on function public.finance_schedule_standard_fee(uuid, numeric, text, uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.finance_set_member_fee(uuid, text, numeric, text, uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.finance_grant_initial_free_months(uuid, smallint, uuid, uuid) from public;
revoke all on function public.finance_generate_membership_fees(uuid, date, uuid, text, uuid) from public;
revoke all on function public.finance_generate_all_membership_fees(date) from public;

grant execute on function public.finance_configure_society(uuid, text, numeric, date, text, uuid, uuid) to authenticated;
grant execute on function public.finance_set_fee_calendar_month(uuid, date, boolean, text, uuid, uuid) to authenticated;
grant execute on function public.finance_set_member_fee(uuid, text, numeric, text, uuid, uuid) to authenticated;
grant execute on function public.finance_grant_initial_free_months(uuid, smallint, uuid, uuid) to authenticated;

-- Obracun ne dobija direktan klijentski execute. Pozivace ga server/cron ili
-- kontrolisana funkcija nakon kreiranja/reaktivacije clana.

select pg_notify('pgrst', 'reload schema');
commit;
