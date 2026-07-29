# MASTER ADMIN V1

## Stanje implementacije — 2026-07-24

Master admin V1 trenutno ima funkcionalan Dashboard, agregatnu listu društava, kompaktne liste zahteva na čekanju/odobrenih/odbijenih zahteva i detalj društva sa tabovima `Pregled`, `Podaci društva`, `Licenca`, `Predsednik`, `Zahtevi` i `Istorija`.

SQL `master-admin-v1-society-detail-workflows.sql` primenjen je u aktivnoj bazi. Kontrolisana suspenzija i ponovna aktivacija društva rade sa obaveznim obrazloženjem i audit zapisom. Funkcionalni test je završen, a testno društvo je vraćeno u status `ACTIVE`.

Kartica `Podaci društva` koristi zajedničku `SocietyDataForm` i poseban kompaktan Master admin raspored: četiri kolone na desktopu, dve na tabletu i jednu na mobilnom uređaju.

Sledeća planirana celina je praktično upravljanje licencnim periodima i promotivnim licencama od 3, 6 i 12 meseci. Finalni Auth/onboarding i produkciona RLS zaštita rade se kasnije, kao što je ranije dogovoreno.

## Stanje na pauzi — 2026-07-25

Master admin UI, cenovnik, ručna suspenzija/reaktivacija i ručna dodela mesečnih, godišnjih i promotivnih licencnih perioda završeni su u DEV/V1 opsegu. Prva promotivna licenca uspešno je dodeljena testnom društvu.

Detaljni poslovni testovi plaćenih licenci i rada sa više društava namerno su odloženi dok u bazi ne budu dva stvarna pilot društva. Kontrolna lista testova nalazi se na vrhu `docs/PROJECT_STATUS.md`.

Pre produkcije još treba implementirati automatske opomene i suspenziju nakon isteka, baza-level read-only zaštitu suspendovanog društva, kontrolu limita pri aktiviranju članova/sekcija, poništavanje pogrešne licencne evidencije, auditovanu izmenu podataka društva i finalni Auth/RLS. Ove stavke nisu označene kao završene samo zato što je njihovo praktično testiranje odloženo.

## 1. Svrha i granice

Master admin upravlja platformom, društvima, registracionim i sistemskim zahtevima, licencama, suspenzijama i auditom.

Master admin nije član niti predsednik svih društava i nema pristup pojedinačnim članovima, sekcijama, prisustvu, događajima, putnim dokumentima ili internim finansijama društva.

Za potrebe pregleda i licenci Master admin dobija isključivo zbirne brojeve:

* broj aktivnih i neaktivnih članstava u `society_members`
* broj aktivnih i neaktivnih sekcija u `sections`

Za licencne limite računaju se samo:

* `society_members.status = ACTIVE`
* `sections.status = ACTIVE`

Roditelji/staratelji koji nisu članovi, gosti, putnici i učesnici događaja ne računaju se kao članovi društva.

Supabase Auth, onboarding predsednika i finalne RLS politike nisu deo ove faze, ali pre produkcije ostaju obavezni.

## 2. Navigacija

Master admin V1 meni:

* Dashboard
* Društva
* Zahtevi
* Licence
* Audit
* Podešavanja sistema

Postojeće liste registracionih zahteva na čekanju, odobrenih i odbijenih zahteva treba objediniti u jedan ekran sa statusnim tabovima.

Dok objedinjeni ekran ne bude završen, sve tri postojeće liste koriste isti kompaktan tabelarni obrazac preko cele širine, sa pretragom, brojem rezultata, jasnom statusnom oznakom i akcijom za detalj. Tehnički identifikatori i identitet izvršioca ne prikazuju se u glavnoj listi.

## 3. Dashboard

Dashboard prikazuje platformske, a ne interne podatke društava:

* aktivna društva
* suspendovana društva
* registracije na čekanju
* licence koje uskoro ističu
* raspodelu društava po licencama
* zahteve koji traže reakciju
* poslednjih 5–10 Master admin akcija

## 4. Društva

Lista društava podržava pretragu po nazivu, gradu, PIB-u i matičnom broju, kao i filtere po statusu i licenci.

Lista prikazuje:

* naziv i grad
* PIB i matični broj
* broj aktivnih članova
* broj aktivnih sekcija
* licencu
* status
* datum registracije, kada je dostupan

Detalj društva koristi tabove:

* Pregled
* Podaci društva
* Licenca
* Predsednik
* Zahtevi
* Istorija

Master admin ne otvara spisak pojedinačnih članova ili sekcija.

## 5. Zahtevi

Jedinstveni ekran objedinjuje:

* registraciju društva
* izmenu podataka društva
* promenu licence
* promenu predsednika

Svaki zahtev čuva status, podnosioca, vreme podnošenja, staru i novu vrednost, izvršioca obrade, vreme obrade i razlog odbijanja. Razlog odbijanja je obavezan. Obrađena odluka se ne prepisuje; korekcija se rešava novim zahtevom.

## 6. Status društva i suspenzija

V1 koristi samo:

* `ACTIVE`
* `SUSPENDED`

Arhiviranje i brisanje društva nisu deo V1.

Suspenzija:

* najčešće nastaje zbog isteka neprodužene licence
* omogućava pregled postojećih podataka
* blokira sve korisničke unose, izmene, potvrde, otkazivanja i brisanja
* mora se sprovoditi u bazi, a ne samo kroz disabled kontrole u interfejsu
* ne zaustavlja automatski mesečni obračun članarina niti tehničke procese koji čuvaju integritet podataka
* ne briše postojeće podatke

Suspenzija se ne briše iz istorije. Čuvaju se početak, završetak, razlog, izvršilac i povezana licenca ili uplata.

Licenca važi do kraja `valid_until` datuma. Društvo automatski prelazi u suspenziju narednog dana u 00:00 prema poslovnoj vremenskoj zoni sistema.

## 7. Licence

Licence mogu biti:

* mesečne
* godišnje
* promotivne u trajanju 3, 6 ili 12 meseci

Licenca je unapred plaćeno pravo korišćenja za određeni period. Ne postoje licencna zaduženja, delimične uplate, višak uplate niti kredit prema platformi.

Plaćanje:

* mora odgovarati punoj ceni paketa i perioda
* čuva stvarni datum uplate i vreme evidentiranja
* aktivira ili produžava licencu
* pri ranijem produženju novi period počinje nakon isteka postojećeg perioda
* ako je licenca istekla, novi period podrazumevano počinje datumom uplate
* pogrešan unos se ne briše već poništava uz obavezan razlog i audit

Paketi će naknadno dobiti nazive, cene i limite nakon praktičnog testa sa najmanje dva društva. Model mora podržati:

* mesečnu cenu
* godišnju cenu
* valutu
* maksimalan broj aktivnih članova
* maksimalan broj aktivnih sekcija

Cena i limiti kopiraju se na licencni period kao istorijski snimak. Kasnija izmena paketa ne menja već dodeljen period.

### Potvrđeni paketi i cene

Sve cene su iskazane bez poreza.

| Paket | Aktivni članovi | Aktivne sekcije | Mesečno | Godišnje |
| --- | ---: | ---: | ---: | ---: |
| Malo društvo | do 100 | do 6 | 8 EUR | 80 EUR |
| Standard | do 250 | do 12 | 15 EUR | 150 EUR |
| Veliko društvo | do 500 | do 20 | 25 EUR | 250 EUR |
| Poseban paket | individualno | individualno | po dogovoru | po dogovoru |

Godišnja cena odgovara ceni deset mesečnih perioda. Za limite se računaju samo aktivna članstva i aktivne sekcije.

Društvo mora zadovoljiti oba limita paketa. Prekoračenje jednog limita zahteva viši ili poseban paket. Dostizanje limita ne suspenduje društvo i ne blokira postojeće podatke, već onemogućava aktiviranje novog člana ili sekcije preko limita dok se paket ne promeni ili Master admin ne odobri posebno rešenje.

Osnovne poslovne funkcije aplikacije dostupne su u svim paketima. Paketi se u V1 razlikuju po kapacitetu, ne uskraćivanjem ključnih funkcija. Budući medijski prostor, video, društvene funkcije, posebne integracije i dodatna podrška mogu biti zasebni dodaci.

Master admin menja mesečnu i godišnju cenu pojedinačnog paketa u `Podešavanjima sistema`. Valuta u V1 ostaje EUR, a sve prikazane cene su bez poreza. Razlog promene je obavezan. Nova cena važi odmah za buduće dodele i produženja, dok postojeći periodi zadržavaju snimljenu cenu. Audit čuva prethodnu i novu cenu, razlog i izvršioca.

## 8. Promotivne licence

Master admin može dodeliti 3, 6 ili 12 meseci gratis licence.

Pri dodeli bira:

* paket
* trajanje
* datum početka
* razlog promocije
* opcionu internu napomenu

Promotivna licenca ima prava i limite izabranog paketa, ali nema povezanu uplatu. Standardno se očekuje jedna početna promocija po društvu. Dodatna promocija je dozvoljena samo uz obavezan razlog i upozorenje da je promocija ranije korišćena.

Ako postoji važeća licenca, novi promotivni period nastavlja se od njenog kraja.

## 9. Obaveštenja o isteku

Obaveštenje se šalje samo kada naredni period nije evidentiran:

* mesečna licenca: 5 dana pre isteka
* godišnja licenca: 30 dana i 7 dana pre isteka
* promotivna licenca: 30 dana i 7 dana pre isteka

Predsednik treba da dobije in-app i email obaveštenje. U ovoj fazi priprema se evidencija/izlazni red, dok se stvarno slanje povezuje kasnije.

Po isteku se šalje obaveštenje o suspenziji, a nakon produženja obaveštenje o ponovnoj aktivaciji.

## 10. Audit

Audit je neizmenjiva istorija važnih Master admin akcija i odgovara na pitanja ko, šta, kada i zašto.

Beleže se najmanje:

* odobravanje i odbijanje registracije
* izmena društva
* dodela, produženje i poništavanje licence
* promotivna licenca
* evidentiranje i poništavanje uplate
* suspenzija i reaktivacija
* promena predsednika

Audit čuva staru i novu vrednost, razlog, izvršioca, vreme i rezultat. Audit je samo za čitanje i ne briše se kroz aplikaciju.

## 11. Podešavanja sistema V1

V1 obuhvata samo:

* podrazumevanu licencu
* naziv platforme
* kontakt email podrške
* osnovne šablone sistemskih obaveštenja
* poslovnu vremensku zonu

Povezivanje sa bankom, kartično plaćanje, fakture, automatska naplata i arhiviranje nisu deo V1.
