// Bundles every src/**/*.lua module into a single dist/main.lua.
//
// Each module is wrapped as `__modules["path/name"] = function(Import) ... end`
// and resolved lazily through Import("path/name"), so the result can be loaded
// with a single loadstring call on any executor.

import { readdirSync, readFileSync, writeFileSync, mkdirSync, statSync } from "node:fs";
import { dirname, join, relative, sep } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const srcDir = join(root, "src");
const outFile = join(root, "dist", "main.lua");
const version = JSON.parse(readFileSync(join(root, "package.json"), "utf8")).version;

function walk(dir) {
	const files = [];
	for (const entry of readdirSync(dir).sort()) {
		const full = join(dir, entry);
		if (statSync(full).isDirectory()) files.push(...walk(full));
		else if (entry.endsWith(".lua")) files.push(full);
	}
	return files;
}

const modules = walk(srcDir).map((file) => ({
	name: relative(srcDir, file).split(sep).join("/").replace(/\.lua$/, ""),
	source: readFileSync(file, "utf8").replace(/\r\n/g, "\n").replace("@VERSION@", version),
}));

if (!modules.some((m) => m.name === "init")) throw new Error("src/init.lua is missing");

let out = "";
out += `-- Mugiwara UI v${version}\n`;
out += "-- Glass + neon Gear 5 UI library for Roblox script hubs.\n";
out += "-- https://github.com/honamichanhere/Mugiwara-UI  |  MIT License\n\n";
out += "local __modules, __cache = {}, {}\n\n";
out += "local function Import(name)\n";
out += "\tlocal cached = __cache[name]\n";
out += "\tif cached then\n\t\treturn cached.Value\n\tend\n";
out += "\tlocal factory = __modules[name]\n";
out += "\tif not factory then\n\t\terror(\"MugiwaraUI: missing module \" .. tostring(name), 2)\n\tend\n";
out += "\tlocal value = factory(Import)\n";
out += "\t__cache[name] = { Value = value }\n";
out += "\treturn value\nend\n\n";

for (const mod of modules) {
	out += `__modules[${JSON.stringify(mod.name)}] = function(Import)\n`;
	out += mod.source.replace(/\s+$/, "") + "\n";
	out += "end\n\n";
}

out += 'return Import("init")\n';

mkdirSync(dirname(outFile), { recursive: true });
writeFileSync(outFile, out);
console.log(`Built ${modules.length} modules -> ${relative(root, outFile)} (${(out.length / 1024).toFixed(1)} KB)`);
