# Glavni plan funkcionalnog testiranja

## Cilj i odobrenje

Ovaj plan omogućava da se postojeće funkcije aplikacije testiraju u jednom
kontinuiranom ciklusu. Kada vlasnik projekta napiše da odobrava ovaj plan,
odobrenje važi za sve dole navedene kontrolisane testove i njihove jasno
označene probne podatke. Nije potrebno tražiti novu poslovnu potvrdu pre svakog
pojedinačnog koraka.

Operativni sistem ili Codex i dalje mogu prikazati obavezan tehnički prozor za
dozvolu. Takav prozor nije ponovno traženje odluke o sadržaju testa.

Odobrenje ovog plana ne obuhvata:

* brisanje stvarnih podataka, korisnika ili društva;
* promenu stvarnih cena, licenci ili statusa društva bez sigurnog vraćanja;
* slanje poruka stvarnim osobama;
* objavljivanje aplikacije na internetu;
* pokretanje nedokumentovane migracije;
* završno brisanje svih test-podataka — ono ostaje poseban, potvrđen korak.

## Stranice koje se sada ne testiraju

`Garderoba`, `Izveštaji` i `Moji podaci` nisu funkcionalno izrađeni i izuzeti
su iz ovog ciklusa. Za njih se kasnije pravi poseban plan posle implementacije.

Stvarno slanje email poziva za dopunu podataka takođe se ne testira dok
aplikacija ne dobije javnu adresu i podešen email servis. Lokalni probni linkovi
ostaju važeća zamena za proveru celog obrasca.

## Pravila probnih podataka

Svi novi probni podaci moraju imati prepoznatljivu oznaku:

* email: `codex.e2e.<namena>.<broj>@example.com`;
* naziv ili napomena: prefiks `CODEX E2E`;
* razlog izmene: opis koji počinje sa `Kontrolisani test`;
* datum: stvarni datum testa, osim kada konkretan scenario zahteva drugi datum.

Za svaki upis odmah se dopunjava
`docs/PRE_RELEASE_CLEANUP_CHECKLIST.md`. Evidentiraju se:

1. poslovni naziv testa;
2. email ili druga jedinstvena oznaka;
3. ID glavnog zapisa kada je dostupan;
4. tabele i zavisni zapisi koji su nastali;
5. da li je podatak ostavljen, vraćen na početno stanje ili već uklonjen;
6. poseban redosled čišćenja ako postoje strani ključevi.

Ne koriste se stvarne email adrese novih test-osoba. Postojeći stvarni članovi,
sekcije, finansije i istorija ne menjaju se ako test može da se izvrši nad
probnom osobom.

## Redosled testiranja

### 1. Automatska tehnička provera — bez poslovnih upisa

* provera strukture projekta i evidencije migracija;
* TypeScript provera;
* produkcioni build;
* javna stranica prijave;
* vraćanje neprijavljenog korisnika sa zaštićene stranice;
* izolovanost javne dopune podataka od glavnog menija;
* osnovno otvaranje svih implementiranih ruta bez rušenja.

### 2. Prijava i aplikacioni okvir

* prijava predsednika i pravilno usmeravanje na njegov dashboard;
* osvežavanje stranice uz očuvanu sesiju;
* zaštita predsedničkih stranica od neprijavljenog korisnika;
* prikaz tačnog društva i uloge;
* odjava i zabrana povratka na zaštićenu stranicu;
* ponovna prijava;
* ponašanje nevažećeg i isteklog javnog linka;
* reset lozinke samo do granice koja ne zahteva stvarno slanje emaila.

### 3. Dashboard predsednika

* tačnost broja aktivnih članova, sekcija i relevantnih zbirnih podataka;
* promene zbirnih brojeva posle kontrolisanog dodavanja ili deaktiviranja;
* navigacija sa kartica na odgovarajuće postojeće module;
* prikaz na širokom i uskom ekranu.

### 4. Članovi i masovni unos

Već potvrđene scenarije treba ponoviti u završnom regresionom prolazu:

* ručno kreiranje punoletnog člana;
* provera obaveznih polja i formata datuma;
* sprečavanje duplog emaila, JMBG-a i pasoša;
* izmena osnovnih i osetljivih podataka;
* promena statusa člana uz istoriju;
* masovni unos sa minimalnim podacima;
* preskakanje duplikata iz `people`, aktivnih članova i kandidata;
* otkazivanje učitanog Excel fajla;
* kandidat bez datuma početka članstva;
* lokalni link člana i roditelja;
* automatsko čuvanje i nastavak nacrta;
* zaključavanje istovremenog uređivanja;
* prava deteta starijeg od 12 godina;
* predsednički pregled nedostajućih podataka;
* konačna aktivacija i opozivanje preostalih linkova;
* odbacivanje kandidata;
* postojeći roditelj se povezuje bez duplikata i dobija dopunjene podatke.

Novi članovi za ovaj ciklus, ako budu potrebni, koriste sledeće rezervisane
adrese:

* `codex.e2e.member.002@example.com`;
* `codex.e2e.minor.002@example.com`;
* `codex.e2e.guardian.002@example.com`.

### 5. Sekcije

* kreiranje jasno označene probne sekcije;
* izmena naziva i trajanja probe;
* deaktiviranje i ponovno aktiviranje sekcije;
* dodavanje člana;
* uklanjanje i ponovno dodavanje istog člana bez duplikata;
* dodela i uklanjanje umetničkog rukovodioca;
* odbijanje dodele UR-a osobi bez odgovarajuće aktivne funkcije;
* dodela i uklanjanje korepetitora;
* kontakt roditelja vidljiv samo tamo gde je dozvoljen;
* dodavanje repertoarske numere;
* izmena i deaktiviranje repertoarske numere;
* pravo UR-a nad dodeljenom sekcijom i zabrana pristupa drugoj sekciji.

Probna sekcija koristi naziv `CODEX E2E sekcija`. Ako postojeća sekcija može
bezbedno da posluži za scenario, novi zapis se ne pravi.

### 6. Prisustvo

* otvaranje probe sa svim aktivnim članovima sekcije;
* početno stanje odsutan;
* promena na prisutan i automatsko čuvanje;
* osvežavanje ili napuštanje stranice bez gubitka otvorene probe;
* zabrana druge istovremeno otvorene probe za istu sekciju;
* ručno zatvaranje;
* pregled održane probe i zbirnih brojeva;
* naknadna predsednička ispravka uz obavezan razlog;
* audit stare i nove vrednosti;
* kontrolisano otkazivanje probne probe;
* pregled otkazane probe;
* test prava UR-a samo u dodeljenoj sekciji;
* korepetitor se prikazuje u evidenciji kada je dodeljen;
* član koji je kasnije uklonjen iz sekcije ostaje u istorijskoj evidenciji.

### 7. Funkcije i dozvole

Za ove testove koriste se samo probni članovi:

* dodela i deaktiviranje funkcije;
* promena pravila cele funkcije uz obavezan razlog;
* pojedinačni `ALLOW`, `DENY` i povratak na `INHERIT`;
* predsednička zaključana prava ne mogu se ukinuti;
* prava više funkcija pravilno se sabiraju;
* promena jedne osobe ne utiče na drugu;
* član vidi samo dozvoljene podatke;
* roditelj vidi samo povezano dete;
* osetljivi podaci zahtevaju posebno pravo;
* sakriveno dugme i direktan nedozvoljeni poziv bazi daju isti bezbedan ishod;
* svaka promena postoji u auditu sa izvršiocem, razlogom i vremenom.

Ako test druge uloge zahteva prijavljivanje, pravi se zaseban probni Auth nalog
sa `codex.e2e` emailom i odmah se dodaje u spisak za čišćenje.

### 8. Događaji

Koristi se događaj `CODEX E2E događaj` i probni članovi:

* kreiranje i izmena nacrta događaja;
* dodavanje i uklanjanje sekcije;
* termini nastupa;
* program i repertoar;
* dodavanje učesnika i promena statusa;
* slanje na odobrenje;
* odobravanje;
* odbijanje posebnog probnog događaja uz razlog;
* otkazivanje posebnog probnog događaja uz razlog;
* otkazivanje sekcije događaja;
* provera istorije i audita svih promena;
* provera da događaj i učesnici pripadaju samo aktivnom društvu.

### 9. Finansije

Finansijski testovi koriste isključivo probnog punoletnog člana i jasno
označene test-transakcije:

* učitavanje finansijskog profila;
* standardna članarina i kalendar meseci naplate;
* formiranje jednog probnog zaduženja;
* delimična uplata;
* puna uplata;
* pravilno stanje duga i kredita;
* korišćenje kredita;
* poništavanje probne uplate uz razlog;
* probni povraćaj i poništavanje povraćaja;
* pojedinačni režimi `STANDARD`, `CUSTOM` i `EXEMPT`;
* vraćanje probnog člana na početni režim;
* audit svake finansijske promene;
* zabrana fizičkog brisanja finansijske istorije;
* proveravanje da stvarni članovi i njihove finansije nisu promenjeni.

Svaki iznos mora biti mali, očigledno probni i evidentiran u listi čišćenja.

### 10. Master admin i predsednički zahtevi

Ovaj deo se izvršava samo ako postojeća Master admin prijava i MFA mogu da se
koriste bez menjanja stvarnog naloga:

* liste zahteva na čekanju, odobrenih i odbijenih;
* detalj zahteva;
* javno slanje jednog jasno označenog probnog predsedničkog zahteva;
* odbijanje jednog probnog zahteva uz razlog;
* odobravanje drugog probnog zahteva samo ako lokalni aktivacioni tok može biti
  završen bez stvarnog emaila;
* izbor paketa i načina obračuna;
* nastavak i završetak probnog predsedničkog onboardinga;
* provera da društvo i licenca postaju aktivni tek posle onboardinga;
* pregled probnog društva, licence i audit istorije;
* provera odvojenosti probnog i postojećeg društva.

Ne menjaju se stvarne cene licenci. Suspenzija postojećeg stvarnog društva se
ne testira. Ako se napravi posebno probno društvo, ono i svi njegovi povezani
podaci odmah se upisuju u listu za završno čišćenje.

### 11. Responzivnost i regresija

Za svaku završenu stranicu iz ovog plana proveravaju se:

* široki desktop;
* uži tablet;
* mobilna širina;
* odsustvo horizontalnog odsecanja važnih kontrola;
* čitljivost modala, tabela i obrazaca;
* tastaturna navigacija kroz ključne forme;
* jasne poruke greške, uspeha, praznog stanja i učitavanja.

Na kraju se ponovo pokreću kompletna tehnička provera, build i automatski
testovi.

## Način izveštavanja

Tokom odobrenog ciklusa vodi se radni dnevnik sa statusima:

* `PROŠAO`;
* `GREŠKA — ZA ISPRAVKU`;
* `BLOKIRAN — NEDOSTAJE PREDUSLOV`;
* `NIJE PRIMENJIVO — FUNKCIJA NIJE IMPLEMENTIRANA`.

Kada se pronađe greška, prvo se beleže tačan scenario, očekivano i stvarno
ponašanje. Ispravka se implementira i ponavlja se samo relevantni test, pa
završna regresija. Bez dodatnog odobrenja mogu se praviti normalne lokalne
izmene koda i kontrolisane Supabase migracije potrebne da odobreni test prođe,
pod uslovom da ne prelaze granice ovog dokumenta.

Konačni izveštaj sadrži:

* broj prošlih, popravljenih, blokiranih i neprimenljivih testova;
* sve pronađene i ispravljene greške;
* kompletan registar preostalih probnih podataka;
* pripremljen, ali neizvršen plan njihovog bezbednog čišćenja.

## Status odobrenja

Plan je odobren 29.07.2026, nakon implementacije i funkcionalne potvrde
obaveznog povezivanja maloletnog kandidata sa već unetim roditeljem/starateljem
pre pravljenja poziva. Odobreni kontinuirani ciklus testiranja može da počne.
