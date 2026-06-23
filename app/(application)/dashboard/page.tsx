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

export default function DashboardPage() {
  return (
    <>
      <section className="page-heading">
        <p className="eyebrow">Dashboard</p>
        <h1>Pregled rada društva</h1>
        <p>
          Ovo je početna, vizuelna tabla aplikacije. Podaci su trenutno samo
          primeri i nisu povezani sa bazom.
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
    </>
  );
}
