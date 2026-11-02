-- [Script] [PS] Vehicle Shadow Caster (Script #5923)
-- Script Type: Parent

property p
global gGame

on new me, tDataList
  if gGame.Shadows = 0 then
    return 0
  end if
  p = [:]
  p[#tag] = tDataList.tag
  t = gGame.vehicles[p.tag]
  p[#member] = member(tDataList.member)
  p[#sprite] = sprite(1)
  tCheckResource = p.member.modelResource(t.general.tag & "ShadowRecieverMesh")
  if tCheckResource <> VOID then
    return VOID
  end if
  p[#ScriptName] = "[PS] Vehicle Shadow Caster"
  p[#light] = p.member.light(tDataList.light)
  if p.light = VOID then
    p.light = p.member.light("Omni001")
  end if
  if p.light = VOID then
    p.light = p.member.light("Direct001")
  end if
  if p.light = VOID then
    p.light = p.member.light("Default Max Light")
  end if
  if p.light = VOID then
    p.light = p.member.light("SunLight")
  end if
  if p.light = VOID then
    return 0
  end if
  if voidp(gGame[#ShadowCasters]) = 1 then
    gGame[#ShadowCasters] = 0
  end if
  gGame.ShadowCasters = gGame.ShadowCasters + 1
  p[#camera] = p.member.newCamera("ShadowCaster" & gGame.ShadowCasters & "_Camera")
  p.camera.transform = p.light.transform
  p.camera.transform.scale = vector(1.0, 1.0, 1.0)
  p.camera.colorBuffer.clearValue = rgb(255, 255, 255)
  p.camera.fieldOfView = 20.0
  if t.Vehicle.name = "BigTruck" then
    p.camera.fieldOfView = 30.0
  else
    if t.Vehicle.name = "Tank" then
      p.camera.fieldOfView = 30.0
    else
      if t.Vehicle.name = "Apache" then
        p.camera.fieldOfView = 30.0
      end if
    end if
  end if
  p.camera.fog.enabled = 1
  p.camera.fog.far = 1
  p.camera.fog.near = -1
  emColor = rgb(132, 132, 132)
  case p.member.name of
    "CityAssets":
      emColor = rgb(152, 143, 137)
    "SnowAssets":
      emColor = rgb(122, 115, 97)
    "JungleAssets":
      emColor = rgb(150, 144, 130)
    "DesertAssets":
      emColor = rgb(171, 171, 180)
  end case
  p.camera.fog.color = emColor
  p.camera.fog.decayMode = #linear
  tShadowDetail = 128
  case gGame.ShadowsDetail of
    #high:
      tShadowDetail = 512
      if t.general.controller = #AI then
        tShadowDetail = 128
      end if
    #medium:
      tShadowDetail = 256
      if t.general.controller = #AI then
        tShadowDetail = 128
      end if
    #low:
      tShadowDetail = 128
      if t.general.controller = #AI then
        tShadowDetail = 64
      end if
  end case
  tWidth = tShadowDetail
  tHeight = tShadowDetail
  p[#RT] = p.member.newTexture("ShadowCaster" & gGame.ShadowCasters & "_Texture", #renderTexture, tWidth, tHeight)
  p.RT.renderFormat = #rgba8888
  p.RT.quality = #lowFiltered
  p[#shadow] = [:]
  p.shadow[#BlurFilter] = filter(#BlurFilter, [#blurX: 2, #blurY: 2, #quality: 1])
  tResource = p.member.newModelResource(t.general.tag & "ShadowRecieverMesh", #plane)
  tResource.width = 20.0
  tResource.length = 20.0
  tResource.lengthVertices = 10
  tResource.widthVertices = 10
  p[#RecieverModel] = p.member.newModel(t.general.tag & "ShadowReciever", tResource)
  p.RecieverModel.addModifier(#meshDeform)
  p.RecieverModel.meshDeform.mesh[1].textureLayer.add()
  p.RecieverModel.meshDeform.mesh[1].textureLayer.add()
  p.RecieverModel.meshDeform.mesh[2].textureLayer.add()
  p.RecieverModel.meshDeform.mesh[2].textureLayer.add()
  tShader = p.member.newShader(t.general.tag & "ShadowReciever_Material", #standard)
  tShader.texture = p.RT
  tShader.ambient = rgb(0, 0, 0)
  tShader.diffuse = rgb(0, 0, 0)
  tShader.specular = rgb(0, 0, 0)
  tShader.emissive = rgb(0, 0, 0)
  tShader.shininess = 0.0
  p[#shader] = tShader
  BlendShader(0, p.member.name, [#shader: tShader.name, #blendMode: #multiply])
  p.RecieverModel.shaderList[1] = tShader
  p.RecieverModel.shaderList[2] = tShader
  p[#shadowmodel] = gGame.vehicles[p.tag].Vehicle.model
  p.shadowmodel.userData.addProp(#shader, p.shadowmodel.shaderList)
  if t.Vehicle.name = "AutoBot" then
    p[#AdditionalModels] = []
  else
    if voidp(t.Vehicle[#wheellist]) = 0 then
      p[#AdditionalModels] = t.Vehicle.wheellist.duplicate()
    else
      p[#AdditionalModels] = []
    end if
  end if
  p[#distance] = 20.0
  p.camera.rootNode = p.shadowmodel
  p[#layer] = 3
  if getRendererServices().renderer = #openGL then
    p.layer = 2
  end if
  p[#filter] = 0
  p[#BlendedShaders] = []
  tCount = p.member.shader.count
  repeat with i = 1 to tCount
    if p.member.shader[i].blendFunctionList[3] = #add then
      p.BlendedShaders.append(p.member.shader[i])
    end if
  end repeat
  return me
end

on enterFrame me
  t = gGame.vehicles[p.tag]
  if t.Vehicle.Health <= 0 then
    p.RecieverModel.parent = VOID
    return 0
  else
    if t.general.limit = 1 then
      p.RecieverModel.parent = VOID
      return 0
    end if
  end if
  p.RecieverModel.parent = p.member.group("World")
  p.RecieverModel.transform.position = t.Vehicle.shadowmodel.transform.position
  p.RecieverModel.transform.rotation = t.Vehicle.shadowmodel.transform.rotation
  if p.light = VOID then
    p.light = p.member.light("Sun")
  end if
  p.camera.transform = p.light.transform
  p.camera.transform.position = p.shadowmodel.worldPosition
  p.camera.translate(0, 0, p.distance, #self)
  tSourceList = []
  tScaleList = []
  repeat with i in p.AdditionalModels
    tSourceList.add(i.getWorldTransform())
    tScaleList.add(i.transform.scale)
    i.transform = p.shadowmodel.getWorldTransform().inverse() * i.transform
    i.parent = p.shadowmodel
  end repeat
  repeat with i in p.BlendedShaders
    if i = VOID then
      next repeat
    end if
    i.renderStyle = #point
  end repeat
  p.sprite.renderToTexture(p.camera, p.RT)
  tCount = 0
  repeat with i in p.AdditionalModels
    tCount = tCount + 1
    i.parent = t.general.member.group("World")
    i.transform = tSourceList[tCount]
    i.transform.scale = tScaleList[tCount]
  end repeat
  repeat with i in p.BlendedShaders
    if i = VOID then
      next repeat
    end if
    i.renderStyle = #fill
  end repeat
  if p.filter then
    tFilter = p.shadow.BlurFilter
    tImage = p.RT.image
    tImage.applyFilter(tFilter)
    p.RT.image = tImage
  end if
  me.SetCoordinates()
end

on SetCoordinates me
  pCamOrigin2D = point(p.camera.rect.width / 2, p.camera.rect.height / 2)
  pCamDist2Plane = tan(p.camera.projectionAngle * (pi() / 360.0))
  pCamProjDist = -(pCamOrigin2D[2] / pCamDist2Plane)
  pCamInvMTX = p.camera.transform.inverse()
  pCamInvMTX.scale(pCamProjDist, pCamProjDist, 1)
  projSize = point(p.camera.rect.width * 1.0, p.camera.rect.height * 1.0)
  pt = point(0, 0)
  zVector = vector(0, 0, 0)
  tm = p.RecieverModel
  tCount = tm.meshDeform.mesh.count
  repeat with m = 1 to tCount
    vertexList = tm.meshDeform.mesh[m].vertexList
    textureCoordinateList = tm.meshDeform.mesh[m].textureLayer[p.layer].textureCoordinateList
    t = vertexList.count
    if t = 0 then
      return
    end if
    repeat with i = 1 to t
      tEyeSp = pCamInvMTX * ((tm.transform * vertexList[i]) + zVector)
      pt[1] = (tEyeSp.x / tEyeSp.z) + pCamOrigin2D[1]
      pt[2] = -(tEyeSp.y / tEyeSp.z) + pCamOrigin2D[2]
      tp = pt / projSize
      textureCoordinateList[i][1] = max(0, min(1.0, tp[1]))
      textureCoordinateList[i][2] = -max(0, min(1.0, tp[2]))
    end repeat
    tm.meshDeform.mesh[m].textureLayer[p.layer].textureCoordinateList = textureCoordinateList
  end repeat
end

on delete me
  p.member.deleteModelResource(p.RecieverModel.resource.name)
  p.member.deleteModel(p.RecieverModel.name)
  p.member.deleteShader(p.shader.name)
  p.member.deleteTexture(p.RT.name)
  gGame.scriptList.deleteOne(me)
end
