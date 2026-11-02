import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import type { AddressInfo } from 'node:net';
import { WebSocket } from 'ws';

import {
  Op,
  decodeClientText,
  decodeServerMessage,
  decodeServerText,
  encodeClientMessage,
  encodeClientText,
  encodeServerMessage,
} from '@br4mp/protocol';
import type { ClientMessage, ServerMessage, SnapshotMsg } from '@br4mp/protocol';
import { createApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import type { App } from '../src/app.js';

const config = { ...loadConfig(), fillWithBots: false, httpPort: 0 };

const apps: App[] = [];
const sockets: WebSocket[] = [];
async function startApp(): Promise<{ app: App; port: number }> {
  const app = createApp(config, 'test');
  apps.push(app);
  await new Promise<void>((resolve) => app.server.listen(0, '127.0.0.1', resolve));
  app.game.start();
  const port = (app.server.address() as AddressInfo).port;
  return { app, port };
}

after(() => {
  for (const socket of sockets) {
    try {
      socket.terminate();
    } catch {
      /* ignore */
    }
  }
  for (const app of apps) {
    app.game.stop();
    app.wss.close();
    app.server.close();
  }
});

function wsClient(port: number) {
  const socket = new WebSocket(`ws://127.0.0.1:${port}/mp/ws`);
  sockets.push(socket);
  const messages: ServerMessage[] = [];
  socket.on('message', (data: Buffer, isBinary: boolean) => {
    if (isBinary) messages.push(decodeServerMessage(new Uint8Array(data)));
    else {
      const text = data.toString();
      if (text.startsWith('{')) return; // greeting
      messages.push(...decodeServerText(text));
    }
  });
  const waitOpen = new Promise<void>((resolve) => socket.once('open', () => resolve()));
  return {
    socket,
    messages,
    waitOpen,
    send(msg: ClientMessage) {
      socket.send(encodeClientMessage(msg));
    },
    sendText(msg: ClientMessage) {
      socket.send(encodeClientText(msg));
    },
    async waitFor<T extends ServerMessage['op']>(
      op: T,
      predicate: (msg: Extract<ServerMessage, { op: T }>) => boolean = () => true,
      timeout = 2500,
    ): Promise<Extract<ServerMessage, { op: T }>> {
      const deadline = Date.now() + timeout;
      for (;;) {
        const found = messages.find(
          (m) => m.op === op && predicate(m as Extract<ServerMessage, { op: T }>),
        );
        if (found) return found as Extract<ServerMessage, { op: T }>;
        if (Date.now() > deadline) throw new Error(`timeout waiting for op 0x${op.toString(16)}`);
        await new Promise((r) => setTimeout(r, 15));
      }
    },
    close() {
      socket.close();
    },
  };
}

test('websocket transport: connect, join, play, chat', async () => {
  const { port } = await startApp();
  const alice = wsClient(port);
  await alice.waitOpen;
  alice.send({
    op: Op.Connect,
    protocolVersion: 1,
    clientVersion: 'test',
    name: 'Alice',
    vehicle: 'PlayerCar',
    skin: 0,
    resumeToken: '',
  });
  const welcome = await alice.waitFor(Op.Welcome);
  assert.ok(welcome.playerId > 0);
  assert.ok(welcome.resumeToken.length > 4);

  alice.send({
    op: Op.Join,
    mode: 0,
    world: 0,
    track: 0,
    trackId: '',
    roomCode: '',
    maxPlayers: 32,
  });
  const joined = await alice.waitFor(Op.Joined);
  assert.match(joined.roomId, /roam/);
  assert.equal(joined.mode, 0);

  const bob = wsClient(port);
  await bob.waitOpen;
  bob.send({
    op: Op.Connect,
    protocolVersion: 1,
    clientVersion: 'test',
    name: 'Bob',
    vehicle: 'Bullet350',
    skin: 1,
    resumeToken: '',
  });
  await bob.waitFor(Op.Welcome);
  bob.send({ op: Op.Join, mode: 0, world: 0, track: 0, trackId: '', roomCode: '', maxPlayers: 32 });
  await bob.waitFor(Op.Joined);

  const spawn = { x: 985, y: 791, z: 21 };
  alice.send({
    op: Op.State,
    seq: 1,
    ackTick: 0,
    pos: spawn,
    rot: { x: 0, y: 0, z: 0, w: 1 },
    vel: { x: 0, y: 0, z: 0 },
    health: 100,
    lap: 0,
    cp: 0,
    speed: 0,
    flags: 0,
  });
  await new Promise((r) => setTimeout(r, 120));
  alice.send({ op: Op.Chat, channel: 0, text: 'hello from the harness' });
  const chat = await bob.waitFor(Op.ChatMsg, (m) => m.text === 'hello from the harness');
  assert.equal(chat.text, 'hello from the harness');
  assert.equal(chat.name, 'Alice');

  const snapshot = (await alice.waitFor(Op.Snapshot)) as SnapshotMsg;
  assert.ok(snapshot.entries.length > 0);
  alice.close();
  bob.close();
});

test('websocket text profile works for Lingo-style clients', async () => {
  const { port } = await startApp();
  const client = wsClient(port);
  await client.waitOpen;
  client.sendText({
    op: Op.Connect,
    protocolVersion: 1,
    clientVersion: 'shockwave',
    name: 'Lingo',
    vehicle: 'PlayerCar',
    skin: 0,
    resumeToken: '',
  });
  const welcome = await client.waitFor(Op.Welcome);
  assert.ok(welcome.resumeToken);
  client.sendText({ op: Op.Join, mode: 0, world: 0, track: 0, trackId: '', roomCode: '', maxPlayers: 32 });
  await client.waitFor(Op.Joined);
  client.sendText({ op: Op.Chat, channel: 0, text: 'text profile hi' });
  const chat = await client.waitFor(Op.ChatMsg, (m) => m.text === 'text profile hi');
  assert.equal(chat.name, 'Lingo');
  client.close();
});

test('http long-poll transport: connect + turn cycle (Shockwave path)', async () => {
  const { port } = await startApp();
  const base = `http://127.0.0.1:${port}`;
  const connectResponse = await fetch(
    `${base}/mp/connect?name=Poll&veh=PlayerCar&sk=0&m=0&w=0&cv=lingo`,
  );
  const connectBody = await connectResponse.text();
  const connectMsgs = decodeServerText(connectBody);
  const welcome = connectMsgs.find((m) => m.op === Op.Welcome);
  const joined = connectMsgs.find((m) => m.op === Op.Joined);
  assert.ok(welcome, `expected welcome in:\n${connectBody.slice(0, 400)}`);
  assert.ok(joined, 'expected joined');
  const token = (welcome as Extract<ServerMessage, { op: typeof Op.Welcome }>).resumeToken;

  const turn1 = await fetch(
    `${base}/mp/turn?token=${encodeURIComponent(token)}&wait=1&d=${encodeURIComponent(
      encodeClientText({ op: Op.Chat, channel: 0, text: 'turn based hello' }),
    )}`,
  );
  const body1 = await turn1.text();
  const msgs1 = decodeServerText(body1);
  const myChat = msgs1.find((m) => m.op === Op.ChatMsg && m.text === 'turn based hello');
  assert.ok(myChat, `expected chat echo in:\n${body1.slice(0, 400)}`);

  const stateLine = encodeClientText({
    op: Op.State,
    seq: 1,
    ackTick: 0,
    pos: { x: 985.5, y: 791.3, z: 21 },
    rot: { x: 0, y: 0, z: 0, w: 1 },
    vel: { x: 0, y: 0, z: 0 },
    health: 100,
    lap: 0,
    cp: 0,
    speed: 0,
    flags: 0,
  });
  const turn2 = await fetch(
    `${base}/mp/turn?token=${encodeURIComponent(token)}&wait=1&d=${encodeURIComponent(stateLine)}`,
  );
  const body2 = await turn2.text();
  const snaps = decodeServerText(body2).filter((m) => m.op === Op.Snapshot);
  assert.ok(snaps.length > 0, `expected a snapshot, got:\n${body2.slice(0, 400)}`);
  const snap = snaps[0] as SnapshotMsg;
  const mine = snap.entries.find((e) => e.id === welcome.playerId);
  assert.ok(mine, 'own state must be echoed');
  assert.ok(mine.pos && Math.abs(mine.pos.x - 985.5) < 0.5);

  const health = await fetch(`${base}/health`);
  const healthJson = (await health.json()) as { ok: boolean; rooms: unknown[] };
  assert.ok(healthJson.ok);
  assert.ok(Array.isArray(healthJson.rooms));
});

test('static assets and catalog are served to the harness', async () => {
  const { port } = await startApp();
  const base = `http://127.0.0.1:${port}`;
  const html = await fetch(`${base}/`).then((r) => r.text());
  assert.match(html, /BURNIN'/);
  const app = await fetch(`${base}/src/app.js`).then((r) => r.text());
  assert.match(app, /new Net\(/);
  const protocol = await fetch(`${base}/lib/protocol/src/index.js`);
  assert.equal(protocol.status, 200);
  const world = (await fetch(`${base}/data/worlds/city.json`).then((r) => r.json())) as {
    world: string;
    markers: unknown[];
  };
  assert.equal(world.world, 'City');
  assert.ok(world.markers.length > 10);
  const catalog = (await fetch(`${base}/api/catalog`).then((r) => r.json())) as { tracks: unknown[] };
  assert.ok(catalog.tracks.length >= 4);
});
