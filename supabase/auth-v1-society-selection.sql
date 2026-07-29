-- FOLKLORAS — AUTH V1 / ACTIVE SOCIETY SELECTION
begin;

create table if not exists public.user_society_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  society_id uuid not null references public.societies(id) on delete cascade,
  updated_at timestamptz not null default now()
);

alter table public.user_society_preferences enable row level security;
revoke all on table public.user_society_preferences from public, anon, authenticated;

create or replace function public.auth_select_society(p_society_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_society_name text;
begin
  if v_user_id is null then raise exception 'Prijava je obavezna.'; end if;

  select s.name into v_society_name
  from public.societies s
  where s.id = p_society_id
    and s.status in ('ACTIVE', 'SUSPENDED')
    and (
      exists (
        select 1 from public.society_members sm
        where sm.society_id = s.id and sm.user_id = v_user_id and sm.status = 'ACTIVE'
      )
      or exists (
        select 1 from public.people guardian
        join public.person_guardians pg on pg.guardian_person_id = guardian.id
        join public.society_members child_member on child_member.person_id = pg.child_person_id
        where guardian.user_id = v_user_id
          and child_member.society_id = s.id
          and child_member.status = 'ACTIVE'
      )
    );

  if v_society_name is null then
    raise exception 'Nemate pristup izabranom društvu.';
  end if;

  insert into public.user_society_preferences(user_id, society_id, updated_at)
  values (v_user_id, p_society_id, now())
  on conflict (user_id) do update
  set society_id = excluded.society_id, updated_at = now();

  return jsonb_build_object('society_id', p_society_id, 'society_name', v_society_name);
end;
$$;

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
  v_selected_society_id uuid;
  v_memberships jsonb;
begin
  if v_user_id is null then raise exception 'Prijava je obavezna.'; end if;

  select lower(btrim(email)) into v_email from auth.users where id = v_user_id;
  select exists (
    select 1 from public.platform_admins
    where user_id = v_user_id and status = 'ACTIVE'
  ) into v_is_master;

  if v_is_master then
    return jsonb_build_object(
      'account_type', 'MASTER_ADMIN', 'user_id', v_user_id, 'email', v_email,
      'is_master_admin', true, 'selected_society_id', null,
      'memberships', '[]'::jsonb
    );
  end if;

  select preference.society_id into v_selected_society_id
  from public.user_society_preferences preference
  where preference.user_id = v_user_id;

  select coalesce(
    jsonb_agg(
      available.row_data
      order by
        case when available.society_id = v_selected_society_id then 0 else 1 end,
        available.society_name
    ),
    '[]'::jsonb
  )
  into v_memberships
  from (
    select distinct on (combined.society_id)
      combined.society_id, combined.society_name, combined.row_data
    from (
      select
        s.id as society_id,
        s.name as society_name,
        false as is_guardian,
        jsonb_build_object(
          'society_id', s.id, 'society_name', s.name, 'society_status', s.status,
          'society_member_id', sm.id, 'person_id', sm.person_id,
          'member_status', sm.status, 'is_guardian', false,
          'functions', coalesce((
            select jsonb_agg(smf.name order by smf.sort_order)
            from public.society_member_function_assignments assignment
            join public.society_member_functions smf on smf.id = assignment.function_id
            where assignment.society_member_id = sm.id and smf.is_active
          ), '[]'::jsonb)
        ) as row_data
      from public.society_members sm
      join public.societies s on s.id = sm.society_id
      where sm.user_id = v_user_id and sm.status = 'ACTIVE'
        and s.status in ('ACTIVE', 'SUSPENDED')

      union all

      select
        s.id as society_id,
        s.name as society_name,
        true as is_guardian,
        jsonb_build_object(
          'society_id', s.id, 'society_name', s.name, 'society_status', s.status,
          'society_member_id', null, 'person_id', guardian.id,
          'member_status', 'GUARDIAN', 'is_guardian', true,
          'functions', '[]'::jsonb
        ) as row_data
      from public.people guardian
      join public.person_guardians pg on pg.guardian_person_id = guardian.id
      join public.society_members child_member on child_member.person_id = pg.child_person_id
      join public.societies s on s.id = child_member.society_id
      where guardian.user_id = v_user_id and child_member.status = 'ACTIVE'
        and s.status in ('ACTIVE', 'SUSPENDED')
    ) combined
    order by combined.society_id, combined.is_guardian
  ) available;

  if jsonb_array_length(v_memberships) = 0 then
    raise exception 'Korisnik nema aktivno članstvo ni pristup društvu.';
  end if;

  if v_selected_society_id is null or not exists (
    select 1 from jsonb_array_elements(v_memberships) membership
    where (membership ->> 'society_id')::uuid = v_selected_society_id
  ) then
    v_selected_society_id := (v_memberships -> 0 ->> 'society_id')::uuid;
  end if;

  return jsonb_build_object(
    'account_type', 'SOCIETY_USER', 'user_id', v_user_id, 'email', v_email,
    'is_master_admin', false, 'selected_society_id', v_selected_society_id,
    'memberships', v_memberships
  );
end;
$$;

revoke all on function public.auth_select_society(uuid) from public, anon;
grant execute on function public.auth_select_society(uuid) to authenticated;
revoke all on function public.auth_get_application_context() from public, anon;
grant execute on function public.auth_get_application_context() to authenticated;

select pg_notify('pgrst', 'reload schema');
commit;
