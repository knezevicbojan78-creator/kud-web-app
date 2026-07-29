# Garderoba V1

## Cilj

Modul vodi količinsku evidenciju nošnji, obuće, kompleta, zaduženja, kofera,
pozajmica, gubitaka i popravki. Pojedinačni inventarski brojevi fizičkih komada
ostaju za kasniju fazu. Interna oznaka postoji na nivou stavke inventara.

Detaljno podešavanje dozvola po funkcijama i korisnicima radi se u narednoj
fazi. Model V1 već razdvaja čitanje, upravljanje inventarom, izdavanje,
razduživanje i rešavanje spornih situacija kako bi se dozvole kasnije dodale
bez promene poslovnih tabela.

## Osnovna pravila

* Odeća u V1 nema veličinu.
* Obuća se vodi po celom evropskom broju.
* `people.shoe_size` čuva broj obuće osobe i može biti prazan.
* Osoba, odnosno roditelj maloletnog člana, može dopuniti broj obuće.
* Garderoba se vodi za jedno skladište po društvu.
* Svaka stavka može pripadati većem broju koreografija ili igara.
* Stavka se označava kao dečja, odrasla ili univerzalna.
* Kategorije imaju početni spisak, a predsednik ih može proširivati i
  deaktivirati. Korišćena kategorija se ne briše.
* Fotografije nisu deo modula.

## Pregled

Glavne kartice su aktivni filteri:

* spremno za izdavanje;
* zaduženo;
* rok za vraćanje je prošao;
* nepotpuno vraćeno;
* otvoreni slučajevi gubitka;
* na popravci.

Ukupan broj komada može se prikazati kao sekundarna informacija, ali nije glavni
pokazatelj rada garderobe.

## Inventar

Stavka inventara sadrži kategoriju, naziv, internu oznaku, uzrast
`CHILD/ADULT/UNIVERSAL`, namenu `MALE/FEMALE/UNISEX`, opcioni broj obuće,
ukupnu količinu i napomenu.

Raspoloživa količina izračunava se iz ukupne količine umanjene za aktivno
zaduženo, pozajmljeno, izgubljeno, na pranju, na popravci, oštećeno ili
rashodovano. Status pojedinačne količine čuva se kroz stavke zaduženja,
popravke i slučajeve gubitka.

## Kompleti

Komplet je obrazac za brzo izdavanje i sadrži više stavki inventara i potrebnu
količinu. Jedno zaduženje može sadržati više kompleta i dodatne pojedinačne
stavke. Delovi kompleta razdužuju se zasebno.

## Zaduženja i događaji

Zaduženje može biti:

* lično članu;
* povezano sa događajem;
* zajedničko pakovanje u kofer;
* pozajmica drugom društvu ili spoljnom primaocu.

Za događaj se rok automatski računa od datuma završetka događaja uvećanog za
broj dana iz podešavanja društva. Podrazumevana vrednost je 3 dana. Promena
podešavanja važi za nova zaduženja; postojeći rok se menja samo ručno.

Član vidi svoja zaduženja, ali ih ne može sam razdužiti. Roditelj vidi
zaduženja svoje maloletne dece.

## Koferi

Kofer ima naziv, događaj, sadržaj i odgovornog člana. Samo ovlašćena osoba može
promeniti odgovornog člana. Svaka primopredaja čuva prethodnog i novog
odgovornog člana, vreme, izvršioca, stanje i napomenu.

## Delimično vraćanje

Svaka stavka zaduženja može biti:

* vraćena ispravna;
* vraćena za pranje;
* vraćena oštećena;
* poslata na popravku;
* nevraćena;
* izgubljena.

Zaduženje ostaje otvoreno dok se ne razduže ili formalno reše sve količine.

## Gubitak i zamena

Otvoren slučaj gubitka ostaje vidljiv kod člana dok ga predsednik ili
garderober ne reši. Rešenja su: naknadno vraćanje, prihvaćena fizička zamena,
finansijska nadoknada, otpis ili drugo obrazloženo rešenje.

Zamenski komad ulazi u vlasništvo i raspoloživu količinu društva tek kada ga
predsednik ili garderober pregleda i prihvati. Finansijsko zaduženje ne nastaje
automatski; garderoba priprema predlog, a finansijska radnja zahteva posebnu
potvrdu.

## Popravke

Popravka može biti dodeljena članu, roditelju, zaduženom članu društva,
garderoberu ili spoljnom saradniku. Tek potvrđen prijem popravljenog komada
vraća količinu među raspoloživu garderobu.

## Obaveštenja

Podrazumevano obaveštenje o roku stiže jedan dan pre isteka, na dan isteka i
nakon prekoračenja. Broj dana ranijeg upozorenja je podešavanje društva.
Obaveštenje dobija član, odnosno roditelj maloletnog člana. Promena odgovornog
člana kofera i dodela popravke takođe stvaraju obaveštenje.

Dok je aplikacija lokalna koriste se obaveštenja u aplikaciji. Email kanal se
uključuje nakon javnog objavljivanja aplikacije i podešavanja email servisa.

## Pozajmica drugom društvu

Vlasništvo ostaje kod društva koje je izdalo garderobu. Ako je primalac drugo
društvo na platformi, ono vidi stavke kao pozajmljene. Izdavanje potvrđuje
vlasnik, prijem primalac, a vraćanje je završeno tek kada vlasnik potvrdi
prijem. Za primaoca van platforme čuvaju se naziv, odgovorna osoba i kontakt.

## Audit

Svaka poslovna promena čuva društvo, vrstu radnje, objekat, prethodno i novo
stanje, izvršioca, vreme i razlog ili napomenu. Istorija se ne briše
deaktiviranjem kategorije, kompleta ili stavke.

## Redosled izrade

1. broj obuće osobe i osnovne tabele;
2. kategorije, inventar i kompleti;
3. lična zaduženja i delimično vraćanje;
4. događaji, rokovi i obaveštenja;
5. koferi i primopredaje;
6. gubici, zamene i popravke;
7. međudruštvene pozajmice;
8. detaljno podešavanje dozvola.

## Realizacija druge faze

Migracija `wardrobe-v1-management.sql` dodaje:

* uređivanje postojećih kategorija, stavki i kompleta;
* različitu količinu svakog dela kompleta;
* zaštitu od smanjenja ukupne količine ispod količine vezane za zaduženja;
* automatsko otvaranje slučaja gubitka ili naloga za popravku pri razduživanju;
* dodelu popravke članu, roditelju, drugom članu ili spoljnom saradniku;
* promenu statusa popravke i povrat popravljene količine u garderobu;
* trajno rešavanje gubitka vraćanjem, prihvaćenom zamenom, finansijskim
  rešenjem, otpisom ili drugim obrazloženim rešenjem;
* promenu odgovornog člana kofera uz istoriju svake primopredaje.

## Realizacija treće faze

Migracija `wardrobe-v1-loans-notifications.sql` i nova kartica `Pozajmice`
dodaju:

* izdavanje više kompleta društvu na Folklorašu ili spoljnom primaocu;
* naziv, odgovornu osobu i kontakt za primaoca van platforme;
* prikaz pozajmljene garderobe i kod vlasnika i kod društva primaoca;
* odvojene potvrde izdavanja, prijema, najave vraćanja, razduženja delova i
  konačnog prijema kod vlasnika;
* in-app obaveštenja o približavanju roka, roku koji je danas i kašnjenju;
* obaveštenje roditelju za garderobu maloletnog člana;
* obaveštenje članu kada postane odgovoran za zajednički kofer ili mu se dodeli
  popravka;
* zaštitu poziva tako da ih koristi samo prijavljeni korisnik sa odgovarajućom
  ulogom.

Detaljno podešavanje dozvola i otvaranje ličnog prikaza garderobe članovima i
roditeljima ostaje poslednja celina ove verzije. Email obaveštenja ostaju za
fazu kada aplikacija bude javno dostupna.

## Realizacija četvrte faze — dozvole

Migracija `wardrobe-v1-permissions.sql` povezuje Garderobu sa centralnim
sistemom dozvola:

* `wardrobe.view` određuje pregled sopstvenih, dečjih ili svih zaduženja;
* `wardrobe.manage` obuhvata operativni rad sa inventarom, kompletima,
  izdavanjem, povratima, koferima, popravkama, gubicima, pozajmicama i rokovima;
* `wardrobe.view_audit` je posebno osetljivo pravo za detaljnu istoriju;
* predsednik početno ima sva tri prava za celo društvo;
* garderober početno ima pregled i operativno upravljanje, ali ne i detaljni
  audit;
* član vidi samo svoja i zaduženja svoje povezane dece;
* roditelj koji nije član vidi samo zaduženja povezane dece;
* član i roditelj ne dobijaju inventar, spisak drugih članova, pozajmice,
  popravke, gubitke niti komande za razduživanje;
* ograničenje se primenjuje u kontrolisanoj baznoj funkciji, a zatim i u
  interfejsu.

Email obaveštenja ostaju za fazu javnog objavljivanja aplikacije.
