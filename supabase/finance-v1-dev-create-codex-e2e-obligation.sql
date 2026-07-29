-- FOLKLORAS DEV/TEST ONLY
-- Pravi jedno idempotentno probno zaduzenje samo za jasno oznacenog CODEX E2E clana.
-- Ne koristiti u produkciji.

do $$
declare
  v_email constant text := 'codex.e2e.member.001@example.com';
  v_month constant date := date '2026-07-01';
  v_member public.society_members%rowtype;
  v_currency text;
  v_obligation_id uuid;
begin
  select sm.*
  into v_member
  from public.society_members sm
  join public.people p on p.id = sm.person_id
  join public.societies s on s.id = sm.society_id
  where lower(trim(p.email)) = v_email
    and sm.status = 'ACTIVE'
    and s.status = 'ACTIVE'
  order by sm.created_at
  limit 1;

  if v_member.id is null then
    raise exception 'Aktivni probni clan % nije pronadjen.', v_email;
  end if;

  select s.base_currency
  into v_currency
  from public.societies s
  where s.id = v_member.society_id;

  insert into public.financial_obligations (
    society_id,
    obligation_type,
    person_id,
    society_member_id,
    obligation_month,
    title,
    original_amount,
    current_amount,
    currency,
    due_date,
    status
  ) values (
    v_member.society_id,
    'MEMBERSHIP_FEE',
    v_member.person_id,
    v_member.id,
    v_month,
    'CODEX E2E test članarina 07/2026',
    100,
    100,
    v_currency,
    date '2026-07-15',
    'OPEN'
  )
  on conflict (society_member_id, obligation_month)
    where obligation_type = 'MEMBERSHIP_FEE'
  do nothing
  returning id into v_obligation_id;

  if v_obligation_id is null then
    select fo.id
    into v_obligation_id
    from public.financial_obligations fo
    where fo.society_member_id = v_member.id
      and fo.obligation_type = 'MEMBERSHIP_FEE'
      and fo.obligation_month = v_month;
  end if;

  insert into public.membership_fee_assessments (
    society_id,
    society_member_id,
    assessment_month,
    result,
    obligation_id,
    assessed_amount,
    currency,
    process_source,
    note
  ) values (
    v_member.society_id,
    v_member.id,
    v_month,
    'CHARGED',
    v_obligation_id,
    100,
    v_currency,
    'RECHECK',
    'CODEX E2E kontrolisano zaduženje za funkcionalni test Finansija'
  )
  on conflict (society_member_id, assessment_month)
  do update set
    result = excluded.result,
    obligation_id = excluded.obligation_id,
    member_fee_grant_id = null,
    assessed_amount = excluded.assessed_amount,
    currency = excluded.currency,
    process_source = excluded.process_source,
    processed_at = now(),
    note = excluded.note;

  raise notice 'CODEX E2E zaduzenje spremno. obligation_id=%', v_obligation_id;
end;
$$;
