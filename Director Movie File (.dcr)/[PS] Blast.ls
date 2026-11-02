-- [Script] [PS] Blast (Script #6162)
-- Script Type: Parent

property p
global gSystem, gGame

on new me, tDataList
  p = [:]
  return me
end

on enterFrame me
  put "Blast done and deleted"
  delete me
end

on delete me
  p = [:]
  if gSystem.scriptList.getPos(me) <> 0 then
    gSystem.scriptList.deleteOne(me)
  else
    gGame.scriptList.deleteOne(me)
  end if
end
