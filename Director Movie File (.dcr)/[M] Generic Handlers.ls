-- [Script] [M] Generic Handlers (Script #5854)
-- Script Type: Movie

global gSystem, gData, gGame, gSound

on LoadData me
  PutMessage(0, "--> Loading data (Handler)")
  if _player.runMode contains "Author" then
    PutMessage(0, "--> --> No data loading when 'Author' runmode")
    return 0
  end if
  tForceSave = 0
  tLocalData = _player.getPref(gGame.PrefFile)
  if tLocalData = VOID then
    PutMessage(0, "--> Couldn't find a BR4: GOTY savegame. Checking for older BR4 version:...")
    tOldLocalData = _player.getPref("XBR4Data.txt")
    if tOldLocalData = VOID then
      PutMessage(0, "--> Couldn't find an older BR4 version either. This is a first play and we do nothing further.")
    else
      PutMessage(0, "--> Found an older BR4 version. Check if data is usable...")
      tOldList = DecodeAndRetrieveData(0, tOldLocalData, 1)
      if tOldList = VOID then
        PutMessage(0, "--> Found an older BR4 version. However data is unusable or corrupted. This is then a first play and we do nothing further.")
      else
        PutMessage(0, "--> Found an older BR4 version. Data is usable. Converting old BR4 savegame to new BR4: GOTY savegame...")
        tOldList.version = #BR4GOTY
        tOldList.globals.Lightmaps = 0
        tOldList.globals.Effects = #medium
        tOldList.globals.world = "City"
        tPos = tOldList.globals.UPCars.getPos("PetiteXS")
        if tPos <> 0 then
          tOldList.globals.UPCars[tPos] = "PetiteXs"
          PutMessage(0, "--> Converting old BR4 savegame to new BR4: GOTY savegame. Updated car name.")
        end if
        tOldList.globals.UPStatistics.timeTrialsCompleted[2] = gGame.UPStatistics.timeTrialsCompleted[2]
        tOldList.globals.UPStatistics.rampagesCompleted[2] = gGame.UPStatistics.rampagesCompleted[2]
        tOldList.globals.UPStatistics.demolitionsCompleted[2] = gGame.UPStatistics.demolitionsCompleted[2]
        tOldList.globals.UPStatistics.nuclearDetonators[2] = gGame.UPStatistics.nuclearDetonators[2]
        tOldList.globals.UPStatistics.Landmarks[2] = gGame.UPStatistics.Landmarks[2]
        tList = tOldList.duplicate()
        PutMessage(0, "--> Converting old BR4 savegame to new BR4: GOTY savegame. SAVEGAME CONVERTED!")
        tForceSave = 1
      end if
    end if
  else
    tList = DecodeAndRetrieveData(0, tLocalData, 1)
  end if
  if tList = VOID then
    PutMessage(0, "--> Loading data either absent or impossible to decode")
  else
    if voidp(tList[#version]) = 1 then
      _player.setPref(gGame.PrefFile, string(EMPTY))
      PutMessage(0, "--> --> Save data reset. Absence of version info.")
    else
      tVersionData = value(member("GameVersion").text)
      tVersion = tVersionData.version
      if voidp(tList[#globals]) = 0 then
        repeat with i = 1 to tList[#globals].count
          tProp = tList[#globals].getPropAt(i)
          if (tList[#globals][i].ilk = #list) or (tList[#globals][i].ilk = #propList) then
            gGame[tProp] = tList[#globals][i].duplicate()
            next repeat
          end if
          gGame[tProp] = tList[#globals][i]
        end repeat
      end if
      if voidp(tList[#data]) = 0 then
        repeat with i = 1 to tList[#data].count
          tProp = tList[#data].getPropAt(i)
          repeat with j = 1 to tList.data[tProp].count
            tProp2 = tList[#data][tProp].getPropAt(j)
            gData.data[tProp][tProp2] = tList.data[i][j].duplicate()
          end repeat
        end repeat
      end if
      repeat with i = 1 to gData.data.car.PlayerCar.count
        tProp = gData.data.car.PlayerCar[i]
        if tProp = #skin then
          next repeat
          next repeat
        end if
        gData.data.car.PlayerCar[i] = gGame.car
      end repeat
      if gGame.ReturnFromHub = 0 then
        gGame.WorldStartDummy.CITY = "SafeHouseCity_Marker"
      end if
      gGame.ReturnFromHub = 0
      tSW1 = (the systemDate).day
      if tSW1 <> VOID then
        if voidp(tList.globals[#DailyChallengeSW1]) = 1 then
          UpdateDailyChallengeData(0, tSW1)
        else
          if tList.globals.DailyChallengeSW1 = tSW1 then
            nothing()
          else
            UpdateDailyChallengeData(0, tSW1)
          end if
        end if
      end if
      gGame.GameLoaded = 1
      gGame.NewGame = 0
      PutMessage(0, "Data loaded! (Handler)")
      if tForceSave = 1 then
        SaveData()
      end if
    end if
  end if
  tSW1 = (the systemDate).day
  if tSW1 <> VOID then
    if gGame.DailyChallengeSW1 = tSW1 then
      nothing()
    else
      UpdateDailyChallengeData(0, tSW1)
    end if
  end if
end

on LoadDataBR3 me
  PutMessage(0, "--> Load Data BR3 (Handler)")
  if _player.runMode contains "Author" then
    PutMessage(0, "--> --> No data loading when 'Author' runmode")
    return 0
  end if
  tLocalData = _player.getPref("XBR3Data.txt")
  tList = DecodeAndRetrieveData(0, tLocalData, 1)
  if tList = VOID then
    PutMessage(0, "--> Loading BR3 data either absent or impossible to decode")
  else
    if tList.ilk = #propList then
      if voidp(tList[#Trophies]) = 0 then
        if voidp(tList.Trophies[#Worlddomination]) = 0 then
          if tList.Trophies.Worlddomination = 1 then
            if gGame.UPCars.getPos("Tank") = 0 then
              PutMessage(0, "--> --> You've finished Burnin Rubber 3 completely. As a reward the tank is available in your safehouse!")
              gGame.TankMessage = 1
              gGame.UPCars.add("Tank")
            else
              PutMessage(0, "--> --> You've finished Burnin Rubber 3 completely. However, you already have the tank!")
            end if
          end if
        end if
      end if
    end if
  end if
end

on SaveData me, tTarget, tDataList
  PutMessage(0, "--> Saving data (Handler)")
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    tDataList = [:]
  end if
  tProgress = 1
  if tDataList[#progress].ilk = #integer then
    if tDataList.progress = 0 then
      tProgress = 0
    end if
  end if
  if tProgress = 1 then
    ShowSaveProgress()
  end if
  if _player.runMode = "Author" then
    PutMessage(0, "No saving in author mode.")
    return 0
  end if
  tSaveList = [:]
  tVersionData = value(member("GameVersion").text)
  tVersion = tVersionData.version
  tSaveList[#version] = tVersion
  tSaveList[#globals] = [:]
  tList = [#car, #money, #world, #sound, #Effects, #FirstTicket, #UPTickets, #UPBossTickets, #UPChallenges, #UPChallengesNew, #UpChallengesCompleted, #UpChallengesPrestige, #UPSpecialMissionsCompleted, #UpRampagesCompleted, #UpDemolitionsCompleted, #UpTimeTrialsCompleted, #UPCars, #UPCashStashes, #UPLandMarks, #UPNuclearDetonators, #UPHiddenPackages, #UPTrophies, #UPStatistics, #UPUnlockableCheats, #DailyChallengeSW1, #DailyChallengeDay, #DailyChallengeState, #DailyChallengeLastTime]
  repeat with i in tList
    if (gGame[i].ilk = #list) or (gGame[i].ilk = #propList) then
      tSaveList[#globals][i] = gGame[i].duplicate()
      next repeat
    end if
    tSaveList[#globals][i] = gGame[i]
  end repeat
  tSaveList[#data] = [:]
  tSaveList.data[#car] = [:]
  repeat with i in gGame.AvailableCars
    tSaveList.data.car[symbol(i)] = gData.data.car[symbol(i)].duplicate()
  end repeat
  tSaveList.data[#CarUpgrades] = [:]
  repeat with i in gGame.AvailableCars
    tSaveList.data.CarUpgrades[symbol(i)] = gData.data.CarUpgrades[symbol(i)].duplicate()
  end repeat
  tSaveList.data[#CarWeapons] = [:]
  repeat with i in gGame.AvailableCars
    tSaveList.data.CarWeapons[symbol(i)] = gData.data.CarWeapons[symbol(i)].duplicate()
  end repeat
  EncodeAndSaveData(0, tSaveList, 1)
  PutMessage(0, "--> --> Data saved! (Handler)")
end

on UpdateTrackInfo me, tTarget, tDataList
  PutMessage(0, "--> UpdateTrackInfo (Handler)")
  if voidp(gGame[#trackInfo]) = 1 then
    gGame[#trackInfo] = [:]
  end if
  tTrack = gGame.track
  if tTrack contains "World" then
    tTrack = tTrack & gGame.setting
  end if
  if gData.Info.trackInfo.getaProp(symbol(tTrack)) <> VOID then
    gGame[#trackInfo] = gData.Info.trackInfo[symbol(tTrack)].duplicate()
  end if
  if (gGame.trackInfo.Enemies.ilk <> #list) and (gGame.trackInfo.Enemies <> #none) then
    gGame.trackInfo.Enemies = [gGame.trackInfo.Enemies]
  end if
  gGame.Assets = gGame.trackInfo.Assets
end

on UpdateSWTrophies me
  PutMessage(0, "--> UpdateSWTrophies (Handler)")
  gGame.SWGameTrophies = gGame.SWTrophies.duplicate()
  member("SWHighscore").text = "0"
end

on CollectSWTrophies me
  PutMessage(0, "--> CollectSWTrophies (Handler)")
  gGame.SWGameTrophies.RoadRaceWon = 1
  gGame.SWGameTrophies.score = gGame.money
  if gGame.UPHiddenPackages.count >= 36 then
    gGame.SWGameTrophies.AllPackages = 1
  end if
  if gGame.UPCars.count >= 15 then
    gGame.SWGameTrophies.AllVehicles = 1
  end if
  tList = ["SpecialMissionSpeedBoat", "SpecialMissionCoastGuard", "SpecialMissionStealth"]
  if tList.getPos(gGame.track) <> 0 then
    gGame.SWGameTrophies.BoatChallenge = 1
  end if
  tList = ["SpecialMissionConvoy", "SpecialMissionDogFight", "SpecialMissionAC130"]
  if tList.getPos(gGame.track) <> 0 then
    gGame.SWGameTrophies.BoatChallenge = 1
  end if
end

on UPdateSWTrophyExplosion me
  if voidp(gGame[#SWGameTrophies]) = 0 then
    if voidp(gGame.SWGameTrophies[#explosion]) = 0 then
      gGame.SWGameTrophies.explosion = gGame.SWGameTrophies.explosion + 1
    end if
  end if
end

on GetChallengeType me
  PutMessage(0, "--> CheckAndSetChallengeType (Handler)")
  if gGame.track contains "SpecialMission" then
    gGame.ChallengeType = #SpecialMission
  else
    if gGame.track contains "BossEnd" then
      gGame.ChallengeType = #SpecialMission
    else
      if gGame.DailyChallenge = 1 then
        gGame.ChallengeType = #SpecialMission
      else
        gGame.ChallengeType = #normal
      end if
    end if
  end if
end

on GetTicket me
  PutMessage(0, "--> GetTicket (Handler)")
  if gGame.DailyChallenge = 0 then
    gGame.Ticket = gData.Info.trackInfo[symbol(gGame.track)].Ticket
  end if
end

on SubmitHighscore me
  PutMessage(0, "--> Submit highscore (Handler)")
  sendSprite(11, #mouseDown)
  (the stage).bgColor = (the stage).bgColor
  _movie.updateStage()
  sendSprite(11, #mouseUp)
end

on CheckAllHiddenPackages me
  PutMessage(0, "--> CheckAllHiddenPackages (Handler)")
  if gGame.UPHiddenPackages.count = 36 then
    UpdateMoney()
  end if
end

on UpdateChallengeNormalMoney me
  PutMessage(0, "--> ShowEndChallengeNormalMoney (Handler)")
  if gGame.RaceResult = #Defeat then
    tPrizeMoney = 0
    tCashBonus = 0
    tTotalMoney = 0
  else
    tPrizeMoney = gGame.trackInfo.PrizeMoney
    tCashBonus = gGame.vehicles[1].race.score
    tTotalMoney = tPrizeMoney + tCashBonus
  end if
  tString = FormatMoney(0, string(tPrizeMoney))
  CreateTextTexture(0, "Interface", [#tag: #ResultsTicketBigRewardMoneyText, #style: #ResultsPrizeMoney, #text: tString, #color: #red, #align: #right])
  tString = FormatMoney(0, string(tCashBonus))
  CreateTextTexture(0, "Interface", [#tag: #ResultsTicketBigCashBonusMoneyText, #style: #ResultsCashBonus, #text: tString, #color: #red, #align: #right])
  tString = FormatMoney(0, string(tTotalMoney))
  CreateTextTexture(0, "Interface", [#tag: #ResultsTicketBigTotalMoneyText, #style: #ResultsTotalMoney, #text: tString, #color: #red, #align: #right])
  gGame.money = gGame.money + tTotalMoney
  UpdateMoney()
end

on UpdateHiddenPackageAndCompleted me
  PutMessage(0, "--> UpdateHiddenPackageAndCompleted (Handler)")
  if gGame.UPHiddenPackages.getPos(gGame.track) = 0 then
    SETVISIBLE(0, "Interface", [#model: "ResultsTicketBigHiddenPackage", #state: 0])
  else
    SETVISIBLE(0, "Interface", [#model: "ResultsTicketBigHiddenPackage", #state: 1, #parent: "ResultsTicketBig"])
  end if
  if gGame.UpChallengesCompleted.getPos(gGame.track) = 0 then
    SETVISIBLE(0, "Interface", [#model: "ResultsTicketBigStatus", #state: 0])
  else
    SETVISIBLE(0, "Interface", [#model: "ResultsTicketBigStatus", #state: 1, #parent: "ResultsTicketBig"])
  end if
  if gGame.UpChallengesPrestige.getPos(gGame.track) = 0 then
    SETVISIBLE(0, "Interface", [#model: "ResultsTicketBigPrestige", #state: 0])
  else
    SETVISIBLE(0, "Interface", [#model: "ResultsTicketBigPrestige", #state: 1, #parent: "ResultsTicketBig"])
  end if
end

on UpdateRewards me
  PutMessage(0, "--> UpdateRewards (Handler)")
  if gGame.RaceResult = #Victory then
    member("SWHighscore").text = string(gGame.money)
    t = gGame.vehicles[1]
    CollectSWTrophies()
    if gGame.trackInfo.Rewards <> #none then
      if gGame.UPCars.getPos(gGame.trackInfo.Rewards) = 0 then
        gGame.UPCars.add(gGame.trackInfo.Rewards)
      end if
      CreateTextTexture(0, "Interface", [#tag: #ResultsUnlockText, #style: #UnlockedNewCar])
      SETVISIBLE(0, "Interface", [#model: "ResultsUnlockText", #state: 1, #parent: "Results"])
    else
      SETVISIBLE(0, "Interface", [#model: "ResultsUnlockText", #state: 0, #parent: "Results"])
    end if
  else
    SETVISIBLE(0, "Interface", [#model: "ResultsUnlockText", #state: 0, #parent: "Results"])
  end if
  SaveData()
end

on RemoveFromNew me
  PutMessage(0, "--> RemoveFromNew (Handler)")
  tTicket = gGame.trackInfo.Ticket
  if gGame.UPChallengesNew.getPos(tTicket) <> 0 then
    gGame.UPChallengesNew.deleteOne(tTicket)
  end if
end

on UpdateChallengeSpecialMissionMoney me, tTarget, tDataList
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    tDataList = [:]
  end if
  tUnlock = 0
  if tDataList[#UNLOCK].ilk = #integer then
    tUnlock = tDataList.UNLOCK
  end if
  if gGame.DailyChallenge = 1 then
    tPrizeMoney = gData.Info.trackInfo[symbol("DailyChallenge" & gGame.DailyChallengeDay)].PrizeMoney
  else
    tPrizeMoney = gData.Info.trackInfo[symbol(gGame.SpecialMission)].PrizeMoney
  end if
  tString = FormatMoney(0, string(tPrizeMoney))
  CreateTextTexture(0, "Interface", [#tag: #SpecialMissionRewardText, #style: #SpecialMissionReward2, #text: tString])
  tString = #SpecialMissionAlreadyUnlocked
  if (gGame.SpecialMission = "SpecialMissionBridge") and (gGame.UPSpecialMissionsCompleted.getPos(gGame.SpecialMission) = 0) then
    tString = #SpecialMissionUnlockArea
  end if
  if (gGame.SpecialMission = "SpecialMissionTunnel") and (gGame.UPSpecialMissionsCompleted.getPos(gGame.SpecialMission) = 0) then
    tString = #SpecialMissionUnlockArea
  end if
  if (gGame.SpecialMission = "SpecialMissionDock") and (gGame.UPSpecialMissionsCompleted.getPos(gGame.SpecialMission) = 0) then
    tString = #SpecialMissionUnlockArea
  end if
  if (gGame.SpecialMission = "SpecialMissionSpeedBoat") and (gGame.UPSpecialMissionsCompleted.getPos(gGame.SpecialMission) = 0) then
    tString = #SpecialMissionUnlockSpecialMission
  end if
  if (gGame.SpecialMission = "SpecialMissionCoastGuard") and (gGame.UPSpecialMissionsCompleted.getPos(gGame.SpecialMission) = 0) then
    tString = #SpecialMissionUnlockSpecialMission
  end if
  if (gGame.SpecialMission = "SpecialMissionStealth") and (gGame.UPSpecialMissionsCompleted.getPos(gGame.SpecialMission) = 0) then
    tString = #SpecialMissionUnlockCar
  end if
  if (gGame.SpecialMission = "SpecialMissionConvoy") and (gGame.UPSpecialMissionsCompleted.getPos(gGame.SpecialMission) = 0) then
    tString = #SpecialMissionUnlockSpecialMission
  end if
  if (gGame.SpecialMission = "SpecialMissionDogfight") and (gGame.UPSpecialMissionsCompleted.getPos(gGame.SpecialMission) = 0) then
    tString = #SpecialMissionUnlockSpecialMission
  end if
  if (gGame.SpecialMission = "SpecialMissionAC130") and (gGame.UPSpecialMissionsCompleted.getPos(gGame.SpecialMission) = 0) then
    tString = #SpecialMissionUnlockCar
  end if
  if (gGame.SpecialMission = "SpecialMissionTaxi") and (gGame.UPSpecialMissionsCompleted.getPos(gGame.SpecialMission) = 0) then
    tString = #SpecialMissionUnlockCar
  end if
  if (gGame.SpecialMission = "SpecialMissionPolice") and (gGame.UPSpecialMissionsCompleted.getPos(gGame.SpecialMission) = 0) then
    tString = #SpecialMissionUnlockCar
  end if
  if gGame.SpecialMission = "SpecialMissionTank" then
    tString = #SpecialMissionTank
  end if
  if (gGame.SpecialMission = "BossEnd") and (gGame.UPSpecialMissionsCompleted.getPos(gGame.SpecialMission) = 0) then
    tString = #SpecialMissionUnlockCar
  end if
  if gGame.DailyChallenge = 1 then
    CreateTextTexture(0, "Interface", [#tag: #SpecialMissionUnlockHeaderText, #style: #SpecialMissionSpecial, #text: #DailyChallengeUnlockHeaderText])
    put gGame.DailyChallengeLastTime
    tString = GetTimeDailyChallenge(0, gGame.DailyChallengeLastTime)
  end if
  CreateTextTexture(0, "Interface", [#tag: #SpecialMissionUnlockText, #style: #SpecialMissionSpecial2, #text: tString])
  if tUnlock = 0 then
    UpdateMoney()
  else
    if gGame.RaceResult = #Victory then
      if gGame.DailyChallenge = 0 then
        event(0, #AddToSpecialMissionList)
      end if
      gGame.money = gGame.money + tPrizeMoney
    end if
    UpdateMoney()
    if gGame.DailyChallenge = 1 then
      case gGame.RaceResult of
        #Victory:
          gGame.DailyChallengeState = #cleared
        #Defaut:
          gGame.DailyChallengeState = #failed
      end case
    end if
    member("SWHighscore").text = string(gGame.money)
  end if
end

on UpdateSpecialMissionRewards me
  t = gGame.vehicles[1]
  CollectSWTrophies()
  if gGame.RaceResult = #Victory then
    if gGame.trackInfo.Rewards <> #none then
      if gGame.UPCars.getPos(gGame.trackInfo.Rewards) = 0 then
        gGame.UPCars.add(gGame.trackInfo.Rewards)
      end if
    end if
  end if
  SaveData()
end

on CreatePrestigeTextTexture me
  tString = gData.data.text.PrestigeChallenge && GetPrestigeTime(0, gGame.trackInfo.PrestigeTarget)
  CreateTextTexture(0, "Interface", [#tag: #ResultsTicketBigPrestigeGoalText, #style: #ResultsGoal, #text: tString])
end

on GetPrestigeTime me, tMillisec
  sec = integer(tMillisec / 1000)
  min = integer(sec / 60)
  sec = sec - (min * 60)
  Hour = integer(min / 60)
  min = min - (Hour * 60)
  tMillisec = integer((tMillisec - (sec * 1000) - (min * 60 * 1000) - (Hour * 60 * 60 * 1000)) / 10.0)
  if min < 10 then
    minString = "0" & string(min + 100).char[3..3] & ":"
  else
    minString = string(min + 100).char[2..3] & ":"
  end if
  secString = string(sec + 100).char[2..3] & "."
  if tMillisec < 10 then
    MilliString = "0" & string(tMillisec)
  else
    MilliString = string(tMillisec)
  end if
  if tMillisec = 100 then
    MilliString = "00"
  end if
  return minString & secString & MilliString
end

on checkPrestige me
  gGame[#Prestige] = 0
  if gGame.trackInfo.GameMode = "Battle" then
    if gGame.timer <= gGame.trackInfo.PrestigeTarget then
      gGame[#Prestige] = 1
    end if
  else
    tTimeNeeded = gGame.trackInfo.target - gGame.timer
    if tTimeNeeded <= gGame.trackInfo.PrestigeTarget then
      gGame[#Prestige] = 1
    end if
  end if
  if (gGame.Prestige = 1) and (gGame.DailyChallenge = 0) then
    if gGame.UpChallengesPrestige.getPos(gGame.track) = 0 then
      gGame.UpChallengesPrestige.add(gGame.track)
    end if
  end if
end

on CheckWhereToGo me
  PutMessage(0, "--> CheckWhereToGo")
  gGame.Vehicle = "Car"
  tBoatList = ["SpecialMissionSpeedBoat", "SpecialMissionCoastGuard", "SpecialMissionStealth"]
  if tBoatList.getPos(gGame.track) <> 0 then
    gGame.Vehicle = "Boat"
  end if
  if tBoatList.getPos(gGame.track) <> 0 then
    gGame.world = "Jungle"
  end if
  if gGame.track contains "SpecialMission" then
    gGame.WorldStartDummy[symbol(gGame.world)] = gGame.track & "_Marker"
  else
    if gGame.track contains "BossEnd" then
      gGame.WorldStartDummy[symbol(gGame.world)] = "BossEndChallengeCity_Marker"
    else
      if gGame.track contains "DailyChallenge" then
        gGame.WorldStartDummy[symbol(gGame.world)] = "DailyChallenge_Marker"
      else
        gGame.WorldStartDummy[symbol(gGame.world)] = "TicketMaster" & gGame.world & "_Marker"
      end if
    end if
  end if
  PutMessage(0, "--> --> The startmarker of " & gGame.world & " has been set to: " & string(gGame.WorldStartDummy[symbol(gGame.world)]))
end

on UpdateVehicleType me
  PutMessage(0, "--> UpdateVehicleType")
  if gGame.track = "SpecialMissionConvoy" then
    gGame.plane = "Apache"
  end if
  if gGame.track = "SpecialMissionDogfight" then
    gGame.plane = "Spitfire"
  end if
  if gGame.track = "SpecialMissionAC130" then
    gGame.plane = "F22"
  end if
  repeat with i = 1 to gData.data.car.PlayerPlane.count
    tProp = gData.data.car.PlayerPlane.getPropAt(i)
    if tProp = #skin then
      next repeat
    end if
    gData.data.car.PlayerPlane[i] = gGame.plane
  end repeat
end

on EventTracking me
end

on RestoreAmmo me
  t = gGame.vehicles[1]
  tPrimary = symbol(t.general.data.Weapons.primary)
  tSecondary = symbol(t.general.data.Weapons.secondary)
  if tPrimary <> #none then
    t.Weapons[tPrimary].ammo[1] = t.Weapons[tPrimary].ammo[2]
    t.Weapons[tPrimary].clips = t.general.data.upgrades.primary[1]
  end if
  if tSecondary <> #none then
    t.Weapons[tSecondary].ammo[1] = t.Weapons[tSecondary].ammo[2]
    t.Weapons[tSecondary].clips = t.general.data.upgrades.secondary[1]
  end if
end

on Detonate me, tSender
  tmodel = gGame.ItemModel
  if tSender = VOID then
    tSender = gGame.CurrentVehicle
  end if
  tParent = tmodel.parent
  if tParent.userData.getaProp(#objects) <> VOID then
    tList = tParent.userData.objects
  else
    tParent = tParent.parent
    tgroup = tParent.userData.objectGroup
    tList = tgroup.userData.objects
  end if
  tCount = tList.count
  repeat with i = 1 to tCount
    if tList[i] = VOID then
      next repeat
    end if
    tName = tList[i].name
    if gGame.fx.Destruction.getPos(tName) <> 0 then
      timeout().new(tName & "Detonate", i * 70, #TimedDetonation, [tName])
    end if
  end repeat
end

on TimedDetonation tList, tTimeOut
  tTimeOut.forget()
  tmodel = gGame.member.model(tList[1])
  if tmodel = VOID then
    return 0
  end if
  if tmodel.userData.Health > 0 then
    DestroyObject(0, gGame.member.name, [#model: tList[1], #sender: #Detonator])
  end if
end

on UpdateBR4CameraSet me, tCurrentSet
  PutMessage(0, " --> UpdateBR4CameraSet (Very special handler)")
  tSet = gData.data.camera.default.duplicate()
  if gData.data.camera.getaProp(symbol(gGame[symbol(gGame.Vehicle)])) <> VOID then
    tSet = gData.data.camera[symbol(gGame[symbol(gGame.Vehicle)])].duplicate()
  end if
  if tSet <> VOID then
    gData.data.camera.car = tSet
    return tSet
  else
    return tCurrentSet
  end if
end

on HoldCarForShop me
  t = gGame.vehicles[1]
  t.Vehicle.hold = gGame[#HoldPosition]
  reset_keyInput(0, t, #hold)
end

on ReleaseCarFromShop me
  t = gGame.vehicles[1]
  t.Vehicle.hold = #none
end

on CheckSpecialMissionRequirements me
  tTrack = gGame.CurrentMarker
  tReq = gData.Info.trackInfo[symbol(tTrack)].Requirement
  if (tReq = #none) or (tReq = 0) then
    event(0, #EnterSpecialMission)
  else
    tFinished = gGame.UpChallengesCompleted.count
    if tReq <= tFinished then
      event(0, #EnterSpecialMission)
    else
      CreateTextTexture(0, "Interface", [#tag: #InterfaceStatusHeaderText, #style: #StatusTitle, #text: #SpecialMissionUnavailableTitle])
      CreateTextTexture(0, "Interface", [#tag: #InterfaceStatusBodyText, #style: #StatusBody, #text: symbol(tTrack & "Requirements")])
      SETVISIBLE(0, "Interface", [#model: "InterfaceStatus", #state: 1, #parent: "World"])
      DelayEvent(0, EMPTY, [#delay: gGame.StatusDelay, #name: "HideStatus", #event: "HideStatus"])
      PlaySound(0, "Status_SFX", [#Override: 1])
    end if
  end if
end

on SetupSpecialMission me
  PutMessage(0, "--> SetupSpecialMission (Handler)")
  if gGame.CurrentMarker = "BossEndChallengeCity" then
    gGame.track = "BossEnd"
  else
    gGame.track = gGame.CurrentMarker
  end if
  gGame.SpecialMission = gGame.track
  UpdateTrackInfo()
  event(0, #ShowSpecialMission)
end

on SetupDailyChallenge me
  PutMessage(0, "--> SetupDailyChallenge (Handler)")
  tTrack = gGame.CurrentMarker & gGame.DailyChallengeDay
  tPrizeMoney = gData.Info.trackInfo[symbol(tTrack)].PrizeMoney
  tString = FormatMoney(0, string(tPrizeMoney))
  CreateTextTexture(0, "Interface", [#tag: #DailyChallengeRewardText, #style: #SpecialMissionReward2, #text: tString])
  if gGame.DailyChallengeLastTime = #none then
    tString = gData.data.text.DailyChallengeNotPlayed
  else
    tString = GetTimeDailyChallenge(0, gGame.DailyChallengeLastTime)
  end if
  CreateTextTexture(0, "Interface", [#tag: #SpecialMissionUnlockText, #style: #SpecialMissionSpecial2, #text: tString])
end

on GetTimeDailyChallenge me, tMillisec
  sec = integer(tMillisec / 1000)
  min = integer(sec / 60)
  sec = sec - (min * 60)
  Hour = integer(min / 60)
  min = min - (Hour * 60)
  tMillisec = integer((tMillisec - (sec * 1000) - (min * 60 * 1000) - (Hour * 60 * 60 * 1000)) / 10.0)
  if min < 10 then
    minString = "0" & string(min + 100).char[3..3] & ":"
  else
    minString = string(min + 100).char[2..3] & ":"
  end if
  secString = string(sec + 100).char[2..3] & "."
  if tMillisec < 10 then
    MilliString = "0" & string(tMillisec)
  else
    MilliString = string(tMillisec)
  end if
  if tMillisec = 100 then
    MilliString = "00"
  end if
  return minString & secString & MilliString
end

on ConfirmDailyChallenge me
  PutMessage(0, "--> ConfirmDailyChallenge (Handler)")
  gGame.DailyChallenge = 1
  gGame.track = gGame.CurrentMarker & gGame.DailyChallengeDay
  UpdateTrackInfo()
  gGame.track = gGame.CurrentMarker
end

on UpdateDailyChallengeData me, tSW1
  PutMessage(0, "ResetDailyChallenge (Handler)")
  tList = [16, 22, 12, 19, 8, 24, 18, 15, 21, 13, 4, 5, 3, 30, 27, 1, 29, 23, 7, 14, 10, 9, 2, 20, 26, 11, 31, 17, 25, 6, 28]
  tDay = tSW1
  tNewDay = tList[tDay]
  gGame.DailyChallengeSW1 = tSW1
  gGame.DailyChallengeDay = tNewDay
  gGame.DailyChallengeState = #new
  gGame.DailyChallengeLastTime = #none
end

on StoreDailyChallengeTime me
  gGame.DailyChallengeLastTime = gGame.timer
end

on PrintScreen me
  if gSystem.local = 0 then
    exit
  end if
  t = gGame.vehicles[1]
  tList = []
  repeat with i = 1 to _movie.lastChannel
    tDTS = 0
    if sprite(i).member.type = #shockwave3d then
      tDTS = sprite(i).directToStage
      sprite(i).directToStage = 0
    end if
    sprite(i).locZ = i + 999
    tEntry = [i, tDTS]
    tList.add(tEntry)
  end repeat
  _movie.updateStage()
  (the stage).bgColor = (the stage).bgColor
  _movie.updateStage()
  (the stage).bgColor = (the stage).bgColor
  tImage = _movie.stage.image
  member("Screenshot").image = tImage
  tTimeStamp = _system.milliSeconds
  if gGame.Scene = "World" then
    tImgName = gGame.grid.center[1] & "_" & "World" & gGame.world & "_" & tTimeStamp & ".jpg"
  else
    tImgName = gGame.track & "_" & tTimeStamp & ".jpg"
  end if
  tImgXtra = new(xtra("SharpExport"))
  if gGame.Scene = "World" then
    tImgXtra.exportJPG(member("Screenshot"), "D:\Projects\BurninRubber4\2D\Bugs\" & gGame.world & "\" & tImgName, 75)
  else
    tImgXtra.exportJPG(member("Screenshot"), "D:\Projects\BurninRubber4\2D\Bugs\Tracks\" & tImgName, 75)
  end if
  tImgXtra = VOID
  tCount = tList.count
  repeat with i = 1 to tCount
    tEntry = tList[i]
    if tEntry[2] = 1 then
      sprite(tEntry[1]).directToStage = 1
    end if
    sprite(tEntry[1]).locZ = tEntry[1]
  end repeat
  tList = []
end

on CheckBossEndAvailability me
  PutMessage(0, "--> CheckBossEndAvailability (Handler)")
  if gGame.UpChallengesCompleted.count >= 36 then
    PutMessage(0, "--> --> BossEnd available")
    if member("World" & gGame.world).model("BossEndChallengeCity_Marker") = VOID then
      AddMarker(0, "World" & gGame.world, [#position: "BossEndChallengeCity_Marker", #type: #BossEnd])
    else
      PutMessage(0, "--> --> BossEnd marker already available.")
    end if
  else
    PutMessage(0, "--> --> No BossEnd available.")
  end if
end

on CheckJungleSpecialMissions me
  PutMessage(0, "--> CheckJungleSpecialMissions (Handler)")
  if gGame.UPSpecialMissionsCompleted.getPos("SpecialMissionSpeedBoat") <> 0 then
    AddMarker(0, "World" & gGame.world, [#position: "SpecialMissionCoastGuard_Marker", #type: #SpecialMission, #priority: #medium])
  end if
  if gGame.UPSpecialMissionsCompleted.getPos("SpecialMissionCoastGuard") <> 0 then
    AddMarker(0, "World" & gGame.world, [#position: "SpecialMissionStealth_Marker", #type: #SpecialMission, #priority: #medium])
  end if
end

on CheckDesertSpecialMissions me
  if gGame.UPSpecialMissionsCompleted.getPos("SpecialMissionConvoy") <> 0 then
    AddMarker(0, "World" & gGame.world, [#position: "SpecialMissionDogfight_Marker", #type: #SpecialMission, #priority: #medium])
  end if
  if gGame.UPSpecialMissionsCompleted.getPos("SpecialMissionDogfight") <> 0 then
    AddMarker(0, "World" & gGame.world, [#position: "SpecialMissionAC130_Marker", #type: #SpecialMission, #priority: #medium])
  end if
end

on DisableCurrentMarker me
  PutMessage(0, "--> DisableCurrentMarker( Handler)")
  if gGame.WorldStartDummy[symbol(gGame.world)] = ("TicketMaster" & gGame.world & "_Marker") then
    return 0
  end if
  if gGame.MiniMap.markerlist.getaProp(gGame.WorldStartDummy[symbol(gGame.world)]) = VOID then
    return 0
  else
    gGame.MiniMap.markerlist[gGame.WorldStartDummy[symbol(gGame.world)]].model.parent = VOID
    gGame.MiniMap.markerlist[gGame.WorldStartDummy[symbol(gGame.world)]].Active = 0
  end if
end

on CheckCityToDesertDoor me
  PutMessage(0, "--> --> CheckCityToDesertDoor (Handler)")
  if gGame.UPSpecialMissionsCompleted.getPos("SpecialMissionBridge") <> 0 then
    tResult = RemoveObject(0, "06_03", "Door")
    if tResult = 1 then
      PutMessage(0, "--> --> --> Succesfully removed the door to the DESERT")
    else
      PutMessage(0, "--> --> --> Failed to remove the door to the DESERT")
    end if
  else
    PutMessage(0, "--> --> --> Door to DESERT not removed. Special mission not completed")
  end if
end

on CheckCityToSnowDoor me
  PutMessage(0, "--> --> CheckCityToSnowDoor (Handler)")
  if gGame.UPSpecialMissionsCompleted.getPos("SpecialMissionTunnel") <> 0 then
    tResult = RemoveObject(0, "05_10", "Door")
    if tResult = 1 then
      PutMessage(0, "--> --> --> Succesfully removed the door to the SNOW")
    else
      PutMessage(0, "--> --> --> Failed to remove the door to the SNOW")
    end if
  else
    PutMessage(0, "--> --> --> Door to SNOW not removed. Special mission not completed")
  end if
end

on CheckCityToJungleDoor me
  PutMessage(0, "--> --> CheckCityToJungleDoor (Handler)")
  if gGame.UPSpecialMissionsCompleted.getPos("SpecialMissionDock") <> 0 then
    tResult = RemoveObject(0, "07_07", "Door")
    if tResult = 1 then
      PutMessage(0, "--> --> --> Succesfully removed the door to the JUNGLE")
    else
      PutMessage(0, "--> --> --> Failed to remove the door to the JUNGLE")
    end if
  else
    PutMessage(0, "--> --> --> Door to JUNGLE not removed. Special mission not completed")
  end if
end

on RemoveObject me, tTile, tString
  tmember = member("World" & gGame.world)
  tPhysics = gGame.Physics
  tgroup = tmember.group(tTile)
  if tgroup = VOID then
    return 0
  end if
  tObjectGroup = tgroup.userData.objectGroup
  tObjects = tObjectGroup.userData.objects
  tRigidBodies = tObjectGroup.userData.rigidBodies
  repeat with i in tObjects
    if i.name contains tString then
      i.parent = VOID
      tRB = tPhysics.getRigidBody(i.name)
      if tRB <> VOID then
        tPhysics.deleteRigidBody(i.name)
        if tRigidBodies.getPos(tRB) <> 0 then
          tObjects.deleteOne(tRB)
        end if
      end if
      return 1
    end if
  end repeat
  return 0
end

on FinishCurrentVehicle me
  t = gGame.vehicles[gGame.CurrentVehicle]
  tController = t.general.controller
  if tController = #player then
    reset_keyInput(0, t)
    reset_Weapons(0, t)
    reset_items(0, t)
    setup_HoldToPin(0, t)
    if t.general.States.getPos(#update_sound) <> 0 then
      reset_sound(0, t)
    end if
    if t.general.States.getPos(#update_sound2) <> 0 then
      reset_sound2(0, t)
    end if
    if t.general.States.getPos(#update_soundPlane) <> 0 then
      reset_soundPlane(0, t)
    end if
    if t.general.States.getPos(#update_soundBoat) <> 0 then
      reset_SoundBoat(0, t)
    end if
    if t.general.States.getPos(#update_flying) <> 0 then
      reset_Flying(0, t)
    end if
    if t.general.States.getPos(#update_flyingSpitfire) <> 0 then
      reset_flyingSpitfire(0, t)
    end if
    if t.general.States.getPos(#update_FlyingAC130) <> 0 then
      reset_FlyingAC130(0, t)
    end if
  end if
  if tController = #AI then
    reset_AutoRace(0, t)
    reset_Weapons(0, t)
    setup_HoldToPin(0, t)
    if t.general.States.getPos(#update_sound) <> 0 then
      reset_sound(0, t)
    end if
    if t.general.States.getPos(#update_sound2) <> 0 then
      reset_sound2(0, t)
    end if
    if t.general.States.getPos(#update_soundPlane) <> 0 then
      reset_soundPlane(0, t)
    end if
    if t.general.States.getPos(#update_soundBoat) <> 0 then
      reset_SoundBoat(0, t)
    end if
    if t.general.States.getPos(#update_flying) <> 0 then
      reset_Flying(0, t)
    end if
    if t.general.States.getPos(#update_flyingSpitfire) <> 0 then
      reset_flyingSpitfire(0, t)
    end if
    if t.general.States.getPos(#update_FlyingAC130) <> 0 then
      reset_FlyingAC130(0, t)
    end if
  end if
end

on FinishAllCars me
  PutMessage(0, "--> --> FINISHALLCARS (Handler)")
  repeat with t in gGame.vehicles
    if (t.race.state = #dead) or (t.race.state = #Finished) then
      next repeat
    end if
    tController = t.general.controller
    if tController = #player then
      t.race.state = #Finished
      if voidp(gGame[#timer]) = 0 then
        t.race.time = gGame.timer
      end if
      reset_keyInput(0, t)
      reset_Weapons(0, t)
      reset_items(0, t)
      setup_HoldToPin(0, t)
      if t.general.States.getPos(#update_sound) <> 0 then
        reset_sound(0, t)
      end if
      if t.general.States.getPos(#update_sound2) <> 0 then
        reset_sound2(0, t)
      end if
      if t.general.States.getPos(#update_soundPlane) <> 0 then
        reset_soundPlane(0, t)
      end if
      if t.general.States.getPos(#update_soundBoat) <> 0 then
        reset_SoundBoat(0, t)
      end if
      if t.general.States.getPos(#update_flying) <> 0 then
        reset_Flying(0, t)
      end if
      if t.general.States.getPos(#update_flyingSpitfire) <> 0 then
        reset_flyingSpitfire(0, t)
      end if
      if t.general.States.getPos(#update_FlyingAC130) <> 0 then
        reset_FlyingAC130(0, t)
      end if
    end if
    if tController = #AI then
      t.race.state = #Finished
      if voidp(gGame[#timer]) = 0 then
        t.race.time = gGame.timer
      end if
      reset_AutoRace(0, t)
      reset_Weapons(0, t)
      setup_HoldToPin(0, t)
      if t.general.States.getPos(#update_sound) <> 0 then
        reset_sound(0, t)
      end if
      if t.general.States.getPos(#update_sound2) <> 0 then
        reset_sound2(0, t)
      end if
      if t.general.States.getPos(#update_soundPlane) <> 0 then
        reset_soundPlane(0, t)
      end if
      if t.general.States.getPos(#update_soundBoat) <> 0 then
        reset_SoundBoat(0, t)
      end if
      if t.general.States.getPos(#update_flying) <> 0 then
        reset_Flying(0, t)
      end if
      if t.general.States.getPos(#update_flyingSpitfire) <> 0 then
        reset_flyingSpitfire(0, t)
      end if
      if t.general.States.getPos(#update_FlyingAC130) <> 0 then
        reset_FlyingAC130(0, t)
      end if
    end if
  end repeat
end

on RestoreMissionItem me
  PutMessage(0, "--> RestoreMissionItem (Handler)")
  gGame[#StoredMissionItem][1].parent = gGame[#StoredMissionItem][2]
  gGame[#StoredMissionItem][2].userData.Pickups.add(gGame[#StoredMissionItem][1])
  gGame[#StoredMissionItem] = []
end

on SetupRampage me
  PutMessage(0, "--> SetupRampage (Handler)")
  gGame[#WorldMission] = 1
  tmember = member("World" & gGame.world)
  tTag = gGame.CollectedItem
  if gGame.Vehicle <> "Helicopter" then
    StoreAndHideCurrentMiniMap()
  end if
  gGame[#Rampage] = [:]
  gGame.Rampage[#track] = tTag
  gGame.Rampage[#trackInfo] = gData.Info.trackInfo[symbol(tTag)].duplicate()
  gGame.Rampage[#markers] = [:]
  gGame.Rampage[#models] = [:]
  gGame.Rampage[#score] = [0, gGame.Rampage.trackInfo.Enemies[1]]
  gGame.Rampage[#result] = #none
  tList = []
  if gGame.Rampage.trackInfo.Enemies[2] = "TaxiTraffic" then
    repeat with i in gGame.traffic.cars
      repeat with j in i
        tmodel = tmember.model(j)
        tUserData = tmodel.userData
        if tUserData.data.type = #TaxiTraffic then
          if tUserData.Health <= 0 then
            next repeat
          end if
          tOnDeath = tUserData.onDeath
          tOnDeath = gData.data.ObjectsEffects[tOnDeath].duplicate()
          tOnDeath[#handler] = "DestroyObjectRampage"
          tUserData.onDeath = tOnDeath
          tList.add(tmodel)
          if gGame.fx.Destruction.getPos(tmodel.name) = 0 then
            gGame.fx.Destruction.add(tmodel.name)
          end if
        end if
      end repeat
    end repeat
    gGame.Rampage.models = tList.duplicate()
    repeat with i in tList
      AddMiniMapMarker(0, "MiniMap", [#type: #Rampage, #position: i.worldPosition, #priority: #high, #name: i.name & "_Rampage", #update: 1, #sourceModel: i])
    end repeat
  else
    tObject = symbol(gGame.Rampage.trackInfo.Enemies[2] & "_Object")
    tObjectName = gGame.Rampage.trackInfo.Enemies[2]
    repeat with i = 1 to tmember.model.count
      tmodel = tmember.model[i]
      if tmodel.name contains tObjectName then
        if (tmodel.name contains "Weapon") or (tmodel.name contains "Pickup") then
          next repeat
        end if
        tList.add(tmodel)
        tmodel.transform = tmodel.userData.LocalTransform.duplicate()
        tmodel.userData.Health = gData.data.objects[tObject].Health
        tmodel.shader = tmember.shader("World" & gGame.world & "Misc_Material")
        tmodel.resource = tmember.modelResource(tmodel.userData.resource)
        if voidp(gData.data.objects[tObject][#script]) = 0 then
          if gData.data.objects[tObject][#script] <> #none then
            if tmodel.userData.script = #none then
              tScript = AddScript(0, EMPTY, [#script: gData.data.objects[tObject][#script], #data: [#member: tmember.name, #model: tmodel.name]])
              tmodel.userData.script = tScript
            end if
          end if
        end if
        tOnDeath = tmodel.userData.onDeath
        tOnDeath = gData.data.ObjectsEffects[tOnDeath].duplicate()
        tOnDeath[#handler] = "DestroyObjectRampage"
        tmodel.userData.onDeath = tOnDeath
        tRB = gGame.Physics.getRigidBody(tmodel.name)
        tRB.position = tmodel.worldPosition
        tRB.orientation = tmodel.transform.axisAngle
        if gGame.fx.Destruction.getPos(tmodel.name) = 0 then
          gGame.fx.Destruction.add(tmodel.name)
        end if
      end if
    end repeat
    gGame.Rampage.models = tList.duplicate()
    repeat with i in tList
      tLoc = i.userData.transform.position
      AddMiniMapMarker(0, "MiniMap", [#type: #Rampage, #position: tLoc, #priority: #high, #name: i.name & "_Rampage"])
    end repeat
  end if
  AddToInterfaceList(0, "InterfaceTimer")
  SetupInterfaceTimer()
  SETVISIBLE(0, "Interface", [#model: "InterfaceTimer", #state: 1])
  AddToInterfaceList(0, "InterfaceTargets")
  SetupInterfaceTargets()
  SETVISIBLE(0, "Interface", [#model: "InterfaceTargets", #state: 1])
  UpdateTargets(0, 0, gGame.Rampage.trackInfo.Enemies[1])
  PlaySound(0, "TrialStart_SFX", [#Override: 1])
end

on DestroyObjectRampage me, tTarget, tDataList
  if voidp(gGame[#Rampage]) = 1 then
    return 0
  end if
  PutMessage(0, "--> --> DestroyObjectRampage (Handler)")
  tObject = tDataList.model
  gGame.Rampage.score[1] = gGame.Rampage.score[1] + 1
  UpdateTargets(0, gGame.Rampage.score[1], gGame.Rampage.score[2])
  RemoveMiniMapMarker(0, "MiniMap", [#name: symbol("Minimap" & tObject & "_Rampage")])
  if gGame.Rampage.score[1] >= gGame.Rampage.score[2] then
    event(0, #ResetRampage)
  end if
end

on ResetRampage me
  PutMessage(0, "--> ResetRampage (Handler)")
  if gGame.Vehicle <> "Helicopter" then
    RestoreAndShowCurrentMiniMap()
  end if
  if (gGame.timer = 0) and (gGame.Rampage.score[1] < gGame.Rampage.score[2]) then
    gGame.Rampage.result = #Defeat
  else
    gGame.Rampage.result = #Victory
  end if
  if gGame.Rampage.result = #Victory then
    gGame.money = gGame.money + gGame.Rampage.trackInfo.PrizeMoney
    UpdateMoney()
    SaveData()
    CreateTextTexture(0, "Interface", [#tag: #InterfaceStatusHeaderText, #style: #StatusTitle, #text: symbol(gGame.Rampage.track & "Title"), #forceSize: [512, 64]])
    CreateTextTexture(0, "Interface", [#tag: #InterfaceStatusBodyText, #style: #StatusBody, #text: symbol(gGame.Rampage.track & "Succes"), #forceSize: [512, 128]])
    SETVISIBLE(0, "Interface", [#model: "InterfaceStatus", #state: 1, #parent: "World"])
    DelayEvent(0, EMPTY, [#delay: gGame.StatusDelay, #name: "HideStatus", #event: "HideStatus"])
    AddToList(0, gGame.UpRampagesCompleted, [#value: gGame.Rampage.trackInfo.TrackName, #Override: 1])
    CheckUnlimitedSprayShop()
    SaveData()
    PlaySound(0, "Status_SFX", [#Override: 1])
    PlaySound(0, "TrialSucces_SFX", [#Override: 1])
  else
    CreateTextTexture(0, "Interface", [#tag: #InterfaceStatusHeaderText, #style: #StatusTitle, #text: symbol(gGame.Rampage.track & "Title"), #forceSize: [512, 64]])
    CreateTextTexture(0, "Interface", [#tag: #InterfaceStatusBodyText, #style: #StatusBody, #text: symbol(gGame.Rampage.track & "Defeat"), #forceSize: [512, 128]])
    SETVISIBLE(0, "Interface", [#model: "InterfaceStatus", #state: 1, #parent: "World"])
    DelayEvent(0, EMPTY, [#delay: gGame.StatusDelay, #name: "HideStatus", #event: "HideStatus"])
    PlaySound(0, "Status_SFX", [#Override: 1])
    PlaySound(0, "TrialFailure_SFX", [#Override: 1])
  end if
  RemoveFromInterfaceList(0, "InterfaceTimer")
  ResetInterfaceTimer()
  SETVISIBLE(0, "Interface", [#model: "InterfaceTimer", #state: 0])
  RemoveFromInterfaceList(0, "InterfaceTargets")
  SETVISIBLE(0, "Interface", [#model: "InterfaceTargets", #state: 0])
  the itemDelimiter = "_"
  repeat with i in gGame.Rampage.models
    if i = VOID then
      next repeat
    end if
    RemoveMiniMapMarker(0, "MiniMap", [#name: symbol("Minimap" & i.name & "_Rampage")])
    tUserData = i.userData
    tName = tUserData.resource
    if tName contains "Taxi" then
      tUserData.onDeath = #DefaultTraffic
      next repeat
    end if
    tUserData.onDeath = symbol(tName.item[1])
  end repeat
  DelayEvent(0, EMPTY, [#delay: 1500, #name: "RestoreMissionItem", #event: "RestoreMissionItem"])
  gGame.deleteProp(#Rampage)
  gGame.deleteProp(#WorldMission)
end

on SetupTimeTrial me
  PutMessage(0, "--> SetupTimeTrial (Handler)")
  gGame[#WorldMission] = 1
  tTag = gGame.CollectedItem
  if gGame.Vehicle <> "Helicopter" then
    StoreAndHideCurrentMiniMap()
  end if
  gGame[#TimeTrial] = [:]
  gGame.TimeTrial[#track] = tTag
  gGame.TimeTrial[#trackInfo] = gData.Info.trackInfo[symbol(tTag)].duplicate()
  gGame.TimeTrial[#markers] = [:]
  gGame.TimeTrial[#CurrentMarker] = #none
  gGame.TimeTrial[#result] = #none
  repeat with i = 1 to gGame.MarkerTransformList.count
    tProp = gGame.MarkerTransformList.getPropAt(i)
    if string(tProp) contains tTag then
      gGame.TimeTrial.markers[tProp] = gGame.MarkerTransformList[i]
    end if
  end repeat
  gGame.TimeTrial.markers.sort()
  if gGame.TimeTrial.markers.count >= 10 then
    tList = [:]
    repeat with i = 1 to gGame.TimeTrial.markers.count
      tSymbol = symbol(gGame.TimeTrial.track & i & "_Marker")
      tList[tSymbol] = gGame.TimeTrial.markers[tSymbol].duplicate()
    end repeat
    gGame.TimeTrial.markers = tList.duplicate()
  end if
  NextMarkerTimeTrial()
  AddToInterfaceList(0, "InterfaceTimer")
  SetupInterfaceTimer()
  SETVISIBLE(0, "Interface", [#model: "InterfaceTimer", #state: 1])
  PlaySound(0, "TrialStart_SFX", [#Override: 1])
end

on NextMarkerTimeTrial me
  PutMessage(0, "--> NextMarkerTimeTrial (Handler)")
  if voidp(gSystem[#BillBoardList]) = 0 then
    gSystem.BillBoardList = [:]
  end if
  if gGame.TimeTrial.CurrentMarker <> #none then
    RemoveMarker(0, "World" & gGame.world, [#name: string(gGame.TimeTrial.CurrentMarker)])
    gGame.TimeTrial.CurrentMarker = #none
    if gGame.TimeTrial.markers.count = 0 then
      event(0, #ResetTimeTrial)
      return 1
    end if
  end if
  gGame.TimeTrial.CurrentMarker = gGame.TimeTrial.markers.getPropAt(1)
  gGame.TimeTrial.markers.deleteProp(gGame.TimeTrial.CurrentMarker)
  AddMarker(0, "World" & gGame.world, [#position: string(gGame.TimeTrial.CurrentMarker), #type: #TimeTrial])
  PlaySound(0, "TimeTrialMarker_SFX", [#Override: 1])
end

on ResetTimeTrial me
  PutMessage(0, "--> ResetTimeTrial (Handler)")
  if gGame.Vehicle <> "Helicopter" then
    RestoreAndShowCurrentMiniMap()
  end if
  if gGame.TimeTrial.CurrentMarker <> #none then
    RemoveMarker(0, "World" & gGame.world, [#name: string(gGame.TimeTrial.CurrentMarker)])
  end if
  if gGame.timer = 0 then
    gGame.TimeTrial.result = #Defeat
  else
    gGame.TimeTrial.result = #Victory
  end if
  if gGame.TimeTrial.result = #Victory then
    gGame.money = gGame.money + gGame.TimeTrial.trackInfo.PrizeMoney
    UpdateMoney()
    SaveData()
    CreateTextTexture(0, "Interface", [#tag: #InterfaceStatusHeaderText, #style: #StatusTitle, #text: symbol(gGame.TimeTrial.track & "Title"), #forceSize: [512, 64]])
    CreateTextTexture(0, "Interface", [#tag: #InterfaceStatusBodyText, #style: #StatusBody, #text: symbol(gGame.TimeTrial.track & "Succes"), #forceSize: [512, 128]])
    SETVISIBLE(0, "Interface", [#model: "InterfaceStatus", #state: 1, #parent: "World"])
    DelayEvent(0, EMPTY, [#delay: gGame.StatusDelay, #name: "HideStatus", #event: "HideStatus"])
    AddToList(0, gGame.UpTimeTrialsCompleted, [#value: gGame.TimeTrial.trackInfo.TrackName, #Override: 1])
    CheckUnlimitedTuneShop()
    SaveData()
    PlaySound(0, "Status_SFX", [#Override: 1])
    PlaySound(0, "TrialSucces_SFX", [#Override: 1])
  else
    CreateTextTexture(0, "Interface", [#tag: #InterfaceStatusHeaderText, #style: #StatusTitle, #text: symbol(gGame.TimeTrial.track & "Title"), #forceSize: [512, 64]])
    CreateTextTexture(0, "Interface", [#tag: #InterfaceStatusBodyText, #style: #StatusBody, #text: symbol(gGame.TimeTrial.track & "Defeat"), #forceSize: [512, 128]])
    SETVISIBLE(0, "Interface", [#model: "InterfaceStatus", #state: 1, #parent: "World"])
    DelayEvent(0, EMPTY, [#delay: gGame.StatusDelay, #name: "HideStatus", #event: "HideStatus"])
    PlaySound(0, "Status_SFX", [#Override: 1])
    PlaySound(0, "TrialFailure_SFX", [#Override: 1])
  end if
  RemoveFromInterfaceList(0, "InterfaceTimer")
  ResetInterfaceTimer()
  SETVISIBLE(0, "Interface", [#model: "InterfaceTimer", #state: 0])
  DelayEvent(0, EMPTY, [#delay: 1500, #name: "RestoreMissionItem", #event: "RestoreMissionItem"])
  gGame.deleteProp(#TimeTrial)
  gGame.deleteProp(#WorldMission)
end

on SetupDemolition me
  PutMessage(0, "--> SetupDemolition (Handler)")
  gGame[#WorldMission] = 1
  tTag = gGame.CollectedItem
  if gGame.Vehicle <> "Helicopter" then
    StoreAndHideCurrentMiniMap()
  end if
  gGame[#Demolition] = [:]
  gGame.Demolition[#track] = tTag
  gGame.Demolition[#trackInfo] = gData.Info.trackInfo[symbol(tTag)].duplicate()
  gGame.Demolition[#markers] = [:]
  gGame.Demolition[#Cameras] = []
  gGame.Demolition[#models] = []
  gGame.Demolition[#result] = #none
  gGame.Demolition[#sourceTile] = gGame.vehicles[1].Vehicle.currentTile.duplicate()
  the itemDelimiter = "_"
  repeat with i = 1 to gGame.MarkerTransformList.count
    tProp = gGame.MarkerTransformList.getPropAt(i)
    if string(tProp) contains tTag then
      gGame.Demolition.markers[tProp] = gGame.MarkerTransformList[i]
      gGame.Demolition.Cameras.add(string(tProp).item[1])
    end if
  end repeat
  gGame.Demolition.markers.sort()
  repeat with i = 1 to gGame.Demolition.markers.count
    tProp = gGame.Demolition.markers.getPropAt(i)
    AddMarker(0, "World" & gGame.world, [#position: string(tProp), #type: #Demolition])
  end repeat
  AddToInterfaceList(0, "InterfaceTimer")
  SetupInterfaceTimer()
  SETVISIBLE(0, "Interface", [#model: "InterfaceTimer", #state: 1])
  AddToInterfaceList(0, "InterfaceTargets")
  SetupInterfaceTargets()
  SETVISIBLE(0, "Interface", [#model: "InterfaceTargets", #state: 1])
  UpdateTargets(0, 0, 4)
  PlaySound(0, "TrialStart_SFX", [#Override: 1])
end

on NextMarkerDemolition me
  PutMessage(0, "--> --> NextMarkerDemolition (Handler)")
  tmember = member("World" & gGame.world)
  tMarker = gGame.CurrentMarker
  if tmember.modelResource("C4") = VOID then
    CloneModel(0, tmember.name, [#sourceMember: "Weapons", #model: "C4", #hide: 1, #lod: 0, #delete: 1])
  end if
  tmodel = tmember.newModel(tMarker & "_C4", tmember.modelResource("C4"))
  tmodel.shader = tmember.shader("Weapons_Material")
  tmodel.transform = gGame.Demolition.markers[symbol(gGame.CurrentMarker & "_Marker")].transform.duplicate()
  gGame.Demolition.models.add(tmodel)
  RemoveMarker(0, "World" & gGame.world, [#name: string(gGame.CurrentMarker & "_Marker")])
  gGame.Demolition.markers.deleteProp(symbol(gGame.CurrentMarker & "_Marker"))
  UpdateTargets(0, 4 - gGame.Demolition.markers.count, 4)
  PlaySound(0, "DemolitionMarker_SFX", [#Override: 1])
  if gGame.Demolition.markers.count = 0 then
    gGame.timer = 10000
  end if
end

on ResetDemolition me
  PutMessage(0, "--> ResetDemolition (Handler)")
  if gGame.Vehicle <> "Helicopter" then
    RestoreAndShowCurrentMiniMap()
  end if
  repeat with i = 1 to gGame.Demolition.markers.count
    tProp = gGame.Demolition.markers.getPropAt(i)
    RemoveMarker(0, "World" & gGame.world, [#name: string(tProp)])
  end repeat
  if (gGame.timer = 0) and (gGame.Demolition.markers.count > 0) then
    gGame.Demolition.result = #Defeat
  else
    gGame.Demolition.result = #Victory
  end if
  if gGame.Demolition.result = #Victory then
    gGame.Input = 0
    event(0, #HideSomeInterface)
    gGame.camera[1].state = #Mimic
    event(0, #UnbindWorldKeys)
    gGame.Demolition[#sourceTile] = gGame.vehicles[1].Vehicle.currentTile.duplicate()
    NExtExplosionDemolition()
    AddToList(0, gGame.UpDemolitionsCompleted, [#value: gGame.Demolition.trackInfo.TrackName, #Override: 1])
    CheckUnlimitedWeaponShop()
    SaveData()
  else
    CreateTextTexture(0, "Interface", [#tag: #InterfaceStatusHeaderText, #style: #StatusTitle, #text: symbol(gGame.Demolition.track & "Title"), #forceSize: [512, 64]])
    CreateTextTexture(0, "Interface", [#tag: #InterfaceStatusBodyText, #style: #StatusBody, #text: symbol(gGame.Demolition.track & "Defeat"), #forceSize: [512, 128]])
    SETVISIBLE(0, "Interface", [#model: "InterfaceStatus", #state: 1, #parent: "World"])
    DelayEvent(0, EMPTY, [#delay: gGame.StatusDelay, #name: "HideStatus", #event: "HideStatus"])
    ResetDemolitionModels()
    gGame.deleteProp(#Demolition)
    gGame.deleteProp(#WorldMission)
    PlaySound(0, "Status_SFX", [#Override: 1])
    PlaySound(0, "TrialFailure_SFX", [#Override: 1])
  end if
  RemoveFromInterfaceList(0, "InterfaceTimer")
  ResetInterfaceTimer()
  SETVISIBLE(0, "Interface", [#model: "InterfaceTimer", #state: 0])
  RemoveFromInterfaceList(0, "InterfaceTargets")
  SETVISIBLE(0, "Interface", [#model: "InterfaceTargets", #state: 0])
  DelayEvent(0, EMPTY, [#delay: 1500, #name: "RestoreMissionItem", #event: "RestoreMissionItem"])
end

on ResetDemolitionModels me
  PutMessage(0, "--> ResetDemolitionModels (Handler)")
  tmember = member("World" & gGame.world)
  repeat with i in gGame.Demolition.models
    tmember.deleteModel(i.name)
  end repeat
end

on NExtExplosionDemolition me
  PutMessage(0, "--> NextExplosionDemolition (Handler)")
  if _movie.timeoutList.getPos(timeout("NextExplosionDemolition")) <> 0 then
    timeout("NextExplosionDemolition").forget()
  end if
  if gGame.Demolition.Cameras.count = 0 then
    gGame.Input = 1
    event(0, #ShowSomeInterface)
    gGame.camera[1].state = #follow
    gGame.camera[1].target = gGame.vehicles[1].general.tag
    event(0, #BindWorldKeys)
    gGame.vehicles[1].Vehicle.tileOverride = 0
    gGame.vehicles[1].Vehicle.currentTile = gGame.Demolition.sourceTile
    if gGame.Vehicle = "Boat" then
      gGame.vehicles[1].general.script.reset(gGame.vehicles[1], 0, 0, 0, VOID, gGame.Demolition.sourceTile)
      _movie.updateStage()
      (the stage).bgColor = (the stage).bgColor
    end if
    gGame.money = gGame.money + gGame.Demolition.trackInfo.PrizeMoney
    UpdateMoney()
    SaveData()
    CreateTextTexture(0, "Interface", [#tag: #InterfaceStatusHeaderText, #style: #StatusTitle, #text: symbol(gGame.Demolition.track & "Title"), #forceSize: [512, 64]])
    CreateTextTexture(0, "Interface", [#tag: #InterfaceStatusBodyText, #style: #StatusBody, #text: symbol(gGame.Demolition.track & "Succes"), #forceSize: [512, 128]])
    SETVISIBLE(0, "Interface", [#model: "InterfaceStatus", #state: 1, #parent: "World"])
    DelayEvent(0, EMPTY, [#delay: gGame.StatusDelay, #name: "HideStatus", #event: "HideStatus"])
    gGame.deleteProp(#Demolition)
    gGame.deleteProp(#WorldMission)
    PlaySound(0, "Status_SFX", [#Override: 1])
    PlaySound(0, "TrialSucces_SFX", [#Override: 1])
    return 1
  else
    timeout().new("NextExplosionDemolition", 5500, #NExtExplosionDemolition)
  end if
  tmember = member("World" & gGame.world)
  the itemDelimiter = "_"
  tmodel = tmember.model(gGame.Demolition.Cameras[1].item[1] & "_C4")
  gGame.camera[1].target = gGame.Demolition.Cameras[1] & "_Camera"
  tTile = GetTile(0, symbol(gGame.Demolition.Cameras[1] & "_Marker"))
  gGame.vehicles[1].Vehicle.tileOverride = 1
  gGame.vehicles[1].Vehicle.currentTile = tTile
  gGame.Demolition.Cameras.deleteAt(1)
  timeout().new("SpawnDemolitionExplosion", 1000, #SpawnDemolitionExplosion, [tmodel])
end

on SpawnDemolitionExplosion tList, tTimeOut
  tExploScript = new(script("[PS] ExplosionLarge"), [#member: "World" & gGame.world, #position: tList[1].worldPosition, #camera: "Player1_Camera", #duration: 2500])
  if tExploScript <> VOID then
    gGame.scriptList.add(tExploScript)
  end if
  areaDamage(0, "World" & gGame.world, [#position: tList[1].worldPosition, #areaDamage: [#damage: 500.0, #minDistance: 1.0, #maxDistance: 100.0], #sender: tList[1].name])
  member("World" & gGame.world).deleteModel(tList[1].name)
  tTimeOut.forget()
end

on ShowCurrentData me
  PutMessage(0, "--> PutCurrentData (Handler)")
  PutMessage(0, gGame.trackInfo)
  PutMessage(0, gGame.Assets)
end

on SetRadioStream me, tTarget, tDataList
  PutMessage(0, "--> SetRadioStream (Handler)")
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  if gSystem.local = 1 then
    tFileName = _movie.path & "Music\" & tDataList.radio & "\" & tDataList.track & ".mp3"
  else
    tFileName = _movie.path & "Music/" & tDataList.radio & "/" & tDataList.track & ".mp3"
  end if
  gGame[#StreamingMP3] = tDataList.track
  if gSound.streamingMusic = 1 then
    tmember = member("Player")
    tmember.streamName = tFileName
  else
    tmember = member("Mp3Player")
    tmember.fileName = tFileName
  end if
  PutMessage(0, "--> --> TrackLocation: " & tFileName)
end

on PlayRadioStream me, tTarget, tDataList
  PutMessage(0, "--> PlayRadioStream (Handler)")
  tmember = member("Player")
  case gGame.StreamingMP3 of
    "Adrenaline_Music":
      tDuration = 24084
    "AllThatMatters_Music":
      tDuration = 102948
    "AlphaBeta2008_Music":
      tDuration = 100101
    "BackFire_Music":
      tDuration = 86073
    "DustAndScratches_Music":
      tDuration = 51304
    "Formula_Music":
      tDuration = 59167
    "GrayScales_Music":
      tDuration = 54961
    "Grip_Music":
      tDuration = 64104
    "HighOctane_Music":
      tDuration = 103470
    "LittleByLittle_Music":
      tDuration = 57417
    "MoreOrLess_Music":
      tDuration = 90435
    "Rotation_Music":
      tDuration = 60081
    "Trailblazer_Music":
      tDuration = 32626
    "Velocity_Music":
      tDuration = 64104
  end case
  timeout().new("LoopRadioStream", 333, #LoopRadioStream)
  tmember.play()
  if gGame.sound = 0 then
    tmember.volume = 0
    sound(1).volume = 0
  else
    tmember.volume = 255
    sound(1).volume = 255
  end if
end

on StopRadioStream me, tTarget, tDataList
  PutMessage(0, "--> StopRadioStream (Handler)")
  repeat with i = gGame.timeoutList.count down to 1
    tName = gGame.timeoutList[i].name
    if tName = "LoopRadioStream" then
      gGame.timeoutList.deleteAt(i)
    end if
  end repeat
  tPos = gGame.timeoutList.getPos(timeout("LoopRadioStream"))
  if tPos <> 0 then
    gGame.deleteAt(tPos)
  end if
  tmember = member("Player")
  tmember.stop()
end

on PauseRadioStream me
  PutMessage(0, "--> PauseRadioStream (Handler)")
  tmember = member("Player")
  tmember.pause()
end

on ContinueRadioStream me
  PutMessage(0, "--> ContinueRadioStream (Handler)")
  tmember = member("Player")
  tmember.play()
end

on DeleteAndForceStartRadioStream me
  PutMessage(0, "--> DeleteAndForceStartRadioStream (Handler)")
  repeat with i = gGame.timeoutList.count down to 1
    tName = gGame.timeoutList[i].name
    if tName = "LoopRadioStream" then
      gGame.timeoutList.deleteAt(i)
    end if
  end repeat
  tPos = _movie.timeoutList.getPos(timeout("LoopRadioStream"))
  if tPos = 0 then
    timeout().new("LoopRadioStream", 333, #LoopRadioStream)
  end if
end

on FadeRadioStream me, tTarget, tDataList
  PutMessage(0, "--> FadeRadioStream (Handler)")
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    return 0
  end if
  tType = #in
  if tDataList[#type].ilk = #symbol then
    tType = tDataList.type
  end if
  tTime = 750
  if tDataList[#time].ilk = #integer then
    tTime = tDataList.time
  end if
  if tType = #in then
    sound(1).fadeIn(tTime)
  end if
  if tType = #out then
    sound(1).fadeOut(tTime)
  end if
end

on SetVolumeRadioStream me, tTarget, tDataList
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    return 0
  end if
  tVolume = 255
  if tDataList[#volume].ilk = #integer then
    tVolume = tDataList.volume
  end if
  tmember = member("Player")
  if gGame.sound = 0 then
    tmember.volume = 0
    sound(1).volume = 0
  else
    tmember.volume = 255
    sound(1).volume = 255
  end if
end

on LoopRadioStream me
  tmember = member("Player")
  if tmember.state = 5 then
    PutMessage(0, "--> LoopRadioStream (Handler)")
    timeout("LoopRadioStream").forget()
    StopRadioStream()
    PlayRadioStream()
    if voidp(gGame[#RaceState]) = 1 then
      if gGame.RaceState = #Finished then
        SetVolumeRadioStream(0, EMPTY, [#volume: 50])
      end if
    end if
  end if
end

on UpdateStats me
  CheckAndUpdateStatistics()
  tText = EMPTY
  tmember = member("StatsText")
  repeat with i = 1 to 13
    tString = convertToUpperCase(0, gData.data.text[symbol("Stats" & i)])
    tText = tText & tString & RETURN
  end repeat
  tmember.text = tText
  tmember.fixedLineSpace = 22
  tText = EMPTY
  tmember = member("StatsResults")
  repeat with i = 1 to gGame.UPStatistics.count
    tProp = gGame.UPStatistics.getPropAt(i)
    if gGame.UPStatistics[i].ilk = #list then
      tString = gGame.UPStatistics[i][1] & "/" & gGame.UPStatistics[i][2]
    else
      if tProp = #totalTime then
        tString = formatStatsTime(0, gGame.UPStatistics[i])
      else
        if tProp = #money then
          tString = "$" & gGame.UPStatistics[i]
        else
          tString = gGame.UPStatistics[i]
        end if
      end if
    end if
    tText = tText & tString & RETURN
  end repeat
  tmember.text = tText
  tmember.alignment = #right
  tmember.fixedLineSpace = 22
  tImage = image(512, 512, 32, 1)
  tAlpha = tImage.extractAlpha()
  tAlpha.fill(tAlpha.rect, rgb(255, 255, 255))
  tImage.setAlpha(tAlpha)
  tImage.copyPixels(member("StatsText").image, rect(25, 0, 370, 512), rect(0, 0, 384, 512))
  tImage.copyPixels(member("StatsResults").image, rect(310, 0, 507, 512), rect(335, 0, 532, 512))
  member("StatsTemplate").image = tImage
  tTempImage = member("StatsTemplate").image
  tFilter = filter(#DropShadowFilter, [#distance: 2, #angle: 235, #color: rgb(0, 0, 0), #blurX: 1, #blurY: 1, #strengthPercent: 65])
  tTempImage.applyFilter(tFilter, tTempImage.rect)
  tFilter = filter(#GlowFilter, [#blurX: 5, #blurY: 5, #quality: 2, #color: color(64, 64, 64), #strengthPercent: 25])
  tTempImage.applyFilter(tFilter, tTempImage.rect)
  tImage.copyPixels(tTempImage, tImage.rect, tTempImage.rect)
  member("Menu").texture("Statistics_Texture").image = tImage
  member("Menu").texture("Statistics_Texture").renderFormat = #rgba4444
end

on formatStatsTime me, tMillisec
  sec = integer(tMillisec / 1000)
  min = integer(sec / 60)
  sec = sec - (min * 60)
  Hour = integer(min / 60)
  min = min - (Hour * 60)
  tMillisec = integer((tMillisec - (sec * 1000) - (min * 60 * 1000) - (Hour * 60 * 60 * 1000)) / 10.0)
  hourString = string(Hour) & "h"
  if min < 10 then
    minString = "0" & string(min + 100).char[3..3] & "m"
  else
    minString = string(min + 100).char[2..3] & "m"
  end if
  secString = string(sec + 100).char[2..3] & "s"
  return hourString & minString & secString
end

on UpdateAchievements me
  tImage = image(512, 512, 32, 1)
  tAlpha = tImage.extractAlpha()
  tAlpha.fill(tAlpha.rect, rgb(255, 255, 255))
  tImage.setAlpha(tAlpha)
  repeat with i = 1 to gGame.UPTrophies.count
    tProp = gGame.UPTrophies.getPropAt(i)
    tSubImage = image(512, 32, 32, 1)
    tAlpha = tSubImage.extractAlpha()
    tAlpha.fill(tAlpha.rect, rgb(255, 255, 255))
    tSubImage.setAlpha(tAlpha)
    if gGame.UPTrophies[i] = 1 then
      tColor = rgb(255, 255, 255)
      tTrophy = member("TrophyCompleted_Texture")
    else
      tColor = rgb(164, 164, 164)
      tTrophy = member("TrophyOpen_Texture")
    end if
    member("TrophyHeader").color = tColor
    member("TrophyText").color = tColor
    member("TrophyHeader").text = convertToUpperCase(0, gData.data.text[symbol("TrophyHeader" & i)])
    member("TrophyText").text = gData.data.text[symbol("TrophySub" & i)]
    tSubImage.copyPixels(member("TrophyHeader").image, rect(5, 0, 389, 16), member("TrophyHeader").rect)
    tSubImage.copyPixels(member("TrophyText").image, rect(5, 16, 389, 26), member("TrophyText").rect)
    tSubImage.copyPixels(tTrophy.image, rect(455, -6, 487, 26), tTrophy.rect)
    tRect = rect(0, -28 + (i * 32), 512, 4 + (i * 32))
    tImage.copyPixels(tSubImage, tRect, tSubImage.rect)
  end repeat
  member("TrophiesTemplate").image = tImage
  tTempImage = member("TrophiesTemplate").image
  tFilter = filter(#DropShadowFilter, [#distance: 2, #angle: 235, #color: rgb(0, 0, 0), #blurX: 1, #blurY: 1, #strengthPercent: 65])
  tTempImage.applyFilter(tFilter, tTempImage.rect)
  tFilter = filter(#GlowFilter, [#blurX: 5, #blurY: 5, #quality: 2, #color: color(64, 64, 64), #strengthPercent: 25])
  tTempImage.applyFilter(tFilter, tTempImage.rect)
  tImage.copyPixels(tTempImage, tImage.rect, tTempImage.rect)
  member("Menu").texture("Trophies_Texture").image = tImage
  member("Menu").texture("Trophies_Texture").renderFormat = #rgba4444
end

on UpdateShopCamera me
  tCamera = member("World" & gGame.world).camera(gGame.CurrentMarker & "_Camera")
  tCamera.fieldOfView = 40.0
  if gGame.car = "BigTruck" then
    tCamera.fieldOfView = 85.0
  end if
  if gGame.car = "MonsterTruck" then
    tCamera.fieldOfView = 65.0
  end if
  if gGame.car = "AutoBot" then
    tCamera.fieldOfView = 65.0
  end if
  if gGame.car = "Tank" then
    tCamera.fieldOfView = 80.0
  end if
end

on CheckAndUpdateTrophies me
  PutMessage(0, "--> CheckAndUpdateTrophies (Handler)")
  if gGame.UpChallengesCompleted.count >= 36 then
    gGame.UPTrophies.WheelsOnFire = 1
  end if
  if gGame.UPSpecialMissionsCompleted.count >= 11 then
    gGame.UPTrophies.SecretAgent = 1
  end if
  if gGame.UPCars.count >= 15 then
    gGame.UPTrophies.KingOfTheGarage = 1
  end if
  if gGame.UPHiddenPackages.count >= 36 then
    gGame.UPTrophies.TheTreasureHunter = 1
  end if
  if gGame.money >= 1000000000 then
    gGame.UPTrophies.BillionDollarMan = 1
  end if
  SaveData()
end

on CheckAndUpdateStatistics me
  gGame.UPStatistics.money = gGame.money
  gGame.UPStatistics.totalTime = gGame.UPStatistics.totalTime + (_system.milliSeconds - gGame.startTime)
  gGame[#startTime] = _system.milliSeconds
  gGame.UPStatistics.ticketsCompleted[1] = gGame.UpChallengesCompleted.count
  gGame.UPStatistics.specialMissionsCompleted[1] = gGame.UPSpecialMissionsCompleted.count
  gGame.UPStatistics.carsUnlocked[1] = gGame.UPCars.count
  gGame.UPStatistics.hiddenPackagesFound[1] = gGame.UPHiddenPackages.count
  gGame.UPStatistics.timeTrialsCompleted[1] = gGame.UpTimeTrialsCompleted.count
  gGame.UPStatistics.rampagesCompleted[1] = gGame.UpRampagesCompleted.count
  gGame.UPStatistics.demolitionsCompleted[1] = gGame.UpDemolitionsCompleted.count
  gGame.UPStatistics.nuclearDetonators[1] = gGame.UPNuclearDetonators.count
  gGame.UPStatistics.Landmarks[1] = gGame.UPLandMarks.count
end

on UpdateStatisticsTotalTime me
  gGame.UPStatistics.totalTime = gGame.UPStatistics.totalTime + (_system.milliSeconds - gGame.startTime)
end

on SetStartTime me
  gGame[#startTime] = _system.milliSeconds
end

on CheckAllLandMarks me
  PutMessage(0, "--> CheckAllLandMarks (TELEPORT CHEAT) (Handler)")
  if gGame.UPLandMarks.count >= 4 then
    if gGame.UPUnlockableCheats.getPos(#Teleport) = 0 then
      PutMessage(0, "--> --> Teleport unlocked")
      gGame.UPUnlockableCheats.add(#Teleport)
      SetTeleportKeys()
      SaveData()
    end if
  end if
end

on CheckNuclearDetonators me
  PutMessage(0, "--> CheckNuclearDetonators (UNLIMITED HEALTH CHEAT) (Handler)")
  if gGame.UPNuclearDetonators.count >= 12 then
    if gGame.UPUnlockableCheats.getPos(#UnlimitedHealth) = 0 then
      PutMessage(0, "--> --> UnlimitedHealth unlocked")
      gGame.UPUnlockableCheats.add(#UnlimitedHealth)
      SaveData()
      t = gGame.vehicles[1]
      t.Vehicle.Health = 500000
      t.general.data.personality.Health = 500000
      t.general.data.personality.origHealth = 500000
    end if
  end if
end

on CheckForPrimaryCheat me
  PutMessage(0, "--> CheckForPrimaryCheat (Handler)")
  if gGame.UpChallengesCompleted.count >= 36 then
    if gGame.UPUnlockableCheats.getPos(#UnlimitedPrimary) = 0 then
      PutMessage(0, "--> --> UnlimitedPrimary ammo unlocked")
      gGame.UPUnlockableCheats.add(#UnlimitedPrimary)
      SaveData()
    end if
  end if
end

on CheckForSecondaryCheat me
  PutMessage(0, "--> CheckForSecondaryCheat (Handler)")
  if gGame.UPSpecialMissionsCompleted.count >= 13 then
    if gGame.UPUnlockableCheats.getPos(#UnlimitedSecondary) = 0 then
      PutMessage(0, "--> --> UnlimitedSecondary ammo unlocked")
      gGame.UPUnlockableCheats.add(#UnlimitedSecondary)
      SaveData()
    end if
  end if
end

on CheckUnlimitedWeaponShop me
  PutMessage(0, "--> CheckUnlimitedWeaponShop (Handler)")
  if gGame.UpDemolitionsCompleted.count >= 4 then
    if gGame.UPUnlockableCheats.getPos(#UnlimitedWeaponShop) = 0 then
      PutMessage(0, "--> --> UnlimitedWeaponShop unlocked. No charge for weapons!")
      gGame.UPUnlockableCheats.add(#UnlimitedWeaponShop)
      SaveData()
    end if
  end if
end

on CheckUnlimitedTuneShop me
  PutMessage(0, "--> CheckUnlimitedTuneShop (Handler)")
  if gGame.UpTimeTrialsCompleted.count >= 5 then
    if gGame.UPUnlockableCheats.getPos(#UnlimitedTuneShop) = 0 then
      PutMessage(0, "--> --> UnlimitedTuneShop unlocked. No charge for tuning!")
      gGame.UPUnlockableCheats.add(#UnlimitedTuneShop)
      SaveData()
    end if
  end if
end

on CheckUnlimitedSprayShop me
  PutMessage(0, "--> CheckUnlimitedSprayShop (Handler)")
  if gGame.UpRampagesCompleted.count >= 4 then
    if gGame.UPUnlockableCheats.getPos(#UnlimitedSprayShop) = 0 then
      PutMessage(0, "--> --> UnlimitedSprayShop unlocked. No charge for new paintjobs!")
      gGame.UPUnlockableCheats.add(#UnlimitedSprayShop)
      SaveData()
    end if
  end if
end

on CheckSoundState me
  if gSound.mute = 1 then
    gGame.sound = 0
  else
    gGame.sound = 1
  end if
end

on SetTeleportKeys me
  PutMessage(0, "--> SetTeleportKeys (Handler)")
  if gGame.UPUnlockableCheats.getPos(#Teleport) <> 0 then
    PutMessage(0, "--> Adding teleport keys!")
    BindKey(0, EMPTY, [#key: "1", #event: "TeleportToCity", #once: 1])
    BindKey(0, EMPTY, [#key: "2", #event: "TeleportToDesert", #once: 1])
    BindKey(0, EMPTY, [#key: "3", #event: "TeleportToSnow", #once: 1])
    BindKey(0, EMPTY, [#key: "4", #event: "TeleportToJungle", #once: 1])
    BindKey(0, EMPTY, [#key: "5", #event: "TeleportToIndustrial", #once: 1])
  end if
end

on RestoreCarData me
  PutMessage(0, "--> RestoreCarData (Handler)")
  gData.data.car.PlayerCar = [#car: gGame.car, #skin: 1, #upgrades: gGame.car, #Weapons: gGame.car, #personality: gGame.car, #settings: gGame.car]
  gData.data.car.PlayerBoat = [#car: gGame.Boat, #skin: 1, #upgrades: gGame.Boat, #Weapons: gGame.Boat, #personality: gGame.Boat, #settings: gGame.Boat]
  gData.data.car.PlayerPlane = [#car: gGame.plane, #skin: 1, #upgrades: gGame.plane, #Weapons: gGame.plane, #personality: gGame.plane, #settings: gGame.plane]
  gData.data.car.PlayerHelicopter = [#car: gGame.Helicopter, #skin: 1, #upgrades: gGame.Helicopter, #Weapons: gGame.Helicopter, #personality: gGame.Helicopter, #settings: gGame.Helicopter]
  gData.data.car.Tank = [#car: "Tank", #skin: 1, #upgrades: "Tank", #Weapons: "Tank", #personality: "Tank", #settings: "Tank"]
  gData.data.car.Taxi = [#car: "Taxi", #skin: 1, #upgrades: "Taxi", #Weapons: "Taxi", #personality: "Taxi", #settings: "Taxi"]
  gData.data.car.Rebel = [#car: "Rebel", #skin: 1, #upgrades: "Rebel", #Weapons: "Rebel", #personality: "Rebel", #settings: "Rebel"]
  gData.data.car.Bullet350 = [#car: "Bullet350", #skin: 4, #upgrades: "Bullet350", #Weapons: "Bullet350", #personality: "Bullet350", #settings: "Bullet350"]
  gData.data.car.ViceV80 = [#car: "ViceV80", #skin: 1, #upgrades: "ViceV80", #Weapons: "ViceV80", #personality: "ViceV80", #settings: "ViceV80"]
  gData.data.car.Fennek = [#car: "Fennek", #skin: 1, #upgrades: "Fennek", #Weapons: "Fennek", #personality: "Fennek", #settings: "Fennek"]
  gData.data.car.Hound = [#car: "Hound", #skin: 1, #upgrades: "Hound", #Weapons: "Hound", #personality: "Hound", #settings: "Hound"]
  gData.data.car.PetiteXs = [#car: "PetiteXs", #skin: 1, #upgrades: "PetiteXs", #Weapons: "PetiteXs", #personality: "PetiteXs", #settings: "PetiteXs"]
  gData.data.car.PhaserGti = [#car: "PhaserGti", #skin: 1, #upgrades: "PhaserGti", #Weapons: "PhaserGti", #personality: "PhaserGti", #settings: "PhaserGti"]
  gData.data.car.Police = [#car: "Police", #skin: 1, #upgrades: "Police", #Weapons: "Police", #personality: "Police", #settings: "Police"]
  gData.data.car.Rally7 = [#car: "Rally7", #skin: 1, #upgrades: "Rally7", #Weapons: "Rally7", #personality: "Rally7", #settings: "Rally7"]
  gData.data.car.BigTruck = [#car: "BigTruck", #skin: 1, #upgrades: "BigTruck", #Weapons: "BigTruck", #personality: "BigTruck", #settings: "BigTruck"]
  gData.data.car.Sunstorm = [#car: "Sunstorm", #skin: 1, #upgrades: "Sunstorm", #Weapons: "Sunstorm", #personality: "Sunstorm", #settings: "Sunstorm"]
  gData.data.car.Autobot = [#car: "Autobot", #skin: 1, #upgrades: "Autobot", #Weapons: "Autobot", #personality: "Autobot", #settings: "Autobot"]
  gData.data.car.MonsterTruck = [#car: "MonsterTruck", #skin: 1, #upgrades: "MonsterTruck", #Weapons: "MonsterTruck", #personality: "MonsterTruck", #settings: "MonsterTruck"]
  gData.data.car.Speedboat = [#car: "Speedboat", #skin: 1, #upgrades: "Speedboat", #Weapons: "Speedboat", #personality: "Speedboat", #settings: "Speedboat"]
  gData.data.car.PoliceBoat = [#car: "Policeboat", #skin: 1, #upgrades: "Policeboat", #Weapons: "Policeboat", #personality: "Policeboat", #settings: "Policeboat"]
  gData.data.car.Zodiac = [#car: "Zodiac", #skin: 1, #upgrades: "Zodiac", #Weapons: "Zodiac", #personality: "Zodiac", #settings: "Zodiac"]
  gData.data.car.Stealth = [#car: "Stealth", #skin: 1, #upgrades: "Stealth", #Weapons: "Stealth", #personality: "Stealth", #settings: "Stealth"]
  gData.data.car.Apache = [#car: "Apache", #skin: 1, #upgrades: "Apache", #Weapons: "Apache", #personality: "Apache", #settings: "Apache"]
  gData.data.car.AC130 = [#car: "AC130", #skin: 1, #upgrades: "AC130", #Weapons: "AC130", #personality: "AC130", #settings: "AC130"]
  gData.data.car.Spitfire = [#car: "Spitfire", #skin: 1, #upgrades: "Spitfire", #Weapons: "Spitfire", #personality: "Spitfire", #settings: "Spitfire"]
  gData.data.car.F22 = [#car: "F22", #skin: 1, #upgrades: "F22", #Weapons: "F22", #personality: "F22", #settings: "F22"]
  gData.data.CarUpgrades.Tank = [#engine: [5, 5], #armor: [8, 8], #handling: [4, 4], #primary: [10, 10], #secondary: [10, 10]]
  gData.data.CarUpgrades.Taxi = [#engine: [1, 4], #armor: [2, 5], #handling: [2, 3], #primary: [2, 3], #secondary: [3, 3]]
  gData.data.CarUpgrades.Rebel = [#engine: [3, 5], #armor: [2, 4], #handling: [3, 6], #primary: [3, 5], #secondary: [2, 4]]
  gData.data.CarUpgrades.Bullet350 = [#engine: [2, 4], #armor: [1, 3], #handling: [1, 4], #primary: [2, 4], #secondary: [2, 3]]
  gData.data.CarUpgrades.ViceV80 = [#engine: [4, 7], #armor: [3, 5], #handling: [3, 6], #primary: [4, 6], #secondary: [3, 5]]
  gData.data.CarUpgrades.Fennek = [#engine: [4, 6], #armor: [5, 9], #handling: [3, 6], #primary: [4, 9], #secondary: [4, 8]]
  gData.data.CarUpgrades.Hound = [#engine: [3, 5], #armor: [4, 7], #handling: [3, 5], #primary: [3, 5], #secondary: [3, 5]]
  gData.data.CarUpgrades.PetiteXs = [#engine: [5, 9], #armor: [3, 5], #handling: [5, 8], #primary: [4, 7], #secondary: [3, 6]]
  gData.data.CarUpgrades.PhaserGti = [#engine: [1, 4], #armor: [2, 4], #handling: [2, 3], #primary: [2, 4], #secondary: [1, 3]]
  gData.data.CarUpgrades.Police = [#engine: [2, 5], #armor: [2, 5], #handling: [3, 4], #primary: [3, 4], #secondary: [2, 4]]
  gData.data.CarUpgrades.Rally7 = [#engine: [4, 7], #armor: [3, 5], #handling: [4, 7], #primary: [4, 6], #secondary: [3, 5]]
  gData.data.CarUpgrades.BigTruck = [#engine: [3, 6], #armor: [5, 8], #handling: [3, 5], #primary: [4, 7], #secondary: [3, 6]]
  gData.data.CarUpgrades.Sunstorm = [#engine: [3, 6], #armor: [3, 5], #handling: [2, 5], #primary: [3, 4], #secondary: [2, 5]]
  gData.data.CarUpgrades.Autobot = [#engine: [8, 8], #armor: [10, 10], #handling: [6, 6], #primary: [10, 10], #secondary: [10, 10]]
  gData.data.CarUpgrades.MonsterTruck = [#engine: [6, 8], #armor: [6, 9], #handling: [3, 6], #primary: [6, 10], #secondary: [5, 8]]
  gData.data.CarUpgrades.Speedboat = [#engine: [3, 10], #armor: [2, 10], #handling: [0, 0], #primary: [8, 8], #secondary: [8, 8]]
  gData.data.CarUpgrades.PoliceBoat = [#engine: [0, 0], #armor: [0, 0], #handling: [0, 0], #primary: [5, 5], #secondary: [5, 5]]
  gData.data.CarUpgrades.Zodiac = [#engine: [0, 0], #armor: [0, 0], #handling: [0, 0], #primary: [5, 5], #secondary: [5, 5]]
  gData.data.CarUpgrades.Stealth = [#engine: [0, 0], #armor: [0, 0], #handling: [0, 0], #primary: [5, 5], #secondary: [5, 5]]
  gData.data.CarUpgrades.Apache = [#engine: [0, 0], #armor: [0, 0], #handling: [0, 0], #primary: [5, 10], #secondary: [5, 10]]
  gData.data.CarUpgrades.AC130 = [#engine: [0, 0], #armor: [0, 0], #handling: [0, 0], #primary: [5, 10], #secondary: [5, 10]]
  gData.data.CarUpgrades.Spitfire = [#engine: [0, 0], #armor: [0, 0], #handling: [0, 0], #primary: [5, 10], #secondary: [5, 10]]
  gData.data.CarUpgrades.F22 = [#engine: [0, 0], #armor: [0, 0], #handling: [0, 0], #primary: [6, 10], #secondary: [6, 10]]
  gData.data.CarWeapons.Tank = [#primary: "MiniGun", #secondary: "MainGun"]
  gData.data.CarWeapons.Taxi = [#primary: "MachineGun", #secondary: "GrenadeLauncher"]
  gData.data.CarWeapons.Rebel = [#primary: "DualMachineGun", #secondary: "RocketPod"]
  gData.data.CarWeapons.Bullet350 = [#primary: "MachineGun", #secondary: "RocketPod"]
  gData.data.CarWeapons.ViceV80 = [#primary: "DualMachineGun", #secondary: "RocketPod"]
  gData.data.CarWeapons.Fennek = [#primary: "DualMiniGun", #secondary: "GrenadeLauncher"]
  gData.data.CarWeapons.Hound = [#primary: "MiniGun", #secondary: "RocketPod"]
  gData.data.CarWeapons.PetiteXs = [#primary: "FlameThrower", #secondary: "GrenadeDeployer"]
  gData.data.CarWeapons.PhaserGti = [#primary: "DualMachineGun", #secondary: "GrenadeLauncher"]
  gData.data.CarWeapons.Police = [#primary: "MachineGun", #secondary: "RocketPod"]
  gData.data.CarWeapons.Rally7 = [#primary: "DualMachineGun", #secondary: "RocketPod"]
  gData.data.CarWeapons.BigTruck = [#primary: "FlameThrower", #secondary: "MineDeployer"]
  gData.data.CarWeapons.Sunstorm = [#primary: "DualMachineGun", #secondary: "MineDeployer"]
  gData.data.CarWeapons.Autobot = [#primary: "Laser", #secondary: "MainGun"]
  gData.data.CarWeapons.MonsterTruck = [#primary: "DualMachineGun", #secondary: "RocketPod"]
  gData.data.CarWeapons.Speedboat = [#primary: "DualMachineGun", #secondary: "RocketPod"]
  gData.data.CarWeapons.PoliceBoat = [#primary: "DualMachineGun", #secondary: "RocketPod"]
  gData.data.CarWeapons.Zodiac = [#primary: "DualMachineGun", #secondary: "RocketPod"]
  gData.data.CarWeapons.Stealth = [#primary: "DualMachineGun", #secondary: "RocketPod"]
  gData.data.CarWeapons.Apache = [#primary: "DualMachineGun", #secondary: "RocketPod"]
  gData.data.CarWeapons.AC130 = [#primary: "DualMachineGun", #secondary: "RocketPod"]
  gData.data.CarWeapons.Spitfire = [#primary: "DualMachineGun", #secondary: "RocketPod"]
  gData.data.CarWeapons.F22 = [#primary: "DualMachineGun", #secondary: "RocketPod"]
end

on SetVehicleStatesToFalse me
  repeat with i = 1 to gData.data.VehiclesLoadingData.count
    gData.data.VehiclesLoadingData[i] = gData.data.VehiclesLoadingDataSource[i].duplicate()
  end repeat
end

on RemoveDoors me
  PutMessage(0, "--> --> RemoveDoors (Handler)")
  tmember = member("World" & gGame.world)
  tPhysics = gGame.Physics
  repeat with i = 1 to tmember.model.count
    tmodel = tmember.model[i]
    if tmodel.name contains "Door" then
      tmodel.parent = VOID
      tUD = tmodel.userData
      tParent = tUD.parent
      tParentUD = tParent.userData
      if tParentUD.objects.getPos(tmodel) <> 0 then
        tParentUD.objects.deleteOne(tmodel)
      end if
      tRB = tPhysics.getRigidBody(tmodel.name)
      if tRB <> VOID then
        if tParentUD.rigidBodies.getPos(tRB) <> 0 then
          tParentUD.rigidBodies.deleteOne(tRB)
        end if
        tPhysics.deleteRigidBody(tmodel.name)
      end if
    end if
  end repeat
end

on CheckLandMarkCity me
  PutMessage(0, "CheckLandMarkCity (Handler)")
  if gGame.UPLandMarks.getPos("LandMarkCity_Object") <> 0 then
    SetModel(0, "World" & gGame.world, [#model: "02_07_landmarkcity_1_object", #resource: "landmarkcitydestroyed_object", #shader: "WorldCityMisc_Material"])
    gGame.fx.Destruction.deleteOne("02_07_landmarkcity_1_Object")
  end if
end

on CheckLandMarkSnow me
  PutMessage(0, "CheckLandMarkSnow (Handler)")
  if gGame.UPLandMarks.getPos("LandMarkSnow_Object") <> 0 then
    SetModel(0, "World" & gGame.world, [#model: "04_12_landmarksnow_1_object", #resource: "landmarksnowdestroyed_object", #shader: "WorldSnowMisc_Material"])
    gGame.fx.Destruction.deleteOne("04_12_landmarksnow_1_Object")
  end if
end

on CheckLandMarkJungle me
  PutMessage(0, "CheckLandMarkJungle (Handler)")
  if gGame.UPLandMarks.getPos("LandMarkJungle_Object") <> 0 then
    SetModel(0, "World" & gGame.world, [#model: "06_08_landmarkjungle_1_object", #resource: "landmarkjungledestroyed_object", #shader: "WorldJungleMisc_Material"])
    gGame.fx.Destruction.deleteOne("06_08_landmarkjungle_1_Object")
  end if
end

on CheckLandMarkDesert me
  PutMessage(0, "CheckLandMarkDesert (Handler)")
  if gGame.UPLandMarks.getPos("LandMarkDesert_Object") <> 0 then
    SetModel(0, "World" & gGame.world, [#model: "07_03_landmarkdesert_1_object", #resource: "landmarkdesertdestroyed_object", #shader: "WorldDesertMisc_Material"])
    gGame.fx.Destruction.deleteOne("07_03_landmarkdesert_1_Object")
  end if
end

on CheckLandMarkIndustrial me
  PutMessage(0, "CheckLandMarkIndustrial (Handler)")
  if gGame.UPLandMarks.getPos("LandMarkIndustrial_Object") <> 0 then
    SetModel(0, "World" & gGame.world, [#model: "06_08_landmarkIndustrial_1_object", #resource: "landmarkindustrialdestroyed_object", #shader: "WorldIndustrialMisc_Material"])
    gGame.fx.Destruction.deleteOne("06_08_landmarkindustrial_1_Object")
  end if
end

on UpdateTagsLoadingAssets me
  PutMessage(0, "UpdateTagsLoadingAssets (Handler)")
  tScript = GetScript(0, EMPTY, [#script: "[PS] Preload Cast"])
  if tScript <> 0 then
    tScript.p.script.UpdateVisualState(#LOADING)
    tScript.p.script.UpdateVisualDetail(#Assets)
    tScript.p.script.UpdateVisualPercentage(#Percentage)
  end if
end

on UpdateTagsLoadingWorld me
  PutMessage(0, "UpdateTagsLoadingWorld (Handler)")
  tScript = GetScript(0, EMPTY, [#script: "[PS] Preload Cast"])
  if tScript <> 0 then
    tScript.p.script.UpdateVisualState(#LOADING)
    tScript.p.script.UpdateVisualDetail(#world)
    tScript.p.script.UpdateVisualPercentage(#Percentage)
  end if
end

on UpdateTagsLoadingTrack me
  PutMessage(0, "UpdateTagsLoadingTrack (Handler)")
  tScript = GetScript(0, EMPTY, [#script: "[PS] Preload Cast"])
  if tScript <> 0 then
    tScript.p.script.UpdateVisualState(#LOADING)
    tScript.p.script.UpdateVisualDetail(#track)
    tScript.p.script.UpdateVisualPercentage(#Percentage)
  end if
end

on UpdateTagsInitializingGame me
  PutMessage(0, "UpdateTagsInitializingGame (Handler)")
  if gSystem.UpdateScript <> #none then
    gSystem.UpdateScript.UpdateVisualState(#initializing)
    gSystem.UpdateScript.UpdateVisualDetail(#game)
    gSystem.UpdateScript.UpdateVisualPercentage(#Percentage)
  end if
end

on WorldTrafficLightsOff me
  PutMessage(0, "WorldTrafficLightsOff (Handler)")
  if voidp(gGame[#traffic]) = 1 then
    return 0
  end if
  repeat with i in gGame.traffic.cars
    repeat with j in i
      tmodel = gGame.member.model(j)
      if tmodel = VOID then
        next repeat
      end if
      tShader = tmodel.shader
      tShader.textureList[2] = VOID
      if gGame.WorldTrafficLights[symbol(gGame.world)] = 1 then
        tUserData = tmodel.userData
        if tUserData.state = #alive then
          repeat with k in tUserData.Lights
            k.parent = VOID
          end repeat
        end if
      end if
    end repeat
  end repeat
end

on WorldTrafficLightsOn me
  PutMessage(0, "WorldTrafficLightsOn (Handler)")
  if (voidp(gGame[#traffic]) = 1) or (gGame.setting = "Day") then
    WorldTrafficLightsOff()
    return 0
  end if
  repeat with i in gGame.traffic.cars
    repeat with j in i
      tmodel = gGame.member.model(j)
      if tmodel = VOID then
        next repeat
      end if
      tShader = tmodel.shader
      tShader.textureList[2] = gGame.member.texture("Reflection_Texture")
      if gGame.WorldTrafficLights[symbol(gGame.world)] = 1 then
        tUserData = tmodel.userData
        if tUserData.state = #alive then
          repeat with k in tUserData.Lights
            k.parent = tmodel
          end repeat
        end if
      end if
    end repeat
  end repeat
end

on CheckCheatsControl me
  if _key.controlDown = 1 then
    event(0, #ReallyEnableCheats)
  end if
end

on UnlockAllTickets me
  PutMessage(0, "--> --> UnlockAllTickets (Handler)")
  gGame.UPTickets = []
  repeat with i = 1 to 32
    tTicket = "Ticket" & i
    gGame.UPTickets.add(tTicket)
  end repeat
  gGame.UPBossTickets = []
  repeat with i = 1 to 4
    tTicket = "TicketBoss" & i
    gGame.UPBossTickets.add(tTicket)
  end repeat
  UpdateTickets()
end

on WinCurrentTickets me
  PutMessage(0, "--> --> WinCurrentTickets (Handler)")
  repeat with i in gGame.UPTickets
    tData = gData.Info.trackInfo
    repeat with j in tData
      if j.Ticket = i then
        if gGame.UpChallengesCompleted.getPos(j.TrackName) = 0 then
          gGame.UpChallengesCompleted.add(j.TrackName)
        end if
      end if
    end repeat
  end repeat
  repeat with i in gGame.UPBossTickets
    tData = gData.Info.trackInfo
    repeat with j in tData
      if j.Ticket = i then
        if gGame.UpChallengesCompleted.getPos(j.TrackName) = 0 then
          gGame.UpChallengesCompleted.add(j.TrackName)
        end if
      end if
    end repeat
  end repeat
  UpdateTickets()
  if gGame.Scene = "World" then
    CheckBossEndAvailability()
  end if
end

on WinCurrentHiddenPackages me
  PutMessage(0, "--> --> WinCurrentHiddenPackages (Handler)")
  repeat with i in gGame.UPTickets
    tData = gData.Info.trackInfo
    repeat with j in tData
      if j.Ticket = i then
        if gGame.UPHiddenPackages.getPos(j.TrackName) = 0 then
          gGame.UPHiddenPackages.add(j.TrackName)
        end if
      end if
    end repeat
  end repeat
  repeat with i in gGame.UPBossTickets
    tData = gData.Info.trackInfo
    repeat with j in tData
      if j.Ticket = i then
        if gGame.UPHiddenPackages.getPos(j.TrackName) = 0 then
          gGame.UPHiddenPackages.add(j.TrackName)
        end if
      end if
    end repeat
  end repeat
  UpdateTickets()
  CheckAllHiddenPackages()
end

on UnlockCars me
  PutMessage(0, "--> --> UnlockCars (Handler)")
  gGame.UPCars = ["Tank", "Taxi", "Rebel", "Bullet350", "ViceV80", "Fennek", "Hound", "PetiteXs", "PhaserGti", "Police", "Rally7", "BigTruck", "Sunstorm", "MonsterTruck", "Autobot"]
end

on UnlockCheats me
  PutMessage(0, "--> --> UnlockCheats (Handler)")
  gGame.UPUnlockableCheats = [#UnlimitedNitro, #UnlimitedHealth, #UnlimitedPrimary, #UnlimitedSecondary, #UnlimitedTuneShop, #UnlimitedWeaponShop, #UnlimitedSprayShop, #Teleport]
  SetTeleportKeys()
end

on WinSpecialMissions me
  PutMessage(0, "--> --> WinSpecialMissions (Handler)")
  gGame.UPSpecialMissionsCompleted = ["SpecialMissionBridge", "SpecialMissionTunnel", "SpecialMissionDock", "SpecialMissionSpeedBoat", "SpecialMissionCoastGuard", "SpecialMissionStealth", "SpecialMissionConvoy", "SpecialMissionDogfight", "SpecialMissionAC130", "SpecialMissionTaxi", "SpecialMissionPolice", "SpecialMissionTank"]
end

on ILikeMoney me
  PutMessage(0, "--> --> ILikeMoney (Handler)")
  gGame.money = gGame.money + 1000000
  UpdateMoney()
end

on DivideByZero me
  t = 1 / 0
end

on ShowPurge me
  repeat with i = 1 to _movie.castLib.count
    tCast = _movie.castLib(i)
    put tCast.member.count
    repeat with j = 1 to tCast.member.count
      tmember = member(j, i)
      if tmember.name.length > 0 then
        tName = tmember.name
        if tName.length < 100 then
          repeat with k = 1 to 100 - tName.length
            tName = tName & SPACE
          end repeat
        end if
        put tName && tmember.purgePriority
      end if
    end repeat
  end repeat
end

on SetPurge me
  repeat with i = 1 to _movie.castLib.count
    tCast = _movie.castLib(i)
    repeat with j = 1 to tCast.member.count
      tmember = member(j, i)
      if tmember.name <> EMPTY then
        tmember.purgePriority = 2
      end if
    end repeat
  end repeat
end

on checkCircularRef obj, l, indent
  cnt = count(obj)
  repeat with i = 1 to cnt
    p = obj.getPropAt(i)
    o = obj.getaProp(p)
    if ilk(o) = #instance then
      if string(o) starts "<offspring" then
        put indent & p && string(o)
        if l.getPos(o) then
          put indent & "= CIRCLE !!!!!!!!!!"
          next repeat
        end if
        tmp = l.duplicate()
        tmp.add(o)
        checkCircularRef(o, tmp, indent & SPACE)
      end if
    end if
  end repeat
end

on MyUnloadCast me, tCastNr
  put "UNLOADING CAST: " & tCastNr
  if tCastNr = VOID then
    tCastNr = "Internal"
  end if
  tCast = _movie.castLib(tCastNr)
  repeat with i = 1 to tCast.member.count
    tName = member(i, tCastNr).name
    if tName.length > 0 then
      member(i, tCastNr).unload()
      _movie.unloadMember(member(i, tCastNr))
    end if
  end repeat
end

on OpenShockwaveSite me
  gotoNetPage("http://www.shockwave.com/", "_new")
end

on NextShaderHack me
  tmember = member("WorldCity")
  tNewShader = DuplicateShader(0, tmember.name, [#shader: "WorldCityBuildings_Material", #shaderTag: "Reflection"])
  tNewShader.textureList[1] = tmember.texture("WorldBuildingsReflection_Texture")
  tNewShader.textureList[2] = tmember.texture("WorldBuildingsWhite_Texture")
  tNewShader.textureModeList[1] = #reflection
  tShader = tmember.shader("WorldCityBuildings_Material")
  tShader.textureList[3] = tShader.textureList[1]
  tShader.textureList[4] = tmember.texture("WorldBuildingsMask_Texture")
  tShader.textureList[1] = VOID
  tShader.textureList[2] = VOID
  tNewShader.shininess = 7.0
  tNewShader.specular = rgb(255, 255, 255)
  tNewShader.blend = 99.90000000000000568
  tNewShader.nextShader = tShader
  repeat with i = 1 to tmember.model.count
    tmodel = tmember.model[i]
    if (tmodel.name contains "buildings") and (tmodel.name contains "Back" = 0) then
      tNewModel = tmember.model(tmodel.name).clone(tmodel.name & "Back")
      tNewModel.shaderList = tmember.shader("DefaultShader")
      tNewModel.visibility = #back
      tmodel.shaderList = tNewShader
    end if
  end repeat
end

on normalMap me
  tmember = member("WorldJungle")
  gGame.camera[1].camera.fog.enabled = 0
  tNormalMap = gGame.member.newTexture("WorldStreetNormalMap_Texture", #fromCastMember, member("WorldStreetNormalMap_Texture"))
  tShader = tmember.newShader("WorldJungleStreetNormalMap_Material", #normalMap)
  tShader.textureList[1] = tNormalMap
  tShader.textureList[2] = tmember.texture("WorldStreet_Texture")
  tShader.textureList[3] = tmember.texture("WorldStreet_Texture")
  tShader.diffuse = rgb(255, 255, 255)
  repeat with i = 1 to tmember.model.count
    tmodel = tmember.model[i]
    if tmodel.name contains "Street" then
      tmodel.shaderList = tShader
    end if
  end repeat
end

on BreakPoint me
  nothing()
end

on createRandomList me
  tList = []
  repeat with i = 1 to 31
    tList.add(i)
  end repeat
  tNewList = []
  repeat while tList.count > 0
    tEntry = random(1, tList.count)
    tEntry = tList[tEntry]
    tNewList.add(tEntry)
    tList.deleteOne(tEntry)
  end repeat
  put tNewList
end

on ShowOverlay me
  tmember = gGame.member
  repeat with i = 1 to tmember.model.count
    tmodel = tmember.model(i)
    if tmodel.name contains "Overlay" then
      put tmodel && i
    end if
  end repeat
end

on TurnOff me
  member("World" & gGame.world).directToStage = 0
end
