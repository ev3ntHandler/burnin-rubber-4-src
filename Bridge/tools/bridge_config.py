"""Parser for ``Bridge/Director/Bridge.Data.txt`` — the one config file all three peers read.

Format is deliberately the same idiom Burnin' Rubber 4 already uses for every data file
(``Director Movie File (.dcr)/Globals.txt``): TAB-separated ``key<TAB>value``, ``//`` or ``--``
comment lines, blank lines ignored. Repeating a key accumulates a list; every other key sets a
scalar. That means the Lingo implementation parses it with the game's own ``SetItemDelimiter`` +
``item[i]`` pattern, GDScript with ``String.split("\\t")`` and Python with ``str.split("\\t")``.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Tuple

LIST_KEYS = ("expose", "write", "call", "event", "ignore", "hook")
INT_KEYS = ("rate", "httpPort", "tcpPort", "udpPort", "verify", "allowEval", "allowExec", "peerTimeoutMs", "requestTimeoutMs", "maxLines")
BOOL_TRUE = ("1", "true", "yes", "on", "#t", "t")


@dataclass
class BridgeConfig:
    transport: str = "files"
    root: str = "BridgeData"
    httpHost: str = "127.0.0.1"
    httpPort: int = 7778
    httpUrl: str = ""
    httpWaitMs: int = 1500
    tcpHost: str = "127.0.0.1"
    tcpPort: int = 7777
    udpPort: int = 7779
    binary: bool = False
    snapshot: str = "delta"
    rate: int = 1
    verify: bool = True
    allowEval: bool = False
    allowExec: bool = False
    peerTimeoutMs: int = 2000
    requestTimeoutMs: int = 2000
    maxLines: int = 200
    expose: List[str] = field(default_factory=list)
    write: List[str] = field(default_factory=list)
    call: List[str] = field(default_factory=list)
    event: List[str] = field(default_factory=list)
    ignore: List[str] = field(default_factory=list)
    alias: Dict[str, str] = field(default_factory=dict)
    hook: List[Tuple[str, str]] = field(default_factory=list)
    source: str = ""

    # -- accessors ---------------------------------------------------------------------------
    def read_patterns(self) -> Tuple[str, ...]:
        return ("gGame", "gSystem", "gData", "gSound", "gBridge", "bridge") + tuple(
            pattern.split("[")[0] for pattern in self.expose
        )

    def allow_list(self) -> Tuple[str, ...]:
        return tuple(self.write) if self.write else ()

    def url(self) -> str:
        if self.httpUrl:
            return self.httpUrl
        return "http://%s:%d/bridge" % (self.httpHost, self.httpPort)

    def resolved_root(self, base: str) -> str:
        return self.root if os.path.isabs(self.root) else os.path.join(base, self.root)

    def summary(self) -> str:
        parts = [
            "transport=%s" % self.transport,
            "root=%s" % self.root,
            "snapshot=%s rate=%d" % (self.snapshot, self.rate),
            "verify=%d" % int(self.verify),
            "allowEval=%d" % int(self.allowEval),
            "expose=%d" % len(self.expose),
            "write=%s" % (len(self.write) or "none"),
            "alias=%d" % len(self.alias),
        ]
        if self.source:
            parts.append("config=%s" % os.path.basename(self.source))
        return "  ".join(parts)

    def to_dict(self) -> Dict[str, Any]:
        return {key: value for key, value in self.__dict__.items() if key != "alias"}


def parse(text: str, source: str = "") -> BridgeConfig:
    config = BridgeConfig(source=source)
    for raw in text.replace("\r\n", "\n").split("\n"):
        line = raw.rstrip()
        stripped = line.strip()
        if not stripped or stripped[:2] in ("//", "--") or stripped[0] == "#":
            continue
        if raw[:1] in (" ", "\t"):
            continue  # indented lines belong to the game's own block parsers, not to us
        key, sep, value = line.partition("\t")
        key = key.strip()
        value = value.strip()
        if not sep:
            key, _, value = line.partition(" ")
            value = value.strip()
        if not key:
            continue
        if key == "alias":
            parts = [part.strip() for part in line.split("\t")[1:3]]
            if len(parts) == 2 and parts[0]:
                config.alias[parts[0]] = parts[1]
            continue
        if key in LIST_KEYS:
            if key == "hook":
                handler, _, event = value.partition("=")
                config.hook.append((handler.strip(), event.strip()))
            elif value:
                getattr(config, key).append(value)
            continue
        if key == "alias":
            continue
        if isinstance(getattr(config, key, None), bool):
            setattr(config, key, value.lower() in BOOL_TRUE)
            continue
        if key in INT_KEYS or key == "httpWaitMs":
            setattr(config, key, _int(value, getattr(config, key, 0)))
            continue
        if hasattr(config, key):
            setattr(config, key, value)
    return config


def _int(value: str, default: Any) -> int:
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return int(default) if isinstance(default, (int, float)) else 0


def load(path: Optional[str]) -> BridgeConfig:
    if path and os.path.isdir(path):
        path = os.path.join(path, "Bridge.Data.txt")
    if not path or not os.path.exists(path):
        return BridgeConfig(source=path or "")
    with open(path, encoding="utf-8", errors="replace") as handle:
        return parse(handle.read(), source=path)


def apply_overrides(config: BridgeConfig, **overrides: Any) -> BridgeConfig:
    for key, value in overrides.items():
        if value is None:
            continue
        if key in LIST_KEYS and isinstance(value, str):
            value = [item for item in value.split(",") if item.strip()]
        setattr(config, key, value)
    return config


EXAMPLE = """//---- SHOCKWAVE <-> GODOT BRIDGE ---------------------------------------------------------
// Read by the Director script, the Godot addon and tools/mock_director.py. TAB separated.

transport       files
root            BridgeData
snapshot        delta
rate            1
verify          1
httpHost        127.0.0.1
httpPort        7778
tcpPort         7777
allowEval       FALSE
peerTimeoutMs   2000
"""


def write_example(path: str) -> None:
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(EXAMPLE)


if __name__ == "__main__":  # tiny smoke test: python3 bridge_config.py <file>
    import json
    import sys

    if len(sys.argv) > 1:
        loaded = load(sys.argv[1])
        print(loaded.summary())
        print(json.dumps(loaded.__dict__, indent=1, default=str))
    else:
        print(parse(EXAMPLE).summary())
