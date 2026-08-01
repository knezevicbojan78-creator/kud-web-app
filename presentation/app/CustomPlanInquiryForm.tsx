"use client";

import { useState, type FormEvent } from "react";
import { getSupabaseClient } from "../../app/_lib/supabaseClient";

const initialValues = { firstName: "", lastName: "", phone: "", email: "", message: "", website: "" };

export function CustomPlanInquiryForm() {
  const [isOpen, setIsOpen] = useState(false);
  const [values, setValues] = useState(initialValues);
  const [isSending, setIsSending] = useState(false);
  const [feedback, setFeedback] = useState("");
  const [isError, setIsError] = useState(false);

  function close() {
    if (isSending) return;
    setIsOpen(false);
    setFeedback("");
    setIsError(false);
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setIsSending(true);
    setFeedback("");
    setIsError(false);

    const { error } = await getSupabaseClient().rpc("auth_submit_custom_plan_inquiry", {
      p_first_name: values.firstName,
      p_last_name: values.lastName,
      p_phone: values.phone,
      p_email: values.email,
      p_message: values.message,
      p_website: values.website || null
    });

    if (error) {
      setIsError(true);
      setFeedback(error.message || "Upit trenutno nije moguće poslati.");
    } else {
      setValues(initialValues);
      setFeedback("Upit je poslat. Master administrator će Vas kontaktirati.");
    }
    setIsSending(false);
  }

  return (
    <>
      <button className="custom-plan-link" onClick={() => setIsOpen(true)} type="button">
        Razgovarajmo o paketu po meri.
      </button>
      {isOpen ? (
        <div className="custom-inquiry-backdrop" onMouseDown={(event) => event.target === event.currentTarget && close()}>
          <section aria-labelledby="custom-inquiry-title" aria-modal="true" className="custom-inquiry-dialog" role="dialog">
            <button aria-label="Zatvori" className="custom-inquiry-close" onClick={close} type="button">×</button>
            <p className="marketing-kicker">PAKET PO MERI</p>
            <h2 id="custom-inquiry-title">Recite nam šta je potrebno Vašem KUD-u</h2>
            <p>Ostavite kontakt podatke i kratak opis. Master administrator će Vam se javiti.</p>
            <form onSubmit={submit}>
              <div className="custom-inquiry-grid">
                <label><span>Ime *</span><input required minLength={2} onChange={(e) => setValues(v => ({ ...v, firstName: e.target.value }))} value={values.firstName} /></label>
                <label><span>Prezime *</span><input required minLength={2} onChange={(e) => setValues(v => ({ ...v, lastName: e.target.value }))} value={values.lastName} /></label>
                <label><span>Telefon *</span><input required minLength={6} type="tel" onChange={(e) => setValues(v => ({ ...v, phone: e.target.value }))} value={values.phone} /></label>
                <label><span>Email *</span><input required type="email" onChange={(e) => setValues(v => ({ ...v, email: e.target.value }))} value={values.email} /></label>
              </div>
              <label className="custom-inquiry-message"><span>Vaš upit *</span><textarea required minLength={10} rows={5} onChange={(e) => setValues(v => ({ ...v, message: e.target.value }))} value={values.message} /></label>
              <label className="custom-inquiry-honeypot" aria-hidden="true"><span>Website</span><input tabIndex={-1} autoComplete="off" onChange={(e) => setValues(v => ({ ...v, website: e.target.value }))} value={values.website} /></label>
              {feedback ? <p className={isError ? "custom-inquiry-feedback error" : "custom-inquiry-feedback success"} role="status">{feedback}</p> : null}
              <div className="custom-inquiry-actions">
                <button className="button" disabled={isSending} onClick={close} type="button">Odustani</button>
                <button className="button marketing-primary" disabled={isSending} type="submit">{isSending ? "Slanje..." : "Pošaljite upit"}</button>
              </div>
            </form>
          </section>
        </div>
      ) : null}
    </>
  );
}
