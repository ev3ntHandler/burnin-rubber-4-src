-- [Script] [M] 3D Group (Script #6150)
-- Script Type: Movie

on CreateGroup me, tTarget, tDataList
end

on deleteGroup me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  if tDataList = VOID then
    tDataList = [#group: "*.*"]
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tTargetList = []
  if tDataList[#group].ilk = #void then
    tDataList[#group] = "*.*"
  end if
  if tDataList[#group].ilk = #list then
    tTargetList = tDataList.group
  else
    if tDataList[#group].ilk = #string then
      if tDataList.group.char[1] = "*" then
        tString = tDataList.group
        if tString <> "*.*" then
          delete tString.char[1]
        end if
        tTargetList = GetObjectList(0, tmember.name, [#type: #group, #string: tString])
      else
        tTargetList.add(tDataList.group)
      end if
    end if
  end if
  if tTargetList.count = 0 then
    return 0
  end if
  repeat with i in tTargetList
    if i = "World" then
      next repeat
    end if
    tmember.deleteGroup(i)
  end repeat
  return 1
end

on DuplicateGroup me, tTarget, tDataList
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
  tSourceMember = tmember
  if tDataList[#sourceMember].ilk = #string then
    tSourceMember = member(tDataList.sourceMember)
  end if
  tTargetList = []
  if tDataList[#group].ilk = #void then
    tDataList[#group] = "*.*"
  end if
  if tDataList[#group].ilk = #list then
    tTargetList = tDataList.group
  else
    if tDataList[#group].ilk = #string then
      if tDataList.group.char[1] = "*" then
        tString = tDataList.group
        if tString <> "*.*" then
          delete tString.char[1]
        end if
        tTargetList = GetObjectList(0, tSourceMember.name, [#type: #group, #string: tString])
      else
        tTargetList.add(tDataList.group)
      end if
    end if
  end if
  if tTargetList.count = 0 then
    return []
  end if
  tGroupList = []
  tGroupTag = VOID
  if tDataList[#groupTag].ilk = #string then
    tGroupTag = tDataList.groupTag
  end if
  repeat with i in tTargetList
    if i = "World" then
      next repeat
    end if
    tOrigGroup = tSourceMember.group(i)
    if tmember.group(tGroupTag & tOrigGroup.name) <> VOID then
      next repeat
    end if
    tDupGroup = tmember.newGroup(tGroupTag & tOrigGroup.name)
    tDupGroup.transform = tOrigGroup.transform.duplicate()
    tGroupList.add(tDupGroup)
  end repeat
  if tGroupList.count = 1 then
    return tGroupList[1]
  else
    return tGroupList
  end if
end
