-- [Script] [M] String Evaluator (Script #6115)
-- Script Type: Movie

global gSystem, gGame

on StringEvaluator me, tString
  if (tString = VOID) or (tString.ilk <> #string) then
    LogMessage(0, "Function: StringEvaluator. String: " & tString & " No string or string type.")
    exit
  end if
  if tString contains "{" then
    tList = []
    tSubList = []
    repeat with i = 1 to tString.length
      tChar = tString.char[i]
      if tChar = "{" then
        tSubList.add(i)
      end if
      if tChar = "}" then
        tSubList.add(i)
        tList.add(tSubList)
        tSubList = []
      end if
    end repeat
    tVarStringList = []
    repeat with j = 1 to tList.count
      tVariable = chars(tString, tList[j][1] + 1, tList[j][2] - 1)
      tVarStringList.add(GetStringVariable(0, tVariable))
    end repeat
    repeat with k = tList.count down to 1
      tAmount = tList[k][2] - tList[k][1] + 1
      repeat with m = 1 to tAmount
        delete char tList[k][1] of tString
      end repeat
      put tVarStringList[k] before tString.char[tList[k][1]]
    end repeat
    if (gSystem.local = 0) and (tString contains "\") then
      tString = FormatURL(0, tString)
    end if
    return tString
  else
    if (gSystem.local = 0) and (tString contains "\") then
      tString = FormatURL(0, tString)
    end if
    return tString
  end if
end

on GetStringVariable me, tString
  if tString.char[1] = ":" then
    delete char 1 of tString
  end if
  if voidp(gGame[symbol(tString)]) = 0 then
    return string(gGame[symbol(tString)])
  end if
  if voidp(gSystem[symbol(tString)]) = 0 then
    return string(gSystem[symbol(tString)])
  end if
end

on FormatURL me, tString
  repeat with i = 1 to tString.length
    tChar = tString.char[i]
    if tChar = "\" then
      put "/" into tString.char[i]
    end if
  end repeat
  return tString
end

on SetItemDelimiter me, tChar
  the itemDelimiter = tChar
end

on ResetItemDelimiter me
  the itemDelimiter = gSystem.itemDelimiter
end

on RemoveSpaces me, tString
  if tString.ilk <> #string then
    return 0
  end if
  if tString contains SPACE then
    nothing()
  else
    return 0
  end if
  tNewString = EMPTY
  repeat with i = 1 to tString.length
    tChar = tString.char[i]
    if tChar = SPACE then
      next repeat
      next repeat
    end if
    tNewString = tNewString & tChar
  end repeat
  return tNewString
end
