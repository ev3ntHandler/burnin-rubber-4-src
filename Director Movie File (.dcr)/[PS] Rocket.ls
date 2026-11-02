-- [Script] [PS] Rocket (Script #5898)
-- Script Type: Parent

property p
global gSystem, gGame, gData

on new me, t, tPod
  p = [:]
  p[#member] = t.general.member
  p[#sender] = t.Vehicle.Proxy.name
  p[#controller] = t.general.controller
  p[#model] = t.Vehicle.model
  p[#Physics] = gGame.Physics
  p[#data] = gData.data.SecondaryWeapons.RocketPod
  p.data[#Speed] = 5.0
  p.data[#rotation] = 25
  if voidp(gGame[#Weapons]) = 1 then
    gGame[#Weapons] = [:]
  end if
  if voidp(gGame.Weapons[#rockets]) = 1 then
    gGame.Weapons[#rockets] = 0
  end if
  gGame.Weapons.rockets = gGame.Weapons.rockets + 1
  tRocketNumber = gGame.Weapons.rockets
  tRocketName = string(p.sender) & "Rocket" & tRocketNumber
  p[#Rocket] = p.member.newModel(tRocketName, p.member.modelResource("Rocket"))
  p.Rocket.pointAtOrientation = [vector(0, 1, 0), vector(0, 0, 1)]
  p.Rocket.shader = p.member.shader("Weapons_Material")
  p[#Flame] = p.member.newModel(tRocketName & "Flame", p.member.modelResource("RocketFlame"))
  p.Flame.shader = p.member.shader("Effects_Material")
  p.Flame.parent = p.Rocket
  p.Flame.transform.position = p.Rocket.worldPosition - (p.Flame.transform.yAxis * 0.5)
  tTransform = t.Vehicle.Effects.secondary[tPod].getWorldTransform().duplicate()
  p.Rocket.transform = tTransform
  tOffset = randomVector() * 0.25
  p.Rocket.transform.position = p.Rocket.transform.position
  p[#TrailEffect] = 0
  if gGame.Effects <> #low then
    me.CreateTrail(tRocketName)
  end if
  p[#state] = #flying
  p[#Speed] = p.data.Speed
  p[#rotation] = p.data.rotation
  p[#distance] = 0
  p[#target] = #none
  p[#timeout] = integer(4 * gGame.tempo)
  PlaySound(0, "RocketPodLaunch_SFX", [#priority: #low, #surround: 1, #member3DName: gGame.member.name, #sender: t.Vehicle.Proxy.name, #targetName: t.Vehicle.Proxy.name, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 0, #Override: 1])
  return me
end

on enterFrame me
  if p.state = #flying then
    p.Rocket.translate(0, p.Speed * gGame.TimeMP, 0, #self)
    p.Rocket.rotate(0, p.rotation * gGame.TimeMP, 0, #self)
    p.distance = p.distance + (p.Speed * gGame.TimeMP)
    tTransform = p.Rocket.transform
    tDetails = gGame.Physics.rayCastClosest(tTransform.position, tTransform.yAxis)
    if tDetails.count > 0 then
      if tDetails[4] < (0.75 + (p.Speed * gGame.TimeMP)) then
        p.state = #destroy
      end if
      if (p.controller = #player) and (tDetails[1] contains "AI") then
        gGame.SWGameTrophies.rockethit = gGame.SWGameTrophies.rockethit + 1
      end if
    end if
    if gGame.TimeMP > 0.09 then
      tRandom = random(10, 30) * 0.10000000000000001
      p.Flame.transform.scale = vector(tRandom, tRandom, tRandom)
    end if
    if p.TrailEffect = 1 then
      p.trailCounter = p.trailCounter + (1.0 * gGame.TimeMP)
      tResource = p.Trail.resource
      tVertexList = tResource.vertexList
      if p.trailCounter >= 1.0 then
        p.trailCounter = 0.0
        tCount = tVertexList.count
        repeat with i = tCount down to 3
          tVertexList[i] = tVertexList[i - 2]
        end repeat
      end if
      tTransform = p.Flame.getWorldTransform()
      tVertexList[1] = tTransform.position + (tTransform.xAxis * p.width)
      tVertexList[2] = tTransform.position - (tTransform.xAxis * p.width)
      tResource.vertexList = tVertexList
    end if
  end if
  if p.state = #Fading then
    if p.TrailEffect = 1 then
      p.TrailShader.blend = max(0, p.TrailShader.blend - (5.0 * gGame.TimeMP))
      if p.TrailShader.blend = 0 then
        p.state = #delete
      end if
    else
      p.state = #delete
    end if
  else
    p.timeout = p.timeout - (1.0 * gGame.TimeMP)
    if p.timeout <= 0 then
      p.state = #destroy
      tDetails = []
    end if
  end if
  if p.state = #destroy then
    me.destroyRocket(tDetails)
  end if
  if p.state = #delete then
    delete me
  end if
end

on CreateTrail me, tRocketName
  p[#TrailShader] = CreateShader(0, p.member.name, [#shader: tRocketName & "Trail_Material", #texture: "RocketTrail_Texture", #emissive: rgb(255, 255, 255), #blend: 100.0])
  if p.member.texture("RocketTrail2_Texture") = VOID then
    createTexture(0, p.member.name, [#texture: "RocketTrail2_Texture", #renderFormat: #rgba8888])
  end if
  p.TrailShader.textureList[2] = p.member.texture("RocketTrail2_Texture")
  p[#width] = 0.29999999999999999
  tFaces = 40
  tVertices = tFaces + 2
  tResource = p.member.newMesh(tRocketName & "Trail", tFaces, tVertices, tVertices, 0, tVertices, 2)
  tVertexList = []
  tFaceList = []
  tUVList1 = []
  tUVList2 = []
  tTransform = p.Flame.getWorldTransform()
  t1 = tTransform.position + (tTransform.xAxis * p.width)
  t2 = tTransform.position - (tTransform.xAxis * p.width)
  tCount = -1.0
  tVCalc = tVertices / 2
  repeat with i = 1 to tVCalc
    tVertexList.add(t1)
    tVertexList.add(t2)
    tUVList1.add([0.0, 1.0 + (tCount + i)])
    tUVList1.add([1.0, 1.0 + (tCount + i)])
    tUVList2.add([0.0, -((i / float(tVCalc)) - 0.001)])
    tUVList2.add([1.0, -((i / float(tVCalc)) - 0.001)])
  end repeat
  tCount = -2
  repeat with i = 1 to tFaces / 2
    tCount = tCount + 2
    tFaceList.add([1 + tCount, 2 + tCount, 3 + tCount])
    tFaceList.add([2 + tCount, 4 + tCount, 3 + tCount])
  end repeat
  tResource.vertexList = tVertexList
  tResource.textureLayer[1].textureCoordinateList = tUVList1
  tResource.textureLayer[2].textureCoordinateList = tUVList2
  repeat with i = 1 to tFaces
    tResource.face[i].vertices = tFaceList[i]
    tResource.face[i].shader = p.TrailShader
    tResource.face[i].textureLayer[1].textureCoordinates[1] = tFaceList[i]
    tResource.face[i].textureLayer[1].textureCoordinates[2] = tFaceList[i]
  end repeat
  tResource.build()
  p[#Trail] = p.member.newModel(tRocketName & "Trail", tResource)
  p.Trail.shaderList[1] = p.TrailShader
  p.Trail.visibility = #both
  p[#trailCounter] = 0.0
  p.TrailEffect = 1
end

on destroyRocket me, tDetails
  if tDetails.count > 0 then
    tExploScript = new(script("[PS] ExplosionSmall"), [#member: p.member.name, #position: tDetails[2], #direction: tDetails[3], #camera: "Player1_Camera", #duration: 1500])
    if tExploScript <> VOID then
      gGame.scriptList.add(tExploScript)
    end if
    if string(p.sender) contains "player" then
      UPdateSWTrophyExplosion()
    end if
    PlaySound(0, "RocketPodExplosion_SFX", [#priority: #medium, #surround: 1, #member3DName: p.member.name, #sender: p.Rocket.name, #targetName: p.Rocket.name, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 1, #Override: 1])
    if (tDetails[1].type = #static) and (gGame.Effects = #high) then
      CreateDecal(0, p.member.name, [#type: #explosion, #model: tDetails[1].name, #position: tDetails[2], #normal: tDetails[3], #scale: 12.0])
    end if
    areaDamage(0, p.member.name, [#position: tDetails[2], #areaDamage: p.data.areaDamage, #sender: p.sender, #parent: tDetails[1].name.char[1..6] & "Objects"])
  end if
  p.member.deleteModel(p.Rocket.name)
  p.member.deleteModel(p.Flame.name)
  p.state = #Fading
end

on delete me
  if p.state = #flying then
    me.destroyRocket([])
  end if
  if gGame.Effects <> #low then
    p.member.deleteShader(p.TrailShader.name)
    p.member.deleteModelResource(p.Trail.resource.name)
    p.member.deleteModel(p.Trail.name)
  end if
  p = [:]
  gGame.scriptList.deleteOne(me)
end
