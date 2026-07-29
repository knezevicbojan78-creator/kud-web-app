# Funkcionalni test ciklus — 29.07.2026.

Plan: `docs/FUNCTIONAL_TEST_MASTER_PLAN.md`

Status ciklusa: `U TOKU`

## Rezultati

### 1. Automatska tehnička provera

Status: `PROŠAO`

* struktura projekta: prošla;
* evidencija šest migracija: prošla;
* TypeScript: prošao;
* produkcioni build svih ruta: prošao;
* javna prijava: prošla;
* zaštita prijavljene rute: prošla;
* javna dopuna bez aplikacionog menija: prošla.

### 4. Članovi — povezivanje maloletnika i roditelja

Status: `PROŠAO POSLE ISPRAVKE`

Pronađeni nedostatak: roditeljski email mogao je da se unese neposredno pored
dugmeta za poziv, bez prethodne sačuvane veze.

Potvrđeno posle ispravke:

* čuvanje maloletnika bez roditelja je odbijeno;
* postojeći roditelj pronađen je po emailu;
* ime, prezime, email i telefon roditelja učitani su iz `people`;
* veza je sačuvana u zajedničkom nacrtu;
* oba poziva otključana su tek posle čuvanja veze;
* javni roditeljski obrazac učitao je tačne podatke;
* email deteta i roditelja zaključani su u javnom obrascu;
* bazna zaštita je primenjena migracijom
  `members-v1-require-guardian-link-before-invitation.sql`.

Probni podaci i svi ID-jevi evidentirani su u
`docs/PRE_RELEASE_CLEANUP_CHECKLIST.md`.

### 2. Prijava i aplikacioni okvir

Status: `DELIMIČNO PROŠAO`

* prijavljena predsednička sesija otvara zaštićene stranice;
* prikazani su tačno društvo i uloga `Predsednik`;
* osvežavanje dashboarda nije izgubilo sesiju;
* neprijavljeni pristup zaštićenoj ruti potvrđen je automatskim testom;
* nepostojeći javni token prikazuje samo poruku `Link nije vazeci.` bez glavnog
  menija ili mogućnosti odlaska na zaštićene stranice;
* ručna odjava i ponovna prijava nisu ponavljane jer bi zahtevale korisnikovu
  lozinku; automatska zaštita od povratka bez sesije prolazi.

### 3. Dashboard predsednika

Status: `PROŠAO`

* dashboard prikazuje 3 aktivna člana i 5 aktivnih sekcija;
* nezavisna read-only SQL provera baze vratila je iste brojeve;
* naziv društva, uloga, paket `Malo društvo` i važenje licence učitani su bez
  greške.

### 7. Funkcije i dozvole

Status: `U TOKU`

* ekran je dostupan samo u predsedničkom kontekstu;
* katalog sadrži 69 prava;
* svih 69 predsedničkih polja je zaključano za ručnu promenu;
* 68 predsedničkih prava je uključeno;
* jedino `members.request_change` nije uključeno, što odgovara modelu: to je
  zahtev člana/roditelja za izmenu, dok predsednik podatke menja direktno.

### 8. Događaji

Status: `U TOKU — TRI GREŠKE ISPRAVLJENE`

Potvrđeno:

* kreiran je jasno označen probni događaj;
* događaj je odobren i ostao dostupan posle ponovnog učitavanja;
* početna sekcija je trajno sačuvana;
* druga sekcija je dodata, a obe veze su potvrđene direktnim čitanjem baze;
* postojeća probna osoba pronađena je po emailu i dodata kao učesnik;
* status učesnika promenjen je iz `PLANNED` u `CONFIRMED`.
* probna sekcija i njena repertoarska numera povezane su sa programom;
* postojeći termin `Glavni nastup`, numera i izvođač ostali su sačuvani posle
  ponovnog učitavanja;
* osoba koja je ranije bila dodata kao gost uspešno je prepoznata kao aktivni
  član sekcije bez dupliranja osobe ili učesnika;
* posebno odobreno probno dešavanje uspešno je otkazano uz obavezan razlog;
* inostrano putovanje odbija potvrdu bez polaska i povratka;
* posle postavljanja termina odrasli putnik bez kompletnih dokumenata je
  odbijen;
* maloletni putnik sa dokumentima, ali bez saglasnosti, odbijen je jasnom
  porukom;
* nakon evidentirane važeće saglasnosti maloletni putnik je potvrđen;
* status drugog putnika uspešno je promenjen iz `PLANNED` u `DECLINED`.
* uvedene su precizne poruke za svako nedostajuće putno polje umesto opšte
  poruke o nekompletnoj dokumentaciji;
* pasoš sada mora važiti najmanje tri meseca od datuma polaska i svakako do
  povratka;
* za polazak 15.08.2026. probni rok pasoša 31.10.2026. pravilno je odbijen uz
  poruku da pasoš mora važiti najmanje do 15.11.2026;
* nakon vraćanja probnog roka pasoša na 31.12.2030. potvrda putnika je prošla.

Pronađena i ispravljena greška: novi sistem dozvola je starijoj proveri slao
opšti naziv `Ovlašćeni korisnik`, zbog čega je promena statusa bila odbijena i
predsedniku. Primenjena je migracija
`finance-v1-event-participant-actor-role.sql`; ponovljeni test je prošao.

Druga ispravljena greška: postojeća osoba dodata kao gost nije mogla kasnije da
bude izabrana kao izvođač svoje aktivne sekcije. Migracija
`events-v1-promote-member-participant.sql` dopunjava isti zapis učesnika
članstvom pre povezivanja sa sekcijom; ponovljeni test je prošao.

Treća ispravljena greška: bezbedni finansijski tok otkazivanja prosleđivao je
starijoj funkciji opštu oznaku `Ovlašćeni korisnik`, dok je ona prihvatala samo
`Predsednik` ili `UR`. Migracija
`events-v1-resolve-authorized-cancel-role.sql` razrešava stvarnu ulogu i čuva je
u istoriji; ponovljeni test je prošao.

Naknadna poslovna dopuna primenjena je migracijom
`events-v1-detailed-travel-document-validation.sql`. Poruke sada posebno
razlikuju nedostajuće lične podatke, adresu, kontakt, broj pasoša, državu
izdavanja, datum važenja, nedovoljno trajanje pasoša i roditeljsku saglasnost.

Polja datuma i vremena su naknadno proverena kroz stvarni obrazac za izmenu.
Test je otkrio da se vreme iz baze u obrascu prikazivalo dva sata ranije zbog
direktnog korišćenja UTC vrednosti. Prikaz je ispravljen tako da obrazac koristi
lokalni datum i vreme, a datum je usklađen sa formatom `dd.mm.yyyy`. Ponovno
čuvanje polaska 15.08.2026. u 18:00 i povratka 17.08.2026. u 21:00 više ne
pomera vremena, a sekcije i učesnici ostaju sačuvani.

Odbijanje celog događaja ostaje blokirano bez zasebne prijavljene UR sesije:
predsednik događaj kreira neposredno kao `APPROVED`, pa u njegovom toku ne
postoji stanje `PENDING` koje bi mogao da odbije.

Završna regresija posle tri ispravke je prošla:

* struktura projekta: 191 fajl;
* evidencija baze: 10 ispravnih zapisa migracija;
* TypeScript: prošao;
* produkcioni build svih 26 ruta: prošao;
* sva 3 javna automatska testa: prošla.

### 5. Sekcije

Status: `U TOKU`

Potvrđeno:

* kreiranje sekcije `CODEX E2E sekcija`;
* trajanje probe `1 h 15 min`;
* dodavanje postojećeg probnog člana;
* tačan zbir jednog aktivnog člana;
* dodavanje repertoarske numere `CODEX E2E numera`, tip koreografija i trajanje
  sedam minuta;
* svi ID-jevi su nezavisno potvrđeni u bazi i upisani u listu čišćenja.
* naziv sekcije je uspešno izmenjen u `CODEX E2E sekcija izmenjena`;
* sekcija je deaktivirana i ponovo aktivirana uz očuvanu istoriju;
* deaktiviran član sekcije ponovo je dodat, čime je reaktiviran isti zapis;
* direktna provera baze potvrđuje tačno jedan red članstva, isti ID i status
  `ACTIVE`, bez duplikata.

### 9. Finansije

Status: `DELIMIČNO PROŠAO — PREOSTALE VARIJANTE UPLATE I PORODICE PROŠLE`

* pretraga i finansijski profil probnog člana rade;
* početno stanje je tačno: 0 otvorenih obaveza, 0 dospelih i 0 kredita;
* postojeća stranica omogućava evidentiranje uplate samo kada otvorena obaveza
  već postoji;
* na stranici ne postoji komanda za ručno formiranje članarine, jer se redovni
  obračun izvršava automatski; za pripremu testa zato je korišćen zaseban,
  idempotentan DEV fajl ograničen na tačnu probnu email adresu;
* napravljeno je kontrolisano probno zaduženje od 100 RSD isključivo za
  `codex.e2e.member.001@example.com`, bez menjanja stvarnih članova;
* zaduženje je u aplikaciji pravilno prikazano kao otvoreno i dospelo;
* uplata na račun od 100 RSD uspešno je evidentirana kroz stvarni ekran i dobila
  broj `UPL-2026-000001`;
* posle uplate profil prikazuje nula otvorenih i dospelih obaveza, a istorija
  prikazuje način `Uplata na račun`;
* direktna read-only provera baze potvrđuje status obaveze `PAID`, iznos 100 RSD
  i način `BANK_TRANSFER`;
* porodični profil probnog roditelja uspešno se učitava, prikazuje povezano dete
  `Test Maloletni Član` i tačno stanje nula otvorenih obaveza, dospelih obaveza
  i kredita.
