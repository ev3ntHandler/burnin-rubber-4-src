-- [Script] [M] Effect Manager (Script #6157)
-- Script Type: Movie

global gData, gGame

on SetObjectData me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    return 0
  end if
  if gGame.Physics = VOID then
    return 0
  end if
  tTargetList = []
  if tDataList[#model].ilk = #void then
    tDataList[#model] = "*.*"
  end if
  if tDataList[#model].ilk = #list then
    tTargetList = tDataList.model
  else
    if tDataList[#model].ilk = #string then
      if tDataList.model.char[1] = "*" then
        tString = tDataList.model
        if tString <> "*.*" then
          delete tString.char[1]
        end if
        tTargetList = GetObjectList(0, tmember.name, [#type: #model, #string: tString])
      else
        tTargetList.add(tDataList.model)
      end if
    end if
  end if
  if tTargetList.count = 0 then
    return []
  end if
  the itemDelimiter = "_"
  repeat with i in tTargetList
    if i contains "_" then
      tName = i.item[1]
    else
      tName = i
    end if
    repeat with j = 1 to 3
      if value(tName.char[tName.length]).ilk = #integer then
        tName = tName.char[1..tName.length - 1]
      end if
    end repeat
    tmodel = tmember.model(i)
    if voidp(gGame.fx.boundingBox[symbol(tName)]) = 1 then
      tBB = GetBoundingBox(0, tmember.name, [#model: tmodel.name])
    else
      tBB = gGame.fx.boundingBox[symbol(tName)]
    end if
    tObjectData = [#mass: #static, #type: #default, #Health: #infinite, #score: 0, #script: #none, #sound: #none, #dieOnCollision: 0, #onDeath: #none]
    if voidp(gData.data.objects[symbol(tName)]) = 0 then
      repeat with l = 1 to gData.data.objects[symbol(tName)].count
        tProp = gData.data.objects[symbol(tName)].getPropAt(l)
        tObjectData[tProp] = gData.data.objects[symbol(tName)][l]
      end repeat
    else
      return 0
    end if
    tmodel.userData.addProp(#resource, tmodel.resource.name)
    tmodel.userData.addProp(#transform, tmodel.getWorldTransform().duplicate())
    tmodel.userData.addProp(#LocalTransform, tmodel.transform.duplicate())
    tmodel.userData.addProp(#parent, tmodel.parent)
    tmodel.userData.addProp(#boundingBox, tBB)
    tmodel.userData.addProp(#collision, 0)
    tCount = tObjectData.count
    repeat with k = 1 to tCount
      tProp = tObjectData.getPropAt(k)
      tmodel.userData.addProp(tProp, tObjectData[tProp])
      case tProp of
        #Health:
          if tObjectData[#Health] <> #infinite then
            gGame.fx.Destruction.add(tmodel.name)
          end if
        #sound:
          if tObjectData[#sound] <> #none then
            put "[ALERT]" & TAB & "NO SOUND FUNCTION IMPLEMENTED YET!"
          end if
        #script:
          if tObjectData[#script] <> #none then
            tScript = AddScript(0, EMPTY, [#script: tObjectData[#script], #data: [#member: tmember.name, #model: tmodel.name]])
          end if
          tmodel.userData.script = tScript
      end case
    end repeat
  end repeat
end

on GetBoundingBox me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    return 0
  end if
  if tDataList[#model].ilk = #string then
    tmodel = tmember.model(tDataList.model)
  else
    return 0
  end if
  if tmodel = VOID then
    return 0
  end if
  tModList = tmodel.modifier
  if tModList.getPos(#meshDeform) = 0 then
    tmodel.addModifier(#meshDeform)
  end if
  tRB = gGame.Physics.createRigidBody(tmodel.name, tmodel.name, #box, #static)
  tProperties = tRB.properties.duplicate()
  gGame.fx.boundingBox[symbol(tmodel.resource.name)] = tProperties
  gGame.Physics.deleteRigidBody(tRB)
  return tProperties
end

on BuildBoundingBox me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    return 0
  end if
  if tDataList[#model].ilk = #string then
    tmodel = tmember.model(tDataList.model)
  else
    return 0
  end if
  if tmodel = VOID then
    return 0
  end if
  if voidp(gGame.fx.boundingBox[symbol(tmodel.resource.name)]) = 0 then
    tProperties = gGame.fx.boundingBox[symbol(tmodel.resource.name)]
  else
    return 0
  end if
  tResource = tmember.newModelResource(tmodel.name & "_BoundingBox", #box)
  tResource.height = tProperties.height
  tResource.width = tProperties.width
  tResource.length = tProperties.length
  tBox = tmember.newModel(tmodel.name & "_BoundingBox", tResource)
  tBox.transform = tmodel.getWorldTransform()
  tBox.transform.position = tBox.transform.position + (tBox.transform * tProperties.center)
  tBox.shaderList = gGame.fx.WireframeShader
end

on BulletHit me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    return 0
  end if
  tName = tDataList.model
  tFX = 1
  if tDataList[#fx].ilk = #integer then
    tFX = tDataList.fx
  end if
  if gGame.Effects = #low then
    tFX = 0
  end if
  if tName contains "Proxy" then
    tName = tName.char[1..tName.length - 5]
    gGame.vehicles[symbol(tName)].Vehicle.impacts.add([tDataList.damage, #Bullet, tDataList.sender])
    PlaySound(0, "HitMetal" & random(1, 4) & "_SFX", [#priority: #low, #surround: 1, #member3DName: tmember.name, #sender: tName, #targetName: tName, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 1])
    if random(1, 3) = 1 then
      PlaySound(0, "HitGlass" & random(1, 3) & "_SFX", [#priority: #low, #surround: 1, #member3DName: tmember.name, #sender: tName, #targetName: tName, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 1])
    end if
    if tFX = 1 then
      CreateImpact(0, tmember.name, [#type: #metal, #model: tName, #position: tDataList.position, #normal: tDataList.normal])
    end if
  else
    tmodel = tmember.model(tDataList.model)
    tUserData = tmodel.userData
    if gGame.fx.Destruction.getPos(tmodel.name) <> 0 then
      case tUserData.type of
        #metal:
          tSound = "HitMetal" & random(1, 4) & "_SFX"
        #concrete:
          tSound = "HitConcrete" & random(1, 2) & "_SFX"
        #wood:
          tSound = "HitWood" & random(1, 3) & "_SFX"
        #plastic:
          tSound = "HitPlastic" & random(1, 3) & "_SFX"
        otherwise:
          tSound = "HitDefault" & random(1, 6) & "_SFX"
      end case
      PlaySound(0, tSound, [#priority: #low, #surround: 1, #member3DName: tmember.name, #sender: tName, #targetName: tName, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 1])
      tUserData.Health = tUserData.Health - tDataList.damage
      if tUserData.Health <= 0 then
        if tUserData.onDeath <> #none then
          DestroyObject(0, tmember.name, [#model: tmodel.name, #sender: tDataList.sender])
        end if
      else
        if tFX = 1 then
          if gGame.Effects = #high then
            CreateDecal(0, tmember.name, [#type: tUserData.type, #model: tDataList.model, #position: tDataList.position, #normal: tDataList.normal])
          end if
          if gGame.Effects <> #low then
            CreateImpact(0, tmember.name, [#type: tUserData.type, #model: tDataList.model, #position: tDataList.position, #normal: tDataList.normal])
          end if
        end if
      end if
    else
      PlaySound(0, "HitDefault" & random(1, 6) & "_SFX", [#priority: #low, #surround: 1, #member3DName: tmember.name, #sender: tName, #targetName: tName, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 1])
      if getaProp(tUserData, #type) <> VOID then
        tType = tUserData.type
      else
        tType = #default
      end if
      if tFX = 1 then
        if gGame.Effects = #high then
          CreateDecal(0, tmember.name, [#type: tType, #model: tDataList.model, #position: tDataList.position, #normal: tDataList.normal])
        end if
        if gGame.Effects <> #low then
          CreateImpact(0, tmember.name, [#type: tType, #model: tDataList.model, #position: tDataList.position, #normal: tDataList.normal])
        end if
      end if
    end if
  end if
end

on CreateDecal me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    return 0
  end if
  tType = #default
  if tDataList[#type].ilk = #symbol then
    tType = tDataList.type
  end if
  tParent = tmember.group("World")
  if tDataList[#model].ilk = #string then
    tParent = tmember.model(tDataList.model)
  end if
  if getaProp(tParent.userData, #Health) <> VOID then
    if tParent.userData.Health <= 0 then
      return 0
    end if
  end if
  tPosition = vector()
  if tDataList[#position].ilk = #vector then
    tPosition = tDataList.position
  end if
  tNormal = vector(0, 0, 1)
  if tDataList[#normal].ilk = #vector then
    tNormal = tDataList.normal
  end if
  tRandom = random(1, gGame.fx.Decals[tType])
  tDecal = tmember.newModel("Decal" & tType & tRandom & "_" & (gGame.fx.Decals.amount + 1), tmember.modelResource("Decal" & tType & tRandom))
  if tDecal <> VOID then
    gGame.fx.Decals.amount = gGame.fx.Decals.amount + 1
    tDecal.shader = tmember.shader("Decals_Material")
    tPosition = tPosition + (tNormal * (0.05 * gGame.worldscale))
    tDecal.transform.position = tPosition
    tDecal.pointAt(tPosition - tNormal)
    tDecal.rotate(0, 0, random(360), #self)
    tDecal.transform = tParent.getWorldTransform().inverse() * tDecal.transform
    tDecal.parent = tParent
    if tType = #explosion then
      if (tDataList[#scale].ilk = #float) or (tDataList[#scale].ilk = #integer) then
        tDecal.transform.scale = vector(1, 1, 1) * tDataList.scale
      end if
    end if
    gGame.fx.Decals.list.add(tDecal)
    if gGame.fx.Decals.list.count > gGame.fx.Decals.maximum then
      tmember.deleteModel(gGame.fx.Decals.list[1].name)
      gGame.fx.Decals.list.deleteAt(1)
    end if
  end if
end

on CreateImpact me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    return 0
  end if
  tType = #default
  if tDataList[#type].ilk = #symbol then
    tType = tDataList.type
  end if
  tParent = tmember.group("World")
  if tDataList[#model].ilk = #string then
    tParent = tmember.model(tDataList.model)
  end if
  if getaProp(tParent.userData, #Health) <> VOID then
    if tParent.userData.Health <= 0 then
      return 0
    end if
  end if
  tNormal = vector(0, 0, 1)
  if tDataList[#normal].ilk = #vector then
    tNormal = tDataList.normal
  end if
  tPosition = vector()
  if tDataList[#position].ilk = #vector then
    tPosition = tDataList.position
  end if
  tPosition = tPosition + (tNormal * (0.05 * gGame.worldscale))
  tRandom = random(1, gGame.fx.impacts[tType])
  gGame.fx.impacts.amount = gGame.fx.impacts.amount + 1
  tAmount = gGame.fx.impacts.amount
  if gGame.Effects = #high then
    tBurst = tmember.newModel("ImpactBurst" & tType & tRandom & "_" & tAmount, tmember.modelResource("ImpactBurst" & tType & tRandom))
    tBurst.shader = tmember.shader("ImpactBurst_Material")
    tBurst.transform.position = tPosition
    tBurst.pointAt(tPosition - tNormal)
    tBurst.rotate(0, 0, random(360), #self)
    tBurst.rotate(random(-10, 10), 0, 0, #self)
    tBurst.transform = tParent.getWorldTransform().inverse() * tBurst.transform
    tBurst.parent = tParent
    tBurst.transform.scale = tBurst.transform.scale * (random(18, 28) * 0.10000000000000001) * gGame.worldscale
    gGame.fx.impacts.list.burst.add(tBurst)
    if gGame.fx.impacts.list.burst.count > gGame.fx.impacts.maximum then
      tmember.deleteModel(gGame.fx.impacts.list.burst[1].name)
      gGame.fx.impacts.list.burst.deleteAt(1)
    end if
    tSmoke = tmember.newModel("ImpactSmoke" & tType & tRandom & "_" & tAmount, tmember.modelResource("ImpactSmoke" & tType & tRandom))
    tSmoke.shader = tmember.shader("ImpactSmoke_Material")
    tSmoke.transform.position = tPosition + (tNormal * (0.14999999999999999 * gGame.worldscale))
    tSmoke.pointAt(tPosition - tNormal)
    tSmoke.transform.scale = tSmoke.transform.scale * (random(28, 46) * 0.10000000000000001) * gGame.worldscale
    tRandomRotation = random(360)
    tSmoke.rotate(0, tRandomRotation, 0, #self)
    gGame.fx.impacts.list.smoke.add([tSmoke, tRandomRotation])
    if gGame.fx.impacts.list.smoke.count > gGame.fx.impacts.maximum then
      tmember.deleteModel(gGame.fx.impacts.list.smoke[1][1].name)
      gGame.fx.impacts.list.smoke.deleteAt(1)
    end if
  end if
  tSparks = tmember.newModel("ImpactSparks" & tType & tRandom & "_" & tAmount, tmember.modelResource("ImpactSparks" & tType & tRandom))
  tSparks.shader = tmember.shader("ImpactSparks_Material")
  tSparks.transform.position = tPosition
  tSparks.pointAt(tPosition - tNormal)
  tSparks.rotate(0, 0, random(360), #self)
  tSparks.transform = tParent.getWorldTransform().inverse() * tSparks.transform
  tSparks.parent = tParent
  tSparks.transform.scale = tSparks.transform.scale * (random(25, 35) * 0.10000000000000001) * gGame.worldscale
  gGame.fx.impacts.list.sparks.add(tSparks)
  if gGame.fx.impacts.list.sparks.count > gGame.fx.impacts.maximum then
    tmember.deleteModel(gGame.fx.impacts.list.sparks[1].name)
    gGame.fx.impacts.list.sparks.deleteAt(1)
  end if
end

on DestroyObject me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    return 0
  end if
  tmodel = tmember.model(tDataList.model)
  if tmodel = VOID then
    return 0
  end if
  tSender = #none
  if tDataList[#sender].ilk <> #void then
    tSender = tDataList.sender
  end if
  gGame[#objectDestroyed] = tmodel.name
  gGame.fx.Destruction.deleteOne(tmodel.name)
  if gGame.fx.CollisionDamage.getPos(tmodel.name) then
    gGame.fx.CollisionDamage.deleteOne(tmodel.name)
  end if
  the itemDelimiter = "_"
  tUserData = tmodel.userData
  if voidp(tUserData[#script]) = 0 then
    if tUserData[#script].ilk = #instance then
      delete tUserData.script
      tUserData.script = #none
    end if
  end if
  tOnDeathData = [#Particles: [], #SpecialParticles: [], #effect: [], #script: [], #handler: [], #event: [], #sound: []]
  tOnDeath = tUserData.onDeath
  if tOnDeath.ilk = #propList then
    tList = tOnDeath.duplicate()
  else
    if voidp(gData.data.ObjectsEffects[tOnDeath]) = 0 then
      tList = gData.data.ObjectsEffects[tOnDeath]
    else
      return 0
    end if
  end if
  tCount = tList.count
  repeat with i = 1 to tCount
    tProp = tList.getPropAt(i)
    if tList[i].ilk <> #list then
      tOnDeathData[tProp].add(tList[i])
      next repeat
    end if
    if tList[i].ilk = #list then
      repeat with j in tList[i]
        tOnDeathData[tProp].add(j)
      end repeat
    end if
  end repeat
  repeat with i in tOnDeathData.Particles
    tParticle = CreateParticleSystem(0, tmember.name, [#type: i])
    tParticle.resource.emitter.region = [tmodel.worldPosition]
  end repeat
  repeat with i in tOnDeathData.SpecialParticles
    AddScript(0, EMPTY, [#script: "[PS] Particles", #data: [#member: tmember.name, #model: tmodel.name, #type: i]])
  end repeat
  repeat with i in tOnDeathData.sound
    PlaySound(0, i, [#priority: #low, #surround: 1, #member3DName: tmember.name, #sender: tmodel.name, #targetName: tmodel.name, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 1, #Override: 1])
  end repeat
  repeat with i in tOnDeathData.effect
    case i of
      #destroyed:
        tResourceName = tmodel.resource.name
        tNewResource = tmember.modelResource(tResourceName.item[1] & "_Destroyed")
        if tNewResource <> VOID then
          tmodel.resource = tNewResource
        end if
      #destroyedSpecial:
        tResourceName = tmodel.resource.name
        tNewResource = tmember.modelResource(tResourceName.item[1] & "_Destroyed")
        if tNewResource <> VOID then
          tmodel.resource = tNewResource
        end if
        tRB = gGame.Physics.getRigidBody(tmodel.name)
        if tRB <> VOID then
          tMass = tRB.mass
          gGame.Physics.deleteRigidBody(tmodel.name)
          tmodel.addModifier(#meshDeform)
          AddObstacle(0, tmember.name, [#model: tmodel.name, #type: #dynamic, #bodyProxy: #convexShape, #restitution: 0.90000000000000002, #friction: 0.90000000000000002, #mass: tMass])
          tmodel.removeModifier(#meshDeform)
        end if
      #DebrisShader:
        tmodel.shaderList = gGame.fx.DebrisShader
      #Debris:
        AddScript(0, EMPTY, [#script: "[PS] Debris", #data: [#member: tmember.name, #model: tmodel.name]])
      #debrisTrails:
        AddScript(0, EMPTY, [#script: "[PS] DebrisTrails", #data: [#member: tmember.name, #model: tmodel.name]])
      #sparks:
        AddScript(0, EMPTY, [#script: "[PS] Sparks", #data: [#member: tmember.name, #model: tmodel.name]])
      #Blast:
        AddScript(0, EMPTY, [#script: "[PS] Blast", #data: [#member: tmember.name, #model: tmodel.name]])
      #Shockwave:
        AddScript(0, EMPTY, [#script: "[PS] Shockwave", #data: [#member: tmember.name, #model: tmodel.name]])
      #explosion:
        AddScript(0, EMPTY, [#script: "[PS] Explosion DestroyObject", #data: [#member: tmember.name, #model: tmodel.name, #dynamic: tOnDeathData.effect.getPos(#delete)]])
    end case
  end repeat
  repeat with i in tOnDeathData.handler
    sendSprite(0, i, tmember.name, [#model: tmodel.name])
  end repeat
  repeat with i in tOnDeathData.event
    event(0, i)
  end repeat
  tDecals = []
  repeat with i = 1 to tmodel.child.count
    if gGame.fx.Decals.list.getPos(tmodel.child[i]) <> 0 then
      tDecals.add(tmodel.child[i])
    end if
  end repeat
  repeat with i in tDecals
    gGame.fx.Decals.list.deleteOne(i)
    tmember.deleteModel(i.name)
  end repeat
  if tOnDeathData.effect.getPos(#delete) <> 0 then
    tParent = tmodel.parent
    tUserData = tParent.userData
    tRB = gGame.Physics.getRigidBody(tmodel.name)
    if tRB <> VOID then
      if tUserData.count > 0 then
        tUserData.rigidBodies.deleteOne(tRB)
      end if
      gGame.Physics.deleteRigidBody(tmodel.name)
    end if
    if tUserData.count > 0 then
      tUserData.objects.deleteOne(tmodel)
    end if
    tmember.deleteModel(tmodel.name)
  end if
  gGame.deleteProp(#objectDestroyed)
end

on CollisionDamage me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    return 0
  end if
  tmodel = tmember.model(tDataList.model)
  if tmodel = VOID then
    return 0
  end if
  tModelName = tmodel.name
  tSender = #none
  if tDataList[#sender].ilk <> #void then
    tSender = tDataList.sender
  end if
  if tDataList[#details].ilk <> #void then
    tDetails = tDataList.details
  else
    return 0
  end if
  tRB = gGame.Physics.getRigidBody(tDetails[1])
  tV = abs(tRB.linearVelocity.dot(tDetails[3]))
  tA = tV * 0.33329999999999999
  tForce = tRB.mass * tA
  tDamage = tForce * 0.0002
  if tModelName contains "Proxy" then
    gGame.vehicles[symbol(tModelName.char[1..tModelName.length - 5])].Vehicle.impacts.add([tDamage, #ImpactDamage, tSender])
  else
    if gGame.fx.Destruction.getPos(tModelName) <> 0 then
      tUserData = tmodel.userData
      tUserData.Health = tUserData.Health - tDamage
      if tUserData.Health <= 0 then
        DestroyObject(0, tmember.name, [#model: tModelName, #sender: tSender])
      end if
    end if
  end if
  if tDamage >= 0.20000000000000001 then
    PlaySound(0, "Bump_SFX", [#priority: #low, #rateShift: random(-6, 8), #surround: 1, #member3DName: tmember.name, #sender: tmodel.name, #targetName: tmodel.name, #referenceName: "Player1_Camera", #distance: [0, 20], #static: 1])
  end if
  if tDamage >= 2.5 then
    PlaySound(0, "Clunk" & random(1, 3), [#priority: #low, #surround: 1, #member3DName: tmember.name, #sender: tmodel.name, #targetName: tmodel.name, #referenceName: "Player1_Camera", #distance: [0, 20], #static: 1])
  end if
end

on areaDamage me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    return 0
  end if
  tList = gGame.fx.Destruction.duplicate()
  if tDataList[#parent].ilk <> #void then
    if tDataList.parent.ilk = #string then
      tParent = GetReferenceType(0, tmember, tDataList.parent)
    else
      tParent = tDataList.parent
    end if
    if tParent <> VOID then
      tUserData = tParent.userData
      if voidp(tUserData[#objects]) = 0 then
        tList = []
        repeat with i in tUserData.objects
          tList.add(i.name)
        end repeat
      end if
    end if
  end if
  if tDataList[#position].ilk = #vector then
    tPosition = tDataList.position
  else
    return 0
  end if
  tPosition = tPosition
  if tDataList[#sender].ilk <> #void then
    tSender = tDataList.sender
  else
    tSender = #world
  end if
  if voidp(gGame[#vehicles]) = 0 then
    repeat with i in gGame.vehicles
      tList.add(i.Vehicle.Proxy.name)
    end repeat
  end if
  tAreaDamage = [#damage: 10, #minDistance: 5, #maxDistance: 10]
  if tDataList[#areaDamage].ilk = #symbol then
    if voidp(gData.data.areaDamage[tDataList.areaDamage]) = 0 then
      tAreaDamage = gData.data.areaDamage[tDataList.areaDamage]
    end if
  end if
  if tDataList[#areaDamage].ilk = #propList then
    tAreaDamage = tDataList.areaDamage
  end if
  repeat with i in tList
    tmodel = tmember.model(i)
    if tmodel = VOID then
      next repeat
    end if
    tDistance = tPosition.distanceTo(tmodel.worldPosition)
    if tDistance < tAreaDamage.maxDistance then
      tPerc = 1.0
      if tDistance <= tAreaDamage.minDistance then
        tDamage = tAreaDamage.damage
      else
        tPerc = 1.0 - (max(0, tDistance - tAreaDamage.minDistance) / (tAreaDamage.maxDistance - tAreaDamage.minDistance))
        tDamage = tPerc * tAreaDamage.damage
      end if
      if i contains "Proxy" then
        gGame.vehicles[symbol(i.char[1..i.length - 5])].Vehicle.impacts.add([tDamage, #areaDamage, tSender])
        next repeat
      end if
      tRB = gGame.Physics.getRigidBody(i)
      tMass = tRB.mass * 3.0
      tDirection = tRB.position - (tPosition - vector(0, 0, 4.5))
      tDirection.normalize()
      tImp = tDirection * (tMass * tPerc)
      tImp.z = tImp.z * 2.0
      tRB.applyLinearImpulse(tImp)
      tRB.applyAngularImpulse(tImp * 0.5)
      if gGame.fx.Destruction.getPos(i) <> 0 then
        tUserData = tmodel.userData
        tUserData.Health = tUserData.Health - tDamage
        if tUserData.Health <= 0 then
          DestroyObject(0, tmember.name, [#model: i, #sender: tSender])
        end if
      end if
    end if
  end repeat
end

on ExplosionPlusInitialization me, tmember
  gGame.fx[#ExplosionPlus] = [:]
  gGame.fx.ExplosionPlus[#id] = 0
  tTexture = createTexture(0, tmember.name, [#texture: "ExplosionFX_Texture", #renderFormat: #rgba8888, #filtering: #lowFiltered])
  tShader = tmember.newShader("ExplosionPlus_Material", #standard)
  tShader.textureList[1] = tmember.texture("DefaultTexture")
  tShader.textureList[2] = tmember.texture("DefaultTexture")
  BlendShader(0, tmember.name, [#shader: tShader.name, #blendMode: #add])
  tShader.emissive = rgb(255, 255, 255)
  tShader.diffuse = rgb(255, 255, 255)
  tShader.ambient = rgb(255, 255, 255)
  tShader.specular = rgb(0, 0, 0)
  tShader.shininess = 0.0
  tShader.textureList[3] = tTexture
  tShader.blendFunctionList[3] = #multiply
  tShader.textureList[4] = tTexture
  tShader.blendFunctionList[4] = #add
  gGame.fx.ExplosionPlus[#texture] = tTexture
  gGame.fx.ExplosionPlus[#shader] = tShader
  tFrames = [8, 6]
  tCoordList = []
  tHStep = 1.0 / tFrames[1]
  tVStep = 0.75 / tFrames[2]
  tF = 0.002
  repeat with j = 1 to tFrames[2]
    repeat with i = 1 to tFrames[1]
      tTexCoords = [[-tHStep + (i * tHStep) + tF, 1.0 - (j * tVStep) + tF], [-tHStep + (i * tHStep) + tF, 1.0 + tVStep - (j * tVStep) - tF], [(i * tHStep) - tF, 1.0 - (j * tVStep) + tF], [(i * tHStep) - tF, 1.0 + tVStep - (j * tVStep) - tF]]
      tCoordList.add(tTexCoords)
    end repeat
  end repeat
  gGame.fx.ExplosionPlus[#FireSmokeCoordList] = tCoordList.duplicate()
  tCoordList = []
  tFrames = [16, 1]
  tHStep = 1.0 / tFrames[1]
  tVStep = 0.0625
  tF = 0.002
  repeat with j = 1 to tFrames[2]
    repeat with i = 1 to tFrames[1]
      tTexCoords = [[-tHStep + (i * tHStep) + tF, 0.25 - (j * tVStep) + tF], [-tHStep + (i * tHStep) + tF, 0.25 + tVStep - (j * tVStep) - tF], [(i * tHStep) - tF, 0.25 - (j * tVStep) + tF], [(i * tHStep) - tF, 0.25 + tVStep - (j * tVStep) - tF]]
      tCoordList.add(tTexCoords)
    end repeat
  end repeat
  gGame.fx.ExplosionPlus[#GlowCoordList] = tCoordList.duplicate()
  tCoordList = [[[0.0, 0.0], [0.0, 0.125], [0.125, 0.0], [0.125, 0.125]]]
  gGame.fx.ExplosionPlus[#SparksCoordList] = tCoordList.duplicate()
end
