-- FOLKLORAS — GARDEROBA V1 / POZAJMICE I OBAVESTENJA

begin;

create table if not exists public.wardrobe_loans (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null unique
    references public.wardrobe_assignments(id) on delete restrict,
  owner_society_id uuid not null references public.societies(id) on delete restrict,
  loan_type text not null check (loan_type in ('EXTERNAL','PLATFORM')),
  recipient_society_id uuid null references public.societies(id) on delete restrict,
  external_recipient_name text null,
  external_responsible_name text null,
  external_contact text null,
  status text not null default 'ISSUED'
    check (status in ('ISSUED','RECEIVED','RETURN_PENDING','RETURNED','CANCELLED')),
  issued_at timestamptz not null default now(),
  received_at timestamptz null,
  received_by_user_id uuid null,
  return_announced_at timestamptz null,
  returned_at timestamptz null,
  returned_confirmed_by_user_id uuid null,
  note text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint wardrobe_loan_recipient_check check (
    (loan_type='PLATFORM' and recipient_society_id is not null
      and external_recipient_name is null)
    or
    (loan_type='EXTERNAL' and recipient_society_id is null
      and external_recipient_name is not null)
  ),
  constraint wardrobe_loan_different_society_check check (
    recipient_society_id is null or recipient_society_id<>owner_society_id
  )
);

create index if not exists wardrobe_loans_owner_status_idx
  on public.wardrobe_loans(owner_society_id,status,issued_at desc);
create index if not exists wardrobe_loans_recipient_status_idx
  on public.wardrobe_loans(recipient_society_id,status,issued_at desc)
  where recipient_society_id is not null;

alter table public.wardrobe_loans enable row level security;
revoke all on table public.wardrobe_loans from public,anon,authenticated;

create unique index if not exists wardrobe_notifications_business_unique
  on public.wardrobe_notifications(
    society_id,
    coalesce(society_member_id,'00000000-0000-0000-0000-000000000000'::uuid),
    coalesce(person_id,'00000000-0000-0000-0000-000000000000'::uuid),
    coalesce(assignment_id,'00000000-0000-0000-0000-000000000000'::uuid),
    coalesce(repair_id,'00000000-0000-0000-0000-000000000000'::uuid),
    notification_type,channel
  );

create or replace function public.wardrobe_notify_luggage_handover()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  insert into public.wardrobe_notifications(
    society_id,society_member_id,assignment_id,notification_type,title,body
  )
  select a.society_id,new.new_member_id,a.id,'LUGGAGE_HANDOVER',
    'Preuzet je zajednički kofer',
    concat('Sada ste odgovorni za ',coalesce(l.name,'zajednički kofer'),
      case when a.due_date is not null
        then concat('. Rok vraćanja je ',to_char(a.due_date,'DD.MM.YYYY')) else '' end,'.')
  from public.wardrobe_luggage l
  join public.wardrobe_assignments a on a.id=l.assignment_id
  where l.id=new.luggage_id
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists wardrobe_luggage_handover_notification
  on public.wardrobe_luggage_handovers;
create trigger wardrobe_luggage_handover_notification
after insert on public.wardrobe_luggage_handovers
for each row execute function public.wardrobe_notify_luggage_handover();

create or replace function public.wardrobe_notify_repair_assignee()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if new.assigned_member_id is not null
     and new.assigned_member_id is distinct from old.assigned_member_id then
    insert into public.wardrobe_notifications(
      society_id,society_member_id,repair_id,notification_type,title,body
    )
    select new.society_id,new.assigned_member_id,new.id,'WARDROBE_REPAIR_ASSIGNED',
      'Dodeljena vam je popravka garderobe',
      concat(new.quantity,' × ',wi.name,
        case when new.due_date is not null
          then concat('. Rok je ',to_char(new.due_date,'DD.MM.YYYY')) else '' end,'.')
    from public.wardrobe_items wi where wi.id=new.wardrobe_item_id
    on conflict do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists wardrobe_repair_assignee_notification
  on public.wardrobe_repairs;
create trigger wardrobe_repair_assignee_notification
after update of assigned_member_id on public.wardrobe_repairs
for each row execute function public.wardrobe_notify_repair_assignee();

create or replace function public.auth_get_wardrobe_loans(p_society_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare v_actor record;
begin
  select * into v_actor from public.auth_wardrobe_actor(p_society_id,true);
  return jsonb_build_object(
    'platform_societies',coalesce((
      select jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,'city',s.city)
        order by s.name)
      from public.societies s
      where s.id<>p_society_id and s.status='ACTIVE'
    ),'[]'::jsonb),
    'owned',coalesce((
      select jsonb_agg(to_jsonb(l) || jsonb_build_object(
        'recipient_name',coalesce(rs.name,l.external_recipient_name),
        'assignment_title',coalesce(a.title,e.title,'Pozajmica garderobe'),
        'responsible_member_name',concat_ws(' ',p.first_name,p.last_name),
        'event_title',e.title,'due_date',a.due_date,
        'assignment_status',a.status,
        'items',coalesce((
          select jsonb_agg(jsonb_build_object(
            'assignment_item_id',ai.id,'item_name',wi.name,
            'shoe_size',wi.shoe_size,'issued_quantity',ai.issued_quantity,
            'returned_quantity',ai.returned_quantity,
            'remaining_quantity',greatest(0,ai.issued_quantity-ai.returned_quantity-
              ai.laundry_quantity-ai.repair_quantity-ai.lost_quantity-ai.damaged_quantity)
          ) order by wi.name)
          from public.wardrobe_assignment_items ai
          join public.wardrobe_items wi on wi.id=ai.wardrobe_item_id
          where ai.assignment_id=a.id
        ),'[]'::jsonb)
      ) order by l.issued_at desc)
      from public.wardrobe_loans l
      join public.wardrobe_assignments a on a.id=l.assignment_id
      left join public.societies rs on rs.id=l.recipient_society_id
      left join public.society_events e on e.id=a.event_id
      join public.society_members sm on sm.id=a.assigned_member_id
      join public.people p on p.id=sm.person_id
      where l.owner_society_id=p_society_id
    ),'[]'::jsonb),
    'received',coalesce((
      select jsonb_agg(to_jsonb(l) || jsonb_build_object(
        'owner_name',os.name,
        'assignment_title',coalesce(a.title,e.title,'Pozajmica garderobe'),
        'responsible_member_name',concat_ws(' ',p.first_name,p.last_name),
        'event_title',e.title,'due_date',a.due_date,
        'items',coalesce((
          select jsonb_agg(jsonb_build_object(
            'assignment_item_id',ai.id,'item_name',wi.name,
            'shoe_size',wi.shoe_size,'issued_quantity',ai.issued_quantity,
            'returned_quantity',ai.returned_quantity,
            'remaining_quantity',greatest(0,ai.issued_quantity-ai.returned_quantity-
              ai.laundry_quantity-ai.repair_quantity-ai.lost_quantity-ai.damaged_quantity)
          ) order by wi.name)
          from public.wardrobe_assignment_items ai
          join public.wardrobe_items wi on wi.id=ai.wardrobe_item_id
          where ai.assignment_id=a.id
        ),'[]'::jsonb)
      ) order by l.issued_at desc)
      from public.wardrobe_loans l
      join public.wardrobe_assignments a on a.id=l.assignment_id
      join public.societies os on os.id=l.owner_society_id
      left join public.society_events e on e.id=a.event_id
      join public.society_members sm on sm.id=a.assigned_member_id
      join public.people p on p.id=sm.person_id
      where l.recipient_society_id=p_society_id
    ),'[]'::jsonb)
  );
end;
$$;

create or replace function public.auth_wardrobe_create_loan(
  p_society_id uuid,p_loan jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_actor record; v_assignment_id uuid; v_loan_id uuid; v_type text;
  v_recipient_society_id uuid; v_payload jsonb;
begin
  select * into v_actor from public.auth_wardrobe_actor(p_society_id,true);
  v_type:=coalesce(nullif(p_loan->>'loan_type',''),'EXTERNAL');
  if v_type not in ('EXTERNAL','PLATFORM') then
    raise exception 'Vrsta pozajmice nije dozvoljena.';
  end if;
  v_recipient_society_id:=nullif(p_loan->>'recipient_society_id','')::uuid;
  if v_type='PLATFORM' then
    if v_recipient_society_id is null or v_recipient_society_id=p_society_id
       or not exists(select 1 from public.societies
         where id=v_recipient_society_id and status='ACTIVE')
    then raise exception 'Izaberite drugo aktivno društvo na platformi.'; end if;
  elsif nullif(btrim(p_loan->>'external_recipient_name'),'') is null then
    raise exception 'Naziv primaoca je obavezan.';
  end if;
  v_payload:=p_loan || jsonb_build_object(
    'assignment_type',case when v_type='PLATFORM'
      then 'PLATFORM_LOAN' else 'EXTERNAL_LOAN' end
  );
  v_assignment_id:=public.auth_wardrobe_create_assignment(p_society_id,v_payload);
  update public.wardrobe_assignments set
    recipient_society_id=v_recipient_society_id,
    external_recipient_name=case when v_type='EXTERNAL'
      then btrim(p_loan->>'external_recipient_name') else null end,
    external_contact=case when v_type='EXTERNAL'
      then nullif(btrim(p_loan->>'external_contact'),'') else null end,
    updated_at=now()
  where id=v_assignment_id;
  insert into public.wardrobe_loans(
    assignment_id,owner_society_id,loan_type,recipient_society_id,
    external_recipient_name,external_responsible_name,external_contact,note
  ) values(
    v_assignment_id,p_society_id,v_type,v_recipient_society_id,
    case when v_type='EXTERNAL' then btrim(p_loan->>'external_recipient_name') end,
    case when v_type='EXTERNAL' then nullif(btrim(p_loan->>'external_responsible_name'),'') end,
    case when v_type='EXTERNAL' then nullif(btrim(p_loan->>'external_contact'),'') end,
    nullif(btrim(p_loan->>'note'),'')
  ) returning id into v_loan_id;
  if v_type='PLATFORM' then
    insert into public.wardrobe_notifications(
      society_id,assignment_id,notification_type,title,body
    ) values(
      v_recipient_society_id,v_assignment_id,'LOAN_ISSUED',
      'Nova pozajmica garderobe',
      'Drugo društvo vam je izdalo garderobu. Potvrdite prijem nakon preuzimanja.'
    ) on conflict do nothing;
  end if;
  insert into public.wardrobe_audit_log(
    society_id,action,entity_type,entity_id,new_data,
    changed_by_user_id,changed_by_member_id
  ) select p_society_id,'CREATE','LOAN',v_loan_id,to_jsonb(l),
    auth.uid(),v_actor.member_id from public.wardrobe_loans l where l.id=v_loan_id;
  return v_loan_id;
end;
$$;

create or replace function public.auth_wardrobe_transition_loan(
  p_society_id uuid,p_loan_id uuid,p_action text,p_note text default null
)
returns public.wardrobe_loans
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_actor record; v_loan public.wardrobe_loans;
  v_assignment public.wardrobe_assignments; v_result public.wardrobe_loans;
  v_is_owner boolean; v_is_recipient boolean;
begin
  select * into v_actor from public.auth_wardrobe_actor(p_society_id,true);
  select * into v_loan from public.wardrobe_loans where id=p_loan_id for update;
  if v_loan.id is null then raise exception 'Pozajmica nije pronađena.'; end if;
  v_is_owner:=v_loan.owner_society_id=p_society_id;
  v_is_recipient:=v_loan.recipient_society_id=p_society_id;
  if not v_is_owner and not v_is_recipient then raise exception 'Pozajmica nije dostupna.'; end if;
  select * into v_assignment from public.wardrobe_assignments
    where id=v_loan.assignment_id;

  if p_action='CONFIRM_RECEIPT' then
    if v_loan.status<>'ISSUED' then raise exception 'Prijem sada nije moguće potvrditi.'; end if;
    if v_loan.loan_type='PLATFORM' and not v_is_recipient then
      raise exception 'Prijem potvrđuje društvo koje je primilo garderobu.';
    elsif v_loan.loan_type='EXTERNAL' and not v_is_owner then
      raise exception 'Prijem spoljnog korisnika evidentira vlasnik.';
    end if;
    update public.wardrobe_loans set status='RECEIVED',received_at=now(),
      received_by_user_id=auth.uid(),updated_at=now() where id=p_loan_id;
  elsif p_action='ANNOUNCE_RETURN' then
    if v_loan.status not in ('ISSUED','RECEIVED') then
      raise exception 'Vraćanje sada nije moguće najaviti.';
    end if;
    if v_loan.loan_type='PLATFORM' and not v_is_recipient then
      raise exception 'Vraćanje najavljuje društvo koje je primilo garderobu.';
    elsif v_loan.loan_type='EXTERNAL' and not v_is_owner then
      raise exception 'Vraćanje spoljnog korisnika evidentira vlasnik.';
    end if;
    update public.wardrobe_loans set status='RETURN_PENDING',
      return_announced_at=now(),updated_at=now() where id=p_loan_id;
    insert into public.wardrobe_notifications(
      society_id,assignment_id,notification_type,title,body
    ) values(v_loan.owner_society_id,v_loan.assignment_id,'LOAN_RETURN_PENDING',
      'Najavljeno vraćanje garderobe',
      'Primalac je najavio vraćanje. Pregledajte svaki deo prilikom prijema.'
    ) on conflict do nothing;
  elsif p_action='CONFIRM_RETURN' then
    if not v_is_owner or v_loan.status<>'RETURN_PENDING' then
      raise exception 'Vlasnik može potvrditi samo najavljeno vraćanje.';
    end if;
    if v_assignment.status<>'RETURNED' then
      raise exception 'Prvo razdužite i pregledajte sve delove pozajmice.';
    end if;
    update public.wardrobe_loans set status='RETURNED',returned_at=now(),
      returned_confirmed_by_user_id=auth.uid(),updated_at=now()
    where id=p_loan_id;
  else raise exception 'Akcija nad pozajmicom nije dozvoljena.';
  end if;
  select * into v_result from public.wardrobe_loans where id=p_loan_id;
  insert into public.wardrobe_audit_log(
    society_id,action,entity_type,entity_id,old_data,new_data,reason,
    changed_by_user_id,changed_by_member_id
  ) values(p_society_id,p_action,'LOAN',p_loan_id,to_jsonb(v_loan),
    to_jsonb(v_result),nullif(btrim(p_note),''),auth.uid(),v_actor.member_id);
  return v_result;
end;
$$;

create or replace function public.auth_get_wardrobe_notifications(p_society_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare v_actor record; v_settings public.wardrobe_settings;
begin
  select * into v_actor from public.auth_wardrobe_actor(p_society_id,false);
  select * into v_settings from public.wardrobe_settings where society_id=p_society_id;

  insert into public.wardrobe_notifications(
    society_id,society_member_id,assignment_id,notification_type,title,body,
    scheduled_for
  )
  select p_society_id,a.assigned_member_id,a.id,
    case when a.due_date<current_date then 'WARDROBE_OVERDUE'
      when a.due_date=current_date then 'WARDROBE_DUE_TODAY'
      else 'WARDROBE_DUE_SOON' end,
    case when a.due_date<current_date then 'Rok za vraćanje je prošao'
      when a.due_date=current_date then 'Garderobu treba vratiti danas'
      else 'Približava se rok za vraćanje garderobe' end,
    concat('Zaduženje ',coalesce(a.title,'garderobe'),' ima rok ',
      to_char(a.due_date,'DD.MM.YYYY'),'.'),
    now()
  from public.wardrobe_assignments a
  where a.society_id=p_society_id
    and a.status in ('OPEN','PARTIALLY_RETURNED','OVERDUE')
    and a.due_date is not null
    and a.due_date<=current_date+coalesce(v_settings.reminder_days_before_due,1)
  on conflict do nothing;

  insert into public.wardrobe_notifications(
    society_id,person_id,assignment_id,notification_type,title,body,scheduled_for
  )
  select p_society_id,pg.guardian_person_id,a.id,
    case when a.due_date<current_date then 'CHILD_WARDROBE_OVERDUE'
      when a.due_date=current_date then 'CHILD_WARDROBE_DUE_TODAY'
      else 'CHILD_WARDROBE_DUE_SOON' end,
    case when a.due_date<current_date then 'Rok za garderobu deteta je prošao'
      when a.due_date=current_date then 'Garderobu deteta treba vratiti danas'
      else 'Približava se rok za vraćanje garderobe deteta' end,
    concat('Rok za vraćanje garderobe je ',to_char(a.due_date,'DD.MM.YYYY'),'.'),
    now()
  from public.wardrobe_assignments a
  join public.society_members sm on sm.id=a.assigned_member_id
  join public.person_guardians pg on pg.child_person_id=sm.person_id
  where a.society_id=p_society_id
    and a.status in ('OPEN','PARTIALLY_RETURNED','OVERDUE')
    and a.due_date is not null
    and a.due_date<=current_date+coalesce(v_settings.reminder_days_before_due,1)
  on conflict do nothing;

  return jsonb_build_object(
    'unread_count',(
      select count(*) from public.wardrobe_notifications n
      where n.society_id=p_society_id and n.channel='IN_APP' and n.read_at is null
        and (
          (v_actor.is_manager and n.society_member_id is null and n.person_id is null)
          or n.society_member_id=v_actor.member_id or n.person_id=v_actor.person_id
        )
    ),
    'notifications',coalesce((
      select jsonb_agg(to_jsonb(n) order by n.scheduled_for desc)
      from public.wardrobe_notifications n
      where n.society_id=p_society_id and n.channel='IN_APP'
        and n.scheduled_for<=now()
        and (
          (v_actor.is_manager and n.society_member_id is null and n.person_id is null)
          or n.society_member_id=v_actor.member_id or n.person_id=v_actor.person_id
        )
    ),'[]'::jsonb)
  );
end;
$$;

create or replace function public.auth_wardrobe_mark_notification_read(
  p_society_id uuid,p_notification_id uuid
)
returns timestamptz
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare v_actor record; v_read_at timestamptz;
begin
  select * into v_actor from public.auth_wardrobe_actor(p_society_id,false);
  update public.wardrobe_notifications n set read_at=coalesce(read_at,now())
  where n.id=p_notification_id and n.society_id=p_society_id
    and (
      (v_actor.is_manager and n.society_member_id is null and n.person_id is null)
      or n.society_member_id=v_actor.member_id or n.person_id=v_actor.person_id
    )
  returning read_at into v_read_at;
  if v_read_at is null then raise exception 'Obaveštenje nije pronađeno.'; end if;
  return v_read_at;
end;
$$;

revoke all on function public.auth_get_wardrobe_loans(uuid) from public,anon;
revoke all on function public.auth_wardrobe_create_loan(uuid,jsonb) from public,anon;
revoke all on function public.auth_wardrobe_transition_loan(uuid,uuid,text,text) from public,anon;
revoke all on function public.auth_get_wardrobe_notifications(uuid) from public,anon;
revoke all on function public.auth_wardrobe_mark_notification_read(uuid,uuid) from public,anon;
grant execute on function public.auth_get_wardrobe_loans(uuid) to authenticated;
grant execute on function public.auth_wardrobe_create_loan(uuid,jsonb) to authenticated;
grant execute on function public.auth_wardrobe_transition_loan(uuid,uuid,text,text) to authenticated;
grant execute on function public.auth_get_wardrobe_notifications(uuid) to authenticated;
grant execute on function public.auth_wardrobe_mark_notification_read(uuid,uuid) to authenticated;

select pg_notify('pgrst','reload schema');
commit;
