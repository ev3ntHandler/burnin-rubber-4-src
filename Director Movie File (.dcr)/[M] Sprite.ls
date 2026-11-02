-- [Script] [M] Sprite (Script #6138)
-- Script Type: Movie

global gGame

on CreateSprite me, tTarget, tDataList
  if (tTarget = VOID) or (tTarget = EMPTY) then
    return 0
  end if
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    tDataList = [#channel: GetEmptyChannel(), #loc: point(_movie.stage.rect.width / 2, _movie.stage.rect.height / 2), #size: [tmember.width, tmember.height]]
  end if
  _movie.puppetSprite(tDataList.channel, 1)
  tSprite = sprite(tDataList.channel)
  tSprite.member = tmember
  tSize = [1, 1]
  if tDataList[#size].ilk = #list then
    tSize = tDataList.size
  end if
  tSprite.width = 1
  tSprite.height = 1
  tSprite.loc = point(1, 1)
  set the stageColor to the stageColor
  _movie.updateStage()
  if tDataList[#flipH].ilk = #integer then
    if (tDataList.flipH >= 0) and (tDataList.flipH <= 1) then
      tSprite.flipH = tDataList.flipH
    end if
  end if
  if tDataList[#flipV].ilk = #integer then
    if (tDataList.flipV >= 0) and (tDataList.flipV <= 1) then
      tSprite.flipV = tDataList.flipV
    end if
  end if
  if tDataList[#ink].ilk = #integer then
    tSprite.ink = tDataList.ink
  end if
  if (tDataList[#blend].ilk = #integer) or (tDataList[#blend].ilk = #float) then
    tSprite.blend = integer(tDataList.blend)
  end if
  tLoc = point(1, 1)
  if tDataList[#loc].ilk = #point then
    tLoc = tDataList.loc
  end if
  tSprite.loc = tLoc
  tSprite.width = tSize[1]
  tSprite.height = tSize[2]
  if tDataList[#dts].ilk = #integer then
    tSprite.directToStage = tDataList.dts
  end if
  if tDataList[#default3dScripts].ilk = #integer then
    if (tDataList.default3dScripts = 1) and (tmember.type = #shockwave3d) then
      AddScript(0, EMPTY, [#script: "[PS] Physics", #data: [#member: tmember.name]])
      AddScript(0, EMPTY, [#script: "[PS] Effect Manager", #data: [#member: tmember.name]])
      if voidp(gGame[#Lightmaps]) = 0 then
        tmember.group("World").transform.scale = vector(1.0, 1.0, 1.00000099999999992)
      end if
    end if
  end if
end

on SetSprite me, tTarget, tDataList
  PutMessage(0, "--> SetSprite (handler)")
  tSprite = gGame.sprite
  if tTarget.ilk = #sprite then
    if tSprite.member <> member(0, 0) then
      tSprite = tTarget
    end if
  end if
  if tTarget.ilk = #integer then
    if sprite(tTarget).member <> member(0, 0) then
      tSprite = sprite(tTarget)
    end if
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if (tDataList.ilk = #integer) or (tDataList.ilk = #void) then
    tDataList = [:]
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tSize = gGame.stageSize
  if gGame.fullscreen = 1 then
    tSize = gGame.resolution
  end if
  if tDataList[#size].ilk = #list then
    tSize = tDataList.size
  end if
  tLoc = point(integer(gGame.stageSize[1] * 0.5), integer(gGame.stageSize[2] * 0.5))
  if gGame.fullscreen = 1 then
    tLoc = point(integer(gGame.resolution[1] * 0.5), integer(gGame.resolution[2] * 0.5))
  end if
  if tDataList[#loc].ilk = #point then
    tLoc = tDataList.loc
  end if
  tVisible = 1
  if tDataList[#visible].ilk = #integer then
    tVisible = tDataList.visible
  end if
  tSprite.width = tSize[1]
  tSprite.height = tSize[2]
  tSprite.loc = tLoc
  tSprite.visible = tVisible
end

on ResetSprites me, tTarget, tDataList
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    tDataList = [:]
  end if
  tStart = 1
  tEnd = _movie.lastChannel
  if tDataList[#start].ilk = #integer then
    tStart = tDataList.start
  end if
  if tDataList[#end].ilk = #integer then
    tEnd = tDataList.end
  end if
  repeat with i = tStart to tEnd
    sprite(i).member = member(0, 0)
    _movie.puppetSprite(i, 0)
  end repeat
end

on DeleteDynamicSprites me
end
