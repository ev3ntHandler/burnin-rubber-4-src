-- [Script] [PS] Motion Blur (Script #6171)
-- Script Type: Parent

property p
global gGame, gData, gSystem

on new me, tDataList
  if gGame.MotionBlur = 0 then
    return 0
  end if
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
  if tDataList[#camera].ilk = #string then
    p[#TargetCamera] = p.member.camera(tDataList.camera)
  else
    p[#TargetCamera] = p.member.camera("Player1_Camera")
  end if
  if voidp(gGame[#StageTexture]) = 1 then
    AddScript(0, #system, [#script: "[PS] StageGrabber", #data: [#member: p.member.name, #camera: p.TargetCamera.name]])
  end if
  p[#Dummy] = p.member.newGroup("MotionblurHelper")
  p.Dummy.parent = p.TargetCamera
  p.Dummy.translate(0, 0, -1, #self)
  p[#PreviousPosition] = p.Dummy.worldPosition
  p[#Passes] = 7
  if tDataList[#Passes].ilk = #integer then
    p.Passes = tDataList.Passes - 1
  end if
  p[#shaders] = []
  p[#Overlays] = []
  p[#texture] = gGame.StageTexture
  p[#diff] = [gGame.resolution[1] / float(p.texture.width), gGame.resolution[2] / float(p.texture.height)]
  p[#MaxDisplX] = 1.0 / p.texture.width
  p[#MaxDisplY] = 1.0 / p.texture.height
  p[#MaxDisplZ] = 1.0 / p.texture.width
  p[#ZMultiplier] = 35.0
  p[#BlendMultiplier] = 1.0
  p[#mask] = #none
  tDataList[#mask] = "MotionBlurMask"
  if tDataList[#mask].ilk = #string then
    p.mask = createTexture(0, p.member.name, [#texture: tDataList.mask, #filtering: #lowFiltered, #renderFormat: #rgba8888])
  end if
  if p.mask = VOID then
    p.mask = #none
  end if
  tScale = gGame.resolution[2] / float(p.texture.height)
  tOffsetX = (gGame.resolution[1] - (p.texture.width * tScale)) * 0.5
  repeat with i = 1 to p.Passes
    p.TargetCamera.addOverlay(p.texture, point(0, 0), 0)
  end repeat
  tModelList = []
  tSortedNameList = []
  tSortedNameList.sort()
  repeat with i = 1 to p.member.model.count
    tmodel = p.member.model(i)
    if tmodel.name contains "Overlay-" then
      tModelList.add(tmodel)
      tSortedNameList.add(tmodel.name)
    end if
  end repeat
  tBlendStep = 100.0 / (p.Passes + 1.0)
  p[#BlendSteps] = []
  repeat with i = 1 to p.Passes
    tShaderName = "MotionBlur" & i & "_Material"
    tShader = p.member.newShader(tShaderName, #standard)
    tShader.specular = rgb(0, 0, 0)
    tShader.emissive = rgb(255, 255, 255)
    tBlend = 100 - (i * tBlendStep)
    tShader.blend = tBlend
    p.BlendSteps.add(tBlend)
    tShader.textureList[1] = p.texture
    if p.mask <> #none then
      tShader.textureList[2] = p.mask
    end if
    tShader.textureRepeat = 0
    tShader.textureTransformList[1].scale = vector(1.0, 1.0, 1.0)
    tShader.textureTransformList[1].position = vector(0.0, 0.0, 0.0)
    p.shaders.add(tShader)
    tName = tSortedNameList[i]
    repeat with j in tModelList
      if j.name = tName then
        tOverlay = j
      end if
    end repeat
    tOverlay.shaderList = tShader
    p.TargetCamera.overlay[i].scale = tScale
    p.TargetCamera.overlay[i].loc = point(tOffsetX, 0)
    p.TargetCamera.rect = rect(0, 0, gGame.resolution[1], gGame.resolution[2])
  end repeat
  return me
end

on enterFrame me
  tdiff = p.Dummy.worldPosition - p.PreviousPosition
  tLength = tdiff.length()
  tTransform = gGame.camera[1].camera.getWorldTransform()
  tdiff = tdiff + tTransform.position
  tTransform.invert()
  tLocal = tTransform * tdiff
  if voidp(gGame[#vehicles]) = 0 then
    if gGame[#vehicles][1].Vehicle.Nitro = 0 then
      p.BlendMultiplier = max(0.0, p.BlendMultiplier * 0.90000000000000002)
    else
      p.BlendMultiplier = min(1.0, (p.BlendMultiplier + 0.10000000000000001) * 1.10000000000000009)
    end if
  end if
  tXOffset = min(p.MaxDisplX, max(-p.MaxDisplX, tLocal.x / p.Passes / 20))
  tYOffset = min(p.MaxDisplY, max(-p.MaxDisplY, tLocal.y / p.Passes / 20))
  tZOffset = abs(tLocal.z) / p.Passes / p.ZMultiplier
  tPerc = max(0.0, min(1.0, tLength / 3.0))
  tCount = p.shaders.count
  repeat with i = 1 to tCount
    tShader = p.shaders[i]
    tScaleOffSet = i * tZOffset
    tShader.blend = p.BlendSteps[i] * tPerc * p.BlendMultiplier
    tScale = 1.0 + tScaleOffSet
    tShader.textureTransformList[1].scale = vector(tScale, tScale, 1.0)
    tX = -(tScaleOffSet * 0.5) + (tXOffset * -i)
    tY = -(tScaleOffSet * 0.5) + (tYOffset * -i)
    tShader.textureTransformList[1].position = vector(tX, tY, 0.0)
  end repeat
  p.PreviousPosition = p.Dummy.worldPosition
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
  if p.Dummy <> VOID then
    p.member.deleteGroup(p.Dummy.name)
  end if
  tCount = p.shaders.count
  repeat with i = tCount down to 1
    if p.shaders[i] <> VOID then
      p.member.deleteShader(p.shaders[i].name)
    end if
  end repeat
  tScript = GetScript(0, EMPTY, [#script: "[PS] Bloom"])
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
