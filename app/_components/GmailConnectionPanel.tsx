"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { getSupabaseClient } from "../_lib/supabaseClient";

type ConnectionStatus = {
  connected: boolean;
  email?: string;
  connected_at?: string;
};

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : "Akcija nije uspela.";
}

function displayDate(value?: string) {
  if (!value) return "";
  return new Intl.DateTimeFormat("sr-Latn-RS", {
    dateStyle: "long",
    timeStyle: "short"
  }).format(new Date(value));
}

export default function GmailConnectionPanel({ societyId }: { societyId: string }) {
  const [status, setStatus] = useState<ConnectionStatus | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isWorking, setIsWorking] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [confirmDisconnect, setConfirmDisconnect] = useState(false);
  const callbackHandled = useRef(false);

  const loadStatus = useCallback(async () => {
    setIsLoading(true);
    setError("");
    const { data, error: loadError } = await (getSupabaseClient().rpc as any)(
      "auth_get_society_gmail_connection",
      { p_society_id: societyId }
    );
    if (loadError) setError(loadError.message);
    else setStatus(data as ConnectionStatus);
    setIsLoading(false);
  }, [societyId]);

  const authenticatedRequest = useCallback(async (path: string, body: Record<string, string>) => {
    const { data } = await getSupabaseClient().auth.getSession();
    const accessToken = data.session?.access_token;
    if (!accessToken) throw new Error("Prijava je istekla. Prijavite se ponovo.");
    const response = await fetch(path, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify(body)
    });
    const result = await response.json();
    if (!response.ok) throw new Error(result.error || "Akcija nije uspela.");
    return result;
  }, []);

  useEffect(() => {
    void loadStatus();
  }, [loadStatus]);

  useEffect(() => {
    if (callbackHandled.current) return;
    const params = new URLSearchParams(window.location.search);
    const gmailResult = params.get("gmail");
    if (!gmailResult) return;
    callbackHandled.current = true;
    const cleanUrl = `${window.location.pathname}${window.location.hash}`;
    if (gmailResult === "error") {
      setError(params.get("message") || "Google nije odobrio povezivanje.");
      window.history.replaceState({}, "", cleanUrl);
      return;
    }
    const code = params.get("code");
    const state = params.get("state");
    if (gmailResult !== "callback" || !code || !state) {
      setError("Google potvrda nije potpuna. Pokrenite povezivanje ponovo.");
      window.history.replaceState({}, "", cleanUrl);
      return;
    }
    setIsWorking(true);
    setError("");
    void authenticatedRequest("/api/gmail/complete", { societyId, code, state })
      .then(async (result) => {
        setMessage(result.replaced
          ? `Gmail nalog je zamenjen nalogom ${result.email}. Prethodna dozvola je uklonjena.`
          : `Gmail nalog ${result.email} je uspešno povezan.`);
        await loadStatus();
      })
      .catch((completeError) => setError(errorMessage(completeError)))
      .finally(() => {
        setIsWorking(false);
        window.history.replaceState({}, "", cleanUrl);
      });
  }, [authenticatedRequest, loadStatus, societyId]);

  async function connect() {
    setIsWorking(true);
    setError("");
    setMessage("");
    try {
      const result = await authenticatedRequest("/api/gmail/connect", { societyId });
      window.location.assign(result.url);
    } catch (connectError) {
      setError(errorMessage(connectError));
      setIsWorking(false);
    }
  }

  async function disconnect() {
    setIsWorking(true);
    setError("");
    setMessage("");
    try {
      const result = await authenticatedRequest("/api/gmail/disconnect", { societyId });
      setStatus({ connected: false });
      setConfirmDisconnect(false);
      setMessage(result.disconnected
        ? `Gmail nalog ${result.email} je odjavljen i njegova dozvola je uklonjena.`
        : "Gmail nalog više nije povezan.");
    } catch (disconnectError) {
      setError(errorMessage(disconnectError));
    } finally {
      setIsWorking(false);
    }
  }

  return (
    <div className="gmail-connection-panel">
      <header className="gmail-panel-heading">
        <div>
          <h2>Gmail povezivanje</h2>
          <p>Povezani nalog koristi se za slanje obaveštenja članovima u ime društva.</p>
        </div>
        {status?.connected && <span className="gmail-status gmail-status-connected">Povezano</span>}
        {!isLoading && !status?.connected && <span className="gmail-status">Nije povezano</span>}
      </header>

      <div className="gmail-security-note">
        <strong>Jedan Gmail nalog po društvu</strong>
        <p>Samo predsednik može da poveže, zameni ili odjavi nalog. Aplikacija dobija dozvolu samo za slanje emailova i ne čuva Google lozinku.</p>
      </div>

      {error && <p className="alert alert-error">{error}</p>}
      {message && <p className="alert alert-success">{message}</p>}
      {(isLoading || isWorking && !status) && <p className="program-empty-row">Provera Gmail povezivanja...</p>}

      {!isLoading && status?.connected && (
        <section className="gmail-account-card">
          <div>
            <span>Povezani nalog</span>
            <strong>{status.email}</strong>
            <small>Povezano: {displayDate(status.connected_at)}</small>
          </div>
          <div className="gmail-account-actions">
            <button className="button button-secondary" disabled={isWorking} onClick={() => void connect()} type="button">
              {isWorking ? "SAČEKAJTE..." : "POVEŽI DRUGI GMAIL"}
            </button>
            {!confirmDisconnect && (
              <button className="button button-secondary danger-action" disabled={isWorking}
                onClick={() => setConfirmDisconnect(true)} type="button">
                ODJAVI GMAIL
              </button>
            )}
          </div>
        </section>
      )}

      {!isLoading && !status?.connected && (
        <div className="gmail-empty-state">
          <div>
            <h3>Nalog još nije povezan</h3>
            <p>Predsednik će na Google stranici izabrati Gmail nalog i potvrditi dozvolu za slanje obaveštenja.</p>
          </div>
          <button className="button button-primary" disabled={isWorking} onClick={() => void connect()} type="button">
            {isWorking ? "POVEZIVANJE..." : "POVEŽI GMAIL"}
          </button>
        </div>
      )}

      {status?.connected && confirmDisconnect && (
        <div className="gmail-confirm-disconnect">
          <p>Odjaviti <strong>{status.email}</strong>? Slanje obaveštenja neće raditi dok predsednik ne poveže drugi nalog.</p>
          <div className="header-actions">
            <button className="button button-secondary" disabled={isWorking}
              onClick={() => setConfirmDisconnect(false)} type="button">ODUSTANI</button>
            <button className="button button-primary" disabled={isWorking}
              onClick={() => void disconnect()} type="button">
              {isWorking ? "ODJAVLJIVANJE..." : "DA, ODJAVI NALOG"}
            </button>
          </div>
        </div>
      )}

      {status?.connected && (
        <p className="gmail-replacement-note">
          Ako povežete drugi Gmail, novo povezivanje će prvo biti potvrđeno, a zatim će prethodni nalog automatski biti uklonjen.
        </p>
      )}
    </div>
  );
}
