-- [Script] [PS] Traffic Manager (Script #5888)
-- Script Type: Parent

property p
global gSystem, gData, gGame

on new me, tDataList
  p = [:]
  p[#member] = member(tDataList[#member])
  tTrafficMember = member("World" & gGame.world & "TrafficWaypoints")
  if tTrafficMember = VOID then
    return 0
  end if
  gGame[#traffic] = [:]
  gGame.traffic[#cars] = [:]
  gGame.traffic[#Paths] = [:]
  gGame.traffic[#CarsKilled] = []
  gGame.traffic[#totalCount] = 0
  gGame.traffic[#closest] = []
  gGame.traffic[#script] = #none
  me.BuildTrafficPaths(tTrafficMember)
  p[#RayCounter] = [1, 1]
  p[#FloorList] = []
  p[#PLayerDistance] = 150.0
  return me
end

on enterFrame me
  if gGame.traffic.cars.count > 0 then
    if gGame.traffic.cars[p.RayCounter[1]].count > 0 then
      tCurrent = p.RayCounter.duplicate()
      tmodel = p.member.model(gGame.traffic.cars[p.RayCounter[1]][p.RayCounter[2]])
      tUserData = tmodel.userData
      if voidp(gGame[#vehicles]) = 0 then
        p.FloorList = gGame.vehicles[1].Vehicle.FloorList.duplicate()
      end if
      tFloorList = []
      repeat with i in p.FloorList
        if i.name contains "street" then
          tFloorList.add(i)
        end if
      end repeat
      tOptionsList = [#maxNumberOfModels: 1, #levelOfDetail: #detailed, #modelList: tFloorList, #maxDistance: 5.0]
      tUserData.intersectDetails = p.member.modelsUnderRay(tmodel.worldPosition + vector(0, 0, 1.0), vector(0.0001, 0.0001, -1.00009999999999999), tOptionsList)
      if tUserData.intersectDetails.count >= 1 then
        tUserData.intersectDetails = tUserData.intersectDetails[1]
      end if
      p.RayCounter[2] = p.RayCounter[2] + 1
      if p.RayCounter[2] > gGame.traffic.cars[p.RayCounter[1]].count then
        p.RayCounter[2] = 1
        p.RayCounter[1] = p.RayCounter[1] + 1
        if p.RayCounter[1] > gGame.traffic.cars.count then
          p.RayCounter[1] = 1
        end if
      end if
    end if
  end if
  gGame.traffic.closest = []
  if voidp(gGame[#vehicles]) = 1 then
    tPlayerPos = vector(0, 0, 0)
  else
    tPlayerPos = gGame.vehicles[1].Vehicle.model.worldPosition
  end if
  tCount = gGame.traffic.cars.count
  repeat with i = 1 to tCount
    tProp = gGame.traffic.cars.getPropAt(i)
    repeat with j in gGame.traffic.cars[i]
      tmodel = p.member.model(j)
      tUserData = tmodel.userData
      tDistanceToPlayer = tmodel.worldPosition.distanceTo(tPlayerPos)
      if tUserData.collision = 1 then
        tUserData.state = #dying
      end if
      if (tUserData.Health <= 0) and (tUserData.state <> #dead) then
        tUserData.state = #dying
        repeat with m in tUserData.wheels
          m.parent = VOID
        end repeat
      end if
      if tUserData.intersectDetails <> #none then
        if tUserData.intersectDetails.count = 0 then
          if tUserData.state = #dead then
            gGame.traffic.CarsKilled.add(tmodel.name)
          else
            tmodel.parent = VOID
          end if
        else
          tmodel.parent = p.member.group("World")
          tUserData.parent = tUserData.intersectDetails.model
        end if
      end if
      tUserData.intersectDetails = #none
      if tUserData.state = #alive then
        tTarget = tUserData.waypoint + tUserData.direction
        if tTarget > gGame.traffic.Paths[tProp].count then
          tTarget = 1
        end if
        if tTarget = 0 then
          tTarget = gGame.traffic.Paths[tProp].count
        end if
        tTransform = gGame.traffic.Paths[tProp][tTarget].duplicate()
        tTransform.position = tTransform.position + (tTransform.xAxis * tUserData.offset)
        tDirection = tTransform.position - tmodel.transform.position
        tDirection.normalize()
        tmodel.transform.position = tmodel.transform.position + (tDirection * (tUserData.Speed * gGame.TimeMP))
        tCurrentT = tmodel.transform.duplicate()
        tmodel.pointAt(tTransform.position, vector(0, 0, 1))
        tTargetT = tmodel.transform.duplicate()
        tCurrentT.interpolateTo(tTargetT, 18)
        tmodel.transform = tCurrentT
        if tmodel.worldPosition.distanceTo(tTransform.position) <= (tUserData.Speed + 0.05) then
          tUserData.waypoint = tTarget
        end if
        repeat with m in tUserData.wheels
          tRotation = tUserData.Speed * gGame.TimeMP / 2.19910000000000005 * 360
          m.rotate(-tRotation, 0, 0, #self)
        end repeat
        tRB = tUserData.RigidBody
        tRB.linearVelocity = vector(0, 0, 0)
        tRB.angularVelocity = vector(0, 0, 0)
        tRB.position = tCurrentT.position
        if tDistanceToPlayer <= (p.PLayerDistance + 100.0) then
          tRB.orientation = tCurrentT.axisAngle
        end if
      end if
      if tUserData.state = #dying then
        tUserData.shadowmodel.parent = VOID
        repeat with m in tUserData.Lights
          m.parent = VOID
        end repeat
        tUserData.state = #dead
        tRB = tUserData.RigidBody
        tRB.angularDamping = 0.0
        tRB.linearDamping = 0.0
        gGame.Physics.enableCollision(tUserData.RigidBody)
      end if
      if tDistanceToPlayer <= p.PLayerDistance then
        gGame.traffic.closest.add(tmodel.name)
      end if
    end repeat
  end repeat
  repeat with i in gGame.traffic.CarsKilled
    tmodel = p.member.model(i)
    tUserData = tmodel.userData
    DeleteTraffic(0, "World" & gGame.world, tUserData)
    gGame.traffic.cars[tUserData.path].deleteOne(i)
    BuildTraffic(0, "World" & gGame.world, tUserData.data)
  end repeat
  gGame.traffic.CarsKilled = []
end

on delete me
  p = [:]
  gGame.deleteProp(#traffic)
  if gSystem.scriptList.getPos(me) <> 0 then
    gSystem.scriptList.deleteOne(me)
  else
    gGame.scriptList.deleteOne(me)
  end if
end

on BuildTrafficPaths me, tmember
  tTag = "World" & gGame.world & "Traffic"
  tgroup = tmember.newGroup("TrafficWaypointBuilder")
  tgroup.pointAtOrientation = [vector(0.0, 1.0, 0.0), vector(0.0, 0.0, 1.0)]
  if gGame.WPHelpers = 1 then
    tr = member("World" & gGame.world).newModelResource("Sphere", #sphere)
    tr.radius = 0.5
  end if
  repeat with i = 1 to 20
    if i < 10 then
      tNr = "0" & i
    else
      tNr = string(i)
    end if
    if tmember.group(tTag & tNr) = VOID then
      exit repeat
    end if
    gGame.traffic.cars[symbol(tTag & tNr)] = []
    gGame.traffic.Paths[symbol(tTag & tNr)] = []
    repeat with j = 1 to 2000
      if j < 10 then
        tCount = "0" & string(j)
      else
        tCount = string(j)
      end if
      tCurrentGroup = tmember.group(tTag & tNr & "_Waypoint" & tCount)
      if tCurrentGroup = VOID then
        exit repeat
      end if
      tCurrentGroup.transform.position = tCurrentGroup.transform.position + (tCurrentGroup.transform.zAxis * 0.14999999999999999)
      if j < 10 then
        tNextCount = "0" & string(j + 1)
      else
        tNextCount = string(j + 1)
      end if
      tNextGroup = tmember.group(tTag & tNr & "_Waypoint" & tNextCount)
      if tNextGroup = VOID then
        tNextGroup = tmember.group(tTag & tNr & "_Waypoint01")
      end if
      tNextGroup.transform.position = tNextGroup.transform.position + (tNextGroup.transform.zAxis * 0.10000000000000001)
      tgroup.transform = tCurrentGroup.transform.duplicate()
      tgroup.pointAt(tNextGroup.transform.position, tCurrentGroup.transform.zAxis)
      gGame.traffic.Paths[symbol(tTag & tNr)].add(tgroup.transform.duplicate())
      if gGame.WPHelpers = 1 then
        tm = member("World" & gGame.world).newModel("sphere" & j, tr)
        tm.transform = tgroup.transform
      end if
    end repeat
  end repeat
  tmember.resetWorld()
end
