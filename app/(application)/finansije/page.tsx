"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  getSupabaseClient,
  type FinanceOpenObligation,
  type FinancePayment,
  type FinanceProfile,
  type FinanceRefund,
  type FinanceSearchEntity,
  type Society
} from "../../_lib/supabaseClient";

function errorMessage(error: unknown) {
  if (error instanceof Error) return error.message;
  if (typeof error === "object" && error && "message" in error) return String(error.message);
  return "Akcija nije uspela.";
}
function money(value: number, currency: string) {
  return new Intl.NumberFormat("sr-Latn-RS", {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2
  }).format(value) + ` ${currency}`;
}
function date(value: string) {
  return new Intl.DateTimeFormat("sr-Latn-RS").format(new Date(`${value}T00:00:00`));
}
function dateTime(value: string) {
  return new Intl.DateTimeFormat("sr-Latn-RS", {
    day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit"
  }).format(new Date(value));
}

export default function FinansijePage() {
  const [society, setSociety] = useState<Society | null>(null);
  const [actorMemberId, setActorMemberId] = useState<string | null>(null);
  const [canSearchSociety, setCanSearchSociety] = useState(false);
  const [canRecordPayment, setCanRecordPayment] = useState(false);
  const [canUseCredit, setCanUseCredit] = useState(false);
  const [canRecordRefund, setCanRecordRefund] = useState(false);
  const [canVoidPayment, setCanVoidPayment] = useState(false);
  const [canVoidRefund, setCanVoidRefund] = useState(false);
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<FinanceSearchEntity[]>([]);
  const [selected, setSelected] = useState<FinanceSearchEntity | null>(null);
  const [profile, setProfile] = useState<FinanceProfile | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isSearching, setIsSearching] = useState(false);
  const [isProfileLoading, setIsProfileLoading] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [isPaymentOpen, setIsPaymentOpen] = useState(false);
  const [selectedObligationIds, setSelectedObligationIds] = useState<string[]>([]);
  const [paymentAmount, setPaymentAmount] = useState("");
  const [paymentMethod, setPaymentMethod] = useState<"CASH" | "BANK_TRANSFER">("CASH");
  const [creditPersonId, setCreditPersonId] = useState("");
  const [creditAmount, setCreditAmount] = useState("");
  const [creditTargetPersonId, setCreditTargetPersonId] = useState("");
  const [isSaving, setIsSaving] = useState(false);
  const [voidPayment, setVoidPayment] = useState<FinanceProfile["payments"][number] | null>(null);
  const [voidPaymentReason, setVoidPaymentReason] = useState("");
  const [isRefundOpen, setIsRefundOpen] = useState(false);
  const [refundPersonId, setRefundPersonId] = useState("");
  const [refundCurrency, setRefundCurrency] = useState("");
  const [refundAmount, setRefundAmount] = useState("");
  const [refundMethod, setRefundMethod] = useState<"CASH" | "BANK_TRANSFER">("CASH");
  const [refundReason, setRefundReason] = useState("");
  const [voidRefund, setVoidRefund] = useState<FinanceRefund | null>(null);
  const [voidRefundReason, setVoidRefundReason] = useState("");

  const isManager = canSearchSociety;

  const loadProfile = useCallback(async (
    entityType: "PERSON" | "GUARDIAN",
    entityId: string,
    currentSociety: Society,
    currentActorMemberId: string | null
  ) => {
    setIsProfileLoading(true);
    setError("");
    try {
      const supabase = getSupabaseClient();
      const { data, error: profileError } = await supabase.rpc("finance_get_entity_profile", {
        p_society_id: currentSociety.id,
        p_entity_type: entityType,
        p_entity_id: entityId,
        p_actor_member_id: currentActorMemberId
      });
      if (profileError) throw profileError;
      if (!data) {
        throw new Error("Baza nije vratila finansijski profil izabranog člana.");
      }
      const { data: refunds, error: refundsError } = await supabase.rpc("finance_list_entity_refunds", {
        p_society_id: currentSociety.id,
        p_entity_type: entityType,
        p_entity_id: entityId,
        p_actor_member_id: currentActorMemberId
      });
      if (refundsError) throw refundsError;
      setProfile({ ...data, refunds: refunds ?? [] });
      setCreditTargetPersonId(data.people[0]?.person_id ?? "");
    } catch (profileLoadError) {
      setError(errorMessage(profileLoadError));
      setProfile(null);
    } finally {
      setIsProfileLoading(false);
    }
  }, []);

  const loadInitial = useCallback(async () => {
    setIsLoading(true);
    setError("");
    try {
      const supabase = getSupabaseClient();
      const { data: context, error: contextError } =
        await supabase.rpc("auth_get_application_context");
      if (contextError) throw contextError;
      const membership = context?.memberships?.[0] ?? null;
      if (!membership) throw new Error("Aktivno članstvo nije pronađeno.");
      const { data: workspace, error: workspaceError } =
        await supabase.rpc(membership.is_guardian
          ? "auth_get_guardian_finance_workspace"
          : "auth_get_finance_workspace", {
          p_society_id: membership.society_id
        });
      if (workspaceError) throw workspaceError;
      const currentSociety = workspace?.society ?? null;
      setSociety(currentSociety);
      if (!currentSociety) return;
      const currentActorMemberId = workspace.actor_society_member_id;
      setActorMemberId(currentActorMemberId);
      setCanSearchSociety(Boolean(workspace.access.can_search_society));
      setCanRecordPayment(Boolean(workspace.access.can_record_payment));
      setCanUseCredit(Boolean(workspace.access.can_use_credit));
      setCanRecordRefund(Boolean(workspace.access.can_record_refund));
      setCanVoidPayment(Boolean(workspace.access.can_void_payment));
      setCanVoidRefund(Boolean(workspace.access.can_void_refund));

      if (!workspace.access.can_search_society && workspace.initial_entity) {
        const self = workspace.initial_entity;
        setSelected(self);
        await loadProfile(
          self.entity_type,
          self.entity_id,
          currentSociety,
          currentActorMemberId
        );
      }
    } catch (initialError) {
      setError(errorMessage(initialError));
    } finally {
      setIsLoading(false);
    }
  }, [loadProfile]);

  useEffect(() => {
    void loadInitial();
  }, [loadInitial]);

  useEffect(() => {
    if (
      !isManager ||
      !society ||
      !actorMemberId ||
      query.trim().length < 2 ||
      (selected && query === selected.display_name)
    ) {
      setResults([]);
      return;
    }
    const timeout = window.setTimeout(async () => {
      setIsSearching(true);
      setError("");
      try {
        const { data, error: searchError } = await getSupabaseClient().rpc("finance_search_entities", {
          p_society_id: society.id,
          p_query: query.trim(),
          p_actor_member_id: actorMemberId,
          p_limit: 12
        });
        if (searchError) throw searchError;
        setResults(data ?? []);
      } catch (searchError) {
        setError(errorMessage(searchError));
      } finally {
        setIsSearching(false);
      }
    }, 300);
    return () => window.clearTimeout(timeout);
  }, [actorMemberId, isManager, query, selected, society]);

  async function selectEntity(entity: FinanceSearchEntity) {
    if (!society) return;
    setSelected(entity);
    setResults([]);
    setQuery(entity.display_name);
    await loadProfile(entity.entity_type, entity.entity_id, society, actorMemberId);
  }

  function openPayment() {
    setSelectedObligationIds([]);
    setPaymentAmount("");
    setPaymentMethod("CASH");
    setCreditPersonId("");
    setCreditAmount("");
    setCreditTargetPersonId(profile?.people[0]?.person_id ?? "");
    setIsPaymentOpen(true);
  }

  const selectedObligations = useMemo(() => {
    if (!profile) return [];
    return profile.open_obligations.filter((item) => selectedObligationIds.includes(item.id));
  }, [profile, selectedObligationIds]);
  const paymentCurrency = selectedObligations[0]?.currency ?? "";
  const cashValue = Math.max(Number(paymentAmount) || 0, 0);
  const requestedCreditValue = Math.max(Number(creditAmount) || 0, 0);
  const allocationPreview = useMemo(() => {
    let available = cashValue + requestedCreditValue;
    return selectedObligations.map((obligation) => {
      const amount = Math.min(obligation.remaining_amount, available);
      available -= amount;
      return { obligation_id: obligation.id, amount, title: obligation.title };
    }).filter((item) => item.amount > 0);
  }, [cashValue, requestedCreditValue, selectedObligations]);
  const allocatedTotal = allocationPreview.reduce((sum, item) => sum + item.amount, 0);
  const newCredit = Math.max(cashValue - allocatedTotal, 0);
  const availableCredits = (profile?.credits ?? []).filter((credit) =>
    !paymentCurrency || credit.currency === paymentCurrency
  );

  function toggleObligation(obligation: FinanceOpenObligation) {
    setSelectedObligationIds((current) => {
      if (current.includes(obligation.id)) return current.filter((id) => id !== obligation.id);
      const existing = profile?.open_obligations.find((item) => current.includes(item.id));
      if (existing && existing.currency !== obligation.currency) {
        setError("Jedna uplata može sadržati samo obaveze u istoj valuti.");
        return current;
      }
      setError("");
      return [...current, obligation.id];
    });
  }

  async function recordPayment() {
    if (!canRecordPayment || !society || !actorMemberId || !profile || !paymentCurrency) return;
    if (cashValue <= 0 || allocationPreview.length === 0) {
      setError("Unesite iznos i izaberite najmanje jednu obavezu.");
      return;
    }
    if (requestedCreditValue > 0 && !creditPersonId) {
      setError("Izaberite čiji kredit koristite.");
      return;
    }
    if (newCredit > 0 && !creditTargetPersonId) {
      setError("Izaberite kome pripada višak uplate.");
      return;
    }
    setIsSaving(true);
    setError("");
    try {
      const supabase = getSupabaseClient();
      const { data: authData } = await supabase.auth.getUser();
      const { data: sessionData } = await supabase.auth.getSession();
      const accessTokenForEmail = sessionData.session?.access_token ?? null;
      const { data, error: paymentError } = await supabase.rpc("finance_record_payment", {
        p_society_id: society.id,
        p_amount: cashValue,
        p_currency: paymentCurrency,
        p_payment_method: paymentMethod,
        p_allocations: allocationPreview.map(({ obligation_id, amount }) => ({ obligation_id, amount })),
        p_credit_to_person_id: newCredit > 0 ? creditTargetPersonId : null,
        p_credit_use_person_id: requestedCreditValue > 0 ? creditPersonId : null,
        p_credit_use_amount: requestedCreditValue,
        p_actor_user_id: authData.user?.id ?? null,
        p_actor_member_id: actorMemberId
      });
      if (paymentError) throw paymentError;
      const payment = data as FinancePayment;
      let emailNote = "";
      if (accessTokenForEmail) {
        const emailResponse = await fetch("/api/finance/payment-confirmation", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessTokenForEmail}`,
            "Content-Type": "application/json"
          },
          body: JSON.stringify({ paymentId: payment.id })
        });
        const emailResult = await emailResponse.json();
        emailNote = emailResponse.ok
          ? ` Email potvrde: ${emailResult.sent}/${emailResult.queued} poslato.`
          : " Uplata je sačuvana, ali potvrda emailom trenutno nije poslata.";
      }
      setMessage(`Uplata ${payment.receipt_number} je uspešno evidentirana.${emailNote}`);
      setIsPaymentOpen(false);
      await loadProfile(selected!.entity_type, selected!.entity_id, society, actorMemberId);
    } catch (paymentError) {
      setError(errorMessage(paymentError));
    } finally {
      setIsSaving(false);
    }
  }

  async function confirmVoidPayment() {
    if (!voidPayment || !voidPaymentReason.trim() || !actorMemberId || !society || !selected) return;
    setIsSaving(true);
    setError("");
    try {
      const supabase = getSupabaseClient();
      const { data: authData } = await supabase.auth.getUser();
      const { error: voidError } = await supabase.rpc("finance_void_payment", {
        p_payment_id: voidPayment.id,
        p_reason: voidPaymentReason.trim(),
        p_actor_user_id: authData.user?.id ?? null,
        p_actor_member_id: actorMemberId
      });
      if (voidError) throw voidError;
      setMessage(`Uplata ${voidPayment.receipt_number} je poništena.`);
      setVoidPayment(null);
      setVoidPaymentReason("");
      await loadProfile(selected.entity_type, selected.entity_id, society, actorMemberId);
    } catch (voidError) { setError(errorMessage(voidError)); }
    finally { setIsSaving(false); }
  }

  function openRefund() {
    const credit = profile?.credits[0];
    if (!credit) return;
    setRefundPersonId(credit.person_id);
    setRefundCurrency(credit.currency);
    setRefundAmount(String(credit.amount));
    setRefundMethod("CASH");
    setRefundReason("");
    setIsRefundOpen(true);
  }

  async function recordRefund() {
    const amount = Number(refundAmount);
    if (!society || !actorMemberId || !selected || !refundPersonId || !refundCurrency || amount <= 0 || !refundReason.trim()) return;
    setIsSaving(true);
    setError("");
    try {
      const { data, error: refundError } = await getSupabaseClient().rpc("finance_record_refund", {
        p_society_id: society.id,
        p_person_id: refundPersonId,
        p_amount: amount,
        p_currency: refundCurrency,
        p_refund_method: refundMethod,
        p_reason: refundReason.trim(),
        p_actor_member_id: actorMemberId
      });
      if (refundError) throw refundError;
      setMessage(`Povraćaj ${data.refund_number} je uspešno evidentiran.`);
      setIsRefundOpen(false);
      await loadProfile(selected.entity_type, selected.entity_id, society, actorMemberId);
    } catch (refundError) { setError(errorMessage(refundError)); }
    finally { setIsSaving(false); }
  }

  async function confirmVoidRefund() {
    if (!voidRefund || !voidRefundReason.trim() || !actorMemberId || !society || !selected) return;
    setIsSaving(true);
    setError("");
    try {
      const { error: voidError } = await getSupabaseClient().rpc("finance_void_refund", {
        p_refund_id: voidRefund.id,
        p_reason: voidRefundReason.trim(),
        p_actor_member_id: actorMemberId
      });
      if (voidError) throw voidError;
      setMessage(`Povraćaj ${voidRefund.refund_number} je poništen.`);
      setVoidRefund(null);
      setVoidRefundReason("");
      await loadProfile(selected.entity_type, selected.entity_id, society, actorMemberId);
    } catch (voidError) { setError(errorMessage(voidError)); }
    finally { setIsSaving(false); }
  }

  if (isLoading) return <section className="card attendance-empty">Učitavanje finansija...</section>;

  return <>
    {error && <p className="alert alert-error">{error}</p>}
    {message && <p className="alert alert-success">{message}</p>}

    {isManager && !actorMemberId && <section className="card attendance-empty">Prijavljeni korisnik nije povezan sa članom društva. Završite profil predsednika ili blagajnika pre rada sa finansijama.</section>}

    <section className={`finance-workspace ${isManager ? "manager" : "self"}`}>
      {isManager && <aside className="card finance-search-panel">
        <header><h2>Pronađi člana</h2><p>Ime, prezime, email ili telefon</p></header>
        <input className="input" autoComplete="off" placeholder="Počnite da kucate..." value={query} onChange={(event) => { setQuery(event.target.value); setSelected(null); setProfile(null); }} />
        <div className="finance-search-results">
          {isSearching && <p className="program-empty-row">Pretraga...</p>}
          {!isSearching && query.trim().length >= 2 && results.length === 0 && <p className="program-empty-row">Nema rezultata.</p>}
          {results.map((entity) => <button key={`${entity.entity_type}-${entity.entity_id}`} type="button" onClick={() => void selectEntity(entity)}>
            <span><strong>{entity.display_name}</strong><small>{entity.subtitle || (entity.entity_type === "GUARDIAN" ? "Roditelj/staratelj" : "Član ili putnik")}</small></span>
            <span className={entity.overdue_obligation_count > 0 ? "overdue" : ""}>{entity.open_obligation_count} otvoreno</span>
          </button>)}
        </div>
      </aside>}

      <main className="card finance-profile-panel">
        {isProfileLoading && <div className="attendance-empty">Učitavanje profila...</div>}
        {!isProfileLoading && !profile && <div className="attendance-empty">{isManager ? "Pretražite i izaberite člana ili roditelja." : "Finansijski profil nije dostupan."}</div>}
        {!isProfileLoading && profile && <>
          <header className="finance-profile-header">
            <div><p className="eyebrow">{profile.entity.type === "GUARDIAN" ? "Porodični pregled" : "Finansijski profil"}</p><h2>{profile.entity.name}</h2><p>{profile.people.map((person) => person.name).join(" · ")}</p></div>
            <div className="header-actions">
              {canRecordRefund && profile.credits.length > 0 && <button className="button button-secondary" onClick={openRefund} type="button">EVIDENTIRAJ POVRAĆAJ</button>}
              {canRecordPayment && profile.open_obligations.length > 0 && <button className="button button-primary" onClick={openPayment} type="button">EVIDENTIRAJ UPLATU</button>}
            </div>
          </header>

          <div className="finance-summary-row">
            <div><span>Otvorene obaveze</span><strong>{profile.open_obligations.length}</strong></div>
            <div><span>Dospele</span><strong>{profile.open_obligations.filter((item) => item.is_overdue).length}</strong></div>
            <div><span>Kredit</span><strong>{profile.credits.length ? profile.credits.map((credit) => money(credit.amount, credit.currency)).join(" · ") : "0"}</strong></div>
          </div>

          <section className="finance-obligations">
            <h3>Otvorene obaveze</h3>
            {profile.open_obligations.length === 0 && <div className="program-empty"><strong>Nema otvorenih obaveza.</strong><span>Sve evidentirane obaveze su izmirene.</span></div>}
            {profile.open_obligations.map((obligation) => <article key={obligation.id} className={obligation.is_overdue ? "overdue" : ""}>
              <div><strong>{obligation.title}</strong><span>{profile.people.find((person) => person.person_id === obligation.person_id)?.name} · rok {date(obligation.due_date)}</span></div>
              <div><small>Plaćeno {money(obligation.paid_amount, obligation.currency)}</small><strong>{money(obligation.remaining_amount, obligation.currency)}</strong></div>
            </article>)}
          </section>

          <section className="finance-payment-history">
            <h3>Istorija uplata</h3>
            {profile.payments.length === 0 && <p className="program-empty-row">Još nema evidentiranih uplata.</p>}
            {profile.payments.length > 0 && <div className="finance-payment-list">
              {profile.payments.map((payment) => <article key={payment.id}>
                <strong>{payment.receipt_number}</strong>
                <span>{dateTime(payment.recorded_at)} · {payment.payment_method === "CASH" ? "Gotovina" : "Uplata na račun"}</span>
                <small>{payment.status === "VOIDED" ? "PONIŠTENA" : "EVIDENTIRANA"}</small>
                <strong>{money(payment.amount, payment.currency)}</strong>
                {canVoidPayment && payment.status === "POSTED" && <button className="button button-danger button-small" onClick={() => { setVoidPayment(payment); setVoidPaymentReason(""); }} type="button">PONIŠTI</button>}
              </article>)}
            </div>}
          </section>

          <section className="finance-payment-history">
            <h3>Istorija povraćaja</h3>
            {profile.refunds.length === 0 && <p className="program-empty-row">Još nema evidentiranih povraćaja.</p>}
            {profile.refunds.length > 0 && <div className="finance-payment-list">
              {profile.refunds.map((refund) => <article key={refund.id}>
                <strong>{refund.refund_number}</strong>
                <span>{dateTime(refund.recorded_at)} · {refund.refund_method === "CASH" ? "Gotovina" : "Prenos na račun"}</span>
                <small>{refund.status === "VOIDED" ? "PONIŠTEN" : "EVIDENTIRAN"}</small>
                <strong>{money(refund.amount, refund.currency)}</strong>
                {canVoidRefund && refund.status === "POSTED" && <button className="button button-danger button-small" onClick={() => { setVoidRefund(refund); setVoidRefundReason(""); }} type="button">PONIŠTI</button>}
              </article>)}
            </div>}
          </section>
        </>}
      </main>
    </section>

    {isPaymentOpen && profile && <div className="modal-backdrop">
      <section className="card modal-card finance-payment-modal">
        <header><div><p className="eyebrow">Nova uplata</p><h2>{profile.entity.name}</h2></div><button className="button button-secondary" onClick={() => setIsPaymentOpen(false)} type="button">ZATVORI</button></header>
        {error && <p className="alert alert-error">{error}</p>}
        <div className="finance-payment-fields">
          <label className="form-field"><span>Primljeni iznos</span><input className="input" min="0" step="0.01" type="number" value={paymentAmount} onChange={(event) => setPaymentAmount(event.target.value)} /></label>
          <label className="form-field"><span>Način plaćanja</span><select className="input" value={paymentMethod} onChange={(event) => setPaymentMethod(event.target.value as "CASH" | "BANK_TRANSFER")}><option value="CASH">Gotovina</option><option value="BANK_TRANSFER">Uplata na račun</option></select></label>
        </div>
        <section className="finance-payment-obligations"><h3>Izaberite obaveze</h3>{profile.open_obligations.map((obligation) => <label key={obligation.id} className={selectedObligationIds.includes(obligation.id) ? "selected" : ""}><input checked={selectedObligationIds.includes(obligation.id)} onChange={() => toggleObligation(obligation)} type="checkbox" /><span><strong>{obligation.title}</strong><small>{profile.people.find((person) => person.person_id === obligation.person_id)?.name} · {money(obligation.remaining_amount, obligation.currency)}</small></span></label>)}</section>
        {canUseCredit && availableCredits.length > 0 && <div className="finance-credit-fields">
          <label className="form-field"><span>Koristi kredit</span><select className="input" value={creditPersonId} onChange={(event) => setCreditPersonId(event.target.value)}><option value="">Ne koristi kredit</option>{availableCredits.map((credit) => <option key={`${credit.person_id}-${credit.currency}`} value={credit.person_id}>{profile.people.find((person) => person.person_id === credit.person_id)?.name} — {money(credit.amount, credit.currency)}</option>)}</select></label>
          {creditPersonId && <label className="form-field"><span>Iznos kredita</span><input className="input" min="0" max={availableCredits.find((credit) => credit.person_id === creditPersonId)?.amount} step="0.01" type="number" value={creditAmount} onChange={(event) => setCreditAmount(event.target.value)} /></label>}
        </div>}
        {newCredit > 0 && <label className="form-field"><span>Višak {money(newCredit, paymentCurrency)} pripada</span><select className="input" value={creditTargetPersonId} onChange={(event) => setCreditTargetPersonId(event.target.value)}>{profile.people.map((person) => <option key={person.person_id} value={person.person_id}>{person.name}</option>)}</select></label>}
        <div className="finance-allocation-preview"><span>Raspoređeno</span><strong>{paymentCurrency ? money(allocatedTotal, paymentCurrency) : "0"}</strong>{allocationPreview.map((item) => <small key={item.obligation_id}>{item.title}: {money(item.amount, paymentCurrency)}</small>)}</div>
        <div className="header-actions"><button className="button button-secondary" onClick={() => setIsPaymentOpen(false)} type="button">OTKAŽI</button><button className="button button-primary" disabled={isSaving || cashValue <= 0 || allocationPreview.length === 0} onClick={() => void recordPayment()} type="button">{isSaving ? "ČUVANJE..." : "POTVRDI UPLATU"}</button></div>
      </section>
    </div>}

    {voidPayment && <div className="modal-backdrop">
      <section className="card modal-card finance-action-modal">
        <header><div><p className="eyebrow">Poništavanje uplate</p><h2>{voidPayment.receipt_number}</h2></div></header>
        <p>Poništavanjem se obaveze ponovo otvaraju. Finansijska istorija ostaje sačuvana.</p>
        <label className="form-field"><span>Razlog poništavanja *</span><textarea className="input" value={voidPaymentReason} onChange={(event) => setVoidPaymentReason(event.target.value)} /></label>
        <div className="header-actions"><button className="button button-secondary" onClick={() => setVoidPayment(null)} type="button">OTKAŽI</button><button className="button button-danger" disabled={isSaving || !voidPaymentReason.trim()} onClick={() => void confirmVoidPayment()} type="button">POTVRDI PONIŠTAVANJE</button></div>
      </section>
    </div>}

    {isRefundOpen && profile && <div className="modal-backdrop">
      <section className="card modal-card finance-action-modal">
        <header><div><p className="eyebrow">Novi povraćaj</p><h2>{profile.entity.name}</h2></div></header>
        <div className="finance-payment-fields">
          <label className="form-field"><span>Kredit osobe</span><select className="input" value={`${refundPersonId}|${refundCurrency}`} onChange={(event) => { const [personId, currency] = event.target.value.split("|"); const credit = profile.credits.find((item) => item.person_id === personId && item.currency === currency); setRefundPersonId(personId); setRefundCurrency(currency); setRefundAmount(String(credit?.amount ?? "")); }}>{profile.credits.map((credit) => <option key={`${credit.person_id}-${credit.currency}`} value={`${credit.person_id}|${credit.currency}`}>{profile.people.find((person) => person.person_id === credit.person_id)?.name} · {money(credit.amount, credit.currency)}</option>)}</select></label>
          <label className="form-field"><span>Iznos povraćaja</span><input className="input" min="0.01" max={profile.credits.find((credit) => credit.person_id === refundPersonId && credit.currency === refundCurrency)?.amount} step="0.01" type="number" value={refundAmount} onChange={(event) => setRefundAmount(event.target.value)} /></label>
          <label className="form-field"><span>Način povraćaja</span><select className="input" value={refundMethod} onChange={(event) => setRefundMethod(event.target.value as "CASH" | "BANK_TRANSFER")}><option value="CASH">Gotovina</option><option value="BANK_TRANSFER">Prenos na račun</option></select></label>
        </div>
        <label className="form-field"><span>Razlog povraćaja *</span><textarea className="input" value={refundReason} onChange={(event) => setRefundReason(event.target.value)} /></label>
        <div className="header-actions"><button className="button button-secondary" onClick={() => setIsRefundOpen(false)} type="button">OTKAŽI</button><button className="button button-primary" disabled={isSaving || Number(refundAmount) <= 0 || !refundReason.trim()} onClick={() => void recordRefund()} type="button">POTVRDI POVRAĆAJ</button></div>
      </section>
    </div>}

    {voidRefund && <div className="modal-backdrop">
      <section className="card modal-card finance-action-modal">
        <header><div><p className="eyebrow">Poništavanje povraćaja</p><h2>{voidRefund.refund_number}</h2></div></header>
        <p>Poništavanjem se iznos vraća na raspoloživi kredit osobe.</p>
        <label className="form-field"><span>Razlog poništavanja *</span><textarea className="input" value={voidRefundReason} onChange={(event) => setVoidRefundReason(event.target.value)} /></label>
        <div className="header-actions"><button className="button button-secondary" onClick={() => setVoidRefund(null)} type="button">OTKAŽI</button><button className="button button-danger" disabled={isSaving || !voidRefundReason.trim()} onClick={() => void confirmVoidRefund()} type="button">POTVRDI PONIŠTAVANJE</button></div>
      </section>
    </div>}
  </>;
}
