"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import {
  getSupabaseClient,
  type MasterDashboardData,
  type PresidentDashboardData
} from "../../_lib/supabaseClient";
import { licensePlanDisplayName } from "../../_lib/licensePlanNames";

function formatDateTime(value: string) {
  return new Intl.DateTimeFormat("sr-Latn-RS", {
    dateStyle: "medium",
    timeStyle: "short"
  }).format(new Date(value));
}

export default function DashboardPage() {
  const [data, setData] = useState<MasterDashboardData | null>(null);
  const [presidentData, setPresidentData] =
    useState<PresidentDashboardData | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    async function loadDashboard() {
      setIsLoading(true);
      setError("");
      const supabase = getSupabaseClient();
      const { data: destination, error: destinationError } =
        await supabase.rpc("auth_get_login_destination");

      if (destinationError || !destination) {
        setError(destinationError?.message || "Pristup dashboardu nije određen.");
        setIsLoading(false);
        return;
      }

      if (destination.account_type === "PRESIDENT") {
        const { data: dashboardData, error: dashboardError } =
          await supabase.rpc("auth_get_president_dashboard");
        if (dashboardError) {
          setError(dashboardError.message || "Podaci društva nisu mogli da se učitaju.");
          setPresidentData(null);
        } else {
          setPresidentData(dashboardData);
          setData(null);
        }
        setIsLoading(false);
        return;
      }

      const { data: dashboardData, error: dashboardError } =
        await supabase.rpc("master_admin_get_dashboard");

      if (dashboardError) {
        setError(
          dashboardError.message ||
            "Master admin podaci nisu mogli da se učitaju."
        );
        setData(null);
      } else {
        setData(dashboardData);
      }
      setIsLoading(false);
    }

    void loadDashboard();
  }, []);

  if (isLoading) {
    return <section className="card dashboard-card">Učitavanje dashboarda...</section>;
  }

  if (presidentData) {
    const presidentCards = [
      {
        title: "Aktivni članovi",
        value: presidentData.active_member_count,
        note: "Članovi evidentirani u društvu"
      },
      {
        title: "Aktivne sekcije",
        value: presidentData.active_section_count,
        note: "Sekcije koje trenutno rade"
      },
      {
        title: "Licencni paket",
        value: licensePlanDisplayName(presidentData.license_type),
        note: presidentData.current_license_valid_until
          ? `Važi do ${presidentData.current_license_valid_until.split("-").reverse().join("/")}`
          : "Aktivna licenca"
      }
    ];

    return (
      <>
        <section className="page-heading">
          <h1>{presidentData.society_name}</h1>
        </section>
        {error && <p className="alert alert-error">{error}</p>}
        <section className="card-grid master-stat-grid" aria-label="Pokazatelji društva">
          {presidentCards.map((card) => (
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

  const masterCards = [
    { title: "Aktivna društva", value: data?.active_society_count ?? 0, note: "Društva sa punim pristupom" },
    { title: "Suspendovana", value: data?.suspended_society_count ?? 0, note: "Društva u režimu pregleda" },
    { title: "Nove registracije", value: data?.pending_registration_count ?? 0, note: "Zahtevi koji čekaju odluku" },
    { title: "Licence ističu", value: data?.expiring_license_count ?? 0, note: "U narednih 30 dana" }
  ];

  return (
    <>
      <section className="page-heading master-heading">
        <div>
          <p className="eyebrow">Master admin</p>
          <h1>Pregled platforme</h1>
          <p>Društva, registracije i licence koje zahtevaju administrativnu reakciju.</p>
        </div>
        <Link className="button button-primary" href="/zahtevi-na-cekanju">
          OTVORI ZAHTEVE
        </Link>
      </section>

      {error && <p className="alert alert-error">{error}</p>}

      <section className="card-grid master-stat-grid" aria-label="Master admin pokazatelji">
        {masterCards.map((card) => (
          <article className="card dashboard-card" key={card.title}>
            <p>{card.title}</p>
            <strong>{card.value}</strong>
            <span>{card.note}</span>
          </article>
        ))}
      </section>

      <section className="master-dashboard-grid">
        <article className="card master-dashboard-panel">
          <header>
            <div>
              <p className="eyebrow">Licence</p>
              <h2>Raspodela društava</h2>
            </div>
            <Link href="/drustva">Sva društva</Link>
          </header>
          {!data?.license_distribution.length && (
            <p className="master-empty">Još nema podataka o licencama.</p>
          )}
          <div className="master-license-list">
            {data?.license_distribution.map((item) => (
              <div key={item.license_type}>
                <span>{licensePlanDisplayName(item.license_type)}</span>
                <strong>{item.society_count}</strong>
              </div>
            ))}
          </div>
        </article>

        <article className="card master-dashboard-panel">
          <header>
            <div>
              <p className="eyebrow">Audit</p>
              <h2>Nedavne akcije</h2>
            </div>
          </header>
          {!data?.recent_actions.length && (
            <p className="master-empty">Još nema evidentiranih Master admin akcija.</p>
          )}
          <div className="master-action-list">
            {data?.recent_actions.map((action) => (
              <div key={action.id}>
                <span>
                  <strong>{action.action}</strong>
                  <small>{action.society_name ?? action.entity_type}</small>
                </span>
                <time dateTime={action.created_at}>{formatDateTime(action.created_at)}</time>
              </div>
            ))}
          </div>
        </article>
      </section>
    </>
  );
}
