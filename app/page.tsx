"use client";

import { useState } from "react";

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
  const [showDashboard, setShowDashboard] = useState(false);

  if (!showDashboard) {
    return (
      <main className="login-page">
        <section className="card login-card">
          <div className="login-brand">
            <p className="eyebrow">Dobrodošli</p>
            <h1>FOLKLORAŠ</h1>
            <span>KUD Mitanče</span>
          </div>

          <form
            className="form-stack"
            onSubmit={(event) => {
              event.preventDefault();
              setShowDashboard(true);
            }}
          >
            <label className="form-field">
              <span>Email</span>
              <input className="input" type="email" placeholder="ime@email.com" />
            </label>

            <label className="form-field">
              <span>Lozinka</span>
              <input
                className="input"
                type="password"
                placeholder="Unesite lozinku"
              />
            </label>

            <button className="button button-primary" type="submit">
              Prijavi se
            </button>
          </form>

          <div className="login-links">
            <a href="#">Zaboravljena lozinka?</a>
            <a className="button button-secondary" href="#">
              Registracija društva
            </a>
          </div>
        </section>
      </main>
    );
  }

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
          <div className="header-brand">FOLKLORAŠ</div>

          <div className="header-actions">
            <span className="organization-name">KUD Mitanče</span>
            <button className="button button-primary" type="button">
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
              <article className="card dashboard-card" key={card.title}>
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
