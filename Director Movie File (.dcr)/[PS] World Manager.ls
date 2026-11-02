-- [Script] [PS] World Manager (Script #5893)
-- Script Type: Parent

property p
global gSystem, gData, gGame

on new me, tDataList
  p = [:]
  p[#ScriptName] = "World Manager"
  p[#member] = VOID
  if tDataList[#member].ilk = #member then
    p.member = tDataList.member
  end if
  if tDataList[#member].ilk = #string then
    p.member = member(tDataList.member)
  end if
  if p.member = VOID then
    return 0
  end if
  gGame[#grid] = [#center: [], #innerRing: [], #outerRing: []]
  gGame[#VisualGrid] = [[], [], [], [], []]
  me.UpdateGrid(gGame.WorldStartTile[symbol(gGame.world)])
  p[#state] = #initializing
  p[#Tiles] = []
  p[#milliSeconds] = _system.milliSeconds
  p[#TileTime] = 0
  me.InitializeTiles()
  p.state = #none
  return me
end

on enterFrame me
  if p.state = #managing then
    me.ManageTiles()
  end if
  if (string(p.member.group("World").boundingSphere[2]) = "NAN") or (string(p.member.group("World").boundingSphere[2]) = "INF") then
    put "WORLD TOO LARGE?"
  end if
end

on GetState me
  return p.state
end

on setState me, tTarget, tDataList
  p.state = tDataList.state
end

on InitTileAndGrid me, tTarget, tDataList
  tTile = GetTile(0, symbol(gGame.WorldStartDummy[symbol(gGame.world)]))
  me.UpdateGrid(tTile)
  gGame.vehicles[1].Vehicle.currentTile = tTile
  me.ManageTiles()
  gGame.vehicles[1].general.script.reset(gGame.vehicles[1], 0, 0)
end

on InitializeTiles me
  PutMessage(0, "--> [World Manager] InitializeTiles (Handler)")
  tMilliseconds = _system.milliSeconds
  me.PrepareTiles()
  PutMessage(0, "--> [World Manager] InitializeTiles (Handler). PrepareTiles() took: " & string(_system.milliSeconds - tMilliseconds) & "ms.")
  tMilliseconds = _system.milliSeconds
  me.CreateTiles()
  PutMessage(0, "--> [World Manager] InitializeTiles (Handler). CreateTiles() took: " & string(_system.milliSeconds - tMilliseconds) & "ms.")
end

on PrepareTiles me
  PutMessage(0, "--> --> [World Manager] PrepareTiles (Handler)")
  tGrid = gGame.WorldGrids[symbol(gGame.world)]
  repeat with i = 1 to tGrid[1]
    repeat with j = 1 to tGrid[2]
      if i < 10 then
        t1 = "0" & i
      else
        t1 = string(i)
      end if
      if j < 10 then
        t2 = "0" & j
      else
        t2 = string(j)
      end if
      tmodel = p.member.model(t1 & "_" & t2 & "_World" & gGame.world & "Street")
      if tmodel = VOID then
        tmodel = p.member.model(t1 & "_" & t2 & "_World" & gGame.world & "Sea")
      end if
      tgroup = p.member.newGroup(t1 & "_" & t2)
      if tmodel <> VOID then
        tgroup.transform = tmodel.transform
      else
        tgroup.transform = transform()
      end if
      tUD = tgroup.userData
      tUD.addProp(#type, #none)
      tUD.addProp(#modelGroup, p.member.newGroup(tgroup.name & "_Models"))
      tUD.addProp(#objectGroup, p.member.newGroup(tgroup.name & "_Objects"))
      tUD.addProp(#pickupGroup, p.member.newGroup(tgroup.name & "_Pickups"))
      tUD.addProp(#CameraGroup, p.member.newGroup(tgroup.name & "_Cameras"))
      tUD.addProp(#markerGroup, p.member.newGroup(tgroup.name & "_Markers"))
      p.Tiles.add(tgroup)
    end repeat
  end repeat
end

on CreateTiles me
  PutMessage(0, "--> --> [World Manager] CreateTiles (Handler)")
  if voidp(gGame[#FloorList]) = 1 then
    gGame[#FloorList] = []
  end if
  the itemDelimiter = "_"
  repeat with i in p.Tiles
    if p.TileTime = 1 then
      tMilliseconds = _system.milliSeconds
    end if
    tTile = i.name.item[1] & "_" & i.name.item[2]
    tModelGroup = p.member.group(tTile & "_Models")
    tModelGroup.transform.position = i.worldPosition
    tModelGroup.transform = i.getWorldTransform().inverse() * tModelGroup.transform
    tModelGroup.parent = i
    tModelGroup.userData.addProp(#parent, i)
    tMainModelGroup = p.member.newGroup(tTile & "_MainModels")
    tMainModelGroup.transform.position = tModelGroup.transform.position
    tMainModelGroup.transform = tModelGroup.getWorldTransform().inverse() * tMainModelGroup.transform
    tMainModelGroup.parent = tModelGroup
    tMainModelGroup.userData.addProp(#parent, tModelGroup)
    tMiscModelGroup = p.member.newGroup(tTile & "_MiscModels")
    tMiscModelGroup.transform.position = tModelGroup.transform.position
    tMiscModelGroup.transform = tModelGroup.getWorldTransform().inverse() * tMiscModelGroup.transform
    tMiscModelGroup.parent = tModelGroup
    tMiscModelGroup.userData.addProp(#parent, tModelGroup)
    tMainModelList = []
    tMiscModelList = []
    tFloorList = []
    tCheckFloorList = ["Street", "Buildings", "Sea", "Waves"]
    if gGame.world = "Industrial" then
      tCheckFloorList = ["Street", "Buildings", "Street2", "Buildings2", "Sea", "Waves"]
    end if
    repeat with j in gGame.WorldModelList
      tTag = "World" & gGame.world & j
      tmodel = p.member.model(tTile & "_" & tTag)
      if tmodel = VOID then
        next repeat
      end if
      if tmodel.resource.type = #fromFile then
        tmodel.resource.lod.auto = 0
        tmodel.resource.lod.bias = 100.0
        tmodel.resource.lod.level = 100.0
      end if
      if tCheckFloorList.getPos(j) <> 0 then
        tFloorList.add(tmodel)
        tMainModelList.add(tmodel)
        tParent = tMainModelGroup
      else
        tMiscModelList.add(tmodel)
        tParent = tMiscModelGroup
      end if
      if voidp(gGame[#Lightmaps]) = 0 then
        if gGame.Lightmaps = 1 then
          if tFloorList.getPos(tmodel) <> 0 then
            tmodel.addModifier(#meshDeform)
            if tmodel.meshDeform.mesh.textureLayer.count > 1 then
              tFaceList = []
              repeat with k = 1 to tmodel.meshDeform.mesh[1].face.count
                tFaceList.add(tmodel.meshDeform.mesh[1].face[k])
              end repeat
              tmodel.userData.addProp(#FaceList2, tFaceList)
              tmodel.userData.addProp(#CoordList2, tmodel.meshDeform.mesh[1].face.textureLayer[2].textureCoordinateList)
            end if
            tmodel.removeModifier(#meshDeform)
          end if
        end if
      end if
      tmodel.transform = tParent.getWorldTransform().inverse() * tmodel.transform
      tmodel.parent = tParent
      tmodel.userData.addProp(#parent, tParent)
      if (j <> "Transparent") and (j <> "Sea") and (j <> "Waves") then
        createRigidBody(0, p.member.name, [#model: tmodel.name, #type: #static, #bodyProxy: #concaveShape])
      end if
      if (j = "InvisibleWall") and (gGame.InvisibleWalls = 0) then
        tMiscModelList.deleteOne(tmodel)
        tmodel.parent = VOID
      end if
    end repeat
    tMainModelGroup.userData.addProp(#models, tMainModelList)
    tMiscModelGroup.userData.addProp(#models, tMiscModelList)
    tModelGroup.userData.addProp(#MainGroup, tMainModelGroup)
    tModelGroup.userData.addProp(#MiscGroup, tMiscModelGroup)
    tModelGroup.userData.addProp(#Floors, tFloorList)
    i.userData.modelGroup = tModelGroup
    tList = ["Objects", "Pickups", "Cameras", "Waypoints", "Markers"]
    tState = 0
    repeat with j in tList
      if voidp(gData.data[symbol(gGame.world & j)]) = 0 then
        if voidp(gData.data[symbol(gGame.world & j)][symbol(tTile)]) = 0 then
          tList = gData.data[symbol(gGame.world & j)][symbol(tTile)].duplicate()
          tCount = tList.count
          repeat with k = 1 to tCount
            tProp = tList.getPropAt(k)
            case j of
              "Objects":
                if (tProp = #MountedGun_Object) and (gGame.MountedGuns = 0) then
                  next repeat
                end if
                if (tProp = #SamSite_Object) and (gGame.SamSites = 0) then
                  next repeat
                end if
                tResult = BuildObjects(0, p.member, [#ROOT: i.name, #parent: tTile & "_Objects", #object: tProp, #location: tList[tProp], #shader: "World" & gGame.world & "Misc_Material", #hide: tState, #pinned: 1])
                if tResult <> 0 then
                  i.userData.objectGroup = tResult
                end if
              "Pickups":
                tResult = BuildPickups(0, p.member, [#ROOT: i.name, #parent: tTile & "_Pickups", #pickUp: tProp, #location: tList[tProp], #shader: "Pickups_Material", #hide: tState, #checkList: [gGame.UPTickets, gGame.UPBossTickets, gGame.UPCashStashes]])
                if tResult <> 0 then
                  i.userData.pickupGroup = tResult
                end if
              "Cameras":
                tResult = BuildCameras(0, p.member, [#ROOT: i.name, #parent: tTile & "_Cameras", #camera: tProp, #location: tList[tProp]])
                if tResult <> 0 then
                  i.userData.CameraGroup = tResult
                end if
              "Markers":
                tResult = BuildMarkers(0, p.member, [#ROOT: i.name, #parent: tTile & "_Markers", #marker: tProp, #location: tList[tProp], #hide: tState])
                if tResult <> 0 then
                  i.userData.markerGroup = tResult
                end if
            end case
          end repeat
        end if
      end if
    end repeat
    tEvent = symbol(tTile & "_World" & gGame.world)
    if gData.Events.getaProp(tEvent) <> VOID then
      event(0, tEvent)
    end if
    me.TileNothing(i)
    if p.TileTime = 1 then
      PutMessage(0, "--> --> --> [World Manager] CreateTiles. Tile: '" & string(tTile) & "' created. This took your computer: " & string(_system.milliSeconds - tMilliseconds) & "ms.")
    end if
  end repeat
end

on RebuildModels me, tTarget, tModelList
  tmember = member(tTarget)
  repeat with i in tModelList
    tmodel = tmember.model(i)
    if tmodel = VOID then
      next repeat
    end if
    tResource = tmodel.resource
    tResource.lod.auto = 0
    tResource.lod.bias = 100.0
    tResource.lod.level = 100.0
    tmodel.addModifier(#meshDeform)
    tData = tmodel.meshDeform.list[1]
    tFaces = tData.mesh[1].face.count
    tVertexList = tData.mesh[1].vertexList
    tNormalList = tData.mesh[1].normalList
    tColorList = []
    repeat with j = 1 to tVertexList.count
      tColorList.add(rgb(255, 255, 255))
    end repeat
    tCoordList = tData.mesh[1].textureCoordinateList
    tShader = tmodel.shaderList[1]
    tRes = tmember.newMesh(tmodel.name & "_Rebuild", tFaces, tVertexList.count, tNormalList.count, tColorList.count, tCoordList.count)
    tRes.vertexList = tVertexList
    tRes.normalList = tNormalList
    tRes.colorList = tColorList
    tRes.textureCoordinateList = tCoordList
    repeat with i = 1 to tFaces
      tRes.face[i].vertices = tData.mesh[1].face[i]
      tRes.face[i].normals = tData.mesh[1].face[i]
      tRes.face[i].colors = tData.mesh[1].face[i]
      tRes.face[i].texCoords = tData.mesh[1].face[i]
      tRes.face[i].shader = tShader
    end repeat
    tRes.build()
    tmember.deleteModelResource(tmodel.resource.name)
    tmodel.resource = tRes
  end repeat
end

on UpdateGrid me, tStartTile
  gGame.grid = [#center: [], #innerRing: [], #outerRing: []]
  gGame.VisualGrid = [[], [], [], [], []]
  tTile = tStartTile
  tFirstTile = [tTile[1] - 3, tTile[2] - 3]
  repeat with i = 1 to 5
    repeat with j = 1 to 5
      tNewTile = [tFirstTile[1] + i, tFirstTile[2] + j]
      gGame.VisualGrid[6 - j][i] = [tNewTile[1], tNewTile[2]]
      if (tNewTile[1] <= 0) or (tNewTile[2] <= 0) then
        next repeat
        next repeat
      end if
      if tNewTile[1] < 10 then
        tX = "0" & string(tNewTile[1])
      else
        tX = string(tNewTile[1])
      end if
      if tNewTile[2] < 10 then
        tY = "0" & string(tNewTile[2])
      else
        tY = string(tNewTile[2])
      end if
      tNewTile = tX & "_" & tY
      if (i >= 2) and (i <= 4) and (j >= 2) and (j <= 4) then
        if (i = 3) and (j = 3) then
          gGame.grid.center.add(tNewTile)
        else
          gGame.grid.innerRing.add(tNewTile)
        end if
        next repeat
      end if
      gGame.grid.outerRing.add(tNewTile)
    end repeat
  end repeat
end

on ManageTiles me
  if voidp(gGame[#vehicles]) = 1 then
    return 0
  end if
  if gGame.vehicles.count = 0 then
    return 0
  end if
  t = gGame.vehicles[1]
  if t.Vehicle.currentTile <> t.Vehicle.previousTile then
    tOldGridList = gGame.grid.duplicate()
    me.UpdateGrid(t.Vehicle.currentTile)
    t.Vehicle.previousTile = t.Vehicle.currentTile
    tOldList = []
    repeat with i in tOldGridList
      repeat with j in i
        tOldList.add(j)
      end repeat
    end repeat
    tNewList = []
    repeat with i in gGame.grid
      repeat with j in i
        tNewList.add(j)
      end repeat
    end repeat
    repeat with i in tOldList
      if p.Tiles.getPos(p.member.group(i)) = 0 then
        next repeat
      end if
      if tNewList.getPos(i) = 0 then
        me.SetTile(i, #none)
      end if
    end repeat
    repeat with i in tNewList
      tgroup = p.member.group(i)
      if tgroup = VOID then
        next repeat
      end if
      tUD = tgroup.userData
      repeat with k = 1 to gGame.grid.count
        tProp = gGame.grid.getPropAt(k)
        tList = gGame.grid[k]
        if tList.getPos(i) <> 0 then
          if tUD.type = tProp then
            next repeat
            next repeat
          end if
          me.SetTile(i, tProp)
        end if
      end repeat
    end repeat
  end if
end

on SetTile me, tTile, tNewType
  tgroup = p.member.group(tTile)
  tUD = tgroup.userData
  tOldType = tUD.type
  tUD.type = tNewType
  if (tOldType = #center) and (tNewType = #innerRing) then
    return 1
  end if
  if (tOldType = #innerRing) and (tNewType = #center) then
    return 1
  end if
  if (tOldType = #outerRing) and (tNewType = #innerRing) then
    return me.TileFullOn(tgroup)
  end if
  if (tOldType = #innerRing) and (tNewType = #outerRing) then
    return me.TileMainModels(tgroup)
  end if
  if (tOldType = #none) and (tNewType = #outerRing) then
    return me.TileMainModels(tgroup)
  end if
  if (tOldType = #outerRing) and (tNewType = #none) then
    return me.TileNothing(tgroup)
  end if
  if (tOldType = #none) and (tNewType = #innerRing) then
    me.TileFullOn(tgroup)
  else
    if (tOldType = #none) and (tNewType = #center) then
      me.TileFullOn(tgroup)
    else
      if (tOldType = #outerRing) and (tNewType = #center) then
        me.TileFullOn(tgroup)
      end if
    end if
  end if
end

on TileFullOn me, tgroup
  tModelGroup = tgroup.userData.modelGroup
  tModelGroup.parent = tgroup
  tModelGroup.userData.MainGroup.parent = tModelGroup
  tModelGroup.userData.MiscGroup.parent = tModelGroup
  repeat with i in tModelGroup.userData.Floors
    gGame.FloorList.add(i)
  end repeat
  tgroup.userData.objectGroup.parent = tgroup
  if tgroup.userData.objectGroup.userData.count > 0 then
    me.SetRigidBodies(tgroup.userData.objectGroup, 0)
  end if
  tgroup.userData.pickupGroup.parent = tgroup
  tgroup.userData.markerGroup.parent = tgroup
  return 1
end

on TileMainModels me, tgroup
  tModelGroup = tgroup.userData.modelGroup
  tModelGroup.parent = tgroup
  tModelGroup.userData.MainGroup.parent = tModelGroup
  if gGame.ShowMore then
    tModelGroup.userData.MiscGroup.parent = tModelGroup
  else
    tModelGroup.userData.MiscGroup.parent = VOID
  end if
  repeat with i in tModelGroup.userData.Floors
    gGame.FloorList.deleteOne(i)
  end repeat
  tgroup.userData.objectGroup.parent = VOID
  if tgroup.userData.objectGroup.userData.count > 0 then
    me.SetRigidBodies(tgroup.userData.objectGroup, 1)
  end if
  tgroup.userData.pickupGroup.parent = VOID
  tgroup.userData.markerGroup.parent = VOID
  return 1
end

on TileNothing me, tgroup
  tModelGroup = tgroup.userData.modelGroup
  tModelGroup.parent = tgroup
  if gGame.ShowMore then
    tModelGroup.userData.MainGroup.parent = tModelGroup
    tModelGroup.userData.MiscGroup.parent = tModelGroup
  else
    tModelGroup.userData.MainGroup.parent = VOID
    tModelGroup.userData.MiscGroup.parent = VOID
  end if
  repeat with i in tModelGroup.userData.Floors
    gGame.FloorList.deleteOne(i)
  end repeat
  tgroup.userData.objectGroup.parent = VOID
  if tgroup.userData.objectGroup.userData.count > 0 then
    me.SetRigidBodies(tgroup.userData.objectGroup, 1)
  end if
  tgroup.userData.pickupGroup.parent = VOID
  tgroup.userData.markerGroup.parent = VOID
  return 1
end

on SetRigidBodies me, tgroup, tState
  repeat with i in tgroup.userData.rigidBodies
    if i = VOID then
      next repeat
    end if
    i.isPinned = tState
  end repeat
end

on delete me
  p = [:]
  if gSystem.scriptList.getPos(me) <> 0 then
    gSystem.scriptList.deleteOne(me)
  else
    gGame.scriptList.deleteOne(me)
  end if
end
