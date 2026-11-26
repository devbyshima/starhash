-- One row per install of StarHash: a random id the app makes on its first
-- launch, and nothing about who uses it.
CREATE TABLE IF NOT EXISTS installs (
  id TEXT PRIMARY KEY,
  first_seen TEXT NOT NULL,
  last_seen TEXT NOT NULL,
  version TEXT
);

-- One row for each day an install was used, by Kigali's date: the same
-- random id and the day, so the people using StarHash each day (daily
-- active users) can be counted, and on any day since, not only today.
CREATE TABLE IF NOT EXISTS active_days (
  day TEXT NOT NULL,
  id TEXT NOT NULL,
  PRIMARY KEY (day, id)
) WITHOUT ROWID;

-- The days already known from before active_days, an install's first and
-- last: run again, it adds nothing.
INSERT OR IGNORE INTO active_days (day, id) SELECT first_seen, id FROM installs;
INSERT OR IGNORE INTO active_days (day, id) SELECT last_seen, id FROM installs;

-- One row per number an owner lists under Show My Name (on unless they turn
-- it off): the number as an HMAC under the Worker's DIRECTORY_SECRET, never
-- the number itself; the hash of the key their iPhone holds (the photo's);
-- the name they gave and their photo's id, either of which may be empty.
-- The app sends its rows again each week; lookups skip rows older than 45
-- days, and the Worker deletes them each night. Two keys listing one number
-- show neither.
CREATE TABLE IF NOT EXISTS directory (
  number_hash TEXT NOT NULL,
  key_hash TEXT NOT NULL,
  name TEXT NOT NULL,
  photo_id TEXT,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (number_hash, key_hash)
) WITHOUT ROWID;
CREATE INDEX IF NOT EXISTS directory_by_key ON directory (key_hash);

-- One row per shared photo: the random id an owner's QR code carries, the
-- hash of the key their iPhone holds (needed to replace or delete it), and
-- the JPEG itself, 200 KB at most. No number, no name.
CREATE TABLE IF NOT EXISTS photos (
  id TEXT PRIMARY KEY,
  key_hash TEXT NOT NULL,
  data BLOB NOT NULL,
  updated_at TEXT NOT NULL
);

-- One row per owner listed under Show My Name whose iPhone takes requests
-- from anywhere: the hash of their key (the directory's key_hash) and the
-- public half of a Curve25519 key their iPhone made, sent with the
-- listing. A request is sealed to it on the asker's iPhone, so the server
-- never reads one. A table of its own rather than a column on directory:
-- schema.sql is run again whole after each change, and SQLite cannot add a
-- column only when it is missing. Deleted with the listing, and each night
-- once not sent again for 45 days.
CREATE TABLE IF NOT EXISTS directory_keys (
  key_hash TEXT PRIMARY KEY,
  public_key TEXT NOT NULL,
  updated_at TEXT NOT NULL
) WITHOUT ROWID;

-- One row per request for money sent through the server: the id both
-- iPhones keep it under, the number asked (as the directory's HMAC) and the
-- hash of the key it was listed under then (only that key reads, answers or
-- drops it, though another may list the number later), the hash of the
-- asker's key and their public key, and what the asker's
-- iPhone sealed to the other's public key (who asks, how much, what for),
-- which the server cannot open. An answer (a decline) is sealed to the
-- asker the same way. Cancelled or dropped, the sealed part is wiped at
-- once; the row, only who asked whom and when, stays until its week is up
-- so the limits hold, and the Worker deletes it that night.
--
-- state: waiting; answered (the answer waits for the asker); closed (the
-- asker cancelled it, or it was paid); dropped (the person asked does not
-- know the asker, and the asker is never told, so for the asker's limits
-- it still waits).
CREATE TABLE IF NOT EXISTS requests (
  id TEXT PRIMARY KEY,
  to_hash TEXT NOT NULL,
  to_key_hash TEXT NOT NULL,
  from_key_hash TEXT NOT NULL,
  from_public_key TEXT NOT NULL,
  sealed TEXT,
  answer TEXT,
  state TEXT NOT NULL,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS requests_to ON requests (to_key_hash);
CREATE INDEX IF NOT EXISTS requests_from ON requests (from_key_hash, created_at);
