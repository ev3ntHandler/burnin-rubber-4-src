-- [Script] [M] 3D Shaders (Script #6146)
-- Script Type: Movie

global gGame

on CreateShader me, tTarget, tDataList
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
  tShaderName = "DefaultShader" & tmember.shader.count & "_Material"
  if tDataList[#shader].ilk = #string then
    tShaderName = tDataList.shader
  end if
  tType = #standard
  tShader = tmember.newShader(tShaderName, tType)
  tShader.ambient = rgb(0, 0, 0)
  tShader.diffuse = rgb(255, 255, 255)
  tShader.emissive = rgb(255, 255, 255)
  tShader.specular = rgb(255, 255, 255)
  tShader.shininess = 0.0
  tShader.blend = 100.0
  tShader.transparent = 1
  tShader.textureList[1] = tmember.texture("DefaultTexture")
  if tDataList[#ambient].ilk = #color then
    tShader.ambient = tDataList.ambient
  end if
  if tDataList[#diffuse].ilk = #color then
    tShader.diffuse = tDataList.diffuse
  end if
  if tDataList[#emissive].ilk = #color then
    tShader.emissive = tDataList.emissive
  end if
  if tDataList[#specular].ilk = #color then
    tShader.specular = tDataList.specular
  end if
  if tDataList[#shininess].ilk = #float then
    tShader.shininess = tDataList.shininess
  end if
  if tDataList[#blend].ilk = #float then
    tShader.blend = tDataList.blend
  end if
  if tDataList[#transparent].ilk = #integer then
    tShader.transparent = tDataList.transparent
  end if
  if tDataList[#texture].ilk = #string then
    tTexture = tmember.texture(tDataList.texture)
    if tTexture = VOID then
      tTexture = createTexture(0, tmember.name, [#texture: tDataList.texture, #filtering: #lowFiltered])
    end if
    tShader.textureList[1] = tTexture
  end if
  if tDataList[#texture].ilk = #void then
    tShader.textureList[1] = VOID
  end if
  if tDataList[#renderStyle].ilk = #symbol then
    tShader.renderStyle = tDataList.renderStyle
  end if
  return tShader
end

on SetShader me, tTarget, tDataList
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
  tTargetList = []
  if tDataList[#shader].ilk = #void then
    tDataList[#model] = "*.*"
  end if
  if tDataList[#shader].ilk = #list then
    tTargetList = tDataList.model
  else
    if tDataList[#shader].ilk = #string then
      if tDataList.shader.char[1] = "*" then
        tString = tDataList.shader
        if tString <> "*.*" then
          delete tString.char[1]
        end if
        tTargetList = GetObjectList(0, tmember.name, [#type: #shader, #string: tString])
      else
        tTargetList.add(tDataList.shader)
      end if
    end if
  end if
  if tTargetList.count = 0 then
    return []
  end if
  repeat with j in tTargetList
    tShader = tmember.shader(j)
    if tShader = VOID then
      next repeat
    end if
    if tDataList[#ambient].ilk = #color then
      tShader.ambient = tDataList.ambient
    end if
    if tDataList[#diffuse].ilk = #color then
      tShader.diffuse = tDataList.diffuse
    end if
    if tDataList[#emissive].ilk = #color then
      tShader.emissive = tDataList.emissive
    end if
    if tDataList[#specular].ilk = #color then
      tShader.specular = tDataList.specular
    end if
    if (tDataList[#shininess].ilk = #integer) or (tDataList[#shininess].ilk = #float) then
      tShader.shininess = tDataList.shininess
    end if
    if tDataList[#useDiffuseWithTexture].ilk = #integer then
      tShader.useDiffuseWithTexture = tDataList.useDiffuseWithTexture
    end if
    if (tDataList[#blend].ilk = #float) or (tDataList[#blend].ilk = #integer) then
      tShader.blend = tDataList.blend
    end if
    if tDataList[#transparent].ilk = #integer then
      tShader.transparent = tDataList.transparent
    end if
    if tDataList[#flat].ilk = #integer then
      tShader.flat = tDataList.flat
    end if
    tRenderStyles = [#point, #wire, #fill]
    if tDataList[#renderStyle].ilk = #symbol then
      if tRenderStyles.getPos(tDataList.renderStyle) <> 0 then
        tShader.renderStyle = tDataList.renderStyle
      end if
    end if
    tTextureModes = [#none, #wrapPlanar, #wrapCylindrical, #wrapSpherical, #reflection, #diffuseLight, #specularLight]
    tBlendFunctions = [#multiply, #replace, #add, #blend]
    tBlendSources = [#alpha, #constant]
    repeat with i = 1 to 8
      if tDataList[symbol("Texture" & i)].ilk = #string then
        tTexture = tmember.texture(tDataList[symbol("Texture" & i)])
        tShader.textureList[i] = tTexture
      end if
      if tDataList[symbol("TextureMode" & i)].ilk = #symbol then
        if tTextureModes.getPos(tDataList[symbol("TextureMode" & i)]) <> 0 then
          tShader.textureModeList[i] = tDataList[symbol("TextureMode" & i)]
        end if
      else
        tShader.textureModeList[i] = #none
      end if
      if tDataList[symbol("BlendFunction" & i)].ilk = #symbol then
        if tBlendFunctions.getPos(tDataList[symbol("BlendFunction" & i)]) <> 0 then
          tShader.blendFunctionList[i] = tDataList[symbol("BlendFunction" & i)]
        end if
      end if
      if tDataList[symbol("BlendSource" & i)].ilk = #symbol then
        if tBlendSources.getPos(tDataList[symbol("BlendSource" & i)]) <> 0 then
          tShader.blendSourceList[i] = tDataList[symbol("BlendSource" & i)]
        end if
      end if
      if (tDataList[symbol("blendConstant" & i)].ilk = #float) or (tDataList[symbol("blendConstant" & i)].ilk = #integer) then
        tShader.blendConstantList[i] = tDataList[symbol("blendConstant" & i)]
      end if
      if tDataList[symbol("TextureRepeat" & i)].ilk = #integer then
        tShader.textureRepeatList[i] = tDataList[symbol("TextureRepeat" & i)]
      end if
      if tDataList[symbol("TexturePosition" & i)].ilk = #vector then
        tShader.textureTransformList[i].position = tDataList[symbol("TexturePosition" & i)]
      end if
      if tDataList[symbol("TextureRotation" & i)].ilk = #vector then
        tShader.textureTransformList[i].rotation = tDataList[symbol("TextureRotation" & i)]
      end if
      if tDataList[symbol("TextureScale" & i)].ilk = #vector then
        tShader.textureTransformList[i].scale = tDataList[symbol("TextureScale" & i)]
      end if
    end repeat
  end repeat
end

on deleteShader me, tTarget, tDataList
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
  tTargetList = []
  if tDataList[#shader].ilk = #void then
    tDataList[#shader] = "*.*"
  end if
  if tDataList[#shader].ilk = #list then
    tTargetList = tDataList.shader
  else
    if tDataList[#shader].ilk = #string then
      if tDataList.shader.char[1] = "*" then
        tString = tDataList.shader
        if tString <> "*.*" then
          delete tString.char[1]
        end if
        tTargetList = GetStringList(0, tmember.name, [#type: #shader, #string: tString])
      else
        tTargetList.add(tDataList.shader)
      end if
    end if
  end if
  if tTargetList.count = 0 then
    return VOID
  end if
  repeat with i in tTargetList
    if tmember.shader(i) <> VOID then
      tmember.deleteShader(i)
    end if
  end repeat
  return 1
end

on DuplicateShader me, tTarget, tDataList
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
  tSourceMember = tmember
  if tDataList[#sourceMember].ilk = #string then
    tSourceMember = member(tDataList.sourceMember)
  end if
  tTargetList = []
  if tDataList[#shader].ilk = #void then
    tDataList[#shader] = "*.*"
  end if
  if tDataList[#shader].ilk = #list then
    tTargetList = tDataList.shader
  else
    if tDataList[#shader].ilk = #string then
      if tDataList.shader.char[1] = "*" then
        tString = tDataList.shader
        if tString <> "*.*" then
          delete tString.char[1]
        end if
        tTargetList = GetStringList(0, tSourceMember.name, [#type: #shader, #string: tString])
      else
        tTargetList.add(tDataList.shader)
      end if
    end if
  end if
  if tTargetList.count = 0 then
    return []
  end if
  if tDataList[#Override].ilk = #integer then
    if tDataList.Override = 1 then
      repeat with i in tTargetList
        deleteShader(0, tmember.name, [#shader: i])
      end repeat
    end if
  end if
  tShaderList = []
  tShaderTag = VOID
  if tDataList[#shaderTag].ilk = #string then
    tShaderTag = tDataList.shaderTag
  end if
  tTextureTag = VOID
  if tDataList[#textureTag].ilk = #string then
    tTextureTag = tDataList.textureTag
  end if
  repeat with i in tTargetList
    tOrigShader = tSourceMember.shader(i)
    if tmember.shader(tShaderTag & tOrigShader.name) <> VOID then
      tShaderList.add(tmember.shader(tShaderTag & tOrigShader.name))
      next repeat
    else
      tDupShader = tmember.newShader(tShaderTag & tOrigShader.name, tOrigShader.type)
    end if
    tDupShader.ambient = tOrigShader.ambient
    tDupShader.diffuse = tOrigShader.diffuse
    tDupShader.emissive = tOrigShader.emissive
    tDupShader.specular = tOrigShader.specular
    tDupShader.shininess = tOrigShader.shininess
    tDupShader.blend = tOrigShader.blend
    tDupShader.transparent = tOrigShader.transparent
    tDupShader.flat = tOrigShader.flat
    tDupShader.renderStyle = tOrigShader.renderStyle
    tDupShader.useDiffuseWithTexture = tOrigShader.useDiffuseWithTexture
    repeat with ii = 1 to 8
      if tOrigShader.textureList[ii] = VOID then
        next repeat
      end if
      tTexture = tOrigShader.textureList[ii]
      tNewTexture = tmember.texture(tTextureTag & tTexture.name)
      if tNewTexture = VOID then
        tNewTexture = DuplicateTexture(0, tmember.name, [#texture: tTexture.name, #sourceMember: tSourceMember.name, #NameTag: tTextureTag])
      end if
      tDupShader.textureList[ii] = tNewTexture
      tDupShader.textureModeList[ii] = tOrigShader.textureModeList[ii]
      tDupShader.wrapTransformList[ii] = tOrigShader.wrapTransformList[ii]
      tDupShader.textureTransformList[ii] = tOrigShader.textureTransformList[ii]
      tDupShader.blendFunctionList[ii] = tOrigShader.blendFunctionList[ii]
      tDupShader.blendSourceList[ii] = tOrigShader.blendSourceList[ii]
      tDupShader.blendConstantList[ii] = tOrigShader.blendConstantList[ii]
      tDupShader.textureRepeatList[ii] = tOrigShader.textureRepeatList[ii]
    end repeat
    tShaderList.add(tDupShader)
  end repeat
  if tShaderList.count = 1 then
    return tShaderList[1]
  else
    return tShaderList
  end if
end

on BlendShader me, tTarget, tDataList
  getRendererServices().multiTexturing = 0
  if tTarget = VOID then
    exit
  end if
  tmember = member(tTarget)
  if tmember = VOID then
    exit
  end if
  if tmember.type <> #shockwave3d then
    exit
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  tShaderName = VOID
  if getaProp(tDataList, #shader).ilk = #string then
    tShaderName = tDataList[#shader]
  end if
  if tShaderName = VOID then
    exit
  end if
  tShader = tmember.shader(tShaderName)
  if tShader = VOID then
    exit
  end if
  tBlendMode = #add
  if getaProp(tDataList, #blendMode).ilk = #symbol then
    tBlendMode = tDataList[#blendMode]
  end if
  tShader.transparent = 1
  tShader.blend = 0.0
  tShader.blendFunctionList[1] = #blend
  tShader.blendConstantList[1] = 0.0
  if _movie.active3dRenderer = #openGL then
    tShader.textureList[2] = tShader.textureList[1]
    tShader.blendFunctionList[2] = tBlendMode
    tShader.blendConstantList[2] = 0.0
  else
    tShader.textureList[2] = tShader.textureList[1]
    tShader.textureList[3] = tShader.textureList[1]
    tShader.blendFunctionList[2] = #blend
    tShader.blendConstantList[2] = 0.0
    tShader.blendFunctionList[3] = tBlendMode
    tShader.blendConstantList[3] = 0.0
  end if
  return tShader
end

on CreateProxyShader me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  if tDataList.ilk = #string then
    tDataList = value(tDataList)
  end if
  if tmember.type <> #shockwave3d then
    return 0
  end if
  tShader = tmember.newShader("Proxy_Material", #standard)
  tShader.ambient = rgb(250, 0, 247)
  tShader.diffuse = rgb(250, 0, 247)
  tShader.emissive = rgb(54, 102, 191)
  tShader.specular = rgb(0, 0, 0)
  tShader.shininess = 0.0
  tShader.blend = 60.0
  tShader.textureList = VOID
  gGame[#ProxyShader] = tShader
end
