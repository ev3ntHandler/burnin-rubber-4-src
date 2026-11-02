-- [Script] [M] Event Manager (Script #6114)
-- Script Type: Movie

global gSystem, gData, gGame

on event me, tEvent
  if tEvent.ilk = #string then
    tEvent = symbol(StringEvaluator(0, tEvent))
  end if
  if voidp(gData[#Events][tEvent]) = 1 then
    LogMessage(0, "Event" & TAB & string(tEvent) & " does not exist.")
    return 0
  end if
  gSystem.event = tEvent
  LogMessage(0, "Event" & TAB & string(tEvent))
  tCount = gData[#Events][tEvent].count
  repeat with i = 1 to tCount
    tFunction = gData[#Events][tEvent].getPropAt(i)
    tTarget = gData[#Events][tEvent][i][1]
    tDataList = gData[#Events][tEvent][i][2]
    tTargetExceptionList = [#AddTrigger, #AddToList, #RemoveFromList]
    if tTargetExceptionList.getPos(tFunction) = 0 then
      tTarget = StringEvaluator(0, tTarget)
    end if
    tDataListExceptionList = []
    if tDataListExceptionList.getPos(tFunction) = 0 then
      tDataList = StringEvaluator(0, tDataList)
    end if
    tResult = _movie.sendSprite(0, tFunction, tTarget, tDataList)
    if gSystem.UpdateScript <> #none then
      gSystem.UpdateScript.update([#command: tFunction, #currentCommand: i])
    else
      if gSystem.ForceUpdate = 1 then
        if member("[PS] Game Progress") <> VOID then
          tScript = script("[PS] Game Progress").new([#event: tEvent, #command: tFunction, #totalCommands: tCount, #currentCommand: i])
        else
          tScript = script("[PS] Default Progress").new([#event: tEvent, #command: tFunction, #totalCommands: tCount, #currentCommand: i])
        end if
        if tScript <> VOID then
          gSystem.UpdateScript = tScript
        end if
      end if
    end if
    if (gSystem.UpdateScript <> #none) and (gSystem.ForceUpdate = 0) then
      delete gSystem.UpdateScript
    end if
  end repeat
  if gSystem.ReturnEvent = gSystem.event then
    gSystem.ReturnEvent = #none
  end if
  gSystem.event = #none
end

on DelayEvent me, tTarget, tDataList
  LogMessage(0, "Function: DelayEvent. Target: " & tTarget & TAB & "DataLdist: " & tDataList)
  tDataList = tDataList
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if (tDataList = VOID) or (tDataList.ilk <> #propList) then
    LogMessage(0, "Function: DelayEvent. Target: " & tTarget & TAB & "DataList: " & tDataList & " Datalist obsolete (VOID or not #proplist).")
    exit
  end if
  pDelay = tDataList[#delay]
  if pDelay = VOID then
    pDelay = 1000
  end if
  pevent = tDataList[#event]
  if pevent = VOID then
    pevent = EMPTY
  end if
  pAmount = _movie.timeoutList.count + 1
  if tDataList[#name].ilk = #string then
    tName = tDataList.name
  else
    tName = "Delay" & pevent & _system.milliSeconds & (_movie.timeoutList.count + 1) & random(1, 10000)
  end if
  tTimeOut = timeout().new(tName, pDelay, #DelayEventTimeOut, pevent)
end

on DelayEventTimeOut tEvent, tTimeOut
  if _movie.timeoutList.getPos(tTimeOut) <> 0 then
    tTimeOut.forget()
  end if
  event(0, tEvent)
end

on DelayCommand me, tTarget, tDataList
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tDelay = tDataList[#delay]
  if tDataList[#delay].ilk = #integer then
    tDelay = tDataList.delay
  else
    tDelay = 1000
  end if
  tList = []
  if tDataList[#command].ilk = #string then
    tCommand = tDataList.command
  else
    return 0
  end if
  if tDataList[#target].ilk = #string then
    tTarget = tDataList.target
  else
    return 0
  end if
  if tDataList[#data].ilk = #propList then
    tData = tDataList.data
  else
    return 0
  end if
  timeout().new("Delay" & tCommand & _system.milliSeconds & (_movie.timeoutList.count + 1) & random(1, 10000), tDelay, #DelayCommandTimeOut, [#handler: tCommand, #target: tTarget, #data: tData])
end

on DelayCommandTimeOut me, tList, tTimeOut
  sendSprite(0, symbol(tList.handler), tList.target, tList.data)
  if _movie.timeoutList.getPos(tTimeOut) <> 0 then
    tTimeOut.forget()
  end if
end

on AddToGlobals me, tmember, tDataList
  repeat with i = 1 to tmember.text.line.count
    tLine = tmember.text.line[i]
    if tLine.word.count = 0 then
      next repeat
    end if
    if tLine contains "//" then
      next repeat
    end if
    AddValue(0, EMPTY, [#name: tLine.item[1], #value: tLine.item[2]])
  end repeat
end

on AddToData me, tmember, tDataList
  if (tmember = VOID) or (tmember.type <> #text) then
    LogMessage(0, "Function: AddEventsFromFile. Member: " & tmember & " Member VOID or no text member. Function aborted.")
    exit
  end if
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    tDataList = [:]
  end if
  tRemove = 0
  if voidp(tDataList[#Remove]) = 0 then
    tRemove = tDataList.Remove
  end if
  tAddEventState = 0
  tTag = VOID
  if tDataList.list = #Triggers then
    repeat with qw = 1 to tmember.line.count
      tLine = tmember.line[qw]
      if (tLine.word.count = 0) or (tLine.length = 0) or (tLine contains "//") then
        next repeat
      end if
      tTrigger = [:]
      SetItemDelimiter(0, TAB)
      tTriggers = tLine.item[1]
      tDataList = value(tLine.item[2])
      AddTrigger(0, tTriggers, tDataList)
    end repeat
  else
    if tDataList.list = #Info then
      gData.Info[symbol(tmember.name)] = [:]
      tMainList = gData.Info[symbol(tmember.name)]
      SetItemDelimiter(0, TAB)
      tDefaultList = [:]
      repeat with we = 1 to tmember.line[1].item.count
        tDefaultList[symbol(tmember.line[1].item[we])] = #noInfo
      end repeat
      tCount = tmember.line.count
      repeat with qw = 2 to tCount
        tLine = tmember.line[qw]
        tNewList = tDefaultList.duplicate()
        if tLine.item.count = 0 then
          next repeat
        end if
        repeat with er = 1 to tNewList.count
          SetItemDelimiter(0, TAB)
          tEntry = tLine.item[er]
          if tEntry contains "," then
            if tEntry contains SPACE then
              tEntry = RemoveSpaces(0, tEntry)
            end if
            SetItemDelimiter(0, ",")
            tSubList = []
            repeat with jk = 1 to tEntry.item.count
              tSubEntry = tEntry.item[jk]
              if tSubEntry = EMPTY then
                tSubEntry = #none
              end if
              if (value(tSubEntry).ilk = #integer) or (value(tSubEntry).ilk = #symbol) then
                tSubEntry = value(tSubEntry)
              end if
              tSubList.add(tSubEntry)
            end repeat
            tNewList[er] = tSubList.duplicate()
            next repeat
          end if
          tSubEntry = tEntry
          if tSubEntry = EMPTY then
            tSubEntry = #none
          end if
          if (value(tSubEntry).ilk = #integer) or (value(tSubEntry).ilk = #symbol) then
            tSubEntry = value(tSubEntry)
          end if
          tNewList[er] = tSubEntry
        end repeat
        tMainList.addProp(symbol(tLine.item[1]), tNewList.duplicate())
      end repeat
    else
      repeat with qw = 1 to tmember.line.count
        tLine = tmember.line[qw]
        if (tLine.word.count = 0) or (tLine.length = 0) or (tLine contains "//") then
          next repeat
        end if
        if tLine.word.count = 1 then
          tWord = tLine.word[1]
          if tWord contains "_Begin" then
            SetItemDelimiter(0, "_")
            if tWord.item.count = 1 then
              tTag = tWord.item[1]
            else
              tTag = EMPTY
              repeat with i = 1 to tWord.item.count - 1
                if i = 1 then
                  tTag = tWord.item[i]
                  next repeat
                end if
                tTag = tTag & "_" & tWord.item[i]
              end repeat
            end if
            if tRemove = 1 then
              gData[symbol("Stored" & string(tDataList.list))].add(symbol(tTag))
            end if
            tAddEventState = 1
            tSubList = [:]
            next repeat
          end if
          if tWord contains "_End" then
            gData[tDataList.list][symbol(tTag)] = tSubList
            tTag = VOID
            tAddEventState = 0
            next repeat
          end if
        end if
        if tAddEventState = 1 then
          SetItemDelimiter(0, TAB)
          delete tLine.char[1..1]
          tProp = symbol(tLine.item[1])
          if tDataList.list = #data then
            if tTag = "Text" then
              tSubList.addProp(tProp, tLine.item[2])
            else
              tPropList = value(tLine.item[2])
              if tPropList.ilk = #propList then
                tSubList.addProp(tProp, tPropList)
              else
                tCheckList = [#list, #integer, #float, #point, #color, #symbol, #vector]
                if tCheckList.getPos(tPropList.ilk) = 0 then
                  tSubList.addProp(tProp, tLine.item[2])
                  if tLine.item[2].char[1] = "[" then
                    PutMessage(0, "Property list suspected, but couldn't create it. Data: " & tProp & TAB & "List: " & tLine.item[2], [#type: #alert])
                  end if
                else
                  tSubList.addProp(tProp, tPropList)
                end if
              end if
            end if
            next repeat
          end if
          tCheck = 1
          if tDataList[#noCheck].ilk = #integer then
            tCheck = tDataList.noCheck
          end if
          if tCheck = 1 then
            if (gSystem.local = 1) and (voidp(gGame[#CheckOverride]) = 1) then
              tState = CheckHandler(0, tProp)
              if tState = 0 then
                PutMessage(0, "Handler does not exist. Event: " & tTag & TAB & "Handler: " & string(tProp), [#type: #alert])
              end if
              tState = CheckTarget(0, tProp, tLine.item[2], tTag)
              if tState <> 1 then
                PutMessage(0, tState, [#type: #alert])
              end if
              tState = CheckPropList(0, tProp, tLine.item[3], tTag)
              if tState <> 1 then
                PutMessage(0, tState, [#type: #alert])
              end if
            end if
          end if
          tSubList.addProp(tProp, [tLine.item[2], tLine.item[3]])
        end if
      end repeat
    end if
  end if
end

on RemoveFromData me, tTag
  if tTag = VOID then
    exit
  end if
  if gData[symbol("Stored" & tTag)].ilk <> #list then
    exit
  end if
  if gData[symbol("Stored" & tTag)].count > 0 then
    repeat with i in gData[symbol("Stored" & tTag)]
      gData[tTag].deleteProp(i)
    end repeat
  end if
  gData[symbol("Stored" & tTag)] = []
end

on CheckHandler me, tHandler
  tState = 0
  tCastList = ["Engine", "Game"]
  repeat with i in tCastList
    tCast = _movie.castLib(i)
    tCount = tCast.member.count
    if tState = 1 then
      exit repeat
    end if
    repeat with j = 1 to tCount
      tmember = member(j, i)
      if tmember.type <> #script then
        next repeat
      end if
      tHandlers = tmember.script.handlers()
      if tHandlers.getPos(tHandler) <> 0 then
        tState = 1
        exit repeat
      end if
    end repeat
  end repeat
  return tState
end

on CheckTarget me, tHandler, tTarget, tEvent
  tState = 1
  tList = [#PutMessage, #event, #load]
  if tList.getPos(tHandler) <> 0 then
    return tState
  end if
  if tTarget.length = 0 then
    return tState
  end if
  if tTarget = "x" then
    return tState
  end if
  if (tTarget contains "{") or (tTarget contains "=") then
    return tState
  end if
  if (tTarget contains "gData") or (tTarget contains "gSystem") or (tTarget contains "gGame") or (tTarget contains "gSound") then
    return tState
  end if
  if value(tTarget).ilk = #integer then
    tValue = value(tTarget)
    if tValue > _movie.lastChannel then
      return "Trying to access an unavailable sprite channel. Event: " & tEvent & TAB & "Handler: " & string(tHandler) & TAB & "Target: " & tTarget & ". Current available channels are: " & string(_movie.lastChannel)
    else
      if sprite(tValue).member = member(0, 0) then
        return "Trying to access a sprite channel without a member. Event: " & tEvent & TAB & "Handler: " & string(tHandler) & TAB & "Target: " & tTarget
      end if
    end if
  else
    tmember = member(tTarget)
    if tmember = VOID then
      return "Trying to access a member that does not exist. NOTE: This member might not be imported yet. Event: " & tEvent & TAB & "Handler: " & string(tHandler) & TAB & "Target: " & tTarget
    end if
  end if
  return tState
end

on CheckPropList me, tHandler, tList, tEvent
  tState = 1
  if tList.length = 0 then
    return tState
  end if
  if tList = "x" then
    return tState
  end if
  if (tList contains "{") or (tList contains "=") then
    return tState
  end if
  if (tList contains "gData") or (tList contains "gSystem") or (tList contains "gGame") or (tList contains "gSound") then
    return tState
  end if
  tValue = value(tList)
  if tValue.ilk <> #propList then
    return "Did not find a correct property list. Event: " & tEvent & TAB & "Handler: " & string(tHandler) & TAB & "List: " & tList
  else
    return tState
  end if
end

on Iterate me, tTarget, tDataList
  if tTarget.ilk = #string then
    tTarget = value(tTarget)
  end if
  if tTarget.ilk <> #integer then
    return 0
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tEvent = VOID
  if tDataList[#event].ilk = #string then
    tEvent = tDataList.event
  end if
  repeat with i = 1 to tTarget
    gGame.Iteration = i
    event(0, tEvent)
  end repeat
  gGame.Iteration = VOID
  return 1
end

on LogMessage me, tString
end

on PutMessage me, tString, tDataList
end

on AlertMessage me, tString
  alert(string(tString))
end
