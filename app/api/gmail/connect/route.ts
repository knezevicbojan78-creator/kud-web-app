import { createClient } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";
import {
  createGmailOAuthState,
  createGoogleAuthorizationUrl
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
    if (!supabaseUrl || !anonKey) {
      throw new Error("Supabase konfiguracija nije dostupna.");
    }
    const supabase = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false }
    });
    const [{ data: userData, error: userError }, { data: context, error: contextError }] =
      await Promise.all([
        supabase.auth.getUser(),
        (supabase.rpc as any)("auth_get_application_context")
      ]);
    if (userError || !userData.user) {
      return NextResponse.json({ error: "Prijava je istekla." }, { status: 401 });
    }
    if (contextError) throw contextError;
    const membership = context?.memberships?.find(
      (item: { society_id: string }) => item.society_id === societyId
    );
    if (!membership?.functions?.includes("Predsednik")) {
      return NextResponse.json(
        { error: "Samo predsednik može da poveže Gmail nalog društva." },
        { status: 403 }
      );
    }
    const state = createGmailOAuthState(userData.user.id, societyId);
    return NextResponse.json({
      url: createGoogleAuthorizationUrl(state, request.nextUrl.origin)
    });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Povezivanje nije moguće." },
      { status: 503 }
    );
  }
}
