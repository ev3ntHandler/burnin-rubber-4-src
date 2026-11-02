# 05 — Director / Lingo bridge

The Director build cannot open a WebSocket: Shockwave Player only gives Lingo
`getNetText` / `postNetText` / `netDone` / `netTextResult` over HTTP. That is why the protocol
has a text profile — one message per line, no binary, no base64 — and why the server exposes
the long-poll endpoints `/mp/connect`, `/mp/send`, `/mp/poll` (and `/mp/turn`, which sends and
waits in a single round trip).

The bridge ships in `lingo/patches/` as one generated single-file build and three sources:

| File | Responsibility |
| --- | --- |
| `br4mp_bridge.ls` | **all of the below in one member** — generated, paste this one |
| `br4mp_config.ls` | server URL, cadence, timeouts, `gBR4MP` state, `BR4MPEnsure`, `BR4MPDiagnostics` |
| `br4mp_net.ls` | transport: connect, poll loop, send queue, line parsing, message dispatch |
| `br4mp_game.ls` | glue to the original game: read the local car, apply remote cars, HUD, chat |

They are *reference implementations*: paste them into the movie as **Movie Script** members
(not Behavior, not Parent — only movie-script handlers are global), keep the property names, and
wire the small set of hooks below. They are written against the exported protocol in
[02-protocol.md](02-protocol.md#5-text-profile), which is the part that matters if you would
rather write your own.

Initialisation is `ilk()`-based (`BR4MPEnsure`) rather than `gBR4MP = gBR4MP or [:]`: Lingo's
`or` is boolean, so the latter produces `TRUE` and every later `gBR4MP.active` fails with
"handler not defined #Active". Every install error met so far is documented in
[lingo/patches/TROUBLESHOOTING.md](../lingo/patches/TROUBLESHOOTING.md).

## Transport shape

```
POST /mp/connect?name=Dirk&v=1&veh=PlayerCar&sk=0&m=1&w=0&tid=city-1
     → WELCOME|i=7,...,k=<resumeToken>
       JOINED|room=race-w0-5,...
       PJ|...                     (roster)
       RS|...  ST|...             (race state)

GET  /mp/poll?token=<resumeToken>&wait=15
     → SN|t=813,b=812             (snapshot)
       E|i=7,m=255,px=...         (one line per visible car)

POST /mp/send?token=<resumeToken>&d=<url-encoded text block>
     → queued lines (usually empty)
```

* `token` is the resume token from `WELCOME` (`k=`). Keep it; the server holds the session for
  60 s after a drop.
* `d` may contain several newline-separated messages in one POST; the server decodes all of
  them. The bridge sends `STATE` at 20 Hz plus any queued `CHAT`/`ACTION`/`HIT`.
* `/mp/poll` holds for up to `wait` seconds (max 20) and returns `OK|` when it times out, so
  Lingo sees a completed request roughly every 15 s at worst.
* Every response is plain text; lines are separated by `\n`, fields by `,`, key/values by `=`,
  and free-form strings are percent-encoded — decode with `decodeURIComponent` equivalents (the
  bridge includes a small `br4mpDecode`).

## Hooks the bridge needs from the movie

These are the only places the original scripts must change. Everything is guarded by
`if gBR4MP.active then`, so single-player is untouched when the bridge is disabled.

1. **Startup** — `BR4MPStart(mode, worldIndex, trackId)` after `gGame` is initialised, e.g. from
   the main menu's "Online" button, and `BR4MPStop()` when returning to the menu.
2. **Frame loop** — `BR4MPGameFrame()` once per frame, from a movie script `enterFrame` or from
   the `Advanced Car` `enterFrame` after the physics update:
   * pumps the poll (`netDone` check),
   * every 50 ms builds a `STATE` line from the local car,
   * pings every 2.5 s,
   * applies incoming snapshot entries to the remote car list and eases them into place,
   * refreshes `gBR4MP.statusText` for the HUD.

   Verify the install from the Message window with `put BR4MPDiagnostics()` — it prints
   `gBR4MP ilk` (must be `#propList`), the URL, token, room, phase, RTT and last error, and
   repairs a damaged global.
3. **Local transform** — the bridge reads
   `pCar = gGame.me.car`, `pCar.transform.position` and `pCar.transform.rotation`, and the speed
   from the physics global (`gGame.me.speed`). Nothing else is needed; the server does not
   simulate physics.
4. **Remote cars** — `BR4MPGameRemoteSpawn(pRemote)` is the one place to create a car model
   (default: returns VOID, so opponents are not drawn). `BR4MPPlaceRemote` writes
   `transform.position`/`transform.rotation` every frame and `BR4MPAnimateRemotes` eases the
   rendered position towards the last snapshot (20 Hz snapshots, smooth at 30–60 fps).
5. **UI** — `BR4MPStatus` fills a small member (`gBR4MP.statusText`) that the existing HUD text
   member can display: room name, ping, player count, race phase and lap.
6. **Input** — chat is `BR4MPChat("text")`, respawn `BR4MPAction(2)`, horn `BR4MPAction(0)`,
   fire `BR4MPHit(targetId, 0, pos)`. Race invites are `ACTION|a=5` / `ACTION|a=6`.

The `Track` and `World` scenes both work: a race uses `mode=1` with a `trackId`, free roam uses
`mode=0`. World indexes are City 0, Desert 1, Jungle 2, Industrial 3, Snow 4; the spawn points
in `data/worlds/*.json` match the original scenes.

## What the server expects from the Director client

* `STATE` at 10–20 Hz, with `s` (sequence) incrementing and `ack` set to the last snapshot tick
  received. Without `ack` the server keeps sending keyframes.
* Transform in metres, Z-up, exactly as `gGame` stores it. Do not rescale to pixels: the
  smallest quantisation step is 1/32 m.
* No need to send `lap`/`cp`: the server validates gates from your position and overwrites them.
* If the server answers `COR|rs=0,...` ("anti-cheat") the car is being pulled back. The bridge
  applies the correction immediately (`pCar.transform.position = cor.pos`) — the physics will
  recover in a frame or two. Sustained corrections mean the local car is faster than
  `MP_MAX_SPEED` (95 m/s) or teleporting more than 55 m per update, e.g. a badly wired
  "restart at checkpoint".

## Typical failure modes

| Symptom | Cause |
| --- | --- |
| `ERR|c=1` on connect | `v=` is not 1 — protocol version mismatch |
| `ERR|c=3` after a while | session aged out past the 60 s resume window; call `BR4MPStart` again |
| no snapshots, chat works | `ack` never advanced (poll loop starved) — the server keeps sending keyframes, which is correct but wasteful |
| cars slide | remote interpolation disabled; snapshots alone are 20 Hz |
| everything teleports once on join | expected: the first `STATE` adopts the server spawn (up to 400 m tolerance) |
| `ERR|c=11` | server connect bucket exhausted (proxy not reusing connections, or a hot reload loop) |

## Testing without Director

The text profile is exercised by the transport tests and can be poked by hand:

The bridge also has a static linter (`npm run check:lingo`) that resolves every referenced
handler and every `gBR4MP.*` key, checks `¬` continuation placement and keeps
`br4mp_bridge.ls` in sync with the three sources.

```bash
# join a free-roam room and read the welcome + roster
curl -s "http://localhost:8080/mp/connect?name=PollTest&m=0&w=0"

# keep the token from WELCOME (k=...), then send a chat line and poll
curl -s "http://localhost:8080/mp/send?token=<token>&d=CHAT%7Cch%3D0%2Cx%3Dhello"
curl -s "http://localhost:8080/mp/poll?token=<token>&wait=2"
```

Ruffle runs the same text transport, so the bridge is also the path for playing the original
`.dcr` in a modern browser without a plugin.
