# Pregled performansi baze — 31.07.2026.

## Obuhvat

Nad povezanim Supabase projektom pokrenuti su isključivo read-only pregledi:
veličine i aktivnost tabela, korišćenje indeksa, bloat, dugi upiti, blokade i vacuum
statistika. Podaci, šema, statistika i indeksi nisu menjani.

## Zaključak

Baza je trenutno veoma mala i nema znakova aktivnog problema sa performansama.
Nema dugotrajnih upita ni blokada. Najveća poslovna tabela zauzima 144 kB ukupno,
a većina ključnih tabela 16–88 kB. Na toj veličini sekvencijalno čitanje je često
jeftinije od korišćenja indeksa, pa veliki `seq_scan` brojevi sami po sebi nisu kvar.

Nije opravdano ručno pokretati `VACUUM`, menjati autovacuum podešavanja niti dodavati
nove indekse samo na osnovu trenutnih podataka.

## Najvažniji nalazi

- `people`: 9 procenjenih redova, 144 kB ukupno.
- `society_members`: 6 procenjenih redova, 64 kB ukupno.
- `financial_obligations`: 2 procenjena reda, 88 kB ukupno.
- `society_events`: 4 procenjena reda, 48 kB ukupno.
- Garderobne tabele su prazne ili gotovo prazne, ukupno uglavnom 8–32 kB.
- Nema trenutno dugih upita.
- Nema blokirajućih transakcija.
- Tabele nemaju procenjeni bloat; prijavljen višak pojedinih indeksa je samo po
  8 kB i nema praktičan značaj.
- Autovacuum trenutno ne očekuje intervenciju ni na jednoj prijavljenoj tabeli.
  Najviše mrtvih redova imaju `member_data_invitations` (39), `society_members`
  (31), `society_fee_month_rule_history` (24) i `people` (23), ali su apsolutne
  količine premale da bi predstavljale problem.

## Kandidati za čišćenje indeksa

Statistika i definicije iz repozitorijuma ukazuju na nekoliko verovatno redundantnih
parova. Njih treba potvrditi katalog upitom iz Paketa 11 pre bilo kakvog uklanjanja:

1. `member_sections_unique_idx` i `member_sections_unique_member_section` — oba
   pokrivaju `(section_id, society_member_id)`.
2. `society_members_society_person_unique_idx` i
   `society_members_one_person_per_society_idx` — oba pokrivaju
   `(society_id, person_id)`.
3. `people_one_auth_user_idx` i `people_user_id_unique_idx` — oba pokrivaju
   `user_id`; potrebno je potvrditi predikate i jedinstvenost.
4. Jedinstveni indeks na `society_fee_month_rule_history`
   `(society_id, month_number, effective_from)` i obični
   `society_fee_month_rule_lookup_idx` imaju iste vodeće kolone; treba proveriti
   da li obični indeks ima drugačiji smer sortiranja ili predikat.
5. Jedinstveni indeks pokušaja slanja `(outbox_id, attempt_number)` i
   `society_email_attempts_outbox_idx` verovatno se preklapaju.

Neiskorišćeni primarni, jedinstveni i parcijalni indeksi nisu kandidati za automatsko
brisanje: oni mogu čuvati integritet ili služiti retkim, ali važnim poslovnim tokovima.

## Preporuka za sledeći paket

Napraviti jednu malu, reverzibilnu migraciju koja uklanja samo potpuno potvrđene
duplikate. Pre toga za svaki par treba uporediti punu definiciju, ograničenja,
predikat i redosled kolona. Ostale indekse ostaviti dok baza ne dobije reprezentativan
broj članova, događaja i finansijskih stavki; tada ponoviti ovaj pregled i meriti
stvarne najskuplje upite.

## Primena Paketa 14

Migracija `20260731160000_performance_v1_remove_redundant_indexes.sql` uspešno je
primenjena 31.07.2026. Supabase evidencija potvrđuje isti lokalni i udaljeni broj
migracije. Završni read-only pregled potvrdio je da je svih pet redundantnih indeksa
uklonjeno i da je svih pet odgovarajućih jedinstvenih indeksa ostalo prisutno.
