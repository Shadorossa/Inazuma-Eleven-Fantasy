-- bb_chronicle_teams bb_tournament, Battle Bay top menu (bb_stadium_top_menu; docs/game/modes/bb-tournament.md §5-§7).
--   * 1.5.47 (owner 2026-10-13): no «Torneo» row any more (bbt_row.lua, 1.4.1-1.5.45, removed): the Torneo is a MODE of
--     the Campaña screen, picked in its header bar (bbt_mode.lua: «Campaña» | «Torneo», L3 or a click). The «Campaña»
--     row: with a tournament running (or ended, not shown yet) it opens in Torneo mode (the bracket + its panel, as the
--     row did: BBT_EntryTournament), else the retail Campaña (its continue window, the grid) whose header may switch to
--     the Torneo; the top bar's Battle Bay › Torneo decides the same row in Torneo mode (BBT_DecideRow). The grid's
--     «Torneo» with a run closes the grid and this menu opens the Torneo (BBT_ModeAfterGrid, parameter
--     evt_bbd_mode_go_tournament); a tournament started from a grid the retail row opened shows its bracket here too.
--     (1.4.1-1.5.45, the row's flow, still the Torneo mode's:) «Campaña» = the retail flow unchanged
--     (1.5.5: the Campaña and the Torneo are independent; neither refuses the other). Torneo with no run: format (straight knockout / group stage + knockout), then
--     teams (8 / 16 / 32; config.toml [tournament] gives the cursor's start), then the retail Campaña grid opens with
--     the tournament armed (CMND_BBD_TOURN_ARM): the player picks his team (the Draft tile too) and the difficulty,
--     and the Decide hook (scripts\campaign.lua) draws the bracket and starts match 1. Refused while a Campaña runs.
--     Torneo with a run: «Continuar el torneo» (the bracket, then Enter = next match) or «Nuevo torneo» (after a Yes /
--     No the run is dropped and a new one starts: the grid at once); an ended run: «Ver el cuadro» / «Nuevo torneo».
--   * 1.5.18 (owner, 2026-10-12): the Torneo PANEL. The entry (this menu's Torneo row, or «Modos de juego»'s Torneo
--     tile: bbt_hub.lua runs this same file on that menu) opens the bracket and, centred over it, the window
--     «Continuar el torneo» (the next match) / «Ver el cuadro» (the bracket stays: L1 / R1 pages, Back closes) /
--     «Nuevo torneo» (Yes / No while one runs, then the team grid); Back closes both and leaves the player where he
--     was. No run: «Nuevo torneo» at once = the team grid. The screen it runs on is BBT_HOST (layers hidden under the
--     bracket, the lists whose focus it takes, the header, the grid, the way back): this menu by default.
--   * 1.5.17 (owner, 2026-10-12): the Battle Bay rows are gone (Inazuma Fantasy's «Modos de juego» hides them, its
--     mh_bb.lua): this hub is entered through the «Torneo» tile of «Modos de juego» (or the top bar), whose row decide
--     runs here; with no run it goes STRAIGHT to the team grid (no window before it). While a Torneo flow runs here
--     the hub's way back to «Modos de juego» waits (EVT_MH_BB_HOLD.bb_tournament); after it (bracket closed, grid left,
--     window cancelled) the player is back on the tile.
--   * Every opening of this menu (back from a match, entering the Battle Bay) first syncs the tournament
--     (CMND_BBD_TOURN_SYNC with the rule engine's STATE of the last match): the result is recorded, the round's other
--     matches simulated, the campaign block written for the next match (or zeroed: out / champion). This runs BEFORE
--     the retail OnInit, so its «campaign active» flag already sees the block as the tournament left it. Then the
--     bracket overlay opens by itself on the round's results.
--   * The overlay (content\menus\bb_tournament.toml), filled from CMND_BBD_TOURN_VIEW; 1.5.15: the WHOLE bracket in
--     one view, built from its size (rounds = log2(teams)): each team on a game list plate with its crest (left side:
--     crest left of the name; right side mirrored), the connectors drawn as lines (the winners' path lit), each
--     match's score at its joint, the champion's plate and crown above the final; results pages on the same
--     plates (goals beside them), the group tables in their own menu (1.5.60, BBT_GroupsShow); the page title in the menu's header. L1 / R1 (and left / right) turn pages, Enter = next match (the retail campaign «continue»
--     request, after selecting the round's rulebook); eliminated: Enter simulates the next remaining round and shows
--     it (round by round to the final), then closes and clears the run; Back = close.
-- Globals only (BBT_*); nothing runs at chunk load.
BBT.ARM = @crc:CMND_BBD_TOURN_ARM@
BBT.DISARM = @crc:CMND_BBD_TOURN_DISARM@
BBT.SYNC = @crc:CMND_BBD_TOURN_SYNC@
BBT.VIEW = @crc:CMND_BBD_TOURN_VIEW@
BBT.ABANDON = @crc:CMND_BBD_TOURN_ABANDON@
BBT.CLOSE = @crc:CMND_BBD_TOURN_CLOSE@
BBT.STEP = @crc:CMND_BBD_TOURN_STEP@
BBT.PREPARE = @crc:CMND_BBD_TOURN_PREPARE@
BBT.UNLOAD = @crc:CMND_BBD_TOURN_UNLOAD@
-- the Torneo's grid = the Campaña's grid variant opened through the 1P row's path: the retail WaitExecOtherMenu of
-- enjoy_team_select_menu sends CMND_OPEN_MENU_OBJECT(786045682, 534870484 offline); BBT_OpenGridAsCampaign swaps that
-- one call to 1455139087 (campaign). The game registers funcLuaCommand AFTER the chunk ran, so a wrapper installed at
-- chunk load is overwritten and never runs (BBD 1.5.6: the Torneo opened the 1v1 grid); the swap is a temporary
-- wrapper put in place around that one WaitExecOtherMenu (the retail chunk looks the global up at every call).
function BBT_OpenGridAsCampaign()
  local cmd = funcLuaCommand
  local swapped = false
  local swap
  swap = function(c, a1, a2, ...)
    if not swapped and c == 433545986 --[[CMND_OPEN_MENU_OBJECT]] and a1 == 786045682 and a2 == 534870484 then
      swapped = true
      if funcLuaCommand == swap then
        funcLuaCommand = cmd
      end
      -- as the retail Campaña path (label L332): the online team-select flag cleared before the campaign grid
      cmd(3363400568, 357455239)
      BBT_Log("grid: the Campaña variant for the Torneo")
      return cmd(c, a1, 1455139087 --[[enjoy_team_select_menu_campaign]], ...)
    end
    return cmd(c, a1, a2, ...)
  end
  funcLuaCommand = swap
  local ok, err = pcall(WaitExecOtherMenu, 786045682 --[[enjoy_team_select_menu]], BBT.LIST_MID)
  if funcLuaCommand == swap then
    funcLuaCommand = cmd
  end
  if not swapped then
    BBT_Log("grid: no swap (the 1P path did not open the grid variant)")
  end
  if not ok then
    error(err, 0)
  end
end
BBT.RULE_SELECT = @crc:CMND_VRFW_RULE_ENGINE_SELECT@
BBT.RULE_STATE = @crc:CMND_VRFW_RULE_ENGINE_STATE@
BBT.ROW_CAMPAIGN = 4154438766
BBT.LIST_MID = 716364754 --[[mainmenu90_11_list_item_middle]]
BBT.LIST_SMALL = 530619243 --[[mainmenu90_12_list_item_small]]
BBT.TOP = 85255651 --[[bb_stadium_top_menu]]
BBT.ANCHOR = @crc:evt_bbd_tn_anchor@
BBT.FN_PREV = @crc:evt_bbd_tn_prev@
BBT.FN_NEXT = @crc:evt_bbd_tn_next@
-- the bracket layers (content\menus\bb_tournament.toml; 1.5.15: the whole bracket in one view, built from its size)
BBT.L = {
  bg = @crc:vroad04_01_p1_bg@,
  line = @crc:evt_bbd_tn_line@,    -- connector pieces (a tinted white quad)
  row_l = @crc:evt_bbd_tn_row_l@,  -- a team plate, crest left of the name (left side; results / groups; champion)
  row_r = @crc:evt_bbd_tn_row_r@,  -- the mirrored plate (right side)
  txt = @crc:evt_bbd_tn_txt@,      -- free texts: match scores, group titles, results values
  icon = @crc:evt_bbd_tn_icon@,    -- the champion's crown
}
-- instances of each layer (the menu file's counts: the largest bracket, T.MAX_SIZE = 64 teams)
BBT.L.box = @crc:evt_bbd_tn_box@   -- 1.5.24: a score box at a plate's inner end (between the plates and the texts)
-- 1.5.35: a crest alone (the left plate's object, plate and name hidden): the winners standing at the bracket's joints
-- and walking to them (at most one per match of the first round: 32)
BBT.L.crest = @crc:evt_bbd_tn_crest@
-- 1.5.57 (owner in game 2026-10-13 22:41: the Battle Bay top menu stayed WHITE): the engine sets up at most ~844
-- layer instances in one open menu (docs/game/ui/menu-layer-limits.md §2.1-§2.2); past it the menu never finishes
-- opening (its background never ends opening, the retail FadeIn never runs: the title's white fade stays). 1.5.54
-- had raised this menu to 1440 instances (its own group-table layers, row_l 64, txt 336, box 112); 1.5.57 went back
-- to the bracket's own pools. 1.5.60: the group tables are drawn in their own menu (BBT_GroupsShow), so the texts are
-- the bracket's only (txt 64: 63 scores of a 64-team bracket, 64 goals of a 32-match results page). Budget: retail 26
-- + Utilities 269 + this file 484 = 779 in bb_stadium_top_menu (every pool costs its instances at every opening).
BBT.N = { line = 256, row_l = 33, row_r = 32, txt = 64, icon = 1, box = 64, crest = 32 }
-- draw priority of a connector-pool quad by what it draws (the layer's own is the connectors' 549; a score box drawn
-- on it where the menu has no box pool: 552, BBT.SHARE)
BBT.PRIO = { line = 549, box = 552 }
-- 1.5.58: a pool this menu does not have (BBT.N[k] = 0) drawn on another pool of the same object, at its own draw
-- priority (BBT.PRIO[k]): { box = "line" } on «Modos de juego» (bbt_hub.lua BBT_HOST.share; the layer budget). None
-- here: this menu has every pool
BBT.SHARE = {}
BBT.ROW_CHAMP = 32                 -- row_l instance of the champion's plate
BBT.ART = 2658588602               -- crc32("#/menu/220_img/bbd_tn/bbd_tn.g4tx"): the mod's drawings
BBT.SPR_LINE = @crc:bbd_tn_line@
BBT.SPR_CROWN = @crc:bbd_tn_crown@
-- 1.5.37 (owner in game, 2026-10-13: every connector white, the lost branches too): CMND_SET_PRIM_COLOR never tinted
-- these cmn01_10 quads, so each state is a flat quad of its own colour (research/scripts/bbd_bracket_art.py FLAT),
-- drawn with a white tint
BBT.SPR_STATE = {
  plain = @crc:bbd_tn_line_plain@, lit = @crc:bbd_tn_line_lit@, me = @crc:bbd_tn_line_me@,
  out = @crc:bbd_tn_line_out@, out_me = @crc:bbd_tn_line_out_me@,
  win = @crc:bbd_tn_line_lit@, lose = @crc:bbd_tn_box_lose@, even = @crc:bbd_tn_box_even@,
}
BBT.WHITE = { 1, 1, 1 }
BBT.MESH_QUAD = 312193881 --[[_icon_new01]]
BBT.NODE_QUAD = 1909474081 --[[icon_new01]]
-- the plate's four looks (team06_02): off = light (a team), on = blue (the player), ok = cyan (the champion), ol =
-- the focus outline (never shown here)
BBT.PLATE = { off = @crc:_list_base_xs01_off@, on = @crc:_list_base_xs01_on@, ok = @crc:_list_base_xs01_ok@,
  ol = @crc:_list_base_xs01_ol@ }
BBT.MESH_EMBLEM = @crc:_icon_emblem_dmy01@
BBT.EMBLEM_TEX = @crc:icon_emblem_dmy01@
BBT.TXT_ON = @crc:_text_list01_on@     -- white (on the blue / cyan plates)
BBT.TXT_OFF = @crc:_text_list01_off@   -- blue (on the light plate)
BBT.STYLE_TXT = 187454762              -- fs_28_w_cc_2d2_001: centred white, outlined (scores, titles)
BBT.C = {
  VISIBLE = 711242136, POS = 1389957207, SCALE = 3778714801, SPRITE = 558735651, PRIM_COLOR = 855211291,
  MESH_VISIBLE = 3405944500, TEXT = 1083631230, TEXT_VISIBLE = 1505208242, TEXT_STYLE = 2333948100,
  TEAM_INFO = 2151743654, ICON_REQ = 3190452549, ICON_RESET = 4176779611,
}
-- the geometry, screen px (y down) of the 1920 x 1080 menu camera; research/scripts/bbd_bracket_art.py draws the
-- same numbers in its preview. Rows: the plates of one side share the height TOP..BOTTOM (pitch = height / rows),
-- the plate scaled to FILL of the pitch (at most SCALE_MAX); the junction of round r at (CX - xe) * r / R from the
-- plates' edge (+ GAP), so the final meets in the middle (CX) and its stem goes up to the champion's plate.
BBT.G = {
  W = 1920, TOP = 136, BOTTOM = 1004, MARGIN = 34, CX = 960, PLATE_W = 520, PLATE_H = 72, FILL = 0.84,
  SCALE_MAX = 1.0, GAP = 16, Q = 36, LINE = 4, LINE_LIT = 6, CHAMP_Y = 176, CHAMP_S = 0.85, CROWN_W = 72,
  CROWN_H = 54, SCORE_DY = 18, TXT_MIN = 0.62, TXT_MAX = 0.9,
  COL = { 0.66, 0.78, 0.95 }, COL_LIT = { 1.0, 0.80, 0.24 }, DIM = 0.5,
  -- the Victory Road background (vroad04_01_p1: one translucent navy panel, 2004 x 724 at y 178 below its origin)
  -- stretched to hold the whole bracket: BG_TOP .. BG_BOTTOM
  BG_Y = 178, BG_H = 724, BG_TOP = 100, BG_BOTTOM = 1036,
  -- results (8 matches: two columns of 4, the two plates of a match one above the other); the group tables: their own
  -- menu (BBT_GroupsShow)
  RES_X = 190, RES_TOP = 196, RES_MATCH = 196, RES_ROW = 80, RES_VAL = 56,
}
-- the top menu's own layers hidden under the overlay (the retail lists of WaitExecOtherMenu)
BBT.TOP_LAYERS = {
  314687935 --[[vs01_00_p2_background_bb_stadium]], 766432831 --[[mainmenu90_35_cross_play_guide]],
  1611500684 --[[mainmenu90_06_content_guide_line03]], 1597333599 --[[mainmenu90_25_list_item_locator]],
  716364754 --[[mainmenu90_11_list_item_middle]], 530619243 --[[mainmenu90_12_list_item_small]],
  3687874606 --[[mainmenu90_24_tutorial_button]], 4096284290 --[[mainmenu90_24_02_play_guide_button]],
  429081730 --[[vs01_21_room_setting_button]], 2575749231 --[[vs11_01_next_stage_guide]],
}
-- 1.5.18: the screen the Torneo runs on. This menu (the Battle Bay top menu) by default; «Modos de juego» sets its own
-- in bbt_hub.lua (appended after this file there). hide = layers made invisible under the bracket (every instance),
-- close = layers closed / reopened (the retail SwitchLayerOpenOrClose way), lists = control focus taken while the
-- bracket is up, step = the top bar step answered here (nil: none)
BBT_HOST = {
  name = "bb_stadium_top_menu", menu = 85255651, hide = {}, close = BBT.TOP_LAYERS,
  lists = { 716364754 --[[mainmenu90_11_list_item_middle]], 530619243 --[[mainmenu90_12_list_item_small]] },
  step = "bb_tournament",
  -- the page title in the menu's header (the BB header type 30); «Modos de juego» keeps its own header (1.5.19)
  title = function(t)
    pcall(SwapSoccerTopCommonHeaderByHeaderType, 30, t)
  end,
  header = function()
    pcall(SwapSoccerTopCommonHeaderByHeaderType, 30, funcLuaCommand(4074371074 --[[CMND_TEXT_GET]], 3066112094))
  end,
  refocus = function()
    funcLuaMenuCommand(3518307824 --[[CMND_SET_ENABLE_CTRL_FOCUS?]], BBT.LIST_MID, true)
    funcLuaMenuCommand(3518307824 --[[CMND_SET_ENABLE_CTRL_FOCUS?]], BBT.LIST_SMALL, true)
    funcLuaMenuCommand(1778826357, BBT.LIST_MID, 0, true)
  end,
  ready = function()
    return funcLuaMenuCommand(102308320 --[[CMND_IS_CTRL_FOCUS_ACTIVE?]], BBT.LIST_MID) == true
  end,
  open_grid = function()
    BBT_OpenGridAsCampaign()
  end,
  before_match = function() end,
}

-- open / close every instance of the layers (soccer_top_menu has no SwitchLayerOpenOrClose of its own)
function BBT_SwitchLayers(t, open)
  for _, l in ipairs(t or {}) do
    local n = funcLuaMenuCommand(1175615627 --[[CMND_GET_CREATE_LAYER_NUM?]], l) or 0
    for i = 0, n - 1 do
      if open then
        funcLuaMenuCommand(629267548 --[[CMND_OPEN_LAYER]], l, i)
      else
        funcLuaMenuCommand(1273612389 --[[CMND_CLOSE_LAYER]], l, i)
      end
    end
  end
end

function BBT_ShowLayers(t, on)
  for _, l in ipairs(t or {}) do
    local n = funcLuaMenuCommand(1175615627 --[[CMND_GET_CREATE_LAYER_NUM?]], l) or 0
    for i = 0, n - 1 do
      funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], l, i, on)
    end
  end
end

BBT_S = { open = false, view = nil, page = -1, want = false, frames = 0, co = nil, busy = false, step = false,
  sync = false, sync_frames = 0, emb = {}, used = {}, taken = {}, entry = false }

-- 1.5.17: «Modos de juego» (Inazuma Fantasy, mh_bb.lua) sends the player back to its tiles once this hub is idle; a
-- Torneo flow of this menu holds it (the bracket open or on its way, the entry / next-match coroutines, the sync,
-- the top bar step)
EVT_MH_BB_HOLD = EVT_MH_BB_HOLD or {}
EVT_MH_BB_HOLD.bb_tournament = function()
  local S = BBT_S
  return S.open or S.entry or S.co ~= nil or S.want or S.step or S.sync or S.after_grid ~= nil
end

function BBT_TeamName(team)
  if team == nil or team == 0 then
    return ""
  end
  local ok, _, name = pcall(funcLuaCommand, 2151743654, team, 2)
  if ok and type(name) == "string" then
    return name
  end
  return ""
end

-- ------------------------------------------------------------------------------------------------ the sync

-- the tournament takes the last match's result (the rule engine's STATE) before the retail OnInit reads the block
function BBT_Sync()
  local st = { pcall(funcLuaCommand, BBT.RULE_STATE) }
  local args = {}
  if st[1] == true then
    for i = 2, 9 do
      args[#args + 1] = st[i]
    end
  end
  local r = BBT_Call(BBT.SYNC, table.unpack(args, 1, 8))
  if type(r) ~= "table" then
    return false
  end
  BBT_Log("sync", r.event, r.show)
  if r.show then
    BBT_S.want = true
    BBT_S.frames = 0
  end
  -- an armed tournament that never started (the grid left without a start) is disarmed here
  local info = BBT_Info()
  if info.armed then
    BBT_Call(BBT.DISARM)
    pcall(funcLuaCommand, BBT.RULE_SELECT, "")
  end
  return true
end

-- ------------------------------------------------------------------------------------------------ the overlay

-- 1.5.22 (owner log 18:32 on «Modos de juego»: every bracket layer open0=false vis0=false): CMND_OPEN_LAYER does
-- not open them there. On a host with vis_only (the hub: its layers are opened with the menu's group, hidden at
-- setup by bbt_hub.lua) «open» / «close» = visible / invisible.
local function bbt_open_layer(l, i)
  if BBT_HOST.vis_only then
    funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], l, i, true)
    return
  end
  funcLuaMenuCommand(629267548 --[[CMND_OPEN_LAYER]], l, i)
end
local function bbt_close_layer(l, i)
  if BBT_HOST.vis_only then
    funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], l, i, false)
    return
  end
  funcLuaMenuCommand(1273612389 --[[CMND_CLOSE_LAYER]], l, i)
end

-- every instance of the overlay's own layers (name in BBT.L / BBT.N)
function BBT_EachInstance(f)
  for k, n in pairs(BBT.N) do
    for i = 0, n - 1 do
      f(BBT.L[k], i)
    end
  end
end

function BBT_Hide(layer, i)
  local C = BBT.C
  funcLuaMenuCommand(C.VISIBLE, layer, i, false)
  funcLuaMenuCommand(C.POS, layer, -4000, 4000, 0, i)
end

-- the pieces drawn by one BBT_Draw: { [layer] = next free instance }; the rest hidden at the end
function BBT_Begin()
  BBT_S.used = {}
  for _, l in pairs(BBT.L) do
    BBT_S.used[l] = 0
  end
  BBT_S.crests = {}
  BBT_S.taken = {}
end

function BBT_Take(layer, fixed)
  local i = fixed
  if i == nil then
    i = BBT_S.used[layer]
    while BBT_S.taken[tostring(layer) .. ":" .. i] do
      i = i + 1
    end
    BBT_S.used[layer] = i + 1
  end
  BBT_S.taken[tostring(layer) .. ":" .. i] = true
  return i
end

function BBT_End()
  BBT_EachInstance(function(l, i)
    if not BBT_S.taken[tostring(l) .. ":" .. i] then
      BBT_Hide(l, i)
    end
  end)
end

-- a tinted quad of the mod's drawings: centre (x, y), w x h px; prio = the draw priority of a connector-pool
-- instance (1.5.58: a score box on a host without a box pool, BBT.SHARE; nil = the connectors' own)
function BBT_Quad(layer, spr, x, y, w, h, col, prio)
  local C, G = BBT.C, BBT.G
  local nk = "icon"
  for k, l in pairs(BBT.L) do
    if l == layer and BBT.N[k] then
      nk = k
    end
  end
  -- 1.5.58: a pool shared with another one (BBT.SHARE) on the menu that has none of its own
  local to = BBT.N[nk] <= 0 and BBT.SHARE[nk] or nil
  if to ~= nil and BBT.L[to] ~= nil and BBT.N[to] then
    layer, nk, prio = BBT.L[to], to, prio or BBT.PRIO[nk]
  end
  local i = BBT_Take(layer)
  if i >= BBT.N[nk] then
    return
  end
  if layer == BBT.L.line then
    local want = prio or BBT.PRIO.line
    BBT_S.prio = BBT_S.prio or {}
    if BBT_S.prio[i] ~= want then
      BBT_S.prio[i] = want
      funcLuaMenuCommand(1491630496 --[[CMND_SET_DRAW_PRIORITY]], layer, i, want, true)
    end
  end
  funcLuaMenuCommand(C.VISIBLE, layer, i, true)
  funcLuaMenuCommand(C.SCALE, layer, w / G.Q, h / G.Q, 1, i)
  funcLuaMenuCommand(C.SPRITE, layer, BBT.ART, spr, BBT.NODE_QUAD, 0, i)
  funcLuaMenuCommand(C.POS, layer, x, -y, 0, i)
  funcLuaMenuCommand(C.PRIM_COLOR, layer, i, BBT.MESH_QUAD, col[1], col[2], col[3])
end

-- an axis-aligned connector piece from (x0, y0) to (x1, y1); lit = on the winners' path (thicker); st = its state
-- (BBT.SPR_STATE: plain / lit / me / out / out_me; default lit or plain), drawn as that state's coloured quad
function BBT_Seg(x0, y0, x1, y1, lit, st)
  local G = BBT.G
  local t = lit and G.LINE_LIT or G.LINE
  local w, h
  if y0 == y1 then
    w, h = math.abs(x1 - x0) + t, t
  else
    w, h = t, math.abs(y1 - y0) + t
  end
  local spr = BBT.SPR_STATE[st or (lit and "lit" or "plain")] or BBT.SPR_LINE
  BBT_Quad(BBT.L.line, spr, (x0 + x1) / 2, (y0 + y1) / 2, w, h, BBT.WHITE)
end

-- a free text centred on (x, y) at `scale`; style = a retail font style (crc32 of its name; default BBT.STYLE_TXT)
function BBT_Txt(s, x, y, scale, style)
  if s == nil or s == "" then
    return
  end
  local C, L = BBT.C, BBT.L
  local i = BBT_Take(L.txt)
  if i >= BBT.N.txt then
    return
  end
  funcLuaMenuCommand(C.VISIBLE, L.txt, i, true)
  funcLuaMenuCommand(C.POS, L.txt, x, -y, 0, i)
  funcLuaMenuCommand(C.SCALE, L.txt, scale, scale, 1, i)
  funcLuaMenuCommand(C.TEXT_STYLE, L.txt, i, BBT.TXT_ON, style or BBT.STYLE_TXT)
  funcLuaMenuCommand(C.TEXT, L.txt, BBT.TXT_ON, s, i)
  funcLuaMenuCommand(C.TEXT, L.txt, BBT.TXT_OFF, "", i)
  funcLuaMenuCommand(C.TEXT_VISIBLE, L.txt, BBT.TXT_ON, true, i)
  funcLuaMenuCommand(C.TEXT_VISIBLE, L.txt, BBT.TXT_OFF, false, i)
end

-- the team's crest on a plate (the retail emblem request of the office lists); asked again only when the instance
-- shows another team (the engine keeps an icon it already holds)
function BBT_Emblem(layer, i, team)
  local C = BBT.C
  local k = tostring(layer) .. ":" .. i
  if BBT_S.emb[k] == team then
    return
  end
  if BBT_S.emb[k] ~= nil then
    pcall(funcLuaMenuCommand, C.ICON_RESET, layer, i, BBT.EMBLEM_TEX)
  end
  BBT_S.emb[k] = team
  local ok, r, e = pcall(funcLuaCommand, C.TEAM_INFO, team, 6, 0)
  if ok and r then
    funcLuaMenuCommand(C.ICON_REQ, layer, i, BBT.MESH_EMBLEM, BBT.EMBLEM_TEX, e)
  end
end

-- a team plate: p = { team, me, out }, (x, y) = its left edge / vertical centre, scale s; right = the mirrored plate;
-- champ = the champion's look; fixed = the instance to use (the champion's)
function BBT_Plate(p, x, y, s, right, champ, fixed)
  local C, L = BBT.C, BBT.L
  local l = right and L.row_r or L.row_l
  local i = BBT_Take(l, fixed)
  if i >= BBT.N[right and "row_r" or "row_l"] then
    return
  end
  local look = champ and "ok" or (p.me and "on" or "off")
  local white = look ~= "off"
  funcLuaMenuCommand(C.VISIBLE, l, i, true)
  funcLuaMenuCommand(C.SCALE, l, s, s, 1, i)
  funcLuaMenuCommand(C.POS, l, x, -y, 0, i)
  for k, m in pairs(BBT.PLATE) do
    funcLuaMenuCommand(C.MESH_VISIBLE, l, m, k == look, i)
  end
  local name = BBT_TeamName(p.team)
  funcLuaMenuCommand(C.TEXT, l, BBT.TXT_ON, white and name or "", i)
  funcLuaMenuCommand(C.TEXT, l, BBT.TXT_OFF, white and "" or name, i)
  funcLuaMenuCommand(C.TEXT_VISIBLE, l, BBT.TXT_ON, white, i)
  funcLuaMenuCommand(C.TEXT_VISIBLE, l, BBT.TXT_OFF, not white, i)
  local c = (p.out and not champ) and BBT.G.DIM or 1
  funcLuaMenuCommand(C.PRIM_COLOR, l, i, BBT.PLATE[look], c, c, c)
  funcLuaMenuCommand(C.PRIM_COLOR, l, i, BBT.MESH_EMBLEM, c, c, c)
  -- 1.5.37: the tint did not show in game; a team that is out is drawn faded (the retail locked-dock alpha)
  BBT_Alpha(l, i, (p.out and not champ) and BBT.ADV.OUT_ALPHA or 1)
  BBT_Emblem(l, i, p.team)
end

-- an instance's model + name alpha (CMND_SET_LAYER_MODEL_ALPHA / CMND_SET_MENU_TEXT_ALPHA, as the retail
-- soccer_team_dock_menu UpdateViewMenuByLock); reset to 1 on every plate / crest drawn (instances are reused)
function BBT_Alpha(l, i, a)
  pcall(funcLuaMenuCommand, 4231609516 --[[CMND_SET_LAYER_MODEL_ALPHA?]], l, i, 0, a)
  pcall(funcLuaMenuCommand, 1126837159 --[[CMND_SET_MENU_TEXT_ALPHA?]], l, i, BBT.TXT_ON, a)
  pcall(funcLuaMenuCommand, 1126837159 --[[CMND_SET_MENU_TEXT_ALPHA?]], l, i, BBT.TXT_OFF, a)
end

-- a match's score, the upper entrant's goals first: «2-1», «1-1 (4-3)» (the shoot-out in brackets; the results page
-- names extra time and penalties)
function BBT_Score(sc)
  if not sc then
    return ""
  end
  local s = string.format("%d-%d", sc.ga or 0, sc.gb or 0)
  if (sc.pa or 0) + (sc.pb or 0) > 0 then
    s = s .. string.format(" (%d-%d)", sc.pa or 0, sc.pb or 0)
  end
  return s
end

-- the knockout tree (1.5.15): every round in one view. v.rounds = R, v.leaves[1 .. 2^R] (first half left, second
-- half right, top to bottom), v.matches[r][t] = { w, score }. The plates of a side share the height; the junction
-- of round r sits at xe + (CX - xe) * r / R (left side; the right side mirrored), so the final meets at CX. A
-- match's score sits between its two stubs, the final's below its joint.
-- 1.5.35 (owner 2026-10-13): the bracket ADVANCES. Every connector piece belongs to the entrant that walks it: lit
-- (gold; the player's own path a light blue) while that entrant is still in, dark once it is out (its whole way from
-- its plate to the match it lost); the plate of a team that is out is dimmed (BBT_Plate). Each winner's CREST stands
-- at the joint it reached (a crest instance of evt_bbd_tn_crest, just past the joint on the next round's stub; the
-- final's winner = the champion's plate); BBT_S.crests = those crests with the path each walked from its previous
-- place (BBT_AnimStart moves the round just played along it).
BBT.ADV = {
  DUR = 0.65,             -- s, one crest's walk
  STAGGER = 0.06,         -- s between two crests' starts (all of them within STAGGER_ALL)
  STAGGER_ALL = 0.4,
  CREST_S = 0.85,         -- a crest at a joint, of the plates' scale
  CREST_W = 68,           -- the crest slot's width (evt_bbd_tn_row_l: 22 .. 90 px from the plate's left edge)
  CREST_X = 56,           -- its centre from the left plate's left edge
  CREST_X_R = 464,        -- and from the mirrored plate's left edge (430 + 34)
  -- the line colours: BBT.SPR_STATE (1.5.37: coloured quads; plain, lit gold, me light blue, out dark, out_me)
  OUT_ALPHA = 0.45,       -- 1.5.37: the plate of a team that is out (model + text alpha, the retail locked-dock way)
}

function BBT_DrawTree(v)
  local G, A = BBT.G, BBT.ADV
  local R = tonumber(v.rounds) or 0
  if R < 1 and type(v.leaves) == "table" then
    -- 1.5.22: the view's own count missing: from the leaves (2^R)
    local n = 0
    for _ in pairs(v.leaves) do
      n = n + 1
    end
    while 2 ^ (R + 1) <= n do
      R = R + 1
    end
  end
  if R < 1 or type(v.leaves) ~= "table" or type(v.matches) ~= "table" then
    return
  end
  local leaves = v.leaves
  local N = 2 ^ R
  local half = N / 2
  local pitch = (G.BOTTOM - G.TOP) / half
  local s = math.min(G.SCALE_MAX, pitch * G.FILL / G.PLATE_H)
  local ts = math.max(G.TXT_MIN, math.min(G.TXT_MAX, s))
  local edge = G.MARGIN + G.PLATE_W * s
  local xe = edge + G.GAP
  local cs = s * A.CREST_S
  local cw = A.CREST_W * cs
  local function jx(r)
    return xe + (G.CX - xe) * r / R
  end
  local function mx(x, right)
    return right and (2 * G.CX - x) or x
  end
  -- leaves: y of entrant t (1-based) of round r - 1 = ys[t]; own[t] = the leaf standing in that slot, at[t] = where
  -- its crest stands (on its plate for round 1)
  local ys, own, at = {}, {}, {}
  for t = 1, N do
    local right = t > half
    local k = (t - 1) % half
    local y = G.TOP + pitch * (k + 0.5)
    ys[t] = y
    own[t] = t
    local p = leaves[t]
    local x = right and (G.W - G.MARGIN - G.PLATE_W * s) or G.MARGIN
    at[t] = { x + (right and A.CREST_X_R or A.CREST_X) * s, y }
    if p and (p.team or 0) ~= 0 then
      BBT_Plate(p, x, y, s, right, false)
    end
  end
  -- a piece walked by leaf `l`: plain before its match is played, lit while that team is still in, dark once out
  local segs = {}
  local function seg(x0, y0, x1, y1, l, played, won)
    local p = leaves[l] or {}
    local st = "plain"
    if played and (p.team or 0) ~= 0 then
      st = (won and not p.out) and "lit" or "out"
    end
    segs[#segs + 1] = { x0, y0, x1, y1, st, p.me == true }
  end
  local crests = {}
  local ymid = (G.TOP + G.BOTTOM) / 2
  local cpw = G.PLATE_W * G.CHAMP_S
  for r = 1, R do
    local row = v.matches[r] or {}
    local cnt = N / 2 ^ r
    local nx, nown, nat = {}, {}, {}
    for t = 1, cnt do
      local m = row[t] or { w = 0 }
      local w = m.w or 0
      local played = w ~= 0
      local ya, yb = ys[2 * t - 1], ys[2 * t]
      local la, lb = own[2 * t - 1], own[2 * t]
      local ym = (ya + yb) / 2
      nx[t] = ym
      local win = w == 1 and la or (w == 2 and lb or 0)
      nown[t] = win
      local from = w == 1 and at[2 * t - 1] or at[2 * t]
      local yw = w == 1 and ya or yb
      local xc = r == 1 and edge or jx(r - 1)
      if r < R then
        local right = t > cnt / 2
        local xj = jx(r)
        seg(mx(xc, right), ya, mx(xj, right), ya, la, played, w == 1)
        seg(mx(xc, right), yb, mx(xj, right), yb, lb, played, w == 2)
        seg(mx(xj, right), ya, mx(xj, right), ym, la, played, w == 1)
        seg(mx(xj, right), ym, mx(xj, right), yb, lb, played, w == 2)
        -- the score in the pocket between the match's two stubs (left of its joint; mirrored on the right)
        BBT_Txt(BBT_Score(m.score), mx((xc + xj) / 2, right), ym, ts)
        if win ~= 0 and from then
          -- the winner's crest: just past the joint, on the next round's stub
          local rest = { mx(xj + cw / 2, right), ym }
          nat[t] = rest
          local nxt = (v.matches[r + 1] or {})[math.floor((t + 1) / 2)] or {}
          crests[#crests + 1] = { leaf = win, round = r, rest = rest, s = cs, stays = (nxt.w or 0) == 0,
            path = { from, { mx(xj, right), yw }, { mx(xj, right), ym }, rest } }
        end
      else
        -- the final: the left finalist's line and the right one's meet at CX; the stem up to the champion
        seg(xc, ya, G.CX, ya, la, played, w == 1)
        seg(mx(xc, true), yb, G.CX, yb, lb, played, w == 2)
        seg(G.CX, G.CHAMP_Y + G.PLATE_H * G.CHAMP_S / 2, G.CX, ymid, win, played, true)
        BBT_Txt(BBT_Score(m.score), G.CX, ymid + G.SCORE_DY * 1.6, math.max(ts, 0.8))
        if win ~= 0 and from then
          -- the champion's crest walks to the champion plate's crest slot (the plate shows once it is there)
          local rest = { G.CX - cpw / 2 + A.CREST_X * G.CHAMP_S, G.CHAMP_Y }
          crests[#crests + 1] = { leaf = win, round = r, rest = rest, s = cs, s1 = G.CHAMP_S, final = true,
            stays = false, path = { from, { G.CX, yw }, { G.CX, G.CHAMP_Y }, rest } }
        end
      end
    end
    ys, own, at = nx, nown, nat
  end
  -- the plain pieces first, then the dark ones, the lit path over them
  for _, st in ipairs({ "plain", "out", "lit" }) do
    for _, g in ipairs(segs) do
      if g[5] == st then
        local look = st
        if g[6] and st == "lit" then
          look = "me"
        elseif g[6] and st == "out" then
          look = "out_me"
        end
        BBT_Seg(g[1], g[2], g[3], g[4], st == "lit", look)
      end
    end
  end
  -- the crests standing at a joint (the round's winners not yet past their next match)
  BBT_S.crests = crests
  for _, c in ipairs(crests) do
    if c.stays then
      c.i = BBT_Crest(c, c.rest[1], c.rest[2], c.s)
    end
  end
  -- the champion: a cyan plate above the final with the crown over it (the crown waits dimmed until the final)
  local champ = (v.champion or 0) ~= 0
  local cs2 = G.CHAMP_S
  local cy = G.CHAMP_Y - G.PLATE_H * cs2 / 2 - G.CROWN_H / 2 + 6
  local cc = champ and 1 or G.DIM
  BBT_Quad(BBT.L.icon, BBT.SPR_CROWN, G.CX, cy, G.CROWN_W, G.CROWN_H, { cc, cc, cc })
  if champ then
    BBT_Plate({ team = v.champion }, G.CX - G.PLATE_W * cs2 / 2, G.CHAMP_Y, cs2, false, true, BBT.ROW_CHAMP)
  end
end

-- a crest alone (an evt_bbd_tn_crest instance: the left plate with its plate and name hidden) centred on (x, y) at
-- scale sc; returns the instance (nil: none left)
function BBT_Crest(c, x, y, sc)
  local C, L = BBT.C, BBT.L
  local i = BBT_Take(L.crest)
  if i >= BBT.N.crest then
    return nil
  end
  local p = BBT.ADV
  funcLuaMenuCommand(C.VISIBLE, L.crest, i, true)
  for _, m in pairs(BBT.PLATE) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L.crest, m, false, i)
  end
  funcLuaMenuCommand(C.TEXT_VISIBLE, L.crest, BBT.TXT_ON, false, i)
  funcLuaMenuCommand(C.TEXT_VISIBLE, L.crest, BBT.TXT_OFF, false, i)
  funcLuaMenuCommand(C.PRIM_COLOR, L.crest, i, BBT.MESH_EMBLEM, 1, 1, 1)
  BBT_Alpha(L.crest, i, 1)
  funcLuaMenuCommand(C.SCALE, L.crest, sc, sc, 1, i)
  funcLuaMenuCommand(C.POS, L.crest, x - p.CREST_X * sc, -y, 0, i)
  local lf = (BBT_S.view and BBT_S.view.leaves or {})[c.leaf] or {}
  BBT_Emblem(L.crest, i, lf.team or 0)
  return i
end

-- ------------------------------------------------------------------------------------------------ the advance
-- 1.5.35 (owner 2026-10-13): when the bracket opens after a match (results -> bracket, the champion screen -> the
-- final bracket) each winner of the round just played walks from its previous place along the lines (along the
-- stub, then the joint) to its new one, a short ease, staggered a little; frame time from Step, so the keys stay
-- live (Enter = straight to the end, L1 / R1 / Back drop it). Every other opening draws the bracket already advanced.

-- the point at fraction f (0..1) of a polyline's length
local function bbt_along(path, f)
  local total, lens = 0, {}
  for k = 2, #path do
    local d = math.abs(path[k][1] - path[k - 1][1]) + math.abs(path[k][2] - path[k - 1][2])
    lens[k] = d
    total = total + d
  end
  if total <= 0 then
    return path[#path][1], path[#path][2]
  end
  local want = total * f
  for k = 2, #path do
    if want <= lens[k] or k == #path then
      local u = lens[k] > 0 and math.min(1, want / lens[k]) or 1
      local a, b = path[k - 1], path[k]
      return a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u
    end
    want = want - lens[k]
  end
  return path[#path][1], path[#path][2]
end

local function bbt_ease(p)
  if p < 0.5 then
    return 4 * p * p * p
  end
  return 1 - (-2 * p + 2) ^ 3 / 2
end

-- the round just played (the last one with a result) walks; nothing when the tree has no result yet
function BBT_AnimStart(v)
  BBT_S.anim = nil
  local crests = BBT_S.crests or {}
  local last = 0
  for _, c in ipairs(crests) do
    last = math.max(last, c.round)
  end
  if last == 0 then
    return
  end
  local A = BBT.ADV
  local items = {}
  for _, c in ipairs(crests) do
    if c.round == last then
      if c.i == nil then
        -- the final's winner: a crest of its own for the walk (the champion plate waits)
        c.i = BBT_Crest(c, c.path[1][1], c.path[1][2], c.s)
      end
      if c.i ~= nil then
        items[#items + 1] = c
      end
    end
  end
  if #items == 0 then
    return
  end
  local gap = math.min(A.STAGGER, A.STAGGER_ALL / #items)
  for k, c in ipairs(items) do
    c.delay = (k - 1) * gap
  end
  BBT_S.anim = { t = 0, page = v.page, items = items, round = last, done_at = (#items - 1) * gap + A.DUR }
  BBT_AnimApply()
  BBT_Log(string.format("bracket advance: round %d, %d crest(s) walk", last, #items))
end

-- place every walking crest at the animation's time (each Step; also right after a redraw of the same page)
function BBT_AnimApply()
  local an = BBT_S.anim
  if not an then
    return
  end
  local C, L, A = BBT.C, BBT.L, BBT.ADV
  local champ_wait = false
  for _, c in ipairs(an.items) do
    local p = math.max(0, math.min(1, (an.t - c.delay) / A.DUR))
    local e = bbt_ease(p)
    local x, y = bbt_along(c.path, e)
    local sc = c.s + ((c.s1 or c.s) - c.s) * e
    local show = not (c.final and p >= 1)
    funcLuaMenuCommand(C.VISIBLE, L.crest, c.i, show)
    funcLuaMenuCommand(C.SCALE, L.crest, sc, sc, 1, c.i)
    funcLuaMenuCommand(C.POS, L.crest, x - A.CREST_X * sc, -y, 0, c.i)
    if c.final and p < 1 then
      champ_wait = true
    end
  end
  -- the champion's plate shows when its crest gets there
  if (BBT_S.view and (BBT_S.view.champion or 0) ~= 0) then
    funcLuaMenuCommand(C.VISIBLE, L.row_l, BBT.ROW_CHAMP, not champ_wait)
  end
end

function BBT_AnimStep()
  local an = BBT_S.anim
  if not an then
    return
  end
  local ok, dt = pcall(funcLuaCommand, 1549797111)
  if not ok or type(dt) ~= "number" or dt <= 0 or dt > 0.5 then
    dt = 1 / 60
  end
  an.t = an.t + dt
  if an.t >= an.done_at then
    BBT_AnimFinish("done")
    return
  end
  BBT_AnimApply()
end

-- the walk to its end at once (Enter, or its time out)
function BBT_AnimFinish(why)
  local an = BBT_S.anim
  if not an then
    return
  end
  an.t = an.done_at + 1
  BBT_AnimApply()
  BBT_S.anim = nil
  BBT_Log("bracket advance:", why)
end

-- the results of a round: matches 1-4 on the left (plates as the left side), 5-8 on the right (mirrored), the two
-- plates of a match one above the other, each team's goals beside its plate
-- 1.5.24 (owner): the round's results as scoreboard rows, EVERY match of the round on one page (16 rows for a
-- 32-team first round): team A's plate (crest left) ending at the centre, team B's mirrored plate starting there,
-- each team's goals in a box at its plate's inner end (the winner's box lit, the loser's dark); a shoot-out adds the
-- kicks in brackets, extra time «(pr.)». v.rows[t] = { a, b, ga, gb, pa, pb, et, done, w }
BBT.RES = { GAP = 20, BOX_W = 64, BOX_W_PEN = 128, BOX_H = 0.74, PITCH_MAX = 84, FILL = 0.84,
  -- the boxes' colours: BBT.SPR_STATE win / lose / even (1.5.37: coloured quads)
}
function BBT_DrawResults(v)
  local G, Rr = BBT.G, BBT.RES
  local rows = v.rows or {}
  local n = #rows
  if n == 0 then
    return
  end
  local pitch = math.min(Rr.PITCH_MAX, (G.BOTTOM - G.TOP) / n)
  local s = math.min(G.SCALE_MAX, pitch * Rr.FILL / G.PLATE_H)
  local top = (G.TOP + G.BOTTOM) / 2 - pitch * n / 2
  local pw = G.PLATE_W * s
  local bh = G.PLATE_H * s * Rr.BOX_H
  local ts = math.max(G.TXT_MIN, math.min(G.TXT_MAX + 0.1, s))
  for t, r in ipairs(rows) do
    local y = top + pitch * (t - 0.5)
    local xa = G.CX - Rr.GAP / 2 - pw
    local xb = G.CX + Rr.GAP / 2
    if r.a and (r.a.team or 0) ~= 0 then
      BBT_Plate(r.a, xa, y, s, false, false)
    end
    if r.b and (r.b.team or 0) ~= 0 then
      BBT_Plate(r.b, xb, y, s, true, false)
    end
    if r.done then
      for side = 1, 2 do
        local g = side == 1 and r.ga or r.gb
        local pk = side == 1 and r.pa or r.pb
        local txt = tostring(g or 0)
        local bw = Rr.BOX_W * s
        if (r.pa or 0) + (r.pb or 0) > 0 then
          txt = string.format("%d (%d)", g or 0, pk or 0)
          bw = Rr.BOX_W_PEN * s
        elseif r.et then
          txt = txt .. "*"
        end
        local look = "even"
        if r.w ~= 0 then
          look = r.w == side and "win" or "lose"
        end
        local bx = side == 1 and (G.CX - Rr.GAP / 2 - bw / 2 - 4) or (G.CX + Rr.GAP / 2 + bw / 2 + 4)
        BBT_Quad(BBT.L.box, BBT.SPR_STATE[look], bx, y, bw, bh, BBT.WHITE)
        BBT_Txt(txt, bx, y, ts)
      end
    end
  end
end

-- 1.5.60 (owner 2026-10-14: «que la fase de grupos no se divida nunca en páginas, siempre 1 sola página»): the group
-- stage's standings tables (1.5.54's approved sketch: a card per group, position, crest + name, the numbers, the
-- points cell, the qualification zone, the player's row, the form dots, the legend) are drawn with EVERY group on one
-- page (1 / 2 / 4 groups «wide», 8 «compact» 4 x 2, 16 «tiny» 4 x 4) in a menu of their own, evt_bbd_tn_groups_menu
-- (content\menus\bb_tournament.toml [[screen]], its script assets\lua\screens\evt_bbd_tn_groups_menu.lua): 642 layer
-- instances that this menu (bb_stadium_top_menu at 779 of the engine's ~844 per open menu, docs/game/ui/
-- menu-layer-limits.md §2.1-2.3) cannot hold. 1.5.57-1.5.58 paged them on the bracket's pools (BBT_GrpPaging, L1 / R1,
-- «(k/n)» in the title): gone. That menu is display-only (registry priority 0, no input layer): this host keeps the
-- keys (L1 / R1 to the other pages, Enter, Back), its header title and the background; the group page draws nothing on
-- this menu's pools (all hidden) and opens the child; any other page, or the overlay's close, closes it.
BBT.GM = {
  MENU = @crc:evt_bbd_tn_groups_menu@,
  P_PAGE = @crc:evt_bbd_tn_groups_page@,   -- parameter: the view page the child draws
  P_HOST = @crc:evt_bbd_tn_groups_host@,   -- parameter: this host (the child closes itself when it is gone)
}

-- the child opened once it is wanted and an earlier one has finished closing (Step and BBT_GroupsShow)
function BBT_GroupsStep()
  local S = BBT_S
  if S.gm_want == nil or S.gm_open or not S.open then
    return
  end
  if funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT?]], BBT.GM.MENU) == true then
    S.gm_wait = (S.gm_wait or 0) + 1
    if S.gm_wait == 300 then
      BBT_Log("groups menu: an earlier one still exists after 300 Steps; waiting")
    end
    return
  end
  S.gm_wait = 0
  pcall(funcLuaCommand, 3860611758 --[[param set]], BBT.GM.P_PAGE, 0, S.gm_want, 1)
  pcall(funcLuaCommand, 3860611758 --[[param set]], BBT.GM.P_HOST, 0, BBT_HOST.menu, 1)
  funcLuaCommand(433545986 --[[CMND_OPEN_MENU_OBJECT]], BBT.GM.MENU)
  S.gm_open = true
  BBT_Log("groups menu opened over", BBT_HOST.name, "page", S.gm_want)
end

-- the group page shown: the child menu opened, or asked to draw again when it is already up
function BBT_GroupsShow(page)
  local S = BBT_S
  S.gm_want = page
  if S.gm_open then
    pcall(funcLuaCommand, 830228314 --[[cross-menu call]], BBT.GM.MENU, "BBG_Redraw", page)
    return
  end
  BBT_GroupsStep()
end

-- the child closed (another page shown, the overlay closed)
function BBT_GroupsHide()
  local S = BBT_S
  S.gm_want = nil
  if S.gm_open then
    S.gm_open = false
    funcLuaCommand(320421347 --[[CMND_CLOSE_MENU_OBJECT]], BBT.GM.MENU)
    BBT_Log("groups menu closed")
  end
end

-- the second line of a plate: a results score, a group table row
function BBT_Line2(l2)
  if not l2 then
    return ""
  end
  if l2.key == "score_pen" then
    return string.format("%d (%s %d)", l2.n or 0, BBT_Text("pen"), l2.m or 0)
  elseif l2.key == "score_et" then
    return string.format("%d (%s)", l2.n or 0, BBT_Text("et"))
  elseif l2.key == "score" then
    return tostring(l2.n or 0)
  elseif l2.key == "group_pts" then
    return string.format("%d %s  %+d", l2.n or 0, BBT_Text("pts"), l2.m or 0)
  end
  return ""
end

function BBT_Title(v)
  local t = v.title or {}
  local key = t.key or ""
  if key == "md" or key == "groups" or key == "groups_md" then
    return BBT_TextValue(key, t.n or 0)
  end
  if key == "" then
    return BBT_Text("mode_tournament")
  end
  return BBT_Text(key)
end

function BBT_Outcome(v)
  if v.outcome == "champion" then
    return BBT_Text("champion")
  end
  if v.outcome == "out" and v.place then
    if v.place.stage == "groups" then
      return BBT_Text("out_groups")
    end
    return BBT_Text("out_ko_" .. tostring(v.place.from_end or 1))
  end
  return ""
end

-- 1.5.28 (owner): the champion screen. When a tournament is over (a champion and an outcome), its first opening
-- shows the WINNER (the player or a CPU team): the crest big in the centre, its name below, «¡CAMPEÓN!» above with
-- the crown; the crest scales in and the banner slides in (BBT_ChampStep, frame time); Enter = the final bracket
-- (then Enter closes the ended run as before). Drawn with the overlay's own layers: the champion's plate instance
-- (row_l BBT.ROW_CHAMP) with its plate hidden (only its crest, scaled), two texts, the crown quad.
BBT.CH = { EMB_S = 3.4, EMB_Y = 520, NAME_Y = 760, NAME_S = 1.3, BANNER_Y = 230, BANNER_S = 2.2, CROWN_Y = 330,
  CROWN_S = 2.2, DUR = 0.6, SLIDE = 700, TXT_BANNER = 0, TXT_NAME = 1 }
function BBT_ChampLayout(p)
  local G, C, L, H = BBT.G, BBT.C, BBT.L, BBT.CH
  local e = 1 - (1 - math.min(1, p)) ^ 3
  -- the crest: the plate's crest slot sits 22 .. 90 px from its left edge, 34 px under its top
  local s = math.max(0.05, H.EMB_S * e)
  local i = BBT.ROW_CHAMP
  funcLuaMenuCommand(C.SCALE, L.row_l, s, s, 1, i)
  funcLuaMenuCommand(C.POS, L.row_l, G.CX - 56 * s, -H.EMB_Y, 0, i)
  -- the banner slides in from the left, the name fades up with the crest
  local bx = G.CX - H.SLIDE * (1 - e)
  funcLuaMenuCommand(C.POS, L.txt, bx, -H.BANNER_Y, 0, H.TXT_BANNER)
  funcLuaMenuCommand(C.SCALE, L.txt, H.NAME_S * e, H.NAME_S * e, 1, H.TXT_NAME)
  local cs = H.CROWN_S * e
  funcLuaMenuCommand(C.SCALE, L.icon, G.CROWN_W * cs / G.Q, G.CROWN_H * cs / G.Q, 1, 0)
end

function BBT_ChampText(i, str, x, y, scale)
  local C, L = BBT.C, BBT.L
  BBT_Take(L.txt, i)
  funcLuaMenuCommand(C.VISIBLE, L.txt, i, true)
  funcLuaMenuCommand(C.POS, L.txt, x, -y, 0, i)
  funcLuaMenuCommand(C.SCALE, L.txt, scale, scale, 1, i)
  funcLuaMenuCommand(C.TEXT_STYLE, L.txt, i, BBT.TXT_ON, BBT.STYLE_TXT)
  funcLuaMenuCommand(C.TEXT, L.txt, BBT.TXT_ON, str, i)
  funcLuaMenuCommand(C.TEXT, L.txt, BBT.TXT_OFF, "", i)
  funcLuaMenuCommand(C.TEXT_VISIBLE, L.txt, BBT.TXT_ON, true, i)
  funcLuaMenuCommand(C.TEXT_VISIBLE, L.txt, BBT.TXT_OFF, false, i)
end

function BBT_ChampOpen(v)
  local C, L, H, G = BBT.C, BBT.L, BBT.CH, BBT.G
  BBT_S.view, BBT_S.page = v, v.page
  BBT_S.champ = { t = 0, team = v.champion }
  BBT_S.champ_done = true
  BBT_Begin()
  -- the crest: the champion's plate instance, plate and name hidden
  local i = BBT_Take(L.row_l, BBT.ROW_CHAMP)
  funcLuaMenuCommand(C.VISIBLE, L.row_l, i, true)
  for _, m in pairs(BBT.PLATE) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L.row_l, m, false, i)
  end
  funcLuaMenuCommand(C.TEXT_VISIBLE, L.row_l, BBT.TXT_ON, false, i)
  funcLuaMenuCommand(C.TEXT_VISIBLE, L.row_l, BBT.TXT_OFF, false, i)
  funcLuaMenuCommand(C.PRIM_COLOR, L.row_l, i, BBT.MESH_EMBLEM, 1, 1, 1)
  BBT_Alpha(L.row_l, i, 1)
  BBT_Emblem(L.row_l, i, v.champion)
  BBT_ChampText(H.TXT_BANNER, BBT_Text("champion_banner"), G.CX, H.BANNER_Y, H.BANNER_S)
  BBT_ChampText(H.TXT_NAME, BBT_TeamName(v.champion), G.CX, H.NAME_Y, H.NAME_S)
  BBT_Quad(L.icon, BBT.SPR_CROWN, G.CX, H.CROWN_Y, G.CROWN_W * H.CROWN_S, G.CROWN_H * H.CROWN_S, { 1, 1, 1 })
  BBT_End()
  BBT_ChampLayout(0)
  pcall(BBT_HOST.title, BBT_Text("champion"))
  funcLuaCommand(1917805374, 3848881948 --[[sy0000]])
  BBT_Log(string.format("champion screen: team 0x%08X (%s)", (v.champion or 0) % 4294967296,
    v.outcome == "champion" and "the player" or "a CPU team"))
  return true
end

-- the entrance animation, from Step (the frame time: Step runs faster than 60 / s in menus)
function BBT_ChampStep()
  local ch = BBT_S.champ
  if not ch or ch.t >= BBT.CH.DUR then
    return
  end
  local ok, dt = pcall(funcLuaCommand, 1549797111)
  if not ok or type(dt) ~= "number" or dt <= 0 or dt > 0.5 then
    dt = 1 / 60
  end
  ch.t = ch.t + dt
  BBT_ChampLayout(ch.t / BBT.CH.DUR)
end

-- animate (1.5.35): the tree's round just played walks to its new places (BBT_AnimStart); without it a redraw of the
-- page being animated keeps the walk going, any other page drops it
function BBT_Draw(page, animate)
  local v = BBT_Call(BBT.VIEW, page or -1)
  if type(v) ~= "table" or v.kind == "none" then
    BBT_Log("view unavailable", tostring(v))
    return false
  end
  -- 1.5.28: a finished tournament opens on its champion first (once per opening of the overlay)
  BBT_S.champ = nil
  if (v.champion or 0) ~= 0 and (v.outcome or "") ~= "" and not BBT_S.champ_done and (page == nil or page < 0) then
    BBT_S.anim = nil
    return BBT_ChampOpen(v)
  end
  BBT_S.view, BBT_S.page = v, v.page
  BBT_Begin()
  local ok, err = pcall(function()
    if v.kind == "tree" then
      BBT_DrawTree(v)
    elseif v.kind == "results" then
      BBT_DrawResults(v)
    end
  end)
  if not ok then
    BBT_Log("draw error", tostring(err))
  end
  BBT_End()
  -- 1.5.60: the group page = every group on one page in the group stage's own menu (this menu's pools all hidden)
  if v.kind == "groups" then
    BBT_GroupsShow(v.page)
  else
    BBT_GroupsHide()
  end
  if animate and v.kind == "tree" then
    local oka, erra = pcall(BBT_AnimStart, v)
    if not oka then
      BBT_S.anim = nil
      BBT_Log("advance error", tostring(erra))
    end
  elseif BBT_S.anim then
    if BBT_S.anim.page == v.page and v.kind == "tree" then
      pcall(BBT_AnimApply)
    else
      BBT_S.anim = nil
    end
  end
  -- 1.5.22: what this draw placed (once per draw), and the view's fields when it placed nothing
  local u = BBT_S.used or {}
  local L = BBT.L
  local placed = (u[L.row_l] or 0) + (u[L.row_r] or 0) + (u[L.line] or 0) + (u[L.txt] or 0)
  local keys = {}
  if placed == 0 then
    for k, x in pairs(v) do
      keys[#keys + 1] = tostring(k) .. ":" .. type(x) .. (type(x) == "table" and ("#" .. #x) or "")
    end
  end
  if v.kind == "groups" then
    keys = {}   -- the group page draws in its own menu (its log line: «groups menu open …»)
  end
  BBT_Log(string.format("bracket drawn n=%d on %s (kind %s, rounds %s; plates %d+%d, lines %d, texts %d)%s%s",
    placed, BBT_HOST.name, tostring(v.kind), tostring(v.rounds), u[L.row_l] or 0, u[L.row_r] or 0, u[L.line] or 0,
    u[L.txt] or 0, v.kind == "groups" and (" groups " .. #(v.groups or {}) .. " in evt_bbd_tn_groups_menu") or "",
    #keys > 0 and (" view: " .. table.concat(keys, " ")) or ""))
  -- the title in the menu's own header: the page; after the run, its end
  local title = BBT_Title(v)
  local tail = BBT_Outcome(v)
  if tail ~= "" then
    title = title .. "  ·  " .. tail
  end
  pcall(BBT_HOST.title, title)
  return true
end

function BBT_Open(page)
  if BBT_S.open then
    return BBT_Draw(page)
  end
  BBT_S.open = true
  BBT_S.emb = {}
  BBT_S.prio = {}
  local H = BBT_HOST
  BBT_SwitchLayers(H.close, false)
  BBT_ShowLayers(H.hide, false)
  for _, l in ipairs(H.lists or {}) do
    funcLuaMenuCommand(3518307824 --[[CMND_SET_ENABLE_CTRL_FOCUS?]], l, false)
  end
  bbt_open_layer(BBT.L.bg, 0)
  local G = BBT.G
  local sy = (G.BG_BOTTOM - G.BG_TOP) / G.BG_H
  funcLuaMenuCommand(BBT.C.SCALE, BBT.L.bg, 1, sy, 1, 0)
  funcLuaMenuCommand(BBT.C.POS, BBT.L.bg, 0, -(G.BG_TOP - G.BG_Y * sy), 0, 0)
  -- every instance opened once, hidden until a page draws it (each draw shows what it uses, hides the rest)
  BBT_EachInstance(function(l, i)
    bbt_open_layer(l, i)
    BBT_Hide(l, i)
  end)
  bbt_open_layer(BBT.ANCHOR, 0)
  -- 1.5.20: the anchor is a button object; on «Modos de juego» it showed at the top left (a teal box over the
  -- header): placed off screen and invisible, it keeps the keys
  funcLuaMenuCommand(BBT.C.POS, BBT.ANCHOR, -4000, 4000, 0, 0)
  funcLuaMenuCommand(BBT.C.VISIBLE, BBT.ANCHOR, 0, false)
  funcLuaMenuCommand(3518307824 --[[CMND_SET_ENABLE_CTRL_FOCUS?]], BBT.ANCHOR, true)
  funcLuaMenuCommand(1778826357, BBT.ANCHOR, 0, true)
  if not BBT_Draw(page) then
    BBT_Close()
    return false
  end
  pcall(BBT_Diag, "open")
  return true
end

-- 1.5.20 diagnostics (owner: the bracket not seen on «Modos de juego»): per layer, the instances the menu created,
-- whether instance 0 is open and how many this draw used; the background's state
-- 1.5.21: one string (the log command keeps only its first 8 arguments), + the visibility / global position the
-- engine reports for instance 0 (the VRFW input trace's own commands)
function BBT_Diag(when)
  local parts = {}
  for k, l in pairs(BBT.L) do
    local n = funcLuaMenuCommand(1175615627 --[[CMND_GET_CREATE_LAYER_NUM?]], l)
    local open = funcLuaMenuCommand(2640875187 --[[CMND_IS_OPEN_LAYER]], l, 0, BBT_HOST.menu)
    local okv, vis = pcall(funcLuaMenuCommand, 1262717583 --[[is visible]], l, 0)
    local okp, gx, gy = pcall(funcLuaMenuCommand, 4002164178 --[[global pos]], l, 0)
    parts[#parts + 1] = string.format("%s n=%s open0=%s vis0=%s pos0=%s,%s used=%s", k, tostring(n), tostring(open),
      tostring(okv and vis), tostring(okp and gx), tostring(okp and gy), tostring(BBT_S.used and BBT_S.used[l]))
  end
  local v = BBT_S.view or {}
  BBT_Log(string.format("bracket %s on %s: kind %s page %s | %s", when, BBT_HOST.name, tostring(v.kind),
    tostring(v.page), table.concat(parts, "; ")))
end

function BBT_Close()
  BBT_S.champ, BBT_S.champ_done, BBT_S.anim = nil, false, nil
  BBT_GroupsHide()   -- 1.5.60: the group stage's own menu
  BBT_EachInstance(function(l, i)
    bbt_close_layer(l, i)
  end)
  bbt_close_layer(BBT.L.bg, 0)
  bbt_close_layer(BBT.ANCHOR, 0)
  BBT_S.emb = {}
  funcLuaMenuCommand(3518307824 --[[CMND_SET_ENABLE_CTRL_FOCUS?]], BBT.ANCHOR, false)
  BBT_S.open = false
  local H = BBT_HOST
  BBT_SwitchLayers(H.close, true)
  BBT_ShowLayers(H.hide, true)
  H.header()
  H.refocus()
end

-- 1.5.33 (owner 2026-10-13): the round's results show ONCE, right after the match (Enter = the bracket); everywhere
-- else (the Torneo panel, «Continuar», «Ver el cuadro», L1 / R1 from a bracket page) the bracket. Page ids
-- (scripts/lib/tourney_view.lua): results >= BBT_RESULTS_PAGE, then the group pages, the tree.
BBT_RESULTS_PAGE = 20

-- the bracket page of a view: the tree when the knockout is drawn, else the first group page; nil when none
function BBT_BracketPageOf(v)
  local first
  for _, p in ipairs(v.pages or {}) do
    if p < BBT_RESULTS_PAGE then
      if p == 0 then
        return 0
      end
      first = first or p
    end
  end
  return first
end

-- the page an entry opens on: -1 (the view's own first page) unless that is the results page; the champion
-- screen of an ended run still comes first (its Enter goes to the tree)
function BBT_EntryPage()
  local v = BBT_Call(BBT.VIEW, -1)
  if type(v) ~= "table" or v.kind ~= "results" then
    return -1
  end
  if (v.champion or 0) ~= 0 and (v.outcome or "") ~= "" then
    return -1
  end
  return BBT_BracketPageOf(v) or -1
end

function BBT_Turn(d)
  local v = BBT_S.view
  if not v or not v.pages then
    return
  end
  -- from a bracket page the results page is not among the pages turned to
  local pages = {}
  for _, p in ipairs(v.pages) do
    if p < BBT_RESULTS_PAGE or (BBT_S.page or 0) >= BBT_RESULTS_PAGE then
      pages[#pages + 1] = p
    end
  end
  if #pages < 2 then
    return
  end
  local k = 1
  for i, p in ipairs(pages) do
    if p == BBT_S.page then
      k = i
    end
  end
  k = (k - 1 + d) % #pages + 1
  funcLuaCommand(1917805374, 3848881948 --[[sy0000]])
  BBT_Draw(pages[k])
end

-- the next match: the round's rulebook selected, then the retail campaign «continue» (the Campaña row's branch 0)
function BBT_PlayNext()
  -- 1.5.5: the Campaña's block kept, the tournament's match written into it (CMND_BBD_TOURN_PREPARE)
  local prep = BBT_Call(BBT.PREPARE)
  if type(prep) ~= "table" or not prep.ok then
    BBT_Log("next match: not prepared", type(prep) == "table" and "refused" or "busy")
    funcLuaCommand(1917805374, 2086672038 --[[sy0003]])
    return
  end
  pcall(funcLuaCommand, BBT.RULE_SELECT, prep.rules or "")
  BBT_Close()
  funcLuaCommand(1917805374, 3848881948 --[[sy0000]])
  local ret = funcLuaMenuCommand(2227512519)
  BBT_Log("next match requested", tostring(ret), prep.rules or "")
  if not ret then
    BBT_Call(BBT.UNLOAD)
  end
  if ret then
    -- the host's mark for the way back (Modos de juego: the engine reopens it on the Torneo tile)
    pcall(BBT_HOST.before_match)
    funcLuaMenuCommand(1558704558, BBT_HOST.menu, false)
    if type(BrightFadeAllMenu) == "function" then
      BrightFadeAllMenu(3578114327 --[[fade_menu_encount_campaign]], true)
    end
    funcLuaCommand(769636339, 0.5)
    if BBT_HOST.menu ~= 811496143 then
      funcLuaCommand(320421347 --[[CMND_CLOSE_MENU_OBJECT]], BBT_HOST.menu, true)
    end
    funcLuaCommand(320421347 --[[CMND_CLOSE_MENU_OBJECT]], 811496143 --[[soccer_top_menu]])
  end
end

function BBT_OnEnter()
  -- 1.5.35: Enter during the bracket's advance = its end at once (the next Enter goes on)
  if BBT_S.anim then
    BBT_AnimFinish("skipped")
    return
  end
  if BBT_S.champ then
    -- the champion screen: Enter = the final bracket (the tree page)
    BBT_S.champ = nil
    funcLuaCommand(1917805374, 3848881948 --[[sy0000]])
    local v = BBT_S.view or {}
    BBT_Draw(v.pages and v.pages[#v.pages] or 0, true)
    return
  end
  local v = BBT_S.view or {}
  -- 1.5.33: on the results page (after a match) Enter = the bracket, updated with the round's winners
  if v.kind == "results" then
    local p = BBT_BracketPageOf(v)
    if p ~= nil then
      funcLuaCommand(1917805374, 3848881948 --[[sy0000]])
      BBT_Draw(p, true)
      BBT_Log("results -> bracket page", p)
      return
    end
  end
  if v.watching then
    -- eliminated: the next remaining round, simulated now, its results first
    local r = BBT_Call(BBT.STEP)
    funcLuaCommand(1917805374, 3848881948 --[[sy0000]])
    if type(r) == "table" and r.event == "step" then
      BBT_Draw(-1)
      return
    end
  end
  if v.outcome ~= nil and v.outcome ~= "" then
    BBT_Call(BBT.CLOSE)
    funcLuaCommand(1917805374, 3848881948 --[[sy0000]])
    BBT_Close()
    return
  end
  if (v.next or 0) ~= 0 then
    BBT_S.co = coroutine.create(BBT_PlayNext)
    return
  end
  BBT_Close()
end

-- ------------------------------------------------------------------------------------------------ the entry

-- the «Torneo» row decided (bbt_row.lua; the «Modos de juego» tile or the top bar step): with a run, continue / new
-- (1.5.17, owner: a new tournament even while one runs, after a Yes / No; an ended run: view / new); else (1.5.4,
-- owner's flow) the tournament is armed with the defaults and the Campaña grid opens
-- (1.5.5: through the 1P row's path with the Campaña variant, whether a Campaña runs or not): the team first (the Draft tile
-- too), then the options panel (bbt_grid.lua: group stage, teams, the knockout rules), then the difficulty window; its
-- start draws the tournament (no match starts), and back here the bracket shows the first round: Enter = match 1.
-- Runs in the decide coroutine.
function BBT_EntryTournament()
  BBT_S.entry = true
  local ok, err = pcall(BBT_EntryFlow)
  BBT_S.entry = false
  if not ok then
    error(err, 0)
  end
end

-- 1.5.18 (owner): the Torneo panel. A run (or an ended one): the bracket opens and the window comes centred over it,
-- «Continuar el torneo» (the next match, or the next simulated round once out) / «Ver el cuadro» (the bracket stays,
-- its keys) / «Nuevo torneo» (Yes / No while one runs; No = the window again); Back = both closed, the player where he
-- was. No run: a new one at once (the team grid).
function BBT_EntryFlow()
  while true do
    local info = BBT_Info()
    if not (info.active or info.ended) then
      return BBT_NewRun()
    end
    BBT_Open(BBT_EntryPage())
    local cont, view, new = BBT_Id("continue"), BBT_Id("view"), BBT_Id("new")
    local ids = { cont, view, new }
    if not info.active then
      ids = { view, new }
    end
    -- 1.5.20: the host menu's input is never switched (1.5.19 did: no effect, and it disturbs the engine's input)
    local c = BBT_Choose(ids, 0)
    local id = ids[c + 1]
    if c < 0 or id == nil then
      if BBT_S.open then
        funcLuaCommand(1917805374, 202039849 --[[sy0006]])
        BBT_Close()
      end
      return
    end
    if id == cont then
      BBT_OnEnter()
      return
    end
    if id == view then
      return -- the bracket stays up: L1 / R1 pages, Enter = the next match, Back closes
    end
    -- «Nuevo torneo»: a running one is dropped only after a Yes (its Campaña block back, as «Abandonar» did); an
    -- ended one is put aside as its last screen would
    -- 1.5.20 (owner, 1.5.18 / 1.5.19 logs): a retail general window (Yes / No) opened over «Modos de juego» never
    -- takes its answer (the BB Campaña's «Partida nueva» question neither); the question is the same centred
    -- window as the panel instead: «Sí, empezar de cero» / «No, volver», cursor on No
    local go = true
    if info.active then
      local a = BBT_Choose({ BBT_Id("new_yes"), BBT_Id("new_no") }, 1)
      go = a == 0
      BBT_Log("new tournament: answer", go and "yes" or "no", a)
    end
    if go then
      if info.active then
        BBT_Call(BBT.ABANDON)
        BBT_Log("new tournament: the running one abandoned")
      else
        BBT_Call(BBT.CLOSE)
        BBT_Log("new tournament: the ended one put aside")
      end
      pcall(funcLuaCommand, BBT.RULE_SELECT, "")
      if BBT_S.open then
        BBT_Close()
      end
      return BBT_NewRun()
    end
  end
end

-- a new tournament: armed with the defaults, the team grid (the host's way: this menu's 1P path with the Campaña
-- variant, or «Modos de juego»'s own grid), back from it the bracket of the first round (or disarmed)
function BBT_NewRun()
  local armed, why = BBT_Call(BBT.ARM, -1, 0, 0)
  if armed ~= true then
    BBT_Log("not armed", tostring(armed), tostring(why))
    return
  end
  -- 1.5.5: the grid opens through the 1P row's own path (no «Campaña in progress» window: the Torneo is independent
  -- of the Campaña), its menu variant swapped to the Campaña's (BBT_OpenGridAsCampaign, 1.5.7: at run time);
  -- 1.5.18: the host's way (BBT_HOST.open_grid)
  BBT_Log("new tournament: armed, team grid opens on", BBT_HOST.name)
  BBT_S.newrun = true
  local okg, errg = pcall(BBT_HOST.open_grid)
  BBT_S.newrun = false
  if not okg then
    error(errg, 0)
  end
  BBT_Log("new tournament: team grid closed")
  -- back from the grid: a started tournament shows its bracket (the first round); else the armed one goes
  local i3 = BBT_Info()
  if i3.active then
    BBT_Open(BBT_EntryPage())
  elseif i3.armed then
    BBT_Call(BBT.DISARM)
  end
end

-- the «Campaña» row of the list: (layer, index, rows), nil when not listed
function BBT_CampaignRow()
  for _, l in ipairs({ BBT.LIST_MID, BBT.LIST_SMALL }) do
    local n = GetNumUsedButtons(l) or 0
    for i = 0, n - 1 do
      local info = GetLitItemInfo(l, i)
      if info ~= nil and info.menuObjectName == BBT.ROW_CAMPAIGN then
        return l, i, n
      end
    end
  end
  return nil
end

-- decide the «Campaña» row in a coroutine (as the hub's own decide runs): mode "tournament" (the top bar's Torneo,
-- the header selector's Torneo after the grid) or "campaign" (the header selector's Campaña over the Torneo)
function BBT_DecideCampaignRow(mode)
  local l, i, n = BBT_CampaignRow()
  if l == nil then
    BBT_Log("no Campaña row in the list:", mode)
    return false
  end
  BBT_S.row_mode = mode
  funcLuaMenuCommand(1778826357, l, i, true)
  funcLuaMenuCommand(381797568 --[[CMND_SET_CURSOR_LOCATOR?]], l, 3313461902 --[[cursor]], i, n)
  pcall(SelectListItem, l)
  BBT_S.co = coroutine.create(function()
    OnDecideFocus(l, i)
  end)
  BBT_Log("Campaña row decided in mode", mode)
  return true
end

-- the top bar step (Battle Bay › Torneo): the Campaña row in Torneo mode
function BBT_DecideRow()
  BBT_DecideCampaignRow("tournament")
end

-- ------------------------------------------------------------------------------------------------ the mode selector
-- (bbt_mode.lua draws it; this menu's side: «Torneo» lit while the bracket / its panel is up)

-- «Campaña» picked over the Torneo: the panel (its coroutine ends as a cancel) and the bracket closed, then the
-- «Campaña» row decided in Campaña mode once the menu has its focus back (BBT_ModeAfterStep)
function BBT_ModeToCampaign()
  local S = BBT_S
  S.after_grid, S.frames_after = "campaign", 0
  if funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT?]], BBT.SUB_WINDOW) == true then
    BBT_ChooseClose()
  end
  if S.anim then
    BBT_AnimFinish("mode switch")
  end
  S.champ = nil
  if S.open then
    BBT_Close()
  end
  funcLuaCommand(1917805374, 3791946501 --[[sy0004]])
  BBT_Log("mode: Torneo -> Campaña")
end

-- the team grid (enjoy_team_select_menu) seen open, then closed: what the grid left for this menu. Only for a grid
-- this file did not open itself (BBT_NewRun shows its own bracket): the header's «Torneo» with a run (parameter
-- evt_bbd_mode_go_tournament) = the Torneo here; a tournament started in it = its bracket; an armed leftover disarmed.
BBT_MODE_P_GO_T = @crc:evt_bbd_mode_go_tournament@
function BBT_ModeAfterGrid()
  local S = BBT_S
  local exists = funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT?]], 786045682 --[[enjoy_team_select_menu]]) == true
  if exists then
    if not S.grid_seen then
      S.grid_seen = true
      S.grid_own = S.newrun == true
      S.grid_active = BBT_Info().active == true
    end
    return
  end
  if not S.grid_seen then
    return
  end
  S.grid_seen = false
  if S.grid_own then
    return
  end
  local ok, has = pcall(funcLuaCommand, 2947612279 --[[param has]], BBT_MODE_P_GO_T)
  if ok and has == true then
    pcall(funcLuaCommand, 3363400568 --[[param delete]], BBT_MODE_P_GO_T)
    S.after_grid, S.frames_after = "tournament", 0
    BBT_Log("grid closed: the Torneo asked from its header")
    return
  end
  local info = BBT_Info()
  if info.active and not S.grid_active then
    S.after_grid, S.frames_after = "bracket", 0
    BBT_Log("grid closed: a tournament started in it, its bracket")
  elseif info.armed then
    BBT_Call(BBT.DISARM)
    pcall(funcLuaCommand, BBT.RULE_SELECT, "")
  end
end

-- what waits for the menu's focus after a grid / a mode switch
function BBT_ModeAfterStep()
  local S = BBT_S
  if S.after_grid == nil or S.co ~= nil or S.open or S.entry then
    return
  end
  S.frames_after = (S.frames_after or 0) + 1
  if S.frames_after > 600 then
    BBT_Log("mode: gave up waiting for the menu:", S.after_grid)
    S.after_grid = nil
    return
  end
  if S.frames_after < 6 or not BBT_HOST.ready() or funcLuaCommand(1215256347 --[[CMND_BRIGHT_IS_FADE]]) == true
    or funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT?]], BBT.SUB_WINDOW) == true then
    return
  end
  local what = S.after_grid
  S.after_grid = nil
  if what == "bracket" then
    BBT_Open(BBT_EntryPage())
  elseif what == "tournament" or what == "campaign" then
    BBT_DecideCampaignRow(what)
  end
end

-- bbt_mode.lua's Step hook in this menu: the grid watch, the waiting switch. The selector is never shown here (owner
-- 2026-10-13: only on the team-select grid before a run starts; a Torneo up here is a run in progress): kept hidden
function BBT_ModeTopStep()
  if BBT_HOST.name ~= "bb_stadium_top_menu" then
    return
  end
  local S = BBT_S
  BBT_ModeAfterGrid()
  BBT_ModeAfterStep()
  -- 1.5.57: the selector's layers are no longer in this menu (the grid's own only): nothing drawn here
  BBT_ModePoll(false)   -- keeps the key / click edges current
end

-- 1.5.57 diagnosis (the white Battle Bay top menu of 2026-10-13: the menu past the engine's layer instance limit never
-- finished opening). Once per opening, BBT_SETUP_FRAMES Steps after OnInit: the instances the engine created of each
-- overlay pool (CMND_GET_CREATE_LAYER_NUM) against the menu file's counts, whether the background
-- (mainmenu90_00_background) is open and whether the screen is still covered by a fade (2259183189). A short pool
-- or «covered true» = the menu is still too big.
BBT_SETUP_FRAMES = 180
function BBT_SetupCheck()
  if BBT_HOST.name ~= "bb_stadium_top_menu" then
    return
  end
  local parts, short = {}, 0
  for k, n in pairs(BBT.N) do
    local got = funcLuaMenuCommand(1175615627 --[[CMND_GET_CREATE_LAYER_NUM?]], BBT.L[k])
    got = type(got) == "number" and got or -1
    if got < n then
      short = short + 1
    end
    parts[#parts + 1] = string.format("%s %d/%d", k, got, n)
  end
  table.sort(parts)
  local bg = funcLuaMenuCommand(2640875187 --[[CMND_IS_OPEN_LAYER]], 367379312 --[[mainmenu90_00_background]], 0)
  local covered = funcLuaCommand(2259183189) == true
  BBT_Log(string.format("top menu setup: %s; background open %s, covered %s (%s)", table.concat(parts, ", "),
    tostring(bg), tostring(covered), (short > 0 or covered) and "STUCK? pools short or screen covered" or "ok"))
end

-- ------------------------------------------------------------------------------------------------ wraps

do
  local init = OnInit
  function OnInit(...)
    BBT_S.setup_frames = 0
    local ok, done = pcall(BBT_Sync)
    if not ok then
      BBT_Log("sync error", tostring(done))
    elseif not done then
      BBT_S.sync, BBT_S.sync_frames = true, 0   -- the scripts were busy: again from Step
    end
    -- the top bar's «Battle Bay» group row «Torneo» (content\menus\top_bar.toml): the title's Estadio BB request with
    -- the step bb_tournament; answered here: the «Campaña» row decided in Torneo mode once the list is ready (Step)
    if BBT_HOST.step ~= nil and type(VRFW_TopBarStep) == "function" then
      local oks, go = pcall(VRFW_TopBarStep, BBT_HOST.step)
      if oks and go then
        BBT_S.step, BBT_S.frames, BBT_S.want = true, 0, false
        BBT_Log("top bar step: the Campaña row in Torneo mode")
      end
    end
    return init(...)
  end

  local decide = OnDecideFocus
  function OnDecideFocus(a1, a2, ...)
    if BBT_S.open then
      if a1 == BBT.ANCHOR then
        BBT_OnEnter()
      end
      return 1
    end
    -- 1.5.47: the «Campaña» row opens the Campaña screen in Torneo mode when a tournament runs (or ended, not shown
    -- yet) or the top bar / the header asked for the Torneo; else the retail Campaña (its header switches there)
    if (a1 == BBT.LIST_MID or a1 == BBT.LIST_SMALL) and BBT_HOST.name == "bb_stadium_top_menu" then
      local okl, info = pcall(GetLitItemInfo, a1, a2)
      if okl and info ~= nil and info.menuObjectName == BBT.ROW_CAMPAIGN then
        local mode = BBT_S.row_mode
        BBT_S.row_mode = nil
        local t = mode == "tournament"
        if mode == nil then
          local ti = BBT_Info()
          t = ti.active == true or ti.ended == true
        end
        if t then
          funcLuaCommand(1917805374, 3848881948 --[[sy0000]])
          local ok, err = pcall(BBT_EntryTournament)
          if not ok then
            BBT_Log("entry error", tostring(err))
          end
          return 1
        end
        pcall(funcLuaCommand, 3363400568 --[[param delete]], BBT_MODE_P_GO_T)
      end
    end
    return decide(a1, a2, ...)
  end

  local back = OnBack
  function OnBack(a1, ...)
    if BBT_S.open then
      funcLuaCommand(1917805374, 202039849 --[[sy0006]])
      BBT_Close()
      return 1
    end
    return back(a1, ...)
  end

  local fn = OnFunction
  function OnFunction(a1, a2, ...)
    if BBT_S.open then
      if a1 == BBT.FN_PREV then
        BBT_Turn(-1)
      elseif a1 == BBT.FN_NEXT then
        BBT_Turn(1)
      end
      return 1
    end
    return fn(a1, a2, ...)
  end

  local step = Step
  function Step(...)
    local r = { step(...) }
    local S = BBT_S
    if S.setup_frames ~= nil then
      S.setup_frames = S.setup_frames + 1
      if S.setup_frames >= BBT_SETUP_FRAMES then
        S.setup_frames = nil
        local okc, errc = pcall(BBT_SetupCheck)
        if not okc then
          BBT_Log("setup check error", tostring(errc))
        end
      end
    end
    if S.open and S.champ then
      pcall(BBT_ChampStep)
    end
    -- 1.5.60: the group stage's own menu, once an earlier one finished closing
    if S.gm_want ~= nil and not S.gm_open then
      local okg, errg = pcall(BBT_GroupsStep)
      if not okg then
        S.gm_want = nil
        BBT_Log("groups menu error", tostring(errg))
      end
    end
    if S.open and S.anim then
      local oka, erra = pcall(BBT_AnimStep)
      if not oka then
        S.anim = nil
        BBT_Log("advance error", tostring(erra))
      end
    end
    -- 1.5.33: a bracket layer set up after the bracket opened (bbt_hub.lua OnSetupLayer hid it): the page again
    if S.redraw then
      S.redraw = false
      if S.open and not S.champ then
        local ok, err = pcall(BBT_Draw, S.page)
        BBT_Log("late layer setup: page drawn again", S.page, ok and "" or tostring(err))
      end
    end
    if S.sync then
      S.sync_frames = S.sync_frames + 1
      local ok, done = pcall(BBT_Sync)
      if (ok and done) or S.sync_frames > 600 then
        S.sync = false
      end
    end
    if S.co ~= nil then
      local ok, err = coroutine.resume(S.co)
      if not ok then
        BBT_Log("error", tostring(err))
      end
      if not ok or coroutine.status(S.co) == "dead" then
        S.co = nil
      end
    elseif S.step and not S.open then
      S.frames = S.frames + 1
      if S.frames > 600 then
        S.step = false
      elseif S.frames > 20 and funcLuaMenuCommand(102308320 --[[CMND_IS_CTRL_FOCUS_ACTIVE?]], BBT.LIST_MID) == true
        and funcLuaCommand(1215256347 --[[CMND_BRIGHT_IS_FADE]]) ~= true then
        S.step = false
        local ok, err = pcall(BBT_DecideRow)
        if not ok then
          BBT_Log("top bar step error", tostring(err))
        end
      end
    elseif S.want and not S.open then
      S.frames = S.frames + 1
      -- 1.5.27 (owner: «Modos de juego» seen 1-2 s before the results): on a host with `cover` the screen stays black
      -- until the bracket is up (the wait was 20 Steps + the hub's own 0.5 s fade-in + its focus); then one fade-in
      local cover = BBT_HOST.cover == true
      if cover then
        funcLuaCommand(609722083 --[[fade black]], 1, 0)
      end
      if S.frames > 600 then
        S.want = false
        if cover then
          funcLuaCommand(609722083, 0, 0.3)
        end
      elseif S.frames > (cover and 2 or 20) and BBT_HOST.ready()
        and (cover or funcLuaCommand(1215256347 --[[CMND_BRIGHT_IS_FADE]]) ~= true) then
        S.want = false
        local ok, err = pcall(BBT_Open, -1)
        if not ok then
          BBT_Log("overlay error", tostring(err))
        end
        if cover then
          funcLuaCommand(609722083, 0, 0.3)
          BBT_Log("results shown under the cover after", S.frames, "Steps")
        end
      end
    end
    return table.unpack(r)
  end
end
