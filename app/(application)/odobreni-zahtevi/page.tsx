"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import {
  getSupabaseClient,
  type PresidentRegistration
} from "../../_lib/supabaseClient";

type ApprovedRegistration = Pick<
  PresidentRegistration,
  | "id"
  | "societyName"
  | "city"
  | "PIB"
  | "registrationNumber"
  | "approvedAt"
  | "presidentEmail"
  | "presidentUserId"
>;

function formatDate(value: string | null) {
  if (!value) {
    return "Nije postavljeno";
  }

  return new Intl.DateTimeFormat("sr-RS", {
    dateStyle: "medium",
    timeStyle: "short"
  }).format(new Date(value));
}

export default function OdobreniZahteviPage() {
  const [requests, setRequests] = useState<ApprovedRegistration[]>([]);
  const [query, setQuery] = useState("");
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState("");
  const [actionMessage, setActionMessage] = useState("");
  const [sendingRequestId, setSendingRequestId] = useState("");

  useEffect(() => {
    async function loadApprovedRequests() {
      setIsLoading(true);
      setErrorMessage("");

      try {
        const supabase = getSupabaseClient();
        const { data, error } = await supabase.rpc(
          "master_admin_get_president_requests",
          { p_status: "APPROVED" }
        );

        if (error) {
          setErrorMessage("Odobreni zahtevi nisu učitani.");
          setRequests([]);
          return;
        }

        setRequests(data ?? []);
      } catch (error) {
        setErrorMessage(
          error instanceof Error
            ?error.message
            : "Došlo je do greške pri učitavanju zahteva."
        );
      } finally {
        setIsLoading(false);
      }
    }

    loadApprovedRequests();
  }, []);

  const visibleRequests = useMemo(() => {
    const normalizedQuery = query.trim().toLocaleLowerCase("sr-Latn");
    if (!normalizedQuery) return requests;
    return requests.filter((request) =>
      [
        request.societyName,
        request.city,
        request.PIB,
        request.registrationNumber
      ]
        .join(" ")
        .toLocaleLowerCase("sr-Latn")
        .includes(normalizedQuery)
    );
  }, [query, requests]);

  async function resendActivation(request: ApprovedRegistration) {
    setSendingRequestId(request.id);
    setActionMessage("");
    const callbackUrl = new URL("/auth/callback", window.location.origin);
    callbackUrl.searchParams.set("next", "/auth/activate-president");

    const { error } = await getSupabaseClient().auth.signInWithOtp({
      email: request.presidentEmail,
      options: {
        emailRedirectTo: callbackUrl.toString(),
        shouldCreateUser: true
      }
    });

    setActionMessage(
      error
        ? `Link nije poslat: ${error.message}`
        : `Novi aktivacioni link je poslat na ${request.presidentEmail}.`
    );
    setSendingRequestId("");
  }

  return (
    <>
      <section className="page-heading master-heading">
        <div>
          <p className="eyebrow">Odobreni zahtevi</p>
          <h1>Odobrene registracije</h1>
          <p>Kompaktan pregled društava čija je registracija odobrena.</p>
        </div>
        <div className="master-result-count">
          <strong>{visibleRequests.length}</strong>
          <span>od {requests.length} odobrenih</span>
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

      {actionMessage && (
        <section className="auth-message success" role="status">
          {actionMessage}
        </section>
      )}

      {!isLoading && !errorMessage && requests.length === 0 && (
        <section className="card dashboard-card">
          <p>Nema odobrenih zahteva.</p>
        </section>
      )}

      {!isLoading && !errorMessage && requests.length > 0 && visibleRequests.length === 0 && (
        <section className="card dashboard-card">
          <p>Nema odobrenih registracija za unetu pretragu.</p>
        </section>
      )}

      {!isLoading && !errorMessage && visibleRequests.length > 0 && (
        <section className="card master-society-table-wrap" aria-label="Odobreni zahtevi">
          <table className="master-society-table approved-request-table">
            <thead>
              <tr>
                <th>Društvo</th>
                <th>PIB</th>
                <th>Matični broj</th>
                <th>Odobreno</th>
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
                  <td>{formatDate(request.approvedAt)}</td>
                  <td><span className="master-status active">ODOBRENO</span></td>
                  <td>
                    <div className="approved-request-actions">
                      {!request.presidentUserId ? (
                        <button
                          className="button button-primary"
                          disabled={sendingRequestId === request.id}
                          onClick={() => resendActivation(request)}
                          type="button"
                        >
                          {sendingRequestId === request.id
                            ? "SLANJE..."
                            : "POŠALJI LINK"}
                        </button>
                      ) : null}
                      <Link
                        className="button button-secondary"
                        href={`/zahtevi-na-cekanju/${request.id}`}
                      >
                        DETALJI
                      </Link>
                    </div>
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
