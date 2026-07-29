-- FOLKLORAS — Master admin V1 license packages and assignment workflows
-- Run after master-admin-v1-setup.sql and master-admin-v1-society-detail-workflows.sql.
-- DEV/V1 anon grants must be removed when final Auth/RLS is introduced.

begin;

insert into public.platform_license_plans (
  code, name, description, monthly_price, annual_price, currency,
  active_member_limit, active_section_limit, status
) values
  ('SMALL', 'Malo društvo', 'Do 100 aktivnih članova i 6 aktivnih sekcija.', 8, 80, 'EUR', 100, 6, 'ACTIVE'),
  ('STANDARD', 'Standard', 'Do 250 aktivnih članova i 12 aktivnih sekcija.', 15, 150, 'EUR', 250, 12, 'ACTIVE'),
  ('LARGE', 'Veliko društvo', 'Do 500 aktivnih članova i 20 aktivnih sekcija.', 25, 250, 'EUR', 500, 20, 'ACTIVE')
on conflict (code) do update set
  name = excluded.name,
  description = excluded.description,
  monthly_price = excluded.monthly_price,
  annual_price = excluded.annual_price,
  currency = excluded.currency,
  active_member_limit = excluded.active_member_limit,
  active_section_limit = excluded.active_section_limit,
  status = 'ACTIVE',
  updated_at = now();

create or replace function public.master_admin_get_license_management(
  p_society_id uuid
) returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_result jsonb;
begin
  if not exists (select 1 from societies where id = p_society_id) then
    raise exception 'Drustvo nije pronadjeno.';
  end if;

  select jsonb_build_object(
    'plans', coalesce((
      select jsonb_agg(to_jsonb(plan_row) order by plan_row.active_member_limit)
      from (
        select id, code, name, description, monthly_price, annual_price, currency,
          active_member_limit, active_section_limit
        from platform_license_plans
        where status = 'ACTIVE'
        order by active_member_limit
      ) plan_row
    ), '[]'::jsonb),
    'periods', coalesce((
      select jsonb_agg(to_jsonb(period_row) order by period_row.valid_from desc, period_row.created_at desc)
      from (
        select slp.id, slp.plan_name_snapshot as plan_name, slp.source,
          slp.billing_cycle, slp.duration_months, slp.valid_from, slp.valid_until,
          slp.price_snapshot, slp.currency_snapshot,
          slp.active_member_limit_snapshot as member_limit,
          slp.active_section_limit_snapshot as section_limit,
          slp.promotion_reason, slp.internal_note, slp.created_at,
          plp.paid_on, plp.payment_method, plp.payment_reference, plp.status as payment_status
        from society_license_periods slp
        left join platform_license_payments plp on plp.id = slp.payment_id
        where slp.society_id = p_society_id
        order by slp.valid_from desc, slp.created_at desc
        limit 50
      ) period_row
    ), '[]'::jsonb),
    'promotion_used', exists (
      select 1 from society_license_periods
      where society_id = p_society_id and source = 'PROMOTIONAL'
    )
  ) into v_result;

  return v_result;
end;
$$;

create or replace function public.master_admin_grant_license(
  p_society_id uuid,
  p_license_plan_id uuid,
  p_license_kind text,
  p_requested_start date default current_date,
  p_paid_on date default null,
  p_payment_method text default null,
  p_payment_reference text default null,
  p_reason text default null,
  p_internal_note text default null,
  p_allow_repeat_promotion boolean default false,
  p_actor_user_id uuid default null,
  p_actor_email text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_society societies;
  v_plan platform_license_plans;
  v_payment platform_license_payments;
  v_period society_license_periods;
  v_active_suspension society_suspensions;
  v_member_count integer;
  v_section_count integer;
  v_duration integer;
  v_cycle text;
  v_source text;
  v_price numeric(12,2);
  v_start date;
  v_end date;
  v_latest_end date;
begin
  if p_license_kind not in ('MONTHLY', 'ANNUAL', 'PROMOTIONAL_3', 'PROMOTIONAL_6', 'PROMOTIONAL_12') then
    raise exception 'Vrsta licence nije dozvoljena.';
  end if;

  select * into v_society from societies where id = p_society_id for update;
  if not found then raise exception 'Drustvo nije pronadjeno.'; end if;

  select * into v_plan
  from platform_license_plans
  where id = p_license_plan_id and status = 'ACTIVE';
  if not found then raise exception 'Aktivan licencni paket nije pronadjen.'; end if;

  select count(*) into v_member_count
  from society_members where society_id = p_society_id and status = 'ACTIVE';
  select count(*) into v_section_count
  from sections where society_id = p_society_id and status = 'ACTIVE';

  if v_plan.active_member_limit is not null and v_member_count > v_plan.active_member_limit then
    raise exception 'Drustvo ima % aktivnih clanova, a paket dozvoljava najvise %.',
      v_member_count, v_plan.active_member_limit;
  end if;
  if v_plan.active_section_limit is not null and v_section_count > v_plan.active_section_limit then
    raise exception 'Drustvo ima % aktivnih sekcija, a paket dozvoljava najvise %.',
      v_section_count, v_plan.active_section_limit;
  end if;

  if p_license_kind = 'MONTHLY' then
    v_duration := 1; v_cycle := 'MONTHLY'; v_source := 'PAID'; v_price := v_plan.monthly_price;
  elsif p_license_kind = 'ANNUAL' then
    v_duration := 12; v_cycle := 'ANNUAL'; v_source := 'PAID'; v_price := v_plan.annual_price;
  else
    v_duration := replace(p_license_kind, 'PROMOTIONAL_', '')::integer;
    v_cycle := 'PROMOTIONAL'; v_source := 'PROMOTIONAL'; v_price := 0;
  end if;

  if v_source = 'PAID' then
    if v_price is null then raise exception 'Cena izabranog perioda nije definisana.'; end if;
    if p_paid_on is null then raise exception 'Datum uplate je obavezan.'; end if;
    if p_paid_on > current_date then raise exception 'Datum uplate ne moze biti u buducnosti.'; end if;
    if p_payment_method not in ('BANK_TRANSFER', 'CASH', 'OTHER') then
      raise exception 'Nacin uplate nije dozvoljen.';
    end if;
  else
    if length(trim(coalesce(p_reason, ''))) = 0 then
      raise exception 'Razlog promotivne licence je obavezan.';
    end if;
    if not p_allow_repeat_promotion and exists (
      select 1 from society_license_periods
      where society_id = p_society_id and source = 'PROMOTIONAL'
    ) then
      raise exception 'Drustvo je vec koristilo promotivnu licencu.';
    end if;
  end if;

  select max(valid_until) into v_latest_end
  from society_license_periods
  where society_id = p_society_id;

  v_start := coalesce(p_requested_start, case when v_source = 'PAID' then p_paid_on else current_date end);
  if v_latest_end is not null and v_latest_end >= v_start then
    v_start := v_latest_end + 1;
  end if;
  v_end := (v_start + make_interval(months => v_duration) - interval '1 day')::date;

  if v_source = 'PAID' then
    insert into platform_license_payments (
      society_id, license_plan_id, billing_cycle, amount, currency, paid_on,
      payment_method, payment_reference, note, recorded_by_user_id
    ) values (
      p_society_id, v_plan.id, v_cycle, v_price, v_plan.currency, p_paid_on,
      p_payment_method, nullif(trim(coalesce(p_payment_reference, '')), ''),
      nullif(trim(coalesce(p_internal_note, '')), ''), p_actor_user_id
    ) returning * into v_payment;
  end if;

  insert into society_license_periods (
    society_id, license_plan_id, source, billing_cycle, duration_months,
    valid_from, valid_until, plan_name_snapshot, price_snapshot, currency_snapshot,
    active_member_limit_snapshot, active_section_limit_snapshot, payment_id,
    promotion_reason, internal_note, granted_by_user_id
  ) values (
    p_society_id, v_plan.id, v_source, v_cycle, v_duration,
    v_start, v_end, v_plan.name, v_price, v_plan.currency,
    v_plan.active_member_limit, v_plan.active_section_limit,
    case when v_source = 'PAID' then v_payment.id else null end,
    case when v_source = 'PROMOTIONAL' then trim(p_reason) else null end,
    nullif(trim(coalesce(p_internal_note, '')), ''), p_actor_user_id
  ) returning * into v_period;

  update societies
  set license_type = v_plan.name, license_price = v_price
  where id = p_society_id;

  if v_source = 'PAID' then
    insert into master_admin_audit_log (
      action, entity_type, entity_id, society_id, new_values, reason,
      actor_user_id, actor_email
    ) values (
      'LICENSE_PAYMENT_RECORDED', 'LICENSE_PAYMENT', v_payment.id, p_society_id,
      jsonb_build_object('amount', v_price, 'currency', v_plan.currency, 'paid_on', p_paid_on),
      nullif(trim(coalesce(p_internal_note, '')), ''), p_actor_user_id, p_actor_email
    );
  end if;

  insert into master_admin_audit_log (
    action, entity_type, entity_id, society_id, new_values, reason,
    actor_user_id, actor_email
  ) values (
    case when v_source = 'PROMOTIONAL' then 'PROMOTIONAL_LICENSE_GRANTED' else 'LICENSE_GRANTED' end,
    'LICENSE_PERIOD', v_period.id, p_society_id,
    jsonb_build_object(
      'plan', v_plan.name, 'source', v_source, 'billing_cycle', v_cycle,
      'valid_from', v_start, 'valid_until', v_end, 'price', v_price,
      'currency', v_plan.currency
    ),
    case when v_source = 'PROMOTIONAL' then trim(p_reason)
      else nullif(trim(coalesce(p_internal_note, '')), '') end,
    p_actor_user_id, p_actor_email
  );

  -- Nova licenca automatski podize samo suspenziju nastalu istekom licence.
  if v_start <= current_date and v_end >= current_date then
    select * into v_active_suspension
    from society_suspensions
    where society_id = p_society_id
      and lifted_at is null
      and reason_type = 'LICENSE_EXPIRED'
    for update;

    if found then
      update society_suspensions
      set lifted_at = now(), lifted_by_user_id = p_actor_user_id,
        lift_reason = 'Licenca je aktivirana.',
        related_reactivation_payment_id = case when v_source = 'PAID' then v_payment.id else null end
      where id = v_active_suspension.id;

      update societies set status = 'ACTIVE' where id = p_society_id;

      insert into master_admin_audit_log (
        action, entity_type, entity_id, society_id, old_values, new_values,
        reason, actor_user_id, actor_email
      ) values (
        'SOCIETY_REACTIVATED', 'SOCIETY', p_society_id, p_society_id,
        jsonb_build_object('status', 'SUSPENDED'),
        jsonb_build_object('status', 'ACTIVE', 'license_period_id', v_period.id),
        'Licenca je aktivirana.', p_actor_user_id, p_actor_email
      );
    end if;
  end if;

  return jsonb_build_object(
    'license_period_id', v_period.id,
    'payment_id', case when v_source = 'PAID' then v_payment.id else null end,
    'valid_from', v_start,
    'valid_until', v_end,
    'plan_name', v_plan.name,
    'source', v_source
  );
end;
$$;

revoke all on function public.master_admin_get_license_management(uuid) from public;
revoke all on function public.master_admin_grant_license(
  uuid, uuid, text, date, date, text, text, text, text, boolean, uuid, text
) from public;

grant execute on function public.master_admin_get_license_management(uuid) to anon, authenticated;
grant execute on function public.master_admin_grant_license(
  uuid, uuid, text, date, date, text, text, text, text, boolean, uuid, text
) to anon, authenticated;

select pg_notify('pgrst', 'reload schema');
commit;
