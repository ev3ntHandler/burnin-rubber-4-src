-- [Script] [M] Vehicle Tank States (Script #5878)
-- Script Type: Movie

global gSystem, gData, gGame, gSound

on setup_tank me, t
  tgroup = gGame.member.newGroup(string(t.general.tag) & "MainGunHelper")
  t.Weapons.MainGun[#helper] = tgroup
  t.Weapons.MainGun.helper.pointAtOrientation = [vector(0.0, 1.0, 0.0), vector(0.0, 0.0, 1.0)]
end

on update_tank me, t
  if gGame.Input = 0 then
    exit
  end if
  tTurret = t.Weapons.MainGun.Turret
  tHelper = t.Weapons.MainGun.helper
  tTransform1 = tTurret.getWorldTransform()
  tTransform2 = gGame.vehicles[1].Vehicle.model.getWorldTransform()
  tHelper.transform.position = tTurret.worldPosition
  tPosition = tTransform2.position
  tPosition.z = tHelper.getWorldTransform().position.z
  tStoreT = tTurret.transform.duplicate()
  tTurret.pointAt(tPosition, vector(0, 0, 1))
  tNewT = transform()
  tNewT.rotation = t.Vehicle.model.getWorldTransform().rotation
  tNewT.rotation.z = tTurret.transform.rotation.z
  tTurret.transform = tStoreT
  tTurret.transform.interpolateTo(tNewT, 5)
  pos1 = tTransform1.position - tTransform2.position
  pos1.normalize()
  tDistance = tTransform1.position.distanceTo(tTransform2.position)
  if tDistance > 100 then
    t.Input.action1 = 0
    t.Input.action2 = 0
  else
    tLeftRight = pos1.dot(tTransform1.xAxis)
    if abs(tLeftRight) <= 0.20000000000000001 then
      t.Input.action1 = 1
      t.Input.action2 = 1
    else
      t.Input.action1 = 0
      t.Input.action2 = 0
    end if
  end if
end

on reset_tank me, t
  t.general.States.deleteOne(#update_tank)
end
