-- FOLKLORAS — GARDEROBA V1
-- Kolicinski inventar, kompleti, zaduzenja, koferi, povrati, gubici i popravke.

begin;

alter table public.people add column if not exists shoe_size integer null;
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'people_shoe_size_check'
  ) then
    alter table public.people
      add constraint people_shoe_size_check
      check (shoe_size is null or shoe_size between 15 and 55);
  end if;
end $$;

create table if not exists public.wardrobe_settings (
  society_id uuid primary key references public.societies(id) on delete restrict,
  return_days_after_event integer not null default 3
    check (return_days_after_event between 0 and 90),
  reminder_days_before_due integer not null default 1
    check (reminder_days_before_due between 0 and 30),
  updated_at timestamptz not null default now(),
  updated_by_user_id uuid null
);

create table if not exists public.wardrobe_categories (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  name text not null,
  code text null,
  is_footwear boolean not null default false,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (society_id, name)
);

create table if not exists public.wardrobe_items (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  category_id uuid not null references public.wardrobe_categories(id) on delete restrict,
  name text not null,
  internal_code text null,
  age_group text not null default 'UNIVERSAL'
    check (age_group in ('CHILD', 'ADULT', 'UNIVERSAL')),
  gender_group text not null default 'UNISEX'
    check (gender_group in ('MALE', 'FEMALE', 'UNISEX')),
  shoe_size integer null check (shoe_size is null or shoe_size between 15 and 55),
  total_quantity integer not null default 0 check (total_quantity >= 0),
  note text null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists wardrobe_items_society_code_unique
  on public.wardrobe_items(society_id, lower(trim(internal_code)))
  where internal_code is not null;
create index if not exists wardrobe_items_society_category_idx
  on public.wardrobe_items(society_id, category_id, is_active);

create table if not exists public.wardrobe_item_repertoire (
  wardrobe_item_id uuid not null references public.wardrobe_items(id) on delete cascade,
  repertoire_item_id uuid not null references public.repertoire_items(id) on delete restrict,
  primary key (wardrobe_item_id, repertoire_item_id)
);

create table if not exists public.wardrobe_kits (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  name text not null,
  internal_code text null,
  age_group text not null default 'UNIVERSAL'
    check (age_group in ('CHILD', 'ADULT', 'UNIVERSAL')),
  gender_group text not null default 'UNISEX'
    check (gender_group in ('MALE', 'FEMALE', 'UNISEX')),
  note text null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (society_id, name)
);

create table if not exists public.wardrobe_kit_items (
  kit_id uuid not null references public.wardrobe_kits(id) on delete cascade,
  wardrobe_item_id uuid not null references public.wardrobe_items(id) on delete restrict,
  quantity integer not null default 1 check (quantity > 0),
  primary key (kit_id, wardrobe_item_id)
);

create table if not exists public.wardrobe_assignments (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  assignment_type text not null default 'MEMBER'
    check (assignment_type in ('MEMBER', 'LUGGAGE', 'EXTERNAL_LOAN', 'PLATFORM_LOAN')),
  assigned_member_id uuid null references public.society_members(id) on delete restrict,
  event_id uuid null references public.society_events(id) on delete restrict,
  recipient_society_id uuid null references public.societies(id) on delete restrict,
  external_recipient_name text null,
  external_contact text null,
  title text null,
  issued_at timestamptz not null default now(),
  due_date date null,
  status text not null default 'OPEN'
    check (status in ('OPEN', 'PARTIALLY_RETURNED', 'RETURNED', 'OVERDUE', 'CANCELLED')),
  note text null,
  issued_by_user_id uuid not null,
  issued_by_member_id uuid not null references public.society_members(id) on delete restrict,
  closed_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists wardrobe_assignments_society_status_idx
  on public.wardrobe_assignments(society_id, status, due_date);

create table if not exists public.wardrobe_assignment_items (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.wardrobe_assignments(id) on delete cascade,
  wardrobe_item_id uuid not null references public.wardrobe_items(id) on delete restrict,
  kit_id uuid null references public.wardrobe_kits(id) on delete restrict,
  issued_quantity integer not null check (issued_quantity > 0),
  returned_quantity integer not null default 0 check (returned_quantity >= 0),
  laundry_quantity integer not null default 0 check (laundry_quantity >= 0),
  repair_quantity integer not null default 0 check (repair_quantity >= 0),
  lost_quantity integer not null default 0 check (lost_quantity >= 0),
  damaged_quantity integer not null default 0 check (damaged_quantity >= 0),
  note text null,
  created_at timestamptz not null default now(),
  constraint wardrobe_assignment_item_quantities_check check (
    returned_quantity + laundry_quantity + repair_quantity +
    lost_quantity + damaged_quantity <= issued_quantity
  )
);

create table if not exists public.wardrobe_luggage (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null unique references public.wardrobe_assignments(id) on delete cascade,
  name text not null,
  responsible_member_id uuid not null references public.society_members(id) on delete restrict,
  status text not null default 'PACKED'
    check (status in ('PACKED', 'ISSUED', 'RETURNED', 'INCOMPLETE')),
  note text null,
  updated_at timestamptz not null default now()
);

create table if not exists public.wardrobe_luggage_handovers (
  id uuid primary key default gen_random_uuid(),
  luggage_id uuid not null references public.wardrobe_luggage(id) on delete restrict,
  previous_member_id uuid null references public.society_members(id) on delete restrict,
  new_member_id uuid not null references public.society_members(id) on delete restrict,
  recorded_by_user_id uuid not null,
  recorded_by_member_id uuid not null references public.society_members(id) on delete restrict,
  condition_note text null,
  created_at timestamptz not null default now()
);

create table if not exists public.wardrobe_loss_cases (
  id uuid primary key default gen_random_uuid(),
  assignment_item_id uuid not null references public.wardrobe_assignment_items(id) on delete restrict,
  quantity integer not null check (quantity > 0),
  status text not null default 'OPEN'
    check (status in ('OPEN', 'REPLACEMENT_PENDING', 'RESOLVED')),
  resolution_type text null
    check (resolution_type is null or resolution_type in
      ('RETURNED', 'REPLACED', 'FINANCIAL', 'WRITTEN_OFF', 'OTHER')),
  replacement_accepted_quantity integer not null default 0
    check (replacement_accepted_quantity >= 0),
  resolution_note text null,
  resolved_at timestamptz null,
  resolved_by_user_id uuid null,
  created_at timestamptz not null default now()
);

create table if not exists public.wardrobe_repairs (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  wardrobe_item_id uuid not null references public.wardrobe_items(id) on delete restrict,
  assignment_item_id uuid null references public.wardrobe_assignment_items(id) on delete restrict,
  quantity integer not null check (quantity > 0),
  assignee_type text not null
    check (assignee_type in ('MEMBER', 'GUARDIAN', 'SOCIETY_PERSON', 'EXTERNAL')),
  assigned_member_id uuid null references public.society_members(id) on delete restrict,
  external_name text null,
  external_contact text null,
  description text not null,
  due_date date null,
  status text not null default 'WAITING_HANDOVER'
    check (status in ('WAITING_HANDOVER', 'HANDED_OVER', 'IN_PROGRESS',
      'COMPLETED', 'RETURNED_TO_WARDROBE', 'UNREPAIRABLE')),
  cost numeric(12,2) null check (cost is null or cost >= 0),
  note text null,
  created_by_user_id uuid not null,
  created_by_member_id uuid not null references public.society_members(id) on delete restrict,
  completed_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.wardrobe_notifications (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  society_member_id uuid null references public.society_members(id) on delete restrict,
  person_id uuid null references public.people(id) on delete restrict,
  assignment_id uuid null references public.wardrobe_assignments(id) on delete restrict,
  repair_id uuid null references public.wardrobe_repairs(id) on delete restrict,
  notification_type text not null,
  channel text not null default 'IN_APP'
    check (channel in ('IN_APP', 'EMAIL')),
  title text not null,
  body text not null,
  scheduled_for timestamptz not null default now(),
  sent_at timestamptz null,
  read_at timestamptz null,
  created_at timestamptz not null default now()
);

create table if not exists public.wardrobe_audit_log (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete restrict,
  action text not null,
  entity_type text not null,
  entity_id uuid null,
  old_data jsonb null,
  new_data jsonb null,
  reason text null,
  changed_by_user_id uuid not null,
  changed_by_member_id uuid not null references public.society_members(id) on delete restrict,
  created_at timestamptz not null default now()
);

create index if not exists wardrobe_audit_society_created_idx
  on public.wardrobe_audit_log(society_id, created_at desc);

do $$
declare v_table text;
begin
  foreach v_table in array array[
    'wardrobe_settings','wardrobe_categories','wardrobe_items',
    'wardrobe_item_repertoire','wardrobe_kits','wardrobe_kit_items',
    'wardrobe_assignments','wardrobe_assignment_items','wardrobe_luggage',
    'wardrobe_luggage_handovers','wardrobe_loss_cases','wardrobe_repairs',
    'wardrobe_notifications','wardrobe_audit_log'
  ] loop
    execute format('alter table public.%I enable row level security', v_table);
    execute format('revoke all on table public.%I from public, anon, authenticated', v_table);
  end loop;
end $$;

insert into public.wardrobe_settings (society_id)
select id from public.societies on conflict (society_id) do nothing;

insert into public.wardrobe_categories
  (society_id, name, code, is_footwear, sort_order)
select s.id, seed.name, seed.code, seed.is_footwear, seed.sort_order
from public.societies s
cross join (values
  ('Košulja','KOS',false,10), ('Pantalone','PAN',false,20),
  ('Suknja','SUK',false,30), ('Jelek','JEL',false,40),
  ('Kecelja','KEC',false,50), ('Pojas','POJ',false,60),
  ('Kapa','KAP',false,70), ('Čarape','CAR',false,80),
  ('Opanci','OPA',true,90), ('Nakit','NAK',false,100),
  ('Rekvizit','REK',false,110), ('Ostalo','OST',false,120)
) as seed(name, code, is_footwear, sort_order)
on conflict (society_id, name) do nothing;

create or replace function public.auth_wardrobe_actor(
  p_society_id uuid,
  p_require_manager boolean default false
)
returns table(member_id uuid, person_id uuid, is_manager boolean)
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if auth.uid() is null then raise exception 'Prijava je obavezna.'; end if;
  return query
  select sm.id, sm.person_id,
    exists (
      select 1
      from public.society_member_function_assignments smfa
      join public.society_member_functions smf on smf.id = smfa.function_id
      where smfa.society_member_id = sm.id and smf.is_active
        and lower(smf.name) in ('predsednik', 'garderober')
    )
  from public.society_members sm
  join public.people p on p.id = sm.person_id
  where sm.society_id = p_society_id and sm.status = 'ACTIVE'
    and coalesce(sm.user_id, p.user_id) = auth.uid()
  limit 1;
  if not found then raise exception 'Aktivno članstvo nije pronađeno.'; end if;
  if p_require_manager and not (select a.is_manager from public.auth_wardrobe_actor(p_society_id, false) a)
  then raise exception 'Nemate ovlašćenje za upravljanje garderobom.'; end if;
end;
$$;

create or replace function public.auth_get_wardrobe_workspace(p_society_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_actor record;
  v_result jsonb;
begin
  select * into v_actor from public.auth_wardrobe_actor(p_society_id, false);

  select jsonb_build_object(
    'society_id', p_society_id,
    'actor_member_id', v_actor.member_id,
    'is_manager', v_actor.is_manager,
    'settings', coalesce((
      select to_jsonb(ws) from public.wardrobe_settings ws
      where ws.society_id = p_society_id
    ), jsonb_build_object('return_days_after_event',3,'reminder_days_before_due',1)),
    'categories', coalesce((
      select jsonb_agg(to_jsonb(c) order by c.sort_order, c.name)
      from public.wardrobe_categories c
      where c.society_id = p_society_id and (v_actor.is_manager or c.is_active)
    ), '[]'::jsonb),
    'items', coalesce((
      select jsonb_agg(
        to_jsonb(i) || jsonb_build_object(
          'category_name', c.name,
          'is_footwear', c.is_footwear,
          'assigned_quantity', coalesce(usage.assigned_quantity,0),
          'unavailable_quantity', coalesce(usage.unavailable_quantity,0),
          'available_quantity', greatest(0, i.total_quantity
            - coalesce(usage.assigned_quantity,0)
            - coalesce(usage.unavailable_quantity,0)),
          'repertoire_names', coalesce((
            select jsonb_agg(r.name order by r.name)
            from public.wardrobe_item_repertoire wir
            join public.repertoire_items r on r.id = wir.repertoire_item_id
            where wir.wardrobe_item_id = i.id
          ), '[]'::jsonb)
        ) order by c.sort_order, i.name, i.shoe_size
      )
      from public.wardrobe_items i
      join public.wardrobe_categories c on c.id = i.category_id
      left join lateral (
        select
          sum(greatest(0, ai.issued_quantity - ai.returned_quantity -
            ai.laundry_quantity - ai.repair_quantity - ai.lost_quantity -
            ai.damaged_quantity)) filter (
              where a.status in ('OPEN','PARTIALLY_RETURNED','OVERDUE')
          )::integer as assigned_quantity,
          sum(ai.laundry_quantity + ai.repair_quantity + ai.lost_quantity +
            ai.damaged_quantity)::integer as unavailable_quantity
        from public.wardrobe_assignment_items ai
        join public.wardrobe_assignments a on a.id = ai.assignment_id
        where ai.wardrobe_item_id = i.id and a.status <> 'CANCELLED'
      ) usage on true
      where i.society_id = p_society_id
        and (v_actor.is_manager or i.is_active)
    ), '[]'::jsonb),
    'kits', coalesce((
      select jsonb_agg(
        to_jsonb(k) || jsonb_build_object('items', coalesce((
          select jsonb_agg(jsonb_build_object(
            'wardrobe_item_id', ki.wardrobe_item_id,
            'name', wi.name,
            'shoe_size', wi.shoe_size,
            'quantity', ki.quantity
          ) order by wi.name, wi.shoe_size)
          from public.wardrobe_kit_items ki
          join public.wardrobe_items wi on wi.id = ki.wardrobe_item_id
          where ki.kit_id = k.id
        ), '[]'::jsonb))
        order by k.name
      )
      from public.wardrobe_kits k
      where k.society_id = p_society_id and (v_actor.is_manager or k.is_active)
    ), '[]'::jsonb),
    'assignments', coalesce((
      select jsonb_agg(
        to_jsonb(a) || jsonb_build_object(
          'member_name', concat_ws(' ', p.first_name, p.last_name),
          'event_title', e.title,
          'items', coalesce((
            select jsonb_agg(to_jsonb(ai) || jsonb_build_object(
              'item_name', wi.name, 'shoe_size', wi.shoe_size,
              'kit_name', wk.name
            ) order by wi.name)
            from public.wardrobe_assignment_items ai
            join public.wardrobe_items wi on wi.id = ai.wardrobe_item_id
            left join public.wardrobe_kits wk on wk.id = ai.kit_id
            where ai.assignment_id = a.id
          ), '[]'::jsonb)
        ) order by a.issued_at desc
      )
      from public.wardrobe_assignments a
      left join public.society_members sm on sm.id = a.assigned_member_id
      left join public.people p on p.id = sm.person_id
      left join public.society_events e on e.id = a.event_id
      where a.society_id = p_society_id
        and (v_actor.is_manager or a.assigned_member_id = v_actor.member_id)
    ),'[]'::jsonb),
    'members', case when v_actor.is_manager then coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',sm.id,'person_id',p.id,
        'name',concat_ws(' ',p.first_name,p.last_name),
        'shoe_size',p.shoe_size
      ) order by p.last_name,p.first_name)
      from public.society_members sm join public.people p on p.id=sm.person_id
      where sm.society_id=p_society_id and sm.status='ACTIVE'
    ),'[]'::jsonb) else '[]'::jsonb end,
    'events', case when v_actor.is_manager then coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',e.id,'title',e.title,'return_at',e.return_at
      ) order by e.departure_at desc nulls last)
      from public.society_events e
      where e.society_id=p_society_id and e.status not in ('CANCELLED','REJECTED')
    ),'[]'::jsonb) else '[]'::jsonb end,
    'repertoire', case when v_actor.is_manager then coalesce((
      select jsonb_agg(jsonb_build_object('id',r.id,'name',r.name) order by r.name)
      from public.repertoire_items r
      where r.society_id=p_society_id and r.status='ACTIVE'
    ),'[]'::jsonb) else '[]'::jsonb end
  ) into v_result;
  return v_result;
end;
$$;

create or replace function public.auth_wardrobe_save_category(
  p_society_id uuid, p_category jsonb
)
returns uuid
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare v_actor record; v_id uuid; v_old jsonb;
begin
  select * into v_actor from public.auth_wardrobe_actor(p_society_id,true);
  v_id := nullif(p_category->>'id','')::uuid;
  if nullif(btrim(p_category->>'name'),'') is null then
    raise exception 'Naziv kategorije je obavezan.';
  end if;
  if v_id is null then
    insert into public.wardrobe_categories
      (society_id,name,code,is_footwear,sort_order)
    values (p_society_id,btrim(p_category->>'name'),
      nullif(upper(btrim(p_category->>'code')),''),
      coalesce((p_category->>'is_footwear')::boolean,false),
      coalesce((p_category->>'sort_order')::integer,0))
    returning id into v_id;
  else
    select to_jsonb(c) into v_old from public.wardrobe_categories c
      where c.id=v_id and c.society_id=p_society_id for update;
    if v_old is null then raise exception 'Kategorija nije pronađena.'; end if;
    update public.wardrobe_categories set
      name=btrim(p_category->>'name'),
      code=nullif(upper(btrim(p_category->>'code')),''),
      is_footwear=coalesce((p_category->>'is_footwear')::boolean,false),
      is_active=coalesce((p_category->>'is_active')::boolean,true),
      updated_at=now()
    where id=v_id;
  end if;
  insert into public.wardrobe_audit_log
    (society_id,action,entity_type,entity_id,old_data,new_data,
     changed_by_user_id,changed_by_member_id)
  select p_society_id,case when v_old is null then 'CREATE' else 'UPDATE' end,
    'CATEGORY',v_id,v_old,to_jsonb(c),auth.uid(),v_actor.member_id
  from public.wardrobe_categories c where c.id=v_id;
  return v_id;
end;
$$;

create or replace function public.auth_wardrobe_save_item(
  p_society_id uuid, p_item jsonb
)
returns uuid
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare v_actor record; v_id uuid; v_old jsonb; v_category public.wardrobe_categories;
begin
  select * into v_actor from public.auth_wardrobe_actor(p_society_id,true);
  select * into v_category from public.wardrobe_categories
    where id=(p_item->>'category_id')::uuid and society_id=p_society_id and is_active;
  if v_category.id is null then raise exception 'Izaberite aktivnu kategoriju.'; end if;
  if nullif(btrim(p_item->>'name'),'') is null then raise exception 'Naziv je obavezan.'; end if;
  if not v_category.is_footwear and nullif(p_item->>'shoe_size','') is not null then
    raise exception 'Broj se unosi samo za obuću.';
  end if;
  v_id := nullif(p_item->>'id','')::uuid;
  if v_id is null then
    insert into public.wardrobe_items (
      society_id,category_id,name,internal_code,age_group,gender_group,
      shoe_size,total_quantity,note
    ) values (
      p_society_id,v_category.id,btrim(p_item->>'name'),
      nullif(upper(btrim(p_item->>'internal_code')),''),
      coalesce(nullif(p_item->>'age_group',''),'UNIVERSAL'),
      coalesce(nullif(p_item->>'gender_group',''),'UNISEX'),
      nullif(p_item->>'shoe_size','')::integer,
      coalesce((p_item->>'total_quantity')::integer,0),
      nullif(btrim(p_item->>'note'),'')
    ) returning id into v_id;
  else
    select to_jsonb(i) into v_old from public.wardrobe_items i
      where i.id=v_id and i.society_id=p_society_id for update;
    if v_old is null then raise exception 'Stavka nije pronađena.'; end if;
    update public.wardrobe_items set
      category_id=v_category.id,name=btrim(p_item->>'name'),
      internal_code=nullif(upper(btrim(p_item->>'internal_code')),''),
      age_group=coalesce(nullif(p_item->>'age_group',''),'UNIVERSAL'),
      gender_group=coalesce(nullif(p_item->>'gender_group',''),'UNISEX'),
      shoe_size=nullif(p_item->>'shoe_size','')::integer,
      total_quantity=(p_item->>'total_quantity')::integer,
      note=nullif(btrim(p_item->>'note'),''),
      is_active=coalesce((p_item->>'is_active')::boolean,true),updated_at=now()
    where id=v_id;
  end if;
  delete from public.wardrobe_item_repertoire where wardrobe_item_id=v_id;
  insert into public.wardrobe_item_repertoire(wardrobe_item_id,repertoire_item_id)
  select v_id, value::text::uuid
  from jsonb_array_elements_text(coalesce(p_item->'repertoire_ids','[]'::jsonb))
  where exists (
    select 1 from public.repertoire_items r
    where r.id=value::text::uuid and r.society_id=p_society_id
  );
  insert into public.wardrobe_audit_log
    (society_id,action,entity_type,entity_id,old_data,new_data,
     changed_by_user_id,changed_by_member_id)
  select p_society_id,case when v_old is null then 'CREATE' else 'UPDATE' end,
    'ITEM',v_id,v_old,to_jsonb(i),auth.uid(),v_actor.member_id
  from public.wardrobe_items i where i.id=v_id;
  return v_id;
end;
$$;

create or replace function public.auth_wardrobe_save_kit(
  p_society_id uuid, p_kit jsonb
)
returns uuid
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare v_actor record; v_id uuid; v_old jsonb; v_row jsonb;
begin
  select * into v_actor from public.auth_wardrobe_actor(p_society_id,true);
  if nullif(btrim(p_kit->>'name'),'') is null then raise exception 'Naziv kompleta je obavezan.'; end if;
  if jsonb_array_length(coalesce(p_kit->'items','[]'::jsonb))=0 then
    raise exception 'Komplet mora imati najmanje jednu stavku.';
  end if;
  v_id:=nullif(p_kit->>'id','')::uuid;
  if v_id is null then
    insert into public.wardrobe_kits
      (society_id,name,internal_code,age_group,gender_group,note)
    values (p_society_id,btrim(p_kit->>'name'),
      nullif(upper(btrim(p_kit->>'internal_code')),''),
      coalesce(nullif(p_kit->>'age_group',''),'UNIVERSAL'),
      coalesce(nullif(p_kit->>'gender_group',''),'UNISEX'),
      nullif(btrim(p_kit->>'note'),''))
    returning id into v_id;
  else
    select to_jsonb(k) into v_old from public.wardrobe_kits k
      where k.id=v_id and k.society_id=p_society_id for update;
    if v_old is null then raise exception 'Komplet nije pronađen.'; end if;
    update public.wardrobe_kits set name=btrim(p_kit->>'name'),
      internal_code=nullif(upper(btrim(p_kit->>'internal_code')),''),
      age_group=coalesce(nullif(p_kit->>'age_group',''),'UNIVERSAL'),
      gender_group=coalesce(nullif(p_kit->>'gender_group',''),'UNISEX'),
      note=nullif(btrim(p_kit->>'note'),''),
      is_active=coalesce((p_kit->>'is_active')::boolean,true),updated_at=now()
    where id=v_id;
  end if;
  delete from public.wardrobe_kit_items where kit_id=v_id;
  for v_row in select * from jsonb_array_elements(p_kit->'items') loop
    insert into public.wardrobe_kit_items(kit_id,wardrobe_item_id,quantity)
    select v_id,i.id,(v_row->>'quantity')::integer
    from public.wardrobe_items i
    where i.id=(v_row->>'wardrobe_item_id')::uuid
      and i.society_id=p_society_id and i.is_active;
  end loop;
  insert into public.wardrobe_audit_log
    (society_id,action,entity_type,entity_id,old_data,new_data,
     changed_by_user_id,changed_by_member_id)
  select p_society_id,case when v_old is null then 'CREATE' else 'UPDATE' end,
    'KIT',v_id,v_old,to_jsonb(k),auth.uid(),v_actor.member_id
  from public.wardrobe_kits k where k.id=v_id;
  return v_id;
end;
$$;

create or replace function public.auth_wardrobe_create_assignment(
  p_society_id uuid, p_assignment jsonb
)
returns uuid
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_actor record; v_id uuid; v_due date; v_event public.society_events;
  v_settings public.wardrobe_settings; v_line jsonb; v_kit_line record;
  v_available integer;
begin
  select * into v_actor from public.auth_wardrobe_actor(p_society_id,true);
  select * into v_settings from public.wardrobe_settings where society_id=p_society_id;
  if nullif(p_assignment->>'event_id','') is not null then
    select * into v_event from public.society_events
      where id=(p_assignment->>'event_id')::uuid and society_id=p_society_id;
    if v_event.id is null then raise exception 'Događaj nije pronađen.'; end if;
    v_due:=coalesce(nullif(p_assignment->>'due_date','')::date,
      coalesce(v_event.return_at::date,current_date)+v_settings.return_days_after_event);
  else
    v_due:=nullif(p_assignment->>'due_date','')::date;
  end if;
  if nullif(p_assignment->>'assigned_member_id','') is null then
    raise exception 'Izaberite odgovornog člana.';
  end if;
  if not exists(select 1 from public.society_members sm
    where sm.id=(p_assignment->>'assigned_member_id')::uuid
      and sm.society_id=p_society_id and sm.status='ACTIVE')
  then raise exception 'Izabrani član nije aktivan.'; end if;
  if jsonb_array_length(coalesce(p_assignment->'lines','[]'::jsonb))=0
     and jsonb_array_length(coalesce(p_assignment->'kit_ids','[]'::jsonb))=0
  then raise exception 'Zaduženje mora imati najmanje jednu stavku ili komplet.'; end if;

  insert into public.wardrobe_assignments(
    society_id,assignment_type,assigned_member_id,event_id,title,due_date,note,
    issued_by_user_id,issued_by_member_id
  ) values (
    p_society_id,coalesce(nullif(p_assignment->>'assignment_type',''),'MEMBER'),
    (p_assignment->>'assigned_member_id')::uuid,
    nullif(p_assignment->>'event_id','')::uuid,
    nullif(btrim(p_assignment->>'title'),''),
    v_due,nullif(btrim(p_assignment->>'note'),''),
    auth.uid(),v_actor.member_id
  ) returning id into v_id;

  for v_line in select * from jsonb_array_elements(coalesce(p_assignment->'lines','[]'::jsonb)) loop
    select i.total_quantity-coalesce(sum(greatest(0,ai.issued_quantity-ai.returned_quantity-
      ai.laundry_quantity-ai.repair_quantity-ai.lost_quantity-ai.damaged_quantity))
      filter(where a.status in ('OPEN','PARTIALLY_RETURNED','OVERDUE')),0)
    into v_available
    from public.wardrobe_items i
    left join public.wardrobe_assignment_items ai on ai.wardrobe_item_id=i.id
    left join public.wardrobe_assignments a on a.id=ai.assignment_id
    where i.id=(v_line->>'wardrobe_item_id')::uuid and i.society_id=p_society_id
    group by i.id;
    if v_available < (v_line->>'quantity')::integer then
      raise exception 'Nema dovoljno raspoložive količine za izabranu stavku.';
    end if;
    insert into public.wardrobe_assignment_items
      (assignment_id,wardrobe_item_id,issued_quantity,note)
    values(v_id,(v_line->>'wardrobe_item_id')::uuid,
      (v_line->>'quantity')::integer,nullif(v_line->>'note',''));
  end loop;

  for v_kit_line in
    select k.id as kit_id,ki.wardrobe_item_id,ki.quantity
    from jsonb_array_elements_text(coalesce(p_assignment->'kit_ids','[]'::jsonb)) x
    join public.wardrobe_kits k on k.id=x.value::uuid and k.society_id=p_society_id
    join public.wardrobe_kit_items ki on ki.kit_id=k.id
  loop
    select i.total_quantity-coalesce(sum(greatest(0,ai.issued_quantity-ai.returned_quantity-
      ai.laundry_quantity-ai.repair_quantity-ai.lost_quantity-ai.damaged_quantity))
      filter(where a.status in ('OPEN','PARTIALLY_RETURNED','OVERDUE')),0)
    into v_available
    from public.wardrobe_items i
    left join public.wardrobe_assignment_items ai on ai.wardrobe_item_id=i.id
    left join public.wardrobe_assignments a on a.id=ai.assignment_id
    where i.id=v_kit_line.wardrobe_item_id group by i.id;
    if v_available < v_kit_line.quantity then
      raise exception 'Komplet nije raspoloživ u potrebnoj količini.';
    end if;
    insert into public.wardrobe_assignment_items
      (assignment_id,wardrobe_item_id,kit_id,issued_quantity)
    values(v_id,v_kit_line.wardrobe_item_id,v_kit_line.kit_id,v_kit_line.quantity);
  end loop;

  if coalesce(nullif(p_assignment->>'assignment_type',''),'MEMBER')='LUGGAGE' then
    insert into public.wardrobe_luggage(assignment_id,name,responsible_member_id,note)
    values(v_id,coalesce(nullif(btrim(p_assignment->>'title'),''),'Zajednički kofer'),
      (p_assignment->>'assigned_member_id')::uuid,nullif(btrim(p_assignment->>'note'),''));
  end if;
  insert into public.wardrobe_audit_log(
    society_id,action,entity_type,entity_id,new_data,
    changed_by_user_id,changed_by_member_id
  ) select p_society_id,'ISSUE','ASSIGNMENT',v_id,to_jsonb(a),auth.uid(),v_actor.member_id
    from public.wardrobe_assignments a where a.id=v_id;
  return v_id;
end;
$$;

create or replace function public.auth_wardrobe_record_return(
  p_society_id uuid, p_assignment_id uuid, p_returns jsonb, p_note text default null
)
returns text
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare v_actor record; v_line jsonb; v_item public.wardrobe_assignment_items; v_remaining integer;
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
    if coalesce((v_line->>'quantity')::integer,0)<=0
       or (v_line->>'quantity')::integer>v_remaining then
      raise exception 'Količina za razduženje nije ispravna.';
    end if;
    update public.wardrobe_assignment_items set
      returned_quantity=returned_quantity+case when v_line->>'result'='RETURNED' then (v_line->>'quantity')::integer else 0 end,
      laundry_quantity=laundry_quantity+case when v_line->>'result'='LAUNDRY' then (v_line->>'quantity')::integer else 0 end,
      repair_quantity=repair_quantity+case when v_line->>'result'='REPAIR' then (v_line->>'quantity')::integer else 0 end,
      damaged_quantity=damaged_quantity+case when v_line->>'result'='DAMAGED' then (v_line->>'quantity')::integer else 0 end,
      lost_quantity=lost_quantity+case when v_line->>'result'='LOST' then (v_line->>'quantity')::integer else 0 end
    where id=v_item.id;
    if v_line->>'result'='LOST' then
      insert into public.wardrobe_loss_cases(assignment_item_id,quantity)
      values(v_item.id,(v_line->>'quantity')::integer);
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
    ) then now() else null end, updated_at=now()
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

create or replace function public.auth_wardrobe_save_settings(
  p_society_id uuid, p_return_days integer, p_reminder_days integer
)
returns public.wardrobe_settings
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare v_actor record; v_result public.wardrobe_settings;
begin
  select * into v_actor from public.auth_wardrobe_actor(p_society_id,true);
  insert into public.wardrobe_settings(
    society_id,return_days_after_event,reminder_days_before_due,updated_at,updated_by_user_id
  ) values(p_society_id,p_return_days,p_reminder_days,now(),auth.uid())
  on conflict(society_id) do update set
    return_days_after_event=excluded.return_days_after_event,
    reminder_days_before_due=excluded.reminder_days_before_due,
    updated_at=now(),updated_by_user_id=auth.uid()
  returning * into v_result;
  insert into public.wardrobe_audit_log(
    society_id,action,entity_type,entity_id,new_data,
    changed_by_user_id,changed_by_member_id
  ) values(p_society_id,'UPDATE','SETTINGS',p_society_id,to_jsonb(v_result),
    auth.uid(),v_actor.member_id);
  return v_result;
end;
$$;

-- Postojeci licni profil se prosiruje brojem obuce bez promene njegovih
-- postojecih pravila za licne podatke i dokumenta.
create or replace function public.auth_update_my_profile(p_profile jsonb)
returns public.people
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_member public.society_members;
  v_person public.people;
  v_result public.people;
  v_changed_fields text[] := array[]::text[];
  v_key text;
  v_allowed_keys constant text[] := array[
    'first_name', 'last_name', 'gender', 'birth_date', 'address', 'city',
    'postal_code', 'country', 'nationality', 'phone', 'shoe_size', 'jmbg',
    'passport_number', 'passport_issuing_country', 'passport_expiry_date'
  ];
begin
  if v_user_id is null then raise exception 'Prijava je obavezna.'; end if;
  select member.* into v_member
  from public.society_members member
  join public.people person on person.id=member.person_id
  join public.societies society on society.id=member.society_id
  where member.status='ACTIVE' and society.status='ACTIVE'
    and coalesce(member.user_id,person.user_id)=v_user_id
  order by member.created_at,member.id limit 1 for update of member;
  if v_member.id is null then raise exception 'Aktivni članski profil nije pronađen.'; end if;
  select * into v_person from public.people where id=v_member.person_id for update;
  if nullif(btrim(p_profile->>'first_name'),'') is null
     or nullif(btrim(p_profile->>'last_name'),'') is null
  then raise exception 'Ime i prezime su obavezni.'; end if;
  if (nullif(btrim(p_profile->>'passport_number'),'') is null)
     <> (nullif(p_profile->>'passport_expiry_date','') is null)
  then raise exception 'Broj pasoša i datum važenja moraju biti uneti zajedno.'; end if;
  if nullif(p_profile->>'shoe_size','') is not null
     and (p_profile->>'shoe_size')::integer not between 15 and 55
  then raise exception 'Broj obuće mora biti ceo broj od 15 do 55.'; end if;
  foreach v_key in array v_allowed_keys loop
    if to_jsonb(v_person)->>v_key is distinct from
       nullif(btrim(coalesce(p_profile->>v_key,'')),'')
    then v_changed_fields:=array_append(v_changed_fields,v_key); end if;
  end loop;
  update public.people set
    first_name=btrim(p_profile->>'first_name'),
    last_name=btrim(p_profile->>'last_name'),
    gender=nullif(btrim(p_profile->>'gender'),''),
    birth_date=nullif(p_profile->>'birth_date','')::date,
    address=nullif(btrim(p_profile->>'address'),''),
    city=nullif(btrim(p_profile->>'city'),''),
    postal_code=nullif(btrim(p_profile->>'postal_code'),''),
    country=coalesce(nullif(btrim(p_profile->>'country'),''),'Srbija'),
    nationality=nullif(btrim(p_profile->>'nationality'),''),
    phone=nullif(btrim(p_profile->>'phone'),''),
    shoe_size=nullif(p_profile->>'shoe_size','')::integer,
    jmbg=nullif(btrim(p_profile->>'jmbg'),''),
    passport_number=nullif(btrim(p_profile->>'passport_number'),''),
    passport_issuing_country=nullif(btrim(p_profile->>'passport_issuing_country'),''),
    passport_expiry_date=nullif(p_profile->>'passport_expiry_date','')::date,
    updated_at=now()
  where id=v_person.id returning * into v_result;
  if cardinality(v_changed_fields)>0 then
    insert into public.person_profile_change_history(
      society_id,society_member_id,person_id,changed_fields,changed_by_user_id
    ) values(v_member.society_id,v_member.id,v_person.id,v_changed_fields,v_user_id);
  end if;
  return v_result;
end;
$$;

revoke all on function public.auth_wardrobe_actor(uuid,boolean) from public,anon,authenticated;
revoke all on function public.auth_get_wardrobe_workspace(uuid) from public,anon;
revoke all on function public.auth_wardrobe_save_category(uuid,jsonb) from public,anon;
revoke all on function public.auth_wardrobe_save_item(uuid,jsonb) from public,anon;
revoke all on function public.auth_wardrobe_save_kit(uuid,jsonb) from public,anon;
revoke all on function public.auth_wardrobe_create_assignment(uuid,jsonb) from public,anon;
revoke all on function public.auth_wardrobe_record_return(uuid,uuid,jsonb,text) from public,anon;
revoke all on function public.auth_wardrobe_save_settings(uuid,integer,integer) from public,anon;
grant execute on function public.auth_get_wardrobe_workspace(uuid) to authenticated;
grant execute on function public.auth_wardrobe_save_category(uuid,jsonb) to authenticated;
grant execute on function public.auth_wardrobe_save_item(uuid,jsonb) to authenticated;
grant execute on function public.auth_wardrobe_save_kit(uuid,jsonb) to authenticated;
grant execute on function public.auth_wardrobe_create_assignment(uuid,jsonb) to authenticated;
grant execute on function public.auth_wardrobe_record_return(uuid,uuid,jsonb,text) to authenticated;
grant execute on function public.auth_wardrobe_save_settings(uuid,integer,integer) to authenticated;
revoke all on function public.auth_update_my_profile(jsonb) from public,anon;
grant execute on function public.auth_update_my_profile(jsonb) to authenticated;

select pg_notify('pgrst','reload schema');
commit;
