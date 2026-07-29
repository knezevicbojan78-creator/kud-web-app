# Auth V1 migracija aplikacije

## Cilj

Ukloniti privremeni DEV kontekst i vezati svaki ekran za stvarno prijavljenog
korisnika, njegovo društvo, članstvo, funkcije i dozvole. Nijedan V1 ekran ne
sme birati prvo aktivno društvo niti čitati testnu ulogu iz browser storage-a.

## Inventar 2026-07-27 — završna V1 provera

| Modul | Trenutno stanje | V1 promena |
|---|---|---|
| AppShell i Dashboard | Auth V1 za Master admina i predsednika | Završeno |
| Članovi | Kontrolisani Auth V1 create/edit/read i lookup tokovi | Završeno i dijagnostički potvrđeno |
| Moje sekcije | Kontrolisani workspace, detalj i management RPC tokovi | Završeno i dijagnostički potvrđeno |
| Prisustvo | Auth V1 aktivni i istorijski tokovi | Završeno i funkcionalno potvrđeno |
| Finansije | Auth V1 pregled, naplata, podešavanja, povraćaj i poništavanje | Završeno i dijagnostički potvrđeno |
| Događaji | Auth V1 pregled, upravljanje, učesnici i statusi | Završeno i dijagnostički potvrđeno |
| Podešavanja | Članarina, funkcije i dozvole koriste Auth V1 | Završeno u V1 opsegu |
| Master admin zahtevi | Liste i detalj koriste MFA zaštićeni RPC | Završeno i dijagnostički potvrđeno |
| Garderoba i Izveštaji | Trenutno nemaju poslovne upise | Budući funkcionalni moduli |
| Moji podaci i Moja deca | Trenutno nemaju poslovne upise | Budući funkcionalni moduli |

## Etape

1. Centralni Auth V1 aplikacioni kontekst.
2. Članovi, Moje sekcije i Prisustvo.
3. Finansije i Događaji.
4. Garderoba, Izveštaji, Podešavanja i Moji podaci.
5. Uklanjanje `testRoles`, browser-storage uloga i fallback izbora društva — završeno.
6. Završna RLS/RPC dijagnostika — završena: 0 DEV politika, 0 direktnih
   `anon` prava nad tabelama i 0 neočekivanih anonimnih funkcija.

## Završni bezbednosni rezultat

Provera `auth-v1-final-security-diagnostic.sql` potvrdila je:

* nema preostalih politika čiji naziv počinje sa `DEV`
* `anon` nema direktan `SELECT`, `INSERT`, `UPDATE` ili `DELETE` nad poslovnim tabelama
* nema neočekivanih funkcija dostupnih anonimnom korisniku
* anonimno su dostupna samo tri namerna javna toka: bootstrap status,
  javni cenovnik licenci i slanje predsedničkog zahteva
* Master admin bootstrap zahteva potvrđenu Auth sesiju i nije anonimni tok

## Obavezna pravila

* Društvo se nikada ne bira preko `order(...).limit(1)`.
* Uloga se nikada ne čita iz `localStorage` ili `sessionStorage`.
* Identitet i društveni kontekst određuje server na osnovu `auth.uid()`.
* Klijentski skriveno dugme nije bezbednosna kontrola; svaka promena se
  proverava i na serverskoj strani.
* Master admin ostaje platformski identitet bez reda u `people` i
  `society_members`.
* Korisnik sa više društava dobija eksplicitan izbor društva; kontekst se ne
  bira proizvoljno.
