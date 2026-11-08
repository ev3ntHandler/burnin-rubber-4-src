"""Shockwave <-> Godot bridge: wire protocol codec (protocol v1).

Normative spec: ``Bridge/PROTOCOL.md``.  This file is the reference implementation that the
Director (Lingo) and Godot (GDScript) ports are validated against -- when this and PROTOCOL.md
disagree, fix this file and both ports together.

Stdlib only, so it sits next to a Director project on a machine with nothing installed.

    python3 bridge_proto.py selftest [-v]   round-trip checks against Director/Bridge.Vectors.txt
    python3 bridge_proto.py vectors [file]  (re)generate that TAB table, mirrored into the Godot
                                            addon; an optional second path also writes the JSON form
    python3 bridge_proto.py encode <value>  one value to its `tag:payload` wire text (a bare word
                                            is a string, `42` is an int, `s:42` is deliberately one)
    python3 bridge_proto.py decode <wire>   and back, unparseable text coming out as itself
    python3 bridge_proto.py bench           framing throughput on a realistic snapshot
"""

from __future__ import annotations

import json
import os
import struct
import sys
import time
import zlib
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

PROTOCOL_VERSION = 1
TAGS = ("i", "f", "s", "b", "y", "p", "v", "q", "c", "r", "d", "l", "n")
TAB = "\t"
LF = "\n"
KV_SEP = ";"


class ProtocolError(Exception):
    """Carried on the wire as ``RSP <id> <op> err <code> <message>``."""

    def __init__(self, code: str, message: str = ""):
        super().__init__("%s: %s" % (code, message))
        self.code = code
        self.message = message


# --------------------------------------------------------------------------------------------
# §1 framing
# --------------------------------------------------------------------------------------------


def sanitize(text: str) -> str:
    """Flatten anything that would break line/field framing. There is no escaping (spec §1)."""
    if "\t" in text or "\n" in text or "\r" in text:
        return text.replace("\t", " ").replace("\r", " ").replace("\n", " ")
    return text


def build(verb: str, fields: Iterable[Any] = ()) -> str:
    return TAB.join([verb] + [sanitize(str(field)) for field in fields])


def parse(line: str) -> Tuple[str, List[str]]:
    """``line`` -> ``(verb, fields)``. Trailing empty fields are kept (spec §9)."""
    line = line.rstrip("\r")
    if not line:
        return "", []
    parts = line.split(TAB)
    return parts[0], parts[1:]


# --------------------------------------------------------------------------------------------
# §2 typed values
# --------------------------------------------------------------------------------------------


class _Void:
    """Lingo ``VOID`` / wire tag ``n``. Falsy, singleton, nice repr."""

    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def __repr__(self) -> str:
        return "VOID"

    def __bool__(self) -> bool:
        return False


VOID = _Void()


class Symbol(str):
    """Lingo ``#symbol`` (tag ``y``). A ``str`` subclass so callers can compare by name."""

    __slots__ = ()

    @property
    def name(self) -> str:
        return self[1:] if self[:1] == "#" else self

    def __repr__(self) -> str:
        return "Symbol(%s)" % str.__repr__(str(self))


class Point(Tuple[float, float]):  # type: ignore[misc,valid-type]
    def __new__(cls, x: float, y: float) -> "Point":
        return tuple.__new__(cls, (float(x), float(y)))

    @property
    def x(self) -> float:
        return self[0]

    @property
    def y(self) -> float:
        return self[1]


class Vector(Tuple[float, float, float]):  # type: ignore[misc,valid-type]
    def __new__(cls, x: float, y: float, z: float) -> "Vector":
        return tuple.__new__(cls, (float(x), float(y), float(z)))

    @property
    def x(self) -> float:
        return self[0]

    @property
    def y(self) -> float:
        return self[1]

    @property
    def z(self) -> float:
        return self[2]


class Quaternion(Tuple[float, float, float, float]):  # type: ignore[misc,valid-type]
    def __new__(cls, x, y, z, w) -> "Quaternion":
        return tuple.__new__(cls, (float(x), float(y), float(z), float(w)))


class Color(Tuple[int, int, int, int]):  # type: ignore[misc,valid-type]
    def __new__(cls, r, g, b, a=255) -> "Color":
        return tuple.__new__(cls, (int(r), int(g), int(b), int(a)))

    @property
    def r(self) -> int:
        return self[0]

    @property
    def g(self) -> int:
        return self[1]

    @property
    def b(self) -> int:
        return self[2]

    @property
    def a(self) -> int:
        return self[3]


class Rect(Tuple[float, float, float, float]):  # type: ignore[misc,valid-type]
    def __new__(cls, left, top, right, bottom) -> "Rect":
        return tuple.__new__(cls, tuple(float(v) for v in (left, top, right, bottom)))


def _num(value: float) -> str:
    text = repr(float(value))
    if "e" in text and "." not in text:  # keep Director's value() on the float path
        text = text.replace("e", ".0e")
    return text


def encode(value: Any) -> str:
    """Python value -> ``tag:payload`` (spec §2)."""
    if value is VOID or value is None:
        return "n"
    if isinstance(value, bool):
        return "b:1" if value else "b:0"
    if isinstance(value, int):
        return "i:%d" % value
    if isinstance(value, float):
        text = _num(value)
        return "f:" + (text if ("." in text or "e" in text) else text + ".0")
    if isinstance(value, Symbol):
        return "y:" + sanitize(str(value.name))
    if isinstance(value, Color):
        if value.a == 255:
            return "c:%d,%d,%d" % (value.r, value.g, value.b)
        return "c:%d,%d,%d,%d" % (value.r, value.g, value.b, value.a)
    if isinstance(value, Point):
        return "p:%s,%s" % (_num(value.x), _num(value.y))
    if isinstance(value, Vector):
        return "v:%s,%s,%s" % (_num(value.x), _num(value.y), _num(value.z))
    if isinstance(value, Quaternion):
        return "q:%s,%s,%s,%s" % tuple(_num(part) for part in value)
    if isinstance(value, Rect):
        return "r:%s,%s,%s,%s" % tuple(_num(part) for part in value)
    if isinstance(value, (list, tuple, dict)):
        return "l:" + lingo_prints(value)
    if isinstance(value, (bytes, bytearray)):
        return "s:" + sanitize(value.decode("utf-8", "replace"))
    return "s:" + sanitize(str(value))


def decode(text: str) -> Any:
    """``tag:payload`` -> Python value. Raises :class:`ProtocolError` on an unknown tag."""
    if text == "n":
        return VOID
    if len(text) < 2 or text[1] != ":" or text[0] not in TAGS:
        raise ProtocolError("badtype", text)
    tag, payload = text[0], text[2:]
    if tag == "i":
        return int(payload)
    if tag == "f":
        return float(payload)
    if tag == "s":
        return payload
    if tag == "b":
        return payload == "1"
    if tag == "y":
        return Symbol("#" + payload)
    if tag == "p":
        x, y = payload.split(",")
        return Point(float(x), float(y))
    if tag == "v":
        x, y, z = payload.split(",")
        return Vector(float(x), float(y), float(z))
    if tag == "q":
        return Quaternion(*[float(p) for p in payload.split(",")])
    if tag == "c":
        return Color(*[int(p) for p in payload.split(",")])
    if tag == "r":
        return Rect(*[float(p) for p in payload.split(",")])
    if tag == "d":
        return float(payload)
    if tag == "l":
        return lingo_parse(payload)
    raise ProtocolError("badtype", tag)


def decode_or_text(text: str) -> Any:
    """Like :func:`decode`, but never fails -- a debug channel must not die on bad data."""
    try:
        return decode(text)
    except (ProtocolError, ValueError):
        return text


# --------------------------------------------------------------------------------------------
# §3 Lingo list literals
# --------------------------------------------------------------------------------------------


def lingo_prints(value: Any) -> str:
    """Python value -> Lingo literal text, i.e. parseable by Director's ``value()``."""
    if value is VOID or value is None:
        return "VOID"
    if isinstance(value, bool):
        return "TRUE" if value else "FALSE"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        text = _num(value)
        return text if ("." in text or "e" in text) else text + ".0"
    if isinstance(value, Symbol):
        return "#" + str(value.name)
    if isinstance(value, Color):
        return "color(%d, %d, %d)" % (value.r, value.g, value.b)
    if isinstance(value, (Point, Vector, Quaternion, Rect)):
        return ", ".join(_num(part) for part in value)
    if isinstance(value, dict):
        inner = ", ".join(
            "%s: %s" % ("#" + str(k)[1:] if isinstance(k, str) and k[:1] == "#" else _key(k), lingo_prints(v))
            for k, v in value.items()
        )
        return "[" + inner + "]"
    if isinstance(value, (list, tuple)):
        return "[" + ", ".join(lingo_prints(item) for item in value) + "]"
    return _quote(sanitize(str(value)))


def _key(key: Any) -> str:
    text = str(key)
    if isinstance(key, Symbol) or text[:1] == "#":
        return "#" + text[1:]
    if text and (text[0].isalpha() or text[0] == "_") and all(c.isalnum() or c == "_" for c in text):
        return "#" + text
    return _quote(text)


def _quote(text: str) -> str:
    """One Lingo string literal, quoting whatever ``text`` contains.

    Director has no backslash escapes: ``"a\\b"`` is three characters, and ``"\"`` is a
    backslash that ENDS the string. A quote inside a string is therefore DOUBLED, which is the
    only form ``value()`` can read -- so it is the only form we write, and both readers un-double
    it. Documented in PROTOCOL.md 3.
    """
    return '"' + text.replace('"', '""') + '"'


def lingo_parse(text: str) -> Any:
    """Lingo literal -> Python. Restricted to the documented §3 subset; falls back to raw text."""
    text = text.strip()
    if not text:
        return VOID
    try:
        scanner = _Scanner(text)
        value = _parse_item(scanner)
        scanner.skip_ws()
        return value
    except ProtocolError:
        return text


class _Scanner:
    __slots__ = ("text", "pos")

    def __init__(self, text: str):
        self.text = text
        self.pos = 0

    def skip_ws(self) -> None:
        while self.pos < len(self.text) and self.text[self.pos] in " \t\r\n":
            self.pos += 1

    def error(self, why: str) -> ProtocolError:
        return ProtocolError("badliteral", "%s at %d: %r" % (why, self.pos, self.text))


def _parse_item(scanner: _Scanner) -> Any:
    scanner.skip_ws()
    if scanner.pos >= len(scanner.text):
        raise scanner.error("expected value")
    if scanner.text[scanner.pos] == "[":
        return _parse_list(scanner)
    start = scanner.pos
    while scanner.pos < len(scanner.text) and scanner.text[scanner.pos] not in ",]":
        if scanner.text[scanner.pos] == '"':
            scanner.pos += 1
            while scanner.pos < len(scanner.text):
                char = scanner.text[scanner.pos]
                if char == '"':
                    if scanner.pos + 1 < len(scanner.text) and scanner.text[scanner.pos + 1] == '"':
                        scanner.pos += 2  # `""` is one quote character, not the end
                        continue
                    break
                if char == "\\":
                    scanner.pos += 1
                scanner.pos += 1
        scanner.pos += 1
    token = scanner.text[start : scanner.pos].strip()
    if not token:
        raise scanner.error("empty item")
    return scalar(token)


def scalar(token: str) -> Any:
    """Parse one Lingo scalar token (also used by the Godot-side tests)."""
    token = token.strip()
    upper = token.upper()
    if upper == "VOID":
        return VOID
    if upper == "TRUE":
        return True
    if upper == "FALSE":
        return False
    if token[:1] == "#":
        return Symbol(token)
    if len(token) >= 2 and token[0] == '"' and token[-1] == '"':
        return _unquote(token[1:-1])
    if token[:1] == "(" and token[-1:] == ")":
        parts = token[1:-1].split(",")
        numbers = [float(p) for p in parts]
        if len(numbers) == 2:
            return Point(*numbers)
        if len(numbers) == 3:
            return Vector(*numbers)
    try:
        return int(token)
    except ValueError:
        pass
    try:
        return float(token)
    except ValueError:
        raise ProtocolError("badscalar", token)


def _unquote(text: str) -> str:
    """The inside of a Lingo string literal, as Director reads it: `""` is one quote, `\` is a
    backslash. A `\"` is unescaped too, because a hand-written or JSON-ish literal people paste
    into the Message window should still work -- but it is never *written*, see :func:`_quote`."""
    out: List[str] = []
    index = 0
    mapping = {'"': '"', "\\": "\\"}
    while index < len(text):
        char = text[index]
        if char == '"' and index + 1 < len(text) and text[index + 1] == '"':
            out.append('"')
            index += 2
            continue
        if char == "\\" and index + 1 < len(text) and text[index + 1] in mapping:
            out.append(mapping[text[index + 1]])
            index += 2
            continue
        out.append(char)
        index += 1
    return "".join(out)


def _parse_list(scanner: _Scanner) -> Any:
    scanner.pos += 1  # consume '['
    scanner.skip_ws()
    if scanner.pos < len(scanner.text) and scanner.text[scanner.pos] == "]":
        scanner.pos += 1
        return []
    items: List[Any] = []
    props: List[Tuple[Any, Any]] = []
    while True:
        start = scanner.pos
        depth = 0
        while scanner.pos < len(scanner.text):
            char = scanner.text[scanner.pos]
            if char == "[":
                depth += 1
            elif char == "]":
                if depth == 0:
                    break
                depth -= 1
            elif char == "," and depth == 0:
                break
            elif char == '"':
                scanner.pos += 1
                while scanner.pos < len(scanner.text) and scanner.text[scanner.pos] != '"':
                    if scanner.text[scanner.pos] == "\\":
                        scanner.pos += 1
                    scanner.pos += 1
            scanner.pos += 1
        chunk = scanner.text[start : scanner.pos].strip()
        key, sep, value_text = _split_key(chunk)
        if sep:
            # prop keys come back as plain names (Godot uses String keys, Director symbol(key))
            props.append((str(key).lstrip("#"), lingo_parse(value_text) if value_text.strip()[:1] == "[" else scalar(value_text)))
        else:
            items.append(lingo_parse(chunk) if chunk[:1] == "[" else scalar(chunk))
        if scanner.pos >= len(scanner.text):
            raise scanner.error("unterminated list")
        if scanner.text[scanner.pos] == "]":
            scanner.pos += 1
            break
        scanner.pos += 1  # consume ','
    if props:
        return dict(props)
    return items


def _split_key(chunk: str) -> Tuple[Any, str, str]:
    """``#mass: 1200`` -> ``(Symbol, ':', ' 1200')``; ``"x"`` -> ``(..., '', text)``."""
    if not chunk or chunk[0] == "[" or chunk[:1] == '"' and chunk[-1:] == '"':
        return VOID, "", chunk
    depth = 0
    index = 0
    while index < len(chunk):
        char = chunk[index]
        if char == "[":
            depth += 1
        elif char == "]":
            depth -= 1
        elif char == '"' and depth == 0:
            index += 1
            while index < len(chunk) and chunk[index] != '"':
                if chunk[index] == "\\":
                    index += 1
                index += 1
        elif char == ":" and depth == 0:
            return scalar(chunk[:index]), ":", chunk[index + 1 :]
        index += 1
    return VOID, "", chunk


# --------------------------------------------------------------------------------------------
# key=value lists (SNAP / DELTA / EVT / RSP payload)
# --------------------------------------------------------------------------------------------


def encode_kv(pairs: Sequence[Tuple[str, Any]]) -> str:
    out = []
    for key, value in pairs:
        encoded = value if isinstance(value, str) and value[:1] in TAGS and value[1:2] == ":" else encode(value)
        out.append("%s=%s" % (sanitize(key), encoded))
    return KV_SEP.join(out)


def decode_kv(text: str) -> List[Tuple[str, Any]]:
    out: List[Tuple[str, Any]] = []
    if not text:
        return out
    for chunk in text.split(KV_SEP):
        key, sep, value = chunk.partition("=")
        if sep and key:
            out.append((key, decode_or_text(value)))
    return out


def kv_to_dict(text: str) -> Dict[str, Any]:
    return dict(decode_kv(text))


# --------------------------------------------------------------------------------------------
# batches, and the §7.1 file-transport commit marker
# --------------------------------------------------------------------------------------------


class Batch:
    """A transport frame: zero or more messages, LF separated."""

    __slots__ = ("lines",)

    def __init__(self, lines: Optional[List[str]] = None):
        self.lines: List[str] = list(lines or [])

    def add(self, verb: str, fields: Iterable[Any] = ()) -> None:
        self.lines.append(build(verb, fields))

    def add_line(self, line: str) -> None:
        self.lines.append(line)

    def extend(self, lines: Iterable[str]) -> None:
        self.lines.extend(lines)

    def __len__(self) -> int:
        return len(self.lines)

    def __bool__(self) -> bool:
        return bool(self.lines)

    def __iter__(self):
        return iter(self.lines)

    def to_bytes(self) -> bytes:
        if not self.lines:
            return b""
        return (LF.join(self.lines) + LF).encode("utf-8")

    @staticmethod
    def from_text(text: str) -> "Batch":
        return Batch([line for line in text.split(LF) if line.strip()])

    @staticmethod
    def from_bytes(data: bytes) -> "Batch":
        return Batch.from_text(data.decode("utf-8", "replace"))

    def chunk(self, max_bytes: int = 24000) -> List["Batch"]:
        """Split so no single transport write exceeds a datagram / HTTP body."""
        out: List[Batch] = []
        current = Batch()
        size = 0
        for line in self.lines:
            weight = len(line) + 1
            if current and size + weight > max_bytes:
                out.append(current)
                current, size = Batch(), 0
            current.add_line(line)
            size += weight
        if current:
            out.append(current)
        return out


def frame_stats(payload: bytes) -> Tuple[int, int]:
    """``(byte length, complete-line count)`` -- what the ``.seq`` marker witnesses."""
    return len(payload), payload.count(b"\n")


def write_frame(path: str, payload: bytes, seq: int, crc: bool = True) -> None:
    """Write the payload atomically, then publish the commit marker (spec §7.1)."""
    directory = os.path.dirname(path) or "."
    os.makedirs(directory, exist_ok=True)
    temporary = path + ".tmp"
    with open(temporary, "wb") as handle:
        handle.write(payload)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary, path)
    size, lines = frame_stats(payload)
    marker = _marker_path(path)  # "seq bytes lines [crc]"; bytes is a minimum, see read_frame
    text = "%d %d %d" % (seq, size, lines)
    if crc:
        text += " %08x" % (zlib.crc32(payload) & 0xFFFFFFFF)
    with open(marker, "w", encoding="ascii", newline="\n") as handle:
        handle.write(text + "\n")
        handle.flush()
        os.fsync(handle.fileno())


def _marker_path(path: str) -> str:
    if path.endswith(".txt"):
        return path[: -len(".txt")] + ".seq"
    return path + ".seq"


def read_frame(path: str, last_seq: int = -1) -> Optional[Tuple[int, Batch]]:
    """``(seq, batch)`` for the newest intact frame the reader has not applied yet, else ``None``.

    Torn or missing ⇒ ``None``: the caller just retries on the next poll. That is the whole
    error handling story of the file transport -- no locks, no partial-state corruption.
    """
    marker = _marker_path(path)
    try:
        with open(marker, "r", encoding="utf-8", errors="replace") as handle:
            head = handle.read(160).split()
        if len(head) < 3:
            return None
        seq, size, lines = int(head[0]), int(head[1]), int(head[2])
        checksum = int(head[3], 16) if len(head) >= 4 else None
    except (OSError, ValueError):
        return None
    # Only an *exact* repeat means "already applied". A seq that has gone backwards is the writer
    # starting its counter over (a restart, which always greets again -- see PROTOCOL.md 7.1), and
    # refusing those would freeze the link until the new counter caught up: after a long session,
    # thousands of frames. Reading one old frame after *our* restart is the harmless trade.
    if seq == last_seq:
        return None
    try:
        with open(path, "rb") as handle:
            payload = handle.read()
    except OSError:
        return None
    # `lines` is the exact witness that a write finished. `size` is only a lower bound: a Lingo
    # writer counts characters, not UTF-8 bytes, so a payload with any non-ASCII text is longer on
    # disk than its marker promises. Being *shorter* than promised is the tearing we must catch.
    if len(payload) < size:
        return None
    if payload.count(b"\n") != lines:
        return None
    if checksum is not None and (zlib.crc32(payload) & 0xFFFFFFFF) != checksum:
        return None
    return seq, Batch.from_bytes(payload)


def read_frame_unchecked(path: str) -> Batch:
    """Read whatever whole lines exist, ignoring the marker (``bridge.verify = 0`` peers)."""
    try:
        with open(path, "rb") as handle:
            payload = handle.read()
    except OSError:
        return Batch()
    lines = payload.decode("utf-8", "replace").split(LF)
    return Batch([line for line in lines[:-1] if line.strip()])  # drop a possibly torn tail


# --------------------------------------------------------------------------------------------
# §7.3 TCP framing
# --------------------------------------------------------------------------------------------


def pack(payload: bytes) -> bytes:
    return struct.pack("<I", len(payload)) + payload


def unpack(buffer: bytes) -> Tuple[List[bytes], bytes]:
    frames: List[bytes] = []
    index = 0
    while len(buffer) - index >= 4:
        (size,) = struct.unpack_from("<I", buffer, index)
        if size > 4 * 1024 * 1024:
            raise ProtocolError("badframe", "declared size %d" % size)
        start = index + 4
        if len(buffer) - start < size:
            break
        frames.append(buffer[start : start + size])
        index = start + size
    return frames, buffer[index:]


# --------------------------------------------------------------------------------------------
# §5 paths, §6 allow-lists
# --------------------------------------------------------------------------------------------


def path_namespace(path: str) -> str:
    head = path.split(".")[0].split("[")[0].strip()
    return head


def path_parent(path: str) -> str:
    if path.endswith("]") and "[" in path:
        return path[: path.rindex("[")]
    return path.rsplit(".", 1)[0] if "." in path else ""


def path_tail(path: str) -> str:
    if path.endswith("]") and "[" in path:
        return path[path.rindex("[") + 1 : -1].strip()
    return path.rsplit(".", 1)[1] if "." in path else path


def path_child(path: str, key: Any) -> str:
    if not path:
        return str(key)
    if isinstance(key, int):
        return "%s[%d]" % (path, key)
    return "%s.%s" % (path, key)


def allowed(path: str, patterns: Sequence[str]) -> bool:
    """A pattern authorises itself and its whole subtree."""
    for pattern in patterns:
        pattern = pattern.strip()
        if not pattern:
            continue
        if path == pattern or path.startswith(pattern + ".") or path.startswith(pattern + "["):
            return True
    return False


def is_bridge_path(path: str) -> bool:
    return path.startswith("bridge.") or path.startswith("gBridge.")


def bridge_key(path: str) -> str:
    return path.split(".", 1)[1]


# --------------------------------------------------------------------------------------------
# canonical rendering + shared test vectors
# --------------------------------------------------------------------------------------------


def render(value: Any) -> str:
    """Stable text form of a decoded value -- the Godot/Lingo selftests compare against this."""
    if value is VOID:
        return "VOID"
    if isinstance(value, bool):
        return "TRUE" if value else "FALSE"
    if isinstance(value, Symbol):
        return "#" + str(value.name)
    if isinstance(value, Color):
        return "color(%d, %d, %d, %d)" % (value.r, value.g, value.b, value.a)
    if isinstance(value, Point):
        return "point(%s, %s)" % (_trim(value.x), _trim(value.y))
    if isinstance(value, Vector):
        return "vector(%s, %s, %s)" % (_trim(value.x), _trim(value.y), _trim(value.z))
    if isinstance(value, Quaternion):
        return "quat(%s)" % ", ".join(_trim(part) for part in value)
    if isinstance(value, Rect):
        return "rect(%s)" % ", ".join(_trim(part) for part in value)
    if isinstance(value, dict):
        return "{" + ", ".join("%s=%s" % (render(key), render(item)) for key, item in value.items()) + "}"
    if isinstance(value, (list, tuple)):
        return "[" + ", ".join(render(item) for item in value) + "]"
    if isinstance(value, float):
        return _trim(value)
    return str(value)


def _trim(value: Any) -> str:
    if isinstance(value, int):
        return str(value)
    number = float(value)
    if number.is_integer() and abs(number) < 1e15:
        return str(int(number))
    return repr(number)


def flatten(value: Any, prefix: str = "") -> List[str]:
    """A parsed literal -> a sorted-by-walk list of ``path=wiretext`` entries.

    This is the cross-language conformance trick: `render()` is cosmetic and float formatting
    differs between engines, but "parse this literal and tell me every leaf with its type" is
    exactly what the bridge does with it. Lingo list indices are 1-based, and they stay 1-based on
    the wire, because that is what both peers hand to `value()` / `getProp()`.
    """
    out: List[str] = []

    def walk(node: Any, path: str) -> None:
        if isinstance(node, dict):
            for key, item in node.items():
                walk(item, path_child(path, key.name if isinstance(key, Symbol) else key))
            return
        if isinstance(node, (list, tuple)):
            for index, item in enumerate(node, 1):
                walk(item, path_child(path, index))
            return
        out.append("%s=%s" % (path if path else "root", encode(node)))

    walk(value, prefix)
    return out


def write_verified(path: str, text: str) -> bool:
    """Write `text` to `path`, then check it is really there.

    Some sandbox/overlay filesystems report success for a write to a path they then refuse to
    materialise (this bit us on `Bridge/test/`). A generator that lies about its own output is worse
    than one that says "I could not write that", so every generated file goes through here.
    """
    directory = os.path.dirname(path) or "."
    os.makedirs(directory, exist_ok=True)
    if os.path.exists(path):
        os.unlink(path)  # fresh inode: overwrite-in-place can serve stale content on an overlay
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)
        handle.flush()
        os.fsync(handle.fileno())
    if not os.path.exists(path):
        return False
    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        return handle.read() == text


def write_compat_vectors(path: str) -> int:
    """Emit the TAB-delimited vector file the *engine* selftests read (Lingo and GDScript).

    Same content as vectors.json, different shape: one record per line, fields separated by TAB,
    which is exactly how Burnin' Rubber 4 stores every data file — so the Lingo selftest parses it
    with the same `itemDelimiter` + `item[i]` idiom the game uses, with no JSON reader in sight.

        value<TAB>note<TAB>wire[<TAB>render]
        message<TAB>note<TAB>verb<TAB>fieldcount<TAB>line
        literal<TAB>note<TAB>input<TAB>flattened
        kv<TAB>note<TAB>text
        path<TAB>path<TAB>namespace<TAB>parent<TAB>tail

    `flattened` is `flatten()`'s output joined with `|`: every leaf of the parsed literal as
    `path=wiretext`. Float text is engine-formatted, so a port compares *values*, not bytes —
    `render` and `flattened` are expectations, and a numeric compare is the contract.
    """
    from bridge_values import SAMPLES, MESSAGE_SAMPLES

    lines = ["# Shockwave <-> Godot bridge conformance vectors -- do not edit, generate me:",
             "#     python3 tools/bridge_proto.py vectors",
             "# Fields are TAB separated. '#' starts a comment. See PROTOCOL.md 2, 3, 4, 5."]
    for note, value in SAMPLES:
        wire = encode(value)
        lines.append(TAB.join(["value", note, wire, render(decode(wire))]))
    for note, line in MESSAGE_SAMPLES:
        verb, fields = parse(line)
        lines.append(TAB.join(["message", note, verb, str(len(fields)), line]))
    for note, text in LINGO_CASES:
        parsed = lingo_parse(text)
        lines.append(TAB.join(["literal", note, text, "|".join(flatten(parsed))]))
    for note, pairs in KV_CASES:
        lines.append(TAB.join(["kv", note, encode_kv([(k, v) for k, v in pairs])]))
    for path_text in PATH_CASES:
        lines.append(TAB.join(["path", path_text, path_namespace(path_text), path_parent(path_text), path_tail(path_text)]))
    if not write_verified(path, "\n".join(lines) + "\n"):
        raise ProtocolError("error", "could not materialise %s" % path)
    return len(lines)


def read_compat_vectors(path: str) -> Dict[str, List[List[str]]]:
    """Parse the TAB vector file back into ``{kind: [record...]}`` -- the selftests' shared reader."""
    out: Dict[str, List[List[str]]] = {"value": [], "message": [], "literal": [], "kv": [], "path": []}
    if not os.path.exists(path):
        return out
    with open(path, encoding="utf-8", errors="replace") as handle:
        for raw in handle.read().replace("\r\n", "\n").split("\n"):
            if not raw.strip() or raw.lstrip()[:1] == "#":
                continue
            fields = raw.split(TAB)
            kind = fields[0]
            if kind in out:
                record = fields[1:]
                if kind == "message":
                    # `message<TAB>note<TAB>verb<TAB>count<TAB>line` -- the line is a protocol line,
                    # so its own TABs are extra fields here. Ports rejoin from index 3 the same way.
                    record = record[:3] + [TAB.join(record[3:])]
                out[kind].append(record)
    return out


def write_vectors(path: str) -> Dict[str, Any]:
    """Emit the vector file both selftests consume, so "my port agrees with the oracle" is checkable."""
    from bridge_values import SAMPLES, MESSAGE_SAMPLES  # local import: keeps codec import cheap

    values = []
    for note, value in SAMPLES:
        wire = encode(value)
        values.append({"note": note, "wire": wire, "render": render(decode(wire))})
    messages = []
    for note, line in MESSAGE_SAMPLES:
        verb, fields = parse(line)
        messages.append({"note": note, "wire": line, "verb": verb, "fields": fields})
    literals = []
    for note, text in LINGO_CASES:
        parsed = lingo_parse(text)
        literals.append({"note": note, "input": text, "literal": lingo_prints(parsed), "flat": flatten(parsed)})
    kvs = []
    for note, pairs in KV_CASES:
        encoded = encode_kv([(k, v) for k, v in pairs])
        kvs.append({"note": note, "text": encoded})
    paths = []
    for path in PATH_CASES:
        paths.append({
            "path": path,
            "namespace": path_namespace(path),
            "parent": path_parent(path),
            "tail": path_tail(path),
        })
    payload = {
        "protocol": PROTOCOL_VERSION,
        "generated_by": "bridge_proto.py vectors",
        "values": values,
        "messages": messages,
        "lingo": [{"note": n, "literal": lingo_prints(lingo_parse(t)), "input": t} for n, t in LINGO_CASES],
        "literals": literals,
        "kvs": kvs,
        "paths": paths,
    }
    write_verified(path, json.dumps(payload, indent=1, ensure_ascii=False) + "\n")
    return payload


LINGO_CASES = [
    ("empty", "[]"),
    ("ints", "[1, 2, 3]"),
    ("nested", "[[1, 2], [3, 4]]"),
    ("proplist", '[#mass: 1200.5, #wheels: [1, 2, 3]]'),
    ("strings", '["Tank", "Taxi"]'),
    ("mixed", '[#name: "Bullet350", #ok: TRUE, #nil: VOID, #sym: #Racing]'),
    ("deep", '[[#a: [1, [2]]], #b]'),
    ("doubled quotes", '["He said ""no""", "C:\\path"]'),
    ("quote before a backslash", '["tail \\ ""q"""]'),
    ("path-ish strings", '[#file: "Data\\Cars\\Tank.w3d", #ok: TRUE]'),
]


KV_CASES = [
    ("two ints", [("gGame.Cash", 1000), ("gGame.Money", -5)]),
    ("mixed types", [("gGame.Cash", 1000), ("gGame.kmh", 187.5), ("gGame.RaceState", Symbol("#Racing")), ("gGame.name", "x")]),
    ("one void", [("bridge.gone", VOID)]),
    ("point and color", [("gGame.pos", Point(1.5, -2.0)), ("gGame.tint", Color(255, 0, 128))]),
    ("nested list payload", [("gGame.list", [1, 2, 3])]),
    ("empty string value", [("gGame.label", "")]),
]

PATH_CASES = [
    "gGame.Cash",
    "gGame",
    "bridge.wantBoost",
    "gGame.vehicles[3].general.kmh",
    "gGame.CurrentVehicle.Input.forward",
    "member(\"Console\").text.line[3]",
    "gd:Player.hp",
    "sprite(12).locH",
]


# --------------------------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------------------------


def selftest(verbose: bool = False, vectors_path: Optional[str] = None) -> int:
    from bridge_values import SAMPLES, MESSAGE_SAMPLES

    failures = 0
    for note, value in SAMPLES:
        wire = encode(value)
        back = decode(wire)
        if value is None:  # both spellings of "nothing" are `n`
            value = VOID
        if isinstance(value, str):  # §1: framing bytes are flattened, not escaped
            value = sanitize(value)
        if render(back) != render(value):
            failures += 1
            print("FAIL %s: %s -> %r (%s)" % (note, wire, back, render(back)))
        if encode(back) != wire:
            failures += 1
            print("FAIL re-encode %s: %s -> %s" % (note, wire, encode(back)))
        if verbose:
            print("ok   %-22s %s" % (note, wire))
    for note, literal in LINGO_CASES:
        parsed = lingo_parse(literal)
        printed = lingo_prints(parsed)
        if render(lingo_parse(printed)) != render(parsed):
            failures += 1
            print("FAIL literal %s: %s -> %s" % (note, literal, printed))
    for note, line in MESSAGE_SAMPLES:
        verb, fields = parse(line)
        rebuilt = build(verb, fields)
        if rebuilt != line:
            failures += 1
            print("FAIL message %s:\n  have %r\n  want %r" % (note, rebuilt, line))
    pairs = [("gGame.Cash", 1000), ("gGame.kmh", 187.5), ("bridge.mode", Symbol("#autopilot")), ("gGame.name", "x")]
    kv = encode_kv([(k, v) for k, v in pairs])
    if [(k, render(v)) for k, v in decode_kv(kv)] != [(k, render(v)) for k, v in pairs]:
        failures += 1
        print("FAIL kv round-trip: %s" % kv)
    data = Batch(["HELLO" + TAB + "godot", "PING" + TAB + "1" + TAB + "2"]).to_bytes()
    if len(Batch.from_bytes(data)) != 2:
        failures += 1
        print("FAIL batch round-trip")
    buffer = pack(data) + pack(data)[:8]  # second frame deliberately cut short of its payload
    frames, rest = unpack(buffer)
    if len(frames) != 1 or rest != pack(data)[:8] or Batch.from_bytes(frames[0]).to_bytes() != data:
        failures += 1
        print("FAIL tcp framing: %d frames, %d leftover bytes" % (len(frames), len(rest)))
    if Batch.from_text("").lines or Batch().to_bytes():
        failures += 1
        print("FAIL an empty batch must stay empty")
    tab_path = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Director", "Bridge.Vectors.txt"))
    if not os.path.exists(tab_path):
        failures += 1
        print("FAIL Bridge/Director/Bridge.Vectors.txt is missing -- run: python3 bridge_proto.py vectors")
    if os.path.exists(tab_path):
        table = read_compat_vectors(tab_path)
        for note, wire, rendered in [tuple(r[:3]) + ("",) * (3 - len(r[:3])) for r in table["value"]]:
            if encode(decode(wire)) != wire:
                failures += 1
                print("FAIL tab vector value %s" % note)
            if rendered and render(decode(wire)) != rendered:
                failures += 1
                print("FAIL tab vector render %s: %s" % (note, render(decode(wire))))
        for record in table["message"]:
            line = record[-1]
            verb, fields = parse(line)
            if verb != record[1] or len(fields) != int(record[2]) or build(verb, fields) != line:
                failures += 1
                print("FAIL tab vector message %s" % record[0])
        for record in table["literal"]:
            if "|".join(flatten(lingo_parse(record[1]))) != (record[2] if len(record) > 2 else ""):
                failures += 1
                print("FAIL tab vector literal %s" % record[0])
        for record in table["kv"]:
            if encode_kv(decode_kv(record[-1])) != record[-1]:
                failures += 1
                print("FAIL tab vector kv %s" % record[0])
        for record in table["path"]:
            if len(record) >= 4 and (path_namespace(record[0]), path_parent(record[0]), path_tail(record[0])) != tuple(record[1:4]):
                failures += 1
                print("FAIL tab vector path %s" % record[0])
        print("tab vectors: %d records from %s" % (
            sum(len(table[k]) for k in table), os.path.basename(tab_path)))
    if vectors_path and os.path.exists(vectors_path):
        with open(vectors_path, encoding="utf-8") as handle:
            vectors = json.load(handle)
        for entry in vectors.get("values", []):
            if encode(decode(entry["wire"])) != entry["wire"]:
                failures += 1
                print("FAIL vector %s" % entry["note"])
            if render(decode(entry["wire"])) != entry["render"]:
                failures += 1
                print("FAIL vector render %s" % entry["note"])
        for entry in vectors.get("messages", []):
            if build(entry["verb"], entry["fields"]) != entry["wire"]:
                failures += 1
                print("FAIL message vector %s" % entry["note"])
            verb, fields = parse(entry["wire"])
            if verb != entry["verb"] or fields != entry["fields"]:
                failures += 1
                print("FAIL message parse vector %s" % entry["note"])
        for entry in vectors.get("literals", []):
            if flatten(lingo_parse(entry["input"])) != entry["flat"]:
                failures += 1
                print("FAIL literal vector %s: %s" % (entry["note"], flatten(lingo_parse(entry["input"]))))
        for entry in vectors.get("kvs", []):
            if encode_kv(decode_kv(entry["text"])) != entry["text"]:
                failures += 1
                print("FAIL kv vector %s: %s" % (entry["note"], encode_kv(decode_kv(entry["text"]))))
        for entry in vectors.get("paths", []):
            got = (path_namespace(entry["path"]), path_parent(entry["path"]), path_tail(entry["path"]))
            if got != (entry["namespace"], entry["parent"], entry["tail"]):
                failures += 1
                print("FAIL path vector %s: %s" % (entry["path"], got))
        print(
            "vectors: %d values, %d messages, %d literals, %d kvs, %d paths from %s"
            % (
                len(vectors.get("values", [])),
                len(vectors.get("messages", [])),
                len(vectors.get("literals", [])),
                len(vectors.get("kvs", [])),
                len(vectors.get("paths", [])),
                os.path.basename(vectors_path),
            )
        )
    if failures:
        print("%d failure(s)" % failures)
        return 1
    print("codec selftest: %d values, %d literals, %d messages -- all pass" % (len(SAMPLES), len(LINGO_CASES), len(MESSAGE_SAMPLES)))
    return 0


def bench(frames: int = 20000, keys: int = 40) -> None:
    pairs = [("gGame.vehicles[%d].general.kmh" % index, 120.0 + index) for index in range(keys)]
    kv = encode_kv(pairs)
    start = time.time()
    for _ in range(frames):
        verb, fields = parse(build("DELTA", [1, 2, 3, 4, kv]))
        decode_kv(fields[4])
    took = time.time() - start
    print(
        "%d frames x %d keys: %.1f us/frame, %.2f MB/s (python reference; Lingo/GDScript are slower)"
        % (frames, keys, took / frames * 1e6, len(kv) * frames / 1e6 / max(took, 1e-9))
    )


def main(argv: List[str]) -> int:
    mode = argv[1] if len(argv) > 1 else "selftest"
    here = os.path.dirname(os.path.abspath(__file__))
    vectors_path = os.path.normpath(os.path.join(here, "..", "test", "vectors.json"))
    if mode == "selftest":
        return selftest("-v" in argv, vectors_path if os.path.exists(vectors_path) else None)
    if mode == "vectors":
        # The TAB file is the primary artifact: it is what the Lingo and Godot selftests read, and
        # both parse it with the same itemDelimiter idiom the game uses for its own data files.
        tab_target = os.path.normpath(os.path.join(here, "..", "Director", "Bridge.Vectors.txt"))
        count = write_compat_vectors(tab_target)
        print("wrote %s (%d records)" % (os.path.relpath(tab_target, here), count))
        addon_tab = os.path.normpath(os.path.join(here, "..", "godot", "addons", "shockwave_bridge", "Bridge.Vectors.txt"))
        if os.path.isdir(os.path.dirname(addon_tab)):
            shutil_copy(tab_target, addon_tab)
            print("mirrored to %s" % os.path.relpath(addon_tab, here))
        # `vectors <file.json>` additionally writes the JSON form, for a third endpoint that would
        # rather read objects than TAB lines. Nothing in this repo consumes it -- the TAB file is the
        # artifact of record for all three engines -- so it is opt-in rather than emitted and then
        # shrugged at when a stale default path does not exist.
        if len(argv) > 2:
            target = os.path.normpath(argv[2])
            try:
                payload = write_vectors(target)
            except OSError as error:  # a filesystem that will not take the file is not a protocol bug
                print("skip %s: %s" % (target, error))
                return 1
            print("wrote %s (%d values)" % (os.path.relpath(target, here), len(payload["values"])))
        return 0
    if mode == "bench":
        bench()
        return 0
    if mode == "encode":
        text = " ".join(argv[2:])
        if not text:
            print(encode(VOID))
            return 0
        try:
            value = scalar(text)
        except ProtocolError:
            # On a command line a bare word means a string. `scalar()` is the parser the protocol
            # uses -- it wants a tag or a number -- so try it first, then fall back rather than
            # making `bridge_proto.py encode Burnin Rubber 4` an error.
            value = text
        print(encode(value))
        return 0
    if mode == "decode":
        print(render(decode_or_text(argv[2])) if len(argv) > 2 else "usage: decode <tag:payload>")
        return 0
    print(__doc__)
    return 2


def shutil_copy(src: str, dst: str) -> None:
    os.makedirs(os.path.dirname(dst) or ".", exist_ok=True)
    with open(src, "rb") as handle:
        data = handle.read()
    with open(dst, "wb") as handle:
        handle.write(data)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
