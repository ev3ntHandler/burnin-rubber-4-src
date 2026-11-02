-- [Script] [PS] Autobot (Script #5883)
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
    tResult = CreateVehicle(0, tmember, [#controller: #player, #car: "PlayerCar"])
  end if
  if tController = #AI then
    tResult = CreateVehicle(0, tmember, [#controller: #AI, #car: gGame.trackInfo.Enemies[gGame.Iteration]])
  end if
  tCarName = tResult.vehicleName
  tmodel = tResult.model
  tProxy = tResult.Proxy
  tShadowModel = tResult.shadowmodel
  tGlassModel = tResult.glassModel
  tModelList = tResult.modelList
  tNitroModels = tResult.nitroModels
  tLightModels = tResult.lightModels
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
  tBanking = tCarParams[#Banking]
  tAdjBanking = 0.0
  tHoverDist = member(tCarName).model(tCarName).transform.position.z + tCarParams[#hoverOffset]
  tStrength = tCarParams[#strength]
  tDamping = tCarParams[#damping]
  tGrip = tCarParams[#grip]
  tDrag = tCarParams[#drag]
  tAdjGrip = tGrip
  tDriftGrip = tCarParams[#driftGrip]
  tCollisionDetails = [EMPTY, EMPTY, vector(1.0, 0.0, 0.0), vector(1.0, 0.0, 0.0)]
  tIntersectDetails = [:]
  tHealth = tData.personality.Health
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
  if tController = #AI then
    tStates.deleteOne(#update_AutoFight)
    tStates.add(#Update_Autobot)
  end if
  t[#general] = [#member: tmember, #controller: tController, #tag: tTag, #player: gGame.vehicles.count + 1, #limit: 0, #data: tData, #States: tStates.duplicate(), #origStates: tStates.duplicate(), #script: me]
  t[#Vehicle] = [#name: tCarName, #model: tmodel, #Proxy: tProxy, #glassModel: tGlassModel, #shadowmodel: tShadowModel, #nitroModels: tNitroModels, #nitroTargetScale: vector(1, 1, 1), #lightModels: tLightModels, #shaderList: tShaderList, #transform: tTransform, #previousT: tTransform.duplicate(), #ResetPosition: tResetPosition, #ResetRotation: tResetRotation, #group: tgroup, #mass: tMass, #Speed: tCurrentSpeed, #maxSpeed: tMaxSpeed, #SpeedPerc: tSpeedPerc, #Hovering: tHovering, #slip: tSlip, #Nitro: 0, #hold: #none, #accGain: tAccGain, #decGain: tDecGain, #turnGain: tTurnGain, #currentGain: 0.0, #MaxWheelTurn: tMaxWheelTurn, #WheelTurnSpeed: tWheelTurnSpeed, #WheelTurn: tWheelTurn, #WheelSpin: tWheelSpin, #Banking: tBanking, #AdjBanking: tAdjBanking, #HoverDist: tHoverDist, #strength: tStrength, #damping: tDamping, #grip: tGrip, #AdjGrip: tGrip, #driftGrip: tDriftGrip, #drag: tDrag, #currentFloor: VOID, #FloorList: gGame.FloorList, #impacts: [], #currentRootNr: 1, #previousRootNR: 0, #RootList: [], #previousRootList: [], #currentTile: [], #previousTile: [], #tileOverride: 0, #collisionDetails: tCollisionDetails, #intersectDetails: tIntersectDetails, #Health: tHealth, #Effects: tEffectlist, #weaponPlaceList: tWeaponPlaceLIst, #horn: 0, #Lights: 0]
  t[#race] = [#state: #none, #position: gGame.vehicles.count + 1, #Leader: tLeader, #leaderModel: VOID, #time: 0, #score: 0, #storedScore: 0, #addScore: 0, #CheckPoints: 0, #WayPointList: [], #waypoint: 1, #Waypoints: 0, #WaypointDistance: 0.0, #WaypointT: transform(), #waypointZ: 0.0, #perpVector: vector(), #perpDistance: 0.0, #perpOffSet: 0.0, #wrongWayCounter: 0, #stuckCounter: 0, #stuckPosition: tmodel.worldPosition]
  t[#Input] = [:]
  t[#camera] = [#index: tCamIndex, #inView: [], #inViewPos: [], #distanceToTarget: [], #MaxDistanceToTarget: 30.0]
  gGame.vehicles[tTag] = t
  p[#tag] = t.general.tag
  t = InitializeCar(t, tCarParams)
  the itemDelimiter = "_"
  repeat with i in tStates
    tString = string(i)
    tHandler = symbol("setup_" & tString.item[2])
    sendSprite(0, tHandler, t)
  end repeat
  if t.general.controller = #player then
    gGame.PlayersBuild = gGame.PlayersBuild + 1
  else
    gGame.AIsBuild = gGame.AIsBuild + 1
  end if
  p[#ResetGroup] = tmember.newGroup(tController & gGame.PlayersBuild & "Reset_Dummy")
  p.ResetGroup.pointAtOrientation = [vector(0.0, 1.0, 0.0), vector(0.0, 0.0, 1.0)]
  t.race[#ResetGroup] = p.ResetGroup
  t = VOID
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
  CreateCollisionReport(0, EMPTY, [#nameA: t.Vehicle.Proxy.name, #nameB: #all, #CollisionDamage: 1])
  tName = t.Vehicle.model.name
  tmember = t.general.member
  tWheelList = [tmember.model(tName & "Wheel_LF"), tmember.model(tName & "Wheel_RF"), tmember.model(tName & "Wheel_LB"), tmember.model(tName & "Wheel_RB")]
  t.Vehicle[#wheellist] = tWheelList
  tCarMember = member(t.Vehicle.name)
  tOrigNames = [t.Vehicle.name & "Wheel_LF", t.Vehicle.name & "Wheel_RF", t.Vehicle.name & "Wheel_LB", t.Vehicle.name & "Wheel_RB"]
  tCount = tWheelList.count
  repeat with i = 1 to tCount
    tdiff = tCarMember.model(tOrigNames[i]).transform.position - tCarMember.model(t.Vehicle.name).transform.position
    tWheelList[i].parent = t.Vehicle.model
    tWheelList[i].transform.position = vector(0.0, 0.0, 0.0)
    tWheelList[i].transform.position = tWheelList[i].transform.position + tdiff
    tWheelList[i].userData.addProp(#parent, t.Vehicle.model)
    tWheelList[i].userData.addProp(#transform, tWheelList[i].transform.duplicate())
  end repeat
  gGame.member.model(tName & "Glass").transform.position = vector(0, 0, 0)
  gGame.member.model(tName & "Glass").parent = t.Vehicle.model
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
  t.Vehicle.model.transform = t.Vehicle.Proxy.transform
  if t.Vehicle.Health = 0 then
    exit
  end if
  tList = t.general.States.duplicate()
  repeat with i in tList
    tResult = sendSprite(0, i, t)
    if tResult = 1 then
      exit
    end if
  end repeat
  tTransform = transform()
  tTransform.rotation = t.Vehicle.Proxy.transform.rotation.duplicate()
  tWorldForward = tTransform * vector(0.0, 1.0, 0.0)
  tWorldAxis = tTransform * -vector(0.0, 0.0, -1.0)
  tWorldRight = tWorldForward.cross(tWorldAxis)
  tWorldDown = tTransform * vector(0.0, 0.0, -1.0)
  tWorldForward.normalize()
  tWorldAxis.normalize()
  tWorldRight.normalize()
  tWorldDown.normalize()
  tChassisPos = t.Vehicle.Proxy.transform.position
  tPhysicsCar = t.Vehicle.RigidBody
  tCurrentVel = tPhysicsCar.linearVelocity
  tForwardVel = tWorldForward * tCurrentVel
  t.Vehicle.Speed = tCurrentVel.dot(tWorldForward)
  t.Vehicle.SpeedPerc = abs(t.Vehicle.Speed / t.Vehicle.maxSpeed)
  tDirection = tWorldDown + vector(0.0001, 0.0001, 0.0001)
  if t.Vehicle.Hovering = 0 then
    tDirection = vector(0.0001, 0.0001, -1.00009999999999999)
  end if
  tOptionList = [#maxNumberOfModels: 1, #levelOfDetail: #detailed, #modelList: t.Vehicle.FloorList, #maxDistance: 5.0]
  tIntersectDetails = t.general.member.modelsUnderRay(tChassisPos, tDirection, tOptionList)
  if tIntersectDetails.count > 0 then
    tIntersectDetails = tIntersectDetails[1]
    t.Vehicle.currentFloor = tIntersectDetails.model
    if (gGame.Scene = "World") and (t.Vehicle.tileOverride = 0) then
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
      t.Vehicle[#ISectShader] = tIntersectDetails[#model].shaderList[tIntersectDetails[#meshID]]
      t.Vehicle.intersectDetails = tIntersectDetails
    else
      t.Vehicle.FloorList = gGame.FloorList
    end if
    tDetails = gGame.Physics.rayCastClosest(tChassisPos, tDirection)
    if tDetails[4] < (t.Vehicle.HoverDist + 2.5) then
      tPhysicsCar.angularVelocity = vector(0, 0, 0)
      tdiff = tDetails[2] - tChassisPos
      tLength = tdiff.length
      tF = -t.Vehicle.strength * (t.Vehicle.HoverDist - tLength)
      tF = tF - (t.Vehicle.damping * tCurrentVel.dot(tdiff))
      tForce = tdiff * tF * t.Vehicle.mass
      tForce = tForce * 4
      tPhysicsCar.applyLinearImpulse(tForce, tChassisPos)
      t.Vehicle.Hovering = 1
      tgroup = t.Vehicle.group
      tgroup.transform = t.Vehicle.Proxy.transform.duplicate()
      thisPosn = tgroup.getWorldTransform().position - (1050.0 * tDetails[3])
      startT = tgroup.getWorldTransform()
      tgroup.pointAt(thisPosn, tWorldForward)
      endT = tgroup.getWorldTransform()
      newT = startT.interpolate(endT, 45)
      tgroup.transform = newT
      tPhysicsCar.orientation = tgroup.transform.axisAngle
      tPhysicsCar.angularVelocity = vector(0, 0, 0)
    else
      t.Vehicle.Hovering = 0
    end if
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
    t.Vehicle.Hovering = 0
  end if
  if t.Vehicle.Hovering = 1 then
    tAdjTurnGain = t.Vehicle.turnGain
    if t.Vehicle.Nitro = 1 then
      tAdjMaxSpeed = t.Vehicle.maxSpeed + gGame.NitroBoost
    else
      tAdjMaxSpeed = t.Vehicle.maxSpeed
    end if
    if t.general.controller = #AI then
      tAdjMaxSpeed = t.Vehicle.maxSpeed
    end if
    if abs(t.Vehicle.Speed) >= (t.Vehicle.maxSpeed * 0.25) then
      tAdjTurnGain = t.Vehicle.turnGain
    else
      tPercentage = abs(t.Vehicle.Speed) / (t.Vehicle.maxSpeed * 0.25)
      tPercentage = min(1.0, tPercentage)
      tAdjTurnGain = t.Vehicle.turnGain * tPercentage
    end if
    if tAdjTurnGain < 0.05 then
      tAdjTurnGain = 0.0
    end if
    if (t.Vehicle.Speed < 0) and (t.Input.forward = 1) then
      tSteering = 0
    else
      if (t.Vehicle.Speed > 0) and (t.Input.backward = 1) then
        tSteering = 0
      else
        tSteering = 1
      end if
    end if
    if t.Input.forward = 1 then
      tdiff = tAdjMaxSpeed - t.Vehicle.Speed
      imp = tdiff * t.Vehicle.accGain * t.Vehicle.mass * tWorldForward
      tPhysicsCar.applyLinearImpulse(imp)
    end if
    if t.Input.backward = 1 then
      tdiff = (-tAdjMaxSpeed / 2.0) - t.Vehicle.Speed
      imp = tdiff * t.Vehicle.decGain * t.Vehicle.mass * tWorldForward
      tPhysicsCar.applyLinearImpulse(imp)
    end if
    if t.Input.brake = 1 then
      t.Vehicle.slip = 1
      t.Vehicle.AdjGrip = t.Vehicle.driftGrip
    end if
    if t.Vehicle.slip = 1 then
      if t.Vehicle.AdjGrip < t.Vehicle.grip then
        t.Vehicle.AdjGrip = t.Vehicle.AdjGrip + 0.02
      end if
      if t.Vehicle.AdjGrip > t.Vehicle.grip then
        t.Vehicle.AdjGrip = t.Vehicle.grip
      end if
      if t.Vehicle.AdjGrip = t.Vehicle.grip then
        t.Vehicle.slip = 0
      end if
    end if
    if tSteering = 1 then
      if t.Input.left = 1 then
        imp = tWorldAxis * (tAdjTurnGain * (t.Vehicle.mass * 0.90000000000000002))
        if t.Vehicle.Speed < 0.0 then
          imp = -imp
        end if
        if t.Input.joystick = 1 then
          imp = imp * t.Input.leftPerc
        end if
        tPhysicsCar.applyAngularImpulse(imp)
      end if
      if t.Input.right = 1 then
        imp = tWorldAxis * (-tAdjTurnGain * (t.Vehicle.mass * 0.90000000000000002))
        if t.Vehicle.Speed < 0.0 then
          imp = -imp
        end if
        if t.Input.joystick = 1 then
          imp = imp * t.Input.rightPerc
        end if
        tPhysicsCar.applyAngularImpulse(imp)
      end if
    end if
    tSlideSpeed = tWorldRight.dot(tCurrentVel)
    imp = tWorldRight * (-tSlideSpeed * t.Vehicle.mass * t.Vehicle.AdjGrip)
    tPhysicsCar.applyLinearImpulse(imp)
    imp = -tCurrentVel * (t.Vehicle.drag * t.Vehicle.mass)
    tPhysicsCar.applyLinearImpulse(imp)
  end if
  t.Vehicle.previousT = t.Vehicle.transform.duplicate()
  tCos = tWorldAxis.dot(vector(0, 0, 1))
  if (t.Vehicle.Hovering = 0) and (abs(t.Vehicle.Speed) <= 0.25) and (tCos < 0.29999999999999999) then
    me.reset(t, 1, 0)
  end if
  if (t.Vehicle.Hovering = 0) and (t.race.waypointZ <= -35.0) then
    me.reset(t, 1, 0)
  end if
  if gGame.RaceState = #Pending then
    me.reset(t)
  end if
  if _player.runMode <> "Plugin" then
    if keyPressed("r") then
      if gGame.Scene = "World" then
        me.reset(t, 0, 0)
      else
        me.reset(t, 1, 0)
      end if
    end if
  end if
  if _player.runMode = "Plugin" then
    if keyPressed("r") then
      if gGame.Scene = "World" then
        me.reset(t, 0, 0)
      else
        me.reset(t, 1, 0)
      end if
    end if
  end if
  if t.Vehicle.hold <> #none then
    me.reset(t, 0, 1, 0, t.Vehicle.hold)
  end if
end

on reset me, t, tWaypoint, tRay, tInPlace, tDummy
  if gGame.Scene = "World" then
    t.Vehicle.currentTile = GetTile(0, symbol(gGame.WorldStartDummy[symbol(gGame.world)]))
    t.Vehicle.ResetPosition = gGame.MarkerTransformList[symbol(gGame.WorldStartDummy[symbol(gGame.world)])].transform.position + vector(0, 0, t.Vehicle.HoverDist)
    t.Vehicle.ResetRotation = gGame.MarkerTransformList[symbol(gGame.WorldStartDummy[symbol(gGame.world)])].transform.axisAngle
    if voidp(gGame[#MiniMap]) = 0 then
      if gGame.MiniMap.markerlist.getaProp(gGame.WorldStartDummy[symbol(gGame.world)]) = VOID then
        nothing()
      else
        if voidp(gGame[#WorldMission]) = 1 then
          gGame.MiniMap.markerlist[gGame.WorldStartDummy[symbol(gGame.world)]].model.parent = VOID
          gGame.MiniMap.markerlist[gGame.WorldStartDummy[symbol(gGame.world)]].Active = 0
        end if
      end if
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
    tPosition = tTransform.position + vector(0, 0, t.Vehicle.HoverDist)
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
  t.Vehicle.model.transform = t.Vehicle.Proxy.transform
  tOptionList = [#maxNumberOfModels: 1, #levelOfDetail: #detailed, #modelList: gGame.FloorList, #maxDistance: 5.0]
  tIntersectDetails = t.general.member.modelsUnderRay(t.Vehicle.Proxy.worldPosition, vector(0.0001, 0.0001, -1.00009999999999999), tOptionList)
  if tIntersectDetails.count > 0 then
    tIntersectDetails = tIntersectDetails[1]
  end if
  if tIntersectDetails.count > 0 then
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
      tAmount = 1
      if gGame.ShowMore then
        tAmount = 2
      end if
      repeat with i = 1 to tAmount
        if (tRootList[tRootList.count] + 1) <= gGame.RootList.count then
          tRootList.add(tRootList[tRootList.count] + 1)
        end if
      end repeat
      if tRootList <> t.Vehicle.RootList then
        t.Vehicle.previousRootList = t.Vehicle.RootList
        t.Vehicle.RootList = tRootList
        tFloorList = []
        repeat with i in t.Vehicle.RootList
          tFloorList.add(gGame.FloorList[i])
        end repeat
        t.Vehicle.FloorList = tFloorList
      end if
    else
      t.Vehicle.FloorList = gGame.FloorList
    end if
    tShadowModel = t.Vehicle.shadowmodel
    if tShadowModel.isInWorld() = 0 then
      tShadowModel.addToWorld()
    end if
    tShadowModel.transform.position = tIntersectDetails[#isectPosition] + vector(0, 0, 0.05)
    tShadowModel.pointAtOrientation = [vector(0, 0, 1), vector(0, 1, 0)]
    tShadowModel.pointAt(tShadowModel.transform.position + tIntersectDetails[#isectNormal])
    tShadowModel.rotate(0, 0, t.Vehicle.Proxy.transform.rotation[3])
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
