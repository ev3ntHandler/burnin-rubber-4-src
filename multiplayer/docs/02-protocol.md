# 02 — Protocol v1

One message set, two framings. The binary profile is what `/mp/ws` speaks; the text profile is
what Lingo speaks over HTTP. Both carry the same `ClientMessage` / `ServerMessage` values, so a
Director client and a browser client can share a room and a race.

* `PROTOCOL_VERSION = 1`; the server rejects other versions with `ErrorCode.BadVersion`.
* Opcodes are stable: client → server in `0x01..0x3f`, server → client in `0x80..0xbf`.
* World space is Z-up, metres. World indexes: City 0, Desert 1, Jungle 2, Industrial 3, Snow 4.

## 1. Binary profile (`/mp/ws`, `?profile=text` for the text framing over WS)

Each frame is a single message: one opcode byte, then a payload. Strings are `u8` length + UTF-8
bytes (never a NUL-terminated C string), numbers are little-endian, fixed point where noted.

| Field | Encoding |
| --- | --- |
| position | `i32` × 3 at 1/32 m (3.1 cm) |
| velocity | `i32` × 3 at 1/32 m/s |
| rotation | smallest-three quaternion, 2 bits index + 3 × 10 bits (`pf32`) — ≈0.17° error |
| speed | `u16`, m/s |
| health | `u16` |
| names / chat / track ids | `u8` length + UTF-8, max 200 bytes |

`packages/protocol/src/bits.ts` is the only reader/writer; it never throws on missing string
fields (they decode to `''`), which keeps a malformed client from crashing a room.

## 2. Client → server

| Op | Name | Payload |
| --- | --- | --- |
| `0x01` | Connect | `protocolVersion u8`, `clientVersion str`, `name str`, `vehicle str`, `skin u8`, `resumeToken str` |
| `0x02` | Join | `mode u8` (0 free roam, 1 race), `world u8`, `track u8` (legacy), `roomCode str`, `trackId str`, `maxPlayers u16` |
| `0x03` | Input | `seq u32`, `ackTick u32`, `buttons u16`, `steer i8`, `clientTimeMs u32` |
| `0x04` | State | `seq u32`, `ackTick u32`, `flags u8`, `pos`, `rot`, `vel`, `health u16`, `lap u16`, `cp u16`, `speed u16` |
| `0x05` | Chat | `channel u8`, `text str` |
| `0x06` | Ping | `nonce u32`, `clientTimeMs u32` |
| `0x07` | Ready | `ready u8` |
| `0x08` | Action | `action u8`, `target u32`, `arg i32`, `pos` |
| `0x09` | Hit | `targetId u32`, `weapon u8`, `pos`, `clientTimeMs u32`, `damage u16` |
| `0x0a` | SetVehicle | `vehicle str`, `skin u8` |
| `0x0b` | Leave | — |
| `0x0c` | RoomList | `mode i8` (−1 = all) |

`ActionId`: Horn 0, Emote 1, Respawn 2, FireWeapon 3, Pickup 4, InviteRace 5, AcceptInvite 6,
Detonate 7, TowRequest 8, Nitro 9.

`InputButton` bits: Forward 1, Backward 2, Left 4, Right 8, Brake 16, Action1 32, Action2 64,
Nitro 128, Horn 256.

## 3. Server → client

| Op | Name | Payload |
| --- | --- | --- |
| `0x80` | Welcome | `playerId u32`, `serverTick u32`, `tickRate u8`, `snapshotRate u8`, `resumeToken str`, `serverName str` |
| `0x81` | Joined | `roomId str`, `mode u8`, `world u8`, `track u8`, `trackId str`, `totalLaps u8`, `startTick u32`, player list |
| `0x82` | Snapshot | `tick u32`, `baselineTick u32`, entries |
| `0x83` | PlayerJoin | player descriptor (`id, name, vehicle, skin, ready`) |
| `0x84` | PlayerLeave | `id u32`, `reason u8` |
| `0x85` | ChatMsg | `senderId u32`, `channel u8`, `name str`, `text str`, `tick u32` |
| `0x86` | Event | `event u8`, `actorId u32`, `targetId u32`, `value i32`, `pos` |
| `0x87` | RaceState | `phase u8`, `timeMs u32`, `lap`, `totalLaps`, `countdownMs u32`, standings |
| `0x88` | Correction | `seq u32`, `reason u8`, `pos`, `rot`, `vel` |
| `0x89` | Pong | `nonce u32`, `tick u32`, `clientTimeMs u32` |
| `0x8a` | Error | `code u8`, `message str` |
| `0x8b` | RoomListResult | rooms (`id, mode, world, track, players, maxPlayers, phase, joinable`) |

`RacePhase`: Lobby 0, Countdown 1, Running 2, Finishing 3, Results 4.
`CorrectionReason`: AntiCheat 0, Respawn 1, RaceStart 2, ServerReset 3.
`EventId`: WeaponFired 0, Hit 1, Explosion 2, PickupTaken 3, PlayerDeath 4, PlayerRespawn 5,
Horn 6, Emote 7, RaceCountdown 8, RaceGo 9, RaceLap 10, RaceFinish 11, PlayerJoined 12,
PlayerLeft 13, VehicleChanged 14, KillFeed 15, RaceInvite 16, PickupRespawn 17, WrongWay 18,
Checkpoint 19.
`ErrorCode`: BadVersion 1 … InvalidState 12 (messages in `constants.ts`).

## 4. Snapshots and deltas

```
SnapshotMsg {
  tick, baselineTick,
  entries: [{ id, mask, pos?, rot?, vel?, health?, flags?, lap?, cp?, speed? }]
}
```

`SnapField`: Position 1, Rotation 2, Velocity 4, Health 8, Flags 16, Race 32, Speed 64,
Absolute 128.

* Entries are delta encoded against the viewer's acknowledged baseline (`baselineTick`).
* `Absolute` is set when an entry must be read literally: the first snapshot after join or
  reconnect, after a teleport/respawn, and whenever a keyframe is requested
  (`room.requestKeyframe(id)`).
* **The local player's own entry is always absolute.** A client that predicted its position
  cannot decode a delta against a baseline it never rendered, and the echo of the authoritative
  transform is what the web client uses to detect corrections.
* Only opponents *visible* to the viewer are included (`RaceRoom.visibleTo` limits free roam to
  a radius; races include the whole grid within the world).
* A 20-player race posts ≈ 300 B per snapshot per client at 20 Hz (measured in the test suite).

## 5. Text profile

Line-oriented, one message per line, `TAG|k=v,k=v,...`. Every free-form string is
`encodeURIComponent`ed, so `,` `=` `|` and newlines inside chat/names can never break framing.

Client tags: `CONNECT`, `JOIN`, `INPUT`, `STATE`, `CHAT`, `PING`, `READY`, `ACTION`, `HIT`,
`SETVEH`, `LEAVE`, `ROOMLIST`.
Server tags: `WELCOME`, `JOINED`, `SN` (snapshot header), `E` (snapshot entry, one line each),
`PJ` (player join / roster line of `JOINED`), `PL`, `C` (chat), `EV` (event), `RS` (race state),
`COR`, `PONG`, `ERR`, `RL` (room list).

Key names: `i` id, `n` name, `veh` vehicle, `sk` skin, `px/py/pz`, `rx/ry/rz/rw`, `vx/vy/vz`,
`h` health, `f` flags, `l` lap, `c` checkpoint, `sp` speed, `s` seq, `ack`, `b` buttons, `st`
steer or startTick, `ct` client time, `m` mode or mask, `w` world or weapon, `tr` legacy track,
`tid` track id, `rc` room code, `ph` phase, `tm` time, `tl` total laps, `cd` countdown,
`rs` reason, `x` chat text, `ch` channel, `a` action/actor, `e` event, `val` value, `c` error
code.

Examples:

```
CONNECT|v=1,cv=shockwave,n=Racer,veh=PlayerCar,sk=0,tok=
JOIN|m=1,w=0,tr=0,rc=,tid=city-1,max=32
STATE|s=41,ack=812,f=2,px=985.49,py=791.33,pz=19.96,rx=0,ry=0,rz=0.7071,rw=0.7071,vx=0,vy=0,vz=0,h=100,l=1,c=3,sp=38
SN|t=813,b=812
E|i=7,m=7,px=1102.51,py=840.02,pz=21.5,rx=0,ry=0,rz=0,rw=1,vx=12,vy=0,vz=0,h=100,f=0,l=1,c=4,sp=12
C|i=0,ch=2,n=SYSTEM,x=Race%20starting%20in%205s,t=813
```

`decodeServerText` accepts one snapshot spread across several lines (header `SN` then `E`
lines) and returns them as a single `SnapshotMsg`, which is what makes the text profile usable
from Lingo without a buffer format. Same for `JOINED` + `PJ` roster lines, `RS` + `ST`
standings lines and `RL` + `R` room lines: the short tags `E`, `PJ`, `ST`, `R` are detail lines
that only make sense after their header.

## 6. Ordering, resumption and heartbeats

* `Ping`/`Pong` every 2.5 s from the web client; RTT is shown in the HUD pill. `Pong` echoes
  `clientTimeMs`, which is also how the server learns each player's clock offset for lag
  compensation.
* A dropped socket keeps the session for `resumeWindowMs` (60 s). Reconnecting with
  `resumeToken` returns the same player id, the same room and a fresh absolute keyframe.
* `seq` is monotonic per client; the server drops duplicates and reordered updates (window
  1000). A client that stalls for a second re-syncs with an absolute state instead of a burst
  of deltas.
* The text profile has no retransmit: `poll` returns what has been queued; if a client misses a
  poll window the next snapshot is a keyframe because the server sees no `ackTick` movement.
