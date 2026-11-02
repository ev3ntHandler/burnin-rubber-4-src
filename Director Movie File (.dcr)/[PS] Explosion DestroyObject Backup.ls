-- [Script] [PS] Explosion DestroyObject Backup (Script #6164)
-- Script Type: Parent

property p
global gSystem, gData, gGame

on new me, tDataList
  p = [:]
  p[#member] = member(tDataList.member)
  p[#model] = p.member.model(tDataList.model)
  tResourceName = p.model.resource.name
  tNewResource = p.member.modelResource(tResourceName.item[1] & "_Destroyed")
  if tNewResource <> VOID then
    p.model.resource = tNewResource
  end if
  p.model.shaderList = gGame.fx.DebrisShader
  tRB = gGame.Physics.getRigidBody(p.model.name)
  if tRB <> VOID then
    if tRB.type = #dynamic then
      tRandom = random(-70, 70) * 0.01
      tMass = tRB.mass
      tRB.applyLinearImpulse(vector(tRandom * tMass, tRandom * tMass, tMass * 20))
      tRB.applyAngularImpulse(vector(tRandom * (tMass * random(-10, 10)), tRandom * (tMass * random(-10, 10)), tMass))
    end if
  end if
  areaDamage(0, p.member.name, [#position: p.model.worldPosition, #sender: p.model.name, #parent: p.model.name.char[1..6] & "Objects"])
  if p.model.boundingSphere[2] <= 2.0 then
    tSize = #Small
  else
    if p.model.boundingSphere[2] <= 5.0 then
      tSize = #medium
    else
      tSize = #large
    end if
  end if
  PlaySound(0, "Explosion" & tSize & "_SFX", [#priority: #low, #surround: 1, #member3DName: p.member.name, #sender: p.model.name, #targetName: p.model.name, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 1, #Override: 1])
  CameraShake(0, p.member.name, [#type: tSize])
  return me
end

on enterFrame me
  put "Explosion DestroyObject  done and deleted"
  delete me
end

on delete me
  p = [:]
  if gSystem.scriptList.getPos(me) <> 0 then
    gSystem.scriptList.deleteOne(me)
  else
    gGame.scriptList.deleteOne(me)
  end if
end
