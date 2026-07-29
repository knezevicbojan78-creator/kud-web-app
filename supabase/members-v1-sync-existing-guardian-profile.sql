begin;

create or replace function public.sync_approved_candidate_guardian_profiles()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_child_person_id uuid;
  v_draft jsonb;
  v_guardian jsonb;
begin
  if new.status <> 'APPROVED' or old.status = 'APPROVED' then
    return new;
  end if;

  select person_id into v_child_person_id
  from public.society_members
  where id = new.society_member_id;

  select coalesce(draft.draft, new.profile) into v_draft
  from public.member_data_drafts draft
  where draft.candidate_id = new.id;

  if v_draft is null then
    v_draft := new.profile;
  end if;

  for v_guardian in
    select value
    from jsonb_array_elements(jsonb_build_array(
      v_draft -> 'guardian1',
      case when coalesce((v_draft ->> 'showGuardian2')::boolean, false)
        then v_draft -> 'guardian2' else null end
    ))
    where value <> 'null'::jsonb
  loop
    update public.people person
    set first_name = coalesce(
          nullif(btrim(v_guardian ->> 'first_name'), ''),
          person.first_name
        ),
        last_name = coalesce(
          nullif(btrim(v_guardian ->> 'last_name'), ''),
          person.last_name
        ),
        phone = coalesce(
          nullif(btrim(v_guardian ->> 'phone'), ''),
          person.phone
        ),
        updated_at = now()
    from public.person_guardians relation
    where relation.child_person_id = v_child_person_id
      and relation.guardian_person_id = person.id
      and lower(person.email) = lower(btrim(v_guardian ->> 'email'));
  end loop;

  return new;
end;
$$;

drop trigger if exists sync_approved_candidate_guardian_profiles_trigger
  on public.member_import_candidates;

create trigger sync_approved_candidate_guardian_profiles_trigger
after update of status on public.member_import_candidates
for each row
execute function public.sync_approved_candidate_guardian_profiles();

revoke all on function public.sync_approved_candidate_guardian_profiles()
  from public, anon, authenticated;

commit;
