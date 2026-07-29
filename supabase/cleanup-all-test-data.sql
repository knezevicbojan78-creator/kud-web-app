-- FOLKLORAS: kontrolisano praznjenje svih trenutnih testnih podataka.
--
-- Ovaj fajl:
--   * NE brise tabele, funkcije, trigere, RLS politike ili cron poslove;
--   * NE brise globalni katalog dozvola i sistemske sablone;
--   * NE brise pakete i aktuelne cene licenci;
--   * brise drustva, osobe, registracione zahteve i sve zavisne testne podatke;
--   * vraca identity brojace obrisanih tabela na pocetak.
--
-- Sigurnosno pravilo:
-- dokumentovano trenutno stanje ima samo jedno testno drustvo naziva "Test".
-- Ako postoji bilo koje drugo drustvo, transakcija se prekida bez brisanja.

begin;

do $$
declare
  v_society_count bigint;
  v_non_test_society_count bigint;
  v_society_names text;
begin
  select count(*)
    into v_society_count
  from public.societies;

  select count(*)
    into v_non_test_society_count
  from public.societies
  where lower(btrim(name)) <> 'test';

  select string_agg(name, ', ' order by name)
    into v_society_names
  from public.societies;

  raise notice 'Pronadjeno drustava: %. Nazivi: %',
    v_society_count,
    coalesce(v_society_names, '(nema)');

  if v_non_test_society_count > 0 then
    raise exception
      'RESET ODBIJEN: pronadjeno je % drustava koja se ne zovu "Test". Nista nije obrisano.',
      v_non_test_society_count;
  end if;

  if v_society_count > 1 then
    raise exception
      'RESET ODBIJEN: ocekivano je najvise jedno trenutno testno drustvo, a pronadjeno je %. Nista nije obrisano.',
      v_society_count;
  end if;
end
$$;

-- TRUNCATE ... CASCADE prazni i sve tabele koje preko stranih kljuceva
-- zavise od ova tri korena: clanove, sekcije, funkcije, dozvole drustva,
-- prisustvo, dogadjaje, repertoar, finansije, licence i audit istoriju.
--
-- Globalne tabele public.permission_catalog,
-- public.system_function_permission_templates i
-- public.platform_license_plans ne zavise od ovih korena i ostaju sacuvane.
truncate table
  public."PresidentReg",
  public.people,
  public.societies
restart identity cascade;

do $$
declare
  v_society_count bigint;
  v_people_count bigint;
  v_registration_count bigint;
  v_permission_count bigint;
  v_template_count bigint;
  v_license_plan_count bigint;
begin
  select count(*) into v_society_count
  from public.societies;

  select count(*) into v_people_count
  from public.people;

  select count(*) into v_registration_count
  from public."PresidentReg";

  select count(*) into v_permission_count
  from public.permission_catalog;

  select count(*) into v_template_count
  from public.system_function_permission_templates;

  select count(*) into v_license_plan_count
  from public.platform_license_plans;

  if v_society_count <> 0
     or v_people_count <> 0
     or v_registration_count <> 0 then
    raise exception
      'RESET NIJE POTPUN: societies=%, people=%, PresidentReg=%. Transakcija se ponistava.',
      v_society_count,
      v_people_count,
      v_registration_count;
  end if;

  if v_permission_count = 0
     or v_template_count = 0
     or v_license_plan_count = 0 then
    raise exception
      'SISTEMSKI PODACI NISU SACUVANI: dozvole=%, sabloni=%, paketi=%. Transakcija se ponistava.',
      v_permission_count,
      v_template_count,
      v_license_plan_count;
  end if;

  raise notice
    'RESET USPESAN. Poslovni podaci su prazni. Sacuvano: % dozvola, % sablona i % paketa licenci.',
    v_permission_count,
    v_template_count,
    v_license_plan_count;
end
$$;

commit;

-- Zavrsni pregled treba da vrati nule za poslovne podatke i pozitivne
-- vrednosti za tri sistemska kataloga.
select
  (select count(*) from public.societies) as societies,
  (select count(*) from public.people) as people,
  (select count(*) from public."PresidentReg") as registration_requests,
  (select count(*) from public.permission_catalog) as permission_catalog,
  (select count(*) from public.system_function_permission_templates) as permission_templates,
  (select count(*) from public.platform_license_plans) as license_plans;
