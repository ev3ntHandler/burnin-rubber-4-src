-- [Script] [PS] Alert (Script #5853)
-- Script Type: Parent

global gGame, gSystem, gData, gSound

on new me
  return me
end

on alertHook me, err, Msg
  if void(gSound) = 0 then
    StopAllSound()
  end if
  if void(gGame) = 0 then
    gGame.scriptList = []
  end if
  if void(gSystem) = 0 then
    gSystem.scriptList = []
  end if
  repeat with i = 1 to 10
    sprite(i).visible = 0
    sprite(i).loc = point(-1000, -1000)
  end repeat
  (the stage).bgColor = (the stage).bgColor
  _movie.updateStage()
  _movie.puppetSprite(10, 1)
  tSprite = sprite(10)
  tSprite.member = member("alertHookText")
  tSprite.visible = 1
  tSprite.member.text = err & RETURN & Msg
  tSprite.loc = point(0, 0)
  (the stage).bgColor = (the stage).bgColor
  _movie.updateStage()
  return 1
end
