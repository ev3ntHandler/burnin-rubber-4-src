-- [Script] [M] Traffic Manager (Script #5887)
-- Script Type: Movie

global gSystem, gData, gGame

on BuildWorldTraffic me
  put "BuildWorldTraffic (Handler)"
  if voidp(gGame[#traffic]) = 1 then
    return 0
  end if
  repeat with i = 1 to gGame.traffic.Paths.count
    tProp = gGame.traffic.Paths.getPropAt(i)
    event(0, tProp)
  end repeat
end

on BuildTraffic me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    return 0
  end if
  if voidp(gGame[#traffic]) = 1 then
    return 0
  end if
  tPath = gSystem.event
  if tDataList[#path].ilk = #symbol then
    tPath = tDataList.path
  end if
  tDataList[#path] = tPath
  tType = #Shopper
  if tDataList[#type].ilk = #symbol then
    tTypeList = [#Bus, #Shopper, #Transporter, #Truck, #YUp, #PoliceTraffic, #TaxiTraffic, #ArmoredTruck]
    if tTypeList.getPos(tDataList.type) = 0 then
      tType = #Shopper
    else
      tType = tDataList.type
    end if
  end if
  tSkin = 1
  if tDataList[#skin].ilk = #integer then
    tSkin = tDataList.skin
  end if
  if tSkin > 2 then
    tSkin = 1
  end if
  if tType = #ArmoredTruck then
    tSkin = 1
  end if
  tDirection = #right1
  if tDataList[#direction].ilk = #symbol then
    tDirList = [#right1, #right2, #left1, #left2]
    if tDirList.getPos(tDataList.direction) = 0 then
      tDirection = #right1
    else
      tDirection = tDataList.direction
    end if
  end if
  tID = gGame.traffic.totalCount + 1
  tList = [#model: #none, #Proxy: #none, #RigidBody: #none, #shadowmodel: #none, #collision: #none, #wheels: [], #Lights: [], #path: tPath, #direction: 1, #waypoint: 1, #Speed: 0.45000000000000001, #offset: 0.0, #state: #alive, #intersectDetails: #none, #parent: #none, #data: tDataList.duplicate()]
  tModelList = [string(tType), string(tType) & "Collision", string(tType) & "Wheels1", string(tType) & "Wheels2"]
  if (tType = #Bus) or (tType = #Truck) then
    tModelList.add(string(tType) & "Wheels3")
  end if
  if gGame.WorldTrafficLights[symbol(gGame.world)] = 1 then
    tModelList.add(string(tType) & "FrontLights")
    tModelList.add(string(tType) & "RearLights")
  end if
  tModelList = CloneModel(0, tmember, [#sourceMember: string(tType), #model: tModelList, #NameTag: "Traffic" & tID, #lod: 0])
  if tmember.shader(string(tType) & "_Material") <> VOID then
    tmember.deleteShader(string(tType) & "_Material")
    tmember.deleteShader(string(tType) & "Wheels_Material")
  end if
  tCarShader = tmember.shader(string(tType) & "Skin" & tSkin & "_Material")
  tWheelShader = tmember.shader(string(tType) & "Skin" & tSkin & "Wheels_Material")
  if tCarShader = VOID then
    tCarShader = CreateShader(0, tmember.name, [#shader: string(tType) & "Skin" & tSkin & "_Material", #texture: string(tType) & "Skin" & tSkin & "_Texture"])
    tCarShader.emissive = gData.data.ambientStyle[symbol("World" & gGame.world & gGame.setting)].emissive
    tCarShader.specular = gData.data.ambientStyle[symbol("World" & gGame.world & gGame.setting)].emissive
    tCarShader.shininess = 65.0
    tCarShader.textureList[2] = createTexture(0, tmember.name, [#texture: "Reflection_Texture"])
    tCarShader.textureModeList[2] = #reflection
    tCarShader.blendFunctionList[2] = #add
    tWheelShader = CreateShader(0, tmember.name, [#shader: string(tType) & "Skin" & tSkin & "Wheels_Material", #texture: string(tType) & "Skin" & tSkin & "_Texture"])
    tWheelShader.emissive = gData.data.ambientStyle[symbol("World" & gGame.world & gGame.setting)].emissive
    tWheelShader.specular = gData.data.ambientStyle[symbol("World" & gGame.world & gGame.setting)].emissive
  end if
  if gGame.WorldTrafficLights[symbol(gGame.world)] = 1 then
    tFrontLightShader = tmember.shader("TrafficFrontLight_Material")
    tRearLightShader = tmember.shader("TrafficRearLight_Material")
    if tFrontLightShader = VOID then
      tFrontLightShader = CreateShader(0, tmember.name, [#shader: "TrafficFrontLight_Material", #texture: "FrontLight_Texture"])
      BlendShader(0, tmember.name, [#shader: "TrafficFrontLight_Material", #blendMode: #add])
      tRearLightShader = CreateShader(0, tmember.name, [#shader: "TrafficRearLight_Material", #texture: "RearLight_Texture"])
      BlendShader(0, tmember.name, [#shader: "TrafficRearLight_Material", #blendMode: #add])
    end if
  end if
  tList.model = tModelList[1]
  tList.model.shaderList = tCarShader
  tList.collision = tModelList[2]
  repeat with i in tModelList
    if i = tList.model then
      next repeat
    end if
    if i.name contains "Collision" then
      tList.collision.parent = VOID
      next repeat
    end if
    if i.name contains "Wheels" then
      tList.wheels.add(i)
      i.shaderList = tWheelShader
    end if
    if (i.name contains "Lights") and (gGame.WorldTrafficLights[symbol(gGame.world)] = 1) then
      tList.Lights.add(i)
      if i.name contains "Rear" then
        i.shaderList = tRearLightShader
      end if
      if i.name contains "Front" then
        i.shaderList = tFrontLightShader
      end if
    end if
    i.transform = tList.model.getWorldTransform().inverse() * i.transform
    i.parent = tList.model
  end repeat
  tList.model.pointAtOrientation = [vector(0.0, 1.0, 0.0), vector(0.0, 0.0, 1.0)]
  tShadowResource = tmember.modelResource("SimpleShadow")
  tShadowModel = tmember.newModel("Traffic" & tID & string(tType) & "Shadow", tShadowResource)
  tShadowModel.transform.scale = vector(1, 1, 1) * ((tList.model.boundingSphere[2] + 0.69999999999999996) * 1.5)
  tShadowModel.parent = tList.model
  tShadowShader = tmember.shader(string(tType) & "Shadow_Material")
  if tShadowShader = VOID then
    tShadowShader = CreateShader(0, tmember.name, [#shader: string(tType) & "Shadow_Material", #texture: "DefaultCarShadow_Texture", #blend: 55.0])
  end if
  tShadowModel.shaderList = tShadowShader
  tList.shadowmodel = tShadowModel
  if tDirection = #right1 then
    tList.offset = 2.5
  end if
  if tDirection = #right2 then
    tList.offset = 6.5
  end if
  if tDirection = #left1 then
    tList.offset = -2.5
  end if
  if tDirection = #left2 then
    tList.offset = -6.5
  end if
  if tDirection = #left1 then
    tList.direction = -1
  end if
  if tDirection = #left2 then
    tList.direction = -1
  end if
  tWPList = []
  repeat with i in gGame.traffic.cars[tPath]
    tmodel = tmember.model(i)
    tUserData = tmodel.userData
    tWPList.add(tUserData.waypoint)
  end repeat
  tRandom = random(1, gGame.traffic.Paths[tPath].count)
  repeat while tWPList.getPos(tRandom) <> 0
    tRandom = random(1, gGame.traffic.Paths[tPath].count)
  end repeat
  tList.waypoint = tRandom
  tTransform = gGame.traffic.Paths[tPath][tRandom].duplicate()
  tTransform.position = tTransform.position + (tTransform.xAxis * tList.offset)
  tList.model.transform = tTransform.duplicate()
  tObjectData = gData.data.objects[tType]
  tmodel = tList.model
  if voidp(gGame.fx.boundingBox[symbol(tType)]) = 1 then
    tBB = GetBoundingBox(0, tmember.name, [#model: tmodel.name])
  else
    tBB = gGame.fx.boundingBox[symbol(tType)]
  end if
  tObjectData = [#mass: #static, #type: #default, #Health: #infinite, #score: 0, #script: #none, #sound: #none, #dieOnCollision: 0, #onDeath: #none]
  if voidp(gData.data.objects[symbol(tType)]) = 0 then
    repeat with l = 1 to gData.data.objects[symbol(tType)].count
      tProp = gData.data.objects[symbol(tType)].getPropAt(l)
      tObjectData[tProp] = gData.data.objects[symbol(tType)][l]
    end repeat
  else
    return 0
  end if
  createRigidBody(0, tmember.name, [#model: tmodel.name, #type: #dynamic, #bodyProxy: #convexShape, #restitution: 0.80000000000000004, #friction: 0.34999999999999998, #mass: tObjectData.mass])
  tRB = gGame.Physics.getRigidBody(tmodel.name)
  gGame.Physics.DisableCollision(tRB)
  gGame.Physics.enableCollision(tRB, gGame.vehicles[1].Vehicle.RigidBody)
  tRB.angularDamping = 50000.0
  tRB.linearDamping = 50000.0
  tmodel.userData.addProp(#resource, tmodel.resource.name)
  tmodel.userData.addProp(#transform, tmodel.getWorldTransform().duplicate())
  tmodel.userData.addProp(#LocalTransform, tmodel.transform.duplicate())
  tmodel.userData.addProp(#parent, tmodel.parent)
  tmodel.userData.addProp(#boundingBox, tBB)
  tmodel.userData.addProp(#collision, 0)
  tObjectDataCount = tObjectData.count
  repeat with k = 1 to tObjectDataCount
    tProp = tObjectData.getPropAt(k)
    if [#mass, #restitution, #friction, #isPinned].getPos(tProp) <> 0 then
      next repeat
    end if
    tmodel.userData.addProp(tProp, tObjectData[tProp])
    case tProp of
      #Health:
        if tObjectData[#Health] <> #infinite then
          gGame.fx.Destruction.add(tmodel.name)
        end if
      #sound:
        if tObjectData[#sound] <> #none then
          put "[ALERT]" & TAB & "NO SOUND FUNCTION IMPLEMENTED YET!"
        end if
    end case
  end repeat
  tmodel.userData.addProp(#traffic, 1)
  tmodel.userData.addProp(#id, tID)
  tmodel.userData.addProp(#model, tList.model)
  tmodel.userData.addProp(#RigidBody, tRB)
  tmodel.userData.addProp(#originalHealth, tObjectData.Health)
  repeat with l = 1 to tList.count
    tProp = tList.getPropAt(l)
    tmodel.userData.addProp(tProp, tList[tProp])
  end repeat
  gGame.traffic.cars[tPath].add(tList.model.name)
  gGame.traffic.totalCount = gGame.traffic.totalCount + 1
  if tObjectData[#script].ilk = #string then
    tScript = AddScript(0, EMPTY, [#script: tObjectData.script, #data: [#member: tmember.name, #model: tList.model, #path: tPath]])
    if tScript <> 0 then
      tmodel.userData.script = tScript
    end if
  end if
end

on DeleteTraffic me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    return 0
  end if
  if tDataList[#script].ilk = #instance then
    delete tDataList.script
  end if
  tmodel = tDataList.model
  gGame.Physics.deleteRigidBody(tmodel.name)
  tmember.deleteModel(tmodel.name)
  tmember.deleteModel(tDataList.shadowmodel.name)
  repeat with i in tDataList.wheels
    tmember.deleteModel(i.name)
  end repeat
  repeat with i in tDataList.Lights
    tmember.deleteModel(i.name)
  end repeat
end

on TrafficSpawnItem me, tTarget, tDataList
  tmember = member(tTarget)
  tmodel = tmember.model(tDataList.model)
  tUserData = tmodel.userData
  tDetails = gGame.Physics.rayCastClosest(tmodel.worldPosition + vector(0, 0, 0.5), vector(0.0001, 0.0001, -1.00009999999999999))
  if tDetails.count = 0 then
    return 0
  end if
  tGroupName = tDetails[1].name
  tGroupName = tGroupName.char[1..5]
  tParent = tmember.group(tGroupName & "_Pickups")
  if tParent = VOID then
    return 0
  end if
  t = gGame.vehicles[1]
  tPickup = #none
  if t.Vehicle.damageState = 2 then
    tRandom = random(1, 3)
    if tRandom = 2 then
      tPickup = "Repair"
    end if
  end if
  if tPickup = #none then
    if voidp(t[#Weapons]) = 0 then
      repeat with i = 1 to t.Weapons.States.count
        if t.Weapons[i + 1].clips = 0 then
          tRandom = random(1, 3)
          if tRandom = 2 then
            tPickup = "Ammo"
            exit repeat
          end if
        end if
      end repeat
    end if
  end if
  if tPickup = #none then
    tPickup = "CashWorld"
  end if
  tResourceName = tPickup
  if tPickup = "CashWorld" then
    tResourceName = "Cash"
  end if
  tPickup = tmember.newModel(tGroupName & "_" & tPickup & "_Traffic" & tUserData.id & "_PickUp", tmember.modelResource(tResourceName & "_PickUp"))
  tPickup.pointAtOrientation = [vector(0, -1, 0), vector(0, 0, 1)]
  tPickup.shader = tmember.shader("Pickups_material")
  tPickup.transform.position = tDetails[2] + vector(0, 0, 1.5)
  if tParent.userData.getaProp(#Pickups) = VOID then
    tParent.userData.addProp(#Pickups, [tPickup])
  else
    tParent.userData.Pickups.add(tPickup)
  end if
end

on ArmoredTruckSpawnItem me, tTarget, tDataList
  tmember = member(tTarget)
  tmodel = tmember.model(tDataList.model)
  tUserData = tmodel.userData
  tItemCount = 10
  tStep = 360 / tItemCount
  tWorldTransform = tmodel.getWorldTransform()
  repeat with i = 1 to tItemCount
    tPos = tmodel.worldPosition + vector(0, 0, 1.5)
    tTransform = tWorldTransform.duplicate()
    tTransform.rotate(tPos, tTransform.zAxis, i * tStep)
    tPos = tPos + (tTransform.yAxis * 5.0)
    tDetails = gGame.Physics.rayCastClosest(tPos, vector(0.0001, 0.0001, -1.00009999999999999))
    if tDetails.count = 0 then
      return 0
    end if
    tGroupName = tDetails[1].name
    tGroupName = tGroupName.char[1..5]
    tParent = tmember.group(tGroupName & "_Pickups")
    if tParent = VOID then
      return 0
    end if
    tPickup = "CashWorld"
    tResourceName = "Cash"
    tPickup = tmember.newModel(tGroupName & "_" & tPickup & "_Traffic" & tUserData.id & i & "_PickUp", tmember.modelResource(tResourceName & "_PickUp"))
    tPickup.pointAtOrientation = [vector(0, -1, 0), vector(0, 0, 1)]
    tPickup.shader = tmember.shader("Pickups_material")
    tPickup.transform.position = tDetails[2] + vector(0, 0, 1.5)
    if tParent.userData.getaProp(#Pickups) = VOID then
      tParent.userData.addProp(#Pickups, [tPickup])
      next repeat
    end if
    tParent.userData.Pickups.add(tPickup)
  end repeat
end
