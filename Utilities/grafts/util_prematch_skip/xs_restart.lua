--@lib util_xskip.lua#Head
-- Utilities pre-match X skip, kick-off side (soccer_restart_guide_menu: the «(A) Saque de centro» / restart button,
-- set up by the engine through these two callbacks): the match is under way, nothing pre-match is left: disarmed
-- (matches without lineup screens). Wrappers only.
local util_xs_prev_kickoff = InitializeKickoffButton_Callback
function InitializeKickoffButton_Callback(...)
  UTIL_XS.Disarm("kick-off")
  return util_xs_prev_kickoff(...)
end
local util_xs_prev_restart = InitializeRestartButton_Callback
function InitializeRestartButton_Callback(...)
  UTIL_XS.Disarm("restart")
  return util_xs_prev_restart(...)
end
-- The button itself (called by the engine when it shows, 0x1105240): the X skip's black cover, if still up (a match
-- without lineup screens), fades in here at the latest.
local util_xs_prev_decide = DecideRestartButton
function DecideRestartButton(...)
  UTIL_XS.Uncover(UTIL_XS.COVER_IN_S, "kick-off button")
  UTIL_XS.UnblackLayer0("kick-off button")
  return util_xs_prev_decide(...)
end
-- A cover the framework still held when it should have come off (its release went unanswered: the script VM was busy):
-- asked again every frame of this menu once the pre-match is over (GO cleared), then faded in.
local util_xs_prev_step = Step
function Step(...)
  if UTIL_XS.Get(UTIL_XS.COVER) == 1 and UTIL_XS.Get(UTIL_XS.GO) ~= 1 then
    UTIL_XS.Uncover(UTIL_XS.COVER_IN_S, "kick-off (retry)")
  end
  if UTIL_XS.Get(UTIL_XS.GO) ~= 1 then
    UTIL_XS.UnblackLayer0("kick-off guide")
  end
  return util_xs_prev_step(...)
end
