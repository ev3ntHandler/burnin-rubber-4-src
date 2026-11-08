# Shockwave ⇄ Godot Bridge — wire protocol v1

Normative spec for everything in this folder. The Director (Lingo), Godot (GDScript) and
Python (`tools/`) peers all implement *this* document. If code and this file disagree, the
file is right and the code has a bug.

Design goals, in order: **offline** (no internet, no third-party services, no install-time
dependencies beyond Director + Godot), **real-time** (one message round trip per game frame),
**fast** (the Lingo hot path must only use string concat + `.item[]` — no parser, no JSON),
**symmetric** (either side can read/write/call the other), **safe by default** (allow-listed
paths, `eval`/`exec` off unless you turn them on, loopback-only binds).

---

## 1. Framing

A **message** is one line. A **frame** (a.k.a. batch) is zero or more messages, LF separated.

```
message := field { TAB field }
field   := printable-text        ; MUST NOT contain TAB, CR or LF
frame   := { message LF }
```

* Field separator: **horizontal tab, `0x09`**. Chosen because the game engine already uses TAB
  as its `itemDelimiter`, so Lingo reads/writes records with the same native chunk expression
  it uses for its own data files — the fastest string operation available in Director.
* Record separator: **LF `0x0A`**. Files may be stored with CRLF; readers MUST strip a
  trailing `CR` from each line before splitting.
* Charset: UTF-8. Both peers MUST sanitise strings they emit: replace `TAB`, `CR`, `LF` with
  a single space. Lingo side does the rare-path check `if tString contains tab then …`, so the
  fast path (no tab present) is a single comparison.
* **No escaping exists.** Any byte sequence that would break framing is flattened on write.
  Consequence: `set` of a string value containing a TAB round-trips as a space. Documented,
  accepted trade-off for a 30 Hz debug/control channel. (Binary payloads, e.g. images, are out
  of scope; use `xtra` transport or the file-drop channel described in §7.)

A transport may prepend **transport-level framing** (a length/validity header) around a batch;
see each transport section. That header is the only thing a reader parses before message parsing.

## 2. Typed values

Every value on the wire is written as

```
value := tag ":" payload | tag
```

| tag | payload                | Lingo type        | Godot type          | notes |
|-----|------------------------|-------------------|---------------------|-------|
| `i` | `-?[0-9]+`             | `#integer`        | `INT`               | 64-bit on Godot side |
| `f` | `-?d+.d+(e[-+]dd)?`    | `#float`          | `FLOAT`             | always contains `.` so `value()` yields a float |
| `s` | any text               | `#string`         | `STRING`            | sanitised (§1) |
| `b` | `0` \| `1`             | `#integer` 1/0    | `BOOL`              | Lingo has no booleans |
| `y` | `sym`                  | `#symbol`         | `STRING_NAME`       | leading `#` omitted on the wire |
| `p` | `x,y`                  | `#point`          | `Vector2`           | integers or floats |
| `v` | `x,y,z`                | `#vector`         | `Vector3`           | |
| `q` | `x,y,z,w`              | `#quaternion`     | `Quaternion`        | |
| `c` | `r,g,b[,a]`            | `#color`          | `Color`             | 0–255 ints (Godot converts /255) |
| `r` | `l,t,r,b`              | `#rect`           | `Rect`              | Director's `t` = top, `b` = bottom |
| `d` | `ms`                   | `#date` (ticks)   | `float` (unix secs) | epoch ms, for Godot-side timestamps |
| `l` | Lingo list literal     | `#list`/`#propList` | `Array`/`Dictionary` | §3; the only nested type |
| `n` | *(empty)*              | `#void`           | `null`              | "does not exist"; write to it = `deleteProp` |

Unknown tag ⇒ reader replies `err:badtype` and drops the message.

`l:` payloads are the *only* place where a real parser is needed, so snapshots and all
`set`/`get` of scalars never touch it. Prefer flat scalar paths over `l:` in the hot path.

## 3. Lingo literal (`l:` payload)

The nested payload is a **Lingo list literal**, which is JSON-like and — critically — parsable
by both peers with almost no code: Director parses it with the built-in `value()`, and Godot
with `LingoLit.parse()` (subset documented below).

```
literal := "[" [ item { "," item } ] "]"
item    := literal | number | string | symbol | propitem | "VOID" | "TRUE" | "FALSE"
propitem := symbolkey ":" item | string ":" item
number  := -?digit+ ("." digit+ (("E"|"e") +-?digit+)?)?
string  := '"' { escaped-quote | any-char-except-quote } '"'
escaped-quote := '""'         -- a string ends at the first quote NOT followed by another quote
symbol  := "#" { alnum | "_" }
symbolkey := "#" { alnum | "_" }
```

Rules for the **writer**:
* `Dictionary`/`propList` keys are always written as `#symbol:` — never `"str":`.
* Strings are double-quoted, and a quote inside one is **doubled**: `["a ""b"""]` is the
  one-element list holding `a "b"` — one `""` pair per quote you want inside, then the single quote
  that closes the literal (which is why that example's tail is three quotes). Director has no
  backslash escapes at all, so `"a\"b"` ends the string at the backslash — an escaped quote is
  text the movie cannot read back with `value()`. A backslash is therefore written as itself.
  Control chars are flattened to a space, as everywhere else (§1).
* Floats must contain a `.` (or `e`) so Director's `value()` produces a float, not an integer.
* `null` → `VOID`, `true/false` → `TRUE/FALSE`, `Color`/`Vector*`/`Rect` → their `l:`-equivalent
  tags are preferred; inside a literal they are written as plain arrays `[r, g, b]`.
* Empty: `[]`.

Rules for the **reader** (Godot): the above subset only; a doubled quote inside a string becomes
one quote character (a hand-typed `\"` is tolerated too, because people paste JSON-ish literals
into the Message window); `#sym` becomes the plain string `sym`; `TRUE`/`FALSE` become booleans;
`VOID` becomes `null`; anything unparseable becomes the raw string — never an error, because a
debug channel must not die on data.

## 4. Messages

First field is the verb. All ids are decimal ints, monotonically increasing **per peer**.

### handshake / liveness
```
HELLO   role name proto seq caps          caps = "," separated: eval,exec,write,snap,sub,event
BYE     reason code
PING    id tms
PONG    id tms
LOG     level text                        level: 0 info | 1 warn | 2 error
```
`role` ∈ `director` | `godot`. `proto` = `1`. Both peers send `HELLO` right after the peer is
first heard from. A peer is **live** if its last inbound `seq` advanced or a `PONG` arrived
within `peerTimeoutMs` (default 2000); otherwise it is `stale`; at 5× the timeout it is `down`
and the transport re-initialises (for `http`: re-issues its poll chain).

`HELLO` is also the **reset** signal. It carries the greeter's current `seq`, and each side numbers
frames from 1 whenever it starts — so a receiver that remembers a *higher* position has to conclude
that the sender began a new session, and re-arm both its frame gate and its snapshot dedupe before
applying the rest of that frame (§8). Without this, restarting one side while the other keeps
running silences it until the new counter passes the old one, which after a long session is
tens of thousands of frames. The greeting is the first line of the restarting peer's first frame, so
this ordering is automatic; no side has to detect the restart any other way.

### state (the hot path — no response, never blocks)
```
SNAP    seq frame tms ack kvlist          full snapshot of the exposed set
DELTA   seq frame tms ack kvlist          only keys changed since the previous snapshot
EVT     seq name kvlist                   fire-and-forget event
```
`frame` is the sending game's frame counter (`_movie.frame` / `Engine.get_frames_drawn()`),
`tms` its `_system.milliSeconds` / `Time.get_ticks_msec()`. `ack` is the highest inbound `seq`
the sender has processed — this piggybacked acknowledgement is what lets the file transports do
back-pressure and cleanup without a second channel.

`kvlist := key "=" value { ";" key "=" value }` — keys are §5 paths. `;` is illegal inside a key,
`.` separates path segments, so a key is always one unambiguous token.

### RPC
```
REQ  id op args...                        request → exactly one RSP with the same id
RSP  id op status args...                 status = ok | err ; err args = (code, message)
CMD  id op args...                        fire-and-forget (no RSP ever)
```

### RPC ops (both peers implement what applies to them)

| op | args | reply args (after `ok`) | meaning |
|----|------|-------------------------|---------|
| `get` | `path` | `path value` | read one value |
| `gets` | `pathlist` | `path value;path value…` | read many, one message |
| `set` | `path value` | `path value` | write one value; `n` deletes |
| `sets` | `path=value;…` | `path=value;…` | write many atomically (same frame) |
| `list` | `path depth` | `path value;…` | enumerate; `depth 0` = props only |
| `sub` | `path [interval]` | `path value` | start mirroring a path |
| `unsub` | `path` | `path` | stop mirroring |
| `snap` | `mode rate [delta]` | `mode rate` | `mode` `b:0`/`b:1`, `rate` = every N frames |
| `call` | `handler target literal` | `value` | Director: `_movie.sendSprite(0, handler, target, dataList)`; Godot: `node.method(...)` |
| `event` | `name literal` | `value` | Director: `event(0, #name)`; Godot: emit `bridge_event` |
| `eval` | `expression` | `value` | **capability `eval`** — Director `value(expr)` |
| `exec` | `statements` | `value` | **capability `exec`** — Director `do(stmts)` |
| `ping` | `tms` | `tms` | round-trip probe |
| `quit` | — | `value` | close the bridge, restore state |

Errors: `RSP id op err code message` with `code` ∈ `unknownop`, `badargs`, `nopath`, `denied`,
`disabled`, `notfound`, `error`, `timeout`.

## 5. Paths

```
path := ns [ "." seg ] { "." seg }
ns   := "gGame" | "gSystem" | "gData" | "gSound" | "gBridge" | "bridge" | "gd"
      | "member" "(" name ")" | "sprite" "(" num ")" | "_movie" | "_player" | "_system" | "_movie.timer"
seg  := ident | "[" int "]" | "(" args ")"
```
* On the **Director** side a plain path ("gGame.a.b[2]") is **walked**, not evaluated: split
  into segments, index propLists by "#symbol" and lists 1-based, stop at the first missing key.
  That is faster than "value()" on the hot path and, more usefully, incapable of running anything.
  Only a path that needs a call or engine access ("member(...)", "sprite(...)", "_movie.*",
  "line[n]") is assembled into an expression and evaluated, so anything expressible in the
  Message window still works:
  "gGame.Cash", "gGame.vehicles[1].general.kmh", "member('Console').text.line[3]", "sprite(12).locH".
  Writes go through "do("path = value")" and are gated by the write allow-list (§6).
  "bridge.*" and "gBridge.*" resolve into the bridge's own replicated store ("gBridge.store"), which needs
  allow-list (§6). `bridge.*` and `gBridge.*` resolve into the bridge's own replicated store
  (`gBridge.store`), which needs no `value()` at all.
* On the **Godot side** "gd:" paths resolve against objects registered with
  "ShockwaveBridge.bind_node(node, 'Player')" → "gd:Player.hp" reads/writes the "hp" property
  of that node via "Object.get"/"Object.set", so setters, export hints and "_set" overrides behave
  as they do in the editor. One segment further: a math type is not an Object, so
  "gd:Player.speed[0]", "gd:Panel.rect[2]" and "gd:Sprite.modulate[1]" address **components**, numbered to
  match the wire tags of §2 — a colour's components are 0–255 ints, and a rect's 2 and 3
  are its END coordinates, not "size". Writing a component reads the whole value, replaces one
  part and stores it back, because a math type read out of a property is a copy.
  node. `bridge.*` resolves into Godot's replicated store, identical to the Director side.
* Paths are opaque to the transport; only the owning peer interprets them.

## 6. Security / capability model

* `bridge.allow_read` (default `[gGame, gSystem, gData, gSound, bridge, gBridge]`) — a read
  outside it returns `denied`.
* `bridge.allow_write` (default **empty**) — nothing may be written until you opt in per path.
  `gGame.Cash` allows `gGame.Cash` only; `gGame.vehicles` allows the whole subtree.
* `eval`/`exec` are `disabled` unless `bridge.allowEval = 1` **and** the transport is a local one
  (file/tcp on loopback). Never enable for a movie published to the web.
* Godot binds `127.0.0.1` only by default (`bridge/bind = "127.0.0.1"`); set an explicit
  address to expose on the LAN. Bridge requests are unauthenticated: treat anyone who can open
  the port as able to run Lingo.
* Every inbound message is processed **inside the game's frame tick**, never in a callback, so
  no bridge message can re-enter the engine mid-frame.

## 7. Transports

All transports carry the same §1 batches. `files` is the default because it works with zero
setup on any OS, in the Director editor, in a projector, and even in the browser-sandboxed
Shockwave plugin when the movie folder is writable.

### 7.1 `files` (default)
Directory `<movie>/BridgeData/` (or the path in `bridge.root`), two batch files plus one
heartbeat each way:

```
BridgeData/d2g.txt      director → godot, one full batch, rewritten every snapshot
BridgeData/d2g.seq      "<seq> <bytes> <lines> LF"     written *after* d2g.txt  (commit marker)
BridgeData/g2d.txt      godot → director
BridgeData/g2d.seq      "<seq> <bytes> <lines> LF"
```
Write order is the whole protocol: payload file first (fully closed), then the tiny ".seq"
marker. A reader accepts a payload when its line count equals "lines" **exactly** and its size is
**at least** "bytes". The line count is the real witness: a payload always ends in exactly one LF, so a
partial write cannot produce the promised count. The size is a minimum rather than an equality
because a Lingo writer can only count characters ("tText.length"), and any non-ASCII value in a
snapshot is longer in UTF-8 than that — a reader demanding equality would reject every frame a movie
wrote with an accented car name in it. Both writers that can rename do it
("payload.tmp" → "payload"), which costs nothing; the Director half cannot, which is exactly why the
two witnesses are the guarantee instead of a nicety.

The frame gate is an **equality** test, never an ordering one: a reader skips a payload whose `seq`
is exactly the frame it already applied and accepts every other value, including a lower one. "Already
applied" is a statement about a session, and a marker on disk cannot tell a stale frame from a peer
that restarted — rejecting the lower `seq` is what turns a re-run into a dead link (§4, §8). A reader
that polls twice between writes sees the same `seq` twice, which is the only repeat worth skipping.

A 4th marker token `crc32hex` may be appended when the writer can compute one cheaply (the
Python tools and Godot do; Director generally has no CRC in stock Lingo). Readers MUST treat it
as optional and only verify it when present.

* Latency: one poll interval. Godot polls on `_physics_process` (60 Hz default, tunable to
  240 Hz); Director reads once per `enterFrame` (32 Hz at the movie's `Tempo 32.0`).
* Throughput: ~40 bytes/second/kilobyte-of-snapshot — far below the disk's ability to keep up.

### 7.2 `http` (recommended when you want sub-ms and no filesystem)
Godot serves a minimal HTTP/1.1 responder on `127.0.0.1:7778`:

```
GET  /bridge/poll?ack=<n>&wait=<ms>   → 200 text/plain  batch (long-poll, holds ≤ wait ms)
POST /bridge/push                     body = batch      → 200 "ok"
GET  /bridge/push?b=<percent-encoded batch>             → 200 "ok"      (Director)
GET  /bridge/state                    → 200 JSON mirror of the state store (for browsers/tools)
GET  /bridge/handshake                → 200 "godot proto=1 caps=…"
```
Director issues exactly one in-flight `getNetText` poll, and re-arms the moment
`netTextDone`/`netTextResult` returns — so it is push-with-polling-fallback, ~0.3 ms on
loopback, zero bandwidth while idle. `POST` bodies are one batch each; no chunking.
Query values are percent-encoded by the Director side (`%09` for TAB, `%0A` for LF) because
`getNetText` URLs cannot contain raw tabs. "wait" default 1500 ms.

Director pushes with the **GET** form rather than the POST: stock NetLingo's "getNetText" is a
GET, and its POST form ("newNetText(url, data)") differs in content-type and chunking behaviour
across Director versions in ways that cannot be checked from the protocol side, while one
frame's batch fits in a URL with room to spare. A listener MUST accept both forms and treat them
identically; tools, the browser and the Godot editor use POST.

### 7.3 `tcp` (for socket Xtras, relays and tooling)
Godot listens on "127.0.0.1:7777". Newlines-delimited batches, no ".seq" marker needed (the
stream is ordered and framed by LF).

A reader drains its socket **once per frame** and processes every complete line, keeping the
unterminated remainder for the next read. The bound on that drain is bytes, not message count:
**256 KiB per read**, and a peer that exceeds it has been fed a flood or garbage, so the link is
dropped rather than parsed further. A per-line message count is not a usable bound on a stream
("SNAP" legitimately carries thousands of "path=value" pairs in one line); the limit that matters is
how many bytes arrive between two frames, which is the same limit the "files" transport implies.

A 4-byte little-endian length framing is available by setting "bridge.binary = 1":

```
u32 len · <batch bytes>          (len excludes the 4 header bytes)
```
Director reaches this transport through any Xtra exposing `connect/send/input` (see
`Bridge/Director/INSTALL.md` §"socket Xtra"); `tools/mock_director.py` and
`tools/bridge_probe.py` speak it natively, which is how the protocol is tested without Director.

### 7.4 `udp` (telemetry only, one-way per direction)
Port 7779, one datagram per batch, no ack, no ordering guarantees. Use it for
high-rate snapshots when you deliberately don't want reliability; commands must go over
`files`/`http`/`tcp`.

## 8. Timing & ordering guarantees

* Within one batch, messages are processed top to bottom, in order.
* `SNAP`/`DELTA` never require a reply; `REQ` always gets exactly one `RSP`, within the peer's
  next frame (default timeout 2000 ms; the requester resolves pending `REQ`s as `timeout` and
  keeps the last known value, flagged `stale`).
* `CMD` is idempotent-safe by construction: all `CMD` ops (`set`, `sets`, `snap`, `event`) are
  either last-write-wins or keyed by `id`, so a duplicate delivery (possible with `files`
  replay) cannot corrupt state.
* A peer must never apply an inbound batch twice for the same `seq` (dedupe on `seq`). The test is
  equality, not order, and it is re-armed by `HELLO`: both sides restart their counters at 1 whenever
  they start, independently of the other, so "smaller than the last one" means "new session" far more
  often than "stale". Values are last-write-wins, so re-applying a frame after a re-arm is harmless;
  ignoring one is not.

### 8.1 Conformance

`Bridge/Director/Bridge.Vectors.txt` is the shared test table, generated from the reference
implementation's own sample table by `python3 Bridge/tools/bridge_proto.py vectors` and mirrored into
the addon. One record per line, TAB separated, first field the kind:

| kind | rest of the record | what it pins down |
| --- | --- | --- |
| `value` | `note wire render` | `decode(wire)` prints as `render`, and re-encoding gives `wire` back **byte for byte** |
| `message` | `note verb fieldcount line` | a whole line splits into that verb and exactly `fieldcount` fields |
| `literal` | `note input flattened` | the `l:` literal parser, including how a parsed value flattens to `path=wire` leaves |
| `kv` | `note text` | a `key=wire;key=wire` list, parsed and re-rendered |
| `path` | `path namespace parent tail` | the path grammar: which global a path hangs off, its parent, its last component |

Numbers compare numerically — Lingo prints six significant digits where python prints the shortest
round trip, and demanding byte equality there would fail on formatting, not on meaning. Every other
field compares as text. The re-encode check is the load-bearing one: a decoder that is *lenient*
(accepting `1` for a float, say) still passes `render` while breaking `encode(decode(wire)) == wire`,
which is what makes two engines exchange bytes instead of merely tolerating each other.

Four commands, all of which must pass for a third implementation to claim conformance:

    python3 Bridge/tools/bridge_proto.py selftest          # the reference, against the same file
    python3 Bridge/tools/bridge_probe.py selftest          # codec + vectors + a live two-peer loopback
    godot --headless --path Bridge/godot --script addons/shockwave_bridge/bridge_selftest.gd
    BridgeSelfTest()                                       # in Director's Message window

Each of those also runs its own behavioural checks — handshake, the `seq` dedupe and its `HELLO`
re-arm (§4, §8), allow-list refusals, the file frame gate (§7.1) — against the same expectations.
`python3 Bridge/tools/test_bridge.py` pairs two reference peers over `files`, `http` and `tcp`
together, which is the suite the other three are measured against. `Bridge/tools/lint_lingo.py
Bridge/Director` is the Director-side stand-in while no copy of Director is open — block structure,
string/comment dialect, and handler-name collisions: it reads this repo's 155 movie scripts for their
759 names without judging them, so a `structure ok` there also means the bridge's 137 global handlers
step on none of the game's, which is the pre-emption of Director's load-time `more than one handler
named X` failure. (`enterFrame` is the one name both sides define, and sharing it is correct: Lingo
events belong to every script that wants them, which is how the bridge gets its per-frame tick at all.
The checker exempts event names from the collision rule for exactly that reason.) Add `.` as a second
argument to run the same checks over the game's own scripts, which is where its 39 calls into Xtra
methods (`rgb`, `transform`, …) show up as unresolved — pre-existing, and why that run is informational
rather than a gate.

## 9. Versioning

`proto` in `HELLO` is the major version. Unknown verbs ⇒ reply `err unknownop`, do not
disconnect. Unknown fields appended at the end of a message ⇒ ignore. Peers must never assume a
fixed field count beyond the verb, and must tolerate trailing empty fields.
