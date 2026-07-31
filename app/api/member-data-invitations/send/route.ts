import { NextResponse, type NextRequest } from "next/server";
import {
  createAuthenticatedServerClient,
  deliverQueuedSocietyEmail
} from "../../../_lib/server/societyEmail";
import { getGmailEncryptionSecret } from "../../../_lib/server/gmailOAuth";

export async function POST(request: NextRequest) {
  const authorization = request.headers.get("authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return NextResponse.json({ error: "Prijava je obavezna." }, { status: 401 });
  }
  try {
    const body = await request.json() as {
      societyId?: string;
      candidateId?: string;
      recipientRole?: "MEMBER" | "GUARDIAN";
      recipientEmail?: string;
    };
    if (!body.societyId || !body.candidateId || !body.recipientRole) {
      return NextResponse.json({ error: "Podaci poziva nisu potpuni." }, { status: 400 });
    }
    const appUrl = process.env.NEXT_PUBLIC_APP_URL || request.nextUrl.origin;
    const supabase = createAuthenticatedServerClient(authorization);
    const { error: acceptError } = await (supabase.rpc as any)(
      "auth_accept_candidate_for_data_completion",
      {
        p_society_id: body.societyId,
        p_candidate_id: body.candidateId
      }
    );
    if (acceptError) {
      return NextResponse.json({ error: acceptError.message }, { status: 400 });
    }
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
    const invitationUrl =
      `${appUrl.replace(/\/$/, "")}/dopuna-podataka/${data.token}`;
    const { data: queued, error: queueError } = await (supabase.rpc as any)(
      "auth_queue_member_data_invitation_email",
      {
        p_society_id: body.societyId,
        p_candidate_id: body.candidateId,
        p_recipient_role: body.recipientRole,
        p_invitation_url: invitationUrl,
        p_encryption_secret: getGmailEncryptionSecret()
      }
    );
    if (queueError || !queued?.outbox_id) {
      await (supabase.rpc as any)("auth_cancel_member_data_invitation", {
        p_society_id: body.societyId,
        p_candidate_id: body.candidateId,
        p_recipient_role: body.recipientRole
      });
      return NextResponse.json(
        { error: queueError?.message || "Email nije moguće evidentirati." },
        { status: 400 }
      );
    }
    try {
      await deliverQueuedSocietyEmail(supabase, queued.outbox_id);
      return NextResponse.json({ sent: true, email: data.email });
    } catch (deliveryError) {
      return NextResponse.json(
        {
          error: deliveryError instanceof Error
            ? deliveryError.message
            : "Poruka je evidentirana, ali slanje nije uspelo."
        },
        { status: 502 }
      );
    }
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Slanje poziva nije uspelo." },
      { status: 400 }
    );
  }
}
