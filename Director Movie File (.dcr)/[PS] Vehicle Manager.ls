-- [Script] [PS] Vehicle Manager (Script #5860)
-- Script Type: Parent

property p
global gSystem, gData, gGame

on new me, tDataList
  p = [:]
  p[#ScriptName] = "Vehicle Manager"
  tState = 1
  if (gGame.VehiclesLoaded.Set1 = #done) and (gGame.VehiclesLoaded.Set1 = #done) and (gGame.VehiclesLoaded.Set1 = #done) then
    tState = 0
  else
    tScript = GetScript(0, EMPTY, [#script: "Vehicle Manager"])
    if tScript <> 0 then
      tState = 0
    end if
  end if
  if tState = 0 then
    event(0, #SetupWorldVehicleMangerOverride)
    return 0
  end if
  p[#member] = member(tDataList.member)
  if p.member = VOID then
    return 0
  end if
  p[#state] = #none
  tSet1 = [gGame.car, "SpeedBoat", "Zodiac", "Apache"]
  repeat with i in gGame.AvailableTraffic
    tSet1.add(i)
  end repeat
  tSet2 = gGame.UPCars.duplicate()
  repeat with i in tSet1
    tSet2.deleteOne(i)
  end repeat
  tSet3 = []
  tList = [#AvailableCars, #availableBoats, #availablePlanes]
  repeat with i in tList
    repeat with j in gGame[i]
      if tSet1.getPos(j) <> 0 then
        next repeat
      end if
      if tSet2.getPos(j) <> 0 then
        next repeat
      end if
      tSet3.add(j)
    end repeat
  end repeat
  p[#set] = 1
  p[#type] = #model
  tEvents = ["ImportVehicleSet1", "WorldVehicleSetup", "WorldManagerSetState", "WorldManagerInitTileAndGrid", "DownloadVehicleSet2"]
  p[#LoadList] = [#Set1: [#state: #hold, #vehicles: tSet1, #event: tEvents], #Set2: [#state: #hold, #vehicles: tSet2, #event: ["DownloadVehicleSet3"]], #Set3: [#state: #hold, #vehicles: tSet3, #event: [EMPTY]]]
  p[#ImportList] = [#Set1: [#state: #hold, #vehicles: [], #event: [EMPTY]], #Set2: [#state: #hold, #vehicles: [], #event: [EMPTY]], #Set3: [#state: #hold, #vehicles: [], #event: [EMPTY]]]
  p[#file] = [#Vehicle: #none, #data: [:], #model: [], #texture: []]
  p[#NetID] = #none
  p[#error] = "none"
  p[#debug] = 0
  me.LoadNext()
  return me
end

on enterFrame me
  if p.state = #LOADING then
    if gSystem.local = 1 then
      if p.debug = 1 then
        me.DisplayFile(p.file[p.type][1], #load)
      end if
      p.file.data[p.type].add(p.file[p.type][1])
      p.file[p.type].deleteAt(1)
      if (p.type = #model) and (p.file.model.count = 0) then
        p.type = #texture
      else
        if (p.type = #texture) and (p.file.texture.count = 0) then
          me.FinishNext()
        end if
      end if
    else
      if p.NetID = #none then
        p.NetID = preloadNetThing(p.file[p.type][1])
      else
        if (netDone(p.NetID) = 1) and (netError(p.NetID) = "OK") then
          if p.debug = 1 then
            me.DisplayFile(p.file[p.type][1], #load)
          end if
          p.file.data[p.type].add(p.file[p.type][1])
          p.file[p.type].deleteAt(1)
          p.NetID = #none
        else
          if netError(p.NetID) <> EMPTY then
            p.error = GetNetIDError(0, netError(p.NetID))
            put "[Vehicle Manager]. Error downloading: " & string(p.file[p.type][1]) & " Error was: " & p.error
            p.file[p.type].deleteAt(1)
            p.NetID = #none
          end if
        end if
        if (p.type = #model) and (p.file.model.count = 0) then
          p.type = #texture
        else
          if (p.type = #texture) and (p.file.texture.count = 0) then
            me.FinishNext()
          end if
        end if
      end if
    end if
  end if
end

on LoadNext me
  p.LoadList[p.set].state = #LOADING
  tList = p.LoadList[p.set]
  gGame.VehiclesLoaded[p.set] = #LOADING
  tVehicle = tList.vehicles[1]
  tData = gData.data.VehiclesLoadingData[symbol(tVehicle)]
  tModelPath = _movie.path & tData.loc & "3d/"
  tTexturePath = _movie.path & tData.loc & "Textures/"
  if gSystem.local = 1 then
    tModelPath = ConvertPath(0, tModelPath, [#type: #local])
    tTexturePath = ConvertPath(0, tTexturePath, [#type: #local])
  end if
  tData.model.add(tVehicle & ".W3D")
  repeat with i = 1 to tData.amount
    tData.texture.add(tVehicle & "Skin" & i & "_Texture.png")
  end repeat
  tData.texture.add(tVehicle & "Shadow_Texture.png")
  if member("Wheels_Texture", "Vehicles") = VOID then
    if tVehicle = gGame.car then
      tData.texture.add("Wheels_Texture.png")
    end if
  end if
  repeat with i = 1 to tData.model.count
    tData.model[i] = tModelPath & tData.model[i]
  end repeat
  repeat with i = 1 to tData.texture.count
    tData.texture[i] = tTexturePath & tData.texture[i]
  end repeat
  p.file.model = tData.model.duplicate()
  p.file.texture = tData.texture.duplicate()
  tData.model = []
  tData.texture = []
  p.file.Vehicle = tVehicle
  p.file.data = tData
  tList.vehicles.deleteAt(1)
  p.state = #LOADING
  p.type = #model
end

on FinishNext me
  p.ImportList[p.set].vehicles.add(p.file.Vehicle)
  if p.LoadList[p.set].vehicles.count = 0 then
    PutMessage(0, "[Vehicle Manager] #Set" & p.set & " downloaded.")
    p.LoadList[p.set].state = #ready
    gGame.VehiclesLoaded[p.set] = #ready
    p.file = [#Vehicle: #none, #data: [:], #model: [], #texture: []]
    p.state = #none
    repeat with i in p.LoadList[p.set].event
      event(0, symbol(i))
    end repeat
  else
    if p.set < 4 then
      me.LoadNext()
    end if
  end if
end

on SetNext me
  p.set = p.set + 1
  if p.set > 3 then
    p.state = #done
  else
    me.LoadNext()
  end if
end

on ImportSet me, tTarget, tDataList
  tSet = tDataList.set
  tType = #model
  if gSystem.local = 1 then
    the itemDelimiter = "\"
  else
    the itemDelimiter = "/"
  end if
  if p.LoadList[tSet].state = #LOADING then
    put "Still downloading..."
  else
    tList = p.ImportList[tSet]
    repeat with i in tList.vehicles
      tData = gData.data.VehiclesLoadingData[symbol(i)]
      repeat with j in tData.model
        the itemDelimiter = "/"
        tName = j.item[j.item.count]
        the itemDelimiter = "."
        tName = tName.item[1]
        tmember = createMember(0, EMPTY, [#type: #shockwave3d, #cast: "Vehicles"])
        tImported = tmember.importFileInto(j)
        tmember.name = tName
        if tImported = 0 then
          tmember.erase()
          next repeat
        end if
        if p.debug = 1 then
          me.DisplayFile(j, #import)
        end if
      end repeat
      repeat with j in tData.texture
        the itemDelimiter = "/"
        tName = j.item[j.item.count]
        the itemDelimiter = "."
        tName = tName.item[1]
        tmember = createMember(0, EMPTY, [#type: #bitmap, #cast: "Vehicles"])
        tImported = tmember.importFileInto(j, [#dither: 0, #trimWhiteSpace: 0, #remapImageToStage: 0])
        tmember.name = tName
        if tImported = 0 then
          tmember.erase()
        else
          if p.debug = 1 then
            me.DisplayFile(j, #import)
          end if
        end if
        if gGame[#HighResCarTextures] = 0 then
          if tName contains "Skin" then
            if (tmember.width = 1024) and (tmember.height = 1024) then
              tImageHolder = image(512, 512, 32, 0)
              tSourceImage = tmember.image
              tImageHolder.copyPixels(tSourceImage, tImageHolder.rect, tSourceImage.rect)
              tmember.image = tImageHolder
              tmember.name = tName
            end if
          end if
        end if
        tmember.purgePriority = 0
      end repeat
      tData.state = 1
    end repeat
    p.ImportList[tSet].state = #done
    gGame.VehiclesLoaded[tSet] = #done
    PutMessage(0, "[Vehicle Manager] #Set" & tSet & " imported.")
  end if
end

on DisplayFile me, tFile, tState
  if gSystem.local = 1 then
    the itemDelimiter = "\"
  else
    the itemDelimiter = "/"
  end if
  if tState = #load then
    PutMessage(0, tFile.item[tFile.item.count] & " downloaded successfully.")
  end if
  if tState = #import then
    PutMessage(0, tFile.item[tFile.item.count] & " imported successfully.")
  end if
end

on delete me
  p = [:]
  if gSystem.scriptList.getPos(me) <> 0 then
    gSystem.scriptList.deleteOne(me)
  else
    gGame.scriptList.deleteOne(me)
  end if
end
