begin;

create table if not exists public.custom_plan_inquiries (
  id uuid primary key default gen_random_uuid(),
  first_name text not null,
  last_name text not null,
  phone text not null,
  email text not null,
  message text not null,
  status text not null default 'NEW' check (status in ('NEW', 'CONTACTED', 'CLOSED')),
  created_at timestamptz not null default now()
);

alter table public.custom_plan_inquiries enable row level security;
revoke all on table public.custom_plan_inquiries from public, anon, authenticated;

create or replace function public.auth_submit_custom_plan_inquiry(
  p_first_name text,
  p_last_name text,
  p_phone text,
  p_email text,
  p_message text,
  p_website text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id uuid;
begin
  if nullif(btrim(coalesce(p_website, '')), '') is not null then
    return jsonb_build_object('status', 'RECEIVED');
  end if;
  if char_length(btrim(coalesce(p_first_name, ''))) not between 2 and 80
     or char_length(btrim(coalesce(p_last_name, ''))) not between 2 and 80 then
    raise exception 'Unesite ime i prezime.';
  end if;
  if char_length(btrim(coalesce(p_phone, ''))) not between 6 and 40 then
    raise exception 'Unesite ispravan telefon.';
  end if;
  if lower(btrim(coalesce(p_email, ''))) !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
     or char_length(btrim(p_email)) > 254 then
    raise exception 'Unesite ispravnu email adresu.';
  end if;
  if char_length(btrim(coalesce(p_message, ''))) not between 10 and 3000 then
    raise exception 'Upit mora imati između 10 i 3000 karaktera.';
  end if;

  insert into public.custom_plan_inquiries(first_name, last_name, phone, email, message)
  values (btrim(p_first_name), btrim(p_last_name), btrim(p_phone), lower(btrim(p_email)), btrim(p_message))
  returning id into v_id;

  return jsonb_build_object('inquiry_id', v_id, 'status', 'NEW');
end;
$$;

revoke all on function public.auth_submit_custom_plan_inquiry(text,text,text,text,text,text) from public, anon, authenticated;
grant execute on function public.auth_submit_custom_plan_inquiry(text,text,text,text,text,text) to anon, authenticated;

create or replace function public.master_admin_get_custom_plan_inquiries()
returns setof public.custom_plan_inquiries
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
begin
  perform public.auth_assert_master_admin();
  return query select inquiry.* from public.custom_plan_inquiries inquiry order by inquiry.created_at desc;
end;
$$;

revoke all on function public.master_admin_get_custom_plan_inquiries() from public, anon, authenticated;
grant execute on function public.master_admin_get_custom_plan_inquiries() to authenticated;

commit;
