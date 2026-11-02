-- [Script] [PS] Plane OLD (Script #5881)
-- Script Type: Parent

property p
global gSystem, gData, gGame

on new me, tDataList
  p = [:]
  t = new(script("[PS] p"))
  if voidp(gGame[#vehicles]) = 1 then
    gGame[#vehicles] = [:]
  end if
  if voidp(gGame[#CurrentVehicle]) = 1 then
    gGame[#CurrentVehicle] = [:]
  end if
  if voidp(gGame[#Physics]) = 1 then
    return 0
  end if
  tmember = member(tDataList[#member])
  tScriptName = tDataList[#ScriptName]
  tController = tDataList[#controller]
  if (tController <> #player) and (tController <> #AI) then
    return 0
  end if
  if (voidp(gGame[#AI]) = 0) and (tController = #AI) then
    if gGame.AI = 0 then
      return 0
    end if
  end if
  if tController = #player then
    tResult = CreateVehicle(0, tmember, [#controller: #player, #car: "PlayerPlane"])
  end if
  if tController = #AI then
    tResult = CreateVehicle(0, tmember, [#controller: #AI, #car: gGame.trackInfo.Enemies[gGame.Iteration]])
  end if
  tCarName = tResult.vehicleName
  tmodel = tResult.model
  tProxy = tResult.Proxy
  tShadowModel = tResult.shadowmodel
  tModelList = tResult.modelList
  tNitroModels = tResult.nitroModels
  tData = tResult.data
  tEffectlist = tResult.effectList
  tWeaponPlaceLIst = tResult.weaponPlaceList
  tTag = symbol(tmodel.name)
  tTransform = tmodel.transform
  tCarParams = tData.settings
  tMass = tCarParams[#mass]
  tCurrentSpeed = 0.0
  tMaxSpeed = tCarParams[#maxSpeed]
  tSpeedPerc = 0.0
  tHovering = 0
  tSlip = 0
  tAccGain = tCarParams[#accGain]
  tDecGain = tCarParams[#brakegain]
  tTurnGain = tCarParams[#turnGain]
  tWheelTurn = 0.0
  tWheelSpin = 0.0
  tMaxWheelTurn = tCarParams[#MaxWheelTurn]
  tWheelTurnSpeed = float(tMaxWheelTurn * 0.10000000000000001)
  tHoverDist = member(tCarName).model(tCarName).transform.position.z + tCarParams[#hoverOffset]
  tStrength = tCarParams[#strength]
  tDamping = tCarParams[#damping]
  tGrip = tCarParams[#grip]
  tDrag = tCarParams[#drag]
  tAdjGrip = tGrip
  tDriftGrip = tCarParams[#driftGrip]
  tBanking = tCarParams[#Banking]
  tAdjBanking = 0.0
  tCollisionDetails = [EMPTY, EMPTY, vector(1.0, 0.0, 0.0), vector(1.0, 0.0, 0.0)]
  tIntersectDetails = [:]
  tHealth = tCarParams[#Health]
  tResetPosition = vector(0, 0, 0)
  tResetRotation = [vector(1, 0, 0), 180]
  if gGame.Scene = "Track" then
    if voidp(gGame[#StartPositions]) = 0 then
      if (tController = #player) and (voidp(gGame.StartPositions[symbol("player" & (gGame.PlayersBuild + 1) & "Start")]) = 0) then
        tResetPosition = gGame.StartPositions[symbol("player" & (gGame.PlayersBuild + 1) & "Start")].position + (gGame.StartPositions[symbol("player" & (gGame.PlayersBuild + 1) & "Start")].zAxis * tHoverDist)
        tResetRotation = gGame.StartPositions[symbol("player" & (gGame.PlayersBuild + 1) & "Start")].axisAngle
      end if
      if (tController = #AI) and (voidp(gGame.StartPositions[symbol("AI" & (gGame.AIsBuild + 1) & "Start")]) = 0) then
        tResetPosition = gGame.StartPositions[symbol("AI" & (gGame.AIsBuild + 1) & "Start")].position + (gGame.StartPositions[symbol("AI" & (gGame.AIsBuild + 1) & "Start")].zAxis * tHoverDist)
        tResetRotation = gGame.StartPositions[symbol("AI" & (gGame.AIsBuild + 1) & "Start")].axisAngle
      end if
    end if
  else
    tMarker = symbol(gGame.WorldStartDummy[symbol(gGame.world)])
    tResetPosition = gGame.MarkerTransformList[tMarker].transform.position + vector(0, 0, tHoverDist)
    tResetRotation = gGame.MarkerTransformList[tMarker].transform.axisAngle
  end if
  tShaderList = []
  repeat with i in tResult.modelList
    tShader = i.shader
    tShader.useDiffuseWithTexture = 1
    if (tShaderList.getPos(tShader) = 0) and not (i.shader.name contains "Proxy") then
      tShaderList.add(tShader)
    end if
  end repeat
  tCamIndex = 1
  if tController = #player then
    tCount = gGame.vehicles.count
    repeat with i in gGame.vehicles
      if i.general.controller = #player then
        tCamIndex = tCamIndex + 1
      end if
    end repeat
  end if
  tgroup = tmember.newGroup(tmodel.name & "_Group")
  tgroup.pointAtOrientation = [vector(0.0, 1.0, 0.0), vector(0.0, 0.0, 1.0)]
  tgroup.transform.position = tResetPosition
  tgroup.transform.axisAngle = tResetRotation
  tLeader = tmember.newGroup(tTag & "Leader_Group")
  tLeader.pointAtOrientation = [vector(0.0, 1.0, 0.0), vector(0.0, 0.0, 1.0)]
  tStates = tDataList[#States]
  if gGame.Scene = "World" then
    tStates.deleteOne(#update_WayPoints)
  end if
  if gGame.Scene = "Track" then
    tStates.deleteOne(#update_Markers)
    if voidp(gGame[#VehicleHelpers]) = 0 then
      if gGame.VehicleHelpers = 1 then
        tStates.add(#update_Helpers)
      end if
    end if
  end if
  t[#general] = [#member: tmember, #controller: tController, #tag: tTag, #player: gGame.vehicles.count + 1, #limit: 0, #data: tData, #States: tStates.duplicate(), #origStates: tStates.duplicate(), #script: me]
  t[#Vehicle] = [#RotY: 0, #RotX: 0, #name: tCarName, #model: tmodel, #Proxy: tProxy, #glassModel: #none, #shadowmodel: tShadowModel, #nitroModels: tNitroModels, #nitroTargetScale: vector(1, 1, 1), #lightModels: [], #shaderList: tShaderList, #transform: tTransform, #previousT: tTransform.duplicate(), #ResetPosition: tResetPosition, #ResetRotation: tResetRotation, #group: tgroup, #mass: tMass, #Speed: tCurrentSpeed, #maxSpeed: tMaxSpeed, #SpeedPerc: tSpeedPerc, #Hovering: tHovering, #slip: tSlip, #Nitro: 0, #hold: #none, #accGain: tAccGain, #decGain: tDecGain, #turnGain: tTurnGain, #currentGain: 0.0, #MaxWheelTurn: tMaxWheelTurn, #WheelTurnSpeed: tWheelTurnSpeed, #WheelTurn: tWheelTurn, #WheelSpin: tWheelSpin, #Banking: tBanking, #AdjBanking: tAdjBanking, #yRot: 0, #HoverDist: tHoverDist, #strength: tStrength, #damping: tDamping, #grip: tGrip, #AdjGrip: tGrip, #driftGrip: tDriftGrip, #drag: tDrag, #currentFloor: VOID, #FloorList: gGame.FloorList.duplicate(), #impacts: [], #currentRootNr: 1, #previousRootNR: 0, #RootList: [], #previousRootList: [], #currentTile: [], #previousTile: [], #collisionDetails: tCollisionDetails, #intersectDetails: tIntersectDetails, #Health: tHealth, #Effects: tEffectlist, #weaponPlaceList: tWeaponPlaceLIst]
  t[#race] = [#state: #none, #position: gGame.vehicles.count + 1, #Leader: tLeader, #leaderModel: VOID, #time: 0, #score: 0, #storedScore: 0, #addScore: 0, #CheckPoints: 0, #WayPointList: [], #waypoint: 1, #Waypoints: 0, #WaypointDistance: 0.0, #WaypointT: transform(), #waypointZ: 0.0, #perpVector: vector(), #perpDistance: 0.0, #perpOffSet: 0.0, #wrongWayCounter: 0, #stuckCounter: 0, #stuckPosition: tmodel.worldPosition]
  t[#Input] = [:]
  t[#camera] = [#index: tCamIndex, #inView: [], #inViewPos: [], #distanceToTarget: [], #MaxDistanceToTarget: 30.0]
  gGame.vehicles[tTag] = t
  SetItemDelimiter(0, "_")
  repeat with i in tStates
    tString = string(i)
    tHandler = symbol("setup_" & tString.item[2])
    sendSprite(0, tHandler, t)
  end repeat
  ResetItemDelimiter()
  p[#tag] = t.general.tag
  t = InitializeCar(t, tCarParams)
  if t.general.controller = #player then
    gGame.PlayersBuild = gGame.PlayersBuild + 1
  else
    gGame.AIsBuild = gGame.AIsBuild + 1
  end if
  t = VOID
  p[#MoveX] = 0
  p[#MoveY] = 0
  p[#boost] = 0
  p[#Input] = [:]
  return me
  return me
end

on InitializeCar t, tCarParams
  t.Vehicle.Proxy.addModifier(#meshDeform)
  t.Vehicle.Proxy.removeFromWorld()
  tPhysicsCar = gGame.Physics.createRigidBody(t.Vehicle.Proxy.name, t.Vehicle.Proxy.name, #convexShape, #dynamic)
  tPhysicsCar.friction = tCarParams[#friction]
  tPhysicsCar.restitution = tCarParams[#restitution]
  tPhysicsCar.mass = t.Vehicle.mass
  tPhysicsCar.angularDamping = 1.30000000000000004
  tPhysicsCar.position = t.Vehicle.ResetPosition
  tPhysicsCar.orientation = t.Vehicle.ResetRotation
  tPhysicsCar.linearVelocity = vector(0, 0, 0)
  tPhysicsCar.angularVelocity = vector(0, 0, 0)
  t.Vehicle[#RigidBody] = tPhysicsCar
  CreateCollisionReport(0, EMPTY, [#nameA: t.Vehicle.Proxy.name, #nameB: #all])
  t.Vehicle[#wheellist] = []
  return t
end

on enterFrame me
  t = gGame.vehicles[p.tag]
  t.camera.inView = []
  t.camera.inViewPos = []
  t.camera.distanceToTarget = []
  repeat with i in gGame.camera
    tInViewPos = i.camera.worldSpaceToSpriteSpace(t.Vehicle.Proxy.transform.position)
    if tInViewPos = VOID then
      t.camera.inView.add(0)
    else
      t.camera.inView.add(1)
    end if
    t.camera.inViewPos.add(tInViewPos)
    tCameraPos = i.transform.position
    t.camera.distanceToTarget.add(tCameraPos.distanceTo(t.Vehicle.Proxy.transform.position))
  end repeat
  tLimit = 0
  if t.camera.inView.getOne(1) = 0 then
    tLimit = 1
  end if
  if t.camera.distanceToTarget.min() < t.camera.MaxDistanceToTarget then
    tLimit = 0
  end if
  t.general.limit = tLimit
  if t.Vehicle.Health = 0 then
    t.Vehicle.model.transform = t.Vehicle.Proxy.transform
    exit
  end if
  tList = t.general.States.duplicate()
  repeat with i in tList
    tResult = sendSprite(0, i, t)
    if tResult = 1 then
      exit repeat
    end if
  end repeat
  tModelT = t.Vehicle.transform
  tDirection = -vector(0, 0, 1)
  tOptionList = [#maxNumberOfModels: 1, #levelOfDetail: #detailed, #modelList: t.Vehicle.FloorList, #maxDistance: 5.0]
  tIntersectDetails = t.general.member.modelsUnderRay(t.Vehicle.model.worldPosition, tDirection, tOptionList)
  if tIntersectDetails.count > 0 then
    tIntersectDetails = tIntersectDetails[1]
    t.Vehicle.currentFloor = tIntersectDetails.model
    if gGame.Scene = "World" then
      tName = tIntersectDetails.model.name
      t.Vehicle.currentTile = [value(tName.char[1..2]), value(tName.char[4..5])]
    end if
    if gGame.Scene = "Track" then
      t.Vehicle.currentRootNr = gGame.FloorList.getPos(t.Vehicle.currentFloor)
      tRootList = [t.Vehicle.currentRootNr]
      tRootList.sort()
      if (tRootList[1] - 1) > 0 then
        tRootList.add(tRootList[1] - 1)
      end if
      repeat with i = 1 to 3
        if (tRootList[tRootList.count] + 1) <= gGame.RootList.count then
          tRootList.add(tRootList[tRootList.count] + 1)
        end if
      end repeat
      t.Vehicle.RootList = tRootList
      if tRootList <> t.Vehicle.previousRootList then
        tFloorList = []
        repeat with i in t.Vehicle.RootList
          tFloorList.add(gGame.FloorList[i])
        end repeat
        t.Vehicle.FloorList = tFloorList
        t.Vehicle.previousRootList = t.Vehicle.RootList
      end if
    else
      t.Vehicle.FloorList = gGame.FloorList
    end if
    t.Vehicle[#ISectShader] = tIntersectDetails[#model].shaderList[tIntersectDetails[#meshID]]
    t.Vehicle.intersectDetails = tIntersectDetails
    tShadowModel = t.Vehicle.shadowmodel
    if tShadowModel.isInWorld() = 0 then
      tShadowModel.addToWorld()
    end if
    tShadowModel.transform.position = tIntersectDetails[#isectPosition] + vector(0, 0, 0.05)
    tShadowModel.pointAtOrientation = [vector(0, 0, 1), vector(0, 1, 0)]
    tShadowModel.pointAt(tShadowModel.transform.position + tIntersectDetails[#isectNormal])
    tShadowModel.rotate(0, 0, t.Vehicle.Proxy.transform.rotation[3])
  else
    t.Vehicle.shadowmodel.parent = VOID
  end if
  tPhysicsCar = t.Vehicle.RigidBody
  tPhysicsCar.position = t.Vehicle.model.worldPosition
  tPhysicsCar.orientation = t.Vehicle.model.transform.axisAngle
  tPhysicsCar.angularVelocity = vector(0, 0, 0)
  tPhysicsCar.linearVelocity = vector(0, 0, 0)
  t.Vehicle.previousT = t.Vehicle.transform.duplicate()
  if gGame.RaceState = #Pending then
    me.reset(t)
  end if
  if _player.runMode <> "Plugin" then
    if keyPressed("r") then
      me.reset(t, 1, 0)
    end if
  end if
  if _player.runMode = "Plugin" then
    if keyPressed("r") then
      me.reset(t, 1, 0)
    end if
  end if
end

on reset me, t, tWaypoint, tRay, tInPlace, tDummy
  if gGame.Scene = "World" then
    t.Vehicle.currentTile = GetTile(0, symbol(gGame.WorldStartDummy[symbol(gGame.world)]))
    t.Vehicle.ResetPosition = gGame.MarkerTransformList[symbol(gGame.WorldStartDummy[symbol(gGame.world)])].transform.position + vector(0, 0, t.Vehicle.HoverDist)
    t.Vehicle.ResetRotation = gGame.MarkerTransformList[symbol(gGame.WorldStartDummy[symbol(gGame.world)])].transform.axisAngle
    if gGame.MiniMap.markerlist.getaProp(gGame.WorldStartDummy[symbol(gGame.world)]) = VOID then
      nothing()
    else
      gGame.MiniMap.markerlist[gGame.WorldStartDummy[symbol(gGame.world)]].model.parent = VOID
      gGame.MiniMap.markerlist[gGame.WorldStartDummy[symbol(gGame.world)]].Active = 0
    end if
  end if
  tPosition = t.Vehicle.ResetPosition
  tRotation = t.Vehicle.ResetRotation
  if tInPlace = 1 then
    tPosition = t.Vehicle.transform.position
    p.ResetGroup.transform.position = tPosition
    tPointAt = tPosition + (t.Vehicle.transform.yAxis * 100)
    tPointAt.z = tPosition.z
    p.ResetGroup.pointAt(tPointAt, vector(0, 0, 1))
    tRotation = p.ResetGroup.transform.axisAngle
  end if
  if tDummy <> VOID then
    tDummy = GetReferenceType(0, t.general.member, tDummy)
    if tDummy <> VOID then
      tPosition = tDummy.getWorldTransform().position + vector(0, 0, t.Vehicle.HoverDist)
      tRotation = tDummy.getWorldTransform().axisAngle
    end if
  end if
  if tWaypoint = 1 then
    if t.race.WayPointList.count <= 2 then
      me.reset(t, 0, 1)
      exit
    end if
    tTransform = t.race.WayPointList[t.race.waypoint].duplicate()
    tPosition = tTransform.position + vector(0, 0, t.Vehicle.HoverDist + 15.0)
    tRotation = tTransform.axisAngle
  end if
  if tRay = 1 then
    tRayDetails = gGame.Physics.rayCastClosest(tPosition, vector(0, 0, -1.00099999999999989))
    if tRayDetails.count > 0 then
      tPosition = tRayDetails[2] + vector(0.0, 0.0, t.Vehicle.HoverDist)
    else
      tPosition = tPosition + vector(0.0, 0.0, t.Vehicle.HoverDist)
    end if
  end if
  t.Vehicle.Proxy.transform.position = tPosition
  t.Vehicle.Proxy.transform.axisAngle = tRotation
  t.Vehicle.RigidBody.position = tPosition
  t.Vehicle.RigidBody.orientation = tRotation
  t.Vehicle.RigidBody.linearVelocity = vector(0, 0, 0)
  t.Vehicle.RigidBody.angularVelocity = vector(0, 0, 0)
  t.Vehicle.group.transform.position = tPosition
  t.Vehicle.group.transform.rotation = vector()
  t.Vehicle.model.transform.position = tPosition
  t.Vehicle.model.transform.rotation = vector()
  tOptionList = [#maxNumberOfModels: 1, #levelOfDetail: #detailed, #modelList: gGame.FloorList, #maxDistance: 5.0]
  tIntersectDetails = t.general.member.modelsUnderRay(t.Vehicle.Proxy.worldPosition, vector(0.0001, 0.0001, -1.00009999999999999), tOptionList)
  if tIntersectDetails.count > 0 then
    tIntersectDetails = tIntersectDetails[1]
    t.Vehicle.currentFloor = tIntersectDetails.model
    if gGame.Scene = "World" then
      tName = tIntersectDetails.model.name
      t.Vehicle.currentTile = [value(tName.char[1..2]), value(tName.char[4..5])]
    end if
    if gGame.Scene = "Track" then
      t.Vehicle.currentRootNr = gGame.FloorList.getPos(t.Vehicle.currentFloor)
      tRootList = [t.Vehicle.currentRootNr]
      tRootList.sort()
      if (tRootList[1] - 1) > 0 then
        tRootList.add(tRootList[1] - 1)
      end if
      repeat with i = 1 to 1
        if (tRootList[tRootList.count] + 1) <= gGame.RootList.count then
          tRootList.add(tRootList[tRootList.count] + 1)
        end if
      end repeat
      t.Vehicle.RootList = tRootList
      if tRootList <> t.Vehicle.previousRootList then
        tFloorList = []
        repeat with i in t.Vehicle.RootList
          tFloorList.add(gGame.FloorList[i])
        end repeat
        t.Vehicle.FloorList = tFloorList
        t.Vehicle.previousRootList = t.Vehicle.RootList
      end if
    else
      t.Vehicle.FloorList = gGame.FloorList
    end if
  end if
end

on delete me
  gGame.vehicles.deleteProp(me.p.tag)
  if gGame.vehicles.count = 0 then
    gGame.deleteProp(#vehicles)
  end if
  p = [:]
  if gSystem.scriptList.getPos(me) <> 0 then
    gSystem.scriptList.deleteOne(me)
  else
    gGame.scriptList.deleteOne(me)
  end if
end
