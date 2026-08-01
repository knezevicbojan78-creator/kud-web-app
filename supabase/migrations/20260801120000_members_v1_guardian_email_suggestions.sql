begin;

create or replace function public.auth_search_guardians_for_member(
  p_society_id uuid,
  p_query text,
  p_limit integer default 6
) returns table (
  id uuid,
  first_name text,
  last_name text,
  email text,
  phone text
)
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_actor_member_id uuid;
  v_actor_person_id uuid;
  v_query text := lower(btrim(coalesce(p_query, '')));
  v_limit integer := least(greatest(coalesce(p_limit, 6), 1), 10);
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
    p_society_id,
    v_actor_member_id,
    v_actor_person_id,
    'members.create',
    array['SOCIETY']::text[]
  ) then
    raise exception 'Nemate dozvolu za pretragu roditelja ili staratelja.';
  end if;

  if length(v_query) < 2 then
    return;
  end if;

  return query
  select
    person.id,
    person.first_name,
    person.last_name,
    person.email,
    person.phone
  from public.people person
  where person.email is not null
    and lower(person.email) like '%' || v_query || '%'
  order by
    case when lower(person.email) like v_query || '%' then 0 else 1 end,
    lower(person.email),
    person.id
  limit v_limit;
end;
$$;

revoke all on function public.auth_search_guardians_for_member(uuid, text, integer)
  from public, anon, authenticated;
grant execute on function public.auth_search_guardians_for_member(uuid, text, integer)
  to authenticated;

commit;
