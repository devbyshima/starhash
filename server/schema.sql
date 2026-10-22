-- One row per install of StarHash: a random id the app makes on its first
-- launch, and nothing about who uses it.
CREATE TABLE IF NOT EXISTS installs (
  id TEXT PRIMARY KEY,
  first_seen TEXT NOT NULL,
  last_seen TEXT NOT NULL,
  version TEXT
);

-- One row per shared photo: the random id an owner's QR code carries, the
-- hash of the key their iPhone holds (needed to replace or delete it), and
-- the JPEG itself, 200 KB at most. No number, no name.
CREATE TABLE IF NOT EXISTS photos (
  id TEXT PRIMARY KEY,
  key_hash TEXT NOT NULL,
  data BLOB NOT NULL,
  updated_at TEXT NOT NULL
);
