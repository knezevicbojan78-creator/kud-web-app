begin;

create or replace function public.enforce_member_data_submission_complete()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_draft jsonb;
  v_minor boolean;
begin
  if new.status <> 'SUBMITTED' or old.status = 'SUBMITTED' then
    return new;
  end if;

  select draft into v_draft
  from public.member_data_drafts
  where candidate_id = new.candidate_id;

  v_minor := coalesce((v_draft ->> 'is_minor_member')::boolean, false);

  if nullif(btrim(v_draft ->> 'first_name'), '') is null
     or nullif(btrim(v_draft ->> 'last_name'), '') is null
     or nullif(lower(btrim(v_draft ->> 'email')), '') is null
     or (not v_minor and nullif(btrim(v_draft ->> 'phone'), '') is null)
     or nullif(btrim(v_draft ->> 'gender'), '') is null
     or nullif(v_draft ->> 'birth_date', '') is null
     or nullif(btrim(v_draft ->> 'address'), '') is null
     or nullif(btrim(v_draft ->> 'city'), '') is null
     or nullif(btrim(v_draft ->> 'postal_code'), '') is null
     or nullif(btrim(v_draft ->> 'country'), '') is null then
    raise exception 'Svi obavezni licni podaci moraju biti uneti pre slanja.';
  end if;

  if (nullif(btrim(v_draft ->> 'passport_number'), '') is null)
     <> (nullif(v_draft ->> 'passport_expiry_date', '') is null) then
    raise exception 'Broj pasosa i datum vazenja moraju biti uneti zajedno.';
  end if;

  if v_minor and (
    nullif(btrim(v_draft #>> '{guardian1,first_name}'), '') is null
    or nullif(btrim(v_draft #>> '{guardian1,last_name}'), '') is null
    or nullif(lower(btrim(v_draft #>> '{guardian1,email}')), '') is null
    or nullif(btrim(v_draft #>> '{guardian1,phone}'), '') is null
  ) then
    raise exception 'Podaci prvog roditelja ili staratelja su obavezni.';
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_member_data_submission_complete_trigger
  on public.member_data_invitations;

create trigger enforce_member_data_submission_complete_trigger
before update of status on public.member_data_invitations
for each row
execute function public.enforce_member_data_submission_complete();

revoke all on function public.enforce_member_data_submission_complete()
  from public, anon, authenticated;

commit;
