-- [Script] [M] Publish Game (Script #5847)
-- Script Type: Movie

global gGame

on Publish me
  reset()
  PrePublish()
  dispatchcommand(4104)
end

on PrePublish
  InitGlobals()
  gGame[#CheckOverride] = #here
  load(0, "\Data\PrePublishLoadingArray.txt")
  tImage = image(8, 8, 32)
  member("Screenshot").image = tImage
  member("StatsTemplate").image = tImage
  member("TrophiesTemplate").image = tImage
  member("CarReflectionReference").image = tImage
  member("MotionBlurRTImage").image = tImage
end
