begin;

alter table public."PresidentReg"
  add column if not exists "rejectionReason" text,
  add column if not exists "rejectedAt" timestamptz;

create or replace function public.master_admin_reject_president_request(
  p_request_id uuid,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_actor_email text;
  v_request public."PresidentReg";
  v_reason text := btrim(coalesce(p_reason, ''));
begin
  perform public.auth_assert_master_admin();

  if v_reason = '' then
    raise exception 'Razlog odbijanja je obavezan.';
  end if;

  select pa.email into v_actor_email
  from public.platform_admins pa
  where pa.user_id = auth.uid()
    and pa.status = 'ACTIVE';

  select * into v_request
  from public."PresidentReg" pr
  where pr.id = p_request_id
  for update;

  if not found then
    raise exception 'Zahtev nije pronađen.';
  end if;

  if v_request."StatReg" <> 'PENDING' then
    raise exception 'Zahtev je već obrađen.';
  end if;

  update public."PresidentReg"
  set
    "StatReg" = 'REJECTED',
    "approvedAt" = null,
    "approvedByEmail" = v_actor_email,
    "rejectionReason" = v_reason,
    "rejectedAt" = now()
  where id = p_request_id;

  insert into public.master_admin_audit_log (
    action, entity_type, entity_id, old_values, new_values, reason,
    actor_user_id, actor_email
  )
  values (
    'PRESIDENT_REQUEST_REJECTED',
    'PRESIDENT_REGISTRATION',
    p_request_id,
    jsonb_build_object('status', v_request."StatReg"),
    jsonb_build_object('status', 'REJECTED'),
    v_reason,
    auth.uid(),
    v_actor_email
  );

  return jsonb_build_object(
    'request_id', p_request_id,
    'status', 'REJECTED',
    'reason', v_reason
  );
end;
$$;

revoke all on function public.master_admin_reject_president_request(uuid, text)
  from public, anon;
grant execute on function public.master_admin_reject_president_request(uuid, text)
  to authenticated;

select pg_notify('pgrst', 'reload schema');

commit;
