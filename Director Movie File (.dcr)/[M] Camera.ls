-- [Script] [M] Camera (Script #6154)
-- Script Type: Movie

global gSystem, gData, gGame

on ShowHideRoots me, t
  if voidp(gGame[#vehicles]) = 1 then
    return 0
  end if
  tSymbol = symbol(t.target.name)
  if voidp(gGame.vehicles[tSymbol]) = 1 then
    exit
  end if
  tRootList = gGame.vehicles[tSymbol].Vehicle.RootList
  tPreviousRootList = gGame.vehicles[tSymbol].Vehicle.previousRootList
  repeat with i in tPreviousRootList
    tgroup = t.member.group("TrackRoot" & i)
    if tgroup <> VOID then
      tgroup.parent = VOID
    end if
  end repeat
  repeat with i in tRootList
    tgroup = t.member.group("TrackRoot" & i)
    if tgroup <> VOID then
      tgroup.parent = gGame.member.group("World")
    end if
  end repeat
end

on BackwardsView me, t
  if voidp(gGame[#vehicles]) = 1 then
    return 0
  end if
  if voidp(gGame.vehicles[symbol(t.target.name)]) = 0 then
    if gGame.vehicles[symbol(t.target.name)].Input.backwardCam = 1 then
      tBackwardSet = #Backwards
      tCount = gData.data.camera[tBackwardSet].count
      repeat with i = 1 to tCount
        tProp = gData.data.camera[tBackwardSet].getPropAt(i)
        t[tProp] = gData.data.camera[tBackwardSet][tProp]
      end repeat
      t.CurrentSet = tBackwardSet
    else
      if t.CurrentSet <> t.DefaultSet then
        tCount = gData.data.camera[symbol(t.DefaultSet)].count
        repeat with i = 1 to tCount
          tProp = gData.data.camera[symbol(t.DefaultSet)].getPropAt(i)
          if tProp = #IntSpeed then
            next repeat
          end if
          t[tProp] = gData.data.camera[symbol(t.DefaultSet)][tProp]
        end repeat
        t.updateStates = 0
        t.script.enterFrame()
        t.updateStates = 1
        t.IntSpeed = gData.data.camera[symbol(t.DefaultSet)].IntSpeed
        t.CurrentSet = symbol(t.DefaultSet)
      end if
    end if
  end if
end

on DebugVehiclesCamera me, t
  if voidp(gGame[#vehicles]) = 0 then
    tValue = value(_key.key)
    if (tValue.ilk <> #integer) or (tValue = 0) then
      return 0
    else
      if tValue <= gGame.vehicles.count then
        gGame.camera[1].target = gGame.vehicles[tValue].general.tag
      end if
    end if
  end if
end

on DebugCompassCamera me, t
  tSet = #none
  if keyPressed("q") then
    tSet = t.DefaultSet
  end if
  if keyPressed("w") then
    tSet = #CNorth
  end if
  if keyPressed("s") then
    tSet = #CSouth
  end if
  if keyPressed("a") then
    tSet = #CWest
  end if
  if keyPressed("d") then
    tSet = #CEast
  end if
  if tSet <> #none then
    tCount = gData.data.camera[tSet].count
    repeat with i = 1 to tCount
      tProp = gData.data.camera[tSet].getPropAt(i)
      t[tProp] = gData.data.camera[tSet][tProp]
    end repeat
  end if
end

on UpdateCameraSet me, tSet
  if tSet.ilk = #string then
    tSet = value(tSet)
  end if
  if tSet.ilk <> #symbol then
    tSet = symbol(tSet)
  end if
  if voidp(gData.data.camera[tSet]) = 1 then
    return 0
  end if
  tCount = gData.data.camera[tSet].count
  repeat with i = 1 to tCount
    tProp = gData.data.camera[tSet].getPropAt(i)
    gGame.camera[1][tProp] = gData.data.camera[tSet][tProp]
  end repeat
  gGame.camera[1].CurrentSet = tSet
  gGame.camera[1].pivot.transform.rotation.x = 0.0
end

on SetFog me, tTarget, tDataList
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
  tCameraName = "DefaultView"
  if tDataList[#camera].ilk = #string then
    tCameraName = tDataList.camera
  end if
  tCamera = tmember.camera(tCameraName)
  if tCamera = VOID then
    return 0
  end if
  tFog = 1
  if tDataList[#fog].ilk = #integer then
    if (tDataList[#fog] = 0) or (tDataList[#fog] = 1) then
      tFog = tDataList.fog
    end if
  end if
  tCamera.fog.enabled = tFog
  if tDataList[#range].ilk = #list then
    tRange = tDataList.range
  else
    tRange = [tCamera.fog.near, tCamera.fog.far]
  end if
  if tDataList[#color].ilk = #list then
    tColor = rgb(tDataList.color[1], tDataList.color[2], tDataList.color[3])
  end if
  if tDataList[#color].ilk = #color then
    tColor = tDataList.color
  end if
  tCamera.fog.near = tRange[1]
  tCamera.fog.far = tRange[2]
  tCamera.fog.color = tColor
  tType = #linear
  if tDataList[#type].ilk = #symbol then
    tType = tDataList.type
  end if
  case tType of
    #linear:
      tCamera.fog.decayMode = tType
    #exponential:
      tCamera.fog.decayMode = tType
    #exponential2:
      tCamera.fog.decayMode = tType
    otherwise:
      tCamera.fog.decayMode = #linear
  end case
  return 1
end

on SetSkybox me, tTarget, tDataList
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return VOID
  end if
  tmember = member("Skyboxes" & gGame.setting)
  if tmember = VOID then
    return VOID
  end if
  tAutoSetup = 1
  if tDataList[#AutoSetup].ilk = #integer then
    tAutoSetup = tDataList.AutoSetup
  end if
  if tAutoSetup = 1 then
    if tmember.texture.count = 1 then
      event(0, #SkyboxInitialization)
    end if
  end if
  if tDataList[#skybox].ilk = #string then
    tSkybox = tDataList.skybox
  else
    return 0
  end if
  tDummy = tmember.model(tSkybox & "_Dummy")
  if tDummy = VOID then
    return 0
  end if
  tParent = tmember.group("Skybox_Group")
  if tParent = VOID then
    tParent = tmember.newGroup("Skybox_Group")
  end if
  if tParent.child.count > 0 then
    repeat with i = 1 to tParent.child.count
      tChild = tParent.child[i]
      tChild.parent = VOID
    end repeat
  end if
  tDummy.parent = tParent
  tCount = tmember.shader.count
  repeat with i = 1 to tCount
    tShader = tmember.shader[i]
    if tShader.name contains "Opaque" then
      tShader.transparent = 0
    end if
  end repeat
end

on AddCameraToSprite me, tTarget, tDataList
  if (tTarget = VOID) or (tTarget = EMPTY) then
    if gGame[#sprite].ilk = #sprite then
      tTarget = gGame.sprite
    end if
  end if
  if tTarget.ilk = #sprite then
    tSprite = tTarget
  else
    tSprite = sprite(value(tTarget))
    if tSprite = sprite(0) then
      return 0
    end if
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tmember = VOID
  if tDataList[#member].ilk = #string then
    tmember = member(tDataList.member)
  end if
  if tmember = VOID then
    return 0
  end if
  tCameraName = VOID
  if tDataList[#camera].ilk = #string then
    tCameraName = tDataList.camera
  end if
  if tCameraName = VOID then
    return 0
  end if
  tCamera = tmember.camera(tCameraName)
  if tCamera = VOID then
    return 0
  end if
  tCamera.userData.addProp(#member, tmember)
  tIndex = tSprite.cameraCount() + 1
  if tDataList[#index].ilk = #integer then
    tIndex = tDataList.index
  end if
  tSprite.addCamera(tCamera, tIndex)
end

on RemoveCameraFromSprite me, tTarget, tDataList
  if value(tTarget).ilk <> #integer then
    return 0
  end if
  tSprite = sprite(value(tTarget))
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tIndex = 0
  if tDataList[#index].ilk = #integer then
    tIndex = tDataList.index
  end if
  if tIndex = 0 then
    tCameraName = VOID
    if tDataList[#camera].ilk = #string then
      tCameraName = tDataList.camera
    end if
    if tCameraName = VOID then
      return 0
    end if
    tCount = tSprite.cameraCount()
    tIndex = 0
    repeat with i = 1 to tCount
      if tSprite.camera(i).name = tCameraName then
        tIndex = i
      end if
    end repeat
    if tIndex > 0 then
      tSprite.deleteCamera(tIndex)
    end if
  else
    if tIndex > 0 then
      tSprite.deleteCamera(tIndex)
    end if
  end if
end

on CreateCamera me, tTarget, tDataList
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
  if tDataList[#camera].ilk = #string then
    tCameraName = tDataList.camera
  else
    return VOID
  end if
  return tmember.newCamera(tCameraName)
end

on setCamera me, tTarget, tDataList
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
  if tDataList[#camera].ilk = #string then
    tCamera = tmember.camera(tDataList.camera)
  else
    return 0
  end if
  if tCamera = VOID then
    return 0
  end if
  if (tDataList[#near].ilk = #float) or (tDataList[#near].ilk = #integer) then
    tCamera.hither = tDataList.near
  end if
  if (tDataList[#far].ilk = #float) or (tDataList[#far].ilk = #integer) then
    tCamera.yon = tDataList.far
  end if
  if (tDataList[#fov].ilk = #float) or (tDataList[#fov].ilk = #integer) then
    tCamera.fieldOfView = tDataList.fov
  end if
  if tDataList[#projection].ilk = #symbol then
    if (tDataList.projection = #orthographic) or (tDataList.projection = #perspective) then
      tCamera.projection = tDataList.projection
    end if
  end if
  if (tDataList[#orthoHeight].ilk = #float) or (tDataList[#orthoHeight].ilk = #integer) then
    tCamera.orthoHeight = tDataList.orthoHeight
  end if
  if tDataList[#clearAtRender].ilk = #integer then
    if (tDataList.clearAtRender = 0) or (tDataList.clearAtRender = 1) then
      tCamera.colorBuffer.clearAtRender = tDataList.clearAtRender
    end if
  end if
  if tDataList[#clearValue].ilk = #color then
    tCamera.colorBuffer.clearValue = tDataList.clearValue
  end if
  if tDataList[#rect].ilk = #rect then
    tCamera.rect = tDataList.rect
  end if
end

on deleteCamera me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  if tDataList = VOID then
    tDataList = [#camera: "*.*"]
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tTargetList = []
  if tDataList[#camera].ilk = #void then
    tDataList[#camera] = "*.*"
  end if
  if tDataList[#camera].ilk = #list then
    tTargetList = tDataList.camera
  else
    if tDataList[#camera].ilk = #string then
      if tDataList.camera.char[1] = "*" then
        tString = tDataList.camera
        if tString <> "*.*" then
          delete tString.char[1]
        end if
        tTargetList = GetObjectList(0, tmember.name, [#type: #camera, #string: tString])
      else
        tTargetList.add(tDataList.camera)
      end if
    end if
  end if
  if tTargetList.count = 0 then
    return 0
  end if
  repeat with i in tTargetList
    if i = "DefaultView" then
      next repeat
    end if
    tmember.deleteCamera(i)
  end repeat
  return 1
end

on DuplicateCamera me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return []
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return []
  end if
  tSourceMember = tmember
  if tDataList[#sourceMember].ilk = #string then
    tSourceMember = member(tDataList.sourceMember)
  end if
  tTargetList = []
  if tDataList[#camera].ilk = #void then
    tDataList[#camera] = "*.*"
  end if
  if tDataList[#camera].ilk = #list then
    tTargetList = tDataList.camera
  else
    if tDataList[#camera].ilk = #string then
      if tDataList.camera.char[1] = "*" then
        tString = tDataList.camera
        if tString <> "*.*" then
          delete tString.char[1]
        end if
        tTargetList = GetObjectList(0, tSourceMember.name, [#type: #camera, #string: tString])
      else
        tTargetList.add(tDataList.camera)
      end if
    end if
  end if
  if tTargetList.count = 0 then
    return []
  end if
  tCameraList = []
  tCameraTag = VOID
  if tDataList[#cameraTag].ilk = #string then
    tCameraTag = tDataList.cameraTag
  end if
  repeat with i in tTargetList
    if i = "DefaultView" then
      next repeat
    end if
    tOrigCam = tSourceMember.camera(i)
    if tmember.camera(tCameraTag & tOrigCam.name) <> VOID then
      next repeat
    end if
    tDupCam = tmember.newCamera(tCameraTag & tOrigCam.name)
    tDupCam.hither = tOrigCam.hither
    tDupCam.yon = tOrigCam.yon
    tDupCam.rect = tOrigCam.rect
    tDupCam.projection = tOrigCam.projection
    tDupCam.fieldOfView = tOrigCam.fieldOfView
    tDupCam.orthoHeight = tOrigCam.orthoHeight
    tDupCam.colorBuffer.clearAtRender = tOrigCam.colorBuffer.clearAtRender
    tDupCam.colorBuffer.clearValue = tOrigCam.colorBuffer.clearValue
    tDupCam.fog.enabled = tOrigCam.fog.enabled
    tDupCam.fog.enabled = tOrigCam.fog.enabled
    tDupCam.fog.near = tOrigCam.fog.near
    tDupCam.fog.far = tOrigCam.fog.far
    tDupCam.fog.color = tOrigCam.fog.color
    tDupCam.fog.decayMode = tOrigCam.fog.decayMode
    tCameraList.add(tDupCam)
  end repeat
  if tCameraList.count = 1 then
    return tCameraList[1]
  else
    return tCameraList
  end if
end

on SetActiveCamera me, tTarget, tDataList
  if (tTarget = VOID) or (tTarget = EMPTY) then
    if gGame[#sprite].ilk = #sprite then
      tTarget = gGame.sprite
    end if
  end if
  if tTarget.ilk = #sprite then
    tSprite = tTarget
  else
    tSprite = sprite(value(tTarget))
    if tSprite = sprite(0) then
      return 0
    end if
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  if tDataList[#camera].ilk = #string then
    tCamera = tSprite.member.camera(tDataList.camera)
  else
    return 0
  end if
  tSprite.camera = tCamera
  if gSystem.UpdateScript <> #none then
    gSystem.UpdateScript.UpdateCamera(tCamera)
  end if
  if gSystem.FadeScript <> #none then
    gSystem.FadeScript.UpdateCamera(tCamera)
  end if
end

on CameraShake me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    return 0
  end if
end
