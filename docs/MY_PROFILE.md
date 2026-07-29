# Moji podaci

Stranica `/moji-podaci` je lični profil prijavljenog korisnika društva.

## Raspored

Stranica koristi isti sistem kartica, boja, razmaka i dugmadi kao ostatak
aplikacije:

* kompaktno zaglavlje sa inicijalima, identitetom, statusom i kompletnošću;
* četiri kratke kartice za lične podatke, dokumenta, društvo i porodicu;
* jedna sadržajna kartica sa tabovima `Lični podaci`, `Dokumenta`, `Društvo`,
  `Porodica` i `Bezbednost`;
* podaci se prvo prikazuju za čitanje, a obrazac se otvara tek komandom
  `IZMENI`;
* na telefonu kartice prelaze u mrežu 2 × 2, tabovi se pomeraju horizontalno, a
  podaci i obrazac prelaze u jednu kolonu.

## Prava izmene

Korisnik može da menja samo sopstvene:

* ime i prezime;
* pol i datum rođenja;
* adresu, grad, poštanski broj i državu;
* državljanstvo i telefon;
* JMBG, broj pasoša, državu izdavanja i datum važenja pasoša.

Korisnik ne može na ovoj stranici da menja:

* email naloga bez posebnog toka potvrde;
* status i početak članstva;
* funkcije, sekcije i članarinu;
* roditeljsku saglasnost za putovanje.

Saglasnost i dalje evidentira predsednik nakon fizičke dostave.

## Bezbednost i audit

Funkcija `auth_update_my_profile(jsonb)` pronalazi profil isključivo preko
`auth.uid()` i aktivnog članstva u aktivnom društvu. Anonimni korisnik nema
pravo poziva.

Tabela `person_profile_change_history` čuva samo spisak promenjenih polja,
identitet korisnika i vreme. Stare i nove vrednosti JMBG-a i pasoša ne kopiraju
se u audit.

Email, društveni podaci i saglasnost nisu deo dozvoljenog skupa polja.
