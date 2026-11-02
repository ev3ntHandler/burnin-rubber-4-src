import type { PlayerDescriptor, Quat, ServerMessage, Vec3 } from '@br4mp/protocol';

export type TransportKind = 'ws' | 'poll' | 'tcp';

/** Everything a room needs from a connection. Transports implement this. */
export interface Connection {
  readonly kind: TransportKind;
  readonly remote: string;
  send(msg: ServerMessage): void;
  close(reason?: string): void;
  /** True when the underlying socket/poll session is still usable. */
  isOpen(): boolean;
}

export interface RateLimiter {
  /** Returns false when the action must be throttled. */
  allow(cost?: number): boolean;
}

export function tokenBucket(perSecond: number, burst = perSecond * 2): RateLimiter {
  let tokens = burst;
  let last = Date.now();
  return {
    allow(cost = 1) {
      const now = Date.now();
      const elapsed = (now - last) / 1000;
      last = now;
      tokens = Math.min(burst, tokens + elapsed * perSecond);
      if (tokens < cost) return false;
      tokens -= cost;
      return true;
    },
  };
}

/** Authoritative record for one player inside a room. */
export interface Player {
  id: number;
  name: string;
  vehicle: string;
  skin: number;
  conn: Connection | null;
  isBot: boolean;
  joinedAt: number;
  lastSeen: number;
  lastAckTick: number;
  lastStateSeq: number;
  lastStateAt: number;
  /** Last state we accepted from the client (or the bot AI). */
  pos: Vec3;
  rot: Quat;
  vel: Vec3;
  speed: number;
  flags: number;
  health: number;
  maxHealth: number;
  /** Race progress */
  lap: number;
  cp: number;
  finished: boolean;
  finishTimeMs: number;
  bestLapMs: number;
  lapStartedAt: number;
  /** Combat / free roam */
  deadUntil: number;
  lastFireAt: Map<number, number>;
  kills: number;
  deaths: number;
  /** Anti cheat */
  strikes: number;
  lastCorrectedAt: number;
  /** Metres the player is still allowed to move (replenished at max speed). */
  distanceBudget: number;
  budgetAt: number;
  /** Chat pacing */
  chatTimestamps: number[];
  /** Clock sync, so hit reports can be rewound on the server */
  clockOffsetMs: number;
  rttMs: number;
  ready: boolean;
  team: number;
  /** Per-viewer delta compression baseline is kept by the room, see Room.lastSent */
}

export interface SentState {
  tick: number;
  pos: Vec3;
  rot: Quat;
  vel: Vec3;
  health: number;
  flags: number;
  lap: number;
  cp: number;
  speed: number;
}

export interface PlayerSnapshotRecord {
  tick: number;
  timeMs: number;
  pos: Vec3;
  rot: Quat;
  vel: Vec3;
}

export function descriptor(p: Player): PlayerDescriptor {
  return { id: p.id, name: p.name, vehicle: p.vehicle, skin: p.skin, ready: p.ready };
}

export function newPlayer(partial: Partial<Player> & { id: number; name: string }): Player {
  return {
    vehicle: 'PlayerCar',
    skin: 0,
    conn: null,
    isBot: false,
    joinedAt: Date.now(),
    lastSeen: Date.now(),
    lastAckTick: 0,
    lastStateSeq: 0,
    lastStateAt: 0,
    pos: { x: 0, y: 0, z: 0 },
    rot: { x: 0, y: 0, z: 0, w: 1 },
    vel: { x: 0, y: 0, z: 0 },
    speed: 0,
    flags: 0,
    health: 100,
    maxHealth: 100,
    lap: 0,
    cp: 0,
    finished: false,
    finishTimeMs: 0,
    bestLapMs: 0,
    lapStartedAt: 0,
    deadUntil: 0,
    lastFireAt: new Map(),
    kills: 0,
    deaths: 0,
    strikes: 0,
    lastCorrectedAt: 0,
    distanceBudget: 60,
    budgetAt: Date.now(),
    chatTimestamps: [],
    clockOffsetMs: 0,
    rttMs: 0,
    ready: false,
    team: 0,
    ...partial,
  };
}

export function distance(a: Vec3, b: Vec3): number {
  return Math.hypot(a.x - b.x, a.y - b.y, a.z - b.z);
}

export function planarDistance(a: Vec3, b: Vec3): number {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

export function clampTo(v: Vec3, max: number): Vec3 {
  const len = Math.hypot(v.x, v.y, v.z);
  if (len <= max || len === 0) return v;
  const k = max / len;
  return { x: v.x * k, y: v.y * k, z: v.z * k };
}

export const sanitizeName = (raw: string): string => {
  const cleaned = raw
    .replace(/[\u0000-\u001f\u007f]/g, '')
    .replace(/[<>]/g, '')
    .trim()
    .slice(0, 20);
  return cleaned || 'Racer';
};
