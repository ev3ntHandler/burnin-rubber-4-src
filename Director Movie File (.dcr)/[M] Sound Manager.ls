-- [Script] [M] Sound Manager (Script #6133)
-- Script Type: Movie

global gSystem, gSound, gGame

on SetupSoundManager me
  ClearSoundManager()
  gSound = [:]
  gSound[#mute] = 0
  if voidp(gGame[#sound]) = 0 then
    gSound.mute = abs(gGame.sound - 1)
  end if
  gSound[#GeneralVolume] = 1.0
  gSound[#Mixer] = []
  gSound[#streamingMusic] = 1
  gSound[#channelCount] = 16
  gSound[#ChannelList] = []
  repeat with i = 1 to gSound.channelCount
    gSound.ChannelList.add(i)
  end repeat
  gSound[#EmptySoundChannels] = gSound.ChannelList.duplicate()
  if gSound.streamingMusic = 1 then
    gSound.EmptySoundChannels.deleteOne(1)
  end if
  gSound[#ChannelPropList] = [:]
  repeat with i in gSound.ChannelList
    gSound.ChannelPropList[symbol("Channel" & i)] = VOID
  end repeat
  gSound[#soundchannels] = gSound.ChannelPropList.duplicate()
  gSound[#DataSoundChannels] = gSound.ChannelPropList.duplicate()
  repeat with i in gSound.ChannelList
    sound(i).volume = integer(255 * gSound.GeneralVolume)
  end repeat
  the soundDevice = "DirectSound"
end

on ClearSoundManager me
  if voidp(gSound) = 1 then
    exit
  end if
  gSound[#mute] = 0
  gSound[#EmptySoundChannels] = gSound.ChannelList.duplicate()
  repeat with i = 1 to gSound.soundchannels.count
    pChannelData = gSound.soundchannels[i]
    if pChannelData <> VOID then
      if _movie.actorList.getPos(pChannelData) <> VOID then
        _movie.actorList.deleteOne(pChannelData)
      end if
    end if
  end repeat
  ClearMixers()
  gSound[#soundchannels] = gSound.ChannelPropList.duplicate()
  gSound[#DataSoundChannels] = gSound.ChannelPropList.duplicate()
  repeat with i = 1 to gSound.channelCount
    sound(i).volume = 255
    sound(i).pan = 0
  end repeat
end

on MuteSound me
  tState = gGame.sound
  repeat with i = 1 to gSound.channelCount
    if i > gSound.DataSoundChannels.count then
      pDataToCheck = VOID
    else
      pDataToCheck = gSound.DataSoundChannels[i]
    end if
    if pDataToCheck = VOID then
      if tState = 0 then
        tVolume = 0
      else
        tVolume = 255
      end if
      sound(i).volume = tVolume
      next repeat
    end if
    if tState = 0 then
      tVolume = 0.0
    else
      tData = gSound.soundchannels[i].returnData()
      tVolume = tData.volume
    end if
    gSound.soundchannels[i].setVolume(tVolume)
  end repeat
  repeat with i in gSound.Mixer
    repeat with j in i.getSoundObjectList()
      if tState = 0 then
        j.mute()
        next repeat
      end if
      j.unmute()
    end repeat
    if tState = 0 then
      i.mute()
      next repeat
    end if
    i.unmute()
  end repeat
end

on PlaySound me, tSoundName, tDataList
  if tSoundName = VOID then
    LogMessage("Function: PlaySound. SoundName: " & tDataList & " No soundname.")
    exit
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    LogMessage("Function: PlaySound. SoundName: " & tDataList & " No proplist. Function continues with default values.")
    tDataList = [:]
  end if
  pFilename = tSoundName
  pMemberName = pFilename
  if getaProp(tDataList, #random) = VOID then
    pMember = member(pMemberName)
    if pMember = VOID then
      LogMessage("Function: PlaySound. SoundName: " & tDataList & " No such member.")
      exit
    end if
  else
    pRandomData = tDataList[#random]
    if pRandomData.ilk <> #list then
      pRandomData = [1, 1]
    end if
    pRandom = random(pRandomData[1], pRandomData[2])
    pMemberName = pMemberName & pRandom
    pMember = member(pMemberName)
    if pMember = VOID then
      LogMessage("Function: PlaySound. SoundName: " & tDataList & " No such member (based upon random).")
      exit
    end if
  end if
  pQueueList = [#member: pMember, #startTime: 0, #endTime: pMember.duration, #loopCount: 1, #loopStartTime: 0, #loopEndTime: pMember.duration, #preloadTime: 0, #rateShift: 0]
  pDataList = [#priority: #low, #sender: VOID, #random: VOID, #fileName: pFilename, #surround: 0, #member3DName: VOID, #targetName: VOID, #referenceName: VOID, #distance: [10, 90], #static: 0, #Override: 0, #volume: 1.0]
  pQueueList[#member] = pMember
  if getaProp(tDataList, #startTime).ilk = #integer then
    pQueueList[#startTime] = tDataList[#startTime]
  end if
  if getaProp(tDataList, #endTime).ilk = #integer then
    pQueueList[#endTime] = tDataList[#endTime]
  end if
  if getaProp(tDataList, #loopCount).ilk = #integer then
    pQueueList[#loopCount] = tDataList[#loopCount]
  end if
  if getaProp(tDataList, #loopStartTime).ilk = #integer then
    pQueueList[#loopStartTime] = tDataList[#loopStartTime]
  end if
  if getaProp(tDataList, #loopEndTime).ilk = #integer then
    pQueueList[#loopEndTime] = tDataList[#loopEndTime]
  end if
  if getaProp(tDataList, #preloadTime).ilk = #integer then
    pQueueList[#preloadTime] = tDataList[#preloadTime]
  end if
  if getaProp(tDataList, #rateShift).ilk = #integer then
    pQueueList[#rateShift] = tDataList[#rateShift]
  end if
  if getaProp(tDataList, #priority).ilk = #symbol then
    pDataList[#priority] = tDataList[#priority]
  end if
  if getaProp(tDataList, #sender).ilk = #string then
    pDataList[#sender] = tDataList[#sender]
  end if
  if getaProp(tDataList, #random).ilk = #list then
    pDataList[#random] = tDataList[#random]
  end if
  if getaProp(tDataList, #surround).ilk = #integer then
    pDataList[#surround] = tDataList[#surround]
  end if
  if getaProp(tDataList, #member3DName).ilk = #string then
    pDataList[#member3DName] = tDataList[#member3DName]
  end if
  if getaProp(tDataList, #targetName).ilk = #string then
    pDataList[#targetName] = tDataList[#targetName]
  end if
  if getaProp(tDataList, #referenceName).ilk = #string then
    pDataList[#referenceName] = tDataList[#referenceName]
  end if
  if getaProp(tDataList, #distance).ilk = #list then
    pDataList[#distance] = tDataList[#distance]
  end if
  if getaProp(tDataList, #static).ilk = #integer then
    pDataList[#static] = tDataList[#static]
  end if
  if getaProp(tDataList, #Override).ilk = #integer then
    pDataList[#Override] = tDataList[#Override]
  end if
  if getaProp(tDataList, #volume).ilk = #float then
    pDataList[#volume] = tDataList[#volume]
  end if
  if pQueueList[#startTime] <> 0 then
    pQueueList[#loopStartTime] = pQueueList[#startTime]
  end if
  if pDataList[#surround] = 1 then
    pMember3D = member(pDataList[#member3DName])
    if pMember3D = VOID then
      LogMessage("A 3d sound was called, but a member was not specified. Function aborted")
      exit
    end if
  end if
  if pDataList[#Override] = 0 then
    repeat with i = 1 to gSound.soundchannels.count
      pDataToCheck = gSound.DataSoundChannels[i]
      if pDataToCheck = VOID then
        next repeat
      end if
      if (pDataToCheck[#priority] = pDataList[#priority]) and (pDataToCheck[#sender] = pDataList[#sender]) and (pDataToCheck[#fileName] = pDataList[#fileName]) then
        return VOID
      end if
    end repeat
  end if
  pCount = gSound.EmptySoundChannels.count
  if pCount = 0 then
    pChannel = ChannelToReplace(0, pDataList[#priority], pDataList[#fileName])
    if pChannel = #none then
      return VOID
    end if
    gSound.soundchannels[pChannel].StopSound(1)
  else
    pChannel = gSound.EmptySoundChannels[1]
  end if
  pSoundScript = new(script("[PS] Sound"), pQueueList, pDataList, pChannel)
  _movie.actorList.add(pSoundScript)
  gSound.EmptySoundChannels.deleteAt(1)
  gSound.soundchannels[pChannel] = pSoundScript
  gSound.DataSoundChannels[pChannel] = pDataList
  return pSoundScript
end

on StopSound me, tSoundName
  pSoundName = tSoundName
  if (pSoundName = VOID) or (pSoundName.ilk <> #string) then
    LogMessage("Function: StopSound. SoundName: " & tSoundName & " No soundname.")
    exit
  end if
  repeat with i = 1 to gSound.soundchannels.count
    pDataToCheck = gSound.DataSoundChannels[i]
    if pDataToCheck = VOID then
      next repeat
    end if
    if pDataToCheck[#fileName] = tSoundName then
      gSound.soundchannels[i].StopSound()
    end if
  end repeat
end

on StopSoundChannel me, tChannel
  pChannel = tChannel
  if pChannel.ilk = #string then
    pChannel = value(tChannel)
  end if
  if (pChannel = VOID) or (pChannel.ilk <> #integer) then
    LogMessage("Function: StopSoundChannel. SoundName: " & tChannel & " No soundchannel.")
    exit
  end if
  if gSound.soundchannels[pChannel] <> VOID then
    gSound.soundchannels[pChannel].StopSound()
  end if
end

on StopAllSound me, tSoundName, tDataList
  pDataList = value(tDataList)
  if (pDataList = VOID) or (pDataList.ilk <> #propList) then
    LogMessage("Function: StopAllSound. Target: " & tSoundName & " Parameters: " & tDataList & " Datalist obsolete (VOID or not #proplist).")
    pDataList = [:]
  end if
  pException = VOID
  if getaProp(pDataList, #exception).ilk = #string then
    pException = pDataList[#exception]
  end if
  repeat with i = 1 to gSound.soundchannels.count
    pDataToCheck = gSound.DataSoundChannels[i]
    if pDataToCheck = VOID then
      next repeat
      next repeat
    end if
    if pDataToCheck.fileName <> pException then
      gSound.soundchannels[i].StopSound()
    end if
  end repeat
  repeat with i = 1 to gSound.channelCount
    sound(i).volume = 255
    sound(i).stop()
  end repeat
  PList = _movie.actorList.duplicate()
  pCount = PList.count
  repeat with i = 1 to pCount
    pScript = PList[i]
    pHandlers = pScript.handlers()
    if pHandlers.getPos(#deleteSoundInstance) <> 0 then
      pScript.deleteSoundInstance()
    end if
  end repeat
  gSound[#EmptySoundChannels] = gSound.ChannelList.duplicate()
  if gSound.streamingMusic = 1 then
    gSound.EmptySoundChannels.deleteOne(1)
  end if
  ClearMixers()
end

on SetSound me, tSoundName, tDataList
  if gSound.mute = 1 then
    return 0
  end if
  pSoundName = tSoundName
  if (pSoundName = VOID) or (pSoundName.ilk <> #string) then
    LogMessage("Function: SetSound. SoundName: " & tSoundName & " DataList " & tDataList & " No soundname.")
    exit
  end if
  pDataList = value(tDataList)
  if (pDataList = VOID) or (pDataList.ilk <> #propList) then
    LogMessage("Function: SetSound. Target: " & tSoundName & " Parameters: " & tDataList & " Datalist obsolete (VOID or not #proplist).")
    exit
  end if
  pVolume = 1.0
  if getaProp(pDataList, #volume).ilk = #float then
    pVolume = pDataList[#volume]
  end if
  tForce = 0
  if getaProp(pDataList, #force).ilk = #integer then
    tForce = pDataList[#force]
  end if
  repeat with i = 1 to gSound.soundchannels.count
    pDataToCheck = gSound.DataSoundChannels[i]
    if pDataToCheck = VOID then
      next repeat
    end if
    if pDataToCheck[#fileName] = tSoundName then
      gSound.soundchannels[i].setVolume(pVolume, tForce)
    end if
  end repeat
end

on FadeSound me, tSoundName, tDataList
  pSoundName = tSoundName
  if (pSoundName = VOID) or (pSoundName.ilk <> #string) then
    LogMessage("Function: SetSound. SoundName: " & tSoundName & " DataList " & tDataList & " No soundname.")
    exit
  end if
  pDataList = value(tDataList)
  if (pDataList = VOID) or (pDataList.ilk <> #propList) then
    LogMessage("Function: SetSound. Target: " & tSoundName & " Parameters: " & tDataList & " Datalist obsolete (VOID or not #proplist).")
    pDataList = [:]
  end if
  pFadeTime = 1000
  if getaProp(pDataList, #FadeTime).ilk = #integer then
    pFadeTime = pDataList[#FadeTime]
  end if
  pState = 1
  if getaProp(pDataList, #fadeOut).ilk = #integer then
    pState = pDataList[#fadeOut]
  end if
  repeat with i = 1 to gSound.soundchannels.count
    pDataToCheck = gSound.DataSoundChannels[i]
    if pDataToCheck = VOID then
      next repeat
    end if
    if pDataToCheck[#fileName] = tSoundName then
      if pState = 1 then
        gSound.soundchannels[i].fadeOut(pFadeTime)
        next repeat
      end if
      gSound.soundchannels[i].fadeIn(pFadeTime)
    end if
  end repeat
end

on ChannelToReplace me, tPrio, tFileName
  pChannel = VOID
  pLowList = []
  pMedList = []
  pHighList = []
  pTopList = []
  repeat with i = 1 to gSound.soundchannels.count
    pDataToCheck = gSound.DataSoundChannels[i]
    if pDataToCheck = VOID then
      next repeat
    end if
    pData = gSound.DataSoundChannels[i].priority
    if pData = #low then
      pLowList.add(i)
    end if
    if pData = #medium then
      pMedList.add(i)
    end if
    if pData = #high then
      pHighList.add(i)
    end if
    if pData = #top then
      pTopList.add(i)
    end if
  end repeat
  if tPrio = #top then
    pTimeList = GetSortedTimeList(0, pLowList)
    pChannel = GetChannel(0, pTimeList, tFileName)
    if pChannel = #none then
      pTimeList = GetSortedTimeList(0, pMedList)
      pChannel = GetChannel(0, pTimeList, tFileName)
    end if
    if pChannel = #none then
      pTimeList = GetSortedTimeList(0, pHighList)
      pChannel = GetChannel(0, pTimeList, tFileName)
    end if
    return pChannel
  end if
  if tPrio = #high then
    if (pLowList = []) and (pMedList = []) and (pHighList = []) then
      pChannel = #none
      return pChannel
    else
      pTimeList = GetSortedTimeList(0, pLowList)
      pChannel = GetChannel(0, pTimeList, tFileName)
      if pChannel = #none then
        pTimeList = GetSortedTimeList(0, pMedList)
        pChannel = GetChannel(0, pTimeList, tFileName)
      end if
      if pChannel = #none then
        pTimeList = GetSortedTimeList(0, pHighList)
        pChannel = GetChannel(0, pTimeList, tFileName)
      end if
      return pChannel
    end if
  end if
  if tPrio = #medium then
    if (pLowList = []) and (pMedList = []) then
      pChannel = #none
      return pChannel
    else
      pTimeList = GetSortedTimeList(0, pLowList)
      pChannel = GetChannel(0, pTimeList, tFileName)
      if pChannel = #none then
        pTimeList = GetSortedTimeList(0, pMedList)
        pChannel = GetChannel(0, pTimeList, tFileName)
      end if
      return pChannel
    end if
  end if
  if tPrio = #low then
    if pLowList = [] then
      pChannel = #none
      return pChannel
    else
      pTimeList = GetSortedTimeList(0, pLowList)
      pChannel = GetChannel(0, pTimeList, tFileName)
      return pChannel
    end if
  end if
end

on GetSortedTimeList me, tList
  pTimeList = []
  pLongestTime = 0
  pOldestChannel = 0
  pCount = tList.count
  repeat with i = 1 to pCount
    pTime = sound(tList[i]).elapsedTime
    pTimeList.add([pTime, tList[1]])
  end repeat
  pTimeList.sort()
  return pTimeList
end

on GetChannel me, tList, tFileName
  pCount = tList.count
  if pCount = 0 then
    return #none
  end if
  repeat with j = pCount down to 1
    pChannel = tList[j][2]
    if gSound.DataSoundChannels[pChannel].fileName = tFileName then
      if j = 1 then
        return #none
      else
        next repeat
      end if
      next repeat
    end if
    return pChannel
  end repeat
end

on CreateMixer me
  tMixer = new(#Mixer)
  gSound.Mixer.add(tMixer)
  tMixer.name = "DynMixer" & gSound.Mixer.count
  gSystem.DynamicMembers.add(tMixer)
  tNr = gSound.soundchannels.count
  if gSound.soundchannels[tNr] <> VOID then
    gSound.soundchannels[tNr].StopSound()
  end if
  gSound.EmptySoundChannels.deleteOne(tNr)
  gSound.soundchannels.deleteAt(tNr)
  gSound.DataSoundChannels.deleteAt(tNr)
  resetMixer(tMixer)
  tMixer.volume = 0
  tMixer.stop()
  return tMixer
end

on resetMixer me, tMixer
  if tMixer.ilk <> #Mixer then
    exit
  end if
  tMixer.stop()
  tMixer.reset()
  tList = tMixer.getSoundObjectList()
  repeat with i = 1 to tList.count
    tMixer.deleteSoundObject(tList[i].name)
  end repeat
end

on ClearMixers me
  tList = gSound.Mixer.duplicate()
  repeat with i in tList
    resetMixer(i)
    gSound.Mixer.deleteOne(i)
    i.erase()
    tNr = gSound.soundchannels.count + 1
    gSound.soundchannels[symbol("Channel" & tNr)] = VOID
    gSound.DataSoundChannels[symbol("Channel" & tNr)] = VOID
  end repeat
  tList = VOID
end

on MuteGame me
  PutMessage(0, "--> MuteGame (Handler)")
  if gSound.mute = 1 then
    gSound.mute = 0
  else
    gSound.mute = 1
  end if
  if gGame.sound = 1 then
    gGame.sound = 0
  else
    gGame.sound = 1
  end if
  MuteSound()
end
