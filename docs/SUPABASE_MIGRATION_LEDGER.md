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

Komanda `npm run check:migrations` proverava da li su zapisi ispravni i da li
navedeni SQL fajlovi postoje. Evidencija je uvedena od ovog datuma i dopunjava
se postepeno; stariji fajlovi ostaju opisani u postojećem projektnom dnevniku.
