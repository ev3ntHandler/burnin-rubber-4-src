-- =====================================================================
--  br4mp_game.ls - Burnin' Rubber 4 online bridge: game glue
--  Movie script (cast member type: Movie Script, internal cast).
--
--  This is the only file with game-specific code. It reads the local car
--  that "[PS] Advanced Car.ls enterFrame" already simulates, sends its
--  transform to the server, and keeps a list of remote cars in the 3D
--  scene. Nothing here reimplements physics: the local car stays
--  authoritative, the server only validates it.
--
--  Every handler declares the globals it uses (gBR4MP, and gGame for the
--  accessors) - see the note in br4mp_config.ls. There are no line
--  continuations in this file, so a mangled continuation character on
--  paste cannot break the compile.
-- =====================================================================

-- ---------------------------------------------------------------------
--  ADAPT: local car accessors
--  These six handlers are the only build-specific code in the bridge.
--  Each is a single expression on purpose: probing for alternative
--  property layouts with `if x.prop <> VOID` raises "Property not found"
--  on script objects in Lingo, so edit the expression instead.
-- ---------------------------------------------------------------------

-- The object the hover physics drives.
on BR4MPLocalCar
  global gGame
  return gGame.me.car
end

-- Its transform in world space (metres, Z-up).
on BR4MPLocalTransform
  global gGame
  return gGame.me.car.transform
end

-- Heading in radians. The physics keeps the car upright, so one yaw
-- around Z is enough for the wire (rx=ry=0). If your build stores the
-- heading in degrees, use:  return gGame.me.angle * pi() / 180
on BR4MPLocalYaw
  pRot = BR4MPLocalTransform().rotation
  if ilk(pRot) = #vector then return pRot.z * pi() / 180
  if ilk(pRot) = #propList then return 2 * BR4MPAtan2(pRot.z, pRot.w)
  return 0
end

-- Ground speed in m/s, as the speedometer uses it.
on BR4MPLocalSpeed
  global gGame
  return gGame.me.speed
end

-- Health, 0..100. Only free roam changes it.
on BR4MPLocalHealth
  global gGame
  return gGame.me.health
end

-- Velocity in m/s. Advisory only (the server derives ram damage from its
-- own history); set gBR4MP.localVel if you want it on the wire.
on BR4MPLocalVelocity
  global gBR4MP
  if ilk(gBR4MP.localVel) = #vector then return gBR4MP.localVel
  return vector(0, 0, 0)
end

-- ---------------------------------------------------------------------
--  per-frame entry point - call BR4MPGameFrame() once per frame
-- ---------------------------------------------------------------------
on BR4MPGameFrame
  if not BR4MPActive() then return
  BR4MPFrame
  BR4MPUplink
  BR4MPPingIfDue
  BR4MPAnimateRemotes
  BR4MPUpdateStatus
end

on BR4MPUplink
  global gBR4MP
  pNow = the milliseconds
  if pNow - gBR4MP.stateSent < (1000 / gBR4MP.stateHz) then return
  gBR4MP.stateSent = pNow

  pPos = BR4MPLocalTransform().position
  pVel = BR4MPLocalVelocity()
  pYaw = BR4MPLocalYaw()
  gBR4MP.seq = gBR4MP.seq + 1

  pLine = "STATE|s=" & string(gBR4MP.seq)
  pLine = pLine & ",ack=" & string(gBR4MP.ackTick)
  pLine = pLine & ",f=0"
  pLine = pLine & ",px=" & BR4MPFixed(pPos.x)
  pLine = pLine & ",py=" & BR4MPFixed(pPos.y)
  pLine = pLine & ",pz=" & BR4MPFixed(pPos.z)
  pLine = pLine & ",rx=0,ry=0"
  pLine = pLine & ",rz=" & BR4MPFixed(sin(pYaw / 2))
  pLine = pLine & ",rw=" & BR4MPFixed(cos(pYaw / 2))
  pLine = pLine & ",vx=" & BR4MPFixed(pVel.x)
  pLine = pLine & ",vy=" & BR4MPFixed(pVel.y)
  pLine = pLine & ",vz=" & BR4MPFixed(pVel.z)
  pLine = pLine & ",h=" & string(round(BR4MPLocalHealth()))
  pLine = pLine & ",l=" & string(gBR4MP.lap)
  pLine = pLine & ",c=" & string(gBR4MP.cp)
  pLine = pLine & ",sp=" & string(round(BR4MPLocalSpeed()))
  BR4MPSendLine(pLine)
end

on BR4MPFixed pValue
  return string(round(pValue * 100) / 100.0)
end

on BR4MPPingIfDue
  global gBR4MP
  pNow = the milliseconds
  if pNow - gBR4MP.lastPing < gBR4MP.pingMs then return
  gBR4MP.lastPing = pNow
  gBR4MP.pingSentAt = pNow
  gBR4MP.pingId = gBR4MP.pingId + 1
  pLine = "PING|n=" & string(gBR4MP.pingId)
  pLine = pLine & ",ct=" & string(pNow)
  BR4MPSendLine(pLine)
end

-- ---------------------------------------------------------------------
--  snapshot entries
-- ---------------------------------------------------------------------
on BR4MPGameSnapshotEntry pBody
  global gBR4MP
  pId = BR4MPNum(pBody, "i")
  if pId = gBR4MP.playerId then return          -- that's us; the local car wins

  pMask = BR4MPNum(pBody, "m")
  pRemote = gBR4MP.remotes[pId]
  if ilk(pRemote) <> #propList then
    pRemote = [:]
    pRemote.id = pId
    pRemote.pos = vector(0, 0, 0)
    pRemote.shown = vector(0, 0, 0)
    pRemote.yaw = 0
    pRemote.health = 100
    pRemote.speed = 0
    pRemote.seenAt = the milliseconds
    pRemote.mesh = VOID
    gBR4MP.remotes[pId] = pRemote
  end if

  if bitAnd(pMask, 1) then
    pRemote.pos = vector(BR4MPNum(pBody, "px"), BR4MPNum(pBody, "py"), BR4MPNum(pBody, "pz"))
  end if
  if bitAnd(pMask, 2) then
    pQZ = BR4MPNum(pBody, "rz")
    pQW = BR4MPNum(pBody, "rw")
    if pQZ = 0 and pQW = 0 then
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

-- ADAPT: create or borrow a car model for this opponent and store it in
-- pRemote.mesh. Example for a movie with a traffic spawner:
--     pRemote.mesh = gGame.world.SpawnTrafficCar(pRemote.id)
--     return pRemote.mesh
-- Returning VOID is safe: roster, chat and race logic keep working, the
-- opponent is simply not drawn.
on BR4MPGameRemoteSpawn pRemote
  if ilk(pRemote.mesh) <> #void then return pRemote.mesh
  return VOID
end

on BR4MPAnimateRemotes
  global gBR4MP
  pIds = gBR4MP.remotes.getPropList()
  pNow = the milliseconds
  repeat with i = 1 to pIds.count
    pId = pIds[i]
    pRemote = gBR4MP.remotes[pId]
    if ilk(pRemote) = #propList then
      if pNow - pRemote.seenAt > 4000 then
        BR4MPHideRemote(pRemote)
      else
        -- snapshots arrive at 20 Hz; ease the drawn car towards the last
        -- authoritative position so it looks smooth at 30-60 fps
        pRemote.shown = BR4MPLerp(pRemote.shown, pRemote.pos, 0.35)
        if pRemote.mesh <> VOID then pRemote.mesh.visible = TRUE
        BR4MPPlaceRemote(pRemote)
      end if
    end if
  end repeat
end

on BR4MPPlaceRemote pRemote
  if pRemote.mesh = VOID then return
  pRemote.mesh.transform.position = pRemote.shown
  pRemote.mesh.transform.rotation = vector(0, 0, pRemote.yaw)
end

on BR4MPHideRemote pRemote
  if pRemote.mesh = VOID then return
  pRemote.mesh.visible = FALSE
end

-- Lingo has no two-argument atan; usual quadrant fix-up.
on BR4MPAtan2 pY, pX
  if pX > 0 then return atan(pY / pX)
  if pX < 0 then
    if pY >= 0 then return atan(pY / pX) + pi()
    return atan(pY / pX) - pi()
  end if
  if pY > 0 then return pi() / 2
  if pY < 0 then return -pi() / 2
  return 0
end

on BR4MPLerp pTarget, pToward, pAlpha
  if ilk(pTarget) <> #vector then return pToward
  if ilk(pToward) <> #vector then return pTarget
  return pTarget + (pToward - pTarget) * pAlpha
end

-- ---------------------------------------------------------------------
--  callbacks from br4mp_net.ls
-- ---------------------------------------------------------------------
on BR4MPGameJoined pRoomId, pTrackId
  global gBR4MP
  gBR4MP.roomId = pRoomId
  gBR4MP.trackId = pTrackId
  gBR4MP.remotes = [:]
  gBR4MP.statusText = "Joined " & pRoomId
end

on BR4MPGamePlayerJoin pPlayer
  BR4MPShowChat("SYSTEM", pPlayer.name & " joined.", 2)
end

on BR4MPGamePlayerLeave pId
  global gBR4MP
  pRemote = gBR4MP.remotes[pId]
  if ilk(pRemote) = #propList then
    if pRemote.mesh <> VOID then pRemote.mesh.visible = FALSE
    gBR4MP.remotes.deleteProp(pId)
  end if
end

on BR4MPGameChat pName, pText, pChannel
  BR4MPShowChat(pName, pText, pChannel)
end

on BR4MPGameRaceState pPhase, pLap, pTotalLaps, pCountdownMs
  global gBR4MP
  gBR4MP.phase = pPhase
  gBR4MP.lap = pLap
  gBR4MP.totalLaps = pTotalLaps
  gBR4MP.countdownMs = pCountdownMs
  if pPhase = 1 then BR4MPShowChat("SYSTEM", "Starting in " & string((pCountdownMs div 1000) + 1) & "...", 2)
  if pPhase = 2 then BR4MPShowChat("SYSTEM", "GO!", 2)
end

on BR4MPGameStanding pId, pLap, pCp, pFinished, pFinishMs
  global gBR4MP
  pRow = [:]
  pRow.id = pId
  pRow.lap = pLap
  pRow.cp = pCp
  pRow.finished = pFinished
  pRow.timeMs = pFinishMs
  gBR4MP.standings.append(pRow)
end

on BR4MPGameEvent pEvent, pActor, pTarget, pValue
  global gBR4MP
  if pEvent = 4 then BR4MPShowChat("SYSTEM", BR4MPPlayerName(pTarget) & " was destroyed by " & BR4MPPlayerName(pActor) & ".", 2)
  if pEvent = 5 then BR4MPShowChat("SYSTEM", BR4MPPlayerName(pActor) & " respawned.", 2)
  if pEvent = 9 then BR4MPShowChat("SYSTEM", "GO!", 2)
  if pEvent = 10 then BR4MPShowChat("SYSTEM", "Lap in " & string(pValue / 1000.0) & "s", 2)
  if pEvent = 11 then BR4MPShowChat("SYSTEM", BR4MPPlayerName(pActor) & " finished!", 2)
  if pEvent = 16 then gBR4MP.invitedRoom = pValue
end

-- The server moved us: reason 1/2 (respawn / race start) are authoritative
-- teleports, reason 0 is the anti-cheat pulling the car back.
on BR4MPGameCorrection pReason, pX, pY, pZ
  global gGame
  gGame.me.car.transform.position = vector(pX, pY, pZ)
  if pReason = 0 then BR4MPShowChat("SYSTEM", "Position corrected by the server.", 2)
end

on BR4MPGameError pCode, pMessage
  global gBR4MP
  gBR4MP.lastError = pMessage
  BR4MPShowChat("SYSTEM", "Error " & string(pCode) & ": " & pMessage, 2)
end

-- ---------------------------------------------------------------------
--  public API for the original UI
-- ---------------------------------------------------------------------
on BR4MPChat pText
  if not BR4MPActive() then return
  if pText = "" then return
  BR4MPSendNow("CHAT|ch=0,x=" & BR4MPEncode(pText))
end

on BR4MPAction pAction
  pLine = "ACTION|a=" & string(pAction)
  pLine = pLine & ",t=0,arg=0"
  BR4MPSendLine(pLine)
end

on BR4MPHit pTargetId, pWeapon, pX, pY, pZ
  global gBR4MP
  pLine = "HIT|t=" & string(pTargetId)
  pLine = pLine & ",w=" & string(pWeapon)
  pLine = pLine & ",px=" & BR4MPFixed(pX)
  pLine = pLine & ",py=" & BR4MPFixed(pY)
  pLine = pLine & ",pz=" & BR4MPFixed(pZ)
  pLine = pLine & ",ct=" & string(the milliseconds)
  pLine = pLine & ",d=0"
  BR4MPSendLine(pLine)
end

on BR4MPAcceptInvite
  global gBR4MP
  if gBR4MP.invitedRoom = 0 then return
  pLine = "ACTION|a=6,t=0,arg=" & string(gBR4MP.invitedRoom)
  BR4MPSendNow(pLine)
end

on BR4MPPlayerName pId
  global gBR4MP
  pPlayer = gBR4MP.players[pId]
  if ilk(pPlayer) <> #propList then return "#" & string(pId)
  return pPlayer.name
end

on BR4MPShowChat pName, pText, pChannel
  global gBR4MP
  pRow = [:]
  pRow.name = pName
  pRow.text = pText
  pRow.channel = pChannel
  gBR4MP.chat.append(pRow)
  while gBR4MP.chat.count > 8
    gBR4MP.chat.deleteAt(1)
  end while
  if gBR4MP.chatMember <> VOID then
    gBR4MP.chatMember.text = pName & ": " & pText
  end if
end

-- Pass the text member that should show the newest chat line.
on BR4MPChatMember pMember
  global gBR4MP
  if ilk(gBR4MP) <> #propList then return
  gBR4MP.chatMember = pMember
end

on BR4MPUpdateStatus
  global gBR4MP
  pPhaseName = ["LOBBY", "COUNTDOWN", "RACING", "FINISHING", "RESULTS"]
  pName = pPhaseName[gBR4MP.phase + 1]
  if pName = VOID then pName = "-"
  pText = gBR4MP.roomId & " - " & pName
  pText = pText & " - lap " & string(gBR4MP.lap) & "/" & string(gBR4MP.totalLaps)
  pText = pText & " - " & string(gBR4MP.players.count) & "p"
  pText = pText & " - " & string(gBR4MP.rttMs) & "ms"
  gBR4MP.statusText = pText
end

on BR4MPStatusText
  global gBR4MP
  if ilk(gBR4MP) <> #propList then return ""
  return gBR4MP.statusText
end
