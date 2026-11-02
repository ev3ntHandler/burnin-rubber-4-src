-- [Script] [PS] Motion Blur OLD 2 (Script #5921)
-- Script Type: Parent

property p
global gGame, gData, gSystem

on new me, tDataList
  p = [:]
  p[#ScriptName] = "[PS] Motion Blur"
  if tDataList[#member].ilk = #string then
    p[#member] = member(tDataList.member)
  else
    p[#member] = VOID
  end if
  if p.member = VOID then
    exit
  end if
  p[#camera] = p.member.camera("MotionBlur_Camera")
  if p.camera = VOID then
    p.camera = p.member.newCamera("MotionBlur_Camera")
  end if
  if tDataList[#camera].ilk = #string then
    p[#TargetCamera] = p.member.camera(tDataList.camera)
  else
    p[#TargetCamea] = p.member.camera("DefaultView")
  end if
  tSize = 1.0
  if getaProp(tDataList, #size).ilk = #float then
    tSize = tDataList[#size]
  end if
  p[#size] = tSize
  p[#sprite] = gGame.sprite
  tWidth = integer(gGame.stageSize[1] * tSize)
  tHeight = integer(gGame.stageSize[2] * tSize)
  p[#rect] = rect(0, 0, tWidth, tHeight)
  p[#Passes] = 7
  if tDataList[#Passes].ilk = #integer then
    p.Passes = tDataList.Passes - 1
  end if
  p[#RenderCounter] = 0
  p[#shaders] = []
  p[#Overlays] = []
  p[#scaleOffset] = 0.025
  if (tDataList[#scaleOffset].ilk = #float) or (tDataList[#scaleOffset].ilk = #integer) then
    p.scaleOffset = tDataList.scaleOffset
  end if
  tBlendStep = 100.0 / (p.Passes + 1.0)
  p[#Percentage] = 1.0
  if tDataList[#percVar].ilk = #string then
    if value(tDataList.percVar).ilk = #float then
      p.Percentage = tDataList.percVar
    end if
  end if
  p[#xOffset] = 0.0
  p[#Yoffset] = 0.0
  p[#texture] = p.member.newTexture("MotionBlur_Texture", #renderTexture, tWidth, tHeight)
  p.texture.quality = #lowFiltered
  p.texture.renderFormat = #rgba8888
  p.texture.updateRTImageOnRender = 0
  repeat with i = 1 to p.Passes
    tShaderName = "MotionBlur" & i & "_Material"
    tShader = p.member.newShader(tShaderName, #standard)
    tShader.specular = rgb(0, 0, 0)
    tShader.emissive = rgb(255, 255, 255)
    tShader.blend = 100 - (i * tBlendStep)
    tShader.texture = p.texture
    tShader.textureTransformList[1].scale = vector(1.0, 1.0, 1.0) + vector(i * p.scaleOffset, i * p.scaleOffset, 0.0)
    tShader.textureTransformList[1].position = vector(0.0, 0.0, 0.0) - vector(i * p.scaleOffset * 0.5, i * p.scaleOffset * 0.5, 0.0)
    p.shaders.add(tShader)
    p.TargetCamera.addOverlay(p.texture, point(0, 0), 0)
    tOverlay = p.member.model[p.member.model.count]
    tOverlay.shaderList = tShader
    p.Overlays.add(p.TargetCamera.overlay.count)
    p.TargetCamera.overlay[i].scale = 1.0 / p.size
    p.TargetCamera.rect = rect(0, 0, gGame.stageSize[1], gGame.stageSize[2])
  end repeat
  p.camera.colorBuffer.clearAtRender = 0
  p.camera.transform = p.TargetCamera.transform
  p.camera.fieldOfView = p.TargetCamera.fieldOfView
  p.camera.yon = p.TargetCamera.yon
  p[#skybox] = 0
  if tDataList[#skybox].ilk = #integer then
    p.skybox = tDataList.skybox
  end if
  if p.skybox = 1 then
    tSkyBoxMember = member("Skyboxes" & gGame.setting)
    if tSkyBoxMember <> VOID then
      if tSkyBoxMember.camera("Skybox1_Camera") = p.sprite.camera(1) then
        p.camera = p.sprite.camera(1)
      end if
    end if
  end if
  return me
end

on enterFrame me
  if p.skybox = 1 then
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
    p.sprite.renderToTexture(p.camera, p.texture)
    if p.texture.updateRTImageOnRender = 1 then
      member("MotionBlurRTImage").image = p.texture.image
    end if
    tPerc = value(p.Percentage)
    tPercScaleOffSet = max(0.0, (tPerc - 0.10000000000000001) * p.scaleOffset)
    tSpeedOffset = gGame.camera[1].direction * gGame.camera[1].Speed * 0.001
    tSpeedOffset = vector(tSpeedOffset.x, 0.0, 0.0)
    repeat with i = 1 to p.shaders.count
      tShader = p.shaders[i]
      tScaleOffSet = i * tPercScaleOffSet
      tPosXOffset = p.xOffset * i
      tPosYOffset = p.Yoffset * i
      tShader.textureTransformList[1].scale = vector(1.0, 1.0, 1.0) + vector(tScaleOffSet, tScaleOffSet, 0.0)
      tShader.textureTransformList[1].position = vector(0.0, 0.0, 0.0) - vector((tScaleOffSet * 0.5) + tPosXOffset, (tScaleOffSet * 0.5) + tPosYOffset, 0.0)
    end repeat
    repeat with i = 3 to tCount
      tCamera = p.sprite.camera(i)
      tCamera.rootNode = tList[i - 2]
    end repeat
    repeat with i = 1 to p.TargetCamera.overlay.count
      p.TargetCamera.overlay[i].scale = tScaleList[i]
    end repeat
  else
    p.camera.transform = p.TargetCamera.getWorldTransform()
    p.camera.fieldOfView = p.TargetCamera.fieldOfView
    p.camera.yon = p.TargetCamera.yon
    p.sprite.renderToTexture(p.camera, p.texture)
    if p.texture.updateRTImageOnRender = 1 then
      member("MotionBlurRTImage").image = p.texture.image
    end if
    repeat with i = 1 to p.shaders.count
      tShader = p.shaders[i]
      tShader.textureTransformList[1].scale = vector(1.0, 1.0, 1.0) + vector(i * p.scaleOffset, i * p.scaleOffset, 0.0)
      tShader.textureTransformList[1].position = vector(0.0, 0.0, 0.0) - vector(i * p.scaleOffset * 0.5, i * p.scaleOffset * 0.5, 0.0)
    end repeat
  end if
end

on delete me
  tIndex = []
  repeat with i = 1 to p.TargetCamera.overlay.count
    if p.TargetCamera.overlay[i].source = p.texture then
      tIndex.add(i)
    end if
  end repeat
  repeat with i in tIndex
    p.TargetCamera.removeOverlay(i)
  end repeat
  p.member.deleteCamera(p.camera.name)
  p.member.deleteTexture(p.texture.name)
  p.member.deleteShader(p.shader.name)
  tSkyBoxMember = member("Skyboxes" & gGame.setting)
  if tSkyBoxMember <> VOID then
    if tSkyBoxMember.camera("SkyBoxBloom_Camera") <> VOID then
      tSkyBoxMember.deleteCamera("SkyBoxBloom_Camera")
    end if
  end if
  if voidp(p[#SkyCamera]) = 0 then
    p.member.deleteCamera("SkyBoxBloom_Camera")
  end if
  gGame.deleteProp(#BloomScript)
  if gSystem.scriptList.getPos(me) <> 0 then
    gSystem.scriptList.deleteOne(me)
  else
    gGame.scriptList.deleteOne(me)
  end if
end
