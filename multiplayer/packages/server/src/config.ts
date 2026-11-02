import { existsSync, readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));

export interface ServerConfig {
  httpPort: number;
  host: string;
  serverName: string;
  tickRate: number;
  snapshotRate: number;
  maxPlayersPerRoom: number;
  maxRooms: number;
  warmRoomsPerWorld: number;
  roomIdleTimeoutMs: number;
  /** Physics / fairness guard rails. */
  maxSpeedMs: number;
  maxTeleportM: number;
  /** Chat */
  chatHistory: number;
  chatMaxLength: number;
  /** Networking */
  pollTimeoutMs: number;
  pollIdleDisconnectMs: number;
  resumeWindowMs: number;
  /** Dev conveniences */
  fillWithBots: boolean;
  botsPerRace: number;
  allowAnonymous: boolean;
  ticketSecret: string;
  webRoot: string;
  protocolRoot: string;
  dataRoot: string;
}

function envInt(name: string, fallback: number): number {
  const raw = process.env[name];
  if (!raw) return fallback;
  const n = Number(raw);
  return Number.isFinite(n) ? n : fallback;
}

function envBool(name: string, fallback: boolean): boolean {
  const raw = process.env[name];
  if (raw === undefined) return fallback;
  return raw === '1' || raw.toLowerCase() === 'true' || raw.toLowerCase() === 'yes';
}

function locate(relative: string[][]): string {
  for (const rel of relative) {
    const p = resolve(HERE, ...rel);
    if (existsSync(p)) return p;
  }
  return resolve(process.cwd(), relative[relative.length - 1].join('/'));
}

export function loadConfig(): ServerConfig {
  const dataRoot = locate([['..', '..', '..', 'data'], ['..', '..', 'data'], ['..', 'data'], ['data']]);
  return {
    httpPort: envInt('MP_PORT', 8080),
    host: process.env.MP_HOST ?? '0.0.0.0',
    serverName: process.env.MP_SERVER_NAME ?? 'Burnin\' Rubber 4 — Online',
    tickRate: Math.max(10, Math.min(60, envInt('MP_TICK_RATE', 20))),
    snapshotRate: Math.max(5, Math.min(30, envInt('MP_SNAPSHOT_RATE', 20))),
    maxPlayersPerRoom: envInt('MP_MAX_PLAYERS', 32),
    maxRooms: envInt('MP_MAX_ROOMS', 64),
    warmRoomsPerWorld: envInt('MP_WARM_ROOMS', 1),
    roomIdleTimeoutMs: envInt('MP_ROOM_IDLE_MS', 5 * 60 * 1000),
    maxSpeedMs: envInt('MP_MAX_SPEED', 95),
    maxTeleportM: envInt('MP_MAX_TELEPORT', 55),
    chatHistory: envInt('MP_CHAT_HISTORY', 50),
    chatMaxLength: envInt('MP_CHAT_MAX', 200),
    pollTimeoutMs: envInt('MP_POLL_TIMEOUT_MS', 15_000),
    pollIdleDisconnectMs: envInt('MP_POLL_IDLE_MS', 25_000),
    resumeWindowMs: envInt('MP_RESUME_WINDOW_MS', 60_000),
    fillWithBots: envBool('MP_BOTS', true),
    botsPerRace: envInt('MP_BOTS_PER_RACE', 3),
    allowAnonymous: envBool('MP_ALLOW_ANONYMOUS', true),
    ticketSecret: process.env.MP_TICKET_SECRET ?? 'dev-secret-change-me',
    webRoot: locate([['..', '..', '..', 'webclient'], ['..', '..', 'webclient'], ['webclient']]),
    protocolRoot: locate([['..', '..', '..', 'protocol', 'dist'], ['..', '..', 'protocol', 'dist']]),
    dataRoot,
  };
}

export function readPackageVersion(): string {
  for (const rel of [['..', '..', '..', 'package.json'], ['..', '..', 'package.json']]) {
    try {
      const p = resolve(HERE, ...rel);
      if (existsSync(p)) return (JSON.parse(readFileSync(p, 'utf8')) as { version?: string }).version ?? '1.0.0';
    } catch {
      /* ignore */
    }
  }
  return '1.0.0';
}
