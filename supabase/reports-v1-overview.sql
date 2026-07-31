-- Operativni izvestaji drustva dostupni predsedniku i delegiranim korisnicima.

begin;

insert into public.permission_catalog (
  permission_key,module_key,label,description,action_type,allowed_scopes,
  is_sensitive,requires_reason,is_president_only,is_active
) values
  ('reports.membership.view','reports','Pregled izveštaja o članstvu','Broj i struktura članova, sekcije i status dopune podataka.','VIEW',array['SOCIETY']::text[],false,false,false,true),
  ('reports.finance.view','reports','Pregled finansijskih izveštaja','Članarine, uplate, dugovanja i kotizacije društva.','VIEW',array['SOCIETY']::text[],true,false,false,true),
  ('reports.attendance.view','reports','Pregled izveštaja o prisustvu','Prisustvo i izostanci po sekcijama.','VIEW',array['SOCIETY']::text[],false,false,false,true),
  ('reports.events.view','reports','Pregled izveštaja o događajima','Događaji, statusi i broj učesnika.','VIEW',array['SOCIETY']::text[],false,false,false,true),
  ('reports.wardrobe.view','reports','Pregled izveštaja o garderobi','Inventar, zaduženja, kašnjenja, popravke i gubici.','VIEW',array['SOCIETY']::text[],false,false,false,true),
  ('reports.data_completion.view','reports','Pregled dopune podataka','Zahtevi, dopuna podataka i statusi konačne potvrde članova.','VIEW',array['SOCIETY']::text[],true,false,false,true),
  ('reports.activity.view','reports','Pregled aktivnosti korisnika','Evidencija važnih finansijskih i garderobnih aktivnosti.','VIEW',array['SOCIETY']::text[],true,false,false,true)
on conflict (permission_key) do update set
  module_key=excluded.module_key,label=excluded.label,description=excluded.description,
  action_type=excluded.action_type,allowed_scopes=excluded.allowed_scopes,
  is_sensitive=excluded.is_sensitive,is_active=true,updated_at=now();

insert into public.system_function_permission_templates(function_name,permission_id,scope_key,is_locked)
select 'Predsednik',p.id,'SOCIETY',true from public.permission_catalog p
where p.permission_key like 'reports.%'
on conflict (function_name,permission_id) do update set scope_key='SOCIETY',is_locked=true,updated_at=now();

insert into public.society_function_permission_rules(society_id,function_id,permission_id,scope_key,is_locked)
select f.society_id,f.id,p.id,'SOCIETY',true
from public.society_member_functions f cross join public.permission_catalog p
where f.name='Predsednik' and f.is_active and p.permission_key like 'reports.%'
on conflict (function_id,permission_id) do update set scope_key='SOCIETY',is_locked=true,updated_at=now();

create or replace function public.auth_get_society_reports_overview(
  p_society_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_actor record;
  v_membership boolean; v_finance boolean; v_attendance boolean; v_events boolean;
  v_wardrobe boolean; v_completion boolean; v_email boolean; v_activity boolean;
begin
  select * into v_actor from public.gmail_actor_member(p_society_id);
  if v_actor.member_id is null then
    raise exception 'Nemate pravo pregleda izvestaja drustva.';
  end if;
  v_membership := public.permissions_has_scope(p_society_id,v_actor.member_id,v_actor.person_id,'reports.membership.view',array['SOCIETY']::text[]);
  v_finance := public.permissions_has_scope(p_society_id,v_actor.member_id,v_actor.person_id,'reports.finance.view',array['SOCIETY']::text[]);
  v_attendance := public.permissions_has_scope(p_society_id,v_actor.member_id,v_actor.person_id,'reports.attendance.view',array['SOCIETY']::text[]);
  v_events := public.permissions_has_scope(p_society_id,v_actor.member_id,v_actor.person_id,'reports.events.view',array['SOCIETY']::text[]);
  v_wardrobe := public.permissions_has_scope(p_society_id,v_actor.member_id,v_actor.person_id,'reports.wardrobe.view',array['SOCIETY']::text[]);
  v_completion := public.permissions_has_scope(p_society_id,v_actor.member_id,v_actor.person_id,'reports.data_completion.view',array['SOCIETY']::text[]);
  v_email := public.permissions_has_scope(p_society_id,v_actor.member_id,v_actor.person_id,'reports.email_log.view',array['SOCIETY']::text[]);
  v_activity := public.permissions_has_scope(p_society_id,v_actor.member_id,v_actor.person_id,'reports.activity.view',array['SOCIETY']::text[]);
  if not (v_membership or v_finance or v_attendance or v_events or v_wardrobe or v_completion or v_email or v_activity) then
    raise exception 'Nemate pravo pregleda izvestaja drustva.';
  end if;

  return jsonb_build_object(
    'can_view', true,
    'access',jsonb_build_object('membership',v_membership,'finance',v_finance,'attendance',v_attendance,'events',v_events,'wardrobe',v_wardrobe,'completion',v_completion,'emails',v_email,'activity',v_activity),
    'membership', case when v_membership then jsonb_build_object(
      'active', (select count(*) from public.society_members m where m.society_id=p_society_id and m.status='ACTIVE'),
      'inactive', (select count(*) from public.society_members m where m.society_id=p_society_id and m.status='INACTIVE'),
      'minors', (select count(*) from public.society_members m join public.people p on p.id=m.person_id where m.society_id=p_society_id and m.status='ACTIVE' and p.birth_date > current_date-interval '18 years'),
      'incomplete', (select count(*) from public.society_members m where m.society_id=p_society_id and m.data_completion_status is distinct from 'COMPLETED'),
      'without_section', (select count(*) from public.society_members m where m.society_id=p_society_id and m.status='ACTIVE' and not exists(select 1 from public.member_sections ms where ms.society_member_id=m.id and ms.status='ACTIVE')),
      'custom_fee', (select count(*) from public.society_members m where m.society_id=p_society_id and m.status='ACTIVE' and m.membership_fee_mode='CUSTOM'),
      'exempt_fee', (select count(*) from public.society_members m where m.society_id=p_society_id and m.status='ACTIVE' and m.membership_fee_mode='EXEMPT'),
      'sections', coalesce((select jsonb_agg(x order by x.member_count desc, x.name) from (
        select s.id, s.name, count(ms.id) member_count
        from public.sections s left join public.member_sections ms on ms.section_id=s.id and ms.status='ACTIVE'
        where s.society_id=p_society_id and s.status='ACTIVE' group by s.id,s.name
      ) x), '[]'::jsonb)
    ) else null end,
    'finance', case when v_finance then jsonb_build_object(
      'posted_payments', (select coalesce(sum(amount),0) from public.financial_payments where society_id=p_society_id and status='POSTED'),
      'payment_count', (select count(*) from public.financial_payments where society_id=p_society_id and status='POSTED'),
      'open_amount', (select coalesce(sum(current_amount),0) from public.financial_obligations where society_id=p_society_id and status not in ('PAID','CANCELLED')),
      'open_count', (select count(*) from public.financial_obligations where society_id=p_society_id and status not in ('PAID','CANCELLED')),
      'overdue_count', (select count(*) from public.financial_obligations where society_id=p_society_id and status not in ('PAID','CANCELLED') and due_date<current_date),
      'membership_amount', (select coalesce(sum(current_amount),0) from public.financial_obligations where society_id=p_society_id and obligation_type='MEMBERSHIP' and status not in ('CANCELLED')),
      'event_amount', (select coalesce(sum(current_amount),0) from public.financial_obligations where society_id=p_society_id and obligation_type<>'MEMBERSHIP' and status not in ('CANCELLED'))
    ) else null end,
    'attendance', case when v_attendance then jsonb_build_object(
      'sessions', (select count(*) from public.attendance_sessions where society_id=p_society_id and status='CLOSED'),
      'open_sessions', (select count(*) from public.attendance_sessions where society_id=p_society_id and status='OPEN'),
      'present', (select count(*) from public.attendance_records r join public.attendance_sessions s on s.id=r.attendance_session_id where s.society_id=p_society_id and r.status='PRESENT'),
      'absent', (select count(*) from public.attendance_records r join public.attendance_sessions s on s.id=r.attendance_session_id where s.society_id=p_society_id and r.status='ABSENT'),
      'by_section', coalesce((select jsonb_agg(x order by x.sessions desc, x.name) from (
        select sec.id, sec.name, count(distinct ses.id) sessions,
          count(rec.id) filter(where rec.status='PRESENT') present,
          count(rec.id) filter(where rec.status='ABSENT') absent
        from public.sections sec
        left join public.attendance_sessions ses on ses.section_id=sec.id and ses.status='CLOSED'
        left join public.attendance_records rec on rec.attendance_session_id=ses.id
        where sec.society_id=p_society_id and sec.status='ACTIVE' group by sec.id,sec.name
      ) x), '[]'::jsonb)
    ) else null end,
    'events', case when v_events then jsonb_build_object(
      'total', (select count(*) from public.society_events where society_id=p_society_id),
      'approved', (select count(*) from public.society_events where society_id=p_society_id and status='APPROVED'),
      'completed', (select count(*) from public.society_events where society_id=p_society_id and status='COMPLETED'),
      'cancelled', (select count(*) from public.society_events where society_id=p_society_id and status='CANCELLED'),
      'participants', (select count(*) from public.event_participants ep join public.society_events e on e.id=ep.event_id where e.society_id=p_society_id),
      'recent', coalesce((select jsonb_agg(x order by x.created_at desc) from (
        select e.id,e.title,e.status,e.event_type,e.departure_at,e.created_at,
          (select count(*) from public.event_participants ep where ep.event_id=e.id) participant_count
        from public.society_events e where e.society_id=p_society_id order by e.created_at desc limit 30
      ) x), '[]'::jsonb)
    ) else null end,
    'wardrobe', case when v_wardrobe then jsonb_build_object(
      'items', (select count(*) from public.wardrobe_items where society_id=p_society_id and is_active),
      'quantity', (select coalesce(sum(total_quantity),0) from public.wardrobe_items where society_id=p_society_id and is_active),
      'active_assignments', (select count(*) from public.wardrobe_assignments where society_id=p_society_id and status not in ('RETURNED','CANCELLED','CLOSED')),
      'overdue_assignments', (select count(*) from public.wardrobe_assignments where society_id=p_society_id and status not in ('RETURNED','CANCELLED','CLOSED') and due_date<current_date),
      'open_repairs', (select count(*) from public.wardrobe_repairs where society_id=p_society_id and status not in ('COMPLETED','CANCELLED')),
      'open_losses', (select count(*) from public.wardrobe_loss_cases l join public.wardrobe_assignment_items ai on ai.id=l.assignment_item_id join public.wardrobe_assignments a on a.id=ai.assignment_id where a.society_id=p_society_id and l.status not in ('RESOLVED','CANCELLED'))
    ) else null end,
    'data_completion', case when v_completion then jsonb_build_object(
      'pending', (select count(*) from public.member_import_candidates where society_id=p_society_id and status='PENDING'),
      'approved', (select count(*) from public.member_import_candidates where society_id=p_society_id and status='APPROVED'),
      'rejected', (select count(*) from public.member_import_candidates where society_id=p_society_id and status='REJECTED'),
      'awaiting_data', (select count(*) from public.society_members where society_id=p_society_id and data_completion_status='AWAITING_DATA'),
      'awaiting_review', (select count(*) from public.society_members where society_id=p_society_id and data_completion_status='AWAITING_REVIEW')
    ) else null end,
    'activity', case when v_activity then coalesce((select jsonb_agg(x order by x.created_at desc) from (
      select id,action,entity_type,reason,actor_role,created_at,'FINANCE' module from public.financial_audit_log where society_id=p_society_id
      union all
      select id,action,entity_type,reason,null::text,created_at,'WARDROBE' module from public.wardrobe_audit_log where society_id=p_society_id
      order by created_at desc limit 100
    ) x), '[]'::jsonb) else null end
  );
end;
$$;

revoke all on function public.auth_get_society_reports_overview(uuid) from public,anon;
grant execute on function public.auth_get_society_reports_overview(uuid) to authenticated;

select pg_notify('pgrst','reload schema');
commit;
