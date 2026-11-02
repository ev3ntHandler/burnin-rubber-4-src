-- [Script] [PS] Armored Truck (Script #5890)
-- Script Type: Parent

property p
global gSystem, gGame

on new me, tDataList
  p = [:]
  p[#member] = member(tDataList[#member])
  p[#userData] = tDataList.model.userData
  p[#state] = #patrolling
  p[#subState] = #hold
  p[#modelList] = ["ArmoredTruckAutoCannonStand", "ArmoredTruckAutoCannonGun", "ArmoredTruckAutoCannonMuzzleFlash", "ArmoredTruckSirenLeft", "ArmoredTruckSirenRight"]
  p.modelList = CloneModel(0, p.member, [#sourceMember: "ArmoredTruck", #model: p.modelList, #NameTag: "ArmoredTruck" & p.userData.id, #lod: 0])
  p[#Sirens] = []
  p[#Gun] = #none
  p[#flash] = #none
  p[#model] = p.userData.model
  repeat with i in p.modelList
    i.pointAtOrientation = [vector(0, 1, 0), vector(0, 0, 1)]
    i.parent = p.model
    if i.name contains "Gun" then
      p.Gun = i
    end if
    if i.name contains "Siren" then
      i.parent = VOID
      p.Sirens.add(i)
    end if
    if i.name contains "Flash" then
      tTransform = i.getWorldTransform()
      i.parent = p.member.group("World")
      i.transform = tTransform
      i.transform = p.Gun.getWorldTransform().inverse() * i.transform
      i.parent = p.Gun
      i.transform.scale = vector(0.001, 0.001, 0.001)
      p.flash = i
    end if
  end repeat
  p.Gun.pointAtOrientation = [vector(0, 1, 0), vector(0, 0, 1)]
  p[#SirenAnimation] = [[0, 5], [0, 5]]
  if p.member.texture("ArmoredTruckSiren_Texture") = VOID then
    p.member.shader("ArmoredTruckSiren_Material").texture = createTexture(0, p.member.name, [#texture: "ArmoredTruckSiren_Texture"])
    BlendShader(0, p.member.name, [#shader: "ArmoredTruckSiren_Material", #blendMode: #add])
  end if
  p[#FlashScale] = vector(1, 1, 1)
  p[#Bullet] = CloneModel(0, p.member.name, [#sourceMember: "Weapons", #model: ["Bullet"], #NameTag: "Traffic" & p.userData.id & "ArmoredTruck", #hide: 0, #lod: 0])
  p.Bullet.transform.scale = vector(0.0001, 0.0001, 0.0001)
  p[#BulletScale] = 1
  p[#rof] = [0, 4]
  p[#coolDown] = [0, 3]
  p[#AttackRadius] = 60.0
  p[#AttackSpeed] = 30.0
  p[#damage] = [2, 3]
  return me
end

on enterFrame me
  if p.model.parent = VOID then
    return 0
  end if
  if voidp(gGame[#vehicles]) = 1 then
    return 0
  end if
  t = gGame.vehicles[1]
  if t.race.state = #dead then
    if p.state = #provoked then
      p.userData.originalHealth = p.userData.Health
      p.Sirens[1].parent = VOID
      p.Sirens[2].parent = VOID
      p[#SirenAnimation] = [[0, 5], [0, 5]]
    end if
    p.state = #patrolling
    if p.subState <> #hold then
      p.subState = #return
    end if
  end if
  tDistance = p.model.worldPosition.distanceTo(t.Vehicle.model.worldPosition)
  tFlash = p.flash.transform
  if p.state = #patrolling then
    if p.userData.collision = 1 then
      p.state = #provoked
    end if
    if p.userData.Health < p.userData.originalHealth then
      p.state = #provoked
    else
      if tDistance <= p.AttackRadius then
        if (t.Input.action1 = 1) and (t.Weapons[2].ammo[1] > 0) then
          p.state = #provoked
        else
          if (t.Input.action2 = 1) and (t.Weapons[3].ammo[1] > 0) then
            if t.Weapons.getPropAt(3) <> #NitroBoost then
              p.state = #provoked
            end if
          end if
        end if
      end if
    end if
  end if
  if p.state = #provoked then
    if tDistance <= p.AttackRadius then
      p.subState = #firing
    else
      if p.subState = #firing then
        p.subState = #return
      end if
    end if
    if gGame.InShop = 1 then
      p.subState = #return
    end if
    if p.subState = #firing then
      tTransform = p.Gun.transform.duplicate()
      p.Gun.pointAt(gGame.vehicles[1].Vehicle.model.worldPosition, vector(0, 0, 1))
      tTransform.interpolateTo(p.Gun.transform, p.AttackSpeed)
      p.Gun.transform = tTransform
      p.rof[1] = p.rof[1] + gGame.TimeMP
      if p.rof[1] >= p.rof[2] then
        p.rof[1] = 0
        p.coolDown[1] = p.coolDown[2]
        p.FlashScale = vector(2.5, random(31, 37) * 0.10000000000000001, 2.5)
        tFlash.scale = p.FlashScale
        tTransform = p.flash.getWorldTransform()
        tDirection = tTransform.yAxis
        p.BulletScale = 100
        tDetails = gGame.Physics.rayCastClosest(tTransform.position, tDirection)
        if tDetails.count > 0 then
          p.BulletScale = max(0.001, tDetails[4])
          if tDetails[1].name <> p.model.name then
            BulletHit(0, p.member.name, [#model: tDetails[1].name, #position: tDetails[2], #normal: tDetails[3], #distance: tDetails[4], #damage: random(p.damage[1], p.damage[2]), #sender: p.model.name])
          end if
        end if
        tScale = vector(0.20000000000000001, p.BulletScale, 0.20000000000000001)
        p.Bullet.transform.scale = tScale
        p.Bullet.transform.position = tTransform.position + (p.BulletScale * tDirection)
        p.Bullet.transform.rotation = tTransform.rotation
        PlaySound(0, "MachineGunSingleShot_SFX", [#priority: #low, #surround: 1, #member3DName: p.member.name, #sender: p.model.name, #targetName: p.model.name, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 0])
      end if
    end if
    p.SirenAnimation[1][1] = max(0, p.SirenAnimation[1][1] - gGame.TimeMP)
    p.SirenAnimation[2][1] = min(p.SirenAnimation[2][2], p.SirenAnimation[2][1] + gGame.TimeMP)
    if p.SirenAnimation[1][1] = 0 then
      p.SirenAnimation[1][1] = p.SirenAnimation[1][2]
      if p.Sirens[1].isInWorld() = 1 then
        p.Sirens[1].parent = VOID
      else
        p.Sirens[1].parent = p.model
      end if
      if tDistance >= (gGame.camera[1].camera.fog.near - 10.0) then
        p.Sirens[1].parent = VOID
      end if
    end if
    if p.SirenAnimation[2][1] = p.SirenAnimation[2][2] then
      p.SirenAnimation[2][1] = 0
      if p.Sirens[2].isInWorld() = 1 then
        p.Sirens[2].parent = VOID
      else
        p.Sirens[2].parent = p.model
      end if
      if tDistance >= (gGame.camera[1].camera.fog.near - 10.0) then
        p.Sirens[2].parent = VOID
      end if
    end if
    tZAxis = gGame.camera[1].camera.getWorldTransform().zAxis
    tPos = p.Sirens[1].worldPosition - tZAxis
    p.Sirens[1].pointAt(tPos, vector(0, 0, 1))
    tPos = p.Sirens[2].worldPosition - tZAxis
    p.Sirens[2].pointAt(tPos, vector(0, 0, 1))
  end if
  if p.subState = #return then
    tTransform = p.Gun.transform.duplicate()
    p.Gun.transform.rotation = vector()
    tTransform.interpolateTo(p.Gun.transform, p.AttackSpeed)
    p.Gun.transform = tTransform
    if (abs(p.Gun.transform.rotation.x) < 0.01) and (abs(p.Gun.transform.rotation.y) < 0.01) and (abs(p.Gun.transform.rotation.z) < 0.01) then
      p.subState = #hold
    end if
  end if
  if p.coolDown > 0.001 then
    p.coolDown[1] = max(0.001, p.coolDown[1] - gGame.TimeMP)
    tPerc = p.coolDown[1] / p.coolDown[2]
    tFlashScale = p.FlashScale * tPerc
    tFlash.scale = tFlashScale
    tBulletScale = max(0.001, p.BulletScale * tPerc)
    p.Bullet.transform.scale.y = tBulletScale
  end if
end

on delete me
  repeat with i in p.modelList
    p.member.deleteModel(i.name)
  end repeat
  p.member.deleteModel(p.Bullet.name)
  p = [:]
  if gSystem.scriptList.getPos(me) <> 0 then
    gSystem.scriptList.deleteOne(me)
  else
    gGame.scriptList.deleteOne(me)
  end if
end
