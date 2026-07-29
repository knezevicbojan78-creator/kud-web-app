-- FOLKLORAS — Master admin V1 society detail and status workflows
-- Run after supabase/master-admin-v1-setup.sql.
-- DEV/V1 anon grants must be removed when final Auth/RLS is introduced.

begin;

create or replace function public.master_admin_get_society_detail(
  p_society_id uuid
) returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_result jsonb;
begin
  if not exists (select 1 from societies where id = p_society_id) then
    raise exception 'Drustvo nije pronadjeno.';
  end if;

  select jsonb_build_object(
    'society', to_jsonb(s),
    'counts', jsonb_build_object(
      'active_members', (select count(*) from society_members sm where sm.society_id = s.id and sm.status = 'ACTIVE'),
      'inactive_members', (select count(*) from society_members sm where sm.society_id = s.id and sm.status <> 'ACTIVE'),
      'active_sections', (select count(*) from sections sec where sec.society_id = s.id and sec.status = 'ACTIVE'),
      'inactive_sections', (select count(*) from sections sec where sec.society_id = s.id and sec.status <> 'ACTIVE')
    ),
    'registration', (
      select jsonb_build_object(
        'id', pr.id,
        'president_name', trim(pr."presidentFirstName" || ' ' || pr."presidentLastName"),
        'president_email', pr."presidentEmail",
        'president_phone', pr."presidentPhone",
        'approved_at', pr."approvedAt"
      )
      from "PresidentReg" pr
      where pr."societyId" = s.id and pr."StatReg" = 'APPROVED'
      order by pr."approvedAt" desc nulls last
      limit 1
    ),
    'current_license', (
      select jsonb_build_object(
        'id', slp.id,
        'plan_name', slp.plan_name_snapshot,
        'source', slp.source,
        'billing_cycle', slp.billing_cycle,
        'duration_months', slp.duration_months,
        'valid_from', slp.valid_from,
        'valid_until', slp.valid_until,
        'member_limit', slp.active_member_limit_snapshot,
        'section_limit', slp.active_section_limit_snapshot
      )
      from society_license_periods slp
      where slp.society_id = s.id
      order by slp.valid_until desc, slp.created_at desc
      limit 1
    ),
    'active_suspension', (
      select jsonb_build_object(
        'id', ss.id,
        'reason_type', ss.reason_type,
        'reason', ss.reason,
        'suspended_at', ss.suspended_at
      )
      from society_suspensions ss
      where ss.society_id = s.id and ss.lifted_at is null
      order by ss.suspended_at desc
      limit 1
    ),
    'recent_audit', coalesce((
      select jsonb_agg(to_jsonb(audit_row) order by audit_row.created_at desc)
      from (
        select mal.id, mal.action, mal.entity_type, mal.reason, mal.result, mal.created_at
        from master_admin_audit_log mal
        where mal.society_id = s.id
        order by mal.created_at desc
        limit 20
      ) audit_row
    ), '[]'::jsonb)
  )
  into v_result
  from societies s
  where s.id = p_society_id;

  return v_result;
end;
$$;

create or replace function public.master_admin_set_society_status(
  p_society_id uuid,
  p_new_status text,
  p_reason text,
  p_actor_user_id uuid default null,
  p_actor_email text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_society societies;
  v_old_status text;
  v_suspension society_suspensions;
begin
  if p_new_status not in ('ACTIVE', 'SUSPENDED') then
    raise exception 'Status drustva nije dozvoljen.';
  end if;
  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'Razlog promene statusa je obavezan.';
  end if;

  select * into v_society from societies where id = p_society_id for update;
  if not found then raise exception 'Drustvo nije pronadjeno.'; end if;
  v_old_status := v_society.status;

  if v_old_status = p_new_status then
    raise exception 'Drustvo je vec u izabranom statusu.';
  end if;

  if p_new_status = 'SUSPENDED' then
    insert into society_suspensions (
      society_id, reason_type, reason, suspended_by_user_id
    ) values (
      p_society_id, 'ADMINISTRATIVE', trim(p_reason), p_actor_user_id
    ) returning * into v_suspension;
  else
    select * into v_suspension
    from society_suspensions
    where society_id = p_society_id and lifted_at is null
    for update;
    if not found then
      raise exception 'Aktivna suspenzija nije pronadjena.';
    end if;

    update society_suspensions
    set lifted_at = now(),
      lifted_by_user_id = p_actor_user_id,
      lift_reason = trim(p_reason)
    where id = v_suspension.id
    returning * into v_suspension;
  end if;

  update societies set status = p_new_status where id = p_society_id;

  insert into master_admin_audit_log (
    action, entity_type, entity_id, society_id, old_values, new_values,
    reason, actor_user_id, actor_email
  ) values (
    case when p_new_status = 'SUSPENDED' then 'SOCIETY_SUSPENDED' else 'SOCIETY_REACTIVATED' end,
    'SOCIETY', p_society_id, p_society_id,
    jsonb_build_object('status', v_old_status),
    jsonb_build_object('status', p_new_status, 'suspension_id', v_suspension.id),
    trim(p_reason), p_actor_user_id, p_actor_email
  );

  return jsonb_build_object(
    'society_id', p_society_id,
    'old_status', v_old_status,
    'new_status', p_new_status,
    'suspension_id', v_suspension.id
  );
end;
$$;

revoke all on function public.master_admin_get_society_detail(uuid) from public;
revoke all on function public.master_admin_set_society_status(uuid, text, text, uuid, text) from public;

grant execute on function public.master_admin_get_society_detail(uuid) to anon, authenticated;
grant execute on function public.master_admin_set_society_status(uuid, text, text, uuid, text) to anon, authenticated;

select pg_notify('pgrst', 'reload schema');
commit;
