"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { getAuthSessionContext } from "../../_lib/auth";
import { getSupabaseClient } from "../../_lib/supabaseClient";

type MfaMode = "LOADING" | "ENROLL" | "CHALLENGE";

export default function MasterMfaPage() {
  const router = useRouter();
  const initializationStarted = useRef(false);
  const [mode, setMode] = useState<MfaMode>("LOADING");
  const [factorId, setFactorId] = useState("");
  const [qrCode, setQrCode] = useState("");
  const [secret, setSecret] = useState("");
  const [verificationCode, setVerificationCode] = useState("");
  const [error, setError] = useState("");
  const [isWorking, setIsWorking] = useState(false);

  useEffect(() => {
    if (initializationStarted.current) {
      return;
    }
    initializationStarted.current = true;

    async function initialize() {
      const supabase = getSupabaseClient();

      try {
        const { data: userData, error: userError } =
          await supabase.auth.getUser();

        if (userError || !userData.user) {
          router.replace("/prijava");
          return;
        }

        const context = await getAuthSessionContext();

        if (!context.is_allowed_master_email && !context.is_master_admin) {
          throw new Error(
            "Ovaj Auth V1 korak je trenutno dostupan samo Master adminu."
          );
        }

        const { data: aalData, error: aalError } =
          await supabase.auth.mfa.getAuthenticatorAssuranceLevel();

        if (aalError) {
          throw aalError;
        }

        if (context.is_master_admin && aalData.currentLevel === "aal2") {
          router.replace("/dashboard");
          return;
        }

        const { data: factorsData, error: factorsError } =
          await supabase.auth.mfa.listFactors();

        if (factorsError) {
          throw factorsError;
        }

        const verifiedFactor = factorsData.totp.find(
          (factor) => factor.status === "verified"
        );

        if (verifiedFactor) {
          setFactorId(verifiedFactor.id);
          setMode("CHALLENGE");
          return;
        }

        for (const factor of factorsData.totp) {
          if (factor.status !== "verified") {
            await supabase.auth.mfa.unenroll({ factorId: factor.id });
          }
        }

        const { data: enrollData, error: enrollError } =
          await supabase.auth.mfa.enroll({
            factorType: "totp",
            friendlyName: "FOLKLORAŠ Master admin"
          });

        if (enrollError) {
          throw enrollError;
        }

        setFactorId(enrollData.id);
        setQrCode(enrollData.totp.qr_code);
        setSecret(enrollData.totp.secret);
        setMode("ENROLL");
      } catch (initializationError) {
        setError(
          initializationError instanceof Error
            ? initializationError.message
            : "MFA podešavanje nije moguće učitati."
        );
      }
    }

    void initialize();
  }, [router]);

  async function verifyCode(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");

    if (!/^\d{6}$/.test(verificationCode.trim())) {
      setError("Unesite važeći šestocifreni kod.");
      return;
    }

    setIsWorking(true);

    try {
      const supabase = getSupabaseClient();
      const { data: challengeData, error: challengeError } =
        await supabase.auth.mfa.challenge({ factorId });

      if (challengeError) {
        throw challengeError;
      }

      const { error: verifyError } = await supabase.auth.mfa.verify({
        factorId,
        challengeId: challengeData.id,
        code: verificationCode.trim()
      });

      if (verifyError) {
        throw verifyError;
      }

      const { error: bootstrapError } = await supabase.rpc(
        "auth_bootstrap_master_admin"
      );

      if (bootstrapError) {
        throw bootstrapError;
      }

      router.replace("/dashboard");
    } catch (verificationError) {
      setError(
        verificationError instanceof Error
          ? verificationError.message
          : "Kod nije potvrđen."
      );
    } finally {
      setIsWorking(false);
    }
  }

  return (
    <main className="login-page">
      <section className="card login-card mfa-card">
        <div className="login-brand">
          <p className="eyebrow">Master admin</p>
          <h1>Zaštita naloga</h1>
          <span>Dvofaktorska autentifikacija</span>
        </div>

        {error ? <div className="auth-message error">{error}</div> : null}

        {mode === "LOADING" && !error ? (
          <p className="auth-center">Učitavanje bezbednosnog koraka...</p>
        ) : null}

        {mode === "ENROLL" ? (
          <div className="mfa-enrollment">
            <p>
              Skenirajte QR kod aplikacijom Google Authenticator, Microsoft
              Authenticator ili drugom TOTP aplikacijom.
            </p>

            {qrCode ? (
              <img
                alt="QR kod za Master admin dvofaktorsku autentifikaciju"
                className="mfa-qr"
                src={qrCode}
              />
            ) : null}

            <details>
              <summary>Ne mogu da skeniram QR kod</summary>
              <code className="mfa-secret">{secret}</code>
            </details>
          </div>
        ) : null}

        {mode !== "LOADING" ? (
          <form className="form-stack" onSubmit={verifyCode}>
            <label className="form-field">
              <span>Šestocifreni kod</span>
              <input
                autoComplete="one-time-code"
                className="input"
                inputMode="numeric"
                maxLength={6}
                onChange={(event) =>
                  setVerificationCode(event.target.value.replace(/\D/g, ""))
                }
                pattern="\d{6}"
                required
                value={verificationCode}
              />
            </label>

            <button
              className="button button-primary"
              disabled={isWorking}
              type="submit"
            >
              {isWorking
                ? "Provera..."
                : mode === "ENROLL"
                  ? "Aktiviraj zaštitu"
                  : "Potvrdi kod"}
            </button>
          </form>
        ) : null}

        <button
          className="auth-text-button"
          onClick={async () => {
            await getSupabaseClient().auth.signOut();
            router.replace("/prijava");
          }}
          type="button"
        >
          Odustani i odjavi se
        </button>
      </section>
    </main>
  );
}
