-- [Script] [PS] Effect Manager (Script #6158)
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
  gGame[#fx] = [:]
  gGame.fx[#Collisions] = [:]
  gGame.fx[#CollisionDamage] = []
  gGame.fx[#Destruction] = []
  gGame.fx[#BulletHits] = []
  gGame.fx[#Decals] = [#amount: 0, #maximum: 20, #default: 1, #metal: 1, #concrete: 1, #wood: 1, #plastic: 1, #explosion: 1, #list: []]
  event(0, #SetupDecals)
  CloneModel(0, p.member.name, [#sourceMember: "Decals", #lod: 0, #delete: 1])
  gGame.fx[#impacts] = [#amount: 0, #maximum: 20, #default: 1, #metal: 1, #concrete: 1, #wood: 1, #plastic: 1, #explosion: 1, #sparks: 1, #list: [#burst: [], #smoke: [], #sparks: [], #Debris: []]]
  event(0, #SetupImpacts)
  CloneModel(0, p.member.name, [#sourceMember: "Impacts", #lod: 0, #delete: 1])
  gGame.fx[#Particles] = [#amount: 0, #list: []]
  gGame.fx[#SpecialParticles] = [#amount: 0, #list: []]
  gGame.fx[#areaDamage] = []
  gGame.fx[#boundingBox] = [:]
  gGame.fx[#DebrisShader] = CreateShader(0, p.member.name, [#shader: "FXDebris_Material", #texture: "Debris_Texture"])
  gGame.fx[#FireShader] = CreateShader(0, p.member.name, [#shader: "FXFire_Material", #texture: "none", #diffuse: rgb(255, 255, 255), #emissive: rgb(240, 150, 0), #blend: 55.0])
  gGame.fx[#SmokeShader] = CreateShader(0, p.member.name, [#shader: "FXSmoke_Material", #texture: "none", #diffuse: rgb(255, 255, 255), #emissive: rgb(35, 25, 25), #blend: 55.0])
  gGame.fx[#WireframeShader] = CreateShader(0, p.member.name, [#shader: "FXWireframe_Material", #texture: "none", #emissive: rgb(255, 255, 255), #renderStyle: #wire])
  return me
end

on enterFrame me
  tCount = gGame.fx.Collisions.count
  repeat with i = 1 to tCount
    tSender = gGame.fx.Collisions.getPropAt(i)
    tList = gGame.fx.Collisions[i]
    gGame.fx.Collisions[symbol(tList[1])][4] = 1
    tmodel = p.member.model(tList[1])
    if tmodel = VOID then
      next repeat
    end if
    tUserData = tmodel.userData
    if gGame.fx.CollisionDamage.getPos(tmodel.name) <> 0 then
      CollisionDamage(0, p.member.name, [#model: tmodel.name, #sender: tSender, #details: tList])
    end if
    if tUserData.count = 0 then
      next repeat
    end if
    if voidp(tUserData[#collision]) = 0 then
      tUserData.collision = 1
    end if
    if gGame.fx.Destruction.getPos(tmodel.name) = 0 then
      next repeat
    end if
    if tmodel.userData.dieOnCollision = 1 then
      DestroyObject(0, p.member.name, [#model: tmodel.name, #sender: tSender])
    end if
    if tList[4] = 1 then
      next repeat
    end if
  end repeat
  gGame.fx.Collisions = [:]
  repeat with i in gGame.fx.Decals.list
  end repeat
  tCount = gGame.fx.impacts.list.burst.count
  repeat with i = tCount down to 1
    tBurst = gGame.fx.impacts.list.burst[i]
    tBurst.transform.scale.x = max(0.01, tBurst.transform.scale.x * (0.55000000000000004 * gGame.TimeMP))
    tBurst.transform.scale.y = tBurst.transform.scale.x
    tBurst.transform.scale.z = max(0.01, tBurst.transform.scale.z * (1.05000000000000004 * gGame.TimeMP))
    if (tBurst.transform.scale.x <= (0.01 * gGame.worldscale)) or (tBurst.transform.scale.z > (5.0 * gGame.worldscale)) then
      gGame.fx.impacts.list.burst.deleteAt(i)
      p.member.deleteModel(tBurst.name)
    end if
  end repeat
  tCount = gGame.fx.impacts.list.smoke.count
  repeat with i = tCount down to 1
    tSmoke = gGame.fx.impacts.list.smoke[i][1]
    tRotation = gGame.fx.impacts.list.smoke[i][2]
    tScale = max(0.01, tSmoke.transform.scale.x * (0.84999999999999998 * gGame.TimeMP))
    if tScale > (0.01 * gGame.worldscale) then
      tSmoke.transform.scale = vector(tScale, tScale, tScale)
      tSmoke.translate(0, 0, 0.03 * gGame.worldscale * gGame.TimeMP, #world)
      tSmoke.transform.rotation = gGame.camera[1].BillboardPoint.transform.rotation
      tRotation = tRotation + (2.0 * gGame.worldscale * gGame.TimeMP)
      tSmoke.rotate(0, tRotation, 0, #self)
      gGame.fx.impacts.list.smoke[i][2] = tRotation
      next repeat
    end if
    gGame.fx.impacts.list.smoke.deleteAt(i)
    p.member.deleteModel(tSmoke.name)
  end repeat
  tCount = gGame.fx.impacts.list.sparks.count
  repeat with i = tCount down to 1
    tSparks = gGame.fx.impacts.list.sparks[i]
    tScale = max(0.01, tSparks.transform.scale.x * (0.69999999999999996 * gGame.TimeMP))
    if tScale > (0.01 * gGame.worldscale) then
      tSparks.transform.scale = vector(tScale, tScale, tScale)
      tSparks.rotate(0, 0, 3 * gGame.TimeMP, #self)
      next repeat
    end if
    gGame.fx.impacts.list.sparks.deleteAt(i)
    p.member.deleteModel(tSparks.name)
  end repeat
  tCount = gGame.fx.impacts.list.Debris.count
  repeat with i = tCount down to 1
    tDebris = gGame.fx.impacts.list.Debris[i][1]
    tTime = gGame.fx.impacts.list.Debris[i][2]
    if tTime > 0 then
      gGame.fx.impacts.list.Debris[i][2] = gGame.fx.impacts.list.Debris[i][2] - gGame.TimeMP
      next repeat
    end if
    if tDebris.count > 0 then
      gGame.Physics.deleteRigidBody(tDebris[1].name)
      p.member.deleteModel(tDebris[1].name)
      tDebris.deleteAt(1)
      next repeat
    end if
    gGame.fx.impacts.list.Debris.deleteAt(i)
  end repeat
  tList = []
  repeat with i in gGame.fx.Particles.list
    if i[1] = VOID then
      next repeat
    end if
    if i[1].resource.emitter.loop = 1 then
      tList.add(i)
      next repeat
    end if
    if (_system.milliSeconds - (i[2] + 100)) > i[1].resource.lifeTime then
      p.member.deleteModelResource(i[1].resource.name)
      p.member.deleteModel(i[1].name)
      next repeat
    end if
    tList.add(i)
  end repeat
  gGame.fx.Particles.list = tList.duplicate()
  repeat with i in gGame.fx.SpecialParticles.list
  end repeat
end

on delete me
  p = [:]
  gGame.deleteProp(#fx)
  if gSystem.scriptList.getPos(me) <> 0 then
    gSystem.scriptList.deleteOne(me)
  else
    gGame.scriptList.deleteOne(me)
  end if
end
