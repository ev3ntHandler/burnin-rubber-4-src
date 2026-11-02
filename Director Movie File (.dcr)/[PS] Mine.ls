-- [Script] [PS] Mine (Script #5879)
-- Script Type: Parent

property p
global gSystem, gGame, gData

on new me, t, tPod
  p = [:]
  p[#member] = t.general.member
  p[#sender] = t.general.tag
  p[#model] = t.Vehicle.model
  p[#data] = gData.data.SecondaryWeapons.mineDeployer
  p[#me] = me
  tDetails = gGame.Physics.rayCastClosest(t.Vehicle.Effects.secondary[1].worldPosition, -t.Vehicle.transform.zAxis)
  if tDetails.count > 0 then
    p[#MineName] = string(p.sender) & "Mine" & _system.milliSeconds
    p[#Mine] = p.member.newModel(p.MineName, p.member.modelResource("Mine"))
    p.Mine.shader = p.member.shader("Weapons_Material")
    p.Mine.pointAtOrientation = [vector(0.0, 0.0, 1.0), vector(0.0, 1.0, 0.0)]
    p.Mine.transform.position = tDetails[2]
    p.Mine.pointAt(tDetails[3] * 100000)
    p[#parent] = p.member.model(tDetails[1].name).parent
    p.Mine.transform = p.parent.getWorldTransform().inverse() * p.Mine.transform
    p.Mine.parent = p.parent
    PlaySound(0, "Mine1_SFX", [#priority: #low, #surround: 1, #member3DName: gGame.member.name, #sender: p.Mine.name, #targetName: p.Mine.name, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 1, #Override: 1])
    p[#timeout] = 25 * gGame.tempo
    return me
  else
    return VOID
  end if
end

on enterFrame me
  if voidp(gGame[#vehicles]) = 1 then
    return
  end if
  repeat with i in gGame.vehicles
    if i.general.tag = p.sender then
      next repeat
    end if
    if i.Vehicle.Proxy.worldPosition.distanceTo(p.Mine.worldPosition) <= p.data.range then
      put "MineDistance" && i.Vehicle.Proxy.name && i.Vehicle.transform.position.distanceTo(p.Mine.worldPosition)
      areaDamage(0, p.member.name, [#position: p.Mine.worldPosition, #areaDamage: p.data.areaDamage, #sender: p.sender, #parent: p.parent])
      tExploScript = new(script("[PS] ExplosionMedium"), [#member: p.member.name, #position: p.Mine.worldPosition, #direction: vector(), #camera: "Player1_Camera", #duration: 1500])
      if tExploScript <> VOID then
        gGame.scriptList.add(tExploScript)
      end if
      PlaySound(0, "MineGrenadeExplosion_SFX", [#priority: #medium, #surround: 1, #member3DName: p.member.name, #sender: p.Mine.name, #targetName: p.Mine.name, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 1, #Override: 1])
      delete me
      exit repeat
    end if
  end repeat
  if (gGame.Scene = "World") and (voidp(gGame[#traffic]) = 0) then
    repeat with j in gGame.traffic.closest
      tmodel = p.member.model(j)
      if tmodel = VOID then
        next repeat
      end if
      if tmodel.worldPosition.distanceTo(p.Mine.worldPosition) <= p.data.range then
        areaDamage(0, p.member.name, [#position: p.Mine.worldPosition, #areaDamage: p.data.areaDamage, #sender: p.sender])
        tExploScript = new(script("[PS] ExplosionMedium"), [#member: p.member.name, #position: p.Mine.worldPosition, #direction: vector(), #camera: "Player1_Camera", #duration: 1500])
        if tExploScript <> VOID then
          gGame.scriptList.add(tExploScript)
        end if
        PlaySound(0, "MineGrenadeExplosion_SFX", [#priority: #medium, #surround: 1, #member3DName: p.member.name, #sender: p.Mine.name, #targetName: p.Mine.name, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 1, #Override: 1])
        delete me
        exit repeat
      end if
    end repeat
  end if
  p.timeout = p.timeout - (1.0 * gGame.TimeMP)
  if p.timeout <= 0 then
    delete me
  end if
end

on delete me
  p.member.deleteModel(p.Mine.name)
  gGame.scriptList.deleteOne(p.me)
end
