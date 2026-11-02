# 04 — Web client

`packages/webclient` is a dependency-free browser harness: `index.html`, `style.css` and five ES
modules served straight from the server at `/`. It is not a port of the Shockwave renderer — it
is a top-down canvas view of the same world data, with the same netcode the Director build
uses. Two jobs:

1. **Reference client** — proves the protocol end to end, and is the fastest way to see a race,
   free roam, chat and the anti-cheat corrections.
2. **Test harness** — `tools/smoke-webclient.mjs` boots this exact code inside a DOM shim and
   `tools/headless-client.mjs` imports `net.js` + `sim.js` to generate load.

## Files

| File | Role |
| --- | --- |
| `index.html` | lobby, game screen (canvas `#stage`), HUD pills, race panel, chat, help overlay |
| `style.css` | layout and HUD styling, no frameworks |
| `src/app.js` | bootstrap, screen flow, message handling, input, HUD updates, chat, firing, invites |
| `src/net.js` | WebSocket transport: binary profile, `welcome`/`playerId`, ping/RTT, auto-reconnect with the resume token, state uplink helpers |
| `src/sim.js` | `Car` (arcade drift/nitro physics), `Interpolator` (120 ms remote buffer), `yawFromQuat` |
| `src/render.js` | canvas 2D renderer: grid, roads, route, gates, markers, pickups, cars, effects, compass |
| `src/ui.js` | DOM helpers: screens, pills, roster, chat log, standings, toasts, kill feed, help |

Modules import the protocol as `/lib/protocol/src/index.js`, which the server maps onto
`packages/protocol/dist` — the same build the server runs, so client and server can never drift.

## Boot sequence

1. `new Renderer(document.getElementById('stage'))`; catalog fetched from `/api/catalog`; room
   list from `/mp/rooms`.
2. Pressing **Race** or **Free roam** builds `app.profile` and calls
   `net.connect({ name, vehicle, world, track, trackId, mode, roomCode })`.
3. `Welcome` carries `playerId` (used as the local entity id) and `resumeToken`.
4. `Joined` carries the room, mode, track, lap count and the roster; the client loads
   `/data/worlds/<world>.json` and `/data/tracks/<track>.json` for rendering.
5. The 20 Hz uplink starts: `STATE` from the local `Car` with `seq`, `ackTick` and `health`.
   `Input` messages are sent as they change.
6. `Snapshot` entries are decoded, remote cars pushed into their `Interpolator`, the local entry
   used to detect disagreements with the prediction; `Correction` snaps the local car when the
   server disagrees by more than 20 m or with reason ≠ AntiCheat.

## Controls

| Key | Action |
| --- | --- |
| W / A / S / D | throttle / steer / reverse |
| Shift | drift |
| N | nitro |
| Space | fire the current weapon |
| Q | cycle weapon (MachineGun 95 m/6 dmg, RocketPod 260 m/34, MiniGun 85 m/3.5) |
| H | horn |
| E | emote |
| R | respawn |
| I | invite the room to a race, Y accept an invite |
| M | cycle minimap/zoom |
| Enter | chat, `?` help, Esc closes chat |

Mouse clicks on the canvas are ignored; the whole client is keyboard driven so it can be driven
headlessly.

## Netcode in the reference client

* **Local car** — simulated locally every animation frame at the `Car.step` timestep, no
  prediction/reconciliation beyond the corrections above. Movement authority is the client by
  design (see [01-architecture.md](01-architecture.md)).
* **Remote cars** — `Interpolator.sample(now, 120)` renders 120 ms in the past, which hides
  jitter and packet loss without rubber-banding.
* **Snapshots** — a delta entry is applied against the client's own copy of that entity's last
  absolute transform; `Absolute` entries replace it outright. Entries for unknown ids create an
  entity (a player who joined while the client was reconnecting).
* **Pickups** — collected locally within 12 m for responsiveness, then arbitrated with
  `Action: Pickup`; a rejected collect is undone by `PickupRespawn`.
* **Weapons** — `Action: FireWeapon` for the effect, `Hit` for the claim; the server decides
  damage.
* **Reconnect** — `net.js` retries with backoff and the resume token, so a laptop lid or a
  Wi-Fi blip returns to the same car, room and race position.

## Verifying it

```bash
# build + tests + static gate
npm run verify

# real server, then drive the actual client code headlessly
npm start &                    # http://localhost:8080
npm run check:webclient        # modules parse, DOM ids and imports resolve
npm run smoke:webclient -- --url http://localhost:8080 --seconds 10
npm run e2e                    # 3 headless cars race city-1 for 12 s
```

`smoke-webclient.mjs` stubs `document`, `canvas` and `localStorage`, rewrites the
`/lib/protocol/` import to the local `dist`, clicks Race, pumps frames and then asserts on what
the DOM would show: lobby list populated, game screen visible, roster pill updated, chat lines
received, ping measured, ≥100 canvas calls and a numeric speedometer. It is the check that
catches runtime wiring bugs (a renamed element id, a socket that never opens, a renderer that
throws on its first frame) — things a static parse cannot see.

`headless-client.mjs` is the load generator: it imports the real `net.js` and `sim.js`,
spawns N clients, drives them around a route at 20 Hz and prints joins, snapshot counts, phase
and lap per client, plus `/health` totals.

## Browser support

Any evergreen browser: native ES modules, WebSocket, canvas 2D, `fetch`. No build step, no
bundler, no polyfills. Served from the same origin as the server, so there is no CORS or proxy
involved; the WS URL is derived from `location`.
