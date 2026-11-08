# Shockwave ⇄ Godot bridge

Real-time, offline, instance-level state sharing between a Macromedia/Adobe Director movie (this
repo's *Burnin' Rubber 4*) and a Godot 4 project. Either side reads the other's live variables every
frame, writes to them, calls handlers on them, and raises events on them — with no web server, no
database, no middleware, and nothing to install beyond Director and Godot.

It is three things that share one wire format:

| part | what it is |
| --- | --- |
| [`Director/`](Director/) | three `[M]` cast-member scripts to import into the movie, plus its config and the generated vectors. `http` needs nothing but the movie; `files` needs a projector (and FileXtra4 if you want the folder created for you); `tcp` needs a socket Xtra. |
| [`godot/addons/shockwave_bridge/`](godot/addons/shockwave_bridge/) | a Godot 4 editor plugin + `ShockwaveBridge` autoload + a demo scene. Drop-in. |
| [`tools/`](tools/) | the Python reference implementation of the wire, two mock peers, the test suite, a `bridge_probe.py` CLI, and the generator for the conformance vectors both engines read. |

The format itself — the byte-level contract, so you can write a fourth endpoint (a Unity side, a
recorder, a bot) — is [`PROTOCOL.md`](PROTOCOL.md). It is normative and complete; the Python in
`tools/` is its reference implementation, and Director, Godot and Python are all conformance-tested
against the same generated vector file ([PROTOCOL.md §8.1](PROTOCOL.md)).

## Why it is shaped like this

* **One message per frame, in both directions.** The bridge never blocks a game loop. Reads come out
  of a mirror that the other side keeps up to date; a write is queued and published with the frame.
  A `REQ`/`RSP` round trip therefore costs one frame each way, and is never a blocking call in
  either engine.
* **The hot path is string concatenation.** Director has no JSON and Lingo string handling is slow, so
  a frame's payload is built with `&` and split with `.item[]` — that is the entire per-frame cost on
  the movie side. The wire is TAB-separated lines for exactly that reason, which is also the format
  this game already uses for its own config (`Globals.txt`, the mods `.txt` files), so `Bridge.Data.txt`
  reads like a file the game already ships.
* **A shared mailbox folder is a real transport.** `BridgeData/d2g.txt` + a `.seq` commit marker needs
  no Xtra, no port, no firewall decision, and works when the two editors are on one machine with no
  network at all. Loopback HTTP long-poll is the lower-latency option and the one that also works in a
  browser-served movie; raw TCP is there for socket Xtras and tooling.
* **Nothing is trusted, including your own game.** Each side publishes an allow-list. A movie exposes
  the paths in `expose`, accepts writes only to `write`, and only invokes handlers named in `call`.
  `eval`/`exec` exist and are off by default. So "the bridge is open on this machine" is not a security
  question, and prototyping damage to your own save state is a config line away from being impossible.

## Five minutes to a live mirror

1. **Director** — import the three `Director/[M] Shockwave Bridge*.ls` files as movie scripts, and
   `Bridge.Data.txt` + `Bridge.Vectors.txt` as text members. Full walkthrough with the io-mode and
   transport decisions: [`Director/INSTALL.md`](Director/INSTALL.md).
2. Pick the mailbox folder in `Bridge.Data.txt` (`root BridgeData`, relative to the movie) and create
   it next to the `.dir`/`.dcr`. Godot creates it too when it starts.
3. **Godot** — copy `godot/addons/shockwave_bridge/` into your project's `addons/`, enable the plugin
   in *Project Settings → Plugins*, add the `ShockwaveBridge` autoload (the bridge's editor dock has a
   button that does both for you). Details, properties and the API:
   [`godot/README.md`](godot/README.md).
4. Point the addon at the same folder — the `mailbox_base` property, or leave it and let it read
   `Bridge.Data.txt` (one config for both processes is the intent).
5. Run both games. In Godot, `ShockwaveBridge.read_number("gGame.Cash")` is now the movie's `gGame.Cash`,
   updated every frame; `ShockwaveBridge.write_path("bridge.wantBoost", true)` appears in the movie as
   `BridgeGet(0, "bridge.wantBoost")`. `godot --path Bridge/godot` runs the demo scene against the movie:
   six labels mirroring the game, six buttons (and F1/F2/F3) doing the same things to it.

## What it looks like in the two games

Godot, reading the movie and writing back:

```gdscript
func _process(_delta: float) -> void:
	hud.speed.text = "%.0f km/h" % ShockwaveBridge.read_number("gGame.CurrentVehicle.general.kmh")
	ShockwaveBridge.write_path("bridge.nitro", input.is_action_pressed("nitro"))

func _ready() -> void:
	ShockwaveBridge.director_value_changed.connect(_on_movie_value)   # push, instead of polling
	ShockwaveBridge.call_director("PutMessage", {"message": "hi from godot"})
	ShockwaveBridge.bind_node(hud.score_label, "Score")               # now: "gd:Score.text"
```

Director, doing the same the other way round — same semantics, Lingo spelling, and shaped like this
game's own handlers (`PutMessage(0, …)` style: `me` is an explicit first argument):

```lingo
on exitFrame me
  --  a read out of the mirror costs nothing, so there is no reason to batch them up
  if BridgeGet(0, "bridge.wantPause") = 1 then
    gGame.pause = 1
  end if
  --  and something the game has no variable for goes where both sides can see it
  BridgeStore(0, "kmh", gGame.CurrentVehicle.general.kmh)
end

on BridgePause me
  --  Godot raised `event BridgePause`, a name on the `event` list in Bridge.Data.txt. The movie's
  --  own keys reach the same handler, because input here is data: a row in gGame.Keys.KeyEvent maps
  --  a key to an event name, so "P pauses" is a config line in a level file, not a new script.
  gGame.pause = 1
end
```

A mirrored value can also be *bound* to a node with no code at all (`bindings` export:
`Speed = HUD/SpeedLabel`), which Director then reads — and writes — as `gd:Speed.text`, any property of
that node being addressable that way.

## Verify

Nothing here asks you to believe a screenshot. Four commands, from the repository root:

```sh
python3 Bridge/tools/test_bridge.py                    # 140 checks: both mock peers over files,
                                                         # http and tcp, including a restarted peer
python3 Bridge/tools/bridge_proto.py selftest          # the codec, against Bridge.Vectors.txt
python3 Bridge/tools/bridge_probe.py selftest          # codec + vectors + a live two-peer loopback
python3 Bridge/tools/lint_lingo.py Bridge/Director     # Lingo structure, and none of the bridge's
                                                         # 137 handlers colliding with the movie's 759
```

In Godot: `godot --headless --path Bridge/godot --script addons/shockwave_bridge/bridge_selftest.gd`
(exits non-zero on failure, so it is a CI step). In Director's Message window: `BridgeSelfTest(0)` (84
vectors), then `BridgeRunLoopbackCheck(0)` — an end-to-end write, read, denial, store and restart test
that passes with no Godot running at all, which is what makes it useful for the "whose fault is this"
question at 1 a.m.

When a link misbehaves, `bridge_probe.py` is the third end: it speaks the same wire from a shell, and it
is what a CI job runs against a recorded mailbox.

```sh
python3 Bridge/tools/bridge_probe.py frames Bridge/Director/BridgeData   # decode a mailbox, offline
python3 Bridge/tools/bridge_probe.py get gGame.Cash --as godot           # one REQ/RSP round trip
python3 Bridge/tools/bridge_probe.py status --transport files --root Bridge/Director/BridgeData
python3 Bridge/tools/bridge_probe.py watch gGame.CurrentVehicle.general.kmh --hz 20
```

## Choosing a transport

| | `files` (default) | `http` | `tcp` |
| --- | --- | --- | --- |
| one-way latency | ≤ 1 frame | ~0.3 ms | ~0.1 ms |
| needs an Xtra in Director | no | no | yes (a socket Xtra) |
| works in a browser-served movie | no (no disk) | yes | no |
| needs a free port / firewall decision | no | loopback only | loopback only |
| survives one side being killed mid-frame | yes (commit marker) | yes | yes (framed by LF) |
| good for | two editors on one machine, CI | the usual choice for real play | relays, external tools, bots |

Change one line — `transport http` in `Bridge.Data.txt` — and both sides follow, because both read the
same file. The Godot side can override it for the editor session without touching the config.

## Layout

```
Bridge/
├── PROTOCOL.md                      the normative wire format (v1), incl. §8.1 conformance
├── Director/
│   ├── [M] Shockwave Bridge.ls      config, mirror, hooks, the movie-facing API
│   ├── [M] Shockwave Bridge Transport.ls   files / http, io modes, the frame marker
│   ├── [M] Shockwave Bridge RPC.ls  verbs, ops, allow-lists, RSP plumbing, selftests
│   ├── Bridge.Data.txt              39 expose, 13 write, 7 alias, 10 call, transport config
│   ├── Bridge.Vectors.txt           generated conformance table (do not hand-edit)
│   └── INSTALL.md                   import, io modes, mailbox, allow-lists, troubleshooting
├── godot/
│   ├── project.godot                a sample project so the demo + selftest run from this repo
│   ├── README.md                    the addon's properties, API, dock, demo
│   └── addons/shockwave_bridge/     the addon: 13 scripts, plugin.cfg, demo/
└── tools/
    ├── bridge_proto.py              codec + vectors: the reference implementation
    ├── bridge_peer.py               both peers' shared state machine
    ├── bridge_transports.py         files / http / tcp
    ├── bridge_config.py             Bridge.Data.txt, the one config both processes read
    ├── bridge_values.py             typed values, paths, Lingo literals
    ├── mock_director.py             a gGame-shaped fake movie (from this repo's Globals.txt)
    ├── mock_godot.py                a Godot-shaped fake peer, `gd:` binding included
    ├── bridge_probe.py              the CLI: get / set / call / event / list / watch / frames / …
    ├── test_bridge.py               140 checks over all three transports
    └── lint_lingo.py                structure linter for Lingo, used on 155 real movie scripts too
```

## What it will not do

* **It is not a save-game bridge.** Values live in memory and stop when the process does. There is a
  `snapshot` op for reading a whole state at a moment and a store both sides can persist from, but
  nothing here writes your `gGame` back into the movie's own save format.
* **It cannot see what the movie does not name.** The mirror is paths, and a path needs a global this
  game actually keeps (`gGame`, `gSystem`, `gData`, plus `alias` lines for the awkward ones). Anything
  living only inside a sprite's instance variables needs one `BridgeSet` line in that sprite to join.
* **Strings lose TAB, CR and LF** — by design: they are the framing bytes, and flattening them beats
  inventing an escape Lingo has to agree with (§1). Everything else round-trips byte for byte, which is
  what the vectors check.
* **Shockwave in a browser can talk to your machine, not your disk.** The `files` transport is out;
  `http` works, and a page served over `https` will refuse loopback mixed content, so a projector is
  the honest target for anything that uses this locally.
* **A frame is the unit of latency, by choice.** If you need sub-millisecond *replies* rather than
  sub-millisecond *state*, the `http` transport gets you there; a 30 fps movie cannot answer faster
  than its own loop, and no protocol trick changes that.
