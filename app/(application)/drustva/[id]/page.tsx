"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import type { FormEvent } from "react";
import { useCallback, useEffect, useMemo, useState } from "react";
import {
  SocietyDataForm,
  type SocietyDataField,
  type SocietyDataFormValues
} from "../../../_components/SocietyDataForm";
import {
  getSupabaseClient,
  type MasterLicenseManagement,
  type MasterSocietyDetail,
  type Society
} from "../../../_lib/supabaseClient";

type SocietyErrors = Partial<Record<SocietyDataField, string>>;
type DetailTab = "overview" | "data" | "license" | "president" | "requests" | "history";
type LicenseKind = "MONTHLY" | "ANNUAL" | "PROMOTIONAL_3" | "PROMOTIONAL_6" | "PROMOTIONAL_12";

const tabs: Array<{ value: DetailTab; label: string }> = [
  { value: "overview", label: "Pregled" },
  { value: "data", label: "Podaci društva" },
  { value: "license", label: "Licenca" },
  { value: "president", label: "Predsednik" },
  { value: "requests", label: "Zahtevi" },
  { value: "history", label: "Istorija" }
];

const emptyValues: SocietyDataFormValues = {
  societyName: "", address: "", city: "", postalCode: "", country: "Srbija",
  pib: "", registrationNumber: "", bankAccount: "", licenseType: "Free"
};

function toFormValues(society: Society): SocietyDataFormValues {
  return {
    societyName: society.name,
    address: society.address,
    city: society.city,
    postalCode: society.postal_code ?? "",
    country: society.country,
    pib: society.pib,
    registrationNumber: society.registration_number,
    bankAccount: society.bank_account ?? "",
    licenseType: society.license_type ?? "Free"
  };
}

function validateSociety(values: SocietyDataFormValues) {
  const errors: SocietyErrors = {};
  const requiredFields: SocietyDataField[] = [
    "societyName", "address", "city", "country", "pib", "registrationNumber"
  ];
  requiredFields.forEach((field) => {
    if (!values[field].trim()) errors[field] = "Ovo polje je obavezno.";
  });
  return errors;
}

function formatDate(value: string | null | undefined) {
  if (!value) return "Nije dostupno";
  return new Intl.DateTimeFormat("sr-Latn-RS", { dateStyle: "medium" }).format(new Date(`${value.slice(0, 10)}T00:00:00`));
}

function formatDateTime(value: string | null | undefined) {
  if (!value) return "Nije dostupno";
  return new Intl.DateTimeFormat("sr-Latn-RS", {
    dateStyle: "medium", timeStyle: "short"
  }).format(new Date(value));
}

function societyStatusLabel(status: Society["status"]) {
  if (status === "ACTIVE") return "AKTIVNO";
  if (status === "ONBOARDING") return "ČEKA ONBOARDING";
  return "SUSPENDOVANO";
}

function auditLabel(action: string) {
  return {
    SOCIETY_SUSPENDED: "Društvo suspendovano",
    SOCIETY_REACTIVATED: "Društvo ponovo aktivirano",
    SOCIETY_UPDATED: "Podaci društva izmenjeni",
    LICENSE_GRANTED: "Licenca dodeljena",
    LICENSE_PAYMENT_RECORDED: "Uplata licence evidentirana"
  }[action] ?? action;
}

export default function DrustvoDetaljiPage() {
  const params = useParams();
  const id = typeof params.id === "string" ? params.id : "";
  const [activeTab, setActiveTab] = useState<DetailTab>("overview");
  const [detail, setDetail] = useState<MasterSocietyDetail | null>(null);
  const [values, setValues] = useState<SocietyDataFormValues>(emptyValues);
  const [errors, setErrors] = useState<SocietyErrors>({});
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [errorMessage, setErrorMessage] = useState("");
  const [message, setMessage] = useState("");
  const [statusActionOpen, setStatusActionOpen] = useState(false);
  const [statusReason, setStatusReason] = useState("");
  const [licenseManagement, setLicenseManagement] = useState<MasterLicenseManagement | null>(null);
  const [licenseFormOpen, setLicenseFormOpen] = useState(false);
  const [licensePlanId, setLicensePlanId] = useState("");
  const [licenseKind, setLicenseKind] = useState<LicenseKind>("PROMOTIONAL_3");
  const [licenseStart, setLicenseStart] = useState(new Date().toISOString().slice(0, 10));
  const [licensePaidOn, setLicensePaidOn] = useState(new Date().toISOString().slice(0, 10));
  const [licensePaymentMethod, setLicensePaymentMethod] = useState<"BANK_TRANSFER" | "CASH" | "OTHER">("BANK_TRANSFER");
  const [licensePaymentReference, setLicensePaymentReference] = useState("");
  const [licenseReason, setLicenseReason] = useState("");
  const [licenseNote, setLicenseNote] = useState("");
  const [allowRepeatPromotion, setAllowRepeatPromotion] = useState(false);
  const [pendingTab, setPendingTab] = useState<DetailTab | null>(null);

  const savedSocietyValues = useMemo(
    () => detail ? toFormValues(detail.society) : emptyValues,
    [detail]
  );
  const hasUnsavedSocietyChanges = useMemo(
    () => (Object.keys(values) as SocietyDataField[]).some(
      (field) => values[field] !== savedSocietyValues[field]
    ),
    [savedSocietyValues, values]
  );

  const loadSociety = useCallback(async () => {
    if (!id) {
      setErrorMessage("Nedostaje ID društva.");
      setIsLoading(false);
      return;
    }
    setIsLoading(true);
    setErrorMessage("");
    const client = getSupabaseClient();
    const { data, error } = await client.rpc(
      "master_admin_get_society_detail",
      { p_society_id: id }
    );
    if (error) {
      setErrorMessage(
        "Detalj društva nije učitan. Primenite supabase/master-admin-v1-society-detail-workflows.sql."
      );
      setDetail(null);
    } else {
      setDetail(data);
      setValues(toFormValues(data.society));
      const { data: licenseData, error: licenseError } = await client.rpc(
        "master_admin_get_license_management",
        { p_society_id: id }
      );
      if (licenseError) {
        setErrorMessage("Licencni podaci nisu učitani.");
      } else {
        setLicenseManagement(licenseData);
        setLicensePlanId((current) => current || licenseData.plans[0]?.id || "");
      }
    }
    setIsLoading(false);
  }, [id]);

  useEffect(() => { void loadSociety(); }, [loadSociety]);
  useEffect(() => {
    function warnBeforeLeaving(event: BeforeUnloadEvent) {
      if (!hasUnsavedSocietyChanges) return;
      event.preventDefault();
      event.returnValue = "";
    }
    window.addEventListener("beforeunload", warnBeforeLeaving);
    return () => window.removeEventListener("beforeunload", warnBeforeLeaving);
  }, [hasUnsavedSocietyChanges]);

  function updateField(field: SocietyDataField, value: string) {
    setValues((current) => ({ ...current, [field]: value }));
    setErrors((current) => ({ ...current, [field]: undefined }));
    setErrorMessage("");
  }

  async function saveSociety() {
    const validationErrors = validateSociety(values);
    setErrors(validationErrors);
    if (Object.keys(validationErrors).length > 0) return false;

    setIsSaving(true);
    setErrorMessage("");
    setMessage("");
    const { error } = await getSupabaseClient().rpc(
      "master_admin_update_society",
      {
        p_society_id: id,
        p_values: {
          name: values.societyName,
          address: values.address,
          city: values.city,
          postal_code: values.postalCode || null,
          country: values.country,
          pib: values.pib,
          registration_number: values.registrationNumber,
          bank_account: values.bankAccount || null
        }
      }
    );
    if (error) {
      setErrorMessage("Društvo nije sačuvano.");
      setIsSaving(false);
      return false;
    } else {
      setMessage("Podaci društva su sačuvani.");
      await loadSociety();
    }
    setIsSaving(false);
    return true;
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await saveSociety();
  }

  function discardSocietyChanges(showMessage = true) {
    setValues(savedSocietyValues);
    setErrors({});
    setErrorMessage("");
    if (showMessage) setMessage("Nesačuvane izmene su odbačene.");
  }

  function requestTabChange(nextTab: DetailTab) {
    if (nextTab === activeTab) return;
    if (activeTab === "data" && hasUnsavedSocietyChanges) {
      setPendingTab(nextTab);
      return;
    }
    setActiveTab(nextTab);
  }

  async function saveAndContinue() {
    if (!pendingTab) return;
    const nextTab = pendingTab;
    const saved = await saveSociety();
    if (saved) {
      setPendingTab(null);
      setActiveTab(nextTab);
    }
  }

  function discardAndContinue() {
    if (!pendingTab) return;
    const nextTab = pendingTab;
    discardSocietyChanges(false);
    setPendingTab(null);
    setActiveTab(nextTab);
    setMessage("Nesačuvane izmene su odbačene.");
  }

  async function changeStatus() {
    if (!detail || !statusReason.trim()) return;
    const nextStatus = detail.society.status === "ACTIVE" ? "SUSPENDED" : "ACTIVE";
    setIsSaving(true);
    setErrorMessage("");
    setMessage("");
    const { error } = await getSupabaseClient().rpc("master_admin_set_society_status", {
      p_society_id: detail.society.id,
      p_new_status: nextStatus,
      p_reason: statusReason.trim()
    });
    if (error) {
      setErrorMessage(error.message || "Status društva nije promenjen.");
    } else {
      setMessage(nextStatus === "SUSPENDED" ? "Društvo je suspendovano." : "Društvo je ponovo aktivirano.");
      setStatusActionOpen(false);
      setStatusReason("");
      await loadSociety();
    }
    setIsSaving(false);
  }

  async function grantLicense() {
    if (!licensePlanId) {
      setErrorMessage("Izaberite licencni paket.");
      return;
    }
    const promotional = licenseKind.startsWith("PROMOTIONAL");
    if (promotional && !licenseReason.trim()) {
      setErrorMessage("Razlog promotivne licence je obavezan.");
      return;
    }
    setIsSaving(true);
    setErrorMessage("");
    setMessage("");
    const { error } = await getSupabaseClient().rpc("master_admin_grant_license", {
      p_society_id: id,
      p_license_plan_id: licensePlanId,
      p_license_kind: licenseKind,
      p_requested_start: licenseStart,
      p_paid_on: promotional ? null : licensePaidOn,
      p_payment_method: promotional ? null : licensePaymentMethod,
      p_payment_reference: promotional ? null : licensePaymentReference || null,
      p_reason: promotional ? licenseReason.trim() : null,
      p_internal_note: licenseNote.trim() || null,
      p_allow_repeat_promotion: allowRepeatPromotion
    });
    if (error) {
      setErrorMessage(error.message || "Licenca nije dodeljena.");
    } else {
      setMessage("Licenca je uspešno dodeljena.");
      setLicenseFormOpen(false);
      setLicenseReason("");
      setLicenseNote("");
      setLicensePaymentReference("");
      setAllowRepeatPromotion(false);
      await loadSociety();
    }
    setIsSaving(false);
  }

  if (isLoading) return <section className="card dashboard-card">Učitavanje društva...</section>;
  if (!detail) return <p className="alert alert-error">{errorMessage}</p>;

  const { society, counts, registration, current_license: license, active_suspension: suspension } = detail;
  const selectedLicensePlan = licenseManagement?.plans.find((plan) => plan.id === licensePlanId) ?? null;

  return (
    <>
      <section className="page-heading master-society-detail-heading">
        <div>
          <Link className="master-back-link" href="/drustva">← Sva društva</Link>
          <div className="master-detail-title-row">
            <div>
              <p className="eyebrow">Master admin · Društvo</p>
              <h1>{society.name}</h1>
              <p>{society.city} · PIB {society.pib}</p>
            </div>
            <span className={`master-status ${society.status.toLowerCase()}`}>
              {societyStatusLabel(society.status)}
            </span>
          </div>
        </div>
      </section>

      {errorMessage && <p className="alert alert-error">{errorMessage}</p>}
      {message && <p className="alert alert-success">{message}</p>}

      <nav className="card master-detail-tabs" aria-label="Detalj društva">
        {tabs.map((tab) => (
          <button
            className={activeTab === tab.value ? "active" : ""}
            key={tab.value}
            onClick={() => requestTabChange(tab.value)}
            type="button"
          >
            {tab.label}
          </button>
        ))}
      </nav>

      {activeTab === "overview" && (
        <section className="master-detail-content">
          <div className="master-detail-counts">
            <article className="card"><span>Aktivni članovi</span><strong>{counts.active_members}</strong><small>{counts.inactive_members} neaktivnih</small></article>
            <article className="card"><span>Aktivne sekcije</span><strong>{counts.active_sections}</strong><small>{counts.inactive_sections} neaktivnih</small></article>
            <article className="card"><span>Licenca</span><strong>{license?.plan_name ?? society.license_type ?? "Nije dodeljena"}</strong><small>{license ? `važi do ${formatDate(license.valid_until)}` : "nema aktivnog perioda"}</small></article>
            <article className="card"><span>Predsednik</span><strong>{registration?.president_name ?? "Nije povezan"}</strong><small>{registration?.president_email ?? "nema podataka"}</small></article>
          </div>

          <div className="master-detail-columns">
            <article className="card master-detail-panel">
              <header><div><p className="eyebrow">Administracija</p><h2>Status društva</h2></div></header>
              <dl className="master-detail-facts">
                <div><dt>Trenutni status</dt><dd>{societyStatusLabel(society.status)}</dd></div>
                <div><dt>Licenca</dt><dd>{license?.plan_name ?? society.license_type ?? "Nije dodeljena"}</dd></div>
                <div><dt>Matični broj</dt><dd>{society.registration_number}</dd></div>
                {suspension && <div><dt>Razlog suspenzije</dt><dd>{suspension.reason}</dd></div>}
                {suspension && <div><dt>Početak suspenzije</dt><dd>{formatDateTime(suspension.suspended_at)}</dd></div>}
              </dl>

              {society.status === "ONBOARDING" && (
                <p className="auth-secondary-note">
                  Društvo će postati aktivno tek kada predsednik završi onboarding.
                </p>
              )}

              {society.status !== "ONBOARDING" && !statusActionOpen && (
                <button
                  className={`button ${society.status === "ACTIVE" ? "button-secondary danger-action" : "button-primary"}`}
                  onClick={() => setStatusActionOpen(true)}
                  type="button"
                >
                  {society.status === "ACTIVE" ? "SUSPENDUJ DRUŠTVO" : "PONOVO AKTIVIRAJ"}
                </button>
              )}

              {society.status !== "ONBOARDING" && statusActionOpen && (
                <div className="master-status-action">
                  <label className="form-field">
                    <span>{society.status === "ACTIVE" ? "Razlog suspenzije" : "Razlog reaktivacije"} *</span>
                    <textarea className="input" onChange={(event) => setStatusReason(event.target.value)} rows={3} value={statusReason} />
                  </label>
                  <div>
                    <button className="button button-secondary" disabled={isSaving} onClick={() => { setStatusActionOpen(false); setStatusReason(""); }} type="button">OTKAŽI</button>
                    <button className={`button ${society.status === "ACTIVE" ? "danger-action" : "button-primary"}`} disabled={isSaving || !statusReason.trim()} onClick={() => void changeStatus()} type="button">
                      {society.status === "ACTIVE" ? "POTVRDI SUSPENZIJU" : "POTVRDI AKTIVACIJU"}
                    </button>
                  </div>
                </div>
              )}
            </article>

            <article className="card master-detail-panel">
              <header><div><p className="eyebrow">Osnovni podaci</p><h2>{society.name}</h2></div><button className="button button-secondary" onClick={() => setActiveTab("data")} type="button">IZMENI</button></header>
              <dl className="master-detail-facts">
                <div><dt>Adresa</dt><dd>{society.address}, {society.city}</dd></div>
                <div><dt>Država</dt><dd>{society.country}</dd></div>
                <div><dt>PIB</dt><dd>{society.pib}</dd></div>
                <div><dt>Matični broj</dt><dd>{society.registration_number}</dd></div>
                <div><dt>Žiro račun</dt><dd>{society.bank_account ?? "Nije unet"}</dd></div>
              </dl>
            </article>
          </div>
        </section>
      )}

      {activeTab === "data" && (
        <form className="card master-detail-form" noValidate onSubmit={handleSubmit}>
          <SocietyDataForm errors={errors} mode="master" onFieldChange={updateField} values={values} />
          <div className="master-form-actions">
            <span className="master-form-state">{hasUnsavedSocietyChanges ? "Imate nesačuvane izmene." : "Nema nesačuvanih izmena."}</span>
            <button className="button button-secondary" disabled={isSaving || !hasUnsavedSocietyChanges} onClick={() => discardSocietyChanges()} type="button">ODBACI IZMENE</button>
            <button className="button button-primary" disabled={isSaving || !hasUnsavedSocietyChanges} type="submit">SAČUVAJ</button>
          </div>
        </form>
      )}

      {activeTab === "license" && (
        <section className="master-license-layout">
          <article className="card master-detail-panel">
            <header>
              <div><p className="eyebrow">Licenca</p><h2>Trenutni period</h2></div>
              {!licenseFormOpen && <button className="button button-primary" onClick={() => setLicenseFormOpen(true)} type="button">DODELI / PRODUŽI</button>}
            </header>
            {license ? (
              <dl className="master-detail-facts">
                <div><dt>Paket</dt><dd>{license.plan_name}</dd></div>
                <div><dt>Izvor</dt><dd>{license.source === "PROMOTIONAL" ? "Promotivna" : "Plaćena"}</dd></div>
                <div><dt>Period</dt><dd>{formatDate(license.valid_from)} – {formatDate(license.valid_until)}</dd></div>
                <div><dt>Trajanje</dt><dd>{license.duration_months} meseci</dd></div>
                <div><dt>Limit članova</dt><dd>{license.member_limit ?? "Bez definisanog limita"}</dd></div>
                <div><dt>Limit sekcija</dt><dd>{license.section_limit ?? "Bez definisanog limita"}</dd></div>
              </dl>
            ) : <div className="master-empty">Licencni period još nije dodeljen.</div>}
          </article>

          {licenseFormOpen && licenseManagement && (
            <article className="card master-detail-panel master-license-form">
              <header><div><p className="eyebrow">Nova licenca</p><h2>Dodela ili produženje</h2></div></header>
              <div className="master-license-form-grid">
                <label className="form-field">
                  <span>Paket *</span>
                  <select className="input" onChange={(event) => setLicensePlanId(event.target.value)} value={licensePlanId}>
                    {licenseManagement.plans.map((plan) => <option key={plan.id} value={plan.id}>{plan.name} · do {plan.active_member_limit} članova / {plan.active_section_limit} sekcija</option>)}
                  </select>
                </label>
                <label className="form-field">
                  <span>Željeni početak *</span>
                  <input className="input" onChange={(event) => setLicenseStart(event.target.value)} type="date" value={licenseStart} />
                </label>
                <div className="master-license-kind-field">
                  <span>Vrsta licence *</span>
                  <div className="master-license-kind-options">
                    <button className={licenseKind === "MONTHLY" ? "active" : ""} onClick={() => setLicenseKind("MONTHLY")} type="button">
                      <span>Mesečna</span>
                      <strong>{selectedLicensePlan?.monthly_price ?? "—"} {selectedLicensePlan?.currency ?? "EUR"}</strong>
                      <small>1 mesec</small>
                    </button>
                    <button className={licenseKind === "ANNUAL" ? "active" : ""} onClick={() => setLicenseKind("ANNUAL")} type="button">
                      <span>Godišnja</span>
                      <strong>{selectedLicensePlan?.annual_price ?? "—"} {selectedLicensePlan?.currency ?? "EUR"}</strong>
                      <small>12 meseci</small>
                    </button>
                    <button className={licenseKind.startsWith("PROMOTIONAL") ? "active" : ""} onClick={() => setLicenseKind("PROMOTIONAL_3")} type="button">
                      <span>Promotivna</span>
                      <strong>0 EUR</strong>
                      <small>3, 6 ili 12 meseci</small>
                    </button>
                  </div>
                </div>
                {licenseKind.startsWith("PROMOTIONAL") && (
                  <label className="form-field">
                    <span>Trajanje promocije *</span>
                    <select className="input" onChange={(event) => setLicenseKind(event.target.value as LicenseKind)} value={licenseKind}>
                      <option value="PROMOTIONAL_3">3 meseca</option>
                      <option value="PROMOTIONAL_6">6 meseci</option>
                      <option value="PROMOTIONAL_12">12 meseci</option>
                    </select>
                  </label>
                )}
                {!licenseKind.startsWith("PROMOTIONAL") && (
                  <>
                    <label className="form-field"><span>Datum uplate *</span><input className="input" onChange={(event) => setLicensePaidOn(event.target.value)} type="date" value={licensePaidOn} /></label>
                    <label className="form-field"><span>Način uplate *</span><select className="input" onChange={(event) => setLicensePaymentMethod(event.target.value as typeof licensePaymentMethod)} value={licensePaymentMethod}><option value="BANK_TRANSFER">Prenos na račun</option><option value="CASH">Gotovina</option><option value="OTHER">Drugo</option></select></label>
                    <label className="form-field"><span>Referenca uplate</span><input className="input" onChange={(event) => setLicensePaymentReference(event.target.value)} value={licensePaymentReference} /></label>
                  </>
                )}
                {licenseKind.startsWith("PROMOTIONAL") && (
                  <label className="form-field master-license-wide"><span>Razlog promocije *</span><input className="input" onChange={(event) => setLicenseReason(event.target.value)} value={licenseReason} /></label>
                )}
                <label className="form-field master-license-wide"><span>Interna napomena</span><input className="input" onChange={(event) => setLicenseNote(event.target.value)} value={licenseNote} /></label>
                {licenseKind.startsWith("PROMOTIONAL") && licenseManagement.promotion_used && (
                  <label className="master-license-repeat"><input checked={allowRepeatPromotion} onChange={(event) => setAllowRepeatPromotion(event.target.checked)} type="checkbox" /><span>Društvo je ranije koristilo promociju — potvrđujem novu promotivnu licencu.</span></label>
                )}
              </div>
              <div className="master-form-actions">
                <button className="button button-secondary" disabled={isSaving} onClick={() => setLicenseFormOpen(false)} type="button">OTKAŽI</button>
                <button className="button button-primary" disabled={isSaving || !licensePlanId || (licenseKind.startsWith("PROMOTIONAL") && (!licenseReason.trim() || (licenseManagement.promotion_used && !allowRepeatPromotion)))} onClick={() => void grantLicense()} type="button">POTVRDI LICENCU</button>
              </div>
            </article>
          )}

          <article className="card master-detail-panel master-license-history">
            <header><div><p className="eyebrow">Istorija</p><h2>Licencni periodi</h2></div></header>
            {!licenseManagement?.periods.length && <div className="master-empty">Još nema licencnih perioda.</div>}
            {licenseManagement?.periods.map((period) => (
              <div className="master-license-history-row" key={period.id}>
                <div><strong>{period.plan_name}</strong><span>{period.source === "PROMOTIONAL" ? "Promotivna" : period.billing_cycle === "MONTHLY" ? "Mesečna" : "Godišnja"}</span></div>
                <div><strong>{formatDate(period.valid_from)} – {formatDate(period.valid_until)}</strong><span>{period.price_snapshot} {period.currency_snapshot} · bez poreza</span></div>
                <div><strong>{period.source === "PROMOTIONAL" ? period.promotion_reason : formatDate(period.paid_on)}</strong><span>{period.internal_note ?? "Bez interne napomene"}</span></div>
              </div>
            ))}
          </article>
        </section>
      )}

      {activeTab === "president" && (
        <section className="card master-detail-panel master-single-panel">
          <header><div><p className="eyebrow">Predsednik</p><h2>Administrativni kontakt</h2></div></header>
          {registration ? (
            <dl className="master-detail-facts">
              <div><dt>Ime i prezime</dt><dd>{registration.president_name}</dd></div>
              <div><dt>Email</dt><dd>{registration.president_email}</dd></div>
              <div><dt>Telefon</dt><dd>{registration.president_phone}</dd></div>
              <div><dt>Registracija odobrena</dt><dd>{formatDateTime(registration.approved_at)}</dd></div>
            </dl>
          ) : <div className="master-empty">Odobrena registracija nije povezana sa ovim društvom.</div>}
        </section>
      )}

      {activeTab === "requests" && (
        <section className="card master-detail-panel master-single-panel">
          <header><div><p className="eyebrow">Zahtevi</p><h2>Povezani zahtevi</h2></div></header>
          {registration ? (
            <div className="master-linked-request">
              <div><strong>Registracija društva</strong><span>Odobrena {formatDateTime(registration.approved_at)}</span></div>
              <Link className="button button-secondary" href={`/zahtevi-na-cekanju/${registration.id}`}>DETALJI</Link>
            </div>
          ) : <div className="master-empty">Nema povezanih zahteva.</div>}
        </section>
      )}

      {activeTab === "history" && (
        <section className="card master-detail-panel master-single-panel">
          <header><div><p className="eyebrow">Audit</p><h2>Istorija promena</h2></div></header>
          {!detail.recent_audit.length && <div className="master-empty">Još nema evidentiranih Master admin akcija za ovo društvo.</div>}
          <div className="master-detail-audit">
            {detail.recent_audit.map((entry) => (
              <article key={entry.id}>
                <div><strong>{auditLabel(entry.action)}</strong><span>{entry.reason ?? "Bez napomene"}</span></div>
                <time dateTime={entry.created_at}>{formatDateTime(entry.created_at)}</time>
              </article>
            ))}
          </div>
        </section>
      )}

      {pendingTab && (
        <div className="modal-backdrop" role="presentation">
          <section aria-labelledby="unsaved-society-title" aria-modal="true" className="card master-unsaved-dialog" role="dialog">
            <div>
              <p className="eyebrow">Nesačuvane izmene</p>
              <h2 id="unsaved-society-title">Da li želite da sačuvate izmene?</h2>
              <p>Promenili ste podatke društva. Izaberite šta želite da uradite pre prelaska na drugi tab.</p>
            </div>
            <div className="master-unsaved-actions">
              <button className="button button-secondary" disabled={isSaving} onClick={() => setPendingTab(null)} type="button">NASTAVI UREĐIVANJE</button>
              <button className="button button-secondary danger-text" disabled={isSaving} onClick={discardAndContinue} type="button">ODBACI I NASTAVI</button>
              <button className="button button-primary" disabled={isSaving} onClick={() => void saveAndContinue()} type="button">SAČUVAJ I NASTAVI</button>
            </div>
          </section>
        </div>
      )}
    </>
  );
}
