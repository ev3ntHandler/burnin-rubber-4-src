-- [Script] [M] Text Misc (Script #6130)
-- Script Type: Movie

global gSystem, gGame

on CreateTextTexture me, tTarget, tDataList
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
  if gSystem.text.engine = #flash then
    CreateTextTextureFlash(0, tTarget, tDataList)
  else
    CreateTextTextureDirector(0, tTarget, tDataList)
  end if
end

on GetAndSetTagTextureSize me, tmodel, tText, tStyle, tTextureData
  if tmodel.resource.type = #fromFile then
    tmodel.resource.lod.auto = 0
    tmodel.resource.lod.bias = 100.0
    tmodel.resource.lod.level = 100.0
  end if
  if tmodel.userData.getaProp(#text) = VOID then
    tmodel.userData.addProp(#text, tText)
  else
    tmodel.userData.text = tText
  end if
  if tmodel.userData.getaProp(#style) = VOID then
    tmodel.userData.addProp(#style, tStyle)
  else
    tmodel.userData.style = tStyle
  end if
  if tmodel.userData.getaProp(#textureData) = VOID then
    tmodel.userData.addProp(#textureData, tTextureData)
  else
    tmodel.userData.textureData = tTextureData
  end if
  tmodel.addModifier(#meshDeform)
  tXList = []
  tYList = []
  tXList.sort()
  tYList.sort()
  tList = tmodel.meshDeform.mesh[1].vertexList
  repeat with b = 1 to tList.count
    tVector = tmodel.meshDeform.mesh[1].vertexList[b]
    tX = tVector.x
    tY = tVector.y
    if tXList.getPos(tX) = 0 then
      tXList.add(tX)
    end if
    if tYList.getPos(tY) = 0 then
      tYList.add(tY)
    end if
  end repeat
  tWidth = integer(abs(tXList[1] - tXList[tXList.count])) * gGame.SourceRatio
  tHeight = integer(abs(tYList[1] - tYList[tYList.count])) * gGame.SourceRatio
  tSize = [tWidth, tHeight]
  tNewSize = tSize.duplicate()
  tFormatSizes = [2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4196, 8392, 16784]
  if tFormatSizes.getPos(tWidth) = 0 then
    tList = tFormatSizes.duplicate()
    tList.add(tWidth)
    tList.sort()
    tNewSize[1] = tList[tList.getPos(tWidth) + 1]
  end if
  if tFormatSizes.getPos(tHeight) = 0 then
    tList = tFormatSizes.duplicate()
    tList.add(tHeight)
    tList.sort()
    tNewSize[2] = tList[tList.getPos(tHeight) + 1]
  end if
  if tNewSize <> tSize then
    if tmodel.userData.getaProp(#textureCoordinateList) = VOID then
      tmodel.userData.addProp(#textureCoordinateList, tmodel.meshDeform.mesh[1].textureCoordinateList)
    else
      tmodel.meshDeform.mesh[1].textureCoordinateList = tmodel.userData.textureCoordinateList
    end if
    tPerc = [float(tSize[1]) / float(tNewSize[1]), float(tSize[2]) / float(tNewSize[2])]
    tdiff = [0.0, 1.0 - tPerc[2] + 0.0002]
    tList = []
    repeat with i = 1 to tmodel.meshDeform.mesh[1].textureCoordinateList.count
      tTCoord = tmodel.meshDeform.mesh[1].textureCoordinateList[i]
      tTCoord = (tTCoord * tPerc) + tdiff
      tTCoord[1] = max(0.0, min(tTCoord[1], 1.0))
      tTCoord[2] = max(0.0, min(tTCoord[2], 1.00019999999999998))
      tList.add(tTCoord)
    end repeat
    tmodel.meshDeform.mesh[1].textureCoordinateList = tList
  end if
  tmodel.removeModifier(#meshDeform)
  return [tSize, tNewSize]
end

on CheckSetTextEnters me, tString
  tText = EMPTY
  the itemDelimiter = "\"
  tCount = tString.item.count
  tList = []
  repeat with i = 1 to tCount
    tList.add(tString.item[i])
  end repeat
  repeat with i = 1 to tList.count
    tItem = tList[i]
    if charToNum(tItem.char[1]) = 110 then
      tText = tText & RETURN & tItem.char[2..tItem.length]
      next repeat
    end if
    if i = 1 then
      tText = tText & tItem
      next repeat
    end if
    tText = tText & "\" & tItem
  end repeat
  return tText
end

on resizeText me, tmember, tStyle, tTextureData
  tFontSize = tmember.fontSize
  repeat with i = 1 to tFontSize
    tCharPos = tmember.charPosToLoc(tmember.text.length)
    if (tCharPos[1] > tmember.rect[3]) or (tCharPos[2] > tmember.rect[4]) then
      tText = tmember.text
      tmember.text = EMPTY
      tmember.fontSize = tmember.fontSize - 1
      tmember.text = tText
      textBottom = tmember.charPosToLoc(tText.char.count + 1).locV
      spaceAtTop = (tmember.pageHeight - textBottom + tmember.topSpacing) / 2
      if tStyle.alignV = 0 then
        tmember.topSpacing = 0
        tmember.fixedLineSpace = tmember.fontSize + 2
      else
        tmember.fixedLineSpace = tmember.fontSize / 18.0 * 10
        tmember.topSpacing = integer(tTextureData.size[2] * 0.5)
      end if
      next repeat
    end if
    return tmember.fontSize
  end repeat
end

on convertToUpperCase me, tString
  tNewString = EMPTY
  tList = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]
  repeat with i = 1 to tString.length
    tChar = tString.char[i]
    if tList.getPos(tChar) <> 0 then
      tChar = charToNum(tString.char[i])
      tChar = numToChar(tChar - 32)
    end if
    tNewString = tNewString & tChar
  end repeat
  return tNewString
end

on convertToLowerCase me, tString
  tNewString = EMPTY
  tList = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
  repeat with i = 1 to tString.length
    tChar = tString.char[i]
    if tList.getPos(tChar) <> 0 then
      tChar = charToNum(tString.char[i])
      tChar = numToChar(tChar + 32)
    end if
    tNewString = tNewString & tChar
  end repeat
  return tNewString
end
