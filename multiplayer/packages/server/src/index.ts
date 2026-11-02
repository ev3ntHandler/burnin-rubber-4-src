import { createApp } from './app.js';
import { loadConfig, readPackageVersion } from './config.js';
import { allTracks, allWorlds } from './data.js';

const config = loadConfig();
const version = readPackageVersion();
const { server, game, wss } = createApp(config, version);

server.listen(config.httpPort, config.host, () => {
  console.log(`
  ╔══════════════════════════════════════════════════════════════╗
  ║  Burnin' Rubber 4 — multiplayer server v${version}
  ║  ${config.serverName}
  ╚══════════════════════════════════════════════════════════════╝
  http://${config.host}:${config.httpPort}
    ws     ws://localhost:${config.httpPort}/mp/ws          (binary profile)
    ws     ws://localhost:${config.httpPort}/mp/ws?profile=text
    poll   /mp/connect /mp/turn /mp/poll /mp/send           (Lingo/Shockwave)
    web    /                                                (harness + chat)
    health /health   metrics /metrics   catalog /api/catalog
  tick ${config.tickRate} Hz · snapshots ${config.snapshotRate} Hz · max ${config.maxPlayersPerRoom}/room
  worlds: ${allWorlds().map((w) => w.world).join(', ')}
  tracks: ${allTracks().map((t) => `${t.id}(${t.length}m)`).join(', ')}
`);
  game.start();
});

let shuttingDown = false;
const shutdown = (signal: string) => {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log(`\n[${signal}] draining…`);
  game.stop();
  for (const room of game.rooms.values()) {
    room.systemChat('Server restarting — you will be reconnected automatically.');
  }
  wss.clients.forEach((client) => client.close(1001, 'server shutdown'));
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 4000).unref();
};

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
