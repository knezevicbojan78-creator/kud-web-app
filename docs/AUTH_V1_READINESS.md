# SUPABASE AUTH V1 — PRIPREMA I PRELAZAK

## 1. Trenutna odluka

Projekat je još u DEV režimu i koristi test uloge iz browser `localStorage` vrednosti. Novi sistem dozvola koristi stvarne funkcije i dodele iz baze, zbog čega je dijagnostika kontrolisanih workflow-a vratila `president_actor_count = 0`.

Ovaj rezultat trenutno nije greška sistema dozvola. Pokazuje da simulirana DEV uloga `Predsednik` nije isto što i stvarna dodela funkcije aktivnom članu u bazi.

Ne uvodi se novi dev adapter za dozvole jer se projekat uskoro prebacuje na Supabase Auth. Osnovni sistem dozvola ostaje zasnovan na stvarnom identitetu, članstvu i funkcijama.

DEV politike i postojeći testni pristup još se ne uklanjaju, jer bi trenutna aplikacija prestala da radi pre završetka Auth prelaska.

## 1a. Potvrđeni Auth V1 tok — 2026-07-26

### Početno pokretanje i Master admin

Dok ne postoji aktivni Master admin:

* prijava postojećeg korisnika ostaje dostupna
* registracija nudi samo opciju `Master admin`
* registracije predsednika, člana i roditelja/staratelja nisu dostupne

Jedini dozvoljeni Master admin email je `knezevic.bojan78@gmail.com`.
Korisnik pri prvoj registraciji unosi samo taj email i željenu lozinku.
Lozinku čuva isključivo Supabase Auth i ona se ne upisuje ni u jednu `public` tabelu.

Master admin postaje aktivan tek kada:

1. potvrdi email preko Supabase aktivacionog linka
2. uspešno se prijavi
3. podesi i potvrdi obavezni TOTP drugi faktor
4. dobije poseban platformski zapis povezan sa svojim `auth.users.id`

Baza mora garantovati da postoji samo jedan Master admin i da njegov Auth identitet ne može biti povezan sa `people`, `society_members`, funkcijom društva ili roditeljskom vezom. Za članstvo u sopstvenom KUD-u ista fizička osoba koristi drugi email i drugi Auth nalog.

Nakon aktiviranja Master admina nestaje mogućnost njegove registracije, a postaju dostupne registracije:

* `Predsednik društva`
* `Član društva`
* `Roditelj/staratelj`

### Registracija i prvi onboarding predsednika

Početni zahtev predsednika sadrži samo:

* naziv društva
* adresu
* grad
* državu
* PIB
* matični broj
* ime i prezime predsednika
* email predsednika
* telefon predsednika
* željeni aktivni licencni paket

Početni zahtev ne traži sve podatke društva i predsednika i ne čuva lozinku.

Master admin odobrava ili odbija zahtev. Zahtevani paket je predlog koji Master
admin vidi; pri odobravanju mora da ga potvrdi ili, uz dogovor, izabere drugi
paket. Dodela licence ostaje isključivo Master admin radnja.
Odobravanje:

1. kreira početni zapis društva
2. povezuje zahtev sa društvom
3. dodeljuje izabrani paket/licencu u stanju čekanja aktivacije
4. šalje aktivacioni link novom Auth korisniku ili obaveštenje postojećem korisniku

Ako email još nema Auth nalog, predsednik preko aktivacionog linka postavlja željenu lozinku. Ako Auth nalog već postoji, ne kreira se novi nalog i korisnik zadržava postojeću lozinku.

Prvi ulazak predsednika vodi isključivo u obavezni onboarding:

* podaci društva dopunjavaju se kroz postojeći `SocietyDataForm`
* podaci predsednika dopunjavaju se kroz postojeći `UF_MEMBER_FORM` u režimu `president_onboarding`
* ne prave se paralelne forme
* PIB, matični broj i Auth email su unapred popunjeni i zaključani
* ostali prethodno uneti podaci mogu se dopuniti ili ispraviti
* napredak se čuva i onboarding može da se nastavi nakon prekida

Dok onboarding nije završen, društvo nije operativno i licencni period ne teče.
Uspešna završna radnja atomski:

1. završava podatke društva
2. povezuje ili kreira odgovarajući `people` zapis
3. povezuje `auth.uid()` sa osobom i članstvom
4. kreira ili aktivira članstvo predsednika
5. dodeljuje funkciju `Predsednik`
6. označava onboarding završenim
7. aktivira društvo
8. aktivira licencni period i tek tada računa njegov početak i istek

### Registracija člana i roditelja/staratelja

Član ili roditelj/staratelj ne može kroz javnu registraciju napraviti novu osobu.
Predsednik mora prethodno uneti najmanje osnovne podatke i email u `people`.

Za člana dodatno mora postojati članstvo u `society_members`.
Za roditelja/staratelja mora postojati veza sa detetom u `person_guardians`; roditelj ne mora biti član društva.

Nakon unosa emaila:

* ekran ne otkriva javno da li email postoji
* podoban novi korisnik dobija aktivacioni link i postavlja lozinku
* postojeći Auth korisnik ne pravi novi nalog niti novu lozinku
* jedan `people` zapis povezuje se sa jednim Auth identitetom
* ista osoba koristi isti nalog u svim društvima i za sve svoje članske i roditeljske veze

Uspešan login sam po sebi ne potvrđuje novu vezu. Korisnik eksplicitno potvrđuje ili odbija:

* svako novo članstvo
* svaku novu roditeljsku/starateljsku vezu

Dok članstvo nije potvrđeno, novo društvo nije aktivan korisnički kontekst i osetljivi podaci postojećeg `people` zapisa ne učitavaju se novom društvu samo na osnovu pogođenog emaila.

Prazna polja korisnik može dopuniti kroz postojeći `UF_MEMBER_FORM`. Izmena već popunjenih podataka koristi dokumentovani zahtev predsedniku. Auth email je zaključan u običnoj profilnoj formi.

### Roditeljska prava

Veza roditelj–dete potvrđuje se jednom na nivou globalnih `people` identiteta. Dostupna društva roditelja izvode se iz aktivnih članstava deteta.

* više dece u istom društvu daje jedan kontekst društva
* deca u više društava daju više dozvoljenih konteksta
* roditelj koji je istovremeno član koristi isti nalog, a prava se sabiraju
* roditeljska prava važe samo uz potvrđenu vezu i aktivno članstvo deteta u izabranom društvu

Roditeljska prava automatski prestaju kada dete napuni 18 godina. Istorijska veza ostaje sačuvana.
Punoletni član može roditelju ponovo dozvoliti ista prava koja je roditelj imao dok je član bio maloletan. Ova dozvola:

* daje se pojedinačnom roditelju
* važi posebno za izabrano društvo
* može se deaktivirati u bilo kom trenutku
* deluje odmah i ostavlja audit

Ne uvode se dodatne grupe roditeljskih prava u Auth V1.

### Korisnički kontekst društva

Nakon logina sistem izračunava dostupna društva iz potvrđenih aktivnih članstava i potvrđenih roditeljskih prava.

* korisnik sa jednim društvom ulazi direktno u njega
* korisnik sa više društava dobija izbor na Dashboardu i u zaglavlju aplikacije
* pamti se poslednje korišćeno društvo samo kao korisničko podešavanje
* svaka promena društva ponovo učitava funkcije, dozvole i opsege
* isto društvo prikazuje se samo jednom i kada korisnik u njemu ima više osnova pristupa
* suspendovano društvo ostaje vidljivo u `read-only` režimu

Zapamćeni ili prosleđeni `society_id` nije dokaz ovlašćenja. Svaki kontrolisani poziv mora proveriti `auth.uid()`, vezu sa izabranim društvom, status društva, funkcije, efektivne dozvole i opseg radnje.

### Granice Auth V1

Auth V1 obuhvata:

* login, logout i reset zaboravljene lozinke
* početno aktiviranje jedinog Master admina
* obavezni TOTP za Master admina
* predsednički zahtev, odobravanje, licencu i onboarding
* aktiviranje unapred evidentiranog člana ili roditelja
* potvrdu članskih i roditeljskih veza
* jedan nalog po osobi i izbor društva
* centralni Auth kontekst i osnovnu RLS/RPC zaštitu

Pre puštanja stvarnih korisnika potrebno je zameniti podrazumevani Supabase
email servis sopstvenim SMTP servisom i verifikovanim domenom. Pošiljalac se
prikazuje kao `Folkloraš`, a potvrda emaila, aktivacija naloga, poziv,
reset lozinke i bezbednosna obaveštenja koriste brendirane šablone na srpskom.
Aktivacioni email predsednika može da prikaže naziv društva iz kontrolisanih
podataka zahteva, ali društvo ne menja platformski identitet pošiljaoca.

Za kasniju fazu ostaju promena Auth emaila kroz aplikaciju, napredno upravljanje sesijama, korisničko brisanje naloga, rezervni MFA uređaji za ostale korisnike i dodatne administrativne opcije koje nisu potrebne za prvi produkcioni login.

## 2. Obavezne provere pre Auth prelaska

### Društvo i predsednik

* svako aktivno društvo ima tačno jednu aktivnu sistemsku funkciju `Predsednik`
* svako aktivno društvo ima aktivnog člana kome je dodeljena funkcija `Predsednik`
* predsednik pripada istom društvu kao dodeljena funkcija
* nije moguće ukloniti poslednjeg aktivnog predsednika
* postoji kontrolisan postupak zamene predsednika

### Identitet korisnika

* `people.user_id` povezuje osobu sa Supabase Auth korisnikom
* `society_members.user_id` koristi isti Auth identitet kada član ima nalog
* veza `auth.users.id` → `people.user_id` → `society_members` mora biti jednoznačna
* nema duplih nepraznih `people.user_id`
* nema duplih nepraznih `society_members.user_id` u nedozvoljenom kontekstu
* nema konfliktnih ili duplih email adresa
* jedan korisnik može imati članstvo u više društava bez dupliranja osobe

### Roditelji i staratelji

* roditelj koji dobije nalog koristi postojeći `people` zapis
* Auth korisnik roditelja povezuje se preko `people.user_id`
* prava za decu izvode se samo iz važećih `person_guardians` veza
* roditelj ne mora biti član društva da bi video svoju decu

### Kontekst društva

* društvo se više ne bira kao prvo aktivno društvo iz baze
* kontekst dolazi iz prijavljenog korisnika i njegovih članstava
* korisnik sa jednim društvom ulazi direktno u njega
* korisnik sa više društava bira društvo iz liste kojoj stvarno pripada
* promena društva ponovo računa funkcije, dozvole i opsege
* korisnik ne može proslediti proizvoljan `society_id`

### Master admin

* Master admin identitet je odvojen od funkcija članova društva
* Master admin nema pristup pojedinačnim članovima i sekcijama društva
* Master admin koristi posebnu proveru sistemske uloge
* uklanjaju se `master@dev.local` i drugi razvojni identiteti

### Dozvole

* prava se računaju iz stvarnih aktivnih funkcija
* prava više funkcija se sabiraju
* član i roditelj zadržavaju svoja zaključana prava
* `ALLOW` i `DENY` rade samo u dozvoljenim granicama
* samo stvarni predsednik koristi podešavanja dozvola
* `actor_member_id` mora pripadati prijavljenom `auth.uid()`
* klijent ne može birati funkciju ili identitet izvršioca

### RLS i kontrolisani workflow-i

* popisati sve DEV politike koje daju širok pristup `anon` ili `authenticated`
* popisati sve RPC funkcije sa privremenim `anon` execute pravom
* postojeće direktne provere naziva funkcije zameniti centralnim dozvolama
* finalne RLS politike i RPC funkcije moraju koristiti isti korisnički kontekst
* direktan pristup tabeli mora biti odbijen i kada korisnik zaobiđe interfejs
* DEV politike uklanjaju se tek kada je odgovarajući finalni tok proveren

### Suspenzija i automatski poslovi

* suspendovano društvo ostaje `read-only` bez obzira na prava korisnika
* automatski mesečni obračuni i tehnički poslovi nastavljaju da rade
* sistemske radnje se u auditu razlikuju od korisničkih radnji
* servisni procesi ne zavise od aktivne korisničke sesije

## 3. Redosled prelaska

1. Napraviti read-only Auth readiness dijagnostiku.
2. Proveriti stvarne podatke i izdvojiti konflikte bez izmene baze.
3. Definisati Auth identitet, login i korisnički kontekst društva.
4. Definisati onboarding i povezivanje postojećih `people` zapisa.
5. Povezati predsednika i ostale korisnike sa Auth identitetima.
6. Omogućiti siguran `authenticated` pristup centralnim dozvolama.
7. Prebacivati module na finalne dozvole i RLS jedan po jedan.
8. Testirati direktne nedozvoljene pozive.
9. Ukloniti test uloge, DEV fallback funkcije, široke politike i `anon` grantove.
10. Izvršiti završnu V1 bezbednosnu proveru.

## 4. Pravilo prelaska

DEV pristup se ne uklanja odjednom unapred. Za svaki modul prvo se:

1. uvede stvarni Auth kontekst
2. uvede finalna dozvola i RLS/RPC zaštita
3. proveri dozvoljeni i zabranjeni tok
4. tek tada ukloni odgovarajući DEV pristup

Na taj način aplikacija ostaje funkcionalna tokom prelaska, a nijedan modul ne ostaje između dva modela autorizacije.

## 5. Tačno mesto nastavka

Potvrđeni Auth V1 model zapisan je u ovom dokumentu 2026-07-26.
Read-only SQL dijagnostika za Auth spremnost pripremljena je u:

* `supabase/auth-v1-readiness-diagnostic.sql`

Read-only dijagnostika uspešno je pokrenuta u aktivnoj Supabase bazi 2026-07-26 nakon brisanja testnih podataka.

Potvrđeni zbirni rezultat:

* `auth_user_count = 0`
* `society_count = 0`
* `people_count = 0`
* `society_member_count = 0`
* `duplicate_people_email_count = 0`
* `duplicate_auth_email_count = 0`
* `people_auth_conflict_count = 0`
* `member_auth_mismatch_count = 0`
* `public_anon_authenticated_policy_count = 49`
* `public_rpc_with_public_execute_count = 58`

Nema postojećih identiteta ili poslovnih podataka koje treba migrirati pre prvog Auth korisnika. Brojevi politika i RPC funkcija predstavljaju očekivani inventar postojećeg DEV pristupa, ne grešku dijagnostike. Ne uklanjaju se odjednom unapred.

SQL osnova i frontend prvog Master admin bootstrap toka pripremljeni su lokalno 2026-07-26:

* `supabase/auth-v1-master-admin-foundation.sql`
* `supabase/auth-v1-master-admin-foundation-diagnostic.sql`
* login bez DEV izbora uloge
* email aktivacioni callback
* reset zaboravljene lozinke
* obavezni TOTP enrollment/challenge
* atomska aktivacija jedinog Master admina tek na `aal2`
* Auth provera aplikacionog layouta i stvarna odjava

Frontend `typecheck` i produkcioni build prolaze.

Pre prvog Master admin naloga potrebno je:

1. primeniti `auth-v1-master-admin-foundation.sql`
2. u Supabase Auth podešavanjima potvrditi da je uključena potvrda emaila
3. dodati lokalni i budući produkcioni `/auth/callback` u dozvoljene redirect URL-ove
4. u `Authentication → Hooks → Before User Created` izabrati SQL funkciju `public.auth_before_user_created`
5. pokrenuti read-only foundation dijagnostiku
6. tek zatim kroz aplikaciju registrovati `knezevic.bojan78@gmail.com`

Postojeći finansijski i drugi DEV RPC grantovi još nisu uklonjeni. Za osam Master admin RPC funkcija lokalno je pripremljena migracija `auth-v1-master-admin-rpc-protection.sql`, koja zahteva `auth_is_master_admin()`/`aal2`, uklanja `anon` izvršavanje i identitet audit izvršioca uzima isključivo iz Auth sesije. Migracija još mora biti primenjena i proverena u aktivnoj bazi.

Master admin bootstrap je funkcionalno potvrđen u aktivnoj bazi 2026-07-26:

* email registracija i potvrda uspešne
* TOTP enrollment i `aal2` challenge uspešni
* Dashboard otvoren kroz stvarnu Auth sesiju
* `platform_admin_count = 1`
* `auth_user_count = 1`
* `invalid_platform_admin_count = 0`
* `master_society_identity_conflict_count = 0`

Sledeći zadatak je primena `auth-v1-master-admin-rpc-protection.sql` i provera rezultata pomoću prateće dijagnostike. Nakon toga se registracija predsednika, člana i roditelja uvodi po potvrđenom redosledu. Ekran dozvola i novi dev adapter se do tada ne rade.
# Aktuelna napomena — 27.07.2026.

Auth V1 prelazak je implementiran. Navodi ispod koji opisuju test uloge,
browser `localStorage`, `master@dev.local` ili izbor prvog aktivnog društva
predstavljaju istorijsko stanje pre migracije. Završni korak je primena i
provera `supabase/auth-v1-final-dev-cleanup.sql`.
