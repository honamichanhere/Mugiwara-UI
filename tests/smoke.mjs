// Runs tests/smoke.lua against dist/main.lua on fengari (Lua 5.3) with a Roblox API mock.

import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import fengari from "fengari";

const { lua, lauxlib, lualib, to_luastring } = fengari;
const root = join(dirname(fileURLToPath(import.meta.url)), "..");

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

function run(name, source) {
	const status = lauxlib.luaL_loadbuffer(L, to_luastring(source), null, to_luastring("=" + name));
	if (status === lua.LUA_OK) {
		const callStatus = lua.lua_pcall(L, 0, 0, 0);
		if (callStatus !== lua.LUA_OK) fail(name);
	} else {
		fail(name);
	}
}

function fail(name) {
	const message = lua.lua_tojsstring(L, -1);
	console.error(`FAILED in ${name}:\n${message}`);
	process.exit(1);
}

const dist = readFileSync(join(root, "dist", "main.lua"), "utf8");
lua.lua_pushstring(L, to_luastring(dist));
lua.lua_setglobal(L, to_luastring("DIST_SOURCE"));

run("mock", readFileSync(join(root, "tests", "mock.lua"), "utf8"));
run("smoke", readFileSync(join(root, "tests", "smoke.lua"), "utf8"));
