-- [Script] [M] Menu (Script #6128)
-- Script Type: Movie

global gSystem, gGame

on CreateMenu me, tTarget, tDataList
  if gSystem.MenuScript = #none then
    AddScript(0, #system, [#script: "[PS] Menu", #data: [:]])
  end if
end

on CreateButton me, tTarget, tDataList
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
  tmodel = VOID
  if tDataList[#model].ilk = #string then
    tmodel = GetReferenceType(0, tmember, tDataList.model)
  end if
  if tmodel = VOID then
    return 0
  end if
  if gSystem.MenuScript = #none then
    CreateMenu(0, EMPTY, [:])
  end if
  tList = [:]
  tList[#member] = tmember.name
  if tDataList[#layer].ilk = #integer then
    tList[#layer] = tDataList.layer
  else
    tList[#layer] = 0
  end if
  tList[#event] = #none
  if tDataList[#event].ilk = #string then
    tList[#event] = symbol(tDataList.event)
  end if
  if tDataList[#event].ilk = #symbol then
    tList[#event] = tDataList.event
  end if
  tList[#handler] = #none
  if (tDataList[#handler].ilk = #string) or (tDataList[#handler].ilk = #symbol) then
    tList[#handler] = tDataList.handler
  end if
  tCursor = 280
  if tDataList[#cursor].ilk = #integer then
    tCursor = tDataList.cursor
  end if
  tList[#transform] = tmodel.transform.duplicate()
  tAlpha = 0
  if tDataList[#alpha].ilk = #integer then
    tAlpha = tDataList.alpha
  end if
  tList[#alpha] = tAlpha
  tList[#rolloverSound] = "Rollover_SFX"
  if tDataList[#rolloverSound].ilk = #string then
    tList[#rolloverSound] = tDataList.rolloverSound
  end if
  tList[#pressedSound] = "Select_SFX"
  if tDataList[#pressedSound].ilk = #string then
    tList[#pressedSound] = tDataList.pressedSound
  end if
  tEffect = #none
  if tDataList[#effect].ilk = #list then
    tEffect = tDataList.effect
  end if
  if tDataList[#effect].ilk = #symbol then
    tEffect = [tDataList.effect]
  end if
  tList[#effect] = tEffect
  tList[#handlers] = []
  if tDataList[#handlers].ilk = #list then
    tList[#handlers] = tDataList.handlers.duplicate()
  end if
  tList[#Events] = []
  if tDataList[#Events].ilk = #list then
    tList[#Events] = tDataList.Events.duplicate()
  end if
  tList[#resources] = []
  if tDataList[#resources].ilk = #list then
    tList[#resources] = tDataList.resources.duplicate()
  end if
  tList[#textures] = []
  if tDataList[#textures].ilk = #list then
    tList[#textures] = tDataList.textures.duplicate()
  end if
  tList[#shaders] = []
  if tDataList[#shaders].ilk = #list then
    tList[#shaders] = tDataList.shaders.duplicate()
  end if
  if gGame.menu.memberList.getPos(tmember) = 0 then
    gGame.menu.memberList.addAt(1, tmember)
  end if
  gGame.menu.buttons[tmodel.name] = tList
  return tList.duplicate()
end

on DeleteButton me, tTarget, tDataList
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  if tDataList[#model].ilk = #string then
    tButton = tDataList.model
  else
    return 0
  end if
  tMemberName = #none
  if voidp(gGame.menu.buttons[tButton]) = 0 then
    tMemberName = gGame.menu.buttons[tButton].member
    gGame.menu.buttons.deleteProp(tButton)
  end if
  if tMemberName <> #none then
    tDelete = 1
    repeat with i in gGame.menu.buttons
      if i.member = tMemberName then
        tDelete = 0
        exit repeat
      end if
    end repeat
    if tDelete = 1 then
      gGame.menu.memberList.deleteOne(member(tMemberName))
    end if
  end if
  return 1
end

on DeleteAllButtons me, tTarget, tDataList
  PutMessage(0, "--> DeleteAllButtons (Handler)")
  if voidp(gGame[#menu]) = 1 then
    return 0
  end if
  gGame.menu.buttons = [:]
  gGame.menu.memberList = []
  _player.cursor(-1)
end
