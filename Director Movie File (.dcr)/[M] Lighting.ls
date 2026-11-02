-- [Script] [M] Lighting (Script #5925)
-- Script Type: Movie

on SetupLighting tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return
  end if
  tLight = tmember.light("Default MAX Light")
  if not (tLight = VOID) then
    tmember.deleteLight("Default MAX Light")
  end if
  tNewLight = tmember.newLight("SunLight")
  tNewLight.type = #directional
  tNewLight.color = rgb(255, 255, 255)
  tPosition = vector(0, 0, 100)
  tRotation = vector(0, 0, 0)
  assetString = "City"
  case tTarget of
    "CityAssets":
      position = vector(-250, 250, 150)
      rotation = vector(63, 0, 124)
      emColor = rgb(152, 143, 137)
      assetString = "City"
    "SnowAssets":
      position = vector(125, 125, 125)
      rotation = vector(55, 0, -135)
      emColor = rgb(122, 115, 97)
      assetString = "Snow"
    "JungleAssets":
      position = vector(-125, -65, 125)
      rotation = vector(48, 0, 63)
      emColor = rgb(150, 144, 130)
      assetString = "Jungle"
    "DesertAssets":
      position = vector(-170, 0, 320)
      rotation = vector(30, 0, 90)
      emColor = rgb(171, 171, 180)
      assetString = "Desert"
  end case
  SetShader(0, tTarget, [#shader: assetString & "Buildings_Material", #emissive: emColor])
  SetShader(0, tTarget, [#shader: assetString & "Street_Material", #emissive: emColor])
  SetShader(0, tTarget, [#shader: assetString & "Opaque_Material", #emissive: emColor])
  SetShader(0, tTarget, [#shader: assetString & "Transparent_Material", #emissive: emColor])
  SetShader(0, tTarget, [#shader: "Misc_Material", #emissive: emColor])
  SetShader(0, tTarget, [#shader: "Advertisements_Material", #emissive: emColor])
  SetShader(0, tTarget, [#shader: "Waves_Material", #emissive: emColor])
  tNewLight.transform.position = position
  tNewLight.transform.rotation = rotation
end
