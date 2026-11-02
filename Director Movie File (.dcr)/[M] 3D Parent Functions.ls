-- [Script] [M] 3D Parent Functions (Script #6144)
-- Script Type: Movie

on StoreParent me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return []
  end if
  tCount = tmember.model.count
  repeat with i = 1 to tCount
    tmodel = tmember.model[i]
    tUD = tmodel.userData
    tUD[#parent] = tmodel.parent
  end repeat
end

on SetParent me, tTarget, tDataList
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
  tProp = #model
  if voidp(tDataList[#group]) = 0 then
    tProp = #group
  end if
  if voidp(tDataList[#light]) = 0 then
    tProp = #light
  end if
  if voidp(tDataList[#camera]) = 0 then
    tProp = #camera
  end if
  tTargetList = []
  if tDataList[tProp].ilk = #void then
    tDataList[#model] = "*.*"
  end if
  if tDataList[tProp].ilk = #list then
    tTargetList = tDataList[tProp]
    tList = []
    repeat with i in tTargetList
      if tProp = #model then
        tEntry = tmember.model(i)
      end if
      if tProp = #group then
        tEntry = tmember.group(i)
      end if
      if tProp = #light then
        tEntry = tmember.light(i)
      end if
      if tProp = #camera then
        tEntry = tmember.camera(i)
      end if
      if tEntry <> VOID then
        tList.add(tEntry)
      end if
    end repeat
    tTargetList = tList.duplicate()
  else
    if tDataList[tProp].ilk = #string then
      if tDataList[tProp].char[1] = "*" then
        tString = tDataList[tProp]
        if tString <> "*.*" then
          delete tString.char[1]
        end if
        tTargetList = GetObjectList(0, tmember.name, [#type: tProp, #string: tString, #Reference: 1])
      else
        if tProp = #model then
          tTargetList.add(tmember.model(tDataList[tProp]))
        end if
        if tProp = #group then
          tTargetList.add(tmember.group(tDataList[tProp]))
        end if
        if tProp = #light then
          tTargetList.add(tmember.light(tDataList[tProp]))
        end if
        if tProp = #camera then
          tTargetList.add(tmember.camera(tDataList[tProp]))
        end if
      end if
    end if
  end if
  if tTargetList.count = 0 then
    return []
  end if
  tParent = VOID
  if tDataList[#parent].ilk = #string then
    tParent = GetReferenceType(tmember, tDataList.parent)
  end if
  if tDataList[#parent].ilk = #symbol then
    tParent = tDataList.parent
  end if
  if tParent = VOID then
    return 0
  end if
  repeat with i in tTargetList
    if tParent = #none then
      i.parent = VOID
      next repeat
    end if
    i.transform = tParent.getWorldTransform().inverse() * i.transform
    i.parent = tParent
  end repeat
end
