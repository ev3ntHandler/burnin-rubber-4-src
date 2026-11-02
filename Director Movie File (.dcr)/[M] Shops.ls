-- [Script] [M] Shops (Script #5866)
-- Script Type: Movie

global gSystem, gData, gGame

on ResetCurrentShop me
  put "--> ResetCurrentShop (Handler)"
  case gGame.CurrentShop of
    #TicketMaster:
      ResetTicketMaster()
    #WeaponShop:
      ResetWeaponShop()
    #TuneShop:
      ResetTuneShop()
    #SprayShop:
      ResetSprayShop()
    #SafeHouse:
      ResetSafeHouse()
    #SpecialMission:
      nothing()
  end case
  gGame.CurrentShop = #none
end

on SetupTotalCosts me
  gGame[#TotalCosts] = 0
  tString = FormatMoney(0, gGame.TotalCosts)
  if (gGame.CurrentShop = #WeaponShop) and (gGame.UPUnlockableCheats.getPos(#UnlimitedWeaponShop) <> 0) then
    tString = gData.data.text[#NoCharge]
  end if
  if (gGame.CurrentShop = #TuneShop) and (gGame.UPUnlockableCheats.getPos(#UnlimitedTuneShop) <> 0) then
    tString = gData.data.text[#NoCharge]
  end if
  if (gGame.CurrentShop = #SprayShop) and (gGame.UPUnlockableCheats.getPos(#UnlimitedSprayShop) <> 0) then
    tString = gData.data.text[#NoCharge]
  end if
  CreateTextTexture(0, "Interface", [#tag: #TotalCostHeaderText, #style: #TotalCostsSteakShop])
  CreateTextTexture(0, "Interface", [#tag: #TotalCostText, #style: #TotalCosts, #text: tString])
end

on UpdateTotalCosts me
  if gGame.TotalCosts > gGame.money then
    CreateTextTexture(0, "Interface", [#tag: #TotalCostText, #style: #TotalCosts, #text: FormatMoney(0, gGame.TotalCosts), #color: #red])
    DeleteButton(0, EMPTY, [#model: "RightButton"])
  else
    CreateTextTexture(0, "Interface", [#tag: #TotalCostText, #style: #TotalCosts, #text: FormatMoney(0, gGame.TotalCosts)])
  end if
  if gGame.TotalCosts = 0 then
    DeleteButton(0, EMPTY, [#model: "RightButton"])
  end if
end

on SetupTicketMaster me
  put "--> SetupTicketMaster (Handler)"
  gGame[#SelectedTicket] = #none
  tmember = member("Interface")
  repeat with i = 1 to 32
    tTicket = "Ticket" & i
    tButton = tmember.model("TicketMaster" & tTicket & "Button")
    tStatus = tmember.model("TicketMaster" & tTicket & "Status")
    tPrestige = tmember.model("TicketMaster" & tTicket & "Prestige")
    if gGame.UPTickets.getPos(tTicket) = 0 then
      tButton.shader = tmember.shader("BlackInterface_Material")
      SETVISIBLE(0, "Interface", [#model: [tStatus.name, tPrestige.name], #state: 0])
      next repeat
    end if
    tTrack = GetTrack(0, tTicket)
    tButton.shader = tmember.shader("GreyInterface_Material")
    CreateButton(0, "Interface", [#model: tButton.name, #handler: "SelectCurrentTicket", #effect: #shaderRollover, #shaders: ["GreyInterface_Material", "Interface_Material"]])
    SETVISIBLE(0, "Interface", [#model: tStatus.name, #state: 1, #parent: "TicketMaster"])
    if gGame.UpChallengesCompleted.getPos(tTrack) <> 0 then
      SetModel(0, "Interface", [#model: tStatus.name, #resource: "TicketCleared"])
    else
      SetModel(0, "Interface", [#model: tStatus.name, #resource: "TicketNew"])
    end if
    if gGame.UpChallengesPrestige.getPos(tTrack) = 0 then
      SetModel(0, "Interface", [#model: tPrestige.name, #resource: "TicketNew"])
      next repeat
    end if
    SetModel(0, "Interface", [#model: tPrestige.name, #resource: "TicketPrestigeCleared"])
  end repeat
  repeat with i = 1 to 4
    tTicket = "TicketBoss" & i
    tButton = tmember.model("TicketMaster" & tTicket & "Button")
    tStatus = tmember.model("TicketMaster" & tTicket & "Status")
    tPrestige = tmember.model("TicketMaster" & tTicket & "Prestige")
    if gGame.UPBossTickets.getPos(tTicket) = 0 then
      tButton.shader = tmember.shader("BlackInterface_Material")
      SETVISIBLE(0, "Interface", [#model: [tStatus.name, tPrestige.name], #state: 0])
      next repeat
    end if
    tTrack = GetTrack(0, tTicket)
    tButton.shader = tmember.shader("GreyInterface_Material")
    CreateButton(0, "Interface", [#model: tButton.name, #handler: "SelectCurrentTicket", #effect: #shaderRollover, #shaders: ["GreyInterface_Material", "Interface_Material"]])
    SETVISIBLE(0, "Interface", [#model: tStatus.name, #state: 1, #parent: "TicketMaster"])
    if gGame.UpChallengesCompleted.getPos(tTrack) <> 0 then
      SetModel(0, "Interface", [#model: tStatus.name, #resource: "TicketCleared"])
    else
      SetModel(0, "Interface", [#model: tStatus.name, #resource: "TicketNew"])
    end if
    if gGame.UpChallengesPrestige.getPos(tTrack) = 0 then
      SetModel(0, "Interface", [#model: tPrestige.name, #resource: "TicketNew"])
      next repeat
    end if
    SetModel(0, "Interface", [#model: tPrestige.name, #resource: "TicketPrestigeCleared"])
  end repeat
  if gGame.UpChallengesCompleted.count >= 36 then
    tStatus = tmember.model("TicketMasterTicketBossEndStatus")
    tPrestige = tmember.model("TicketMasterTicketBossEndPrestige")
    SETVISIBLE(0, "Interface", [#model: "TicketMasterTicketBossEndStatus", #state: 1, #parent: "TicketMaster"])
    tmember.model("TicketMasterTicketBossEndButton").shader = tmember.shader("Interface_Material")
    if gGame.UPSpecialMissionsCompleted.getPos("BossEnd") = 0 then
      SetModel(0, "Interface", [#model: tStatus.name, #resource: "TicketNew"])
    else
      SetModel(0, "Interface", [#model: tStatus.name, #resource: "TicketCleared"])
    end if
    if gGame.UpChallengesPrestige.getPos("BossEnd") = 0 then
      SETVISIBLE(0, "Interface", [#model: tPrestige.name, #state: 0, #parent: "TicketMaster"])
    else
      SETVISIBLE(0, "Interface", [#model: tPrestige.name, #state: 1, #parent: "TicketMaster"])
    end if
  else
    SETVISIBLE(0, "Interface", [#model: ["TicketMasterTicketBossEndStatus", "TicketMasterTicketBossEndPrestige"], #state: 0])
    tmember.model("TicketMasterTicketBossEndButton").shader = tmember.shader("GreyInterface_Material")
  end if
end

on ResetTicketMaster me
  put "--> ResetTicketMaster (Handler)"
  DeleteAllButtons()
end

on SelectCurrentTicket me
  put "--> SelectCurrentTicket (Handler)"
  tTicket = gGame.menu.PressedButton
  tTicket = tTicket.char[13..tTicket.length]
  tTicket = tTicket.char[1..tTicket.length - 6]
  tTrack = GetTrack(0, tTicket)
  gGame.track = tTrack
  UpdateTrackInfo()
  gGame.Assets = gGame.trackInfo.Assets
  if gGame.SelectedTicket <> #none then
    SetModel(0, "Interface", [#model: gGame.SelectedTicket, #shader: "GreyInterface_Material"])
    CreateButton(0, "Interface", [#model: gGame.SelectedTicket, #handler: "SelectCurrentTicket", #effect: #shaderRollover, #shaders: ["GreyInterface_Material", "Interface_Material"]])
  end if
  gGame.SelectedTicket = gGame.menu.PressedButton
  DeleteButton(0, EMPTY, [#model: gGame.menu.PressedButton])
  SetModel(0, "Interface", [#model: gGame.menu.PressedButton, #shader: "Interface_Material"])
  SetModel(0, "Interface", [#model: "TicketMasterTicketBigEvent", #resource: tTicket])
  CreateTextTexture(0, "Interface", [#tag: #TicketMasterTicketBigHeader, #style: #MiniResultsTrackName, #text: symbol(tTrack & "Title")])
  CreateTextTexture(0, "Interface", [#tag: #TicketMasterTicketBigGoal, #style: #MiniResultsGoal, #text: symbol("GameModeGoal" & gData.Info.trackInfo[symbol(tTrack)].GameMode)])
  tString = gData.data.text.PrestigeChallenge && GetPrestigeTime(0, gGame.trackInfo.PrestigeTarget)
  CreateTextTexture(0, "Interface", [#tag: #TicketMasterTicketBigPrestigeGoal, #style: #MiniResultsGoal, #text: tString])
  CreateTextTexture(0, "Interface", [#tag: #TicketMasterTicketBigPrizeMoney, #style: #MiniResultsPrizeMoney, #text: FormatMoney(0, gData.Info.trackInfo[symbol(tTrack)].PrizeMoney)])
  if gGame.UPHiddenPackages.getPos(tTrack) <> 0 then
    SETVISIBLE(0, "Interface", [#model: "TicketMasterTicketBigHiddenPackage", #state: 1, #parent: "TicketMasterTicketBig"])
  else
    SETVISIBLE(0, "Interface", [#model: "TicketMasterTicketBigHiddenPackage", #state: 0])
  end if
  if gGame.UpChallengesPrestige.getPos(tTrack) <> 0 then
    SETVISIBLE(0, "Interface", [#model: "TicketMasterTicketBigPrestige", #state: 1, #parent: "TicketMasterTicketBig"])
  else
    SETVISIBLE(0, "Interface", [#model: "TicketMasterTicketBigPrestige", #state: 0])
  end if
  if tTicket contains "Boss" = 1 then
    SETVISIBLE(0, "Interface", [#model: "TicketMasterTicketBigStatus", #state: 1, #parent: "TicketMasterTicketBig"])
    if gGame.UpChallengesCompleted.getPos(tTrack) <> 0 then
      SetModel(0, "Interface", [#model: "TicketMasterTicketBigStatus", #resource: "TicketBigCleared"])
    else
      SetModel(0, "Interface", [#model: "TicketMasterTicketBigStatus", #resource: "TicketBigNew"])
    end if
  else
    SETVISIBLE(0, "Interface", [#model: "TicketMasterTicketBigStatus", #state: 1, #parent: "TicketMasterTicketBig"])
    if gGame.UpChallengesCompleted.getPos(tTrack) <> 0 then
      SetModel(0, "Interface", [#model: "TicketMasterTicketBigStatus", #resource: "TicketBigCleared"])
    else
      SetModel(0, "Interface", [#model: "TicketMasterTicketBigStatus", #resource: "TicketBigNew"])
    end if
  end if
  SETVISIBLE(0, "Interface", [#model: "TicketMasterTicketBig", #state: 1, #parent: "TicketMaster"])
  if gGame.Scene = "World" then
    CreateButton(0, "Interface", [#model: "RightButton", #event: "FadeTrackInitialization", #effect: #shaderRollover, #shaders: ["GreyInterface_Material", "Interface_Material"]])
  else
    CreateButton(0, "Interface", [#model: "RightButton", #event: "FadeNewChallenge", #effect: #shaderRollover, #shaders: ["GreyInterface_Material", "Interface_Material"]])
  end if
end

on GetTrack me, tTicket
  repeat with i = 1 to gData.Info.trackInfo.count
    tProp = gData.Info.trackInfo.getPropAt(i)
    if gData.Info.trackInfo[i].Ticket = tTicket then
      return string(tProp)
    end if
  end repeat
end

on SetupWeaponShop end
  put "--> SetupWeaponShop (Handler)"
  gGame[#WeaponsStore] = [#currentWeapons: #none, #primary: #none, #secondary: #none, #PrimaryCost: 0, #SecondaryCost: 0]
  gGame[#SelectedPrimary] = #none
  gGame[#SelectedSecondary] = #none
  tmember = member("Interface")
  tmember.model("WeaponShopPrimaryWeapons").shader = tmember.shader("WeaponShopInterface_Material")
  tmember.model("WeaponShopSecondaryWeapons").shader = tmember.shader("WeaponShopInterface_Material")
  tmember.model("TotalCost").shader = tmember.shader("WeaponShopInterface_Material")
  CreateTextTexture(0, "Interface", [#tag: #WeaponShopPrimaryWeaponsText, #style: #SteakWeaponShop])
  CreateTextTexture(0, "Interface", [#tag: #WeaponShopSecondaryWeaponsText, #style: #SteakWeaponShop])
  SetupTotalCosts()
  t = gGame.vehicles[1]
  tWeapons = t.general.data.Weapons
  gGame.WeaponsStore.currentWeapons = tWeapons.duplicate()
  gGame.WeaponsStore.primary = tWeapons.primary
  gGame.WeaponsStore.secondary = tWeapons.secondary
  repeat with i in gGame.WSPrimWeapons
    tButton = tmember.model("WeaponShop" & i & "Button")
    tEquipped = tmember.model("WeaponShop" & i & "Equipped")
    tPrice = tmember.model("WeaponShop" & i & "PriceText")
    tName = tmember.model("WeaponShop" & i & "NameText")
    tString = tName.name
    tWeaponName = convertToUpperCase(0, gData.data.PrimaryWeapons[symbol(tString.char[11..tString.length - 8])].name)
    SetModel(0, "Interface", [#model: tButton.name, #shader: "GreyInterface_Material"])
    SetModel(0, "Interface", [#model: tEquipped.name, #shader: "GreyInterface_Material"])
    tPrice.visibility = #none
    tName.visibility = #none
    tPrize = gData.data.PrimaryWeapons[symbol(i)].cost
    CreateTextTexture(0, "Interface", [#tag: symbol(tPrice.name), #style: #ShopPrize, #text: FormatMoney(0, tPrize)])
    CreateTextTexture(0, "Interface", [#tag: symbol(tName.name), #style: #ShopName, #text: tWeaponName])
    CreateButton(0, "Interface", [#model: tButton.name, #handler: "SelectPrimaryWeapon", #effect: [#shaderRollover, #handlerRollover], #shaders: ["GreyInterface_Material", "Interface_Material"], #handlers: [#ButtonLeaveWeaponShop, #ButtonEnterWeaponShop]])
  end repeat
  repeat with i in gGame.WSSecWeapons
    tButton = tmember.model("WeaponShop" & i & "Button")
    tEquipped = tmember.model("WeaponShop" & i & "Equipped")
    tPrice = tmember.model("WeaponShop" & i & "PriceText")
    tName = tmember.model("WeaponShop" & i & "NameText")
    tString = tName.name
    tWeaponName = convertToUpperCase(0, gData.data.SecondaryWeapons[symbol(tString.char[11..tString.length - 8])].name)
    SetModel(0, "Interface", [#model: tButton.name, #shader: "GreyInterface_Material"])
    SetModel(0, "Interface", [#model: tEquipped.name, #shader: "GreyInterface_Material"])
    tPrice.visibility = #none
    tName.visibility = #none
    tPrize = gData.data.SecondaryWeapons[symbol(i)].cost
    CreateTextTexture(0, "Interface", [#tag: symbol(tPrice.name), #style: #ShopPrize, #text: FormatMoney(0, tPrize)])
    CreateTextTexture(0, "Interface", [#tag: symbol(tName.name), #style: #ShopName, #text: tWeaponName])
    CreateButton(0, "Interface", [#model: tButton.name, #handler: "SelectSecondaryWeapon", #effect: [#shaderRollover, #handlerRollover], #shaders: ["GreyInterface_Material", "Interface_Material"], #handlers: [#ButtonLeaveWeaponShop, #ButtonEnterWeaponShop]])
  end repeat
  ShowWeaponShopEquipped()
end

on ShowWeaponShopEquipped me
  t = gGame.vehicles[1]
  tWeapons = t.general.data.Weapons
  tmember = member("Interface")
  repeat with i in gGame.WSPrimWeapons
    tEquipped = tmember.model("WeaponShop" & i & "Equipped")
    if i = tWeapons.primary then
      tEquipped.visibility = #front
      next repeat
    end if
    tEquipped.visibility = #none
  end repeat
  repeat with i in gGame.WSSecWeapons
    tEquipped = tmember.model("WeaponShop" & i & "Equipped")
    if i = tWeapons.secondary then
      tEquipped.visibility = #front
      next repeat
    end if
    tEquipped.visibility = #none
  end repeat
end

on ResetWeaponShop end
  put "--> ResetWeaponShop (Handler)"
  DeleteAllButtons()
  t = gGame.vehicles[1]
  tData = t.general.data
  tData.Weapons.primary = gGame.WeaponsStore.currentWeapons.primary
  sendSprite(0, symbol("reset_" & gGame.WeaponsStore.primary), gGame.vehicles[1])
  sendSprite(0, symbol("setup_" & gGame.WeaponsStore.currentWeapons.primary), gGame.vehicles[1])
  tData.Weapons.secondary = gGame.WeaponsStore.currentWeapons.secondary
  sendSprite(0, symbol("reset_" & gGame.WeaponsStore.secondary), gGame.vehicles[1])
  sendSprite(0, symbol("setup_" & gGame.WeaponsStore.currentWeapons.secondary), gGame.vehicles[1])
  UpdateWeaponsData()
  gGame.deleteProp(#WeaponsStore)
end

on ButtonEnterWeaponShop me, tTarget, tDataList
  tmember = member(tTarget)
  tButton = tmember.model(tDataList.model)
  tString = tButton.name
  tString = tString.char[1..tString.length - 6]
  tButton.child[1].shader = tmember.shader("Interface_Material")
  tmember.model(tString & "PriceText").visibility = #front
  tmember.model(tString & "NameText").visibility = #front
end

on ButtonLeaveWeaponShop me, tTarget, tDataList
  tmember = member(tTarget)
  tButton = tmember.model(tDataList.model)
  tString = tButton.name
  tString = tString.char[1..tString.length - 6]
  tButton.child[1].shader = tmember.shader("GreyInterface_Material")
  tmember.model(tString & "PriceText").visibility = #none
  tmember.model(tString & "NameText").visibility = #none
end

on SelectPrimaryWeapon me
  put "--> SelectPrimaryWeapon (Handler)"
  t = gGame.vehicles[1]
  tButton = gGame.menu.PressedButton
  tOldWeapon = t.general.data.Weapons[#primary]
  tNewWeapon = tButton.char[1..tButton.length - 6]
  tNewWeapon = tNewWeapon.char[11..tNewWeapon.length]
  t.general.data.Weapons[#primary] = tNewWeapon
  gGame.WeaponsStore.primary = tNewWeapon
  sendSprite(0, symbol("reset_" & tOldWeapon), gGame.vehicles[1])
  sendSprite(0, symbol("setup_" & tNewWeapon), gGame.vehicles[1])
  CreateButton(0, "Interface", [#model: "RightButton", #handler: "BuyWeapons", #effect: #shaderRollover, #shaders: ["GreyInterface_Material", "Interface_Material"]])
  if gGame.UPUnlockableCheats.getPos(#UnlimitedWeaponShop) = 0 then
    gGame.WeaponsStore.PrimaryCost = gData.data.PrimaryWeapons[symbol(tNewWeapon)].cost
    if tNewWeapon = gGame.WeaponsStore.currentWeapons.primary then
      gGame.WeaponsStore.PrimaryCost = 0
    end if
    gGame.TotalCosts = gGame.WeaponsStore.PrimaryCost + gGame.WeaponsStore.SecondaryCost
    UpdateTotalCosts()
  end if
  PlaySound(0, "SelectWeapon_SFX", [#Override: 1])
end

on SelectSecondaryWeapon me
  put "--> SelectSecondaryWeapon (Handler)"
  t = gGame.vehicles[1]
  tButton = gGame.menu.PressedButton
  tOldWeapon = t.general.data.Weapons[#secondary]
  tNewWeapon = tButton.char[1..tButton.length - 6]
  tNewWeapon = tNewWeapon.char[11..tNewWeapon.length]
  t.general.data.Weapons[#secondary] = tNewWeapon
  gGame.WeaponsStore.secondary = tNewWeapon
  sendSprite(0, symbol("reset_" & tOldWeapon), gGame.vehicles[1])
  sendSprite(0, symbol("setup_" & tNewWeapon), gGame.vehicles[1])
  CreateButton(0, "Interface", [#model: "RightButton", #handler: "BuyWeapons", #effect: #shaderRollover, #shaders: ["GreyInterface_Material", "Interface_Material"]])
  if gGame.UPUnlockableCheats.getPos(#UnlimitedWeaponShop) = 0 then
    gGame.WeaponsStore.SecondaryCost = gData.data.SecondaryWeapons[symbol(tNewWeapon)].cost
    if tNewWeapon = gGame.WeaponsStore.currentWeapons.secondary then
      gGame.WeaponsStore.SecondaryCost = 0
    end if
    gGame.TotalCosts = gGame.WeaponsStore.PrimaryCost + gGame.WeaponsStore.SecondaryCost
    UpdateTotalCosts()
  end if
  PlaySound(0, "SelectWeapon_SFX", [#Override: 1])
end

on BuyWeapons me
  put "--> BuyWeapons (Handler)"
  gGame.SWGameTrophies.weaponPurchased = gGame.SWGameTrophies.weaponPurchased + 1
  if gGame.UPUnlockableCheats.getPos(#UnlimitedWeaponShop) = 0 then
    gGame.money = gGame.money - gGame.TotalCosts
    UpdateMoney()
  end if
  t = gGame.vehicles[1]
  tData = t.general.data
  gGame.WeaponsStore.currentWeapons = tData.Weapons.duplicate()
  gData.data.CarWeapons[symbol(t.Vehicle.name)] = tData.Weapons.duplicate()
  RestoreAmmo()
  UpdateWeaponsData()
  event(0, #ExitShop)
end

on SetupTuneShop end
  put "--> SetupTuneShop (Handler)"
  gGame[#TuneStore] = [#engine: 0, #armor: 0, #handling: 0, #primary: 0, #secondary: 0]
  tmember = member("Interface")
  tmember.model("TuneShopCarStats").shader = tmember.shader("TuneShopInterface_Material")
  tmember.model("TotalCost").shader = tmember.shader("TuneShopInterface_Material")
  tCarName = gData.data.carsettings[symbol(gGame.vehicles[1].Vehicle.name)].name
  CreateTextTexture(0, "Interface", [#tag: #TuneShopCarStatsText, #style: #SteakShop2, #text: tCarName])
  SetupTotalCosts()
  tData = gGame.vehicles[1].general.data.upgrades.duplicate()
  tPropList = [#engine, #armor, #handling]
  repeat with j in tPropList
    tProp = j
    tString = string(tProp)
    tList = tData[tProp].duplicate()
    repeat with i = 1 to 12
      tmodel = tmember.model("TuneShop" & tString & "Upgrade" & i)
      if i <= tList[1] then
        tmodel.resource = tmember.modelResource("CarUpgradeSlotFull")
      else
        if i <= tList[2] then
          tmodel.resource = tmember.modelResource("CarUpgradeSlotOpen")
        else
          tmodel.resource = VOID
        end if
      end if
      tmodel.shader = tmember.shader("Interface_Material")
    end repeat
    SetModel(0, "Interface", [#model: "TuneShop" & tString & "UpgradeMinusButton", #shader: "GreyInterface_Material"])
    SetModel(0, "Interface", [#model: "TuneShop" & tString & "UpgradePlusButton", #shader: "GreyInterface_Material"])
    CreateButton(0, "Interface", [#model: "TuneShop" & tString & "UpgradeMinusButton", #handler: "RemoveUpgrade", #effect: #shaderRollover, #shaders: ["GreyInterface_Material", "Interface_Material"]])
    CreateButton(0, "Interface", [#model: "TuneShop" & tString & "UpgradePlusButton", #handler: "AddUpgrade", #effect: #shaderRollover, #shaders: ["GreyInterface_Material", "Interface_Material"]])
  end repeat
  tPropList = [#primary, #secondary]
  repeat with j in tPropList
    tProp = j
    tString = string(tProp)
    tList = tData[tProp].duplicate()
    repeat with i = 1 to 10
      tmodel = tmember.model("TuneShop" & tString & "WeaponUpgrade" & i)
      if i <= tList[1] then
        tmodel.resource = tmember.modelResource("WeaponUpgradeSlotFull")
      else
        if i <= tList[2] then
          tmodel.resource = tmember.modelResource("WeaponUpgradeSlotOpen")
        else
          tmodel.resource = VOID
        end if
      end if
      tmodel.shader = tmember.shader("Interface_Material")
    end repeat
    SetModel(0, "Interface", [#model: "TuneShop" & tString & "WeaponUpgradeMinusButton", #shader: "GreyInterface_Material"])
    SetModel(0, "Interface", [#model: "TuneShop" & tString & "WeaponUpgradePlusButton", #shader: "GreyInterface_Material"])
    CreateButton(0, "Interface", [#model: "TuneShop" & tString & "WeaponUpgradeMinusButton", #handler: "RemoveUpgrade", #effect: #shaderRollover, #shaders: ["GreyInterface_Material", "Interface_Material"]])
    CreateButton(0, "Interface", [#model: "TuneShop" & tString & "WeaponUpgradePlusButton", #handler: "AddUpgrade", #effect: #shaderRollover, #shaders: ["GreyInterface_Material", "Interface_Material"]])
  end repeat
end

on ResetTuneShop end
  put "--> ResetTuneShop (Handler)"
  DeleteAllButtons()
  gGame.deleteProp(#TuneStore)
end

on AddUpgrade me
  put "--> AddUpgrade (Handler)"
  tButton = gGame.menu.PressedButton
  tProp = #none
  if tButton contains "Engine" then
    tProp = #engine
  end if
  if tButton contains "Armor" then
    tProp = #armor
  end if
  if tButton contains "Handling" then
    tProp = #handling
  end if
  if tButton contains "Primary" then
    tProp = #primary
  end if
  if tButton contains "Secondary" then
    tProp = #secondary
  end if
  if tProp = #none then
    return 0
  end if
  tData = gGame.vehicles[1].general.data.upgrades.duplicate()
  tList = tData[tProp].duplicate()
  if gGame.TuneStore[tProp] < (tList[2] - tList[1]) then
    gGame.TuneStore[tProp] = gGame.TuneStore[tProp] + 1
    if gGame.UPUnlockableCheats.getPos(#UnlimitedTuneShop) = 0 then
      gGame.TotalCosts = gGame.TotalCosts + gGame[symbol(string(tProp) & "Cost")]
    end if
  end if
  CreateButton(0, "Interface", [#model: "RightButton", #handler: "BuyTuning", #effect: #shaderRollover, #shaders: ["GreyInterface_Material", "Interface_Material"]])
  UpdateTuneShopStatistics()
end

on RemoveUpgrade me
  put "--> RemoveUpgrade (Handler)"
  tButton = gGame.menu.PressedButton
  tProp = #none
  if tButton contains "Engine" then
    tProp = #engine
  end if
  if tButton contains "Armor" then
    tProp = #armor
  end if
  if tButton contains "Handling" then
    tProp = #handling
  end if
  if tButton contains "Primary" then
    tProp = #primary
  end if
  if tButton contains "Secondary" then
    tProp = #secondary
  end if
  if tProp = #none then
    return 0
  end if
  tData = gGame.vehicles[1].general.data.upgrades.duplicate()
  tList = tData[tProp].duplicate()
  if gGame.TuneStore[tProp] > 0 then
    gGame.TuneStore[tProp] = gGame.TuneStore[tProp] - 1
    if gGame.UPUnlockableCheats.getPos(#UnlimitedTuneShop) = 0 then
      gGame.TotalCosts = gGame.TotalCosts - gGame[symbol(string(tProp) & "Cost")]
    end if
  end if
  CreateButton(0, "Interface", [#model: "RightButton", #handler: "BuyTuning", #effect: #shaderRollover, #shaders: ["GreyInterface_Material", "Interface_Material"]])
  UpdateTuneShopStatistics()
end

on BuyTuning me
  put "--> BuyTuning (Handler)"
  gGame.SWGameTrophies.upgradePurchased = gGame.SWGameTrophies.upgradePurchased + 1
  if gGame.UPUnlockableCheats.getPos(#UnlimitedTuneShop) = 0 then
    gGame.money = gGame.money - gGame.TotalCosts
    UpdateMoney()
  end if
  t = gGame.vehicles[1]
  tData = t.general.data
  repeat with i = 1 to gGame.TuneStore.count
    tProp = gGame.TuneStore.getPropAt(i)
    tData.upgrades[tProp][1] = tData.upgrades[tProp][1] + gGame.TuneStore[i]
  end repeat
  gData.data.CarUpgrades[symbol(t.Vehicle.name)] = tData.upgrades.duplicate()
  tSpeedMS = float(gGame.EngineUpgrade[1]) * 1000.0 / 3600.0
  tData.settings.maxSpeed = tData.settings.origMaxSpeed + (tData.upgrades.engine[1] * tSpeedMS)
  tData.settings.accGain = tData.settings.origaccGain + (tData.upgrades.engine[1] * gGame.EngineUpgrade[2])
  tData.settings.decGain = tData.settings.origdecGain + (tData.upgrades.engine[1] * gGame.EngineUpgrade[3])
  tData.personality.Health = tData.personality.origHealth + (tData.upgrades.armor[1] * gGame.HealthUpgrade)
  tData.settings.turnGain = min(1.75, tData.settings.turnGain + (tData.upgrades.handling[1] * gGame.HandlingUpgrade))
  t.Vehicle.maxSpeed = tData.settings.maxSpeed
  t.Vehicle.accGain = tData.settings.accGain
  t.Vehicle.decGain = tData.settings.decGain
  t.Vehicle.Health = t.general.data.personality.Health
  t.Vehicle.turnGain = tData.settings.turnGain
  RestoreAmmo()
  event(0, #ExitShop)
end

on UpdateTuneShopStatistics me
  put "--> --> --> RemoveEngineUpgrade (Handler)"
  tmember = member("Interface")
  tData = gGame.vehicles[1].general.data.upgrades.duplicate()
  tPropList = [#engine, #armor, #handling]
  repeat with j in tPropList
    tProp = j
    tString = string(tProp)
    tList = tData[tProp].duplicate()
    repeat with i = tList[1] + 1 to tList[2]
      tmodel = tmember.model("TuneShop" & tString & "Upgrade" & i)
      if i <= (tList[1] + gGame.TuneStore[tProp]) then
        tmodel.resource = tmember.modelResource("CarUpgradeSlotTemp")
      else
        tmodel.resource = tmember.modelResource("CarUpgradeSlotOpen")
      end if
      tmodel.shader = tmember.shader("Interface_Material")
    end repeat
  end repeat
  tPropList = [#primary, #secondary]
  repeat with j in tPropList
    tProp = j
    tString = string(tProp)
    tList = tData[tProp].duplicate()
    repeat with i = tList[1] + 1 to tList[2]
      tmodel = tmember.model("TuneShop" & tString & "WeaponUpgrade" & i)
      if i <= (tList[1] + gGame.TuneStore[tProp]) then
        tmodel.resource = tmember.modelResource("WeaponUpgradeSlotTemp")
      else
        tmodel.resource = tmember.modelResource("WeaponUpgradeSlotOpen")
      end if
      tmodel.shader = tmember.shader("Interface_Material")
    end repeat
  end repeat
  if gGame.UPUnlockableCheats.getPos(#UnlimitedTuneShop) = 0 then
    UpdateTotalCosts()
  end if
end

on SetupSprayShop end
  put "--> SetupSprayShop (Handler)"
  gGame[#SprayStore] = [#skin: gGame.vehicles[1].general.data.skin, #Health: gGame.vehicles[1].Vehicle.Health, #currentTexture: gGame.vehicles[1].Vehicle.model.shader.textureList[1], #textures: []]
  tVehicleName = gGame.vehicles[1].Vehicle.name
  tWorld = member("World" & gGame.world)
  repeat with i = 1 to 4
    tName = "_player1" & tVehicleName & "Skin" & i & "_Texture"
    if tWorld.texture(tName) = VOID then
      tTexture = tWorld.newTexture(tName, #fromCastMember, member(tVehicleName & "Skin" & i & "_Texture"))
      tTexture.renderFormat = #rgba8888
      gGame.SprayStore.textures.add(tTexture)
    end if
  end repeat
  tmember = member("Interface")
  tmember.model("TuneShopCarStats").shader = tmember.shader("SprayShopInterface_Material")
  tmember.model("TotalCost").shader = tmember.shader("SprayShopInterface_Material")
  SetupTotalCosts()
  repeat with i = 1 to 4
    tMask = tmember.model("SprayShopSkinPosition" & i & "Mask")
    tPos = tmember.model("SprayShopSkinPosition" & i)
    tPrice = tmember.model("SprayShopSkinPosition" & i & "PriceText")
    SetModel(0, "Interface", [#model: tMask.name, #shader: "GreyInterface_Material"])
    SetModel(0, "Interface", [#model: tPos.name, #resource: "Skin" & i & gGame.vehicles[1].Vehicle.name, #shader: "GreySprayShopSkins_Material"])
    CreateButton(0, "Interface", [#model: tPos.name, #handler: "SelectSkin", #effect: [#shaderRollover, #handlerRollover], #shaders: ["GreySprayShopSkins_Material", "SprayShopSkins_Material"], #handlers: [#ButtonLeaveSprayShop, #ButtonEnterSprayShop]])
    CreateTextTexture(0, "Interface", [#tag: symbol(tPrice.name), #style: #ShopPrize, #text: FormatMoney(0, gGame[symbol("SkinCost" & i)])])
    tPrice.visibility = #none
  end repeat
end

on ResetSprayShop end
  put "--> ResetSprayShop (Handler)"
  DeleteAllButtons()
  t = gGame.vehicles[1]
  tWorld = member("World" & gGame.world)
  t.Vehicle.model.shader.textureList[1] = gGame.SprayStore.currentTexture
  if t.Vehicle.glassModel <> #none then
    t.Vehicle.glassModel.shader.textureList[1] = gGame.SprayStore.currentTexture
  end if
  t.Vehicle.Health = gGame.SprayStore.Health
  tWorld = member("World" & gGame.world)
  repeat with i = 1 to 4
    tName = "_player1" & t.Vehicle.name & "Skin" & i & "_Texture"
    if tWorld.texture(tName) <> VOID then
      tWorld.deleteTexture(tName)
    end if
  end repeat
  gGame.deleteProp(#SprayStore)
end

on ButtonEnterSprayShop me, tTarget, tDataList
  tmember = member(tTarget)
  tButton = tmember.model(tDataList.model)
  tButton.child[1].shader = tmember.shader("Interface_Material")
  tmember.model(tButton.name & "PriceText").visibility = #front
end

on ButtonLeaveSprayShop me, tTarget, tDataList
  tmember = member(tTarget)
  tButton = tmember.model(tDataList.model)
  tButton.child[1].shader = tmember.shader("GreyInterface_Material")
  tmember.model(tButton.name & "PriceText").visibility = #none
end

on SelectSkin me
  put "--> SelectSkin (Handler)"
  tButton = gGame.menu.PressedButton
  tNewSkin = value(tButton.char[tButton.length])
  gGame.SprayStore.skin = tNewSkin
  t = gGame.vehicles[1]
  t.Vehicle.Health = t.general.data.personality.Health
  update_Damage(0, t)
  tOldSkin = t.general.data.skin
  tWorld = member("World" & gGame.world)
  t.Vehicle.model.shader.textureList[1] = gGame.SprayStore.textures[tNewSkin]
  if t.Vehicle.glassModel <> #none then
    t.Vehicle.glassModel.shader.textureList[1] = gGame.SprayStore.textures[tNewSkin]
  end if
  CreateButton(0, "Interface", [#model: "RightButton", #handler: "BuySkin", #effect: #shaderRollover, #shaders: ["GreyInterface_Material", "Interface_Material"]])
  if gGame.UPUnlockableCheats.getPos(#UnlimitedSprayShop) = 0 then
    gGame.TotalCosts = gGame[symbol("SkinCost" & tNewSkin)]
    UpdateTotalCosts()
  end if
end

on BuySkin me
  put "--> BuySkin (Handler)"
  gGame.SWGameTrophies.paintPurchased = gGame.SWGameTrophies.paintPurchased + 1
  if gGame.UPUnlockableCheats.getPos(#UnlimitedSprayShop) = 0 then
    gGame.money = gGame.money - gGame.TotalCosts
    UpdateMoney()
  end if
  t = gGame.vehicles[1]
  gGame.SprayStore.Health = t.general.data.personality.Health
  tWorld = member("World" & gGame.world)
  tWorld.deleteTexture(gGame.SprayStore.currentTexture.name)
  gGame.SprayStore.currentTexture = tWorld.newTexture("player1" & t.Vehicle.name & "Skin" & gGame.SprayStore.skin & "_Texture", #fromCastMember, member(t.Vehicle.name & "Skin" & gGame.SprayStore.skin & "_Texture"))
  gGame.SprayStore.currentTexture.renderFormat = #rgba5650
  t.general.data.skin = gGame.SprayStore.skin
  gData.data.car[symbol(t.Vehicle.name)].skin = gGame.SprayStore.skin
  event(0, #ExitShop)
end

on SetupSafeHouse end
  put "--> SetupSafehouse (Handler)"
  gGame[#SafeHouseStore] = [#currentCar: gGame.vehicles[1].Vehicle.name, #newCar: #none, #currentSelection: gGame.vehicles[1].Vehicle.name, #carsBuild: [:], #script: #none]
  gGame.SafeHouseStore.script = script("[PS] Game Progress").new([#event: #none, #command: #none, #totalCommands: 1, #currentCommand: 0])
  tmember = member("Interface")
  tmember.model("SafeHouseCarStats").shader = tmember.shader("SafeHouseInterface_Material")
  tmember.model("SafeHouseCarName").shader = tmember.shader("SafeHouseInterface_Material")
  CreateTextTexture(0, "Interface", [#tag: #SafeHouseCarStatsText, #style: #SafeHouseStatistics])
  DeleteVehicle(0, EMPTY, [#index: 1])
  SafeHouseBuildCars()
  tPos = gGame.UPCars.getPos(gGame.SafeHouseStore.currentCar)
  gGame.camera[1].target = "CarPosition" & gGame.world & tPos & "_Camera"
  tCamera = member("World" & gGame.world).camera("CarPosition" & gGame.world & tPos & "_Camera")
  tCamera.fieldOfView = 40.0
  if gGame.SafeHouseStore.currentCar = "BigTruck" then
    tCamera.fieldOfView = 85.0
  end if
  if gGame.SafeHouseStore.currentCar = "MonsterTruck" then
    tCamera.fieldOfView = 65.0
  end if
  if gGame.SafeHouseStore.currentCar = "AutoBot" then
    tCamera.fieldOfView = 65.0
  end if
  if gGame.SafeHouseStore.currentCar = "Tank" then
    tCamera.fieldOfView = 80.0
  end if
  UpdateSafeHouseStatistics()
  UpdateSafeHouseCarName()
  SetModel(0, "Interface", [#model: "SafeHouseCarSelectPreviousArrowButton", #shader: "GreyInterface_Material"])
  SetModel(0, "Interface", [#model: "SafeHouseCarSelectNextArrowButton", #shader: "GreyInterface_Material"])
  CreateButton(0, "Interface", [#model: "SafeHouseCarSelectPreviousArrowButton", #handler: "SelectPreviousCar", #effect: #shaderRollover, #shaders: ["GreyInterface_Material", "Interface_Material"]])
  CreateButton(0, "Interface", [#model: "SafeHouseCarSelectNextArrowButton", #handler: "SelectNextCar", #effect: #shaderRollover, #shaders: ["GreyInterface_Material", "Interface_Material"]])
  delete gGame.SafeHouseStore.script
  gGame.SafeHouseStore.script = #none
end

on RestoreVehicleSafeHouse
  gGame.SafeHouseStore.currentSelection = gGame.SafeHouseStore.currentCar
end

on ResetSafeHouse end
  put "--> ResetSafeHouse (Handler)"
  DeleteAllButtons()
  gGame.car = gGame.SafeHouseStore.currentSelection
  gGame.WorldStartDummy[symbol(gGame.world)] = "SafeHouse" & gGame.world & "_Marker"
  DisableCurrentMarker()
  SafeHouseDeleteCars()
  SafeHouseCreateCar()
  UpdateWeaponsData()
  gGame.deleteProp(#SafeHouseStore)
  event(0, #ExitSafeHouse)
end

on SetupProgressLoader me
  gGame[#SetupProgressLoader] = script("[PS] Game Progress").new([#event: #none, #command: #none, #totalCommands: 1, #currentCommand: 2, #tag: #vehicles])
end

on UpdateProgressLoader me
  gGame.SetupProgressLoader.UpdateVisuals()
end

on ResetProgressLoader me
  if voidp(gGame[#SetupProgressLoader]) = 1 then
    return 0
  end if
  delete gGame.SetupProgressLoader
  gGame.deleteProp(#SetupProgressLoader)
end

on UpdateSafeHouseStatistics me
  tmember = member("Interface")
  tData = gData.data.CarUpgrades[symbol(gGame.SafeHouseStore.currentSelection)]
  tPropList = [#engine, #armor, #handling]
  repeat with j in tPropList
    tProp = j
    tString = string(tProp)
    tList = tData[tProp].duplicate()
    repeat with i = 1 to 12
      tmodel = tmember.model("SafeHouse" & tString & "Upgrade" & i)
      if i <= tList[1] then
        tmodel.resource = tmember.modelResource("CarUpgradeSlotFull")
      else
        if i <= tList[2] then
          tmodel.resource = tmember.modelResource("CarUpgradeSlotOpen")
        else
          tmodel.resource = VOID
        end if
      end if
      tmodel.shader = tmember.shader("Interface_Material")
    end repeat
  end repeat
  tPropList = [#primary, #secondary]
  repeat with j in tPropList
    tProp = j
    tString = string(tProp)
    tList = tData[tProp].duplicate()
    repeat with i = 1 to 10
      tmodel = tmember.model("SafeHouse" & tString & "WeaponUpgrade" & i)
      if i <= tList[1] then
        tmodel.resource = tmember.modelResource("WeaponUpgradeSlotFull")
      else
        if i <= tList[2] then
          tmodel.resource = tmember.modelResource("WeaponUpgradeSlotOpen")
        else
          tmodel.resource = VOID
        end if
      end if
      tmodel.shader = tmember.shader("Interface_Material")
    end repeat
  end repeat
end

on UpdateSafeHouseCarName me
  tText = gData.data.carsettings[symbol(gGame.SafeHouseStore.currentSelection)].name
  CreateTextTexture(0, "Interface", [#tag: #SafeHouseCarNameText, #style: #SteakShop, #text: tText, #align: #center])
end

on SelectPreviousCar me
  if gGame.camera[1].CurrentSet <> #MimicSoft then
    UpdateCameraSet(0, #MimicSoft)
  end if
  tPos = gGame.UPCars.getPos(gGame.SafeHouseStore.currentSelection)
  if tPos > 1 then
    tPos = tPos - 1
  end if
  gGame.SafeHouseStore.currentSelection = gGame.UPCars[tPos]
  gGame.camera[1].target = "CarPosition" & gGame.world & tPos & "_Camera"
  tCamera = member("World" & gGame.world).camera("CarPosition" & gGame.world & tPos & "_Camera")
  tCamera.fieldOfView = 40.0
  if gGame.SafeHouseStore.currentSelection = "BigTruck" then
    tCamera.fieldOfView = 85.0
  end if
  if gGame.SafeHouseStore.currentSelection = "MonsterTruck" then
    tCamera.fieldOfView = 65.0
  end if
  if gGame.SafeHouseStore.currentSelection = "AutoBot" then
    tCamera.fieldOfView = 65.0
  end if
  if gGame.SafeHouseStore.currentSelection = "Tank" then
    tCamera.fieldOfView = 80.0
  end if
  UpdateSafeHouseStatistics()
  UpdateSafeHouseCarName()
end

on SelectNextCar me
  if gGame.camera[1].CurrentSet <> #MimicSoft then
    UpdateCameraSet(0, #MimicSoft)
  end if
  tPos = gGame.UPCars.getPos(gGame.SafeHouseStore.currentSelection)
  if tPos < gGame.UPCars.count then
    tPos = tPos + 1
  end if
  gGame.SafeHouseStore.currentSelection = gGame.UPCars[tPos]
  gGame.camera[1].target = "CarPosition" & gGame.world & tPos & "_Camera"
  tCamera = member("World" & gGame.world).camera("CarPosition" & gGame.world & tPos & "_Camera")
  tCamera.fieldOfView = 40.0
  if gGame.SafeHouseStore.currentSelection = "BigTruck" then
    tCamera.fieldOfView = 85.0
  end if
  if gGame.SafeHouseStore.currentSelection = "MonsterTruck" then
    tCamera.fieldOfView = 65.0
  end if
  if gGame.SafeHouseStore.currentSelection = "AutoBot" then
    tCamera.fieldOfView = 65.0
  end if
  if gGame.SafeHouseStore.currentSelection = "Tank" then
    tCamera.fieldOfView = 80.0
  end if
  UpdateSafeHouseStatistics()
  UpdateSafeHouseCarName()
end

on SafeHouseBuildCars me
  repeat with i = 1 to gGame.UPCars.count
    BuildCarInSafeHouse(0, gGame.UPCars[i], i)
    gGame.SafeHouseStore.script.UpdateVisuals(0.0, 10)
  end repeat
end

on BuildCarInSafeHouse me, tCar, tCount
  tData = gData.data.car[symbol(tCar)]
  tWeapons = gData.data.CarWeapons[symbol(tCar)]
  tmember = member("World" & gGame.world)
  tCarMember = member(tCar)
  tShader = tmember.shader("Weapons_Material")
  if tShader <> VOID then
    if tShader.textureList[1].name = "DefaultTexture" then
      tShader.textureList[1] = tmember.texture("Weapons_Texture")
      put "------------------------------------FIXING THE WEAPONS TEXTURE ISSUE"
    end if
  end if
  tList = [#models: [], #groups: [:], #shaders: [], #textures: [], #Weapons: []]
  tModelList = [tCar, tCar & "Glass", tCar & "Wheel_LB", tCar & "Wheel_RB", tCar & "Wheel_RF", tCar & "Wheel_LF"]
  tModelList = CloneModel(0, tmember.name, [#sourceMember: tCar, #model: tModelList])
  tCarModel = tmember.model(tCar)
  repeat with i in tModelList
    if i.name = tCar then
      next repeat
    end if
    i.transform = tCarModel.getWorldTransform().inverse() * i.transform
    i.parent = tCarModel
  end repeat
  tList.models = tModelList
  tWeaponPlacementList = [:]
  tPrimGroup = tCarMember.group(tCar & "PrimaryWeapon1_Dummy")
  if tPrimGroup <> VOID then
    tNewPrimGroup = tmember.newGroup(tCar & "PrimaryWeapon1_Dummy")
    tNewPrimGroup.transform = tPrimGroup.transform
    tNewPrimGroup.transform = tCarModel.getWorldTransform().inverse() * tNewPrimGroup.transform
    tNewPrimGroup.parent = tCarModel
    tWeaponPlacementList[#primary1] = tNewPrimGroup
  end if
  repeat with i = 1 to 4
    tSecGroup = tCarMember.group(tCar & "SecondaryWeapon" & i & "_Dummy")
    if tSecGroup <> VOID then
      tNewSecGroup = tmember.newGroup(tCar & "SecondaryWeapon" & i & "_Dummy")
      tNewSecGroup.transform = tSecGroup.transform
      tNewSecGroup.transform = tCarModel.getWorldTransform().inverse() * tNewSecGroup.transform
      tNewSecGroup.parent = tCarModel
      tWeaponPlacementList[symbol("Secondary" & i)] = tNewSecGroup
    end if
  end repeat
  tList.groups = tWeaponPlacementList
  tCarModel.transform = gGame.MarkerTransformList[symbol("CarPosition" & gGame.world & tCount & "_Marker")].transform
  tCarModel.transform.position.z = tCarModel.transform.position.z + member(tCar).model(tCar).transform.position.z
  tShadowResource = tmember.modelResource("SimpleShadow")
  tShadowModel = tmember.newModel(tCar & "Shadow", tShadowResource)
  if voidp(gGame.ShadowScale[symbol(tCar)]) = 0 then
    tShadowModel.transform.scale = vector(1, 1, 1) * gGame.ShadowScale[symbol(tCar)]
  else
    tShadowModel.transform.scale = vector(1, 1, 1) * (tCarModel.boundingSphere[2] * 1.39999999999999991)
  end if
  tShadowModel.transform.rotation = gGame.MarkerTransformList[symbol("CarPosition" & gGame.world & tCount & "_Marker")].transform.rotation + vector(0, 0, 0.01)
  tShadowModel.transform.position = gGame.MarkerTransformList[symbol("CarPosition" & gGame.world & tCount & "_Marker")].transform.position + vector(0, 0, 0.01)
  tShadowShader = CreateShader(0, tmember.name, [#shader: tCar & "Shadow_Material", #texture: tCar & "Shadow_Texture", #blend: 75.0])
  tShadowShader.diffuse = rgb(0, 0, 0)
  tShadowShader.ambient = rgb(0, 0, 0)
  tShadowShader.emissive = rgb(0, 0, 0)
  tShadowShader.useDiffuseWithTexture = 1
  tShadowModel.shaderList = tShadowShader
  tList.shaders.add(tShadowShader)
  tList.textures.add(tmember.texture(tCar & "Shadow_Texture"))
  tList.models.add(tShadowModel)
  tCarTexture = createTexture(0, tmember.name, [#texture: tCar & "Skin" & tData.skin & "_Texture", #filtering: #lowFiltered])
  if tmember.texture("Reflection_Texture") = VOID then
    tRefTexture = createTexture(0, tmember.name, [#texture: "Reflection_Texture", #filtering: #lowFiltered])
  else
    tRefTexture = tmember.texture("Reflection_Texture")
  end if
  if tmember.texture("Wheels_Texture") = VOID then
    tWheelsTexture = createTexture(0, tmember.name, [#texture: "Wheels_Texture", #filtering: #lowFiltered])
  else
    tWheelsTexture = tmember.texture("Wheels_Texture")
  end if
  tShader = tmember.shader(tCar & "_Material")
  tGlassShader = tmember.shader(tCar & "Glass_Material")
  tWheelsShader = tmember.shader(tCar & "Wheels_Material")
  tShader.textureList[1] = tCarTexture
  tGlassShader.textureList[1] = tCarTexture
  if tWheelsShader <> VOID then
    tWheelsShader.textureList[1] = tWheelsTexture
  end if
  tShader.textureList[2] = tRefTexture
  tShader.textureModeList[2] = #reflection
  tShader.blendFunctionList[2] = #add
  tShader.ambient = rgb(255, 255, 255)
  tShader.emissive = gData.data.ambientStyle[symbol("World" & gGame.world & gGame.setting)].emissive
  tShader.specular = rgb(200, 200, 200)
  tShader.shininess = 45.0
  tGlassShader.textureList[2] = tRefTexture
  tGlassShader.textureModeList[2] = #reflection
  tGlassShader.blendFunctionList[2] = #add
  tGlassShader.ambient = rgb(255, 255, 255)
  tGlassShader.emissive = gData.data.ambientStyle[symbol("World" & gGame.world & gGame.setting)].emissive
  tGlassShader.specular = rgb(200, 200, 200)
  tGlassShader.shininess = 45.0
  if tWheelsShader <> VOID then
    tWheelsShader.ambient = rgb(255, 255, 255)
    tWheelsShader.emissive = gData.data.ambientStyle[symbol("World" & gGame.world & gGame.setting)].emissive
    tWheelsShader.specular = rgb(200, 200, 200)
    tWheelsShader.shininess = 85.0
  end if
  tList.shaders.add(tShader)
  tList.shaders.add(tGlassShader)
  if tWheelsShader <> VOID then
    tList.shaders.add(tWheelsShader)
  end if
  tList.textures.add(tCarTexture)
  if (tCar <> "Autobot") and (tCar <> "Tank") then
    if tWeapons.primary <> "none" then
      tWeapon = tWeapons.primary
      if tWeapon = "Minigun" then
        tWeaponList = ["MiniGun", "MiniGunBarrel"]
      else
        if tWeapon = "DualMinigun" then
          tWeaponList = ["DualMiniGun", "DualMiniGunBarrel1", "DualMiniGunBarrel2"]
        else
          tWeaponList = [tWeapon]
        end if
      end if
      tModelList = CloneModel(0, tmember.name, [#sourceMember: "Weapons", #model: tWeaponList, #NameTag: tCar])
      if tModelList.ilk <> #list then
        tModelList = [tModelList]
      end if
      if tModelList.count > 1 then
        tmodel = tModelList[1]
        repeat with i = 2 to tModelList.count
          tOtherModel = tModelList[i]
          tOtherModel.transform = tmodel.getWorldTransform().inverse() * tOtherModel.transform
          tOtherModel.parent = tmodel
        end repeat
      end if
      tModelList[1].transform = tList.groups.primary1.getWorldTransform()
      repeat with i in tModelList
        tList.Weapons.add(i)
      end repeat
    end if
  end if
  if (tCar <> "Autobot") and (tCar <> "Tank") then
    if tWeapons.secondary <> "none" then
      tWeapon = tWeapons.secondary
      if tWeapon = "RocketPod" then
        tWeaponList = ["RocketPodLeft", "RocketPodRight"]
      else
        tWeaponList = [tWeapon]
      end if
      tModelList = CloneModel(0, tmember.name, [#sourceMember: "Weapons", #model: tWeaponList, #NameTag: tCar])
      if tModelList.ilk <> #list then
        tModelList = [tModelList]
      end if
      if tWeapon = "GrenadeLauncher" then
        tModelList[1].transform = tList.groups.Secondary1.getWorldTransform()
      end if
      if tWeapon = "AirstrikeLauncher" then
        tModelList[1].transform = tList.groups.Secondary1.getWorldTransform()
      end if
      if tWeapon = "MineDeployer" then
        tModelList[1].transform = tList.groups.Secondary2.getWorldTransform()
      end if
      if tWeapon = "GrenadeDeployer" then
        tModelList[1].transform = tList.groups.Secondary2.getWorldTransform()
      end if
      if tWeapon = "NitroBoost" then
        tModelList[1].transform = tList.groups.Secondary2.getWorldTransform()
      end if
      if tWeapon = "RocketPod" then
        tModelList[1].transform = tList.groups.Secondary3.getWorldTransform()
        tModelList[2].transform = tList.groups.Secondary4.getWorldTransform()
      end if
      repeat with i in tModelList
        tList.Weapons.add(i)
      end repeat
    end if
  end if
  gGame.SafeHouseStore.carsBuild[tCar] = tList
end

on SafeHouseDeleteCars me
  tmember = member("World" & gGame.world)
  repeat with i in gGame.SafeHouseStore.carsBuild
    repeat with j in i.models
      tMName = j.name
      tRName = j.resource.name
      tmember.deleteModel(tMName)
      tmember.deleteModelResource(tMName)
    end repeat
    repeat with j in i.groups
      tmember.deleteGroup(j.name)
    end repeat
    repeat with j in i.shaders
      tmember.deleteShader(j.name)
    end repeat
    repeat with j in i.textures
      tmember.deleteTexture(j.name)
    end repeat
    repeat with j in i.Weapons
      tMName = j.name
      tRName = j.resource.name
      tmember.deleteModel(tMName)
      tmember.deleteModelResource(tMName)
    end repeat
  end repeat
end

on SafeHouseCreateCar me
  tCar = gGame.SafeHouseStore.currentSelection
  repeat with i = 1 to gData.data.car.PlayerCar.count
    tProp = gData.data.car.PlayerCar[i]
    if tProp = #skin then
      next repeat
      next repeat
    end if
    gData.data.car.PlayerCar[i] = tCar
  end repeat
  if tCar = "Autobot" then
    tScript = script("[PS] Autobot").new([#member: "World" & gGame.world, #ScriptName: "PlayerCar", #controller: #player, #States: gGame.PlayerStatesAutobot.duplicate()])
  else
    tScript = script("[PS] Advanced Car").new([#member: "World" & gGame.world, #ScriptName: "PlayerCar", #controller: #player, #States: gGame.PlayerStatesCar.duplicate()])
  end if
  tPos = gGame.scriptList.getPos(GetScript(0, EMPTY, [#script: "Camera1"]))
  gGame.scriptList.addAt(tPos, tScript)
  t = gGame.vehicles[1]
  tShaderList = t.Vehicle.shaderList
  repeat with i in tShaderList
    if i.name contains "Proxy" then
      next repeat
    end if
    if i.name contains "Light" then
      next repeat
    end if
    if i.name contains "Shadow" then
      i.diffuse = rgb(0, 0, 0)
      i.ambient = rgb(0, 0, 0)
      i.useDiffuseWithTexture = 1
    end if
    i.ambient = rgb(255, 255, 255)
    i.emissive = gData.data.ambientStyle[symbol("World" & gGame.world & gGame.setting)].emissive
  end repeat
  AddScript(0, EMPTY, [#script: "[PS] Vehicle Shadow Caster", #data: [#member: "World" & gGame.world, #light: "Sun", #tag: gGame.vehicles.count]])
  gGame.camera[1].target = gGame.vehicles[1].general.tag
  gGame.camera[1].DefaultSet = symbol(tCar)
  UpdateCameraSet(0, symbol(tCar))
end
