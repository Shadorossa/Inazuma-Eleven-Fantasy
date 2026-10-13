-- bb_chronicle_teams bb_tournament, the Campaña / Torneo mode selector (Battle Bay Deluxe 1.5.47; docs/game/modes/
-- bb-tournament.md §0 1.5.47). Owner 2026-10-13: no «Torneo» row in the Battle Bay top menu any more; the Campaña
-- screen's header bar (the dark bar «BB | Estadio BB · Campaña» with the top bar shortcuts on its right) carries a
-- CENTRED selector of two pills «Campaña» | «Torneo» (the active one lit), with the key glyph left of them:
--   * the key: Battle Bay Deluxe's own rebindable action CMD_BBD_MODE_SWITCH (content\inputs\mode_switch.toml: the row
--     «Cambiar Campaña / Torneo» in the game's «Configuración de controles»; default Y / B (owner 2026-10-13); 1.5.47
--     had L3 = retail CMD_FUNC5, which the VR-Framework top bar's open button took on 2026-10-13), polled with
--     CMND_CHECK_INPUT (MENU_CTRL) so it works whatever has the focus; its glyph <CMD_BBD_MODE_SWITCH> follows the
--     player's binding. Y is also retail CMD_FUNC3 (keyboard V) there: in bb_stadium_top_menu the list items' «Guía de
--     controles» window (function 1643904886), in the Campaña grid the ready balloon's button (layer
--     cmn03_04_cmn_button_b_graphic_text, function 3859022927; the grid's own Y function 756653130 has no handler in
--     the campaign script). While the selector is shown, a retail OnFunction that comes with a press of the selector's
--     key is left out (the wrap at the end), and the selector is locked while that balloon button is open; the mouse: a left click on a pill (CMD_EVT_MOUSE_LEFT, Utilities' top bar input:
--     without Utilities only the key).
--   * the Campaña grid (enjoy_team_select_menu_campaign, opened from the top menu's «Campaña» row): «Torneo» arms the
--     tournament (CMND_BBD_TOURN_ARM with the defaults: the team, then the options popup, the difficulty, the bracket:
--     bbt_grid.lua), «Campaña» disarms it. With a tournament already running (or ended, not shown yet) «Torneo» closes
--     the grid and the top menu opens the Torneo (the bracket + «Continuar el torneo» / «Ver el cuadro» / «Nuevo
--     torneo»: bbt_top.lua, parameter evt_bbd_mode_go_tournament). Locked (buzzer) while a window / popup / the
--     Draft is over the grid or the options are confirmed. Shown only when the grid runs over the Battle Bay top menu
--     (Inazuma Fantasy's «Modos de juego» keeps its own Campaña / Torneo tiles).
--   * the top menu (bb_stadium_top_menu) while the Torneo is up: no selector (owner 2026-10-13: only on the grid
--     before a run starts; until 1.5.50 «Torneo» was lit there and «Campaña» closed the bracket).
-- Layers (content\menus\bb_tournament.toml, in both menus, not opened with the group: opened here on the first draw):
-- evt_bbd_mode_bg (the strip), evt_bbd_mode_pill (0 Campaña, 1 Torneo), evt_bbd_mode_txt (0 the key glyph, 1 / 2 the
-- labels: the retail change-page text plate team00_40, its own grey base hidden, as the VR-Framework's grid strip).
-- The drawings: the mod's atlas #/menu/220_img/bbd_md/bbd_md.g4tx (research/scripts/bbd_mode_selector_art.py).
-- Globals only (BBT_MODE*); nothing runs at chunk load.
BBT_MODE = {
  BG = @crc:evt_bbd_mode_bg@,
  PILL = @crc:evt_bbd_mode_pill@,
  TXT = @crc:evt_bbd_mode_txt@,
  ATLAS = "#/menu/220_img/bbd_md/bbd_md.g4tx",
  SPR_BG = @crc:bbd_md_bg@, SPR_ON = @crc:bbd_md_on@, SPR_OFF = @crc:bbd_md_off@,
  KEY = @crc:CMD_BBD_MODE_SWITCH@,       -- the mod's action (MENU_CTRL; default Y / B, rebindable)
  READY_BTN = 2055576472 --[[cmn03_04_cmn_button_b_graphic_text: the ready balloon's button, retail Y there]],
  CLICK = 218912913 --[[CMD_EVT_MOUSE_LEFT]],
  -- geometry, screen px (y down) of the 1920 x 1080 menu camera: the strip centred on CX at the bar's middle Y (the
  -- top bar's own row height, 10_top_bar.lua TB.Y); the sprites are drawn 1:1 (research/scripts/
  -- bbd_mode_selector_art.py SIZES)
  CX = 960, Y = 34, BG_W = 480, BG_H = 56, PILL_W = 200, PILL_H = 44, PILL_GAP = 6, KEY_W = 40, GAP = 8, PAD = 10,
  TEXT_CX = 102,                         -- the change-page plate is right-anchored (VR-Framework vrfw_bbp_grid.lua)
  TEXT_S = 0.85, KEY_S = 0.85, DIM = 0.55, LOCK = 0.6, PRIO_TXT = 697,
  Q = 36, NODE_QUAD = 1909474081 --[[icon_new01]], MESH_QUAD = 312193881,
  N = {},
  shown = {}, opened = {}, prev_key = false, prev_click = false, atlas = nil,
}
BBT_MODE.N[BBT_MODE.BG], BBT_MODE.N[BBT_MODE.PILL], BBT_MODE.N[BBT_MODE.TXT] = 1, 2, 3
BBT_MODE.TEXT = 378156699 --[[_text_guide01]]
-- the commands this file sends in either menu (bbt_top.lua / bbt_grid.lua name the others)
BBT.DISARM = BBT.DISARM or @crc:CMND_BBD_TOURN_DISARM@
BBT.RULE_SELECT = BBT.RULE_SELECT or @crc:CMND_VRFW_RULE_ENGINE_SELECT@
BBT_MODE.BTN = @crc:_text_btn01@
BBT_MODE.PLATE_BASE = @crc:_win_guide_base01@

function BBT_ModeLog(...)
  pcall(funcLuaCommand, 3661580131 --[[CMND_EVT_LOG]], "bb_chronicle_teams mode", ...)
end

local function same(layer, i, state)
  local M = BBT_MODE
  local k = tostring(layer) .. ":" .. tostring(i)
  if M.shown[k] == state then
    return true
  end
  M.shown[k] = state
  return false
end

-- every instance of the selector's layers opened once (they are not opened with their group)
local function open_all()
  local M = BBT_MODE
  for layer, n in pairs(M.N) do
    for i = 0, n - 1 do
      local k = tostring(layer) .. ":" .. i
      if not M.opened[k] then
        M.opened[k] = true
        funcLuaMenuCommand(629267548 --[[CMND_OPEN_LAYER]], layer, i)
      end
    end
  end
end

local function quad(layer, i, spr, x, y, w, h, show, g)
  local M = BBT_MODE
  local state = show and string.format("%s %.1f %.1f %.1f %.1f %.2f", tostring(spr), x, y, w, h, g) or "off"
  if same(layer, i, state) then
    return
  end
  if not show then
    funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], layer, i, false)
    return
  end
  if M.atlas == nil then
    M.atlas = BBT_Crc(M.ATLAS)
  end
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], layer, i, true)
  funcLuaMenuCommand(3778714801 --[[CMND_SET_LAYER_SCALE]], layer, w / M.Q, h / M.Q, 1, i)
  funcLuaMenuCommand(558735651 --[[sprite]], layer, M.atlas, spr, M.NODE_QUAD, 0, i)
  funcLuaMenuCommand(1389957207 --[[CMND_SET_LAYER_LOCAL_POS]], layer, x, -y, 0, i)
  funcLuaMenuCommand(855211291 --[[CMND_SET_PRIM_COLOR]], layer, i, M.MESH_QUAD, g, g, g)
end

-- one text (or key glyph) centred on (cx, y)
local function text(i, s, cx, y, scale, show, alpha)
  local M = BBT_MODE
  if same(M.TXT, i, show and string.format("%s %.1f %.1f %.2f %.2f", s, cx, y, scale, alpha) or "off") then
    return
  end
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], M.TXT, i, show)
  if not show then
    return
  end
  funcLuaMenuCommand(1389957207 --[[CMND_SET_LAYER_LOCAL_POS]], M.TXT, cx + M.TEXT_CX * scale, -y, 0, i)
  funcLuaMenuCommand(3778714801 --[[CMND_SET_LAYER_SCALE]], M.TXT, scale, scale, 1, i)
  funcLuaMenuCommand(1491630496 --[[CMND_SET_DRAW_PRIORITY]], M.TXT, i, M.PRIO_TXT, true)
  funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING]], M.TXT, M.BTN, "", i)
  funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING]], M.TXT, M.TEXT, s, i)
  funcLuaMenuCommand(1172899594 --[[CMND_UPDATE_TEXT_PLATE]], M.TXT, i, M.TEXT)
  funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], M.TXT, M.PLATE_BASE, false, i)
  pcall(funcLuaMenuCommand, 1126837159 --[[CMND_SET_MENU_TEXT_ALPHA]], M.TXT, i, M.TEXT, alpha)
end

-- the pills' centres (x), left to right: Campaña, Torneo; the key glyph's centre
function BBT_ModeGeom()
  local M = BBT_MODE
  local inner = M.PAD + M.KEY_W + M.GAP + 2 * M.PILL_W + M.PILL_GAP + M.PAD
  local x0 = M.CX - inner / 2
  local key = x0 + M.PAD + M.KEY_W / 2
  local p1 = x0 + M.PAD + M.KEY_W + M.GAP + M.PILL_W / 2
  return key, p1, p1 + M.PILL_W + M.PILL_GAP
end

-- draw the selector: mode = "campaign" | "tournament", show, locked (dimmed: no switch now)
function BBT_ModeDraw(mode, show, locked)
  local M = BBT_MODE
  if show then
    open_all()
  end
  local key, p1, p2 = BBT_ModeGeom()
  local g = locked and M.LOCK or 1
  quad(M.BG, 0, M.SPR_BG, M.CX, M.Y, M.BG_W, M.BG_H, show, 1)
  local camp = mode ~= "tournament"
  quad(M.PILL, 0, camp and M.SPR_ON or M.SPR_OFF, p1, M.Y, M.PILL_W, M.PILL_H, show, g)
  quad(M.PILL, 1, camp and M.SPR_OFF or M.SPR_ON, p2, M.Y, M.PILL_W, M.PILL_H, show, g)
  text(0, "<CMD_BBD_MODE_SWITCH>", key, M.Y, M.KEY_S, show, locked and M.DIM or 1)
  if show and (M.label_c == nil or M.label_c == "") then
    M.label_c, M.label_t = BBT_Text("mode_campaign"), BBT_Text("mode_tournament")
  end
  text(1, M.label_c or "", p1, M.Y, M.TEXT_S, show, camp and 1 or M.DIM)
  text(2, M.label_t or "", p2, M.Y, M.TEXT_S, show, camp and M.DIM or 1)
end

-- a selector layer set up again (opened by the engine): its cached state forgotten
function BBT_ModeSetup(a1)
  local M = BBT_MODE
  if M.N[a1] == nil then
    return false
  end
  for k in pairs(M.shown) do
    if k:sub(1, #tostring(a1) + 1) == tostring(a1) .. ":" then
      M.shown[k] = nil
    end
  end
  return true
end

-- the pill under the pointer: "campaign" | "tournament" | nil
local function pointed()
  local M = BBT_MODE
  local mx, my = funcLuaMenuCommand(558229292 --[[pointer]])
  if type(mx) ~= "number" or type(my) ~= "number" then
    return nil
  end
  local py = -my
  for i, mode in ipairs({ "campaign", "tournament" }) do
    local gx, gy = funcLuaMenuCommand(4002164178 --[[GPOS]], M.PILL, i - 1)
    if type(gx) == "number" and type(gy) == "number" and math.abs(mx - gx) <= M.PILL_W / 2
      and math.abs(py - gy) <= M.PILL_H / 2 then
      return mode
    end
  end
  return nil
end

-- the switch asked this frame: "campaign" | "tournament" | "toggle" | nil (key / click edges; only while shown)
function BBT_ModePoll(shown)
  local M = BBT_MODE
  local key = funcLuaCommand(4265778440 --[[CMND_CHECK_INPUT]], 1332654303 --[[MENU_CTRL]], M.KEY) == true
  local click = funcLuaCommand(4265778440 --[[CMND_CHECK_INPUT]], 1332654303 --[[MENU_CTRL]], M.CLICK) == true
  local kd, cd = key and not M.prev_key, click and not M.prev_click
  M.prev_key, M.prev_click = key, click
  if not shown then
    return nil
  end
  if kd then
    return "toggle"
  end
  if cd then
    return pointed()
  end
  return nil
end

-- ------------------------------------------------------------------------------------------------ the grid's side

BBT_MODE.P_GO_T = @crc:evt_bbd_mode_go_tournament@   -- parameter store: the top menu opens the Torneo after the grid
BBT_MODE.TOP = 85255651 --[[bb_stadium_top_menu]]
BBT_MODE.DIFFICULTY = 2996147312 --[[win05_11_select_difficulty_win_base]]

-- the grid's state for the selector: shown, mode, locked. Owner 2026-10-13: ONLY on the team-select grid before a
-- run starts («Elige con qué equipo jugarás», enjoy_team_select_menu_campaign over the Battle Bay top menu): never
-- while a tournament run exists (active, or ended and not shown yet: the group stage, the bracket, the run's menus)
-- nor anywhere else (the top menu's Torneo shows no selector any more: bbt_top.lua BBT_ModeTopStep). A retail
-- Campaña in progress never opens this grid (its row goes to the campaign's own screens).
function BBT_ModeGridState()
  local M = BBT_MODE
  local info = BBT_INFO or {}
  local show = funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT]], M.TOP) == true
    and info.active ~= true and info.ended ~= true
  local mode = info.armed and "tournament" or "campaign"
  local locked = (BBT_G and BBT_G.co ~= nil)
    or funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT]], BBT.SUB_WINDOW) == true
    or funcLuaMenuCommand(2640875187 --[[CMND_IS_OPEN_LAYER]], M.DIFFICULTY) == true
    or (type(VRFW_BBP) == "table" and VRFW_BBP.hidden == true)
    or funcLuaMenuCommand(2640875187 --[[CMND_IS_OPEN_LAYER]], M.READY_BTN) == true
    or info.configured == true or info.pending == true
  return show, mode, locked
end

function BBT_ModeGridSwitch(to, mode)
  local M = BBT_MODE
  local info = BBT_Info()
  if to == "tournament" then
    if info.active or info.ended then
      -- a run already there: the Torneo of the top menu (its bracket and panel), the grid closed
      pcall(funcLuaCommand, 3363400568 --[[param delete]], M.P_GO_T)
      pcall(funcLuaCommand, 3860611758 --[[param set]], M.P_GO_T, 0, 1)
      funcLuaCommand(1917805374, 3848881948 --[[sy0000]])
      BBT_ModeLog("grid -> Torneo: a run exists, the grid closes for the top menu's Torneo")
      funcLuaCommand(320421347 --[[CMND_CLOSE_MENU_OBJECT]], 786045682 --[[enjoy_team_select_menu]])
      return
    end
    local ok, why = BBT_Call(BBT.ARM, -1, 0, 0)
    if ok ~= true then
      BBT_ModeLog("grid -> Torneo refused", tostring(ok), tostring(why))
      funcLuaCommand(1917805374, 2086672038 --[[sy0003]])
      return
    end
    BBT_ModeLog("grid -> Torneo: armed")
  else
    BBT_Call(BBT.DISARM)
    pcall(funcLuaCommand, BBT.RULE_SELECT, "")
    BBT_ModeLog("grid -> Campaña: disarmed")
  end
  funcLuaCommand(1917805374, 3791946501 --[[sy0004]])
  BBT_Info()
end

function BBT_ModeGridStep()
  local show, mode, locked = BBT_ModeGridState()
  BBT_ModeDraw(mode, show, locked)
  local req = BBT_ModePoll(show)
  if req == nil then
    return
  end
  local to = req == "toggle" and (mode == "tournament" and "campaign" or "tournament") or req
  if to == mode then
    return
  end
  if locked then
    funcLuaCommand(1917805374, 2086672038 --[[sy0003]])
    return
  end
  BBT_ModeGridSwitch(to, mode)
end

-- ------------------------------------------------------------------------------------------------ the header

-- Owner 2026-10-13: while the team-select grid is up (before a run starts, the selector's screen), the Battle Bay top
-- menu's header shows the «Estadio BB / Bahía de Batalla» logo 10 % smaller (its left edge kept) and no title text
-- «Campaña» next to it (the selector says the mode). Both are this menu's layers (mainmenu90_01_header text node
-- _text_sub_title02, the logo layer vs01_47_bb_stadium_header_logo), so this runs in the top menu's VM. Leaving the
-- grid gives the logo its size back; the title is the game's again (it writes it with its own state changes).
-- LEFT / MID_Y: the logo's drawn left edge and middle on screen (px, y down) as BetterUI's compact header places it
-- (docs/framework/top-bar.md §8: x 112, the bar's middle 33.6); the scale is around them. Tunables.
BBT_MODE.HDR = {
  HEADER = 575058101 --[[mainmenu90_01_header]], TITLE = 1220590795 --[[_text_sub_title02]],
  LOGO = 766762856 --[[vs01_47_bb_stadium_header_logo]], GRID = 786045682 --[[enjoy_team_select_menu]],
  SCALE = 0.9, LEFT = 112, MID_Y = 33.6, on = false, origin = nil,
}

function BBT_ModeHeaderStep()
  local H = BBT_MODE.HDR
  local info = BBT_INFO or {}
  local want = funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT]], H.GRID) == true
    and info.active ~= true and info.ended ~= true
  if want then
    if not H.on then
      -- the logo layer's origin on screen at its own scale (y up), once per showing: the shift that keeps the left edge
      local gx, gy = funcLuaMenuCommand(4002164178 --[[global position]], H.LOGO, 0)
      H.origin = (type(gx) == "number" and type(gy) == "number") and {gx, -gy} or {0, 0}
      local k = 1 - H.SCALE
      funcLuaMenuCommand(3778714801 --[[CMND_SET_LAYER_LOCAL_SCALE]], H.LOGO, H.SCALE, H.SCALE, 1, 0)
      funcLuaMenuCommand(1389957207 --[[CMND_SET_LAYER_LOCAL_POS]], H.LOGO, k * (H.LEFT - H.origin[1]),
        -k * (H.MID_Y - H.origin[2]), 0, 0)
      H.on = true
      BBT_ModeLog("header: logo x" .. H.SCALE .. ", title hidden (team-select grid)")
    end
    -- the title: blank every frame (the game may write it again while the grid is up)
    funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING]], H.HEADER, H.TITLE, "", 0)
  elseif H.on then
    funcLuaMenuCommand(3778714801 --[[CMND_SET_LAYER_LOCAL_SCALE]], H.LOGO, 1, 1, 1, 0)
    funcLuaMenuCommand(1389957207 --[[CMND_SET_LAYER_LOCAL_POS]], H.LOGO, 0, 0, 0, 0)
    H.on = false
    BBT_ModeLog("header: logo back to its size")
  end
end

-- ------------------------------------------------------------------------------------------------ wraps

do
  local setup = OnSetupLayer
  function OnSetupLayer(a1, a2, ...)
    if BBT_ModeSetup(a1) then
      funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], a1, a2 or 0, false)
      return
    end
    return setup(a1, a2, ...)
  end
  -- the selector's key pressed while it is shown: a retail function the same press fires (Y = retail CMD_FUNC3:
  -- the hub's «Guía de controles», the ready balloon's button) is left out, the selector has the press
  local fn = OnFunction
  if type(fn) == "function" then
    function OnFunction(a1, a2, ...)
      local M = BBT_MODE
      local any = false
      for _, v in pairs(M.shown) do
        if v then
          any = true
          break
        end
      end
      if any and funcLuaCommand(4265778440 --[[CMND_CHECK_INPUT]], 1332654303 --[[MENU_CTRL]], M.KEY) == true then
        BBT_ModeLog("retail function", tostring(a1), "left out: the press is the selector's key")
        return 1
      end
      return fn(a1, a2, ...)
    end
  end
  local step = Step
  function Step(...)
    local r = table.pack(step(...))
    local ok, err
    if BBT_G ~= nil then
      ok, err = pcall(BBT_ModeGridStep)
    elseif BBT_S ~= nil and type(BBT_ModeTopStep) == "function" then
      ok, err = pcall(BBT_ModeTopStep)
      if ok and type(BBT_HOST) == "table" and BBT_HOST.name == "bb_stadium_top_menu" then
        ok, err = pcall(BBT_ModeHeaderStep)
      end
    else
      ok = true
    end
    if not ok then
      BBT_ModeLog("error", tostring(err))
    end
    return table.unpack(r, 1, r.n)
  end
end
