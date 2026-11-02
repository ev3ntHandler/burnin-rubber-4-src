-- [Script] [PS] Explosion DestroyObject (Script #5922)
-- Script Type: Parent

property p
global gSystem, gData, gGame

on new me, tDataList
  p = [:]
  p[#member] = member(tDataList.member)
  p[#model] = p.member.model(tDataList.model)
  p[#dynamic] = 0
  if tDataList.dynamic = 0 then
    p.dynamic = 1
  end if
  tBB = gGame.fx.boundingBox[symbol(p.model.resource.name)]
  tResourceName = p.model.resource.name
  tNewResource = p.member.modelResource(tResourceName.item[1] & "_Destroyed")
  if tNewResource <> VOID then
    p.model.resource = tNewResource
  end if
  p.model.shaderList = gGame.fx.DebrisShader
  tInfluenceDirection = vector(0, 0, 0)
  p[#rb] = #none
  tRB = gGame.Physics.getRigidBody(p.model.name)
  if tRB <> VOID then
    if tRB.type = #dynamic then
      tRandom = random(-70, 70) * 0.01
      tMass = tRB.mass
      tRB.applyLinearImpulse(vector(tRandom * tMass, tRandom * tMass, tMass * 20))
      tRB.applyAngularImpulse(vector(tRandom * (tMass * random(-10, 10)), tRandom * (tMass * random(-10, 10)), tMass))
      p.rb = tRB
      p.dynamic = 1
    else
      p.dynamic = 0
    end if
  end if
  if tDataList.dynamic <> 0 then
    p.dynamic = 0
  end if
  p.dynamic = 0
  areaDamage(0, p.member.name, [#position: p.model.worldPosition, #sender: p.model.name])
  if p.model.boundingSphere[2] <= 2.0 then
    tSize = #Small
  else
    if p.model.boundingSphere[2] <= 5.0 then
      tSize = #medium
    else
      tSize = #large
    end if
  end if
  tPrio = #low
  tDistance = [20, 200]
  if tSize = #medium then
    tDistance = tDistance * 3.0
    tPrio = #medium
  else
    if tSize = #large then
      tDistance = tDistance * 7.0
      tPrio = #high
    end if
  end if
  PlaySound(0, "Explosion" & tSize & "_SFX", [#priority: tPrio, #surround: 1, #member3DName: p.member.name, #sender: p.model.name, #targetName: p.model.name, #referenceName: "Player1_Camera", #distance: tDistance, #static: 1, #Override: 1])
  CameraShake(0, p.member.name, [#type: tSize])
  p[#fire] = []
  p[#smoke] = []
  tDetail = max(2, p.model.boundingSphere[2] * 0.33300000000000002)
  tAmount = [#x: max(2, integer(tBB.width / tDetail)), #y: max(2, integer(tBB.height / tDetail)), #z: max(2, integer(tBB.length / tDetail))]
  tStep = [#x: tBB.width / (tAmount.x + 1), #y: tBB.height / (tAmount.y + 1), #z: tBB.length / (tAmount.z + 1)]
  tNewTransform = transform()
  tNewTransform.position = tBB.center
  tTransform = p.model.getWorldTransform() * tNewTransform
  p[#center] = tTransform.position
  tSpeed = 1.0
  if tDetail = 2 then
    tSpeed = 0.5
  end if
  repeat with i = 1 to tAmount.x
    repeat with j = 1 to tAmount.y
      repeat with k = 1 to tAmount.z
        tLocalPosition = vector(-tBB.width * 0.5, -tBB.height * 0.5, -tBB.length * 0.5)
        tLocalPosition = tLocalPosition + vector(i * tStep.x, j * tStep.y, k * tStep.z)
        tWorldPosition = tTransform * tLocalPosition
        tDirection = tWorldPosition - p.center
        tDirection.normalize()
        tScale = (vector(1.0, 1.0, 1.0) + (vector(1, 1, 1) * (random(0, 20) * 0.10000000000000001))) * (tDetail * 1.0)
        tRotation = [random(-360, 360), random(-15, 15) * 0.10000000000000001]
        tmodel = p.member.newModel(p.model.name & "_ExplosionFire" & i & j & k, p.member.modelResource("PartExplo1"))
        tmodel.shader = p.member.shader("ParticleExplosion1_Material")
        tmodel.transform.position = tWorldPosition
        tmodel.rotate(0, tRotation[1], 0, #self)
        tmodel.transform.scale = tScale * 1.19999999999999996
        if p.dynamic = 0 then
          tSpeedDrag = 0.80000000000000004
        else
          tSpeedDrag = 0.80000000000000004 + (random(0, 20) * 0.01)
        end if
        p.fire.add([#part: tmodel, #life: [random(1, 12), 0], #direction: tDirection, #Speed: tSpeed, #speedDrag: tSpeedDrag, #rotation: tRotation, #growth: 0.12, #growthDrag: 0.90000000000000002, #influence: 1.0, #influenceDrag: 0.90000000000000002, #gravity: vector(0, 0, random(50, 150) * 0.001)])
        tmodel = p.member.newModel(p.model.name & "_ExplosionSmoke" & i & j & k, p.member.modelResource("PartSmoke16"))
        tmodel.shader = p.member.shader("ParticleSmoke1_Material")
        tmodel.transform.position = tWorldPosition - (tDirection * 0.14999999999999999)
        tmodel.rotate(0, tRotation[1], 0, #self)
        tmodel.transform.scale = tScale
        if p.dynamic = 0 then
          tSpeedDrag = 0.75
        else
          tSpeedDrag = 0.75 + (random(0, 30) * 0.01)
        end if
        p.smoke.add([#part: tmodel, #life: [16, 9 + random(1, 20), 0], #direction: tDirection, #Speed: tSpeed, #speedDrag: tSpeedDrag, #rotation: tRotation, #growth: 0.10000000000000001, #growthDrag: 0.94999999999999996, #influence: 1.0, #influenceDrag: 0.90000000000000002, #gravity: vector(0, 0, random(50, 150) * 0.001)])
      end repeat
    end repeat
  end repeat
  return me
end

on enterFrame me
  if p.dynamic = 1 then
    tLinDirection = p.rb.linearVelocity
    tLinDirection.normalize()
  end if
  tRotation = gGame.camera[1].BillboardPoint.transform.rotation
  tCount = p.fire.count
  repeat with j = tCount down to 1
    i = p.fire[j]
    if p.dynamic = 1 then
      tDirection = tLinDirection * i.influence
      i.influence = i.influence * i.influenceDrag
    else
      tDirection = i.direction
    end if
    i.part.transform.position = i.part.transform.position + (tDirection * i.Speed)
    i.Speed = i.Speed * i.speedDrag
    i.part.transform.scale = i.part.transform.scale + i.growth
    i.growth = i.growth * i.growthDrag
    i.part.translate(i.gravity * gGame.TimeMP, #world)
    i.part.transform.rotation = tRotation
    i.rotation[1] = i.rotation[1] + (i.rotation[2] * gGame.TimeMP)
    i.part.rotate(0, i.rotation[1], 0, #self)
    i.life[1] = i.life[1] - gGame.TimeMP
    if i.life[1] <= 0 then
      if i.life[2] = 16 then
        p.member.deleteModel(i.part.name)
        p.fire.deleteAt(j)
        next repeat
      end if
      i.life[2] = min(16, max(1, i.life[2] + (0.5 * gGame.TimeMP)))
      i.part.resource = p.member.modelResource("PartExplo" & integer(i.life[2]))
    end if
  end repeat
  tCount = p.smoke.count
  repeat with j = tCount down to 1
    i = p.smoke[j]
    if p.dynamic = 1 then
      tDirection = tLinDirection * i.influence
      i.influence = i.influence * i.influenceDrag
    else
      tDirection = i.direction
    end if
    i.part.transform.position = i.part.transform.position + (tDirection * i.Speed)
    i.Speed = i.Speed * i.speedDrag
    i.part.transform.scale = i.part.transform.scale + i.growth
    i.growth = i.growth * i.growthDrag
    i.part.translate(i.gravity * gGame.TimeMP, #world)
    i.part.transform.rotation = tRotation
    i.rotation[1] = i.rotation[1] + (i.rotation[2] * gGame.TimeMP)
    i.part.rotate(0, i.rotation[1], 0, #self)
    i.life[1] = max(1.0, i.life[1] - (0.75 * gGame.TimeMP))
    if i.life[1] = 1.0 then
      i.life[2] = i.life[2] - (0.75 * gGame.TimeMP)
      if i.life[2] <= 0 then
        if i.life[3] = 16 then
          p.member.deleteModel(i.part.name)
          p.smoke.deleteAt(j)
        else
          i.life[3] = min(16, max(1, i.life[3] + (0.75 * gGame.TimeMP)))
          i.part.resource = p.member.modelResource("PartExplo" & integer(i.life[3]))
        end if
      end if
      next repeat
    end if
    i.part.resource = p.member.modelResource("PartExplo" & integer(i.life[1]))
  end repeat
  if p.smoke.count = 0 then
    delete me
  end if
end

on delete me
  p = [:]
  if gSystem.scriptList.getPos(me) <> 0 then
    gSystem.scriptList.deleteOne(me)
  else
    gGame.scriptList.deleteOne(me)
  end if
end
