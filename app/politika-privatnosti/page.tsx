import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Politika privatnosti i kolačića | Folkloraš",
  description: "Informacije o obradi podataka o ličnosti i upotrebi kolačića na platformi Folkloraš."
};

export default function PrivacyPolicyPage() {
  return (
    <main className="privacy-page"><article className="privacy-card">
      <Link className="privacy-back" href="/">← Nazad na početnu</Link>
      <p className="privacy-eyebrow">FOLKLORAŠ</p><h1>Politika privatnosti i kolačića</h1>
      <p className="privacy-updated">Poslednje ažuriranje: 2. avgust 2026.</p>
      <p>Ova politika objašnjava kako se obrađuju podaci kada posećujete sajt <strong>folkloras.rs</strong>, registrujete društvo ili koristite platformu Folkloraš.</p>

      <h2>1. Ko je odgovoran za podatke</h2>
      <p>Za podatke posetilaca sajta, registracije društva, poslovnu komunikaciju i upravljanje platformom rukovalac je:</p>
      <address><strong>Bojan Knežević preduzetnik Ostalo štampanje Design Studio Art Craft Belegiš</strong><br />Kralja Petra Prvog Karađorđevića 48, 22306 Belegiš, Srbija<br />Matični broj: 63411221 · PIB: 108378874<br />E-pošta: <a href="mailto:knezevic.bojan78@gmail.com">knezevic.bojan78@gmail.com</a><br />Telefon: <a href="tel:+381658651682">+381 65 865 1682</a></address>
      <p>Kada kulturno-umetničko društvo unosi podatke svojih članova, roditelja, zaposlenih ili saradnika, to društvo određuje svrhu i način obrade tih podataka, dok Folkloraš podatke obrađuje za njegov račun radi pružanja usluge.</p>

      <h2>2. Koje podatke obrađujemo</h2>
      <ul><li>podatke koje unesete prilikom registracije društva, otvaranja i korišćenja naloga;</li><li>kontakt i poslovne podatke iz poruka, zahteva za probni period i korisničke podrške;</li><li>podatke koje ovlašćeni korisnici unesu o članovima, roditeljima, sekcijama, prisustvu, članarinama, događajima i garderobi;</li><li>tehničke i bezbednosne podatke potrebne za prijavu, rad sistema, rešavanje grešaka i zaštitu naloga;</li><li>podatke o posećenosti, približnoj lokaciji, uređaju, pregledaču i korišćenju stranica, ali samo ako prihvatite analitičke kolačiće.</li></ul>

      <h2>3. Svrhe i pravni osnov</h2>
      <p>Podatke obrađujemo radi pružanja ugovorene usluge, registracije i administracije naloga, komunikacije, naplate, bezbednosti sistema, ispunjavanja zakonskih obaveza i ostvarivanja legitimnih poslovnih interesa koji ne pretežu nad pravima lica. Google Analytics koristimo isključivo na osnovu vaše saglasnosti, koju možete povući u svakom trenutku.</p>

      <h2>4. Kolačići i lokalna memorija</h2>
      <p>Neophodna lokalna memorija čuva vaš izbor kolačića pod nazivom <code>folkloras-cookie-consent-v1</code>. Ona ne služi oglašavanju i potrebna je da sajt zapamti da li ste prihvatili ili odbili analitiku.</p>
      <p>Ako prihvatite analitiku, Google Analytics može postaviti kolačiće <code>_ga</code> i <code>_ga_*</code>. Oni služe razlikovanju poseta i izradi zbirnih izveštaja. Ne šaljemo Google Analyticsu imena, e-adrese, telefone niti druge podatke koje direktno unosite u aplikaciju.</p>

      <h2>5. Primaoci i pružaoci usluga</h2>
      <p>Za tehnički rad platforme mogu se koristiti pažljivo odabrani pružaoci infrastrukture i komunikacionih usluga, uključujući Vercel za isporuku sajta, Supabase za bazu podataka i autentifikaciju, Google za slanje povezane poslovne e-pošte i, uz saglasnost, Google Analytics. Podaci se dele samo u meri potrebnoj za konkretnu uslugu i uz odgovarajuće ugovorne i bezbednosne mere.</p>

      <h2>6. Prenos podataka u druge države</h2>
      <p>Pojedini pružaoci usluga mogu obrađivati podatke izvan Srbije. U takvim slučajevima primenjuju se odgovarajući mehanizmi zaštite i ugovorne mere koje pružalac usluge nudi za međunarodni prenos podataka.</p>

      <h2>7. Rok čuvanja</h2>
      <p>Podatke čuvamo dok je nalog ili poslovni odnos aktivan, odnosno onoliko dugo koliko je potrebno za navedene svrhe, rešavanje zahteva, zaštitu sistema i ispunjavanje zakonskih obaveza. Po prestanku potrebe podaci se brišu ili anonimizuju, osim kada zakon zahteva duže čuvanje.</p>

      <h2>8. Vaša prava</h2>
      <p>U skladu sa važećim propisima možete tražiti pristup, ispravku, brisanje, ograničenje obrade, prenosivost podataka i uložiti prigovor. Saglasnost možete povući bez uticaja na zakonitost ranije obrade. Zahtev pošaljite na <a href="mailto:knezevic.bojan78@gmail.com">knezevic.bojan78@gmail.com</a>. Takođe imate pravo da se obratite Povereniku za informacije od javnog značaja i zaštitu podataka o ličnosti.</p>

      <h2>9. Podaci maloletnih lica</h2>
      <p>Podatke maloletnih članova u platformu unose samo ovlašćena lica društva u skladu sa svojim pravilima, odgovarajućim pravnim osnovom i obavezama prema roditeljima ili starateljima. Platforma nije namenjena samostalnoj registraciji dece kao korisnika javnog sajta.</p>

      <h2>10. Bezbednost i izmene politike</h2>
      <p>Primenjujemo tehničke i organizacione mere radi zaštite podataka od neovlašćenog pristupa, izmene, gubitka ili zloupotrebe. Ovu politiku možemo menjati kada se promene funkcije, pružaoci usluga ili propisi; datum poslednje izmene biće naveden na vrhu stranice.</p>
      <div className="privacy-actions"><button className="privacy-settings" data-cookie-settings type="button">Podešavanja kolačića</button><Link href="/">Povratak na Folkloraš</Link></div>
    </article></main>
  );
}
