-- [Script] [M] Vehicle Boat States (Script #5874)
-- Script Type: Movie

global gSystem, gData, gGame, gSound

on setup_boatEffects me, t
  t.Vehicle[#wakeEffect] = [:]
  t.Vehicle.wakeEffect[#Current] = 1
  t.Vehicle.wakeEffect[#amount] = 15
  t.Vehicle.wakeEffect[#animSpeed] = 1.0 / t.Vehicle.wakeEffect.amount
  t.Vehicle.wakeEffect[#maxScale] = 2.0
  t.Vehicle.wakeEffect[#wakes] = []
  tmember = t.general.member
  tWake = t.Vehicle.name & "Wake"
  if tmember.modelResource(tWake) = VOID then
    CloneModel(0, tmember, [#sourceMember: t.Vehicle.name, #model: t.Vehicle.name & "Wake", #hide: 1, #delete: 1])
  end if
  tResource = tmember.modelResource(tWake)
  if tResource <> VOID then
    tTexture = tmember.texture(t.Vehicle.name & "Wake_Texture")
    if tTexture = VOID then
      tTexture = createTexture(0, tmember.name, [#texture: t.Vehicle.name & "Wake_Texture", #renderFormat: #rgba8888, #filtering: #lowFiltered])
    end if
    tmodel = tmember.newModel(string(t.general.tag) & "WakeMain", tResource)
    tmodel.transform.scale = vector(1, 1, 1) * 1.19999999999999996
    t.Vehicle.wakeEffect[#Main] = tmodel
    tShader = DuplicateShader(0, tmember.name, [#shader: t.Vehicle.name & "Wake_Material", #shaderTag: string(t.general.tag) & "WakeMain"])
    tShader.texture = tTexture
    tShader.diffuse = gData.data.ambientStyle[gGame.trackInfo.ambientStyle].emissive
    tShader.emissive = gData.data.ambientStyle[gGame.trackInfo.ambientStyle].emissive
    t.Vehicle.wakeEffect.Main.shader = tShader
    repeat with i = 1 to t.Vehicle.wakeEffect.amount
      tmodel = tmember.newModel(string(t.general.tag) & "Wake" & i, tResource)
      tmodel.pointAtOrientation = [vector(0, 0, 1), vector(0, 1, 0)]
      tmodel.transform.scale = vector(1, 1, 1) + (vector(1, 1, 1) * t.Vehicle.wakeEffect.maxScale * (float(i) / t.Vehicle.wakeEffect.amount))
      tShader = DuplicateShader(0, tmember.name, [#shader: t.Vehicle.name & "Wake_Material", #shaderTag: string(t.general.tag) & "Wake" & i])
      tShader.texture = tTexture
      tShader.diffuse = gData.data.ambientStyle[gGame.trackInfo.ambientStyle].emissive
      tShader.emissive = gData.data.ambientStyle[gGame.trackInfo.ambientStyle].emissive
      tmodel.shader = tShader
      tEntry = [#model: tmodel, #shader: tShader, #Anim: (i * t.Vehicle.wakeEffect.animSpeed) - t.Vehicle.wakeEffect.animSpeed]
      t.Vehicle.wakeEffect.wakes.add(tEntry)
    end repeat
  end if
  t.Vehicle[#waterParticles] = []
  t.Vehicle.Effects[#Water] = []
  t.Vehicle[#waterPartCounter] = [1, 2]
  tCount = 2
  repeat with i = 1 to tCount
    tgroup = tmember.newGroup(string(t.general.tag) & "WaterParticle" & i & "_Group")
    tgroup.parent = t.Vehicle.Proxy
    tgroup.transform.position = member(t.Vehicle.name).group(t.Vehicle.name & "Splashes" & i & "_Dummy").worldPosition - member(t.Vehicle.name).model(t.Vehicle.name & "Proxy").worldPosition
    t.Vehicle.Effects.Water.add(tgroup)
    tPart = CreateParticleSystem(0, t.general.member.name, [#type: symbol("Water" & i), #NameTag: string(t.general.tag) & "Water" & i])
    tPart.resource.colorRange.start = gData.data.ambientStyle[gGame.trackInfo.ambientStyle].lightColor
    tPart.resource.colorRange.end = gData.data.ambientStyle[gGame.trackInfo.ambientStyle].lightColor
    t.Vehicle.waterParticles.add(tPart)
  end repeat
end

on update_boatEffects me, t
  if t.Vehicle.Nitro = 1 then
    tC = 0
    tTargetScale = t.Vehicle.nitroTargetScale
    if t.Vehicle.nitroModels[1].transform.scale = tTargetScale then
      tRandom = random(100, 130) * 0.01
      tTargetScale = vector(1, 1.39999999999999991, 1) * tRandom
    end if
    repeat with i in t.Vehicle.nitroModels
      tC = tC + 1
      if i.parent = VOID then
        i.parent = t.Vehicle.Effects.Nitro[tC]
      end if
      tStep = (tTargetScale - i.transform.scale) * gGame.TimeMP
      i.transform.scale = i.transform.scale + tStep
    end repeat
  else
    if t.Vehicle.nitroModels[1].parent <> VOID then
      tScale = t.Vehicle.nitroModels[1].transform.scale.z
      tScale = tScale - 0.14999999999999999
      tScale = max(0.001, tScale)
      repeat with i in t.Vehicle.nitroModels
        i.transform.scale = vector(1, 1, 1) * tScale
        if tScale = 0.001 then
          i.parent = VOID
        end if
      end repeat
    end if
  end if
  repeat with i in t.Vehicle.wakeEffect.wakes
    i.Anim = min(1.0, i.Anim + (t.Vehicle.wakeEffect.animSpeed * gGame.TimeMP))
    if i.Anim = 1.0 then
      tState = 1
    else
      tState = 0
    end if
    i.model.transform.scale = vector(1, 1, 1) + (vector(1, 1, 1) * (2.0 * i.Anim))
    i.shader.blend = max(0, integer(100 - (100 * i.Anim)))
    if tState = 1 then
      i.model.transform.position = t.Vehicle.shadowmodel.transform.position
      i.model.transform.rotation = t.Vehicle.shadowmodel.transform.rotation
    end if
    if tState = 1 then
      i.Anim = 0.0
    end if
  end repeat
  tResource = t.Vehicle.waterParticles[1].resource
  t.Vehicle.waterPartCounter = t.Vehicle.waterPartCounter + 1
  if t.Vehicle.waterPartCounter[1] > 2 then
    t.Vehicle.waterPartCounter[1] = 1
  end if
  if t.Vehicle.waterPartCounter[2] > 2 then
    t.Vehicle.waterPartCounter[2] = 1
  end if
  tCount = t.Vehicle.waterParticles.count
  tPerc = min(1.0, max(0.40000000000000002, abs(t.Vehicle.Speed) / (t.Vehicle.maxSpeed * 0.69999999999999996)))
  repeat with i = 1 to tCount
    tResource = t.Vehicle.waterParticles[i].resource
    tBlend = tResource.blendRange.start
    if t.Vehicle.Hovering = 0 then
      tBlend = tBlend * 0.59999999999999998
    else
      tBlend = 100.0
    end if
    tResource.emitter.region = [t.Vehicle.Effects.Water[t.Vehicle.waterPartCounter[i]].worldPosition]
    tResource.blendRange.start = tBlend
    tResource.sizeRange.start = 2.0 * tPerc
    tResource.sizeRange.end = 4.0 * tPerc
  end repeat
end

on reset_boatEffects me, t
  repeat with i in t.Vehicle.nitroModels
    i.parent = VOID
  end repeat
  repeat with i in t.Vehicle.wakeEffect.wakes
    i[1].parent = VOID
  end repeat
  repeat with i in t.Vehicle.waterParticles
    i.parent = VOID
  end repeat
  t.general.States.deleteOne(#update_boatEffects)
end

on setup_BoatSound me, t
  t[#sound] = [:]
  t.sound[#Mixer] = CreateMixer()
  t.sound.Mixer.bufferSize = 80
  t.sound[#channel] = gSound.DataSoundChannels.count + 1
  t.sound[#rate] = 1.0
  tSFX = "SpeedboatEngine_SFX"
  t.sound[#engine] = t.sound.Mixer.createSoundObject(tSFX, member(tSFX), [#loopCount: 0])
  t.sound.engine.volume = 0
  t.sound[#filter] = audioFilter(#PitchShiftFilter, [#Shift: t.sound.rate])
  t.sound.engine.filterList.append(t.sound.filter)
  t.sound.Mixer.play()
  if gSound.mute = 1 then
    t.sound.Mixer.mute()
    repeat with i in t.sound.Mixer.getSoundObjectList()
      i.mute()
    end repeat
  end if
  sound(t.sound.channel).volume = 255
end

on update_BoatSound me, t
  if gSound.mute = 1 then
    return 0
  end if
  tDistance = t.camera.distanceToTarget[t.camera.index]
  tLeft = LeftOrRight(0, t.Vehicle.transform, gGame.camera[t.camera.index].transform)
  tPan = tLeft[2]
  tPan = max(-1.0, min(1.0, tPan))
  sound(t.sound.channel).pan = tPan
  if tDistance < 10.0 then
    tVolume = 255
  else
    tVolume = 255 - integer(255 * tDistance / 100.0)
    tVolume = max(0, min(255, tVolume))
  end if
  if sound(t.sound.channel).volume <> tVolume then
    sound(t.sound.channel).volume = tVolume
  end if
  if t.sound.engine.volume <> 164 then
    t.sound.engine.volume = 164
  end if
  tRate = max(0.25, min(t.Vehicle.SpeedPerc * 1.10000000000000009, 1.0))
  if t.sound.filter.Shift <> tRate then
    t.sound.filter.Shift = tRate
  end if
end

on reset_BoatSound me, t
  t.sound.Mixer.mute()
  repeat with i in t.sound.Mixer.getSoundObjectList()
    i.mute()
  end repeat
  t.general.States.deleteOne(#update_BoatSound)
end

on setup_BoatSoundAI me, t
end

on update_BoatSoundAI me, t
end

on reset_BoatSoundAI me, t
  t.general.States.deleteOne(#update_BoatSoundAI)
end
