-- [Script] [PS] Airstrike Beacon (Script #5897)
-- Script Type: Parent

property p
global gSystem, gGame, gData

on new me, t, tPod
  p = [:]
  p[#member] = t.general.member
  p[#sender] = t.general.tag
  p[#model] = t.Vehicle.model
  p[#axis] = p.model.getWorldTransform().xAxis
  p[#data] = gData.data.SecondaryWeapons.AirstrikeLauncher
  p[#me] = me
  p[#BeaconName] = string(p.sender) & "AirstrikeBeacon" & _system.milliSeconds
  p[#Beacon] = p.member.newModel(p.BeaconName, p.member.modelResource("AirstrikeBeacon"))
  p.Beacon.shader = p.member.model("AirstrikeBeacon").shader
  p.Beacon.pointAtOrientation = [vector(0.0, 0.0, 1.0), vector(0.0, 1.0, 0.0)]
  tTransform = t.Vehicle.Effects.secondary[1].getWorldTransform().duplicate()
  p.Beacon.transform = tTransform
  p[#Stuck] = 0
  p[#Speed] = 5.0
  p[#gravity] = -0.07000000000000001
  p[#rotation] = 25
  p[#distance] = 0
  p[#Bombs] = 20
  p[#TargetList] = []
  p[#Counter] = 1.0
  p[#BombDelay] = 1.0
  PlaySound(0, "RocketPodLaunch_SFX", [#priority: #low, #surround: 1, #member3DName: gGame.member.name, #sender: t.Vehicle.Proxy.name, #targetName: t.Vehicle.Proxy.name, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 0, #Override: 1])
  PlaySound(0, "AirstrikeJet_SFX", [#priority: #medium, #surround: 1, #member3DName: p.member.name, #sender: p.Beacon.name, #targetName: p.Beacon.name, #referenceName: "Player1_Camera", #distance: [75, 300], #static: 0, #Override: 1])
  p[#timeout] = 5 * gGame.tempo
  return me
end

on enterFrame me
  if p.Stuck = 0 then
    p.Beacon.translate(0, p.Speed * gGame.TimeMP, p.gravity * gGame.TimeMP, #self)
    p.distance = p.distance + (p.Speed * gGame.TimeMP)
    tTransform = p.Beacon.transform
    tDetails1 = gGame.Physics.rayCastClosest(tTransform.position, tTransform.yAxis)
    tDetails2 = gGame.Physics.rayCastClosest(tTransform.position, vector(0.0001, 0.0001, -1.00009999999999999))
    if tDetails1.count > 0 then
      if tDetails1[4] < (0.5 + (p.Speed * gGame.TimeMP)) then
        me.Stuck(tDetails1)
      end if
    end if
    if (tDetails2.count > 0) and (p.Stuck = 0) then
      if tDetails2[4] < 0.20000000000000001 then
        me.Stuck(tDetails2)
      end if
    end if
  else
    p.Counter = p.Counter - (1 * gGame.TimeMP)
    if (p.Bombs > 0) and (p.Counter = 0) then
      tVector = p.TargetList[p.Bombs]
      tDetails = gGame.Physics.rayCastClosest(tVector + vector(0, 0, 100), vector(0, 0, -1))
      if tDetails.count > 0 then
        tVector = tDetails[2]
      end if
      if string(p.sender) contains "player" then
        UPdateSWTrophyExplosion()
      end if
      tExploScript = new(script("[PS] ExplosionSmall"), [#member: p.member.name, #position: tVector, #camera: "Player1_Camera", #duration: 2500])
      if tExploScript <> VOID then
        gGame.scriptList.add(tExploScript)
      end if
      PlaySound(0, "RocketPodExplosion_SFX", [#priority: #medium, #surround: 1, #member3DName: p.member.name, #sender: p.Beacon.name, #targetName: p.Beacon.name, #referenceName: "Player1_Camera", #distance: [20, 200], #static: 0, #Override: 1])
      areaDamage(0, p.member.name, [#position: tVector, #areaDamage: p.data.areaDamage, #sender: p.sender])
      p.Counter = p.BombDelay
      p.Bombs = p.Bombs - 1
      if p.Bombs = 0 then
        delete me
        exit
      end if
    end if
  end if
  p.timeout = p.timeout - (1.0 * gGame.TimeMP)
  if p.timeout <= 0 then
    delete me
  end if
end

on Stuck me, tDetails
  PlaySound(0, "AirstrikeJet_SFX", [#priority: #medium, #surround: 1, #member3DName: p.member.name, #sender: p.Beacon.name, #targetName: p.Beacon.name, #referenceName: "Player1_Camera", #distance: [75, 300], #static: 0, #Override: 1])
  tName = tDetails[1].name
  tmodel = p.member.model(tName)
  p.Beacon.transform.position = tDetails[2] + (tDetails[3] * 0.05)
  p.Beacon.pointAt(tDetails[3] * 100000, vector(0, 0, 1))
  tOffset = p.Beacon.worldPosition - tmodel.worldPosition
  p.Beacon.transform.position = tmodel.worldPosition
  p.Beacon.parent = tmodel
  p.Beacon.transform.position = tOffset
  p.Stuck = 1
  tOffset = 24
  tTransform = p.Beacon.getWorldTransform().duplicate()
  repeat with i = 1 to p.Bombs
    tVector = tTransform.position
    tVector = tVector - (p.axis * tOffset)
    tVector = tVector + (p.axis * (i * 4))
    tOdd = i mod 2
    if tOdd = 1 then
      tVector = tVector - (tTransform.yAxis * 4)
    else
      tVector = tVector + (tTransform.yAxis * 4)
    end if
    tVector = tVector + randomVector()
    p.TargetList.add(tVector)
  end repeat
end

on delete me
  if p.Beacon <> VOID then
    p.member.deleteModel(p.Beacon.name)
  end if
  gGame.scriptList.deleteOne(p.me)
end
