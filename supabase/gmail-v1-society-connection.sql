begin;

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.society_gmail_connections (
  society_id uuid primary key references public.societies(id) on delete cascade,
  google_account_id text not null,
  email text not null,
  encrypted_refresh_token bytea not null,
  encrypted_access_token bytea null,
  access_token_expires_at timestamptz null,
  connected_by_user_id uuid not null references auth.users(id) on delete restrict,
  connected_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint society_gmail_connections_email_check
    check (position('@' in email) > 1)
);

alter table public.society_gmail_connections enable row level security;
revoke all on table public.society_gmail_connections from public, anon, authenticated;

create table if not exists public.society_gmail_connection_history (
  id uuid primary key default gen_random_uuid(),
  society_id uuid not null references public.societies(id) on delete cascade,
  action text not null check (action in ('CONNECTED', 'REPLACED', 'DISCONNECTED')),
  email text not null,
  actor_user_id uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

alter table public.society_gmail_connection_history enable row level security;
revoke all on table public.society_gmail_connection_history from public, anon, authenticated;

create or replace function public.gmail_assert_president(p_society_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_member_id uuid;
begin
  select member.id into v_member_id
  from public.society_members member
  join public.society_member_function_assignments assignment
    on assignment.society_member_id = member.id
  join public.society_member_functions member_function
    on member_function.id = assignment.function_id
  where member.society_id = p_society_id
    and member.user_id = auth.uid()
    and member.status = 'ACTIVE'
    and member_function.name = 'Predsednik'
    and member_function.is_active
  limit 1;

  if v_member_id is null then
    raise exception 'Samo predsednik može da upravlja Gmail povezivanjem.';
  end if;

  return v_member_id;
end;
$$;

create or replace function public.auth_get_society_gmail_connection(p_society_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_member_id uuid := public.gmail_assert_president(p_society_id);
begin
  return coalesce((
    select jsonb_build_object(
      'connected', true,
      'email', connection.email,
      'connected_at', connection.connected_at,
      'updated_at', connection.updated_at
    )
    from public.society_gmail_connections connection
    where connection.society_id = p_society_id
  ), jsonb_build_object('connected', false));
end;
$$;

create or replace function public.auth_save_society_gmail_connection(
  p_society_id uuid,
  p_google_account_id text,
  p_email text,
  p_refresh_token text,
  p_access_token text,
  p_access_token_expires_at timestamptz,
  p_encryption_secret text
) returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions, pg_temp
as $$
declare
  v_member_id uuid := public.gmail_assert_president(p_society_id);
  v_previous_email text;
  v_previous_refresh_token text;
  v_action text;
begin
  if length(coalesce(p_encryption_secret, '')) < 32 then
    raise exception 'Gmail enkripcioni ključ nije ispravno podešen.';
  end if;
  if length(coalesce(p_refresh_token, '')) < 10 then
    raise exception 'Google nije vratio trajnu dozvolu. Ponovite povezivanje.';
  end if;

  select connection.email,
         extensions.pgp_sym_decrypt(connection.encrypted_refresh_token, p_encryption_secret)
    into v_previous_email, v_previous_refresh_token
  from public.society_gmail_connections connection
  where connection.society_id = p_society_id;

  v_action := case when v_previous_email is null then 'CONNECTED' else 'REPLACED' end;

  insert into public.society_gmail_connections (
    society_id, google_account_id, email,
    encrypted_refresh_token, encrypted_access_token, access_token_expires_at,
    connected_by_user_id, connected_at, updated_at
  ) values (
    p_society_id, p_google_account_id, lower(btrim(p_email)),
    extensions.pgp_sym_encrypt(p_refresh_token, p_encryption_secret),
    case when p_access_token is null then null
      else extensions.pgp_sym_encrypt(p_access_token, p_encryption_secret) end,
    p_access_token_expires_at, auth.uid(), now(), now()
  )
  on conflict (society_id) do update set
    google_account_id = excluded.google_account_id,
    email = excluded.email,
    encrypted_refresh_token = excluded.encrypted_refresh_token,
    encrypted_access_token = excluded.encrypted_access_token,
    access_token_expires_at = excluded.access_token_expires_at,
    connected_by_user_id = excluded.connected_by_user_id,
    connected_at = excluded.connected_at,
    updated_at = now();

  insert into public.society_gmail_connection_history (
    society_id, action, email, actor_user_id
  ) values (
    p_society_id, v_action, lower(btrim(p_email)), auth.uid()
  );

  return jsonb_build_object(
    'connected', true,
    'email', lower(btrim(p_email)),
    'replaced', v_previous_email is not null,
    'previous_email', v_previous_email,
    'previous_refresh_token', v_previous_refresh_token
  );
end;
$$;

create or replace function public.auth_disconnect_society_gmail(
  p_society_id uuid,
  p_encryption_secret text
) returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions, pg_temp
as $$
declare
  v_member_id uuid := public.gmail_assert_president(p_society_id);
  v_email text;
  v_refresh_token text;
begin
  select connection.email,
         extensions.pgp_sym_decrypt(connection.encrypted_refresh_token, p_encryption_secret)
    into v_email, v_refresh_token
  from public.society_gmail_connections connection
  where connection.society_id = p_society_id;

  if v_email is null then
    return jsonb_build_object('disconnected', false);
  end if;

  delete from public.society_gmail_connections
  where society_id = p_society_id;

  insert into public.society_gmail_connection_history (
    society_id, action, email, actor_user_id
  ) values (
    p_society_id, 'DISCONNECTED', v_email, auth.uid()
  );

  return jsonb_build_object(
    'disconnected', true,
    'email', v_email,
    'refresh_token', v_refresh_token
  );
end;
$$;

revoke all on function public.gmail_assert_president(uuid) from public, anon, authenticated;
revoke all on function public.auth_get_society_gmail_connection(uuid) from public, anon;
revoke all on function public.auth_save_society_gmail_connection(
  uuid, text, text, text, text, timestamptz, text
) from public, anon;
revoke all on function public.auth_disconnect_society_gmail(uuid, text) from public, anon;

grant execute on function public.auth_get_society_gmail_connection(uuid) to authenticated;
grant execute on function public.auth_save_society_gmail_connection(
  uuid, text, text, text, text, timestamptz, text
) to authenticated;
grant execute on function public.auth_disconnect_society_gmail(uuid, text) to authenticated;

select pg_notify('pgrst', 'reload schema');
commit;
