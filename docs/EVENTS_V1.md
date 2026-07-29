# DOGAĐAJI V1 – koncerti, putovanja i repertoar

## 1. Svrha

Modul `DOGAĐAJI` upravlja koncertima i putovanjima društva. Postojeća navigaciona kartica `KONCERTI` biće preimenovana u `DOGAĐAJI`.

Repertoar se ne definiše na događaju. Centralni repertoar pripada sekcijama i uređuje se u posebnom tabu `REPERTOAR` unutar modula `MOJE SEKCIJE`. Događaj samo bira postojeće numere.

## 2. Uloge i prava

### Predsednik

Predsednik:

* vidi sve događaje društva
* kreira nacrt ili odmah odobrava događaj
* bira sve sekcije, članove i goste
* odobrava ili odbija predlog UR-a
* menja i otkazuje odobren događaj
* upravlja repertoarom svih sekcija
* dodeljuje UR-u pravo upravljanja repertoarom konkretne sekcije
* direktno menja osetljive podatke osobe u okviru postojećih pravila

### UR

UR:

* kreira događaj kao `DRAFT` i šalje ga predsedniku kao `PENDING`
* na događaj dodaje samo sekcije u kojima ima aktivnu UR dodelu
* bira članove svojih sekcija
* može dodavati goste na događaj koji je kreirao ili koji uključuje njegovu sekciju
* direktno unosi samo ime, prezime, telefon i email osobe
* za ostale podatke osobe šalje zahtev predsedniku
* vidi repertoar svojih sekcija
* uređuje centralni repertoar sekcije samo kada njegova aktivna `section_role_assignments` dodela ima `can_manage_repertoire = true`
* može povezivati postojeće numere sa programom svojih sekcija bez posebne dozvole za upravljanje centralnim repertoarom
* nakon odobrenja može menjati program i izvođače svojih sekcija, ali ne menja datume, mesto, finansije ni druge sekcije

Članovi, roditelji i gosti ne menjaju svoj status učešća. Status menja isključivo predsednik ili nadležni UR.

## 3. Tipovi i statusi događaja

Tip događaja:

* `CONCERT`
* `TRIP`

Status događaja:

* `DRAFT`
* `PENDING`
* `APPROVED`
* `REJECTED`
* `CANCELLED`
* `COMPLETED`

Samo `APPROVED` događaj smatra se aktivnim i kasnije će biti vidljiv članovima i roditeljima.

## 4. Obaveznost podataka

Događaj može biti nepotpun dok je `DRAFT` ili `PENDING`.

Za odobravanje su obavezni:

* naziv
* tip
* država i mesto
* najmanje jedna sekcija

Učesnici i numere nisu obavezni pri odobravanju i mogu se dodati kasnije.

Za `TRIP` su obavezni datum i vreme polaska i povratka. Povratak mora biti posle polaska.

Koncert može biti odobren bez numere. Nedostatak programa prikazuje upozorenje, ali ne blokira odobravanje.

## 5. Sekcije, putnici i izvođači

Jedan događaj može imati više sekcija.

`event_participants` predstavlja sve osobe koje idu na događaj:

* član koji nastupa
* član koji samo putuje
* gost koji nije član društva

Svaki učesnik obavezno ima `person_id`. `society_member_id` postoji samo kada je osoba član trenutnog društva.

Gost:

* mora postojati u `people`
* ne dobija red u `society_members`
* nema obaveznu kategoriju poput roditelja, vozača ili fotografa
* ne pripada sekciji
* ne može biti izvođač numere
* može imati finansijsko učešće

Ista osoba može postojati samo jednom na istom događaju, bez obzira na broj sekcija ili numera.

Član može biti povezan sa više sekcija događaja, ali dobija samo jedan zapis učesnika i jedno planirano finansijsko učešće.

Izvođači se biraju posebno za svaku numeru. Član koji samo putuje nema vezu sa numerom.

## 6. Status učešća

Status učesnika:

* `PLANNED`
* `CONFIRMED`
* `DECLINED`
* `CANCELLED`
* `ATTENDED`
* `ABSENT`

Status menja predsednik ili nadležni UR. Učesnik ga ne menja samostalno.

## 7. Domaće i inostrano putovanje

Država događaja podrazumevano je `Srbija`.

Za domaće putovanje gost mora imati:

* ime
* prezime
* najmanje telefon ili email

Za inostrano putovanje, pre prelaska učesnika u `CONFIRMED`, obavezni su:

* ime i prezime
* datum rođenja
* pol
* državljanstvo
* adresa, grad, poštanski broj i država prebivališta
* broj pasoša
* država izdavanja pasoša
* datum važenja pasoša
* najmanje telefon ili email

Ako je putnik maloletan na datum polaska, dodatno su obavezni:

* evidentirana overena saglasnost oba roditelja za put u inostranstvo
* datum važenja saglasnosti koji pokriva najmanje datum povratka

Saglasnost je podatak osobe u `people`, jer isto pravilo važi za maloletne članove i maloletne putnike koji nisu članovi društva. Ne čuva se kao podatak članstva.

JMBG je obavezan samo kada ga osoba ima; strani gost ne mora imati srpski JMBG.

Pasoš mora važiti najmanje do datuma povratka. Ako ističe pre povratka, `CONFIRMED` se blokira. Isticanje u naredna tri meseca prikazuje upozorenje. Posebna pravila pojedinačnih država nisu deo V1.

UR za postojećeg člana ne vidi osetljive vrednosti. Vidi samo da li je dokumentacija kompletna, nepotpuna, čeka odobrenje, pasoš ne važi do povratka ili maloletna osoba nema važeću saglasnost.

## 8. Zahtevi za izmenu podataka osobe

UR direktno unosi samo:

* ime
* prezime
* telefon
* email

Za datum rođenja, pol, adresu, JMBG, državljanstvo i podatke pasoša UR kreira `person_data_change_requests`.

Zahtev sadrži postojeće i predložene vrednosti, događaj kao opcioni kontekst i status:

* `PENDING`
* `APPROVED`
* `REJECTED`

Predsednik odobrava ili odbija zahtev. Odobravanje atomarno ažurira `people`. Odobren podatak ostaje važeći i za buduće događaje.

## 9. Finansijsko učešće

Događaj može imati podrazumevani planirani iznos po učesniku:

* iznos
* valuta, podrazumevano `RSD`
* rok plaćanja
* napomena

Iznos se kopira na učesnika pri dodavanju. Predsednik može postaviti pojedinačni iznos, uključujući nulu.

U V1 se ne kreira stvarno finansijsko zaduženje. Budući modul `FINANSIJE` generisaće zaduženje samo za `CONFIRMED` učesnike.

## 10. Repertoar

Centralna numera sadrži:

* naziv
* tip: `CHOREOGRAPHY`, `SONG`, `INSTRUMENTAL` ili `OTHER`
* trajanje
* opis
* napomenu za kostim
* status `ACTIVE` ili `INACTIVE`

Numera može pripadati većem broju sekcija.

Jedan nastup može imati više numera iste sekcije. Ista numera može se koristiti na drugim nastupima istog događaja, ali se ne duplira u istom nastupu za istu sekciju.

Stabilni `repertoire_items.id` kasnije će se povezivati sa kostimskim kompletima i njihovim delovima kroz budući modul `GARDEROBA`.

## 11. Nastupi

Lokalni koncert obično ima jedan nastup. Putovanje može imati nula, jedan ili više nastupa.

Nastup sadrži:

* naziv
* početak i kraj
* državu, mesto, objekat i adresu
* redosled
* napomenu

Program nastupa povezuje nastup, sekciju događaja i numeru. Posebna veza određuje koji potvrđeni članovi izvode konkretnu numeru.

## 12. Audit i brisanje

Promene statusa događaja čuvaju se u `event_status_history`.

Događaj se ne briše fizički nakon slanja predsedniku. Odbijeni i otkazani događaji ostaju u istoriji.

Statusne promene izvršavaju kontrolisane bazne funkcije:

* `submit_event`
* `approve_event`
* `reject_event`
* `cancel_event`
* `complete_event`

## 13. Planirane tabele

* `society_events`
* `event_status_history`
* `event_sections`
* `event_participants`
* `event_participant_sections`
* `repertoire_items`
* `repertoire_item_sections`
* `event_appearances`
* `event_appearance_repertoire`
* `event_repertoire_participants`
* `person_data_change_requests`

Izmena postojećih tabela:

* `people.nationality`
* `people.passport_issuing_country`
* `section_role_assignments.can_manage_repertoire`

SQL migracija:

* `supabase/events-v1-setup.sql`
