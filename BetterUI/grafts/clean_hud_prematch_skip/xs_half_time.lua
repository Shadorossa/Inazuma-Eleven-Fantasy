--@lib clean_hud_xskip.lua#Head
-- Clean HUD pre-match X skip, half-time side (soccer_half_time_menu): a last safety net, disarmed at half time (a match
-- whose kick-off opened no restart button and had no lineup screens), so no second-half event shows the X guide.
-- Wrapper only.
local chd_xs_prev_init = OnInit
function OnInit(...)
  CHD_XS.Disarm("half time")
  return chd_xs_prev_init(...)
end
