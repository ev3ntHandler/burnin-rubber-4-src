import { Op } from './constants.js';
import type {
  GameMode,
  PlayerDescriptor,
  Quat,
  RaceStanding,
  RoomSummary,
  SnapshotEntry,
  Vec3,
} from './constants.js';

export interface ConnectMsg {
  op: typeof Op.Connect;
  protocolVersion: number;
  clientVersion: string;
  name: string;
  vehicle: string;
  skin: number;
  /** Session resume token from a previous `Welcome`, or '' for a fresh session. */
  resumeToken: string;
}

export interface JoinMsg {
  op: typeof Op.Join;
  mode: GameMode;
  world: number;
  /** Numeric slot kept for compatibility with the original protocol sketch. */
  track: number;
  /** Track id from data/tracks (`city-1`, `jungle-1-sprint`, ...). */
  trackId: string;
  roomCode: string;
  maxPlayers: number;
}

export interface InputMsg {
  op: typeof Op.Input;
  seq: number;
  /** Last server tick the client received, used for snapshot delta baselines. */
  ackTick: number;
  buttons: number;
  steer: number;
  /** Client-side tick when the input was sampled (ms, client clock). */
  clientTimeMs: number;
}

export interface StateMsg {
  op: typeof Op.State;
  seq: number;
  ackTick: number;
  pos: Vec3;
  rot: Quat;
  vel: Vec3;
  health: number;
  lap: number;
  cp: number;
  speed: number;
  flags: number;
}

export interface ChatMsg {
  op: typeof Op.Chat;
  channel: number;
  text: string;
}

export interface PingMsg {
  op: typeof Op.Ping;
  nonce: number;
  clientTimeMs: number;
}

export interface ReadyMsg {
  op: typeof Op.Ready;
  ready: boolean;
}

export interface ActionMsg {
  op: typeof Op.Action;
  action: number;
  target: number;
  arg: number;
  pos: Vec3;
}

export interface HitMsg {
  op: typeof Op.Hit;
  targetId: number;
  weapon: number;
  pos: Vec3;
  /** Client tick at which the hit happened, for lag compensation. */
  clientTimeMs: number;
  damage: number;
}

export interface SetVehicleMsg {
  op: typeof Op.SetVehicle;
  vehicle: string;
  skin: number;
}

export interface LeaveMsg {
  op: typeof Op.Leave;
}

export interface RoomListMsg {
  op: typeof Op.RoomList;
  mode: number;
}

export interface WelcomeMsg {
  op: typeof Op.Welcome;
  playerId: number;
  serverTick: number;
  tickRate: number;
  snapshotRate: number;
  resumeToken: string;
  serverName: string;
}

export interface JoinedMsg {
  op: typeof Op.Joined;
  roomId: string;
  mode: number;
  world: number;
  track: number;
  totalLaps: number;
  /** Track id (index file name) — '' in free roam. */
  trackId: string;
  players: PlayerDescriptor[];
  /** Server tick at which the race countdown ends (race mode only, 0 otherwise). */
  startTick: number;
}

export interface SnapshotMsg {
  op: typeof Op.Snapshot;
  tick: number;
  baselineTick: number;
  entries: SnapshotEntry[];
}

export interface PlayerJoinMsg {
  op: typeof Op.PlayerJoin;
  player: PlayerDescriptor;
}

export interface PlayerLeaveMsg {
  op: typeof Op.PlayerLeave;
  id: number;
  reason: number;
}

export interface ChatBroadcastMsg {
  op: typeof Op.ChatMsg;
  senderId: number;
  channel: number;
  name: string;
  text: string;
  tick: number;
}

export interface EventMsg {
  op: typeof Op.Event;
  event: number;
  actorId: number;
  targetId: number;
  value: number;
  pos: Vec3;
}

export interface RaceStateMsg {
  op: typeof Op.RaceState;
  phase: number;
  timeMs: number;
  lap: number;
  totalLaps: number;
  countdownMs: number;
  standings: RaceStanding[];
}

export interface CorrectionMsg {
  op: typeof Op.Correction;
  seq: number;
  reason: number;
  pos: Vec3;
  rot: Quat;
  vel: Vec3;
}

export interface PongMsg {
  op: typeof Op.Pong;
  nonce: number;
  tick: number;
  clientTimeMs: number;
}

export interface ErrorMsg {
  op: typeof Op.Error;
  code: number;
  message: string;
}

export interface RoomListResultMsg {
  op: typeof Op.RoomListResult;
  rooms: RoomSummary[];
}

export type ClientMessage =
  | ConnectMsg
  | JoinMsg
  | InputMsg
  | StateMsg
  | ChatMsg
  | PingMsg
  | ReadyMsg
  | ActionMsg
  | HitMsg
  | SetVehicleMsg
  | LeaveMsg
  | RoomListMsg;

export type ServerMessage =
  | WelcomeMsg
  | JoinedMsg
  | SnapshotMsg
  | PlayerJoinMsg
  | PlayerLeaveMsg
  | ChatBroadcastMsg
  | EventMsg
  | RaceStateMsg
  | CorrectionMsg
  | PongMsg
  | ErrorMsg
  | RoomListResultMsg;
