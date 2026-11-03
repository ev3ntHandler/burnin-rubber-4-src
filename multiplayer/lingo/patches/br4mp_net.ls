-- =====================================================================
--  br4mp_net.ls - Burnin' Rubber 4 online bridge: text transport
--  Movie script (cast member type: Movie Script, internal cast).
--
--  Shockwave Player cannot open a WebSocket, so the bridge speaks the
--  line-oriented text profile over HTTP (see docs/02-protocol.md section 5):
--
--    POST /mp/connect?...            once, gets WELCOME/JOINED/roster
--    GET  /mp/poll?token=..&wait=15  held open, returns queued lines
--    POST /mp/send?token=..&d=..     state uplink + chat/actions
--
--  Everything is asynchronous: BR4MPFrame (pumped once per frame by
--  BR4MPGameFrame) collects the completed requests, so nothing blocks the
--  Director playback head.
--
--  Every handler declares `global gBR4MP` itself - see the note in
--  br4mp_config.ls. There are no line continuations in this file, so a
--  paste that mangles a continuation character cannot break the compile.
-- =====================================================================

-- ---------------------------------------------------------------------
--  connect
-- ---------------------------------------------------------------------
on BR4MPConnect
  global gBR4MP
  pURL = gBR4MP.baseURL & "/mp/connect"
  pURL = pURL & "?name=" & BR4MPEncode(gBR4MP.playerName)
  pURL = pURL & "&v=1&cv=director"
  pURL = pURL & "&veh=" & BR4MPEncode(gBR4MP.vehicle)
  pURL = pURL & "&sk=" & string(gBR4MP.skin)
  pURL = pURL & "&m=" & string(gBR4MP.mode)
  pURL = pURL & "&w=" & string(gBR4MP.worldIndex)
  pURL = pURL & "&tid=" & BR4MPEncode(gBR4MP.trackId)
  pURL = pURL & "&tok=" & BR4MPEncode(gBR4MP.token)
  gBR4MP.connectNet = postNetText(pURL, "")
  gBR4MP.lastError = ""
  BR4MPTrace("connect -> " & pURL)
end

-- ---------------------------------------------------------------------
--  per-frame pump
-- ---------------------------------------------------------------------
on BR4MPFrame
  global gBR4MP
  if not BR4MPActive() then
    return
  end if

  -- 1. connection reply
  if gBR4MP.connectNet > 0 then
    if netDone(gBR4MP.connectNet) then
      pNet = gBR4MP.connectNet
      pText = netTextResult(pNet)
      pErr = netError(pNet)
      gBR4MP.connectNet = 0
      if pErr <> "" then
        gBR4MP.lastError = "net: " & pErr
      end if
      BR4MPStartPoll
      BR4MPHandleText(pText)
    end if
  end if

  -- 2. held poll reply: parse, then immediately queue the next one
  if gBR4MP.pollNet > 0 then
    if netDone(gBR4MP.pollNet) then
      pNet = gBR4MP.pollNet
      pText = netTextResult(pNet)
      gBR4MP.pollNet = 0
      -- queue the next held poll *before* parsing: if one bad line raises,
      -- the stream keeps running instead of going silent until the session
      -- times out
      if BR4MPActive() then
        BR4MPStartPoll
      end if
      BR4MPHandleText(pText)
    end if
  end if

  -- 3. flush queued uplinks at most every 50 ms
  if the milliseconds - gBR4MP.lastFlush >= 50 then
    BR4MPFlush
  end if
end

on BR4MPStartPoll
  global gBR4MP
  if not BR4MPActive() then
    return
  end if
  if gBR4MP.token = "" then
    return
  end if
  if gBR4MP.pollNet > 0 then
    return
  end if
  pURL = gBR4MP.baseURL & "/mp/poll?token=" & BR4MPEncode(gBR4MP.token)
  pURL = pURL & "&wait=" & string(gBR4MP.pollWait)
  pURL = pURL & "&r=" & string(the milliseconds)
  gBR4MP.pollNet = getNetText(pURL)
end

on BR4MPCancelPoll
  global gBR4MP
  if ilk(gBR4MP) <> #propList then
    return
  end if
  -- nothing to cancel in Lingo; forget the handle so its result is ignored
  gBR4MP.pollNet = 0
end

-- ---------------------------------------------------------------------
--  uplink
-- ---------------------------------------------------------------------
on BR4MPSendLine pLine
  global gBR4MP
  if ilk(gBR4MP) <> #propList then
    return
  end if
  if pLine = "" then
    return
  end if
  gBR4MP.sendQueue.append(pLine)
end

on BR4MPSendNow pLine
  BR4MPSendLine(pLine)
  BR4MPFlush
end

on BR4MPFlush
  global gBR4MP
  if ilk(gBR4MP) <> #propList then
    return
  end if
  if gBR4MP.token = "" then
    return
  end if
  if gBR4MP.sendQueue.count = 0 then
    return
  end if
  pPayload = gBR4MP.sendQueue[1]
  repeat with i = 2 to gBR4MP.sendQueue.count
    pPayload = pPayload & numToChar(10) & gBR4MP.sendQueue[i]
  end repeat
  gBR4MP.sendQueue = []
  gBR4MP.lastFlush = the milliseconds
  pURL = gBR4MP.baseURL & "/mp/send?token=" & BR4MPEncode(gBR4MP.token)
  pURL = pURL & "&d=" & BR4MPEncode(pPayload)
  -- fire and forget: the reply (usually empty) is dropped on purpose
  postNetText(pURL, "")
end

-- ---------------------------------------------------------------------
--  parsing
-- ---------------------------------------------------------------------
on BR4MPHandleText pText
  if pText = "" then
    return
  end if
  pCount = the number of lines in pText
  repeat with i = 1 to pCount
    pLine = pText.line[i]
    if pLine <> "" then
      BR4MPHandleLine(pLine)
    end if
  end repeat
end

-- One response line: TAG|k=v,k=v,...
on BR4MPHandleLine pLine
  global gBR4MP
  BR4MPTrace("<- " & pLine)
  pBar = offset("|", pLine)
  if pBar > 0 then
    pTagEnd = pBar - 1
    pBodyStart = pBar + 1
    pTag = pLine.char[1 .. pTagEnd]
    pBody = pLine.char[pBodyStart .. pLine.length]
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
      BR4MPGameJoined(gBR4MP.roomId, gBR4MP.trackId)

    "PJ":
      pPlayer = [#id: BR4MPNum(pBody, "i"), #name: BR4MPStr(pBody, "n"), #vehicle: BR4MPStr(pBody, "veh"), #ready: BR4MPNum(pBody, "r")]
      gBR4MP.players[BR4MPKey(pPlayer.id)] = pPlayer
      BR4MPGamePlayerJoin(pPlayer)

    "PL":
      pId = BR4MPNum(pBody, "i")
      gBR4MP.players.deleteProp(BR4MPKey(pId))
      BR4MPGamePlayerLeave(pId)

    "C":
      pChannel = BR4MPNum(pBody, "ch")
      pName = BR4MPStr(pBody, "n")
      pTextValue = BR4MPStr(pBody, "x")
      BR4MPGameChat(pName, pTextValue, pChannel)

    "SN":
      gBR4MP.snapshotTick = BR4MPNum(pBody, "t")
      gBR4MP.ackTick = gBR4MP.snapshotTick

    "E":
      BR4MPGameSnapshotEntry(pBody)

    "RS":
      gBR4MP.phase = BR4MPNum(pBody, "ph")
      gBR4MP.lap = BR4MPNum(pBody, "l")
      gBR4MP.totalLaps = BR4MPNum(pBody, "tl")
      gBR4MP.countdownMs = BR4MPNum(pBody, "cd")
      BR4MPGameRaceState(gBR4MP.phase, gBR4MP.lap, gBR4MP.totalLaps, gBR4MP.countdownMs)

    "ST":
      BR4MPGameStanding(BR4MPNum(pBody, "i"), BR4MPNum(pBody, "l"), BR4MPNum(pBody, "c"), BR4MPNum(pBody, "f"), BR4MPNum(pBody, "ft"))

    "EV":
      BR4MPGameEvent(BR4MPNum(pBody, "e"), BR4MPNum(pBody, "a"), BR4MPNum(pBody, "t"), BR4MPNum(pBody, "val"))

    "COR":
      BR4MPGameCorrection(BR4MPNum(pBody, "rs"), BR4MPNum(pBody, "px"), BR4MPNum(pBody, "py"), BR4MPNum(pBody, "pz"))

    "PONG":
      if gBR4MP.pingSentAt > 0 then
        gBR4MP.rttMs = the milliseconds - gBR4MP.pingSentAt
        gBR4MP.pingSentAt = 0
      end if

    "ERR":
      gBR4MP.lastError = BR4MPStr(pBody, "m")
      BR4MPGameError(BR4MPNum(pBody, "c"), BR4MPStr(pBody, "m"))

    otherwise:
      -- unknown tags are ignored so a newer server cannot break an old build
  end case
end

-- ---------------------------------------------------------------------
--  field helpers
-- ---------------------------------------------------------------------
-- Returns the text after the first pMarker in pLine.
on BR4MPAfter pLine, pMarker
  pAt = offset(pMarker, pLine)
  if pAt = 0 then
    return pLine
  end if
  pStart = pAt + pMarker.length
  return pLine.char[pStart .. pLine.length]
end

-- Value of key=value inside a comma separated body, still percent-encoded.
on BR4MPParam pBody, pKey
  pCount = the number of items in pBody
  repeat with i = 1 to pCount
    pItem = pBody.item[i]
    pEq = offset("=", pItem)
    if pEq > 0 then
      pEnd = pEq - 1
      if pItem.char[1 .. pEnd] = pKey then
        pStart = pEq + 1
        return pItem.char[pStart .. pItem.length]
      end if
    end if
  end repeat
  return ""
end

on BR4MPNum pBody, pKey
  pValue = BR4MPParam(pBody, pKey)
  if pValue = "" then
    return 0
  end if
  return value(pValue)
end

on BR4MPStr pBody, pKey
  return BR4MPDecode(BR4MPParam(pBody, pKey))
end

-- ---------------------------------------------------------------------
--  percent encoding (Lingo has no built-in codec)
-- ---------------------------------------------------------------------
on BR4MPEncode pText
  pOut = ""
  pLen = pText.length
  repeat with i = 1 to pLen
    pCh = pText.char[i]
    pCode = charToNum(pCh)
    pKeep = 0
    if (pCode >= 48 and pCode <= 57) or (pCode >= 65 and pCode <= 90) or (pCode >= 97 and pCode <= 122) then
      pKeep = 1
    end if
    if pCh = "." then
      pKeep = 1
    end if
    if pCh = "-" then
      pKeep = 1
    end if
    if pCh = "_" then
      pKeep = 1
    end if
    if pKeep = 1 then
      pOut = pOut & pCh
    else
      pHigh = integer(pCode / 16)
      pLow = pCode - (pHigh * 16)
      pOut = pOut & "%" & BR4MPHex(pHigh) & BR4MPHex(pLow)
    end if
  end repeat
  return pOut
end

on BR4MPHex pValue
  pDigits = "0123456789ABCDEF"
  pIndex = pValue + 1
  return pDigits.char[pIndex]
end

on BR4MPDecode pText
  pOut = ""
  pLen = pText.length
  i = 1
  repeat while i <= pLen
    pCh = pText.char[i]
    pStep = 1
    if pCh = "%" and i + 2 <= pLen then
      pCode = BR4MPUnHex(pText.char[i + 1]) * 16 + BR4MPUnHex(pText.char[i + 2])
      pOut = pOut & numToChar(pCode)
      pStep = 3
    else
      if pCh = "+" then
        pOut = pOut & " "
      else
        pOut = pOut & pCh
      end if
    end if
    i = i + pStep
  end repeat
  return pOut
end

on BR4MPUnHex pCh
  pCode = charToNum(pCh)
  if pCode >= 48 and pCode <= 57 then
    return pCode - 48
  end if
  if pCode >= 65 and pCode <= 70 then
    return pCode - 55
  end if
  if pCode >= 97 and pCode <= 102 then
    return pCode - 87
  end if
  return 0
end

on BR4MPTrace pText
  global gBR4MP
  if ilk(gBR4MP) <> #propList then
    return
  end if
  if gBR4MP.trace then
    put pText
  end if
end
