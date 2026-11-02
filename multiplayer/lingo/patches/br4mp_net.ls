-- =====================================================================
--  br4mp_net.ls  —  Burnin' Rubber 4 online bridge: text transport
--  Movie script (cast member type: Movie Script). Requires br4mp_config.ls,
--  or use the single-file build br4mp_bridge.ls.
--
--  Shockwave Player cannot open a WebSocket, so the bridge speaks the
--  line-oriented text profile over HTTP (see docs/02-protocol.md §5):
--
--    POST /mp/connect?...            once, gets WELCOME/JOINED/roster
--    GET  /mp/poll?token=..&wait=15  held open, returns queued lines
--    POST /mp/send?token=..&d=..     state uplink + chat/actions
--
--  Everything here is asynchronous: BR4MPFrame (called once per frame by
--  the game) pumps the completed requests, so nothing ever blocks the
--  Director playback head.
-- =====================================================================

global gBR4MP

-- ── connect ────────────────────────────────────────────────────────────
on BR4MPConnect
  BR4MPEnsure
  pURL = gBR4MP.baseURL & "/mp/connect" & "?name=" & BR4MPEncode(gBR4MP.playerName) & ¬
         "&v=1&cv=director&veh=" & BR4MPEncode(gBR4MP.vehicle) & ¬
         "&sk=" & string(gBR4MP.skin) & ¬
         "&m=" & string(gBR4MP.mode) & ¬
         "&w=" & string(gBR4MP.worldIndex) & ¬
         "&tid=" & BR4MPEncode(gBR4MP.trackId) & ¬
         "&tok=" & BR4MPEncode(gBR4MP.token)

  gBR4MP.connectNet = postNetText(pURL, "")
  gBR4MP.connectedAt = the milliseconds
  gBR4MP.statusText = "Connecting to " & gBR4MP.baseURL & " ..."
  BR4MPTrace("connect -> " & pURL)
end

-- ── per-frame pump ─────────────────────────────────────────────────────
on BR4MPFrame
  BR4MPEnsure
  if not BR4MPActive() then return

  -- 1. connection reply
  if gBR4MP.connectNet > 0 and netDone(gBR4MP.connectNet) then
    pNet = gBR4MP.connectNet
    pText = netTextResult(pNet)
    pErr = netError(pNet)
    gBR4MP.connectNet = 0
    if pErr <> "" then gBR4MP.lastError = "net: " & pErr
    BR4MPHandleText(pText)
    BR4MPStartPoll
  end if

  -- 2. held poll reply: parse, then immediately queue the next one
  if gBR4MP.pollNet > 0 and netDone(gBR4MP.pollNet) then
    pText = netTextResult(gBR4MP.pollNet)
    gBR4MP.pollNet = 0
    BR4MPHandleText(pText)
    if BR4MPActive() then BR4MPStartPoll
  end if

  -- 3. flush queued uplinks at most every 50 ms
  if gBR4MP.lastFlush = VOID then gBR4MP.lastFlush = the milliseconds
  if the milliseconds - gBR4MP.lastFlush >= 50 then BR4MPFlush
end

on BR4MPStartPoll
  BR4MPEnsure
  if not BR4MPActive() then return
  if gBR4MP.token = "" then return
  if gBR4MP.pollNet > 0 then return
  pURL = gBR4MP.baseURL & "/mp/poll?token=" & BR4MPEncode(gBR4MP.token) & ¬
         "&wait=" & string(gBR4MP.pollWait) & "&r=" & string(the milliseconds)
  gBR4MP.pollNet = getNetText(pURL)
end

on BR4MPCancelPoll
  BR4MPEnsure
  -- nothing to cancel in Lingo; just forget the handle so its result is ignored
  gBR4MP.pollNet = 0
end

-- ── uplink ─────────────────────────────────────────────────────────────
-- Queue one protocol line (no newline needed) for the next flush.
on BR4MPSendLine pLine
  BR4MPEnsure
  if pLine = "" then return
  gBR4MP.sendQueue.add(pLine)
end

on BR4MPSendNow pLine
  BR4MPSendLine(pLine)
  BR4MPFlush
end

on BR4MPFlush
  BR4MPEnsure
  if gBR4MP.token = "" then return
  if gBR4MP.sendQueue.count = 0 then return
  pPayload = gBR4MP.sendQueue[1]
  repeat with i = 2 to gBR4MP.sendQueue.count
    pPayload = pPayload & numToChar(10) & gBR4MP.sendQueue[i]
  end repeat
  gBR4MP.sendQueue = []
  gBR4MP.lastFlush = the milliseconds
  pURL = gBR4MP.baseURL & "/mp/send?token=" & BR4MPEncode(gBR4MP.token) & ¬
         "&d=" & BR4MPEncode(pPayload)
  -- fire and forget: replies (usually empty) are dropped on purpose
  postNetText(pURL, "")
end

-- ── parsing ────────────────────────────────────────────────────────────
-- One response is many lines; each line is TAG|k=v,k=v,...
on BR4MPHandleText pText
  if pText = "" then return
  pCount = the number of lines in pText
  repeat with i = 1 to pCount
    pLine = pText.line[i]
    if pLine <> "" then BR4MPHandleLine(pLine)
  end repeat
end

on BR4MPHandleLine pLine
  BR4MPTrace("<- " & pLine)
  pBar = offset("|", pLine)
  if pBar > 0 then
    pTag = pLine.char[1 .. pBar - 1]
    pBody = pLine.char[pBar + 1 .. pLine.length]
  else
    pTag = pLine
    pBody = ""
  end if

  case pTag of
    "WELCOME":
      gBR4MP.playerId = BR4MPNum(pBody, "i")
      gBR4MP.token = BR4MPStr(pBody, "k")
      gBR4MP.tickRate = BR4MPNum(pBody, "r")
      gBR4MP.statusText = "Connected as #" & string(gBR4MP.playerId)

    "JOINED":
      gBR4MP.roomId = BR4MPStr(pBody, "room")
      gBR4MP.mode = BR4MPNum(pBody, "m")
      gBR4MP.worldIndex = BR4MPNum(pBody, "w")
      gBR4MP.trackId = BR4MPStr(pBody, "tid")
      gBR4MP.totalLaps = BR4MPNum(pBody, "laps")
      gBR4MP.startTick = BR4MPNum(pBody, "st")
      gBR4MP.players = [:]
      BR4MPGameJoined gBR4MP.roomId, gBR4MP.trackId

    "PJ":
      pPlayer = [#id: BR4MPNum(pBody, "i"), #name: BR4MPStr(pBody, "n"), ¬
                 #vehicle: BR4MPStr(pBody, "veh"), #ready: BR4MPNum(pBody, "r")]
      gBR4MP.players[pPlayer.id] = pPlayer
      BR4MPGamePlayerJoin(pPlayer)

    "PL":
      pId = BR4MPNum(pBody, "i")
      gBR4MP.players.deleteProp(pId)
      BR4MPGamePlayerLeave(pId)

    "C":
      pChannel = BR4MPNum(pBody, "ch")
      pName = BR4MPStr(pBody, "n")
      pTextValue = BR4MPStr(pBody, "x")
      gBR4MP.chat.add([#name: pName, #text: pTextValue, #channel: pChannel])
      if gBR4MP.chat.count > 60 then gBR4MP.chat.deleteAt(1)
      BR4MPGameChat(pName, pTextValue, pChannel)

    "SN":
      gBR4MP.snapshotTick = BR4MPNum(pBody, "t")
      gBR4MP.ackTick = gBR4MP.snapshotTick
      gBR4MP.pendingEntries = []

    "E":
      if gBR4MP.pendingEntries <> VOID then gBR4MP.pendingEntries.add(pBody)

    "RS":
      gBR4MP.phase = BR4MPNum(pBody, "ph")
      gBR4MP.lap = BR4MPNum(pBody, "l")
      gBR4MP.totalLaps = BR4MPNum(pBody, "tl")
      gBR4MP.countdownMs = BR4MPNum(pBody, "cd")
      BR4MPGameRaceState(gBR4MP.phase, gBR4MP.lap, gBR4MP.totalLaps, gBR4MP.countdownMs)

    "ST":
      BR4MPGameStanding(BR4MPNum(pBody, "i"), BR4MPNum(pBody, "l"), BR4MPNum(pBody, "c"), ¬
                        BR4MPNum(pBody, "f"), BR4MPNum(pBody, "ft"))

    "EV":
      BR4MPGameEvent(BR4MPNum(pBody, "e"), BR4MPNum(pBody, "a"), BR4MPNum(pBody, "t"), ¬
                     BR4MPNum(pBody, "val"), [BR4MPNum(pBody, "px"), BR4MPNum(pBody, "py"), BR4MPNum(pBody, "pz")])

    "COR":
      BR4MPGameCorrection(BR4MPNum(pBody, "rs"), ¬
                          [BR4MPNum(pBody, "px"), BR4MPNum(pBody, "py"), BR4MPNum(pBody, "pz")], ¬
                          [BR4MPNum(pBody, "rx"), BR4MPNum(pBody, "ry"), BR4MPNum(pBody, "rz"), BR4MPNum(pBody, "rw")])

    "PONG":
      if gBR4MP.pingSentAt > 0 then
        gBR4MP.rttMs = the milliseconds - gBR4MP.pingSentAt
        gBR4MP.pingSentAt = 0
      end if

    "ERR":
      gBR4MP.lastError = "server: " & BR4MPStr(pBody, "m") & " (code " & string(BR4MPNum(pBody, "c")) & ")"
      BR4MPGameError(BR4MPNum(pBody, "c"), BR4MPStr(pBody, "m"))

    otherwise:
      -- unknown tags are ignored so a newer server cannot break an old build
  end case

  -- entries arrive after their SN header, one line each
  if pTag = "E" then BR4MPGameSnapshotEntry(pBody)
end

-- ── field helpers ──────────────────────────────────────────────────────
-- Returns the text after pMarker in pLine (whole line when missing).
on BR4MPAfter pLine, pMarker
  pAt = offset(pMarker, pLine)
  if pAt = 0 then return pLine
  return pLine.char[pAt + pMarker.length .. pLine.length]
end

on BR4MPParam pBody, pKey
  pCount = the number of items in pBody
  repeat with i = 1 to pCount
    pItem = pBody.item[i]
    pEq = offset("=", pItem)
    if pEq > 0 then
      if pItem.char[1 .. pEq - 1] = pKey then return pItem.char[pEq + 1 .. pItem.length]
    end if
  end repeat
  return ""
end

on BR4MPNum pBody, pKey
  pValue = BR4MPParam(pBody, pKey)
  if pValue = "" then return 0
  return value(pValue)
end

on BR4MPStr pBody, pKey
  return BR4MPDecode(BR4MPParam(pBody, pKey))
end

-- ── percent encoding (Lingo has no built-in codec) ─────────────────────
on BR4MPEncode pText
  pOut = ""
  pLen = pText.length
  repeat with i = 1 to pLen
    pCh = pText.char[i]
    pCode = charToNum(pCh)
    if (pCode >= 48 and pCode <= 57) or (pCode >= 65 and pCode <= 90) or (pCode >= 97 and pCode <= 122) then
      pOut = pOut & pCh
    else if pCh = "." or pCh = "-" or pCh = "_" then
      pOut = pOut & pCh
    else
      pOut = pOut & "%" & BR4MPHex(pCode div 16) & BR4MPHex(pCode mod 16)
    end if
  end repeat
  return pOut
end

on BR4MPHex pValue
  pDigits = "0123456789ABCDEF"
  return pDigits.char[(pValue + 1)]
end

on BR4MPDecode pText
  pOut = ""
  pLen = pText.length
  i = 1
  repeat while i <= pLen
    pCh = pText.char[i]
    if pCh = "%" and i + 2 <= pLen then
      pCode = BR4MPUnHex(pText.char[i + 1]) * 16 + BR4MPUnHex(pText.char[i + 2])
      pOut = pOut & numToChar(pCode)
      i = i + 3
    else if pCh = "+" then
      pOut = pOut & " "
      i = i + 1
    else
      pOut = pOut & pCh
      i = i + 1
    end if
  end repeat
  return pOut
end

on BR4MPUnHex pCh
  pCode = charToNum(pCh)
  if pCode >= 48 and pCode <= 57 then return pCode - 48
  if pCode >= 65 and pCode <= 70 then return pCode - 55
  if pCode >= 97 and pCode <= 102 then return pCode - 87
  return 0
end

on BR4MPTrace pText
  if ilk(gBR4MP) <> #propList then return
  if gBR4MP.trace then put pText
end
