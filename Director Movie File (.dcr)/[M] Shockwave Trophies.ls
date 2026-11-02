-- [Script] [M] Shockwave Trophies (Script #6120)
-- Script Type: Movie

global gGame

on RestoreSWTrophies me
  PutMessage(0, "--> RestoreSWTrophies (Handler)")
  gGame.SWGameTrophies = gGame.SWTrophies.duplicate()
end

on UpdateTrophy me, tTarget, tDataList
  put "--> UpdateTrophy (Handler)"
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  if tDataList.count = 0 then
    return 0
  end if
  if tDataList[#value].ilk <> #symbol then
    return 0
  end if
  tValue = tDataList.value
  if voidp(gGame.SWGameTrophies[tValue]) = 1 then
    return 0
  end if
  if tDataList[#amount].ilk <> #integer then
    return 0
  end if
  gGame.SWGameTrophies[tValue] = gGame.SWGameTrophies[tValue] + tDataList.amount
end
