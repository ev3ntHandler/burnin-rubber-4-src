-- [Script] [M] Weapons (Script #5891)
-- Script Type: Movie

global gSystem, gData, gGame, gSound

on BuildWeapon me, t, tProp, tWeaponList
  tmember = t.general.member
  tWeaponsMember = member("Weapons")
  tWeapon = t.general.data.Weapons[tProp]
  t.Vehicle.Effects[tProp] = []
  if tWeapon = "none" then
    return 0
  end if
  tStringTag = string(t.general.tag)
  tModelList = CloneModel(0, gGame.member.name, [#sourceMember: tWeaponsMember.name, #model: tWeaponList, #NameTag: tStringTag, #shaderTag: tStringTag, #lod: 0])
  if tModelList.ilk <> #list then
    tModelList = [tModelList]
  end if
  tLocations = gData.data[symbol(string(tProp) & "Weapons")][symbol(tWeapon)][#location]
  tCount = tLocations.count
  repeat with i = 1 to tModelList.count
    tmodel = tModelList[i]
    tString = string(tProp & tLocations[i])
    if tProp = #primary2 then
      tString = #Secondary1
    end if
    if tProp = #primary3 then
      tString = #Secondary2
    end if
    tmodel.transform = t.Vehicle.weaponPlaceList[symbol(tString)].getWorldTransform()
    tmodel.transform = t.Vehicle.model.getWorldTransform().inverse() * tmodel.transform
    tmodel.parent = t.Vehicle.model
    tShader = tmodel.shader
    if t.Vehicle.shaderList.getPos(tShader) = 0 then
      t.Vehicle.shaderList.add(tShader)
    end if
    if t.Vehicle.weaponShaders.getPos(tShader) = 0 then
      t.Vehicle.weaponShaders.add(tShader)
    end if
  end repeat
  repeat with i = 1 to 4
    if i <= tWeaponList.count then
      tgroup = tWeaponsMember.group(tWeaponList[i] & "Flash" & i & "_Dummy")
    else
      tgroup = tWeaponsMember.group(tWeaponList[1] & "Flash" & i & "_Dummy")
    end if
    if i <= tWeaponList.count then
      tWeaponModel = tWeaponsMember.model(tWeaponList[i])
    else
      tWeaponModel = tWeaponsMember.model(tWeaponList[1])
    end if
    if tgroup = VOID then
      next repeat
    end if
    tNewGroup = tmember.newGroup(tStringTag & tgroup.name)
    if i <= tWeaponList.count then
      tNewGroup.transform = tModelList[i].getWorldTransform()
    else
      tNewGroup.transform = tModelList[1].getWorldTransform()
    end if
    tOffset = tgroup.transform.position - tWeaponModel.transform.position
    tNewGroup.translate(tOffset, #self)
    tNewGroup.transform = t.Vehicle.model.getWorldTransform().inverse() * tNewGroup.transform
    tNewGroup.parent = t.Vehicle.model
    t.Vehicle.Effects[tProp].add(tNewGroup)
  end repeat
  if tModelList.ilk <> #list then
    tModelList = [tModelList]
  end if
  repeat with i in tModelList
    i.userData.addProp(#parent, i.parent)
    i.userData.addProp(#transform, i.transform.duplicate())
    if gGame.HideWeapons.getPos(t.Vehicle.name) <> 0 then
      i.visibility = #none
    end if
  end repeat
  return tModelList
end

on setup_machinegun me, t
  tData = gData.data.PrimaryWeapons.MachineGun.duplicate()
  t.Weapons[#MachineGun] = [#models: [], #rof: [0.0, integer(gGame.tempo / float(tData.rof))], #ammo: [tData.ammo, tData.ammo], #clips: t.general.data.upgrades.primary[1], #damage: tData.damage]
  tModelList = BuildWeapon(0, t, #primary, ["MachineGun"])
  t.Weapons.MachineGun.models = tModelList
  t.Weapons.MachineGun[#Flash1] = CloneModel(0, t.general.member.name, [#sourceMember: "Weapons", #model: ["MachineGunMuzzleFlash1"], #NameTag: string(t.general.tag), #lod: 0])
  t.Weapons.MachineGun.Flash1.parent = t.Vehicle.Effects.primary[1]
  t.Weapons.MachineGun.Flash1.transform.position = vector()
  t.Weapons.MachineGun.Flash1.transform.scale = vector(0.001, 0.001, 0.001)
  t.Weapons.MachineGun[#Flash1Scale] = vector(1, 1, 1)
  t.Weapons.MachineGun[#Flash2] = CloneModel(0, t.general.member.name, [#sourceMember: "Weapons", #model: ["MachineGunMuzzleFlash2"], #NameTag: string(t.general.tag), #lod: 0])
  t.Weapons.MachineGun.Flash2.parent = t.Vehicle.Effects.primary[1]
  t.Weapons.MachineGun.Flash2.transform.position = vector()
  t.Weapons.MachineGun.Flash2.transform.scale = vector(0.001, 0.001, 0.001)
  t.Weapons.MachineGun[#Shells] = []
  if t.general.controller = #player then
    t.Weapons.MachineGun.Shells.add(CreateParticleSystem(0, t.general.member.name, [#type: symbol("Shells1"), #NameTag: string(t.general.tag) & "Shells"]))
    t.Weapons.MachineGun.Shells[1].resource.emitter.region = [vector(0, 0, -1500)]
  end if
  if t[#sound] <> VOID then
    t.sound[#primary] = t.sound.Mixer.createSoundObject("Primary", member("MachineGun_SFX"), [#loopCount: 0])
    t.sound.primary.volume = 0
    t.sound.primary.play()
  end if
  t.Weapons.MachineGun[#Bullet] = CloneModel(0, t.general.member.name, [#sourceMember: "Weapons", #model: ["Bullet"], #NameTag: string(t.general.tag), #hide: 1, #lod: 0])
  t.Weapons.MachineGun[#BulletScale] = 1.0
  if t.Weapons.States.getPos(#update_machinegun) = 0 then
    t.Weapons.States.add(#update_machinegun)
  end if
end

on update_machinegun me, t
  tData = t.Weapons.MachineGun
  tTransform = t.Vehicle.Effects.primary[1].getWorldTransform().duplicate()
  tDirection = tTransform.yAxis
  tBullet = tData.Bullet
  tBulletT = tBullet.transform
  tFlash1 = tData.Flash1.transform
  tFlash2 = tData.Flash2.transform
  if t.Input.action1 = 1 then
    if tData.ammo[1] > 0 then
      tData.rof[1] = tData.rof[1] + gGame.TimeMP
      if tData.rof[1] >= tData.rof[2] then
        tData.rof[1] = 0
        if (gGame.UPUnlockableCheats.getPos(#UnlimitedPrimary) <> 0) and (t.general.controller = #player) then
          nothing()
        else
          tData.ammo[1] = tData.ammo[1] - 1
        end if
        if (tData.ammo[1] = 0) and (tData.clips > 0) then
          tData.ammo[1] = tData.ammo[2]
          tData.clips = tData.clips - 1
        end if
        tFlash2.scale = vector(1.5, 1.5, 1.5)
        tFlash2.rotation.y = random(1, 120)
        tRandom = random(1000, 1400) * 0.001
        tData.Flash1Scale = vector(tRandom, tRandom * 1.5, tRandom)
        tFlash1.scale = tData.Flash1Scale
        tFlash1.rotation.y = random(1, 45)
        if (t[#sound] <> VOID) and (gSound.mute = 0) then
          t.sound.primary.volume = 180
        end if
        tBullet.addToWorld()
        tBullet.transform = tTransform.duplicate()
        tBulletT.scale.y = 100
        tBulletT.position = tTransform.position + (100 * tDirection)
        tData.BulletScale = 100
        tDetails = gGame.Physics.rayCastClosest(tTransform.position, tDirection)
        if tDetails.count > 0 then
          tBulletT.scale.y = max(0.001, tDetails[4])
          tBulletT.position = tTransform.position + (tDetails[4] * tDirection)
          tData.BulletScale = max(0.001, tDetails[4])
          BulletHit(0, t.general.member.name, [#model: tDetails[1].name, #position: tDetails[2], #normal: tDetails[3], #distance: tDetails[4], #damage: random(tData.damage[1], tData.damage[2]), #sender: t.general.tag])
        end if
        if t.general.controller = #player then
          tData.Shells[1].resource.emitter.region = [tData.models[1].worldPosition]
        end if
      else
        tPerc = 1.0 - (tData.rof[1] / tData.rof[2])
        tPerc = max(tPerc, 0.001)
        tFlash1.scale = tData.Flash1Scale * tPerc
        tBulletScale = max(0.001, tData.BulletScale * tPerc)
        tBulletT.scale.y = tBulletScale
        if tData.rof[1] <= (tData.rof[2] * 0.5) then
          tPerc = 1.0 - (tData.rof[1] / (tData.rof[2] * 0.5))
          tPerc = max(tPerc, 0.001)
          tFlash2.scale = vector(1.39999999999999991, 1.39999999999999991, 1.39999999999999991) * tPerc
        else
          tPerc = (tData.rof[1] - (tData.rof[2] * 0.5)) / (tData.rof[2] * 0.5)
          tPerc = max(tPerc, 0.001)
          tFlash2.scale = vector(1.39999999999999991, 1.39999999999999991, 1.39999999999999991) * tPerc
        end if
        if t.general.controller = #player then
          tData.Shells[1].resource.emitter.region = [vector(0, 0, -1500)]
        end if
      end if
    else
      if (t[#sound] <> VOID) and (gSound.mute = 0) then
        t.sound.primary.volume = 0
      end if
      tFlash1.scale = vector(0.001, 0.001, 0.001)
      tFlash2.scale = vector(0.001, 0.001, 0.001)
      tBulletT.scale = vector(0.001, 0.001, 0.001)
      if t.general.controller = #player then
        tData.Shells[1].resource.emitter.region = [vector(0, 0, -1500)]
      end if
    end if
  else
    tFlash1.scale = vector(0.001, 0.001, 0.001)
    tFlash2.scale = vector(0.001, 0.001, 0.001)
    tBulletT.scale = vector(0.001, 0.001, 0.001)
    if (t[#sound] <> VOID) and (gSound.mute = 0) then
      t.sound.primary.volume = 0
    end if
    tData.rof[1] = tData.rof[2]
    if t.general.controller = #player then
      tData.Shells[1].resource.emitter.region = [vector(0, 0, -1500)]
    end if
  end if
end

on reset_machinegun me, t
  tmember = t.general.member
  repeat with i in t.Weapons.MachineGun
    if i.ilk = #model then
      tList = [i]
    else
      if i.ilk = #list then
        tList = i
      else
        next repeat
      end if
    end if
    repeat with j in tList
      if j.ilk = #model then
        tmember.deleteModel(j.name)
      end if
    end repeat
  end repeat
  tList = t.Vehicle.Effects
  repeat with i = 1 to tList.count
    tProp = tList.getPropAt(i)
    if tProp = #primary then
      repeat with j in tList[tProp]
        tmember.deleteGroup(j.name)
      end repeat
      tList[tProp] = []
      next repeat
    end if
    next repeat
  end repeat
  if t[#sound] <> VOID then
    t.sound.Mixer.deleteSoundObject(t.sound.primary)
  end if
  t.Weapons.deleteProp(#MachineGun)
  t.Weapons.States.deleteOne(#update_machinegun)
end

on setup_dualMachinegun me, t
  tData = gData.data.PrimaryWeapons.DualMachineGun.duplicate()
  t.Weapons[#DualMachineGun] = [#models: [], #rof1: [integer(gGame.tempo / float(tData.rof) * 0.5), integer(gGame.tempo / float(tData.rof))], #rof2: [0.0, integer(gGame.tempo / float(tData.rof))], #ammo: [tData.ammo, tData.ammo], #clips: t.general.data.upgrades.primary[1], #damage: tData.damage]
  tModelList = BuildWeapon(0, t, #primary, ["DualMachineGun"])
  t.Weapons.DualMachineGun.models = tModelList
  repeat with i = 1 to 2
    tSymbol = symbol("RightFlash" & i)
    t.Weapons.DualMachineGun[tSymbol] = CloneModel(0, t.general.member.name, [#sourceMember: "Weapons", #model: ["DualMachineGunMuzzleFlashRight" & i], #NameTag: string(t.general.tag), #lod: 0])
    t.Weapons.DualMachineGun[tSymbol].parent = t.Vehicle.Effects.primary[2]
    t.Weapons.DualMachineGun[tSymbol].transform.position = vector()
    t.Weapons.DualMachineGun[tSymbol].transform.scale = vector(0.001, 0.001, 0.001)
    t.Weapons.DualMachineGun[symbol("RightFlash" & i & "Scale")] = vector(1, 1, 1)
  end repeat
  repeat with i = 1 to 2
    tSymbol = symbol("LeftFlash" & i)
    t.Weapons.DualMachineGun[tSymbol] = CloneModel(0, t.general.member.name, [#sourceMember: "Weapons", #model: ["DualMachineGunMuzzleFlashLeft" & i], #NameTag: string(t.general.tag), #lod: 0])
    t.Weapons.DualMachineGun[tSymbol].parent = t.Vehicle.Effects.primary[1]
    t.Weapons.DualMachineGun[tSymbol].transform.position = vector()
    t.Weapons.DualMachineGun[tSymbol].transform.scale = vector(0.001, 0.001, 0.001)
    t.Weapons.DualMachineGun[symbol("LeftFlash" & i & "Scale")] = vector(1, 1, 1)
  end repeat
  t.Weapons.DualMachineGun[#Shells] = []
  if t.general.controller = #player then
    t.Weapons.DualMachineGun.Shells.add(CreateParticleSystem(0, t.general.member.name, [#type: symbol("Shells1"), #NameTag: string(t.general.tag) & "Shells"]))
    t.Weapons.DualMachineGun.Shells.add(CreateParticleSystem(0, t.general.member.name, [#type: symbol("Shells2"), #NameTag: string(t.general.tag) & "Shells"]))
    t.Weapons.DualMachineGun.Shells[1].resource.emitter.region = [vector(0, 0, -1500)]
    t.Weapons.DualMachineGun.Shells[2].resource.emitter.region = [vector(0, 0, -1500)]
  end if
  if t[#sound] <> VOID then
    t.sound[#primary] = t.sound.Mixer.createSoundObject("Primary1", member("MachineGun_SFX"), [#loopCount: 0])
    t.sound.primary.play()
    t.sound.primary.volume = 0
  end if
  t.Weapons.DualMachineGun[#bullet1] = CloneModel(0, t.general.member.name, [#sourceMember: "Weapons", #model: ["Bullet"], #NameTag: string(t.general.tag) & "1", #hide: 1, #lod: 0])
  t.Weapons.DualMachineGun[#bullet2] = CloneModel(0, t.general.member.name, [#sourceMember: "Weapons", #model: ["Bullet"], #NameTag: string(t.general.tag) & "2", #hide: 1, #lod: 0])
  t.Weapons.DualMachineGun[#BulletScale1] = 1.0
  t.Weapons.DualMachineGun[#BulletScale2] = 1.0
  if t.Weapons.States.getPos(#update_dualMachinegun) = 0 then
    t.Weapons.States.add(#update_dualMachinegun)
  end if
end

on update_dualMachinegun me, t
  tData = t.Weapons.DualMachineGun
  repeat with i = 1 to 2
    tProp = symbol("Rof" & i)
    tRof = tData[tProp]
    tBullet = tData[symbol("Bullet" & i)]
    tBulletT = tBullet.transform
    if i = 1 then
      tString = "RightFlash"
    else
      tString = "LeftFlash"
    end if
    tFlash1 = tData[symbol(tString & "1")].transform
    tFlash2 = tData[symbol(tString & "2")].transform
    tTransform = t.Vehicle.Effects.primary[i].getWorldTransform().duplicate()
    tDirection = tTransform.yAxis
    if t.Input.action1 = 1 then
      if tData.ammo[1] > 0 then
        tRof[1] = tRof[1] + gGame.TimeMP
        if tRof[1] >= tRof[2] then
          tRof[1] = 0.0
          if (gGame.UPUnlockableCheats.getPos(#UnlimitedPrimary) <> 0) and (t.general.controller = #player) then
            nothing()
          else
            tData.ammo[1] = tData.ammo[1] - 1
          end if
          if (tData.ammo[1] = 0) and (tData.clips > 0) then
            tData.ammo[1] = tData.ammo[2]
            tData.clips = tData.clips - 1
          end if
          tFlash2.scale = vector(1.5, 1.5, 1.5)
          tFlash2.rotation.y = random(1, 120)
          tRandom = random(1000, 1400) * 0.001
          tData[symbol(tString & i & "Scale")] = vector(tRandom, tRandom * 1.5, tRandom)
          tFlash1.scale = tData[symbol(tString & i & "Scale")]
          tFlash1.rotation.y = random(1, 45)
          if (t[#sound] <> VOID) and (gSound.mute = 0) then
            t.sound.primary.volume = 180
          end if
          tBullet.addToWorld()
          tBullet.transform = tTransform.duplicate()
          tBulletT.scale.y = 100
          tBulletT.position = tTransform.position + (100 * tDirection)
          tData[symbol("BulletScale" & i)] = 100
          tDetails = gGame.Physics.rayCastClosest(tTransform.position, tDirection)
          if tDetails.count > 0 then
            tBulletT.scale.y = max(0.001, tDetails[4])
            tBulletT.position = tTransform.position + (tDetails[4] * tDirection)
            tData[symbol("BulletScale" & i)] = max(0.001, tDetails[4])
            BulletHit(0, t.general.member.name, [#model: tDetails[1].name, #position: tDetails[2], #normal: tDetails[3], #distance: tDetails[4], #damage: random(tData.damage[1], tData.damage[2]), #sender: t.general.tag])
          end if
          if t.general.controller = #player then
            tOffset = tData.models[1].getWorldTransform().xAxis * 0.40000000000000002
            repeat with m = 1 to 2
              tResource = tData.Shells[m].resource
              if m = 1 then
                tResource.emitter.region = [tData.models[1].worldPosition + tOffset]
                next repeat
              end if
              tResource.emitter.region = [tData.models[1].worldPosition - tOffset]
            end repeat
          end if
        else
          tPerc = 1.0 - (tRof[1] / tRof[2])
          tPerc = max(tPerc, 0.001)
          tFlash1.scale = tData[symbol(tString & i & "Scale")] * tPerc
          tBulletScale = max(0.001, tData[symbol("BulletScale" & i)] * tPerc)
          tBulletT.scale.y = tBulletScale
          if tRof[1] <= (tRof[2] * 0.5) then
            tPerc = 1.0 - (tRof[1] / (tRof[2] * 0.5))
            tPerc = max(tPerc, 0.001)
            tFlash2.scale = vector(1.39999999999999991, 1.39999999999999991, 1.39999999999999991) * tPerc
          else
            tPerc = (tRof[1] - (tRof[2] * 0.5)) / (tRof[2] * 0.5)
            tPerc = max(tPerc, 0.001)
            tFlash2.scale = vector(1.39999999999999991, 1.39999999999999991, 1.39999999999999991) * tPerc
          end if
          if t.general.controller = #player then
            repeat with m = 1 to 2
              tResource = tData.Shells[m].resource
              tResource.emitter.region = [vector(0, 0, -1500)]
            end repeat
          end if
        end if
      else
        tFlash1.scale = vector(0.001, 0.001, 0.001)
        tFlash2.scale = vector(0.001, 0.001, 0.001)
        tBulletT.scale = vector(0.001, 0.001, 0.001)
        if (t[#sound] <> VOID) and (gSound.mute = 0) then
          t.sound.primary.volume = 0
        end if
        if t.general.controller = #player then
          repeat with m = 1 to 2
            tResource = tData.Shells[m].resource
            tResource.emitter.region = [vector(0, 0, -1500)]
          end repeat
        end if
      end if
      next repeat
    end if
    tFlash1.scale = vector(0.001, 0.001, 0.001)
    tFlash2.scale = vector(0.001, 0.001, 0.001)
    tBulletT.scale = vector(0.001, 0.001, 0.001)
    if (t[#sound] <> VOID) and (gSound.mute = 0) then
      t.sound.primary.volume = 0
    end if
    if i = 1 then
      tRof[1] = tRof[2] * 0.5
    else
      tRof[1] = tRof[2]
    end if
    if t.general.controller = #player then
      repeat with m = 1 to 2
        tResource = tData.Shells[m].resource
        tResource.emitter.region = [vector(0, 0, -1500)]
      end repeat
    end if
  end repeat
end

on reset_dualmachinegun me, t
  tmember = t.general.member
  repeat with i in t.Weapons.DualMachineGun
    if i.ilk = #model then
      tList = [i]
    else
      if i.ilk = #list then
        tList = i
      else
        next repeat
      end if
    end if
    repeat with j in tList
      if j.ilk = #model then
        tmember.deleteModel(j.name)
      end if
    end repeat
  end repeat
  tList = t.Vehicle.Effects
  repeat with i = 1 to tList.count
    tProp = tList.getPropAt(i)
    if tProp = #primary then
      repeat with j in tList[tProp]
        tmember.deleteGroup(j.name)
      end repeat
      tList[tProp] = []
      next repeat
    end if
    next repeat
  end repeat
  if t[#sound] <> VOID then
    t.sound.Mixer.deleteSoundObject(t.sound.primary)
  end if
  t.Weapons.deleteProp(#DualMachineGun)
  t.Weapons.States.deleteOne(#update_dualMachinegun)
end

on setup_minigun me, t
  tData = gData.data.PrimaryWeapons.Minigun.duplicate()
  t.Weapons[#Minigun] = [#models: [], #rof: [0.0, integer(gGame.tempo / float(tData.rof))], #ammo: [tData.ammo, tData.ammo], #clips: t.general.data.upgrades.primary[1], #damage: tData.damage, #chargeTime: [0, tData.chargeTime * gGame.tempo]]
  tModelList = BuildWeapon(0, t, #primary, ["MiniGun"])
  t.Weapons.Minigun.models = tModelList
  CloneModel(0, gGame.member.name, [#sourceMember: "Weapons", #model: ["MiniGunBarrel"], #NameTag: string(t.general.tag), #shaderTag: string(t.general.tag), #lod: 0])
  tmodel = gGame.member.model(string(t.general.tag) & "MiniGunBarrel")
  tmodel.transform = member("Weapons").model("MiniGun").getWorldTransform().inverse() * member("Weapons").model("MiniGunBarrel").transform
  tmodel.parent = gGame.member.model(string(t.general.tag) & "MiniGun")
  if gGame.HideWeapons.getPos(t.Vehicle.name) <> 0 then
    tmodel.visibility = #none
  end if
  t.Weapons.Minigun[#Barrel] = tmodel
  t.Weapons.Minigun[#Flash1] = CloneModel(0, t.general.member.name, [#sourceMember: "Weapons", #model: ["MiniGunMuzzleFlash1"], #NameTag: string(t.general.tag), #lod: 0])
  t.Weapons.Minigun.Flash1.parent = t.Vehicle.Effects.primary[1]
  t.Weapons.Minigun.Flash1.transform.position = vector()
  t.Weapons.Minigun.Flash1.transform.scale = vector(0.001, 0.001, 0.001)
  t.Weapons.Minigun[#Flash1Scale] = vector(1, 1, 1)
  t.Weapons.Minigun[#Shells] = []
  if t.general.controller = #player then
    t.Weapons.Minigun.Shells.add(CreateParticleSystem(0, t.general.member.name, [#type: symbol("Shells1"), #NameTag: string(t.general.tag) & "Shells"]))
    t.Weapons.Minigun.Shells[1].resource.emitter.region = [vector(0, 0, -1500)]
  end if
  if t[#sound] <> VOID then
    t.sound[#primary] = t.sound.Mixer.createSoundObject("Primary", member("MiniGun_SFX"), [#loopCount: 0])
    t.sound.primary.volume = 0
    t.sound.primary.play()
  end if
  t.Weapons.Minigun[#Bullet] = CloneModel(0, t.general.member.name, [#sourceMember: "Weapons", #model: ["Bullet"], #NameTag: string(t.general.tag), #hide: 1, #lod: 0])
  t.Weapons.Minigun[#BulletScale] = 1.0
  if t.Weapons.States.getPos(#update_minigun) = 0 then
    t.Weapons.States.add(#update_minigun)
  end if
end

on update_minigun me, t
  tData = t.Weapons.Minigun
  tTransform = t.Vehicle.Effects.primary[1].getWorldTransform().duplicate()
  tDirection = tTransform.yAxis
  tBullet = tData.Bullet
  tBulletT = tBullet.transform
  tFlash1 = tData.Flash1.transform
  if t.Input.action1 = 1 then
    if tData.chargeTime[1] < tData.chargeTime[2] then
      tData.chargeTime[1] = tData.chargeTime[1] + gGame.TimeMP
      t.Weapons.Minigun.Barrel.rotate(vector(0, tData.chargeTime[1] * gGame.TimeMP, 0), #self)
    else
      if tData.ammo[1] > 0 then
        tData.rof[1] = tData.rof[1] + gGame.TimeMP
        t.Weapons.Minigun.Barrel.rotate(vector(0, tData.chargeTime[1] * gGame.TimeMP, 0), #self)
        if tData.rof[1] >= tData.rof[2] then
          tData.rof[1] = 0
          if (gGame.UPUnlockableCheats.getPos(#UnlimitedPrimary) <> 0) and (t.general.controller = #player) then
            nothing()
          else
            tData.ammo[1] = tData.ammo[1] - 1
          end if
          if (tData.ammo[1] = 0) and (tData.clips > 0) then
            tData.ammo[1] = tData.ammo[2]
            tData.clips = tData.clips - 1
          end if
          tRandom = random(1000, 1400) * 0.001
          tData.Flash1Scale = vector(tRandom, tRandom * 1.5, tRandom)
          tFlash1.scale = tData.Flash1Scale
          tFlash1.rotation.y = random(1, 45)
          if (t[#sound] <> VOID) and (gSound.mute = 0) then
            t.sound.primary.volume = 180
          end if
          tBullet.addToWorld()
          tBullet.transform = tTransform.duplicate()
          tBulletT.scale.y = 100
          tBulletT.position = tTransform.position + (100 * tDirection)
          tData.BulletScale = 100
          tDetails = gGame.Physics.rayCastClosest(tTransform.position, tDirection)
          if tDetails.count > 0 then
            tBulletT.scale.y = max(0.001, tDetails[4])
            tBulletT.position = tTransform.position + (tDetails[4] * tDirection)
            tData.BulletScale = max(0.001, tDetails[4])
            BulletHit(0, t.general.member.name, [#model: tDetails[1].name, #position: tDetails[2], #normal: tDetails[3], #distance: tDetails[4], #damage: random(tData.damage[1], tData.damage[2]), #sender: t.general.tag])
          end if
          if t.general.controller = #player then
            tData.Shells[1].resource.emitter.region = [tData.Barrel.worldPosition]
          end if
        else
          tPerc = 1.0 - (tData.rof[1] / tData.rof[2])
          tPerc = max(tPerc, 0.001)
          tFlash1.scale = tData.Flash1Scale * tPerc
          tBulletScale = max(0.001, tData.BulletScale * tPerc)
          tBulletT.scale.y = tBulletScale
          if t.general.controller = #player then
            tData.Shells[1].resource.emitter.region = [vector(0, 0, -1500)]
          end if
        end if
      else
        if (t[#sound] <> VOID) and (gSound.mute = 0) then
          t.sound.primary.volume = 0
        end if
        tFlash1.scale = vector(0.001, 0.001, 0.001)
        tBulletT.scale = vector(0.001, 0.001, 0.001)
        if t.general.controller = #player then
          tData.Shells[1].resource.emitter.region = [vector(0, 0, -1500)]
        end if
      end if
    end if
  else
    if tData.chargeTime[1] > 0 then
      tData.chargeTime[1] = tData.chargeTime[1] - gGame.TimeMP
    end if
    t.Weapons.Minigun.Barrel.rotate(vector(0, tData.chargeTime[1] * gGame.TimeMP, 0), #self)
    tFlash1.scale = vector(0.001, 0.001, 0.001)
    tBulletT.scale = vector(0.001, 0.001, 0.001)
    if (t[#sound] <> VOID) and (gSound.mute = 0) then
      t.sound.primary.volume = 0
    end if
    tData.rof[1] = tData.rof[2]
    if t.general.controller = #player then
      tData.Shells[1].resource.emitter.region = [vector(0, 0, -1500)]
    end if
  end if
end

on reset_miniGun me, t
  tmember = t.general.member
  repeat with i in t.Weapons.Minigun
    if i = VOID then
      next repeat
    end if
    if i.ilk = #model then
      tList = [i]
    else
      if i.ilk = #list then
        tList = i
      else
        next repeat
      end if
    end if
    repeat with j in tList
      if j.ilk = #model then
        tmember.deleteModel(j.name)
      end if
    end repeat
  end repeat
  tList = t.Vehicle.Effects
  repeat with i = 1 to tList.count
    tProp = tList.getPropAt(i)
    if tProp = #primary then
      repeat with j in tList[tProp]
        tmember.deleteGroup(j.name)
      end repeat
      tList[tProp] = []
      next repeat
    end if
    next repeat
  end repeat
  if t[#sound] <> VOID then
    t.sound.Mixer.deleteSoundObject(t.sound.primary)
  end if
  t.Weapons.deleteProp(#Minigun)
  t.Weapons.States.deleteOne(#update_minigun)
end

on Setup_DualMiniGun me, t
  tData = gData.data.PrimaryWeapons.DualMiniGun.duplicate()
  t.Weapons[#DualMiniGun] = [#models: [], #rof1: [integer(gGame.tempo / float(tData.rof) * 0.5), integer(gGame.tempo / float(tData.rof))], #rof2: [0.0, integer(gGame.tempo / float(tData.rof))], #ammo: [tData.ammo, tData.ammo], #clips: t.general.data.upgrades.primary[1], #damage: tData.damage, #chargeTime: [0, tData.chargeTime * gGame.tempo]]
  tModelList = BuildWeapon(0, t, #primary, ["DualMiniGun"])
  t.Weapons.DualMiniGun.models = tModelList
  CloneModel(0, gGame.member.name, [#sourceMember: "Weapons", #model: ["DualMiniGunBarrel1", "DualMiniGunBarrel2"], #NameTag: string(t.general.tag), #shaderTag: string(t.general.tag), #lod: 0])
  repeat with i = 1 to 2
    tmodel = gGame.member.model(string(t.general.tag) & "DualMiniGunBarrel" & i)
    tmodel.transform = member("Weapons").model("DualMiniGun").getWorldTransform().inverse() * member("Weapons").model("DualMiniGunBarrel" & i).transform
    tmodel.parent = gGame.member.model(string(t.general.tag) & "DualMiniGun")
    t.Weapons.DualMiniGun[symbol("Barrel" & i)] = tmodel
    if gGame.HideWeapons.getPos(t.Vehicle.name) <> 0 then
      tmodel.visibility = #none
    end if
    tProp = symbol("Flash" & i)
    t.Weapons.DualMiniGun[tProp] = CloneModel(0, t.general.member.name, [#sourceMember: "Weapons", #model: ["DualMiniGunMuzzleFlash" & i], #NameTag: string(t.general.tag), #lod: 0])
    t.Weapons.DualMiniGun[tProp].parent = t.Vehicle.Effects.primary[i]
    t.Weapons.DualMiniGun[tProp].transform.position = vector()
    t.Weapons.DualMiniGun[tProp].transform.scale = vector(0.001, 0.001, 0.001)
    t.Weapons.DualMiniGun[symbol("Flash" & i & "Scale")] = vector(1, 1, 1)
  end repeat
  t.Weapons.DualMiniGun[#Shells] = []
  if t.general.controller = #player then
    t.Weapons.DualMiniGun.Shells.add(CreateParticleSystem(0, t.general.member.name, [#type: symbol("Shells1"), #NameTag: string(t.general.tag) & "Shells"]))
    t.Weapons.DualMiniGun.Shells.add(CreateParticleSystem(0, t.general.member.name, [#type: symbol("Shells2"), #NameTag: string(t.general.tag) & "Shells"]))
    t.Weapons.DualMiniGun.Shells[1].resource.emitter.region = [vector(0, 0, -1500)]
    t.Weapons.DualMiniGun.Shells[2].resource.emitter.region = [vector(0, 0, -1500)]
  end if
  if t[#sound] <> VOID then
    t.sound[#primary] = t.sound.Mixer.createSoundObject("Primary1", member("MiniGun_SFX"), [#loopCount: 0])
    t.sound.primary.play()
    t.sound.primary.volume = 0
  end if
  t.Weapons.DualMiniGun[#bullet1] = CloneModel(0, t.general.member.name, [#sourceMember: "Weapons", #model: ["Bullet"], #NameTag: string(t.general.tag) & "1", #hide: 1, #lod: 0])
  t.Weapons.DualMiniGun[#bullet2] = CloneModel(0, t.general.member.name, [#sourceMember: "Weapons", #model: ["Bullet"], #NameTag: string(t.general.tag) & "2", #hide: 1, #lod: 0])
  t.Weapons.DualMiniGun[#BulletScale1] = 1.0
  t.Weapons.DualMiniGun[#BulletScale2] = 1.0
  if t.Weapons.States.getPos(#update_dualMiniGun) = 0 then
    t.Weapons.States.add(#update_dualMiniGun)
  end if
end

on update_dualMiniGun me, t
  tData = t.Weapons.DualMiniGun
  repeat with i = 1 to 2
    tProp = symbol("Rof" & i)
    tRof = tData[tProp]
    tBullet = tData[symbol("Bullet" & i)]
    tBulletT = tBullet.transform
    tFlash1 = tData[symbol("Flash" & i)].transform
    tFlash1Scale = tData[symbol("Flash" & i & "Scale")]
    tBarrel = tData[symbol("Barrel" & i)]
    tTransform = t.Vehicle.Effects.primary[i].getWorldTransform().duplicate()
    tDirection = tTransform.yAxis
    if t.Input.action1 = 1 then
      if tData.chargeTime[1] < tData.chargeTime[2] then
        tData.chargeTime[1] = tData.chargeTime[1] + gGame.TimeMP
        tBarrel.rotate(vector(0, tData.chargeTime[1] * gGame.TimeMP, 0), #self)
      else
        if tData.ammo[1] > 0 then
          tRof[1] = tRof[1] + gGame.TimeMP
          tBarrel.rotate(vector(0, tData.chargeTime[1] * gGame.TimeMP, 0), #self)
          if tRof[1] >= tRof[2] then
            tRof[1] = 0.0
            if (gGame.UPUnlockableCheats.getPos(#UnlimitedPrimary) <> 0) and (t.general.controller = #player) then
              nothing()
            else
              tData.ammo[1] = tData.ammo[1] - 1
            end if
            if (tData.ammo[1] = 0) and (tData.clips > 0) then
              tData.ammo[1] = tData.ammo[2]
              tData.clips = tData.clips - 1
            end if
            tRandom = random(1000, 1400) * 0.001
            tFlash1Scale = vector(tRandom, tRandom * 1.5, tRandom)
            tFlash1.scale = tFlash1Scale
            tFlash1.rotation.y = random(1, 45)
            if (t[#sound] <> VOID) and (gSound.mute = 0) then
              t.sound.primary.volume = 180
            end if
            tBullet.addToWorld()
            tBullet.transform = tTransform.duplicate()
            tBulletT.scale.y = 100
            tBulletT.position = tTransform.position + (100 * tDirection)
            tData[symbol("BulletScale" & i)] = 100
            tDetails = gGame.Physics.rayCastClosest(tTransform.position, tDirection)
            if tDetails.count > 0 then
              tBulletT.scale.y = max(0.001, tDetails[4])
              tBulletT.position = tTransform.position + (tDetails[4] * tDirection)
              tData[symbol("BulletScale" & i)] = max(0.001, tDetails[4])
              BulletHit(0, t.general.member.name, [#model: tDetails[1].name, #position: tDetails[2], #normal: tDetails[3], #distance: tDetails[4], #damage: random(tData.damage[1], tData.damage[2]), #sender: t.general.tag])
            end if
            if t.general.controller = #player then
              repeat with m = 1 to 2
                tResource = tData.Shells[m].resource
                tResource.emitter.region = [tData[symbol("Barrel" & m)].worldPosition]
              end repeat
            end if
          else
            tPerc = 1.0 - (tRof[1] / tRof[2])
            tPerc = max(tPerc, 0.001)
            tFlash1.scale = tFlash1Scale * tPerc
            tBulletScale = max(0.001, tData[symbol("BulletScale" & i)] * tPerc)
            tBulletT.scale.y = tBulletScale
            if t.general.controller = #player then
              repeat with m = 1 to 2
                tResource = tData.Shells[m].resource
                tResource.emitter.region = [vector(0, 0, -1500)]
              end repeat
            end if
          end if
        else
          tFlash1.scale = vector(0.001, 0.001, 0.001)
          tBulletT.scale = vector(0.001, 0.001, 0.001)
          if (t[#sound] <> VOID) and (gSound.mute = 0) then
            t.sound.primary.volume = 0
          end if
          if t.general.controller = #player then
            repeat with m = 1 to 2
              tResource = tData.Shells[m].resource
              tResource.emitter.region = [vector(0, 0, -1500)]
            end repeat
          end if
        end if
      end if
      next repeat
    end if
    if t.general.controller = #player then
      repeat with m = 1 to 2
        tResource = tData.Shells[m].resource
        tResource.emitter.region = [vector(0, 0, -1500)]
      end repeat
    end if
    tFlash1.scale = vector(0.001, 0.001, 0.001)
    tBulletT.scale = vector(0.001, 0.001, 0.001)
    if tData.chargeTime[1] > 0 then
      tData.chargeTime[1] = tData.chargeTime[1] - gGame.TimeMP
    end if
    tBarrel.rotate(vector(0, tData.chargeTime[1] * gGame.TimeMP, 0), #self)
    if (t[#sound] <> VOID) and (gSound.mute = 0) then
      t.sound.primary.volume = 0
    end if
    if i = 1 then
      tRof[1] = tRof[2] * 0.5
      next repeat
    end if
    tRof[1] = tRof[2]
  end repeat
end

on reset_dualMiniGun me, t
  tmember = t.general.member
  repeat with i in t.Weapons.DualMiniGun
    if i.ilk = #model then
      tList = [i]
    else
      if i.ilk = #list then
        tList = i
      else
        next repeat
      end if
    end if
    repeat with j in tList
      if j.ilk = #model then
        tmember.deleteModel(j.name)
      end if
    end repeat
  end repeat
  tList = t.Vehicle.Effects
  repeat with i = 1 to tList.count
    tProp = tList.getPropAt(i)
    if tProp = #primary then
      repeat with j in tList[tProp]
        tmember.deleteGroup(j.name)
      end repeat
      tList[tProp] = []
      next repeat
    end if
    next repeat
  end repeat
  if t[#sound] <> VOID then
    t.sound.Mixer.deleteSoundObject(t.sound.primary)
  end if
  t.Weapons.deleteProp(#DualMiniGun)
  t.Weapons.States.deleteOne(#update_dualMiniGun)
end

on Setup_Laser me, t
  tData = gData.data.PrimaryWeapons.Laser.duplicate()
  t.Weapons[#Laser] = [#models: [], #fire: #charging, #rof: tData.rof, #ammo: [tData.ammo, tData.ammo], #clips: t.general.data.upgrades.primary[1], #damage: [tData.damage[1], tData.damage[2]], #chargedDamage: 0, #chargeTime: [0, tData.chargeTime]]
  tModelList = BuildWeapon(0, t, #primary, ["Laser"])
  t.Weapons.Laser.models = tModelList
  CloneModel(0, gGame.member.name, [#sourceMember: "Weapons", #model: ["LaserCharge", "LaserBeam"], #NameTag: string(t.general.tag), #shaderTag: string(t.general.tag), #lod: 0])
  tmodel = gGame.member.model(string(t.general.tag) & "LaserCharge")
  tmodel.transform = member("Weapons").model("Laser").getWorldTransform().inverse() * member("Weapons").model("LaserCharge").transform
  tmodel.parent = gGame.member.model(string(t.general.tag) & "Laser")
  tmodel.transform.scale = vector(1, 1, 1) * 0.001
  tmodel.userData.addProp(#parent, tmodel.parent)
  tmodel.userData.addProp(#transform, tmodel.transform.duplicate())
  t.Weapons.Laser[#laserCharge] = tmodel
  tmodel = gGame.member.model(string(t.general.tag) & "LaserBeam")
  tmodel.transform = member("Weapons").model("Laser").getWorldTransform().inverse() * member("Weapons").model("LaserBeam").transform
  tmodel.parent = gGame.member.model(string(t.general.tag) & "Laser")
  tmodel.transform.scale = vector(1, 1, 1) * 0.001
  tmodel.userData.addProp(#parent, tmodel.parent)
  tmodel.userData.addProp(#transform, tmodel.transform.duplicate())
  t.Weapons.Laser[#laserBeam] = tmodel
  t.Weapons.Laser[#laserTrail] = []
  t.Weapons.Laser.laserTrail.add(CreateParticleSystem(0, t.general.member.name, [#type: #laserTrail, #NameTag: string(t.general.tag) & "LaserTrail"]))
  t.Weapons.Laser.laserTrail[1].resource.emitter.region = [vector(0, 0, -1500)]
  if t[#sound] <> VOID then
    t.sound[#primary] = t.sound.Mixer.createSoundObject("Primary", member("Laser_SFX"), [#loopCount: 0])
    t.sound.primary.volume = 0
    t.sound.primary.play()
    t.sound[#primary2] = t.sound.Mixer.createSoundObject("Primary2", member("LaserCharge_SFX"), [#loopCount: 1])
    t.sound.primary2.volume = 180
    t.sound.primary2.stop()
  end if
  if t.Weapons.States.getPos(#update_laser) = 0 then
    t.Weapons.States.add(#update_laser)
  end if
end

on update_laser me, t
  tData = t.Weapons.Laser
  tTransform = t.Vehicle.Effects.primary[1].getWorldTransform().duplicate()
  tDirection = tTransform.yAxis
  tFire = tData.fire
  tCharge = tData.laserCharge
  tBeam = tData.laserBeam
  if (t.Input.action1 = 1) and (tFire <> #blasting) then
    if (tData.chargeTime[1] < tData.chargeTime[2]) and (tData.clips > -1) then
      tData.chargeTime[1] = tData.chargeTime[1] + gGame.TimeMP
      tData.chargedDamage = tData.damage[2] * (tData.chargeTime[1] / tData.chargeTime[2])
      tCharge.transform.scale = vector(1, 1, 1) * (tData.chargeTime[1] / tData.chargeTime[2])
      if (gGame.UPUnlockableCheats.getPos(#UnlimitedPrimary) <> 0) and (t.general.controller = #player) then
        nothing()
      else
        tData.ammo[1] = tData.ammo[1] - (tData.rof * gGame.TimeMP)
      end if
      if tData.ammo[1] <= 0 then
        tdiff = tData.ammo[1]
        tData.ammo[1] = tData.ammo[2] + tdiff
        tData.clips = tData.clips - 1
      end if
      if tData.clips < 0 then
        tData.ammo[1] = 0
        tFire = #blasting
      else
        tFire = #charging
      end if
      if t[#sound] <> VOID then
        t.sound.primary2.play()
      end if
    else
      tFire = #blasting
    end if
    tData.laserTrail[1].resource.emitter.region = [vector(0, 0, -1500)]
  else
    tData.chargedDamage = tData.chargedDamage - (gGame.TimeMP * 0.5)
    if tData.chargedDamage <= 0.0 then
      tData.chargedDamage = 0
      tData.chargeTime[1] = 20
      tData.chargedDamage = 0
      tCharge.transform.scale = vector(1, 1, 1) * 0.001
      tBeam.transform.scale = vector(1, 1, 1) * 0.001
      tFire = #charging
      if t[#sound] <> VOID then
        t.sound.primary.volume = 0
      end if
      tData.laserTrail[1].resource.emitter.region = [vector(0, 0, -1500)]
    else
      tPerc = max(0.001, tData.chargedDamage / tData.damage[2])
      tCharge.transform.scale = vector(1, 1, 1) * tPerc
      tDetails = gGame.Physics.rayCastClosest(tTransform.position, tDirection)
      tBeam.transform.rotation = vector()
      tBeam.transform.scale = vector(1, 1, 1) * tPerc
      tBeam.transform.scale.y = 750.0
      if tDetails.count > 0 then
        BulletHit(0, t.general.member.name, [#model: tDetails[1].name, #position: tDetails[2], #normal: tDetails[3], #distance: tDetails[4], #damage: tData.chargedDamage, #sender: t.general.tag, #fx: 0])
        tBeam.transform.scale.y = tDetails[4] + 0.75
        tData.laserTrail[1].resource.emitter.region = [tDetails[2] + (tDetails[3] * 0.29999999999999999)]
      else
        tData.laserTrail[1].resource.emitter.region = [vector(0, 0, -1500)]
      end if
      if t[#sound] <> VOID then
        t.sound.primary.volume = 180
      end if
      if t[#sound] <> VOID then
        t.sound.primary2.stop()
      end if
      tFire = #blasting
    end if
  end if
  t.Weapons.Laser.fire = tFire
  if t.Vehicle.Health <= 0 then
    tData.chargedDamage = 0
    tData.chargeTime[1] = 20
    tData.chargedDamage = 0
    tCharge.transform.scale = vector(1, 1, 1) * 0.001
    tBeam.transform.scale = vector(1, 1, 1) * 0.001
    tFire = #charging
    if t[#sound] <> VOID then
      t.sound.primary.volume = 0
    end if
    tData.laserTrail[1].resource.emitter.region = [vector(0, 0, -1500)]
  end if
end

on reset_laser me, t
  tmember = t.general.member
  repeat with i in t.Weapons.Laser
    if i = VOID then
      next repeat
    end if
    if i.ilk = #model then
      tList = [i]
    else
      if i.ilk = #list then
        tList = i
      else
        next repeat
      end if
    end if
    repeat with j in tList
      if j.ilk = #model then
        tmember.deleteModel(j.name)
      end if
    end repeat
  end repeat
  tList = t.Vehicle.Effects
  repeat with i = 1 to tList.count
    tProp = tList.getPropAt(i)
    if tProp = #primary then
      repeat with j in tList[tProp]
        tmember.deleteGroup(j.name)
      end repeat
      tList[tProp] = []
      next repeat
    end if
    next repeat
  end repeat
  if t[#sound] <> VOID then
    t.sound.Mixer.deleteSoundObject(t.sound.primary)
  end if
  if t[#sound] <> VOID then
    t.sound.Mixer.deleteSoundObject(t.sound.primary2)
  end if
  t.Weapons.deleteProp(#Laser)
  t.Weapons.States.deleteOne(#update_laser)
end

on Setup_FlameThrower me, t
  tData = gData.data.PrimaryWeapons.FlameThrower.duplicate()
  t.Weapons[#FlameThrower] = [#models: [], #rof: tData.rof, #ammo: [tData.ammo, tData.ammo], #clips: t.general.data.upgrades.primary[1], #damage: tData.damage, #ChargeFlame: [1, 5], #scrolling: [1, 20]]
  tModelList = BuildWeapon(0, t, #primary, ["FlameThrower"])
  t.Weapons.FlameThrower.models = tModelList
  t.Weapons.FlameThrower[#Flame] = CloneModel(0, t.general.member.name, [#sourceMember: "Weapons", #model: "FlameThrowerFlame", #NameTag: string(t.general.tag), #lod: 0])
  t.Weapons.FlameThrower.Flame.parent = t.Vehicle.Effects.primary[1]
  t.Weapons.FlameThrower.Flame.transform.position = vector()
  t.Weapons.FlameThrower.Flame.transform.scale = vector(0.001, 0.001, 0.001)
  t.Weapons.FlameThrower[#FlameScale] = vector(1.0, 3.0, 1.0)
  if t[#sound] <> VOID then
    t.sound[#primary] = t.sound.Mixer.createSoundObject("Primary", member("FlameThrower2_SFX"), [#loopCount: 0])
    t.sound.primary.volume = 0
    t.sound.primary.play()
  end if
  if t.Weapons.States.getPos(#update_FlameThrower) = 0 then
    t.Weapons.States.add(#update_FlameThrower)
  end if
end

on update_FlameThrower me, t
  tData = t.Weapons.FlameThrower
  tTransform = t.Vehicle.Effects.primary[1].getWorldTransform().duplicate()
  tDirection = tTransform.yAxis
  if (t.Input.action1 = 1) and (tData.ammo[1] > 0) then
    if tData.ChargeFlame[1] < tData.ChargeFlame[2] then
      tData.ChargeFlame[1] = tData.ChargeFlame[1] + (1 * gGame.TimeMP)
    end if
    tPerc = float(tData.ChargeFlame[1]) / float(tData.ChargeFlame[2])
    tPerc = min(tPerc, 1.0)
    if tPerc < 0.001 then
      tPerc = 0.001
    end if
    tData.Flame.transform.scale = tData.FlameScale * (tPerc * (random(80, 140) * 0.01))
    tData.Flame.rotate(0, 35 * gGame.TimeMP, 0, #self)
    tDetails = gGame.Physics.rayCastClosest(tTransform.position, tDirection)
    if tDetails.count > 0 then
      tScale = tDetails[4]
      if tScale >= 31.60000000000000142 then
        tScale = 31.60000000000000142
      end if
      tData.Flame.transform.scale.y = max(0.0001, tScale / 10.59999999999999964)
      if tDetails[4] < 31.60000000000000142 then
        BulletHit(0, t.general.member.name, [#model: tDetails[1].name, #position: tDetails[2], #normal: tDetails[3], #distance: tDetails[4], #damage: tData.damage, #sender: t.general.tag, #fx: 0])
      end if
    end if
    if (gGame.UPUnlockableCheats.getPos(#UnlimitedPrimary) <> 0) and (t.general.controller = #player) then
      nothing()
    else
      tData.ammo[1] = tData.ammo[1] - (tData.rof * gGame.TimeMP)
    end if
    if (tData.ammo[1] <= 0) and (tData.clips > 0) then
      tData.ammo[1] = tData.ammo[2]
      tData.clips = tData.clips - 1
    end if
    if t[#sound] <> VOID then
      t.sound.primary.volume = integer(180 * tPerc)
    end if
  else
    if tData.ChargeFlame[1] > 0 then
      tData.ChargeFlame[1] = tData.ChargeFlame[1] - (1 * gGame.TimeMP)
    end if
    if tData.ChargeFlame[1] <= 0 then
      tData.ChargeFlame[1] = 0
    end if
    tPerc = float(tData.ChargeFlame[1]) / float(tData.ChargeFlame[2])
    tPerc = min(tPerc, 1.0)
    if tPerc < 0.001 then
      tPerc = 0.001
    end if
    tData.Flame.transform.scale = tData.FlameScale * tPerc
    if t[#sound] <> VOID then
      t.sound.primary.volume = 0
    end if
  end if
  if t.Vehicle.Health <= 0 then
    tData.Flame.transform.scale = vector(0.001, 0.001, 0.001)
    tData.ChargeFlame[1] = 0
    if t[#sound] <> VOID then
      t.sound.primary.volume = 0
    end if
  end if
end

on reset_flamethrower me, t
  tmember = t.general.member
  repeat with i in t.Weapons.FlameThrower
    if i.ilk = #model then
      tList = [i]
    else
      if i.ilk = #list then
        tList = i
      else
        next repeat
      end if
    end if
    repeat with j in tList
      if j.ilk = #model then
        tmember.deleteModel(j.name)
      end if
    end repeat
  end repeat
  tList = t.Vehicle.Effects
  repeat with i = 1 to tList.count
    tProp = tList.getPropAt(i)
    if tProp = #primary then
      repeat with j in tList[tProp]
        tmember.deleteGroup(j.name)
      end repeat
      tList[tProp] = []
      next repeat
    end if
    next repeat
  end repeat
  if t[#sound] <> VOID then
    t.sound.Mixer.deleteSoundObject(t.sound.primary)
  end if
  t.Weapons.deleteProp(#FlameThrower)
  t.Weapons.States.deleteOne(#update_FlameThrower)
end

on Setup_RocketPod me, t
  tData = gData.data.SecondaryWeapons.RocketPod.duplicate()
  t.Weapons[#RocketPod] = [#models: [], #pod: [0, 2], #rof: [0.0, integer(gGame.tempo / float(tData.rof))], #ammo: [tData.ammo, tData.ammo], #clips: t.general.data.upgrades.secondary[1], #damage: tData.damage, #areaDamage: tData.areaDamage]
  tModelList = BuildWeapon(0, t, #secondary, ["RocketPodLeft", "RocketPodRight"])
  t.Weapons.RocketPod.models = tModelList
  if t.general.member.model("Rocket") = VOID then
    tModelList = CloneModel(0, t.general.member.name, [#sourceMember: "Weapons", #model: ["Rocket", "RocketFlame"], #hide: 1, #lod: 0, #delete: 1])
    BlendShader(0, t.general.member.name, [#shader: "RocketFlame_Material", #blendMode: #add])
  end if
  if t.Weapons.States.getPos(#update_rocketPod) = 0 then
    t.Weapons.States.add(#update_rocketPod)
  end if
end

on update_rocketPod me, t
  tData = t.Weapons.RocketPod
  if t.Input.action2 = 1 then
    tData.rof[1] = tData.rof[1] + gGame.TimeMP
    if tData.rof[1] >= tData.rof[2] then
      tData.rof[1] = 0.0
      if tData.ammo[1] > 0 then
        if (gGame.UPUnlockableCheats.getPos(#UnlimitedSecondary) <> 0) and (t.general.controller = #player) then
          nothing()
        else
          tData.ammo[1] = tData.ammo[1] - 1
        end if
        if (tData.ammo[1] = 0) and (tData.clips > 0) then
          tData.ammo[1] = tData.ammo[2]
          tData.clips = tData.clips - 1
        end if
        tData.pod[1] = tData.pod[1] + 1
        if tData.pod[1] > tData.pod[2] then
          tData.pod[1] = 1
        end if
        tScript = new(script("[PS] Rocket"), t, tData.pod[1])
        if tScript <> VOID then
          gGame.scriptList.add(tScript)
        end if
      end if
    end if
  else
    tData.rof[1] = tData.rof[2]
  end if
end

on reset_rocketPod me, t
  tmember = t.general.member
  repeat with i in t.Weapons.RocketPod
    if i.ilk = #model then
      tList = [i]
    else
      if i.ilk = #list then
        tList = i
      else
        next repeat
      end if
    end if
    repeat with j in tList
      if j.ilk = #model then
        tmember.deleteModel(j.name)
      end if
    end repeat
  end repeat
  tList = t.Vehicle.Effects
  repeat with i = 1 to tList.count
    tProp = tList.getPropAt(i)
    if tProp = #secondary then
      repeat with j in tList[tProp]
        tmember.deleteGroup(j.name)
      end repeat
      tList[tProp] = []
      next repeat
    end if
    next repeat
  end repeat
  t.Weapons.deleteProp(#RocketPod)
  t.Weapons.States.deleteOne(#update_rocketPod)
end

on setup_MineDeployer me, t
  tData = gData.data.SecondaryWeapons.mineDeployer.duplicate()
  t.Weapons[#mineDeployer] = [#models: [], #pod: [0, 2], #rof: [0.0, integer(gGame.tempo / float(tData.rof))], #ammo: [tData.ammo, tData.ammo], #clips: t.general.data.upgrades.secondary[1], #damage: tData.damage, #areaDamage: tData.areaDamage]
  tModelList = BuildWeapon(0, t, #secondary, ["MineDeployer"])
  t.Weapons.mineDeployer.models = tModelList
  if t.general.member.model("Mine") = VOID then
    tModelList = CloneModel(0, t.general.member.name, [#sourceMember: "Weapons", #model: ["Mine"], #hide: 1, #lod: 0, #delete: 1])
  end if
  if t.Weapons.States.getPos(#update_MineDeployer) = 0 then
    t.Weapons.States.add(#update_MineDeployer)
  end if
end

on update_MineDeployer me, t
  tData = t.Weapons.mineDeployer
  if t.Input.action2 = 1 then
    tData.rof[1] = tData.rof[1] + gGame.TimeMP
    if tData.rof[1] >= tData.rof[2] then
      tData.rof[1] = 0.0
      if tData.ammo[1] > 0 then
        if (gGame.UPUnlockableCheats.getPos(#UnlimitedSecondary) <> 0) and (t.general.controller = #player) then
          nothing()
        else
          tData.ammo[1] = tData.ammo[1] - 1
        end if
        if (tData.ammo[1] = 0) and (tData.clips > 0) then
          tData.ammo[1] = tData.ammo[2]
          tData.clips = tData.clips - 1
        end if
        tScript = new(script("[PS] Mine"), t)
        if tScript <> VOID then
          gGame.scriptList.add(tScript)
        end if
      end if
    end if
  else
    tData.rof[1] = tData.rof[2]
  end if
end

on reset_MineDeployer me, t
  tmember = t.general.member
  repeat with i in t.Weapons.mineDeployer
    if i.ilk = #model then
      tList = [i]
    else
      if i.ilk = #list then
        tList = i
      else
        next repeat
      end if
    end if
    repeat with j in tList
      if j.ilk = #model then
        tmember.deleteModel(j.name)
      end if
    end repeat
  end repeat
  tList = t.Vehicle.Effects
  repeat with i = 1 to tList.count
    tProp = tList.getPropAt(i)
    if tProp = #secondary then
      repeat with j in tList[tProp]
        tmember.deleteGroup(j.name)
      end repeat
      tList[tProp] = []
      next repeat
    end if
    next repeat
  end repeat
  t.Weapons.deleteProp(#mineDeployer)
  t.Weapons.States.deleteOne(#update_MineDeployer)
end

on setup_GrenadeDeployer me, t
  tData = gData.data.SecondaryWeapons.GrenadeDeployer.duplicate()
  t.Weapons[#GrenadeDeployer] = [#models: [], #pod: [0, 2], #rof: [0.0, integer(gGame.tempo / float(tData.rof))], #ammo: [tData.ammo, tData.ammo], #clips: t.general.data.upgrades.secondary[1], #damage: tData.damage, #areaDamage: tData.areaDamage]
  tModelList = BuildWeapon(0, t, #secondary, ["GrenadeDeployer"])
  t.Weapons.GrenadeDeployer.models = tModelList
  if t.general.member.model("Grenade1") = VOID then
    tModelList = CloneModel(0, t.general.member.name, [#sourceMember: "Weapons", #model: ["Grenade1"], #hide: 1, #lod: 0, #delete: 1])
  end if
  if t.Weapons.States.getPos(#update_GrenadeDeployer) = 0 then
    t.Weapons.States.add(#update_GrenadeDeployer)
  end if
end

on update_GrenadeDeployer me, t
  tData = t.Weapons.GrenadeDeployer
  if t.Input.action2 = 1 then
    tData.rof[1] = tData.rof[1] + gGame.TimeMP
    if tData.rof[1] >= tData.rof[2] then
      tData.rof[1] = 0.0
      if tData.ammo[1] > 0 then
        if (gGame.UPUnlockableCheats.getPos(#UnlimitedSecondary) <> 0) and (t.general.controller = #player) then
          nothing()
        else
          tData.ammo[1] = tData.ammo[1] - 5
        end if
        if (tData.ammo[1] = 0) and (tData.clips > 0) then
          tData.ammo[1] = tData.ammo[2]
          tData.clips = tData.clips - 1
        end if
        tScript = new(script("[PS] Grenades"), t)
        if tScript <> VOID then
          gGame.scriptList.add(tScript)
        end if
      end if
    end if
  else
    tData.rof[1] = tData.rof[2]
  end if
end

on reset_GrenadeDeployer me, t
  tmember = t.general.member
  repeat with i in t.Weapons.GrenadeDeployer
    if i.ilk = #model then
      tList = [i]
    else
      if i.ilk = #list then
        tList = i
      else
        next repeat
      end if
    end if
    repeat with j in tList
      if j.ilk = #model then
        tmember.deleteModel(j.name)
      end if
    end repeat
  end repeat
  tList = t.Vehicle.Effects
  repeat with i = 1 to tList.count
    tProp = tList.getPropAt(i)
    if tProp = #secondary then
      repeat with j in tList[tProp]
        tmember.deleteGroup(j.name)
      end repeat
      tList[tProp] = []
      next repeat
    end if
    next repeat
  end repeat
  t.Weapons.deleteProp(#GrenadeDeployer)
  t.Weapons.States.deleteOne(#update_GrenadeDeployer)
end

on setup_NitroBoost me, t
  tData = gData.data.SecondaryWeapons.NitroBoost.duplicate()
  t.Weapons[#NitroBoost] = [#models: [], #rof: [0.0, integer(gGame.tempo / float(tData.rof))], #ammo: [tData.ammo, tData.ammo], #clips: t.general.data.upgrades.secondary[1]]
  tModelList = BuildWeapon(0, t, #secondary, ["NitroBoost"])
  t.Weapons.NitroBoost.models = tModelList
  if t[#sound] <> VOID then
    t.sound[#secondary] = t.sound.Mixer.createSoundObject("Secondary", member("NitroBoost_SFX"), [#loopCount: 0])
    t.sound.secondary.volume = 0
    t.sound.secondary.play()
  end if
  if t.Weapons.States.getPos(#update_NitroBoost) = 0 then
    t.Weapons.States.add(#update_NitroBoost)
  end if
end

on update_NitroBoost me, t
  if gGame.NitroOVerride = 1 then
    return 0
  end if
  tData = t.Weapons.NitroBoost
  if t.Input.action2 = 1 then
    tData.rof[1] = tData.rof[1] + gGame.TimeMP
    if tData.rof[1] >= tData.rof[2] then
      tData.rof[1] = 0.0
      if tData.ammo[1] > 0 then
        if (gGame.UPUnlockableCheats.getPos(#UnlimitedSecondary) <> 0) and (t.general.controller = #player) then
          nothing()
        else
          tData.ammo[1] = tData.ammo[1] - 1
        end if
        if (tData.ammo[1] = 0) and (tData.clips > 0) then
          tData.ammo[1] = tData.ammo[2]
          tData.clips = tData.clips - 1
        end if
        if t.Vehicle.Nitro = 0 then
          PlaySound(0, "NitroPickup_SFX", [#Override: 1, #priority: #low])
        end if
        t.Vehicle.Nitro = 1
        gGame.camera[1][#fov] = 75.0
      else
        t.Vehicle.Nitro = 0
      end if
    else
      tData.rof[1] = tData.rof[2]
    end if
    if t[#sound] <> VOID then
      t.sound.secondary.volume = 255
    end if
  else
    t.Vehicle.Nitro = 0
    gGame.camera[1][#fov] = 55.0
    if t[#sound] <> VOID then
      t.sound.secondary.volume = 0
    end if
  end if
end

on reset_NitroBoost me, t
  tmember = t.general.member
  repeat with i in t.Weapons.NitroBoost
    if i.ilk = #model then
      tList = [i]
    else
      if i.ilk = #list then
        tList = i
      else
        next repeat
      end if
    end if
    repeat with j in tList
      if j.ilk = #model then
        tmember.deleteModel(j.name)
      end if
    end repeat
  end repeat
  tList = t.Vehicle.Effects
  repeat with i = 1 to tList.count
    tProp = tList.getPropAt(i)
    if tProp = #secondary then
      repeat with j in tList[tProp]
        tmember.deleteGroup(j.name)
      end repeat
      tList[tProp] = []
      next repeat
    end if
    next repeat
  end repeat
  if t[#sound] <> VOID then
    t.sound.Mixer.deleteSoundObject(t.sound.secondary)
  end if
  t.Weapons.deleteProp(#NitroBoost)
  t.Weapons.States.deleteOne(#update_NitroBoost)
end

on setup_GrenadeLauncher me, t
  tData = gData.data.SecondaryWeapons.GrenadeLauncher.duplicate()
  t.Weapons[#GrenadeLauncher] = [#models: [], #pod: [0, 2], #rof: [0.0, integer(gGame.tempo / float(tData.rof))], #ammo: [tData.ammo, tData.ammo], #clips: t.general.data.upgrades.secondary[1], #damage: tData.damage, #areaDamage: tData.areaDamage]
  tModelList = BuildWeapon(0, t, #secondary, ["GrenadeLauncher"])
  t.Weapons.GrenadeLauncher.models = tModelList
  if t.general.member.model("Grenade") = VOID then
    tModelList = CloneModel(0, t.general.member.name, [#sourceMember: "Weapons", #model: ["Grenade"], #hide: 1, #lod: 0, #delete: 1])
  end if
  t.Weapons.GrenadeLauncher[#flash] = CloneModel(0, t.general.member.name, [#sourceMember: "Weapons", #model: ["GrenadeLauncherMuzzleFlash"], #NameTag: string(t.general.tag), #lod: 0])
  t.Weapons.GrenadeLauncher.flash.transform = t.Vehicle.Effects.secondary[1].transform
  t.Weapons.GrenadeLauncher.flash.parent = t.Vehicle.Effects.secondary[1]
  t.Weapons.GrenadeLauncher.flash.transform.position = vector()
  t.Weapons.GrenadeLauncher.flash.transform.scale = vector(0.001, 0.001, 0.001)
  t.Weapons.GrenadeLauncher[#FlashScale] = vector(1, 1, 1)
  if t.Weapons.States.getPos(#update_GrenadeLauncher) = 0 then
    t.Weapons.States.add(#update_GrenadeLauncher)
  end if
end

on update_GrenadeLauncher me, t
  tData = t.Weapons.GrenadeLauncher
  tFlash = tData.flash.transform
  if t.Input.action2 = 1 then
    if tData.ammo[1] > 0 then
      tData.rof[1] = tData.rof[1] + gGame.TimeMP
      if tData.rof[1] >= tData.rof[2] then
        tData.rof[1] = 0
        if (gGame.UPUnlockableCheats.getPos(#UnlimitedSecondary) <> 0) and (t.general.controller = #player) then
          nothing()
        else
          tData.ammo[1] = tData.ammo[1] - 1
        end if
        if (tData.ammo[1] = 0) and (tData.clips > 0) then
          tData.ammo[1] = tData.ammo[2]
          tData.clips = tData.clips - 1
        end if
        tRandom = random(2000, 2400) * 0.001
        tData.FlashScale = vector(tRandom, tRandom * 1.5, tRandom)
        tFlash.scale = tData.FlashScale
        tFlash.rotation.y = random(1, 45)
        tScript = new(script("[PS] Grenade"), t)
        if tScript <> VOID then
          gGame.scriptList.add(tScript)
        end if
      else
        if tData.rof[1] <= 3 then
          tPerc = 1.0 - (tData.rof[1] / 3)
          tPerc = max(tPerc, 0.001)
          tScaleXZ = tData.FlashScale.x * tPerc
          tScaleXZ = max(tScaleXZ, 0.001)
          if tScaleXZ = 0.001 then
            tScale = vector(tScaleXZ, tScaleXZ, tScaleXZ)
          else
            tScale = vector(tScaleXZ, tScaleXZ * 5, tScaleXZ)
          end if
          tFlash.scale = tScale
        else
          tFlash.scale = vector(0.001, 0.001, 0.001)
        end if
      end if
    else
      if tData.rof[1] <= 3 then
        tPerc = 1.0 - (tData.rof[1] / 3)
        tPerc = max(tPerc, 0.001)
        tScaleXZ = tData.FlashScale.x * tPerc
        tScaleXZ = max(tScaleXZ, 0.001)
        if tScaleXZ = 0.001 then
          tScale = vector(tScaleXZ, tScaleXZ, tScaleXZ)
        else
          tScale = vector(tScaleXZ, tScaleXZ * 5, tScaleXZ)
        end if
        tFlash.scale = tScale
      else
        tFlash.scale = vector(0.001, 0.001, 0.001)
      end if
    end if
  else
    if tData.rof[1] <= 3 then
      tPerc = 1.0 - (tData.rof[1] / 3)
      tPerc = max(tPerc, 0.001)
      tScaleXZ = tData.FlashScale.x * tPerc
      tScaleXZ = max(tScaleXZ, 0.001)
      if tScaleXZ = 0.001 then
        tScale = vector(tScaleXZ, tScaleXZ, tScaleXZ)
      else
        tScale = vector(tScaleXZ, tScaleXZ * 5, tScaleXZ)
      end if
    else
      tFlash.scale = vector(0.001, 0.001, 0.001)
    end if
    tData.rof[1] = tData.rof[2]
  end if
end

on reset_GrenadeLauncher me, t
  tmember = t.general.member
  repeat with i in t.Weapons.GrenadeLauncher
    if i.ilk = #model then
      tList = [i]
    else
      if i.ilk = #list then
        tList = i
      else
        next repeat
      end if
    end if
    repeat with j in tList
      if j.ilk = #model then
        tmember.deleteModel(j.name)
      end if
    end repeat
  end repeat
  tList = t.Vehicle.Effects
  repeat with i = 1 to tList.count
    tProp = tList.getPropAt(i)
    if tProp = #secondary then
      repeat with j in tList[tProp]
        tmember.deleteGroup(j.name)
      end repeat
      tList[tProp] = []
      next repeat
    end if
    next repeat
  end repeat
  t.Weapons.deleteProp(#GrenadeLauncher)
  t.Weapons.States.deleteOne(#update_GrenadeLauncher)
end

on setup_airstrikeLauncher me, t
  tData = gData.data.SecondaryWeapons.AirstrikeLauncher.duplicate()
  t.Weapons[#AirstrikeLauncher] = [#models: [], #delay: [0, 45], #fire: 1, #rof: [0.0, integer(gGame.tempo / float(tData.rof))], #ammo: [tData.ammo, tData.ammo], #clips: t.general.data.upgrades.secondary[1], #damage: tData.damage, #areaDamage: tData.areaDamage]
  tModelList = BuildWeapon(0, t, #secondary, ["AirstrikeLauncher"])
  t.Weapons.AirstrikeLauncher.models = tModelList
  if t.general.member.model("AirstrikeBeacon") = VOID then
    t.Weapons.AirstrikeLauncher[#airstrikeBeacon] = CloneModel(0, t.general.member.name, [#sourceMember: "Weapons", #model: ["AirstrikeBeacon"], #hide: 1, #lod: 0])
  else
    t.Weapons.AirstrikeLauncher[#airstrikeBeacon] = t.general.member.model("AirstrikeBeacon")
  end if
  if t.Weapons.States.getPos(#update_AirstrikeLauncher) = 0 then
    t.Weapons.States.add(#update_AirstrikeLauncher)
  end if
end

on update_AirstrikeLauncher me, t
  tData = t.Weapons.AirstrikeLauncher
  tDelay = tData.delay[1]
  tFire = tData.fire
  if tDelay > 0 then
    tDelay = tDelay - (1 * gGame.TimeMP)
    tDelay = max(0, tDelay)
    if tDelay = 0 then
      tFire = 1
    end if
  end if
  if (tData.ammo[1] > 0) and (tData.ammo[1] > 0) then
    if (t.Input.action2 = 1) and (tDelay = 0) and (tFire = 1) then
      tScript = new(script("[PS] Airstrike Beacon"), t)
      if tScript <> VOID then
        gGame.scriptList.add(tScript)
      end if
      tFire = 0
      tDelay = t.Weapons.AirstrikeLauncher.delay[2]
      if (gGame.UPUnlockableCheats.getPos(#UnlimitedSecondary) <> 0) and (t.general.controller = #player) then
        nothing()
      else
        tData.ammo[1] = tData.ammo[1] - 1
      end if
      if tData.ammo[1] = 0 then
        if tData.clips > 0 then
          tData.ammo[1] = tData.ammo[2]
          tData.clips = tData.clips - 1
        end if
      end if
    end if
  end if
  tData.delay[1] = tDelay
  tData.fire = tFire
end

on reset_AirStrikeLauncher me, t
  tmember = t.general.member
  repeat with i in t.Weapons.AirstrikeLauncher
    if i.ilk = #model then
      tList = [i]
    else
      if i.ilk = #list then
        tList = i
      else
        next repeat
      end if
    end if
    repeat with j in tList
      if j.ilk = #model then
        tmember.deleteModel(j.name)
      end if
    end repeat
  end repeat
  tList = t.Vehicle.Effects
  repeat with i = 1 to tList.count
    tProp = tList.getPropAt(i)
    if tProp = #secondary then
      repeat with j in tList[tProp]
        tmember.deleteGroup(j.name)
      end repeat
      tList[tProp] = []
      next repeat
    end if
    next repeat
  end repeat
  t.Weapons.deleteProp(#AirstrikeLauncher)
  t.Weapons.States.deleteOne(#update_AirstrikeLauncher)
end

on Setup_MainGun me, t
  tData = gData.data.SecondaryWeapons.MainGun.duplicate()
  t.Weapons[#MainGun] = [#models: [], #rof: [0.0, integer(gGame.tempo / float(tData.rof))], #ammo: [tData.ammo, tData.ammo], #clips: t.general.data.upgrades.secondary[1], #damage: tData.damage, #areaDamage: tData.areaDamage]
  if t.general.member.model("Shell") = VOID then
    tModelList = CloneModel(0, t.general.member.name, [#sourceMember: "Weapons", #model: ["Shell"], #hide: 1, #lod: 0, #delete: 1])
  end if
  tModelList = BuildWeapon(0, t, #secondary, ["MainGun"])
  t.Weapons.MainGun.models = tModelList
  t.Weapons.MainGun[#flash] = CloneModel(0, t.general.member.name, [#sourceMember: "Weapons", #model: ["MainGunMuzzleFlash1"], #NameTag: string(t.general.tag), #lod: 0])
  t.Weapons.MainGun.flash.transform = t.Vehicle.Effects.secondary[1].transform
  t.Weapons.MainGun.flash.parent = t.Vehicle.Effects.secondary[1]
  t.Weapons.MainGun.flash.transform.position = vector()
  t.Weapons.MainGun.flash.transform.scale = vector(0.001, 0.001, 0.001)
  t.Weapons.MainGun[#FlashScale] = vector(1, 1, 1)
  t.Vehicle.Effects.primary[1].parent = gGame.member.model(string(t.general.tag) & "Glass")
  t.Vehicle.Effects.secondary[1].parent = gGame.member.model(string(t.general.tag) & "Glass")
  t.Vehicle.Effects.primary[1].transform.rotation = vector(-0.69999999999999996, 0, 0)
  t.Vehicle.Effects.secondary[1].transform.rotation = vector(-0.69999999999999996, 0, 0)
  if t.Weapons.States.getPos(#update_MainGun) = 0 then
    t.Weapons.States.add(#update_MainGun)
  end if
end

on update_MainGun me, t
  tData = t.Weapons.MainGun
  tTransform = t.Vehicle.Effects.secondary[1].getWorldTransform().duplicate()
  tDirection = tTransform.yAxis
  tFlash = tData.flash.transform
  if t.Input.action2 = 1 then
    if tData.ammo[1] > 0 then
      tData.rof[1] = tData.rof[1] + gGame.TimeMP
      if tData.rof[1] >= tData.rof[2] then
        tData.rof[1] = 0
        if (gGame.UPUnlockableCheats.getPos(#UnlimitedSecondary) <> 0) and (t.general.controller = #player) then
          nothing()
        else
          tData.ammo[1] = tData.ammo[1] - 1
        end if
        if (tData.ammo[1] = 0) and (tData.clips > 0) then
          tData.ammo[1] = tData.ammo[2]
          tData.clips = tData.clips - 1
        end if
        tRandom = random(2000, 2400) * 0.001
        tData.FlashScale = vector(tRandom, tRandom * 1.5, tRandom)
        tFlash.scale = tData.FlashScale
        tFlash.rotation.y = random(1, 45)
        tDetails = gGame.Physics.rayCastClosest(tTransform.position, tDirection)
        if tDetails.count > 0 then
          tScript = new(script("[PS] Shell"), t)
          if tScript <> VOID then
            gGame.scriptList.add(tScript)
          end if
        end if
      else
        if tData.rof[1] <= 3 then
          tPerc = 1.0 - (tData.rof[1] / 3)
          tPerc = max(tPerc, 0.001)
          tScaleXZ = tData.FlashScale.x * tPerc
          tScaleXZ = max(tScaleXZ, 0.001)
          if tScaleXZ = 0.001 then
            tScale = vector(tScaleXZ, tScaleXZ, tScaleXZ)
          else
            tScale = vector(tScaleXZ, tScaleXZ * 7, tScaleXZ)
          end if
          tFlash.scale = tScale
        end if
      end if
    else
      if tData.rof[1] <= 3 then
        tPerc = 1.0 - (tData.rof[1] / 3)
        tPerc = max(tPerc, 0.001)
        tScaleXZ = tData.FlashScale.x * tPerc
        tScaleXZ = max(tScaleXZ, 0.001)
        if tScaleXZ = 0.001 then
          tScale = vector(tScaleXZ, tScaleXZ, tScaleXZ)
        else
          tScale = vector(tScaleXZ, tScaleXZ * 7, tScaleXZ)
        end if
        tFlash.scale = tScale
      end if
    end if
  else
    if tData.rof[1] <= 3 then
      tPerc = 1.0 - (tData.rof[1] / 3)
      tPerc = max(tPerc, 0.001)
      tScaleXZ = tData.FlashScale.x * tPerc
      tScaleXZ = max(tScaleXZ, 0.001)
      if tScaleXZ = 0.001 then
        tScale = vector(tScaleXZ, tScaleXZ, tScaleXZ)
      else
        tScale = vector(tScaleXZ, tScaleXZ * 7, tScaleXZ)
      end if
    else
      tFlash.scale = vector(0.001, 0.001, 0.001)
    end if
    tData.rof[1] = tData.rof[2]
  end if
  if t.Vehicle.Health <= 0 then
    tFlash.scale = vector(0.001, 0.001, 0.001)
  end if
end

on Reset_MainGun me, t
  tmember = t.general.member
  repeat with i in t.Weapons.MainGun
    if i.ilk = #model then
      tList = [i]
    else
      if i.ilk = #list then
        tList = i
      else
        next repeat
      end if
    end if
    repeat with j in tList
      if j.ilk = #model then
        tmember.deleteModel(j.name)
      end if
    end repeat
  end repeat
  tList = t.Vehicle.Effects
  repeat with i = 1 to tList.count
    tProp = tList.getPropAt(i)
    if tProp = #secondary then
      repeat with j in tList[tProp]
        tmember.deleteGroup(j.name)
      end repeat
      tList[tProp] = []
      next repeat
    end if
    next repeat
  end repeat
  t.Weapons.deleteProp(#MainGun)
  t.Weapons.States.deleteOne(#update_MainGun)
end

on Setup_AC130AutoGun1 me, t
  tData = gData.data.primary2Weapons.AC130AutoGun1.duplicate()
  t.Weapons[#AC130AutoGun1] = [#models: [], #rof: [0.0, integer(gGame.tempo / float(tData.rof))], #ammo: [tData.ammo, tData.ammo], #clips: t.general.data.upgrades.primary[1], #damage: tData.damage, #chargeTime: [0, tData.chargeTime * gGame.tempo]]
  tModelList = BuildWeapon(0, t, #primary2, ["AC130AutoGun1"])
  t.Weapons.AC130AutoGun1.models = tModelList
  t.Weapons.AC130AutoGun1[#Flash1] = CloneModel(0, t.general.member.name, [#sourceMember: "Weapons", #model: ["AC130AutoGun1Flash1"], #NameTag: string(t.general.tag), #lod: 0])
  t.Weapons.AC130AutoGun1.Flash1.parent = t.Vehicle.Effects.primary2[1]
  t.Weapons.AC130AutoGun1.Flash1.transform.position = vector()
  t.Weapons.AC130AutoGun1.Flash1.transform.scale = vector(0.001, 0.001, 0.001)
  t.Weapons.AC130AutoGun1[#Flash1Scale] = vector(1, 1, 1)
  if t[#sound] <> VOID then
    t.sound[#primary2] = t.sound.Mixer.createSoundObject("Primary2", member("MiniGun_SFX"), [#loopCount: 0])
    t.sound.primary2.volume = 0
    t.sound.primary2.play()
  end if
  t.Weapons.AC130AutoGun1[#Bullet] = CloneModel(0, t.general.member.name, [#sourceMember: "Weapons", #model: ["Bullet"], #NameTag: string(t.general.tag), #hide: 1, #lod: 0])
  t.Weapons.AC130AutoGun1[#BulletScale] = 1.0
  if t.Weapons.States.getPos(#Update_AC130AutoGun1) = 0 then
    t.Weapons.States.add(#Update_AC130AutoGun1)
  end if
end

on Update_AC130AutoGun1 me, t
  tData = t.Weapons.AC130AutoGun1
  tShoot = 1
  tgroup = t.Vehicle.Effects.primary2[1]
  tCurrentT = tgroup.transform.duplicate()
  tgroup.pointAtOrientation = [vector(0.0, 1.0, 0.0), vector(0.0, 0.0, 1.0)]
  tgroup.pointAt(gGame.vehicles[1].Vehicle.group.worldPosition)
  tTargetT = tgroup.transform.duplicate()
  tCurrentT.interpolateTo(tTargetT, 5)
  tgroup.transform = tCurrentT
  tTransform = tgroup.getWorldTransform().duplicate()
  tDirection = tTransform.yAxis
  tBullet = tData.Bullet
  tBulletT = tBullet.transform
  tFlash1 = tData.Flash1.transform
  if tShoot = 1 then
    if tData.chargeTime[1] < tData.chargeTime[2] then
      tData.chargeTime[1] = tData.chargeTime[1] + gGame.TimeMP
    else
      if tData.ammo[1] > 0 then
        tData.rof[1] = tData.rof[1] + gGame.TimeMP
        if tData.rof[1] >= tData.rof[2] then
          tData.rof[1] = 0
          if (tData.ammo[1] = 0) and (tData.clips > 0) then
            tData.ammo[1] = tData.ammo[2]
            tData.clips = tData.clips - 1
          end if
          tRandom = random(1000, 1400) * 0.001
          tData.Flash1Scale = vector(tRandom, tRandom * 1.5, tRandom)
          tFlash1.scale = tData.Flash1Scale
          tFlash1.rotation.y = random(1, 45)
          if (t[#sound] <> VOID) and (gSound.mute = 0) then
            t.sound.primary2.volume = 180
          end if
          tBullet.addToWorld()
          tBullet.transform = tTransform.duplicate()
          tBulletT.scale.y = 1000
          tBulletT.position = tTransform.position + (100 * tDirection)
          tData.BulletScale = 1000
          tDetails = gGame.Physics.rayCastClosest(tTransform.position, tDirection)
          if tDetails.count > 0 then
            tBulletT.scale.y = max(0.001, tDetails[4])
            tBulletT.position = tTransform.position + (tDetails[4] * tDirection)
            tData.BulletScale = max(0.001, tDetails[4])
            if tDetails[1].name <> string(t.Vehicle.Proxy.name) then
              BulletHit(0, t.general.member.name, [#model: tDetails[1].name, #position: tDetails[2], #normal: tDetails[3], #distance: tDetails[4], #damage: random(tData.damage[1], tData.damage[2]), #sender: t.general.tag, #fx: 0])
            end if
          end if
        else
          tPerc = 1.0 - (tData.rof[1] / tData.rof[2])
          tPerc = max(tPerc, 0.001)
          tFlash1.scale = tData.Flash1Scale * tPerc
          tBulletScale = max(0.001, tData.BulletScale * tPerc)
          tBulletT.scale.y = tBulletScale
        end if
      else
        if (t[#sound] <> VOID) and (gSound.mute = 0) then
          t.sound.primary2.volume = 0
        end if
        tFlash1.scale = vector(0.001, 0.001, 0.001)
        tBulletT.scale = vector(0.001, 0.001, 0.001)
      end if
    end if
  else
    if tData.chargeTime[1] > 0 then
      tData.chargeTime[1] = tData.chargeTime[1] - gGame.TimeMP
    end if
    tFlash1.scale = vector(0.001, 0.001, 0.001)
    tBulletT.scale = vector(0.001, 0.001, 0.001)
    if (t[#sound] <> VOID) and (gSound.mute = 0) then
      t.sound.primary2.volume = 0
    end if
    tData.rof[1] = tData.rof[2]
  end if
end

on reset_AC130AutoGun1 me, t
  tmember = t.general.member
  repeat with i in t.Weapons.AC130AutoGun1
    if i.ilk = #model then
      tList = [i]
    else
      if i.ilk = #list then
        tList = i
      else
        next repeat
      end if
    end if
    repeat with j in tList
      if j.ilk = #model then
        tmember.deleteModel(j.name)
      end if
    end repeat
  end repeat
  tList = t.Vehicle.Effects
  repeat with i = 1 to tList.count
    tProp = tList.getPropAt(i)
    if tProp = #secondary then
      repeat with j in tList[tProp]
        tmember.deleteGroup(j.name)
      end repeat
      tList[tProp] = []
      next repeat
    end if
    next repeat
  end repeat
  t.Weapons.deleteProp(#AC130AutoGun1)
  t.Weapons.States.deleteOne(#AC130AutoGun1)
end

on Setup_AC130AutoGun2 me, t
  tData = gData.data.Primary3Weapons.AC130AutoGun2.duplicate()
  t.Weapons[#AC130AutoGun2] = [#models: [], #rof: [0.0, integer(gGame.tempo / float(tData.rof))], #ammo: [tData.ammo, tData.ammo], #clips: t.general.data.upgrades.primary[1], #damage: tData.damage, #chargeTime: [0, tData.chargeTime * gGame.tempo]]
  tModelList = BuildWeapon(0, t, #primary3, ["AC130AutoGun2"])
  t.Weapons.AC130AutoGun2.models = tModelList
  t.Weapons.AC130AutoGun2[#Flash1] = CloneModel(0, t.general.member.name, [#sourceMember: "Weapons", #model: ["AC130AutoGun2Flash1"], #NameTag: string(t.general.tag), #lod: 0])
  t.Weapons.AC130AutoGun2.Flash1.parent = t.Vehicle.Effects.primary3[1]
  t.Weapons.AC130AutoGun2.Flash1.transform.position = vector()
  t.Weapons.AC130AutoGun2.Flash1.transform.scale = vector(0.001, 0.001, 0.001)
  t.Weapons.AC130AutoGun2[#Flash1Scale] = vector(1, 1, 1)
  if t[#sound] <> VOID then
    t.sound[#primary3] = t.sound.Mixer.createSoundObject("Primary3", member("MiniGun_SFX"), [#loopCount: 0])
    t.sound.primary3.volume = 0
    t.sound.primary3.play()
  end if
  t.Weapons.AC130AutoGun2[#Bullet] = CloneModel(0, t.general.member.name, [#sourceMember: "Weapons", #model: ["Bullet"], #NameTag: string(t.general.tag) & "EXTRA", #hide: 1, #lod: 0])
  t.Weapons.AC130AutoGun2[#BulletScale] = 1.0
  if t.Weapons.States.getPos(#update_AC130AutoGun2) = 0 then
    t.Weapons.States.add(#update_AC130AutoGun2)
  end if
end

on update_AC130AutoGun2 me, t
  tData = t.Weapons.AC130AutoGun2
  tShoot = 1
  tgroup = t.Vehicle.Effects.primary3[1]
  tCurrentT = tgroup.transform.duplicate()
  tgroup.pointAtOrientation = [vector(0.0, 1.0, 0.0), vector(0.0, 0.0, 1.0)]
  tgroup.pointAt(gGame.vehicles[1].Vehicle.group.worldPosition)
  tTargetT = tgroup.transform.duplicate()
  tCurrentT.interpolateTo(tTargetT, 5)
  tgroup.transform = tCurrentT
  tTransform = tgroup.getWorldTransform().duplicate()
  tDirection = tTransform.yAxis
  tBullet = tData.Bullet
  tBulletT = tBullet.transform
  tFlash1 = tData.Flash1.transform
  if tShoot = 1 then
    if tData.chargeTime[1] < tData.chargeTime[2] then
      tData.chargeTime[1] = tData.chargeTime[1] + gGame.TimeMP
    else
      if tData.ammo[1] > 0 then
        tData.rof[1] = tData.rof[1] + gGame.TimeMP
        if tData.rof[1] >= tData.rof[2] then
          tData.rof[1] = 0
          if (tData.ammo[1] = 0) and (tData.clips > 0) then
            tData.ammo[1] = tData.ammo[2]
            tData.clips = tData.clips - 1
          end if
          tRandom = random(1000, 1400) * 0.001
          tData.Flash1Scale = vector(tRandom, tRandom * 1.5, tRandom)
          tFlash1.scale = tData.Flash1Scale
          tFlash1.rotation.y = random(1, 45)
          if (t[#sound] <> VOID) and (gSound.mute = 0) then
            t.sound.primary3.volume = 180
          end if
          tBullet.addToWorld()
          tBullet.transform = tTransform.duplicate()
          tBulletT.scale.y = 1000
          tBulletT.position = tTransform.position + (100 * tDirection)
          tData.BulletScale = 1000
          tDetails = gGame.Physics.rayCastClosest(tTransform.position, tDirection)
          if tDetails.count > 0 then
            tBulletT.scale.y = max(0.001, tDetails[4])
            tBulletT.position = tTransform.position + (tDetails[4] * tDirection)
            tData.BulletScale = max(0.001, tDetails[4])
            if tDetails[1].name <> string(t.Vehicle.Proxy.name) then
              BulletHit(0, t.general.member.name, [#model: tDetails[1].name, #position: tDetails[2], #normal: tDetails[3], #distance: tDetails[4], #damage: random(tData.damage[1], tData.damage[2]), #sender: t.general.tag, #fx: 0])
            end if
          end if
        else
          tPerc = 1.0 - (tData.rof[1] / tData.rof[2])
          tPerc = max(tPerc, 0.001)
          tFlash1.scale = tData.Flash1Scale * tPerc
          tBulletScale = max(0.001, tData.BulletScale * tPerc)
          tBulletT.scale.y = tBulletScale
        end if
      else
        if (t[#sound] <> VOID) and (gSound.mute = 0) then
          t.sound.primary3.volume = 0
        end if
        tFlash1.scale = vector(0.001, 0.001, 0.001)
        tBulletT.scale = vector(0.001, 0.001, 0.001)
      end if
    end if
  else
    if tData.chargeTime[1] > 0 then
      tData.chargeTime[1] = tData.chargeTime[1] - gGame.TimeMP
    end if
    tFlash1.scale = vector(0.001, 0.001, 0.001)
    tBulletT.scale = vector(0.001, 0.001, 0.001)
    if (t[#sound] <> VOID) and (gSound.mute = 0) then
      t.sound.primary3.volume = 0
    end if
    tData.rof[1] = tData.rof[2]
  end if
end

on Reset_AC130AutoGun2 me, t
  tmember = t.general.member
  repeat with i in t.Weapons.AC130AutoGun2
    if i.ilk = #model then
      tList = [i]
    else
      if i.ilk = #list then
        tList = i
      else
        next repeat
      end if
    end if
    repeat with j in tList
      if j.ilk = #model then
        tmember.deleteModel(j.name)
      end if
    end repeat
  end repeat
  tList = t.Vehicle.Effects
  repeat with i = 1 to tList.count
    tProp = tList.getPropAt(i)
    if tProp = #secondary then
      repeat with j in tList[tProp]
        tmember.deleteGroup(j.name)
      end repeat
      tList[tProp] = []
      next repeat
    end if
    next repeat
  end repeat
  t.Weapons.deleteProp(#AC130AutoGun2)
  t.Weapons.States.deleteOne(#AC130AutoGun2)
end
