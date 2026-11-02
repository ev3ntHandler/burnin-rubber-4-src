/**
 * Text profile of the protocol.
 *
 * Used by the Shockwave/Lingo clients, which can only reach the network through
 * `preloadNetThing` / `getNetText` polling. Each message is one `\n` separated
 * line of `OPCODE|key=value,key=value`. Multi-part messages (snapshot, joined,
 * race state, room list) are a header line followed by detail lines, which is
 * what makes the Lingo side able to build a propList with `value()` and a few
 * string splits — no bit twiddling, no base64.
 *
 *   SN|t=1044,b=1034          header for server tick 1044, delta baseline 1034
 *   E|i=7,m=17,px=1.25,py=-3.5,pz=42
 *   E|i=9,m=1,px=100
 *
 * Every field is optional and driven by the same `SnapField` mask the binary
 * profile uses, so both transports share one code path on the server.
 */
import { Op, SnapField } from './constants.js';
import type { SnapshotEntry } from './constants.js';
import type { ClientMessage, ServerMessage } from './messages.js';

type KV = Record<string, string>;

const TAGS: Record<number, string> = {
  [Op.Connect]: 'CONNECT',
  [Op.Join]: 'JOIN',
  [Op.Input]: 'INPUT',
  [Op.State]: 'STATE',
  [Op.Chat]: 'CHAT',
  [Op.Ping]: 'PING',
  [Op.Ready]: 'READY',
  [Op.Action]: 'ACTION',
  [Op.Hit]: 'HIT',
  [Op.SetVehicle]: 'SETVEH',
  [Op.Leave]: 'LEAVE',
  [Op.RoomList]: 'ROOMLIST',
  [Op.Welcome]: 'WELCOME',
  [Op.Joined]: 'JOINED',
  [Op.Snapshot]: 'SN',
  [Op.PlayerJoin]: 'PJ',
  [Op.PlayerLeave]: 'PL',
  [Op.ChatMsg]: 'C',
  [Op.Event]: 'EV',
  [Op.RaceState]: 'RS',
  [Op.Correction]: 'COR',
  [Op.Pong]: 'PONG',
  [Op.Error]: 'ERR',
  [Op.RoomListResult]: 'RL',
};

const BY_TAG = new Map<string, number>(Object.entries(TAGS).map(([op, tag]) => [tag, Number(op)]));

/** Tags that only exist as detail lines of the preceding header line. */
const DETAIL_TAGS = new Set(['E', 'ST', 'PJ_DETAIL', 'R']);

function encStr(s: string): string {
  // encodeURIComponent escapes every protocol separator (`,`, `=`, `|`, CR/LF),
  // so free-form chat and player names can never break the framing.
  return encodeURIComponent(s);
}

function decStr(s: string): string {
  try {
    return decodeURIComponent(s);
  } catch {
    return s;
  }
}

function num(n: number, decimals = 3): string {
  if (!Number.isFinite(n)) return '0';
  const r = Number(n.toFixed(decimals));
  return String(Object.is(r, -0) ? 0 : r);
}

function pairs(...items: Array<[string, string | number | undefined]>): string {
  const parts: string[] = [];
  for (const [k, v] of items) {
    if (v === undefined) continue;
    parts.push(`${k}=${typeof v === 'number' ? num(v) : v}`);
  }
  return parts.join(',');
}

function parseKV(line: string): { tag: string; kv: KV } {
  const bar = line.indexOf('|');
  const tag = bar === -1 ? line : line.slice(0, bar);
  const kv: KV = {};
  if (bar !== -1) {
    for (const chunk of line.slice(bar + 1).split(',')) {
      if (!chunk) continue;
      const eq = chunk.indexOf('=');
      if (eq === -1) continue;
      kv[chunk.slice(0, eq)] = chunk.slice(eq + 1);
    }
  }
  return { tag, kv };
}

const f = (kv: KV, k: string, d = 0): number => {
  const raw = kv[k];
  if (raw === undefined || raw === '') return d;
  const n = Number(raw);
  return Number.isFinite(n) ? n : d;
};
const s = (kv: KV, k: string, d = ''): string => (kv[k] === undefined ? d : decStr(kv[k]));

// ---------------------------------------------------------------------------
// client -> server
// ---------------------------------------------------------------------------

export function encodeClientText(msg: ClientMessage): string {
  switch (msg.op) {
    case Op.Connect:
      return `CONNECT|${pairs(
        ['v', msg.protocolVersion],
        ['cv', encStr(msg.clientVersion)],
        ['n', encStr(msg.name)],
        ['veh', encStr(msg.vehicle)],
        ['sk', msg.skin],
        ['tok', encStr(msg.resumeToken)],
      )}`;
    case Op.Join:
      return `JOIN|${pairs(
        ['m', msg.mode],
        ['w', msg.world],
        ['tr', msg.track],
        ['rc', encStr(msg.roomCode)],
        ['tid', encStr(msg.trackId)],
        ['max', msg.maxPlayers],
      )}`;
    case Op.Input:
      return `INPUT|${pairs(
        ['s', msg.seq],
        ['ack', msg.ackTick],
        ['b', msg.buttons],
        ['st', msg.steer],
        ['ct', msg.clientTimeMs],
      )}`;
    case Op.State:
      return `STATE|${pairs(
        ['s', msg.seq],
        ['ack', msg.ackTick],
        ['f', msg.flags],
        ['px', msg.pos.x],
        ['py', msg.pos.y],
        ['pz', msg.pos.z],
        ['rx', msg.rot.x],
        ['ry', msg.rot.y],
        ['rz', msg.rot.z],
        ['rw', msg.rot.w],
        ['vx', msg.vel.x],
        ['vy', msg.vel.y],
        ['vz', msg.vel.z],
        ['h', msg.health],
        ['l', msg.lap],
        ['c', msg.cp],
        ['sp', msg.speed],
      )}`;
    case Op.Chat:
      return `CHAT|ch=${msg.channel},x=${encStr(msg.text)}`;
    case Op.Ping:
      return `PING|n=${msg.nonce},ct=${msg.clientTimeMs}`;
    case Op.Ready:
      return `READY|r=${msg.ready ? 1 : 0}`;
    case Op.Action:
      return `ACTION|${pairs(
        ['a', msg.action],
        ['t', msg.target],
        ['arg', msg.arg],
        ['px', msg.pos.x],
        ['py', msg.pos.y],
        ['pz', msg.pos.z],
      )}`;
    case Op.Hit:
      return `HIT|${pairs(
        ['t', msg.targetId],
        ['w', msg.weapon],
        ['px', msg.pos.x],
        ['py', msg.pos.y],
        ['pz', msg.pos.z],
        ['ct', msg.clientTimeMs],
        ['d', msg.damage],
      )}`;
    case Op.SetVehicle:
      return `SETVEH|veh=${encStr(msg.vehicle)},sk=${msg.skin}`;
    case Op.Leave:
      return 'LEAVE|';
    case Op.RoomList:
      return `ROOMLIST|m=${msg.mode}`;
    default:
      throw new Error('unsupported client message for text profile');
  }
}

export function decodeClientText(input: string): ClientMessage[] {
  const out: ClientMessage[] = [];
  for (const rawLine of input.split('\n')) {
    const line = rawLine.trim();
    if (!line) continue;
    const { tag, kv } = parseKV(line);
    const op = BY_TAG.get(tag);
    switch (op) {
      case Op.Connect:
        out.push({
          op: Op.Connect,
          protocolVersion: f(kv, 'v'),
          clientVersion: s(kv, 'cv'),
          name: s(kv, 'n'),
          vehicle: s(kv, 'veh'),
          skin: f(kv, 'sk'),
          resumeToken: s(kv, 'tok'),
        });
        break;
      case Op.Join:
        out.push({
          op: Op.Join,
          mode: (f(kv, 'm') === 1 ? 1 : 0),
          world: f(kv, 'w'),
          track: f(kv, 'tr'),
          roomCode: s(kv, 'rc'),
          trackId: s(kv, 'tid'),
          maxPlayers: f(kv, 'max', 32),
        });
        break;
      case Op.Input:
        out.push({
          op: Op.Input,
          seq: f(kv, 's'),
          ackTick: f(kv, 'ack'),
          buttons: f(kv, 'b'),
          steer: f(kv, 'st'),
          clientTimeMs: f(kv, 'ct'),
        });
        break;
      case Op.State:
        out.push({
          op: Op.State,
          seq: f(kv, 's'),
          ackTick: f(kv, 'ack'),
          flags: f(kv, 'f'),
          pos: { x: f(kv, 'px'), y: f(kv, 'py'), z: f(kv, 'pz') },
          rot: { x: f(kv, 'rx'), y: f(kv, 'ry'), z: f(kv, 'rz'), w: f(kv, 'rw', 1) },
          vel: { x: f(kv, 'vx'), y: f(kv, 'vy'), z: f(kv, 'vz') },
          health: f(kv, 'h'),
          lap: f(kv, 'l'),
          cp: f(kv, 'c'),
          speed: f(kv, 'sp'),
        });
        break;
      case Op.Chat:
        out.push({ op: Op.Chat, channel: f(kv, 'ch'), text: s(kv, 'x') });
        break;
      case Op.Ping:
        out.push({ op: Op.Ping, nonce: f(kv, 'n'), clientTimeMs: f(kv, 'ct') });
        break;
      case Op.Ready:
        out.push({ op: Op.Ready, ready: f(kv, 'r') === 1 });
        break;
      case Op.Action:
        out.push({
          op: Op.Action,
          action: f(kv, 'a'),
          target: f(kv, 't'),
          arg: f(kv, 'arg'),
          pos: { x: f(kv, 'px'), y: f(kv, 'py'), z: f(kv, 'pz') },
        });
        break;
      case Op.Hit:
        out.push({
          op: Op.Hit,
          targetId: f(kv, 't'),
          weapon: f(kv, 'w'),
          pos: { x: f(kv, 'px'), y: f(kv, 'py'), z: f(kv, 'pz') },
          clientTimeMs: f(kv, 'ct'),
          damage: f(kv, 'd'),
        });
        break;
      case Op.SetVehicle:
        out.push({ op: Op.SetVehicle, vehicle: s(kv, 'veh'), skin: f(kv, 'sk') });
        break;
      case Op.Leave:
        out.push({ op: Op.Leave });
        break;
      case Op.RoomList:
        out.push({ op: Op.RoomList, mode: f(kv, 'm') });
        break;
      default:
        // unknown tag: ignore rather than kill the connection
        break;
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// server -> client
// ---------------------------------------------------------------------------

function encodeEntry(e: SnapshotEntry): string {
  const parts = [`i=${e.id}`, `m=${e.mask}`];
  if (e.mask & SnapField.Position && e.pos) {
    parts.push(`px=${num(e.pos.x, 2)}`, `py=${num(e.pos.y, 2)}`, `pz=${num(e.pos.z, 2)}`);
  }
  if (e.mask & SnapField.Rotation && e.rot) {
    parts.push(
      `rx=${num(e.rot.x, 4)}`,
      `ry=${num(e.rot.y, 4)}`,
      `rz=${num(e.rot.z, 4)}`,
      `rw=${num(e.rot.w, 4)}`,
    );
  }
  if (e.mask & SnapField.Velocity && e.vel) {
    parts.push(`vx=${num(e.vel.x, 2)}`, `vy=${num(e.vel.y, 2)}`, `vz=${num(e.vel.z, 2)}`);
  }
  if (e.mask & SnapField.Health) parts.push(`h=${Math.round(e.health ?? 0)}`);
  if (e.mask & SnapField.Flags) parts.push(`f=${e.flags ?? 0}`);
  if (e.mask & SnapField.Race) parts.push(`l=${e.lap ?? 0}`, `c=${e.cp ?? 0}`);
  if (e.mask & SnapField.Speed) parts.push(`sp=${Math.round(e.speed ?? 0)}`);
  return `E|${parts.join(',')}`;
}

export function encodeServerText(msg: ServerMessage): string[] {
  switch (msg.op) {
    case Op.Welcome:
      return [
        `WELCOME|${pairs(
          ['i', msg.playerId],
          ['t', msg.serverTick],
          ['r', msg.tickRate],
          ['sr', msg.snapshotRate],
          ['k', encStr(msg.resumeToken)],
          ['sn', encStr(msg.serverName)],
        )}`,
      ];
    case Op.Joined: {
      const lines = [
        `JOINED|${pairs(
          ['room', encStr(msg.roomId)],
          ['m', msg.mode],
          ['w', msg.world],
          ['tr', msg.track],
          ['laps', msg.totalLaps],
          ['tid', encStr(msg.trackId)],
          ['st', msg.startTick],
        )}`,
      ];
      for (const p of msg.players) {
        lines.push(
          `PJ|${pairs(
            ['i', p.id],
            ['n', encStr(p.name)],
            ['veh', encStr(p.vehicle)],
            ['sk', p.skin],
            ['r', p.ready ? 1 : 0],
          )}`,
        );
      }
      return lines;
    }
    case Op.Snapshot: {
      const lines = [`SN|${pairs(['t', msg.tick], ['b', msg.baselineTick])}`];
      for (const e of msg.entries) lines.push(encodeEntry(e));
      return lines;
    }
    case Op.PlayerJoin:
      return [
        `PJ|${pairs(
          ['i', msg.player.id],
          ['n', encStr(msg.player.name)],
          ['veh', encStr(msg.player.vehicle)],
          ['sk', msg.player.skin],
          ['r', msg.player.ready ? 1 : 0],
        )}`,
      ];
    case Op.PlayerLeave:
      return [`PL|i=${msg.id},rs=${msg.reason}`];
    case Op.ChatMsg:
      return [
        `C|${pairs(
          ['i', msg.senderId],
          ['ch', msg.channel],
          ['n', encStr(msg.name)],
          ['x', encStr(msg.text)],
          ['t', msg.tick],
        )}`,
      ];
    case Op.Event:
      return [
        `EV|${pairs(
          ['e', msg.event],
          ['a', msg.actorId],
          ['t', msg.targetId],
          ['val', msg.value],
          ['px', msg.pos.x],
          ['py', msg.pos.y],
          ['pz', msg.pos.z],
        )}`,
      ];
    case Op.RaceState: {
      const lines = [
        `RS|${pairs(
          ['ph', msg.phase],
          ['tm', msg.timeMs],
          ['l', msg.lap],
          ['tl', msg.totalLaps],
          ['cd', msg.countdownMs],
        )}`,
      ];
      for (const st of msg.standings) {
        lines.push(
          `ST|${pairs(
            ['i', st.id],
            ['l', st.lap],
            ['c', st.cp],
            ['d', st.dist],
            ['f', st.finished ? 1 : 0],
            ['ft', st.finishTimeMs],
            ['bl', st.bestLapMs],
          )}`,
        );
      }
      return lines;
    }
    case Op.Correction:
      return [
        `COR|${pairs(
          ['s', msg.seq],
          ['rs', msg.reason],
          ['px', msg.pos.x],
          ['py', msg.pos.y],
          ['pz', msg.pos.z],
          ['rx', msg.rot.x],
          ['ry', msg.rot.y],
          ['rz', msg.rot.z],
          ['rw', msg.rot.w],
          ['vx', msg.vel.x],
          ['vy', msg.vel.y],
          ['vz', msg.vel.z],
        )}`,
      ];
    case Op.Pong:
      return [`PONG|${pairs(['n', msg.nonce], ['t', msg.tick], ['ct', msg.clientTimeMs])}`];
    case Op.Error:
      return [`ERR|c=${msg.code},m=${encStr(msg.message)}`];
    case Op.RoomListResult: {
      const lines = [`RL|n=${msg.rooms.length}`];
      for (const room of msg.rooms) {
        lines.push(
          `R|${pairs(
            ['id', encStr(room.id)],
            ['m', room.mode],
            ['w', room.world],
            ['tr', room.track],
            ['p', room.players],
            ['max', room.maxPlayers],
            ['ph', room.phase],
            ['j', room.joinable ? 1 : 0],
          )}`,
        );
      }
      return lines;
    }
    default:
      throw new Error('unsupported server message for text profile');
  }
}

export function decodeServerText(input: string): ServerMessage[] {
  const out: ServerMessage[] = [];
  let snapshotHeader: { tick: number; baselineTick: number; entries: SnapshotEntry[] } | null = null;
  let joined: ServerMessage | null = null;
  let race: Extract<ServerMessage, { op: typeof Op.RaceState }> | null = null;
  let roomList: Extract<ServerMessage, { op: typeof Op.RoomListResult }> | null = null;

  const flush = () => {
    if (snapshotHeader) {
      out.push({ op: Op.Snapshot, ...snapshotHeader });
      snapshotHeader = null;
    }
    if (joined) {
      out.push(joined);
      joined = null;
    }
    if (race) {
      out.push(race);
      race = null;
    }
    if (roomList) {
      out.push(roomList);
      roomList = null;
    }
  };

  for (const rawLine of input.split('\n')) {
    const line = rawLine.trim();
    if (!line) continue;
    const { tag, kv } = parseKV(line);

    if (tag === 'E' && snapshotHeader) {
      const mask = f(kv, 'm');
      const entry: SnapshotEntry = { id: f(kv, 'i'), mask };
      if (mask & SnapField.Position) {
        entry.pos = { x: f(kv, 'px'), y: f(kv, 'py'), z: f(kv, 'pz') };
      }
      if (mask & SnapField.Rotation) {
        entry.rot = { x: f(kv, 'rx'), y: f(kv, 'ry'), z: f(kv, 'rz'), w: f(kv, 'rw', 1) };
      }
      if (mask & SnapField.Velocity) {
        entry.vel = { x: f(kv, 'vx'), y: f(kv, 'vy'), z: f(kv, 'vz') };
      }
      if (mask & SnapField.Health) entry.health = f(kv, 'h');
      if (mask & SnapField.Flags) entry.flags = f(kv, 'f');
      if (mask & SnapField.Race) {
        entry.lap = f(kv, 'l');
        entry.cp = f(kv, 'c');
      }
      if (mask & SnapField.Speed) entry.speed = f(kv, 'sp');
      snapshotHeader.entries.push(entry);
      continue;
    }
    if (tag === 'ST' && race) {
      race.standings.push({
        id: f(kv, 'i'),
        lap: f(kv, 'l'),
        cp: f(kv, 'c'),
        dist: f(kv, 'd'),
        finished: f(kv, 'f') === 1,
        finishTimeMs: f(kv, 'ft'),
        bestLapMs: f(kv, 'bl'),
      });
      continue;
    }
    if (tag === 'R' && roomList) {
      roomList.rooms.push({
        id: s(kv, 'id'),
        mode: f(kv, 'm') as 0 | 1,
        world: f(kv, 'w'),
        track: f(kv, 'tr'),
        players: f(kv, 'p'),
        maxPlayers: f(kv, 'max'),
        phase: f(kv, 'ph'),
        joinable: f(kv, 'j') === 1,
      });
      continue;
    }
    if (tag === 'PJ' && joined && joined.op === Op.Joined) {
      joined.players.push({
        id: f(kv, 'i'),
        name: s(kv, 'n'),
        vehicle: s(kv, 'veh'),
        skin: f(kv, 'sk'),
        ready: f(kv, 'r') === 1,
      });
      continue;
    }

    flush();
    const op = BY_TAG.get(tag);
    switch (op) {
      case Op.Welcome:
        out.push({
          op: Op.Welcome,
          playerId: f(kv, 'i'),
          serverTick: f(kv, 't'),
          tickRate: f(kv, 'r', 20),
          snapshotRate: f(kv, 'sr', 20),
          resumeToken: s(kv, 'k'),
          serverName: s(kv, 'sn'),
        });
        break;
      case Op.Joined:
        joined = {
          op: Op.Joined,
          roomId: s(kv, 'room'),
          mode: f(kv, 'm'),
          world: f(kv, 'w'),
          track: f(kv, 'tr'),
          totalLaps: f(kv, 'laps'),
          trackId: s(kv, 'tid'),
          startTick: f(kv, 'st'),
          players: [],
        };
        break;
      case Op.Snapshot:
        snapshotHeader = { tick: f(kv, 't'), baselineTick: f(kv, 'b'), entries: [] };
        break;
      case Op.PlayerJoin:
        out.push({
          op: Op.PlayerJoin,
          player: {
            id: f(kv, 'i'),
            name: s(kv, 'n'),
            vehicle: s(kv, 'veh'),
            skin: f(kv, 'sk'),
            ready: f(kv, 'r') === 1,
          },
        });
        break;
      case Op.PlayerLeave:
        out.push({ op: Op.PlayerLeave, id: f(kv, 'i'), reason: f(kv, 'rs') });
        break;
      case Op.ChatMsg:
        out.push({
          op: Op.ChatMsg,
          senderId: f(kv, 'i'),
          channel: f(kv, 'ch'),
          name: s(kv, 'n'),
          text: s(kv, 'x'),
          tick: f(kv, 't'),
        });
        break;
      case Op.Event:
        out.push({
          op: Op.Event,
          event: f(kv, 'e'),
          actorId: f(kv, 'a'),
          targetId: f(kv, 't'),
          value: f(kv, 'val'),
          pos: { x: f(kv, 'px'), y: f(kv, 'py'), z: f(kv, 'pz') },
        });
        break;
      case Op.RaceState:
        race = {
          op: Op.RaceState,
          phase: f(kv, 'ph'),
          timeMs: f(kv, 'tm'),
          lap: f(kv, 'l'),
          totalLaps: f(kv, 'tl'),
          countdownMs: f(kv, 'cd'),
          standings: [],
        };
        break;
      case Op.Correction:
        out.push({
          op: Op.Correction,
          seq: f(kv, 's'),
          reason: f(kv, 'rs'),
          pos: { x: f(kv, 'px'), y: f(kv, 'py'), z: f(kv, 'pz') },
          rot: { x: f(kv, 'rx'), y: f(kv, 'ry'), z: f(kv, 'rz'), w: f(kv, 'rw', 1) },
          vel: { x: f(kv, 'vx'), y: f(kv, 'vy'), z: f(kv, 'vz') },
        });
        break;
      case Op.Pong:
        out.push({ op: Op.Pong, nonce: f(kv, 'n'), tick: f(kv, 't'), clientTimeMs: f(kv, 'ct') });
        break;
      case Op.Error:
        out.push({ op: Op.Error, code: f(kv, 'c'), message: s(kv, 'm') });
        break;
      case Op.RoomListResult:
        roomList = { op: Op.RoomListResult, rooms: [] };
        break;
      default:
        break;
    }
  }
  flush();
  return out;
}

export { DETAIL_TAGS };
