-- [Script] [PS] Sam Site Old (Script #5902)
-- Script Type: Parent

property p
global gSystem, gGame, gData

on new me, tDataList
  p = [:]
  p[#member] = member(tDataList.member)
  p[#model] = tDataList.model
  p[#parent] = p.model.userData.parent
  p[#ROOT] = me.GetRoot()
  p[#waypoint] = me.GetWaypoint()
  p[#group] = p.member.newGroup(p.model.name & "_Group")
  p.group.pointAtOrientation = [vector(0.0, 1.0, 0.0), vector(0.0, 0.0, 1.0)]
  p.group.transform = p.model.getWorldTransform()
  p[#offset] = [[-1.5, -2.29999999999999982, 11], [0, -2.29999999999999982, 11], [1.5, -2.29999999999999982, 11], [-1.5, -3.10000000000000009, 10], [0, -3.10000000000000009, 10], [1.5, -3.10000000000000009, 10]]
  p[#FireDelay] = [0, 22]
  p[#FireSeq] = 0
  p[#state] = #sleeping
  return me
end

on enterFrame me
  if gGame.SamSites = 0 then
    return 0
  end if
  if voidp(gGame[#RaceState]) = 1 then
    return 0
  else
    if gGame.RaceState <> #Racing then
      return 0
    end if
  end if
  if voidp(gGame[#vehicles]) = 1 then
    return 0
  end if
  t = gGame.vehicles[1]
  tTargetRoot = t.Vehicle.currentRootNr
  tTargetWaypoint = t.race.waypoint
  tHealth = p.model.userData.Health
  if tHealth <= 0 then
    p.state = #Death
  end if
  if p.state = #sleeping then
    tDistance = p.model.worldPosition.distanceTo(t.Vehicle.model.worldPosition)
    if tDistance <= 500 then
      p.state = #Active
    end if
  else
    if p.state = #Active then
      if (tTargetRoot = p.ROOT) and ((p.waypoint - tTargetWaypoint) <= 3) then
        p.state = #inactive
      end if
      p.FireDelay[1] = p.FireDelay[1] + (1.0 * gGame.TimeMP)
      if p.FireDelay[1] >= p.FireDelay[2] then
        p.FireDelay[1] = 0
        p.FireSeq = p.FireSeq + 1
        if p.FireSeq > 6 then
          p.FireSeq = 1
        end if
        p.group.transform = p.model.getWorldTransform()
        p.group.translate(p.offset[p.FireSeq][1], p.offset[p.FireSeq][2], p.offset[p.FireSeq][3], #self)
        tDistance = p.model.worldPosition.distanceTo(t.Vehicle.model.worldPosition)
        tFrames = integer(tDistance / 5.0)
        if voidp(t.Vehicle[#flySpeed]) = 1 then
          tSpeed = t.Vehicle.Speed / gGame.tempo
        else
          tSpeed = t.Vehicle.flySpeed[1]
        end if
        tFutLoc = t.Vehicle.group.worldPosition + (t.Vehicle.group.transform.yAxis * tSpeed * tFrames)
        p.group.pointAt(tFutLoc, vector(0, 0, 1))
        tScript = new(script("[PS] Sam Rocket"), [#member: p.member, #sender: p.model.name, #transform: p.group.transform.duplicate()])
        if tScript <> VOID then
          gGame.scriptList.add(tScript)
        end if
      end if
    end if
  end if
  if p.state = #Death then
    delete me
  end if
end

on GetRoot me
  tString = p.parent.name
  the itemDelimiter = "_"
  tString = tString.item[1]
  return value(tString.char[10..tString.length])
end

on GetWaypoint me
  tList = gGame.WayPointList[symbol(p.parent.name)].duplicate()
  tPos = p.model.worldPosition
  tWaypoint = 1
  tDistance = 999.0
  tCount = tList.count
  repeat with i = 1 to tCount
    tNewDistance = p.model.worldPosition.distanceTo(tList[i].position)
    if tNewDistance < tDistance then
      tDistance = tNewDistance
      tWaypoint = i
    end if
  end repeat
  return tWaypoint
end

on delete me
  gGame.scriptList.deleteOne(me)
end
