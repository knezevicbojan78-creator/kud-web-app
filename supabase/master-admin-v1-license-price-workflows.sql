-- FOLKLORAS — Master admin V1 license price settings
-- Run after supabase/master-admin-v1-license-workflows.sql.
-- DEV/V1 anon grants must be removed when final Auth/RLS is introduced.

begin;

create or replace function public.master_admin_get_license_prices()
returns jsonb
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(jsonb_agg(to_jsonb(plan_row) order by plan_row.active_member_limit), '[]'::jsonb)
  from (
    select id, code, name, monthly_price, annual_price, currency,
      active_member_limit, active_section_limit, updated_at
    from platform_license_plans
    where status = 'ACTIVE'
    order by active_member_limit
  ) plan_row;
$$;

create or replace function public.master_admin_update_license_price(
  p_license_plan_id uuid,
  p_monthly_price numeric,
  p_annual_price numeric,
  p_reason text,
  p_actor_user_id uuid default null,
  p_actor_email text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plan platform_license_plans;
  v_updated platform_license_plans;
begin
  if p_monthly_price is null or p_monthly_price <= 0 then
    raise exception 'Mesecna cena mora biti veca od nule.';
  end if;
  if p_annual_price is null or p_annual_price <= 0 then
    raise exception 'Godisnja cena mora biti veca od nule.';
  end if;
  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'Razlog promene cene je obavezan.';
  end if;

  select * into v_plan
  from platform_license_plans
  where id = p_license_plan_id and status = 'ACTIVE'
  for update;
  if not found then raise exception 'Aktivan licencni paket nije pronadjen.'; end if;

  if v_plan.currency <> 'EUR' then
    raise exception 'Promena cene je u V1 dozvoljena samo za EUR pakete.';
  end if;
  if v_plan.monthly_price = p_monthly_price and v_plan.annual_price = p_annual_price then
    raise exception 'Nove cene su iste kao postojece.';
  end if;

  update platform_license_plans
  set monthly_price = round(p_monthly_price, 2),
    annual_price = round(p_annual_price, 2),
    updated_at = now()
  where id = v_plan.id
  returning * into v_updated;

  insert into master_admin_audit_log (
    action, entity_type, entity_id, old_values, new_values, reason,
    actor_user_id, actor_email
  ) values (
    'LICENSE_PLAN_PRICE_UPDATED', 'LICENSE_PLAN', v_plan.id,
    jsonb_build_object(
      'monthly_price', v_plan.monthly_price,
      'annual_price', v_plan.annual_price,
      'currency', v_plan.currency
    ),
    jsonb_build_object(
      'monthly_price', v_updated.monthly_price,
      'annual_price', v_updated.annual_price,
      'currency', v_updated.currency
    ),
    trim(p_reason), p_actor_user_id, p_actor_email
  );

  return jsonb_build_object(
    'id', v_updated.id,
    'code', v_updated.code,
    'name', v_updated.name,
    'monthly_price', v_updated.monthly_price,
    'annual_price', v_updated.annual_price,
    'currency', v_updated.currency,
    'updated_at', v_updated.updated_at
  );
end;
$$;

revoke all on function public.master_admin_get_license_prices() from public;
revoke all on function public.master_admin_update_license_price(uuid, numeric, numeric, text, uuid, text) from public;

grant execute on function public.master_admin_get_license_prices() to anon, authenticated;
grant execute on function public.master_admin_update_license_price(uuid, numeric, numeric, text, uuid, text) to anon, authenticated;

select pg_notify('pgrst', 'reload schema');
commit;
