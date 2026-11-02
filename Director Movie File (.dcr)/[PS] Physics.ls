-- [Script] [PS] Physics (Script #6156)
-- Script Type: Parent

property p
global gSystem, gGame

on new me, tDataList
  p = [:]
  tmember = member(tDataList[#member])
  if tmember = VOID then
    return 0
  end if
  p[#ScriptName] = "[PS] Physics"
  gGame[#Physics] = createMember(0, tmember.name & "_Physics", [#type: #Physics])
  p[#timeStep] = 0.0333
  p[#subSteps] = 4
  gGame.Physics.destroy()
  gGame.Physics.Init(tmember, vector(1.0, 1.0, 1.0), #equal, p.timeStep, p.subSteps)
  gGame.Physics.gravity = vector(0.0, 0.0, -39.24000000000000199)
  gGame.Physics.sleepThreshold = 1
  gGame.Physics.sleepMode = #linearVelocity
  gGame.Physics.RegisterCollisionCallback(#collisionCallback)
  return me
end

on enterFrame me
  tTimeStep = p.timeStep * gGame.TimeMP
  gGame.Physics.timeStep = tTimeStep
  gGame.Physics.simulate()
end

on delete me
  gGame[#Physics].erase()
  gGame[#Physics] = VOID
  gGame.deleteProp(#Physics)
  if gSystem.scriptList.getPos(me) <> 0 then
    gSystem.scriptList.deleteOne(me)
  else
    gGame.scriptList.deleteOne(me)
  end if
end
