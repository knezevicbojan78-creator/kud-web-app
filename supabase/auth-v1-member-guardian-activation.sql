-- FOLKLORAS — AUTH V1 / MEMBER AND GUARDIAN ACTIVATION
begin;

create table if not exists public.user_access_decisions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  person_id uuid not null references public.people(id) on delete restrict,
  access_kind text not null check (access_kind in ('MEMBERSHIP', 'GUARDIAN_LINK')),
  access_id uuid not null,
  decision text not null check (decision in ('ACCEPTED', 'REJECTED')),
  decided_at timestamptz not null default now(),
  constraint user_access_decisions_unique unique (user_id, access_kind, access_id)
);
alter table public.user_access_decisions enable row level security;
revoke all on table public.user_access_decisions from public, anon, authenticated;

create or replace function public.auth_get_account_activation()
returns jsonb language plpgsql stable security definer
set search_path = public, auth, pg_temp as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_person public.people;
begin
  if v_user_id is null then raise exception 'Prijava je obavezna.'; end if;
  select lower(btrim(email)) into v_email from auth.users
  where id = v_user_id and email_confirmed_at is not null;
  if v_email is null then raise exception 'Email mora biti potvrđen.'; end if;
  select p.* into v_person from public.people p
  where lower(btrim(p.email)) = v_email order by p.created_at limit 1;
  if v_person.id is null then raise exception 'Nalog nije prethodno evidentiran u društvu.'; end if;
  if v_person.user_id is not null and v_person.user_id <> v_user_id then
    raise exception 'Ova osoba je već povezana sa drugim nalogom.';
  end if;

  return jsonb_build_object(
    'person_name', concat_ws(' ', v_person.first_name, v_person.last_name),
    'completed', v_person.user_id = v_user_id,
    'memberships', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', sm.id, 'society_name', s.name, 'status', sm.status, 'decision', d.decision
      ) order by s.name)
      from public.society_members sm join public.societies s on s.id = sm.society_id
      left join public.user_access_decisions d on d.user_id = v_user_id
        and d.access_kind = 'MEMBERSHIP' and d.access_id = sm.id
      where sm.person_id = v_person.id
    ), '[]'::jsonb),
    'guardian_links', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', pg.id, 'child_name', concat_ws(' ', child.first_name, child.last_name),
        'relationship', pg.relationship, 'decision', d.decision,
        'societies', coalesce((
          select jsonb_agg(distinct s.name) from public.society_members csm
          join public.societies s on s.id = csm.society_id
          where csm.person_id = child.id and csm.status = 'ACTIVE'
        ), '[]'::jsonb)
      ) order by child.last_name, child.first_name)
      from public.person_guardians pg join public.people child on child.id = pg.child_person_id
      left join public.user_access_decisions d on d.user_id = v_user_id
        and d.access_kind = 'GUARDIAN_LINK' and d.access_id = pg.id
      where pg.guardian_person_id = v_person.id
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.auth_complete_account_activation(p_decisions jsonb)
returns jsonb language plpgsql security definer
set search_path = public, auth, pg_temp as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_person public.people;
  v_expected integer;
  v_submitted integer;
  v_item jsonb;
  v_kind text;
  v_id uuid;
  v_decision text;
begin
  if v_user_id is null then raise exception 'Prijava je obavezna.'; end if;
  if jsonb_typeof(p_decisions) <> 'array' then raise exception 'Odluke nisu ispravno poslate.'; end if;
  select lower(btrim(email)) into v_email from auth.users
  where id = v_user_id and email_confirmed_at is not null;
  select p.* into v_person from public.people p
  where lower(btrim(p.email)) = v_email order by p.created_at limit 1 for update;
  if v_person.id is null then raise exception 'Nalog nije prethodno evidentiran.'; end if;
  if v_person.user_id is not null and v_person.user_id <> v_user_id then
    raise exception 'Osoba je već povezana sa drugim nalogom.';
  end if;

  select (select count(*) from public.society_members where person_id = v_person.id)
    + (select count(*) from public.person_guardians where guardian_person_id = v_person.id)
  into v_expected;
  select count(*) into v_submitted from jsonb_array_elements(p_decisions);
  if v_expected = 0 or v_submitted <> v_expected then
    raise exception 'Potrebno je odlučiti o svakoj ponuđenoj vezi.';
  end if;

  for v_item in select value from jsonb_array_elements(p_decisions) loop
    v_kind := v_item ->> 'kind';
    v_id := (v_item ->> 'id')::uuid;
    v_decision := v_item ->> 'decision';
    if v_kind not in ('MEMBERSHIP', 'GUARDIAN_LINK')
       or v_decision not in ('ACCEPTED', 'REJECTED') then
      raise exception 'Nepoznata odluka o pristupu.';
    end if;
    if v_kind = 'MEMBERSHIP' and not exists (
      select 1 from public.society_members where id = v_id and person_id = v_person.id
    ) then raise exception 'Članstvo ne pripada prijavljenoj osobi.'; end if;
    if v_kind = 'GUARDIAN_LINK' and not exists (
      select 1 from public.person_guardians where id = v_id and guardian_person_id = v_person.id
    ) then raise exception 'Roditeljska veza ne pripada prijavljenoj osobi.'; end if;
    insert into public.user_access_decisions(user_id, person_id, access_kind, access_id, decision)
    values (v_user_id, v_person.id, v_kind, v_id, v_decision)
    on conflict (user_id, access_kind, access_id)
    do update set decision = excluded.decision, decided_at = now();
  end loop;

  update public.people set user_id = v_user_id, updated_at = now() where id = v_person.id;
  update public.society_members sm
  set user_id = case when d.decision = 'ACCEPTED' then v_user_id else null end,
      updated_at = now()
  from public.user_access_decisions d where d.user_id = v_user_id
    and d.access_kind = 'MEMBERSHIP' and d.access_id = sm.id;
  delete from public.person_guardians pg using public.user_access_decisions d
  where d.user_id = v_user_id and d.access_kind = 'GUARDIAN_LINK'
    and d.access_id = pg.id and d.decision = 'REJECTED';

  return jsonb_build_object('completed', true, 'has_access',
    exists (select 1 from public.society_members where user_id = v_user_id and status = 'ACTIVE')
    or exists (
      select 1 from public.person_guardians pg
      join public.people guardian on guardian.id = pg.guardian_person_id
      join public.society_members child_member on child_member.person_id = pg.child_person_id
      where guardian.user_id = v_user_id and child_member.status = 'ACTIVE'
    ));
end;
$$;

create or replace function public.auth_get_login_destination()
returns jsonb language plpgsql stable security definer
set search_path = public, auth, pg_temp as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_aal text := coalesce(auth.jwt() ->> 'aal', 'aal1');
  v_onboarding public.user_onboarding_state;
begin
  if v_user_id is null then raise exception 'Prijava je obavezna.'; end if;
  if exists (select 1 from public.platform_admins where user_id = v_user_id and status = 'ACTIVE') then
    return jsonb_build_object('account_type', 'MASTER_ADMIN',
      'destination', case when v_aal = 'aal2' then '/dashboard' else '/auth/mfa' end);
  end if;
  select uos.* into v_onboarding from public.user_onboarding_state uos
  join public."PresidentReg" pr on pr.id = uos.president_reg_id
  where uos.user_id = v_user_id and pr."presidentUserId" = v_user_id
    and pr."StatReg" = 'APPROVED' order by uos.created_at desc limit 1;
  if found then
    return jsonb_build_object('account_type', 'PRESIDENT',
      'society_id', v_onboarding.society_id,
      'onboarding_completed', v_onboarding.completed_at is not null,
      'destination', case when v_onboarding.completed_at is null
        then '/auth/president-onboarding' else '/dashboard' end);
  end if;
  if exists (select 1 from public.society_members where user_id = v_user_id and status = 'ACTIVE')
    or exists (
      select 1 from public.people guardian
      join public.person_guardians pg on pg.guardian_person_id = guardian.id
      join public.society_members child_member on child_member.person_id = pg.child_person_id
      where guardian.user_id = v_user_id and child_member.status = 'ACTIVE'
    ) then
    return jsonb_build_object('account_type', 'SOCIETY_USER', 'destination', '/garderoba');
  end if;
  select lower(btrim(email)) into v_email from auth.users where id = v_user_id;
  if exists (select 1 from public.people where lower(btrim(email)) = v_email) then
    return jsonb_build_object('account_type', 'PENDING_ACTIVATION',
      'destination', '/auth/activate-account');
  end if;
  raise exception 'Nalog još nema aktivan pristup aplikaciji.';
end;
$$;

create or replace function public.auth_get_application_context()
returns jsonb language plpgsql stable security definer
set search_path = public, auth, pg_temp as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_is_master boolean;
  v_memberships jsonb;
begin
  if v_user_id is null then raise exception 'Prijava je obavezna.'; end if;
  select lower(btrim(email)) into v_email from auth.users where id = v_user_id;
  select exists (select 1 from public.platform_admins
    where user_id = v_user_id and status = 'ACTIVE') into v_is_master;
  if v_is_master then
    return jsonb_build_object('account_type', 'MASTER_ADMIN', 'user_id', v_user_id,
      'email', v_email, 'is_master_admin', true, 'memberships', '[]'::jsonb);
  end if;
  select coalesce(jsonb_agg(row_data order by row_data ->> 'society_name'), '[]'::jsonb)
  into v_memberships from (
    select distinct on (row_data ->> 'society_id') row_data
    from (
    select jsonb_build_object(
      'society_id', s.id, 'society_name', s.name, 'society_status', s.status,
      'society_member_id', sm.id, 'person_id', sm.person_id,
      'member_status', sm.status, 'is_guardian', false,
      'functions', coalesce((select jsonb_agg(smf.name order by smf.sort_order)
        from public.society_member_function_assignments a
        join public.society_member_functions smf on smf.id = a.function_id
        where a.society_member_id = sm.id and smf.is_active), '[]'::jsonb)
    ) row_data
    from public.society_members sm join public.societies s on s.id = sm.society_id
    where sm.user_id = v_user_id and sm.status = 'ACTIVE'
      and s.status in ('ACTIVE', 'SUSPENDED')
    union
    select jsonb_build_object(
      'society_id', s.id, 'society_name', s.name, 'society_status', s.status,
      'society_member_id', null, 'person_id', guardian.id,
      'member_status', 'GUARDIAN', 'is_guardian', true, 'functions', '[]'::jsonb
    ) row_data
    from public.people guardian
    join public.person_guardians pg on pg.guardian_person_id = guardian.id
    join public.society_members child_member on child_member.person_id = pg.child_person_id
    join public.societies s on s.id = child_member.society_id
    where guardian.user_id = v_user_id and child_member.status = 'ACTIVE'
      and s.status in ('ACTIVE', 'SUSPENDED')
    ) combined
    order by row_data ->> 'society_id',
      case when (row_data ->> 'is_guardian')::boolean then 1 else 0 end
  ) available;
  if jsonb_array_length(v_memberships) = 0 then
    raise exception 'Korisnik nema aktivno članstvo ni pristup društvu.';
  end if;
  return jsonb_build_object('account_type', 'SOCIETY_USER', 'user_id', v_user_id,
    'email', v_email, 'is_master_admin', false, 'memberships', v_memberships);
end;
$$;

revoke all on function public.auth_get_account_activation() from public, anon;
grant execute on function public.auth_get_account_activation() to authenticated;
revoke all on function public.auth_complete_account_activation(jsonb) from public, anon;
grant execute on function public.auth_complete_account_activation(jsonb) to authenticated;
revoke all on function public.auth_get_login_destination() from public, anon;
grant execute on function public.auth_get_login_destination() to authenticated;
revoke all on function public.auth_get_application_context() from public, anon;
grant execute on function public.auth_get_application_context() to authenticated;
select pg_notify('pgrst', 'reload schema');
commit;
