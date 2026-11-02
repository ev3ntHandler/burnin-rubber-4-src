-- [Script] [PS] ExplosionGround (Script #5904)
-- Script Type: Parent

property p
global gSystem, gGame

on new me, tDataList
  p = [:]
  p[#member] = VOID
  if tDataList[#member].ilk = #string then
    p.member = member(tDataList.member)
  end if
  if tDataList[#member].ilk = #member then
    p.member = tDataList.member
  end if
  if p.member = VOID then
    return 0
  end if
  p[#id] = gGame.scriptList.count + 1
  if tDataList[#camera].ilk = #string then
    p[#camera] = p.member.camera(tDataList.camera)
  else
    p[#camera] = p.member.camera("DefaultView")
  end if
  p[#name] = "ExplosionPlus_ID" & p.id & "_" & _system.milliSeconds
  p[#group] = p.member.newGroup(p.name & "_Group")
  p[#position] = vector()
  if tDataList[#position].ilk = #vector then
    p.position = tDataList.position
  else
    if tDataList[#position].ilk = #string then
      tObject = GetReferenceType(0, p.member, tDataList.position)
      if tObject <> VOID then
        p.position = tObject.worldPosition
      end if
    end if
  end if
  p[#timeout] = [0, integer(7500 / gGame.tempo)]
  if (tDataList[#duration].ilk = #integer) or (tDataList[#duration].ilk = #float) then
    p.timeout = [0, integer(tDataList.duration / gGame.tempo)]
  end if
  p[#shader] = gGame.fx.ExplosionPlus.shader
  p[#resource] = p.member.newMesh(p.name & "_0", 0, 0, 0, 0, 0)
  p[#model] = p.member.newModel(p.name, p.resource)
  p.model.transform.position = p.position
  p.model.transform.scale = vector(1, 1, 1) * (random(1000, 1900) * 0.001)
  p[#Jetting] = 1
  p[#TotalLife] = 32.0
  p[#Counter] = 1.0
  p[#FrameAmount] = 32
  p[#Particles] = []
  p[#VertList] = []
  p[#FaceList] = []
  p[#TexList] = []
  p[#TexList2] = []
  p.Particles.sort()
  p[#GlowCoordList] = gGame.fx.ExplosionPlus.GlowCoordList
  p[#FireSmokeCoordList] = gGame.fx.ExplosionPlus.FireSmokeCoordList
  p[#SparksCoordList] = gGame.fx.ExplosionPlus.SparksCoordList
  p[#Streaks] = 0
  if random(1, 10) = 1 then
    p.Streaks = 3
  end if
  p[#StreakList] = []
  t1 = p.position + vector(0, 0, 1)
  repeat with i = 1 to p.Streaks
    tRandom = vector(random(-50, 50) * 0.001, random(-50, 50) * 0.001, 0.05)
    tRV = t1 + tRandom
    tDir = tRV - t1
    tLength = tDir.magnitude
    tDir.normalize()
    tDir = tDir * 4.25
    tList = []
    tCount = random(7, 18)
    repeat with j = 1 to tCount
      tPerc = 1.0 - (float(j) / float(tCount))
      tOffset = tDir - (tDir * tPerc)
      tList.add(tOffset)
    end repeat
    tList.add(tDir)
    p.StreakList.add(tList)
  end repeat
  return me
end

on enterFrame me
  p.group.transform.position = p.camera.worldPosition
  p.group.pointAt(p.model.worldPosition, vector(0, 0, 1))
  tTransform = p.group.getWorldTransform()
  p.Counter = p.Counter + gGame.TimeMP
  if p.Counter >= 1.0 then
    if p.Jetting > 0 then
      repeat with i = 1 to 7
        tPos = vector(random(-12, 12) * 0.01, random(-12, 12) * 0.01, random(0, 5) * 0.01)
        tVel = vector(random(-160, 160) * 0.001, random(-160, 160) * 0.001, random(25, 95) * 0.01)
        if i = 1 then
          tSize = 1.75
          tVel = vector(0, 0, 0.07000000000000001)
          tSpin = random(-20, 20) * 0.20000000000000001
          tDistance = tTransform.position.distanceTo(tPos + p.position)
          p.Particles.add([#distance: tDistance, #type: #glow, #position: tPos, #velocity: [tVel, 0.81999999999999995], #life: 0, #FrameAmount: 16, #maxLife: 16, #rotation: [random(15, 60), random(-7, 7), 0.92000000000000004], #startSize: tSize * 1.25])
          p.Particles.add([#distance: tDistance, #type: #explosion, #position: tPos, #velocity: [tVel, 0.81999999999999995], #life: 0, #FrameAmount: 32, #maxLife: p.TotalLife + random(0, 14), #rotation: [random(15, 60), random(-7, 7), 0.92000000000000004], #startSize: tSize])
          next repeat
        end if
        tSize = random(24, 55) * 0.045
        tSpin = random(-20, 20) * 0.20000000000000001
        tDistance = tTransform.position.distanceTo(tPos + p.position)
        p.Particles.add([#distance: tDistance, #type: #explosion, #position: tPos, #velocity: [tVel, 0.81999999999999995], #life: 0, #FrameAmount: 32, #maxLife: p.TotalLife + random(0, 14), #rotation: [random(15, 60), random(-7, 7), 0.92000000000000004], #startSize: tSize])
        tPos = vector(random(-12, 12) * 0.01, random(-12, 12) * 0.01, random(0, 5) * 0.01)
        tVel = vector(random(-160, 160) * 0.001, random(-160, 160) * 0.001, random(25, 95) * 0.01)
        tSize = random(34, 40) * 0.045
        tSpin = random(-20, 20) * 0.20000000000000001
        tDistance = tTransform.position.distanceTo(tPos + p.position)
        p.Particles.add([#distance: tDistance, #type: #sparks, #position: tPos, #velocity: [tVel, 0.75], #life: 0, #FrameAmount: 1, #maxLife: 10 + random(2, 10), #rotation: [random(15, 60), random(-5, 5), 0.92000000000000004], #startSize: tSize])
      end repeat
      p.Jetting = p.Jetting - 1
    end if
    tList = p.StreakList.duplicate()
    repeat with i = 1 to tList.count
      if tList[i].count > 0 then
        tPos = vector(0, 0, 0.5) + tList[i][1]
        tVel = tList[i][1] * 0.04
        tSize = 0.40000000000000002
        tSpin = random(-20, 20) * 0.20000000000000001
        tDistance = tTransform.position.distanceTo(tPos + p.position)
        p.Particles.add([#distance: tDistance, #type: #explosion, #shader: p.shader, #position: tPos, #velocity: [tVel, 0.90000000000000002], #life: 0, #FrameAmount: 32, #maxLife: p.TotalLife + random(0, 8), #rotation: [random(-45, 45), random(-10, 10), 0.92000000000000004], #startSize: tSize])
        p.StreakList[i].deleteAt(1)
        next repeat
      end if
      p.StreakList.deleteOne(i)
    end repeat
    p.Counter = 0.0
  end if
  p.VertList = []
  p.FaceList = []
  p.TexList = []
  p.TexList2 = []
  tCount = p.Particles.count
  repeat while tCount > 0
    tPart = p.Particles[tCount]
    tPart.life = tPart.life + (1.0 * gGame.TimeMP)
    if tPart.life > tPart.maxLife then
      p.Particles.deleteAt(tCount)
      if p.Particles.count = 0 then
        delete me
        exit
      end if
      next repeat
    end if
    tCounter = p.VertList.count
    tSubSize = tPart.startSize * (tPart.life / tPart.maxLife)
    s = tPart.startSize + (tSubSize * 1.5)
    tPart.velocity[1] = tPart.velocity[1] * tPart.velocity[2]
    tPart.position = tPart.position + tPart.velocity[1]
    tPart.rotation[2] = tPart.rotation[2] * tPart.rotation[3]
    tPart.rotation[1] = tPart.rotation[1] + tPart.rotation[2]
    tPart.distance = tTransform.position.distanceTo(tPart.position + p.position)
    tFrame = abs(integer(tPart.FrameAmount - (tPart.maxLife - tPart.life)))
    if tFrame <= 0 then
      tFrame = 1
    end if
    tFrame = min(tFrame, p.FrameAmount)
    t = tTransform.duplicate()
    t.rotation = t.rotation + vector(0, tPart.rotation[1], 0)
    tX = t.xAxis
    tZ = t.yAxis
    p.VertList.add(tPart.position - (tZ * s))
    p.VertList.add(tPart.position - (tX * s))
    p.VertList.add(tPart.position + (tX * s))
    p.VertList.add(tPart.position + (tZ * s))
    if tPart.type = #glow then
      p.TexList.add([0.0, 0.5])
      p.TexList.add([0.0, 0.5])
      p.TexList.add([0.0, 0.5])
      p.TexList.add([0.0, 0.5])
      p.TexList2.add(p.GlowCoordList[tFrame][1])
      p.TexList2.add(p.GlowCoordList[tFrame][2])
      p.TexList2.add(p.GlowCoordList[tFrame][3])
      p.TexList2.add(p.GlowCoordList[tFrame][4])
    end if
    if tPart.type = #explosion then
      p.TexList.add(p.FireSmokeCoordList[tFrame + 16][1])
      p.TexList.add(p.FireSmokeCoordList[tFrame + 16][2])
      p.TexList.add(p.FireSmokeCoordList[tFrame + 16][3])
      p.TexList.add(p.FireSmokeCoordList[tFrame + 16][4])
      if tFrame <= 16 then
        p.TexList2.add(p.FireSmokeCoordList[tFrame][1])
        p.TexList2.add(p.FireSmokeCoordList[tFrame][2])
        p.TexList2.add(p.FireSmokeCoordList[tFrame][3])
        p.TexList2.add(p.FireSmokeCoordList[tFrame][4])
      else
        p.TexList2.add([0.0, 1.0])
        p.TexList2.add([0.0, 1.0])
        p.TexList2.add([0.0, 1.0])
        p.TexList2.add([0.0, 1.0])
      end if
    end if
    if tPart.type = #sparks then
      p.TexList.add([0.0, 0.5])
      p.TexList.add([0.0, 0.5])
      p.TexList.add([0.0, 0.5])
      p.TexList.add([0.0, 0.5])
      p.TexList2.add(p.SparksCoordList[1][1])
      p.TexList2.add(p.SparksCoordList[1][2])
      p.TexList2.add(p.SparksCoordList[1][3])
      p.TexList2.add(p.SparksCoordList[1][4])
    end if
    p.FaceList.add([1 + tCounter, 3 + tCounter, 4 + tCounter])
    p.FaceList.add([1 + tCounter, 4 + tCounter, 2 + tCounter])
    tCount = tCount - 1
  end repeat
  p.timeout[1] = p.timeout[1] + (1.0 * gGame.TimeMP)
  p.member.deleteModelResource(p.resource.name)
  p.resource = p.member.newMesh(p.name & "_" & p.timeout[1], p.FaceList.count, p.VertList.count, 0, 0, p.TexList.count, 4)
  p.resource.vertexList = p.VertList
  if p.TexList.count > 0 then
    p.resource.textureLayer[1].textureCoordinateList = p.TexList
    p.resource.textureLayer[2].textureCoordinateList = p.TexList
    p.resource.textureLayer[3].textureCoordinateList = p.TexList
    p.resource.textureLayer[4].textureCoordinateList = p.TexList2
  end if
  tCount = p.FaceList.count
  repeat with i = 1 to tCount
    tList = p.FaceList[i]
    p.resource.face[i].vertices = tList
    p.resource.face[i].textureLayer[1].textureCoordinates[1] = tList
    p.resource.face[i].textureLayer[2].textureCoordinates[2] = tList
    p.resource.face[i].textureLayer[3].textureCoordinates[3] = tList
    p.resource.face[i].textureLayer[4].textureCoordinates[4] = tList
  end repeat
  p.resource.build()
  p.model.resource = p.resource
  p.model.shader = p.shader
  if p.timeout[1] >= p.timeout[2] then
    delete me
  end if
end

on delete me
  tModelName = p.model.name
  tResourceName = p.model.resource.name
  tGroupName = p.group.name
  p.member.deleteModel(tModelName)
  p.member.deleteModelResource(tResourceName)
  p.member.deleteGroup(tGroupName)
  p = [:]
  if gSystem.scriptList.getPos(me) <> 0 then
    gSystem.scriptList.deleteOne(me)
  else
    gGame.scriptList.deleteOne(me)
  end if
end
