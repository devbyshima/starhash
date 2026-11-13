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
