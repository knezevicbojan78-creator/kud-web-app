"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import {
  DEFAULT_TEST_ROLE,
  TEST_ROLE_STORAGE_KEY,
  TEST_ROLES,
  type TestRole
} from "./_lib/testRoles";

export default function LoginPage() {
  const router = useRouter();
  const [selectedRole, setSelectedRole] =
    useState<TestRole>(DEFAULT_TEST_ROLE);

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
            localStorage.setItem(TEST_ROLE_STORAGE_KEY, selectedRole);
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

          <label className="form-field">
            <span>Test uloga</span>
            <select
              className="input"
              value={selectedRole}
              onChange={(event) =>
                setSelectedRole(event.target.value as TestRole)
              }
            >
              {TEST_ROLES.map((role) => (
                <option key={role} value={role}>
                  {role}
                </option>
              ))}
            </select>
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
