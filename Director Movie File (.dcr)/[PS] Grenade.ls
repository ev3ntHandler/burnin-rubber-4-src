-- [Script] [PS] Grenade (Script #5895)
-- Script Type: Parent

property p
global gSystem, gGame, gData

on new me, t, tPod
  p = [:]
  p[#member] = t.general.member
  p[#sender] = t.general.tag
  p[#model] = t.Vehicle.model
  p[#data] = gData.data.SecondaryWeapons.GrenadeLauncher
  p[#me] = me
  tName = string(p.sender) & "Grenade" & _system.milliSeconds
  p[#GrenadeName] = tName
  p[#Grenade] = p.member.newModel(tName, p.member.modelResource("Grenade"))
  p.Grenade.shader = p.member.shader("Weapons_Material")
  p.Grenade.pointAtOrientation = [vector(0.0, 0.0, 1.0), vector(0.0, 1.0, 0.0)]
  p.Grenade.transform = t.Vehicle.Effects.secondary[1].getWorldTransform()
  p.Grenade.transform.scale = vector(1, 1, 1) * 1
  p.Grenade.addModifier(#meshDeform)
  p[#rb] = gGame.Physics.createRigidBody(tName, tName, #sphere, #dynamic)
  p.rb.restitution = 0.90000000000000002
  p.rb.friction = 0.5
  p.rb.mass = 20.0
  p.Grenade.removeModifier(#meshDeform)
  p.rb.linearVelocity = p.Grenade.transform.yAxis * 100
  p.rb.angularVelocity = vector()
  p[#SmokeModel] = CreateParticleSystem(0, p.member.name, [#type: #GrenadeSmoke, #NameTag: tName])
  p[#SmokeResource] = p.SmokeModel.resource
  tSound = "GrenadeLauncher" & random(1, 3) & "_SFX"
  PlaySound(0, tSound, [#priority: #low, #surround: 1, #member3DName: gGame.member.name, #sender: t.Vehicle.Proxy.name, #targetName: t.Vehicle.Proxy.name, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 0, #Override: 1])
  p[#timeout] = 2 * gGame.tempo
  return me
end

on enterFrame me
  if voidp(gGame[#vehicles]) = 0 then
    repeat with i in gGame.vehicles
      if i.general.tag = p.sender then
        next repeat
      end if
      if i.Vehicle.transform.position.distanceTo(p.Grenade.worldPosition) <= 4.0 then
        if string(p.sender) contains "player" then
          UPdateSWTrophyExplosion()
        end if
        tExploScript = new(script("[PS] ExplosionSmall"), [#member: p.member.name, #position: p.Grenade.worldPosition, #camera: "Player1_Camera", #duration: 2500])
        if tExploScript <> VOID then
          gGame.scriptList.add(tExploScript)
        end if
        PlaySound(0, "GrenadeExplosion_SFX", [#priority: #medium, #surround: 1, #member3DName: p.member.name, #sender: p.Grenade.name, #targetName: p.Grenade.name, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 1, #Override: 1])
        areaDamage(0, p.member.name, [#position: p.Grenade.worldPosition, #areaDamage: p.data.areaDamage, #sender: p.sender, #parent: VOID])
        delete me
        exit
      end if
    end repeat
  end if
  if (gGame.Scene = "World") and (voidp(gGame[#traffic]) = 0) then
    repeat with j in gGame.traffic.closest
      tmodel = p.member.model(j)
      if tmodel = VOID then
        next repeat
      end if
      if tmodel.worldPosition.distanceTo(p.Grenade.worldPosition) <= 4.0 then
        if string(p.sender) contains "player" then
          UPdateSWTrophyExplosion()
        end if
        tExploScript = new(script("[PS] ExplosionSmall"), [#member: p.member.name, #position: p.Grenade.worldPosition, #camera: "Player1_Camera", #duration: 2500])
        if tExploScript <> VOID then
          gGame.scriptList.add(tExploScript)
        end if
        PlaySound(0, "GrenadeExplosion_SFX", [#priority: #medium, #surround: 1, #member3DName: p.member.name, #sender: p.Grenade.name, #targetName: p.Grenade.name, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 1, #Override: 1])
        areaDamage(0, p.member.name, [#position: p.Grenade.worldPosition, #areaDamage: p.data.areaDamage, #sender: p.sender])
        delete me
        exit
      end if
    end repeat
  end if
  if p.Grenade <> VOID then
    pRegion = p.Grenade.getWorldTransform().position - (p.Grenade.transform.yAxis * 0.10000000000000001)
    p.SmokeResource.emitter.region = [pRegion]
  end if
  p.timeout = p.timeout - (1.0 * gGame.TimeMP)
  if p.timeout <= 0 then
    if string(p.sender) contains "player" then
      UPdateSWTrophyExplosion()
    end if
    tExploScript = new(script("[PS] ExplosionSmall"), [#member: p.member.name, #position: p.Grenade.worldPosition, #camera: "Player1_Camera", #duration: 2500])
    if tExploScript <> VOID then
      gGame.scriptList.add(tExploScript)
    end if
    PlaySound(0, "GrenadeExplosion_SFX", [#priority: #medium, #surround: 1, #member3DName: p.member.name, #sender: p.Grenade.name, #targetName: p.Grenade.name, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 1, #Override: 1])
    areaDamage(0, p.member.name, [#position: p.Grenade.worldPosition, #areaDamage: p.data.areaDamage, #sender: p.sender, #parent: VOID])
    delete me
  end if
end

on delete me
  p.member.deleteModel(p.SmokeModel.name)
  p.member.deleteModelResource(p.SmokeResource.name)
  p.SmokeResource = VOID
  p.deleteProp(#SmokeModel)
  tName = p.Grenade.name
  p.member.deleteModel(tName)
  if voidp(gGame[#Physics]) = 0 then
    gGame.Physics.deleteRigidBody(tName)
  end if
  gGame.scriptList.deleteOne(p.me)
end
