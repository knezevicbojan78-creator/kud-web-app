# Auth V1 — detaljna primopredaja 27.07.2026.

## Sažetak

Prelazak postojećih funkcionalnih modula aplikacije Folkloraš iz privremenog
DEV pristupa u Auth V1 bezbednosni model završen je 27.07.2026.

Aplikacija više ne bira proizvoljno prvo društvo, ne veruje ulozi ili
identifikatoru izvršioca koje pošalje browser i nema direktne `.from(...)`
pristupe Supabase tabelama u aplikacionom kodu. Identitet, društvo, članstvo,
funkcije i dozvole određuju se na serverskoj strani prema aktivnoj Supabase Auth
sesiji.

Završna provera aktivne baze vratila je:

| Provera | Rezultat |
|---|---:|
| Preostale DEV politike | 0 |
| Direktna `anon` prava nad poslovnim tabelama | 0 |
| Neočekivane anonimno dostupne funkcije | 0 |
| Namerni javni anonimni tokovi | 3 |

Tri namerna anonimna toka su:

1. provera da li je platformski Master admin već aktiviran
2. javni pregled aktivnih licencnih paketa
3. slanje zahteva za registraciju predsednika društva

Upis Master admin zapisa nije anoniman: zahteva potvrđenu Auth sesiju i završava
se tek sa obaveznim MFA nivoom `aal2`.

## Potvrđeni Auth tokovi

### Master admin

* Postoji samo jedan platformski Master admin.
* Master admin nije član nijednog društva i nema red u `people` ili
  `society_members`.
* Registracija traži samo dozvoljeni email i željenu lozinku.
* Email mora biti potvrđen.
* TOTP dvofaktorska autentifikacija je obavezna.
* Bootstrap se završava atomski tek sa `aal2`.
* Posle prvog Master admina više se ne nudi početna Master admin registracija.
* Master admin pregled i izmene zahtevaju stvarni Master admin identitet i MFA.

### Predsednik društva

* Predsednik javno šalje samo osnovne podatke društva i predsednika.
* Pri zahtevu bira željeni paket i mesečni ili godišnji obračun.
* Master admin pri odobravanju obavezno potvrđuje ili menja licencu.
* Društvo i licenca ostaju u onboarding stanju do završetka predsedničkog
  onboardinga.
* Predsednik aktivacionim linkom postavlja željenu lozinku.
* Onboarding koristi postojeće `SocietyDataForm` i `UF_MEMBER_FORM`.
* Tek konačna potvrda kreira/povezuje osobu, članstvo i funkciju predsednika i
  aktivira društvo i licencu.

### Član i roditelj/staratelj

Dogovorena V1 logika ostaje:

* nalog se može aktivirati samo ako je osoba prethodno evidentirana
* član potvrđuje svako novo članstvo pre učitavanja osetljivih podataka
* korisnik sa više društava dobija izbor društva
* roditelj/staratelj dobija isti osnovni opseg kao kod maloletnog člana
* punoletni član može dozvoliti i kasnije ukinuti roditeljski pristup

Kompletan javni UI za samostalnu aktivaciju člana i roditelja ostaje naredna
funkcionalna etapa; bezbednosna pravila i model su dokumentovani.

## Dozvole

Implementiran je centralni sistem dozvola:

* početna prava po funkcijama
* sabiranje prava korisnika sa više funkcija
* zaključana predsednička prava
* pojedinačni izuzeci `INHERIT`, `ALLOW` i `DENY`
* opsezi kao što su celo društvo, dodeljene sekcije, sopstveni podaci i deca
* audit promena

Predsednik u `Podešavanja → Dozvole` može da menja pravila funkcije i
pojedinačne izuzetke. U interfejsu se prikazuje konačno efektivno pravo.

Funkcionalno je potvrđeno:

* davanje dozvole
* ukidanje dozvole
* učitavanje podešavanja
* učitavanje članova za pojedinačne izuzetke
* zaključana/nasleđena prava predsednika

## Članovi

Završeno je:

* zaštićeni pregled članova aktivnog društva
* učitavanje detalja člana prema efektivnim dozvolama
* odvojena osnovna, osetljiva, statusna, roditeljska, funkcijska i sekcijska
  prava
* kontrolisano kreiranje i izmena člana
* kontrolisana dodela funkcija i sekcija
* predsednik je pravilno evidentiran i prikazan kao član društva
* zaštićena provera postojeće osobe po emailu, JMBG-u i broju pasoša
* provera da li je postojeća osoba već član aktivnog društva

Stranica `Članovi` više nema direktno čitanje tabela. Glavni servisi su:

* `auth_get_members_page()`
* `auth_get_member_detail(uuid)`
* `auth_create_society_member(...)`
* `auth_update_society_member(...)`
* `auth_lookup_person_for_member(uuid,text,text,text)`

## Sekcije

Završeno je:

* pregled samo dozvoljenih sekcija
* kreiranje, izmena i promena statusa sekcije
* podešavanje trajanja probe
* dodavanje i uklanjanje člana iz sekcije
* dodela umetničkog rukovodioca i korepetitora
* upravljanje pravom umetničkog rukovodioca nad repertoarom
* dodavanje i deaktiviranje repertoarske numere
* zaštićeno učitavanje članova, roditeljskih kontakata i repertoara sekcije

Stranica `Moje sekcije` više nema direktno čitanje tabela. Glavni servisi su:

* `auth_get_sections_workspace(uuid)`
* `auth_get_section_detail(uuid)`
* `auth_manage_section(text,jsonb)`

## Prisustvo

DEV funkcije koje su verovale ulozi i ID-u izvršioca iz browsera zamenjene su
Auth V1 tokovima.

Potvrđeno je:

* učitavanje dozvoljenih sekcija
* otvaranje probe
* evidencija prisustva
* zatvaranje i otkazivanje probe
* pregled istorije
* uređivanje dozvoljene završene evidencije
* anonimni izvršilac nema pristup

## Događaji

Potvrđeni su Auth V1 tokovi za:

* pregled događaja
* kreiranje i izmenu
* slanje na odobrenje, odobravanje, odbijanje i otkazivanje
* sekcije događaja
* učesnike i njihove statuse
* termine nastupa
* program i repertoar
* kontrolisano otkazivanje sekcije događaja

Stare funkcije koje su primale tekstualnu ulogu i actor ID iz browsera više
nisu javno izvršive.

## Finansije

Završena je serverska provera finansijskog opsega prema stvarnom članu i
dozvolama.

Potvrđeno je:

* finansijski workspace
* pretraga člana ili roditelja
* finansijski profil
* evidentiranje delimične i pune uplate
* korišćenje kredita
* poništavanje uplate
* podešavanje standardne članarine
* kalendar meseci naplate
* pojedinačni režimi `STANDARD`, `CUSTOM` i `EXEMPT`
* formiranje članarine
* povraćaj novca
* poništavanje povraćaja

Za sve javne finansijske tokove potvrđeno je:

* `authenticated = true`
* `anon = false`
* interne funkcije za generisanje brojeva i obračune nisu direktno dostupne

U završnom čišćenju uklonjena su sva preostala direktna `anon` prava nad:

* finansijskim obavezama, uplatama, povraćajima i kreditima
* finansijskim auditom i numeracijom
* email outboxom
* pravilima i istorijom članarine
* onboarding stanjem korisnika

## Master admin zahtevi

Liste zahteva na čekanju, odobrenih i odbijenih zahteva, kao i detalj zahteva,
više ne čitaju tabelu `PresidentReg` direktno.

Koriste:

* `master_admin_get_president_requests(text,uuid)`

Funkcija zahteva aktivnog Master admina i MFA. Dijagnostika je potvrdila:

* `authenticated = true`
* `anon = false`

## Uklonjeni DEV ostaci

Završno čišćenje obuhvatilo je:

* sve politike čiji naziv počinje sa `DEV`
* direktna anonimna prava nad poslovnim tabelama
* stare finansijske funkcije koje su primale actor ID iz browsera
* stare događajne funkcije koje su primale tekstualnu ulogu
* stare tokove odobravanja promena ličnih podataka
* javno izvršavanje trigger funkcija
* neaktivne frontend helper funkcije za direktno čitanje članova

## Interfejs i pravila prikaza

Tokom funkcionalne provere potvrđena i primenjena pravila:

* forme moraju biti kompaktne i koristiti prostor u dve ili tri kolone
* datum se prikazuje kao `dd/mm/yyyy`, dok se u bazi čuva ISO vrednost
* dugme `Nastavi` nikada ne završava onboarding
* suvišni naslovi, podnaslovi i ponovljeni brojači se uklanjaju
* dugmad za glavnu akciju stoje desno u liniji sa naslovom kada prostor dozvoli
* checkbox i tekst moraju biti vertikalno poravnati
* nazivi u interfejsu su na srpskom, uključujući `Umetnički rukovodilac` i
  `Koreografija`

## Tehnička potvrda

Na kraju rada:

* TypeScript provera prolazi bez greške
* produkcioni Next.js build prolazi
* generiše se svih 25 aplikacionih ruta
* aplikacioni kod nema direktne `.from(...)` pozive ka Supabase tabelama

## SQL fajlovi završne etape

Najvažniji poslednji primenjeni i provereni fajlovi:

* `auth-v1-sections-detail-read.sql`
* `auth-v1-sections-detail-read-diagnostic.sql`
* `auth-v1-member-person-lookup.sql`
* `auth-v1-member-person-lookup-diagnostic.sql`
* `auth-v1-master-admin-president-requests-read.sql`
* `auth-v1-master-admin-president-requests-read-diagnostic.sql`
* `auth-v1-final-anon-cleanup.sql`
* `auth-v1-final-security-diagnostic.sql`

Prethodno su završeni i provereni Auth V1 fajlovi za članove, sekcije,
prisustvo, događaje, finansije, dozvole, Master admin zaštitu, predsedničko
odobravanje i onboarding.

## Sledeće mesto nastavka

Bezbednosni prelazak postojećih funkcionalnih modula je završen. Sledeći rad ne
treba ponovo da otvara DEV migraciju, osim ako nova dijagnostika pokaže stvaran
problem.

Nastavak ide ovim redom:

1. funkcionalno testiranje aplikacije sa stvarnim predsednikom
2. testiranje korisnika koji nije predsednik i kome se prava mogu menjati
3. testiranje drugog društva i izbora društva za osobu sa više članstava
4. implementacija aktivacije člana i roditelja iz login ekrana
5. implementacija budućih modula `Moji podaci`, `Moja deca`, `Garderoba` i
   `Izveštaji`
6. povezivanje sopstvenog SMTP servisa, verifikovanog domena i brendiranih
   Folkloraš email šablona
7. produkciona automatizacija licenci, upozorenja i mesečnih obračuna

## Važna granica V1

Završena bezbednosna migracija ne znači da su svi budući poslovni moduli već
implementirani. Znači da postojeći aktivni moduli više ne zavise od DEV
identiteta, širokih anonimnih prava ili direktnog pristupa tabelama.

## Dodatak 2026-07-27 — korepetitori na probama

Pripremljeno je proširenje kojim sekcija dobija više korepetitora iz `people`,
uključujući eksterne osobe koje nisu članovi društva. Za svaku dodelu postoji
poseban prekidač za evidentiranje prisustva.

Pripremljeni fajlovi:

* `auth-v1-section-accompanists-attendance.sql`
* `auth-v1-sections-permissions-read.sql`
* `auth-v1-sections-detail-read.sql`
* `auth-v1-attendance-permissions-read.sql`
* `auth-v1-section-accompanists-attendance-diagnostic.sql`

UI i produkcioni build su provereni. Dodatak je 28.07.2026. primenjen u aktivnoj
bazi. Dijagnostika je potvrdila tabelu `section_accompanists`, zaštićene
authenticated-only funkcije upravljanja i pretrage, jednu dozvolu, jedno
predsedničko pravilo i nula neispravnih osoba u evidenciji. Funkcionalno
testiranje sa stvarnim korepetitorom ostaje odloženo dok odgovarajuća osoba ne
bude uneta u `people`.
