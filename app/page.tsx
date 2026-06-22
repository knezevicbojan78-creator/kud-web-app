const menuItems = [
  "Dashboard",
  "Moje sekcije",
  "Prisustvo",
  "Članovi",
  "Finansije",
  "Garderoba",
  "Izveštaji",
  "Koncerti",
  "Podešavanja",
  "Moji podaci"
];

const dashboardCards = [
  {
    title: "Ukupno članova",
    value: "128",
    note: "Pregled svih članova društva"
  },
  {
    title: "Aktivne sekcije",
    value: "6",
    note: "Folklor, hor i ostale sekcije"
  },
  {
    title: "Prisustvo danas",
    value: "42",
    note: "Evidentirani dolasci za danas"
  },
  {
    title: "Dugovanja članarine",
    value: "18",
    note: "Članovi sa otvorenim dugovanjem"
  }
];

export default function Home() {
  return (
    <div className="app-shell">
      <aside className="sidebar" aria-label="Glavni meni">
        <div className="sidebar-title">FOLKLORAŠ</div>

        <nav className="menu">
          {menuItems.map((item) => (
            <a
              className={item === "Dashboard" ? "menu-item active" : "menu-item"}
              href="#"
              key={item}
            >
              {item}
            </a>
          ))}
        </nav>
      </aside>

      <div className="content-shell">
        <header className="top-header">
          <div className="header-brand">App KUD</div>

          <div className="header-actions">
            <span className="organization-name">KUD Mitanče</span>
            <button className="logout-button" type="button">
              Odjava
            </button>
          </div>
        </header>

        <main className="main-content">
          <section className="page-heading">
            <p className="eyebrow">Dashboard</p>
            <h1>Pregled rada društva</h1>
            <p>
              Ovo je početna, vizuelna tabla aplikacije. Podaci su trenutno
              samo primeri i nisu povezani sa bazom.
            </p>
          </section>

          <section className="card-grid" aria-label="Dashboard kartice">
            {dashboardCards.map((card) => (
              <article className="dashboard-card" key={card.title}>
                <p>{card.title}</p>
                <strong>{card.value}</strong>
                <span>{card.note}</span>
              </article>
            ))}
          </section>
        </main>
      </div>
    </div>
  );
}
