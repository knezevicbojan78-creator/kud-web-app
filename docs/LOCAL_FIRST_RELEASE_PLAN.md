# Local-first razvoj i plan objavljivanja

## Odluka

Aplikacija ostaje u lokalnom razvojnom režimu dok glavni poslovni moduli,
dozvole, migracije i javni obrazac ne budu funkcionalno završeni i provereni.

Vercel, javni domen aplikacije i stvarno slanje email poziva nisu trenutni
preduslov za nastavak razvoja. Uvode se tek u fazi pripreme ograničene
produkcione probe.

## Šta završavamo lokalno

Lokalno se razvijaju i proveravaju:

* članovi, masovni unos i predsedničko potvrđivanje
* odvojeni pozivi detetu i roditelju/staratelju
* zajednički nacrt, automatsko čuvanje i nastavak unosa
* zaštita od istovremenog prepisivanja podataka
* sekcije, prisustvo, događaji, finansije, garderoba i izveštaji
* dozvole, vidljivost i prava izmene
* ponašanje na manjim ekranima
* Supabase migracije, kontrolisani RPC workflow-i i dijagnostike

## Lokalno testiranje poziva

Dok email servis nije podešen, predsednički ekran nudi `Kopiraj test link`.
Link se otvara u drugom privatnom prozoru pregledača na istom računaru.

Na taj način proveravamo:

1. prikaz obrasca bez aplikacione navigacije
2. prava deteta i roditelja/staratelja
3. automatsko čuvanje nacrta
4. zatvaranje i nastavak preko istog linka
5. zaključavanje kada drugi primalac već uređuje podatke
6. statuse i nedostajuća polja kod predsednika
7. ručnu dopunu i konačno aktiviranje člana

Stvarno slanje emaila i otvaranje linka na tuđem uređaju ostaju završna
integraciona provera posle objavljivanja probne verzije.

## Uslovi za probno objavljivanje

Pre prelaska na internet potrebno je:

* završiti glavne module predviđene za prvu verziju
* proveriti predsednička, UR, član i roditeljska prava
* ukloniti ili jasno odvojiti testne podatke
* potvrditi sve produkcione SQL migracije i dijagnostike
* pripremiti rezervnu kopiju produkcione baze
* proveriti javni obrazac i masovni unos lokalnim test linkovima
* definisati politiku privatnosti i rokove čuvanja napuštenih nacrta

Tačan spisak trenutno poznatih probnih osoba, povezanih zapisa i završnih
provera nalazi se u `docs/PRE_RELEASE_CLEANUP_CHECKLIST.md`. Lista se dopunjava
svaki put kada tokom razvoja napravimo novu vrstu probnih podataka.

## Budući redosled objavljivanja

1. Privatni GitHub repozitorijum.
2. Vercel Preview okruženje.
3. Odvojena razvojna i produkciona konfiguracija.
4. Provera prijavljivanja i glavnih tokova na Preview adresi.
5. Povezivanje poddomena `app.folkloraš.rs`.
6. Podešavanje Resend domena i ograničenog API ključa.
7. Proba sa malim brojem stvarnih korisnika.
8. Produkciono puštanje nakon prihvatanja probe.

Izmene se ni tada ne objavljuju direktno korisnicima: prvo se rade lokalno,
zatim na Preview verziji, pa tek nakon potvrde u produkciji.

## Operativni način rada

Lokalni razvoj se kombinuje sa prijavljenom Supabase sesijom u povezanom
pregledaču. To omogućava da se pripremljene migracije, dijagnostike i stvarni
korisnički tokovi provere u jednom radnom ciklusu.

Detaljan postupak, granice pristupa, potvrde i pravilo proaktivnog predlaganja
novih mogućnosti zapisani su u `docs/COLLABORATION_WORKFLOW.md`.

Objedinjeni spisak funkcionalnih testova, pravila jednokratnog odobrenja i
evidencije svih probnih podataka nalazi se u
`docs/FUNCTIONAL_TEST_MASTER_PLAN.md`.
