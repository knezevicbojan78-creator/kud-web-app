# Pravila Projekta

## Dokumentacija

* Dokumentacija baze mora jasno razlikovati:
  * tabela postoji u aktivnoj Supabase bazi
  * tabela postoji u repo SQL/migration fajlu
  * tabela postoji samo kao plan

## Dozvole novih modula

* Svaka nova kartica ili modul mora istovremeno dopuniti `docs/PERMISSIONS_V1.md`.
* Modul nije potpuno definisan niti spreman za implementaciju dok nisu određeni katalog dozvola, opsezi, početna prava funkcija, dodatna prava, zaključana predsednička prava i audit.
* Zaštita novog modula mora biti planirana u bazi i na serverskoj strani; sakrivanje kontrola u interfejsu nije dovoljan model dozvola.
* Provera dozvola je obavezan deo prihvatanja svakog budućeg modula, uključujući buduću karticu `GARDEROBA`.
* Masovni unos članova koristi dozvolu `members.bulk_import`.
* Predsednik društva ovu dozvolu uvek ima u opsegu svog društva i ona je za funkciju `Predsednik` zaključana.
* Predsednik može istu dozvolu dodeliti drugim funkcijama ili pojedinačnim članovima; kod njih dozvola nije zaključana i može se naknadno ukinuti.
* Pristup masovnom unosu proverava se serverski za trenutno aktivno društvo. Greška provere nikada ne sme automatski odobriti pristup.

## Obavezna UI pravila

* Svi operativni ekrani moraju biti projektovani kompaktno i sa jasnom vizuelnom hijerarhijom.
* Osnovni font aplikacije je `Nunito Sans`, ugrađen preko Next.js font sistema.
* Preporučene težine su: običan tekst `400`, navigacija i oznake polja `500-600`, dugmad `600`, naslovi `700`.
* Težinu `800` i veću koristiti samo izuzetno za male statusne oznake; ne koristiti je kao podrazumevanu težinu dugmadi i navigacije.
* Vertikalni skrol cele stranice treba izbegavati gde god je moguće; duge liste i detaljni paneli koriste sopstveni kontrolisani skrol.
* Forme koje nisu stalno potrebne ne prikazuju se unapred, već se otvaraju preko jasnog dugmeta, checkbox-a ili sklopivog panela.
* Primarni sadržaj ekrana je pregled postojećih podataka; forme za dodavanje i izmenu su sekundarne i ne smeju nepotrebno zauzimati prostor.
* Na manjim ekranima dozvoljen je prirodan skrol kada bi unutrašnji skrol otežao korišćenje.
* Modalne forme ne smeju imati horizontalni skrol.
* Podaci koji se retko koriste, kao što su putna dokumenta, prikazuju se u sklopivom bloku.

## Forme

* Postoji samo jedna univerzalna forma za društvo:
  `app/_components/SocietyDataForm.tsx`

* `/registracija-drustva` i `/drustva/[id]` mogu biti različite rute, ali moraju koristiti istu `SocietyDataForm` komponentu.

* Zabranjeno je praviti paralelne forme za društvo bez prethodnog odobrenja.

* Interno polje za PIB u `SocietyDataForm` je:
  `pib`

* Postoji samo jedna forma za člana:
  `UF_MEMBER_FORM`

* `UF_MEMBER_FORM` je jedina univerzalna forma za unos i izmenu članova.

* `UF_MEMBER_FORM` mora da se koristi za:

  * kreiranje novog člana
  * izmenu postojećeg člana
  * onboarding predsednika posle prvog logovanja
  * buduće role-based tokove unosa članova

* Zabranjeno je praviti posebnu formu za profil predsednika.

* Onboarding predsednika mora da poziva `UF_MEMBER_FORM` u posebnom režimu, na primer:
  `mode = "president_onboarding"`

* `UF_MEMBER_FORM` mora koristiti sledeća imena polja:

  * `people.birth_date` je polje za datum rođenja
  * `society_member_function_assignments` je veza clana i funkcije
  * `society_members.status` je status članstva, npr. `ACTIVE` ili `INACTIVE`
  * `society_members.start_date` je obavezan datum početka članstva

* `UF_MEMBER_FORM` ne sme uvoditi paralelna imena kao što su `date_of_birth`, `joined_at`, `member_status`, `role_in_society` ili `is_active`.

## UF_MEMBER_FORM Kontrolisani Tok

* `UF_MEMBER_FORM` se ne posmatra kao obicna forma koja odmah prikazuje sva polja, vec kao kontrolisani tok / wizard forma.

* Kada korisnik klikne `DODAJ CLANA`, forma na pocetku mora odmah razlikovati dva toka:
  * dodavanje punoletnog clana
  * dodavanje maloletnog clana

* Na pocetku forme prikazuju se:
  * checkbox / switch `Maloletan clan`
  * email polje

* Ako `Maloletan clan` nije oznacen:
  * email polje predstavlja `Email novog clana`
  * vaze postojeca pravila email-first wizard toka za punoletnog clana
  * sistem proverava `people.email`
  * ako osoba postoji, povlaci podatke
  * ako osoba postoji i nije clan trenutnog drustva, dodaje je u `society_members`
  * ako osoba ne postoji, kreira `people` i `society_members`

* Ako je `Maloletan clan` oznacen:
  * email polje vise ne predstavlja email deteta
  * email polje postaje `Email roditelja / staratelja`
  * prvi identifikacioni podatak za maloletnog clana je email roditelja/staratelja, ne email deteta
  * razlog je da maloletna deca cesto nemaju svoju email adresu i ne treba forsirati email deteta
  * sistem proverava email roditelja/staratelja u `people.email`
  * ako roditelj/staratelj postoji, koristi postojeci `person_id` i povlaci njegove podatke
  * ako roditelj/staratelj ne postoji, otvara polja za unos roditelja/staratelja i pri snimanju kreira novi `people` zapis za roditelja/staratelja
  * zatim se otvara blok za unos podataka maloletnog clana

* Za maloletnog clana:
  * dete se upisuje u `people`
  * dete se upisuje u `society_members`
  * roditelj/staratelj se ne upisuje u `society_members` iz ovog toka
  * veza dete-roditelj se upisuje u `person_guardians`
  * `relationship = GUARDIAN`
  * `is_primary = true` za prvog roditelja/staratelja

* Email novog clana je obavezan u add-member toku za punoletnog clana.

* Za maloletnog clana email deteta se ne forsira; obavezan je email prvog roditelja/staratelja.

* Provera email-a ide ovim redom:
  * prvo proveriti da li je email prazan
  * zatim proveriti da li je email u validnom email formatu
  * tek zatim pretraziti `people.email`

* `people.email` mora predstavljati jedinstveni identifikator osobe kada postoji.

* Jedna osoba = jedan email.

* Dva razlicita clana, roditelja ili staratelja ne smeju imati isti email.

* Ako email postoji u `people`:
  * ne kreira se novi `people` zapis
  * sistem povlaci postojece podatke osobe
  * proverava se da li ta osoba vec ima red u `society_members` za trenutno drustvo
  * ako vec jeste clan istog drustva, prikazuje se poruka da je osoba vec clan tog drustva
  * ako nije clan tog drustva, postojeca osoba se moze dodati u `society_members` za trenutno drustvo

* Ako email ne postoji u `people`:
  * otvaraju se prazna polja za unos nove osobe
  * pri snimanju se kreira novi `people` zapis
  * zatim se kreira `society_members` zapis za trenutno drustvo

* Ako korisnik promeni email nakon sto su podaci vec ucitani:
  * forma mora resetovati prethodno ucitane podatke
  * forma mora ponovo validirati email
  * forma mora ponovo proveriti `people.email`

* Ako postojeca osoba ima popunjene podatke, postojece vrednosti su read-only u add-member toku.

* Prazna ili nedostajuca polja postojece osobe mogu se dopuniti tokom add-member toka.

* Ako je postojeci podatak zastareo, ne menja se automatski kroz obican add-member tok.

* Zastarele postojece podatke moze azurirati predsednik ili korisnik kome je predsednik dao odgovarajucu dozvolu za izmenu podataka osobe.

* Provere ne smeju raditi samo na dugme `SNIMI`.

* Provere se moraju pokretati odmah pri unosu, napustanju polja i prelasku na sledece polje, posebno za:
  * email clana
  * JMBG
  * broj pasosa
  * datum vazenja pasosa
  * email roditelja/staratelja

* Dugme `SNIMI` mora ponovo izvrsiti kljucne provere radi sigurnosti.

* Nakon unosa `birth_date`, `UF_MEMBER_FORM` odmah proverava da li je osoba maloletna.

* Ako je osoba maloletna, odmah ispod `birth_date` otvara se blok za roditelje/staratelje.

* Blok za roditelje/staratelje dolazi pre ostalih polja clana.

* Roditelj/Staratelj 1 je obavezan za maloletnog clana.

* Za Roditelja/Staratelja 1 prvo se unosi email.

* Ime, prezime i telefon Roditelja/Staratelja 1 su vidljivi, ali disabled dok se email ne unese i proveri.

* Ako email Roditelja/Staratelja 1 postoji u `people`, sistem automatski popunjava ime, prezime i telefon i koristi postojeci `person_id`.

* Ako email Roditelja/Staratelja 1 ne postoji u `people`, ime, prezime i telefon se otkljucavaju za rucni unos i pri snimanju se kreira novi `people` zapis.

* Roditelj/Staratelj 2 je opcion.

* Ako korisnik zapocne unos Roditelja/Staratelja 2, vaze ista pravila kao za Roditelja/Staratelja 1:
  * prvo se unosi email
  * validira se email format
  * proverava se `people.email`
  * ako postoji, koristi se postojeci `person_id`
  * ako ne postoji, pri snimanju se kreira novi `people` zapis
  * veza se upisuje u `person_guardians` sa `is_primary = false`

* Roditelji/staratelji se iz ove forme ne upisuju u `society_members`.

* Roditelji/staratelji iz child/guardian toka upisuju se samo u:
  * `people`
  * `person_guardians`

* Ako roditelj koji je ranije unet kroz child/guardian tok kasnije postane clan drustva:
  * pri unosu clana sistem ga pronalazi po email-u u `people`
  * koristi isti `person_id`
  * dodaje ga samo u `society_members` ako vec nije clan tog drustva

* Dokumentacija i implementacija moraju jasno razlikovati:
  * `people` = sve osobe u sistemu
  * `society_members` = osobe koje su clanovi odredjenog drustva
  * `person_guardians` = veza izmedju maloletnog clana i roditelja/staratelja

* `UF_MEMBER_FORM` mora podržati maloletne članove kroz `person_guardians`, ne kroz parent polja na detetu.

* Roditelj/staratelj se uvek čuva kao osoba u `people`.

* Roditelj/staratelj može, ali ne mora, biti član društva u `society_members`.

* Za maloletnog člana Roditelj/Staratelj 1 je obavezan.

* Roditelj/Staratelj 2 je opcion.

* Oba staratelja su ravnopravne veze.

* U add-member toku za maloletnog clana `person_guardians.relationship` koristi vrednost `GUARDIAN`.

* Ne uvoditi dodatne kategorije odnosa.

* Pri unosu roditelja/staratelja prvo proveriti postojeću osobu u `people` po email-u i ponovo koristiti postojeći zapis ako postoji.

* Ista osoba sme biti i roditelj/staratelj i član društva, bez dupliranja u `people`.

* Zabranjeno je dodavati posebna parent/staratelj polja direktno na record deteta.

* `people.email` je unique kada postoji i glavni je praktični identifikator za pronalaženje postojećih osoba.

* `people.phone`, `people.user_id`, `people.jmbg` i `people.passport_number` su unique kada postoje.

* Kod novog unosa broj pasosa i datum vazenja pasosa unose se zajedno. Datum bez broja i broj bez datuma nisu dozvoljeni.

* Datum vazenja pasosa moze biti u proslosti. Istekao pasos prikazuje upozorenje, ali ne blokira cuvanje.

* Datum vazenja pasosa ima ista prava vidljivosti i izmene kao broj pasosa.

* Buduca obavestenja za pasos salju se punoletnom clanu, a za maloletnog clana primarnom roditelju/staratelju kada je pasos istekao ili istice u naredna tri meseca.

* `jmbg` može postojati, ali nije obavezan i ne sme biti glavni lookup identifikator.

* `people.gender` mora biti izabrano iz vrednosti `Muško` ili `Žensko`.

* Osoba iz `people` može biti član više društava kroz više redova u `society_members`.

* Roditelj/staratelj koji kasnije dobije korisnički nalog koristi isti postojeći `people` zapis; samo se naknadno povezuje `user_id`.

* Maloletni član bez email-a i telefona je dozvoljen.

* Za maloletnog člana bez email-a i telefona zaštita od duplikata je best-effort i ne uvodi se veštački identifikator u V1.

* Obavezna polja za punoletnu osobu / punoletnog člana su `first_name`, `last_name`, `email` i `phone`.

* Obavezna polja za predsednika tokom onboardinga su `first_name`, `last_name`, `email` i `phone`.

* Obavezna polja za maloletnog člana su `first_name` i `last_name`; `email` i `phone` su opcioni.

* Obavezna polja za roditelja/staratelja su `first_name`, `last_name`, `email` i `phone`.

* Kada korisnik unese `birth_date`, `UF_MEMBER_FORM` mora izračunati da li osoba ima manje od 18 godina.

* Ako osoba ima manje od 18 godina, `UF_MEMBER_FORM` automatski prikazuje sekciju Roditelj/Staratelj 1.

* Sekcija Roditelj/Staratelj 1 je obavezna za maloletnike.

* `UF_MEMBER_FORM` prikazuje dugme `DODAJ DRUGOG RODITELJA/STARATELJA`.

* Klik na `DODAJ DRUGOG RODITELJA/STARATELJA` otvara sekciju Roditelj/Staratelj 2.

* Roditelj/Staratelj 2 koristi ista polja i validaciju kao Roditelj/Staratelj 1, ali je opcion.

* Svaka roditelj/staratelj sekcija sadrži `first_name`, `last_name`, `email` i `phone`.

* Za svakog roditelja/staratelja `first_name`, `last_name`, `email` i `phone` su obavezni.

* Pre kreiranja novog roditelja/staratelja u `people`, `UF_MEMBER_FORM` mora pretražiti postojeće osobe po email-u.

* Ako osoba sa tim email-om postoji, `UF_MEMBER_FORM` koristi postojeći `people.id`.

* `society_members.start_date` je obavezan.

* `society_members.start_date` označava datum kada je osoba postala član tog društva.

* `society_members.start_date` mora se birati ručno iz calendar/date picker kontrole.

* `society_members.start_date` može biti datum iz prošlosti, jer aplikacija može evidentirati postojeća članstva koja su počela pre uvođenja sistema.

* `society_members.start_date` koristi se kao prvi ACTIVE datum za `member_status_history`.

* `society_members.status` čuva trenutni status članstva i može biti `ACTIVE` ili `INACTIVE`.

* Članski jubilej se ne računa samo iz `society_members.start_date`.

* Članski jubilej se računa sabiranjem ACTIVE perioda iz `member_status_history`; INACTIVE periodi se ne računaju.

* Članarine se zasnivaju na ACTIVE/INACTIVE istoriji iz `member_status_history`, ne samo na trenutnom statusu.

* Kada se kreira novi red u `society_members`, mora se kreirati i prvi red u `member_status_history`.

* Prvi red u `member_status_history` za novo članstvo ima `status = ACTIVE` i `effective_date = society_members.start_date`.

* Svaka aktivacija i deaktivacija člana mora kreirati red u `member_status_history`.

* Funkcije članova nisu globalne; svako društvo ima svoju listu u `society_member_functions`.

* Kada Master admin odobri registraciju i kreira novo društvo, sistem automatski kreira početne funkcije za to novo društvo.

* Početne funkcije su `Predsednik`, `Sekretar`, `Blagajnik`, `Upravnik`, `UR`, `Korepetitor` i `Član`.

* `UR` znači `Umetnički rukovodilac`.

* `UR` ne znači `Upravnik`.

* `Upravnik` može postojati samo kao posebna funkcija, odvojena od `UR`.

* Dodatne funkcije kasnije može dodati predsednik.

* Postojeće funkcije kasnije može menjati ili deaktivirati predsednik.

* Funkcije se deaktiviraju, ne brišu se fizički.
* Jedan clan moze imati nula, jednu ili vise funkcija.

* Funkcije se ne upisuju u `society_members.funkcija`.

* Dodele funkcija se cuvaju u `society_member_function_assignments`.

* Ako clan nema izabranu funkciju, clan se i dalje moze sacuvati.

* Ista funkcija ne sme biti duplirana za istog clana.

* Funkcija `Predsednik` je posebna: mora uvek postojati, ne sme biti obrisana i ne sme biti deaktivirana.
* `Predsednik` se ne dodeljuje ručno kroz `UF_MEMBER_FORM`.

* `UR`, ako postoji kao opšta funkcija, ne dodeljuje se ručno kroz `UF_MEMBER_FORM`; UR po sekcijama rešava se kroz sekcijski model.

* `UF_MEMBER_FORM` prikazuje funkcije iz `society_member_functions` kao checkbox listu.

* Privremena hardcoded lista funkcija je dozvoljena samo dok `society_member_functions` nije implementirana u UI.

* `UF_MEMBER_FORM` je modul kroz koji se pri unosu i izmeni clana bira pripadnost clana sekcijama.

* `UF_MEMBER_FORM` prikazuje sekcije kao checkbox listu.

* Jedan clan moze biti izabran u nula, jednu ili vise sekcija kroz `UF_MEMBER_FORM`.

* `UF_MEMBER_FORM` ne upravlja samim sekcijama: ne kreira sekcije, ne menja nazive sekcija, ne aktivira/deaktivira sekcije i ne dodeljuje UR-a ili korepetitora.

* Nazivi sekcija se ne čuvaju direktno na `people` ili `society_members`.

## Section Assignment Rules

* `UF_MEMBER_FORM` ostaje centralna forma za clana.

* `UF_MEMBER_FORM` sluzi za:
  * unos clana
  * izmenu clana
  * izbor sekcija kojima clan pripada

* Sekcije u `UF_MEMBER_FORM` prikazuju se kao checkbox lista.

* Jedan clan moze pripadati vecem broju sekcija.

* `member_sections` cuva pripadnost clana sekcijama.

* `MOJE SEKCIJE` upravlja sekcijama.

* `UF_MEMBER_FORM` upravlja clanom.

* Predsednik u `UF_MEMBER_FORM`:
  * vidi sve sekcije drustva
  * moze cekirati bilo koju sekciju
  * moze menjati pripadnost clana svim sekcijama

* UR u `UF_MEMBER_FORM`:
  * vidi samo sekcije u kojima je on UR
  * moze cekirati samo te sekcije
  * ne vidi ostale sekcije drustva
  * ne moze menjati clanstvo u sekcijama kojima nije UR

* Izvor za UR ogranicenje je aktivan zapis u `section_role_assignments`.

* Ako je clan ranije bio `INACTIVE` u sekciji i korisnik ga ponovo cekira u `UF_MEMBER_FORM`, postojeci `member_sections` red se reaktivira na `ACTIVE`.

* Ako korisnik odcekira sekciju u `UF_MEMBER_FORM`, clanstvo u toj sekciji se ne brise fizicki nego se `member_sections.status` menja na `INACTIVE`.

* Svaka promena pripadnosti clana sekciji kroz `UF_MEMBER_FORM` mora napraviti odgovarajuci zapis u `member_section_history`.

## Sekcije

* `sections` predstavlja sekcije, grupe ili probne jedinice unutar jednog društva.

* Sekcije nisu globalne; pripadaju samo društvu za koje su kreirane.

* Kada Master admin odobri registraciju i kreira novo društvo, sistem automatski kreira početne sekcije za to novo društvo.

* Početne sekcije su `Izvođački ansambl`, `Pripremni ansambl`, `Dečiji ansambl`, `Pevačka grupa` i `Orkestar`.

* Sve početne sekcije kreiraju se sa `status = ACTIVE`.

* `sections.status` može biti `ACTIVE` ili `INACTIVE`.

* Aktivne sekcije mogu se izabrati kao pripadnost clana kroz `UF_MEMBER_FORM` prema pravilima pristupa iz poglavlja `Section Assignment Rules`.

* Dodatne sekcije kasnije može kreirati predsednik.

* Postojeće sekcije kasnije mogu biti preimenovane.

* Postojeće sekcije kasnije mogu biti aktivirane ili deaktivirane.

* Neaktivne sekcije ostaju u sistemu zbog istorije i ne brišu se fizički.

* Sekcije se ne brišu fizički.

* Nazivi sekcija su unique po društvu.

* `member_sections` povezuje članove društva sa sekcijama.

* Dodela sekcije nije obavezna pri kreiranju clana.

* Clan moze imati nula, jednu ili vise sekcija.

* Jedan clan moze biti aktivan u vise sekcija.

* Dodela sekcija i promena statusa clanstva clana u sekciji rade se kroz `UF_MEMBER_FORM` prema pravilima pristupa.

* Isti član ne sme biti dupliran unutar iste sekcije.

* Clanstvo u sekciji se ne brise fizicki; koristi se status:
  * `ACTIVE`
  * `INACTIVE`

* Ako je clan ranije bio `INACTIVE` u sekciji i ponovo se dodaje, ne pravi se novi dupli zapis; postojeci zapis se reaktivira na `ACTIVE`.

* `member_sections` cuva trenutno stanje clanstva clana u sekciji.

* Za istog clana i istu sekciju postoji samo jedan red u `member_sections`.

* `member_sections.status` moze biti:
  * `ACTIVE`
  * `INACTIVE`

* Istorija promena clanstva u sekciji se ne cuva kroz duple redove u `member_sections`.

* Za istoriju promena clanstva u sekciji koristi se `member_section_history`.

* Pravilo citanja podataka:
  * `member_sections` = trenutno stanje
  * `member_section_history` = istorija promena

* `member_section_history` cuva:
  * kada je clan dodat u sekciju
  * kada je deaktiviran
  * kada je ponovo aktiviran
  * ko je izvrsio promenu
  * datum od kada promena vazi
  * napomenu ako postoji

* Kada se clan prvi put doda u sekciju:
  * `member_sections.status = ACTIVE`
  * `member_section_history.old_status = null`
  * `member_section_history.new_status = ACTIVE`

* Kada se clan deaktivira:
  * `member_sections.status = INACTIVE`
  * `member_section_history.old_status = ACTIVE`
  * `member_section_history.new_status = INACTIVE`

* Kada se clan ponovo aktivira:
  * `member_sections.status = ACTIVE`
  * `member_section_history.old_status = INACTIVE`
  * `member_section_history.new_status = ACTIVE`

## Moje Sekcije

* Jasna podela modula:
  * `CLANOVI` = podaci osobe i clana
  * `UF_MEMBER_FORM` = unos/izmena clana i izbor sekcija kojima clan pripada
  * `MOJE SEKCIJE` = upravljanje sekcijama, UR-ovima, korepetitorima i pregledom clanova sekcije

* Sekcije kao organizacione jedinice se ne uredjuju kroz edit formu clana.

* Pripadnost clana sekcijama uredjuje se kroz `UF_MEMBER_FORM`.

* `MOJE SEKCIJE` ostaje glavni modul za:
  * upravljanje sekcijama
  * kreiranje sekcija
  * deaktivaciju sekcija
  * dodelu i uklanjanje UR-a
  * dodelu i uklanjanje korepetitora
  * pregled clanova sekcije

* Predsednik u modulu `MOJE SEKCIJE` vidi sve sekcije drustva.

* UR bez dodatne dozvole u modulu `MOJE SEKCIJE` vidi samo sekcije u kojima je on UR.

* Predsednik ima globalni pristup svim sekcijama svog drustva.

* UR ima početni sekcijski ograničen pristup sekcijama gde je dodeljen kao UR; predsednik mu može dodatno dozvoliti pregled ili rad u drugim sekcijama.

* Predsednik podrazumevano može:
  * kreirati sekciju
  * menjati naziv sekcije
  * aktivirati ili deaktivirati sekciju
  * dodeliti ili ukloniti UR-a sekciji
  * dodeliti ili ukloniti korepetitora
  * pregledati clanove svih sekcija

* Predsednik može navedena operativna prava za sekcije dodeliti sekretaru, upravniku, celoj drugoj funkciji ili pojedinačnom članu.
* Dodela i uklanjanje same funkcije `UR` ili `Korepetitor` ostaje isključivo predsedničko podešavanje dozvola i funkcija.

* UR ne moze:
  * kreirati sekciju
  * menjati naziv sekcije
  * aktivirati ili deaktivirati sekciju
  * dodeljivati ili uklanjati UR-a
  * dodeljivati korepetitora
  * menjati strukturu bilo koje sekcije
  * menjati pripadnost clana sekcijama u kojima nije UR

* UR moze:
  * videti samo sekcije u kojima je on UR
  * pregledati clanove samo u svojim sekcijama
  * kroz `UF_MEMBER_FORM` menjati pripadnost clana samo svojim sekcijama
  * videti kontakte roditelja/staratelja za maloletne clanove svoje sekcije

* UR sme da vidi sledece kontakte roditelja/staratelja za maloletne clanove svojih sekcija:
  * ime
  * prezime
  * telefon
  * email

* UR ne sme da vidi osetljive podatke roditelja/staratelja:
  * JMBG
  * broj pasosa
  * druge licne identifikacione podatke

* Sekcija moze imati vise UR-ova.

* Korepetitor je posebna uloga u sekciji.

* Korepetitor nije isto sto i obican clan sekcije.

* Korepetitor ne mora biti član društva, ali mora postojati kao jedinstvena osoba u `people`.

* Veza korepetitora i sekcije čuva se u `section_accompanists`; raniji model
  `section_role_assignments.role = KOREPETITOR` zamenjen je ovim modelom.

* Jedna sekcija može imati više aktivnih korepetitora.

* Korepetitora sekciji dodeljuje predsednik ili korisnik sa izričitom dozvolom
  `sections.manage_accompanists`.

* Dodela korepetitora se ne briše fizički; koristi se status:
  * `ACTIVE`
  * `INACTIVE`

* Za svakog korepetitora u konkretnoj sekciji predsednik podešava da li se
  njegovo prisustvo evidentira.

* Aktivna funkcija `UR` u `society_member_function_assignments` uslov je da član može biti izabran kao UR, a aktivna dodela u `section_role_assignments` određuje njegove početne nadležne sekcije.

* Sekcije se ne brisu fizicki iz baze; koristi se `sections.status`:
  * `ACTIVE`
  * `INACTIVE`

* Clanstvo u sekciji se ne brise fizicki iz baze; koristi se `member_sections.status`:
  * `ACTIVE`
  * `INACTIVE`

* Detalj sekcije treba da prikazuje:
  * naziv sekcije
  * status sekcije
  * listu UR-ova
  * korepetitora
  * aktivne clanove
  * neaktivne clanove kroz filter

* Dodavanje clana u sekciju radi se kroz `UF_MEMBER_FORM`, izborom sekcije iz checkbox liste.

* Detalj sekcije u `MOJE SEKCIJE` sluzi za pregled clanova sekcije i upravljanje strukturom sekcije.

* Ne sme se dodati isti clan dva puta kao `ACTIVE` u istoj sekciji.

* Ako postoji `INACTIVE` zapis za tu sekciju i clana, treba ga reaktivirati na `ACTIVE`.

## Funkcije I Sekcije

* Funkcija nije isto sto i sekcija.

* Funkcija clana se ne cuva u `society_members.funkcija`; dodele se cuvaju u `society_member_function_assignments`.

* Sekcije su grupe/probne jedinice unutar društva.

* `Predsednik`, `Sekretar`, `Blagajnik`, `Upravnik`, `UR`, `Korepetitor` i `Član` su funkcije člana društva.

* `UR` znači `Umetnički rukovodilac`; `Upravnik` je posebna funkcija i nije značenje skraćenice `UR`.

* `UR` je član društva. Korepetitor može, ali ne mora biti član društva.

* `UR` i `Korepetitor` mogu imati članarinu, `ACTIVE`/`INACTIVE` status, `start_date` i `member_status_history` kao svi drugi članovi.

* `UR` se raspoređuje po sekcijama postojećim sekcijskim modelom, a korepetitor
  kroz `section_accompanists`.

* Prisustvo se prati po probi, sekciji i osobi. Zapis razlikuje člana i
  korepetitora.

## Prisustvo Na Probama

* Modul `PRISUSTVO` ima `EVIDENCIJA PROBE` za trenutno otvorenu probu i operativni `PREGLED PROBA`. Statistika, poređenja i izvoz ostaju u budućem modulu `IZVEŠTAJI`.
* Korisnik prvo bira aktivnu sekciju, a zatim bira `OTVORI PROBU`.
* Datum i vreme početka ne unose se ručno. Sistem ih beleži automatski u trenutku otvaranja probe.
* Vreme završetka beleži se automatski u trenutku zatvaranja probe.
* Svaka sekcija ima `rehearsal_duration_minutes`, koje predsednik podešava u `MOJE SEKCIJE`.
* Trajanje probe može biti od 30 do 240 minuta, u koracima od 15 minuta; podrazumevana vrednost je 120 minuta.
* UR vidi trajanje sekcije, ali ga ne menja.
* Pri otvaranju probe baza zamrzava `planned_end_at` prema tadašnjem trajanju sekcije i `auto_close_at` 30 minuta kasnije.
* Naknadna promena trajanja sekcije ne menja rok već otvorene ili završene probe.
* Periodični serverski posao automatski zatvara probu kada prođe `auto_close_at`, čak i kada aplikacija nije otvorena.
* Automatsko zatvaranje beleži `closed_by_role = SYSTEM` i `close_type = AUTOMATIC`; ručno zatvaranje beleži `close_type = MANUAL`.
* Probu mogu otvoriti i zatvoriti predsednik društva ili UR koji ima aktivnu `UR` dodelu za izabranu sekciju.
* Za jednu sekciju može postojati najviše jedna otvorena proba. Ako otvorena proba već postoji, korisnik nastavlja postojeću evidenciju.
* Ne postoji ograničenje broja održanih proba iste sekcije u jednom danu. Nakon zatvaranja ili otkazivanja prethodne probe može se odmah otvoriti nova.
* U trenutku otvaranja probe pravi se snimak svih članova koji imaju aktivno članstvo u izabranoj sekciji. Kasnije promene članstva ne menjaju spisak već otvorene ili zatvorene probe.
* U isti snimak ulaze aktivni korepetitori sekcije kojima je uključeno
  evidentiranje prisustva.
* Korepetitori se prikazuju prvi, centrirani preko pune širine, a ispod njih
  paralelne kolone `Devojke` i `Momci`.
* Ako je ista osoba član sekcije i korepetitor, u probi postoji samo jedan
  zapis; ostaje u odgovarajućoj polnoj koloni uz oznaku `Korepetitor`.
* Uključivanje evidencije ne daje korepetitoru pravo pregleda ili izmene
  prisustva. Prava se određuju isključivo katalogom dozvola.
* Svi članovi na snimku probe početno dobijaju status `ABSENT`.
* Dodirom na red ili ime člana status se menja između `ABSENT` i `PRESENT`.
* V1 nema opravdano i neopravdano odsustvo, kašnjenje, ručni datum, ručno vreme, beleške uz redovno evidentiranje ni ručno dodavanje članova na probu.
* Svaka promena prisustva mora odmah da se sačuva u bazi. Osvežavanje stranice, izlazak sa stranice ili ponovno otvaranje aplikacije ne smeju izgubiti evidentirane promene.
* Interfejs mora jasno prikazati stanje čuvanja i grešku ako promena nije potvrđena u bazi.
* Pre zatvaranja probe prikazuje se potvrda sa ukupnim brojem članova, prisutnih i odsutnih.
* Zatvaranjem probe njen status prelazi iz `OPEN` u `CLOSED`, beleži se tačno vreme zatvaranja i redovno evidentiranje se završava.
* Dok je proba `OPEN`, prisustvo mogu menjati predsednik i UR nadležan za tu sekciju.
* Kada je proba `CLOSED`, UR ima samo pravo pregleda, a prisustvo može menjati isključivo predsednik društva.
* Izmena prisustva na zatvorenoj probi zahteva obavezan razlog i ne menja vreme otvaranja ili zatvaranja probe.
* Otvaranje, zatvaranje i svaka promena prisustva moraju imati audit trag: ko je izvršio radnju, kada, u kojoj ulozi, prethodnu i novu vrednost, kao i razlog kada se menja zatvorena proba.
* Identitet izvršioca dolazi iz prijavljenog korisnika i ne sme se birati ili unositi ručno.
* Audit zapisi ne mogu se menjati niti brisati kroz aplikaciju.
* Evidencije proba se ne brišu kroz aplikaciju. Njihovi podaci ostaju dostupni za buduće izveštaje.
* Greškom otvorena proba može se otkazati dok je `OPEN`. Otkazivanje postavlja status `CANCELLED`, beleži ko je i kada otkazao probu i ne briše evidenciju.
* `CANCELLED` proba ne računa se kao održana proba u budućim izveštajima.

## Tokovi Za Maloletnike I Staratelje

* Punoletni član:

  * kreira ili ažurira jedan zapis u `people`
  * kreira ili ažurira jedan zapis u `society_members`
  * ne kreira `person_guardians`

* Maloletni član sa jednim starateljem:

  * kreira ili ažurira dete u `people`
  * kreira ili ažurira članstvo deteta u `society_members`
  * pronalazi ili kreira Staratelja 1 u `people`
  * kreira ili ažurira vezu u `person_guardians`

* Maloletni član sa dva staratelja:

  * kreira ili ažurira dete u `people`
  * kreira ili ažurira članstvo deteta u `society_members`
  * pronalazi ili kreira Staratelja 1 u `people`
  * pronalazi ili kreira Staratelja 2 u `people`
  * kreira ili ažurira dve veze u `person_guardians`

* Staratelj koji je već član:

  * koristi postojeći `people` zapis
  * postojeći `society_members` zapis ostaje nezavisan od `person_guardians`
  * ne kreira se duplikat osobe

* Edit workflow:

  * izmena člana ažurira postojeći `people` i `society_members`
  * izmena maloletnika može dodati, promeniti ili ukloniti opcionog Staratelja 2
  * Staratelj 1 za maloletnika ne sme ostati prazan
  * promena staratelja menja vezu u `person_guardians`, ne parent polja na detetu

## Događaji, putovanja i repertoar

* Konačna V1 pravila modula nalaze se u `docs/EVENTS_V1.md`.
* Kartica `KONCERTI` prelazi u modul `DOGAĐAJI` sa tipovima `CONCERT` i `TRIP`.
* Predsednik upravlja svim događajima društva; UR kreira predlog za svoje sekcije koji predsednik odobrava.
* Događaj mora imati najmanje jednu sekciju pre odobravanja. Učesnici i numere mogu se dodati kasnije.
* Repertoar se uređuje kroz tab `REPERTOAR` u `MOJE SEKCIJE`.
* Predsednik uređuje repertoar svih sekcija. UR uređuje repertoar samo svoje sekcije i samo kada sekcijska dodela ima `can_manage_repertoire = true`.
* UR bez te dozvole i dalje može izabrati postojeću numeru za program svoje sekcije.
* Učesnik događaja može biti član društva ili gost iz `people`.
* Gost se ne upisuje u `society_members`, nema obaveznu kategoriju, ne pripada sekciji i ne može biti izvođač numere.
* Jedna osoba se na događaj dodaje samo jednom i dobija samo jedan planirani finansijski iznos.
* Putnik ne mora biti izvođač. Izvođači se biraju posebno za svaku numeru.
* Status učešća menjaju isključivo predsednik ili nadležni UR.
* UR direktno unosi samo ime, prezime, telefon i email osobe. Za ostale podatke šalje zahtev predsedniku.
* Za inostrano putovanje `CONFIRMED` zahteva kompletnu putnu dokumentaciju i pasoš koji važi najmanje do povratka.
* Stvarno finansijsko zaduženje nije deo V1 modula `DOGAĐAJI`; sada se čuva samo planirani iznos.
* Događaji poslati predsedniku ne brišu se fizički.

## Promena Predsednika

* Jedno društvo može imati samo jednog aktivnog predsednika.

* Funkcija `Predsednik` postoji za svako društvo i ne sme biti obrisana ili deaktivirana.

* Promena predsednika nije obična izmena člana.

* `UF_MEMBER_FORM` ne sme slucajno kreirati dve aktivne predsednicke dodele za isto drustvo kada workflow promene predsednika bude implementiran.

* Trenutni predsednik pokreće zahtev za promenu predsednika.

* Trenutni predsednik bira novog predsednika samo iz aktivnih članova svog društva.

* Razlog nije obavezan za trenutnog predsednika.

* Master admin odobrava ili odbija zahtev.

* Kada Master admin odobri zahtev:

  * prethodni predsednik ostaje član
  * prethodnom predsedniku se uklanja dodela funkcije `Predsednik` i po potrebi dodaje dodela funkcije `Clan`
  * izabrani član postaje `Predsednik`
  * status zahteva postaje `APPROVED`
  * čuvaju se reviewer i vreme pregleda

* Kada Master admin odbije zahtev:

  * ne menja se `society_members`
  * status zahteva postaje `REJECTED`
  * razlog odbijanja može biti sačuvan

* Može postojati samo jedan `PENDING` zahtev za promenu predsednika po društvu.

## Registracija Društva

* Društvo se kreira automatski kada Master admin odobri zahtev.

* Predsednik se ne kreira automatski kao član.

* Predsednik se pri prvom logovanju unosi kao prvi član kroz `UF_MEMBER_FORM`.

## Onboarding

* Onboarding predsednika prati se preko `user_onboarding_state`.

* Ne proveravati pri svakom logovanju da li predsednik postoji u `society_members`.

* Predsednik se tokom onboardinga unosi kroz `UF_MEMBER_FORM`, ne kroz posebnu president profile formu.

* Predsednik tokom onboardinga mora biti punoletan.

* Predsednik tokom onboardinga ručno bira `society_members.start_date` iz calendar/date picker kontrole.

* Predsednikov `start_date` može biti datum iz prošlosti.

* Svi datumi se korisniku prikazuju u formatu `dd/mm/yyyy`; vrednosti se u aplikaciji i bazi i dalje čuvaju u ISO formatu `yyyy-mm-dd`.

* Dugme `Nastavi` služi isključivo za prelazak na sledeći korak i nikada ne sme završiti onboarding niti aktivirati društvo ili licencu.

* Završetak onboardinga i aktiviranje društva/licence zahtevaju poseban završni ekran za proveru i jasno označeno dugme za konačnu potvrdu.

* Predsednik tokom onboardinga vidi i može da izmeni svoja polja za članarinu:

  * `membership_fee_required`
  * `membership_fee_amount`

* Posle uspešnog onboardinga predsednika kreira se prvi red u `member_status_history` sa `status = ACTIVE` i `effective_date = izabrani start_date`.

## Izmene Podataka

* Mora se jasno razlikovati vidljivost podatka od prava izmene podatka.

* Korisnik moze videti podatak, ali to ne znaci automatski da sme da ga menja.

* Osnovni kontakt podaci clana koji treba da budu vidljivi korisnicima koji imaju pravo da vide tog clana su:
  * ime
  * prezime
  * telefon
  * email

* Osetljivi podaci clana su:
  * JMBG
  * broj pasosa
  * datum vazenja pasosa
  * datum rodjenja
  * pol
  * licni identifikacioni podaci

* Osetljive podatke vidi i menja samo:
  * predsednik
  * korisnik kome je predsednik dao posebnu dozvolu

* Predsednik:
  * vidi sve clanove svog drustva
  * vidi sve podatke clanova
  * moze da menja sve podatke clanova
  * moze da menja status clanstva
  * moze da menja clanstvo u svim sekcijama kroz `UF_MEMBER_FORM`
  * moze da menja roditelje/staratelje

* UR:
  * vidi samo clanove sekcija u kojima je on UR
  * vidi osnovne kontakt podatke clana
  * vidi kontakte roditelja/staratelja za maloletne clanove svoje sekcije
  * ne vidi JMBG, broj pasosa ni datum vazenja pasosa osim ako ima posebnu dozvolu
  * moze da menja samo dozvoljene kontakt podatke ako mu je to omoguceno
  * moze da upravlja clanstvom samo u sekcijama gde je on UR, kroz `UF_MEMBER_FORM`

* Kontakti roditelja/staratelja koje UR sme da vidi za maloletne clanove svoje sekcije su:
  * ime
  * prezime
  * telefon
  * email

* Roditelji/staratelji se ne tretiraju kao clanovi drustva samo zato sto su roditelji/staratelji.

* Roditelji/staratelji postoje u `people` i vezani su sa detetom kroz `person_guardians`.

* Clanstvo u sekciji ne treba brisati; treba koristiti status:
  * `ACTIVE`
  * `INACTIVE`

* Predsednik moze da menja clanstvo u svim sekcijama kroz `UF_MEMBER_FORM`.

* UR moze da menja samo clanstvo u sekcijama gde je on UR kroz `UF_MEMBER_FORM`.

* Buduci workflow: korisnici koji nemaju pravo direktne izmene mogu poslati zahtev za izmenu podataka predsedniku.

* Predsednik odobrava ili odbija zahtev za izmenu podataka clana.

* Tek nakon odobrenja podaci se menjaju.

* Buduca tabela za zahteve za izmenu podataka clana moze biti `member_data_change_requests`.

* `member_data_change_requests` je planirana faza, nije obavezna trenutna implementacija.

* Predsednik ne menja direktno podatke u `societies`.

* Predsednik može da traži:

  * izmenu podataka društva
  * promenu licence

* Master admin odobrava ili odbija zahtev.

* PIB i matični broj predsednik ne menja direktno.

## Dashboard

* Master admin dashboard mora biti poseban sistemski dashboard.

* Master admin dashboard ne prikazuje:

  * broj članova jednog društva
  * prisustvo jednog društva
  * članarine jednog društva

## Razvoj

* Pre pravljenja nove forme, komponente ili tabele obavezno proveriti da li već postoji odgovarajuće rešenje.
