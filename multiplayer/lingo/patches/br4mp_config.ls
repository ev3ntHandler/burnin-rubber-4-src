-- =====================================================================
--  br4mp_config.ls  —  Burnin' Rubber 4 online bridge: configuration
--  Movie script. Loaded before br4mp_net.ls and br4mp_game.ls.
--
--  Everything lives in the global gBR4MP (a property list) so the other
--  two scripts, and the original game scripts, can reach it without
--  passing arguments around.
-- =====================================================================

global gBR4MP

on BR4MPDefaults
  gBR4MP = gBR4MP or [:]
  gBR4MP.active = FALSE

  -- Point this at the machine running packages/server (no trailing slash).
  -- Shockwave Player may only reach the same host it was served from unless
  -- a crossdomain.xml allows more; see docs/06-operations.md.
  gBR4MP.baseURL = "http://localhost:8080"

  -- Identity shown in the roster and chat.
  gBR4MP.playerName = "Racer"
  gBR4MP.vehicle = "PlayerCar"
  gBR4MP.skin = 0

  -- Networking cadence. 20 Hz state uplink, 15 s long-poll hold, 2.5 s ping.
  gBR4MP.stateHz = 20
  gBR4MP.pollWait = 15
  gBR4MP.pingMs = 2500
  gBR4MP.requestTimeoutMs = 25000

  -- Server-side session resume window (must match MP_RESUME_WINDOW_MS).
  gBR4MP.resumeWindowMs = 60000

  -- Debug: trace every parsed line to the message window.
  gBR4MP.trace = FALSE

  -- Runtime state (filled in by br4mp_net.ls / br4mp_game.ls).
  gBR4MP.token = ""
  gBR4MP.playerId = 0
  gBR4MP.roomId = ""
  gBR4MP.trackId = ""
  gBR4MP.mode = 0
  gBR4MP.worldIndex = 0
  gBR4MP.seq = 0
  gBR4MP.ackTick = 0
  gBR4MP.pingId = 0
  gBR4MP.pingSentAt = 0
  gBR4MP.rttMs = 0
  gBR4MP.phase = 0
  gBR4MP.lap = 0
  gBR4MP.totalLaps = 1
  gBR4MP.players = [:]
  gBR4MP.remotes = [:]
  gBR4MP.chat = []
  gBR4MP.statusText = ""
  gBR4MP.lastError = ""
  gBR4MP.sendQueue = []
end

-- Public helper used by the main menu's "Online" button.
--   mode: 0 free roam, 1 race.  worldIndex: 0 City, 1 Desert, 2 Jungle,
--   3 Industrial, 4 Snow.  trackId: "city-1", "" for free roam.
on BR4MPStart mode, worldIndex, trackId
  BR4MPDefaults
  gBR4MP.mode = mode
  gBR4MP.worldIndex = worldIndex
  gBR4MP.trackId = trackId
  gBR4MP.active = TRUE
  gBR4MP.lastError = ""
  BR4MPConnect
  return gBR4MP.active
end

on BR4MPStop
  if voidP(gBR4MP) then return
  if gBR4MP.token <> "" then BR4MPSendLine("LEAVE|")
  gBR4MP.active = FALSE
  gBR4MP.token = ""
  BR4MPCancelPoll
end

on BR4MPActive
  if voidP(gBR4MP) then return FALSE
  return gBR4MP.active
end
