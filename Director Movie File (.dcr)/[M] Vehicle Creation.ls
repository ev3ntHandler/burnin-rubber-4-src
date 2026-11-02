-- [Script] [M] Vehicle Creation (Script #5871)
-- Script Type: Movie

global gSystem, gData, gGame, gSound

on CreateVehicle me, tTarget, tDataList
  tmember = VOID
  if tTarget.ilk = #string then
    tmember = member(tTarget)
  end if
  if tTarget.ilk = #member then
    tmember = tTarget
  end if
  if tmember = VOID then
    return 0
  end if
  if tDataList = VOID then
    tDataList = [:]
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  tCarName = "Default"
  if tDataList[#car].ilk = #string then
    tCarName = tDataList.car
  end if
  if voidp(gData.data.car[symbol(tCarName)]) = 1 then
    tCarName = "Default"
  end if
  tController = VOID
  if tDataList[#controller].ilk = #symbol then
    tList = [#player, #AI]
    if tList.getPos(tDataList.controller) <> 0 then
      tController = tDataList.controller
    end if
  end if
  if tController = VOID then
    return 0
  end if
  tNr = gGame.vehicles.count + 1
  tData = gData.data.car[symbol(tCarName)].duplicate()
  if tController = #player then
    if (tCarName = "PlayerBoat") or (tCarName = "PlayerPlane") or (tCarName = "PlayerHelicopter") then
      tData.skin = 1
    else
      tData.skin = gData.data.car[symbol(gGame.car)].skin
    end if
  end if
  if voidp(tData[#personality]) = 1 then
    if voidp(gData.data.carpersonality[symbol(tCarName)]) = 1 then
      tData[#personality] = gData.data.carpersonality.default.duplicate()
    else
      tData[#personality] = gData.data.carpersonality[symbol(tCarName)].duplicate()
    end if
  else
    if voidp(gData.data.carpersonality[symbol(tData.personality)]) = 1 then
      tData[#personality] = gData.data.carpersonality.default.duplicate()
    else
      tData[#personality] = gData.data.carpersonality[symbol(tData.personality)].duplicate()
    end if
  end if
  if voidp(tData[#upgrades]) = 1 then
    if voidp(gData.data.CarUpgrades[symbol(tCarName)]) = 1 then
      tData[#upgrades] = gData.data.CarUpgrades.default
    else
      tData[#upgrades] = gData.data.CarUpgrades[symbol(tCarName)]
    end if
  else
    if voidp(gData.data.CarUpgrades[symbol(tData.upgrades)]) = 1 then
      tData[#upgrades] = gData.data.CarUpgrades.default
    else
      tData[#upgrades] = gData.data.CarUpgrades[symbol(tData.upgrades)]
    end if
  end if
  if voidp(tData[#Weapons]) = 1 then
    if voidp(gData.data.CarWeapons[symbol(tCarName)]) = 1 then
      tData[#Weapons] = gData.data.CarWeapons.default
    else
      tData[#Weapons] = gData.data.CarWeapons[symbol(tCarName)]
    end if
  else
    if voidp(gData.data.CarWeapons[symbol(tData.Weapons)]) = 1 then
      tData[#Weapons] = gData.data.CarWeapons.default
    else
      tData[#Weapons] = gData.data.CarWeapons[symbol(tData.Weapons)]
    end if
  end if
  if voidp(tData[#settings]) = 1 then
    if voidp(gData.data.carsettings[symbol(tCarName)]) = 1 then
      tData[#settings] = gData.data.carsettings.default.duplicate()
    else
      tData[#settings] = gData.data.carsettings[symbol(tCarName)].duplicate()
    end if
  else
    if voidp(gData.data.carsettings[symbol(tData.settings)]) = 1 then
      tData[#settings] = gData.data.carsettings.default.duplicate()
    else
      tData[#settings] = gData.data.carsettings[symbol(tData.settings)].duplicate()
    end if
  end if
  tCarName = tData.car
  tChassisName = string(tController) & tNr & tCarName
  tReturnList = [#CarName: tCarName, #model: VOID, #Proxy: VOID, #shadowmodel: VOID, #modelList: [], #data: [:], #effectList: [:]]
  if (tController = #player) and (gGame.UPUnlockableCheats.getPos(#UnlimitedHealth) <> 0) then
    tData.personality.Health = 500000
  end if
  tData.personality[#origHealth] = tData.personality.Health
  tData.personality.Health = tData.personality.Health + (tData.upgrades.armor[1] * gGame.HealthUpgrade)
  tData.settings[#origMaxSpeed] = tData.settings.maxSpeed
  tData.settings[#origaccGain] = tData.settings.accGain
  tData.settings[#origdecGain] = tData.settings.decGain
  tSpeedMS = float(gGame.EngineUpgrade[1]) * 1000.0 / 3600.0
  tData.settings.maxSpeed = tData.settings.maxSpeed + (tData.upgrades.engine[1] * tSpeedMS)
  tData.settings.accGain = tData.settings.accGain + (tData.upgrades.engine[1] * gGame.EngineUpgrade[2])
  tData.settings.decGain = tData.settings.decGain + (tData.upgrades.engine[1] * gGame.EngineUpgrade[3])
  tData.settings[#origTurnGain] = tData.settings.turnGain
  tData.settings.turnGain = min(1.75, tData.settings.turnGain + (tData.upgrades.handling[1] * gGame.HandlingUpgrade))
  tCarMember = member(tData.car)
  if tCarMember = VOID then
    return tReturnList
  end if
  gGame[#setupCar] = tCarName
  gGame[#setupSkin] = tData.skin
  if voidp(gData.Events[symbol("Setup" & tCarName)]) = 0 then
    event(0, symbol("Setup" & tCarName))
  else
    event(0, #setupCar)
  end if
  gGame.deleteProp(#setupCar)
  gGame.deleteProp(#setupSkin)
  tModelList = [tCarName, tCarName & "Proxy", tCarName & "Glass", tCarName & "Wheel_LB", tCarName & "Wheel_RB", tCarName & "Wheel_RF", tCarName & "Wheel_LF", tCarName & "FrontLights", tCarName & "RearLights"]
  if tCarName = "Apache" then
    tModelList = AddToModelList(0, tModelList, ["ApacheTopRotor", "ApacheBackRotor"])
  end if
  if tCarName = "Spitfire" then
    tModelList = AddToModelList(0, tModelList, ["SpitfireRotor"])
  end if
  if tCarName = "F22" then
    tModelList = AddToModelList(0, tModelList, ["F22Engine1", "F22Engine2"])
  end if
  if tCarName = "AC130" then
    tModelList = AddToModelList(0, tModelList, ["AC130Rotor1", "AC130Rotor2", "AC130Rotor3", "AC130Rotor4"])
  end if
  tModelList = CloneModel(0, tmember.name, [#sourceMember: tCarName, #model: tModelList, #NameTag: string(tController) & tNr, #shaderTag: string(tController) & tNr, #textureTag: string(tController) & tNr, #lod: 0])
  tmodel = tModelList[1]
  tProxy = tModelList[2]
  tLightModelList = []
  tRotorModelList = []
  repeat with i in tModelList
    if i.name contains "Lights" then
      tLightModelList.add(i)
    end if
    if i.name contains "Rotor" then
      tRotorModelList.add(i)
    end if
    if (i = tmodel) or (i = tProxy) then
      next repeat
      next repeat
    end if
    if i.name contains "Wheel" then
      next repeat
    end if
    i.transform = tmodel.getWorldTransform().inverse() * i.transform
    i.parent = tmodel
  end repeat
  tShadowResource = tmember.modelResource("SimpleShadow")
  if tShadowResource = VOID then
    CloneModel(0, tmember.name, [#sourceMember: "SimpleShadow"])
    tmember.deleteModel("SimpleShadow")
    tmember.deleteShader("SimpleShadow_Material")
  end if
  tShadowResource = tmember.modelResource("SimpleShadow")
  tShadowModel = tmember.newModel(tChassisName & "Shadow", tShadowResource)
  if voidp(gGame.ShadowScale[symbol(tCarName)]) = 0 then
    tShadowModel.transform.scale = vector(1, 1, 1) * gGame.ShadowScale[symbol(tCarName)]
  else
    tShadowModel.transform.scale = vector(1, 1, 1) * (tmodel.boundingSphere[2] * 1.39999999999999991)
  end if
  tShadowModel.transform.position = vector(0, 0, 0.01)
  tShadowShader = CreateShader(0, tmember.name, [#shader: tChassisName & "Shadow_Material", #texture: tCarName & "Shadow_Texture", #blend: 85.0])
  tShadowShader.diffuse = rgb(0, 0, 0)
  tShadowShader.ambient = rgb(0, 0, 0)
  tShadowShader.useDiffuseWithTexture = 1
  tShadowModel.shaderList = tShadowShader
  if tmember.texture(tCarName & "Shadow_Texture") <> VOID then
    tmember.texture(tCarName & "Shadow_Texture").renderFormat = #rgba8888
  end if
  tModelList.add(tShadowModel)
  tGlassModel = tmember.model(string(tController) & tNr & tCarName & "Glass")
  if tGlassModel <> VOID then
    tGlassModel.userData.addProp(#parent, tGlassModel.parent)
    tGlassModel.userData.addProp(#transform, tGlassModel.transform.duplicate())
    tReturnList[#glassModel] = tGlassModel
  else
    tGlassModel = #none
  end if
  tWeaponPlacementList = [:]
  tPrimGroup = tCarMember.group(tCarName & "PrimaryWeapon1_Dummy")
  if tPrimGroup <> VOID then
    tNewPrimGroup = tmember.newGroup(tChassisName & "PrimaryWeapon1_Dummy")
    tNewPrimGroup.transform = tPrimGroup.transform
    tNewPrimGroup.transform = tmodel.getWorldTransform().inverse() * tNewPrimGroup.transform
    tNewPrimGroup.transform.scale = vector(1, 1, 1)
    tNewPrimGroup.parent = tmodel
    if tCarName = "MonsterTruck" then
      tNewPrimGroup.rotate(0, 180, 0, #self)
    end if
    tWeaponPlacementList[#primary1] = tNewPrimGroup
  end if
  repeat with i = 1 to 4
    tSecGroup = tCarMember.group(tCarName & "SecondaryWeapon" & i & "_Dummy")
    if tSecGroup <> VOID then
      tNewSecGroup = tmember.newGroup(tChassisName & "SecondaryWeapon" & i & "_Dummy")
      tNewSecGroup.transform = tSecGroup.transform
      tNewSecGroup.transform = tmodel.getWorldTransform().inverse() * tNewSecGroup.transform
      tNewSecGroup.transform.scale = vector(1, 1, 1)
      tNewSecGroup.parent = tmodel
      tWeaponPlacementList[symbol("Secondary" & i)] = tNewSecGroup
    end if
  end repeat
  tEffectlist = [#primary: [], #secondary: [], #smoke: [], #Nitro: []]
  tgroup = tmember.newGroup(tChassisName & "Smoke")
  tgroup.transform.position = tCarMember.model(tCarName).transform.position
  tgroup.parent = tmodel
  tgroup.transform.position = tCarMember.group(tCarName & "Smoke_Dummy").transform.position - tCarMember.model(tCarName).transform.position
  tEffectlist.smoke.add(tgroup)
  repeat with i = 1 to 4
    tDummy = tCarName & "Nitro" & i & "_Dummy"
    if tCarMember.group(tDummy) = VOID then
      exit repeat
    end if
    tgroup = tmember.newGroup(tChassisName & "Nitro" & i & "_Dummy")
    tgroup.parent = tmodel
    tdiff = tCarMember.group(tDummy).transform.position - tCarMember.model(tCarName).transform.position
    tgroup.transform.position = tdiff
    tEffectlist.Nitro.add(tgroup)
  end repeat
  if tmember.modelResource("Nitro") = VOID then
    event(0, #NitroSetup)
    CloneModel(0, tmember.name, [#sourceMember: "Nitro", #lod: 0, #delete: 1])
  end if
  tNitroModels = []
  repeat with i = 1 to tEffectlist.Nitro.count
    tName = tChassisName & "Nitro" & i
    tNitro = tmember.newModel(tName, tmember.modelResource("Nitro"))
    tNitro.shader = tmember.shader("Nitro_Material")
    tNitro.parent = VOID
    tNitroModels.add(tNitro)
  end repeat
  repeat with i in tLightModelList
    i.parent = VOID
  end repeat
  member(tCarName).resetWorld()
  tReturnList = [#vehicleName: tCarName, #model: tmodel, #Proxy: tProxy, #glassModel: tGlassModel, #shadowmodel: tShadowModel, #modelList: tModelList, #nitroModels: tNitroModels, #lightModels: tLightModelList, #rotorModels: tRotorModelList, #data: tData, #effectList: tEffectlist, #weaponPlaceList: tWeaponPlacementList]
  return tReturnList
end

on AddToModelList me, tList, tAddList
  repeat with i in tAddList
    tList.add(i)
  end repeat
  return tList
end

on DeleteVehicle me, tTarget, tDataList
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tIndex = 0
  if tDataList[#index].ilk = #integer then
    tIndex = tDataList.index
  end if
  if tIndex <= gGame.vehicles.count then
    t = gGame.vehicles[tIndex]
  else
    return 0
  end if
  tScript = GetScript(0, EMPTY, [#script: "[PS] Vehicle Shadow Caster"])
  if tScript <> VOID then
    delete tScript
  end if
  tmember = t.general.member
  t.general.States = []
  tData = t.general.data.Weapons
  sendSprite(0, symbol("reset_" & tData.primary), gGame.vehicles[1])
  sendSprite(0, symbol("reset_" & tData.secondary), gGame.vehicles[1])
  gGame.Physics.deleteRigidBody(t.Vehicle.RigidBody.name)
  tList = []
  tList.add(t.Vehicle.model)
  tList.add(t.Vehicle.Proxy)
  if t.Vehicle.glassModel <> #none then
    tList.add(t.Vehicle.glassModel)
  end if
  tList.add(t.Vehicle.shadowmodel)
  repeat with i in t.Vehicle.nitroModels
    tList.add(i)
  end repeat
  repeat with i in t.Vehicle.lightModels
    tList.add(i)
  end repeat
  if voidp(t.Vehicle[#wheellist]) = 0 then
    repeat with i in t.Vehicle.wheellist
      tList.add(i)
    end repeat
  end if
  if voidp(t.Vehicle[#SlipParticles]) = 0 then
    repeat with i in t.Vehicle.SlipParticles
      tList.add(i)
    end repeat
  end if
  if voidp(t.Vehicle[#rotorModels]) = 0 then
    repeat with i in t.Vehicle.rotorModels
      tList.add(i)
    end repeat
  end if
  repeat with i in tList
    if i = VOID then
      next repeat
    end if
    tMName = i.name
    tRName = i.resource.name
    tmember.deleteModel(tMName)
    if tRName = "SimpleShadow" then
      next repeat
    end if
    if tRName contains "nitro" then
      next repeat
    end if
    tmember.deleteModelResource(tRName)
  end repeat
  repeat with i in t.Vehicle.Effects
    repeat with j in i
      tmember.deleteGroup(j.name)
    end repeat
  end repeat
  repeat with i in t.Vehicle.weaponPlaceList
    tmember.deleteGroup(i.name)
  end repeat
  repeat with i in t.Vehicle.shaderList
    tmember.deleteShader(i.name)
  end repeat
  if voidp(t.Vehicle[#smoke]) = 0 then
    if t.Vehicle[#smoke] <> VOID then
      tResourceName = t.Vehicle.smoke.resource.name
      tName = t.Vehicle.smoke.name
      gGame.member.deleteModel(tName)
      gGame.member.deleteModelResource(tResourceName)
    end if
  end if
  if voidp(t.Vehicle[#group]) = 0 then
    tmember.deleteGroup(t.Vehicle.group.name)
  end if
  tString = string(t.general.controller) & string(t.general.player)
  tList = []
  repeat with i = 1 to tmember.texture.count
    tTexture = tmember.texture[i]
    if tTexture.name contains tString then
      tList.add(tTexture)
    end if
  end repeat
  repeat with i in tList
    tmember.deleteTexture(i.name)
  end repeat
  if voidp(t.Vehicle[#wakeEffect]) = 0 then
    repeat with i in t.Vehicle.wakeEffect.wakes
      tmember.deleteModel(i.model.name)
      tmember.deleteShader(i.shader.name)
    end repeat
    tName = t.Vehicle.wakeEffect.Main.name
    tmember.deleteModel(tName)
    repeat with i in t.Vehicle.waterParticles
      tRName = i.resource.name
      tName = i.name
      tmember.deleteModelResource(tRName)
      tmember.deleteModel(tName)
    end repeat
  end if
  if t.race.Leader.ilk = #group then
    tmember.deleteGroup(t.race.Leader.name)
  end if
  if t.race.ResetGroup.ilk = #group then
    tmember.deleteGroup(t.race.ResetGroup.name)
  end if
  ClearMixers()
  gGame.camera[1].target = "World"
  delete t.general.script
end

on RespawnVehicleTimeOut tTag, tTimeOut
  RespawnVehicle(0, EMPTY, [#tag: tTag])
  tTimeOut.forget()
end

on RespawnVehicle me, tTarget, tDataList
  PutMessage(0, "--> RespawnVehicle")
  if voidp(gGame[#RaceResult]) = 0 then
    return 0
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  t = #none
  if tDataList[#index].ilk = #integer then
    if tDataList.index <= gGame.vehicles.count then
      t = gGame.vehicles[tDataList.index]
    end if
  end if
  if tDataList[#tag].ilk = #symbol then
    if voidp(gGame.vehicles[tDataList.tag]) = 0 then
      t = gGame.vehicles[tDataList.tag]
    end if
  end if
  if t = #none then
    return 0
  end if
  if t.race.state <> #dead then
    return 0
  end if
  tmember = t.general.member
  tPhysics = gGame.Physics
  tController = t.general.controller
  t.race.state = #none
  t.Vehicle.Health = t.general.data.personality.Health
  t.general.States = t.general.origStates.duplicate()
  if gGame.Scene = "World" then
  end if
  if gGame.Scene = "Track" then
  end if
  t.Vehicle.model.visibility = #front
  tPhysics.deleteRigidBody(t.Vehicle.model.name)
  if t.Vehicle.glassModel <> #none then
    t.Vehicle.glassModel.parent = t.Vehicle.glassModel.userData.parent
    t.Vehicle.glassModel.transform = t.Vehicle.glassModel.userData.transform.duplicate()
    tPhysics.deleteRigidBody(t.Vehicle.glassModel.name)
  end if
  if voidp(t.Vehicle[#wheellist]) = 0 then
    repeat with i in t.Vehicle.wheellist
      tPhysics.deleteRigidBody(i.name)
    end repeat
  end if
  repeat with i = 2 to t.Weapons.count
    tData = t.Weapons[i]
    if tData.models = #none then
      next repeat
    end if
    repeat with j in tData.models
      j.transform = j.userData.transform
      j.parent = j.userData.parent
      tPhysics.deleteRigidBody(j.name)
    end repeat
  end repeat
  if voidp(t.Vehicle[#impacts]) = 0 then
    t.Vehicle.impacts = []
  end if
  if gGame.Scene = "World" then
    t.general.script.reset(t, 0, 0)
  else
    t.general.script.reset(t, 1, 0)
  end if
end

on AddCarScript me, tTarget, tDataList
  if gGame.car = "Autobot" then
    tScript = script("[PS] Autobot").new([#member: "World" & gGame.world, #ScriptName: "PlayerCar", #controller: #player, #States: gGame.PlayerStatesAutobot.duplicate()])
  else
    tScript = script("[PS] Advanced Car").new([#member: "World" & gGame.world, #ScriptName: "PlayerCar", #controller: #player, #States: gGame.PlayerStatesCar.duplicate()])
  end if
  tPos = gGame.scriptList.getPos(GetScript(0, EMPTY, [#script: "Camera1"]))
  gGame.scriptList.addAt(tPos, tScript)
  if gGame.ShowMore then
    gGame.camera[1].camera.yon = 1500.0
  else
    gGame.camera[1].camera.yon = 500.0
  end if
  if gGame.Effects = #low then
    TurnOffCarEffects()
  end if
  AddScript(0, EMPTY, [#script: "[PS] Vehicle Shadow Caster", #data: [#member: "World" & gGame.world, #light: "Sun", #tag: gGame.vehicles.count]])
  t = gGame.vehicles[1]
  tShaderList = t.Vehicle.shaderList
  repeat with i in tShaderList
    if i.name contains "Proxy" then
      next repeat
    end if
    if i.name contains "Light" then
      next repeat
    end if
    if i.name contains "Shadow" then
      next repeat
    end if
    i.ambient = rgb(255, 255, 255)
    i.emissive = gData.data.ambientStyle[symbol("World" & gGame.world & gGame.setting)].emissive
  end repeat
end

on UpdateBoatData me
  gData.data.car.PlayerBoat = [#car: gGame.Boat, #skin: 1, #upgrades: gGame.Boat, #Weapons: gGame.Boat, #personality: gGame.Boat, #settings: gGame.Boat]
end

on AddBoatScript me, tTarget, tDataList
  tScript = script("[PS] Boat").new([#member: gGame.member.name, #ScriptName: "PlayerBoat", #controller: #player, #States: gGame.PlayerStatesBoat])
  tPos = gGame.scriptList.getPos(GetScript(0, EMPTY, [#script: "Camera1"]))
  gGame.scriptList.addAt(tPos, tScript)
  if gGame.ShowMore then
    gGame.camera[1].camera.yon = 1500.0
  else
    gGame.camera[1].camera.yon = 500.0
  end if
  if gGame.Effects = #low then
    TurnOffBoatEffects()
  end if
  t = gGame.vehicles[1]
  tShaderList = t.Vehicle.shaderList
  repeat with i in tShaderList
    if i.name contains "Proxy" then
      next repeat
    end if
    if i.name contains "Light" then
      next repeat
    end if
    if i.name contains "Shadow" then
      next repeat
    end if
    i.ambient = rgb(255, 255, 255)
    i.emissive = gData.data.ambientStyle[symbol("World" & gGame.world & gGame.setting)].emissive
  end repeat
end

on AddHelicopterScript me, tTarget, tDataList
  tScript = script("[PS] Helicopter").new([#member: gGame.member.name, #ScriptName: "PlayerHelicopter", #controller: #player, #States: gGame.PlayerStatesHelicopter])
  tPos = gGame.scriptList.getPos(GetScript(0, EMPTY, [#script: "Camera1"]))
  gGame.scriptList.addAt(tPos, tScript)
  gGame.camera[1].camera.yon = 1500.0
  if gGame.Effects = #low then
    TurnOffHelicopterEffects()
  end if
  t = gGame.vehicles[1]
  tShaderList = t.Vehicle.shaderList
  repeat with i in tShaderList
    if i.name contains "Proxy" then
      next repeat
    end if
    if i.name contains "Light" then
      next repeat
    end if
    if i.name contains "Shadow" then
      next repeat
    end if
    i.ambient = rgb(255, 255, 255)
    i.emissive = gData.data.ambientStyle[symbol("World" & gGame.world & gGame.setting)].emissive
  end repeat
end
