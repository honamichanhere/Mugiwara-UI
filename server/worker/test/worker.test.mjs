// Runs the Worker's fetch handler against a real SQLite database (node:sqlite stands in for D1),
// so the actual SQL and the batch / transaction behavior are exercised.

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { DatabaseSync } from "node:sqlite";
import worker from "../src/index.js";

// the Worker logs failed Roblox lookups with console.warn; the outage tests trigger that on purpose
console.warn = () => {};

const here = dirname(fileURLToPath(import.meta.url));
const schema = readFileSync(join(here, "..", "schema.sql"), "utf8");

// Minimal D1 look-alike: prepare().bind().first()/all()/run() and batch() inside one transaction.
function createD1() {
	const db = new DatabaseSync(":memory:");
	db.exec(schema);
	const statement = (sql, params = []) => ({
		bind: (...args) => statement(sql, args),
		first: async () => db.prepare(sql).get(...params) ?? null,
		all: async () => ({ results: db.prepare(sql).all(...params).map((row) => ({ ...row })) }),
		run: async () => {
			db.prepare(sql).run(...params);
			return { success: true };
		},
		_run() {
			const prepared = db.prepare(sql);
			if (/^\s*SELECT/i.test(sql)) return { results: prepared.all(...params).map((row) => ({ ...row })) };
			prepared.run(...params);
			return { results: [] };
		},
	});
	return {
		raw: db, // for tests that need to poke the database directly
		prepare: (sql) => statement(sql),
		batch: async (statements) => {
			db.exec("BEGIN");
			try {
				const out = statements.map((item) => item._run());
				db.exec("COMMIT");
				return out;
			} catch (error) {
				db.exec("ROLLBACK");
				throw error;
			}
		},
	};
}

// Every limit is switched off by default so each test only turns on what it is about.
function makeEnv(extra = {}) {
	return {
		DB: createD1(),
		MAX_LENGTH: "200",
		COOLDOWN_MS: "0",
		IP_SENDS_PER_MIN: "0",
		IP_NEW_USERS_PER_HOUR: "0",
		RETENTION_HOURS: "0",
		KEEP_MESSAGES: "1000",
		VERIFY_ROBLOX: "false",
		RESERVED_NAMES: "owner,admin",
		...extra,
	};
}

async function call(env, method, path, body, headers = {}) {
	const request = new Request("https://chat.test" + path, {
		method,
		headers: body ? { "content-type": "application/json", ...headers } : headers,
		body: body ? JSON.stringify(body) : undefined,
	});
	const response = await worker.fetch(request, env);
	const text = await response.text();
	return { status: response.status, body: text ? JSON.parse(text) : null };
}

const TOKEN_A = "a".repeat(40);
const TOKEN_B = "b".repeat(40);
const alice = { channel: "global", userId: 101, name: "alice_rbx", displayName: "Alice", token: TOKEN_A };
const bob = { channel: "global", userId: 202, name: "bob_rbx", displayName: "Bob", token: TOKEN_B };

let passed = 0;
async function test(name, fn) {
	try {
		await fn();
		passed++;
	} catch (error) {
		console.error(`FAILED: ${name}`);
		throw error;
	}
}

// fake Roblox users API for the name checks
const realFetch = globalThis.fetch;
function fakeRoblox(users, counter = { calls: 0 }) {
	globalThis.fetch = async (url) => {
		counter.calls++;
		const id = Number(String(url).split("/").pop());
		const user = users[id];
		if (user === "down") return new Response("oops", { status: 503 });
		if (!user) return new Response(JSON.stringify({ errors: [{ code: 3 }] }), { status: 404 });
		return new Response(JSON.stringify({ id, ...user }), { status: 200 });
	};
	return counter;
}
const restoreFetch = () => {
	globalThis.fetch = realFetch;
};

//// basics (unchanged behavior) ---------------------------------------------------------------------

await test("health, CORS preflight and unknown routes", async () => {
	const env = makeEnv();
	assert.equal((await call(env, "GET", "/")).body.ok, true);
	assert.equal((await call(env, "OPTIONS", "/v1/send")).status, 204);
	assert.equal((await call(env, "GET", "/nope")).status, 404);
	assert.equal((await call(env, "GET", "/v1/history?channel=BAD CHANNEL!")).status, 400);
	assert.equal((await call(env, "GET", "/v1/send")).status, 405);
});

await test("send, history and poll", async () => {
	const env = makeEnv();
	const sent = await call(env, "POST", "/v1/send", { ...alice, text: "  hello world  " });
	assert.equal(sent.status, 201);
	assert.equal(sent.body.message.text, "hello world", "text is trimmed");
	assert.equal(sent.body.message.id, 1);
	assert.equal(sent.body.message.displayName, "Alice");
	assert.equal(typeof sent.body.message.time, "number");

	const history = await call(env, "GET", "/v1/history?channel=global");
	assert.equal(history.body.messages.length, 1);
	assert.equal(history.body.rev, 1);

	assert.equal((await call(env, "GET", "/v1/poll?channel=global&since=0")).body.messages.length, 1);
	const idle = await call(env, "GET", "/v1/poll?channel=global&since=1");
	assert.deepEqual(idle.body, { rev: 1, messages: [] }, "nothing new is a tiny response");
});

await test("channels are separate", async () => {
	const env = makeEnv();
	await call(env, "POST", "/v1/send", { ...alice, text: "in global" });
	await call(env, "POST", "/v1/send", { ...alice, channel: "other", text: "in other" });
	assert.equal((await call(env, "GET", "/v1/history?channel=other")).body.messages[0].text, "in other");
	assert.equal((await call(env, "GET", "/v1/history?channel=global")).body.messages.length, 1);
	assert.equal((await call(env, "GET", "/v1/poll?channel=other&since=0")).body.messages.length, 1);
});

await test("validation", async () => {
	const env = makeEnv({ MAX_LENGTH: "10" });
	assert.equal((await call(env, "POST", "/v1/send", { ...alice, text: "   " })).body.error, "empty");
	assert.equal((await call(env, "POST", "/v1/send", { ...alice, text: "x".repeat(11) })).body.error, "too_long");
	assert.equal((await call(env, "POST", "/v1/send", { ...alice, text: "ok", token: "short" })).status, 400);
	assert.equal((await call(env, "POST", "/v1/send", { ...alice, text: "ok", userId: "nope" })).status, 400);
	assert.equal((await call(env, "POST", "/v1/send", { ...alice, text: "ok", userId: -5 })).status, 400);
	const bad = await worker.fetch(new Request("https://chat.test/v1/send", { method: "POST", body: "not json" }), env);
	assert.equal(bad.status, 400);
});

await test("a Roblox account is bound to the first device token (no impersonation)", async () => {
	const env = makeEnv();
	assert.equal((await call(env, "POST", "/v1/send", { ...alice, text: "mine" })).status, 201);
	const stolen = await call(env, "POST", "/v1/send", { ...alice, token: TOKEN_B, text: "pretending" });
	assert.equal(stolen.status, 403);
	assert.equal(stolen.body.error, "identity_mismatch");
	assert.equal((await call(env, "POST", "/v1/send", { ...alice, text: "still me" })).status, 201);
	assert.equal((await call(env, "POST", "/v1/send", { ...bob, text: "other user" })).status, 201);
});

await test("per-user cooldown", async () => {
	const env = makeEnv({ COOLDOWN_MS: "60000" });
	assert.equal((await call(env, "POST", "/v1/send", { ...alice, text: "one" })).status, 201);
	const second = await call(env, "POST", "/v1/send", { ...alice, text: "two" });
	assert.equal(second.status, 429);
	assert.equal(second.body.error, "rate_limited");
	assert.equal((await call(env, "POST", "/v1/send", { ...bob, text: "different user" })).status, 201, "cooldown is per user");
});

await test("replies keep a snapshot of the original", async () => {
	const env = makeEnv();
	const first = await call(env, "POST", "/v1/send", { ...alice, text: "what time is the event?" });
	const reply = await call(env, "POST", "/v1/send", { ...bob, text: "9pm", replyTo: first.body.message.id });
	assert.equal(reply.body.message.replyTo, first.body.message.id);
	assert.equal(reply.body.message.replyName, "Alice");
	assert.equal(reply.body.message.replyText, "what time is the event?");
	const unknown = await call(env, "POST", "/v1/send", { ...bob, text: "no original", replyTo: 9999 });
	assert.equal(unknown.body.message.replyTo, null, "an unknown reply target is ignored");
});

await test("deleting: owner only, shows up in poll, text is wiped", async () => {
	const env = makeEnv();
	const sent = await call(env, "POST", "/v1/send", { ...alice, text: "oops" });
	const id = sent.body.message.id;
	const rev = sent.body.rev;
	await call(env, "POST", "/v1/send", { ...bob, text: "bob here" });

	const byBob = await call(env, "POST", "/v1/delete", { channel: "global", id, userId: bob.userId, token: TOKEN_B });
	assert.equal(byBob.body.error, "not_owner");
	const forged = await call(env, "POST", "/v1/delete", { channel: "global", id, userId: alice.userId, token: TOKEN_B });
	assert.equal(forged.body.error, "identity_mismatch");
	assert.equal((await call(env, "POST", "/v1/delete", { channel: "global", id: 4242, userId: alice.userId, token: TOKEN_A })).status, 404);

	const ok = await call(env, "POST", "/v1/delete", { channel: "global", id, userId: alice.userId, token: TOKEN_A });
	assert.equal(ok.status, 200);
	assert.equal((await call(env, "POST", "/v1/delete", { channel: "global", id, userId: alice.userId, token: TOKEN_A })).status, 200, "deleting twice is fine");

	const changes = await call(env, "GET", `/v1/poll?channel=global&since=${rev + 1}`); // after bob's message
	assert.equal(changes.body.messages.length, 1, "the deletion is delivered as a change");
	assert.equal(changes.body.messages[0].id, id);
	assert.equal(changes.body.messages[0].deleted, true);
	assert.equal(changes.body.messages[0].text, "");

	const history = await call(env, "GET", "/v1/history?channel=global");
	assert.equal(history.body.messages.find((m) => m.id === id).deleted, true);
});

await test("a reply to a deleted message says so", async () => {
	const env = makeEnv();
	const sent = await call(env, "POST", "/v1/send", { ...alice, text: "secret" });
	await call(env, "POST", "/v1/delete", { channel: "global", id: sent.body.message.id, userId: alice.userId, token: TOKEN_A });
	const reply = await call(env, "POST", "/v1/send", { ...bob, text: "huh?", replyTo: sent.body.message.id });
	assert.equal(reply.body.message.replyText, "Message deleted");
});

await test("history pages with `before`, oldest first", async () => {
	const env = makeEnv();
	for (let index = 1; index <= 5; index++) {
		await call(env, "POST", "/v1/send", { ...alice, text: `m${index}` });
	}
	const latest = await call(env, "GET", "/v1/history?channel=global&limit=2");
	assert.deepEqual(latest.body.messages.map((m) => m.text), ["m4", "m5"]);
	assert.equal(latest.body.more, true);
	const older = await call(env, "GET", `/v1/history?channel=global&limit=2&before=${latest.body.messages[0].id}`);
	assert.deepEqual(older.body.messages.map((m) => m.text), ["m2", "m3"]);
	const oldest = await call(env, "GET", `/v1/history?channel=global&limit=2&before=${older.body.messages[0].id}`);
	assert.deepEqual(oldest.body.messages.map((m) => m.text), ["m1"]);
	assert.equal(oldest.body.more, false);
});

await test("poll pages through large backlogs without skipping", async () => {
	const env = makeEnv();
	for (let index = 1; index <= 130; index++) {
		await call(env, "POST", "/v1/send", { ...alice, text: `n${index}` });
	}
	let since = 0;
	let received = [];
	for (let guard = 0; guard < 5; guard++) {
		const page = await call(env, "GET", `/v1/poll?channel=global&since=${since}`);
		received = received.concat(page.body.messages.map((m) => m.text));
		if (page.body.messages.length === 0) break;
		since = page.body.rev;
	}
	assert.equal(received.length, 130);
	assert.equal(received[0], "n1");
	assert.equal(received[129], "n130");
});

//// safeguards ----------------------------------------------------------------------------------------------

await test("kill switch: read-only keeps reading, off stops everything but /v1/info", async () => {
	const env = makeEnv();
	await call(env, "POST", "/v1/send", { ...alice, text: "before" });

	env.DB.raw.exec("UPDATE meta SET value = 1 WHERE key = 'mode'");
	assert.equal((await call(env, "GET", "/v1/history?channel=global")).body.messages.length, 1, "read-only still shows history");
	assert.equal((await call(env, "GET", "/v1/poll?channel=global&since=0")).status, 200);
	const blockedSend = await call(env, "POST", "/v1/send", { ...alice, text: "nope" });
	assert.equal(blockedSend.status, 503);
	assert.equal(blockedSend.body.error, "chat_readonly");
	assert.equal((await call(env, "POST", "/v1/delete", { channel: "global", id: 1, userId: 101, token: TOKEN_A })).body.error, "chat_readonly");
	assert.equal((await call(env, "GET", "/v1/info")).body.mode, "readonly");

	env.DB.raw.exec("UPDATE meta SET value = 2 WHERE key = 'mode'");
	const off = await call(env, "GET", "/v1/history?channel=global");
	assert.equal(off.status, 503);
	assert.equal(off.body.error, "chat_disabled");
	assert.equal((await call(env, "GET", "/v1/poll?channel=global&since=0")).body.error, "chat_disabled");
	assert.equal((await call(env, "GET", "/v1/info")).body.mode, "off", "info still answers so clients can show why");

	env.DB.raw.exec("UPDATE meta SET value = 0 WHERE key = 'mode'");
	assert.equal((await call(env, "POST", "/v1/send", { ...alice, text: "back" })).status, 201, "switching it on again needs no redeploy");
});

await test("per-network send limit stops floods that rotate fake user ids", async () => {
	const env = makeEnv({ IP_SENDS_PER_MIN: "3" });
	const from = { "cf-connecting-ip": "203.0.113.7" };
	for (let index = 1; index <= 3; index++) {
		const sent = await call(env, "POST", "/v1/send", { ...alice, userId: 500 + index, name: `bot${index}`, text: "spam", token: `t${index}`.padEnd(20, "x") }, from);
		assert.equal(sent.status, 201, `message ${index} passes`);
	}
	const flood = await call(env, "POST", "/v1/send", { ...alice, userId: 600, name: "bot4", text: "spam", token: "t4".padEnd(20, "x") }, from);
	assert.equal(flood.status, 429);
	assert.equal(flood.body.error, "ip_rate_limited");
	const elsewhere = await call(env, "POST", "/v1/send", { ...bob, text: "different network" }, { "cf-connecting-ip": "198.51.100.9" });
	assert.equal(elsewhere.status, 201, "other networks are unaffected");

	// the window resets after a minute
	env.DB.raw.exec("UPDATE ip_limits SET minute = minute - 2");
	assert.equal((await call(env, "POST", "/v1/send", { ...alice, userId: 601, name: "bot5", text: "ok again", token: "t5".padEnd(20, "x") }, from)).status, 201);
});

await test("a network can only start chatting with a few new accounts per hour", async () => {
	const env = makeEnv({ IP_NEW_USERS_PER_HOUR: "2" });
	const from = { "cf-connecting-ip": "203.0.113.50" };
	const as = (id) => ({ channel: "global", userId: id, name: `u${id}`, displayName: `U${id}`, token: `token-${id}`.padEnd(24, "x"), text: "hi" });
	assert.equal((await call(env, "POST", "/v1/send", as(1001), from)).status, 201);
	assert.equal((await call(env, "POST", "/v1/send", as(1002), from)).status, 201);
	const third = await call(env, "POST", "/v1/send", as(1003), from);
	assert.equal(third.status, 429);
	assert.equal(third.body.error, "too_many_identities");
	assert.equal((await call(env, "POST", "/v1/send", as(1001), from)).status, 201, "an account that already exists keeps working");
});

await test("network addresses are stored hashed, never raw", async () => {
	const env = makeEnv({ IP_SENDS_PER_MIN: "5" });
	await call(env, "POST", "/v1/send", { ...alice, text: "x" }, { "cf-connecting-ip": "203.0.113.99" });
	const rows = env.DB.raw.prepare("SELECT ip_hash FROM ip_limits").all();
	assert.equal(rows.length, 1);
	assert.match(rows[0].ip_hash, /^[0-9a-f]{16}$/);
	assert.ok(!JSON.stringify(rows).includes("203.0.113"));
});

await test("retention: expired messages vanish immediately and are deleted by the hourly cleanup", async () => {
	const env = makeEnv({ RETENTION_HOURS: "1" });
	await call(env, "POST", "/v1/send", { ...alice, text: "fresh" });
	await call(env, "POST", "/v1/send", { ...bob, text: "old" });
	env.DB.raw.exec("UPDATE messages SET created_at = created_at - 7200 WHERE text = 'old'"); // two hours ago

	const history = await call(env, "GET", "/v1/history?channel=global");
	assert.deepEqual(history.body.messages.map((m) => m.text), ["fresh"], "hidden even before it is physically deleted");
	assert.equal((await call(env, "GET", "/v1/poll?channel=global&since=0")).body.messages.length, 1);
	assert.equal(env.DB.raw.prepare("SELECT COUNT(*) AS n FROM messages").get().n, 2, "still stored until the cleanup runs");

	let finished;
	await worker.scheduled({}, env, { waitUntil: (promise) => (finished = promise) });
	await finished;
	assert.equal(env.DB.raw.prepare("SELECT COUNT(*) AS n FROM messages").get().n, 1, "the cron deleted it");
});

await test("the cleanup also trims each channel to KEEP_MESSAGES and drops old network rows", async () => {
	const env = makeEnv({ KEEP_MESSAGES: "3" });
	for (let index = 1; index <= 6; index++) await call(env, "POST", "/v1/send", { ...alice, text: `k${index}` });
	env.DB.raw.exec("INSERT INTO ip_limits (ip_hash, minute, sends, hour, new_users) VALUES ('stale', 1, 1, 1, 0)");
	let finished;
	await worker.scheduled({}, env, { waitUntil: (promise) => (finished = promise) });
	await finished;
	const texts = env.DB.raw.prepare("SELECT text FROM messages ORDER BY id").all().map((row) => row.text);
	assert.deepEqual(texts, ["k4", "k5", "k6"]);
	assert.equal(env.DB.raw.prepare("SELECT COUNT(*) AS n FROM ip_limits WHERE ip_hash = 'stale'").get().n, 0);
});

await test("names come from Roblox, so a client cannot invent a display name", async () => {
	const env = makeEnv({ VERIFY_ROBLOX: "true" });
	const counter = fakeRoblox({ 101: { name: "alice_rbx", displayName: "Alice Real" } });
	try {
		const sent = await call(env, "POST", "/v1/send", { ...alice, displayName: "Totally Someone Else", name: "faker", text: "hi" });
		assert.equal(sent.status, 201);
		assert.equal(sent.body.message.name, "alice_rbx");
		assert.equal(sent.body.message.displayName, "Alice Real");
		await call(env, "POST", "/v1/send", { ...alice, text: "again" });
		assert.equal(counter.calls, 1, "the profile is cached, Roblox is asked once");
	} finally {
		restoreFetch();
	}
});

await test("an id that does not exist is rejected", async () => {
	const env = makeEnv({ VERIFY_ROBLOX: "true" });
	fakeRoblox({ 101: { name: "alice_rbx", displayName: "Alice" } });
	try {
		const ghost = await call(env, "POST", "/v1/send", { ...alice, userId: 999999, text: "boo" });
		assert.equal(ghost.status, 400);
		assert.equal(ghost.body.error, "unknown_user");
	} finally {
		restoreFetch();
	}
});

await test("strict mode: a Roblox outage holds back NEW accounts instead of trusting the client's names", async () => {
	const env = makeEnv({ VERIFY_ROBLOX: "true" });
	const counter = fakeRoblox({ 202: "down" });
	try {
		const blocked = await call(env, "POST", "/v1/send", { ...bob, displayName: "Owner Of The Hub", text: "let me in" });
		assert.equal(blocked.status, 503);
		assert.equal(blocked.body.error, "verification_unavailable");
		assert.equal(counter.calls, 2, "the lookup is retried once");
		assert.equal(env.DB.raw.prepare("SELECT COUNT(*) AS n FROM messages").get().n, 0, "nothing was stored");
		assert.equal(env.DB.raw.prepare("SELECT COUNT(*) AS n FROM users").get().n, 0, "and no identity was bound");
	} finally {
		restoreFetch();
	}
});

await test("a rate-limited lookup is retried and succeeds", async () => {
	const env = makeEnv({ VERIFY_ROBLOX: "true" });
	let calls = 0;
	globalThis.fetch = async () => {
		calls++;
		if (calls === 1) return new Response("slow down", { status: 429 });
		return new Response(JSON.stringify({ id: 101, name: "alice_rbx", displayName: "Alice Real" }), { status: 200 });
	};
	try {
		const sent = await call(env, "POST", "/v1/send", { ...alice, displayName: "Fake Name", text: "hi" });
		assert.equal(sent.status, 201);
		assert.equal(sent.body.message.displayName, "Alice Real");
		assert.equal(calls, 2);
	} finally {
		restoreFetch();
	}
});

await test("accounts with a cached name keep chatting through an outage", async () => {
	const env = makeEnv({ VERIFY_ROBLOX: "true" });
	fakeRoblox({ 101: { name: "alice_rbx", displayName: "Alice Real" } });
	try {
		assert.equal((await call(env, "POST", "/v1/send", { ...alice, text: "first" })).status, 201);
		env.DB.raw.exec("UPDATE profiles SET fetched_at = fetched_at - 864000"); // the cache is 10 days old: due for a refresh
		fakeRoblox({ 101: "down" });
		const during = await call(env, "POST", "/v1/send", { ...alice, displayName: "Spoof", text: "second" });
		assert.equal(during.status, 201, "the stale cached name is better than nothing");
		assert.equal(during.body.message.displayName, "Alice Real");
	} finally {
		restoreFetch();
	}
});

await test("lenient mode trusts the client's names when Roblox cannot be reached", async () => {
	const env = makeEnv({ VERIFY_ROBLOX: "lenient" });
	fakeRoblox({ 202: "down" });
	try {
		const outage = await call(env, "POST", "/v1/send", { ...bob, text: "still works" });
		assert.equal(outage.status, 201);
		assert.equal(outage.body.message.displayName, "Bob");
	} finally {
		restoreFetch();
	}
});

await test("reserved display names are for the owners only", async () => {
	const env = makeEnv({ VERIFY_ROBLOX: "true", OWNER_IDS: "202" });
	fakeRoblox({ 101: { name: "alice_rbx", displayName: "Admin" }, 202: { name: "bob_rbx", displayName: "Owner" }, 303: { name: "carl", displayName: "Administrator Fan" } });
	try {
		const impostor = await call(env, "POST", "/v1/send", { ...alice, text: "I am the admin" });
		assert.equal(impostor.status, 403);
		assert.equal(impostor.body.error, "reserved_name");
		assert.equal((await call(env, "POST", "/v1/send", { ...bob, text: "the real owner" })).status, 201, "OWNER_IDS may use reserved names");
		const partial = await call(env, "POST", "/v1/send", { channel: "global", userId: 303, name: "carl", displayName: "x", token: TOKEN_A, text: "hi" });
		assert.equal(partial.status, 201, "only whole words are reserved ('Administrator Fan' is fine with 'admin' reserved)");
	} finally {
		restoreFetch();
	}
});

await test("the optional filter (off by default) can block links and phone numbers", async () => {
	const open = makeEnv();
	assert.equal((await call(open, "POST", "/v1/send", { ...alice, text: "join discord.gg/abc or call 0812 3456 7890" })).status, 201, "no filter by default");

	const strict = makeEnv({ FILTER: "links,phone" });
	for (const text of ["go to https://evil.example", "visit www.scam.net now", "discord.gg/free-robux", "free stuff at robux.gg", "call me 0812-3456-7890", "+62 812 3456 7890"]) {
		const blocked = await call(strict, "POST", "/v1/send", { ...alice, text });
		assert.equal(blocked.status, 400, `blocked: ${text}`);
		assert.equal(blocked.body.error, "blocked_content");
	}
	for (const text of ["hello friends", "I have 3 apples and 12 oranges", "level 99999 reached", "a.b is not a link", "see you at 9.30"]) {
		assert.equal((await call(strict, "POST", "/v1/send", { ...alice, text })).status, 201, `allowed: ${text}`);
	}

	const linksOnly = makeEnv({ FILTER: "links" });
	assert.equal((await call(linksOnly, "POST", "/v1/send", { ...alice, text: "call 0812 3456 7890" })).status, 201, "rules are independent");
});

await test("/v1/info exposes the settings clients need, and no secrets", async () => {
	const env = makeEnv({ RETENTION_HOURS: "48", FILTER: "links", NOTICE: "Be nice.", COOLDOWN_MS: "1500", IP_SALT: "secret-salt" });
	const result = await call(env, "GET", "/v1/info");
	assert.deepEqual(result.body, { mode: "on", maxLength: 200, cooldownMs: 1500, retentionHours: 48, filter: ["links"], notice: "Be nice." });
	assert.ok(!JSON.stringify(result.body).includes("secret-salt"));
});

console.log(`worker tests passed (${passed})`);
