-- [Script] [M] Shockwave Highscore (Script #6119)
-- Script Type: Movie

global gSystem, gGame, gSwScoreSetupList, gSwScoreNetID

on SWStoreHighscore me, tTarget, tDataList
  PutMessage(0, "--> SWStoreHighscore")
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    return 0
  end if
  if voidp(tDataList[#highscore]) = 1 then
    return 0
  end if
  tHighscore = tDataList.highscore
  if (gGame.SWScoreDescription = "milliseconds") and (tHighscore.ilk = #integer) then
    tHighscore = integer(tHighscore / 10)
  end if
  PutMessage(0, "--> --> Highscore is: " & tHighscore)
  member("SWHighscore").text = string(tHighscore)
end

on SWSubmitHighscore me
  PutMessage(0, "--> SWSubmitHighscore (Handler)")
  gSwScoreSetupList = [:]
  gSwScoreNetID = []
  tGameID = "default_hs"
  if voidp(gGame[#SWHighscoreID]) = 0 then
    if gGame.SWHighscoreID.ilk = #string then
      tGameID = gGame.SWHighscoreID
    end if
  end if
  gSwScoreSetupList[#gameid] = tGameID
  tTitle = "Default Highscore"
  if voidp(gGame[#SWHighscoreTitle]) = 0 then
    if gGame.SWHighscoreTitle.ilk = #string then
      tTitle = gGame.SWHighscoreTitle
    end if
  end if
  gSwScoreSetupList[#gametitle1] = tTitle
  tScoreDesc = "points"
  if voidp(gGame[#SWScoreDescription]) = 0 then
    if gGame.SWScoreDescription.ilk = #string then
      tScoreDesc = gGame.SWScoreDescription
    end if
  end if
  gSwScoreSetupList[#scoredesc] = tScoreDesc
  gSwScoreSetupList[#gametitle2] = EMPTY
  gSwScoreSetupList[#width] = _movie.stage.rect.width
  gSwScoreSetupList[#height] = _movie.stage.rect.height
  gSwScoreSetupList[#userName] = EMPTY
  gSwScoreSetupList[#userscore] = member("SWHighscore").text
  gSwScoreSetupList[#userscore] = member("SWHighscore").text
  gSwScoreSetupList[#movielocation] = _movie.path & _movie.name
  gSwScoreSetupList[#optional1] = []
  gSwScoreSetupList[#optional2] = []
  gSwScoreSetupList[#optional3] = []
  gSwScoreSetupList[#Function] = #SUBMIT
  gSwScoreSetupList[#status] = #start
  repeat with i = 1 to gGame.SWGameTrophies.count
    tProp = gGame.SWGameTrophies.getPropAt(i)
    if gGame.SWGameTrophies[i] > 0 then
      SWAddToList(me, tProp, gGame.SWGameTrophies[i])
    end if
  end repeat
  case (the environment).runMode of
    "Plugin":
      if (the environment).shockMachine = 1 then
        myURL = SWSetupGlobalBranch()
      else
        if the moviePath contains "http://" then
          myURL = SWSetupGlobalBranch()
        else
          myURL = EMPTY
        end if
      end if
      gSwScoreNetID = [gotoNetMovie(myURL), myURL]
    "Author":
      SWOpenLocalHub()
    "Projector":
      nothing()
  end case
  _movie.go("SWHighscore")
end

on SWAddToList me, whatProp, whatValue
  if voidp(getaProp(gSwScoreSetupList, whatProp)) then
    addProp(gSwScoreSetupList, whatProp, whatValue)
  else
    setaProp(gSwScoreSetupList, whatProp, whatValue)
  end if
end

on SWResetHighscore me
  PutMessage(0, "--> SWResetHighscore")
  member("SWHighscore").text = "0"
  gSwScoreSetupList = [:]
  gSwScoreNetID = []
end

on SWSetupGlobalBranch me
  if not voidp(externalParamValue("swURL")) then
    myURL = externalParamValue("swURL")
  else
    myGameURL = the moviePath
    the itemDelimiter = "/"
    mySite = item 3 of myGameURL
    if (myGameURL contains "http://") and (mySite contains "shockwave.com") then
      the itemDelimiter = "."
      myPrefix = item 1 of mySite
      myURL = "http://" & myPrefix & ".shockwave.com/content/highscores/scorez-2000.dcr"
    else
      myURL = "http://www.shockwave.com/content/highscores/scorez-2000.dcr"
    end if
  end if
  return myURL
end

on SWOpenLocalHub me
  if voidp(gGame[#SWLocalHub]) = 0 then
    SWCloseLocalHub()
  end if
  gGame[#SWLocalHub] = window().new("http://www.shockwave.com/content/highscores/scorez-2000.dcr")
  gGame.SWLocalHub.open()
  gSystem.windows.add(gGame.SWLocalHub)
end

on SWCloseLocalHub me
  if voidp(gGame[#SWLocalHub]) = 0 then
    gGame.SWLocalHub.forget()
    gGame.SWLocalHub.close()
    gGame.deleteProp(#SWLocalHub)
  end if
end

on SWReturnToGame me
  gotoNetMovie(gSystem.FullPath)
end
