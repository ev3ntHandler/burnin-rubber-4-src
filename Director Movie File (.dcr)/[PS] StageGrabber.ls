-- [Script] [PS] StageGrabber (Script #6169)
-- Script Type: Parent

property p
global gGame, gData, gSystem

on new me, tDataList
  p = [:]
  p[#ScriptName] = "[PS] StageGrabber"
  if tDataList[#member].ilk = #string then
    p[#member] = member(tDataList.member)
  else
    p[#member] = VOID
  end if
  if p.member = VOID then
    exit
  end if
  p[#camera] = p.member.camera("StageGrabber_Camera")
  if p.camera = VOID then
    p.camera = p.member.newCamera("StageGrabber_Camera")
  end if
  if tDataList[#camera].ilk = #string then
    p[#TargetCamera] = p.member.camera(tDataList.camera)
  else
    p[#TargetCamera] = p.member.camera("Player1_Camera")
  end if
  p[#size] = 0.5
  if not voidp(gGame[#MotionBlurQuality]) then
    if gGame.MotionBlurQuality = #low then
      p.size = 0.25
    end if
  end if
  if getaProp(tDataList, #size).ilk = #float then
    p.size = tDataList[#size]
  end if
  p[#sprite] = sprite(gGame.sprite)
  tSourceList = [32, 64, 128, 256, 512, 1024, 2048]
  tSourceList.sort()
  tWidth = tSourceList.duplicate()
  tWidth.add(integer(gGame.resolution[1] * p.size))
  tPos = min(tWidth.count, tWidth.getPos(integer(gGame.resolution[1] * p.size)) + 1)
  tWidth = tWidth[tPos]
  tHeight = tSourceList.duplicate()
  tHeight.add(integer(gGame.resolution[2] * p.size))
  tPos = min(tHeight.count, tHeight.getPos(integer(gGame.resolution[2] * p.size)) + 1)
  tHeight = tHeight[tPos]
  if tWidth = tHeight then
    put "AANGEPASTE WIDTH!"
    tWidth = tWidth * 2
  end if
  tWidth = integer(gGame.resolution[1] * p.size)
  tHeight = integer(gGame.resolution[2] * p.size)
  p[#texture] = p.member.newTexture("StageGrabber_Texture", #renderTexture, tWidth, tHeight)
  p.texture.quality = #lowFiltered
  p.texture.renderFormat = #rgba8888
  tWidth = integer(gGame.resolution[1] * (gGame.BloomSize * 1))
  tHeight = integer(gGame.resolution[2] * (gGame.BloomSize * 1))
  p[#BloomTexture] = p.member.newTexture("StageGrabberBloom_Texture", #renderTexture, tWidth, tHeight)
  p.BloomTexture.quality = #lowFiltered
  p.BloomTexture.renderFormat = #rgba8888
  p.BloomTexture.updateRTImageOnRender = 1
  p.camera.colorBuffer.clearAtRender = 0
  p.camera.transform = p.TargetCamera.transform
  p.camera.fieldOfView = p.TargetCamera.fieldOfView
  p.camera.yon = p.TargetCamera.yon
  p[#update] = 1
  tSkyBoxMember = member("Skyboxes" & gGame.setting)
  if tSkyBoxMember <> VOID then
    tSkyboxCamera = tSkyBoxMember.camera("Skybox1_Camera")
    if tSkyboxCamera <> VOID then
      if tSkyBoxMember.camera("Skybox1_Camera") = p.sprite.camera(1) then
        p.member.deleteCamera("StageGrabber_Camera")
        p.camera = p.sprite.camera(1)
        p.camera.yon = 1500.0
        p.update = 0
      end if
    end if
  end if
  gGame[#StageTexture] = p.texture
  gGame[#BloomTexture] = p.BloomTexture
  p[#MotionBlur] = VOID
  return me
end

on enterFrame me
  tList = []
  tCount = p.sprite.cameraCount()
  repeat with i = 3 to tCount
    tCamera = p.sprite.camera(i)
    tList.add(tCamera.rootNode)
    tCamera.rootNode = 0
  end repeat
  tScaleList = []
  repeat with i = 1 to p.TargetCamera.overlay.count
    tScaleList.add(p.TargetCamera.overlay[i].scale)
    p.TargetCamera.overlay[i].scale = 0.0
  end repeat
  if p.update then
    p.camera.transform = p.TargetCamera.transform
    p.camera.fieldOfView = p.TargetCamera.fieldOfView
    p.camera.yon = p.TargetCamera.yon
  end if
  if gGame.MotionBlur = 1 then
    if p.MotionBlur = VOID then
      p.MotionBlur = GetScript(0, EMPTY, [#script: "[PS] Motion Blur"])
    end if
    if not p.MotionBlur = VOID then
      if p.MotionBlur.p.BlendMultiplier > 0.01 then
        tSourceYon = p.TargetCamera.yon
        p.TargetCamera.yon = 100.0
        p.sprite.renderToTexture(p.camera, p.texture)
        p.TargetCamera.yon = tSourceYon
      end if
    end if
  end if
  if gGame.Bloom = 1 then
    tSourceYon = p.TargetCamera.yon
    if tSourceYon > p.TargetCamera.yon then
      p.TargetCamera.yon = 1500
    end if
    p.sprite.renderToTexture(p.camera, p.BloomTexture)
    p.TargetCamera.yon = tSourceYon
  end if
  repeat with i = 3 to tCount
    tCamera = p.sprite.camera(i)
    tCamera.rootNode = tList[i - 2]
  end repeat
  repeat with i = 1 to p.TargetCamera.overlay.count
    p.TargetCamera.overlay[i].scale = tScaleList[i]
  end repeat
end

on delete me
  gGame.deleteProp(#StageTexture)
  gGame.deleteProp(#BloomTexture)
  if p.camera <> VOID then
    p.member.deleteCamera(p.camera.name)
  end if
  if p.texture <> VOID then
    p.member.deleteTexture(p.texture.name)
  end if
  if p.BloomTexture <> VOID then
    p.member.deleteTexture(p.BloomTexture.name)
  end if
  if gSystem.scriptList.getPos(me) <> 0 then
    gSystem.scriptList.deleteOne(me)
  else
    gGame.scriptList.deleteOne(me)
  end if
end
