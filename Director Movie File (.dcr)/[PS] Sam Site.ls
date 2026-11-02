-- [Script] [PS] Sam Site (Script #5900)
-- Script Type: Parent

property p
global gSystem, gGame, gData

on new me, tDataList
  if voidp(gGame[#SamSites]) = 0 then
    if gGame.SamSites = 0 then
      return 0
    end if
  end if
  p = [:]
  p[#member] = member(tDataList.member)
  p[#model] = p.member.model(tDataList.model)
  tObjects = member("Objects")
  tName = p.model.name
  if gGame.Scene = "World" then
    tWeaponName = tName.char[1..13] & "weapon" & tName.char[14..tName.length]
  else
    the itemDelimiter = "_"
    tWeaponName = tName.item[1] & "_" & tName.item[2] & "Weapon_" & tName.item[3] & "_" & tName.item[4]
  end if
  p[#weapon] = p.member.newModel(tWeaponName, p.member.modelResource("SamSiteWeapon"))
  p.weapon.shaderList = p.member.shader("WorldMisc_Material")
  p.weapon.pointAtOrientation = [vector(0.0, 1.0, 0.0), vector(0.0, 0.0, 1.0)]
  p[#LaunchTubes] = []
  repeat with i = 1 to 6
    if gGame.Scene = "World" then
      tNewGroup = p.member.newGroup(tName.char[1..16] & "WeaponLaunchTube" & i)
    else
      tNewGroup = p.member.newGroup(tName.item[1] & "_" & tName.item[2] & "Weapon_" & tName.item[3] & "_WeaponLaunchTube" & i)
    end if
    tNewGroup.transform = p.weapon.transform
    tOffset = tObjects.group("SamSiteTube" & i & "_Dummy").transform.position - tObjects.model("SamSiteWeapon").transform.position
    tNewGroup.transform.position = p.weapon.transform.position + tOffset
    tNewGroup.transform = p.weapon.getWorldTransform().inverse() * tNewGroup.transform
    tNewGroup.parent = p.weapon
    p.LaunchTubes.add(tNewGroup)
  end repeat
  p[#CurrentTube] = 0
  p[#LaunchTimer] = [0, 22]
  p.weapon.transform = p.model.getWorldTransform()
  tOffset = tObjects.model("SamSiteWeapon").transform.position - tObjects.model("SamSite_Object").transform.position
  p.weapon.translate(tOffset, #self)
  p.weapon.transform = p.model.getWorldTransform().inverse() * p.weapon.transform
  p.weapon.parent = p.model
  p[#state] = #inactive
  p[#subState] = #patrolling
  if gGame.Scene = "World" then
    me.InitWorld()
  else
    me.InitTrack()
  end if
  return me
end

on enterFrame me
  if voidp(gGame[#vehicles]) = 1 then
    return 0
  end if
  case p.type of
    #world:
      me.UpdateWorld()
    #track:
      me.UpdateTrack()
  end case
end

on UpdateWorld me
  tState = 0
  if gGame.grid.center[1] = p.Tile then
    tState = 1
  else
    if gGame.grid.innerRing.getPos(p.Tile) <> 0 then
      tState = 1
    else
      if gGame.grid.outerRing.getPos(p.Tile) <> 0 then
        tState = 1
      end if
    end if
  end if
  if tState = 0 then
    if p.state <> #inactive then
      p.state = #inactive
      p.subState = #patrolling
    end if
    return 0
  else
    p.state = #Active
  end if
  t = gGame.vehicles[1]
  tWorldPosition = t.Vehicle.model.worldPosition
  tDistance = p.model.worldPosition.distanceTo(tWorldPosition)
  if p.subState = #patrolling then
    p.weapon.rotate(0, 0, 1 * gGame.TimeMP, #self)
    if (tDistance <= p.AttackRadius) and (gGame.Vehicle = "Helicopter") then
      p.subState = #provoked
    end if
  end if
  if p.subState = #provoked then
    p.weapon.pointAt(tWorldPosition, vector(0, 0, 1))
    p.LaunchTimer[1] = p.LaunchTimer[1] + gGame.TimeMP
    if p.LaunchTimer[1] >= p.LaunchTimer[2] then
      p.LaunchTimer[1] = 0
      p.CurrentTube = p.CurrentTube + 1
      if p.CurrentTube > p.LaunchTubes.count then
        p.CurrentTube = 1
      end if
      tTransform = p.LaunchTubes[p.CurrentTube].getWorldTransform()
      tPart = CreateParticleSystem(0, p.member.name, [#type: #SamLaunch, #NameTag: p.weapon.name])
      tPart.resource.emitter.region = [tTransform.position]
      tScript = new(script("[PS] Sam Rocket"), [#member: p.member, #sender: p.weapon.name, #transform: tTransform])
      if tScript <> VOID then
        gGame.scriptList.add(tScript)
      end if
    end if
    if (tDistance > p.AttackRadius) or (gGame.InShop = 1) then
      p.weapon.transform.rotation = vector()
      p.subState = #patrolling
    end if
  end if
end

on UpdateTrack me
  if p.state = #Active then
    t = gGame.vehicles[1]
    tWorldPosition = t.Vehicle.model.worldPosition
    tDistance = p.model.worldPosition.distanceTo(tWorldPosition)
  else
    tDistance = 999.0
  end if
  if p.subState = #patrolling then
    p.weapon.rotate(0, 0, 1 * gGame.TimeMP, #self)
    if tDistance <= p.AttackRadius then
      p.subState = #provoked
    end if
  end if
  if voidp(gGame[#RaceState]) = 0 then
    if gGame.RaceState = #Finished then
      p.subState = #patrolling
    end if
  end if
  if p.subState = #provoked then
    p.weapon.pointAt(tWorldPosition, vector(0, 0, 1))
    p.LaunchTimer[1] = p.LaunchTimer[1] + gGame.TimeMP
    if p.LaunchTimer[1] = p.LaunchTimer[2] then
      p.LaunchTimer[1] = 0
      p.CurrentTube = p.CurrentTube + 1
      if p.CurrentTube > p.LaunchTubes.count then
        p.CurrentTube = 1
      end if
      tTransform = p.LaunchTubes[p.CurrentTube].getWorldTransform()
      tPart = CreateParticleSystem(0, p.member.name, [#type: #SamLaunch, #NameTag: p.weapon.name])
      tPart.resource.emitter.region = [tTransform.position]
      tScript = new(script("[PS] Sam Rocket"), [#member: p.member, #sender: p.weapon.name, #transform: tTransform])
      if tScript <> VOID then
        gGame.scriptList.add(tScript)
      end if
    end if
    if tDistance > p.AttackRadius then
      p.weapon.transform.rotation = vector()
      p.subState = #patrolling
    end if
    tTargetRoot = t.Vehicle.currentRootNr
    tTargetWaypoint = t.race.waypoint
    if (tTargetRoot = p.ROOT) and ((p.waypoint - tTargetWaypoint) <= 3) then
      p.state = #inactive
      p.weapon.transform.rotation = vector()
      p.subState = #patrolling
    end if
  end if
end

on InitWorld me
  p[#type] = #world
  p[#Tile] = p.model.name.char[1..5]
  p[#AttackRadius] = 150.0
end

on InitTrack me
  p[#type] = #track
  p[#parent] = p.model.userData.parent
  p[#ROOT] = me.GetRoot()
  p[#waypoint] = me.GetWaypoint()
  p[#AttackRadius] = 350.0
  p[#state] = #Active
end

on GetRoot me
  tString = p.parent.name
  the itemDelimiter = "_"
  tString = tString.item[1]
  return value(tString.char[10..tString.length])
end

on GetWaypoint me
  tList = gGame.WayPointList[symbol(p.parent.name)].duplicate()
  tPos = p.model.worldPosition
  tWaypoint = 1
  tDistance = 999.0
  tCount = tList.count
  repeat with i = 1 to tCount
    tNewDistance = p.model.worldPosition.distanceTo(tList[i].position)
    if tNewDistance < tDistance then
      tDistance = tNewDistance
      tWaypoint = i
    end if
  end repeat
  return tWaypoint
end

on OldEnterFrame me
  if gGame.SamSites = 0 then
    return 0
  end if
  if voidp(gGame[#RaceState]) = 1 then
    return 0
  else
    if gGame.RaceState <> #Racing then
      return 0
    end if
  end if
  if voidp(gGame[#vehicles]) = 1 then
    return 0
  end if
  t = gGame.vehicles[1]
  tTargetRoot = t.Vehicle.currentRootNr
  tTargetWaypoint = t.race.waypoint
  tHealth = p.model.userData.Health
  if tHealth <= 0 then
    p.state = #Death
  end if
  if p.state = #sleeping then
    tDistance = p.model.worldPosition.distanceTo(t.Vehicle.model.worldPosition)
    if tDistance <= 500 then
      p.state = #Active
    end if
  else
    if p.state = #Active then
      if (tTargetRoot = p.ROOT) and ((p.waypoint - tTargetWaypoint) <= 3) then
        p.state = #inactive
      end if
      p.FireDelay[1] = p.FireDelay[1] + (1.0 * gGame.TimeMP)
      if p.FireDelay[1] >= p.FireDelay[2] then
        p.FireDelay[1] = 0
        p.FireSeq = p.FireSeq + 1
        if p.FireSeq > 6 then
          p.FireSeq = 1
        end if
        p.group.transform = p.model.getWorldTransform()
        p.group.translate(p.offset[p.FireSeq][1], p.offset[p.FireSeq][2], p.offset[p.FireSeq][3], #self)
        tDistance = p.model.worldPosition.distanceTo(t.Vehicle.model.worldPosition)
        tFrames = integer(tDistance / 5.0)
        if voidp(t.Vehicle[#flySpeed]) = 1 then
          tSpeed = t.Vehicle.Speed / gGame.tempo
        else
          tSpeed = t.Vehicle.flySpeed[1]
        end if
        tFutLoc = t.Vehicle.group.worldPosition + (t.Vehicle.group.transform.yAxis * tSpeed * tFrames)
        p.group.pointAt(tFutLoc, vector(0, 0, 1))
        tScript = new(script("[PS] Sam Rocket"), [#member: p.member, #sender: p.model.name, #transform: p.group.transform.duplicate()])
        if tScript <> VOID then
          gGame.scriptList.add(tScript)
        end if
      end if
    end if
  end if
  if p.state = #Death then
    delete me
  end if
end

on delete me
  p.member.deleteModel(p.weapon.name)
  repeat with i in p.LaunchTubes
    p.member.deleteGroup(i.name)
  end repeat
  p = [:]
  if gSystem.scriptList.getPos(me) <> 0 then
    gSystem.scriptList.deleteOne(me)
  else
    gGame.scriptList.deleteOne(me)
  end if
end
