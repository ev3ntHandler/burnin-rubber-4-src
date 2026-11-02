-- [Script] [M] Loader (Script #6109)
-- Script Type: Movie

global gSystem, gData

on load me, tFile, tDataList
  LogMessage(0, "Load" & TAB & "File: " & tFile & " DataList: " & tDataList)
  if (tFile = EMPTY) or (tFile contains "//") then
    tFile = VOID
  else
    tFile = gSystem.path & StringEvaluator(0, tFile)
  end if
  if tFile = VOID then
    LogMessage(0, "Load" & TAB & "File: " & tFile & " DataList: " & tDataList & ". No path available. Load aborted.")
    exit
  end if
  if gSystem.Mac = 1 then
    tFile = ReformatForMac(0, tFile)
  end if
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    tDataList = [:]
  end if
  if tFile contains ".txt" then
    if gSystem.local = 1 then
      tResult = LoadTxt(0, tFile, tDataList.duplicate())
    end if
    if tDataList[#event].ilk = #string then
      event(0, tDataList.event)
    end if
  else
    if gSystem.local = 1 then
      ImportFile(0, tFile, tDataList.duplicate())
    end if
  end if
end

on ReformatForMac me, tFile
  tString = EMPTY
  repeat with i = 1 to tFile.length
    tChar = tFile.char[i]
    if tChar = "\" then
      tString = tString & ":"
      next repeat
    end if
    tString = tString & tChar
  end repeat
  return tString
end

on LoadTxt me, tFile, tDataList
  if voidp(tFile) = 1 then
    LogMessage("Function: LoadTxt. Parameters: " & tFile && tDataList & " No path available. LoadTxt aborted.")
    exit
  end if
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    tDataList = [:]
  end if
  tCast = "Internal"
  if voidp(tDataList[#cast]) = 0 then
    tCast = tDataList.cast
  end if
  SetItemDelimiter(0, "\")
  tFileName = tFile.item[tFile.item.count]
  tFutureName = tFileName.char[1..tFileName.length - 4]
  ResetItemDelimiter()
  tOverride = 0
  if tDataList[#Override].ilk = #integer then
    tOverride = tDataList.Override
  end if
  if tOverride = 1 then
    if member(tFutureName) <> VOID then
      EraseMember(0, member(tFutureName))
    end if
  end if
  if member(tFutureName) = VOID then
    tmember = createMember(0, EMPTY, [#type: #text, #cast: tCast])
    tImported = tmember.importFileInto(tFile)
    if tImported <> 0 then
      HandleTxt(0, tmember, tDataList.duplicate())
    else
      LogMessage(0, "Function: LoadTxt. Parameters: " & tFile && tDataList & " Import failed, member was erased.")
      EraseMember(0, tmember)
      return 0
    end if
  else
    return 0
  end if
  return 1
end

on HandleTxt me, tmember, tDataList
  tDataList = tDataList.duplicate()
  if tmember.name contains "LoadingArray" then
    repeat with i = 1 to tmember.text.line.count
      SetItemDelimiter(0, TAB)
      tPath = tmember.text.line[i].item[1]
      tTextDataList = value(tmember.text.line[i].item[2])
      if tTextDataList.ilk <> #propList then
        tTextDataList = tDataList
      end if
      if voidp(tTextDataList[#event]) = 0 then
        tTextDataList.deleteProp(#event)
      end if
      load(0, tPath, tTextDataList.duplicate())
    end repeat
  end if
  if tmember.name contains "Globals" then
    AddToGlobals(0, tmember, tDataList)
  end if
  if tmember.name contains "Events" then
    tDataList[#list] = #Events
    AddToData(0, tmember, tDataList)
  end if
  if tmember.name contains "Data" then
    tDataList[#list] = #data
    AddToData(0, tmember, tDataList)
  end if
  if tmember.name contains "Triggers" then
    tDataList[#list] = #Triggers
    AddToData(0, tmember, tDataList)
  end if
  if tmember.name contains "Info" then
    tDataList[#list] = #Info
    AddToData(0, tmember, tDataList)
  end if
end

on ImportFile me, tFile, tDataList
  LogMessage(0, "ImportFile" & TAB & "File: " & tFile & " DataList: " & tDataList)
  if voidp(tFile) = 1 then
    LogMessage("Function: ImportFile. Parameters: " & tFile && tDataList & " No path available. ImportFile aborted.")
    exit
  end if
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    tDataList = [:]
  end if
  tCast = "Internal"
  repeat with m = 1 to _movie.castLib.count
    tCastName = _movie.castLib[m].name
    if (tCastName = "Engine") or (tCastName = "Game") then
      next repeat
    end if
    if tFile contains _movie.castLib[m].name then
      tCast = _movie.castLib[m].name
      exit repeat
    end if
  end repeat
  if voidp(tDataList[#cast]) = 0 then
    tCast = tDataList.cast
  end if
  ResetItemDelimiter()
  if tFile.item.count > 1 then
    tFile = tFile.item[1]
    tDataList = value(tFile.item[2])
  end if
  tSingleFile = 0
  tType = VOID
  tFiles = [".W3D", ".w3d", ".bmp", ".png", ".tga", ".wav", ".swf", ".txt", ".jpg", ".swa", ".tif", ".mp3", ".gif"]
  tTypes = [#shockwave3d, #shockwave3d, #bitmap, #bitmap, #bitmap, #sound, #flash, #text, #bitmap, #sound, #bitmap, #sound, #bitmap]
  tTag = tFile.char[tFile.length - 3..tFile.length]
  if tFiles.getPos(tTag) <> 0 then
    tSingleFile = 1
    tType = tTypes[tFiles.getPos(tTag)]
  end if
  if tSingleFile = 1 then
    tmember = createMember(0, EMPTY, [#type: tType, #cast: tCast])
    case tType of
      #bitmap:
        tImported = tmember.importFileInto(tFile, [#dither: 0, #trimWhiteSpace: 0, #remapImageToStage: 0])
      #text:
        tImported = tmember.importFileInto(tFile)
        HandleTxt(0, tmember, tDataList.duplicate())
      otherwise:
        tImported = tmember.importFileInto(tFile)
    end case
  else
    repeat with j = 1 to 101
      tNextFile = getNthFileNameInFolder(tFile, j)
      if tNextFile = EMPTY then
        exit repeat
      end if
      if tNextFile contains "svn" then
        next repeat
      end if
      tTag = tNextFile.char[tNextFile.length - 3..tNextFile.length]
      if tFiles.getPos(tTag) <> 0 then
        tSingleFile = 1
        tType = tTypes[tFiles.getPos(tTag)]
      end if
      if voidp(tType) = 1 then
        LogMessage(0, "tType was VOID. This means it could be a folder or you're trying to import a file that is (currently) not supported.")
        next repeat
      end if
      tFutureName = tNextFile.char[1..tNextFile.length - 4]
      if member(tFutureName) <> VOID then
        next repeat
      end if
      tmember = createMember(0, EMPTY, [#type: tType, #cast: tCast])
      case tType of
        #bitmap:
          tImported = tmember.importFileInto(tFile & tNextFile, [#dither: 0, #trimWhiteSpace: 0, #remapImageToStage: 0])
        #text:
          tImported = tmember.importFileInto(tFile & tNextFile)
          HandleTxt(0, tmember, tDataList.duplicate())
        otherwise:
          tImported = tmember.importFileInto(tFile & tNextFile)
      end case
    end repeat
  end if
  if tImported = 0 then
    if tmember <> VOID then
      EraseMember(0, tmember)
    end if
  end if
end

on GetFileName me, tString
  SetItemDelimiter(0, "/")
  tFullFileName = tString.item[tString.item.count]
  SetItemDelimiter(0, ".")
  tFileName = tFullFileName.item[1]
  ResetItemDelimiter()
  return tFileName
end

on FilterForCasts me, tString
  tmember = member(tString)
  if tmember = VOID then
    return VOID
  end if
  if tmember.type <> #text then
    return VOID
  end if
  tList = []
  tCount = tmember.line.count
  SetItemDelimiter(0, "\")
  repeat with i = 1 to tCount
    tLine = tmember.line[i]
    tCast = tLine.item[3]
    if tList.getPos(tCast) = 0 then
      tList.add(tCast)
    end if
  end repeat
  ResetItemDelimiter()
  return tList
end

on OnlineLoad me, tTarget, tLocation
  tCount = _movie.castLib("Internal").member.count
  repeat with i = 1 to tCount
    tmember = member(i, "Internal")
    if tmember.type = #text then
      HandleTxt(0, tmember, [:])
    end if
  end repeat
  gSystem.OnlineDataLoaded = 1
end
