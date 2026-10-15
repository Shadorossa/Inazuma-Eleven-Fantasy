-- VRFW › archetypes declared by mods: the menus' name / large icon / explanation of a
-- build number. A declared archetype has a number 7+ (CMND_VRFW_ARCHETYPE_INFO answers its texts and icons); the
-- game's builds 0-6 keep the game's answers. The team's build the menus ask stays 0-6 (6 when a declared one won: the
-- retail tables are indexed by it); the patches that draw a team's build ask CMND_VRFW_ARCHETYPE_TEAM / _MATCH.
-- No engine call at load time; wrapped again when the include runs again (its chunk redefines the functions).

VRFW_Archetype = VRFW_Archetype or {}
local A = VRFW_Archetype
A.CMD_TEAM = 3704961242   -- CMND_VRFW_ARCHETYPE_TEAM
A.CMD_MATCH = 2854479468  -- CMND_VRFW_ARCHETYPE_MATCH
A.CMD_INFO = 3552358290   -- CMND_VRFW_ARCHETYPE_INFO
A.FIRST = 7

-- { name, desc, icon, large, gauge } of a declared archetype's number, nil for the game's builds / no answer
function A.Info(n)
  if type(n) ~= "number" or n < A.FIRST then return nil end
  local ok, has, name, desc, icon, large, gauge = pcall(funcLuaCommand, A.CMD_INFO, n)
  if ok and has == true then return { name = name, desc = desc, icon = icon, large = large, gauge = gauge } end
  return nil
end

-- the declared archetype a team set (dock, party) got at its last pick, nil when it is one of the game's builds
function A.Team(dock, party)
  local ok, b = pcall(funcLuaCommand, A.CMD_TEAM, dock or 0, party or 0)
  if ok and type(b) == "number" and b >= A.FIRST then return b end
  return nil
end

-- the declared archetype of a match side (0 / 1) and its rank, nil when none
function A.Match(side)
  if side ~= 0 and side ~= 1 then return nil end
  local ok, b, rank = pcall(funcLuaCommand, A.CMD_MATCH, side)
  if ok and type(b) == "number" and b >= A.FIRST then return b, rank or 0 end
  return nil
end

if MENU_DEF ~= nil then
  A.menu_def = A.menu_def or {}
  local W = A.menu_def
  local function wrap(name, field)
    local cur = MENU_DEF[name]
    if type(cur) ~= "function" or cur == W[name] then return end
    local orig = cur
    W[name] = function(a1, ...)
      local x = A.Info(a1)
      if x and x[field] ~= nil and x[field] ~= 0 then return x[field] end
      return orig(a1, ...)
    end
    MENU_DEF[name] = W[name]
  end
  wrap("GetBuildTypeLargeTextureIdFromTeamBuildType", "large")
  wrap("GetBuildTypeNameTextIdFromTeamBuildType", "name")
  wrap("GetBuildTypeExplanationTextIdFromTeamBuildType", "desc")
end
