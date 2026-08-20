#!/usr/bin/env node
// Validates the kit's invariants. Run: node scripts/validate.mjs
// Exits non-zero on any failure, so it works as a CI gate.

import { readdirSync, readFileSync, statSync, existsSync } from "node:fs";
import { join, dirname, resolve, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { execSync } from "node:child_process";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const errors = [];
const warn = [];

const walk = (dir, acc = []) => {
  for (const n of readdirSync(dir)) {
    if (n === ".git" || n === "node_modules") continue;
    const p = join(dir, n);
    if (statSync(p).isDirectory()) walk(p, acc);
    else if (n.endsWith(".md")) acc.push(p);
  }
  return acc;
};

const files = walk(root);
const rel = (p) => relative(root, p);

// GitHub-style anchor slug
const slug = (s) =>
  s.toLowerCase().trim()
    .replace(/[^\w\s-]/g, "")
    .replace(/\s/g, "-");

const headingsOf = (text) =>
  new Set([...text.matchAll(/^#{1,6}\s+(.*)$/gm)].map((m) => slug(m[1])));

// 1. No addresses anywhere.
for (const f of files) {
  const hits = readFileSync(f, "utf8").match(/0x[a-fA-F0-9]{40}/g);
  if (hits) errors.push(`${rel(f)}: contains address(es): ${[...new Set(hits)].join(", ")}`);
}

// 2. Every card under references/ (except CATALOG/card-format) has title + triggers.
for (const f of files) {
  const r = rel(f);
  if (!r.startsWith("references/")) continue;
  if (r.endsWith("CATALOG.md") || r.endsWith("card-format.md")) continue;
  const text = readFileSync(f, "utf8");
  const fm = text.match(/^---\n([\s\S]*?)\n---/);
  if (!fm) { errors.push(`${r}: missing frontmatter`); continue; }
  for (const k of ["title", "triggers"])
    if (!new RegExp(`^${k}:`, "m").test(fm[1])) errors.push(`${r}: frontmatter missing '${k}'`);
}

// 3. Relative links resolve, including anchors.
let linkCount = 0;
for (const f of files) {
  const text = readFileSync(f, "utf8");
  for (const m of text.matchAll(/\]\((?!https?:|mailto:)([^)\s]*?)(#[^)\s]*)?\)/g)) {
    const [, target, anchor] = m;
    linkCount++;
    const dest = target ? resolve(dirname(f), target) : f;
    if (target && !existsSync(dest)) { errors.push(`${rel(f)}: broken link -> ${target}`); continue; }
    if (anchor && dest.endsWith(".md")) {
      const want = anchor.slice(1).toLowerCase();
      if (!headingsOf(readFileSync(dest, "utf8")).has(want))
        warn.push(`${rel(f)}: anchor not found -> ${target || ""}${anchor}`);
    }
  }
}

// 4. Catalog is current.
try {
  const before = readFileSync(join(root, "references/CATALOG.md"), "utf8");
  execSync("node scripts/build-catalog.mjs", { cwd: root, stdio: "pipe" });
  if (readFileSync(join(root, "references/CATALOG.md"), "utf8") !== before)
    errors.push("references/CATALOG.md is stale — run: node scripts/build-catalog.mjs");
} catch (e) {
  errors.push(`catalog build failed: ${e.message}`);
}

console.log(`checked ${files.length} markdown files, ${linkCount} relative links`);
for (const w of warn) console.log(`  warn: ${w}`);
if (errors.length) {
  console.error(`\n${errors.length} error(s):`);
  for (const e of errors) console.error(`  ${e}`);
  process.exit(1);
}
console.log(warn.length ? `OK (${warn.length} warning(s))` : "OK");
