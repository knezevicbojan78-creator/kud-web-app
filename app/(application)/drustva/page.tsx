"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import {
  getSupabaseClient,
  type MasterSocietySummary
} from "../../_lib/supabaseClient";
import { licensePlanDisplayName } from "../../_lib/licensePlanNames";

function formatDate(value: string | null) {
  if (!value) return "Nije dostupno";
  return new Intl.DateTimeFormat("sr-Latn-RS", { dateStyle: "medium" }).format(
    new Date(value)
  );
}

function societyStatusLabel(status: MasterSocietySummary["status"]) {
  if (status === "ACTIVE") return "AKTIVNO";
  if (status === "ONBOARDING") return "ČEKA ONBOARDING";
  return "SUSPENDOVANO";
}

export default function DrustvaPage() {
  const [societies, setSocieties] = useState<MasterSocietySummary[]>([]);
  const [query, setQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState("ALL");
  const [licenseFilter, setLicenseFilter] = useState("ALL");
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState("");

  useEffect(() => {
    async function loadSocieties() {
      setIsLoading(true);
      setErrorMessage("");
      const { data, error } = await getSupabaseClient().rpc(
        "master_admin_get_society_summaries"
      );

      if (error) {
        setErrorMessage(
          "Agregatni pregled društava nije učitan. Primenite supabase/master-admin-v1-setup.sql u aktivnoj bazi."
        );
        setSocieties([]);
      } else {
        setSocieties(data ?? []);
      }
      setIsLoading(false);
    }

    void loadSocieties();
  }, []);

  const licenseOptions = useMemo(
    () =>
      Array.from(
        new Set(societies.map((society) => society.license_type ?? "Nije dodeljena"))
      ).sort((a, b) => a.localeCompare(b, "sr-Latn")),
    [societies]
  );

  const visibleSocieties = useMemo(() => {
    const normalizedQuery = query.trim().toLocaleLowerCase("sr-Latn");
    return societies.filter((society) => {
      const matchesQuery =
        !normalizedQuery ||
        [society.name, society.city, society.pib, society.registration_number]
          .join(" ")
          .toLocaleLowerCase("sr-Latn")
          .includes(normalizedQuery);
      const matchesStatus =
        statusFilter === "ALL" || society.status === statusFilter;
      const licenseName = society.license_type ?? "Nije dodeljena";
      const matchesLicense =
        licenseFilter === "ALL" || licenseName === licenseFilter;
      return matchesQuery && matchesStatus && matchesLicense;
    });
  }, [licenseFilter, query, societies, statusFilter]);

  return (
    <>
      <section className="page-heading master-heading">
        <div>
          <p className="eyebrow">Master admin</p>
          <h1>Društva</h1>
          <p>Administrativni pregled bez pristupa pojedinačnim članovima i sekcijama.</p>
        </div>
        <div className="master-result-count">
          <strong>{visibleSocieties.length}</strong>
          <span>od {societies.length} društava</span>
        </div>
      </section>

      <section className="card master-society-toolbar" aria-label="Filteri društava">
        <label>
          <span>Pretraga</span>
          <input
            className="input"
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Naziv, grad, PIB ili matični broj"
            type="search"
            value={query}
          />
        </label>
        <label>
          <span>Status</span>
          <select className="input" onChange={(event) => setStatusFilter(event.target.value)} value={statusFilter}>
            <option value="ALL">Svi statusi</option>
            <option value="ONBOARDING">Čeka onboarding</option>
            <option value="ACTIVE">Aktivna</option>
            <option value="SUSPENDED">Suspendovana</option>
          </select>
        </label>
        <label>
          <span>Licenca</span>
          <select className="input" onChange={(event) => setLicenseFilter(event.target.value)} value={licenseFilter}>
            <option value="ALL">Sve licence</option>
            {licenseOptions.map((license) => <option key={license}>{license}</option>)}
          </select>
        </label>
      </section>

      {isLoading && <section className="card dashboard-card">Učitavanje društava...</section>}
      {errorMessage && <p className="alert alert-error">{errorMessage}</p>}

      {!isLoading && !errorMessage && visibleSocieties.length === 0 && (
        <section className="card dashboard-card">Nema društava za izabrane filtere.</section>
      )}

      {!isLoading && !errorMessage && visibleSocieties.length > 0 && (
        <section className="card master-society-table-wrap">
          <table className="master-society-table">
            <thead>
              <tr>
                <th>Društvo</th>
                <th>PIB / matični broj</th>
                <th>Članovi</th>
                <th>Sekcije</th>
                <th>Licenca</th>
                <th>Status</th>
                <th>Registrovano</th>
                <th><span className="sr-only">Akcija</span></th>
              </tr>
            </thead>
            <tbody>
              {visibleSocieties.map((society) => (
                <tr key={society.id}>
                  <td><strong>{society.name}</strong><span>{society.city}</span></td>
                  <td><strong>{society.pib}</strong><span>{society.registration_number}</span></td>
                  <td><strong>{society.active_member_count}</strong><span>aktivnih</span></td>
                  <td><strong>{society.active_section_count}</strong><span>aktivnih</span></td>
                  <td>{licensePlanDisplayName(society.license_type)}</td>
                  <td>
                    <span className={`master-status ${society.status.toLowerCase()}`}>
                      {societyStatusLabel(society.status)}
                    </span>
                  </td>
                  <td>{formatDate(society.registered_at)}</td>
                  <td><Link className="button button-secondary" href={`/drustva/${society.id}`}>OTVORI</Link></td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}
    </>
  );
}
