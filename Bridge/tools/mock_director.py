#!/usr/bin/env python3
"""Mock Shockwave/Director peer: speaks the bridge exactly like ``[M] Shockwave Bridge.ls``,
against a simulated Burnin' Rubber 4 runtime instead of a real Director movie.

Two reasons it exists:
1. it is how the protocol is tested in this repo (``test_bridge.py``) and how you can develop the
   Godot side without launching Director;
2. it is a live oracle for the Lingo port — the path syntax, ops, allow-lists and config file are
   shared, so a ``REQ get gGame.vehicles[1].general.kmh`` behaves the same against either.

    python3 mock_director.py                       # files transport against ./BridgeData
    python3 mock_director.py --transport http      # long-polls the Godot addon's HTTP server
    python3 mock_director.py --transport tcp       # connects to the Godot addon's TCP listener
    python3 mock_director.py --fps 32 --verbose
    python3 mock_director.py --once --transport tcp --script drive.txt

The simulation is deliberately simple but its *shape* matches the real game (``gGame`` propList,
``gGame.vehicles`` list of car records with ``.general`` / ``.Input`` / ``.physics``, symbols for
states, TAB data files), and it honours writes: set ``gGame.CurrentVehicle.Input.forward`` to 1
from Godot and the mock car accelerates, so the whole loop is exercised in both directions.
"""

from __future__ import annotations

import argparse
import math
import os
import random
import sys
import time
from typing import Any, Dict, List, Optional, Tuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from bridge_config import BridgeConfig, apply_overrides, load as load_config
from bridge_peer import Config, Peer
from bridge_proto import (
    Batch,
    Color,
    Point,
    ProtocolError,
    Symbol,
    VOID,
    Vector,
    allowed,
    bridge_key,
    encode,
    is_bridge_path,
    path_child,
    render,
    sanitize,
)
from bridge_transports import FilesTransport, HttpClientTransport, TcpClientTransport

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_CONFIG = os.path.normpath(os.path.join(HERE, "..", "Director", "Bridge.Data.txt"))


# --------------------------------------------------------------------------------------------
# simulated runtime
# --------------------------------------------------------------------------------------------

CAR_NAMES = ["Bullet350", "PhaserGti", "Rally7", "Sunstorm", "MonsterTruck"]


def make_game() -> Dict[str, Any]:
    """A ``gGame``-shaped state dict, seeded from ``Director Movie File (.dcr)/Globals.txt``."""
    cars: List[Dict[str, Any]] = []
    for index, name in enumerate(CAR_NAMES[:4]):
        cars.append(
            {
                "name": name,
                "controller": Symbol("#player" if index == 0 else "#AI"),
                "general": {
                    "kmh": 0.0,
                    "pos": Vector(index * 12.0, -88.5, 4.0),
                    "rot": Vector(0.0, 0.0, 1.5708),
                    "health": 100.0,
                    "nitro": 0.0,
                    "slip": 0.0,
                    "gear": 1,
                    "state": Symbol("#Racing"),
                    "waypoint": index * 3,
                    "laps": 0,
                },
                "Input": {"forward": 0, "backward": 0, "left": 0, "right": 0, "brake": 0, "action1": 0, "action2": 0},
                "physics": {"mass": 1200.0 + index * 90.0, "maxSpeed": 240.0 + index * 8.0, "wheelSpin": 0.0},
                "weapons": {"primary": Symbol("#MachineGun"), "secondary": Symbol("#RocketPod"), "ammo": [120, 24]},
            }
        )
    return {
        "name": "Burnin Rubber 4",
        "version": 2.2,
        "Scene": Symbol("#World"),
        "World": Symbol("#City"),
        "Track": Symbol("#OperationSandStorm1"),
        "RaceState": Symbol("#Racing"),
        "Vehicle": Symbol("#Car"),
        "Cash": 1000,
        "Money": 50000,
        "pause": 0,
        "Input": 1,
        "tempo": 32.0,
        "frameRate": Symbol("#limit"),
        "resolution": [800, 450],
        "stageSize": Point(800, 450),
        "worldscale": 1.0,
        "TimeMP": 1.0,
        "Iteration": 0,
        "Bloom": 1,
        "BloomSize": 0.0625,
        "Lightmaps": 1,
        "AI": 3,
        "AIsBuild": 3,
        "PlayersBuild": 1,
        "startTime": 0,
        "CheckPoints": {"done": 0, "total": 9},
        "traffic": {"count": 26, "hidden": 0},
        "interface": {"kmh": Point(700, 400), "visible": 1},
        "MiniMap": {"rotation": 1.5708, "scale": 0.5},
        "vehicles": cars,
        "CurrentVehicle": cars[0],
        "UPCars": ["Bullet350", "PhaserGti"],
        "UPStatistics": {"money": 0, "totalTime": 0, "carsWrecked": 0, "ticketsCompleted": [0, 36]},
        "tint": Color(255, 255, 255),
    }


def make_system(path: str) -> Dict[str, Any]:
    return {
        "debug": 0,
        "local": 1,
        "Init": 1,
        "Focus": 1,
        "path": path + os.sep,
        "frame": 0,
        "itemDelimiter": "\t",
        "event": Symbol("#none"),
        "text": {"engine": Symbol("#Director")},
    }


class DirectorPeer(Peer):
    """Lingo-side behaviour: ``value()``-style path reads, ``do()``-style writes, handler calls."""

    def __init__(
        self,
        config: Optional[BridgeConfig] = None,
        game: Optional[Dict[str, Any]] = None,
        movie_path: str = ".",
        verbose: bool = False,
        allow_eval: Optional[bool] = None,
    ):
        self.game = game if game is not None else make_game()
        self.system = make_system(movie_path)
        self.data: Dict[str, Any] = {"Events": {}, "data": {}, "Triggers": [], "Info": {}}
        self.globals: Dict[str, Dict[str, Any]] = {"gGame": self.game, "gSystem": self.system, "gData": self.data}
        self.members: Dict[str, Dict[str, Any]] = {
            "Console": {"text": "", "type": "text"},
            "FPSCounterText": {"text": "32 fps", "type": "text"},
            "GameVersion": {"text": "2.2", "type": "text"},
        }
        self.sprites: Dict[int, Dict[str, Any]] = {
            1: {"member": "Console", "loc": Point(0, 0), "locH": 0.0, "locV": 0.0, "visible": 1},
            2: {"member": "FPSCounterText", "loc": Point(700, 20), "locH": 700.0, "locV": 20.0, "visible": 1},
        }
        self.log_lines: List[str] = []
        self.events_seen: List[Tuple[str, Any]] = []
        self.bridge_config = config or BridgeConfig()
        overrides = self.bridge_config
        caps = ["write", "snap", "sub", "event", "call", "list"]
        if overrides.allowEval:
            caps.insert(1, "eval")
        if overrides.allowExec:
            caps.insert(2, "exec")
        peer_config = Config(
            role="director",
            name="Burnin Rubber 4",
            caps=tuple(caps),
            allow_read=overrides.read_patterns(),
            allow_write=overrides.allow_list(),
            allow_eval=bool(overrides.allowEval if allow_eval is None else allow_eval),
            snapshot_rate=overrides.rate,
            snapshot_mode=overrides.snapshot,
            peer_timeout_ms=overrides.peerTimeoutMs,
            request_timeout_ms=overrides.requestTimeoutMs,
        )
        super().__init__(peer_config, verbose=verbose)
        if self.bridge_config.expose:
            for path in self.bridge_config.expose:
                if "*" not in path:
                    self.subscriptions[path] = 0
        self.rng = random.Random(20100415)  # xform released BR4 in 2010; deterministic replay

    # -- simulation -------------------------------------------------------------------------
    def step(self) -> None:
        """One game frame of very fake driving, so mirrors have something to look at."""
        if self.game.get("pause"):
            return
        for car in self.game["vehicles"]:
            player = car["controller"] == Symbol("#player")
            keys = car["Input"]
            if not player or not self.game.get("Input", 1):
                if not player:  # AI drives itself
                    keys = {"forward": 1, "brake": 0, "left": int(self.rng.random() < 0.15), "right": int(self.rng.random() < 0.15), "backward": 0, "action1": 0, "action2": 0}
                else:
                    keys = {k: 0 for k in keys}
            limits = car["physics"]
            speed = car["general"]["kmh"]
            accel = 0.9 if keys.get("forward") else (-0.35 if keys.get("brake") or keys.get("backward") else -0.12)
            if keys.get("backward") and speed < 40:
                accel = -0.6
            speed += accel
            if keys.get("action1"):  # nitro
                speed += 1.2
                car["general"]["nitro"] = min(1.0, car["general"]["nitro"] + 0.02)
            else:
                car["general"]["nitro"] = max(0.0, car["general"]["nitro"] - 0.01)
            speed = max(-40.0, min(limits["maxSpeed"], speed))
            car["general"]["kmh"] = round(speed, 2)
            heading = car["general"]["rot"].z
            turn = (1 if keys.get("left") else 0) - (1 if keys.get("right") else 0)
            heading = (heading + turn * 0.006 * min(1.0, abs(speed) / 60.0) + math.pi * 2) % (math.pi * 2)
            car["general"]["rot"] = Vector(0.0, 0.0, round(heading, 4))
            position = car["general"]["pos"]
            scale = 0.09
            car["general"]["pos"] = Vector(
                round(position.x + math.cos(heading) * speed * scale, 3),
                round(position.y + math.sin(heading) * speed * scale, 3),
                position.z,
            )
            car["physics"]["wheelSpin"] = round(speed * 0.32, 2)
            if player:
                self.game["CheckPoints"]["done"] = min(
                    self.game["CheckPoints"]["total"], int(abs(position.x) // 240)
                )
                if speed > 60 and self.rng.random() < 0.01:
                    self.game["Cash"] += 5
                    self.game["UPStatistics"]["money"] += 5
        self.game["startTime"] = self.game.get("startTime", 0) + 31.25
        self.system["frame"] = self.frame

    # -- path engine (mirrors value()/do() on the Lingo side) --------------------------------
    def resolve_path(self, path: str) -> Any:
        if is_bridge_path(path):
            return self.store.get(bridge_key(path), VOID)
        root = path.split(".")[0].split("[")[0]
        if root == "member":
            return self._member_lookup(path)
        if root == "sprite":
            return self._sprite_lookup(path)
        if root not in self.globals:
            return VOID
        return _walk(self.globals[root], _segments(path)[1:])

    def write_path(self, path: str, value: Any) -> bool:
        if is_bridge_path(path):
            key = bridge_key(path)
            if value is VOID:
                self.store.pop(key, None)
            else:
                self.store[key] = value
            return True
        segments = _segments(path)
        if not segments or segments[0] not in self.globals:
            return False
        return _assign(self.globals[segments[0]], segments[1:], value)

    def enumerate(self, prefix: str, depth: int) -> List[Tuple[str, Any]]:  # noqa: C901
        out: List[Tuple[str, Any]] = []
        if not prefix or prefix in ("gBridge", "bridge") or is_bridge_path(prefix):
            for key, value in sorted(self.store.items()):
                out.append(("bridge." + key, value))
            if not prefix or is_bridge_path(prefix) or prefix in ("gBridge", "bridge"):
                return out
        segments = _segments(prefix)
        if not segments or segments[0] not in self.globals:
            return out
        node = _walk(self.globals[segments[0]], segments[1:])
        _collect(segments and ".".join(segments) or prefix, node, depth, out)
        if self.bridge_config.expose:
            out = [(p, v) for p, v in out if allowed(p, self.cfg.allow_read)]
        return out

    def execute_call(self, handler: str, target: str, data: Any) -> Any:
        self.log("info", "call", handler, target, render(data))
        if handler == "PutMessage":
            text = None
            if isinstance(data, dict):
                for candidate in ("message", "#message", "text", "#text"):
                    if data.get(candidate) is not None:
                        text = data[candidate]
                        break
            if text is None:
                text = str(data)
            self.log_lines.append(str(text))
            return str(text)
        if handler == "LogMessage":
            self.log_lines.append(str(data.get("message", data) if isinstance(data, dict) else data))
            return 1
        if handler in ("event", "Event"):
            name = data if isinstance(data, str) else (data.get("#event") if isinstance(data, dict) else "")
            self.events_seen.append((str(name), data))
            return 1
        if handler == "alert":
            self.log("info", "alert:", str(data))
            return VOID
        if handler == "GetGlobals":
            return dict(self.game)
        if handler in ("GetVersion", "getVersion"):
            return str(self.game["version"])
        raise ProtocolError("notfound", "handler %s is not implemented by the mock" % handler)

    def raise_event(self, name: str, data: Any) -> None:
        self.events_seen.append((name, data))
        if name == "BridgePause":
            requested = data.get("pause", 1) if isinstance(data, dict) else 1
            self.game["pause"] = int(bool(requested))
        elif name == "BridgeResume":
            self.game["pause"] = 0
        elif name in ("BridgeReset", "ResetGame"):
            fresh = make_game()
            self.game.clear()
            self.game.update(fresh)
        elif name == "BridgeSpawn":
            self.game["Cash"] = int(self.game.get("Cash", 0)) + 100

    def evaluate(self, expression: str) -> Any:
        return _mini_eval(self, expression)

    def executes(self, statements: str) -> Any:
        for line in filter(None, (part.strip() for part in statements.replace(";", "\n").split("\n"))):
            target, sep, raw = line.partition("=")
            if not sep:
                raise ProtocolError("badargs", "expected <path> = <value>, got %r" % line)
            if not self.write_path(target.strip(), decode_literal(raw.strip())):
                raise ProtocolError("nopath", target.strip())
        return 1

    # -- helpers ------------------------------------------------------------------------------
    def _member_lookup(self, path: str) -> Any:
        name = path.partition("(")[2].partition(")")[0].strip().strip('"')
        member = self.members.get(name)
        if member is None:
            return VOID
        rest = _segments(path.split(")", 1)[1].lstrip(".")) if ")" in path else []
        return _walk(member, rest)

    def _sprite_lookup(self, path: str) -> Any:
        number = path.partition("(")[2].partition(")")[0].strip()
        sprite = self.sprites.get(int(number) if number.isdigit() else -1)
        if sprite is None:
            return VOID
        rest = _segments(path.split(")", 1)[1].lstrip(".")) if ")" in path else []
        return _walk(sprite, rest)


def _segments(path: str) -> List[str]:
    out: List[str] = []
    token = ""
    for char in path:
        if char == ".":
            if token:
                out.append(token)
            token = ""
        elif char == "[":
            if token:
                out.append(token)
            token = ""
        elif char == "]":
            if token:
                out.append(token)
            token = ""
        else:
            token += char
    if token:
        out.append(token)
    return out


def _walk(node: Any, segments: List[str]) -> Any:
    current = node
    for segment in segments:
        if current is VOID or current is None:
            return VOID
        if isinstance(current, dict):
            if segment in current:
                current = current[segment]
                continue
            symbol = Symbol("#" + segment)
            if symbol in current or ("#" + segment) in current:
                current = current.get(symbol, current.get("#" + segment))
                continue
            return VOID
        if isinstance(current, (list, tuple)):
            if not segment.lstrip("-").isdigit():
                return VOID
            index = int(segment)
            index = index - 1 if index >= 0 else index
            if index < 0 or index >= len(current):
                return VOID
            current = current[index]
            continue
        return getattr(current, segment, VOID)
    return current


def _assign(node: Any, segments: List[str], value: Any) -> bool:
    if not segments:
        return False
    target = _walk(node, segments[:-1])
    last = segments[-1]
    if isinstance(target, dict):
        if value is VOID:
            target.pop(last, None)
            target.pop(Symbol("#" + last), None)
        else:
            existing = [key for key in target if str(key).lstrip("#").lower() == last.lower()]
            for key in existing:
                target.pop(key)
            target[last] = value
        return True
    if isinstance(target, list) and last.lstrip("-").isdigit():
        index = int(last) - (1 if int(last) > 0 else 0)
        if 0 <= index < len(target):
            target[index] = value
            return True
    return False


def _collect(prefix: str, node: Any, depth: int, out: List[Tuple[str, Any]]) -> None:
    if isinstance(node, dict):
        for key, value in node.items():
            name = str(key).lstrip("#")
            child = path_child(prefix, name)
            if isinstance(value, (dict, list)) and depth != 0:
                _collect(child, value, depth - 1, out)
            else:
                out.append((child, value))
    elif isinstance(node, (list, tuple)):
        for index, value in enumerate(node):
            child = path_child(prefix, index + 1)
            if isinstance(value, (dict, list)) and depth != 0:
                _collect(child, value, depth - 1, out)
            else:
                out.append((child, value))
    else:
        out.append((prefix, node))


def decode_literal(text: str) -> Any:
    text = text.strip()
    if text[:1] == '"' and text[-1:] == '"':
        return text[1:-1]
    if text[:1] == "#" or text[:1] == "[" or text[:1] in "-0123456789." or text.upper() in ("TRUE", "FALSE", "VOID"):
        from bridge_proto import lingo_parse

        return lingo_parse(text) if text[:1] == "[" else _scalar(text)
    return text


def _scalar(text: str) -> Any:
    from bridge_proto import scalar

    try:
        return scalar(text)
    except ProtocolError:
        return text


def _mini_eval(peer: "DirectorPeer", expression: str) -> Any:
    """Enough of Lingo expression syntax to be useful in tests and demos: paths, + - * / and
    string concat with '&'. The real Lingo side hands the same strings to ``value()``."""
    text = expression.strip()
    for operator in (" + ", " - ", " * ", " / "):
        if operator in text:
            left, _, right = text.partition(operator)
            a = _mini_eval(peer, left)
            b = _mini_eval(peer, right)
            a = 0.0 if a is VOID else a
            b = 0.0 if b is VOID else b
            try:
                if operator == " + ":
                    return a + b
                if operator == " - ":
                    return a - b
                if operator == " * ":
                    return a * b
                return a / b if b else VOID
            except (TypeError, ZeroDivisionError):
                return VOID
    if "&" in text:
        parts = [str(_mini_eval(peer, part)) for part in text.split("&")]
        return "".join(p.strip() for p in parts)
    if text[:1] == '"' and text[-1:] == '"':
        return text[1:-1]
    if text.upper() in ("TRUE", "1"):
        return True
    if text.upper() in ("FALSE", "0"):
        return False
    if text.upper() == "VOID":
        return VOID
    try:
        return int(text) if text.lstrip("-").isdigit() else float(text)
    except ValueError:
        pass
    value = peer.resolve_path(text)
    if value is VOID and "." in text:
        raise ProtocolError("notfound", text)
    return value


# --------------------------------------------------------------------------------------------
# runner
# --------------------------------------------------------------------------------------------


def build_transport(peer: DirectorPeer, config: BridgeConfig, transport: str):
    if transport == "files":
        root = config.resolved_root(os.getcwd())
        return FilesTransport(peer, root, crc=config.verify)
    if transport == "http":
        return HttpClientTransport(peer, config.url(), wait_ms=config.httpWaitMs)
    if transport == "tcp":
        return TcpClientTransport(peer, config.httpHost, config.tcpPort, binary=config.binary)
    raise SystemExit("unknown transport %r (files|http|tcp)" % transport)


def run_script(peer: DirectorPeer, transport: Any, script_path: str, fps: float, settle_s: float = 0.35) -> None:
    """``--script`` runs a list of commands then exits: used by the test-suite."""
    with open(script_path, encoding="utf-8") as handle:
        lines = [line.strip() for line in handle if line.strip() and not line.startswith("#")]
    for line in lines:
        verb, _, rest = line.partition(" ")
        args = rest.split(" ", 1)
        if verb == "wait":
            deadline = time.time() + float(args[0] if args else "1")
            while time.time() < deadline:
                step(peer, transport, fps)
            continue
        if verb == "set":
            path, _, value = rest.partition(" ")
            peer.set(path.strip(), decode_literal(value))
        elif verb == "get":
            print("get %s = %s" % (rest, render(peer.get(rest))))
        elif verb == "event":
            peer.event(rest)
        elif verb == "subscribe":
            for path in rest.split(","):
                peer.subscribe(path.strip())
        elif verb == "eval":
            result: List[Any] = []

            def show(value: Any, sink: List[Any] = result) -> None:
                sink.append(value)

            peer.eval(rest, callback=show)
            while not result and step(peer, transport, fps):
                pass
            print("eval %s -> %s" % (rest, render(result[0]) if result else "no reply"))
        elif verb == "snapshot":
            peer.snapshot(on=(rest != "off"), rate=int(rest.split()[1]) if len(rest.split()) > 1 else None)
        step(peer, transport, fps)
    deadline = time.time() + settle_s
    while time.time() < deadline:
        step(peer, transport, fps)


def step(peer: DirectorPeer, transport: Any, fps: float) -> bool:
    peer.step()
    peer.tick()
    peer.flush()
    received = transport.poll()
    if received is not None:
        peer.feed_batch(received)
        peer.flush()
    time.sleep(1.0 / max(1.0, fps))
    return True


def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser(description="Mock Shockwave (Director) peer")
    parser.add_argument("--transport", choices=("files", "http", "tcp"), default=None)
    parser.add_argument("--root", default=None, help="mailbox directory for --transport files")
    parser.add_argument("--url", default=None, help="http base for --transport http")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=None)
    parser.add_argument("--fps", type=float, default=32.0, help="simulation rate (Director Tempo)")
    parser.add_argument("--config", default=DEFAULT_CONFIG)
    parser.add_argument("--script", default=None, help="run a command file and exit")
    parser.add_argument("--once", action="store_true", help="tick a few frames and exit")
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--no-expose", action="store_true", help="start with no subscriptions")
    args = parser.parse_args(argv[1:])

    config = load_config(args.config)
    apply_overrides(
        config,
        transport=args.transport or config.transport,
        root=args.root or config.root,
        httpUrl=args.url or config.httpUrl,
        httpHost=args.host,
        tcpPort=args.port or config.tcpPort,
        expose=[] if args.no_expose else config.expose,
    )
    peer = DirectorPeer(config=config, verbose=args.verbose)
    transport = build_transport(peer, config, config.transport)
    transport.start()
    print("mock director: %s" % config.summary())
    print("             %s" % transport.status())
    stop_at = time.time() + 1.0 if args.once else None
    try:
        if args.script:
            run_script(peer, transport, args.script, args.fps)
        else:
            while stop_at is None or time.time() < stop_at:
                step(peer, transport, args.fps)
                if args.verbose and peer.frame % 32 == 0:
                    print("frame %d  kmh=%s cash=%s  %s" % (
                        peer.frame,
                        render(peer.game["CurrentVehicle"]["general"]["kmh"]),
                        peer.game["Cash"],
                        transport.status(),
                    ))
    except KeyboardInterrupt:
        pass
    finally:
        peer.stop()
        peer.flush()
        transport.stop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
