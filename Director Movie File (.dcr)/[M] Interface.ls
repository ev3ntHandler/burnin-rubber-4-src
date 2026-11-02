-- [Script] [M] Interface (Script #5867)
-- Script Type: Movie

global gGame

on ShowCurrentInterface me, tTarget, tDataList
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    tDataList = [:]
  end if
  if voidp(gGame[#interface]) = 0 then
    gGame.interface.ShowCurrentInterface(tTarget, tDataList)
  end if
end

on HideCurrentInterface me, tTarget, tDataList
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    tDataList = [:]
  end if
  if voidp(gGame[#interface]) = 0 then
    gGame.interface.HideCurrentInterface(tTarget, tDataList)
  end if
end

on ShowSaveProgress me
  if voidp(gGame[#interface]) = 0 then
    gGame.interface.ShowSaveProgress()
  end if
end

on HideSaveProgress me
  if voidp(gGame[#interface]) = 0 then
    gGame.interface.HideSaveProgress()
  end if
end

on ShowLoadProgress me, tTarget, tDataList
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    tDataList = [:]
  end if
  if voidp(gGame[#interface]) = 0 then
    gGame.interface.ShowLoadProgress(tTarget, tDataList)
  end if
end

on HideLoadProgress me
  if voidp(gGame[#interface]) = 0 then
    gGame.interface.HideLoadProgress()
  end if
end

on HideProgress me
  if voidp(gGame[#interface]) = 0 then
    gGame.interface.HideProgress()
  end if
end

on AddToInterfaceList me, tTarget
  if voidp(gGame[#interface]) = 0 then
    gGame.interface.AddToInterfaceList(tTarget)
  end if
end

on RemoveFromInterfaceList me, tTarget
  if voidp(gGame[#interface]) = 0 then
    gGame.interface.RemoveFromInterfaceList(tTarget)
  end if
end

on SetupInterfaceTimer me, tTarget
  if voidp(gGame[#interface]) = 0 then
    gGame.interface.SetupTimer()
  end if
end

on ResetInterfaceTimer me, tTarget
  if voidp(gGame[#interface]) = 0 then
    gGame.interface.resetTimer()
  end if
end

on SetupInterfaceTargets me
  if voidp(gGame[#interface]) = 0 then
    gGame.interface.SetupTargets()
  end if
end

on UpdateMoney me, tTarget, tDataList
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    tDataList = [:]
  end if
  if voidp(gGame[#interface]) = 0 then
    gGame.interface.UpdateMoney(tTarget, tDataList)
  end if
end

on UpdateTickets me
  if voidp(gGame[#interface]) = 0 then
    gGame.interface.UpdateTickets()
  end if
  if gGame.FirstTicket = 1 then
    if (gGame.UPTickets.count = 1) and (gGame.UPBossTickets.count = 0) then
      event(0, #FirstTicket)
    else
      if (gGame.UPTickets.count = 0) and (gGame.UPBossTickets.count = 1) then
        event(0, #FirstTicket)
      end if
    end if
  end if
end

on UpdateWeaponsData me
  if voidp(gGame[#interface]) = 0 then
    gGame.interface.UpdateWeaponsData()
  end if
end

on UpdateTargets me, tCurrent, tTotal
  if voidp(gGame[#interface]) = 0 then
    gGame.interface.UpdateTargets(tCurrent, tTotal)
  end if
end

on FormatMoney me, tString
  if tString.ilk = #integer then
    tString = string(tString)
  end if
  if tString.length >= 4 then
    put "," before tString.char[tString.length - 2]
  end if
  if tString.length >= 8 then
    put "," before tString.char[tString.length - 6]
  end if
  if tString.length >= 12 then
    put "," before tString.char[tString.length - 10]
  end if
  if tString.length >= 16 then
    put "," before tString.char[tString.length - 14]
  end if
  return "$ " & tString
end
