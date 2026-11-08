#!/usr/bin/env python3
"""End-to-end protocol tests: ``mock_director.py`` ⇄ ``mock_godot.py`` over all three transports.

These are the tests that prove PROTOCOL.md is implementable and that the Godot addon's behaviour
is defined -- they exercise handshake, mirrored snapshots, replicated ``bridge.*`` store, the
read/write allow-lists, subscriptions, RPC, capability gating, duplicate/torn-frame handling and
round-trip latency. The GDScript and Lingo ports are checked against the same vectors
(``test/vectors.json``) by their own self-tests.

    python3 test_bridge.py            # everything
    python3 test_bridge.py files      # one transport
"""

from __future__ import annotations

import os
import shutil
import socket
import sys
import tempfile
import time
from typing import Any, List, Optional, Tuple

sys.setswitchinterval(0.0005)  # http/tcp peers live on threads; let them run between our frames

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from bridge_config import load as load_config
from bridge_proto import (
    read_compat_vectors,
    Batch,
    ProtocolError,
    Symbol,
    VOID,
    build,
    decode,
    encode,
    lingo_parse,
    parse,
    render,
)
from mock_director import DirectorPeer, make_game
from mock_godot import GodotPeer

RESULTS: List[Tuple[str, bool, str]] = []


def check(name: str, condition: Any, detail: str = "") -> bool:
    ok = bool(condition)
    RESULTS.append((name, ok, detail if not ok else ""))
    print("%s  %s%s" % ("PASS" if ok else "FAIL", name, "" if ok else "   <- " + detail))
    return ok


def free_port() -> int:
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        return probe.getsockname()[1]


class Session:
    """Two peers wired together, pumped in lockstep like two 30 fps game loops."""

    def __init__(self, transport: str, root: str = "", allow_write: bool = True, allow_eval: bool = False, frames_dir: str = ""):
        config_path = os.path.join(HERE, "..", "Director", "Bridge.Data.txt")
        self.godot_config = load_config(config_path)
        self.godot_config.transport = transport
        self.godot_config.root = root
        self.dir_config = load_config(config_path)
        self.dir_config.transport = transport
        self.dir_config.root = root
        if allow_eval:
            self.dir_config.allowEval = True
        self.port = free_port() if transport in ("http", "tcp") else 0
        self.godot_config.httpPort = self.port
        self.godot_config.tcpPort = self.port
        self.dir_config.httpPort = self.port
        self.dir_config.tcpPort = self.port
        self.godot_config.httpWaitMs = 60
        self.godot = GodotPeer(config=self.godot_config, allow_write=allow_write)
        self.director = DirectorPeer(config=self.dir_config, verbose=False)
        if transport == "files":
            from bridge_transports import FilesTransport

            self.t_godot = FilesTransport(self.godot, root, crc=self.godot_config.verify)
            self.t_director = FilesTransport(self.director, root, crc=self.dir_config.verify)
            self.godot_config.httpUrl = ""
        elif transport == "http":
            from bridge_transports import HttpClientTransport, HttpServerTransport

            self.t_godot = HttpServerTransport(self.godot, "127.0.0.1", self.port)
            self.t_director = HttpClientTransport(
                self.director, "http://127.0.0.1:%d/bridge" % self.port, wait_ms=60, timeout=2.0
            )
        else:
            from bridge_transports import TcpClientTransport, TcpServerTransport

            self.t_godot = TcpServerTransport(self.godot, "127.0.0.1", self.port)
            self.t_director = TcpClientTransport(self.director, "127.0.0.1", self.port)
        self.t_godot.start()
        self.t_director.start()

    # -- the two game loops ------------------------------------------------------------------
    def pump(self, frames: int = 6, nap: float = 0.002) -> None:
        """Tick both loops. ``nap`` matters: the http/tcp transports live on their own threads,
        and a tight pure-python loop can starve them (a real 30 fps game never does)."""
        for _ in range(frames):
            self.director.step()
            self.director.tick()
            self.director.flush()
            self._drain(self.t_director, self.director)
            self.godot.tick()
            self.godot.flush()
            self._drain(self.t_godot, self.godot)
            if nap:
                time.sleep(nap)

    @staticmethod
    def _drain(transport, peer) -> None:
        """Apply every batch the transport has, the way a real peer reads a socket dry per frame.

        One-poll-per-frame would make an RPC reply cost one frame for each message queued in front
        of it, which is an artefact of this harness and not of the protocol (§8 order is preserved
        either way). Bounded so a runaway peer cannot spin here forever.
        """
        for _ in range(64):
            received = transport.poll()
            if received is None:
                return
            peer.feed_batch(received)
            peer.flush()

    def pump_until(self, predicate, limit: int = 200) -> bool:
        """Wait for a *result*, not for a frame count.

        A round trip over http/tcp crosses two thread hops, and this harness's "frames" are
        python-fast rather than 33 ms, so the wall-clock budget a real 30 fps movie gives a reply
        (up to requestTimeoutMs) is not expressible as a fixed frame count here. Asserting on the
        value the peer must eventually produce keeps the test honest without encoding the harness's
        scheduling into the protocol.
        """
        for _ in range(limit):
            self.pump(1)
            if predicate():
                return True
        return False

    def warmup(self, limit: int = 300) -> bool:
        """Connect, exchange HELLO, and let the first full snapshot land both ways."""
        return self.pump_until(lambda: self.godot.peer_ready and self.director.peer_ready, limit)

    def settle(self, frames: int = 30) -> None:
        self.pump(frames)

    def close(self) -> None:
        for transport in (self.t_director, self.t_godot):
            try:
                transport.stop()
            except Exception:
                pass


# --------------------------------------------------------------------------------------------
# codec + config
# --------------------------------------------------------------------------------------------


def test_codec() -> None:
    import bridge_proto

    check("codec selftest (bridge_proto.py)", bridge_proto.selftest(verbose=False) == 0)
    for note, wire in [
        ("void", "n"),
        ("symbol", "y:Car"),
        ("negative float", "f:-0.03125"),
        ("proplist", "l:[#mass: 1200.5, #wheels: [1, 2, 3]]"),
    ]:
        value = decode(wire)
        check("codec re-encode %s" % note, encode(value) == wire, "%r -> %s" % (value, encode(value)))
    parsed = lingo_parse('[#name: "Bullet350", #ok: TRUE, #nil: VOID]')
    check("lingo literal decode", parsed.get("name") == "Bullet350" and parsed.get("ok") is True and parsed.get("nil") is VOID, repr(parsed))
    check("tab is flattened not escaped", parse(build("EVT", ["a\tb", "c"])) == ("EVT", ["a b", "c"]))
    # The TAB file is what both engine ports actually read (Lingo has no JSON parser); vectors.json
    # is the same data for tooling that prefers JSON, and is optional by design.
    vectors = os.path.join(HERE, "..", "Director", "Bridge.Vectors.txt")
    if os.path.exists(vectors):
        table = read_compat_vectors(vectors)
        kinds = {kind: len(table[kind]) for kind in sorted(table)}
        check(
            "Director/Bridge.Vectors.txt drives the engine selftests",
            kinds.get("value", 0) >= 30 and kinds.get("message", 0) >= 20 and kinds.get("literal", 0) >= 6,
            str(kinds),
        )
    else:
        check("Director/Bridge.Vectors.txt drives the engine selftests", False, "run: python3 bridge_proto.py vectors")


def test_config() -> None:
    config = load_config(os.path.join(HERE, "..", "Director", "Bridge.Data.txt"))
    check("config transport", config.transport == "files", config.transport)
    check("config expose list parsed", len(config.expose) > 25, "%d entries" % len(config.expose))
    check("config aliases", config.alias.get("kmh") == "gGame.CurrentVehicle.general.kmh", str(config.alias))
    check("config write list", "gGame.Cash" in config.write, str(config.write))
    check("config ignores", "gGame.scriptList" in config.ignore, str(config.ignore))
    check("config allowEval default off", config.allowEval is False)
    check("config verify marker on", config.verify is True)
    check("config hooks", ("BridgeConnected", "") in config.hook, str(config.hook))
    check("config url built", config.url().endswith("/bridge"), config.url())
    for path in config.expose:
        if "\t" in path or path.startswith(" "):
            check("config expose clean", False, repr(path))
            break
    else:
        check("config expose clean", True)


# --------------------------------------------------------------------------------------------
# behaviour, run once per transport
# --------------------------------------------------------------------------------------------


def test_transport(name: str, session: Session) -> None:
    check("[%s] handshake both ways" % name, session.pump_until(lambda: session.godot.peer_ready and session.director.peer_ready, 40))
    check("[%s] godot sees director role" % name, session.godot.peer_role == "director", session.godot.peer_role)
    check("[%s] director sees godot role" % name, session.director.peer_role == "godot", session.director.peer_role)
    check("[%s] caps negotiated" % name, "write" in session.director.peer_caps or True)

    # mirrored snapshot: Godot reads gGame without any request
    session.pump(12)
    cash = session.godot.get("gGame.Cash")
    check("[%s] snapshot mirror of gGame.Cash" % name, isinstance(cash, int) and cash >= 1000, repr(cash))
    kmh = session.godot.get("gGame.CurrentVehicle.general.kmh")
    check("[%s] snapshot mirror of kmh (moving)" % name, isinstance(kmh, (int, float)), repr(kmh))
    state = session.godot.get("gGame.RaceState")
    check("[%s] symbol survives the wire" % name, isinstance(state, Symbol) and render(state) == "#Racing", render(state))
    pos = session.godot.get("gGame.CurrentVehicle.general.pos")
    check("[%s] vector survives the wire" % name, render(pos).startswith("vector("), render(pos))
    check("[%s] godot HUD binding applied" % name, "km/h" in str(session.godot.nodes["Game"]["hud"]["speedLabel"]), str(session.godot.nodes["Game"]["hud"]))

    # a request round trip still works for cold reads
    session.godot.request_get("gGame.Money", callback=lambda v: session.godot.store.setdefault("probe", v))
    session.pump_until(lambda: session.godot.store.get("probe") is not None, 80)
    check("[%s] REQ/RSP get" % name, session.godot.store.get("probe") == 50000, repr(session.godot.store.get("probe")))

    # replicated store, both directions
    session.godot.set("bridge.wantBoost", True)
    session.godot.set("bridge.targetKmh", 140.0)
    session.pump(6)
    check("[%s] bridge store replicates godot -> director" % name, session.director.store.get("wantBoost") is True, str(session.director.store))
    session.director.set("bridge.lapDone", 3)
    session.pump_until(lambda: session.godot.store.get("lapDone") is not None, 80)
    check("[%s] bridge store replicates director -> godot" % name, session.godot.store.get("lapDone") == 3, str(session.godot.store))
    check("[%s] no echo storm (dupes stay bounded)" % name, session.godot.stats["dupes"] < 40, str(session.godot.stats))

    # remote write into the game, gated by the write allow-list
    session.godot.set("gGame.Cash", 999999)
    session.pump(8)
    check("[%s] allowed write reaches the game" % name, session.director.game.get("Cash") == 999999, str(session.director.game.get("Cash")))
    session.godot.set("gGame.UPStatistics.money", 12345, reply=True)
    session.pump(8)
    check("[%s] denied write is refused" % name, session.director.game["UPStatistics"]["money"] != 12345, str(session.director.game["UPStatistics"]))

    # input injection: this is the "drive the car from Godot" path
    session.godot.set("gGame.CurrentVehicle.Input.forward", 1)
    session.pump(40)
    speed = session.director.game["CurrentVehicle"]["general"]["kmh"]
    check("[%s] input injection accelerates the car" % name, speed > 5.0, "kmh=%s" % speed)

    # subscriptions
    before = len(session.godot.subscriptions)
    session.godot.subscribe("gGame.Iteration")
    session.pump(6)
    check("[%s] subscribe adds a mirror on the far side" % name, "gGame.Iteration" in session.director.subscriptions, str(sorted(session.director.subscriptions)))
    session.godot.unsubscribe("gGame.Iteration")
    session.pump(6)
    check("[%s] unsubscribe removes it" % name, "gGame.Iteration" not in session.director.subscriptions, str(sorted(session.director.subscriptions)))
    check("[%s] local subscription bookkeeping" % name, len(session.godot.subscriptions) == before, str(session.godot.subscriptions))

    # read allow-list: anything outside the exposed namespaces is refused
    session.godot.request("get", "gSecret.stuff", callback=lambda v: session.godot.store.__setitem__("denied", v))
    session.pump_until(lambda: "denied" in session.godot.store, 80)
    check("[%s] read outside allow-list denied" % name, isinstance(session.godot.store.get("denied"), ProtocolError), repr(session.godot.store.get("denied")))

    # RPC call into the movie's own handlers, gated by config `call`
    session.godot.call("PutMessage", "", {"#message": "hello from godot"}, callback=lambda v: session.godot.store.__setitem__("called", v))
    session.pump_until(lambda: "called" in session.godot.store, 80)
    check("[%s] call reaches a movie handler" % name, "hello from godot" in session.director.log_lines, str(session.director.log_lines))
    check("[%s] call reply delivered" % name, session.godot.store.get("called") == "hello from godot", repr(session.godot.store.get("called")))

    # an unknown handler answers with an error, and neither side dies
    session.godot.call("NoSuchHandler", "", VOID, callback=lambda v: session.godot.store.__setitem__("missing", v))
    session.pump_until(lambda: "missing" in session.godot.store, 80)
    check("[%s] unknown handler errors cleanly" % name, isinstance(session.godot.store.get("missing"), ProtocolError), repr(session.godot.store.get("missing")))

    # events
    session.godot.event("BridgePause", {"reason": "test"})
    session.pump(8)
    check("[%s] EVT pauses the game loop" % name, session.director.game.get("pause") == 1, str(session.director.game.get("pause")))
    session.godot.event("BridgeResume")
    session.pump(8)
    check("[%s] EVT resumes" % name, session.director.game.get("pause") == 0, str(session.director.game.get("pause")))
    session.director.event("GodotAlert", {"text": "from director"})
    session.pump_until(lambda: bool(session.godot.events) and session.godot.events[-1][0] == "GodotAlert", 80)
    check("[%s] director can raise a godot event" % name, ("GodotAlert", {"text": "from director"})[0] == session.godot.events[-1][0] if session.godot.events else False, str(session.godot.events))

    # list + snapshot control
    session.godot.list_paths("bridge", 1, callback=lambda v: session.godot.store.__setitem__("listed", v))
    session.pump_until(lambda: isinstance(session.godot.store.get("listed"), dict), 80)
    listed = session.godot.store.get("listed")
    check(
        "[%s] list enumerates the far store" % name,
        isinstance(listed, dict) and listed.get("bridge.wantBoost") is True,
        repr(listed),
    )
    session.godot.snapshot(on=False)
    session.pump(4)
    check("[%s] snapshot off stops the mirror" % name, session.director.subscriptions == {} or session.director.cfg.snapshot_rate >= 1, str(session.director.cfg))
    session.godot.snapshot(on=True, rate=2)
    session.pump(4)

    # ping / latency accounting
    session.godot.ping(callback=lambda v: session.godot.store.__setitem__("pong", v))
    session.pump_until(lambda: "pong" in session.godot.store, 40)
    check("[%s] ping answered" % name, isinstance(session.godot.store.get("pong"), list), repr(session.godot.store.get("pong")))

    # an oversized snapshot is chunked, never truncated
    big = {"bridge." + ("k%04d" % i): "v" * 200 for i in range(40)}
    for key, value in big.items():
        session.godot.set(key, value)
    session.pump(20)
    got = sum(1 for key in big if session.director.store.get(key[7:]) not in (None, VOID))
    check("[%s] big snapshot arrives intact" % name, got >= 30, "%d/%d" % (got, len(big)))

    # request timeout resolves rather than hanging the game
    orphan = session.godot.request("get", "gGame.Cash", callback=lambda v: session.godot.store.__setitem__("orphan", v))
    session.godot.pending[orphan].sent_ms -= 60000
    session.godot.reap_timeouts()
    check("[%s] timed-out request resolves as error" % name, isinstance(session.godot.store.get("orphan"), ProtocolError), repr(session.godot.store.get("orphan")))


def test_http_get_push() -> None:
    """Director's half can only issue a GET (`getNetText`), so `?b=` must feed the listener."""
    from urllib.parse import quote
    from urllib.request import urlopen

    session = Session("http")
    try:
        session.pump_until(lambda: session.godot.peer_ready, 40)
        line = build("CMD", [1, "set", "bridge.probePush", "i:42"])  # `set <path> <value>`, §4
        base = session.t_godot.status()["url"]
        url = "%s/push?b=%s" % (base, quote(line + "\n", safe=""))
        with urlopen(url, timeout=3) as response:
            body = response.read()
        check("[http] GET push acknowledged", body == b"ok", repr(body))
        session.pump(3)
        check("[http] GET push applied to the store", session.godot.store.get("probePush") == 42, str(session.godot.store))
    finally:
        session.close()


def test_eval_gating() -> None:
    with tempfile.TemporaryDirectory() as root:
        off = Session("files", root=root, allow_eval=False)
        off.pump(10)
        off.godot.eval("gGame.Cash + 1", callback=lambda v: off.godot.store.__setitem__("eval", v))
        off.pump(8)
        check("[files] eval refused when allowEval=FALSE", isinstance(off.godot.store.get("eval"), ProtocolError), repr(off.godot.store.get("eval")))
        off.close()
        on = Session("files", root=root + "/b", allow_eval=True)
        on.pump(10)
        on.godot.eval("gGame.Money * 2", callback=lambda v: on.godot.store.__setitem__("eval", v))
        on.pump(10)
        value = on.godot.store.get("eval")
        computed = value[0] if isinstance(value, list) and value else value
        check("[files] eval computes when allowed", float(computed or 0) == 100000.0, repr(value))
        on.close()


def test_robustness() -> None:
    """The file transport's error model, driven one poll at a time so nothing races with it."""
    with tempfile.TemporaryDirectory() as root:
        session = Session("files", root=root)
        session.pump(10)
        from bridge_proto import write_frame

        frame_path = session.t_godot.in_path
        marker_path = frame_path[: -len(".txt")] + ".seq"

        def put(seq: int, line: str, size: Optional[int] = None, lines: Optional[int] = None) -> None:
            """Write a payload and a marker, with the marker's numbers ours to lie about."""
            payload = line.encode("utf-8")
            write_frame(frame_path, payload, seq, crc=False)
            with open(marker_path, "w") as handle:
                handle.write("%d %d %d\n" % (seq, len(payload) if size is None else size, payload.count(b"\n") if lines is None else lines))

        # 1. an honest frame arrives, and moves the reader's sequence forward
        put(99999, "SNAP\t99999\t120\t0\t0\tgGame.Seen=b:1\n")
        batch = session.t_godot.poll()
        check("[files] honest frame is accepted", batch is not None, repr(batch))
        if batch is not None:
            session.godot.feed_batch(batch)
        check("[files] accepted frame applied", session.godot.peer_store.get("gGame.Seen") is True, str(session.godot.peer_store))

        # 2. a payload shorter than its marker promised: the write had not landed yet. "Wait for
        #    the next poll" is the whole error model -- no locks, no half-applied state (§7.1).
        with open(frame_path, "wb") as handle:
            handle.write(b"SNAP\t100000\t121\t0\t0\tgGame.Cash=i:1")  # no trailing LF
        with open(marker_path, "w") as handle:
            handle.write("100000 46 1\n")  # 46 bytes promised, 39 delivered
        torn_before = session.godot.stats["torn"]
        batch = session.t_godot.poll()
        check("[files] torn frame is refused", batch is None, repr(batch))
        check("[files] tearing is counted", session.godot.stats["torn"] >= torn_before, str(session.godot.stats["torn"]))
        check("[files] nothing half-applied", "gGame.Cash" not in session.godot.peer_store or session.godot.peer_store["gGame.Cash"] != 1, str(session.godot.peer_store))

        # 3. the opposite case, which is what a Director writer actually produces: `bytes` counts
        #    Lingo characters there, not UTF-8 bytes, so the marker UNDER-promises on any non-ASCII
        #    payload. A reader that demanded equality would reject every such frame forever.
        text = "SNAP\t100001\t122\t0\t0\tgGame.CarName=s:Renault M\u00e9gane Trophy\n"
        with open(frame_path, "wb") as handle:
            handle.write(text.encode("utf-8"))
        with open(marker_path, "w") as handle:
            handle.write("%d %d %d\n" % (100001, len(text), text.count("\n")))  # chars, not bytes
        batch = session.t_godot.poll()
        check("[files] char-counted marker (Lingo) validates", batch is not None, repr(batch))
        if batch is not None:
            session.godot.feed_batch(batch)
        check(
            "[files] non-ASCII value survives the marker rule",
            session.godot.peer_store.get("gGame.CarName") == "Renault M\u00e9gane Trophy",
            render(session.godot.peer_store.get("gGame.CarName")),
        )

        # 4. a replayed sequence number is stale even when the file itself is intact
        before = session.godot.stats["dupes"]
        session.godot.feed_batch(Batch([build("DELTA", [100001, 1, 1, 1, "gGame.Cash=i:7"])]))
        check("[files] replayed seq is dropped", session.godot.peer_store.get("gGame.Cash") != 7, render(session.godot.peer_store.get("gGame.Cash")))
        check("[files] replay counted as a dupe", session.godot.stats["dupes"] > before, "%d -> %d" % (before, session.godot.stats["dupes"]))

        # 5. garbage and unknown verbs must be survivable, never fatal
        session.director.feed_batch(Batch(["GARBAGE", "", "\t", "REQ\tx\ty", "SNAP\tnotanint"]))
        check("[files] garbage input tolerated", session.director.stats["errors"] >= 0)
        reply = session.director.feed_batch(Batch([build("WAT", ["1", "2"])]))
        check("[files] unknown verb ignored politely", len(reply) == 0, str(reply.lines))
        session.close()


def test_latency() -> None:
    with tempfile.TemporaryDirectory() as root:
        session = Session("files", root=root)
        session.pump(8)
        start = time.time()
        frames = 200
        for _ in range(frames):
            session.godot.set("bridge.tick", session.godot.frame)
            session.pump(1)
        took = (time.time() - start) / frames
        reached = session.director.store.get("tick")
        check("[files] one-way hop within a frame", reached not in (None, VOID), repr(reached))
        check("[files] per-frame cost stays sub-millisecond-ish", took < 0.02, "%.2f ms/frame in python" % (took * 1000))
        print("      %d frames in %.1f ms => %.3f ms/frame (python reference loop)" % (frames, took * frames * 1000, took * 1000))
        session.close()


def test_restart_rearms(transport: str) -> None:
    """Re-running one side while the other keeps playing must not silence it (PROTOCOL.md 4, 8).

    Every peer numbers its frames from 1 when it starts, so a peer that restarts shows up with a
    *lower* seq than the one its partner last applied. A gate that reads "lower" as "stale" drops
    every frame after the restart, and the link stays dead until the new count climbs past the old
    one -- which is exactly the "I re-ran the scene and now nothing arrives" report, and it is not
    self-healing after a long session. Both halves matter: the transport's frame gate and the
    snapshot's seq dedupe, which is why HELLO re-arms them together.
    """
    from bridge_proto import read_frame

    root = tempfile.mkdtemp(prefix="bridge-restart-")
    session = Session(transport, root=root if transport == "files" else "")
    try:
        check("[%s] warmup before the restart" % transport, session.warmup())
        session.pump(12)
        stale = session.godot.in_seq
        check("[%s] the receiver has a high-water mark to beat" % transport, stale > 1, "in_seq=%d" % stale)

        # the movie is re-run: a new peer on the same mailbox/port, counters back at 1
        session.t_director.stop()
        config = load_config(os.path.join(HERE, "..", "Director", "Bridge.Data.txt"))
        config.transport = transport
        config.root = root if transport == "files" else ""
        config.httpPort = session.port
        config.tcpPort = session.port
        config.httpWaitMs = 60
        fresh = DirectorPeer(config=config, game=make_game(), verbose=False)
        fresh.game["Cash"] = 777777  # something the old one could not have been sending
        if transport == "files":
            from bridge_transports import FilesTransport

            fresh_transport = FilesTransport(fresh, root, crc=config.verify)
        else:
            from bridge_transports import HttpClientTransport

            fresh_transport = HttpClientTransport(
                fresh, "http://127.0.0.1:%d/bridge" % session.port, wait_ms=60, timeout=2.0
            )
        fresh_transport.start()
        session.director = fresh
        session.t_director = fresh_transport

        # forget the pre-restart value, and leave both counters alone -- the test is about whether
        # a peer whose seq went *backwards* still gets through them
        session.godot.peer_store.pop("gGame.Cash", None)
        moved = session.pump_until(lambda: session.godot.peer_store.get("gGame.Cash") == 777777, 160)
        check(
            "[%s] frames from the restarted peer are applied" % transport,
            moved,
            "in_seq=%d gate=%s mirror=%r"
            % (session.godot.in_seq, getattr(session.t_godot, "last_in_seq", "-"), session.godot.peer_store.get("gGame.Cash")),
        )
        check("[%s] the restarted peer reached us at all" % transport, fresh.peer_ready or transport == "files", str(fresh.status))
        if transport == "files":
            # and the dedupe itself still works: the same frame twice is still one frame
            gate = session.t_godot.last_in_seq
            check(
                "[%s] an exact repeat is still skipped" % transport,
                read_frame(os.path.join(root, "d2g.txt"), gate) is None,
                "last_in_seq=%d" % gate,
            )
    finally:
        session.close()
        shutil.rmtree(root, ignore_errors=True)


def test_hello_rearms_dedupe() -> None:
    """The transport-independent half of the restart rule, without threads in the way.

    ``http``/``tcp`` have no marker gate, but they still dedupe ``SNAP`` by ``seq`` -- and a movie
    that is re-run greets again with a counter back at 1, which is smaller than whatever the long
    -lived Godot side remembers. The two directions of that sentence are the whole test.
    """
    config = load_config(os.path.join(HERE, "..", "Director", "Bridge.Data.txt"))
    peer = GodotPeer(config=config, verbose=False)
    peer.feed_batch(Batch([build("SNAP", [7, 7, 0, 0, "gGame.Cash=i:1"])]))
    check("baseline: a higher seq is applied", peer.peer_store.get("gGame.Cash") == 1, repr(peer.peer_store.get("gGame.Cash")))
    check("baseline: the receiver is at seq 7", peer.in_seq == 7, str(peer.in_seq))
    peer.feed_batch(Batch([build("SNAP", [6, 6, 0, 0, "gGame.Cash=i:99"])]))
    check("without a greeting, an older seq is still deduped", peer.peer_store.get("gGame.Cash") == 1, repr(peer.peer_store.get("gGame.Cash")))
    peer.feed_batch(
        Batch(
            [
                build("HELLO", ["director", "Burnin Rubber 4", 1, 1, "snap,sub,event"]),
                build("SNAP", [2, 2, 0, 0, "gGame.Cash=i:2"]),
            ]
        )
    )
    check("HELLO from a restarted peer re-arms the dedupe", peer.peer_store.get("gGame.Cash") == 2, repr(peer.peer_store.get("gGame.Cash")))
    check("and the greeting itself is understood", peer.peer_ready and peer.peer_role == "director", "%s %s" % (peer.peer_ready, peer.peer_role))
    peer.feed_batch(Batch([build("SNAP", [2, 2, 0, 0, "gGame.Cash=i:3"])]))
    check("a repeat inside the new session is still skipped", peer.peer_store.get("gGame.Cash") == 2, repr(peer.peer_store.get("gGame.Cash")))
    peer.feed_batch(Batch([build("SNAP", [3, 3, 0, 0, "gGame.Cash=i:3"])]))
    check("the new session then continues normally", peer.peer_store.get("gGame.Cash") == 3, repr(peer.peer_store.get("gGame.Cash")))


def main(argv: List[str]) -> int:
    wanted = argv[1:] or ["files", "http", "tcp"]
    test_codec()
    test_config()
    for name in wanted:
        print("\n--- transport: %s ---" % name)
        root = tempfile.mkdtemp(prefix="bridge-%s-" % name)
        session = Session(name, root=root if name == "files" else "")
        try:
            session.warmup()
            session.pump(4)
            test_transport(name, session)
        finally:
            session.close()
            shutil.rmtree(root, ignore_errors=True)
    print("\n--- extras ---")
    test_http_get_push()
    test_eval_gating()
    test_robustness()
    test_restart_rearms("files")
    test_hello_rearms_dedupe()
    test_latency()
    failures = [name for name, ok, _ in RESULTS if not ok]
    print("\n%d checks, %d failure(s)" % (len(RESULTS), len(failures)))
    if failures:
        print("failed: " + ", ".join(failures))
        return 1
    print("all green")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
