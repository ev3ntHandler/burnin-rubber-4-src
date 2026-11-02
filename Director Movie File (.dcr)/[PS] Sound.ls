-- [Script] [PS] Sound (Script #6134)
-- Script Type: Parent

property p
global gSound

on new me, tQueueList, tDataList, tChannel
  p = [:]
  p[#channel] = tChannel
  p[#QueueList] = tQueueList
  p[#dataList] = tDataList
  p[#member] = tQueueList[#member]
  p[#priority] = tDataList[#priority]
  p[#surround] = tDataList[#surround]
  p[#sender] = tDataList[#sender]
  p[#timer] = _system.milliSeconds
  p[#Fade] = #none
  p[#StoredVolume] = VOID
  if p.surround = 1 then
    p[#target] = GetReferenceType(0, member(tDataList[#member3DName]), tDataList[#targetName])
    p[#Reference] = GetReferenceType(0, member(tDataList[#member3DName]), tDataList[#referenceName])
    p[#distance] = tDataList[#distance]
    p[#static] = 0
    if tDataList[#static].ilk = #integer then
      p.static = tDataList[#static]
    end if
    if p.static = 1 then
      p[#StaticTransform] = p.target.getWorldTransform().duplicate()
    end if
  end if
  if gSound.mute = 1 then
    setVolume(me, 0.0)
  end if
  if gSound.mute = 0 then
    setVolume(me, p.dataList.volume)
  end if
  if p.surround = 1 then
    setVolume(me, 0.0)
  end if
  sound(p.channel).queue(p.QueueList)
  sound(p.channel).play()
  p[#me] = me
  return me
end

on stepFrame me
  if p.Fade <> #none then
    me.CheckFade()
  end if
  if (p.surround = 1) and (gSound.mute = 0) and (p.Fade = #none) then
    UpdateSurroundSound()
  end if
  if p.QueueList[#loopCount] <> 0 then
    if (_system.milliSeconds - p.timer) >= (p.member.duration * p.QueueList[#loopCount]) then
      StopSound()
    end if
  end if
end

on returnData me
  tList = p.dataList
  tList[#timer] = p.timer
  tList[#elapsedTime] = sound(p.channel).elapsedTime
  return tList
end

on StopSound me, tState
  sound(p.channel).setPlayList([])
  sound(p.channel).stop()
  setVolume(me, 1.0)
  SetPan(me, 0.0)
  gSound.EmptySoundChannels.add(p.channel)
  gSound.soundchannels[p.channel] = VOID
  gSound.DataSoundChannels[p.channel] = VOID
  _movie.actorList.deleteOne(p.me)
  return VOID
end

on deleteSoundInstance me
  me.StopSound()
end

on setVolume me, tVolume
  if tVolume.ilk <> #float then
    if tVolume.ilk = #integer then
      tVolume = abs(float(tVolume))
    end if
    tVolume = max(0.0, min(1.0, tVolume))
  end if
  if p.Fade = #none then
    tVolume = integer(255 * (tVolume * gSound.GeneralVolume))
  end if
  tVolume = max(0, min(255, tVolume))
  sound(p.channel).volume = tVolume
end

on SetPan me, tPan
  if tPan.ilk <> #float then
    if tPan.ilk = #integer then
      tPan = float(tPan)
    end if
    tPan = max(-1.0, min(1.0, tPan))
  end if
  tPan = integer(tPan * 100)
  sound(p.channel).pan = tPan
end

on CheckFade me
  if (p.Fade = #out) and (sound(p.channel).volume = 0) then
    me.StopSound()
  end if
  if (p.Fade = #in) and (sound(p.channel).volume = p.StoredVolume) then
    p.Fade = #none
  end if
  if (p.Fade = #to) and (sound(p.channel).volume = 0) then
    p.Fade = #none
  end if
end

on fadeOut me, tTime
  p.Fade = #out
  sound(p.channel).fadeOut(tTime)
end

on fadeIn me, tTime
  p.Fade = #in
  p.StoredVolume = sound(p.channel).volume
  sound(p.channel).fadeIn(tTime)
end

on fadeTo me, tTime, tVolume
  p.Fade = #to
  tVolume = 255 * integer(tVolume * gSound.GeneralVolume)
  tVolume = max(0, min(255, tVolume))
  p.StoredVolume = tVolume
  sound(p.channel).fadeTo(tVolume, tTime)
end

on UpdateSurroundSound me
  if (p.target = VOID) or (p.Reference = VOID) then
    if p.static = 0 then
      StopSound()
      exit
    end if
  end if
  if p.static = 1 then
    tPos1 = p.StaticTransform.position
  else
    tPos1 = p.target.getWorldTransform().position
  end if
  tPos2 = p.Reference.getWorldTransform().position
  tDistance = tPos1.distanceTo(tPos2)
  tPercentage = abs((tDistance - p.distance[1]) / (p.distance[2] - p.distance[1]))
  if (tDistance >= p.distance[1]) and (tDistance <= p.distance[2]) then
    tVolume = 1.0 - tPercentage
  else
    if tDistance >= p.distance[2] then
      tVolume = 0.0
    end if
    if tDistance <= p.distance[1] then
      tVolume = 1.0
    end if
  end if
  tVOlumeBefore = tVolume
  tVolume = max(0.0, min(1.0, tVolume))
  setVolume(me, tVolume)
  if p.static = 1 then
    tTransform = p.StaticTransform
  else
    tTransform = p.target.transform
  end if
  tLeft = LeftOrRight(0, tTransform, p.Reference.transform)
  tPan = tLeft[2]
  tPan = max(-1.0, min(1.0, tPan))
  SetPan(me, tPan)
end
