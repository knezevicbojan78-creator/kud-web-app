# Odluke

## 2026-07-15

ODLUKA:
Trenutna faza ostaje DEV/V1 i pre nastavka se usklađuje samo dokumentacija neophodna za tačno razumevanje stanja. `UF_MEMBER_FORM` i `MOJE SEKCIJE` smatraju se funkcionalno implementiranim u DEV/V1 opsegu.

Supabase Auth, stvarni korisnički i multi-society kontekst, finalna President/UR prava, RLS, transakcijski approval i kompletno usklađivanje SQL migracija odlažu se za narednu arhitektonsku fazu.

Dok taj model nije uveden, `CLANOVI` i `MOJE SEKCIJE` mogu privremeno koristiti prvo aktivno društvo, a `CLANOVI` privremeno radi sa pravima predsednika. Ovo je razvojna pretpostavka, ne finalni bezbednosni model.

RAZLOG:
Postojeći tokovi članova i sekcija mogu se dalje razvijati bez prevremenog širenja opsega. Poznate razlike u SQL-u, dozvolama i korisničkom kontekstu ostaju jasno zabeležene kako privremeno ponašanje ne bi bilo proglašeno završenom arhitekturom.

---

## 2026-07-15

ODLUKA:
Modul `MOJE SEKCIJE` koristi kompaktan master-detail raspored. Lista sekcija je odvojena od detalja izabrane sekcije, a detalj koristi tabove `Članovi`, `Uloge` i `Podešavanja`. Forme za kreiranje sekcije, dodavanje člana i dodelu uloge prikazuju se samo na zahtev.

RAZLOG:
Pregled, uređivanje, uloge i članovi više ne treba da budu istovremeno otvoreni u velikim karticama. Novi raspored smanjuje vertikalno skrolovanje bez promene poslovne logike.

---

## 2026-06-25

ODLUKA:
Aktivna Supabase baza je trenutno provereni izvor istine za postojanje tabela.

RAZLOG:
Rucno je potvrdjeno da u aktivnoj bazi postoje `PresidentReg`, `societies`, `people`, `society_members`, `society_member_functions`, `society_member_function_assignments`, `member_status_history`, `sections`, `member_sections`, `person_guardians` i `user_onboarding_state`.

---

## 2026-06-25

ODLUKA:
Repo SQL fajlovi i migracije moraju naknadno biti uskladjeni sa aktivnom Supabase bazom.

RAZLOG:
Neke tabele postoje u aktivnoj bazi, ali kompletni SQL/migration fajlovi nisu potvrdjeni u repozitorijumu. Dokumentacija mora jasno razlikovati aktivnu bazu od repo migracija.

---

## 2026-06-25

ODLUKA:
`society_members.funkcija` ostaje legacy kolona dok se ne potvrdi bezbedno uklanjanje.

RAZLOG:
Novi model funkcija vise ne koristi tekstualno polje na `society_members`, ali kolona postoji u bazi i ne treba je brisati bez provere podataka i migracionog plana.

---

## 2026-06-25

ODLUKA:
Novi model funkcija clanova koristi `society_member_functions` i `society_member_function_assignments`.

RAZLOG:
`society_member_functions` je katalog funkcija po drustvu, a `society_member_function_assignments` je veza clana i jedne funkcije. Time clan moze imati nula, jednu ili vise funkcija bez upisa u `society_members.funkcija`.

---

## 2026-06-24

ODLUKA:
Postoji samo jedna univerzalna forma za društvo: `SocietyDataForm`.

RAZLOG:
Izbegavanje dupliranja formi.

---

## 2026-06-24

ODLUKA:
`/registracija-drustva` i `/drustva/[id]` koriste istu formu.

RAZLOG:
Različit workflow, ista forma i ista polja.

---

## 2026-06-24

ODLUKA:
Interno polje `taxId` zamenjeno je sa `pib`.

RAZLOG:
Usklađivanje sa PIB terminologijom i `societies.pib`.

---

## 2026-06-24

ODLUKA:
Društvo se kreira pri approval-u.

RAZLOG:
Master admin odobrenjem aktivira društvo.

---

## 2026-06-24

ODLUKA:
Predsednik se ne kreira automatski kao član.

RAZLOG:
Predsednik sebe unosi kroz `UF_MEMBER_FORM`.

---

## 2026-06-24

ODLUKA:
Onboarding ide preko `user_onboarding_state`.

RAZLOG:
Ne proveravati `society_members` pri svakom logovanju.

---

## 2026-06-24

ODLUKA:
Promene društva i licence idu kroz zahtev.

RAZLOG:
Master admin mora imati kontrolu odobravanja.

---

## 2026-06-24

ODLUKA:
Master admin dashboard mora biti sistemski dashboard.

RAZLOG:
Master admin upravlja sistemom, ne jednim društvom.

---

## 2026-06-24

ODLUKA:
`UF_MEMBER_FORM` je jedina univerzalna forma za unos i izmenu članova.

RAZLOG:
Ista forma mora da se koristi za dodavanje članova, izmenu članova i onboarding predsednika. Predsednik se ne sme unositi kroz posebnu formu, već kroz `UF_MEMBER_FORM` u posebnom režimu.

---

## 2026-06-24

ODLUKA:
`people` and `society_members` field names are standardized before implementing `UF_MEMBER_FORM`.

RAZLOG:
`UF_MEMBER_FORM` must not introduce parallel names such as `date_of_birth`, `joined_at`, `member_status`, `role_in_society`, or `is_active`.

---

## 2026-06-24

ODLUKA:
Roditelji/staratelji se čuvaju u `people`, a veza dete-staratelj ide kroz `person_guardians`.

RAZLOG:
Ista osoba može biti roditelj/staratelj i član društva. Zato se osoba ne sme duplirati niti se smeju dodavati posebna parent polja na record deteta.

---

## 2026-06-24

ODLUKA:
`people.email` je unique kada postoji i glavni je praktični identifikator za pronalaženje postojećih osoba.

RAZLOG:
`UF_MEMBER_FORM` mora moći da pronađe postojeće osobe bez oslanjanja na JMBG. JMBG može postojati, ali nije obavezan i nije glavni lookup identifikator.

---

## 2026-06-24

ODLUKA:
Maloletni članovi mogu imati prazne `email` i `phone` vrednosti.

RAZLOG:
Kontakt podaci za maloletnika mogu ići preko roditelja/staratelja.

---

## 2026-06-24

ODLUKA:
Roditelji/staratelji moraju imati `first_name`, `last_name`, `email` i `phone`.

RAZLOG:
Roditelj/staratelj je kontakt osoba za maloletnog člana i mora biti pouzdano identifikovan i kontaktibilan.

---

## 2026-06-24

ODLUKA:
Maloletni član mora imati najmanje jednog roditelja/staratelja, a drugi roditelj/staratelj je opcion.

RAZLOG:
Sistem mora imati najmanje jednu odgovornu kontakt osobu za maloletnog člana.

---

## 2026-06-24

ODLUKA:
Postoji samo jedna kategorija odnosa roditelja/staratelja: `RODITELJ_STARATELJ`.

RAZLOG:
U ovoj fazi nije potrebno razlikovati tipove porodičnog odnosa kao posebne kategorije.

---

## 2026-06-24

ODLUKA:
Ne koristi se model glavnog i sporednog roditelja/staratelja.

RAZLOG:
Obe veze u `person_guardians` su ravnopravne i ne zahtevaju dodatna polja za prioritet.

---

## 2026-06-24

ODLUKA:
`people` je jedina tabela identiteta za sve osobe, a osoba može biti član više društava kroz više redova u `society_members`.

RAZLOG:
Ista osoba može imati više uloga i članstava bez dupliranja zapisa u `people`.

---

## 2026-06-24

ODLUKA:
`people.email`, `people.phone`, `people.user_id`, `people.jmbg` i `people.passport_number` su unique kada postoje.

RAZLOG:
Potrebna je zaštita od dupliranja osoba, ali neka polja nisu obavezna za sve tipove osoba.

---

## 2026-06-24

ODLUKA:
Maloletni član bez email-a i telefona je dozvoljen, a zaštita od duplikata je best-effort bez veštačkog identifikatora u V1.

RAZLOG:
Maloletnici često nemaju sopstvene kontakt podatke; kontakt ide preko roditelja/staratelja.

---

## 2026-06-24

ODLUKA:
Istorija statusa članstva čuva se u `member_status_history`.

RAZLOG:
Jubileji, članarine, pauze i reaktivacije zahtevaju kompletnu istoriju ACTIVE/INACTIVE perioda, ne samo trenutni status u `society_members`.

## Finansije V1 — obračun mesečne članarine

Potvrđeno je da se član zadužuje prvog dana u mesecu za tekući mesec, sa rokom plaćanja prvog dana narednog meseca. Početak članstva i reaktivacija od 1. do 15. dana uključuju tekući mesec, dok početak od 16. dana omogućava prvo zaduženje narednog meseca.

Deaktivacija je izuzetak od pravila da finansijske promene važe od narednog meseca: deaktivacija do 15. dana ukida važenje tekućeg zaduženja, a deaktivacija od 16. dana ostavlja tekuće zaduženje. Prethodna dugovanja ostaju sačuvana.

Individualni gratis meseci računaju samo mesece koji bi inače bili naplativi. Meseci bez članarine za celo društvo ne troše individualni gratis period. Predsednik podešava naplative i nenaplatne mesece po konkretnom mesecu i godini, a redovne promene važe najranije od prvog dana narednog meseca.

Detaljna potvrđena pravila nalaze se u `docs/FINANCE_V1.md`.

---

## 2026-06-24

ODLUKA:
Funkcije članova su vezane za društvo kroz `society_member_functions`, nisu globalne.

RAZLOG:
Svako drustvo moze imati sopstvenu listu funkcija, a `UF_MEMBER_FORM` ne sme koristiti slobodan tekst za funkcije.

---

## 2026-06-24

ODLUKA:
Promena predsednika ide kroz `president_change_requests`, ne kroz običnu izmenu člana.

RAZLOG:
Jedno društvo može imati samo jednog aktivnog predsednika i Master admin mora kontrolisati promenu.

---

## 2026-06-24

ODLUKA:
`society_members.start_date` je obavezan i može biti datum iz prošlosti.

RAZLOG:
Aplikacija može evidentirati postojeća članstva koja su počela pre uvođenja sistema, a datum početka članstva je potreban za istoriju statusa i kasnije obračune.

---

## 2026-06-24

ODLUKA:
Prvi `member_status_history` red za novo članstvo kreira se iz `society_members.start_date`.

RAZLOG:
Početak članstva mora imati eksplicitan ACTIVE zapis u istoriji, sa `status = ACTIVE` i `effective_date = society_members.start_date`.

---

## 2026-06-24

ODLUKA:
`president_onboarding` dozvoljava predsedniku da vidi i izmeni svoja polja za članarinu.

RAZLOG:
Predsednik se tokom prvog logovanja unosi kao član kroz `UF_MEMBER_FORM`, pa ista forma mora pokriti i `membership_fee_required` i `membership_fee_amount`.

---

## 2026-06-24

ODLUKA:
Roditelj/staratelj se traži u `people` samo po email-u.

RAZLOG:
Email je lookup ključ za pronalaženje postojećeg roditelja/staratelja. Telefon ostaje obavezno kontakt polje, ali se ne koristi kao lookup ključ.

Dopuna 01.08.2026: ovlašćeni korisnik pri povezivanju maloletnog člana može da
dobije ograničene predloge iz globalnog `people` registra na osnovu dela
emaila. Pretraga nije ograničena na aktivno društvo, jer roditelj može biti član
drugog društva ili još uvek ne mora imati nijedno članstvo. Rezultat služi samo
za pronalaženje postojeće osobe i ne daje roditeljska prava bez sačuvane veze u
`person_guardians`.

---

## 2026-06-24

ODLUKA:
Sekcije društva se čuvaju u `sections`, a veze članova i sekcija u `member_sections`.

RAZLOG:
Sekcije su grupe/probne jedinice unutar jednog društva i moraju imati sopstveni status, istoriju i veze sa članovima bez upisivanja naziva sekcija direktno na `people` ili `society_members`.

---

## 2026-06-24

ODLUKA:
DOPUNJENO odlukom od 2026-06-28: funkcija člana nije isto što i sekcija, a sekcijska prava za `UR` i `KOREPETITOR` vode se kroz `section_role_assignments`.

RAZLOG:
Funkcije člana se čuvaju kroz `society_member_function_assignments`, dok se pripadnost sekcijama čuva kroz `member_sections`. Kada se `UR` ili `KOREPETITOR` dodeljuju za konkretnu sekciju, izvor sekcijskih prava je aktivan zapis u `section_role_assignments`.
---

## 2026-06-24

ODLUKA:
ZAMENJENO odlukom od 2026-07-02: izbor i izmena sekcija jesu deo `UF_MEMBER_FORM`; `MOJE SEKCIJE` upravlja samim sekcijama, UR-ovima, korepetitorima i pregledom clanova sekcije.

RAZLOG:
Nova poslovna odluka precizira podelu: `UF_MEMBER_FORM` upravlja clanom i njegovom pripadnoscu sekcijama kroz checkbox listu, dok `MOJE SEKCIJE` upravlja sekcijama kao organizacionim jedinicama.

---

## 2026-07-02

ODLUKA:
`UF_MEMBER_FORM` ostaje centralna forma za clana i ukljucuje izbor sekcija kojima clan pripada.

RAZLOG:
Pripadnost sekcijama je deo podataka o clanu i treba da se menja u istom toku u kojem se clan unosi ili uredjuje. Sekcije se prikazuju kao checkbox lista, jedan clan moze pripadati vecem broju sekcija, a promene se cuvaju kroz `member_sections` i `member_section_history`.

PRAVILA:

* Predsednik u `UF_MEMBER_FORM` vidi sve sekcije drustva, moze cekirati bilo koju sekciju i moze menjati pripadnost clana svim sekcijama.
* UR u `UF_MEMBER_FORM` vidi samo sekcije u kojima je on UR.
* UR moze cekirati samo sekcije u kojima je on UR.
* UR ne vidi ostale sekcije drustva i ne moze menjati clanstvo u sekcijama kojima nije UR.
* Izvor za UR ogranicenje je aktivan zapis u `section_role_assignments`.
* `MOJE SEKCIJE` ostaje glavni modul za upravljanje sekcijama, kreiranje sekcija, deaktivaciju sekcija, UR-ove, korepetitore i pregled clanova sekcije.
* `UF_MEMBER_FORM` upravlja clanom.
* `MOJE SEKCIJE` upravlja sekcijama.

---

## 2026-06-24

ODLUKA:
Pri approval-u društva sistem automatski kreira početne funkcije i početne sekcije.

RAZLOG:
Svako novo društvo mora odmah imati osnovnu organizacionu strukturu bez dodatnog ručnog podešavanja.

---

## 2026-06-24

ODLUKA:
Jedan clan moze imati vise funkcija, a dodele funkcija se cuvaju u `society_member_function_assignments`.

RAZLOG:
Funkcija vise nije jedno tekstualno polje na `society_members`. Funkcije se citaju iz `society_member_functions`, a clan moze imati nula, jednu ili vise dodeljenih funkcija bez dupliranja podataka.

---

## 2026-06-24

ODLUKA:
`UR` označava `Umetnički rukovodilac`, ne `Upravnik`.

RAZLOG:
`Upravnik` može postojati kao posebna funkcija, ali ne sme biti tumačenje skraćenice `UR`.

---

## 2026-06-27

ODLUKA:
`UF_MEMBER_FORM` za unos clana radi kao kontrolisani wizard tok koji prvo trazi email novog clana, validira ga i tek zatim otvara odgovarajuci nastavak forme.

RAZLOG:
Email u `people` je jedinstveni identifikator osobe kada postoji. Forma mora prvo utvrditi da li osoba vec postoji u `people`, da li je vec clan trenutnog drustva u `society_members`, i da li treba kreirati novu osobu ili samo novo clanstvo. Time se sprecava dupliranje osoba i razdvaja identitet osobe od clanstva u konkretnom drustvu.

---

## 2026-06-27

ODLUKA:
Roditelji/staratelji koji se unose kroz tok maloletnog clana ne upisuju se u `society_members`.

RAZLOG:
Roditelj/staratelj je osoba u `people` i veza sa detetom se cuva u `person_guardians`. Ako roditelj/staratelj kasnije postane clan drustva, isti `people.id` se koristi i dodaje se samo novi red u `society_members` ako za to drustvo vec ne postoji.

---

## 2026-06-27

ODLUKA:
Postojeci popunjeni podaci osobe pronadjene po email-u su read-only u obicnom add-member toku; prazna polja mogu se dopuniti, ali zastareli podaci se ne menjaju automatski.

RAZLOG:
Add-member tok sluzi za dodavanje osobe u drustvo, a ne za nekontrolisano menjanje identitetskih podataka. Izmenu postojecih podataka radi predsednik ili korisnik kome je predsednik dao odgovarajucu dozvolu.

---

## 2026-06-28

ODLUKA:
`UF_MEMBER_FORM` add-member tok na pocetku prvo prikazuje izbor `Maloletan clan` i email polje, pa tek zatim nastavlja kao tok za punoletnog ili maloletnog clana.

RAZLOG:
Kod punoletnog clana email polje predstavlja `Email novog clana` i koristi se za proveru osobe u `people.email`. Kod maloletnog clana prvi identifikacioni podatak nije email deteta nego `Email roditelja / staratelja`, jer maloletna deca cesto nemaju svoju email adresu i ne treba forsirati email deteta.

---

## 2026-06-28

ODLUKA:
U add-member toku za maloletnog clana dete se upisuje u `people` i `society_members`, roditelj/staratelj se ne upisuje u `society_members`, a veza se upisuje u `person_guardians` sa `relationship = GUARDIAN`.

RAZLOG:
`society_members` predstavlja clanstvo u drustvu, dok je roditelj/staratelj u ovom toku kontakt i odgovorna osoba za dete. Prvi roditelj/staratelj dobija `is_primary = true`, a drugi roditelj/staratelj, ako se koristi, dobija `is_primary = false`.

NAPOMENA:
Ova odluka dopunjuje ranije pravilo za `person_guardians.relationship`; za `UF_MEMBER_FORM` add-member tok koristi se `GUARDIAN`.

---

## 2026-06-28

ODLUKA:
Kod podataka clanova mora se razlikovati vidljivost podatka od prava izmene podatka.

RAZLOG:
Osnovni kontakt podaci kao ime, prezime, telefon i email mogu biti vidljivi korisnicima koji imaju pravo da vide clana, ali osetljivi podaci kao JMBG, broj pasosa, datum rodjenja, pol i licni identifikacioni podaci smeju biti vidljivi i izmenjivi samo predsedniku ili korisniku sa posebnom dozvolom predsednika.

---

## 2026-06-28

ODLUKA:
DOPUNJENO odlukom od 2026-07-02: UR vidi clanove sekcija u kojima je on UR i kroz `UF_MEMBER_FORM` moze menjati pripadnost clana samo tim sekcijama, dok predsednik vidi i menja sve clanove, podatke, roditelje/staratelje, status clanstva i pripadnost sekcijama u svom drustvu.

RAZLOG:
UR je sekcijska uloga, ne globalni administrator drustva. Zato UR moze videti osnovne kontakt podatke clanova i kontakte roditelja/staratelja maloletnika samo za svoje sekcije, bez pristupa JMBG-u i pasosu osim ako ima posebnu dozvolu.

---

## 2026-06-28

ODLUKA:
ZAMENJENO odlukom od 2026-07-02: moduli se jasno razdvajaju tako da `CLANOVI`/`UF_MEMBER_FORM` sluze za podatke osobe/clana i izbor sekcija clana, a `MOJE SEKCIJE` za upravljanje sekcijama, UR-ovima, korepetitorima i pregled clanova sekcije.

RAZLOG:
Sekcije imaju posebne dozvole, vise UR-ova, korepetitora, aktivne/neaktivne clanove i reaktivaciju ranijih clanstava. Nova odluka zadrzava `MOJE SEKCIJE` kao modul za strukturu sekcija, ali pripadnost konkretnog clana sekcijama menja se kroz `UF_MEMBER_FORM`.

---

## 2026-06-28

ODLUKA:
DOPUNJENO odlukom od 2026-07-02: samo predsednik moze kreirati, preimenovati, aktivirati/deaktivirati sekciju, dodeliti ili ukloniti UR-a i dodeliti ili ukloniti korepetitora. UR vidi samo sekcije u kojima je on UR, ne menja strukturu sekcije, ali kroz `UF_MEMBER_FORM` moze menjati pripadnost clanova svojim sekcijama.

RAZLOG:
Predsednik ima globalni pristup svim sekcijama drustva, dok je UR sekcijski ogranicena uloga. UR ne sme menjati strukturu drustva, naziv sekcije, UR-ove, korepetitora ili sekcije u kojima nije UR.

---

## 2026-06-28

ODLUKA:
Sekcija moze imati vise UR-ova, a korepetitor je posebna sekcijska uloga. Sekcijske uloge vode se kroz `section_role_assignments` sa `role` vrednostima `UR` i `KOREPETITOR`.

RAZLOG:
UR i korepetitor nisu obicni clanovi sekcije u smislu upravljackih prava. Sekcijski model mora omoguciti vise umetnickih rukovodilaca i zasebno evidentiranje korepetitora. Uloge dodeljuje samo predsednik, ne brisu se fizicki i deaktiviraju se preko statusa `INACTIVE`.

NAPOMENA 2026-07-26:
Odluka je delimično zamenjena. Funkcije i dalje dodeljuje samo predsednik, ali UR-a i korepetitora koji već imaju odgovarajuću funkciju može po sekcijama raspoređivati i korisnik sa posebnom dozvolom.

---

## 2026-06-28

ODLUKA:
UR prava se odredjuju preko aktivne dodele u `section_role_assignments`, a ne preko globalne funkcije u `society_member_functions`.

NAPOMENA 2026-07-26:
Odluka je dopunjena. Aktivna funkcija `UR` sada je obavezan uslov za izbor, a aktivna sekcijska dodela određuje početni opseg nadležnih sekcija. Dodatne dozvole mogu proširiti taj opseg.

RAZLOG:
UR je sekcijski ogranicena uloga. Jedna osoba moze biti UR u jednoj sekciji, bez istih prava u drugim sekcijama, pa izvor prava mora biti aktivan zapis za konkretnu sekciju i clana drustva.

---

## 2026-06-28

ODLUKA:
Sekcije i clanstva u sekcijama se ne brisu fizicki; koriste `ACTIVE` i `INACTIVE` status. `member_sections` cuva trenutno stanje clanstva u sekciji i za istog clana i istu sekciju sme da postoji samo jedan red.

RAZLOG:
Trenutno stanje mora biti jednoznacno. Kada se clan ukloni iz sekcije, red u `member_sections` se ne brise nego se status menja na `INACTIVE`; kada se ponovo vrati, isti red se reaktivira na `ACTIVE`, bez kreiranja duplikata.

---

## 2026-06-28

ODLUKA:
Istorija promena clanstva u sekciji cuva se u `member_section_history`, ne kroz duple redove u `member_sections`.

RAZLOG:
`member_sections` predstavlja trenutno stanje, a `member_section_history` predstavlja istoriju. Istorija belezi kada je clan dodat u sekciju, deaktiviran ili ponovo aktiviran, ko je izvrsio promenu, datum od kada promena vazi i napomenu ako postoji.

---

## 2026-06-28

ODLUKA:
Buduci workflow za korisnike bez prava direktne izmene bice zahtev za izmenu podataka predsedniku, potencijalno kroz tabelu `member_data_change_requests`.

RAZLOG:
Podaci se ne smeju menjati mimo dozvola. Korisnik bez direktnog prava izmene moze predloziti promenu, a predsednik je odobrava ili odbija; tek odobren zahtev menja podatke.

---

## 2026-07-16

ODLUKA:
V1 stranica `PRISUSTVO` služi samo za evidentiranje trenutne probe. Korisnik bira sekciju i otvara probu, dok sistem automatski beleži datum i vreme otvaranja. Vreme završetka beleži se automatski pri zatvaranju probe. Na stranici nema istorije ni statistike; ti podaci će se kasnije koristiti kroz `IZVEŠTAJI`.

RAZLOG:
Evidentiranje na probi mora biti brzo i prilagođeno radu dodirom na telefonu ili tabletu, bez ručnog unosa podataka koje sistem već može pouzdano odrediti.

---

## 2026-07-16

ODLUKA:
Otvaranjem probe pravi se snimak trenutno aktivnih članova izabrane sekcije. Svi početno imaju status `ABSENT`, a dodirom na člana status se menja između `ABSENT` i `PRESENT`. V1 ne razlikuje opravdano i neopravdano odsustvo i ne beleži kašnjenje.

RAZLOG:
Snimak čuva tačan spisak za konkretnu probu i sprečava da kasnije promene članstva u sekciji izmene već evidentiranu probu. Dva statusa omogućavaju najbrži tok evidentiranja.

---

## 2026-07-16

ODLUKA:
Otvorena proba i svaka promena prisustva odmah se čuvaju u bazi. Za jednu sekciju može postojati samo jedna otvorena proba; ponovni dolazak na stranicu nastavlja postojeću evidenciju. Osvežavanje ili napuštanje stranice ne sme izgubiti podatke.

RAZLOG:
Evidentiranje može trajati tokom cele probe i mora biti otporno na osvežavanje stranice, prekid rada pregledača i ponovno otvaranje aplikacije.

---

## 2026-07-16

ODLUKA:
Dok je proba otvorena, prisustvo mogu menjati predsednik i UR koji ima aktivnu dodelu za tu sekciju. Nakon zatvaranja UR ima samo pregled, a izmene može vršiti isključivo predsednik uz obavezan razlog.

RAZLOG:
UR vodi operativnu evidenciju svoje sekcije, dok predsednik ima odgovornost za kontrolisane naknadne ispravke finalizovanih podataka.

---

## 2026-07-16

ODLUKA:
Otvaranje i zatvaranje probe, kao i svaka promena statusa prisustva, imaju neizmenjivi audit trag koji beleži izvršioca, njegovu ulogu, vreme, staru i novu vrednost i razlog naknadne izmene. Identitet izvršioca dolazi iz prijavljenog korisnika i ne unosi se ručno.

RAZLOG:
Za podatke o prisustvu mora biti moguće utvrditi ko je šta i kada promenio, naročito kada predsednik ispravlja već zatvorenu probu.

---

## 2026-07-16

ODLUKA:
Greškom otvorena proba može se otkazati dok je otvorena. Otkazivanje ne briše probu, već postavlja status `CANCELLED` i beleži ko je i kada izvršio radnju. Otkazana proba ne računa se kao održana u budućim izveštajima.

RAZLOG:
Korisniku je potreban bezbedan izlaz iz greškom otvorene probe, ali audit i prethodno evidentirani podaci ne smeju nestati fizičkim brisanjem.

---

## 2026-07-16

ODLUKA:
Jedna sekcija može imati samo jednu istovremeno otvorenu probu, ali broj zatvorenih proba u istom danu nije ograničen. Nakon zatvaranja prethodne probe predsednik ili nadležni UR može odmah otvoriti novu.

RAZLOG:
Sekcija može realno imati više proba ili aktivnosti tokom istog dana; zaštita služi samo sprečavanju dve paralelne otvorene evidencije.

---

## 2026-07-20

ODLUKA:
Modul `PRISUSTVO` ima dva odvojena operativna prikaza: `EVIDENCIJA PROBE` za trenutnu probu i `PREGLED PROBA` za istoriju održanih i otkazanih proba. Pregled proba nije statistički izveštaj; statistika, poređenja i izvoz ostaju u budućem modulu `IZVEŠTAJI`.

Predsednik vidi probe svih sekcija društva i može ispraviti prisustvo na zatvorenoj održanoj probi uz obavezan razlog i audit trag. UR vidi probe samo sekcija za koje trenutno ima aktivnu UR dodelu i nema pravo izmene zatvorene probe. Otkazane probe ostaju vidljive, ne računaju se kao održane i ne mogu se menjati.

Nakon uspešnog zatvaranja probe prikazuje se kratka potvrda, a ekran evidencije se posle tri sekunde vraća u početno stanje. Zatvorena proba odmah postaje dostupna u `PREGLED PROBA`.

RAZLOG:
Vođenje trenutne probe treba da ostane brz i čist tok, dok predsednik i UR ipak moraju imati operativni uvid u ranije probe. Odvajanje pregleda od statističkih izveštaja sprečava mešanje evidencije, korekcija i analitike.

---

## 2026-07-20

ODLUKA:
Svaka sekcija ima svoje podrazumevano trajanje probe u minutima. Trajanje definiše i menja isključivo predsednik kroz kreiranje i podešavanje sekcije u modulu `MOJE SEKCIJE`. UR može videti trajanje sekcije, ali ga ne može menjati.

Dozvoljeno trajanje je od 30 do 240 minuta, u koracima od 15 minuta. Postojeće i nove sekcije podrazumevano dobijaju 120 minuta dok predsednik ne izabere drugu vrednost.

Pri otvaranju probe baza kopira trenutno trajanje sekcije u konkretan vremenski plan probe:

* `planned_end_at = opened_at + rehearsal_duration_minutes`
* `auto_close_at = planned_end_at + 30 minuta`

Vremena se zamrzavaju na zapisu probe. Kasnija promena trajanja sekcije utiče samo na buduće probe, ne na već otvorene ili završene probe.

Otvorena proba se automatski zatvara kada prođe `auto_close_at`. Automatsko zatvaranje izvršava baza, nezavisno od toga da li je aplikacija otvorena, i beleži `closed_by_role = SYSTEM` i `close_type = AUTOMATIC`. Ručno zatvaranje beleži `close_type = MANUAL`.

RAZLOG:
Različite sekcije imaju različito uobičajeno trajanje probe. Podešavanje na nivou sekcije uklanja ponavljanje pri svakom otvaranju, dok dodatnih 30 minuta štiti od prerano zatvorene evidencije. Serversko zatvaranje sprečava da proba ostane otvorena kada korisnik napusti aplikaciju.

---

## 2026-07-20

ODLUKA:
Uz `people.passport_number` čuva se i opciono polje `people.passport_expiry_date` tipa `date`. U `UF_MEMBER_FORM` datum važenja nalazi se neposredno uz broj pasoša.

Za nove unose važe uparena pravila: ako je broj pasoša unet, datum važenja je obavezan; datum važenja ne može se uneti bez broja pasoša. Datum može biti u prošlosti. Istekao pasoš ne blokira čuvanje, već se korisniku jasno prikazuje upozorenje.

Datum važenja pasoša je osetljiv podatak i koristi ista prava vidljivosti i izmene kao broj pasoša.

Budući sistem obaveštenja koristiće ovaj datum za upozorenje kada je pasoš istekao ili ističe u naredna tri meseca. Obaveštenje se šalje punoletnom članu, a za maloletnog člana primarnom roditelju/staratelju. Slanje obaveštenja nije deo trenutne implementacije.

RAZLOG:
Datum važenja je sastavni deo evidencije pasoša i omogućava buduće pravovremeno obaveštavanje. Dozvoljavanje istorijskog datuma čuva stvarno stanje dokumenta i ne sprečava unos člana.

---

## 2026-07-20

ODLUKA:
V1 modul `DOGAĐAJI` obuhvata koncerte i putovanja, President/UR approval workflow, sekcije, članove, goste iz `people`, planirano finansijsko učešće, nastupe i program. Konačna pravila i plan tabela definisani su u `docs/EVENTS_V1.md`.

Centralni repertoar uređuje se u tabu `REPERTOAR` modula `MOJE SEKCIJE`. Predsednik upravlja svim repertoarom, a UR samo repertoarom konkretne sekcije kada njegova aktivna sekcijska dodela ima `can_manage_repertoire = true`.

Događaj mora imati najmanje jednu sekciju za odobravanje. Učesnici i numere mogu se dodati nakon odobrenja. Putnik može biti član ili gost iz `people`, a gost nema obaveznu kategoriju i ne upisuje se u `society_members`.

Učesnici ne menjaju sopstveni status. Status učešća menja predsednik ili nadležni UR. UR direktno menja samo ranije dozvoljene osnovne podatke osobe; ostale podatke predlaže kroz `person_data_change_requests`, a predsednik ih odobrava ili odbija.

RAZLOG:
Model mora podržati planiranje pre konačnog spiska, putnike koji ne nastupaju, goste koji nisu članovi, više numera iste sekcije i buduću vezu repertoara sa garderobom, bez dupliranja osoba, učesnika ili finansijskih iznosa.
# 2026-07-24 — Master admin V1

ODLUKA:

Master admin je platformska uloga odvojena od članstva i funkcija u društvima. Panel koristi Dashboard, Društva, Zahteve, Licence, Audit i Podešavanja sistema. Master admin nema pristup pojedinačnim članovima ili sekcijama, već samo agregatnim brojevima aktivnih i neaktivnih članstava i sekcija.

V1 koristi statuse društva `ACTIVE` i `SUSPENDED`. Suspenzija je read-only režim koji ne zaustavlja automatske poslovne i tehničke procese. Arhiviranje i brisanje nisu deo V1.

Licence su unapred plaćeni mesečni, godišnji ili promotivni periodi. Ne postoje licencna zaduženja, delimične uplate, višak niti kredit. Promotivni periodi traju 3, 6 ili 12 meseci. Mesečno upozorenje šalje se 5 dana pre isteka, a godišnje i promotivno 30 i 7 dana pre isteka. Društvo se suspenduje prvog dana nakon isteka neprodužene licence.

RAZLOG:

Master adminu su potrebni platformski nadzor, upravljanje licencama i audit bez pristupa privatnim operativnim podacima društava. Prepaid periodi i strogo odvojena evidencija platformskih uplata pojednostavljuju V1 i sprečavaju mešanje sa finansijama članova.

Detaljna pravila nalaze se u `docs/MASTER_ADMIN_V1.md`.

---

# 2026-07-25 — Paketi i cene licenci

ODLUKA:

V1 koristi pakete `Malo društvo` (100 aktivnih članova, 6 aktivnih sekcija, 8 EUR mesečno ili 80 EUR godišnje), `Standard` (250 članova, 12 sekcija, 15 EUR mesečno ili 150 EUR godišnje) i `Veliko društvo` (500 članova, 20 sekcija, 25 EUR mesečno ili 250 EUR godišnje). Cene su bez poreza. Društva iznad ovih limita koriste poseban paket sa individualnim limitima i cenom po dogovoru.

Godišnja cena odgovara deset mesečnih naknada. Svi paketi u V1 imaju iste osnovne funkcije i razlikuju se po kapacitetu. Za limite se računaju samo aktivna članstva i aktivne sekcije.

RAZLOG:

Najveći broj folklornih društava ima između 100 i 200 članova, pa je `Standard` glavni paket. Progresija 8/15/25 EUR ostaje pristupačna, daje količinski popust većim društvima i ne pokušava da infrastrukturni trošak pogrešno obračunava linearno po članu.

---

# 2026-07-25 — Master admin menja cene paketa

ODLUKA:

Master admin u `Podešavanjima sistema` može pojedinačno menjati mesečnu i godišnju cenu aktivnog standardnog paketa. Valuta u V1 ostaje EUR, cene su bez poreza, moraju biti veće od nule i zahtevaju obavezan razlog promene.

Promena važi odmah samo za buduće licence. Postojeći licencni periodi zadržavaju istorijski snimak cene. Svaka promena čuva staru i novu cenu u Master admin auditu.

RAZLOG:

Cena mora biti upravljiva bez SQL intervencije, ali se istorija već dodeljenih i plaćenih perioda ne sme menjati retroaktivno.

---

# 2026-07-25 — Funkcije i dozvole društva

ODLUKA:

Funkcija člana, sekcijska uloga i dozvola u aplikaciji predstavljaju tri odvojena nivoa. UR ili korepetitor može biti dodeljen konkretnoj sekciji tek kada aktivni član ima odgovarajuću aktivnu funkciju na nivou društva.

Predsednička podešavanja koriste jedinstveni ekran dozvola. Nakon izbora funkcije podrazumevano se menjaju pravila svih članova te funkcije. Izborom `Pojedinačni izuzetak` predsednik bira konkretnog člana sa tom funkcijom i menja samo njegova efektivna prava.

Pojedinačna dozvola ima stanja `INHERIT`, `ALLOW` i `DENY`. Bez izuzetka sabiraju se prava svih aktivnih funkcija člana. Ekran mora prikazati izvore i konačno efektivno pravo kada član ima više funkcija.

RAZLOG:

Jedinstveni ekran je jednostavniji od odvojenih stranica po funkciji i po članu, ali jasno označen opseg promene sprečava slučajno menjanje prava svih korisnika. Funkcija daje osnovna prava, sekcijska dodela ograničava gde ona važe, a pojedinačni izuzetak rešava posebne slučajeve.

Detaljna pravila nalaze se u `docs/PERMISSIONS_V1.md`.

---

# 2026-07-25 — Zaključana prava predsednika

ODLUKA:

Predsednik ima puna prava pregleda i izmene svih delova i podataka svog društva. Ta prava su sistemska, zaključana i ne mogu se ukloniti podešavanjima funkcije ili pojedinačnim izuzetkom.

Finansijska istorija se ne može fizički brisati. Dozvola za njeno fizičko brisanje neće postojati ni za predsednika niti za bilo koju drugu funkciju ili člana.

RAZLOG:

Predsednik mora uvek moći da upravlja društvom, dok finansijska evidencija mora ostati trajna i proverljiva.

---

# 2026-07-25 — Obavezna i dodatna prava UR-a

ODLUKA:

Postojeća sekcijski ograničena prava UR-a predstavljaju njegova obavezna prava. UR podrazumevano vidi i operativno vodi samo sekcije u kojima ima aktivnu UR dodelu.

Predsednik može svim UR-ovima ili pojedinačnom UR-u dodatno dozvoliti pregled drugih sekcija, pregled i/ili izmenu svih podataka članova svojih ili drugih sekcija, ispravku zatvorene probe, promenu trajanja probe, odobravanje događaja i otkazivanje već odobrenog ili zakazanog događaja.

Pregled i izmena predstavljaju odvojena prava, a opseg `svoje sekcije` i `druge sekcije` mora biti jasno razdvojen.

Svaka izmena koju izvrši UR mora imati audit trag koji pokazuje ko je, kada i šta promenio, uključujući prethodnu i novu vrednost.

RAZLOG:

UR dobija dovoljan obavezni minimum za rad svojih sekcija, dok predsednik može proširiti odgovornost svim UR-ovima ili samo određenoj osobi bez davanja nekontrolisanog pristupa celom društvu.

---

# 2026-07-25 — Dodatna finansijska prava blagajnika

ODLUKA:

Blagajnik podrazumevano zadržava operativna finansijska prava: pregled obaveza i uplata, evidentiranje naplate, korišćenje kredita pri naplati kotizacije, pregled kalendara članarine i pokretanje opomena.

Predsednik može svim blagajnicima ili pojedinačnom blagajniku odvojeno dodeliti pravo da menja standardni iznos članarine, pojedinačni iznos ili režim članarine, kalendar članarine i finansijska podešavanja; da poništi pogrešnu uplatu ili povraćaj; da ispravi ranije finansijske podatke; i da pristupi detaljnom finansijskom auditu.

Svako od ovih prava predstavlja posebnu dozvolu. Dodela jednog prava ne uključuje automatski ostala finansijska prava.

Sve finansijske izmene blagajnika moraju imati audit trag sa izvršiocem, vremenom, razlogom, prethodnom i novom vrednošću.

RAZLOG:

Blagajnik zadržava bezbedan operativni minimum, dok predsednik može precizno proširiti njegovu odgovornost bez davanja kompletnog administrativnog pristupa finansijama.

---

# 2026-07-26 — Zajedničke dodatne dozvole, sekretar i upravnik

ODLUKA:

Blagajniku predsednik može dodatno dozvoliti pregled i/ili izmenu ostalih podataka članova. Pregled i izmena ostaju odvojene dozvole.

Dodatni pristup modulima definiše se kroz zajednički katalog. Predsednik može dodatno pravo pregleda ili izmene dodeliti bilo kojoj funkciji ili pojedinačnom članu sa tom funkcijom, uz poštovanje sistemskih ograničenja.

Sekretaru i upravniku mogu se dodeliti sva prava koja se odnose na svakodnevni i operativni rad društva, do nivoa operativnih prava predsednika. Ne mogu dobiti pristup podešavanjima funkcija i dozvola, bezbednosnim pravilima dozvola niti mogu menjati zaključana prava predsednika.

Sekretar i upravnik samom dodelom funkcije dobijaju globalni `read-only` pregled svih operativnih delova i podataka društva, bez pristupa podešavanjima dozvola. Ne mogu unositi, menjati niti izvršavati akcije koje menjaju stanje dok im predsednik ne dodeli odgovarajuće pravo.

Prava unosa, izmene i drugih operativnih akcija nisu automatska. Predsednik ih bira iz zajedničkog kataloga za celu funkciju ili pojedinačnu osobu.

Sve izmene moraju imati audit trag sa izvršiocem, vremenom, prethodnom i novom vrednošću.

RAZLOG:

Jedinstveni katalog sprečava dupliranje istih dozvola za svaku funkciju. Sekretar i upravnik mogu preuzeti široku operativnu odgovornost, ali upravljanje ovlašćenjima i bezbednosnim podešavanjima ostaje isključivo predsedniku.

---

# 2026-07-26 — Početna prava korepetitora

ODLUKA:

Korepetitor podrazumevano ima samo `read-only` pregled sopstvenog prisustva u sekcijama u kojima ima aktivnu dodelu korepetitora.

Ne može evidentirati niti menjati svoje ili tuđe prisustvo i ne vidi prisustvo drugih članova. Sama funkcija korepetitora ne daje pristup drugim podacima ili operativnim delovima aplikacije.

Predsednik mu može dodeliti dodatna prava iz zajedničkog kataloga, za sve korepetitore ili samo za pojedinačnu osobu.

RAZLOG:

Početna prava korepetitora treba da budu ograničena na njegovu ličnu evidenciju, dok se svaka šira odgovornost dodeljuje izričito.

---

# 2026-07-26 — Početna prava člana

ODLUKA:

Član vidi svoje lične podatke. Izmenu pokreće kroz standardnu formu, ali klik na `Sačuvaj` šalje zahtev predsedniku i ne menja podatke dok predsednik zahtev ne odobri.

Član vidi samo svoje prisustvo na probama. Vidi događaje na kojima učestvuje, njihov program i svoj status učešća, ali ne može sam potvrditi ili odbiti učešće; status menja predsednik ili nadležni UR.

Član vidi sekcije kojima pripada i njihov sadržaj bez prava izmene. Ovaj pregled ne uključuje lične, osetljive ili finansijske podatke drugih članova.

Član vidi svoje obaveze, kredite i istoriju uplata i može pregledati i preuzeti svoje potvrde o uplati.

Zahtev za izmenu podataka čuva predložene vrednosti, status, vreme slanja, odluku predsednika i vreme odluke.

RAZLOG:

Član dobija potpun lični i operativni pregled koji mu je potreban, dok se izmene ličnih podataka kontrolišu odobrenjem predsednika i podaci drugih članova ostaju zaštićeni.

---

# 2026-07-26 — Prava roditelja i staratelja

ODLUKA:

Roditelj ili staratelj za svoju decu ima ista prava koja član ima za sebe. Vidi njihove lične podatke, prisustvo, događaje, program, status učešća, sekcije, finansijske obaveze, kredite, uplate i potvrde.

Izmenu podataka deteta šalje predsedniku na odobrenje. Ne može sam menjati status učešća deteta niti uređivati podatke sekcije.

Prava važe isključivo za decu sa kojima postoji važeća roditeljska ili starateljska veza u evidenciji društva. Ako je roditelj istovremeno član, njegova lična i roditeljska prava se sabiraju.

RAZLOG:

Roditelj mora imati isti pregled i kontrolisani tok predlaganja izmena koji bi dete imalo za sebe, bez pristupa podacima drugih članova.

---

# 2026-07-26 — Objedinjavanje prava više funkcija

ODLUKA:

Kada član ima više aktivnih funkcija, njegova prava se sabiraju. Korisnik ne bira funkciju pod kojom koristi aplikaciju, već mu se svi dozvoljeni moduli, podaci i akcije prikazuju zajedno u jednom objedinjenom interfejsu.

Isto pravo se ne prikazuje više puta ako ga član dobija iz više funkcija. Sekcijska i druga ograničenja opsega ostaju važeća za pravo iz funkcije iz koje potiču, a pojedinačni `ALLOW` i `DENY` izuzeci primenjuju se prema pravilima efektivnih dozvola.

RAZLOG:

Jedinstven prikaz je jednostavniji za korisnika i sprečava potrebu za menjanjem aktivne funkcije, dok sistem i dalje tačno kontroliše opseg svakog prava.

---

# 2026-07-26 — Katalog dozvola za članove i lične podatke

ODLUKA:

Katalog modula članova odvojeno obuhvata pregled osnovnih, kontakt i osetljivih podataka, roditelja/staratelja, istorije članstva i pripadnosti sekcijama; kao i slanje zahteva za izmenu sopstvenih podataka ili podataka deteta, unos člana, izmenu osnovnih/kontakt i osetljivih podataka, status članstva, pripadnost sekcijama, roditelje/staratelje i odluke o zahtevima za izmenu.

Dozvole mogu važiti za sopstvene podatke, sopstvenu decu, članove nadležnih sekcija ili sve članove društva. Izmena podrazumeva pregled u istom opsegu, dok su osetljivi podaci posebno pravo.

Fizičko brisanje člana i istorije nije dozvoljeno. Dodela funkcija ostaje u predsedničkim podešavanjima. Osnovna i kontakt polja grupišu se kako se ne bi pravila nepregledna dozvola za svako pojedinačno polje.

RAZLOG:

Ovaj katalog omogućava preciznu kontrolu podataka i opsega bez nepotrebnog usitnjavanja interfejsa.

---

# 2026-07-26 — Katalog dozvola za sekcije

ODLUKA:

Katalog sekcija obuhvata pregled sekcija, njihovih članova, UR-ova, korepetitora, statusa i osnovnih podataka; kao i kreiranje, izmenu, aktiviranje/deaktiviranje, upravljanje članstvom i raspoređivanje UR-ova i korepetitora.

Dozvole mogu važiti za sekcije u kojima korisnik ima aktivnu nadležnost ili za sve sekcije društva.

Predsednik može sekretaru, upravniku ili drugom ovlašćenom korisniku dati pravo da dodeljuje i uklanja postojeće UR-ove i korepetitore po sekcijama. Ovlašćeni korisnik može izabrati samo člana koji već ima odgovarajuću aktivnu funkciju u društvu i ne može sam dodeliti ili ukloniti tu funkciju.

Sekcije, istorija članstva i sekcijske uloge ne brišu se fizički. Sve promene moraju imati audit trag.

RAZLOG:

Veliko društvo mora moći da delegira operativno upravljanje sekcijama sekretaru ili upravniku, dok kontrola dodele funkcija i dalje ostaje u predsedničkim podešavanjima.

---

# 2026-07-26 — Katalog dozvola za prisustvo

ODLUKA:

Katalog prisustva obuhvata pregled sopstvenog i tuđeg prisustva, otvaranje probe, evidentiranje prisustva dok je proba otvorena, zatvaranje i otkazivanje otvorene probe, ispravku zatvorene probe i promenu podrazumevanog trajanja probe.

Dozvole mogu važiti za sopstveno prisustvo, sopstvenu decu, nadležne sekcije ili sve sekcije društva.

Predsednik ima sva prava. UR podrazumevano vodi otvorene probe svojih sekcija i pregleda zatvorene, dok dodatno može dobiti ispravku zatvorene probe i promenu trajanja. Član, roditelj i korepetitor imaju ranije definisane lične preglede, a sekretar i upravnik globalni `read-only` pregled.

Evidencija probe se ne briše. Otkazivanje ostaje u istoriji, ispravka zatvorene probe zahteva razlog, a svaka radnja ima neizmenjiv audit trag.

RAZLOG:

Odvojene dozvole omogućavaju delegiranje operativnog rada bez gubitka kontrole nad istorijom i naknadnim ispravkama.

---

# 2026-07-26 — Katalog dozvola za događaje i repertoar

ODLUKA:

Katalog događaja odvojeno obuhvata pregled događaja, sekcija, učesnika, programa i planiranih kotizacija; kao i kreiranje nacrta, slanje na odobrenje, odobravanje/odbijanje, izmenu i otkazivanje odobrenog događaja, sekcije, učesnike, statuse, kotizacije, nastupe, program i izvođače.

Katalog repertoara obuhvata pregled, dodavanje, izmenu i aktiviranje/deaktiviranje numere, kao i povezivanje postojeće numere sa programom.

Dozvole koriste opseg nadležnih, kreiranih, ličnih, događaja dece ili svih događaja i sekcija društva. Predsednik ima sva prava; UR zadržava ranije definisan operativni tok za svoje sekcije; sekretar i upravnik imaju globalni `read-only` pregled; član i roditelj vide svoje događaje; korepetitor nema početni pristup.

Planirana kotizacija, odobravanje i otkazivanje predstavljaju odvojene dozvole. Pristup događaju ne otvara automatski osetljive podatke učesnika.

Događaji i numere se ne brišu fizički. Odbijeni, otkazani i istorijski zapisi ostaju sačuvani, a sve promene imaju audit trag.

RAZLOG:

Odvajanje pregleda, pripreme, finansijskih odluka, odobravanja i otkazivanja omogućava bezbedno delegiranje velikim društvima.

---

# 2026-07-26 — Katalog finansijskih dozvola

ODLUKA:

Finansijske dozvole dele se na pregled, operativni rad, ispravke i podešavanja članarine.

Pregled obuhvata obaveze, uplate, kredite, povraćaje, operativnu istoriju, kalendar i pravila članarine, detaljni audit i potvrde. Operativni rad obuhvata uplate, raspodelu, korišćenje kredita za kotizaciju, povraćaje i slanje poruka. Ispravke obuhvataju poništavanje uplata i povraćaja i kontrolisanu ispravku ranijih podataka. Podešavanja obuhvataju standardnu i pojedinačnu članarinu, režim člana, mesece naplate i druga finansijska pravila.

Dozvole mogu važiti za sopstvene finansije, finansije sopstvene dece ili sve finansije društva.

Predsednik ima sva prava. Blagajnik podrazumevano ima globalni pregled i operativnu naplatu, a rizičnije radnje dobija dodatno. Sekretar i upravnik imaju globalni `read-only` pregled bez detaljnog audita, a finansijska podešavanja mogu dobiti dodatno. Član i roditelj imaju ranije definisan lični pregled.

Finansijski zapisi se ne brišu niti direktno prepravljaju. Poništavanje, povraćaj i ispravka zahtevaju razlog i audit. Pregled, naplata, poništavanje, finansijska podešavanja i detaljni audit predstavljaju odvojena prava.

RAZLOG:

Razdvajanje svakodnevne naplate od ispravki, audita i podešavanja sprečava da jedna široka dozvola otvori sve finansijske radnje.

---

# 2026-07-26 — Ispravka: podešavanja dozvola isključivo za predsednika

ODLUKA:

Isključivo predsednik vidi i koristi deo `Podešavanja dozvola`. Nijedna druga funkcija niti pojedinačni član ne može videti ovaj deo ili dobiti pravo upravljanja zajedničkim pravima funkcija i pojedinačnim izuzecima.

Ograničenje se ne odnosi na sva podešavanja aplikacije. Ranije dogovorena mogućnost da blagajnik dobije promenu standardne ili pojedinačne članarine, kalendara naplate ili drugih finansijskih podešavanja ostaje važeća.

Ista prava podešavanja članarine predsednik može dodeliti sekretaru i upravniku, celoj funkciji ili pojedinačnoj osobi.

Pravo upravljanja dozvolama nije deo zajedničkog kataloga i ne može se otvoriti pojedinačnim `ALLOW` izuzetkom. Zabrana mora biti sprovedena u bazi i na serverskoj strani, ne samo sakrivanjem dela interfejsa.

RAZLOG:

Predsednik može delegirati poslovne i finansijske poslove, ali kontrola nad tim ko dobija koja prava mora ostati isključivo predsednička.

---

# 2026-07-26 — Audit dozvole i obavezna dopuna za nove module

ODLUKA:

Operativna istorija prati pravo pregleda modula i njegov opseg, dok je detaljni audit posebna dodatna dozvola za svaki modul. Audit funkcija i dozvola vidi samo predsednik. Audit zapisi se ne mogu menjati niti brisati, osetljive radnje zahtevaju razlog, a automatske promene jasno se razlikuju od ručnih.

Svaka nova kartica ili modul mora istovremeno dopuniti katalog dozvola. Modul nije potpuno definisan niti spreman za implementaciju dok nisu određeni pregled, unos, izmena, posebne radnje, opsezi, početna i dodatna prava, predsednička ograničenja, audit, ponašanje više funkcija i zaštita u bazi i na serverskoj strani.

Ovo pravilo obavezno važi i za buduće module kao što je `Garderoba`.

RAZLOG:

Dozvole ne smeju naknadno da se dodaju kao zakrpa. Njihovo definisanje zajedno sa poslovnim pravilima sprečava neovlašćen pristup i nedoslednosti između modula.

---

# 2026-07-26 — Prelazak sa DEV uloga na Supabase Auth

ODLUKA:

Ne uvodi se dodatni dev adapter za novi sistem dozvola. Rezultat `president_actor_count = 0` nastao je zato što test uloga iz browsera nije stvarna dodela funkcije aktivnom članu u bazi.

Pre izrade ekrana dozvola radi se read-only Auth readiness dijagnostika, zatim se definišu stvarni korisnički identitet, kontekst društva, onboarding i login. Moduli se potom jedan po jedan prebacuju na centralne dozvole i finalni RLS.

Postojeće DEV politike i testni tokovi ne uklanjaju se unapred. Odgovarajući DEV pristup uklanja se tek kada je Auth/RLS zamena konkretnog modula implementirana i proverena.

Detaljan plan i mesto nastavka nalaze se u `docs/AUTH_V1_READINESS.md`.

RAZLOG:

Novi dev most bi zahtevao dodatni privremeni kod i mogao bi prikriti probleme stvarnog identiteta. Kontrolisan prelazak modul po modul čuva funkcionalnost aplikacije i smanjuje rizik od bezbednosnih praznina.

---

# 2026-07-26 — Potvrđeni Supabase Auth V1 korisnički tok

ODLUKA:

Početna registracija nudi samo jedinog Master admina i dozvoljena je isključivo za `knezevic.bojan78@gmail.com`. Master admin postaje aktivan nakon potvrde emaila, prvog logina i obaveznog TOTP drugog faktora. Master admin identitet ostaje platformski i ne može biti povezan sa osobom, članstvom, funkcijom ili roditeljskom vezom u društvu.

Nakon aktiviranja Master admina dostupne su registracije predsednika, člana i roditelja/staratelja. Predsednik podnosi skraćeni zahtev. Master admin pri odobravanju obavezno dodeljuje licencu, kreira početno društvo i pokreće Auth aktivaciju. Društvo i licenca ostaju neoperativni do završetka predsedničkog onboardinga kroz postojeće `SocietyDataForm` i `UF_MEMBER_FORM`.

Član i roditelj/staratelj mogu aktivirati nalog samo ako ih je predsednik prethodno evidentirao u `people`, uz postojeće članstvo odnosno roditeljsku vezu. Postojeći korisnik zadržava isti Auth nalog u svim društvima. Novo članstvo i roditeljska veza zahtevaju eksplicitnu potvrdu ili odbijanje posle logina.

Korisnik sa više dozvoljenih društava bira društvo na Dashboardu. Izbor društva nije dokaz ovlašćenja; svaki bazni tok proverava stvarni Auth identitet i važeći opseg. Roditeljska prava prestaju sa punoletstvom, ali punoletni član može pojedinačnom roditelju dati ista prava za konkretno društvo i kasnije ih deaktivirati.

RAZLOG:

Tok sprečava javno pravljenje nepoznatih osoba, dupliranje identiteta i automatsko otvaranje podataka samo na osnovu emaila. Istovremeno ostaje dovoljno jednostavan za V1 i ponovo koristi postojeće forme i poslovne modele.

Detaljna pravila i granice nalaze se u `docs/AUTH_V1_READINESS.md`.

---

# 2026-07-26 — Auth readiness dijagnostika na praznoj bazi

ODLUKA:

Read-only dijagnostika `supabase/auth-v1-readiness-diagnostic.sql` uspešno je pokrenuta nakon kontrolisanog brisanja testnih podataka. Potvrđeno je nula Auth korisnika, društava, osoba, članstava, duplih emailova, Auth konflikata i neusaglašenih `people`/`society_members` Auth veza.

Popis je pronašao 49 `public` politika dostupnih javnim ili korisničkim ulogama i 58 javno izvršivih RPC funkcija. Ovaj rezultat se tretira kao DEV inventar. Politike i grantovi ne uklanjaju se odjednom, već tek kada konkretan modul dobije proverenu Auth/RLS zamenu.

RAZLOG:

Prazna baza omogućava uvođenje prvog Auth identiteta bez migracije postojećih korisnika. Postojeći DEV pristup ipak mora ostati evidentiran i kontrolisano uklonjen tokom prelaska.

---

# 2026-07-26 — Brendirani Auth emailovi pre stvarnih korisnika

ODLUKA:

Pre uključivanja stvarnih korisnika Folkloraš dobija sopstveni SMTP servis i
verifikovani domen. Auth poruke se šalju kao `Folkloraš`, sa šablonima na
srpskom za potvrdu emaila, aktivaciju, poziv, reset lozinke i bezbednosna
obaveštenja. Aktivacija predsednika može u sadržaju da navede naziv društva,
ali pošiljalac ostaje platformski Folkloraš.

RAZLOG:

Podrazumevani Supabase pošiljalac i šabloni namenjeni su razvoju i ne
predstavljaju identitet gotove aplikacije. Jedinstveni platformski pošiljalac
olakšava prepoznavanje bezbednosnih poruka, dok kontrolisani naziv društva
korisniku daje potreban kontekst.

---

# 2026-07-27 — Kompaktan raspored svih formi

ODLUKA:

Administrativne, onboarding i operativne forme na širokom ekranu ne koriste
jedno kratko polje po punom redu. Kratka polja se raspoređuju u tri ili četiri
kolone kada prostor dozvoljava, na tabletu u dve, a na telefonu u jednu.
Punu širinu dobijaju samo podaci kojima je ona stvarno potrebna.

Zajedničke komponente kao `SocietyDataForm` i `UF_MEMBER_FORM` ostaju jedine
forme za svoje podatke, ali svaki workflow dobija odgovarajuću kompaktnu CSS
varijantu. Ponovna upotreba komponente nije opravdanje za preglomazan raspored.

RAZLOG:

Velike kartice i kratka polja pune širine stvaraju nepotrebno skrolovanje,
otežavaju pregled povezanih podataka i usporavaju rad. Kompaktan responzivni
raspored čuva čitljivost, validaciju i mobilnu upotrebljivost uz znatno bolji
radni pregled.

Detaljno obavezno pravilo dodato je u `docs/CGPT.md`.

---
# 2026-07-27 — Postojeći funkcionalni moduli završili DEV → Auth V1 prelazak

## Odluka

Prelazak postojećih funkcionalnih modula na Auth V1 smatra se završenim nakon
što je aktivna baza vratila nula DEV politika, nula direktnih anonimnih prava
nad poslovnim tabelama i nula neočekivanih anonimnih funkcija.

Aplikacioni kod više ne koristi direktne `.from(...)` pozive. Poslovni podaci
se čitaju i menjaju isključivo kroz kontrolisane RPC tokove koji identitet i
dozvole određuju iz Supabase Auth sesije.

Tri namerna anonimna toka ostaju: bootstrap status, javni cenovnik licenci i
slanje predsedničkog zahteva. Master admin bootstrap zahteva potvrđenu Auth
sesiju i nije anoniman.

## Posledice

* Naredno testiranje ne vraća aplikaciju na DEV politike ili actor ID iz browsera.
* Novi modul mora istovremeno dobiti serversku proveru dozvole i dijagnostiku
  `authenticated/anon`.
* `Moji podaci`, `Moja deca`, `Garderoba` i `Izveštaji` ostaju budući moduli,
  a ne nedovršeni deo bezbednosne migracije postojećih modula.
* Detaljan dokaz, obuhvat i mesto nastavka nalaze se u
  `docs/AUTH_V1_COMPLETION_2026-07-27.md`.

---
# 2026-07-27 — Korepetitori u evidenciji probe

## Odluka

Sekcija može imati više korepetitora. Korepetitor ne mora biti član društva,
ali mora biti jedinstvena osoba u `people`. Veza osobe i sekcije vodi se kroz
`section_accompanists`, odvojeno od članstva u društvu i od dodele UR-a.

Za svakog korepetitora i svaku sekciju posebno postoji podešavanje
`attendance_enabled`. Samo aktivni korepetitori kojima je ovo uključeno ulaze
u snimak nove probe. Promena podešavanja utiče samo na buduće probe; već
otvorene i završene probe ostaju nepromenjene.

Na evidenciji probe korepetitori se prikazuju prvi, u centriranoj grupi preko
cele širine. Tek ispod njih stoje dve kolone `Devojke` i `Momci`. Ako je ista
osoba istovremeno član sekcije i korepetitor, postoji samo jedan zapis
prisustva: osoba ostaje u svojoj polnoj koloni, uz oznaku `Korepetitor`.

Upravljanje korepetitorima štiti posebna dozvola
`sections.manage_accompanists`. Predsednik je ima kao zaključano pravo, a može
je delegirati kroz postojeći sistem dozvola. Samo evidentiranje korepetitora
ne daje toj osobi pravo da vidi ili menja tuđe prisustvo.

## Razlog

Korepetitor može biti angažovan spolja, više korepetitora može raditi sa istom
sekcijom, a njihovo prisustvo ne mora svako društvo da prati. Odvojena veza i
prekidač rešavaju sva tri slučaja bez lažnog članstva i bez duplih zapisa.
