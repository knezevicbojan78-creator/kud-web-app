"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import {
  getSupabaseClient,
  type MasterLicensePrice,
  type PresidentRegistration
} from "../../../_lib/supabaseClient";

type RegistrationDetail = PresidentRegistration;

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function formatDate(value: string | null) {
  if (!value) {
    return "Nije postavljeno";
  }

  return new Intl.DateTimeFormat("sr-RS", {
    dateStyle: "medium",
    timeStyle: "short"
  }).format(new Date(value));
}

function formatValue(value: string | number | null) {
  if (value === null || value === "") {
    return "Nije uneto";
  }

  return String(value);
}

function isPermissionError(message: string, code?: string) {
  return (
    code === "42501" ||
    message.toLowerCase().includes("row-level security") ||
    message.toLowerCase().includes("permission denied")
  );
}

export default function ZahtevDetaljiPage() {
  const params = useParams();
  const id = typeof params.id === "string" ?params.id : "";
  const router = useRouter();
  const [request, setRequest] = useState<RegistrationDetail | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState("");
  const [actionMessage, setActionMessage] = useState("");
  const [isSubmittingAction, setIsSubmittingAction] = useState(false);
  const [licensePlans, setLicensePlans] = useState<MasterLicensePrice[]>([]);
  const [selectedPlanId, setSelectedPlanId] = useState("");
  const [licenseKind, setLicenseKind] = useState<
    "MONTHLY" | "ANNUAL" | "PROMOTIONAL_3" | "PROMOTIONAL_6" | "PROMOTIONAL_12"
  >("ANNUAL");
  const [paidOn, setPaidOn] = useState(new Date().toISOString().slice(0, 10));
  const [paymentMethod, setPaymentMethod] = useState<
    "BANK_TRANSFER" | "CASH" | "OTHER"
  >("BANK_TRANSFER");
  const [paymentReference, setPaymentReference] = useState("");
  const [licenseReason, setLicenseReason] = useState("");

  useEffect(() => {
    async function loadRequest() {
      setIsLoading(true);
      setErrorMessage("");

      if (!uuidPattern.test(id)) {
        setErrorMessage("Neispravan ID zahteva.");
        setRequest(null);
        setIsLoading(false);
        return;
      }

      try {
        const supabase = getSupabaseClient();
        const { data, error } = await supabase.rpc(
          "master_admin_get_president_requests",
          { p_request_id: id }
        );

        if (error) {
          setErrorMessage(
            "Zahtev nije učitan. Proverite Supabase RLS policy za Master admin čitanje."
          );
          setRequest(null);
          return;
        }

        const loadedRequest = data?.[0] ?? null;
        if (!loadedRequest) {
          setErrorMessage("Zahtev nije pronađen.");
          setRequest(null);
          return;
        }

        setRequest(loadedRequest);
        setSelectedPlanId(loadedRequest.requestedLicensePlanId ?? "");
        if (
          loadedRequest.requestedLicenseKind === "MONTHLY" ||
          loadedRequest.requestedLicenseKind === "ANNUAL"
        ) {
          setLicenseKind(loadedRequest.requestedLicenseKind);
        }
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

    loadRequest();
  }, [id]);

  useEffect(() => {
    async function loadLicensePlans() {
      const { data, error } = await getSupabaseClient().rpc(
        "master_admin_get_license_prices"
      );
      if (error) {
        setActionMessage("Licencni paketi nisu učitani.");
      } else {
        setLicensePlans(data ?? []);
      }
    }
    void loadLicensePlans();
  }, []);

  async function handleSecureApprove() {
    if (!request || !selectedPlanId) {
      setActionMessage("Izaberite licencni paket.");
      return;
    }

    const promotional = licenseKind.startsWith("PROMOTIONAL");
    if (promotional && !licenseReason.trim()) {
      setActionMessage("Razlog promotivne licence je obavezan.");
      return;
    }

    setIsSubmittingAction(true);
    setActionMessage("");

    const supabase = getSupabaseClient();
    const { data, error } = await supabase.rpc(
      "master_admin_approve_president_request",
      {
        p_request_id: request.id,
        p_license_plan_id: selectedPlanId,
        p_license_kind: licenseKind,
        p_paid_on: promotional ? null : paidOn,
        p_payment_method: promotional ? null : paymentMethod,
        p_payment_reference: promotional ? null : paymentReference || null,
        p_reason: promotional ? licenseReason.trim() : null
      }
    );

    if (error || !data) {
      setActionMessage(error?.message || "Zahtev nije odobren.");
      setIsSubmittingAction(false);
      return;
    }

    const callbackUrl = new URL("/auth/callback", window.location.origin);
    callbackUrl.searchParams.set("next", "/auth/activate-president");
    const { error: inviteError } = await supabase.auth.signInWithOtp({
      email: data.president_email,
      options: {
        emailRedirectTo: callbackUrl.toString(),
        shouldCreateUser: true
      }
    });

    if (inviteError) {
      setActionMessage(
        `Zahtev je odobren, ali aktivacioni email nije poslat: ${inviteError.message}`
      );
      setIsSubmittingAction(false);
      return;
    }

    router.push("/odobreni-zahtevi");
  }

  async function updateRequestStatus(status: "REJECTED") {
    if (!uuidPattern.test(id)) {
      setActionMessage("Neispravan ID zahteva.");
      return;
    }

    setActionMessage("");
    setIsSubmittingAction(true);

    try {
      const supabase = getSupabaseClient();
      const { error } = await supabase.rpc(
        "master_admin_reject_president_request",
        {
          p_request_id: id,
          p_reason: null
        }
      );

      if (error) {
        setActionMessage(
          isPermissionError(error.message, error.code)
            ?"UPDATE je blokiran Supabase RLS policy pravilom."
            : "Zahtev nije ažuriran. Proverite Supabase podešavanja i pokušajte ponovo."
        );
        return;
      }

      router.push("/zahtevi-na-cekanju");
    } catch (error) {
      setActionMessage(
        error instanceof Error
          ?error.message
          : "Došlo je do greške pri ažuriranju zahteva."
      );
    } finally {
      setIsSubmittingAction(false);
    }
  }

  return (
    <>
      <section className="page-heading">
        <p className="eyebrow">Detalj zahteva</p>
        <h1>{request?.societyName ?? "Zahtev za registraciju"}</h1>
        <p>Pregled podataka iz zahteva za registraciju društva.</p>
      </section>

      <Link className="button button-secondary" href="/zahtevi-na-cekanju">
        Nazad na zahteve
      </Link>

      {isLoading && (
        <section
          className="card dashboard-card"
          style={{ marginTop: "var(--space-4)" }}
        >
          <p>Učitavanje zahteva...</p>
        </section>
      )}

      {errorMessage && (
        <section
          className="card dashboard-card"
          role="alert"
          style={{ marginTop: "var(--space-4)" }}
        >
          <p>{errorMessage}</p>
        </section>
      )}

      {actionMessage && (
        <section
          className="card dashboard-card"
          role="alert"
          style={{ marginTop: "var(--space-4)" }}
        >
          <p>{actionMessage}</p>
        </section>
      )}

      {!isLoading && !errorMessage && request && (
        <section
          className="request-detail-layout"
          style={{ marginTop: "var(--space-4)" }}
          aria-label="Detalji zahteva"
        >
          <article className="card request-detail-card">
            <section className="request-detail-group">
              <p className="eyebrow">Društvo</p>
              <h2>{request.societyName}</h2>
              <dl className="request-facts">
                <div><dt>Adresa</dt><dd>{request.address}, {request.city}</dd></div>
                <div><dt>Država</dt><dd>{request.country}</dd></div>
                <div><dt>PIB</dt><dd>{request.PIB}</dd></div>
                <div><dt>Matični broj</dt><dd>{request.registrationNumber}</dd></div>
              </dl>
            </section>

            <section className="request-detail-group">
              <p className="eyebrow">Predsednik</p>
              <h2>{request.presidentFirstName} {request.presidentLastName}</h2>
              <dl className="request-facts">
                <div><dt>Email</dt><dd>{request.presidentEmail}</dd></div>
                <div><dt>Telefon</dt><dd>{request.presidentPhone}</dd></div>
              </dl>
            </section>

            <section className="request-detail-group">
              <p className="eyebrow">Zahtev</p>
              <h2>{formatValue(request.licenseType)}</h2>
              <dl className="request-facts">
                <div>
                  <dt>Status</dt>
                  <dd><span className="status-badge pending">Na čekanju</span></dd>
                </div>
                <div><dt>Poslato</dt><dd>{formatDate(request.createdAt)}</dd></div>
                <div>
                  <dt>
                    {request.requestedLicenseKind === "ANNUAL"
                      ? "Godišnja cena"
                      : "Mesečna cena"}
                  </dt>
                  <dd>{request.licensePrice !== null ? `${request.licensePrice} EUR` : "Nije navedena"}</dd>
                </div>
                <div>
                  <dt>Traženi period</dt>
                  <dd>
                    {request.requestedLicenseKind === "ANNUAL"
                      ? "Godišnja licenca"
                      : request.requestedLicenseKind === "MONTHLY"
                        ? "Mesečna licenca"
                        : "Nije navedeno"}
                  </dd>
                </div>
              </dl>
            </section>
          </article>

          {request.StatReg === "PENDING" && (
            <article className="card request-approval-card">
              <header>
                <p className="eyebrow">Odluka Master admina</p>
                <strong>Potvrdite paket i uslove licence pre odobravanja.</strong>
              </header>

              <div className="request-approval-grid">
                <label className="form-field">
                  <span>Licencni paket</span>
                  <select
                    className="input"
                    onChange={(event) => setSelectedPlanId(event.target.value)}
                    value={selectedPlanId}
                  >
                    <option value="">Izaberite paket</option>
                    {licensePlans.map((plan) => (
                      <option key={plan.id} value={plan.id}>
                        {plan.name}
                      </option>
                    ))}
                  </select>
                </label>

                <label className="form-field">
                  <span>Period licence</span>
                  <select
                    className="input"
                    onChange={(event) =>
                      setLicenseKind(event.target.value as typeof licenseKind)
                    }
                    value={licenseKind}
                  >
                    <option value="MONTHLY">Mesečna</option>
                    <option value="ANNUAL">Godišnja</option>
                    <option value="PROMOTIONAL_3">Promotivna — 3 meseca</option>
                    <option value="PROMOTIONAL_6">Promotivna — 6 meseci</option>
                    <option value="PROMOTIONAL_12">Promotivna — 12 meseci</option>
                  </select>
                </label>

                {licenseKind.startsWith("PROMOTIONAL") ? (
                  <label className="form-field request-approval-wide">
                    <span>Razlog promotivne licence</span>
                    <input
                      className="input"
                      onChange={(event) => setLicenseReason(event.target.value)}
                      value={licenseReason}
                    />
                  </label>
                ) : (
                  <>
                    <label className="form-field">
                      <span>Datum uplate</span>
                      <input
                        className="input"
                        max={new Date().toISOString().slice(0, 10)}
                        onChange={(event) => setPaidOn(event.target.value)}
                        type="date"
                        value={paidOn}
                      />
                    </label>
                    <label className="form-field">
                      <span>Način uplate</span>
                      <select
                        className="input"
                        onChange={(event) =>
                          setPaymentMethod(event.target.value as typeof paymentMethod)
                        }
                        value={paymentMethod}
                      >
                        <option value="BANK_TRANSFER">Prenos na račun</option>
                        <option value="CASH">Gotovina</option>
                        <option value="OTHER">Drugo</option>
                      </select>
                    </label>
                    <label className="form-field request-approval-wide">
                      <span>Referenca uplate — opciono</span>
                      <input
                        className="input"
                        onChange={(event) => setPaymentReference(event.target.value)}
                        value={paymentReference}
                      />
                    </label>
                  </>
                )}
              </div>

              <p className="auth-secondary-note">
                Licenca će biti dodeljena sada, ali njen period počinje tek
                nakon završenog onboardinga predsednika.
              </p>

              <div className="header-actions request-approval-actions">
                <button
                  className="button button-primary"
                  disabled={isSubmittingAction || !selectedPlanId}
                  onClick={handleSecureApprove}
                  type="button"
                >
                  {isSubmittingAction ? "ODOBRAVANJE..." : "ODOBRI I POŠALJI LINK"}
                </button>
                <button
                  className="button button-secondary"
                  disabled={isSubmittingAction}
                  onClick={() => void updateRequestStatus("REJECTED")}
                  type="button"
                >
                  ODBIJ
                </button>
              </div>
            </article>
          )}
        </section>
      )}
    </>
  );
}
