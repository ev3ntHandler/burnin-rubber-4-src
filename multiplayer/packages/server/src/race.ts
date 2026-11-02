import {
  CorrectionReason,
  EventId,
  Op,
  PlayerFlag,
  RacePhase,
} from '@br4mp/protocol';
import type {
  ActionMsg,
  ClientMessage,
  HitMsg,
  PlayerDescriptor,
  RaceStanding,
  ServerMessage,
  Vec3,
} from '@br4mp/protocol';
import { makeSpawnRot, Room } from './room.js';
import type { ServerConfig } from './config.js';
import type { TrackCheckpoint, TrackData } from './data.js';
import { resolveTrack } from './data.js';
import { newPlayer, planarDistance } from './types.js';
import type { Player } from './types.js';
import { BotDriver } from './bots.js';

export const COUNTDOWN_MS = 4000;
export const RESULTS_MS = 10_000;
export const FINISH_WINDOW_MS = 45_000;
const STUCK_SPEED = 1.2;
const STUCK_MS = 6500;
const MAX_GRID = 12;

interface RaceProgress {
  /** Index of the next gate we expect this player to cross. */
  expected: number;
  started: boolean;
  lapStartedAt: number;
  stuckSince: number;
  lastGateAt: number;
}

/**
 * Circuit / sprint race.
 *
 * Progress is validated against the gates derived from the game's own traffic
 * waypoint loops (see tools/import-br4-data.mjs): a gate only counts when the
 * player crosses its plane in the forward direction, inside its lateral width,
 * and it is the gate the server expects (with a two gate tolerance for lossy
 * transport). Laps, split times, standings and the finish order are therefore
 * impossible to fake from a modified client.
 */
export class RaceRoom extends Room {
  track: TrackData;
  private readonly progress = new Map<number, RaceProgress>();
  private readonly gridPos = new Map<number, Vec3>();
  private countdownEndsAt = 0;
  private runningStartedAt = 0;
  private resultsUntil = 0;
  private lastStateBroadcast = 0;
  private bots: BotDriver[] = [];
  private raceNumber = 0;

  constructor(config: ServerConfig, id: string, worldIndex: number, trackId: string) {
    super(config, id, 1, worldIndex, trackId);
    this.track = resolveTrack(trackId, worldIndex) as TrackData;
    this.settings = {
      totalLaps: this.track.totalLaps,
      type: this.track.type ?? 'circuit',
      finishCheckpoint: this.track.finishCheckpoint ?? -1,
    };
    this.phase = RacePhase.Lobby;
  }

  roomLabel(): string {
    return this.track.name;
  }

  joinable(): boolean {
    return this.players.size < this.capacity() && this.phase !== RacePhase.Results;
  }

  summaryPhase(): number {
    return this.phase;
  }

  capacity(): number {
    return Math.min(MAX_GRID, this.config.maxPlayersPerRoom);
  }

  spawnPlayer(player: Player): { pos: Vec3; rot: { x: number; y: number; z: number; w: number } } {
    const index = this.players.size;
    const slot = this.track.grid[index % this.track.grid.length];
    const row = Math.floor(index / this.track.grid.length);
    return {
      pos: { x: slot.pos[0] - row * 7, y: slot.pos[1], z: slot.pos[2] + 1.2 },
      rot: makeSpawnRot(slot.yawDeg),
    };
  }

  addPlayer(player: Player): number {
    const id = super.addPlayer(player);
    this.resetProgress(player);
    this.gridPos.set(id, { ...player.pos });
    player.health = player.maxHealth;
    this.systemChat(`${player.name} joined the race (${this.players.size}/${this.capacity()}).`);
    this.broadcastRaceState();
    if (this.phase === RacePhase.Lobby && this.players.size >= 2) this.startCountdown();
    return id;
  }

  removePlayer(id: number, reason = 0): void {
    super.removePlayer(id, reason);
    this.progress.delete(id);
    this.gridPos.delete(id);
    if (this.phase !== RacePhase.Lobby && this.players.size === 0) this.phase = RacePhase.Lobby;
  }

  protected onJoin(player: Player): void {
    this.send(player, this.raceState());
    this.send(player, {
      op: Op.Event,
      event: EventId.RaceCountdown,
      actorId: 0,
      targetId: 0,
      value: Math.max(0, this.countdownEndsAt - Date.now()),
      pos: { x: 0, y: 0, z: 0 },
    });
  }

  protected onAction(player: Player, msg: ActionMsg): void {
    switch (msg.action) {
      case 2:
        this.respawnToLastGate(player);
        return;
      case 0:
        this.sendEvent(EventId.Horn, player.id, 0, 0, player.pos);
        return;
      default:
        return;
    }
  }

  protected onHit(_player: Player, _msg: HitMsg): void {
    /* weapons are disabled on the grid */
  }

  protected visibleTo(_viewer: Player, _target: Player): boolean {
    return true;
  }

  // -- lifecycle -----------------------------------------------------------

  startCountdown(): void {
    if (this.phase !== RacePhase.Lobby) return;
    this.phase = RacePhase.Countdown;
    this.countdownEndsAt = Date.now() + COUNTDOWN_MS;
    this.raceNumber++;
    for (const p of this.players.values()) {
      if (p.isBot) continue;
      const spawn = this.spawnPlayer(p);
      this.teleport(p, spawn.pos, spawn.rot, CorrectionReason.RaceStart);
      this.resetProgress(p);
      this.gridPos.set(p.id, { ...spawn.pos });
    }
    for (const bot of this.bots) {
      const spawn = this.spawnPlayer(bot.player);
      bot.player.pos = spawn.pos;
      bot.player.rot = spawn.rot;
      this.resetProgress(bot.player);
    }
    this.spawnBotsIfNeeded();
    this.systemChat(
      `Race starting in ${COUNTDOWN_MS / 1000}s — ${this.settings.totalLaps} lap(s) on ${this.track.name}.`,
    );
    this.broadcastRaceState();
  }

  private resetProgress(player: Player): void {
    player.lap = 0;
    player.cp = 0;
    player.finished = false;
    player.finishTimeMs = 0;
    player.bestLapMs = 0;
    player.flags &= ~PlayerFlag.Dead;
    this.progress.set(player.id, {
      expected: 0,
      started: false,
      lapStartedAt: 0,
      stuckSince: 0,
      lastGateAt: 0,
    });
  }

  private spawnBotsIfNeeded(): void {
    if (!this.config.fillWithBots) return;
    const humans = [...this.players.values()].filter((p) => !p.isBot).length;
    if (humans === 0) return;
    const wanted = Math.min(Math.max(0, this.config.botsPerRace), this.capacity() - this.players.size);
    const names = ['Ava', 'Bolt', 'Crank', 'Diesel', 'Echo', 'Fang'];
    for (let i = 0; i < wanted; i++) {
      const id = this.addBot(names[(this.bots.length + i) % names.length] + (this.bots.length + i >= names.length ? String(i) : ''));
      const bot = this.players.get(id);
      if (bot) this.bots.push(new BotDriver(bot, this.track, id % 7));
    }
  }

  private addBot(name: string): number {
    const bot = newPlayer({
      id: 0,
      name,
      vehicle: 'Bullet350',
      skin: this.players.size % 3,
      isBot: true,
      ready: true,
    });
    return this.addPlayer(bot);
  }

  private removeBots(): void {
    for (const bot of this.bots) this.removePlayer(bot.player.id, 2);
    this.bots = [];
  }

  private startRace(): void {
    this.phase = RacePhase.Running;
    this.runningStartedAt = Date.now();
    this.sendEvent(EventId.RaceGo, 0, 0, 0, { x: 0, y: 0, z: 0 });
    this.systemChat('GO!');
    this.broadcastRaceState();
  }

  private resetToLobby(): void {
    this.removeBots();
    this.phase = RacePhase.Lobby;
    this.countdownEndsAt = 0;
    this.runningStartedAt = 0;
    for (const p of this.players.values()) {
      const spawn = this.spawnPlayer(p);
      this.teleport(p, spawn.pos, spawn.rot, CorrectionReason.ServerReset);
      this.resetProgress(p);
    }
    this.systemChat('Race over — waiting for the next grid (2+ players starts automatically).');
    this.broadcastRaceState();
  }

  // -- tick ----------------------------------------------------------------

  protected onTick(nowMs: number): void {
    const dt = 1 / this.config.tickRate;

    if (this.phase === RacePhase.Running || this.phase === RacePhase.Finishing) {
      for (const bot of this.bots) {
        bot.step(dt);
        this.checkGateCrossing(bot.player, bot.consumedGates(), nowMs);
      }
    }

    switch (this.phase) {
      case RacePhase.Countdown: {
        for (const p of this.players.values()) {
          if (p.isBot) continue;
          const grid = this.gridPos.get(p.id);
          if (grid && planarDistance(p.pos, grid) > 6) {
            this.teleport(p, grid, p.rot, CorrectionReason.RaceStart);
            this.sendChat(0, 'SYSTEM', 'False start — hold your position.', 2);
          }
        }
        if (nowMs >= this.countdownEndsAt) this.startRace();
        break;
      }
      case RacePhase.Running: {
        for (const p of this.players.values()) {
          if (p.isBot || p.finished) continue;
          const progress = this.progress.get(p.id);
          if (!progress) continue;
          if (p.speed < STUCK_SPEED) {
            progress.stuckSince = progress.stuckSince || nowMs;
            if (nowMs - progress.stuckSince > STUCK_MS) {
              progress.stuckSince = 0;
              this.systemChat(`${p.name} reset to the last checkpoint.`);
              this.respawnToLastGate(p);
            }
          } else {
            progress.stuckSince = 0;
          }
        }
        const finished = [...this.players.values()].filter((p) => p.finished);
        if (finished.length > 0) {
          this.phase = RacePhase.Finishing;
          this.resultsUntil = nowMs + FINISH_WINDOW_MS;
          const winner = [...finished].sort((a, b) => a.finishTimeMs - b.finishTimeMs)[0];
          this.systemChat(`🏁 ${winner.name} wins — ${this.formatTime(winner.finishTimeMs)}`);
          this.broadcastRaceState();
        }
        break;
      }
      case RacePhase.Finishing: {
        const pending = [...this.players.values()].filter((p) => !p.finished && !p.isBot);
        if (nowMs >= this.resultsUntil || pending.length === 0) {
          this.phase = RacePhase.Results;
          this.resultsUntil = nowMs + RESULTS_MS;
          const order = this.standings();
          this.systemChat(
            `Results: ${order
              .slice(0, 6)
              .map((s, i) => `${i + 1}. ${this.players.get(s.id)?.name ?? '?'}`)
              .join('  ')}`,
          );
          this.broadcastRaceState();
        }
        break;
      }
      case RacePhase.Results:
        if (nowMs >= this.resultsUntil) this.resetToLobby();
        break;
      default:
        break;
    }

    if (nowMs - this.lastStateBroadcast > 250) {
      this.lastStateBroadcast = nowMs;
      this.broadcastRaceState();
    }
  }

  // -- gates ---------------------------------------------------------------

  protected onStateApplied(player: Player, msg: Extract<ClientMessage, { op: typeof Op.State }>): void {
    if (this.phase !== RacePhase.Running && this.phase !== RacePhase.Finishing) return;
    if (player.finished) return;
    const hit = this.expectedGateCrossing(player, msg.pos);
    if (hit !== -1) this.advance(player, hit, Date.now(), msg.pos);
  }

  private checkGateCrossing(player: Player, gates: number[], nowMs: number): void {
    for (const gate of gates) this.advance(player, gate, nowMs, player.pos);
  }

  /** Which of the next few gates did the player just cross forward? */
  private expectedGateCrossing(player: Player, newPos: Vec3): number {
    const progress = this.progress.get(player.id);
    if (!progress) return -1;
    const gates = this.track.checkpoints;
    for (let offset = 0; offset <= 2; offset++) {
      const index = (progress.expected + offset) % gates.length;
      if (this.crossed(player.pos, newPos, gates[index])) return index;
    }
    return -1;
  }

  private crossed(from: Vec3, to: Vec3, gate: TrackCheckpoint): boolean {
    const yaw = (gate.yawDeg * Math.PI) / 180;
    const fx = Math.cos(yaw);
    const fy = Math.sin(yaw);
    const s0 = (from.x - gate.pos[0]) * fx + (from.y - gate.pos[1]) * fy;
    const s1 = (to.x - gate.pos[0]) * fx + (to.y - gate.pos[1]) * fy;
    if (!(s0 < 0 && s1 >= 0)) return false;
    const lateral = Math.abs(-(to.x - gate.pos[0]) * fy + (to.y - gate.pos[1]) * fx);
    return lateral <= gate.width / 2 + 6;
  }

  private advance(player: Player, gateIndex: number, nowMs: number, at: Vec3): void {
    const progress = this.progress.get(player.id);
    if (!progress) return;
    const gates = this.track.checkpoints;

    const delta = (gateIndex - progress.expected + gates.length) % gates.length;
    if (delta > 2) return; // stale / out of order
    progress.expected = (gateIndex + 1) % gates.length;
    progress.lastGateAt = nowMs;
    player.cp = gateIndex;

    this.sendEvent(EventId.Checkpoint, player.id, 0, gateIndex, at);

    if (this.settings.type === 'sprint') {
      if (gateIndex === this.settings.finishCheckpoint) {
        this.finishPlayer(player, nowMs);
      }
      return;
    }

    if (gateIndex !== 0) return;
    // crossed the start/finish line
    if (!progress.started) {
      progress.started = true;
      progress.lapStartedAt = nowMs;
      return;
    }
    const lapMs = nowMs - (progress.lapStartedAt || this.runningStartedAt);
    progress.lapStartedAt = nowMs;
    const completed = player.lap + 1;
    player.bestLapMs = player.bestLapMs ? Math.min(player.bestLapMs, lapMs) : lapMs;
    this.sendEvent(EventId.RaceLap, player.id, 0, Math.round(lapMs), at);
    if (completed >= this.settings.totalLaps) {
      player.lap = completed;
      this.finishPlayer(player, nowMs);
      return;
    }
    player.lap = completed;
    this.systemChat(
      `${player.name} — lap ${completed + 1}/${this.settings.totalLaps} (${this.formatTime(lapMs)})`,
    );
  }

  private finishPlayer(player: Player, nowMs: number): void {
    if (player.finished) return;
    player.finished = true;
    player.finishTimeMs = nowMs - this.runningStartedAt;
    player.lap = this.settings.totalLaps;
    this.sendEvent(EventId.RaceFinish, player.id, 0, player.finishTimeMs, player.pos);
    for (const p of this.players.values()) if (p.conn) this.requestKeyframe(p.id);
  }

  respawnToLastGate(player: Player): void {
    const progress = this.progress.get(player.id);
    const gates = this.track.checkpoints;
    const index = progress ? Math.max(0, (progress.expected - 1 + gates.length) % gates.length) : 0;
    const gate = gates[index];
    const yaw = (gate.yawDeg * Math.PI) / 180;
    this.teleport(
      player,
      { x: gate.pos[0] - Math.cos(yaw) * 6, y: gate.pos[1] - Math.sin(yaw) * 6, z: gate.pos[2] + 1.2 },
      makeSpawnRot(gate.yawDeg),
      CorrectionReason.Stuck,
    );
    player.health = player.maxHealth;
  }

  // -- standings -----------------------------------------------------------

  standings(): RaceStanding[] {
    const gates = this.track.checkpoints;
    const list: RaceStanding[] = [];
    for (const player of this.players.values()) {
      const progress = this.progress.get(player.id);
      const nextGate = gates[(progress?.expected ?? 0) % gates.length];
      const dist = nextGate
        ? planarDistance(player.pos, { x: nextGate.pos[0], y: nextGate.pos[1], z: nextGate.pos[2] })
        : 0;
      list.push({
        id: player.id,
        lap: player.lap,
        cp: player.cp,
        dist,
        finished: player.finished,
        finishTimeMs: player.finishTimeMs,
        bestLapMs: Math.round(player.bestLapMs),
      });
    }
    list.sort((a, b) => {
      if (a.finished !== b.finished) return a.finished ? -1 : 1;
      if (a.finished && b.finished) return a.finishTimeMs - b.finishTimeMs;
      if (a.lap !== b.lap) return b.lap - a.lap;
      if (a.cp !== b.cp) return b.cp - a.cp;
      return a.dist - b.dist;
    });
    return list;
  }

  protected raceState(): Extract<ServerMessage, { op: typeof Op.RaceState }> {
    const standings = this.standings();
    const leader = standings[0];
    return {
      op: Op.RaceState,
      phase: this.phase,
      timeMs: this.runningStartedAt ? Date.now() - this.runningStartedAt : 0,
      lap: (leader?.lap ?? 0) + (this.phase === RacePhase.Running ? 1 : 0),
      totalLaps: this.settings.totalLaps,
      countdownMs: Math.max(0, this.countdownEndsAt - Date.now()),
      standings,
    };
  }

  broadcastRaceState(): void {
    this.broadcast(this.raceState());
  }

  private formatTime(ms: number): string {
    const total = Math.max(0, Math.round(ms));
    const minutes = Math.floor(total / 60000);
    const seconds = Math.floor((total % 60000) / 1000);
    const millis = total % 1000;
    return `${minutes}:${String(seconds).padStart(2, '0')}.${String(millis).padStart(3, '0')}`;
  }

  descriptors(): PlayerDescriptor[] {
    return [...this.players.values()].map((p) => ({
      id: p.id,
      name: p.name,
      vehicle: p.vehicle,
      skin: p.skin,
      ready: p.ready,
    }));
  }

  /** Test helper: skip the countdown. */
  forceStart(): void {
    if (this.phase === RacePhase.Lobby) this.startCountdown();
    this.startRace();
  }

  /** Test helper: drive a player through a specific gate. */
  debugCrossGate(playerId: number, gateIndex: number): void {
    const player = this.players.get(playerId);
    if (!player) return;
    this.advance(player, gateIndex, Date.now(), player.pos);
  }
}
