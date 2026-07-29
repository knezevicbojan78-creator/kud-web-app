# Kontrolna lista čišćenja pre puštanja aplikacije u rad

Ovaj dokument je obavezna kontrolna lista pre prve produkcione probe i pre
uključivanja stvarnih korisnika. Čišćenje se ne pokreće unapred jer se probni
podaci još koriste za lokalno funkcionalno testiranje.

Svaki novi podatak nastao tokom odobrenog ciklusa iz
`docs/FUNCTIONAL_TEST_MASTER_PLAN.md` dopisuje se u ovu listu odmah nakon
nastanka, a ne tek na kraju testiranja.

## Poznati probni podaci koje trenutno zadržavamo

U aktivnoj Supabase bazi trenutno ostaju:

* `codex.e2e.member.001@example.com` — aktivni probni punoletni član
* `codex.e2e.minor.001@example.com` — aktivni probni maloletni član
* `codex.e2e.guardian.001@example.com` — probni roditelj/staratelj povezan sa
  maloletnim članom
* `codex.e2e.minor.002@example.com` — probni maloletni kandidat za test
  povezivanja roditelja; kandidat ID
  `ea9cba01-bab1-49a2-8259-b0d839d63924`
* `codex.e2e.guardian.002@example.com` — probni uvezeni roditelj; osoba ID
  `975a63d9-32fe-4477-83ef-81e259517d6a`

Za kandidata `minor.002` nastali su:

* zajednički nacrt `533c1db7-ad27-4d44-aadc-e25c032207c8`;
* roditeljski poziv `6ad69b4c-3be4-4b7f-96c9-8122090119fd`;
* članski poziv `5c1ec523-72b1-4e2b-80e8-b5d944070e3f`;
* izvorna oznaka `CODEX-E2E-POVEZIVANJE-RODITELJA.xlsx`.

Pri čišćenju se prvo uklanjaju oba poziva i nacrt, zatim kandidat, pa probna
osoba roditelja ako u međuvremenu nije povezana ni sa jednim drugim probnim
zapisom.

Probni maloletni član je 29.07.2026. dodat u sekciju `Dečiji ansambl`. Istog
dana je za tu sekciju napravljena i zatvorena kontrolisana proba sa jednim
prisustvom tog člana. I sekcijsko članstvo i cela povezana evidencija te probe
moraju biti obuhvaćeni završnim čišćenjem. Evidencija sadrži i dva audit zapisa
naknadne predsedničke ispravke zatvorene probe, sa obaveznim razlozima, koji se
takođe uklanjaju zajedno sa ovom probnom evidencijom.

Pre produkcije treba ukloniti njihove povezane zapise iz:

* poziva za dopunu podataka i opozvati sve njihove tokene
* sačuvanih nacrta javne dopune
* kandidata masovnog unosa
* veza dete–roditelj/staratelj
* dodeljenih funkcija i sekcija, ako budu korišćene u daljim testovima
* istorije statusa člana
* članstva u društvu
* tabele osoba `people`
* Supabase Auth korisnika, samo ako je za neku od ovih probnih adresa naknadno
  napravljen Auth nalog
* drugih poslovnih zapisa koji naknadno budu vezani za ove osobe: prisustvo,
  garderoba, događaji, finansije, obaveštenja i audit test-radnji

Brisanje mora biti jedna kontrolisana transakcija. Pre izvršavanja treba prvo
prikazati broj pronađenih zapisa po tabeli. Ako se pronađe neočekivana osoba,
email ili društvo, postupak se prekida bez promena.

## Završna provera cele baze

Neposredno pre produkcije treba:

1. pretražiti email adrese, imena i opise sa oznakama `codex.e2e`, `test`,
   `demo` i drugim oznakama korišćenim tokom razvoja;
2. proveriti da nema kandidata, aktivnih poziva ili napuštenih nacrta koji
   pripadaju probnim osobama;
3. proveriti da nema probnih finansijskih zaduženja, uplata, prisustava,
   garderobe, događaja, licenci i obaveštenja;
4. proveriti da svi preostali Auth korisnici imaju očekivanu osobu, članstvo i
   funkciju;
5. napraviti rezervnu kopiju baze pre čišćenja i sačuvati rezultat završne
   read-only dijagnostike posle čišćenja.

Stvarno društvo, predsednik, platformski Master admin, katalog dozvola,
licencni paketi, funkcije, triggeri, RLS pravila i istorija stvarnih poslovnih
promena ne smeju biti obrisani ovim postupkom.

## Razvojni fajlovi i alati

Automatski testovi, generatori probnih Excel fajlova i lokalni SQL alati mogu
ostati u privatnom repozitorijumu. Oni se ne izvršavaju nad produkcionom bazom.

Pre produkcije posebno treba potvrditi da:

* nijedna migracija označena kao `prepared` ili razvojna nije nenamerno
  primenjena;
* DEV SQL funkcije i privremena prava nisu dostupni produkcionim korisnicima;
* `.env.local`, probni Excel fajlovi, Playwright izveštaji i drugi lokalni
  artefakti nisu deo objavljene verzije;
* produkcione promenljive koriste produkcioni Supabase projekat, javnu adresu
  aplikacije i ograničene ključeve email servisa.

## Trenutni status

Čišćenje još nije izvršeno. Poznati probni podaci namerno ostaju u bazi dok se
ne završe naredna funkcionalna testiranja.

## Probni događaj iz ciklusa 29.07.2026.

Zadržan je događaj `CODEX E2E događaj`:

* događaj ID `1104573c-8835-467b-93ac-a5277e2ed128`;
* veza sa sekcijom `Dečiji ansambl` ID
  `09288c21-8d9f-4158-8099-64ba5698e61a`;
* privremeno dodata veza sa sekcijom `Narodni orkestar` ID
  `99f78894-3b58-4973-aece-7b0df5a45775`;
* veza sa probnom sekcijom ID
  `4d944809-e2bb-415c-b3ec-eed7d2c50e64`;
* učesnik ID `81512696-0f43-4a35-8101-e8798f4893c2`, povezan sa postojećom
  probnom osobom `codex.e2e.member.001@example.com`;
* status učesnika je tokom testa promenjen iz `PLANNED` u `CONFIRMED`;
* termin nastupa ID `3ae4078b-d010-44fe-86cb-5b74c1f9d29b`;
* programska veza numere ID `b55323d2-a1ec-474b-bb1d-b0c933b464b0`;
* veza izvođača ID `1e0eac2f-c958-4620-8969-4b7ec14b0925`;
* postoje i pripadajući zapisi istorije statusa i finansijskog audita.

Pri završnom čišćenju prvo ukloniti zavisne programske, učesničke, finansijske,
istorijske i audit zapise događaja, zatim veze događaj–sekcija, pa sam događaj.
Stvarne sekcije se ne brišu.

## Probna sekcija iz ciklusa 29.07.2026.

Zadržani su:

* sekcija `CODEX E2E sekcija izmenjena`, ID
  `b750e65f-bb1f-4aff-a131-f0e9db534e17`;
* članstvo probnog člana u sekciji, ID
  `de37fd1a-c886-4cd0-83f6-27e6154f8980`;
* repertoarska numera `CODEX E2E numera`, ID
  `129616b6-efe9-4edf-950e-8bd374104837`;
* pripadajuća veza numere i sekcije, kao i audit/istorijski zapisi.

Pri čišćenju najpre ukloniti zavisne uloge, članstva, probe, repertoarske veze i
audit zapise probne sekcije, zatim probnu numeru ako nije vezana ni za jednu
drugu sekciju, pa samu sekciju.

Sekcija je tokom testa deaktivirana i ponovo aktivirana. Isto članstvo je
reaktivirano bez pravljenja duplikata; u tabeli `member_sections` postoji tačno
jedan red sa gore navedenim ID-jem i statusom `ACTIVE`.

## Dodatni događaji iz ciklusa 29.07.2026.

* `CODEX E2E događaj za otkazivanje`, ID
  `196f4efc-a6c2-48bb-9957-1c6013ced60e`, status `CANCELLED`;
* njegova veza sa probnom sekcijom ID
  `fc91ffcf-43ac-43ae-8b9f-37f863df32f6`;
* njegov automatski termin koncerta ID
  `409bac28-52eb-40b2-bdbc-ed7d51c0e9b2`;
* `CODEX E2E inostrano putovanje`, ID
  `9e6dcad5-aa29-403a-a5f0-90ab1c7a0f87`, status `APPROVED`;
* njegova veza sa probnom sekcijom ID
  `f755719b-1e6d-447e-bce3-93f5dbc495e1`;
* odrasli putnik ID `240093c5-f1d7-4349-84e1-90a2d95d819c`,
  status `DECLINED`;
* maloletni putnik ID `934b24ca-287d-4f77-81a7-fa203b370b04`,
  status `CONFIRMED`.

Na probnom inostranom putovanju termini su zbog ograničenja automatizovanog
sistemskog birača postavljeni kontrolisano u bazi: polazak 15.08.2026. u 18:00,
povratak 17.08.2026. u 21:00 po lokalnom vremenu.

Za probnu osobu `codex.e2e.minor.001@example.com` tokom testa su dopunjeni
`nationality = Srpsko`, `passport_issuing_country = Srbija`,
`parental_travel_consent = true` i važenje saglasnosti do 20.08.2026. Ovi
podaci pripadaju probnoj osobi i uklanjaju se zajedno sa njom.

## Probni finansijski zapisi iz ciklusa 29.07.2026.

Za `codex.e2e.member.001@example.com` napravljeno je jedno kontrolisano
zaduženje `CODEX E2E test članarina 07/2026` od 100 RSD:

* obaveza ID `ff357ff4-a164-4bed-90c0-dbe4f53ce5ba`, status `PAID`;
* uplata ID `0744097f-5deb-4776-a074-b9aa3d5d083b`;
* broj potvrde `UPL-2026-000001`;
* način uplate `BANK_TRANSFER`, konačni status `VOIDED`;
* druga uplata ID `bd5f68db-5a5b-4525-a4e0-07e87f878cd5`;
* broj druge potvrde `UPL-2026-000002`, iznos 150 RSD, način `CASH`, status
  `POSTED`;
* poništen povraćaj ID `de70e97c-3d56-46ec-b08f-790f41711f26`;
* broj povraćaja `POV-2026-000001`, iznos 50 RSD, način `BANK_TRANSFER`, status
  `VOIDED`;
* dodatna obaveza `CODEX E2E test korišćenja kredita 08/2026`, ID
  `4f009257-6e4f-429e-97fb-3cae6c6911d2`, iznos 100 RSD, status `PAID`;
* treća uplata ID `72d8f232-cb44-442b-bb65-701b8ffd059c`, potvrda
  `UPL-2026-000003`, iznos 50 RSD, način `CASH`, status `POSTED`;
* ta uplata je zajedno sa postojećim kreditom od 50 RSD zatvorila dodatnu
  obavezu, pa je konačni raspoloživi kredit probnog člana 0 RSD;
* istorija podešavanja sadrži probne promene sa razlozima koji počinju sa
  `CODEX E2E`: privremeno uključivanje avgusta, njegovo vraćanje, kao i promene
  probnog člana `CUSTOM`, `EXEMPT` i povratak na `STANDARD`;
* završno stanje podešavanja je standardna članarina 3.000 RSD, bez obračuna za
  jul i avgust, a probni član je u režimu `STANDARD`;
* postoje i pripadajuća procena članarine, raspodela uplate, audit i eventualni
  brojački zapisi, kreditne stavke i reverzije.

Pri čišćenju ukloniti zavisne raspodele, povraćaje, kreditne stavke, audit i
procene članarine, zatim sve tri uplate i obe obaveze. Ukloniti i navedenu probnu
istoriju podešavanja prema tačnim `CODEX E2E` razlozima. Pre uklanjanja proveriti da svi
zapisi pripadaju isključivo navedenom probnom članu i navedenim test iznosima.
