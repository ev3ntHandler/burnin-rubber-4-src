-- [Script] [PS] BR4 Menu (Script #5862)
-- Script Type: Parent

property p
global gSystem, gGame

on new me, tDataList
  p = [:]
  p[#ScriptName] = "BR4 Menu"
  p[#member] = member(tDataList[#member])
  p[#state] = #inactive
  p[#event] = #none
  p[#camera] = p.member.camera("Menu_Camera")
  p.camera.rootNode = 0
  p[#TargetCamera] = gGame.camera[1].camera
  p[#StoredPosition] = p.TargetCamera.worldPosition
  p[#CameraScript] = GetScript(0, EMPTY, [#script: "Camera1"])
  p[#target] = #none
  p[#FovYonFog] = transform()
  p[#Percentage] = 22
  p[#animation] = 0
  tList = ["TitleLogo", "TitleLogoShadow", "LogoGotyPlate", "TitleLogoAfterburner1", "TitleStartButton", "TitlestartGlowButton"]
  p[#ModelAnimList] = []
  repeat with i in tList
    tmodel = p.member.model(i)
    tmodel.keyframePlayer.pause()
    tmodel.keyframePlayer.removeLast()
    tAnimation = p.member.motion(tmodel.name & "-Key")
    p.ModelAnimList.add([tmodel, tAnimation])
  end repeat
  p[#SoundTimeLine] = [#frame1: "FlamethrowerLogo_SFX", #frame50: "ExplosionMedium_SFX", #frame55: "ExplosionLarge_SFX", #frame74: "Rollover_SFX", #Frame75: "Bump_SFX", #frame84: "Rollover_SFX", #frame94: "Rollover_SFX"]
  p[#EventTimeLine] = [#frame50: "Explosion1Intro", #frame55: "Explosion2Intro", #Frame80: "PlayMusicIntro"]
  p[#interface] = member("Interface")
  p[#OverlayShader] = p.interface.shader("InterfaceOverlaysPause_Material")
  tParent = p.member.model("Clouds").clone("DropShadowClouds")
  repeat with i = 1 to tParent.child.count
    tChild = tParent.child[i]
    if tChild.name contains "CloudsScrolling" then
      if tChild.name contains "LowerCloudsScrolling" then
        tChild.shader = p.member.shader("DropShadowCloudsScrolling2_Material")
      else
        tChild.shader = p.member.shader("DropShadowCloudsScrolling_Material")
      end if
      next repeat
    end if
    tChild.shader = p.member.shader("DropShadowClouds_Material")
  end repeat
  tParent.translate(1, -1, -1, #self)
  p.member.model("LowerCloudsScrolling").parent = VOID
  p[#Clouds] = [p.member.model("Clouds"), tParent]
  repeat with i in p.Clouds
    i.userData.addProp(#transform, i.getWorldTransform())
  end repeat
  p[#AnimationMultipliers] = [0.0015, 6.5, -0.0001, -0.0002, -0.0002, -0.0004, 0.10000000000000001]
  p[#timer] = 0
  p[#CloudShaders] = [p.member.shader("CloudsScrolling_Material"), p.member.shader("DropShadowCloudsScrolling_Material")]
  p[#LowerCloudShader] = p.member.shader("DropShadowCloudsScrolling2_Material")
  tGlowButton = member(8, 3).cloneModelFromCastmember("QuitGlowButton", "QuitGlowButton", member("QuitButton", 3))
  tGlowButton.shader = p.member.shader("Font3DGlow_Material")
  p[#QuitButton] = member(8, 3).cloneModelFromCastmember("QuitButton", "QuitButton", member("QuitButton", 3))
  p.QuitButton.shader = p.member.shader("Font3D_Material")
  tGlowButton.parent = p.QuitButton
  p.QuitButton.transform.position = vector(6.40000000000000036, 4.25, 622.5)
  return me
end

on enterFrame me
  if p.state = #Active then
    if p.animation = 1 then
      me.UpdateAnimation()
    end if
    if p.target <> #none then
      p.camera.transform.interpolateTo(p.target.transform, p.Percentage)
      tDistance = p.camera.worldPosition.distanceTo(p.target.worldPosition)
      if p.target.name = "Target_Dummy" then
        if tDistance > 10.0 then
          p.camera.transform.rotation = vector(0, 0, 0)
        end if
      end if
      if tDistance <= 0.01 then
        p.camera.transform = p.target.transform
        p.target = #none
        if p.event <> #none then
          me.RunEvent()
        end if
      end if
    end if
    me.UpdateTargetCamera()
  end if
  if p.state = #fadeOut then
    p.OverlayShader.blend = max(0, p.OverlayShader.blend - 13)
    if (p.OverlayShader.blend = 0) and (p.event <> #none) then
      me.RunEvent()
    end if
  end if
  if p.state = #fadeIn then
    p.OverlayShader.blend = min(100, p.OverlayShader.blend + 13)
    if (p.OverlayShader.blend = 100) and (p.event <> #none) then
      me.RunEvent()
    end if
  end if
  if (p.state = #Active) or (p.state = #fadeIn) or (p.state = #fadeOut) then
    p.timer = p.timer + p.AnimationMultipliers[1]
    tOffset = sin(p.timer)
    tOffset2 = cos(p.timer)
    repeat with i in p.Clouds
      i.transform.position.x = i.userData.transform.position.x + (tOffset * p.AnimationMultipliers[2])
      i.transform.position.y = i.userData.transform.position.y + (tOffset2 * p.AnimationMultipliers[2])
    end repeat
    repeat with i in p.CloudShaders
      i.textureTransformList[1].position = vector(tOffset * p.AnimationMultipliers[7], tOffset2 * p.AnimationMultipliers[7], 0)
    end repeat
    p.LowerCloudShader.textureTransformList[1].position = vector(tOffset * p.AnimationMultipliers[7], tOffset2 * p.AnimationMultipliers[7], 0)
  end if
end

on setState me, tTarget, tDataList
  p.state = tDataList.state
end

on StorePosition me
  p.StoredPosition = p.TargetCamera.worldPosition
  p.member.group("Target_Dummy").transform.rotation.x = p.TargetCamera.transform.rotation.x
end

on setCamera me, tTarget, tDataList
  tDummy = GetReferenceType(0, p.member, tDataList.target)
  p.camera.transform = tDummy.transform
end

on SetCameraTarget me, tTarget, tDataList
  p.target = GetReferenceType(0, p.member, tDataList.target)
end

on SetCameraRootNode me, tTarget, tDataList
  if tDataList.target = #none then
    p.camera.rootNode = 0
  else
    p.camera.rootNode = GetReferenceType(0, p.member, tDataList.target)
  end if
end

on SetCameraSettings me, tTarget, tDataList
  if gGame.Vehicle = "Helicopter" then
    tDataList.yon = 1500.0
  end if
  if gGame.ShowMore then
    tDataList.yon = 1500.0
  end if
  p.FovYonFog.position = vector(tDataList.fov, tDataList.yon, tDataList.fogFar)
end

on SetShader me, tTarget, tDataList
  p.OverlayShader.blend = tDataList.blend
end

on SetEvent me, tTarget, tDataList
  p.event = tDataList.event
end

on RunEvent me
  tEvent = p.event
  p.event = #none
  event(0, tEvent)
end

on UpdateTargetCamera me, tTarget, tDataList
  p.TargetCamera.transform.position.z = p.StoredPosition.z + p.camera.worldPosition.z
  p.TargetCamera.transform.rotation.x = p.camera.transform.rotation.x
  tTransform = transform()
  tTransform.position = vector(p.TargetCamera.fieldOfView, p.TargetCamera.yon, p.TargetCamera.fog.far)
  tTransform.interpolateTo(p.FovYonFog, p.Percentage)
  p.TargetCamera.fieldOfView = tTransform.position.x
  p.TargetCamera.yon = max(1.0, tTransform.position.y)
  p.TargetCamera.fog.far = tTransform.position.z
  p.CameraScript.updateSkyBox(gGame.camera[1])
end

on PrepareIntroAndStart me
  timeout().new("PrepareAnimationEvent", 3000, #PrepareAnimationEvent, me)
  timeout().new("IntroAnimationEvent", 3250, #IntroAnimationEvent, me)
end

on PrepareAnimationEvent me
  timeout("PrepareAnimationEvent").forget()
  event(0, #PrepareIntro)
end

on IntroAnimationEvent me
  timeout("IntroAnimationEvent").forget()
  event(0, #StartIntro)
end

on startAnimation me
  repeat with i in p.ModelAnimList
    i[1].keyframePlayer.removeLast()
    i[1].keyframePlayer.play(i[2].name, 0)
  end repeat
  p.animation = 1
end

on UpdateAnimation me
  repeat with i in p.ModelAnimList
    i[1].keyframePlayer.currentTime = i[1].keyframePlayer.currentTime + (33.32999999999999829 * gGame.TimeMP)
  end repeat
  tFrame = integer(p.ModelAnimList[1][1].keyframePlayer.currentTime / (33.32999999999999829 * gGame.TimeMP))
  tSymbol = symbol("Frame" & tFrame)
  if p.SoundTimeLine.getaProp(tSymbol) <> VOID then
    PlaySound(0, p.SoundTimeLine[tSymbol], [#Override: 1])
    p.SoundTimeLine.deleteProp(tSymbol)
  end if
  if p.EventTimeLine.getaProp(tSymbol) <> VOID then
    event(0, symbol(p.EventTimeLine[tSymbol]))
    p.EventTimeLine.deleteProp(tSymbol)
  end if
  if p.ModelAnimList[1][1].keyframePlayer.currentTime = 0 then
    p.animation = 0
    if p.event <> #none then
      me.RunEvent()
    end if
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
