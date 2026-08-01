"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";

type ConsentChoice = "accepted" | "rejected" | null;
const storageKey = "folkloras-cookie-consent-v1";

declare global {
  interface Window {
    dataLayer?: unknown[];
    gtag?: (...args: unknown[]) => void;
  }
}

function removeAnalyticsCookies() {
  document.cookie.split(";").forEach((cookie) => {
    const name = cookie.split("=")[0]?.trim();
    if (!name || (name !== "_ga" && !name.startsWith("_ga_"))) return;
    document.cookie = `${name}=; Max-Age=0; Path=/; SameSite=Lax`;
    document.cookie = `${name}=; Max-Age=0; Path=/; Domain=.folkloras.rs; SameSite=Lax`;
  });
}

function loadGoogleAnalytics(measurementId: string) {
  if (document.querySelector(`script[data-folkloras-ga="${measurementId}"]`)) return;
  window.dataLayer = window.dataLayer || [];
  window.gtag = (...args: unknown[]) => window.dataLayer?.push(args);
  window.gtag("js", new Date());
  window.gtag("config", measurementId, { anonymize_ip: true });
  const script = document.createElement("script");
  script.async = true;
  script.src = `https://www.googletagmanager.com/gtag/js?id=${measurementId}`;
  script.dataset.folklorasGa = measurementId;
  document.head.appendChild(script);
}

export function CookieConsent({ googleAnalyticsId }: { googleAnalyticsId?: string }) {
  const [choice, setChoice] = useState<ConsentChoice>(null);
  const [isOpen, setIsOpen] = useState(false);

  useEffect(() => {
    const stored = window.localStorage.getItem(storageKey) as ConsentChoice;
    if (stored === "accepted" || stored === "rejected") {
      setChoice(stored);
      if (stored === "accepted" && googleAnalyticsId) loadGoogleAnalytics(googleAnalyticsId);
    } else {
      setIsOpen(true);
    }
  }, [googleAnalyticsId]);

  useEffect(() => {
    const openSettings = (event: Event) => {
      const target = event.target as Element | null;
      if (!target?.closest("[data-cookie-settings]")) return;
      event.preventDefault();
      setIsOpen(true);
    };
    document.addEventListener("click", openSettings);
    return () => document.removeEventListener("click", openSettings);
  }, []);

  const saveChoice = useCallback((nextChoice: Exclude<ConsentChoice, null>) => {
    window.localStorage.setItem(storageKey, nextChoice);
    setChoice(nextChoice);
    setIsOpen(false);
    if (nextChoice === "accepted" && googleAnalyticsId) {
      loadGoogleAnalytics(googleAnalyticsId);
    } else if (nextChoice === "rejected") {
      const analyticsWasLoaded = Boolean(document.querySelector("script[data-folkloras-ga]"));
      window.gtag?.("consent", "update", { analytics_storage: "denied" });
      removeAnalyticsCookies();
      if (analyticsWasLoaded) window.location.reload();
    }
  }, [googleAnalyticsId]);

  if (!isOpen) return null;
  return (
    <section aria-labelledby="cookie-consent-title" aria-live="polite" className="cookie-consent" role="dialog">
      <div>
        <h2 id="cookie-consent-title">Vaša privatnost je važna</h2>
        <p>Koristimo neophodnu memoriju pregledača da sačuvamo vaš izbor. Google Analytics uključujemo samo ako pristanete, kako bismo razumeli posećenost i unapredili sajt. Više informacija je u našoj <Link href="/politika-privatnosti">Politici privatnosti i kolačića</Link>.</p>
        {choice ? <small>Trenutni izbor: {choice === "accepted" ? "analitika je dozvoljena" : "analitika je odbijena"}.</small> : null}
      </div>
      <div className="cookie-consent-actions">
        <button className="cookie-button cookie-button-secondary" onClick={() => saveChoice("rejected")} type="button">Odbijam</button>
        <button className="cookie-button cookie-button-primary" onClick={() => saveChoice("accepted")} type="button">Prihvatam</button>
      </div>
    </section>
  );
}
