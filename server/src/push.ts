// Push: a request to an owner whose iPhone sent its APNs token (a build
// with STARHASH_PUSH, which needs a paid Apple team) wakes StarHash there.
// The push says "New request" and carries the request still sealed, as the
// server keeps it, with the asker's public key: neither the server nor
// Apple can read it. On the iPhone, StarHash's Notification Service
// Extension (`mutable-content`) opens it and, when the asker is someone the
// owner knows, shows who asks and for how much instead; StarHash itself,
// woken by `content-available`, fetches what waits as it does after
// Background App Refresh.
//
// Sent only when the Worker has the three secrets of an APNs key (the .p8
// file's text, its id, the team's id): without them nothing is sent, and
// tokens are only kept.

export interface PushEnv {
  DB: D1Database;
  /// The APNs key, the .p8 file's text, and its 10-character id
  /// (`npx wrangler secret put APNS_KEY` and so on).
  APNS_KEY?: string;
  APNS_KEY_ID?: string;
  /// The Apple team the key belongs to.
  APNS_TEAM_ID?: string;
  /// Tests only: where pushes go instead of APNs, production's and the
  /// sandbox's.
  APNS_URL?: string;
  APNS_SANDBOX_URL?: string;
}

/// StarHash's bundle id: the app APNs delivers to.
const TOPIC = "com.devbyshima.starhash";
const PRODUCTION = "https://api.push.apple.com";
const SANDBOX = "https://api.sandbox.push.apple.com";

/// An APNs device token in hex: 32 bytes now, and Apple says it may grow.
export const TOKEN = /^[0-9a-f]{64,200}$/;
/// One key on a few iPhones at most (a new one restored from the old one's
/// backup): the oldest tokens past this go.
export const MAX_TOKENS_PER_KEY = 3;

/// APNs takes 4 KB of payload at most.
const MAX_PAYLOAD = 4096;

/// A request as the push carries it: as the server keeps it.
export interface SealedRequest {
  id: string;
  sealed: string;
  /// The asker's public key, which sealed it.
  key: string;
}

/// What the push for `request` says. "New request" is a key in the app's
/// string catalog, so iOS shows it in English, French or Kinyarwanda (and
/// the words themselves when it finds none) whenever the iPhone does not
/// open the request. In the requests thread, beside StarHash's own.
export function payload(request: SealedRequest): string {
  return JSON.stringify({
    aps: {
      alert: { "loc-key": "New request" },
      sound: "default",
      "content-available": 1,
      "mutable-content": 1,
      "thread-id": "requests",
    },
    sealed: { id: request.id, sealed: request.sealed, key: request.key },
  });
}

/// The token APNs is shown with each push: made again after 50 minutes, as
/// APNs refuses one older than an hour and one made more often than every
/// 20 minutes. Kept for the life of the Worker's isolate.
let provider: { jwt: string; madeAt: number; keyID: string } | null = null;

/// Whether the Worker can push: the three secrets are set.
export function canPush(env: PushEnv): boolean {
  return Boolean(env.APNS_KEY && env.APNS_KEY_ID && env.APNS_TEAM_ID);
}

/// Tells every iPhone that listed `keyHash` with a token that `request`
/// came, until `expires`, the request's own end. Never throws: a push that
/// fails leaves the request to be found when StarHash next opens.
export async function notifyRequest(
  keyHash: string,
  request: SealedRequest,
  expires: string,
  lapsed: string,
  env: PushEnv,
): Promise<void> {
  if (!canPush(env)) return;
  const body = payload(request);
  // A seal is 2 KB at most, so this never happens; if it did, APNs would
  // refuse the push whole.
  if (new TextEncoder().encode(body).length > MAX_PAYLOAD) return;
  try {
    const { results } = await env.DB.prepare(
      `SELECT token, sandbox FROM push_tokens WHERE key_hash = ?1 AND updated_at > ?2
       ORDER BY updated_at DESC LIMIT ?3`,
    )
      .bind(keyHash, lapsed, MAX_TOKENS_PER_KEY)
      .all<{ token: string; sandbox: number }>();
    if (results.length === 0) return;
    const jwt = await providerToken(env);
    if (!jwt) return;
    const expiration = String(Math.floor(Date.parse(expires) / 1000));
    await Promise.all(results.map((row) => push(row.token, row.sandbox === 1, jwt, expiration, request.id, body, env)));
  } catch (error) {
    console.error("push failed", error);
  }
}

async function push(
  token: string,
  sandbox: boolean,
  jwt: string,
  expiration: string,
  id: string,
  body: string,
  env: PushEnv,
): Promise<void> {
  const base = sandbox ? (env.APNS_SANDBOX_URL ?? SANDBOX) : (env.APNS_URL ?? PRODUCTION);
  let response: Response;
  try {
    response = await fetch(`${base}/3/device/${token}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": TOPIC,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "apns-expiration": expiration,
        "apns-collapse-id": id,
        "content-type": "application/json",
      },
      body,
    });
  } catch (error) {
    console.error("APNs not reached", error);
    return;
  }
  if (response.ok) return;
  const reason = await response
    .json<{ reason?: string }>()
    .then((body) => body?.reason)
    .catch(() => undefined);
  // The app was deleted, or the token is not one of StarHash's: it goes.
  if (response.status === 410 || (response.status === 400 && (reason === "BadDeviceToken" || reason === "DeviceTokenNotForTopic"))) {
    await env.DB.prepare("DELETE FROM push_tokens WHERE token = ?1").bind(token).run();
    return;
  }
  // The provider token is refused: the next push makes a new one.
  if (response.status === 403) provider = null;
  console.error("APNs refused a push", response.status, reason);
}

/// The JWT APNs takes, signed ES256 with the team's key, or null when the
/// key cannot be read.
async function providerToken(env: PushEnv): Promise<string | null> {
  const keyID = env.APNS_KEY_ID!;
  const now = Date.now();
  if (provider && provider.keyID === keyID && now - provider.madeAt < 50 * 60 * 1000) return provider.jwt;
  let key: CryptoKey;
  try {
    key = await crypto.subtle.importKey("pkcs8", pemBody(env.APNS_KEY!), { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  } catch (error) {
    console.error("APNS_KEY is not a P-256 key in PKCS #8", error);
    return null;
  }
  const header = base64url(new TextEncoder().encode(JSON.stringify({ alg: "ES256", kid: keyID })));
  const claims = base64url(new TextEncoder().encode(JSON.stringify({ iss: env.APNS_TEAM_ID, iat: Math.floor(now / 1000) })));
  const signed = `${header}.${claims}`;
  // WebCrypto signs as r and s side by side, the form a JWT carries.
  const signature = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(signed));
  const jwt = `${signed}.${base64url(new Uint8Array(signature))}`;
  provider = { jwt, madeAt: now, keyID };
  return jwt;
}

/// The key's bytes from the .p8 file's text, with or without its BEGIN and
/// END lines and line breaks.
function pemBody(pem: string): Uint8Array {
  const body = pem.replace(/-----(BEGIN|END) [A-Z ]+-----/g, "").replace(/\s+/g, "");
  return Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
}

function base64url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
