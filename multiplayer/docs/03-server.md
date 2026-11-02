# 03 — Server

Everything here lives in `packages/server/src`. `app.ts` exposes one entry point,
`createApp(config)`, which wires HTTP, WebSocket, the long-poll API, the static mounts and the
game loop together; both `index.ts` and the test suite use it.

```
index.ts  →  createApp()  →  GameServer (sessions, rooms, tick)
                          →  HttpApi    (/mp/* long-poll)
                          →  ws.ts      (/mp/ws binary)
                          →  static.ts  (/, /data/, /lib/protocol/)
```

## Sessions

A session is created on `Connect` and identified by a random `resumeToken`
(`base64url`, 16 bytes). It holds the name, vehicle, skin, current room and player.

* `protocolVersion` must equal `PROTOCOL_VERSION`, otherwise `BadVersion`.
* Duplicate names are suffixed (`Name-42`) rather than rejected.
* A connection is rate limited by a token bucket (20 burst, 40/s replenish); exceeding it yields
  `ServerBusy` before any room work happens.
* On socket close the session is **detached**, not destroyed: the player stays in the room for
  `resumeWindowMs` (default 60 s) with `conn = null`. Reconnecting with the token restores the
  same id and asks the room for a keyframe.
* After the resume window the session is dropped; the player is removed from the room with
  reason 1. Rooms with no humans for 90 s are destroyed (warm free-roam rooms excepted).

`GameServer.describe()` powers `/health` and `/mp/info`: session count, player count and a room
list with mode, world, track, occupants, phase and `joinable`.

## Rooms

`Room` (abstract) owns what both modes share:

* the player map, per-player 1 s transform history (128 samples, used for lag-compensated hits),
  snapshot delta baselines and keyframe requests;
* chat with history, sanitising, a global bucket and a per-player 6-messages-per-10-s rule;
* the `applyState` guard rails (below);
* `removePlayer`, `teleport`, `respawn`, `sendEvent`, `requestKeyframe`.

`RaceRoom` and `FreeRoamRoom` add mode rules. Room ids look like `roam-w0-1` / `race-w0-5`
(`counter` is process wide, so ids are stable in logs and tests).

`GameServer.findFreeRoam(world)` reuses the first joinable free-roam room for that world, else
creates one. `findRace(world, trackId, roomCode)` prefers: the room named by `roomCode` →
lobbies with humans → empty lobbies → rooms in countdown (late joiners land on the back of the
grid) → a new room.

### Race lifecycle

| Phase | Value | What happens |
| --- | --- | --- |
| Lobby | 0 | waiting for players; `fillWithBots` fillers are added when a human is present |
| Countdown | 1 | 4 s grid hold; moving >6 m from your grid slot teleports you back with "False start" |
| Running | 2 | gates are validated, laps counted, stuck players reset to the last gate |
| Finishing | 3 | first finisher opens a 45 s window for the rest |
| Results | 4 | 10 s of standings, then the grid is cleared for the next race |

* Grid: `MAX_GRID = 12` slots, staggered from the track's `grid` data; a player joining during
  countdown is placed on a free slot.
* Gate validation: on every accepted `State` message the room checks whether the segment
  `oldPos → newPos` crossed one of the next three gates' planes, forward, within
  `width/2 + 6 m` laterally. Crossing is server-side, so "lap skip" cheats do nothing.
* A circuit counts a lap when gate 0 is crossed after the first lap start; a sprint finishes at
  `finishCheckpoint`.
* Stuck detection: speed < 1.2 m/s for 6.5 s sends you back to the last gate and says so in chat.
* Finishing requests a keyframe for every player, so the results screen is exact.

### Free roam

* Pickups from the world file (max 80) are arbitrated server-side: `Action: Pickup` within
  13 m of the pickup grants it, marks it taken for 25 s and broadcasts `PickupTaken`; everyone
  else's local collect is rejected by `PickupRespawn`.
* Weapons: `Hit` messages carry the claimed target, weapon and position. The server validates
  weapon range, cooldown, line-of-sight distance, and rewinds the target to the attacker's
  clock (up to 400 ms, `MAX_REWIND_MS`) before accepting. Damage table lives in
  `freeRoam.ts` (MachineGun 6, RocketPod 34, MiniGun 3.5, Laser 28, MainGun 45, …).
* Death: health ≤ 0 sets `PlayerFlag.Dead`, broadcasts `PlayerDeath`/`KillFeed` and respawns the
  car after 4.5 s with a `Correction` (reason `Respawn`).
* Ram damage uses the real relative velocity with a 450 ms cooldown per pair.
* Visibility: opponents further than 340 m are not snapshotted (`VISION_RADIUS`), which keeps a
  32-player free-roam room's snapshots as small as a 4-player race.

### Bots

`BotDriver` walks the imported traffic/route loop at a plausible pace and reports gates through
the *same* validation path (`checkGateCrossing`), so a bot can win or be scored normally. Bots
are added to a race lobby when `fillWithBots` is on and at least one human is in the room, and
they get synthetic player ids (`>= 1_000_000`) so a filler can never shadow a session — see the
note in [06-operations.md](06-operations.md#known-pitfalls).

## Anti-cheat (movement)

`Room.applyState` is the only place a client transform enters the server. Order of checks:

1. duplicate/out-of-order `seq` → drop silently;
2. non-finite coordinates → drop;
3. all-zero position from a brand-new player → drop (Lingo streams a zero transform before its
   first real one);
4. **first state after (re)connect** → accepted up to 400 m from the spawn, corrected beyond
   that without counting a strike (clients legitimately spawn at slightly different points);
5. **teleport** → movement larger than `maxTeleportM` (55 m, `MP_MAX_TELEPORT`) in one update is
   a strike;
6. **distance budget** → a token bucket refilled at `maxSpeedMs × 1.8` (171 m/s) with a 75.6 m
   burst cap. Legit nitro/ramp bursts are fine, sustained movement above 1.8× the fastest car is
   a strike. This replaced an implied-speed test that false-positived on bursty HTTP long-poll
   updates;
7. otherwise the transform is stored (health/speed/lap/cp clamped) and mode hooks run
   (`onStateApplied`).

A strike returns a `Correction` (rate limited to one every 500 ms) and does **not** apply the
update. More than `MAX_STRIKES = 12` strikes within a session closes the connection with
`ErrorCode.Kicked` — "Too many invalid state updates — reconnect to resync." The client is
expected to reconnect with its resume token, which yields a clean keyframe.

Set `MP_DEBUG_AC=1` to log every strike with player name, id, bot flag and the offending
distance; that is how the budget numbers above were tuned against the headless load generator.

## Chat

`Chat` messages are sanitised (control characters stripped, clipped to `chatMaxLength`),
rate limited per player (6 per 10 s, ≥250 ms apart) and per room. Channels: All 0, Team 1,
System 2, Whisper 3, Local 4. History is replayed to joiners (`chatHistory`, default 50 lines).

Commands (type them in chat): `/help`, `/players`, `/me <text>`, `/w <name> <text>`,
`/r` or `/respawn`, `/track <id>` (race invite), `/kick <name>` (admins, `MP_ADMINS`).

## Invites

`Action: InviteRace` sends a `RaceInvite` event with the room id; `Action: AcceptInvite` moves
the player into that room (`enterRoom` handles leaving the previous one). Used by the web
client's `I` / `Y` keys and available to Lingo through the same `ACTION` line.

## Tests

`packages/server/test/server.test.ts` covers the logic in-process with a `FakeConnection`:
connect/join/leave, gate order, sprint finish, chat sanitising and rate limits, pickup
arbitration and respawn, lag-compensated hit validation, snapshot delta size for 20 players,
resume, and protocol-version rejection — plus the two regressions found during the live runs
(filler ids must not shadow sessions; a room left with only bots reports `hasHumans() === false`).
`transport.test.ts` boots a real server on an ephemeral port and exercises WS, the long-poll
endpoints and the static mounts.
