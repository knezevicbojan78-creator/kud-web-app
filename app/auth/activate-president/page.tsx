"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { getSupabaseClient } from "../../_lib/supabaseClient";

export default function ActivatePresidentPage() {
  const router = useRouter();
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [isWorking, setIsWorking] = useState(false);

  async function activate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setMessage("");

    if (password.length < 10) {
      setError("Lozinka mora imati najmanje 10 karaktera.");
      return;
    }
    if (password !== confirmPassword) {
      setError("Lozinka i potvrda lozinke nisu iste.");
      return;
    }

    setIsWorking(true);
    const supabase = getSupabaseClient();
    const { error: passwordError } = await supabase.auth.updateUser({
      password
    });

    if (passwordError) {
      setError(passwordError.message);
      setIsWorking(false);
      return;
    }

    const { data, error: activationError } = await supabase.rpc(
      "auth_activate_approved_president"
    );

    if (activationError || !data) {
      setError(activationError?.message || "Predsednički nalog nije povezan.");
    } else {
      setPassword("");
      setConfirmPassword("");
      router.replace("/auth/president-onboarding");
    }
    setIsWorking(false);
  }

  return (
    <main className="login-page">
      <section className="card login-card">
        <div className="login-brand">
          <p className="eyebrow">Aktivacija predsednika</p>
          <h1>Postavite lozinku</h1>
          <span>Aktivacioni link je potvrdio vaš email</span>
        </div>

        {error ? <div className="auth-message error">{error}</div> : null}
        {message ? (
          <section className="auth-request-complete">
            <div className="auth-message success">{message}</div>
            <p>
              Ekran za obavezni onboarding biće sledeći korak implementacije.
            </p>
          </section>
        ) : (
          <form className="form-stack" onSubmit={activate}>
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
              {isWorking ? "Aktiviranje..." : "Aktiviraj nalog"}
            </button>
          </form>
        )}
      </section>
    </main>
  );
}
