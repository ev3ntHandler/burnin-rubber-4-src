-- [Script] [M] Misc Handlers (Script #6106)
-- Script Type: Movie

global gSystem, gGame

on GetEmptyChannel me, t1, t2
  if t1 = VOID then
    t1 = 1
  end if
  if t2 = VOID then
    t2 = _movie.lastChannel
  end if
  repeat with i = t1 to t2
    if sprite(i).member.name = EMPTY then
      exit repeat
    end if
  end repeat
  return i
end

on GetStageSize me
  return [_movie.stage.rect.width, _movie.stage.rect.height]
end

on EncodeAndSaveData me, tObject, tEncode
  if tEncode = 1 then
    tString = EncodeHard(0, tObject)
  else
    tString = string(tObject)
  end if
  tResult = _player.setPref(gGame.PrefFile, tString)
  return tResult
end

on DecodeAndRetrieveData me, tString, tDecode
  if tDecode = 1 then
    tPropList = DecodeHard(0, tString)
  else
    tPropList = tString
    if tPropList.ilk = #string then
      tPropList = value(tPropList)
    end if
  end if
  return tPropList
end

on EncodeHard me, tObject
  tString = string(tObject)
  tLength = tString.length
  tEncodedString = EMPTY
  repeat with i = 1 to tLength
    tChar = tString.char[i]
    tCharString = string(tChar.charToNum)
    if tCharString.length = 2 then
      tCharString = "0" & tCharString
    end if
    tCharString = ConvertIntegerToChar(0, tCharString)
    tEncodedString = tEncodedString & tCharString
  end repeat
  return tEncodedString
end

on DecodeHard me, tString
  if tString.ilk <> #string then
    LogMessage(0, "No string to 'hard decode'")
    exit
  end if
  tPropListString = EMPTY
  tIntList = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
  tCount = tString.length / 3
  tCounter = 1
  repeat with i = 1 to tCount
    tCnt1 = tCounter
    tCnt2 = tCounter + 2
    tCharSet = tString.char[tCnt1..tCnt2]
    tIntCharSet = EMPTY
    repeat with j = 1 to 3
      tChar = tCharSet.char[j]
      tValue = tIntList.getPos(tChar)
      if tValue = 10 then
        tValue = 0
      end if
      tStringValue = string(tValue)
      tIntCharSet = tIntCharSet & tStringValue
    end repeat
    tNum = value(tIntCharSet)
    tFinalChar = numToChar(tNum)
    tPropListString = tPropListString & tFinalChar
    tCounter = tCounter + 3
  end repeat
  tPropList = value(tPropListString)
  return tPropList
end

on ConvertIntegerToChar me, tString
  tZeroList = "asdfghjkl"
  tIntList = "qwertyuiop"
  tNewString = EMPTY
  tCount = tString.length
  repeat with i = 1 to tCount
    tValue = value(tString.char[i])
    if i = 1 then
      if tValue = 0 then
        tNewChar = tZeroList.char[random(1, 9)]
      else
        tNewChar = tIntList.char[tValue]
      end if
    else
      if tValue = 0 then
        tValue = 10
      end if
      tNewChar = tIntList.char[tValue]
    end if
    tNewString = tNewString & tNewChar
  end repeat
  return tNewString
end

on Encode me, tString
  if tString.ilk <> #string then
    exit
  end if
  tRandomList = "qweasdzxcrtyfghvbnuiojklmp,[]: 0192837465#" & QUOTE
  tNormalList = "abcdefghijklmnopqrstuvwxyz" & QUOTE & "#0 123456789,:[]"
  tNewString = EMPTY
  tCount = tString.length
  repeat with i = 1 to tCount
    tOldChar = tString.char[i]
    repeat with j = 1 to tNormalList.length
      tCheckChar = tNormalList.char[j]
      if tCheckChar = tOldChar then
        tNewChar = tRandomList.char[j]
        tNewString = tNewString & tNewChar
        exit repeat
        next repeat
      end if
      next repeat
    end repeat
  end repeat
  return tNewString
end

on Decode me, tString
  if tString.ilk <> #string then
    exit
  end if
  tRandomList = "qweasdzxcrtyfghvbnuiojklmp,[]: 0192837465#" & QUOTE
  tNormalList = "abcdefghijklmnopqrstuvwxyz" & QUOTE & "#0 123456789,:[]"
  tNewString = EMPTY
  tCount = tString.length
  repeat with i = 1 to tCount
    tOldChar = tString.char[i]
    repeat with j = 1 to tRandomList.length
      tCheckChar = tRandomList.char[j]
      if tCheckChar = tOldChar then
        tNewChar = tNormalList.char[j]
        tNewString = tNewString & tNewChar
        exit repeat
        next repeat
      end if
      next repeat
    end repeat
  end repeat
  return tNewString
end

on GetTimeString me, tMillisec, tFormat
  sec = integer(tMillisec / 1000)
  min = integer(sec / 60)
  sec = sec - (min * 60)
  Hour = integer(min / 60)
  min = min - (Hour * 60)
  tMillisec = integer((tMillisec - (sec * 1000) - (min * 60 * 1000) - (Hour * 60 * 60 * 1000)) / 10.0)
  if tFormat = VOID then
    tFormat = #standard
  end if
  if tFormat = #standard then
    if min < 10 then
      minString = "0" & string(min + 100).char[3..3] & ":"
    else
      minString = string(min + 100).char[3..3] & ":"
    end if
    secString = string(sec + 100).char[2..3] & "."
    if tMillisec < 10 then
      MilliString = "0" & string(tMillisec)
    else
      MilliString = string(tMillisec)
    end if
    if tMillisec = 100 then
      MilliString = "00"
    end if
    return minString & secString & MilliString
  end if
end

on ManipulateTime me, tTarget, tDataList
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if (tDataList = VOID) or (tDataList.ilk <> #propList) then
    LogMessage(0, "ManipulateTime" & TAB & "Target: " & tTarget & " Parameters: " & tDataList & " Datalist obsolete set to [:].")
    tDataList = [:]
  end if
  tTargetTime = 1.0
  if tDataList[#targetTime].ilk = #float then
    tTargetTime = tDataList.targetTime
  end if
  tDefaultStep = 0.29999999999999999
  if tDataList[#defaultStep].ilk = #float then
    tDefaultStep = tDataList.defaultStep
  end if
  if gGame.TimeMP = tTargetTime then
    exit
  end if
  tList = [#targetTime: tTargetTime, #defaultStep: tDefaultStep, #Counter: 0]
  tPeriod = integer(1.0 / gGame.tempo * 1000.0)
  timeout().new("ManipulateTimeTimeOut", tPeriod, #manipulateTimeTimeOut, tList)
end

on manipulateTimeTimeOut tProperties, tTimeOut
  tTargetTime = tProperties[#targetTime]
  tDefaultStep = tProperties[#defaultStep]
  tCounter = tProperties[#Counter]
  tCounter = tCounter + 1
  tProperties[#Counter] = tCounter
  tY = tDefaultStep / tCounter
  if tTargetTime < gGame.TimeMP then
    tY = tY * -1
  end if
  if tY < 0.0 then
    if gGame.TimeMP > tTargetTime then
      gGame.TimeMP = gGame.TimeMP + tY
    end if
    if gGame.TimeMP < tTargetTime then
      gGame.TimeMP = tTargetTime
      tTimeOut.forget()
    end if
  else
    if gGame.TimeMP < tTargetTime then
      gGame.TimeMP = gGame.TimeMP + tY
    end if
    if gGame.TimeMP > tTargetTime then
      gGame.TimeMP = tTargetTime
      tTimeOut.forget()
    end if
  end if
end

on ClearTimeOutList me
  _movie.timeoutList = []
end

on ClearActorList me
  _movie.actorList = []
end

on CloseWindows me
  tCount = _player.windowList.count
  if tCount > 1 then
    repeat with i = 2 to tCount
      tWindow = _player.windowList[i]
      if tWindow.name = "3DPI" then
        next repeat
      end if
      tWindow.forget()
      tWindow.close()
    end repeat
  end if
end

on fullscreen me
  if gGame.fullscreen = 1 then
    ResXoff()
    SetStageSize()
    gGame.fullscreen = 0
  else
    ResXon()
    gGame.fullscreen = 1
  end if
end

on SetStageSize me
  t = (the desktopRectList)[1]
  t1 = (t[3] / 2) - (gGame.resolution[1] / 2)
  t2 = (t[4] / 2) - (gGame.resolution[2] / 2)
  (the stage).rect = rect(t1, t2, t1 + gGame.resolution[1], t2 + gGame.resolution[2])
end

on ResXon me
  tempList = []
  tempList = resx_getDisplayMode()
  gGame[#OrigResolution] = tempList.duplicate()
  tempList[1] = gGame.resolution[1]
  tempList[2] = gGame.resolution[2]
  x = resx_setDisplayMode(tempList)
  if x = 0 then
  end if
  (the stage).rect = (the desktopRectList)[1]
end

on ResXoff me
  x = resx_setDisplayMode(gGame.OrigResolution)
end

on GameQuit me
  _player.quit()
end

on UpdateVersion me, tmember
  if tmember = VOID then
    return 0
  end if
  if tmember.type <> #text then
    return 0
  end if
  tVersionData = value(tmember.text)
  tNewVersion = tVersionData[#version] + 0.001
  tNewVersion = string(tNewVersion)
  tNewVersion = tNewVersion.char[1..5]
  tVersionData[#version] = value(tNewVersion)
  tmember.text = string(tVersionData)
end

on ShowVersion me
  tmember = member("GameVersion")
  if tmember = VOID then
    tmember = member("Version")
    tVersion = value(tmember.text)[#version]
    tVersion = string(tVersion).char[1..4]
    alert(string("Engine Version: " & tVersion))
  else
    tVersion = value(tmember.text)[#version]
    tVersion = string(tVersion).char[1..4]
    alert(string(gGame.name & " Version: " & tVersion))
  end if
end

on ShowHandlers me
  tTextMember = member("Handlers")
  tTextMember.text = EMPTY
  tCount = _movie.castLib("Engine").member.count
  tList = []
  repeat with i = 1 to tCount
    tmember = _movie.castLib("Engine").member[i]
    if tmember.type = #script then
      if tmember.scriptType = #movie then
        tScriptText = tmember.scriptText
        tTextMember.text = tTextMember.text & RETURN & tmember.name
        tHandlers = tmember.script.handlers()
        if tHandlers.count > 0 then
          repeat with j in tHandlers
            repeat with k = 1 to tScriptText.line.count
              tLine = tScriptText.line[k]
              if tLine contains ("on " & string(j)) then
                tTextMember.text = tTextMember.text & RETURN & TAB & string(j) & TAB & TAB & TAB & TAB & TAB & tLine
                exit repeat
              end if
            end repeat
          end repeat
        end if
        tTextMember.text = tTextMember.text & RETURN
      end if
    end if
  end repeat
end

on update me
  gSystem.ScriptManager.prepareFrame()
  gSystem.ScriptManager.enterFrame()
end

on DivideByZero me
  t = 1 / 0
end
