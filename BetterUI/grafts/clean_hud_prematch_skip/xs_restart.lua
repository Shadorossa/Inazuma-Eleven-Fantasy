--@lib clean_hud_xskip.lua#Head
-- Clean HUD pre-match X skip, kick-off side (soccer_restart_guide_menu: the «(A) Saque de centro» / restart button,
-- set up by the engine through these two callbacks): the match is under way, nothing pre-match is left: disarmed
-- (matches without lineup screens). Wrappers only.
local chd_xs_prev_kickoff = InitializeKickoffButton_Callback
function InitializeKickoffButton_Callback(...)
  CHD_XS.Disarm("kick-off")
  return chd_xs_prev_kickoff(...)
end
local chd_xs_prev_restart = InitializeRestartButton_Callback
function InitializeRestartButton_Callback(...)
  CHD_XS.Disarm("restart")
  return chd_xs_prev_restart(...)
end
-- The button itself (called by the engine when it shows, 0x1105240): the X skip's black cover, if still up (a match
-- without lineup screens), fades in here at the latest.
local chd_xs_prev_decide = DecideRestartButton
function DecideRestartButton(...)
  CHD_XS.Uncover(CHD_XS.COVER_IN_S, "kick-off button")
  return chd_xs_prev_decide(...)
end
-- A cover the framework still held when it should have come off (its release went unanswered: the script VM was busy):
-- asked again every frame of this menu once the pre-match is over (GO cleared), then faded in.
local chd_xs_prev_step = Step
function Step(...)
  if CHD_XS.Get(CHD_XS.COVER) == 1 and CHD_XS.Get(CHD_XS.GO) ~= 1 then
    CHD_XS.Uncover(CHD_XS.COVER_IN_S, "kick-off (retry)")
  end
  return chd_xs_prev_step(...)
end
