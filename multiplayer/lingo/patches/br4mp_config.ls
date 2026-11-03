-- =====================================================================
--  br4mp_config.ls - Burnin' Rubber 4 online bridge: configuration
--  Movie script (cast member type: Movie Script, internal cast).
--
--  Everything lives in the global gBR4MP (a property list) so the other
--  two scripts, and the original game scripts, can reach it without
--  passing arguments around.
--
--  IMPORTANT - Lingo globals are declared *inside each handler*:
--      on SomeHandler
--        global gBR4MP
--        ...
--      end
--  A single `global gBR4MP` line at the top of a script does NOT make the
--  name global inside its handlers. Without the per-handler declaration,
--  gBR4MP is an unassigned local there and Director reports
--  "variable used before assigned a value". Every handler below declares
--  what it uses, so the error cannot come back when scripts are pasted in
--  any order or split across several cast members.
--
--  Two Lingo rules this file depends on:
--
--  1. `gBR4MP = gBR4MP or [:]` is wrong: `or` is boolean/bitwise, so it
--     yields TRUE and every later gBR4MP.active becomes a handler lookup.
--  2. Dot syntax only *reads or updates existing* properties. Creating a
--     property needs setProp() or bracket syntax - `pList.newKey = x` on a
--     fresh [:] raises "Property not found #newKey". Every key is therefore
--     created below with gBR4MP[#key] = value; the rest of the bridge can
--     then use ordinary dot syntax.
-- =====================================================================

-- Version of the bridge scripts.
on BR4MPVersion
  return "1.1"
end

-- Full (re)initialisation. Writes every key the bridge uses, so no handler
-- ever reads VOID from the property list.
on BR4MPDefaults
  global gBR4MP
  gBR4MP = [:]
  gBR4MP[#version] = BR4MPVersion()
  gBR4MP[#active] = FALSE

  -- Point this at the machine running packages/server (no trailing slash).
  -- Shockwave Player may only reach the host it was served from unless a
  -- crossdomain.xml allows more; see docs/06-operations.md.
  gBR4MP[#baseURL] = "http://localhost:8080"

  -- Identity shown in the roster and chat.
  gBR4MP[#playerName] = "Racer"
  gBR4MP[#vehicle] = "PlayerCar"
  gBR4MP[#skin] = 0

  -- Networking cadence: 20 Hz state uplink, 15 s long-poll hold, 2.5 s ping.
  gBR4MP[#stateHz] = 20
  gBR4MP[#pollWait] = 15
  gBR4MP[#pingMs] = 2500
  gBR4MP[#resumeWindowMs] = 60000

  -- Debug: put every parsed protocol line in the Message window.
  gBR4MP[#trace] = FALSE

  -- Transport handles (0 = no request in flight).
  gBR4MP[#connectNet] = 0
  gBR4MP[#pollNet] = 0
  gBR4MP[#lastFlush] = 0
  gBR4MP[#stateSent] = 0
  gBR4MP[#lastFrameMs] = -1
  gBR4MP[#lastPing] = 0
  gBR4MP[#pingSentAt] = 0
  gBR4MP[#pingId] = 0
  gBR4MP[#rttMs] = 0
  gBR4MP[#lastError] = ""

  -- Session state.
  gBR4MP[#token] = ""
  gBR4MP[#playerId] = 0
  gBR4MP[#roomId] = ""
  gBR4MP[#trackId] = ""
  gBR4MP[#mode] = 0
  gBR4MP[#worldIndex] = 0
  gBR4MP[#startTick] = 0
  gBR4MP[#seq] = 0
  gBR4MP[#ackTick] = 0
  gBR4MP[#snapshotTick] = 0
  gBR4MP[#tickRate] = 20
  gBR4MP[#localVel] = vector(0, 0, 0)

  -- Race / HUD state.
  gBR4MP[#phase] = 0
  gBR4MP[#lap] = 0
  gBR4MP[#cp] = 0
  gBR4MP[#totalLaps] = 1
  gBR4MP[#countdownMs] = 0
  gBR4MP[#statusText] = ""

  -- Collections.
  gBR4MP[#players] = [:]
  gBR4MP[#remotes] = [:]
  gBR4MP[#chat] = []
  gBR4MP[#standings] = []
  gBR4MP[#sendQueue] = []
  gBR4MP[#invitedRoom] = 0
  gBR4MP[#chatMember] = VOID

  return gBR4MP
end

-- Public entry point.  mode: 0 free roam, 1 race
--                     worldIndex: 0 City, 1 Desert, 2 Jungle, 3 Industrial, 4 Snow
--                     trackId: "city-1", "" for free roam
on BR4MPStart mode, worldIndex, trackId
  global gBR4MP
  BR4MPDefaults
  gBR4MP.mode = mode
  gBR4MP.worldIndex = worldIndex
  gBR4MP.trackId = trackId
  gBR4MP.active = TRUE
  gBR4MP.statusText = "Connecting to " & gBR4MP.baseURL
  BR4MPConnect
  return gBR4MP.active
end

-- Entry point for the MenuEvents.txt event system, which dispatches every
-- command as sendSprite(0, #handler, tTarget, tDataList) - i.e. two
-- arguments only. Add this line to the StartGame_*_Begin block (TAB
-- separated, like PutMessage):
--     BR4MPOnline<TAB>0<TAB>[#mode: 0, #world: 0, #track: ""]
on BR4MPOnline me, tTarget, tDataList
  pMode = 0
  pWorld = 0
  pTrack = ""
  pList = tDataList
  if ilk(pList) <> #propList then
    pList = tTarget
  end if
  if ilk(pList) = #propList then
    pValue = getProp(pList, #mode)
    if ilk(pValue) <> #void then
      pMode = pValue
    end if
    pValue = getProp(pList, #world)
    if ilk(pValue) <> #void then
      pWorld = pValue
    end if
    pValue = getProp(pList, #track)
    if ilk(pValue) <> #void then
      pTrack = pValue
    end if
  end if
  return BR4MPStart(pMode, pWorld, pTrack)
end

on BR4MPStop
  global gBR4MP
  if ilk(gBR4MP) <> #propList then
    return
  end if
  if gBR4MP.token <> "" then
    BR4MPSendLine("LEAVE|")
  end if
  BR4MPFlush
  gBR4MP.active = FALSE
  gBR4MP.token = ""
  BR4MPCancelPoll
end

-- TRUE once BR4MPStart has run and the session has not been stopped.
on BR4MPActive
  global gBR4MP
  if ilk(gBR4MP) <> #propList then
    return FALSE
  end if
  -- getProp returns VOID for a missing key instead of raising
  -- "Property not found", so this is safe before BR4MPDefaults has run.
  return getProp(gBR4MP, #active) = TRUE
end

-- ---------------------------------------------------------------------
--  Diagnostics. Call from the Message window after pasting the scripts:
--      put BR4MPDiagnostics()
--  Only uses configuration-level state, so it works even when the
--  transport or game scripts are missing.
-- ---------------------------------------------------------------------
-- Property lists here reject integer keys ("Index out of range"), so the
-- roster and the remote-car table are keyed by symbol: BR4MPKey(14) -> #p14.
on BR4MPKey pId
  return symbol("p" & string(pId))
end

on BR4MPDiagnostics
  global gBR4MP
  if ilk(gBR4MP) <> #propList then
    put "gBR4MP was " & string(ilk(gBR4MP)) & " - reinitialising."
    BR4MPDefaults
  end if
  put "=== br4mp bridge " & BR4MPVersion() & " ==="
  put "ilk(gBR4MP)  : " & string(ilk(gBR4MP)) & "   (must be #propList)"
  put "baseURL      : " & string(gBR4MP.baseURL)
  put "active       : " & string(gBR4MP.active)
  put "player       : " & string(gBR4MP.playerName)
  put "token        : " & string(gBR4MP.token)
  put "room / track : " & string(gBR4MP.roomId) & " / " & string(gBR4MP.trackId)
  put "playerId     : " & string(gBR4MP.playerId)
  put "phase / lap  : " & string(gBR4MP.phase) & " / " & string(gBR4MP.lap)
  put "players      : " & string(gBR4MP.players.count)
  put "queue / rtt  : " & string(gBR4MP.sendQueue.count) & " / " & string(gBR4MP.rttMs)
  put "last error   : " & string(gBR4MP.lastError)
  return gBR4MP.statusText
end
