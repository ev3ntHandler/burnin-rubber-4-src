-- [Script] [PS] 3D Animation (Script #6153)
-- Script Type: Parent

property p
global gSystem, gGame

on new me, tDataList
  p = [:]
  gGame[#animation] = [:]
  gGame.animation[#ModelBoneList] = [:]
  return me
end

on prepareFrame me
  repeat with i in gGame.animation.ModelBoneList
    t = i.model.bonesPlayer.bone[i.bone].worldTransform
    i.object.transform.rotation = t.rotation
    i.object.transform.position = t.position
  end repeat
end

on enterFrame me
end

on delete me
  p = [:]
  gGame.deleteProp(#animation)
  if gSystem.scriptList.getPos(me) <> 0 then
    gSystem.scriptList.deleteOne(me)
  else
    gGame.scriptList.deleteOne(me)
  end if
end
