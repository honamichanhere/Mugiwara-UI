# Mugiwara chat backend (Cloudflare Worker + D1)

The backend for the `Chat` element. One small Worker and one D1 (SQLite) database, both on Cloudflare's free plan.
No accounts, no secrets in the script: the executor only needs the Worker URL.

## Deploy (about 5 minutes)

You need a free Cloudflare account and Node.js.

```bash
cd server/worker
npm install
npx wrangler login
npx wrangler d1 create mugiwara-chat
```

The last command prints a `database_id`. Paste it into [`wrangler.toml`](wrangler.toml) (`database_id = "..."`), then:

```bash
npx wrangler d1 execute mugiwara-chat --remote --file=schema.sql
npx wrangler deploy
```

Wrangler prints your URL, something like `https://mugiwara-chat.<your-name>.workers.dev`. Open it in a browser:
`{"name":"mugiwara-chat","ok":true}` means it works. Then in your script:

```lua
local chat = MugiwaraUI.ChatTransports.Http({
    Url = "https://mugiwara-chat.<your-name>.workers.dev",
    Channel = "global",     -- other names are separate rooms
    Folder = "MugiwaraHub", -- where the device token is stored
})
tab:Chat({ Transport = chat })
```

Tip: if you publish your fork, keep your real `database_id` out of git. Put it in `wrangler.local.toml` (already
gitignored, same content as `wrangler.toml`) and run the commands with `-c wrangler.local.toml`.

Limits and safeguards are configured in `[vars]` of `wrangler.toml` (see Safeguards below).

## API

All responses are JSON. Errors look like `{ "error": "code", "message": "text" }`.

| Route | Purpose |
| --- | --- |
| `GET /v1/info` | Mode (`on` / `readonly` / `off`), limits, retention and the privacy notice. Always answers, even when the chat is off. |
| `GET /v1/history?channel=global&limit=50[&before=ID]` | Latest messages, oldest first, plus the current `rev`. `before` pages backwards. |
| `GET /v1/poll?channel=global&since=REV` | Everything that changed after `REV`: new messages **and** deletions. An empty answer is a few bytes. |
| `POST /v1/send` | `{ channel, userId, name, displayName, text, replyTo?, token }` |
| `POST /v1/delete` | `{ channel, id, userId, token }` (owner only; the text is wiped, the row stays as "deleted") |

## Identity

- With `VERIFY_ROBLOX` on, the names shown come from Roblox's own API for that user id, so a display name cannot be invented. Which person is behind a user id still cannot be *proven* from an executor: anyone can claim any id.
- What the server does enforce: each device has a random secret token. The first time a Roblox user id sends, the
  SHA-256 of that token is stored. Afterwards the same user id only works with the same token, so nobody can post
  as an account that already chatted, or delete its messages (first come, first served). The token lives in
  `<Folder>/chat-token.txt` on the player's device; without file access it lasts for one session.
- Only the hash is stored, never the token.

## Safeguards

There is **no moderation** (no word lists, no bans, no reports). What exists are cheap protections for the free tier
and for the people running the hub. Everything is configured in [`wrangler.toml`](wrangler.toml) `[vars]`
(numeric limits: `0` = off).

| Safeguard | Setting | What it does |
| --- | --- | --- |
| **Kill switch** | `meta.mode` in D1 | `0` on, `1` read-only, `2` off. One SQL command, no redeploy (see below). Clients show "Read-only" / "Disabled" and lock the input. |
| **Rate limit per user** | `COOLDOWN_MS` (1500) | Minimum time between two messages of one account. |
| **Rate limit per network** | `IP_SENDS_PER_MIN` (20), `IP_NEW_USERS_PER_HOUR` (5) | A flood that rotates fake user ids still comes from one network. Addresses are stored as a salted, truncated hash and deleted after a day. |
| **Retention** | `RETENTION_HOURS` (72), `KEEP_MESSAGES` (1000) | Expired messages disappear from every response immediately and are deleted by an hourly cron job. Less stored means less exposure. |
| **Names from Roblox** | `VERIFY_ROBLOX` (true) | The Worker asks Roblox who the user id really is (cached a week, one retry), so a client cannot invent a display name. Unknown ids are rejected. Roblox sometimes answers Cloudflare with HTTP 429: in the default strict mode a *new* account then gets "try again in a moment" (accounts already cached keep working); `"lenient"` trusts the client's names instead, `"false"` never asks Roblox. |
| **Reserved names** | `RESERVED_NAMES`, `OWNER_IDS` | Whole-word display names such as "Owner" or "Admin" only work for the Roblox ids listed in `OWNER_IDS`. |
| **Optional content rules** | `FILTER` (empty = off) | `"links"` rejects URLs / invites / domains, `"phone"` rejects long digit runs. Off by default. |
| **Privacy banner** | `NOTICE` (optional) | Text shown in the chat's banner (the client adds "Messages are deleted after N hours"). |
| **Length cap** | `MAX_LENGTH` (200) | Per message. |

### Admin commands

[`admin.sql`](admin.sql) has ready-made statements: switch the chat on / read-only / off, remove a message (everyone
sees it vanish), erase or export everything about one Roblox user (privacy requests), wipe a channel. Run one with:

```bash
cd server/worker
npx wrangler d1 execute mugiwara-chat --remote -c wrangler.local.toml --command "UPDATE meta SET value = 2 WHERE key = 'mode'"
```

Shortcuts (they use `wrangler.local.toml`): `npm run chat:on`, `npm run chat:readonly`, `npm run chat:off`.

### Recommended extras

- Set a secret salt for the stored network hashes: `npx wrangler secret put IP_SALT`.
- Reads (history / poll) are not rate limited by the Worker, because counting them would cost a database write each.
  In the Cloudflare dashboard (Security → WAF → Rate limiting rules) add a rule for your Worker's hostname if you
  are worried about someone hammering it; the free plan includes one.
- Decide what you tell your users: messages, Roblox ids and names are stored in **your** D1 database, and
  Roblox does not filter this chat. The chat shows a short privacy banner by default.

## Updating an existing deployment

`schema.sql` only creates what is missing, so after pulling a new version:

```bash
cd server/worker
npx wrangler d1 execute mugiwara-chat --remote -c wrangler.local.toml --file=schema.sql
npx wrangler deploy -c wrangler.local.toml
```

Old clients keep working against a newer Worker.

## Free tier

Cloudflare's free plan (check the current numbers on their pricing page) allows roughly 100,000 Worker requests per
day, 5 million D1 rows read per day and 100,000 rows written per day. When a limit is reached the Worker simply
refuses requests until the next day; nothing is billed on the free plan.

The client keeps request counts low: it only polls while the chat is on screen (every 3 s while people are talking,
8 s otherwise, backing off when offline), and a poll with nothing new is one tiny read. That is roughly 600
requests per user per hour, so about 150 user-hours of open chat per day fit in the free requests. Each message is a
few row writes, so thousands of messages per day are fine.

## Tests

```bash
npm run test:server   # from the repo root
```

The tests run the Worker's `fetch` handler against a real SQLite database (`node:sqlite` standing in for D1); the Roblox API is faked.
