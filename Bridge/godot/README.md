# Shockwave Bridge — Godot addon

Read live state out of a running Adobe Director / Shockwave movie, and write state back into it,
from Godot, **offline and in real time**. No server, no internet, no third-party installers: the
default transport is a shared folder both programs already can reach.

This is the Godot half. The Director half is `../Director/INSTALL.md`; the wire itself is
`../PROTOCOL.md`; `../tools/` is a Python reference implementation of the same protocol that the
two engines are conformance-tested against.

```
Godot                                   Director / Shockwave
ShockwaveBridge (autoload)   ⇄  BridgeData/d2g.txt · g2d.txt   ⇄   [M] Shockwave Bridge (3 scripts)
    read_path("gGame.Cash")            one file write per frame       mirrors gGame every frame
    write_path("gGame.pause", 1)                                        applies writes in enterFrame
```

## Install

1. Copy `addons/shockwave_bridge/` into your project's `addons/`.
2. **Project ▸ Project Settings ▸ Plugins** ▸ enable *Shockwave Bridge*. The dock appears as a
   **Shockwave** bottom panel, and it offers to install the autoload for you.
3. Or install the autoload by hand: **Globals ▸ Autoload** ▸ `res://addons/shockwave_bridge/shockwave_bridge.gd`,
   name `ShockwaveBridge`, check *Enable*.

That is the whole install. The addon has no scene, no shader, no dependency, and nothing in your
project needs to reference it — you read it, it does not call you.

## Point it at the movie

Both peers read the *same* config file, `Bridge.Data.txt`, so there is one source of truth. Put the
movie's copy where Godot can see it and tell the autoload where it is:

| Autoload property | What it does |
| --- | --- |
| `config_path` | Path to `Bridge.Data.txt`. Leave empty to search `res://Bridge.Data.txt`, `res://Bridge/Director/Bridge.Data.txt`, `res://addons/shockwave_bridge/Bridge.Data.txt` |
| `mailbox_base` | Base directory a relative `root` in the config resolves against. Empty = `user://`. Set it to the movie folder (absolute) when the two projects sit side by side |
| `transport_override` | `""` = whatever the config says; otherwise `files`, `http` or `tcp`. Also switchable live from the dock |
| `physics_tick` | Poll in `_physics_process` (deterministic, 60 Hz) instead of `_process` (one per drawn frame). Keep it on when you write physics from mirrored values |
| `bindings` | `Alias=/root/Scene/Node` entries that let the movie address your scene as `gd:Alias.prop` |
| `initial_store` | `key=literal` seeds for the replicated store, e.g. `wantBoost=TRUE`, `targetKmh=140.0` |

Example, for a Godot project next to the movie checkout:

```
mailbox_base     res://../../            # or an absolute path
config_path      res://Bridge/Director/Bridge.Data.txt
```

and in that `Bridge.Data.txt`, so both sides agree on the mailbox:

```
root	BridgeData
```

## Reading the game

Anything in the movie's `expose` list is mirrored into Godot **every frame**, so a read is a
dictionary lookup — no round trip, no await, safe to call from `_process`:

```gdscript
func _process(_delta: float) -> void:
    speed_label.text = "%d km/h" % ShockwaveBridge.read_int("gGame.CurrentVehicle.general.kmh")
    health_bar.value = ShockwaveBridge.read_number("gGame.CurrentVehicle.general.health")
    if ShockwaveBridge.read_int("gGame.pause") == 1:
        get_tree().paused = true
```

| call | returns |
| --- | --- |
| `read_path(path, fallback)` | the mirrored value, typed (int, float, String, StringName, Vector2/3, Color, Rect2, Array, Dictionary, or `null` for VOID) |
| `read_number` / `read_int` / `read_string` | the same value coerced, so a missing path does not crash a HUD |
| `mirror()` | the whole mirrored dictionary |
| `subscribe(path, rate)` | start mirroring a path the config forgot; `unsubscribe(path)` stops |
| `request_read(path, callback)` | **cold read**: asks the movie with a `REQ` and answers the callback when the `RSP` lands, usually the next frame. Use it for anything not in `expose` |
| `request_many([paths], cb)` | one `REQ gets` for several paths, one round trip |
| `list_paths(prefix, depth, cb)` | enumerate the movie's side, e.g. `list_paths("gGame.CurrentVehicle", 2, ...)` |

`read_path` reads the *mirror*, so its value is whatever the movie last sent: at most one frame
old, and never blocking. `request_read` asks the movie *now*, so it costs a frame of latency and
returns nothing until the callback fires. Those two are the whole API decision: hot paths read the
mirror, tools and setup code request.

## Writing back

```gdscript
# A path on the movie's `write` allow-list lands in gGame on the movie's next frame.
ShockwaveBridge.write_path("gGame.Cash", 999999)
ShockwaveBridge.write_path("gGame.pause", 1)

# Several at once, in one message — the movie applies the batch in one enterFrame.
ShockwaveBridge.write_many({
    "gGame.CurrentVehicle.Input.forward": 1,
    "gGame.CurrentVehicle.Input.brake": 0,
})

# Anything else: the replicated store. Needs no allow-list, cannot break the game,
# arrives on both sides, and is writable from either.
ShockwaveBridge.send_custom("wantBoost", true)
var boost := ShockwaveBridge.read_custom("wantBoost", false)
```

`write_path` refuses loudly and harmlessly when the movie says `denied`: it logs through the
`bridge_log` signal and leaves the mirror alone. There is no way to make the movie execute
something from here unless its config explicitly turns `allowEval` on.

Two more channels, both gated by the movie's config:

```gdscript
# Invoke a Lingo handler by name with a propList; the reply is its return value.
ShockwaveBridge.call_director("PutMessage", 0, {"message": "hello from Godot"},
    func(result): print("movie answered: ", result))

# Raise one of the movie's own events (it dispatches via its Event Manager).
ShockwaveBridge.raise_director_event("BridgePause", {"reason": "cutscene"})
```

## Your scene, addressed from the movie

Bind a node and the movie can read and write its properties as `gd:` paths — which is how you let a
Shockwave HUD drive Godot state without writing a line of Godot code:

```gdscript
func _ready() -> void:
    ShockwaveBridge.bind_node($Player, "Player")
```

```lingo
-- in the movie
BridgeGet(0, "gd:Player.hp")          -- read a Godot property
BridgeSet(0, "gd:Player.score", 2500) -- write one
```

`gd:Player.position[1]` reaches components (a Vector's `y`, a Color's channels as 0–255 ints, a
Rect's end coordinates), and `gd:Player.take_damage(25)`? No — calls go through
`call_director`/`call`, and a handler named in the movie's `call` list can call back into Godot
with `BridgeCallRemote`. Properties need no allow-list on the Godot side for `gd:` reads — but the
movie's own `expose`/`call` lists decide what it may ask for, so the movie is the one that says no.

React to changes instead of polling:

```gdscript
func _ready() -> void:
    ShockwaveBridge.director_value_changed.connect(_on_director_value)
    ShockwaveBridge.bridge_event_raised.connect(_on_movie_event)
    ShockwaveBridge.status_changed.connect(func(status): print("bridge: ", status))

func _on_director_value(path: String, value: Variant) -> void:
    if path == "bridge.wantBoost":
        _apply_boost(value)

func _on_movie_event(name: String, data: Dictionary) -> void:
    if name == "BridgePause":
        get_tree().paused = true
```

And a bound node gets `bridge_event(name, data)` called on it directly, so a scene can own its own
reaction without touching the autoload.

## The Shockwave dock

The bottom panel is a live inspector that works **without running the game**: it owns its own peer
on the `files` transport, pointed at the same mailbox, so while Director is playing you can watch
`gGame` move in the editor.

Buttons: **Install autoload**, **Reload config** (re-reads `Bridge.Data.txt`), **Run selftest**
(launches a headless Godot and shows its output).

Command line, which is the protocol spelled directly:

```
get gGame.Cash              read the mirror, show its wire form too
request gGame.Money         cold REQ/RSP read from the movie
set bridge.targetKmh=140.0  CMD write into the replicated store
sets p=v;q=w                several writes in one atomic REQ
watch gGame.kmh             ask for a path to be mirrored from now on
list gGame 1                enumerate the movie's side
call PutMessage {"message":"hi"}   invoke a handler on the `call` list
event BridgePause           raise one of the movie's events
snap off | snap on          stop / start the mirror
status | ping | reload      health
```

## Verifying a port or a change

From the repository root, run `Bridge/tools/test_godot.sh` with Godot 4 on your PATH (or set
`GODOT_BIN` to its executable). It imports the project with the editor, runs the self-test, and
smoke-tests the demo. It also fails if Godot logs a script error despite returning exit code 0.

For a project that has already been imported by the Godot editor, you can run just the self-test:

```
godot --headless --path . --script addons/shockwave_bridge/bridge_selftest.gd
```

Exit code 1 on any failure. It checks, in order: the wire codec (every typed value, both
directions), the Lingo literal parser, config parsing, the **conformance vectors** in
`Bridge.Vectors.txt` — the same table the Lingo side reads and the Python tool generates, so
both implementations can be checked against the same expected values — then two peers in lockstep over an
in-memory transport, the real-filesystem `files` transport including a deliberately torn frame, the
**restart re-arm** (a peer whose `seq` goes backwards after a re-run must still be heard — see
`../PROTOCOL.md` §4 and §8), and finally `gd:` binding against a live node.

The same command works straight out of this repository, because `Bridge/godot/` is itself a project
with the plugin and the autoload already enabled:

```
godot --headless --path Bridge/godot --script addons/shockwave_bridge/bridge_selftest.gd
```

Regenerate the vectors after changing the Python reference:

```
cd ../../tools && python3 bridge_proto.py vectors
```

## Demo

`addons/shockwave_bridge/demo/` holds `bridge_demo.tscn` and `bridge_demo.gd`: a HUD over
`gGame.CurrentVehicle.general.kmh`, buttons that pause the movie and set cash, a store-backed
`targetKmh` autopilot that writes `gGame.CurrentVehicle.Input.*` to drive the car from Godot, a
`list_paths` probe that prints what the movie would answer for a prefix, and a log pane. `F1` pause,
`F2` cash, `F3` probe — the same three calls as the buttons, so you can drive it with the movie
holding focus. `godot --path Bridge/godot` opens it as the main scene of the sample project.

Two flags, after `--`, so it is drivable from a shell and from CI without the Inspector:
`--config <Bridge.Data.txt>` (the same file the movie reads — set the autoload's `config_path` in the
Inspector for the same effect) and `--transport files|http|tcp` (which is `transport_override`).
Against the Python mock, with no Director anywhere:

```sh
mkdir -p ../box && sed "s|^root\t.*|root\t$PWD/../box|" ../Director/Bridge.Data.txt > ../box/Bridge.Data.txt
(cd ../tools && python3 mock_director.py --config ../box/Bridge.Data.txt) &
godot --path . -- --config "$PWD/../box/Bridge.Data.txt"
```

With the default `files` transport and `delta` snapshots, a receiver that starts after the sender can
miss unchanged initial values: the mailbox holds only the latest batch. For now, start Godot before
the sender when testing, or use `request_read()` for a current value. This transport does not yet
guarantee delivery of every intermediate batch.

Both ends now share one mailbox folder and one config; the log pane prints the resolved path, so a
side that is looking at the wrong folder says so in its first line instead of silently showing `VOID`.

## Transports

| | latency | needs | works in a browser movie |
| --- | --- | --- | --- |
| `files` (default) | one frame | a folder both can write | no |
| `http` | one frame, long-polled | Godot listening on `127.0.0.1:7778` | **yes** |
| `tcp` | sub-frame | a socket xtra on the Director side | yes, if the xtra runs there |

`files` is the default because it needs nothing: no ports, no firewall decisions, no xtra, and a
torn read is self-healing by construction. `http` is the one to use for a `._dcr` played through
Shockwave, and is also the easiest to watch with `curl` while you debug.

## Files here, and what they are for

| file | role |
| --- | --- |
| `shockwave_bridge.gd` | the autoload: lifecycle, `gd:` walking, the API above |
| `bridge_peer.gd` | the protocol itself — verbs, ops, snapshot/delta, dedupe, timeouts. Transport-agnostic |
| `bridge_wire.gd` | frame and type codec: `tag:payload`, TAB lines, kv lists |
| `bridge_lingo.gd` | Lingo literal reader/printer (`l:` payloads), which Director parses natively |
| `bridge_config.gd` | `Bridge.Data.txt`, the same TAB data-file format the movie uses |
| `bridge_error.gd` | the one error shape (`code`, `message`) both peers exchange |
| `bridge_transport_files.gd` | the mailbox, with the `.seq` commit marker |
| `bridge_transport_http.gd` | the loopback listener, long-poll + push, hand-rolled HTTP/1.1 |
| `bridge_transport_tcp.gd` | newline-delimited batches over `TCPServer` |
| `bridge_net.gd` | shared socket plumbing: non-blocking reads, line splitting, percent codec |
| `bridge_selftest.gd` | the headless check above |
| `bridge_dock.gd`, `bridge_editor_plugin.gd`, `plugin.cfg` | the editor panel |
| `demo/bridge_demo.gd`, `demo/bridge_demo.tscn` | the runnable scene above; also the `bridge_event` hook example |
| `../project.godot` (one level up) | makes this folder an openable project so the demo and the selftest run from a clone |
| `Bridge.Vectors.txt` | the conformance table, generated — do not hand-edit |
