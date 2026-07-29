-- FOLKLORAS — AUTH V1 / PREDSEDNICKA PODESAVANJA DOZVOLA (READ)
-- Bezbedan ulaz iz aplikacije za pregled funkcija i zajednickih pravila.

begin;

create or replace function public.auth_permissions_get_settings(
  p_function_id uuid default null
) returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_society_id uuid;
  v_actor_member_id uuid;
  v_selected_function_id uuid;
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception 'Prijava je obavezna.';
  end if;

  select member.society_id, member.id
  into v_society_id, v_actor_member_id
  from public.people person
  join public.society_members member
    on member.person_id = person.id
   and member.status = 'ACTIVE'
  join public.society_member_function_assignments assignment
    on assignment.society_id = member.society_id
   and assignment.society_member_id = member.id
  join public.society_member_functions member_function
    on member_function.id = assignment.function_id
   and member_function.society_id = member.society_id
   and member_function.is_active = true
  join public.societies society
    on society.id = member.society_id
   and society.status = 'ACTIVE'
  where coalesce(member.user_id, person.user_id) = v_user_id
    and lower(trim(member_function.name)) = lower('Predsednik')
  order by member.id
  limit 1;

  if v_actor_member_id is null then
    raise exception 'Samo predsednik moze da pregleda podesavanja dozvola.';
  end if;

  if p_function_id is not null and exists (
    select 1
    from public.society_member_functions member_function
    where member_function.id = p_function_id
      and member_function.society_id = v_society_id
      and member_function.is_active = true
  ) then
    v_selected_function_id := p_function_id;
  else
    select member_function.id
    into v_selected_function_id
    from public.society_member_functions member_function
    where member_function.society_id = v_society_id
      and member_function.is_active = true
    order by
      case when lower(trim(member_function.name)) = lower('Predsednik') then 1 else 0 end,
      member_function.sort_order,
      member_function.name
    limit 1;
  end if;

  select jsonb_build_object(
    'society_id', v_society_id,
    'actor_member_id', v_actor_member_id,
    'selected_function_id', v_selected_function_id,
    'functions', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', member_function.id,
          'name', member_function.name,
          'is_president', lower(trim(member_function.name)) = lower('Predsednik'),
          'assignment_count', (
            select count(*)
            from public.society_member_function_assignments assignment
            join public.society_members assigned_member
              on assigned_member.id = assignment.society_member_id
             and assigned_member.society_id = assignment.society_id
             and assigned_member.status = 'ACTIVE'
            where assignment.society_id = v_society_id
              and assignment.function_id = member_function.id
          )
        )
        order by member_function.sort_order, member_function.name
      )
      from public.society_member_functions member_function
      where member_function.society_id = v_society_id
        and member_function.is_active = true
    ), '[]'::jsonb),
    'rules', coalesce((
      select jsonb_agg(
        to_jsonb(configuration)
        order by configuration.module_key, configuration.permission_key
      )
      from public.permissions_list_function_configuration(
        v_society_id,
        v_selected_function_id,
        v_actor_member_id
      ) configuration
    ), '[]'::jsonb)
  )
  into v_result;

  return v_result;
end;
$$;

create or replace function public.auth_permissions_save_function_rules(
  p_function_id uuid,
  p_changes jsonb,
  p_reason text
) returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_society_id uuid;
  v_actor_member_id uuid;
begin
  if v_user_id is null then
    raise exception 'Prijava je obavezna.';
  end if;

  select member.society_id, member.id
  into v_society_id, v_actor_member_id
  from public.people person
  join public.society_members member
    on member.person_id = person.id
   and member.status = 'ACTIVE'
  join public.society_member_function_assignments assignment
    on assignment.society_id = member.society_id
   and assignment.society_member_id = member.id
  join public.society_member_functions member_function
    on member_function.id = assignment.function_id
   and member_function.society_id = member.society_id
   and member_function.is_active = true
  join public.societies society
    on society.id = member.society_id
   and society.status = 'ACTIVE'
  where coalesce(member.user_id, person.user_id) = v_user_id
    and lower(trim(member_function.name)) = lower('Predsednik')
  order by member.id
  limit 1;

  if v_actor_member_id is null then
    raise exception 'Samo predsednik moze da menja podesavanja dozvola.';
  end if;

  perform public.permissions_save_function_rules(
    v_society_id,
    p_function_id,
    p_changes,
    p_reason,
    v_actor_member_id
  );

  return public.auth_permissions_get_settings(p_function_id);
end;
$$;

create or replace function public.auth_permissions_list_function_members(
  p_function_id uuid,
  p_query text default ''
) returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_society_id uuid;
  v_actor_member_id uuid;
  v_result jsonb;
begin
  if v_user_id is null then raise exception 'Prijava je obavezna.'; end if;

  select member.society_id, member.id
  into v_society_id, v_actor_member_id
  from public.people person
  join public.society_members member on member.person_id = person.id and member.status = 'ACTIVE'
  join public.society_member_function_assignments assignment
    on assignment.society_id = member.society_id and assignment.society_member_id = member.id
  join public.society_member_functions member_function
    on member_function.id = assignment.function_id
   and member_function.society_id = member.society_id
   and member_function.is_active = true
  join public.societies society on society.id = member.society_id and society.status = 'ACTIVE'
  where coalesce(member.user_id, person.user_id) = v_user_id
    and lower(trim(member_function.name)) = lower('Predsednik')
  order by member.id
  limit 1;

  if v_actor_member_id is null then
    raise exception 'Samo predsednik moze da pregleda pojedinacne izuzetke.';
  end if;

  select coalesce(jsonb_agg(to_jsonb(member_row) order by member_row.display_name), '[]'::jsonb)
  into v_result
  from public.permissions_list_function_members(
    v_society_id,
    p_function_id,
    coalesce(p_query, ''),
    v_actor_member_id
  ) member_row;

  return v_result;
end;
$$;

create or replace function public.auth_permissions_get_member_configuration(
  p_target_member_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_society_id uuid;
  v_actor_member_id uuid;
  v_result jsonb;
begin
  if v_user_id is null then raise exception 'Prijava je obavezna.'; end if;

  select member.society_id, member.id
  into v_society_id, v_actor_member_id
  from public.people person
  join public.society_members member on member.person_id = person.id and member.status = 'ACTIVE'
  join public.society_member_function_assignments assignment
    on assignment.society_id = member.society_id and assignment.society_member_id = member.id
  join public.society_member_functions member_function
    on member_function.id = assignment.function_id
   and member_function.society_id = member.society_id
   and member_function.is_active = true
  join public.societies society on society.id = member.society_id and society.status = 'ACTIVE'
  where coalesce(member.user_id, person.user_id) = v_user_id
    and lower(trim(member_function.name)) = lower('Predsednik')
  order by member.id
  limit 1;

  if v_actor_member_id is null then
    raise exception 'Samo predsednik moze da pregleda pojedinacne izuzetke.';
  end if;

  select jsonb_build_object(
    'society_member_id', target_member.id,
    'display_name', trim(target_person.first_name || ' ' || target_person.last_name),
    'active_function_names', (
      select coalesce(array_agg(distinct assigned_function.name order by assigned_function.name), array[]::text[])
      from public.society_member_function_assignments assigned
      join public.society_member_functions assigned_function
        on assigned_function.id = assigned.function_id and assigned_function.is_active = true
      where assigned.society_id = v_society_id
        and assigned.society_member_id = target_member.id
    ),
    'rules', coalesce((
      select jsonb_agg(to_jsonb(configuration) order by configuration.module_key, configuration.permission_key)
      from public.permissions_get_member_configuration(
        v_society_id,
        target_member.id,
        v_actor_member_id
      ) configuration
    ), '[]'::jsonb)
  )
  into v_result
  from public.society_members target_member
  join public.people target_person on target_person.id = target_member.person_id
  where target_member.id = p_target_member_id
    and target_member.society_id = v_society_id
    and target_member.status = 'ACTIVE';

  if v_result is null then raise exception 'Aktivni clan nije pronadjen u drustvu.'; end if;
  return v_result;
end;
$$;

create or replace function public.auth_permissions_save_member_overrides(
  p_target_member_id uuid,
  p_changes jsonb,
  p_reason text
) returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_society_id uuid;
  v_actor_member_id uuid;
begin
  if v_user_id is null then raise exception 'Prijava je obavezna.'; end if;

  select member.society_id, member.id
  into v_society_id, v_actor_member_id
  from public.people person
  join public.society_members member on member.person_id = person.id and member.status = 'ACTIVE'
  join public.society_member_function_assignments assignment
    on assignment.society_id = member.society_id and assignment.society_member_id = member.id
  join public.society_member_functions member_function
    on member_function.id = assignment.function_id
   and member_function.society_id = member.society_id
   and member_function.is_active = true
  join public.societies society on society.id = member.society_id and society.status = 'ACTIVE'
  where coalesce(member.user_id, person.user_id) = v_user_id
    and lower(trim(member_function.name)) = lower('Predsednik')
  order by member.id
  limit 1;

  if v_actor_member_id is null then
    raise exception 'Samo predsednik moze da menja pojedinacne izuzetke.';
  end if;

  perform public.permissions_save_member_overrides(
    v_society_id,
    p_target_member_id,
    p_changes,
    p_reason,
    v_actor_member_id
  );

  return public.auth_permissions_get_member_configuration(p_target_member_id);
end;
$$;

comment on function public.auth_permissions_get_settings(uuid)
is 'Predsedniku vraca aktivne funkcije drustva i zajednicka pravila izabrane funkcije.';
comment on function public.auth_permissions_save_function_rules(uuid, jsonb, text)
is 'Predsedniku atomski cuva zajednicka pravila funkcije i vraca osvezen prikaz.';
comment on function public.auth_permissions_list_function_members(uuid, text)
is 'Predsedniku vraca aktivne clanove izabrane funkcije.';
comment on function public.auth_permissions_get_member_configuration(uuid)
is 'Predsedniku vraca efektivna prava i pojedinacne izuzetke clana.';
comment on function public.auth_permissions_save_member_overrides(uuid, jsonb, text)
is 'Predsedniku atomski cuva pojedinacne izuzetke i vraca osvezen prikaz.';

revoke all on function public.auth_permissions_get_settings(uuid)
  from public, anon;
grant execute on function public.auth_permissions_get_settings(uuid)
  to authenticated;
revoke all on function public.auth_permissions_save_function_rules(uuid, jsonb, text)
  from public, anon;
grant execute on function public.auth_permissions_save_function_rules(uuid, jsonb, text)
  to authenticated;
revoke all on function public.auth_permissions_list_function_members(uuid, text)
  from public, anon;
grant execute on function public.auth_permissions_list_function_members(uuid, text)
  to authenticated;
revoke all on function public.auth_permissions_get_member_configuration(uuid)
  from public, anon;
grant execute on function public.auth_permissions_get_member_configuration(uuid)
  to authenticated;
revoke all on function public.auth_permissions_save_member_overrides(uuid, jsonb, text)
  from public, anon;
grant execute on function public.auth_permissions_save_member_overrides(uuid, jsonb, text)
  to authenticated;

commit;
