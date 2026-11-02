-- [Script] [PS] Bloom OLD (Script #6166)
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
  p[#ScriptName] = "[PS] Bloom"
  if tDataList[#member].ilk = #string then
    p[#member] = member(tDataList.member)
  else
    p[#member] = VOID
  end if
  if p.member = VOID then
    exit
  end if
  if voidp(gGame[#StageImage]) = 1 then
    AddScript(0, EMPTY, [#script: "[PS] Stage Grabber", #data: [:]])
  end if
  p[#SourceCamera] = p.member.camera("RTTBloomCamera")
  if p.SourceCamera = VOID then
    p.SourceCamera = p.member.newCamera("RTTBloomCamera")
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
  p[#sprite] = sprite(GetEmptyChannel())
  tWidth = integer(gGame.stageSize[1] * tSize)
  tHeight = integer(gGame.stageSize[2] * tSize)
  p[#rect] = rect(0, 0, tWidth, tHeight)
  p[#loc] = point(integer(tWidth / 2), integer(tHeight / 2))
  CreateSprite(0, p.member.name, [#channel: p.sprite.spriteNum, #dts: 0])
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
  tTextureName = "Bloom" & string(p.template) & "_Texture"
  if p.member.texture(tTextureName) = VOID then
    p[#texture] = p.member.newTexture(tTextureName)
  end if
  p.texture.quality = #lowFiltered
  p.texture.renderFormat = #rgba8888
  p[#BlackImage] = image(p.rect[3], p.rect[4], 32)
  p.BlackImage.fill(p.BlackImage.rect, rgb(0, 0, 0))
  p.texture.image = p.BlackImage
  tShaderName = "Bloom" & string(p.template) & "_Material"
  p[#shader] = p.member.newShader(tShaderName, #standard)
  p.shader.specular = rgb(0, 0, 0)
  p.shader.texture = p.texture
  BlendShader(0, p.member.name, [#shader: tShaderName, #blendMode: #add])
  tResult = p.TargetCamera.addOverlay(p.texture, point(0, 0), 0)
  p.TargetCamera.overlay[1].scale = 1.0 / p.size
  p.TargetCamera.rect = rect(0, 0, gGame.stageSize[1], gGame.stageSize[2])
  if p.SourceCamera.name <> "DefaultView" then
    SetActiveCamera(0, p.sprite, [#camera: p.SourceCamera.name])
  end if
  p.SourceCamera.colorBuffer.clearAtRender = 0
  p.SourceCamera.transform = p.TargetCamera.transform
  p.SourceCamera.fieldOfView = p.TargetCamera.fieldOfView
  p.SourceCamera.yon = p.TargetCamera.yon
  p[#SkyBloomCamera] = #none
  if tDataList[#skybox].ilk = #integer then
    tSkybox = tDataList.skybox
  else
    tSkybox = 0
  end if
  if tSkybox = 1 then
    tSkyBoxMember = member("Skyboxes")
    if tSkyBoxMember <> VOID then
      p.SkyBloomCamera = tSkyBoxMember.newCamera("SkyBoxBloom_Camera")
      p.SkyBloomCamera.rootNode = tSkyBoxMember.group("SkyBox_Group")
      p.sprite.addCamera(p.SkyBloomCamera, 1)
      p.SkyBloomCamera.rect = rect(0, 0, p.rect[3], p.rect[4])
      p.SkyBloomCamera.transform = p.TargetCamera.transform
      p.SkyBloomCamera.transform.position = vector()
      p.SkyBloomCamera.fieldOfView = p.TargetCamera.fieldOfView
      p.SkyBloomCamera.yon = 1500.0
      p.SourceCamera.rect = p.rect
    end if
  end if
  p[#state] = #resize
  return me
end

on enterFrame me
  if p.state = #resize then
    p.sprite.width = p.rect[3]
    p.sprite.height = p.rect[4]
    p.sprite.loc = p.loc
    tList = []
    tList.sort()
    repeat with i = 1 to p.member.model.count
      tmodel = p.member.model(i)
      if tmodel.name contains "Overlay" then
        tList.add(tmodel)
      end if
    end repeat
    p[#overlay] = tList[tList.count]
    put p.overlay
    p.overlay.shaderList = p.shader
    p.state = #render
  end if
  p.SourceCamera.transform = p.TargetCamera.getWorldTransform()
  p.SourceCamera.fieldOfView = p.TargetCamera.fieldOfView
  p.SourceCamera.yon = p.TargetCamera.yon
  if voidp(p[#SkyBloomCamera]) = 0 then
    tTransform = p.TargetCamera.getWorldTransform()
    p.SkyBloomCamera.transform.position.z = tTransform.position.z
    p.SkyBloomCamera.transform.rotation = tTransform.rotation
    p.SkyBloomCamera.fieldOfView = p.SourceCamera.fieldOfView
  end if
  tImage = gGame.StageImage.crop(p.sprite.rect)
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
  _movie.puppetSprite(p.sprite.spriteNum, 0)
  tIndex = []
  repeat with i = 1 to p.TargetCamera.overlay.count
    if p.TargetCamera.overlay[i].source = p.texture then
      tIndex.add(i)
    end if
  end repeat
  repeat with i in tIndex
    p.TargetCamera.removeOverlay(i)
  end repeat
  p.member.deleteCamera(p.SourceCamera.name)
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
