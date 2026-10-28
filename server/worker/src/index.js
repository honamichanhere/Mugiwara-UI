// Mugiwara chat backend: a Cloudflare Worker + D1. Plain JSON over HTTP, no accounts.
//
//   GET  /v1/info                                           mode, limits and the privacy notice (always answers)
//   GET  /v1/history?channel=global&limit=50[&before=ID]   latest messages (oldest first) + current `rev`
//   GET  /v1/poll?channel=global&since=REV                  everything that changed after REV (new + deleted)
//   POST /v1/send    { channel, userId, name, displayName, text, replyTo?, token }
//   POST /v1/delete  { channel, id, userId, token }
//
// Identity: the client keeps a random secret ("token") per device. The first time a Roblox userId sends, the
// SHA-256 of that token is stored for it. Later requests for the same userId must present the same token.
// Names are taken from Roblox's own API (cached for a week), so a client cannot invent a display name.
//
// Safeguards (all configurable in wrangler.toml, all cheap):
//   kill switch   meta.mode in D1: 0 on, 1 read-only, 2 off (flip it with one SQL command, no redeploy)
//   rate limits   per user (COOLDOWN_MS) and per network (IP_SENDS_PER_MIN, IP_NEW_USERS_PER_HOUR)
//   retention     RETENTION_HOURS / KEEP_MESSAGES, enforced on read and deleted by an hourly cron
//   names         VERIFY_ROBLOX ("true" strict / "lenient" / "false"), RESERVED_NAMES, OWNER_IDS
//   filter        FILTER = "links,phone" (off by default)
// There is no moderation beyond that: no word lists, no bans, no reports.

const DEFAULTS = {
	MAX_LENGTH: 200,
	COOLDOWN_MS: 1500,
	IP_SENDS_PER_MIN: 20,
	IP_NEW_USERS_PER_HOUR: 5,
	RETENTION_HOURS: 72,
	KEEP_MESSAGES: 1000,
};
const HISTORY_MAX = 100;
const POLL_MAX = 100;
const PROFILE_TTL = 7 * 86400; // seconds
const ROBLOX_TIMEOUT_MS = 3000;
const MODE = { ON: 0, READ_ONLY: 1, OFF: 2 };

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

//// small helpers ---------------------------------------------------------------------------------
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

// numeric setting from wrangler.toml; 0 is a valid value ("off")
const setting = (env, name) => clampInt(env[name], 0, 1_000_000, DEFAULTS[name]);

const list = (value) => String(value ?? "").split(",").map((item) => item.trim().toLowerCase()).filter(Boolean);

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

async function readState(env) {
	const { results } = await env.DB.prepare("SELECT key, value FROM meta WHERE key IN ('rev', 'mode')").all();
	const state = { rev: 0, mode: MODE.ON };
	for (const row of results) state[row.key] = row.value;
	return state;
}

async function readJson(request) {
	try {
		const body = await request.json();
		return body && typeof body === "object" ? body : null;
	} catch {
		return null;
	}
}

const nowSeconds = () => Math.floor(Date.now() / 1000);

// oldest created_at a message may have to still be visible (0 = no age limit)
function retentionCutoff(env) {
	const hours = setting(env, "RETENTION_HOURS");
	return hours > 0 ? nowSeconds() - hours * 3600 : 0;
}

// a salted, truncated hash of the caller's network address: enough to rate limit, not enough to identify
async function networkKey(request, env) {
	const address = request.headers.get("cf-connecting-ip") || "unknown";
	return (await sha256(`${env.IP_SALT || "mugiwara"}:${address}`)).slice(0, 16);
}

//// optional content rules -------------------------------------------------------------------------
const LINK_PATTERN =
	/(https?:\/\/|www\.|discord\.gg|t\.me\/|\b[a-z0-9-]{2,}\.(com|net|org|gg|io|me|xyz|ru|cc|co|tv|ly|app|dev|info|link|site|online|shop|store)\b)/i;
const PHONE_PATTERN = /(?:\+?\d[\s().-]*){8,}/;

function blockedContent(env, text) {
	const rules = list(env.FILTER);
	if (rules.includes("links") && LINK_PATTERN.test(text)) return "Links are not allowed in this chat";
	if (rules.includes("phone") && PHONE_PATTERN.test(text)) return "Phone numbers are not allowed in this chat";
	return null;
}

//// names ---------------------------------------------------------------------------------------------
const DEFAULT_RESERVED = "owner,admin,administrator,staff,moderator,system,mugiwara";

function isReserved(env, userId, ...names) {
	if (list(env.OWNER_IDS).includes(String(userId))) return false;
	const reserved = list(env.RESERVED_NAMES ?? DEFAULT_RESERVED);
	const words = names.flatMap((name) => name.toLowerCase().split(/[^a-z0-9]+/)).filter(Boolean);
	return words.some((word) => reserved.includes(word));
}

// VERIFY_ROBLOX: "true" (default) = names must come from Roblox, "lenient" = if Roblox cannot be reached, trust the
// client's names, "false" = never ask Roblox.
const verifyMode = (env) => {
	const value = String(env.VERIFY_ROBLOX ?? "true").toLowerCase();
	return value === "false" || value === "lenient" ? value : "true";
};

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Asks Roblox who this user id really is (cached a week). status: ok | unknown | unavailable | skipped
// Roblox answers some requests from Cloudflare with HTTP 429, so a failed lookup is retried once.
async function lookupProfile(env, userId) {
	if (verifyMode(env) === "false") return { status: "skipped" };

	const cached = await env.DB.prepare("SELECT name, display_name, fetched_at FROM profiles WHERE user_id = ?").bind(userId).first();
	const cachedResult = cached ? { status: "ok", name: cached.name, displayName: cached.display_name } : null;
	if (cached && nowSeconds() - cached.fetched_at < PROFILE_TTL) return cachedResult;

	for (let attempt = 1; attempt <= 2; attempt++) {
		if (attempt > 1) await sleep(300);
		const controller = new AbortController();
		const timer = setTimeout(() => controller.abort(), ROBLOX_TIMEOUT_MS);
		try {
			const response = await fetch(`https://users.roblox.com/v1/users/${userId}`, {
				signal: controller.signal,
				headers: { accept: "application/json" },
			});
			if (response.status === 404 || response.status === 400) return { status: "unknown" };
			if (!response.ok) {
				console.warn(`roblox lookup for ${userId} failed: HTTP ${response.status} (attempt ${attempt})`); // visible in `wrangler tail`
				continue;
			}
			const data = await response.json();
			const name = cleanName(data.name);
			if (!name) continue;
			const displayName = cleanName(data.displayName) ?? name;
			await env.DB.prepare(
				"INSERT INTO profiles (user_id, name, display_name, fetched_at) VALUES (?, ?, ?, ?) " +
					"ON CONFLICT(user_id) DO UPDATE SET name = excluded.name, display_name = excluded.display_name, fetched_at = excluded.fetched_at",
			)
				.bind(userId, name, displayName, nowSeconds())
				.run();
			return { status: "ok", name, displayName };
		} catch (error) {
			console.warn(`roblox lookup for ${userId} threw: ${error && error.message ? error.message : error} (attempt ${attempt})`);
		} finally {
			clearTimeout(timer);
		}
	}
	return cachedResult ?? { status: "unavailable" }; // an old cached name beats nothing
}

//// GET /v1/info ------------------------------------------------------------------------------------------
async function info(env) {
	const state = await readState(env);
	return json({
		mode: ["on", "readonly", "off"][state.mode] ?? "on",
		maxLength: setting(env, "MAX_LENGTH"),
		cooldownMs: setting(env, "COOLDOWN_MS"),
		retentionHours: setting(env, "RETENTION_HOURS"),
		filter: list(env.FILTER),
		notice: env.NOTICE ? String(env.NOTICE) : null,
	});
}

//// GET /v1/history ---------------------------------------------------------------------------------------
async function history(url, env, state) {
	const channel = cleanChannel(url.searchParams.get("channel"));
	if (!channel) return fail(400, "bad_channel", "Invalid channel name");

	const limit = clampInt(url.searchParams.get("limit"), 1, HISTORY_MAX, 50);
	const before = intOrNull(url.searchParams.get("before"));
	const cutoff = retentionCutoff(env);

	// `state.rev` was read before this query: anything that changes meanwhile is re-sent by the next poll
	const query =
		before === null
			? env.DB.prepare("SELECT * FROM messages WHERE channel = ? AND created_at >= ? ORDER BY id DESC LIMIT ?").bind(channel, cutoff, limit)
			: env.DB
					.prepare("SELECT * FROM messages WHERE channel = ? AND id < ? AND created_at >= ? ORDER BY id DESC LIMIT ?")
					.bind(channel, before, cutoff, limit);
	const { results } = await query.all();

	const messages = results.reverse().map(toMessage);
	return json({ rev: state.rev, messages, more: messages.length === limit });
}

//// GET /v1/poll --------------------------------------------------------------------------------------------
async function poll(url, env, state) {
	const channel = cleanChannel(url.searchParams.get("channel"));
	if (!channel) return fail(400, "bad_channel", "Invalid channel name");

	const since = intOrNull(url.searchParams.get("since")) ?? 0;
	if (since >= state.rev) return json({ rev: state.rev, messages: [] }); // the common case costs a single tiny read

	const { results } = await env.DB
		.prepare("SELECT * FROM messages WHERE channel = ? AND rev > ? AND created_at >= ? ORDER BY rev ASC LIMIT ?")
		.bind(channel, since, retentionCutoff(env), POLL_MAX)
		.all();

	// a full page means there may be more: continue from the last row instead of jumping to `rev`
	const next = results.length === POLL_MAX ? results[results.length - 1].rev : state.rev;
	return json({ rev: next, messages: results.map(toMessage) });
}

//// POST /v1/send -----------------------------------------------------------------------------------------------
async function send(request, env) {
	const body = await readJson(request);
	if (!body) return fail(400, "bad_json", "Body must be JSON");

	const maxLength = clampInt(env.MAX_LENGTH, 1, 1000, DEFAULTS.MAX_LENGTH);
	const cooldown = setting(env, "COOLDOWN_MS");

	const channel = cleanChannel(body.channel);
	const userId = Number.isSafeInteger(body.userId) && body.userId > 0 ? body.userId : null;
	const claimedName = cleanName(body.name);
	const claimedDisplay = cleanName(body.displayName) ?? claimedName;
	const token = typeof body.token === "string" && body.token.length >= 16 && body.token.length <= 128 ? body.token : null;
	const text = typeof body.text === "string" ? body.text.trim() : "";

	if (!channel || !userId || !claimedName || !token) return fail(400, "bad_request", "Missing or invalid fields");
	if (text.length === 0) return fail(400, "empty", "Message is empty");
	if (text.length > maxLength) return fail(400, "too_long", `Messages are limited to ${maxLength} characters`);

	const blocked = blockedContent(env, text);
	if (blocked) return fail(400, "blocked_content", blocked);

	const now = Date.now();
	const tokenHash = await sha256(token);
	const network = await networkKey(request, env);

	const user = await env.DB.prepare("SELECT token_hash, last_sent FROM users WHERE user_id = ?").bind(userId).first();
	if (user) {
		if (user.token_hash !== tokenHash) return fail(403, "identity_mismatch", "This Roblox account already chats from another device");
		if (cooldown > 0 && now - user.last_sent < cooldown) return fail(429, "rate_limited", "You are sending messages too fast");
	}

	// per-network limits: a flood that rotates fake user ids still comes from one place
	const sendsPerMinute = setting(env, "IP_SENDS_PER_MIN");
	const newUsersPerHour = setting(env, "IP_NEW_USERS_PER_HOUR");
	const minute = Math.floor(now / 60000);
	const hour = Math.floor(now / 3600000);
	const limits = await env.DB.prepare("SELECT minute, sends, hour, new_users FROM ip_limits WHERE ip_hash = ?").bind(network).first();
	if (limits) {
		if (sendsPerMinute > 0 && limits.minute === minute && limits.sends >= sendsPerMinute) {
			return fail(429, "ip_rate_limited", "Too many messages from your network, wait a moment");
		}
		if (!user && newUsersPerHour > 0 && limits.hour === hour && limits.new_users >= newUsersPerHour) {
			return fail(429, "too_many_identities", "Too many new accounts from your network, try again later");
		}
	}

	// names come from Roblox, not from the client
	const profile = await lookupProfile(env, userId);
	if (profile.status === "unknown") return fail(400, "unknown_user", "That Roblox user does not exist");
	if (profile.status === "unavailable" && verifyMode(env) === "true") {
		// strict: never let an unverified name through. A new account just tries again in a moment.
		return fail(503, "verification_unavailable", "Could not verify your Roblox account right now, try again in a moment");
	}
	const name = profile.status === "ok" ? profile.name : claimedName;
	const displayName = profile.status === "ok" ? profile.displayName : claimedDisplay;
	if (isReserved(env, userId, name, displayName)) {
		return fail(403, "reserved_name", "That name is reserved for the hub's staff");
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

	// one transaction: the revision counter, the limits and the new row stay consistent
	const results = await env.DB.batch([
		env.DB.prepare(
			"INSERT INTO users (user_id, token_hash, last_sent) VALUES (?, ?, ?) " +
				"ON CONFLICT(user_id) DO UPDATE SET last_sent = excluded.last_sent",
		).bind(userId, tokenHash, now),
		env.DB.prepare(
			"INSERT INTO ip_limits (ip_hash, minute, sends, hour, new_users) VALUES (?, ?, 1, ?, ?) " +
				"ON CONFLICT(ip_hash) DO UPDATE SET " +
				"sends = CASE WHEN ip_limits.minute = excluded.minute THEN ip_limits.sends + 1 ELSE 1 END, " +
				"minute = excluded.minute, " +
				"new_users = CASE WHEN ip_limits.hour = excluded.hour THEN ip_limits.new_users + excluded.new_users ELSE excluded.new_users END, " +
				"hour = excluded.hour",
		).bind(network, minute, hour, user ? 0 : 1),
		env.DB.prepare("UPDATE meta SET value = value + 1 WHERE key = 'rev'"),
		env.DB.prepare(
			"INSERT INTO messages (channel, user_id, name, display_name, text, reply_to, reply_name, reply_text, created_at, deleted, rev) " +
				"VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, (SELECT value FROM meta WHERE key = 'rev'))",
		).bind(channel, userId, name, displayName, text, replyTo, replyName, replyText, Math.floor(now / 1000)),
		env.DB.prepare("SELECT * FROM messages WHERE id = last_insert_rowid()"),
	]);

	const row = results[4].results[0];
	return json({ message: toMessage(row), rev: row.rev }, 201);
}

//// POST /v1/delete -----------------------------------------------------------------------------------------------
async function remove(request, env, state) {
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
	if (message.deleted === 1) return json({ ok: true, rev: state.rev });

	await env.DB.batch([
		env.DB.prepare("UPDATE meta SET value = value + 1 WHERE key = 'rev'"),
		env.DB
			.prepare("UPDATE messages SET deleted = 1, text = '', rev = (SELECT value FROM meta WHERE key = 'rev') WHERE id = ? AND user_id = ?")
			.bind(id, userId),
	]);
	return json({ ok: true, rev: (await readState(env)).rev });
}

//// hourly cleanup (cron trigger) --------------------------------------------------------------------------------------
export async function prune(env) {
	const hours = setting(env, "RETENTION_HOURS");
	const keep = setting(env, "KEEP_MESSAGES");

	if (hours > 0) {
		await env.DB.prepare("DELETE FROM messages WHERE created_at < ?").bind(nowSeconds() - hours * 3600).run();
	}
	if (keep > 0) {
		const { results } = await env.DB.prepare("SELECT DISTINCT channel FROM messages").all();
		for (const { channel } of results) {
			await env.DB
				.prepare("DELETE FROM messages WHERE channel = ? AND id <= (SELECT MAX(id) FROM messages WHERE channel = ?) - ?")
				.bind(channel, channel, keep)
				.run();
		}
	}
	await env.DB.prepare("DELETE FROM ip_limits WHERE hour < ?").bind(Math.floor(Date.now() / 3600000) - 24).run();
}

//// router ------------------------------------------------------------------------------------------------------------------
const WRITES = new Set(["/v1/send", "/v1/delete"]);

export default {
	async fetch(request, env) {
		const url = new URL(request.url);
		try {
			if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: HEADERS });
			if (request.method === "GET" && url.pathname === "/") return json({ name: "mugiwara-chat", ok: true });
			if (request.method === "GET" && url.pathname === "/v1/info") return await info(env);

			const known = ["/v1/history", "/v1/poll", "/v1/send", "/v1/delete"].includes(url.pathname);
			if (!known) return fail(404, "not_found", "Unknown route");

			// the kill switch: one tiny read that also gives us the current revision
			const state = await readState(env);
			if (state.mode >= MODE.OFF) return fail(503, "chat_disabled", "Chat is turned off right now");
			if (state.mode === MODE.READ_ONLY && WRITES.has(url.pathname)) {
				return fail(503, "chat_readonly", "Chat is read-only right now");
			}

			if (request.method === "GET" && url.pathname === "/v1/history") return await history(url, env, state);
			if (request.method === "GET" && url.pathname === "/v1/poll") return await poll(url, env, state);
			if (request.method === "POST" && url.pathname === "/v1/send") return await send(request, env);
			if (request.method === "POST" && url.pathname === "/v1/delete") return await remove(request, env, state);
			return fail(405, "method_not_allowed", "Wrong method for this route");
		} catch (error) {
			return fail(500, "server_error", String(error && error.message ? error.message : error));
		}
	},

	async scheduled(_event, env, ctx) {
		ctx.waitUntil(prune(env));
	},
};
