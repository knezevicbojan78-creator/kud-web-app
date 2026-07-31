"use client";

import Link from "next/link";
import { usePresidentRequests } from "../../_hooks/usePresidentRequests";

const rejectedSearchFields = [
  "societyName", "city", "PIB", "registrationNumber"
] as const;

function formatDate(value: string) {
  return new Intl.DateTimeFormat("sr-RS", {
    dateStyle: "medium",
    timeStyle: "short"
  }).format(new Date(value));
}

export default function OdbijeniZahteviPage() {
  const { requests, visibleRequests, query, setQuery, isLoading, errorMessage } =
    usePresidentRequests({
      status: "REJECTED",
      searchFields: [...rejectedSearchFields],
      loadErrorMessage: "Odbijeni zahtevi nisu učitani."
    });

  return (
    <>
      <section className="page-heading master-heading">
        <div>
          <p className="eyebrow">Odbijeni zahtevi</p>
          <h1>Odbijene registracije</h1>
          <p>Kompaktan pregled zahteva za registraciju koji nisu odobreni.</p>
        </div>
        <div className="master-result-count">
          <strong>{visibleRequests.length}</strong>
          <span>od {requests.length} odbijenih</span>
        </div>
      </section>

      {!isLoading && !errorMessage && requests.length > 0 && (
        <section className="card approved-request-toolbar">
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
          <p>Nema odbijenih zahteva.</p>
        </section>
      )}

      {!isLoading && !errorMessage && requests.length > 0 && visibleRequests.length === 0 && (
        <section className="card dashboard-card">
          <p>Nema odbijenih registracija za unetu pretragu.</p>
        </section>
      )}

      {!isLoading && !errorMessage && visibleRequests.length > 0 && (
        <section className="card master-society-table-wrap" aria-label="Odbijeni zahtevi">
          <table className="master-society-table rejected-request-table">
            <thead>
              <tr>
                <th>Društvo</th>
                <th>PIB</th>
                <th>Matični broj</th>
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
                  <td>{request.PIB}</td>
                  <td>{request.registrationNumber}</td>
                  <td>{formatDate(request.createdAt)}</td>
                  <td><span className="master-status rejected">ODBIJENO</span></td>
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
