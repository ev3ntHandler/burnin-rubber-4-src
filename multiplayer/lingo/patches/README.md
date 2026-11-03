# Lingo patches — online bridge for the Director build

These three movie scripts give the original Shockwave build an online mode that talks to
`packages/server`. They use the **text profile** over HTTP long-polling, because Shockwave
Player gives Lingo `getNetText` / `postNetText` and nothing else — no WebSocket, no binary
frames. Protocol reference: [docs/02-protocol.md](../../docs/02-protocol.md#5-text-profile).
Integration notes: [docs/05-director-bridge.md](../../docs/05-director-bridge.md).

| File | Paste as | Purpose |
| --- | --- | --- |
| `br4mp_config.ls` | movie script | server URL, identity, cadence, all runtime state in `gBR4MP` |
| `br4mp_net.ls` | movie script | connect / poll / send, percent codec, line parser and dispatch |
| `br4mp_game.ls` | movie script | reads the local car, sends `STATE`, spawns and animates remote cars, HUD |

They are deliberately dependency free and self-contained: no external casts, no Xtras, no
`.ls` includes. Copy them into a new cast (`File → New → Cast`), then paste each into a movie
script cast member.

## Install

1. Copy the three `.ls` files into a movie script cast, in the order listed above.
2. Add the calls below. Everything is guarded by `BR4MPActive()`, so the single-player game is
   unchanged when online is not started.
3. Start the server (`npm start` in `multiplayer/`, or a deployed instance) and point
   `gBR4MP.baseURL` at it in `br4mp_config.ls`.
4. If the movie is embedded in a browser page on a different host than the server, add a
   `crossdomain.xml` (or serve both from the same origin) — see
   [docs/06-operations.md](../../docs/06-operations.md#shockwave-and-cross-origin-requests).

## Version note (v1.1)

Two Lingo-specific fixes, both of which showed up as script errors during bring-up:

* **Globals are per handler.** `global gBR4MP` must appear inside every handler that touches
  it, not once at the top of the script. Without it, `gBR4MP` is an unassigned local and
  Director reports *"variable used before assigned a value"* — typically on the `STATE` line in
  `BR4MPUplink`.
* **`gBR4MP = gBR4MP or [:]` is wrong.** `or` is boolean/bitwise in Lingo, so it yields `TRUE`
  and every later `gBR4MP.active` is read as a handler lookup (*"handler not defined #Active"*).
  v1.1 initialises with a plain `gBR4MP = [:]`.
* **Dot syntax does not create properties.** On a fresh `[:]`, `pList.newKey = x` raises
  *"Property not found #newKey"*. Keys must be created with `setProp(pList, #key, value)` or
  bracket syntax; every key is created that way in `BR4MPDefaults`, and remote/roster/chat rows
  are built as complete `[#id: ..., #pos: ...]` literals, so the rest of the bridge can use
  ordinary `gBR4MP.key` access.

**There is no `else if` in Lingo.** The keyword does not exist in this Director build (and in
classic Lingo generally): an `else if` chain fails with *"errors here at end, expected end if"*.
Write either a nested block

```lingo
if a then
  ...
else
  if b then
    ...
  end if
end if
```

or a `case` statement, which the movie itself uses in 26 scripts. Every branch in these three
files is block form - no `else if`, and no one-line `if ... then statement` either (the movie's
own scripts contain none, and this parser rejects them).

**The runtime implements what the movie itself uses, and little else.** `round()` is not in
its function table - it raises *"Handler not defined #round"* - so `BR4MPRound()` (built on
`integer()`) does the rounding, and `BR4MPHasBit()` does the arithmetic that `bitAnd()` would.
**Property lists reject integer keys.** `pList[14] = x` raises *"Index out of range"* - the
runtime treats a numeric key as a linear index. Player records are therefore stored under symbol
keys built by `BR4MPKey(id)` (`#p14`), which is also what `deleteProp` is given on leave.

`getPropList()` is missing too: walk property lists with `count` + `getPropAt(i)` (which returns
the *key* at position i - the same pattern `[M] 3D Particles.ls` uses). `sin`, `cos`, `atan`,
`pi`, `sqrt`, `integer`, `abs`, `string`, `the milliseconds`, `getProp`, `postNetText`,
`charToNum` and `numToChar` are all present. If you add handlers, stick to functions the shipped
scripts already call.

The uplink also builds its `STATE` line one statement at a time instead of using `¬`
continuations, so a paste that mangles a continuation character cannot break the compile.

Verify an install from the Message window at any time:

```lingo
put BR4MPDiagnostics()   -- ilk(gBR4MP) must be #propList, plus URL/token/room/phase/rtt
```

## Hook points (verified against the shipped movie)

The three edits below are the only ones the movie needs. Each is a single line (or two) in an
existing handler; no new cast members.

**1. Frame pump - `[PS] Advanced Car.ls`, first lines of `on enterFrame me`**

```lingo
on enterFrame me
  t = gGame.vehicles[p.tag]
  if t.general.controller = #player then BR4MPGameFrame
  ... existing body ...
```

Put it *at the top*, not at the end: this handler returns early for a destroyed car
(`if t.Vehicle.Health = 0 then return 0`) and `exit`s out of its state loop, so anything appended
to the bottom stops running as soon as the car explodes or a state handles the frame. The
`#player` guard matters too - `enterFrame` is the car script, so it runs once per vehicle
instance (AI and traffic included). `BR4MPGameFrame` also ignores repeat calls inside the same
millisecond, so the guard is belt-and-braces.

**2. Joining online - `MenuEvents.txt`, end of the `StartGame_Begin` block**

`MenuEvents.txt` is *data* parsed by `[M] Event Manager.ls`, not Lingo: fields are TAB separated
and every command is dispatched as `sendSprite(0, #Handler, tTarget, tDataList)`, i.e. with two
arguments. So a three-argument `BR4MPStart 0 0 ""` cannot be called from there. Use the
two-argument wrapper instead (TABs, like `PutMessage`):

```
BR4MPOnline	0	[#mode: 0, #world: 0, #track: ""]
```

**3. Leaving - `[M] Init Game.ls`, first line of `on stopMovie me`**

```lingo
on stopMovie me
  BR4MPStop
  if _player.runMode = "Plugin" then
    return 0
  end if
```

It has to be the first statement: in Plugin (Shockwave) mode the handler returns before doing
anything, and the `ResetEngine()`/`reset()` calls further down can cancel still-pending nets, so
the `LEAVE` would never leave.

**Menu-driven calls (all optional)**

```lingo
BR4MPStart(1, 0, "city-1")        -- mode 1 = race, world 0 = City, track city-1
BR4MPChat("hello grid")
BR4MPChatMember(member("status")) -- HUD text member showing the newest chat line
BR4MPStop
```

`BR4MPGameFrame` does four things per frame: pumps the completed HTTP requests, sends a `STATE`
line every 50 ms, pings every 2.5 s, and eases the remote cars towards their last snapshot.

## What the server does with the data

* **Movement** is validated, not simulated: the local car keeps its original hover physics.
  Beyond 95 m/s sustained or 55 m per update the server sends `COR` and eventually kicks the
  session ("Too many invalid state updates").
* **Gates, laps and finish order** are computed from the positions you send, so lap skipping
  does nothing.
* **Damage and pickups** are arbitrated from `HIT` / `ACTION` lines (free roam only).

## Things to adapt to your build

Only the "ADAPT" block in `br4mp_game.ls` assumes anything about the movie, and it now matches
the shipped Director source:

* `BR4MPLocalVehicle()` — the player's vehicle record:
  `gGame.vehicles[gGame.CurrentVehicle]`, falling back to `gGame.vehicles[1]` (tag 1 is the car
  created first, i.e. the player's).
* `BR4MPLocalTransform()` — `t.Vehicle.Proxy.transform` (metres, Z-up); corrections are written
  straight back to this transform's `position`.
* `BR4MPLocalYaw()` — heading in radians, computed the way `Advanced Car` computes its forward
  vector: rotate `(0,1,0)` by the car transform, `atan2(y, x)`.
* `BR4MPLocalSpeed()` / `BR4MPLocalHealth()` — `t.Vehicle.Speed` / `t.Vehicle.Health` (sent as
  magnitudes).
* `BR4MPLocalVelocity()` — derived from speed and heading.

If your build names these fields differently, edit those six handlers and nothing else.

And one optional spawner:

* `BR4MPGameRemoteSpawn()` — asks `gGame.world.SpawnCarMesh(id)` for a car model. If your build
  has a different traffic-car factory, create the clone there and return the mesh; otherwise the
  roster still works but opponents are invisible.

## Not included

* Voice or music — out of scope.
* Account login / leaderboards — the server runs anonymous (`MP_ALLOW_ANONYMOUS=1`) and rooms
  are in-memory only.
* A lobby UI in the Director movie. The bridge exposes `gBR4MP.players`, `gBR4MP.phase`,
  `gBR4MP.lap`, `gBR4MP.standings` and `BR4MPStatusText()`; draw them with the existing HUD
  members or a simple `field` member during bring-up.

## Bring-up checklist

1. `BR4MPDefaults` runs without script errors (check the message window).
2. `BR4MPStart(0, 0, "")` logs `WELCOME|i=…` and `JOINED|room=roam-w0-…` in trace mode
   (`gBR4MP.trace = TRUE`).
3. The local car moves in the game and `/health` shows one more player.
4. A second client (browser tab or a second Director copy) appears in `gBR4MP.remotes` and
   drives smoothly.
5. Chat reaches both directions; `/help` replies from the server.
6. `BR4MPStart(1, 0, "city-1")` starts a countdown, and laps advance as you cross the gates.
