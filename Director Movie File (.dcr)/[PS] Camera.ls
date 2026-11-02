-- [Script] [PS] Camera (Script #6174)
-- Script Type: Parent

property p
global gSystem, gData, gGame

on new me, tDataList
  p = [:]
  tmember = VOID
  if tDataList[#member].ilk = #string then
    tmember = member(tDataList.member)
  end if
  if tDataList[#member].ilk = #member then
    tmember = tDataList.member
  end if
  if tmember = VOID then
    return 0
  end if
  if tDataList[#sprite].ilk = #integer then
    p[#sprite] = sprite(tDataList.sprite)
  else
    p[#sprite] = gGame.sprite
  end if
  if getaProp(gGame, #camera) = VOID then
    gGame[#camera] = [:]
  end if
  tNr = gGame.camera.count + 1
  p[#index] = symbol("Camera" & tNr)
  p[#ScriptName] = "Camera" & tNr
  gGame.camera[p.index] = [:]
  tList = gGame.camera[p.index]
  tList[#sprite] = p.sprite
  tList[#member] = tmember
  tCamera = tmember.newCamera("Player" & tNr & "_Camera")
  tCamera.rotate(90, 0, 0, #self)
  tSkyBoxMember = member("Skyboxes" & gGame.setting)
  tSkyBoxMember.camera("DefaultView").transform.position = vector(0, 0, -1500)
  tSkyBoxMember.camera("DefaultView").transform.rotation = vector(0, 0, 0)
  tSkyboxCamera = tSkyBoxMember.newCamera("Skybox" & tNr & "_Camera")
  tSkyboxCamera.rootNode = tSkyBoxMember.group("Skybox_Group")
  tSkyBoxMember.group("Skybox_Group").removeFromWorld()
  tSkyboxCamera.transform.position = vector(0, 0, -1500)
  tSkyboxCamera.transform.rotation = vector(0, 0, 0)
  p.sprite.camera = tCamera
  p.sprite.addCamera(tSkyboxCamera, 1)
  tCamera.rect = rect(0, 0, gGame.stageSize[1], gGame.stageSize[2])
  tSkyboxCamera.rect = rect(0, 0, gGame.stageSize[1], gGame.stageSize[2])
  tCameraSet = #default
  if gGame[#CameraSet].ilk = #symbol then
    tCameraSet = gGame.CameraSet
  end if
  if voidp(gData.data[#camera][tCameraSet]) = 0 then
    tCamSet = gData.data.camera[tCameraSet].duplicate()
  else
    tCamSet = gData.data.camera.default.duplicate()
  end if
  tCamera.hither = tCamSet.NearClip
  tCamera.yon = tCamSet.FarClip
  if gGame.ShowMore then
    if gGame.Scene = "Track" then
      tCamera.yon = 1000
    else
      tCamera.yon = 1500
    end if
  end if
  tCamera.colorBuffer.clearAtRender = 0
  tList[#state] = #follow
  tList[#oldState] = #free
  tList[#camera] = tCamera
  tList[#SkyBoxCamera] = tSkyboxCamera
  if tDataList[#target].ilk <> #void then
    tTarget = GetReferenceType(0, tmember, string(tDataList.target))
  else
    tTarget = tmember.group("World")
  end if
  tList[#OldTarget] = tTarget
  tList[#target] = tTarget
  tList[#offset] = tCamSet.offset
  tList[#OldOffSet] = vector()
  tList[#rotation] = tCamSet.rotation
  tList[#OldRotation] = vector()
  tList[#position] = tCamSet.position
  tList[#OldPosition] = vector()
  tList[#transform] = tCamera.transform
  tList[#PosSpeed] = tCamSet.PosSpeed
  tList[#RotSpeed] = tCamSet.RotSpeed
  tList[#IntSpeed] = tCamSet.IntSpeed
  tList[#fov] = tCamSet.fov
  tList[#scale] = 1.0
  tList[#DefaultSet] = tCameraSet
  tList[#CurrentSet] = tCameraSet
  tList[#pivot] = tmember.newGroup(tCamera.name & "Pivot")
  tList[#Camerapoint] = tmember.newGroup(tCamera.name & "Point")
  tList.Camerapoint.parent = gGame.camera[p.index].pivot
  tList[#BillboardPoint] = tmember.newGroup(tCamera.name & "Billboard")
  tList.BillboardPoint.pointAtOrientation = [vector(0, 1, 0), vector(0, 0, 1)]
  tList[#PosPos] = 1
  tList[#RotPos] = 1
  tList[#UpDownLock] = 1
  tList[#FreeKey] = [0, 0]
  tList[#FreeSpeed] = [0.75, 5.0]
  tList[#SpeedKeys] = [[0, 0], [0, 0]]
  tList[#MouseClick] = #none
  tList[#OrigTransform] = tCamera.getWorldTransform().duplicate()
  tList[#OldTransform] = tCamera.getWorldTransform()
  tList[#Speed] = 0.0
  tList[#direction] = vector(0, 1, 0)
  tList[#drag] = 0.90000000000000002
  tList[#limitX] = #none
  tList[#limitY] = #none
  tList[#limitZ] = #none
  if gGame[#CameraStates].ilk = #list then
    gGame.camera[p.index][#States] = gGame.CameraStates
  else
    gGame.camera[p.index][#States] = []
  end if
  tList[#updateStates] = 1
  tList[#script] = me
  if tDataList[#target].ilk <> #void then
    tIntSpeed = tList.IntSpeed
    tPosSpeed = tList.PosSpeed
    tRotSpeed = tList.RotSpeed
    tList.IntSpeed = 100.0
    tList.PosSpeed = 1.0
    tList.RotSpeed = 1.0
    me.enterFrame()
    tList.IntSpeed = tIntSpeed
    tList.PosSpeed = tPosSpeed
    tList.RotSpeed = tRotSpeed
  end if
  return me
end

on enterFrame me
  t = gGame.camera[p.index]
  if t.OldTarget <> t.target then
    t.target = GetReferenceType(0, t.member, string(t.target))
  end if
  if t.target = VOID then
    t.target = t.member.group("World")
  end if
  t.OldTarget = t.target
  t.OldTransform = t.camera.getWorldTransform()
  if t.state.ilk <> #list then
    t.state = [t.state]
  end if
  tList = t.state.duplicate()
  repeat with i in tList
    case i of
      #Mimic:
        me.Mimic(t)
      #follow:
        me.follow(t)
      #free:
        me.free(t)
      #slowDown:
        me.slowDown(t)
      #lookAt:
        me.lookAt(t)
      otherwise:
        nothing()
    end case
  end repeat
  me.updateSkyBox(t)
  if t.updateStates = 1 then
    repeat with i in t.States
      sendSprite(0, i, t)
    end repeat
  end if
  tTransform = t.camera.getWorldTransform()
  t.BillboardPoint.transform = tTransform
  t.BillboardPoint.pointAt(tTransform.position + tTransform.zAxis + vector(0.001, 0.001, 0.001), vector(0, 0, 1))
  t.FreeKey.addAt(1, _key.keyPressed("c"))
  if (_key.commandDown = 1) and (_key.optionDown = 1) then
    if (t.FreeKey[1] = 0) and (t.FreeKey[2] = 1) then
      tOldState = t.oldState
      t.oldState = t.state
      t.state = tOldState
      if (t.oldState = [#follow]) and ((t.state = [#free]) or (t.state = #free)) then
        gGame.Input = 0
        gGame.TimeMP = 0.0001
        member("Interface").camera("Interface_Camera").rootNode = 0
        member("MiniMap").camera("MiniMap_Camera").rootNode = 0
      else
        gGame.Input = 1
        gGame.TimeMP = 1
        member("Interface").camera("Interface_Camera").rootNode = member("Interface").group("World")
        member("MiniMap").camera("MiniMap_Camera").rootNode = member("MiniMap").group("World")
      end if
      put "--> Camera in " & string(t.state) & " mode. Old state was " & string(t.oldState)
    end if
  end if
  if t.FreeKey.count > 2 then
    t.FreeKey.deleteAt(3)
  end if
end

on Mimic me, t
  tCurrentTransform = t.camera.transform
  tTargetTransform = t.target.getWorldTransform().duplicate()
  if tCurrentTransform <> tTargetTransform then
    tCurrentTransform.interpolateTo(tTargetTransform, t.IntSpeed)
  end if
  t.camera.transform.scale = vector(1, 1, 1) * t.scale
  if t.target.ilk = #camera then
    tCurrentFov = transform()
    tTargetFov = transform()
    tCurrentFov.position.z = float(t.camera.fieldOfView)
    tTargetFov.position.z = t.target.fieldOfView
    if tCurrentFov <> tTargetFov then
      tCurrentFov.interpolateTo(tTargetFov, t.IntSpeed)
    end if
    t.camera.fieldOfView = tCurrentFov.position.z
  end if
  t.direction = t.camera.getWorldTransform().position - t.OldTransform.position
  t.Speed = t.direction.length
  t.direction.normalize()
end

on follow me, t
  tCurrentTransform = t.Camerapoint.transform
  tTargetTransform = t.Camerapoint.getWorldTransform().duplicate()
  if t.PosPos = 1 then
    tTargetTransform.position = t.offset
  end if
  if t.RotPos = 1 then
    tTargetTransform.rotation = t.rotation
  end if
  if tCurrentTransform <> tTargetTransform then
    tCurrentTransform.interpolateTo(tTargetTransform, t.IntSpeed)
  end if
  tCurrentFov = transform()
  tTargetFov = transform()
  tCurrentFov.position.z = float(t.camera.fieldOfView)
  tTargetFov.position.z = t.fov
  if tCurrentFov <> tTargetFov then
    tCurrentFov.interpolateTo(tTargetFov, t.IntSpeed)
  end if
  tCos = t.target.transform.zAxis.dot(vector(0, 0, 1))
  txform = t.target.getWorldTransform()
  pxr = t.pivot.transform.rotation
  pxp = t.pivot.transform.position
  if tCos < 0 then
    txform.rotation.z = 0.0
  end if
  pxr.x = pxr.x + (360 * (txform.rotation.x > (pxr.x + 180))) - (360 * (txform.rotation.x < (pxr.x - 180)))
  pxr.y = pxr.y + (360 * (txform.rotation.y > (pxr.y + 180))) - (360 * (txform.rotation.y < (pxr.y - 180)))
  pxr.z = pxr.z + (360 * (txform.rotation.z > (pxr.z + 180))) - (360 * (txform.rotation.z < (pxr.z - 180)))
  pxp = pxp + ((txform.position - pxp) * (t.PosSpeed * gGame.TimeMP))
  pxr = pxr + ((txform.rotation - pxr) * (t.RotSpeed * gGame.TimeMP))
  t.pivot.transform.rotation.z = pxr.z
  if t.UpDownLock = 0 then
    if tCos > 0 then
      t.pivot.transform.rotation.x = pxr.x
    end if
  else
    if (pxr.x < 0) and (tCos > 0) then
      t.pivot.transform.rotation.x = pxr.x
    end if
  end if
  t.pivot.transform.position = pxp
  t.camera.transform = t.Camerapoint.getWorldTransform()
  t.camera.transform.scale = vector(1, 1, 1) * t.scale
  t.camera.fieldOfView = tCurrentFov.position.z
  t.direction = t.camera.getWorldTransform().position - t.OldTransform.position
  t.Speed = t.direction.length
end

on free me, t
  t.SpeedKeys[1].addAt(1, _key.keyPressed("-"))
  t.SpeedKeys[2].addAt(1, _key.keyPressed("="))
  if (t.SpeedKeys[1][1] = 0) and (t.SpeedKeys[1][2] = 1) then
    t.FreeSpeed[1] = max(t.FreeSpeed[1] - 0.10000000000000001, 0.10000000000000001)
  end if
  if t.SpeedKeys[1].count > 2 then
    t.SpeedKeys[1].deleteAt(3)
  end if
  if (t.SpeedKeys[2][1] = 0) and (t.SpeedKeys[2][2] = 1) then
    t.FreeSpeed[1] = min(t.FreeSpeed[1] + 0.10000000000000001, t.FreeSpeed[2])
  end if
  if t.SpeedKeys[2].count > 2 then
    t.SpeedKeys[2].deleteAt(3)
  end if
  tTransform = t.camera.transform
  if _key.shiftDown = 1 then
    tOffset = -(vector(0, 0, 1) * t.FreeSpeed[1])
  else
    tOffset = tTransform.zAxis * t.FreeSpeed[1]
  end if
  if keyPressed("w") then
    tTransform.position = tTransform.position - tOffset
  end if
  if keyPressed("s") then
    tTransform.position = tTransform.position + tOffset
  end if
  if keyPressed("a") then
    tTransform.position = tTransform.position - (tTransform.xAxis * t.FreeSpeed[1])
  end if
  if keyPressed("d") then
    tTransform.position = tTransform.position + (tTransform.xAxis * t.FreeSpeed[1])
  end if
  if _mouse.mouseDown = 1 then
    if t.MouseClick <> #none then
      t.camera.transform.rotation = t.OrigTransform.rotation
      tdiff = _mouse.mouseLoc - t.MouseClick
      tRotZ = tdiff.locH * 0.20000000000000001
      t.camera.transform.rotation.z = t.camera.transform.rotation.z - tRotZ
      tRotX = tdiff.locV * 0.20000000000000001
      t.camera.transform.rotation.x = t.camera.transform.rotation.x - tRotX
    else
      if _mouse.mouseLoc.inside(p.sprite.rect) = 1 then
        t.MouseClick = _mouse.mouseLoc
        t.OrigTransform = t.camera.getWorldTransform().duplicate()
      end if
    end if
  else
    t.MouseClick = #none
  end if
  if keyPressed("7") then
    member("Interface").camera("Interface_Camera").rootNode = 0
    member("MiniMap").camera("MiniMap_Camera").rootNode = 0
  end if
  if keyPressed("8") then
    member("Interface").camera("Interface_Camera").rootNode = member("Interface").group("World")
    member("MiniMap").camera("MiniMap_Camera").rootNode = member("MiniMap").group("World")
  end if
  if keyPressed("9") then
    gGame.Input = 0
    gGame.TimeMP = 0.0001
  end if
  if keyPressed("0") then
    gGame.Input = 1
    gGame.TimeMP = 1
  end if
  t.camera.transform.scale = vector(1, 1, 1) * t.scale
end

on slowDown me, t
  t.camera.transform.position = t.camera.transform.position + (t.direction * t.Speed)
  t.Speed = t.Speed * t.drag
  if t.Speed < 0.0001 then
    t.Speed = 0.0
  end if
  if t.Speed = 0.0 then
    t.state.deleteOne(#slowDown)
  end if
end

on lookAt me, t
  tPosition = t.target.worldPosition
  if t.limitZ <> #none then
    if t.limitZ = #camera then
      if tPosition.z >= t.camera.getWorldTransform().position.z then
        t.camera.pointAt(tPosition, vector(0, 0, 1))
      end if
    else
      if tPosition.z <= t.limitZ then
        tPosition.z = t.limitZ
      end if
    end if
  else
    t.camera.pointAt(tPosition, vector(0, 0, 1))
  end if
end

on updateSkyBox me, t
  if t = VOID then
    t = gGame.camera[1]
  end if
  t.SkyBoxCamera.transform.scale = t.camera.transform.scale
  t.SkyBoxCamera.transform.rotation = t.camera.transform.rotation
  t.SkyBoxCamera.transform.position.z = max(0.0, t.camera.transform.position.z)
  t.SkyBoxCamera.fieldOfView = t.camera.fieldOfView
end

on delete me
  p = [:]
  gGame.deleteProp(#camera)
  if gSystem.scriptList.getPos(me) <> 0 then
    gSystem.scriptList.deleteOne(me)
  else
    gGame.scriptList.deleteOne(me)
  end if
end
