-- [Script] [M] Main (Script #6105)
-- Script Type: Movie

global gSystem, gData, gSound, gGame, gStarter

on InitEngine me
  if voidp(gSystem) = 1 then
    InitGlobals()
  end if
  if not voidp(gStarter) then
    gGame[#setting] = gStarter.setting
    gGame[#MountedGuns] = gStarter.MountedGuns
    gGame[#ShowMore] = gStarter.ShowMore
    gGame[#Lightmaps] = 1
    gGame[#HighResCarTextures] = gStarter.Visuals[#HighResCarTextures]
    gGame[#Bloom] = gStarter.Visuals[#Bloom]
    gGame[#BloomPlus] = gStarter.Visuals[#BloomPlus]
    gGame[#MotionBlur] = gStarter.Visuals[#MotionBlur]
    gGame[#MotionBlurQuality] = gStarter.Visuals[#MotionBlurQuality]
    gGame[#Shadows] = gStarter.Visuals[#Shadows]
    gGame[#ShadowsDetail] = gStarter.Visuals[#ShadowsDetail]
    gGame[#AntiAliasing] = gStarter.Visuals[#AntiAliasing]
    gGame.resolution = gStarter.resolution
    gGame.stageSize = gGame.resolution
    SetStageSize()
  else
    gGame[#setting] = "Night"
    gGame[#MountedGuns] = 1
    gGame[#ShowMore] = 0
    gGame[#Lightmaps] = 1
    gGame[#HighResCarTextures] = 0
    gGame[#Bloom] = 0
    gGame[#BloomPlus] = 0
    gGame[#MotionBlur] = 0
    gGame[#MotionBlurQuality] = #low
    gGame[#Shadows] = 0
    gGame[#ShadowsDetail] = #low
    gGame[#AntiAliasing] = #none
  end if
  gGame[#SourceRatio] = gGame.resolution[1] / 800.0
  gGame[#ResRatio] = 800.0 / gGame.resolution[1]
  if gSystem.local = 1 then
    load(0, "\Data\LoadingArray.txt")
  else
    if gSystem.OnlineDataLoaded = 0 then
      OnlineLoad()
    end if
  end if
  if not voidp(gStarter) then
    if gStarter.Preloader = 0 then
      gGame.Scene = "World"
    end if
    gGame.setting = gStarter.setting
    gGame.MountedGuns = gStarter.MountedGuns
    gGame[#Bloom] = gStarter.Visuals[#Bloom]
    if gGame.BloomPlus = 1 then
      gGame.BloomSize = 0.125
    end if
    gGame[#Lightmaps] = 1
  end if
  if gGame.BloomPlus = 1 then
    gGame.BloomSize = 0.125
  end if
  if voidp(gSound) = 1 then
    SetupSoundManager()
  end if
  event(0, #GameInitialization)
end

on ResetEngine me
  if gGame.fullscreen = 1 then
    ResXoff()
  end if
  DeleteDynamicMembers()
  DeleteDynamicSprites()
  ClearSoundManager()
  _movie.actorList = []
  _movie.timeoutList = []
  gSystem.scriptList = []
  gGame.scriptList = []
  CloseWindows()
  _movie.castLib("Shared").fileName = _movie.path & "Assets.cst"
  _movie.castLib("Assets").fileName = _movie.path & "Shared.cst"
  _movie.castLib("World").fileName = _movie.path & "World.cst"
end

on InitGlobals me
  if voidp(gSystem) = 0 then
    if gSystem.Init = 1 then
      exit
    end if
    LogMessage(0, "Exited from InitGlobals. gSystem exists, but gSystem.Init = TRUE")
  end if
  gSystem = [:]
  gSystem[#debug] = 0
  gSystem[#local] = 0
  gSystem[#Init] = 0
  gSystem[#Focus] = 1
  gSystem[#path] = _movie.path
  gSystem[#FullPath] = gSystem.path & _movie.name
  gSystem[#frame] = 0
  gSystem[#OnlineDataLoaded] = 0
  gSystem[#DefaultCast] = "Internal"
  gSystem[#InternalCasts] = GetInternalCasts()
  gSystem[#ExternalCasts] = GetExternalCasts()
  gSystem[#MessageWindow] = 0
  gSystem[#itemDelimiter] = TAB
  gSystem[#DynamicMembers] = []
  gSystem[#DynamicSprites] = []
  gSystem[#handlerList] = []
  gSystem[#scriptList] = []
  gSystem[#event] = #none
  gSystem[#ReturnEvent] = #none
  gSystem[#parent] = _player.windowList[1].movie
  gSystem[#console] = [:]
  gSystem.console[#text] = []
  gSystem[#windows] = []
  gSystem[#ForceUpdate] = 0
  gSystem[#ForceState] = #LOADING
  gSystem[#UpdateScript] = #none
  gSystem[#FadeScript] = #none
  gSystem[#MenuScript] = #none
  gSystem[#ScriptManager] = script("[PS] Script Manager").new()
  gSystem[#text] = [:]
  gSystem.text[#engine] = #Director
  gSystem.text[#Init] = 0
  gSystem[#Mac] = 0
  if _system.environmentPropList.platform contains "Mac" then
    gSystem.Mac = 1
  end if
  gData = [:]
  gData[#Events] = [:]
  gData[#data] = [:]
  gData[#Triggers] = []
  gData[#Info] = [:]
  gData[#StoredEvents] = []
  gData[#StoredData] = []
  gData[#StoredTriggers] = []
  gGame = [:]
  gGame[#version] = 0.10000000000000001
  gGame[#name] = "UnknownGame"
  gGame[#PrefFile] = "XData.txt"
  gGame[#pause] = 0
  gGame[#PauseTime] = 0
  gGame[#Input] = 1
  gGame[#tempo] = 30.0
  gGame[#frameRate] = #limit
  gGame[#worldscale] = 1.0
  gGame[#TimeMP] = 1.0
  gGame[#fullscreen] = 0
  gGame[#stageSize] = [_movie.stage.drawRect[3], _movie.stage.drawRect[4]]
  gGame[#resolution] = [800, 450]
  gGame[#LockEscape] = 1
  gGame[#Iteration] = 0
  gGame[#timeoutList] = []
  gGame[#actorList] = []
  gGame[#timerList] = [:]
  gGame[#timerData] = [:]
  gGame[#timerData][#Lastupdate] = _system.milliSeconds
  gGame[#scriptList] = []
  gGame[#Bloom] = 1
  gGame[#BloomSize] = 0.0625
  gGame[#SWGame] = 0
  gGame[#SWTrophies] = [:]
  gGame[#SWGameTrophies] = [:]
  gGame[#SWHighscoreID] = "default_hs"
  gGame[#SWHighscoreTitle] = "Default Highscore"
  gGame[#SWScoreDescription] = "points"
  gGame[#SWReturnFromHub] = 0
  _movie.exitLock = gGame.LockEscape
  if _player.runMode = "Author" then
    gGame.fullscreen = 0
  end if
end
