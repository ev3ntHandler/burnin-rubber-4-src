-- [Script] [M] Physics (Script #6155)
-- Script Type: Movie

global gGame

on collisionCallback collisionReport
  repeat with i in collisionReport
    gGame.fx.Collisions[symbol(i.ObjectA.name)] = [i.ObjectB.name, i.contactPoints[1][1], i.contactNormals[1], 0]
    gGame.fx.Collisions[symbol(i.ObjectB.name)] = [i.ObjectA.name, i.contactPoints[1][1], i.contactNormals[1] * -1, 0]
  end repeat
end

on createRigidBody me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    return 0
  end if
  if gGame.Physics = VOID then
    return 0
  end if
  tTargetList = []
  if tDataList[#model].ilk = #void then
    tDataList[#model] = "*.*"
  end if
  if tDataList[#model].ilk = #list then
    tTargetList = tDataList.model
  else
    if tDataList[#model].ilk = #string then
      if tDataList.model.char[1] = "*" then
        tString = tDataList.model
        if tString <> "*.*" then
          delete tString.char[1]
        end if
        tTargetList = GetObjectList(0, tmember.name, [#type: #model, #string: tString])
      else
        tTargetList.add(tDataList.model)
      end if
    end if
  end if
  if tTargetList.count = 0 then
    return []
  end if
  if tDataList[#type].ilk = #symbol then
    if [#static, #dynamic].getPos(tDataList.type) <> 0 then
      tType = tDataList.type
    else
      tType = #static
    end if
  else
    tType = #static
  end if
  if tDataList[#pinned].ilk = #integer then
    tPinned = tDataList.pinned
  else
    tPinned = 0
  end if
  if (tDataList[#restitution].ilk = #integer) or (tDataList[#restitution].ilk = #float) then
    tRestitution = tDataList.restitution
  else
    if tType = #static then
      tRestitution = 0.10000000000000001
    else
      tRestitution = 0.20000000000000001
    end if
  end if
  if (tDataList[#friction].ilk = #integer) or (tDataList[#friction].ilk = #float) then
    tFriction = tDataList.friction
  else
    if tType = #static then
      tFriction = 0.10000000000000001
    else
      tFriction = 0.5
    end if
  end if
  if (tDataList[#mass].ilk = #integer) or (tDataList[#mass].ilk = #float) then
    tMass = tDataList.mass
  else
    tMass = 0.0
  end if
  tList = []
  repeat with i in tTargetList
    tmodel = tmember.model(i)
    if gGame.Physics.getRigidBody(i) <> VOID then
      next repeat
    end if
    tResource = tmodel.resource
    if tResource.type = #fromFile then
      if tResource.lod.auto = 1 then
        tResource.lod.auto = 0
        tResource.lod.bias = 100.0
        tResource.lod.level = 100.0
      end if
    end if
    tmodel.addModifier(#meshDeform)
    if tDataList[#bodyProxy].ilk = #symbol then
      if [#convexShape, #concaveShape, #box, #sphere].getPos(tDataList.bodyProxy) <> 0 then
        tBodyProxy = tDataList.bodyProxy
      else
        tBodyProxy = #convexShape
      end if
    else
      tBodyProxy = #convexShape
    end if
    tRB = gGame.Physics.createRigidBody(i, i, tBodyProxy, tType)
    tRB.restitution = tRestitution
    tRB.friction = tFriction
    tRB.mass = tMass
    tRB.isPinned = tPinned
    tmodel.removeModifier(#meshDeform)
    tList.add(tRB)
  end repeat
  if tList.count = 1 then
    return tList[1]
  else
    return tList
  end if
end

on deleteRigidBody me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    return 0
  end if
  if gGame.Physics = VOID then
    return 0
  end if
  tTargetList = []
  if tDataList[#model].ilk = #void then
    tDataList[#model] = "*.*"
  end if
  if tDataList[#model].ilk = #list then
    tTargetList = tDataList.model
  else
    if tDataList[#model].ilk = #string then
      if tDataList.model.char[1] = "*" then
        tString = tDataList.model
        if tString <> "*.*" then
          delete tString.char[1]
        end if
        tTargetList = GetObjectList(0, tmember.name, [#type: #model, #string: tString])
      else
        tTargetList.add(tDataList.model)
      end if
    end if
  end if
  if tTargetList.count = 0 then
    return []
  end if
  repeat with i in tTargetList
    tRB = gGame.Physics.getRigidBody(i)
    if tRB <> VOID then
      gGame.Physics.deleteRigidBody(tRB)
    end if
  end repeat
  return 1
end

on CreateCollisionReport me, tTarget, tDataList
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    return 0
  end if
  if gGame.Physics = VOID then
    return 0
  end if
  if voidp(gGame[#fx]) = 1 then
    return 0
  end if
  if (tDataList[#nameA].ilk = #void) or (tDataList[#nameB].ilk = #void) then
    return 0
  end if
  tNameA = tDataList.nameA
  tNameB = tDataList.nameB
  if tNameA = #all then
    gGame.Physics.EnableCollisionCallback()
  else
    if tNameB = #all then
      tRB = gGame.Physics.getRigidBody(tNameA)
      if tRB = VOID then
        return 0
      end if
      tList = gGame.Physics.getRigidBodies()
      repeat with i in tList
        if i = tRB then
          next repeat
        end if
        gGame.Physics.EnableCollisionCallback(tRB, i)
      end repeat
    end if
    if tNameB = #vehicles then
      tRB = gGame.Physics.getRigidBody(tNameA)
      if tRB = VOID then
        return 0
      end if
      repeat with i in gGame.vehicles
        if i.Vehicle.RigidBody = tRB then
          next repeat
        end if
        gGame.Physics.EnableCollisionCallback(tRB, i.Vehicle.RigidBody)
      end repeat
    end if
    if (tNameB <> #all) and (tNameB <> #vehicles) then
      tRBa = gGame.Physics.getRigidBody(tNameA)
      tRBb = gGame.Physics.getRigidBody(tNameB)
      gGame.Physics.EnableCollisionCallback(tRBa, tRBb)
    end if
  end if
  if tDataList[#CollisionDamage].ilk <> #void then
    if tDataList.CollisionDamage = 1 then
      if gGame.fx.CollisionDamage.getPos(tNameA) = 0 then
        gGame.fx.CollisionDamage.add(tNameA)
      end if
    end if
  end if
end
