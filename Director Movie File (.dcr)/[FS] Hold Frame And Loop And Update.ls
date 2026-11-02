-- [Script] [FS] Hold Frame And Loop And Update (Script #5849)
-- Script Type: Behavior

global gSystem, gGame

on prepareFrame me
  gSystem.ScriptManager.prepareFrame()
end

on enterFrame me
  gSystem.ScriptManager.enterFrame()
  if (_key.commandDown = 1) and keyPressed("i") then
    ShowVersion()
  end if
  if _player.runMode = "Projector" then
    if (_key.commandDown = 1) and keyPressed("q") then
      _player.quit()
    end if
    if (_key.optionDown = 1) and _key.keyPressed(RETURN) then
      fullscreen()
    end if
  end if
end

on mouseUp me
  gSystem.ScriptManager.mouseUp()
end

on mouseDown me
  gSystem.ScriptManager.mouseDown()
end

on keyUp me
  gSystem.ScriptManager.keyUp()
end

on keyDown me
  gSystem.ScriptManager.keyDown()
end

on exitFrame me
  _movie.go(_movie.frame)
  if gGame.frameRate = #free then
    if _movie.frameTempo <> 999 then
      _movie.puppetTempo(999)
    end if
  else
    if _movie.frameTempo <> gGame.tempo then
      _movie.puppetTempo(gGame.tempo)
    end if
  end if
end
