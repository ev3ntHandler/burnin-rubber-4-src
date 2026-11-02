-- [Script] [PS] Bloom RT (Script #6167)
-- Script Type: Parent

property p
global gGame, gData, gSystem

on new me, tDataList
  if voidp(gGame[#Bloom]) = 1 then
    return 0
  end if
  if gGame.Bloom = 0 then
    return 0
  end if
  if voidp(gData[#data][#Bloom]) = 1 then
    return 0
  end if
  if voidp(gData[#data][#Bloom][#default]) = 1 then
    return 0
  end if
  p = [:]
  p[#ScriptName] = "[PS] Bloom RT"
  if tDataList[#member].ilk = #string then
    p[#member] = member(tDataList.member)
  else
    p[#member] = VOID
  end if
  if p.member = VOID then
    exit
  end if
  p[#BloomCamera] = p.member.camera("Bloom_Camera")
  if p.BloomCamera = VOID then
    p.BloomCamera = p.member.newCamera("Bloom_Camera")
  end if
  if tDataList[#camera].ilk = #string then
    p[#TargetCamera] = p.member.camera(tDataList.camera)
  else
    p[#TargetCamea] = p.member.camera("DefaultView")
  end if
  tSize = 0.0625
  if getaProp(tDataList, #size).ilk = #float then
    tSize = tDataList[#size]
  end if
  p[#size] = tSize
  p[#sprite] = gGame.sprite
  tWidth = integer(gGame.stageSize[1] * tSize)
  tHeight = integer(gGame.stageSize[2] * tSize)
  p[#rect] = rect(0, 0, tWidth, tHeight)
  if tDataList[#template].ilk = #string then
    tDataList[#template] = symbol(tDataList[#template])
  end if
  if tDataList[#template].ilk = #symbol then
    if voidp(gData.data.Bloom[tDataList.template]) = 0 then
      p[#template] = tDataList.template
    else
      p[#template] = #default
    end if
  end if
  p[#BloomData] = gData.data.Bloom[p.template]
  p[#texture] = p.member.newTexture("Bloom_Texture", #renderTexture, tWidth, tHeight)
  p.texture.quality = #lowFiltered
  p.texture.renderFormat = #rgba8888
  p.texture.updateRTImageOnRender = 1
  p[#BlackImage] = image(p.rect[3], p.rect[4], 32)
  p.BlackImage.fill(p.BlackImage.rect, rgb(0, 0, 0))
  p.texture.image = p.BlackImage
  tShaderName = "Bloom" & string(p.template) & "_Material"
  p[#shader] = p.member.newShader(tShaderName, #standard)
  p.shader.specular = rgb(0, 0, 0)
  p.shader.texture = p.texture
  BlendShader(0, p.member.name, [#shader: tShaderName, #blendMode: #add])
  p.TargetCamera.addOverlay(p.texture, point(0, 0), 0)
  tOverlay = p.member.model[p.member.model.count]
  tOverlay.shaderList = p.shader
  p[#overlay] = p.TargetCamera.overlay.count
  p.TargetCamera.overlay[1].scale = 1.0 / p.size
  p.TargetCamera.rect = rect(0, 0, gGame.stageSize[1], gGame.stageSize[2])
  p[#index] = 3
  if tDataList[#index].ilk = #integer then
    p.index = tDataList.index + 1
  end if
  p.BloomCamera.colorBuffer.clearAtRender = 0
  p.BloomCamera.transform = p.TargetCamera.transform
  p.BloomCamera.fieldOfView = p.TargetCamera.fieldOfView
  p.BloomCamera.yon = p.TargetCamera.yon
  p[#skybox] = 0
  if tDataList[#skybox].ilk = #integer then
    p.skybox = tDataList.skybox
  end if
  if p.skybox = 1 then
    tSkyBoxMember = member("Skyboxes" & gGame.setting)
    if tSkyBoxMember <> VOID then
      if tSkyBoxMember.camera("Skybox1_Camera") = p.sprite.camera(1) then
        p.BloomCamera = p.sprite.camera(1)
      end if
    end if
  end if
  return me
end

on enterFrame me
  if p.skybox = 1 then
    tList = []
    tCount = p.sprite.cameraCount()
    repeat with i = p.index to tCount
      tCamera = p.sprite.camera(i)
      tList.add(tCamera.rootNode)
      tCamera.rootNode = 0
    end repeat
    p.TargetCamera.overlay[p.overlay].scale = 0.0
    p.sprite.renderToTexture(p.BloomCamera, p.texture)
    repeat with i = p.index to tCount
      tCamera = p.sprite.camera(i)
      tCamera.rootNode = tList[i - (p.index - 1)]
    end repeat
    p.TargetCamera.overlay[p.overlay].scale = 1.0 / p.size
  else
    p.BloomCamera.transform = p.TargetCamera.getWorldTransform()
    p.BloomCamera.fieldOfView = p.TargetCamera.fieldOfView
    p.BloomCamera.yon = p.TargetCamera.yon
    p.sprite.renderToTexture(p.BloomCamera, p.texture)
  end if
  tImage = p.texture.image
  tAdjustColorData = p.BloomData.colorFilter
  tBlurData = p.BloomData.blur
  tAdjustFilter = filter(#AdjustColorFilter, tAdjustColorData)
  tBlurFilter = filter(#BlurFilter, tBlurData)
  tImage.applyFilter(tAdjustFilter)
  tImage.applyFilter(tBlurFilter)
  tImage.copyPixels(p.BlackImage, tImage.rect, p.BlackImage.rect, [#blend: 100 - p.BloomData.intensity])
  p.texture.image = tImage
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
  p.member.deleteCamera(p.BloomCamera.name)
  p.member.deleteTexture(p.texture.name)
  p.member.deleteShader(p.shader.name)
  tSkyBoxMember = member("Skyboxes" & gGame.setting)
  if tSkyBoxMember <> VOID then
    if tSkyBoxMember.camera("SkyBoxBloom_Camera") <> VOID then
      tSkyBoxMember.deleteCamera("SkyBoxBloom_Camera")
    end if
  end if
  if voidp(p[#SkyBloomCamera]) = 0 then
    p.member.deleteCamera("SkyBoxBloom_Camera")
  end if
  gGame.deleteProp(#BloomScript)
  if gSystem.scriptList.getPos(me) <> 0 then
    gSystem.scriptList.deleteOne(me)
  else
    gGame.scriptList.deleteOne(me)
  end if
end
