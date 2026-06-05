const fs = require("fs");
const path = require("path");

const LINE_PATTERN =
	/^(\t+)(set_board|place_stone|place_stone_for)\(g,\s*\{ (.+) \}\)(, false)?\s*$/;

function reformatLine(line) {
	const m = line.match(LINE_PATTERN);
	if (!m) {
		return { line, changed: false };
	}
	const indent = m[1];
	const fn = m[2];
	const inner = m[3];
	const extra = m[4] || "";
	const rows = [...inner.matchAll(/"([^"]*)"/g)].map((x) => x[1]);
	if (rows.length < 2) {
		return { line, changed: false };
	}
	const rowIndent = indent + "\t\t\t";
	const lines = rows.map((r) => `${rowIndent}"${r}",`);
	lines[lines.length - 1] = lines[lines.length - 1].slice(0, -1);
	const body =
		`${indent}${fn}(g, {\n` + lines.join("\n") + `\n${indent}\t\t})${extra}`;
	return { line: body, changed: true };
}

function reformatFile(filePath) {
	const text = fs.readFileSync(filePath, "utf8");
	let count = 0;
	const out = text.split(/\r?\n/).map((bare) => {
		const { line, changed } = reformatLine(bare);
		if (changed) {
			count++;
		}
		return line;
	});
	if (count > 0) {
		fs.writeFileSync(filePath, out.join("\n") + (text.endsWith("\n") ? "\n" : ""));
	}
	return count;
}

const root = path.join(__dirname, "..", "spec", "visual", "stones_scoring");
let total = 0;
for (const name of fs.readdirSync(root).sort()) {
	if (!name.endsWith(".lua")) {
		continue;
	}
	const n = reformatFile(path.join(root, name));
	if (n > 0) {
		console.log(`${name}: ${n}`);
		total += n;
	}
}
console.log(`total: ${total}`);
