-- [Script] [M] Preload Cast (Script #6111)
-- Script Type: Movie

global gGame

on preloadCast me, tTarget, tDataList
  MyUnloadCast(0, "Assets")
  _movie.castLib("Assets").fileName = _movie.path & "Assets.cst"
  MyUnloadCast(0, "World")
  _movie.castLib("World").fileName = _movie.path & "World.cst"
  clearMemory()
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  if voidp(tDataList[#data]) = 1 then
    return 0
  end if
  if tDataList[#data].ilk = #string then
    tDataList.date = symbol(tDataList.data)
  end if
  if tDataList[#data].ilk = #symbol then
    if voidp(gGame[tDataList[#data]]) = 0 then
      tDataList.data = gGame[tDataList.data]
    end if
  end if
  if tDataList[#data].ilk <> #propList then
    return 0
  end if
  if (tDataList[#event].ilk = #string) or (tDataList[#event].ilk = #symbol) then
    nothing()
  else
    return 0
  end if
  tScript = new(script("[PS] Preload Cast"), tDataList)
  if tScript <> VOID then
    _movie.actorList.add(tScript)
  else
    LogMessage(0, "PreloadCast. Missing error message")
  end if
end
