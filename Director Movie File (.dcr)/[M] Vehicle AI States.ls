-- [Script] [M] Vehicle AI States (Script #5872)
-- Script Type: Movie

global gSystem, gData, gGame, gSound

on setup_AutoDrive me, t
end

on update_AutoDrive me, t
end

on reset_autoDrive me, t
end

on setup_AutoRace me, t
  t.Input[#joystick] = 0
  tCount = gGame.PlayerKeys1.count
  repeat with i = 1 to tCount
    tProp = gGame.PlayerKeys1.getPropAt(i)
    t.Input[tProp] = 0
  end repeat
end

on update_AutoRace me, t
  t.race.Leader.worldPosition = t.Vehicle.Proxy.worldPosition
  tdiff = t.race.Waypoints - gGame.vehicles[1].race.Waypoints
  if tdiff <= gGame.RaceRubberOn then
    t.Vehicle.maxSpeed = t.general.data.settings.maxSpeed + gGame.RaceSpeedBoost
    t.Vehicle.accGain = t.general.data.settings.accGain + gGame.RaceAccBoost
  end if
  if tdiff >= gGame.RaceRubberOff then
    t.Vehicle.maxSpeed = t.general.data.settings.maxSpeed
    t.Vehicle.accGain = t.general.data.settings.accGain
  end if
  tTarget = t.race.waypoint + 5
  if tTarget > t.race.WayPointList.count then
    tTarget = t.race.WayPointList.count
  end if
  tTotalAmount = 0
  tStartDiff = 0.0
  tChassisAxis = abs(t.Vehicle.model.transform.axisAngle[2])
  repeat with i = 1 to 15
    tNr = t.race.waypoint + i
    if tNr > t.race.WayPointList.count then
      tNr = t.race.WayPointList.count
    end if
    tPointAtPos = t.race.WayPointList[tNr].position
    tPointAtPos.z = t.race.Leader.transform.position.z
    if tPointAtPos = t.race.Leader.transform.position then
      tDifference = 0.0
    else
      t.race.Leader.pointAt(tPointAtPos, vector(0.0, 0.0, 1.0))
      tLeaderHelperAxis = abs(t.race.Leader.transform.axisAngle[2])
      tDifference = abs(tLeaderHelperAxis - tChassisAxis)
    end if
    tTotalAmount = tTotalAmount + tDifference
    if i = tTarget then
      tStartDiff = tDifference
    end if
  end repeat
  tGenDiff = tTotalAmount / 15
  tBrakingDifference = abs(tStartDiff - tGenDiff)
  if tBrakingDifference > 15.0 then
    t.Input.brake = 1
  else
    t.Input.brake = 0
  end if
  t.Input.forward = 1
  tPointAtPos = t.race.WayPointList[tTarget].position
  tPointAtPos.z = t.race.Leader.transform.position.z
  if tPointAtPos = t.race.Leader.transform.position then
    tDifference = 0.0
  else
    t.race.Leader.pointAt(tPointAtPos, vector(0.0, 0.0, 1.0))
    tLeaderHelperAxis = abs(t.race.Leader.transform.axisAngle[2])
    tDifference = abs(tLeaderHelperAxis - tChassisAxis)
  end if
  tLeftRight = LeftOrRight(0, t.race.WayPointList[tTarget], t.Vehicle.Proxy.transform)
  t.Input.right = 0
  t.Input.left = 0
  if tDifference > 3.5 then
    if tLeftRight[2] < 0.0 then
      t.Input.left = 1
    else
      t.Input.right = 1
    end if
  end if
  if gGame.RaceState <> #Pending then
    t.race.stuckCounter = t.race.stuckCounter + 1
    if (t.race.stuckCounter * gGame.tempo) >= 2000 then
      tDistance = t.race.stuckPosition.distanceTo(t.Vehicle.model.worldPosition)
      if tDistance <= 1.0 then
        t.general.script.reset(t, 1, 0)
      else
        t.race.stuckPosition = t.Vehicle.model.worldPosition
      end if
      t.race.stuckCounter = 0
    end if
  end if
end

on reset_AutoRace me, t, tState
  if tState = VOID then
    tState = #delete
  end if
  tCount = t.Input.count
  repeat with i = 1 to tCount
    tProp = t.Input.getPropAt(i)
    if (tProp = #joystick) or (tProp = #keySet) or (tProp = #Keys) then
      next repeat
    end if
    t.Input[tProp] = 0
  end repeat
  if tState = #delete then
    t.general.States.deleteOne(#update_AutoRace)
  end if
end

on setup_AutoFight me, t
end

on update_AutoFight me, t
  if gGame.AIFriendlyFire = 1 then
    tList = gGame.vehicles.duplicate()
    tList.deleteOne(t)
  else
    tList = [gGame.vehicles[1]]
  end if
  tTransform1 = t.Vehicle.transform
  repeat with i in tList
    tTransform2 = i.Vehicle.transform
    pos1 = tTransform1.position - tTransform2.position
    pos1.normalize()
    tForward = pos1.dot(tTransform2.yAxis)
    tLeftRight = pos1.dot(tTransform2.xAxis)
    if tForward > 0 then
      t.Input.action1 = 0
      if (t.general.data.Weapons.secondary = "MineDeployer") or (t.general.data.Weapons.secondary = "GrenadeDeployer") then
        if abs(tLeftRight) <= 0.29999999999999999 then
          t.Input.action2 = 1
        else
          t.Input.action2 = 0
        end if
      end if
    else
      if abs(tLeftRight) <= 0.29999999999999999 then
        t.Input.action1 = 1
        if (t.general.data.Weapons.secondary <> "MineDeployer") or (t.general.data.Weapons.secondary <> "GrenadeDeployer") then
          if abs(tLeftRight) <= 0.29999999999999999 then
            t.Input.action2 = 1
          else
            t.Input.action2 = 0
          end if
        end if
      else
        t.Input.action1 = 0
        t.Input.action2 = 0
      end if
    end if
    if (t.Input.action1 = 1) or (t.Input.action2 = 1) then
      exit repeat
    end if
  end repeat
end

on reset_AutoFight me, t, tState
  if tState = VOID then
    tState = #delete
  end if
  t.Input.action1 = 0
  t.Input.action2 = 0
  if tState = #delete then
    t.general.States.deleteOne(#update_AutoFight)
  end if
end
