-- [Script] [M] Vehicle Plane States (Script #5875)
-- Script Type: Movie

global gSystem, gData, gGame, gSound

on setup_planeEffects me, t
end

on update_planeEffects me, t
end

on reset_planeEffects me, t
  t.general.States.deleteOne(#update_planeEffects)
end

on setup_PlaneSound me, t
  t[#sound] = [:]
  t.sound[#Mixer] = CreateMixer()
  t.sound.Mixer.bufferSize = 80
  t.sound[#channel] = gSound.DataSoundChannels.count + 1
  t.sound[#rate] = 1.0
  if t.Vehicle.name = "F22" then
    tSFX = "F22Engine_SFX"
  end if
  if t.Vehicle.name = "Spitfire" then
    tSFX = "SpitfireEngine_SFX"
  end if
  t.sound[#engine] = t.sound.Mixer.createSoundObject(tSFX, member(tSFX), [#loopCount: 0])
  t.sound.engine.volume = 0
  t.sound[#filter] = audioFilter(#PitchShiftFilter, [#Shift: t.sound.rate])
  t.sound.engine.filterList.append(t.sound.filter)
  t.sound.Mixer.play()
  if gSound.mute = 1 then
    t.sound.Mixer.mute()
    repeat with i in t.sound.Mixer.getSoundObjectList()
      i.mute()
    end repeat
  end if
  sound(t.sound.channel).volume = 255
end

on update_PlaneSound me, t
  if gSound.mute = 1 then
    return 0
  end if
  tDistance = t.camera.distanceToTarget[t.camera.index]
  tLeft = LeftOrRight(0, t.Vehicle.transform, gGame.camera[t.camera.index].transform)
  tPan = tLeft[2]
  tPan = max(-1.0, min(1.0, tPan))
  sound(t.sound.channel).pan = tPan
  if tDistance < 10.0 then
    tVolume = 255
  else
    tVolume = 255 - integer(255 * tDistance / 100.0)
    tVolume = max(0, min(255, tVolume))
  end if
  if sound(t.sound.channel).volume <> tVolume then
    sound(t.sound.channel).volume = tVolume
  end if
  if t.sound.engine.volume <> 100 then
    t.sound.engine.volume = 100
  end if
  tRate = max(1.0, t.Vehicle.SpeedPerc * 2.5)
  if t.sound.filter.Shift <> tRate then
    t.sound.filter.Shift = tRate
  end if
end

on reset_PlaneSound me, t
  t.sound.Mixer.mute()
  repeat with i in t.sound.Mixer.getSoundObjectList()
    i.mute()
  end repeat
  t.general.States.deleteOne(#update_PlaneSound)
end

on setup_PlaneSoundAI me, t
end

on update_PlaneSoundAI me, t
end

on reset_PlaneSoundAI me, t
  t.general.States.deleteOne(#update_PlaneSoundAI)
end

on setup_AutoFly me, t
  tCount = gGame.PlayerKeys1.count
  repeat with i = 1 to tCount
    tProp = gGame.PlayerKeys1.getPropAt(i)
    t.Input[tProp] = 0
  end repeat
  if t.Vehicle.name = "Spitfire" then
    t.Vehicle.maxSpeed = 20.0 + (9.0 * gGame.AIsBuild)
  end if
  if t.Vehicle.name = "AC130" then
    t.Vehicle.maxSpeed = 30.0
  end if
  t.Vehicle[#RayCounter] = [0, 3]
  if t.Vehicle.name = "Spitfire" then
    t.Vehicle[#range] = t.Vehicle.model.boundingSphere[2] * 5.0
  end if
  if t.Vehicle.name = "AC130" then
    t.Vehicle[#range] = t.Vehicle.model.boundingSphere[2] * 3.0
  end if
end

on update_AutoFly me, t
  t.Vehicle.RayCounter[1] = t.Vehicle.RayCounter[1] + 1
  if t.Vehicle.RayCounter[1] > t.Vehicle.RayCounter[2] then
    t.Vehicle.RayCounter[1] = 1
  end if
  tCount = t.Vehicle.RayCounter[1]
  tTransform = t.Vehicle.model.getWorldTransform()
  tRange = t.Vehicle.range
  if tCount = 1 then
    t.Input.left = 0
    tDetails = gGame.Physics.rayCastClosest(tTransform.position, vector(1.00009999999999999, 0.0001, 0.0001))
    if tDetails.count > 0 then
      if tDetails[4] <= tRange then
        t.Input.left = 1
      end if
    end if
  end if
  if tCount = 2 then
    t.Input.right = 0
    tDetails = gGame.Physics.rayCastClosest(tTransform.position, vector(-1.00009999999999999, 0.0001, 0.0001))
    if tDetails.count > 0 then
      if tDetails[4] <= tRange then
        t.Input.right = 1
      end if
    end if
  end if
  if tCount = 3 then
    t.Input.backward = 0
    tDetails = gGame.Physics.rayCastClosest(tTransform.position, vector(0.0001, 1.00009999999999999, 0.0001))
    if tDetails.count > 0 then
      if tDetails[4] <= tRange then
        t.Input.backward = 1
      end if
    end if
  end if
end

on reset_AutoFly me, t
end

on setup_flying me, t
  if t.general.controller = #AI then
    tCount = gGame.PlayerKeys1.count
    repeat with i = 1 to tCount
      tProp = gGame.PlayerKeys1.getPropAt(i)
      t.Input[tProp] = 0
    end repeat
  end if
  t.Vehicle[#rightSpeed] = [0, 1]
  t.Vehicle[#leftSpeed] = [0, 1]
  t.Vehicle[#upSpeed] = [0, 1]
  t.Vehicle[#downSpeed] = [0, 1]
  t.Vehicle[#acc] = 0.10000000000000001
  t.Vehicle[#drag] = 0.90000000000000002
  t.Vehicle[#flySpeed] = [0.10000000000000001, 1.0]
  t.Vehicle[#maxOffsetH] = 100.0
  t.Vehicle[#maxOffsetV] = 60.0
  if t.Vehicle.name = "Apache" then
    t.Vehicle[#slideOffsetH] = 0.29999999999999999
    t.Vehicle[#slideOffsetV] = 0.14999999999999999
    t.Vehicle[#slideOffsetZ] = 3.0
    tModelList = CloneModel(0, t.general.member, [#sourceMember: t.Vehicle.name, #model: ["ApacheTopRotor", "ApacheBackRotor"], #NameTag: string(t.general.tag)])
    tTexture = t.general.member.texture("ApacheRotor_Texture")
    if tTexture = VOID then
      tTexture = createTexture(0, t.general.member.name, [#texture: "ApacheRotor_Texture", #renderFormat: #rgba8888])
    end if
    repeat with i in tModelList
      i.parent = t.Vehicle.model
      i.transform.position = vector()
      i.transform.position = member("Apache").model(i.resource.name).worldPosition - member("Apache").model("Apache").worldPosition
      i.shader.texture = tTexture
    end repeat
    t.Vehicle[#rotorList] = tModelList
  end if
  if t.Vehicle.name = "Spitfire" then
    t.Vehicle[#slideOffsetH] = 3.0
    t.Vehicle[#slideOffsetV] = 0.34999999999999998
    t.Vehicle[#slideOffsetZ] = 3.0
    t.Vehicle[#flySpeed] = [0.10000000000000001, 1.30000000000000004]
    tModelList = CloneModel(0, t.general.member, [#sourceMember: t.Vehicle.name, #model: ["SpitfireRotor"], #NameTag: string(t.general.tag)])
    if tModelList.ilk <> #list then
      tModelList = [tModelList]
    end if
    tTexture = t.general.member.texture("SpitfireRotor_Texture")
    if tTexture = VOID then
      tTexture = createTexture(0, t.general.member.name, [#texture: "SpitfireRotor_Texture", #renderFormat: #rgba8888])
    end if
    repeat with i in tModelList
      i.parent = t.Vehicle.model
      i.transform.position = vector()
      i.transform.position = member("Spitfire").model(i.resource.name).worldPosition - member("Spitfire").model("Spitfire").worldPosition
      i.shader.texture = tTexture
    end repeat
    t.Vehicle[#rotorList] = tModelList
    if t.general.controller = #AI then
      t.Vehicle[#spitFireOffsets] = [3.0 * gGame.vehicles.count, 1.5 * gGame.vehicles.count]
      tPos = t.general.States.getPos(#update_flying)
      t.general.States.deleteOne(#update_flying)
      t.general.origStates.deleteOne(#update_flying)
      t.general.States.addAt(tPos, #update_flyingSpitfire)
      t.general.origStates.addAt(tPos, #update_flyingSpitfire)
    end if
  end if
  if t.Vehicle.name = "F22" then
    t.Vehicle[#slideOffsetH] = 3.0
    t.Vehicle[#slideOffsetV] = 0.29999999999999999
    t.Vehicle[#slideOffsetZ] = 3.0
    tModelList = CloneModel(0, t.general.member, [#sourceMember: t.Vehicle.name, #model: ["F22Engine1", "F22Engine2"], #NameTag: string(t.general.tag)])
    if tModelList.ilk <> #list then
      tModelList = [tModelList]
    end if
    tTexture = t.general.member.texture("F22Engine_Texture")
    if tTexture = VOID then
      tTexture = createTexture(0, t.general.member.name, [#texture: "F22Engine_Texture", #renderFormat: #rgba8888])
      t.general.member.shader("F22Engine_Material").texture = tTexture
      BlendShader(0, t.general.member.name, [#shader: "F22Engine_Material", #blendMode: #add])
    end if
    repeat with i in tModelList
      i.parent = t.Vehicle.model
      i.transform.position = vector()
      i.transform.position = member("F22").model(i.resource.name).worldPosition - member("F22").model("F22").worldPosition
    end repeat
    t.Vehicle[#engineList] = tModelList
  end if
  if t.Vehicle.name = "AC130" then
    t.Vehicle[#slideOffsetH] = 3.0
    t.Vehicle[#slideOffsetV] = 0.29999999999999999
    t.Vehicle[#slideOffsetZ] = 3.0
    tModelList = CloneModel(0, t.general.member, [#sourceMember: t.Vehicle.name, #model: ["AC130Rotor1", "AC130Rotor2", "AC130Rotor3", "AC130Rotor4"], #NameTag: string(t.general.tag)])
    if tModelList.ilk <> #list then
      tModelList = [tModelList]
    end if
    tTexture = t.general.member.texture("AC130Rotor_Texture")
    if tTexture = VOID then
      tTexture = createTexture(0, t.general.member.name, [#texture: "AC130Rotor_Texture", #renderFormat: #rgba8888])
    end if
    repeat with i in tModelList
      i.parent = t.Vehicle.model
      i.transform.position = vector()
      i.transform.position = member("AC130").model(i.resource.name).worldPosition - member("AC130").model("AC130").worldPosition
      i.shader.texture = tTexture
    end repeat
    t.Vehicle[#rotorList] = tModelList
    tPos = t.general.States.getPos(#update_flying)
    t.general.States.deleteOne(#update_flying)
    t.general.origStates.deleteOne(#update_flying)
    t.general.States.addAt(tPos, #update_FlyingAC130)
    t.general.origStates.addAt(tPos, #update_FlyingAC130)
    Setup_AC130AutoGun1(0, t)
    Setup_AC130AutoGun2(0, t)
  end if
  if gGame.PlaneHelpers = 1 then
    tResource = t.general.member.newModelResource("FLyHelper1", #cylinder)
    tResource.topRadius = 0.10000000000000001
    tResource.bottomRadius = 0.10000000000000001
    t.Vehicle[#flyHelper1] = t.general.member.newModel("FlyHelper1", tResource)
    t.Vehicle[#flyHelper1].pointAtOrientation = [vector(0.0, 1.0, 0.0), vector(0.0, 0.0, 1.0)]
    tResource = t.general.member.newModelResource("FLyHelper2", #cylinder)
    tResource.topRadius = 0.10000000000000001
    tResource.bottomRadius = 0.10000000000000001
    t.Vehicle[#flyHelper2] = t.general.member.newModel("FlyHelper2", tResource)
    t.Vehicle[#flyHelper2].pointAtOrientation = [vector(0.0, 1.0, 0.0), vector(0.0, 0.0, 1.0)]
    tResource = t.general.member.newModelResource("FLyHelper3", #cylinder)
    tResource.topRadius = 0.10000000000000001
    tResource.bottomRadius = 0.10000000000000001
    t.Vehicle[#flyHelper3] = t.general.member.newModel("FlyHelper3", tResource)
    t.Vehicle[#flyHelper3].pointAtOrientation = [vector(0.0, 1.0, 0.0), vector(0.0, 0.0, 1.0)]
    tResource = t.general.member.newModelResource("FLyHelper4", #cylinder)
    tResource.topRadius = 0.10000000000000001
    tResource.bottomRadius = 0.10000000000000001
    t.Vehicle[#flyHelper4] = t.general.member.newModel("FlyHelper4", tResource)
    t.Vehicle[#flyHelper4].pointAtOrientation = [vector(0.0, 1.0, 0.0), vector(0.0, 0.0, 1.0)]
  end if
end

on update_flying me, t
  if t.Vehicle.Health <= 0 then
    return 0
  end if
  tgroup = t.Vehicle.group
  tTransform = t.Vehicle.group.transform
  t.Vehicle.RigidBody.position = vector()
  tFutOffSet = t.Vehicle.flySpeed[1]
  if (t.Input.brake = 1) and (tFutOffSet > 0) then
    tFutOffSet = max(0.5, tFutOffSet * 0.90000000000000002)
  else
    if tFutOffSet < 0.0 then
      if tFutOffSet < 0.0001 then
        tFutOffSet = 0.0
      end if
      tFutOffSet = tFutOffSet * 0.69999999999999996
    else
      if tFutOffSet < 0.10000000000000001 then
        tFutOffSet = 0.10000000000000001
      end if
      tFutOffSet = min(tFutOffSet * 1.25, t.Vehicle.flySpeed[2])
    end if
  end if
  tIntersectDetails = gGame.Physics.rayCastClosest(tTransform.position, vector(0.0001, 1.00009999999999999, 0.0001))
  if tIntersectDetails.count > 0 then
    tDistance = tIntersectDetails[4]
    if (tDistance < t.Vehicle.slideOffsetZ) and (tFutOffSet < t.Vehicle.slideOffsetZ) then
      tFutOffSet = -t.Vehicle.flySpeed[2]
    else
      if tDistance < tFutOffSet then
        tFutOffSet = -tFutOffSet
      end if
    end if
  end if
  tgroup.transform.position = tgroup.transform.position + (tgroup.transform.yAxis * tFutOffSet)
  t.Vehicle.flySpeed[1] = tFutOffSet
  tCarT = t.Vehicle.model.transform
  tWaypointT = t.race.WayPointList[t.race.waypoint]
  tMaxOffset = [tWaypointT.position.x, tWaypointT.position.z]
  tFutOffSet = t.Vehicle.leftSpeed[1]
  if t.Input.left = 1 then
    t.Vehicle.rightSpeed[1] = 0
    tFutOffSet = tFutOffSet + t.Vehicle.acc
    tFutOffSet = min(tFutOffSet, t.Vehicle.leftSpeed[2])
    if tCarT.rotation.y > -10 then
      tCarT.rotation.y = tCarT.rotation.y - 1.0
    end if
    if tCarT.rotation.z > -5 then
      tCarT.rotation.z = tCarT.rotation.z - 0.5
    end if
  else
    tFutOffSet = tFutOffSet * t.Vehicle.drag
  end if
  if tFutOffSet > 0.0001 then
    tIntersectDetails = gGame.Physics.rayCastClosest(tTransform.position, vector(-1.00009999999999999, 0.0001, 0.0001))
    if tIntersectDetails.count > 0 then
      if gGame.PlaneHelpers = 1 then
        tmodel = t.Vehicle.flyHelper1
        tmodel.parent = t.general.member.group("World")
        tmodel.transform.position = tTransform.position
        tmodel.pointAt(tIntersectDetails[2])
        tmodel.resource.height = tIntersectDetails[4]
        tmodel.translate(0, tIntersectDetails[4] * 0.5, 0, #self)
      end if
      tDistance = tIntersectDetails[4]
      if (tDistance < t.Vehicle.slideOffsetH) and (tFutOffSet < t.Vehicle.slideOffsetH) then
        tFutOffSet = -t.Vehicle.slideOffsetH * 0.5
      else
        if tDistance < tFutOffSet then
          tFutOffSet = -tFutOffSet
        else
          if (tTransform.position.x - tFutOffSet) < (tMaxOffset[1] - t.Vehicle.maxOffsetH) then
            tFutOffSet = -tFutOffSet * 0.5
          end if
        end if
      end if
    else
      if (tTransform.position.x - tFutOffSet) < (tMaxOffset[1] - t.Vehicle.maxOffsetH) then
        tFutOffSet = -tFutOffSet * 0.5
      end if
      if gGame.PlaneHelpers = 1 then
        t.Vehicle.flyHelper1.parent = VOID
      end if
    end if
  end if
  tTransform.position = tTransform.position - (tTransform.xAxis * tFutOffSet)
  t.Vehicle.leftSpeed[1] = tFutOffSet
  tFutOffSet = t.Vehicle.rightSpeed[1]
  if t.Input.right = 1 then
    t.Vehicle.leftSpeed[1] = 0
    tFutOffSet = tFutOffSet + t.Vehicle.acc
    tFutOffSet = min(tFutOffSet, t.Vehicle.rightSpeed[2])
    if tCarT.rotation.y < 10 then
      tCarT.rotation.y = tCarT.rotation.y + 1.0
    end if
    if tCarT.rotation.z < 5 then
      tCarT.rotation.z = tCarT.rotation.z + 0.5
    end if
  else
    tFutOffSet = tFutOffSet * t.Vehicle.drag
  end if
  if tFutOffSet > 0.0001 then
    tIntersectDetails = gGame.Physics.rayCastClosest(tTransform.position, vector(1.00009999999999999, 0.0001, 0.0001))
    if tIntersectDetails.count > 0 then
      if gGame.PlaneHelpers = 1 then
        tmodel = t.Vehicle.flyHelper2
        tmodel.parent = t.general.member.group("World")
        tmodel.transform.position = tTransform.position
        tmodel.pointAt(tIntersectDetails[2])
        tmodel.resource.height = tIntersectDetails[4]
        tmodel.translate(0, tIntersectDetails[4] * 0.5, 0, #self)
      end if
      tDistance = tIntersectDetails[4]
      if (tDistance < t.Vehicle.slideOffsetH) and (tFutOffSet < t.Vehicle.slideOffsetH) then
        tFutOffSet = -t.Vehicle.slideOffsetH * 0.5
      else
        if tDistance < tFutOffSet then
          tFutOffSet = -tFutOffSet
        else
          if (tTransform.position.x + tFutOffSet) > (tMaxOffset[1] + t.Vehicle.maxOffsetH) then
            tFutOffSet = -tFutOffSet * 0.5
          end if
        end if
      end if
    else
      if (tTransform.position.x + tFutOffSet) > (tMaxOffset[1] + t.Vehicle.maxOffsetH) then
        tFutOffSet = -tFutOffSet * 0.5
      end if
      if gGame.PlaneHelpers = 1 then
        t.Vehicle.flyHelper2.parent = VOID
      end if
    end if
  end if
  tTransform.position = tTransform.position + (tTransform.xAxis * tFutOffSet)
  t.Vehicle.rightSpeed[1] = tFutOffSet
  if (t.Input.left = 0) and (t.Input.right = 0) then
    tCarT.rotation.y = tCarT.rotation.y * 0.90000000000000002
    tCarT.rotation.z = tCarT.rotation.z * 0.90000000000000002
  end if
  tFutOffSet = t.Vehicle.upSpeed[1]
  if t.Input.backward = 1 then
    t.Vehicle.downSpeed[1] = 0.0
    tFutOffSet = tFutOffSet + t.Vehicle.acc
    tFutOffSet = min(tFutOffSet, t.Vehicle.upSpeed[2])
    if tCarT.rotation.x < 10 then
      tCarT.rotation.x = tCarT.rotation.x + 1.0
    end if
  else
    tFutOffSet = tFutOffSet * t.Vehicle.drag
  end if
  if tFutOffSet > 0.0001 then
    tIntersectDetails = gGame.Physics.rayCastClosest(tTransform.position, vector(0.0001, 0.0001, 1.00009999999999999))
    if tIntersectDetails.count > 0 then
      if gGame.PlaneHelpers = 1 then
        tmodel = t.Vehicle.flyHelper3
        tmodel.parent = t.general.member.group("World")
        tmodel.transform.position = tTransform.position
        tmodel.pointAt(tIntersectDetails[2])
        tmodel.resource.height = tIntersectDetails[4]
        tmodel.translate(0, tIntersectDetails[4] * 0.5, 0, #self)
      end if
      tDistance = tIntersectDetails[4]
      if (tDistance < t.Vehicle.slideOffsetV) and (tFutOffSet < t.Vehicle.slideOffsetV) then
        tFutOffSet = -t.Vehicle.slideOffsetV * 0.5
      else
        if tDistance < tFutOffSet then
          tFutOffSet = -tFutOffSet
        else
          if (tTransform.position.x + tFutOffSet) > (tMaxOffset[1] + t.Vehicle.maxOffsetV) then
            tFutOffSet = -tFutOffSet * 0.5
          end if
        end if
      end if
    else
      if (tTransform.position.x + tFutOffSet) > (tMaxOffset[1] + t.Vehicle.maxOffsetV) then
        tFutOffSet = -tFutOffSet * 0.5
      end if
      if gGame.PlaneHelpers = 1 then
        t.Vehicle.flyHelper3.parent = VOID
      end if
    end if
  end if
  tTransform.position = tTransform.position + (tTransform.zAxis * tFutOffSet)
  t.Vehicle.upSpeed[1] = tFutOffSet
  tFutOffSet = t.Vehicle.downSpeed[1]
  if t.Input.forward = 1 then
    t.Vehicle.upSpeed[1] = 0.0
    tFutOffSet = tFutOffSet + t.Vehicle.acc
    tFutOffSet = min(tFutOffSet, t.Vehicle.downSpeed[2])
    if tCarT.rotation.x > -10 then
      tCarT.rotation.x = tCarT.rotation.x - 1.0
    end if
  else
    tFutOffSet = tFutOffSet * t.Vehicle.drag
  end if
  if tFutOffSet > 0.0001 then
    tIntersectDetails = gGame.Physics.rayCastClosest(tTransform.position, vector(0.0001, 0.0001, -1.00009999999999999))
    if tIntersectDetails.count > 0 then
      if gGame.PlaneHelpers = 1 then
        tmodel = t.Vehicle.flyHelper4
        tmodel.parent = t.general.member.group("World")
        tmodel.transform.position = tTransform.position
        tmodel.pointAt(tIntersectDetails[2])
        tmodel.resource.height = tIntersectDetails[4]
        tmodel.translate(0, tIntersectDetails[4] * 0.5, 0, #self)
      end if
      tDistance = tIntersectDetails[4]
      if (tDistance < t.Vehicle.slideOffsetV) and (tFutOffSet < t.Vehicle.slideOffsetV) then
        tFutOffSet = -t.Vehicle.slideOffsetV * 0.5
      else
        if tDistance < tFutOffSet then
          tFutOffSet = -tFutOffSet
        else
          if (tTransform.position.x - tFutOffSet) < (tMaxOffset[1] - t.Vehicle.maxOffsetV) then
            tFutOffSet = -tFutOffSet * 0.5
          end if
        end if
      end if
    else
      if (tTransform.position.x - tFutOffSet) < (tMaxOffset[1] - t.Vehicle.maxOffsetV) then
        tFutOffSet = -tFutOffSet * 0.5
      end if
      if gGame.PlaneHelpers = 1 then
        t.Vehicle.flyHelper4.parent = VOID
      end if
    end if
  end if
  tTransform.position = tTransform.position - (tTransform.zAxis * tFutOffSet)
  t.Vehicle.downSpeed[1] = tFutOffSet
  if (t.Input.forward = 0) and (t.Input.backward = 0) then
    if t.Vehicle.name = "Apache" then
      tdiff = -7.0 - tCarT.rotation.x
      tCarT.rotation.x = -7.0 - (tdiff * 0.90000000000000002)
    else
      tCarT.rotation.x = tCarT.rotation.x * 0.90000000000000002
    end if
  end if
  t.Vehicle.model.transform.position = tTransform.position
  if t.Vehicle.name <> "F22" then
    repeat with i in t.Vehicle.rotorList
      i.rotate(0, 10.0 * gGame.TimeMP, 0, #self)
    end repeat
  else
    tRandom = random(10, 50) * 0.01
    repeat with i in t.Vehicle.engineList
      i.transform.scale.y = 0.5 + abs(t.Vehicle.flySpeed[1]) + tRandom
    end repeat
  end if
end

on reset_Flying me, t
  t.general.States.deleteOne(#update_flying)
end

on update_FlyingAC130 me, t
  if t.Vehicle.Health <= 0 then
    return 0
  end if
  tgroup = t.Vehicle.group
  tTransform = t.Vehicle.group.transform
  t.Vehicle.RigidBody.position = vector()
  tgroup.transform.position = tgroup.transform.position + (tgroup.transform.yAxis * 0.90000000000000002)
  tCarT = t.Vehicle.model.transform
  tWaypointT = t.race.WayPointList[t.race.waypoint]
  tMaxOffset = [tWaypointT.position.x, tWaypointT.position.z]
  t.Vehicle.model.transform.position = tTransform.position
  repeat with i in t.Vehicle.rotorList
    i.rotate(0, 10.0 * gGame.TimeMP, 0, #self)
  end repeat
end

on reset_fyingAC130 me, t
  t.general.States.deleteOne(#update_FlyingAC130)
end

on update_flyingSpitfire me, t
  if t.Vehicle.Health <= 0 then
    return 0
  end if
  tgroup = t.Vehicle.group
  tTransform = t.Vehicle.group.transform
  t.Vehicle.RigidBody.position = vector()
  tWaypointT = t.race.WayPointList[t.race.waypoint]
  tCurrentT = tgroup.getWorldTransform()
  tgroup.transform.position = tgroup.transform.position + (tgroup.transform.yAxis * 0.90000000000000002)
  tIntersectDetails = gGame.Physics.rayCastClosest(tTransform.position, vector(1.00009999999999999, 0.0001, 0.0001))
  if tIntersectDetails.count > 0 then
    if tIntersectDetails[4] <= (50.0 - t.Vehicle.spitFireOffsets[1]) then
      tgroup.transform.position = tgroup.transform.position + (-tgroup.transform.xAxis * 0.10000000000000001)
    end if
    if tIntersectDetails[4] >= (70.0 + t.Vehicle.spitFireOffsets[1]) then
      tgroup.transform.position = tgroup.transform.position + (tgroup.transform.xAxis * 0.10000000000000001)
    end if
  end if
  if (tgroup.transform.position.z - tWaypointT.position.z) >= (30.0 + t.Vehicle.spitFireOffsets[2]) then
    tgroup.transform.position = tgroup.transform.position + (-tgroup.transform.zAxis * 0.10000000000000001)
  end if
  if (tgroup.transform.position.z - tWaypointT.position.z) <= (25.0 - t.Vehicle.spitFireOffsets[2]) then
    tgroup.transform.position = tgroup.transform.position + (tgroup.transform.zAxis * 0.10000000000000001)
  end if
  tCarT = t.Vehicle.model.transform
  t.Vehicle.model.transform.position = tTransform.position
  repeat with i in t.Vehicle.rotorList
    i.rotate(0, 10.0 * gGame.TimeMP, 0, #self)
  end repeat
end

on reset_flyingSpitfire me, t
  t.general.States.deleteOne(#update_flyingSpitfire)
end
