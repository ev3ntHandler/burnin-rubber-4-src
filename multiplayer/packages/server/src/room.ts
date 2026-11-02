import {
  ActionId,
  ChatChannel,
  CorrectionReason,
  ErrorCode,
  ERROR_MESSAGES,
  EventId,
  Op,
  PlayerFlag,
  RacePhase,
  SnapField,
} from '@br4mp/protocol';
import type {
  ActionMsg,
  ChatMsg,
  ClientMessage,
  CorrectionMsg,
  HitMsg,
  JoinMsg,
  RaceStateMsg,
  ServerMessage,
  SnapshotEntry,
  SnapshotMsg,
  Vec3,
} from '@br4mp/protocol';
import type { ServerConfig } from './config.js';
import { getTrack, getWorld } from './data.js';
import type { TrackData, WorldData } from './data.js';
import {
  distance,
  planarDistance,
  sanitizeName,
  tokenBucket,
  newPlayer,
  descriptor,
} from './types.js';
import type { Connection, Player, PlayerSnapshotRecord, SentState } from './types.js';

const KEYFRAME_INTERVAL_TICKS = 100; // 5 s at 20 Hz
const HISTORY_LENGTH = 128; // 6.4 s of rewound positions
const STALE_STATE_MS = 2000;
const CORRECTION_COOLDOWN_MS = 500;

export interface RaceSettings {
  totalLaps: number;
  type: 'circuit' | 'sprint';
  finishCheckpoint: number;
}

/**
 * One authoritative game session (a free roam world instance or one race).
 *
 * The server does not re-simulate Burnin' Rubber's hover physics. Instead the
 * owning client streams its state at 20–30 Hz and the server:
 *   - validates every state (speed budget, teleport distance, room bounds),
 *   - keeps a 6 s history per player for lag-compensated hit validation,
 *   - owns everything that must be unique: checkpoints, laps, standings,
 *     health, pickups, kills, chat, match state,
 *   - publishes delta compressed snapshots with interest management.
 *
 * Movement authority stays with the client (that is what makes a 2007-era
 * Shockwave physics engine playable over the internet); everything a player
 * could cheat for is server side. See docs/01-architecture.md.
 */
/** Ids handed to server-side filler bots (never clash with session ids). */
let nextBotId = 1_000_000;

export abstract class Room {
  readonly id: string;
  readonly mode: number;
  readonly worldIndex: number;
  world: WorldData;
  track: TrackData | null;
  players = new Map<number, Player>();
  chatLog: Array<Extract<ServerMessage, { op: typeof Op.ChatMsg }>> = [];
  tick = 0;
  startedAt = Date.now();
  lastActivity = Date.now();
  settings: RaceSettings;
  protected readonly config: ServerConfig;
  private readonly lastSent = new Map<number, Map<number, SentState>>();
  private readonly history = new Map<number, PlayerSnapshotRecord[]>();
  private readonly keyframeRequested = new Set<number>();
  private readonly chatBucket: ReturnType<typeof tokenBucket>;
  private nextPlayerId = 1;
  protected phase: number = RacePhase.Lobby;
  /** Set by the registry so rooms can talk to each other (invites, quick match). */
  bus: RoomBus | null = null;

  constructor(config: ServerConfig, id: string, mode: number, worldIndex: number, trackId?: string) {
    this.config = config;
    this.id = id;
    this.mode = mode;
    this.worldIndex = worldIndex;
    this.world = getWorld(worldIndex) ?? {
      world: 'Unknown',
      worldIndex,
      source: 'none',
      spawn: { name: 'default', pos: [0, 0, 0], yawDeg: 0 },
      markers: [],
      pickups: [],
      roads: [],
    };
    this.track = trackId ? (getTrack(trackId) ?? null) : null;
    this.settings = {
      totalLaps: this.track?.totalLaps ?? 1,
      type: this.track?.type ?? 'circuit',
      finishCheckpoint: this.track?.finishCheckpoint ?? -1,
    };
    this.chatBucket = tokenBucket(3, 6);
  }

  // -- lifecycle -----------------------------------------------------------

  abstract roomLabel(): string;
  abstract joinable(): boolean;
  abstract summaryPhase(): number;
  /** Called once per tick before snapshots. */
  protected abstract onTick(nowMs: number): void;
  /** Extra messages a joining player needs (race state, pickups, ...). */
  protected abstract onJoin(player: Player): void;
  /** Field of `ClientMessage` handling beyond the shared ones. */
  protected abstract onAction(player: Player, msg: ActionMsg): void;
  protected abstract onHit(player: Player, msg: HitMsg): void;
  abstract spawnPlayer(player: Player): { pos: Vec3; rot: { x: number; y: number; z: number; w: number } };
  /** Should `target` be included in `viewer`'s snapshot? */
  protected abstract visibleTo(viewer: Player, target: Player): boolean;

  addPlayer(player: Player): number {
    // Humans arrive with the id the GameServer gave them; bots get synthetic ids
    // far outside the session range so a filler can never shadow a real session.
    let id = player.id;
    if (!id) id = player.isBot ? nextBotId++ : this.nextPlayerId++;
    if (this.players.has(id)) {
      // Never let a late arrival clobber an existing player (the id space used to
      // collide between room bots and GameServer sessions).
      id = player.isBot ? nextBotId++ : this.nextPlayerId++;
    }
    player.id = id;
    if (!player.rot) player.rot = { x: 0, y: 0, z: 0, w: 1 };
    const spawn = this.spawnPlayer(player);
    player.pos = spawn.pos;
    player.rot = spawn.rot;
    this.players.set(id, player);
    this.history.set(id, []);
    this.keyframeRequested.add(id);
    this.lastActivity = Date.now();

    const joined = {
      op: Op.Joined,
      roomId: this.id,
      mode: this.mode,
      world: this.worldIndex,
      track: 0,
      trackId: this.track?.id ?? '',
      totalLaps: this.settings.totalLaps,
      players: [...this.players.values()].map(descriptor),
      startTick: this.tick + this.config.tickRate * 4,
    } as const;
    this.send(player, joined as ServerMessage);
    // chat history so late joiners see context
    for (const chat of this.chatLog.slice(-this.config.chatHistory)) this.send(player, chat);
    this.broadcast({ op: Op.PlayerJoin, player: descriptor(player) }, id);
    this.onJoin(player);
    return id;
  }

  removePlayer(id: number, reason = 0): void {
    const player = this.players.get(id);
    if (!player) return;
    this.players.delete(id);
    this.history.delete(id);
    this.lastSent.delete(id);
    this.keyframeRequested.delete(id);
    if (player.conn) {
      try {
        player.conn.send({ op: Op.PlayerLeave, id, reason });
      } catch {
        /* connection already gone */
      }
    }
    this.broadcast({ op: Op.PlayerLeave, id, reason });
    this.lastActivity = Date.now();
  }

  isEmpty(): boolean {
    return this.players.size === 0;
  }

  /** True when only server-side filler bots are left (rooms without humans idle out). */
  hasHumans(): boolean {
    for (const p of this.players.values()) if (!p.isBot) return true;
    return false;
  }

  publicPlayers(): Player[] {
    return [...this.players.values()];
  }

  // -- messaging -----------------------------------------------------------

  send(player: Player, msg: ServerMessage): void {
    if (!player.conn) return;
    try {
      player.conn.send(msg);
    } catch {
      player.conn = null;
    }
  }

  broadcast(msg: ServerMessage, exceptId?: number): void {
    for (const p of this.players.values()) {
      if (p.id === exceptId || !p.conn) continue;
      try {
        p.conn.send(msg);
      } catch {
        p.conn = null;
      }
    }
  }

  sendError(player: Player, code: number, message?: string): void {
    this.send(player, {
      op: Op.Error,
      code,
      message: message ?? ERROR_MESSAGES[code] ?? 'Error',
    });
  }

  sendEvent(
    event: number,
    actorId: number,
    targetId = 0,
    value = 0,
    pos: Vec3 = { x: 0, y: 0, z: 0 },
  ): void {
    this.broadcast({ op: Op.Event, event, actorId, targetId, value, pos });
  }

  sendChat(
    senderId: number,
    name: string,
    text: string,
    channel: number = ChatChannel.All,
  ): void {
    const msg = {
      op: Op.ChatMsg,
      senderId,
      channel,
      name,
      text,
      tick: this.tick,
    } as const;
    this.chatLog.push(msg);
    if (this.chatLog.length > 200) this.chatLog.shift();
    this.broadcast(msg);
  }

  systemChat(text: string): void {
    this.sendChat(0, 'SYSTEM', text, ChatChannel.System);
  }

  requestKeyframe(playerId: number): void {
    this.keyframeRequested.add(playerId);
  }

  // -- message dispatch ----------------------------------------------------

  handleMessage(player: Player, msg: ClientMessage): void {
    player.lastSeen = Date.now();
    this.lastActivity = Date.now();
    switch (msg.op) {
      case Op.Input:
        player.lastAckTick = Math.max(player.lastAckTick, msg.ackTick);
        player.clockOffsetMs = player.clockOffsetMs || 0;
        return;
      case Op.State:
        this.applyState(player, msg);
        return;
      case Op.Chat:
        this.handleChat(player, msg);
        return;
      case Op.Ping: {
        // Clock sync: remember the offset between the client clock and ours so
        // hit reports can be rewound to the right server tick.
        player.clockOffsetMs = Date.now() - msg.clientTimeMs;
        this.send(player, { op: Op.Pong, nonce: msg.nonce, tick: this.tick, clientTimeMs: msg.clientTimeMs });
        return;
      }
      case Op.Ready: {
        player.ready = msg.ready;
        this.broadcast({ op: Op.PlayerJoin, player: descriptor(player) });
        return;
      }
      case Op.Action:
        this.onAction(player, msg);
        return;
      case Op.Hit:
        this.onHit(player, msg);
        return;
      case Op.SetVehicle: {
        const vehicle = msg.vehicle.slice(0, 32);
        if (!/^[A-Za-z0-9_]*$/.test(vehicle)) {
          this.sendError(player, ErrorCode.BadRequest, 'Invalid vehicle id');
          return;
        }
        player.vehicle = vehicle || player.vehicle;
        player.skin = Math.max(0, Math.min(3, msg.skin));
        this.broadcast({ op: Op.PlayerJoin, player: descriptor(player) });
        this.sendEvent(EventId.VehicleChanged, player.id, 0, 0, player.pos);
        return;
      }
      case Op.RoomList: {
        if (this.bus) this.bus.sendRoomList(player, msg.mode);
        return;
      }
      default:
        return;
    }
  }

  /**
   * Accept a state update from the owning client.
   *
   * Guard rails (see docs/06-operations.md):
   *   - implied speed above `maxSpeed * 1.8` (physics tolerance for nitro/ramps)
   *   - a single update jumping further than `maxTeleportM`
   *   - updates while dead / before the race start
   * Offenders get a `Correction` back to their last accepted transform.
   */
  protected applyState(
    player: Player,
    msg: Extract<ClientMessage, { op: typeof Op.State }>,
  ): void {
    const now = Date.now();
    if (msg.seq <= player.lastStateSeq && player.lastStateSeq - msg.seq < 1000) {
      return; // duplicated / reordered update
    }
    if (!Number.isFinite(msg.pos.x) || !Number.isFinite(msg.pos.y) || !Number.isFinite(msg.pos.z)) return;
    if (msg.pos.x === 0 && msg.pos.y === 0 && msg.pos.z === 0 && player.lastStateAt === 0) {
      // Lingo clients that spawn before streaming positions
      player.lastStateSeq = msg.seq;
      player.lastStateAt = now;
      return;
    }

    // Floor the sample interval: bursty transports (HTTP long-poll) can deliver
    // two updates back to back, which must not look like a 3000 m/s teleport.
    const moved = distance(msg.pos, player.pos);
    const speedBudgetPerSecond = this.config.maxSpeedMs * 1.8;
    const budgetElapsed = Math.max(0, now - (player.budgetAt || now)) / 1000;
    player.distanceBudget = Math.min(
      speedBudgetPerSecond * 0.35,
      (player.distanceBudget || 0) + budgetElapsed * speedBudgetPerSecond,
    );
    player.budgetAt = now;
    let corrected = false;

    if (player.lastStateAt === 0) {
      // First state after (re)connect: the client spawns on its own side, so allow
      // a generous window before the speed budget applies.
      if (moved > 400) {
        this.correct(player, CorrectionReason.AntiCheat);
        return;
      }
    } else if (moved > this.config.maxTeleportM) {
      corrected = true;
      player.strikes++;
      if (process.env.MP_DEBUG_AC) {
        console.log(
          `[ac] ${player.name}#${player.id} bot=${player.isBot} conn=${player.conn ? 'y' : 'n'} teleport ${moved.toFixed(1)}m > ${this.config.maxTeleportM}m (strike ${player.strikes}) from ${new Error().stack?.split('\n')[2]?.trim()}`,
        );
      }
    } else if (moved > player.distanceBudget + 0.5) {
      // Bursts are fine (HTTP long-poll delivers in clumps); sustained movement
      // faster than the fastest car in the game is not.
      corrected = true;
      player.strikes++;
      if (process.env.MP_DEBUG_AC) {
        console.log(`[ac] ${player.name} budget ${moved.toFixed(1)}m > ${player.distanceBudget.toFixed(1)}m (strike ${player.strikes})`);
      }
    } else {
      player.distanceBudget = Math.max(0, player.distanceBudget - moved);
    }

    if (corrected) {
      this.correct(player, CorrectionReason.AntiCheat);
      return;
    }

    player.pos = msg.pos;
    player.rot = msg.rot;
    player.vel = msg.vel;
    player.speed = Math.max(0, Math.min(400, msg.speed));
    player.health = Math.max(0, Math.min(9999, msg.health));
    player.lap = msg.lap;
    player.cp = msg.cp;
    player.flags = msg.flags;
    player.lastStateSeq = msg.seq;
    player.lastStateAt = now;
    player.lastAckTick = Math.max(player.lastAckTick, msg.ackTick);
    this.onStateApplied(player, msg);
  }

  /** Hook for race progress validation. */
  protected onStateApplied(_player: Player, _msg: Extract<ClientMessage, { op: typeof Op.State }>): void {}

  correct(player: Player, reason: number): void {
    const now = Date.now();
    if (now - player.lastCorrectedAt < CORRECTION_COOLDOWN_MS) return;
    player.lastCorrectedAt = now;
    const msg: CorrectionMsg = {
      op: Op.Correction,
      seq: player.lastStateSeq,
      reason,
      pos: player.pos,
      rot: player.rot,
      vel: player.vel,
    };
    this.send(player, msg);
  }

  teleport(player: Player, pos: Vec3, rot: { x: number; y: number; z: number; w: number }, reason: number): void {
    player.pos = pos;
    player.rot = rot;
    player.vel = { x: 0, y: 0, z: 0 };
    player.speed = 0;
    this.send(player, { op: Op.Correction, seq: player.lastStateSeq, reason, pos, rot, vel: player.vel });
  }

  // -- chat ----------------------------------------------------------------

  private handleChat(player: Player, msg: ChatMsg): void {
    const now = Date.now();
    player.chatTimestamps = player.chatTimestamps.filter((t) => now - t < 10_000);
    const allowed =
      this.chatBucket.allow() && player.chatTimestamps.length < 6 && now - (player.chatTimestamps.at(-1) ?? 0) > 250;
    if (!allowed) {
      this.sendError(player, ErrorCode.RateLimited, 'Chat rate limit reached.');
      return;
    }
    player.chatTimestamps.push(now);

    const text = msg.text
      .replace(/[\u0000-\u001f\u007f]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim()
      .slice(0, this.config.chatMaxLength);
    if (!text) return;

    if (text.startsWith('/')) {
      this.handleCommand(player, text);
      return;
    }
    this.sendChat(player.id, player.name, text, msg.channel === ChatChannel.Team ? ChatChannel.Team : ChatChannel.All);
  }

  protected handleCommand(player: Player, text: string): void {
    const [cmd, ...rest] = text.slice(1).split(' ');
    const arg = rest.join(' ').trim();
    switch ((cmd ?? '').toLowerCase()) {
      case 'help':
        this.sendChat(0, 'SYSTEM', 'Commands: /help /players /respawn /me <action> /w <name> <msg> /r <msg> /track', ChatChannel.System);
        return;
      case 'players': {
        const list = [...this.players.values()]
          .map((p) => `${p.name}${p.id === player.id ? ' (you)' : ''}`)
          .join(', ');
        this.sendChat(0, 'SYSTEM', `${this.players.size} in ${this.roomLabel()}: ${list}`, ChatChannel.System);
        return;
      }
      case 'me':
        if (arg) this.sendEvent(EventId.Emote, player.id, 0, 0, player.pos);
        if (arg) this.sendChat(player.id, player.name, `* ${player.name} ${arg.slice(0, 80)} *`);
        return;
      case 'w':
      case 'whisper': {
        const [name, ...words] = rest;
        const target = [...this.players.values()].find(
          (p) => p.name.toLowerCase() === (name ?? '').toLowerCase() && !p.isBot,
        );
        const body = words.join(' ').trim();
        if (!target || !body) {
          this.sendChat(0, 'SYSTEM', 'Usage: /w <name> <message>', ChatChannel.System);
          return;
        }
        this.send(target, {
          op: Op.ChatMsg,
          senderId: player.id,
          channel: ChatChannel.Whisper,
          name: player.name,
          text: body.slice(0, this.config.chatMaxLength),
          tick: this.tick,
        });
        this.sendChat(0, 'SYSTEM', `To ${target.name}: ${body}`, ChatChannel.System);
        return;
      }
      case 'r':
      case 'respawn':
        this.respawn(player);
        return;
      case 'track':
        if (this.bus) this.bus.handleTrackCommand(player, arg);
        return;
      case 'kick':
        if (this.bus) this.bus.handleKickCommand(player, arg);
        return;
      default:
        this.sendChat(0, 'SYSTEM', `Unknown command /${cmd}. Try /help`, ChatChannel.System);
    }
  }

  respawn(player: Player): void {
    const spawn = this.spawnPlayer(player);
    player.health = player.maxHealth;
    player.deadUntil = 0;
    player.flags &= ~PlayerFlag.Dead;
    this.teleport(player, spawn.pos, spawn.rot, CorrectionReason.Respawn);
    this.sendEvent(EventId.PlayerRespawn, player.id, 0, 0, spawn.pos);
  }

  // -- tick ----------------------------------------------------------------

  runTick(nowMs: number): void {
    this.tick++;
    this.onTick(nowMs);
    for (const p of this.players.values()) {
      if (p.conn === null && !p.isBot) {
        if (nowMs - p.lastSeen > this.config.pollIdleDisconnectMs) this.removePlayer(p.id, 1);
        continue;
      }
      this.recordHistory(p, nowMs);
    }
    if (this.tick % Math.max(1, Math.round(this.config.tickRate / this.config.snapshotRate)) === 0) {
      this.broadcastSnapshots();
    }
  }

  private recordHistory(player: Player, nowMs: number): void {
    let list = this.history.get(player.id);
    if (!list) {
      list = [];
      this.history.set(player.id, list);
    }
    list.push({ tick: this.tick, timeMs: nowMs, pos: player.pos, rot: player.rot, vel: player.vel });
    if (list.length > HISTORY_LENGTH) list.shift();
  }

  /** Interpolated position of `playerId` at a past server time (lag compensation). */
  positionAt(playerId: number, timeMs: number): PlayerSnapshotRecord | null {
    const list = this.history.get(playerId);
    if (!list || list.length === 0) return null;
    if (timeMs >= list[list.length - 1].timeMs) return list[list.length - 1];
    if (timeMs <= list[0].timeMs) return list[0];
    for (let i = list.length - 1; i > 0; i--) {
      const a = list[i - 1];
      const b = list[i];
      if (timeMs >= a.timeMs && timeMs <= b.timeMs) {
        const t = b.timeMs === a.timeMs ? 0 : (timeMs - a.timeMs) / (b.timeMs - a.timeMs);
        return {
          tick: b.tick,
          timeMs,
          pos: {
            x: a.pos.x + (b.pos.x - a.pos.x) * t,
            y: a.pos.y + (b.pos.y - a.pos.y) * t,
            z: a.pos.z + (b.pos.z - a.pos.z) * t,
          },
          rot: b.rot,
          vel: {
            x: a.vel.x + (b.vel.x - a.vel.x) * t,
            y: a.vel.y + (b.vel.y - a.vel.y) * t,
            z: a.vel.z + (b.vel.z - a.vel.z) * t,
          },
        };
      }
    }
    return list[0];
  }

  // -- snapshots -----------------------------------------------------------

  private broadcastSnapshots(): void {
    for (const viewer of this.players.values()) {
      if (!viewer.conn) continue;
      const keyframe = this.keyframeRequested.delete(viewer.id);
      let sent = this.lastSent.get(viewer.id);
      if (!sent || keyframe) {
        sent = new Map();
        this.lastSent.set(viewer.id, sent);
      }
      const entries: SnapshotEntry[] = [];

      for (const target of this.players.values()) {
        if (!this.visibleTo(viewer, target)) continue;
        const prev = sent.get(target.id);
        const entry = this.buildEntry(target, prev, keyframe, target.id === viewer.id);
        if (!entry) continue;
        entries.push(entry);
        sent.set(target.id, {
          tick: this.tick,
          pos: target.pos,
          rot: target.rot,
          vel: target.vel,
          health: target.health,
          flags: target.flags,
          lap: target.lap,
          cp: target.cp,
          speed: target.speed,
        });
      }

      if (!entries.length) continue;
      const msg: SnapshotMsg = { op: Op.Snapshot, tick: this.tick, baselineTick: 0, entries };
      try {
        viewer.conn.send(msg);
      } catch {
        viewer.conn = null;
      }
    }
  }

  private buildEntry(
    target: Player,
    prev: SentState | undefined,
    keyframe: boolean,
    isSelf: boolean,
  ): SnapshotEntry | null {
    // A client's own entry is absolute whenever it is sent: it is the
    // authoritative answer to the client's prediction, never a delta against its
    // predicted state.
    const absolute = keyframe || !prev;
    let mask = 0;
    if (absolute || !prev || distance(prev.pos, target.pos) > 0.02) mask |= SnapField.Position;
    if (absolute || !prev || quatAngle(prev.rot, target.rot) > (absolute ? 0.001 : 0.012)) mask |= SnapField.Rotation;
    if (absolute || !prev || distance(prev.vel, target.vel) > 0.35) mask |= SnapField.Velocity;
    if (absolute || !prev || prev.health !== target.health) mask |= SnapField.Health;
    if (absolute || !prev || prev.flags !== target.flags) mask |= SnapField.Flags;
    if (absolute || !prev || prev.lap !== target.lap || prev.cp !== target.cp) mask |= SnapField.Race;
    if (absolute || !prev || Math.abs(prev.speed - target.speed) > 1) mask |= SnapField.Speed;
    if (mask === 0) return null;
    if (absolute || isSelf) mask |= SnapField.Absolute;
    if (isSelf) mask |= SnapField.Position;
    return {
      id: target.id,
      mask,
      pos: target.pos,
      rot: target.rot,
      vel: target.vel,
      health: Math.round(target.health),
      flags: target.flags,
      lap: target.lap,
      cp: target.cp,
      speed: Math.round(target.speed),
    };
  }

  /** Normalised quaternion relative angle in radians. */
  // eslint-disable-next-line class-methods-use-this
  protected raceState(): RaceStateMsg {
    return {
      op: Op.RaceState,
      phase: this.phase,
      timeMs: Date.now() - this.startedAt,
      lap: 0,
      totalLaps: this.settings.totalLaps,
      countdownMs: 0,
      standings: [],
    };
  }
}

function quatAngle(a: { x: number; y: number; z: number; w: number }, b: { x: number; y: number; z: number; w: number }): number {
  const dot = Math.abs(a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w);
  return 2 * Math.acos(Math.min(1, dot));
}

export interface RoomBus {
  sendRoomList(player: Player, mode: number): void;
  startPrivateRace(inviter: Player, invitee: Player, worldIndex: number): void;
  handleTrackCommand(player: Player, arg: string): void;
  handleKickCommand(player: Player, arg: string): void;
}

export function makeSpawnRot(yawDeg: number): { x: number; y: number; z: number; w: number } {
  // yaw around Z (the game's up axis)
  const half = (yawDeg * Math.PI) / 360;
  return { x: 0, y: 0, z: Math.sin(half), w: Math.cos(half) };
}

export function yawFromQuat(q: { x: number; y: number; z: number; w: number }): number {
  // forward is +Y in Burnin' Rubber's authoring space
  const siny = 2 * (q.w * q.z + q.x * q.y);
  const cosy = 1 - 2 * (q.y * q.y + q.z * q.z);
  return (Math.atan2(siny, cosy) * 180) / Math.PI;
}

export { sanitizeName, newPlayer, tokenBucket, planarDistance, distance, KEYFRAME_INTERVAL_TICKS, STALE_STATE_MS };
