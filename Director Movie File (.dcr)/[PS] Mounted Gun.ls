-- [Script] [PS] Mounted Gun (Script #5928)
-- Script Type: Parent

property p
global gSystem, gGame, gData

on new me, tDataList
  if voidp(gGame[#MountedGuns]) = 0 then
    if gGame.MountedGuns = 0 then
      return 0
    end if
  end if
  p = [:]
  p[#member] = member(tDataList.member)
  p[#model] = p.member.model(tDataList.model)
  tObjects = member("Objects")
  tName = p.model.name
  tWeaponName = tName.char[1..13] & "weapon" & tName.char[14..tName.length]
  p[#weapon] = p.member.newModel(tWeaponName, p.member.modelResource("MountedGunWeapon"))
  p.weapon.shaderList = p.member.shader("WorldMisc_Material")
  p.weapon.pointAtOrientation = [vector(0.0, 1.0, 0.0), vector(0.0, 0.0, 1.0)]
  p[#Flashes] = []
  p[#Bullets] = []
  repeat with i = 1 to 2
    if i = 1 then
      tFlashName = "MountedGunMuzzleFlashLeft"
    else
      tFlashName = "MountedGunMuzzleFlashRight"
    end if
    tFlash = p.member.newModel(tName.char[1..18] & tFlashName, p.member.modelResource(tFlashName))
    tFlash.transform = p.weapon.transform
    tOffset = tObjects.model(tFlashName).transform.position - tObjects.model("MountedGunWeapon").transform.position
    tFlash.transform.position = p.weapon.transform.position + tOffset
    tFlash.transform = p.weapon.getWorldTransform().inverse() * tFlash.transform
    tFlash.parent = p.weapon
    tFlash.transform.scale = vector(0.0001, 0.0001, 0.0001)
    p.Flashes.add(tFlash)
  end repeat
  p[#FlashScale] = [vector(1, 1, 1), vector(1, 1, 1)]
  p[#BulletScale] = [1, 1]
  p[#rof] = [[0, 7], [0, 7]]
  p[#coolDown] = [[0, 3], [0, 3]]
  p[#damage] = [1, 3]
  p[#CurrentFlash] = 1
  p.weapon.transform = p.model.getWorldTransform()
  tOffset = tObjects.model("MountedGunWeapon").transform.position - tObjects.model("MountedGun_Object").transform.position
  p.weapon.translate(tOffset, #self)
  p.weapon.transform = p.model.getWorldTransform().inverse() * p.weapon.transform
  p.weapon.parent = p.model
  p[#group] = p.member.newGroup(tName.char[1..18] & "Offset")
  p.group.pointAtOrientation = [vector(0.0, 1.0, 0.0), vector(0.0, 0.0, 1.0)]
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
  if (p.subState = #patrolling) and (gGame.InShop = 0) then
    p.weapon.rotate(0, 0, 1 * gGame.TimeMP, #self)
    if (tDistance <= p.AttackRadius) and (gGame.Vehicle = "Car") then
      p.subState = #provoked
    end if
  else
    p.subState = #patrolling
  end if
  if p.subState = #provoked then
    if p.Bullets.count = 0 then
      me.CreateBullets()
    end if
    tTransform = p.weapon.transform.duplicate()
    p.weapon.pointAt(tWorldPosition, vector(0, 0, 1))
    tTransform.interpolateTo(p.weapon.transform, p.AttackSpeed)
    p.weapon.transform = tTransform
    tFlash = p.Flashes[p.CurrentFlash].transform
    p.rof[p.CurrentFlash][1] = p.rof[p.CurrentFlash][1] + gGame.TimeMP
    if p.rof[p.CurrentFlash][1] >= p.rof[p.CurrentFlash][2] then
      p.rof[p.CurrentFlash][1] = 0
      p.coolDown[p.CurrentFlash][1] = p.coolDown[p.CurrentFlash][2]
      p.FlashScale[p.CurrentFlash] = vector(2.5, random(31, 37) * 0.10000000000000001, 2.5)
      tFlash.scale = p.FlashScale[p.CurrentFlash]
      tTransform = p.Flashes[p.CurrentFlash].getWorldTransform()
      p.group.transform = tTransform
      p.group.pointAt(tWorldPosition, vector(0, 0, 1))
      tTransform.interpolateTo(p.group.transform, p.AttackSpeed * 2.0)
      tTransform = p.group.getWorldTransform()
      tDirection = tTransform.yAxis
      p.BulletScale[p.CurrentFlash] = 100
      tDetails = gGame.Physics.rayCastClosest(tTransform.position, tDirection)
      if tDetails.count > 0 then
        p.BulletScale[p.CurrentFlash] = max(0.001, tDetails[4])
        BulletHit(0, p.member.name, [#model: tDetails[1].name, #position: tDetails[2], #normal: tDetails[3], #distance: tDetails[4], #damage: random(p.damage[1], p.damage[2]), #sender: symbol(p.model.name)])
      end if
      tScale = vector(0.20000000000000001, p.BulletScale[p.CurrentFlash], 0.20000000000000001)
      p.Bullets[p.CurrentFlash].transform.scale = tScale
      p.Bullets[p.CurrentFlash].transform.position = tTransform.position + (p.BulletScale[p.CurrentFlash] * tDirection)
      p.Bullets[p.CurrentFlash].transform.rotation = tTransform.rotation
      PlaySound(0, "MachineGunSingleShot_SFX", [#priority: #low, #surround: 1, #member3DName: p.member.name, #sender: p.weapon.name, #targetName: p.weapon.name, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 0])
      p.CurrentFlash = p.CurrentFlash + 1
      if p.CurrentFlash > p.Flashes.count then
        p.CurrentFlash = 1
      end if
    end if
    if (tDistance > p.AttackRadius) or (gGame.InShop = 1) then
      p.weapon.transform.rotation = vector()
      p.subState = #patrolling
    end if
  end if
  repeat with i = 1 to 2
    if p.coolDown[i] > 0.001 then
      p.coolDown[i][1] = max(0.001, p.coolDown[i][1] - gGame.TimeMP)
      tPerc = p.coolDown[i][1] / p.coolDown[i][2]
      if tPerc <= 0.0005 then
        tPerc = 0.0001
      end if
      tFlash = p.Flashes[i].transform
      tFlashScale = p.FlashScale[i] * tPerc
      tFlash.scale = tFlashScale
      tBulletScale = max(0.001, p.BulletScale[i] * tPerc)
      p.Bullets[i].transform.scale.y = tBulletScale
    end if
  end repeat
end

on InitWorld me
  p[#type] = #world
  p[#Tile] = p.model.name.char[1..5]
  p[#AttackRadius] = 85.0
  p[#AttackSpeed] = 25.0
end

on InitTrack me
  p[#type] = #track
end

on CreateBullets me
  repeat with i = 1 to 2
    tName = p.model.name
    tBulletName = tName.char[1..18] & "Bullet"
    tBullet = p.member.newModel(tBulletName & i, p.member.modelResource("Bullet"))
    tBullet.shader = p.member.shader("Effects_Material")
    tBullet.transform.scale = vector(0.0001, 0.0001, 0.0001)
    p.Bullets.add(tBullet)
  end repeat
  repeat with i in p.Flashes
    i.shaderList = p.member.shader("Effects_Material")
  end repeat
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

on delete me
  p.member.deleteModel(p.weapon.name)
  p.member.deleteGroup(p.group.name)
  repeat with i in p.Flashes
    p.member.deleteModel(i.name)
  end repeat
  repeat with i in p.Bullets
    p.member.deleteModel(i.name)
  end repeat
  p = [:]
  if gSystem.scriptList.getPos(me) <> 0 then
    gSystem.scriptList.deleteOne(me)
  else
    gGame.scriptList.deleteOne(me)
  end if
end
