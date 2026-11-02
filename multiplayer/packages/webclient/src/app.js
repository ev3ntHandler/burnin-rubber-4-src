import { ChatChannel, EventId, Mode, Op, PlayerFlag, RacePhase } from '/lib/protocol/src/index.js';
import { Net } from './net.js';
import { Car, Interpolator } from './sim.js';
import { Renderer, makePalette } from './render.js';
import { ui, escapeHtml } from './ui.js';

const STATE_HZ = 20;
const WEAPONS = [
  { name: 'MachineGun', range: 95, cooldown: 110, damage: 6 },
  { name: 'RocketPod', range: 260, cooldown: 1400, damage: 34 },
  { name: 'MiniGun', range: 85, cooldown: 55, damage: 3.5 },
];

const app = {
  screen: 'lobby',
  net: null,
  renderer: null,
  palette: makePalette(),
  self: null,
  selfId: 0,
  entities: new Map(),
  world: null,
  track: null,
  catalog: null,
  race: null,
  pickupsTaken: new Set(),
  pickupCooldown: 0,
  effects: [],
  input: { forward: false, backward: false, left: false, right: false, brake: false, nitro: false },
  chatOpen: false,
  weapon: 0,
  lastFire: 0,
  lastState: 0,
  lastPing: 0,
  names: new Map(),
  profile: null,
  pendingHit: null,
};

// ── bootstrap ──────────────────────────────────────────────────────────
const stored = JSON.parse(localStorage.getItem('br4mp') ?? '{}');
ui.el('name').value = stored.name ?? randomName();
ui.el('vehicle').value = stored.vehicle ?? 'PlayerCar';
ui.el('world').value = stored.world ?? '0';

app.renderer = new Renderer(ui.el('stage'));
loadCatalog().then(() => refreshRooms());

ui.el('world').addEventListener('change', () => {
  const world = Number(ui.el('world').value);
  const tracks = (app.catalog?.tracks ?? []).filter((t) => t.worldIndex === world);
  ui.tracks(tracks);
});

ui.el('refresh').addEventListener('click', refreshRooms);
ui.el('btn-help').addEventListener('click', () => ui.help(ui.el('help').classList.contains('hidden')));
ui.el('btn-leave').addEventListener('click', leave);
ui.el('btn-roam').addEventListener('click', () => start(Mode.FreeRoam));
ui.el('btn-race').addEventListener('click', () => start(Mode.Race));

ui.el('chat-form').addEventListener('submit', (event) => {
  event.preventDefault();
  const input = ui.el('chat-input');
  const text = input.value.trim();
  input.value = '';
  input.blur();
  app.chatOpen = false;
  input.classList.remove('active');
  if (text) send({ op: Op.Chat, channel: ChatChannel.All, text });
});

window.addEventListener('keydown', onKeyDown);
window.addEventListener('keyup', onKeyUp);
setInterval(() => {
  if (app.screen !== 'game') return;
  const now = performance.now();
  if (now - app.lastPing > 2500) {
    app.lastPing = now;
    app.net?.ping();
  }
}, 100);

async function loadCatalog() {
  try {
    const response = await fetch('/api/catalog');
    app.catalog = await response.json();
    const worldSelect = ui.el('world');
    worldSelect.innerHTML = '';
    for (const world of app.catalog.worlds) {
      const option = document.createElement('option');
      option.value = String(world.index);
      option.textContent = world.name === 'Desert' && world.roads === 0 ? `${world.name} (free roam only)` : world.name;
      worldSelect.appendChild(option);
    }
    worldSelect.value = stored.world ?? '0';
    const world = Number(worldSelect.value);
    ui.tracks(app.catalog.tracks.filter((t) => t.worldIndex === world));
  } catch (err) {
    console.error('catalog failed', err);
  }
}

async function refreshRooms() {
  try {
    const response = await fetch('/mp/rooms');
    const data = await response.json();
    ui.rooms(data.rooms ?? [], null);
  } catch {
    /* ignore */
  }
}

function randomName() {
  const names = ['Dirk', 'Bullet', 'Phaser', 'Nitro', 'Clutch', 'Drift', 'Hound', 'Storm'];
  return `${names[Math.floor(Math.random() * names.length)]}${Math.floor(Math.random() * 90 + 10)}`;
}

// ── start / stop ───────────────────────────────────────────────────────

function start(mode) {
  const name = ui.el('name').value.trim() || randomName();
  const vehicle = ui.el('vehicle').value;
  const world = Number(ui.el('world').value);
  const trackId = ui.el('track').value;
  localStorage.setItem('br4mp', JSON.stringify({ name, vehicle, world }));

  app.profile = { name, vehicle, world, trackId, mode };
  app.net = new Net({ message: onMessage, status: onStatus });
  app.entities.clear();
  app.names.clear();
  app.effects = [];
  app.race = null;
  app.pickupsTaken.clear();
  app.self = null;

  ui.screen('game');
  app.screen = 'game';
  app.net.connect({ name, vehicle, world, track: 0, trackId, mode, roomCode: '' });
  ui.toast('Connecting…');
  requestAnimationFrame(loop);
}

function leave() {
  app.net?.close();
  app.screen = 'lobby';
  ui.screen('lobby');
  refreshRooms();
}

function onStatus(status) {
  if (status === 'reconnecting') ui.toast('Connection lost — reconnecting…', 4000);
}

// ── message handling ───────────────────────────────────────────────────

async function onMessage(msg) {
  switch (msg.op) {
    case Op.Welcome:
      app.selfId = msg.playerId;
      ui.pill('ping-pill', '—');
      break;
    case Op.Joined:
      await enterRoom(msg);
      break;
    case Op.Snapshot:
      applySnapshot(msg);
      break;
    case Op.PlayerJoin:
      upsertPlayer(msg.player);
      break;
    case Op.PlayerLeave: {
      const entity = app.entities.get(msg.id);
      if (entity) ui.chat(`${entity.name} left.`, { system: true });
      app.entities.delete(msg.id);
      app.names.delete(msg.id);
      updateRoster();
      break;
    }
    case Op.ChatMsg:
      ui.chat(msg.text, {
        name: msg.name,
        channel: msg.channel,
        system: msg.channel === ChatChannel.System,
        me: msg.text.startsWith('* '),
      });
      break;
    case Op.Event:
      handleEvent(msg);
      break;
    case Op.RaceState:
      app.race = msg;
      ui.race(msg, app.selfId, app.names);
      break;
    case Op.Pong:
      app.net.onPong(app.net.pingSentAt ?? Date.now());
      break;
    case Op.Correction:
      if (app.self) {
        const hard = msg.reason !== 0 || distance(app.self.pos, msg.pos) > 20;
        app.self.pos = hard ? { ...msg.pos } : app.self.pos;
        if (hard) app.self.pos = { ...msg.pos };
        app.self.applyCorrection(msg.pos, msg.rot, msg.vel, hard);
      }
      break;
    case Op.Error:
      ui.toast(msg.message, 4000);
      if (msg.code === 9 || msg.code === 1) {
        leave();
      }
      break;
    default:
      break;
  }
}

async function enterRoom(joined) {
  const worldIndex = joined.world;
  const worldName = (app.catalog?.worlds.find((w) => w.index === worldIndex)?.name ?? 'City').toLowerCase();
  app.world = await fetchJson(`/data/worlds/${worldName}.json`);
  app.world.pickups = (app.world?.pickups ?? []).slice(0, 80).map((p, index) => ({ ...p, index }));
  app.track = joined.trackId ? await fetchJson(`/data/tracks/${joined.trackId}.json`) : null;
  app.renderer.setWorld(app.world);
  app.renderer.setTrack(app.track);

  app.race = null;
  ui.el('race-panel').classList.toggle('hidden', joined.mode !== 1);

  const spawn = app.world?.spawn?.pos ?? [0, 0, 0];
  app.self = new Car(spawn[0], spawn[1], spawn[2] + 1.2, ((app.world?.spawn?.yawDeg ?? 0) * Math.PI) / 180);
  app.self.id = app.selfId;
  app.self.name = app.profile.name;
  app.self.isSelf = true;

  const roomName = joined.mode === 1 ? `Race · ${app.track?.name ?? joined.trackId}` : `${app.world?.world ?? 'City'} · Free Roam`;
  ui.room(roomName, joined.players.length);
  app.names.set(app.selfId, app.profile.name);
  for (const player of joined.players) upsertPlayer(player);
  updateRoster();
  ui.chat(`Welcome to ${roomName}. Press Enter to chat.`, { system: true });
  refreshRooms();
}

function upsertPlayer(player) {
  app.names.set(player.id, player.name);
  let entity = app.entities.get(player.id);
  if (!entity) {
    entity = {
      id: player.id,
      name: player.name,
      vehicle: player.vehicle,
      skin: player.skin,
      pos: { x: 0, y: 0, z: 0 },
      yaw: 0,
      speed: 0,
      health: 100,
      flags: 0,
      lap: 0,
      cp: 0,
      dead: false,
      bot: false,
      interp: new Interpolator(),
      lastSeenAt: performance.now(),
    };
    app.entities.set(player.id, entity);
  } else {
    entity.name = player.name;
    entity.vehicle = player.vehicle;
    entity.skin = player.skin;
  }
  rosterDirty = true;
}

function applySnapshot(msg) {
  const updates = app.net.applySnapshot(msg);
  const now = performance.now();
  for (const update of updates) {
    if (update.id === app.selfId) {
      const self = app.self;
      if (!self) continue;
      if (update.pos) {
        const gap = distance(self.pos, update.pos);
        if (gap > 0.35) self.applyCorrection(update.pos, update.rot ?? self.rot, update.vel ?? self.vel, gap > 18);
        else self.pos = { ...update.pos };
      }
      if (update.health !== undefined) self.health = update.health;
      if (update.speed !== undefined) self.authoritativeSpeed = update.speed;
      if (update.lap !== undefined) self.lap = update.lap;
      if (update.cp !== undefined) {
        self.cp = update.cp;
        const gates = app.track?.checkpoints?.length ?? 0;
        const lap = update.lap ?? self.lap;
        self.nextGate = gates ? (lap === 0 && update.cp === 0 ? 0 : (update.cp + 1) % gates) : -1;
      }
      continue;
    }
    upsertPlayer({ id: update.id, name: app.names.get(update.id) ?? `Racer ${update.id}`, vehicle: 'PlayerCar', skin: 0 });
    const entity = app.entities.get(update.id);
    if (!entity) continue;
    entity.pos = update.pos ?? entity.pos;
    entity.yaw = update.rot ? yaw(update.rot) : entity.yaw;
    entity.speed = update.speed ?? entity.speed;
    entity.health = update.health ?? entity.health;
    entity.flags = update.flags ?? entity.flags;
    entity.lap = update.lap ?? entity.lap;
    entity.cp = update.cp ?? entity.cp;
    entity.dead = Boolean(entity.flags & PlayerFlag.Dead);
    entity.lastSeenAt = now;
    entity.interp.push(now, { ...entity.pos }, update.rot ?? quat(entity.yaw), entity.speed, entity.health, entity.flags);
  }
  rosterDirty = true;
}

let rosterDirty = false;
let lastRoster = 0;
let lastHudText = 0;

function handleEvent(msg) {
  const actor = app.names.get(msg.actorId) ?? `Racer ${msg.actorId}`;
  const target = app.names.get(msg.targetId) ?? `Racer ${msg.targetId}`;
  switch (msg.event) {
    case EventId.Hit:
      addEffect({ type: 'boom', pos: msg.pos, until: performance.now() + 260, duration: 260, radius: 6 });
      addEffect({ type: 'text', pos: msg.pos, text: `-${msg.value}`, until: performance.now() + 700, duration: 700 });
      break;
    case EventId.WeaponFired:
      addEffect({ type: 'boom', pos: msg.pos, until: performance.now() + 120, duration: 120, radius: 3 });
      break;
    case EventId.PickupTaken:
      app.pickupsTaken.add(msg.value);
      if (msg.actorId === app.selfId) ui.toast('Pickup collected');
      break;
    case EventId.PickupRespawn:
      app.pickupsTaken.delete(msg.value);
      break;
    case EventId.PlayerDeath:
      addEffect({ type: 'boom', pos: msg.pos, until: performance.now() + 700, duration: 700, radius: 16 });
      ui.kill(`${actor} 💥 ${target}`);
      break;
    case EventId.KillFeed:
      ui.kill(`${actor} wrecked ${target} (${msg.value} kills)`);
      break;
    case EventId.Horn:
      addEffect({ type: 'text', pos: msg.pos, text: '📣', until: performance.now() + 900, duration: 900 });
      break;
    case EventId.Emote:
      addEffect({ type: 'text', pos: msg.pos, text: '💬', until: performance.now() + 900, duration: 900 });
      break;
    case EventId.RaceCountdown:
      if (msg.value > 0) ui.toast('Race starting…');
      break;
    case EventId.RaceGo:
      ui.toast('GO!', 1200);
      break;
    case EventId.RaceLap:
      if (msg.actorId === app.selfId) ui.toast(`Lap ${app.self.lap + 1}`);
      break;
    case EventId.RaceFinish:
      ui.toast(msg.actorId === app.selfId ? '🏁 Finished!' : `${actor} finished`, 3500);
      break;
    case EventId.RaceInvite:
      if (msg.targetId === app.selfId) {
        ui.toast(`${actor} invites you to a race — press Y to accept`, 6000);
        app.pendingInvite = msg.actorId;
      } else if (msg.actorId === app.selfId) {
        ui.toast(`Invite sent to ${target}`);
      }
      break;
    case EventId.Checkpoint:
      if (msg.actorId === app.selfId) ui.toast(`Checkpoint ${msg.value}`, 900);
      break;
    default:
      break;
  }
}

function updateRoster() {
  const total = new Set([app.selfId, ...app.entities.keys()]).size;
  const roomName = app.track ? `Race · ${app.track.name}` : `${app.world?.world ?? 'City'} · Free Roam`;
  ui.room(roomName, total);
}

// ── input ──────────────────────────────────────────────────────────────

function onKeyDown(event) {
  if (event.target instanceof HTMLInputElement) {
    if (event.key === 'Escape') {
      event.target.blur();
      app.chatOpen = false;
      ui.el('chat-input').classList.remove('active');
    }
    return;
  }
  if (app.screen !== 'game') return;
  const key = event.key.toLowerCase();
  if (key === 'enter') {
    event.preventDefault();
    app.chatOpen = true;
    const input = ui.el('chat-input');
    input.classList.add('active');
    input.focus();
    return;
  }
  switch (key) {
    case 'w':
    case 'arrowup':
      app.input.forward = true;
      break;
    case 's':
    case 'arrowdown':
      app.input.backward = true;
      break;
    case 'a':
    case 'arrowleft':
      app.input.left = true;
      break;
    case 'd':
    case 'arrowright':
      app.input.right = true;
      break;
    case 'shift':
      app.input.brake = true;
      break;
    case 'n':
      app.input.nitro = true;
      break;
    case ' ':
      event.preventDefault();
      fire();
      break;
    case 'h':
      send({ op: Op.Action, action: 0, target: 0, arg: 0, pos: app.self?.pos ?? zero() });
      break;
    case 'e':
      send({ op: Op.Action, action: 1, target: 0, arg: Math.floor(Math.random() * 4), pos: app.self?.pos ?? zero() });
      break;
    case 'r':
      send({ op: Op.Action, action: 2, target: 0, arg: 0, pos: app.self?.pos ?? zero() });
      break;
    case 'i':
      inviteNearest();
      break;
    case 'y':
      send({ op: Op.Action, action: 6, target: 0, arg: 0, pos: app.self?.pos ?? zero() });
      break;
    case 'm':
      app.renderer.cycleZoom();
      break;
    case 'q':
      app.weapon = (app.weapon + 1) % WEAPONS.length;
      ui.toast(`Weapon: ${WEAPONS[app.weapon].name}`, 1200);
      break;
    case '?':
      ui.help(ui.el('help').classList.contains('hidden'));
      break;
    default:
      break;
  }
}

function onKeyUp(event) {
  switch (event.key.toLowerCase()) {
    case 'w':
    case 'arrowup':
      app.input.forward = false;
      break;
    case 's':
    case 'arrowdown':
      app.input.backward = false;
      break;
    case 'a':
    case 'arrowleft':
      app.input.left = false;
      break;
    case 'd':
    case 'arrowright':
      app.input.right = false;
      break;
    case 'shift':
      app.input.brake = false;
      break;
    case 'n':
      app.input.nitro = false;
      break;
    default:
      break;
  }
}

function inviteNearest() {
  let best = null;
  let bestDist = 400;
  for (const entity of app.entities.values()) {
    const d = distance(entity.pos, app.self.pos);
    if (d < bestDist) {
      bestDist = d;
      best = entity;
    }
  }
  if (!best) {
    ui.toast('No one nearby to invite');
    return;
  }
  send({ op: Op.Action, action: 5, target: best.id, arg: 0, pos: app.self.pos });
}

function fire() {
  const self = app.self;
  if (!self) return;
  const now = performance.now();
  const weapon = WEAPONS[app.weapon];
  if (now - app.lastFire < weapon.cooldown) return;
  app.lastFire = now;

  send({ op: Op.Action, action: 3, target: 0, arg: app.weapon, pos: self.pos });

  // local hit test — the server rewinds and validates before applying damage
  let target = null;
  let bestScore = Infinity;
  for (const entity of app.entities.values()) {
    if (entity.dead) continue;
    const dx = entity.pos.x - self.pos.x;
    const dy = entity.pos.y - self.pos.y;
    const dist = Math.hypot(dx, dy);
    if (dist > weapon.range || dist < 1) continue;
    const angle = Math.abs(angleDiff(Math.atan2(dy, dx), self.yaw));
    if (angle > 0.22) continue;
    const score = dist + angle * 40;
    if (score < bestScore) {
      bestScore = score;
      target = entity;
    }
  }

  const muzzle = { x: self.pos.x, y: self.pos.y, z: self.pos.z };
  const impact = target ? { x: target.pos.x, y: target.pos.y, z: target.pos.z } : {
    x: self.pos.x + Math.cos(self.yaw) * weapon.range,
    y: self.pos.y + Math.sin(self.yaw) * weapon.range,
    z: self.pos.z,
  };
  addEffect({ type: 'tracer', from: muzzle, to: impact, until: now + 140, duration: 140 });

  if (target) {
    send({
      op: Op.Hit,
      targetId: target.id,
      weapon: app.weapon,
      pos: target.pos,
      clientTimeMs: Date.now(),
      damage: weapon.damage,
    });
  }
}

// ── main loop ──────────────────────────────────────────────────────────

let lastFrame = performance.now();
function loop(now) {
  if (app.screen !== 'game') return;
  const dt = Math.min(0.05, (now - lastFrame) / 1000);
  lastFrame = now;

  if (app.self) {
    app.self.step(dt, app.input);
    // keep the local car on the world surface height of its spawn area
    if (app.world) app.self.pos.z = (app.world.spawn?.pos?.[2] ?? 0) + 1.2;

    if (now - app.lastState >= 1000 / STATE_HZ) {
      app.lastState = now;
      const snap = app.self.snapshot();
      app.net.sendState({ ...snap, health: app.self.health });
    }

    maybeCollectPickup(now);

    const kmh = Math.abs(app.self.speed) * 3.6;
    ui.speed(kmh, app.self.health, app.self.nitro);
    if (now - lastHudText > 400) {
      lastHudText = now;
      ui.pill('ping-pill', `${app.net.pingMs} ms`);
    }
  }

  app.effects = app.effects.filter((fx) => fx.until > now);
  if (rosterDirty && now - lastRoster > 900) {
    rosterDirty = false;
    lastRoster = now;
    updateRoster();
  }
  const entities = [...app.entities.values()].map((entity) => {
    const sample = entity.interp.sample(now, 120);
    return {
      id: entity.id,
      name: entity.name,
      pos: sample.pos,
      yaw: sample.yaw,
      speed: sample.speed,
      health: sample.health ?? entity.health,
      dead: entity.dead,
      isBot: entity.bot,
    };
  });
  const selfSnapshot = app.self
    ? {
        id: app.selfId,
        name: app.profile?.name ?? '',
        pos: app.self.pos,
        yaw: app.self.yaw,
        health: app.self.health,
        isSelf: true,
        nextGate: app.self.nextGate,
        dead: false,
      }
    : null;

  app.renderer.draw({
    self: selfSnapshot,
    entities,
    effects: app.effects,
    pickupsTaken: app.pickupsTaken,
    palette: app.palette,
  });

  requestAnimationFrame(loop);
}

function maybeCollectPickup(now) {
  if (!app.self || !app.world || now < app.pickupCooldown) return;
  for (const pickup of app.world.pickups ?? []) {
    if (app.pickupsTaken.has(pickup.index)) continue;
    const d = distance({ x: pickup.pos[0], y: pickup.pos[1], z: pickup.pos[2] }, app.self.pos);
    if (d < 12) {
      app.pickupCooldown = now + 1200;
      send({ op: Op.Action, action: 4, target: 0, arg: pickup.index, pos: app.self.pos });
      return;
    }
  }
}

// ── helpers ────────────────────────────────────────────────────────────

function send(msg) {
  app.net?.send(msg);
}

function addEffect(fx) {
  app.effects.push(fx);
  if (app.effects.length > 120) app.effects.shift();
}

async function fetchJson(url) {
  try {
    const response = await fetch(url);
    if (!response.ok) return null;
    return await response.json();
  } catch {
    return null;
  }
}

function distance(a, b) {
  return Math.hypot(a.x - b.x, a.y - b.y, (a.z ?? 0) - (b.z ?? 0));
}

function yaw(rot) {
  const siny = 2 * (rot.w * rot.z + rot.x * rot.y);
  const cosy = 1 - 2 * (rot.y * rot.y + rot.z * rot.z);
  return Math.atan2(siny, cosy);
}

function quat(yawRad) {
  return { x: 0, y: 0, z: Math.sin(yawRad / 2), w: Math.cos(yawRad / 2) };
}

function zero() {
  return { x: 0, y: 0, z: 0 };
}

function angleDiff(a, b) {
  let diff = a - b;
  while (diff > Math.PI) diff -= Math.PI * 2;
  while (diff < -Math.PI) diff += Math.PI * 2;
  return diff;
}

void escapeHtml;
