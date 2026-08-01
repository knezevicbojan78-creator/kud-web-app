"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { getSupabaseClient } from "../../_lib/supabaseClient";

export default function AuthCallbackPage() {
  const router = useRouter();
  const [error, setError] = useState("");

  useEffect(() => {
    let active = true;

    async function completeCallback() {
      const supabase = getSupabaseClient();
      const url = new URL(window.location.href);
      const code = url.searchParams.get("code");
      const next = url.searchParams.get("next") || "/auth/mfa";
      const tokenHash = url.searchParams.get("token_hash");
      const otpType = url.searchParams.get("type");
      const hash = new URLSearchParams(url.hash.replace(/^#/, ""));
      const accessToken = hash.get("access_token");
      const refreshToken = hash.get("refresh_token");
      const linkError =
        url.searchParams.get("error_description") ||
        hash.get("error_description");

      try {
        if (linkError) {
          throw new Error(decodeURIComponent(linkError.replace(/\+/g, " ")));
        }

        if (code) {
          const { error: exchangeError } =
            await supabase.auth.exchangeCodeForSession(code);
          if (exchangeError) {
            throw exchangeError;
          }
        } else if (accessToken && refreshToken) {
          const { error: sessionError } = await supabase.auth.setSession({
            access_token: accessToken,
            refresh_token: refreshToken
          });
          if (sessionError) {
            throw sessionError;
          }
        } else if (
          tokenHash &&
          (otpType === "email" ||
            otpType === "invite" ||
            otpType === "magiclink" ||
            otpType === "recovery" ||
            otpType === "signup")
        ) {
          const { error: verifyError } = await supabase.auth.verifyOtp({
            token_hash: tokenHash,
            type: otpType
          });
          if (verifyError) {
            throw verifyError;
          }
        } else {
          const { data: initialData, error: initialError } =
            await supabase.auth.getSession();
          if (initialError) {
            throw initialError;
          }

          if (!initialData.session) {
            const session = await new Promise<boolean>((resolve) => {
              let settled = false;
              const {
                data: { subscription }
              } = supabase.auth.onAuthStateChange((_event, authSession) => {
                if (!settled && authSession) {
                  settled = true;
                  subscription.unsubscribe();
                  resolve(true);
                }
              });

              window.setTimeout(() => {
                if (!settled) {
                  settled = true;
                  subscription.unsubscribe();
                  resolve(false);
                }
              }, 3000);
            });

            if (!session) {
              throw new Error(
                "Aktivaciona sesija nije pronađena. Link je možda istekao ili je već iskorišćen."
              );
            }
          }
        }

        if (active) {
          router.replace(next);
        }
      } catch (callbackError) {
        if (active) {
          setError(
            callbackError instanceof Error
              ? callbackError.message
              : "Aktivacioni link nije moguće obraditi."
          );
        }
      }
    }

    void completeCallback();
    return () => {
      active = false;
    };
  }, [router]);

  return (
    <main className="login-page">
      <section className="card login-card auth-center">
        <h1>Potvrda naloga</h1>
        {error ? (
          <>
            <div className="auth-message error">{error}</div>
            <a className="button button-secondary" href="/prijava">
              Nazad na prijavljivanje
            </a>
          </>
        ) : (
          <p>Proveravamo aktivacioni link...</p>
        )}
      </section>
    </main>
  );
}
