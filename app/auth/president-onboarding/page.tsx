"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import {
  SocietyDataForm,
  type SocietyDataField,
  type SocietyDataFormValues
} from "../../_components/SocietyDataForm";
import {
  UF_MEMBER_FORM,
  type UFMemberFormErrors,
  type UFMemberFormField,
  type UFMemberFormValues,
  type UFMemberGuardianField
} from "../../_components/UF_MEMBER_FORM";
import { getSupabaseClient } from "../../_lib/supabaseClient";

type Step = "SOCIETY" | "PRESIDENT" | "REVIEW" | "COMPLETED";

const emptySociety: SocietyDataFormValues = {
  societyName: "",
  address: "",
  city: "",
  postalCode: "",
  country: "Srbija",
  pib: "",
  registrationNumber: "",
  bankAccount: "",
  licenseType: ""
};

const emptyGuardian = { first_name: "", last_name: "", email: "", phone: "" };

function initialProfile(): UFMemberFormValues {
  const today = new Date().toISOString().slice(0, 10);
  return {
    is_minor_member: false,
    first_name: "",
    last_name: "",
    gender: "",
    birth_date: "",
    address: "",
    city: "",
    postal_code: "",
    country: "Srbija",
    jmbg: "",
    passport_number: "",
    passport_expiry_date: "",
    parental_travel_consent: false,
    parental_travel_consent_valid_until: "",
    email: "",
    phone: "",
    shoe_size: "",
    status: "ACTIVE",
    start_date: today,
    membership_fee_required: false,
    membership_fee_amount: "",
    guardian1: { ...emptyGuardian },
    guardian2: { ...emptyGuardian },
    showGuardian2: false,
    selectedFunctionIds: [],
    selectedSectionIds: []
  };
}

export default function PresidentOnboardingPage() {
  const router = useRouter();
  const [step, setStep] = useState<Step>("SOCIETY");
  const [societyId, setSocietyId] = useState("");
  const [society, setSociety] = useState(emptySociety);
  const [profile, setProfile] = useState(initialProfile);
  const [societyErrors, setSocietyErrors] = useState<
    Partial<Record<SocietyDataField, string>>
  >({});
  const [profileErrors, setProfileErrors] = useState<UFMemberFormErrors>({});
  const [error, setError] = useState("");
  const [isWorking, setIsWorking] = useState(true);

  useEffect(() => {
    async function load() {
      const { data, error: loadError } = await getSupabaseClient().rpc(
        "auth_get_president_onboarding"
      );
      if (loadError || !data) {
        setError(loadError?.message || "Onboarding nije moguće učitati.");
        setIsWorking(false);
        return;
      }

      if (data.state.completed) {
        setStep("COMPLETED");
      } else if (data.state.society_profile_completed) {
        setStep("PRESIDENT");
      }

      setSocietyId(data.society.id);
      setSociety({
        societyName: data.society.name,
        address: data.society.address,
        city: data.society.city,
        postalCode: data.society.postal_code ?? "",
        country: data.society.country,
        pib: data.society.pib,
        registrationNumber: data.society.registration_number,
        bankAccount: data.society.bank_account ?? "",
        licenseType: data.society.license_type ?? ""
      });
      setProfile((current) => ({
        ...current,
        first_name: data.president.first_name,
        last_name: data.president.last_name,
        email: data.president.email,
        phone: data.president.phone,
        address: data.society.address,
        city: data.society.city,
        postal_code: data.society.postal_code ?? "",
        country: data.society.country
      }));
      setIsWorking(false);
    }
    void load();
  }, []);

  function updateSociety(field: SocietyDataField, value: string) {
    setSociety((current) => ({ ...current, [field]: value }));
    setSocietyErrors((current) => ({ ...current, [field]: undefined }));
  }

  async function saveSociety() {
    const required: SocietyDataField[] = [
      "societyName", "address", "city", "country", "pib", "registrationNumber"
    ];
    const nextErrors: Partial<Record<SocietyDataField, string>> = {};
    required.forEach((field) => {
      if (!society[field].trim()) nextErrors[field] = "Ovo polje je obavezno.";
    });
    setSocietyErrors(nextErrors);
    if (Object.keys(nextErrors).length) return;

    setIsWorking(true);
    setError("");
    const { error: saveError } = await getSupabaseClient().rpc(
      "auth_save_president_society_onboarding",
      {
        p_society: {
          name: society.societyName,
          address: society.address,
          city: society.city,
          postal_code: society.postalCode,
          country: society.country,
          pib: society.pib,
          registration_number: society.registrationNumber,
          bank_account: society.bankAccount
        }
      }
    );
    if (saveError) {
      setError(saveError.message);
    } else {
      setStep("PRESIDENT");
    }
    setIsWorking(false);
  }

  function updateProfile(field: UFMemberFormField | "showGuardian2" | "is_minor_member", value: string | boolean) {
    setProfile((current) => ({ ...current, [field]: value }));
    setProfileErrors((current) => ({ ...current, [field]: undefined }));
  }

  async function completeOnboarding() {
    setIsWorking(true);
    setError("");
    const { error: completeError } = await getSupabaseClient().rpc(
      "auth_complete_president_onboarding",
      {
        p_profile: {
          first_name: profile.first_name,
          last_name: profile.last_name,
          gender: profile.gender,
          birth_date: profile.birth_date,
          address: profile.address,
          city: profile.city,
          postal_code: profile.postal_code,
          country: profile.country,
          jmbg: profile.jmbg,
          passport_number: profile.passport_number,
          passport_expiry_date: profile.passport_expiry_date,
          email: profile.email,
          phone: profile.phone,
          start_date: profile.start_date,
          membership_fee_required: profile.membership_fee_required,
          membership_fee_amount: profile.membership_fee_amount
        }
      }
    );
    if (completeError) {
      setError(completeError.message);
    } else {
      setStep("COMPLETED");
    }
    setIsWorking(false);
  }

  async function signOut() {
    await getSupabaseClient().auth.signOut();
    router.replace("/prijava");
  }

  if (isWorking && !societyId) {
    return <main className="login-page"><section className="card login-card auth-center">Učitavanje onboardinga...</section></main>;
  }

  return (
    <main className="onboarding-page">
      <section className="onboarding-shell">
        <header className="onboarding-header">
          <div>
            <p className="eyebrow">Predsednik društva</p>
            <h1>Početno podešavanje</h1>
          </div>
          <div className="onboarding-progress">
            <span className={step === "SOCIETY" ? "active" : "done"}>1. Društvo</span>
            <span className={step === "PRESIDENT" ? "active" : step === "REVIEW" || step === "COMPLETED" ? "done" : ""}>2. Predsednik</span>
            <span className={step === "REVIEW" ? "active" : step === "COMPLETED" ? "done" : ""}>3. Potvrda</span>
          </div>
        </header>

        {error ? <div className="auth-message error">{error}</div> : null}

        {step === "SOCIETY" ? (
          <section className="card onboarding-card">
            <SocietyDataForm
              errors={societyErrors}
              mode="president"
              onFieldChange={updateSociety}
              values={society}
            />
            <div className="onboarding-actions">
              <button className="auth-text-button" onClick={signOut} type="button">Sačuvaj za kasnije i odjavi se</button>
              <button className="button button-primary" disabled={isWorking} onClick={saveSociety} type="button">
                {isWorking ? "Čuvanje..." : "Sačuvaj i nastavi"}
              </button>
            </div>
          </section>
        ) : null}

        {step === "PRESIDENT" ? (
          <section className="card onboarding-card">
            <UF_MEMBER_FORM
              allowFallbackFunctionOptions={false}
              errors={profileErrors}
              isSubmitting={isWorking}
              mode="president_onboarding"
              onAddSecondGuardian={() => undefined}
              onCancel={() => setStep("SOCIETY")}
              onFieldChange={updateProfile}
              onFunctionToggle={() => undefined}
              onGuardianFieldChange={(
                _guardian: "guardian1" | "guardian2",
                _field: UFMemberGuardianField,
                _value: string
              ) => undefined}
              onRemoveSecondGuardian={() => undefined}
              onSubmit={() => setStep("REVIEW")}
              readOnlyPersonFields={{ email: true }}
              readOnlyFunctions
              readOnlySections
              societyId={societyId}
              values={profile}
            />
          </section>
        ) : null}

        {step === "REVIEW" ? (
          <section className="card onboarding-card">
            <div className="page-heading">
              <p className="eyebrow">Završna potvrda</p>
              <h2>Proverite podatke pre aktiviranja</h2>
              <p>Društvo i licenca biće aktivirani tek kada potvrdite završetak onboardinga.</p>
            </div>
            <div className="onboarding-review-grid">
              <section>
                <p className="eyebrow">Društvo</p>
                <strong>{society.societyName}</strong>
                <p>{society.address}, {society.city}</p>
              </section>
              <section>
                <p className="eyebrow">Predsednik</p>
                <strong>{profile.first_name} {profile.last_name}</strong>
                <p>{profile.email}</p>
              </section>
              <section>
                <p className="eyebrow">Članstvo</p>
                <strong>Aktivno</strong>
                <p>Početak: {profile.start_date.split("-").reverse().join("/")}</p>
              </section>
            </div>
            <div className="onboarding-actions">
              <button className="button button-secondary" disabled={isWorking} onClick={() => setStep("PRESIDENT")} type="button">Nazad na podatke</button>
              <button className="button button-primary" disabled={isWorking} onClick={completeOnboarding} type="button">
                {isWorking ? "Aktiviranje..." : "Završi onboarding i aktiviraj društvo"}
              </button>
            </div>
          </section>
        ) : null}

        {step === "COMPLETED" ? (
          <section className="card login-card auth-center">
            <div className="auth-message success">
              Onboarding je završen. Društvo i licenca su aktivirani.
            </div>
            <p>Možete nastaviti rad u aktiviranom društvu.</p>
            <button className="button button-primary" onClick={() => router.replace("/dashboard")} type="button">
              Otvori dashboard
            </button>
          </section>
        ) : null}
      </section>
    </main>
  );
}
