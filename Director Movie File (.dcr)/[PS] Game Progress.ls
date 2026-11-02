-- [Script] [PS] Game Progress (Script #5851)
-- Script Type: Parent

property p
global gSystem, gGame

on new me, tDataList
  p = [:]
  p[#event] = tDataList.event
  p[#progress] = [tDataList.currentCommand, tDataList.totalCommands]
  p[#member] = member("Preloader")
  if p.member = VOID then
    return 0
  end if
  p[#model] = p.member.model("PreLoaderLoadingIcon")
  p[#model2] = p.member.model("PreLoaderLoadingIconShadow")
  p[#ScriptName] = "Game Progress"
  p[#StateTag] = #none
  p[#DetailTag] = #none
  p[#PercentageTag] = #none
  p[#tag] = #none
  if tDataList[#tag].ilk = #symbol then
    p.tag = tDataList.tag
  end if
  createTexture(0, p.member.name, [#texture: "PreLoaderImage_Texture", #nearFiltering: 0, #filtering: #lowFiltered, #renderFormat: #rgba8888])
  createTexture(0, p.member.name, [#texture: "PreLoaderLoading_Texture", #nearFiltering: 1, #filtering: #lowFiltered, #renderFormat: #rgba8888])
  if gSystem.local = 0 then
    CreateTextTexture(0, p.member.name, [#tag: #PreloaderPercentage, #style: #PreloaderPercentage, #text: "0 %"])
  end if
  CreateButton(0, "Preloader", [#model: "PreLoaderShockwaveButton", #event: EMPTY, #handler: "OpenShockwaveSite"])
  p.member.model("Splash").parent = VOID
  p[#icon] = p.member.model("PreLoaderLoadingIcon")
  p[#state] = p.member.model("PreloaderState")
  p[#detail] = p.member.model("PreloaderDetail")
  p[#Percentage] = p.member.model("PreloaderPercentage")
  me.UpdateVisualState(p.StateTag)
  me.UpdateVisualDetail(p.DetailTag)
  me.UpdateVisualPercentage(p.PercentageTag)
  p[#InitString] = "..."
  p[#camera] = p.member.camera("PreLoader_Camera")
  p.camera.projection = #orthographic
  p.camera.orthoHeight = 450
  p.camera.transform.position = vector(400, -225, 1000.0)
  tCamera = p.member.camera("DefaultView")
  tCamera.projection = #orthographic
  tCamera.orthoHeight = 450
  tCamera.transform.position = p.camera.transform.position
  p[#TargetRect] = rect(0, 0, gGame.stageSize[1], gGame.stageSize[2])
  p.camera.rect = p.TargetRect
  tCamera.rect = p.TargetRect
  me.Initialize()
  me.update([#command: tDataList.command, #currentCommand: tDataList.currentCommand])
  return me
end

on update me, tDataList
  p.progress[1] = tDataList.currentCommand
  tPerc = float(p.progress[1]) / float(p.progress[2])
  me.UpdateVisuals(tPerc)
  if gSystem.ForceState = #LOADING then
    if p.progress[1] = p.progress[2] then
      delete me
    end if
  end if
end

on Initialize me
  tChannel = _movie.lastChannel
  _movie.puppetSprite(tChannel, 1)
  p[#sprite] = sprite(tChannel)
  p.sprite.member = p.member
  p.sprite.width = gGame.stageSize[1]
  p.sprite.height = gGame.stageSize[2]
  p.sprite.loc = point(integer(gGame.stageSize[1] * 0.5), integer(gGame.stageSize[2] * 0.5))
end

on UpdateVisuals me, tPerc, tSpeed
  if tPerc = VOID then
    tPerc = 0.0
  end if
  if tSpeed = VOID then
    tSpeed = 1
  end if
  p.model.rotate(0, 0, tSpeed, #self)
  p.model2.rotate(0, 0, tSpeed, #self)
  tString = string(integer(min(tPerc, 1.0) * 100.0) & " %")
  if p.StateTag = #initializing then
    if p.InitString = "." then
      p.InitString = ".."
    else
      if p.InitString = ".." then
        p.InitString = "..."
      else
        if p.InitString = "..." then
          p.InitString = "...."
        else
          if p.InitString = "...." then
            p.InitString = "....."
          else
            if p.InitString = "....." then
              p.InitString = "."
            end if
          end if
        end if
      end if
    end if
    tString = p.InitString
  end if
  if gSystem.local = 0 then
    CreateTextTexture(0, p.member.name, [#tag: #PreloaderPercentage, #style: #PreloaderPercentage, #text: tString])
  end if
  if p.camera.rect <> p.TargetRect then
    p.camera.rect = p.TargetRect
  end if
  set the stageColor to the stageColor
  _movie.updateStage()
end

on UpdateVisualState me, tTag
  p.state.visibility = #front
  p.icon.visibility = #front
  case tTag of
    #none:
      p.state.visibility = #none
      p.icon.visibility = #none
    #LOADING:
      p.state.resource = p.member.modelResource("PreLoaderStateLoading")
    #initializing:
      p.state.resource = p.member.modelResource("PreLoaderStateInitializing")
  end case
  p.StateTag = tTag
end

on UpdateVisualDetail me, tTag
  p.detail.visibility = #front
  case tTag of
    #none:
      p.detail.visibility = #none
    #cast:
      p.detail.resource = p.member.modelResource("PreLoaderStateAssets")
    #Assets:
      p.detail.resource = p.member.modelResource("PreLoaderStateAssets")
    #world:
      p.detail.resource = p.member.modelResource("PreLoaderStateWorld")
    #track:
      p.detail.resource = p.member.modelResource("PreLoaderStateTrack")
    #game:
      p.detail.resource = p.member.modelResource("PreLoaderStateGame")
  end case
end

on UpdateVisualPercentage me, tTag
  p.Percentage.visibility = #front
  case tTag of
    #none:
      p.Percentage.visibility = #none
    #Percentage:
      p.Percentage.visibility = #front
  end case
end

on UpdateCamera me
  nothing()
end

on delete me
  gSystem.UpdateScript = #none
  p.sprite.member = VOID
  p.sprite = VOID
  _movie.puppetSprite(_movie.lastChannel, 0)
  DeleteButton(0, EMPTY, [#model: "PreLoaderShockwaveButton"])
  sprite(_movie.lastChannel).width = 1
  sprite(_movie.lastChannel).height = 1
  p.member.resetWorld()
  p = [:]
end
