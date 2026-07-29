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
