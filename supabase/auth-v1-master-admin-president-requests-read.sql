begin;

create or replace function public.master_admin_get_president_requests(
  p_status text default null,
  p_request_id uuid default null
) returns setof public."PresidentReg"
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
begin
  perform public.auth_assert_master_admin();

  if p_status is not null
     and p_status not in ('PENDING', 'APPROVED', 'REJECTED') then
    raise exception 'Nepoznat status zahteva.';
  end if;

  return query
  select request.*
  from public."PresidentReg" request
  where (p_status is null or request."StatReg" = p_status)
    and (p_request_id is null or request.id = p_request_id)
  order by coalesce(request."approvedAt", request."createdAt") desc;
end;
$$;

revoke all on function public.master_admin_get_president_requests(text, uuid)
  from public, anon, authenticated;
grant execute on function public.master_admin_get_president_requests(text, uuid)
  to authenticated;

commit;
