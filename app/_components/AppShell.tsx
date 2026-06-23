"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import {
  DEFAULT_TEST_ROLE,
  TEST_ROLE_STORAGE_KEY,
  type TestRole
} from "../_lib/testRoles";

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
  const pathname = usePathname();
  const [selectedRole, setSelectedRole] =
    useState<TestRole>(DEFAULT_TEST_ROLE);

  useEffect(() => {
    const savedRole = localStorage.getItem(TEST_ROLE_STORAGE_KEY);

    if (savedRole) {
      setSelectedRole(savedRole as TestRole);
    }
  }, []);

  return (
    <div className="app-shell">
      <aside className="sidebar" aria-label="Glavni meni">
        <div className="sidebar-title">FOLKLORAŠ</div>

        <nav className="menu">
          {menuItems.map((item) => (
            <Link
              className={
                pathname === item.href ? "menu-item active" : "menu-item"
              }
              href={item.href}
              key={item.href}
            >
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
            <span className="organization-name">Uloga: {selectedRole}</span>
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
