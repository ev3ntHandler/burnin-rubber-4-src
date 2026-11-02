import { randomBytes } from 'node:crypto';
import {
  ChatChannel,
  ErrorCode,
  ERROR_MESSAGES,
  Mode,
  Op,
  PROTOCOL_VERSION,
  RacePhase,
} from '@br4mp/protocol';
import type { ClientMessage, ConnectMsg, JoinMsg, ServerMessage } from '@br4mp/protocol';
import type { ServerConfig } from './config.js';
import { allTracks, resolveTrack, tracksForWorld } from './data.js';
import { FreeRoamRoom } from './freeRoam.js';
import { RaceRoom } from './race.js';
import { Room } from './room.js';
import type { RoomBus } from './room.js';
import { newPlayer, sanitizeName, tokenBucket } from './types.js';
import type { Connection, Player } from './types.js';

export interface Session {
  id: number;
  token: string;
  name: string;
  vehicle: string;
  skin: number;
  conn: Connection;
  room: Room | null;
  player: Player | null;
  createdAt: number;
  lastSeen: number;
  detachAt: number;
  bot: boolean;
}

const MAX_ROOM_IDLE_MS = 90_000;
const MAX_STRIKES = 12;

export class GameServer implements RoomBus {
  readonly config: ServerConfig;
  readonly rooms = new Map<string, Room>();
  readonly sessions = new Map<string, Session>();
  readonly byPlayer = new Map<number, Session>();
  private nextPlayerId = 1;
  private roomCounter = 0;
  private readonly connectBucket: ReturnType<typeof tokenBucket>;
  private readonly admins: Set<string>;
  private timer: NodeJS.Timeout | null = null;
  private lastTickAt = Date.now();
  private tickDrift = 0;
  public stats = { connections: 0, peakConnections: 0, messagesIn: 0, messagesOut: 0, ticks: 0 };

  constructor(config: ServerConfig) {
    this.config = config;
    this.connectBucket = tokenBucket(20, 40);
    this.admins = new Set(
      (process.env.MP_ADMINS ?? '')
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .filter(Boolean),
    );
    this.warmRooms();
  }

  // -- room lifecycle ------------------------------------------------------

  private newRoomId(mode: number, worldIndex: number): string {
    this.roomCounter++;
    const tag = mode === Mode.Race ? 'race' : 'roam';
    return `${tag}-w${worldIndex}-${this.roomCounter.toString(36)}`;
  }

  createFreeRoam(worldIndex: number): FreeRoamRoom {
    const id = this.newRoomId(Mode.FreeRoam, worldIndex);
    const room = new FreeRoamRoom(this.config, id, worldIndex);
    room.bus = this;
    this.rooms.set(id, room);
    return room;
  }

  createRace(worldIndex: number, trackId: string): RaceRoom {
    const id = this.newRoomId(Mode.Race, worldIndex);
    const room = new RaceRoom(this.config, id, worldIndex, trackId);
    room.bus = this;
    this.rooms.set(id, room);
    return room;
  }

  /** One always-on free roam instance per world so people can join instantly. */
  private warmRooms(): void {
    const worlds = new Set(allTracks().map((t) => t.worldIndex));
    worlds.add(0);
    for (const worldIndex of worlds) {
      for (let i = 0; i < this.config.warmRoomsPerWorld; i++) this.createFreeRoam(worldIndex);
    }
  }

  findFreeRoam(worldIndex: number): FreeRoamRoom {
    for (const room of this.rooms.values()) {
      if (room instanceof FreeRoamRoom && room.worldIndex === worldIndex && room.joinable()) return room;
    }
    return this.createFreeRoam(worldIndex);
  }

  findRace(worldIndex: number, trackId: string, roomCode?: string): RaceRoom {
    if (roomCode) {
      const existing = this.rooms.get(roomCode);
      if (existing instanceof RaceRoom && existing.joinable()) return existing;
      const byShort = [...this.rooms.values()].find(
        (r) => r instanceof RaceRoom && r.id.toUpperCase() === roomCode.toUpperCase() && r.joinable(),
      );
      if (byShort) return byShort as RaceRoom;
      return this.createRace(worldIndex, trackId);
    }
    // Prefer lobbies that already have humans in them, then empty lobbies, and
    // finally rooms in countdown (late joiners land on the back of the grid).
    const candidates = [...this.rooms.values()].filter(
      (room) =>
        room instanceof RaceRoom &&
        room.worldIndex === worldIndex &&
        room.track.id === trackId &&
        room.joinable() &&
        (room.summaryPhase() === RacePhase.Lobby || room.summaryPhase() === RacePhase.Countdown),
    ) as RaceRoom[];
    if (candidates.length) {
      candidates.sort((a, b) => {
        const humansA = [...a.players.values()].filter((p) => !p.isBot).length;
        const humansB = [...b.players.values()].filter((p) => !p.isBot).length;
        const lobbyA = a.summaryPhase() === RacePhase.Lobby ? 0 : 1;
        const lobbyB = b.summaryPhase() === RacePhase.Lobby ? 0 : 1;
        if (lobbyA !== lobbyB) return lobbyA - lobbyB;
        return humansB - humansA;
      });
      return candidates[0];
    }
    return this.createRace(worldIndex, trackId);
  }

  destroyRoom(room: Room): void {
    for (const player of room.publicPlayers()) {
      const session = this.byPlayer.get(player.id);
      if (session) {
        session.room = null;
        session.player = null;
      }
    }
    this.rooms.delete(room.id);
  }

  // -- connection ----------------------------------------------------------

  connect(conn: Connection, msg: ConnectMsg): Session | { error: number; message?: string } {
    if (!this.connectBucket.allow()) return { error: ErrorCode.ServerBusy };
    if (msg.protocolVersion !== PROTOCOL_VERSION) {
      return { error: ErrorCode.BadVersion, message: `Server speaks protocol v${PROTOCOL_VERSION}.` };
    }
    const name = sanitizeName(msg.name);

    // resume an existing session (page reload, connection blip, Director crash)
    if (msg.resumeToken) {
      const existing = this.sessions.get(msg.resumeToken);
      if (existing && Date.now() - existing.detachAt < this.config.resumeWindowMs) {
        existing.conn = conn;
        existing.lastSeen = Date.now();
        existing.detachAt = 0;
        if (existing.player) {
          existing.player.conn = conn;
          existing.player.lastSeen = Date.now();
          existing.room?.requestKeyframe(existing.player.id);
        }
        this.stats.connections++;
        return existing;
      }
    }

    if (!this.config.allowAnonymous && !msg.resumeToken) {
      return { error: ErrorCode.AuthFailed, message: 'This server requires an account ticket.' };
    }

    const taken = [...this.sessions.values()].some(
      (s) => s.name.toLowerCase() === name.toLowerCase() && s.detachAt === 0,
    );
    const finalName = taken ? `${name}-${(this.nextPlayerId % 97).toString()}` : name;

    const session: Session = {
      id: this.nextPlayerId++,
      token: randomBytes(12).toString('base64url'),
      name: finalName,
      vehicle: /^[A-Za-z0-9_]{1,32}$/.test(msg.vehicle) ? msg.vehicle : 'PlayerCar',
      skin: Math.max(0, Math.min(3, msg.skin)),
      conn,
      room: null,
      player: null,
      createdAt: Date.now(),
      lastSeen: Date.now(),
      detachAt: 0,
      bot: false,
    };
    this.sessions.set(session.token, session);
    this.byPlayer.set(session.id, session);
    this.stats.connections++;
    this.stats.peakConnections = Math.max(this.stats.peakConnections, this.activeSessions());
    return session;
  }

  private activeSessions(): number {
    let n = 0;
    for (const s of this.sessions.values()) if (s.detachAt === 0) n++;
    return n;
  }

  welcome(session: Session): void {
    const msg: ServerMessage = {
      op: Op.Welcome,
      playerId: session.id,
      serverTick: Math.floor(process.uptime() * this.config.tickRate),
      tickRate: this.config.tickRate,
      snapshotRate: this.config.snapshotRate,
      resumeToken: session.token,
      serverName: this.config.serverName,
    };
    session.conn.send(msg);
  }

  join(session: Session, msg: JoinMsg): void {
    const worldIndex = Number.isFinite(msg.world) ? Math.max(0, Math.min(7, msg.world)) : 0;
    let room: Room;
    if (msg.mode === Mode.Race) {
      const requested = msg.trackId || resolveTrack('', worldIndex)?.id || tracksForWorld(worldIndex)[0]?.id;
      room = this.findRace(worldIndex, requested, msg.roomCode);
    } else {
      room = this.findFreeRoam(worldIndex);
    }
    this.enterRoom(session, room);
  }

  enterRoom(session: Session, room: Room): Player {
    if (session.room && session.player) {
      // moving between rooms (free roam → private race)
      if (session.room === room) return session.player;
      session.room.removePlayer(session.player.id, 3);
    }
    const player = newPlayer({
      id: session.id,
      name: session.name,
      vehicle: session.vehicle,
      skin: session.skin,
    });
    player.conn = session.conn;
    const id = room.addPlayer(player);
    session.room = room;
    session.player = room.players.get(id) ?? player;
    return session.player;
  }

  leaveRoom(session: Session): void {
    if (session.room && session.player) session.room.removePlayer(session.player.id, 0);
    session.room = null;
    session.player = null;
  }

  disconnect(session: Session): void {
    session.detachAt = Date.now();
    if (session.player) session.player.conn = null;
  }

  /** Called when a session is gone for good. */
  dropSession(session: Session): void {
    this.leaveRoom(session);
    this.sessions.delete(session.token);
    this.byPlayer.delete(session.id);
  }

  handle(session: Session, msg: ClientMessage): void {
    this.stats.messagesIn++;
    session.lastSeen = Date.now();
    if (msg.op === Op.RoomList) {
      this.sendRoomListFor(session, msg.mode);
      return;
    }
    if (!session.room || !session.player) {
      if (msg.op === Op.Join) {
        this.join(session, msg);
        return;
      }
      session.conn.send({
        op: Op.Error,
        code: ErrorCode.NotInRoom,
        message: ERROR_MESSAGES[ErrorCode.NotInRoom],
      });
      return;
    }
    if (msg.op === Op.Join) {
      this.join(session, msg);
      return;
    }
    if (msg.op === Op.Leave) {
      this.leaveRoom(session);
      return;
    }
    if (msg.op === Op.SetVehicle) {
      session.vehicle = msg.vehicle;
      session.skin = msg.skin;
    }
    const player = session.player;
    session.room.handleMessage(player, msg);
    if (player.strikes > MAX_STRIKES) {
      session.conn.send({
        op: Op.Error,
        code: ErrorCode.Kicked,
        message: 'Too many invalid state updates — reconnect to resync.',
      });
      session.conn.close('anticheat');
    }
  }

  // -- RoomBus -------------------------------------------------------------

  sendRoomList(player: Player, mode: number): void {
    const session = this.byPlayer.get(player.id);
    if (!session) return;
    this.sendRoomListFor(session, mode);
  }

  private sendRoomListFor(session: Session, mode: number): void {
    const rooms = [...this.rooms.values()]
      .filter((room) => (mode === -1 ? true : room.mode === mode))
      .map((room) => ({
        id: room.id,
        mode: room.mode as 0 | 1,
        world: room.worldIndex,
        track: 0,
        players: room.players.size,
        maxPlayers: room instanceof RaceRoom ? room.capacity() : this.config.maxPlayersPerRoom,
        phase: room.summaryPhase(),
        joinable: room.joinable(),
      }));
    session.conn.send({ op: Op.RoomListResult, rooms });
  }

  startPrivateRace(a: Player, b: Player, worldIndex: number): void {
    const sessionA = this.byPlayer.get(a.id);
    const sessionB = this.byPlayer.get(b.id);
    if (!sessionA || !sessionB) return;
    const track = tracksForWorld(worldIndex)[0] ?? allTracks()[0];
    if (!track) return;
    const room = this.createRace(worldIndex, track.id);
    this.enterRoom(sessionA, room);
    this.enterRoom(sessionB, room);
    room.systemChat(`${a.name} vs ${b.name} — ${track.name}. Grid up!`);
    room.startCountdown();
  }

  handleTrackCommand(player: Player, arg: string): void {
    const session = this.byPlayer.get(player.id);
    if (!session) return;
    const track = allTracks().find((t) => t.id.toLowerCase() === arg.toLowerCase());
    if (!arg) {
      const list = tracksForWorld(session.room?.worldIndex ?? 0).map((t) => t.id).join(', ');
      session.conn.send({
        op: Op.ChatMsg,
        senderId: 0,
        channel: ChatChannel.System,
        name: 'SYSTEM',
        text: `Tracks: ${list || 'none'}`,
        tick: 0,
      });
      return;
    }
    if (!track) {
      session.conn.send({
        op: Op.ChatMsg,
        senderId: 0,
        channel: ChatChannel.System,
        name: 'SYSTEM',
        text: `Unknown track "${arg}".`,
        tick: 0,
      });
      return;
    }
    if (session.room instanceof RaceRoom) {
      session.conn.send({
        op: Op.ChatMsg,
        senderId: 0,
        channel: ChatChannel.System,
        name: 'SYSTEM',
        text: 'Leave the race first (the race room is fixed to its track).',
        tick: 0,
      });
      return;
    }
    const room = this.findRace(track.worldIndex, track.id);
    this.enterRoom(session, room);
  }

  handleKickCommand(player: Player, arg: string): void {
    const session = this.byPlayer.get(player.id);
    if (!session) return;
    const deny = () =>
      session.conn.send({
        op: Op.ChatMsg,
        senderId: 0,
        channel: ChatChannel.System,
        name: 'SYSTEM',
        text: this.admins.size
          ? 'Only listed admins can kick (MP_ADMINS env var).'
          : 'Kicking is disabled. Set MP_ADMINS=name1,name2 on the server.',
        tick: 0,
      });
    if (!this.admins.has(player.name.toLowerCase())) {
      deny();
      return;
    }
    const target = [...(session.room?.players.values() ?? [])].find(
      (p) => p.name.toLowerCase() === arg.toLowerCase(),
    );
    if (!target) {
      deny();
      return;
    }
    const targetSession = this.byPlayer.get(target.id);
    targetSession?.conn.send({
      op: Op.Error,
      code: ErrorCode.Kicked,
      message: 'You were kicked by an admin.',
    });
    if (targetSession) {
      this.dropSession(targetSession);
      targetSession.conn.close('kicked');
    }
    session.room?.systemChat(`${target.name} was kicked.`);
  }

  // -- ticking -------------------------------------------------------------

  start(): void {
    if (this.timer) return;
    const interval = Math.max(5, Math.round(1000 / this.config.tickRate));
    this.timer = setInterval(() => this.tick(), interval);
    this.timer.unref?.();
  }

  stop(): void {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
  }

  tick(): void {
    const now = Date.now();
    this.tickDrift += now - this.lastTickAt - 1000 / this.config.tickRate;
    this.lastTickAt = now;
    this.stats.ticks++;
    for (const room of [...this.rooms.values()]) {
      room.runTick(now);
      const idle = !room.hasHumans() && now - room.lastActivity > MAX_ROOM_IDLE_MS;
      const warm = room instanceof FreeRoamRoom && this.isWarmRoom(room);
      if (idle && !warm) this.destroyRoom(room);
    }
    // reap detached sessions after the resume window
    for (const session of [...this.sessions.values()]) {
      if (session.detachAt && now - session.detachAt > this.config.resumeWindowMs) {
        this.dropSession(session);
      }
    }
  }

  private isWarmRoom(room: FreeRoamRoom): boolean {
    const perWorld = [...this.rooms.values()].filter(
      (r) => r instanceof FreeRoamRoom && r.worldIndex === room.worldIndex,
    );
    const index = perWorld.indexOf(room);
    return index >= 0 && index < this.config.warmRoomsPerWorld;
  }

  sessionCount(): number {
    return this.activeSessions();
  }

  playerCount(): number {
    let n = 0;
    for (const room of this.rooms.values()) n += room.players.size;
    return n;
  }

  describe(): Record<string, unknown> {
    return {
      server: this.config.serverName,
      protocolVersion: PROTOCOL_VERSION,
      tickRate: this.config.tickRate,
      snapshotRate: this.config.snapshotRate,
      sessions: this.sessionCount(),
      players: this.playerCount(),
      rooms: [...this.rooms.values()].map((room) => ({
        id: room.id,
        mode: room.mode === Mode.Race ? 'race' : 'freeroam',
        world: room.world.world,
        track: room.track?.id ?? null,
        players: room.players.size,
        phase: room.summaryPhase(),
        joinable: room.joinable(),
      })),
      stats: this.stats,
      tickDriftMs: Math.round(this.tickDrift),
    };
  }
}
