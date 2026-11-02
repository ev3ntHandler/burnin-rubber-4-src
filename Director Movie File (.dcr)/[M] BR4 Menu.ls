-- [Script] [M] BR4 Menu (Script #5861)
-- Script Type: Movie

global gGame, gData

on MenuPrepareIntroAndStart me
  tScript = GetScript(0, EMPTY, [#script: "BR4 Menu"])
  if tScript <> 0 then
    tScript.PrepareIntroAndStart()
  end if
end

on MenuStartIntro me
  tScript = GetScript(0, EMPTY, [#script: "BR4 Menu"])
  if tScript <> 0 then
    tScript.startAnimation()
  end if
end

on MenuStorePosition me
  tScript = GetScript(0, EMPTY, [#script: "BR4 Menu"])
  if tScript <> 0 then
    tScript.StorePosition()
  end if
end

on MenuSetState me, tTarget, tDataList
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tScript = GetScript(0, EMPTY, [#script: "BR4 Menu"])
  if tScript <> 0 then
    tScript.setState(EMPTY, tDataList)
  end if
end

on MenuSetCamera me, tTarget, tDataList
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tScript = GetScript(0, EMPTY, [#script: "BR4 Menu"])
  if tScript <> 0 then
    tScript.setCamera(EMPTY, tDataList)
  end if
end

on MenuSetCameraTarget me, tTarget, tDataList
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tScript = GetScript(0, EMPTY, [#script: "BR4 Menu"])
  if tScript <> 0 then
    tScript.SetCameraTarget(EMPTY, tDataList)
  end if
end

on MenuSetCameraRootNode me, tTarget, tDataList
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tScript = GetScript(0, EMPTY, [#script: "BR4 Menu"])
  if tScript <> 0 then
    tScript.SetCameraRootNode(EMPTY, tDataList)
  end if
end

on MenuSetCameraSettings me, tTarget, tDataList
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tScript = GetScript(0, EMPTY, [#script: "BR4 Menu"])
  if tScript <> 0 then
    tScript.SetCameraSettings(EMPTY, tDataList)
  end if
end

on MenuSetEvent me, tTarget, tDataList
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tScript = GetScript(0, EMPTY, [#script: "BR4 Menu"])
  if tScript <> 0 then
    tScript.SetEvent(EMPTY, tDataList)
  end if
end

on MenuSetShader me, tTarget, tDataList
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tScript = GetScript(0, EMPTY, [#script: "BR4 Menu"])
  if tScript <> 0 then
    tScript.SetShader(EMPTY, tDataList)
  end if
end
