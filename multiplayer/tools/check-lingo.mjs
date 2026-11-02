#!/usr/bin/env node
/**
 * Static checks for the Lingo bridge in lingo/patches.
 *
 * Lingo has no compiler in CI and no unit tests we can run, so this is the
 * closest thing to `tsc` for the Director side. It catches the mistakes that
 * actually bite when pasting movie scripts into Director:
 *
 *   - a handler that is called but never defined (`handler not defined #X`)
 *   - a `gBR4MP.<key>` that BR4MPResetProps never initialises (reads VOID)
 *   - the `gBR4MP = gBR4MP or [:]` bug: `or` is boolean in Lingo, so this
 *     makes gBR4MP an integer and every later `gBR4MP.active` becomes a
 *     handler lookup ("handler not defined #Active")
 *   - `voidP(gBR4MP)` guards instead of `ilk(gBR4MP) <> #propList`
 *   - text after a line-continuation character (¬ must end the line)
 *   - unbalanced `on ... end` blocks
 *   - br4mp_bridge.ls drifting away from the three source scripts
 *
 *   node tools/check-lingo.mjs            # check
 *   node tools/check-lingo.mjs --build    # regenerate br4mp_bridge.ls
 */
import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';

const HERE = dirname(fileURLToPath(import.meta.url));
const DIR = resolve(HERE, '..', 'lingo', 'patches');
const SOURCES = ['br4mp_config.ls', 'br4mp_net.ls', 'br4mp_game.ls'];
const COMBINED = 'br4mp_bridge.ls';

const BUILD = process.argv.includes('--build');
const problems = [];
const report = (file, line, message) => problems.push(`${file}${line ? `:${line}` : ''} — ${message}`);

const stripComment = (line) => {
  // Lingo comments: "--" to end of line (there are no block comments).
  const i = line.indexOf('--');
  return i === -1 ? line : line.slice(0, i);
};

const files = new Map();
for (const name of [...SOURCES, COMBINED]) {
  try {
    files.set(name, await readFile(join(DIR, name), 'utf8'));
  } catch {
    if (name === COMBINED) files.set(name, null);
    else report(name, 0, 'missing');
  }
}

// ── per-file checks ─────────────────────────────────────────────────────
const handlersByFile = new Map();
for (const name of SOURCES) {
  const text = files.get(name) ?? '';
  const lines = text.split('\n');
  const handlers = new Set();
  let openHandlers = 0;

  lines.forEach((raw, index) => {
    const line = raw.replace(/\r$/, '');
    const n = index + 1;
    const code = stripComment(line);

    if (/[ \t]¬[ \t]*$/.test(line) && /¬[ \t]+$/.test(line)) {
      report(name, n, 'line-continuation "¬" must be the last character (trailing whitespace)');
    }
    if (/¬.*\S/.test(code.slice(code.indexOf('¬') + 1))) {
      report(name, n, 'text after a line-continuation character');
    }

    const def = code.match(/^\s*on\s+([A-Za-z_][\w]*)/i);
    if (def) {
      handlers.add(def[1]);
      openHandlers++;
    }
    if (/^\s*end\s*$/i.test(code)) openHandlers--;

    if (/=\s*gBR4MP\s+or\b/i.test(code)) {
      report(name, n, '`gBR4MP = gBR4MP or [:]` makes gBR4MP TRUE/1 — use BR4MPEnsure (ilk check)');
    }
    if (/voidP\s*\(\s*gBR4MP\s*\)/i.test(code)) {
      report(name, n, 'voidP(gBR4MP) does not protect against a damaged global — use ilk(gBR4MP) <> #propList');
    }
  });

  if (openHandlers !== 0) report(name, 0, `unbalanced handlers (${openHandlers} unclosed "on" blocks)`);
  handlersByFile.set(name, handlers);
}

// ── property keys initialised by BR4MPResetProps ───────────────────────
const configText = files.get('br4mp_config.ls') ?? '';
const resetStart = configText.indexOf('on BR4MPResetProps');
const resetEnd = configText.indexOf('on BR4MPDefaults');
const knownKeys = new Set();
for (const line of configText.slice(resetStart, resetEnd).split('\n')) {
  const m = stripComment(line).match(/gBR4MP\.([A-Za-z_][\w]*)\s*=/);
  if (m) knownKeys.add(m[1]);
}
if (!knownKeys.size) report('br4mp_config.ls', 0, 'BR4MPResetProps initialises no keys');

// ── cross-file checks ──────────────────────────────────────────────────
const allHandlers = new Set([...handlersByFile.values()].flatMap((s) => [...s]));
const allLines = SOURCES.map((name) => ({ name, lines: (files.get(name) ?? '').split('\n') }));

for (const { name, lines } of allLines) {
  lines.forEach((raw, index) => {
    const code = stripComment(raw.replace(/\r$/, ''));
    // handler references (calls, `then X`, statement-position X)
    for (const m of code.matchAll(/\bBR4MP[A-Za-z0-9_]+\b/g)) {
      const token = m[0];
      const before = code.slice(0, m.index).trimEnd();
      if (/on$/i.test(before)) continue; // definition
      if (!allHandlers.has(token)) {
        report(name, index + 1, `handler #${token} is referenced but not defined`);
      }
    }
    // property reads
    for (const m of code.matchAll(/gBR4MP\.([A-Za-z_][\w]*)/g)) {
      if (!knownKeys.has(m[1])) {
        report(name, index + 1, `gBR4MP.${m[1]} is never initialised in BR4MPResetProps`);
      }
    }
  });
}

// ── single-file build ──────────────────────────────────────────────────
const header = `-- =====================================================================
--  br4mp_bridge.ls  —  Burnin' Rubber 4 online bridge (single file)
--
--  Generated by tools/check-lingo.mjs --build from
--      br4mp_config.ls + br4mp_net.ls + br4mp_game.ls
--  Do not edit by hand: edit the three sources and rebuild.
--
--  INSTALL: paste this whole file into ONE cast member whose type is
--  "Movie Script" (not Behavior, not Parent), and tick
--  "Include in Shockwave" in that member's properties if you publish a
--  .dcr. Then call BR4MPDiagnostics() from the Message window to verify.
-- =====================================================================

`;
const combinedExpected = header + SOURCES.map((name) => (files.get(name) ?? '').trimEnd()).join('\n\n\n') + '\n';

if (BUILD) {
  await writeFile(join(DIR, COMBINED), combinedExpected);
  console.log(`✓ wrote lingo/patches/${COMBINED} (${SOURCES.join(' + ')})`);
} else if (files.get(COMBINED) === null) {
  report(COMBINED, 0, 'missing — run `node tools/check-lingo.mjs --build`');
} else if (files.get(COMBINED) !== combinedExpected) {
  report(COMBINED, 0, 'out of date with the source scripts — run `node tools/check-lingo.mjs --build`');
}

// ── summary ────────────────────────────────────────────────────────────
const handlerCount = allHandlers.size;
if (problems.length) {
  console.error(`✗ lingo bridge: ${problems.length} problem(s)\n`);
  for (const p of problems) console.error(`  ${p}`);
  process.exit(1);
}
console.log(
  `✓ lingo bridge: ${handlerCount} handlers across ${SOURCES.length} scripts, ` +
    `${knownKeys.size} state keys, ${BUILD ? 'bridge rebuilt' : 'bridge in sync'}`,
);
