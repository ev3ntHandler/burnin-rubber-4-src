-- [Script] [PS] Burnin3 Scroller (Script #5863)
-- Script Type: Parent

property p
global gData, gGame, gSystem

on new me, tDataList
  p = [:]
  p[#member] = member(tDataList[#member])
  p[#ScriptName] = "Scroller"
  p[#button] = VOID
  p[#PreviousButton] = VOID
  p[#mouseDown] = 0
  p[#rightMouseDown] = 0
  p[#MouseStart] = _mouse.mouseLoc
  p[#tag] = tDataList[#tag]
  p[#camera] = p.member.camera("Menu_Camera")
  p[#Slider] = p.member.model(p.tag & "Slider")
  p[#SliderSize] = 0.23999999999999999
  p[#bar] = p.member.model(p.tag & "bar")
  p[#BarSize] = 3.83999999999999986
  p[#minMax] = [p.bar.transform.position.y, p.bar.transform.position.y - (p.BarSize - p.SliderSize)]
  p[#shader] = p.member.shader(p.tag & "_Material")
  if tDataList[#ShaderMax].ilk = #float then
    p[#ShaderMax] = tDataList.ShaderMax
  else
    p[#ShaderMax] = 0.5
  end if
  p.Slider.transform.position.y = p.bar.transform.position.y
  p[#transform] = p.Slider.transform.duplicate()
  p.shader.textureTransformList[1].position = vector(0.0, 0.0, 0.0)
  p[#normal] = p.member.shader("Slider_Material")
  p[#rollover] = p.member.shader("OrangeSlider_Material")
  p.Slider.shader = p.normal
  p[#me] = me
  return me
end

on enterFrame me
  if p.mouseDown = 0 then
    tmodel = p.camera.modelUnderLoc(_mouse.mouseLoc)
    if tmodel <> VOID then
      if tmodel.name = p.Slider.name then
        p.button = tmodel
        p.MouseStart = _mouse.mouseLoc
      else
        p.button = VOID
      end if
    end if
    if (p.button = VOID) and (p.PreviousButton <> VOID) then
      me.ButtonLeave(p.PreviousButton)
    end if
    if p.button <> VOID then
      me.ButtonEnter()
    end if
  end if
  if _mouse.mouseDown and (p.button <> VOID) then
    me.ButtonDown()
  end if
  if _mouse.mouseUp and (p.button <> VOID) and (p.mouseDown = 1) then
    me.ButtonUp()
  end if
end

on ButtonEnter me
  if p.button = p.PreviousButton then
    return
  else
    me.ButtonLeave(p.PreviousButton)
  end if
  _player.cursor(260)
  p.button.shader = p.rollover
  p.PreviousButton = p.button
  PlaySound(0, "Rollover_SFX", [#Override: 1])
end

on ButtonLeave me, tButton
  _player.cursor(-1)
  if tButton <> VOID then
    tButton.shader = p.normal
  end if
  p.PreviousButton = VOID
end

on ButtonDown me
  _player.cursor(290)
  tDiffV = _mouse.mouseV - p.MouseStart.locV
  p.button.transform.position.y = p.transform.position.y - (tDiffV / 66.66670000000000584)
  if p.button.transform.position.y > p.minMax[1] then
    p.button.transform.position.y = p.minMax[1]
  end if
  if p.button.transform.position.y < p.minMax[2] then
    p.button.transform.position.y = p.minMax[2]
  end if
  tPerc = abs((p.minMax[1] - p.button.transform.position.y) / (p.minMax[2] - p.minMax[1]))
  p.shader.textureTransformList[1].position = vector(0.0, p.ShaderMax * tPerc, 0.0)
  p.mouseDown = 1
  gGame.menu.layer = 2
end

on ButtonUp me
  p.transform = p.button.transform.duplicate()
  p.button = VOID
  p.mouseDown = 0
  gGame.menu.layer = 0
end

on delete me
  p = [:]
  if gSystem.scriptList.getPos(me) <> 0 then
    gSystem.scriptList.deleteOne(me)
  else
    gGame.scriptList.deleteOne(me)
  end if
end
