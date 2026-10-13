--@lib clean_hud_xskip.lua#Head
-- Clean HUD pre-match X skip, Chronicle side (chronicle_mode_soccer_vs_menu: Chronicle's VS screen, BattleSettingFlow
-- state 1 -> 5, instead of the flow VS screen): leaving it arms the X guide of the walk-in events (xs_event.lua).
-- Wrapper only.
local chd_xs_prev_close = CloseChronicleModeSoccerVsMenu
function CloseChronicleModeSoccerVsMenu(...)
  CHD_XS.Arm("chronicle vs screen")
  return chd_xs_prev_close(...)
end
