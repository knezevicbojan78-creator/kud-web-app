# PLAN IMPLEMENTACIJE DOZVOLA V1

## 1. Cilj

Implementirati potvrđeni model iz `docs/PERMISSIONS_V1.md` tako da:

* funkcija daje početna prava
* predsednik menja pravila cele funkcije
* predsednik može napraviti pojedinačni `ALLOW` ili `DENY` izuzetak
* prava više aktivnih funkcija se sabiraju
* opseg prava ostaje ograničen na sebe, decu, nadležne sekcije ili celo društvo
* baza, serverski tok i interfejs koriste isti izvor efektivnih dozvola
* deo za podešavanje dozvola vidi i koristi samo predsednik

## 2. Postojeće stanje koje se zadržava

Postojeće tabele ostaju:

* `society_member_functions` — katalog funkcija društva
* `society_member_function_assignments` — aktivne funkcije člana
* `section_role_assignments` — dodela UR-a i korepetitora konkretnim sekcijama

Postojeći kontrolisani tokovi, istorije i audit tabele se ne brišu. Njihove provere naziva funkcije postepeno se prebacuju na centralnu proveru efektivnih dozvola.

## 3. Nove tabele

### `permission_catalog`

Globalni sistemski katalog dozvola.

Planirana polja:

* `id`
* `permission_key` — stabilan tehnički ključ
* `module_key`
* `label`
* `description`
* `action_type`
* `allowed_scopes`
* `is_sensitive`
* `requires_reason`
* `is_president_only`
* `is_active`
* vremena kreiranja i izmene

Katalog se ne uređuje slobodnim tekstom iz društva. Dopunjava se kontrolisanom migracijom kada se uvede novi modul ili kartica.

### `system_function_permission_templates`

Početni sistemski šabloni za funkcije:

* Predsednik
* Sekretar
* Blagajnik
* Upravnik
* UR
* Korepetitor
* Član

Šablon određuje početnu dozvolu, opseg i da li je pravo zaključano.

### `society_function_permission_rules`

Pravila koja važe za sve članove jedne funkcije u konkretnom društvu.

Planirana polja:

* `society_id`
* `function_id`
* `permission_id`
* `scope_key`
* `effect`
* `is_locked`
* ko je i kada promenio pravilo

Predsednikova obavezna prava i druga zaključana početna prava ne mogu se isključiti.

### `society_member_permission_overrides`

Pojedinačni izuzeci člana.

Planirana polja:

* `society_id`
* `society_member_id`
* `permission_id`
* `scope_key`
* `effect` — `ALLOW` ili `DENY`
* razlog
* ko je i kada uneo izuzetak

Stanje `INHERIT` ne zahteva zapis; ono znači da pojedinačni izuzetak ne postoji.

### `permission_change_audit`

Neizmenjiv audit promena funkcija i dozvola:

* društvo
* vrsta i identitet cilja
* dozvola i opseg
* prethodno i novo stanje
* razlog
* izvršilac
* aktivne funkcije izvršioca
* vreme promene

Audit podešavanja dozvola vidi samo predsednik.

## 4. Centralna provera efektivnih prava

Baza treba da dobije centralne funkcije za:

* pronalaženje članstva prijavljenog korisnika u društvu
* učitavanje svih aktivnih funkcija člana
* sabiranje zaključanih i promenljivih prava funkcija
* primenu pojedinačnih `ALLOW` i `DENY` izuzetaka
* proveru opsega nad ciljnim članom, detetom, sekcijom ili događajem
* vraćanje objedinjenog spiska prava za interfejs
* odbijanje nedozvoljene radnje u kontrolisanim baznim funkcijama

Pravila prioriteta:

1. sistemska zabrana i predsedničko zaključavanje ne mogu se zaobići
2. pojedinačni `DENY` uklanja nasleđeno pravo u istom opsegu
3. pojedinačni `ALLOW` dodaje pravo koje funkcije nisu dale
4. bez pojedinačnog izuzetka sabiraju se prava svih aktivnih funkcija
5. širi opseg ne nastaje automatski iz užeg opsega

Roditeljska prava proveravaju se preko važeće veze roditelja/staratelja i deteta. UR opseg proverava se preko aktivne funkcije `UR` i aktivne sekcijske dodele.

## 5. Bezbednost

* Klijent ne sme direktno menjati tabele dozvola.
* Promene se izvršavaju kroz kontrolisane bazne funkcije dostupne samo predsedniku.
* Prosleđeni `actor_member_id` ne sme biti dovoljan dokaz identiteta; nakon povezivanja Auth-a mora odgovarati prijavljenom korisniku.
* RLS i kontrolisane funkcije moraju proveravati istu centralnu dozvolu.
* Sakriveno dugme ili kartica nisu bezbednosna zaštita.
* Suspendovano društvo ostaje u opštem `read-only` režimu bez obzira na dozvole korisnika.

## 6. Plan interfejsa

### `Podešavanja → Funkcije i zaduženja`

Predsednik:

* vidi aktivne članove i njihove funkcije
* dodeljuje i deaktivira funkcije
* ne može ukloniti sopstvenu obaveznu funkciju i zaključati društvo
* pri uklanjanju funkcije `UR` ili `Korepetitor` dobija upozorenje o aktivnim sekcijskim dodelama
* potvrdom deaktivira povezane aktivne sekcijske dodele, bez brisanja istorije

U modulima sekcija kandidat za UR-a ili korepetitora prikazuje se samo ako već ima odgovarajuću aktivnu funkciju.

### `Podešavanja → Dozvole`

Ovaj deo vidi samo predsednik.

Tok:

1. bira funkciju
2. podrazumevano uređuje pravila za sve članove funkcije
3. po potrebi uključuje `Pojedinačni izuzetak`
4. pretražuje i bira aktivnog člana koji ima izabranu funkciju
5. dozvole vidi grupisane po modulima
6. za svaku dozvolu vidi pregled, izmenu, posebnu radnju i opseg
7. zaključana prava imaju oznaku i ne mogu se menjati
8. pojedinačni prikaz koristi `INHERIT`, `ALLOW` i `DENY`
9. ekran prikazuje efektivno pravo i izvor kada član ima više funkcija

Obavezno ponašanje forme:

* `Sačuvaj` je aktivan samo kada postoje izmene
* `Otkaži izmene` odmah vraća poslednje sačuvano stanje i ne zahteva naknadno čuvanje
* promena taba, funkcije, člana ili napuštanje stranice sa nesačuvanim izmenama prikazuje upozorenje
* čuvanje osetljivih izmena traži razlog
* uspeh ili greška moraju biti jasno prikazani

### Objedinjeni korisnički prikaz

Navigacija i akcije računaju se iz efektivnih dozvola. Korisnik ne menja aktivnu funkciju. Sve dozvoljene kartice i akcije prikazuju se zajedno, bez dupliranja.

## 7. Redosled implementacije

### Faza 1 — katalog i struktura

1. SQL za nove tabele, ograničenja i indekse
2. početni katalog potvrđenih dozvola
3. početni šabloni funkcija
4. bootstrap postojećih društava i automatska primena šablona pri kreiranju funkcija budućih društava, bez promene trenutnog ponašanja
5. read-only dijagnostika podataka

### Faza 2 — centralni obračun

1. funkcija za efektivna prava
2. funkcija za proveru prava i opsega
3. funkcije za predsedničku izmenu pravila i izuzetaka
4. audit promena
5. testovi sabiranja funkcija, `ALLOW`, `DENY` i opsega

### Faza 3 — predsednički interfejs

1. `Funkcije i zaduženja`
2. `Dozvole`
3. zaštita nesačuvanih izmena
4. prikaz zaključanih i efektivnih prava

### Faza 4 — sprovođenje po modulima

Postojeće provere naziva funkcija menjaju se centralnim dozvolama sledećim redom:

1. članovi i lični podaci
2. sekcije
3. prisustvo
4. događaji i repertoar
5. finansije
6. navigacija i objedinjeni prikaz

Svaki modul se završava proverom baze, serverskog toka i interfejsa pre prelaska na sledeći.

### Faza 5 — finalni Auth i RLS

1. povezivanje korisnika sa `people` i `society_members`
2. uklanjanje testnih uloga i razvojnih `anon` pravila
3. finalne RLS politike
4. pokušaji direktnog nedozvoljenog pristupa
5. test korisnika sa više funkcija i dva društva

## 8. Testovi prihvatanja

Obavezno proveriti:

* predsednik uvek zadržava sva prava
* samo predsednik vidi podešavanja dozvola
* promena cele funkcije utiče na sve njene članove
* pojedinačni izuzetak utiče samo na izabranog člana
* `INHERIT`, `ALLOW` i `DENY` daju očekivano efektivno pravo
* prava više funkcija se sabiraju i prikazuju zajedno
* sekcijski opseg ne otvara druge sekcije bez posebnog prava
* roditelj vidi samo povezanu decu
* član vidi samo svoje podatke
* osetljivi podaci zahtevaju posebnu dozvolu
* suspendovano društvo ostaje `read-only`
* svaka izmena ima potpun audit
* direktan nedozvoljeni poziv bazi se odbija čak i kada korisnik zaobiđe interfejs

## 9. Važna migraciona napomena

Trenutni finansijski i drugi SQL tokovi na više mesta direktno proveravaju nazive funkcija, na primer `Predsednik` ili `Blagajnik`. Ekran dozvola ne sme biti pušten kao funkcionalan dok odgovarajući bazni tokovi ne počnu da koriste centralnu proveru efektivnih prava.

Migracija zato mora ići modul po modul, bez privremenog stanja u kojem interfejs prikazuje dodeljeno pravo, a baza ga odbija ili obrnuto.

## 10. Pauza pre predsedničkog interfejsa

Odlukom od 2026-07-26 ne uvodi se novi dev adapter za dozvole. Pre izrade ekrana `Funkcije i zaduženja` i `Dozvole` projekat prelazi na pripremu stvarnog Supabase Auth identiteta.

Nastavak modela dozvola zavisi od koraka iz `docs/AUTH_V1_READINESS.md`: read-only dijagnostika, identitet korisnika, kontekst društva, onboarding/login i siguran `authenticated` pristup. Postojeći DEV pristup uklanja se modul po modul tek nakon provere finalne zamene.
