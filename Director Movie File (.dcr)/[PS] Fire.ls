-- [Script] [PS] Fire (Script #5913)
-- Script Type: Parent

property p, pID
global gGame

on new me, theWorld, theLocation, theCameraToPointAt, tmodel, tDuration
  p = [:]
  p[#member] = theWorld
  p[#camera] = theCameraToPointAt
  p[#Jetting] = 1
  p[#model] = tmodel
  p[#ModelName] = p.model.name
  p[#duration] = tDuration
  if p.duration = VOID then
    p.duration = 400000
  end if
  p[#TotalLife] = 68.0
  p[#Counter] = 1.0
  me.script.pID = me.script.pID + 1
  p[#group] = p.member.newGroup("Fire" & p.ModelName & me.script.pID & "_Group")
  p.group.transform.position = theLocation + vector(1, 0.5, -1)
  BlendShader(p.member.name, [#shader: "PartExplo1_Material", #blendMode: #add])
  BlendShader(p.member.name, [#shader: "PartSmoke1_Material", #blendMode: #multiply])
  p[#PartResource] = p.member.modelResource("Particle")
  p[#ExploShader] = p.member.shader("PartExplo1_Material")
  p[#SmokeShader] = p.member.shader("PartSmoke1_Material")
  p[#Particles] = []
  p[#FrameAmount] = 32
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
    end if
    p.Counter = 0
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

on AddParticle me, tShaderToUse, velocitybump
  if voidp(velocitybump) then
    velocitybump = vector(0, 0, 0)
  end if
  pID = pID + 1
  m = p.member.newModel("PartExplosion" & p.ModelName & pID, p.member.modelResource("PartExplo1"))
  m.pointAtOrientation = [vector(0.0, -1.0, 0.0), vector(0.0, 0.0, 1.0)]
  m.addModifier(#meshDeform)
  m.parent = p.group
  m.shader = tShaderToUse
  tRandomSize = random(100, 200) * 0.10000000000000001
  m.transform.scale = m.transform.scale * tRandomSize
  tRandomV = randomVector() * 0.025
  tRandomV.y = random(-15, 15) * 0.01
  V = tRandomV + vector(-0.25, 0.0, 0.14999999999999999)
  Pos = p.model.getWorldTransform().position + V
  s = random(-8, 8) * 0.69999999999999996
  if tShaderToUse.name = "PartSmoke1_Material" then
    V = V + velocitybump
  end if
  m.transform.rotation = vector(0.0, 0.0, random(1, 360))
  p.Particles.add([#model: m, #position: Pos, #velocity: V, #life: 0, #maxLife: p.TotalLife, #spin: s, #startSize: tRandomSize])
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
  s = pPart.startSize - tSubSize
  if s < 0.10000000000000001 then
    s = 0.01
  end if
  pPart.model.transform.scale = vector(s, s, s)
  tVelocity = pPart.velocity * gGame.TimeMP
  pPart.position = pPart.position + tVelocity
  pPart.model.transform.position = pPart.position
  pPart.model.pointAt(p.camera.transform.position)
  pNewSpin = pPart.life * pPart.spin
  pPart.model.rotate(0, pNewSpin, 0, #self)
  tdiff = integer(p.FrameAmount - (pPart.maxLife - pPart.life))
  if (tdiff >= 1) and (tdiff <= p.FrameAmount) then
    pPart.model.resource = p.member.modelResource("PartExplo" & integer(tdiff))
  end if
end
