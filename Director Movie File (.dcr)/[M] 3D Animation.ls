-- [Script] [M] 3D Animation (Script #6152)
-- Script Type: Movie

global gGame

on LinkModelToBone me, tTarget, tDataList
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
  tObject = VOID
  if tDataList[#object].ilk = #string then
    tObject = GetReferenceType(0, tmember, tDataList.object)
  else
    if tDataList[#object].ilk = #model then
      tObject = tDataList.object
    end if
  end if
  if tObject = VOID then
    return 0
  end if
  tmodel = VOID
  if tDataList[#model].ilk = #string then
    tmodel = GetReferenceType(0, tmember, tDataList.model)
  else
    if tDataList[#model].ilk = #model then
      tObject = tDataList.object
    end if
  end if
  if tmodel = VOID then
    return 0
  end if
  tModList = tmodel.modifier
  if tModList.getPos(#bonesPlayer) = 0 then
    return 0
  end if
  tBone = VOID
  if tDataList[#bone].ilk = #string then
    tBone = tmodel.resource.getBoneId(tDataList.bone)
  else
    if tDataList[#bone].ilk = #integer then
      tBone = tDataList.bone
    end if
  end if
  if tBone = VOID then
    return 0
  end if
  if voidp(gGame[#animation]) = 1 then
    AddScript(0, EMPTY, [#script: "[PS] 3D Animation", #data: [:]])
  end if
  gGame.animation.ModelBoneList[symbol(tObject.name)] = [#object: tObject, #model: tmodel, #bone: tBone]
end

on UnlinkModelFromBone me, tTarget, tDataList
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
  tObject = VOID
  if tDataList[#object].ilk = #string then
    tObject = tDataList.object
  end if
  if tObject = VOID then
    return 0
  end if
  if voidp(gGame.animation.ModelBoneList[symbol(tObject)]) = 0 then
    gGame.animation.ModelBoneList.deleteProp(symbol(tObject))
  end if
end

on CloneAnimation me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return []
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return []
  end if
  tSourceMember = VOID
  if tDataList[#sourceMember].ilk = #string then
    tSourceMember = member(tDataList.sourceMember)
  end if
  if tSourceMember = VOID then
    return []
  end if
  if tSourceMember = tmember then
    return []
  end if
  tTag = EMPTY
  if tDataList[#NameTag].ilk = #string then
    tTag = tDataList.NameTag
  end if
  tCount = tSourceMember.motion.count
  tOldDelimiter = the itemDelimiter
  the itemDelimiter = "-"
  repeat with i = 1 to tCount
    tMotion = tSourceMember.motion[i]
    if tMotion.name = "DefaultMotion" then
      next repeat
      next repeat
    end if
    tSourceName = tMotion.name
    tName = tSourceName.item[1] & tTag & "-" & tSourceName.item[2]
    if tmember.motion(tName) = VOID then
      tmember.cloneMotionFromCastmember(tName, tMotion.name, tSourceMember)
    end if
  end repeat
  the itemDelimiter = tOldDelimiter
end
