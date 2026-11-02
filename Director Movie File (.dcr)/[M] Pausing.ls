-- [Script] [M] Pausing (Script #6140)
-- Script Type: Movie

global gGame, gSound

on PauseGame me, tTarget, tDataList
  PutMessage(0, "--> PauseGame (Handler)")
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    tDataList = [#mute: 0]
  end if
  tParticles = 1
  tAnimations = 1
  if tDataList[#Particles].ilk = #integer then
    tParticles = tDataList.Particles
  end if
  if tDataList[#animations].ilk = #integer then
    tAnimations = tDataList.animations
  end if
  if gGame.pause = 0 then
    PutMessage(0, "--> --> PauseGame (Handler) TRUE")
    gGame[#PauseTime] = _system.milliSeconds
    gGame.timeoutList = _movie.timeoutList.duplicate()
    _movie.timeoutList = []
    if tParticles = 1 then
      PauseParticles(0, 1)
    end if
    if tAnimations = 1 then
      PauseAnimations(0, 1)
    end if
    if tDataList[#mute].ilk = #integer then
      if tDataList.mute = 1 then
        MuteGame()
      end if
    end if
    gGame.pause = 1
    event(0, #PauseGame)
    exit
  end if
  if gGame.pause = 1 then
    PutMessage(0, "--> --> PauseGame (Handler) FALSE")
    gGame[#PauseTime] = _system.milliSeconds - gGame.PauseTime
    _movie.timeoutList = gGame.timeoutList.duplicate()
    gGame.timeoutList = []
    if tParticles = 1 then
      PauseParticles(0, 0)
    end if
    if tAnimations = 1 then
      PauseAnimations(0, 0)
    end if
    if tDataList[#mute].ilk = #integer then
      if tDataList.mute = 1 then
        MuteGame()
      end if
    end if
    gGame.pause = 0
    event(0, #UnPauseGame)
    exit
  end if
end

on PauseParticles me, tState
  pCount = gGame.member.modelResource.count
  repeat with i = 1 to pCount
    pResource = gGame.member.modelResource[i]
    if pResource.type = #particle then
      pResource.paused = tState
    end if
  end repeat
end

on PauseAnimations me, tState
  tCount = gGame.member.model.count
  repeat with i = 1 to tCount
    tmodel = gGame.member.model[i]
    tModList = tmodel.modifier
    if tModList.getPos(#bonesPlayer) <> 0 then
      if tState = 1 then
        tmodel.bonesPlayer.pause()
      else
        tmodel.bonesPlayer.play()
      end if
    end if
    if tModList.getPos(#keyframePlayer) <> 0 then
      if tState = 1 then
        tmodel.keyframePlayer.pause()
        next repeat
      end if
      tmodel.keyframePlayer.play()
    end if
  end repeat
end
