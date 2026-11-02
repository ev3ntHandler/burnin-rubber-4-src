-- [Script] [M] Text Director (Script #6131)
-- Script Type: Movie

global gData, gGame

on CreateTextTextureDirector me, tTarget, tDataList
  tmember = member(tTarget)
  tTextMember = member("Text")
  tTextMember.text = EMPTY
  tTag = #none
  if tDataList[#tag].ilk = #symbol then
    tTag = tDataList.tag
  end if
  if tDataList[#tag].ilk = #string then
    tTag = symbol(tDataList.tag)
  end if
  tmodel = tmember.model(string(tTag))
  if tmodel = VOID then
    return 0
  end if
  tText = #none
  if tTag <> #none then
    if voidp(gData.data[#text]) = 0 then
      if voidp(gData.data.text[tTag]) = 0 then
        tText = gData.data.text[tTag]
      end if
    end if
  end if
  if tDataList[#text].ilk = #symbol then
    tText = gData.data.text[tDataList.text]
  end if
  if tDataList[#text].ilk = #string then
    tText = tDataList.text
  end if
  if (tText = #none) and (tDataList[#text].ilk <> #void) then
    tText = string(tDataList.text)
  end if
  if (tText = #none) or (tText = VOID) then
    return 0
  end if
  if tText contains "\" then
    tText = CheckSetTextEnters(0, tText)
  end if
  tStyle = [#font: "Arial", #fontSize: 12, #align: #left, #wrap: 0, #resize: 0, #kerning: 0, #alignV: 1, #fontStyle: [], #color: rgb(255, 255, 255), #fixedLineSpace: #none, #topSpacing: #none, #filters: []]
  tTextureData = [#name: "TextTexture" & tmember.texture.count & "_Texture", #size: [128, 32], #nearFiltering: 0, #renderFormat: #rgba4444, #Override: 1]
  if tDataList[#style].ilk = #symbol then
    if gData.data.textStyle.getaProp(tDataList.style) <> VOID then
      tList = gData.data.textStyle[tDataList.style].duplicate()
      repeat with i = 1 to tList.count
        tProp = tList.getPropAt(i)
        if (tProp = #font) or (tProp = #color) then
          if tList[tProp].ilk = #symbol then
            if gData.data[symbol("Text" & string(tProp))].getaProp(tList[tProp]) <> VOID then
              tStyle[tProp] = gData.data[symbol("Text" & string(tProp))][tList[tProp]]
            end if
          else
            if tList[tProp].ilk = tStyle[tProp].ilk then
              tStyle[tProp] = tList[tProp]
            end if
          end if
          next repeat
        end if
        if (tProp = #fixedLineSpace) or (tProp = #topSpacing) then
          tStyle[tProp] = tList[tProp]
          next repeat
        end if
        if tList[tProp].ilk = tStyle[tProp].ilk then
          tStyle[tProp] = tList[tProp]
        end if
      end repeat
    end if
  end if
  repeat with i = 1 to tDataList.count
    tProp = tDataList.getPropAt(i)
    if tStyle[tProp].ilk <> #void then
      if (tProp = #font) or (tProp = #color) then
        if tDataList[tProp].ilk = #symbol then
          if gData.data[symbol("Text" & string(tProp))].getaProp(tDataList[tProp]) <> VOID then
            tStyle[tProp] = gData.data[symbol("Text" & string(tProp))][tDataList[tProp]]
          end if
        else
          if tDataList[tProp].ilk = tStyle[tProp].ilk then
            tStyle[tProp] = tDataList[tProp]
          end if
        end if
      else
        if (tProp = #fixedLineSpace) or (tProp = #topSpacing) then
          tStyle[tProp] = tDataList[tProp]
        else
          if tDataList[tProp].ilk = tStyle[tProp].ilk then
            tStyle[tProp] = tDataList[tProp]
          end if
        end if
      end if
      next repeat
    end if
    if tTextureData[tProp].ilk <> #void then
      if tTextureData[tProp].ilk = tDataList[tProp].ilk then
        tTextureData[tProp] = tDataList[tProp]
      end if
    end if
  end repeat
  if tTag <> #none then
    tResult = GetAndSetTagTextureSize(0, tmodel, tText, tStyle, tTextureData)
    tTextureData[#size] = tResult[1]
    tTextureData[#membersize] = tResult[1]
    tTextureData[#textureSize] = tResult[2]
    tTextureData.name = string(tTag) & "_Texture"
  end if
  tTextMember.font = tStyle.font
  tTextMember.fontSize = tStyle.fontSize * gGame.SourceRatio
  if tTag <> #none then
    tTextMember.height = tTextureData.membersize[2]
  else
    tTextMember.height = tTextureData.size[2]
  end if
  tTextMember.wordWrap = tStyle.wrap
  if tTag <> #none then
    tTextMember.width = tTextureData.membersize[1]
  else
    tTextMember.width = tTextureData.size[1]
  end if
  tTextMember.alignment = tStyle.align
  tTextMember.fontStyle = tStyle.fontStyle
  tTextMember.charSpacing = tStyle.kerning
  tTextMember.color = tStyle.color
  tTextMember.text = tText
  if tStyle.alignV = 0 then
    tTextMember.topSpacing = 0
    tTextMember.fixedLineSpace = (tStyle.fontSize + 2) * gGame.SourceRatio
  else
    tTextMember.fixedLineSpace = tStyle.fontSize / 18.0 * 10 * gGame.SourceRatio
    tTextMember.topSpacing = integer(tTextureData.size[2] * 0.5)
  end if
  if tStyle.resize = 1 then
    tStyle.fontSize = resizeText(0, tTextMember, tStyle, tTextureData)
  end if
  if tStyle.topSpacing <> #none then
    tTextMember.topSpacing = tStyle.topSpacing * gGame.SourceRatio
  end if
  if tStyle.fixedLineSpace <> #none then
    tTextMember.fixedLineSpace = tStyle.fixedLineSpace * gGame.SourceRatio
  end if
  if tTextureData.Override = 1 then
    tTextureMember = member("TextTemplate")
  else
    if member(tTextureData.name) = VOID then
      tEmpty = castLib("Internal").findEmpty()
      tTextureMember = new(#bitmap, member(tEmpty, "Internal"))
      tTextureMember.name = tTextureData.name
    else
      tTextureMember = member(tTextureData.name)
    end if
  end if
  member("TextTemplate").image = tTextMember.image
  tImage = member("TextTemplate").image
  if tTag <> #none then
    if tTextureData.membersize <> tTextureData.textureSize then
      tNewImage = image(tTextureData.textureSize[1], tTextureData.textureSize[2], 32, 1)
      tAlpha = image(tTextureData.textureSize[1], tTextureData.textureSize[2], 8)
      tAlpha.fill(tAlpha.rect, rgb(255, 255, 255))
      tNewImage.setAlpha(tAlpha)
      tNewImage.copyPixels(tImage, tImage.rect, tImage.rect)
      tImage = tNewImage
    end if
  end if
  repeat with i in tStyle.filters
    if gData.data.TextFilters.getaProp(i) <> VOID then
      tTextFilter = gData.data.TextFilters[i]
      if tTextFilter = VOID then
        next repeat
      end if
      tFilter = filter(tTextFilter.getPropAt(1), tTextFilter[1])
      tImage.applyFilter(tFilter, tImage.rect)
    end if
  end repeat
  tTextureMember.image = tImage
  tTexture = tmember.texture(tTextureData.name)
  if tTexture = VOID then
    tTexture = tmember.newTexture(tTextureData.name, #fromCastMember, tTextureMember)
    tTexture.quality = #lowFiltered
    tTexture.nearFiltering = tTextureData.nearFiltering
    tTexture.renderFormat = tTextureData.renderFormat
    tTexture.image = tImage
  else
    tTexture.image = tImage
  end if
  if tTag <> #none then
    tShader = tmember.shader(string(tTag) & "_Material")
    if tShader = VOID then
      tShader = CreateShader(0, tmember.name, [#shader: string(tTag) & "_Material", #emissive: rgb(255, 255, 255), #texture: tTexture.name])
      tShader.textureRepeatList[1] = 0
      tmodel.shaderList = tShader
    else
      tShader.textureList[1] = tTexture
      tShader.textureRepeatList[1] = 0
    end if
  end if
  return tTexture
end
