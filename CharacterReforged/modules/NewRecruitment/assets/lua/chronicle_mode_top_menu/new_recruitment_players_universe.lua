-- New Recruitment: the Chronicle gacha «Universo del jugador» (players_universe_menu) is covered (owner request
-- 2026-10-16): with this mod players come from other sources, so its pull of players is closed. Its only way in is the
-- big list row of the Chronicle top menu (chronicle_mode_top_menu: menuObjectName 2357301264, the last row of the
-- middle list layer 4042532538); the map point of the Chronicle hub is closed in content\triggers\w90i001.lua. While
-- NewRecruitment.Applies() holds (not in a mode's reserved slot):
--   * GetNumUsedButtons(middle list) is one less: the retail setup of the layer hides the row that is left over;
--   * OnDecideFocus / OnEnter on that row do nothing (a mouse click, a key, any focus path);
--   * IsReservedPlayersUniverseEvent answers false: nothing opens the gacha by itself.
-- Wrappers over the retail globals; nothing runs at load but their definition; every check goes through pcall.
local MIDDLE_LIST = 4042532538            -- mainmenu90_11_chronicle_top_list_item_middle
local UNIVERSE_MENU = 2357301264          -- players_universe_menu

local function covered()
  return type(NewRecruitment) == "table" and type(NewRecruitment.Applies) == "function"
    and (select(2, pcall(NewRecruitment.Applies))) == true
end

local function is_universe_row(layer, index)
  local ok, info = pcall(GetLitItemInfo, layer, index)
  return ok and type(info) == "table" and info.menuObjectName == UNIVERSE_MENU
end

local retail_count = rawget(_ENV, "GetNumUsedButtons")
if type(retail_count) == "function" then
  function GetNumUsedButtons(layer, ...)
    local count = retail_count(layer, ...)
    if layer == MIDDLE_LIST and type(count) == "number" and count > 1 and covered() then
      -- the universe row is the last of the middle list (retail order 1, 2)
      if is_universe_row(layer, count - 1) then
        return count - 1
      end
    end
    return count
  end
end

local retail_decide = rawget(_ENV, "OnDecideFocus")
if type(retail_decide) == "function" then
  function OnDecideFocus(layer, index, ...)
    if (layer == MIDDLE_LIST or layer == 530619243) and covered() and is_universe_row(layer, index) then
      return
    end
    return retail_decide(layer, index, ...)
  end
end

local retail_enter = rawget(_ENV, "OnEnter")
if type(retail_enter) == "function" then
  function OnEnter(layer, index, ...)
    if layer == MIDDLE_LIST and covered() and is_universe_row(layer, index) then
      return
    end
    return retail_enter(layer, index, ...)
  end
end

local retail_reserved = rawget(_ENV, "IsReservedPlayersUniverseEvent")
if type(retail_reserved) == "function" then
  function IsReservedPlayersUniverseEvent(...)
    if covered() then
      return false
    end
    return retail_reserved(...)
  end
end

-- The gap. The gacha row was the second big row; everything under it hangs one row lower than it needs.
--   * With BetterUI the four square boxes (layer clean_hud_chr_box) sit under the big rows: each box instance moves up
--     one row pitch after its setup. Its «!» notice (layer clean_hud_chr_box_notice) is attached to its box, so it follows
--     by itself and is NOT moved here (moving it too put the notices one pitch above their boxes).
--   * Without BetterUI the retail small rows (layer mainmenu90_12_list_item_small, their «!» is part of the row) move up
--     the same way.
-- The position is written as the instance's first-seen position plus the pitch (never read again after a move), so the
-- setup and the open of a layer, or a reopen of the menu, move an instance exactly once. Nothing moves while the
-- gacha is not covered.
local BOX_LAYER = 1676790659              -- clean_hud_chr_box
local SMALL_LIST = 530619243              -- mainmenu90_12_list_item_small
local GET_LOCAL_POS = 2834507455          -- CMND_GET_LAYER_LOCAL_POS (layer, instance) -> x, y, z
local SET_LOCAL_POS = 1389957207          -- CMND_SET_LAYER_LOCAL_POS (layer, x, y, z, instance)
local ROW_PITCH = 108                     -- layout px between the two big rows (Cadena de Crónica -222, Universo -330)
local first_seen = {}                     -- layer .. ":" .. instance -> {x, y, z} before any move

local function moves_with_gap(layer)
  if layer == BOX_LAYER then
    return true
  end
  return layer == SMALL_LIST and rawget(_ENV, "CLEAN_HUD_CHR_BOXES") ~= true
end

local function close_gap(layer, instance)
  if type(instance) ~= "number" or not moves_with_gap(layer) or not covered() then
    return
  end
  local key = layer .. ":" .. instance
  local base = first_seen[key]
  if base == nil then
    local ok, x, y, z = pcall(funcLuaMenuCommand, GET_LOCAL_POS, layer, instance)
    if not ok or type(x) ~= "number" or type(y) ~= "number" then
      return
    end
    base = {x, y, type(z) == "number" and z or 0}
    first_seen[key] = base
  end
  pcall(funcLuaMenuCommand, SET_LOCAL_POS, layer, base[1], base[2] + ROW_PITCH, base[3], instance)
end

for _, name in ipairs({"OnSetupLayer", "OnOpenLayer"}) do
  local retail = rawget(_ENV, name)
  if type(retail) == "function" then
    _ENV[name] = function(layer, instance, ...)
      local results = table.pack(retail(layer, instance, ...))
      close_gap(layer, instance)
      return table.unpack(results, 1, results.n)
    end
  end
end
