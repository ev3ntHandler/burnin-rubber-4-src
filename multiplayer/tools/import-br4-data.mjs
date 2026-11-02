#!/usr/bin/env node
/**
 * import-br4-data.mjs
 *
 * Extracts real world data out of the Burnin' Rubber 4 decompiled assets so the
 * multiplayer server does not have to invent geometry:
 *
 *   Worlds/World <Name> (.cct)/<...>TrafficWaypoints.w3d
 *        Shockwave 3D node graphs containing the traffic loops. Every node is
 *        `u16 nameLen, name, u16 parentLen, parent, pad, 12 floats rotation,
 *        4 floats translation (x,y,z,1)`. Those loops *are* the city's road
 *        network, so we derive race circuits and checkpoints from them.
 *
 *   Director Movie File (.dcr)/World<Name>Data.txt
 *        Tab separated sections (CityMarkers_Begin, CityPickUps_Begin,
 *        CityObjects_Begin, ...). Each line is a tile id plus a propList of
 *        `#Name_Marker: [[vector (x,y,z), [qx,qy,qz,qw]], ...]`.
 *
 * Output: multiplayer/data/worlds/<world>.json and
 *         multiplayer/data/tracks/<world>-<n>.json
 *
 * Coordinates are kept in the game's own space: Z is up, Y is "north",
 * 1 unit = 1 metre.
 */
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, '..', '..');
const DCR = join(REPO, 'Director Movie File (.dcr)');
const WORLDS_DIR = join(REPO, 'Worlds');
const OUT_WORLDS = join(HERE, '..', 'data', 'worlds');
const OUT_TRACKS = join(HERE, '..', 'data', 'tracks');

const WORLDS = [
  { index: 0, name: 'City', folder: 'World City (.cct)', data: 'WorldCityData.txt', events: 'WorldCityEvents.txt' },
  { index: 1, name: 'Desert', folder: 'World Desert (.cct)', data: 'WorldDesertData.txt', events: 'WorldDesertEvents.txt' },
  { index: 2, name: 'Jungle', folder: 'World Jungle (.cct)', data: 'WorldJungleData.txt', events: 'WorldJungleEvents.txt' },
  { index: 3, name: 'Industrial', folder: 'World Industrial (.cct)', data: 'WorldIndustrialData.txt', events: 'WorldIndustrialEvents.txt' },
  { index: 4, name: 'Snow', folder: 'World Snow (.cct)', data: 'WorldSnowData.txt', events: 'WorldSnowEvents.txt' },
];

// ---------------------------------------------------------------------------
// quaternion helpers (game convention: axis = (qx, qz, qy), angle from w)
// ---------------------------------------------------------------------------

/** Reconstruct the forward vector exactly like Tile Handlers.ls does. */
function forwardFromGameQuat(q) {
  const [qx, qy, qz, qw] = q;
  const s = Math.sqrt(Math.max(0, 1 - qw * qw));
  const angle = 2 * Math.atan2(s, qw);
  const axis = s < 1e-6 ? [0, 0, 1] : [qx / s, qz / s, qy / s];
  // Rodrigues rotation of (0,1,0) around `axis`
  const [ax, ay, az] = axis;
  const c = Math.cos(angle);
  const sn = Math.sin(angle);
  const v = [0, 1, 0];
  const dot = ax * v[0] + ay * v[1] + az * v[2];
  const cross = [ay * v[2] - az * v[1], az * v[0] - ax * v[2], ax * v[1] - ay * v[0]];
  const out = [
    v[0] * c + cross[0] * sn + ax * dot * (1 - c),
    v[1] * c + cross[1] * sn + ay * dot * (1 - c),
    v[2] * c + cross[2] * sn + az * dot * (1 - c),
  ];
  const len = Math.hypot(out[0], out[1]) || 1;
  return { forward: out, yawDeg: (Math.atan2(out[1] / len, out[0] / len) * 180) / Math.PI };
}

// ---------------------------------------------------------------------------
// text data parsing
// ---------------------------------------------------------------------------

const NUM = '[-+0-9.eE]+';
const MARKER_RE = new RegExp(
  `#(\\w+?)_(Marker|PickUp|Object)\\s*:\\s*\\[([\\s\\S]*?)\\](?=,\\s*#|\\s*\\]\\s*\\])`,
  'g',
);

/** Parse a `[vector (x,y,z), [q0,q1,q2,q3]]` (possibly repeated) value list. */
function parsePlacements(body) {
  const re = new RegExp(
    `vector\\s*\\(\\s*(${NUM})\\s*,\\s*(${NUM})\\s*,\\s*(${NUM})\\s*\\)\\s*,\\s*\\[\\s*(${NUM})\\s*,\\s*(${NUM})\\s*,\\s*(${NUM})\\s*,\\s*(${NUM})\\s*\\]`,
    'g',
  );
  const out = [];
  let m;
  while ((m = re.exec(body))) {
    out.push({
      pos: [Number(m[1]), Number(m[2]), Number(m[3])],
      quat: [Number(m[4]), Number(m[5]), Number(m[6]), Number(m[7])],
    });
  }
  return out;
}

function sectionLines(text, prefix) {
  const lines = text.split('\n');
  const begin = lines.findIndex((l) => l.startsWith(`${prefix}_Begin`));
  if (begin === -1) return [];
  const end = lines.findIndex((l, i) => i > begin && l.startsWith(`${prefix}_End`));
  return lines.slice(begin + 1, end === -1 ? undefined : end);
}

function parseSection(text, prefix, kind) {
  const items = [];
  for (const line of sectionLines(text, prefix)) {
    const cols = line.split('\t');
    if (cols.length < 2) continue;
    const tile = cols[1].trim();
    if (!/^\d\d_\d\d$/.test(tile)) continue;
    const body = line;
    const re = new RegExp(`#(\\w+?)_${kind}\\s*:\\s*(\\[[\\s\\S]*?\\])\\s*(?=,\\s*#|\\]\\s*\\]|$)`, 'g');
    let m;
    while ((m = re.exec(body))) {
      const name = m[1];
      const placements = parsePlacements(m[2]);
      if (!placements.length) continue;
      items.push({
        name,
        kind: name.replace(/(Marker|PickUp|Object)$/, ''),
        tile,
        placements: placements.map((p) => ({ ...p, ...forwardFromGameQuat(p.quat) })),
      });
    }
  }
  return items;
}

// ---------------------------------------------------------------------------
// Shockwave 3D waypoint parsing
// ---------------------------------------------------------------------------

function parseWaypoints(file) {
  const data = readFileSync(file);
  const text = data.toString('latin1');
  const nodes = [];
  const re = /([A-Za-z][A-Za-z0-9_]*?)(\d+)(?=_|$)/g;

  // Locate every `<u16 len>NAME` occurrence that is followed by a u16-length
  // parent name and a 64 byte transform block.
  const candidates = [];
  for (let i = 0; i < text.length; i++) {
    // names are printable ASCII; cheap scan
    const c = data[i];
    if (!((c >= 65 && c <= 90) || (c >= 97 && c <= 122))) continue;
    // walk back to find the u16 length prefix
    for (let len = 4; len <= 64; len++) {
      const start = i;
      const end = start + len;
      if (end + 4 > data.length || start - 2 < 0) break;
      if (data.readUInt16LE(start - 2) !== len) continue;
      let printable = true;
      for (let k = start; k < end; k++) {
        const b = data[k];
        if (b < 0x20 || b > 0x7e) {
          printable = false;
          break;
        }
      }
      if (!printable) break;
      const name = data.toString('latin1', start, end);
      if (!/^[A-Za-z][A-Za-z0-9_]+$/.test(name)) break;
      candidates.push({ name, end });
      break;
    }
  }

  for (const { name, end } of candidates) {
    if (!/_Waypoint\d+$|_Waypoint$/.test(name) && !/_Waypoint\d+/.test(name)) continue;
    // parent string
    const parentLen = data.readUInt16LE(end);
    if (parentLen < 1 || parentLen > 64) continue;
    let p = end + 2 + parentLen;
    let ok = null;
    for (let pad = 0; pad < 5 && !ok; pad++) {
      const q = p + pad;
      if (q + 64 > data.length) break;
      const f = new Float32Array(16);
      for (let k = 0; k < 16; k++) f[k] = data.readFloatLE(q + k * 4);
      const rowLen = (o) => Math.hypot(f[o], f[o + 1], f[o + 2]);
      const near1 = (v) => Math.abs(v - 1) < 0.02;
      const valid =
        near1(rowLen(0)) &&
        near1(rowLen(4)) &&
        near1(rowLen(8)) &&
        Math.abs(f[3]) < 0.01 &&
        Math.abs(f[7]) < 0.01 &&
        Math.abs(f[11]) < 0.01 &&
        near1(f[15]) &&
        Math.abs(f[12]) < 5000 &&
        Math.abs(f[13]) < 5000 &&
        f[14] > -200 &&
        f[14] < 900;
      if (valid) ok = { pos: [f[12], f[13], f[14]] };
    }
    if (!ok) continue;
    const m = name.match(/^(.*)_Waypoint(\d+)$/);
    if (!m) continue;
    nodes.push({ path: m[1], index: Number(m[2]), pos: ok.pos, name });
  }

  // group + order
  const paths = new Map();
  for (const n of nodes) {
    if (!paths.has(n.path)) paths.set(n.path, []);
    paths.get(n.path).push(n);
  }
  const out = [];
  for (const [path, list] of paths) {
    list.sort((a, b) => a.index - b.index);
    const points = list.map((n) => n.pos);
    if (points.length < 4) continue;
    out.push({ name: path, points, closed: true });
  }
  return out;
}

// ---------------------------------------------------------------------------
// route building from a waypoint loop
// ---------------------------------------------------------------------------

const dist2 = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1]);

function resampleLoop(points, step) {
  // Spline-ish resample: use Catmull-Rom through the closed loop of waypoints.
  const pts = points.slice();
  const out = [];
  const n = pts.length;
  const catmull = (p0, p1, p2, p3, t) => {
    const t2 = t * t;
    const t3 = t2 * t;
    return [0, 1, 2].map(
      (k) =>
        0.5 *
        (2 * p1[k] +
          (-p0[k] + p2[k]) * t +
          (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2 +
          (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3),
    );
  };
  for (let i = 0; i < n; i++) {
    const p0 = pts[(i - 1 + n) % n];
    const p1 = pts[i];
    const p2 = pts[(i + 1) % n];
    const p3 = pts[(i + 2) % n];
    const segLen = dist2(p1, p2);
    const steps = Math.max(2, Math.ceil(segLen / 6));
    for (let s = 0; s < steps; s++) out.push(catmull(p0, p1, p2, p3, s / steps));
  }
  // resample by arc length
  const result = [];
  let acc = 0;
  let carry = 0;
  for (let i = 0; i < out.length; i++) {
    const a = out[i];
    const b = out[(i + 1) % out.length];
    const seg = dist2(a, b);
    if (seg < 1e-6) continue;
    while (acc + (seg - carry) >= step) {
      const need = step - acc + carry;
      const t = need / seg;
      result.push([a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t]);
      acc = 0;
      carry = 0;
      a[0] = a[0] + (b[0] - a[0]) * t;
      a[1] = a[1] + (b[1] - a[1]) * t;
      a[2] = a[2] + (b[2] - a[2]) * t;
    }
    acc += seg - carry;
    carry = 0;
  }
  return result;
}

function polylineLength(points, closed = true) {
  let total = 0;
  for (let i = 0; i < points.length; i++) {
    const a = points[i];
    const b = points[(i + 1) % points.length];
    if (!closed && i === points.length - 1) break;
    total += dist2(a, b);
  }
  return total;
}

function buildCheckpoints(points, spacing, width = 30) {
  const checkpoints = [];
  let travelled = 0;
  let nextGate = 0;
  for (let i = 0; i < points.length; i++) {
    const a = points[i];
    const b = points[(i + 1) % points.length];
    travelled += dist2(a, b);
    if (travelled >= nextGate * spacing) {
      const dir = Math.atan2(b[1] - a[1], b[0] - a[0]);
      checkpoints.push({
        index: checkpoints.length,
        pos: [round(a[0]), round(a[1]), round(a[2])],
        yawDeg: round((dir * 180) / Math.PI),
        width,
      });
      nextGate++;
    }
  }
  return checkpoints;
}

function buildGrid(origin, yawDeg, slots = 12) {
  const grid = [];
  const yaw = (yawDeg * Math.PI) / 180;
  const fwd = [Math.cos(yaw), Math.sin(yaw)];
  const right = [-Math.sin(yaw), Math.cos(yaw)];
  for (let row = 0; row < Math.ceil(slots / 2); row++) {
    for (let col = 0; col < 2; col++) {
      if (grid.length >= slots) break;
      const back = 14 + row * 9;
      const side = col === 0 ? -4.5 : 4.5;
      grid.push({
        slot: grid.length,
        pos: [
          round(origin[0] - fwd[0] * back + right[0] * side),
          round(origin[1] - fwd[1] * back + right[1] * side),
          round(origin[2]),
        ],
        yawDeg,
      });
    }
  }
  return grid;
}

function buildTrack(world, path, routeIndex) {
  const points = resampleLoop(path.points, 8);
  const length = polylineLength(points);
  if (length < 400) return null;
  const base = {
    world: world.name,
    worldIndex: world.index,
    source: path.name,
  };
  const slug = world.name.toLowerCase();

  // Circuits for loops that make a sane lap; sprints (a contiguous slice of the
  // same road loop, point to point) for the very long arterials.
  if (length <= 3600) {
    const gateCount = Math.max(4, Math.min(16, Math.round(length / 150)));
    const checkpoints = buildCheckpoints(points, length / gateCount);
    return [
      {
        ...base,
        id: `${slug}-${routeIndex + 1}`,
        name: `${world.name} ${path.name.replace(/^World/, '').replace(/(\d+)$/, ' $1').trim()} Circuit`,
        type: 'circuit',
        length: Math.round(length),
        totalLaps: 3,
        route: points.filter((_, i) => i % 2 === 0).map((p) => p.map(round)),
        checkpoints,
        grid: buildGrid(points[0], checkpoints[0].yawDeg),
      },
    ];
  }

  // sprint: walk the loop until ~2200 m, then cut
  const target = 2200;
  const slice = [];
  let acc = 0;
  for (const point of points) {
    slice.push(point);
    if (slice.length > 1) acc += dist2(slice[slice.length - 2], point);
    if (acc > target) break;
  }
  if (slice.length < 8) return null;
  const checkpoints = buildCheckpoints(slice, target / 12);
  if (!checkpoints.length) return null;
  return [
    {
      ...base,
      id: `${slug}-${routeIndex + 1}-sprint`,
      name: `${world.name} ${path.name.replace(/^World/, '').replace(/(\d+)$/, ' $1').trim()} Sprint`,
      type: 'sprint',
      length: Math.round(acc),
      totalLaps: 1,
      finishCheckpoint: checkpoints.length - 1,
      route: slice.filter((_, i) => i % 2 === 0).map((p) => p.map(round)),
      checkpoints,
      grid: buildGrid(slice[0], checkpoints[0].yawDeg),
    },
  ];
}

const round = (n) => Math.round(n * 100) / 100;

// ---------------------------------------------------------------------------

function main() {
  mkdirSync(OUT_WORLDS, { recursive: true });
  mkdirSync(OUT_TRACKS, { recursive: true });
  const summary = [];

  for (const world of WORLDS) {
    const dataPath = join(DCR, world.data);
    if (!existsSync(dataPath)) {
      console.warn(`! missing ${world.data}, skipping ${world.name}`);
      continue;
    }
    const text = readFileSync(dataPath, 'latin1');
    // discover section prefixes from the file itself
    const prefixes = [...text.matchAll(/^(\w+?)_Begin/mg)]
      .map((m) => m[1])
      .filter((p) => /(Markers|PickUps|Objects|Waypoints|Cameras|AIPaths)$/.test(p));

    const markers = [];
    const pickups = [];
    for (const prefix of prefixes) {
      if (prefix.endsWith('Markers')) markers.push(...parseSection(text, prefix, 'Marker'));
      if (prefix.endsWith('PickUps')) pickups.push(...parseSection(text, prefix, 'PickUp'));
    }

    const w3d = join(WORLDS_DIR, world.folder, `World${world.name}TrafficWaypoints.w3d`);
    let paths = [];
    if (existsSync(w3d)) {
      paths = parseWaypoints(w3d);
    } else {
      console.warn(`! missing waypoints for ${world.name}`);
    }

    // free roam spawn: SafeHouse marker when present, else the first marker
    const spawnMarker =
      markers.find((m) => /SafeHouse/.test(m.name)) ??
      markers.find((m) => /BossEndChallenge/.test(m.name)) ??
      markers[0];

    const outWorld = {
      world: world.name,
      worldIndex: world.index,
      source: world.data,
      generatedFrom: 'Burnin\' Rubber 4 decompiled assets',
      spawn: spawnMarker
        ? {
            name: `${spawnMarker.name}_Marker`,
            pos: spawnMarker.placements[0].pos.map(round),
            yawDeg: round(spawnMarker.placements[0].yawDeg),
          }
        : { name: 'default', pos: [0, 0, 0], yawDeg: 0 },
      markers: markers.map((m) => ({
        name: `${m.name}_Marker`,
        kind: m.kind,
        tile: m.tile,
        pos: m.placements[0].pos.map(round),
        yawDeg: round(m.placements[0].yawDeg),
        count: m.placements.length,
      })),
      pickups: pickups
        .filter((p) => /Repair|Nitro|Ammo|CashStash|Health/i.test(p.kind))
        .slice(0, 120)
        .map((p) => ({
          kind: p.kind.replace(/^.*?(Repair|Nitro|Ammo|CashStash|Health).*$/i, '$1').toLowerCase(),
          tile: p.tile,
          pos: p.placements[0].pos.map(round),
        })),
      roads: paths.map((p) => ({
        name: p.name,
        length: Math.round(polylineLength(p.points)),
        points: p.points.map((pt) => pt.map(round)),
      })),
    };

    writeFileSync(join(OUT_WORLDS, `${world.name.toLowerCase()}.json`), JSON.stringify(outWorld, null, 1));

    // race circuits from the longest road loops
    // Prefer loops that make a good race lap (roughly 0.8–3.2 km); fall back to
    // the longest ones for worlds whose road network is only long arterials.
    const all = paths.map((p) => ({ p, len: polylineLength(p.points) })).filter((e) => e.len > 500);
    const nice = all.filter((e) => e.len >= 800 && e.len <= 3200).sort((a, b) => a.len - b.len);
    const usable = (nice.length ? nice : all.sort((a, b) => b.len - a.len)).slice(0, 3);
    const tracks = [];
    for (const [i, entry] of usable.entries()) {
      const built = buildTrack(world, entry.p, i);
      if (!built) continue;
      for (const t of built) {
        tracks.push(t);
        writeFileSync(join(OUT_TRACKS, `${t.id}.json`), JSON.stringify(t, null, 1));
      }
    }

    summary.push({
      world: world.name,
      markers: outWorld.markers.length,
      pickups: outWorld.pickups.length,
      roads: outWorld.roads.length,
      tracks: tracks.map((t) => `${t.id} [${t.type}] (${t.length}m, ${t.checkpoints.length} cp)`),
    });
  }

  for (const s of summary) {
    console.log(`✓ ${s.world}: ${s.markers} markers, ${s.pickups} pickups, ${s.roads} roads`);
    for (const t of s.tracks) console.log(`    └ ${t}`);
  }
}

main();
