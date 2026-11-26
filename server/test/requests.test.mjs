// The Worker run locally (`wrangler dev`, its own D1 in a temporary
// folder), driven over HTTP as the app drives it: the directory's keys, and
// requests sent, read, answered, closed, dropped and expired, with their
// limits. `npm test` from server/. Nothing here reaches the live Worker.

import { execFileSync, spawn } from "node:child_process";
import { randomBytes, randomUUID } from "node:crypto";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, before, describe, test } from "node:test";
import assert from "node:assert/strict";

const PORT = 8799;
const BASE = `http://127.0.0.1:${PORT}`;
const state = mkdtempSync(join(tmpdir(), "starhash-worker-"));
const wrangler = join(import.meta.dirname, "..", "node_modules", ".bin", "wrangler");
let dev;

function d1(command) {
  const out = execFileSync(
    wrangler,
    ["d1", "execute", "starhash", "--local", "--persist-to", state, "--json", "--command", command],
    { cwd: join(import.meta.dirname, ".."), encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] },
  );
  return JSON.parse(out)[0].results;
}

before(async () => {
  execFileSync(wrangler, ["d1", "execute", "starhash", "--local", "--persist-to", state, "--file", "schema.sql"], {
    cwd: join(import.meta.dirname, ".."),
    stdio: "ignore",
  });
  dev = spawn(
    wrangler,
    ["dev", "--port", String(PORT), "--ip", "127.0.0.1", "--persist-to", state, "--var", "DIRECTORY_SECRET:test-secret", "--test-scheduled"],
    { cwd: join(import.meta.dirname, ".."), stdio: ["ignore", "pipe", "pipe"] },
  );
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("wrangler dev did not start")), 60_000);
    const watch = (chunk) => {
      if (String(chunk).includes("Ready on")) {
        clearTimeout(timer);
        resolve();
      }
    };
    dev.stdout.on("data", watch);
    dev.stderr.on("data", watch);
  });
});

after(() => {
  dev?.kill();
  rmSync(state, { recursive: true, force: true });
});

/// An owner: a secret key, a number, and the public key their iPhone
/// would make (32 random bytes stand in: the server never opens a seal).
function owner(number, { publicKey = true } = {}) {
  return {
    key: randomBytes(32).toString("base64"),
    number,
    publicKey: publicKey ? randomBytes(32).toString("base64") : null,
  };
}

const sealed = () => randomBytes(160).toString("base64");

async function call(method, path, { key, body } = {}) {
  const headers = {};
  if (key) headers.Authorization = `Bearer ${key}`;
  if (body !== undefined) headers["Content-Type"] = "application/json";
  const response = await fetch(BASE + path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  const type = response.headers.get("Content-Type") ?? "";
  return { status: response.status, body: type.includes("json") ? await response.json() : await response.text() };
}

async function list(person, name = "Someone") {
  const body = { numbers: [person.number], name };
  if (person.publicKey) body.key = person.publicKey;
  const { status } = await call("PUT", "/v1/directory", { key: person.key, body });
  assert.equal(status, 200);
}

const ask = (from, to, extra = {}) =>
  call("POST", "/v1/requests", {
    key: from.key,
    body: { id: randomUUID(), to: to.number, from: from.number, sealed: sealed(), ...extra },
  });

describe("the directory's keys", () => {
  test("a listing carries its public key to lookups, and loses it when sent without", async () => {
    const ariane = owner("0788100001");
    await list(ariane, "Ariane");
    let found = await call("POST", "/v1/directory/lookup", { body: { number: ariane.number } });
    assert.equal(found.status, 200);
    assert.deepEqual(found.body, { name: "Ariane", photo: null, key: ariane.publicKey });

    await call("PUT", "/v1/directory", { key: ariane.key, body: { numbers: [ariane.number], name: "Ariane" } });
    found = await call("POST", "/v1/directory/lookup", { body: { number: ariane.number } });
    assert.equal(found.body.key, null);
  });

  test("a key that is not 32 bytes is refused", async () => {
    const eric = owner("0788100002");
    const { status } = await call("PUT", "/v1/directory", {
      key: eric.key,
      body: { numbers: [eric.number], name: "Eric", key: "short" },
    });
    assert.equal(status, 400);
  });

  test("deleting the listing deletes its key", async () => {
    const grace = owner("0788100003");
    await list(grace, "Grace");
    await call("DELETE", "/v1/directory", { key: grace.key });
    assert.equal(d1(`SELECT COUNT(*) AS n FROM directory_keys WHERE public_key = '${grace.publicKey}'`)[0].n, 0);
  });
});

describe("requests", () => {
  const jean = owner("0788200001");
  const shima = owner("0788200002");
  const noKey = owner("0788200003", { publicKey: false });

  before(async () => {
    await list(jean, "Jean");
    await list(shima, "Shima");
    await list(noKey, "Old app");
  });

  test("only to someone on StarHash who takes requests, and only from the asker's own number", async () => {
    assert.equal((await ask(jean, { number: "0788299999" })).status, 404);
    assert.equal((await ask(jean, noKey)).status, 404);
    assert.equal((await ask(jean, shima, { from: shima.number })).status, 403);
    assert.equal((await ask(noKey, shima)).status, 403);
    assert.equal((await ask(jean, jean)).status, 400);
    assert.equal((await ask(jean, shima, { sealed: "not base64!" })).status, 400);
    assert.equal((await ask(jean, shima, { sealed: "A".repeat(4096) })).status, 400);
    assert.equal((await call("POST", "/v1/requests", { body: { to: shima.number } })).status, 401);
  });

  test("reaches the person asked, sealed, with the asker's public key; answered, it goes back sealed", async () => {
    const id = randomUUID();
    const content = sealed();
    const sent = await ask(jean, shima, { id, sealed: content });
    assert.equal(sent.status, 200);
    assert.equal(sent.body.id, id);
    const week = new Date(sent.body.expires_at) - new Date(sent.body.created_at);
    assert.equal(week, 7 * 86400 * 1000);

    // The server keeps no number, only the directory's hashes.
    const row = d1(`SELECT * FROM requests WHERE id = '${id}'`)[0];
    assert.ok(!JSON.stringify(row).includes(jean.number) && !JSON.stringify(row).includes(shima.number));

    const inbox = await call("GET", "/v1/requests", { key: shima.key });
    assert.deepEqual(inbox.body.asked, [{ id, sealed: content, key: jean.publicKey, created_at: sent.body.created_at }]);
    assert.deepEqual((await call("GET", "/v1/requests", { key: jean.key })).body, { asked: [], answers: [] });

    // One waiting request per pair.
    assert.equal((await ask(jean, shima)).status, 409);
    // Only the person asked answers it.
    assert.equal((await call("POST", `/v1/requests/${id}/answer`, { key: noKey.key, body: { sealed: sealed() } })).status, 404);
    const answer = sealed();
    assert.equal((await call("POST", `/v1/requests/${id}/answer`, { key: shima.key, body: { sealed: answer } })).status, 200);
    assert.equal((await call("POST", `/v1/requests/${id}/answer`, { key: shima.key, body: { sealed: answer } })).status, 409);

    assert.deepEqual((await call("GET", "/v1/requests", { key: jean.key })).body.answers, [{ id, answer }]);
    assert.deepEqual((await call("GET", "/v1/requests", { key: shima.key })).body.asked, []);
    // Answered, the pair may ask again.
    const again = await ask(jean, shima);
    assert.equal(again.status, 200);

    // The asker closes both: the answer is wiped, and the person asked
    // sees the waiting one closed, so its card goes.
    assert.equal((await call("DELETE", `/v1/requests/${id}`, { key: jean.key })).status, 200);
    assert.equal((await call("DELETE", `/v1/requests/${again.body.id}`, { key: jean.key })).status, 200);
    assert.deepEqual((await call("GET", "/v1/requests", { key: jean.key })).body.answers, []);
    // Both read as closed: the declined one too, which the iPhone asked
    // already holds as declined.
    assert.deepEqual((await call("GET", "/v1/requests", { key: shima.key })).body.asked, [
      { id, closed: true },
      { id: again.body.id, closed: true },
    ]);
    assert.equal(d1(`SELECT COUNT(*) AS n FROM requests WHERE id = '${id}' AND (sealed IS NOT NULL OR answer IS NOT NULL)`)[0].n, 0);
    // Nobody else closes it.
    assert.equal((await call("DELETE", `/v1/requests/${id}`, { key: noKey.key })).status, 404);
  });

  test("dropped by the person asked, it is wiped, and still waits for the asker's limits", async () => {
    const sent = await ask(shima, jean);
    assert.equal(sent.status, 200);
    assert.equal((await call("DELETE", `/v1/requests/${sent.body.id}`, { key: jean.key })).status, 200);
    assert.deepEqual((await call("GET", "/v1/requests", { key: jean.key })).body.asked, []);
    assert.equal(d1(`SELECT sealed FROM requests WHERE id = '${sent.body.id}'`)[0].sealed, null);
    // The asker hears nothing: it waits for them until it expires, so
    // they cannot ask again meanwhile.
    assert.deepEqual((await call("GET", "/v1/requests", { key: shima.key })).body.answers, []);
    assert.equal((await ask(shima, jean)).status, 409);
  });

  test("someone who lists the asked number later cannot read, answer or drop the request", async () => {
    const asker = owner("0788600001");
    const asked = owner("0788600002");
    await list(asker);
    await list(asked);
    const sent = await ask(asker, asked);
    // Listing a number needs no proof of the SIM: a thief lists it too.
    const thief = { ...owner(asked.number) };
    await list(thief, "Thief");
    assert.deepEqual((await call("GET", "/v1/requests", { key: thief.key })).body.asked, []);
    assert.equal((await call("POST", `/v1/requests/${sent.body.id}/answer`, { key: thief.key, body: { sealed: sealed() } })).status, 404);
    assert.equal((await call("DELETE", `/v1/requests/${sent.body.id}`, { key: thief.key })).status, 404);
    assert.equal((await call("GET", "/v1/requests", { key: asked.key })).body.asked.length, 1);
    // And with two listings, nobody can ask that number at all.
    const another = owner("0788600003");
    await list(another);
    assert.equal((await ask(another, asked)).status, 404);
  });

  test("twenty a day per key", async () => {
    const busy = owner("0788300000");
    await list(busy, "Busy");
    const people = Array.from({ length: 21 }, (_, i) => owner(`07883${String(i + 1).padStart(5, "0")}`));
    for (const person of people) await list(person);
    let sent = 0;
    for (const person of people.slice(0, 20)) {
      if ((await ask(busy, person)).status === 200) sent += 1;
    }
    assert.equal(sent, 20);
    assert.equal((await ask(busy, people[20])).status, 429);
    // Closing them does not give any back.
    const { id } = d1(`SELECT id FROM requests WHERE state = 'waiting' LIMIT 1`)[0];
    await call("DELETE", `/v1/requests/${id}`, { key: busy.key });
    assert.equal((await ask(busy, people[20])).status, 429);
  });

  test("Delete All Data closes what the owner sent and drops what waits for them", async () => {
    const asker = owner("0788400001");
    const asked = owner("0788400002");
    await list(asker);
    await list(asked);
    const out = await ask(asker, asked);
    const into = await ask(asked, asker);
    assert.equal((await call("DELETE", "/v1/requests", { key: asker.key })).status, 200);
    assert.deepEqual((await call("GET", "/v1/requests", { key: asked.key })).body.asked, [{ id: out.body.id, closed: true }]);
    assert.equal(d1(`SELECT state, sealed FROM requests WHERE id = '${into.body.id}'`)[0].state, "dropped");
  });
});

describe("expiry", () => {
  test("a request past its week is not shown, and the nightly run deletes it and lapsed keys", async () => {
    const asker = owner("0788500001");
    const asked = owner("0788500002");
    await list(asker);
    await list(asked);
    const sent = await ask(asker, asked);
    const past = new Date(Date.now() - 60_000).toISOString();
    d1(`UPDATE requests SET expires_at = '${past}' WHERE id = '${sent.body.id}'`);
    assert.deepEqual((await call("GET", "/v1/requests", { key: asked.key })).body.asked, []);
    // Expired, it no longer holds the pair.
    assert.equal((await ask(asker, asked)).status, 200);

    const lapsed = new Date(Date.now() - 46 * 86400 * 1000).toISOString();
    d1(`UPDATE directory_keys SET updated_at = '${lapsed}' WHERE public_key = '${asker.publicKey}'`);
    assert.equal((await fetch(`${BASE}/__scheduled?cron=0+1+*+*+*`)).status, 200);
    assert.equal(d1(`SELECT COUNT(*) AS n FROM requests WHERE id = '${sent.body.id}'`)[0].n, 0);
    assert.equal(d1(`SELECT COUNT(*) AS n FROM directory_keys WHERE public_key = '${asker.publicKey}'`)[0].n, 0);
    assert.equal(d1(`SELECT COUNT(*) AS n FROM requests WHERE expires_at > '${new Date().toISOString()}'`)[0].n > 0, true);
  });
});
