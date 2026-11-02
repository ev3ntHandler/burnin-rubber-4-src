-- [Script] [PS] FPSCounter (Script #6125)
-- Script Type: Parent

property p
global gSystem, gGame

on new me, tDataList
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    tDataList = [:]
  end if
  if voidp(gGame[#FPSCounter]) = 1 then
    return 0
  end if
  if gGame[#FPSCounter] = 0 then
    return 0
  end if
  p = [:]
  tSprite = sprite(1)
  if tDataList[#sprite].ilk = #integer then
    tSprite = sprite(tDataList.sprite)
  end if
  if tDataList[#sprite].ilk = #sprite then
    tSprite = tDataList.sprite
  end if
  if tSprite.member = member(0, 0) then
    return 0
  else
    p[#sprite] = tSprite
  end if
  p[#camera] = tSprite.camera(tSprite.cameraCount())
  p[#member] = p.sprite.member
  tUD = p.camera.userData
  if tUD[#member].ilk = #member then
    p.member = p.camera.userData.member
  end if
  p[#textMember] = member("FPSCounterText")
  p[#ScriptName] = tDataList[#ScriptName]
  if p.ScriptName = VOID then
    p.ScriptName = "[PS] FPSCounter"
  end if
  p[#texture] = p.member.newTexture("FPS_Texture")
  p.texture.quality = #lowFiltered
  p.texture.renderFormat = #rgba4444
  p.texture.member = p.textMember
  p.camera.addOverlay(p.texture, point(2, 0), 0)
  FPSInit()
  return me
end

on FPSInit
  p[#FPS_Min] = the maxinteger
  p[#FPS_Max] = 0
  p[#FPS_Now] = 0
  p[#FPS_Tally] = 0
  p[#FPS_Entries] = 0
  p[#frameCount] = 0
  p[#MaxInterval] = 100
  p[#TimePeriod] = 2000
  p[#milliSeconds] = the milliSeconds
  p[#FrameInterval] = 100
  p[#NextMilliseconds] = p.milliSeconds + p.TimePeriod
  p.textMember.text = "FPS Counter initializing..."
end

on enterFrame me
  p.FrameInterval = (_system.milliSeconds - p.milliSeconds + p.FrameInterval) * 0.5
  if p.FrameInterval > p.MaxInterval then
    p.FrameInterval = p.MaxInterval
  end if
  if p.FrameInterval < 1 then
    p.FrameInterval = 1
  end if
  p.milliSeconds = _system.milliSeconds
  p.frameCount = p.frameCount + 1
  if p.milliSeconds > p.NextMilliseconds then
    p.FPS_Now = p.frameCount / float(p.milliSeconds - p.NextMilliseconds + p.TimePeriod) * 1000
    p.NextMilliseconds = p.milliSeconds + p.TimePeriod
    p.frameCount = 0
    if (p.FPS_Now < p.FPS_Min) and (p.FPS_Max <> 0) then
      p.FPS_Min = p.FPS_Now
    end if
    if p.FPS_Now > p.FPS_Max then
      p.FPS_Max = p.FPS_Now
    end if
    if p.FPS_Min <> the maxinteger then
      p.FPS_Tally = p.FPS_Tally + p.FPS_Now
      p.FPS_Entries = p.FPS_Entries + 1
      fptemp = p.FPS_Tally / p.FPS_Entries
    else
      fptemp = "Calculating..."
    end if
    if p.FPS_Min = the maxinteger then
      tFPSMin = "Calculating..."
    else
      tFPSMin = p.FPS_Min
    end if
    set the floatPrecision to 1
    tText = "MIN: " & string(tFPSMin) & "   MAX: " & string(p.FPS_Max) & "   NOW: " & string(p.FPS_Now) & "   AVG: " & string(fptemp)
    set the floatPrecision to 4
    p.textMember.text = tText
    p.texture.image = p.textMember.image
  end if
end

on delete me
  p = [:]
  if gSystem.scriptList.getPos(me) <> 0 then
    gSystem.scriptList.deleteOne(me)
  else
    gGame.scriptList.deleteOne(me)
  end if
end
