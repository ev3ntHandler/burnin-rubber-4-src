-- [Script] [M] 3D Particles (Script #6148)
-- Script Type: Movie

global gData, gGame

on CreateParticleSystem me, tTarget, tDataList
  tmember = member(tTarget)
  if tmember = VOID then
    return 0
  end if
  tDataList = value(tDataList)
  if tDataList.ilk <> #propList then
    return 0
  end if
  tType = #default
  if tDataList[#type].ilk = #symbol then
    tType = tDataList.type
  end if
  if voidp(gData.data.Particles[tType]) = 0 then
    tPartDataList = gData.data.Particles[tType]
  else
    return 0
  end if
  gGame.fx.Particles.amount = gGame.fx.Particles.amount + 1
  tName = tType & gGame.fx.Particles.amount & "_Particle"
  tResource = tmember.newModelResource(tName, #particle)
  tResource.emitter.numParticles = 20
  tResource.lifeTime = 500.0
  tResource.emitter.minSpeed = 0.0
  tResource.emitter.maxSpeed = 0.0
  tResource.sizeRange.start = 1.0
  tResource.sizeRange.end = 0.0
  tResource.blendRange.start = 100.0
  tResource.blendRange.end = 0.0
  tResource.colorRange.start = color(255, 255, 255)
  tResource.colorRange.end = color(255, 255, 255)
  tResource.emitter.distribution = #linear
  tResource.emitter.mode = #stream
  tResource.tweenMode = #age
  tResource.emitter.loop = 1
  tResource.emitter.angle = 0.0
  tResource.drag = 0.0
  tResource.emitter.direction = vector(0.0, 0.0, 1.0)
  tResource.gravity = vector(0.0, 0.0, 0.0)
  tResource.wind = vector(0.0, 0.0, 0.0)
  tResource.emitter.region = [vector(0.0, 0.0, 0.0)]
  tResource.texture = VOID
  tCount = tPartDataList.count
  repeat with i = 1 to tCount
    tProp = tPartDataList.getPropAt(i)
    case tProp of
      #amount:
        tResource.emitter.numParticles = tPartDataList[tProp]
      #lifeTime:
        tResource.lifeTime = tPartDataList[tProp]
      #minSpeed:
        tResource.emitter.minSpeed = tPartDataList[tProp]
      #maxSpeed:
        tResource.emitter.maxSpeed = tPartDataList[tProp]
      #SizeStart:
        tResource.sizeRange.start = tPartDataList[tProp]
      #SizeEnd:
        tResource.sizeRange.end = tPartDataList[tProp]
      #blendStart:
        tResource.blendRange.start = tPartDataList[tProp]
      #blendEnd:
        tResource.blendRange.end = tPartDataList[tProp]
      #colorStart:
        tResource.colorRange.start = tPartDataList[tProp]
      #colorEnd:
        tResource.colorRange.end = tPartDataList[tProp]
      #distribution:
        tResource.emitter.distribution = tPartDataList[tProp]
      #mode:
        tResource.emitter.mode = tPartDataList[tProp]
      #tweenMode:
        tResource.tweenMode = tPartDataList[tProp]
      #loop:
        tResource.emitter.loop = tPartDataList[tProp]
      #angle:
        tResource.emitter.angle = tPartDataList[tProp]
      #drag:
        tResource.drag = tPartDataList[tProp]
      #direction:
        tResource.emitter.direction = tPartDataList[tProp]
      #gravity:
        tResource.gravity = tPartDataList[tProp]
      #wind:
        tResource.wind = tPartDataList[tProp]
      #texture:
        if tmember.texture(tPartDataList.texture) = VOID then
          tResource.texture = createTexture(0, tmember.name, [#texture: tPartDataList.texture, #filtering: #lowFiltered, #renderFormat: #rgba8888])
        else
          tResource.texture = tmember.texture(tPartDataList.texture)
        end if
      #region:
        tResource.emitter.region = tPartDataList[tProp]
      #pause:
        tResource.emitter.pause = tPartDataList[tProp]
    end case
  end repeat
  tmodel = tmember.newModel(tName, tResource)
  gGame.fx.Particles.list.add([tmodel, _system.milliSeconds])
  return tmodel
end
