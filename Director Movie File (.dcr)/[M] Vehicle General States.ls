-- [Script] [M] Vehicle General States (Script #5844)
-- Script Type: Movie

global gSystem, gData, gGame, gSound

on ResetStates me, t
  if t = VOID then
    t = gGame.vehicles[gGame.CurrentVehicle]
  end if
  tList = t.general.States.duplicate()
  SetItemDelimiter("_")
  repeat with i in tList
    tString = string(i)
    if i = #update_tank then
      tHandler = #reset_tank
    else
      if i = #Update_Autobot then
        tHandler = #reset_autobot
      else
        if i = #update_AutoFight then
          tHandler = #reset_AutoFight
        else
          tHandler = symbol("reset_" & tString.item[2])
        end if
      end if
    end if
    sendSprite(0, tHandler, t)
  end repeat
  ResetItemDelimiter()
end

on setup_keyInput me, t
  t.Input[#joystick] = 0
  tKeySets = [gGame.PlayerKeys1]
  tKeys = 1
  repeat with i in gGame.vehicles
    if i.general.controller = #player then
      tKeySet = tKeySet + 1
    end if
  end repeat
  t.Input[#keySet] = tKeySet
  t.Input[#Keys] = tKeySets[tKeySet]
  tCount = t.Input.Keys.count
  repeat with i = 1 to tCount
    tProp = t.Input.Keys.getPropAt(i)
    t.Input[tProp] = 0
  end repeat
end

on update_keyInput me, t
  if gGame.Input = 0 then
    exit
  end if
  tCount = t.Input.count
  repeat with i = 1 to tCount
    tProp = t.Input.getPropAt(i)
    if (tProp = #joystick) or (tProp = #keySet) or (tProp = #Keys) then
      next repeat
    end if
    if tProp = #brake then
      if t.Input.Keys.brake = "Shift" then
        t.Input.brake = _key.shiftDown
      else
        t.Input.brake = _key.keyPressed(t.Input.Keys.brake)
      end if
      next repeat
    end if
    t.Input[tProp] = _key.keyPressed(t.Input.Keys[tProp])
    case tProp of
      #forward:
        if t.Input.forward = 0 then
          t.Input.forward = _key.keyPressed("w")
        end if
      #backward:
        if t.Input.backward = 0 then
          t.Input.backward = _key.keyPressed("s")
        end if
      #left:
        if t.Input.left = 0 then
          t.Input.left = _key.keyPressed("a")
        end if
      #right:
        if t.Input.right = 0 then
          t.Input.right = _key.keyPressed("d")
        end if
      #action1:
        if t.Input.action1 = 0 then
          t.Input.action1 = _key.keyPressed("y")
        end if
        if t.Input.action1 = 0 then
          t.Input.action1 = _key.keyPressed(128)
        end if
      #action2:
        if t.Input.action2 = 0 then
          t.Input.action2 = _key.keyPressed(129)
        end if
    end case
  end repeat
end

on reset_keyInput me, t, tState
  if tState = VOID then
    tState = #delete
  end if
  tCount = t.Input.count
  repeat with i = 1 to tCount
    tProp = t.Input.getPropAt(i)
    if (tProp = #joystick) or (tProp = #keySet) or (tProp = #Keys) then
      next repeat
    end if
    t.Input[tProp] = 0
  end repeat
  if tState = #delete then
    t.general.States.deleteOne(#update_keyInput)
  end if
end

on setup_joyInput me, t
  if gGame[#joystick] = VOID then
    gGame[#joystick] = xtra("joystick").new()
  end if
  tNumberOfJoy = gGame.joystick.numberOfJoy()
  if tNumberOfJoy > 0 then
    tNr = 1
    repeat with i in gGame.vehicles
      if voidp(i.Input[#joystick]) = 0 then
        if i.Input.joystick = 1 then
          tNr = tNr + 1
        end if
      end if
    end repeat
    t.Input[#JoyNr] = tNr
    t.Input[#leftPerc] = 0.0
    t.Input[#rightPerc] = 0.0
    t.Input[#joystick] = 1
  else
    gGame.joystick = VOID
    gGame.deleteProp(#joystick)
    t.Input[#joystick] = 0
  end if
  t.Input[#forward] = 0
  t.Input[#backward] = 0
  t.Input[#left] = 0
  t.Input[#right] = 0
  t.Input[#brake] = 0
  t.Input[#action1] = 0
  t.Input[#action2] = 0
  t.Input[#backwardCam] = 0
end

on update_joyInput me, t
  if gGame.Input = 0 then
    exit
  end if
  gGame.joystick.useJoy(t.Input.JoyNr)
  t.Input.forward = gGame.joystick.button(2)
  t.Input.backward = gGame.joystick.button(4)
  if gGame.joystick.xPos() <= (32768 - 4096) then
    tLeft = 1
  else
    tLeft = 0
  end if
  t.Input.left = tLeft
  t.Input.leftPerc = (32768.0 - gGame.joystick.xPos()) / 32768.0
  if gGame.joystick.xPos() >= (32768 + 4096) then
    tRight = 1
  else
    tRight = 0
  end if
  t.Input.right = tRight
  t.Input.rightPerc = (gGame.joystick.xPos() - 32768.0) / 32768.0
  t.Input.brake = gGame.joystick.button(6)
  t.Input.action1 = gGame.joystick.button(1)
  t.Input.action2 = gGame.joystick.button(3)
  t.Input.backwardCam = gGame.joystick.button(5)
end

on reset_joyInput me, t
  t.general.States.deleteOne(#update_joyInput)
end

on setup_WayPoints me, t
  nothing()
end

on update_WayPoints me, t
  if voidp(gGame[#WayPointList]) = 1 then
    exit
  end if
  if gGame.WayPointList.count = 0 then
    exit
  end if
  if t.Vehicle.currentRootNr <> t.Vehicle.previousRootNR then
    tWayPointList = gGame.WayPointList[t.Vehicle.currentRootNr].duplicate()
    if t.Vehicle.currentRootNr < gGame.WayPointList.count then
      tList = gGame.WayPointList[t.Vehicle.currentRootNr + 1].duplicate()
      repeat with i in tList
        tWayPointList.add(i)
      end repeat
    end if
    t.Vehicle.previousRootNR = t.Vehicle.currentRootNr
    t.race.WayPointList = tWayPointList
  end if
  tWaypoint = t.race.waypoint
  tPreviousD = 250.0
  tCarPos = t.Vehicle.model.worldPosition
  repeat with i in t.race.WayPointList
    TD = i.position.distanceTo(tCarPos)
    if TD < tPreviousD then
      t.race.waypoint = t.race.WayPointList.getPos(i)
      t.race.WaypointDistance = TD
      t.race.WaypointT = i
      tPreviousD = TD
    end if
  end repeat
  tTotalWaypoints = 0
  repeat with i = 1 to t.Vehicle.currentRootNr - 1
    tTotalWaypoints = tTotalWaypoints + gGame.WayPointList[i].count
  end repeat
  t.race.Waypoints = tTotalWaypoints + t.race.waypoint
  tTarget = t.race.waypoint + 1
  if tTarget > t.race.WayPointList.count then
    tTarget = t.race.WayPointList.count
  end if
  tTransform = t.race.WayPointList[tTarget].duplicate()
  tIntList = LineLineIntersect(0, t.Vehicle.transform.duplicate(), tTransform, tTransform.yAxis, #x)
  tVector = vector(tIntList[1], tIntList[2], tTransform.position.z)
  t.race.perpVector = tVector
  t.race.perpDistance = (t.Vehicle.model.worldPosition - tVector).length
  tNewT = tTransform.duplicate()
  tNewT.position = tVector
  tLeftRight = LeftOrRight(0, tTransform, tNewT)
  if tLeftRight[1] = 0 then
    t.race.perpOffSet = -tVector.distanceTo(tTransform.position)
  else
    t.race.perpOffSet = tVector.distanceTo(tTransform.position)
  end if
  if voidp(gGame[#CheckPoints]) = 0 then
    tSymbol = symbol("TrackRoot" & t.Vehicle.currentRootNr)
    if voidp(gGame.CheckPoints[tSymbol]) = 0 then
      tList = gGame.CheckPoints[tSymbol]
      repeat with i in tList
        tTransform1 = i.transform.duplicate()
        tTransform2 = t.Vehicle.previousT.duplicate()
        tAxis = tTransform2.position - t.Vehicle.Proxy.worldPosition
        tAxis.normalize()
        tIntList = LineLineIntersect(0, tTransform1, tTransform2, #x, tAxis)
        pPoint1 = point(t.Vehicle.previousT.position.x, t.Vehicle.previousT.position.y)
        pPoint2 = point(t.Vehicle.Proxy.getWorldTransform().position.x, t.Vehicle.Proxy.getWorldTransform().position.y)
        pXList = [tIntList[1], pPoint1.locH, pPoint2.locH]
        pYList = [tIntList[2], pPoint1.locV, pPoint2.locV]
        pXList.sort()
        pYList.sort()
        if (pXList[2] = tIntList[1]) or (pYList[2] = tIntList[2]) then
          gGame[#CurrentVehicle] = t.general.tag
          gGame[#currentController] = t.general.controller
          event(0, string(i.type) & "Line")
        end if
      end repeat
    end if
  end if
  tZDistance = abs(t.race.WayPointList[t.race.waypoint].position.z - tCarPos.z)
  if tCarPos.z < t.race.WayPointList[t.race.waypoint].position.z then
    tZDistance = -tZDistance
  end if
  t.race.waypointZ = tZDistance
end

on reset_waypoints me, t
  t.general.States.deleteOne(#update_WayPoints)
end

on setup_items me, t
  tPos = t.general.States.getPos(#update_items)
  if gGame.Scene = "Track" then
    t.general.States[tPos] = #update_itemsTrack
    t.general.origStates[tPos] = #update_itemsTrack
  end if
  if gGame.Scene = "World" then
    t.general.States[tPos] = #update_itemsWorld
    t.general.origStates[tPos] = #update_itemsWorld
  end if
  gGame[#ItemModel] = #none
end

on update_itemsTrack me, t
  tCurrentTile = t.Vehicle.currentRootNr
  tItemList = gGame.member.group("TrackRoot" & tCurrentTile).userData.Pickups
  tList = []
  the itemDelimiter = "_"
  tCarPos = t.Vehicle.transform.position
  tCamPos = gGame.camera[1].transform.position
  repeat with i in tItemList
    i.pointAt(tCamPos, vector(0, 0, 1))
    tDistance = i.worldPosition.distanceTo(tCarPos)
    if tDistance < 3.0 then
      gGame.CurrentVehicle = t.general.tag
      gGame.ItemModel = i
      event(0, symbol(i.name.item[2]))
      tList.add(i)
    end if
  end repeat
  repeat with i in tList
    tName = i.name
    tItemList.deleteOne(i)
    gGame.member.deleteModel(tName)
  end repeat
  the itemDelimiter = TAB
  if tCurrentTile < gGame.RootList.count then
    tNextTile = tCurrentTile + 1
    tItemList = gGame.member.group("TrackRoot" & tNextTile).userData.Pickups
    repeat with i in tItemList
      i.pointAt(tCamPos, vector(0, 0, 1))
    end repeat
  end if
end

on update_itemsWorld me, t
  tmember = t.general.member
  tCarPos = t.Vehicle.transform.position
  tCamPos = gGame.camera[1].transform.position
  if tmember.group(gGame.grid.center[1] & "_Pickups").userData.count = 0 then
    tItemList = []
  else
    tItemList = tmember.group(gGame.grid.center[1] & "_Pickups").userData.Pickups
  end if
  the itemDelimiter = "_"
  repeat with i = tItemList.count down to 1
    tItem = tItemList[i]
    tItem.pointAt(tCamPos, vector(0, 0, 1))
    tDistance = tItem.worldPosition.distanceTo(tCarPos)
    if tDistance < 3.0 then
      if voidp(gGame[#WorldMission]) = 0 then
        if (tItem.name contains "Rampage") or (tItem.name contains "TimeTrial") or (tItem.name contains "Demolition") then
          event(0, #WorldMissionInProgress)
          next repeat
        end if
      end if
      gGame.CurrentVehicle = t.general.tag
      gGame.ItemModel = tItem
      tName = tItem.name.item[3]
      gGame[#CollectedItem] = tName
      if (tName contains "Ticket") and (tName contains "Boss" = 0) and (tName contains "Master" = 0) then
        gGame[#CollectedTicket] = tName
        event(0, #Ticket)
        gGame.deleteProp(#CollectedTicket)
      else
        if tName contains "CashStash" then
          event(0, #CashStash)
        else
          event(0, symbol(tName))
        end if
      end if
      gGame.deleteProp(#CollectedItem)
      tItemList.deleteOne(tItem)
      if (tName contains "Trial") or (tName contains "Rampage") or (tName contains "Demolition") then
        gGame[#StoredMissionItem] = [tItem, tItem.parent]
        tItem.parent = VOID
        next repeat
      end if
      tmember.deleteModel(tItem.name)
    end if
  end repeat
  repeat with i in gGame.grid.innerRing
    tgroup = tmember.group(i & "_Pickups")
    if tgroup = VOID then
      next repeat
    end if
    if tgroup.userData.count = 0 then
      next repeat
    end if
    tItemList = tgroup.userData.Pickups
    repeat with j in tItemList
      j.pointAt(tCamPos, vector(0, 0, 1))
    end repeat
  end repeat
end

on reset_items me, t
  if t.general.States.getPos(#update_itemsTrack) <> 0 then
    t.general.States.deleteOne(#update_itemsTrack)
  end if
  if t.general.States.getPos(#update_itemsWorld) <> 0 then
    t.general.States.deleteOne(#update_itemsWorld)
  end if
end

on setup_Markers me, t
  t.race[#InsideMarker] = 0
end

on update_Markers me, t
  tmember = t.general.member
  tPlayerPos = t.Vehicle.model.worldPosition
  tCount = gGame.MiniMap.markerlist.count
  repeat with i = 1 to tCount
    tEntry = gGame.MiniMap.markerlist[i]
    tLength = tEntry.model.worldPosition.distanceTo(tPlayerPos)
    if tEntry.Active = 1 then
      if tLength <= tEntry.distance[1] then
        if t.race.InsideMarker = 1 then
          exit repeat
        else
          t.race.InsideMarker = 1
          tEntry.model.removeFromWorld()
          gGame[#HoldPosition] = tEntry.position
          gGame[#CurrentMarker] = tEntry.name
          if gGame.CurrentMarker contains "TimeTrial" then
            event(0, #NextMarkerTimeTrial)
          else
            if gGame.CurrentMarker contains "Demolition" then
              event(0, #NextMarkerDemolition)
            else
              event(0, "Setup" & tEntry.type)
            end if
          end if
          if string(tEntry.type) contains "Entrance" then
            return 1
          else
            if string(tEntry.type) contains "SafeHouse" then
              return 1
            else
              if string(tEntry.type) contains "Car" then
                return 1
              else
                if string(tEntry.type) contains "Boat" then
                  return 1
                else
                  exit repeat
                end if
              end if
            end if
          end if
        end if
      else
        if (tLength > tEntry.distance[2]) and (tEntry.model.parent = VOID) then
          tEntry.model.addToWorld()
        end if
        if i = tCount then
          t.race.InsideMarker = 0
        end if
      end if
      next repeat
    end if
    if (tLength > tEntry.distance[2]) and (tEntry.model.parent = VOID) then
      tEntry.model.addToWorld()
      tEntry.Active = 1
    end if
    if i = tCount then
      t.race.InsideMarker = 0
    end if
  end repeat
end

on reset_Markers me, t
  put "--> Reset Marker (Handler)"
  t.general.States.deleteOne(#update_Markers)
end

on setup_Damage me, t
  t.Vehicle[#Health] = t.general.data.personality.Health
  t.Vehicle[#HealthStates] = [t.Vehicle.Health * 0.29999999999999999, t.Vehicle.Health * 0.59999999999999998]
  t.Vehicle[#damageState] = 0
  t.Vehicle[#impacts] = []
  t.Vehicle[#previousMomentum] = vector()
end

on update_Damage me, t
  tList = t.Vehicle.impacts.duplicate()
  tEnemy = #none
  repeat with i in tList
    t.Vehicle.Health = t.Vehicle.Health - i[1]
    if i.count = 3 then
      tEnemy = i[3]
    end if
  end repeat
  t.Vehicle.impacts = []
  if t.Vehicle.Health <= 0 then
    if string(tEnemy) contains "player" then
      gGame.SWGameTrophies.carsTotalled = gGame.SWGameTrophies.carsTotalled + 1
      gGame.UPStatistics.enemiesWrecked = gGame.UPStatistics.enemiesWrecked + 1
    end if
    if t.general.controller = #player then
      gGame.SWGameTrophies.CarsWrecked = gGame.SWGameTrophies.CarsWrecked + 1
      gGame.UPStatistics.CarsWrecked = gGame.UPStatistics.CarsWrecked + 1
    end if
    PlaySound(0, "ExplosionLarge_SFX", [#priority: #high, #surround: 1, #member3DName: gGame.member.name, #sender: t.Vehicle.Proxy.name, #targetName: t.Vehicle.Proxy.name, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 0])
    t.Vehicle.model.visibility = #both
    pRandomVector = randomVector()
    tImp = vector(pRandomVector.x * 1000, pRandomVector.y * 1000, 45000.0)
    tTorque = vector(pRandomVector.x * 450000, pRandomVector.y * 450000, pRandomVector.z * 550000)
    tImp2 = vector(pRandomVector.x * 70, pRandomVector.y * 70, 500.0)
    tTorque2 = vector(pRandomVector.x * 250, pRandomVector.y * 250, pRandomVector.z * 250)
    t.Vehicle.RigidBody.applyLinearImpulse(tImp)
    t.Vehicle.RigidBody.applyTorque(tTorque)
    if t.Vehicle[#wheellist] <> VOID then
      ExplodeModelList(0, t.Vehicle.wheellist, t.Vehicle.RigidBody.linearVelocity * 0.69999999999999996, tImp2, tTorque2)
    end if
    tList = []
    if t.Vehicle.glassModel <> #none then
      tList.add(t.Vehicle.glassModel)
    end if
    repeat with i in t.Weapons
      if i.ilk <> #propList then
        next repeat
      end if
      if i.getaProp(#models) <> VOID then
        if i.models = #none then
          next repeat
        end if
        repeat with j in i.models
          tList.add(j)
        end repeat
      end if
    end repeat
    ExplodeModelList(0, tList, t.Vehicle.RigidBody.linearVelocity * 0.69999999999999996, tImp2, tTorque2)
    repeat with i in t.Vehicle.lightModels
      i.parent = VOID
    end repeat
    repeat with i in t.Vehicle.nitroModels
      i.parent = VOID
    end repeat
    if t.Vehicle[#smoke] <> VOID then
      tResourceName = t.Vehicle.smoke.resource.name
      tName = t.Vehicle.smoke.name
      gGame.member.deleteModel(tName)
      gGame.member.deleteModelResource(tResourceName)
      t.Vehicle.deleteProp(#smoke)
    end if
    t.Vehicle.shadowmodel.parent = VOID
    if t.general.controller = #player then
      UPdateSWTrophyExplosion()
    end if
    tExploScript = new(script("[PS] ExplosionCar"), gGame.member, #none, gGame.member.camera("PLayer1_camera"), t.Vehicle.model.name, 8000, vector(), t.Vehicle.RigidBody, [])
    if tExploScript <> VOID then
      gGame.scriptList.add(tExploScript)
    end if
    t.Vehicle.Health = 0
    t.race.state = #dead
    if t.general.controller = #player then
      reset_keyInput(0, t, #none)
    else
      reset_AutoRace(0, t, #none)
      reset_AutoFight(0, t, #Racing)
    end if
    update_Weapons(0, t)
    if t.general.controller = #AI then
      gGame.AIsKilled = gGame.AIsKilled + 1
      if gGame.Challenge <> "Destroy" then
        timeout().new(string(t.general.tag) & "RespawnVehicle", 3250, #RespawnVehicleTimeOut, t.general.tag)
      end if
    end if
    if t.general.controller = #player then
      gGame.PlayersKilled = gGame.PlayersKilled + 1
      event(0, "ImpactTimeOn")
      gGame.camera[1].updateStates = 0
      UpdateCameraSet(0, #ExplodingCar)
      timeout().new(string(t.general.tag) & "RespawnVehicle", 5500, #RespawnVehicleTimeOut, t.general.tag)
      DelayEvent(0, EMPTY, [#delay: 5466, #event: gGame.Scene & "FlashFade"])
    end if
  end if
  if t.Vehicle.Health < t.Vehicle.HealthStates.max() then
    if t.Vehicle.Health <= 0 then
      tState = 3
    else
      if t.Vehicle.Health < t.Vehicle.HealthStates.min() then
        tState = 2
      else
        tState = 1
      end if
    end if
    if t.Vehicle.damageState <> tState then
      tTexture = t.Vehicle.model.shader.texture
      tmember = tTexture.member
      tImage = tmember.image.duplicate()
      tImage.copyPixels(member("Damage" & tState & "_Texture").image, tImage.rect, tImage.rect)
      tTexture.image = tImage
      tNormalShader = gGame.member.shader(string(t.general.tag) & "_Material")
      tGlassShader = gGame.member.shader(string(t.general.tag) & "Glass_Material")
      if t.Vehicle.shaderList.getPos(tNormalShader) <> 0 then
        tNormalShader.textureList[2] = VOID
      end if
      if t.Vehicle.shaderList.getPos(tGlassShader) <> 0 then
        tGlassShader.textureList[2] = VOID
      end if
      if tState = 2 then
        t.Vehicle[#smoke] = CreateParticleSystem(0, gGame.member.name, [#type: #EngineSmoke, #NameTag: string(t.general.tag)])
        t.Vehicle[#smoke].resource.colorRange.start = gData.data.ambientStyle[gGame.trackInfo.ambientStyle].lightColor
        t.Vehicle[#smoke].resource.colorRange.end = gData.data.ambientStyle[gGame.trackInfo.ambientStyle].lightColor
      end if
      if tState = 1 then
        if voidp(t.Vehicle[#smoke]) = 0 then
          if t.Vehicle[#smoke] <> VOID then
            tResourceName = t.Vehicle.smoke.resource.name
            tName = t.Vehicle.smoke.name
            gGame.member.deleteModel(tName)
            gGame.member.deleteModelResource(tResourceName)
            t.Vehicle.deleteProp(#smoke)
          end if
        end if
      end if
      t.Vehicle.damageState = tState
      if tState = 1 then
        PlaySound(0, "Crash", [#priority: #medium, #surround: 1, #member3DName: gGame.member.name, #random: [1, 3], #sender: t.Vehicle.model.name, #targetName: t.Vehicle.model.name, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 1])
      end if
      if tState = 2 then
        PlaySound(0, "Crash", [#priority: #medium, #surround: 1, #member3DName: gGame.member.name, #random: [1, 3], #sender: t.Vehicle.model.name, #targetName: t.Vehicle.model.name, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 1])
        PlaySound(0, "CrashGlass", [#priority: #low, #surround: 1, #member3DName: gGame.member.name, #rateShift: random(-4, 4), #sender: t.Vehicle.model.name, #targetName: t.Vehicle.model.name, #referenceName: "Player1_Camera", #distance: [20, 100], #static: 1])
      end if
    end if
    if tState = 2 then
      t.Vehicle.smoke.resource.emitter.region = [t.Vehicle.Effects.smoke[1].getWorldTransform().position]
    end if
  else
    if t.Vehicle.damageState <> 0 then
      tTexture = t.Vehicle.model.shader.texture
      tmember = tTexture.member
      tImage = tmember.image.duplicate()
      tOrigMember = member(t.Vehicle.name & "Skin" & t.general.data.skin & "_Texture")
      tImage.copyPixels(tOrigMember.image, tImage.rect, tImage.rect)
      tTexture.image = tImage
      tNormalShader = gGame.member.shader(string(t.general.tag) & "_Material")
      tGlassShader = gGame.member.shader(string(t.general.tag) & "Glass_Material")
      tTexture = string(t.general.controller) & string(t.general.player) & "Reflection_Texture"
      if t.Vehicle.shaderList.getPos(tNormalShader) <> 0 then
        tNormalShader.textureList[2] = gGame.member.texture(tTexture)
      end if
      if t.Vehicle.shaderList.getPos(tGlassShader) <> 0 then
        tGlassShader.textureList[2] = gGame.member.texture(tTexture)
      end if
      if t.Vehicle[#smoke] <> VOID then
        tResourceName = t.Vehicle.smoke.resource.name
        tName = t.Vehicle.smoke.name
        gGame.member.deleteModel(tName)
        gGame.member.deleteModelResource(tResourceName)
        t.Vehicle.deleteProp(#smoke)
      end if
      t.Vehicle.damageState = 0
    end if
  end if
  if (t.Vehicle.Health <= 0) and (tState = 3) then
    return 1
  end if
end

on reset_Damage me, t
  if t.Vehicle[#smoke] <> VOID then
    tResourceName = t.Vehicle.smoke.resource.name
    tName = t.Vehicle.smoke.name
    gGame.member.deleteModel(tName)
    gGame.member.deleteModelResource(tResourceName)
    t.Vehicle.deleteProp(#smoke)
  end if
  t.general.States.deleteOne(#update_Damage)
end

on ExplodeModelList me, tList, tLinVel, tImp2, tTorque2
  repeat with i in tList
    tTransform = i.getWorldTransform()
    i.parent = gGame.member.group("World")
    i.transform = tTransform
    i.addModifier(#meshDeform)
    tRB = gGame.Physics.createRigidBody(i.name, i.name, #convexShape, #dynamic)
    tRB.restitution = 0.20000000000000001
    tRB.friction = 0.5
    tRB.mass = 20.0
    tRB.linearVelocity = tLinVel
    tRB.applyLinearImpulse(tImp2)
    tRB.applyTorque(tTorque2)
    i.removeModifier(#meshDeform)
  end repeat
end

on setup_LightManager me, t
  t.Vehicle[#imageData] = [#none, #none]
  t.Vehicle[#LMSourceEmissive] = t.Vehicle.model.shader.emissive
  t.Vehicle[#adjColor] = rgb(80, 80, 80)
  t.Vehicle[#LMColor] = rgb(255, 255, 255)
  t.Vehicle[#LMShaderList] = [t.Vehicle.model.shader]
  if t.Vehicle.glassModel <> #none then
    t.Vehicle.LMShaderList.append(t.Vehicle.glassModel.shader)
  end if
  t.Vehicle[#ambientColor] = rgb(0, 0, 0)
  t.Vehicle[#AmbientEmissive] = gData.data.ambientStyle[gGame.trackInfo.ambientStyle].ambientColor
  if gGame.setting = "Night" then
    t.Vehicle.ambientColor = rgb(255, 255, 255)
  end if
  if voidp(t.Vehicle[#wheellist]) = 0 then
    if t.Vehicle.wheellist.count > 0 then
      t.Vehicle.LMShaderList.append(t.Vehicle.wheellist[1].shader)
    end if
  end if
  repeat with aShader in t.Vehicle.weaponShaders
    t.Vehicle.LMShaderList.append(aShader)
  end repeat
end

on update_LightManager me, t
  tColor = rgb(255, 255, 255)
  if gGame.Effects <> #low then
    tDetails = t.Vehicle.intersectDetails
    if tDetails.count > 0 then
      tmodel = tDetails[1]
      if voidp(tmodel.userData[#FaceList2]) = 0 then
        tTexture = t.Vehicle.ISectShader.textureList[2]
        if tTexture <> VOID then
          if t.Vehicle.imageData[1] <> tTexture.name then
            tmember = tTexture.member
            t.Vehicle.imageData[2] = tmember.image
          end if
          tFace = tDetails[#faceID]
          tUVCoord = tDetails[#uvCoord]
          tUD = tmodel.userData
          tCoordList = tUD[#CoordList2]
          if tFace <= tUD[#FaceList2].count then
            tFaceList = tUD[#FaceList2][tFace]
            tLocA = tCoordList[tFaceList[1]]
            tLocA = point(tLocA[1] * tTexture.width, (1 - tLocA[2]) * tTexture.height)
            tLocB = tCoordList[tFaceList[2]]
            tLocB = point(tLocB[1] * tTexture.width, (1 - tLocB[2]) * tTexture.height)
            tLocC = tCoordList[tFaceList[3]]
            tLocC = point(tLocC[1] * tTexture.width, (1 - tLocC[2]) * tTexture.height)
            tUVector = (tLocB - tLocA) * tUVCoord.u
            tVVector = (tLocC - tLocA) * tUVCoord.V
            tPos = tLocA + tUVector + tVVector
            if tPos = 0 then
              tColor = rgb(255, 255, 255)
            else
              tColor = t.Vehicle.imageData[2].getPixel(tPos)
            end if
            if tColor = 0 then
              tColor = rgb(255, 255, 255)
            end if
            repeat with i in t.Vehicle.LMShaderList
              if i = VOID then
                next repeat
              end if
              i.ambient = t.Vehicle.ambientColor
              i.specular = tColor + rgb(32, 32, 32)
              if gGame.setting = "Day" then
                i.emissive = tColor
              end if
              i.diffuse = tColor
            end repeat
            t.Vehicle.LMColor = tColor
          end if
        end if
      end if
    end if
  end if
end

on reset_LightManager me, t
  t.general.States.deleteOne(#update_LightManager)
end

on setup_Weapons me, t
  event(0, #SetupWeapons)
  event(0, "Setup3DParticles")
  CloneModel(0, t.general.member.name, [#sourceMember: "Particles", #hide: 1, #delete: 1])
  BlendShader(0, t.general.member.name, [#shader: "ParticleExplosion1_Material", #blendMode: #add])
  tmember = t.general.member
  tShader = tmember.shader("Effects_Material")
  if tShader <> VOID then
    if tShader.textureList[1].name = "DefaultTexture" then
      tShader.textureList[1] = tmember.texture("Effects_Texture")
      BlendShader(0, tmember, [#shader: "Effects_Material", #blendMode: #add])
      put "------------------------------------FIXING THE EFFECTS TEXTURE ISSUE"
    end if
  end if
  if (t.general.controller = #player) and (gGame[symbol("playerWeapons" & t.general.player)] = 0) then
    t.general.States.deleteOne(#update_Weapons)
  else
    if (t.general.controller = #AI) and (gGame.AIWeapons = 0) then
      t.general.States.deleteOne(#update_Weapons)
    else
      t[#Weapons] = [:]
      t.Vehicle[#weaponShaders] = []
      t.Weapons[#States] = []
      repeat with i in t.general.data.Weapons
        if i = "None" then
          next repeat
        end if
        t.Weapons.States.add(symbol("update_" & i))
        case i of
          "MachineGun":
            setup_machinegun(0, t)
          "DualMachineGun":
            setup_dualMachinegun(0, t)
          "MiniGun":
            setup_minigun(0, t)
          "DualMiniGun":
            Setup_DualMiniGun(0, t)
          "Laser":
            Setup_Laser(0, t)
          "RocketPod":
            Setup_RocketPod(0, t)
          "MineDeployer":
            setup_MineDeployer(0, t)
          "GrenadeDeployer":
            setup_GrenadeDeployer(0, t)
          "GrenadeLauncher":
            setup_GrenadeLauncher(0, t)
          "AirstrikeLauncher":
            setup_airstrikeLauncher(0, t)
          "FlameThrower":
            Setup_FlameThrower(0, t)
          "NitroBoost":
            setup_NitroBoost(0, t)
          "MainGun":
            Setup_MainGun(0, t)
          "AC130AutoGun1":
            Setup_AC130AutoGun1(0, t)
          "AC130AutoGun2":
            Setup_AC130AutoGun2(0, t)
        end case
      end repeat
    end if
  end if
end

on update_Weapons me, t
  if (t.general.controller = #player) and (gGame[symbol("playerWeaponsActive" & t.general.player)] = 0) then
    return 0
  end if
  if (t.general.controller = #AI) and (gGame.AIWeaponsActive = 0) then
    return 0
  end if
  repeat with i in t.Weapons.States
    sendSprite(0, i, t)
  end repeat
end

on reset_Weapons me, t
  tList = t.Weapons.States.duplicate()
  the itemDelimiter = "_"
  repeat with i in tList
    tString = string(i)
    tHandler = symbol("reset_" & tString.item[2])
    sendSprite(0, tHandler, t)
  end repeat
  t.general.States.deleteOne(#update_Weapons)
end

on setup_HoldToPin me, t
  if (t.Vehicle.name = "Spitfire") or (t.Vehicle.name = "F22") or (t.Vehicle.name = "Apache") or (t.Vehicle.name = "AC130") then
    return 0
  end if
  t.general.States.add(#update_HoldToPin)
end

on update_HoldToPin me, t
  t.Input.forward = 0
  t.Input.backward = 0
  if t.Vehicle.Speed > 0 then
    t.Input.backward = 1
  end if
  if t.Vehicle.Speed < 0 then
    t.Input.forward = 1
  end if
  if (t.Vehicle.Speed > -0.29999999999999999) and (t.Vehicle.Speed < 0.29999999999999999) then
    reset_HoldToPin(0, t)
  end if
end

on reset_HoldToPin me, t
  t.Input.forward = 0
  t.Input.backward = 0
  t.Vehicle.RigidBody.isPinned = 1
  t.general.States.deleteOne(#update_HoldToPin)
end

on setup_Helpers me, t
  tTag = t.general.tag
  tmember = t.general.member
  if gGame[#ProxyShader] = VOID then
    CreateProxyShader(tmember)
  end if
  theModelResource = tmember.newModelResource(tTag & "LeaderSphere", #sphere)
  theModelResource.radius = 0.5
  tLeaderPoint = tmember.newModel(tTag & "LeaderSphere", theModelResource)
  tLeaderPoint.shader = gGame.ProxyShader
  tLeaderArrow = CloneModel(0, tmember, [#sourceMember: "LeaderHelper", #model: "LeaderHelper", #NameTag: tTag & "Leader"])
  tLeaderArrow.shader = gGame.ProxyShader
  theModelResource = tmember.newModelResource(tTag & "LeaderCyl1", #cylinder)
  theModelResource.topRadius = 0.10000000000000001
  theModelResource.bottomRadius = 0.10000000000000001
  theModelResource.height = 100.0
  tLeaderCyl1 = tmember.newModel(tTag & "LeaderCyl1", theModelResource)
  tLeaderCyl1.pointAtOrientation = [vector(0.0, 1.0, 0.0), vector(0.0, 0.0, 1.0)]
  theModelResource = tmember.newModelResource(tTag & "LeaderCyl2", #cylinder)
  theModelResource.topRadius = 0.10000000000000001
  theModelResource.bottomRadius = 0.10000000000000001
  theModelResource.height = 100.0
  tLeaderCyl2 = tmember.newModel(tTag & "LeaderCyl2", theModelResource)
  tLeaderCyl2.pointAtOrientation = [vector(0.0, 1.0, 0.0), vector(0.0, 0.0, 1.0)]
  tLeaderCyl1.shader = gGame.ProxyShader
  tLeaderCyl2.shader = gGame.ProxyShader
  t[#Helpers] = [:]
  t[#Helpers][#LeaderPoint] = tLeaderPoint
  t[#Helpers][#LeaderArrow] = tLeaderArrow
  t[#Helpers][#LeaderCyl1] = tLeaderCyl1
  t[#Helpers][#LeaderCyl2] = tLeaderCyl2
end

on update_Helpers me, t
  t.Helpers.LeaderPoint.transform.position = t.race.WaypointT.position
  t.Helpers.LeaderArrow.transform = t.race.Leader.transform
  t.Helpers.LeaderArrow.transform.position = t.Helpers.LeaderArrow.transform.position + vector(0.0, 0.0, 1.5)
  t.Helpers.LeaderCyl1.transform.position = t.race.perpVector
  t.Helpers.LeaderCyl1.transform.rotation = t.race.WaypointT.rotation
  t.Helpers.LeaderCyl1.rotate(vector(0, 0, 90), #self)
  tResource = t.Helpers.LeaderCyl2.resource
  tResource.height = t.race.perpDistance
  t.Helpers.LeaderCyl2.transform.position = t.Vehicle.model.worldPosition
  if t.race.perpVector <> vector() then
    t.Helpers.LeaderCyl2.pointAt(t.race.perpVector, vector(0, 0, 1))
  end if
  t.Helpers.LeaderCyl2.translate(0, t.race.perpDistance * 0.5, 0, #self)
end

on reset_helpers me, t
  t.general.States.deleteOne(#update_Helpers)
end
