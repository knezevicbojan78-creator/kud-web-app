const modules = [
  "Login / logout",
  "Registracija društva",
  "Master admin",
  "Zahtevi na čekanju",
  "Dashboard",
  "Članovi",
  "Unos / izmena člana",
  "Sekcije",
  "Prisustvo",
  "Finansije",
  "Izveštaji",
  "Podešavanja",
  "Moji podaci"
];

export default function Home() {
  return (
    <main className="page">
      <section className="hero">
        <p className="eyebrow">KUD management system</p>
        <h1>App KUD</h1>
        <p className="intro">
          Ovo je početna web osnova aplikacije za upravljanje kulturno-umetničkim društvima.
        </p>
      </section>

      <section className="panel">
        <h2>Budući moduli</h2>
        <ul>
          {modules.map((module) => (
            <li key={module}>{module}</li>
          ))}
        </ul>
      </section>
    </main>
  );
}
