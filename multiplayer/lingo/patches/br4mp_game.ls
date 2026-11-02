-- =====================================================================
--  br4mp_game.ls  —  Burnin' Rubber 4 online bridge: game glue
--  Movie script (cast member type: Movie Script). Requires br4mp_config.ls
--  and br4mp_net.ls, or use the single-file build br4mp_bridge.ls.
--
--  This is the only file with game-specific code. It reads the local car
--  that "[PS] Advanced Car.ls enterFrame" already simulates, sends its
--  transform to the server, and keeps a list of remote cars in the 3D
--  scene. Nothing here reimplements physics: the local car stays
--  authoritative, the server only validates it.
--
--  The two accessors marked ADAPT are the only places that assume a
--  particular build of the movie. Everything else uses the text protocol.
-- =====================================================================

global gBR4MP

-- ── ADAPT: local car accessors ─────────────────────────────────────────
-- These four handlers are the only build-specific code in the bridge.
-- Each one is a single expression on purpose: probing for different
-- property layouts with `if x.prop <> VOID` raises "property not found"
-- on script objects in Lingo, so edit the expression instead of guessing.

-- The object the hover physics drives in [PS] Advanced Car.ls.
on BR4MPLocalCar
  return gGame.me.car
end

-- The car's transform in world space (metres, Z-up).
on BR4MPLocalTransform
  return BR4MPLocalCar().transform
end

-- Heading in radians. The physics keeps the car upright, so a single yaw
-- around Z is enough for the wire (rx=ry=0). If your build stores the
-- heading in degrees on the script object, use:
--     return gGame.me.angle * pi() / 180
on BR4MPLocalYaw
  pRot = BR4MPLocalTransform().rotation
  if ilk(pRot) = #vector then return pRot.z * pi() / 180
  if ilk(pRot) = #propList then return 2 * BR4MPAtan2(pRot.z, pRot.w)
  return 0
end

-- Ground speed in m/s, as the speedometer uses it.
on BR4MPLocalSpeed
  return gGame.me.speed
end

-- Velocity in m/s; only used as advisory info in the snapshot.
on BR4MPLocalVelocity
  pVel = gBR4MP.localVel
  if ilk(pVel) = #vector then return pVel
  return vector(0, 0, 0)
end

on BR4MPLocalHealth
  return gGame.me.health
end

-- ── per-frame entry point (call from a movie script enterFrame) ────────
on BR4MPGameFrame
  BR4MPEnsure
  if not BR4MPActive() then return
  BR4MPFrame                       -- transport pump (br4mp_net.ls)
  BR4MPUplink
  BR4MPPingIfDue
  BR4MPAnimateRemotes
  BR4MPUpdateStatus
end

on BR4MPUplink
  BR4MPEnsure
  if the milliseconds - gBR4MP.stateSent < (1000 / gBR4MP.stateHz) then return
  gBR4MP.stateSent = the milliseconds

  pTransform = BR4MPLocalTransform()
  pPos = pTransform.position
  pVel = BR4MPLocalVelocity()
  pYaw = BR4MPLocalYaw()
  gBR4MP.localVel = pVel
  gBR4MP.seq = gBR4MP.seq + 1

  pLine = "STATE|s=" & string(gBR4MP.seq) & ¬
          ",ack=" & string(gBR4MP.ackTick) & ¬
          ",f=0" & ¬
          ",px=" & BR4MPFixed(pPos.x) & ",py=" & BR4MPFixed(pPos.y) & ",pz=" & BR4MPFixed(pPos.z) & ¬
          ",rx=0,ry=0" & ¬
          ",rz=" & BR4MPFixed(sin(pYaw / 2)) & ",rw=" & BR4MPFixed(cos(pYaw / 2)) & ¬
          ",vx=" & BR4MPFixed(pVel.x) & ",vy=" & BR4MPFixed(pVel.y) & ",vz=" & BR4MPFixed(pVel.z) & ¬
          ",h=" & string(round(BR4MPLocalHealth())) & ¬
          ",l=" & string(gBR4MP.lap) & ",c=" & string(gBR4MP.cp) & ¬
          ",sp=" & string(round(BR4MPLocalSpeed()))
  BR4MPSendLine(pLine)
end

on BR4MPFixed pValue
  return string(round(pValue * 100) / 100.0)
end

on BR4MPPingIfDue
  BR4MPEnsure
  if the milliseconds - gBR4MP.lastPing < gBR4MP.pingMs then return
  gBR4MP.lastPing = the milliseconds
  gBR4MP.pingSentAt = the milliseconds
  gBR4MP.pingId = gBR4MP.pingId + 1
  BR4MPSendLine("PING|n=" & string(gBR4MP.pingId) & ",ct=" & string(the milliseconds))
end

-- ── snapshot entries ───────────────────────────────────────────────────
on BR4MPGameSnapshotEntry pBody
  BR4MPEnsure
  pId = BR4MPNum(pBody, "i")
  if pId = gBR4MP.playerId then return          -- that's us; the local car wins

  pMask = BR4MPNum(pBody, "m")
  pRemote = gBR4MP.remotes[pId]
  if pRemote = VOID then
    pRemote = [#id: pId, #pos: vector(0, 0, 0), #shown: VOID, #yaw: 0, ¬
               #health: 100, #speed: 0, #seenAt: the milliseconds, #mesh: VOID]
    gBR4MP.remotes[pId] = pRemote
  end if

  if bitAnd(pMask, 1) then
    pRemote.pos = vector(BR4MPNum(pBody, "px"), BR4MPNum(pBody, "py"), BR4MPNum(pBody, "pz"))
    if pRemote.shown = VOID then pRemote.shown = pRemote.pos
  end if
  if bitAnd(pMask, 2) then
    pQZ = BR4MPNum(pBody, "rz")
    pQW = BR4MPNum(pBody, "rw")
    if pQW = 0 and pQZ = 0 then
      pRemote.yaw = 0
    else
      pRemote.yaw = 2 * BR4MPAtan2(pQZ, pQW)
    end if
  end if
  if bitAnd(pMask, 8) then pRemote.health = BR4MPNum(pBody, "h")
  if bitAnd(pMask, 64) then pRemote.speed = BR4MPNum(pBody, "sp")
  pRemote.seenAt = the milliseconds
  BR4MPGameRemoteSpawn(pRemote)
end

-- ── ADAPT: remote car meshes ───────────────────────────────────────────
-- Default implementation: ask the movie for a car model through the same
-- routine the traffic system uses. If your build has no such routine,
-- create a clone of the player car here and return it.
on BR4MPGameRemoteSpawn pRemote
  if pRemote.mesh <> VOID then return pRemote.mesh
  -- ADAPT: create (or borrow from the traffic pool) a car model for this
  -- opponent, store it in pRemote.mesh and return it. Example for a movie
  -- whose traffic system exposes a spawner:
  --     pRemote.mesh = gGame.world.SpawnTrafficCar(pRemote.id)
  --     return pRemote.mesh
  -- Returning VOID is safe: the roster, chat and race logic keep working,
  -- the opponent is just not drawn.
  return VOID
end

on BR4MPAnimateRemotes
  BR4MPEnsure
  pIds = gBR4MP.remotes.getPropList()
  pNow = the milliseconds
  repeat with i = 1 to pIds.count
    pId = pIds[i]
    pRemote = gBR4MP.remotes[pId]
    if pRemote <> VOID then
      if pNow - pRemote.seenAt > 4000 then
        -- silent for 4 s: hide the car but keep the roster entry
        BR4MPHideRemote(pRemote)
      else
        -- snapshots arrive at 20 Hz; ease the rendered car towards the last
        -- authoritative position so it looks smooth at 30/60 fps
        if pRemote.shown = VOID then pRemote.shown = pRemote.pos
        pRemote.shown = BR4MPLerp(pRemote.shown, pRemote.pos, 0.35)
        if pRemote.mesh <> VOID then pRemote.mesh.visible = TRUE
        BR4MPPlaceRemote(pRemote)
      end if
    end if
  end repeat
end

on BR4MPPlaceRemote pRemote
  if pRemote.mesh = VOID then return
  pMesh = pRemote.mesh
  pMesh.transform.position = pRemote.shown
  pMesh.transform.rotation = vector(0, 0, pRemote.yaw)
end

on BR4MPHideRemote pRemote
  if pRemote.mesh = VOID then return
  pRemote.mesh.visible = FALSE
end

-- Lingo has no two-argument atan; this is the usual quadrant fix-up.
on BR4MPAtan2 pY, pX
  if pX > 0 then return atan(pY / pX)
  if pX < 0 and pY >= 0 then return atan(pY / pX) + pi()
  if pX < 0 and pY < 0 then return atan(pY / pX) - pi()
  if pX = 0 and pY > 0 then return pi() / 2
  if pX = 0 and pY < 0 then return -pi() / 2
  return 0
end

on BR4MPLerp pTarget, pToward, pAlpha
  if ilk(pTarget) <> #vector then return pToward
  if ilk(pToward) <> #vector then return pTarget
  return pTarget + (pToward - pTarget) * pAlpha
end

-- ── callbacks from br4mp_net.ls ────────────────────────────────────────
on BR4MPGameJoined pRoomId, pTrackId
  BR4MPEnsure
  gBR4MP.roomId = pRoomId
  gBR4MP.trackId = pTrackId
  gBR4MP.remotes = [:]
  gBR4MP.statusText = "Joined " & pRoomId
end

on BR4MPGamePlayerJoin pPlayer
  -- roster is kept in gBR4MP.players by the transport; a chat notice is nice
  BR4MPShowChat("SYSTEM", pPlayer.name & " joined.", 2)
end

on BR4MPGamePlayerLeave pId
  BR4MPEnsure
  pRemote = gBR4MP.remotes[pId]
  if pRemote <> VOID then
    if pRemote.mesh <> VOID then pRemote.mesh.visible = FALSE
    gBR4MP.remotes.deleteProp(pId)
  end if
end

on BR4MPGameChat pName, pText, pChannel
  BR4MPShowChat(pName, pText, pChannel)
end

on BR4MPGameRaceState pPhase, pLap, pTotalLaps, pCountdownMs
  gBR4MP.phase = pPhase
  gBR4MP.lap = pLap
  gBR4MP.totalLaps = pTotalLaps
  gBR4MP.countdownMs = pCountdownMs
  if pPhase = 1 then
    BR4MPShowChat("SYSTEM", "Starting in " & string(pCountdownMs div 1000 + 1) & "...", 2)
  else if pPhase = 2 then
    BR4MPShowChat("SYSTEM", "GO!", 2)
  end if
end

on BR4MPGameStanding pId, pLap, pCp, pFinished, pFinishMs
  BR4MPEnsure
  -- keep a simple table the HUD can draw; index 1 = leader
  gBR4MP.standings.add([#id: pId, #lap: pLap, #cp: pCp, #finished: pFinished, #timeMs: pFinishMs])
end

on BR4MPGameEvent pEvent, pActor, pTarget, pValue, pPos
  case pEvent of
    5: BR4MPShowChat("SYSTEM", BR4MPPlayerName(pActor) & " respawned.", 2)
    4:
      BR4MPShowChat("SYSTEM", BR4MPPlayerName(pTarget) & " was destroyed by " & BR4MPPlayerName(pActor) & ".", 2)
    9: BR4MPShowChat("SYSTEM", "GO!", 2)
    10: BR4MPShowChat("SYSTEM", "Lap in " & string(pValue / 1000.0) & "s", 2)
    11: BR4MPShowChat("SYSTEM", BR4MPPlayerName(pActor) & " finished!", 2)
    16: gBR4MP.invitedRoom = pValue
    17: -- pickup respawned: nothing to do, the world model already shows it
  end case
end

on BR4MPGameCorrection pReason, pPos, pRot
  -- Trust the server: reason 1/2 (respawn / race start) are authoritative
  -- teleports, reason 0 is the anti-cheat pulling us back.
  BR4MPLocalTransform().position = vector(pPos[1], pPos[2], pPos[3])
  if pReason = 0 then
    BR4MPShowChat("SYSTEM", "Position corrected by the server.", 2)
  end if
end

on BR4MPGameError pCode, pMessage
  gBR4MP.lastError = pMessage
  BR4MPShowChat("SYSTEM", "Error " & string(pCode) & ": " & pMessage, 2)
end

-- ── public API for the original UI ─────────────────────────────────────
on BR4MPChat pText
  BR4MPEnsure
  if not BR4MPActive() then return
  if pText = "" then return
  BR4MPSendNow("CHAT|ch=0,x=" & BR4MPEncode(pText))
end

on BR4MPAction pAction
  BR4MPEnsure
  BR4MPSendLine("ACTION|a=" & string(pAction) & ",t=0,arg=0")
end

on BR4MPHit pTargetId, pWeapon, pPos
  BR4MPEnsure
  BR4MPSendLine("HIT|t=" & string(pTargetId) & ",w=" & string(pWeapon) & ¬
                ",px=" & BR4MPFixed(pPos[1]) & ",py=" & BR4MPFixed(pPos[2]) & ",pz=" & BR4MPFixed(pPos[3]) & ¬
                ",ct=" & string(the milliseconds) & ",d=0")
end

on BR4MPAcceptInvite
  BR4MPEnsure
  if gBR4MP.invitedRoom = 0 then return
  BR4MPSendNow("ACTION|a=6,t=0,arg=" & string(gBR4MP.invitedRoom))
end

on BR4MPPlayerName pId
  BR4MPEnsure
  pPlayer = gBR4MP.players[pId]
  if pPlayer = VOID then return "#" & string(pId)
  return pPlayer.name
end

-- ── HUD ────────────────────────────────────────────────────────────────
on BR4MPShowChat pName, pText, pChannel
  BR4MPEnsure
  gBR4MP.chat.add([#name: pName, #text: pText, #channel: pChannel])
  if gBR4MP.chat.count > 8 then gBR4MP.chat.deleteAt(1)
  if gBR4MP.chatMember <> VOID then
    pMember = gBR4MP.chatMember
    pMember.text = pName & ": " & pText
  end if
end

on BR4MPChatMember pMember
  -- Pass the text member that should show the newest line.
  gBR4MP.chatMember = pMember
end

on BR4MPUpdateStatus
  BR4MPEnsure
  pPhaseName = ["LOBBY", "COUNTDOWN", "RACING", "FINISHING", "RESULTS"]
  pName = pPhaseName[gBR4MP.phase + 1]
  if pName = VOID then pName = "—"
  gBR4MP.statusText = gBR4MP.roomId & " · " & pName & ¬
                      " · lap " & string(gBR4MP.lap) & "/" & string(gBR4MP.totalLaps) & ¬
                      " · " & string(gBR4MP.players.count) & "p" & ¬
                      " · " & string(gBR4MP.rttMs) & "ms"
end

on BR4MPStatusText
  BR4MPEnsure
  return gBR4MP.statusText
end
