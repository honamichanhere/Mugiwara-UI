-- Mugiwara chat: D1 (SQLite) schema. Safe to run again (it only creates what is missing), so it is also
-- how you update an existing database after upgrading the Worker:
--   npx wrangler d1 execute mugiwara-chat --remote --file=schema.sql

CREATE TABLE IF NOT EXISTS messages (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  channel      TEXT    NOT NULL,
  user_id      INTEGER NOT NULL,
  name         TEXT    NOT NULL,
  display_name TEXT    NOT NULL,
  text         TEXT    NOT NULL,
  reply_to     INTEGER,
  reply_name   TEXT,
  reply_text   TEXT,
  created_at   INTEGER NOT NULL,            -- unix seconds
  deleted      INTEGER NOT NULL DEFAULT 0,
  rev          INTEGER NOT NULL             -- bumped on every change (new message or deletion); clients poll by it
);

CREATE INDEX IF NOT EXISTS idx_messages_channel_rev ON messages (channel, rev);
CREATE INDEX IF NOT EXISTS idx_messages_channel_id  ON messages (channel, id);
CREATE INDEX IF NOT EXISTS idx_messages_created     ON messages (created_at);
CREATE INDEX IF NOT EXISTS idx_messages_user        ON messages (user_id);

-- One row per Roblox user: the SHA-256 of their device token (first sender wins) and the last send time.
CREATE TABLE IF NOT EXISTS users (
  user_id    INTEGER PRIMARY KEY,
  token_hash TEXT    NOT NULL,
  last_sent  INTEGER NOT NULL DEFAULT 0     -- unix milliseconds
);

-- Names as reported by Roblox's own API (cached a week), so a client cannot invent a display name.
CREATE TABLE IF NOT EXISTS profiles (
  user_id      INTEGER PRIMARY KEY,
  name         TEXT    NOT NULL,
  display_name TEXT    NOT NULL,
  fetched_at   INTEGER NOT NULL             -- unix seconds
);

-- Per-network send limits. ip_hash is a salted, truncated hash, never the address itself. Rows older than a
-- day are deleted by the hourly cleanup.
CREATE TABLE IF NOT EXISTS ip_limits (
  ip_hash   TEXT    PRIMARY KEY,
  minute    INTEGER NOT NULL,               -- current send window (unix minute)
  sends     INTEGER NOT NULL,
  hour      INTEGER NOT NULL,               -- current "new identity" window (unix hour)
  new_users INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS meta (
  key   TEXT PRIMARY KEY,
  value INTEGER NOT NULL
);
INSERT OR IGNORE INTO meta (key, value) VALUES ('rev', 0);
-- kill switch: 0 = on, 1 = read-only (history and polling work, nobody can send), 2 = off
INSERT OR IGNORE INTO meta (key, value) VALUES ('mode', 0);
