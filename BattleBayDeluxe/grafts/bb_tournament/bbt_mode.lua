-- BattleBayDeluxe bb_tournament, the Campaña / Torneo mode selector (Battle Bay Deluxe 1.5.47; docs/game/modes/
-- bb-tournament.md §0 1.5.47). Owner 2026-10-13: no «Torneo» row in the Battle Bay top menu any more; the Campaña
-- screen's header bar (the dark bar «BB | Estadio BB · Campaña» with the top bar shortcuts on its right) carries a
-- CENTRED selector of pills «Campaña» | «Torneo» | «Liga» (BattleBayDeluxe.TournamentModeSelector.MODES; the active one lit), with the key glyph
-- left of them (the key steps through them in order):
--   * the key: Battle Bay Deluxe's own rebindable action CMD_BBD_MODE_SWITCH (content\inputs\mode_switch.toml: the row
--     «Cambiar Campaña / Torneo» in the game's «Configuración de controles»; default RS / B (owner 2026-10-15: Y
--     opens the focused team's «Plantilla», research/grafts/bb_draft/bbd_roster.lua; Y / B from 2026-10-13; 1.5.47
--     had L3 = retail CMD_FUNC5, which the VR-Framework top bar's open button took on 2026-10-13), polled with
--     CMND_CHECK_INPUT (MENU_CTRL) so it works whatever has the focus; its glyph <CMD_BBD_MODE_SWITCH> follows the
--     player's binding. R3 has no retail command on these screens. While the selector is shown, a retail OnFunction
--     that comes with a press of the selector's key is left out (the wrap at the end: a binding over a retail key),
--     and the selector is locked while the ready balloon's button (layer cmn03_04_cmn_button_b_graphic_text) is open;
--     the mouse: a left click on a pill (CMD_EVT_MOUSE_LEFT, Utilities' top bar input: without Utilities only the
--     key).
--   * the Campaña grid (enjoy_team_select_menu_campaign, opened from the top menu's «Campaña» row): «Torneo» arms the
--     tournament (CMND_BBD_TOURN_ARM with the defaults: the team, then the options popup, the difficulty, the bracket:
--     bbt_grid.lua), «Liga» arms the league (format 2: the same flow, the league's options and standings), «Campaña»
--     disarms it. With a tournament already running (or ended, not shown yet) «Torneo» closes
--     the grid and the top menu opens the Torneo (the bracket + «Continuar el torneo» / «Ver el cuadro» / «Nuevo
--     torneo»: bbt_top.lua, parameter evt_bbd_mode_go_tournament). Locked (buzzer) while a window / popup / the
--     Draft is over the grid or the options are confirmed. Shown only when the grid runs over the Battle Bay top menu
--     (Inazuma Fantasy's «Modos de juego» keeps its own Campaña / Torneo tiles).
--   * the top menu (bb_stadium_top_menu) while the Torneo is up: no selector (owner 2026-10-13: only on the grid
--     before a run starts; until 1.5.50 «Torneo» was lit there and «Campaña» closed the bracket).
-- Layers (content\menus\bb_tournament.toml, in both menus, not opened with the group: opened here on the first draw):
-- evt_bbd_mode_bg (the strip), evt_bbd_mode_pill (one per mode, MODES' order), evt_bbd_mode_txt (0 the key glyph,
-- 1.. the labels: the retail change-page text plate team00_40, its own grey base hidden, as the VR-Framework's grid
-- strip). The instance counts in content\menus\bb_tournament.toml follow MODES (pills #MODES, texts #MODES + 1).
-- The drawings: the mod's atlas #/menu/220_img/bbd_md/bbd_md.g4tx (research/scripts/bbd_mode_selector_art.py).
-- Globals only (BattleBayDeluxe.TournamentModeSelector*); nothing runs at chunk load.
BattleBayDeluxe = type(BattleBayDeluxe) == "table" and BattleBayDeluxe or {}
BattleBayDeluxe.TournamentModeSelector = {
  BG = @crc:evt_bbd_mode_bg@,
  PILL = @crc:evt_bbd_mode_pill@,
  TXT = @crc:evt_bbd_mode_txt@,
  ATLAS = "#/menu/220_img/bbd_md/bbd_md.g4tx",
  SPR_BG = @crc:bbd_md_bg@, SPR_ON = @crc:bbd_md_on@, SPR_OFF = @crc:bbd_md_off@,
  KEY = @crc:CMD_BBD_MODE_SWITCH@,       -- the mod's action (MENU_CTRL; default RS / B, rebindable)
  READY_BTN = 2055576472 --[[cmn03_04_cmn_button_b_graphic_text: the ready balloon's button, retail Y there]],
  CLICK = 218912913 --[[CMD_EVT_MOUSE_LEFT]],
  -- the modes, left to right, and their labels' text keys (evt_bbd_tn_<key>); the format each arms: bbt_mode.lua
  -- BBT_ModeGridSwitch (CMND_BBD_TOURN_ARM: -1 the tournament's default format, 2 the league)
  MODES = { "campaign", "tournament", "league" },
  LABELS = { campaign = "mode_campaign", tournament = "mode_tournament", league = "mode_league" },
  ARM_FMT = { tournament = -1, league = 2 },
  -- geometry, screen px (y down) of the 1920 x 1080 menu camera: the strip centred on CX at the bar's middle Y (the
  -- top bar's own row height, 10_top_bar.lua TB.Y); the pills are drawn PILL_W x PILL_H, the strip as wide as the row + BG_EXTRA (research/scripts/
  -- bbd_mode_selector_art.py SIZES)
  -- BG_EXTRA: the strip past the pills' row (the art's 480 around a 474 px row)
  CX = 960, Y = 34, BG_EXTRA = 6, BG_H = 56, PILL_W = 172, PILL_H = 44, PILL_GAP = 6, KEY_W = 40, GAP = 8, PAD = 10,
  TEXT_CX = 102,                         -- the change-page plate is right-anchored (VR-Framework vrfw_bbp_grid.lua)
  TEXT_S = 0.85, KEY_S = 0.85, DIM = 0.55, LOCK = 0.6, PRIO_TXT = 697,
  Q = 36, NODE_QUAD = 1909474081 --[[icon_new01]], MESH_QUAD = 312193881,
  N = {},
  shown = {}, opened = {}, prev_key = false, prev_click = false, atlas = nil, labels = {},
}
BattleBayDeluxe.TournamentModeSelector.N[BattleBayDeluxe.TournamentModeSelector.BG], BattleBayDeluxe.TournamentModeSelector.N[BattleBayDeluxe.TournamentModeSelector.PILL], BattleBayDeluxe.TournamentModeSelector.N[BattleBayDeluxe.TournamentModeSelector.TXT] = 1, #BattleBayDeluxe.TournamentModeSelector.MODES, #BattleBayDeluxe.TournamentModeSelector.MODES + 1
BattleBayDeluxe.TournamentModeSelector.TEXT = 378156699 --[[_text_guide01]]
-- the commands this file sends in either menu (bbt_top.lua / bbt_grid.lua name the others)
BattleBayDeluxe.Tournament.DISARM = BattleBayDeluxe.Tournament.DISARM or @crc:CMND_BBD_TOURN_DISARM@
BattleBayDeluxe.Tournament.RULE_SELECT = BattleBayDeluxe.Tournament.RULE_SELECT or @crc:CMND_VRFW_RULE_ENGINE_SELECT@
BattleBayDeluxe.TournamentModeSelector.BTN = @crc:_text_btn01@
BattleBayDeluxe.TournamentModeSelector.PLATE_BASE = @crc:_win_guide_base01@

-- the logger (VRFW_Log), made at the first line: the framework's menu files load after the graft blocks
function BBT_ModeLog(...)
  BattleBayDeluxe.TournamentModeSelector.logger = BattleBayDeluxe.TournamentModeSelector.logger or VRFW_Log.New("BattleBayDeluxe.tournament_mode")
  BattleBayDeluxe.TournamentModeSelector.logger(...)
end

local function same(layer, i, state)
  local M = BattleBayDeluxe.TournamentModeSelector
  local k = tostring(layer) .. ":" .. tostring(i)
  if M.shown[k] == state then
    return true
  end
  M.shown[k] = state
  return false
end

-- every instance of the selector's layers opened once (they are not opened with their group)
local function open_all()
  local M = BattleBayDeluxe.TournamentModeSelector
  for layer, n in pairs(M.N) do
    for i = 0, n - 1 do
      local k = tostring(layer) .. ":" .. i
      if not M.opened[k] then
        M.opened[k] = true
        funcLuaMenuCommand(@crc:CMND_OPEN_LAYER@, layer, i)
      end
    end
  end
end

local function quad(layer, i, spr, x, y, w, h, show, g)
  local M = BattleBayDeluxe.TournamentModeSelector
  local state = show and string.format("%s %.1f %.1f %.1f %.1f %.2f", tostring(spr), x, y, w, h, g) or "off"
  if same(layer, i, state) then
    return
  end
  if not show then
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, layer, i, false)
    return
  end
  if M.atlas == nil then
    M.atlas = BBT_Crc(M.ATLAS)
  end
  funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, layer, i, true)
  funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_SCALE@, layer, w / M.Q, h / M.Q, 1, i)
  funcLuaMenuCommand(558735651 --[[sprite]], layer, M.atlas, spr, M.NODE_QUAD, 0, i)
  funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_POS@, layer, x, -y, 0, i)
  funcLuaMenuCommand(@crc:CMND_SET_PRIM_COLOR@, layer, i, M.MESH_QUAD, g, g, g)
end

-- one text (or key glyph) centred on (cx, y)
local function text(i, s, cx, y, scale, show, alpha)
  local M = BattleBayDeluxe.TournamentModeSelector
  if same(M.TXT, i, show and string.format("%s %.1f %.1f %.2f %.2f", s, cx, y, scale, alpha) or "off") then
    return
  end
  funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, M.TXT, i, show)
  if not show then
    return
  end
  funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_POS@, M.TXT, cx + M.TEXT_CX * scale, -y, 0, i)
  funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_SCALE@, M.TXT, scale, scale, 1, i)
  funcLuaMenuCommand(@crc:CMND_SET_DRAW_PRIORITY@, M.TXT, i, M.PRIO_TXT, true)
  funcLuaMenuCommand(@crc:CMND_SET_MENU_TEXT_STRING@, M.TXT, M.BTN, "", i)
  funcLuaMenuCommand(@crc:CMND_SET_MENU_TEXT_STRING@, M.TXT, M.TEXT, s, i)
  funcLuaMenuCommand(@crc:CMND_UPDATE_TEXT_PLATE@, M.TXT, i, M.TEXT)
  funcLuaMenuCommand(@crc:CMND_SET_MESH_VISIBLE@, M.TXT, M.PLATE_BASE, false, i)
  pcall(funcLuaMenuCommand, @crc:CMND_SET_MENU_TEXT_ALPHA@, M.TXT, i, M.TEXT, alpha)
end

-- the key glyph's centre (x), the pills' centres left to right (MODES' order) and the strip's width
function BBT_ModeGeom()
  local M = BattleBayDeluxe.TournamentModeSelector
  local n = #M.MODES
  local inner = M.PAD + M.KEY_W + M.GAP + n * M.PILL_W + (n - 1) * M.PILL_GAP + M.PAD
  local x0 = M.CX - inner / 2
  local key = x0 + M.PAD + M.KEY_W / 2
  local p1 = x0 + M.PAD + M.KEY_W + M.GAP + M.PILL_W / 2
  local pills = {}
  for i = 1, n do
    pills[i] = p1 + (i - 1) * (M.PILL_W + M.PILL_GAP)
  end
  return key, pills, inner + M.BG_EXTRA
end

-- draw the selector: mode = one of MODES, show, locked (dimmed: no switch now)
function BBT_ModeDraw(mode, show, locked)
  local M = BattleBayDeluxe.TournamentModeSelector
  if show then
    open_all()
  end
  local key, pills, bg_w = BBT_ModeGeom()
  local g = locked and M.LOCK or 1
  quad(M.BG, 0, M.SPR_BG, M.CX, M.Y, bg_w, M.BG_H, show, 1)
  text(0, "<CMD_BBD_MODE_SWITCH>", key, M.Y, M.KEY_S, show, locked and M.DIM or 1)
  for i, m in ipairs(M.MODES) do
    local on = m == mode
    quad(M.PILL, i - 1, on and M.SPR_ON or M.SPR_OFF, pills[i], M.Y, M.PILL_W, M.PILL_H, show, g)
    if show and (M.labels[m] == nil or M.labels[m] == "") then
      M.labels[m] = BBT_Text(M.LABELS[m])
    end
    text(i, M.labels[m] or "", pills[i], M.Y, M.TEXT_S, show, on and 1 or M.DIM)
  end
end

-- the mode after `mode` in MODES (the key's step), the first after the last
function BBT_ModeNext(mode)
  local M = BattleBayDeluxe.TournamentModeSelector
  for i, m in ipairs(M.MODES) do
    if m == mode then
      return M.MODES[i % #M.MODES + 1]
    end
  end
  return M.MODES[1]
end

-- a selector layer set up again (opened by the engine): its cached state forgotten
function BBT_ModeSetup(a1)
  local M = BattleBayDeluxe.TournamentModeSelector
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

-- the pill under the pointer: one of MODES, or nil
local function pointed()
  local M = BattleBayDeluxe.TournamentModeSelector
  local mx, my = funcLuaMenuCommand(558229292 --[[pointer]])
  if type(mx) ~= "number" or type(my) ~= "number" then
    return nil
  end
  local py = -my
  for i, mode in ipairs(M.MODES) do
    local gx, gy = funcLuaMenuCommand(4002164178 --[[GPOS]], M.PILL, i - 1)
    if type(gx) == "number" and type(gy) == "number" and math.abs(mx - gx) <= M.PILL_W / 2
      and math.abs(py - gy) <= M.PILL_H / 2 then
      return mode
    end
  end
  return nil
end

-- the switch asked this frame: one of MODES | "toggle" | nil (key / click edges; only while shown)
function BBT_ModePoll(shown)
  local M = BattleBayDeluxe.TournamentModeSelector
  local key = funcLuaCommand(@crc:CMND_CHECK_INPUT_CMD@, 1332654303 --[[MENU_CTRL]], M.KEY) == true
  local click = funcLuaCommand(@crc:CMND_CHECK_INPUT_CMD@, 1332654303 --[[MENU_CTRL]], M.CLICK) == true
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

BattleBayDeluxe.TournamentModeSelector.P_GO_T = @crc:evt_bbd_mode_go_tournament@   -- parameter store: the top menu opens the Torneo after the grid
BattleBayDeluxe.TournamentModeSelector.TOP = 85255651 --[[bb_stadium_top_menu]]
BattleBayDeluxe.TournamentModeSelector.DIFFICULTY = 2996147312 --[[win05_11_select_difficulty_win_base]]

-- the grid's state for the selector: shown, mode, locked. Owner 2026-10-13: ONLY on the team-select grid before a
-- run starts («Elige con qué equipo jugarás», enjoy_team_select_menu_campaign over the Battle Bay top menu): never
-- while a tournament run exists (active, or ended and not shown yet: the group stage, the bracket, the run's menus)
-- nor anywhere else (the top menu's Torneo shows no selector any more: bbt_top.lua BBT_ModeTopStep). A retail
-- Campaña in progress never opens this grid (its row goes to the campaign's own screens).
function BBT_ModeGridState()
  local M = BattleBayDeluxe.TournamentModeSelector
  local info = BBT_INFO or {}
  local show = funcLuaMenuCommand(@crc:CMND_IS_EXIST_MENU_OBJECT@, M.TOP) == true
    and info.active ~= true and info.ended ~= true
    and not (type(BBD_ROSTER) == "table" and BBD_ROSTER.state ~= nil) -- hidden under the «Plantilla» viewer (bb_draft)
  local mode = info.armed and (info.fmt == 2 and "league" or "tournament") or "campaign"
  local locked = (BattleBayDeluxe.TournamentGrid and BattleBayDeluxe.TournamentGrid.co ~= nil)
    or funcLuaMenuCommand(@crc:CMND_IS_EXIST_MENU_OBJECT@, BattleBayDeluxe.Tournament.SUB_WINDOW) == true
    or funcLuaMenuCommand(@crc:CMND_IS_OPEN_LAYER@, M.DIFFICULTY) == true
    or (type(VRFW_BBP) == "table" and VRFW_BBP.hidden == true)
    or funcLuaMenuCommand(@crc:CMND_IS_OPEN_LAYER@, M.READY_BTN) == true
    or info.configured == true or info.pending == true
  return show, mode, locked
end

function BBT_ModeGridSwitch(to, mode)
  local M = BattleBayDeluxe.TournamentModeSelector
  local info = BBT_Info()
  if M.ARM_FMT[to] ~= nil then
    if info.active or info.ended then
      -- a run already there: the Torneo of the top menu (its bracket and panel), the grid closed
      VRFW_Param.Clear(M.P_GO_T)
      VRFW_Param.Set(M.P_GO_T, 1, "plain")
      funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3848881948 --[[sy0000]])
      BBT_ModeLog("grid -> Torneo: a run exists, the grid closes for the top menu's Torneo")
      funcLuaCommand(@crc:CMND_CLOSE_MENU_OBJECT@, 786045682 --[[enjoy_team_select_menu]])
      return
    end
    local ok, why = BBT_Call(BattleBayDeluxe.Tournament.ARM, M.ARM_FMT[to], 0, 0)
    if ok ~= true then
      BBT_ModeLog("grid ->", to, "refused", tostring(ok), tostring(why))
      funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 2086672038 --[[sy0003]])
      return
    end
    BBT_ModeLog("grid ->", to, "armed")
  else
    BBT_Call(BattleBayDeluxe.Tournament.DISARM)
    pcall(funcLuaCommand, BattleBayDeluxe.Tournament.RULE_SELECT, "")
    BBT_ModeLog("grid -> Campaña: disarmed")
  end
  funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 3791946501 --[[sy0004]])
  BBT_Info()
end

-- 1.49.0: while the «Personalizado» team picker runs on the grid (bbt_grid.lua BBT_GridPick) the selector's place says
-- «N / M elegidos» and «<key> Aceptar» (the picker reads the key itself); the pills are hidden
BattleBayDeluxe.TournamentModeSelector.PICK = { COUNT_X = -60, KEY_X = 170, LABEL_X = 262 }
function BBT_ModePickDraw()
  local M, P, pk = BattleBayDeluxe.TournamentModeSelector, BattleBayDeluxe.TournamentModeSelector.PICK, BattleBayDeluxe.TournamentGrid.pick
  open_all()
  quad(M.BG, 0, M.SPR_BG, M.CX, M.Y, 10, M.BG_H, false, 1)
  for i = 1, #M.MODES do
    quad(M.PILL, i - 1, M.SPR_OFF, 0, M.Y, M.PILL_W, M.PILL_H, false, 1)
  end
  local t = BBT_Text("pick_count")
  local ok, r = pcall(funcLuaCommand, 910683996, t, "VALUE", pk.n or 1, 0, 0, true)
  t = ok and r or t
  local ok2, r2 = pcall(funcLuaCommand, 910683996, t, "VALUE2", pk.max or 0, 0, 0, true)
  t = ok2 and r2 or t
  text(1, t, M.CX + P.COUNT_X, M.Y, M.TEXT_S, true, 1)
  text(0, "<CMD_BBD_MODE_SWITCH>", M.CX + P.KEY_X, M.Y, M.KEY_S, true, 1)
  if M.labels.pick == nil or M.labels.pick == "" then
    M.labels.pick = BBT_Text("pick_accept")
  end
  text(2, M.labels.pick, M.CX + P.LABEL_X, M.Y, M.TEXT_S, true, 1)
  for i = 3, #M.MODES do
    text(i, "", 0, M.Y, M.TEXT_S, false, 1)
  end
end

function BBT_ModeGridStep()
  if type(BattleBayDeluxe.TournamentGrid) == "table" and BattleBayDeluxe.TournamentGrid.pick then
    BBT_ModePickDraw()
    return
  end
  local show, mode, locked = BBT_ModeGridState()
  BBT_ModeDraw(mode, show, locked)
  local req = BBT_ModePoll(show)
  if req == nil then
    return
  end
  local to = req == "toggle" and BBT_ModeNext(mode) or req
  if to == mode then
    return
  end
  if locked then
    funcLuaCommand(@crc:CMND_SND_PLAY_SE@, 2086672038 --[[sy0003]])
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
BattleBayDeluxe.TournamentModeSelector.HDR = {
  HEADER = 575058101 --[[mainmenu90_01_header]], TITLE = 1220590795 --[[_text_sub_title02]],
  LOGO = 766762856 --[[vs01_47_bb_stadium_header_logo]], GRID = 786045682 --[[enjoy_team_select_menu]],
  SCALE = 0.9, LEFT = 112, MID_Y = 33.6, on = false, origin = nil,
}

function BBT_ModeHeaderStep()
  local H = BattleBayDeluxe.TournamentModeSelector.HDR
  local info = BBT_INFO or {}
  local want = funcLuaMenuCommand(@crc:CMND_IS_EXIST_MENU_OBJECT@, H.GRID) == true
    and info.active ~= true and info.ended ~= true
  if want then
    if not H.on then
      -- the logo layer's origin on screen at its own scale (y up), once per showing: the shift that keeps the left edge
      local gx, gy = funcLuaMenuCommand(4002164178 --[[global position]], H.LOGO, 0)
      H.origin = (type(gx) == "number" and type(gy) == "number") and {gx, -gy} or {0, 0}
      local k = 1 - H.SCALE
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_SCALE@, H.LOGO, H.SCALE, H.SCALE, 1, 0)
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_POS@, H.LOGO, k * (H.LEFT - H.origin[1]),
        -k * (H.MID_Y - H.origin[2]), 0, 0)
      H.on = true
      BBT_ModeLog("header: logo x" .. H.SCALE .. ", title hidden (team-select grid)")
    end
    -- the title: blank every frame (the game may write it again while the grid is up)
    funcLuaMenuCommand(@crc:CMND_SET_MENU_TEXT_STRING@, H.HEADER, H.TITLE, "", 0)
  elseif H.on then
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_SCALE@, H.LOGO, 1, 1, 1, 0)
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_POS@, H.LOGO, 0, 0, 0, 0)
    H.on = false
    BBT_ModeLog("header: logo back to its size")
  end
end

-- ------------------------------------------------------------------------------------------------ wraps

do
  local setup = OnSetupLayer
  function OnSetupLayer(a1, a2, ...)
    if BBT_ModeSetup(a1) then
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, a1, a2 or 0, false)
      return
    end
    return setup(a1, a2, ...)
  end
  -- the selector's key pressed while it is shown: a retail function the same press fires (a binding over a retail
  -- key) is left out, the selector has the press
  local fn = OnFunction
  if type(fn) == "function" then
    function OnFunction(a1, a2, ...)
      local M = BattleBayDeluxe.TournamentModeSelector
      local any = false
      for _, v in pairs(M.shown) do
        if v then
          any = true
          break
        end
      end
      if any and funcLuaCommand(@crc:CMND_CHECK_INPUT_CMD@, 1332654303 --[[MENU_CTRL]], M.KEY) == true then
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
    if BattleBayDeluxe.TournamentGrid ~= nil then
      ok, err = pcall(BBT_ModeGridStep)
    elseif BattleBayDeluxe.TournamentState ~= nil and type(BBT_ModeTopStep) == "function" then
      ok, err = pcall(BBT_ModeTopStep)
      if ok and type(BattleBayDeluxe.TournamentHost) == "table" and BattleBayDeluxe.TournamentHost.name == "bb_stadium_top_menu" then
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
