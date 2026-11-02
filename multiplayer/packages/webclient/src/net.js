import {
  Op,
  decodeServerMessage,
  encodeClientMessage,
} from '/lib/protocol/src/index.js';

/**
 * Thin WebSocket transport for the reference client.
 * Binary profile, 20 Hz state uplink, automatic resume on drop.
 */
export class Net {
  constructor(handlers) {
    this.handlers = handlers;
    this.socket = null;
    this.welcome = null;
    this.lastSnapshotTick = 0;
    this.pingMs = 0;
    this.token = '';
    this.queue = [];
    this.reconnectTimer = null;
    this.closedByUser = false;
    this.baselines = new Map();
    this.rttSamples = [];
    this.sentBytes = 0;
    this.receivedBytes = 0;
  }

  get connected() {
    return this.socket && this.socket.readyState === WebSocket.OPEN && this.welcome;
  }

  get playerId() {
    return this.welcome?.playerId ?? 0;
  }

  connect(profile, urlOverride) {
    this.closedByUser = false;
    this.profile = profile;
    this.url = urlOverride ?? this.url;
    const url =
      urlOverride ??
      (typeof location === 'undefined'
        ? 'ws://localhost:8080/mp/ws'
        : `${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.host}/mp/ws`);
    const socket = new WebSocket(url);
    socket.binaryType = 'arraybuffer';
    this.socket = socket;

    socket.addEventListener('open', () => {
      this.send({
        op: Op.Connect,
        protocolVersion: 1,
        clientVersion: 'web-harness/1.0',
        name: profile.name,
        vehicle: profile.vehicle,
        skin: profile.skin ?? 0,
        resumeToken: this.token,
      });
      this.send({
        op: Op.Join,
        mode: profile.mode,
        world: profile.world,
        track: profile.track ?? 0,
        trackId: profile.trackId ?? '',
        roomCode: profile.roomCode ?? '',
        maxPlayers: 32,
      });
      this.flushQueue();
    });

    socket.addEventListener('message', (event) => {
      if (typeof event.data === 'string') {
        // server greeting / errors as JSON text
        try {
          const info = JSON.parse(event.data);
          if (info && info.hello) return;
        } catch {
          /* not JSON: ignore */
        }
        return;
      }
      const bytes = new Uint8Array(event.data);
      this.receivedBytes += bytes.length;
      let msg;
      try {
        msg = decodeServerMessage(bytes, (id) => this.baselines.get(id));
      } catch (err) {
        console.warn('undecodable message', err);
        return;
      }
      if (msg.op === Op.Welcome) {
        this.welcome = msg;
        this.token = msg.resumeToken;
        this.flushQueue();
      }
      if (msg.op === Op.Snapshot) {
        this.lastSnapshotTick = Math.max(this.lastSnapshotTick, msg.tick);
      }
      this.handlers.message?.(msg);
    });

    socket.addEventListener('close', () => {
      this.handlers.status?.('disconnected');
      if (!this.closedByUser) this.scheduleReconnect(this.profile ?? profile);
    });
    socket.addEventListener('error', () => {
      /* close handles it */
    });
  }

  scheduleReconnect(profile) {
    if (this.reconnectTimer) return;
    this.handlers.status?.('reconnecting');
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      this.connect(profile, this.url);
    }, 1500);
  }

  close() {
    this.closedByUser = true;
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    this.socket?.close(1000, 'bye');
  }

  flushQueue() {
    const queue = this.queue;
    this.queue = [];
    for (const msg of queue) this.send(msg);
  }

  send(msg) {
    const ephemeral = msg.op === Op.State || msg.op === Op.Input || msg.op === Op.Ping;
    const ready = this.socket && this.socket.readyState === WebSocket.OPEN;
    if (!ready || (msg.op !== Op.Connect && !this.welcome)) {
      if (!ephemeral) this.queue.push(msg);
      return;
    }
    try {
      const bytes = encodeClientMessage(msg);
      this.sentBytes += bytes.length;
      this.socket.send(bytes);
    } catch (err) {
      console.warn('send failed', err);
    }
  }

  sendState(state) {
    this.baselines.set(this.playerId, {
      id: this.playerId,
      mask: 0,
      pos: state.pos,
      vel: state.vel,
      rot: state.rot,
    });
    this.send({
      op: Op.State,
      seq: state.seq,
      ackTick: this.lastSnapshotTick,
      pos: state.pos,
      rot: state.rot,
      vel: state.vel,
      health: Math.round(state.health),
      lap: state.lap,
      cp: state.cp,
      speed: Math.round(state.speed),
      flags: state.flags,
    });
  }

  ping() {
    if (!this.connected) return;
    this.pingSentAt = Date.now();
    this.send({ op: Op.Ping, nonce: (Math.random() * 1e6) | 0, clientTimeMs: Date.now() });
  }

  /**
   * Merge a snapshot into the per-entity mirror the server keeps on our behalf.
   * Deltas were encoded against this same mirror, so it must be updated after
   * every entry (absolute values for self, merged fields for everyone else).
   */
  applySnapshot(msg) {
    const updates = [];
    for (const entry of msg.entries) {
      const prev = this.baselines.get(entry.id);
      const merged = {
        id: entry.id,
        mask: entry.mask,
        pos: entry.pos ?? prev?.pos,
        rot: entry.rot ?? prev?.rot,
        vel: entry.vel ?? prev?.vel,
        health: entry.health ?? prev?.health,
        flags: entry.flags ?? prev?.flags,
        lap: entry.lap ?? prev?.lap,
        cp: entry.cp ?? prev?.cp,
        speed: entry.speed ?? prev?.speed,
      };
      this.baselines.set(entry.id, merged);
      updates.push(merged);
    }
    return updates;
  }

  onPong(sentAt) {
    const rtt = Date.now() - sentAt;
    this.rttSamples.push(rtt);
    if (this.rttSamples.length > 8) this.rttSamples.shift();
    this.pingMs = Math.round(this.rttSamples.reduce((a, b) => a + b, 0) / this.rttSamples.length);
  }
}
