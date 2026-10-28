-- Mugiwara chat: admin cheat sheet. This file is documentation, do not run it as a whole.
-- Run one statement at a time from server/worker (use your own config file, see README):
--
--   npx wrangler d1 execute mugiwara-chat --remote -c wrangler.local.toml --command "<SQL>"
--
-- Changes take effect immediately, no redeploy.

----------------------------------------------------------------------------------------------------
-- KILL SWITCH
----------------------------------------------------------------------------------------------------
UPDATE meta SET value = 0 WHERE key = 'mode';  -- on
UPDATE meta SET value = 1 WHERE key = 'mode';  -- read-only: history and polling work, nobody can send or delete
UPDATE meta SET value = 2 WHERE key = 'mode';  -- off: every chat route answers 503; clients show "Disabled"

----------------------------------------------------------------------------------------------------
-- REMOVE A MESSAGE (everyone sees it turn into "Message deleted")
----------------------------------------------------------------------------------------------------
UPDATE meta SET value = value + 1 WHERE key = 'rev';
UPDATE messages SET deleted = 1, text = '', rev = (SELECT value FROM meta WHERE key = 'rev') WHERE id = 123;

----------------------------------------------------------------------------------------------------
-- PRIVACY REQUEST: erase one Roblox user completely
-- (their messages, their device binding and their cached name)
----------------------------------------------------------------------------------------------------
DELETE FROM messages WHERE user_id = 123456789;
DELETE FROM users    WHERE user_id = 123456789;
DELETE FROM profiles WHERE user_id = 123456789;

-- ...or export what is stored about them first
SELECT id, channel, name, display_name, text, created_at FROM messages WHERE user_id = 123456789;
SELECT * FROM profiles WHERE user_id = 123456789;

----------------------------------------------------------------------------------------------------
-- WIPE
----------------------------------------------------------------------------------------------------
DELETE FROM messages;                          -- all messages, every channel (identities are kept)
DELETE FROM messages WHERE channel = 'global'; -- one channel
DELETE FROM ip_limits;                         -- forget the network counters

----------------------------------------------------------------------------------------------------
-- LOOK AROUND
----------------------------------------------------------------------------------------------------
SELECT channel, COUNT(*) AS messages, MAX(created_at) AS newest FROM messages GROUP BY channel;
SELECT COUNT(*) AS identities FROM users;
SELECT key, value FROM meta;                   -- rev (change counter) and mode
