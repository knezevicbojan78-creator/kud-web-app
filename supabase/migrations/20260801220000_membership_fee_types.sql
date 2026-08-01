begin;

create table if not exists public.society_membership_fee_types (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  name text not null check (char_length(btrim(name)) between 2 and 80),
  amount numeric(12,2) not null check (amount > 0),
  currency text not null,
  is_active boolean not null default true,
  created_by_user_id uuid null,
  created_by_society_member_id uuid null references public.society_members(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists society_membership_fee_types_active_name_uq
  on public.society_membership_fee_types (society_id, lower(btrim(name)))
  where is_active;

alter table public.society_membership_fee_types enable row level security;
revoke all on table public.society_membership_fee_types from public, anon, authenticated;

create or replace function public.finance_assert_president_fee_type_access(
  p_society_id uuid,
  p_actor_member_id uuid
) returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if not exists (
    select 1
    from public.society_members member
    join public.people person on person.id = member.person_id
    join public.society_member_function_assignments assignment
      on assignment.society_member_id = member.id
    join public.society_member_functions function_row
      on function_row.id = assignment.function_id
    where member.id = p_actor_member_id
      and member.society_id = p_society_id
      and member.status = 'ACTIVE'
      and coalesce(member.user_id, person.user_id) = auth.uid()
      and function_row.society_id = p_society_id
      and function_row.is_active
      and function_row.name = 'Predsednik'
  ) then
    raise exception 'Samo predsednik može da upravlja vrstama članarine.';
  end if;
end;
$$;

create or replace function public.finance_list_membership_fee_types(
  p_society_id uuid,
  p_actor_member_id uuid,
  p_include_inactive boolean default false
) returns setof public.society_membership_fee_types
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
begin
  perform public.finance_assert_president_fee_type_access(p_society_id, p_actor_member_id);
  return query
  select fee_type.*
  from public.society_membership_fee_types fee_type
  where fee_type.society_id = p_society_id
    and (p_include_inactive or fee_type.is_active)
  order by fee_type.is_active desc, lower(fee_type.name), fee_type.created_at;
end;
$$;

create or replace function public.finance_save_membership_fee_type(
  p_society_id uuid,
  p_fee_type_id uuid,
  p_name text,
  p_amount numeric,
  p_actor_member_id uuid
) returns public.society_membership_fee_types
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_currency text;
  v_result public.society_membership_fee_types;
begin
  perform public.finance_assert_president_fee_type_access(p_society_id, p_actor_member_id);
  if char_length(btrim(coalesce(p_name, ''))) not between 2 and 80 then
    raise exception 'Naziv vrste članarine mora imati između 2 i 80 karaktera.';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'Iznos vrste članarine mora biti veći od nule.';
  end if;
  select base_currency into v_currency from public.societies where id = p_society_id;
  if v_currency is null then raise exception 'Društvo nije pronađeno.'; end if;

  if p_fee_type_id is null then
    insert into public.society_membership_fee_types (
      society_id, name, amount, currency, created_by_user_id, created_by_society_member_id
    ) values (
      p_society_id, btrim(p_name), p_amount, v_currency, auth.uid(), p_actor_member_id
    ) returning * into v_result;
  else
    update public.society_membership_fee_types
    set name = btrim(p_name), amount = p_amount, updated_at = now()
    where id = p_fee_type_id and society_id = p_society_id and is_active
    returning * into v_result;
    if v_result.id is null then raise exception 'Vrsta članarine nije pronađena.'; end if;
  end if;
  return v_result;
exception when unique_violation then
  raise exception 'Već postoji aktivna vrsta članarine sa ovim nazivom.';
end;
$$;

create or replace function public.finance_archive_membership_fee_type(
  p_fee_type_id uuid,
  p_actor_member_id uuid
) returns public.society_membership_fee_types
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_result public.society_membership_fee_types;
begin
  select * into v_result from public.society_membership_fee_types where id = p_fee_type_id;
  if v_result.id is null then raise exception 'Vrsta članarine nije pronađena.'; end if;
  perform public.finance_assert_president_fee_type_access(v_result.society_id, p_actor_member_id);
  update public.society_membership_fee_types set is_active = false, updated_at = now()
  where id = p_fee_type_id returning * into v_result;
  return v_result;
end;
$$;

revoke all on function public.finance_assert_president_fee_type_access(uuid,uuid) from public,anon,authenticated;
revoke all on function public.finance_list_membership_fee_types(uuid,uuid,boolean) from public,anon,authenticated;
revoke all on function public.finance_save_membership_fee_type(uuid,uuid,text,numeric,uuid) from public,anon,authenticated;
revoke all on function public.finance_archive_membership_fee_type(uuid,uuid) from public,anon,authenticated;
grant execute on function public.finance_list_membership_fee_types(uuid,uuid,boolean) to authenticated;
grant execute on function public.finance_save_membership_fee_type(uuid,uuid,text,numeric,uuid) to authenticated;
grant execute on function public.finance_archive_membership_fee_type(uuid,uuid) to authenticated;

select pg_notify('pgrst', 'reload schema');
commit;
