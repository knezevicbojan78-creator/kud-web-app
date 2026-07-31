# Dijagnostika performansi baze

Datoteka `supabase/performance-v1-core-read-diagnostic.sql` je read-only pregled
ključnih tabela aplikacije. Ona ne menja podatke, šemu, indekse niti statistiku baze.
Primeri poslovnih upita koriste `EXPLAIN` bez `ANALYZE`, pa se samo pravi plan i
upiti se ne izvršavaju.

## Šta rezultat pokazuje

1. **Tabele** — procenjeni broj aktivnih i mrtvih redova, sekvencijalna i indeksna
   čitanja, vreme poslednje analize i zauzeće diska.
2. **Indeksi** — veličinu, broj zabeleženih korišćenja, validnost i punu definiciju.
3. **Strani ključevi bez vodećeg indeksa** — mesta koja treba proveriti kod JOIN,
   brisanja i izmene roditeljskih redova.
4. **Ekvivalentni indeksi** — mogući duplikati koji zauzimaju prostor i usporavaju
   upis, ali se ne brišu bez provere ograničenja i stvarnog opterećenja.
5. **Planovi čestih upita** — pristup članovima, događajima i garderobi bez čitanja
   poslovnih podataka.

## Bezbedan postupak

Pokrenuti datoteku u Supabase SQL Editoru i sačuvati sve skupove rezultata. Za
preciznije procene planera može se samo u toj sesiji postaviti identifikator društva
prema komentaru u SQL datoteci. To podešavanje nije trajna promena baze.

Broj `idx_scan = 0` sam po sebi nije dovoljan razlog za uklanjanje indeksa: statistika
može biti skoro resetovana, a jedinstveni i primarni indeksi štite ispravnost podataka.
Slično, strani ključ bez indeksa nije automatski problem na veoma maloj tabeli.

Pre bilo kakve izmene indeksa treba zajedno pregledati rezultate, potvrditi najskuplje
planove i napraviti poseban, reverzibilan paket migracije. Ovaj dijagnostički paket
namerno ne sadrži takve izmene.
