"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { getSupabaseClient } from "../../_lib/supabaseClient";

export default function ResetPasswordPage() {
  const router = useRouter();
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [error, setError] = useState("");
  const [isWorking, setIsWorking] = useState(false);

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");

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
      const { error: updateError } = await supabase.auth.updateUser({ password });

      if (updateError) {
        throw updateError;
      }

      await supabase.auth.signOut();
      router.replace("/");
    } catch (updatePasswordError) {
      setError(
        updatePasswordError instanceof Error
          ? updatePasswordError.message
          : "Lozinku nije moguće promeniti."
      );
    } finally {
      setIsWorking(false);
    }
  }

  return (
    <main className="login-page">
      <section className="card login-card">
        <div className="login-brand">
          <h1>FOLKLORAŠ</h1>
          <span>Postavljanje nove lozinke</span>
        </div>

        {error ? <div className="auth-message error">{error}</div> : null}

        <form className="form-stack" onSubmit={handleSubmit}>
          <label className="form-field">
            <span>Nova lozinka</span>
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
            <span>Potvrdite novu lozinku</span>
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
            {isWorking ? "Čuvanje..." : "Sačuvaj novu lozinku"}
          </button>
        </form>
      </section>
    </main>
  );
}
