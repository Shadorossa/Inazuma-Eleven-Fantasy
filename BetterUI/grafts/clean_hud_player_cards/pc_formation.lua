-- Clean HUD compact player cards (graft clean_hud_player_cards): the end of include/menu/soccer_formation_menu_inc, where
-- its 7 formation card functions exist. CLEAN_HUD_PC_WrapFormation is defined by the soccer_common part (INCLUDEd at the
-- top of this file); it wraps them so the level, element and position are hidden again after their post-processing.
if type(CLEAN_HUD_PC_WrapFormation) == "function" then
  CLEAN_HUD_PC_WrapFormation()
end
