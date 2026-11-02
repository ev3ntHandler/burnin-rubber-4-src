-- [Script] [M] Triggers (Script #6124)
-- Script Type: Movie

global gData

on EvalTriggers me
  tDelList = []
  repeat with i in gData.Triggers
    i.Counter = i.Counter + 1
    if i.Counter = i.frameFreq then
      i.Counter = 0
      tVal = 1
      repeat with j in i.trigger
        tString = StringEvaluator(0, j)
        tVal = value(tString)
        if tVal = 0 then
          exit repeat
        end if
      end repeat
      if tVal = 1 then
        sendSprite(0, symbol(i.handler), 0)
        event(0, i.event)
        if i.RunOnce > 0 then
          i.RunOnce = i.RunOnce - 1
          if i.RunOnce = 0 then
            tDelList.add(i)
          end if
        end if
      end if
    end if
  end repeat
  repeat with i in tDelList
    gData.Triggers.deleteOne(i)
  end repeat
end

on AddTrigger me, tTriggers, tDataList
  tList = [:]
  SetItemDelimiter(0, ";")
  tTriggerList = []
  tCount = tTriggers.item.count
  repeat with j = 1 to tCount
    tTriggerList.add(tTriggers.item[j])
  end repeat
  tList[#trigger] = tTriggerList
  tList[#event] = #none
  tList[#handler] = #none
  tList[#RunOnce] = 1
  tList[#frameFreq] = 1
  tList[#Counter] = 0
  if tDataList.ilk <> #propList then
    tDataList = value(tDataList)
  end if
  if voidp(tDataList[#event]) = 0 then
    tList.event = tDataList.event
  end if
  if voidp(tDataList[#handler]) = 0 then
    tList.handler = tDataList.handler
  end if
  if voidp(tDataList[#RunOnce]) = 0 then
    tList.RunOnce = tDataList.RunOnce
  end if
  if voidp(tDataList[#frameFreq]) = 0 then
    tList.frameFreq = tDataList.frameFreq
  end if
  gData.Triggers.add(tList.duplicate())
end

on Evaluate me, tTarget, tDataList
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  SetItemDelimiter(0, ";")
  tState = 1
  repeat with i = 1 to tTarget.item.count
    if value(tTarget.item[i]) = 0 then
      return 0
    end if
  end repeat
  tEvent = VOID
  if tDataList[#event].ilk = #string then
    tEvent = tDataList.event
  end if
  if tDataList[#handler].ilk = #string then
    sendSprite(0, symbol(tDataList.handler), 0)
  end if
  if tEvent <> VOID then
    event(0, tEvent)
  end if
  return 1
end
