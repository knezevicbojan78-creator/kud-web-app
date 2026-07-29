"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { getSupabaseClient } from "../../_lib/supabaseClient";

type AccessItem = {
  id: string;
  society_name?: string;
  child_name?: string;
  societies?: string[];
  decision?: "ACCEPTED" | "REJECTED" | null;
};
type Activation = {
  person_name: string;
  memberships: AccessItem[];
  guardian_links: AccessItem[];
};

export default function ActivateAccountPage() {
  const router = useRouter();
  const [data, setData] = useState<Activation | null>(null);
  const [choices, setChoices] = useState<Record<string, boolean>>({});
  const [error, setError] = useState("");
  const [working, setWorking] = useState(false);

  useEffect(() => {
    void (async () => {
      const { data: activation, error: loadError } =
        await getSupabaseClient().rpc("auth_get_account_activation");
      if (loadError || !activation) {
        setError(loadError?.message || "Aktivaciju nije moguće učitati.");
        return;
      }
      const value = activation as Activation;
      setData(value);
      setChoices(Object.fromEntries([
        ...value.memberships.map((item) => [item.id, item.decision !== "REJECTED"]),
        ...value.guardian_links.map((item) => [item.id, item.decision !== "REJECTED"])
      ]));
    })();
  }, []);

  async function complete() {
    if (!data) return;
    setWorking(true);
    setError("");
    const decisions = [
      ...data.memberships.map((item) => ({
        kind: "MEMBERSHIP",
        id: item.id,
        decision: choices[item.id] ? "ACCEPTED" : "REJECTED"
      })),
      ...data.guardian_links.map((item) => ({
        kind: "GUARDIAN_LINK",
        id: item.id,
        decision: choices[item.id] ? "ACCEPTED" : "REJECTED"
      }))
    ];
    const { data: result, error: saveError } = await getSupabaseClient().rpc(
      "auth_complete_account_activation",
      { p_decisions: decisions }
    );
    if (saveError) {
      setError(saveError.message);
      setWorking(false);
      return;
    }
    if (!(result as { has_access?: boolean })?.has_access) {
      await getSupabaseClient().auth.signOut();
      router.replace("/");
      return;
    }
    const { data: destination } =
      await getSupabaseClient().rpc("auth_get_login_destination");
    router.replace(destination?.destination || "/garderoba");
  }

  return (
    <main className="login-page">
      <section className="card login-card">
        <div className="login-brand">
          <p className="eyebrow">Aktiviranje naloga</p>
          <h1>FOLKLORAŠ</h1>
          <span>{data?.person_name || "Provera evidentiranih veza"}</span>
        </div>
        {error ? <div className="auth-message error">{error}</div> : null}
        {!data && !error ? <p>Učitavanje...</p> : null}
        {data ? (
          <div className="form-stack">
            <p>Potvrdite veze koje prepoznajete. Isključene veze biće odbijene.</p>
            {data.memberships.map((item) => (
              <label className="auth-access-choice" key={item.id}>
                <input
                  checked={Boolean(choices[item.id])}
                  onChange={(event) => setChoices((current) => ({
                    ...current,
                    [item.id]: event.target.checked
                  }))}
                  type="checkbox"
                />
                <span><strong>Članstvo</strong><small>{item.society_name}</small></span>
              </label>
            ))}
            {data.guardian_links.map((item) => (
              <label className="auth-access-choice" key={item.id}>
                <input
                  checked={Boolean(choices[item.id])}
                  onChange={(event) => setChoices((current) => ({
                    ...current,
                    [item.id]: event.target.checked
                  }))}
                  type="checkbox"
                />
                <span>
                  <strong>Roditelj/staratelj: {item.child_name}</strong>
                  <small>{item.societies?.join(", ") || "Evidentirana veza"}</small>
                </span>
              </label>
            ))}
            {!data.memberships.length && !data.guardian_links.length ? (
              <div className="auth-message error">Nema veza koje mogu biti aktivirane.</div>
            ) : (
              <button
                className="button button-primary"
                disabled={working}
                onClick={() => void complete()}
                type="button"
              >
                {working ? "Čuvanje..." : "POTVRDI I NASTAVI"}
              </button>
            )}
          </div>
        ) : null}
      </section>
    </main>
  );
}
