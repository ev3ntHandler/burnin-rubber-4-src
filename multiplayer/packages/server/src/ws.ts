import type { Server as HttpServer, IncomingMessage } from 'node:http';
import { WebSocketServer, WebSocket } from 'ws';
import {
  decodeClientMessage,
  decodeClientText,
  encodeServerMessage,
  encodeServerText,
  ErrorCode,
  Op,
} from '@br4mp/protocol';
import type { ClientMessage, ConnectMsg, ServerMessage } from '@br4mp/protocol';
import type { GameServer, Session } from './gameServer.js';
import type { Connection } from './types.js';
import { tokenBucket } from './types.js';

const MAX_FRAME = 64 * 1024;
const MAX_MESSAGES_PER_SECOND = 180;

export function attachWebSocket(server: HttpServer, game: GameServer): WebSocketServer {
  const wss = new WebSocketServer({
    server,
    path: '/mp/ws',
    maxPayload: MAX_FRAME,
    perMessageDeflate: { threshold: 256, zlibDeflateOptions: { level: 6 } },
  });

  wss.on('connection', (socket: WebSocket, req: IncomingMessage) => {
    const url = new URL(req.url ?? '/mp/ws', 'http://localhost');
    const profile = url.searchParams.get('profile') === 'text' ? 'text' : 'binary';
    const bucket = tokenBucket(MAX_MESSAGES_PER_SECOND, MAX_MESSAGES_PER_SECOND * 2);
    let session: Session | null = null;
    let closed = false;

    const conn: Connection = {
      kind: 'ws',
      remote: req.socket.remoteAddress ?? 'unknown',
      send(msg: ServerMessage) {
        if (closed || socket.readyState !== WebSocket.OPEN) return;
        game.stats.messagesOut++;
        if (profile === 'binary') {
          socket.send(encodeServerMessage(msg), { binary: true });
        } else {
          socket.send(encodeServerText(msg).join('\n'));
        }
      },
      close(reason?: string) {
        closed = true;
        try {
          socket.close(4000, reason?.slice(0, 100));
        } catch {
          /* ignore */
        }
      },
      isOpen() {
        return !closed && socket.readyState === WebSocket.OPEN;
      },
    };

    socket.on('message', (data: Buffer | ArrayBuffer | Buffer[], isBinary: boolean) => {
      if (!bucket.allow()) {
        conn.send({ op: Op.Error, code: ErrorCode.RateLimited, message: 'Too many messages.' });
        return;
      }
      let messages: ClientMessage[] = [];
      try {
        if (isBinary) {
          const buf = Array.isArray(data) ? Buffer.concat(data) : Buffer.from(data as ArrayBuffer);
          messages = [decodeClientMessage(new Uint8Array(buf))];
        } else {
          messages = decodeClientText(data.toString());
        }
      } catch (err) {
        conn.send({
          op: Op.Error,
          code: ErrorCode.BadRequest,
          message: `Malformed message: ${(err as Error).message}`,
        });
        return;
      }

      for (const msg of messages) {
        try {
          if (!session) {
            if (msg.op !== Op.Connect) {
              conn.send({
                op: Op.Error,
                code: ErrorCode.AuthFailed,
                message: 'Send CONNECT first.',
              });
              continue;
            }
            const result = game.connect(conn, msg as ConnectMsg);
            if ('error' in result) {
              conn.send({
                op: Op.Error,
                code: result.error,
                message: result.message ?? 'Connection rejected.',
              });
              conn.close('rejected');
              return;
            }
            session = result;
            game.welcome(session);
            continue;
          }
          game.handle(session, msg);
        } catch (err) {
          console.error('[ws] handler error', err);
        }
      }
    });

    socket.on('close', () => {
      closed = true;
      if (session) game.disconnect(session);
    });
    socket.on('error', () => {
      closed = true;
      if (session) game.disconnect(session);
    });

    socket.send(
      JSON.stringify({
        hello: 'br4mp',
        profile,
        hint: 'send CONNECT (binary or text profile) to start',
      }),
    );
  });

  return wss;
}
