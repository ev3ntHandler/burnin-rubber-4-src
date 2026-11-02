-- [Script] [PS] MiniMap (Script #5870)
-- Script Type: Parent

property p
global gSystem, gLoader, gData, gGame

on new me, tDataList
  p = [:]
  p[#sprite] = tDataList[#sprite]
  p[#member] = member(tDataList[#member])
  gGame[#MiniMap] = [:]
  gGame.MiniMap[#markerlist] = [:]
  gGame.MiniMap[#MiniMapMarkerList] = [:]
  gGame.MiniMap[#StoredMarkerList] = [:]
  gGame.MiniMap[#StoredMiniMapMarkerList] = [:]
  p[#MiniMap] = member("MiniMap")
  p[#camera] = p.MiniMap.camera("MiniMap_Camera")
  p[#shader] = p.MiniMap.shader("MiniMap_Material")
  p[#MapModel] = p.MiniMap.model("MiniMap")
  p[#border] = p.MiniMap.model("MiniMapBorder")
  p[#offset] = 225.0
  p[#MapScale] = 4
  p[#MattScale] = 1.87000000000000011
  p[#scale] = 1.0 / (2048.0 / 128.0) * p.MapScale
  p.shader.textureTransformList[2].scale = vector(1, 1, 1) * p.scale / p.MattScale
  p.shader.textureRepeatList[2] = 0
  p.border.transform.scale = vector(1, 1, 1) * p.MapScale
  tPosList = [#CITY: vector(-665.0, -416.0, -500.0), #Jungle: vector(-1916.0, -1666.0, -500.0), #Desert: vector(-789.0, -615.0, -500.0), #Snow: vector(-1114.0, -113.0, -500.0), #Industrial: vector(-164.0, -665.0, -500.0)]
  p.MapModel.transform.position = tPosList[symbol(gGame.world)]
  p.MapModel.transform.scale = vector(1, 1, 1) * p.MattScale
  AddCameraToSprite(0, gGame.sprite, [#member: "MiniMap", #camera: "Minimap_Camera"])
  tScale = gGame.stageSize[1] / 800.0
  tLeft = gGame.stageSize[1] - (10 * tScale) - (128 * tScale)
  tTop = gGame.stageSize[2] - (10 * tScale) - (128 * tScale)
  tRight = gGame.stageSize[1] - (10 * tScale)
  tBottom = gGame.stageSize[2] - (10 * tScale)
  p[#rect] = rect(tLeft, tTop, tRight, tBottom)
  gGame.MiniMap[#script] = me
  return me
end

on enterFrame me
  if voidp(gGame[#vehicles]) = 1 then
    return 0
  end if
  if gGame.vehicles.count = 0 then
    return 0
  end if
  t = gGame.vehicles[1]
  tCarTransform = t.Vehicle.transform.duplicate()
  tRotCamera = gGame.camera[t.camera.index].transform.rotation.z
  if gGame.MiniMap.MiniMapMarkerList.count > 0 then
    repeat with i in gGame.MiniMap.MiniMapMarkerList
      if (i.update = 1) and (i.sourceModel <> #none) then
        i.model.transform.position = i.sourceModel.getWorldTransform().position
        i.position = i.model.transform.position
      end if
      i.model.transform.rotation.z = p.camera.transform.rotation.z
      tDistance = i.position.distanceTo(tCarTransform.position)
      if tDistance <= p.offset then
        i.model.transform.position = i.position
      else
        tNorm = i.position - tCarTransform.position
        tNorm.normalize()
        i.model.transform.position = tCarTransform.position + (tNorm * p.offset)
      end if
      tOffsetList = [#SwitchToCar, #SwitchToBoat, #SwitchToHelicopter]
      tOffset = vector()
      if tOffsetList.getPos(i.type) <> 0 then
        i.model.transform.position.z = 35.0
      else
        if (i.type = #TimeTrial) or (i.type = #Demolition) then
          i.model.transform.position.z = 65.0
        else
          i.model.transform.position.z = 0.0
        end if
      end if
      if (tDistance <= (p.offset * 2.0)) and (i.priority = #medium) then
        i.model.parent = p.MiniMap.group("World")
      else
        i.model.parent = VOID
      end if
      if (tDistance <= p.offset) and (i.priority = #low) then
        i.model.parent = p.MiniMap.group("World")
      end if
      if i.priority = #high then
        i.model.parent = p.MiniMap.group("World")
      end if
      if i.type = #player then
        i.model.transform.position = vector(tCarTransform.position.x, tCarTransform.position.y, 50.0)
        i.model.transform.rotation.z = p.camera.transform.rotation.z
      end if
      if i.type = #North then
        i.model.transform.position = vector(tCarTransform.position.x, tCarTransform.position.y + p.offset, 50.0)
        i.model.transform.rotation.z = p.camera.transform.rotation.z
      end if
    end repeat
  end if
  if t.Input.backwardCam = 1 then
    p.camera.transform.rotation = vector(0, 0, tRotCamera + 180.0)
  else
    p.camera.transform.rotation = vector(0, 0, tRotCamera)
  end if
  p.camera.transform.position.x = tCarTransform.position.x
  p.camera.transform.position.y = tCarTransform.position.y
  tPosition = [abs(p.MapModel.worldPosition.x - tCarTransform.position.x), abs(p.MapModel.worldPosition.y - tCarTransform.position.y)]
  tNormalizePositionX = (tPosition[1] / (2048.0 * p.MattScale)) - (p.scale * (0.5 / p.MattScale))
  tNormalizePositionY = (tPosition[2] / (2048.0 * p.MattScale)) - (p.scale * (0.5 / p.MattScale))
  p.shader.textureTransformList[2].position = vector(tNormalizePositionX, tNormalizePositionY, 0)
  p.border.transform.position = p.camera.transform.position
  p.border.transform.position.z = -30.0
  p.border.transform.rotation.z = p.camera.transform.rotation.z
end

on ShowMiniMap me
  p.camera.rootNode = p.MiniMap.group("World")
  setCamera(0, "MiniMap", [#camera: "Minimap_Camera", #projection: #orthographic, #orthoHeight: 520.0, #rect: p.rect, #clearAtRender: 0])
end

on HideMiniMap me
  p.camera.rootNode = 0
end

on delete me
  p = [:]
  gGame.deleteProp(#MiniMap)
  if gSystem.scriptList.getPos(me) <> 0 then
    gSystem.scriptList.deleteOne(me)
  else
    gGame.scriptList.deleteOne(me)
  end if
end
