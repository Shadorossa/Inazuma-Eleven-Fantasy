-- VRFW › archetypes declared by mods: the small build icon (plate rows, the player's
-- archetype badge) of a declared archetype's number 7+ (CMND_VRFW_ARCHETYPE_INFO); the game's builds keep theirs.
-- No engine call at load time; wrapped again when the include runs again.

VRFW_Archetype = VRFW_Archetype or {}
local A = VRFW_Archetype
A.CMD_INFO = A.CMD_INFO or 3552358290   -- CMND_VRFW_ARCHETYPE_INFO

local function info_icon(n)
  if type(n) ~= "number" or n < 7 then return nil end
  local ok, has, _, _, icon = pcall(funcLuaCommand, A.CMD_INFO, n)
  if ok and has == true and type(icon) == "number" and icon ~= 0 then return icon end
  return nil
end

if type(GeTeamBuffBuildTypeIconTextureName) == "function" and GeTeamBuffBuildTypeIconTextureName ~= A.small_icon then
  local orig = GeTeamBuffBuildTypeIconTextureName
  A.small_icon = function(a1, ...)
    local icon = info_icon(a1)
    if icon then return icon end
    return orig(a1, ...)
  end
  GeTeamBuffBuildTypeIconTextureName = A.small_icon
end
