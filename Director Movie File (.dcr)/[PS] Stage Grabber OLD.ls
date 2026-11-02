-- [Script] [PS] Stage Grabber OLD (Script #6165)
-- Script Type: Parent

property p
global gGame, gSystem

on new me, tParams
  p = [:]
  p[#ScriptName] = "StageGrabber"
  gGame[#StageImage] = (the stage).image
  return me
end

on enterFrame me
  gGame.StageImage = (the stage).image
end

on delete me
  gGame.StageImage = VOID
  gGame.deleteProp(#StageImage)
  if gSystem.scriptList.getPos(me) <> 0 then
    gSystem.scriptList.deleteOne(me)
  else
    gGame.scriptList.deleteOne(me)
  end if
end
