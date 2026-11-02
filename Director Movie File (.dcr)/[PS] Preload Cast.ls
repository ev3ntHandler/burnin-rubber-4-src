-- [Script] [PS] Preload Cast (Script #6112)
-- Script Type: Parent

property p

on new me, tDataList
  p = [:]
  p[#ScriptName] = "[PS] Preload Cast"
  p[#state] = #Downloading
  p[#data] = tDataList.data
  p[#cast] = tDataList.data.cast
  p[#url] = _movie.path & tDataList.data.loc
  p[#NetID] = preloadNetThing(p.url)
  p[#error] = "No Error"
  p[#event] = tDataList.event
  p[#Percentage] = 0
  p[#memberList] = []
  if member("[PS] Game Progress") <> VOID then
    p[#script] = script("[PS] Game Progress").new([#event: #none, #command: #none, #totalCommands: 1, #currentCommand: 0, #tag: #cast])
  else
    p[#script] = script("[PS] Default Progress").new([#event: #none, #command: #none, #totalCommands: 1, #currentCommand: 0, #tag: #cast])
  end if
  p[#me] = me
  return me
end

on stepFrame me
  if p.state = #Downloading then
    tData = getStreamStatus(p.NetID)
    if tData.bytesTotal <> 0 then
      p.Percentage = float(tData.bytesSoFar) / float(tData.bytesTotal)
    end if
    if p.script <> VOID then
      p.script.UpdateVisuals(p.Percentage)
    end if
    if (netDone(p.NetID) = 1) and (netError(p.NetID) = "OK") then
      me.DownloadDone(1)
    else
      if netError(p.NetID) <> EMPTY then
        p.error = GetNetIDError(0, netError(p.NetID))
        me.DownloadDone(0)
      end if
    end if
  end if
  if p.state = #PReloading then
    tList = p.memberList.duplicate()
    tCount = tList.count
    repeat with i = 1 to tCount
      tmember = tList[i]
      if tmember.state = 4 then
        p.memberList.deleteOne(tmember)
      end if
    end repeat
    if p.memberList.count = 0 then
      me.DownloadDone(1)
    end if
  end if
end

on DownloadDone me, tState
  if tState = 1 then
    if p.state = #PReloading then
      p.state = #done
      if p.script <> VOID then
        delete p.script
      end if
      _movie.actorList.deleteOne(p.me)
      event(0, p.event)
    end if
    if p.state = #Downloading then
      PutMessage(0, "-->" && p.cast & " was downloaded succesfull. URL was: " & p.url)
      _movie.castLib(p.cast).fileName = p.url
      p.data.state = 1
      p.state = #PReloading
      p.memberList = me.Get3DMembers(p.cast)
    end if
  else
    PutMessage(0, "-->" && p.cast & " was not downloaded. URL was: " & p.url & " Error was: " & p.error, [#type: #alert])
    _movie.actorList.deleteOne(p.me)
  end if
end

on AbortDownload me
  netAbort(p.NetID)
  _movie.actorList.deleteOne(p.me)
end

on returnPercentage me
  return p.Percentage
end

on Get3DMembers me, tCast
  tList = []
  tCount = _movie.castLib(tCast).member.count
  repeat with i = 1 to tCount
    tmember = _movie.castLib(tCast).member[i]
    if tmember.type = #shockwave3d then
      tmember.preload()
      tList.add(tmember)
    end if
  end repeat
  return tList
end
