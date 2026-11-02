import {
  ActionId,
  ChatChannel,
  CorrectionReason,
  ErrorCode,
  EventId,
  Op,
  PlayerFlag,
  RacePhase,
} from '@br4mp/protocol';
import type { ActionMsg, HitMsg, ServerMessage, Vec3 } from '@br4mp/protocol';
import { makeSpawnRot, Room } from './room.js';
import type { ServerConfig } from './config.js';
import { planarDistance } from './types.js';
import type { Player } from './types.js';

/** Server-side weapon table. Ids match the client's `MP Weapon Map` cast list. */
export interface WeaponDef {
  name: string;
  damage: number;
  range: number;
  cooldownMs: number;
  splashRadius: number;
  hitscan: boolean;
}

export const WEAPONS: WeaponDef[] = [
  { name: 'MachineGun', damage: 6, range: 95, cooldownMs: 110, splashRadius: 0, hitscan: true },
  { name: 'DualMachineGun', damage: 5, range: 95, cooldownMs: 100, splashRadius: 0, hitscan: true },
  { name: 'MiniGun', damage: 3.5, range: 85, cooldownMs: 55, splashRadius: 0, hitscan: true },
  { name: 'Laser', damage: 28, range: 160, cooldownMs: 1100, splashRadius: 0, hitscan: true },
  { name: 'RocketPod', damage: 34, range: 260, cooldownMs: 1400, splashRadius: 9, hitscan: false },
  { name: 'GrenadeLauncher', damage: 30, range: 200, cooldownMs: 1200, splashRadius: 8, hitscan: false },
  { name: 'MineDeployer', damage: 42, range: 12, cooldownMs: 3000, splashRadius: 7, hitscan: false },
  { name: 'FlameThrower', damage: 2.2, range: 28, cooldownMs: 70, splashRadius: 3, hitscan: true },
  { name: 'MainGun', damage: 45, range: 320, cooldownMs: 2400, splashRadius: 6, hitscan: false },
  { name: 'AirstrikeLauncher', damage: 60, range: 420, cooldownMs: 8000, splashRadius: 14, hitscan: false },
];

const RESPAWN_MS = 4500;
const PICKUP_RADIUS = 13;
const PICKUP_RESPAWN_MS = 25_000;
const RAM_COOLDOWN_MS = 450;
const MAX_REWIND_MS = 400;
const VISION_RADIUS = 340;

interface PickupState {
  index: number;
  kind: string;
  pos: Vec3;
  takenUntil: number;
  takenBy: number;
}

interface Invite {
  fromId: number;
  expiresAt: number;
}

/**
 * Persistent free roam world.
 *
 * This is where "see and interact with players" happens: shared pickups the
 * server hands out, ram damage from real relative velocities, lag compensated
 * weapon hits, death/kill feed, horns, emotes and race invites that spin up a
 * private grid without leaving the world.
 */
export class FreeRoamRoom extends Room {
  private readonly pickups: PickupState[] = [];
  private readonly invites = new Map<number, Invite>();
  private readonly ramCooldown = new Map<string, number>();
  private lastCombatTick = 0;

  constructor(config: ServerConfig, id: string, worldIndex: number) {
    super(config, id, 0, worldIndex);
    this.phase = RacePhase.Lobby;
    this.loadPickups();
  }

  private loadPickups(): void {
    const sources = this.world.pickups.slice(0, 80);
    let index = 0;
    for (const pickup of sources) {
      this.pickups.push({
        index: index++,
        kind: pickup.kind,
        pos: { x: pickup.pos[0], y: pickup.pos[1], z: pickup.pos[2] },
        takenUntil: 0,
        takenBy: 0,
      });
    }
  }

  roomLabel(): string {
    return `${this.world.world} Free Roam`;
  }

  joinable(): boolean {
    return this.players.size < this.config.maxPlayersPerRoom;
  }

  summaryPhase(): number {
    return RacePhase.Running;
  }

  spawnPlayer(_player: Player): { pos: Vec3; rot: { x: number; y: number; z: number; w: number } } {
    const spawn = this.world.spawn;
    const angle = Math.random() * Math.PI * 2;
    const radius = 4 + Math.random() * 10;
    return {
      pos: {
        x: spawn.pos[0] + Math.cos(angle) * radius,
        y: spawn.pos[1] + Math.sin(angle) * radius,
        z: spawn.pos[2] + 1.2,
      },
      rot: makeSpawnRot(spawn.yawDeg),
    };
  }

  addPlayer(player: Player): number {
    player.health = player.maxHealth;
    player.deadUntil = 0;
    const id = super.addPlayer(player);
    this.systemChat(`${player.name} entered ${this.world.world} — say hi with the chat bar (Enter).`);
    // tell the newcomer which pickups are currently gone
    const now = Date.now();
    for (const pickup of this.pickups) {
      if (pickup.takenUntil > now) {
        this.send(player, {
          op: Op.Event,
          event: EventId.PickupTaken,
          actorId: 0,
          targetId: 0,
          value: pickup.index,
          pos: pickup.pos,
        });
      }
    }
    return id;
  }

  protected onJoin(player: Player): void {
    this.send(player, {
      op: Op.RaceState,
      phase: RacePhase.Running,
      timeMs: 0,
      lap: 0,
      totalLaps: 0,
      countdownMs: 0,
      standings: [...this.players.values()].map((p) => ({
        id: p.id,
        lap: 0,
        cp: 0,
        dist: 0,
        finished: false,
        finishTimeMs: 0,
        bestLapMs: Math.round(p.health),
      })),
    });
  }

  protected visibleTo(viewer: Player, target: Player): boolean {
    return viewer.id === target.id || planarDistance(viewer.pos, target.pos) <= VISION_RADIUS;
  }

  // -- actions -------------------------------------------------------------

  protected onAction(player: Player, msg: ActionMsg): void {
    switch (msg.action) {
      case ActionId.Horn:
        this.sendEvent(EventId.Horn, player.id, 0, 0, player.pos);
        return;
      case ActionId.Emote:
        this.sendEvent(EventId.Emote, player.id, 0, msg.arg, player.pos);
        return;
      case ActionId.FireWeapon:
        this.sendEvent(EventId.WeaponFired, player.id, 0, msg.arg, player.pos);
        return;
      case ActionId.Respawn:
        this.respawn(player);
        return;
      case ActionId.Pickup:
        this.takePickup(player, msg.arg);
        return;
      case ActionId.InviteRace:
        this.inviteToRace(player, msg.target);
        return;
      case ActionId.AcceptInvite:
        this.acceptInvite(player);
        return;
      default:
        return;
    }
  }

  // -- pickups -------------------------------------------------------------

  private takePickup(player: Player, index: number): void {
    const now = Date.now();
    const pickup = this.pickups[index];
    if (!pickup) return;
    if (pickup.takenUntil > now) return;
    if (planarDistance(player.pos, pickup.pos) > PICKUP_RADIUS) {
      this.sendError(player, ErrorCode.InvalidState, 'Too far from that pickup.');
      return;
    }
    pickup.takenUntil = now + PICKUP_RESPAWN_MS;
    pickup.takenBy = player.id;

    switch (pickup.kind) {
      case 'repair':
      case 'health':
        player.health = Math.min(player.maxHealth, player.health + 45);
        break;
      case 'nitro':
        player.flags |= PlayerFlag.Boosting;
        setTimeout(() => {
          player.flags &= ~PlayerFlag.Boosting;
        }, 1500).unref?.();
        break;
      case 'ammo':
        player.lastFireAt.clear();
        break;
      default:
        break;
    }
    this.sendEvent(EventId.PickupTaken, player.id, 0, index, pickup.pos);
  }

  // -- invites -------------------------------------------------------------

  private inviteToRace(player: Player, targetId: number): void {
    const target = this.players.get(targetId);
    if (!target || target.id === player.id) {
      this.sendError(player, ErrorCode.BadRequest, 'Pick a player to invite.');
      return;
    }
    if (target.isBot) {
      this.sendChat(0, 'SYSTEM', `${target.name} is a bot and accepts by default.`, ChatChannel.System);
      this.acceptInviteFor(player, target);
      return;
    }
    this.invites.set(target.id, { fromId: player.id, expiresAt: Date.now() + 30_000 });
    this.sendEvent(EventId.RaceInvite, player.id, target.id, 0, player.pos);
    this.sendChat(0, 'SYSTEM', `${player.name} invited ${target.name} to a race.`, ChatChannel.System);
  }

  private acceptInvite(player: Player): void {
    const invite = this.invites.get(player.id);
    if (!invite || invite.expiresAt < Date.now()) {
      this.sendError(player, ErrorCode.InvalidState, 'No pending race invite.');
      return;
    }
    this.invites.delete(player.id);
    const inviter = this.players.get(invite.fromId);
    if (!inviter) {
      this.sendError(player, ErrorCode.InvalidState, 'That player left.');
      return;
    }
    this.acceptInviteFor(inviter, player);
  }

  private acceptInviteFor(inviter: Player, player: Player): void {
    if (!this.bus) return;
    this.bus.startPrivateRace(inviter, player, this.worldIndex);
  }

  // -- combat --------------------------------------------------------------

  protected onHit(player: Player, msg: HitMsg): void {
    const now = Date.now();
    const target = this.players.get(msg.targetId);
    if (!target || target.id === player.id) return;
    if (this.isDead(player) || this.isDead(target)) return;

    const weapon = WEAPONS[Math.max(0, Math.min(WEAPONS.length - 1, msg.weapon))];
    const lastFire = player.lastFireAt.get(msg.weapon) ?? 0;
    if (now - lastFire < weapon.cooldownMs * 0.85) {
      this.sendError(player, ErrorCode.RateLimited, 'Weapon firing too fast.');
      return;
    }
    player.lastFireAt.set(msg.weapon, now);

    // The shot must originate near the shooter's accepted position…
    if (planarDistance(msg.pos, player.pos) > weapon.range * 1.15 + 15) {
      return;
    }
    // …and hit where the target actually was, rewound for the shooter's RTT.
    const shotServerTime = msg.clientTimeMs + player.clockOffsetMs;
    const rewind = Math.max(0, Math.min(MAX_REWIND_MS, now - shotServerTime));
    const past = this.positionAt(target.id, now - rewind) ?? {
      pos: target.pos,
    };
    const radius = weapon.hitscan ? 3.6 : Math.max(6, weapon.splashRadius);
    const miss = planarDistance(msg.pos, past.pos as Vec3);
    if (miss > radius) {
      return; // rejected: no damage, no event
    }
    const falloff = weapon.splashRadius > 0 ? Math.max(0.35, 1 - miss / (weapon.splashRadius * 1.5)) : 1;
    const damage = Math.min(weapon.damage, msg.damage || weapon.damage) * falloff;
    this.applyDamage(player, target, damage, msg.pos, weapon.name);
  }

  private applyDamage(attacker: Player, target: Player, amount: number, at: Vec3, _source: string): void {
    if (amount <= 0) return;
    target.health = Math.max(0, target.health - amount);
    this.sendEvent(EventId.Hit, attacker.id, target.id, Math.round(amount), at);
    if (target.health <= 0) this.killPlayer(attacker, target, at);
  }

  private killPlayer(attacker: Player, victim: Player, at: Vec3): void {
    const now = Date.now();
    if (this.isDead(victim)) return;
    victim.health = 0;
    victim.flags |= PlayerFlag.Dead;
    victim.deadUntil = now + RESPAWN_MS;
    victim.deaths++;
    attacker.kills++;
    this.sendEvent(EventId.PlayerDeath, attacker.id, victim.id, 0, at);
    this.sendEvent(EventId.KillFeed, attacker.id, victim.id, attacker.kills, at);
    this.sendChat(0, 'SYSTEM', `${attacker.name} wrecked ${victim.name} (${attacker.kills} kills)`, ChatChannel.System);
  }

  private isDead(player: Player): boolean {
    return player.deadUntil > Date.now() || (player.flags & PlayerFlag.Dead) !== 0;
  }

  // -- tick ----------------------------------------------------------------

  protected onTick(nowMs: number): void {
    this.tickRespawns(nowMs);
    this.tickPickups(nowMs);
    this.tickRamming(nowMs);
    this.tickInvites(nowMs);
  }

  private tickRespawns(nowMs: number): void {
    for (const player of this.players.values()) {
      if (player.isBot) continue;
      if (player.deadUntil > 0 && nowMs >= player.deadUntil) {
        player.deadUntil = 0;
        player.flags &= ~PlayerFlag.Dead;
        const spawn = this.spawnPlayer(player);
        player.health = player.maxHealth;
        this.teleport(player, spawn.pos, spawn.rot, CorrectionReason.Respawn);
        this.sendEvent(EventId.PlayerRespawn, player.id, 0, 0, spawn.pos);
      }
    }
  }

  private tickPickups(nowMs: number): void {
    for (const pickup of this.pickups) {
      if (pickup.takenUntil > 0 && nowMs >= pickup.takenUntil) {
        pickup.takenUntil = 0;
        pickup.takenBy = 0;
        this.broadcast({
          op: Op.Event,
          event: EventId.PickupRespawn,
          actorId: 0,
          targetId: 0,
          value: pickup.index,
          pos: pickup.pos,
        });
      }
    }
  }

  /** Collision damage from real relative velocities, so ramming means something. */
  private tickRamming(nowMs: number): void {
    if (nowMs - this.lastCombatTick < 100) return;
    this.lastCombatTick = nowMs;
    const list = [...this.players.values()].filter((p) => !this.isDead(p));
    for (let i = 0; i < list.length; i++) {
      for (let j = i + 1; j < list.length; j++) {
        const a = list[i];
        const b = list[j];
        const gap = planarDistance(a.pos, b.pos);
        if (gap > 3.6 || Math.abs(a.pos.z - b.pos.z) > 3) continue;
        const key = a.id < b.id ? `${a.id}:${b.id}` : `${b.id}:${a.id}`;
        const last = this.ramCooldown.get(key) ?? 0;
        if (nowMs - last < RAM_COOLDOWN_MS) continue;
        this.ramCooldown.set(key, nowMs);
        const rel = Math.hypot(a.vel.x - b.vel.x, a.vel.y - b.vel.y);
        if (rel < 13) continue;
        const damage = Math.min(18, 2 + rel * 0.28);
        const faster = Math.hypot(a.vel.x, a.vel.y) >= Math.hypot(b.vel.x, b.vel.y) ? a : b;
        const slower = faster.id === a.id ? b : a;
        this.applyDamage(faster, slower, damage, slower.pos, 'Ram');
        this.applyDamage(slower, faster, damage * 0.45, faster.pos, 'Ram');
      }
    }
  }

  private tickInvites(nowMs: number): void {
    for (const [id, invite] of this.invites) {
      if (invite.expiresAt < nowMs || !this.players.has(id)) this.invites.delete(id);
    }
  }

  pickupSnapshot(): Array<{ index: number; kind: string; pos: Vec3; taken: boolean }> {
    const now = Date.now();
    return this.pickups.map((p) => ({ index: p.index, kind: p.kind, pos: p.pos, taken: p.takenUntil > now }));
  }
}
