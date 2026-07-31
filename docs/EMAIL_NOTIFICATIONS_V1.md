# Email obaveštenja V1

## Opseg

Aplikacija ne služi za pisanje proizvoljnih emailova. Gmail nalog društva
koristi se samo za unapred definisane poslovne poruke:

* link za dopunu podataka člana;
* link za dopunu podataka roditelja/staratelja;
* potvrdu evidentirane uplate članarine ili kotizacije.

Svaka poruka prvo nastaje u zajedničkom `society_email_outbox` redu. Direktno
slanje iz ekrana bez evidencije nije dozvoljeno.

Migracije za ovaj tok primenjene su u aktivnoj Supabase bazi 30.07.2026.
Dijagnostika je potvrdila strukturu, dozvolu i nula neusaglašenih email zapisa.

## Prijem člana i dopuna podataka

Predsednik prvo pregleda kandidata. Slanje linka znači da je kandidat prihvaćen
u članstvo. Član se prikazuje sa posebnim stanjem dopune podataka:

* `AWAITING_DATA`;
* `DATA_IN_PROGRESS`;
* `AWAITING_REVIEW`;
* `COMPLETED`.

Ovo stanje ne zamenjuje aktivni/neaktivni status članstva.

Za maloletnika:

* primarni roditelj/staratelj uvek dobija svoj link;
* dete dobija odvojeni link ako ima najmanje 12 godina i sopstveni email;
* oba linka koriste isti nacrt, uz postojeće razdvajanje dozvoljenih podataka.

## Potvrda uplate

Nakon uspešnog upisa uplate automatski se priprema potvrda. Neuspeh Gmail
slanja ne poništava uplatu.

Primaoci:

* punoletni član dobija svoju potvrdu;
* maloletnik sa najmanje 12 godina i sopstvenim emailom dobija svoju potvrdu;
* primarni roditelj/staratelj maloletnika uvek dobija potvrdu;
* ista email adresa dobija samo jednu poruku za istu uplatu;
* roditeljska poruka može objediniti raspodelu za više dece.

Poruka sadrži društvo, broj potvrde, iznos, valutu, način plaćanja, vreme
evidencije i raspodelu na članarine ili kotizacije. Ne sadrži bankarske
poverljive podatke.

## Evidencija

Za svaku poruku čuvaju se društvo, vrsta, pošiljalac, primalac, predmet,
verzija šablona, povezani poslovni zapis, način pokretanja, status, broj
pokušaja, poslednja greška, Gmail identifikator i vremena kreiranja, pokušaja
i uspešnog slanja.

Svaki pokušaj ima zaseban red u `society_email_delivery_attempts`. Prethodni
neuspeh se ne prepisuje uspešnim ponovnim pokušajem.

Osetljivi link za dopunu čuva se šifrovano samo u delu potrebnom za isporuku.
Gmail tokeni, JMBG i podaci pasoša nisu deo evidencije emailova.

## Izveštaji i dozvole

Evidencija se prikazuje kao tab `Evidencija emailova` u modulu `Izveštaji`.
Ne postoji posebna centralna email stranica.

Tab vidi predsednik i korisnik kome je predsednik dodelio
`reports.email_log.view`. Predsednik ima ovu dozvolu zaključano. Tab je
read-only i ne sadrži pisanje nove poruke niti izbor proizvoljnih primalaca.
