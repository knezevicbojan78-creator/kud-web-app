-- FOLKLORAS DEV/V1
-- Bezbedan pregled pojedinacnih rezima clanarine za tab Podesavanja.

begin;

create or replace function public.finance_list_member_fee_settings(
  p_society_id uuid,
  p_query text,
  p_only_nonstandard boolean,
  p_actor_member_id uuid
) returns table (
  society_member_id uuid,
  person_id uuid,
  display_name text,
  fee_mode text,
  fee_amount numeric,
  currency text,
  effective_from date
)
language plpgsql
security definer
stable
set search_path = public
as $$
begin
  if not finance_can_manage_society(p_society_id, p_actor_member_id) then
    raise exception 'Nemate pravo pregleda pojedinačnih članarina.';
  end if;

  return query
  select
    sm.id,
    p.id,
    trim(p.first_name || ' ' || p.last_name),
    sm.membership_fee_mode,
    case when sm.membership_fee_mode = 'EXEMPT' then null else sm.membership_fee_amount end,
    s.base_currency,
    (
      select h.effective_from
      from member_fee_setting_history h
      where h.society_member_id = sm.id
      order by h.effective_from desc, h.created_at desc
      limit 1
    )
  from society_members sm
  join people p on p.id = sm.person_id
  join societies s on s.id = sm.society_id
  where sm.society_id = p_society_id
    and sm.status = 'ACTIVE'
    and (not p_only_nonstandard or sm.membership_fee_mode <> 'STANDARD')
    and (
      length(trim(coalesce(p_query, ''))) = 0
      or lower(concat_ws(' ', p.first_name, p.last_name, p.email, p.phone))
        like '%' || lower(trim(p_query)) || '%'
    )
  order by p.first_name, p.last_name
  limit 50;
end;
$$;

revoke all on function public.finance_list_member_fee_settings(uuid, text, boolean, uuid)
  from public, anon, authenticated;
grant execute on function public.finance_list_member_fee_settings(uuid, text, boolean, uuid)
  to authenticated;

select pg_notify('pgrst', 'reload schema');
commit;
