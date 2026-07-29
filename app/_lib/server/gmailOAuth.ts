import { createHmac, randomBytes, timingSafeEqual } from "node:crypto";

const gmailSendScope = "https://www.googleapis.com/auth/gmail.send";

type GmailState = {
  userId: string;
  societyId: string;
  expiresAt: number;
  nonce: string;
};

type GoogleTokenResponse = {
  access_token?: string;
  expires_in?: number;
  refresh_token?: string;
  scope?: string;
  token_type?: string;
  error?: string;
  error_description?: string;
};

type GoogleUserInfo = {
  sub?: string;
  email?: string;
  email_verified?: boolean;
};

function requireEnvironment(name: string, minimumLength = 1) {
  const value = process.env[name]?.trim();
  if (!value || value.length < minimumLength) {
    throw new Error(`Nedostaje serversko podešavanje ${name}.`);
  }
  return value;
}

export function getGmailEncryptionSecret() {
  return requireEnvironment("GMAIL_TOKEN_ENCRYPTION_KEY", 32);
}

function getStateSecret() {
  return requireEnvironment("GMAIL_OAUTH_STATE_SECRET", 32);
}

function encode(value: string | Buffer) {
  return Buffer.from(value).toString("base64url");
}

export function createGmailOAuthState(userId: string, societyId: string) {
  const payload: GmailState = {
    userId,
    societyId,
    expiresAt: Date.now() + 10 * 60 * 1000,
    nonce: randomBytes(18).toString("base64url")
  };
  const encodedPayload = encode(JSON.stringify(payload));
  const signature = createHmac("sha256", getStateSecret()).update(encodedPayload).digest("base64url");
  return `${encodedPayload}.${signature}`;
}

export function verifyGmailOAuthState(value: string): GmailState {
  const [encodedPayload, receivedSignature, extra] = value.split(".");
  if (!encodedPayload || !receivedSignature || extra) {
    throw new Error("Google potvrda nije ispravna. Pokrenite povezivanje ponovo.");
  }
  const expectedSignature = createHmac("sha256", getStateSecret())
    .update(encodedPayload)
    .digest();
  let received: Buffer;
  try {
    received = Buffer.from(receivedSignature, "base64url");
  } catch {
    throw new Error("Google potvrda nije ispravna. Pokrenite povezivanje ponovo.");
  }
  if (received.length !== expectedSignature.length || !timingSafeEqual(received, expectedSignature)) {
    throw new Error("Google potvrda nije ispravna. Pokrenite povezivanje ponovo.");
  }
  let payload: GmailState;
  try {
    payload = JSON.parse(Buffer.from(encodedPayload, "base64url").toString("utf8")) as GmailState;
  } catch {
    throw new Error("Google potvrda nije ispravna. Pokrenite povezivanje ponovo.");
  }
  if (!payload.userId || !payload.societyId || !payload.nonce || payload.expiresAt < Date.now()) {
    throw new Error("Google potvrda je istekla. Pokrenite povezivanje ponovo.");
  }
  return payload;
}

export function getGmailRedirectUri(origin: string) {
  const configuredAppUrl = process.env.NEXT_PUBLIC_APP_URL?.trim();
  return `${(configuredAppUrl || origin).replace(/\/$/, "")}/api/gmail/callback`;
}

export function createGoogleAuthorizationUrl(state: string, origin: string) {
  const url = new URL("https://accounts.google.com/o/oauth2/v2/auth");
  url.searchParams.set("client_id", requireEnvironment("GOOGLE_GMAIL_CLIENT_ID"));
  url.searchParams.set("redirect_uri", getGmailRedirectUri(origin));
  url.searchParams.set("response_type", "code");
  url.searchParams.set("scope", `openid email ${gmailSendScope}`);
  url.searchParams.set("access_type", "offline");
  url.searchParams.set("prompt", "consent");
  url.searchParams.set("include_granted_scopes", "true");
  url.searchParams.set("state", state);
  return url.toString();
}

export async function exchangeGoogleCode(code: string, origin: string) {
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      code,
      client_id: requireEnvironment("GOOGLE_GMAIL_CLIENT_ID"),
      client_secret: requireEnvironment("GOOGLE_GMAIL_CLIENT_SECRET"),
      redirect_uri: getGmailRedirectUri(origin),
      grant_type: "authorization_code"
    })
  });
  const data = await response.json() as GoogleTokenResponse;
  if (!response.ok || !data.access_token) {
    throw new Error(data.error_description || "Google nije završio povezivanje Gmail naloga.");
  }
  if (!data.refresh_token) {
    throw new Error("Google nije vratio trajnu dozvolu. Pokrenite povezivanje ponovo.");
  }
  return data;
}

export async function getGoogleUserInfo(accessToken: string) {
  const response = await fetch("https://openidconnect.googleapis.com/v1/userinfo", {
    headers: { Authorization: `Bearer ${accessToken}` }
  });
  const data = await response.json() as GoogleUserInfo;
  if (!response.ok || !data.sub || !data.email || data.email_verified === false) {
    throw new Error("Nije moguće potvrditi email adresu povezanog Google naloga.");
  }
  return { accountId: data.sub, email: data.email };
}

export async function revokeGoogleToken(token?: string | null) {
  if (!token) return;
  try {
    await fetch("https://oauth2.googleapis.com/revoke", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ token })
    });
  } catch {
    // Povezivanje ili odjava ostaju uspešni i ako Google trenutno ne odgovori.
  }
}
