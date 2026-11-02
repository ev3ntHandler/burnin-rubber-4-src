-- [Script] [PS] Sam Rocket (Script #5901)
-- Script Type: Parent

property p
global gSystem, gGame, gData

on new me, tDataList
  p = [:]
  p[#member] = tDataList.member
  p[#sender] = tDataList.sender
  p[#transform] = tDataList.transform
  p[#me] = me
  if p.member.model("Rocket") = VOID then
    tModelList = CloneModel(0, p.member.name, [#sourceMember: "Weapons", #model: ["Rocket", "RocketFlame"], #hide: 1, #lod: 0, #delete: 1])
    BlendShader(0, p.member.name, [#shader: "RocketFlame_Material", #blendMode: #add])
  end if
  p[#RocketName] = string(p.sender) & "Rocket" & _system.milliSeconds
  p[#Rocket] = p.member.newModel(p.RocketName, p.member.modelResource("Rocket"))
  p.Rocket.shader = p.member.shader("Weapons_Material")
  p[#Flame] = p.member.newModel(p.RocketName & "Flame", p.member.modelResource("RocketFlame"))
  p.Flame.shader = p.member.shader("Effects_Material")
  p.Flame.parent = p.Rocket
  p.Flame.transform.position = p.Rocket.worldPosition - (p.Flame.transform.yAxis * 0.5)
  p.Rocket.transform = p.transform
  p[#target] = gGame.vehicles[1].Vehicle.model
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
  p.Trail.transform.position = p.transform.position
  p.Trail.visibility = #both
  p[#alive] = 1
  p[#Speed] = 5.0
  p[#rotation] = 25
  p[#distance] = 0
  PlaySound(0, "RocketPodLaunch_SFX", [#priority: #low, #surround: 1, #member3DName: p.member.name, #sender: p.sender, #targetName: p.sender, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 0, #Override: 1])
  p[#timeout] = 3 * gGame.tempo
  return me
end

on enterFrame me
  if p.alive = 1 then
    p.Rocket.translate(0, p.Speed * gGame.TimeMP, 0, #self)
    p.Rocket.rotate(0, p.rotation * gGame.TimeMP, 0, #self)
    p.distance = p.distance + (p.Speed * gGame.TimeMP)
    tTransform = p.Rocket.transform
    tDistance = p.Rocket.worldPosition.distanceTo(p.target.worldPosition)
    if tDistance < 6.0 then
      me.destroy()
      exit
    else
      tDetails = gGame.Physics.rayCastClosest(tTransform.position, tTransform.yAxis)
      if tDetails.count > 0 then
        if tDetails[4] < (0.75 + (p.Speed * gGame.TimeMP)) then
          if tDetails[1].name contains "AI" then
            nothing()
          else
            me.destroy()
            exit
          end if
        end if
      end if
    end if
    tRandom = random(10, 30) * 0.10000000000000001
    p.Flame.transform.scale = vector(tRandom, tRandom, tRandom)
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
    me.DeleteRocket()
  end if
end

on destroy me
  tExploScript = new(script("[PS] ExplosionSmall"), [#member: p.member.name, #position: p.Rocket.worldPosition, #camera: "Player1_Camera", #duration: 2500])
  if tExploScript <> VOID then
    gGame.scriptList.add(tExploScript)
  end if
  PlaySound(0, "RocketPodExplosion_SFX", [#priority: #medium, #surround: 1, #member3DName: p.member.name, #sender: p.Rocket.name, #targetName: p.Rocket.name, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 1, #Override: 1])
  areaDamage(0, p.member.name, [#position: p.Rocket.worldPosition, #areaDamage: [#damage: 30.0, #minDistance: 3.0, #maxDistance: 8.0], #sender: p.sender])
  me.DeleteRocket()
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
