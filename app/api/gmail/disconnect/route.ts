import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";
import {
  getGmailEncryptionSecret,
  revokeGoogleToken
} from "../../../_lib/server/gmailOAuth";

export async function POST(request: NextRequest) {
  const authorization = request.headers.get("authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return NextResponse.json({ error: "Prijava je obavezna." }, { status: 401 });
  }
  try {
    const { societyId } = await request.json() as { societyId?: string };
    if (!societyId) {
      return NextResponse.json({ error: "Društvo nije izabrano." }, { status: 400 });
    }
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    if (!supabaseUrl || !anonKey) throw new Error("Supabase konfiguracija nije dostupna.");
    const supabase = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false }
    });
    const { data, error } = await (supabase.rpc as any)(
      "auth_disconnect_society_gmail",
      {
        p_society_id: societyId,
        p_encryption_secret: getGmailEncryptionSecret()
      }
    );
    if (error) throw error;
    await revokeGoogleToken(data?.refresh_token);
    return NextResponse.json({
      disconnected: Boolean(data?.disconnected),
      email: data?.email ?? null
    });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Odjava Gmail naloga nije uspela." },
      { status: 400 }
    );
  }
}
