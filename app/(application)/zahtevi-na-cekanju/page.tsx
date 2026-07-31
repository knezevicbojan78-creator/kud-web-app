"use client";

import Link from "next/link";
import { usePresidentRequests } from "../../_hooks/usePresidentRequests";

const pendingSearchFields = [
  "societyName",
  "city",
  "PIB",
  "registrationNumber",
  "presidentFirstName",
  "presidentLastName",
  "presidentEmail"
] as const;

function formatDate(value: string) {
  return new Intl.DateTimeFormat("sr-RS", {
    dateStyle: "medium",
    timeStyle: "short"
  }).format(new Date(value));
}

export default function ZahteviNaCekanjuPage() {
  const { requests, visibleRequests, query, setQuery, isLoading, errorMessage } =
    usePresidentRequests({
      status: "PENDING",
      searchFields: pendingSearchFields,
      loadErrorMessage: "Zahtevi nisu učitani. Proverite Supabase RLS policy za Master admin čitanje.",
      rlsErrorMessage: "SELECT blocked by RLS policy"
    });

  return (
    <>
      <section className="page-heading master-heading">
        <div>
          <p className="eyebrow">Zahtevi na čekanju</p>
          <h1>Nove registracije</h1>
          <p>Pregled zahteva koji čekaju odluku Master admina.</p>
        </div>
        <div className="master-result-count">
          <strong>{visibleRequests.length}</strong>
          <span>od {requests.length} zahteva</span>
        </div>
      </section>

      {!isLoading && !errorMessage && requests.length > 0 && (
        <section className="card approved-request-toolbar">
          <label>
            <span>Pretraga</span>
            <input
              className="input"
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Društvo, predsednik, email, PIB ili matični broj"
              type="search"
              value={query}
            />
          </label>
        </section>
      )}

      {isLoading && (
        <section className="card dashboard-card">
          <p>Učitavanje zahteva...</p>
        </section>
      )}

      {errorMessage && (
        <section className="card dashboard-card" role="alert">
          <p>{errorMessage}</p>
        </section>
      )}

      {!isLoading && !errorMessage && requests.length === 0 && (
        <section className="card dashboard-card">
          <p>Nema zahteva na čekanju.</p>
        </section>
      )}

      {!isLoading && !errorMessage && requests.length > 0 && visibleRequests.length === 0 && (
        <section className="card dashboard-card">
          <p>Nema zahteva za unetu pretragu.</p>
        </section>
      )}

      {!isLoading && !errorMessage && visibleRequests.length > 0 && (
        <section className="card master-society-table-wrap" aria-label="Zahtevi na čekanju">
          <table className="master-society-table pending-request-table">
            <thead>
              <tr>
                <th>Društvo</th>
                <th>PIB / matični broj</th>
                <th>Predsednik</th>
                <th>Kontakt</th>
                <th>Poslato</th>
                <th>Status</th>
                <th><span className="sr-only">Akcija</span></th>
              </tr>
            </thead>
            <tbody>
              {visibleRequests.map((request) => (
                <tr key={request.id}>
                  <td>
                    <strong>{request.societyName}</strong>
                    <span>{request.city}</span>
                  </td>
                  <td>
                    <strong>{request.PIB}</strong>
                    <span>{request.registrationNumber}</span>
                  </td>
                  <td>{request.presidentFirstName} {request.presidentLastName}</td>
                  <td>{request.presidentEmail}</td>
                  <td>{formatDate(request.createdAt)}</td>
                  <td><span className="master-status pending">NA ČEKANJU</span></td>
                  <td>
                    <Link
                      className="button button-secondary"
                      href={`/zahtevi-na-cekanju/${request.id}`}
                    >
                      DETALJI
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}
    </>
  );
}
