#!/usr/bin/env python3
"""Command-line peer: talk to a running movie, or a running Godot game, without either GUI open.

The bridge's two real ends are Director and Godot, and both are awkward to script. This tool is a
third thing that speaks the same wire (PROTOCOL.md) on top of the reference implementation in this
folder, so you can:

* see what a movie is actually sending when the Godot side reports "no data";
* push values into a movie from a shell script, a build step, or CI;
* decode a mailbox folder after a crash, with no live peer at all;
* run the codec, the shared vectors file and a live two-peer loopback as one command.

    python3 bridge_probe.py get gGame.Cash                     # read, print, exit
    python3 bridge_probe.py get gGame.Cash --json              # machine-readable (flags go after the verb)
    python3 bridge_probe.py get gGame.Cash gGame.Money --json  # several, as JSON
    python3 bridge_probe.py set gGame.Cash 999999              # the movie's allow-list still applies
    python3 bridge_probe.py set bridge.wantBoost TRUE
    python3 bridge_probe.py call PutMessage '{"message": "hi"}'
    python3 bridge_probe.py event BridgePause reason=cutscene
    python3 bridge_probe.py list gGame.CurrentVehicle --depth 2
    python3 bridge_probe.py watch gGame.CurrentVehicle.general.kmh
    python3 bridge_probe.py status
    python3 bridge_probe.py snap off | snap on --rate 2 --kind full
    python3 bridge_probe.py repl
    python3 bridge_probe.py frames ../Director/BridgeData      # offline mailbox decode
    python3 bridge_probe.py selftest                            # codec + vectors + live loopback

Transport and mailbox folder come from `Bridge.Data.txt` when it can be found, so a probe normally
needs no options; `--root`, `--host`, `--port`, `--transport` override it. By default the probe
imitates the **Director** end (it connects *to* a Godot listener, or writes `d2g.txt`);
`--as godot` makes it the Godot end instead — it then *listens* on http/tcp and writes `g2d.txt`,
which is how you drive a movie that is already running.

Exit status: 0 ok, 1 refused or failed, 2 bad usage. A denied read prints `denied` on stderr and
exits 1, so a script can tell "not allowed" from "zero".
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
import time
from typing import Any, Dict, List, Optional

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from bridge_config import apply_overrides, load as load_config  # noqa: E402
from bridge_proto import (  # noqa: E402
    Batch,
    ProtocolError,
    VOID,
    decode_or_text,
    encode,
    parse,
    read_frame,
    render,
    sanitize,
)
from mock_director import DirectorPeer, make_game  # noqa: E402
from mock_godot import GodotPeer  # noqa: E402

EXIT_OK, EXIT_FAIL, EXIT_USAGE = 0, 1, 2
MAX_DRAIN = 64  # lines per poll, the bound PROTOCOL.md 7.3 puts on a drain


# --------------------------------------------------------------------------------------------
# wiring: a peer, a transport, and a loop you can pump
# --------------------------------------------------------------------------------------------


def find_config(explicit: str) -> str:
    if explicit:
        return explicit
    for candidate in (
        os.path.join(HERE, "..", "Director", "Bridge.Data.txt"),
        os.path.join(os.getcwd(), "Bridge.Data.txt"),
        os.path.join(os.getcwd(), "Bridge", "Director", "Bridge.Data.txt"),
    ):
        if os.path.isfile(candidate):
            return os.path.abspath(candidate)
    return ""


class Probe:
    """One peer, its transport, and enough of a frame clock to be useful from a shell."""

    def __init__(self, args: argparse.Namespace):
        self.args = args
        self.config = load_config(find_config(args.config))
        apply_overrides(
            self.config,
            transport=args.transport or self.config.transport,
            root=self._root(args.root or self.config.root),
            httpPort=args.port or self.config.httpPort,
            tcpPort=args.port or self.config.tcpPort,
        )
        self.as_godot = args.as_role == "godot"
        if self.as_godot:
            self.peer = GodotPeer(config=self.config, verbose=args.verbose, allow_write=True)
        else:
            self.peer = DirectorPeer(config=self.config, game=make_game(), verbose=args.verbose)
        self.peer.start()
        self.transport = self._build_transport()
        if self.transport is not None:
            self.transport.start()
        self.frames = 0

    def _root(self, root: str) -> str:
        return root if os.path.isabs(root) else os.path.abspath(os.path.join(HERE, "..", "..", root))

    def _build_transport(self) -> Any:
        from bridge_transports import (  # noqa: PLC0415 - only needed once, per mode
            FilesTransport,
            HttpClientTransport,
            HttpServerTransport,
            TcpClientTransport,
            TcpServerTransport,
        )

        name = self.config.transport
        if name == "files":
            return FilesTransport(self.peer, self.config.root, crc=bool(self.config.verify))
        if name == "http":
            if self.as_godot:
                return HttpServerTransport(self.peer, "127.0.0.1", self.config.httpPort)
            return HttpClientTransport(
                self.peer,
                "http://%s:%d/bridge" % (self.config.httpHost, self.config.httpPort),
                wait_ms=min(200, self.config.httpWaitMs or 200),
                timeout=3.0,
            )
        if name == "tcp":
            if self.as_godot:
                return TcpServerTransport(self.peer, "127.0.0.1", self.config.tcpPort)
            return TcpClientTransport(self.peer, self.config.tcpHost or "127.0.0.1", self.config.tcpPort)
        raise SystemExit("unknown transport %r (expected files, http or tcp)" % name)

    def pump(self, frames: int = 1, settle: float = 0.01) -> None:
        for _ in range(frames):
            self.frames += 1
            self.peer.tick(self.frames)
            self.peer.flush()
            self.drain()
            if settle:
                time.sleep(settle)

    def drain(self) -> None:
        if self.transport is None:
            return
        for _ in range(MAX_DRAIN):
            batch = self.transport.poll()
            if not batch:
                return
            self.peer.feed_batch(batch)

    def greet(self, frames: int = 30) -> bool:
        """Pump until the other end has said HELLO. False if it never showed up."""
        for _ in range(frames):
            if self.peer.peer_ready:
                return True
            self.pump(1)
        return bool(self.peer.peer_ready)

    def roundtrip(self, op: str, *args: Any, attempts: int = 3, per_attempt: int = 40) -> Any:
        """Send a REQ, pump until the RSP arrives, and resend it if the mailbox ate it.

        A files mailbox has no acknowledgement and no locking, so a frame written while the other
        end is mid-rewrite is simply lost (PROTOCOL.md 7.1: the reader counts torn reads). Retrying
        is therefore normal here, not an error path: each attempt gets a fresh rid, so a late reply
        to an earlier attempt is dropped as a dupe rather than delivered twice.
        """
        for _ in range(max(1, attempts)):
            holder: Dict[str, Any] = {}
            self.peer.request(op, *args, callback=lambda value: holder.setdefault("v", value))
            for _ in range(max(2, per_attempt)):
                self.pump(1)
                if "v" in holder:
                    return holder["v"]
        return ProtocolError("timeout", "no RSP for %s after %d attempt(s)" % (op, max(1, attempts)))

    def close(self) -> None:
        try:
            self.peer.stop()
        except Exception:  # noqa: BLE001 - a probe must not fail on the way out
            pass
        if self.transport is not None:
            try:
                self.transport.stop()
            except Exception:  # noqa: BLE001
                pass

    def __enter__(self) -> "Probe":
        return self

    def __exit__(self, *exc: Any) -> None:
        self.close()


def request_read(probe: Probe, path: str) -> Any:
    """`REQ <rid> get <path>` -> the value, or the error the game sent back.

    The allow-list is enforced by the *game* (PROTOCOL.md 6), not here -- a probe can only read
    what `Bridge.Data.txt` exposes, which is the point: it proves what the shipped movie allows.
    """
    return probe.roundtrip("get", sanitize(path))


def unwrap_get(result: Any) -> Any:
    """`RSP rid get ok <path> <wirevalue>` arrives as a 2-list; a denial arrives as an error."""
    if isinstance(result, list) and len(result) >= 2:
        return decode_or_text(result[1]) if isinstance(result[1], str) else result[1]
    return result


# --------------------------------------------------------------------------------------------
# output
# --------------------------------------------------------------------------------------------


def jsonable(value: Any) -> Any:
    if value is VOID or value is None:
        return None
    if isinstance(value, ProtocolError):
        return {"error": value.code, "message": value.message}
    if isinstance(value, bool):
        return value
    if hasattr(value, "name"):  # Symbol
        return "#" + str(value.name)
    if isinstance(value, (list, tuple)):
        return [jsonable(item) for item in value]
    if isinstance(value, dict):
        return {str(key): jsonable(item) for key, item in value.items()}
    return value


def emit(value: Any, as_json: bool, key: str = "") -> None:
    if as_json:
        payload = {key: jsonable(value)} if key else jsonable(value)
        print(json.dumps(payload, ensure_ascii=False))
        return
    print("%s\t%s" % (key, render(value)) if key else render(value))


def plain(text: str) -> Any:
    """`TRUE`, `12`, `1.5`, `#Sym`, `s:text`, `VOID`, otherwise a string."""
    stripped = text.strip()
    lowered = stripped.lower()
    if lowered in ("true", "yes", "on"):
        return True
    if lowered in ("false", "no", "off"):
        return False
    if lowered in ("void", "null", "none", ""):
        return VOID
    if len(stripped) > 1 and stripped[1] == ":" and stripped[0] in "ifsbpyvqcrdln":
        return decode_or_text(stripped)
    if stripped[:1] == "#":
        return decode_or_text("y:" + stripped[1:])
    try:
        return int(stripped)
    except ValueError:
        pass
    try:
        return float(stripped)
    except ValueError:
        return stripped


# --------------------------------------------------------------------------------------------
# commands
# --------------------------------------------------------------------------------------------


def cmd_get(args: argparse.Namespace) -> int:
    with Probe(args) as probe:
        probe.greet()
        results: Dict[str, Any] = {}
        for path in args.paths:
            # the mirror is one lookup and never blocks; use it when it has the path, and only
            # pay a round trip for a path nobody subscribed to
            mirrored = probe.peer.get(path)  # local lookup of the mirror; no request, no wait
            results[path] = mirrored if mirrored is not VOID else unwrap_get(request_read(probe, path))
        failed = any(isinstance(value, ProtocolError) for value in results.values())
        if len(args.paths) == 1:
            value = results[args.paths[0]]
            if isinstance(value, ProtocolError):
                print("%s: %s %s" % (args.paths[0], value.code, value.message), file=sys.stderr)
                return EXIT_FAIL
            emit(value, args.json)
        else:
            emit(results, args.json)
        return EXIT_FAIL if failed else EXIT_OK


def cmd_set(args: argparse.Namespace) -> int:
    with Probe(args) as probe:
        probe.greet()
        result = probe.roundtrip("set", sanitize(args.path), encode(plain(args.value)), attempts=args.tries)
        if isinstance(result, ProtocolError):
            print("%s: %s %s" % (args.path, result.code, result.message), file=sys.stderr)
            return EXIT_FAIL
        # `RSP rid set ok <path> <wirevalue>`: echo what the far side says it now holds
        emit(unwrap_get(result), args.json, key=args.path)
        return EXIT_OK


def cmd_call(args: argparse.Namespace) -> int:
    with Probe(args) as probe:
        probe.greet()
        data = plain(args.data) if args.data else VOID
        result = probe.roundtrip("call", args.handler, args.target or "", encode(data) if data is not VOID else "VOID", attempts=args.tries)
        if isinstance(result, ProtocolError):
            print("%s: %s %s" % (args.handler, result.code, result.message), file=sys.stderr)
            return EXIT_FAIL
        emit(result, args.json)
        return EXIT_OK


def cmd_event(args: argparse.Namespace) -> int:
    with Probe(args) as probe:
        probe.greet()
        pairs: Dict[str, Any] = {}
        for chunk in args.kv:
            key, _sep, value = chunk.partition("=")
            pairs[key.strip()] = plain(value)
        probe.peer.event(args.name, pairs)
        probe.pump(3)
        print("EVT %s sent%s" % (args.name, (" with %d field(s)" % len(pairs)) if pairs else ""))
        return EXIT_OK


def cmd_list(args: argparse.Namespace) -> int:
    with Probe(args) as probe:
        probe.greet()
        result = probe.roundtrip("list", args.prefix or "", str(args.depth), attempts=args.tries)
        if isinstance(result, ProtocolError):
            print("list: %s %s" % (result.code, result.message), file=sys.stderr)
            return EXIT_FAIL
        chunks = result if isinstance(result, list) else [result]
        rows: List[str] = []
        for chunk in chunks:
            rows += [part for part in str(chunk).split(";") if part]
        if args.json:
            out = {}
            for row in rows:
                key, _sep, value = row.partition("=")
                out[key] = jsonable(decode_or_text(value))
            print(json.dumps(out, ensure_ascii=False, indent=1))
        else:
            for row in rows:
                print("  " + row)
        return EXIT_OK if rows else EXIT_FAIL


def cmd_watch(args: argparse.Namespace) -> int:
    with Probe(args) as probe:
        probe.greet()
        for path in args.paths:
            probe.peer.subscribe(path)
            probe.peer.request("sub", sanitize(path))
            # a DELTA only carries *changed* keys, so a path that never changes would leave this watch
            # printing nothing but VOID forever: prime it with one honest round trip
            primed = unwrap_get(request_read(probe, path))
            if not isinstance(primed, ProtocolError):
                probe.peer.peer_store[path] = primed
        interval = 1.0 / max(1.0, args.hz)
        print("# watching %s at %g Hz over %s  (Ctrl-C to stop)" % (", ".join(args.paths), args.hz, probe.config.transport))
        last: Dict[str, str] = {}
        try:
            while True:
                probe.pump(1, settle=interval)
                for path in args.paths:
                    text = render(probe.peer.peer_store.get(path, VOID))
                    if last.get(path) != text:
                        last[path] = text
                        print("%10.3f  %s = %s" % (time.time() % 100000, path, text))
                        sys.stdout.flush()
        except KeyboardInterrupt:
            print("\n# stopped")
        return EXIT_OK


def cmd_status(args: argparse.Namespace) -> int:
    with Probe(args) as probe:
        probe.greet(20)
        peer = probe.peer
        snapshot = {
            "status": peer.status,
            "transport": probe.config.transport,
            "role": peer.cfg.role,
            "peerRole": peer.peer_role,
            "peerName": peer.peer_name,
            "peerCaps": list(peer.peer_caps),
            "frame": peer.frame,
            "seqOut": peer.out_seq,
            "seqIn": peer.in_seq,
            "latencyMs": getattr(peer, "latency_ms", 0),
            "stats": dict(peer.stats),
            "mailbox": getattr(probe.transport, "out_path", None),
            "store": {key: render(value) for key, value in peer.store.items()},
            "mirror": {key: render(value) for key, value in sorted(peer.peer_store.items())},
        }
        if args.json:
            emit(snapshot, True)
        else:
            for key, value in snapshot.items():
                if key in ("store", "mirror", "stats"):
                    print("  %s:" % key)
                    for sub_key, sub_value in (value.items() if isinstance(value, dict) else []):
                        print("      %-40s %s" % (sub_key, sub_value))
                else:
                    print("  %-8s %s" % (key, value if value not in ("", None, []) else "-"))
            if not peer.peer_ready:
                print("  (no HELLO from the peer yet -- if it has been running a while it sent that"
                      "\n   once, long before you joined; receiving %d message(s) is fine)" % peer.stats["msgs_in"])
        # "usable" is not "handshaken": either side of the pair answering you is what matters
        return EXIT_OK if (peer.peer_ready or peer.stats["msgs_in"]) else EXIT_FAIL


def cmd_snap(args: argparse.Namespace) -> int:
    with Probe(args) as probe:
        probe.greet()
        probe.peer.snapshot(args.mode == "on", args.rate if args.rate else None, args.kind or None)
        probe.pump(3)
        print("snapshot %s%s" % (args.mode, (" rate %d" % args.rate) if args.rate else ""))
        return EXIT_OK


def cmd_frames(args: argparse.Namespace) -> int:
    """Decode a mailbox folder with nobody running. When a movie "sends nothing", this says whether
    the file has the frame, whether the marker agrees with it, and what each message holds."""
    target = args.path or os.path.join(HERE, "..", "Director", "BridgeData")
    if os.path.isfile(target):
        paths = [target]
    else:
        paths = [os.path.join(target, name) for name in ("d2g.txt", "g2d.txt") if os.path.isfile(os.path.join(target, name))]
    if not paths:
        print("no mailbox files under %s" % target, file=sys.stderr)
        return EXIT_FAIL
    shown = 0
    for path in paths:
        marker = path[: -len(".txt")] + ".seq" if path.endswith(".txt") else path + ".seq"
        print("== %s" % os.path.basename(path))
        if not os.path.exists(marker):
            print("   no commit marker at %s -- the writer never finished a frame" % marker)
            continue
        try:
            head = open(marker, encoding="utf-8", errors="replace").read(160).split()
            print("   marker: seq %s, %s bytes, %s lines" % (head[0], head[1], head[2] if len(head) > 2 else "?"))
        except OSError as error:
            print("   marker unreadable: %s" % error)
            continue
        result = read_frame(path, -1)
        if result is None:
            print("   refused: the payload does not satisfy its marker (torn, or still being written)")
            continue
        seq, batch = result
        print("   accepted: seq %d, %d message(s)" % (seq, len(batch)))
        for line in batch:
            verb, fields = parse(line)
            if verb in ("SNAP", "DELTA") and len(fields) > 4:
                pairs = [part for part in fields[4].split(";") if part]
                print("   %s seq=%s frame=%s ack=%s  %d key(s)" % (verb, fields[0], fields[1], fields[3], len(pairs)))
                for pair in pairs[: (args.limit or 40)]:
                    print("       " + pair)
                if len(pairs) > (args.limit or 40):
                    print("       … %d more" % (len(pairs) - (args.limit or 40)))
            else:
                print("   %-6s %s" % (verb, " | ".join(fields[:8])))
        shown += 1
    return EXIT_OK if shown else EXIT_FAIL


def cmd_selftest(args: argparse.Namespace) -> int:
    """Three things, in the order they fail: the codec, the vectors both engines read, and a live
    two-peer exchange through a temporary mailbox."""
    import bridge_proto  # noqa: PLC0415

    print("== codec and conformance vectors")
    if bridge_proto.selftest(verbose=False) != 0:
        print("codec selftest FAILED", file=sys.stderr)
        return EXIT_FAIL
    from bridge_proto import read_compat_vectors

    vectors = os.path.join(HERE, "..", "Director", "Bridge.Vectors.txt")
    # a dict of sections -> one number to eyeball, and a floor that means "the file is real"
    sections = read_compat_vectors(vectors) if os.path.exists(vectors) else {}
    counts = {name: len(rows) for name, rows in sections.items()}
    total = sum(counts.values())
    print("vectors: %d records from %s  (%s)" % (total, os.path.relpath(vectors, HERE), ", ".join("%s=%d" % item for item in sorted(counts.items()))))
    if total < 30:
        print("   too few to mean anything -- regenerate: python3 bridge_proto.py vectors", file=sys.stderr)
        return EXIT_FAIL

    print("== live loopback, files transport, two peers in lockstep")
    with tempfile.TemporaryDirectory(prefix="bridge-probe-") as root:
        from bridge_transports import FilesTransport

        config = load_config(find_config(""))
        apply_overrides(config, transport="files", root=root)
        director = DirectorPeer(config=config, game=make_game())
        godot = GodotPeer(config=config, allow_write=True)
        director.bridge_transport = FilesTransport(director, root, crc=False)
        godot.bridge_transport = FilesTransport(godot, root, crc=False)
        for peer in (director, godot):
            peer.bridge_transport.start()
            peer.start()

        def spin(count: int = 1) -> None:
            for _ in range(count):
                for peer in (director, godot):
                    peer.frame += 1
                    peer.tick(peer.frame)
                    peer.flush()
                    batch = peer.bridge_transport.poll()
                    if batch:
                        peer.feed_batch(batch)

        ok = True
        for _ in range(30):
            spin()
            if director.peer_ready and godot.peer_ready and len(godot.peer_store) > 3:
                break
        ok &= expect("handshake both ways", director.peer_ready and godot.peer_ready)
        ok &= expect("godot mirrors gGame.Cash", isinstance(godot.peer_store.get("gGame.Cash"), int))
        asked = None
        for _ in range(3):
            asked = godot.get_path("gGame.Money") if "gGame.Money" in godot.peer_store else None
            holder: Dict[str, Any] = {}
            godot.request_get("gGame.Money", callback=lambda value: holder.setdefault("v", value))
            for _ in range(10):
                spin()
                if "v" in holder:
                    break
            asked = holder.get("v", asked)
            if not isinstance(asked, ProtocolError):
                break
        ok &= expect("REQ/RSP get", asked == director.game.get("Money"), "%r vs %r" % (asked, director.game.get("Money")))
        godot.command("set", "gGame.Cash", encode(424242))
        spin(8)
        ok &= expect("CMD set lands in the game", director.game.get("Cash") == 424242, repr(director.game.get("Cash")))
        godot.command("set", "bridge.probeKey", encode("from probe"))
        spin(8)
        ok &= expect("store replicates godot -> director", director.store.get("probeKey") == "from probe", str(director.store))
        # and the refusal has to reach the *asker* as an error, not just be logged over here
        denied_before = director.stats["denied"]
        refusal: Dict[str, Any] = {}
        godot.request_get("gSecret.stuff", callback=lambda value: refusal.setdefault("v", value))
        spin(20)
        ok &= expect(
            "a read outside expose is refused, with err back to the asker",
            director.stats["denied"] > denied_before and isinstance(refusal.get("v"), ProtocolError),
            "%r  denied=%d" % (refusal.get("v"), director.stats["denied"]),
        )
        for peer in (director, godot):
            peer.bridge_transport.stop()
        print("probe loopback: %s" % ("ok" if ok else "FAILED"))
        return EXIT_OK if ok else EXIT_FAIL


def expect(label: str, condition: Any, detail: str = "") -> bool:
    print("  %s %s%s" % ("ok  " if condition else "FAIL", label, "" if condition or not detail else "   <- " + detail))
    return bool(condition)


def cmd_repl(args: argparse.Namespace) -> int:
    with Probe(args) as probe:
        probe.greet(20)
        print("# probe as %s over %s  (get/set/list/store/status/quit)" % (probe.peer.cfg.role, probe.config.transport))
        while True:
            probe.pump(1, settle=0.005)
            try:
                line = input("bridge> ").strip()
            except (EOFError, KeyboardInterrupt):
                return EXIT_OK
            if not line:
                continue
            verb, _space, rest = line.partition(" ")
            if verb in ("quit", "exit"):
                return EXIT_OK
            if verb == "get":
                args.paths = [part for part in rest.replace(",", " ").split() if part] or ["gGame.Cash"]
                args.json = False
                cmd_get(args)
                continue
            if verb == "set":
                path, _sep, value = rest.partition(" ")
                args.path, args.value = path, value
                args.json = False
                cmd_set(args)
                continue
            if verb == "list":
                args.prefix, args.depth, args.json = rest or "gGame", 1, False
                cmd_list(args)
                continue
            if verb == "store":
                print("  ours: %s" % (dict((k, render(v)) for k, v in probe.peer.store.items()) or "{}"))
                print("  theirs: %s" % (dict((k, render(v)) for k, v in sorted(probe.peer.peer_store.items())) or "{}"))
                continue
            if verb == "status":
                args.json = False
                cmd_status(args)
                continue
            print("  try: get <path> | set <path> <value> | list <prefix> | store | status | quit")


# --------------------------------------------------------------------------------------------


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="bridge_probe.py",
        description="Shockwave/Godot bridge probe",
        epilog="global options go AFTER the subcommand: `get gGame.Cash --json`, not `--json get gGame.Cash`.",
    )
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--transport", choices=["files", "http", "tcp"], default="", help="override the config's transport")
    common.add_argument("--root", default="", help="mailbox folder for `files`")
    common.add_argument("--host", default="", help="peer host for http/tcp")
    common.add_argument("--port", type=int, default=0, help="peer port for http/tcp")
    common.add_argument("--config", default="", help="Bridge.Data.txt to read (default: auto-detect)")
    common.add_argument("--as", dest="as_role", choices=["director", "godot"], default="director", help="which end to imitate")
    common.add_argument("--json", action="store_true", help="machine-readable output")
    common.add_argument("--verbose", action="store_true", help="print every message sent and received")
    common.add_argument("--tries", type=int, default=3, help="RSPs to wait for before giving up (files loses frames)")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("get", parents=[common], help="read paths (mirror first, REQ only if needed)")
    p.add_argument("paths", nargs="+")
    p.set_defaults(func=cmd_get)

    p = sub.add_parser("set", parents=[common], help="write one path (the far side's allow-list applies)")
    p.add_argument("path")
    p.add_argument("value")
    p.set_defaults(func=cmd_set)

    p = sub.add_parser("call", parents=[common], help="invoke a handler over there")
    p.add_argument("handler")
    p.add_argument("data", nargs="?", default="", help="literal, e.g. '{\"message\": \"hi\"}'")
    p.add_argument("--target", default="", help="sprite number or expression, Director side")
    p.set_defaults(func=cmd_call)

    p = sub.add_parser("event", parents=[common], help="raise an event over there")
    p.add_argument("name")
    p.add_argument("kv", nargs="*", help="key=value pairs")
    p.set_defaults(func=cmd_event)

    p = sub.add_parser("list", parents=[common], help="enumerate a prefix")
    p.add_argument("prefix", nargs="?", default="gGame")
    p.add_argument("--depth", type=int, default=1)
    p.set_defaults(func=cmd_list)

    p = sub.add_parser("watch", parents=[common], help="print mirrored values as they change")
    p.add_argument("paths", nargs="*")
    p.add_argument("--hz", type=float, default=20.0)
    p.set_defaults(func=cmd_watch)

    p = sub.add_parser("status", parents=[common], help="handshake, sequences, stats, store, mirror")
    p.set_defaults(func=cmd_status)

    p = sub.add_parser("snap", parents=[common], help="turn the far side's snapshot on or off")
    p.add_argument("mode", choices=["on", "off"])
    p.add_argument("--rate", type=int, default=0)
    p.add_argument("--kind", choices=["delta", "full"], default="")
    p.set_defaults(func=cmd_snap)

    p = sub.add_parser("repl", parents=[common], help="interactive loop")
    p.set_defaults(func=cmd_repl)

    p = sub.add_parser("frames", help="decode a mailbox folder, offline")
    p.add_argument("path", nargs="?", default="")
    p.add_argument("--limit", type=int, default=0, help="keys to print per snapshot (default 40)")
    p.set_defaults(func=cmd_frames)

    p = sub.add_parser("selftest", parents=[common], help="codec, vectors, and a live two-peer loopback")
    p.set_defaults(func=cmd_selftest)
    return parser


def main(argv: List[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv[1:])
    if getattr(args, "paths", None) == [] and args.command == "watch":
        args.paths = ["gGame.CurrentVehicle.general.kmh"]
    try:
        return int(args.func(args))
    except KeyboardInterrupt:
        return EXIT_OK
    except BrokenPipeError:
        # `watch | head` and `frames | less` are normal things to do. The reader closing the pipe is
        # not a bridge failure, so answer it quietly -- and point our own stdout at /dev/null first, or
        # python adds an "Exception ignored" traceback at exit for the privilege.
        try:
            os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
        except OSError:
            pass
        return EXIT_OK
    except SystemExit as error:  # argparse and our own raise
        return int(error.code) if isinstance(error.code, int) else EXIT_USAGE


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
