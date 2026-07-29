-- FOLKLORAS DEV/V1
-- FINANSIJE: bezbedno odredjivanje finansijske uloge prijavljenog korisnika.
-- Pokrenuti nakon finance-v1-read-workflows.sql.

begin;

create or replace function public.finance_get_actor_context()
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_context record;
begin
  if auth.uid() is null then
    raise exception 'Korisnik nije prijavljen.';
  end if;

  select
    sm.society_id,
    sm.id as society_member_id,
    smf.name as role
  into v_context
  from society_members sm
  join society_member_function_assignments smfa
    on smfa.society_id = sm.society_id
   and smfa.society_member_id = sm.id
   and smfa.status = 'ACTIVE'
  join society_member_functions smf
    on smf.id = smfa.function_id
   and smf.status = 'ACTIVE'
  where sm.user_id = auth.uid()
    and sm.status = 'ACTIVE'
    and smf.name in ('Predsednik', 'Blagajnik')
  order by case smf.name when 'Predsednik' then 1 else 2 end
  limit 1;

  if v_context.society_member_id is null then
    return null;
  end if;

  return jsonb_build_object(
    'society_id', v_context.society_id,
    'society_member_id', v_context.society_member_id,
    'role', v_context.role
  );
end;
$$;

revoke all on function public.finance_get_actor_context() from public;
grant execute on function public.finance_get_actor_context() to authenticated;

commit;
