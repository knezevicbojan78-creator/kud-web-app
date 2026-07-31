import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";
import {
  exchangeGoogleCode,
  getGmailEncryptionSecret,
  getGoogleUserInfo,
  revokeGoogleToken,
  verifyGmailOAuthState
} from "../../../_lib/server/gmailOAuth";

export async function POST(request: NextRequest) {
  const authorization = request.headers.get("authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return NextResponse.json({ error: "Prijava je obavezna." }, { status: 401 });
  }
  try {
    const body = await request.json() as { code?: string; state?: string; societyId?: string };
    if (!body.code || !body.state || !body.societyId) {
      return NextResponse.json({ error: "Google potvrda nije potpuna." }, { status: 400 });
    }
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    if (!supabaseUrl || !anonKey) throw new Error("Supabase konfiguracija nije dostupna.");
    const supabase = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false }
    });
    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData.user) {
      return NextResponse.json({ error: "Prijava je istekla." }, { status: 401 });
    }
    const state = verifyGmailOAuthState(body.state);
    if (state.userId !== userData.user.id || state.societyId !== body.societyId) {
      return NextResponse.json({ error: "Google potvrda ne pripada ovom nalogu." }, { status: 403 });
    }

    const token = await exchangeGoogleCode(body.code, request.nextUrl.origin);
    const googleAccount = await getGoogleUserInfo(token.access_token!);
    const expiresAt = token.expires_in
      ? new Date(Date.now() + token.expires_in * 1000).toISOString()
      : null;
    const { data, error } = await (supabase.rpc as any)(
      "auth_save_society_gmail_connection",
      {
        p_society_id: body.societyId,
        p_google_account_id: googleAccount.accountId,
        p_email: googleAccount.email,
        p_refresh_token: token.refresh_token,
        p_access_token: token.access_token,
        p_access_token_expires_at: expiresAt,
        p_encryption_secret: getGmailEncryptionSecret()
      }
    );
    if (error) throw error;
    // Google can invalidate the whole token family when an older refresh token
    // for the same account is revoked. The database row has already been
    // replaced, so only revoke a previous token when the connected account
    // itself changed.
    if (
      data?.previous_refresh_token &&
      data.previous_refresh_token !== token.refresh_token &&
      data.previous_email?.toLowerCase() !== googleAccount.email.toLowerCase()
    ) {
      await revokeGoogleToken(data.previous_refresh_token);
    }
    return NextResponse.json({
      connected: true,
      email: googleAccount.email,
      replaced: Boolean(data?.replaced)
    });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Povezivanje Gmail naloga nije uspelo." },
      { status: 400 }
    );
  }
}
