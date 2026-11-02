-- [Script] [M] Text Flash (Script #6132)
-- Script Type: Movie

global gSystem, gGame

on CreateTextTextureFlash me, tTarget, tDataList
  tmember = member(tTarget)
  tText = VOID
  if tDataList[#text].ilk = #string then
    tText = tDataList.text
  end if
  if tText = VOID then
    return 0
  end if
  tTextureName = VOID
  if tDataList[#texture].ilk = #string then
    tTextureName = tDataList.texture
  end if
  if tTextureName = VOID then
    tTextureName = tText
  end if
  if voidp(gGame[#text]) = 1 then
    gGame[#text] = [:]
    gGame.text[#sprite] = sprite(11)
    gGame.text[#object] = gGame.text.sprite.getVariable("_root", 0)
    gGame.text[#textMember] = gGame.text.sprite.textMember
    gGame.text[#textMember2] = gGame.text.sprite.textMember2
    gGame.text[#textMember3] = gGame.text.sprite.textMember3
    (the stage).bgColor = (the stage).bgColor
    _movie.updateStage()
  end if
  tFont = "_sans"
  if voidp(gGame[#font]) = 0 then
    tFont = gGame.font
  end if
  if tDataList[#font].ilk = #string then
    tFont = tDataList.font
  end if
  tFontSize = 12
  if tDataList[#fontSize].ilk = #integer then
    tFontSize = tDataList.fontSize
  end if
  tWrap = 0
  if tDataList[#wrap].ilk = #integer then
    tWrap = tDataList[#wrap]
  end if
  tWidth = 256
  if tDataList[#width].ilk = #integer then
    tWidth = tDataList[#width]
  end if
  tHeight = 32
  if tDataList[#height].ilk = #integer then
    tHeight = tDataList[#height]
  end if
  tLeading = 0
  if tDataList[#leading].ilk = #integer then
    tLeading = tDataList[#leading]
  end if
  tOffsetV = 0
  if (tDataList[#offsetV].ilk = #integer) or (tDataList[#offsetV].ilk = #float) then
    tOffsetV = tDataList[#offsetV]
  end if
  tAlignH = #left
  if tDataList[#align].ilk = #symbol then
    tList = [#left, #center, #right]
    if tList.getPos(tDataList.align) <> 0 then
      tAlignH = tDataList.align
    end if
  end if
  tAlignV = 1
  if tDataList[#alignV].ilk = #integer then
    tAlignV = tDataList.alignV
  end if
  tKerning = 0
  tColor = rgb(0, 0, 0)
  if tDataList[#color].ilk = #color then
    tColor = tDataList.color
  end if
  tColor = string(tColor.hexString())
  delete tColor.char[1]
  tColor = "0x" & tColor
  tFilters = VOID
  if tDataList[#filters].ilk = #list then
    tFilters = tDataList.filters
  end if
  tResize = 1
  if tDataList[#resize].ilk = #integer then
    tResize = tDataList.resize
  end if
  tOffSetH = 0
  if tDataList[#offsetH].ilk = #integer then
    tOffSetH = tDataList.offsetH
  end if
  if member(tTextureName) = VOID then
    tEmpty = castLib("Shared").findEmpty()
    tTextureMember = new(#bitmap, member(tEmpty, "Shared"))
    tTextureMember.name = tTextureName
    gSystem.DynamicMembers.add(tTextureMember)
  else
    tTextureMember = member(tTextureName)
  end if
  if tFont = gGame.font3 then
    gGame.text.textMember.text = EMPTY
    gGame.text.textMember2.text = EMPTY
    gGame.text.textMember3.text = tText
    gGame.text.object.setTextFormat(3, tWidth, tHeight, tFont, tFontSize, tWrap, string(tAlignH), tAlignV, 1, 0, 0, 0, tLeading, tColor, tResize, tOffsetV, tKerning)
  else
    if gGame.EmbedFonts = 0 then
      gGame.text.textMember.EmbedFonts = gGame.EmbedFonts
      gGame.text.textMember2.EmbedFonts = gGame.EmbedFonts
      gGame.text.textMember.text = tText
      gGame.text.textMember2.text = EMPTY
      gGame.text.textMember3.text = EMPTY
      gGame.text.object.setTextFormat(1, tWidth, tHeight, "_sans", tFontSize, tWrap, string(tAlignH), tAlignV, 1, 0, 0, 0, tLeading, tColor, tResize, tOffsetV, tKerning)
    else
      if tFont = gGame.font then
        gGame.text.textMember.text = tText
        gGame.text.textMember2.text = EMPTY
        gGame.text.textMember3.text = EMPTY
        gGame.text.object.setTextFormat(1, tWidth, tHeight, tFont, tFontSize, tWrap, string(tAlignH), tAlignV, 1, 0, 0, 0, tLeading, tColor, tResize, tOffsetV, tKerning)
      end if
      if tFont = gGame.Font2 then
        gGame.text.textMember.text = EMPTY
        gGame.text.textMember2.text = tText
        gGame.text.textMember3.text = EMPTY
        gGame.text.object.setTextFormat(2, tWidth, tHeight, tFont, tFontSize, tWrap, string(tAlignH), tAlignV, 1, 0, 0, 0, tLeading, tColor, tResize, tOffsetV, tKerning)
      end if
    end if
  end if
  tBmpData = gGame.text.sprite.newObject("flash.display.BitmapData", tWidth, tHeight, 1, 0)
  tBmpData.draw(gGame.text.sprite._level0)
  tImage = gGame.text.sprite.convert(#image, tBmpData)
  if tDataList[#gradient].ilk = #string then
    tGradientSource = member(tDataList.gradient)
    if tGradientSource <> VOID then
      tGradientImage = image(tWidth, tHeight, 32, 1)
      tGradientImage.copyPixels(tGradientSource.image, tGradientImage.rect, tGradientSource.rect)
      tGradientImage.setAlpha(tImage.extractAlpha())
      member("ImageTemplate").image = tGradientImage
    else
      member("ImageTemplate").image = tImage
    end if
  else
    member("ImageTemplate").image = tImage
  end if
  if tFilters <> VOID then
    repeat with i = 1 to tFilters.count
      tFilter = filter(tFilters[i].getPropAt(1), tFilters[i][1])
      tImage.applyFilter(tFilter, tImage.rect)
    end repeat
  end if
  tTextureMember.image = tImage
  tForceSize = []
  if tDataList[#forceSize].ilk = #list then
    tForceSize = tDataList.forceSize
  end if
  if tForceSize.count > 0 then
    tForceImage = image(tForceSize[1], tForceSize[2], 32, 1)
    if tAlignH = #left then
      tForceImage.copyPixels(tImage, tImage.rect, tImage.rect)
      tForceAlpha = tForceImage.extractAlpha()
      tForceAlpha.fill(tForceAlpha.rect, rgb(255, 255, 255))
      tTempAlpha = tImage.extractAlpha()
      tForceAlpha.copyPixels(tTempAlpha, tTempAlpha.rect, tTempAlpha.rect)
      tForceImage.setAlpha(tForceAlpha)
    end if
    if tAlignH = #center then
      tX1 = integer((tForceSize[1] * 0.5) - (tImage.rect.width * 0.5))
      tX2 = integer((tForceSize[1] * 0.5) + (tImage.rect.width * 0.5))
      tTargetRect = rect(tX1, tImage.rect[2], tX2, tImage.rect[4])
      tForceImage.copyPixels(tImage, tTargetRect, tImage.rect)
      tForceAlpha = tForceImage.extractAlpha()
      tForceAlpha.fill(tForceAlpha.rect, rgb(255, 255, 255))
      tTempAlpha = tImage.extractAlpha()
      tForceAlpha.copyPixels(tTempAlpha, tTargetRect, tTempAlpha.rect)
      tForceImage.setAlpha(tForceAlpha)
    end if
    tImage = tForceImage.duplicate()
    tTextureMember.image = tImage
  end if
  tNearFiltering = 0
  if tDataList[#nearFiltering].ilk = #integer then
    tNearFiltering = tDataList.nearFiltering
  end if
  tRenderFormat = #rgba4444
  if tDataList[#renderFormat].ilk = #symbol then
    tList = [#rgba4444, #rgba8888]
    if tList.getPos(tDataList.renderFormat) <> 0 then
      tRenderFormat = tDataList.renderFormat
    end if
  end if
  tMemberOnly = 0
  if tDataList[#memberOnly].ilk = #integer then
    tMemberOnly = tDataList.memberOnly
  end if
  if tMemberOnly = 1 then
    return tTextureMember
  else
    tTexture = tmember.texture(tTextureName)
    if tTexture = VOID then
      tTexture = tmember.newTexture(tTextureName, #fromCastMember, tTextureMember)
      tTexture.quality = #lowFiltered
      tTexture.nearFiltering = tNearFiltering
      tTexture.renderFormat = tRenderFormat
    else
      tTexture.image = tImage
    end if
    return tTexture
  end if
end
