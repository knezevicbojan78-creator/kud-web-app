-- FOLKLORAS — zajednička evidencija i Gmail slanje poslovnih emailova.
-- Proširuje postojeći finansijski outbox bez gubitka istorije.

begin;

create extension if not exists pgcrypto with schema extensions;

do $$
begin
  if to_regclass('public.society_email_outbox') is null
     and to_regclass('public.financial_email_outbox') is not null then
    alter table public.financial_email_outbox rename to society_email_outbox;
  end if;
end
$$;

alter table public.society_email_outbox
  drop constraint if exists financial_email_outbox_message_type_check;
alter table public.society_email_outbox
  drop constraint if exists society_email_outbox_message_type_check;
alter table public.society_email_outbox
  add constraint society_email_outbox_message_type_check check (
    message_type in (
      'MEMBER_DATA_INVITATION',
      'GUARDIAN_DATA_INVITATION',
      'PAYMENT_CONFIRMATION',
      'PAYMENT_VOIDED',
      'PAYMENT_REMINDER'
    )
  );

alter table public.society_email_outbox
  add column if not exists member_invitation_id uuid
    references public.member_data_invitations(id) on delete restrict,
  add column if not exists related_person_id uuid
    references public.people(id) on delete restrict,
  add column if not exists recipient_name text,
  add column if not exists sender_email text,
  add column if not exists template_key text,
  add column if not exists template_version integer not null default 1,
  add column if not exists initiated_by_user_id uuid,
  add column if not exists initiation_type text not null default 'AUTOMATIC',
  add column if not exists encrypted_delivery_payload bytea,
  add column if not exists cancelled_at timestamptz;

alter table public.society_email_outbox
  drop constraint if exists society_email_outbox_initiation_type_check;
alter table public.society_email_outbox
  add constraint society_email_outbox_initiation_type_check
    check (initiation_type in ('BUSINESS_ACTION', 'AUTOMATIC'));

alter table public.society_email_outbox
  drop constraint if exists financial_email_outbox_status_check;
alter table public.society_email_outbox
  drop constraint if exists society_email_outbox_status_check;
alter table public.society_email_outbox
  add constraint society_email_outbox_status_check
    check (status in ('PENDING', 'SENDING', 'SENT', 'FAILED', 'CANCELLED'));

alter table public.society_email_outbox enable row level security;
revoke all on public.society_email_outbox from public, anon, authenticated;

create table if not exists public.society_email_delivery_attempts (
  id uuid primary key default gen_random_uuid(),
  outbox_id uuid not null references public.society_email_outbox(id) on delete restrict,
  attempt_number integer not null check (attempt_number > 0),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  status text not null check (status in ('SENDING', 'SENT', 'FAILED')),
  provider_message_id text,
  error text,
  unique (outbox_id, attempt_number)
);

alter table public.society_email_delivery_attempts enable row level security;
revoke all on public.society_email_delivery_attempts from public, anon, authenticated;

create index if not exists society_email_outbox_society_created_idx
  on public.society_email_outbox(society_id, created_at desc);
create index if not exists society_email_attempts_outbox_idx
  on public.society_email_delivery_attempts(outbox_id, attempt_number desc);

insert into public.permission_catalog (
  permission_key, module_key, label, description, action_type, allowed_scopes,
  is_sensitive, requires_reason, is_president_only, is_active
) values (
  'reports.email_log.view',
  'reports',
  'Pregled evidencije emailova',
  'Pregled vremena, primalaca, statusa i pokušaja automatskih poslovnih emailova.',
  'VIEW',
  array['SOCIETY']::text[],
  true,
  false,
  false,
  true
)
on conflict (permission_key) do update set
  module_key = excluded.module_key,
  label = excluded.label,
  description = excluded.description,
  action_type = excluded.action_type,
  allowed_scopes = excluded.allowed_scopes,
  is_sensitive = excluded.is_sensitive,
  requires_reason = excluded.requires_reason,
  is_president_only = excluded.is_president_only,
  is_active = true,
  updated_at = now();

insert into public.system_function_permission_templates (
  function_name, permission_id, scope_key, is_locked
)
select 'Predsednik', id, 'SOCIETY', true
from public.permission_catalog
where permission_key = 'reports.email_log.view'
on conflict (function_name, permission_id) do update set
  scope_key = excluded.scope_key,
  is_locked = excluded.is_locked,
  updated_at = now();

insert into public.society_function_permission_rules (
  society_id, function_id, permission_id, scope_key, is_locked
)
select function.society_id, function.id, permission.id, 'SOCIETY', true
from public.society_member_functions function
cross join public.permission_catalog permission
where function.name = 'Predsednik'
  and function.is_active
  and permission.permission_key = 'reports.email_log.view'
on conflict (function_id, permission_id) do update set
  scope_key = excluded.scope_key,
  is_locked = true,
  updated_at = now();

create or replace function public.gmail_actor_member(p_society_id uuid)
returns table(member_id uuid, person_id uuid)
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select member.id, member.person_id
  from public.society_members member
  join public.people person on person.id = member.person_id
  where member.society_id = p_society_id
    and member.status = 'ACTIVE'
    and coalesce(member.user_id, person.user_id) = auth.uid()
  limit 1
$$;

create or replace function public.auth_queue_member_data_invitation_email(
  p_society_id uuid,
  p_candidate_id uuid,
  p_recipient_role text,
  p_invitation_url text,
  p_encryption_secret text
) returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions, pg_temp
as $$
declare
  v_invitation public.member_data_invitations%rowtype;
  v_candidate public.member_import_candidates%rowtype;
  v_society_name text;
  v_sender_email text;
  v_recipient_name text;
  v_subject text;
  v_text text;
  v_html text;
  v_outbox_id uuid;
begin
  perform public.gmail_assert_president(p_society_id);
  if length(coalesce(p_encryption_secret, '')) < 32 then
    raise exception 'Gmail enkripcioni ključ nije ispravno podešen.';
  end if;
  select invitation.* into v_invitation
  from public.member_data_invitations invitation
  where invitation.candidate_id = p_candidate_id
    and invitation.society_id = p_society_id
    and invitation.recipient_role = p_recipient_role
    and invitation.status in ('INVITED', 'OPENED', 'IN_PROGRESS');
  if v_invitation.id is null then raise exception 'Poziv nije pronađen.'; end if;

  select * into v_candidate from public.member_import_candidates where id = p_candidate_id;
  select society.name, connection.email into v_society_name, v_sender_email
  from public.societies society
  left join public.society_gmail_connections connection on connection.society_id = society.id
  where society.id = p_society_id;
  if v_sender_email is null then raise exception 'Gmail nalog društva nije povezan.'; end if;

  v_recipient_name := concat_ws(' ', v_candidate.profile->>'first_name', v_candidate.profile->>'last_name');
  v_subject := case when p_recipient_role = 'GUARDIAN'
    then 'Dopunite podatke za ' || v_recipient_name || ' – ' || v_society_name
    else 'Dopunite podatke za članstvo u ' || v_society_name end;
  v_text := 'Poštovani/a,' || E'\n\n' ||
    case when p_recipient_role = 'GUARDIAN'
      then 'Dopunite podatke za ' || v_recipient_name || '.'
      else 'Dopunite podatke potrebne za Vaše članstvo.' end ||
    E'\n\n' || p_invitation_url ||
    E'\n\nLink važi do ' || to_char(v_invitation.expires_at at time zone 'Europe/Belgrade', 'DD.MM.YYYY. HH24:MI') ||
    E'. Podatke možete sačuvati i nastaviti kasnije. Nemojte prosleđivati ovaj link.';
  v_html := '<p>Poštovani/a,</p><p>' ||
    case when p_recipient_role = 'GUARDIAN'
      then 'Dopunite podatke za ' || replace(v_recipient_name, '<', '&lt;') || '.'
      else 'Dopunite podatke potrebne za Vaše članstvo.' end ||
    '</p><p><a href="' || replace(p_invitation_url, '"', '&quot;') ||
    '">DOPUNITE PODATKE</a></p><p>Link važi do ' ||
    to_char(v_invitation.expires_at at time zone 'Europe/Belgrade', 'DD.MM.YYYY. HH24:MI') ||
    '. Podatke možete sačuvati i nastaviti kasnije.</p><p>Nemojte prosleđivati ovaj link.</p>';

  insert into public.society_email_outbox (
    society_id, message_type, member_invitation_id, recipient_email,
    recipient_name, subject, payload, sender_source, sender_email,
    template_key, template_version, idempotency_key, initiated_by_user_id,
    initiation_type, encrypted_delivery_payload, status
  ) values (
    p_society_id,
    case when p_recipient_role = 'GUARDIAN'
      then 'GUARDIAN_DATA_INVITATION' else 'MEMBER_DATA_INVITATION' end,
    v_invitation.id, v_invitation.recipient_email, v_recipient_name,
    v_subject,
    jsonb_build_object(
      'candidate_id', p_candidate_id,
      'recipient_role', p_recipient_role,
      'expires_at', v_invitation.expires_at
    ),
    'SOCIETY_GMAIL', v_sender_email, 'member_data_invitation', 1,
    'member-invitation:' || v_invitation.id::text || ':' || v_invitation.updated_at::text,
    auth.uid(), 'BUSINESS_ACTION',
    extensions.pgp_sym_encrypt(
      jsonb_build_object('text', v_text, 'html', v_html)::text,
      p_encryption_secret
    ),
    'PENDING'
  )
  on conflict (idempotency_key) do update set
    status = case when society_email_outbox.status = 'SENT'
      then 'SENT' else 'PENDING' end
  returning id into v_outbox_id;
  return jsonb_build_object('outbox_id', v_outbox_id);
end;
$$;

create or replace function public.auth_queue_payment_confirmation_emails(
  p_payment_id uuid
) returns table(outbox_id uuid)
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_payment public.financial_payments%rowtype;
  v_actor record;
  v_society_name text;
  v_sender_email text;
  v_recipient record;
  v_subject text;
  v_lines text;
  v_html_lines text;
  v_id uuid;
begin
  select * into v_payment from public.financial_payments where id = p_payment_id;
  if v_payment.id is null or v_payment.status <> 'POSTED' then
    raise exception 'Važeća uplata nije pronađena.';
  end if;
  select * into v_actor from public.gmail_actor_member(v_payment.society_id);
  if v_actor.member_id is null or not public.permissions_has_scope(
    v_payment.society_id, v_actor.member_id, v_actor.person_id,
    'finance.record_payment', array['SOCIETY']::text[]
  ) then raise exception 'Nemate pravo pripreme potvrde uplate.'; end if;

  select society.name, connection.email into v_society_name, v_sender_email
  from public.societies society
  left join public.society_gmail_connections connection on connection.society_id = society.id
  where society.id = v_payment.society_id;
  if v_sender_email is null then raise exception 'Gmail nalog društva nije povezan.'; end if;

  for v_recipient in
    with paid_people as (
      select distinct person.id, person.first_name, person.last_name,
        person.email, person.birth_date
      from public.financial_obligation_allocations allocation
      join public.financial_obligations obligation on obligation.id = allocation.obligation_id
      join public.people person on person.id = obligation.person_id
      where allocation.payment_id = p_payment_id and allocation.status = 'ACTIVE'
    ),
    recipients as (
      select person.id as related_person_id, lower(person.email) as email,
        concat_ws(' ', person.first_name, person.last_name) as recipient_name
      from paid_people person
      where nullif(btrim(person.email), '') is not null
        and (
          person.birth_date is null
          or person.birth_date <= current_date - interval '12 years'
        )
      union
      select child.id, lower(guardian.email),
        concat_ws(' ', guardian.first_name, guardian.last_name)
      from paid_people child
      join public.person_guardians link
        on link.child_person_id = child.id and link.is_primary
      join public.people guardian on guardian.id = link.guardian_person_id
      where child.birth_date > current_date - interval '18 years'
        and nullif(btrim(guardian.email), '') is not null
    )
    select email, max(recipient_name) as recipient_name,
      jsonb_agg(distinct related_person_id) as related_people
    from recipients
    group by email
  loop
    select
      string_agg(
        obligation.title || ': ' || allocation.amount || ' ' || allocation.currency,
        E'\n' order by obligation.title
      ),
      string_agg(
        '<li>' || replace(obligation.title, '<', '&lt;') || ': <strong>' ||
        allocation.amount || ' ' || allocation.currency || '</strong></li>',
        '' order by obligation.title
      )
    into v_lines, v_html_lines
    from public.financial_obligation_allocations allocation
    join public.financial_obligations obligation on obligation.id = allocation.obligation_id
    where allocation.payment_id = p_payment_id
      and allocation.status = 'ACTIVE'
      and obligation.person_id in (
        select value::uuid from jsonb_array_elements_text(v_recipient.related_people)
      );

    v_subject := 'Potvrda uplate ' || v_payment.receipt_number || ' – ' || v_society_name;
    insert into public.society_email_outbox (
      society_id, message_type, payment_id, related_person_id,
      recipient_email, recipient_name, subject, payload,
      sender_source, sender_email, template_key, template_version,
      idempotency_key, initiated_by_user_id, initiation_type,
      encrypted_delivery_payload, status
    ) values (
      v_payment.society_id, 'PAYMENT_CONFIRMATION', v_payment.id,
      (v_recipient.related_people->>0)::uuid,
      v_recipient.email, v_recipient.recipient_name, v_subject,
      jsonb_build_object(
        'receipt_number', v_payment.receipt_number,
        'amount', v_payment.amount,
        'currency', v_payment.currency,
        'payment_method', v_payment.payment_method,
        'recorded_at', v_payment.recorded_at,
        'related_people', v_recipient.related_people
      ),
      'SOCIETY_GMAIL', v_sender_email, 'payment_confirmation', 1,
      'payment:' || v_payment.id::text || ':' || v_recipient.email,
      auth.uid(), 'AUTOMATIC',
      convert_to(jsonb_build_object(
        'text',
          'Poštovani/a ' || v_recipient.recipient_name || E',\n\nEvidentirana je uplata ' ||
          v_payment.receipt_number || ' u iznosu ' || v_payment.amount || ' ' ||
          v_payment.currency || E'.\n\n' || coalesce(v_lines, '') ||
          E'\n\nNačin plaćanja: ' ||
          case v_payment.payment_method when 'CASH' then 'Gotovina' else 'Uplata na račun' end,
        'html',
          '<p>Poštovani/a ' || replace(v_recipient.recipient_name, '<', '&lt;') ||
          ',</p><p>Evidentirana je uplata <strong>' || v_payment.receipt_number ||
          '</strong> u iznosu <strong>' || v_payment.amount || ' ' ||
          v_payment.currency || '</strong>.</p><ul>' || coalesce(v_html_lines, '') ||
          '</ul><p>Način plaćanja: ' ||
          case v_payment.payment_method when 'CASH' then 'Gotovina' else 'Uplata na račun' end ||
          '</p>'
      )::text, 'utf8'),
      'PENDING'
    )
    on conflict (idempotency_key) do update set
      status = case when society_email_outbox.status = 'SENT'
        then 'SENT' else 'PENDING' end
    returning id into v_id;
    outbox_id := v_id;
    return next;
  end loop;
end;
$$;

create or replace function public.auth_claim_society_email(
  p_outbox_id uuid,
  p_encryption_secret text
) returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions, pg_temp
as $$
declare
  v_message public.society_email_outbox%rowtype;
  v_payload jsonb;
  v_refresh_token text;
  v_attempt integer;
begin
  select * into v_message from public.society_email_outbox
  where id = p_outbox_id for update;
  if v_message.id is null or v_message.status not in ('PENDING', 'FAILED') then
    raise exception 'Poruka nije dostupna za slanje.';
  end if;
  if not exists (
    select 1 from public.gmail_actor_member(v_message.society_id)
  ) then raise exception 'Nemate pristup ovoj poruci.'; end if;
  select extensions.pgp_sym_decrypt(connection.encrypted_refresh_token, p_encryption_secret)
    into v_refresh_token
  from public.society_gmail_connections connection
  where connection.society_id = v_message.society_id;
  if v_refresh_token is null then raise exception 'Gmail nalog društva nije povezan.'; end if;

  if v_message.message_type in ('MEMBER_DATA_INVITATION', 'GUARDIAN_DATA_INVITATION') then
    v_payload := extensions.pgp_sym_decrypt(
      v_message.encrypted_delivery_payload, p_encryption_secret
    )::jsonb;
  else
    v_payload := convert_from(v_message.encrypted_delivery_payload, 'utf8')::jsonb;
  end if;
  v_attempt := v_message.attempt_count + 1;
  update public.society_email_outbox set
    status = 'SENDING', attempt_count = v_attempt,
    last_attempt_at = now(), last_error = null
  where id = p_outbox_id;
  insert into public.society_email_delivery_attempts (
    outbox_id, attempt_number, status
  ) values (p_outbox_id, v_attempt, 'SENDING');
  return jsonb_build_object(
    'recipient_email', v_message.recipient_email,
    'sender_email', v_message.sender_email,
    'subject', v_message.subject,
    'text_body', v_payload->>'text',
    'html_body', v_payload->>'html',
    'refresh_token', v_refresh_token
  );
end;
$$;

create or replace function public.auth_complete_society_email_attempt(
  p_outbox_id uuid,
  p_succeeded boolean,
  p_provider_message_id text,
  p_error text
) returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare v_message public.society_email_outbox%rowtype;
begin
  select * into v_message from public.society_email_outbox where id = p_outbox_id for update;
  if v_message.id is null or v_message.status <> 'SENDING' then
    raise exception 'Aktivan pokušaj slanja nije pronađen.';
  end if;
  if not exists (select 1 from public.gmail_actor_member(v_message.society_id)) then
    raise exception 'Nemate pristup ovoj poruci.';
  end if;
  update public.society_email_delivery_attempts set
    completed_at = now(),
    status = case when p_succeeded then 'SENT' else 'FAILED' end,
    provider_message_id = p_provider_message_id,
    error = case when p_succeeded then null else left(p_error, 1000) end
  where outbox_id = p_outbox_id and attempt_number = v_message.attempt_count;
  update public.society_email_outbox set
    status = case when p_succeeded then 'SENT' else 'FAILED' end,
    provider_message_id = p_provider_message_id,
    last_error = case when p_succeeded then null else left(p_error, 1000) end,
    sent_at = case when p_succeeded then now() else sent_at end
  where id = p_outbox_id;
end;
$$;

create or replace function public.auth_list_society_email_log(
  p_society_id uuid,
  p_status text default null,
  p_message_type text default null,
  p_query text default null,
  p_limit integer default 100
) returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare v_actor record;
begin
  select * into v_actor from public.gmail_actor_member(p_society_id);
  if v_actor.member_id is null or not public.permissions_has_scope(
    p_society_id, v_actor.member_id, v_actor.person_id,
    'reports.email_log.view', array['SOCIETY']::text[]
  ) then raise exception 'Nemate pravo pregleda evidencije emailova.'; end if;
  return jsonb_build_object(
    'can_view', true,
    'messages', coalesce((
      select jsonb_agg(row_data order by row_data.created_at desc)
      from (
        select message.id, message.message_type, message.recipient_email,
          message.recipient_name, message.sender_email, message.subject,
          message.status, message.attempt_count, message.last_error,
          message.created_at, message.last_attempt_at, message.sent_at,
          message.payment_id, payment.receipt_number,
          coalesce((
            select jsonb_agg(jsonb_build_object(
              'attempt_number', attempt.attempt_number,
              'started_at', attempt.started_at,
              'completed_at', attempt.completed_at,
              'status', attempt.status,
              'error', attempt.error
            ) order by attempt.attempt_number)
            from public.society_email_delivery_attempts attempt
            where attempt.outbox_id = message.id
          ), '[]'::jsonb) attempts
        from public.society_email_outbox message
        left join public.financial_payments payment on payment.id = message.payment_id
        where message.society_id = p_society_id
          and (p_status is null or message.status = p_status)
          and (p_message_type is null or message.message_type = p_message_type)
          and (
            nullif(btrim(coalesce(p_query, '')), '') is null
            or message.recipient_email ilike '%' || btrim(p_query) || '%'
            or message.recipient_name ilike '%' || btrim(p_query) || '%'
            or payment.receipt_number ilike '%' || btrim(p_query) || '%'
          )
        order by message.created_at desc
        limit least(greatest(coalesce(p_limit, 100), 1), 250)
      ) row_data
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.gmail_actor_member(uuid) from public, anon, authenticated;
revoke all on function public.auth_queue_member_data_invitation_email(uuid,uuid,text,text,text) from public, anon;
revoke all on function public.auth_queue_payment_confirmation_emails(uuid) from public, anon;
revoke all on function public.auth_claim_society_email(uuid,text) from public, anon;
revoke all on function public.auth_complete_society_email_attempt(uuid,boolean,text,text) from public, anon;
revoke all on function public.auth_list_society_email_log(uuid,text,text,text,integer) from public, anon;

grant execute on function public.auth_queue_member_data_invitation_email(uuid,uuid,text,text,text) to authenticated;
grant execute on function public.auth_queue_payment_confirmation_emails(uuid) to authenticated;
grant execute on function public.auth_claim_society_email(uuid,text) to authenticated;
grant execute on function public.auth_complete_society_email_attempt(uuid,boolean,text,text) to authenticated;
grant execute on function public.auth_list_society_email_log(uuid,text,text,text,integer) to authenticated;

select pg_notify('pgrst', 'reload schema');
commit;
