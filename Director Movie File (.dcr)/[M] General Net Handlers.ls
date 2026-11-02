-- [Script] [M] General Net Handlers (Script #6110)
-- Script Type: Movie

on GetNetIDError me, tID
  case tID of
    4:
      tError = "Bad MOA class. The required network or nonnetwork Xtra extensions are improperly installed or not installed at all."
    5:
      tError = "Bad MOA Interface."
    6:
      tError = "Bad URL or Bad MOA class. The required network or nonnetwork Xtra extensions are improperly installed or not installed at all."
    20:
      tError = "Internal error. Returned by netError() in the Netscape browser if the browser detected a network or internal error."
    4146:
      tError = "Connection could not be established with the remote host."
    4149:
      tError = "Data supplied by the server was in an unexpected format."
    415:
      tError = "Unexpected early closing of connection."
    4154:
      tError = "Operation could not be completed due to timeout."
    4155:
      tError = "Not enough memory available to complete the transaction."
    4156:
      tError = "Protocol reply to request indicates an error in the reply."
    4157:
      tError = "Transaction failed to be authenticated."
    4159:
      tError = "Invalid URL."
    4164:
      tError = "Could not create a socket."
    4165:
      tError = "Requested object could not be found (URL may be incorrect)."
    4166:
      tError = "Generic proxy failure."
    4167:
      tError = "Transfer was intentionally interrupted by client."
    4242:
      tError = "Download stopped by netAbort(url)."
    4836:
      tError = "Download stopped for an unknown reason, possibly a network error, or the download was abandoned."
    otherwise:
      tError = "Error unknown"
  end case
  return tError
end
