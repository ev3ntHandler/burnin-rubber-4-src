-- [Script] [PS] Generic Explosion (Script #5912)
-- Script Type: Parent

property p, pID
global gSystem, gGame

on new me, theWorld, theLocation, theCameraToPointAt, tmodel, tDuration, tLinVel
  p = [:]
  p[#member] = theWorld
  p[#camera] = theCameraToPointAt
  p[#Jetting] = 1
  if tmodel = VOID then
    p[#model] = p.member.group("World")
  else
    p[#model] = p.member.model(tmodel)
  end if
  p[#ModelName] = p.model.name & gGame.scriptList.count & _system.milliSeconds
  p[#duration] = tDuration
  if p.duration = VOID then
    p.duration = 400000
  end if
  p[#LinVel] = vector()
  if tLinVel <> VOID then
    p[#LinVel] = tLinVel
  end if
  p[#TotalLife] = 16.0
  p[#Counter] = 1.0
  pID = _system.milliSeconds
  p[#group] = p.member.newGroup("CarExplosion" & p.ModelName & pID & "_Group")
  if theLocation <> vector() then
    p.group.transform.position = theLocation
  else
    p.group.transform.position = p.model.worldPosition
  end if
  if theLocation <> vector() then
    p[#Override] = 1
  else
    p[#Override] = 0
  end if
  p[#ExploShader] = p.member.shader("ParticleExplosion1_Material")
  p[#SmokeShader] = p.member.shader("ParticleSmoke1_Material")
  p[#Particles] = []
  p[#FrameAmount] = 16
  p[#Streaks] = 0
  p[#StreakList] = []
  t1 = p.model.worldPosition
  repeat with i = 1 to p.Streaks
    tRandom = randomVector() * 7.5
    tRandom.z = abs(tRandom.z)
    tRV = t1 + tRandom
    tDir = tRV - t1
    tLength = tDir.magnitude
    tDir.normalize()
    tList = []
    repeat with j = 1 to 10
      tOffset = tDir * j
      tList.add(tOffset)
    end repeat
    p.StreakList.add(tList)
  end repeat
  p[#TimeOutName] = p.ModelName & "StopJetting" & pID
  timeout().new(p.TimeOutName, p.duration, #StopJetting, me)
  p[#me] = me
  return me
end

on enterFrame me
  if p.model = VOID then
    me.deleteSystem()
    exit
  end if
  p.Counter = p.Counter + gGame.TimeMP
  if p.Counter >= 1.0 then
    if p.Jetting = 1 then
      me.AddParticle(p.ExploShader)
      me.AddParticle(p.ExploShader)
      me.AddParticle(p.ExploShader)
      me.AddParticle(p.SmokeShader)
      me.AddParticle(p.SmokeShader)
      p.Jetting = 0
    end if
    tList = p.StreakList.duplicate()
    repeat with i = 1 to tList.count
      if tList[i].count > 0 then
        me.AddParticle(p.ExploShader, vector(), tList[i][1], 0.69999999999999996)
        me.AddParticle(p.SmokeShader, vector(), tList[i][1], 0.69999999999999996)
        p.StreakList[i].deleteAt(1)
        next repeat
      end if
      p.StreakList.deleteOne(i)
    end repeat
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
  p.Jetting = 1
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
  _movie.actorList.deleteOne(p.me)
end

on AddParticle me, tShaderToUse, velocitybump, tOffset, tSize
  if voidp(velocitybump) then
    velocitybump = vector(0, 0, 0)
  end if
  pID = pID + 1
  m = p.member.newModel("PartExplosion" & p.ModelName & pID, p.member.modelResource("PartExplo" & random(1, 16)))
  m.addModifier(#meshDeform)
  m.transform.position = vector()
  m.parent = p.group
  m.shader = tShaderToUse
  m.pointAtOrientation = [vector(0, 1, 0), vector(0, 0, 1)]
  m.pointAt(p.camera.transform.position, vector(0, 0, 1))
  tRandomSize = random(24, 34) * 0.10000000000000001
  if tSize <> VOID then
    tRandomSize = tSize
  end if
  m.transform.scale = m.transform.scale * tRandomSize
  V = vector()
  Pos = (randomVector() * 1.5) + vector(0, 0, 0.5)
  if tShaderToUse.name = "ParticleSmoke1_Material" then
    Pos = Pos - (m.transform.yAxis * 3.0)
  end if
  if tOffset <> VOID then
    Pos = Pos + tOffset
  end if
  if tOffset <> VOID then
    V = V * 0.10000000000000001
  end if
  s = random(-20, 20) * 0.20000000000000001
  if tShaderToUse.name = "ParticleSmoke1_Material" then
    V = V + velocitybump
  end if
  m.transform.rotation = vector(0.0, 0.0, random(1, 360))
  p.Particles.add([#model: m, #position: Pos, #velocity: V, #life: 0, #maxLife: p.TotalLife + random(1, 10), #spin: s, #startSize: tRandomSize])
end

on doParticle me, tCount
  if p.model = VOID then
    me.deleteSystem()
  end if
  pPart = p.Particles[tCount]
  pPart.life = pPart.life + (1.0 * gGame.TimeMP)
  if pPart.life > pPart.maxLife then
    p.member.deleteModel(pPart.model.name)
    p.Particles.deleteAt(tCount)
    if p.Particles.count = 0 then
      me.deleteSystem()
    end if
    return
  end if
  tSubSize = pPart.startSize * (pPart.life / pPart.maxLife)
  s = pPart.startSize + (tSubSize * 3)
  pPart.model.transform.scale = vector(s, s, s)
  tVelocity = pPart.velocity * gGame.TimeMP
  pPart.position = pPart.position + tVelocity
  pPart.model.transform.position = pPart.position
  pPart.model.pointAt(p.camera.transform.position, vector(0, 0, 1))
  tdiff = integer(p.FrameAmount - (pPart.maxLife - pPart.life))
  if (tdiff >= 1) and (tdiff <= p.FrameAmount) then
    pPart.model.resource = p.member.modelResource("PartExplo" & integer(tdiff))
  end if
end
