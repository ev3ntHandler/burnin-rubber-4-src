# 01 — Architecture

Burnin' Rubber 4 shipped in 2007 as a Director/Shockwave title: Lingo scripts (`[M]`/`[PS]`)
driving a Shockwave 3D scene, with `gSystem` / `gData` / `gGame` / `gSound` globals and two
scenes, `"Track"` and `"World"`. It had no online mode. This repository adds one **without
touching the physics**: the original car simulation stays authoritative for the local car, and
a Node server arbitrates everything a player can cheat for (race position, damage, pickups).

```
┌──────────────────────────── clients ────────────────────────────┐
│                                                                 │
│  Shockwave / Ruffle (Director)          Browser / Electron      │
│  Lingo + netTextResult                  native ES modules       │
│         │ text profile                  │ binary profile        │
│         ▼                               ▼                       │
└──────────┬───────────────────────────────┬──────────────────────┘
           │ HTTP long-poll /mp/*          │ WS /mp/ws
           ▼                               ▼
      ┌────────────────────────────────────────────────┐
      │ packages/server  (Node ≥20, no framework)      │
      │  app.ts        createApp(): http + ws + static │
      │  gameServer.ts sessions, registry, 20 Hz tick  │
      │  room.ts       shared room: state, chat, snap  │
      │  race.ts       RaceRoom: grid, gates, laps     │
      │  freeRoam.ts   FreeRoamRoom: damage, pickups   │
      │  bots.ts       server-side filler drivers      │
      └───────────────┬────────────────────────────────┘
                      │ imports
                      ▼
      ┌────────────────────────────────────────────────┐
      │ packages/protocol  (dependency-free TypeScript)│
      │  constants  opcodes, enums, masks              │
      │  bits       bit reader/writer                  │
      │  quantize   1/32 m fixed point, smallest-3 quat│
      │  binary     WS framing                         │
      │  text       `OP|k=v,...` framing (Lingo)       │
      └────────────────────────────────────────────────┘
                      ▲
                      │ `/lib/protocol/src/index.js`
      ┌───────────────┴────────────────────────────────┐
      │ packages/webclient  (HTML + canvas 2D, no deps)│
      └────────────────────────────────────────────────┘
```

## Authority split

| Thing | Authority | Why |
| --- | --- | --- |
| Car position / velocity / rotation | **client**, validated by server | The hover physics in `[PS] Advanced Car.ls enterFrame` *is* the game. Re-running it server-side would require porting Shockwave physics and would feel worse over 100 ms of jitter. |
| Speed cap, teleport distance, sustained-movement budget | server (`applyState`) | Stops speed hacks and teleports without fighting legit nitro/ramp bursts. |
| Damage, kills, respawn, pickups | server | Arbitrated from `Hit` / `Action` messages, with lag compensation against the 1 s position history. |
| Race gates, laps, finish order, standings | server | Gates are crossed only when the server validates a checkpoint against the player's own position; progress is per-room state, not client claims. |
| Chat content and rate | server | Sanitised, rate limited, channel-filtered. |
| Look / camera / particles / engine audio | client | Purely cosmetic, no round trip. |

Everything the server *does* validate is in `packages/server/src/room.ts` and documented in
[03-server.md](03-server.md).

## Tick loop

`GameServer.start()` drives one `setInterval` at `tickRate` (default 20 Hz):

1. `room.runTick(now)` for every room
   - `onTick()` — mode specific work (bots, countdown, stuck detection, pickup respawns)
   - prune players whose socket has been gone longer than `pollIdleDisconnectMs`
   - record the transform into the per-player history ring (1 s, used for hit validation)
   - every `tickRate / snapshotRate` ticks, `broadcastSnapshots()`
2. destroy rooms that have had no humans for `MAX_ROOM_IDLE_MS` (90 s) — warm free-roam
   rooms per world are kept alive
3. reap detached sessions after `resumeWindowMs` (60 s)

Client → server state arrives at 20 Hz from the web client (`STATE_HZ`) and at 10–20 Hz from
Lingo; the server never blocks on it.

## Snapshot strategy

Snapshots are **delta encoded per viewer** against the last snapshot that viewer acknowledged
implicitly by the `ackTick` inside its state updates. Each entry carries a field mask, and the
`Absolute` bit forces full position/rotation values (first snapshot, respawn, reconnect,
keyframe request). Remote cars on the client are rendered from an interpolation buffer with a
120 ms delay, the local car is predicted by the original physics. Details in
[02-protocol.md](02-protocol.md).

## Why two transports, one message set

Shockwave Player can only make HTTP requests from Lingo (`getNetText` / `postNetText`, or
`preloadNetThing`); it cannot open a raw WebSocket. Ruffle is similar. So the protocol exists
twice over the same logical messages:

* **binary** — bit-packed frames over `/mp/ws`, used by the web harness and Electron.
* **text** — one `OP|k=v,...` line per message over `/mp/connect`, `/mp/turn`, `/mp/poll`,
  `/mp/send`, used by Lingo. Long-polling gives 20 Hz updates with 15 s holds.

Both profiles are produced by the same `ServerMessage` objects, so a Director client and a
browser client can share a room. See [05-director-bridge.md](05-director-bridge.md) and
[06-operations.md](06-operations.md).

## Repository layout

```
multiplayer/
  packages/protocol/   wire format, shared by everyone (zero dependencies)
  packages/server/     HTTP + WS + long-poll server, game logic, bots
  packages/webclient/  index.html, canvas renderer, sim, net, UI
  tools/               import-br4-data, check-webclient, smoke-webclient, headless-client
  data/                worlds + tracks extracted from the original assets
  lingo/patches/       Lingo bridge for the Director build
  docs/                this documentation
```

Working directories are `packages/*/dist`; `node_modules` and `dist` are generated.

## Deliberate non-goals

* No server-side re-simulation of `Advanced Car.ls`; physics parity would be a porting project
  of its own and would change the feel of the game.
* No database. Rooms are ephemeral and in-memory; only accounts/leaderboards would need
  persistence and are out of scope for v1.
* No anti-cheat beyond what a 2007 arcade racer needs: no kernel drivers, no screenshot
  validation, no client integrity hashes.
