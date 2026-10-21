--@lib util_xskip.lua#Head
-- Utilities pre-match X skip, Chronicle side (chronicle_mode_soccer_vs_menu: Chronicle's VS screen, BattleSettingFlow
-- state 1 -> 5, instead of the flow VS screen): leaving it arms the X guide of the walk-in events (xs_event.lua).
-- Wrapper only.
local util_xs_prev_close = CloseChronicleModeSoccerVsMenu
function CloseChronicleModeSoccerVsMenu(...)
  UTIL_XS.Arm("chronicle vs screen")
  return util_xs_prev_close(...)
end
