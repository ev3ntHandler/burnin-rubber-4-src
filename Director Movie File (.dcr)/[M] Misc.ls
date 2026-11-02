-- [Script] [M] Misc (Script #6139)
-- Script Type: Movie

global gGame

on goto me, tTarget, tDataList
  LogMessage("Function: GoTo" && "Target" && tTarget && "DataList" && tDataList)
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tFrame = #none
  if tDataList[#frame].ilk = #integer then
    tFrame = tDataList.frame
  end if
  tMarker = #none
  if tDataList[#marker].ilk = #string then
    tMarker = tDataList.marker
  end if
  repeat with i = 1 to _movie.markerlist.count
    tListMarker = _movie.markerlist[i]
    if tMarker = tListMarker then
      exit repeat
      next repeat
    end if
    if (i = _movie.markerlist.count) and (tMarker <> tListMarker) then
      tMarker = #none
    end if
  end repeat
  if tFrame <> #none then
    _movie.go(tFrame)
  end if
  if tMarker <> #none then
    _movie.go(tMarker)
  end if
  _player.cursor(-1)
end

on wait me
  set the stageColor to the stageColor
  _movie.updateStage()
end

on updateStage me
  set the stageColor to the stageColor
  _movie.updateStage()
end

on puppetTempo me, tTarget
  tTempo = value(tTarget)
  if tTempo.ilk <> #integer then
    return 0
  end if
  _movie.puppetTempo(tTempo)
end

on CreateTimeOut me, tTarget, tDataList
  pTimeOUtName = tTarget
  if pTimeOUtName = VOID then
    pTimeOUtName = "GenericTimeOut" & string(_movie.timeoutList.count + 1)
  end if
  pDataList = value(tDataList)
  if (pDataList = VOID) or (pDataList.ilk <> #propList) then
    LogMessage("Function: CreateTimeOut. Target: " & tTarget & " Parameters: " & tDataList & " Datalist obsolete (VOID or not #proplist).")
    exit
  end if
  pPeriod = 1.0 / gGame.tempo
  if getaProp(pDataList, #period).ilk = #integer then
    pPeriod = pDataList[#period]
  end if
  pHandler = #put
  if getaProp(pDataList, #handler).ilk = #symbol then
    pHandler = pDataList[#handler]
  end if
  PList = []
  if pDataList[#list] <> VOID then
    PList = pDataList[#list]
  end if
  timeout().new(pTimeOUtName, pPeriod, pHandler, PList)
end
