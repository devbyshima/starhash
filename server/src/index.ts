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
// Installs: once each day it is used the app sends a random id it made on
// its first launch and its version, so the number of people using StarHash
// can be counted, in all (installs) and each day (active_days, by Kigali's
// date). Nothing else: no transactions.

export interface Env {
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

/// An owner has one SIM or two.
const MAX_NUMBERS = 2;
const MAX_NAME = 60;

/// An entry the app has not sent again in this long is left out of
/// lookups and deleted that night (`scheduled`): the app sends it each
/// week while it is in use, so one from a lost or wiped iPhone, or from a
/// deleted app, lapses, and stops hiding the number's new entry.
const ENTRY_LIFETIME_DAYS = 45;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
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
    return text(404, "Not found");
  },

  /// Each night (the cron in wrangler.toml): the directory's lapsed
  /// entries are deleted, not only left out of lookups.
  async scheduled(_controller: ScheduledController, env: Env): Promise<void> {
    await env.DB.prepare("DELETE FROM directory WHERE updated_at <= ?1").bind(lapsedBefore(new Date())).run();
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
  let body: { numbers?: unknown; name?: unknown; photo?: unknown };
  try {
    body = await request.json();
  } catch {
    return text(400, "Bad request");
  }
  const given = Array.isArray(body.numbers) ? body.numbers : [];
  const numbers = [...new Set(given.filter((n): n is string => typeof n === "string" && NUMBER.test(n)))];
  if (numbers.length === 0 || numbers.length > MAX_NUMBERS || numbers.length !== given.length) {
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
  ]);
  return text(200, "Saved");
}

/// Show My Name turned off, or the owner's numbers gone.
async function deleteEntry(request: Request, env: Env): Promise<Response> {
  const key = bearer(request);
  if (!key) return text(401, "A key is needed");
  await env.DB.prepare("DELETE FROM directory WHERE key_hash = ?1").bind(await sha256(key)).run();
  return text(200, "Deleted");
}

/// The name and photo listed for a number, or 404.
async function lookUp(request: Request, env: Env): Promise<Response> {
  const secret = env.DIRECTORY_SECRET;
  if (!secret) return text(404, "Not found");
  let body: { number?: unknown };
  try {
    body = await request.json();
  } catch {
    return text(400, "Bad request");
  }
  const number = typeof body.number === "string" ? body.number : "";
  if (!NUMBER.test(number)) return text(400, "Bad request");
  const since = lapsedBefore(new Date());
  const { results } = await env.DB.prepare(
    "SELECT name, photo_id FROM directory WHERE number_hash = ?1 AND updated_at > ?2 LIMIT 2",
  )
    .bind(await numberHash(number, secret), since)
    .all<{ name: string; photo_id: string | null }>();
  // Two iPhones listing one number: the server cannot tell which holds
  // the SIM, so it shows neither rather than maybe the wrong one.
  if (results.length !== 1) return text(404, "Not found");
  const entry = results[0];
  return new Response(JSON.stringify({ name: entry.name || null, photo: entry.photo_id }), {
    headers: { "Content-Type": "application/json", "Cache-Control": "private, max-age=300" },
  });
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

function text(status: number, body: string): Response {
  return new Response(body, { status, headers: { "Content-Type": "text/plain; charset=utf-8" } });
}
