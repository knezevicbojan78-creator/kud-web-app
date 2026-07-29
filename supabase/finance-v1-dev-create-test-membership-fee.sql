-- FOLKLORAS DEV/V1 ONLY
-- Kreira jedno kontrolisano testno zaduzenje clanarine od 3.000 RSD za i3 p3.
-- Ne koristiti u produkciji.

do $$
declare
  v_society public.societies%rowtype;
  v_member public.society_members%rowtype;
  v_month date := date_trunc('month', current_date)::date;
  v_obligation_id uuid;
begin
  select s.* into v_society
  from public.societies s
  where s.name = 'Test' and s.status = 'ACTIVE'
  order by s.created_at
  limit 1;

  if v_society.id is null then
    raise exception 'Aktivno testno drustvo Test nije pronadjeno.';
  end if;

  select sm.* into v_member
  from public.society_members sm
  join public.people p on p.id = sm.person_id
  where sm.society_id = v_society.id
    and sm.status = 'ACTIVE'
    and lower(trim(p.first_name)) = 'i3'
    and lower(trim(p.last_name)) = 'p3'
  order by sm.created_at
  limit 1;

  if v_member.id is null then
    raise exception 'Aktivni testni clan i3 p3 nije pronadjen u drustvu Test.';
  end if;

  update public.societies
  set default_membership_fee_amount = 3000,
      finance_start_month = coalesce(finance_start_month, v_month),
      updated_at = now()
  where id = v_society.id;

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
    status,
    created_by_society_member_id
  ) values (
    v_society.id,
    'MEMBERSHIP_FEE',
    v_member.person_id,
    v_member.id,
    v_month,
    'Test članarina ' || to_char(v_month, 'MM/YYYY'),
    3000,
    3000,
    v_society.base_currency,
    (v_month + interval '1 month')::date,
    'OPEN',
    v_member.id
  )
  on conflict (society_member_id, obligation_month)
    where obligation_type = 'MEMBERSHIP_FEE'
  do nothing
  returning id into v_obligation_id;

  if v_obligation_id is null then
    select fo.id into v_obligation_id
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
    v_society.id,
    v_member.id,
    v_month,
    'CHARGED',
    v_obligation_id,
    3000,
    v_society.base_currency,
    'RECHECK',
    'DEV test zaduženje za proveru kartice Finansije'
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

  raise notice 'Test clanarina 3.000 % kreirana za i3 p3.', v_society.base_currency;
end;
$$;

select pg_notify('pgrst', 'reload schema');
