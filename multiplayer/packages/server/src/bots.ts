import type { Player } from './types.js';
import type { TrackData } from './data.js';
import { makeSpawnRot } from './room.js';

/**
 * Server side race filler.
 *
 * Follows the same imported traffic loop the players race on, at a plausible
 * pace, and reports gate crossings through the exact same validation path as a
 * human client. Used to keep small lobbies fun and to make the web harness
 * demonstrable with a single human player.
 */
export class BotDriver {
  readonly player: Player;
  private readonly track: TrackData;
  private targetGate: number;
  private readonly cruise: number;
  private pending: number[] = [];
  private wobble: number;

  constructor(player: Player, track: TrackData, seed = 0) {
    this.player = player;
    this.track = track;
    this.targetGate = 0;
    this.cruise = 24 + (seed % 5) * 2.4;
    this.wobble = seed * 0.7;
  }

  step(dt: number): void {
    const gates = this.track.checkpoints;
    const gate = gates[this.targetGate % gates.length];
    const p = this.player;
    const dx = gate.pos[0] - p.pos.x;
    const dy = gate.pos[1] - p.pos.y;
    const dist = Math.hypot(dx, dy) || 1;
    const speed = this.cruise * (1 + Math.sin(Date.now() * 0.0007 + this.wobble) * 0.06);
    const step = Math.min(dist, speed * dt);
    p.pos = {
      x: p.pos.x + (dx / dist) * step,
      y: p.pos.y + (dy / dist) * step,
      z: gate.pos[2] + 1.2,
    };
    p.vel = { x: (dx / dist) * speed, y: (dy / dist) * speed, z: 0 };
    p.speed = speed;
    const yaw = (Math.atan2(dy, dx) * 180) / Math.PI;
    p.rot = makeSpawnRot(yaw);
    if (dist < 16) {
      this.pending.push(this.targetGate % gates.length);
      this.targetGate = (this.targetGate + 1) % gates.length;
    }
  }

  consumedGates(): number[] {
    const gates = this.pending;
    this.pending = [];
    return gates;
  }
}
