-- [Script] [PS] Shockwave Sitelock (Script #5852)
-- Script Type: Parent

property p

on new me
  p = [:]
  if (_player.runMode contains "author") or (_player.runMode contains "projector") or (_movie.path contains "xform") then
    put "[MESSAGE]" & TAB & "This movie runs either in Author/Projector mode OR runs online on the Xform server. Sitelock skipped."
    startMovieActual()
    return 0
  else
    p[#Premium] = 0
    p[#NetID] = 0
    p[#progress] = 0
    p[#CurrentTry] = 0
    p[#maxTries] = 5
    p[#startTime] = the milliSeconds
    p[#MaxTime] = 10 * 1000
    p[#TimeoutID] = string(me)
    p[#token] = VOID
    p[#Keyword] = "www"
    p[#Domain] = "www.shockwave.com"
    p[#Subdomain] = "www."
    p[#error] = 0
    me.parseTag()
    me.parseDomain()
    if p.error = 1 then
      me.delete(#Fail)
    else
      p[#url] = "http://" & p.Subdomain & "shockwave.com/contentPlay/validateToken.jsp?token=" & p.token
      me.Try()
    end if
  end if
  return me
end

on stepFrame me
end

on delete me, tState
  if tState = #success then
    put "[MESSAGE]" & TAB & "This movie runs on Shockwave.com and checks out."
    _movie.updateStage()
    (the stage).bgColor = (the stage).bgColor
    startMovieActual()
  else
    put "[ALERT]" & TAB & "This movie does not run on Shockwave.com OR could not be checked."
    gotoNetPage("http://www.shockwave.com/gamelanding/" & p.Keyword & ".jsp")
  end if
  _movie.actorList.deleteOne(me)
end

on parseTag me
  if externalParamName("sw8") = "sw8" then
    p.token = externalParamValue("sw8")
  else
    p.error = 1
  end if
  if externalParamName("sw9") = "sw9" then
    p.Keyword = externalParamValue("sw9")
  else
    p.Keyword = "www"
  end if
end

on parseDomain me
  id = the itemDelimiter
  str = ".shockwave.com"
  MP = the moviePath
  the itemDelimiter = "/"
  p.Domain = MP.item[3]
  the itemDelimiter = "."
  n = the number of items in p.Domain
  if n <= 2 then
    p.Subdomain = "www."
  else
    tSubdomain = EMPTY
    repeat with i = 1 to n - 2
      put p.Domain.item[i] & "." after tSubdomain
    end repeat
    p.Subdomain = tSubdomain
  end if
  the itemDelimiter = id
end

on Try me
  p.CurrentTry = p.CurrentTry + 1
  if p.CurrentTry > p.maxTries then
    me.delete(#Fail)
    exit
  end if
  p.NetID = getNetText(p.url)
  timeout().new(p.TimeoutID, 50, #Monitor, me)
end

on bail me
  timeout(p.TimeoutID).forget()
  me.Try()
end

on Monitor me
  ct = the milliSeconds
  if ct > (p.startTime + p.MaxTime) then
    timeout(p.TimeoutID).forget()
    p.Premium = 0
    me.delete(#Fail)
    exit
  end if
  if netDone(p.NetID) then
    timeout(p.TimeoutID).forget()
    if (netError(p.NetID) = "OK") or (netError(p.NetID) = EMPTY) then
      b = integer(netTextResult(p.NetID))
      case b of
        0:
          me.delete(#Fail)
        1:
          me.delete(#success)
        otherwise:
          me.Try()
      end case
    else
      me.Try()
    end if
  else
    DownloadState = getStreamStatus(p.NetID)
    case DownloadState.state of
      "Connecting", "Started", "Complete":
        nothing()
      "InProgress":
        p.progress = DownloadState.bytesSoFar / (DownloadState.bytesTotal + 0.0000000001)
      "Error", "NoInformation":
        me.bail()
    end case
  end if
end
