// Push, with APNs stood in for by a server here that checks what it is
// sent (the JWT's signature included): tokens tied to a listed key, a
// request waking the iPhones of the person asked with a push that says
// nothing of it, tokens going with the listing, and nothing pushed without
// the APNs secrets. Two Workers run locally (`wrangler dev`), each with a
// D1 of its own: one with the secrets, one without. `npm test` from
// server/. Nothing here reaches the live Worker or APNs.

import { execFileSync, spawn } from "node:child_process";
import { createPublicKey, generateKeyPairSync, randomBytes, randomUUID, verify } from "node:crypto";
import { mkdtempSync, rmSync } from "node:fs";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, before, describe, test } from "node:test";
import assert from "node:assert/strict";

const SERVER = join(import.meta.dirname, "..");
const wrangler = join(SERVER, "node_modules", ".bin", "wrangler");
const APNS_PORT = 8796;
const KEY_ID = "ABC123DEFG";
const TEAM_ID = "W46T258AXM";
const apnsKey = generateKeyPairSync("ec", { namedCurve: "P-256" });
const apnsPEM = apnsKey.privateKey.export({ type: "pkcs8", format: "pem" });

// MARK: APNs, stood in for

/// Every push received: which Worker sent it (the first part of the path),
/// whether to the sandbox, the token, the headers and the body.
const pushes = [];
const apns = createServer((request, response) => {
  let body = "";
  request.on("data", (chunk) => (body += chunk));
  request.on("end", () => {
    const [, worker, service, , , token] = request.url.split("/");
    pushes.push({ worker, sandbox: service === "sandbox", token, headers: request.headers, body });
    // Tokens made to fail, as APNs answers for an app deleted and for a
    // token that is not one.
    if (token.startsWith("dead")) {
      response.writeHead(410, { "Content-Type": "application/json" }).end(JSON.stringify({ reason: "Unregistered" }));
    } else if (token.startsWith("bad0")) {
      response.writeHead(400, { "Content-Type": "application/json" }).end(JSON.stringify({ reason: "BadDeviceToken" }));
    } else {
      response.writeHead(200).end();
    }
  });
});

const pushesFrom = (worker) => pushes.filter((push) => push.worker === worker);

async function waitForPushes(worker, count) {
  const deadline = Date.now() + 10_000;
  while (pushesFrom(worker).length < count && Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  return pushesFrom(worker);
}

// MARK: The Workers

/// A Worker on `port` with a D1 of its own, its pushes sent to the stand-in
/// under `/<name>`.
function worker(name, port, inspectorPort, vars) {
  const state = mkdtempSync(join(tmpdir(), `starhash-${name}-`));
  const base = `http://127.0.0.1:${port}`;
  let dev;
  return {
    base,
    name,
    async start() {
      execFileSync(wrangler, ["d1", "execute", "starhash", "--local", "--persist-to", state, "--file", "schema.sql"], {
        cwd: SERVER,
        stdio: "ignore",
      });
      const apnsURL = `http://127.0.0.1:${APNS_PORT}/${name}`;
      const all = { DIRECTORY_SECRET: "test-secret", APNS_URL: `${apnsURL}/production`, APNS_SANDBOX_URL: `${apnsURL}/sandbox`, ...vars };
      const args = ["dev", "--port", String(port), "--ip", "127.0.0.1", "--inspector-port", String(inspectorPort), "--persist-to", state];
      for (const [key, value] of Object.entries(all)) args.push("--var", `${key}:${value}`);
      dev = spawn(wrangler, [...args, "--test-scheduled"], { cwd: SERVER, stdio: ["ignore", "pipe", "pipe"] });
      await new Promise((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error(`wrangler dev (${name}) did not start`)), 60_000);
        const watch = (chunk) => {
          if (String(chunk).includes("Ready on")) {
            clearTimeout(timer);
            resolve();
          }
        };
        dev.stdout.on("data", watch);
        dev.stderr.on("data", watch);
      });
    },
    stop() {
      dev?.kill();
      rmSync(state, { recursive: true, force: true });
    },
    d1(command) {
      const out = execFileSync(
        wrangler,
        ["d1", "execute", "starhash", "--local", "--persist-to", state, "--json", "--command", command],
        { cwd: SERVER, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] },
      );
      return JSON.parse(out)[0].results;
    },
    async call(method, path, { key, body } = {}) {
      const headers = {};
      if (key) headers.Authorization = `Bearer ${key}`;
      if (body !== undefined) headers["Content-Type"] = "application/json";
      const response = await fetch(base + path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
      const type = response.headers.get("Content-Type") ?? "";
      return { status: response.status, body: type.includes("json") ? await response.json() : await response.text() };
    },
  };
}

const pushing = worker("pushing", 8798, 9238, { APNS_KEY: apnsPEM, APNS_KEY_ID: KEY_ID, APNS_TEAM_ID: TEAM_ID });
const plain = worker("plain", 8797, 9237, {});

before(async () => {
  await new Promise((resolve) => apns.listen(APNS_PORT, "127.0.0.1", resolve));
  await Promise.all([pushing.start(), plain.start()]);
});

after(() => {
  pushing.stop();
  plain.stop();
  apns.close();
});

// MARK: Owners

/// An owner: a secret key, a number, and the public key their iPhone would
/// make (32 random bytes stand in: the server never opens a seal).
function owner(number, { publicKey = true } = {}) {
  return {
    key: randomBytes(32).toString("base64"),
    number,
    publicKey: publicKey ? randomBytes(32).toString("base64") : null,
  };
}

/// A token as APNs gives one: 32 bytes, in hex, starting with `start`.
const token = (start = "") => start + randomBytes(32).toString("hex").slice(start.length);

async function list(server, person, name = "Someone") {
  const body = { numbers: [person.number], name };
  if (person.publicKey) body.key = person.publicKey;
  assert.equal((await server.call("PUT", "/v1/directory", { key: person.key, body })).status, 200);
}

const register = (server, person, hex, extra = {}) =>
  server.call("PUT", "/v1/push", { key: person.key, body: { token: hex, sandbox: false, ...extra } });

const ask = (server, from, to) =>
  server.call("POST", "/v1/requests", {
    key: from.key,
    body: { id: randomUUID(), to: to.number, from: from.number, sealed: randomBytes(160).toString("base64") },
  });

function base64url(text) {
  return Buffer.from(text, "base64url");
}

// MARK: Tests

describe("tokens", () => {
  test("taken only from a key listed with requests on, and only as APNs makes them", async () => {
    const ariane = owner("0788300001");
    const old = owner("0788300002", { publicKey: false });
    assert.equal((await register(pushing, ariane, token())).status, 404);
    await list(pushing, old, "Old app");
    assert.equal((await register(pushing, old, token())).status, 404);
    await list(pushing, ariane, "Ariane");
    assert.equal((await register(pushing, ariane, token())).status, 200);
    assert.equal((await register(pushing, ariane, "abc")).status, 400);
    assert.equal((await register(pushing, ariane, token(), { sandbox: "yes" })).status, 400);
    assert.equal((await register(pushing, ariane, token(), { replaces: "nope" })).status, 400);
    assert.equal((await pushing.call("PUT", "/v1/push", { body: { token: token(), sandbox: false } })).status, 401);
  });

  test("a new token replaces the old one, and a key keeps three at most", async () => {
    const eric = owner("0788300003");
    await list(pushing, eric, "Eric");
    const first = token(), second = token();
    await register(pushing, eric, first);
    await register(pushing, eric, second, { replaces: first });
    const keyHash = pushing.d1(`SELECT key_hash FROM push_tokens WHERE token = '${second}'`)[0].key_hash;
    const count = () => pushing.d1(`SELECT COUNT(*) AS n FROM push_tokens WHERE key_hash = '${keyHash}'`)[0].n;
    assert.equal(count(), 1);
    for (let i = 0; i < 4; i++) {
      await register(pushing, eric, token());
      await new Promise((resolve) => setTimeout(resolve, 5));
    }
    assert.equal(count(), 3);
  });

  test("they go with the listing, when it stops taking requests, and when deleted", async () => {
    const grace = owner("0788300004");
    await list(pushing, grace, "Grace");
    const hex = token();
    const count = () => pushing.d1(`SELECT COUNT(*) AS n FROM push_tokens WHERE token = '${hex}'`)[0].n;
    await register(pushing, grace, hex);
    assert.equal(count(), 1);
    // Listed again without its key: requests off.
    await pushing.call("PUT", "/v1/directory", { key: grace.key, body: { numbers: [grace.number], name: "Grace" } });
    assert.equal(count(), 0);
    await list(pushing, grace, "Grace");
    await register(pushing, grace, hex);
    await pushing.call("DELETE", "/v1/directory", { key: grace.key });
    assert.equal(count(), 0);
    await list(pushing, grace, "Grace");
    await register(pushing, grace, hex);
    // Someone else's key cannot remove it.
    await pushing.call("DELETE", "/v1/push", { key: owner("0788300005").key, body: { token: hex } });
    assert.equal(count(), 1);
    assert.equal((await pushing.call("DELETE", "/v1/push", { key: grace.key, body: { token: hex } })).status, 200);
    assert.equal(count(), 0);
    await register(pushing, grace, hex);
    await register(pushing, grace, token());
    assert.equal((await pushing.call("DELETE", "/v1/push", { key: grace.key })).status, 200);
    assert.equal(count(), 0);
  });

  test("a token not sent again for 45 days is deleted that night", async () => {
    const jean = owner("0788300006");
    await list(pushing, jean, "Jean");
    const hex = token();
    await register(pushing, jean, hex);
    const lapsed = new Date(Date.now() - 46 * 86400 * 1000).toISOString();
    pushing.d1(`UPDATE push_tokens SET updated_at = '${lapsed}' WHERE token = '${hex}'`);
    assert.equal((await fetch(`${pushing.base}/__scheduled?cron=0+1+*+*+*`)).status, 200);
    assert.equal(pushing.d1(`SELECT COUNT(*) AS n FROM push_tokens WHERE token = '${hex}'`)[0].n, 0);
  });
});

describe("pushes", () => {
  test("a request wakes every iPhone of the person asked, with a push that says nothing of it", async () => {
    const asker = owner("0788400001");
    const asked = owner("0788400002");
    await list(pushing, asker, "Ariane Uwase");
    await list(pushing, asked, "Bosco");
    const phone = token("aa"), sandboxed = token("bb");
    await register(pushing, asked, phone);
    await register(pushing, asked, sandboxed, { sandbox: true });
    // The asker's own iPhone is not told of what they asked.
    const askersPhone = token("cc");
    await register(pushing, asker, askersPhone);
    const before = pushesFrom("pushing").length;

    const sent = await ask(pushing, asker, asked);
    assert.equal(sent.status, 200);
    const received = (await waitForPushes("pushing", before + 2)).slice(before);
    assert.equal(received.length, 2);
    assert.deepEqual(received.map((push) => [push.token, push.sandbox]).sort(), [
      [phone, false],
      [sandboxed, true],
    ]);

    for (const push of received) {
      assert.equal(push.headers["apns-topic"], "com.devbyshima.starhash");
      assert.equal(push.headers["apns-push-type"], "alert");
      assert.equal(push.headers["apns-priority"], "10");
      assert.equal(push.headers["apns-collapse-id"], "requests");
      assert.equal(push.headers["apns-expiration"], String(Math.floor(Date.parse(sent.body.expires_at) / 1000)));
      // "New request", in the iPhone's language, and nothing else: no
      // amount, no name, no number.
      assert.deepEqual(JSON.parse(push.body), {
        aps: { alert: { "loc-key": "New request" }, sound: "default", "content-available": 1, "thread-id": "requests" },
      });
      for (const secret of [asker.number, asked.number, "Ariane", "Bosco", sent.body.id]) {
        assert.ok(!push.body.includes(secret) && !JSON.stringify(push.headers).includes(secret));
      }

      // The JWT: ES256 under the key's id, from the team, signed by the key.
      const [scheme, jwt] = push.headers.authorization.split(" ");
      assert.equal(scheme, "bearer");
      const [header, claims, signature] = jwt.split(".");
      assert.deepEqual(JSON.parse(base64url(header)), { alg: "ES256", kid: KEY_ID });
      const { iss, iat } = JSON.parse(base64url(claims));
      assert.equal(iss, TEAM_ID);
      assert.ok(Math.abs(iat - Date.now() / 1000) < 120);
      const publicKey = createPublicKey(apnsKey.privateKey);
      assert.ok(
        verify("sha256", Buffer.from(`${header}.${claims}`), { key: publicKey, dsaEncoding: "ieee-p1363" }, base64url(signature)),
      );
    }
    assert.ok(!received.some((push) => push.token === askersPhone));
  });

  test("a request refused pushes nothing", async () => {
    const asker = owner("0788400003");
    const asked = owner("0788400004");
    await list(pushing, asker, "Asker");
    await list(pushing, asked, "Asked");
    await register(pushing, asked, token());
    assert.equal((await ask(pushing, asker, asked)).status, 200);
    await waitForPushes("pushing", pushesFrom("pushing").length);
    const before = pushesFrom("pushing").length;
    // One waiting per pair: the second is refused, and no one is told.
    assert.equal((await ask(pushing, asker, asked)).status, 409);
    await new Promise((resolve) => setTimeout(resolve, 1500));
    assert.equal(pushesFrom("pushing").length, before);
  });

  test("a token APNs says is gone is deleted", async () => {
    const asker = owner("0788400005");
    const asked = owner("0788400006");
    await list(pushing, asker, "Asker");
    await list(pushing, asked, "Asked");
    const gone = token("dead"), bad = token("bad0"), fine = token("ee");
    for (const hex of [gone, bad, fine]) await register(pushing, asked, hex);
    const before = pushesFrom("pushing").length;
    assert.equal((await ask(pushing, asker, asked)).status, 200);
    await waitForPushes("pushing", before + 3);
    // The deletes follow the answers: give them a moment.
    const deadline = Date.now() + 5000;
    const left = () => pushing.d1(`SELECT token FROM push_tokens WHERE token IN ('${gone}', '${bad}', '${fine}')`).map((row) => row.token);
    while (left().length > 1 && Date.now() < deadline) await new Promise((resolve) => setTimeout(resolve, 100));
    assert.deepEqual(left(), [fine]);
  });

  test("without the APNs secrets nothing is pushed, though tokens are kept", async () => {
    const asker = owner("0788400007");
    const asked = owner("0788400008");
    await list(plain, asker, "Asker");
    await list(plain, asked, "Asked");
    assert.equal((await register(plain, asked, token())).status, 200);
    assert.equal((await ask(plain, asker, asked)).status, 200);
    await new Promise((resolve) => setTimeout(resolve, 1500));
    assert.equal(pushesFrom("plain").length, 0);
  });
});
