begin;

create or replace function public.auth_create_member_data_invitation(
  p_society_id uuid,
  p_candidate_id uuid,
  p_recipient_role text,
  p_recipient_email text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_candidate public.member_import_candidates%rowtype;
  v_draft jsonb;
  v_is_minor boolean;
  v_guardian_email text;
  v_token text := encode(extensions.gen_random_bytes(32), 'hex');
  v_email text;
begin
  if auth.uid() is null or not exists (
    select 1
    from public.society_members member
    join public.people person on person.id = member.person_id
    join public.society_member_function_assignments assignment
      on assignment.society_member_id = member.id
     and assignment.society_id = member.society_id
    join public.society_member_functions member_function
      on member_function.id = assignment.function_id
     and member_function.society_id = member.society_id
    where member.society_id = p_society_id
      and member.status = 'ACTIVE'
      and coalesce(member.user_id, person.user_id) = auth.uid()
      and member_function.name = 'Predsednik'
      and member_function.is_active
  ) then
    raise exception 'Samo predsednik moze da posalje poziv za dopunu.';
  end if;

  select * into v_candidate
  from public.member_import_candidates
  where id = p_candidate_id
    and society_id = p_society_id
    and status = 'PENDING';
  if v_candidate.id is null then
    raise exception 'Kandidat nije pronadjen.';
  end if;
  if p_recipient_role not in ('MEMBER', 'GUARDIAN') then
    raise exception 'Vrsta primaoca nije dozvoljena.';
  end if;

  select coalesce((
    select data_draft.draft
    from public.member_data_drafts data_draft
    where data_draft.candidate_id = v_candidate.id
  ), v_candidate.profile)
  into v_draft;

  v_is_minor := coalesce((v_draft ->> 'is_minor_member')::boolean, false);
  v_guardian_email := lower(btrim(v_draft #>> '{guardian1,email}'));

  if p_recipient_role = 'GUARDIAN' and not v_is_minor then
    raise exception 'Roditeljski poziv je dozvoljen samo za maloletnog kandidata.';
  end if;

  if v_is_minor then
    if nullif(v_guardian_email, '') is null then
      raise exception 'Pre slanja poziva prvo povezite roditelja ili staratelja.';
    end if;
    if not exists (
      select 1
      from public.people person
      where lower(person.email) = v_guardian_email
    ) then
      raise exception 'Povezani roditelj ili staratelj nije pronadjen medju osobama.';
    end if;
    if p_recipient_role = 'GUARDIAN'
       and p_recipient_email is not null
       and lower(btrim(p_recipient_email)) <> v_guardian_email then
      raise exception 'Email poziva mora odgovarati povezanom roditelju ili staratelju.';
    end if;
  end if;

  v_email := case
    when p_recipient_role = 'GUARDIAN' then v_guardian_email
    else lower(btrim(v_draft ->> 'email'))
  end;
  if nullif(v_email, '') is null then
    raise exception 'Email primaoca je obavezan.';
  end if;

  insert into public.member_data_drafts (
    candidate_id, society_id, draft
  ) values (
    v_candidate.id, p_society_id,
    v_draft
      - 'parental_travel_consent'
      - 'parental_travel_consent_valid_until'
  )
  on conflict (candidate_id) do nothing;

  insert into public.member_data_invitations (
    candidate_id, society_id, recipient_role, recipient_email, token_hash, status,
    expires_at, created_by_user_id
  ) values (
    v_candidate.id, p_society_id, p_recipient_role, v_email,
    encode(extensions.digest(v_token, 'sha256'), 'hex'),
    'INVITED', now() + interval '7 days', auth.uid()
  )
  on conflict (candidate_id, recipient_role) do update set
    token_hash = excluded.token_hash,
    recipient_email = excluded.recipient_email,
    status = 'INVITED',
    expires_at = excluded.expires_at,
    created_by_user_id = excluded.created_by_user_id,
    updated_at = now();

  return jsonb_build_object(
    'token', v_token,
    'email', v_email,
    'recipient_role', p_recipient_role,
    'recipient_name', concat_ws(
      ' ', v_draft ->> 'first_name',
      v_draft ->> 'last_name'
    )
  );
end;
$$;

revoke all on function public.auth_create_member_data_invitation(
  uuid, uuid, text, text
) from public, anon;
grant execute on function public.auth_create_member_data_invitation(
  uuid, uuid, text, text
) to authenticated;

select pg_notify('pgrst', 'reload schema');

commit;
