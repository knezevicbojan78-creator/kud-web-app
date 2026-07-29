# Status Projekta

> Detaljna primopredaja završenog Auth V1 prelaska nalazi se u
> `docs/AUTH_V1_COMPLETION_2026-07-27.md`. Taj dokument je glavno polazište za
> naredni nastavak rada.
>
> Evidencija dopuna, provera, palete, korepetitora i masovnog unosa od
> 28.07.2026. nalazi se u `docs/WORK_LOG_2026-07-28.md`.
>
> Stalni način rada sa lokalnim kodom, prijavljenom Supabase sesijom,
> funkcionalnim testiranjem i proaktivnim predlaganjem dostupnih ubrzanja
> zapisan je u `docs/COLLABORATION_WORKFLOW.md`.

## Supabase Auth V1 — potvrđena logika, 2026-07-26

### Završna bezbednosna dopuna, 2026-07-27

* Prelazak aktivnih V1 modula sa direktnog pristupa tabelama na kontrolisane
  Auth RPC tokove je završen.
* Aplikacioni kod više nema direktne `.from(...)` pristupe Supabase tabelama.
* Završna dijagnostika aktivne baze potvrđuje: 0 DEV politika, 0 direktnih
  anonimnih prava nad poslovnim tabelama i 0 neočekivanih anonimnih funkcija.
* Javna su samo tri namerna anonimna toka: bootstrap status, javni cenovnik
  licenci i slanje predsedničkog zahteva. Kreiranje Master admin zapisa zahteva
  potvrđenu Auth sesiju.
* Kontrolisani V1 tokovi članova, sekcija, prisustva, događaja, finansija,
  dozvola i Master admin zahteva dijagnostički su potvrđeni.
* Frontend typecheck i produkcioni build sa 25 ruta prolaze.

* Potvrđen je V1 tok za početno aktiviranje jedinog Master admina, predsedničku registraciju i onboarding, aktiviranje unapred evidentiranih članova i roditelja, potvrdu veza i izbor društva.
* Jedini Master admin email je `knezevic.bojan78@gmail.com`; nalog je platformski, odvojen od svih društvenih identiteta i zahteva potvrđen email i TOTP.
* Master admin pri odobravanju predsedničkog zahteva obavezno bira licencu. Društvo i licenca postaju operativni tek nakon završenog onboardinga predsednika.
* Postojeće forme `SocietyDataForm` i `UF_MEMBER_FORM` ostaju jedine forme za dopunu društva i osobe.
* Član i roditelj mogu aktivirati nalog samo ako ih je predsednik prethodno evidentirao; nova članstva i roditeljske veze eksplicitno se potvrđuju.
* Potvrđeni model i V1 granice zapisani su u `docs/AUTH_V1_READINESS.md`.
* Read-only dijagnostika pripremljena je u `supabase/auth-v1-readiness-diagnostic.sql`.
* Dijagnostika je uspešno pokrenuta u aktivnoj bazi 2026-07-26: nema Auth korisnika, društava, osoba, članstava, duplih emailova, Auth konflikata niti neusaglašenih članskih Auth veza.
* Evidentirano je 49 `public` politika dostupnih ulogama `anon`/`authenticated`/`public` i 58 javno izvršivih RPC funkcija. To je očekivani DEV inventar koji se uklanja modul po modul, ne odjednom.
* Lokalno su pripremljeni `auth-v1-master-admin-foundation.sql` i prateća read-only dijagnostika.
* Login više ne koristi DEV izbor uloge. Implementirani su Master admin registracija, potvrda emaila, callback, reset lozinke, obavezni TOTP, atomski bootstrap na `aal2`, provera pristupa layoutu i stvarna odjava.
* Frontend `typecheck` i produkcioni build prolaze.
* SQL osnova je primenjena, `Before User Created` hook uključen, a prvi Master admin nalog uspešno je registrovan, email potvrđen i TOTP aktiviran.
* Završna dijagnostika potvrđuje jednog Auth korisnika i jednog Master admina, bez neispravnih zapisa ili konflikta sa identitetima društava.
* Lokalno je pripremljena migracija `auth-v1-master-admin-rpc-protection.sql`: svih osam Master admin RPC funkcija dobija obaveznu proveru aktivnog Master admina i `aal2`, uklanja se `anon` pristup, a audit izvršioca uzima se iz Auth sesije.
* Sledeći korak je primena migracije u aktivnoj bazi i pokretanje `auth-v1-master-admin-rpc-protection-diagnostic.sql`.
* Pre uključivanja stvarnih korisnika obavezno je povezati sopstveni SMTP servis i verifikovani domen, postaviti pošiljaoca `Folkloraš` i pripremiti brendirane Auth email šablone na srpskom. Aktivacioni email predsednika može da sadrži naziv društva, dok pošiljalac ostaje platformski `Folkloraš`.
* Lokalno je pripremljen minimalni predsednički zahtev: osnovni podaci društva i predsednika, bez lozinke i finansijskih/onboarding detalja. Predsednik bira željeni aktivni licencni paket sa javnog cenovnika; Master admin ga vidi u zahtevu i potvrđuje ili menja pri obaveznoj dodeli licence. Direktni javni upis u `PresidentReg` zamenjen je kontrolisanim RPC pozivom `auth_submit_president_request`.
* `auth-v1-president-request.sql` je primenjen u aktivnoj bazi 2026-07-26. Dijagnostika potvrđuje da su direktni `anon` i `authenticated` insert zatvoreni, kontrolisani RPC dostupan i javni pregled aktivnih paketa omogućen.
* Slanje predsedničkog zahteva i njegov prikaz Master adminu funkcionalno su potvrđeni 2026-07-27.
* Lokalno je pripremljen atomski Master admin approval tok: obavezna potvrda paketa i perioda, društvo u stanju `ONBOARDING`, licenca `PENDING_ONBOARDING`, audit stvarnog Master admina i slanje email linka za potvrdu i postavljanje predsedničke lozinke.
* Predsednički zahtev sada odvojeno bira licencni paket i mesečni ili godišnji obračun. Master admin oba izbora dobija unapred postavljena, ali ih može promeniti pri odobravanju; promotivne licence ostaju isključivo Master admin opcija.
* `auth-v1-president-approval.sql` je primenjen u aktivnoj bazi 2026-07-27. Dijagnostika potvrđuje tabelu dodela, authenticated-only approval, zatvoren anon pristup, dostupnu predsedničku aktivaciju i nula neispravnih odobrenih zahteva.
* Funkcionalno su potvrđeni odobravanje postojećeg zahteva, ponovno slanje aktivacionog linka, obrada callbacka i postavljanje prve predsedničke lozinke 2026-07-27.
* Centralni login routing je primenjen i dijagnostički potvrđen 2026-07-27: authenticated korisnik dobija odredište prema stvarnom identitetu, dok anonimni poziv nije dozvoljen. Master admin ide na MFA/Dashboard, a predsednik sa nezavršenim onboardingom na predsednički onboarding.
* Lokalno je pripremljen obavezni predsednički onboarding kroz postojeće `SocietyDataForm` i `UF_MEMBER_FORM`: čuvanje napretka, zaključan Auth email i licenca, automatsko kreiranje osobe/članstva/funkcije Predsednik i aktiviranje društva/licence tek po završetku.
* `auth-v1-president-onboarding.sql` je primenjen 2026-07-27. Dijagnostika potvrđuje sva tri authenticated onboarding RPC toka, zatvoren anonimni završetak i jedno društvo u stanju `ONBOARDING`.
* Onboarding varijante `SocietyDataForm` i `UF_MEMBER_FORM` preuređene su u kompaktan responzivni raspored: tri kolone na širokom ekranu, dve na tabletu i jedna na telefonu. Obavezno opšte pravilo zapisano je u `docs/CGPT.md` i odluka u `docs/DECISIONS.md`.
* Datumi u onboarding formi prikazuju se kao `dd/mm/yyyy`, uz nepromenjen ISO format podataka. Konačna aktivacija je odvojena od unutrašnjeg dugmeta `Nastavi` i zahteva poseban treći korak za potvrdu.
* Završeni predsednički onboarding sada vodi u predsednički dashboard. Aplikacioni okvir razlikuje Master admina i predsednika, prikazuje odgovarajući meni i naziv aktivnog društva, a predsednički dashboard učitava isključivo zbirne podatke njegovog društva.
* Pokrenut je sistemski prelaz cele aplikacije sa DEV konteksta na Auth V1. Inventar i etape zapisani su u `docs/AUTH_V1_MIGRATION_PLAN.md`, a `auth-v1-application-context.sql` uvodi centralni serverski kontekst korisnika, društvenih članstava i stvarnih funkcija.
* Etapa 2A je lokalno pripremljena za `Moje sekcije` i `Prisustvo`: uklonjeno je čitanje testne uloge iz browser storage-a i izbor prvog aktivnog društva. Oba modula sada koriste stvarno članstvo, funkcije i dozvoljene sekcije iz centralnog Auth V1 konteksta.
* U Etapi 2B otkriveno je da su DEV RPC funkcije prisustva verovale ulozi i actor ID-u koje šalje browser. `auth-v1-attendance-security.sql` pretvara stare funkcije u zatvorene implementacije, a javni Auth V1 omotači sami utvrđuju stvarnog predsednika ili UR-a prema `auth.uid()` i konkretnoj sekciji.
* Sledeće je funkcionalni test dopune društva, profila predsednika i završne aktivacije društva/licence.

## Predsednička podešavanja — funkcije i dozvole, 2026-07-25

* Potvrđena arhitektura zapisana je u `docs/PERMISSIONS_V1.md`.
* Potvrđeno je da trenutni `Moje sekcije` tok ne proverava funkciju kandidata i omogućava dodelu UR-a ili korepetitora bilo kom aktivnom članu.
* Novo pravilo zahteva prethodnu aktivnu funkciju `UR` ili `Korepetitor` pre sekcijske dodele.
* Podešavanja će imati tabove `Članarina`, `Funkcije i zaduženja` i `Dozvole`.
* Dozvole koriste jedinstveni ekran: podrazumevano se uređuje cela funkcija, a jasno izabran pojedinačni izuzetak odnosi se samo na konkretnog člana.
* Pojedinačna prava koriste `INHERIT`, `ALLOW` i `DENY`, uz prikaz konačnog prava za člana sa više funkcija.
* Katalog i početna/zaključana prava su naknadno definisani 2026-07-26; trenutno stanje implementacije navedeno je u dopuni ispod.

### Dopuna 2026-07-26

* Definisana su početna i dodatna prava predsednika, UR-a, blagajnika, sekretara, upravnika, korepetitora, člana i roditelja/staratelja.
* Definisani su katalozi za članove, sekcije, prisustvo, događaje, repertoar, finansije i audit.
* Potvrđeno je sabiranje prava više aktivnih funkcija i objedinjeni korisnički prikaz.
* Samo predsednik vidi i koristi podešavanja dozvola.
* Svaki novi modul mora istovremeno dopuniti katalog dozvola.
* Dokumentacija sekcija i finansija usklađena je sa delegiranjem prava.
* Plan baze, interfejsa, migracije i testiranja zapisan je u `docs/PERMISSIONS_IMPLEMENTATION_PLAN.md`.
* SQL osnova iz `supabase/permissions-v1-foundation.sql` uspešno je primenjena u aktivnoj bazi 2026-07-26.
* Read-only provera iz `supabase/permissions-v1-foundation-diagnostic.sql` potvrdila je 67 aktivnih dozvola, 154 šablona, 140 pravila funkcija i nula neispravnih opsega, pogrešnih društava ili društava bez aktivne funkcije predsednika.
* Pojedinačnih izuzetaka i audit zapisa još nema, što je očekivano pre izrade kontrolisanih workflow-a i interfejsa.
* Centralni read obračun iz `supabase/permissions-v1-effective-read.sql` uspešno je primenjen u aktivnoj bazi 2026-07-26.
* Dijagnostika je potvrdila 10 aktivnih članova, 4 sa funkcijama, 2 sa više funkcija i 3 roditeljska konteksta, uz nula grešaka članskih, roditeljskih i zaključanih prava i nula curenja predsedničke dozvole.
* Kontrolisani workflow-i za pregled i izmenu prava iz `supabase/permissions-v1-management-workflows.sql` primenjeni su u aktivnoj bazi 2026-07-26.
* Osnovna dozvola `members.bulk_import` i provera pristupa masovnom unosu iz `permissions-v1-members-bulk-import.sql` primenjene su u aktivnoj bazi 2026-07-28.
* Korekcija je primenjena u aktivnoj bazi: svim postojećim i budućim funkcijama `Predsednik` upisuje se zaključano pravo na nivou društva, provera pristupa vezana je za aktivno društvo, a greška RPC provere više ne daje pristup kroz UI fallback.
* Dijagnostika masovnog unosa potvrđuje jednu aktivnu funkciju predsednika, jedno odgovarajuće zaključano pravilo i nula pogrešno zaključanih pravila drugih funkcija.
* Lokalna implementacija masovnog unosa sadrži čitanje i validaciju Excel fajla, pregled grešaka, preskakanje email adresa koje već postoje, pripremu kandidata, predsedničko potvrđivanje, jednokratne pozive i javni obrazac sa automatskim čuvanjem nacrta.
* Predsednički ekran u lokalnom režimu može da napravi i kopira odvojene probne linkove za člana i roditelja. Stvarno slanje emaila nije potrebno za lokalnu funkcionalnu proveru.
* Pravila su opisana u `docs/MEMBER_BULK_IMPORT_SELF_SERVICE.md`, a baza u `supabase/members-v1-bulk-import-approval.sql`.
* Migracija masovnog unosa primenjena je u aktivnoj Supabase bazi 2026-07-28. Dijagnostika je potvrdila 3/3 tabele, 10/10 funkcija, izvršavanje javnih funkcija za `anon`, zabranu anonimnog pokretanja masovnog unosa i dozvolu za `authenticated`.
* Tok tokena je dodatno ispravljen za Supabase `extensions` šemu. Lokalna provera nepostojećeg tokena vraća korisničku poruku `Link nije važeći` bez tehničke greške. Stvarno slanje emaila ostaje odloženo do probnog objavljivanja.
* Funkcionalna provera masovnog unosa završena je 2026-07-28: novi red sa imenom, prezimenom i emailom prolazi, postojeći email se preskače uz jasno obaveštenje, a kandidat se pravilno pojavljuje u predsedničkom redu za potvrdu.
* Pronađena je i ispravljena kompatibilnost sa ranijom tabelom `member_data_invitations`: migracija sada dodaje ulogu primaoca i menja staro ograničenje jednog linka u odvojene linkove člana i roditelja.
* Funkcionalno su potvrđeni pravljenje oba lokalna test linka, otvaranje izolovanog javnog obrasca, automatsko čuvanje, nastavak preko istog linka, zajednički nacrt i zaključavanje roditeljskog obrasca dok član uređuje podatke.
* Javni obrazac sada normalizuje prazne SQL/Excel vrednosti pre prikaza, pa `null` polja više ne obaraju stranicu. Testni kandidat je nakon provere odbačen, a oba njegova linka su opozvana.
* Doneta je odluka da projekat ostaje u local-first režimu dok glavne funkcije i bezbednosne provere ne budu spremne za ograničenu probu. Vercel, javni domen i Resend odlažu se do tada; plan i kriterijumi prelaska zapisani su u `docs/LOCAL_FIRST_RELEASE_PLAN.md`.
* Prva dijagnostika je pokazala `president_actor_count = 0`: aktivna funkcija `Predsednik` postoji, ali nijedan aktivni član trenutno nema potvrđenu dodelu te funkcije. Zbog toga funkcionalna provera President-only workflow-a još nije završena.
* Read-only dijagnostika workflow-a pripremljena je u `supabase/permissions-v1-management-workflows-diagnostic.sql`.
* Sprovođenje prava po poslovnim modulima još nije započeto; Master admin Auth bootstrap osnova pripremljena je lokalno.
* Odlučeno je da se ne pravi dodatni dev adapter za dozvole jer projekat uskoro prelazi na Supabase Auth.
* Auth readiness plan, obavezne provere, redosled prelaska i tačno mesto nastavka zapisani su u `docs/AUTH_V1_READINESS.md`.
* Auth readiness dijagnostika je završena. Sledeći zadatak je primena i funkcionalna provera Master admin Auth osnove; DEV politike se i dalje ne uklanjaju unapred.

## Primopredaja — Master admin V1, pauza do dva stvarna društva, 2026-07-25

### Završeno

* Master admin ima Dashboard sa brojem aktivnih/suspendovanih društava, registracijama, licencama koje ističu, raspodelom licenci i nedavnim audit akcijama.
* Paneli `Licence` i `Audit` na Dashboardu imaju sopstveni vertikalni skrol i ne produžavaju stranicu.
* Liste `Društva`, `Zahtevi na čekanju`, `Odobreni zahtevi` i `Odbijeni zahtevi` koriste kompaktne tabele sa sopstvenim skrolom i lepljivim zaglavljem kada postoje redovi.
* Detalj društva ima tabove `Pregled`, `Podaci društva`, `Licenca`, `Predsednik`, `Zahtevi` i `Istorija`.
* Master admin vidi samo zbirne brojeve članova i sekcija, bez pristupa pojedinačnim članovima i nazivima sekcija.
* Ručna suspenzija i ponovna aktivacija rade uz obavezan razlog i audit.
* Izmena podataka društva koristi kompaktan prikaz. Dugmad su aktivna samo kada postoje izmene, odbacivanje odmah vraća sačuvane podatke, a promena taba sa nesačuvanim podacima nudi čuvanje, odbacivanje ili nastavak uređivanja.
* Paketi su `Malo društvo` (100 članova / 6 sekcija), `Standard` (250 / 12) i `Veliko društvo` (500 / 20). Cene bez poreza su 8/80 EUR, 15/150 EUR i 25/250 EUR mesečno/godišnje.
* Master admin u `Podešavanjima sistema` pojedinačno menja mesečnu i godišnju cenu uz obavezan razlog i audit. Promena važi samo za buduće licence.
* Kartica `Licenca` jasno razdvaja mesečnu, godišnju i promotivnu licencu, prikazuje odgovarajuću cenu, podržava promociju od 3, 6 ili 12 meseci i prikazuje istoriju perioda.
* Direktno menjanje legacy oznake licence uklonjeno je iz taba `Podaci društva`.
* Testnom društvu dodeljena je promotivna licenca `Malo društvo` od 25.07.2026. do 24.10.2026.
* Primenjeni su SQL fajlovi `master-admin-v1-setup.sql`, `master-admin-v1-society-detail-workflows.sql`, `master-admin-v1-license-workflows.sql` i `master-admin-v1-license-price-workflows.sql`.
* Frontend `typecheck` i produkcioni build prolaze nakon Master admin izmena.

### Namerno odloženo do dva stvarna društva

Kada u aktivnoj bazi budu dva stvarna pilot društva, testirati:

* mesečnu plaćenu licencu
* godišnju plaćenu licencu
* produženje pre isteka postojeće licence
* novu licencu nakon isteka
* ponovljenu promotivnu licencu uz eksplicitnu potvrdu
* odbijanje paketa čije limite društvo već premašuje
* automatsku reaktivaciju društva suspendovanog isključivo zbog isteka licence
* tačnost zbirnih brojeva članova i sekcija za društva različite veličine
* odvojenost podataka između dva društva u svim Master admin pregledima
* istoriju licencnih perioda, uplata i audit zapisa
* pretragu, filtere i unutrašnje skrolove sa realnim brojem redova

### Još nije implementirano — obavezno pre produkcije

* Dnevni automatski posao za upozorenja, istek licence i suspenziju narednog dana.
* Baza-level read-only zaštita svih korisničkih upisa za suspendovano društvo, uz nastavak dozvoljenih automatskih procesa.
* Zaštita aktiviranja novog člana ili sekcije kada je dostignut limit paketa.
* Kontrolisano poništavanje pogrešno evidentirane licencne uplate/perioda uz razlog i audit, bez fizičkog brisanja.
* Kontrolisana i auditovana izmena podataka društva umesto trenutnog direktnog frontend update-a.
* Evidencija in-app/email opomena 5 dana pre mesečnog i 30/7 dana pre godišnjeg ili promotivnog isteka; stvarno slanje emaila može doći kasnije.
* Finalni Supabase Auth i RLS umesto privremenih DEV `anon` execute prava.

### Tačno mesto za nastavak

* Master admin UI i ručni licencni tok su za sada završeni. Sledeći Master admin rad počinje kada budu dostupna dva stvarna pilot društva ili kada krenemo u produkcionu bezbednost i automatizaciju.

## Licence — potvrđeni paketi, 2026-07-25

* Potvrđeni su paketi `Malo društvo` (100 članova / 6 sekcija), `Standard` (250 / 12) i `Veliko društvo` (500 / 20).
* Mesečne cene bez poreza su 8 EUR, 15 EUR i 25 EUR.
* Godišnje cene bez poreza su 80 EUR, 150 EUR i 250 EUR, odnosno deset mesečnih naknada.
* Društva iznad 500 aktivnih članova ili 20 aktivnih sekcija koriste poseban paket po dogovoru.
* U V1 svi paketi imaju iste osnovne funkcije i razlikuju se po kapacitetu.
* `supabase/master-admin-v1-license-workflows.sql` primenjen je u aktivnoj bazi 2026-07-25.
* `supabase/master-admin-v1-license-price-workflows.sql` primenjen je u aktivnoj bazi za kontrolisanu promenu cena uz obavezan razlog i audit.
* Ekran `Podešavanja sistema → Cene licenci` prikazuje aktivne pakete, cene bez poreza i pojedinačno uređivanje mesečne/godišnje cene.
* Frontend `typecheck` i produkcioni build prolaze nakon dodavanja ekrana cenovnika.
* SQL za cene primenjen je i funkcionalno potvrđen 2026-07-25. Paket `Standard` probno je promenjen sa 15,00 na 15,01 EUR i vraćen na 15,00 EUR; oba audit zapisa namerno ostaju u istoriji.
* Kartica `Licenca` sada prikazuje trenutni period, istoriju perioda i sklopivu formu za promotivnu, mesečnu ili godišnju licencu.
* Staro direktno menjanje oznake licence uklonjeno je iz Master admin taba `Podaci društva`; licencom se upravlja samo kroz kontrolisani licencni workflow.
* Prikaz paketa i forme dodele funkcionalno je potvrđen, dok stvarnu dodelu prve licence treba testirati izborom željenog promotivnog ili plaćenog perioda.

## Primopredaja — Master admin detalj društva, 2026-07-24

### Završeno i funkcionalno potvrđeno

* `supabase/master-admin-v1-society-detail-workflows.sql` uspešno je primenjen u aktivnoj Supabase bazi.
* Master admin detalj društva koristi tabove `Pregled`, `Podaci društva`, `Licenca`, `Predsednik`, `Zahtevi` i `Istorija`.
* Pregled prikazuje samo zbirne brojeve aktivnih i neaktivnih članstava i sekcija; Master admin nema pristup identitetima članova niti nazivima pojedinačnih sekcija.
* Funkcionalno je potvrđen prikaz društva `Test` sa 10 aktivnih članova i 6 aktivnih sekcija.
* Suspenzija i ponovna aktivacija zahtevaju obavezno obrazloženje. Obe promene uspešno su proverene i upisane u Master admin audit istoriju.
* Nakon testa društvo `Test` vraćeno je u status `ACTIVE`. U istoriji su namerno ostala dva probna zapisa — suspenzija i ponovna aktivacija.
* Tab `Podaci društva` koristi zajedničku `SocietyDataForm`, ali u Master admin prikazu ima kompaktan raspored: četiri kolone na širokom ekranu, dve na tabletu i jednu na telefonu.
* Naziv, adresa i tip licence dobijaju šira polja, dok su visina kontrola, razmaci i spoljašnji okvir forme smanjeni.
* Kompaktni prikaz je vizuelno potvrđen, a `npm.cmd run typecheck` prolazi.

### Tačno mesto za nastavak

* Osnovni Master admin Dashboard, liste zahteva, agregatna lista društava i detalj društva sa kontrolom statusa završeni su u trenutnom DEV/V1 opsegu.
* Sledeći funkcionalni deo je upravljanje licencnim periodima: promotivne licence od 3, 6 ili 12 meseci, puna mesečna/godišnja licenca i prikaz njenog trajanja i statusa.
* Pre produkcije privremeni DEV `anon` pristup Master admin RPC funkcijama mora biti uklonjen i zamenjen stvarnim Supabase Auth identitetom i RLS pravilima.

## Master admin V1 — 2026-07-24

### Potvrđeno i dokumentovano

* Potvrđena arhitektura Master admin panela zapisana je u `docs/MASTER_ADMIN_V1.md`.
* Master admin je platformska uloga i nema pristup pojedinačnim članovima ili sekcijama društva.
* Za pregled i buduće licencne limite koriste se samo agregatni brojevi aktivnih i neaktivnih članstava i sekcija; za limit se računaju `ACTIVE` članstva i `ACTIVE` sekcije.
* V1 statusi društva su `ACTIVE` i `SUSPENDED`; arhiviranje i brisanje nisu deo ove verzije.
* Suspenzija je read-only režim za korisnike društva, dok automatski mesečni obračun članarina i tehnički procesi nastavljaju da rade.
* Licence su unapred plaćeni mesečni, godišnji ili promotivni periodi. Promotivni period traje 3, 6 ili 12 meseci.
* Mesečno obaveštenje planira se 5 dana pre isteka, a godišnje i promotivno 30 i 7 dana pre isteka. Neprodužena licenca suspenduje društvo narednog dana.

### Primenjeno i funkcionalno provereno

* `supabase/master-admin-v1-setup.sql` primenjen je u aktivnoj bazi 2026-07-24 i priprema pakete, licencne periode, pune uplate, suspenzije, obaveštenja i Master admin audit.
* Platformske tabele imaju uključen RLS i nemaju direktan klijentski pristup.
* Agregatne funkcije `master_admin_get_dashboard` i `master_admin_get_society_summaries` ne vraćaju identitete članova niti nazive sekcija.
* Master admin sada ima zaseban Dashboard sa pokazateljima platforme i pregledom licenci/audita.
* Lista Društva dobila je pretragu, filter statusa, filter licence i zbirne brojeve aktivnih članova i sekcija.
* Master admin meni sada sadrži Dashboard, a zaglavlje je označeno kao administracija sistema.
* Funkcionalno je potvrđeno učitavanje Dashboarda iz aktivne baze: 1 aktivno društvo, 0 suspendovanih, 0 novih registracija i Free raspodela licence.
* Funkcionalno je potvrđen agregatni pregled društva `Test`: 10 aktivnih članova i 6 aktivnih sekcija, bez preuzimanja njihovih pojedinačnih podataka.
* Liste registracija na čekanju, odobrenih i odbijenih registracija koriste zajednički kompaktan tabelarni obrazac preko cele širine, sa brojem rezultata, pretragom, statusnom oznakom i akcijom za detalj.
* Odobrene registracije u glavnoj listi ne prikazuju tehnički ID društva niti email Master admina; ti podaci ostaju u detalju zahteva i auditu.
* Master admin detalj društva preuređen je u tabove `Pregled`, `Podaci društva`, `Licenca`, `Predsednik`, `Zahtevi` i `Istorija`.
* Tab `Pregled` prikazuje isključivo agregatne brojeve aktivnih/neaktivnih članstava i sekcija, licencu, administrativni kontakt i status društva.
* Postojeća `SocietyDataForm` ostaje jedina forma za izmenu podataka društva i koristi se u tabu `Podaci društva`.

### Dodatni workflow primenjen u aktivnoj bazi

* `supabase/master-admin-v1-society-detail-workflows.sql` obezbeđuje kontrolisani agregatni detalj društva i auditovanu promenu statusa `ACTIVE ↔ SUSPENDED` sa obaveznim razlogom.
* Tabovi detalja, suspenzija, ponovna aktivacija i upisi u `master_admin_audit_log` funkcionalno su potvrđeni 2026-07-24.

### Sledeći korak

* Pre produkcije ukloniti privremeni `anon` execute pristup agregatnim Master admin funkcijama i zameniti ga stvarnim Auth/RLS pravilima.
* Nakon praktičnog testa sa najmanje dva društva definisati nazive paketa, mesečne i godišnje cene i limite članova i sekcija.

## Primopredaja — Kotizacije događaja, 2026-07-23

### Završeno i funkcionalno potvrđeno

* Događaj sa finansijskim učešćem definiše podrazumevani iznos kotizacije, troslovnu valutu, obavezni krajnji rok plaćanja i opcionu napomenu. Isti podaci mogu se menjati i prikazuju se u pregledu događaja.
* Promena učesnika iz `PLANNED` u `CONFIRMED` koristi finansijski kontrolisani RPC tok i formira kotizaciju. U DEV režimu Događaji koriste isti tehnički kontekst izvršioca kao kartica `FINANSIJE`.
* Izbor sekcije događaja automatski dodaje sve njene aktivne članove u spisak učesnika sa statusom `PLANNED`. Član koji pripada više izabranih sekcija ne duplira se.
* Ručni padajući izbor sekcije i pretraga pojedinačnih članova uklonjeni su iz taba `SEKCIJE I UČESNICI`. Poseban tok za dodavanje putnika koji nije član ostaje dostupan.
* Promena statusa učesnika više ne koristi širok select. Statusi su prikazani kao kompaktne ikonice sa bojom i opisom: `PLANNED`, `CONFIRMED`, `DECLINED`, `CANCELLED`, `ATTENDED` i `ABSENT`.
* Iznad spiska je dodat filter sa istim statusnim ikonicama. Dozvoljen je izbor više filtera; ponovni klik uklanja pojedinačni filter, a bez aktivnih filtera prikazuju se svi učesnici. Filter se resetuje promenom događaja.
* Spisak učesnika ima ograničenu visinu i sopstveni vertikalni skrol. Zaglavlje filtera i statusne ikonice u redovima su horizontalno poravnati.
* Zaglavlje izabranog događaja je sabijeno u jedan red: tip događaja, naziv i mesto, dok status događaja ostaje desno. Sekcije se normalno prelamaju bez horizontalnog skrola.
* Frontend `typecheck` prolazi nakon današnjih izmena.

### Pripremljeno lokalno — primeniti u aktivnoj Supabase bazi

* `finance-v1-event-refund-workflows.sql` sada sadrži `finance_cancel_event_section`: predsednik pri odštikliranju sekcije mora uneti razlog i potvrditi posledice; učesnici koji ostaju povezani preko druge sekcije nisu pogođeni; ekskluzivni nepotvrđeni učesnici se uklanjaju, a njihove kotizacije se auditovano poništavaju. Ranije plaćeni iznos postaje kredit.
* `finance-v1-dev-test-access.sql` daje DEV testnom toku potrebna prava za promenu finansijskog statusa učesnika i otkazivanje sekcije bez finalne Supabase Auth veze.
* Redosled primene je: prvo `finance-v1-event-refund-workflows.sql`, zatim `finance-v1-dev-test-access.sql`.
* Fizičko brisanje finansijskih obaveza nije dozvoljeno. Otkazane kotizacije dobijaju status `CANCELLED` i nestaju iz otvorenih zaduženja, ali ostaju u istoriji i auditu.

### Sledeći korak

* U tabu `SEKCIJE I UČESNICI` napraviti predsedničku izmenu pojedinačne kotizacije pre potvrđivanja učesnika: podrazumevani iznos, poseban iznos ili oslobađanje (`0`), uz obaveznu napomenu za odstupanje.
* Nastaviti završno vizuelno doterivanje taba nakon funkcionalne provere većeg broja sekcija i učesnika.
* Pre produkcije ukloniti DEV fallback i povezati stvarne Supabase Auth identitete, funkcije i RLS pravila.

## Primopredaja — Finansije, 2026-07-22

### Potvrđeno završeno

* Poslovna pravila modula `FINANSIJE V1` detaljno su definisana u `docs/FINANCE_V1.md`.
* U aktivnoj Supabase bazi korisnik je uspešno primenio: `finance-v1-tables-setup.sql`, `finance-v1-membership-workflows.sql`, `finance-v1-monthly-cron.sql`, `finance-v1-payment-workflows.sql`, `finance-v1-event-refund-workflows.sql` i `finance-v1-read-workflows.sql`.
* Mesečni cron je kreiran i ranije je potvrđen rezultatom `schedule = 2`.
* Kartica `FINANSIJE` više nije placeholder. Implementirani su pretraga člana/roditelja, porodični profil, otvorene i dospele obaveze, kredit, istorija uplata i modal za delimičnu/punu uplatu sa ručnim izborom obaveza.
* Frontend typecheck prolazi. Produkcioni build je bio zaustavljen samo zato što okruženje nije moglo da preuzme postojeći Google font `Nunito Sans`.

### Trenutni blokator

* Projekat je još u DEV/V1 test režimu: uloga se bira pri testnom loginu i nije finalno povezana sa Supabase Auth identitetom.
* Aktivna baza je read-only proverena: društvo `Test` ima 10 aktivnih članova, ali nema dodeljene funkcije u `society_member_function_assignments`, niti vrednosti u legacy koloni `society_members.funkcija`.
* `finance-v1-dev-test-access.sql` je prilagođen tom stvarnom stanju i uspešno primenjen 2026-07-23.
* Pretraga članova na kartici `FINANSIJE` sada radi. Testna uloga dolazi iz frontend login izbora, a aktivni član testnog društva koristi se samo kao tehnički izvršilac.
* `finance-v1-read-workflows.sql` je usklađen tako da menadžerski DEV kontekst može otvoriti profil bez finalnog Auth identiteta; nakon ponovne primene read workflow-a i DEV pristupa uspešno je potvrđeno otvaranje profila člana bez zaduženja, sa nulama za otvorene obaveze, dospele obaveze, kredit i istoriju uplata.
* Za člana `i3 p3` uspešno je napravljeno DEV testno zaduženje članarine od 3.000 RSD za 07/2026, sa rokom 01.08.2026.
* Ispravljen je konflikt izlazne kolone `counter_year` u `finance_next_document_number` korišćenjem primarnog ključa u `ON CONFLICT` klauzuli.
* Uspešno je funkcionalno potvrđena delimična gotovinska uplata od 1.000 RSD: automatsko zatvaranje modala, broj potvrde `UPL-2026-000001`, preostali dug 2.000 RSD, prikaz plaćenog iznosa i zapis u istoriji uplata.
* Uspešno je potvrđena ručna uplata na račun od 500 RSD (`UPL-2026-000002`) i višak gotovinske uplate kao kredit: uplata 2.000 RSD zatvorila je preostali dug 1.500 RSD i evidentirala kredit 500 RSD (`UPL-2026-000003`).
* Uspešno je potvrđen automatski mesečni obračun za 08/2026 i automatska primena kredita: članarina 3.000 RSD, primenjen kredit 500 RSD, kredit sveden na nulu i preostali dug 2.500 RSD sa rokom 01.09.2026.
* Istorija uplata je sabijena na jedan red po uplati i dobila je sopstveni vertikalni skrol, kako veći broj uplata ne bi produžavao celu stranicu.
* DEV fallback se ne sme preneti u produkciju; mora biti zamenjen finalnom Auth/RLS proverom.

### Obavezan prvi korak pri nastavku

* Osnovni blagajnički tok članarine je funkcionalno potvrđen. Sledeće izraditi predsednička podešavanja članarine i meseci bez naplate, pa zatim tok kotizacije za događaj.
* Implementiran je tab `PODEŠAVANJA → ČLANARINA` sa standardnim iznosom, trajnim godišnjim obrascem 12 meseci, razlogom promene i automatskim važenjem od sledećeg meseca.
* Pripremljena je migracija `finance-v1-recurring-membership-settings.sql` sa istorijom trajnih pravila po broju meseca i kontrolisanim RPC funkcijama za čitanje i izmenu.
* Mesečni generator je prebačen sa pojedinačnog kalendarskog datuma na trajni godišnji obrazac meseci.
* Registracija društva je proširena početnom valutom, standardnom članarinom i izborom meseci naplate; approval prenosi vrednosti na novo društvo.
* Pripremljena je migracija `finance-v1-registration-settings.sql` za nova polja registracionog zahteva.
* Migracije `finance-v1-registration-settings.sql`, `finance-v1-recurring-membership-settings.sql`, ponovljeni `finance-v1-membership-workflows.sql` i završni `finance-v1-dev-test-access.sql` uspešno su primenjene u aktivnoj Supabase bazi 2026-07-23.
* Funkcionalno je potvrđen tab `PODEŠAVANJA → ČLANARINA`: učitavanje iznosa 3.000 RSD, svih 12 početno aktivnih meseci, deaktiviranje meseca, ponovno aktiviranje i čuvanje sa važenjem od sledećeg meseca.
* Primenjen je `finance-v1-member-fee-settings-ui.sql`; tab prikazuje članove sa posebnom članarinom ili oslobođenjem, a funkcionalno je potvrđeno vraćanje oslobođenog člana na standardnu članarinu i automatsko uklanjanje sa liste izuzetaka.
* Funkcionalno je potvrđena pretraga standardnog člana, postavljanje statusa `Oslobođen članarine`, prikaz bez iznosa 0 i ponovno pojavljivanje na listi izuzetaka. Pojedinačni režimi `STANDARD`, `CUSTOM` i `EXEMPT` završeni su u trenutnom DEV/V1 opsegu.
* Tok kotizacije događaja je dopunjen obaveznim krajnjim rokom plaćanja i opcionom napomenom u kreiranju i izmeni događaja. Podaci se prikazuju u pregledu događaja, a frontend sprečava potvrdu nepotpunih finansijskih podešavanja. Typecheck prolazi 2026-07-23.
* Događaji sada koriste isti DEV finansijski kontekst izvršioca kao kartica `FINANSIJE`. Time je uklonjena greška „Prijavljeni korisnik nije povezan sa članom društva“ pri promeni učesnika iz `PLANNED` u `CONFIRMED`; uspešna potvrda prikazuje poruku da je kotizacija formirana.
* Otkazivanje sekcije događaja je prebačeno na kontrolisani RPC tok sa obaveznim razlogom i potvrdom. Učesnici koji ostaju preko druge sekcije nisu pogođeni; ekskluzivni nepotvrđeni učesnici se uklanjaju, a njihove postojeće kotizacije se auditovano poništavaju uz kredit za ranije plaćeni iznos. Za aktivnu bazu ponovo primeniti `finance-v1-event-refund-workflows.sql`, pa `finance-v1-dev-test-access.sql`.

## Završeno

* Lokalni projekat radi u `D:\PROJEKATWebAPP`
* Pravila za maloletne članove i roditelje/staratelje su dokumentovana
* Pravila identiteta za `people` su dokumentovana
* Wizard pravila za `UF_MEMBER_FORM` add-member tok su dokumentovana
* Pocetno grananje `UF_MEMBER_FORM` toka na punoletnog i maloletnog clana je dokumentovano
* Pravilo da je kod maloletnog clana prvi email email roditelja/staratelja, a ne email deteta, je dokumentovano
* Redosled provere email-a, lookup u `people.email` i zastita od dupliranja clanova po drustvu su dokumentovani
* Pravila za read-only postojece podatke i dopunu praznih podataka u add-member toku su dokumentovana
* Pravila da se roditelji/staratelji iz child/guardian toka ne upisuju u `society_members` su dokumentovana
* Pravila vidljivosti i prava izmene podataka clanova su dokumentovana
* Pravila za predsednika, UR i osetljive podatke clanova su dokumentovana
* Pravila za modul `MOJE SEKCIJE`, sekcijska ogranicenja UR-a i upravljanje sekcijama su dokumentovana
* Pravilo da `UF_MEMBER_FORM` upravlja pripadnoscu clana sekcijama kroz checkbox listu je dokumentovano
* Pravilo `MOJE SEKCIJE upravlja sekcijama`, a `UF_MEMBER_FORM upravlja clanom` je dokumentovano
* Pravila za vise UR-ova po sekciji, korepetitora i ACTIVE/INACTIVE status sekcija i clanstva u sekciji su dokumentovana
* Pravilo `member_sections = trenutno stanje`, `member_section_history = istorija promena` je dokumentovano
* Pravilo da za istog clana i istu sekciju postoji samo jedan `member_sections` red je dokumentovano
* Pravila za istoriju dodavanja, deaktivacije i reaktivacije clana u sekciji kroz `member_section_history` su dokumentovana
* Pravilo da se UR prava odredjuju kroz aktivan `section_role_assignments` zapis, a ne kroz globalnu funkciju, je dokumentovano
* Kljucne tabele za clanove, funkcije, sekcije, staratelje i onboarding potvrdjene su u aktivnoj Supabase bazi
* `member_status_history` postoji u aktivnoj Supabase bazi
* `society_member_functions` i `society_member_function_assignments` postoje u aktivnoj Supabase bazi
* `sections` i `member_sections` postoje u aktivnoj Supabase bazi
* SQL migracija za `section_role_assignments` je pripremljena u repozitorijumu
* SQL migracija za `member_section_history` je pripremljena u repozitorijumu
* `person_guardians` postoji u aktivnoj Supabase bazi
* `user_onboarding_state` postoji u aktivnoj Supabase bazi
* Početne funkcije i početne sekcije pri approval-u društva su dokumentovane
* Workflow promene predsednika je dokumentovan
* Supabase povezan
* Registracija društva radi
* `PresidentReg` koristi se za registracione zahteve
* `PresidentReg` ima `societyId` u aplikacionim tipovima i workflow-u
* Tabela `societies` postoji u aktivnoj bazi
* Approval workflow kreira društvo u `societies`
* Approval workflow upisuje `societyId` u `PresidentReg`
* Duplikati po PIB i matičnom broju rade
* Predsednik se ne kreira u `people`/`society_members` pri approval-u
* Lista Društva radi
* Lista Zahtevi na čekanju radi
* Lista Odobreni zahtevi radi
* Lista Odbijeni zahtevi radi
* `SocietyDataForm` izdvojena iz registracije
* `SocietyDataForm` koristi se na registraciji
* `SocietyDataForm` koristi se na `/drustva/[id]`
* `/drustva/[id]` koristi master mode
* `/drustva/[id]` ima SAČUVAJ i OTKAŽI
* Master admin upravljanje društvima preko `SocietyDataForm` završeno je u trenutnom V1 opsegu
* Registracija ima izbor licence
* Podrazumevana licenca je Free
* `taxId` refaktorisan u `pib` u frontend formi
* `npm.cmd run typecheck` prolazi
* `npm.cmd run build` prolazi
* `UF_MEMBER_FORM` funkcionalno podržava izbor sekcija, promene u `member_sections` i upis u `member_section_history`
* Modul `MOJE SEKCIJE` funkcionalno je implementiran u DEV/V1 opsegu
* `MOJE SEKCIJE` koristi kompaktan master-detail prikaz sa tabovima za članove, uloge i podešavanja
* `CLANOVI` koristi kompaktan tabelarni prikaz sa ugrađenom pretragom, lepljivim zaglavljem i sopstvenim skrolom liste
* `UF_MEMBER_FORM` koristi kompaktan prikaz u tri koraka: identifikacija, lični podaci i članstvo sa funkcijama i sekcijama
* V1 poslovna pravila za modul `PRISUSTVO`, automatsko vreme probe, trajno čuvanje otvorene evidencije, President/UR prava i audit trag dokumentovana su 2026-07-16
* V1 stranica `PRISUSTVO` i repo SQL model sa kontrolisanim upisima i audit tragom implementirani su 2026-07-16
* `PRISUSTVO` ima odvojene prikaze za trenutnu evidenciju i operativni pregled održanih/otkazanih proba
* Predsednik u pregledu proba može izvršiti auditovanu ispravku zatvorene probe, dok UR ima samo pregled svojih sekcija
* SQL migracija za trajanje probe po sekciji i serversko automatsko zatvaranje primenjena je u aktivnoj Supabase bazi 2026-07-20
* `MOJE SEKCIJE` podržava predsedničko podešavanje trajanja probe od 30 do 240 minuta
* `PRISUSTVO` prikazuje planirani kraj i rok automatskog zatvaranja, a pregled proba razlikuje ručno i automatsko zatvaranje
* SQL migracija `people-passport-expiry-setup.sql` primenjena je u aktivnoj Supabase bazi 2026-07-20
* `UF_MEMBER_FORM` podržava datum važenja pasoša, uparenu validaciju sa brojem pasoša i upozorenje za istekao dokument
* SQL migracija `events-v1-setup.sql` primenjena je u aktivnoj Supabase bazi 2026-07-20
* Modul `DOGAĐAJI` podržava nacrte, President/UR tok odobravanja, sekcije, članove, goste, statuse učesnika, nastupe, numere i izvođače
* Centralni repertoar sekcija implementiran je u modulu `MOJE SEKCIJE`; predsednik ga uređuje, a UR samo uz posebno odobrenje
* Navigaciona stavka `KONCERTI` preimenovana je u `DOGAĐAJI`

## U Toku

* Poslovna pravila Finansija V1 za članarine, kotizacije, uplate, kredite, povraćaje, email potvrde, Gmail povezivanje, opomene i audit objedinjena su u `docs/FINANCE_V1.md` 2026-07-22.
* Finansije V1 namerno ne obuhvataju izveštaje, početna stanja, konverziju valuta, formalne rate ni nepotrebne bankarske detalje.
* SQL model Finansija V1 iz `supabase/finance-v1-tables-setup.sql`, uključujući 14 novih tabela, ograničenja, indekse, zatvoren RLS pristup i zaštitu od fizičkog brisanja, uspešno je primenjen u aktivnoj Supabase bazi 2026-07-22.
* Kontrolisane finansijske RPC funkcije, finalna role-based read pravila i automatski mesečni obračun slede nakon provere aktivnih tabela.
* Kontrolisane funkcije iz `finance-v1-membership-workflows.sql` za finansijska ovlašćenja, podešavanja članarine, gratis mesece i idempotentan mesečni obračun uspešno su primenjene u aktivnoj Supabase bazi 2026-07-22.
* Raspored iz `finance-v1-monthly-cron.sql` uspešno je primenjen u aktivnoj bazi 2026-07-22 kao cron zadatak ID `2`; mesečni obračun se automatski pokreće svakog prvog dana u 00:10 UTC.
* Migracija `finance-v1-payment-workflows.sql` za atomsku numeraciju, evidentiranje, raspodelu, kredit i predsedničko poništavanje uplata uspešno je primenjena u aktivnoj Supabase bazi 2026-07-22.
* Migracija `finance-v1-event-refund-workflows.sql` za kotizacije, otkazivanje, kredit i povraćaje uspešno je primenjena u aktivnoj Supabase bazi 2026-07-22.
* Modul `DOGAĐAJI` koristi finansijski kontrolisane RPC funkcije za status učesnika i otkazivanje događaja.
* Migracija `finance-v1-read-workflows.sql` za bezbednu pretragu i read-only finansijski profil člana ili porodice uspešno je primenjena u aktivnoj Supabase bazi 2026-07-22.
* Kartica `FINANSIJE` povezana je sa aktivnim finansijskim RPC tokovima: pretraga člana/roditelja, pregled otvorenih i dospelih obaveza, kredita i istorije uplata, kao i evidentiranje delimične ili pune uplate sa ručnim izborom obaveza.
* Funkcionalna provera kotizacija i otkazivanja završena je 2026-07-24: formiranje jedne kotizacije pri potvrdi, evidentiranje uplate, `PLANNED → DECLINED`, ponovno potvrđivanje bez duplog zaduženja, otkazivanje neplaćene i plaćene kotizacije, kreditiranje uplaćenog iznosa, otkazivanje celog događaja i otkazivanje pojedinačne sekcije.
* Potvrđeno je da član povezan sa više sekcija istog događaja ostaje potvrđen i zadržava jednu kotizaciju kada se otkaže samo jedna od njegovih sekcija.

* SQL migracija `people-parental-travel-consent-setup.sql` primenjena je u aktivnoj Supabase bazi 2026-07-21
* Osnovni font aplikacije promenjen je na `Nunito Sans`; težine dugmadi, oznaka i navigacije su ublažene
* Forma novog putnika koristi `UF_MEMBER_FORM` režim `person_create`, bez kreiranja članstva u društvu
* Forma novog putnika ima email autocomplete iz `people`, opciju maloletnog putnika i sklopiva putna dokumenta
* Maloletne osobe imaju evidenciju saglasnosti oba roditelja i datum njenog važenja
* Potvrda maloletnog putnika na inostranom putovanju blokira se kada saglasnost ne važi do povratka
* Razvoj članova i sekcija u privremenom DEV/V1 kontekstu, bez finalnog Auth/RLS modela
* Dokumentaciono usklađivanje stvarnog stanja i odloženih obaveza
* Funkcionalna provera trajanja probe po sekciji i serverskog automatskog zatvaranja u aktivnoj Supabase bazi
* Funkcionalna provera svih V1 tokova modula `DOGAĐAJI` sa realnim podacima u aktivnoj bazi

## Sledeće

* Dovršiti funkcionalnu proveru kartice `FINANSIJE` sa predsednikom ili blagajnikom povezanim sa stvarnim članstvom za preostale varijante koje nisu posebno potvrđene: uplata na račun i porodični pregled.
* Nastaviti razvoj postojećih DEV/V1 tokova članova i sekcija u okviru dokumentovanih granica
* Proći ručno kroz kompletan tok: UR nacrt → sekcije i putnici → slanje → odobrenje predsednika → program i izvođači
* Funkcionalno proveriti domaće i inostrano putovanje sa punoletnim i maloletnim putnikom, uključujući blokadu nevažeće roditeljske saglasnosti
* Nastaviti kompaktno vizuelno usklađivanje modula `DOGAĐAJI`, posebno modalnih formi i prikaza na manjim ekranima
* Primeniti `supabase/attendance-setup.sql` u aktivnoj Supabase bazi i funkcionalno proveriti V1 modul `PRISUSTVO`
* Zahtevi za izmenu podataka društva
* Zahtevi za promenu licence

## Privremeni DEV/V1 Kontekst

* Dok Supabase Auth i stvarni korisnički kontekst nisu uvedeni, ekrani `CLANOVI` i `MOJE SEKCIJE` privremeno koriste prvo aktivno društvo iz baze.
* `CLANOVI` privremeno koristi prava predsednika i prikazuje sve aktivne sekcije izabranog društva.
* Dokumentovana UR ograničenja u `UF_MEMBER_FORM` još nisu finalno implementirana. UR filtriranje kasnije mora koristiti aktivne zapise iz `section_role_assignments`.
* Test role i frontend ograničenja služe samo razvoju i ne predstavljaju bezbednosni model.

## Odloženo Za Narednu Arhitektonsku Fazu

* Supabase Auth, prvi login i onboarding predsednika povezan sa stvarnim Auth korisnikom
* Povezivanje korisnika sa `people`, članstvom i društvom
* Stvarni multi-society kontekst umesto izbora prvog aktivnog društva
* Finalna President/UR prava i filtriranje sekcija u `UF_MEMBER_FORM`
* Finalne RLS politike po društvu, korisniku i sekcijskoj ulozi
* Transakcijski/RPC approval workflow
* Kompletan inventar aktivne baze i usklađivanje repo SQL migracija
* Dopuna nedostajućih setup/migration fajlova i constraint-a
* Formalna migracija i eventualno uklanjanje legacy kolone `society_members.funkcija`

## Tehnički Dug

* Approval workflow nije transakcijski
* DEV RLS policy-je su privremeno rešenje
* Dokumentacija/repo migracije i aktivna Supabase baza moraju biti uskladjeni
* Proveriti da li svi SQL fajlovi/migracije postoje u repo-u za tabele koje vec postoje u aktivnoj bazi
* `getLicensePrice` je trenutno u `SocietyDataForm`
* Liste zahteva imaju duplirane fetch obrasce
* Proveriti i očistiti eventualne mojibake karaktere
* `supabase/president-reg-setup.sql` nema `societyId`, iako ga aplikacioni kod i DEV update policy koriste
* `society_members.start_date` je nullable u repo SQL-u, iako je poslovno obavezan
* Repo nema kompletne potvrđene migracije za sve tabele koje postoje u aktivnoj bazi
* Nisu svi dokumentovani unique/check constraint-i potvrđeni u repo SQL-u
* Nije potvrđeno da su `section_role_assignments` i `member_section_history` primenjene u aktivnoj bazi
# Aktuelni V1 status — 27.07.2026.

Supabase Auth V1, Master admin i predsednički tokovi su aktivni. Frontend više
ne koristi test uloge iz browser storage-a niti bira prvo aktivno društvo kao
identitet korisnika. Završna bezbednosna migracija je
`supabase/auth-v1-final-dev-cleanup.sql`; ona uklanja široke DEV mutation
politike, uvodi Auth select ograničenja i dodaje kontrolisano odbijanje zahteva
i izmenu društva. Stariji odeljci ovog dokumenta ostaju kao istorija razvoja.

Dodatna migracija `supabase/auth-v1-remaining-dev-policies-cleanup.sql`
uklanja preostalih 38 javnih DEV politika za lične podatke, članstva,
prisustvo, događaje i repertoar i zamenjuje ih Auth V1 pravilima ograničenim na
stvarno društvo prijavljenog korisnika. Produkcioni Next.js build je uspešno
prošao 27.07.2026. za svih 25 aktivnih ruta; privremena testna ruta je
uklonjena, kao i mrežna zavisnost builda od Google fonta.

Funkcionalna provera prijavljene aplikacije potvrđena je nakon primene novih
politika: svi glavni ekrani učitavaju podatke. Stari direktni tok odobravanja i
nepozvani pomoćni upisi članova fizički su uklonjeni iz frontenda. Završna
statička provera više ne nalazi direktne `insert`, `update`, `delete` ili
`upsert` pozive u aplikacionim ekranima; sve poslovne promene prolaze kroz
kontrolisane Auth V1 RPC funkcije. Produkcioni build je zatim ponovo uspešno
završen za svih 25 ruta.

## Gmail OAuth status — 29.07.2026.

Predsedničko povezivanje Gmail naloga je implementirano i potvrđeno u lokalnoj
aplikaciji. Svako društvo ima najviše jednu vezu, samo predsednik može da je
poveže, zameni ili odjavi, a Google tokeni čuvaju se šifrovano. Migracija
`supabase/gmail-v1-society-connection.sql` primenjena je na aktivnu bazu i
dijagnostika je uspešno prošla.

U Google Cloud projektu `folkloras` uključen je Gmail API i napravljen OAuth
Web application klijent za `http://localhost:3000`. Lokalni callback je
`http://localhost:3000/api/gmail/callback`, a stvarno povezivanje testnog
naloga uspešno je završeno. OAuth tajne postoje samo u `.env.local` i nisu deo
repo-a.

Ovo je trenutno OAuth osnova, ne kompletan email kanal. Sledeće treba
implementirati serversko osvežavanje Google tokena i `users.messages.send`,
pouzdani email outbox, šablone i vezu sa konkretnim obaveštenjima članovima.
Produkcija dodatno zahteva javni HTTPS domen, produkcijski callback i
environment variables hostinga, Google podatke o aplikaciji i verifikaciju
`gmail.send` dozvole. Potpuna tačka nastavka je `docs/GMAIL_OAUTH.md`.
