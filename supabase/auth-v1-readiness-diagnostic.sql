-- FOLKLORAS — SUPABASE AUTH V1 READ-ONLY DIJAGNOSTIKA
--
-- Ovaj fajl ne menja podatke, Auth korisnike, politike, grantove niti funkcije.
-- Pokrenuti ceo fajl u Supabase SQL Editoru nakon test-data reseta i pre prve
-- Auth migracije. Detaljni result setovi daju inventar, a poslednji result set
-- daje zbirne brojace za primopredaju.

-- 1. Osnovno trenutno stanje pre Auth migracije.
select
  (select count(*) from auth.users) as auth_user_count,
  (select count(*) from public.societies) as society_count,
  (select count(*) from public.people) as people_count,
  (select count(*) from public.society_members) as society_member_count,
  (select count(*) from public."PresidentReg") as president_request_count;

-- 2. Auth korisnici. Ne prikazuje enkriptovane lozinke ili tokene.
select
  id,
  lower(email) as normalized_email,
  email_confirmed_at,
  last_sign_in_at,
  created_at,
  banned_until
from auth.users
order by created_at, id;

-- 3. Dupli emailovi u people. Rezultat treba da bude prazan.
select
  lower(btrim(email)) as normalized_email,
  count(*) as person_count,
  array_agg(id order by id) as person_ids
from public.people
where nullif(btrim(email), '') is not null
group by lower(btrim(email))
having count(*) > 1
order by normalized_email;

-- 4. Dupli emailovi u Auth-u. Rezultat treba da bude prazan.
select
  lower(btrim(email)) as normalized_email,
  count(*) as auth_user_count,
  array_agg(id order by id) as auth_user_ids
from auth.users
where nullif(btrim(email), '') is not null
group by lower(btrim(email))
having count(*) > 1
order by normalized_email;

-- 5. People/Auth konflikti. Rezultat treba da bude prazan.
select
  p.id as person_id,
  p.email as person_email,
  p.user_id,
  u.email as auth_email,
  case
    when u.id is null then 'AUTH_USER_MISSING'
    when lower(btrim(p.email)) is distinct from lower(btrim(u.email))
      then 'EMAIL_MISMATCH'
    else 'UNKNOWN'
  end as problem
from public.people p
left join auth.users u on u.id = p.user_id
where p.user_id is not null
  and (
    u.id is null
    or lower(btrim(p.email)) is distinct from lower(btrim(u.email))
  )
order by p.email, p.id;

-- 6. Isti Auth identitet na vise people zapisa. Rezultat treba da bude prazan.
select
  user_id,
  count(*) as person_count,
  array_agg(id order by id) as person_ids
from public.people
where user_id is not null
group by user_id
having count(*) > 1
order by user_id;

-- 7. Nedoslednost people.user_id i society_members.user_id.
-- Rezultat treba da bude prazan pre i posle Auth migracije.
select
  sm.id as society_member_id,
  sm.society_id,
  sm.person_id,
  p.user_id as people_user_id,
  sm.user_id as membership_user_id
from public.society_members sm
join public.people p on p.id = sm.person_id
where p.user_id is distinct from sm.user_id
  and (p.user_id is not null or sm.user_id is not null)
order by sm.society_id, sm.id;

-- 8. Aktivna clanstva iste osobe u vise drustava. Informacioni rezultat.
select
  p.id as person_id,
  p.email,
  count(distinct sm.society_id) as active_society_count,
  array_agg(distinct s.name order by s.name) as society_names
from public.people p
join public.society_members sm
  on sm.person_id = p.id
 and sm.status = 'ACTIVE'
join public.societies s on s.id = sm.society_id
group by p.id, p.email
having count(distinct sm.society_id) > 1
order by active_society_count desc, p.email;

-- 9. Roditelji sa Auth vezom i broj aktivnih drustava njihove dece.
-- Informacioni rezultat.
select
  guardian.id as guardian_person_id,
  guardian.email as guardian_email,
  guardian.user_id,
  count(distinct pg.child_person_id) as child_count,
  count(distinct sm.society_id) filter (where sm.status = 'ACTIVE')
    as active_child_society_count
from public.people guardian
join public.person_guardians pg
  on pg.guardian_person_id = guardian.id
left join public.society_members sm
  on sm.person_id = pg.child_person_id
where guardian.user_id is not null
group by guardian.id, guardian.email, guardian.user_id
order by guardian.email, guardian.id;

-- 10. Drustva bez tacno jednog aktivno dodeljenog predsednika.
-- Posle zavrsenog onboardinga rezultat treba da bude prazan.
select
  s.id as society_id,
  s.name as society_name,
  count(distinct smf.id) filter (
    where lower(btrim(smf.name)) = lower('Predsednik')
      and coalesce(smf.is_active, true) = true
  ) as active_president_function_count,
  count(distinct sm.id) filter (
    where lower(btrim(smf.name)) = lower('Predsednik')
      and coalesce(smf.is_active, true) = true
      and sm.status = 'ACTIVE'
  ) as active_president_actor_count
from public.societies s
left join public.society_member_functions smf
  on smf.society_id = s.id
left join public.society_member_function_assignments smfa
  on smfa.function_id = smf.id
 and smfa.society_id = s.id
left join public.society_members sm
  on sm.id = smfa.society_member_id
 and sm.society_id = s.id
group by s.id, s.name
having
  count(distinct smf.id) filter (
    where lower(btrim(smf.name)) = lower('Predsednik')
      and coalesce(smf.is_active, true) = true
  ) <> 1
  or
  count(distinct sm.id) filter (
    where lower(btrim(smf.name)) = lower('Predsednik')
      and coalesce(smf.is_active, true) = true
      and sm.status = 'ACTIVE'
  ) <> 1
order by s.name;

-- 11. Funkcijske dodele ciji clan, funkcija i zapis ne pripadaju istom
-- drustvu. Rezultat treba da bude prazan.
select
  smfa.id as assignment_id,
  smfa.society_id as assignment_society_id,
  sm.society_id as member_society_id,
  smf.society_id as function_society_id,
  smfa.society_member_id,
  smfa.function_id
from public.society_member_function_assignments smfa
join public.society_members sm on sm.id = smfa.society_member_id
join public.society_member_functions smf on smf.id = smfa.function_id
where smfa.society_id <> sm.society_id
   or smfa.society_id <> smf.society_id
order by smfa.id;

-- 12. Aktivne politike dostupne anon/authenticated u public semi.
-- Ovo je inventar za kasnije kontrolisano uklanjanje, ne automatska greska:
-- javni insert registracionog zahteva moze ostati namerno dozvoljen.
select
  schemaname,
  tablename,
  policyname,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where schemaname = 'public'
  and (
    'anon' = any(roles)
    or 'authenticated' = any(roles)
    or 'public' = any(roles)
  )
order by tablename, policyname;

-- 13. Public RPC EXECUTE grantovi za anon/authenticated/PUBLIC.
-- PUBLIC grant je bitan jer ga nasledjuju i anon i authenticated.
select distinct
  routine_schema,
  routine_name,
  grantee,
  privilege_type
from information_schema.routine_privileges
where routine_schema = 'public'
  and grantee in ('anon', 'authenticated', 'PUBLIC')
  and privilege_type = 'EXECUTE'
order by routine_name, grantee;

-- 14. Zbirni rezultat. Posle trenutnog test-data reseta poslovni i Auth
-- brojaci treba da budu 0. DEV policy/grant brojaci su informacioni inventar
-- koji ce se smanjivati modul po modul tokom Auth prelaska.
select
  (select count(*) from auth.users) as auth_user_count,
  (select count(*) from public.societies) as society_count,
  (select count(*) from public.people) as people_count,
  (select count(*) from public.society_members) as society_member_count,
  (
    select count(*)
    from (
      select lower(btrim(email))
      from public.people
      where nullif(btrim(email), '') is not null
      group by lower(btrim(email))
      having count(*) > 1
    ) duplicate_people_email
  ) as duplicate_people_email_count,
  (
    select count(*)
    from (
      select lower(btrim(email))
      from auth.users
      where nullif(btrim(email), '') is not null
      group by lower(btrim(email))
      having count(*) > 1
    ) duplicate_auth_email
  ) as duplicate_auth_email_count,
  (
    select count(*)
    from public.people p
    left join auth.users u on u.id = p.user_id
    where p.user_id is not null
      and (
        u.id is null
        or lower(btrim(p.email)) is distinct from lower(btrim(u.email))
      )
  ) as people_auth_conflict_count,
  (
    select count(*)
    from public.society_members sm
    join public.people p on p.id = sm.person_id
    where p.user_id is distinct from sm.user_id
      and (p.user_id is not null or sm.user_id is not null)
  ) as member_auth_mismatch_count,
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and (
        'anon' = any(roles)
        or 'authenticated' = any(roles)
        or 'public' = any(roles)
      )
  ) as public_anon_authenticated_policy_count,
  (
    select count(distinct routine_name)
    from information_schema.routine_privileges
    where routine_schema = 'public'
      and grantee in ('anon', 'authenticated', 'PUBLIC')
      and privilege_type = 'EXECUTE'
  ) as public_rpc_with_public_execute_count;
