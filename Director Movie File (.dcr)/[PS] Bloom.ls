-- [Script] [PS] Bloom (Script #6170)
-- Script Type: Parent

property p
global gGame, gData, gSystem

on new me, tDataList
  if gGame.Bloom = 0 then
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
  if tDataList[#camera].ilk = #string then
    p[#TargetCamera] = p.member.camera(tDataList.camera)
  else
    p[#TargetCamera] = p.member.camera("Player1_Camera")
  end if
  if voidp(gGame[#StageTexture]) = 1 then
    AddScript(0, #system, [#script: "[PS] StageGrabber", #data: [#member: p.member.name, #camera: p.TargetCamera.name]])
  end if
  p[#size] = gGame.BloomSize
  tWidth = integer(gGame.resolution[1] * p.size)
  tHeight = integer(gGame.resolution[2] * p.size)
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
  p[#height] = tHeight
  p[#width] = tWidth
  p[#image] = image(tWidth, tHeight, 32, 0)
  p[#BlackImage] = image(tWidth, tHeight, 32, 0)
  p.BlackImage.fill(p.BlackImage.rect, rgb(0, 0, 0))
  p[#texture] = p.member.newTexture("Bloom_Texture", #fromImageObject, p.BlackImage)
  p.texture.quality = #lowFiltered
  p.texture.renderFormat = #rgba8888
  tShaderName = "Bloom" & string(p.template) & "_Material"
  p[#shader] = p.member.newShader(tShaderName, #standard)
  p.shader.specular = rgb(0, 0, 0)
  p.shader.texture = p.texture
  BlendShader(0, p.member.name, [#shader: tShaderName, #blendMode: #add])
  p.TargetCamera.addOverlay(p.texture, point(0, 0), 0)
  tModelList = []
  tSortedNameList = []
  tSortedNameList.sort()
  repeat with i = 1 to p.member.model.count
    tmodel = p.member.model(i)
    if tmodel.name contains "Overlay-" then
      tSortedNameList.add(tmodel.name)
      tModelList.add(tmodel)
    end if
  end repeat
  tName = tSortedNameList[tSortedNameList.count]
  repeat with j in tModelList
    if j.name = tName then
      tOverlayModel = j
    end if
  end repeat
  tOverlayModel.shaderList = p.shader
  tOverlay = p.TargetCamera.overlay.count
  p[#overlay] = tOverlay
  tScale = gGame.resolution[2] / float(tHeight)
  p.TargetCamera.overlay[tOverlay].scale = tScale
  tOffsetX = (gGame.resolution[1] - (tWidth * tScale)) * 0.5
  p.TargetCamera.overlay[tOverlay].loc = point(tOffsetX, 0)
  p.TargetCamera.rect = rect(0, 0, gGame.resolution[1], gGame.resolution[2])
  p.TargetCamera.overlay[tOverlay].source = p.texture
  p[#colorList] = []
  tResource = p.member.modelResource("DefaultModel")
  tResource.lengthVertices = 6
  tResource.widthVertices = 6
  return me
end

on enterFrame me
  tScale = gGame.resolution[2] / float(p.height)
  p.TargetCamera.overlay[p.overlay].scale = tScale
  tOffsetX = (gGame.resolution[1] - (p.width * tScale)) * 0.5
  p.TargetCamera.overlay[p.overlay].loc = point(tOffsetX, 0)
  p.TargetCamera.rect = rect(0, 0, gGame.resolution[1], gGame.resolution[2])
  tSourceImage = gGame.BloomTexture.image
  tBlack = p.BlackImage
  tAdjustColorData = p.BloomData.colorFilter
  tBlurData = p.BloomData.blur
  tAdjustFilter = filter(#AdjustColorFilter, tAdjustColorData)
  tBlurFilter = filter(#BlurFilter, tBlurData)
  tSourceImage.applyFilter(tAdjustFilter)
  tSourceImage.applyFilter(tBlurFilter)
  tSourceImage.copyPixels(tBlack, tSourceImage.rect, tBlack.rect, [#blend: 100 - p.BloomData.intensity])
  p.texture.image = tSourceImage
end

on delete me, tTag
  if tTag = VOID then
    repeat with i = p.TargetCamera.overlay.count down to 1
      if p.TargetCamera.overlay[i].source = p.texture then
        p.TargetCamera.removeOverlay(i)
        next repeat
      end if
      if p.TargetCamera.overlay[i].source = p.member.texture("DefaultTexture") then
        p.TargetCamera.removeOverlay(i)
      end if
    end repeat
  end if
  p.image = VOID
  p.BlackImage = VOID
  if p.texture <> VOID then
    p.member.deleteTexture(p.texture.name)
  end if
  if p.shader <> VOID then
    p.member.deleteShader(p.shader.name)
  end if
  tScript = GetScript(0, EMPTY, [#script: "[PS] Motion Blur"])
  if tScript = VOID then
    tScript = GetScript(0, EMPTY, [#script: "[PS] StageGrabber"])
    if tScript <> VOID then
      delete tScript
    end if
  end if
  if gSystem.scriptList.getPos(me) <> 0 then
    gSystem.scriptList.deleteOne(me)
  else
    gGame.scriptList.deleteOne(me)
  end if
end
