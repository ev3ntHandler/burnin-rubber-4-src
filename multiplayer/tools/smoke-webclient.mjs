#!/usr/bin/env node
/**
 * Browser smoke test for the web harness, without a browser.
 *
 * `tools/check-webclient.mjs` is a static gate (parses modules, resolves ids and
 * imports). This one actually boots `packages/webclient/src/app.js` against a
 * live server inside a minimal DOM/canvas shim, clicks "Race", pumps frames and
 * then asserts on what the DOM would show: the game screen is visible, the room
 * was joined, snapshots arrive, the canvas is drawing and the lobby list is
 * populated. It catches the class of bug the static gate cannot see (a rename
 * that only breaks at runtime, a socket that never opens, a renderer that
 * throws on the first frame).
 *
 *   node tools/smoke-webclient.mjs --url http://localhost:8080 --seconds 10
 */
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join, resolve } from 'node:path';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '..');
const SRC = join(ROOT, 'packages', 'webclient', 'src');
const TMP = join(ROOT, '.tmp', 'smoke');

const args = process.argv.slice(2);
const flag = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i === -1 ? fallback : args[i + 1];
};
const base = (flag('url', 'http://localhost:8080') || '').replace(/\/$/, '');
const seconds = Number(flag('seconds', 10));
const mode = flag('mode', 'race'); // race | roam
const verbose = args.includes('--verbose');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const failures = [];
const check = (ok, label, detail = '') => {
  if (ok) console.log(`  ✓ ${label}`);
  else {
    console.log(`  ✗ ${label}${detail ? ` — ${detail}` : ''}`);
    failures.push(label);
  }
};

// ── DOM shim ────────────────────────────────────────────────────────────
const NOOP = () => {};
const drawCalls = { count: 0 };

function makeContext() {
  const target = {
    canvas: null,
    createLinearGradient: () => ({ addColorStop: NOOP }),
    createRadialGradient: () => ({ addColorStop: NOOP }),
    measureText: (t) => ({ width: String(t).length * 6 }),
    getImageData: () => ({ data: new Uint8ClampedArray(4) }),
  };
  return new Proxy(target, {
    get(obj, prop) {
      if (prop in obj) return obj[prop];
      if (typeof prop !== 'string') return undefined;
      return (...a) => {
        drawCalls.count++;
        if (verbose && drawCalls.count < 12) console.log(`    ctx.${prop}(${a.length})`);
        return undefined;
      };
    },
    set(obj, prop, value) {
      obj[prop] = value;
      return true;
    },
  });
}

class ClassList {
  constructor() {
    this.set = new Set();
  }
  add(...names) {
    for (const n of names) this.set.add(n);
  }
  remove(...names) {
    for (const n of names) this.set.delete(n);
  }
  contains(name) {
    return this.set.has(name);
  }
  toggle(name, force) {
    const on = force === undefined ? !this.set.has(name) : Boolean(force);
    if (on) this.set.add(name);
    else this.set.delete(name);
    return on;
  }
  get value() {
    return [...this.set].join(' ');
  }
}

class El {
  constructor(tag = 'div', id = '') {
    this.tagName = String(tag).toUpperCase();
    this.id = id;
    this.children = [];
    this.style = {};
    this.handlers = new Map();
    this.classList = new ClassList();
    this.value = '';
    this.checked = false;
    this.disabled = false;
    this.scrollTop = 0;
    this._text = '';
    this._html = '';
    this.width = 0;
    this.height = 0;
    this.parentNode = null;
    this.ctx = null;
  }
  get textContent() {
    return this._text;
  }
  set textContent(v) {
    this._text = String(v ?? '');
  }
  get innerHTML() {
    return this._html;
  }
  set innerHTML(v) {
    this._html = String(v ?? '');
    if (!this._html) this.children = [];
  }
  get firstChild() {
    return this.children[0] ?? null;
  }
  get lastChild() {
    return this.children[this.children.length - 1] ?? null;
  }
  get scrollHeight() {
    return this.children.length * 20;
  }
  appendChild(child) {
    this.children.push(child);
    child.parentNode = this;
    return child;
  }
  append(...nodes) {
    for (const n of nodes) this.appendChild(typeof n === 'string' ? new El('span') : n);
  }
  removeChild(child) {
    this.children = this.children.filter((c) => c !== child);
    return child;
  }
  remove() {
    this.parentNode?.removeChild(this);
  }
  addEventListener(type, fn) {
    if (!this.handlers.has(type)) this.handlers.set(type, []);
    this.handlers.get(type).push(fn);
  }
  removeEventListener(type, fn) {
    this.handlers.set(type, (this.handlers.get(type) ?? []).filter((f) => f !== fn));
  }
  dispatch(type, event = {}) {
    const ev = { type, preventDefault: NOOP, stopPropagation: NOOP, ...event };
    for (const fn of this.handlers.get(type) ?? []) fn(ev);
    return ev;
  }
  click() {
    this.dispatch('click');
  }
  focus() {}
  blur() {}
  getContext() {
    if (!this.ctx) {
      this.ctx = makeContext();
      this.ctx.canvas = this;
    }
    return this.ctx;
  }
  getBoundingClientRect() {
    return { x: 0, y: 0, width: 1280, height: 720, top: 0, left: 0 };
  }
  querySelector() {
    return null;
  }
  querySelectorAll() {
    return [];
  }
}

const byId = new Map();
const ensureEl = (id, tag = 'div') => {
  let el = byId.get(id);
  if (!el) {
    el = new El(tag, id);
    byId.set(id, el);
  }
  return el;
};

// ids from index.html (kept in sync by tools/check-webclient.mjs)
const ids = [
  'lobby', 'name', 'vehicle', 'world', 'track-label', 'track', 'btn-roam', 'btn-race', 'refresh',
  'rooms', 'game', 'stage', 'hud-top', 'room-pill', 'ping-pill', 'players-pill', 'race-panel',
  'race-phase', 'race-timer', 'race-countdown', 'standings', 'speedo', 'speed-value', 'health-bar',
  'nitro-bar', 'killfeed', 'toasts', 'chat', 'chat-log', 'chat-form', 'chat-input', 'help', 'leave',
  'btn-leave', 'btn-help',
];
for (const id of ids) {
  const tag = id === 'stage' ? 'canvas' : id === 'name' || id === 'chat-input' ? 'input' : 'div';
  ensureEl(id, tag);
}
ensureEl('game').classList.add('hidden');
ensureEl('help').classList.add('hidden');

const document = {
  getElementById: (id) => byId.get(id) ?? null,
  createElement: (tag) => new El(tag),
  querySelector: (sel) => (sel.startsWith('#') ? byId.get(sel.slice(1)) ?? null : null),
  addEventListener: NOOP,
  body: new El('body', 'body'),
  documentElement: new El('html', 'html'),
  hidden: false,
};

const store = new Map();
const localStorage = {
  getItem: (k) => (store.has(k) ? store.get(k) : null),
  setItem: (k, v) => store.set(k, String(v)),
  removeItem: (k) => store.delete(k),
};

const winHandlers = new Map();
const window = {
  innerWidth: 1280,
  innerHeight: 720,
  devicePixelRatio: 1,
  addEventListener: (type, fn) => {
    if (!winHandlers.has(type)) winHandlers.set(type, []);
    winHandlers.get(type).push(fn);
  },
  removeEventListener: NOOP,
  localStorage,
  document,
  requestAnimationFrame: (fn) => queueFrame(fn),
  cancelAnimationFrame: NOOP,
  location: { protocol: 'http:', host: base.replace(/^https?:\/\//, ''), href: `${base}/` },
  setInterval,
  clearInterval,
  setTimeout,
  clearTimeout,
};

const frames = [];
let frameSeq = 0;
function queueFrame(fn) {
  frames.push(fn);
  return ++frameSeq;
}

function pumpFrame() {
  const due = frames.splice(0, frames.length);
  for (const fn of due) {
    try {
      fn(performance.now());
    } catch (err) {
      errors.push(err);
    }
  }
}

const errors = [];
const realFetch = globalThis.fetch;
const shimFetch = (input, init) => {
  const url = typeof input === 'string' ? input : String(input?.url ?? input);
  return realFetch(url.startsWith('http') ? url : `${base}${url.startsWith('/') ? '' : '/'}${url}`, init);
};

Object.assign(globalThis, {
  window,
  document,
  localStorage,
  location: window.location,
  fetch: shimFetch,
  requestAnimationFrame: queueFrame,
  cancelAnimationFrame: NOOP,
  devicePixelRatio: 1,
});
globalThis.self ??= globalThis;

// ── load the real client modules with the protocol import rewritten ─────
const MODULES = ['app.js', 'net.js', 'sim.js', 'render.js', 'ui.js'];
const protocolPath = pathToFileURL(join(ROOT, 'packages', 'protocol', 'dist', 'src', 'index.js')).href;

await mkdir(TMP, { recursive: true });
for (const name of MODULES) {
  const source = await readFile(join(SRC, name), 'utf8');
  const rewritten = source.replace(/(['"])\/lib\/protocol\/src\/index\.js\1/g, `'${protocolPath}'`);
  await writeFile(join(TMP, name), rewritten);
}

process.on('uncaughtException', (err) => errors.push(err));
process.on('unhandledRejection', (err) => errors.push(err));

console.log(`\nsmoke: booting webclient against ${base} (${mode})\n`);
const appModule = await import(pathToFileURL(join(TMP, 'app.js')).href + `?t=${Date.now()}`);
void appModule;

// let the bootstrap fetch the catalog + room list
for (let i = 0; i < 40; i++) {
  await sleep(50);
  pumpFrame();
}

const roomList = byId.get('rooms').children;
const roomsText = roomList.map((c) => c.innerHTML || c.textContent).join(' | ');
check(roomList.length > 0 && /City|Industrial|Jungle|Snow|city-1/.test(roomsText), 'lobby room list rendered from /mp/rooms', roomsText.slice(0, 100));

// pick a name and press the start button
byId.get('name').value = `Smoke${Math.floor(Math.random() * 900 + 100)}`;
const startBtn = byId.get(mode === 'roam' ? 'btn-roam' : 'btn-race');
startBtn.click();

const frameTimer = setInterval(pumpFrame, 16);
const deadline = Date.now() + seconds * 1000;
let joined = false;
let framesBefore = 0;
while (Date.now() < deadline) {
  await sleep(100);
  const chatLines = byId.get('chat-log').children;
  if (chatLines.length > framesBefore) framesBefore = chatLines.length;
  if (/player|players/.test(byId.get('players-pill').textContent)) joined = true;
  if (joined && drawCalls.count > 0 && byId.get('speed-value').textContent) break;
}
clearInterval(frameTimer);
pumpFrame();

const game = byId.get('game');
const lobby = byId.get('lobby');
check(game.classList.contains('hidden') === false, 'game screen visible');
check(lobby.classList.contains('hidden') === true, 'lobby hidden while playing');
check(errors.length === 0, 'no uncaught client errors', errors.map((e) => e?.message ?? String(e)).join('; '));
check(joined || /player/.test(byId.get('players-pill').textContent), 'joined a room (roster pill updated)', byId.get('players-pill').textContent);
check(byId.get('room-pill').textContent && byId.get('room-pill').textContent !== '—', 'room pill named', byId.get('room-pill').textContent);
const chatText = byId.get('chat-log').children.map((c) => c.textContent || c.innerHTML).join(' | ');
check(byId.get('chat-log').children.length > 0, 'chat log received server lines', chatText.slice(0, 120));
check(byId.get('ping-pill').textContent !== '—' && /\d/.test(byId.get('ping-pill').textContent), 'ping measured', byId.get('ping-pill').textContent);
check(drawCalls.count > 100, 'canvas renderer drew frames', `${drawCalls.count} 2d calls`);
check(/\d/.test(byId.get('speed-value').textContent ?? ''), 'speedometer updates', byId.get('speed-value').textContent);
if (mode === 'race') {
  const phase = byId.get('race-phase').textContent;
  check(phase && phase !== '—', 'race panel shows a phase', phase);
}

const text = JSON.stringify({ errors: errors.length, draws: drawCalls.count, frames: frameSeq });
console.log(`\n  ${failures.length ? `${failures.length} check(s) failed` : 'all checks passed'}  ${text}\n`);
process.exit(failures.length ? 1 : 0);
