--@lib clean_hud_xskip.lua#Head
-- Clean HUD pre-match X skip, small-match side (soccer_battle_vs_menu: the VS screen of the 5v5 / small story duels,
-- match type 2): leaving it arms the X guide of the events that follow (xs_event.lua). Wrapper only.
local chd_xs_prev_close = CloseSoccerBattleVsMenu
function CloseSoccerBattleVsMenu(...)
  CHD_XS.Arm("small match vs screen")
  return chd_xs_prev_close(...)
end
