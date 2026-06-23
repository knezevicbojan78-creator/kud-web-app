"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { getMenuItemsForRole } from "../_lib/navigation";
import {
  DEFAULT_TEST_ROLE,
  TEST_ROLE_STORAGE_KEY,
  TEST_ROLES,
  type TestRole
} from "../_lib/testRoles";

function isTestRole(value: string): value is TestRole {
  return TEST_ROLES.includes(value as TestRole);
}

export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const [selectedRole, setSelectedRole] =
    useState<TestRole>(DEFAULT_TEST_ROLE);

  useEffect(() => {
    const savedRole = localStorage.getItem(TEST_ROLE_STORAGE_KEY);

    if (savedRole && isTestRole(savedRole)) {
      setSelectedRole(savedRole);
    }
  }, []);

  const menuItems = getMenuItemsForRole(selectedRole);

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
