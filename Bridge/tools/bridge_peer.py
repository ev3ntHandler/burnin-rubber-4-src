"""Shockwave <-> Godot bridge: protocol engine (spec §4, §6, §8) — transport and language agnostic.

The Godot addon (``bridge_core.gd``) and the Director script (``[M] Shockwave Bridge.ls``)
implement this same state machine in their own languages.  This module is the shared, runnable
definition of it, so the behaviour can be tested here without either engine:
``mock_director.py`` and ``mock_godot.py`` are thin subclasses over it, and ``test_bridge.py``
drives the two against each other over every transport.

    p = GodotPeer(...)                       # or DirectorPeer
    p.subscribe("gGame.Cash")                # mirror a Director variable into the state store
    p.set("bridge.wantBoost", True)          # write the replicated store (both sides see it)
    p.tick(frame=Engine.get_frames_drawn())  # build + flush this frame's snapshot
    p.flush()

Design notes that the ports must keep:
* ``get()`` is *always* answered from the local mirror — no request round trip in the hot path.
* inbound batches are applied in one lump at the top of a frame, never from a callback (§6).
* a value received from the peer is stored but never re-broadcast (§8, no echo loops).
* ``RSP`` fields are pre-formatted by the op; only the second field of a ``k=v`` pair is typed.
"""

from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Any, Callable, Dict, List, Optional, Sequence, Tuple

from bridge_proto import (
    Batch,
    ProtocolError,
    path_namespace,
    VOID,
    allowed,
    bridge_key,
    build,
    decode,
    decode_kv,
    decode_or_text,
    encode,
    encode_kv,
    is_bridge_path,
    lingo_parse,
    lingo_prints,
    parse,
    sanitize,
)

PROTOCOL_VERSION = 1
CAPS_ALL = ("write", "eval", "exec", "snap", "sub", "event", "call", "list")
STATUS_UP, STATUS_STALE, STATUS_DOWN = "up", "stale", "down"
_MISSING = object()


@dataclass
class Config:
    role: str = "godot"
    name: str = "peer"
    caps: Tuple[str, ...] = CAPS_ALL
    allow_read: Tuple[str, ...] = ("gGame", "gSystem", "gData", "gSound", "gBridge", "bridge", "gd")
    allow_write: Tuple[str, ...] = ()
    allow_eval: bool = False
    snapshot_rate: int = 1
    snapshot_mode: str = "delta"
    request_timeout_ms: int = 2000
    peer_timeout_ms: int = 2000


@dataclass
class Pending:
    rid: int
    op: str
    sent_ms: int
    callback: Optional[Callable[[Any], None]] = None


class Peer:
    """The engine. Subclasses implement ``emit`` (transport) and the runtime hooks."""

    def __init__(self, config: Optional[Config] = None, verbose: bool = False):
        self.cfg = config or Config()
        self.verbose = verbose
        self.out_seq = 0
        self.in_seq = 0
        self.frame = 0
        self.epoch_ms = self.now_ms()
        self.store: Dict[str, Any] = {}
        self.peer_store: Dict[str, Any] = {}
        self.subscriptions: Dict[str, int] = {}
        self.pending: Dict[int, Pending] = {}
        self.outbox: List[Batch] = []
        self._next_rid = 0
        self._dirty: Dict[str, Any] = {}
        self._last_sent: Dict[str, Any] = {}
        self._hello_sent = False
        self.status = STATUS_DOWN
        self.peer_ready = False
        self.peer_caps: Tuple[str, ...] = ()
        self.peer_name = ""
        self.peer_role = ""
        self.peer_frame = 0
        self.peer_tms = 0
        self.last_seen_ms = 0
        self.latency_ms = 0.0
        self.stats = dict.fromkeys(
            ("frames_out", "frames_in", "msgs_out", "msgs_in", "bytes_out", "bytes_in",
             "errors", "dupes", "torn", "timeouts", "denied", "requests", "replies"),
            0,
        )
        self.on_event: Callable[[str, Dict[str, Any]], None] = self._default_on_event
        self.on_status: Callable[[str], None] = lambda status: None
        self.on_change: Callable[[str, Any], None] = lambda path, value: None

    def _default_on_event(self, name: str, data: Any) -> None:
        """Inbound EVT: forward to the runtime hook unless the embedder replaced ``on_event``."""
        try:
            self.raise_event(name, data)
        except ProtocolError as error:
            self.log("warn", "event", name, error.code)

    # -- small utilities ---------------------------------------------------------------------
    def now_ms(self) -> int:
        return int(time.time() * 1000)

    def uptime_ms(self) -> int:
        return self.now_ms() - self.epoch_ms

    def log(self, level: str, *parts: Any) -> None:
        if self.verbose or level in ("warn", "error"):
            print("[%-8s %-5s] %s" % (self.cfg.role, level, " ".join(str(part) for part in parts)))

    def capability(self, name: str) -> bool:
        return name in self.cfg.caps

    # -- outbound ----------------------------------------------------------------------------
    def push(self, batch: Batch) -> None:
        if not batch:
            return
        for chunk in batch.chunk():
            self.stats["msgs_out"] += len(chunk)
            self.stats["bytes_out"] += len(chunk.to_bytes())
            self.outbox.append(chunk)

    def drain(self) -> List[Batch]:
        out, self.outbox = self.outbox, []
        return out

    _transport: Any = None

    def emit(self, batch: Batch) -> None:
        """Hand the batch to the attached transport (see ``Transport.start``)."""
        transport = self._transport
        if transport is None:
            raise NotImplementedError("no transport attached")
        transport.send(batch)

    def flush(self) -> int:
        """Emit everything queued since the last flush as **one** frame.

        Merging matters: the file transport publishes by replacing one file, so two separate
        emits in the same frame would mean the first one never arrived. One frame per
        ``emit()`` is also what makes the http/tcp transports cheap -- they chunk internally.
        """
        batches = self.drain()
        if not batches:
            return 0
        merged = Batch([line for batch in batches for line in batch])
        self.emit(merged)
        return len(batches)

    def request(self, op: str, *args: Any, callback: Optional[Callable[[Any], None]] = None) -> int:
        """Queued RPC; exactly one ``RSP`` (or a ``timeout`` error) resolves it."""
        self._next_rid += 1
        rid = self._next_rid
        batch = Batch()
        batch.add("REQ", [rid, op] + [str(arg) for arg in args])
        self.push(batch)
        self.pending[rid] = Pending(rid, op, self.now_ms(), callback)
        self.stats["requests"] += 1
        return rid

    def command(self, op: str, *args: Any) -> None:
        batch = Batch()
        batch.add("CMD", [self.next_rid(), op] + [str(arg) for arg in args])
        self.push(batch)

    def next_rid(self) -> int:
        self._next_rid += 1
        return self._next_rid

    # -- the API both engines expose ----------------------------------------------------------
    def get(self, path: str, default: Any = VOID) -> Any:
        """Read the mirrored copy. Never blocks, never allocates a request."""
        value = self.peer_store.get(path, _MISSING)
        if value is _MISSING and is_bridge_path(path):
            value = self.store.get(bridge_key(path), _MISSING)
        if value is _MISSING:
            return default
        return value

    def get_path(self, path: str) -> Any:
        """Local truth: our own store for ``bridge.*``, otherwise the mirror."""
        if is_bridge_path(path):
            return self.store.get(bridge_key(path), self.peer_store.get(path, VOID))
        return self.peer_store.get(path, VOID)

    def set(self, path: str, value: Any, reply: bool = False) -> Any:
        """Write a value.

        ``bridge.*`` lands in our own replicated store (and goes out with the next snapshot).
        Any other path is a write on the *peer*: fire-and-forget by default -- the peer's own
        DELTA is what brings the value back to us, so there is nothing to wait for. Pass
        ``reply=True`` when you need the peer's echo (validation, permission errors).
        """
        if value is None:
            value = VOID
        if is_bridge_path(path):
            key = bridge_key(path)
            if value is VOID:
                self.store.pop(key, None)
            else:
                self.store[key] = value
            self.mark_dirty(path, value)
            return value
        if reply:
            return self.request("set", path, encode(value))
        self.command("set", path, encode(value))
        if self.owns(path):  # e.g. a Director-side GodotPeer driving its own mirror
            self.mark_dirty(path, value)
        return 0

    def set_many(self, pairs: Dict[str, Any]) -> int:
        chunks = ["%s=%s" % (sanitize(path), encode(value)) for path, value in pairs.items()]
        return self.request("sets", ";".join(chunks))

    def request_get(self, path: str, callback: Optional[Callable[[Any], None]] = None) -> int:
        def _unwrap(value: Any) -> None:
            if isinstance(value, list) and len(value) >= 2:
                value = value[1]
            if callback:
                callback(value)

        return self.request("get", path, callback=_unwrap if callback else None)

    def subscribe(self, path: str, rate: int = 0) -> None:
        if path in self.subscriptions:
            return
        self.subscriptions[path] = rate
        self.command("sub", path, rate)

    def unsubscribe(self, path: str) -> None:
        if self.subscriptions.pop(path, None) is not None:
            self.command("unsub", path)

    def call(self, handler: str, target: str = "", data: Any = VOID, callback: Optional[Callable[[Any], None]] = None) -> int:
        payload = "" if data is VOID or data is None else lingo_prints(data)
        return self.request("call", sanitize(handler), sanitize(target), payload, callback=callback)

    def event(self, name: str, pairs: Optional[Dict[str, Any]] = None) -> None:
        self.out_seq += 1
        batch = Batch()
        batch.add("EVT", [self.out_seq, sanitize(name), encode_kv(list((pairs or {}).items()))])
        self.push(batch)

    def eval(self, expression: str, callback: Optional[Callable[[Any], None]] = None) -> int:
        return self.request("eval", sanitize(expression), callback=callback)

    def exec(self, statements: str, callback: Optional[Callable[[Any], None]] = None) -> int:
        return self.request("exec", sanitize(statements), callback=callback)

    def list_paths(self, prefix: str, depth: int = 0, callback: Optional[Callable[[Any], None]] = None) -> int:
        def _parse_list_field(value: Any) -> None:
            text = value if isinstance(value, str) else ""
            if callback:
                callback(dict(decode_kv(text)))

        return self.request("list", sanitize(prefix), depth, callback=_parse_list_field)

    def ping(self, callback: Optional[Callable[[Any], None]] = None) -> int:
        return self.request("ping", self.uptime_ms(), callback=callback)

    def snapshot(self, on: bool = True, rate: Optional[int] = None, mode: Optional[str] = None) -> None:
        args = ["b:%d" % int(bool(on)), self.cfg.snapshot_rate if rate is None else max(1, int(rate)), mode or self.cfg.snapshot_mode]
        self.cfg.snapshot_rate = int(args[1])
        self.cfg.snapshot_mode = args[2]
        if not on:
            self.subscriptions.clear()
            self._dirty.clear()
        self.command("snap", *args)

    # -- ownership ------------------------------------------------------------------------------
    #: which path roots this peer is the source of truth for (spec §5)
    DIRECTOR_ROOTS = ("gGame", "gSystem", "gData", "gSound", "gBridge", "member", "sprite", "_movie", "_player", "_system")

    def owns(self, path: str) -> bool:
        """Only a path's owner may include it in a snapshot -- that is what stops echo loops."""
        if is_bridge_path(path):
            return True
        if path.startswith("gd:"):
            return self.cfg.role == "godot"
        head = path_namespace(path)
        if self.cfg.role == "director":
            return head in self.DIRECTOR_ROOTS
        return head not in self.DIRECTOR_ROOTS

    # -- snapshot building ---------------------------------------------------------------------
    def mark_dirty(self, path: str, value: Any) -> None:
        if not self.owns(path):
            return
        self._dirty[path] = value

    def collect_changes(self) -> List[Tuple[str, Any]]:
        """Subscribed paths whose value moved, plus anything the local code flagged dirty."""
        pairs: List[Tuple[str, Any]] = []
        for path, value in self._dirty.items():
            pairs.append((path, value))
        self._dirty.clear()
        for path in self.subscriptions:
            value = self.resolve_path(path)
            if self._last_sent.get(path, _MISSING) != value:
                pairs.append((path, value))
        return pairs

    def build_snapshot(self, batch: Batch) -> None:
        """One DELTA (or SNAP) per frame: subscribed changes + our side of the replicated store.

        Everything queued in one frame goes out as a single batch (see ``flush``), and values
        received from the peer are deliberately not re-broadcast -- that is what keeps the two
        mirrors from feeding each other (spec §8).
        """
        if self.cfg.snapshot_mode == "full":
            pairs: List[Tuple[str, Any]] = [(path, self.resolve_path(path)) for path in self.subscriptions]
            seen = {path for path, _ in pairs}
            pairs += [(path, value) for path, value in self._dirty.items() if path not in seen]
        else:
            pairs = self.collect_changes()
        seen = dict(pairs)
        for key, value in self.store.items():
            path = "bridge." + key
            if path not in seen and self._last_sent.get(path, _MISSING) != value:
                pairs.append((path, value))
        pairs = [(path, value) for path, value in pairs if self.owns(path)]
        if not pairs:
            return
        for path, value in pairs:
            self._last_sent[path] = value
        self.out_seq += 1
        verb = "SNAP" if self.cfg.snapshot_mode == "full" else "DELTA"
        batch.add(verb, [self.out_seq, self.frame, self.uptime_ms(), self.in_seq, encode_kv(pairs)])

    def tick(self, frame: Optional[int] = None) -> None:
        """Per-frame pump: snapshot this frame's changes, greet the peer, reap timeouts."""
        self.frame = self.frame + 1 if frame is None else frame
        rate = max(1, int(self.cfg.snapshot_rate))
        if self.frame % rate == 0:
            batch = Batch()
            self.build_snapshot(batch)
            if batch:
                self.stats["frames_out"] += 1
                self.push(batch)
        if not self._hello_sent:
            self._hello_sent = True
            hello = Batch()
            hello.add("HELLO", [self.cfg.role, self.cfg.name, PROTOCOL_VERSION, self.out_seq, ",".join(self.cfg.caps)])
            self.push(hello)
        self.reap_timeouts()

    def reap_timeouts(self) -> None:
        now = self.now_ms()
        for rid in list(self.pending):
            item = self.pending[rid]
            if now - item.sent_ms > self.cfg.request_timeout_ms:
                del self.pending[rid]
                self.stats["timeouts"] += 1
                self.log("warn", "request timeout", item.op, rid)
                if item.callback:
                    item.callback(ProtocolError("timeout", item.op))
        self.update_status()

    def update_status(self) -> None:
        silence = (self.now_ms() - self.last_seen_ms) if self.last_seen_ms else 10**12
        previous = self.status
        if not self.peer_ready:
            self.status = STATUS_DOWN
        elif silence > self.cfg.peer_timeout_ms * 5:
            self.status = STATUS_DOWN
        elif silence > self.cfg.peer_timeout_ms:
            self.status = STATUS_STALE
        else:
            self.status = STATUS_UP
        if previous != self.status:
            self.log("info", "status", previous, "->", self.status)
            self.on_status(self.status)

    # -- inbound -------------------------------------------------------------------------------
    def feed(self, data: bytes) -> Batch:
        return self.feed_batch(Batch.from_bytes(data))

    def feed_batch(self, batch: Batch) -> Batch:
        reply = Batch()
        for line in batch:
            verb, fields = parse(line)
            if not verb:
                continue
            self.stats["msgs_in"] += 1
            self.last_seen_ms = self.now_ms()
            try:
                self.dispatch(verb, fields, reply)
            except ProtocolError as error:
                self.stats["errors"] += 1
                if verb == "REQ" and len(fields) >= 2:
                    reply.add("RSP", [fields[0], fields[1], "err", error.code, error.message])
            except Exception as error:  # a debug bridge must never crash the game it is attached to
                self.stats["errors"] += 1
                self.log("error", "inbound", verb, repr(error))
                if verb == "REQ" and len(fields) >= 2:
                    reply.add("RSP", [fields[0], fields[1], "err", "error", sanitize(repr(error))])
        if reply:
            self.stats["replies"] += 1
            self.push(reply)
        return reply

    def dispatch(self, verb: str, fields: List[str], reply: Batch) -> None:
        if verb in ("SNAP", "DELTA"):
            self.accept_snapshot(fields)
            return
        if verb == "EVT":
            if len(fields) >= 2:
                self.on_event(fields[1], dict(decode_kv(fields[2] if len(fields) > 2 else "")))
            return
        if verb == "HELLO":
            self.peer_ready = True
            self.peer_role = fields[0] if fields else ""
            self.peer_name = fields[1] if len(fields) > 1 else ""
            self.peer_caps = tuple(filter(None, fields[4].split(","))) if len(fields) > 4 else ()
            # HELLO doubles as "my frame counter has started over": field 3 is the greeter's seq,
            # and if it is behind where we left off, everything we would otherwise discard as stale
            # is in fact the only live data there is.
            announced = fields[3] if len(fields) > 3 else ""
            self.reset_inbound(int(announced) if announced.lstrip("-").isdigit() else 0, "hello")
            self.last_seen_ms = self.now_ms()
            self.stats["frames_in"] += 1
            self.update_status()
            if not self._hello_sent:  # peer greeted us first: answer, once
                self._hello_sent = True
                hello = Batch()
                hello.add("HELLO", [self.cfg.role, self.cfg.name, PROTOCOL_VERSION, self.out_seq, ",".join(self.cfg.caps)])
                self.push(hello)
            return
        if verb == "BYE":
            self.peer_ready = False
            self.update_status()
            return
        if verb == "PING":
            reply.add("PONG", [fields[0] if fields else 0, self.uptime_ms()])
            return
        if verb == "PONG":
            if len(fields) >= 2:
                try:
                    self.latency_ms = float(self.uptime_ms() - int(fields[1]))
                except ValueError:
                    pass
            return
        if verb == "LOG":
            self.log("peer", *fields)
            return
        if verb == "REQ":
            if len(fields) < 2:
                return
            rid, op, args = fields[0], fields[1], fields[2:]
            try:
                result = self.handle_op(op, args)
            except ProtocolError as error:
                result = ("err", error.code, error.message)
            reply.add_line(self.rsp_line(rid, op, result))
            return
        if verb == "CMD":
            if len(fields) < 2:
                return
            try:
                self.handle_op(fields[1], fields[2:])
            except ProtocolError as error:
                self.log("warn", "cmd", fields[1], error.code, error.message)
            return
        if verb == "RSP":
            self.accept_rsp(fields)
            return
        self.log("warn", "ignored unknown verb", verb)

    def accept_snapshot(self, fields: List[str]) -> None:
        if not fields:
            return
        try:
            seq = int(fields[0])
        except ValueError:
            return
        if seq <= self.in_seq:
            self.stats["dupes"] += 1
            return
        self.in_seq = seq
        self.stats["frames_in"] += 1
        self.peer_frame = int(fields[1]) if len(fields) > 1 and fields[1] else 0
        self.peer_tms = int(fields[2]) if len(fields) > 2 and fields[2] else 0
        self.peer_ack = int(fields[3]) if len(fields) > 3 and fields[3] else self.peer_ack
        for path, value in decode_kv(fields[4] if len(fields) > 4 else ""):
            self.apply_remote(path, value)

    peer_ack = 0

    def accept_rsp(self, fields: List[str]) -> None:
        if len(fields) < 3:
            return
        try:
            rid = int(fields[0])
        except ValueError:
            return
        item = self.pending.pop(rid, None)
        if item is None:
            self.stats["dupes"] += 1
            return
        if fields[2] == "ok":
            payload = [decode_or_text(field) if field else "" for field in fields[3:]]
            if item.callback:
                # a one-field reply is the value itself; multi-field replies stay a list
                item.callback(payload[0] if len(payload) == 1 else payload)
            return
        code = fields[3] if len(fields) > 3 else "error"
        message = fields[4] if len(fields) > 4 else ""
        self.stats["errors"] += 1
        if item.callback:
            item.callback(ProtocolError(code, message))

    def rsp_line(self, rid: str, op: str, result: Any) -> str:
        if isinstance(result, tuple) and result and result[0] == "err":
            return build("RSP", [rid, op, "err", result[1], result[2] if len(result) > 2 else ""])
        fields = list(result) if isinstance(result, (list, tuple)) else [result]
        return build("RSP", [rid, op, "ok"] + [str(field) for field in fields])

    def apply_remote(self, path: str, value: Any, local_write: bool = False) -> None:
        if is_bridge_path(path):
            key = bridge_key(path)
            if value is VOID:
                self.store.pop(key, None)
            else:
                self.store[key] = value
            self.peer_store[path] = value
            self._last_sent[path] = value
            self.on_change(path, value)
            return
        if local_write:
            self.write_path(path, value)
        self.peer_store[path] = value
        self._last_sent[path] = value
        self.on_change(path, value)

    # -- ops -----------------------------------------------------------------------------------
    def handle_op(self, op: str, args: List[str]) -> Any:
        """Return a list of already-formatted RSP fields, or raise :class:`ProtocolError`."""
        if op == "get":
            if not args:
                raise ProtocolError("badargs", "get <path>")
            self.check_read(args[0])
            return [args[0], encode(self.resolve_path(args[0]))]
        if op == "gets":
            out = []
            for path in filter(None, (args[0] if args else "").split(";")):
                if not allowed(path, self.cfg.allow_read):
                    self.stats["denied"] += 1
                    out.append("%s=denied" % path)
                    continue
                out.append("%s=%s" % (path, encode(self.resolve_path(path))))
            return [";".join(out)]
        if op == "set":
            if len(args) < 2:
                raise ProtocolError("badargs", "set <path> <value>")
            self.check_write(args[0])
            value = decode(args[1])
            self.apply_remote(args[0], value, local_write=True)
            self.mark_dirty(args[0], value)
            return [args[0], encode(value)]
        if op == "sets":
            out = []
            for chunk in filter(None, (args[0] if args else "").split(";")):
                path, sep, raw = chunk.partition("=")
                if not sep:
                    continue
                try:
                    self.check_write(path)
                except ProtocolError:
                    self.stats["denied"] += 1
                    out.append("%s=denied" % path)
                    continue
                value = decode_or_text(raw) if raw else VOID
                self.apply_remote(path, value, local_write=True)
                self.mark_dirty(path, value)
                out.append("%s=%s" % (path, encode(value)))
            return [";".join(out)]
        if op == "sub":
            if not args:
                raise ProtocolError("badargs", "sub <path>")
            self.check_read(args[0])
            self.subscriptions[args[0]] = int(args[1]) if len(args) > 1 and args[1] else 0
            return [args[0], encode(self.resolve_path(args[0]))]
        if op == "unsub":
            if args:
                self.subscriptions.pop(args[0], None)
            return [args[0] if args else ""]
        if op == "snap":
            on = (args[0] if args else "b:1").endswith("1")
            if len(args) > 1 and args[1]:
                self.cfg.snapshot_rate = max(1, int(args[1]))
            if len(args) > 2 and args[2]:
                self.cfg.snapshot_mode = args[2]
            if not on:
                self.subscriptions.clear()
                self._dirty.clear()
                self._last_sent.clear()
            return ["b:%d" % int(on), str(self.cfg.snapshot_rate), self.cfg.snapshot_mode]
        if op == "call":
            if not self.capability("call"):
                raise ProtocolError("disabled", "call")
            if not args:
                raise ProtocolError("badargs", "call <handler> [target] [literal]")
            data = lingo_parse(args[2]) if len(args) > 2 and args[2] else VOID
            result = self.execute_call(args[0], args[1] if len(args) > 1 else "", data)
            return [encode(result)]
        if op == "event":
            if not args:
                raise ProtocolError("badargs", "event <name> [kvlist]")
            self.raise_event(args[0], dict(decode_kv(args[1])) if len(args) > 1 else {})
            return ["b:1"]
        if op == "eval":
            if not (self.cfg.allow_eval and self.capability("eval")):
                raise ProtocolError("disabled", "eval needs allowEval")
            return [encode(self.evaluate(" ".join(args)))]
        if op == "exec":
            if not (self.cfg.allow_eval and self.capability("exec")):
                raise ProtocolError("disabled", "exec needs allowEval")
            return [encode(self.executes(" ".join(args)))]
        if op == "list":
            prefix = args[0] if args else ""
            depth = int(args[1]) if len(args) > 1 and args[1] else 0
            if prefix and not allowed(prefix, self.cfg.allow_read):
                raise ProtocolError("denied", prefix)
            return [";".join("%s=%s" % (path, encode(value)) for path, value in self.enumerate(prefix, depth))]
        if op == "ping":
            sent = int(args[0]) if args and args[0] else 0
            self.stats["replies"] += 1
            return [str(self.uptime_ms()), str(sent)]
        if op == "quit":
            self.push_bye("quit")
            return ["b:1"]
        raise ProtocolError("unknownop", op)

    def reset_inbound(self, peer_seq: int, reason: str) -> None:
        """Forget where the peer's frame counter was, because it has started over.

        A HELLO carries the greeter's current seq, so a value *below* where we left off means the
        peer restarted and is counting up from 1 again. Without this the reader's `seq > in_seq`
        filter would drop every one of its frames until the new count passed the old one -- after a
        20-minute session that is 36 000 frames of silence, which is exactly the "I restarted
        Godot and now it never gets data" report. Idempotent, and it does not touch the mirrored
        values: they are the last known truth until the new session overwrites them.
        """
        if peer_seq >= self.in_seq:
            return  # same session, or further along: nothing to forget
        self.log("info", "peer restarted at seq %d (we had %d): re-arming (%s)" % (peer_seq, self.in_seq, reason))
        self.in_seq = 0
        self.stats["dupes"] = 0
        transport = self._transport
        reset = getattr(transport, "reset_inbound", None)
        if callable(reset):
            reset()

    def push_bye(self, reason: str) -> None:
        batch = Batch()
        batch.add("BYE", [sanitize(reason), "i:0"])
        self.push(batch)

    def check_read(self, path: str) -> None:
        if not allowed(path, self.cfg.allow_read):
            self.stats["denied"] += 1
            raise ProtocolError("denied", path)

    def check_write(self, path: str) -> None:
        if is_bridge_path(path):  # the replicated store is always writable from either side
            return
        if not self.capability("write") or not self.cfg.allow_write:
            self.stats["denied"] += 1
            raise ProtocolError("disabled", "no write allow-list on this peer")
        if not allowed(path, self.cfg.allow_write):
            self.stats["denied"] += 1
            raise ProtocolError("denied", path)

    # -- runtime hooks (implemented by DirectorPeer / GodotPeer) -------------------------------
    def resolve_path(self, path: str) -> Any:
        if is_bridge_path(path):
            return self.store.get(bridge_key(path), VOID)
        return VOID

    def write_path(self, path: str, value: Any) -> bool:
        if is_bridge_path(path):
            self.store[bridge_key(path)] = value
            return True
        return False

    def enumerate(self, prefix: str, depth: int) -> List[Tuple[str, Any]]:
        return []

    def execute_call(self, handler: str, target: str, data: Any) -> Any:
        raise ProtocolError("unknownop", "call is not implemented by this peer")

    def raise_event(self, name: str, data: Any) -> None:
        raise ProtocolError("unknownop", "event is not implemented by this peer")

    def evaluate(self, expression: str) -> Any:
        raise ProtocolError("disabled", "eval is not implemented by this peer")

    def executes(self, statements: str) -> Any:
        raise ProtocolError("disabled", "exec is not implemented by this peer")

    # -- lifecycle -------------------------------------------------------------------------------
    def start(self) -> "Peer":
        self._hello_sent = False
        return self

    def stop(self) -> None:
        self.push_bye("stop")

    def __enter__(self) -> "Peer":
        return self

    def __exit__(self, *exc: Any) -> None:
        try:
            self.stop()
            self.flush()
        except Exception:
            pass
