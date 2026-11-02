-- [Script] [M] Adding and Controlling Scripts (Script #6121)
-- Script Type: Movie

global gSystem, gGame

on AddScript me, tTarget, tDataList
  tValue = value(tTarget)
  if (tValue.ilk = #integer) and (tValue > 0) then
    tScript = AddScriptToSprite(0, tTarget, tDataList)
  else
    tScript = AddScriptToScriptList(0, tTarget, tDataList)
  end if
  return tScript
end

on AddScriptToSprite me, tTarget, tDataList
  LogMessage(0, "AddScriptToSprite" & TAB & "tTarget: " & tTarget & " DataList: " & tDataList)
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    exit
  end if
  tSprite = sprite(tTarget)
  if tSprite.member = member(0, 0) then
    return 0
  end if
  tScriptName = #void
  if tDataList[#script].ilk = #string then
    tScriptName = tDataList.script
  end if
  if tScriptName = #void then
    return 0
  end if
  if member(tScriptName) = VOID then
    return 0
  end if
  tScriptDataList = [:]
  if tDataList[#data].ilk = #propList then
    tScriptDataList = tDataList.data.duplicate()
  end if
  if getaProp(tScriptDataList, #memberName) = VOID then
    tScriptDataList[#memberName] = tSprite.member.name
  end if
  if getaProp(tScriptDataList, #SpriteNR) = VOID then
    tScriptDataList[#SpriteNR] = tSprite.spriteNum
  end if
  tScript = script(tScriptName).new(tScriptDataList)
  if tScript <> VOID then
    tSprite.scriptInstanceList.add(tScript)
    return tScript
  else
    return 0
  end if
end

on AddScriptToScriptList me, tTarget, tDataList
  LogMessage(0, "AddScriptToScriptList" & TAB & "tTarget: " & tTarget & " DataList: " & tDataList)
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    exit
  end if
  tScriptName = #void
  if tDataList[#script].ilk = #string then
    tScriptName = tDataList.script
  end if
  if tScriptName = #void then
    return 0
  end if
  if member(tScriptName) = VOID then
    return 0
  end if
  tScriptDataList = [:]
  if tDataList[#data].ilk = #propList then
    tScriptDataList = tDataList.data.duplicate()
  end if
  tDuplicate = 1
  if tDataList[#duplicate].ilk = #integer then
    tDuplicate = tDataList.duplicate
  end if
  if tDuplicate = 0 then
    tResult = CheckForDuplicateScripts(0, EMPTY, [#script: tScriptName])
    if tResult = 1 then
      return 0
    end if
  end if
  tList = #game
  if (tTarget <> EMPTY) or (tTarget <> VOID) then
    tPossibleLists = [#actorList, #game, #system]
    if tPossibleLists.getPos(value(tTarget)) <> 0 then
      tList = value(tTarget)
    end if
  end if
  tScript = script(tScriptName).new(tScriptDataList)
  if tScript = VOID then
    return 0
  end if
  case tList of
    #game:
      gGame.scriptList.add(tScript)
    #system:
      gSystem.scriptList.add(tScript)
    #actorList:
      _movie.actorList.add(tScript)
  end case
  return tScript
end

on DeleteScript me, tTarget, tDataList
  LogMessage(0, "DeleteScript" & TAB & "tTarget: " & tTarget & " DataList: " & tDataList)
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    return 0
  end if
  tList = gGame.scriptList.duplicate()
  if (tTarget.ilk = #symbol) or (tTarget.ilk = #string) then
    tPossibleLists = [#actorList, #game, #system]
    if tPossibleLists.getPos(value(tTarget)) <> 0 then
      if value(tTarget) = #game then
        tList = gGame.scriptList.duplicate()
      end if
      if value(tTarget) = #system then
        tList = gSystem.scriptList.duplicate()
      end if
      if value(tTarget) = #actorList then
        tList = _movie.actorList.duplicate()
      end if
    end if
  end if
  repeat with i in tList
    if voidp(i[#p]) = 0 then
      if voidp(i.p[#ScriptName]) = 0 then
        tName = i.p.ScriptName
        if tName = tDataList.name then
          tHandlers = i.handlers()
          if tHandlers.getPos(#delete) <> 0 then
            call(#delete, i)
          end if
        end if
      end if
    end if
  end repeat
end

on DeleteAllScripts me, tTarget, tDataList
  LogMessage(0, "DeleteScript" & TAB & "tTarget: " & tTarget & " DataList not necessary")
  tList = gGame.scriptList.duplicate()
  if (tTarget.ilk = #symbol) or (tTarget.ilk = #string) then
    tPossibleLists = [#actorList, #game, #system]
    if tPossibleLists.getPos(value(tTarget)) <> 0 then
      if value(tTarget) = #game then
        tList = gGame.scriptList.duplicate()
      end if
      if value(tTarget) = #system then
        tList = gSystem.scriptList.duplicate()
      end if
      if value(tTarget) = #actorList then
        tList = _movie.actorList.duplicate()
      end if
    end if
  end if
  repeat with i in tList
    tHandlers = i.handlers()
    if tHandlers.getPos(#delete) <> 0 then
      call(#delete, i)
    end if
  end repeat
end

on GetScript me, tTarget, tDataList
  if tDataList[#script].ilk = #string then
    tScript = tDataList.script
  else
    return 0
  end if
  repeat with i in gGame.scriptList
    if voidp(i[#p]) = 0 then
      if voidp(i.p[#ScriptName]) = 0 then
        if tScript = i.p.ScriptName then
          return i
        end if
      end if
    end if
  end repeat
  repeat with i in gSystem.scriptList
    if voidp(i[#p]) = 0 then
      if voidp(i.p[#ScriptName]) = 0 then
        if tScript = i.p.ScriptName then
          return i
        end if
      end if
    end if
  end repeat
  repeat with i in _movie.actorList
    if voidp(i[#p]) = 0 then
      if voidp(i.p[#ScriptName]) = 0 then
        if tScript = i.p.ScriptName then
          return i
        end if
      end if
    end if
  end repeat
end

on CheckForDuplicateScripts me, tTarget, tDataList
  tState = 0
  tScript = tDataList.script
  repeat with i in gGame.scriptList
    if voidp(i[#p]) = 0 then
      if voidp(i.p[#ScriptName]) = 0 then
        if tScript = i.p.ScriptName then
          return 1
        end if
      end if
    end if
  end repeat
  repeat with i in gSystem.scriptList
    if voidp(i[#p]) = 0 then
      if voidp(i.p[#ScriptName]) = 0 then
        if tScript = i.p.ScriptName then
          return 1
        end if
      end if
    end if
  end repeat
  repeat with i in _movie.actorList
    if voidp(i[#p]) = 0 then
      if voidp(i.p[#ScriptName]) = 0 then
        if tScript = i.p.ScriptName then
          return 1
        end if
      end if
    end if
  end repeat
  return tState
end
