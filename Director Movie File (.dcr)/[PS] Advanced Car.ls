-- [Script] [PS] Advanced Car (Script #5927)
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
    if tShaderList.getPos(tShader) = 0 then
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
    if gGame.Effects <> #high then
      if tStates.getPos(#update_CarEffects) then
        tStates.deleteOne(#update_CarEffects)
      end if
    end if
    if gGame.Effects = #low then
      if tStates.getPos(#update_CarSoundAI) then
        tStates.deleteOne(#update_CarSoundAI)
      end if
    end if
  end if
  t[#general] = [#member: tmember, #controller: tController, #tag: tTag, #player: gGame.vehicles.count + 1, #limit: 0, #data: tData, #States: tStates.duplicate(), #origStates: tStates.duplicate(), #script: me]
  t[#Vehicle] = [#name: tCarName, #model: tmodel, #Proxy: tProxy, #glassModel: tGlassModel, #shadowmodel: tShadowModel, #nitroModels: tNitroModels, #nitroTargetScale: vector(1, 1, 1), #lightModels: tLightModels, #shaderList: tShaderList, #transform: tTransform, #previousT: tTransform.duplicate(), #ResetPosition: tResetPosition, #ResetRotation: tResetRotation, #group: tgroup, #mass: tMass, #Speed: tCurrentSpeed, #maxSpeed: tMaxSpeed, #SpeedPerc: tSpeedPerc, #Hovering: tHovering, #slip: tSlip, #Nitro: 0, #hold: #none, #accGain: tAccGain, #decGain: tDecGain, #turnGain: tTurnGain, #currentGain: 0.0, #MaxWheelTurn: tMaxWheelTurn, #WheelTurnSpeed: tWheelTurnSpeed, #WheelTurn: tWheelTurn, #WheelSpin: tWheelSpin, #Banking: tBanking, #AdjBanking: tAdjBanking, #HoverDist: tHoverDist, #strength: tStrength, #damping: tDamping, #grip: tGrip, #AdjGrip: tGrip, #driftGrip: tDriftGrip, #drag: tDrag, #currentFloor: VOID, #FloorList: gGame.FloorList, #impacts: [], #currentRootNr: 1, #previousRootNR: 0, #RootList: [], #previousRootList: [], #currentTile: [], #previousTile: [], #tileOverride: 0, #collisionDetails: tCollisionDetails, #intersectDetails: tIntersectDetails, #Health: tHealth, #Effects: tEffectlist, #weaponPlaceList: tWeaponPlaceLIst, #horn: 0, #Lights: 0]
  t[#race] = [#state: #none, #position: gGame.vehicles.count + 1, #Leader: tLeader, #leaderModel: VOID, #time: 0, #score: 0, #storedScore: 0, #addScore: 0, #CheckPoints: 0, #WayPointList: [], #waypoint: 1, #Waypoints: 0, #WaypointDistance: 0.0, #WaypointT: transform(), #waypointZ: 0.0, #perpVector: vector(), #perpDistance: 0.0, #perpOffSet: 0.0, #wrongWayCounter: 0, #stuckCounter: 0, #stuckPosition: tmodel.worldPosition]
  t[#Input] = [:]
  t[#camera] = [#index: tCamIndex, #inView: [], #inViewPos: [], #distanceToTarget: [], #MaxDistanceToTarget: 20.0]
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
  p[#ResetGroup] = tmember.newGroup(tController & gGame.vehicles.count & "Reset_Dummy")
  p.ResetGroup.pointAtOrientation = [vector(0.0, 1.0, 0.0), vector(0.0, 0.0, 1.0)]
  t.race[#ResetGroup] = p.ResetGroup
  if gGame.Scene = "World" then
    reset(0, t, 0, 0)
  end if
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
  if gGame.track = "SpecialMissionConvoy" then
    CreateCollisionReport(0, EMPTY, [#nameA: t.Vehicle.Proxy.name, #nameB: #all])
  else
    CreateCollisionReport(0, EMPTY, [#nameA: t.Vehicle.Proxy.name, #nameB: #all, #CollisionDamage: 1])
  end if
  tName = t.Vehicle.model.name
  tmember = t.general.member
  tWheelList = [tmember.model(tName & "Wheel_LF"), tmember.model(tName & "Wheel_RF"), tmember.model(tName & "Wheel_LB"), tmember.model(tName & "Wheel_RB")]
  t.Vehicle[#wheellist] = tWheelList
  t.Vehicle[#IsHoveringList] = [0, 0, 0, 0]
  t.Vehicle[#HoverDistList] = [0.0, 0.0, 0.0, 0.0]
  com = t.Vehicle.RigidBody.centerOfMass
  tWidth = abs(tWheelList[1].transform.position.x) + abs(tWheelList[2].transform.position.x)
  tWheelBase = (abs(tWheelList[2].transform.position.y) + abs(tWheelList[4].transform.position.y)) / 2
  posA = com + (tWheelBase * vector(0, 1, 0)) + (tWidth * 0.5 * -vector(1, 0, 0))
  posB = com + (tWheelBase * vector(0, 1, 0)) + (tWidth * 0.5 * vector(1, 0, 0))
  posC = com + (tWheelBase * -vector(0, 1, 0)) + (tWidth * 0.5 * -vector(1, 0, 0))
  posD = com + (tWheelBase * -vector(0, 1, 0)) + (tWidth * 0.5 * vector(1, 0, 0))
  t.Vehicle[#WheelPointList] = [posA, posB, posC, posD]
  t.Vehicle[#WheelRadius] = member(t.Vehicle.name).model(t.Vehicle.name & "Wheel_LF").boundingSphere[2]
  t.Vehicle[#WheelRadiusDEV] = abs(tWheelList[1].transform.position.y - tWheelBase)
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
    return 0
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
  tPhysicsCar = t.Vehicle.RigidBody
  tChassisPos = t.Vehicle.Proxy.transform.position + tPhysicsCar.centerOfMass
  tCurrentVel = tPhysicsCar.linearVelocity
  tForwardVel = tWorldForward * tCurrentVel
  tAngularVel = tPhysicsCar.angularVelocity
  t.Vehicle.Speed = tCurrentVel.dot(tWorldForward)
  t.Vehicle.SpeedPerc = abs(t.Vehicle.Speed / t.Vehicle.maxSpeed)
  tPowerCoeff = t.Vehicle.IsHoveringList[1] + t.Vehicle.IsHoveringList[2] + t.Vehicle.IsHoveringList[3] + t.Vehicle.IsHoveringList[4]
  tPowerCoeff = tPowerCoeff / 4.0
  tProxyT = t.Vehicle.Proxy.transform
  repeat with i = 1 to t.Vehicle.WheelPointList.count
    t.Vehicle.IsHoveringList[i] = 0
    tWorldWheelPoint = tProxyT * t.Vehicle.WheelPointList[i]
    tIntersectDetails = gGame.Physics.rayCastClosest(tWorldWheelPoint, tWorldDown + vector(0.0001, 0.0001, 0.0001))
    if tIntersectDetails.count > 0 then
      if tIntersectDetails[4] < t.Vehicle.HoverDist then
        tPointVelocity = tCurrentVel + tAngularVel.cross(tWorldWheelPoint - tChassisPos)
        tdiff = tIntersectDetails[2] - tWorldWheelPoint
        tLength = tdiff.length
        tF = -t.Vehicle.strength * (t.Vehicle.HoverDist - tLength)
        tF = tF - (t.Vehicle.damping * tPointVelocity.dot(tdiff))
        tForce = tdiff * tF * t.Vehicle.mass
        tPhysicsCar.applyLinearImpulse(tForce, t.Vehicle.WheelPointList[i])
        t.Vehicle.IsHoveringList[i] = 1
        t.Vehicle.HoverDistList[i] = tLength
      end if
    end if
  end repeat
  if t.Vehicle.IsHoveringList.getPos(1) = 0 then
    t.Vehicle.Hovering = 0
    if tPhysicsCar.angularVelocity.magnitude < 0.69999999999999996 then
      tPhysicsCar.angularVelocity = tPhysicsCar.angularVelocity * 0.69999999999999996
    end if
  else
    t.Vehicle.Hovering = 1
  end if
  tDirection = tWorldDown + vector(0.0001, 0.0001, 0.0001)
  if t.Vehicle.Hovering = 0 then
    tDirection = vector(0.0001, 0.0001, -1.00009999999999999)
  end if
  tOptionList = [#maxNumberOfModels: 1, #levelOfDetail: #detailed, #modelList: t.Vehicle.FloorList, #maxDistance: 5.0]
  tRayPosition = t.Vehicle.model.transform.position
  tIntersectDetails = t.general.member.modelsUnderRay(tRayPosition, tDirection, tOptionList)
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
    t.Vehicle[#ISectShader] = tIntersectDetails[#model].shaderList[tIntersectDetails[#meshID]]
    t.Vehicle.intersectDetails = tIntersectDetails
    tShadowModel = t.Vehicle.shadowmodel
    if tShadowModel.isInWorld() = 0 then
      tShadowModel.addToWorld()
    end if
    tShadowModel.transform.position = tIntersectDetails[#isectPosition] + vector(0, 0, 0.05)
    tShadowModel.pointAtOrientation = [vector(0, 0, 1), vector(0, 1, 0)]
    tShadowModel.pointAt(tShadowModel.transform.position + tIntersectDetails[#isectNormal])
    tDot = t.Vehicle.Proxy.transform.yAxis.dot(vector(1, 0, 0))
    tAngle = t.Vehicle.Proxy.transform.yAxis.angleBetween(vector(0, 1, 0))
    if tDot > 0 then
      tAngle = -tAngle
    end if
    tShadowModel.rotate(0, 0, tAngle)
  else
    t.Vehicle.shadowmodel.parent = VOID
  end if
  if tPowerCoeff > 0.0 then
    if gGame.UPUnlockableCheats.getPos(#UnlimitedNitro) <> 0 then
      if gGame.NitroOVerride = 0 then
        if _key.keyPressed("n") = 1 then
          t.Vehicle.Nitro = 1
          gGame.camera[1][#fov] = 75.0
        else
          if voidp(t.Weapons[#NitroBoost]) = 0 then
            if t.Input.action2 = 0 then
              t.Vehicle.Nitro = 0
              gGame.camera[1][#fov] = 55.0
            end if
          else
            t.Vehicle.Nitro = 0
            gGame.camera[1][#fov] = 55.0
          end if
        end if
      end if
    end if
    tAdjTurnGain = t.Vehicle.turnGain
    if t.Vehicle.Nitro = 1 then
      tAdjMaxSpeed = t.Vehicle.maxSpeed + gGame.NitroBoost
    else
      tAdjMaxSpeed = t.Vehicle.maxSpeed
    end if
    if abs(t.Vehicle.Speed) >= (t.Vehicle.maxSpeed * 0.22500000000000001) then
      tAdjTurnGain = t.Vehicle.turnGain
    else
      tPercentage = abs(t.Vehicle.Speed) / (t.Vehicle.maxSpeed * 0.22500000000000001)
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
      imp = tdiff * t.Vehicle.accGain * t.Vehicle.mass * tWorldForward * tPowerCoeff
      tPhysicsCar.applyLinearImpulse(imp)
    end if
    if t.Input.backward = 1 then
      tdiff = (-tAdjMaxSpeed / 2.0) - t.Vehicle.Speed
      imp = tdiff * t.Vehicle.decGain * t.Vehicle.mass * tWorldForward * tPowerCoeff
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
        imp = tWorldAxis * (tAdjTurnGain * (t.Vehicle.mass * 0.90000000000000002)) * tPowerCoeff
        if t.Vehicle.Speed < 0.0 then
          imp = -imp
        end if
        if t.Input.joystick = 1 then
          imp = imp * t.Input.leftPerc
        end if
        tPhysicsCar.applyAngularImpulse(imp)
      end if
      if t.Input.right = 1 then
        imp = tWorldAxis * (-tAdjTurnGain * (t.Vehicle.mass * 0.90000000000000002)) * tPowerCoeff
        if t.Vehicle.Speed < 0.0 then
          imp = -imp
        end if
        if t.Input.joystick = 1 then
          imp = imp * t.Input.rightPerc
        end if
        tPhysicsCar.applyAngularImpulse(imp)
      end if
    end if
    tAngVelLength = tAngularVel.length
    if tAngVelLength > 0.0 then
      if abs(t.Vehicle.Speed) <= (t.Vehicle.maxSpeed * 7) then
        tPerc = abs(t.Vehicle.Speed) / (t.Vehicle.maxSpeed * 0.69999999999999996)
      else
        tPerc = 1.0
      end if
      tCompensateGain = 0.25 + (tAdjTurnGain * tPerc)
      if tCompensateGain > tAdjTurnGain then
        tCompensateGain = tAdjTurnGain
      end if
      imp = tWorldAxis * tAngularVel.dot(tWorldAxis) * (-tCompensateGain * t.Vehicle.mass) * tPowerCoeff
      tPhysicsCar.applyAngularImpulse(imp)
    end if
    tSlideSpeed = tWorldRight.dot(tCurrentVel)
    imp = tWorldRight * (-tSlideSpeed * t.Vehicle.mass * t.Vehicle.AdjGrip) * tPowerCoeff
    tPhysicsCar.applyLinearImpulse(imp)
    imp = -tCurrentVel * (t.Vehicle.drag * t.Vehicle.mass)
    tPhysicsCar.applyLinearImpulse(imp)
  end if
  if t.Input.left and not (t.Vehicle.WheelTurn < -0.90000000000000002) then
    t.Vehicle.WheelTurn = t.Vehicle.WheelTurn - 0.10000000000000001
  end if
  if t.Input.right and not (t.Vehicle.WheelTurn > 0.90000000000000002) then
    t.Vehicle.WheelTurn = t.Vehicle.WheelTurn + 0.10000000000000001
  end if
  if not t.Input.left and not t.Input.right then
    if not (t.Vehicle.WheelTurn = 0) then
      if t.Vehicle.WheelTurn < 0 then
        t.Vehicle.WheelTurn = t.Vehicle.WheelTurn + 0.10000000000000001
      else
        t.Vehicle.WheelTurn = t.Vehicle.WheelTurn - 0.10000000000000001
      end if
    end if
  end if
  t.Vehicle.WheelSpin = t.Vehicle.WheelSpin - (tForwardVel * (2.0 * gGame.TimeMP))
  if t.Vehicle.WheelSpin > 360 then
    t.Vehicle.WheelSpin = t.Vehicle.WheelSpin - 360
  else
    if t.Vehicle.WheelSpin < -360 then
      t.Vehicle.WheelSpin = t.Vehicle.WheelSpin - 360
    end if
  end if
  repeat with i = 1 to t.Vehicle.IsHoveringList.count
    if t.Vehicle.IsHoveringList[i] = 1 then
      tWorldWheelPoint = tProxyT * (t.Vehicle.WheelPointList[i] + vector(0, t.Vehicle.WheelRadiusDEV, 0))
      t.Vehicle.wheellist[i].transform.position = tWorldWheelPoint + (t.Vehicle.HoverDistList[i] * tWorldDown) - (t.Vehicle.WheelRadius * tWorldDown)
    else
      if t.Vehicle.IsHoveringList[i] = 0 then
        tWorldWheelPoint = tProxyT * (t.Vehicle.WheelPointList[i] + vector(0, t.Vehicle.WheelRadiusDEV, 0))
        t.Vehicle.wheellist[i].transform.position = tWorldWheelPoint + (t.Vehicle.HoverDist * tWorldDown) - (t.Vehicle.WheelRadius * tWorldDown)
      end if
    end if
    t.Vehicle.wheellist[i].transform.rotation = tProxyT.rotation
    tTempTrans = t.Vehicle.wheellist[i].transform.duplicate()
    tTempTrans.position = vector(0, 0, 0)
    tWheelRightDir = tTempTrans * vector(1, 0, 0)
    tWheelRightDir.normalize()
    if (i = 1) or (i = 2) then
      tRot = t.Vehicle.MaxWheelTurn * t.Vehicle.WheelTurn
      t.Vehicle.wheellist[i].transform.rotate(t.Vehicle.wheellist[i].transform.position, tWheelRightDir, t.Vehicle.WheelSpin)
      t.Vehicle.wheellist[i].transform.rotate(t.Vehicle.wheellist[i].transform.position, tWorldDown, tRot)
      next repeat
    end if
    t.Vehicle.wheellist[i].transform.rotate(t.Vehicle.wheellist[i].transform.position, tWheelRightDir, t.Vehicle.WheelSpin)
  end repeat
  if t.Input.right and not (t.Vehicle.AdjBanking < -0.90000000000000002) then
    t.Vehicle.AdjBanking = t.Vehicle.AdjBanking - (0.10000000000000001 * gGame.TimeMP)
  end if
  if t.Input.left and not (t.Vehicle.AdjBanking > 0.90000000000000002) then
    t.Vehicle.AdjBanking = t.Vehicle.AdjBanking + (0.10000000000000001 * gGame.TimeMP)
  end if
  if ((t.Input.left = 0) and (t.Input.right = 0)) or (t.Vehicle.Hovering = 0) then
    if not (t.Vehicle.AdjBanking = 0) then
      if t.Vehicle.AdjBanking < 0 then
        t.Vehicle.AdjBanking = t.Vehicle.AdjBanking + (0.10000000000000001 * gGame.TimeMP)
      else
        t.Vehicle.AdjBanking = t.Vehicle.AdjBanking - (0.10000000000000001 * gGame.TimeMP)
      end if
    end if
  end if
  tBanking = t.Vehicle.SpeedPerc * (t.Vehicle.AdjBanking * t.Vehicle.Banking)
  t.Vehicle.model.transform.rotate(t.Vehicle.model.transform.position, t.Vehicle.model.transform.yAxis, tBanking)
  t.Vehicle.previousT = t.Vehicle.transform.duplicate()
  tgroup = t.Vehicle.group
  tgroup.transform = t.Vehicle.Proxy.transform.duplicate()
  tCos = tWorldAxis.dot(vector(0, 0, 1))
  if gGame.Scene = "World" then
    if (t.Vehicle.Hovering = 0) and (abs(t.Vehicle.Speed) <= 0.25) and (tCos < 0.29999999999999999) then
      me.reset(t, 0, 1, 1)
    end if
    if (t.Vehicle.Hovering = 0) and (t.Vehicle.transform.position.z <= -100.0) then
      event(0, #WorldFlashFade)
      me.reset(t, 0, 0)
    end if
  else
    if (t.Vehicle.Hovering = 0) and (abs(t.Vehicle.Speed) <= 0.25) and (tCos < 0.29999999999999999) then
      me.reset(t, 1, 1)
    end if
    if (t.Vehicle.Hovering = 0) and (t.race.waypointZ <= -35.0) then
      me.reset(t, 1, 0)
    end if
  end if
  if gGame.RaceState = #Pending then
    me.reset(t)
  end if
  if (_player.runMode <> "Plugin") and (t.general.controller = #player) then
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
