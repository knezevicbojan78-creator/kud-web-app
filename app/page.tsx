"use client";

import { useRouter } from "next/navigation";

export default function LoginPage() {
  const router = useRouter();

  return (
    <main className="login-page">
      <section className="card login-card">
        <div className="login-brand">
          <p className="eyebrow">Dobrodošli</p>
          <h1>FOLKLORAŠ</h1>
          <span>KUD Mitanče</span>
        </div>

        <form
          className="form-stack"
          onSubmit={(event) => {
            event.preventDefault();
            router.push("/dashboard");
          }}
        >
          <label className="form-field">
            <span>Email</span>
            <input className="input" type="email" placeholder="ime@email.com" />
          </label>

          <label className="form-field">
            <span>Lozinka</span>
            <input
              className="input"
              type="password"
              placeholder="Unesite lozinku"
            />
          </label>

          <button className="button button-primary" type="submit">
            Prijavi se
          </button>
        </form>

        <div className="login-links">
          <a href="#">Zaboravljena lozinka?</a>
          <a className="button button-secondary" href="#">
            Registracija društva
          </a>
        </div>
      </section>
    </main>
  );
}
