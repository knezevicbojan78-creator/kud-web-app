begin;

create or replace function public.auth_apply_initial_member_fee(
  p_society_member_id uuid,
  p_fee_mode text,
  p_custom_amount numeric,
  p_reason text
) returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_member public.society_members%rowtype;
  v_society public.societies%rowtype;
  v_mode text := upper(trim(coalesce(p_fee_mode, 'STANDARD')));
  v_amount numeric(12,2);
  v_reason text;
  v_effective date;
  v_actor_member_id uuid;
  v_history_id uuid;
begin
  select * into v_member from public.society_members
  where id = p_society_member_id for update;
  if v_member.id is null then raise exception 'Clan nije pronadjen.'; end if;
  select * into v_society from public.societies where id = v_member.society_id;

  if v_mode not in ('STANDARD', 'CUSTOM', 'EXEMPT') then
    raise exception 'Nepoznat rezim clanarine.';
  end if;
  if v_mode <> 'STANDARD' and nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception 'Razlog posebne clanarine ili oslobodjenja je obavezan.';
  end if;

  v_amount := case
    when v_mode = 'STANDARD' then v_society.default_membership_fee_amount
    when v_mode = 'CUSTOM' then p_custom_amount
    else null
  end;
  if v_mode <> 'EXEMPT' and (v_amount is null or v_amount <= 0) then
    raise exception 'Iznos clanarine nije ispravan.';
  end if;

  v_reason := case when v_mode = 'STANDARD'
    then 'Pocetna standardna clanarina pri prijemu clana'
    else btrim(p_reason)
  end;
  v_effective := date_trunc('month', coalesce(v_member.start_date, current_date))::date;
  select member.id into v_actor_member_id
  from public.society_members member
  join public.people person on person.id = member.person_id
  where member.society_id = v_member.society_id
    and member.status = 'ACTIVE'
    and coalesce(member.user_id, person.user_id) = auth.uid()
  order by member.id limit 1;

  update public.society_members set
    membership_fee_mode = v_mode,
    membership_fee_required = (v_mode <> 'EXEMPT'),
    membership_fee_amount = v_amount,
    updated_at = now()
  where id = v_member.id;

  insert into public.member_fee_setting_history (
    society_id, society_member_id, fee_mode, fee_amount, currency,
    effective_from, reason, changed_by_user_id, changed_by_society_member_id
  ) values (
    v_member.society_id, v_member.id, v_mode, v_amount, v_society.base_currency,
    v_effective, v_reason, auth.uid(), v_actor_member_id
  )
  on conflict (society_member_id, effective_from) do update set
    fee_mode = excluded.fee_mode,
    fee_amount = excluded.fee_amount,
    currency = excluded.currency,
    reason = excluded.reason,
    changed_by_user_id = excluded.changed_by_user_id,
    changed_by_society_member_id = excluded.changed_by_society_member_id,
    created_at = now()
  returning id into v_history_id;

  insert into public.financial_audit_log (
    society_id, entity_type, entity_id, action, new_values, reason,
    actor_user_id, actor_society_member_id, actor_role
  ) values (
    v_member.society_id, 'MEMBER_FEE_SETTING', v_history_id,
    'INITIAL_FEE_SETTING', jsonb_build_object(
      'fee_mode', v_mode, 'fee_amount', v_amount, 'effective_from', v_effective
    ), v_reason, auth.uid(), v_actor_member_id, 'Predsednik'
  );
end;
$$;

create or replace function public.auth_create_society_member_with_fee(
  p_society_id uuid,
  p_profile jsonb,
  p_guardians jsonb default '[]'::jsonb,
  p_function_ids uuid[] default array[]::uuid[],
  p_section_ids uuid[] default array[]::uuid[],
  p_fee jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare v_result jsonb;
begin
  v_result := public.auth_create_society_member(
    p_society_id, p_profile, p_guardians, p_function_ids, p_section_ids
  );
  perform public.auth_apply_initial_member_fee(
    (v_result->>'society_member_id')::uuid,
    coalesce(p_fee->>'mode', 'STANDARD'),
    nullif(p_fee->>'custom_amount', '')::numeric,
    p_fee->>'reason'
  );
  return v_result;
end;
$$;

create or replace function public.auth_update_society_member_with_fee(
  p_society_member_id uuid,
  p_profile jsonb,
  p_guardians jsonb default '[]'::jsonb,
  p_function_ids uuid[] default array[]::uuid[],
  p_section_ids uuid[] default array[]::uuid[],
  p_fee jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_result jsonb;
  v_member public.society_members%rowtype;
  v_mode text := upper(trim(coalesce(p_fee->>'mode', 'STANDARD')));
  v_custom numeric := nullif(p_fee->>'custom_amount', '')::numeric;
  v_changed boolean;
begin
  select * into v_member from public.society_members where id = p_society_member_id;
  if v_member.id is null then raise exception 'Clan nije pronadjen.'; end if;
  v_changed := v_member.membership_fee_mode is distinct from v_mode
    or (v_mode = 'CUSTOM' and v_member.membership_fee_amount is distinct from v_custom);

  v_result := public.auth_update_society_member(
    p_society_member_id, p_profile, p_guardians, p_function_ids, p_section_ids
  );
  if v_changed then
    perform public.finance_set_member_fee(
      p_society_member_id,
      v_mode,
      v_custom,
      case when v_mode = 'STANDARD'
        then 'Vracanje na standardnu clanarinu'
        else p_fee->>'reason'
      end,
      auth.uid(),
      (
        select member.id from public.society_members member
        join public.people person on person.id = member.person_id
        where member.society_id = v_member.society_id
          and member.status = 'ACTIVE'
          and coalesce(member.user_id, person.user_id) = auth.uid()
        order by member.id limit 1
      )
    );
  end if;
  return v_result;
end;
$$;

create or replace function public.auth_finalize_pending_member_with_fee(
  p_society_id uuid,
  p_candidate_id uuid,
  p_start_date date,
  p_profile_updates jsonb default '{}'::jsonb,
  p_fee jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_candidate public.member_import_candidates%rowtype;
  v_result jsonb;
  v_member_id uuid;
begin
  select * into v_candidate from public.member_import_candidates
  where id = p_candidate_id and society_id = p_society_id for update;
  if v_candidate.id is null then raise exception 'Kandidat nije pronadjen.'; end if;

  if v_candidate.society_member_id is null then
    v_result := public.auth_approve_pending_member_import(
      p_society_id, p_candidate_id, p_start_date, p_profile_updates
    );
    v_member_id := (v_result->>'society_member_id')::uuid;
  else
    v_member_id := v_candidate.society_member_id;
    v_result := public.auth_complete_accepted_member_data(
      p_society_id, p_candidate_id, p_start_date, p_profile_updates
    );
  end if;

  perform public.auth_apply_initial_member_fee(
    v_member_id,
    coalesce(p_fee->>'mode', 'STANDARD'),
    nullif(p_fee->>'custom_amount', '')::numeric,
    p_fee->>'reason'
  );
  return v_result;
end;
$$;

revoke all on function public.auth_apply_initial_member_fee(uuid,text,numeric,text)
  from public, anon, authenticated;
revoke all on function public.auth_create_society_member_with_fee(uuid,jsonb,jsonb,uuid[],uuid[],jsonb)
  from public, anon;
grant execute on function public.auth_create_society_member_with_fee(uuid,jsonb,jsonb,uuid[],uuid[],jsonb)
  to authenticated;
revoke all on function public.auth_update_society_member_with_fee(uuid,jsonb,jsonb,uuid[],uuid[],jsonb)
  from public, anon;
grant execute on function public.auth_update_society_member_with_fee(uuid,jsonb,jsonb,uuid[],uuid[],jsonb)
  to authenticated;
revoke all on function public.auth_finalize_pending_member_with_fee(uuid,uuid,date,jsonb,jsonb)
  from public, anon;
grant execute on function public.auth_finalize_pending_member_with_fee(uuid,uuid,date,jsonb,jsonb)
  to authenticated;

select pg_notify('pgrst', 'reload schema');
commit;
