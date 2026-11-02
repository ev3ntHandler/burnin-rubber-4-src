-- [Script] [M] 3D HandlerList Functions (Script #6151)
-- Script Type: Movie

global gSystem, gGame

on RunHandlerList me
  repeat with i in gSystem.handlerList
    case i of
      #Rotator:
        Rotator()
      #Scroller:
        Scroller()
      #billboard:
        billboard()
      #Interpolator:
        Interpolator()
      #PointAtor:
        PointAtor()
      #Mimic:
        Mimic()
      #Scaler:
        Scaler()
      #fader:
        fader()
      #Colorize:
        Colorize()
      otherwise:
        if i.ilk = #string then
          do(i)
        end if
        if i.ilk = #list then
          RunHandlerSubList(i)
        end if
    end case
  end repeat
end

on RunHandlerSubList me, tList
  if tList[2] = tList[3] then
    do(tList[1])
    tList[2] = 0
  else
    tList[2] = tList[2] + 1
  end if
end

on RemoveFromHandlerList me, tTarget, tDataList
  tOne = VOID
  repeat with i in gSystem.handlerList
    if i.ilk = #list then
      if i[1] = value(tTarget) then
        tOne = i
      end if
      exit repeat
      next repeat
    end if
    if i = value(tTarget) then
      tOne = i
    end if
    exit repeat
  end repeat
  if tOne <> VOID then
    gSystem.handlerList.deleteOne(tOne)
    return 1
  else
    return 0
  end if
end

on ClearHandlerLists me
  tList = [#RotatorList, #ScrollerList, #BillBoardList, #InterPolatorList, #PointAtList, #MimicList]
  repeat with i in tList
    gSystem[i] = [:]
  end repeat
end

on AddToRotator me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    exit
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    exit
  end if
  tModelList = []
  tString = EMPTY
  if tDataList[#string].ilk = #string then
    tString = tDataList[#string]
  end if
  if (tString <> EMPTY) and (tString <> VOID) then
    tModelList = GetModelList(tmember, tString)
  end if
  tModelName = EMPTY
  if tDataList[#model].ilk = #string then
    tModelName = tDataList[#model]
  end if
  tmodel = tmember.model(tModelName)
  if tmodel <> VOID then
    tModelList.add(tmodel)
  end if
  if tModelList.count = 0 then
    exit
  end if
  tVector = vector(0, 0, 0)
  if tDataList[#rotation].ilk = #vector then
    tVector = tDataList[#rotation]
  end if
  tRelativeTo = #self
  if tDataList[#relativeTo] = #symbol then
    tRelativeTo = tDataList[#relativeTo]
  end if
  if tDataList[#relativeTo] = #string then
    tRelativeTo = GetReferenceType(tmember, tDataList[#relativeTo])
  end if
  if tRelativeTo = VOID then
    exit
  end if
  tList = [tModelList, tVector, tRelativeTo]
  if gSystem[#RotatorList] = VOID then
    gSystem[#RotatorList] = [:]
  end if
  gSystem.RotatorList[symbol(tmodel.name)] = tList
  if gSystem.handlerList.getPos(#Rotator) = VOID then
    gSystem.handlerList.add(#Rotator)
  end if
end

on Rotator me
  repeat with i in gSystem.RotatorList
    repeat with j in i[1]
      j.rotate(i[2], i[3])
    end repeat
  end repeat
end

on AddToScroller me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    exit
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tShader = VOID
  if tDataList[#shader].ilk = #string then
    tShader = tmember.shader(tDataList[#shader])
  end if
  if tShader = VOID then
    return 0
  end if
  tLayer = 1
  if tDataList[#layer].ilk = #integer then
    tLayer = tDataList[#layer]
  end if
  tTime = gGame.tempo
  if tDataList[#time].ilk = #integer then
    tTime = tDataList.time
  end if
  tTimer = [0, integer(float(tTime) / gGame.tempo)]
  tPosition = vector(0, 0, 0)
  if tDataList[#position].ilk = #vector then
    tPosition = tDataList[#position]
  end if
  tRotation = vector(0, 0, 0)
  if tDataList[#rotation].ilk = #vector then
    tRotation = tDataList[#rotation]
  end if
  tCap = 0
  if tDataList[#cap].ilk = #integer then
    tCap = tDataList[#cap]
  end if
  tList = [[tShader], tLayer, tTimer, tPosition, tRotation]
  if voidp(gSystem[#ScrollerList]) = 1 then
    gSystem[#ScrollerList] = [:]
  end if
  gSystem.ScrollerList[symbol(tShader.name)] = tList
  if gSystem.handlerList.getPos(#Scroller) = VOID then
    gSystem.handlerList.add(#Scroller)
  end if
end

on Scroller me
  repeat with i in gSystem.ScrollerList
    i[3][1] = i[3][1] + 1
    if i[3][1] = i[3][2] then
      repeat with j in i[1]
        j.textureTransformList[i[2]].position = j.textureTransformList[i[2]].position + (i[4] * gGame.TimeMP)
        j.textureTransformList[i[2]].rotation = j.textureTransformList[i[2]].rotation + (i[5] * gGame.TimeMP)
      end repeat
      i[3][1] = 0
    end if
  end repeat
end

on AddToBillBoard me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    exit
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tmodel = VOID
  if tDataList[#model].ilk = #string then
    tmodel = tmember.model(tDataList[#model])
  end if
  if tmodel = VOID then
    return 0
  end if
  tmodel.pointAtOrientation = [vector(0, 1, 0), vector(0, 0, 1)]
  tCamera = VOID
  if tDataList[#camera].ilk = #string then
    tCamera = tmember.camera(tDataList[#camera])
  end if
  if tCamera = VOID then
    return 0
  end if
  tUpVector = vector(0, 0, 1)
  if tDataList[#upvector].ilk = #string then
    tUpVector = tDataList[#upvector]
  end if
  tList = [tmodel, tCamera, tUpVector]
  if gSystem[#BillBoardList] = VOID then
    gSystem[#BillBoardList] = [:]
  end if
  gSystem.BillBoardList[symbol(tmodel.name)] = tList
  if gSystem.handlerList.getPos(#billboard) = VOID then
    gSystem.handlerList.add(#billboard)
  end if
end

on billboard me
  repeat with i in gSystem.BillBoardList
    i[1].pointAt(i[2].getWorldTransform().position, i[3])
  end repeat
end

on AddToInterPolator me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    exit
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  if tDataList[#object].ilk = #string then
    tObject = GetReferenceType(0, tmember, tDataList.object)
  else
    return 0
  end if
  if tObject = VOID then
    return 0
  else
    t1 = tObject.transform
  end if
  tTarget = VOID
  if tDataList[#target].ilk = #string then
    tTarget = GetReferenceType(0, tmember, tDataList.target)
  end if
  if tTarget <> VOID then
    t2 = tTarget.transform
  else
    t2 = tObject.transform.duplicate()
    if (tDataList[#OffSetX].ilk = #integer) or (tDataList[#OffSetX].ilk = #float) then
      t2.position.x = t2.position.x + tDataList.OffSetX
    end if
  end if
  if tDataList[#Percentage].ilk = #integer then
    tPerc = tDataList.Percentage
  else
    tPerc = 50
  end if
  if tDataList[#event].ilk = #string then
    tEvent = tDataList.event
  else
    tEvent = #none
  end if
  if tDataList[#handler].ilk = #string then
    tHandler = tDataList.handler
  else
    tHandler = #none
  end if
  if (tDataList[#Threshold].ilk = #integer) or (tDataList[#Threshold].ilk = #float) then
    tThreshold = tDataList.Threshold
  else
    tThreshold = 0.01
  end if
  tList = [t1, t2, tPerc, tThreshold, tEvent, tHandler]
  if gSystem[#InterPolatorList] = VOID then
    gSystem[#InterPolatorList] = [:]
  end if
  gSystem.InterPolatorList[symbol(tObject.name)] = tList
  if gSystem.handlerList.getPos(#Interpolator) = VOID then
    gSystem.handlerList.add(#Interpolator)
  end if
end

on Interpolator me
  tList = gSystem.InterPolatorList.duplicate()
  repeat with i in tList
    i[1].interpolateTo(i[2], i[3])
    if (abs((i[1].position - i[2].position) * vector(1, 1, 1)) < i[4]) and (abs((i[1].rotation - i[2].rotation) * vector(1, 1, 1)) < i[4]) then
      if i[5] <> #none then
        event(0, i[5])
      end if
      if i[6] <> #none then
        sendSprite(0, symbol(i[6]), 0)
      end if
      i[1].position = i[2].position
      gSystem.InterPolatorList.deleteOne(i)
    end if
  end repeat
end

on AddToPointAt me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    exit
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  if tDataList[#object].ilk = #string then
    tObject = GetReferenceType(tmember, tDataList.object)
  else
    return 0
  end if
  if tObject = VOID then
    return 0
  end if
  if tDataList[#target].ilk = #string then
    tTarget = GetReferenceType(tmember, tDataList.target)
  else
    return 0
  end if
  if tTarget = VOID then
    return 0
  end if
  if tDataList[#upvector].ilk = #vector then
    tUpVector = tDataList.upvector
  else
    tUpVector = vector(0, 0, 1)
  end if
  tList = [tObject, tTarget, tUpVector]
  if gSystem[#PointAtList] = VOID then
    gSystem[#PointAtList] = [:]
  end if
  gSystem.PointAtList[symbol(tObject.name)] = tList
  if gSystem.handlerList.getPos(#PointAtor) = VOID then
    gSystem.handlerList.add(#PointAtor)
  end if
end

on PointAtor me
  repeat with i in gSystem.PointAtList
    i[1].pointAt(i[2].worldPosition, i[3])
  end repeat
end

on AddToMimic me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    exit
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  if tDataList[#object].ilk = #string then
    tObject = GetReferenceType(tmember, tDataList.object)
  else
    return 0
  end if
  if tObject = VOID then
    return 0
  end if
  if tDataList[#target].ilk = #string then
    tTarget = GetReferenceType(tmember, tDataList.target)
  else
    return 0
  end if
  if tTarget = VOID then
    return 0
  end if
  tList = [tObject, tTarget]
  if gSystem[#MimicList] = VOID then
    gSystem[#MimicList] = [:]
  end if
  gSystem.MimicList[symbol(tTarget.name)] = tList
  if gSystem.handlerList.getPos(#Mimic) = VOID then
    gSystem.handlerList.add(#Mimic)
  end if
end

on Mimic me
  repeat with i in gSystem.MimicList
    i[1].transform = i[2].getWorldTransform()
  end repeat
end

on AddToScaler me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    exit
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  if tDataList[#object].ilk = #string then
    tObject = GetReferenceType(tmember, tDataList.object)
  else
    return 0
  end if
  if tDataList[#start].ilk = #vector then
    tStart = tDataList.start
  else
    if tDataList[#start].ilk = #float then
      tStart = vector(1, 1, 1) * tDataList.start
    else
      if tDataList[#start].ilk = #integer then
        tStart = vector(1, 1, 1) * tDataList.start
      else
        tStart = VOID
      end if
    end if
  end if
  if tDataList[#end].ilk = #vector then
    tEnd = tDataList.end
  else
    if tDataList[#end].ilk = #float then
      tEnd = vector(1, 1, 1) * tDataList.end
    else
      if tDataList[#end].ilk = #integer then
        tEnd = vector(1, 1, 1) * tDataList.end
      else
        tEnd = VOID
      end if
    end if
  end if
  if (tStart = VOID) or (tEnd = VOID) then
    return 0
  end if
  if tStart = vector() then
    tStart = vector(0.001, 0.001, 0.001)
  end if
  if tEnd = vector() then
    tEnd = vector(0.001, 0.001, 0.001)
  end if
  if tDataList[#setStart].ilk = #integer then
    if tDataList.setStart = 1 then
      tObject.transform.scale = tStart
    end if
  end if
  if tDataList[#interpolate].ilk = #integer then
    tInterpolate = tDataList.interpolate
  else
    tInterpolate = 0
  end if
  if (tDataList[#Percentage].ilk = #integer) or (tDataList[#Percentage] = #float) then
    tPercentage = tDataList.Percentage
  else
    tPercentage = 0
  end if
  if tDataList[#duration].ilk = #integer then
    tDuration = integer(float(tDataList.duration) / gGame.tempo)
  else
    tDuration = integer(1000.0 / gGame.tempo)
  end if
  if tDataList[#event].ilk = #string then
    tEvent = tDataList.event
  else
    tEvent = EMPTY
  end if
  if tDataList[#handler].ilk = #string then
    tHandler = tDataList.handler
  else
    tHandler = EMPTY
  end if
  tStore = #none
  if tDataList[#Store].ilk = #symbol then
    tStore = tDataList.Store
    gGame[tStore] = tStart.duplicate()
  end if
  tDependency = #none
  if tDataList[#dependency].ilk = #symbol then
    tDependency = tDataList.dependency
  end if
  if tInterpolate = 0 then
    tStep = (tEnd - tStart) / tDuration
  else
    tStep = 0
  end if
  tList = [tObject, tStart, tEnd, tStep, tInterpolate, tPercentage, tDuration, tEvent, tHandler, tStore, tDependency]
  if gSystem[#ScalerList] = VOID then
    gSystem[#ScalerList] = []
  end if
  gSystem.ScalerList.add(tList)
  if gSystem.handlerList.getPos(#Scaler) = VOID then
    gSystem.handlerList.add(#Scaler)
  end if
end

on Scaler me
  tDeleteList = []
  repeat with i in gSystem.ScalerList
    if i[11] <> #none then
      if gGame[i[11]] = 1 then
        if i[5] = 1 then
          tTargetT = i[1].transform.duplicate()
          tTargetT.scale = i[3]
          tSourceT = i[1].transform
          tSourceT.interpolateTo(tTargetT, i[6])
          if i[10] <> #none then
            gGame[i[10]] = i[1].transform.scale.duplicate()
          end if
        else
          tScale = i[1].transform.scale + i[4]
          if tScale.x < 0.001 then
            tScale.x = 0.001
          end if
          if tScale.y < 0.001 then
            tScale.y = 0.001
          end if
          if tScale.z < 0.001 then
            tScale.z = 0.001
          end if
          i[1].transform.scale = tScale
          if i[10] <> #none then
            gGame[i[10]] = i[1].transform.scale.duplicate()
          end if
        end if
        i[7] = i[7] - 1
        if i[7] = 0 then
          i[1].transform.scale = i[3]
          if i[8] <> EMPTY then
            event(i[8])
          end if
          if i[9] <> EMPTY then
            sendSprite(0, symbol(i[9]), 0)
          end if
          tDeleteList.add(i)
        end if
      end if
    end if
  end repeat
  repeat with i in tDeleteList
    gSystem.ScalerList.deleteOne(i)
  end repeat
end

on AddToFader me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    exit
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tmodel = tmember.model(tDataList[#model])
  if tmodel = VOID then
    exit
  end if
  tChildren = 0
  if tDataList[#children].ilk = #integer then
    tChildren = tDataList.children
  end if
  tModelList = [tmodel]
  if tChildren = 1 then
    tModelList = GetChildren(0, tModelList, tmodel)
  end if
  tShaderList = []
  repeat with i in tModelList
    tmodel = i
    repeat with j = 1 to tmodel.shaderList.count
      tShaderList.add(tmodel.shaderList[j])
    end repeat
  end repeat
  if (tDataList[#start].ilk = #integer) or (tDataList[#start].ilk = #float) then
    repeat with i in tShaderList
      i.blend = tDataList.start
    end repeat
  end if
  tFade = 0.0
  if (tDataList[#Fade].ilk = #integer) or (tDataList[#Fade].ilk = #float) then
    tFade = tDataList.Fade
  end if
  tTime = [0, integer(150.0 / gGame.tempo)]
  if (tDataList[#time].ilk = #integer) or (tDataList[#time].ilk = #float) then
    tTime = [0, integer(tDataList.time / gGame.tempo)]
  end if
  tBlend = float(tShaderList[1].blend)
  tStep = (tBlend - tFade) / tTime[2]
  tEvent = #none
  if (tDataList[#event].ilk = #string) or (tDataList[#event].ilk = #symbol) then
    tEvent = tDataList.event
  end if
  tHandler = #none
  if (tDataList[#handler].ilk = #string) or (tDataList[#handler].ilk = #symbol) then
    tHandler = tDataList.handler
  end if
  tList = [tShaderList, tStep, tFade, tTime, tEvent, tHandler]
  if gSystem[#FaderList] = VOID then
    gSystem[#FaderList] = [:]
  end if
  gSystem.FaderList[symbol(tmodel.name)] = tList
  if gSystem.handlerList.getPos(#fader) = VOID then
    gSystem.handlerList.add(#fader)
  end if
end

on GetChildren me, tList, tmodel
  if tList.getPos(tmodel) = 0 then
    tList.add(tmodel)
  end if
  tCount = tmodel.child.count
  repeat with i = 1 to tCount
    tChild = tmodel.child[i]
    if tList.getPos(tChild) = 0 then
      tList.add(tChild)
    end if
    if tChild.child.count > 0 then
      tList = GetChildren(0, tList, tChild)
    end if
  end repeat
  return tList
end

on fader me
  tDeleteList = []
  repeat with i in gSystem.FaderList
    tBlend = i[1][1].blend
    tBlend = tBlend - i[2]
    if (i[2] > 0) and (tBlend < i[3]) then
      tBlend = i[3]
    end if
    if (i[2] < 0) and (tBlend > i[3]) then
      tBlend = i[3]
    end if
    if tBlend = i[3] then
      tDeleteList.add(i)
      if i[5] <> #none then
        event(0, i[5])
      end if
      if i[6] <> #none then
        sendSprite(0, symbol(i[6]), 0)
      end if
    end if
    repeat with j in i[1]
      j.blend = tBlend
    end repeat
  end repeat
  repeat with i in tDeleteList
    gSystem.FaderList.deleteOne(i)
  end repeat
end

on AddToColorize me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    exit
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  if tDataList[#shader].ilk = #string then
    tShader = tmember.shader(tDataList.shader)
  end if
  if tShader = VOID then
    return VOID
  end if
  tEmissive = VOID
  if tDataList[#emissive].ilk = #color then
    tEmissive = [tDataList.emissive.red, tDataList.emissive.green, tDataList.emissive.blue]
  end if
  if tEmissive = VOID then
    return VOID
  end if
  tTime = [0, integer(150.0 / gGame.tempo)]
  if (tDataList[#time].ilk = #integer) or (tDataList[#time].ilk = #float) then
    tTime = [0, integer(tDataList.time / gGame.tempo)]
  end if
  tEmmissiveColor = [tShader.emissive.red, tShader.emissive.green, tShader.emissive.blue]
  tStep = (tEmmissiveColor - tEmissive) / tTime[2]
  tList = [tShader, tStep, tEmissive, tTime]
  put tList
  if gSystem[#ColorizeList] = VOID then
    gSystem[#ColorizeList] = [:]
  end if
  gSystem.ColorizeList[symbol(tShader.name)] = tList
  if gSystem.handlerList.getPos(#Colorize) = VOID then
    gSystem.handlerList.add(#Colorize)
  end if
end

on Colorize me
  tDeleteList = []
  repeat with i in gSystem.ColorizeList
    tCurrentEmissive = [i[1].emissive.red, i[1].emissive.green, i[1].emissive.blue]
    tCurrentEmissive = tCurrentEmissive - i[2]
    tCurrentEmissive[1] = max(0.0, min(tCurrentEmissive[1], i[3][1]))
    tCurrentEmissive[2] = max(0.0, min(tCurrentEmissive[2], i[3][2]))
    tCurrentEmissive[3] = max(0.0, min(tCurrentEmissive[3], i[3][3]))
    i[1].emissive = rgb(integer(tCurrentEmissive[1]), integer(tCurrentEmissive[2]), integer(tCurrentEmissive[3]))
    if (i[1].emissive.red = i[3][1]) and (i[1].emissive.green = i[3][2]) and (i[1].emissive.blue = i[3][3]) then
      tDeleteList.add(i)
    end if
  end repeat
  repeat with i in tDeleteList
    gSystem.ColorizeList.deleteOne(i)
  end repeat
end
