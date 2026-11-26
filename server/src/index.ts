// StarHash's server, the one thing StarHash keeps off the iPhone.
//
// Photos: an owner who shares their photo with their QR code uploads it
// under a random id the app made; the code carries that id, so whoever
// scans it can fetch the photo. A secret key, kept on the owner's iPhone,
// is needed to replace or delete it: the server keeps only its hash.
//
// The directory: an owner's numbers with the name they gave and their
// photo's id, so someone typing one of those numbers to pay it sees who it
// is. On unless the owner turns off Show My Name. Each number is kept only
// as a keyed hash (HMAC with DIRECTORY_SECRET, which only the Worker
// holds), so the table alone gives no number back, and the owner's key
// (the photo's) is needed to change or clear their entry. An entry not
// sent again for 45 days is deleted each night.
//
// Requests: an owner asks another StarHash user for money, wherever they
// are. Both need a directory entry with a public key. The asker's iPhone
// seals who asks, how much and what for to the other's public key (HPKE),
// so the server keeps only who asked whom and when, for the request's week.
// The asker's own number is checked against what their key lists, then
// dropped; the iPhone asked checks it again against the seal.
//
// Push (push.ts): an iPhone listed with requests on, in a build that has
// push, sends its APNs token under the same key, and a request to it then
// wakes StarHash there with a push that carries the request still sealed,
// for the iPhone to open. The token goes with the listing, and lapses with
// it.
//
// Installs: once each day it is used the app sends a random id it made on
// its first launch and its version, so the number of people using StarHash
// can be counted, in all (installs) and each day (active_days, by Kigali's
// date). Nothing else: no transactions.

import { MAX_TOKENS_PER_KEY, notifyRequest, type PushEnv, TOKEN } from "./push";

export interface Env extends PushEnv {
  DB: D1Database;
  /// The directory's numbers are hashed with it. Set with
  /// `npx wrangler secret put DIRECTORY_SECRET`; without it the directory
  /// is off.
  DIRECTORY_SECRET?: string;
}

/// A photo is one small JPEG, 600 points square at most.
const MAX_PHOTO_BYTES = 200 * 1024;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

/// A Rwandan mobile number as the app keeps it: MTN's 078 and 079,
/// Airtel's 072 and 073.
const NUMBER = /^07[2389]\d{7}$/;

/// A number however it is written, "+250 788 123 456", "250788123456",
/// "00250788123456", "0788-123-456" or Airtel's "788123456", as the
/// directory keeps it, "0788123456", or null when it is not a Rwandan
/// mobile number. Every number the Worker takes goes through it before it
/// is hashed, so one number written two ways is one number.
function localNumber(given: unknown): string | null {
  if (typeof given !== "string" || given.length > 32) return null;
  let digits = given.replace(/[\s\-().]/g, "");
  if (digits.startsWith("+")) digits = digits.slice(1);
  if (!/^\d+$/.test(digits)) return null;
  if (digits.startsWith("00250") && digits.length === 14) digits = "0" + digits.slice(5);
  else if (digits.startsWith("250") && digits.length === 12) digits = "0" + digits.slice(3);
  else if (digits.startsWith("7") && digits.length === 9) digits = "0" + digits;
  return NUMBER.test(digits) ? digits : null;
}

/// Numbers one lookup may ask about at once: a Request sheet checks the
/// owner's contacts in batches of this many.
const MAX_LOOKUP = 500;
/// D1 binds at most 100 values a query; the rest of a batch goes in more.
const LOOKUP_CHUNK = 90;

/// An owner has one SIM or two.
const MAX_NUMBERS = 2;
const MAX_NAME = 60;

/// A request waits this long, and is deleted the night after.
const REQUEST_LIFETIME_DAYS = 7;
/// Requests one key may send in any 24 hours.
const MAX_REQUESTS_A_DAY = 20;
/// A sealed request or answer, in base64: what StarHash seals is a few
/// hundred bytes (a name and a note of 60 characters at most).
const MAX_SEALED = 2048;
/// The public half of a Curve25519 key, 32 bytes in base64.
const PUBLIC_KEY = /^[A-Za-z0-9+/]{43}=$/;
const BASE64 = /^[A-Za-z0-9+/]+={0,2}$/;

/// An entry the app has not sent again in this long is left out of
/// lookups and deleted that night (`scheduled`): the app sends it each
/// week while it is in use, so one from a lost or wiped iPhone, or from a
/// deleted app, lapses, and stops hiding the number's new entry.
const ENTRY_LIFETIME_DAYS = 45;

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    const photo = url.pathname.match(/^\/v1\/photos\/([^/]+)$/);
    if (photo) {
      const id = photo[1].toLowerCase();
      if (!UUID.test(id)) return text(404, "Not found");
      switch (request.method) {
        case "GET":
          return getPhoto(id, env);
        case "PUT":
          return putPhoto(id, request, env);
        case "DELETE":
          return deletePhoto(id, request, env);
        default:
          return text(405, "Method not allowed");
      }
    }
    if (url.pathname === "/v1/ping" && request.method === "POST") {
      return ping(request, env);
    }
    if (url.pathname === "/v1/directory") {
      switch (request.method) {
        case "PUT":
          return putEntry(request, env);
        case "DELETE":
          return deleteEntry(request, env);
        default:
          return text(405, "Method not allowed");
      }
    }
    // A POST, so the number travels in the body and never in a URL.
    if (url.pathname === "/v1/directory/lookup" && request.method === "POST") {
      return lookUp(request, env);
    }
    if (url.pathname === "/v1/requests") {
      switch (request.method) {
        case "POST":
          return sendRequest(request, env, ctx);
        case "GET":
          return getRequests(request, env);
        case "DELETE":
          return eraseRequests(request, env);
        default:
          return text(405, "Method not allowed");
      }
    }
    if (url.pathname === "/v1/push") {
      switch (request.method) {
        case "PUT":
          return putPushToken(request, env);
        case "DELETE":
          return deletePushToken(request, env);
        default:
          return text(405, "Method not allowed");
      }
    }
    const one = url.pathname.match(/^\/v1\/requests\/([^/]+)(\/answer)?$/);
    if (one) {
      const id = one[1].toLowerCase();
      if (!UUID.test(id)) return text(404, "Not found");
      if (one[2]) {
        return request.method === "POST" ? answerRequest(id, request, env) : text(405, "Method not allowed");
      }
      return request.method === "DELETE" ? closeRequest(id, request, env) : text(405, "Method not allowed");
    }
    return text(404, "Not found");
  },

  /// Each night (the cron in wrangler.toml): the directory's lapsed
  /// entries, keys and push tokens are deleted, not only left out of
  /// lookups, and so are requests past their week.
  async scheduled(_controller: ScheduledController, env: Env): Promise<void> {
    const now = new Date();
    const lapsed = lapsedBefore(now);
    await env.DB.batch([
      env.DB.prepare("DELETE FROM directory WHERE updated_at <= ?1").bind(lapsed),
      env.DB.prepare("DELETE FROM directory_keys WHERE updated_at <= ?1").bind(lapsed),
      env.DB.prepare("DELETE FROM push_tokens WHERE updated_at <= ?1").bind(lapsed),
      env.DB.prepare("DELETE FROM requests WHERE expires_at <= ?1").bind(now.toISOString()),
    ]);
  },
} satisfies ExportedHandler<Env>;

/// The moment an entry not sent since has lapsed: lookups skip it and the
/// nightly run deletes it, by the one rule.
function lapsedBefore(now: Date): string {
  return new Date(now.getTime() - ENTRY_LIFETIME_DAYS * 86400 * 1000).toISOString();
}

// MARK: The directory

/// Lists the owner's numbers under their name and photo, in place of what
/// their key listed before (a number changed, a SIM dropped).
async function putEntry(request: Request, env: Env): Promise<Response> {
  const key = bearer(request);
  if (!key) return text(401, "A key is needed");
  const secret = env.DIRECTORY_SECRET;
  if (!secret) return text(503, "Not set up");
  let body: { numbers?: unknown; name?: unknown; photo?: unknown; key?: unknown };
  try {
    body = await request.json();
  } catch {
    return text(400, "Bad request");
  }
  // The public key requests are sealed to, from an iPhone that takes them.
  if (body.key !== undefined && body.key !== null && (typeof body.key !== "string" || !PUBLIC_KEY.test(body.key))) {
    return text(400, "Bad request");
  }
  const publicKey = typeof body.key === "string" ? body.key : null;
  const given = Array.isArray(body.numbers) ? body.numbers : [];
  const local = given.map(localNumber);
  const numbers = [...new Set(local.filter((n): n is string => n !== null))];
  if (numbers.length === 0 || numbers.length > MAX_NUMBERS || local.includes(null)) {
    return text(400, "Bad request");
  }
  const name = typeof body.name === "string" ? body.name.trim().slice(0, MAX_NAME) : "";
  const photo = typeof body.photo === "string" && UUID.test(body.photo.toLowerCase()) ? body.photo.toLowerCase() : null;
  // Nothing to show for a number with neither.
  if (!name && !photo) return text(400, "Bad request");

  const keyHash = await sha256(key);
  const now = new Date().toISOString();
  const hashes = await Promise.all(numbers.map((number) => numberHash(number, secret)));
  await env.DB.batch([
    env.DB.prepare("DELETE FROM directory WHERE key_hash = ?1").bind(keyHash),
    ...hashes.map((hash) =>
      env.DB.prepare(
        "INSERT INTO directory (number_hash, key_hash, name, photo_id, updated_at) VALUES (?1, ?2, ?3, ?4, ?5)",
      ).bind(hash, keyHash, name, photo, now),
    ),
    publicKey
      ? env.DB.prepare(
          `INSERT INTO directory_keys (key_hash, public_key, updated_at) VALUES (?1, ?2, ?3)
           ON CONFLICT(key_hash) DO UPDATE SET public_key = ?2, updated_at = ?3`,
        ).bind(keyHash, publicKey, now)
      : env.DB.prepare("DELETE FROM directory_keys WHERE key_hash = ?1").bind(keyHash),
    // A push only ever says a request came: no requests, no pushes.
    ...(publicKey ? [] : [env.DB.prepare("DELETE FROM push_tokens WHERE key_hash = ?1").bind(keyHash)]),
  ]);
  return text(200, "Saved");
}

/// Show My Name turned off, or the owner's numbers gone: their push
/// tokens go too.
async function deleteEntry(request: Request, env: Env): Promise<Response> {
  const key = bearer(request);
  if (!key) return text(401, "A key is needed");
  const keyHash = await sha256(key);
  await env.DB.batch([
    env.DB.prepare("DELETE FROM directory WHERE key_hash = ?1").bind(keyHash),
    env.DB.prepare("DELETE FROM directory_keys WHERE key_hash = ?1").bind(keyHash),
    env.DB.prepare("DELETE FROM push_tokens WHERE key_hash = ?1").bind(keyHash),
  ]);
  return text(200, "Deleted");
}

/// The name and photo listed for a number, and the public key requests to
/// it are sealed to when its iPhone takes them, or 404. Given `numbers`
/// instead, which of them are listed (`listedAmong`).
async function lookUp(request: Request, env: Env): Promise<Response> {
  const secret = env.DIRECTORY_SECRET;
  if (!secret) return text(404, "Not found");
  let body: { number?: unknown; numbers?: unknown };
  try {
    body = await request.json();
  } catch {
    return text(400, "Bad request");
  }
  if (body.numbers !== undefined) return listedAmong(body.numbers, secret, env);
  const number = localNumber(body.number);
  if (!number) return text(400, "Bad request");
  const entry = await listed(await numberHash(number, secret), env);
  if (!entry) return text(404, "Not found");
  return new Response(JSON.stringify({ name: entry.name || null, photo: entry.photo_id, key: entry.public_key }), {
    headers: { "Content-Type": "application/json", "Cache-Control": "private, max-age=300" },
  });
}

/// Which of `given` the directory lists, each as it was sent, and nothing
/// else: no name, photo or key, which a tap on one still looks up alone.
/// For the Request sheet, which shows the owner's contacts on StarHash
/// first. Numbers that are not Rwandan mobile numbers are left out; the
/// numbers are hashed to compare and kept nowhere.
async function listedAmong(given: unknown, secret: string, env: Env): Promise<Response> {
  if (!Array.isArray(given) || given.length > MAX_LOOKUP) return text(400, "Bad request");
  // The local form of each, and every way it was sent.
  const sent = new Map<string, string[]>();
  for (const raw of given) {
    const number = localNumber(raw);
    if (!number || typeof raw !== "string") continue;
    sent.set(number, [...(sent.get(number) ?? []), raw]);
  }
  const numbers = [...sent.keys()];
  const hashes = await Promise.all(numbers.map((number) => numberHash(number, secret)));
  const byHash = new Map(hashes.map((hash, i) => [hash, numbers[i]]));
  const lapsed = lapsedBefore(new Date());
  const listedNumbers: string[] = [];
  for (let start = 0; start < hashes.length; start += LOOKUP_CHUNK) {
    const chunk = hashes.slice(start, start + LOOKUP_CHUNK);
    const marks = chunk.map((_, i) => `?${i + 2}`).join(", ");
    const { results } = await env.DB.prepare(
      `SELECT number_hash FROM directory WHERE updated_at > ?1 AND number_hash IN (${marks})
       GROUP BY number_hash HAVING COUNT(*) = 1`,
    )
      .bind(lapsed, ...chunk)
      .all<{ number_hash: string }>();
    for (const row of results) {
      const number = byHash.get(row.number_hash);
      if (number) listedNumbers.push(...(sent.get(number) ?? []));
    }
  }
  return new Response(JSON.stringify({ listed: listedNumbers }), {
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

/// The one live entry for a number, or null. Two iPhones listing one
/// number: the server cannot tell which holds the SIM, so it shows
/// neither rather than maybe the wrong one, and takes no request for it.
async function listed(hash: string, env: Env) {
  const { results } = await env.DB.prepare(
    `SELECT d.name, d.photo_id, d.key_hash, k.public_key FROM directory d
     LEFT JOIN directory_keys k ON k.key_hash = d.key_hash
     WHERE d.number_hash = ?1 AND d.updated_at > ?2 LIMIT 2`,
  )
    .bind(hash, lapsedBefore(new Date()))
    .all<{ name: string; photo_id: string | null; key_hash: string; public_key: string | null }>();
  return results.length === 1 ? results[0] : null;
}

// MARK: Requests

/// Asks the owner of `to` for money: `sealed` is who asks, how much and
/// what for, sealed on the asker's iPhone to `to`'s public key. `from` is
/// the asker's own number, checked against what their key lists, so
/// nobody asks in another's name, and then forgotten. Once it is stored,
/// the iPhones of the person asked are told (`notifyRequest`), after the
/// answer.
async function sendRequest(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
  const key = bearer(request);
  if (!key) return text(401, "A key is needed");
  const secret = env.DIRECTORY_SECRET;
  if (!secret) return text(503, "Not set up");
  const body = await smallJSON<{ id?: unknown; to?: unknown; from?: unknown; sealed?: unknown }>(request);
  if (!body) return text(400, "Bad request");
  const id = typeof body.id === "string" ? body.id.toLowerCase() : "";
  const to = localNumber(body.to);
  const from = localNumber(body.from);
  const sealed = typeof body.sealed === "string" ? body.sealed : "";
  if (!UUID.test(id) || !to || !from || !isSealed(sealed)) return text(400, "Bad request");

  const keyHash = await sha256(key);
  const now = new Date();
  const lapsed = lapsedBefore(now);
  const [fromHash, toHash] = await Promise.all([numberHash(from, secret), numberHash(to, secret)]);
  const asker = await env.DB.prepare(
    `SELECT k.public_key FROM directory d JOIN directory_keys k ON k.key_hash = d.key_hash
     WHERE d.number_hash = ?1 AND d.key_hash = ?2 AND d.updated_at > ?3`,
  )
    .bind(fromHash, keyHash, lapsed)
    .first<{ public_key: string }>();
  // Only a number this key lists, with requests on, may ask.
  if (!asker) return text(403, "Not your number");
  const asked = await listed(toHash, env);
  if (!asked || !asked.public_key) return text(404, "Not on StarHash");
  if (asked.key_hash === keyHash) return text(400, "Your own number");

  const dayAgo = new Date(now.getTime() - 86400 * 1000).toISOString();
  const nowISO = now.toISOString();
  const expires = new Date(now.getTime() + REQUEST_LIFETIME_DAYS * 86400 * 1000).toISOString();
  // The limits and the insert in one statement, so two sent at once
  // cannot both slip under them.
  const result = await env.DB.prepare(
    `INSERT INTO requests (id, to_hash, to_key_hash, from_key_hash, from_public_key, sealed, state, created_at, expires_at)
     SELECT ?1, ?2, ?10, ?3, ?4, ?5, 'waiting', ?6, ?7
     WHERE (SELECT COUNT(*) FROM requests WHERE from_key_hash = ?3 AND created_at > ?8) < ?9
       AND NOT EXISTS (SELECT 1 FROM requests WHERE from_key_hash = ?3 AND to_hash = ?2
                       AND state IN ('waiting', 'dropped') AND expires_at > ?6)
     ON CONFLICT(id) DO NOTHING`,
  )
    .bind(id, toHash, keyHash, asker.public_key, sealed, nowISO, expires, dayAgo, MAX_REQUESTS_A_DAY, asked.key_hash)
    .run();
  if (result.meta.changes === 1) {
    ctx.waitUntil(notifyRequest(asked.key_hash, { id, sealed, key: asker.public_key }, expires, lapsed, env));
    return json(200, { id, created_at: nowISO, expires_at: expires });
  }
  const sent = await env.DB.prepare("SELECT COUNT(*) AS n FROM requests WHERE from_key_hash = ?1 AND created_at > ?2")
    .bind(keyHash, dayAgo)
    .first<{ n: number }>();
  if ((sent?.n ?? 0) >= MAX_REQUESTS_A_DAY) return text(429, "Too many today");
  // One waiting already, or this id taken.
  return text(409, "Already asked");
}

/// What waits for the caller: requests to a number their key listed when
/// it was asked (sealed, with the asker's public key; or only the id once
/// the asker closed it, so the card goes), and answers to the requests they
/// sent.
async function getRequests(request: Request, env: Env): Promise<Response> {
  const key = bearer(request);
  if (!key) return text(401, "A key is needed");
  const keyHash = await sha256(key);
  const now = new Date();
  const [asked, answers] = await env.DB.batch<Record<string, string>>([
    env.DB.prepare(
      `SELECT id, sealed, from_public_key, state, created_at FROM requests
       WHERE to_key_hash = ?1 AND state IN ('waiting', 'closed') AND expires_at > ?2
       ORDER BY created_at LIMIT 100`,
    ).bind(keyHash, now.toISOString()),
    env.DB.prepare(
      `SELECT id, answer FROM requests WHERE from_key_hash = ?1 AND state = 'answered' AND expires_at > ?2
       ORDER BY created_at LIMIT 100`,
    ).bind(keyHash, now.toISOString()),
  ]);
  return json(200, {
    asked: asked.results.map((row) =>
      row.state === "closed"
        ? { id: row.id, closed: true }
        : { id: row.id, sealed: row.sealed, key: row.from_public_key, created_at: row.created_at },
    ),
    answers: answers.results.map((row) => ({ id: row.id, answer: row.answer })),
  });
}

/// The person asked answers (declines), sealed to the asker: only a
/// request to them, still waiting.
async function answerRequest(id: string, request: Request, env: Env): Promise<Response> {
  const key = bearer(request);
  if (!key) return text(401, "A key is needed");
  const body = await smallJSON<{ sealed?: unknown }>(request);
  const sealed = typeof body?.sealed === "string" ? body.sealed : "";
  if (!isSealed(sealed)) return text(400, "Bad request");
  const keyHash = await sha256(key);
  const now = new Date();
  const result = await env.DB.prepare(
    `UPDATE requests SET state = 'answered', answer = ?1, sealed = NULL
     WHERE id = ?2 AND state = 'waiting' AND expires_at > ?3 AND to_key_hash = ?4`,
  )
    .bind(sealed, id, now.toISOString(), keyHash)
    .run();
  if (result.meta.changes === 1) return text(200, "Answered");
  return (await isAskedOf(id, keyHash, env)) ? text(409, "Not waiting") : text(404, "Not found");
}

/// The asker closes their request (cancelled, or paid): it goes from the
/// other's iPhone, and the pair may ask again. The person asked drops one
/// from someone they don't know: it is wiped without a word to the asker,
/// for whom it waits until it expires.
async function closeRequest(id: string, request: Request, env: Env): Promise<Response> {
  const key = bearer(request);
  if (!key) return text(401, "A key is needed");
  const keyHash = await sha256(key);
  const closed = await env.DB.prepare(
    "UPDATE requests SET state = 'closed', sealed = NULL, answer = NULL WHERE id = ?1 AND from_key_hash = ?2",
  )
    .bind(id, keyHash)
    .run();
  if (closed.meta.changes === 1) return text(200, "Closed");
  if (!(await isAskedOf(id, keyHash, env))) return text(404, "Not found");
  await env.DB.prepare("UPDATE requests SET state = 'dropped', sealed = NULL WHERE id = ?1 AND state = 'waiting'")
    .bind(id)
    .run();
  return text(200, "Dropped");
}

/// Delete All Data: every request the caller sent is closed, and every one
/// waiting for them dropped, their sealed parts wiped.
async function eraseRequests(request: Request, env: Env): Promise<Response> {
  const key = bearer(request);
  if (!key) return text(401, "A key is needed");
  const keyHash = await sha256(key);
  await env.DB.batch([
    env.DB.prepare("UPDATE requests SET state = 'closed', sealed = NULL, answer = NULL WHERE from_key_hash = ?1").bind(keyHash),
    env.DB.prepare("UPDATE requests SET state = 'dropped', sealed = NULL WHERE state = 'waiting' AND to_key_hash = ?1").bind(
      keyHash,
    ),
  ]);
  return text(200, "Erased");
}

// MARK: Push tokens

/// Ties this iPhone's APNs token to the owner's key, so a request to the
/// numbers it lists wakes StarHash there (`notifyRequest`), in place of
/// `replaces`, the token it had before. Only from a key listed with
/// requests on: there is nothing else to wake it for. `sandbox` says which
/// APNs the token is for (a build Xcode signed for development).
async function putPushToken(request: Request, env: Env): Promise<Response> {
  const key = bearer(request);
  if (!key) return text(401, "A key is needed");
  const body = await smallJSON<{ token?: unknown; sandbox?: unknown; replaces?: unknown }>(request);
  if (!body) return text(400, "Bad request");
  const token = typeof body.token === "string" ? body.token.toLowerCase() : "";
  const replaces = body.replaces === undefined || body.replaces === null ? null : String(body.replaces).toLowerCase();
  if (!TOKEN.test(token) || typeof body.sandbox !== "boolean" || (replaces !== null && !TOKEN.test(replaces))) {
    return text(400, "Bad request");
  }
  const keyHash = await sha256(key);
  const now = new Date();
  const takes = await env.DB.prepare("SELECT 1 AS yes FROM directory_keys WHERE key_hash = ?1 AND updated_at > ?2")
    .bind(keyHash, lapsedBefore(now))
    .first();
  if (!takes) return text(404, "Not listed");
  await env.DB.batch([
    ...(replaces ? [env.DB.prepare("DELETE FROM push_tokens WHERE key_hash = ?1 AND token = ?2").bind(keyHash, replaces)] : []),
    env.DB.prepare(
      `INSERT INTO push_tokens (key_hash, token, sandbox, updated_at) VALUES (?1, ?2, ?3, ?4)
       ON CONFLICT(key_hash, token) DO UPDATE SET sandbox = ?3, updated_at = ?4`,
    ).bind(keyHash, token, body.sandbox ? 1 : 0, now.toISOString()),
    env.DB.prepare(
      `DELETE FROM push_tokens WHERE key_hash = ?1 AND token NOT IN
       (SELECT token FROM push_tokens WHERE key_hash = ?1 ORDER BY updated_at DESC LIMIT ?2)`,
    ).bind(keyHash, MAX_TOKENS_PER_KEY),
  ]);
  return text(200, "Saved");
}

/// Unties `token` from the owner's key (Show My Name or word of requests
/// turned off, Delete All Data, a build without push), or every token
/// under it when the body names none.
async function deletePushToken(request: Request, env: Env): Promise<Response> {
  const key = bearer(request);
  if (!key) return text(401, "A key is needed");
  const body = await smallJSON<{ token?: unknown }>(request);
  const token = body?.token === undefined ? null : String(body.token).toLowerCase();
  if (token !== null && !TOKEN.test(token)) return text(400, "Bad request");
  const keyHash = await sha256(key);
  await (token
    ? env.DB.prepare("DELETE FROM push_tokens WHERE key_hash = ?1 AND token = ?2").bind(keyHash, token)
    : env.DB.prepare("DELETE FROM push_tokens WHERE key_hash = ?1").bind(keyHash)
  ).run();
  return text(200, "Deleted");
}

/// Whether request `id` was made to `keyHash`.
async function isAskedOf(id: string, keyHash: string, env: Env): Promise<boolean> {
  const row = await env.DB.prepare("SELECT 1 AS yes FROM requests WHERE id = ?1 AND to_key_hash = ?2").bind(id, keyHash).first();
  return row !== null;
}

function isSealed(value: string): boolean {
  return value.length >= 64 && value.length <= MAX_SEALED && BASE64.test(value);
}

/// A JSON body of a few kilobytes at most, or null.
async function smallJSON<T>(request: Request): Promise<T | null> {
  const body = await request.text();
  if (body.length > 4 * MAX_SEALED) return null;
  try {
    const parsed = JSON.parse(body);
    return parsed && typeof parsed === "object" ? (parsed as T) : null;
  } catch {
    return null;
  }
}

/// The number as the directory keeps it: an HMAC under the Worker's
/// secret, so a copy of the table gives no number back.
async function numberHash(number: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, [
    "sign",
  ]);
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(number));
  return hex(signature);
}

async function getPhoto(id: string, env: Env): Promise<Response> {
  const row = await env.DB.prepare("SELECT data FROM photos WHERE id = ?1").bind(id).first<{ data: number[] }>();
  if (!row) return text(404, "Not found");
  return new Response(new Uint8Array(row.data), {
    headers: {
      "Content-Type": "image/jpeg",
      // A replaced photo shows within the hour.
      "Cache-Control": "public, max-age=3600",
    },
  });
}

async function putPhoto(id: string, request: Request, env: Env): Promise<Response> {
  const key = bearer(request);
  if (!key) return text(401, "A key is needed");
  if (request.headers.get("Content-Type") !== "image/jpeg") return text(415, "Only a JPEG");
  const body = await request.arrayBuffer();
  if (body.byteLength === 0 || body.byteLength > MAX_PHOTO_BYTES) return text(413, "Too large");
  if (!isJPEG(body)) return text(415, "Only a JPEG");
  const keyHash = await sha256(key);
  // The first upload claims the id for its key; later ones replace it
  // only when their key matches, in the one statement, so two uploads at
  // once can't both claim it.
  const result = await env.DB.prepare(
    `INSERT INTO photos (id, key_hash, data, updated_at) VALUES (?1, ?2, ?3, ?4)
     ON CONFLICT(id) DO UPDATE SET data = ?3, updated_at = ?4 WHERE photos.key_hash = ?2`,
  )
    .bind(id, keyHash, body, new Date().toISOString())
    .run();
  if (result.meta.changes === 0) return text(403, "Not yours");
  return text(200, "Saved");
}

async function deletePhoto(id: string, request: Request, env: Env): Promise<Response> {
  const key = bearer(request);
  if (!key) return text(401, "A key is needed");
  const keyHash = await sha256(key);
  const row = await env.DB.prepare("SELECT key_hash FROM photos WHERE id = ?1").bind(id).first<{ key_hash: string }>();
  if (!row) return text(200, "Gone");
  if (row.key_hash !== keyHash) return text(403, "Not yours");
  await env.DB.prepare("DELETE FROM photos WHERE id = ?1 AND key_hash = ?2").bind(id, keyHash).run();
  return text(200, "Deleted");
}

async function ping(request: Request, env: Env): Promise<Response> {
  let body: { id?: unknown; version?: unknown };
  try {
    body = await request.json();
  } catch {
    return text(400, "Bad request");
  }
  const id = typeof body.id === "string" ? body.id.toLowerCase() : "";
  if (!UUID.test(id)) return text(400, "Bad request");
  const version = typeof body.version === "string" ? body.version.slice(0, 32) : null;
  const today = kigaliDate(new Date());
  await env.DB.batch([
    env.DB.prepare(
      `INSERT INTO installs (id, first_seen, last_seen, version) VALUES (?1, ?2, ?2, ?3)
       ON CONFLICT(id) DO UPDATE SET last_seen = ?2, version = ?3`,
    ).bind(id, today, version),
    env.DB.prepare("INSERT OR IGNORE INTO active_days (day, id) VALUES (?1, ?2)").bind(today, id),
  ]);
  return text(200, "Counted");
}

/// The date in Kigali (UTC+2 all year, no daylight saving), where the people
/// using StarHash are, so a day of use is their day and not UTC's.
function kigaliDate(now: Date): string {
  return new Date(now.getTime() + 2 * 3600 * 1000).toISOString().slice(0, 10);
}

function bearer(request: Request): string | null {
  const header = request.headers.get("Authorization") ?? "";
  const key = header.startsWith("Bearer ") ? header.slice(7).trim() : "";
  // The app's keys are 32 random bytes in base64.
  return key.length >= 32 && key.length <= 128 ? key : null;
}

function isJPEG(body: ArrayBuffer): boolean {
  const bytes = new Uint8Array(body, 0, Math.min(3, body.byteLength));
  return bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
}

async function sha256(value: string): Promise<string> {
  return hex(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)));
}

function hex(bytes: ArrayBuffer): string {
  return [...new Uint8Array(bytes)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

function text(status: number, body: string): Response {
  return new Response(body, { status, headers: { "Content-Type": "text/plain; charset=utf-8" } });
}
