-- [Script] [M] Init Game (Script #5845)
-- Script Type: Movie

global gSystem

on prepareMovie me
  tMessageWindow = 1
  _player.debugPlaybackEnabled = tMessageWindow
  tAlert = 0
  _player.alertHook = 0
  if tAlert = 1 then
    _player.alertHook = script("[PS] Game Alert").new()
  end if
end

on startMovie me
  put "-----------------------------------------------------------------------------------------------"
  put "[SYSTEM]" & TAB & "Movie started at @ " & _system.time() & _system.date() & "."
  InitEngine()
end

on stopMovie me
  if _player.runMode = "Plugin" then
    return 0
  end if
  if voidp(gSystem) = 0 then
    ResetEngine()
  end if
  reset()
  put "[SYSTEM]" & TAB & "Movie stopped at @ " & _system.time() & _system.date() & "."
  put "-----------------------------------------------------------------------------------------------"
end

on GameQuit me
  _player.quit()
end

on closeRequest
  if _key.keyPressed(53) = 1 then
    nothing()
  else
    halt()
  end if
end
