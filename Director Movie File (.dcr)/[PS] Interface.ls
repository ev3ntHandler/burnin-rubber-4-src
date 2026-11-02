-- [Script] [PS] Interface (Script #5868)
-- Script Type: Parent

property p
global gSystem, gGame

on new me, tDataList
  p = [:]
  p[#member] = member(tDataList[#member])
  tmodel = p.member.model("Interface")
  tCount = tmodel.child.count
  repeat with i = 1 to tCount
    tmodel.child[i].parent = VOID
  end repeat
  tList = ["TicketMaster", "TuneShop", "WeaponShop", "SprayShop", "SafeHouse", "SpecialMission", "DailyChallenge", "Misc", "Results"]
  repeat with i in tList
    p.member.model(i).parent = VOID
  end repeat
  p[#CurrentTarget] = 1
  p[#previousTarget] = #none
  p[#Speedo] = 0
  p[#timer] = 0
  p[#Targets] = 0
  p[#position] = 0
  p[#Weapons] = 0
  p[#Tickets] = 0
  p[#progress] = 0
  p[#shader] = p.member.shader("Interface_Material")
  p[#RedShader] = DuplicateShader(0, p.member.name, [#shader: "Interface_Material", #shaderTag: "Red"])
  p.RedShader.emissive = rgb(220, 30, 30)
  p.RedShader.diffuse = rgb(220, 30, 30)
  p.RedShader.useDiffuseWithTexture = 1
  p[#BlackShader] = DuplicateShader(0, p.member.name, [#shader: "Interface_Material", #shaderTag: "Black"])
  p.BlackShader.emissive = rgb(0, 0, 0)
  p.BlackShader.diffuse = rgb(0, 0, 0)
  p.BlackShader.useDiffuseWithTexture = 1
  p[#GreyShader] = DuplicateShader(0, p.member.name, [#shader: "Interface_Material", #shaderTag: "Grey"])
  p.GreyShader.emissive = rgb(85, 85, 85)
  p.GreyShader.diffuse = rgb(85, 85, 85)
  p.GreyShader.useDiffuseWithTexture = 1
  p[#GreyShader] = DuplicateShader(0, p.member.name, [#shader: "SprayShopSkins_Material", #shaderTag: "Grey"])
  p.GreyShader.emissive = rgb(85, 85, 85)
  p.GreyShader.diffuse = rgb(85, 85, 85)
  p.GreyShader.useDiffuseWithTexture = 1
  tList = [#SafeHouse: rgb(38, 87, 143), #TuneShop: rgb(22, 51, 19), #WeaponShop: rgb(101, 10, 13), #SprayShop: rgb(192, 18, 100)]
  repeat with i = 1 to tList.count
    tProp = tList.getPropAt(i)
    tShader = DuplicateShader(0, p.member.name, [#shader: "Interface_Material", #shaderTag: string(tProp)])
    tShader.emissive = tList[i]
    tShader.diffuse = tList[i]
    tShader.useDiffuseWithTexture = 1
  end repeat
  p[#VisibilityList] = ["InterfaceOverlay"]
  if gGame.trackInfo.interface.ilk = #string then
    gGame.trackInfo.interface = [gGame.trackInfo.interface]
  end if
  repeat with i in gGame.trackInfo.interface
    case i of
      "SpeedoMeter":
        p.VisibilityList.add("Interface" & i)
        me.SetupSpeedo()
      "Timer":
        p.VisibilityList.add("Interface" & i)
        me.SetupTimer()
      "Targets":
        p.VisibilityList.add("Interface" & i)
        me.SetupTargets()
      "Position":
        p.VisibilityList.add("Interface" & i)
        me.SetupPosition()
      "Weapons":
        p.VisibilityList.add("Interface" & i)
        me.SetupWeapons()
      "Money":
        p.VisibilityList.add(i)
        me.SetupMoney()
      "Tickets":
        p.VisibilityList.add(i)
        me.SetupTickets()
      "Keys":
        p.VisibilityList.add("Interface" & i)
    end case
  end repeat
  p.member.model("InterfaceOverlay").transform.scale = vector(1.01000000000000001, 1.01000000000000001, 1.01000000000000001)
  gGame[#interface] = me
  return me
end

on enterFrame me
  if voidp(gGame[#vehicles]) = 1 then
    return 0
  end if
  if gGame.vehicles.count = 0 then
    return 0
  end if
  t = gGame.vehicles[1]
  if p.Speedo = 1 then
    tString = "00" & string(integer(abs(t.Vehicle.Speed) * 3600) / 1000)
    tString = tString.char[tString.length - 2..tString.length]
    repeat with i = 1 to 3
      tValue = value(tString.char[i])
      p.SpeedoModels[i].resource = p.member.modelResource("InterfaceNumbersDigital" & tValue)
    end repeat
  end if
  if p.timer = 1 then
    if voidp(gGame[#timer]) = 0 then
      tMillisec = gGame.timer
      sec = integer(tMillisec / 1000)
      min = integer(sec / 60)
      sec = sec - (min * 60)
      Hour = integer(min / 60)
      min = min - (Hour * 60)
      minString = string(min + 100).char[3..3]
      secString = string(sec + 100).char[2..3]
      MilliString = "00" & string(integer(tMillisec - (sec * 1000) - (min * 60 * 1000) - (Hour * 60 * 60 * 1000)))
      MilliString = MilliString.char[MilliString.length - 2..MilliString.length]
      tString = minString & secString & MilliString
      repeat with i = 1 to 6
        p.TimerModels[i].resource = p.member.modelResource("InterfaceNumbersDigital" & tString.char[i])
        if (tMillisec <= 10000) and (gGame.trackInfo.GameMode <> "Battle") then
          p.TimerModels[i].shader = p.RedShader
          next repeat
        end if
        p.TimerModels[i].shader = p.shader
      end repeat
      if (tMillisec <= 10000) and (gGame.trackInfo.GameMode <> "Battle") then
        p.TimerDigitModel.shader = p.RedShader
      else
        p.TimerDigitModel.shader = p.shader
      end if
    end if
  end if
  if p.position = 1 then
    tList = []
    repeat with i in gGame.vehicles
      tEntry = [i.race.Waypoints, -i.race.perpDistance, i.general.tag]
      tList.add(tEntry)
    end repeat
    tList.sort()
    tCount = tList.count
    repeat with i = 1 to tCount
      gGame.vehicles[tList[i][3]].race.position = tCount + 1 - i
    end repeat
    p.PlayerPosModel.resource = p.member.modelResource("InterfaceNumbersWhite" & t.race.position)
  end if
  if (p.Targets = 1) and (gGame.Scene = "Track") then
    me.UpdateTargets(gGame.AIsKilled, gGame.vehicles.count - 1)
  end if
  if (p.Weapons = 1) and (voidp(t[#Weapons]) = 0) then
    if p.WeaponsUpdated = 0 then
      me.UpdateWeaponsData()
    end if
    tString = "00" & string(integer(p.primData.ammo[1]))
    p.primModels[1].resource = p.member.modelResource("InterfaceNumbersDigital" & tString.char[tString.length - 1])
    p.primModels[2].resource = p.member.modelResource("InterfaceNumbersDigital" & tString.char[tString.length])
    p.primModels[3].resource = p.member.modelResource("InterfaceAmmoSlots" & p.primData.clips)
    if p.primData.clips <= 0 then
      p.primModels[1].shader = p.RedShader
      p.primModels[2].shader = p.RedShader
    else
      p.primModels[1].shader = p.shader
      p.primModels[2].shader = p.shader
    end if
    tString = "00" & string(integer(p.secData.ammo[1]))
    p.secModels[1].resource = p.member.modelResource("InterfaceNumbersDigital" & tString.char[tString.length - 1])
    p.secModels[2].resource = p.member.modelResource("InterfaceNumbersDigital" & tString.char[tString.length])
    p.secModels[3].resource = p.member.modelResource("InterfaceAmmoSlots" & p.secData.clips)
    if p.secData.clips <= 0 then
      p.secModels[1].shader = p.RedShader
      p.secModels[2].shader = p.RedShader
    else
      p.secModels[1].shader = p.shader
      p.secModels[2].shader = p.shader
    end if
  end if
  if p.progress = 1 then
    if p.progressState <> #none then
      p.ProgressTimer[1] = p.ProgressTimer[1] + 1
      repeat with i in p.ProgressArrowModels
        i.rotate(0, 0, 5, #self)
      end repeat
      if p.ProgressTimer[1] = p.ProgressTimer[2] then
        me.HideProgress()
      end if
    end if
  end if
end

on SetupSpeedo me
  put "--> --> SetupSpeedo (Handler)"
  p.Speedo = 1
  p[#SpeedoModels] = [p.member.model("InterfaceSpeedometerCounterPosition1"), p.member.model("InterfaceSpeedometerCounterPosition2"), p.member.model("InterfaceSpeedometerCounterPosition3")]
end

on SetupTimer me, tType
  put "--> --> SetupTimer (Handler)"
  p.timer = 1
  p[#TimerModels] = []
  repeat with i = 1 to 6
    tmodel = p.member.model("InterfaceTimerPosition" & i)
    if tmodel <> VOID then
      p.TimerModels.add(tmodel)
    end if
  end repeat
  p[#TimerDigitModel] = p.member.model("InterfaceNumbersDigital:")
  p[#TimerShaderSwitch] = 0
end

on resetTimer me, tType
  put "--> --> ResetTimer (Handler)"
  p.timer = 0
end

on SetupWeapons me
  put "--> --> SetupWeapons (Handler)"
  p.Weapons = 1
  p[#primData] = [:]
  p[#secData] = [:]
  p[#primModels] = [p.member.model("InterfacePrimaryWeaponCounterPosition1"), p.member.model("InterfacePrimaryWeaponCounterPosition2"), p.member.model("InterfacePrimaryWeaponSlots")]
  p[#secModels] = [p.member.model("InterfaceSecondaryWeaponCounterPosition1"), p.member.model("InterfaceSecondaryWeaponCounterPosition2"), p.member.model("InterfaceSecondaryWeaponSlots")]
  p[#WeaponsUpdated] = 0
end

on SetupTargets me
  put "--> --> SetupTargets (Handler)"
  p.Targets = 1
  p[#CurrentTargets] = [p.member.model("InterfaceTargetsCounterPlayer1"), p.member.model("InterfaceTargetsCounterPlayer2")]
  p[#TotalTargets] = [p.member.model("InterfaceTargetsCounterTotal1"), p.member.model("InterfaceTargetsCounterTotal2")]
  me.UpdateTargets(0, 0)
end

on SetupPosition me
  put "--> --> SetupPosition (Handler)"
  p.position = 1
  p[#PlayerPosModel] = p.member.model("InterfacePositionCounterPlayer")
  p[#TotalPlayersModel] = p.member.model("InterfacePositionCounterTotal")
  p.TotalPlayersModel.resource = p.member.modelResource("InterfaceNumbersWhite" & gGame.vehicles.count)
end

on SetupMoney me
  put "--> --> SetupMoney (Handler)"
  me.UpdateMoney()
end

on SetupTickets me
  put "--> --> SetupTickets (Handler)"
  p.Tickets = 1
  p[#TicketModels] = [p.member.model("TicketsCounterPosition1"), p.member.model("TicketsCounterPosition2")]
  p[#TicketTotalModels] = [p.member.model("TicketsTotalCounterPosition1"), p.member.model("TicketsTotalCounterPosition2")]
  me.UpdateTickets()
end

on UpdateWeaponsData me
  t = gGame.vehicles[1]
  if voidp(t[#Weapons]) = 1 then
    return 0
  end if
  p[#primData] = t.Weapons[symbol(t.general.data.Weapons.primary)]
  p[#secData] = t.Weapons[symbol(t.general.data.Weapons.secondary)]
  p.member.model("InterfacePrimaryWeaponType").resource = p.member.modelResource("Interface" & t.general.data.Weapons.primary)
  p.member.model("InterfaceSecondaryWeaponType").resource = p.member.modelResource("Interface" & t.general.data.Weapons.secondary)
  p.WeaponsUpdated = 1
end

on UpdateMoney me, tTarget, tDataList
  put "--> UpdateMoney (Handler)"
  tString = FormatMoney(0, string(gGame.money))
  tAlign = #right
  if tDataList = VOID then
    tDataList = [:]
  end if
  if tDataList[#align].ilk = #symbol then
    tAlign = tDataList.align
  end if
  tTexture = CreateTextTexture(0, "Interface", [#tag: #MoneyText, #style: #money, #text: tString, #align: tAlign])
end

on UpdateTickets me
  put "--> UpdateTickets (Handler)"
  if p.Tickets = 0 then
    me.SetupTickets()
    return 0
  end if
  tString = string(gGame.UpChallengesCompleted.count)
  if tString.length < 2 then
    tString = "0" & tString
  end if
  repeat with i = 1 to p.TicketModels.count
    tValue = value(tString.char[i])
    p.TicketModels[i].resource = p.member.modelResource("InterfaceNumbersWhite" & tValue)
    p.TicketModels[i].shader = p.shader
  end repeat
  tString = string(gGame.UPTickets.count + gGame.UPBossTickets.count)
  if tString.length < 2 then
    tString = "0" & tString
  end if
  repeat with i = 1 to p.TicketTotalModels.count
    tValue = value(tString.char[i])
    p.TicketTotalModels[i].resource = p.member.modelResource("InterfaceNumbersWhite" & tValue)
    p.TicketTotalModels[i].shader = p.shader
  end repeat
end

on UpdateTargets me, tCurrent, tTotal
  if tCurrent < 10 then
    tCurrent = "0" & string(tCurrent)
  else
    tCurrent = string(tCurrent)
  end if
  p.CurrentTargets[1].resource = p.member.modelResource("InterfaceNumbersWhite" & tCurrent.char[1])
  p.CurrentTargets[2].resource = p.member.modelResource("InterfaceNumbersWhite" & tCurrent.char[2])
  if tTotal < 10 then
    tTotal = "0" & string(tTotal)
  else
    tTotal = string(tTotal)
  end if
  p.TotalTargets[1].resource = p.member.modelResource("InterfaceNumbersWhite" & tTotal.char[1])
  p.TotalTargets[2].resource = p.member.modelResource("InterfaceNumbersWhite" & tTotal.char[2])
end

on AddToInterfaceList me, tTarget
  p.VisibilityList.add(tTarget)
end

on RemoveFromInterfaceList me, tTarget
  if p.VisibilityList.getPos(tTarget) <> 0 then
    p.VisibilityList.deleteOne(tTarget)
  end if
end

on ShowCurrentInterface me, tTarget, tDataList
  put "--> ShowCurrentInterface (Handler)"
  SETVISIBLE(0, "Interface", [#model: p.VisibilityList, #state: 1, #parent: "World"])
end

on HideCurrentInterface me, tTarget, tDataList
  put "--> HideCurrentInterface (Handler)"
  tList = p.VisibilityList.duplicate()
  if tDataList[#exclude].ilk = #list then
    repeat with i in tDataList.exclude
      tList.deleteOne(i)
    end repeat
  end if
  SETVISIBLE(0, "Interface", [#model: tList, #state: 0])
end

on SetupProgress me
  p[#ProgressArrowModels] = [p.member.model("InterfaceProgressArrow"), p.member.model("InterfaceProgressArrowDropShadow")]
  p[#ProgressMessageModels] = [p.member.model("InterfaceProgressMessage"), p.member.model("InterfaceProgressMessageDetail")]
  p[#progressState] = #none
  p[#ProgressTimer] = [0, 90]
  p[#progress] = 1
  gGame[#progressState] = #none
end

on ResetProgress me
  repeat with i in p.ProgressArrowModels
    i.transform.rotation = vector()
  end repeat
  p.progressState = #none
  p.ProgressTimer = [0, 90]
  if gGame.progressState = #LOADING then
    me.ShowLoadProgress(EMPTY, [#detail: #world])
  end if
end

on ShowSaveProgress me
  if p.progress = 0 then
    me.SetupProgress()
  end if
  p.ProgressMessageModels[1].resource = p.member.modelResource("InterfaceSavingMessage")
  p.ProgressMessageModels[1].shader = p.member.shader("Interface_Material")
  p.ProgressMessageModels[2].visibility = #none
  p.member.model("InterfaceProgress").parent = p.member.group("World")
  if p.VisibilityList.getPos("InterfaceProgress") = 0 then
    p.VisibilityList.add("InterfaceProgress")
  end if
  p.progressState = #saving
  p.ProgressTimer = [0, 90]
end

on HideSaveProgress me
end

on ShowLoadProgress me, tTarget, tDataList
  if p.progress = 0 then
    me.SetupProgress()
  end if
  tDetail = #none
  if (tDataList[#detail].ilk = #symbol) or (tDataList[#detail].ilk = #string) then
    tDetail = symbol(tDataList.detail)
  end if
  p.ProgressMessageModels[1].resource = p.member.modelResource("InterfaceLoadingMessage")
  p.ProgressMessageModels[1].shader = p.member.shader("Interface_Material")
  if tDetail = #none then
    p.ProgressMessageModels[2].visibility = #none
  else
    p.ProgressMessageModels[2].visibility = #front
    p.ProgressMessageModels[2].resource = p.member.modelResource("InterfaceLoadingMessage" & string(tDetail))
    p.ProgressMessageModels[2].shader = p.member.shader("Interface_Material")
  end if
  p.member.model("InterfaceProgress").parent = p.member.group("World")
  if p.VisibilityList.getPos("InterfaceProgress") = 0 then
    p.VisibilityList.add("InterfaceProgress")
  end if
  p.progressState = #LOADING
  gGame.progressState = #LOADING
  p.ProgressTimer = [0, -1]
end

on HideLoadProgress me
  gGame.progressState = #none
  me.HideProgress()
end

on HideProgress me
  p.member.model("InterfaceProgress").parent = VOID
  if p.VisibilityList.getPos("InterfaceProgress") <> 0 then
    p.VisibilityList.deleteOne("InterfaceProgress")
  end if
  me.ResetProgress()
end

on delete me
  p = [:]
  gGame.deleteProp(#interface)
  gGame.deleteProp(#progressState)
  if gSystem.scriptList.getPos(me) <> 0 then
    gSystem.scriptList.deleteOne(me)
  else
    gGame.scriptList.deleteOne(me)
  end if
end
