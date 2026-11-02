-- [Script] [M] Vehicle Car States (Script #5873)
-- Script Type: Movie

global gSystem, gData, gGame, gSound

on setup_CarEffects me, t
  t.Vehicle[#SlipParticles] = []
  tCount = t.Vehicle.wheellist.count
  repeat with i = 1 to tCount
    tWheel = t.Vehicle.wheellist[i]
    tPart = CreateParticleSystem(0, t.general.member.name, [#type: symbol("Wheel" & i)])
    tPart.resource.colorRange.start = gData.data.ambientStyle[gGame.trackInfo.ambientStyle].lightColor
    tPart.resource.colorRange.end = gData.data.ambientStyle[gGame.trackInfo.ambientStyle].lightColor
    tPart.resource.blendRange.start = 0
    tPart.resource.blendRange.end = 0
    t.Vehicle.SlipParticles.add(tPart)
  end repeat
end

on update_CarEffects me, t
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
  tList = [1, 2, 3, 4]
  tRandomList = []
  repeat with i = 1 to 4
    tRandomPos = tList[random(1, tList.count)]
    tRandomList.add(tRandomPos)
    tList.deleteOne(tRandomPos)
  end repeat
  tCount = t.Vehicle.SlipParticles.count
  tColor = rgb(255, 255, 255)
  if voidp(t.Vehicle[#LMColor]) = 0 then
    tColor = t.Vehicle.LMColor
  end if
  repeat with i = 1 to tCount
    tResource = t.Vehicle.SlipParticles[i].resource
    tBlend = tResource.blendRange.start
    if (t.Input.brake = 1) and (t.Vehicle.Hovering = 1) then
      if (t.Input.left = 1) or (t.Input.right = 1) then
        tPerc = abs(t.Vehicle.Speed) / (t.Vehicle.maxSpeed * 0.69999999999999996)
        tTargetBlend = min(100, integer(tPerc * 100))
        if tBlend < tTargetBlend then
          tBlend = tBlend + (6 * tPerc)
        else
          if tBlend > tTargetBlend then
            tBlend = tBlend - 6
          end if
        end if
        tBlend = max(0, min(100, tBlend))
      else
        if tBlend > 0 then
          tBlend = tBlend * 0.80000000000000004
        end if
      end if
    else
      if tBlend > 0 then
        tBlend = tBlend * 0.80000000000000004
      end if
    end if
    tResource.emitter.region = [t.Vehicle.wheellist[tRandomList[i]].worldPosition]
    tResource.colorRange.start = tColor + color(40, 40, 40)
    tResource.colorRange.end = tColor + color(40, 40, 40)
    tResource.blendRange.start = tBlend
  end repeat
  if (t.Input.Lights = 1) and (t.Vehicle.Lights = 0) then
    tParent = t.Vehicle.lightModels[1].parent
    if tParent = VOID then
      tState = 1
    else
      tState = 0
    end if
    repeat with i in t.Vehicle.lightModels
      if tState = 0 then
        i.parent = VOID
        next repeat
      end if
      i.parent = t.Vehicle.model
    end repeat
    t.Vehicle.Lights = 1
  end if
  if (t.Input.Lights = 0) and (t.Vehicle.Lights = 1) then
    t.Vehicle.Lights = 0
  end if
  if (t.Input.horn = 1) and (t.Vehicle.horn = 0) then
    PlaySound(0, "Horn_SFX", [#Override: 1, #priority: #low])
    t.Vehicle.horn = 1
  end if
  if (t.Input.horn = 0) and (t.Vehicle.horn = 1) then
    t.Vehicle.horn = 0
  end if
end

on reset_CarEffects me, t
  repeat with i in t.Vehicle.nitroModels
    i.parent = VOID
  end repeat
  repeat with i in t.Vehicle.SlipParticles
    i.parent = VOID
  end repeat
  if voidp(t.Vehicle[#lightModels]) = 0 then
    repeat with i in t.Vehicle.lightModels
      i.parent = VOID
    end repeat
  end if
  t.general.States.deleteOne(#update_CarEffects)
end

on TurnOffVehicleEffects me
  PutMessage(0, "TurnOffVehicleEffects (Handler)")
  if gGame.Vehicle = "Car" then
    if gGame.car = "Autobot" then
      nothing()
    else
      TurnOffCarEffects()
    end if
  end if
  if gGame.Vehicle = "Boat" then
    TurnOffBoatEffects()
  end if
  if gGame.Vehicle = "Helicopter" then
    TurnOffHelicopterEffects()
  end if
end

on TurnOnVehicleEffects me
  PutMessage(0, "TurnOnVehicleEffects (Handler)")
  if gGame.Vehicle = "Car" then
    if gGame.car = "Autobot" then
      nothing()
    else
      TurnOnCarEffects()
    end if
  end if
  if gGame.Vehicle = "Boat" then
    TurnOnBoatEffects()
  end if
  if gGame.Vehicle = "Helicopter" then
    TurnOnHelicopterEffects()
  end if
end

on TurnOnCarEffects me
  PutMessage(0, "TurnOnCarEffects (Handler)")
  t = gGame.vehicles[1]
  if t.general.States.getPos(#update_CarEffects) = 0 then
    t.general.States.add(#update_CarEffects)
  end if
  repeat with i in t.Vehicle.SlipParticles
    i.parent = t.general.member.group("World")
  end repeat
end

on TurnOffCarEffects me
  PutMessage(0, "TurnOffCarEffects (Handler)")
  reset_CarEffects(0, gGame.vehicles[1])
end

on TurnOnBoatEffects me
  PutMessage(0, "TurnOnBoatEffects (Handler)")
  t = gGame.vehicles[1]
  if t.general.States.getPos(#update_boatEffects) = 0 then
    t.general.States.add(#update_boatEffects)
  end if
  repeat with i in t.Vehicle.wakeEffect.wakes
    i[1].parent = t.general.member.group("World")
  end repeat
  repeat with i in t.Vehicle.waterParticles
    i.parent = t.general.member.group("World")
  end repeat
end

on TurnOffBoatEffects me
  PutMessage(0, "TurnOffBoatEffects (Handler)")
  reset_boatEffects(0, gGame.vehicles[1])
end

on TurnOnHelicopterEffects me
  PutMessage(0, "TurnOnHelicopterEffects (Handler)")
  t = gGame.vehicles[1]
  if t.general.States.getPos(#update_HelicopterEffects) = 0 then
    t.general.States.add(#update_HelicopterEffects)
  end if
end

on TurnOffHelicopterEffects me
  PutMessage(0, "TurnOffHelicopterEffects (Handler)")
  reset_HelicopterEffects(0, gGame.vehicles[1])
end

on setup_CarSound me, t
  t[#sound] = [:]
  t.sound[#Mixer] = CreateMixer()
  t.sound.Mixer.bufferSize = 80
  t.sound[#channel] = gSound.DataSoundChannels.count + 1
  t.sound[#rate] = 1.0
  if t.Vehicle.name = "Tank" then
    t.sound[#engine] = t.sound.Mixer.createSoundObject("CarStationair", member("TankEngine_SFX"), [#loopCount: 0])
  else
    t.sound[#engine] = t.sound.Mixer.createSoundObject("CarStationair", member("CarStationair_SFX"), [#loopCount: 0])
  end if
  t.sound.engine.volume = 0
  t.sound[#filter] = audioFilter(#PitchShiftFilter, [#Shift: t.sound.rate])
  t.sound.engine.filterList.append(t.sound.filter)
  tSoundSet = [member("CarAsphalt_SFX"), member("CarSkid_SFX")]
  t.sound[#Ground] = t.sound.Mixer.createSoundObject("CarGround", tSoundSet[1], [#loopCount: 0])
  t.sound.Ground.volume = 0
  t.sound[#slip] = t.sound.Mixer.createSoundObject("CarSkid", tSoundSet[2], [#loopCount: 0, #loopStartTime: 135, #loopEndTime: tSoundSet[2].duration - 135])
  t.sound.slip.volume = 0
  t.sound.Mixer.play()
  if gSound.mute = 1 then
    t.sound.Mixer.mute()
    repeat with i in t.sound.Mixer.getSoundObjectList()
      i.mute()
    end repeat
  end if
  sound(t.sound.channel).volume = 255
end

on update_CarSound me, t
  if gSound.mute = 1 then
    sound(t.sound.channel).volume = 0
    return 0
  end if
  tDistance = t.camera.distanceToTarget[t.camera.index]
  tLeft = LeftOrRight(0, t.Vehicle.transform, gGame.camera[t.camera.index].transform)
  tPan = tLeft[2]
  tPan = max(-1.0, min(1.0, tPan))
  sound(t.sound.channel).pan = tPan
  if tDistance < 10.0 then
    tVolume = 200
  else
    tVolume = 200 - integer(200 * tDistance / 100.0)
    tVolume = max(0, min(200, tVolume))
  end if
  if sound(t.sound.channel).volume <> tVolume then
    sound(t.sound.channel).volume = tVolume
  end if
  if t.sound.engine.volume <> 164 then
    t.sound.engine.volume = 164
  end if
  tRate = 1.0 + (t.Vehicle.SpeedPerc * 1.69999999999999996)
  tRate = max(1.0, min(tRate, 5.0))
  if t.sound.filter.Shift <> tRate then
    t.sound.filter.Shift = tRate
  end if
  if t.Vehicle.Hovering = 1 then
    tVolume = integer(255 * t.Vehicle.SpeedPerc)
  else
    tVolume = 0
  end if
  if t.sound.Ground.volume <> tVolume then
    t.sound.Ground.volume = tVolume
  end if
  if (t.Vehicle.Hovering = 1) and (t.Input.brake = 1) then
    tVolume = 200 * t.Vehicle.SpeedPerc
  else
    tVolume = 0
  end if
  if t.sound.slip.volume <> tVolume then
    t.sound.slip.volume = tVolume
  end if
  if gSound.mute = 1 then
    sound(t.sound.channel).volume = 0
  end if
end

on reset_CarSound me, t
  put "--> reset_sound (handler)"
  t.sound.Mixer.mute()
  repeat with i in t.sound.Mixer.getSoundObjectList()
    i.mute()
  end repeat
  t.general.States.deleteOne(#update_CarSound)
end

on StopPlayerMixer me
  if voidp(gGame[#vehicles]) = 1 then
    return 0
  end if
  if gGame.vehicles.count = 0 then
    return 0
  end if
  if voidp(gGame[#vehicles][1][#sound]) = 1 then
    return 0
  end if
  gGame.vehicles[1].sound.Mixer.stop()
end

on StartPlayerMixer me
  if voidp(gGame[#vehicles]) = 1 then
    return 0
  end if
  if gGame.vehicles.count = 0 then
    return 0
  end if
  if voidp(gGame[#vehicles][1][#sound]) = 1 then
    return 0
  end if
  gGame.vehicles[1].sound.Mixer.play()
end

on setup_CarSoundAI me, t
  t[#sound] = [:]
  t.sound[#Mixer] = CreateMixer()
  t.sound.Mixer.bufferSize = 200
  t.sound[#channel] = gSound.DataSoundChannels.count + 1
  t.sound.Mixer.play()
  if gSound.mute = 1 then
    t.sound.Mixer.mute()
    repeat with i in t.sound.Mixer.getSoundObjectList()
      i.mute()
    end repeat
  end if
  sound(t.sound.channel).volume = 255
end

on update_CarSoundAI me, t
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
end

on reset_CarSoundAI me, t
  t.sound.Mixer.mute()
  repeat with i in t.sound.Mixer.getSoundObjectList()
    i.mute()
  end repeat
  t.general.States.deleteOne(#update_CarSoundAI)
end
