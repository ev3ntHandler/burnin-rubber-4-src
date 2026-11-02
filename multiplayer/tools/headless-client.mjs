#!/usr/bin/env node
/**
 * Headless client/reference driver.
 *
 * Imports the *exact* networking and vehicle modules the browser harness uses
 * (`packages/webclient/src/net.js` + `sim.js`) so this doubles as an end to end
 * protocol test and as a load generator:
 *
 *   node tools/headless-client.mjs --url http://localhost:8080 --mode race --track city-1
 *   node tools/headless-client.mjs --bots 20 --seconds 20        (load test)
 */
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '..');

const PROTOCOL = pathToFileURL(join(ROOT, 'packages/protocol/dist/src/index.js')).href;
const TMP = join(ROOT, '.tmp');
mkdirSync(TMP, { recursive: true });
const rewritten = readFileSync(join(ROOT, 'packages/webclient/src/net.js'), 'utf8').replace(
  "'/lib/protocol/src/index.js'",
  `'${PROTOCOL}'`,
);
writeFileSync(join(TMP, 'net.mjs'), rewritten);

const { Net } = await import(pathToFileURL(join(TMP, 'net.mjs')).href);
const { Car } = await import(pathToFileURL(join(ROOT, 'packages/webclient/src/sim.js')).href);
const proto = await import(PROTOCOL);

export async function spawnClient(options) {
  const {
    url = 'http://localhost:8080',
    name = `Bot${Math.floor(Math.random() * 999)}`,
    mode = 0,
    world = 0,
    trackId = '',
    vehicle = 'PlayerCar',
    drive = false,
    onMessage,
    onJoined,
  } = options;

  const manager = new Net({
    message: (msg) => {
      client.messages.push(msg);
      if (msg.op === proto.Op.Correction && client.car) {
        client.car.pos = { ...msg.pos };
        client.car.yaw = Math.atan2(2 * (msg.rot.w * msg.rot.z), 1 - 2 * msg.rot.z * msg.rot.z);
        client.car.speed = Math.hypot(msg.vel.x, msg.vel.y);
      }
      if (msg.op === proto.Op.Snapshot && client.car) {
        const self = msg.entries.find((e) => e.id === client.selfId);
        if (self?.pos && !client.spawned) {
          client.car.pos = { ...self.pos };
          client.spawned = true;
        }
      }
      if (msg.op === proto.Op.Joined) client.joined = msg;
      if (msg.op === proto.Op.Snapshot) client.snapshotCount++;
      if (msg.op === proto.Op.ChatMsg) client.chatCount++;
      if (msg.op === proto.Op.RaceState) client.raceState = msg;
      if (msg.op === proto.Op.Error) client.lastError = msg;
      onMessage?.(msg, client);
    },
    status: () => {},
  });
  const wsUrl = `${url.replace(/^http/, 'ws')}/mp/ws`;
  const client = {
    manager,
    messages: [],
    joined: null,
    car: null,
    selfId: 0,
    stop: false,
    route: null,
    waypoint: 0,
    snapshotCount: 0,
    chatCount: 0,
    raceState: null,
    lastError: null,
  };
  manager.connect(
    { name, vehicle, world, track: 0, trackId, mode, roomCode: '', skin: Math.floor(Math.random() * 3) },
    wsUrl,
  );

  const started = Date.now();
  while (!client.joined && Date.now() - started < 5000) await sleep(20);
  if (!client.joined) throw new Error(`${name}: never joined a room`);
  client.selfId = manager.playerId;
  onJoined?.(client);

  client.car = new Car(0, 0, 0);
  client.car.id = client.selfId;
  // adopt the server's authoritative spawn / corrections before driving
  const waitSpawn = Date.now();
  while (!client.spawned && Date.now() - waitSpawn < 3000) {
    const selfEntry = client.messages
      .filter((m) => m.op === proto.Op.Snapshot)
      .flatMap((m) => m.entries)
      .filter((e) => e.id === client.selfId)
      .pop();
    if (selfEntry?.pos) {
      client.car.pos = { ...selfEntry.pos };
      client.spawned = true;
    } else {
      await sleep(25);
    }
  }

  manager.lastPingSentAt = 0;
  const timers = [];
  timers.push(
    setInterval(() => {
      if (client.stop) return;
      manager.ping();
    }, 1500),
  );
  timers.push(
    setInterval(() => {
      if (client.stop || !client.car) return;
      const snap = client.car.snapshot();
      manager.sendState({ ...snap, health: client.car.health });
    }, 50),
  );

  client.close = () => {
    client.stop = true;
    for (const t of timers) clearInterval(t);
    manager.close();
  };
  return client;
}

export async function driveRoute(clientProbe, route) {
  // simple: keep pushing the car towards the next route point
  const client = clientProbe;
  client.route = route;
  const timer = setInterval(() => {
    if (client.stop || !client.route) return;
    const target = client.route[client.waypoint % client.route.length];
    const dx = target[0] - client.car.pos.x;
    const dy = target[1] - client.car.pos.y;
    const d = Math.hypot(dx, dy);
    if (d < 12) client.waypoint++;
    const input = { forward: true, backward: false, left: false, right: false, brake: false, nitro: false };
    const desired = Math.atan2(dy, dx);
    let diff = desired - client.car.yaw;
    while (diff > Math.PI) diff -= Math.PI * 2;
    while (diff < -Math.PI) diff += Math.PI * 2;
    input.left = diff < -0.05;
    input.right = diff > 0.05;
    client.car.step(0.05, input);
  }, 50);
  client.stopDriving = () => clearInterval(timer);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ── CLI ────────────────────────────────────────────────────────────────
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = process.argv.slice(2);
  const flag = (name, fallback) => {
    const i = args.indexOf(`--${name}`);
    return i === -1 ? fallback : args[i + 1];
  };
  const url = flag('url', 'http://localhost:8080');
  const bots = Number(flag('bots', 1));
  const seconds = Number(flag('seconds', 12));
  const mode = Number(flag('mode', 0));
  const world = Number(flag('world', 0));
  const trackId = flag('track', '');

  const catalog = await fetch(`${url}/api/catalog`).then((r) => r.json());
  const track = trackId || catalog.tracks.find((t) => t.worldIndex === world)?.id || '';
  const trackData = track ? await fetch(`${url}/data/tracks/${track}.json`).then((r) => r.json()) : null;

  const clients = [];
  for (let i = 0; i < bots; i++) {
    const client = await spawnClient({ url, name: `Load${i + 1}`, mode, world, trackId: track });
    if (trackData) await driveRoute(client, trackData.route);
    clients.push(client);
    await sleep(120);
  }

  const started = Date.now();
  while (Date.now() - started < seconds * 1000) {
    await sleep(500);
    const health = await fetch(`${url}/health`).then((r) => r.json());
    const snaps = clients.reduce((a, c) => a + c.snapshotCount, 0);
    const chats = clients.reduce((a, c) => a + c.chatCount, 0);
    process.stdout.write(
      `\r  sessions=${health.sessions} players=${health.players} rooms=${health.rooms.length} snaps=${snaps} chats=${chats}   `,
    );
  }
  console.log('\n');
  const health = await fetch(`${url}/health`).then((r) => r.json());
  console.log('  final:', JSON.stringify({ sessions: health.sessions, players: health.players, stats: health.stats }));
  for (const client of clients) {
    const race = client.raceState;
    console.log(
      `   ${client.joined ? 'joined' : 'NOT joined'} room=${client.joined?.roomId ?? '?'} snaps=${client.snapshotCount} phase=${
        race?.phase ?? '-'
      } lap=${race?.lap ?? '-'}/${race?.totalLaps ?? '-'}${
        client.lastError ? ` error=${client.lastError.message}` : ''
      }`,
    );
  }
  for (const client of clients) {
    client.stopDriving?.();
    client.close();
  }
  await sleep(300);
  process.exit(0);
}
