import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

export async function POST(request: NextRequest) {
  const authorization = request.headers.get("authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return NextResponse.json({ error: "Prijava je obavezna." }, { status: 401 });
  }

  const body = await request.json();
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  const resendKey = process.env.RESEND_API_KEY;
  const fromEmail = process.env.MEMBER_INVITATION_FROM_EMAIL;
  const appUrl = process.env.NEXT_PUBLIC_APP_URL || request.nextUrl.origin;

  if (!supabaseUrl || !anonKey) {
    return NextResponse.json({ error: "Supabase konfiguracija nije dostupna." }, { status: 500 });
  }
  if (!resendKey || !fromEmail) {
    return NextResponse.json(
      { error: "Email servis nije podešen. Nedostaju RESEND_API_KEY ili MEMBER_INVITATION_FROM_EMAIL." },
      { status: 503 }
    );
  }

  const supabase = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false }
  });
  const { data, error } = await (supabase.rpc as any)(
    "auth_create_member_data_invitation",
    {
      p_society_id: body.societyId,
      p_candidate_id: body.candidateId,
      p_recipient_role: body.recipientRole,
      p_recipient_email: body.recipientEmail || null
    }
  );
  if (error || !data) {
    return NextResponse.json(
      { error: error?.message || "Poziv nije moguće napraviti." },
      { status: 400 }
    );
  }

  const invitationUrl = `${appUrl.replace(/\/$/, "")}/dopuna-podataka/${data.token}`;
  const emailResponse = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      from: fromEmail,
      to: [data.email],
      subject: "Dopunite podatke za članstvo",
      html: `
        <p>Poštovani/a ${escapeHtml(data.recipient_name)},</p>
        <p>Molimo vas da dopunite ${
          data.recipient_role === "GUARDIAN"
            ? "podatke deteta i roditelja/staratelja"
            : "lične podatke potrebne za evidenciju članstva"
        }.</p>
        <p><a href="${invitationUrl}">Otvorite bezbedan obrazac za dopunu podataka</a></p>
        <p>Podatke možete sačuvati i nastaviti kasnije. Link važi 7 dana.</p>
      `
    })
  });
  if (!emailResponse.ok) {
    const providerError = await emailResponse.text();
    await (supabase.rpc as any)("auth_cancel_member_data_invitation", {
      p_society_id: body.societyId,
      p_candidate_id: body.candidateId,
      p_recipient_role: body.recipientRole
    });
    return NextResponse.json(
      { error: `Email nije poslat: ${providerError.slice(0, 300)}` },
      { status: 502 }
    );
  }

  return NextResponse.json({ sent: true, email: data.email });
}

function escapeHtml(value: string) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}
