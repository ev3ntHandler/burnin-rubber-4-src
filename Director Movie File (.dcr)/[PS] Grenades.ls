-- [Script] [PS] Grenades (Script #5894)
-- Script Type: Parent

property p
global gSystem, gGame, gData

on new me, t
  p = [:]
  p[#member] = t.general.member
  p[#sender] = t.general.tag
  p[#model] = t.Vehicle.model
  p[#data] = gData.data.SecondaryWeapons.GrenadeDeployer
  p[#parent] = t.Vehicle.currentFloor.parent
  p[#me] = me
  p[#Counter] = 0
  p[#Grenades] = 5
  p[#GrenadeList] = []
  p[#SpawnPos] = t.Vehicle.Effects.secondary[1]
  p[#AllSpawned] = 0
  p[#timeout] = 25 * gGame.tempo
  return me
end

on enterFrame me
  p.Counter = p.Counter + gGame.TimeMP
  if (p.Counter >= 2) and (p.Grenades >= 1) then
    p.Counter = 0
    tName = string(p.sender) & "Grenade" & p.Grenades & _system.milliSeconds
    tGrenade = p.member.newModel(tName, p.member.modelResource("Grenade1"))
    tGrenade.shader = p.member.shader("Weapons_Material")
    tGrenade.transform.position = p.SpawnPos.worldPosition
    tGrenade.transform.rotation = randomVector() * 90
    tGrenade.transform = p.parent.getWorldTransform().inverse() * tGrenade.transform
    tGrenade.parent = p.parent
    tGrenade.addModifier(#meshDeform)
    tRB = gGame.Physics.createRigidBody(tName, tName, #convexShape, #dynamic)
    tRB.restitution = 0.75
    tRB.friction = 0.5
    tRB.mass = 20.0
    tGrenade.removeModifier(#meshDeform)
    tVector = vector(random(-50, 50) * 0.01, abs(p.SpawnPos.transform.yAxis), random(-50, 50) * 0.01) * 500
    tRB.applyLinearImpulse(tVector)
    p.GrenadeList.add(tGrenade)
    p.Grenades = p.Grenades - 1
    if p.Grenades = 0 then
      p.AllSpawned = 1
    end if
    tSound = "Grenade" & random(1, 5) & "_SFX"
    PlaySound(0, tSound, [#priority: #low, #surround: 1, #member3DName: gGame.member.name, #sender: tGrenade.name, #targetName: tGrenade.name, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 1, #Override: 1])
  end if
  if p.AllSpawned = 1 then
    if voidp(gGame[#vehicles]) = 1 then
      delete me
      exit
    end if
    tList = p.GrenadeList.duplicate()
    repeat with i in gGame.vehicles
      if i.general.tag = p.sender then
        next repeat
      end if
      repeat with j in tList
        if j = VOID then
          next repeat
        end if
        if i.Vehicle.transform.position.distanceTo(j.worldPosition) <= p.data.range then
          areaDamage(0, p.member.name, [#position: j.worldPosition, #areaDamage: p.data.areaDamage, #sender: p.sender, #parent: p.parent])
          tExploScript = new(script("[PS] ExplosionSmall"), [#member: p.member.name, #position: j.worldPosition, #direction: vector(), #camera: "Player1_Camera", #duration: 1500])
          if tExploScript <> VOID then
            gGame.scriptList.add(tExploScript)
          end if
          PlaySound(0, "MineGrenadeExplosion_SFX", [#priority: #medium, #surround: 1, #member3DName: p.member.name, #sender: j.name, #targetName: j.name, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 1, #Override: 1])
          tName = j.name
          p.GrenadeList.deleteOne(j)
          p.member.deleteModel(tName)
          gGame.Physics.deleteRigidBody(tName)
          if p.GrenadeList.count = 0 then
            delete me
            exit
          end if
        end if
      end repeat
    end repeat
    if (gGame.Scene = "World") and (voidp(gGame[#traffic]) = 0) then
      repeat with k in tList
        repeat with j in gGame.traffic.closest
          if k = VOID then
            next repeat
          end if
          tmodel = p.member.model(j)
          if tmodel = VOID then
            next repeat
          end if
          tUserData = tmodel.userData
          if tUserData.state = #dead then
            next repeat
          end if
          if tmodel.worldPosition.distanceTo(k.worldPosition) <= (p.data.range * 1.5) then
            areaDamage(0, p.member.name, [#position: k.worldPosition, #areaDamage: p.data.areaDamage, #sender: p.sender])
            tExploScript = new(script("[PS] ExplosionSmall"), [#member: p.member.name, #position: k.worldPosition, #direction: vector(), #camera: "Player1_Camera", #duration: 1500])
            if tExploScript <> VOID then
              gGame.scriptList.add(tExploScript)
            end if
            PlaySound(0, "MineGrenadeExplosion_SFX", [#priority: #medium, #surround: 1, #member3DName: p.member.name, #sender: k.name, #targetName: k.name, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 1, #Override: 1])
            tName = k.name
            p.GrenadeList.deleteOne(k)
            p.member.deleteModel(tName)
            gGame.Physics.deleteRigidBody(tName)
            if p.GrenadeList.count = 0 then
              delete me
              exit
            end if
            next repeat
          end if
        end repeat
      end repeat
    end if
  end if
  p.timeout = p.timeout - gGame.TimeMP
  if p.timeout <= 0 then
    delete me
  end if
end

on delete me
  tList = p.GrenadeList.duplicate()
  repeat with i in tList
    tName = i.name
    p.GrenadeList.deleteOne(i)
    p.member.deleteModel(tName)
    if voidp(gGame[#Physics]) = 0 then
      gGame.Physics.deleteRigidBody(tName)
    end if
  end repeat
  gGame.scriptList.deleteOne(p.me)
end
