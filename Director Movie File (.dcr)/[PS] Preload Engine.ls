-- [Script] [PS] Preload Engine (Script #5850)
-- Script Type: Parent

property p

on new me, tDataList
  p = [:]
  if tDataList[#url].ilk = #string then
    p[#url] = tDataList.url
  else
    return VOID
  end if
  p[#NetID] = preloadNetThing(p.url)
  p[#Percentage] = 0
  p[#me] = me
  return me
end

on stepFrame me
  if (netDone(p.NetID) = 1) and (netError(p.NetID) = "OK") then
    DownloadDone(1)
  else
    if netError(p.NetID) <> EMPTY then
      p[#NetIDError] = netError(p.NetID)
      p[#error] = "nothing"
      case p.NetIDError of
        4:
          p.error = "Bad MOA class. The required network or nonnetwork Xtra extensions are improperly installed or not installed at all."
        5:
          p.error = "Bad MOA Interface."
        6:
          p.error = "Bad URL or Bad MOA class. The required network or nonnetwork Xtra extensions are improperly installed or not installed at all."
        20:
          p.error = "Internal error. Returned by netError() in the Netscape browser if the browser detected a network or internal error."
        4146:
          p.error = "Connection could not be established with the remote host."
        4149:
          p.error = "Data supplied by the server was in an unexpected format."
        415:
          p.error = "Unexpected early closing of connection."
        4154:
          p.error = "Operation could not be completed due to timeout."
        4155:
          p.error = "Not enough memory available to complete the transaction."
        4156:
          p.error = "Protocol reply to request indicates an error in the reply."
        4157:
          p.error = "Transaction failed to be authenticated."
        4159:
          p.error = "Invalid URL."
        4164:
          p.error = "Could not create a socket."
        4165:
          p.error = "Requested object could not be found (URL may be incorrect)."
        4166:
          p.error = "Generic proxy failure."
        4167:
          p.error = "Transfer was intentionally interrupted by client."
        4242:
          p.error = "Download stopped by netAbort(url)."
        4836:
          p.error = "Download stopped for an unknown reason, possibly a network error, or the download was abandoned."
        otherwise:
          p.error = "Error unknown."
      end case
      DownloadDone(0)
    end if
  end if
  tData = getStreamStatus(p.NetID)
  if tData.bytesTotal <> 0 then
    p.Percentage = float(tData.bytesSoFar) / float(tData.bytesTotal)
  end if
end

on DownloadDone tState
  if tState = 1 then
    _movie.castLib("Engine").fileName = p.url
    put "[SYSTEM]" & TAB & "Engine was downloaded and linked succesfully."
    InitEngine()
  else
    put "[SYSTEM]" & TAB & "Engine was not downloaded and linked. Error was: " & p.error
  end if
  _movie.actorList.deleteOne(p.me)
end

on AbortDownload me
  netAbort(p.NetID)
  put "[SYSTEM]" & TAB & "Engine download was aborted."
  _movie.actorList.deleteOne(p.me)
end

on returnPercentage me
  return p.Percentage
end
