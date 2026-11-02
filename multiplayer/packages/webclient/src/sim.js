/**
 * Local arcade car model for the harness.
 *
 * It deliberately mirrors the feel of the Shockwave original (impulse-ish
 * acceleration, speed-scaled yaw, drift grip, nitro) but it is *not* the game's
 * physics: in the real integration the Director client keeps running
 * `[PS] Advanced Car` and only the networking layer is replaced.
 */
const ACCEL = 16;
const BRAKE = 24;
const MAX_SPEED = 46;
const NITRO_SPEED = 60;
const TURN_RATE = 1.5; // rad/s at full grip
const DRAG = 0.6;

export class Car {
  constructor(x = 0, y = 0, z = 0, yaw = 0) {
    this.pos = { x, y, z };
    this.yaw = yaw;
    this.speed = 0;
    this.health = 100;
    this.nitro = 0.35;
    this.drifting = false;
    this.seq = 0;
    this.lap = 0;
    this.cp = 0;
    this.flags = 0;
    this.nitroActive = 0;
  }

  get rot() {
    const half = this.yaw / 2;
    return { x: 0, y: 0, z: Math.sin(half), w: Math.cos(half) };
  }

  get vel() {
    return { x: Math.cos(this.yaw) * this.speed, y: Math.sin(this.yaw) * this.speed, z: 0 };
  }

  step(dt, input) {
    const throttle = (input.forward ? 1 : 0) - (input.backward ? 1 : 0);
    const steer = (input.right ? 1 : 0) - (input.left ? 1 : 0);
    const maxSpeed = input.nitro && this.nitro > 0.02 ? NITRO_SPEED : MAX_SPEED;

    if (input.nitro && this.nitro > 0.02) {
      this.nitro = Math.max(0, this.nitro - dt * 0.35);
      this.nitroActive = 1;
    } else {
      this.nitro = Math.min(1, this.nitro + dt * 0.05);
      this.nitroActive = 0;
    }

    if (throttle > 0) this.speed += ACCEL * (this.nitroActive ? 1.5 : 1) * dt;
    else if (throttle < 0) this.speed -= BRAKE * dt;
    else this.speed -= Math.sign(this.speed) * Math.min(Math.abs(this.speed), 8 * dt);

    this.drifting = Boolean(input.brake) && Math.abs(this.speed) > 9;
    this.speed -= this.speed * DRAG * dt * (this.drifting ? 0.4 : 1);
    this.speed = Math.max(-MAX_SPEED * 0.45, Math.min(maxSpeed, this.speed));

    const grip = this.drifting ? 0.62 : 1;
    const speedFactor = Math.min(1, Math.abs(this.speed) / 12);
    this.yaw += steer * TURN_RATE * grip * speedFactor * dt * Math.sign(this.speed || 1);

    const vx = Math.cos(this.yaw) * this.speed;
    const vy = Math.sin(this.yaw) * this.speed;
    this.pos.x += vx * dt;
    this.pos.y += vy * dt;
    if (this.pos.z < 1) this.pos.z = 1.2;
  }

  /** Snapshot uplink payload. */
  snapshot() {
    this.seq++;
    return {
      pos: { x: this.pos.x, y: this.pos.y, z: this.pos.z },
      rot: this.rot,
      vel: this.vel,
      speed: Math.abs(this.speed),
      health: this.health,
      lap: this.lap,
      cp: this.cp,
      flags: this.flags,
      seq: this.seq,
    };
  }

  applyCorrection(pos, rot, vel, hard) {
    if (hard) {
      this.pos = { ...pos };
      this.yaw = yawFromQuat(rot);
      this.speed = Math.hypot(vel.x, vel.y) * Math.sign(this.speed || 1);
      return;
    }
    // soft reconciliation: pull 18% per receiving frame, keep control feel
    this.pos.x += (pos.x - this.pos.x) * 0.18;
    this.pos.y += (pos.y - this.pos.y) * 0.18;
  }
}

export function yawFromQuat(q) {
  const siny = 2 * (q.w * q.z + q.x * q.y);
  const cosy = 1 - 2 * (q.y * q.y + q.z * q.z);
  return Math.atan2(siny, cosy);
}

/** Snapshot interpolation buffer for a remote entity. */
export class Interpolator {
  constructor() {
    this.frames = [];
    this.latest = { pos: { x: 0, y: 0, z: 0 }, yaw: 0, speed: 0, health: 100, flags: 0 };
  }

  push(now, pos, rot, speed, health, flags) {
    this.latest = { pos, yaw: yawFromQuat(rot), speed, health, flags };
    this.frames.push({ t: now, ...this.latest });
    if (this.frames.length > 40) this.frames.shift();
  }

  /** Returns {pos, yaw, speed} at `now - delayMs`. */
  sample(now, delayMs = 120) {
    const target = now - delayMs;
    const frames = this.frames;
    if (!frames.length) return this.latest;
    if (frames.length === 1 || target <= frames[0].t) return frames[0];
    const last = frames[frames.length - 1];
    if (target >= last.t) return last;
    for (let i = frames.length - 1; i > 0; i--) {
      const a = frames[i - 1];
      const b = frames[i];
      if (target >= a.t && target <= b.t) {
        const span = b.t - a.t || 1;
        const k = (target - a.t) / span;
        let delta = b.yaw - a.yaw;
        while (delta > Math.PI) delta -= Math.PI * 2;
        while (delta < -Math.PI) delta += Math.PI * 2;
        return {
          pos: {
            x: a.pos.x + (b.pos.x - a.pos.x) * k,
            y: a.pos.y + (b.pos.y - a.pos.y) * k,
            z: a.pos.z + (b.pos.z - a.pos.z) * k,
          },
          yaw: a.yaw + delta * k,
          speed: a.speed + (b.speed - a.speed) * k,
          health: b.health,
          flags: b.flags,
        };
      }
    }
    return last;
  }
}
