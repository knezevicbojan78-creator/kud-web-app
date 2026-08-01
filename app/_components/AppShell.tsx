"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { getMenuItemsForRole } from "../_lib/navigation";
import {
  getSupabaseClient,
  type ApplicationMembership
} from "../_lib/supabaseClient";
import type { ApplicationRole } from "../_lib/roles";

export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const [isAuthorized, setIsAuthorized] = useState(false);
  const [authError, setAuthError] = useState("");
  const [role, setRole] = useState<ApplicationRole>("Predsednik");
  const [organizationName, setOrganizationName] = useState("");
  const [societies, setSocieties] = useState<ApplicationMembership[]>([]);
  const [selectedSocietyId, setSelectedSocietyId] = useState("");
  const [isSwitchingSociety, setIsSwitchingSociety] = useState(false);
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

  useEffect(() => {
    setIsMobileMenuOpen(false);
  }, [pathname]);

  useEffect(() => {
    if (!isMobileMenuOpen) return;

    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") setIsMobileMenuOpen(false);
    };
    window.addEventListener("keydown", closeOnEscape);

    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", closeOnEscape);
    };
  }, [isMobileMenuOpen]);

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

        if (
          destination.account_type === "PENDING_ACTIVATION" ||
          destination.destination.startsWith("/auth/")
        ) {
          router.replace(destination.destination);
          return;
        }

        if (destination.account_type === "MASTER_ADMIN") {
          setRole("Master admin");
          setOrganizationName("Administracija sistema");
        } else if (destination.account_type === "PRESIDENT") {
          const { data: presidentDashboard, error: presidentError } =
            await supabase.rpc("auth_get_president_dashboard");
          if (presidentError || !presidentDashboard) {
            throw presidentError ?? new Error("Društvo nije moguće učitati.");
          }
          setRole("Predsednik");
          setOrganizationName(presidentDashboard.society_name);
        } else {
          const { data: context, error: contextError } =
            await supabase.rpc("auth_get_application_context");
          const membership = context?.memberships?.[0];
          if (contextError || !membership) {
            throw contextError ?? new Error("Društvo nije moguće učitati.");
          }
          const functions = membership.functions ?? [];
          const nextRole: ApplicationRole = membership.is_guardian
            ? "Roditelj"
            : functions.includes("UR")
              ? "UR"
              : functions.includes("Blagajnik")
                ? "Blagajnik"
                : functions.includes("Sekretar")
                  ? "Sekretar"
                  : "Član";
          setRole(nextRole);
          setOrganizationName(membership.society_name);
          setSocieties(context.memberships);
          setSelectedSocietyId(membership.society_id);
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

  async function changeSociety(societyId: string) {
    if (!societyId || societyId === selectedSocietyId) return;
    setIsSwitchingSociety(true);
    setAuthError("");
    const { error } = await getSupabaseClient().rpc("auth_select_society", {
      p_society_id: societyId
    });
    if (error) {
      setAuthError(error.message);
      setIsSwitchingSociety(false);
      return;
    }
    window.location.reload();
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
      <button
        aria-label="Zatvori glavni meni"
        className={isMobileMenuOpen ? "menu-backdrop open" : "menu-backdrop"}
        onClick={() => setIsMobileMenuOpen(false)}
        tabIndex={isMobileMenuOpen ? 0 : -1}
        type="button"
      />
      <aside
        className={isMobileMenuOpen ? "sidebar open" : "sidebar"}
        aria-label="Glavni meni"
        id="main-navigation"
      >
        <div className="sidebar-title">
          <Image
            alt=""
            aria-hidden="true"
            className="sidebar-brand-logo"
            height={30}
            priority
            src="/brand/folkloras-logo.png"
            width={30}
          />
          <span>FOLKLORAŠ</span>
        </div>

        <nav className="menu">
          {menuItems.map((item) => (
            <Link
              className={
                pathname === item.href ? "menu-item active" : "menu-item"
              }
              href={item.href}
              key={item.href}
              onClick={() => setIsMobileMenuOpen(false)}
            >
              {item.label}
            </Link>
          ))}
        </nav>
      </aside>

      <div className="content-shell">
        <header className="top-header">
          <div className="header-main">
            <button
              aria-controls="main-navigation"
              aria-expanded={isMobileMenuOpen}
              aria-label="Otvori glavni meni"
              className="mobile-menu-button"
              onClick={() => setIsMobileMenuOpen(true)}
              type="button"
            >
              <span aria-hidden="true">☰</span>
            </button>
            <span className="mobile-role-name">Uloga: {role}</span>
            <button
              className="button button-primary mobile-sign-out"
              onClick={signOut}
              type="button"
            >
              Odjava
            </button>
            <div className="header-brand">{organizationName}</div>
          </div>

          <div className="header-actions">
            {societies.length > 1 ? (
              <label className="header-society-picker">
                <span>Društvo</span>
                <select
                  disabled={isSwitchingSociety}
                  onChange={(event) => void changeSociety(event.target.value)}
                  value={selectedSocietyId}
                >
                  {societies.map((society) => (
                    <option key={society.society_id} value={society.society_id}>
                      {society.society_name}
                    </option>
                  ))}
                </select>
              </label>
            ) : null}
            <span className="organization-name desktop-role-name">Uloga: {role}</span>
            <button
              className="button button-primary desktop-sign-out"
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
