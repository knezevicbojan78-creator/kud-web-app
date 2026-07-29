# Masovni unos — samostalna dopuna podataka

## Cilj

Masovni unos zahteva samo vrstu osobe, ime, prezime i email. Roditelj/staratelj
se odmah evidentira u `people`. Član se evidentira kao kandidat i ne postaje
član društva dok predsednik ne završi potvrđivanje.

Predsednik može kandidatu poslati vremenski ograničen link za samostalnu dopunu
podataka. Stranica otvorena tim linkom nema aplikacioni meni, prijavljivanje niti
mogućnost pristupa drugim ekranima.

## Statusi

Poziv za dopunu koristi statuse:

* `INVITED` — link je napravljen i slanje emaila je pokrenuto
* `OPENED` — primalac je prvi put otvorio link
* `IN_PROGRESS` — postoji sačuvan nacrt
* `SUBMITTED` — primalac je završio i poslao podatke predsedniku
* `CANCELLED` — predsednik je opozvao link
* `EXPIRED` — link je istekao

Kandidat ostaje `PENDING` dok ga predsednik ne potvrdi ili odbaci.

## Nacrt i nastavak unosa

* Svaka promena se automatski čuva u bazi posle kratkog perioda bez kucanja.
* Nepotpuni podaci smeju da se sačuvaju kao nacrt.
* Stranica prikazuje `Čuvanje`, `Sačuvano` ili grešku čuvanja.
* Isti važeći link ponovo učitava poslednji nacrt.
* Dugme `Sačuvaj i nastavi kasnije` odmah čuva nacrt.
* Konačna validacija obaveznih polja radi se tek na `Pošalji predsedniku`.
* Nakon slanja podaci su zaključani. Predsednik ih zatim pregleda i potvrđuje
  članstvo sa datumom početka.

## Maloletni član, dete i roditelj

* Za maloletnika mogu postojati dva odvojena poziva: `MEMBER` za dete i
  `GUARDIAN` za roditelja/staratelja.
* Predsednik pre pravljenja bilo kog poziva za maloletnika mora da ga označi
  kao maloletnog, pronađe već unetog roditelja/staratelja po emailu i sačuva
  vezu.
* Roditeljski email se uzima iz sačuvane veze i ne može se proizvoljno promeniti
  prilikom slanja poziva.
* Ako roditelj još nije među osobama iz masovnog unosa, predsednik prvo mora da
  ga unese, pa tek onda da ga poveže sa kandidatom.
* Oba poziva rade nad istim kandidatom i zajedničkim nacrtom, pa se već sačuvani
  podaci ne unose ponovo.
* Dete sa navršenih 12 godina sme da dopunjava sve svoje lične podatke,
  uključujući JMBG, broj pasoša i datum važenja pasoša.
* Dete ne vidi niti menja podatke roditelja/staratelja.
* Roditelj dopunjava podatke deteta i podatke roditelja/staratelja.
* Aktivno uređivanje se evidentira po delu obrasca. Drugi primalac dobija
  obaveštenje kada je isti deo trenutno otvoren kod deteta ili roditelja.
* Zaključavanje je privremeno i ističe posle pet minuta bez aktivnosti.
* Svako čuvanje koristi verziju zajedničkog nacrta, pa starija stranica ne može
  neprimetno prepisati novije podatke.

## Saglasnost za putovanje

Roditeljsku saglasnost za putovanje i datum njenog važenja ne unose dete niti
roditelj preko javnog linka. Ta polja su deo predsedničkog završnog unosa.
Predsednik ih evidentira tek kada mu fizička saglasnost bude dostavljena.

Javni RPC odbacuje ova polja čak i ako ih neko pokuša poslati mimo interfejsa.

## Podela podataka

Javna dopuna obuhvata lične podatke člana: ime, prezime, pol, datum rođenja,
email, telefon, adresu, mesto, poštanski broj, državu, JMBG, broj pasoša i datum
važenja pasoša. Podaci vezani za društvo ostaju predsednički: status članstva,
datum početka, članarina, funkcije i sekcije.

Kompletnost se računa iz stvarno sačuvanih podataka, a ne samo iz toga da li je
neko kliknuo `Pošalji`. Predsednik vidi tačan spisak nedostajućih podataka i
može ih sam dopuniti i aktivirati člana. Aktivacijom se opozivaju svi preostali
linkovi kandidata.

## Bezbednost

* Link sadrži kriptografski nasumičan token. U bazi se čuva samo SHA-256 hash.
* Token važi sedam dana, može se opozvati i vezan je za jednog kandidata.
* Javni RPC vraća i menja samo podatke kandidata vezanog za dati token.
* Nacrt se ne čuva u `localStorage`, naročito zbog JMBG-a i pasoša.
* Javni ekran je van `(application)` layout-a i zato nema `AppShell`.
* Ponovno slanje pravi novi token, a sačuvani nacrt ostaje vezan za kandidata.
* Predsedničke operacije se proveravaju u bazi; skrivanje dugmadi nije zaštita.

## Email

Slanje obavlja serverska Next.js ruta preko email provajdera. Tajna provajdera
se čuva isključivo u serverskoj promenljivoj `RESEND_API_KEY`. Pošiljalac se
zadaje kroz `MEMBER_INVITATION_FROM_EMAIL`, a javna adresa aplikacije kroz
`NEXT_PUBLIC_APP_URL`. Ako email provajder nije podešen, aplikacija prijavljuje
grešku i ne tvrdi da je poruka poslata.

## Lokalna funkcionalna provera

Dok aplikacija nije objavljena, predsednik na listi kandidata koristi:

* `Kopiraj test link člana`
* `Kopiraj test link roditelja`

Probni link treba otvoriti u privatnom prozoru pregledača na istom računaru.
Ponovno pravljenje linka za istu ulogu opoziva prethodni link, ali ne briše
sačuvani nacrt.

Redovni lokalni test obuhvata:

1. masovni unos reda sa samo imenom, prezimenom i emailom
2. preskakanje reda čiji email već postoji u bazi i prikaz razloga
3. otvaranje javnog obrasca bez navigacije ostatka aplikacije
4. automatsko čuvanje, zatvaranje stranice i nastavak preko istog linka
5. odvojena prava člana starijeg od 12 godina i roditelja
6. poruku drugom primaocu dok prvi trenutno uređuje podatke
7. prikaz nedostajućih podataka predsedniku
8. predsedničku dopunu podataka društva i konačnu aktivaciju člana
9. opozivanje oba linka posle aktivacije ili otkazivanja

## Potvrđivanje

Za punoletnog člana obavezni su ime, prezime, email, telefon i datum početka
članstva koji unosi predsednik. Za maloletnog člana obavezni su ime i prezime
deteta, datum rođenja i podaci primarnog roditelja/staratelja. Roditelj se
ponovo koristi po emailu i povezuje preko `person_guardians`.

Konačno slanje javnog obrasca ne kreira `society_members`. Članstvo nastaje tek
nakon predsedničke potvrde kroz kontrolisani serverski workflow.
