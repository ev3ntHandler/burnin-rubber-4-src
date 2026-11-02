-- [Script] [M] 3D Textures (Script #6147)
-- Script Type: Movie

global gSystem, gData

on createTexture me, tTarget, tDataList
  LogMessage(0, "CreateTexture" && "Target" && tTarget && "DataList" && tDataList)
  tmember = member(tTarget)
  if tmember = VOID then
    exit
  end if
  if tmember.type <> #shockwave3d then
    exit
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tTexture = EMPTY
  if tDataList[#texture].ilk = #string then
    tTexture = tDataList.texture
  end if
  tTextureMember = member(tTexture)
  if tTextureMember = VOID then
    return 0
  end if
  if tTextureMember.type <> #bitmap then
    return 0
  end if
  tOverride = 0
  if tDataList[#Override].ilk = #integer then
    tOverride = tDataList.Override
  end if
  if (tmember.texture(tTexture) <> VOID) and (tOverride = 0) then
    return tmember.texture(tTexture)
  end if
  tCast = tTextureMember.castLibNum
  if tDataList[#cast].ilk = #string then
    tCast = tDataList.cast
  end if
  tFiltering = #high
  tFilteringList = [#lowFiltered, #low, #medium, #high]
  if tDataList[#filtering].ilk = #symbol then
    tFiltering = tDataList.filtering
  end if
  if tFilteringList.getPos(tFiltering) = 0 then
    tFiltering = #high
  end if
  tRenderFormat = #rgba5650
  tRenderFormatList = [#rgba4444, #rgba5551, #rgba5550, #rgba5650, #rgba8880, #rgba8888]
  if tTextureMember.useAlpha = 1 then
    tRenderFormat = #rgba4444
  end if
  if tDataList[#renderFormat].ilk = #symbol then
    tRenderFormat = tDataList.renderFormat
  end if
  if tRenderFormatList.getPos(tRenderFormat) = 0 then
    if tTextureMember.useAlpha = 1 then
      tRenderFormat = #rgba4444
    else
      tRenderFormat = #rgba5650
    end if
  end if
  tNearFiltering = 1
  if tDataList[#nearFiltering].ilk = #integer then
    tNearFiltering = tDataList.nearFiltering
  end if
  tCompressed = 1
  if tDataList[#compressed].ilk = #integer then
    tCompressed = tDataList.compressed
  end if
  tScaleDown = 0
  if tDataList[#scaleDown].ilk = #integer then
    tScaleDown = tDataList.scaleDown
  end if
  if tScaleDown > 0 then
    tCompressed = 0
  end if
  tAdjustment = #none
  if tDataList[#adjustment].ilk = #symbol then
    tAdjustment = [tDataList.adjustment]
  end if
  if tDataList[#adjustment].ilk = #list then
    tAdjustment = tDataList.adjustment
  end if
  if tAdjustment <> #none then
    repeat with i = tAdjustment.count down to 1
      if gData.data.texture.getaProp(tDataList.adjustment) = VOID then
        tAdjustment.deleteAt(i)
      end if
    end repeat
  end if
  tResize = #none
  if tDataList[#resize].ilk = #list then
    if tDataList.resize.count = 2 then
      tResize = tDataList.resize
      tSizes = [2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4196, 8392, 16784]
      tSizes.sort()
      tWidth = tSizes.duplicate()
      tWidth.add(tResize[1])
      tWidth = tWidth[tWidth.getPos(tResize[1]) + 1]
      tHeight = tSizes.duplicate()
      tHeight.add(tResize[2])
      tHeight = tHeight[tHeight.getPos(tResize[2]) + 1]
      tResize = [tWidth, tHeight]
    end if
  end if
  tErase = 0
  if tDataList[#erase].ilk = #integer then
    tErase = tDataList.erase
  end if
  tImage = #none
  if tDataList[#alpha].ilk = #string then
    if member(tDataList.alpha) <> VOID then
      tImage = image(member(tTexture).width, member(tTexture).height, 32, 1)
      tImage.copyPixels(member(tTexture).image, member(tTexture).rect, member(tTexture).rect)
      tAlpha = image(member(tDataList.alpha).width, member(tDataList.alpha).height, 8, #grayscale)
      tAlpha.copyPixels(member(tDataList.alpha).image, member(tDataList.alpha).rect, member(tDataList.alpha).rect, [#ink: 4])
      tImage.setAlpha(tAlpha)
    end if
  end if
  if tResize <> #none then
    tImage = member(tTexture, tCast).image.duplicate()
    tSamplePixel = tImage.getPixel(point(0, 0))
    tNewImage = image(tResize[1], tResize[2], 32)
    tNewImage.fill(tNewImage.rect, tSamplePixel)
    tNewImage.copyPixels(tImage, tImage.rect, tImage.rect)
    tImage = tNewImage
  end if
  if tAdjustment <> #none then
    if tImage = #none then
      tImage = member(tTexture, tCast).image.duplicate()
    end if
    repeat with i in tAdjustment
      tAdjustmentFilter = filter(#AdjustColorFilter, gData.data.texture[i])
      tImage.applyFilter(tAdjustmentFilter)
    end repeat
  end if
  if tImage = #none then
    tTexture = tmember.newTexture(tTexture, #fromCastMember, member(tTexture, tCast))
  else
    tTexture = tmember.newTexture(tTexture, #fromImageObject, tImage)
  end if
  tTexture.quality = tFiltering
  tTexture.renderFormat = tRenderFormat
  tTexture.nearFiltering = tNearFiltering
  tTexture.compressed = tCompressed
  if tScaleDown > 0 then
    repeat with i = 1 to tScaleDown
      tTexture.scaleDown()
    end repeat
  end if
  if (gSystem.local = 1) and (tErase = 1) then
    tTextureMember.erase()
  else
    tTextureMember.unload()
    _movie.unloadMember(tTextureMember)
  end if
  return tTexture
end

on ASSIGNTEXTURE me, tTarget, tDataList
  pMember = member(tTarget)
  pDataList = value(tDataList)
  pCast = pDataList[#cast]
  pMaterial = pDataList[#material]
  pTexture1 = pDataList[#texture1]
  pTexture2 = pDataList[#texture2]
  pTexture3 = pDataList[#Texture3]
  pTexture4 = pDataList[#Texture4]
  pTexture5 = pDataList[#Texture5]
  pTexture6 = pDataList[#Texture6]
  pTexture7 = pDataList[#Texture7]
  pTexture8 = pDataList[#Texture8]
  pLightmap = pDataList[#lightmap]
  pAddMap = pDataList[#AddMap]
  pTextureList = [pTexture1, pTexture2, pTexture3, pTexture4, pTexture5, pTexture6, pTexture7, pTexture8]
  if pMember = VOID then
    exit
  end if
  if pMember.type <> #shockwave3d then
    exit
  end if
  if pDataList = [:] then
    exit
  end if
  if pCast = VOID then
    pCast = pMember.cast.name
  end if
  if pMaterial = VOID then
    exit
  end if
  if pMember.shader(pMaterial) = VOID then
    exit
  end if
  pTextureList = [pTexture1, pTexture2, pTexture3, pTexture4, pTexture5, pTexture6, pTexture7, pTexture8]
  pCount = pTextureList.count
  repeat with i = 1 to pCount
    if pTextureList[i] = VOID then
      next repeat
    end if
    if pMember.texture(pTextureList[i]) = VOID then
      next repeat
      next repeat
    end if
    pMember.shader(pMaterial).textureList[i] = pMember.texture(pTextureList[i])
  end repeat
  if pAddMap <> VOID then
    pMember.shader(pMaterial).flat = 1
    pMember.shader(pMaterial).blendFunctionList[1] = #replace
    pMember.shader(pMaterial).textureList[2] = pMember.texture(pAddMap)
    pMember.shader(pMaterial).blendFunctionList[2] = #add
    if pLightmap <> VOID then
      pMember.shader(pMaterial).textureList[3] = pMember.texture(pLightmap)
      pMember.shader(pMaterial).blendFunctionList[3] = #multiply
    end if
  else
    pMember.shader(pMaterial).blendFunctionList[1] = #multiply
    if pLightmap <> VOID then
      pMember.shader(pMaterial).transparent = 0
      pMember.shader(pMaterial).blendFunctionList[1] = #multiply
      pMember.shader(pMaterial).textureList[2] = pMember.texture(pLightmap)
      pMember.shader(pMaterial).blendFunctionList[2] = #multiply
    end if
  end if
end

on SetTexture me, tTarget, tDataList
  LogMessage(string("SetTexture" && "Target" && tTarget && "DataList" && tDataList))
end

on deleteTexture me, tTarget, tDataList
  LogMessage("Function: DeleteTexture" && "Target" && tTarget && "DataList" && tDataList)
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tTextureName = #none
  if tDataList[#texture].ilk = #string then
    tTextureName = tDataList.texture
  end if
  if tTextureName = #none then
    return 0
  end if
  tTexture = tmember.texture(tTextureName)
  if tTexture <> VOID then
    tmember.deleteTexture(tTextureName)
  end if
end

on DuplicateTexture me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return []
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return []
  end if
  tSourceMember = tmember
  if tDataList[#sourceMember].ilk = #string then
    tSourceMember = member(tDataList.sourceMember)
  end if
  tTargetList = []
  if tDataList[#texture].ilk = #void then
    tDataList[#texture] = "*.*"
  end if
  if tDataList[#texture].ilk = #list then
    tTargetList = tDataList.texture
  else
    if tDataList[#texture].ilk = #string then
      if tDataList.texture.char[1] = "*" then
        tString = tDataList.shader
        if tString <> "*.*" then
          delete tString.char[1]
        end if
        tTargetList = GetStringList(0, tSourceMember.name, [#type: #texture, #string: tString])
      else
        tTargetList.add(tDataList.texture)
      end if
    end if
  end if
  if tTargetList.count = 0 then
    return []
  end if
  tNameTag = VOID
  if tDataList[#NameTag].ilk = #string then
    tNameTag = tDataList.NameTag
  end if
  tTextureList = []
  repeat with i in tTargetList
    tTexture = tSourceMember.texture(i)
    tTextureMember = tTexture.member
    tImage = tTextureMember.image.duplicate()
    tNewTexture = tmember.newTexture(tNameTag & tTexture.name, #fromImageObject, tImage)
    tNewTexture.quality = tTexture.quality
    tNewTexture.nearFiltering = tTexture.nearFiltering
    tNewTexture.compressed = tTexture.compressed
    tNewTexture.renderFormat = tTexture.renderFormat
    tNewTexture.member = tTexture.member
    tTextureList.add(tNewTexture)
  end repeat
  if tTextureList.count = 1 then
    return tTextureList[1]
  else
    return tTextureList
  end if
end
