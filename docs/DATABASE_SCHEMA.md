# Šema Baze

Napomena o izvorima:

* Status `POSTOJI U AKTIVNOJ BAZI` znaci da je tabela rucno potvrdjena u aktivnoj Supabase bazi.
* To ne znaci automatski da u repo-u postoji kompletan SQL/migration fajl za tu tabelu.
* Ako repo migracija nije pronadjena ili nije kompletna, to je posebno navedeno kao tehnicki dug.

## 1. PresidentReg

Status:
POSTOJI U AKTIVNOJ BAZI

Svrha:
Registracioni zahtevi.

Važna polja:

* `id`
* `societyId`
* `societyName`
* `address`
* `city`
* `postalCode`
* `country`
* `PIB`
* `registrationNumber`
* `bankAccount`
* `presidentFirstName`
* `presidentLastName`
* `presidentGender`
* `presidentPhone`
* `presidentEmail`
* `presidentUserId`
* `StatReg`
* `createdAt`
* `approvedAt`
* `approvedByEmail`
* `password`
* `confirmPassword`
* `licenseType`
* `licensePrice`

Veze:

* `societyId` -> `societies.id`

Napomena:
U aktivnoj bazi tabela postoji. Repo SQL fajl `supabase/president-reg-setup.sql` treba proveriti i uskladiti sa aktivnom bazom, posebno za `societyId`, jer aplikacioni kod i DEV update policy ocekuju ovo polje.

## 2. societies

Status:
POSTOJI U AKTIVNOJ BAZI

Svrha:
Aktivna društva.

Važna polja:

* `id`
* `name`
* `address`
* `city`
* `postal_code`
* `country` default `'Srbija'`
* `pib`
* `registration_number`
* `bank_account`
* `license_type`
* `license_price`
* `license_valid_from`
* `license_valid_until`
* `status` default `'ACTIVE'`
* `created_at`
* `updated_at`

Pravila:

* unique `pib`
* unique `registration_number`
* `status` check: `ACTIVE`, `INACTIVE`, `SUSPENDED`

Napomena:
Tabela je potvrdjena u aktivnoj Supabase bazi. Repo SQL/migration fajl za `societies` i dalje treba proveriti i uskladiti ako nije kompletan u repozitorijumu.

## 3. people

Status:
POSTOJI U AKTIVNOJ BAZI

Svrha:
Podaci o svim osobama u sistemu.
`people` čuva punoletne članove, maloletne članove, roditelje/staratelje, predsednike, sekretare, blagajnike, umetničke rukovodioce i svaku osobu koja kasnije može imati jednu ili više uloga.
`society_members` čuva samo osobe koje su članovi jednog društva.

Važna polja:

* `id` uuid primary key default `gen_random_uuid()`
* `first_name` text not null
* `last_name` text not null
* `gender` text null
* `address` text null
* `city` text null
* `postal_code` text null
* `country` text null default `'Srbija'`
* `jmbg` text null
* `passport_number` text null
* `passport_expiry_date` date null
* `parental_travel_consent` boolean not null default false
* `parental_travel_consent_valid_until` date null
* `email` text null
* `phone` text null
* `birth_date` date null
* `user_id` uuid null
* `created_at` timestamp with time zone default `now()`
* `updated_at` timestamp with time zone default `now()`

Veze:

* `user_id` -> auth korisnik, kada Supabase Auth bude povezan

Pravila:

* `email` je unique kada postoji.
* `email` mora predstavljati jedinstveni identifikator osobe kada postoji.
* Jedna osoba = jedan email.
* Dva razlicita clana, roditelja ili staratelja ne smeju imati isti email.
* `phone` je unique kada postoji.
* `user_id` je unique kada postoji.
* `jmbg` je unique kada postoji.
* `passport_number` je unique kada postoji.
* Za nove unose `passport_number` i `passport_expiry_date` unose se zajedno.
* Postojeći zapisi sa brojem pasoša mogu privremeno imati prazan datum važenja dok se podatak ne dopuni.
* `passport_expiry_date` može biti u prošlosti; istekao pasoš ne blokira čuvanje.
* Saglasnost oba roditelja za put maloletne osobe u inostranstvo čuva se na `people`, nezavisno od članstva.
* Kada `parental_travel_consent = true`, unosi se i `parental_travel_consent_valid_until`.
* Kod inostranog putovanja potvrda maloletnog putnika zahteva saglasnost koja važi najmanje do povratka.
* Kod inostranog putovanja pasoš mora važiti najmanje tri meseca od datuma
  polaska i svakako najmanje do datuma povratka.
* Datum važenja pasoša je osetljiv podatak sa istim pravima kao broj pasoša.
* Budući servis obaveštenja koristi datum za istekli pasoš i period od tri meseca pre isteka; za maloletnika primalac je primarni roditelj/staratelj.
* Email je glavni praktični identifikator za pronalaženje postojećeg `people` zapisa.
* `jmbg` može postojati, ali nije obavezan i ne sme biti glavni lookup identifikator.
* `gender` mora biti izabrano iz vrednosti `Muško` ili `Žensko`.
* Osoba iz `people` može biti član više društava kroz više redova u `society_members`.
* Roditelj/staratelj koji kasnije dobije korisnički nalog mora koristiti isti postojeći `people` zapis; samo se naknadno povezuje `user_id`.
* Maloletni član bez email-a i telefona je dozvoljen.
* Za maloletnog člana bez email-a i telefona zaštita od duplikata je best-effort.
* Ne uvoditi veštački identifikator za maloletne članove u V1.
* Punoletna osoba / punoletni član mora imati `first_name`, `last_name`, `email` i `phone`.
* Predsednik tokom onboardinga mora imati `first_name`, `last_name`, `email` i `phone`.
* Maloletni član mora imati `first_name` i `last_name`; `email` i `phone` su opcioni.
* Roditelj/staratelj mora imati `first_name`, `last_name`, `email` i `phone`.
* Kada `UF_MEMBER_FORM` pronadje osobu po `people.email`, ne kreira se novi `people` zapis.
* Ako postojeca osoba ima popunjene podatke, ti podaci su read-only u add-member toku.
* Prazna ili nedostajuca polja postojece osobe mogu se dopuniti kroz add-member tok.
* Zastareli postojeci podaci ne menjaju se automatski kroz obican add-member tok; moze ih izmeniti predsednik ili korisnik sa odgovarajucom dozvolom.

## 4. society_members

Status:
POSTOJI U AKTIVNOJ BAZI

Svrha:
Veza osobe i društva, uključujući uloge i članstvo.

Važna polja:

* `id` uuid primary key default `gen_random_uuid()`
* `society_id` uuid not null references `societies(id)`
* `person_id` uuid not null references `people(id)`
* `user_id` uuid null
* `status` text not null default `'ACTIVE'`
* `start_date` date null u trenutnoj repo SQL definiciji; poslovno pravilo trazi obavezan datum
* `funkcija` text null, legacy kolona koja se vise ne koristi u aplikacionom kodu
* `membership_fee_required` boolean not null default true
* `membership_fee_amount` numeric null
* `created_at` timestamp with time zone default `now()`
* `updated_at` timestamp with time zone default `now()`

Veze:

* `society_id` -> `societies.id`
* `person_id` -> `people.id`
* `user_id` -> auth korisnik, kada Supabase Auth bude povezan

Pravila:

* `start_date` je obavezan.
* `start_date` označava datum kada je osoba postala član tog društva.
* `start_date` se bira ručno iz calendar/date picker kontrole.
* `start_date` može biti datum iz prošlosti, jer aplikacija može evidentirati članstva koja su počela pre uvođenja sistema.
* `start_date` se koristi kao prvi ACTIVE datum za `member_status_history`.
* Kada se kreira novi red u `society_members`, mora se kreirati i prvi red u `member_status_history`:
  * `status = ACTIVE`
  * `effective_date = society_members.start_date`
* `status` čuva trenutni status članstva.
* `status` može biti `ACTIVE` ili `INACTIVE`.
* Jubilej se ne računa samo iz `start_date`.
* Jubilej se računa sabiranjem ACTIVE perioda iz `member_status_history`.
* INACTIVE periodi se ne računaju u članski jubilej.
* Funkcije clana se vise ne cuvaju u `society_members.funkcija`; dodele funkcija se cuvaju u `society_member_function_assignments`.
* `society_members.funkcija` postoji kao legacy kolona dok se ne potvrdi bezbedno uklanjanje.
* Pre kreiranja novog reda u `society_members`, sistem mora proveriti da li ista osoba vec ima clanstvo u istom drustvu.
* Ako osoba vec ima red u `society_members` za trenutno drustvo, add-member tok prikazuje poruku da je osoba vec clan tog drustva.
* Ako osoba postoji u `people`, ali nema red u `society_members` za trenutno drustvo, koristi se isti `person_id` i kreira se samo novo clanstvo za trenutno drustvo.

## 5. member_status_history

Status:
POSTOJI U AKTIVNOJ BAZI

Svrha:
Praćenje kompletne istorije promena statusa članstva za finansije, pauze članstva, reaktivaciju, jubileje i izveštaje.

Važna polja:

* `id` uuid primary key default `gen_random_uuid()`
* `society_member_id` uuid not null references `society_members(id)`
* `status` text not null
* `effective_date` date not null
* `note` text null
* `created_at` timestamp with time zone default `now()`
* `updated_at` timestamp with time zone default `now()`

Veze:

* `society_member_id` -> `society_members.id`

Pravila:

* `status` može biti `ACTIVE` ili `INACTIVE`.
* Kada se kreira novi red u `society_members`, prvi red u `member_status_history` kreira se iz `society_members.start_date`.
* Prvi automatski red ima:
  * `status = ACTIVE`
  * `effective_date = society_members.start_date`
* Svaka aktivacija i deaktivacija mora kreirati red u `member_status_history`.
* Trenutni status se čuva u `society_members.status`.
* Kompletna istorija se čuva u `member_status_history`.
* Članski jubilej se računa sabiranjem samo ACTIVE perioda.
* Članarine se zasnivaju na ACTIVE/INACTIVE istoriji, ne samo na trenutnom statusu.

## 6. society_member_functions

Status:
POSTOJI U AKTIVNOJ BAZI

Svrha:
Lista funkcija članova za svako pojedinačno društvo.

Važna polja:

* `id` uuid primary key default `gen_random_uuid()`
* `society_id` uuid not null references `societies(id)`
* `name` text not null
* `is_system` boolean not null default false
* `is_active` boolean not null default true
* `sort_order` integer not null default 0
* `created_at` timestamp with time zone default `now()`
* `updated_at` timestamp with time zone default `now()`

Veze:

* `society_id` -> `societies.id`

Ogranicenja:

* Ocekivano: unique po `society_id` + `name`, da isto drustvo ne duplira isti naziv funkcije.
* Potrebno proveriti i dopuniti repo SQL/migraciju ako ovaj constraint nije zapisan u repozitorijumu.

Pravila:

* Funkcije nisu globalne.
* Funkcije pripadaju samo društvu za koje su kreirane.
* Kada Master admin odobri registraciju i kreira novo društvo, sistem automatski kreira početne funkcije u `society_member_functions` za to novo društvo.
* Početne funkcije su: `Predsednik`, `Sekretar`, `Blagajnik`, `Upravnik`, `UR`, `Korepetitor`, `Član`.
* `UR` znači `Umetnički rukovodilac`.
* `UR` ne znači `Upravnik`.
* `Upravnik` može postojati samo kao posebna funkcija, odvojena od `UR`.
* Predsednik kasnije može dodavati dodatne funkcije za svoje društvo.
* Predsednik kasnije može menjati ili deaktivirati postojeće funkcije za svoje društvo.
* Funkcije se deaktiviraju, ne brišu se fizički.
* Funkcija `Predsednik` je posebna.
* Funkcija `Predsednik` mora uvek postojati.
* Funkcija `Predsednik` ne sme biti obrisana.
* Funkcija `Predsednik` ne sme biti deaktivirana.
* `Predsednik` se ne dodeljuje ručno kroz `UF_MEMBER_FORM`.
* `UR`, ako postoji kao opšta funkcija, ne dodeljuje se ručno kroz `UF_MEMBER_FORM`; UR po sekcijama rešava se kroz sekcijski model.
* `UF_MEMBER_FORM` prikazuje funkcije iz ove liste kao checkbox listu.
* Privremena hardcoded lista je dozvoljena samo dok `society_member_functions` nije implementirana u UI.
## 7. society_member_function_assignments

Status:
POSTOJI U AKTIVNOJ BAZI

Svrha:
Veza izmedju clana drustva i jedne funkcije iz `society_member_functions`.

Vazna polja:

* `id`
* `society_id`
* `society_member_id`
* `function_id`
* `created_at`

Veze:

* `society_id` -> `societies.id`
* `society_member_id` -> `society_members.id`
* `function_id` -> `society_member_functions.id`

Ogranicenja:

* Ocekivano: unique po `society_member_id` + `function_id`, da isti clan ne dobije istu funkciju vise puta.
* Potrebno proveriti i dopuniti repo SQL/migraciju ako ovaj constraint nije zapisan u repozitorijumu.

Pravila:

* Jedan clan moze imati nula, jednu ili vise funkcija.
* Funkcije se citaju iz `society_member_functions`.
* Dodele funkcija se snimaju u `society_member_function_assignments`.
* `society_members.funkcija` je legacy kolona i ne koristi se u aplikacionom kodu.
* Ista funkcija ne sme biti duplirana za istog clana.
* Kod izmene clana stare dodele se zamenjuju novim izabranim funkcijama.
## 8. user_onboarding_state

Status:
POSTOJI U AKTIVNOJ BAZI

Svrha:
Praćenje onboarding procesa predsednika nakon što Master admin odobri registraciju društva.
Predsednik se ne kreira automatski kao član pri approval-u.
Posle prvog logovanja predsednik mora da popuni svoje lične podatke kroz `UF_MEMBER_FORM`.
Tek nakon toga postaje član društva sa funkcijom Predsednik.

SQL schema:

```sql
create table public.user_onboarding_state (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null,
  society_id uuid not null,
  president_reg_id uuid null,
  president_profile_completed boolean not null default false,
  president_permissions_bootstrapped boolean not null default false,
  completed_at timestamp with time zone null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint user_onboarding_state_pkey primary key (id),
  constraint user_onboarding_state_president_reg_id_fkey foreign KEY (president_reg_id) references "PresidentReg" (id),
  constraint user_onboarding_state_society_id_fkey foreign KEY (society_id) references societies (id)
) TABLESPACE pg_default;
```

Važna polja:

* `id`
* `user_id`
* `society_id`
* `president_reg_id`
* `president_profile_completed`
* `president_permissions_bootstrapped`
* `completed_at`
* `created_at`
* `updated_at`

Veze:

* `president_reg_id` -> `PresidentReg.id`
* `society_id` -> `societies.id`

Pravila:

* `user_onboarding_state` se koristi za odluku da li predsednik mora na onboarding.
* Ne proveravati pri svakom logovanju da li predsednik postoji u `society_members`.
* `president_profile_completed=false` znači da predsednik mora da popuni `UF_MEMBER_FORM`.
* `president_profile_completed=true` znači da predsednik može na dashboard.
* `president_permissions_bootstrapped` prati da li su inicijalne dozvole predsednika pripremljene.
* Onboarding predsednika koristi `UF_MEMBER_FORM`.
* Predsednik tokom onboardinga mora biti punoletan.
* Predsednik tokom onboardinga vidi i može da izmeni svoja polja za članarinu:
  * `membership_fee_required`
  * `membership_fee_amount`
* Predsednik tokom onboardinga ručno bira `society_members.start_date` iz calendar/date picker kontrole.
* Predsednikov `start_date` može biti datum iz prošlosti.
* Posle uspešnog onboardinga kreira se prvi red u `member_status_history`:
  * `status = ACTIVE`
  * `effective_date = izabrani start_date`

## 9. sections

Status:
POSTOJI U AKTIVNOJ BAZI

Svrha:
Grupe/probne jedinice unutar jednog društva.

Važna polja:

* `id` uuid primary key default `gen_random_uuid()`
* `society_id` uuid not null references `societies(id)`
* `name` text not null
* `rehearsal_duration_minutes` integer not null default `120`
* `status` text not null default `'ACTIVE'`
* `created_at` timestamp with time zone default `now()`
* `updated_at` timestamp with time zone default `now()`

Veze:

* `society_id` -> `societies.id`

Ogranicenja:

* Naziv sekcije treba da bude unique po drustvu.
* `rehearsal_duration_minutes` mora biti između 30 i 240 i deljivo sa 15.
* Potrebno proveriti i dopuniti repo SQL/migraciju ako ovaj constraint nije zapisan u repozitorijumu.

Pravila:

* `sections` predstavlja sekcije, grupe ili probne jedinice unutar jednog društva.
* Sekcije pripadaju samo društvu za koje su kreirane.
* Kada Master admin odobri registraciju i kreira novo društvo, sistem automatski kreira početne sekcije za to novo društvo.
* Početne sekcije su: `Izvođački ansambl`, `Pripremni ansambl`, `Dečiji ansambl`, `Pevačka grupa`, `Orkestar`.
* Sve početne sekcije kreiraju se sa `status = ACTIVE`.
* `status` može biti `ACTIVE` ili `INACTIVE`.
* Aktivne sekcije se prikazuju u `UF_MEMBER_FORM` kao checkbox lista za izbor pripadnosti clana sekcijama.
* Samim sekcijama kao organizacionim jedinicama upravlja modul `MOJE SEKCIJE`.
* Dodatne sekcije kasnije može kreirati predsednik.
* Postojeće sekcije kasnije mogu biti preimenovane.
* Postojeće sekcije kasnije mogu biti aktivirane ili deaktivirane.
* Neaktivne sekcije ostaju u sistemu zbog istorije i ne brišu se fizički.
* Sekcije se ne brišu fizički.
* Nazivi sekcija su unique po društvu.
* Predsednik definiše trajanje probe pri kreiranju ili izmeni sekcije u `MOJE SEKCIJE`.
* UR vidi trajanje sekcije, ali ga ne menja.
* Promena trajanja utiče samo na probe otvorene nakon promene.

## 10. member_sections

Status:
POSTOJI U AKTIVNOJ BAZI

Svrha:
Veza članova društva i sekcija.

Važna polja:

* `id` uuid primary key default `gen_random_uuid()`
* `society_id` uuid not null references `societies(id)`
* `section_id` uuid not null references `sections(id)`
* `society_member_id` uuid not null references `society_members(id)`
* `status` text not null default `'ACTIVE'`
* `created_at` timestamp with time zone default `now()`
* `updated_at` timestamp with time zone default `now()`

Veze:

* `society_id` -> `societies.id`
* `section_id` -> `sections.id`
* `society_member_id` -> `society_members.id`

Ogranicenja:

* Ocekivano: unique po `section_id` + `society_member_id`, da isti clan ne bude dupliran u istoj sekciji.
* Potrebno proveriti i dopuniti repo SQL/migraciju ako ovaj constraint nije zapisan u repozitorijumu.
* `status` treba da bude `ACTIVE` ili `INACTIVE`.

Pravila:

* Dodela sekcije nije obavezna pri kreiranju clana.
* Clan moze imati nula, jednu ili vise sekcija.
* Jedan clan moze biti aktivan u vise sekcija.
* Dodela i izmena pripadnosti clana sekcijama rade se kroz `UF_MEMBER_FORM`.
* `UF_MEMBER_FORM` prikazuje sekcije kao checkbox listu.
* Predsednik u `UF_MEMBER_FORM` vidi sve sekcije drustva i moze menjati pripadnost clana svim sekcijama.
* UR u `UF_MEMBER_FORM` vidi samo sekcije u kojima je aktivno dodeljen kao UR kroz `section_role_assignments`.
* UR moze menjati pripadnost clana samo sekcijama u kojima je on UR.
* UR ne vidi i ne moze menjati ostale sekcije drustva.
* Modul `MOJE SEKCIJE` upravlja sekcijama, UR-ovima, korepetitorima i pregledom clanova sekcije.
* Isti clan ne sme biti dupliran unutar iste sekcije.
* Isti clan ne sme imati dva `ACTIVE` zapisa u istoj sekciji.
* Ako postoji `INACTIVE` zapis za istu sekciju i clana, ponovno dodavanje reaktivira postojeci zapis na `ACTIVE`.
* Nazivi sekcija se ne čuvaju direktno na `people` ili `society_members`.
* Clanstvo u sekciji se ne brise fizicki; koristi se `status = ACTIVE` ili `status = INACTIVE`.
* Predsednik moze da menja clanstvo u svim sekcijama svog drustva kroz `UF_MEMBER_FORM`.
* UR moze da menja samo clanstvo u sekcijama gde je on UR kroz `UF_MEMBER_FORM`.

## Section Assignment Rules

* `UF_MEMBER_FORM` ostaje centralna forma za clana.
* `UF_MEMBER_FORM` sluzi za unos clana, izmenu clana i izbor sekcija kojima clan pripada.
* Sekcije se u `UF_MEMBER_FORM` prikazuju kao checkbox lista.
* Jedan clan moze pripadati jednoj ili vise sekcija.
* `member_sections` cuva trenutno stanje pripadnosti clana sekcijama.
* `MOJE SEKCIJE` upravlja sekcijama kao organizacionim jedinicama.
* `MOJE SEKCIJE` je glavni modul za kreiranje sekcija, deaktivaciju sekcija, UR-ove, korepetitore i pregled clanova sekcije.
* Predsednik vidi sve sekcije drustva, moze cekirati bilo koju sekciju i moze menjati pripadnost clana svim sekcijama.
* UR vidi samo sekcije u kojima je on UR, moze cekirati samo te sekcije, ne vidi ostale sekcije drustva i ne moze menjati clanstvo u sekcijama kojima nije UR.
* Ako se clan doda u sekciju kroz `UF_MEMBER_FORM`, kreira se ili reaktivira odgovarajuci `member_sections` red.
* Ako se clan ukloni iz sekcije kroz `UF_MEMBER_FORM`, red u `member_sections` se ne brise fizicki nego prelazi na `INACTIVE`.
* Svaka promena pripadnosti clana sekciji treba da napravi zapis u `member_section_history`.

## 10a. section_role_assignments

Status:
POSTOJI U REPO SQL/MIGRATION FAJLU

Svrha:
Sekcijske uloge za UR-ove i korepetitora.

SQL fajl:

* `supabase/section-role-assignments-setup.sql`

Važna polja:

* `id` uuid primary key default `gen_random_uuid()`
* `society_id` uuid not null references `societies(id)` on delete cascade
* `section_id` uuid not null references `sections(id)` on delete cascade
* `society_member_id` uuid not null references `society_members(id)` on delete cascade
* `role` text not null
* `status` text not null default `'ACTIVE'`
* `created_at` timestamp with time zone default `now()`
* `updated_at` timestamp with time zone default `now()`

Ogranicenja:

* `role` moze biti samo `UR` ili `KOREPETITOR`.
* `status` moze biti samo `ACTIVE` ili `INACTIVE`.
* Unique index za `section_id` + `society_member_id` + `role` sprecava dupliranje iste uloge istom clanu u istoj sekciji.

Pravila:

* `role` podrzava:
  * `UR`
  * `KOREPETITOR`
* Jedna sekcija moze imati vise aktivnih UR-ova.
* Korepetitor je posebna sekcijska uloga.
* Korepetitor nije isto sto i obican clan sekcije.
* Korepetitora sekciji dodeljuje predsednik ili korisnik sa izričitom dozvolom za raspoređivanje sekcijskih uloga.
* UR-a i korepetitora sekciji može dodeliti ili ukloniti predsednik ili ovlašćeni korisnik, ali kandidat prethodno mora imati odgovarajuću aktivnu funkciju u društvu.
* Aktivna funkcija `UR` u `society_member_function_assignments` uslov je za izbor, a aktivna dodela u `section_role_assignments` određuje početne nadležne sekcije UR-a.
* Sekcijske uloge se ne brisu fizicki; koriste `ACTIVE` i `INACTIVE`.
* Potrebno je spreciti duplu aktivnu dodelu iste uloge istom clanu u istoj sekciji.

## 10b. member_section_history

Status:
POSTOJI U REPO SQL/MIGRATION FAJLU

Svrha:
Istorija promena statusa clanstva clana u sekciji.

SQL fajl:

* `supabase/member-section-history-setup.sql`

Važna polja:

* `id` uuid primary key default `gen_random_uuid()`
* `member_section_id` uuid not null references `member_sections(id)` on delete cascade
* `society_id` uuid not null references `societies(id)` on delete cascade
* `section_id` uuid not null references `sections(id)` on delete cascade
* `society_member_id` uuid not null references `society_members(id)` on delete cascade
* `old_status` text null
* `new_status` text not null
* `effective_date` date not null default `current_date`
* `changed_by_user_id` uuid null
* `note` text null
* `created_at` timestamptz default `now()`
* `updated_at` timestamptz default `now()`

Ogranicenja:

* `new_status` moze biti samo `ACTIVE` ili `INACTIVE`.
* `old_status` moze biti null samo kod prvog dodavanja clana u sekciju.
* `old_status`, kada postoji, moze biti samo `ACTIVE` ili `INACTIVE`.

Pravila:

* `member_sections` cuva trenutno stanje clanstva clana u sekciji.
* Za istog clana i istu sekciju postoji samo jedan red u `member_sections`.
* `member_sections.status` moze biti `ACTIVE` ili `INACTIVE`.
* Kada se clan ukloni iz sekcije, red u `member_sections` se ne brise; status se menja na `INACTIVE`.
* Kada se clan ponovo vrati u istu sekciju, ne pravi se novi `member_sections` red; postojeci red se reaktivira na `ACTIVE`.
* Istorija promena clanstva u sekciji ne cuva se kroz duple redove u `member_sections`.
* Za istoriju se koristi iskljucivo `member_section_history`.
* `member_section_history` cuva kada je clan dodat u sekciju, deaktiviran, ponovo aktiviran, ko je izvrsio promenu, datum od kada promena vazi i napomenu ako postoji.
* Pravilo citanja:
  * `member_sections` = trenutno stanje
  * `member_section_history` = istorija promena
* Kada se clan prvi put doda u sekciju:
  * `member_sections.status = ACTIVE`
  * `member_section_history.old_status = null`
  * `member_section_history.new_status = ACTIVE`
* Kada se clan deaktivira:
  * `member_sections.status = INACTIVE`
  * `member_section_history.old_status = ACTIVE`
  * `member_section_history.new_status = INACTIVE`
* Kada se clan ponovo aktivira:
  * `member_sections.status = ACTIVE`
  * `member_section_history.old_status = INACTIVE`
  * `member_section_history.new_status = ACTIVE`

## Funkcije i sekcije

* Funkcija nije isto što i sekcija.
* Funkcija clana se ne cuva u `society_members.funkcija`; jedan clan moze imati vise funkcija kroz `society_member_function_assignments`.
* Sekcije su grupe/probne jedinice unutar društva.
* `Predsednik`, `Sekretar`, `Blagajnik`, `Upravnik`, `UR`, `Korepetitor` i `Član` su funkcije člana društva.
* `UR` znači `Umetnički rukovodilac`; `Upravnik` je posebna funkcija i nije značenje skraćenice `UR`.
* `UR` i `Korepetitor` su i dalje članovi društva.
* `UR` i `Korepetitor` mogu imati članarinu, `ACTIVE`/`INACTIVE` status, `start_date` i `member_status_history` kao svi drugi članovi.
* `UR` i `Korepetitor` mogu biti povezani sa jednom ili više sekcija kroz `member_sections`, a njihova sekcijska uloga vodi se kroz `section_role_assignments`.
* Prisustvo se prati po probi, sekciji i članu društva kroz `attendance_sessions`, `attendance_records` i `attendance_record_history`.

## 10c. attendance_sessions

Status:
PLANIRANO ZA V1 MODUL `PRISUSTVO`

Svrha:
Jedan zapis predstavlja jednu otvorenu ili zatvorenu probu konkretne sekcije.

Planirana važna polja:

* `id` uuid primary key default `gen_random_uuid()`
* `society_id` uuid not null references `societies(id)`
* `section_id` uuid not null references `sections(id)`
* `status` text not null, dozvoljene vrednosti `OPEN`, `CLOSED` i `CANCELLED`
* `opened_at` timestamp with time zone not null default `now()`
* `opened_by` identitet prijavljenog korisnika koji je otvorio probu
* `closed_at` timestamp with time zone null
* `closed_by` identitet prijavljenog korisnika koji je zatvorio probu
* `cancelled_at` timestamp with time zone null
* `cancelled_by` identitet prijavljenog korisnika koji je otkazao probu
* `planned_end_at` timestamp with time zone not null
* `auto_close_at` timestamp with time zone not null
* `close_type` text null, dozvoljene vrednosti za zatvorenu probu `MANUAL` i `AUTOMATIC`
* `created_at` timestamp with time zone not null default `now()`
* `updated_at` timestamp with time zone not null default `now()`

Pravila:

* Datum probe izvodi se iz `opened_at`; datum i vreme ne unose se ručno.
* `closed_at` se postavlja automatski pri zatvaranju probe.
* Parcijalni unique indeks treba da dozvoli najviše jedan `OPEN` zapis po `section_id`.
* Proba se ne briše kroz aplikaciju.
* Greškom otvorena proba prelazi iz `OPEN` u `CANCELLED`; otkazana proba ne predstavlja održanu probu.
* Pri otvaranju se `planned_end_at` izračunava iz tadašnjeg `sections.rehearsal_duration_minutes`.
* `auto_close_at` je uvek tačno 30 minuta nakon `planned_end_at`.
* Vremenski plan se čuva na probi i ne menja se ako predsednik kasnije promeni trajanje sekcije.
* Periodični serverski posao zatvara dospele otvorene probe i beleži `closed_by_role = SYSTEM` i `close_type = AUTOMATIC`.

## 10d. attendance_records

Status:
PLANIRANO ZA V1 MODUL `PRISUSTVO`

Svrha:
Čuva trenutno, važeće stanje prisustva jednog člana na jednoj probi i predstavlja snimak spiska članova u trenutku otvaranja probe.

Planirana važna polja:

* `id` uuid primary key default `gen_random_uuid()`
* `attendance_session_id` uuid not null references `attendance_sessions(id)`
* `society_member_id` uuid not null references `society_members(id)`
* `status` text not null default `ABSENT`, dozvoljene vrednosti `ABSENT` i `PRESENT`
* `updated_at` timestamp with time zone not null default `now()`
* `updated_by` identitet prijavljenog korisnika koji je poslednji promenio status

Pravila:

* Pri otvaranju probe kreira se po jedan zapis sa statusom `ABSENT` za svakog tada aktivnog člana izabrane sekcije.
* Unique constraint po `attendance_session_id` + `society_member_id` sprečava dupliranje člana na istoj probi.
* Svaka promena statusa odmah se trajno čuva; klijentska memorija nije izvor istine.
* Nakon zatvaranja probe status može menjati samo predsednik društva.

## 10e. attendance_record_history

Status:
PLANIRANO ZA V1 MODUL `PRISUSTVO`

Svrha:
Neizmenjivi audit trag svih promena prisustva, uključujući promene tokom otvorene probe i naknadne predsedničke ispravke.

Planirana važna polja:

* `id` uuid primary key default `gen_random_uuid()`
* `attendance_record_id` uuid not null references `attendance_records(id)`
* `old_status` text null
* `new_status` text not null, dozvoljene vrednosti `ABSENT` i `PRESENT`
* `changed_at` timestamp with time zone not null default `now()`
* `changed_by` identitet prijavljenog korisnika
* `changed_by_role` text not null
* `session_status_at_change` text not null, vrednost `OPEN` ili `CLOSED`
* `reason` text null, obavezno kada je `session_status_at_change = CLOSED`

Pravila:

* Audit red se kreira pri svakoj promeni statusa.
* Promena zatvorene probe bez razloga nije dozvoljena.
* Audit redovi se ne ažuriraju i ne brišu kroz aplikaciju.
* Finalna implementacija identiteta u kolonama `opened_by`, `closed_by`, `updated_by` i `changed_by` biće usklađena sa Supabase Auth modelom.

## V1 modul DOGAĐAJI

Status:
PLANIRANO ZA SQL MIGRACIJU

Kompletna poslovna pravila, prava, obaveznost podataka i veze definisani su u `docs/EVENTS_V1.md`.

Postojeće tabele koje se dopunjuju:

* `people.nationality` text null
* `people.passport_issuing_country` text null
* `section_role_assignments.can_manage_repertoire` boolean not null default false

Planirane nove tabele:

* `society_events` – osnovni podaci koncerta ili putovanja i approval workflow
* `event_status_history` – neizmenjiva istorija statusa događaja
* `event_sections` – sekcije uključene u događaj
* `event_participants` – članovi i gosti koji učestvuju ili putuju
* `event_participant_sections` – sekcije sa kojima član učestvuje
* `repertoire_items` – centralne numere društva
* `repertoire_item_sections` – sekcije koje koriste numeru
* `event_appearances` – pojedinačni nastupi događaja
* `event_appearance_repertoire` – program nastupa po sekciji
* `event_repertoire_participants` – izvođači konkretne numere
* `person_data_change_requests` – predlozi izmena podataka osobe koje odobrava predsednik

Ključna ograničenja:

* događaj ima tip `CONCERT` ili `TRIP`
* status događaja je `DRAFT`, `PENDING`, `APPROVED`, `REJECTED`, `CANCELLED` ili `COMPLETED`
* jedan događaj može imati istu sekciju samo jednom
* jedna osoba može biti učesnik istog događaja samo jednom
* gost obavezno ima `person_id`, ali nema `society_member_id`
* samo član događaja može biti povezan sa sekcijom ili numerom
* povratak mora biti posle polaska
* finansijski iznosi ne mogu biti negativni
* odobravanje zahteva najmanje jednu sekciju, ali ne zahteva učesnika ni numeru
* `CONFIRMED` učesnik na inostranom putovanju mora imati kompletnu odobrenu putnu dokumentaciju i pasoš koji važi najmanje do povratka

## 11. person_guardians

Status:
POSTOJI U AKTIVNOJ BAZI

Svrha:
Veza maloletnog deteta i roditelja/staratelja.
Roditelji/staratelji se takođe čuvaju u `people`, jer ista osoba može biti i roditelj/staratelj i član društva.
Ne dodavati posebna parent/staratelj polja direktno na record deteta u `people`.

Važna polja:

* `id` uuid primary key default `gen_random_uuid()`
* `child_person_id` uuid not null references `people(id)`
* `guardian_person_id` uuid not null references `people(id)`
* `relationship` text null, vrednost `GUARDIAN` u add-member toku za maloletnog clana
* `is_primary` boolean null, `true` za prvog roditelja/staratelja i `false` za drugog roditelja/staratelja
* `created_at` timestamp with time zone default `now()`
* `updated_at` timestamp with time zone default `now()`

SQL schema:

```sql
create table public.person_guardians (
  id uuid not null default gen_random_uuid(),
  child_person_id uuid not null,
  guardian_person_id uuid not null,
  relationship text null,
  is_primary boolean null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint person_guardians_pkey primary key (id),
  constraint person_guardians_child_person_id_fkey foreign key (child_person_id) references people(id),
  constraint person_guardians_guardian_person_id_fkey foreign key (guardian_person_id) references people(id)
) TABLESPACE pg_default;
```

Veze:

* `child_person_id` -> `people.id`
* `guardian_person_id` -> `people.id`

Pravila:

* `people` čuva sve osobe: punoletne članove, maloletne članove, roditelje/staratelje i osobe koje mogu imati više uloga.
* `society_members` čuva samo osobe koje su članovi društva.
* `person_guardians` povezuje dete iz `people` sa roditeljem/starateljem iz `people`.
* U add-member toku za maloletnog clana `relationship` koristi vrednost `GUARDIAN`.
* `is_primary = true` za prvog roditelja/staratelja.
* `is_primary = false` za drugog roditelja/staratelja ako se koristi.
* Maloletni član mora imati najmanje jednog staratelja.
* Drugi staratelj je opcion.
* Oba staratelja su ravnopravne veze.
* Staratelj može, ali ne mora, imati red u `society_members`.
* Staratelj koji je već član društva koristi isti `people` zapis; ne kreira se duplikat osobe.
* Pre kreiranja novog staratelja proveriti da li osoba već postoji u `people` po email-u.
* Ako se postojeći staratelj pronađe po email-u, `person_guardians` treba da poveže dete sa postojećim `people.id`.
* Roditelji/staratelji koji se unose kroz tok maloletnog clana ne upisuju se u `society_members`.
* Iz child/guardian toka roditelji/staratelji se upisuju samo u `people` i `person_guardians`.
* Roditelji/staratelji se ne tretiraju kao clanovi drustva samo zato sto su roditelji/staratelji.
* Ako roditelj/staratelj kasnije postane clan drustva, add-member tok ga pronalazi po email-u u `people`, koristi isti `person_id` i dodaje ga u `society_members` samo ako vec nije clan tog drustva.
* Ne uvoditi posebna parent polja na `people` zapisu deteta.
* Ne uvoditi dodatne kategorije odnosa.

## UF_MEMBER_FORM add-member tok

Ovaj tok ne uvodi novu tabelu. Pravila koriste postojece tabele `people`, `society_members` i `person_guardians`.

Razlika tabela:

* `people` = sve osobe u sistemu.
* `society_members` = osobe koje su clanovi odredjenog drustva.
* `person_guardians` = veza izmedju maloletnog clana i roditelja/staratelja.

Pocetak add-member toka:

* Kada korisnik klikne `DODAJ CLANA`, forma prvo prikazuje checkbox / switch `Maloletan clan` i email polje.
* Forma odmah razlikuje tok za punoletnog clana i tok za maloletnog clana.
* Ako `Maloletan clan` nije oznacen, email polje predstavlja `Email novog clana`.
* Ako je `Maloletan clan` oznacen, email polje predstavlja `Email roditelja / staratelja`.
* Za maloletnog clana prvi identifikacioni podatak nije email deteta nego email roditelja/staratelja.
* Email deteta se ne forsira jer maloletna deca cesto nemaju svoju email adresu.

Pravila email provere:

* Email je obavezan za punoletnog clana.
* Email prvog roditelja/staratelja je obavezan za maloletnog clana.
* Redosled provere je:
  * da li je email prazan
  * da li je email u validnom formatu
  * tek zatim pretraga u `people.email`
* Ako se email promeni nakon ucitavanja podataka, prethodno ucitani podaci se resetuju i provera krece ponovo.
* Provere se pokrecu pri unosu, napustanju polja i prelasku na sledece polje, ne samo na `SNIMI`.
* `SNIMI` ponovo izvrsava kljucne provere radi sigurnosti.

Pravila kada email postoji u `people`:

* Ne kreira se novi `people` zapis.
* Sistem povlaci postojece podatke.
* U toku za punoletnog clana sistem proverava da li osoba vec ima `society_members` red za trenutno drustvo.
* Ako punoletna osoba vec ima red u `society_members`, prikazuje se poruka da je osoba vec clan tog drustva.
* Ako punoletna osoba nema red u `society_members`, osoba se moze dodati u `society_members` za trenutno drustvo.
* U toku za maloletnog clana pronadjena osoba je roditelj/staratelj; koristi se njegov postojeci `person_id` i ne upisuje se u `society_members` iz ovog toka.

Pravila kada email ne postoji u `people`:

* U toku za punoletnog clana otvaraju se prazna polja za unos nove osobe.
* Pri snimanju punoletnog clana kreira se novi `people` zapis, zatim `society_members` zapis.
* U toku za maloletnog clana otvaraju se prazna polja za unos roditelja/staratelja.
* Pri snimanju maloletnog clana kreira se novi `people` zapis za roditelja/staratelja samo ako ne postoji.

Pravila za maloletnog clana:

* Kada je `Maloletan clan` oznacen, nakon provere email-a prvog roditelja/staratelja otvara se blok za unos podataka maloletnog clana.
* Dete se upisuje u `people`.
* Dete se upisuje u `society_members`.
* Roditelj/staratelj se ne upisuje u `society_members` iz ovog toka.
* Veza dete-roditelj se upisuje u `person_guardians`.
* `relationship = GUARDIAN`.
* `is_primary = true` za Roditelja/Staratelja 1.
* Roditelj/Staratelj 1 je obavezan.
* Roditelj/Staratelj 2 je opcion.
* Za svakog roditelja/staratelja prvo se unosi email.
* Ime, prezime i telefon roditelja/staratelja su vidljivi, ali disabled dok se email ne unese i proveri.
* Ako email postoji u `people`, forma popunjava ime, prezime i telefon i koristi postojeci `person_id`.
* Ako email ne postoji u `people`, ime, prezime i telefon se otkljucavaju za rucni unos i pri snimanju se kreira novi `people` zapis.
* Ako se koristi Roditelj/Staratelj 2, prvo se unosi email, validira se format, proverava se `people`, koristi se postojeci `person_id` ili se kreira novi `people` zapis, a veza se upisuje u `person_guardians` sa `is_primary = false`.

## 12. society_change_requests

Status:
PLANIRANO

Svrha:
Zahtevi za izmenu podataka društva i licence.

Važna polja:
PLANIRANO.

Veze:
PLANIRANO.

## 13. member_data_change_requests

Status:
PLANIRANO

Svrha:
Zahtevi za izmenu podataka clana kada korisnik nema pravo direktne izmene.
Korisnik salje zahtev predsedniku, predsednik odobrava ili odbija, a podaci se menjaju tek nakon odobrenja.

Vazna polja:

* `id`
* `society_id`
* `person_id`
* `requested_by_user_id`
* `field_name`
* `old_value`
* `new_value`
* `status` sa vrednostima `PENDING`, `APPROVED`, `REJECTED`
* `approved_by_user_id`
* `approved_at`
* `created_at`

Veze:

* `society_id` -> `societies.id`
* `person_id` -> `people.id`
* `requested_by_user_id` -> auth korisnik, kada Supabase Auth bude povezan
* `approved_by_user_id` -> auth korisnik predsednika, kada Supabase Auth bude povezan

Pravila:

* Ova tabela je planirana faza, nije obavezna trenutna implementacija.
* Korisnici bez prava direktne izmene ne menjaju podatke odmah.
* Predsednik odobrava ili odbija zahtev.
* Tek odobren zahtev menja podatke.
* Mora se razlikovati vidljivost podatka od prava izmene podatka.
* Osnovni kontakt podaci mogu biti vidljivi korisnicima koji imaju pravo da vide clana.
* Osetljivi podaci kao JMBG, broj pasosa, datum rodjenja, pol i licni identifikacioni podaci traze posebnu dozvolu.

## 14. president_change_requests

Status:
PLANIRANO

Svrha:
Zahtevi za promenu predsednika društva.

Važna polja:

* `id` uuid primary key default `gen_random_uuid()`
* `society_id` uuid not null references `societies(id)`
* `current_president_member_id` uuid not null references `society_members(id)`
* `current_president_person_id` uuid not null references `people(id)`
* `new_president_member_id` uuid not null references `society_members(id)`
* `new_president_person_id` uuid not null references `people(id)`
* `status` text not null default `'PENDING'`
* `requested_by_user_id` uuid null
* `requested_at` timestamp with time zone default `now()`
* `reviewed_by_user_id` uuid null
* `reviewed_by_email` text null
* `reviewed_at` timestamp with time zone null
* `rejection_reason` text null
* `created_at` timestamp with time zone default `now()`
* `updated_at` timestamp with time zone default `now()`

Veze:

* `society_id` -> `societies.id`
* `current_president_member_id` -> `society_members.id`
* `current_president_person_id` -> `people.id`
* `new_president_member_id` -> `society_members.id`
* `new_president_person_id` -> `people.id`

Pravila:

* Jedno društvo može imati samo jednog aktivnog predsednika.
* Funkcija `Predsednik` postoji za svako društvo i ne sme biti obrisana ili deaktivirana.
* Promena predsednika nije obična izmena člana.
* `UF_MEMBER_FORM` ne sme slučajno kreirati dva predsednika.
* Trenutni predsednik pokreće zahtev za promenu predsednika.
* Trenutni predsednik bira novog predsednika samo iz aktivnih članova svog društva.
* Razlog nije obavezan za trenutnog predsednika.
* Master admin odobrava ili odbija zahtev.
* Kada Master admin odobri, prethodni predsednik ostaje clan; dodela funkcije `Predsednik` se uklanja, a po potrebi mu se dodaje dodela funkcije `Clan`.
* Kada Master admin odobri, izabrani član postaje `Predsednik`.
* Kada Master admin odobri, status zahteva postaje `APPROVED`, a čuvaju se reviewer i vreme pregleda.
* Kada Master admin odbije, ne menja se `society_members`, status zahteva postaje `REJECTED`, a razlog odbijanja može biti sačuvan.
* Može postojati samo jedan `PENDING` zahtev za promenu predsednika po društvu.

## DEV Privremeno

Sledeći fajlovi su razvojni workaround za RLS dok uloge nisu povezane sa Supabase Auth:

* `supabase/president-reg-dev-select-policy.sql`
* `supabase/president-reg-dev-update-policy.sql`

Ove policy-je treba zameniti finalnim pravilima koja proveravaju Master admin rolu.

## Master admin V1

Status:

POSTOJI U AKTIVNOJ BAZI; PRIMENJENO 2026-07-24 IZ `supabase/master-admin-v1-setup.sql`

Master admin koristi isključivo agregatne brojeve aktivnih i neaktivnih članstava i sekcija. Pojedinačni podaci članova i sekcija nisu deo Master admin read modela.

Nove platformske tabele:

* `platform_license_plans` — konfigurabilni paketi, mesečna i godišnja cena, valuta i limiti aktivnih članova i sekcija
* `society_license_periods` — plaćeni i promotivni periodi sa istorijskim snimkom cene i limita
* `platform_license_payments` — pune ručno evidentirane uplate za licencu i njihova auditovana poništavanja
* `society_suspensions` — istorija početka i završetka read-only suspenzije
* `platform_license_notifications` — red planiranih i poslatih obaveštenja o isteku, suspenziji i reaktivaciji
* `master_admin_audit_log` — neizmenjiva istorija platformske administracije

Ključna pravila:

* status društva u V1 je `ACTIVE` ili `SUSPENDED`
* licencni period ima inkluzivne datume `valid_from` i `valid_until`
* izvor perioda je `PAID` ili `PROMOTIONAL`
* plaćeni period je `MONTHLY` ili `ANNUAL`, a promotivni traje 3, 6 ili 12 meseci
* licencna uplata je samo puna; nema delimične uplate, viška ili kredita
* cena, valuta i limiti paketa kopiraju se na period kao istorijski snimak
* promotivni period nema povezanu uplatu i zahteva razlog
* društvo prelazi u suspenziju prvog dana nakon isteka neprodužene licence
* arhiviranje i fizičko brisanje društva nisu deo V1

Detaljna poslovna pravila nalaze se u `docs/MASTER_ADMIN_V1.md`.

`supabase/master-admin-v1-society-detail-workflows.sql` priprema:

* `master_admin_get_society_detail` — agregatni detalj bez identiteta članova i naziva sekcija
* `master_admin_set_society_status` — kontrolisanu suspenziju i reaktivaciju sa obaveznim razlogom, istorijom suspenzije i Master admin auditom

Migracija detalja društva primenjena je i funkcionalno potvrđena u aktivnoj bazi 2026-07-24.

`supabase/master-admin-v1-license-workflows.sql` primenjen je u aktivnoj bazi 2026-07-25. On:

* upisuje potvrđene pakete `Malo društvo`, `Standard` i `Veliko društvo` sa cenama bez poreza i limitima
* dodaje agregatni read model `master_admin_get_license_management`
* dodaje atomski workflow `master_admin_grant_license` za mesečne, godišnje i promotivne periode
* proverava aktivne članove i sekcije prema limitu izabranog paketa
* za plaćenu licencu istovremeno evidentira punu uplatu i licencni period
* nastavlja novi period nakon već evidentiranog perioda kada se oni preklapaju
* sprečava ponovnu promociju bez eksplicitne potvrde Master admina
* automatski podiže samo suspenziju čiji je razlog istek licence; administrativna suspenzija ostaje aktivna
* upisuje Master admin audit za uplatu, dodelu licence i eventualnu reaktivaciju

`supabase/master-admin-v1-license-price-workflows.sql` primenjen je u aktivnoj bazi 2026-07-25. Funkcije `master_admin_get_license_prices` i `master_admin_update_license_price` omogućavaju čitanje aktivnog cenovnika i pojedinačnu promenu mesečne/godišnje cene uz obavezan razlog i audit. Promena paketa ne menja istorijske snimke cena na postojećim licencnim periodima.

## Finansije V1

Status:
POSTOJI U AKTIVNOJ BAZI; DEFINISANO U REPO SQL FAJLU `supabase/finance-v1-tables-setup.sql`

Detaljna poslovna pravila nalaze se u `docs/FINANCE_V1.md`.

### Proširenja postojećih tabela

`societies` dobija:

* `base_currency` — osnovna ISO valuta društva
* `default_membership_fee_amount` — standardni mesečni iznos
* `finance_start_month` — prvi obračunski mesec
* `payment_instructions` — tekst instrukcije u opomenama
* `finance_last_reminder_at` i `finance_last_reminder_by_user_id`

`society_members` dobija:

* `membership_fee_mode` — `STANDARD`, `CUSTOM` ili `EXEMPT`

Postojeća polja `membership_fee_required` i `membership_fee_amount` ostaju trenutna kompatibilna vrednost dok aplikacija ne pređe na kontrolisani finansijski workflow.

### Nove tabele

* `member_fee_setting_history` — vremenska istorija režima i iznosa članarine
* `society_fee_calendar` — odluka da li je konkretan mesec naplativ
* `member_fee_grants` — dodeljenih 0–3 gratis naplativa meseca
* `membership_fee_assessments` — rezultat mesečne provere za svakog člana
* `financial_obligations` — konkretne mesečne članarine i kotizacije
* `financial_payments` — primljene uplate i godišnji broj potvrde
* `financial_credit_entries` — append-only nastanak i korišćenje kredita
* `financial_obligation_allocations` — raspodela uplate ili kredita na obavezu
* `financial_refunds` — povraćaji kredita i njihova poništenja
* `financial_number_counters` — bezbedna godišnja numeracija po društvu
* `financial_audit_log` — neizmenjiv audit poslovnih promena
* `society_email_connections` — opciona Gmail OAuth veza društva
* `financial_email_outbox` — pouzdan red email potvrda, poništenja i opomena
* `financial_reminder_runs` — istorija grupnog slanja opomena

### Ključna ograničenja

* Jedan član može imati najviše jedan obračun i jednu članarinsku obavezu za isti mesec.
* Jedan učesnik može imati najviše jednu kotizaciju po događaju.
* Uplata, obaveza i raspodela moraju koristiti istu valutu; konačnu proveru radi kontrolisana bazna funkcija.
* Zbir važećih raspodela određuje plaćeni iznos obaveze.
* Kredit se računa kao zbir append-only kreditnih stavki po osobi i valuti.
* Poništeni brojevi uplata i povraćaja se ne koriste ponovo.
* Finansijske tabele nemaju privremene javne DEV read politike; pristup ostaje zatvoren do kontrolisanih funkcija.
* Finansijski klijentski upisi su zabranjeni; promene će se obavljati preko kontrolisanih funkcija.

### Repo workflow migracije

* `supabase/finance-v1-membership-workflows.sql` definiše kontrolisano početno podešavanje Finansija, kalendar naplativih meseci, promenu standardne i pojedinačne članarine, početne gratis mesece i idempotentan mesečni obračun sa automatskim korišćenjem kredita.
* `supabase/finance-v1-monthly-cron.sql` zakazuje automatski obračun svakog prvog dana u mesecu u 00:10 UTC.
* `finance-v1-membership-workflows.sql` je primenjen u aktivnoj bazi 2026-07-22.
* `finance-v1-monthly-cron.sql` je primenjen u aktivnoj bazi 2026-07-22 kao cron zadatak ID `2`.
* `supabase/finance-v1-payment-workflows.sql` definiše atomsku godišnju numeraciju, evidentiranje jedne uplate, raspodelu na više obaveza iste valute, korišćenje i stvaranje kredita, osvežavanje statusa obaveze i predsedničko poništavanje uplate sa vraćanjem prethodnog stanja. Primenjen je u aktivnoj bazi 2026-07-22.
* `supabase/finance-v1-event-refund-workflows.sql` definiše finansijski kontrolisane statuse učesnika, nastanak kotizacije na `CONFIRMED`, predsedničko poništavanje na `CANCELLED`, kredit pri otkazivanju učesnika ili celog događaja i predsednički povraćaj/poništavanje povraćaja. Primenjen je u aktivnoj bazi 2026-07-22.
* Lokalna dopuna od 2026-07-23 dodaje `finance_cancel_event_section`: atomsku proveru predsedničkog prava, obavezan razlog, očuvanje učesnika povezanih sa drugim sekcijama, uklanjanje ekskluzivnih nepotvrđenih učesnika i auditovano poništavanje njihovih kotizacija uz kredit za ranije plaćeni iznos. Dopuna i DEV test pristup primenjeni su u aktivnoj bazi, a funkcionalna provera završena je 2026-07-24.
* `supabase/finance-v1-read-workflows.sql` definiše bezbednu pretragu članova, putnika i roditelja/staratelja i objedinjeni read-only finansijski profil sa otvorenim obavezama, kreditima i istorijom uplata. Primenjen je u aktivnoj bazi 2026-07-22.

## Planirani model dozvola V1

Status:

PRIMENJEN U AKTIVNOJ BAZI 2026-07-26

Izvor:

* `supabase/permissions-v1-foundation.sql`
* `supabase/permissions-v1-foundation-diagnostic.sql`
* `docs/PERMISSIONS_V1.md`
* `docs/PERMISSIONS_IMPLEMENTATION_PLAN.md`

Planirane tabele:

* `permission_catalog` — globalni kontrolisani katalog dozvola i dozvoljenih opsega
* `system_function_permission_templates` — početna i zaključana prava sistemskih funkcija
* `society_function_permission_rules` — zajednička prava funkcije u konkretnom društvu
* `society_member_permission_overrides` — pojedinačni `ALLOW` i `DENY` izuzeci
* `permission_change_audit` — neizmenjiva istorija promena funkcija i dozvola

Faza 1 priprema strukturu, katalog i početna pravila postojećih društava. Dijagnostika nakon primene potvrdila je 67 aktivnih dozvola, 154 sistemska šablona, 140 pravila funkcija i nula neispravnih opsega, pogrešnih društava ili društava bez aktivne funkcije predsednika.

Foundation još ne menja postojeće finansijske, sekcijske, događajne i druge RPC provere funkcija. Centralni obračun efektivnih prava i sprovođenje po modulima dolaze u narednim fazama.

Centralni read obračun pripremljen je u:

* `supabase/permissions-v1-effective-read.sql`
* `supabase/permissions-v1-effective-read-diagnostic.sql`

Status centralnog read obračuna:

PRIMENJEN U AKTIVNOJ BAZI 2026-07-26

Planirane interne funkcije:

* `permissions_get_effective_rules` — sabira zaključana članska i roditeljska prava, prava svih aktivnih funkcija i pojedinačne izuzetke
* `permissions_has_scope` — proverava da li efektivna dozvola postoji u jednom od traženih opsega

`DENY` uklanja promenljivo nasleđeno pravo, ali ne može ukloniti zaključano početno pravo. `ALLOW` ne može otvoriti predsedničku dozvolu `permissions.manage`. Funkcije još nisu direktno dostupne klijentu i ne proveravaju konkretan ciljni zapis; ciljna provera dolazi pri sprovođenju dozvola po modulima.

Dijagnostika nakon primene potvrdila je:

* 10 aktivnih članova
* 4 člana sa najmanje jednom funkcijom
* 2 člana sa više funkcija
* 3 roditeljska/starateljska konteksta
* 0 grešaka obaveznih članskih prava
* 0 grešaka obaveznih roditeljskih prava
* 0 nedostajućih zaključanih prava funkcija
* 0 curenja predsedničke dozvole

Kontrolisani workflow-i upravljanja pripremljeni su u:

* `supabase/permissions-v1-management-workflows.sql`
* `supabase/permissions-v1-management-workflows-diagnostic.sql`

Status workflow-a upravljanja:

PRIMENJENI U AKTIVNOJ BAZI 2026-07-26; FUNKCIONALNA PROVERA ČEKA AKTIVNU DODELU FUNKCIJE PREDSEDNIK

Planirane funkcije omogućavaju predsedniku:

* pregled kataloga i trenutnih pravila izabrane funkcije
* pretragu aktivnih članova izabrane funkcije
* pregled pojedinačnih izuzetaka i efektivnih izvora prava
* atomsko čuvanje paketa zajedničkih pravila funkcije
* atomsko čuvanje pojedinačnih `INHERIT`, `ALLOW` i `DENY` izuzetaka

Svaka stvarna promena zahteva razlog i upisuje neizmenjiv audit. Zaključana prava, predsednička dozvola i suspendovano društvo zaštićeni su u kontrolisanim funkcijama. Funkcije još nisu dodeljene `anon` ili `authenticated` ulozi.

Prva read-only dijagnostika vratila je `president_actor_count = 0`. Funkcija `Predsednik` postoji u društvu, ali trenutno nema aktivnog člana sa tom dodelom, pa President-only read i write tokovi još nisu funkcionalno provereni.
