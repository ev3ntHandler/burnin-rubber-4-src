-- [Script] [M] World Manager (Script #5857)
-- Script Type: Movie

global gData, gGame

on WorldManagerGetState me
  tScript = GetScript(0, EMPTY, [#script: "World Manager"])
  if tScript <> 0 then
    return tScript.WorldManagerGetState()
  end if
end

on WorldManagerSetState me, tTarget, tDataList
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return 0
  end if
  tScript = GetScript(0, EMPTY, [#script: "World Manager"])
  if tScript <> 0 then
    tScript.setState(EMPTY, tDataList)
  end if
end

on WorldManagerInitTileAndGrid me, tTarget, tDataList
  tScript = GetScript(0, EMPTY, [#script: "World Manager"])
  if tScript <> 0 then
    tScript.InitTileAndGrid()
  end if
end

on BakeShadows me, tTarget
  tMIll = _system.milliSeconds
  tmember = member(gGame.member.name)
  tLightList = [tmember.light("Sun").worldPosition]
  if tmember.model("LightCatcher") = VOID then
    tLightCatcherResource = tmember.newModelResource("LightCatcher", #sphere)
    tLightCatcherResource.radius = 0.5
    tLightCatcher = tmember.newModel("LightCatcher", tLightCatcherResource)
    tLightCatcher.addModifier(#meshDeform)
  else
    tLightCatcher = tmember.model("LightCatcher")
  end if
  tModelList = [tmember.model("05_05_WorldCityStreet"), tmember.model("06_05_WorldCityStreet")]
  repeat with i in tModelList
    tmodel = i
    tWorldPosition = tmodel.worldPosition
    tRes = tmodel.resource
    tVertexList = tRes.vertexList
    tFaceCount = tRes.face.count
    tOldColorList = tRes.colorList
    tColorList = []
    repeat with i = 1 to tVertexList.count
      tColorList.add(rgb(255, 255, 255))
    end repeat
    tCheckModelList = tModelList.duplicate()
    tCheckModelList.deleteOne(tmodel)
    tCheckList = []
    repeat with i = 1 to tFaceCount
      tFace = tRes.face[i].vertices
      repeat with j = 1 to 3
        if tCheckList.getPos(tFace[j]) <> 0 then
          next repeat
        end if
        tVertex = tmodel.getWorldTransform() * tVertexList[tFace[j]]
        tHits = 0
        tLightCatcher.transform.position = tVertex
        _movie.updateStage()
        repeat with k in tLightList
          tDirection = tVertex - k
          tDirection.normalize()
          tIntersectDetails = tmember.modelsUnderRay(k, tDirection)
          if tIntersectDetails.count > 0 then
            if tIntersectDetails[1] = tLightCatcher then
              tHits = tHits + 1
            end if
          end if
        end repeat
        tPerc = float(tHits) / tLightList.count
        tColor = integer(255 * tPerc)
        tColor = rgb(tColor, tColor, tColor)
        tColorList[tFace[j]] = tColor
        tCheckList.add(tFace[j])
      end repeat
    end repeat
    tFinalColorLIst = []
    repeat with i = 1 to tColorList.count
      theColour1 = tOldColorList[i]
      theColour2 = tColorList[i]
      theRed = theColour1.red * theColour2.red / 255.0
      theGreen = theColour1.green * theColour2.green / 255.0
      theBlue = theColour1.blue * theColour2.blue / 255.0
      theNewColour = color(theRed, theGreen, theBlue)
      tFinalColorLIst.add(theNewColour)
    end repeat
    tRes.colorList = tFinalColorLIst
    repeat with i = 1 to tFaceCount
      tFace = tRes.face[i].vertices
      tRes.face[i].colors = tFace
    end repeat
    tRes.build()
  end repeat
  put _system.milliSeconds - tMIll
end

on GetTile me, tMarker, tCenterTile, tString
  if tString = VOID then
    tString = 0
  end if
  tList = gData.data[symbol(gGame.world & "Markers")]
  the itemDelimiter = "_"
  tCount = tList.count
  repeat with i = 1 to tCount
    tProp = tList.getPropAt(i)
    tEntry = tList[tProp]
    tCount2 = tEntry.count
    repeat with j = 1 to tCount2
      tProp2 = tEntry.getPropAt(j)
      if tProp2 = tMarker then
        tTile = string(tProp)
        tTile = [value(tTile.item[1]), value(tTile.item[2])]
        if tCenterTile = 1 then
          gGame.WorldStartTile[symbol(gGame.world)] = tTile
        end if
        if tString = 0 then
          return tTile
          next repeat
        end if
        return string(tProp)
      end if
    end repeat
  end repeat
  if tCenterTile = 1 then
    return gGame.WorldStartTile[symbol(gGame.world)]
  else
    return #none
  end if
end
