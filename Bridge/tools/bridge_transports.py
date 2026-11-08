"""Transport adapters for the bridge, shared by the mock peers and the CLI tools.

Each adapter moves *protocol batches* (see PROTOCOL.md §7) between two peers. They are the
runnable counterpart of ``bridge_transport_files.gd`` / ``_http.gd`` / ``_tcp.gd`` in the Godot
addon and of the ``files`` / ``http`` transports in ``[M] Shockwave Bridge.ls``.

Role split: ``files`` is symmetric (each peer owns one direction's file pair); ``http`` and
``tcp`` have a server side (normally Godot) and a client side (normally Director).
"""

from __future__ import annotations

import json
import os
import socket
import threading
import time
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any, Callable, Dict, List, Optional, Tuple
from urllib.parse import parse_qs, quote, unquote

from bridge_proto import Batch, pack, unpack, write_frame, read_frame

FILES_OUT = {"director": "d2g.txt", "godot": "g2d.txt"}
FILES_IN = {"director": "g2d.txt", "godot": "d2g.txt"}


class Transport:
    """Base: ``start()`` wires the transport into the peer as its ``emit`` target."""

    name = "base"

    def start(self) -> None:
        peer = getattr(self, "peer", None)
        if peer is not None:
            peer._transport = self

    def stop(self) -> None:
        pass

    def send(self, batch: Batch) -> None:
        raise NotImplementedError

    def poll(self) -> Optional[Batch]:
        """Return the next received batch, or None."""
        return None

    def reset_inbound(self) -> None:
        """Forget the inbound frame position. Called when the peer restarts (see ``Peer.reset_inbound``).

        Streaming transports have no frame-seq gate at all, so this is a no-op for them; only the
        file mailbox remembers a seq across frames and therefore needs to be told to forget it.
        """

    def status(self) -> Dict[str, Any]:
        return {"transport": self.name}


# --------------------------------------------------------------------------------------------
# §7.1 files
# --------------------------------------------------------------------------------------------


class FilesTransport(Transport):
    """Append-free whole-file mailbox with a commit marker; torn reads just retry."""

    name = "files"

    def __init__(self, peer: Any, root: str, crc: bool = True):
        self.peer = peer
        self.out_path = os.path.join(root, FILES_OUT[peer.cfg.role])
        self.in_path = os.path.join(root, FILES_IN[peer.cfg.role])
        self.crc = crc
        self.last_in_seq = -1
        self.last_out_seq = -1
        self.bytes_written = 0
        self.polls = 0
        self.torn = 0
        os.makedirs(root, exist_ok=True)

    def send(self, batch: Batch) -> None:
        payload = batch.to_bytes()
        if not payload:
            return
        self.last_out_seq += 1
        write_frame(self.out_path, payload, self.last_out_seq, crc=self.crc)
        self.bytes_written += len(payload)

    def poll(self) -> Optional[Batch]:
        self.polls += 1
        before = self.last_in_seq
        result = read_frame(self.in_path, self.last_in_seq)
        if result is None:
            if os.path.exists(self.in_path) and os.path.exists(self.in_path[: -len(".txt")] + ".seq"):
                self.torn += 1
                self.peer.stats["torn"] += 1
            return None
        seq, batch = result
        self.last_in_seq = seq
        del before
        return batch

    def reset_inbound(self) -> None:
        # The peer's counter is starting over, so "I have already applied frame N" is a statement
        # about a session that no longer exists. Forget it and the next frame is new again.
        self.last_in_seq = -1

    def status(self) -> Dict[str, Any]:
        return {
            "transport": "files",
            "out": os.path.relpath(self.out_path),
            "in": os.path.relpath(self.in_path),
            "polls": self.polls,
            "torn": self.torn,
            "bytes": self.bytes_written,
        }


# --------------------------------------------------------------------------------------------
# §7.2 http
# --------------------------------------------------------------------------------------------


class HttpServerTransport(Transport):
    """Minimal HTTP/1.1 responder used by the Godot side (and the mock).

    GET  /bridge/poll?wait=<ms>   long-poll; answers as soon as a batch is queued
    POST /bridge/push             body = one percent-encoded batch
    GET  /bridge/state            JSON mirror, for a browser or curl
    GET  /bridge/handshake        one-line capability advertisement
    """

    name = "http"

    def __init__(self, peer: Any, host: str = "127.0.0.1", port: int = 7778):
        self.peer = peer
        self.host = host
        self.port = port
        self.queue: List[Batch] = []
        self.condition = threading.Condition()
        self.httpd: Optional[ThreadingHTTPServer] = None
        self.thread: Optional[threading.Thread] = None
        self.served = 0
        self.pushes = 0

    def start(self) -> None:
        super().start()
        outer = self

        class Handler(BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"
            server_version = "ShockwaveBridge/1"

            def log_message(self, *args: Any) -> None:
                pass

            def reply(self, body: bytes, kind: str = "text/plain", code: int = 200) -> None:
                self.send_response(code)
                self.send_header("Content-Type", kind + "; charset=utf-8")
                self.send_header("Content-Length", str(len(body)))
                self.send_header("Cache-Control", "no-store")
                self.end_headers()
                self.wfile.write(body)

            def do_GET(self) -> None:
                path, _, query = self.path.partition("?")
                params = {key: values[0] for key, values in parse_qs(query).items()}
                if path.endswith("/handshake"):
                    self.reply(("godot proto=1 role=%s caps=%s" % (outer.peer.cfg.name, ",".join(outer.peer.cfg.caps))).encode())
                    return
                if path.endswith("/state"):
                    indent = 1 if "pretty" in params else None
                    self.reply(json.dumps(_state_json(outer.peer), indent=indent).encode(), "application/json")
                    return
                if path.endswith("/push"):
                    # Director's NetLingo can only GET: the batch arrives percent-encoded in `?b=`
                    outer.pushes += 1
                    outer.peer.feed_batch(Batch.from_text(unquote(params.get("b", ""))))
                    outer.peer.flush()
                    self.reply(b"ok")
                    return
                if not path.endswith("/poll"):
                    self.reply(b"not found", "text/plain", 404)
                    return
                deadline = time.time() + max(0.0, float(params.get("wait", "1500"))) / 1000.0
                batch: Optional[Batch] = None
                while batch is None:
                    with outer.condition:
                        if outer.queue:
                            batch = outer.queue.pop(0)
                    if batch is not None or time.time() >= deadline:
                        break
                    time.sleep(0.0005)
                outer.served += 1
                self.reply((batch.to_bytes() if batch else b""))

            def do_POST(self) -> None:
                if not self.path.partition("?")[0].endswith("/push"):
                    self.reply(b"not found", "text/plain", 404)
                    return
                length = int(self.headers.get("Content-Length") or "0")
                raw = self.rfile.read(length).decode("utf-8", "replace") if length else ""
                outer.pushes += 1
                outer.peer.feed_batch(Batch.from_text(unquote(raw)))
                outer.peer.flush()
                self.reply(b"ok")

        self.httpd = ThreadingHTTPServer((self.host, self.port), Handler)
        self.httpd.daemon_threads = True
        self.thread = threading.Thread(target=self.httpd.serve_forever, kwargs={"poll_interval": 0.02}, daemon=True)
        self.thread.start()

    def stop(self) -> None:
        if self.httpd:
            self.httpd.shutdown()
            self.httpd.server_close()
            self.httpd = None

    def send(self, batch: Batch) -> None:
        if not batch:
            return
        with self.condition:
            for chunk in batch.chunk():
                self.queue.append(chunk)
            self.condition.notify_all()

    def status(self) -> Dict[str, Any]:
        return {
            "transport": "http",
            "role": "server",
            "url": "http://%s:%d/bridge/" % (self.host, self.port),
            "pollsServed": self.served,
            "pushes": self.pushes,
            "queued": len(self.queue),
        }


class HttpClientTransport(Transport):
    """The Director pattern: exactly one in-flight long-poll, re-armed on completion."""

    name = "http"

    def __init__(self, peer: Any, base: str = "http://127.0.0.1:7778/bridge", wait_ms: int = 1500, timeout: float = 3.0):
        self.peer = peer
        self.base = base.rstrip("/")
        self.wait_ms = wait_ms
        self.timeout = timeout
        self.incoming: List[Batch] = []
        self.connection: Optional[HTTPConnection] = None
        self.pushes = 0
        self.polls = 0
        self.errors = 0

    def _host_port(self) -> Tuple[str, int]:
        rest = self.base.partition("://")[2]
        authority, _, _path = rest.partition("/")
        host, _, port = authority.partition(":")
        return host, int(port or 80)

    def _connection_or_new(self) -> HTTPConnection:
        if self.connection is None:
            host, port = self._host_port()
            self.connection = HTTPConnection(host, port, timeout=self.timeout)
        return self.connection

    def _call(self, method: str, path: str, body: str = "") -> str:
        prefix = self.base.partition("://")[2].partition("/")[2]
        url = "/" + prefix + path if prefix else path
        for attempt in (0, 1):
            try:
                connection = self._connection_or_new()
                headers = {"User-Agent": "shockwave-bridge/1", "Connection": "keep-alive"}
                if body:
                    headers["Content-Type"] = "text/plain; charset=utf-8"
                    headers["Content-Length"] = str(len(body.encode("utf-8")))
                connection.request(method, url, body=body.encode("utf-8") if body else None, headers=headers)
                response = connection.getresponse()
                data = response.read().decode("utf-8", "replace")
                if response.status != 200:
                    raise OSError("http %d" % response.status)
                return data
            except OSError:
                self.errors += 1
                self.reset()
                self.peer._hello_sent = False
                if attempt:
                    return ""
        return ""

    def reset(self) -> None:
        if self.connection:
            try:
                self.connection.close()
            except Exception:
                pass
        self.connection = None

    def send(self, batch: Batch) -> None:
        for chunk in batch.chunk():
            payload = chunk.to_bytes()
            if not payload:
                continue
            self.pushes += 1
            self._call("POST", "/push?n=%d" % self.pushes, quote(payload, safe=""))

    def poll(self) -> Optional[Batch]:
        if self.incoming:
            return self.incoming.pop(0)
        self.polls += 1
        text = self._call("GET", "/poll?wait=%d&ack=%d" % (self.wait_ms, self.peer.in_seq))
        if not text.strip():
            return None
        batch = Batch.from_text(unquote(text) if "%" in text else text)
        return batch if len(batch) else None

    def status(self) -> Dict[str, Any]:
        return {"transport": "http", "role": "client", "base": self.base, "polls": self.polls, "pushes": self.pushes, "errors": self.errors}


# --------------------------------------------------------------------------------------------
# §7.3 tcp
# --------------------------------------------------------------------------------------------


class TcpServerTransport(Transport):
    name = "tcp"

    def __init__(self, peer: Any, host: str = "127.0.0.1", port: int = 7777, binary: bool = False):
        self.peer = peer
        self.host = host
        self.port = port
        self.binary = binary
        self._listener: Optional[socket.socket] = None  # noqa: E501
        self._thread: Optional[threading.Thread] = None
        self._client: Optional[socket.socket] = None
        self._send_lock = threading.Lock()
        self._incoming: List[Batch] = []
        self._stop = threading.Event()
        self.clients = 0
        self.idle_drops = 0

    def start(self) -> None:
        super().start()
        self._listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self._listener.bind((self.host, self.port))
        self._listener.listen(4)
        self._thread = threading.Thread(target=self._serve, daemon=True)
        self._thread.start()

    def _serve(self) -> None:
        assert self._listener is not None
        self._listener.settimeout(0.25)
        while not self._stop.is_set():
            try:
                client, _addr = self._listener.accept()
            except socket.timeout:
                continue
            except OSError:
                break
            self.clients += 1
            self._client = client
            # a fresh client means we may have dropped our HELLO while it was not connected yet
            if getattr(self.peer, "_transport", None) is self:
                self.peer._hello_sent = False
            client.settimeout(0.15)
            threading.Thread(target=self._session, args=(client,), daemon=True).start()

    def _session(self, client: socket.socket) -> None:
        buffer = b""
        while not self._stop.is_set():
            try:
                chunk = client.recv(65536)
            except socket.timeout:
                self._pump(client)
                continue
            except OSError:
                break
            if not chunk:
                break
            buffer += chunk
            if self.binary:
                frames, buffer = unpack(buffer)
                for frame in frames:
                    self._take(frame)
            else:
                while b"\n" in buffer:
                    line, _, buffer = buffer.partition(b"\n")
                    if line.strip():
                        self._take(line + b"\n")
        with self._send_lock:
            if self._client is client:
                self._client = None

    def _take(self, data: bytes) -> None:
        self._incoming.append(Batch.from_bytes(data))

    def _pump(self, client: socket.socket) -> None:
        pass

    def stop(self) -> None:
        self._stop.set()
        if self._client:
            try:
                self._client.close()
            except OSError:
                pass
        if self._listener:
            self._listener.close()
            self._listener = None

    def send(self, batch: Batch) -> None:
        payload = batch.to_bytes()
        if not payload:
            return
        if self._client is None:
            self.idle_drops += 1
            return
        data = pack(payload) if self.binary else payload
        with self._send_lock:
            try:
                self._client.sendall(data)
            except OSError:
                pass

    def poll(self) -> Optional[Batch]:
        """One batch per call, containing *everything* received so far.

        A peer pumps this once per frame, so draining fully here is what keeps an RPC reply from
        queueing behind the six snapshot lines that arrived in the same segment (§8). Handing back
        one line at a time would make each frame cost a frame of latency, and a burst would never
        catch up. Lines stay in order, so a whole batch is still processed top to bottom.
        """
        if not self._incoming:
            return None
        lines = [line for batch in self._incoming for line in batch]
        self._incoming.clear()
        return Batch(lines)

    def status(self) -> Dict[str, Any]:
        return {
            "transport": "tcp",
            "role": "server",
            "listen": "%s:%d" % (self.host, self.port),
            "clients": self.clients,
            "connected": self._client is not None,
            "binary": self.binary,
        }


class TcpClientTransport(Transport):
    name = "tcp"

    #: a stalled reader must not grow our send backlog without bound (§7.3 has no back-pressure)
    max_pending_bytes = 262144

    def __init__(self, peer: Any, host: str = "127.0.0.1", port: int = 7777, binary: bool = False, retry_ms: int = 1000):
        self.peer = peer
        self.host = host
        self.port = port
        self.binary = binary
        self.retry_ms = retry_ms
        self._socket: Optional[socket.socket] = None
        self._buffer = b""
        self._out_pending = b""
        self._incoming: List[Batch] = []
        self._last_try = 0
        self.attempts = 0
        self.dropped = 0
        self.retries = 0

    def _ensure(self) -> bool:
        if self._socket is not None:
            return True
        now = time.time() * 1000
        if now - self._last_try < self.retry_ms:
            return False
        self._last_try = now
        self.attempts += 1
        try:
            self._socket = socket.create_connection((self.host, self.port), timeout=0.25)
            # non-blocking for the recv in poll(); writes are handled by write() below, which
            # never uses sendall(): on a non-blocking socket that raises half way through a batch
            # and would leave a torn line on the wire.
            self._socket.setblocking(False)
            self.peer._hello_sent = False  # we were not connected when it was queued
            return True
        except OSError:
            self._socket = None
            return False

    def write(self, data: bytes) -> bytes:
        """Write what the kernel accepts, return whatever it did not. Order is always preserved."""
        if self._out_pending:
            data = self._out_pending + data
            self._out_pending = b""
        socket_ = self._socket
        if socket_ is None:
            self._out_pending = data
            return b""
        while data:
            try:
                sent = socket_.send(data)
            except (BlockingIOError, InterruptedError):
                self.retries += 1
                break
            except OSError:
                self._reset()
                break
            if sent <= 0:
                break
            data = data[sent:]
        if len(data) > self.max_pending_bytes:
            # Partial drops would break LF framing, so throw the link away instead and let
            # _ensure() reconnect and re-send HELLO. Nothing is ever silently corrupted.
            self.dropped += 1
            data = b""
            self._reset()
        self._out_pending = data
        return b""

    def flush_pending(self) -> None:
        if self._out_pending and self._ensure():
            self.write(b"")

    def _consume(self, chunk: bytes) -> None:
        self._buffer += chunk
        if self.binary:
            frames, self._buffer = unpack(self._buffer)
            for frame in frames:
                self._incoming.append(Batch.from_bytes(frame))
        else:
            while b"\n" in self._buffer:
                line, _, self._buffer = self._buffer.partition(b"\n")
                if line.strip():
                    self._incoming.append(Batch([line.decode("utf-8", "replace")]))

    def send(self, batch: Batch) -> None:
        payload = batch.to_bytes()
        if not payload:
            return
        if not self._ensure():
            self.dropped += 1
            return
        self.write(pack(payload) if self.binary else payload)

    def _reset(self) -> None:
        if self._socket:
            try:
                self._socket.close()
            except OSError:
                pass
        self._socket = None
        self._buffer = b""
        # _out_pending deliberately survives: the next _ensure() reconnects, re-sends HELLO and
        # flushes it, so a blip costs latency and never a lost command.

    def poll(self) -> Optional[Batch]:
        """Drain everything the socket will give up right now and hand it over as one batch.

        Same rule as the server side: one poll per frame, so a burst must be consumed in full or
        replies fall a frame behind per line. Non-blocking recv returns immediately when the
        buffer is empty, which keeps the movie's frame loop unblocked (§6).
        """
        if not self._ensure():
            return None
        if self._out_pending:
            self.write(b"")
        for _ in range(16):  # bounded: a chatty peer can never starve the frame loop
            try:
                chunk = self._socket.recv(65536)
            except BlockingIOError:
                break
            except OSError:
                self._reset()
                break
            if not chunk:
                self._reset()
                break
            self._consume(chunk)
        if not self._incoming:
            return None
        lines = [line for batch in self._incoming for line in batch]
        self._incoming.clear()
        return Batch(lines)

    def status(self) -> Dict[str, Any]:
        return {
            "transport": "tcp",
            "role": "client",
            "target": "%s:%d" % (self.host, self.port),
            "connected": self._socket is not None,
            "attempts": self.attempts,
            "droppedWhileDown": self.dropped,
            "binary": self.binary,
        }


# --------------------------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------------------------


def _state_json(peer: Any) -> Dict[str, Any]:
    def plain(value: Any) -> Any:
        from bridge_proto import VOID as _VOID, Symbol as _Symbol

        if value is _VOID:
            return None
        if isinstance(value, _Symbol):
            return "#" + str(value.name)
        if isinstance(value, dict):
            return {str(k): plain(v) for k, v in value.items()}
        if isinstance(value, (list, tuple)):
            return [plain(v) for v in value]
        if isinstance(value, (int, float, bool, str)) or value is None:
            return value
        return str(value)

    return {
        "role": peer.cfg.role,
        "status": peer.status,
        "peer": peer.peer_name,
        "frame": peer.frame,
        "peerFrame": peer.peer_frame,
        "seq": peer.out_seq,
        "peerSeq": peer.in_seq,
        "latencyMs": round(peer.latency_ms, 3),
        "subscriptions": sorted(peer.subscriptions),
        "stats": dict(peer.stats),
        "store": {key: plain(value) for key, value in sorted(peer.store.items())},
        "peerStore": {key: plain(value) for key, value in sorted(peer.peer_store.items())},
    }
