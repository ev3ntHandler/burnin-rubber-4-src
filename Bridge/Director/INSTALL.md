# Installing the bridge into the Director movie

This is the Director half of the bridge. Three movie scripts and one data file. Nothing else in
the game changes, and nothing is required to be installed: no Xtra, no extension, no server.

Read `../PROTOCOL.md` when you want to know *why* something is the way it is; this file only tells
you where to click.

---

## 1. Import the three scripts

Copy these into your movie as **movie scripts** (Script type: Movie), keeping the names — the
bridge looks its own scripts up by name in one place, and the game's own convention is that a
movie-wide handler lives in an `[M]` script:

| File | Import as | Provides |
| --- | --- | --- |
| `[M] Shockwave Bridge.ls` | `[M] Shockwave Bridge` | `on enterFrame`, config, wire codec, path resolution, mirror + store |
| `[M] Shockwave Bridge Transport.ls` | `[M] Shockwave Bridge Transport` | the `files` / `http` / `tcp` transports, disk access |
| `[M] Shockwave Bridge RPC.ls` | `[M] Shockwave Bridge RPC` | message dispatch, the ops Godot may call, your API |

They are all movie scripts in one global namespace, so the order of import does not matter — but
**do not** put them in a behaviour script: `on enterFrame` must fire on the movie's own frame, not
on a sprite that may be off-stage.

`Bridge.Data.txt` and `Bridge.Vectors.txt` live in this folder. Import them as **Text cast
members** named `Bridge.Data` and `Bridge.Vectors`, or leave them on disk: the bridge tries the
member first (that is how this movie reads every other data file) and falls back to
`_movie.path & "Bridge\Bridge.Data.txt"`, then `_movie.path & "Bridge.Data.txt"`.

## 2. Decide how it reaches the disk (or doesn't)

The default transport is `files`: a shared folder both programs read and write. That needs real
file access, and Director's depends on how the movie is running:

| Running as | Reads | Writes | Mailbox transport usable? |
| --- | --- | --- | --- |
| Director editor (`.dir` open) | yes | yes | **yes** — this is the development setup |
| Projector (`.exe`/`.app`) | yes | yes | **yes** |
| Projector + `FileXtra4` | yes | yes | yes, and it can also create the mailbox folder |
| Browser / `._dcr` via Shockwave | no | no | **no — use `transport http`** |

A browser movie has no disk access at all, which is not something this bridge can work around; the
`http` transport exists so the same movie still bridges (see step 4).

`FileXtra4` is the xtra `[M] Mods.ls` already uses for mod textures
(`fx = xtra("FileXtra4").new()`), so if your build loads mods, it has it. To use it for the
bridge, add one line to `Bridge.Data.txt`:

```
io	filextra4
```

It is opt-in because calling a method an xtra does not have is a script error in Director, not a
return value — so the bridge would rather you tell it. With FileXtra4 the bridge can create
`BridgeData/` itself; without it, make the folder once (step 3).

## 3. The mailbox folder

Create, next to the movie:

```
BridgeData/
```

Godot creates it on startup when it can (`DirAccess.make_dir_recursive_absolute`), and Director
creates it too when FileXtra4 is available. So in practice you only make it by hand if you started
Director first on a projector build without the xtra — and the bridge says so, once, in the Message
window, with the full path it tried:

```
[bridge warn] cannot write D:\games\br4\BridgeData\d2g.txt -- the folder has to exist first
```

Both sides must point at the **same** folder. If your Godot project is not next to the movie, set
an absolute `root` in `Bridge.Data.txt` (and the same absolute path as `bridge.root` in Godot's
autoload or a `Bridge.Data.txt` copy in the Godot project — one file, both peers read it):

```
root	D:\games\burnin-rubber-4\BridgeData
```

What appears in it, once, and no otherwise:

```
BridgeData/d2g.txt   +   d2g.seq     written by Director, read by Godot
BridgeData/g2d.txt   +   g2d.seq     written by Godot, read by Director
```

## 4. Or use `http`, which works everywhere

In Godot: Project ▸ Project Settings ▸ Globals ▸ Autoload, add `shockwave_bridge.gd` as
`ShockwaveBridge`, and in the inspector set **Transport Override** to `http`. The addon listens on
`127.0.0.1:7778`.

In `Bridge.Data.txt`:

```
transport	http
httpHost	127.0.0.1
httpPort	7778
```

Director is the client, so the movie can run anywhere the port is reachable — including in a
browser tab, where it is the only option. One long-poll stays open in each direction, so a value
crosses in about the time of one frame.

Start Godot first, then the movie: Director's poll will report `waiting` until the listener exists,
and picks up on its own when it does.

## 5. Check it, from the Message window

```lingo
BridgeStatusText()
```

```
status waiting  transport files  io projector  peer  "" (0)  frame 12  seq 12/0 ...
```

`status` becomes `up` the frame Godot answers the handshake. Then:

```lingo
BridgeGet(0, "gGame.Cash")              -- the movie's own value, resolved live
BridgeStore(0, "wantBoost", TRUE)       -- reaches Godot on the next frame
BridgeSet(0, "bridge.targetKmh", 140.0) -- writes the replicated store
BridgeSelfTest(0)                       -- codec, against the shared vectors
BridgeRunLoopbackCheck(0)               -- end to end, with no Godot in sight
```

Every one of those handlers takes an explicit `me` first, the way this movie's own
`PutMessage(0, ...)` does, and from the Message window you pass `0` for it like everywhere else.

`BridgeSelfTest(0)` reads `Bridge.Vectors.txt` — the conformance table generated from the reference
implementation — and checks this engine's encoder, decoder and path parser against it.
`BridgeRunLoopbackCheck(0)` then feeds the dispatcher a whole frame and checks the five things a
transport can get wrong: write, read, refusal, store, and a peer restarting under it. They print:

```
BRIDGE SELFTEST: 84 of 84 vectors pass {value=36, message=24, literal=10, kv=6, path=8}
BRIDGE LOOPBACK: pass (write, read, denial, store, restart)
```

If the vectors pass and the peer stays `waiting`, the problem is the mailbox folder or the port, not
the protocol.

## 6. Letting Godot touch the game

`Bridge.Data.txt` ships with a real config for *this* movie: 39 mirrored paths from `gGame`
(`Cash`, `Scene`, `CurrentVehicle.general.kmh`, `CheckPoints.done`, the input flags …), 13 writable
paths (`gGame.Cash`, `gGame.pause`, `gGame.Input.*`, `gGame.tempo` …), the 7 aliases the HUD uses, 10
handler names on `call` and 10 names on `event` — and `eval`, `exec` and `call` **off**, so the handler
list is a list of what you *may* allow, not a hole you forgot to close. `event` is on: the 10 names are
the movie's own lifecycle events (`GameInitialization`, `WorldEnter`, `RaceEnd`, …) plus the bridge's
three, and an inbound event may only raise one of those. Drop the `event` lines and *any* name passes,
which is the `BridgeCheckEvent` default for a single-player game on its own machine.

What to know:

* A path in `expose` is read every snapshot; `ignore` prunes it. Keep it small — that list is the
  frame cost.
* A path in `write` may be set by Godot. Nothing else can be, and the refusal is an `err denied`
  reply, not an error dialog.
* `call` names handlers Godot may invoke. They are called the way `[M] Event Manager` calls
  everything (`_movie.sendSprite(0, #Handler, target, dataList)`), so the handler must be a movie
  handler. `PutMessage` and `LogMessage` are already listed: `BridgeCall` from Godot writes to the
  game's own Message window, which is the fastest way to see a value change while you work.
* `event` names events Godot may raise. It goes through the movie's own `event(0, #Name)`, so it is
  limited to what your data files already raise — and an unknown event is a logged no-op by
  `Event Manager`, never a crash.
* `allowEval TRUE` turns `eval`/`exec` on, which is `value()`/`do()` on strings from the network.
  Off is the correct default; flip it only while debugging, on a machine you own.

## 7. `ResetEngine` and `InitEngine`

`[M] Main.ls`'s `ResetEngine` clears `_movie.actorList` and the timeout list, and the movie
re-initialises state on `#GameInitialization`. The bridge does not use actors or timeouts on the
`files` transport (it runs from `on enterFrame`, which survives), so a reset costs you:

* the mirror, which rebuilds itself on the next frame (no action needed);
* the HTTP poll id, which the bridge re-arms by itself because a dead id simply reports done.

If you write your own timers or actors on top of the bridge, re-arm them from a
`#GameInitialization` handler, the same way the rest of the game does.

## 8. Socket Xtras (`transport tcp`)

`tcp` is for tools, relays, and machines where a shared folder is awkward. Director has no socket
in stock Lingo, so the bridge will not pretend otherwise: with `transport tcp` and no socket
attached it logs

```
[bridge warn] transport `tcp` needs a socket xtra handed to BridgeTcpAttach(xtraInstance) first
```

and sets `status` to `blocked`. Any xtra whose object speaks this shape works:

```lingo
BridgeTcpAttach(xtra("SocketXtra").new())
```

| method the object needs | meaning |
| --- | --- |
| `connect(host, port)` | open, non-blocking is fine |
| `connected()` | TRUE once the link is up |
| `send(text)` | write bytes; returning an error string is tolerated |
| `input()` | all bytes available now, `VOID` when none |

The bridge adds no framing of its own on `tcp` — the stream is newline-delimited batches, exactly
like the file payload — and it holds the unterminated tail of a read until its LF arrives, so a
partial frame is never dispatched.

## 9. Troubleshooting

| Symptom | Almost always |
| --- | --- |
| `status waiting` forever, `files` | the two sides point at different folders, or Godot is not running. Read the path in the warn line; check it exists on both machines' views of the disk |
| `status waiting`, `http` | Godot's autoload is not installed, `Transport Override` is empty (so it followed a `Bridge.Data.txt` that says `files`), or a firewall is on loopback (rare, but Avast/BitDefender on the game partition) |
| `torn` climbing, values arriving anyway | normal: a frame was caught mid-write, and the next one carried it. Only a problem if values stop moving |
| values froze after one side was re-run | should not happen any more: a `HELLO` from a peer whose `seq` went backwards re-arms the reader (§4, §8), which is what makes restarting Godot mid-session safe. If it still looks deaf, `python3 ../tools/bridge_probe.py frames BridgeData` prints the frame that is actually in the mailbox, its marker, and every key in it |
| values arrive but stop at some number | that path is in `expose` but its container was replaced — `gGame.vehicles[3].*` paths go stale if the movie rebuilds the list. Add the parent instead (`gGame.vehicles`) and let Godot read the subtree, or `BridgeWatch` the new path after the rebuild |
| `err denied` in Godot | correct behaviour: the path is not in `expose` (read) or `write` (write) |
| `io none` in `BridgeStatusText()` | browser movie. Use `http` |
| one long pause when the bridge starts | first `newMember(#file)` for the mailbox read; one-time, and only on the read path without FileXtra4 |
| script error mentioning `fileOpen` | your Director build has no projector file API (some Mac builds, and any browser player). Use `io filextra4`, or `http` |

## 10. Uninstalling

Delete the three `[M] Shockwave Bridge*` scripts. Nothing else in the movie refers to them: no
game handler calls into the bridge, the mirror is read-only over `gGame`, and `Bridge.Data.txt` is
inert data. The `BridgeData/` folder can go with them.
