# 06 — Transports, hosting and operations

## Running it

```bash
cd multiplayer
npm install            # node_modules is not committed
npm run build          # tsc -b for protocol + server
npm test               # 26 tests (protocol + server, includes a real WS/HTTP server)
npm start              # http://0.0.0.0:8080

# convenience
MP_PORT=9000 MP_BOTS=false npm start
npm run verify                        # tests + static webclient gate
npm run smoke:webclient -- --url http://localhost:8080   # boots the real client headlessly
npm run e2e                           # 3 headless cars racing city-1 for 12 s
```

`npm start` needs a build first; `npm run dev` builds and starts in one step. The server prints
the banner with every endpoint, the loaded worlds/tracks and the tick/snapshot rates.

Data (worlds, tracks) is committed under `multiplayer/data` and is produced by
`npm run import-data` from the original `Worlds/` assets. The server serves it at `/data/` and
advertises it at `/api/catalog`.

## Endpoints

| Path | What |
| --- | --- |
| `/` | web harness (`packages/webclient`) |
| `/mp/ws` | WebSocket, binary profile; `?profile=text` for the text framing over WS |
| `/mp/connect` | long-poll connect + join (`name`, `v`, `cv`, `veh`, `sk`, `m`, `w`, `tid`, `tok`); returns `WELCOME`/`JOINED`/roster/race state lines |
| `/mp/turn` | send + wait in one request (`token`, `d`, `wait`) |
| `/mp/poll` | held GET (`token`, `wait` ≤ 20 s) — returns queued lines or `OK|` |
| `/mp/send` | send lines without waiting (`token`, `d`) |
| `/mp/rooms` | JSON room list (`?mode=0|1`, default all) |
| `/mp/info` | JSON, same payload as `/health` |
| `/health` | JSON: sessions, players, rooms, stats, tick drift |
| `/metrics` | Prometheus text: `br4mp_sessions`, `br4mp_players`, `br4mp_rooms`, `br4mp_messages_in/out`, `br4mp_ticks`, `br4mp_tick_drift_ms` |
| `/api/catalog` | worlds + tracks with sizes, laps and checkpoint counts |
| `/data/…` | world/track JSON |
| `/lib/protocol/…` | the compiled protocol, so the browser and the server share one build |

Long-poll sessions are idle-disconnected after `MP_POLL_IDLE_MS` (25 s) without a request; the
resume token keeps the player for `MP_RESUME_WINDOW_MS` (60 s) either way.

## Configuration

| Variable | Default | Meaning |
| --- | --- | --- |
| `MP_PORT` | 8080 | HTTP/WS port |
| `MP_HOST` | 0.0.0.0 | bind address |
| `MP_SERVER_NAME` | `Burnin' Rubber 4 — Online` | banner + `Welcome.serverName` |
| `MP_TICK_RATE` | 20 | simulation ticks/s (10–60) |
| `MP_SNAPSHOT_RATE` | 20 | snapshots/s (5–30) |
| `MP_MAX_PLAYERS` | 32 | players per free-roam room (races cap at 12 grid slots) |
| `MP_MAX_ROOMS` | 64 | room ceiling |
| `MP_WARM_ROOMS` | 1 | free-roam rooms kept alive per world |
| `MP_ROOM_IDLE_MS` | 300000 | room idle timeout |
| `MP_MAX_SPEED` | 95 | m/s reference speed for the movement budget |
| `MP_MAX_TELEPORT` | 55 | max metres per state update |
| `MP_CHAT_HISTORY` | 50 | lines replayed to joiners |
| `MP_CHAT_MAX` | 200 | max chat length |
| `MP_POLL_TIMEOUT_MS` | 15000 | default long-poll hold |
| `MP_POLL_IDLE_MS` | 25000 | drop long-poll sessions that stop polling |
| `MP_RESUME_WINDOW_MS` | 60000 | session resume window |
| `MP_BOTS` | true | fill race lobbies with bots |
| `MP_BOTS_PER_RACE` | 3 | bots per race |
| `MP_ALLOW_ANONYMOUS` | true | allow connections without a ticket |
| `MP_ADMINS` | — | comma-separated names allowed to use `/kick` |
| `MP_TICKET_SECRET` | `dev-secret-change-me` | **change it** before exposing the server |
| `MP_DEBUG_AC` | — | log every anti-cheat strike with distance and player |

## Reverse proxy / TLS

Browsers refuse `ws://` from an `https://` page and Shockwave refuses mixed content too, so put
the server behind a proxy that terminates TLS:

```nginx
server {
  listen 443 ssl http2;
  server_name br4.example.com;
  # ssl_certificate ...; ssl_certificate_key ...;

  location / {
    proxy_pass http://127.0.0.1:8080;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_read_timeout 120s;        # > poll hold (15 s) and resume window
  }
}
```

Notes:

* Set `proxy_buffering off` if you want long-polls to flush as soon as they complete.
* Keep `proxy_read_timeout` above `MP_POLL_TIMEOUT_MS`, otherwise nginx kills every poll and
  Shockwave clients see a dozen reconnects a minute.
* The client derives its WS URL from `location`, so no configuration is needed after a proxy.
* One process serves every room; the tick loop is not clustered. For more capacity, run several
  processes on different ports and put players on a shard by world — rooms are in-memory, so a
  room cannot span processes.

### Docker

```dockerfile
FROM node:22-alpine
WORKDIR /app
COPY multiplayer/package*.json ./
RUN npm ci --omit=dev || npm install --omit=dev
COPY multiplayer/ ./
RUN npm run build
ENV MP_PORT=8080 MP_HOST=0.0.0.0
EXPOSE 8080
CMD ["node", "packages/server/dist/src/index.js"]
```

Healthcheck: `wget -qO- http://127.0.0.1:8080/health || exit 1`.

## Shockwave and cross-origin requests

Shockwave Player only loads movies and makes HTTP requests under the page's security rules. Two
workable setups:

1. **Same origin** (simplest): serve the `.dcr` and the multiplayer server from the same host,
   e.g. put the movie under `packages/webclient/` and use a relative `gBR4MP.baseURL = ""`.
2. **`crossdomain.xml`** at the server root (the static mount already serves `/`, so drop the
   file into `packages/webclient/`):

```xml
<?xml version="1.0"?>
<!DOCTYPE cross-domain-policy SYSTEM "http://www.adobe.com/xml/dtds/cross-domain-policy.dtd">
<cross-domain-policy>
  <allow-access-from domain="*" />
</cross-domain-policy>
```

The long-poll endpoints already send permissive CORS headers
(`Access-Control-Allow-Origin: *`, `GET/POST/OPTIONS`), so a browser-hosted client needs no
extra work.

## Capacity and measurements

* 20 Hz snapshots, deltas per viewer; a 20-player race is ≈300 B per client per snapshot
  (asserted in the test suite), so ~6 KB/s down and ~1 KB/s up per player at 20 Hz.
* Idle cost per room is one tick callback; snapshots are skipped when the room has no viewers.
* Verified locally: three clients + three bots in one race, 20 Hz, 246 snapshots each in 12 s,
  no anti-cheat corrections once the client adopts the server spawn.
* The server is single-threaded; the tick loop is a plain `setInterval` and drift is published
  as `br4mp_tick_drift_ms`. Watch it — sustained positive drift means the loop is
  oversubscribed.
* `/health` reports `sessions` (live sockets), `players` (players still in rooms, including
  detached ones inside the resume window) and the room list. After a load test you will briefly
  see `sessions: 0` with `players: N` — that is the resume window, not a leak; players drop when
  it expires and rooms with only bots idle out after 90 s.

## Known pitfalls

* **Player id collisions.** Session ids come from `GameServer`, room bots used to get ids from
  the room's own counter, so `room.players.set(id, bot)` could replace a human and route that
  human's state updates into the bot (symptom: an innocent client kicked with "Too many invalid
  state updates", strikes logged for a *bot* name at a constant ~1600 m distance). Bots now use
  ids ≥ 1 000 000 and `addPlayer` refuses to overwrite an existing id.
* **First state after join.** A client spawns on its own side, so the first update can be far
  from the server's spawn. It is accepted up to 400 m and corrected beyond that without a
  strike — do not "fix" this by counting strikes, or every rejoin starts at 1 strike.
* **Bursty transports.** HTTP long-poll delivers several states back to back. The movement
  guard is a distance token bucket (171 m/s refill, 75.6 m burst), not an implied-speed test.
* **`MP_DEBUG_AC=1` is the fastest debugging tool** for "I got kicked": it prints the player,
  the distance and the limit that was exceeded. Zero `[ac]` lines with kicks means the ids are
  crossed (see the first bullet).
* **Stale room counts.** Warm free-roam rooms always exist (`/health` shows them with
  `players: 0`); that is intentional and they are not counted as leaks.
* **Static 404s** for `/data/...` are case-sensitive: the extractor writes lowercase file names
  (`city.json`), while world *indexes* and display names are capitalised.
* **`npm start` before `npm run build`** fails on a fresh clone because `dist/` is not committed.
