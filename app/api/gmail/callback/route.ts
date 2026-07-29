import { NextResponse, type NextRequest } from "next/server";

export async function GET(request: NextRequest) {
  const destination = new URL("/podesavanja", request.url);
  const googleError = request.nextUrl.searchParams.get("error");
  if (googleError) {
    destination.searchParams.set("gmail", "error");
    destination.searchParams.set(
      "message",
      googleError === "access_denied"
        ? "Povezivanje je otkazano na Google stranici."
        : "Google nije odobrio povezivanje."
    );
    return NextResponse.redirect(destination);
  }

  const code = request.nextUrl.searchParams.get("code");
  const state = request.nextUrl.searchParams.get("state");
  if (!code || !state) {
    destination.searchParams.set("gmail", "error");
    destination.searchParams.set("message", "Google nije vratio potrebnu potvrdu.");
    return NextResponse.redirect(destination);
  }
  destination.searchParams.set("gmail", "callback");
  destination.searchParams.set("code", code);
  destination.searchParams.set("state", state);
  return NextResponse.redirect(destination);
}
