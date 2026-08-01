"use client";

import { useEffect, useState } from "react";
import { getSupabaseClient, type CustomPlanInquiry } from "../_lib/supabaseClient";

function formatDate(value: string) {
  return new Intl.DateTimeFormat("sr-RS", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value));
}

export function CustomPlanInquiries() {
  const [inquiries, setInquiries] = useState<CustomPlanInquiry[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState("");

  useEffect(() => {
    async function load() {
      const { data, error } = await getSupabaseClient().rpc("master_admin_get_custom_plan_inquiries");
      if (error) setErrorMessage("Upiti za paket po meri trenutno nisu učitani.");
      else setInquiries(data ?? []);
      setIsLoading(false);
    }
    void load();
  }, []);

  return (
    <section className="custom-plan-admin-section">
      <div className="page-heading master-heading">
        <div><p className="eyebrow">Upiti sa sajta</p><h2>Paketi po meri</h2><p>Kontakt podaci zainteresovanih KUD-ova i opis njihovih potreba.</p></div>
        <div className="master-result-count"><strong>{inquiries.length}</strong><span>upita</span></div>
      </div>
      {isLoading ? <section className="card dashboard-card"><p>Učitavanje upita...</p></section> : null}
      {errorMessage ? <section className="card dashboard-card" role="alert"><p>{errorMessage}</p></section> : null}
      {!isLoading && !errorMessage && inquiries.length === 0 ? <section className="card dashboard-card"><p>Nema novih upita za paket po meri.</p></section> : null}
      {!isLoading && !errorMessage && inquiries.length > 0 ? (
        <section className="card master-society-table-wrap" aria-label="Upiti za paket po meri">
          <table className="master-society-table">
            <thead><tr><th>Kontakt</th><th>Telefon</th><th>Email</th><th>Upit</th><th>Poslato</th><th>Status</th></tr></thead>
            <tbody>{inquiries.map((inquiry) => <tr key={inquiry.id}>
              <td><strong>{inquiry.first_name} {inquiry.last_name}</strong></td>
              <td>{inquiry.phone}</td><td><a href={`mailto:${inquiry.email}`}>{inquiry.email}</a></td>
              <td className="custom-plan-inquiry-message">{inquiry.message}</td><td>{formatDate(inquiry.created_at)}</td>
              <td><span className="master-status pending">NOVO</span></td>
            </tr>)}</tbody>
          </table>
        </section>
      ) : null}
    </section>
  );
}
