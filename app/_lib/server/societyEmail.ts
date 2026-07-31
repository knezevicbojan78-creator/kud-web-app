import { createClient } from "@supabase/supabase-js";
import { getGmailEncryptionSecret, sendGmailMessage } from "./gmailOAuth";

export function createAuthenticatedServerClient(authorization: string) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) throw new Error("Supabase konfiguracija nije dostupna.");
  return createClient(url, key, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false }
  });
}

export function escapeEmailHtml(value: unknown) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

export async function deliverQueuedSocietyEmail(
  supabase: ReturnType<typeof createAuthenticatedServerClient>,
  outboxId: string
) {
  const { data: delivery, error: claimError } = await (supabase.rpc as any)(
    "auth_claim_society_email",
    {
      p_outbox_id: outboxId,
      p_encryption_secret: getGmailEncryptionSecret()
    }
  );
  if (claimError || !delivery) {
    throw new Error(claimError?.message || "Email nije moguće pripremiti za slanje.");
  }
  try {
    const sent = await sendGmailMessage({
      refreshToken: delivery.refresh_token,
      fromEmail: delivery.sender_email,
      toEmail: delivery.recipient_email,
      subject: delivery.subject,
      html: delivery.html_body,
      text: delivery.text_body
    });
    const { error: successError } = await (supabase.rpc as any)(
      "auth_complete_society_email_attempt",
      {
        p_outbox_id: outboxId,
        p_succeeded: true,
        p_provider_message_id: sent.messageId,
        p_error: null
      }
    );
    if (successError) throw successError;
    return sent;
  } catch (error) {
    await (supabase.rpc as any)("auth_complete_society_email_attempt", {
      p_outbox_id: outboxId,
      p_succeeded: false,
      p_provider_message_id: null,
      p_error: error instanceof Error ? error.message.slice(0, 1000) : "Slanje nije uspelo."
    });
    throw error;
  }
}
