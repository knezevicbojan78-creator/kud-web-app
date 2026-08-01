# FOLKLORAŠ

Next.js aplikacija za upravljanje kulturno-umetničkim društvima, povezana sa
Supabase bazom i objavljena preko Vercela.

## Produkcija

* Javni sajt: `https://www.folkloras.rs`
* Prijava: `https://www.folkloras.rs/prijava`
* Politika privatnosti: `https://www.folkloras.rs/politika-privatnosti`
* Produkcijska grana: `main`
* Hosting projekat: Vercel `kud-web-app`

Početna ruta je prezentaciona strana. Google Analytics (`G-JT7R47R6KS`) se
učitava samo nakon saglasnosti posetioca. Izbor se može promeniti kroz link
`Podešavanja kolačića` u podnožju sajta.

## Trenutne celine

* Supabase Auth V1, MFA za Master administratora i stvarni korisnički kontekst
* registracija, odobravanje i onboarding predsednika i društva
* članovi, roditelji/staratelji, maloletnici i red za dopunu podataka
* pojedinačni i masovni prijem članova
* funkcije, sekcije, prisustvo i dozvole
* događaji, finansije, izveštaji i garderoba
* predsednička podešavanja i više imenovanih vrsta članarine
* licence, društva, zahtevi i audit za Master administratora
* javni paketi i kontrolisani upiti za paket po meri
* Gmail OAuth osnova i serverski email tokovi
* prezentacioni sajt, politika privatnosti i saglasnost za analitičke kolačiće

## Migracije

Svaka produkcijska SQL promena mora biti evidentirana u
`supabase/migration-ledger.json`. Statusi i obavezni postupak opisani su u
`docs/SUPABASE_MIGRATION_LEDGER.md`.

Provera evidencije:

```bash
npm run check:migrations
```

## Razvoj i provere

```bash
npm run dev
npm run typecheck
npm run build
npm run verify
```

## Dokumentacija

* `docs/PROJECT_STATUS.md` — aktuelni zbirni status
* `docs/WORK_LOG_2026-08-01_02.md` — poslednji produkcijski radni ciklus
* `docs/DECISIONS.md` — potvrđene poslovne i tehničke odluke
* `docs/DATABASE_SCHEMA.md` — model baze
* `docs/PRE_RELEASE_CLEANUP_CHECKLIST.md` — produkcijske i bezbednosne provere

Detaljna dokumentacija funkcionalnih modula nalazi se u folderu `docs`.
