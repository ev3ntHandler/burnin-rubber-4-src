import { createServer } from 'node:http';
import type { Server as HttpServer } from 'node:http';
import type { WebSocketServer } from 'ws';
import { GameServer } from './gameServer.js';
import { attachWebSocket } from './ws.js';
import { HttpApi, json, text } from './httpApi.js';
import { serveStatic } from './static.js';
import { allTracks, allWorlds } from './data.js';
import type { ServerConfig } from './config.js';

export interface App {
  server: HttpServer;
  game: GameServer;
  wss: WebSocketServer;
  api: HttpApi;
}

/** Wires HTTP + WebSocket + static + game loop into one server (used by index and tests). */
export function createApp(config: ServerConfig, version = '1.0.0'): App {
  const game = new GameServer(config);
  const api = new HttpApi(game, config);
  const mounts = [
    { prefix: '/lib/protocol/', root: config.protocolRoot },
    { prefix: '/data/', root: config.dataRoot },
    { prefix: '/', root: config.webRoot },
  ];

  const server = createServer(async (req, res) => {
    const url = new URL(req.url ?? '/', `http://${req.headers.host ?? 'localhost'}`);
    const path = url.pathname;

    if (path === '/health') {
      json(res, 200, { ok: true, version, uptime: Math.round(process.uptime()), ...game.describe() });
      return;
    }
    if (path === '/metrics') {
      const d = game.describe();
      text(
        res,
        200,
        [
          '# br4mp metrics (prometheus text format)',
          `br4mp_sessions ${game.sessionCount()}`,
          `br4mp_players ${game.playerCount()}`,
          `br4mp_rooms ${game.rooms.size}`,
          `br4mp_messages_in ${game.stats.messagesIn}`,
          `br4mp_messages_out ${game.stats.messagesOut}`,
          `br4mp_ticks ${game.stats.ticks}`,
          `br4mp_tick_drift_ms ${Math.round((d.tickDriftMs as number) ?? 0)}`,
        ].join('\n') + '\n',
      );
      return;
    }
    if (path === '/api/catalog') {
      json(res, 200, {
        worlds: allWorlds().map((w) => ({
          index: w.worldIndex,
          name: w.world,
          spawn: w.spawn,
          markers: w.markers.length,
          roads: w.roads.length,
        })),
        tracks: allTracks().map((t) => ({
          id: t.id,
          name: t.name,
          world: t.world,
          worldIndex: t.worldIndex,
          length: t.length,
          type: t.type,
          totalLaps: t.totalLaps,
          checkpoints: t.checkpoints.length,
        })),
      });
      return;
    }

    if (await api.handle(req, res, url)) return;
    if (serveStatic(req, res, mounts, path)) return;
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('not found');
  });

  const wss = attachWebSocket(server, game);
  return { server, game, wss, api };
}
