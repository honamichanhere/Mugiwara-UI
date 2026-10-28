// Runs the Worker's fetch handler against a real SQLite database (node:sqlite stands in for D1),
// so the actual SQL and the batch / transaction behavior are exercised.

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { DatabaseSync } from "node:sqlite";
import worker from "../src/index.js";

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

function makeEnv(extra = {}) {
	return { DB: createD1(), MAX_LENGTH: "200", COOLDOWN_MS: "0", ...extra };
}

async function call(env, method, path, body) {
	const request = new Request("https://chat.test" + path, {
		method,
		headers: body ? { "content-type": "application/json" } : undefined,
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

await test("health, CORS preflight and unknown routes", async () => {
	const env = makeEnv();
	assert.equal((await call(env, "GET", "/")).body.ok, true);
	assert.equal((await call(env, "OPTIONS", "/v1/send")).status, 204);
	assert.equal((await call(env, "GET", "/nope")).status, 404);
	assert.equal((await call(env, "GET", "/v1/history?channel=BAD CHANNEL!")).status, 400);
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

console.log(`worker tests passed (${passed})`);
