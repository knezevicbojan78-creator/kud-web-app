# Finansije V1

## 1. Opseg

V1 obuhvata:

* mesečne članarine
* kotizacije za događaje i putovanja
* delimične i zbirne uplate
* kredit člana ili putnika
* poništavanje pogrešne uplate
* povraćaj kredita
* email potvrde i ručno slanje opomena
* potpun audit finansijskih promena

V1 ne obuhvata:

* finansijske izveštaje i izvoz izveštaja
* početna stanja i prenos stare finansijske istorije
* kursne razlike i konverziju valuta
* formalne planove rata
* ručno storniranje članarine
* detalje bankarskog izvoda, poziv na broj i datum bankarske transakcije
* prenos kredita između članova
* delegiranje finansijskih prava drugim ulogama; planirano je za kasnije

## 2. Operativni prikaz

* Finansije su prvenstveno orijentisane na člana ili roditelja i njegovu decu.
* Pretraga pronalazi člana, dete ili roditelja/staratelja.
* Naplata prikazuje samo otvorene i delimično plaćene obaveze, od najstarije ka najnovijoj.
* Plaćene obaveze se ne prikazuju u naplati; ostaju u istoriji osobe.
* Korisnik ručno bira obaveze koje plaća. Sistem ih ne označava automatski.
* Roditelj može jednom uplatom pokriti obaveze više svoje dece, ali se raspodela čuva po konkretnom detetu i obavezi.

## 3. Prava

* Predsednik i blagajnik mogu evidentirati sve nove uplate.
* Predsednik može poništiti pogrešnu uplatu i povraćaj, menjati finansijska podešavanja i ispravljati ranije finansijske podatke; svako od tih prava može posebno dodeliti ovlašćenom korisniku.
* Predsednik vidi kompletan finansijski audit.
* Blagajnik vidi operativnu istoriju uplata, njihov status i korisnika koji ih je evidentirao, ali nema poseban detaljni audit ekran.
* Član ima read-only pregled svojih obaveza, kredita i uplata.
* Roditelj/staratelj ima read-only pregled obaveza, kredita i uplata svoje dece.
* Putnik bez korisničkog naloga dobija email potvrde i opomene, ali nema samostalni pristup aplikaciji.

## 4. Valute

* Društvo pri registraciji dobija osnovnu valutu u troslovnom ISO formatu.
* Država predlaže valutu, ali se valuta posebno čuva na društvu.
* Članarina koristi osnovnu valutu društva.
* Osnovna valuta može se slobodno promeniti samo dok društvo nema finansijske obaveze.
* Nakon nastanka prve obaveze valutu može promeniti samo Master administrator kroz kontrolisanu i auditovanu promenu.
* Jedno putovanje ima jednu valutu kotizacije. Učesnici mogu imati različite iznose, ali u istoj valuti događaja.
* Kotizacija se plaća u valuti putovanja.
* Jedna uplata ima samo jednu valutu i može se rasporediti samo na obaveze u toj valuti.
* Krediti se vode odvojeno po članu/putniku i valuti.
* Konverzija valuta nije deo V1.

## 5. Podešavanja članarine

* Društvo ima jedan standardni mesečni iznos članarine.
* Novi član podrazumevano dobija standardni iznos.
* Svaki član ima režim članarine:
  * `STANDARD` — prati standardni iznos društva
  * `CUSTOM` — ima poseban individualni iznos
  * `EXEMPT` — ne plaća članarinu
* Predsednik ili korisnik sa posebnom dozvolom menja standardni iznos, režim ili pojedinačni iznos.
* Svaka promena zahteva razlog i važi od prvog dana narednog meseca.
* Pri promeni standardnog iznosa sistem automatski priprema promenu za `STANDARD` članove, a predsedniku prikazuje `CUSTOM` članove radi pojedinačne odluke.
* `EXEMPT` članovi ostaju oslobođeni.
* Mesečna obaveza pamti iznos koji je važio pri njenom nastanku. Kasnije promene ne prepravljaju ranije obaveze.

## 6. Kalendar članarine

* Predsednik ili korisnik sa posebnom dozvolom u Podešavanjima finansija određuje buduće mesece u kojima društvo naplaćuje ili ne naplaćuje članarinu.
* Podešavanje se vodi po konkretnom mesecu i godini.
* Promena kalendara važi najranije od prvog dana narednog meseca.
* Tekući i prethodni meseci se redovnim podešavanjem ne menjaju retroaktivno.
* Blagajnik, sekretar i upravnik podrazumevano vide kalendar, a menjaju ga samo uz posebno dodeljenu dozvolu.
* Mesec bez članarine ne formira obavezu i ne troši individualni gratis mesec.
* Svaka promena kalendara ulazi u audit.

## 7. Aktivacija finansija

* Predsednik pri aktivaciji Finansija bira prvi obračunski mesec društva.
* Aplikacija počinje sa nulom i ne prenosi stare dugove, kredite ili uplate.
* Sve pre prvog obračunskog meseca ostaje u prethodnom načinu evidencije.

## 8. Formiranje članarine

* Članarina se plaća jednom mesečno.
* Sistem automatski prvog dana u mesecu formira obaveze za tekući mesec.
* Proces mora biti bezbedan za ponavljanje i ne sme praviti duplikate.
* Jedan član dobija jednu mesečnu članarinu bez obzira na broj sekcija.
* Rok plaćanja je prvi dan narednog meseca.
* Obaveza je dospela za opomenu od drugog dana narednog meseca.

Redosled provere je:

1. da li je dostignut prvi obračunski mesec društva
2. da li je mesec naplativ
3. da li je član aktivan prema datumima statusa
4. da li je režim članarine `STANDARD`, `CUSTOM` ili `EXEMPT`
5. da li član ima preostali gratis naplativi mesec
6. koji iznos važi za dati mesec
7. da li je obračun za istog člana i mesec već izvršen

Sistem mora zabeležiti rezultat mesečne provere, uključujući razloge kada obaveza nije formirana.

## 9. Novo članstvo i gratis meseci

* Početak članstva od 1. do 15. dana, uključujući 15. dan, omogućava zaduženje za taj mesec.
* Početak članstva od 16. dana do kraja meseca omogućava prvo zaduženje narednog meseca.
* Član unet od 1. do 15. dana dobija tekuću obavezu odmah nakon uspešnog unosa, osim ako koristi gratis mesec ili mesec nije naplativ.
* Pri prvom učlanjenju podrazumevano nema gratis perioda. Može se izabrati 1, 2 ili 3 gratis naplativa meseca.
* Gratis se računa samo kroz mesece koji bi inače bili naplativi za društvo i člana.
* Mesec učlanjenja posle 15. dana ne troši gratis mesec.
* Sistem čuva koliko je gratis meseci dodeljeno, za koje naplative mesece su iskorišćeni i koliko ih je ostalo.

## 10. Reaktivacija

* Reaktivacija od 1. do 15. dana odmah omogućava zaduženje za taj mesec.
* Reaktivacija od 16. dana omogućava prvo zaduženje narednog meseca.
* Pri reaktivaciji nije dozvoljen novi gratis period.
* Sva prethodna dugovanja ostaju sačuvana.

## 11. Deaktivacija

Deaktivacija je izuzetak od pravila da finansijske promene važe od narednog meseca.

* Deaktivacija od 1. do 15. dana ukida neplaćeni deo članarine za tekući mesec.
* Deaktivacija od 16. dana nadalje ostavlja tekuće zaduženje.
* Od narednog meseca ne nastaju nova zaduženja.
* Prethodna dugovanja ostaju.
* Potpuno plaćena tekuća članarina ostaje plaćena članarina i ne postaje kredit.
* Kod delimično plaćene članarine uplaćeni deo ostaje članarina, a preostali dug se ukida. Ne nastaje kredit.
* Promena se ne rešava fizičkim brisanjem; čuvaju se prvobitni iznos, konačni iznos, razlog, korisnik i vreme promene.

## 12. Kotizacija događaja

* Događaj ima podrazumevani iznos, jednu valutu i jedan krajnji rok plaćanja.
* Formalne rate ne postoje. Dozvoljene su proizvoljne delimične uplate do krajnjeg roka.
* Učesnik dobija zaduženje prelaskom u status `CONFIRMED`.
* Tada se kopiraju njegov konkretan iznos, valuta i rok; kasnije promene podrazumevanog iznosa ne menjaju obavezu.
* Predsednik ili korisnik sa posebnom dozvolom može pre potvrđivanja postaviti drugačiji iznos učesniku, uključujući nulu. Odstupanje zahteva napomenu.
* `DECLINED` se koristi pre potvrde i ne stvara zaduženje.
* Posle potvrde samo predsednik može postaviti `CANCELLED`, uz obavezan razlog; time se otvoreno zaduženje poništava.
* `ABSENT` ne poništava kotizaciju.
* Ako je kotizacija delimično ili potpuno plaćena pre `CANCELLED`, plaćeni iznos postaje kredit tog učesnika u istoj valuti.
* Otkazivanje celog putovanja poništava otvorene kotizacije, a plaćeni iznosi postaju krediti učesnika. Predsednik može evidentirati povraćaj tih kredita.
* Putnik koji nije član koristi isti tok kotizacije, uplata, kredita, povraćaja, potvrda i opomena, ali nema članarinu.

## 13. Uplate i raspodela

* Podrazumevani način plaćanja je `CASH`.
* Drugi način u V1 je `BANK_TRANSFER`, koji se ručno evidentira bez dodatnih bankarskih detalja.
* Čuva se samo datum i vreme evidencije u bazi; ne čuva se poseban stvarni datum gotovinske ili bankarske transakcije.
* Uplata se uvek vodi na člana, dete ili putnika čije se obaveze plaćaju. Ne vodi se poseban model platioca.
* Dozvoljeno je delimično plaćanje i neograničen broj uplata jedne obaveze.
* Jedna uplata može se rasporediti na više ručno izabranih obaveza iste valute.
* Jedna roditeljska naplata može obuhvatiti više dece, ali baza čuva raspodelu po detetu i obavezi.
* Plaćeno i preostalo računaju se iz važećih raspodela; ne održavaju se kao nepovezane ručne vrednosti.

## 14. Kredit

* Iznos uplate preko izabranih obaveza postaje kredit tačno određenog člana, deteta ili putnika u istoj valuti.
* Kredit se ne prenosi između članova.
* Pri nastanku nove članarine raspoloživi kredit u valuti društva automatski se koristi kao deo ili cela članarina.
* Ako kredit premašuje članarinu, ostatak ostaje za buduća zaduženja.
* Kredit se ne koristi automatski za kotizaciju. Predsednik ili blagajnik ga svesno uključuje pri naplati izabrane kotizacije.
* Svako nastajanje i korišćenje kredita ostaje povezano sa izvornom uplatom ili događajem koji ga je proizveo.

## 15. Poništavanje uplate

* Uplata se nikada direktno ne menja niti fizički briše.
* Predsednik ili korisnik sa posebnom dozvolom može poništiti uplatu uz obavezan razlog.
* Nakon poništavanja unosi se nova ispravna uplata ako je potrebna.
* Poništavanje vraća kompletno stanje pre transakcije: uklanja važeće raspodele, vraća prethodno korišćen kredit i ponovo otvara odgovarajući dug.
* Originalna uplata, poništavanje i nova uplata ostaju u istoriji.

## 16. Povraćaj

* Predsednik ili korisnik sa posebnom dozvolom može evidentirati povraćaj raspoloživog kredita.
* Povraćaj je u istoj valuti, ne može biti veći od kredita i zahteva razlog.
* Način povraćaja je `CASH` ili `BANK_TRANSFER`.
* Pogrešan povraćaj se ne menja niti briše; predsednik ili korisnik sa posebnom dozvolom poništava ga uz razlog, kredit se vraća, a zatim se unosi novi povraćaj.
* Finansijski profil prikazuje istoriju povraćaja za izabranu osobu, odnosno za
  svu povezanu decu kada je otvoren porodični pregled.
* Komande za poništavanje prikazuju se samo korisniku sa odgovarajućom
  finansijskom dozvolom; poništeni zapisi ostaju vidljivi u istoriji.

## 17. Numeracija

* Svako društvo ima odvojenu godišnju numeraciju.
* Uplata dobija broj oblika `UPL-2026-000001`.
* Povraćaj dobija broj oblika `POV-2026-000001`.
* Brojevi se ne koriste ponovo nakon poništavanja.

## 18. Email potvrde

* Automatski email se šalje samo nakon prihvaćene uplate i nakon poništavanja uplate.
* Punoletni član prima svoju potvrdu, a primarni roditelj/staratelj potvrdu maloletnika.
* Jedna uplata koja pokriva više dece istog roditelja može proizvesti jednu zbirnu poruku sa raspodelom.
* Email sadrži broj potvrde, društvo, člana/dete/putnika, iznos i valutu, način plaćanja, raspodelu, kredit, vreme evidencije i korisnika koji je evidentirao uplatu.
* V1 nema PDF prilog; potvrda se može prikazati i odštampati iz aplikacije.
* Neuspeh slanja ne poništava uplatu.

## 19. Gmail i red za slanje

* Društvo može opciono povezati svoj Gmail nalog preko Google OAuth-a. Gmail lozinka se nikada ne čuva.
* Povezivanje, promena i prekid veze dostupni su predsedniku.
* Ako Gmail nije povezan, koristi se centralna FOLKLORAŠ adresa.
* Ako povezani Gmail privremeno ne pošalje poruku, ne prelazi se automatski na centralnu adresu zbog rizika od duplikata.
* Poruka ostaje u redu kao neuspešna, a predsednik ili blagajnik mogu ponoviti slanje.
* Red za slanje čuva primaoca, vrstu poruke, status, broj pokušaja, poslednju grešku, identifikator provajdera i vremena pokušaja/uspeha.

## 20. Opomene

* Predsednik i blagajnik mogu ručno pokrenuti `POŠALJI OPOMENE`.
* Pre slanja vide pregled primalaca, dospelih obaveza, ukupnog duga i osoba bez emaila.
* Email se šalje samo ako primalac ima najmanje jednu dospelu obavezu.
* Poruka jasno odvaja `DOSPELE OBAVEZE` od ostalih otvorenih obaveza koje još nisu dospele.
* Roditelj dobija jednu zbirnu poruku za svoju decu.
* Isto pravilo važi za putnika koji nije član.
* Pored dugmeta se prikazuje datum i vreme poslednjeg grupnog slanja i čuva se korisnik koji ga je pokrenuo.
* Opomena sadrži račun društva i podesive instrukcije za plaćanje.

## 21. Audit i zabrana brisanja

* Finansijski zapisi se ne brišu fizički kada bi time nestala istorija.
* Svaka promena čuva korisnika, datum i vreme, prethodno stanje, novo stanje i razlog kada je razlog obavezan.
* Audit razlikuje ručnu promenu od automatske posledice, na primer automatsko korišćenje kredita ili ukidanje duga zbog deaktivacije.
* Direktni upisi, izmene i brisanja finansijskih tabela iz klijenta moraju biti zabranjeni; promene se izvršavaju kroz kontrolisane bazne funkcije.

## 22. Raspored finansijskih podešavanja u interfejsu

* Kartica `FINANSIJE` služi isključivo za operativni rad: pretragu člana ili roditelja, pregled obaveza i kredita, evidentiranje uplata i pregled istorije.
* Kartica `FINANSIJE` nema link niti prečicu ka podešavanjima članarine.
* Sve vrednosti i pravila koja se definišu ili menjaju nalaze se isključivo u kartici `PODEŠAVANJA`, raspoređena po odgovarajućim tabovima.
* Podešavanja članarine nalaze se u tabu `ČLANARINA` unutar kartice `PODEŠAVANJA`.

## 23. Trajni godišnji obrazac meseci naplate

* Predsednik i korisnik sa posebnom dozvolom u `PODEŠAVANJA → ČLANARINA` vidi svih 12 meseci i štiklira mesece u kojima se članarina naplaćuje.
* Izabrani meseci predstavljaju trajno godišnje pravilo koje se ponavlja svake godine.
* Pravilo nema datum isteka i važi dok ga predsednik ponovo ne promeni.
* Ne unose se zasebno jul 2026, jul 2027 i drugi pojedinačni kalendarski meseci.
* Izmena obrasca primenjuje se od sledećeg meseca; već nastalo zaduženje tekućeg meseca se zbog ove izmene ne menja.
* Pri prvom prikazu podrazumevano je štiklirano svih 12 meseci.

## 24. Početna finansijska podešavanja pri registraciji društva

* Početna finansijska podešavanja unose se pri prvoj registraciji društva/predsednika jer pripadaju društvu, a ne pojedinačnom korisniku.
* Registracija sadrži osnovnu valutu društva, standardni mesečni iznos članarine i trajni godišnji obrazac meseci naplate.
* Pri registraciji je podrazumevano štiklirano svih 12 meseci.
* Nakon odobrenja i početka rada predsednik ili korisnik sa posebnom dozvolom menja ove vrednosti isključivo u `PODEŠAVANJA → ČLANARINA`.
* Automatski mesečni obračun ne sme početi bez potpunih početnih finansijskih podešavanja društva.

## 25. Način članarine pojedinačnog člana

* Član ima jedan od režima: `STANDARD`, `CUSTOM` ili `EXEMPT`.
* `STANDARD` koristi važeći standardni iznos društva.
* `CUSTOM` koristi posebno unet iznos za tog člana.
* `EXEMPT` se u interfejsu prikazuje kao `Oslobođen članarine`, a ne kao iznos `0`.
* Za oslobođenog člana polje iznosa nije primenljivo i ne prikazuje se kao nulta članarina.
* Promena režima ili posebnog iznosa važi od sledećeg meseca i čuva korisnika, vreme i razlog promene.
