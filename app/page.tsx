"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import {
  getAuthBootstrapStatus,
  MASTER_ADMIN_EMAIL,
  type AuthBootstrapStatus
} from "./_lib/auth";
import { getSupabaseClient } from "./_lib/supabaseClient";

type AuthMode =
  | "LOGIN"
  | "REGISTER_MASTER"
  | "REGISTER_SOCIETY_USER"
  | "CHOOSE_REGISTRATION"
  | "RESET_PASSWORD";

export default function LoginPage() {
  const router = useRouter();
  const [mode, setMode] = useState<AuthMode>("LOGIN");
  const [bootstrap, setBootstrap] = useState<AuthBootstrapStatus | null>(null);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [isWorking, setIsWorking] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  useEffect(() => {
    let active = true;

    async function load() {
      try {
        const status = await getAuthBootstrapStatus();
        if (active) {
          setBootstrap(status);
        }
      } catch (loadError) {
        if (active) {
          setError(
            loadError instanceof Error
              ? loadError.message
              : "Auth status nije moguće učitati."
          );
        }
      }
    }

    void load();
    return () => {
      active = false;
    };
  }, []);

  function clearFeedback() {
    setError("");
    setMessage("");
  }

  async function handleLogin(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    clearFeedback();
    setIsWorking(true);

    try {
      const supabase = getSupabaseClient();
      const { error: signInError } = await supabase.auth.signInWithPassword({
        email: email.trim().toLowerCase(),
        password
      });

      if (signInError) {
        throw signInError;
      }

      const { data: destination, error: destinationError } =
        await supabase.rpc("auth_get_login_destination");

      if (destinationError || !destination) {
        await supabase.auth.signOut();
        throw destinationError ?? new Error("Pristup nalogu nije određen.");
      }

      router.replace(destination.destination);
    } catch (loginError) {
      setError(
        loginError instanceof Error
          ? loginError.message
          : "Prijavljivanje nije uspelo."
      );
    } finally {
      setIsWorking(false);
    }
  }

  async function handleMasterRegistration(
    event: React.FormEvent<HTMLFormElement>
  ) {
    event.preventDefault();
    clearFeedback();

    if (password.length < 10) {
      setError("Lozinka mora imati najmanje 10 karaktera.");
      return;
    }

    if (password !== confirmPassword) {
      setError("Lozinka i potvrda lozinke nisu iste.");
      return;
    }

    setIsWorking(true);

    try {
      const supabase = getSupabaseClient();
      const callbackUrl = `${window.location.origin}/auth/callback`;
      const { error: signUpError } = await supabase.auth.signUp({
        email: MASTER_ADMIN_EMAIL,
        password,
        options: {
          emailRedirectTo: callbackUrl
        }
      });

      if (signUpError) {
        throw signUpError;
      }

      setMessage(
        "Aktivacioni link je poslat. Otvorite email i potvrdite Master admin nalog."
      );
      setPassword("");
      setConfirmPassword("");
    } catch (registrationError) {
      setError(
        registrationError instanceof Error
          ? registrationError.message
          : "Registracija Master admina nije uspela."
      );
    } finally {
      setIsWorking(false);
    }
  }

  async function handleSocietyUserRegistration(
    event: React.FormEvent<HTMLFormElement>
  ) {
    event.preventDefault();
    clearFeedback();
    if (password.length < 10) {
      setError("Lozinka mora imati najmanje 10 karaktera.");
      return;
    }
    if (password !== confirmPassword) {
      setError("Lozinka i potvrda lozinke nisu iste.");
      return;
    }
    setIsWorking(true);
    try {
      const callbackUrl =
        `${window.location.origin}/auth/callback?next=/auth/activate-account`;
      const { error: signUpError } = await getSupabaseClient().auth.signUp({
        email: email.trim().toLowerCase(),
        password,
        options: { emailRedirectTo: callbackUrl }
      });
      if (signUpError) throw signUpError;
      setMessage(
        "Ako ste prethodno evidentirani, poslat je link za aktiviranje naloga."
      );
      setPassword("");
      setConfirmPassword("");
    } catch {
      setMessage(
        "Ako ste prethodno evidentirani, poslat je link za aktiviranje naloga."
      );
    } finally {
      setIsWorking(false);
    }
  }

  async function handlePasswordReset(
    event: React.FormEvent<HTMLFormElement>
  ) {
    event.preventDefault();
    clearFeedback();
    setIsWorking(true);

    try {
      const supabase = getSupabaseClient();
      const callbackUrl =
        `${window.location.origin}/auth/callback?next=/auth/reset-password`;
      const { error: resetError } = await supabase.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        { redirectTo: callbackUrl }
      );

      if (resetError) {
        throw resetError;
      }

      setMessage(
        "Ako nalog postoji, poslat je link za postavljanje nove lozinke."
      );
    } catch {
      setMessage(
        "Ako nalog postoji, poslat je link za postavljanje nove lozinke."
      );
    } finally {
      setIsWorking(false);
    }
  }

  const title =
    mode === "REGISTER_MASTER"
      ? "Aktiviranje sistema"
      : mode === "REGISTER_SOCIETY_USER"
        ? "Aktiviranje evidentiranog naloga"
      : mode === "CHOOSE_REGISTRATION"
        ? "Izaberite vrstu registracije"
      : mode === "RESET_PASSWORD"
        ? "Nova lozinka"
        : "Prijavljivanje";

  return (
    <main className="login-page">
      <section className="card login-card">
        <div className="login-brand">
          <p className="eyebrow">Dobrodošli</p>
          <h1>FOLKLORAŠ</h1>
          <span>{title}</span>
        </div>

        {error ? <div className="auth-message error">{error}</div> : null}
        {message ? <div className="auth-message success">{message}</div> : null}

        {mode === "LOGIN" ? (
          <form className="form-stack" onSubmit={handleLogin}>
            <label className="form-field">
              <span>Email</span>
              <input
                autoComplete="email"
                className="input"
                onChange={(event) => setEmail(event.target.value)}
                placeholder="ime@email.com"
                required
                type="email"
                value={email}
              />
            </label>

            <label className="form-field">
              <span>Lozinka</span>
              <input
                autoComplete="current-password"
                className="input"
                onChange={(event) => setPassword(event.target.value)}
                placeholder="Unesite lozinku"
                required
                type="password"
                value={password}
              />
            </label>

            <button
              className="button button-primary"
              disabled={isWorking}
              type="submit"
            >
              {isWorking ? "Prijavljivanje..." : "Prijavi se"}
            </button>
          </form>
        ) : null}

        {mode === "REGISTER_MASTER" ? (
          <form className="form-stack" onSubmit={handleMasterRegistration}>
            <label className="form-field">
              <span>Master admin email</span>
              <input
                className="input"
                readOnly
                type="email"
                value={MASTER_ADMIN_EMAIL}
              />
            </label>

            <label className="form-field">
              <span>Željena lozinka</span>
              <input
                autoComplete="new-password"
                className="input"
                minLength={10}
                onChange={(event) => setPassword(event.target.value)}
                required
                type="password"
                value={password}
              />
            </label>

            <label className="form-field">
              <span>Potvrdite lozinku</span>
              <input
                autoComplete="new-password"
                className="input"
                minLength={10}
                onChange={(event) => setConfirmPassword(event.target.value)}
                required
                type="password"
                value={confirmPassword}
              />
            </label>

            <button
              className="button button-primary"
              disabled={isWorking}
              type="submit"
            >
              {isWorking ? "Slanje..." : "Pošalji aktivacioni link"}
            </button>
          </form>
        ) : null}

        {mode === "REGISTER_SOCIETY_USER" ? (
          <form className="form-stack" onSubmit={handleSocietyUserRegistration}>
            <label className="form-field">
              <span>Email</span>
              <input
                className="input"
                onChange={(event) => setEmail(event.target.value)}
                required
                type="email"
                value={email}
              />
            </label>
            <label className="form-field">
              <span>Željena lozinka</span>
              <input
                className="input"
                minLength={10}
                onChange={(event) => setPassword(event.target.value)}
                required
                type="password"
                value={password}
              />
            </label>
            <label className="form-field">
              <span>Potvrdite lozinku</span>
              <input
                className="input"
                minLength={10}
                onChange={(event) => setConfirmPassword(event.target.value)}
                required
                type="password"
                value={confirmPassword}
              />
            </label>
            <button className="button button-primary" disabled={isWorking} type="submit">
              {isWorking ? "Slanje..." : "POŠALJI AKTIVACIONI LINK"}
            </button>
          </form>
        ) : null}

        {mode === "RESET_PASSWORD" ? (
          <form className="form-stack" onSubmit={handlePasswordReset}>
            <label className="form-field">
              <span>Email</span>
              <input
                autoComplete="email"
                className="input"
                onChange={(event) => setEmail(event.target.value)}
                required
                type="email"
                value={email}
              />
            </label>

            <button
              className="button button-primary"
              disabled={isWorking}
              type="submit"
            >
              {isWorking ? "Slanje..." : "Pošalji link"}
            </button>
          </form>
        ) : null}

        {mode === "CHOOSE_REGISTRATION" ? (
          <div className="form-stack auth-registration-options">
            <button
              className="button button-primary"
              onClick={() => router.push("/registracija-drustva")}
              type="button"
            >
              Predsednik društva
            </button>
            <button
              className="button button-secondary"
              onClick={() => {
                clearFeedback();
                setMode("REGISTER_SOCIETY_USER");
              }}
              type="button"
            >
              Član ili roditelj / staratelj
            </button>
            <p className="auth-secondary-note">
              Član i roditelj mogu se registrovati tek kada ih predsednik
              prethodno evidentira u društvu.
            </p>
          </div>
        ) : null}

        <div className="login-links">
          {mode === "LOGIN" ? (
            <>
              <button
                className="auth-text-button"
                onClick={() => {
                  clearFeedback();
                  setMode("RESET_PASSWORD");
                }}
                type="button"
              >
                Zaboravljena lozinka?
              </button>

              {bootstrap?.master_admin_registration_available ? (
                <button
                  className="button button-secondary"
                  onClick={() => {
                    clearFeedback();
                    setPassword("");
                    setMode("REGISTER_MASTER");
                  }}
                  type="button"
                >
                  Registracija Master admina
                </button>
              ) : null}

              {bootstrap?.master_admin_active ? (
                <button
                  className="button button-secondary"
                  onClick={() => {
                    clearFeedback();
                    setMode("CHOOSE_REGISTRATION");
                  }}
                  type="button"
                >
                  Registracija novog korisnika
                </button>
              ) : null}
            </>
          ) : (
            <button
              className="auth-text-button"
              onClick={() => {
                clearFeedback();
                setPassword("");
                setConfirmPassword("");
                setMode("LOGIN");
              }}
              type="button"
            >
              Nazad na prijavljivanje
            </button>
          )}
        </div>
      </section>
    </main>
  );
}
