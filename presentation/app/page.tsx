import Image from "next/image";
import Link from "next/link";
import { CustomPlanInquiryForm } from "./CustomPlanInquiryForm";

const features = [
  ["01", "Članovi i roditelji", "Podaci, statusi, kontakti i istorija članstva povezani na jednom mestu."],
  ["02", "Sekcije i prisustvo", "Organizujte sekcije i brzo evidentirajte dolaske direktno na probi."],
  ["03", "Članarine i finansije", "Pratite obaveze, uplate, popuste i povraćaje kroz jasan pregled."],
  ["04", "Koncerti i putovanja", "Planirajte događaje, učesnike, troškove i potrebnu dokumentaciju."],
  ["05", "Garderoba", "Znajte gde se nalaze nošnje, kompleti i pojedinačni delovi garderobe."],
  ["06", "Uloge i ovlašćenja", "Svako vidi i uređuje samo ono za šta mu je poverena odgovornost."]
];

const plans = [
  { code: "SMALL", name: "Folkloraš Start", price: "9,60 €", annual: "96 € godišnje", capacity: "Do 100 članova", sections: "Do 6 sekcija" },
  { code: "STANDARD", name: "Folkloraš Plus", price: "18 €", annual: "180 € godišnje", capacity: "Do 250 članova", sections: "Do 12 sekcija", featured: true },
  { code: "LARGE", name: "Folkloraš Pro", price: "30 €", annual: "300 € godišnje", capacity: "Do 500 članova", sections: "Do 20 sekcija" }
];

function ArrowIcon() {
  return <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6" /></svg>;
}

export default function MarketingHome() {
  const loginUrl = "/prijava";
  const registrationUrl = "/registracija-drustva";

  return (
    <main className="marketing-page">
      <header className="marketing-header">
        <Link className="marketing-brand" href="/" aria-label="Folkloraš, početna">
          <Image alt="" height={48} priority src="/brand/folkloras-logo.png" unoptimized width={48} />
          <span>FOLKLORAŠ</span>
        </Link>
        <nav aria-label="Glavna navigacija">
          <a href="#mogucnosti">Mogućnosti</a><a href="#kako-radi">Kako funkcioniše</a><a href="#paketi">Paketi</a>
        </nav>
        <a className="button marketing-login" href={loginUrl}>Prijavite se</a>
      </header>

      <section className="marketing-hero">
        <div className="hero-copy">
          <p className="marketing-kicker"><span /> Platforma napravljena za folklorna društva</p>
          <h1><span className="no-wrap">Vođenje KUD-a</span> na <em>jednom mestu.</em></h1>
          <p className="hero-lead">Članovi, sekcije, prisustvo, članarine, nastupi i garderoba — pregledno, povezano i dostupno ljudima kojima ste poverili odgovornost.</p>
          <div className="hero-actions">
            <a className="button marketing-primary" href={registrationUrl}>Isprobajte Folkloraš besplatno <ArrowIcon /></a>
            <a className="marketing-text-link" href="#mogucnosti">Pogledajte mogućnosti</a>
          </div>
        </div>

        <div className="product-preview" aria-label="Primer kontrolne table Folkloraš aplikacije">
          <div className="preview-window-bar"><i /><i /><i /><span>app.folkloras.rs</span></div>
          <div className="preview-app">
            <aside>
              <div className="preview-logo"><Image alt="" height={28} src="/brand/folkloras-logo.png" unoptimized width={28} /><b>FOLKLORAŠ</b></div>
              {['Pregled', 'Članovi', 'Moje sekcije', 'Prisustvo', 'Finansije'].map((item, index) => <span className={index === 0 ? 'active' : ''} key={item}><i />{item}</span>)}
            </aside>
            <div className="preview-content">
              <div className="preview-heading"><div><small>DOBRO DOŠLI</small><strong>Pregled društva</strong></div><span>FK</span></div>
              <div className="preview-stats">
                <article><small>AKTIVNI ČLANOVI</small><strong>184</strong><em>+ 8 ovog meseca</em></article>
                <article><small>DANAŠNJE PROBE</small><strong>4</strong><em>Prva počinje u 17:30</em></article>
                <article><small>NAPLATA ČLANARINE</small><strong>91%</strong><em>Tekući mesec</em></article>
              </div>
              <div className="preview-bottom">
                <article><small>PRISUSTVO PO SEKCIJAMA</small><div className="mini-bars"><i style={{height:'48%'}}/><i style={{height:'68%'}}/><i style={{height:'55%'}}/><i style={{height:'82%'}}/><i style={{height:'72%'}}/><i style={{height:'92%'}}/><i style={{height:'76%'}}/></div></article>
                <article><small>SLEDEĆI DOGAĐAJ</small><b>Godišnji koncert</b><span>18. oktobar · 19:00</span><hr/><em>126 učesnika</em></article>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="marketing-problem">
        <div><p className="marketing-kicker">SVE JE POVEZANO</p><h2>Manje tabela, poruka i papirologije.<br/>Više vremena za društvo.</h2></div>
        <p>Kada se podaci o članovima, probama, članarinama i nastupima nalaze na različitim mestima, i jednostavan zadatak postaje komplikovan. Folkloraš povezuje svakodnevne poslove u jedan pregledan sistem.</p>
      </section>

      <section className="marketing-section features-section" id="mogucnosti">
        <div className="section-heading"><p className="marketing-kicker">MOGUĆNOSTI PLATFORME</p><h2>Sve što vam je potrebno za svakodnevni rad</h2><p>Jednostavni alati, prilagođeni stvarnoj organizaciji KUD-a.</p></div>
        <div className="feature-grid">{features.map(([number,title,text]) => <article key={title}><span>{number}</span><h3>{title}</h3><p>{text}</p></article>)}</div>
      </section>

      <section className="how-section" id="kako-radi">
        <div className="section-heading light"><p className="marketing-kicker">JEDNOSTAVAN POČETAK</p><h2>Od prijave do svakodnevnog korišćenja</h2></div>
        <div className="steps">
          <article><b>1</b><h3>Prijavite društvo</h3><p>Pošaljite osnovne podatke. Master administrator će sa vama dogovoriti probni period.</p></article>
          <article><b>2</b><h3>Podesite organizaciju</h3><p>Dodajte članove, sekcije, zaduženja i pravila prema kojima vaše društvo radi.</p></article>
          <article><b>3</b><h3>Radite preglednije</h3><p>Vodite probe, članarine, događaje i garderobu kroz jedan povezan sistem.</p></article>
        </div>
      </section>

      <section className="marketing-section pricing-section" id="paketi">
        <div className="section-heading"><p className="marketing-kicker">PAKETI</p><h2>Izaberite prostor koji odgovara vašem društvu</h2><p>Svi paketi sadrže osnovne mogućnosti platforme. Razlikuju se prema broju članova i sekcija.</p></div>
        <div className="pricing-grid">
          {plans.map(plan => <article className={plan.featured ? 'featured' : ''} key={plan.name}>{plan.featured && <span className="plan-badge">NAJČEŠĆI IZBOR</span>}<h3>{plan.name}</h3><div className="plan-price"><strong>{plan.price}</strong><span>/ mesečno</span></div><small>Cena uključuje porez od 20%</small><ul><li>{plan.capacity}</li><li>{plan.sections}</li><li>Sve osnovne mogućnosti</li></ul><p>{plan.annual}</p><a className="button" href={`${registrationUrl}?paket=${plan.code}`}>Besplatno testirajte</a></article>)}
        </div>
        <div className="custom-plan"><span>Više od 500 članova ili 20 sekcija?</span> <CustomPlanInquiryForm /></div>
      </section>

      <section className="marketing-cta">
        <div><p className="marketing-kicker">VREME JE ZA PREGLEDNIJI RAD</p><h2>Neka organizacija prati vaš rad, a ne da ga usporava.</h2><p>Prijavite društvo i upoznajte mogućnosti Folkloraša tokom probnog perioda.</p></div>
        <a className="button marketing-primary light-button" href={registrationUrl}>Započnite besplatno testiranje <ArrowIcon /></a>
      </section>

      <footer className="marketing-footer"><div className="marketing-brand"><Image alt="" height={40} src="/brand/folkloras-logo.png" unoptimized width={40}/><span>FOLKLORAŠ</span></div><p>Jedno mesto za svakodnevni rad KUD-a.</p><nav><a href="#mogucnosti">Mogućnosti</a><a href="#paketi">Paketi</a><a href={loginUrl}>Prijava</a></nav><small>© 2026 Folkloraš. Sva prava zadržana.</small></footer>
    </main>
  );
}
