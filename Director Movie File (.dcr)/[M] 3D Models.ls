-- [Script] [M] 3D Models (Script #6145)
-- Script Type: Movie

on CloneModel me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return []
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tDataList.ilk <> #propList then
    return []
  end if
  tSourceMember = VOID
  if tDataList[#sourceMember].ilk = #string then
    tSourceMember = member(tDataList.sourceMember)
  end if
  if tSourceMember = VOID then
    return []
  end if
  if tSourceMember = tmember then
    return []
  end if
  tTargetList = []
  if tDataList[#model].ilk = #void then
    tDataList[#model] = "*.*"
  end if
  if tDataList[#model].ilk = #list then
    tTargetList = tDataList.model
  else
    if tDataList[#model].ilk = #string then
      if tDataList.model.char[1] = "*" then
        tString = tDataList.model
        if tString <> "*.*" then
          delete tString.char[1]
        end if
        tTargetList = GetObjectList(0, tSourceMember.name, [#type: #model, #string: tString])
      else
        tTargetList.add(tDataList.model)
      end if
    end if
  end if
  if tTargetList.count = 0 then
    return []
  end if
  tNameTag = VOID
  if tDataList[#NameTag].ilk = #string then
    tNameTag = tDataList.NameTag
  end if
  tShaderTag = VOID
  if tDataList[#shaderTag].ilk = #string then
    tShaderTag = tDataList.shaderTag
  end if
  tTextureTag = VOID
  if tDataList[#textureTag].ilk = #string then
    tTextureTag = tDataList.textureTag
  end if
  tModelList = []
  repeat with i in tTargetList
    if i.ilk <> #model then
      i = tSourceMember.model(i)
    end if
    if i = VOID then
      next repeat
    end if
    tOldShaderList = []
    repeat with ii in i.shaderList
      tOldShaderList.add(ii)
    end repeat
    i.shaderList = tmember.shader("DefaultShader")
    if tmember.modelResource(i.resource.name) <> VOID then
      tmodel = tmember.newModel(tNameTag & i.name, tmember.modelResource(i.resource.name))
      tmodel.transform = i.transform.duplicate()
    else
      tmodel = tmember.cloneModelFromCastmember(tNameTag & i.name, i.name, tSourceMember)
    end if
    tShaderList = []
    repeat with iii in tOldShaderList
      tShader = tmember.shader(tShaderTag & iii.name)
      if tShader = VOID then
        tShader = DuplicateShader(0, tmember, [#shader: iii.name, #sourceMember: tSourceMember.name, #shaderTag: tShaderTag, #textureTag: tTextureTag])
      end if
      tShaderList.add(tShader)
    end repeat
    tmodel.shaderList = tShaderList.duplicate()
    tModelList.add(tmodel)
    i.shaderList = tOldShaderList.duplicate()
  end repeat
  tHide = 0
  if tDataList[#hide].ilk = #integer then
    tHide = tDataList.hide
  end if
  if tHide = 1 then
    repeat with i in tModelList
      i.parent = VOID
    end repeat
  end if
  tLod = 1
  if tDataList[#lod].ilk = #integer then
    tLod = tDataList.lod
  end if
  if tLod = 0 then
    repeat with i in tModelList
      i.resource.lod.auto = 0
      i.resource.lod.bias = 100
      i.resource.lod.level = 100
    end repeat
  end if
  tDelete = 0
  if tDataList[#delete].ilk = #integer then
    tDelete = tDataList.delete
  end if
  if tDelete = 1 then
    repeat with i in tModelList
      tmember.deleteModel(i.name)
    end repeat
    tModelList = []
  end if
  if tModelList.count = 1 then
    return tModelList[1]
  else
    return tModelList
  end if
end

on SetModel me, tTarget, tDataList
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
  tTargetList = []
  if tDataList[#model].ilk = #void then
    tDataList[#model] = "*.*"
  end if
  if tDataList[#model].ilk = #list then
    tTargetList = tDataList.model
  else
    if tDataList[#model].ilk = #string then
      if tDataList.model.char[1] = "*" then
        tString = tDataList.model
        if tString <> "*.*" then
          delete tString.char[1]
        end if
        tTargetList = GetObjectList(0, tmember.name, [#type: #model, #string: tString])
      else
        tTargetList.add(tDataList.model)
      end if
    end if
  end if
  if tTargetList.count = 0 then
    return []
  end if
  repeat with i in tTargetList
    tmodel = tmember.model(i)
    if tmodel = VOID then
      next repeat
    end if
    if tDataList[#resource].ilk = #string then
      tmodel.resource = tmember.modelResource(tDataList.resource)
    end if
    if tDataList[#shader].ilk = #string then
      tmodel.shader = tmember.shader(tDataList.shader)
    end if
    if tDataList[#visibility].ilk = #symbol then
      tList = [#front, #back, #none, #both, #front_nodepth, #back_nodepth, #both_nodepth]
      if tList.getPos(tDataList.visibility) <> 0 then
        tmodel.visibility = tDataList.visibility
      end if
    end if
    if tDataList[#position].ilk = #vector then
      tmodel.transform.position = tDataList.position
    end if
  end repeat
end
