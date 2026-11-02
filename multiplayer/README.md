# Burnin' Rubber 4 — online multiplayer

A self-hosted multiplayer stack for the 2007 Shockwave racer **Burnin' Rubber 4**: online races
and free roam with chat, built around the original game instead of replacing it. The car physics
in `[PS] Advanced Car.ls` stay authoritative on the client; a Node server arbitrates everything
a player could cheat for — race position, damage, pickups.

Works with two clients:

* **browser** — a dependency-free canvas harness served by the server itself (`/`),
* **Director/Shockwave** — the original `.dcr` plus a Lingo bridge that speaks the text profile
  over HTTP long-polling (`lingo/patches/`).

## Quick start

```bash
cd multiplayer
npm install
npm run build
npm start                 # http://localhost:8080  (web harness + WS + long-poll)
```

Open `http://localhost:8080`, pick a name, press **Race** (bots fill the grid) or **Free roam**.

```bash
npm test                  # 26 tests: protocol + rooms + transport + static
npm run check:webclient   # static gate for the browser client
npm run smoke:webclient -- --url http://localhost:8080   # boots the real client headlessly
npm run e2e               # 3 headless cars race city-1 for 12 s
```

## Layout

```
packages/protocol/   wire format (binary + text), zero dependencies, shared by everyone
packages/server/     HTTP/WS/long-poll server, rooms, race + free-roam rules, bots
packages/webclient/  index.html + canvas renderer + net/sim/ui modules
tools/               data importer, static + runtime checks, headless load client
data/                worlds and tracks extracted from the original assets
lingo/patches/       Director bridge (config, transport, game glue)
docs/                architecture, protocol, server, webclient, Director, operations
```

## Documentation

| Doc | Contents |
| --- | --- |
| [01-architecture](docs/01-architecture.md) | authority split, tick loop, snapshot strategy, non-goals |
| [02-protocol](docs/02-protocol.md) | opcodes, message tables, quantisation, deltas, text profile |
| [03-server](docs/03-server.md) | sessions, rooms, race lifecycle, free roam, anti-cheat, bots |
| [04-webclient](docs/04-webclient.md) | modules, controls, netcode, how to verify it |
| [05-director-bridge](docs/05-director-bridge.md) | Lingo integration, hooks, failure modes |
| [06-operations](docs/06-operations.md) | endpoints, env vars, TLS/proxy, capacity, pitfalls |

## What works today

* Rooms: free roam per world and races per track, join/leave, roster, resume after a drop.
* Races: 12-slot grid, countdown, server-validated checkpoints and laps, standings, results,
  fill-in bots that race the same validated path.
* Free roam: shared pickups with server arbitration, weapon damage with lag compensation,
  kill feed, respawns, ram damage.
* Chat: channels, rate limits, history, `/help`, `/players`, `/me`, `/w`, `/r`, `/track`.
* Movement authority: distance-budget anti-cheat with corrections and a kick at 12 strikes.
* Data: City circuit (1451 m, 11 checkpoints, 3 laps) and three 2204 m sprints, extracted from
  the original `Worlds/` assets.

## Status

The server, protocol, browser client and the transport for Director are complete and tested;
the Director-side Lingo scripts are a reference implementation (they cannot be executed outside
Shockwave Player, so they are documented rather than unit-tested). Not included: accounts,
persistence, matchmaking, voice.
