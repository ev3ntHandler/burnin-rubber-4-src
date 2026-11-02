import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));

/** Resolve the repo data folder from dist/src, dist, or src. */
function findDataDir(): string {
  const candidates = [
    join(HERE, '..', '..', '..', 'data'), // dist/src/data.js -> multiplayer/data
    join(HERE, '..', '..', 'data'),
    join(HERE, '..', 'data'),
    join(process.cwd(), 'data'),
  ];
  for (const c of candidates) if (existsSync(c)) return c;
  throw new Error(`could not locate data directory (tried ${candidates.join(', ')})`);
}

export const DATA_DIR = findDataDir();
export const TRACKS_DIR = join(DATA_DIR, 'tracks');
export const WORLDS_DIR = join(DATA_DIR, 'worlds');

export interface WorldMarker {
  name: string;
  kind: string;
  tile: string;
  pos: [number, number, number];
  yawDeg: number;
  count: number;
}

export interface WorldPickup {
  kind: string;
  tile: string;
  pos: [number, number, number];
}

export interface WorldRoad {
  name: string;
  length: number;
  points: Array<[number, number, number]>;
}

export interface WorldData {
  world: string;
  worldIndex: number;
  source: string;
  spawn: { name: string; pos: [number, number, number]; yawDeg: number };
  markers: WorldMarker[];
  pickups: WorldPickup[];
  roads: WorldRoad[];
}

export interface TrackCheckpoint {
  index: number;
  pos: [number, number, number];
  yawDeg: number;
  width: number;
}

export interface TrackGridSlot {
  slot: number;
  pos: [number, number, number];
  yawDeg: number;
}

export interface TrackData {
  id: string;
  name: string;
  world: string;
  worldIndex: number;
  source: string;
  length: number;
  totalLaps: number;
  type?: 'circuit' | 'sprint';
  finishCheckpoint?: number;
  route: Array<[number, number, number]>;
  checkpoints: TrackCheckpoint[];
  grid: TrackGridSlot[];
}

const worlds = new Map<number, WorldData>();
const tracks = new Map<string, TrackData>();
const tracksByWorld = new Map<number, TrackData[]>();

for (const file of readdirSync(WORLDS_DIR)) {
  if (!file.endsWith('.json')) continue;
  const data = JSON.parse(readFileSync(join(WORLDS_DIR, file), 'utf8')) as WorldData;
  worlds.set(data.worldIndex, data);
}

for (const file of readdirSync(TRACKS_DIR)) {
  if (!file.endsWith('.json')) continue;
  const data = JSON.parse(readFileSync(join(TRACKS_DIR, file), 'utf8')) as TrackData;
  if (!data.type) data.type = data.length > 4600 ? 'sprint' : 'circuit';
  if (data.type === 'sprint' && data.finishCheckpoint === undefined) {
    data.finishCheckpoint = Math.floor(data.checkpoints.length / 2);
    data.totalLaps = 1;
  }
  if (data.type === 'sprint') data.totalLaps = 1;
  tracks.set(data.id, data);
  const list = tracksByWorld.get(data.worldIndex) ?? [];
  list.push(data);
  tracksByWorld.set(data.worldIndex, list);
}

export function getWorld(index: number): WorldData | undefined {
  return worlds.get(index);
}

export function allWorlds(): WorldData[] {
  return [...worlds.values()].sort((a, b) => a.worldIndex - b.worldIndex);
}

export function getTrack(id: string): TrackData | undefined {
  return tracks.get(id);
}

export function allTracks(): TrackData[] {
  return [...tracks.values()];
}

export function tracksForWorld(worldIndex: number): TrackData[] {
  return tracksByWorld.get(worldIndex) ?? [];
}

/** Fallback used when a world has no imported road loops (e.g. Desert assets absent). */
export function syntheticTrack(worldIndex: number): TrackData | undefined {
  const world = worlds.get(worldIndex);
  if (!world) return undefined;
  const cx = world.spawn.pos[0];
  const cy = world.spawn.pos[1];
  const radius = 420;
  const points: Array<[number, number, number]> = [];
  const checkpoints: TrackCheckpoint[] = [];
  for (let i = 0; i < 48; i++) {
    const a = (i / 48) * Math.PI * 2;
    points.push([
      Math.round(cx + Math.cos(a) * radius),
      Math.round(cy + Math.sin(a) * radius),
      world.spawn.pos[2],
    ]);
  }
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * Math.PI * 2;
    checkpoints.push({
      index: i,
      pos: [
        Math.round(cx + Math.cos(a) * radius),
        Math.round(cy + Math.sin(a) * radius),
        world.spawn.pos[2],
      ],
      yawDeg: Math.round((a * 180) / Math.PI + 90),
      width: 40,
    });
  }
  const grid: TrackGridSlot[] = [];
  for (let i = 0; i < 8; i++) {
    grid.push({
      slot: i,
      pos: [Math.round(cx - 20 - i * 9), Math.round(cy + (i % 2 === 0 ? -4.5 : 4.5)), world.spawn.pos[2]],
      yawDeg: 0,
    });
  }
  return {
    id: `${world.world.toLowerCase()}-fallback`,
    name: `${world.world} Ring`,
    world: world.world,
    worldIndex,
    source: 'synthetic',
    length: Math.round(2 * Math.PI * radius),
    totalLaps: 2,
    type: 'circuit',
    route: points,
    checkpoints,
    grid,
  };
}

export function resolveTrack(id: string, worldIndex: number): TrackData | undefined {
  return tracks.get(id) ?? tracksForWorld(worldIndex)[0] ?? syntheticTrack(worldIndex);
}
