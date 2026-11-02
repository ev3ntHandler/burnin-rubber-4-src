-- [Script] [M] File & System (Script #6135)
-- Script Type: Movie

on GetFolderContents me, tPath
  tList = []
  repeat with i = 1 to 200
    tFile = getNthFileNameInFolder(tPath, i)
    if tFile = EMPTY then
      exit repeat
    end if
    if tFile contains "svn" then
      next repeat
    end if
    tList.add(tFile)
  end repeat
  return tList
end

on ConvertPath me, tTarget, tDataList
  if tTarget = VOID then
    return 0
  end if
  if tTarget.ilk <> #string then
    return 0
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tType = #local
  if tDataList[#type].ilk = #symbol then
    tList = [#local, #url]
    if tList.getPos(tDataList.type) <> 0 then
      tType = tDataList.type
    end if
  end if
  case tType of
    #local:
      c = ["/", "\"]
    #url:
      c = ["\", "/"]
  end case
  tString = EMPTY
  tLength = tTarget.length
  repeat with i = 1 to tLength
    if tTarget.char[i] = c[1] then
      tString = tString & c[2]
      next repeat
    end if
    tString = tString & tTarget.char[i]
  end repeat
  return tString
end
