import { Op, PROTOCOL_VERSION, SnapField } from './constants.js';
import type { ClientMessage, ServerMessage } from './messages.js';
import type { SnapshotEntry } from './constants.js';
import { Reader, Writer } from './bits.js';
import { dequantPos, dequantVel, packQuat, quantPos, quantVel, unpackQuat } from './quantize.js';

export class ProtocolError extends Error {}

const MAX_STRING = 512;

// ---------------------------------------------------------------------------
// small vec/quat helpers on the writer
// ---------------------------------------------------------------------------

function wVec(w: Writer, v: { x: number; y: number; z: number }): void {
  w.f32(v.x).f32(v.y).f32(v.z);
}

function rVec(r: Reader) {
  return { x: r.f32(), y: r.f32(), z: r.f32() };
}

function wQuat(w: Writer, q: { x: number; y: number; z: number; w: number }): void {
  w.u32(packQuat(q));
}

function rQuat(r: Reader) {
  return unpackQuat(r.u32());
}

function wShortString(w: Writer, s: string): void {
  const clipped = s.length > MAX_STRING ? s.slice(0, MAX_STRING) : s;
  w.string(clipped);
}

// ---------------------------------------------------------------------------
// client -> server
// ---------------------------------------------------------------------------

export function encodeClientMessage(msg: ClientMessage): Uint8Array {
  const w = new Writer(64);
  w.u8(msg.op);

  switch (msg.op) {
    case Op.Connect:
      w.u16(msg.protocolVersion)
        .string(msg.clientVersion)
        .string(msg.name)
        .string(msg.vehicle)
        .u8(msg.skin)
        .string(msg.resumeToken);
      break;
    case Op.Join:
      w.u8(msg.mode).u8(msg.world).u8(msg.track).string(msg.roomCode).string(msg.trackId).u16(msg.maxPlayers);
      break;
    case Op.Input:
      w.varuint(msg.seq).varuint(msg.ackTick).u16(msg.buttons).varint(msg.steer).varuint(msg.clientTimeMs);
      break;
    case Op.State: {
      w.varuint(msg.seq).varuint(msg.ackTick).u8(msg.flags);
      const [px, py, pz] = quantPos(msg.pos);
      w.i32(px).i32(py).i32(pz);
      wQuat(w, msg.rot);
      const [vx, vy, vz] = quantVel(msg.vel);
      w.i16(vx).i16(vy).i16(vz);
      w.varuint(msg.health).u8(msg.lap).u8(msg.cp).varuint(Math.round(msg.speed));
      break;
    }
    case Op.Chat:
      w.u8(msg.channel).string(msg.text);
      break;
    case Op.Ping:
      w.varuint(msg.nonce).varuint(msg.clientTimeMs);
      break;
    case Op.Ready:
      w.u8(msg.ready ? 1 : 0);
      break;
    case Op.Action:
      w.u8(msg.action).varuint(msg.target).varint(msg.arg);
      wVec(w, msg.pos);
      break;
    case Op.Hit:
      w.varuint(msg.targetId).u8(msg.weapon);
      wVec(w, msg.pos);
      w.varuint(msg.clientTimeMs).varuint(Math.round(msg.damage));
      break;
    case Op.SetVehicle:
      w.string(msg.vehicle).u8(msg.skin);
      break;
    case Op.Leave:
      break;
    case Op.RoomList:
      w.u8(msg.mode);
      break;
    default:
      throw new ProtocolError(`unknown client opcode ${(msg as { op: number }).op}`);
  }
  return w.toBytes();
}

export function decodeClientMessage(bytes: Uint8Array): ClientMessage {
  const r = new Reader(bytes);
  const op = r.u8();
  switch (op) {
    case Op.Connect:
      return {
        op,
        protocolVersion: r.u16(),
        clientVersion: r.string(),
        name: r.string(),
        vehicle: r.string(),
        skin: r.u8(),
        resumeToken: r.string(),
      };
    case Op.Join:
      return {
        op,
        mode: r.u8() as 0 | 1,
        world: r.u8(),
        track: r.u8(),
        roomCode: r.string(),
        trackId: r.string(),
        maxPlayers: r.u16(),
      };
    case Op.Input:
      return {
        op,
        seq: r.varuint(),
        ackTick: r.varuint(),
        buttons: r.u16(),
        steer: r.varint(),
        clientTimeMs: r.varuint(),
      };
    case Op.State: {
      const seq = r.varuint();
      const ackTick = r.varuint();
      const flags = r.u8();
      const pos = dequantPos(r.i32(), r.i32(), r.i32());
      const rot = rQuat(r);
      const vel = dequantVel(r.i16(), r.i16(), r.i16());
      const health = r.varuint();
      const lap = r.u8();
      const cp = r.u8();
      const speed = r.varuint();
      return { op, seq, ackTick, pos, rot, vel, health, lap, cp, speed, flags };
    }
    case Op.Chat:
      return { op, channel: r.u8(), text: r.string() };
    case Op.Ping:
      return { op, nonce: r.varuint(), clientTimeMs: r.varuint() };
    case Op.Ready:
      return { op, ready: r.u8() === 1 };
    case Op.Action:
      return { op, action: r.u8(), target: r.varuint(), arg: r.varint(), pos: rVec(r) };
    case Op.Hit:
      return {
        op,
        targetId: r.varuint(),
        weapon: r.u8(),
        pos: rVec(r),
        clientTimeMs: r.varuint(),
        damage: r.varuint(),
      };
    case Op.SetVehicle:
      return { op, vehicle: r.string(), skin: r.u8() };
    case Op.Leave:
      return { op };
    case Op.RoomList:
      return { op, mode: r.u8() };
    default:
      throw new ProtocolError(`unknown client opcode 0x${op.toString(16)}`);
  }
}

// ---------------------------------------------------------------------------
// server -> client
// ---------------------------------------------------------------------------

/** Baseline lookup used to delta encode snapshot entries. */
export type BaselineLookup = (id: number) => SnapshotEntry | undefined;

export function encodeServerMessage(msg: ServerMessage, baseline?: BaselineLookup): Uint8Array {
  const w = new Writer(256);
  w.u8(msg.op);
  switch (msg.op) {
    case Op.Welcome:
      w.varuint(msg.playerId)
        .varuint(msg.serverTick)
        .u8(msg.tickRate)
        .u8(msg.snapshotRate)
        .string(msg.resumeToken)
        .string(msg.serverName);
      break;
    case Op.Joined: {
      w.string(msg.roomId).u8(msg.mode).u8(msg.world).u8(msg.track).u8(msg.totalLaps);
      w.string(msg.trackId);
      w.varuint(msg.startTick);
      w.varuint(msg.players.length);
      for (const p of msg.players) {
        w.varuint(p.id).string(p.name).string(p.vehicle).u8(p.skin).u8(p.ready ? 1 : 0);
      }
      break;
    }
    case Op.Snapshot: {
      w.varuint(msg.tick).varuint(msg.baselineTick).varuint(msg.entries.length);
      for (const e of msg.entries) {
        w.varuint(e.id).u8(e.mask);
        if (e.mask & SnapField.Position) {
          const [px, py, pz] = quantPos(e.pos ?? { x: 0, y: 0, z: 0 });
          if (e.mask & SnapField.Absolute) {
            w.i32(px).i32(py).i32(pz);
          } else {
            const base = baseline?.(e.id)?.pos;
            const [bx, by, bz] = base
              ? quantPos(base)
              : [0, 0, 0];
            w.varint(px - bx).varint(py - by).varint(pz - bz);
          }
        }
        if (e.mask & SnapField.Rotation) wQuat(w, e.rot ?? { x: 0, y: 0, z: 0, w: 1 });
        if (e.mask & SnapField.Velocity) {
          const [vx, vy, vz] = quantVel(e.vel ?? { x: 0, y: 0, z: 0 });
          if (e.mask & SnapField.Absolute) {
            w.i16(vx).i16(vy).i16(vz);
          } else {
            const base = baseline?.(e.id)?.vel;
            const [bx, by, bz] = base ? quantVel(base) : [0, 0, 0];
            w.varint(vx - bx).varint(vy - by).varint(vz - bz);
          }
        }
        if (e.mask & SnapField.Health) w.varuint(e.health ?? 0);
        if (e.mask & SnapField.Flags) w.u8(e.flags ?? 0);
        if (e.mask & SnapField.Race) w.u8(e.lap ?? 0).u8(e.cp ?? 0);
        if (e.mask & SnapField.Speed) w.varuint(Math.round(e.speed ?? 0));
      }
      break;
    }
    case Op.PlayerJoin: {
      const p = msg.player;
      w.varuint(p.id).string(p.name).string(p.vehicle).u8(p.skin).u8(p.ready ? 1 : 0);
      break;
    }
    case Op.PlayerLeave:
      w.varuint(msg.id).u8(msg.reason);
      break;
    case Op.ChatMsg:
      w.varuint(msg.senderId).u8(msg.channel).string(msg.name).string(msg.text).varuint(msg.tick);
      break;
    case Op.Event:
      w.u8(msg.event).varuint(msg.actorId).varuint(msg.targetId).varint(msg.value);
      wVec(w, msg.pos);
      break;
    case Op.RaceState: {
      w.u8(msg.phase).varuint(msg.timeMs).u8(msg.lap).u8(msg.totalLaps).varuint(msg.countdownMs);
      w.varuint(msg.standings.length);
      for (const s of msg.standings) {
        w.varuint(s.id).u8(s.lap).u8(s.cp).varuint(Math.round(s.dist));
        w.u8(s.finished ? 1 : 0).varuint(s.finishTimeMs).varuint(s.bestLapMs);
      }
      break;
    }
    case Op.Correction:
      w.varuint(msg.seq).u8(msg.reason);
      wVec(w, msg.pos);
      wQuat(w, msg.rot);
      wVec(w, msg.vel);
      break;
    case Op.Pong:
      w.varuint(msg.nonce).varuint(msg.tick).varuint(msg.clientTimeMs);
      break;
    case Op.Error:
      w.u8(msg.code).string(msg.message);
      break;
    case Op.RoomListResult: {
      w.varuint(msg.rooms.length);
      for (const room of msg.rooms) {
        w.string(room.id).u8(room.mode).u8(room.world).u8(room.track);
        w.varuint(room.players).varuint(room.maxPlayers).u8(room.phase).u8(room.joinable ? 1 : 0);
      }
      break;
    }
    default:
      throw new ProtocolError(`unknown server opcode ${(msg as { op: number }).op}`);
  }
  return w.toBytes();
}

export function decodeServerMessage(bytes: Uint8Array, baseline?: BaselineLookup): ServerMessage {
  const r = new Reader(bytes);
  const op = r.u8();
  switch (op) {
    case Op.Welcome:
      return {
        op,
        playerId: r.varuint(),
        serverTick: r.varuint(),
        tickRate: r.u8(),
        snapshotRate: r.u8(),
        resumeToken: r.string(),
        serverName: r.string(),
      };
    case Op.Joined: {
      const roomId = r.string();
      const mode = r.u8();
      const world = r.u8();
      const track = r.u8();
      const totalLaps = r.u8();
      const trackId = r.string();
      const startTick = r.varuint();
      const count = r.varuint();
      const players = [];
      for (let i = 0; i < count; i++) {
        players.push({
          id: r.varuint(),
          name: r.string(),
          vehicle: r.string(),
          skin: r.u8(),
          ready: r.u8() === 1,
        });
      }
      return { op, roomId, mode, world, track, totalLaps, trackId, startTick, players };
    }
    case Op.Snapshot: {
      const tick = r.varuint();
      const baselineTick = r.varuint();
      const count = r.varuint();
      const entries: SnapshotEntry[] = [];
      for (let i = 0; i < count; i++) {
        const id = r.varuint();
        const mask = r.u8();
        const entry: SnapshotEntry = { id, mask };
        const base = baseline?.(id);
        if (mask & SnapField.Position) {
          if (mask & SnapField.Absolute) {
            entry.pos = dequantPos(r.i32(), r.i32(), r.i32());
          } else {
            const [bx, by, bz] = base?.pos ? quantPos(base.pos) : [0, 0, 0];
            entry.pos = dequantPos(
              bx + r.varint(),
              by + r.varint(),
              bz + r.varint(),
            );
          }
        }
        if (mask & SnapField.Rotation) entry.rot = rQuat(r);
        if (mask & SnapField.Velocity) {
          if (mask & SnapField.Absolute) {
            entry.vel = dequantVel(r.i16(), r.i16(), r.i16());
          } else {
            const [bx, by, bz] = base?.vel ? quantVel(base.vel) : [0, 0, 0];
            entry.vel = dequantVel(bx + r.varint(), by + r.varint(), bz + r.varint());
          }
        }
        if (mask & SnapField.Health) entry.health = r.varuint();
        if (mask & SnapField.Flags) entry.flags = r.u8();
        if (mask & SnapField.Race) {
          entry.lap = r.u8();
          entry.cp = r.u8();
        }
        if (mask & SnapField.Speed) entry.speed = r.varuint();
        entries.push(entry);
      }
      return { op, tick, baselineTick, entries };
    }
    case Op.PlayerJoin:
      return {
        op,
        player: {
          id: r.varuint(),
          name: r.string(),
          vehicle: r.string(),
          skin: r.u8(),
          ready: r.u8() === 1,
        },
      };
    case Op.PlayerLeave:
      return { op, id: r.varuint(), reason: r.u8() };
    case Op.ChatMsg:
      return {
        op,
        senderId: r.varuint(),
        channel: r.u8(),
        name: r.string(),
        text: r.string(),
        tick: r.varuint(),
      };
    case Op.Event:
      return {
        op,
        event: r.u8(),
        actorId: r.varuint(),
        targetId: r.varuint(),
        value: r.varint(),
        pos: rVec(r),
      };
    case Op.RaceState: {
      const phase = r.u8();
      const timeMs = r.varuint();
      const lap = r.u8();
      const totalLaps = r.u8();
      const countdownMs = r.varuint();
      const count = r.varuint();
      const standings = [];
      for (let i = 0; i < count; i++) {
        standings.push({
          id: r.varuint(),
          lap: r.u8(),
          cp: r.u8(),
          dist: r.varuint(),
          finished: r.u8() === 1,
          finishTimeMs: r.varuint(),
          bestLapMs: r.varuint(),
        });
      }
      return { op, phase, timeMs, lap, totalLaps, countdownMs, standings };
    }
    case Op.Correction:
      return {
        op,
        seq: r.varuint(),
        reason: r.u8(),
        pos: rVec(r),
        rot: rQuat(r),
        vel: rVec(r),
      };
    case Op.Pong:
      return { op, nonce: r.varuint(), tick: r.varuint(), clientTimeMs: r.varuint() };
    case Op.Error:
      return { op, code: r.u8(), message: r.string() };
    case Op.RoomListResult: {
      const count = r.varuint();
      const rooms = [];
      for (let i = 0; i < count; i++) {
        rooms.push({
          id: r.string(),
          mode: r.u8() as 0 | 1,
          world: r.u8(),
          track: r.u8(),
          players: r.varuint(),
          maxPlayers: r.varuint(),
          phase: r.u8(),
          joinable: r.u8() === 1,
        });
      }
      return { op, rooms };
    }
    default:
      throw new ProtocolError(`unknown server opcode 0x${op.toString(16)}`);
  }
}

export { PROTOCOL_VERSION };
