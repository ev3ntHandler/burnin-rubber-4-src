-- [Script] [M] 3D Light (Script #6149)
-- Script Type: Movie

on createlight me, tTarget, tDataList
end

on SetLight me, tTarget, tDataList
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
  tName = VOID
  if tDataList[#name].ilk = #string then
    tName = tDataList.name
  end if
  if tName = VOID then
    return 0
  end if
  tLight = tmember.light(tName)
  if tLight = VOID then
    return 0
  end if
  tType = tLight.type
  if tDataList[#type].ilk = #symbol then
    tList = [#ambient, #point, #spot, #directional]
    if tList.getPos(tDataList.type) <> 0 then
      tLight.type = tDataList.type
    end if
  end if
  if tLight.type = #ambient then
    if tDataList[#color].ilk = #color then
      tLight.color = tDataList.color
    end if
  end if
  if tLight.type = #directional then
    if tDataList[#color].ilk = #color then
      tLight.color = tDataList.color
    end if
    if tDataList[#specular].ilk = #integer then
      tLight.specular = tDataList.specular
    end if
  end if
  if tLight.type = #point then
    if tDataList[#color].ilk = #color then
      tLight.color = tDataList.color
    end if
    if tDataList[#specular].ilk = #integer then
      tLight.specular = tDataList.specular
    end if
    if tDataList[#attenuation].ilk = #vector then
      tLight.attenuation = tDataList.attenuation
    end if
  end if
  if tLight.type = #spot then
    if tDataList[#color].ilk = #color then
      tLight.color = tDataList.color
    end if
    if tDataList[#specular].ilk = #integer then
      tLight.specular = tDataList.specular
    end if
    if tDataList[#attenuation].ilk = #vector then
      tLight.attenuation = tDataList.attenuation
    end if
    if (tDataList[#spotAngle].ilk = #integer) or (tDataList[#spotAngle].ilk = #float) then
      tLight.spotAngle = tDataList.spotAngle
    end if
    if tDataList[#spotDecay].ilk = #integer then
      tLight.spotDecay = tDataList.spotDecay
    end if
  end if
  return 1
end

on deleteLight me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  if tDataList = VOID then
    tDataList = [#light: "*.*"]
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tTargetList = []
  if tDataList[#light].ilk = #void then
    tDataList[#light] = "*.*"
  end if
  if tDataList[#light].ilk = #list then
    tTargetList = tDataList.light
  else
    if tDataList[#light].ilk = #string then
      if tDataList.light.char[1] = "*" then
        tString = tDataList.light
        if tString <> "*.*" then
          delete tString.char[1]
        end if
        tTargetList = GetObjectList(0, tmember.name, [#type: #light, #string: tString])
      else
        tTargetList.add(tDataList.light)
      end if
    end if
  end if
  if tTargetList.count = 0 then
    return []
  end if
  repeat with i in tTargetList
    tmember.deleteLight(i)
  end repeat
  return 1
end

on DuplicateLight me, tTarget, tDataList
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
  if tDataList[#light].ilk = #void then
    tDataList[#light] = "*.*"
  end if
  if tDataList[#light].ilk = #list then
    tTargetList = tDataList.light
  else
    if tDataList[#light].ilk = #string then
      if tDataList.light.char[1] = "*" then
        tString = tDataList.light
        if tString <> "*.*" then
          delete tString.char[1]
        end if
        tTargetList = GetObjectList(0, tSourceMember.name, [#type: #light, #string: tString])
      else
        tTargetList.add(tDataList.light)
      end if
    end if
  end if
  if tTargetList.count = 0 then
    return []
  end if
  tLightList = []
  tLightTag = VOID
  if tDataList[#lightTag].ilk = #string then
    tLightTag = tDataList.lightTag
  end if
  repeat with i in tTargetList
    tOrigLight = tSourceMember.light(i)
    if tmember.light(tLightTag & tOrigLight.name) <> VOID then
      next repeat
    end if
    tDupLight = tmember.newLight(tLightTag & tOrigLight.name, tOrigLight.type)
    if tOrigLight.type = #ambient then
      tDupLight.color = tOrigLight.color
    end if
    if tOrigLight.type = #directional then
      tDupLight.color = tOrigLight.color
      tDupLight.specular = tOrigLight.specular
      tDupLight.transform = tOrigLight.transform.duplicate()
    end if
    if tOrigLight.type = #point then
      tDupLight.color = tOrigLight.color
      tDupLight.specular = tOrigLight.specular
      tDupLight.attenuation = tOrigLight.attenuation
      tDupLight.transform = tOrigLight.transform.duplicate()
    end if
    if tOrigLight.type = #spot then
      tDupLight.color = tOrigLight.color
      tDupLight.specular = tOrigLight.specular
      tDupLight.attenuation = tOrigLight.attenuation
      tDupLight.spotAngle = tOrigLight.spotAngle
      tDupLight.spotDecay = tOrigLight.spotDecay
      tDupLight.transform = tOrigLight.transform.duplicate()
    end if
    tLightList.add(tDupLight)
  end repeat
  if tLightList.count = 1 then
    return tLightList[1]
  else
    return tLightList
  end if
end
