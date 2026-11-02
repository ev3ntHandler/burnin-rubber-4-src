-- [Script] [M] Mods (Script #5924)
-- Script Type: Movie

global fx, gGame

on LoadExternalTextures me
  put "LOADING EXTERNAL TEXTURES"
  SourceList = ["PhaserGTI", "PantherV8", "DXTurbo", "Viral", "Hound", "GTBlaze", "Sunstorm", "PetiteXS", "Rebel", "Inferno66", "Rally7", "BTOne", "AbrahamN1", "Coyote", "Jumper", "Giant", "Coyote", "Tank"]
  TargetList = ["BMW", "AstonMartin", "AudiR8", "Corvette", "DodgeRam", "FordGT", "Marcos", "MiniCooper", "Mustang", "Porsche", "Seat", "BlackTruck", "Tank", "Apache", "Eclipse", "Nissan", "Apache", "Tank"]
  fx = xtra("FileXtra4").new()
  repeat with sourceEntry in SourceList
    repeat with i = 1 to 2
      fileExists = fx.fx_FileExists(_movie.path & "Data\Cars\Mods\" & sourceEntry & "Skin" & i & "_Texture.png")
      Pos = SourceList.getPos(sourceEntry)
      memberRef = member(TargetList[Pos] & "Skin" & i & "_Texture")
      if memberRef = VOID then
        next repeat
      end if
      memberRefName = memberRef.name
      if fileExists then
        memberRef.importFileInto(_movie.path & "Data\Cars\Mods\" & sourceEntry & "Skin" & i & "_Texture.png", [#dither: 0, #trimWhiteSpace: 0, #linked: 1, #remapImageToStage: 0])
        memberRef.name = memberRefName
        memberRef.purgePriority = 0
        put _movie.path & "Data\Cars\Mods\" & sourceEntry & "Skin" & i & "_Texture.png " & "IMPORTED INTO " & memberRefName
      end if
    end repeat
  end repeat
  fileExists = fx.fx_FileExists(_movie.path & "Data\Cars\Mods\Wheels_Texture.png")
  memberRef = member("Wheels_Texture")
  memberRefName = memberRef.name
  if fileExists then
    memberRef.importFileInto(_movie.path & "Data\Cars\Mods\Wheels_Texture.png", [#dither: 0, #trimWhiteSpace: 0, #linked: 1, #remapImageToStage: 0])
    memberRef.name = memberRefName
    memberRef.purgePriority = 0
    put _movie.path & "Data\Cars\Mods\Wheels_Texture.png " & "IMPORTED INTO " & memberRefName
  end if
  if gGame.HighResCarTextures = 0 then
    tImageHolder = image(512, 512, 32, 0)
    tSourceImage = VOID
    repeat with targetEntry in TargetList
      repeat with i = 1 to 2
        memberRef = member(targetEntry & "Skin" & i & "_Texture")
        if memberRef = VOID then
          next repeat
        end if
        tSourceImage = memberRef.image
        if tSourceImage.width > 512 then
          tImageHolder.copyPixels(tSourceImage, tImageHolder.rect, tSourceImage.rect)
          memberRef.image = tImageHolder
          memberRef.name = targetEntry & "Skin" & i & "_Texture"
          memberRef.purgePriority = 0
          put "Rescaled - " & memberRef.name
        end if
      end repeat
    end repeat
    memberRef = member("Wheels_Texture")
    tSourceImage = memberRef.image
    if tSourceImage.width > 512 then
      tImageHolder.copyPixels(tSourceImage, tImageHolder.rect, tSourceImage.rect)
      memberRef.image = tImageHolder
      memberRef.name = "Wheels_Texture"
      memberRef.purgePriority = 0
      put "Rescaled - " & memberRef.name
    end if
  end if
end
