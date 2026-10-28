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

Settings (`[vars]` in `wrangler.toml`): `MAX_LENGTH` (characters per message, default 200) and `COOLDOWN_MS`
(minimum time between two messages of one user, default 1500).

## API

All responses are JSON. Errors look like `{ "error": "code", "message": "text" }`.

| Route | Purpose |
| --- | --- |
| `GET /v1/history?channel=global&limit=50[&before=ID]` | Latest messages, oldest first, plus the current `rev`. `before` pages backwards. |
| `GET /v1/poll?channel=global&since=REV` | Everything that changed after `REV`: new messages **and** deletions. An empty answer is a few bytes. |
| `POST /v1/send` | `{ channel, userId, name, displayName, text, replyTo?, token }` |
| `POST /v1/delete` | `{ channel, id, userId, token }` (owner only; the text is wiped, the row stays as "deleted") |

## Identity

- The name shown is the Roblox name the client reports. An executor can claim any name, so it cannot be *proven*.
- What the server does enforce: each device has a random secret token. The first time a Roblox user id sends, the
  SHA-256 of that token is stored. Afterwards the same user id only works with the same token, so nobody can post
  as an account that already chatted, or delete its messages (first come, first served). The token lives in
  `<Folder>/chat-token.txt` on the player's device; without file access it lasts for one session.
- Only the hash is stored, never the token.

## Limits

There is **no moderation**: no word filter, no bans, no reports. The only limits protect the free tier: a message
length cap, a per-user cooldown, and pruning to the newest 3000 messages per channel.

Roblox does not filter this chat. Messages, user ids and names are stored in your D1 database, so decide what you
tell your users about that.

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

The tests run the Worker's `fetch` handler against a real SQLite database (`node:sqlite` standing in for D1).
