-- FOLKLORAS — GARDEROBA V1 / UREDJIVANJE I OPERATIVNI TOKOVI

begin;

create or replace function public.auth_wardrobe_get_item_repertoire(
  p_society_id uuid,
  p_wardrobe_item_id uuid
)
returns uuid[]
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
begin
  perform 1 from public.auth_wardrobe_actor(p_society_id, false);
  if not exists (
    select 1 from public.wardrobe_items
    where id=p_wardrobe_item_id and society_id=p_society_id
  ) then raise exception 'Stavka garderobe nije pronađena.'; end if;
  return coalesce((
    select array_agg(wir.repertoire_item_id order by wir.repertoire_item_id)
    from public.wardrobe_item_repertoire wir
    where wir.wardrobe_item_id=p_wardrobe_item_id
  ),array[]::uuid[]);
end;
$$;

-- Dodatna zastita: ukupna kolicina ne moze da se smanji ispod kolicine koja je
-- trenutno van garderobe ili je ostala povezana sa aktivnim zaduzenjima.
create or replace function public.auth_wardrobe_save_item(
  p_society_id uuid, p_item jsonb
)
returns uuid
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_actor record; v_id uuid; v_old jsonb;
  v_category public.wardrobe_categories; v_committed integer:=0;
  v_new_quantity integer;
begin
  select * into v_actor from public.auth_wardrobe_actor(p_society_id,true);
  select * into v_category from public.wardrobe_categories
    where id=(p_item->>'category_id')::uuid and society_id=p_society_id and is_active;
  if v_category.id is null then raise exception 'Izaberite aktivnu kategoriju.'; end if;
  if nullif(btrim(p_item->>'name'),'') is null then raise exception 'Naziv je obavezan.'; end if;
  if not v_category.is_footwear and nullif(p_item->>'shoe_size','') is not null then
    raise exception 'Broj se unosi samo za obuću.';
  end if;
  v_new_quantity:=coalesce((p_item->>'total_quantity')::integer,0);
  if v_new_quantity<0 then raise exception 'Količina ne može biti negativna.'; end if;
  v_id:=nullif(p_item->>'id','')::uuid;
  if v_id is null then
    insert into public.wardrobe_items(
      society_id,category_id,name,internal_code,age_group,gender_group,
      shoe_size,total_quantity,note
    ) values(
      p_society_id,v_category.id,btrim(p_item->>'name'),
      nullif(upper(btrim(p_item->>'internal_code')),''),
      coalesce(nullif(p_item->>'age_group',''),'UNIVERSAL'),
      coalesce(nullif(p_item->>'gender_group',''),'UNISEX'),
      nullif(p_item->>'shoe_size','')::integer,v_new_quantity,
      nullif(btrim(p_item->>'note'),'')
    ) returning id into v_id;
  else
    select to_jsonb(i) into v_old from public.wardrobe_items i
      where i.id=v_id and i.society_id=p_society_id for update;
    if v_old is null then raise exception 'Stavka nije pronađena.'; end if;
    select coalesce(sum(
      greatest(0,ai.issued_quantity-ai.returned_quantity)
    ),0)::integer into v_committed
    from public.wardrobe_assignment_items ai
    join public.wardrobe_assignments a on a.id=ai.assignment_id
    where ai.wardrobe_item_id=v_id and a.status<>'CANCELLED';
    if v_new_quantity<v_committed then
      raise exception 'Količina ne može biti manja od % jer je toliko komada vezano za zaduženja.',v_committed;
    end if;
    update public.wardrobe_items set
      category_id=v_category.id,name=btrim(p_item->>'name'),
      internal_code=nullif(upper(btrim(p_item->>'internal_code')),''),
      age_group=coalesce(nullif(p_item->>'age_group',''),'UNIVERSAL'),
      gender_group=coalesce(nullif(p_item->>'gender_group',''),'UNISEX'),
      shoe_size=nullif(p_item->>'shoe_size','')::integer,
      total_quantity=v_new_quantity,note=nullif(btrim(p_item->>'note'),''),
      is_active=coalesce((p_item->>'is_active')::boolean,true),updated_at=now()
    where id=v_id;
  end if;
  delete from public.wardrobe_item_repertoire where wardrobe_item_id=v_id;
  insert into public.wardrobe_item_repertoire(wardrobe_item_id,repertoire_item_id)
  select v_id,value::text::uuid
  from jsonb_array_elements_text(coalesce(p_item->'repertoire_ids','[]'::jsonb))
  where exists(select 1 from public.repertoire_items r
    where r.id=value::text::uuid and r.society_id=p_society_id);
  insert into public.wardrobe_audit_log(
    society_id,action,entity_type,entity_id,old_data,new_data,
    changed_by_user_id,changed_by_member_id
  ) select p_society_id,case when v_old is null then 'CREATE' else 'UPDATE' end,
    'ITEM',v_id,v_old,to_jsonb(i),auth.uid(),v_actor.member_id
    from public.wardrobe_items i where i.id=v_id;
  return v_id;
end;
$$;

create or replace function public.auth_get_wardrobe_operations(p_society_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare v_actor record;
begin
  select * into v_actor from public.auth_wardrobe_actor(p_society_id,false);
  return jsonb_build_object(
    'repairs',coalesce((
      select jsonb_agg(to_jsonb(r) || jsonb_build_object(
        'item_name',wi.name,
        'member_name',concat_ws(' ',ap.first_name,ap.last_name),
        'assigned_name',coalesce(concat_ws(' ',rp.first_name,rp.last_name),r.external_name)
      ) order by r.created_at desc)
      from public.wardrobe_repairs r
      join public.wardrobe_items wi on wi.id=r.wardrobe_item_id
      left join public.wardrobe_assignment_items ai on ai.id=r.assignment_item_id
      left join public.wardrobe_assignments a on a.id=ai.assignment_id
      left join public.society_members asm on asm.id=a.assigned_member_id
      left join public.people ap on ap.id=asm.person_id
      left join public.society_members rsm on rsm.id=r.assigned_member_id
      left join public.people rp on rp.id=rsm.person_id
      where r.society_id=p_society_id
        and (v_actor.is_manager or a.assigned_member_id=v_actor.member_id
          or r.assigned_member_id=v_actor.member_id)
    ),'[]'::jsonb),
    'loss_cases',coalesce((
      select jsonb_agg(to_jsonb(lc) || jsonb_build_object(
        'item_name',wi.name,'member_name',concat_ws(' ',p.first_name,p.last_name),
        'assignment_id',a.id,'assignment_title',coalesce(a.title,e.title,'Zaduženje')
      ) order by lc.created_at desc)
      from public.wardrobe_loss_cases lc
      join public.wardrobe_assignment_items ai on ai.id=lc.assignment_item_id
      join public.wardrobe_items wi on wi.id=ai.wardrobe_item_id
      join public.wardrobe_assignments a on a.id=ai.assignment_id
      join public.society_members sm on sm.id=a.assigned_member_id
      join public.people p on p.id=sm.person_id
      left join public.society_events e on e.id=a.event_id
      where a.society_id=p_society_id
        and (v_actor.is_manager or a.assigned_member_id=v_actor.member_id)
    ),'[]'::jsonb),
    'luggage',coalesce((
      select jsonb_agg(to_jsonb(l) || jsonb_build_object(
        'assignment_title',coalesce(a.title,l.name),
        'event_title',e.title,
        'responsible_name',concat_ws(' ',p.first_name,p.last_name),
        'handovers',coalesce((
          select jsonb_agg(to_jsonb(h) || jsonb_build_object(
            'previous_name',concat_ws(' ',pp.first_name,pp.last_name),
            'new_name',concat_ws(' ',np.first_name,np.last_name)
          ) order by h.created_at desc)
          from public.wardrobe_luggage_handovers h
          left join public.society_members psm on psm.id=h.previous_member_id
          left join public.people pp on pp.id=psm.person_id
          join public.society_members nsm on nsm.id=h.new_member_id
          join public.people np on np.id=nsm.person_id
          where h.luggage_id=l.id
        ),'[]'::jsonb)
      ) order by a.issued_at desc)
      from public.wardrobe_luggage l
      join public.wardrobe_assignments a on a.id=l.assignment_id
      left join public.society_events e on e.id=a.event_id
      join public.society_members sm on sm.id=l.responsible_member_id
      join public.people p on p.id=sm.person_id
      where a.society_id=p_society_id
        and (v_actor.is_manager or l.responsible_member_id=v_actor.member_id)
    ),'[]'::jsonb)
  );
end;
$$;

create or replace function public.auth_wardrobe_record_return(
  p_society_id uuid, p_assignment_id uuid, p_returns jsonb, p_note text default null
)
returns text
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_actor record; v_line jsonb; v_item public.wardrobe_assignment_items;
  v_remaining integer; v_quantity integer; v_result text;
begin
  select * into v_actor from public.auth_wardrobe_actor(p_society_id,true);
  if not exists(select 1 from public.wardrobe_assignments
    where id=p_assignment_id and society_id=p_society_id
      and status in ('OPEN','PARTIALLY_RETURNED','OVERDUE'))
  then raise exception 'Otvoreno zaduženje nije pronađeno.'; end if;
  for v_line in select * from jsonb_array_elements(p_returns) loop
    select * into v_item from public.wardrobe_assignment_items
      where id=(v_line->>'assignment_item_id')::uuid
        and assignment_id=p_assignment_id for update;
    if v_item.id is null then raise exception 'Stavka zaduženja nije pronađena.'; end if;
    v_remaining:=v_item.issued_quantity-v_item.returned_quantity-v_item.laundry_quantity-
      v_item.repair_quantity-v_item.lost_quantity-v_item.damaged_quantity;
    v_quantity:=coalesce((v_line->>'quantity')::integer,0);
    if v_quantity<=0 or v_quantity>v_remaining then
      raise exception 'Količina za razduženje nije ispravna.';
    end if;
    v_result:=v_line->>'result';
    if v_result not in ('RETURNED','LAUNDRY','REPAIR','DAMAGED','LOST') then
      raise exception 'Ishod razduženja nije dozvoljen.';
    end if;
    update public.wardrobe_assignment_items set
      returned_quantity=returned_quantity+case when v_result='RETURNED' then v_quantity else 0 end,
      laundry_quantity=laundry_quantity+case when v_result='LAUNDRY' then v_quantity else 0 end,
      repair_quantity=repair_quantity+case when v_result='REPAIR' then v_quantity else 0 end,
      damaged_quantity=damaged_quantity+case when v_result='DAMAGED' then v_quantity else 0 end,
      lost_quantity=lost_quantity+case when v_result='LOST' then v_quantity else 0 end
    where id=v_item.id;
    if v_result='LOST' then
      insert into public.wardrobe_loss_cases(assignment_item_id,quantity)
      values(v_item.id,v_quantity);
    elsif v_result='REPAIR' then
      insert into public.wardrobe_repairs(
        society_id,wardrobe_item_id,assignment_item_id,quantity,assignee_type,
        description,created_by_user_id,created_by_member_id
      ) values(
        p_society_id,v_item.wardrobe_item_id,v_item.id,v_quantity,'SOCIETY_PERSON',
        'Popravka evidentirana prilikom razduživanja',auth.uid(),v_actor.member_id
      );
    end if;
  end loop;
  update public.wardrobe_assignments a set
    status=case when not exists(
      select 1 from public.wardrobe_assignment_items ai where ai.assignment_id=a.id
      and ai.issued_quantity>ai.returned_quantity+ai.laundry_quantity+
        ai.repair_quantity+ai.lost_quantity+ai.damaged_quantity
    ) then 'RETURNED' else 'PARTIALLY_RETURNED' end,
    closed_at=case when not exists(
      select 1 from public.wardrobe_assignment_items ai where ai.assignment_id=a.id
      and ai.issued_quantity>ai.returned_quantity+ai.laundry_quantity+
        ai.repair_quantity+ai.lost_quantity+ai.damaged_quantity
    ) then now() else null end,updated_at=now()
  where a.id=p_assignment_id;
  insert into public.wardrobe_audit_log(
    society_id,action,entity_type,entity_id,reason,new_data,
    changed_by_user_id,changed_by_member_id
  ) select p_society_id,'RETURN','ASSIGNMENT',a.id,nullif(btrim(p_note),''),
    to_jsonb(a),auth.uid(),v_actor.member_id
    from public.wardrobe_assignments a where a.id=p_assignment_id;
  return (select status from public.wardrobe_assignments where id=p_assignment_id);
end;
$$;

create or replace function public.auth_wardrobe_update_repair(
  p_society_id uuid,p_repair_id uuid,p_changes jsonb
)
returns public.wardrobe_repairs
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_actor record; v_repair public.wardrobe_repairs;
  v_old jsonb; v_new_status text; v_result public.wardrobe_repairs;
begin
  select * into v_actor from public.auth_wardrobe_actor(p_society_id,true);
  select * into v_repair from public.wardrobe_repairs r
    where r.id=p_repair_id and r.society_id=p_society_id for update;
  if v_repair.id is null then raise exception 'Nalog za popravku nije pronađen.'; end if;
  v_old:=to_jsonb(v_repair);
  v_new_status:=coalesce(nullif(p_changes->>'status',''),v_repair.status);
  if v_new_status not in ('WAITING_HANDOVER','HANDED_OVER','IN_PROGRESS',
    'COMPLETED','RETURNED_TO_WARDROBE','UNREPAIRABLE')
  then raise exception 'Status popravke nije dozvoljen.'; end if;
  if nullif(p_changes->>'assigned_member_id','') is not null and not exists(
    select 1 from public.society_members sm
    where sm.id=(p_changes->>'assigned_member_id')::uuid
      and sm.society_id=p_society_id and sm.status='ACTIVE'
  ) then raise exception 'Izabrani član nije aktivan.'; end if;
  update public.wardrobe_repairs set
    assignee_type=coalesce(nullif(p_changes->>'assignee_type',''),assignee_type),
    assigned_member_id=nullif(p_changes->>'assigned_member_id','')::uuid,
    external_name=nullif(btrim(p_changes->>'external_name'),''),
    external_contact=nullif(btrim(p_changes->>'external_contact'),''),
    description=coalesce(nullif(btrim(p_changes->>'description'),''),description),
    due_date=nullif(p_changes->>'due_date','')::date,status=v_new_status,
    cost=nullif(p_changes->>'cost','')::numeric,
    note=nullif(btrim(p_changes->>'note'),''),
    completed_at=case when v_new_status in ('COMPLETED','RETURNED_TO_WARDROBE')
      then coalesce(completed_at,now()) else completed_at end,updated_at=now()
  where id=p_repair_id returning * into v_result;
  if v_new_status='RETURNED_TO_WARDROBE'
     and v_repair.status<>'RETURNED_TO_WARDROBE'
     and v_repair.assignment_item_id is not null then
    update public.wardrobe_assignment_items set
      repair_quantity=repair_quantity-v_repair.quantity,
      returned_quantity=returned_quantity+v_repair.quantity
    where id=v_repair.assignment_item_id and repair_quantity>=v_repair.quantity;
  end if;
  insert into public.wardrobe_audit_log(
    society_id,action,entity_type,entity_id,old_data,new_data,
    changed_by_user_id,changed_by_member_id
  ) values(p_society_id,'UPDATE','REPAIR',p_repair_id,v_old,to_jsonb(v_result),
    auth.uid(),v_actor.member_id);
  return v_result;
end;
$$;

create or replace function public.auth_wardrobe_resolve_loss(
  p_society_id uuid,p_loss_case_id uuid,p_resolution text,
  p_note text,p_replacement_quantity integer default 0
)
returns public.wardrobe_loss_cases
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_actor record; v_case public.wardrobe_loss_cases;
  v_assignment_item public.wardrobe_assignment_items;
  v_result public.wardrobe_loss_cases;
begin
  select * into v_actor from public.auth_wardrobe_actor(p_society_id,true);
  select lc.* into v_case
  from public.wardrobe_loss_cases lc
  join public.wardrobe_assignment_items ai on ai.id=lc.assignment_item_id
  join public.wardrobe_assignments a on a.id=ai.assignment_id
  where lc.id=p_loss_case_id and a.society_id=p_society_id for update of lc;
  if v_case.id is null then raise exception 'Slučaj gubitka nije pronađen.'; end if;
  if v_case.status='RESOLVED' then raise exception 'Slučaj gubitka je već rešen.'; end if;
  if p_resolution not in ('RETURNED','REPLACED','FINANCIAL','WRITTEN_OFF','OTHER')
  then raise exception 'Način rešavanja nije dozvoljen.'; end if;
  if nullif(btrim(p_note),'') is null then raise exception 'Napomena o rešenju je obavezna.'; end if;
  select * into v_assignment_item from public.wardrobe_assignment_items
    where id=v_case.assignment_item_id for update;
  if p_resolution='RETURNED' then
    update public.wardrobe_assignment_items set
      lost_quantity=lost_quantity-v_case.quantity,
      returned_quantity=returned_quantity+v_case.quantity
    where id=v_case.assignment_item_id and lost_quantity>=v_case.quantity;
  elsif p_resolution='REPLACED' then
    if p_replacement_quantity<=0 or p_replacement_quantity>v_case.quantity then
      raise exception 'Prihvaćena količina zamene nije ispravna.';
    end if;
    update public.wardrobe_items set
      total_quantity=total_quantity+p_replacement_quantity,updated_at=now()
    where id=v_assignment_item.wardrobe_item_id;
  end if;
  update public.wardrobe_loss_cases set
    status='RESOLVED',resolution_type=p_resolution,
    replacement_accepted_quantity=case when p_resolution='REPLACED'
      then p_replacement_quantity else 0 end,
    resolution_note=btrim(p_note),resolved_at=now(),resolved_by_user_id=auth.uid()
  where id=p_loss_case_id returning * into v_result;
  insert into public.wardrobe_audit_log(
    society_id,action,entity_type,entity_id,reason,new_data,
    changed_by_user_id,changed_by_member_id
  ) values(p_society_id,'RESOLVE','LOSS_CASE',p_loss_case_id,p_note,
    to_jsonb(v_result),auth.uid(),v_actor.member_id);
  return v_result;
end;
$$;

create or replace function public.auth_wardrobe_handover_luggage(
  p_society_id uuid,p_luggage_id uuid,p_new_member_id uuid,p_condition_note text
)
returns public.wardrobe_luggage
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_actor record; v_luggage public.wardrobe_luggage;
  v_result public.wardrobe_luggage;
begin
  select * into v_actor from public.auth_wardrobe_actor(p_society_id,true);
  select l.* into v_luggage
  from public.wardrobe_luggage l
  join public.wardrobe_assignments a on a.id=l.assignment_id
  where l.id=p_luggage_id and a.society_id=p_society_id for update of l;
  if v_luggage.id is null then raise exception 'Kofer nije pronađen.'; end if;
  if p_new_member_id=v_luggage.responsible_member_id then
    raise exception 'Izabrani član je već odgovoran za ovaj kofer.';
  end if;
  if not exists(select 1 from public.society_members sm
    where sm.id=p_new_member_id and sm.society_id=p_society_id and sm.status='ACTIVE')
  then raise exception 'Novi odgovorni član nije aktivan.'; end if;
  insert into public.wardrobe_luggage_handovers(
    luggage_id,previous_member_id,new_member_id,recorded_by_user_id,
    recorded_by_member_id,condition_note
  ) values(v_luggage.id,v_luggage.responsible_member_id,p_new_member_id,
    auth.uid(),v_actor.member_id,nullif(btrim(p_condition_note),''));
  update public.wardrobe_luggage set responsible_member_id=p_new_member_id,
    updated_at=now() where id=v_luggage.id returning * into v_result;
  update public.wardrobe_assignments set assigned_member_id=p_new_member_id,
    updated_at=now() where id=v_luggage.assignment_id;
  insert into public.wardrobe_audit_log(
    society_id,action,entity_type,entity_id,old_data,new_data,reason,
    changed_by_user_id,changed_by_member_id
  ) values(p_society_id,'HANDOVER','LUGGAGE',p_luggage_id,to_jsonb(v_luggage),
    to_jsonb(v_result),nullif(btrim(p_condition_note),''),
    auth.uid(),v_actor.member_id);
  return v_result;
end;
$$;

revoke all on function public.auth_wardrobe_get_item_repertoire(uuid,uuid)
  from public,anon;
grant execute on function public.auth_wardrobe_get_item_repertoire(uuid,uuid)
  to authenticated;
revoke all on function public.auth_wardrobe_save_item(uuid,jsonb)
  from public,anon;
grant execute on function public.auth_wardrobe_save_item(uuid,jsonb)
  to authenticated;
revoke all on function public.auth_get_wardrobe_operations(uuid) from public,anon;
revoke all on function public.auth_wardrobe_record_return(uuid,uuid,jsonb,text) from public,anon;
revoke all on function public.auth_wardrobe_update_repair(uuid,uuid,jsonb) from public,anon;
revoke all on function public.auth_wardrobe_resolve_loss(uuid,uuid,text,text,integer) from public,anon;
revoke all on function public.auth_wardrobe_handover_luggage(uuid,uuid,uuid,text) from public,anon;
grant execute on function public.auth_get_wardrobe_operations(uuid) to authenticated;
grant execute on function public.auth_wardrobe_record_return(uuid,uuid,jsonb,text) to authenticated;
grant execute on function public.auth_wardrobe_update_repair(uuid,uuid,jsonb) to authenticated;
grant execute on function public.auth_wardrobe_resolve_loss(uuid,uuid,text,text,integer) to authenticated;
grant execute on function public.auth_wardrobe_handover_luggage(uuid,uuid,uuid,text) to authenticated;

select pg_notify('pgrst','reload schema');
commit;
