-- [Script] [M] Vehicle Manager (Script #5859)
-- Script Type: Movie

global gSystem, gGame, gData

on VehicleManagerImportSet me, tTarget, tDataList
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tScript = GetScript(0, EMPTY, [#script: "Vehicle Manager"])
  if tScript <> 0 then
    tScript.ImportSet(EMPTY, tDataList)
  end if
end

on VehicleManagerDownloadSet me, tTarget, tDataList
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tScript = GetScript(0, EMPTY, [#script: "Vehicle Manager"])
  if tScript <> 0 then
    tScript.SetNext(EMPTY, tDataList)
  end if
end

on RestoreVehiclesLoadingData me
  gData.data.VehiclesLoadingData = [:]
  repeat with i = 1 to gData.data.VehiclesLoadingDataSource.count
    tProp = gData.data.VehiclesLoadingDataSource.getPropAt(i)
    gData.data.VehiclesLoadingData.addProp(tProp, gData.data.VehiclesLoadingDataSource[i])
  end repeat
end

on AuthorVehicleLoading me
  if _player.runMode <> "Author" then
    return
  end if
  PutMessage(0, "AUTHOR VEHICLE LOADING")
  gSystem.local = 1
  load(0, "\Vehicles\TrackVehiclesLoadingArray.txt", [:])
  gSystem.local = 0
end
