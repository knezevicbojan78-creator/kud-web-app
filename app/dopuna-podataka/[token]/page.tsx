"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { useParams } from "next/navigation";

import { getSupabaseClient } from "../../_lib/supabaseClient";

type Draft = {
  is_minor_member: boolean;
  first_name: string;
  last_name: string;
  gender: string;
  birth_date: string;
  email: string;
  phone: string;
  shoe_size: string;
  address: string;
  city: string;
  postal_code: string;
  country: string;
  jmbg: string;
  passport_number: string;
  passport_expiry_date: string;
  guardian1: GuardianDraft;
  guardian2: GuardianDraft;
  showGuardian2: boolean;
};

type GuardianDraft = {
  first_name: string;
  last_name: string;
  email: string;
  phone: string;
};

const emptyGuardian = (): GuardianDraft => ({
  first_name: "", last_name: "", email: "", phone: ""
});

const emptyDraft = (): Draft => ({
  is_minor_member: false,
  first_name: "",
  last_name: "",
  gender: "",
  birth_date: "",
  email: "",
  phone: "",
  shoe_size: "",
  address: "",
  city: "",
  postal_code: "",
  country: "Srbija",
  jmbg: "",
  passport_number: "",
  passport_expiry_date: "",
  guardian1: emptyGuardian(),
  guardian2: emptyGuardian(),
  showGuardian2: false
});

export default function MemberDataCompletionPage() {
  const token = String(useParams<{ token: string }>().token ?? "");
  const [draft, setDraft] = useState<Draft>(emptyDraft);
  const [version, setVersion] = useState(1);
  const [status, setStatus] = useState("");
  const [saveState, setSaveState] = useState<"idle" | "saving" | "saved" | "error">("idle");
  const [lastSavedAt, setLastSavedAt] = useState<string | null>(null);
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(true);
  const [isSubmitted, setIsSubmitted] = useState(false);
  const [recipientRole, setRecipientRole] = useState<"MEMBER" | "GUARDIAN">("MEMBER");
  const [editingLocked, setEditingLocked] = useState(false);
  const [editingBy, setEditingBy] = useState("");
  const saveTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const latestDraft = useRef<Draft>(draft);
  const latestVersion = useRef(version);

  useEffect(() => { latestDraft.current = draft; }, [draft]);
  useEffect(() => { latestVersion.current = version; }, [version]);

  useEffect(() => {
    async function load() {
      try {
        const { data, error: loadError } = await (getSupabaseClient().rpc as any)(
          "public_get_member_data_invitation",
          { p_token: token }
        );
        if (loadError || !data) throw loadError ?? new Error("Link nije važeći.");
        const loadedDraft = mergeDraft(data.draft);
        // Punoletstvo se određuje isključivo iz datuma rođenja. Roditeljski
        // poziv je već dokaz da se radi o maloletnom članu dok se datum ne unese.
        loadedDraft.is_minor_member = data.recipient_role === "GUARDIAN" || isUnder18(loadedDraft.birth_date);
        setDraft(loadedDraft);
        setVersion(data.draft_version);
        setRecipientRole(data.recipient_role);
        setEditingLocked(Boolean(data.editing_locked));
        setEditingBy(data.editing_by ?? "");
        setStatus(data.status);
        setLastSavedAt(data.last_saved_at);
        setIsSubmitted(data.status === "SUBMITTED");
      } catch (loadError) {
        setError(getMessage(loadError));
      } finally {
        setIsLoading(false);
      }
    }
    void load();
  }, [token]);

  const saveDraft = useCallback(async (showConfirmation = false) => {
    if (isSubmitted) return true;
    setSaveState("saving");
    setError("");
    const expectedVersion = latestVersion.current;
    try {
      const { data, error: saveError } = await (getSupabaseClient().rpc as any)(
        "public_save_member_data_draft",
        {
          p_token: token,
          p_draft: latestDraft.current,
          p_expected_version: expectedVersion
        }
      );
      if (saveError || !data) throw saveError ?? new Error("Nacrt nije sačuvan.");
      latestVersion.current = data.draft_version;
      setVersion(data.draft_version);
      setLastSavedAt(data.last_saved_at);
      setSaveState("saved");
      if (showConfirmation) setStatus("IN_PROGRESS");
      return true;
    } catch (saveError) {
      setSaveState("error");
      setError(getMessage(saveError));
      return false;
    }
  }, [isSubmitted, token]);

  function scheduleSave(nextDraft: Draft) {
    if (editingLocked) return;
    latestDraft.current = nextDraft;
    setDraft(nextDraft);
    setSaveState("idle");
    if (saveTimer.current) clearTimeout(saveTimer.current);
    saveTimer.current = setTimeout(() => void saveDraft(), 1200);
  }

  function change(field: keyof Draft, value: string | boolean) {
    const nextDraft = { ...latestDraft.current, [field]: value };
    if (field === "birth_date") {
      nextDraft.is_minor_member = isUnder18(String(value));
    }
    scheduleSave(nextDraft);
  }

  function changeGuardian(which: "guardian1" | "guardian2", field: keyof GuardianDraft, value: string) {
    scheduleSave({
      ...latestDraft.current,
      [which]: { ...latestDraft.current[which], [field]: value }
    });
  }

  async function submit() {
    if (saveTimer.current) clearTimeout(saveTimer.current);
    setError("");
    const missing = getMissingRequiredFields(latestDraft.current);
    if (missing.length > 0) {
      setError(`Dopunite obavezna polja: ${missing.join(", ")}.`);
      return;
    }
    if (
      Boolean(latestDraft.current.passport_number) !==
      Boolean(latestDraft.current.passport_expiry_date)
    ) {
      setError("Broj pasoša i datum važenja moraju biti uneti zajedno.");
      return;
    }
    setSaveState("saving");
    try {
      const { error: submitError } = await (getSupabaseClient().rpc as any)(
        "public_submit_member_data",
        {
          p_token: token,
          p_draft: latestDraft.current,
          p_expected_version: latestVersion.current
        }
      );
      if (submitError) throw submitError;
      setIsSubmitted(true);
      setStatus("SUBMITTED");
      setSaveState("saved");
    } catch (submitError) {
      setSaveState("error");
      setError(getMessage(submitError));
    }
  }

  if (isLoading) return <PublicShell><p>Učitavanje obrasca...</p></PublicShell>;
  if (error && !status) return <PublicShell><div className="auth-message error">{error}</div></PublicShell>;
  if (isSubmitted) {
    return <PublicShell>
      <div className="member-data-complete">
        <h1>Podaci su poslati</h1>
        <p>Predsednik društva će pregledati podatke i završiti evidentiranje članstva.</p>
      </div>
    </PublicShell>;
  }

  return (
    <PublicShell>
      <header className="member-data-header">
        <div>
          <p className="eyebrow">Dopuna podataka</p>
          <h1>{draft.first_name} {draft.last_name}</h1>
          <p>Podaci se automatski čuvaju. Obrazac možete zatvoriti i nastaviti kasnije preko istog linka.</p>
        </div>
        <div className="member-data-progress">
          <strong>{getProgress(draft)}%</strong>
          <span>obaveznih podataka</span>
          <SaveIndicator state={saveState} lastSavedAt={lastSavedAt} />
        </div>
      </header>

      {error && <div className="auth-message error">{error}</div>}
      {editingLocked && (
        <div className="auth-message">
          Podatke trenutno dopunjava {editingBy || "druga osoba"}. Obrazac je privremeno samo za pregled. Pokušajte ponovo za nekoliko minuta.
        </div>
      )}
      <fieldset className="member-data-fieldset" disabled={editingLocked}>
      <div className="member-data-grid">
        <Field label="Ime" value={draft.first_name} onChange={(value) => change("first_name", value)} required />
        <Field label="Prezime" value={draft.last_name} onChange={(value) => change("last_name", value)} required />
        <Field label="Email" value={draft.email} onChange={(value) => change("email", value)} type="email" required={!draft.is_minor_member} disabled />
        <Field label="Telefon" value={draft.phone} onChange={(value) => change("phone", value)} type="tel" required={!draft.is_minor_member} />
        <Field label="Broj obuće" value={draft.shoe_size} onChange={(value) => change("shoe_size", value.replace(/\D/g, "").slice(0, 2))} type="number" />
        <label className="form-field">
          <span>Pol *</span>
          <select className="input" required value={draft.gender} onChange={(event) => change("gender", event.target.value)}>
            <option value="">Izaberite</option><option>Muško</option><option>Žensko</option>
          </select>
        </label>
        <DateField label="Datum rođenja" value={draft.birth_date} onChange={(value) => change("birth_date", value)} required />
        <Field label="Adresa" value={draft.address} onChange={(value) => change("address", value)} required />
        <Field label="Mesto" value={draft.city} onChange={(value) => change("city", value)} required />
        <Field label="Poštanski broj" value={draft.postal_code} onChange={(value) => change("postal_code", value)} required />
        <Field label="Država" value={draft.country} onChange={(value) => change("country", value)} required />
        <Field label="JMBG" value={draft.jmbg} onChange={(value) => change("jmbg", value)} />
        <Field label="Broj pasoša" value={draft.passport_number} onChange={(value) => change("passport_number", value)} />
        <DateField label="Datum važenja pasoša" value={draft.passport_expiry_date} onChange={(value) => change("passport_expiry_date", value)} />
      </div>

      {recipientRole === "GUARDIAN" && (
        <section className="member-data-guardians">
          <h2>Roditelj/staratelj 1</h2>
          <GuardianFields value={draft.guardian1} emailDisabled onChange={(field, value) => changeGuardian("guardian1", field, value)} />
          {draft.showGuardian2 ? <>
            <h2>Roditelj/staratelj 2</h2>
            <GuardianFields value={draft.guardian2} onChange={(field, value) => changeGuardian("guardian2", field, value)} />
            <button className="button button-secondary" type="button" onClick={() => change("showGuardian2", false)}>Ukloni drugog roditelja/staratelja</button>
          </> : (
            <button className="button button-secondary" type="button" onClick={() => change("showGuardian2", true)}>Dodaj drugog roditelja/staratelja</button>
          )}
        </section>
      )}
      </fieldset>

      <footer className="member-data-actions">
        <button className="button button-secondary" type="button" disabled={editingLocked || saveState === "saving"} onClick={() => void saveDraft(true)}>
          Sačuvaj i nastavi kasnije
        </button>
        <button className="button button-primary" type="button" disabled={editingLocked || saveState === "saving"} onClick={() => void submit()}>
          Pošalji podatke predsedniku
        </button>
      </footer>
    </PublicShell>
  );
}

function PublicShell({ children }: { children: React.ReactNode }) {
  return <main className="member-data-public-page"><section className="card member-data-public-card">{children}</section></main>;
}

function Field({ label, value, onChange, type = "text", required = false, disabled = false }: {
  label: string; value: string; onChange: (value: string) => void; type?: string; required?: boolean; disabled?: boolean;
}) {
  return <label className="form-field"><span>{label}{required ? " *" : ""}</span><input className="input" type={type} value={value} required={required} disabled={disabled} onChange={(event) => onChange(event.target.value)} /></label>;
}

function DateField({ label, value, onChange, required = false }: {
  label: string; value: string; onChange: (value: string) => void; required?: boolean;
}) {
  const [text, setText] = useState(() => formatSerbianDate(value));

  useEffect(() => {
    setText(formatSerbianDate(value));
  }, [value]);

  function commit() {
    if (!text.trim()) {
      onChange("");
      return;
    }
    const parsed = parseSerbianDate(text);
    if (parsed) {
      setText(formatSerbianDate(parsed));
      onChange(parsed);
    }
  }

  return <label className="form-field">
    <span>{label}{required ? " *" : ""}</span>
    <input
      className="input"
      inputMode="numeric"
      placeholder="dd.mm.gggg"
      required={required}
      type="text"
      value={text}
      onBlur={commit}
      onChange={(event) => setText(event.target.value)}
    />
  </label>;
}

function GuardianFields({ value, onChange, emailDisabled = false }: { value: GuardianDraft; onChange: (field: keyof GuardianDraft, value: string) => void; emailDisabled?: boolean }) {
  return <div className="member-data-grid">
    <Field label="Ime" value={value.first_name} onChange={(next) => onChange("first_name", next)} required />
    <Field label="Prezime" value={value.last_name} onChange={(next) => onChange("last_name", next)} required />
    <Field label="Email" value={value.email} onChange={(next) => onChange("email", next)} type="email" required disabled={emailDisabled} />
    <Field label="Telefon" value={value.phone} onChange={(next) => onChange("phone", next)} type="tel" required />
  </div>;
}

function SaveIndicator({ state, lastSavedAt }: { state: string; lastSavedAt: string | null }) {
  if (state === "saving") return <span className="member-data-save saving">Čuvanje...</span>;
  if (state === "error") return <span className="member-data-save error">Nije sačuvano</span>;
  if (lastSavedAt) return <span className="member-data-save saved">Sačuvano {new Date(lastSavedAt).toLocaleTimeString("sr-RS", { hour: "2-digit", minute: "2-digit" })}</span>;
  return <span className="member-data-save">Još nije sačuvano</span>;
}

function asDraftText(value: unknown, fallback = "") {
  return typeof value === "string" ? value : value == null ? fallback : String(value);
}

function isUnder18(birthDate: string) {
  const match = birthDate.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) return false;
  const date = new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])));
  if (Number.isNaN(date.getTime())) return false;
  const today = new Date();
  let age = today.getFullYear() - date.getUTCFullYear();
  const birthdayThisYear = new Date(today.getFullYear(), date.getUTCMonth(), date.getUTCDate());
  if (today < birthdayThisYear) age -= 1;
  return age < 18;
}

function mergeDraft(value: Partial<Draft> | null): Draft {
  const base = emptyDraft();
  const source = value ?? {};
  const guardian1: Partial<GuardianDraft> = source.guardian1 ?? {};
  const guardian2: Partial<GuardianDraft> = source.guardian2 ?? {};

  return {
    is_minor_member: source.is_minor_member === true,
    first_name: asDraftText(source.first_name),
    last_name: asDraftText(source.last_name),
    gender: asDraftText(source.gender),
    birth_date: asDraftText(source.birth_date),
    email: asDraftText(source.email),
    phone: asDraftText(source.phone),
    shoe_size: asDraftText(source.shoe_size),
    address: asDraftText(source.address),
    city: asDraftText(source.city),
    postal_code: asDraftText(source.postal_code),
    country: asDraftText(source.country, base.country),
    jmbg: asDraftText(source.jmbg),
    passport_number: asDraftText(source.passport_number),
    passport_expiry_date: asDraftText(source.passport_expiry_date),
    guardian1: {
      first_name: asDraftText(guardian1.first_name),
      last_name: asDraftText(guardian1.last_name),
      email: asDraftText(guardian1.email),
      phone: asDraftText(guardian1.phone)
    },
    guardian2: {
      first_name: asDraftText(guardian2.first_name),
      last_name: asDraftText(guardian2.last_name),
      email: asDraftText(guardian2.email),
      phone: asDraftText(guardian2.phone)
    },
    showGuardian2: source.showGuardian2 === true
  };
}

function getMessage(error: unknown) {
  return error instanceof Error ? error.message : typeof error === "object" && error && "message" in error ? String(error.message) : "Došlo je do greške.";
}

function getProgress(draft: Draft) {
  const values = [
    draft.first_name, draft.last_name,
    ...(!draft.is_minor_member ? [draft.email, draft.phone] : []),
    draft.gender,
    draft.birth_date, draft.address, draft.city, draft.postal_code, draft.country,
    ...(draft.is_minor_member
      ? [
          draft.guardian1.first_name, draft.guardian1.last_name,
          draft.guardian1.email, draft.guardian1.phone
        ]
      : [])
  ];
  return Math.round((values.filter((value) => value.trim()).length / values.length) * 100);
}

function getMissingRequiredFields(draft: Draft) {
  const fields: Array<[string, string]> = [
    ["Ime", draft.first_name],
    ["Prezime", draft.last_name],
    ["Pol", draft.gender],
    ["Datum rođenja", draft.birth_date],
    ["Adresa", draft.address],
    ["Mesto", draft.city],
    ["Poštanski broj", draft.postal_code],
    ["Država", draft.country]
  ];
  if (!draft.is_minor_member) {
    fields.push(["Email", draft.email], ["Telefon", draft.phone]);
  }
  if (draft.is_minor_member) {
    fields.push(
      ["Ime roditelja/staratelja", draft.guardian1.first_name],
      ["Prezime roditelja/staratelja", draft.guardian1.last_name],
      ["Email roditelja/staratelja", draft.guardian1.email],
      ["Telefon roditelja/staratelja", draft.guardian1.phone]
    );
  }
  return fields.filter(([, value]) => !value.trim()).map(([label]) => label);
}

function formatSerbianDate(value: string) {
  const match = value.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  return match ? `${match[3]}.${match[2]}.${match[1]}` : value;
}

function parseSerbianDate(value: string) {
  const normalized = value.trim();
  const match =
    normalized.match(/^(\d{1,2})\.(\d{1,2})\.(\d{4})\.?$/) ??
    normalized.match(/^(\d{2})(\d{2})(\d{4})$/);
  if (!match) return null;
  const day = Number(match[1]);
  const month = Number(match[2]);
  const year = Number(match[3]);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) return null;
  return `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}
