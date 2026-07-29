# Lokalne provere i test-podaci

Glavna komanda za proveru projekta je:

`npm run verify`

Ona proverava da tajni i generisani fajlovi nisu završili u Git istoriji,
proverava evidenciju promena baze, TypeScript i produkciono pravljenje
aplikacije, a zatim pokreće osnovne automatske testove u odvojenom lokalnom
Chrome prozoru.

Javni automatski testovi pokreću se komandom:

`npm run test:e2e:smoke`

Testovi sami pokreću lokalnu aplikaciju, proveravaju prijavljivanje, da
neprijavljeni korisnik ne vidi zaštićeni meni i izolovanu javnu stranicu za
dopunu podataka. Osnovni testovi ne zavise od mreže i ne menjaju Supabase bazu.

Kontrolisani Excel za buduće testiranje masovnog unosa pravi se komandom:

`npm run test:data:prepare`

Fajl se čuva u lokalnom folderu `.test-data`, koji se ne šalje u Git. Koristi
isključivo prepoznatljive adrese sa domena `example.com`. Unos u bazu i
brisanje test-redova ostaju zaseban, potvrđen korak dok ne uvedemo poseban
test-nalog i potpuno izolovano test-okruženje.
