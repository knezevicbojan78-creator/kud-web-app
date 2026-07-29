-- FOLKLORAS — AUTH V1 / LOGIN DESTINATION
-- Centralna odluka gde prijavljeni korisnik nastavlja posle logina.

begin;

create or replace function public.auth_get_login_destination()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_aal text := coalesce(auth.jwt() ->> 'aal', 'aal1');
  v_onboarding public.user_onboarding_state;
begin
  if v_user_id is null then
    raise exception 'Prijava je obavezna.';
  end if;

  if exists (
    select 1
    from public.platform_admins pa
    where pa.user_id = v_user_id and pa.status = 'ACTIVE'
  ) then
    return jsonb_build_object(
      'account_type', 'MASTER_ADMIN',
      'destination', case when v_aal = 'aal2' then '/dashboard' else '/auth/mfa' end
    );
  end if;

  select uos.* into v_onboarding
  from public.user_onboarding_state uos
  join public."PresidentReg" pr on pr.id = uos.president_reg_id
  where uos.user_id = v_user_id
    and pr."presidentUserId" = v_user_id
    and pr."StatReg" = 'APPROVED'
  order by uos.created_at desc
  limit 1;

  if found then
    return jsonb_build_object(
      'account_type', 'PRESIDENT',
      'society_id', v_onboarding.society_id,
      'onboarding_completed', v_onboarding.completed_at is not null,
      'destination', case
        when v_onboarding.completed_at is null
          then '/auth/president-onboarding'
        else '/dashboard'
      end
    );
  end if;

  raise exception using
    errcode = '42501',
    message = 'Nalog još nema aktivan pristup aplikaciji.';
end;
$$;

revoke all on function public.auth_get_login_destination()
  from public, anon;
grant execute on function public.auth_get_login_destination()
  to authenticated;

select pg_notify('pgrst', 'reload schema');

commit;
