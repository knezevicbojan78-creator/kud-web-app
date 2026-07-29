-- FOLKLORAS — AUTH V1 / PRESIDENT DASHBOARD
-- Predsednik dobija samo zbirne podatke svog aktivnog drustva.

begin;

create or replace function public.auth_get_president_dashboard()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_society_id uuid;
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception 'Prijava je obavezna.';
  end if;

  select uos.society_id
  into v_society_id
  from public.user_onboarding_state uos
  join public."PresidentReg" pr on pr.id = uos.president_reg_id
  where uos.user_id = v_user_id
    and uos.completed_at is not null
    and pr."presidentUserId" = v_user_id
    and pr."StatReg" = 'APPROVED'
  order by uos.completed_at desc
  limit 1;

  if v_society_id is null then
    raise exception 'Aktivno predsednicko drustvo nije pronadjeno.';
  end if;

  select jsonb_build_object(
    'account_type', 'PRESIDENT',
    'society_id', s.id,
    'society_name', s.name,
    'society_status', s.status,
    'license_type', s.license_type,
    'active_member_count', (
      select count(*)
      from public.society_members sm
      where sm.society_id = s.id and sm.status = 'ACTIVE'
    ),
    'active_section_count', (
      select count(*)
      from public.sections sec
      where sec.society_id = s.id and sec.status = 'ACTIVE'
    ),
    'current_license_valid_until', (
      select slp.valid_until
      from public.society_license_periods slp
      where slp.society_id = s.id
        and slp.valid_from <= current_date
        and slp.valid_until >= current_date
      order by slp.valid_until desc
      limit 1
    )
  )
  into v_result
  from public.societies s
  where s.id = v_society_id
    and s.status = 'ACTIVE';

  if v_result is null then
    raise exception 'Drustvo nije aktivno.';
  end if;

  return v_result;
end;
$$;

create or replace function public.auth_get_president_members_page()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_society_id uuid;
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception 'Prijava je obavezna.';
  end if;

  select uos.society_id
  into v_society_id
  from public.user_onboarding_state uos
  join public."PresidentReg" pr on pr.id = uos.president_reg_id
  where uos.user_id = v_user_id
    and uos.completed_at is not null
    and pr."presidentUserId" = v_user_id
    and pr."StatReg" = 'APPROVED'
  order by uos.completed_at desc
  limit 1;

  if v_society_id is null then
    raise exception 'Aktivno predsednicko drustvo nije pronadjeno.';
  end if;

  select jsonb_build_object(
    'society', to_jsonb(s),
    'functions', coalesce((
      select jsonb_agg(to_jsonb(smf) order by smf.sort_order)
      from public.society_member_functions smf
      where smf.society_id = s.id and smf.is_active
    ), '[]'::jsonb),
    'sections', coalesce((
      select jsonb_agg(to_jsonb(sec) order by sec.name)
      from public.sections sec
      where sec.society_id = s.id and sec.status = 'ACTIVE'
    ), '[]'::jsonb),
    'members', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', sm.id,
          'person_id', sm.person_id,
          'first_name', p.first_name,
          'last_name', p.last_name,
          'birth_date', p.birth_date,
          'email', p.email,
          'phone', p.phone,
          'status', sm.status,
          'start_date', sm.start_date
        )
        order by sm.created_at desc
      )
      from public.society_members sm
      join public.people p on p.id = sm.person_id
      where sm.society_id = s.id
    ), '[]'::jsonb)
  )
  into v_result
  from public.societies s
  where s.id = v_society_id and s.status = 'ACTIVE';

  if v_result is null then
    raise exception 'Drustvo nije aktivno.';
  end if;

  return v_result;
end;
$$;

create or replace function public.auth_get_president_member_detail(
  p_society_member_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_society_id uuid;
  v_result jsonb;
begin
  select uos.society_id
  into v_society_id
  from public.user_onboarding_state uos
  join public."PresidentReg" pr on pr.id = uos.president_reg_id
  where uos.user_id = v_user_id
    and uos.completed_at is not null
    and pr."presidentUserId" = v_user_id
    and pr."StatReg" = 'APPROVED'
  order by uos.completed_at desc
  limit 1;

  if v_society_id is null then
    raise exception 'Predsednicki pristup nije pronadjen.';
  end if;

  select jsonb_build_object(
    'member', to_jsonb(sm),
    'person', to_jsonb(p),
    'guardians', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'link', to_jsonb(pg),
          'person', to_jsonb(gp)
        )
        order by pg.is_primary desc, pg.created_at
      )
      from public.person_guardians pg
      join public.people gp on gp.id = pg.guardian_person_id
      where pg.child_person_id = p.id
    ), '[]'::jsonb),
    'function_ids', coalesce((
      select jsonb_agg(smfa.function_id)
      from public.society_member_function_assignments smfa
      join public.society_member_functions smf on smf.id = smfa.function_id
      where smfa.society_member_id = sm.id
        and smf.society_id = v_society_id
    ), '[]'::jsonb),
    'section_ids', coalesce((
      select jsonb_agg(ms.section_id)
      from public.member_sections ms
      where ms.society_member_id = sm.id
        and ms.society_id = v_society_id
        and ms.status = 'ACTIVE'
    ), '[]'::jsonb)
  )
  into v_result
  from public.society_members sm
  join public.people p on p.id = sm.person_id
  where sm.id = p_society_member_id
    and sm.society_id = v_society_id;

  if v_result is null then
    raise exception 'Clan nije pronadjen u drustvu prijavljenog predsednika.';
  end if;

  return v_result;
end;
$$;

revoke all on function public.auth_get_president_dashboard()
  from public, anon;
grant execute on function public.auth_get_president_dashboard()
  to authenticated;
revoke all on function public.auth_get_president_members_page()
  from public, anon;
grant execute on function public.auth_get_president_members_page()
  to authenticated;
revoke all on function public.auth_get_president_member_detail(uuid)
  from public, anon;
grant execute on function public.auth_get_president_member_detail(uuid)
  to authenticated;

select pg_notify('pgrst', 'reload schema');

commit;

select
  to_regprocedure('public.auth_get_president_dashboard()') as president_dashboard_function,
  has_function_privilege(
    'authenticated',
    'public.auth_get_president_dashboard()',
    'EXECUTE'
  ) as authenticated_execute,
  has_function_privilege(
    'anon',
    'public.auth_get_president_dashboard()',
    'EXECUTE'
  ) as anon_execute,
  to_regprocedure('public.auth_get_president_members_page()') as president_members_function,
  has_function_privilege(
    'authenticated',
    'public.auth_get_president_members_page()',
    'EXECUTE'
  ) as members_authenticated_execute,
  has_function_privilege(
    'anon',
    'public.auth_get_president_members_page()',
    'EXECUTE'
  ) as members_anon_execute,
  to_regprocedure('public.auth_get_president_member_detail(uuid)') as member_detail_function,
  has_function_privilege(
    'authenticated',
    'public.auth_get_president_member_detail(uuid)',
    'EXECUTE'
  ) as detail_authenticated_execute,
  has_function_privilege(
    'anon',
    'public.auth_get_president_member_detail(uuid)',
    'EXECUTE'
  ) as detail_anon_execute;
