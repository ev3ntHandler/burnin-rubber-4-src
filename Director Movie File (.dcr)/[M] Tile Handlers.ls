-- [Script] [M] Tile Handlers (Script #5858)
-- Script Type: Movie

global gSystem, gData, gGame

on CreateTile me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  if voidp(gGame[#LinkedMembers]) = 1 then
    LinkToTheRoot(0, tmember.name)
  else
    if gGame.LinkedMembers.getPos(tmember.name) = 0 then
      LinkToTheRoot(0, tmember.name)
    end if
  end if
  tType = VOID
  if tDataList[#type].ilk = #string then
    tType = tDataList.type
  end if
  tDirection = EMPTY
  if tDataList[#direction].ilk = #string then
    tDirection = tDataList.direction
  end if
  tAIPath = EMPTY
  if tDataList[#aipath].ilk = #list then
    if tDataList.aipath[1].ilk = #string then
      tAIPath = tDataList.aipath[1]
    end if
  end if
  if tAIPath = EMPTY then
    tAIPath = tType
  end if
  tPosition = vector()
  if tDataList[#position].ilk = #vector then
    tPosition = tDataList.position
  end if
  tDeco = 0
  if tDataList[#deco].ilk = #integer then
    tDeco = tDataList.deco
  end if
  tParentRoot = 0
  if tDataList[#parent].ilk = #integer then
    tParentRoot = tDataList.parent
  end if
  if tDeco = 0 then
    tTag = "Track"
  else
    tTag = "Deco"
  end if
  tRoot = tmember.model(tType & "_Root")
  if tRoot = VOID then
    return 0
  end if
  if voidp(gGame[#RootList]) = 1 then
    gGame[#RootList] = []
  end if
  if gGame.RootList.getPos(VOID) <> 0 then
    gGame.RootList = []
  end if
  if voidp(gGame[#DecoList]) = 1 then
    gGame[#DecoList] = []
  end if
  if tDeco = 0 then
    tCount = gGame.RootList.count + 1
  else
    tCount = gGame.DecoList.count + 1
  end if
  tGroupRootName = tTag & "Root" & tCount
  tGroupRoot = tmember.newGroup(tGroupRootName)
  tNewModelList = []
  tChildCount = tRoot.child.count
  repeat with i = 1 to tChildCount
    tmodel = tRoot.child[i]
    if (tmodel.name contains "Outside") and (tmodel.name contains "InvisibleWall") then
      next repeat
    end if
    if (tDeco = 1) and (tmodel.name contains "InvisibleWall") then
      next repeat
    end if
    tNewModel = tmember.newModel(tTag & "Root" & tCount & "_" & tmodel.name, tmodel.resource)
    tNewModel.transform = tmodel.transform
    tNewModel.shaderList = tmodel.shaderList
    tNewModel.parent = tGroupRoot
    if voidp(gGame[#Lightmaps]) = 0 then
      if gGame.Lightmaps = 1 then
        tNewModel.addModifier(#meshDeform)
        tShaderList = []
        repeat with j = 1 to tmodel.shaderList.count
          if tNewModel.meshDeform.mesh.textureLayer.count > 1 then
            if (tNewModel.name contains "Street") or (tNewModel.name contains "Buildings") then
              tShader = DuplicateShader(0, tmember.name, [#shader: tmodel.shaderList[j].name, #shaderTag: tGroupRootName])
              tLightMap = tType & "StreetLightmap_Texture"
              if tmember.texture(tLightMap) = VOID then
                createTexture(0, tmember.name, [#texture: tLightMap, #renderFormat: #rgba5650, #filtering: #lowFiltered])
              end if
              ASSIGNTEXTURE(0, tmember.name, [#material: tShader.name, #lightmap: tLightMap])
              tShaderList.add(tShader)
            else
              tShader = tmodel.shaderList[j]
            end if
          else
            tShader = tmodel.shaderList[j]
          end if
          tShaderList.add(tShader)
        end repeat
        tNewModel.shaderList = tShaderList
        if (tNewModel.meshDeform.mesh.textureLayer.count > 1) and (tNewModel.name contains "Street") then
          tUD = tNewModel.userData
          tFaceList = []
          repeat with k = 1 to tNewModel.meshDeform.mesh[1].face.count
            tFaceList.add(tNewModel.meshDeform.mesh[1].face[k])
          end repeat
          tNewModel.userData.addProp(#FaceList2, tFaceList)
          tNewModel.userData.addProp(#CoordList2, tNewModel.meshDeform.mesh[1].face.textureLayer[2].textureCoordinateList)
        end if
        tNewModel.removeModifier(#meshDeform)
      end if
    end if
    tNewModelList.add(tNewModel)
  end repeat
  if tDeco <> 0 then
    tGroupRoot.transform.position = tPosition
    tParent = gGame.RootList[tParentRoot]
    tGroupRoot.transform = tParent.getWorldTransform().inverse() * tGroupRoot.transform
    tGroupRoot.parent = tParent
  else
    tGroupRoot.transform.position = tPosition
  end if
  if tDeco = 0 then
    gGame.RootList.add(tGroupRoot)
  else
    gGame.DecoList.add(tGroupRoot)
  end if
  if tDeco = 0 then
    repeat with i in tNewModelList
      if (gGame.Vehicle = "Car") or (gGame.Vehicle = "Plane") or (gGame.Vehicle = "Helicopter") then
        if i.name contains "Street" then
          SetAttribute(0, tmember.name, [#ModelName: i.name, #attribute: #floor, #model: i.name])
          createRigidBody(0, tmember.name, [#model: i.name, #type: #static, #bodyProxy: #concaveShape])
        else
          if i.name contains "Transparent" then
            nothing()
          else
            createRigidBody(0, tmember.name, [#model: i.name, #type: #static, #bodyProxy: #concaveShape])
          end if
          if i.name contains "InvisibleWall" then
            i.parent = VOID
          end if
        end if
      end if
      if gGame.Vehicle = "Boat" then
        if i.name.char[i.name.length - 2..i.name.length] = "Sea" then
          SetAttribute(0, tmember.name, [#ModelName: i.name, #attribute: #floor, #model: i.name])
          createRigidBody(0, tmember.name, [#model: i.name, #type: #static, #bodyProxy: #concaveShape])
          next repeat
        end if
        if i.name contains "Transparent" then
          nothing()
        end if
        if i.name contains "Waves" then
          nothing()
        else
          createRigidBody(0, tmember.name, [#model: i.name, #type: #static, #bodyProxy: #concaveShape])
        end if
        if i.name contains "InvisibleWall" then
          i.parent = VOID
        end if
      end if
    end repeat
    if getaProp(gGame, #WayPointList) = VOID then
      gGame[#WayPointList] = [:]
    end if
    tResult = BuildTileAIPath(0, tGroupRoot, tAIPath, tDirection)
    tPointList = tResult[1]
    tReverse = tResult[2]
    if tPointList.count = 0 then
      tPointList.add(tGroupRoot.transform.duplicate())
    end if
    gGame.WayPointList[symbol(tGroupRoot.name)] = tPointList
    if voidp(gGame[#totalWaypoints]) = 1 then
      gGame[#totalWaypoints] = 0
    end if
    gGame.totalWaypoints = gGame.totalWaypoints + tPointList.count
    tGroupRoot.userData.addProp(#Obstacles, [])
    tGroupRoot.userData.addProp(#Pickups, [])
    tGroupRoot.userData.addProp(#traffic, [])
    if voidp(gGame[#Obstacles]) = 1 then
      tObstacles = 1
    else
      tObstacles = gGame.Obstacles
    end if
    if voidp(gGame[#Pickups]) = 1 then
      tPickups = 1
    else
      tPickups = gGame.Pickups
    end if
    if voidp(gGame[#traffic]) = 1 then
      tTraffic = 1
    else
      tTraffic = gGame.traffic
    end if
    repeat with i = 1 to tDataList.count
      tDataProp = tDataList.getPropAt(i)
      if (tDataProp = #type) or (tDataProp = #aipath) or (tDataProp = #direction) or (tDataProp = #position) then
        next repeat
        next repeat
      end if
      if (string(tDataProp) contains "object") and (tObstacles = 1) then
        BuildObjects(0, tmember, [#ROOT: tGroupRoot.name, #object: tDataProp, #location: tDataList[tDataProp], #shader: #original])
        next repeat
      end if
      if (string(tDataProp) contains "pickup") and (tPickups = 1) then
        BuildPickups(0, tmember, [#ROOT: tGroupRoot.name, #pickUp: tDataProp, #location: tDataList[tDataProp], #shader: #original])
        next repeat
      end if
      if tTraffic = 1 then
        BuildTraffic(0, tGroupRootName, tDataProp, tDataList[tDataProp], tGroupRoot)
      end if
    end repeat
  end if
  tGroupRoot.removeFromWorld()
end

on DeleteTile me, tTarget, tDataList
end

on LinkToTheRoot me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  tRootList = []
  tCount = tmember.model.count
  repeat with i = 1 to tCount
    tmodel = tmember.model(i)
    if tmodel.name contains "_Root" then
      tRootList.add(tmodel)
    end if
  end repeat
  if tRootList.count > 0 then
    if voidp(gGame[#LinkedMembers]) = 1 then
      gGame[#LinkedMembers] = []
    end if
    SetItemDelimiter(0, "_")
    repeat with i in tRootList
      tTag = i.name.item[1]
      repeat with j = 1 to tCount
        tmodel = tmember.model(j)
        if tmodel.name contains tTag then
          tmodel.parent = i
        end if
      end repeat
      i.parent = VOID
    end repeat
    ResetItemDelimiter()
    gGame.LinkedMembers.add(tmember.name)
    return 1
  else
    return 0
  end if
end

on BuildTileAIPath me, tGroupRoot, tAIPath, tDirection
  tDataList = gData.data[symbol(gGame.Assets & "AIPaths")]
  tWayPointList = []
  tReverse = 0
  tProp = symbol(tAIPath & "_" & tDirection)
  if voidp(tDataList[tProp]) = 0 then
    tTileList = tDataList[tProp].duplicate()
  else
    tSwitchList = [#SouthNorth: "NorthSouth", #NorthSouth: "SouthNorth", #WestEast: "EastWest", #EastWest: "WestEast", #SouthWest: "WestSouth", #WestSouth: "SouthWest", #SouthEast: "EastSouth", #EastSouth: "SouthEast", #WestNorth: "NorthWest", #NorthWest: "WestNorth", #EastNorth: "NorthEast", #NorthEast: "EastNorth"]
    tProp = symbol(tAIPath & "_" & tSwitchList[tDirection])
    tReverse = 1
    if voidp(tDataList[tProp]) = 0 then
      tTileList = tDataList[tProp].duplicate()
    else
      return [tWayPointList, tReverse]
    end if
  end if
  tgroup = gGame.member.newGroup("WaypointHelper")
  tgroup.pointAtOrientation = [vector(0.0, 1.0, 0.0), vector(0.0, 0.0, 1.0)]
  tRootTransform = tGroupRoot.getWorldTransform()
  t1 = 1
  t2 = tTileList.count
  if tReverse = 0 then
    if gGame.member.shader("Proxy_Material") = VOID then
      CreateProxyShader(0, gGame.member.name)
    end if
    repeat with j = t1 to t2
      tWayPointPos = tRootTransform.position + tTileList[j]
      if j < tTileList.count then
        tFutWayPointPos = tRootTransform.position + tTileList[j + 1]
        tgroup.transform.position = tWayPointPos
        tgroup.pointAt(tFutWayPointPos, vector(0, 0, 1))
        tEntry = tgroup.transform.duplicate()
      else
        tgroup.transform.position = tWayPointPos
        tEntry = tgroup.transform.duplicate()
      end if
      tWayPointList.append(tEntry)
    end repeat
  else
    repeat with j = t2 down to t1
      tWayPointPos = tRootTransform.position + tTileList[j]
      if j < tTileList.count then
        tFutWayPointPos = tRootTransform.position + tTileList[j + 1]
        tgroup.transform.position = tWayPointPos
        tgroup.pointAt(tFutWayPointPos, vector(0, 0, 1))
        tgroup.rotate(0, 0, 180, #self)
        tEntry = tgroup.transform.duplicate()
      else
        tgroup.transform.position = tWayPointPos
        tgroup.rotate(0, 0, 180, #self)
        tEntry = tgroup.transform.duplicate()
      end if
      tWayPointList.append(tEntry)
    end repeat
  end if
  if voidp(gGame[#WPHelpers]) = 0 then
    if gGame.WPHelpers = 1 then
      tResource = gGame.member.modelResource("WPHelper")
      if tResource = VOID then
        tResource = gGame.member.newModelResource("WPHelper", #box)
      end if
      tResource.width = 10.0
      tResource.height = 1.0
      tResource.length = 1.0
      if gGame.member.shader("Proxy_Material") = VOID then
        CreateProxyShader(0, gGame.member.name)
      end if
      repeat with j = 1 to tWayPointList.count
        tmodel = gGame.member.newModel(tGroupRoot.name & "WPHelper" & j, tResource)
        tmodel.shaderList = gGame.member.shader("Proxy_Material")
        tmodel.transform = tWayPointList[j].duplicate()
      end repeat
    end if
  end if
  gGame.member.deleteGroup("WaypointHelper")
  return [tWayPointList, tReverse]
end

on BuildObjects me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tResource = VOID
  if (tDataList[#object].ilk = #symbol) or (tDataList[#object].ilk = #string) then
    tResource = tmember.modelResource(string(tDataList.object))
  end if
  if tResource = VOID then
    return 0
  end if
  tResourceName = tResource.name
  tRoot = tmember.group("World")
  if tDataList[#ROOT].ilk = #group then
    tRoot = tDataList.ROOT
  end if
  if tDataList[#ROOT].ilk = #string then
    tRoot = GetReferenceType(0, tmember, tDataList.ROOT)
  end if
  tRootName = tRoot.name
  tParent = tRoot
  if tDataList[#parent].ilk = #string then
    tParent = GetReferenceType(0, tmember, tDataList.parent)
    if tParent = VOID then
      tParent = tmember.newGroup(tDataList.parent)
    end if
    if tParent.parent <> tRoot then
      tParent.parent = tRoot
      tParent.userData.addProp(#parent, tRoot)
    end if
  end if
  if tParent.userData.getaProp(#objects) = VOID then
    tParent.userData.addProp(#objects, [])
  end if
  if tParent.userData.getaProp(#rigidBodies) = VOID then
    tParent.userData.addProp(#rigidBodies, [])
  end if
  tLocation = []
  if tDataList[#location].ilk = #list then
    tLocation = tDataList.location
  end if
  if tLocation.count = 0 then
    return 0
  end if
  tHide = 0
  tNoPhysics = 0
  tPinned = 0
  if tDataList[#hide].ilk = #integer then
    tHide = tDataList.hide
  end if
  if tDataList[#noPhysics].ilk = #integer then
    tNoPhysics = tDataList.noPhysics
  end if
  if tDataList[#pinned].ilk = #integer then
    tPinned = tDataList.pinned
  end if
  tShader = tmember.shader("DefaultShader")
  if tDataList[#shader].ilk = #shader then
    tShader = tDataList.shader
  end if
  if tDataList[#shader].ilk = #string then
    tShader = tmember.shader(tDataList.shader)
  end if
  if tDataList[#shader].ilk = #symbol then
    if tDataList.shader = #original then
      tShader = DuplicateShader(0, tmember.name, [#shader: member("Objects").model(string(tDataList.object)).shader.name, #sourceMember: "Objects", #Override: 1])
    end if
  end if
  tExceptionList = ["ai1start_object", "ai2start_object", "ai3start_object", "ai4start_object", "ai5start_object", "ai6start_object", "ai7start_object", "player1start_object", "player2start_object", "player3start_object", "player4start_object", "startline_object", "checkpoint_object", "finishline_object"]
  the itemDelimiter = "_"
  tCount = tLocation.count
  repeat with i = 1 to tCount
    tmodel = tmember.newModel(string(tRootName & "_" & tResourceName.item[1] & "_" & i & "_Object"), tResource)
    tmodel.shader = tShader
    tmodel.parent = tParent
    tmodel.worldPosition = tLocation[i][1]
    q = tLocation[i][2]
    tAngle = 2 * atan(sqrt(1.0 - (q[4] * q[4])), q[4]) * 180 / pi()
    t = sqrt(1 - (q[4] * q[4]))
    if t = 0 then
      tVector = vector(0, 1, 0)
    else
      tVector = vector(q[1] / sqrt(1 - (q[4] * q[4])), q[3] / sqrt(1 - (q[4] * q[4])), q[2] / sqrt(1 - (q[4] * q[4])))
    end if
    tmodel.transform.axisAngle = [tVector, tAngle]
    if tExceptionList.getPos(tResourceName) <> 0 then
      if voidp(gGame[#StartPositions]) = 1 then
        gGame[#StartPositions] = [:]
      end if
      if (tResourceName contains "Start" = 1) and (tResourceName contains "Line" = 0) then
        gGame.StartPositions[symbol(tResourceName.item[1])] = tmodel.getWorldTransform().duplicate()
      end if
      if (tResourceName contains "Line") or (tResourceName contains "Checkpoint") then
        if voidp(gGame[#CheckPoints]) = 1 then
          gGame[#CheckPoints] = [:]
        end if
        if voidp(gGame.CheckPoints[symbol(tRoot.name)]) = 1 then
          gGame.CheckPoints[symbol(tRoot.name)] = []
        end if
        if tResourceName = "StartLine_Object" then
          gGame.CheckPoints[symbol(tRoot.name)].add([#transform: tmodel.getWorldTransform().duplicate(), #type: #start])
        end if
        if tResourceName = "FinishLine_Object" then
          gGame.CheckPoints[symbol(tRoot.name)].add([#transform: tmodel.getWorldTransform().duplicate(), #type: #finish])
        end if
        if tResourceName = "Checkpoint_Object" then
          gGame.CheckPoints[symbol(tRoot.name)].add([#transform: tmodel.getWorldTransform().duplicate(), #type: #checkPoint])
        end if
      end if
      if gGame.CPHelpers = 0 then
        tmember.deleteModelResource(tmodel.resource.name)
        tmember.deleteModel(tmodel.name)
      end if
      next repeat
    end if
    tmodel.addModifier(#meshDeform)
    if voidp(gGame.fx.boundingBox[symbol(tResourceName)]) = 1 then
      tBB = GetBoundingBox(0, tmember.name, [#model: tmodel.name])
    else
      tBB = gGame.fx.boundingBox[symbol(tResourceName)]
    end if
    tObjectData = [#mass: #static, #restitution: 0.10000000000000001, #friction: 0.10000000000000001, #isPinned: tPinned, #type: #default, #Health: #infinite, #score: 0, #script: #none, #sound: #none, #dieOnCollision: 0, #onDeath: #none]
    if voidp(gData.data.objects[symbol(tResourceName)]) = 0 then
      repeat with l = 1 to gData.data.objects[symbol(tResourceName)].count
        tProp = gData.data.objects[symbol(tResourceName)].getPropAt(l)
        tObjectData[tProp] = gData.data.objects[symbol(tResourceName)][l]
      end repeat
    end if
    tDoNotRBList = ["finishtext_object"]
    if tDoNotRBList.getPos(tResourceName) <> 0 then
      tNoPhysics = 1
    end if
    if tNoPhysics = 0 then
      if tObjectData.mass = #static then
        tBodyProxy = #concaveShape
      else
        tBodyProxy = #convexShape
      end if
      if (tmodel.name contains "SamSite") or (tmodel.name contains "MountedGun") then
        tBodyProxy = #box
      end if
      if tObjectData.mass = #static then
        tRB = createRigidBody(0, tmember.name, [#model: tmodel.name, #type: #static, #bodyProxy: tBodyProxy, #restitution: tObjectData.restitution, #friction: tObjectData.friction, #pinned: tObjectData.isPinned])
      else
        tRB = createRigidBody(0, tmember.name, [#model: tmodel.name, #type: #dynamic, #bodyProxy: tBodyProxy, #restitution: 0.90000000000000002, #friction: 0.90000000000000002, #mass: tObjectData.mass, #pinned: tObjectData.isPinned])
      end if
    end if
    tmodel.userData.addProp(#resource, tmodel.resource.name)
    tmodel.userData.addProp(#transform, tmodel.getWorldTransform().duplicate())
    tmodel.userData.addProp(#LocalTransform, tmodel.transform.duplicate())
    tmodel.userData.addProp(#parent, tmodel.parent)
    tmodel.userData.addProp(#boundingBox, tBB)
    tmodel.userData.addProp(#collision, 0)
    tObjectDataCount = tObjectData.count
    repeat with k = 1 to tObjectDataCount
      tProp = tObjectData.getPropAt(k)
      if [#mass, #restitution, #friction, #isPinned].getPos(tProp) <> 0 then
        next repeat
      end if
      tmodel.userData.addProp(tProp, tObjectData[tProp])
      case tProp of
        #Health:
          if tObjectData[#Health] <> #infinite then
            gGame.fx.Destruction.add(tmodel.name)
          end if
        #sound:
          if tObjectData[#sound] <> #none then
            put "[ALERT]" & TAB & "NO SOUND FUNCTION IMPLEMENTED YET!"
          end if
        #script:
          if tObjectData[#script] <> #none then
            tScript = AddScript(0, EMPTY, [#script: tObjectData[#script], #data: [#member: tmember.name, #model: tmodel.name]])
          end if
          tmodel.userData.script = tScript
        #handler:
          if tObjectData[#handler].ilk = #string then
            sendSprite(0, symbol(tObjectData.handler), tmember, [#model: tmodel])
          end if
        #event:
          if tObjectData[#event].ilk = #string then
            event(0, symbol(tObjectData.event))
          end if
      end case
    end repeat
    tmodel.removeModifier(#meshDeform)
    if gGame.boundingBox = 1 then
      BuildBoundingBox(0, tmember.name, [#model: tmodel.name])
    end if
    tParent.userData.rigidBodies.add(tRB)
    if tHide = 1 then
      tmodel.parent = VOID
    end if
    tParent.userData.objects.add(tmodel)
  end repeat
  return tParent
end

on BuildPickups me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tPickup = VOID
  the itemDelimiter = "_"
  if (tDataList[#pickUp].ilk = #symbol) or (tDataList[#object].ilk = #string) then
    tPickup = string(tDataList.pickUp)
  end if
  tCheckList = []
  if tDataList[#checkList].ilk = #list then
    tCheckList = tDataList.checkList.duplicate()
  end if
  repeat with i in tCheckList
    if i.ilk <> #list then
      next repeat
      next repeat
    end if
    if i.getPos(tPickup.item[1]) <> 0 then
      return 0
    end if
  end repeat
  tResource = VOID
  tResource = tmember.modelResource(tPickup)
  if tResource = VOID then
    return 0
  end if
  tResourceName = tResource.name
  tRoot = tmember.group("World")
  if tDataList[#ROOT].ilk = #group then
    tRoot = tDataList.ROOT
  end if
  if tDataList[#ROOT].ilk = #string then
    tRoot = GetReferenceType(0, tmember, tDataList.ROOT)
  end if
  tRootName = tRoot.name
  tParent = tRoot
  if tDataList[#parent].ilk = #string then
    tParent = GetReferenceType(0, tmember, tDataList.parent)
    if tParent = VOID then
      tParent = tmember.newGroup(tDataList.parent)
    end if
    if tParent.parent <> tRoot then
      tParent.parent = tRoot
      tParent.userData.addProp(#parent, tRoot)
    end if
  end if
  if tParent.userData.getaProp(#Pickups) = VOID then
    tParent.userData.addProp(#Pickups, [])
  end if
  tLocation = []
  if tDataList[#location].ilk = #list then
    tLocation = tDataList.location
  end if
  if tLocation.count = 0 then
    return 0
  end if
  tShader = tmember.shader("DefaultShader")
  if tDataList[#shader].ilk = #shader then
    tShader = tDataList.shader
  end if
  if tDataList[#shader].ilk = #string then
    tShader = tmember.shader(tDataList.shader)
  end if
  if tDataList[#shader].ilk = #symbol then
    if tDataList.shader = #original then
      tShader = DuplicateShader(0, tmember.name, [#shader: member("Pickups").model(string(tDataList.pickUp)).shader.name, #sourceMember: "Pickups", #Override: 1])
    end if
  end if
  tCount = tLocation.count
  repeat with i = 1 to tCount
    tmodel = tmember.newModel(tRootName & "_" & tPickup.item[1] & "_" & i & "_Pickup", tResource)
    tmodel.pointAtOrientation = [vector(0, -1, 0), vector(0, 0, 1)]
    tmodel.shader = tShader
    tmodel.parent = tParent
    tmodel.worldPosition = tLocation[i][1]
    tParent.userData.Pickups.add(tmodel)
  end repeat
  return tParent
end

on BuildCameras me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  if (tDataList[#camera].ilk = #symbol) or (tDataList[#camera].ilk = #string) then
    tCamera = string(tDataList.camera)
  else
    return 0
  end if
  tRoot = tmember.group("World")
  if tDataList[#ROOT].ilk = #group then
    tRoot = tDataList.ROOT
  end if
  if tDataList[#ROOT].ilk = #string then
    tRoot = GetReferenceType(0, tmember, tDataList.ROOT)
  end if
  tRootName = tRoot.name
  tParent = tRoot
  if tDataList[#parent].ilk = #string then
    tParent = GetReferenceType(0, tmember, tDataList.parent)
    if tParent = VOID then
      tParent = tmember.newGroup(tDataList.parent)
    end if
    if tParent.parent <> tRoot then
      tParent.parent = tRoot
      tParent.userData.addProp(#parent, tRoot)
    end if
  end if
  if tParent.userData.getaProp(#Cameras) = VOID then
    tParent.userData.addProp(#Cameras, [])
  end if
  tLocation = []
  if tDataList[#location].ilk = #list then
    tLocation = tDataList.location
  end if
  if tLocation.count = 0 then
    return 0
  end if
  tCount = tLocation.count
  repeat with i = 1 to tCount
    tCamera = tmember.newCamera(tCamera)
    tCamera.parent = tRoot
    tCamera.worldPosition = tLocation[i][1]
    q = tLocation[i][2]
    tAngle = 2 * atan(sqrt(1.0 - (q[4] * q[4])), q[4]) * 180 / pi()
    t = sqrt(1 - (q[4] * q[4]))
    if t = 0 then
      tVector = vector(0, 1, 0)
    else
      x = q[1] / sqrt(1 - (q[4] * q[4]))
      y = q[2] / sqrt(1 - (q[4] * q[4]))
      z = q[3] / sqrt(1 - (q[4] * q[4]))
      tVector = vector(x, z, y)
    end if
    tAxisAngle = [tVector, tAngle]
    tCamera.transform.axisAngle = tAxisAngle
    tCamera.transform.rotation.x = tCamera.transform.rotation.x + 90.0
    tCamera.fieldOfView = 40.0
    tParent.userData.Cameras.add(tCamera)
  end repeat
  return tParent
end

on BuildMarkers me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  if (tDataList[#marker].ilk = #symbol) or (tDataList[#marker].ilk = #string) then
    tMarker = string(tDataList.marker)
  else
    return 0
  end if
  tMarkerName = tMarker
  tRoot = tmember.group("World")
  if tDataList[#ROOT].ilk = #group then
    tRoot = tDataList.ROOT
  end if
  if tDataList[#ROOT].ilk = #string then
    tRoot = GetReferenceType(0, tmember, tDataList.ROOT)
  end if
  tRootName = tRoot.name
  tParent = tRoot
  if tDataList[#parent].ilk = #string then
    tParent = GetReferenceType(0, tmember, tDataList.parent)
    if tParent = VOID then
      tParent = tmember.newGroup(tDataList.parent)
    end if
    if tParent.parent <> tRoot then
      tParent.parent = tRoot
      tParent.userData.addProp(#parent, tRoot)
    end if
  end if
  if tParent.userData.getaProp(#markers) = VOID then
    tParent.userData.addProp(#markers, [:])
  end if
  tLocation = []
  if tDataList[#location].ilk = #list then
    tLocation = tDataList.location
  end if
  if tLocation.count = 0 then
    return 0
  end if
  tHide = 0
  if tDataList[#hide].ilk = #integer then
    tHide = tDataList.hide
  end if
  if voidp(gGame[#MarkerTransformList]) = 1 then
    gGame[#MarkerTransformList] = [:]
    gGame.MarkerTransformList.sort()
  end if
  the itemDelimiter = "_"
  tCount = tLocation.count
  repeat with i = 1 to tCount
    tName = tMarker
    tMarkerName = tMarker
    tMarker = tmember.newGroup(tName.item[1] & "_Group")
    tMarker.parent = tRoot
    tMarker.worldPosition = tLocation[i][1]
    q = tLocation[i][2]
    tAngle = 2 * atan(sqrt(1.0 - (q[4] * q[4])), q[4]) * 180 / pi()
    t = sqrt(1 - (q[4] * q[4]))
    if t = 0 then
      tVector = vector(0, 1, 0)
    else
      x = q[1] / sqrt(1 - (q[4] * q[4]))
      y = q[2] / sqrt(1 - (q[4] * q[4]))
      z = q[3] / sqrt(1 - (q[4] * q[4]))
      tVector = vector(x, z, y)
    end if
    tAxisAngle = [tVector, tAngle]
    tMarker.transform.axisAngle = tAxisAngle
    tTransform = tMarker.getWorldTransform().duplicate()
    tmember.deleteGroup(tMarker.name)
    tEntry = [#state: #empty, #type: #default, #model: #none, #transform: tTransform]
    tParent.userData.markers.addProp(symbol(tName), tEntry)
    gGame.MarkerTransformList[symbol(tMarkerName)] = tEntry
  end repeat
  return tParent
end
