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

Status: `U TOKU — JEDNA GREŠKA ISPRAVLJENA`

Potvrđeno:

* kreiran je jasno označen probni događaj;
* događaj je odobren i ostao dostupan posle ponovnog učitavanja;
* početna sekcija je trajno sačuvana;
* druga sekcija je dodata, a obe veze su potvrđene direktnim čitanjem baze;
* postojeća probna osoba pronađena je po emailu i dodata kao učesnik;
* status učesnika promenjen je iz `PLANNED` u `CONFIRMED`.

Pronađena i ispravljena greška: novi sistem dozvola je starijoj proveri slao
opšti naziv `Ovlašćeni korisnik`, zbog čega je promena statusa bila odbijena i
predsedniku. Primenjena je migracija
`finance-v1-event-participant-actor-role.sql`; ponovljeni test je prošao.

Polja datuma još nisu ocenjena: automatski pregledač ne uspeva da unese vrednost
u sistemsko polje tipa datum, pa taj korak ostaje za kratku ručnu proveru.

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

Status: `DELIMIČNO PROŠAO — BLOKIRAN NEDOVRŠENIM TOKOM`

* pretraga i finansijski profil probnog člana rade;
* početno stanje je tačno: 0 otvorenih obaveza, 0 dospelih i 0 kredita;
* postojeća stranica omogućava evidentiranje uplate samo kada otvorena obaveza
  već postoji;
* na stranici trenutno ne postoji komanda za formiranje članarine ili drugog
  probnog zaduženja, pa ostatak finansijskog scenarija nije izvršen direktnim
  upisom u bazu koji bi zaobišao aplikaciju.
