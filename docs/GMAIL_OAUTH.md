# Gmail OAuth povezivanje društva

## Trenutni status — 29.07.2026.

Gmail OAuth osnova je implementirana i funkcionalno potvrđena u lokalnoj
aplikaciji:

* samo prijavljeni predsednik može da upravlja povezivanjem;
* jedno društvo može imati tačno jedan povezani Gmail nalog;
* novi nalog može da zameni postojeći tek nakon uspešnog Google odobrenja;
* odjava uklanja vezu iz aplikacije i opoziva Google token;
* Google lozinka se nikada ne čuva;
* refresh i access tokeni čuvaju se šifrovano u aktivnoj Supabase bazi;
* direktan pristup tabelama zabranjen je `anon` i `authenticated` ulogama;
* migracija `supabase/gmail-v1-society-connection.sql` primenjena je i
  dijagnostika je uspešno potvrđena;
* Gmail API je uključen u Google Cloud projektu `folkloras`;
* napravljen je OAuth Web application klijent za lokalni razvoj;
* lokalni origin je `http://localhost:3000`;
* lokalni redirect URI je
  `http://localhost:3000/api/gmail/callback`;
* testni korisnik `info@mitance.rs` dodat je u Google OAuth test korisnike;
* predsednički tok `Podešavanja -> Gmail povezivanje -> Poveži Gmail`
  uspešno je završio stvarno povezivanje naloga.

OAuth Client ID, Client Secret i interne aplikacione tajne nalaze se samo u
lokalnom `.env.local`. Njihove vrednosti se ne dokumentuju i ne smeju u Git.
Preuzet Google OAuth JSON takođe ne sme biti dodat u repozitorijum.

## Implementirani delovi

Frontend:

* tab `Gmail povezivanje` na predsedničkoj stranici `Podešavanja`;
* prikaz statusa i povezane email adrese bez prikaza tokena;
* povezivanje, bezbedna zamena i odjava naloga;
* automatska obnova Supabase sesije pre serverskih Gmail zahteva;
* obrada Google callback rezultata i čišćenje osetljivih URL parametara.

Serverske rute:

* `POST /api/gmail/connect`;
* `GET /api/gmail/callback`;
* `POST /api/gmail/complete`;
* `POST /api/gmail/disconnect`.

Baza:

* `society_gmail_connections` — trenutno povezivanje, jedan red po društvu;
* `society_gmail_connection_history` — istorija povezivanja, zamene i odjave;
* `auth_get_society_gmail_connection`;
* `auth_save_society_gmail_connection`;
* `auth_disconnect_society_gmail`.

Google dozvola je ograničena na identitet/email i
`https://www.googleapis.com/auth/gmail.send`. Aplikacija ne traži čitanje
poruka niti pristup prijemnom sandučetu.

## Važna granica trenutne implementacije

Povezivanje Gmail naloga radi, ali poslovna obaveštenja još nisu prebačena na
ovaj kanal. Nisu još implementirani:

* zajednički serverski servis za osvežavanje Google access tokena i poziv
  Gmail API `users.messages.send`;
* pouzdan email outbox sa statusom, pokušajima i poslednjom greškom;
* povezivanje konkretnih obaveštenja članovima sa Gmail servisom;
* šabloni poruka i kontrolisani izbor primalaca;
* ekran istorije poslatih i neuspelih poruka.

Zato status `Povezano` trenutno potvrđuje OAuth vezu, ali sam po sebi ne znači
da su sva postojeća in-app obaveštenja već počela da se šalju emailom.

## Promenljive okruženja

Potrebne serverske promenljive:

* `GOOGLE_GMAIL_CLIENT_ID`;
* `GOOGLE_GMAIL_CLIENT_SECRET`;
* `GMAIL_OAUTH_STATE_SECRET` — najmanje 32 znaka;
* `GMAIL_TOKEN_ENCRYPTION_KEY` — najmanje 32 znaka;
* `NEXT_PUBLIC_APP_URL`.

Lokalne vrednosti postoje u `.env.local`. Pri objavljivanju se unose u
bezbedne environment variables izabranog hostinga. Ne kopiraju se u repo,
dokumentaciju, klijentski kod ili screenshot.

## Koraci pre produkcije

1. Odrediti javni HTTPS domen aplikacije.
2. U Google OAuth klijentu dodati produkcijski JavaScript origin, na primer
   `https://app.folkloras.rs`.
3. Dodati produkcijski redirect URI:
   `https://app.folkloras.rs/api/gmail/callback`.
4. Postaviti `NEXT_PUBLIC_APP_URL` na isti javni origin.
5. Preneti četiri Gmail/OAuth tajne u serversko okruženje hostinga.
6. Dopuniti Google Auth Platform podatke: naziv, logo, početna stranica,
   politika privatnosti, uslovi korišćenja i kontakt.
7. Pokrenuti Google verifikaciju za osetljivu `gmail.send` dozvolu i objaviti
   OAuth aplikaciju u režim `Production`.
8. Do završetka verifikacije svaki probni Google nalog mora ručno biti dodat u
   `Audience -> Test users`.
9. Ponoviti povezivanje i probno slanje u produkcionom okruženju.
10. Implementirati i proveriti servis slanja/outbox pre uključivanja stvarnih
    automatskih obaveštenja članovima.

Dok je Google OAuth aplikacija u režimu `Testing`, testni refresh tokeni mogu
isteći posle sedam dana, pa se lokalno povezivanje tada ponavlja.

## Sledeće mesto nastavka

Sledeći razvojni zadatak je Gmail servis za stvarno slanje jedne kontrolisane
probne poruke. Servis treba da:

1. učita i dešifruje refresh token isključivo na serveru;
2. obnovi access token kod Google-a;
3. napravi RFC 2822/MIME poruku;
4. pošalje je preko Gmail API `users.messages.send`;
5. sačuva bezbedan rezultat bez tokena i sadržaja osetljivih podataka;
6. zatim se poveže sa budućim email outbox-om i konkretnim obaveštenjima.
