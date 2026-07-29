-- FOLKLORAS — AUTH V1 / MASTER ADMIN RPC PROTECTION
--
-- Primeniti nakon:
--   * auth-v1-master-admin-foundation.sql
--   * svih master-admin-v1-*.sql workflow fajlova
--
-- Postojece implementacije ostaju privatne, a javna RPC imena postaju
-- kontrolisani omotaci koji zahtevaju aktivnog Master admina i MFA (aal2).

begin;

create or replace function public.auth_assert_master_admin()
returns void
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if not public.auth_is_master_admin() then
    raise exception using
      errcode = '42501',
      message = 'Pristup je dozvoljen samo aktivnom Master adminu sa potvrđenim MFA.';
  end if;
end;
$$;

revoke all on function public.auth_assert_master_admin() from public, anon;
grant execute on function public.auth_assert_master_admin() to authenticated;

-- Prethodno primenjene funkcije preimenujemo u privatne implementacije.
alter function public.master_admin_get_society_summaries()
  rename to master_admin_get_society_summaries_impl;
alter function public.master_admin_get_dashboard()
  rename to master_admin_get_dashboard_impl;
alter function public.master_admin_get_society_detail(uuid)
  rename to master_admin_get_society_detail_impl;
alter function public.master_admin_set_society_status(uuid, text, text, uuid, text)
  rename to master_admin_set_society_status_impl;
alter function public.master_admin_get_license_management(uuid)
  rename to master_admin_get_license_management_impl;
alter function public.master_admin_grant_license(
  uuid, uuid, text, date, date, text, text, text, text, boolean, uuid, text
) rename to master_admin_grant_license_impl;
alter function public.master_admin_get_license_prices()
  rename to master_admin_get_license_prices_impl;
alter function public.master_admin_update_license_price(
  uuid, numeric, numeric, text, uuid, text
) rename to master_admin_update_license_price_impl;

revoke all on function public.master_admin_get_society_summaries_impl() from public, anon, authenticated;
revoke all on function public.master_admin_get_dashboard_impl() from public, anon, authenticated;
revoke all on function public.master_admin_get_society_detail_impl(uuid) from public, anon, authenticated;
revoke all on function public.master_admin_set_society_status_impl(uuid, text, text, uuid, text)
  from public, anon, authenticated;
revoke all on function public.master_admin_get_license_management_impl(uuid)
  from public, anon, authenticated;
revoke all on function public.master_admin_grant_license_impl(
  uuid, uuid, text, date, date, text, text, text, text, boolean, uuid, text
) from public, anon, authenticated;
revoke all on function public.master_admin_get_license_prices_impl()
  from public, anon, authenticated;
revoke all on function public.master_admin_update_license_price_impl(
  uuid, numeric, numeric, text, uuid, text
) from public, anon, authenticated;

create function public.master_admin_get_society_summaries()
returns table (
  id uuid,
  name text,
  city text,
  pib text,
  registration_number text,
  license_type text,
  status text,
  active_member_count bigint,
  inactive_member_count bigint,
  active_section_count bigint,
  inactive_section_count bigint,
  registered_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
begin
  perform public.auth_assert_master_admin();
  return query select * from public.master_admin_get_society_summaries_impl();
end;
$$;

create function public.master_admin_get_dashboard()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
begin
  perform public.auth_assert_master_admin();
  return public.master_admin_get_dashboard_impl();
end;
$$;

create function public.master_admin_get_society_detail(p_society_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
begin
  perform public.auth_assert_master_admin();
  return public.master_admin_get_society_detail_impl(p_society_id);
end;
$$;

create function public.master_admin_set_society_status(
  p_society_id uuid,
  p_new_status text,
  p_reason text,
  p_actor_user_id uuid default null,
  p_actor_email text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_actor_user_id uuid := auth.uid();
  v_actor_email text;
begin
  perform public.auth_assert_master_admin();
  select pa.email into v_actor_email
  from public.platform_admins pa
  where pa.user_id = v_actor_user_id and pa.status = 'ACTIVE';

  return public.master_admin_set_society_status_impl(
    p_society_id, p_new_status, p_reason, v_actor_user_id, v_actor_email
  );
end;
$$;

create function public.master_admin_get_license_management(p_society_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
begin
  perform public.auth_assert_master_admin();
  return public.master_admin_get_license_management_impl(p_society_id);
end;
$$;

create function public.master_admin_grant_license(
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
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_actor_user_id uuid := auth.uid();
  v_actor_email text;
begin
  perform public.auth_assert_master_admin();
  select pa.email into v_actor_email
  from public.platform_admins pa
  where pa.user_id = v_actor_user_id and pa.status = 'ACTIVE';

  return public.master_admin_grant_license_impl(
    p_society_id, p_license_plan_id, p_license_kind, p_requested_start,
    p_paid_on, p_payment_method, p_payment_reference, p_reason,
    p_internal_note, p_allow_repeat_promotion, v_actor_user_id, v_actor_email
  );
end;
$$;

create function public.master_admin_get_license_prices()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
begin
  perform public.auth_assert_master_admin();
  return public.master_admin_get_license_prices_impl();
end;
$$;

create function public.master_admin_update_license_price(
  p_license_plan_id uuid,
  p_monthly_price numeric,
  p_annual_price numeric,
  p_reason text,
  p_actor_user_id uuid default null,
  p_actor_email text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_actor_user_id uuid := auth.uid();
  v_actor_email text;
begin
  perform public.auth_assert_master_admin();
  select pa.email into v_actor_email
  from public.platform_admins pa
  where pa.user_id = v_actor_user_id and pa.status = 'ACTIVE';

  return public.master_admin_update_license_price_impl(
    p_license_plan_id, p_monthly_price, p_annual_price, p_reason,
    v_actor_user_id, v_actor_email
  );
end;
$$;

revoke all on function public.master_admin_get_society_summaries() from public, anon;
revoke all on function public.master_admin_get_dashboard() from public, anon;
revoke all on function public.master_admin_get_society_detail(uuid) from public, anon;
revoke all on function public.master_admin_set_society_status(uuid, text, text, uuid, text)
  from public, anon;
revoke all on function public.master_admin_get_license_management(uuid) from public, anon;
revoke all on function public.master_admin_grant_license(
  uuid, uuid, text, date, date, text, text, text, text, boolean, uuid, text
) from public, anon;
revoke all on function public.master_admin_get_license_prices() from public, anon;
revoke all on function public.master_admin_update_license_price(
  uuid, numeric, numeric, text, uuid, text
) from public, anon;

grant execute on function public.master_admin_get_society_summaries() to authenticated;
grant execute on function public.master_admin_get_dashboard() to authenticated;
grant execute on function public.master_admin_get_society_detail(uuid) to authenticated;
grant execute on function public.master_admin_set_society_status(uuid, text, text, uuid, text)
  to authenticated;
grant execute on function public.master_admin_get_license_management(uuid) to authenticated;
grant execute on function public.master_admin_grant_license(
  uuid, uuid, text, date, date, text, text, text, text, boolean, uuid, text
) to authenticated;
grant execute on function public.master_admin_get_license_prices() to authenticated;
grant execute on function public.master_admin_update_license_price(
  uuid, numeric, numeric, text, uuid, text
) to authenticated;

select pg_notify('pgrst', 'reload schema');

commit;
