-- FOLKLORAS — AUTH V1 / FINAL DEV CLEANUP
--
-- Pokrenuti tek nakon svih auth-v1-*.sql migracija za članove, sekcije,
-- prisustvo, finansije i događaje.

begin;

create or replace function public.master_admin_reject_president_request(
  p_request_id uuid,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_actor_email text;
  v_request public."PresidentReg";
begin
  perform public.auth_assert_master_admin();

  select pa.email into v_actor_email
  from public.platform_admins pa
  where pa.user_id = auth.uid()
    and pa.status = 'ACTIVE';

  select * into v_request
  from public."PresidentReg" pr
  where pr.id = p_request_id
  for update;

  if not found then
    raise exception 'Zahtev nije pronađen.';
  end if;

  if v_request."StatReg" <> 'PENDING' then
    raise exception 'Zahtev je već obrađen.';
  end if;

  update public."PresidentReg"
  set
    "StatReg" = 'REJECTED',
    "approvedAt" = null,
    "approvedByEmail" = v_actor_email
  where id = p_request_id;

  return jsonb_build_object(
    'request_id', p_request_id,
    'status', 'REJECTED',
    'reason', nullif(btrim(coalesce(p_reason, '')), '')
  );
end;
$$;

create or replace function public.master_admin_update_society(
  p_society_id uuid,
  p_values jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_society public.societies;
begin
  perform public.auth_assert_master_admin();

  if length(btrim(coalesce(p_values->>'name', ''))) < 2
    or length(btrim(coalesce(p_values->>'address', ''))) < 3
    or length(btrim(coalesce(p_values->>'city', ''))) < 2
    or length(btrim(coalesce(p_values->>'country', ''))) < 2
    or length(btrim(coalesce(p_values->>'pib', ''))) < 5
    or length(btrim(coalesce(p_values->>'registration_number', ''))) < 5
  then
    raise exception 'Popunite sva obavezna polja ispravnim podacima.';
  end if;

  if exists (
    select 1
    from public.societies s
    where s.id <> p_society_id
      and (
        btrim(s.pib) = btrim(p_values->>'pib')
        or btrim(s.registration_number) =
          btrim(p_values->>'registration_number')
      )
  ) then
    raise exception 'Društvo sa ovim PIB-om ili matičnim brojem već postoji.';
  end if;

  update public.societies
  set
    name = btrim(p_values->>'name'),
    address = btrim(p_values->>'address'),
    city = btrim(p_values->>'city'),
    postal_code = nullif(btrim(coalesce(p_values->>'postal_code', '')), ''),
    country = btrim(p_values->>'country'),
    pib = btrim(p_values->>'pib'),
    registration_number = btrim(p_values->>'registration_number'),
    bank_account = nullif(btrim(coalesce(p_values->>'bank_account', '')), '')
  where id = p_society_id
  returning * into v_society;

  if not found then
    raise exception 'Društvo nije pronađeno.';
  end if;

  return to_jsonb(v_society);
end;
$$;

revoke all on function public.master_admin_reject_president_request(uuid, text)
  from public, anon;
revoke all on function public.master_admin_update_society(uuid, jsonb)
  from public, anon;
grant execute on function public.master_admin_reject_president_request(uuid, text)
  to authenticated;
grant execute on function public.master_admin_update_society(uuid, jsonb)
  to authenticated;

create or replace function public.auth_can_access_society(p_society_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select public.auth_is_master_admin()
    or exists (
      select 1
      from public.society_members sm
      where sm.user_id = auth.uid()
        and sm.society_id = p_society_id
        and sm.status = 'ACTIVE'
    );
$$;

revoke all on function public.auth_can_access_society(uuid) from public, anon;
grant execute on function public.auth_can_access_society(uuid) to authenticated;

-- Uklanjanje širokih DEV politika.
drop policy if exists "dev_sections_select" on public.sections;
drop policy if exists "dev_sections_insert" on public.sections;
drop policy if exists "dev_sections_update" on public.sections;
drop policy if exists "dev_sections_delete" on public.sections;

drop policy if exists "dev_member_sections_select" on public.member_sections;
drop policy if exists "dev_member_sections_insert" on public.member_sections;
drop policy if exists "dev_member_sections_update" on public.member_sections;
drop policy if exists "dev_member_sections_delete" on public.member_sections;

drop policy if exists "dev_member_section_history_select"
  on public.member_section_history;
drop policy if exists "dev_member_section_history_insert"
  on public.member_section_history;
drop policy if exists "dev_member_section_history_update"
  on public.member_section_history;
drop policy if exists "dev_member_section_history_delete"
  on public.member_section_history;

drop policy if exists "dev_section_role_assignments_select"
  on public.section_role_assignments;
drop policy if exists "dev_section_role_assignments_insert"
  on public.section_role_assignments;
drop policy if exists "dev_section_role_assignments_update"
  on public.section_role_assignments;
drop policy if exists "dev_section_role_assignments_delete"
  on public.section_role_assignments;

drop policy if exists "dev_anon_update_pending_president_reg_status"
  on public."PresidentReg";
drop policy if exists "dev_authenticated_select_president_reg"
  on public."PresidentReg";

drop policy if exists "auth_sections_select" on public.sections;
drop policy if exists "auth_member_sections_select" on public.member_sections;
drop policy if exists "auth_member_section_history_select"
  on public.member_section_history;
drop policy if exists "auth_section_role_assignments_select"
  on public.section_role_assignments;
drop policy if exists "auth_master_president_reg_select"
  on public."PresidentReg";

create policy "auth_sections_select"
on public.sections
for select
to authenticated
using (public.auth_can_access_society(society_id));

create policy "auth_member_sections_select"
on public.member_sections
for select
to authenticated
using (public.auth_can_access_society(society_id));

create policy "auth_member_section_history_select"
on public.member_section_history
for select
to authenticated
using (public.auth_can_access_society(society_id));

create policy "auth_section_role_assignments_select"
on public.section_role_assignments
for select
to authenticated
using (public.auth_can_access_society(society_id));

create policy "auth_master_president_reg_select"
on public."PresidentReg"
for select
to authenticated
using (public.auth_is_master_admin());

revoke select on public.sections from anon;
revoke select on public.member_sections from anon;
revoke select on public.member_section_history from anon;
revoke select on public.section_role_assignments from anon;
revoke select on public."PresidentReg" from anon;
grant select on public.sections to authenticated;
grant select on public.member_sections to authenticated;
grant select on public.member_section_history to authenticated;
grant select on public.section_role_assignments to authenticated;
grant select on public."PresidentReg" to authenticated;

revoke insert, update, delete on public.sections from anon, authenticated;
revoke insert, update, delete on public.member_sections from anon, authenticated;
revoke insert, update, delete on public.member_section_history
  from anon, authenticated;
revoke insert, update, delete on public.section_role_assignments
  from anon, authenticated;
revoke update on public."PresidentReg" from anon, authenticated;

drop function if exists public.finance_get_test_actor_context(text);

select pg_notify('pgrst', 'reload schema');

commit;

select
  to_regprocedure(
    'public.master_admin_reject_president_request(uuid,text)'
  ) as reject_request_function,
  to_regprocedure(
    'public.master_admin_update_society(uuid,jsonb)'
  ) as update_society_function,
  has_function_privilege(
    'authenticated',
    'public.master_admin_reject_president_request(uuid,text)',
    'EXECUTE'
  ) as authenticated_reject_execute,
  has_function_privilege(
    'anon',
    'public.master_admin_reject_president_request(uuid,text)',
    'EXECUTE'
  ) as anon_reject_execute,
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and policyname ilike 'dev_%'
  ) as remaining_dev_policies,
  has_table_privilege('anon', 'public.sections', 'INSERT,UPDATE,DELETE')
    as anon_sections_write,
  has_table_privilege(
    'anon',
    'public.section_role_assignments',
    'INSERT,UPDATE,DELETE'
  ) as anon_section_roles_write;
