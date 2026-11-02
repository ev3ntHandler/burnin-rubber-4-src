/**
 * Burnin' Rubber 4 — Multiplayer wire protocol v1.
 *
 * Shared by the game client (Lingo, via the text profile), the browser/Electron
 * client and the authoritative Node server.
 *
 * Two profiles carry the exact same message set:
 *
 *   binary : compact bit-packed framing over WebSocket / WebTransport. Used by
 *            the web harness, the Electron shell and the local TCP bridge.
 *   text   : line-oriented `OP|key=value,...` framing over HTTP long-polling.
 *            Used by Shockwave Player / Ruffle, where Lingo can only talk HTTP
 *            through `preloadNetThing`/`netTextResult`. No bit twiddling in
 *            Lingo, no base64.
 *
 * See docs/02-protocol.md for the normative description.
 */

export const PROTOCOL_VERSION = 1;

/** Opcodes. Client -> server live in 0x01..0x3f, server -> client in 0x80..0xbf. */
export const Op = {
  // ---- client -> server -------------------------------------------------
  Connect: 0x01,
  Join: 0x02,
  Input: 0x03,
  State: 0x04,
  Chat: 0x05,
  Ping: 0x06,
  Ready: 0x07,
  Action: 0x08,
  Hit: 0x09,
  SetVehicle: 0x0a,
  Leave: 0x0b,
  RoomList: 0x0c,

  // ---- server -> client -------------------------------------------------
  Welcome: 0x80,
  Joined: 0x81,
  Snapshot: 0x82,
  PlayerJoin: 0x83,
  PlayerLeave: 0x84,
  ChatMsg: 0x85,
  Event: 0x86,
  RaceState: 0x87,
  Correction: 0x88,
  Pong: 0x89,
  Error: 0x8a,
  RoomListResult: 0x8b,
} as const;

export type OpCode = (typeof Op)[keyof typeof Op];

export const Mode = { FreeRoam: 0, Race: 1 } as const;
export type GameMode = (typeof Mode)[keyof typeof Mode];

/** World indexes. Must match the `Worlds/` folders shipped with the game. */
export const WorldIndex = {
  City: 0,
  Desert: 1,
  Jungle: 2,
  Industrial: 3,
  Snow: 4,
} as const;
export type WorldId = (typeof WorldIndex)[keyof typeof WorldIndex];

export const WORLD_NAMES = ['City', 'Desert', 'Jungle', 'Industrial', 'Snow'] as const;

export const ChatChannel = {
  All: 0,
  Team: 1,
  System: 2,
  Whisper: 3,
  Local: 4,
} as const;
export type ChatChannelId = (typeof ChatChannel)[keyof typeof ChatChannel];

export const ActionId = {
  Horn: 0,
  Emote: 1,
  Respawn: 2,
  FireWeapon: 3,
  Pickup: 4,
  InviteRace: 5,
  AcceptInvite: 6,
  Detonate: 7,
  TowRequest: 8,
  Nitro: 9,
} as const;
export type ActionIdValue = (typeof ActionId)[keyof typeof ActionId];

export const EventId = {
  WeaponFired: 0,
  Hit: 1,
  Explosion: 2,
  PickupTaken: 3,
  PlayerDeath: 4,
  PlayerRespawn: 5,
  Horn: 6,
  Emote: 7,
  RaceCountdown: 8,
  RaceGo: 9,
  RaceLap: 10,
  RaceFinish: 11,
  PlayerJoined: 12,
  PlayerLeft: 13,
  VehicleChanged: 14,
  KillFeed: 15,
  RaceInvite: 16,
  PickupRespawn: 17,
  WrongWay: 18,
  Checkpoint: 19,
} as const;
export type EventIdValue = (typeof EventId)[keyof typeof EventId];

/** Per-player state flags carried inside snapshots. */
export const PlayerFlag = {
  Dead: 1 << 0,
  Boosting: 1 << 1,
  Braking: 1 << 2,
  Airborne: 1 << 3,
  Respawning: 1 << 4,
  Spectator: 1 << 5,
  Ready: 1 << 6,
  WrongWay: 1 << 7,
} as const;

export const InputButton = {
  Forward: 1 << 0,
  Backward: 1 << 1,
  Left: 1 << 2,
  Right: 1 << 3,
  Brake: 1 << 4,
  Action1: 1 << 5,
  Action2: 1 << 6,
  Nitro: 1 << 7,
  Horn: 1 << 8,
} as const;

/** Bits in `SnapshotEntry.mask`. */
export const SnapField = {
  Position: 1 << 0,
  Rotation: 1 << 1,
  Velocity: 1 << 2,
  Health: 1 << 3,
  Flags: 1 << 4,
  Race: 1 << 5,
  Speed: 1 << 6,
  /** Position/velocity are absolute instead of deltas (first snapshot, respawns). */
  Absolute: 1 << 7,
} as const;

export const ErrorCode = {
  None: 0,
  BadVersion: 1,
  BadRequest: 2,
  AuthFailed: 3,
  NameTaken: 4,
  RoomFull: 5,
  RoomNotFound: 6,
  NotInRoom: 7,
  RateLimited: 8,
  Kicked: 9,
  Banned: 10,
  ServerBusy: 11,
  InvalidState: 12,
} as const;
export type ErrorCodeValue = (typeof ErrorCode)[keyof typeof ErrorCode];

export const ERROR_MESSAGES: Record<number, string> = {
  1: 'Protocol version mismatch — update the game client.',
  2: 'Malformed message.',
  3: 'Authentication failed.',
  4: 'That callsign is already in use.',
  5: 'Room is full.',
  6: 'Room no longer exists.',
  7: 'You are not in a room.',
  8: 'Slow down! Rate limit reached.',
  9: 'You were kicked from the server.',
  10: 'You are banned from this server.',
  11: 'Server is at capacity, try again shortly.',
  12: 'That action is not valid right now.',
};

/** Race phases as published in `RaceState`. */
export const RacePhase = {
  Lobby: 0,
  Countdown: 1,
  Running: 2,
  Finishing: 3,
  Results: 4,
} as const;
export type RacePhaseValue = (typeof RacePhase)[keyof typeof RacePhase];

/** Reasons a `Correction` may be sent. */
export const CorrectionReason = {
  AntiCheat: 0,
  Respawn: 1,
  RaceStart: 2,
  ServerReset: 3,
  Stuck: 4,
} as const;

// ---- shared value types -------------------------------------------------

export interface Vec3 {
  x: number;
  y: number;
  z: number;
}

export interface Quat {
  x: number;
  y: number;
  z: number;
  w: number;
}

export interface Transform {
  pos: Vec3;
  rot: Quat;
}

export interface PlayerDescriptor {
  id: number;
  name: string;
  vehicle: string;
  skin: number;
  ready: boolean;
}

export interface SnapshotEntry {
  id: number;
  mask: number;
  pos?: Vec3;
  rot?: Quat;
  vel?: Vec3;
  health?: number;
  flags?: number;
  lap?: number;
  cp?: number;
  speed?: number;
}

export interface RaceStanding {
  id: number;
  lap: number;
  cp: number;
  /** Distance to the next checkpoint, metres. Lower is further ahead. */
  dist: number;
  finished: boolean;
  finishTimeMs: number;
  bestLapMs: number;
}

export interface RoomSummary {
  id: string;
  mode: GameMode;
  world: number;
  track: number;
  players: number;
  maxPlayers: number;
  phase: number;
  joinable: boolean;
}
