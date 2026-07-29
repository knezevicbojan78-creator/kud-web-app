"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { getMenuItemsForRole } from "../_lib/navigation";
import { getSupabaseClient } from "../_lib/supabaseClient";
import type { ApplicationRole } from "../_lib/roles";

export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const [isAuthorized, setIsAuthorized] = useState(false);
  const [authError, setAuthError] = useState("");
  const [role, setRole] = useState<ApplicationRole>("Predsednik");
  const [organizationName, setOrganizationName] = useState("");

  useEffect(() => {
    let active = true;

    async function authorize() {
      try {
        const supabase = getSupabaseClient();
        const { data } = await supabase.auth.getSession();

        if (!data.session) {
          router.replace("/");
          return;
        }

        const { data: destination, error: destinationError } =
          await supabase.rpc("auth_get_login_destination");
        if (destinationError || !destination) {
          throw destinationError ?? new Error("Pristup aplikaciji nije određen.");
        }

        if (destination.destination !== "/dashboard") {
          router.replace(destination.destination);
          return;
        }

        if (destination.account_type === "MASTER_ADMIN") {
          setRole("Master admin");
          setOrganizationName("Administracija sistema");
        } else {
          const { data: presidentDashboard, error: presidentError } =
            await supabase.rpc("auth_get_president_dashboard");
          if (presidentError || !presidentDashboard) {
            throw presidentError ?? new Error("Društvo nije moguće učitati.");
          }
          setRole("Predsednik");
          setOrganizationName(presidentDashboard.society_name);
        }

        if (active) {
          setIsAuthorized(true);
        }
      } catch (error) {
        if (active) {
          setAuthError(
            error instanceof Error
              ? error.message
              : "Pristup aplikaciji nije moguće proveriti."
          );
        }
      }
    }

    void authorize();
    return () => {
      active = false;
    };
  }, [router]);

  const menuItems = getMenuItemsForRole(role);

  async function signOut() {
    await getSupabaseClient().auth.signOut();
    router.replace("/");
  }

  if (authError) {
    return (
      <main className="login-page">
        <section className="card login-card auth-center">
          <div className="auth-message error">{authError}</div>
          <button
            className="button button-secondary"
            onClick={signOut}
            type="button"
          >
            Nazad na prijavljivanje
          </button>
        </section>
      </main>
    );
  }

  if (!isAuthorized) {
    return (
      <main className="login-page">
        <section className="card login-card auth-center">
          <p>Provera pristupa...</p>
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
          <div className="header-brand">{organizationName}</div>

          <div className="header-actions">
            <span className="organization-name">Uloga: {role}</span>
            <button
              className="button button-primary"
              onClick={signOut}
              type="button"
            >
              Odjava
            </button>
          </div>
        </header>

        <main className="main-content">{children}</main>
      </div>
    </div>
  );
}
