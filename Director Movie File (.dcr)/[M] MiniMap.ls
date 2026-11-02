-- [Script] [M] MiniMap (Script #5869)
-- Script Type: Movie

property p
global gSystem, gLoader, gData, gGame

on AddMarker me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tVector = VOID
  if tDataList[#position].ilk = #vector then
    tVector = tDataList.position
  end if
  if tDataList[#position].ilk = #string then
    tMarker = GetTile(0, symbol(tDataList.position), 0, 1)
    if tMarker = #none then
      return 0
    end if
    tVector = gData.data[symbol(gGame.world & "Markers")][symbol(tMarker)][symbol(tDataList.position)][1][1]
  end if
  if tVector = VOID then
    return 0
  end if
  tTypeList = [#default, #SafeHouse, #SprayShop, #WeaponShop, #TuneShop, #TicketMaster, #Ticket, #SpecialMission, #BossEnd, #SwitchToCar, #red, #SwitchToBoat, #SwitchToHelicopter, #SnowEntrance, #DesertEntrance, #CityEntrance, #JungleEntrance, #IndustrialEntrance, #TimeTrial, #Demolition, #Rampage, #DailyChallenge]
  if tDataList[#type].ilk = #symbol then
    if tTypeList.getPos(tDataList.type) = 0 then
      tDataList[#type] = #default
    end if
  else
    tDataList[#type] = #default
  end if
  tColorList = [#SafeHouse: rgb(69, 146, 233), #SprayShop: rgb(251, 87, 163), #WeaponShop: rgb(250, 46, 36), #TuneShop: rgb(121, 239, 68), #TicketMaster: rgb(252, 246, 73), #SpecialMission: rgb(250, 252, 231)]
  if tColorList[tDataList.type].ilk = #color then
    tColor = tColorList[tDataList.type]
  else
    tColor = rgb(255, 255, 255)
  end if
  if tDataList[#AddtoMinimap].ilk = #integer then
    tDataList.AddtoMinimap = tDataList.AddtoMinimap
  else
    tDataList[#AddtoMinimap] = 1
  end if
  tDataList[#name] = tDataList.position
  the itemDelimiter = "_"
  tMarkerName = tDataList.position.item[1]
  tActive = 1
  if tDataList[#Active].ilk = #integer then
    tActive = tDataList.Active
  end if
  if tmember.modelResource("WorldMarker") = VOID then
    CloneModel(0, tmember.name, [#sourceMember: ["WorldMarker", "WorldSkyMarker"], #hide: 1, #lod: 0])
    createTexture(0, tmember.name, [#texture: "WorldMarker_Texture", #renderFormat: #rgba8888, #filtering: #lowFiltered])
    SetShader(0, tmember.name, [#shader: "WorldMarker_Material", #texture1: "WorldMarker_Texture"])
  end if
  tResourceName = "WorldMarker"
  if (voidp(gGame[#TimeTrial]) = 0) and (gGame.Vehicle = "Helicopter") then
    tResourceName = "WorldSkyMarker"
  end if
  tMarker = tmember.newModel(tDataList.name, tmember.modelResource(tResourceName))
  tShader = DuplicateShader(0, tmember.name, [#shader: "WorldMarker_Material", #shaderTag: string(tDataList.type)])
  if tResourceName = "WorldMarker" then
    tOffsetList = [#TicketMaster, #SafeHouse, #SprayShop, #WeaponShop, #TuneShop, #SpecialMission, #empty, #empty]
    tPos = tOffsetList.getPos(tDataList.type)
    if (tDataList.type = #TimeTrial) or (tDataList.type = #Demolition) or (tDataList.type = #Rampage) then
      tPos = 4
    end if
    if tPos <> 0 then
      tShader.textureTransformList[1].position.y = 1.0 / tOffsetList.count * (tPos - 1)
    end if
    AddToScroller(0, tmember.name, [#shader: tShader.name, #position: vector(0.01, 0.0, 0.0)])
  else
    AddToBillBoard(0, tmember.name, [#model: tMarker.name, #camera: "Player1_Camera"])
  end if
  tMarker.shaderList = tShader
  tMarker.worldPosition = tVector
  if string(tDataList.type) contains "Entrance" then
    tMarker.transform.scale = vector(3.0, 3.0, 1.0)
  end if
  if tDataList.type = #JungleEntrance then
    tMarker.transform.scale = vector(1.75, 1.75, 1.0)
  end if
  tDistance = [5.5, 10]
  if string(tDataList.type) contains "Entrance" then
    tDistance = [15, 30]
  end if
  if tDataList.type = #JungleEntrance then
    tDistance = [8.75, 17.5]
  end if
  if (tDataList.type = #TimeTrial) and (gGame.Vehicle = "Helicopter") then
    tDistance = [20.0, 30.0]
  end if
  if tActive = 0 then
    tMarker.parent = VOID
  end if
  gGame.MiniMap.markerlist[symbol(tDataList.name)] = [#model: tMarker, #type: tDataList.type, #position: tDataList.position, #AddtoMinimap: tDataList.AddtoMinimap, #distance: tDistance, #name: tMarkerName, #Active: tActive]
  tPriority = #high
  if tDataList[#priority].ilk = #symbol then
    tPriority = tDataList.priority
  end if
  if tDataList[#AddtoMinimap] = 1 then
    AddMiniMapMarker(0, "MiniMap", [#type: tDataList.type, #position: tVector, #priority: tPriority, #name: tDataList.name])
  end if
end

on RemoveMarker me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  if voidp(gGame.MiniMap.markerlist[symbol(tDataList.name)]) = 1 then
    return 0
  end if
  tShader = tmember.model(tDataList.name)
  if tShader <> VOID then
    tmember.deleteShader(tShader.name)
  end if
  tmember.deleteModel(tDataList.name)
  if gGame.MiniMap.markerlist[symbol(tDataList.name)][#AddtoMinimap] = 1 then
    RemoveMiniMapMarker(0, "MiniMap", [#name: symbol("MiniMap" & tDataList.name)])
  end if
  gGame.MiniMap.markerlist.deleteProp(symbol(tDataList.name))
end

on GetBla me, tPos, tScale
  return (tPos / (2048.0 * 1.87000000000000011)) - (tScale * 0.27500000000000002)
end

on AddMiniMapMarker me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  if tDataList[#position].ilk <> #vector then
    return 0
  end if
  tTypeList = [#default, #player, #North, #SafeHouse, #SprayShop, #WeaponShop, #TuneShop, #TicketMaster, #Ticket, #SpecialMission, #BossEnd, #SwitchToCar, #red, #SwitchToBoat, #SwitchToHelicopter, #SnowEntrance, #DesertEntrance, #CityEntrance, #JungleEntrance, #IndustrialEntrance, #TimeTrial, #Demolition, #Rampage, #DailyChallenge]
  if tDataList[#type].ilk = #symbol then
    if tTypeList.getPos(tDataList.type) = 0 then
      tDataList[#type] = #default
    end if
  else
    tDataList[#type] = #default
  end if
  tEffectlist = [#scale, #highlight]
  if tDataList[#effect].ilk = #symbol then
    if tEffectlist.getPos(tDataList.effect) = 0 then
      tDataList[#effect] = #scale
    end if
  else
    tDataList[#effect] = #scale
  end if
  if tDataList[#start].ilk = #float then
    tDataList.start = tDataList.start
  else
    tDataList[#start] = 4.0
  end if
  if tDataList[#end].ilk = #integer then
    tDataList.end = tDataList.end
  else
    tDataList[#end] = 1.0
  end if
  if tDataList[#amount].ilk = 1 then
    tDataList.amount = 1
  else
    tDataList[#amount] = 1.0
  end if
  if tDataList[#time].ilk = #integer then
    tDataList.time = tDataList.time
  else
    tDataList[#time] = 2000
  end if
  tPriorityList = [#low, #medium, #high]
  if tDataList[#priority].ilk = #symbol then
    if tPriorityList.getPos(tDataList.priority) = 0 then
      tDataList[#priority] = #high
    end if
  else
    tDataList[#priority] = #high
  end if
  if tDataList[#name].ilk = #void then
    tDataList[#name] = "MiniMap" & string(tDataList.type) & "_Marker"
  else
    tDataList.name = "MiniMap" & tDataList.name
  end if
  tMarker = tmember.newModel(tDataList.name, tmember.modelResource(string(tDataList.type)))
  tMarker.shaderList = tmember.shader("MiniMapMarker_Material")
  tVector = tDataList.position
  tMarker.worldPosition = tVector
  tMarker.transform.scale = vector(1, 1, 1) * 3.0
  tUpdate = 0
  if tDataList[#update].ilk = #integer then
    tUpdate = tDataList.update
  end if
  tSourceModel = #none
  if tDataList[#sourceModel].ilk = #model then
    tSourceModel = tDataList.sourceModel
  end if
  gGame.MiniMap.MiniMapMarkerList[symbol(tDataList.name)] = [#model: tMarker, #type: tDataList.type, #priority: tDataList.priority, #position: tDataList.position, #update: tUpdate, #sourceModel: tSourceModel]
end

on RemoveMiniMapMarker me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  gGame.MiniMap.MiniMapMarkerList.deleteProp(tDataList.name)
  tmember.deleteModel(string(tDataList.name))
end

on ScaleMiniMapMarker me, tTarget, tDataList
  tmember = member("Minimap")
  tMarker = tmember.model(tTarget)
  if tMarker = VOID then
    false()
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tdiff = tDataList.start - tDataList.end
  tScale = tDataList.start - (tdiff * tDataList.Perc)
  tMarker.transform.scale = vector(tScale, tScale, tScale)
end

on HighlightMiniMapMarker me, tTarget, tDataList
  tmember = member("Minimap")
  tMarker = tmember.model(tTarget)
  if tMarker = VOID then
    false()
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tMarker.shader.blend = 100 - tDataList.blend
end

on SetBossEndMarker me
  put "--> SetBossEndMarker (Handler)"
end

on HideMiniMap me
  if voidp(gGame[#MiniMap]) = 0 then
    gGame.MiniMap.script.HideMiniMap()
  end if
end

on ShowMiniMap me
  if voidp(gGame[#MiniMap]) = 0 then
    gGame.MiniMap.script.ShowMiniMap()
  end if
end

on StoreAndHideCurrentMiniMap me
  put "--> StoreAndHideCurrentMiniMap (Handler)"
  repeat with i in gGame.MiniMap.markerlist
    i.model.visibility = #none
    i.Active = 0
  end repeat
  repeat with i in gGame.MiniMap.MiniMapMarkerList
    if (i.type = #North) or (i.type = #player) then
      next repeat
    end if
    i.model.visibility = #none
  end repeat
end

on RestoreAndShowCurrentMiniMap me
  put "--> StoreAndHideCurrentMiniMap (Handler)"
  repeat with i in gGame.MiniMap.markerlist
    i.model.visibility = #front
    i.Active = 1
  end repeat
  repeat with i in gGame.MiniMap.MiniMapMarkerList
    if (i.type = #North) or (i.type = #player) then
      next repeat
    end if
    i.model.visibility = #front
  end repeat
end
