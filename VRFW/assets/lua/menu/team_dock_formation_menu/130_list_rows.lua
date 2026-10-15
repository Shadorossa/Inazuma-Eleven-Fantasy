-- list rows (VR-Framework base feature): the rules the mods register for the player popup
-- «PERSONAJE» of this screen (menu "team_dock.player_commands": hide / add / take over rows by retail setting type)
-- are applied by the handlers VRFW_ListRows.AttachPlayerCommands registers on this script's host (000_host.lua);
-- lua\_all\68_list_rows_player_commands.lua. The team COMANDOS window needs no file here (lua\_all\67_list_rows.lua).
-- No engine call at load time.
if VRFW_ListRows ~= nil and VRFW_ListRows.AttachPlayerCommands ~= nil then
  VRFW_ListRows.AttachPlayerCommands()
end
