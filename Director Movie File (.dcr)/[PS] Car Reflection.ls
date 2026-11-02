-- [Script] [PS] Car Reflection (Script #5919)
-- Script Type: Parent

property p
global gGame

on new me, tDataList
  p = [:]
  p[#member] = member(tDataList.member)
  p[#sprite] = sprite(tDataList.sprite)
  tScale = 0.25
  tWidth = gGame.stageSize[1] * tScale
  tHeight = gGame.stageSize[2] * tScale
  t = gGame.vehicles[1]
  p[#modelList] = []
  p.modelList.add(t.Vehicle.model)
  p.modelList.add(t.Vehicle.glassModel)
  repeat with i in t.Vehicle.wheellist
    p.modelList.add(i)
  end repeat
  p[#shaderList] = []
  p.shaderList.add(p.modelList[1].shader)
  p.shaderList.add(p.modelList[2].shader)
  p[#RT] = gGame.member.newTexture("CarReflection_Texture", #renderTexture, tWidth, tHeight)
  p.RT.renderFormat = #rgba8888
  p.RT.updateRTImageOnRender = 1
  repeat with i in p.shaderList
    i.textureList[2] = p.RT
    i.textureRepeatList[2] = 0
    i.blendFunctionList[2] = #blend
    i.blendConstantList[2] = 25.0
    i.textureTransformList[2].scale.x = -1
  end repeat
  p[#TargetCamera] = gGame.camera[1].camera
  p[#camera] = gGame.member.newCamera("CarReflection_Camera")
  p.camera.rect = rect(0, 0, tWidth, tHeight)
  p.camera.fieldOfView = 90.0
  p.camera.colorBuffer.clearValue = color(110, 180, 190)
  return me
end

on enterFrame me
  p.camera.transform.position = p.modelList[1].worldPosition
  p.camera.pointAt(p.TargetCamera.worldPosition, vector(0, 0, 1))
  repeat with i in p.modelList
    i.visibility = #none
  end repeat
  p.sprite.renderToTexture(p.camera, p.RT)
  repeat with i in p.modelList
    i.visibility = #front
  end repeat
end
