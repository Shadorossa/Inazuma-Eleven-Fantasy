-- Utilities: the top bar shortcuts' game Lua (docs/framework/top-bar.md). The framework's top bar runtime
-- (lua\menu\_all\10_top_bar.lua) calls, in each host menu's VM: the hosts' gates (`gate = "BetterQoL.TopBarOn"` /
-- `"BetterQoL.TopBarOnBoard"` in content\menus\top_bar.toml and Inazuma Fantasy's menus TOML), the open button's hint
-- (VRFW_TopBarHint), a group's dropdown labels (VRFW_TopBarDropLabel) and the rank plate's hide
-- (VRFW_TopBarRankHide). This file runs in every VM so they are there. Moved from BetterUI (assets\lua\_all\
-- clean_hud_top_bar.lua, until BetterUI 1.20.0, owner decision 2026-10-12): its old globals stay as aliases at the end
-- (CLEAN_HUD_TopBarOn, CLEAN_HUD_TopBarOnBoard, CLEAN_HUD_TB_*). Defines functions and tables only; nothing runs at
-- chunk load.
BetterQoL = type(BetterQoL) == "table" and BetterQoL or {}
BetterQoL.TopBar = type(BetterQoL.TopBar) == "table" and BetterQoL.TopBar or {}
local TB = BetterQoL.TopBar

-- The gate of every Utilities host: always on (no option row); kept as the hosts' gate.
function BetterQoL.TopBarOn()
  return true
end

-- The gate of the menus that also open elsewhere and get the bar only over the Chronicle board (BetterUI 1.18.1, Nacho
-- 2026-10-11): the board's START menu kizuna_town_mainmenu (Plantilla de equipo / Objetos / Ayuda / Opciones /
-- Guardar) is Estación Kizuna's main menu too, which keeps no bar. True while a board menu exists: the board script's
-- settings, the same four menus content\menus\top_bar.toml gives the bar to (research/scripts/top_bar_build.py
-- ROUTE_MENUS; `--check` compares them). Engine calls only when the framework calls the gate (from a Step).
TB.BOARD_MENUS = {"vs_route_town_menu", "vs_route_town_menu_future", "vs_route_town_menu_future_clear",
  "vs_route_town_menu_victory"}

function BetterQoL.TopBarOnBoard()
  if type(CRC32) ~= "function" then
    return false
  end
  for _, m in ipairs(TB.BOARD_MENUS) do
    local ok, r = pcall(funcLuaMenuCommand, 2231168902 --[[CMND_IS_EXIST_MENU_OBJECT]], CRC32(m))
    if ok and r == true then
      return true
    end
  end
  return false
end

-- The open button's hint left of the row (Nacho 2026-10-08): the game's own button glyph, not a drawn badge. Layer
-- evt_topbar_hint (content\menus\top_bar.toml: a copy of the retail corner button cmn03_01_cmd_back, its plate meshes
-- hidden here, no collision / anchor) carries in its text node the markup of the text row utilities_topbar_open
-- («<CMD_VRFW_TOPBAR_OPEN>»: the command of Utilities' action «Abrir accesos directos», content\inputs\top_bar.toml,
-- default L3 / N, rebindable in the game's «Configuración de controles»; until 2026-10-13 «<CMD_FUNC6>» = R3), so the
-- engine draws the glyph of the button bound now on the device in use (Xbox LS, PlayStation L3, the keyboard key) like
-- every retail button guide. The framework calls this from its Draw (VRFW_TopBarHint(menu, x, y, on), x / y = the
-- hint's centre on screen).
-- HINT: the text node's box in cmn03_01.g4pkm (left x -384, middle y 144, local, y up; the text style is left-aligned)
-- and the glyph's half width, to put the glyph's centre on (x, y). Tunables.
TB.HINT = {
  LAYER = 1224058434 --[[evt_topbar_hint]], NODE = 378327766 --[[_text_cmd_back01]],
  MESHES = {298211823 --[[_cmd_back_base01]], 2853207670 --[[_cmd_back_base01_add]]},
  TEXT = 536445349 --[[crc32 utilities_topbar_open]], FALLBACK = "<CMD_VRFW_TOPBAR_OPEN>",
  BOX_LEFT = -384, BOX_MID_Y = 144, HALF = 17, SCALE = 1.0,
  shown = {},
}

function VRFW_TopBarHint(menu, x, y, on)
  local H = TB.HINT
  local n = funcLuaMenuCommand(1175615627 --[[CMND_GET_CREATE_LAYER_NUM]], H.LAYER)
  if type(n) ~= "number" or n <= 0 then
    return
  end
  if not on then
    funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], H.LAYER, 0, false)
    funcLuaMenuCommand(1389957207 --[[CMND_SET_LAYER_LOCAL_POS]], H.LAYER, -4000, 4000, 0, 0)
    H.shown[menu or 0] = false
    return
  end
  local s = funcLuaCommand(4074371074 --[[CMND_TEXT_GET]], H.TEXT)
  if type(s) ~= "string" or s == "" then
    s = H.FALLBACK
  end
  for _, m in ipairs(H.MESHES) do
    funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], H.LAYER, m, false, 0)
  end
  funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING]], H.LAYER, H.NODE, s, 0)
  funcLuaMenuCommand(3778714801 --[[CMND_SET_LAYER_LOCAL_SCALE]], H.LAYER, H.SCALE, H.SCALE, 1, 0)
  funcLuaMenuCommand(1389957207 --[[CMND_SET_LAYER_LOCAL_POS]], H.LAYER,
    x - H.HALF - H.BOX_LEFT * H.SCALE, -y - H.BOX_MID_Y * H.SCALE, 0, 0)
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], H.LAYER, 0, true)
  H.shown[menu or 0] = true
end

-- The labels of a top bar group's dropdown (VR-Framework 2.0.92: docs/framework/top-bar.md §16). The framework draws
-- the dropdown's panel, row highlight and row icons and calls VRFW_TopBarDropLabel(menu, i, text, x, y, on, sel) for
-- row i (x = the label's left edge, y = the row's centre on screen; text = the entry's text in the game's language).
-- Layer evt_topbar_drop_label (content\menus\top_bar.toml: instance i - 1 = row i) is the hint's retail corner button
-- cmn03_01_cmd_back: its plate meshes hidden, the text written into its text node, the node box's left / middle put on
-- (x, y) (same box as the hint: left x -384, middle y 144, left-aligned text). Tunables.
TB.DROP = {
  LAYER = 4195704679 --[[evt_topbar_drop_label]], NODE = 378327766 --[[_text_cmd_back01]],
  MESHES = {298211823 --[[_cmd_back_base01]], 2853207670 --[[_cmd_back_base01_add]]},
  BOX_LEFT = -384, BOX_MID_Y = 144, SCALE = 1.0,
  TEXT_SIZE = 3549540977 --[[CMND_GET_MENU_TEXT_RECT_SIZE (layer, idx, node, string) -> w, h]],
}

-- a label's width on screen at SCALE (the engine's text box of the label layer's text node); nil = not measurable
-- (no shrink then). Utilities' own (Utilities 1.14.11: a VRFW_ global here was a reserved-name WARN).
function Utilities_TopBarDropLabelWidth(menu, text)
  local D = TB.DROP
  local n = funcLuaMenuCommand(1175615627 --[[CMND_GET_CREATE_LAYER_NUM]], D.LAYER)
  if type(n) ~= "number" or n < 1 or type(text) ~= "string" then return nil end
  local ok, w = pcall(funcLuaMenuCommand, D.TEXT_SIZE, D.LAYER, 0, D.NODE, text)
  if ok and type(w) == "number" and w > 0 then return w * D.SCALE end
  return nil
end

-- maxw (VRFW 2.2.41): the room the framework gives the label (px); a wider text is drawn smaller to fit it
function VRFW_TopBarDropLabel(menu, i, text, x, y, on, sel, maxw)
  local D = TB.DROP
  local n = funcLuaMenuCommand(1175615627 --[[CMND_GET_CREATE_LAYER_NUM]], D.LAYER)
  if type(n) ~= "number" or i < 1 or i > n then
    return
  end
  local idx = i - 1
  if not on or type(text) ~= "string" then
    funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], D.LAYER, idx, false)
    funcLuaMenuCommand(1389957207 --[[CMND_SET_LAYER_LOCAL_POS]], D.LAYER, -4000, 4000, 0, idx)
    return
  end
  for _, m in ipairs(D.MESHES) do
    funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], D.LAYER, m, false, idx)
  end
  funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING]], D.LAYER, D.NODE, text, idx)
  local s = D.SCALE
  if type(maxw) == "number" and maxw > 0 then
    local w = Utilities_TopBarDropLabelWidth(menu, text)
    if w ~= nil and w > maxw then s = D.SCALE * maxw / w end
  end
  funcLuaMenuCommand(3778714801 --[[CMND_SET_LAYER_LOCAL_SCALE]], D.LAYER, s, s, 1, idx)
  funcLuaMenuCommand(1389957207 --[[CMND_SET_LAYER_LOCAL_POS]], D.LAYER,
    x - D.BOX_LEFT * s, -y - D.BOX_MID_Y * s, 0, idx)
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], D.LAYER, idx, true)
end

-- The rank plate never shares the bar with the team panel (Nacho 2026-10-08): in the hubs whose header has both (Modo
-- Competición = soccer_top_menu, Victory Road), the team panel «PLANTILLA DE EQUIPO / name / Nv. EQUIPO» opens in the
-- header when the team dock, the skill board or another team screen is open over the hub, and the rank plate (centred
-- on the bar by BetterUI's [top_bar_rank]) was drawn behind it. The framework asks this every check
-- (VRFW_TopBarRankHide(menu) -> true = hide the plate in that menu, kept hidden every frame, shown again after).
-- RANK_HIDE_WITH: the header layers that take the plate's place (the team panel mainmenu90_31_doc_item, attached at the
-- header's _pos_atc_sdock01).
TB.RANK_HIDE_WITH = {2279382105 --[[mainmenu90_31_doc_item]]}

function VRFW_TopBarRankHide(menu)
  for _, layer in ipairs(TB.RANK_HIDE_WITH) do
    -- open AND visible: soccer_top_menu keeps the panel open and only shows it (CMND_SET_LAYER_VISIBLE) while a team
    -- screen is over the hub (SetSoccerTopCommonHeaderTeamDocLayerVisible)
    local ok, r = pcall(funcLuaCommand, 3693934564 --[[CMND_IS_OPEN_MENU_OBJECT]], menu, layer)
    if ok and r ~= nil and r ~= false and r ~= 0 then
      local okv, v = pcall(funcLuaMenuCommand, 1262717583 --[[CMND_IS_LAYER_VISIBLE]], layer, 0)
      if okv and v == true then
        return true
      end
    end
  end
  return false
end

-- The names these had while BetterUI declared the bar (until 1.20.0): other mods' TOML gates and game Lua may still
-- name them. Same functions / tables (by reference).
CLEAN_HUD_TopBarOn = BetterQoL.TopBarOn
CLEAN_HUD_TopBarOnBoard = BetterQoL.TopBarOnBoard
CLEAN_HUD_TB_BOARD_MENUS = TB.BOARD_MENUS
CLEAN_HUD_TB_HINT = TB.HINT
CLEAN_HUD_TB_DROP = TB.DROP
CLEAN_HUD_TB_RANK_HIDE_WITH = TB.RANK_HIDE_WITH
