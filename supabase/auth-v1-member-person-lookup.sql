begin;

create or replace function public.auth_lookup_person_for_member(
  p_society_id uuid,
  p_email text default null,
  p_jmbg text default null,
  p_passport_number text default null
) returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_actor_member_id uuid;
  v_actor_person_id uuid;
  v_person public.people;
begin
  if v_user_id is null then
    raise exception 'Prijava je obavezna.';
  end if;

  select member.id, member.person_id
  into v_actor_member_id, v_actor_person_id
  from public.society_members member
  join public.people person on person.id = member.person_id
  where member.society_id = p_society_id
    and member.status = 'ACTIVE'
    and coalesce(member.user_id, person.user_id) = v_user_id
  order by member.id
  limit 1;

  if v_actor_member_id is null or not public.permissions_has_scope(
    p_society_id, v_actor_member_id, v_actor_person_id,
    'members.create', array['SOCIETY']::text[]
  ) then
    raise exception 'Nemate dozvolu za proveru novih clanova.';
  end if;

  if nullif(lower(btrim(p_email)), '') is not null then
    select person.* into v_person
    from public.people person
    where lower(person.email) = lower(btrim(p_email))
    limit 1;
  elsif nullif(btrim(p_jmbg), '') is not null then
    select person.* into v_person
    from public.people person
    where person.jmbg = btrim(p_jmbg)
    limit 1;
  elsif nullif(btrim(p_passport_number), '') is not null then
    select person.* into v_person
    from public.people person
    where person.passport_number = btrim(p_passport_number)
    limit 1;
  else
    return jsonb_build_object('person', null, 'already_member', false);
  end if;

  if v_person.id is null then
    return jsonb_build_object('person', null, 'already_member', false);
  end if;

  return jsonb_build_object(
    'person', to_jsonb(v_person),
    'already_member', exists (
      select 1
      from public.society_members member
      where member.society_id = p_society_id
        and member.person_id = v_person.id
    )
  );
end;
$$;

revoke all on function public.auth_lookup_person_for_member(
  uuid, text, text, text
) from public, anon, authenticated;
grant execute on function public.auth_lookup_person_for_member(
  uuid, text, text, text
) to authenticated;

commit;
