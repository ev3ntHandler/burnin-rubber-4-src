-- [Script] [M] Vehicle Autobot States (Script #5877)
-- Script Type: Movie

global gSystem, gData, gGame, gSound

on setup_AutobotEffects me, t
  t.Vehicle[#SlipParticles] = []
end

on update_AutobotEffects me, t
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
  if (t.Input.horn = 1) and (t.Vehicle.horn = 0) then
    PlaySound(0, "Horn_SFX", [#Override: 1, #priority: #low])
    t.Vehicle.horn = 1
  end if
  if (t.Input.horn = 0) and (t.Vehicle.horn = 1) then
    t.Vehicle.horn = 0
  end if
end

on reset_AutobotEffects me, t
  repeat with i in t.Vehicle.nitroModels
    i.parent = VOID
  end repeat
  repeat with i in t.Vehicle.SlipParticles
    i.parent = VOID
  end repeat
  t.general.States.deleteOne(#update_AutobotEffects)
end

on setup_AutobotSound me, t
  t[#sound] = [:]
  t.sound[#Mixer] = CreateMixer()
  t.sound.Mixer.bufferSize = 80
  t.sound[#channel] = gSound.DataSoundChannels.count + 1
  t.sound[#rate] = 1.0
  t.sound[#engine] = t.sound.Mixer.createSoundObject("F22Engine_SFX", member("F22Engine_SFX"), [#loopCount: 0])
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

on update_AutobotSound me, t
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
  if t.sound.engine.volume <> 45 then
    t.sound.engine.volume = 45
  end if
  tRate = max(1.5, t.Vehicle.SpeedPerc * 3.0)
  if t.sound.filter.Shift <> tRate then
    t.sound.filter.Shift = tRate
  end if
end

on reset_AutobotSound me, t
  t.sound.Mixer.mute()
  repeat with i in t.sound.Mixer.getSoundObjectList()
    i.mute()
  end repeat
  t.general.States.deleteOne(#update_AutobotSound)
end

on setup_Autobot me, t
  tgroup = gGame.member.newGroup(string(t.general.tag) & "MainGunHelper")
  t.Weapons.MainGun[#helper] = tgroup
  t.Weapons.MainGun.helper.pointAtOrientation = [vector(0.0, 1.0, 0.0), vector(0.0, 0.0, 1.0)]
  t.general.States.deleteOne(#update_Weapons)
  t.general.States.add(#update_Weapons)
end

on Update_Autobot me, t
  if gGame.Input = 0 then
    exit
  end if
  tTurret = t.Vehicle.model
  tTurret.pointAtOrientation = [vector(0.0, 1.0, 0.0), vector(0.0, 0.0, 1.0)]
  tTransform1 = tTurret.getWorldTransform()
  tTransform2 = gGame.vehicles[1].Vehicle.model.getWorldTransform()
  tPosition = gGame.vehicles[1].Vehicle.model.worldPosition
  tTurret.pointAt(tPosition, vector(0, 0, 1))
  tTargetT = tTurret.getWorldTransform()
  tDistance = tTransform1.position.distanceTo(tTransform2.position)
  if tDistance > 100.0 then
    t.Input.action1 = 0
    t.Input.action2 = 0
  else
    t.Input.action1 = 1
    t.Input.action2 = 1
  end if
  t.Vehicle.Nitro = 1
end

on reset_autobot me, t
  t.general.States.deleteOne(#Update_Autobot)
end
