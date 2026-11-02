-- [Script] [M] Vehicle Helicopter States (Script #5876)
-- Script Type: Movie

global gSystem, gData, gGame, gSound

on setup_HelicopterEffects me, t
end

on update_HelicopterEffects me, t
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
end

on reset_HelicopterEffects me, t
  repeat with i in t.Vehicle.nitroModels
    i.parent = VOID
  end repeat
  t.general.States.deleteOne(#update_HelicopterEffects)
end

on setup_HelicopterSound me, t
  t[#sound] = [:]
  t.sound[#Mixer] = CreateMixer()
  t.sound.Mixer.bufferSize = 80
  t.sound[#channel] = gSound.DataSoundChannels.count + 1
  t.sound[#rate] = 1.0
  if t.Vehicle.name = "Apache" then
    tSFX = "ApacheEngine_SFX"
  end if
  if t.Vehicle.name = "F22" then
    tSFX = "F22Engine_SFX"
  end if
  if t.Vehicle.name = "Spitfire" then
    tSFX = "SpitfireEngine_SFX"
  end if
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

on update_HelicopterSound me, t
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
end

on reset_HelicopterSound me, t
  t.sound.Mixer.mute()
  repeat with i in t.sound.Mixer.getSoundObjectList()
    i.mute()
  end repeat
  t.general.States.deleteOne(#update_HelicopterSound)
end

on setup_HelicopterSoundAI me, t
end

on update_HelicopterSoundAI me, t
end

on reset_HelicopterSoundAI me, t
  t.general.States.deleteOne(#update_HelicopterSoundAI)
end
