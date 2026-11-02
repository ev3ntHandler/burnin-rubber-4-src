-- [Script] [M] Input Keys (Script #6127)
-- Script Type: Movie

global gGame

on KeyHandler me, tKey
  if getaProp(gGame, #Keys) = VOID then
    exit
  end if
  if getaProp(gGame.Keys, #KeyEvent) <> VOID then
    pCount = gGame.Keys.KeyEvent.count
    repeat with i = 1 to pCount
      pCheckKey = gGame.Keys.KeyEvent[i][1]
      pevent = gGame.Keys.KeyEvent[i][2]
      pSoundName = gGame.Keys.KeyEvent[i][3]
      pOnce = gGame.Keys.KeyEvent[i][4]
      if (pCheckKey = tKey) and (pCheckKey.ilk = tKey.ilk) then
        if pOnce = 1 then
          gGame.Keys.KeyEvent.deleteAt(i)
        end if
        event(0, pevent)
        if pSoundName <> VOID then
          PlaySound(0, pSoundName)
        end if
        exit repeat
      end if
    end repeat
  end if
  if getaProp(gGame.Keys, #KeyHandler) <> VOID then
    pCount = gGame.Keys.KeyHandler.count
    repeat with i = 1 to pCount
      pCheckKey = gGame.Keys.KeyHandler[i][1]
      pHandler = gGame.Keys.KeyHandler[i][2]
      pSoundName = gGame.Keys.KeyHandler[i][3]
      pOnce = gGame.Keys.KeyHandler[i][4]
      if (pCheckKey = tKey) and (pCheckKey.ilk = tKey.ilk) then
        if pOnce = 1 then
          gGame.Keys.KeyHandler.deleteAt(i)
        end if
        do(pHandler & "(" & string(tKey) & ")")
        if pSoundName <> VOID then
          PlaySound(0, pSoundName)
        end if
        exit repeat
      end if
    end repeat
  end if
  if getaProp(gGame.Keys, #KeyGoTo) <> VOID then
    pCount = gGame.Keys.KeyGoTo.count
    repeat with i = 1 to pCount
      pCheckKey = gGame.Keys.KeyGoTo[i][1]
      pFrame = gGame.Keys.KeyGoTo[i][2]
      pSoundName = gGame.Keys.KeyGoTo[i][3]
      pOnce = gGame.Keys.KeyGoTo[i][4]
      if (pCheckKey = tKey) and (pCheckKey.ilk = tKey.ilk) then
        if pOnce = 1 then
          gGame.Keys.KeyGoTo.deleteAt(i)
        end if
        _movie.go(pFrame)
        if pSoundName <> VOID then
          PlaySound(0, pSoundName)
        end if
        exit repeat
      end if
    end repeat
  end if
  if getaProp(gGame.Keys, #KeyMarker) <> VOID then
    pCount = gGame.Keys.KeyMarker.count
    repeat with i = 1 to pCount
      pCheckKey = gGame.Keys.KeyMarker[i][1]
      pmarker = gGame.Keys.KeyMarker[i][2]
      pSoundName = gGame.Keys.KeyMarker[i][3]
      pOnce = gGame.Keys.KeyMarker[i][4]
      if (pCheckKey = tKey) and (pCheckKey.ilk = tKey.ilk) then
        if pOnce = 1 then
          gGame.Keys.KeyMarker.deleteAt(i)
        end if
        _movie.go(pmarker)
        if pSoundName <> VOID then
          PlaySound(0, pSoundName)
        end if
        exit repeat
      end if
    end repeat
  end if
end

on BindKey me, tTarget, tDataList
  LogMessage("Function: LinkKey" && "Target" && tTarget && "DataList" && tDataList)
  pDataList = tDataList
  if pDataList.ilk = #string then
    pDataList = value(pDataList)
  end if
  if (pDataList = VOID) or (pDataList.ilk <> #propList) then
    LogMessage("Function: LinkKey. Target: " & tTarget & " Parameters: " & tDataList & " Datalist obsolete (VOID or not #proplist).")
    exit
  end if
  pKey = VOID
  if getaProp(pDataList, #key).ilk = #string then
    pKey = pDataList[#key]
  end if
  if getaProp(pDataList, #key).ilk = #integer then
    pKey = pDataList[#key]
  end if
  if pKey = VOID then
    LogMessage("Function: LinkKey. Target: " & tTarget & " Parameters: " & tDataList & " No key.")
    exit
  end if
  pCase = VOID
  if getaProp(pDataList, #event) <> VOID then
    pCase = #event
  end if
  if getaProp(pDataList, #handler) <> VOID then
    pCase = #handler
  end if
  if getaProp(pDataList, #goto) <> VOID then
    pCase = #goto
  end if
  if getaProp(pDataList, #marker) <> VOID then
    pCase = #marker
  end if
  if pCase = VOID then
    LogMessage("Function: LinkKey. Target: " & tTarget & " Parameters: " & tDataList & " No info to store the key.")
    exit
  end if
  if pDataList[#Override].ilk = #integer then
    tOverride = pDataList.Override
  else
    tOverride = 0
  end if
  pSoundName = VOID
  if getaProp(pDataList, #soundName).ilk = #string then
    pSoundName = pDataList[#soundName]
  end if
  pOnce = 1
  if getaProp(pDataList, #once).ilk = #integer then
    pOnce = pDataList[#once]
  end if
  if getaProp(gGame, #Keys) = VOID then
    gGame[#Keys] = [:]
  end if
  if pCase = #event then
    if getaProp(gGame.Keys, #KeyEvent) = VOID then
      gGame.Keys[#KeyEvent] = []
    end if
    pevent = EMPTY
    if getaProp(pDataList, #event).ilk = #string then
      pevent = pDataList[#event]
    end if
    pEntry = [pKey, pevent, pSoundName, pOnce]
    pError = 0
    pCount = gGame.Keys.KeyEvent.count
    repeat with i = 1 to pCount
      pkeyCheck = gGame.Keys.KeyEvent[i][1]
      if pKey = pkeyCheck then
        if tOverride = 1 then
          if gGame.Keys.KeyEvent[i] <> pEntry then
            gGame.Keys.KeyEvent[i] = pEntry
          end if
          exit
        else
          pError = 1
        end if
        exit repeat
      end if
    end repeat
    if pError = 1 then
      LogMessage("Function: LinkKey. Target: " & tTarget & " Parameters: " & tDataList & " Key already present.")
      exit
    end if
    gGame.Keys.KeyEvent.add(pEntry)
  end if
  if pCase = #handler then
    if getaProp(gGame.Keys, #KeyHandler) = VOID then
      gGame.Keys[#KeyHandler] = []
    end if
    pHandler = VOID
    if getaProp(pDataList, #handler).ilk = #string then
      pHandler = pDataList[#handler]
    end if
    pEntry = [pKey, pHandler, pSoundName, pOnce]
    pError = 0
    pCount = gGame.Keys.KeyHandler.count
    repeat with i = 1 to pCount
      pkeyCheck = gGame.Keys.KeyHandler[i][1]
      if pKey = pkeyCheck then
        pError = 1
        exit repeat
      end if
    end repeat
    if pError = 1 then
      LogMessage("Function: LinkKey. Target: " & tTarget & " Parameters: " & tDataList & " Key already present.")
      exit
    end if
    gGame.Keys.KeyHandler.add(pEntry)
  end if
  if pCase = #goto then
    if getaProp(gGame.Keys, #KeyGoTo) = VOID then
      gGame.Keys[#KeyGoTo] = []
    end if
    pGoTo = VOID
    if getaProp(pDataList, #goto).ilk = #string then
      pGoTo = pDataList[#goto]
    end if
    pEntry = [pKey, pGoTo, pSoundName, pOnce]
    pError = 0
    pCount = gGame.Keys.KeyGoTo.count
    repeat with i = 1 to pCount
      pkeyCheck = gGame.Keys.KeyGoTo[i][1]
      if pKey = pkeyCheck then
        pError = 1
        exit repeat
      end if
    end repeat
    if pError = 1 then
      LogMessage("Function: LinkKey. Target: " & tTarget & " Parameters: " & tDataList & " Key already present.")
      exit
    end if
    gGame.Keys.KeyGoTo.add(pEntry)
  end if
  if pCase = #marker then
    if getaProp(gGame.Keys, #KeyMarker) = VOID then
      gGame.Keys[#KeyMarker] = []
    end if
    pGoTo = VOID
    if getaProp(pDataList, #marker).ilk = #string then
      pGoTo = pDataList[#marker]
    end if
    pEntry = [pKey, pGoTo, pSoundName, pOnce]
    pError = 0
    pCount = gGame.Keys.KeyMarker.count
    repeat with i = 1 to pCount
      pkeyCheck = gGame.Keys.KeyMarker[i][1]
      if pKey = pkeyCheck then
        pError = 1
        exit repeat
      end if
    end repeat
    if pError = 1 then
      LogMessage("Function: LinkKey. Target: " & tTarget & " Parameters: " & tDataList & " Key already present.")
      exit
    end if
    gGame.Keys.KeyMarker.add(pEntry)
  end if
end

on UnBindKey me, tTarget, tDataList
  if voidp(gGame[#Keys]) = 1 then
    exit
  end if
  LogMessage("Function: UnlinkKey" && "Target" && tTarget && "DataList" && tDataList)
  pDataList = tDataList
  if pDataList.ilk = #string then
    pDataList = value(pDataList)
  end if
  if (pDataList = VOID) or (pDataList.ilk <> #propList) then
    LogMessage("Function: UnlinkKey. Target: " & tTarget & " Parameters: " & tDataList & " Datalist obsolete (VOID or not #proplist).")
    exit
  end if
  pKey = VOID
  if (getaProp(pDataList, #key).ilk = #string) or (getaProp(pDataList, #key).ilk = #integer) then
    pKey = pDataList[#key]
  end if
  if pKey = VOID then
    LogMessage("Function: UnlinkKey. Target: " & tTarget & " Parameters: " & tDataList & " No key.")
    exit
  end if
  if getaProp(gGame.Keys, #KeyEvent) <> VOID then
    pCount = gGame.Keys.KeyEvent.count
    repeat with i = 1 to pCount
      pCheckKey = gGame.Keys.KeyEvent[i][1]
      if pCheckKey = pKey then
        gGame.Keys.KeyEvent.deleteAt(i)
        exit repeat
      end if
    end repeat
  end if
  if getaProp(gGame.Keys, #KeyHandler) <> VOID then
    pCount = gGame.Keys.KeyHandler.count
    repeat with i = 1 to pCount
      pCheckKey = gGame.Keys.KeyHandler[i][1]
      if pCheckKey = pKey then
        gGame.Keys.KeyHandler.deleteAt(i)
        exit repeat
      end if
    end repeat
  end if
  if getaProp(gGame.Keys, #KeyGoTo) <> VOID then
    pCount = gGame.Keys.KeyGoTo.count
    repeat with i = 1 to pCount
      pCheckKey = gGame.Keys.KeyGoTo[i][1]
      if pCheckKey = pKey then
        gGame.Keys.KeyGoTo.deleteAt(i)
        exit repeat
      end if
    end repeat
  end if
  if getaProp(gGame.Keys, #KeyMarker) <> VOID then
    pCount = gGame.Keys.KeyMarker.count
    repeat with i = 1 to pCount
      pCheckKey = gGame.Keys.KeyMarker[i][1]
      if pCheckKey = pKey then
        gGame.Keys.KeyMarker.deleteAt(i)
        exit repeat
      end if
    end repeat
  end if
end
