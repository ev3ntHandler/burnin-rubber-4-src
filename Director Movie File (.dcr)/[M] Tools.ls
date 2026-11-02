-- [Script] [M] Tools (Script #5856)
-- Script Type: Movie

global gSystem, gGame

on OpenColorPicker me, tTarget, tDataList
  if voidp(gGame[#AmbientStyler]) = 0 then
    CloseColorPicker()
  end if
  gGame[#ColorPicker] = window().new(_movie.path & "Data\Engine\Tools\ColorPicker.dcr")
  gGame.ColorPicker.open()
  gSystem.windows.add(gGame.ColorPicker)
  gGame.ColorPicker.movie.InitializeColorPicker(0, tTarget, tDataList)
end

on CloseColorPicker me
  if voidp(gGame[#ColorPicker]) = 0 then
    gGame.ColorPicker.forget()
    gGame.ColorPicker.close()
    gGame.deleteProp(#ColorPicker)
  end if
end

on OpenAmbientStyler me, tTarget, tDataList
  if voidp(gGame[#AmbientStyler]) = 0 then
    CloseAmbientStyler()
  end if
  gGame[#AmbientStyler] = window().new(_movie.path & "Data\Engine\Tools\AmbientStyler2.dcr")
  gGame.AmbientStyler.open()
  gSystem.windows.add(gGame.AmbientStyler)
  if tTarget = VOID then
    tmember = gGame.member
  end if
  gGame.AmbientStyler.movie.InitializeAmbientStyler(0, tmember.name, [:])
end

on CloseAmbientStyler me
  if voidp(gGame[#AmbientStyler]) = 0 then
    gGame.AmbientStyler.forget()
    gGame.AmbientStyler.close()
    gGame.deleteProp(#AmbientStyler)
  end if
end

on kut me
  repeat with i = 1 to gGame.member.model.count
    tmodel = gGame.member.model(i)
    tPosition = tmodel.transform.position
    if tPosition.z < -10 then
      put tmodel.name && tPosition
    end if
  end repeat
end
