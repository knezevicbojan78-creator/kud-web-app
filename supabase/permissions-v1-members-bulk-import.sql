begin;

insert into public.permission_catalog (
  permission_key,
  module_key,
  label,
  action_type,
  allowed_scopes,
  is_sensitive,
  requires_reason,
  is_president_only
)
values (
  'members.bulk_import',
  'members',
  'Masovni unos osoba i priprema novih clanova',
  'CREATE',
  array['SOCIETY'],
  true,
  false,
  false
)
on conflict (permission_key) do update
set
  module_key = excluded.module_key,
  label = excluded.label,
  action_type = excluded.action_type,
  allowed_scopes = excluded.allowed_scopes,
  is_sensitive = excluded.is_sensitive,
  requires_reason = excluded.requires_reason,
  is_president_only = excluded.is_president_only,
  is_active = true,
  updated_at = now();

insert into public.system_function_permission_templates (
  function_name,
  permission_id,
  scope_key,
  is_locked
)
select
  'Predsednik',
  permission.id,
  'SOCIETY',
  true
from public.permission_catalog permission
where permission.permission_key = 'members.bulk_import'
on conflict (function_name, permission_id) do update
set
  scope_key = excluded.scope_key,
  is_locked = excluded.is_locked,
  updated_at = now();

-- Postojeća društva odmah dobijaju obavezno zaključano pravo Predsednika.
-- Ostalim funkcijama predsednik može delegirati ovo pravo kroz Podešavanja.
insert into public.society_function_permission_rules (
  society_id,
  function_id,
  permission_id,
  scope_key,
  is_locked
)
select
  function_row.society_id,
  function_row.id,
  permission.id,
  'SOCIETY',
  true
from public.society_member_functions function_row
join public.permission_catalog permission
  on permission.permission_key = 'members.bulk_import'
where function_row.name = 'Predsednik'
  and function_row.is_active
on conflict (function_id, permission_id) do update
set
  scope_key = excluded.scope_key,
  is_locked = true,
  updated_at = now();

drop function if exists public.auth_can_bulk_import_members();

create function public.auth_can_bulk_import_members(
  p_society_id uuid default null
)
returns boolean
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_society_id uuid := p_society_id;
  v_actor_member_id uuid;
  v_actor_person_id uuid;
begin
  if v_user_id is null then
    return false;
  end if;

  select member.id, member.person_id
  into v_actor_member_id, v_actor_person_id
  from public.people person
  join public.society_members member
    on member.person_id = person.id
   and member.status = 'ACTIVE'
  join public.societies society
    on society.id = member.society_id
   and society.status = 'ACTIVE'
  where coalesce(member.user_id, person.user_id) = v_user_id
    and (v_society_id is null or member.society_id = v_society_id)
  order by member.id
  limit 1;

  if v_actor_member_id is null then
    return false;
  end if;

  if v_society_id is null then
    select member.society_id
    into v_society_id
    from public.society_members member
    where member.id = v_actor_member_id;
  end if;

  return public.permissions_has_scope(
    v_society_id,
    v_actor_member_id,
    v_actor_person_id,
    'members.bulk_import',
    array['SOCIETY']
  );
end;
$$;

revoke all on function public.auth_can_bulk_import_members(uuid)
  from public, anon;
grant execute on function public.auth_can_bulk_import_members(uuid)
  to authenticated;

commit;
