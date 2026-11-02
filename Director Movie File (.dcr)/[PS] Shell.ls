-- [Script] [PS] Shell (Script #5896)
-- Script Type: Parent

property p
global gSystem, gGame, gData

on new me, t
  p = [:]
  p[#member] = t.general.member
  p[#sender] = t.general.tag
  p[#model] = t.Vehicle.model
  p[#data] = gData.data.SecondaryWeapons.MainGun
  p[#me] = me
  p[#ShellName] = string(p.sender) & "Shell" & _system.milliSeconds
  p[#Shell] = p.member.newModel(p.ShellName, p.member.modelResource("Shell"))
  p.Shell.shader = p.member.shader("Weapons_Material")
  tTransform = t.Vehicle.Effects.secondary[1].getWorldTransform().duplicate()
  p.Shell.transform = tTransform
  p[#shader] = CreateShader(0, p.member.name, [#shader: p.ShellName & "Trail_Material", #texture: "RocketTrail_Texture", #blend: 100.0])
  if gGame.Effects <> #low then
    p[#vList] = [p.Shell.transform.zAxis, -p.Shell.transform.zAxis]
    p[#faces] = 0
    p[#FList] = []
    p[#tList] = []
    p[#TrailResource] = p.member.newMesh(p.ShellName & "Trail", 0, p.vList.count, 0, 0, p.tList.count)
    p[#Trail] = p.member.newModel(p.ShellName & "Trail", p.TrailResource)
    tTexture = p.member.texture("RocketTrail2_Texture")
    if tTexture = VOID then
      tTexture = createTexture(0, p.member.name, [#texture: "RocketTrail2_Texture"])
    end if
    p.shader.textureList[2] = tTexture
    p.shader.textureModeList[2] = #wrapPlanar
    p.shader.wrapTransformList[2].rotation = p.Shell.transform.rotation
    p.Trail.shader = p.shader
    p.Trail.transform.position = p.Shell.transform.position
    p.Trail.visibility = #both
  end if
  p[#alive] = 1
  p[#Speed] = 7.5
  p[#rotation] = 25
  p[#distance] = 0
  tSound = "MainGun" & random(1, 2) & "_SFX"
  PlaySound(0, tSound, [#priority: #low, #surround: 1, #member3DName: gGame.member.name, #sender: t.Vehicle.Proxy.name, #targetName: t.Vehicle.Proxy.name, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 0, #Override: 1])
  p[#timeout] = 4 * gGame.tempo
  return me
end

on enterFrame me
  if p.alive = 1 then
    p.Shell.translate(0, p.Speed * gGame.TimeMP, 0, #self)
    p.Shell.rotate(0, p.rotation * gGame.TimeMP, 0, #self)
    p.distance = p.distance + (p.Speed * gGame.TimeMP)
    tTransform = p.Shell.getWorldTransform()
    tDetails = gGame.Physics.rayCastClosest(tTransform.position, tTransform.yAxis)
    if tDetails.count > 0 then
      if tDetails[4] < (0.75 + (p.Speed * gGame.TimeMP)) then
        tName = tDetails[1].name
        tmodel = p.member.model(tName)
        tExploScript = new(script("[PS] ExplosionMedium"), [#member: p.member.name, #position: tDetails[2], #direction: tDetails[3], #camera: "Player1_Camera", #duration: 1500])
        if tExploScript <> VOID then
          gGame.scriptList.add(tExploScript)
        end if
        PlaySound(0, "MainGunExplosion_SFX", [#priority: #medium, #surround: 1, #member3DName: p.member.name, #sender: p.Shell.name, #targetName: p.Shell.name, #referenceName: "Player1_Camera", #distance: [80, 300], #static: 1, #Override: 1])
        areaDamage(0, p.member.name, [#position: p.Shell.worldPosition, #areaDamage: p.data.areaDamage, #sender: p.sender, #parent: p.member.model(tDetails[1].name).parent])
        me.DeleteShell()
        exit
      end if
    end if
    if gGame.Effects <> #low then
      p.member.deleteModelResource(p.Trail.resource.name)
      p.vList.add((tTransform.zAxis * 0.40000000000000002) + (tTransform.yAxis * p.distance) + (tTransform.xAxis * 0.20000000000000001))
      p.vList.add((-tTransform.zAxis * 0.40000000000000002) + (tTransform.yAxis * p.distance) + (-tTransform.xAxis * 0.20000000000000001))
      p.tList.add([0, p.distance * 0.20000000000000001])
      p.tList.add([1, p.distance * 0.20000000000000001])
      tCount = p.faces
      p.faces = p.faces + 2
      p.FList.add([1 + tCount, 3 + tCount, 4 + tCount])
      p.FList.add([1 + tCount, 4 + tCount, 2 + tCount])
      p.TrailResource = p.member.newMesh(p.Shell.name & "Trail" & p.timeout, p.faces, p.vList.count, 0, 0, p.tList.count)
      p.TrailResource.vertexList = p.vList
      p.TrailResource.textureCoordinateList = p.tList
      repeat with i = 1 to p.faces
        p.TrailResource.face[i].vertices = p.FList[i]
        p.TrailResource.face[i].texCoords = p.FList[i]
      end repeat
      p.TrailResource.build()
      p.Trail.resource = p.TrailResource
      p.Trail.shader = p.shader
    end if
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

on DeleteShell me
  if p.Shell <> VOID then
    p.member.deleteModel(p.Shell.name)
  end if
  p.alive = 0
end

on delete me
  if p.alive = 1 then
    me.DeleteShell()
  end if
  if p.shader <> VOID then
    p.member.deleteShader(p.shader.name)
  end if
  if gGame.Effects <> #low then
    if p.Trail <> VOID then
      p.member.deleteModel(p.Trail.name)
    end if
    if p.TrailResource <> VOID then
      p.member.deleteModelResource(p.TrailResource.name)
    end if
  end if
  gGame.scriptList.deleteOne(p.me)
end
