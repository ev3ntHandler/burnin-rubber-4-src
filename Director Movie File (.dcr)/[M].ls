-- [Script] [M] (Script #5899)
-- Script Type: Movie

global gGame

on MountedWeaponSpawnItem me, tTarget, tDataList
  tmember = member(tTarget)
  tmodel = tmember.model(tDataList.model)
  tUserData = tmodel.userData
  tItemCount = 10
  tStep = 360 / tItemCount
  tWorldTransform = tmodel.getWorldTransform()
  tOffset = 7.0
  if tmodel.name contains "SamSite" then
    tOffset = 12.5
  end if
  tRandom = _system.milliSeconds
  repeat with i = 1 to tItemCount
    tPos = tmodel.worldPosition + vector(0, 0, 0.5)
    tTransform = tWorldTransform.duplicate()
    tTransform.rotate(tPos, tTransform.zAxis, i * tStep)
    tPos = tPos + (tTransform.yAxis * tOffset)
    tDetails = gGame.Physics.rayCastClosest(tPos, vector(0.0001, 0.0001, -1.00009999999999999))
    if tDetails.count = 0 then
      return 0
    end if
    tGroupName = tDetails[1].name
    tGroupName = tGroupName.char[1..5]
    tParent = tmember.group(tGroupName & "_Pickups")
    if tParent = VOID then
      return 0
    end if
    tPickup = "CashWorld"
    tResourceName = "Cash"
    tPickup = tmember.newModel(tGroupName & "_" & tPickup & "_" & tmodel.name.item[3] & "_" & tRandom & "_" & i & "_PickUp", tmember.modelResource(tResourceName & "_PickUp"))
    tPickup.pointAtOrientation = [vector(0, -1, 0), vector(0, 0, 1)]
    tPickup.shader = tmember.shader("Pickups_material")
    tPickup.transform.position = tDetails[2] + vector(0, 0, 1.5)
    if tParent.userData.getaProp(#Pickups) = VOID then
      tParent.userData.addProp(#Pickups, [tPickup])
      next repeat
    end if
    tParent.userData.Pickups.add(tPickup)
  end repeat
end
