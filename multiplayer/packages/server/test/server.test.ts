import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  ChatChannel as ChatCh,
  ErrorCode,
  EventId,
  Mode,
  Op,
  RacePhase,
  SnapField,
} from '@br4mp/protocol';
import type { ClientMessage, ServerMessage, SnapshotMsg } from '@br4mp/protocol';
import { GameServer } from '../src/gameServer.js';
import { FreeRoamRoom } from '../src/freeRoam.js';
import { RaceRoom } from '../src/race.js';
import type { Connection } from '../src/types.js';
import { loadConfig } from '../src/config.js';

class FakeConnection implements Connection {
  readonly kind = 'ws' as const;
  readonly remote = 'test';
  messages: ServerMessage[] = [];
  closed = false;
  send(msg: ServerMessage): void {
    this.messages.push(msg);
  }
  close(): void {
    this.closed = true;
  }
  isOpen(): boolean {
    return !this.closed;
  }
  take<T extends ServerMessage['op']>(op: T): Array<Extract<ServerMessage, { op: T }>> {
    const out = this.messages.filter((m) => m.op === op) as Array<Extract<ServerMessage, { op: T }>>;
    this.messages = this.messages.filter((m) => m.op !== op);
    return out;
  }
  clear(): void {
    this.messages = [];
  }
}

function testConfig(overrides: Record<string, unknown> = {}) {
  return {
    ...loadConfig(),
    fillWithBots: false,
    botsPerRace: 0,
    warmRoomsPerWorld: 1,
    ...overrides,
  };
}

function connect(game: GameServer, name: string, vehicle = 'PlayerCar') {
  const conn = new FakeConnection();
  const session = game.connect(conn, {
    op: Op.Connect,
    protocolVersion: 1,
    clientVersion: 'test',
    name,
    vehicle,
    skin: 0,
    resumeToken: '',
  });
  assert.ok(!('error' in session), 'connect failed');
  game.welcome(session);
  return { conn, session };
}

function join(game: GameServer, session: ReturnType<typeof connect>['session'], mode: number, world = 0) {
  game.join(session, { op: Op.Join, mode: mode as 0 | 1, world, track: 0, trackId: '', roomCode: '', maxPlayers: 32 });
  return session.room!;
}

function send(game: GameServer, session: ReturnType<typeof connect>['session'], msg: ClientMessage) {
  game.handle(session, msg);
}

/** First state from a client: adopt the authoritative spawn, as real clients do. */
function syncSpawn(game: GameServer, session: ReturnType<typeof connect>['session'], room: { players: Map<number, { pos: { x: number; y: number; z: number } }> }) {
  const player = room.players.get(session.id);
  if (!player) return;
  send(game, session, state({ ...player.pos }, 1));
  tickN(game, 1);
}

function tickN(game: GameServer, n: number) {
  for (let i = 0; i < n; i++) game.tick();
}

function state(
  pos: { x: number; y: number; z: number },
  seq: number,
  extra: Partial<Extract<ClientMessage, { op: typeof Op.State }>> = {},
): Extract<ClientMessage, { op: typeof Op.State }> {
  return {
    op: Op.State,
    seq,
    ackTick: 0,
    pos,
    rot: { x: 0, y: 0, z: 0, w: 1 },
    vel: { x: 0, y: 0, z: 0 },
    health: 100,
    lap: 0,
    cp: 0,
    speed: 0,
    flags: 0,
    ...extra,
  };
}

test('connect, join free roam and exchange snapshots', () => {
  const game = new GameServer(testConfig());
  const alice = connect(game, 'Alice');
  const bob = connect(game, 'Bob');
  const room = join(game, alice.session, Mode.FreeRoam, 0) as FreeRoamRoom;
  join(game, bob.session, Mode.FreeRoam, 0);

  const joined = alice.conn.take(Op.Joined);
  assert.equal(joined.length, 1);
  assert.equal(joined[0].roomId, room.id);
  assert.equal(bob.conn.take(Op.Joined).length, 1);

  syncSpawn(game, alice.session, room);
  syncSpawn(game, bob.session, room);
  const spawn = room.players.get(alice.session.id)!.pos;
  send(game, bob.session, state({ x: spawn.x + 20, y: spawn.y + 10, z: spawn.z }, 2));
  alice.conn.clear();
  tickN(game, 3);

  const snaps = alice.conn.take(Op.Snapshot);
  assert.ok(snaps.length > 0, 'expected snapshots');
  const entries = snaps.flatMap((s) => s.entries);
  assert.ok(entries.some((e) => e.id === bob.session.id), 'bob should be visible');
  const bobEntry = entries.find((e) => e.id === bob.session.id)!;
  assert.ok((bobEntry.mask & SnapField.Absolute) === 0, 'remote entries are deltas');
  assert.ok(Math.abs(bobEntry.pos!.x - (spawn.x + 20)) < 1, 'bob position is authoritative');

  // moving locally echoes our own authoritative state back
  alice.conn.clear();
  send(game, alice.session, state({ x: spawn.x + 1, y: spawn.y, z: spawn.z }, 2));
  tickN(game, 1);
  const selfEntry = alice.conn
    .take(Op.Snapshot)
    .flatMap((s) => s.entries)
    .find((e) => e.id === alice.session.id);
  assert.ok(selfEntry, 'own state echoed');
  assert.ok((selfEntry!.mask & SnapField.Absolute) !== 0, 'own entry must be absolute');
});

test('interest management hides players outside the vision radius', () => {
  const game = new GameServer(testConfig());
  const alice = connect(game, 'Alice');
  const bob = connect(game, 'Bob');
  const room = join(game, alice.session, Mode.FreeRoam, 0) as FreeRoamRoom;
  join(game, bob.session, Mode.FreeRoam, 0);
  syncSpawn(game, alice.session, room);
  syncSpawn(game, bob.session, room);
  const spawn = room.players.get(alice.session.id)!.pos;
  send(game, bob.session, state({ x: spawn.x + 900, y: spawn.y + 900, z: spawn.z }, 2));
  alice.conn.clear();
  tickN(game, 2);
  const ids = alice.conn
    .take(Op.Snapshot)
    .flatMap((s) => s.entries)
    .map((e) => e.id);
  assert.ok(!ids.includes(bob.session.id), 'far player must be culled');
});

test('chat is broadcast, sanitised and rate limited', () => {
  const game = new GameServer(testConfig());
  const alice = connect(game, 'Alice');
  const bob = connect(game, 'Bob');
  join(game, alice.session, Mode.FreeRoam, 0);
  join(game, bob.session, Mode.FreeRoam, 0);
  bob.conn.clear();

  send(game, alice.session, { op: Op.Chat, channel: ChatCh.All, text: '  hello \u0007 world  ' });
  const chats = bob.conn.take(Op.ChatMsg);
  assert.equal(chats.length, 1);
  assert.equal(chats[0].text, 'hello world');
  assert.equal(chats[0].name, 'Alice');

  alice.conn.clear();
  for (let i = 0; i < 12; i++) {
    send(game, alice.session, { op: Op.Chat, channel: ChatCh.All, text: `spam ${i}` });
  }
  assert.ok(alice.conn.take(Op.Error).some((e) => e.code === ErrorCode.RateLimited), 'spam should be throttled');
});

test('anti-cheat rejects teleports with a correction', () => {
  const game = new GameServer(testConfig());
  const alice = connect(game, 'Alice');
  join(game, alice.session, Mode.FreeRoam, 0);
  const room = alice.session.room!;
  syncSpawn(game, alice.session, room);
  const spawn = room.players.get(alice.session.id)!.pos;
  alice.conn.clear();
  send(game, alice.session, state({ x: spawn.x + 900, y: spawn.y, z: spawn.z }, 2));
  const corrections = alice.conn.take(Op.Correction);
  assert.equal(corrections.length, 1);
  const player = room.players.get(alice.session.id)!;
  assert.ok(Math.abs(player.pos.x - spawn.x) < 1, 'position must not jump');
  assert.ok(player.strikes >= 1);
});

test('pickups are arbitrated by the server, then respawn', () => {
  const game = new GameServer(testConfig());
  const alice = connect(game, 'Alice');
  const bob = connect(game, 'Bob');
  const room = join(game, alice.session, Mode.FreeRoam, 0) as FreeRoamRoom;
  join(game, bob.session, Mode.FreeRoam, 0);
  syncSpawn(game, alice.session, room);
  syncSpawn(game, bob.session, room);
  const pickup = room.pickupSnapshot()[0];
  assert.ok(pickup, 'world data must provide pickups');

  // move the player next to the pickup (server side teleport = respawn path)
  const alicePlayer = room.players.get(alice.session.id)!;
  room.teleport(alicePlayer, pickup.pos, alicePlayer.rot, 1);
  send(game, alice.session, state({ ...pickup.pos }, 2));
  tickN(game, 1);
  alice.conn.clear();
  bob.conn.clear();
  send(game, alice.session, { op: Op.Action, action: 4, target: 0, arg: pickup.index, pos: pickup.pos });
  const taken = bob.conn.take(Op.Event).filter((e) => e.event === EventId.PickupTaken);
  assert.equal(taken.length, 1);
  assert.equal(taken[0].actorId, alice.session.id);

  // a second player cannot grab the same pickup
  const bobPlayer = room.players.get(bob.session.id)!;
  room.teleport(bobPlayer, pickup.pos, bobPlayer.rot, 1);
  send(game, bob.session, state({ ...pickup.pos }, 2));
  tickN(game, 1);
  bob.conn.clear();
  send(game, bob.session, { op: Op.Action, action: 4, target: 0, arg: pickup.index, pos: pickup.pos });
  assert.equal(bob.conn.take(Op.Event).filter((e) => e.event === EventId.PickupTaken).length, 0);
  assert.ok(room.pickupSnapshot()[pickup.index].taken);
});

test('lag-compensated hit validation: in range hurts, out of range is rejected', () => {
  const game = new GameServer(testConfig());
  const alice = connect(game, 'Alice');
  const bob = connect(game, 'Bob');
  const room = join(game, alice.session, Mode.FreeRoam, 0) as FreeRoamRoom;
  join(game, bob.session, Mode.FreeRoam, 0);
  syncSpawn(game, alice.session, room);
  syncSpawn(game, bob.session, room);
  const spawn = room.players.get(alice.session.id)!.pos;

  send(game, bob.session, state({ x: spawn.x + 30, y: spawn.y, z: spawn.z }, 2));
  tickN(game, 4);

  // clock sync so the rewind window is sane
  send(game, alice.session, { op: Op.Ping, nonce: 1, clientTimeMs: Date.now() });
  alice.conn.clear();
  bob.conn.clear();

  send(game, alice.session, {
    op: Op.Hit,
    targetId: bob.session.id,
    weapon: 0,
    pos: { x: spawn.x + 30, y: spawn.y, z: spawn.z },
    clientTimeMs: Date.now(),
    damage: 6,
  });
  const hits = bob.conn.take(Op.Event).filter((e) => e.event === EventId.Hit);
  assert.equal(hits.length, 1, 'valid hit should register');
  assert.ok(hits[0].value > 0);

  // now claim a hit 200 m away
  send(game, alice.session, {
    op: Op.Hit,
    targetId: bob.session.id,
    weapon: 0,
    pos: { x: spawn.x + 260, y: spawn.y, z: spawn.z },
    clientTimeMs: Date.now(),
    damage: 999,
  });
  assert.equal(
    bob.conn.take(Op.Event).filter((e) => e.event === EventId.Hit).length,
    0,
    'impossible hit must be dropped',
  );
});

test('race: gate order is enforced, laps and finish are server side', () => {
  const game = new GameServer(testConfig());
  const alice = connect(game, 'Alice');
  const bob = connect(game, 'Bob');
  const room = game.findRace(0, 'city-1') as RaceRoom;
  game.enterRoom(alice.session, room);
  game.enterRoom(bob.session, room);
  room.forceStart();

  const gates = room.track.checkpoints.length;
  // skipping gates must not count
  room.debugCrossGate(alice.session.id, 5);
  assert.equal(room.players.get(alice.session.id)!.lap, 0);
  assert.equal(room.players.get(alice.session.id)!.cp, 0);

  // start line, then a full lap
  room.debugCrossGate(alice.session.id, 0);
  assert.equal(room.players.get(alice.session.id)!.cp, 0);
  for (let lap = 1; lap <= room.track.totalLaps; lap++) {
    room.debugCrossGate(alice.session.id, 1 % gates);
    for (let i = 2; i < gates; i++) room.debugCrossGate(alice.session.id, i);
    room.debugCrossGate(alice.session.id, 0);
  }
  const player = room.players.get(alice.session.id)!;
  assert.ok(player.finished, 'player should have finished');
  assert.ok(player.finishTimeMs >= 0);

  const standings = room.standings();
  assert.equal(standings[0].id, alice.session.id, 'finisher leads the standings');
  assert.equal(standings[0].finished, true);
});

test('race: sprint track finishes at its last checkpoint', () => {
  const game = new GameServer(testConfig());
  const sprint = [...game.rooms.values()];
  void sprint;
  const room = game.createRace(2, 'jungle-1-sprint');
  const alice = connect(game, 'Alice');
  game.enterRoom(alice.session, room);
  room.forceStart();
  const last = room.track.checkpoints.length - 1;
  room.debugCrossGate(alice.session.id, 0);
  for (let i = 1; i <= last; i++) room.debugCrossGate(alice.session.id, i);
  assert.equal(room.players.get(alice.session.id)!.finished, true);
});

test('reconnect resumes the same player session', () => {
  const game = new GameServer(testConfig());
  const alice = connect(game, 'Alice');
  join(game, alice.session, Mode.FreeRoam, 0);
  const token = alice.session.token;
  const playerId = alice.session.id;

  game.disconnect(alice.session);
  const conn2 = new FakeConnection();
  const resumed = game.connect(conn2, {
    op: Op.Connect,
    protocolVersion: 1,
    clientVersion: 'test',
    name: 'Alice',
    vehicle: 'PlayerCar',
    skin: 0,
    resumeToken: token,
  });
  assert.ok(!('error' in resumed));
  assert.equal(resumed.id, playerId);
  assert.equal(game.sessionCount(), 1);
});

test('protocol version mismatch is rejected', () => {
  const game = new GameServer(testConfig());
  const conn = new FakeConnection();
  const result = game.connect(conn, {
    op: Op.Connect,
    protocolVersion: 99,
    clientVersion: 'old',
    name: 'Old',
    vehicle: 'PlayerCar',
    skin: 0,
    resumeToken: '',
  });
  assert.ok('error' in result);
  assert.equal(result.error, ErrorCode.BadVersion);
});

test('room list is served over the bus', () => {
  const game = new GameServer(testConfig());
  const alice = connect(game, 'Alice');
  join(game, alice.session, Mode.FreeRoam, 0);
  alice.conn.clear();
  send(game, alice.session, { op: Op.RoomList, mode: -1 });
  const lists = alice.conn.take(Op.RoomListResult);
  assert.equal(lists.length, 1);
  assert.ok(lists[0].rooms.length >= 1);
  assert.ok(lists[0].rooms.some((r) => r.joinable));
});

test('snapshot delta compression keeps packets small at 20 players', () => {
  const game = new GameServer(testConfig());
  const alice = connect(game, 'Alice');
  const room = join(game, alice.session, Mode.FreeRoam, 0) as FreeRoamRoom;
  const spawn = room.players.get(alice.session.id)!.pos;
  const others = [];
  syncSpawn(game, alice.session, room);
  for (let i = 0; i < 19; i++) {
    const s = connect(game, `P${i}`);
    join(game, s.session, Mode.FreeRoam, 0);
    others.push(s);
    syncSpawn(game, s.session, room);
    const p = room.players.get(s.session.id)!;
    send(game, s.session, state({ x: spawn.x + 10 + i * 3, y: spawn.y + i * 2, z: p.pos.z }, 2));
  }
  tickN(game, 3);
  alice.conn.clear();
  tickN(game, 2);
  assert.equal(alice.conn.take(Op.Snapshot).length, 0, 'a frozen world is not worth a packet');

  // move one player a little: only that player's entry should go out
  const mover = room.players.get(others[0].session.id)!;
  send(game, others[0].session, state({ x: mover.pos.x + 1.5, y: mover.pos.y, z: mover.pos.z }, 5));
  alice.conn.clear();
  tickN(game, 1);
  const snaps: SnapshotMsg[] = alice.conn.take(Op.Snapshot);
  assert.equal(snaps.length, 1);
  const entries = snaps[0].entries;
  assert.equal(entries.length, 1, `expected a single delta entry, got ${entries.length}`);
  assert.equal(entries[0].id, others[0].session.id);
  assert.ok((entries[0].mask & SnapField.Position) !== 0);
  assert.ok((entries[0].mask & SnapField.Absolute) === 0, 'delta, not keyframe');
});

test('race phase machine progresses lobby -> countdown -> running', async () => {
  const game = new GameServer(testConfig());
  const alice = connect(game, 'Alice');
  const bob = connect(game, 'Bob');
  const room = game.findRace(0, 'city-1') as RaceRoom;
  game.enterRoom(alice.session, room);
  assert.equal(room.summaryPhase(), RacePhase.Lobby);
  game.enterRoom(bob.session, room);
  assert.equal(room.summaryPhase(), RacePhase.Countdown, 'second player triggers the grid');
  room.forceStart();
  assert.equal(room.summaryPhase(), RacePhase.Running);
});

test('filler bots get synthetic ids and never shadow a session', () => {
  const game = new GameServer(testConfig({ fillWithBots: true, botsPerRace: 4 }));
  const alice = connect(game, 'Alice');
  const room = game.findRace(0, 'city-1') as RaceRoom;
  game.enterRoom(alice.session, room);
  const bob = connect(game, 'Bob');
  game.enterRoom(bob.session, room);

  room.forceStart(); // spawns the lobby fillers
  const bots = [...room.players.values()].filter((p) => p.isBot);
  assert.ok(bots.length >= 1, 'expected filler bots');
  for (const bot of bots) assert.ok(bot.id >= 1_000_000, `bot id ${bot.id} must not look like a session id`);
  assert.equal(room.players.get(alice.session.id)?.name, 'Alice');
  assert.equal(room.players.get(bob.session.id)?.name, 'Bob');

  // A human state update must land on that human, not on a filler.
  syncSpawn(game, alice.session, room);
  const start = { ...room.players.get(alice.session.id)!.pos };
  const moved = { x: start.x + 3, y: start.y, z: start.z };
  send(game, alice.session, state(moved, 2));
  const alicePlayer = room.players.get(alice.session.id)!;
  assert.ok(Math.abs(alicePlayer.pos.x - moved.x) < 0.01, 'state did not apply to Alice');
  assert.equal(alicePlayer.strikes, 0);
});

test('a race room left with only bots stops being joinable and gets reaped', () => {
  const game = new GameServer(testConfig({ fillWithBots: true, botsPerRace: 2 }));
  const alice = connect(game, 'Alice');
  const bob = connect(game, 'Bob');
  const room = game.findRace(0, 'city-1') as RaceRoom;
  game.enterRoom(alice.session, room);
  game.enterRoom(bob.session, room);
  assert.ok(room.hasHumans());
  game.leaveRoom(alice.session);
  game.leaveRoom(bob.session);
  assert.equal(room.hasHumans(), false, 'only fillers should be left');
  assert.ok([...room.players.values()].every((p) => p.isBot));
});
