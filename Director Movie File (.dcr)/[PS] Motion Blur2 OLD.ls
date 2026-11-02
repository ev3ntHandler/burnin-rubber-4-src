-- [Script] [PS] Motion Blur2 OLD (Script #6168)
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
  p[#Passes] = 4
  p[#RenderCounter] = 0
  p[#textures] = []
  p[#shaders] = []
  tBlendStep = 100.0 / p.Passes
  repeat with i = 1 to p.Passes
    tTexture = p.member.newTexture("MotionBlur" & i & "_Texture", #renderTexture, tWidth, tHeight)
    tTexture.quality = #lowFiltered
    tTexture.renderFormat = #rgba8888
    tTexture.updateRTImageOnRender = 0
    p.textures.add(tTexture)
    tShaderName = "MotionBlur" & i & "_Material"
    tShader = p.member.newShader(tShaderName, #standard)
    tShader.specular = rgb(0, 0, 0)
    tShader.emissive = rgb(255, 255, 255)
    tShader.blend = 100 - (-tBlendStep + (i * tBlendStep))
    tShader.texture = tTexture
    p.shaders.add(tShader)
    p.TargetCamera.addOverlay(tTexture, point(0, 0), 0)
    tOverlay = p.member.model[p.member.model.count]
    tOverlay.shaderList = tShader
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
    tSkyBoxMember = member("Skyboxes")
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
    repeat with i = 1 to p.Passes
      p.TargetCamera.overlay[i].scale = 0.0
    end repeat
    p.textures.addAt(1, p.textures[p.textures.count])
    p.textures.deleteAt(p.Passes + 1)
    repeat with i = 1 to p.shaders.count
      p.shaders[i].texture = p.textures[i]
    end repeat
    p.sprite.renderToTexture(p.camera, p.shaders[1].texture)
    member("BloomRTImage").image = p.shaders[1].texture.image
    repeat with i = 3 to tCount
      tCamera = p.sprite.camera(i)
      tCamera.rootNode = tList[i - 2]
    end repeat
    repeat with i = 1 to p.Passes
      p.TargetCamera.overlay[i].scale = 1.0 / p.size
    end repeat
  else
    p.camera.transform = p.TargetCamera.getWorldTransform()
    p.camera.fieldOfView = p.TargetCamera.fieldOfView
    p.camera.yon = p.TargetCamera.yon
    p.sprite.renderToTexture(p.camera, p.texture)
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
  tSkyBoxMember = member("Skyboxes")
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
