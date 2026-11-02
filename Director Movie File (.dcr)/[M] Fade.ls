-- [Script] [M] Fade (Script #6117)
-- Script Type: Movie

global gGame, gSystem

on Fade me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  if tmember.type <> #shockwave3d then
    LogMessage(0, "This fade function is currently only supported for 3d members")
    return 0
  end if
  if gSystem.FadeScript <> #none then
    delete gSystem.FadeScript
  end if
  tDataList[#member] = tmember
  if tDataList[#time].ilk <> #integer then
    tDataList[#time] = 1000
  end if
  tTypeList = [#out, #in]
  if tDataList[#type].ilk <> #symbol then
    tDataList[#type] = #out
  else
    if tTypeList.getPos(tDataList.type) <> 0 then
      tDataList[#type] = tDataList.type
    else
      tDataList[#type] = #out
    end if
  end if
  if tDataList[#color].ilk <> #color then
    tDataList[#color] = rgb(0, 0, 0)
  end if
  if tDataList[#texture].ilk <> #string then
    tDataList[#texture] = #none
  end if
  tLocList = [#game, #system]
  if tDataList[#location].ilk <> #symbol then
    tDataList[#location] = #system
  else
    if tLocList.getPos(tDataList.location) <> 0 then
      tDataList[#location] = tDataList.location
    else
      tDataList[#location] = #system
    end if
  end if
  if (tDataList[#event].ilk = #string) or (tDataList[#event].ilk = #symbol) or (tDataList[#event].ilk = #list) then
    tDataList[#event] = tDataList.event
  end if
  clearMemory()
  tScript = script("[PS] Fade").new(tDataList)
  if tDataList.location = #game then
    gGame.scriptList.add(tScript)
  else
    gSystem.scriptList.add(tScript)
  end if
  if tScript = VOID then
    return 0
  else
    return 1
  end if
end
