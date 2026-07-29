# Funkcionalni test ciklus — 29.07.2026.

Plan: `docs/FUNCTIONAL_TEST_MASTER_PLAN.md`

Status ciklusa: `U TOKU`

## Rezultati

### 12. Moji podaci

Status: `PROŠAO U PREDSEDNIČKOM KONTEKSTU`

* stranica učitava profil prijavljenog korisnika bez izbora osobe;
* kompaktno zaglavlje, četiri statusne kartice i pet tabova koriste postojeći
  vizuelni sistem aplikacije;
* lični podaci, dokumenta, članstvo, funkcije i porodica prikazuju se u odvojenim
  kratkim celinama;
* režim izmene se otvara tek na zahtev, email je zaključan, a društveni podaci i
  saglasnost su samo za čitanje;
* forma koristi vrednosti `Muško` i `Žensko` i datum u standardnom biraču;
* pasoš i datum važenja moraju biti uneti zajedno;
* čuvanje nepromenjenog profila uspešno je prošlo bez promene stvarnih podataka;
* bezbedna funkcija dozvoljava samo izmenu sopstvenog profila i nema anonimno
  pravo poziva;
* audit čuva samo nazive promenjenih polja, bez kopiranja osetljivih vrednosti;
* tab za lozinku nudi postojeći bezbedni email tok, ali poruka nije slata tokom
  testa.

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

Status: `PROŠAO U PREDSEDNIČKOM KONTEKSTU`

* ekran je dostupan samo u predsedničkom kontekstu;
* katalog sadrži 69 prava;
* svih 69 predsedničkih polja je zaključano za ručnu promenu;
* 68 predsedničkih prava je uključeno;
* jedino `members.request_change` nije uključeno, što odgovara modelu: to je
  zahtev člana/roditelja za izmenu, dok predsednik podatke menja direktno.
* pravilo funkcije `Sekretar` za detaljni audit prisustva kontrolisano je
  uključeno, sačuvano i potvrđeno posle ponovnog učitavanja;
* isto pravilo je zatim vraćeno na početno isključeno stanje i vraćanje je
  potvrđeno posle ponovnog učitavanja;
* matrica svih funkcija učitava tačno 69 kataloških prava, odnosno 68 za
  funkcije kojima zahtev člana nije primenljiv;
* potvrđena početna matrica uključenih obaveznih prava:
  `Sekretar` 15, `Blagajnik` 6, `Upravnik` 15, `UR` 23,
  `Korepetitor` 1 i `Član` 14;
* sva navedena obavezna prava su zaključana, dok opciona isključena polja ostaju
  dostupna za promenu;
* pojedinačni izuzeci prijavljenog predsednika prikazani su kao `Nasleđeno` i
  sva polja su zaključana, pa predsednička prava nije moguće oslabiti ni tim
  putem;
* na širini ekrana od 390 px nema horizontalnog prelivanja; matrica prelazi u
  jednu kolonu, a širina sadržaja ostaje unutar ekrana.

Za konačnu proveru stvarnog menija i zabrana po funkciji biće potrebna zasebna
prijavljena sesija korisnika koji nije predsednik. Predsednička konfiguracija,
čuvanje, vraćanje, zaključana prava i mobilni prikaz ovim ciklusom su prošli.

### 8. Događaji

Status: `PROŠAO U PREDSEDNIČKOM KONTEKSTU — TRI GREŠKE ISPRAVLJENE`

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
* jedna sekcija odobrenog događaja otkazana je uz obavezan razlog;
* otkazivanje nije uklonilo učesnika niti finansijsku obavezu koja ne pripada
  isključivo toj sekciji;
* uklonjena sekcija je zatim ponovo dodata kroz aplikaciju, uz automatsko
  formiranje planiranog spiska;
* finansijski audit čuva tačan razlog otkazivanja i ID uklonjene veze;
* direktna provera baze potvrđuje nula pogrešnih veza sekcija i učesnika sa
  drugim društvom.

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

* struktura projekta: 193 fajla;
* evidencija baze: 11 ispravnih zapisa migracija;
* TypeScript: prošao;
* produkcioni build svih 26 ruta: prošao;
* sva 3 javna automatska testa: prošla.

### 5. Sekcije

Status: `DELIMIČNO PROŠAO — PREOSTALA IZMENA NUMERE I POSEBNA UR SESIJA`

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
* uklanjanje i ponovno dodavanje probnog člana ponovljeno je kroz stvarni ekran;
  ponovno učitavanje i baza potvrđuju jedan aktivan zapis bez duplikata;
* probni član bez funkcije `UR` nije ponuđen kao kandidat za umetničkog
  rukovodioca;
* važeći kandidat `Bojan Knežević` uspešno je dodeljen probnoj sekciji, pravo
  upravljanja repertoarom uključeno i isključeno, a dodela zatim uklonjena;
* postojeća probna osoba uspešno je dodeljena kao korepetitor, uključivanje i
  isključivanje evidencije prisustva rade, a dodela je zatim deaktivirana;
* test je otkrio da aktivna verzija `auth_get_section_detail` nije čitala
  `section_accompanists`, iako je ispravna verzija već postojala u projektu;
* `supabase/auth-v1-sections-detail-read.sql` ponovo je primenjen na aktivnu
  bazu; nakon toga se korepetitor pravilno prikazuje i može ukloniti kroz UI;
* roditeljski kontakt maloletnog člana u `Dečijem ansamblu` označen je kao
  dostupan u detalju člana, u skladu sa predsedničkim pravima;
* repertoarska numera je deaktivirana, stanje je potvrđeno posle ponovnog
  učitavanja i zatim je vraćena u status `ACTIVE`;
* završna provera baze za probnu sekciju potvrđuje: 1 aktivan član, 0 aktivnih
  sekcijskih uloga, 0 aktivnih korepetitora i 1 aktivna numera.

Preostalo:

* ekran još nema komandu za izmenu podataka postojeće repertoarske numere;
* pravo UR-a samo nad dodeljenom sekcijom i zabrana druge sekcije zahtevaju
  zasebnu prijavljenu UR sesiju.

### 6. Prisustvo

Status: `PROŠAO U PREDSEDNIČKOM KONTEKSTU`

Ranije potvrđeno:

* otvaranje probe za `Dečiji ansambl` sa jednim aktivnim maloletnim članom;
* početno stanje `ODSUTAN`, promena u `PRISUTAN` i automatsko čuvanje;
* ručno zatvaranje i pregled održane probe sa jednim prisutnim;
* dve naknadne predsedničke ispravke zatvorene probe sa obaveznim razlozima;
* audit sadrži staru i novu vrednost, razlog, status `CLOSED` i ulogu
  `Predsednik`;
* članstvo u sekciji je deaktivirano i reaktivirano bez gubitka istorijske
  evidencije.

Dopunski test:

* nova proba probne sekcije otvorena je sa jednim članom koji je početno
  `ODSUTAN`;
* član je promenjen u `PRISUTAN`, a ekran je potvrdio da su sve promene
  automatski sačuvane;
* dok je proba otvorena, izbor sekcije i ponovno otvaranje probe nisu dostupni;
  baza dodatno ima jedinstvenu zaštitu jedne otvorene probe po sekciji;
* posle ponovnog učitavanja i izbora iste sekcije otvorena proba, vreme i stanje
  `PRISUTAN` ostali su sačuvani;
* proba je kontrolisano otkazana, ostala je u istoriji kao `OTKAZANA` i njen
  detalj je samo za čitanje;
* ista probna osoba je zatim privremeno dodeljena kao korepetitor sa uključenom
  evidencijom prisustva;
* na drugoj probnoj probi prikazana je tačno jednom, sa oznakom `Korepetitor`,
  čime je potvrđena zaštita od dupliranja člana i korepetitora;
* druga proba je otkazana, a korepetitorska dodela ponovo deaktivirana;
* direktna provera baze potvrđuje po jedan zapis prisustva u obe probe:
  `PRESENT` bez posebne uloge i `ABSENT` sa ulogom `Korepetitor`;
* završno stanje nema otvorenu probu za probnu sekciju.

Preostala je provera prava prijavljenog UR-a samo u njegovoj dodeljenoj sekciji,
što zahteva zasebnu UR sesiju.

### 10. Master admin i predsednički zahtevi

Status: `PROŠAO U MASTER ADMIN KONTEKSTU — ONBOARDING ČEKA STVARNI EMAIL`

Potvrđeno:

* javni obrazac prikazuje sva obavezna polja, izbor vrste licence, izbor paketa
  i potvrdu tačnosti podataka;
* slanje praznog obrasca daje jasne poruke za sva obavezna polja, paket i
  potvrdu;
* jasno označen probni zahtev za mesečni paket `Malo društvo` uspešno je poslat;
* zahtev je nezavisnim čitanjem baze potvrđen sa statusom `PENDING`;
* predsednička sesija ne može da čita Master admin listu — pristup je pravilno
  blokiran RLS pravilom baze;
* Master admin dashboard, liste zahteva na čekanju, odobrenih i odbijenih
  zahteva učitavaju se ispravno;
* pretraga zahteva radi, a detalj prikazuje društvo, predsednika, paket i uslove;
* prvi test je otkrio da je odbijanje prolazilo bez razloga;
* ekran je dopunjen dijalogom sa obaveznim razlogom, a baza kolonama za razlog i
  vreme odbijanja i Master admin auditom;
* prazan razlog je posle ispravke blokiran, a ponovljeni zahtev odbijen je tek
  posle unosa razloga;
* drugi probni zahtev odobren je za godišnji paket `Malo društvo`, prenos na
  račun i jasno označenu probnu referencu;
* probno društvo je napravljeno sa statusom `ONBOARDING`, bez članova, sekcija i
  aktivnog licencnog perioda;
* lista i detalj su ispravljeni da `ONBOARDING` prikazuju kao `ČEKA ONBOARDING`,
  a ručna aktivacija nije dostupna pre završetka onboardinga;
* povezani zahtev i audit odobravanja vidljivi su u detalju društva;
* probno i postojeće društvo imaju različite ID-jeve, PIB, matične brojeve i
  odvojene članove, sekcije i licence.

Preostalo:

* aktivacioni email, postavljanje lozinke i predsednički onboarding zahtevaju
  adresu koja stvarno prima email; bezbedna probna adresa `example.com` je
  očekivano odbijena pri slanju;
* zbog toga društvo namerno ostaje u statusu `ONBOARDING`, a godišnji licencni
  period još nije počeo.

Završna regresija Master admin izmene je prošla: 195 projektnih fajlova, 12
evidentiranih migracija, TypeScript, produkcioni build svih 26 ruta i sva 3
javna automatska testa.

### 9. Finansije

Status: `PROŠAO — KOMPLETNO TESTIRANJE MODULA ZAVRŠENO`

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
* stranica sada omogućava poništavanje evidentirane uplate uz obavezan razlog;
* poništavanjem `UPL-2026-000001` uplata je ostala u istoriji kao `PONIŠTENA`,
  a dug od 100 RSD se ponovo otvorio;
* nova gotovinska uplata `UPL-2026-000002` od 150 RSD zatvorila je dug od
  100 RSD i napravila kredit od 50 RSD;
* povraćaj kredita na račun `POV-2026-000001` od 50 RSD uspešno je evidentiran,
  smanjio kredit na nulu i prikazan je u novoj istoriji povraćaja;
* poništavanje tog povraćaja uz obavezan razlog promenilo je status u
  `PONIŠTEN` i vratilo kredit od 50 RSD;
* read-only provera baze potvrdila je oba statusa `VOIDED`, aktivnu uplatu
  `POSTED`, sve iznose, načine plaćanja i razloge.
* promena opšteg kalendara članarine je sačuvana, proverena i vraćena na početno
  stanje: jul i avgust se ne obračunavaju, ostali meseci se obračunavaju;
* probni član je kroz stvarni ekran uspešno promenjen iz režima `STANDARD` u
  `CUSTOM` sa 2.500 RSD, zatim u `EXEMPT`, pa vraćen u `STANDARD`;
* završno podešavanje ostalo je 3.000 RSD i standardni režim probnog člana;
* drugo kontrolisano zaduženje
  `CODEX E2E test korišćenja kredita 08/2026` od 100 RSD zatvoreno je kombinacijom
  nove gotovinske uplate od 50 RSD i postojećeg kredita od 50 RSD;
* potvrda `UPL-2026-000003` ima status `POSTED`, obaveza je `PAID`, a konačni
  raspoloživi kredit probnog člana je 0 RSD;
* finansijski audit sadrži 11 zapisa za probnog člana;
* pokušaj fizičkog brisanja tačno određene probne uplate blokiran je očekivanom
  porukom baze `Finansijski zapisi se ne brisu fizicki.`;
* pregled pravila za manje ekrane potvrđuje slaganje polja u jednu kolonu, a
  zaglavlja, dugmad i komande istorije dodatno su prilagođeni da se ne preklapaju;
* u poruci o uspešnom čuvanju podešavanja uklonjena je dupla tačka posle datuma.

### 13. Garderoba — početna funkcionalna faza

Status: `PROŠAO — OSNOVA MODULA`

* migracija je primenjena na aktivnu bazu;
* potvrđeno je 14 novih tabela sa uključenim RLS pravilima;
* prijavljeni korisnik može da pozove radni pregled, anonimni korisnik ne može;
* početnih 12 kategorija prikazano je u aplikaciji;
* kartice pregleda, tabovi, pretraga i filteri pravilno se prikazuju;
* otvoreni su obrasci za novu stavku inventara i broj obuće, bez čuvanja
  probnih poslovnih podataka;
* broj obuće pravilno se prikazuje u obrascu `Moji podaci`;
* sledeća funkcionalna provera radi se nakon unosa prvih stvarnih kategorija,
  stavki i kompleta.

### 14. Garderoba — upravljanje i posebni slučajevi

Status: `PROŠAO — STRUKTURA I PRAZNA STANJA`

* operativna migracija primenjena je na aktivnu bazu;
* potvrđeno je postojanje svih funkcija za uređivanje, popravke, gubitke i
  primopredaju kofera;
* prijavljeni korisnik ima izvršno pravo, anonimni korisnik nema;
* stranica pravilno učitava prazan pregled popravki i gubitaka;
* postojeće kategorije prikazuju komandu za uređivanje;
* obrazac kompleta podržava zasebnu količinu svakog izabranog dela;
* potpuna poslovna provera zahteva stvarne stavke, komplet i kontrolisano
  zaduženje, pa nije unosila privremene podatke u ovoj fazi.

### 15. Garderoba — pozajmice i obaveštenja

Status: `PROŠAO — STRUKTURA, OVLAŠĆENJA I PRAZNA STANJA`

* migracija za pozajmice i obaveštenja primenjena je na aktivnu bazu;
* potvrđeno je postojanje tabele i svih funkcija za čitanje, kreiranje i
  promenu statusa pozajmice;
* prijavljeni korisnik ima izvršno pravo, anonimni korisnik nema;
* uvedena su obaveštenja za rokove, roditelje maloletnika, primopredaju kofera
  i dodelu popravke;
* nova kartica razlikuje garderobu koju je društvo izdalo i garderobu koju je
  primilo od drugog društva na platformi;
* forma podržava spoljnog primaoca ili izbor postojećeg društva, odgovornog
  člana, događaj, rok i više kompleta;
* potpuna poslovna provera toka sa dva društva radiće se kada postoje stvarni
  inventar i kompleti; u ovoj proveri nisu unoseni probni poslovni podaci.

### 16. Garderoba — centralne dozvole

Status: `PROŠAO — BAZA, PREDSEDNIČKI PRIKAZ I STRUKTURNA ZAŠTITA`

* centralni katalog sadrži tri aktivna prava Garderobe;
* predsednik ima zaključan pregled, upravljanje i detaljni audit;
* garderober ima zaključan pregled i operativno upravljanje bez detaljnog
  audita;
* funkcija ličnog pregleda postoji i dostupna je prijavljenom, ali ne i
  anonimnom korisniku;
* odgovor baze za člana ili roditelja uklanja inventar, komplete, druge
  članove, događaje i repertoar i vraća samo sopstvena ili dečja zaduženja;
* interfejs ima uslovni lični prikaz sa samo karticama `Pregled` i `Zaduženja`,
  bez komandi za izdavanje ili razduživanje;
* predsednički pregled je ponovo otvoren u lokalnoj aplikaciji i učitao je sve
  operativne kartice i podešavanja bez greške;
* zasebna prijava člana i roditelja još nije mogla biti izvršena jer postojeći
  centralni login trenutno pušta samo predsednika i Master admina; to je
  sledeća opšta Auth faza, a bazna ograničenja Garderobe su unapred pripremljena;
* nisu menjani niti dodavani poslovni podaci garderobe.
