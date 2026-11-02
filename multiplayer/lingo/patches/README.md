# Lingo patches — online bridge for the Director build

These scripts give the original Shockwave build an online mode that talks to
`packages/server`. They use the **text profile** over HTTP long-polling, because Shockwave
Player gives Lingo `getNetText` / `postNetText` and nothing else — no WebSocket, no binary
frames. Protocol reference: [docs/02-protocol.md](../../docs/02-protocol.md#5-text-profile).
Integration notes: [docs/05-director-bridge.md](../../docs/05-director-bridge.md).
Errors while installing: **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)**.

## Install — one member (recommended)

1. `File → New → Cast Member → Script`, set the script type popup to **Movie Script**.
2. Paste **`br4mp_bridge.ls`** — the whole file, configuration + transport + game glue in one
   script. There is then exactly one member to place and no cross-member handler resolution.
3. If you publish a `.dcr`, tick **Include in Shockwave** in that member's properties and keep
   it in the movie's internal cast.
4. Call it from the movie:

```lingo
-- main menu, "Online" button
BR4MPStart(1, 0, "city-1")        -- mode 1 = race, world 0 = City, track city-1

-- once per frame, after the car physics has run
-- (end of [PS] Advanced Car.ls "enterFrame", or a movie script "enterFrame")
BR4MPGameFrame()

-- chat input field
BR4MPChat("hello grid")

-- HUD text member that should show the newest chat line
BR4MPChatMember(member("status"))

-- leaving the online menu
BR4MPStop()
```

5. Verify from the Message window:

```lingo
put BR4MPDiagnostics()    -- ilk, version, baseURL, token, room, phase, rtt, last error
put BR4MPStart(0, 0, "")  -- free roam in City
put BR4MPStatusText()     -- e.g. "roam-w0-1 · LOBBY · lap 0/1 · 2p · 12ms"
```

## Install — three members

Same calls, but paste one file per Movie Script member, in this order:

| File | Purpose |
| --- | --- |
| `br4mp_config.ls` | server URL, identity, cadence, `gBR4MP` state, `BR4MPEnsure`, `BR4MPDiagnostics` |
| `br4mp_net.ls` | connect / poll / send, percent codec, line parser and dispatch |
| `br4mp_game.ls` | local car accessors, `STATE` uplink, remote cars, HUD |

`br4mp_bridge.ls` is generated from these three (`npm run build:lingo`), so the two install
styles can never drift apart.

## Version note (v1.1)

v1.0 initialised the global with `gBR4MP = gBR4MP or [:]`, which in Lingo turns the global into
`TRUE` and makes every later `gBR4MP.active` fail with *"handler not defined #Active"*. v1.1
uses `ilk(gBR4MP) <> #propList` instead (`BR4MPEnsure`), adds `BR4MPDiagnostics`, initialises
every state key up front, and removes speculative property probing from the car accessors. If
you pasted an earlier copy, replace the members.

## What the server does with the data

* **Movement** is validated, not simulated: the local car keeps its original hover physics.
  Beyond 95 m/s sustained or 55 m per update the server sends `COR` and eventually kicks the
  session ("Too many invalid state updates").
* **Gates, laps and finish order** are computed from the positions you send, so lap skipping
  does nothing.
* **Damage and pickups** are arbitrated from `HIT` / `ACTION` lines (free roam only).

## What to adapt to your build

Four accessors at the top of `br4mp_game.ls` (section "ADAPT"), each a single expression:

```lingo
on BR4MPLocalCar        -- the object the hover physics drives
  return gGame.me.car
end

on BR4MPLocalYaw        -- heading, radians (vector → degrees around Z, or a quaternion)
on BR4MPLocalSpeed      -- gGame.me.speed, m/s
on BR4MPLocalHealth     -- gGame.me.health
```

And one optional spawner:

```lingo
on BR4MPGameRemoteSpawn pRemote
  pRemote.mesh = gGame.world.SpawnTrafficCar(pRemote.id)   -- your traffic spawner
  return pRemote.mesh
end
```

By default it returns VOID: the roster, chat and race logic work, opponents are simply not
drawn.

## Not included

* Voice or music — out of scope.
* Account login / leaderboards — the server runs anonymous (`MP_ALLOW_ANONYMOUS=1`) and rooms
  are in-memory only.
* A lobby UI in the Director movie. The bridge exposes `gBR4MP.players`, `gBR4MP.phase`,
  `gBR4MP.lap`, `gBR4MP.standings` and `BR4MPStatusText()`; draw them with the existing HUD
  members or a simple `field` member during bring-up.

## Bring-up checklist

1. `put BR4MPDiagnostics()` runs and prints `gBR4MP ilk : #propList`.
2. `BR4MPStart(0, 0, "")` — in trace mode (`gBR4MP.trace = TRUE`) you see `WELCOME|i=…` and
   `JOINED|room=roam-w0-…`.
3. The local car moves and `/health` on the server shows one more player.
4. A second client (browser tab or a second Director copy) appears in `gBR4MP.remotes` and
   drives smoothly.
5. Chat works both ways; `/help` replies from the server.
6. `BR4MPStart(1, 0, "city-1")` starts a countdown and laps advance as you cross the gates.

## Static checks

```bash
cd multiplayer
npm run check:lingo   # every referenced handler is defined, every gBR4MP key initialised,
                      # ¬ placement, bridge in sync with the three sources
npm run build:lingo   # regenerate br4mp_bridge.ls
```
