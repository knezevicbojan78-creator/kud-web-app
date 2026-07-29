-- OVO JE SAMO DEV ALAT. NE KORISTITI U PRODUKCIJI.
-- Brisanje test osobe po email-u iz development baze.

create or replace function public.dev_delete_test_person_by_email(target_email text)
returns text
language plpgsql
as $$
declare
  target_person_id uuid;
  deleted_function_assignments integer := 0;
  deleted_status_history integer := 0;
  deleted_guardian_links integer := 0;
  deleted_society_members integer := 0;
  deleted_people integer := 0;
begin
  if target_email is null or length(trim(target_email)) = 0 then
    return 'Email nije prosledjen.';
  end if;

  select id
    into target_person_id
  from public.people
  where lower(email) = lower(trim(target_email))
  limit 1;

  if target_person_id is null then
    return 'Osoba nije pronadjena za email: ' || trim(target_email);
  end if;

  delete from public.society_member_function_assignments
  where society_member_id in (
    select id
    from public.society_members
    where person_id = target_person_id
  );
  get diagnostics deleted_function_assignments = row_count;

  delete from public.member_status_history
  where society_member_id in (
    select id
    from public.society_members
    where person_id = target_person_id
  );
  get diagnostics deleted_status_history = row_count;

  delete from public.person_guardians
  where child_person_id = target_person_id
     or guardian_person_id = target_person_id;
  get diagnostics deleted_guardian_links = row_count;

  delete from public.society_members
  where person_id = target_person_id;
  get diagnostics deleted_society_members = row_count;

  delete from public.people
  where id = target_person_id;
  get diagnostics deleted_people = row_count;

  return
    'Obrisano za email '
    || trim(target_email)
    || ': society_member_function_assignments='
    || deleted_function_assignments
    || ', member_status_history='
    || deleted_status_history
    || ', person_guardians='
    || deleted_guardian_links
    || ', society_members='
    || deleted_society_members
    || ', people='
    || deleted_people
    || '.';
end;
$$;

-- Primer upotrebe:
-- select public.dev_delete_test_person_by_email('test@example.com');
