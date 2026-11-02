import type { IncomingMessage, ServerResponse } from 'node:http';
import { decodeClientText, encodeServerText, ErrorCode, Mode, Op } from '@br4mp/protocol';
import type { ClientMessage, ConnectMsg, JoinMsg, ServerMessage } from '@br4mp/protocol';
import type { GameServer, Session } from './gameServer.js';
import type { ServerConfig } from './config.js';
import type { Connection } from './types.js';

/**
 * HTTP long-poll transport — the Shockwave path.
 *
 * Lingo in Shockwave can only do HTTP (`preloadNetThing` + `getNetText`), so the
 * whole session runs over two endpoints that piggyback uplink and downlink in a
 * single request/response, one cycle per tick group:
 *
 *   GET /mp/connect?name=Fox&veh=PlayerCar&sk=0&m=1&w=0&tr=city-1&tok=
 *   GET /mp/turn?token=...&d=<urlencoded text profile lines>&wait=8
 *
 * The turn response carries the text profile downlink (snapshots, chat, ...).
 * `POST` variants accept the same parameters in the body so non-Lingo clients
 * can send larger batches.
 */
class PollConnection implements Connection {
  readonly kind = 'poll';
  readonly remote: string;
  private outbox: string[] = [];
  private waiters: Array<() => void> = [];
  private closed = false;
  lastPoll = Date.now();

  constructor(remote: string) {
    this.remote = remote;
  }

  send(msg: ServerMessage): void {
    this.outbox.push(...encodeServerText(msg));
    if (this.outbox.length > 4000) this.outbox.splice(0, this.outbox.length - 4000);
    this.notify();
  }

  close(): void {
    this.closed = true;
    this.notify();
  }

  isOpen(): boolean {
    return !this.closed;
  }

  async drain(timeoutMs: number): Promise<string> {
    this.lastPoll = Date.now();
    if (!this.outbox.length && !this.closed && timeoutMs > 0) {
      await new Promise<void>((resolve) => {
        const timer = setTimeout(() => {
          this.waiters = this.waiters.filter((w) => w !== wake);
          resolve();
        }, timeoutMs);
        const wake = () => {
          clearTimeout(timer);
          resolve();
        };
        this.waiters.push(wake);
      });
    }
    this.lastPoll = Date.now();
    const text = this.outbox.join('\n');
    this.outbox = [];
    return text;
  }

  private notify(): void {
    const waiters = this.waiters;
    this.waiters = [];
    for (const wake of waiters) wake();
  }
}

interface PollSession {
  conn: PollConnection;
  session: Session | null;
  lastSeen: number;
}

export class HttpApi {
  private readonly game: GameServer;
  private readonly config: ServerConfig;
  private readonly pollSessions = new Map<string, PollSession>();

  constructor(game: GameServer, config: ServerConfig) {
    this.game = game;
    this.config = config;
    setInterval(() => this.reap(), 5000).unref?.();
  }

  private reap(): void {
    const now = Date.now();
    for (const [token, entry] of this.pollSessions) {
      if (now - entry.lastSeen > this.config.pollIdleDisconnectMs) {
        if (entry.session) this.game.disconnect(entry.session);
        entry.conn.close();
        this.pollSessions.delete(token);
      }
    }
  }

  /** Returns true when the request was handled. */
  async handle(req: IncomingMessage, res: ServerResponse, url: URL): Promise<boolean> {
    const path = url.pathname;
    if (!path.startsWith('/mp/')) return false;

    if (req.method === 'OPTIONS') {
      res.writeHead(204, corsHeaders());
      res.end();
      return true;
    }

    try {
      if (path === '/mp/connect') {
        await this.handleConnect(req, res, url);
        return true;
      }
      if (path === '/mp/turn') {
        await this.handleTurn(req, res, url);
        return true;
      }
      if (path === '/mp/poll') {
        await this.handlePoll(req, res, url);
        return true;
      }
      if (path === '/mp/send') {
        await this.handleSend(req, res, url);
        return true;
      }
      if (path === '/mp/rooms') {
        const mode = url.searchParams.has('mode') ? Number(url.searchParams.get('mode')) : -1;
        json(res, 200, {
          rooms: [...this.game.rooms.values()]
            .filter((room) => mode === -1 || room.mode === mode)
            .map((room) => ({
              id: room.id,
              mode: room.mode === Mode.Race ? 'race' : 'freeroam',
              world: room.world.world,
              worldIndex: room.worldIndex,
              track: room.track?.id ?? null,
              players: room.players.size,
              phase: room.summaryPhase(),
              joinable: room.joinable(),
            })),
        });
        return true;
      }
      if (path === '/mp/info') {
        json(res, 200, this.game.describe());
        return true;
      }
      return false;
    } catch (err) {
      json(res, 500, { error: (err as Error).message });
      return true;
    }
  }

  // -- endpoints -----------------------------------------------------------

  private async params(req: IncomingMessage, url: URL): Promise<URLSearchParams> {
    const merged = new URLSearchParams(url.searchParams);
    if (req.method === 'POST') {
      const body = await readBody(req, 32 * 1024);
      if (body) {
        const contentType = (req.headers['content-type'] ?? '').toString();
        if (contentType.includes('application/json')) {
          try {
            const obj = JSON.parse(body) as Record<string, unknown>;
            for (const [k, v] of Object.entries(obj)) if (v !== undefined && v !== null) merged.set(k, String(v));
          } catch {
            /* fall through */
          }
        } else {
          const form = new URLSearchParams(body);
          for (const [k, v] of form) merged.set(k, v);
        }
      }
    }
    return merged;
  }

  private async handleConnect(req: IncomingMessage, res: ServerResponse, url: URL): Promise<void> {
    const params = await this.params(req, url);
    const name = params.get('name') ?? params.get('n') ?? 'Racer';
    const profile: ClientMessage = {
      op: Op.Connect,
      protocolVersion: Number(params.get('v') ?? 1),
      clientVersion: params.get('cv') ?? 'shockwave',
      name,
      vehicle: params.get('veh') ?? 'PlayerCar',
      skin: Number(params.get('sk') ?? 0),
      resumeToken: params.get('tok') ?? '',
    } as ConnectMsg;

    const remote = req.socket.remoteAddress ?? 'unknown';
    const conn = new PollConnection(remote);
    const tempToken = `pending-${Math.random().toString(36).slice(2)}`;
    const entry: PollSession = { conn, session: null, lastSeen: Date.now() };
    this.pollSessions.set(tempToken, entry);

    const result = this.game.connect(conn, profile as ConnectMsg);
    if ('error' in result) {
      this.pollSessions.delete(tempToken);
      text(res, 200, `ERR|c=${result.error},m=${encodeURIComponent(result.message ?? 'rejected')}`);
      return;
    }
    entry.session = result;
    this.pollSessions.delete(tempToken);
    this.pollSessions.set(result.token, entry);
    this.game.welcome(result);

    const mode = Number(params.get('m') ?? 0) === 1 ? Mode.Race : Mode.FreeRoam;
    const world = Number(params.get('w') ?? 0);
    const joinMsg: JoinMsg = {
      op: Op.Join,
      mode: mode as 0 | 1,
      world,
      track: Number(params.get('tr') ?? 0),
      trackId: params.get('tid') ?? '',
      roomCode: params.get('rc') ?? '',
      maxPlayers: Number(params.get('max') ?? this.config.maxPlayersPerRoom),
    };
    this.game.join(result, joinMsg);

    if (params.get('chat')) {
      this.game.handle(result, { op: Op.Chat, channel: 0, text: params.get('chat')! });
    }

    const body = await conn.drain(0);
    text(res, 200, body);
  }

  private async handleTurn(req: IncomingMessage, res: ServerResponse, url: URL): Promise<void> {
    const params = await this.params(req, url);
    const token = params.get('token') ?? '';
    const entry = this.pollSessions.get(token);
    if (!entry || !entry.session) {
      text(res, 200, `ERR|c=${ErrorCode.AuthFailed},m=${encodeURIComponent('Unknown or expired session.')}`);
      return;
    }
    entry.lastSeen = Date.now();
    const payload = params.get('d') ?? '';
    if (payload) this.feed(entry.session, payload);

    const wait = Math.max(0, Math.min(20, Number(params.get('wait') ?? 8)));
    const body = await entry.conn.drain(wait * 1000);
    text(res, 200, body || 'OK|');
  }

  private async handlePoll(req: IncomingMessage, res: ServerResponse, url: URL): Promise<void> {
    const params = await this.params(req, url);
    const entry = this.pollSessions.get(params.get('token') ?? '');
    if (!entry) {
      text(res, 410, `ERR|c=${ErrorCode.AuthFailed},m=expired`);
      return;
    }
    entry.lastSeen = Date.now();
    const wait = Math.max(0, Math.min(20, Number(params.get('wait') ?? this.config.pollTimeoutMs / 1000)));
    const body = await entry.conn.drain(wait * 1000);
    text(res, 200, body || 'OK|');
  }

  private async handleSend(req: IncomingMessage, res: ServerResponse, url: URL): Promise<void> {
    const params = await this.params(req, url);
    const entry = this.pollSessions.get(params.get('token') ?? '');
    if (!entry || !entry.session) {
      text(res, 200, `ERR|c=${ErrorCode.AuthFailed},m=expired`);
      return;
    }
    entry.lastSeen = Date.now();
    const payload = params.get('d') ?? '';
    if (payload) this.feed(entry.session, payload);
    text(res, 200, (await entry.conn.drain(0)) || 'OK|');
  }

  private feed(session: Session, payload: string): void {
    let messages: ClientMessage[] = [];
    try {
      messages = decodeClientText(payload);
    } catch {
      return;
    }
    for (const msg of messages) {
      if (msg.op === Op.Connect) continue;
      try {
        this.game.handle(session, msg);
      } catch (err) {
        console.error('[http] handler error', err);
      }
    }
  }
}

function corsHeaders(): Record<string, string> {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Max-Age': '600',
  };
}

export function text(res: ServerResponse, status: number, body: string): void {
  res.writeHead(status, {
    'Content-Type': 'text/plain; charset=utf-8',
    'Cache-Control': 'no-store',
    ...corsHeaders(),
  });
  res.end(body);
}

export function json(res: ServerResponse, status: number, body: unknown): void {
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    ...corsHeaders(),
  });
  res.end(JSON.stringify(body));
}

export function readBody(req: IncomingMessage, limit: number): Promise<string> {
  return new Promise((resolve) => {
    let size = 0;
    const chunks: Buffer[] = [];
    req.on('data', (chunk: Buffer) => {
      size += chunk.length;
      if (size > limit) {
        req.destroy();
        resolve('');
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', () => resolve(''));
  });
}

export { encodeServerText, PollConnection };
