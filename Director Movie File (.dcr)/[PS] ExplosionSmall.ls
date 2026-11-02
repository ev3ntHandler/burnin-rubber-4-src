-- [Script] [PS] ExplosionSmall (Script #5915)
-- Script Type: Parent

property p, pID
global gSystem, gGame

on new me, tDataList
  p = [:]
  p[#member] = member(tDataList.member)
  p[#camera] = p.member.camera(tDataList.camera)
  p[#Jetting] = 1
  p[#model] = p.member.group("World")
  if tDataList[#model].ilk = #model then
    p.model = tDataList.model
  end if
  p[#ModelName] = p.model.name & gGame.scriptList.count & _system.milliSeconds
  p[#duration] = tDataList.duration
  if p.duration = VOID then
    p.duration = 4000
  end if
  p[#LinVel] = vector()
  if tDataList[#LinVel] = #vector then
    p[#LinVel] = tDataList.LinVel
  end if
  p[#TotalLife] = 16.0
  p[#Counter] = 1.0
  pID = _system.milliSeconds
  p[#group] = p.member.newGroup("Explosion" & p.ModelName & pID & "_Group")
  p.group.transform.scale = vector(1, 1, 1) * 0.80000000000000004
  p[#direction] = vector()
  if tDataList[#direction].ilk = #vector then
    p.direction = tDataList.direction
  end if
  if tDataList[#position] <> vector() then
    p.group.transform.position = tDataList.position + (p.direction * 2.0)
  else
    p.group.transform.position = p.model.worldPosition
  end if
  if tDataList[#position] <> vector() then
    p[#Override] = 1
  else
    p[#Override] = 0
  end if
  p[#ExploShader] = p.member.shader("ParticleExplosion1_Material")
  p[#SmokeShader] = p.member.shader("ParticleSmoke1_Material")
  p[#Particles] = []
  p[#FrameAmount] = 16
  p[#Streaks] = 0
  if random(10) = 1 then
    p.Streaks = 1
  end if
  p[#StreakList] = []
  t1 = p.model.worldPosition
  repeat with i = 1 to p.Streaks
    tRandom = vector(random(-50, 50) * 0.001, random(-50, 50) * 0.001, 0.05)
    tRV = t1 + tRandom
    tDir = tRV - t1
    tLength = tDir.length
    tDir.normalize()
    tList = []
    repeat with j = 1 to 7
      tOffset = tDir * (j * 2)
      tList.add(tOffset)
    end repeat
    p.StreakList.add(tList)
  end repeat
  p[#timeout] = [0, integer(7500 / gGame.tempo)]
  if (tDataList[#duration].ilk = #integer) or (tDataList[#duration].ilk = #float) then
    p.timeout = [0, integer(tDataList.duration / gGame.tempo)]
  end if
  if p.member.light("Explosion") = VOID then
    p[#light] = p.member.newLight("Explosion")
  else
    p[#light] = p.member.light("Explosion")
  end if
  p.light.transform.position = p.group.worldPosition
  p.light.specular = 0
  p.light.color = rgb(250, 215, 180)
  p.light.attenuation = vector(0.0, 0.10000000000000001, 0.01)
  p[#me] = me
  return me
end

on enterFrame me
  if p.model = VOID then
    delete me
    exit
  end if
  p.light.color = p.light.color - (rgb(75, 75, 75) * gGame.TimeMP)
  p.timeout[1] = p.timeout[1] + (1.0 * gGame.TimeMP)
  p.Counter = p.Counter + gGame.TimeMP
  if p.Counter >= 1.0 then
    if p.Jetting = 1 then
      if gGame.Effects <> #low then
        repeat with i = 1 to 3
          me.AddParticle(i)
        end repeat
      else
        me.AddParticle(1)
        me.AddParticle(2)
      end if
      p.Jetting = 0
    end if
    tList = p.StreakList.duplicate()
    repeat with i = 1 to tList.count
      if tList[i].count > 0 then
        me.AddParticle(i + 1, tList[i][1], 0.59999999999999998)
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
  if p.timeout[1] >= p.timeout[2] then
    delete me
  end if
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

on AddParticle me, tCount, tOffset, tScale
  pID = pID + 1
  tSize = random(30, 40) * 0.10000000000000001
  if tScale <> VOID then
    tSize = tSize * tScale
  end if
  if tCount = 1 then
    V = vector()
  else
    V = vector(0, 0, random(50, 300) * 0.001)
  end if
  if tCount = 1 then
    Pos = vector()
  else
    Pos = randomVector() * 2.39999999999999991
    if Pos.z < 0 then
      Pos.z = -Pos.z
    end if
  end if
  if tOffset <> VOID then
    Pos = tOffset
  end if
  r = vector(0.0, 0.0, random(1, 360))
  s = random(-10, 10) * 0.20000000000000001
  l = random(1, 7)
  repeat with i = 1 to 2
    m = p.member.newModel("PartExplosion" & p.ModelName & "_" & i & "_" & pID, p.member.modelResource("PartExplo" & random(1, 16)))
    m.transform.position = vector()
    m.transform.scale = m.transform.scale * tSize
    if i = 1 then
      m.shader = p.ExploShader
    else
      m.shader = p.SmokeShader
    end if
    m.transform.rotation = r
    m.parent = p.group
    m.pointAtOrientation = [vector(0, 1, 0), vector(0, 0, 1)]
    m.pointAt(p.camera.transform.position, vector(0, 0, 1))
    if i = 2 then
      Pos = Pos + (randomVector() * 0.90000000000000002)
      Pos = Pos - m.transform.yAxis
    end if
    p.Particles.add([#model: m, #position: Pos, #velocity: V, #life: 0, #maxLife: p.TotalLife + l, #spin: s, #startSize: tSize])
  end repeat
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
    return
  end if
  tSubSize = pPart.startSize * (pPart.life / pPart.maxLife)
  s = pPart.startSize + (tSubSize * 3)
  pPart.model.transform.scale = vector(s, s, s)
  tVelocity = pPart.velocity * gGame.TimeMP
  pPart.position = pPart.position + tVelocity
  pPart.model.transform.position = pPart.position
  pPart.model.transform.rotation = gGame.camera[1].BillboardPoint.transform.rotation
  pNewSpin = pPart.life * pPart.spin
  pPart.model.rotate(0, pNewSpin, 0, #self)
  tdiff = integer(p.FrameAmount - (pPart.maxLife - pPart.life))
  if (tdiff >= 1) and (tdiff <= p.FrameAmount) then
    pPart.model.resource = p.member.modelResource("PartExplo" & integer(tdiff))
  end if
end

on delete me
  me.stop()
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
