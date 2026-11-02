import type { Quat, Vec3 } from './constants.js';

/**
 * Quantisation helpers.
 *
 * Positions/velocities are stored as 1/32 m fixed point shorts. Burnin' Rubber's
 * worlds span roughly ±2000 m (`MiniMap.GetBla` divides by 2048*1.87), so an
 * int32 at 1/32 m is exact enough (3 cm) and deltas compress to 1–2 bytes.
 */
export const POS_SCALE = 32;
export const VEL_SCALE = 32;

export function quantPos(v: Vec3): [number, number, number] {
  return [Math.round(v.x * POS_SCALE), Math.round(v.y * POS_SCALE), Math.round(v.z * POS_SCALE)];
}

export function dequantPos(x: number, y: number, z: number): Vec3 {
  return { x: x / POS_SCALE, y: y / POS_SCALE, z: z / POS_SCALE };
}

export function quantVel(v: Vec3): [number, number, number] {
  return [Math.round(v.x * VEL_SCALE), Math.round(v.y * VEL_SCALE), Math.round(v.z * VEL_SCALE)];
}

export function dequantVel(x: number, y: number, z: number): Vec3 {
  return { x: x / VEL_SCALE, y: y / VEL_SCALE, z: z / VEL_SCALE };
}

const INV_SQRT2 = Math.SQRT1_2; // 0.7071067811865476
const QUAT_BITS = 10;
const QUAT_MASK = (1 << QUAT_BITS) - 1; // 1023

/**
 * Smallest-three quaternion packing: 2 bits index + 3 × 10 bits = 32 bits.
 * Angular error ≈ 2 * (π/2) / 1023 ≈ 0.003 rad (0.17°), far below anything the
 * Shockwave 3D renderer or a car's wheel can show.
 */
export function packQuat(q: Quat): number {
  const c = [q.x, q.y, q.z, q.w];
  let largest = 0;
  for (let i = 1; i < 4; i++) if (Math.abs(c[i]) > Math.abs(c[largest])) largest = i;
  const sign = c[largest] < 0 ? -1 : 1;

  let packed = largest;
  let shift = 2;
  for (let i = 0; i < 4; i++) {
    if (i === largest) continue;
    let v = (c[i] * sign) / INV_SQRT2; // -> [-1, 1]
    v = Math.max(-1, Math.min(1, v));
    const quant = Math.round(((v + 1) / 2) * QUAT_MASK);
    packed |= (quant & QUAT_MASK) << shift;
    shift += QUAT_BITS;
  }
  return packed >>> 0;
}

export function unpackQuat(packed: number): Quat {
  const largest = packed & 0x3;
  const c = [0, 0, 0, 0];
  let shift = 2;
  let sum = 0;
  for (let i = 0; i < 4; i++) {
    if (i === largest) continue;
    const quant = (packed >>> shift) & QUAT_MASK;
    shift += QUAT_BITS;
    const v = (quant / QUAT_MASK) * 2 - 1; // [-1, 1]
    const component = v * INV_SQRT2;
    c[i] = component;
    sum += component * component;
  }
  const missing = Math.sqrt(Math.max(0, 1 - sum));
  c[largest] = missing;
  return { x: c[0], y: c[1], z: c[2], w: c[3] };
}

/** Euler (degrees, Shockwave's intrinsic order) -> quaternion, for race spawn data. */
export function eulerToQuat(yawDeg: number, pitchDeg = 0, rollDeg = 0): Quat {
  const h = (yawDeg * Math.PI) / 360;
  const p = (pitchDeg * Math.PI) / 360;
  const r = (rollDeg * Math.PI) / 360;
  const ch = Math.cos(h);
  const sh = Math.sin(h);
  const cp = Math.cos(p);
  const sp = Math.sin(p);
  const cr = Math.cos(r);
  const sr = Math.sin(r);
  return {
    x: sr * cp * ch - cr * sp * sh,
    y: cr * sp * ch + sr * cp * sh,
    z: cr * cp * sh - sr * sp * ch,
    w: cr * cp * ch + sr * sp * sh,
  };
}

export function clamp(v: number, min: number, max: number): number {
  return v < min ? min : v > max ? max : v;
}
