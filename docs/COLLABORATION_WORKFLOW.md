# Način zajedničkog rada

## Stalna odluka

Od 28.07.2026. razvoj se, kada su potrebni baza i funkcionalna provera, radi
kao jedinstven tok:

1. izmena lokalnog koda i SQL migracija
2. korisnik se prijavljuje u odgovarajući servis u povezanom pregledaču
3. Codex koristi tu već prijavljenu sesiju za rad u odobrenom projektu
4. rizične, trajne ili spoljne promene Codex jasno najavljuje i traži potvrdu
5. migracija se primenjuje i odmah proverava read-only dijagnostikom
6. lokalna aplikacija se otvara u povezanom pregledaču
7. stvarni korisnički tok se funkcionalno testira
8. pronađene greške se ispravljaju i isti tok se ponavlja
9. testni podaci se na kraju odbacuju ili brišu prema dogovoru
10. rezultat i mesto nastavka beleže se u dokumentaciji

Ovaj način rada trenutno obuhvata lokalnu Next.js aplikaciju i aktivni Supabase
projekat.

## Pristup prijavljenim servisima

Codex može da radi kroz povezani pregledač samo dok postoji dostupna prijavljena
sesija. Pristup nije trajan, ne podrazumeva poznavanje lozinke i može prestati
kada se sesija zatvori ili istekne.

Ako servis zatraži prijavu, korisnik se sam prijavljuje. Lozinke, jednokratni
kodovi i druge podatke za prijavu ne treba slati u razgovoru.

Codex ne menja drugi projekat, nalog ili servis bez jasnog dogovora. Za
destruktivne, produkcione ili druge značajne spoljne promene traži se potvrda
neposredno pre izvršenja.

## Proaktivno ubrzavanje rada

Kad god u radnom okruženju postoji nova ili ranije nekorišćena mogućnost koja
može značajno ubrzati razvoj, Codex treba da je predloži korisniku jednostavnim
jezikom i objasni:

* šta ta mogućnost omogućava
* za koji konkretan korak je korisna
* da li nešto menja izvan lokalnog koda
* da li zahteva prijavu, povezivanje ili potvrdu korisnika
* koje ograničenje ili rizik postoji

Nakon korisnikovog prihvatanja takva mogućnost postaje deo uobičajenog načina
rada dok je dostupna i primerena zadatku.

Primeri uključuju direktnu proveru Supabase baze kroz prijavljeni pregledač,
funkcionalno testiranje lokalne aplikacije, automatizovanu proveru dokumenata i
tabela, Preview okruženja i povezane servise za objavljivanje ili email.

## Pravilo komunikacije

Korisniku se ne prebacuju tehnički koraci koje Codex može bezbedno da uradi
samostalno u okviru odobrenog zadatka. Kada je potrebna korisnikova radnja,
objašnjenje mora biti kratko, tačno i korak-po-korak.

