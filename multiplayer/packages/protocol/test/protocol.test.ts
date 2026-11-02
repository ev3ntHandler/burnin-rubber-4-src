import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  Op,
  SnapField,
  decodeClientMessage,
  decodeClientText,
  decodeServerMessage,
  decodeServerText,
  encodeClientMessage,
  encodeClientText,
  encodeServerMessage,
  encodeServerText,
  packQuat,
  unpackQuat,
  quantPos,
  dequantPos,
} from '../src/index.js';
import type { ClientMessage, ServerMessage, SnapshotEntry } from '../src/index.js';

const near = (a: number, b: number, eps: number, label = '') =>
  assert.ok(Math.abs(a - b) <= eps, `${label} expected ${b} ±${eps} got ${a}`);

function quatClose(
  got: { x: number; y: number; z: number; w: number },
  want: { x: number; y: number; z: number; w: number },
  eps = 0.003,
) {
  // q and -q are the same rotation
  const dot = got.x * want.x + got.y * want.y + got.z * want.z + got.w * want.w;
  const sign = dot < 0 ? -1 : 1;
  near(got.x * sign, want.x, eps, 'qx');
  near(got.y * sign, want.y, eps, 'qy');
  near(got.z * sign, want.z, eps, 'qz');
  near(got.w * sign, want.w, eps, 'qw');
}

test('quaternion packing round-trips within 0.5 degrees', () => {
  let seed = 12345;
  const rand = () => {
    seed = (seed * 1664525 + 1013904223) % 4294967296;
    return seed / 4294967296;
  };
  for (let i = 0; i < 2000; i++) {
    const q = { x: rand() * 2 - 1, y: rand() * 2 - 1, z: rand() * 2 - 1, w: rand() * 2 - 1 };
    const len = Math.hypot(q.x, q.y, q.z, q.w) || 1;
    q.x /= len;
    q.y /= len;
    q.z /= len;
    q.w /= len;
    quatClose(unpackQuat(packQuat(q)), q);
  }
});

test('position quantisation is within 2cm', () => {
  const p = { x: 1234.5678, y: -45.678, z: 0.123 };
  const back = dequantPos(...quantPos(p));
  near(back.x, p.x, 0.02);
  near(back.y, p.y, 0.02);
  near(back.z, p.z, 0.02);
});

test('binary client messages round-trip', () => {
  const messages: ClientMessage[] = [
    {
      op: Op.Connect,
      protocolVersion: 1,
      clientVersion: '1.0.0',
      name: 'Räikkönen',
      vehicle: 'PhaserGTI',
      skin: 2,
      resumeToken: 'abc123',
    },
    { op: Op.Join, mode: 1, world: 0, track: 3, trackId: 'city-1', roomCode: 'ABCD', maxPlayers: 12 },
    { op: Op.Input, seq: 42, ackTick: 400, buttons: 0b1001, steer: -7, clientTimeMs: 123456 },
    {
      op: Op.State,
      seq: 99,
      ackTick: 401,
      flags: 0b1010,
      pos: { x: 100.5, y: -20.25, z: 3.125 },
      rot: { x: 0, y: 0.7071, z: 0, w: 0.7071 },
      vel: { x: 12.5, y: 0, z: -3.25 },
      health: 88,
      lap: 2,
      cp: 5,
      speed: 143,
    },
    { op: Op.Chat, channel: 0, text: 'gg <script>alert(1)</script>' },
    { op: Op.Ping, nonce: 7, clientTimeMs: 999 },
    { op: Op.Ready, ready: true },
    {
      op: Op.Action,
      action: 3,
      target: 12,
      arg: -1,
      pos: { x: 1, y: 2, z: 3 },
    },
    {
      op: Op.Hit,
      targetId: 4,
      weapon: 1,
      pos: { x: 9, y: 8, z: 7 },
      clientTimeMs: 555,
      damage: 22,
    },
    { op: Op.SetVehicle, vehicle: 'Bullet350', skin: 1 },
    { op: Op.Leave },
    { op: Op.RoomList, mode: 1 },
  ];
  for (const msg of messages) {
    const decoded = decodeClientMessage(encodeClientMessage(msg));
    if (msg.op === Op.State) {
      assert.equal(decoded.op, Op.State);
      const d = decoded as Extract<ClientMessage, { op: typeof Op.State }>;
      near(d.pos.x, msg.pos.x, 0.02);
      near(d.speed, msg.speed, 0.001);
      assert.equal(d.health, msg.health);
      assert.equal(d.lap, msg.lap);
      assert.equal(d.cp, msg.cp);
      assert.equal(d.flags, msg.flags);
      quatClose(d.rot, msg.rot, 0.01);
    } else {
      assert.deepEqual(decoded, msg);
    }
  }
});

test('binary snapshots honour delta baselines', () => {
  const baseline = new Map<number, SnapshotEntry>([
    [1, { id: 1, mask: SnapField.Position, pos: { x: 100, y: 200, z: 300 } }],
  ]);
  const entries: SnapshotEntry[] = [
    { id: 1, mask: SnapField.Position | SnapField.Rotation | SnapField.Speed, pos: { x: 100.2, y: 200.1, z: 300 }, rot: { x: 0, y: 0, z: 0, w: 1 }, speed: 55 },
    { id: 2, mask: SnapField.Position | SnapField.Absolute, pos: { x: -10, y: 0, z: 4 } },
  ];
  const msg: ServerMessage = { op: Op.Snapshot, tick: 10, baselineTick: 9, entries };
  const bytes = encodeServerMessage(msg, (id) => baseline.get(id));
  // delta encoding of a tiny movement should keep the packet small
  assert.ok(bytes.length < 60, `snapshot too big: ${bytes.length} bytes`);

  const decoded = decodeServerMessage(bytes, (id) => baseline.get(id));
  assert.equal(decoded.op, Op.Snapshot);
  const snap = decoded as Extract<ServerMessage, { op: typeof Op.Snapshot }>;
  assert.equal(snap.tick, 10);
  assert.equal(snap.baselineTick, 9);
  near(snap.entries[0].pos!.x, 100.2, 0.04);
  near(snap.entries[1].pos!.x, -10, 0.04);
  assert.equal(snap.entries[0].speed, 55);
});

test('text profile round-trips client messages', () => {
  const msgs: ClientMessage[] = [
    {
      op: Op.Connect,
      protocolVersion: 1,
      clientVersion: '1.0.0',
      name: 'Dirk',
      vehicle: 'PlayerCar',
      skin: 0,
      resumeToken: '',
    },
    { op: Op.Chat, channel: 0, text: 'hello |, world' },
    {
      op: Op.State,
      seq: 5,
      ackTick: 6,
      flags: 0,
      pos: { x: 1.5, y: 2, z: 3 },
      rot: { x: 0, y: 0, z: 0, w: 1 },
      vel: { x: 0, y: 0, z: 0 },
      health: 100,
      lap: 1,
      cp: 2,
      speed: 12,
    },
    { op: Op.Action, action: 0, target: 0, arg: 0, pos: { x: 0, y: 0, z: 0 } },
  ];
  const text = msgs.map(encodeClientText).join('\n');
  const back = decodeClientText(text);
  assert.equal(back.length, msgs.length);
  assert.equal(back[0].op, Op.Connect);
  assert.equal((back[0] as Extract<ClientMessage, { op: typeof Op.Connect }>).name, 'Dirk');
  assert.equal((back[1] as Extract<ClientMessage, { op: typeof Op.Chat }>).text, 'hello |, world');
});

test('text profile round-trips snapshot + race state + room list', () => {
  const msgs: ServerMessage[] = [
    {
      op: Op.Welcome,
      playerId: 3,
      serverTick: 100,
      tickRate: 20,
      snapshotRate: 20,
      resumeToken: 'tok',
      serverName: 'Frankfurt #1',
    },
    {
      op: Op.Joined,
      roomId: 'city-fr-1',
      mode: 1,
      world: 0,
      track: 2,
      totalLaps: 3,
      trackId: 'city-1',
      startTick: 140,
      players: [{ id: 3, name: 'Fox', vehicle: 'PlayerCar', skin: 1, ready: true }],
    },
    {
      op: Op.Snapshot,
      tick: 101,
      baselineTick: 100,
      entries: [
        {
          id: 3,
          mask: SnapField.Position | SnapField.Rotation | SnapField.Race | SnapField.Health,
          pos: { x: 12.34, y: -5.6, z: 7.8 },
          rot: { x: 0.1, y: 0.2, z: 0.3, w: 0.927 },
          lap: 1,
          cp: 4,
          health: 77,
        },
      ],
    },
    {
      op: Op.RaceState,
      phase: 2,
      timeMs: 61000,
      lap: 2,
      totalLaps: 3,
      countdownMs: 0,
      standings: [
        { id: 3, lap: 2, cp: 1, dist: 42, finished: false, finishTimeMs: 0, bestLapMs: 58900 },
      ],
    },
    {
      op: Op.RoomListResult,
      rooms: [
        { id: 'a', mode: 0, world: 0, track: 0, players: 4, maxPlayers: 32, phase: 0, joinable: true },
      ],
    },
    { op: Op.ChatMsg, senderId: 3, channel: 0, name: 'Fox', text: 'yo', tick: 5 },
    { op: Op.Error, code: 5, message: 'Room is full.' },
  ];

  const lines: string[] = [];
  for (const m of msgs) lines.push(...encodeServerText(m));
  const back = decodeServerText(lines.join('\n'));

  assert.equal(back.length, msgs.length, `got ${back.map((m) => m.op).join(',')}`);
  const snap = back.find((m) => m.op === Op.Snapshot) as Extract<ServerMessage, { op: typeof Op.Snapshot }>;
  assert.equal(snap.entries.length, 1);
  near(snap.entries[0].pos!.x, 12.34, 0.01);
  assert.equal(snap.entries[0].health, 77);
  const rs = back.find((m) => m.op === Op.RaceState) as Extract<ServerMessage, { op: typeof Op.RaceState }>;
  assert.equal(rs.standings[0].bestLapMs, 58900);
  const joined = back.find((m) => m.op === Op.Joined) as Extract<ServerMessage, { op: typeof Op.Joined }>;
  assert.equal(joined.players.length, 1);
  assert.equal(joined.players[0].name, 'Fox');
  const rooms = back.find((m) => m.op === Op.RoomListResult) as Extract<
    ServerMessage,
    { op: typeof Op.RoomListResult }
  >;
  assert.equal(rooms.rooms[0].id, 'a');
});

test('unknown text tags are ignored, malformed lines do not throw', () => {
  const parsed = decodeClientText('WHAT|a=1\n\nCHAT|ch=0,x=ok\nBROKEN|');
  assert.equal(parsed.length, 1);
  assert.equal(parsed[0].op, Op.Chat);
});
