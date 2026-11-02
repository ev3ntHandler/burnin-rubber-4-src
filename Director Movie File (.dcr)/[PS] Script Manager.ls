-- [Script] [PS] Script Manager (Script #6107)
-- Script Type: Parent

global gGame, gSystem

on new me, tParams
  return me
end

on prepareFrame me
  call(#prepareFrame, gSystem.scriptList)
  if gGame.pause = 1 then
    exit
  end if
  call(#prepareFrame, gGame.scriptList)
end

on enterFrame me
  call(#enterFrame, gSystem.scriptList)
  if gGame.pause = 1 then
    exit
  end if
  call(#enterFrame, gGame.scriptList)
  RunHandlerList()
  EvalTriggers()
  UpdateTimers()
end

on exitFrame me
  gSystem.frame = gSystem.frame + 1
end

on keyUp me
  KeyHandler(0, _key.key)
  KeyHandler(0, _key.keyCode)
end

on keyDown me
end

on mouseUp me
end

on mouseDown me
end

on delete me
end
