-- [Script] [PS] Default Progress (Script #6116)
-- Script Type: Parent

property p
global gSystem, gGame

on new me, tDataList
  p = [:]
  p[#event] = tDataList.event
  p[#progress] = [tDataList.currentCommand, tDataList.totalCommands]
  p[#member] = member("DefaultProgress")
  p[#textMember] = member("DefaultProgressText")
  p[#model] = p.member.model("ProgressIndicator")
  p[#Init] = #void
  p[#ScriptName] = "Default Progress"
  p[#texture] = p.member.newTexture("ProgressText_Texture", #fromImageObject, p.textMember.image)
  p.texture.renderFormat = #rgba4444
  p.texture.quality = #low
  p.texture.nearFiltering = 0
  tShader = p.member.shader("ProgressText_Material")
  tShader.textureList[1] = p.texture
  tShader.textureRepeatList[1] = 0
  p[#camera] = p.member.camera("Progress_Camera")
  p.camera.projection = #orthographic
  p.camera.orthoHeight = gGame.stageSize[2]
  p.camera.transform.position.x = gGame.stageSize[1] * 0.5
  p.camera.transform.position.z = -gGame.stageSize[2] * 0.5
  tCamera = p.member.camera("DefaultView")
  tCamera.projection = #orthographic
  tCamera.orthoHeight = gGame.stageSize[2]
  tCamera.transform.position.x = gGame.stageSize[1] * 0.5
  tCamera.transform.position.z = -gGame.stageSize[2] * 0.5
  p[#TargetRect] = rect(0, 0, gGame.stageSize[1], gGame.stageSize[2])
  p.camera.rect = p.TargetRect
  tCamera.rect = p.TargetRect
  p.member.model("Black").transform.scale.x = gGame.stageSize[1]
  p.member.model("Black").transform.scale.z = gGame.stageSize[2]
  p.member.model("Progress").transform.position = vector(gGame.stageSize[1], 0.0, -gGame.stageSize[2])
  me.update([#command: tDataList.command, #currentCommand: tDataList.currentCommand])
  p[#me] = me
  return me
end

on update me, tDataList
  p.progress[1] = tDataList.currentCommand
  tPerc = float(p.progress[1]) / float(p.progress[2])
  me.Initialize()
  me.UpdateVisuals(tPerc)
  set the stageColor to the stageColor
  _movie.updateStage()
  if p.progress[1] = p.progress[2] then
    delete me
  end if
end

on Initialize me
  if (voidp(gGame[#sprite]) = 1) and (p.Init <> #TwoD) then
    p[#channel] = _movie.lastChannel
    _movie.puppetSprite(p.channel, 1)
    p[#sprite] = sprite(p.channel)
    p.sprite.member = p.member
    p.sprite.width = gGame.stageSize[1]
    p.sprite.height = gGame.stageSize[2]
    p.sprite.loc = point(integer(gGame.stageSize[1] * 0.5), integer(gGame.stageSize[2] * 0.5))
    p.Init = #TwoD
  end if
  if (voidp(gGame[#sprite]) = 0) and (p.Init <> #threeD) then
    if p.Init = #TwoD then
      me.ResetTwoD()
    end if
    gGame.sprite.addCamera(p.camera, gGame.sprite.cameraCount() + 1)
    p.camera.rect = p.TargetRect
    p.Init = #threeD
  end if
end

on UpdateVisuals me, tPerc
  tString = "INITIALIZING... " & string(integer(tPerc * 100)) & "%"
  p.textMember.text = tString
  p.texture.image = p.textMember.image
  p.model.rotate(0, 0, -6, #self)
  if p.camera.rect <> p.TargetRect then
    p.camera.rect = p.TargetRect
  end if
end

on UpdateCamera me, tCamera
  if p.Init <> #threeD then
    return 0
  end if
  gGame.sprite.addCamera(p.camera, gGame.sprite.cameraCount() + 1)
  if p.camera.rect <> p.TargetRect then
    p.camera.rect = p.TargetRect
  end if
end

on delete me
  if p.Init = #TwoD then
    me.ResetTwoD()
  end if
  if p.Init = #threeD then
    me.ResetThreeD()
  end if
  p.member.resetWorld()
  p.textMember.text = EMPTY
  p.me = VOID
  p = [:]
  gSystem.UpdateScript = #none
end

on ResetTwoD me
  p.sprite.member = VOID
  p.sprite = VOID
  _movie.puppetSprite(p.channel, 0)
end

on ResetThreeD me
  tSprite = gGame.sprite
  tCount = tSprite.cameraCount()
  tIndex = 0
  repeat with i = 1 to tCount
    if tSprite.camera(i).name = p.camera.name then
      tIndex = i
    end if
  end repeat
  if tIndex > 0 then
    tSprite.deleteCamera(tIndex)
  end if
end
