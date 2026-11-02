-- [Script] [PS] Menu (Script #6129)
-- Script Type: Parent

property p
global gSystem, gData, gGame

on new me, tDataList
  p = [:]
  p[#sprite] = sprite(tDataList[#SpriteNR])
  p[#ScriptName] = "Menu"
  p[#button] = VOID
  p[#PreviousButton] = VOID
  p[#mouseDown] = 0
  p[#rightMouseDown] = 0
  gGame[#menu] = [:]
  gGame.menu[#memberList] = []
  gGame.menu[#layer] = 0
  gGame.menu[#textButtons] = [:]
  gGame.menu[#buttons] = [:]
  gGame.menu[#PressedButton] = #none
  gSystem.MenuScript = me
  return me
end

on enterFrame me
  tOptionList = [#maxNumberOfModels: 3, #levelOfDetail: #detailed]
  tPoint = _mouse.mouseLoc
  if (tPoint.locH < 0) or (tPoint.locV < 0) then
    return 0
  end if
  if (tPoint.locH > gGame.resolution[1]) or (tPoint.locV > gGame.resolution[2]) then
    return 0
  end if
  tList = []
  repeat with k in gGame.menu.memberList
    tCount = k.camera.count
    repeat with i = 1 to tCount
      tCamera = k.camera[i]
      if tCamera.name = "DefaultView" then
        next repeat
      end if
      if tCamera.rect = rect(0, 0, 1, 1) then
        next repeat
      end if
      tModelList = tCamera.modelsUnderLoc(_mouse.mouseLoc, tOptionList)
      if tModelList.count > 0 then
        repeat with j = 1 to tModelList.count
          tmodel = tModelList[j].model
          if voidp(gGame.menu.buttons[tmodel.name]) = 0 then
            if gGame.menu.buttons[tmodel.name].layer = gGame.menu.layer then
              tData = gGame.menu.buttons[tmodel.name]
              if tData.alpha = 0 then
                tList.add(tmodel)
                next repeat
              end if
              if GetAlphaPixel(tModelList[j]) <> color(0) then
                tList.add(tmodel)
              end if
            end if
          end if
        end repeat
      end if
    end repeat
  end repeat
  if tList.count = 0 then
    p.button = VOID
  else
    p.button = tList[1]
  end if
  if (p.button = VOID) and (p.PreviousButton <> VOID) then
    me.ButtonLeave(p.PreviousButton)
  end if
  if p.button <> VOID then
    me.ButtonEnter()
  end if
  if p.button = VOID then
    p.mouseDown = 0
  end if
  if _mouse.mouseDown and (p.button <> VOID) and (p.mouseDown = 0) then
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
    if p.PreviousButton <> VOID then
      me.ButtonLeave()
    end if
  end if
  _player.cursor(280)
  me.NormalButtonEnter(p.button)
  p.PreviousButton = p.button
end

on ButtonLeave me
  _player.cursor(-1)
  me.NormalButtonLeave(p.PreviousButton)
end

on ButtonDown me
  me.NormalButtonDown(p.button)
  p.mouseDown = 1
end

on ButtonUp me
  _player.cursor(-1)
  me.NormalButtonUp(p.button)
  p.mouseDown = 0
end

on NormalButtonEnter me, tButton
  tList = gGame.menu.buttons[tButton.name]
  if tList.effect <> #none then
    tmember = member(tList.member)
    repeat with i in tList.effect
      case i of
        #handlerRollover:
          if tList.handlers.count >= 2 then
            sendSprite(0, symbol(tList.handlers[2]), tmember.name, [#model: tButton.name])
          end if
        #eventRollover:
          if tList.Events.count >= 2 then
            event(0, symbol(tList.Events[2]))
          end if
        #modelRollover:
          if tList.resources.count >= 2 then
            tButton.resource = tmember.modelResource(tList.resources[2])
          end if
        #textureRollover:
          if tList.textures.count >= 2 then
            tButton.shader.textureList[1] = tmember.texture(tList.textures[2])
          end if
        #shaderRollover:
          if tList.shaders.count >= 2 then
            tButton.shader = tmember.shader(tList.shaders[2])
          end if
      end case
    end repeat
  end if
  if tList.rolloverSound <> #none then
    PlaySound(0, tList.rolloverSound, [#Override: 1, #volume: 1.0])
  end if
end

on NormalButtonLeave me, tButton
  tList = gGame.menu.buttons[tButton.name]
  if tList = VOID then
    p.PreviousButton = VOID
    return 0
  end if
  if tList.effect <> #none then
    tmember = member(tList.member)
    repeat with i in tList.effect
      case i of
        #handlerRollover:
          if tList.handlers.count >= 1 then
            sendSprite(0, symbol(tList.handlers[1]), tmember.name, [#model: tButton.name])
          end if
        #eventRollover:
          if tList.Events.count >= 1 then
            event(0, symbol(tList.Events[1]))
          end if
        #modelRollover:
          if tList.resources.count >= 1 then
            tButton.resource = tmember.modelResource(tList.resources[1])
          end if
        #textureRollover:
          if tList.textures.count >= 1 then
            tButton.shader.textureList[1] = tmember.texture(tList.textures[1])
          end if
        #shaderRollover:
          if tList.shaders.count >= 1 then
            tButton.shader = tmember.shader(tList.shaders[1])
          end if
      end case
    end repeat
  end if
  p.PreviousButton = VOID
end

on NormalButtonDown me, tButton
  tList = gGame.menu.buttons[tButton.name]
  if tList.effect <> #none then
    tmember = member(tList.member)
    repeat with i in tList.effect
      case i of
        #handlerRollover:
          if tList.handlers.count = 3 then
            sendSprite(0, symbol(tList.handlers[3]), tmember.name, [#model: tButton.name])
          end if
        #eventRollover:
          if tList.Events.count = 3 then
            event(0, symbol(tList.Events[3]))
          end if
        #modelRollover:
          if tList.resources.count = 3 then
            tButton.resource = tmember.modelResource(tList.resources[3])
          end if
        #textureRollover:
          if tList.textures.count = 3 then
            tButton.shader.textureList[1] = tmember.texture(tList.textures[3])
          end if
        #shaderRollover:
          if tList.shaders.count = 3 then
            tButton.shader = tmember.shader(tList.shaders[3])
          end if
      end case
    end repeat
  end if
  if tList.pressedSound <> #none then
    PlaySound(0, tList.pressedSound, [#Override: 1, #volume: 1.0])
  end if
end

on NormalButtonUp me, tButton
  tList = gGame.menu.buttons[tButton.name]
  me.NormalButtonLeave(tButton)
  gGame.menu.PressedButton = tButton.name
  if tList.event <> #none then
    event(0, tList.event)
  end if
  if tList[#handler].ilk = #string then
    sendSprite(0, symbol(tList.handler), tButton.name)
  end if
  gGame.menu.PressedButton = #none
end

on GetAlphaPixel iSectList
  tmodel = iSectList.model
  tmember = tmodel.shader.textureList[1].member
  tImage = tmember.image
  tmodel.addModifier(#meshDeform)
  tFace = iSectList.faceID
  tUVCoord = iSectList.uvCoord
  tCoordList = tmodel.meshDeform.mesh[iSectList.meshID].textureCoordinateList
  tFaceList = tmodel.meshDeform.mesh[iSectList.meshID].face[tFace]
  tmodel.removeModifier(#meshDeform)
  tLocA = tCoordList[tFaceList[1]]
  tLocA = point(tLocA[1] * tImage.width, (1 - tLocA[2]) * tImage.height)
  tLocB = tCoordList[tFaceList[2]]
  tLocB = point(tLocB[1] * tImage.width, (1 - tLocB[2]) * tImage.height)
  tLocC = tCoordList[tFaceList[3]]
  tLocC = point(tLocC[1] * tImage.width, (1 - tLocC[2]) * tImage.height)
  tUVector = (tLocB - tLocA) * tUVCoord.u
  tVVector = (tLocC - tLocA) * tUVCoord.V
  tPos = tLocA + tUVector + tVVector
  tAlpha = tImage.extractAlpha().getPixel(tPos)
  return tAlpha
end

on delete me
  p = [:]
  gSystem.MenuScript = #none
  gGame.deleteProp(#menu)
  if gSystem.scriptList.getPos(me) <> 0 then
    gSystem.scriptList.deleteOne(me)
  else
    gGame.scriptList.deleteOne(me)
  end if
end
