-- EVT ui_clean graft: common part (research/scripts/ui_clean_build.py, docs/game/ui-redesign.md section 11).
-- Appended as one child function to the retail bytecode of a menu and run at the end of its main chunk.
-- Build-time placeholders: limpio (string), the owning mod's ui_flags.toml flags, merged (Lua table body), player_cards (menu tag for the log).
local EVT_UI_MARK = "EVT_UI_CLEAN_GRAFT"

-- Kill switch. EVT_UI_PRESET = "off" makes every ui_clean wrapper pass everything through unchanged.
-- Each feature can also be switched off on its own in EVT_UI_FLAGS (set by the build, see --preset / --no-*).
if EVT_UI_PRESET == nil then
  EVT_UI_PRESET = "limpio"
end
EVT_UI_FLAGS = EVT_UI_FLAGS or {}
for k, v in pairs({ bank_sort_guide = true, buff_icons = true, buff_panel = false, compact_cards = true, corner_buttons = true, duel_telop = true, enemy_meters = true, esc_guide = true, exec_offset = true, header_short = true, nickname_pill = true, team_param_guide = true, zone_exec = false, zone_hud = true }) do
  if EVT_UI_FLAGS[k] == nil then
    EVT_UI_FLAGS[k] = v
  end
end

@UI_WRAP@

EVT_UI_FLAGS.compact_cards = true
-- EVT ui_clean, Clean HUD «compact player cards» (flag compact_cards; graft research/grafts/clean_hud_player_cards,
-- docs/game/characters/position-cards.md §4 / §8, docs/game/ui/ui-redesign.md §3.6). Run by soccer_common (every card
-- drawer INCLUDEs it), so it acts in every menu VM that draws a team00_01 player card.
--
-- The data (Clean HUD files\data + menus\player_cards.toml) points the formation screens' cards at the formation
-- layout copy team00_01_evt_fc (card 0.78 wide, face centred; the element icon at the bottom LEFT and the position badge
-- at the bottom RIGHT, where the name line was: layout data). On every card drawn with that layout this block hides the
-- player name (_text_chr01) and the level («Nv.» label, anchor meshes, number prims) after the native card draw, and
-- turns a later "visible = true" for them into false until a card of the retail layout is drawn on that slot. Element
-- and position stay visible (1.14.2; 1.14.0 hid them too). The card colour is the
-- game's; Inazuma Fantasy's position_cards graft colours it on top (it wraps funcLuaMenuCommand too: the wrappers
-- chain) and uses the exports below.
--
-- Exports (defined in every VM, whatever the flag; another mod's graft calls them at run time, never at load):
--   CLEAN_HUD_PC_IsCardLayer(layer)            a team00_01 card layer (retail names + EVT_FC_EXTRA[layer] = true, the
--                                              hook a graft uses for its own card layers)
--   CLEAN_HUD_PC_IsCompact(call, layer, idx)   the card uses the formation layout (call = a funcLuaMenuCommand)
--   CLEAN_HUD_PC_HideName(call, layer, idx)    hide the name line (and block its re-show)
--   CLEAN_HUD_PC_KeepName(layer, idx)          stop blocking the name line of that card (a menu's own label there)
--   CLEAN_HUD_PC_WrapFormation()               called by the soccer_formation_menu_inc part of the graft
-- No engine call at load: funcLuaMenuCommand / funcLuaCommand do not exist while INCLUDEs run.
local PC_CMD_CARD_HDL = 3837561292      -- chara card by chara status handle (native 0xCC2590)
local PC_CMD_CARD_PARAM = 2339877830    -- chara card by chara param id (native 0xCC2080)
local PC_CMD_CARD_TABLE = 2329292196    -- chara card from a table {layerName, layerIdx, ...} (0xCC0BF0)
local PC_CMD_LEADER_SOCCER = 1000031904 -- leader card by soccer chara handle
local PC_CMD_LEADER_TEAM = 3550249130   -- leader card of the team
local PC_CMD_PRIM_VISIBLE = 1233047821  -- (layer, idx, prim, visible)
local PC_CMD_MESH_VISIBLE = 3405944500  -- (layer, mesh, visible, idx)
local PC_CMD_NODE_VISIBLE = 2158717427  -- (layer, node, visible, idx)
local PC_CMD_TEXT_VISIBLE = 1505208242  -- CMND_SET_MENU_TEXT_VISIBLE (layer, text, visible, idx)
local PC_CMD_PLAY_ANIME = 3781155141    -- CMND_PLAY_ANIME_TYPE (layer, idx, set, 0, type)
local PC_CMD_ANIME_RESET = 1586300804   -- (layer, idx, set, 1, 0)
local PC_CMD_MESH_POSE = 2373227714     -- CMND_GET_MESH_POSE (layer, idx, node) -> ok, x, y, z, ...
local PC_CMD_LAYER_NUM = 1175615627     -- CMND_GET_CREATE_LAYER_NUM (layer) -> instance count
local PC_TEXT_NAME = 170976702
local PC_NODE_MARK = 1726289776          -- y +1000 on the formation layout (+850 on Inazuma Fantasy's grid copy)
local PC_NODE_MARK_PARENT = 3279539624
local PC_LAYER_SOCCER = 1973487846
-- layers created from team00_01 card objbins (all menus)
local PC_CARD_LAYERS = {
  [1973487846] = true, [1658289671] = true,
  [3241819447] = true, [1791816279] = true,
  [1774956026] = true, [3003299608] = true, [3825623416] = true,
  [2344757061] = true, [3940198160] = true,
  [3578260017] = true, [1690405657] = true,
  [2276833727] = true
}
-- the formation layers of a formation screen (the menu-count fallback of the layout test)
local PC_FORMATION_LAYERS = {
  [1973487846] = true, [1658289671] = true,
  [3241819447] = true
}
-- level: «Nv.» label meshes, the number anchor meshes and the level number prims (normal, q, gray, cup = cap, basara)
local PC_LV_MESHES = {1343488901, 1198450632, 1451641049, 1107078292}
local PC_LV_PRIMS = {
  3653219854, 3469038147, 3883528262, 97120277, 3238733729,
  1687159846, 1202218120, 3594422447, 3957043376, 1031695061
}
local PC_HIDDEN_MESH = {}
for _, v in ipairs(PC_LV_MESHES) do
  PC_HIDDEN_MESH[v] = true
end
local PC_LV_PRIM_SET = {}
for _, v in ipairs(PC_LV_PRIMS) do
  PC_LV_PRIM_SET[v] = true
end
-- functions of include/menu/soccer_formation_menu_inc that draw the formation member / leader cards
local PC_FORMATION_FUNCS = {
  "UpdateMemberCharaIconInfo", "UpdateMemberCharaIconInfoByChrParamId", "UpdateMemberCharaIconInfoByChrStHdl",
  "UpdateLeaderChara", "UpdateLeaderCharaBySoccerCharaHdl", "UpdateLeaderCharaByCharaParamId",
  "UpdateLeaderCharaByCharaStHdl"
}

-- one state per menu VM (soccer_common can be INCLUDEd more than once)
if CLEAN_HUD_PC == nil then
  CLEAN_HUD_PC = {
    layout = {},     -- layer -> true / false: the card layer uses the formation layout (cached)
    name = {},       -- "layer:idx" -> true while the name line is hidden
    hide = {},       -- "layer:idx" -> true while the level is hidden
    wrapped = {},    -- formation functions already wrapped
    form = 0,        -- depth inside the formation card functions
    formKeys = {}    -- cards drawn by the outermost formation function now running
  }
end
local PC = CLEAN_HUD_PC

local function PcKey(layer, idx)
  return tostring(layer) .. ":" .. tostring(idx or 0)
end

function CLEAN_HUD_PC_IsCardLayer(layer)
  if PC_CARD_LAYERS[layer] then
    return true
  end
  local x = EVT_FC_EXTRA
  return type(x) == "table" and x[layer] == true
end

local function PoseY(call, layer, idx, node)
  local p = Pack(pcall(call, PC_CMD_MESH_POSE, layer, idx or 0, node))
  if p[1] and type(p[3]) == "number" then
    return p[3]
  end
  return nil
end

-- The layout test: _pos_atc_free02 sits 1000 px above _pos_base02 on the formation layout copy (850 on the 0.85 grid
-- copy), 0 on the retail layout. Only when the pose command gives no number does the menu decide: the formation layers
-- of a menu that creates team00_01_chara_card_for_soccer 11..19 times (pitch + bench + 3 managers).
function CLEAN_HUD_PC_IsCompact(call, layer, idx)
  if not CLEAN_HUD_PC_IsCardLayer(layer) then
    return false
  end
  local lv = PC.layout[layer]
  if lv == nil then
    local my = PoseY(call, layer, idx, PC_NODE_MARK)
    local py = PoseY(call, layer, idx, PC_NODE_MARK_PARENT)
    if my == nil then
      lv = false
      if PC_FORMATION_LAYERS[layer] then
        local ok, n = pcall(call, PC_CMD_LAYER_NUM, PC_LAYER_SOCCER)
        lv = ok and type(n) == "number" and n >= 11 and n <= 19
      end
    else
      local d = my - (py or 0)
      lv = d > 500 or d < -500
    end
    PC.layout[layer] = lv
    UiLog("layout", layer, idx, my, py, lv)
  end
  return lv
end

function CLEAN_HUD_PC_HideName(call, layer, idx)
  PC.name[PcKey(layer, idx)] = true
  call(PC_CMD_TEXT_VISIBLE, layer, PC_TEXT_NAME, false, idx or 0)
  call(PC_CMD_NODE_VISIBLE, layer, PC_TEXT_NAME, false, idx or 0)
end

function CLEAN_HUD_PC_KeepName(layer, idx)
  PC.name[PcKey(layer, idx)] = nil
end

-- level off on one card; later "visible = true" calls are blocked
local function HideParts(call, layer, idx)
  PC.hide[PcKey(layer, idx)] = true
  for m in pairs(PC_HIDDEN_MESH) do
    call(PC_CMD_MESH_VISIBLE, layer, m, false, idx or 0)
  end
  for _, pr in ipairs(PC_LV_PRIMS) do
    call(PC_CMD_PRIM_VISIBLE, layer, idx or 0, pr, false)
  end
end

-- after a card command: the formation layout loses name and level; a retail-layout card keeps them
local function AfterCard(call, layer, idx)
  if layer == nil then
    return
  end
  local key = PcKey(layer, idx)
  if PC.form > 0 and PC_FORMATION_LAYERS[layer] then
    PC.formKeys[#PC.formKeys + 1] = key
  end
  if CLEAN_HUD_PC_IsCompact(call, layer, idx) then
    CLEAN_HUD_PC_HideName(call, layer, idx)
    HideParts(call, layer, idx)
  else
    PC.name[key] = nil
    PC.hide[key] = nil
  end
end

local function PcFilter(orig, id, ...)
  if not UiOn("compact_cards") then
    return nil
  end
  if id == PC_CMD_CARD_HDL or id == PC_CMD_CARD_PARAM or id == PC_CMD_LEADER_SOCCER or id == PC_CMD_LEADER_TEAM then
    local layer, idx = ...
    local r = Pack(orig(id, ...))
    AfterCard(orig, layer, idx)
    return r
  elseif id == PC_CMD_CARD_TABLE then
    local t = ...
    local r = Pack(orig(id, ...))
    if type(t) == "table" then
      AfterCard(orig, t.layerName, t.layerIdx)
    end
    return r
  elseif id == PC_CMD_TEXT_VISIBLE then
    local a = Pack(...)
    if a[2] == PC_TEXT_NAME and a[3] == true and PC.name[PcKey(a[1], a[4])] then
      a[3] = false
      return Pack(orig(id, table.unpack(a, 1, a.n)))
    end
  elseif id == PC_CMD_NODE_VISIBLE then
    local a = Pack(...)
    if a[2] == PC_TEXT_NAME and a[3] == true and PC.name[PcKey(a[1], a[4])] then
      a[3] = false
      return Pack(orig(id, table.unpack(a, 1, a.n)))
    end
  elseif id == PC_CMD_MESH_VISIBLE then
    local a = Pack(...)
    if a[3] == true and PC_HIDDEN_MESH[a[2]] and PC.hide[PcKey(a[1], a[4])] then
      a[3] = false
      return Pack(orig(id, table.unpack(a, 1, a.n)))
    end
  elseif id == PC_CMD_PRIM_VISIBLE then
    local a = Pack(...)
    if a[4] == true and PC_LV_PRIM_SET[a[3]] and PC.hide[PcKey(a[1], a[2])] then
      a[4] = false
      return Pack(orig(id, table.unpack(a, 1, a.n)))
    end
  elseif id == PC_CMD_PLAY_ANIME or id == PC_CMD_ANIME_RESET then
    -- a state animation (the drag card plays «Active» when picked up and dropped) can show them again natively
    local layer, idx = ...
    local r = Pack(orig(id, ...))
    if PC.hide[PcKey(layer, idx)] then
      HideParts(orig, layer, idx)
    end
    return r
  end
  return nil
end
UiHookMenuCommand(PcFilter)

-- Formation cards: the level is hidden again when the outermost formation card function
-- returns (after UpdateLevelCapAndGrayout and the other post-processing), on the cards it drew with the formation layout.
local function ApplyFormationHide()
  local keys = PC.formKeys
  PC.formKeys = {}
  if not UiOn("compact_cards") or type(funcLuaMenuCommand) ~= "function" then
    return
  end
  for _, key in ipairs(keys) do
    local sep = string.find(key, ":", 1, true)
    local layer = tonumber(string.sub(key, 1, sep - 1))
    local idx = tonumber(string.sub(key, sep + 1)) or 0
    if layer ~= nil and PC.layout[layer] == true then
      HideParts(funcLuaMenuCommand, layer, idx)
    end
  end
end

function CLEAN_HUD_PC_WrapFormation()
  for _, name in ipairs(PC_FORMATION_FUNCS) do
    local f = rawget(_ENV, name)
    if type(f) == "function" and not PC.wrapped[f] then
      local w = function(...)
        PC.form = PC.form + 1
        local r = Pack(f(...))
        PC.form = PC.form - 1
        if PC.form <= 0 then
          PC.form = 0
          ApplyFormationHide()
        end
        return table.unpack(r, 1, r.n)
      end
      PC.wrapped[w] = true
      rawset(_ENV, name, w)
    end
  end
end
