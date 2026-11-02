-- [Script] [PS] Explosion (Script #5910)
-- Script Type: Parent

property p, pID
global gSystem, gGame

on new me, theWorld, theLocation, theCameraToPointAt, tmodel, tDuration, tLinVel, tLinVelOrig, tTrailModelList
  p = [:]
  p[#member] = theWorld
  p[#camera] = theCameraToPointAt
  p[#Jetting] = 8
  if gGame.Effects = #low then
    p.Jetting = 4
  end if
  if tmodel = VOID then
    p[#model] = p.member.group("World")
  else
    p[#model] = p.member.model(tmodel)
  end if
  p[#ModelName] = p.model.name
  p[#duration] = tDuration
  if p.duration = VOID then
    p.duration = 400000
  end if
  p[#LinVel] = vector()
  if tLinVel <> VOID then
    p[#LinVel] = tLinVel
  end if
  p[#LinVelOrig] = VOID
  if tLinVelOrig.ilk <> VOID then
    p.LinVelOrig = tLinVelOrig
  end if
  p[#TotalLife] = 16.0
  p[#Counter] = 1.0
  pID = _system.milliSeconds
  p[#group] = p.member.newGroup("Explosion" & p.ModelName & pID & "_Group")
  if theLocation = vector() then
    p.group.transform.position = theLocation
  else
    p.group.transform.position = p.model.worldPosition
  end if
  if theLocation <> vector() then
    p[#Override] = 1
  else
    p[#Override] = 0
  end if
  p[#TrailModelList] = []
  if tTrailModelList <> VOID then
    p.TrailModelList = tTrailModelList
  end if
  p[#ExploShader] = p.member.shader("ParticleExplosion1_Material")
  p[#SmokeShader] = p.member.shader("ParticleSmoke1_Material")
  p[#Particles] = []
  p[#FrameAmount] = 16
  p[#Streaks] = 3
  if gGame.Effects = #low then
    p.Streaks = 0
  end if
  p[#StreakList] = []
  p[#trailDelay] = 3
  p[#TrailCount] = 10
  if gGame.Effects = #low then
    p.TrailCount = 0
  end if
  p[#TimeOutName] = p.ModelName & "StopJetting" & pID
  timeout().new(p.TimeOutName, p.duration, #StopJetting, me)
  p[#me] = me
  return me
end

on enterFrame me
  if p.model = VOID then
    delete me
    exit
  end if
  p.Counter = p.Counter + gGame.TimeMP
  if p.Counter >= 1.0 then
    if p.Jetting > 0 then
      me.AddParticle(p.ExploShader)
      me.AddParticle(p.SmokeShader)
      p.Jetting = p.Jetting - 1
    end if
    if p.trailDelay <= 0 then
      if p.TrailCount > 0 then
        repeat with i in p.TrailModelList
          me.AddParticle(p.ExploShader, vector(), i.worldPosition, 0.5, 1)
          me.AddParticle(p.SmokeShader, vector(), i.worldPosition, 0.5, 1)
        end repeat
        p.TrailCount = p.TrailCount - 1
      end if
    end if
    p.trailDelay = p.trailDelay - 1
    p.Counter = 0.0
  end if
  if p.Override = 0 then
    startT = p.group.getWorldTransform()
    endT = p.model.getWorldTransform()
    newT = startT.interpolate(endT, 75)
    p.group.transform.position = newT.position
  end if
  pCount = p.Particles.count
  repeat while pCount > 0
    me.doParticle(pCount)
    pCount = pCount - 1
  end repeat
end

on start me
  p.Jetting = 3
  p.Counter = 0
end

on stop me
  p.Jetting = 0
end

on getGroup me
  return p.group
end

on name me
  return "particle"
end

on StopJetting me
  me.stop()
  timeout(p.TimeOutName).forget()
end

on getShader me, tShaderName, tBlendMode
  pShader = p.member.shader(tShaderName)
  if pShader <> VOID then
    return pShader
  end if
  if tShaderName = "PartExplosion_Material" then
    pTextureName = "Explosion_Texture"
  end if
  if tShaderName = "PartSmoke_Material" then
    pTextureName = "SmokeExplosion_Texture"
  end if
  pTexture = p.member.texture(pTextureName)
  if pTexture = VOID then
    pTexture = createTexture(p.member.name, [#fileName: pTextureName, #filtering: #lowFiltered, #renderFormat: #rgba8888])
  end if
  pShader = p.member.newShader(tShaderName, #standard)
  pShader.texture = pTexture
  pShader.emissive = rgb(0, 0, 0)
  pShader.emissive = rgb(0, 0, 0)
  pShader.diffuse = rgb(0, 0, 0)
  pShader.specular = rgb(0, 0, 0)
  SetAddShader(pShader, tBlendMode)
  return pShader
end

on deleteSystem me
  me.stop()
  if _movie.timeoutList.getPos(timeout(p.TimeOutName)) <> 0 then
    timeout(p.TimeOutName).forget()
  end if
  pCount = p.Particles.count
  repeat with i = 1 to pCount
    pPart = p.Particles[i]
    pmodel = pPart.model
    if pmodel = VOID then
      next repeat
    end if
    p.member.deleteModel(pPart.model.name)
  end repeat
  p.member.deleteGroup(p.group.name)
end

on AddParticle me, tShaderToUse, velocitybump, tOffset, tSize, tTrail
  if voidp(velocitybump) then
    velocitybump = vector(0, 0, 0)
  end if
  pID = pID + 1
  tStartFrame = random(1, 16)
  m = p.member.newModel("PartExplosion" & p.ModelName & pID, p.member.modelResource("PartExplo" & tStartFrame))
  m.addModifier(#meshDeform)
  m.worldPosition = p.model.worldPosition + randomVector()
  m.shader = tShaderToUse
  m.pointAtOrientation = [vector(0, 1, 0), vector(0, 0, 1)]
  m.pointAt(p.camera.transform.position, vector(0, 0, 1))
  tRandomSize = random(14, 24) * 0.10000000000000001
  if tSize <> VOID then
    tRandomSize = tSize
  end if
  m.transform.scale = m.transform.scale * tRandomSize
  if tTrail = 1 then
    V = 0.0
  else
    V = 1.0
  end if
  if tOffset <> VOID then
    Pos = tOffset
  else
    Pos = p.model.worldPosition + (randomVector() * 1.39999999999999991)
  end if
  s = random(-13, 13)
  sDrag = 1.0
  m.transform.rotation = vector(0.0, 0.0, random(1, 360))
  tExtraLife = random(1, 30)
  if tShaderToUse.name = "ParticleSmoke1_Material" then
    tExtraLife = random(10, 35)
  end if
  p.Particles.add([#model: m, #position: Pos, #velocity: V, #life: tStartFrame, #maxLife: p.TotalLife + tExtraLife, #spin: s, #spinDrag: 1.0, #startSize: tRandomSize, #LinVel: p.LinVel, #startFrame: tStartFrame])
end

on doParticle me, tCount
  if p.model = VOID then
    delete me
  end if
  pPart = p.Particles[tCount]
  pPart.life = pPart.life + (1.0 * gGame.TimeMP)
  if pPart.life > pPart.maxLife then
    p.member.deleteModel(pPart.model.name)
    p.Particles.deleteAt(tCount)
    if p.Particles.count = 0 then
      delete me
    end if
    return
  end if
  tSubSize = pPart.startSize * (pPart.life / pPart.maxLife)
  s = pPart.startSize + (tSubSize * 3)
  pPart.model.transform.scale = vector(s, s, s)
  tVelocity = p.LinVelOrig.linearVelocity / 32 * pPart.velocity * gGame.TimeMP
  pPart.position = pPart.position + tVelocity
  pPart.model.transform.position = pPart.position
  pPart.model.pointAt(p.camera.transform.position)
  pNewSpin = pPart.spin * (1.0 - (pPart.maxLife / pPart.life)) * gGame.TimeMP
  pPart.model.rotate(0, pNewSpin, 0, #self)
  pPart.velocity = pPart.velocity * 0.99199999999999999
  tdiff = integer(p.FrameAmount - (pPart.maxLife - pPart.life))
  if (tdiff >= 1) and (tdiff <= p.FrameAmount) then
    pPart.model.resource = p.member.modelResource("PartExplo" & integer(tdiff))
  end if
end

on delete me
  me.stop()
  if _movie.timeoutList.getPos(timeout(p.TimeOutName)) <> 0 then
    timeout(p.TimeOutName).forget()
  end if
  pCount = p.Particles.count
  repeat with i = 1 to pCount
    pPart = p.Particles[i]
    pmodel = pPart.model
    if pmodel = VOID then
      next repeat
    end if
    p.member.deleteModel(pPart.model.name)
  end repeat
  p.member.deleteGroup(p.group.name)
  p = [:]
  if gSystem.scriptList.getPos(me) <> 0 then
    gSystem.scriptList.deleteOne(me)
  else
    gGame.scriptList.deleteOne(me)
  end if
end
