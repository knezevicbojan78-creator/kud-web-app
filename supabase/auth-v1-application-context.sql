-- FOLKLORAS — AUTH V1 / CENTRAL APPLICATION CONTEXT
-- Jedini izvor istine za identitet, drustvo, clanstvo i funkcije korisnika.

begin;

create or replace function public.auth_get_application_context()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_is_master boolean;
  v_context jsonb;
begin
  if v_user_id is null then
    raise exception 'Prijava je obavezna.';
  end if;

  select lower(btrim(au.email))
  into v_email
  from auth.users au
  where au.id = v_user_id;

  select exists (
    select 1
    from public.platform_admins pa
    where pa.user_id = v_user_id and pa.status = 'ACTIVE'
  )
  into v_is_master;

  if v_is_master then
    return jsonb_build_object(
      'account_type', 'MASTER_ADMIN',
      'user_id', v_user_id,
      'email', v_email,
      'is_master_admin', true,
      'memberships', '[]'::jsonb
    );
  end if;

  select jsonb_build_object(
    'account_type', 'SOCIETY_USER',
    'user_id', v_user_id,
    'email', v_email,
    'is_master_admin', false,
    'memberships', coalesce(jsonb_agg(membership order by membership ->> 'society_name'), '[]'::jsonb)
  )
  into v_context
  from (
    select jsonb_build_object(
      'society_id', s.id,
      'society_name', s.name,
      'society_status', s.status,
      'society_member_id', sm.id,
      'person_id', sm.person_id,
      'member_status', sm.status,
      'functions', coalesce((
        select jsonb_agg(smf.name order by smf.sort_order)
        from public.society_member_function_assignments smfa
        join public.society_member_functions smf on smf.id = smfa.function_id
        where smfa.society_member_id = sm.id
          and smf.is_active
      ), '[]'::jsonb)
    ) as membership
    from public.society_members sm
    join public.societies s on s.id = sm.society_id
    where sm.user_id = v_user_id
      and sm.status = 'ACTIVE'
      and s.status in ('ACTIVE', 'SUSPENDED')
  ) user_memberships;

  if jsonb_array_length(coalesce(v_context -> 'memberships', '[]'::jsonb)) = 0 then
    raise exception 'Korisnik nema aktivno clanstvo ni pristup drustvu.';
  end if;

  return v_context;
end;
$$;

create or replace function public.auth_get_society_workspace(p_society_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_member_id uuid;
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception 'Prijava je obavezna.';
  end if;

  select sm.id
  into v_member_id
  from public.society_members sm
  where sm.user_id = v_user_id
    and sm.society_id = p_society_id
    and sm.status = 'ACTIVE';

  if v_member_id is null then
    raise exception 'Korisnik nema aktivno clanstvo u izabranom drustvu.';
  end if;

  select jsonb_build_object(
    'society', to_jsonb(s),
    'actor_society_member_id', v_member_id,
    'functions', coalesce((
      select jsonb_agg(smf.name order by smf.sort_order)
      from public.society_member_function_assignments smfa
      join public.society_member_functions smf on smf.id = smfa.function_id
      where smfa.society_member_id = v_member_id and smf.is_active
    ), '[]'::jsonb),
    'sections', coalesce((
      select jsonb_agg(
        to_jsonb(sec) || jsonb_build_object(
          'roles', coalesce((
            select jsonb_agg(
              to_jsonb(sra) || jsonb_build_object(
                'memberName', concat_ws(' ', p.first_name, p.last_name),
                'email', p.email,
                'phone', p.phone
              )
              order by sra.role, p.last_name, p.first_name
            )
            from public.section_role_assignments sra
            join public.society_members rsm on rsm.id = sra.society_member_id
            join public.people p on p.id = rsm.person_id
            where sra.section_id = sec.id
          ), '[]'::jsonb)
        )
        order by sec.name
      )
      from public.sections sec
      where sec.society_id = s.id
    ), '[]'::jsonb)
  )
  into v_result
  from public.societies s
  where s.id = p_society_id and s.status in ('ACTIVE', 'SUSPENDED');

  if v_result is null then
    raise exception 'Izabrano drustvo nije dostupno.';
  end if;

  return v_result;
end;
$$;

revoke all on function public.auth_get_application_context()
  from public, anon;
grant execute on function public.auth_get_application_context()
  to authenticated;
revoke all on function public.auth_get_society_workspace(uuid)
  from public, anon;
grant execute on function public.auth_get_society_workspace(uuid)
  to authenticated;

select pg_notify('pgrst', 'reload schema');

commit;

select
  to_regprocedure('public.auth_get_application_context()') as application_context_function,
  has_function_privilege(
    'authenticated',
    'public.auth_get_application_context()',
    'EXECUTE'
  ) as authenticated_execute,
  has_function_privilege(
    'anon',
    'public.auth_get_application_context()',
    'EXECUTE'
  ) as anon_execute,
  to_regprocedure('public.auth_get_society_workspace(uuid)') as society_workspace_function,
  has_function_privilege(
    'authenticated',
    'public.auth_get_society_workspace(uuid)',
    'EXECUTE'
  ) as workspace_authenticated_execute,
  has_function_privilege(
    'anon',
    'public.auth_get_society_workspace(uuid)',
    'EXECUTE'
  ) as workspace_anon_execute;
