import { NextResponse, type NextRequest } from "next/server";
import {
  createAuthenticatedServerClient,
  deliverQueuedSocietyEmail
} from "../../../_lib/server/societyEmail";

export async function POST(request: NextRequest) {
  const authorization = request.headers.get("authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return NextResponse.json({ error: "Prijava je obavezna." }, { status: 401 });
  }
  try {
    const body = await request.json() as { paymentId?: string };
    if (!body.paymentId) {
      return NextResponse.json({ error: "Uplata nije navedena." }, { status: 400 });
    }
    const supabase = createAuthenticatedServerClient(authorization);
    const { data, error } = await (supabase.rpc as any)(
      "auth_queue_payment_confirmation_emails",
      { p_payment_id: body.paymentId }
    );
    if (error) throw error;
    const messages = Array.isArray(data) ? data : [];
    const results = await Promise.allSettled(
      messages.map((message: { outbox_id: string }) =>
        deliverQueuedSocietyEmail(supabase, message.outbox_id)
      )
    );
    return NextResponse.json({
      queued: messages.length,
      sent: results.filter((result) => result.status === "fulfilled").length,
      failed: results.filter((result) => result.status === "rejected").length
    });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Potvrde uplate nisu pripremljene." },
      { status: 400 }
    );
  }
}
