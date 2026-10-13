-- EVT utilities_formations (mod Utilities, feature formations; research/grafts/utilities_formations/graft.toml).
-- The picker's list (main-chunk local t6 of soccer_formation_menu_inc, also held by l2) is found among the table
-- upvalues of its list functions as the table whose every entry is a formation the game offers (CMND_UTIL_FORMATION
-- 1, i), then the unlocked ones (CMND_UTIL_FORMATION 0, i) are appended in place. Engine calls only when the picker
-- runs (wrappers), never while the chunk loads. No plugin / no EVT_DEBUG: the game's list.
@UPV@
local UTIL_FM_CMD = @crc:CMND_UTIL_FORMATION@
local UTIL_FM_DONE = false

local function UTIL_FM_Get(which, i)
  local ok, v = pcall(funcLuaCommand, UTIL_FM_CMD, which, i)
  if ok and type(v) == "number" then
    return v
  end
  return 0
end

local function UTIL_FM_Fill()
  if UTIL_FM_DONE then
    return
  end
  UTIL_FM_DONE = true
  local ng, nx = UTIL_FM_Get(1, 0), UTIL_FM_Get(0, 0)
  if ng <= 0 or nx <= 0 then
    return
  end
  local game = {}
  for i = 1, ng do
    game[UTIL_FM_Get(1, i)] = true
  end
  local list = EVT_UpvalueFind({"OnInitFormationCommon", "UpdateListItem", "OnMoveListItem"}, function(t)
    if #t == 0 then
      return false
    end
    for i = 1, #t do
      if not game[t[i]] then
        return false
      end
    end
    return true
  end)
  if list == nil then
    return
  end
  local have = {}
  for i = 1, #list do
    have[list[i]] = true
  end
  for i = 1, nx do
    local id = UTIL_FM_Get(0, i)
    if id ~= 0 and not have[id] then
      list[#list + 1] = id
      have[id] = true
    end
  end
end

for _, name in ipairs({"OnInitFormationCommon", "UpdateListItem", "OnMoveListItem"}) do
  local orig = rawget(_ENV, name)
  if type(orig) == "function" then
    _ENV[name] = function(...)
      UTIL_FM_Fill()
      return orig(...)
    end
  end
end
