// StarHash's server, the one thing StarHash keeps off the iPhone.
//
// Photos: an owner who shares their photo with their QR code uploads it
// under a random id the app made; the code carries that id, so whoever
// scans it can fetch the photo, and no one can find a photo by a phone
// number. A secret key, kept on the owner's iPhone, is needed to replace or
// delete it: the server keeps only its hash.
//
// Installs: once a day the app sends a random id it made on its first
// launch and its version, so the number of people using StarHash can be
// counted. Nothing else: no number, no name, no transactions.

export interface Env {
  DB: D1Database;
}

/// A photo is one small JPEG, 600 points square at most.
const MAX_PHOTO_BYTES = 200 * 1024;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

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
    return text(404, "Not found");
  },
} satisfies ExportedHandler<Env>;

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
  const today = new Date().toISOString().slice(0, 10);
  await env.DB.prepare(
    `INSERT INTO installs (id, first_seen, last_seen, version) VALUES (?1, ?2, ?2, ?3)
     ON CONFLICT(id) DO UPDATE SET last_seen = ?2, version = ?3`,
  )
    .bind(id, today, version)
    .run();
  return text(200, "Counted");
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
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function text(status: number, body: string): Response {
  return new Response(body, { status, headers: { "Content-Type": "text/plain; charset=utf-8" } });
}
