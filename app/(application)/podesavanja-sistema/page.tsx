"use client";

import { useCallback, useEffect, useState } from "react";
import {
  getSupabaseClient,
  type MasterLicensePrice
} from "../../_lib/supabaseClient";

type PriceDraft = {
  monthly: string;
  annual: string;
  reason: string;
};

function formatMoney(value: number, currency: string) {
  return new Intl.NumberFormat("sr-Latn-RS", {
    style: "currency",
    currency,
    minimumFractionDigits: value % 1 === 0 ? 0 : 2
  }).format(value);
}

export default function PodesavanjaSistemaPage() {
  const [plans, setPlans] = useState<MasterLicensePrice[]>([]);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [draft, setDraft] = useState<PriceDraft>({ monthly: "", annual: "", reason: "" });
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [message, setMessage] = useState("");
  const [errorMessage, setErrorMessage] = useState("");

  const loadPrices = useCallback(async () => {
    setIsLoading(true);
    setErrorMessage("");
    const { data, error } = await getSupabaseClient().rpc("master_admin_get_license_prices");
    if (error) {
      setPlans([]);
      setErrorMessage("Cene nisu učitane. Primenite supabase/master-admin-v1-license-price-workflows.sql.");
    } else {
      setPlans(data ?? []);
    }
    setIsLoading(false);
  }, []);

  useEffect(() => { void loadPrices(); }, [loadPrices]);

  function beginEdit(plan: MasterLicensePrice) {
    setEditingId(plan.id);
    setDraft({
      monthly: String(plan.monthly_price),
      annual: String(plan.annual_price),
      reason: ""
    });
    setMessage("");
    setErrorMessage("");
  }

  function cancelEdit() {
    setEditingId(null);
    setDraft({ monthly: "", annual: "", reason: "" });
  }

  async function savePrice(plan: MasterLicensePrice) {
    const monthly = Number(draft.monthly);
    const annual = Number(draft.annual);
    if (!Number.isFinite(monthly) || monthly <= 0 || !Number.isFinite(annual) || annual <= 0) {
      setErrorMessage("Mesečna i godišnja cena moraju biti veće od nule.");
      return;
    }
    if (!draft.reason.trim()) {
      setErrorMessage("Razlog promene cene je obavezan.");
      return;
    }

    setIsSaving(true);
    setMessage("");
    setErrorMessage("");
    const { error } = await getSupabaseClient().rpc("master_admin_update_license_price", {
      p_license_plan_id: plan.id,
      p_monthly_price: monthly,
      p_annual_price: annual,
      p_reason: draft.reason.trim()
    });
    if (error) {
      setErrorMessage(error.message || "Cena licence nije promenjena.");
    } else {
      setMessage(`Cene paketa „${plan.name}“ su sačuvane.`);
      cancelEdit();
      await loadPrices();
    }
    setIsSaving(false);
  }

  return (
    <>
      <section className="page-heading">
        <p className="eyebrow">Podešavanja sistema</p>
        <h1>Cene licenci</h1>
        <p>Globalni cenovnik za buduće mesečne i godišnje licence.</p>
      </section>

      {errorMessage && <p className="alert alert-error">{errorMessage}</p>}
      {message && <p className="alert alert-success">{message}</p>}

      <section className="card master-price-settings">
        <header>
          <div>
            <p className="eyebrow">Licencni paketi</p>
            <h2>Aktivne cene</h2>
            <p>Promena ne utiče na već dodeljene licencne periode.</p>
          </div>
          <span className="master-price-tax-note">CENE BEZ POREZA</span>
        </header>

        {isLoading && <div className="master-empty">Učitavanje cena...</div>}
        {!isLoading && !plans.length && !errorMessage && <div className="master-empty">Nema aktivnih licencnih paketa.</div>}

        <div className="master-price-list">
          {plans.map((plan) => {
            const isEditing = editingId === plan.id;
            return (
              <article key={plan.id}>
                <div className="master-price-plan">
                  <strong>{plan.name}</strong>
                  <span>do {plan.active_member_limit} članova · do {plan.active_section_limit} sekcija</span>
                </div>

                {isEditing ? (
                  <>
                    <label className="form-field">
                      <span>Mesečno ({plan.currency})</span>
                      <input className="input" min="0.01" onChange={(event) => setDraft((current) => ({ ...current, monthly: event.target.value }))} step="0.01" type="number" value={draft.monthly} />
                    </label>
                    <label className="form-field">
                      <span>Godišnje ({plan.currency})</span>
                      <input className="input" min="0.01" onChange={(event) => setDraft((current) => ({ ...current, annual: event.target.value }))} step="0.01" type="number" value={draft.annual} />
                    </label>
                    <label className="form-field master-price-reason">
                      <span>Razlog promene *</span>
                      <input className="input" onChange={(event) => setDraft((current) => ({ ...current, reason: event.target.value }))} value={draft.reason} />
                    </label>
                    <div className="master-price-actions">
                      <button className="button button-secondary" disabled={isSaving} onClick={cancelEdit} type="button">OTKAŽI</button>
                      <button className="button button-primary" disabled={isSaving || !draft.reason.trim()} onClick={() => void savePrice(plan)} type="button">SAČUVAJ</button>
                    </div>
                  </>
                ) : (
                  <>
                    <div className="master-price-value"><span>Mesečno</span><strong>{formatMoney(plan.monthly_price, plan.currency)}</strong></div>
                    <div className="master-price-value"><span>Godišnje</span><strong>{formatMoney(plan.annual_price, plan.currency)}</strong></div>
                    <button className="button button-secondary" disabled={editingId !== null} onClick={() => beginEdit(plan)} type="button">IZMENI</button>
                  </>
                )}
              </article>
            );
          })}
        </div>
      </section>
    </>
  );
}
