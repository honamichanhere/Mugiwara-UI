// Static check for every src/**/*.lua: syntax errors and references to undefined globals.
// (There is no Luau toolchain in CI, so this catches typos that would only blow up in the executor.)

import { readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import luaparse from "luaparse";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");

const ALLOWED = new Set(
	(
		"game workspace script Instance Enum Vector2 Vector3 UDim UDim2 Color3 ColorSequence ColorSequenceKeypoint " +
		"NumberSequence NumberSequenceKeypoint TweenInfo Rect CFrame Random Ray " +
		"task typeof warn error print pcall xpcall select type tostring tonumber ipairs pairs next unpack " +
		"setmetatable getmetatable rawget rawset rawequal assert require " +
		"math string table os utf8 coroutine bit32 buffer " +
		"_G _VERSION Import " +
		// executor globals — every use must be guarded / optional
		"getgenv gethui cloneref identifyexecutor syn protect_gui writefile readfile isfile makefolder isfolder " +
		"delfile listfiles setclipboard toclipboard Clipboard loadstring request http_request"
	).split(" ")
);

function walkFiles(dir) {
	const out = [];
	for (const entry of readdirSync(dir).sort()) {
		const full = join(dir, entry);
		if (statSync(full).isDirectory()) out.push(...walkFiles(full));
		else if (entry.endsWith(".lua")) out.push(full);
	}
	return out;
}

function visit(node, parent, onNode) {
	if (!node || typeof node !== "object") return;
	if (Array.isArray(node)) {
		for (const child of node) visit(child, parent, onNode);
		return;
	}
	if (node.type) onNode(node, parent);
	for (const key of Object.keys(node)) {
		if (key === "loc" || key === "range" || key === "globals" || key === "comments") continue;
		const value = node[key];
		if (value && typeof value === "object") visit(value, node, onNode);
	}
}

let problems = 0;
const files = walkFiles(join(root, "src"));

for (const file of files) {
	const rel = relative(root, file);
	const source = readFileSync(file, "utf8");
	let ast;
	try {
		ast = luaparse.parse(source, { luaVersion: "5.1", scope: true, locations: true });
	} catch (error) {
		console.error(`SYNTAX  ${rel}: ${error.message}`);
		problems++;
		continue;
	}

	const seen = new Set();
	visit(ast, null, (node, parent) => {
		if (node.type !== "Identifier" || node.isLocal) return;
		if (parent && parent.type === "MemberExpression" && parent.identifier === node) return;
		if (parent && parent.type === "TableKeyString" && parent.key === node) return;
		if (parent && parent.type === "FunctionDeclaration" && parent.identifier === node && parent.isLocal) return;
		if (ALLOWED.has(node.name)) return;
		const key = `${node.name}@${node.loc.start.line}`;
		if (seen.has(key)) return;
		seen.add(key);
		console.error(`GLOBAL  ${rel}:${node.loc.start.line} uses undefined global '${node.name}'`);
		problems++;
	});
}

if (problems > 0) {
	console.error(`\n${problems} problem(s) in ${files.length} files`);
	process.exit(1);
}
console.log(`OK - ${files.length} files, no syntax errors, no undefined globals`);
