-- [Script] [PS] Rocket Old (Script #5892)
-- Script Type: Parent

property p
global gSystem, gGame, gData

on new me, t, tPod
  p = [:]
  p[#member] = t.general.member
  p[#sender] = t.general.tag
  p[#model] = t.Vehicle.model
  p[#data] = gData.data.SecondaryWeapons.RocketPod
  p[#me] = me
  p[#RocketName] = string(p.sender) & "Rocket" & _system.milliSeconds
  p[#Rocket] = p.member.newModel(p.RocketName, p.member.modelResource("Rocket"))
  p.Rocket.shader = p.member.shader("Weapons_Material")
  p[#Flame] = p.member.newModel(p.RocketName & "Flame", p.member.modelResource("RocketFlame"))
  p.Flame.shader = p.member.shader("Effects_Material")
  p.Flame.parent = p.Rocket
  p.Flame.transform.position = p.Rocket.worldPosition - (p.Flame.transform.yAxis * 0.5)
  tTransform = t.Vehicle.Effects.secondary[tPod].getWorldTransform().duplicate()
  p.Rocket.transform = tTransform
  tOffset = randomVector() * 0.25
  p.Rocket.transform.position = p.Rocket.transform.position
  p[#vList] = [p.Rocket.transform.zAxis * 0.40000000000000002, -p.Rocket.transform.zAxis * 0.40000000000000002]
  p[#faces] = 0
  p[#FList] = []
  p[#tList] = []
  p[#TrailResource] = p.member.newMesh(p.RocketName & "Trail", 0, p.vList.count, 0, 0, p.tList.count)
  p[#Trail] = p.member.newModel(p.RocketName & "Trail", p.TrailResource)
  p[#shader] = CreateShader(0, p.member.name, [#shader: p.RocketName & "Trail_Material", #texture: "RocketTrail_Texture", #blend: 100.0])
  tTexture = p.member.texture("RocketTrail2_Texture")
  if tTexture = VOID then
    tTexture = createTexture(0, p.member.name, [#texture: "RocketTrail2_Texture"])
  end if
  p.shader.textureList[2] = tTexture
  p.shader.textureModeList[2] = #wrapPlanar
  p.shader.wrapTransformList[2].rotation = p.Rocket.transform.rotation
  p.Trail.shader = p.shader
  p.Trail.transform.position = tTransform.position
  p.Trail.visibility = #both
  p[#alive] = 1
  p[#Speed] = 5.0
  p[#rotation] = 25
  p[#distance] = 0
  PlaySound(0, "RocketPodLaunch_SFX", [#priority: #low, #surround: 1, #member3DName: gGame.member.name, #sender: t.Vehicle.Proxy.name, #targetName: t.Vehicle.Proxy.name, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 0, #Override: 1])
  p[#timeout] = 4 * gGame.tempo
  return me
end

on enterFrame me
  if p.alive = 1 then
    p.Rocket.translate(0, p.Speed * gGame.TimeMP, 0, #self)
    p.Rocket.rotate(0, p.rotation * gGame.TimeMP, 0, #self)
    p.distance = p.distance + (p.Speed * gGame.TimeMP)
    tTransform = p.Rocket.transform
    tDetails = gGame.Physics.rayCastClosest(tTransform.position, tTransform.yAxis)
    if tDetails.count > 0 then
      if tDetails[4] < (0.75 + (p.Speed * gGame.TimeMP)) then
        tName = tDetails[1].name
        tmodel = p.member.model(tName)
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
        areaDamage(0, p.member.name, [#position: tDetails[2], #data: p.data.areaDamage, #sender: p.sender, #parent: tDetails[1].name.char[1..6] & "Objects"])
        me.DeleteRocket()
        exit
      end if
    end if
    if gGame.TimeMP > 0.09 then
      tRandom = random(10, 30) * 0.10000000000000001
      p.Flame.transform.scale = vector(tRandom, tRandom, tRandom)
    end if
    p.member.deleteModelResource(p.Trail.resource.name)
    p.vList.add((tTransform.zAxis * 0.40000000000000002) + (tTransform.yAxis * p.distance) + (tTransform.xAxis * 0.25))
    p.vList.add((-tTransform.zAxis * 0.40000000000000002) + (tTransform.yAxis * p.distance) + (tTransform.xAxis * 0.25))
    p.tList.add([0, p.distance * 0.20000000000000001])
    p.tList.add([1, p.distance * 0.20000000000000001])
    tCount = p.faces
    p.faces = p.faces + 2
    p.FList.add([1 + tCount, 3 + tCount, 4 + tCount])
    p.FList.add([1 + tCount, 4 + tCount, 2 + tCount])
    p.TrailResource = p.member.newMesh(p.Rocket.name & "Trail" & p.timeout, p.faces, p.vList.count, 0, 0, p.tList.count)
    p.TrailResource.vertexList = p.vList
    p.TrailResource.textureCoordinateList = p.tList
    repeat with i = 1 to p.faces
      p.TrailResource.face[i].vertices = p.FList[i]
      p.TrailResource.face[i].texCoords = p.FList[i]
    end repeat
    p.TrailResource.build()
    p.Trail.resource = p.TrailResource
    p.Trail.shader = p.shader
  else
    tBlend = p.shader.blend
    tBlend = tBlend - 5
    tBlend = max(0, tBlend)
    p.shader.blend = tBlend
    if tBlend = 0 then
      delete me
    end if
  end if
  p.timeout = p.timeout - (1.0 * gGame.TimeMP)
  if p.timeout <= 0 then
    delete me
  end if
end

on DeleteRocket me
  if p.Rocket <> VOID then
    p.member.deleteModel(p.Rocket.name)
  end if
  if p.Flame <> VOID then
    p.member.deleteModel(p.Flame.name)
  end if
  p.alive = 0
end

on delete me
  if p.alive = 1 then
    me.DeleteRocket()
  end if
  if p.shader <> VOID then
    p.member.deleteShader(p.shader.name)
  end if
  if p.Trail <> VOID then
    p.member.deleteModel(p.Trail.name)
  end if
  if p.TrailResource <> VOID then
    p.member.deleteModelResource(p.TrailResource.name)
  end if
  gGame.scriptList.deleteOne(p.me)
end
