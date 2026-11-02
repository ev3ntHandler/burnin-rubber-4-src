-- [Script] [M] 3D Logics (Script #6143)
-- Script Type: Movie

on LeftOrRight me, tTransform1, tTransform2
  pos1 = tTransform1.position - tTransform2.position
  pos1.normalize()
  pos2 = tTransform2.xAxis
  pLeftRight = pos1.dot(pos2)
  if pLeftRight < 0 then
    return [1, pLeftRight]
  else
    return [0, pLeftRight]
  end if
end

on FrontOrBack me, tTransform1, tTransform2
  if tTransform1 = VOID then
    exit
  end if
  if tTransform2 = VOID then
    exit
  end if
  if tTransform1.ilk <> #transform then
    exit
  end if
  if tTransform2.ilk <> #transform then
    exit
  end if
  pos1 = tTransform1.position - tTransform2.position
  pos1.normalize()
  pos2 = tTransform2.yAxis
  pFrontBack = pos1.dot(pos2)
  if pFrontBack < 0 then
    return [0, pFrontBack]
  else
    return [1, pFrontBack]
  end if
end

on LineLineIntersect me, tTransform1, tTransform2, tAxis1, tAxis2, tSpecial, tDisplay
  if tTransform1 = VOID then
    exit
  end if
  if tTransform2 = VOID then
    exit
  end if
  if tTransform1.ilk <> #transform then
    exit
  end if
  if tTransform2.ilk <> #transform then
    exit
  end if
  if tAxis1 = VOID then
    tAxis1 = #y
  end if
  if tAxis2 = VOID then
    tAxis2 = #y
  end if
  if tSpecial = VOID then
    tSpecial = 0
  end if
  if tDisplay = VOID then
    tDisplay = 0
  end if
  case tAxis1 of
    #x:
      pOffSet1 = tTransform1.xAxis
    #y:
      pOffSet1 = tTransform1.yAxis
    #z:
      pOffSet1 = tTransform1.zAxis
    otherwise:
      pOffSet1 = tAxis1
  end case
  a1 = point(tTransform1.position.x, tTransform1.position.y)
  a2 = point(a1.locH + pOffSet1.x, a1.locV + pOffSet1.y)
  case tAxis2 of
    #x:
      pOffSet2 = tTransform2.xAxis
    #y:
      pOffSet2 = tTransform2.yAxis
    #z:
      pOffSet2 = tTransform2.zAxis
    otherwise:
      pOffSet2 = tAxis2
  end case
  if tSpecial = 1 then
    pOffSet2 = tTransform1.xAxis
  end if
  b1 = point(tTransform2.position.x, tTransform2.position.y)
  b2 = point(b1.locH + pOffSet2.x, b1.locV + pOffSet2.y)
  if a1.locH = a2.locH then
    a2 = a2 - point(0.0002, 0.0002)
  end if
  if a1.locV = a2.locV then
    a2 = a2 - point(0.0002, 0.0002)
  end if
  bLine1 = (a1.locV - a2.locV) / (a1.locH - a2.locH)
  aLine1 = a1.locV - (bLine1 * a1.locH)
  if b1.locH = b2.locH then
    b2 = b2 - point(0.0002, 0.0002)
  end if
  if b1.locV = b2.locV then
    b2 = b2 - point(0.0002, 0.0002)
  end if
  bLine2 = (b1.locV - b2.locV) / (b1.locH - b2.locH)
  aLine2 = b1.locV - (bLine2 * b1.locH)
  tHack1 = bLine1 - bLine2
  if tHack1 = 0.0 then
    tHack1 = 0.0001
  end if
  tHack2 = aLine1 - aLine2
  if tHack2 = 0.0 then
    tHack2 = 0.0001
  end if
  xi = -tHack2 / tHack1
  yi = aLine1 + (bLine1 * xi)
  tVector = vector(xi, yi, 1.0)
  tList = [xi, yi]
  if tDisplay = 1 then
    put xi && yi && aLine1 && bLine1 && tVector && tList
  end if
  return tList
end
