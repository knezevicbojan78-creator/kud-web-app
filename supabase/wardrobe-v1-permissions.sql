-- FOLKLORAS — GARDEROBA V1 / CENTRALNE DOZVOLE I LICNI PREGLED
begin;

insert into public.permission_catalog(
  permission_key,module_key,label,description,action_type,allowed_scopes,
  is_sensitive,requires_reason,is_president_only
) values
  ('wardrobe.view','wardrobe','Pregled garderobe',
   'Pregled sopstvenih, dečjih ili svih zaduženja garderobe.',
   'VIEW',array['SELF','CHILDREN','SOCIETY'],false,false,false),
  ('wardrobe.manage','wardrobe','Upravljanje garderobom',
   'Inventar, kompleti, izdavanje, razduživanje, koferi, popravke, gubici, pozajmice i rokovi.',
   'MANAGE',array['SOCIETY'],true,false,false),
  ('wardrobe.view_audit','wardrobe','Detaljni audit garderobe',
   'Pregled pune istorije poslovnih promena garderobe.',
   'VIEW',array['SOCIETY'],true,false,false)
on conflict(permission_key) do update set
  module_key=excluded.module_key,label=excluded.label,
  description=excluded.description,action_type=excluded.action_type,
  allowed_scopes=excluded.allowed_scopes,is_sensitive=excluded.is_sensitive,
  requires_reason=excluded.requires_reason,
  is_president_only=excluded.is_president_only,is_active=true,updated_at=now();

insert into public.system_function_permission_templates(
  function_name,permission_id,scope_key,is_locked
)
select 'Predsednik',pc.id,'SOCIETY',true from public.permission_catalog pc
where pc.permission_key in ('wardrobe.view','wardrobe.manage','wardrobe.view_audit')
on conflict(function_name,permission_id) do update set
  scope_key=excluded.scope_key,is_locked=excluded.is_locked,updated_at=now();

insert into public.system_function_permission_templates(
  function_name,permission_id,scope_key,is_locked
)
select 'Garderober',pc.id,'SOCIETY',true from public.permission_catalog pc
where pc.permission_key in ('wardrobe.view','wardrobe.manage')
on conflict(function_name,permission_id) do update set
  scope_key=excluded.scope_key,is_locked=excluded.is_locked,updated_at=now();

insert into public.system_function_permission_templates(
  function_name,permission_id,scope_key,is_locked
)
select names.function_name,pc.id,'SELF',true
from (values('Clan'),('Član')) names(function_name)
cross join public.permission_catalog pc where pc.permission_key='wardrobe.view'
on conflict(function_name,permission_id) do update set
  scope_key=excluded.scope_key,is_locked=excluded.is_locked,updated_at=now();

insert into public.society_function_permission_rules(
  society_id,function_id,permission_id,scope_key,is_locked
)
select smf.society_id,smf.id,t.permission_id,t.scope_key,t.is_locked
from public.society_member_functions smf
join public.system_function_permission_templates t
  on lower(btrim(t.function_name))=lower(btrim(smf.name))
join public.permission_catalog pc on pc.id=t.permission_id and pc.module_key='wardrobe'
where smf.is_active
on conflict(function_id,permission_id) do nothing;

create or replace function public.auth_wardrobe_actor(
  p_society_id uuid,p_require_manager boolean default false
)
returns table(member_id uuid,person_id uuid,is_manager boolean)
language plpgsql stable security definer
set search_path=public,auth,pg_temp
as $$
declare v_person_id uuid; v_member_id uuid; v_is_manager boolean:=false;
begin
  if auth.uid() is null then raise exception 'Prijava je obavezna.'; end if;
  select p.id into v_person_id from public.people p
  where p.user_id=auth.uid() or exists(
    select 1 from public.society_members linked
    where linked.person_id=p.id and linked.user_id=auth.uid()
  ) order by case when p.user_id=auth.uid() then 0 else 1 end,p.id limit 1;
  if v_person_id is null then raise exception 'Osoba prijavljenog korisnika nije pronađena.'; end if;

  select sm.id into v_member_id from public.society_members sm
  where sm.society_id=p_society_id and sm.person_id=v_person_id and sm.status='ACTIVE'
  order by sm.id limit 1;
  if v_member_id is null and not exists(
    select 1 from public.person_guardians pg
    join public.society_members child on child.person_id=pg.child_person_id
      and child.society_id=p_society_id and child.status='ACTIVE'
    where pg.guardian_person_id=v_person_id
  ) then raise exception 'Nemate pristup garderobi ovog društva.'; end if;

  if v_member_id is not null then
    v_is_manager:=public.permissions_has_scope(
      p_society_id,v_member_id,v_person_id,'wardrobe.manage',array['SOCIETY']
    );
  end if;
  if p_require_manager and not v_is_manager then
    raise exception 'Nemate dozvolu za upravljanje garderobom.';
  end if;
  return query select v_member_id,v_person_id,v_is_manager;
end;
$$;

create or replace function public.auth_get_wardrobe_page(p_society_id uuid)
returns jsonb language plpgsql security definer
set search_path=public,auth,pg_temp
as $$
declare v_actor record; v_base jsonb; v_assignments jsonb;
begin
  select * into v_actor from public.auth_wardrobe_actor(p_society_id,false);
  v_base:=public.auth_get_wardrobe_workspace(p_society_id);
  if v_actor.is_manager then
    return v_base||jsonb_build_object(
      'access',jsonb_build_object('scope','SOCIETY','can_manage',true));
  end if;

  select coalesce(jsonb_agg(
    to_jsonb(a)||jsonb_build_object(
      'member_name',concat_ws(' ',p.first_name,p.last_name),'event_title',e.title,
      'items',coalesce((
        select jsonb_agg(to_jsonb(ai)||jsonb_build_object(
          'item_name',wi.name,'shoe_size',wi.shoe_size,'kit_name',wk.name
        ) order by wi.name)
        from public.wardrobe_assignment_items ai
        join public.wardrobe_items wi on wi.id=ai.wardrobe_item_id
        left join public.wardrobe_kits wk on wk.id=ai.kit_id
        where ai.assignment_id=a.id
      ),'[]'::jsonb)
    ) order by a.issued_at desc
  ),'[]'::jsonb) into v_assignments
  from public.wardrobe_assignments a
  join public.society_members sm on sm.id=a.assigned_member_id
  join public.people p on p.id=sm.person_id
  left join public.society_events e on e.id=a.event_id
  where a.society_id=p_society_id and (
    a.assigned_member_id=v_actor.member_id or exists(
      select 1 from public.person_guardians pg
      where pg.guardian_person_id=v_actor.person_id and pg.child_person_id=sm.person_id
    )
  );

  return (v_base-'categories'-'items'-'kits'-'members'-'events'-'repertoire')
    ||jsonb_build_object(
      'categories','[]'::jsonb,'items','[]'::jsonb,'kits','[]'::jsonb,
      'members','[]'::jsonb,'events','[]'::jsonb,'repertoire','[]'::jsonb,
      'assignments',v_assignments,'access',jsonb_build_object(
        'scope',case when v_actor.member_id is null then 'CHILDREN'
          else 'SELF_AND_CHILDREN' end,'can_manage',false));
end;
$$;

revoke all on function public.auth_get_wardrobe_page(uuid) from public,anon;
grant execute on function public.auth_get_wardrobe_page(uuid) to authenticated;
revoke all on function public.auth_wardrobe_actor(uuid,boolean)
  from public,anon,authenticated;
select pg_notify('pgrst','reload schema');
commit;
