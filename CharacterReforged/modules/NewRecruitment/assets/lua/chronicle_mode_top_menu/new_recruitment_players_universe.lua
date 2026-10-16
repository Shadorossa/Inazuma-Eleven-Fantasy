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

-- The gap. With BetterUI the two big rows sit above four square boxes (layer clean_hud_chr_box, its «!» layer
-- clean_hud_chr_box_notice) placed by its locator; with the gacha row gone the boxes would hang one row lower than they
-- need. After the retail / BetterUI setup of each box instance, the instance is moved up by the row pitch of that
-- locator (CMND_GET_LAYER_LOCAL_POS read, CMND_SET_LAYER_LOCAL_POS written back one pitch higher; an instance already
-- moved is left alone). Without BetterUI there are no such layers and nothing moves.
local BOX_LAYERS = {
  [1676790659] = true,                -- clean_hud_chr_box
  [791190873] = true,                 -- clean_hud_chr_box_notice
}
local GET_LOCAL_POS = 2834507455      -- CMND_GET_LAYER_LOCAL_POS (layer, instance) -> x, y, z
local SET_LOCAL_POS = 1389957207      -- CMND_SET_LAYER_LOCAL_POS (layer, x, y, z, instance)
local ROW_PITCH = 108                 -- layout px between the two big rows (Cadena de Crónica -222, Universo -330)
local moved = {}                      -- layer .. ":" .. instance -> the y it was moved to

local function close_gap(layer, instance)
  if not BOX_LAYERS[layer] or type(instance) ~= "number" or not covered() then
    return
  end
  local ok, x, y, z = pcall(funcLuaMenuCommand, GET_LOCAL_POS, layer, instance)
  if not ok or type(x) ~= "number" or type(y) ~= "number" then
    return
  end
  local key = layer .. ":" .. instance
  if moved[key] ~= nil and math.abs(y - moved[key]) < 0.5 then
    return
  end
  local target = y + ROW_PITCH
  if pcall(funcLuaMenuCommand, SET_LOCAL_POS, layer, x, target, type(z) == "number" and z or 0, instance) then
    moved[key] = target
  end
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
