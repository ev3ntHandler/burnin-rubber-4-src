#!/usr/bin/env python3
"""Mock Godot peer: the stand-in for a running Godot project + ``addons/shockwave_bridge``.

Useful for two things: driving the Director side (or ``mock_director.py``) from a terminal while
you build the Godot scene, and as the second half of ``test_bridge.py``.

    python3 mock_godot.py --transport http                      # hosts /bridge/poll + /push
    python3 mock_godot.py --transport tcp                       # hosts the 127.0.0.1:7777 listener
    python3 mock_godot.py --transport files --root ../BridgeData
    python3 mock_godot.py --transport http --watch --drive      # live mirror + autopilot demo
    python3 mock_godot.py --once --get gGame.Cash --set gGame.Cash=999999

``gd:`` paths map onto the ``nodes`` dictionary, mirroring ``ShockwaveBridge.bind(node, name)``:
reading ``gd:Game.player.score`` from Director returns the same thing the GDScript addon would.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from typing import Any, Dict, List, Optional, Tuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from bridge_config import BridgeConfig, apply_overrides, load as load_config
from bridge_peer import Config, Peer
from bridge_proto import (
    ProtocolError,
    VOID,
    bridge_key,
    encode,
    is_bridge_path,
    lingo_parse,
    path_child,
    render,
)
from bridge_transports import FilesTransport, HttpServerTransport, TcpServerTransport

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_CONFIG = os.path.normpath(os.path.join(HERE, "..", "Director", "Bridge.Data.txt"))


class GodotPeer(Peer):
    """State store + ``gd:`` object binding, the same surface ``bridge_core.gd`` exposes."""

    def __init__(self, config: Any = None, verbose: bool = False, allow_write: bool = False):
        self.bridge_config = config or BridgeConfig()
        caps = ["snap", "sub", "event", "list"]
        if allow_write:
            caps.append("write")
        peer_config = Config(
            role="godot",
            name="Godot (mock)",
            caps=tuple(caps),
            allow_read=("bridge", "gd"),
            allow_write=("bridge", "gd") if allow_write else (),
            snapshot_rate=self.bridge_config.rate,
            snapshot_mode="delta",
            peer_timeout_ms=self.bridge_config.peerTimeoutMs,
        )
        super().__init__(peer_config, verbose=verbose)
        self.nodes: Dict[str, Any] = {
            "Game": {
                "player": {"score": 0, "lives": 3, "pos": [0.0, 0.0], "label": "player"},
                "hud": {"visible": True, "speedLabel": "", "cashLabel": ""},
                "autopilot": False,
            }
        }
        self.log_lines: List[str] = []
        self.events: List[Tuple[str, Dict[str, Any]]] = []
        self.on_change = self._record_change
        self.changes: List[Tuple[str, Any]] = []

    # -- mirrors bridge_core.gd --------------------------------------------------------------
    def _record_change(self, path: str, value: Any) -> None:
        self.changes.append((path, value))
        self._apply_binding(path, value)

    def _apply_binding(self, path: str, value: Any) -> None:
        """Push mirrored Director state into bound Godot nodes (auto-bind by tail name)."""
        if not path.startswith("gGame."):
            return
        hud = self.nodes["Game"]["hud"]
        if path.endswith(".kmh"):
            hud["speedLabel"] = "%6.1f km/h" % (value if isinstance(value, (int, float)) else 0)
        elif path == "gGame.Cash":
            hud["cashLabel"] = "$%s" % value
        elif path == "gGame.RaceState":
            hud["raceState"] = render(value)

    def resolve_path(self, path: str) -> Any:
        if is_bridge_path(path):
            return self.store.get(bridge_key(path), VOID)
        if path.startswith("gd:"):
            return _walk(self.nodes, path[3:].split("."))
        if path.startswith("state."):
            return self.peer_store.get(path[6:], self.store.get(path, VOID))
        return VOID

    def write_path(self, path: str, value: Any) -> bool:
        if is_bridge_path(path):
            self.store[bridge_key(path)] = value
            return True
        if path.startswith("gd:"):
            return _assign(self.nodes, path[3:].split("."), value)
        return False

    def enumerate(self, prefix: str, depth: int) -> List[Tuple[str, Any]]:
        out: List[Tuple[str, Any]] = []
        if prefix.startswith("gd:"):
            _collect(prefix, _walk(self.nodes, prefix[3:].split(".")), depth, out)
            return out
        for key, value in sorted(self.peer_store.items()):
            if not prefix or key.startswith(prefix):
                out.append((key, value))
        for key, value in sorted(self.store.items()):
            out.append(("bridge." + key, value))
        return out

    def execute_call(self, handler: str, target: str, data: Any) -> Any:
        if handler == "push_log":
            self.log_lines.append(str(data))
            return 1
        raise ProtocolError("notfound", handler)

    def raise_event(self, name: str, data: Any) -> None:
        self.events.append((name, data))
        if name == "bridge_set":
            if isinstance(data, dict):
                for key, value in data.items():
                    self.set(key, value)


def _walk(node: Any, segments: List[str]) -> Any:
    current = node
    for segment in segments:
        if not segment:
            continue
        if isinstance(current, dict) and segment in current:
            current = current[segment]
        elif isinstance(current, list) and segment.lstrip("-").isdigit():
            index = int(segment)
            if not 0 <= index < len(current):
                return VOID
            current = current[index]
        else:
            return VOID
    return current


def _assign(node: Any, segments: List[str], value: Any) -> bool:
    if not segments:
        return False
    target = _walk(node, segments[:-1])
    if isinstance(target, dict):
        target[segments[-1]] = value
        return True
    return False


def _collect(prefix: str, node: Any, depth: int, out: List[Tuple[str, Any]]) -> None:
    if isinstance(node, dict):
        for key, value in node.items():
            child = path_child(prefix, key)
            if isinstance(value, (dict, list)) and depth != 0:
                _collect(child, value, max(0, depth - 1) if depth > 0 else 0, out)
            else:
                out.append((child, value))
    elif isinstance(node, list):
        for index, value in enumerate(node):
            out.append((path_child(prefix, index), value))


def build_transport(peer: GodotPeer, config: Any, transport: str, host: str, port: Optional[int]):
    if transport == "files":
        return FilesTransport(peer, config.resolved_root(os.getcwd()), crc=config.verify)
    if transport == "http":
        return HttpServerTransport(peer, host, port or config.httpPort)
    if transport == "tcp":
        return TcpServerTransport(peer, host, port or config.tcpPort, binary=config.binary)
    raise SystemExit("unknown transport %r" % transport)


def autopilot(peer: GodotPeer) -> None:
    """A one-paragraph demo of the round trip: read the mirrored kmh, write the car's Input."""
    target_kmh = 140.0
    speed = peer.get("gGame.CurrentVehicle.general.kmh", 0.0)
    speed = speed if isinstance(speed, (int, float)) else 0.0
    keys = {"forward": 1 if speed < target_kmh - 4 else 0, "brake": 1 if speed > target_kmh + 8 else 0}
    peer.set("gGame.CurrentVehicle.Input.forward", keys["forward"])
    peer.set("gGame.CurrentVehicle.Input.brake", keys["brake"])
    peer.set("bridge.autopilot.target", target_kmh)
    score = int(peer.get("gGame.Cash", 0) or 0)
    peer.nodes["Game"]["player"]["score"] = score


def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser(description="Mock Godot peer (host side of the bridge)")
    parser.add_argument("--transport", choices=("files", "http", "tcp"), default=None)
    parser.add_argument("--root", default=None)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=None)
    parser.add_argument("--config", default=DEFAULT_CONFIG)
    parser.add_argument("--fps", type=float, default=60.0)
    parser.add_argument("--watch", action="store_true", help="print every mirrored value change")
    parser.add_argument("--drive", action="store_true", help="run the autopilot demo (writes into the game)")
    parser.add_argument("--allow-write", action="store_true", help="let Director write our gd: store")
    parser.add_argument("--get", action="append", default=[], help="print a mirrored path once")
    parser.add_argument("--set", action="append", default=[], help="write path=value once")
    parser.add_argument("--subscribe", default=None, help="comma separated paths")
    parser.add_argument("--once", action="store_true")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args(argv[1:])

    config = load_config(args.config)
    apply_overrides(config, transport=args.transport or config.transport, root=args.root or config.root)
    peer = GodotPeer(config=config, verbose=args.verbose, allow_write=args.allow_write)
    transport = build_transport(peer, config, config.transport, args.host, args.port)
    transport.start()
    for path in (args.subscribe or "").split(","):
        if path.strip():
            peer.subscribe(path.strip())
    if not (args.subscribe or "").strip():
        for path in config.expose[:12]:
            peer.subscribe(path)
    print("mock godot:   %s" % config.summary())
    print("            %s" % transport.status())

    for entry in args.set:
        path, _, value = entry.partition("=")
        peer.set(path.strip(), lingo_parse(value.strip()) if value.strip()[:1] in "[#" else value.strip())
    for path in args.get:
        print("get %s = %s" % (path, render(peer.get(path))))

    stop_at = time.time() + 1.0 if args.once else None
    period = 1.0 / max(1.0, args.fps)
    try:
        while stop_at is None or time.time() < stop_at:
            received = transport.poll()
            if received is not None:
                peer.feed_batch(received)
            if args.drive:
                autopilot(peer)
            peer.tick()
            peer.flush()
            if args.watch and peer.changes:
                for path, value in peer.changes[-8:]:
                    print("  %-46s %s" % (path, render(value)))
                peer.changes.clear()
            time.sleep(period)
    except KeyboardInterrupt:
        pass
    finally:
        peer.stop()
        peer.flush()
        transport.stop()
        print("stats: %s" % json.dumps(peer.stats, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
