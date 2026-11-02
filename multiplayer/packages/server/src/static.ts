import { createReadStream, existsSync, statSync } from 'node:fs';
import { extname, join, normalize, resolve } from 'node:path';
import type { IncomingMessage, ServerResponse } from 'node:http';

const MIME: Record<string, string> = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.map': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff2': 'font/woff2',
  '.txt': 'text/plain; charset=utf-8',
  '.d.ts': 'text/plain; charset=utf-8',
};

export interface Mount {
  prefix: string;
  root: string;
}

export function serveStatic(req: IncomingMessage, res: ServerResponse, mounts: Mount[], pathname: string): boolean {
  for (const mount of mounts) {
    if (!pathname.startsWith(mount.prefix)) continue;
    let rel = pathname.slice(mount.prefix.length);
    if (!rel || rel.endsWith('/')) rel += 'index.html';
    const safe = normalize(rel).replace(/^(\.\.[/\\])+/, '');
    const file = resolve(join(mount.root, safe));
    if (!file.startsWith(resolve(mount.root))) return false;
    if (!existsSync(file) || !statSync(file).isFile()) return false;
    const ext = extname(file).toLowerCase();
    res.writeHead(200, {
      'Content-Type': MIME[ext] ?? 'application/octet-stream',
      'Cache-Control': ext === '.html' ? 'no-cache' : 'public, max-age=60',
      'Access-Control-Allow-Origin': '*',
      'Cross-Origin-Resource-Policy': 'cross-origin',
    });
    createReadStream(file).pipe(res);
    return true;
  }
  return false;
}
