-- [Script] [M] Cast (Script #6136)
-- Script Type: Movie

on ClearCast me, tCast
  if _movie.castLib(tCast) = VOID then
    LogMessage(0, "ClearCast" & TAB & "Cast: " & tCast & TAB & "This cast does not exist.")
    exit
  end if
  tCount = _movie.castLib(tCast).member.count
  EraseMembers(0, 1, tCount, tCast)
end

on ClearCasts me, tCastList
  if tCastList.ilk <> #list then
    LogMessage(0, "ClearCasts" & TAB & "CastList: " & tCastList & TAB & "Castlist was not a list.")
    exit
  end if
  tCount = tCastList.count
  repeat with i in tCastList
    if _movie.castLib(i) = VOID then
      LogMessage(0, "ClearCasts" & TAB & "CastList: " & tCastList & TAB & "Cast: " & i & " does not exist")
      next repeat
      next repeat
    end if
    tMemberCount = _movie.castLib(i).member.count
    EraseMembers(0, 1, tMemberCount, i)
  end repeat
end

on GetExternalCasts me
  tCount = _movie.castLib.count
  tList = []
  repeat with i = 1 to tCount
    tFileName = _movie.castLib[i].fileName
    if tFileName contains ".dir" then
      next repeat
    end if
    if tFileName contains ".dcr" then
      next repeat
    end if
    if tFileName contains ".dxr" then
      next repeat
    end if
    tList.add(_movie.castLib[i].name)
  end repeat
  return tList
end

on GetInternalCasts me
  tCount = _movie.castLib.count
  tList = []
  repeat with i = 1 to tCount
    tFileName = _movie.castLib[i].fileName
    if tFileName contains ".dir" then
      tList.add(_movie.castLib[i].name)
    end if
    if tFileName contains ".dcr" then
      tList.add(_movie.castLib[i].name)
    end if
    if tFileName contains ".dxr" then
      tList.add(_movie.castLib[i].name)
    end if
  end repeat
  return tList
end

on ShowCastNames me
  tCount = _movie.castLib.count
  repeat with i = 1 to tCount
    tName = _movie.castLib(i).name
    tFileName = _movie.castLib(i).fileName
    put tName && tFileName
  end repeat
end
