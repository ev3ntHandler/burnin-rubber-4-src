-- [Script] [PS] Lensflare (Script #5920)
-- Script Type: Parent

property p
global gGame

on new me, tDataList
  p = [:]
  tMemberName = EMPTY
  if getaProp(tDataList, #memberName).ilk = #string then
    tMemberName = tDataList[#memberName]
  end if
  p[#member] = member(tDataList[#member])
  if p.member = VOID then
    exit
  end if
  p[#camera] = VOID
  if getaProp(tDataList, #camera).ilk = #string then
    p.camera = p.member.camera(tDataList[#camera])
  end if
  if p.camera = VOID then
    exit
  end if
  p[#light] = p.member.group("World")
  if getaProp(tDataList, #light).ilk = #string then
    p.light = GetReferenceType(0, p.member, tDataList[#light])
  end if
  if p.light = VOID then
    p.light = p.member.group("World")
  end if
  tSpriteNr = gGame.sprite
  p[#sprite] = tSpriteNr
  p[#rect] = rect(0, 0, 800, 450)
  tResource = p.member.newModelResource("SunSphere", #sphere)
  tResource.radius = 100.0
  tmodel = p.member.newModel("SunSphere", tResource)
  tmodel.transform.position = p.light.transform.position
  p[#width] = p.rect.width
  p[#height] = p.rect.height
  p[#XCenter] = p.width / 2
  p[#YCenter] = p.height / 2
  p[#Overlays] = [[1.0, "Lensflare3_Texture", 7.5], [1.0, "Lensflare5_Texture", 3.5], [0.40000000000000002, "Lensflare4_Texture", 1.5], [0.10000000000000001, "Lensflare5_Texture", 2.0], [-0.40000000000000002, "Lensflare4_Texture", 3.0], [-1.0, "Lensflare2_Texture", 3.0]]
  repeat with i in p.Overlays
    tTextureName = i[2]
    if p.member.texture(tTextureName) = VOID then
      createTexture(0, p.member.name, [#texture: tTextureName, #renderFormat: #rgba8888])
    end if
    tTexture = p.member.texture(tTextureName)
    p.camera.addOverlay(tTexture, point(0, 0), 0)
    tOverlay = p.camera.overlay.count
    i[2] = tOverlay
    p.camera.overlay[tOverlay].scale = i[3]
    tScale = i[3]
    tXOffset = integer(member(tTextureName).width * tScale) / -2
    tYOffset = integer(member(tTextureName).height * tScale) / -2
    i.add(point(tXOffset, tYOffset))
  end repeat
  repeat with i in p.Overlays
    p.camera.overlay[i[2]].loc = point(-10000, -10000)
    p.camera.overlay[i[2]].blend = 0
  end repeat
  return me
end

on enterFrame me
  tLightPos = p.light.transform.position
  tCamPos = p.camera.transform.position
  tDirection = tLightPos - tCamPos
  tDirection.normalize()
  tPos = tCamPos + (tDirection * p.camera.yon)
  tOnScreen = p.camera.worldSpaceToSpriteSpace(tPos)
  if tOnScreen = VOID then
    tVisible = 0
  else
    tVisible = 1
  end if
  if tVisible = 1 then
    tDirection = tCamPos - tLightPos
    tMagnitude = tDirection.magnitude
    tOptionList = [#maxNumberOfModels: 1, #levelOfDetail: #detailed]
    tIsectList = p.member.modelsUnderRay(tLightPos, tDirection, tOptionList)
    if tIsectList <> [] then
      if tIsectList[1].distance < tMagnitude then
        tVisible = 0
      end if
    end if
  end if
  if tVisible = 1 then
    tBlend = p.camera.overlay[p.Overlays[1][2]].blend
    if tBlend < 50 then
      tBlend = tBlend + 5
    end if
    if tBlend > 50 then
      tBlend = 50
    end if
    t2dPos = p.camera.worldSpaceToSpriteSpace(tPos)
    tSX = t2dPos[1] - p.XCenter
    tSY = t2dPos[2] - p.YCenter
    repeat with i in p.Overlays
      tpPos = me.CalculateOffset(tSX, tSY, i[1]) + i[4]
      tOverlay = i[2]
      p.camera.overlay[tOverlay].loc = tpPos
      p.camera.overlay[tOverlay].blend = tBlend
    end repeat
  else
    tBlend = p.camera.overlay[p.Overlays[1][2]].blend
    if tBlend > 0 then
      tBlend = tBlend - 10
    end if
    if tBlend < 5 then
      tBlend = 0
    end if
    repeat with i in p.Overlays
      p.camera.overlay[i[2]].blend = tBlend
    end repeat
    if (tBlend = 0) and (p.camera.overlay[p.Overlays[1][2]].loc <> point(-10000, -10000)) then
      repeat with i in p.Overlays
        p.camera.overlay[i[2]].loc = point(-10000, -10000)
      end repeat
    end if
  end if
end

on CalculateOffset me, tSX, tSY, tRatio
  tX = integer(tSX * tRatio) + p.XCenter
  tY = integer(tSY * tRatio) + p.YCenter
  return point(tX, tY)
end
