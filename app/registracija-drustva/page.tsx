"use client";

import Link from "next/link";
import { useEffect, useState, type FormEvent } from "react";
import {
  getSupabaseClient,
  type PublicLicensePlan
} from "../_lib/supabaseClient";

type FormValues = {
  societyName: string;
  address: string;
  city: string;
  country: string;
  pib: string;
  registrationNumber: string;
  presidentFirstName: string;
  presidentLastName: string;
  presidentEmail: string;
  presidentPhone: string;
  consent: boolean;
};

type TextField = Exclude<keyof FormValues, "consent">;
type FormErrors = Partial<Record<keyof FormValues, string>>;

const initialValues: FormValues = {
  societyName: "",
  address: "",
  city: "",
  country: "Srbija",
  pib: "",
  registrationNumber: "",
  presidentFirstName: "",
  presidentLastName: "",
  presidentEmail: "",
  presidentPhone: "",
  consent: false
};

const fields: Array<{
  key: TextField;
  label: string;
  section: "society" | "president";
  type?: "email" | "tel";
}> = [
  { key: "societyName", label: "Naziv društva", section: "society" },
  { key: "address", label: "Adresa", section: "society" },
  { key: "city", label: "Grad", section: "society" },
  { key: "country", label: "Država", section: "society" },
  { key: "pib", label: "PIB", section: "society" },
  { key: "registrationNumber", label: "Matični broj", section: "society" },
  { key: "presidentFirstName", label: "Ime predsednika", section: "president" },
  { key: "presidentLastName", label: "Prezime predsednika", section: "president" },
  { key: "presidentEmail", label: "Email predsednika", section: "president", type: "email" },
  { key: "presidentPhone", label: "Telefon predsednika", section: "president", type: "tel" }
];

function validate(values: FormValues) {
  const errors: FormErrors = {};
  fields.forEach(({ key }) => {
    if (values[key].trim().length < 2) errors[key] = "Ovo polje je obavezno.";
  });
  if (values.presidentEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(values.presidentEmail)) {
    errors.presidentEmail = "Unesite ispravnu email adresu.";
  }
  if (!values.consent) errors.consent = "Potvrdite tačnost podataka.";
  return errors;
}

export default function RegistracijaDrustvaPage() {
  const [values, setValues] = useState(initialValues);
  const [errors, setErrors] = useState<FormErrors>({});
  const [message, setMessage] = useState("");
  const [submitError, setSubmitError] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [licensePlans, setLicensePlans] = useState<PublicLicensePlan[]>([]);
  const [requestedLicensePlanId, setRequestedLicensePlanId] = useState("");
  const [requestedLicenseKind, setRequestedLicenseKind] = useState<
    "MONTHLY" | "ANNUAL"
  >("MONTHLY");

  useEffect(() => {
    let active = true;
    async function loadPlans() {
      const { data, error } = await getSupabaseClient().rpc(
        "auth_get_public_license_plans"
      );
      if (!active) return;
      if (error) {
        setSubmitError("Licencni paketi trenutno nisu dostupni.");
      } else {
        setLicensePlans(data ?? []);
      }
    }
    void loadPlans();
    return () => {
      active = false;
    };
  }, []);

  function updateText(key: TextField, value: string) {
    setValues((current) => ({ ...current, [key]: value }));
    setErrors((current) => ({ ...current, [key]: undefined }));
    setSubmitError("");
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const nextErrors = validate(values);
    setErrors(nextErrors);
    setMessage("");
    setSubmitError("");
    if (!requestedLicensePlanId) {
      setSubmitError("Izaberite licencni paket.");
      return;
    }
    if (Object.keys(nextErrors).length > 0) return;

    setIsSubmitting(true);
    const { error } = await getSupabaseClient().rpc("auth_submit_president_request", {
      p_society_name: values.societyName,
      p_address: values.address,
      p_city: values.city,
      p_country: values.country,
      p_pib: values.pib,
      p_registration_number: values.registrationNumber,
      p_president_first_name: values.presidentFirstName,
      p_president_last_name: values.presidentLastName,
      p_president_email: values.presidentEmail.trim().toLowerCase(),
      p_president_phone: values.presidentPhone,
      p_requested_license_plan_id: requestedLicensePlanId,
      p_requested_license_kind: requestedLicenseKind
    });

    if (error) {
      setSubmitError(error.message || "Zahtev nije poslat.");
    } else {
      setValues(initialValues);
      setRequestedLicensePlanId("");
      setRequestedLicenseKind("MONTHLY");
      setMessage("Zahtev je poslat Master adminu. Nakon odobrenja dobićete aktivacioni link za postavljanje lozinke.");
    }
    setIsSubmitting(false);
  }

  function renderFields(section: "society" | "president") {
    return fields.filter((field) => field.section === section).map((field) => (
      <label className="form-field" key={field.key}>
        <span>{field.label} *</span>
        <input
          autoComplete={field.key === "presidentEmail" ? "email" : field.key === "presidentPhone" ? "tel" : undefined}
          className="input"
          onChange={(event) => updateText(field.key, event.target.value)}
          type={field.type ?? "text"}
          value={values[field.key]}
        />
        {errors[field.key] ? <small>{errors[field.key]}</small> : null}
      </label>
    ));
  }

  return (
    <main className="login-page">
      <section className="card login-card auth-request-card">
        <div className="login-brand">
          <p className="eyebrow">Novi korisnik</p>
          <h1>Registracija predsednika</h1>
          <span>Pošaljite osnovne podatke društva na odobrenje</span>
        </div>

        {message ? (
          <section className="auth-request-complete" role="status">
            <div className="auth-message success">{message}</div>
            <p>
              Nije potrebno ponovo slati podatke. Zahtev sada čeka odluku
              Master admina.
            </p>
            <Link className="button button-primary" href="/">
              Nazad na prijavljivanje
            </Link>
          </section>
        ) : (
          <>
            {submitError ? (
              <div className="auth-message error">{submitError}</div>
            ) : null}

            <form className="form-stack" noValidate onSubmit={handleSubmit}>
          <fieldset className="auth-request-section">
            <legend>Osnovni podaci o društvu</legend>
            <div className="auth-request-grid">{renderFields("society")}</div>
          </fieldset>

          <fieldset className="auth-request-section">
            <legend>Predsednik društva</legend>
            <div className="auth-request-grid">{renderFields("president")}</div>
          </fieldset>

          <fieldset className="auth-request-section">
            <legend>Željeni licencni paket</legend>
            <div className="license-cycle-options">
              <button
                className={requestedLicenseKind === "MONTHLY" ? "selected" : ""}
                onClick={() => setRequestedLicenseKind("MONTHLY")}
                type="button"
              >
                <strong>Mesečna licenca</strong>
                <span>Obnavlja se svakog meseca</span>
              </button>
              <button
                className={requestedLicenseKind === "ANNUAL" ? "selected" : ""}
                onClick={() => setRequestedLicenseKind("ANNUAL")}
                type="button"
              >
                <strong>Godišnja licenca</strong>
                <span>Povoljnija uplata za 12 meseci</span>
              </button>
            </div>
            <div className="license-request-options">
              {licensePlans.map((plan) => (
                <label
                  className={
                    requestedLicensePlanId === plan.id
                      ? "license-request-option selected"
                      : "license-request-option"
                  }
                  key={plan.id}
                >
                  <input
                    checked={requestedLicensePlanId === plan.id}
                    name="license-plan"
                    onChange={() => {
                      setRequestedLicensePlanId(plan.id);
                      setSubmitError("");
                    }}
                    type="radio"
                  />
                  <span>
                    <strong>{plan.name}</strong>
                    <small>{plan.description}</small>
                    <small>
                      {requestedLicenseKind === "ANNUAL"
                        ? `${plan.annual_price} ${plan.currency} godišnje`
                        : `${plan.monthly_price} ${plan.currency} mesečno`}
                    </small>
                  </span>
                </label>
              ))}
            </div>
            <p className="auth-secondary-note">
              Ovo je zahtevani paket. Master admin ga potvrđuje pri odobravanju
              naloga i obaveznoj dodeli licence.
            </p>
          </fieldset>

          <label className="auth-consent">
            <input
              checked={values.consent}
              onChange={(event) => {
                setValues((current) => ({ ...current, consent: event.target.checked }));
                setErrors((current) => ({ ...current, consent: undefined }));
              }}
              type="checkbox"
            />
            <span>Potvrđujem da su uneti podaci tačni.</span>
          </label>
          {errors.consent ? <small className="auth-field-error">{errors.consent}</small> : null}

          <button className="button button-primary" disabled={isSubmitting} type="submit">
            {isSubmitting ? "Slanje..." : "Pošalji zahtev"}
          </button>
              <Link className="auth-text-button auth-centered-link" href="/">
                Nazad na prijavljivanje
              </Link>
            </form>
          </>
        )}
      </section>
    </main>
  );
}
