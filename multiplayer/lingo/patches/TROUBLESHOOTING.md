# Lingo bridge — troubleshooting

The two errors below are the ones you hit while wiring the bridge into the movie. Both are
fixed in **v1.1** (this directory). If you copied the scripts before v1.1, replace them — or
paste the single-file build `br4mp_bridge.ls` instead of the three separate members.

---

## `handler not defined gBR4MP.active = FALSE (#Active)`

Full message:

```
Script error: handler not defined
gBR4MP.active = FALSE
(#Active)
```

**Cause: `gBR4MP` is not a property list.** v1.0 initialised it with

```lingo
gBR4MP = gBR4MP or [:]      -- WRONG
```

`or` in Lingo is a boolean / bitwise operator, not a null-coalescing one: with `gBR4MP` unset
that line evaluates to `TRUE` (1). Every later `gBR4MP.active` is then read as "call handler
`#Active` on the integer 1", which is exactly the error above.

Nothing is wrong with the rest of your install — this fails on the first line of
`BR4MPDefaults`, before any networking happens.

**Fix (v1.1):**

```lingo
on BR4MPEnsure
  if ilk(gBR4MP) <> #propList then
    gBR4MP = [:]
    BR4MPResetProps
  end if
  return gBR4MP
end

on BR4MPActive
  if ilk(gBR4MP) <> #propList then return FALSE
  return gBR4MP.active = TRUE
end
```

Sanity check in the Message window:

```lingo
put ilk(gBR4MP)          -- must be #propList
put BR4MPDiagnostics()   -- repairs a damaged global and prints the state
```

If you cannot replace the files right now, the minimal surgical patch to the old member is:

```lingo
-- replace: gBR4MP = gBR4MP or [:]
if ilk(gBR4MP) <> #propList then
  gBR4MP = [:]
end if
```

Other causes of the same message, for completeness:

* another script assigns `gBR4MP` to something else (`gBR4MP = TRUE`, a list, a script object);
* `gBR4MP` was used inside a **parent/behavior script** where a local variable shadows the
  global — declare `global gBR4MP` at the top of every script that touches it;
* `voidP(gBR4MP)` guards (v1.0) do **not** help: `voidP(1)` is FALSE, so the guard passes and
  the `.active` lookup still explodes.

---

## `handler not defined #BR4MPGameFrame`

The call is fine; Director cannot find the handler. In Lingo only handlers in a **movie
script** are global — a handler pasted into a Behavior or a Parent script is not visible from
`[PS] Advanced Car.ls` or from other scripts.

Check these, in order:

1. **Cast member type.** Select the member that holds `br4mp_game.ls` and look at the Script
   window's script type popup. It must read **Movie Script**. If it says *Behavior* or
   *Parent*, create a new member with `File → New → Cast Member → Script`, set its type to
   Movie Script, and paste again.
2. **The member is not part of the movie.** A script in an external cast that is not loaded (or
   not ticked *Include in Shockwave* when publishing a `.dcr`) is simply absent at runtime. The
   safest place is the movie's internal cast. In a published `.dcr`, open the cast member's
   properties and tick **Include in Shockwave**.
3. **The script does not compile.** A syntax error anywhere in the member disables *all* of its
   handlers. Reopen the member (this forces a recompile) and watch for an error dialog; the
   Message window also reports it. Common paste damage: the `¬` continuation character lost its
   place (it must be the **last** character on the line, with nothing after it), or smart quotes
   replaced `"`.
4. **Mixed versions.** v1.1 handlers call `BR4MPEnsure`, which v1.0 does not have. If you see
   `handler not defined #BR4MPEnsure`, some members are still v1.0 — replace all of them, or use
   the single file.
5. **Wrong call site.** `BR4MPGameFrame` must run once per frame. A movie script
   `on enterFrame` or the end of the `[PS] Advanced Car.ls` `enterFrame` handler both work; the
   same call placed inside `prepareFrame`, a `repeat` loop or a button handler will not.

### Fastest way to get unblocked

Paste **`br4mp_bridge.ls`** into one Movie Script member. It contains configuration, transport
and game glue in a single script, so there is exactly one member to place and one to include in
the build, and no cross-member handler resolution to go wrong.

Then, from the Message window:

```lingo
put BR4MPDiagnostics()        -- prints ilk, version, URL, token, room, error, ...
put BR4MPStart(0, 0, "")      -- free roam, City
-- after a second or so:
put BR4MPStatusText()         -- "roam-w0-1 · LOBBY · lap 0/1 · 2p · 12ms"
```

If `BR4MPDiagnostics()` itself is not defined, the config member is not in the movie at all —
go back to point 1.

---

## Other messages you may hit while bringing it up

| Message | Meaning |
| --- | --- |
| `handler not defined #BR4MPConnect` | the transport member (`br4mp_net.ls`) is missing or not a Movie Script |
| `handler not defined #BR4MPEnsure` | mixed v1.0 / v1.1 members — replace them all or use `br4mp_bridge.ls` |
| `Property not found` | one of the four ADAPT accessors in `br4mp_game.ls` reads a property your build does not have; edit that single expression |
| `Error 11: ...` / `ERR|c=11` on connect | server connect bucket exhausted (usually a proxy opening a new connection per poll) |
| `ERR|c=1` | protocol version mismatch — send `v=1` in `CONNECT` |
| `ERR|c=3` after a while | the 60 s resume window expired; call `BR4MPStart(…)` again |
| Cars never appear | `BR4MPGameRemoteSpawn` returns VOID by default — wire it to your traffic car spawner (see README) |
| Cars judder | `BR4MPGameFrame` is not being called every frame, so snapshots arrive in bursts |

## Static checks

The bridge has its own linter, so these mistakes are caught before Director sees them:

```bash
cd multiplayer
npm run check:lingo      # handlers defined, state keys initialised, ¬ placement, bridge in sync
npm run build:lingo      # regenerate br4mp_bridge.ls from the three sources
```

The linter is what caught two `gBR4MP.*` reads (`tickRate`, `localVel`) that would have raised
`Property not found` on first use — the same class of bug as the `#Active` error above.
