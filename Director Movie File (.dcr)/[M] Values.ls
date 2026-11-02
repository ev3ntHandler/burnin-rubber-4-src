-- [Script] [M] Values (Script #6122)
-- Script Type: Movie

global gSystem, gData, gGame

on AddValue me, tArray, tDataList
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    LogMessage("Function: AddValue. Target: " & tArray & " Parameters: " & tDataList & " Datalist was not a #PropList after value().")
    return 0
  end if
  tList = gGame
  if voidp(tArray) = 0 then
    tList = value(tArray)
  end if
  if tList.ilk <> #propList then
    tList = gGame
  end if
  tValue = value(tDataList.value)
  if tValue.ilk = #void then
    tValue = tDataList.value
  end if
  tSymbol = symbol(tDataList.name)
  tList[tSymbol] = tValue
  return tSymbol
end

on SetValue me, tArray, tDataList
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    LogMessage("Function: SetValue. Target: " & tArray & " Parameters: " & tDataList & " Datalist was not a #PropList after value().")
    return 0
  end if
  tProp = tDataList.getPropAt(1)
  tValue = tDataList[1]
  tList = value(tArray)
  if tList.ilk <> #propList then
    if voidp(gGame[tProp]) = 0 then
      gGame[tProp] = tValue
      return 1
    end if
    if voidp(gSystem[tProp]) = 0 then
      gSystem[tProp] = tValue
      return 1
    end if
  else
    if voidp(tList[tProp]) = 0 then
      tList[tProp] = tValue
      return 1
    end if
  end if
  return 0
end

on RemoveValue me, tArray, tDataList
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    LogMessage("Function: RemoveValue. Target: " & tArray & " Parameters: " & tDataList & " Datalist was not a #PropList after value().")
    return 0
  end if
  tList = gGame
  if voidp(tArray) = 0 then
    tList = value(tArray)
  end if
  if tList.ilk <> #propList then
    tList = gGame
  end if
  tName = VOID
  if tDataList[#name].ilk = #string then
    tName = tDataList.name
  end if
  if tName = VOID then
    return 0
  end if
  if voidp(tList[symbol(tName)]) = 0 then
    tList.deleteProp(symbol(tName))
  else
    return 0
  end if
  return 1
end

on AddToList me, tArray, tDataList
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    LogMessage("Function: AddToList. Target: " & tArray & " Parameters: " & tDataList & " Datalist was not a #PropList after value().")
    return 0
  end if
  tArray = value(tArray)
  tOverride = 0
  if tDataList[#Override].ilk = #integer then
    tOverride = tDataList.Override
  end if
  if tArray.ilk = #propList then
    tValue = tDataList[#value]
    if tOverride = 1 then
      if tDataList[#name].ilk = #string then
        tArray[symbol(tDataList.name)] = tValue
      else
        return 0
      end if
    else
      if tDataList[#name].ilk = #string then
        tArray.addProp(symbol(tDataList.name), tValue)
      else
        return 0
      end if
    end if
  else
    tValue = tDataList[#value]
    if tValue = VOID then
      return 0
    end if
    if tOverride = 1 then
      if tArray.getPos(tValue) = 0 then
        tArray.add(tValue)
      end if
    else
      tArray.add(tValue)
    end if
  end if
  return 1
end

on RemoveFromList me, tArray, tDataList
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    LogMessage("Function: AddToList. Target: " & tArray & " Parameters: " & tDataList & " Datalist was not a #PropList after value().")
    return 0
  end if
  tArray = value(tArray)
  if tArray.ilk = #propList then
    if tDataList[#name].ilk = #string then
      tArray.deleteProp(symbol(tDataList.name))
    end if
  else
    tValue = tDataList[#value]
    if tValue <> VOID then
      tArray.deleteOne(tValue)
    end if
  end if
  return 1
end

on MiniCalculator me, tArray, tDataList
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    LogMessage("Function: MiniCalculator. Target: " & tArray & " Parameters: " & tDataList & " Datalist was not a #PropList after value().")
    return 0
  end if
  tArray = value(tArray)
  tValue = VOID
  if tArray.ilk = #propList then
    tValue = tArray[tDataList.value]
  else
    tValue = gGame[tDataList.value]
  end if
  if (tDataList[#add].ilk = #float) or (tDataList[#add].ilk = #integer) then
    tValue = tValue + tDataList.add
  end if
  if (tDataList[#substract].ilk = #float) or (tDataList[#substract].ilk = #integer) then
    tValue = tValue - tDataList.substract
  end if
  if (tDataList[#multiply].ilk = #float) or (tDataList[#multiply].ilk = #integer) then
    tValue = tValue * tDataList.multiply
  end if
  if (tDataList[#divide].ilk = #float) or (tDataList[#divide].ilk = #integer) then
    tValue = tValue / tDataList.divide
  end if
  if tArray.ilk = #propList then
    tArray[tDataList.value] = tValue
  else
    gGame[tDataList.value] = tValue
  end if
  return 1
end
