-- [Script] [PS] Fade (Script #6118)
-- Script Type: Parent

property p
global gSystem, gGame

on new me, tDataList
  p = [:]
  p[#member] = tDataList.member
  p[#FadeMember] = member("DefaultFade")
  p[#camera] = p.FadeMember.camera("Fade_Camera")
  p.camera.colorBuffer.clearAtRender = 0
  p.camera.projection = #orthographic
  p.camera.orthoHeight = gGame.stageSize[2]
  p.camera.transform.position.x = gGame.stageSize[1] * 0.5
  p.camera.transform.position.z = -gGame.stageSize[2] * 0.5
  p[#shader] = p.FadeMember.shader("Fade_Material")
  if tDataList[#hold].ilk = #integer then
    p[#hold] = [0, integer(float(tDataList.hold) / gGame.tempo)]
  else
    p[#hold] = [0, 0]
  end if
  p[#time] = [0, integer(float(tDataList.time) / gGame.tempo)]
  p[#type] = tDataList.type
  if p.type = #out then
    p.shader.blend = 100
  else
    p.shader.blend = 0
  end if
  p.shader.emissive = tDataList.color
  if tDataList.texture <> #none then
    tTexture = p.FadeMember.texture(tDataList.texture)
    if tTexture = VOID then
      tTexture = createTexture(0, "DefaultFade", [])
    end if
    p.shader.texture = tTexture
    p.shader.emissive = rgb(255, 255, 255)
  end if
  p.FadeMember.model("Fade").transform.scale.x = gGame.stageSize[1] + 100
  p.FadeMember.model("Fade").transform.scale.z = gGame.stageSize[2] + 100
  p[#TargetRect] = rect(0, 0, gGame.stageSize[1], gGame.stageSize[2])
  p[#event] = #none
  if (tDataList[#event].ilk = #string) or (tDataList[#event].ilk = #symbol) or (tDataList[#event].ilk = #list) then
    p.event = tDataList.event
  end if
  p[#handler] = #none
  if (tDataList[#handler].ilk = #string) or (tDataList[#handler].ilk = #symbol) or (tDataList[#handler].ilk = #list) then
    p.handler = tDataList.handler
  end if
  gGame.sprite.addCamera(p.camera, gGame.sprite.cameraCount() + 1)
  p.camera.rect = p.TargetRect
  gSystem.FadeScript = me
  return me
end

on prepareFrame me
  if p.time[1] = p.time[2] then
    delete me
  end if
end

on enterFrame me
  if p.hold[1] <> p.hold[2] then
    p.hold[1] = p.hold[1] + 1
  else
    p.time[1] = p.time[1] + 1
    tPerc = float(p.time[1]) / float(p.time[2] - 1)
    tPerc = min(1.0, tPerc)
    if p.type = #out then
      tBlend = 100.0 - (tPerc * 100.0)
    else
      tBlend = tPerc * 100.0
    end if
    tBlend = max(0, min(100, tBlend))
    p.shader.blend = tBlend
  end if
  if p.camera.rect <> p.TargetRect then
    p.camera.rect = p.TargetRect
  end if
end

on UpdateCamera me, tCamera
  gGame.sprite.addCamera(p.camera, gGame.sprite.cameraCount() + 1)
  if p.camera.rect <> p.TargetRect then
    p.camera.rect = p.TargetRect
  end if
end

on delete me
  tSprite = gGame.sprite
  tCount = tSprite.cameraCount()
  tIndex = 0
  repeat with i = 1 to tCount
    if tSprite.camera(i).name = p.camera.name then
      tIndex = i
    end if
  end repeat
  if tIndex > 0 then
    tSprite.deleteCamera(tIndex)
  end if
  p.FadeMember.resetWorld()
  if gSystem.scriptList.getPos(gSystem.FadeScript) <> 0 then
    gSystem.scriptList.deleteOne(gSystem.FadeScript)
  else
    gGame.scriptList.deleteOne(gSystem.FadeScript)
  end if
  gSystem.FadeScript = #none
  if p.handler <> #none then
    if p.handler.ilk = #list then
      repeat with i in p.handler
        sendSprite(0, symbol(i), 0)
      end repeat
    else
      sendSprite(0, symbol(p.handler), 0)
    end if
  end if
  if p.event <> #none then
    if p.event.ilk = #list then
      repeat with i in p.event
        event(0, i)
      end repeat
    else
      event(0, p.event)
    end if
  end if
end
