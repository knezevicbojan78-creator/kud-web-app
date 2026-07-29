"use client";

import { useEffect, useMemo, useState } from "react";
import {
  getSupabaseClient,
  type ApplicationContext,
  type Person,
  type SocietyMember
} from "../../_lib/supabaseClient";

type Tab = "personal" | "documents" | "society" | "family" | "security";
type Detail = {
  member: SocietyMember | null;
  person: Person;
  guardians: Array<{ person: Person }>;
  section_ids: string[];
};
type GuardianChild = {
  person: Person;
  member: SocietyMember;
  section_ids: string[];
};
type Workspace = {
  society: { name: string };
  sections: Array<{ id: string; name: string }>;
};
type FormValues = {
  first_name: string; last_name: string; gender: string; birth_date: string;
  address: string; city: string; postal_code: string; country: string;
  nationality: string; phone: string; jmbg: string; passport_number: string;
  passport_issuing_country: string; passport_expiry_date: string;
  shoe_size: string;
};

const tabs: Array<{ id: Tab; label: string }> = [
  { id: "personal", label: "Lični podaci" },
  { id: "documents", label: "Dokumenta" },
  { id: "society", label: "Društvo" },
  { id: "family", label: "Porodica" },
  { id: "security", label: "Bezbednost" }
];

const emptyForm: FormValues = {
  first_name: "", last_name: "", gender: "", birth_date: "", address: "",
  city: "", postal_code: "", country: "Srbija", nationality: "", phone: "",
  jmbg: "", passport_number: "", passport_issuing_country: "",
  passport_expiry_date: "", shoe_size: ""
};

function toForm(person: Person): FormValues {
  return Object.fromEntries(
    Object.keys(emptyForm).map((key) => [
      key,
      String(person[key as keyof Person] ?? "")
    ])
  ) as unknown as FormValues;
}

function formatDate(value: string | null) {
  if (!value) return "Nije uneto";
  return new Intl.DateTimeFormat("sr-Latn-RS").format(
    new Date(`${value.slice(0, 10)}T00:00:00`)
  );
}

function valueOrEmpty(value: string | null | undefined) {
  return value?.trim() || "Nije uneto";
}

function initials(person: Person) {
  return `${person.first_name?.[0] ?? ""}${person.last_name?.[0] ?? ""}`.toUpperCase();
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return <div className="my-data-row"><dt>{label}</dt><dd>{value}</dd></div>;
}

export default function MojiPodaciPage() {
  const [context, setContext] = useState<ApplicationContext | null>(null);
  const [detail, setDetail] = useState<Detail | null>(null);
  const [workspace, setWorkspace] = useState<Workspace | null>(null);
  const [guardianChildren, setGuardianChildren] = useState<GuardianChild[]>([]);
  const [isGuardian, setIsGuardian] = useState(false);
  const [activeTab, setActiveTab] = useState<Tab>("personal");
  const [isEditing, setIsEditing] = useState(false);
  const [form, setForm] = useState<FormValues>(emptyForm);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  async function loadProfile() {
    setIsLoading(true);
    setError("");
    const supabase = getSupabaseClient();
    const { data: contextData, error: contextError } = await supabase.rpc(
      "auth_get_application_context"
    );
    if (contextError || !contextData || contextData.account_type !== "SOCIETY_USER") {
      setError(
        contextData?.account_type === "MASTER_ADMIN"
          ? "Master admin nema članski profil. Ova stranica je namenjena korisnicima društva."
          : "Članski profil nije dostupan."
      );
      setIsLoading(false);
      return;
    }
    const membership = contextData.memberships[0];
    if (!membership) {
      setError("Aktivno članstvo nije pronađeno.");
      setIsLoading(false);
      return;
    }
    if (membership.is_guardian) {
      const { data: guardianProfile, error: guardianError } = await supabase.rpc(
        "auth_get_guardian_profile",
        { p_society_id: membership.society_id }
      );
      if (guardianError || !guardianProfile) {
        setError(guardianError?.message || "Roditeljski profil nije učitan.");
        setIsLoading(false);
        return;
      }
      setContext(contextData);
      setIsGuardian(true);
      setGuardianChildren(guardianProfile.children ?? []);
      setDetail({
        member: null,
        person: guardianProfile.person,
        guardians: [],
        section_ids: []
      });
      setWorkspace({
        society: { name: guardianProfile.society.name },
        sections: guardianProfile.sections ?? []
      });
      setForm(toForm(guardianProfile.person));
      setIsLoading(false);
      return;
    }
    const [detailResult, workspaceResult] = await Promise.all([
      supabase.rpc("auth_get_member_detail", {
        p_society_member_id: membership.society_member_id
      }),
      supabase.rpc("auth_get_society_workspace", {
        p_society_id: membership.society_id
      })
    ]);
    if (detailResult.error || !detailResult.data) {
      setError(detailResult.error?.message || "Profil nije učitan.");
      setIsLoading(false);
      return;
    }
    setContext(contextData);
    setIsGuardian(false);
    setGuardianChildren([]);
    setDetail(detailResult.data);
    setWorkspace(workspaceResult.data ?? null);
    setForm(toForm(detailResult.data.person));
    setIsLoading(false);
  }

  useEffect(() => { void loadProfile(); }, []);

  const missingFields = useMemo(() => {
    if (!detail) return [];
    const person = detail.person;
    const required: Array<[string, string | null]> = [
      ["datum rođenja", person.birth_date], ["pol", person.gender],
      ["adresa", person.address], ["grad", person.city],
      ["poštanski broj", person.postal_code], ["država", person.country],
      ["telefon", person.phone], ["email", person.email]
    ];
    return required.filter(([, value]) => !value?.trim()).map(([label]) => label);
  }, [detail]);

  const sectionNames = useMemo(() => {
    if (!detail || !workspace) return [];
    return workspace.sections
      .filter((section) => detail.section_ids.includes(section.id))
      .map((section) => section.name);
  }, [detail, workspace]);

  async function saveProfile() {
    if (!form.first_name.trim() || !form.last_name.trim()) {
      setError("Ime i prezime su obavezni.");
      return;
    }
    if (!!form.passport_number.trim() !== !!form.passport_expiry_date) {
      setError("Broj pasoša i datum važenja moraju biti uneti zajedno.");
      return;
    }
    if (form.shoe_size && (!Number.isInteger(Number(form.shoe_size)) || Number(form.shoe_size) < 15 || Number(form.shoe_size) > 55)) {
      setError("Broj obuće mora biti ceo broj od 15 do 55.");
      return;
    }
    setIsSaving(true);
    setError("");
    setMessage("");
    const membership = context?.memberships[0];
    const { error: saveError } = isGuardian && membership
      ? await getSupabaseClient().rpc("auth_update_guardian_profile", {
          p_society_id: membership.society_id,
          p_profile: form
        })
      : await getSupabaseClient().rpc("auth_update_my_profile", {
          p_profile: form
        });
    if (saveError) {
      setError(saveError.message || "Podaci nisu sačuvani.");
      setIsSaving(false);
      return;
    }
    await loadProfile();
    setIsEditing(false);
    setMessage("Lični podaci su sačuvani.");
    setIsSaving(false);
  }

  function changeTab(tab: Tab) {
    if (isEditing && tab !== activeTab) {
      const confirmed = window.confirm("Imate nesačuvane izmene. Da li želite da ih odbacite?");
      if (!confirmed) return;
      if (detail) setForm(toForm(detail.person));
      setIsEditing(false);
    }
    setActiveTab(tab);
    setError("");
    setMessage("");
  }

  if (isLoading) {
    return <section className="card dashboard-card">Učitavanje ličnih podataka...</section>;
  }
  if (!detail || !context) {
    return <section className="card dashboard-card"><p className="alert alert-error">{error}</p></section>;
  }

  const person = detail.person;
  const membership = context.memberships[0];
  const completion = Math.round(((8 - missingFields.length) / 8) * 100);
  const passportState = person.passport_number
    ? `Važi do ${formatDate(person.passport_expiry_date)}`
    : "Nije unet";

  return (
    <>
      <section className="card my-data-hero">
        <div className="my-data-avatar" aria-hidden="true">{initials(person)}</div>
        <div className="my-data-identity">
          <p className="eyebrow">Moji podaci</p>
          <h1>{person.first_name} {person.last_name}</h1>
          <p>{person.email ?? context.email} · {valueOrEmpty(person.phone)}</p>
          <div className="my-data-badges">
            <span className="master-status active">
              {isGuardian ? "RODITELJ / STARATELJ" : "AKTIVAN ČLAN"}
            </span>
            <span className={`my-data-completion ${completion === 100 ? "complete" : ""}`}>
              Profil {completion}%
            </span>
          </div>
        </div>
        <button
          className="button button-primary"
          onClick={() => { setActiveTab("personal"); setIsEditing(true); }}
          type="button"
        >
          IZMENI PODATKE
        </button>
      </section>

      {message && <p className="alert alert-success">{message}</p>}
      {error && <p className="alert alert-error">{error}</p>}

      <section className="my-data-summary" aria-label="Pregled profila">
        <article className="card">
          <span>Lični podaci</span>
          <strong>{missingFields.length === 0 ? "Kompletni" : `Nedostaje ${missingFields.length}`}</strong>
          <small>{missingFields.length ? missingFields.slice(0, 2).join(", ") : "Svi obavezni podaci su uneti"}</small>
        </article>
        <article className="card">
          <span>Dokumenta</span>
          <strong>{person.passport_number ? "Pasoš unet" : "Nema pasoša"}</strong>
          <small>{passportState}</small>
        </article>
        <article className="card">
          <span>Društvo</span>
          <strong>{isGuardian ? "Roditeljski pristup" : membership?.functions.join(", ") || "Član"}</strong>
          <small>{isGuardian ? `${guardianChildren.length} povezane dece` : `${sectionNames.length} aktivnih sekcija`}</small>
        </article>
        <article className="card">
          <span>Porodica</span>
          <strong>{isGuardian ? `${guardianChildren.length} dece` : detail.guardians.length ? `${detail.guardians.length} povezanih` : "Pregled porodice"}</strong>
          <small>Roditelji, staratelji i deca</small>
        </article>
      </section>

      <section className="card my-data-panel">
        <nav className="my-data-tabs" aria-label="Delovi ličnog profila">
          {tabs.map((tab) => (
            <button
              className={activeTab === tab.id ? "active" : ""}
              key={tab.id}
              onClick={() => changeTab(tab.id)}
              type="button"
            >
              {tab.label}
            </button>
          ))}
        </nav>

        <div className="my-data-content">
          {activeTab === "personal" && (
            <section>
              <header className="my-data-section-heading">
                <div><p className="eyebrow">Profil</p><h2>Lični i kontakt podaci</h2></div>
                {!isEditing && <button className="button button-secondary" onClick={() => setIsEditing(true)} type="button">IZMENI</button>}
              </header>
              {isEditing ? (
                <div className="my-data-form">
                  {([
                    ["first_name", "Ime"], ["last_name", "Prezime"],
                    ["birth_date", "Datum rođenja"], ["gender", "Pol"],
                    ["phone", "Telefon"], ["shoe_size", "Broj obuće"], ["address", "Adresa"],
                    ["city", "Grad"], ["postal_code", "Poštanski broj"],
                    ["country", "Država"], ["nationality", "Državljanstvo"]
                  ] as Array<[keyof FormValues, string]>).map(([key, label]) => (
                    <label className="form-field" key={key}>
                      <span>{label}</span>
                      {key === "gender" ? (
                        <select className="input" value={form[key]} onChange={(event) => setForm({ ...form, [key]: event.target.value })}>
                          <option value="">Nije izabrano</option><option value="Muško">Muško</option><option value="Žensko">Žensko</option>
                        </select>
                      ) : (
                        <input
                          className="input"
                          type={key === "birth_date" ? "date" : key === "shoe_size" ? "number" : "text"}
                          min={key === "shoe_size" ? 15 : undefined}
                          max={key === "shoe_size" ? 55 : undefined}
                          value={form[key]}
                          onChange={(event) => setForm({ ...form, [key]: event.target.value })}
                        />
                      )}
                    </label>
                  ))}
                  <label className="form-field"><span>Email</span><input className="input" disabled value={person.email ?? context.email} /></label>
                  <p className="my-data-note">Promena email adrese zahteva posebnu potvrdu i nije deo ovog obrasca.</p>
                  <div className="my-data-actions">
                    <button className="button button-secondary" disabled={isSaving} onClick={() => { setForm(toForm(person)); setIsEditing(false); }} type="button">OTKAŽI</button>
                    <button className="button button-primary" disabled={isSaving} onClick={() => void saveProfile()} type="button">{isSaving ? "ČUVANJE..." : "SAČUVAJ IZMENE"}</button>
                  </div>
                </div>
              ) : (
                <dl className="my-data-grid">
                  <InfoRow label="Datum rođenja" value={formatDate(person.birth_date)} />
                  <InfoRow label="Pol" value={valueOrEmpty(person.gender)} />
                  <InfoRow label="Adresa" value={valueOrEmpty(person.address)} />
                  <InfoRow label="Mesto" value={[person.postal_code, person.city].filter(Boolean).join(" ") || "Nije uneto"} />
                  <InfoRow label="Država" value={valueOrEmpty(person.country)} />
                  <InfoRow label="Državljanstvo" value={valueOrEmpty(person.nationality)} />
                  <InfoRow label="Telefon" value={valueOrEmpty(person.phone)} />
                  <InfoRow label="Broj obuće" value={person.shoe_size ? String(person.shoe_size) : "Nije uneto"} />
                  <InfoRow label="Email" value={person.email ?? context.email} />
                </dl>
              )}
            </section>
          )}

          {activeTab === "documents" && (
            <section>
              <header className="my-data-section-heading"><div><p className="eyebrow">Identifikacija</p><h2>Lična dokumenta</h2></div><button className="button button-secondary" onClick={() => setIsEditing(true)} type="button">IZMENI</button></header>
              {isEditing ? (
                <div className="my-data-form">
                  {([
                    ["jmbg", "JMBG"], ["passport_number", "Broj pasoša"],
                    ["passport_issuing_country", "Država izdavanja"],
                    ["passport_expiry_date", "Pasoš važi do"]
                  ] as Array<[keyof FormValues, string]>).map(([key, label]) => (
                    <label className="form-field" key={key}><span>{label}</span><input className="input" type={key === "passport_expiry_date" ? "date" : "text"} value={form[key]} onChange={(event) => setForm({ ...form, [key]: event.target.value })} /></label>
                  ))}
                  <div className="my-data-actions"><button className="button button-secondary" onClick={() => { setForm(toForm(person)); setIsEditing(false); }} type="button">OTKAŽI</button><button className="button button-primary" onClick={() => void saveProfile()} type="button">SAČUVAJ IZMENE</button></div>
                </div>
              ) : (
                <dl className="my-data-grid">
                  <InfoRow label="JMBG" value={valueOrEmpty(person.jmbg)} />
                  <InfoRow label="Broj pasoša" value={valueOrEmpty(person.passport_number)} />
                  <InfoRow label="Država izdavanja" value={valueOrEmpty(person.passport_issuing_country)} />
                  <InfoRow label="Važi do" value={formatDate(person.passport_expiry_date)} />
                  <InfoRow label="Saglasnost za putovanje" value={person.parental_travel_consent ? "Evidentirana kod predsednika" : "Nije evidentirana"} />
                  <InfoRow label="Saglasnost važi do" value={formatDate(person.parental_travel_consent_valid_until)} />
                </dl>
              )}
              <p className="my-data-note">Saglasnost za putovanje evidentira predsednik nakon fizičke dostave dokumenta.</p>
            </section>
          )}

          {activeTab === "society" && (
            <section>
              <header className="my-data-section-heading"><div><p className="eyebrow">Članstvo</p><h2>Podaci u društvu</h2></div></header>
              <dl className="my-data-grid">
                <InfoRow label="Društvo" value={workspace?.society.name ?? membership?.society_name ?? "Nije dostupno"} />
                {isGuardian ? (
                  <>
                    <InfoRow label="Vrsta pristupa" value="Roditelj / staratelj" />
                    <InfoRow label="Povezana deca" value={guardianChildren.map((child) => `${child.person.first_name} ${child.person.last_name}`).join(", ") || "Nema povezane dece"} />
                    <InfoRow label="Opseg" value="Samo podaci povezane dece" />
                  </>
                ) : detail.member ? (
                  <>
                    <InfoRow label="Status članstva" value={detail.member.status === "ACTIVE" ? "Aktivan član" : detail.member.status} />
                    <InfoRow label="Početak članstva" value={formatDate(detail.member.start_date)} />
                    <InfoRow label="Funkcije" value={membership?.functions.join(", ") || "Član"} />
                    <InfoRow label="Sekcije" value={sectionNames.join(", ") || "Nema aktivnih sekcija"} />
                    <InfoRow label="Članarina" value={detail.member.membership_fee_required ? "Obračunava se" : "Ne obračunava se"} />
                  </>
                ) : null}
              </dl>
              <p className="my-data-note">Ove podatke uređuje predsednik društva.</p>
            </section>
          )}

          {activeTab === "family" && (
            <section>
              <header className="my-data-section-heading"><div><p className="eyebrow">Porodica</p><h2>Povezane osobe</h2></div></header>
              {isGuardian ? guardianChildren.map((child) => {
                const childSections = workspace?.sections
                  .filter((section) => child.section_ids.includes(section.id))
                  .map((section) => section.name) ?? [];
                return (
                  <article className="my-data-family-card" key={child.person.id}>
                    <strong>{child.person.first_name} {child.person.last_name}</strong>
                    <span>{child.member.status === "ACTIVE" ? "Aktivan član" : child.member.status}</span>
                    <small>{childSections.join(", ") || "Nema aktivnih sekcija"}</small>
                  </article>
                );
              }) : detail.guardians.length ? detail.guardians.map(({ person: guardian }) => (
                <article className="my-data-family-card" key={guardian.id}><strong>{guardian.first_name} {guardian.last_name}</strong><span>Roditelj / staratelj</span><small>{guardian.email ?? "Email nije unet"} · {guardian.phone ?? "Telefon nije unet"}</small></article>
              )) : <p className="my-data-empty">Na ovom profilu nema povezanih porodičnih osoba.</p>}
            </section>
          )}

          {activeTab === "security" && (
            <section>
              <header className="my-data-section-heading"><div><p className="eyebrow">Nalog</p><h2>Bezbednost</h2></div></header>
              <dl className="my-data-grid">
                <InfoRow label="Email naloga" value={context.email} />
                <InfoRow label="Status" value="Prijavljen nalog" />
              </dl>
              <button className="button button-secondary" onClick={() => void getSupabaseClient().auth.resetPasswordForEmail(context.email, { redirectTo: `${window.location.origin}/auth/reset-password` })} type="button">POŠALJI LINK ZA PROMENU LOZINKE</button>
              <p className="my-data-note">Link za promenu lozinke biće poslat na email adresu naloga.</p>
            </section>
          )}
        </div>
      </section>
    </>
  );
}
