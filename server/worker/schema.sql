-- Mugiwara chat: D1 (SQLite) schema. Run once:
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

-- One row per Roblox user: the SHA-256 of their device token (first sender wins) and the last send time.
CREATE TABLE IF NOT EXISTS users (
  user_id    INTEGER PRIMARY KEY,
  token_hash TEXT    NOT NULL,
  last_sent  INTEGER NOT NULL DEFAULT 0     -- unix milliseconds
);

CREATE TABLE IF NOT EXISTS meta (
  key   TEXT PRIMARY KEY,
  value INTEGER NOT NULL
);
INSERT OR IGNORE INTO meta (key, value) VALUES ('rev', 0);
