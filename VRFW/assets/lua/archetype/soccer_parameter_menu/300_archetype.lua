-- VRFW › archetypes declared by mods: «Bonificaciones de equipo» (soccer_parameter_menu,
-- layer soccer11_21_formation_team_passive_list_base): the build name and large icon of a team whose archetype is a
-- declared one. Outside a match: the last menu pick (this menu picks its team set at OnInit); in a match: the side
-- of the user (CMND_GET_SOCCER_TEAM_INFO 0). The game's code runs first (it draws build 6), then the declared one.
-- No engine call at load time.

VRFW_Archetype = VRFW_Archetype or {}
local A = VRFW_Archetype
A.CMD_TEAM = A.CMD_TEAM or 3704961242    -- CMND_VRFW_ARCHETYPE_TEAM
A.CMD_MATCH = A.CMD_MATCH or 2854479468  -- CMND_VRFW_ARCHETYPE_MATCH
A.CMD_INFO = A.CMD_INFO or 3552358290    -- CMND_VRFW_ARCHETYPE_INFO

local LIST_BASE = 862546245     -- soccer11_21_formation_team_passive_list_base
local ICON_COMMON_LG = 502529699
local ICON_DMY = 2789893477     -- icon_build_dmy01
local TEXT_BUILD = 2160352228   -- _text_build01

local function current_build()
  local okm, soccer = pcall(funcLuaCommand, 4156639577) -- CMND_IS_SOCCER_MODE
  if okm and soccer == true then
    local ok, has, side = pcall(funcLuaCommand, 3112466283, 0) -- CMND_GET_SOCCER_TEAM_INFO(0): the user's side
    if not (ok and has == true and (side == 0 or side == 1)) then return nil end
    local okb, b = pcall(funcLuaCommand, A.CMD_MATCH, side)
    if okb and type(b) == "number" and b >= 7 then return b end
    return nil
  end
  local ok, b = pcall(funcLuaCommand, A.CMD_TEAM)
  if ok and type(b) == "number" and b >= 7 then return b end
  return nil
end

A.parameter = A.parameter or {}
local W = A.parameter

if type(OnSetupLayer) == "function" and OnSetupLayer ~= W.OnSetupLayer then
  local orig = OnSetupLayer
  W.OnSetupLayer = function(a1, a2, ...)
    local r = orig(a1, a2, ...)
    if a1 == LIST_BASE then
      local b = current_build()
      if b then
        local ok, has, name, _, _, large = pcall(funcLuaCommand, A.CMD_INFO, b)
        if ok and has == true then
          if type(large) == "number" and large ~= 0 then
            pcall(funcLuaMenuCommand, 558735651, a1, ICON_COMMON_LG, large, ICON_DMY, 0, a2)
          end
          local okt, s = pcall(funcLuaCommand, 4074371074, name) -- CMND_TEXT_GET
          if okt and type(s) == "string" then
            pcall(funcLuaMenuCommand, 1083631230, a1, TEXT_BUILD, s, a2)
            pcall(funcLuaMenuCommand, 1172899594, a1, a2, TEXT_BUILD) -- CMND_UPDATE_TEXT_PLATE
          end
        end
      end
    end
    return r
  end
  OnSetupLayer = W.OnSetupLayer
end
