# Evidencija promena Supabase baze

Od 28. jula 2026. svaka nova SQL promena mora da bude upisana u
`supabase/migration-ledger.json`. Evidencija sprečava da se ista promena
slučajno primeni dva puta i jasno razdvaja pripremljene od već primenjenih
promena.

Statusi:

- `prepared` — fajl je spreman, ali nije primenjen na povezanoj bazi;
- `applied` — promena je primenjena, uz obavezan datum;
- `retired` — fajl se više ne koristi i ostaje samo radi istorije.

Za novu promenu redosled je:

1. napraviti SQL fajl i, kada je primenljivo, dijagnostički SQL;
2. dodati zapis sa statusom `prepared`;
3. primeniti promenu tek posle pregleda i potvrde;
4. pokrenuti dijagnostiku;
5. promeniti status u `applied`, upisati datum i rezultat u radni dnevnik.

Komanda `npm run check:migrations` proverava da li su zapisi ispravni, da li
navedeni SQL i dijagnostički fajlovi postoje i da li u `supabase` folderu ima
produkcijskih SQL kandidata bez ledger zapisa.

Neispravan postojeći zapis prekida proveru. Neevidentirani produkcioni SQL
fajlovi trenutno daju upozorenje, ali ne prekidaju build, jer je evidencija
uvedena naknadno i stariji fajlovi se klasifikuju postepeno. Dijagnostičke,
DEV, testne cleanup/reset/restore skripte nisu produkcioni kandidati.

Upozorenje ne treba ignorisati za novu promenu: svaki novi produkcioni SQL mora
odmah dobiti `prepared`, `applied` ili `retired` zapis. Postojeći istorijski
dug treba smanjivati tek nakon poređenja sa aktivnom bazom; status starog fajla
ne sme se nagađati samo na osnovu njegovog prisustva u repozitorijumu.

## Poslednje primenjene migracije — 01.08.2026.

* `migrations/20260801120000_members_v1_guardian_email_suggestions.sql`
* `migrations/20260801170000_pending_membership_waiting_state.sql`
* `migrations/20260801190000_custom_plan_inquiries.sql`
* `migrations/20260801200000_single_member_pending_intake.sql`
* `migrations/20260801220000_membership_fee_types.sql`

Svih pet zapisa ima status `applied` i datum `2026-08-01` u mašinski čitljivoj
evidenciji. Za migracije koje imaju posebnu dijagnostiku, naziv dijagnostičkog
fajla upisan je u polje `verified_by`.
