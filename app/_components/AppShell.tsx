import Link from "next/link";

const menuItems = [
  { label: "Dashboard", href: "/dashboard" },
  { label: "Moje sekcije", href: "/moje-sekcije" },
  { label: "Prisustvo", href: "/prisustvo" },
  { label: "Članovi", href: "/clanovi" },
  { label: "Finansije", href: "/finansije" },
  { label: "Garderoba", href: "/garderoba" },
  { label: "Izveštaji", href: "/izvestaji" },
  { label: "Koncerti", href: "/koncerti" },
  { label: "Podešavanja", href: "/podesavanja" },
  { label: "Moji podaci", href: "/moji-podaci" }
];

export function AppShell({ children }: { children: React.ReactNode }) {
  return (
    <div className="app-shell">
      <aside className="sidebar" aria-label="Glavni meni">
        <div className="sidebar-title">FOLKLORAŠ</div>

        <nav className="menu">
          {menuItems.map((item) => (
            <Link className="menu-item" href={item.href} key={item.href}>
              {item.label}
            </Link>
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

        <main className="main-content">{children}</main>
      </div>
    </div>
  );
}
