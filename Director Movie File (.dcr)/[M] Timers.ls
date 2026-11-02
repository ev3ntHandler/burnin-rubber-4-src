-- [Script] [M] Timers (Script #6123)
-- Script Type: Movie

global gGame

on AddTimer me, tTarget, tDataList
  if tTarget.ilk <> #string then
    tTarget = "DefaultTimer" & (gGame.timerList.count + 1)
  end if
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    LogMessage("Function: SetupTimer. Target: " & tTarget & " Parameters: " & tDataList & " Datalist was not a #PropList after value().")
    return 0
  end if
  tValue = VOID
  if tDataList[#value].ilk = #string then
    tValue = tDataList.value
  end if
  if tValue = VOID then
    return 0
  end if
  tTime = 0
  if tDataList[#time].ilk = #integer then
    tTime = tDataList.time
  end if
  tState = #up
  if tDataList[#state].ilk = #symbol then
    tState = tDataList.state
  end if
  tLimit = #none
  if tDataList[#limit].ilk = #integer then
    tLimit = tDataList.limit
  end if
  tGlobal = AddValue(0, EMPTY, [#name: tValue, #value: tTime])
  tList = [tGlobal, tState, _system.milliSeconds, tLimit]
  gGame.timerList[symbol(tTarget)] = tList
  return 1
end

on RemoveTimer me, tTarget, tDataList
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tTimer = #none
  if tDataList[#timer].ilk = #string then
    tTimer = symbol(tDataList.timer)
  else
    if tDataList[#timer].ilk = #symbol then
      tTimer = tDataList.timer
    end if
  end if
  if voidp(gGame.timerList[tTimer]) = 0 then
    gGame.timerList.deleteProp(#timer)
    if gGame.timerList.count = 0 then
      gGame[#PauseTime] = 0
    end if
    return 1
  else
    return 0
  end if
end

on UpdateTimers me
  tDelList = []
  repeat with i in gGame.timerList
    tdiff = integer((_system.milliSeconds - i[3]) * gGame.TimeMP)
    if i[2] = #down then
      gGame[i[1]] = gGame[i[1]] - tdiff
      gGame[i[1]] = gGame[i[1]] + gGame.PauseTime
    else
      gGame[i[1]] = gGame[i[1]] + tdiff
      gGame[i[1]] = gGame[i[1]] - gGame.PauseTime
    end if
    i[3] = _system.milliSeconds
    if i[4] <> #none then
      if (i[2] = #down) and (gGame[i[1]] <= i[4]) then
        gGame[i[1]] = i[4]
        tDelList.add(i)
      end if
      if (i[2] = #up) and (gGame[i[1]] >= i[4]) then
        gGame[i[1]] = i[4]
        tDelList.add(i)
      end if
    end if
  end repeat
  repeat with i in tDelList
    gGame.timerList.deleteOne(i)
  end repeat
  gGame[#PauseTime] = 0
end
