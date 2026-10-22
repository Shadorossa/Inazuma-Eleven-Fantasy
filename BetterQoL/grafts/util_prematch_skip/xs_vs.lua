--@lib util_xskip.lua#Head
-- Utilities pre-match X skip, VS side (soccer_battle_setting_flow_vs_menu, the VS screen of BattleSettingFlow state 4:
-- story 11v11, free matches, Victory Road / clubs, Battle Bay): leaving the VS screen arms the X guide of the
-- walk-in events that follow (xs_event.lua). Online / observer: not armed. Wrapper only.
local util_xs_prev_go = GoToFormationScreen
function GoToFormationScreen(...)
  UTIL_XS.Arm("vs screen")
  return util_xs_prev_go(...)
end
