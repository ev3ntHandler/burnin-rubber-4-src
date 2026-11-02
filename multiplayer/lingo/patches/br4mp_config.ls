-- =====================================================================
--  br4mp_config.ls  —  Burnin' Rubber 4 online bridge: configuration
--  Movie script (cast member type: Movie Script). Load it before
--  br4mp_net.ls and br4mp_game.ls, or use the single-file build
--  br4mp_bridge.ls instead.
--
--  v1.1 — fixes "handler not defined #Active":
--    `gBR4MP = gBR4MP or [:]` was wrong. Lingo's `or` is a boolean /
--    bitwise operator, so that expression evaluates to TRUE and every
--    later `gBR4MP.active` became a handler lookup on an integer.
--    Initialisation is now `ilk()`-based (see BR4MPEnsure).
-- =====================================================================

global gBR4MP

-- Bump when the script changes; shown by BR4MPDiagnostics.
on BR4MPVersion
  return "1.1"
end

-- ---------------------------------------------------------------------
--  Initialisation
-- ---------------------------------------------------------------------

-- Idempotent: creates gBR4MP if it is missing or damaged, keeps the
-- current session state when it is already a valid property list.
-- Every entry point calls this, so call order never matters.
on BR4MPEnsure
  if ilk(gBR4MP) <> #propList then
    gBR4MP = [:]
    BR4MPResetProps
  end if
  return gBR4MP
end

-- Full reset: wipes session state and writes every key the bridge uses,
-- so no handler ever reads VOID from the property list.
on BR4MPResetProps
  gBR4MP.active = FALSE
  gBR4MP.version = BR4MPVersion()

  -- Point this at the machine running packages/server (no trailing slash).
  -- Shockwave Player may only reach the host it was served from unless a
  -- crossdomain.xml allows more; see docs/06-operations.md.
  gBR4MP.baseURL = "http://localhost:8080"

  -- Identity shown in the roster and chat.
  gBR4MP.playerName = "Racer"
  gBR4MP.vehicle = "PlayerCar"
  gBR4MP.skin = 0

  -- Networking cadence: 20 Hz state uplink, 15 s long-poll hold,
  -- 2.5 s ping, 50 ms send flush.
  gBR4MP.stateHz = 20
  gBR4MP.pollWait = 15
  gBR4MP.pingMs = 2500
  gBR4MP.resumeWindowMs = 60000

  -- Debug: put every parsed protocol line in the Message window.
  gBR4MP.trace = FALSE

  -- Transport handles (0 = no request in flight).
  gBR4MP.connectNet = 0
  gBR4MP.pollNet = 0
  gBR4MP.connectedAt = 0
  gBR4MP.lastFlush = 0
  gBR4MP.lastPing = 0
  gBR4MP.stateSent = 0
  gBR4MP.pingSentAt = 0
  gBR4MP.pingId = 0
  gBR4MP.rttMs = 0
  gBR4MP.tickRate = 20
  gBR4MP.lastError = ""

  -- Session state.
  gBR4MP.token = ""
  gBR4MP.playerId = 0
  gBR4MP.roomId = ""
  gBR4MP.trackId = ""
  gBR4MP.mode = 0
  gBR4MP.worldIndex = 0
  gBR4MP.startTick = 0
  gBR4MP.seq = 0
  gBR4MP.ackTick = 0
  gBR4MP.snapshotTick = 0
  gBR4MP.localVel = vector(0, 0, 0)

  -- Race / HUD state.
  gBR4MP.phase = 0
  gBR4MP.lap = 0
  gBR4MP.cp = 0
  gBR4MP.totalLaps = 1
  gBR4MP.countdownMs = 0
  gBR4MP.statusText = ""

  -- Collections.
  gBR4MP.players = [:]
  gBR4MP.remotes = [:]
  gBR4MP.chat = []
  gBR4MP.standings = []
  gBR4MP.sendQueue = []
  gBR4MP.pendingEntries = []
  gBR4MP.invitedRoom = 0
  gBR4MP.chatMember = VOID
end

-- Full reset, kept for BR4MPStart and for manual recovery.
on BR4MPDefaults
  gBR4MP = [:]
  BR4MPResetProps
  return gBR4MP
end

-- ---------------------------------------------------------------------
--  Public entry points
-- ---------------------------------------------------------------------

-- menu button:  mode 0 = free roam, 1 = race
--               worldIndex 0 City, 1 Desert, 2 Jungle, 3 Industrial, 4 Snow
--               trackId "city-1", "" for free roam
on BR4MPStart mode, worldIndex, trackId
  BR4MPDefaults
  gBR4MP.mode = mode
  gBR4MP.worldIndex = worldIndex
  gBR4MP.trackId = trackId
  gBR4MP.active = TRUE
  gBR4MP.statusText = "Connecting to " & gBR4MP.baseURL & " ..."
  BR4MPConnect
  return gBR4MP.active
end

on BR4MPStop
  BR4MPEnsure
  if gBR4MP.token <> "" then BR4MPSendLine("LEAVE|")
  BR4MPFlush
  gBR4MP.active = FALSE
  gBR4MP.token = ""
  BR4MPCancelPoll
end

on BR4MPActive
  if ilk(gBR4MP) <> #propList then return FALSE
  return gBR4MP.active = TRUE
end

-- ---------------------------------------------------------------------
--  Diagnostics — call this from the Message window after pasting scripts:
--     put BR4MPDiagnostics()
--  It only uses configuration-level state, so it works even when the
--  transport or game scripts are missing.
-- ---------------------------------------------------------------------
on BR4MPDiagnostics
  pWasBroken = FALSE
  if ilk(gBR4MP) <> #propList then
    pWasBroken = TRUE
    put "gBR4MP was " & string(ilk(gBR4MP)) & " (should be #propList) — repairing."
    BR4MPEnsure
  end if

  put "=== br4mp bridge " & BR4MPVersion() & " ==="
  put "gBR4MP ilk      : " & string(ilk(gBR4MP)) & "  (must be #propList)"
  put "baseURL         : " & string(gBR4MP.baseURL)
  put "active          : " & string(gBR4MP.active)
  put "player          : " & string(gBR4MP.playerName) & " / " & string(gBR4MP.vehicle)
  put "token           : " & string(gBR4MP.token)
  put "room            : " & string(gBR4MP.roomId) & "  track=" & string(gBR4MP.trackId)
  put "playerId        : " & string(gBR4MP.playerId)
  put "phase / lap     : " & string(gBR4MP.phase) & " / " & string(gBR4MP.lap) & " of " & string(gBR4MP.totalLaps)
  put "players/remotes : " & string(gBR4MP.players.count) & " / " & string(gBR4MP.remotes.count)
  put "queue / rtt     : " & string(gBR4MP.sendQueue.count) & " / " & string(gBR4MP.rttMs) & " ms"
  put "last error      : " & string(gBR4MP.lastError)

  if pWasBroken then
    put "gBR4MP has been reinitialised. Call BR4MPStart again."
  end if
  put "If gBR4MP ilk is #propList but a BR4MP* handler is missing,"
  put "the script that defines it is not part of the movie: paste the"
  put "member as a Movie Script and tick 'Include in Shockwave' in its"
  put "cast member properties. See TROUBLESHOOTING.md."
  return gBR4MP.statusText
end
