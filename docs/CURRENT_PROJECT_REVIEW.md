# FOLKLORAŠ – trenutni pregled projekta

## 1. Kratak rezime trenutnog stanja

Projekat FOLKLORAŠ je Next.js aplikacija povezana sa Supabase bazom. Trenutno postoji funkcionalan osnovni tok za registraciju društva, pregled zahteva, odobravanje/odbijanje zahteva, kreiranje aktivnog društva pri odobrenju, pregled društava i master admin izmenu podataka društva kroz zajedničku formu `SocietyDataForm`.

Dokumentacija je znatno šira od trenutno stabilno zatvorene implementacije. Ona već definiše budući model članova, roditelja/staratelja, sekcija, funkcija, onboardinga predsednika, promena predsednika, zahteva za izmenu podataka, multi-society princip i finalni Auth/RLS model. U kodu su neki od tih delova već započeti ili dobrim delom implementirani, posebno `UF_MEMBER_FORM`, stranica `CLANOVI` i modul `MOJE SEKCIJE`.

Najvažnija granica trenutnog stanja je da aplikacija još radi u razvojnom modelu: uloge su simulirane kroz test role/localStorage, više ekrana bira prvo aktivno društvo umesto društva iz realnog korisničkog konteksta, a RLS politike za više tabela su privremene DEV anon/authenticated politike. Supabase Auth i finalna role-based autorizacija još nisu potpuno uvedeni.

## 2. Šta je do sada urađeno

### Registracija društva

- Postoji ruta `app/registracija-drustva/page.tsx`.
- Forma koristi zajedničku komponentu `app/_components/SocietyDataForm.tsx`.
- Zahtev se upisuje u tabelu `PresidentReg`.
- Podaci predsednika se upisuju u registracioni zahtev, ali predsednik se ne kreira automatski kao član.
- Lozinka se trenutno hash-uje na klijentu i čuva u `PresidentReg`, što je razvojni/privremeni obrazac dok Supabase Auth nije potpuno uveden.
- Podrazumevana licenca je `Free`.
- Frontend koristi `pib`, a tabela `PresidentReg` i dalje ima kolonu `PIB`.

### Master admin deo

- Postoji aplikacioni layout sa sidebar menijem u `app/_components/AppShell.tsx`.
- Navigacija se filtrira prema test ulozi iz `app/_lib/testRoles.ts` i `app/_lib/navigation.ts`.
- Za Master admin rolu postoje meniji: `Društva`, `Zahtevi na čekanju`, `Odobreni zahtevi`, `Odbijeni zahtevi`, `Podešavanja sistema`.
- Ne postoji još poseban pun Master admin dashboard, već su implementirani konkretni pregledi i akcije.

### Odobravanje zahteva

- Lista zahteva na čekanju postoji u `app/(application)/zahtevi-na-cekanju/page.tsx`.
- Detalj zahteva i akcije postoje u `app/(application)/zahtevi-na-cekanju/[id]/page.tsx`.
- Approval workflow:
  - učitava `PresidentReg`,
  - proverava da zahtev nije već obrađen,
  - proverava duplikate društva po PIB-u i matičnom broju,
  - kreira red u `societies`,
  - kreira početne funkcije u `society_member_functions`,
  - kreira početne sekcije u `sections`,
  - pokušava da kreira `user_onboarding_state` samo ako postoji `presidentUserId`,
  - ažurira `PresidentReg` na `APPROVED` i upisuje `societyId`.
- Odbijanje zahteva ažurira `PresidentReg.StatReg` na `REJECTED`.
- U kodu postoji TODO da approval workflow treba prebaciti u transakciju/RPC.

### Društva

- Lista društava postoji u `app/(application)/drustva/page.tsx`.
- Detalj/izmena društva postoji u `app/(application)/drustva/[id]/page.tsx`.
- Detalj društva koristi isti `SocietyDataForm` u `master` režimu.
- Master admin može direktno menjati podatke u tabeli `societies`.
- Dokumentacija kaže da predsednik ne menja direktno `societies`, već šalje zahtev; taj workflow još nije implementiran.

### Članovi

- Postoji komponenta `app/_components/UF_MEMBER_FORM.tsx`.
- Postoji stranica `app/(application)/clanovi/page.tsx`.
- Implementirani su:
  - unos punoletnog člana,
  - unos maloletnog člana,
  - provera email-a,
  - sprečavanje dupliranja člana u istom društvu,
  - kreiranje/ponovno korišćenje `people`,
  - kreiranje `society_members`,
  - kreiranje prvog reda u `member_status_history`,
  - unos roditelja/staratelja u `people`,
  - povezivanje roditelja/staratelja kroz `person_guardians`,
  - dodela funkcija kroz `society_member_function_assignments`,
  - edit člana i ažuriranje osnovnih podataka.
- Postoji pretraga članova po imenu, prezimenu, telefonu ili email-u.
- Stranica trenutno bira prvo aktivno društvo iz baze, što nije finalni multi-society model.

### Sekcije

- Dokumentacija detaljno definiše sekcije, članstvo u sekcijama, istoriju i sekcijske uloge.
- Postoji modul `app/(application)/moje-sekcije/page.tsx`.
- Modul radi sa tabelama:
  - `sections`,
  - `member_sections`,
  - `member_section_history`,
  - `section_role_assignments`,
  - `society_members`,
  - `people`,
  - `person_guardians`.
- Implementirano je kreiranje sekcija, izmena naziva, aktivacija/deaktivacija, dodela UR/Korepetitor uloga, pregled članova sekcije, reaktivacija postojećeg članstva i zapisivanje istorije promena u `member_section_history`.
- Modul koristi test ulogu (`Predsednik`, `UR`, itd.) umesto realne Supabase Auth role.

### Uloge i dozvole

- U dokumentaciji su definisane uloge: Master admin, Predsednik, UR, Blagajnik, Sekretar, Član, Roditelj.
- U aplikaciji su trenutno test uloge definisane u `app/_lib/testRoles.ts`.
- Meni se filtrira preko `app/_lib/navigation.ts`.
- Realna autorizacija preko Supabase Auth, korisničkih uloga i finalnih RLS pravila nije završena.
- Predsednik i UR pravila su delimično simulirana u `MOJE SEKCIJE`, ali nisu kriptografski/serverski zaštićena kroz finalni RLS model.

### Supabase integracija

- Postoji `app/_lib/supabaseClient.ts`.
- Supabase klijent koristi `NEXT_PUBLIC_SUPABASE_URL` i `NEXT_PUBLIC_SUPABASE_ANON_KEY`.
- U istom fajlu su ručno definisani TypeScript tipovi za glavne tabele.
- Aplikacija direktno poziva Supabase iz client komponenti.

### RLS / DEV politike

- Dokumentacija i SQL fajlovi jasno označavaju više DEV politika kao privremene.
- DEV politike postoje za:
  - `PresidentReg` select/update,
  - `member_sections`,
  - `member_section_history`,
  - `section_role_assignments`.
- Ove politike daju širok pristup `anon` i/ili `authenticated` rolama i moraju se zameniti finalnim pravilima.

### Dizajn i layout

- Postoji globalni stil u `app/globals.css`.
- Postoji aplikacioni shell sa sidebarom i headerom.
- Većina ekrana koristi iste klase: `card`, `dashboard-card`, `form-stack`, `page-heading`, `button`.
- UI je funkcionalan, ali deo tekstova u nekim fajlovima prikazuje mojibake karaktere u terminalu/kodu, što je već navedeno kao tehnički dug u dokumentaciji.

### Ostalo

- Postoje placeholder stranice za module kao što su finansije, garderoba, izveštaji, koncerti, prisustvo, podešavanja, moja deca i moji podaci.
- Postoji test stranica `app/(application)/test-uf-member-form/page.tsx` za vizuelnu proveru `UF_MEMBER_FORM`.
- `package.json` ima skripte `dev`, `build`, `start` i `typecheck`.

## 3. Šta je implementirano u aplikaciji

### Registracija društva

Šta radi:
Omogućava javni unos zahteva za registraciju društva. Podaci o društvu i predsedniku se snimaju u `PresidentReg` sa statusom `PENDING`.

Gde se nalazi:
- `app/registracija-drustva/page.tsx`
- `app/_components/SocietyDataForm.tsx`
- `app/_lib/supabaseClient.ts`

Najvažnije tabele:
- `PresidentReg`

Napomena:
Supabase Auth još nije finalno uključen; `presidentUserId` se upisuje kao `null`, a lozinka se čuva kao hash u registracionom zahtevu.

### Pregled i obrada registracionih zahteva

Šta radi:
Master admin vidi zahteve na čekanju, odobrene i odbijene zahteve. Detalj zahteva omogućava odobravanje ili odbijanje.

Gde se nalazi:
- `app/(application)/zahtevi-na-cekanju/page.tsx`
- `app/(application)/zahtevi-na-cekanju/[id]/page.tsx`
- `app/(application)/odobreni-zahtevi/page.tsx`
- `app/(application)/odbijeni-zahtevi/page.tsx`

Najvažnije tabele:
- `PresidentReg`
- `societies`
- `society_member_functions`
- `sections`
- `user_onboarding_state`

Napomena:
Approval nije transakcijski. Ako se neki korak posle kreiranja društva ne izvrši, moguće je delimično stanje.

### Aktivna društva i master izmena društva

Šta radi:
Prikazuje društva iz `societies` i omogućava izmenu podataka društva kroz isti form koji se koristi pri registraciji.

Gde se nalazi:
- `app/(application)/drustva/page.tsx`
- `app/(application)/drustva/[id]/page.tsx`
- `app/_components/SocietyDataForm.tsx`

Najvažnije tabele:
- `societies`

Napomena:
Direktna izmena društva je trenutno master admin tok. Zahtevi predsednika za izmenu podataka društva još nisu implementirani.

### Univerzalna forma društva

Šta radi:
Jedna komponenta pokriva unos/izmenu podataka društva kroz režime `registration`, `president` i `master`.

Gde se nalazi:
- `app/_components/SocietyDataForm.tsx`

Najvažnije tabele:
- `PresidentReg`
- `societies`

Napomena:
`getLicensePrice` je trenutno u ovoj komponenti, što je dokumentovano kao tehnički dug.

### Univerzalna forma člana

Šta radi:
Predstavlja centralnu formu za člana. Podržava režime `create`, `edit` i `president_onboarding`. Ima početni wizard izbor za maloletnog člana, email lookup, roditelje/staratelje, status članstva, datum početka, članarinu i funkcije.

Gde se nalazi:
- `app/_components/UF_MEMBER_FORM.tsx`
- `app/(application)/clanovi/page.tsx`
- `app/(application)/test-uf-member-form/page.tsx`

Najvažnije tabele:
- `people`
- `society_members`
- `member_status_history`
- `person_guardians`
- `society_member_functions`
- `society_member_function_assignments`
- `sections`
- `member_sections`

Napomena:
Forma ima sekcijski blok i `selectedSectionIds`, što je sada usklađeno sa novom odlukom da `UF_MEMBER_FORM` upravlja pripadnošću člana sekcijama kroz checkbox listu.

### Modul Članovi

Šta radi:
Učitava prvo aktivno društvo, prikazuje članove, omogućava pretragu, dodavanje i izmenu člana kroz `UF_MEMBER_FORM`.

Gde se nalazi:
- `app/(application)/clanovi/page.tsx`

Najvažnije tabele:
- `societies`
- `people`
- `society_members`
- `member_status_history`
- `person_guardians`
- `society_member_functions`
- `society_member_function_assignments`
- `sections`
- `member_sections`

Napomena:
Nije još vezano za realnog ulogovanog korisnika i njegovo društvo. Koristi prvo aktivno društvo.

### Modul Moje sekcije

Šta radi:
Upravlja sekcijama, UR/Korepetitor ulogama i pregledom članova sekcije. Predsednik kroz test rolu može da kreira/menja/deaktivira sekcije i uloge. UR kroz test rolu vidi samo simulirano dostupne sekcije.

Gde se nalazi:
- `app/(application)/moje-sekcije/page.tsx`

Najvažnije tabele:
- `societies`
- `sections`
- `section_role_assignments`
- `society_members`
- `people`
- `member_sections`
- `member_section_history`
- `person_guardians`

Napomena:
Modul je funkcionalno napredniji od statusa u `PROJECT_STATUS.md`, ali i dalje zavisi od test role i DEV RLS politika.

### Navigacija, layout i test role

Šta radi:
Prikazuje aplikacioni shell, sidebar i meni prema izabranoj test ulozi.

Gde se nalazi:
- `app/_components/AppShell.tsx`
- `app/_lib/navigation.ts`
- `app/_lib/testRoles.ts`
- `app/(application)/layout.tsx`

Najvažnije tabele:
- Nema direktne tabele; ovo je frontend simulacija pristupa.

Napomena:
Ovo nije finalni permission sistem.

## 4. Šta je dokumentovano, ali nije jasno da li je završeno

- Finalni Supabase Auth login nije završen.
- Prvi login predsednika nije završen.
- `presidentUserId` se trenutno ne dobija iz realnog Auth toka pri registraciji.
- Onboarding predsednika je dokumentovan i `UF_MEMBER_FORM` ima režim `president_onboarding`, ali nema kompletan realan tok prvog logovanja.
- `user_onboarding_state` postoji u tipu i SQL fajlu, ali se kreira samo ako `PresidentReg.presidentUserId` postoji; u registraciji se trenutno postavlja na `null`.
- Finalne RLS politike nisu završene.
- Master admin rola nije povezana sa Supabase Auth.
- Predsednik/UR/Blagajnik/Sekretar/Član/Roditelj dozvole nisu finalno sprovedene kroz bazu.
- Zahtevi za izmenu podataka društva nisu implementirani.
- Zahtevi za promenu licence nisu implementirani.
- Poseban Master admin dashboard nije implementiran.
- `society_change_requests` je planirana tabela.
- `member_data_change_requests` je planirana tabela.
- `president_change_requests` je dokumentovana kao planirana, a tip postoji u `supabaseClient.ts`, ali dokumentacija kaže da je tabela planirana.
- Promena predsednika nije implementirana.
- Finalno uklanjanje ili migracija `society_members.funkcija` nije urađeno.
- Repo SQL/migracije nisu potpuno usklađene sa aktivnom bazom.
- Nije jasno da li u repo-u postoji kompletan SQL za `societies`, `society_member_functions`, `society_member_function_assignments`, `member_status_history`, `sections`, `member_sections` i `person_guardians`; dokumentacija kaže da aktivna baza postoji, ali repo SQL treba proveriti/uskladiti.
- `member_section_history` i `section_role_assignments` postoje kao SQL fajlovi u repo-u, ali dokumentacija ih ne označava kao ručno potvrđene u aktivnoj bazi.
- Modul `MOJE SEKCIJE` smatra se funkcionalno implementiranim u DEV/V1 opsegu. Finalna prava i RLS ostaju odloženi.
- `UF_MEMBER_FORM` upravlja izborom sekcija kojima član pripada i upisuje trenutno stanje i istoriju promena. `CLANOVI` u ovoj fazi privremeno radi sa pravima predsednika; stvarno UR filtriranje preko `section_role_assignments` odloženo je do uvođenja Auth i korisničkog konteksta.
- Finansije, prisustvo, garderoba, koncerti, izveštaji, moja deca i moji podaci deluju kao placeholder ili nisu analizirani kao završeni funkcionalni moduli.

## 5. Poznate arhitektonske odluke

- Postoji samo jedna univerzalna forma za društvo: `SocietyDataForm`.
- `/registracija-drustva` i `/drustva/[id]` moraju koristiti istu formu društva.
- Interno frontend polje za PIB je `pib`, i ne treba vraćati paralelni `taxId`.
- Postoji samo jedna univerzalna forma za člana: `UF_MEMBER_FORM`.
- `UF_MEMBER_FORM` se koristi za kreiranje člana, izmenu člana, onboarding predsednika i buduće role-based tokove.
- Zabranjeno je praviti posebnu formu za profil predsednika.
- Predsednik se ne kreira automatski kao član pri approval-u društva.
- Predsednik se unosi kroz `UF_MEMBER_FORM` tokom prvog logovanja/onboardinga.
- Onboarding predsednika prati se preko `user_onboarding_state`, a ne proverom `society_members` pri svakom logovanju.
- Predsednik tokom onboardinga mora biti punoletan.
- `society_members.start_date` je poslovno obavezan i može biti datum iz prošlosti.
- Prvi `member_status_history` red se kreira iz `society_members.start_date`.
- `people` je centralna tabela identiteta za sve osobe.
- Jedna osoba može biti član više društava kroz više redova u `society_members`.
- Roditelji/staratelji su takođe osobe u `people`.
- Roditelj/staratelj se ne upisuje u `society_members` samo zato što je staratelj.
- Veza dete-staratelj ide kroz `person_guardians`.
- U add-member toku za maloletnika koristi se `relationship = GUARDIAN`, `is_primary = true/false`.
- `people.email` je glavni praktični lookup identifikator kada postoji.
- Maloletni član može biti bez email-a i telefona.
- `society_members.funkcija` je legacy kolona i ne koristi se za novi model funkcija.
- Funkcije se vode kroz `society_member_functions` i `society_member_function_assignments`.
- Funkcije nisu globalne, već pripadaju društvu.
- Početne funkcije pri approval-u: `Predsednik`, `Sekretar`, `Blagajnik`, `Upravnik`, `UR`, `Korepetitor`, `Član`.
- `Predsednik` je zaštićena/system funkcija: mora postojati, ne briše se, ne deaktivira se i ne dodeljuje ručno kroz običan `UF_MEMBER_FORM`.
- `UR` znači `Umetnički rukovodilac`, ne `Upravnik`.
- `UR` kao sekcijsko pravo ne dolazi iz globalne funkcije, već iz `section_role_assignments`.
- Sekcije pripadaju društvu i nisu globalne.
- Početne sekcije pri approval-u: `Izvođački ansambl`, `Pripremni ansambl`, `Dečiji ansambl`, `Pevačka grupa`, `Orkestar`.
- `CLANOVI` služi za podatke osobe i člana.
- `UF_MEMBER_FORM` služi za podatke člana i izbor sekcija kojima član pripada.
- `MOJE SEKCIJE` služi za upravljanje sekcijama, UR-ovima, korepetitorima i pregled članova sekcije.
- Sekcije kao organizacione jedinice se ne uređuju kroz edit formu člana, ali se pripadnost člana sekcijama uređuje kroz `UF_MEMBER_FORM`.
- `member_sections` je trenutno stanje članstva u sekciji.
- `member_section_history` je istorija promena članstva u sekciji.
- Za istog člana i istu sekciju treba da postoji samo jedan `member_sections` red.
- Sekcije, članstva u sekcijama i sekcijske uloge se ne brišu fizički, već deaktiviraju.
- Sekcija može imati više UR-ova.
- Korepetitor je posebna sekcijska uloga.
- Promena predsednika ide kroz `president_change_requests`, ne kroz običnu izmenu člana.
- Jedno društvo može imati samo jednog aktivnog predsednika.
- Zahtevi za izmenu podataka i licence društva idu preko Master admin odobrenja.
- Master admin dashboard je sistemski dashboard i ne treba da prikazuje metrike jednog društva kao glavni sadržaj.
- Dokumentacija ima prednost pre implementacije; pre nove forme/tabele/workflow-a treba proveriti postojeća pravila.

### Section Assignment Rules

- `UF_MEMBER_FORM` ostaje centralna forma za člana.
- `UF_MEMBER_FORM` služi za unos člana, izmenu člana i izbor sekcija kojima član pripada.
- Sekcije se u `UF_MEMBER_FORM` prikazuju kao checkbox lista.
- Jedan član može pripadati jednoj ili više sekcija.
- Predsednik vidi sve sekcije društva, može čekirati bilo koju sekciju i može menjati pripadnost člana svim sekcijama.
- UR vidi samo sekcije u kojima je on UR, može čekirati samo te sekcije, ne vidi ostale sekcije društva i ne može menjati članstvo u sekcijama kojima nije UR.
- Izvor UR ograničenja je aktivan zapis u `section_role_assignments`.
- `MOJE SEKCIJE` ostaje glavni modul za upravljanje sekcijama, kreiranje/deaktivaciju sekcija, UR-ove, korepetitore i pregled članova sekcije.
- `UF_MEMBER_FORM` upravlja članom.
- `MOJE SEKCIJE` upravlja sekcijama.

## 6. Baza podataka i tabele

### PresidentReg

Svrha:
Registracioni zahtevi za društva.

Aktivno korišćenje:
Da. Koriste je registracija, liste zahteva i approval workflow.

Napomene:
Repo SQL postoji u `supabase/president-reg-setup.sql`. Dokumentacija kaže da treba proveriti usklađenost, posebno za `societyId`, jer ga kod koristi, a prikazani SQL fajl ne sadrži eksplicitno `societyId`.

RLS rizik:
Osnovni SQL dozvoljava anon insert, a DEV select/update politike su privremene.

### societies

Svrha:
Aktivna društva.

Aktivno korišćenje:
Da. Koriste je approval workflow, lista društava, detalj društva, članovi i sekcije.

Napomene:
Dokumentacija kaže da tabela postoji u aktivnoj bazi. U repo listi nije uočen poseban kompletan `societies` setup SQL fajl.

RLS rizik:
Finalne politike po Master admin/predsednik/društvo nisu dokumentovane kao završene.

### people

Svrha:
Centralni identitet svih osoba: članovi, roditelji/staratelji, predsednici i budući korisnici.

Aktivno korišćenje:
Da. Koriste je `CLANOVI` i `MOJE SEKCIJE`.

Napomene:
Repo SQL postoji, ali prikazani `people-setup.sql` ne sadrži sve unique/check constraint-e koje dokumentacija očekuje. Potrebno je usklađivanje.

RLS rizik:
Osetljivi podaci zahtevaju stroge politike; trenutno se to ne vidi kao finalno rešeno.

### society_members

Svrha:
Veza osobe i društva, status članstva, datum početka, članarina.

Aktivno korišćenje:
Da. Koristi se za članove, sekcije i sekcijske uloge.

Napomene:
`start_date` je u SQL-u nullable, ali poslovno pravilo kaže da je obavezan. `funkcija` je legacy kolona.

RLS rizik:
Finalni multi-society pristup nije uveden; trenutno više ekrana bira prvo aktivno društvo.

### member_status_history

Svrha:
Istorija ACTIVE/INACTIVE statusa članstva.

Aktivno korišćenje:
Da, pri dodavanju člana i pri promeni statusa člana.

Napomene:
Dokumentacija kaže da postoji u aktivnoj bazi. Nije uočljiv poseban repo SQL fajl u trenutnoj listi, što treba proveriti.

RLS rizik:
Istorija statusa je važna za finansije i jubileje; mora biti zaštićena po društvu.

### society_member_functions

Svrha:
Katalog funkcija po društvu.

Aktivno korišćenje:
Da. Approval kreira početne funkcije, `CLANOVI` ih učitava i dodeljuje.

Napomene:
Dokumentacija očekuje unique po `society_id + name`. Treba proveriti da li je constraint stvarno u bazi/repo-u.

RLS rizik:
Predsednik treba da upravlja funkcijama svog društva, ali finalne politike nisu uvedene.

### society_member_function_assignments

Svrha:
Dodela funkcija članovima.

Aktivno korišćenje:
Da. `CLANOVI` kreira i zamenjuje dodele funkcija.

Napomene:
Dokumentacija očekuje unique po `society_member_id + function_id`. Treba proveriti da li je constraint stvarno prisutan.

RLS rizik:
Zaštićena funkcija `Predsednik` ne sme se dodeljivati običnim tokom.

### user_onboarding_state

Svrha:
Praćenje onboardinga predsednika.

Aktivno korišćenje:
Delimično. Kod pokušava kreiranje pri approval-u samo ako postoji `presidentUserId`.

Napomene:
Pošto `presidentUserId` trenutno ostaje `null`, realan tok onboardinga nije zatvoren.

RLS rizik:
Treba povezati sa Supabase Auth korisnikom.

### sections

Svrha:
Sekcije/probne grupe unutar društva.

Aktivno korišćenje:
Da. Approval kreira početne sekcije, `MOJE SEKCIJE` upravlja njima, `CLANOVI` ih još delimično učitava.

Napomene:
Dokumentacija očekuje unique naziv po društvu.

RLS rizik:
Predsednik vidi sve sekcije svog društva; UR samo svoje. To trenutno nije finalno u RLS-u.

### member_sections

Svrha:
Trenutno stanje članstva člana u sekciji.

Aktivno korišćenje:
Da. `UF_MEMBER_FORM`/`CLANOVI` koriste ovu tabelu za izbor sekcija kojima član pripada. `MOJE SEKCIJE` koristi istu tabelu za pregled članova sekcije i rad sa trenutnim stanjem članstva u sekciji.

Napomene:
Repo SQL dopunjuje status i unique index. Treba proveriti aktivnu bazu.

RLS rizik:
Postoji DEV policy koja daje širok pristup anon/authenticated rolama.

### section_role_assignments

Svrha:
Sekcijske uloge `UR` i `KOREPETITOR`.

Aktivno korišćenje:
Da. `MOJE SEKCIJE` učitava i menja ovu tabelu.

Napomene:
Dokumentacija kaže da SQL migracija postoji u repo-u, ali ne potvrđuje da tabela postoji u aktivnoj bazi. Kod eksplicitno javlja grešku ako tabela nije dostupna.

RLS rizik:
Posebno važan rizik: trenutno postoji DEV policy sa širokim select/insert/update/delete pristupom. Finalna pravila moraju proveravati predsednika i UR prava po sekciji.

### member_section_history

Svrha:
Istorija dodavanja, deaktivacije i reaktivacije članstva u sekciji.

Aktivno korišćenje:
Da. `UF_MEMBER_FORM` treba da upisuje istoriju pri promeni pripadnosti člana sekcijama, a `MOJE SEKCIJE` koristi istoriju za pregled i sekcijske tokove.

Napomene:
Dokumentacija kaže da SQL migracija postoji u repo-u, ali ne potvrđuje da tabela postoji u aktivnoj bazi.

RLS rizik:
Postoji DEV policy sa širokim pristupom.

### person_guardians

Svrha:
Veza maloletnog deteta i roditelja/staratelja.

Aktivno korišćenje:
Da. `CLANOVI` kreira/koristi veze, `MOJE SEKCIJE` prikazuje kontakte staratelja za članove sekcije.

Napomene:
Dokumentacija kaže da tabela postoji u aktivnoj bazi. U repo listi nije uočen poseban setup SQL fajl.

RLS rizik:
UR sme da vidi samo osnovne kontakte staratelja za maloletnike u svojim sekcijama, ne osetljive podatke.

### society_change_requests

Svrha:
Planirani zahtevi za izmenu podataka društva i licence.

Aktivno korišćenje:
Ne. Planirano.

### member_data_change_requests

Svrha:
Planirani zahtevi za izmenu podataka člana kada korisnik nema pravo direktne izmene.

Aktivno korišćenje:
Ne. Planirano.

### president_change_requests

Svrha:
Planirani zahtevi za promenu predsednika.

Aktivno korišćenje:
Ne kao implementiran workflow. Tip postoji u `supabaseClient.ts`, ali dokumentacija status označava kao planiran.

## 7. Poznati problemi i rizici

- `section_role_assignments` je ključan za UR prava, ali tabela je u dokumentaciji označena kao repo SQL/migration, ne kao potvrđena aktivna tabela. Kod zavisi od nje u `MOJE SEKCIJE`.
- DEV RLS politike za `section_role_assignments` daju širok pristup i moraju se ukloniti/zameniti finalnim pravilima.
- DEV RLS politike za `member_sections` i `member_section_history` takođe daju širok pristup.
- DEV politike za `PresidentReg` select/update su privremene dok Master admin nije povezan sa Supabase Auth.
- Approval workflow nije transakcijski; moguće je delimično kreirano društvo bez svih pratećih update-a.
- `PresidentReg.presidentUserId` je trenutno `null`, pa `user_onboarding_state` uglavnom neće biti kreiran pri approval-u.
- Supabase Auth nije kompletno uveden.
- Test role/localStorage nisu bezbednosni model.
- Više funkcionalnosti koristi prvo aktivno društvo, što nije finalni multi-society princip.
- `society_members.funkcija` postoji kao legacy kolona; novi sistem koristi `society_member_function_assignments`. Potrebna je pažljiva migracija/provera pre uklanjanja.
- `UF_MEMBER_FORM` sadrži sekcije i `selectedSectionIds`; to je sada potvrđena arhitektura, ali treba proveriti da li su filtriranje i prava izmene usklađeni sa pravilima za Predsednika i UR-a.
- `CLANOVI` ima kod za `member_sections`; potrebno je proveriti da li Predsednik vidi sve sekcije, a UR samo sekcije u kojima je UR.
- `member_section_history` se upisuje iz `MOJE SEKCIJE`, ali nije jasno da li je tabela primenjena u aktivnoj bazi.
- Nisu svi očekivani unique/check constraint-i vidljivi u repo SQL fajlovima.
- `people-setup.sql` i `society-members-setup.sql` deluju minimalno u odnosu na dokumentovana pravila.
- Nije uočen kompletan repo SQL za sve tabele koje dokumentacija navodi kao postojeće u aktivnoj bazi.
- Osetljivi podaci članova još nisu finalno zaštićeni kroz realne dozvole i RLS.
- UR vidljivost i izmena su simulirane u frontend logici, ne garantovane bazom.
- Potencijalni mojibake karakteri postoje u kodu/dokumentaciji i mogu kvariti UI tekstove.
- Password/hash u `PresidentReg` je privremen i treba ga zameniti pravim Supabase Auth tokom.
- `getLicensePrice` je privremeno u `SocietyDataForm`.
- Liste zahteva imaju duplirane fetch obrasce.

## 8. Predlog sledećih koraka

Napomena za trenutnu DEV/V1 fazu (odluka 2026-07-15): stavke u nastavku ostaju arhitektonski i tehnički backlog, ali nisu preduslov za nastavak razvoja postojećih tokova članova i sekcija. Pre nastavka je obavezno samo dokumentaciono usklađivanje trenutnog stanja i jasno evidentiranje privremenih ograničenja. Auth, finalni RLS, stvarni multi-society kontekst, UR filtriranje, RPC approval i kompletno usklađivanje SQL migracija rade se u narednoj arhitektonskoj fazi.

### 1. Uskladiti dokumentaciju statusa sa stvarnim kodom

Zašto je važno:
`PROJECT_STATUS.md` kaže da je `MOJE SEKCIJE` sledeći zadatak, ali kod već ima značajnu implementaciju. Tim mora imati tačnu mapu stanja pre naredne implementacije.

Šta proveriti/uraditi:
Pregledati `CLANOVI`, `MOJE SEKCIJE`, `UF_MEMBER_FORM` i ažurirati status dokumentaciju nakon Bojanove potvrde.

Verovatni fajlovi/tabele:
- `docs/PROJECT_STATUS.md`
- `app/(application)/clanovi/page.tsx`
- `app/(application)/moje-sekcije/page.tsx`
- `app/_components/UF_MEMBER_FORM.tsx`

Tip zadatka:
Dokumentacija / analiza.

### 2. Proveriti aktivnu Supabase bazu naspram repo SQL fajlova

Zašto je važno:
Dokumentacija kaže da je aktivna baza izvor istine, ali repo migracije nisu kompletno usklađene.

Šta proveriti/uraditi:
Napraviti inventar tabela, kolona, constraint-a, index-a i RLS politika iz aktivne baze, pa ga uporediti sa `supabase` folderom.

Verovatni fajlovi/tabele:
- ceo `supabase` folder
- sve tabele iz `DATABASE_SCHEMA.md`

Tip zadatka:
Baza / analiza.

### 3. Uskladiti implementaciju `UF_MEMBER_FORM` sa Section Assignment Rules

Zašto je važno:
Nova dokumentacija potvrđuje da `UF_MEMBER_FORM` upravlja pripadnošću člana sekcijama. Sledeći razvoj treba da proveri da li UI i baza poštuju pravila za Predsednika i UR-a.

Šta proveriti/uraditi:
Proveriti da Predsednik u `UF_MEMBER_FORM` vidi i može menjati sve sekcije društva, a UR vidi i može menjati samo sekcije u kojima ima aktivnu `section_role_assignments` dodelu. Proveriti da promene kreiraju/reaktiviraju/deaktiviraju `member_sections` i upisuju `member_section_history`.

Verovatni fajlovi/tabele:
- `app/_components/UF_MEMBER_FORM.tsx`
- `app/(application)/clanovi/page.tsx`
- `member_sections`
- `member_section_history`

Tip zadatka:
Analiza, zatim implementacija.

### 4. Potvrditi i primeniti `section_role_assignments` i `member_section_history` u aktivnoj bazi

Zašto je važno:
`MOJE SEKCIJE` zavisi od ovih tabela. Bez njih modul puca ili ostaje neupotrebljiv.

Šta proveriti/uraditi:
Proveriti da li tabele, constraint-i, index-i i privremene DEV politike postoje u aktivnoj bazi. Ako ne postoje, pripremiti kontrolisanu primenu SQL-a tek nakon potvrde.

Verovatni fajlovi/tabele:
- `supabase/section-role-assignments-setup.sql`
- `supabase/member-section-history-setup.sql`
- `section_role_assignments`
- `member_section_history`

Tip zadatka:
Baza.

### 5. Projektovati finalni Supabase Auth i role/RLS model

Zašto je važno:
Trenutni sistem nije bezbednosno zatvoren. Test role i DEV anon politike nisu prihvatljive za produkciju.

Šta proveriti/uraditi:
Definisati kako se korisnik povezuje sa `people`, `society_members`, predsednikom, Master adminom i sekcijskim ulogama. Zatim projektovati RLS po tabelama.

Verovatni fajlovi/tabele:
- `people.user_id`
- `society_members.user_id`
- `user_onboarding_state`
- `section_role_assignments`
- sve DEV policy SQL datoteke

Tip zadatka:
Arhitektura / baza.

### 6. Završiti prvi login i onboarding predsednika

Zašto je važno:
Dokumentovano pravilo kaže da predsednik postaje član tek kroz onboarding. Trenutno taj tok nije zatvoren.

Šta proveriti/uraditi:
Definisati Auth registraciju/login, popunjavanje `presidentUserId`, kreiranje `user_onboarding_state` i pozivanje `UF_MEMBER_FORM` u `president_onboarding` režimu.

Verovatni fajlovi/tabele:
- `PresidentReg`
- `user_onboarding_state`
- `people`
- `society_members`
- `member_status_history`
- `society_member_function_assignments`
- `UF_MEMBER_FORM`

Tip zadatka:
Arhitektura, baza, implementacija.

### 7. Prebaciti approval workflow u transakciju/RPC

Zašto je važno:
Approval trenutno radi više odvojenih client-side koraka. Ako jedan korak padne, baza može ostati u poluzavršenom stanju.

Šta proveriti/uraditi:
Projektovati Supabase RPC ili server-side tok koji atomarno kreira društvo, početne funkcije, početne sekcije, onboarding state i ažurira `PresidentReg`.

Verovatni fajlovi/tabele:
- `app/(application)/zahtevi-na-cekanju/[id]/page.tsx`
- `PresidentReg`
- `societies`
- `society_member_functions`
- `sections`
- `user_onboarding_state`

Tip zadatka:
Baza / implementacija.

### 8. Uvesti realni multi-society kontekst

Zašto je važno:
Trenutno `CLANOVI` i `MOJE SEKCIJE` biraju prvo aktivno društvo, što nije ispravno za korisnike koji pripadaju konkretnom društvu ili više društava.

Šta proveriti/uraditi:
Definisati kako se bira trenutno društvo za korisnika i kako se filtriraju podaci.

Verovatni fajlovi/tabele:
- `society_members`
- `people`
- `user_onboarding_state`
- `AppShell`
- `clanovi/page.tsx`
- `moje-sekcije/page.tsx`

Tip zadatka:
Arhitektura / implementacija.

### 9. Očistiti DEV politike pre produkcije

Zašto je važno:
Anon/authenticated wide-open politike su ozbiljan bezbednosni rizik.

Šta proveriti/uraditi:
Popisati sve DEV politike, označiti šta se briše, i napisati finalna pravila.

Verovatni fajlovi/tabele:
- `supabase/*dev*policy.sql`
- `PresidentReg`
- `member_sections`
- `member_section_history`
- `section_role_assignments`

Tip zadatka:
Baza / bezbednost.

### 10. Popraviti mojibake/encoding tekstove

Zašto je važno:
UI i dokumentacija na srpskom moraju prikazivati ispravne karaktere.

Šta proveriti/uraditi:
Proveriti da li je problem samo terminal prikaz ili stvarni sadržaj fajlova. Ako je stvarni sadržaj, očistiti tekstove kontrolisano.

Verovatni fajlovi/tabele:
- `app/**/*.tsx`
- `docs/**/*.md`

Tip zadatka:
Analiza, zatim dokumentacija/implementacija.

## 9. Pitanja za Bojana pre nastavka

1. Da li trenutno stanje `MOJE SEKCIJE` treba smatrati implementiranim V1 modulom ili samo prototipom koji još treba arhitektonski potvrditi?
2. Da li `UF_MEMBER_FORM` treba odmah da prikazuje sekcije u svim režimima (`create`, `edit`, `president_onboarding`) ili samo u `create`/`edit` režimu za obične članove?
3. Da li je aktivna Supabase baza i dalje jedini izvor istine za postojeće tabele, ili sada repo SQL treba proglasiti izvorom istine?
4. Da li su `section_role_assignments` i `member_section_history` već primenjene u aktivnoj Supabase bazi?
5. Da li treba prvo rešavati Auth/onboarding predsednika ili prvo završiti/očistiti članove i sekcije u DEV režimu?
6. Kako Bojan želi da se kreira predsednikov Supabase Auth nalog: tokom registracije društva, tokom approval-a ili pri prvom login/onboarding toku?
7. Da li `PresidentReg` treba i dalje da čuva password hash, ili to treba ukloniti čim se uvede Supabase Auth?
8. Da li predsednik u V1 može direktno uređivati funkcije društva ili se to odlaže?
9. Da li Master admin direktna izmena društva kroz `/drustva/[id]` ostaje trajni master tok?
10. Koje module treba tretirati kao van opsega za sledeću fazu: finansije, prisustvo, garderoba, koncerti, izveštaji?
11. Da li se `society_members.funkcija` samo ignoriše, ili treba planirati formalnu migraciju i kasnije uklanjanje?
12. Da li treba prvo napraviti SQL inventory dokument pre bilo kakve nove implementacije?
# Napomena o aktuelnom stanju — 27.07.2026.

Ovaj dokument sadrži istorijski pregled DEV faze i ne predstavlja više tačan
opis aktivnog identiteta i autorizacije. Aplikacija koristi Supabase Auth V1,
centralni aplikacioni kontekst i kontrolisane RPC tokove. Završno uklanjanje
širokih DEV politika pripremljeno je u
`supabase/auth-v1-final-dev-cleanup.sql`. Istorijske navode o test ulogama,
`localStorage` identitetu i izboru prvog aktivnog društva ne koristiti kao
uputstvo za novi kod.
