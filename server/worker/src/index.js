// Mugiwara chat backend: a Cloudflare Worker + D1. Plain JSON over HTTP, no accounts.
//
//   GET  /v1/history?channel=global&limit=50[&before=ID]   latest messages (oldest first) + current `rev`
//   GET  /v1/poll?channel=global&since=REV                  everything that changed after REV (new + deleted)
//   POST /v1/send    { channel, userId, name, displayName, text, replyTo?, token }
//   POST /v1/delete  { channel, id, userId, token }
//
// Identity: the client keeps a random secret ("token") per device. The first time a Roblox userId sends, the
// SHA-256 of that token is stored for it. Later requests for the same userId must present the same token, so
// nobody else can post as you or delete your messages (first come, first served). Roblox ids themselves cannot
// be verified from an executor; this only stops impersonation of someone who already chatted.
//
// There is deliberately no moderation. The only limits are the ones that protect the free tier: a message
// length cap, a per-user cooldown, and pruning of old messages.

const DEFAULT_MAX_LENGTH = 200;
const DEFAULT_COOLDOWN_MS = 1500;
const HISTORY_MAX = 100;
const POLL_MAX = 100;
const KEEP_MESSAGES = 3000; // per channel; older ones are pruned now and then

const HEADERS = {
	"content-type": "application/json",
	"access-control-allow-origin": "*",
	"access-control-allow-methods": "GET, POST, OPTIONS",
	"access-control-allow-headers": "content-type",
	"cache-control": "no-store",
};

const json = (data, status = 200) => new Response(JSON.stringify(data), { status, headers: HEADERS });
const fail = (status, error, message) => json({ error, message }, status);

async function sha256(text) {
	const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
	return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function cleanChannel(value) {
	const channel = String(value ?? "global").toLowerCase();
	return /^[a-z0-9_-]{1,32}$/.test(channel) ? channel : null;
}

function cleanName(value) {
	if (typeof value !== "string") return null;
	const name = value.trim();
	return name.length >= 1 && name.length <= 50 ? name : null;
}

function intOrNull(value) {
	if (value === null || value === undefined || value === "") return null;
	const number = Number(value);
	return Number.isSafeInteger(number) ? number : null;
}

function clampInt(value, min, max, fallback) {
	const number = intOrNull(value);
	if (number === null) return fallback;
	return Math.min(Math.max(number, min), max);
}

function toMessage(row) {
	return {
		id: row.id,
		userId: row.user_id,
		name: row.name,
		displayName: row.display_name,
		text: row.deleted ? "" : row.text,
		replyTo: row.reply_to ?? null,
		replyName: row.reply_name ?? null,
		replyText: row.reply_text ?? null,
		time: row.created_at,
		deleted: row.deleted === 1,
	};
}

async function currentRev(env) {
	const row = await env.DB.prepare("SELECT value FROM meta WHERE key = 'rev'").first();
	return row ? row.value : 0;
}

async function readJson(request) {
	try {
		const body = await request.json();
		return body && typeof body === "object" ? body : null;
	} catch {
		return null;
	}
}

//// GET /v1/history ---------------------------------------------------------------------------
async function history(url, env) {
	const channel = cleanChannel(url.searchParams.get("channel"));
	if (!channel) return fail(400, "bad_channel", "Invalid channel name");

	const limit = clampInt(url.searchParams.get("limit"), 1, HISTORY_MAX, 50);
	const before = intOrNull(url.searchParams.get("before"));

	// read the revision first: anything that changes while we query is re-sent by the next poll
	const rev = await currentRev(env);
	const query = before === null
		? env.DB.prepare("SELECT * FROM messages WHERE channel = ? ORDER BY id DESC LIMIT ?").bind(channel, limit)
		: env.DB.prepare("SELECT * FROM messages WHERE channel = ? AND id < ? ORDER BY id DESC LIMIT ?").bind(channel, before, limit);
	const { results } = await query.all();

	const messages = results.reverse().map(toMessage);
	return json({ rev, messages, more: messages.length === limit });
}

//// GET /v1/poll -------------------------------------------------------------------------------
async function poll(url, env) {
	const channel = cleanChannel(url.searchParams.get("channel"));
	if (!channel) return fail(400, "bad_channel", "Invalid channel name");

	const since = intOrNull(url.searchParams.get("since")) ?? 0;
	const rev = await currentRev(env);
	if (since >= rev) return json({ rev, messages: [] }); // the common case costs a single tiny read

	const { results } = await env.DB
		.prepare("SELECT * FROM messages WHERE channel = ? AND rev > ? ORDER BY rev ASC LIMIT ?")
		.bind(channel, since, POLL_MAX)
		.all();

	// a full page means there may be more: continue from the last row instead of jumping to `rev`
	const next = results.length === POLL_MAX ? results[results.length - 1].rev : rev;
	return json({ rev: next, messages: results.map(toMessage) });
}

//// POST /v1/send --------------------------------------------------------------------------------
async function send(request, env) {
	const body = await readJson(request);
	if (!body) return fail(400, "bad_json", "Body must be JSON");

	const maxLength = clampInt(env.MAX_LENGTH, 1, 1000, DEFAULT_MAX_LENGTH);
	const cooldown = clampInt(env.COOLDOWN_MS, 0, 60000, DEFAULT_COOLDOWN_MS);

	const channel = cleanChannel(body.channel);
	const userId = Number.isSafeInteger(body.userId) && body.userId > 0 ? body.userId : null;
	const name = cleanName(body.name);
	const displayName = cleanName(body.displayName) ?? name;
	const token = typeof body.token === "string" && body.token.length >= 16 && body.token.length <= 128 ? body.token : null;
	const text = typeof body.text === "string" ? body.text.trim() : "";

	if (!channel || !userId || !name || !token) return fail(400, "bad_request", "Missing or invalid fields");
	if (text.length === 0) return fail(400, "empty", "Message is empty");
	if (text.length > maxLength) return fail(400, "too_long", `Messages are limited to ${maxLength} characters`);

	const now = Date.now();
	const tokenHash = await sha256(token);
	const user = await env.DB.prepare("SELECT token_hash, last_sent FROM users WHERE user_id = ?").bind(userId).first();
	if (user) {
		if (user.token_hash !== tokenHash) return fail(403, "identity_mismatch", "This Roblox account already chats from another device");
		if (now - user.last_sent < cooldown) return fail(429, "rate_limited", "You are sending messages too fast");
	}

	// replies keep a snapshot of the original, so the quote still works when the original is out of history
	let replyTo = null;
	let replyName = null;
	let replyText = null;
	const wanted = intOrNull(body.replyTo);
	if (wanted !== null) {
		const original = await env.DB
			.prepare("SELECT id, display_name, text, deleted FROM messages WHERE id = ? AND channel = ?")
			.bind(wanted, channel)
			.first();
		if (original) {
			replyTo = original.id;
			replyName = original.display_name;
			replyText = original.deleted ? "Message deleted" : original.text.slice(0, 80);
		}
	}

	// one transaction: the revision counter and the new row stay consistent
	const results = await env.DB.batch([
		env.DB.prepare(
			"INSERT INTO users (user_id, token_hash, last_sent) VALUES (?, ?, ?) " +
				"ON CONFLICT(user_id) DO UPDATE SET last_sent = excluded.last_sent",
		).bind(userId, tokenHash, now),
		env.DB.prepare("UPDATE meta SET value = value + 1 WHERE key = 'rev'"),
		env.DB.prepare(
			"INSERT INTO messages (channel, user_id, name, display_name, text, reply_to, reply_name, reply_text, created_at, deleted, rev) " +
				"VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, (SELECT value FROM meta WHERE key = 'rev'))",
		).bind(channel, userId, name, displayName, text, replyTo, replyName, replyText, Math.floor(now / 1000)),
		env.DB.prepare("SELECT * FROM messages WHERE id = last_insert_rowid()"),
	]);

	const row = results[3].results[0];

	// keep the table small (free tier): prune only now and then
	if (Math.random() < 0.02) {
		await env.DB
			.prepare("DELETE FROM messages WHERE channel = ? AND id <= (SELECT MAX(id) FROM messages WHERE channel = ?) - ?")
			.bind(channel, channel, KEEP_MESSAGES)
			.run();
	}

	return json({ message: toMessage(row), rev: row.rev }, 201);
}

//// POST /v1/delete ------------------------------------------------------------------------------------
async function remove(request, env) {
	const body = await readJson(request);
	if (!body) return fail(400, "bad_json", "Body must be JSON");

	const id = intOrNull(body.id);
	const userId = Number.isSafeInteger(body.userId) && body.userId > 0 ? body.userId : null;
	const token = typeof body.token === "string" && body.token.length >= 16 && body.token.length <= 128 ? body.token : null;
	if (id === null || !userId || !token) return fail(400, "bad_request", "Missing or invalid fields");

	const user = await env.DB.prepare("SELECT token_hash FROM users WHERE user_id = ?").bind(userId).first();
	if (!user || user.token_hash !== (await sha256(token))) return fail(403, "identity_mismatch", "Not your account");

	const message = await env.DB.prepare("SELECT user_id, deleted FROM messages WHERE id = ?").bind(id).first();
	if (!message) return fail(404, "not_found", "No such message");
	if (message.user_id !== userId) return fail(403, "not_owner", "You can only delete your own messages");
	if (message.deleted === 1) return json({ ok: true, rev: await currentRev(env) });

	await env.DB.batch([
		env.DB.prepare("UPDATE meta SET value = value + 1 WHERE key = 'rev'"),
		env.DB
			.prepare("UPDATE messages SET deleted = 1, text = '', rev = (SELECT value FROM meta WHERE key = 'rev') WHERE id = ? AND user_id = ?")
			.bind(id, userId),
	]);
	return json({ ok: true, rev: await currentRev(env) });
}

//// router ------------------------------------------------------------------------------------------------
export default {
	async fetch(request, env) {
		const url = new URL(request.url);
		try {
			if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: HEADERS });
			if (request.method === "GET" && url.pathname === "/") return json({ name: "mugiwara-chat", ok: true });
			if (request.method === "GET" && url.pathname === "/v1/history") return await history(url, env);
			if (request.method === "GET" && url.pathname === "/v1/poll") return await poll(url, env);
			if (request.method === "POST" && url.pathname === "/v1/send") return await send(request, env);
			if (request.method === "POST" && url.pathname === "/v1/delete") return await remove(request, env);
			return fail(404, "not_found", "Unknown route");
		} catch (error) {
			return fail(500, "server_error", String(error && error.message ? error.message : error));
		}
	},
};
