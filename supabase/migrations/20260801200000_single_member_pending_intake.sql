begin;

create or replace function public.auth_prepare_single_member_candidate(
  p_society_id uuid,
  p_profile jsonb,
  p_guardians jsonb default '[]'::jsonb,
  p_membership_setup jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_actor_member_id uuid;
  v_actor_person_id uuid;
  v_person_id uuid;
  v_candidate_id uuid;
  v_guardian jsonb;
  v_guardian_person_id uuid;
  v_profile jsonb;
  v_is_minor boolean := coalesce(jsonb_array_length(coalesce(p_guardians, '[]'::jsonb)) > 0, false);
  v_reused_person boolean := false;
  v_source_row integer;
begin
  if v_user_id is null then raise exception 'Prijava je obavezna.'; end if;

  select member.id, member.person_id into v_actor_member_id, v_actor_person_id
  from public.society_members member
  join public.people person on person.id = member.person_id
  where member.society_id = p_society_id and member.status = 'ACTIVE'
    and coalesce(member.user_id, person.user_id) = v_user_id
  order by member.id limit 1;

  if v_actor_member_id is null or not public.permissions_has_scope(
    p_society_id, v_actor_member_id, v_actor_person_id,
    'members.create', array['SOCIETY']::text[]
  ) then raise exception 'Nemate dozvolu za unos člana.'; end if;

  if nullif(btrim(p_profile ->> 'first_name'), '') is null
     or nullif(btrim(p_profile ->> 'last_name'), '') is null then
    raise exception 'Ime i prezime člana su obavezni.';
  end if;
  if not v_is_minor and (
    nullif(lower(btrim(p_profile ->> 'email')), '') is null
    or nullif(btrim(p_profile ->> 'phone'), '') is null
  ) then raise exception 'Email i telefon punoletnog člana su obavezni.'; end if;
  if v_is_minor and jsonb_array_length(coalesce(p_guardians, '[]'::jsonb)) = 0 then
    raise exception 'Za maloletnog člana unesite roditelja ili staratelja.';
  end if;

  if nullif(lower(btrim(p_profile ->> 'email')), '') is not null then
    select id into v_person_id from public.people
    where lower(email) = lower(btrim(p_profile ->> 'email')) limit 1;
  end if;
  if v_person_id is not null and exists (
    select 1 from public.society_members
    where society_id = p_society_id and person_id = v_person_id
  ) then raise exception 'Ova osoba je već član ovog društva.'; end if;
  v_reused_person := v_person_id is not null;

  if v_person_id is null then
    insert into public.people(first_name,last_name,gender,birth_date,address,city,postal_code,country,email,phone)
    values (
      btrim(p_profile ->> 'first_name'), btrim(p_profile ->> 'last_name'),
      nullif(btrim(p_profile ->> 'gender'), ''), nullif(p_profile ->> 'birth_date', '')::date,
      nullif(btrim(p_profile ->> 'address'), ''), nullif(btrim(p_profile ->> 'city'), ''),
      nullif(btrim(p_profile ->> 'postal_code'), ''), coalesce(nullif(btrim(p_profile ->> 'country'), ''), 'Srbija'),
      nullif(lower(btrim(p_profile ->> 'email')), ''), nullif(btrim(p_profile ->> 'phone'), '')
    ) returning id into v_person_id;
  end if;

  for v_guardian in select value from jsonb_array_elements(coalesce(p_guardians, '[]'::jsonb)) loop
    if nullif(btrim(v_guardian ->> 'first_name'), '') is null
       or nullif(btrim(v_guardian ->> 'last_name'), '') is null
       or nullif(lower(btrim(v_guardian ->> 'email')), '') is null
       or nullif(btrim(v_guardian ->> 'phone'), '') is null then
      raise exception 'Ime, prezime, email i telefon roditelja/staratelja su obavezni.';
    end if;
    select id into v_guardian_person_id from public.people
    where lower(email) = lower(btrim(v_guardian ->> 'email')) limit 1;
    if v_guardian_person_id is null then
      insert into public.people(first_name,last_name,email,phone,country)
      values (btrim(v_guardian ->> 'first_name'),btrim(v_guardian ->> 'last_name'),lower(btrim(v_guardian ->> 'email')),btrim(v_guardian ->> 'phone'),'Srbija');
    end if;
    v_guardian_person_id := null;
  end loop;

  if exists (
    select 1 from public.member_import_candidates candidate
    where candidate.society_id = p_society_id and candidate.status = 'PENDING'
      and (
        candidate.profile ->> '_person_id' = v_person_id::text
        or (nullif(lower(btrim(p_profile ->> 'email')), '') is not null
          and lower(candidate.profile ->> 'email') = lower(btrim(p_profile ->> 'email')))
      )
  ) then raise exception 'Ova osoba već čeka odobrenje u ovom društvu.'; end if;

  v_profile := p_profile || jsonb_build_object(
    '_person_id', v_person_id,
    'is_minor_member', v_is_minor,
    '_membership_setup', coalesce(p_membership_setup, '{}'::jsonb)
  );
  if v_is_minor then
    v_profile := v_profile || jsonb_build_object('guardian1', p_guardians -> 0);
    if jsonb_array_length(p_guardians) > 1 then
      v_profile := v_profile || jsonb_build_object('guardian2', p_guardians -> 1, 'showGuardian2', true);
    end if;
  end if;

  select coalesce(max(source_row), 0) + 1 into v_source_row
  from public.member_import_candidates where society_id = p_society_id;
  insert into public.member_import_candidates(society_id,profile,source_row,source_file_name,created_by_user_id)
  values (p_society_id,v_profile,v_source_row,'Pojedinačni unos',v_user_id)
  returning id into v_candidate_id;
  insert into public.member_data_drafts(candidate_id,society_id,draft,last_saved_at)
  values (v_candidate_id,p_society_id,v_profile,now());

  return jsonb_build_object('candidate_id',v_candidate_id,'person_id',v_person_id,'reused_person',v_reused_person,'status','PENDING');
end;
$$;

revoke all on function public.auth_prepare_single_member_candidate(uuid,jsonb,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.auth_prepare_single_member_candidate(uuid,jsonb,jsonb,jsonb) to authenticated;

commit;
