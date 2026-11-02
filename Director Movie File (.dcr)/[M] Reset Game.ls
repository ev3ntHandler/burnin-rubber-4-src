-- [Script] [M] Reset Game (Script #5846)
-- Script Type: Movie

on reset me, tState
  if _player.runMode <> "Plugin" then
    _movie.castLib("Engine").fileName = _movie.path & "Engine.cst"
  end if
  tExcludeList = ["Internal", "Engine", "Game"]
  repeat with i = 1 to _movie.castLib.count
    if tExcludeList.getPos(_movie.castLib[i].name) <> 0 then
      next repeat
      next repeat
    end if
    repeat with j = 1 to _movie.castLib[i].member.count
      tmember = member(_movie.castLib[i].member[j])
      tmember.erase()
    end repeat
  end repeat
  repeat with j = 89 to 500
    tmember = member(j, "Internal")
    if tmember = VOID then
      next repeat
      next repeat
    end if
    tmember.erase()
  end repeat
  _movie.timeoutList = []
  _movie.actorList = []
  clearGlobals()
  tImage = image(8, 8, 32)
  member("Screenshot").image = tImage
  member("StatsTemplate").image = tImage
  member("TrophiesTemplate").image = tImage
  if tState = #save then
    dispatchcommand(35334)
    dispatchcommand(58370)
    dispatchcommand(16390)
    put "[SYSTEM] All is reset @ " & the time & the date & " from Message Window."
  end if
end
