#!/usr/bin/env node
/**
 * Static sanity checks for the browser harness:
 *   1. every module parses as ESM (catches typos that would blank the page),
 *   2. every `el('id')` / `$('id')` / `getElementById('id')` reference exists in
 *      index.html (catches silent UI wiring mistakes),
 *   3. no import points at a file that does not exist.
 */
import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { execFileSync } from 'node:child_process';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '..');
const WEB = join(ROOT, 'packages', 'webclient');
const files = readdirSync(join(WEB, 'src')).filter((f) => f.endsWith('.js'));
let failures = 0;

const fail = (msg) => {
  failures++;
  console.error(`  ✗ ${msg}`);
};

// 1. syntax
for (const file of files) {
  const path = join(WEB, 'src', file);
  try {
    execFileSync(process.execPath, ['--check', path], { stdio: 'pipe' });
  } catch (err) {
    fail(`${file} does not parse:\n${err.stderr?.toString() ?? err.message}`);
  }
}

// 2. DOM ids
const html = readFileSync(join(WEB, 'index.html'), 'utf8');
const ids = new Set([...html.matchAll(/\bid="([^"]+)"/g)].map((m) => m[1]));
for (const file of files) {
  const code = readFileSync(join(WEB, 'src', file), 'utf8');
  for (const match of code.matchAll(/(?:el|\$)\(\s*'([a-z0-9-]+)'\s*\)/gi)) {
    const id = match[1];
    if (!ids.has(id)) fail(`${file} references #${id} which is not in index.html`);
  }
  for (const match of code.matchAll(/getElementById\(\s*'([^']+)'\s*\)/g)) {
    if (!ids.has(match[1])) fail(`${file} references #${match[1]} which is not in index.html`);
  }
}

// 3. browser import targets
for (const file of files) {
  const code = readFileSync(join(WEB, 'src', file), 'utf8');
  for (const match of code.matchAll(/from\s+'([^']+)'/g)) {
    const spec = match[1];
    if (spec.startsWith('/lib/protocol/')) {
      const target = join(ROOT, 'packages', 'protocol', 'dist', spec.replace('/lib/protocol/', ''));
      if (!existsSync(target)) fail(`${file} imports ${spec} but ${target} is missing (run npm run build)`);
    } else if (spec.startsWith('./')) {
      const target = join(WEB, 'src', spec);
      if (!existsSync(target)) fail(`${file} imports ${spec} which does not exist`);
    }
  }
}

if (failures) {
  console.error(`\n✗ webclient checks failed (${failures})`);
  process.exit(1);
}
console.log(`✓ webclient: ${files.length} modules parse, DOM ids and imports resolve`);
void pathToFileURL;
