-- Player Training › the bean rows of the formation's team «COMANDOS» window (Alt / «Equipar todo»;
-- docs/framework/list-rows.md). The training replaces the retail training beans (content\game\player_training.toml
-- «the training beans»), so «Equipar judías de entrenamiento», «Quitar judías de entrenamiento» and the «Autoequipar
-- judías» checkbox are hidden through the framework's list rows point (rules by retail row id, applied with every
-- other mod's rules of that window; no menu function redefined). Every menu VM (the window opens from every screen
-- that includes soccer_formation_menu_inc); registration only, no engine call at chunk load. The team dock's own list
-- (soccer_team_dock_menu) hides its bean rows in graft player_training_dock.
-- 1.0.6: this mod is lua_early, so this `_all` runs BEFORE the framework's `_all` (VRFW_ListRows still nil here; until
-- 1.0.5 the rules were never registered and the bean rows stayed). The rules go to the framework's queue
-- VRFW_LIST_ROWS_Q (vr_framework 2.4.47), drained when VRFW_ListRows is defined; registered at once if it already is.
local function hide_bean_rows(Rows)
  Rows.Hide(Rows.TEAM_COMMANDS, { id = "player_training.beans_equip", row = Rows.TEAM_COMMAND.EQUIP_BEANS })
  Rows.Hide(Rows.TEAM_COMMANDS, { id = "player_training.beans_remove", row = Rows.TEAM_COMMAND.REMOVE_BEANS })
  Rows.Hide(Rows.TEAM_COMMANDS, { id = "player_training.beans_auto_equip", row = Rows.TEAM_COMMAND.AUTO_EQUIP_BEANS })
end

if VRFW_ListRows ~= nil and VRFW_ListRows.Hide ~= nil then
  hide_bean_rows(VRFW_ListRows)
else
  VRFW_LIST_ROWS_Q = VRFW_LIST_ROWS_Q or {}
  table.insert(VRFW_LIST_ROWS_Q, hide_bean_rows)
end
