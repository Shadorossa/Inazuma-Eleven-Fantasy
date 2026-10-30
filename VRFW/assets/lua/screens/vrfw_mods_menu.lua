-- vrfw_mods_menu: the script of the «Mods» screen (mod mods_menu, VR-Framework). This file is only the stub the menu
-- loads (served as common/script/lua/menu/vrfw_mods_menu.lua.bin by the mods_menu plugin); the screen itself is the
-- per-mod Lua patch mods\mods_menu\lua\vrfw_mods_menu\*.lua, run in this VM right after this chunk.
-- If the patch did not run (ModLoader without Lua patches), the screen closes itself at once.
INCLUDE("LUA_PROG_BASE")
INCLUDE("LUA_SAVEDATA_MANAGEMENT_MENU_INC")

-- fingerprint of this script for the ModLoader's Lua patch runner (lua\_fingerprints.json)
function VRFW_ModsMenuStub()
  return 1
end

function OnInit()
end

function Step()
  funcLuaMenuCommand(1558704558, 4051526990 --[[crc32("vrfw_mods_menu")]], false)
  funcLuaCommand(VRFW_Cmd.CLOSE_MENU_OBJECT, 4051526990)
end
