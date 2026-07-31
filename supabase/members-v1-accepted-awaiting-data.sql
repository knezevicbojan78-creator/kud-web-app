-- Prihvatanje kandidata u članstvo pre dopune ličnih podataka.

begin;

alter table public.society_members
  add column if not exists data_completion_status text not null default 'COMPLETED';
alter table public.society_members
  drop constraint if exists society_members_data_completion_status_check;
alter table public.society_members
  add constraint society_members_data_completion_status_check check (
    data_completion_status in (
      'AWAITING_DATA', 'DATA_IN_PROGRESS', 'AWAITING_REVIEW', 'COMPLETED'
    )
  );

create or replace function public.auth_accept_candidate_for_data_completion(
  p_society_id uuid,
  p_candidate_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_candidate public.member_import_candidates%rowtype;
  v_person_id uuid;
  v_member_id uuid;
begin
  if auth.uid() is null or not public.auth_can_bulk_import_members(p_society_id) then
    raise exception 'Nemate dozvolu za prijem člana.';
  end if;
  if not exists (
    select 1
    from public.society_members member
    join public.people person on person.id = member.person_id
    join public.society_member_function_assignments assignment
      on assignment.society_member_id = member.id
    join public.society_member_functions function on function.id = assignment.function_id
    where member.society_id = p_society_id
      and member.status = 'ACTIVE'
      and coalesce(member.user_id, person.user_id) = auth.uid()
      and function.name = 'Predsednik'
      and function.is_active
  ) then raise exception 'Samo predsednik može da prihvati člana.'; end if;

  select * into v_candidate
  from public.member_import_candidates
  where id = p_candidate_id and society_id = p_society_id and status = 'PENDING'
  for update;
  if v_candidate.id is null then raise exception 'Kandidat nije pronađen.'; end if;
  if v_candidate.society_member_id is not null then
    return jsonb_build_object(
      'society_member_id', v_candidate.society_member_id,
      'already_accepted', true
    );
  end if;

  select id into v_person_id
  from public.people
  where lower(email) = lower(btrim(v_candidate.profile->>'email'))
  limit 1;
  if v_person_id is null then
    insert into public.people(first_name, last_name, email, phone, country)
    values (
      btrim(v_candidate.profile->>'first_name'),
      btrim(v_candidate.profile->>'last_name'),
      lower(btrim(v_candidate.profile->>'email')),
      nullif(btrim(v_candidate.profile->>'phone'), ''),
      coalesce(nullif(btrim(v_candidate.profile->>'country'), ''), 'Srbija')
    )
    returning id into v_person_id;
  end if;
  if exists (
    select 1 from public.society_members
    where society_id = p_society_id and person_id = v_person_id
  ) then raise exception 'Osoba je već član ovog društva.'; end if;

  insert into public.society_members (
    society_id, person_id, status, start_date,
    membership_fee_required, membership_fee_amount, data_completion_status
  ) values (
    p_society_id, v_person_id, 'ACTIVE', current_date, true, 0, 'AWAITING_DATA'
  ) returning id into v_member_id;
  insert into public.member_status_history(society_member_id, status, effective_date)
  values (v_member_id, 'ACTIVE', current_date);
  update public.member_import_candidates
  set society_member_id = v_member_id, reviewed_by_user_id = auth.uid(), reviewed_at = now()
  where id = v_candidate.id;
  return jsonb_build_object(
    'society_member_id', v_member_id,
    'data_completion_status', 'AWAITING_DATA'
  );
end;
$$;

create or replace function public.members_sync_data_completion_status()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.society_members member set
    data_completion_status = case
      when new.status = 'SUBMITTED' then 'AWAITING_REVIEW'
      when new.status in ('OPENED', 'IN_PROGRESS') then 'DATA_IN_PROGRESS'
      else member.data_completion_status
    end
  from public.member_import_candidates candidate
  where candidate.id = new.candidate_id
    and member.id = candidate.society_member_id
    and member.data_completion_status <> 'COMPLETED';
  return new;
end;
$$;

drop trigger if exists member_invitation_sync_completion_status
  on public.member_data_invitations;
create trigger member_invitation_sync_completion_status
after insert or update of status on public.member_data_invitations
for each row execute function public.members_sync_data_completion_status();

create or replace function public.auth_complete_accepted_member_data(
  p_society_id uuid,
  p_candidate_id uuid,
  p_start_date date,
  p_profile_updates jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_candidate public.member_import_candidates%rowtype;
  v_draft public.member_data_drafts%rowtype;
  v_profile jsonb;
  v_guardians jsonb := '[]'::jsonb;
  v_function_ids uuid[] := array[]::uuid[];
  v_section_ids uuid[] := array[]::uuid[];
  v_result jsonb;
begin
  if auth.uid() is null or not public.auth_can_bulk_import_members(p_society_id) then
    raise exception 'Nemate dozvolu za završetak dopune člana.';
  end if;
  select * into v_candidate
  from public.member_import_candidates
  where id = p_candidate_id and society_id = p_society_id
    and status = 'PENDING' and society_member_id is not null
  for update;
  if v_candidate.id is null then raise exception 'Prihvaćeni član nije pronađen.'; end if;
  select * into v_draft from public.member_data_drafts where candidate_id = v_candidate.id;
  v_profile := coalesce(v_draft.draft, v_candidate.profile) ||
    coalesce(p_profile_updates, '{}'::jsonb);
  select coalesce(array_agg(item.value::uuid), array[]::uuid[])
    into v_function_ids
  from jsonb_array_elements_text(
    coalesce(p_profile_updates->'function_ids', '[]'::jsonb)
  ) item(value);
  select coalesce(array_agg(item.value::uuid), array[]::uuid[])
    into v_section_ids
  from jsonb_array_elements_text(
    coalesce(p_profile_updates->'section_ids', '[]'::jsonb)
  ) item(value);
  v_profile := v_profile - 'function_ids' - 'section_ids';
  if nullif(btrim(v_profile->>'first_name'), '') is null
     or nullif(btrim(v_profile->>'last_name'), '') is null
     or nullif(btrim(v_profile->>'gender'), '') is null
     or nullif(v_profile->>'birth_date', '') is null
     or nullif(lower(btrim(v_profile->>'email')), '') is null
     or (
       not coalesce((v_profile->>'is_minor_member')::boolean, false)
       and nullif(btrim(v_profile->>'phone'), '') is null
     )
     or nullif(btrim(v_profile->>'address'), '') is null
     or nullif(btrim(v_profile->>'city'), '') is null
     or nullif(btrim(v_profile->>'postal_code'), '') is null
     or nullif(btrim(v_profile->>'country'), '') is null then
    raise exception 'Nisu uneti svi obavezni lični podaci člana.';
  end if;
  if coalesce((v_profile->>'is_minor_member')::boolean, false) then
    if nullif(btrim(v_profile#>>'{guardian1,first_name}'), '') is null
       or nullif(btrim(v_profile#>>'{guardian1,last_name}'), '') is null
       or nullif(lower(btrim(v_profile#>>'{guardian1,email}')), '') is null
       or nullif(btrim(v_profile#>>'{guardian1,phone}'), '') is null then
      raise exception 'Primarni roditelj ili staratelj je obavezan.';
    end if;
    v_guardians := jsonb_build_array(
      (v_profile->'guardian1') || jsonb_build_object('is_primary', true)
    );
    if coalesce((v_profile->>'showGuardian2')::boolean, false) then
      v_guardians := v_guardians || jsonb_build_array(
        (v_profile->'guardian2') || jsonb_build_object('is_primary', false)
      );
    end if;
  end if;

  v_result := public.auth_update_society_member(
    v_candidate.society_member_id,
    v_profile || jsonb_build_object(
      'status', 'ACTIVE',
      'start_date', p_start_date,
      'membership_fee_required', coalesce(
        (p_profile_updates->>'membership_fee_required')::boolean,
        true
      ),
      'membership_fee_amount', case
        when coalesce((p_profile_updates->>'membership_fee_required')::boolean, true)
          then coalesce((p_profile_updates->>'membership_fee_amount')::numeric, 0)
        else null
      end
    ),
    v_guardians,
    v_function_ids,
    v_section_ids
  );
  update public.society_members set data_completion_status = 'COMPLETED'
  where id = v_candidate.society_member_id;
  update public.member_import_candidates set
    status = 'APPROVED', reviewed_by_user_id = auth.uid(), reviewed_at = now()
  where id = v_candidate.id;
  update public.member_data_invitations set status = 'CANCELLED', updated_at = now()
  where candidate_id = v_candidate.id and status <> 'SUBMITTED';
  return v_result || jsonb_build_object('data_completion_status', 'COMPLETED');
end;
$$;

revoke all on function public.auth_accept_candidate_for_data_completion(uuid,uuid)
  from public, anon;
revoke all on function public.auth_complete_accepted_member_data(uuid,uuid,date,jsonb)
  from public, anon;
grant execute on function public.auth_accept_candidate_for_data_completion(uuid,uuid)
  to authenticated;
grant execute on function public.auth_complete_accepted_member_data(uuid,uuid,date,jsonb)
  to authenticated;

select pg_notify('pgrst', 'reload schema');
commit;
