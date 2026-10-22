-- One row per install of StarHash: a random id the app makes on its first
-- launch, and nothing about who uses it.
CREATE TABLE IF NOT EXISTS installs (
  id TEXT PRIMARY KEY,
  first_seen TEXT NOT NULL,
  last_seen TEXT NOT NULL,
  version TEXT
);
