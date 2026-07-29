# FOLKLORAŠ

Next.js aplikacija za upravljanje kulturno-umetničkim društvima, povezana sa Supabase bazom.

## Trenutno stanje

U razvojnom V1 toku trenutno postoje:

- registracija društva
- pregled, odobravanje i odbijanje registracionih zahteva
- kreiranje aktivnog društva pri odobravanju
- pregled i Master admin izmena podataka društva kroz zajedničku `SocietyDataForm`
- unos i izmena članova kroz zajedničku `UF_MEMBER_FORM`
- podrška za maloletne članove i roditelje/staratelje
- funkcije članova, pripadnost sekcijama i istorija statusa
- DEV/V1 modul `MOJE SEKCIJE` za sekcije, UR-ove, korepetitore i pregled članova
- DEV/V1 modul `PRISUSTVO` za otvaranje i zatvaranje probe, brzo evidentiranje članova i audit promena

## Važna ograničenja trenutne faze

- Supabase Auth V1 Master admin osnova primenjena je i funkcionalno potvrđena u aktivnoj bazi; registracija, potvrda emaila, TOTP i otvaranje Dashboarda prošli su uspešno.
- Za osam Master admin RPC funkcija pripremljena je Auth/MFA zaštitna migracija koja još mora biti primenjena i proverena u aktivnoj bazi.
- Registracija i onboarding predsednika, člana i roditelja još nisu implementirani.
- Postojeći moduli i RPC tokovi još se postepeno prebacuju sa DEV pristupa na finalnu autorizaciju.
- Ekrani za članove i sekcije privremeno koriste prvo aktivno društvo.
- `CLANOVI` privremeno radi sa pravima predsednika; stvarno UR ograničenje biće uvedeno sa korisničkim kontekstom i finalnim dozvolama.
- RLS politike i repo SQL migracije još nisu finalno usklađeni sa aktivnom bazom.
- Approval workflow još nije transakcijski.

Detaljan status, pravila i odloženi tehnički dug nalaze se u folderu `docs`.

## Razvoj

```bash
npm run dev
npm run typecheck
npm run build
```
