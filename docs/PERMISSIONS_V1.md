# DOZVOLE DRUŠTVA V1

## 1. Svrha

Predsednik upravlja funkcijama članova društva i njihovim dozvolama u aplikaciji. Model jasno razdvaja:

* funkciju člana u društvu
* sekcijsku ulogu i njen opseg
* pravo pregleda
* pravo izmene
* zajednička prava funkcije
* pojedinačne izuzetke člana

Dozvole se ne smeju sprovoditi samo skrivanjem elemenata interfejsa. Konačna provera mora postojati i na strani baze/RPC workflow-a.

## 2. Funkcije društva

Funkcije se vode kroz postojeće `society_member_functions` i `society_member_function_assignments`.

Početne sistemske funkcije su:

* Predsednik
* Sekretar
* Blagajnik
* Upravnik
* UR
* Korepetitor
* Član

Jedan član može imati više aktivnih funkcija.

Predsednik u tabu `Funkcije i zaduženja` može:

* pregledati članove po funkciji
* dodeliti funkciju aktivnom članu
* ukloniti funkciju članu
* dodati novu funkciju društva
* deaktivirati dodatnu funkciju

Funkcija `Predsednik` ne dodeljuje se kroz ovaj ekran. Menja se isključivo kroz kontrolisani workflow promene predsednika.

## 3. Veza funkcije i sekcijske uloge

Funkcija predstavlja kvalifikaciju/zaduženje na nivou društva, a `section_role_assignments` određuje u kojoj sekciji se funkcija obavlja.

* UR konkretne sekcije može biti samo aktivan član koji ima aktivnu funkciju `UR`.
* Korepetitor konkretne sekcije može biti samo aktivan član koji ima aktivnu funkciju `Korepetitor`.
* Pretraga kandidata u `Moje sekcije` prikazuje samo članove sa odgovarajućom funkcijom.
* Uklanjanje funkcije `UR` ili `Korepetitor` mora upozoriti predsednika ako postoje aktivne sekcijske dodele.
* Nakon potvrde aktivne sekcijske dodele se deaktiviraju, ne brišu, a istorija ostaje sačuvana.

Ovo pravilo zamenjuje raniju odluku po kojoj se UR nije morao prethodno dodeliti kao funkcija društva.

## 4. Jedinstveni ekran dozvola

Podešavanja predsednika dobijaju tabove:

* Članarina
* Funkcije i zaduženja
* Dozvole

Tab `Dozvole` nije podeljen na dve odvojene stranice. Predsednik prvo bira funkciju.

Podrazumevani opseg je:

* `Pravila za sve članove funkcije`

Alternativni opseg je:

* `Pojedinačni izuzetak`

Tek izborom pojedinačnog izuzetka otvara se pretraga članova. Pretraga prikazuje samo aktivne članove koji imaju izabranu funkciju.

Ekran mora stalno i jasno prikazivati da li se menjaju prava cele funkcije ili samo jednog člana.

## 5. Katalog dozvola

Dozvole dolaze iz unapred definisanog sistemskog kataloga sa stabilnim tehničkim ključevima. Predsednik ne unosi slobodan tekst za dozvole.

Dozvole se grupišu po modulima i odvajaju najmanje:

* pravo pregleda
* pravo izmene

Pravo izmene podrazumeva pravo pregleda, ali se u bazi čuvaju i proveravaju eksplicitna prava.

Kompletan katalog dozvola i početna prava svake sistemske funkcije moraju biti potvrđeni pre izrade SQL modela.

## 6. Zajednička prava funkcije

Svaka sistemska funkcija dobija početni skup prava.

Postoje:

* zaključana osnovna prava bez kojih funkcija nema poslovni smisao
* dodatna prava koja predsednik može uključiti ili isključiti

Primer: Blagajnik mora imati osnovna finansijska prava, dok mu predsednik može dodatno dozvoliti pregled događaja ili osnovnih podataka članova.

Izmena pravila funkcije primenjuje se na sve aktivne članove koji imaju tu funkciju, osim njihovih eksplicitnih pojedinačnih izuzetaka.

## 7. Pojedinačni izuzeci

Za konkretnog člana svaka dozvola ima tri stanja:

* `INHERIT` — nasleđuje zbir prava svojih funkcija
* `ALLOW` — posebno dozvoljeno
* `DENY` — posebno zabranjeno

Postoji akcija `Vrati sva prava na pravila funkcije`, koja uklanja pojedinačne izuzetke i vraća člana na nasleđivanje.

Pojedinačni izuzetak predstavlja konačno pravilo za osobu:

* bez izuzetka sabiraju se dozvole svih aktivnih funkcija
* `ALLOW` ima prednost nad nasleđenim odsustvom prava
* `DENY` ima prednost nad dozvolama dobijenim kroz funkcije

## 8. Član sa više funkcija

Kada član ima više funkcija, ekran mora prikazati:

* sve njegove aktivne funkcije
* izvor svake nasleđene dozvole
* pojedinačni izuzetak, ako postoji
* konačno efektivno pravo

Primer: član može dobiti pregled finansija kroz funkciju Blagajnik iako je u ekran otvoren kroz funkciju UR.

Korisnik ne bira funkciju pod kojom koristi aplikaciju. Sistem pri svakom pristupu sabira prava svih njegovih aktivnih funkcija i važećih pojedinačnih izuzetaka.

Korisnički interfejs prikazuje sve dozvoljene module, podatke i akcije zajedno, u jednom objedinjenom prikazu. Isti modul ili akcija ne prikazuju se više puta ako pravo dolazi iz više funkcija.

Ograničenje opsega i dalje se primenjuje na svako pravo. Na primer, član koji je istovremeno blagajnik i UR dobija globalna finansijska prava blagajnika, dok njegova osnovna UR prava ostaju ograničena na sekcije u kojima je aktivno dodeljen.

## 9. Opseg dozvole

Dozvola za modul ne ukida ograničenje opsega.

Primer:

* UR sa pravom pregleda članova podrazumevano vidi samo članove sekcija u kojima ima aktivnu UR dodelu.
* Globalni pregled svih članova društva mora biti posebno pravo.

Isto pravilo važi za prisustvo, događaje, repertoar i druge sekcijski ograničene podatke.

## 10. Bezbednosna pravila

* Predsednik ne sme slučajno ukloniti sopstvena obavezna prava i zaključati društvo.
* Sistemska bezbednosna ograničenja ne mogu se zaobići pojedinačnim `ALLOW` izuzetkom.
* Promena dozvola ne briše istoriju.
* Svaka promena funkcije, zajedničkih prava i pojedinačnih izuzetaka zahteva audit.
* Audit čuva prethodnu i novu vrednost, opseg promene, razlog, izvršioca i vreme.

## 11. Potvrđena prava funkcija

### Predsednik

* Predsednik vidi sve delove aplikacije i sve podatke svog društva.
* Predsednik može da menja sve podatke i podešavanja svog društva.
* Ova prava su sistemska i zaključana; ne mogu se isključiti kroz podešavanja funkcije niti pojedinačnim izuzetkom.
* Puno pravo izmene ne podrazumeva fizičko brisanje finansijske istorije.
* Finansijska istorija se ne može fizički brisati i dozvola za takvo brisanje neće postojati u katalogu dozvola.

### Umetnički rukovodilac — UR

Obavezna i zaključana prava svakog UR-a:

* vidi sekcije u kojima ima aktivnu UR dodelu
* vidi članove svojih sekcija i njihove osnovne podatke
* vidi osnovne kontakte roditelja ili staratelja maloletnih članova svojih sekcija
* menja pripadnost člana samo sekcijama u kojima je UR
* otvara i zatvara probu svoje sekcije
* evidentira prisustvo dok je proba otvorena
* nakon zatvaranja probe ima pravo pregleda
* vidi trajanje probe svoje sekcije
* kreira predlog događaja za svoje sekcije
* menja status učešća članova svojih sekcija
* koristi postojeće numere u programu svoje sekcije

UR bez dodatne dozvole:

* ne vidi druge sekcije i njihove članove
* ne vidi osetljive podatke članova
* ne menja podatke članova osim ranije dozvoljenih osnovnih kontakt podataka
* ne ispravlja zatvorenu probu
* ne menja trajanje probe
* ne odobrava događaj
* ne otkazuje već odobren ili zakazan događaj
* ne uređuje repertoar, osim ako mu je to posebno dozvoljeno

Dodatne dozvole predsednik može dodeliti svim UR-ovima ili samo pojedinačnom UR-u:

* pregled drugih sekcija
* pregled članova drugih sekcija
* pregled svih podataka članova svojih sekcija
* izmena svih podataka članova svojih sekcija
* pregled svih podataka članova drugih sekcija
* izmena svih podataka članova drugih sekcija
* ispravka zatvorene probe na isti način kao predsednik
* promena trajanja probe
* odobravanje događaja
* otkazivanje već odobrenog ili zakazanog događaja
* uređivanje repertoara

Pravo pregleda i pravo izmene su odvojene dozvole. Pravo izmene podrazumeva da je podatak vidljiv u opsegu u kojem je izmena dozvoljena, ali samo pravo pregleda nikada ne daje pravo izmene.

Svaka izmena koju izvrši UR mora ostaviti audit trag sa identitetom UR-a, vremenom, prethodnom vrednošću, novom vrednošću i opsegom promene.

### Blagajnik

Obavezna i zaključana prava svakog blagajnika:

* vidi finansijski modul društva
* vidi članove, putnike i njihove podatke u meri potrebnoj za naplatu
* vidi obaveze, dugovanja, kredite i operativnu istoriju uplata
* evidentira nove uplate članarina i kotizacija
* evidentira gotovinsku uplatu i uplatu na račun
* raspoređuje uplatu na ručno izabrane obaveze
* svesno koristi raspoloživi kredit pri naplati kotizacije
* vidi ko je i kada evidentirao uplatu
* vidi kalendar naplate članarine
* ručno pokreće slanje opomena
* vidi pregled primalaca i dugovanja pre slanja
* ponavlja slanje neuspele finansijske poruke

Blagajnik bez dodatne dozvole:

* ne menja standardni iznos članarine
* ne menja pojedinačni iznos ili režim članarine člana
* ne menja kalendar naplate članarine
* ne menja finansijska podešavanja
* ne poništava pogrešnu uplatu
* ne poništava pogrešan povraćaj
* ne ispravlja ranije finansijske podatke
* nema poseban detaljni finansijski audit

Predsednik može svim blagajnicima ili pojedinačnom blagajniku odvojeno dodeliti:

* promenu standardnog iznosa članarine
* promenu pojedinačnog iznosa ili režima članarine člana
* promenu kalendara naplate članarine
* promenu finansijskih podešavanja
* poništavanje pogrešne uplate
* poništavanje pogrešnog povraćaja
* ispravku ranijih finansijskih podataka
* pristup detaljnom finansijskom auditu
* pregled ostalih podataka članova
* izmenu ostalih podataka članova

Svaka dodatna dozvola se dodeljuje zasebno. Dodela jednog finansijskog prava ne uključuje automatski ostala prava.

Svaka finansijska izmena blagajnika mora ostaviti audit trag sa identitetom blagajnika, vremenom, razlogom, prethodnom vrednošću i novom vrednošću.

### Zajednički katalog dodatnih dozvola

Dodatne dozvole za pregled i izmenu modula ne definišu se kao zatvorena lista samo za jednu funkciju. Predsednik može iz zajedničkog kataloga dodeliti odgovarajuću dodatnu dozvolu bilo kojoj funkciji ili pojedinačnom članu sa tom funkcijom.

Dozvole pregleda i izmene uvek su odvojene. Dodela pristupa jednom modulu ne daje automatski pristup drugim modulima, osetljivim podacima ili podešavanjima.

### Sekretar i upravnik

Sekretaru i upravniku predsednik može dodeliti sva prava koja se odnose na svakodnevni i operativni rad društva, do nivoa operativnih prava predsednika.

Obavezna i zaključana početna prava sekretara i upravnika:

* imaju pregled svih operativnih delova i podataka društva
* pregled je globalan i nije ograničen na pojedinačne sekcije
* pristup je isključivo `read-only`
* ne mogu unositi nove podatke
* ne mogu menjati postojeće podatke
* ne mogu izvršavati operativne akcije koje menjaju stanje u bazi
* ne vide i ne mogu otvoriti deo za podešavanje dozvola

Oni ne mogu dobiti pristup delu za podešavanje dozvola i ne mogu:

* upravljati funkcijama članova
* određivati zajednička prava funkcija
* dodeljivati pojedinačne izuzetke dozvola
* menjati bezbednosna pravila dozvola
* ukloniti ili menjati zaključana prava predsednika

Prava unosa, izmene, podešavanja članarine i drugih operativnih akcija sekretaru i upravniku nisu uključena automatski samom dodelom funkcije. Predsednik ih dodeljuje iz zajedničkog kataloga svim članovima funkcije ili pojedinačnom sekretaru odnosno upravniku.

Sve njihove izmene moraju ostaviti audit trag sa identitetom izvršioca, vremenom, prethodnom i novom vrednošću.

### Korepetitor

Obavezna i zaključana početna prava korepetitora:

* vidi samo sopstvenu evidenciju prisustva
* vidi sopstveno prisustvo samo u sekcijama u kojima ima aktivnu dodelu korepetitora
* pregled je isključivo `read-only`
* ne može evidentirati niti menjati svoje ili tuđe prisustvo
* ne vidi prisustvo drugih članova sekcije

Sama funkcija korepetitora ne daje pristup drugim podacima, članovima ili operativnim akcijama. Dodatna prava predsednik može dodeliti iz zajedničkog kataloga svim korepetitorima ili pojedinačnom korepetitoru.

### Član

Obavezna i zaključana početna prava člana:

* vidi sve svoje lične podatke
* može otvoriti izmenu svojih podataka i poslati zahtev predsedniku
* klik na `Sačuvaj` ne menja odmah podatke, već formira zahtev za odobrenje
* predsednik odobrava ili odbija zahtev pre nego što izmena postane važeća
* vidi samo sopstveno prisustvo na probama
* vidi događaje na kojima učestvuje
* vidi program tih događaja i svoj status učešća
* ne može sam potvrditi ili odbiti učešće; status menja predsednik ili nadležni UR
* vidi sekcije kojima aktivno pripada
* ima `read-only` pregled podataka i sadržaja svojih sekcija, uključujući raspored/probe, repertoar, događaje i program
* pregled sekcije ne daje pristup ličnim, osetljivim ili finansijskim podacima drugih članova
* vidi svoje finansijske obaveze, kredite i istoriju uplata
* vidi i preuzima svoje potvrde o uplati

Član bez dodatne funkcije ili dozvole ne može neposredno menjati poslovne podatke društva. Zahtev za izmenu sopstvenih podataka mora čuvati predložene vrednosti, status zahteva, vreme slanja, odluku predsednika i vreme odluke.

### Roditelj ili staratelj

Roditelj ili staratelj ima za svoju decu ista prava koja član ima za sebe:

* vidi lične podatke svoje dece
* predlaže izmenu podataka deteta kroz zahtev koji predsednik odobrava ili odbija
* vidi prisustvo svoje dece na probama
* vidi događaje svoje dece, program i status učešća
* ne može potvrditi ili odbiti učešće deteta
* vidi sekcije kojima njegova deca pripadaju i njihov sadržaj bez prava izmene
* ne vidi lične, osetljive ili finansijske podatke drugih članova
* vidi obaveze, kredite i istoriju uplata svoje dece
* vidi i preuzima potvrde o uplati svoje dece

Roditeljska prava važe samo za decu sa kojima postoji važeća veza roditelja ili staratelja u evidenciji društva.

Ako je roditelj ili staratelj istovremeno član društva, njegova prava člana i roditeljska prava se sabiraju, ali svaki podatak ostaje ograničen na odgovarajuću osobu.

## 12. Katalog dozvola

### Članovi i lični podaci

Dozvole pregleda:

* pregled osnovnih podataka članova
* pregled kontakt podataka članova
* pregled osetljivih podataka članova
* pregled roditelja ili staratelja
* pregled istorije članstva
* pregled sekcija kojima član pripada

Dozvole unosa i izmene:

* slanje zahteva za izmenu svojih podataka ili podataka deteta
* unos novog člana
* izmena osnovnih i kontakt podataka
* izmena osetljivih podataka
* promena statusa članstva
* promena pripadnosti sekcijama
* upravljanje roditeljima ili starateljima
* odobravanje ili odbijanje zahteva za izmenu podataka

Svaka dozvola koristi jedan od odgovarajućih opsega:

* sopstveni podaci
* sopstvena deca
* članovi sekcija u kojima korisnik ima aktivnu nadležnost
* svi članovi društva

Pravila:

* fizičko brisanje člana nije dozvoljeno
* istorija članstva i izmena se ne briše
* pravo izmene podrazumeva pregled podatka u istom opsegu
* pristup osetljivim podacima je posebna dozvola
* svaka izmena beleži izvršioca, vreme, prethodnu i novu vrednost
* dodela funkcija članu ne pripada modulu članova, već predsedničkim podešavanjima
* osnovna i kontakt polja čine jednu grupu dozvola; ne pravi se posebna dozvola za svako pojedinačno polje

### Sekcije

Dozvole pregleda:

* pregled sekcija
* pregled članova sekcija
* pregled UR-ova i korepetitora sekcije
* pregled statusa i osnovnih podataka sekcije

Dozvole upravljanja:

* kreiranje nove sekcije
* izmena naziva i osnovnih podataka sekcije
* aktiviranje i deaktiviranje sekcije
* dodavanje i uklanjanje članova iz sekcije
* dodela i uklanjanje UR-a po sekcijama
* dodela i uklanjanje korepetitora po sekcijama

Dozvole koriste jedan od opsega:

* sekcije u kojima korisnik ima aktivnu nadležnost
* sve sekcije društva

Pravila:

* sekcija se ne briše fizički, već deaktivira
* istorija članstva i sekcijskih uloga se ne briše
* UR ili korepetitor može biti dodeljen sekciji samo ako već ima odgovarajuću aktivnu funkciju u društvu
* dodela funkcije `UR` ili `Korepetitor` članu ostaje isključivo u predsedničkim podešavanjima
* predsednik može sekretaru, upravniku ili drugom ovlašćenom korisniku dodeliti operativno pravo da raspoređuje postojeće UR-ove i korepetitore po sekcijama
* pravo raspoređivanja po sekcijama ne daje pravo dodeljivanja ili uklanjanja funkcije članu
* sve izmene ostavljaju audit trag sa izvršiocem, vremenom, prethodnom i novom vrednošću

### Prisustvo

Dozvole:

* pregled sopstvenog prisustva
* pregled prisustva drugih članova
* otvaranje probe
* evidentiranje prisustva na otvorenoj probi
* zatvaranje probe
* otkazivanje otvorene probe
* ispravka prisustva na zatvorenoj probi
* promena podrazumevanog trajanja probe

Dozvole koriste jedan od odgovarajućih opsega:

* sopstveno prisustvo
* sopstvena deca
* sekcije u kojima korisnik ima aktivnu nadležnost
* sve sekcije društva

Početna prava:

* predsednik ima sva prava za sve sekcije
* UR otvara, vodi, zatvara i otkazuje otvorenu probu svojih sekcija i pregleda zatvorene probe
* UR može dodatno dobiti ispravku zatvorene probe i promenu trajanja probe
* član vidi samo svoje prisustvo
* roditelj ili staratelj vidi samo prisustvo svoje dece
* korepetitor vidi samo svoje prisustvo u sekcijama kojima je dodeljen
* sekretar i upravnik imaju globalni `read-only` pregled

Trajna pravila:

* vreme otvaranja i zatvaranja beleži sistem i ne unosi se ručno
* evidencija probe se ne briše
* otkazana proba ostaje u istoriji i ne računa se kao održana
* ispravka zatvorene probe zahteva obavezan razlog
* svaka radnja beleži korisnika, vreme, aktivne funkcije, prethodnu i novu vrednost
* audit zapisi se ne mogu menjati niti brisati
* statistika, poređenja i izvoz nisu deo dozvola prisustva; pripadaju budućem modulu `Izveštaji`

### Događaji

Dozvole pregleda:

* pregled događaja
* pregled sekcija događaja
* pregled učesnika i gostiju
* pregled programa i izvođača
* pregled planiranih kotizacija

Dozvole upravljanja:

* kreiranje i izmena nacrta
* slanje događaja na odobrenje
* odobravanje ili odbijanje događaja
* izmena već odobrenog događaja
* otkazivanje odobrenog ili zakazanog događaja
* dodavanje i uklanjanje sekcija događaja
* dodavanje članova i gostiju
* promena statusa učesnika
* određivanje i izmena planirane kotizacije
* upravljanje nastupima, programom i izvođačima

Dozvole koriste jedan od odgovarajućih opsega:

* događaji i sekcije u kojima korisnik ima aktivnu nadležnost
* događaji koje je korisnik kreirao
* događaji na kojima korisnik učestvuje
* događaji na kojima učestvuje dete korisnika
* svi događaji i sekcije društva

Početna prava:

* predsednik ima sva prava za sve događaje
* UR vidi i priprema događaje svojih sekcija, dodaje učesnike i goste, menja njihove statuse i uređuje program svojih sekcija
* UR može dodatno dobiti odobravanje i otkazivanje događaja
* sekretar i upravnik imaju globalni `read-only` pregled dok im se ne dodele prava izmene
* član vidi događaje na kojima učestvuje, program i svoj status
* roditelj ili staratelj vidi isto za svoju decu
* korepetitor nema početno pravo pristupa događajima

### Repertoar

Dozvole:

* pregled repertoara
* dodavanje nove numere
* izmena numere
* aktiviranje i deaktiviranje numere
* povezivanje postojeće numere sa programom događaja

Dozvole mogu važiti za nadležne sekcije ili za sve sekcije društva.

Početna prava:

* predsednik upravlja repertoarom svih sekcija
* UR vidi repertoar svojih sekcija i povezuje postojeće numere sa njihovim programom
* UR centralni repertoar svoje sekcije menja samo uz dodatnu dozvolu
* član i roditelj vide repertoar u okviru `read-only` pregleda svojih sekcija

Trajna pravila događaja i repertoara:

* događaji i numere se ne brišu fizički
* odbijeni i otkazani događaji ostaju u istoriji
* neaktivna numera ostaje u istorijskim programima
* član i roditelj ne mogu menjati status učešća
* pregled ili izmena planirane kotizacije predstavlja posebno finansijski osetljivo pravo
* odobravanje i otkazivanje događaja su odvojene dozvole
* pristup događaju ne daje automatski pristup osetljivim podacima učesnika
* sve statusne i sadržajne izmene ostavljaju audit trag

### Finansije

Dozvole pregleda:

* pregled obaveza, dugovanja i uplata
* pregled raspoloživih kredita
* pregled povraćaja
* pregled operativne finansijske istorije
* pregled kalendara i pravila članarine
* pregled detaljnog finansijskog audita
* pregled i preuzimanje potvrda o uplati

Dozvole operativnog rada:

* evidentiranje nove uplate
* raspodela uplate na izabrane obaveze
* korišćenje kredita pri naplati kotizacije
* evidentiranje povraćaja
* slanje opomena
* ponovno slanje neuspele potvrde ili opomene

Dozvole ispravke:

* poništavanje pogrešne uplate
* poništavanje pogrešnog povraćaja
* ispravka ranijih finansijskih podataka

Dozvole podešavanja članarine:

* promena standardnog iznosa članarine
* promena pojedinačnog režima `STANDARD`, `CUSTOM` ili `EXEMPT`
* promena pojedinačnog iznosa članarine
* promena godišnjeg obrasca meseci naplate
* promena ostalih finansijskih pravila i instrukcija za plaćanje

Dozvole koriste jedan od opsega:

* sopstvene finansije
* finansije sopstvene dece
* sve finansije društva

Početna prava:

* predsednik ima sva finansijska prava
* blagajnik ima pregled svih finansija i operativnu naplatu, dok ispravke, povraćaje, finansijska podešavanja i detaljni audit dobija dodatno
* sekretar i upravnik imaju globalni `read-only` pregled bez detaljnog finansijskog audita, dok finansijska podešavanja dobijaju dodatno
* član vidi svoje finansije i potvrde
* roditelj ili staratelj vidi finansije i potvrde svoje dece
* UR i korepetitor nemaju početna finansijska prava osim ličnih prava koja imaju kao članovi

Trajna pravila:

* finansijski zapisi se nikada fizički ne brišu
* uplata ili povraćaj se ne menja direktno, već se poništava i po potrebi unosi novi zapis
* poništavanje, povraćaj i ispravka zahtevaju razlog
* svaka finansijska radnja čuva izvršioca, vreme, prethodno i novo stanje
* automatizovane promene označavaju se kao sistemske
* pregled finansija ne daje pravo operativnog rada
* evidentiranje uplate ne daje pravo poništavanja
* detaljni finansijski audit je posebna dozvola
* dozvole finansijskih podešavanja mogu se dodeliti blagajniku, sekretaru, upravniku ili drugom ovlašćenom korisniku kroz zajednički katalog

### Podešavanja dozvola

* deo `Podešavanja dozvola` vidi i koristi isključivo predsednik
* nijedna druga funkcija niti pojedinačni član ne vidi ovaj deo
* upravljanje zajedničkim pravima funkcija i pojedinačnim izuzecima nije deo kataloga dodatnih dozvola
* pristup podešavanjima dozvola ne može se dodeliti kroz `ALLOW` izuzetak
* ovo ograničenje ne odnosi se automatski na druga podešavanja, kao što su podešavanja članarine
* pokušaj direktnog pristupa mora biti odbijen u bazi i na serverskoj strani, a ne samo sakriven u interfejsu

### Audit

* operativnu istoriju modula vidi korisnik koji ima pravo pregleda tog modula i odgovarajućeg opsega podataka
* detaljni audit predstavlja posebnu dodatnu dozvolu za svaki modul
* audit promena funkcija, zajedničkih dozvola i pojedinačnih izuzetaka vidi samo predsednik
* audit zapis niko ne može menjati niti brisati
* osetljive radnje zahtevaju obavezan razlog
* audit beleži izvršioca, vreme, aktivne funkcije, opseg, prethodnu i novu vrednost
* automatske promene beleže sistem kao izvršioca i jasno se razlikuju od ručnih promena

## 13. Obavezno pravilo za svaki novi modul

Svaka nova kartica ili modul, na primer buduća `Garderoba`, mora se istovremeno dopuniti u katalogu dozvola.

Novi modul nije potpuno definisan niti spreman za implementaciju dok nisu određeni:

* dozvole pregleda, unosa, izmene i posebnih radnji
* odgovarajući opsezi dozvola
* početna prava svih relevantnih funkcija
* prava koja se mogu dodatno dodeliti funkciji ili pojedincu
* prava koja ostaju zaključana samo za predsednika
* audit i radnje koje zahtevaju razlog
* ponašanje kada korisnik ima više funkcija
* zaštita u bazi i na serverskoj strani

Ova provera je obavezan deo definisanja, izrade i prihvatanja svakog budućeg modula.

## 14. Sledeći korak

Poslovni model i katalog V1 su definisani. Implementacija se nastavlja po fazama iz `docs/PERMISSIONS_IMPLEMENTATION_PLAN.md`:

1. struktura baze i početni katalog
2. centralni obračun efektivnih prava
3. predsednički interfejs
4. sprovođenje dozvola modul po modul
5. finalni Auth, RLS i testovi
