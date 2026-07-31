-- Završna potvrda prihvaćenog člana sa članarinom, funkcijama i sekcijama.

begin;

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
  where id = p_candidate_id
    and society_id = p_society_id
    and status = 'PENDING'
    and society_member_id is not null
  for update;

  if v_candidate.id is null then
    raise exception 'Prihvaćeni član nije pronađen.';
  end if;

  select * into v_draft
  from public.member_data_drafts
  where candidate_id = v_candidate.id;

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
    if nullif(lower(btrim(v_profile#>>'{guardian1,email}')), '') is null
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
        when coalesce(
          (p_profile_updates->>'membership_fee_required')::boolean,
          true
        ) then coalesce(
          (p_profile_updates->>'membership_fee_amount')::numeric,
          0
        )
        else null
      end
    ),
    v_guardians,
    v_function_ids,
    v_section_ids
  );

  update public.society_members
  set data_completion_status = 'COMPLETED'
  where id = v_candidate.society_member_id;

  update public.member_import_candidates
  set status = 'APPROVED',
      reviewed_by_user_id = auth.uid(),
      reviewed_at = now()
  where id = v_candidate.id;

  update public.member_data_invitations
  set status = 'CANCELLED',
      updated_at = now()
  where candidate_id = v_candidate.id
    and status <> 'SUBMITTED';

  return v_result || jsonb_build_object(
    'data_completion_status', 'COMPLETED'
  );
end;
$$;

revoke all on function public.auth_complete_accepted_member_data(
  uuid, uuid, date, jsonb
) from public, anon;

grant execute on function public.auth_complete_accepted_member_data(
  uuid, uuid, date, jsonb
) to authenticated;

select pg_notify('pgrst', 'reload schema');

commit;
