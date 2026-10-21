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
--   * 2026-10-19 (owner): a knockout of exactly 16 teams on the Victory Road «決勝トーナメント» art (the retail vroad04_*
--     objects as this menu's layers: the tree base, the 16 gold path strips lit by their «move» rate, the stars, the
--     trophy, the per-round scores, the schedule panel with the round and the player's next match): BBT_DrawRetail;
--     the stadium of the final in a box at the bottom of every tree page (BBT_DrawStadium).
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
  stadium = @crc:vroad01_00_background@,   -- 1.8.0: the Victory Road stadium (opaque) behind the band
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
-- 1.8.0: box 36 (the stadium's dim + a results page's 32 score boxes, or on a tree the dim, the player's focus
-- band, the stars at the joints (at most 32), the final stadium's panel and picture: at most 36). 1.9.0: the scores
-- are digit sprites on the connector pool (BBT.NUM): line 256 -> 330 (1.12.0; a 64-team tree: 251 pieces + 62 pairs + the
-- final's 2 digits + shoot-outs; a results page: its digits only), txt 66 -> 4 (the final stadium's two lines, the
-- champion screen's two)
BBT.N = { line = 330, row_l = 33, row_r = 32, txt = 4, icon = 1, box = 36, crest = 32 }
-- draw priority of a connector-pool quad by what it draws (the layer's own is the connectors' 549; a score box drawn
-- on it where the menu has no box pool: 552, BBT.SHARE)
BBT.PRIO = { line = 549, box = 552 }
-- 1.5.58: a pool this menu does not have (BBT.N[k] = 0) drawn on another pool of the same object, at its own draw
-- priority (BBT.PRIO[k]): { box = "line" } on «Modos de juego» (bbt_hub.lua BBT_HOST.share; the layer budget). None
-- here: this menu has every pool
BBT.SHARE = {}
BBT.ROW_CHAMP = 32                 -- row_l instance of the champion's plate
BBT.ART = 2658588602               -- crc32("#/menu/220_img/bbd_tn/bbd_tn.g4tx"): the mod's drawings
-- 1.12.0: the score digits' own atlas (a g4tx holds at most 255 sprites; 1.9.0 had them all in bbd_tn: 275, and the
-- game crashed loading it): crc32("#/menu/220_img/bbd_tn_num/bbd_tn_num.g4tx")
BBT.ART_NUM = 1494349866
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
-- 1.8.0 (owner 2026-10-21: the bracket in the Victory Road look; research/scripts/bbd_bracket_art.py): a lit piece is
-- a white core with a halo across its thickness, one sprite per direction (gold; the player's own path cyan); the
-- unlit pieces navy (bbd_tn_line_plain), a lost way dark (out / out_me)
BBT.SPR_HALO = {
  lit = { h = @crc:bbd_tn_lit_h@, v = @crc:bbd_tn_lit_v@ },
  me = { h = @crc:bbd_tn_me_h@, v = @crc:bbd_tn_me_v@ },
}
BBT.SPR_STAR = @crc:bbd_tn_star@      -- the glow at the joint a team waits at (the Victory Road star)
BBT.SPR_FOCUS = @crc:bbd_tn_focus@    -- the player's focus band behind his plate
BBT.SPR_PANEL = @crc:bbd_tn_panel@    -- the final stadium's translucent panel
BBT.SPR_DIM = @crc:bbd_tn_dim@        -- the Victory Road stadium dimmed under a page (one box-pool quad)
-- the team strips in the order of scripts/lib/plate_colors.lua M.names (a plate's .strip = its 1-based index): the
-- list plate's own sprite (list_base_xs01_off of team06_02.g4tx) swapped for the team's strip (CMND 558735651)
BBT.SPR_STRIP = {
  @crc:bbd_tn_strip_red@, @crc:bbd_tn_strip_orange@, @crc:bbd_tn_strip_yellow@, @crc:bbd_tn_strip_green@,
  @crc:bbd_tn_strip_cyan@, @crc:bbd_tn_strip_blue@, @crc:bbd_tn_strip_purple@, @crc:bbd_tn_strip_pink@,
  @crc:bbd_tn_strip_black@, @crc:bbd_tn_strip_silver@,
}
BBT.PLATE_SPRITE = @crc:list_base_xs01_off@
BBT.PLATE_ATLAS = 143680280            -- crc32("#/menu/102_team/team06/team06_02/team06_02.g4tx")
BBT.WHITE = { 1, 1, 1 }
BBT.MESH_QUAD = 312193881 --[[_icon_new01]]
BBT.NODE_QUAD = 1909474081 --[[icon_new01]]
-- 1.9.0 (owner 2026-10-21, on a crop of the Victory Road bracket: «Deberían verse así los resultados»): a played
-- match's result is the two entrants' goals STACKED just past its joint, the upper entrant's over the lower's with the
-- joint's outgoing line between them, the winner's gold and the loser's dark: one connector-pool quad showing a pair
-- sprite bbd_tn_pr_<upper>_<lower>_<winner 1 / 2> (a number of two digits: single digits above / below); a
-- shoot-out: the kicks as smaller digits beside each; the final: the two goals left / right below the centre; the
-- results page: single digits in its boxes (research/scripts/bbd_bracket_art.py draws them; W / H / GAP / PAIR_H =
-- its DIGIT_W / DIGIT_H / PAIR_GAP / PAIR_H). HEIGHT = a digit's height of the plates' pitch (H_MIN .. H_MAX px),
-- SPACE = the gap from the joint (digit units), ADV = a digit's advance in a row, PRIO = in front of the connectors
BBT.NUM = { W = 22, H = 29, GAP = 20, PAIR_H = 78, HEIGHT = 0.55, H_MIN = 13, H_MAX = 26, SPACE = 4, ADV = 0.78,
  PEN_S = 0.75, FINAL_S = 1.3, BOX_FILL = 0.72, PRIO = 548 }
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
  SCALE_MAX = 1.0, GAP = 16, Q = 36, LINE = 4, LINE_LIT = 10, CHAMP_Y = 176, CHAMP_S = 0.85, CROWN_W = 72,
  CROWN_H = 54, SCORE_DY = 18, TXT_MIN = 0.62, TXT_MAX = 0.9,
  -- 1.8.0: the trophy's centre on the generic tree (the retail trophy in place of the crown, BBT_TrophyPlace); a
  -- star's size = STAR of the plates' pitch (STAR_MIN .. STAR_MAX px); the focus band = FOCUS_W x FOCUS_H of the plate
  TROPHY_Y = 300, STAR = 1.8, STAR_MIN = 32, STAR_MAX = 64, FOCUS_W = 1.2, FOCUS_H = 1.7,
  COL = { 0.66, 0.78, 0.95 }, COL_LIT = { 1.0, 0.80, 0.24 }, DIM = 0.5,
  -- the Victory Road background (vroad04_01_p1: one translucent navy panel, 2004 x 724 at y 178 below its origin)
  -- stretched to hold the whole bracket: BG_TOP .. BG_BOTTOM
  BG_Y = 178, BG_H = 724, BG_TOP = 100, BG_BOTTOM = 1036,
  PRIO_STADIUM = 560,                    -- 1.8.0: the Victory Road stadium behind the bracket (BBT_Open)
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
-- instance (1.5.58: a score box on a host without a box pool, BBT.SHARE; nil = the connectors' own); atlas = another
-- loaded atlas than the mod's drawings (crc32 of its path; the final stadium's thumbnail)
function BBT_Quad(layer, spr, x, y, w, h, col, prio, atlas)
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
  funcLuaMenuCommand(C.SPRITE, layer, atlas or BBT.ART, spr, BBT.NODE_QUAD, 0, i)
  funcLuaMenuCommand(C.POS, layer, x, -y, 0, i)
  funcLuaMenuCommand(C.PRIM_COLOR, layer, i, BBT.MESH_QUAD, col[1], col[2], col[3])
  return i
end

-- an axis-aligned connector piece from (x0, y0) to (x1, y1); lit = on the winners' path (thicker); st = its state
-- (BBT.SPR_STATE: plain / lit / me / out / out_me; default lit or plain), drawn as that state's coloured quad; 1.8.0:
-- a lit / me piece is its direction's halo sprite (BBT.SPR_HALO)
function BBT_Seg(x0, y0, x1, y1, lit, st)
  local G = BBT.G
  local t = lit and G.LINE_LIT or G.LINE
  local w, h
  if y0 == y1 then
    w, h = math.abs(x1 - x0) + t, t
  else
    w, h = t, math.abs(y1 - y0) + t
  end
  local look = st or (lit and "lit" or "plain")
  local halo = BBT.SPR_HALO[look]
  local spr = halo and halo[y0 == y1 and "h" or "v"] or BBT.SPR_STATE[look] or BBT.SPR_LINE
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
  return i
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
  -- 1.8.0: a team plate (and the player's: his focus band marks him) is the team's strip with the name in white
  local strip = not champ and BBT.SPR_STRIP[tonumber(p.strip) or 0] or nil
  if strip then
    look = "off"
  end
  BBT_PlateStrip(l, i, look == "off" and strip or nil)
  local white = look ~= "off" or strip ~= nil
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

-- 1.8.0: the plate's own sprite (list_base_xs01_off) swapped for a team strip of the mod's atlas, or back to the
-- list plate (spr nil); once per instance and sprite while the overlay is open (BBT_S.strip, reset at every opening)
function BBT_PlateStrip(l, i, spr)
  BBT_S.strip = BBT_S.strip or {}
  local k = tostring(l) .. ":" .. i
  local want = spr or false
  if BBT_S.strip[k] == want then
    return
  end
  BBT_S.strip[k] = want
  if spr then
    pcall(funcLuaMenuCommand, BBT.C.SPRITE, l, BBT.ART, spr, BBT.PLATE_SPRITE, 0, i)
  else
    pcall(funcLuaMenuCommand, BBT.C.SPRITE, l, BBT.PLATE_ATLAS, BBT.PLATE_SPRITE, BBT.PLATE_SPRITE, 0, i)
  end
end

-- 1.8.0: the player's focus band behind his plate (left edge x, centre y, scale s), on the box pool
function BBT_Focus(x, y, s)
  local G = BBT.G
  BBT_Quad(BBT.L.box, BBT.SPR_FOCUS, x + G.PLATE_W * s / 2, y, G.PLATE_W * s * G.FOCUS_W, G.PLATE_H * s * G.FOCUS_H,
    BBT.WHITE)
end

-- an instance's model + name alpha (CMND_SET_LAYER_MODEL_ALPHA / CMND_SET_MENU_TEXT_ALPHA, as the retail
-- soccer_team_dock_menu UpdateViewMenuByLock); reset to 1 on every plate / crest drawn (instances are reused)
function BBT_Alpha(l, i, a)
  pcall(funcLuaMenuCommand, 4231609516 --[[CMND_SET_LAYER_MODEL_ALPHA?]], l, i, 0, a)
  pcall(funcLuaMenuCommand, 1126837159 --[[CMND_SET_MENU_TEXT_ALPHA?]], l, i, BBT.TXT_ON, a)
  pcall(funcLuaMenuCommand, 1126837159 --[[CMND_SET_MENU_TEXT_ALPHA?]], l, i, BBT.TXT_OFF, a)
end

-- 1.9.0: crc32 of a digit sprite's name, kept (the same few names every draw)
function BBT_SprCrc(name)
  BBT_S.spr_crc = BBT_S.spr_crc or {}
  local c = BBT_S.spr_crc[name]
  if c == nil then
    c = BBT_Crc(name)
    BBT_S.spr_crc[name] = c
  end
  return c
end

-- a row of digit sprites centred on (x, y): parts = { { sprite name, height }, ... }; returns its width
function BBT_Glyphs(parts, x, y)
  local N = BBT.NUM
  local total, ws = 0, {}
  for k, p in ipairs(parts) do
    ws[k] = N.W * p[2] / N.H
    total = total + ws[k] * (k < #parts and N.ADV or 1)
  end
  local cx = x - total / 2
  for k, p in ipairs(parts) do
    BBT_Quad(BBT.L.line, BBT_SprCrc(p[1]), cx + ws[k] / 2, y, ws[k], p[2], BBT.WHITE, N.PRIO, BBT.ART_NUM)
    cx = cx + ws[k] * N.ADV
  end
  return total
end

-- the parts of number n (style gold / dark / white) at height h appended to parts; wrap = in brackets
function BBT_NumParts(parts, n, style, h, wrap)
  if wrap then
    parts[#parts + 1] = { "bbd_tn_d_lp", h }
  end
  for c in tostring(math.max(0, math.floor(tonumber(n) or 0))):gmatch("%d") do
    parts[#parts + 1] = { "bbd_tn_d_" .. style .. "_" .. c, h }
  end
  if wrap then
    parts[#parts + 1] = { "bbd_tn_d_rp", h }
  end
  return parts
end

-- the width of a row of k digits at height h
local function bbt_row_w(k, h)
  local N = BBT.NUM
  return N.W * h / N.H * (1 + N.ADV * (k - 1))
end

-- a played match's result at its joint (xj, ym) of the left side (right = mirrored): the pair just past the joint
-- (lead px further: the big crest standing on the joint), a shoot-out's kicks after it; returns the room it took past
-- the joint (0: not played)
function BBT_TreeScore(m, xj, ym, right, pitch, lead)
  local sc = m and (m.w or 0) ~= 0 and m.score or nil
  if not sc then
    return 0
  end
  local N, G = BBT.NUM, BBT.G
  local h = math.max(N.H_MIN, math.min(N.H_MAX, pitch * N.HEIGHT))
  local dy = (h + h * N.GAP / N.H) / 2
  local function x_of(off, w)
    local c = xj + off + w / 2
    return right and (2 * G.CX - c) or c
  end
  local space = N.SPACE * h / N.H
  local used = (lead or 0) + space
  local ga, gb = sc.ga or 0, sc.gb or 0
  local sa, sb = m.w == 1 and "gold" or "dark", m.w == 2 and "gold" or "dark"
  local w
  if ga <= 9 and gb <= 9 then
    w = N.W * h / N.H
    BBT_Quad(BBT.L.line, BBT_SprCrc(string.format("bbd_tn_pr_%d_%d_%d", ga, gb, m.w)), x_of(used, w), ym, w,
      h * N.PAIR_H / N.H, BBT.WHITE, N.PRIO, BBT.ART_NUM)
  else
    local pa, pb = BBT_NumParts({}, ga, sa, h), BBT_NumParts({}, gb, sb, h)
    w = bbt_row_w(math.max(#pa, #pb), h)
    BBT_Glyphs(pa, x_of(used, w), ym - dy)
    BBT_Glyphs(pb, x_of(used, w), ym + dy)
  end
  used = used + w
  if (sc.pa or 0) + (sc.pb or 0) > 0 then
    local hp = h * N.PEN_S
    local pa, pb = BBT_NumParts({}, sc.pa or 0, sa, hp), BBT_NumParts({}, sc.pb or 0, sb, hp)
    local wp = bbt_row_w(math.max(#pa, #pb), hp)
    used = used + space / 2
    BBT_Glyphs(pa, x_of(used, wp), ym - dy)
    BBT_Glyphs(pb, x_of(used, wp), ym + dy)
    used = used + wp
  end
  return used + space
end

-- the final's result below the centre: the left finalist's goals left of it, the right one's right of it (a
-- shoot-out: the kicks in brackets below each)
function BBT_FinalScore(m, ymid, pitch)
  local sc = m and (m.w or 0) ~= 0 and m.score or nil
  if not sc then
    return
  end
  local N, G = BBT.NUM, BBT.G
  local h = math.max(N.H_MIN, math.min(N.H_MAX, pitch * N.HEIGHT)) * N.FINAL_S
  local y = ymid + G.LINE_LIT + h / 2
  local off = N.W * h / N.H
  local sa, sb = m.w == 1 and "gold" or "dark", m.w == 2 and "gold" or "dark"
  BBT_Glyphs(BBT_NumParts({}, sc.ga or 0, sa, h), G.CX - off, y)
  BBT_Glyphs(BBT_NumParts({}, sc.gb or 0, sb, h), G.CX + off, y)
  if (sc.pa or 0) + (sc.pb or 0) > 0 then
    local hp = h * N.PEN_S
    local yp = y + h / 2 + hp * 0.7
    BBT_Glyphs(BBT_NumParts({}, sc.pa or 0, sa, hp, true), G.CX - off, yp)
    BBT_Glyphs(BBT_NumParts({}, sc.pb or 0, sb, hp, true), G.CX + off, yp)
  end
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
  -- 1.9.0: the crest standing on a joint (BBT_BigCrest): BIG_OF of the stub, the round's joint spacing less BIG_GAP,
  -- BIG_MIN .. BIG_MAX px, its bottom BIG_LIFT px above the line; drawn in front of the connectors and the digits
  BIG_OF = 0.5, BIG_GAP = 8, BIG_MIN = 24, BIG_MAX = 72, BIG_LIFT = 1, CREST_PRIO = 547,
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
      if p.me then
        BBT_Focus(x, y, s)
      end
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
        -- 1.9.0: the result stacked just past the joint (BBT_TreeScore)
        -- 1.9.0 (owner 2026-10-21: «El logo del equipo debe ser grande y estar arriba de la intersección»): the
        -- winner waiting at this joint stands BIG on top of it (BBT_BigCrest), the result stacked right of it
        local nxt = (v.matches[r + 1] or {})[math.floor((t + 1) / 2)] or {}
        local stays = win ~= 0 and (nxt.w or 0) == 0
        local big = BBT_BigCrest(r, pitch, (G.CX - xe) / R)
        -- (the digits always clear the crest's column, so a neighbour's crest never covers them)
        BBT_TreeScore(m, xj, ym, right, pitch, big / 2)
        if win ~= 0 and from then
          local rest = { mx(xj, right), ym - G.LINE_LIT / 2 - A.BIG_LIFT - big / 2 }
          nat[t] = rest
          crests[#crests + 1] = { leaf = win, round = r, rest = rest, s = big / A.CREST_W, stays = stays,
            joint = { mx(xj, right), ym }, path = { from, { mx(xj, right), yw }, { mx(xj, right), ym }, rest } }
        end
      else
        -- the final: the left finalist's line and the right one's meet at CX; the stem up to the champion
        seg(xc, ya, G.CX, ya, la, played, w == 1)
        seg(mx(xc, true), yb, G.CX, yb, lb, played, w == 2)
        seg(G.CX, G.CHAMP_Y + G.PLATE_H * G.CHAMP_S / 2, G.CX, ymid, win, played, true)
        BBT_FinalScore(m, ymid, pitch)
        if win ~= 0 and from then
          -- the champion's crest walks to the champion plate's crest slot (the plate shows once it is there)
          local rest = { G.CX - cpw / 2 + A.CREST_X * G.CHAMP_S, G.CHAMP_Y }
          local fs = BBT_BigCrest(R, pitch, (G.CX - xe) / R) / A.CREST_W
          crests[#crests + 1] = { leaf = win, round = r, rest = rest, s = fs, s1 = G.CHAMP_S, final = true,
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
  -- 1.8.0: the star glow at the joint each of them waits at (behind the lines; shown when its crest gets there)
  local star = math.max(G.STAR_MIN, math.min(G.STAR_MAX, pitch * G.STAR))
  for _, c in ipairs(crests) do
    if c.stays then
      c.star = BBT_Quad(BBT.L.box, BBT.SPR_STAR, c.joint[1], c.joint[2], star, star, BBT.WHITE)
      c.i = BBT_Crest(c, c.rest[1], c.rest[2], c.s)
    end
  end
  -- the champion: a cyan plate above the final with the crown over it (the crown waits dimmed until the final)
  local champ = (v.champion or 0) ~= 0
  local cs2 = G.CHAMP_S
  local cy = G.CHAMP_Y - G.PLATE_H * cs2 / 2 - G.CROWN_H / 2 + 6
  local cc = champ and 1 or G.DIM
  if not BBT_S.trophy then
    BBT_Quad(BBT.L.icon, BBT.SPR_CROWN, G.CX, cy, G.CROWN_W, G.CROWN_H, { cc, cc, cc })
  end
  if champ then
    BBT_Plate({ team = v.champion }, G.CX - G.PLATE_W * cs2 / 2, G.CHAMP_Y, cs2, false, true, BBT.ROW_CHAMP)
  end
end

-- ------------------------------------------------------------------------------------------------ the retail bracket
-- 2026-10-19 (owner): a knockout of exactly 16 teams is drawn in the style of Victory Road's «決勝トーナメント» with
-- the retail objects as layers of this menu (content\menus\bb_tournament.toml, retail layer names): the tree base
-- (the unlit bracket mesh) attaches the 16 gold path strips, the trophy, the per-round scores and the schedule panel
-- to its nodes; each strip attaches the star of its slot to the head of its lit part. A strip's lit length is its
-- MenuRateSetting «move» (the retail native code: 0.25 a round won, bound to the animation group «line»), set with
-- the rate commands the retail gauges use (541357333 bind, 1595998683 set). BBD's own plates stand at the base's
-- name nodes. Every other bracket (8, 32, 64 teams) keeps the generic lines (BBT_DrawTree).
BBT.RL = {
  base = @crc:vroad04_01_tournament_base@,
  trophy = @crc:vroad04_02_trophy@,
  star = @crc:vroad04_04_light_on_line@,   -- 16 instances: strip k attaches instance k - 1
  sched = @crc:vroad04_09_schedule_for_spectator@,
  -- slots in the view's leaf order: the left side top to bottom (l01 .. l08), then the right side (r01 .. r08)
  lines = {
    @crc:vroad04_03_l01_tournament_line@, @crc:vroad04_03_l02_tournament_line@, @crc:vroad04_03_l03_tournament_line@,
    @crc:vroad04_03_l04_tournament_line@, @crc:vroad04_03_l05_tournament_line@, @crc:vroad04_03_l06_tournament_line@,
    @crc:vroad04_03_l07_tournament_line@, @crc:vroad04_03_l08_tournament_line@, @crc:vroad04_03_r01_tournament_line@,
    @crc:vroad04_03_r02_tournament_line@, @crc:vroad04_03_r03_tournament_line@, @crc:vroad04_03_r04_tournament_line@,
    @crc:vroad04_03_r05_tournament_line@, @crc:vroad04_03_r06_tournament_line@, @crc:vroad04_03_r07_tournament_line@,
    @crc:vroad04_03_r08_tournament_line@,
  },
  -- per round: round 1 (8: matches 1-4 left, 5-8 right), 2 (4), 3 (2), the final (1); instance = match - 1
  score = { @crc:vroad04_07_tounament_score_round01@, @crc:vroad04_07_tounament_score_round02@,
    @crc:vroad04_07_tounament_score_round03@, @crc:vroad04_07b_tounament_score_final@ },
}
BBT.RETAIL = {
  ROUNDS = 4,                          -- the retail tree: 16 entrants
  STARS = 16,
  SCORES = { 8, 4, 2, 1 },
  RATE_MOVE = 4013832056 --[[move]],   -- the strips' MenuRateSetting
  ANIM_LINE = @crc:line@,              -- its animation group (the retail native code binds «move» to «line»)
  NUM_A = 2710162575,                  -- the score objects' two number settings: the upper (left) entrant's goals
  NUM_B = 947952949,                   -- and the lower (right) entrant's
  -- the score objects' flag meshes (hidden by the object), shown beside the winner of a shoot-out: [side][entrant]
  FLAG = { left = { @crc:_icon_flag_l01@, @crc:_icon_flag_l02@ }, right = { @crc:_icon_flag_r01@, @crc:_icon_flag_r02@ } },
  FLAG_FINAL = { @crc:_icon_flag_l01@, @crc:_icon_flag_r01@ },
  FLAG_ALL = { @crc:_icon_flag_l01@, @crc:_icon_flag_l02@, @crc:_icon_flag_r01@, @crc:_icon_flag_r02@ },
  -- the panel's texts (vroad04_09: _text_time01_01 top, _text_time01_02, _text_now01; _text_time02 shares the top
  -- line's place and stays empty)
  TXT_ROUND = @crc:_text_time01_01@, TXT_PLAYED = @crc:_text_time01_02@, TXT_NEXT = @crc:_text_now01@,
  TXT_SPARE = @crc:_text_time02@,
  -- the base's layout is in screen px (as vroad04_01_p1_bg's): placed at the origin. Its name nodes
  -- (_atc_name_l01 .. r08): x 363 / 1557, y 288 + 72 a slot; a strip starts 137 px inside its node
  NAME_X_L = 363, NAME_X_R = 1557, NAME_Y0 = 288, NAME_STEP = 72, STRIP_IN = 137,
  PLATE_S = 0.6,                       -- BBD's plate (520 x 72) at the name nodes: 312 x 43
  PLATE_GAP = 6,                       -- between a plate's inner end and its strip
  MESH_TREE = @crc:_tournament01@,     -- the base's unlit 16-team bracket mesh
  TROPHY_NODE_Y = 381,                 -- the base's _atc_trophy01 (the trophy's place), screen px
  CHAMP_Y = 206,                       -- the champion's plate, above the trophy (_atc_trophy01 at y 381)
}

-- whether this menu has the retail layers (another host, or a menu file without them: the generic lines)
function BBT_RetailReady()
  if BBT_S.retail_ok ~= nil then
    return BBT_S.retail_ok
  end
  local L = BBT.RL
  local need = { L.base, L.trophy, L.sched, L.star, L.lines[1], L.lines[16], L.score[1], L.score[4] }
  local ok = true
  for _, l in ipairs(need) do
    local n = funcLuaMenuCommand(1175615627 --[[CMND_GET_CREATE_LAYER_NUM?]], l)
    if type(n) ~= "number" or n < 1 then
      ok = false
    end
  end
  if ok then
    BBT_S.retail_ok = true
  end
  if ok or not BBT_S.retail_missing_logged then
    BBT_S.retail_missing_logged = not ok
    BBT_Log("retail bracket layers: " .. (ok and "present (16-team knockouts in the Victory Road style)" or
      "missing on " .. tostring(BBT_HOST.name) .. " (every bracket on the generic lines)"))
  end
  return ok
end

-- every instance of the retail layers: f(layer, instance)
function BBT_RetailEach(f)
  local L, R = BBT.RL, BBT.RETAIL
  f(L.base, 0)
  f(L.trophy, 0)
  f(L.sched, 0)
  for k = 1, #L.lines do
    f(L.lines[k], 0)
  end
  for i = 0, R.STARS - 1 do
    f(L.star, i)
  end
  for r = 1, #L.score do
    for i = 0, R.SCORES[r] - 1 do
      f(L.score[r], i)
    end
  end
end

-- the retail layers shown (a 16-team tree page) or hidden (every other page); the stars and scores are shown by
-- BBT_DrawRetail one by one
function BBT_RetailShow(on)
  if not BBT_S.retail_open then
    return
  end
  local C, L = BBT.C, BBT.RL
  BBT_RetailEach(function(l, i)
    funcLuaMenuCommand(C.VISIBLE, l, i, on and l ~= L.star and l ~= L.score[1] and l ~= L.score[2]
      and l ~= L.score[3] and l ~= L.score[4])
  end)
  BBT_S.retail_shown = on
end

-- 1.8.0: every other tree (8, 32, 64 teams) shows the retail trophy in place of the crown: the base without its
-- 16-team mesh, moved so its trophy node stands at BBT.G.TROPHY_Y (its strips, stars, scores and panel hidden by
-- BBT_RetailShow); alone = false puts the base back for the 16-team art (mesh shown, at the origin)
function BBT_TrophyPlace(alone)
  local C, L, R = BBT.C, BBT.RL, BBT.RETAIL
  funcLuaMenuCommand(C.MESH_VISIBLE, L.base, R.MESH_TREE, not alone, 0)
  funcLuaMenuCommand(C.POS, L.base, 0, alone and (R.TROPHY_NODE_Y - BBT.G.TROPHY_Y) or 0, 0, 0)
  if alone then
    funcLuaMenuCommand(C.VISIBLE, L.base, 0, true)
    funcLuaMenuCommand(C.VISIBLE, L.trophy, 0, true)
  end
end

-- a strip's lit length: rate 0 (unlit) .. 1 (to the centre); the star at its head shown while the rate is above 0
function BBT_RetailRate(k, rate)
  local L, R, C = BBT.RL, BBT.RETAIL, BBT.C
  local l = L.lines[k]
  local g = funcLuaMenuCommand(112302847 --[[CMND_GET_GROUP_INDEX?]], l, 0, R.ANIM_LINE)
  funcLuaMenuCommand(541357333, l, R.RATE_MOVE, g or 0, 0)
  funcLuaMenuCommand(1595998683, l, R.RATE_MOVE, 0, rate, 0, true, R.ANIM_LINE)
  funcLuaMenuCommand(C.VISIBLE, L.star, k - 1, rate > 0)
end

-- one score object: the two entrants' goals, the shoot-out's winner flagged; nil = hidden (not played)
function BBT_RetailScore(r, t, m)
  local L, R, C = BBT.RL, BBT.RETAIL, BBT.C
  local l, i = L.score[r], t - 1
  local sc = m and (m.w or 0) ~= 0 and m.score or nil
  funcLuaMenuCommand(C.VISIBLE, l, i, sc ~= nil)
  if not sc then
    return
  end
  for _, prim in ipairs({ R.NUM_A, R.NUM_B }) do
    funcLuaMenuCommand(1233047821, l, i, prim, true)
    local pi = funcLuaMenuCommand(1927054058 --[[CMND_SEARCH_PRIM_INDEX?]], l, i, prim)
    funcLuaMenuCommand(3609943765, l, i, pi, prim == R.NUM_A and (sc.ga or 0) or (sc.gb or 0))
  end
  for _, f in ipairs(R.FLAG_ALL) do
    funcLuaMenuCommand(C.MESH_VISIBLE, l, f, false, i)
  end
  if (sc.pa or 0) + (sc.pb or 0) > 0 then
    local flags = r == #L.score and R.FLAG_FINAL or (t > R.SCORES[r] / 2 and R.FLAG.right or R.FLAG.left)
    funcLuaMenuCommand(C.MESH_VISIBLE, l, flags[m.w] or flags[1], true, i)
  end
end

-- a text with <VALUE> and <VALUE2> filled (the retail text value command, once per tag)
function BBT_TextValue2(key, a, b)
  local t = BBT_Text(key)
  local ok, r = pcall(funcLuaCommand, 910683996, t, "VALUE", a or 0, 0, 0, true)
  t = ok and r or t
  local ok2, r2 = pcall(funcLuaCommand, 910683996, t, "VALUE2", b or 0, 0, 0, true)
  return ok2 and r2 or t
end

-- the schedule panel: the round being played, its matches played, the player's next match (or the run's end)
function BBT_RetailPanel(v)
  local L, R, C = BBT.RL, BBT.RETAIL, BBT.C
  local cur, played, total = nil, 0, 0
  for r = 1, R.ROUNDS do
    local row = v.matches[r] or {}
    local n, done = 0, 0
    for _, m in pairs(row) do
      n = n + 1
      if (m.w or 0) ~= 0 then
        done = done + 1
      end
    end
    if cur == nil and done < n then
      cur, played, total = r, done, n
    end
  end
  local round_txt, played_txt, next_txt
  if cur == nil then
    round_txt = BBT_Text("sched_over")
    played_txt = ""
  else
    round_txt = BBT_Text("round_" .. tostring(R.ROUNDS - cur + 1))
    played_txt = BBT_TextValue2("sched_played", played, total)
  end
  local tail = BBT_Outcome(v)
  if tail ~= "" then
    next_txt = tail
  elseif cur ~= nil then
    local rival = (v.next or 0) ~= 0 and BBT_TeamName(v.next) or BBT_Text("sched_rival_tbd")
    next_txt = BBT_Text("sched_next") .. "  ·  " .. rival
  else
    next_txt = ""
  end
  local l = L.sched
  for node, s in pairs({ [R.TXT_ROUND] = round_txt, [R.TXT_PLAYED] = played_txt, [R.TXT_NEXT] = next_txt,
    [R.TXT_SPARE] = "" }) do
    funcLuaMenuCommand(C.TEXT, l, node, s, 0)
    funcLuaMenuCommand(C.TEXT_VISIBLE, l, node, s ~= "", 0)
  end
  pcall(funcLuaMenuCommand, 1172899594 --[[CMND_UPDATE_TEXT_PLATE?]], l, 0, R.TXT_ROUND)
  pcall(funcLuaMenuCommand, 1172899594 --[[CMND_UPDATE_TEXT_PLATE?]], l, 0, R.TXT_PLAYED)
  return cur
end

-- the 16-team tree on the retail art: BBD's plates at the name nodes, each slot's strip lit by the rounds its team
-- won while it is still in (a team that is out: unlit, its plate faded, as BBT_DrawTree's dark paths), the scores
-- of the played matches, the trophy, the panel; the champion's plate above the trophy. BBT_S.retail keeps each
-- slot's rate and its rate before the last round played (the advance animates from one to the other).
function BBT_DrawRetail(v)
  local G, R, L, C = BBT.G, BBT.RETAIL, BBT.RL, BBT.C
  local leaves = v.leaves
  local s = R.PLATE_S
  local pw = G.PLATE_W * s
  -- the last round with a result (the one the advance animates)
  local last = 0
  for r = 1, R.ROUNDS do
    for _, m in pairs(v.matches[r] or {}) do
      if (m.w or 0) ~= 0 then
        last = r
      end
    end
  end
  local rates, prev = {}, {}
  for k = 1, #L.lines do
    local p = leaves[k] or {}
    local right = k > 8
    local y = R.NAME_Y0 + R.NAME_STEP * ((k - 1) % 8)
    local x = right and (R.NAME_X_R - R.STRIP_IN + R.PLATE_GAP) or (R.NAME_X_L + R.STRIP_IN - R.PLATE_GAP - pw)
    if (p.team or 0) ~= 0 then
      if p.me then
        BBT_Focus(x, y, s)
      end
      BBT_Plate(p, x, y, s, right, false)
    end
    -- the rounds this slot's team won: its leaf's own count (tourney_view) or walked up the tree
    local won = tonumber(p.won) or 0
    local rate = (not p.out and (p.team or 0) ~= 0) and math.min(1, won / R.ROUNDS) or 0
    rates[k] = rate
    -- before the last round: one round less for its winner; its loser was lit by the rounds it had won
    local before = rate
    local t = math.floor((k - 1) / 2 ^ last) + 1
    local m = (v.matches[last] or {})[t]
    if last > 0 and m and (m.w or 0) ~= 0 then
      local upper = ((k - 1) % 2 ^ last) < 2 ^ (last - 1)
      local winner = (m.w == 1) == upper
      if winner then
        before = math.max(0, rate - 1 / R.ROUNDS)
      elseif (p.team or 0) ~= 0 then
        before = math.min(1, (last - 1) / R.ROUNDS)
      end
    end
    prev[k] = before
    BBT_RetailRate(k, rate)
  end
  for r = 1, R.ROUNDS do
    local row = v.matches[r] or {}
    for t = 1, R.SCORES[r] do
      BBT_RetailScore(r, t, row[t])
    end
  end
  local cur = BBT_RetailPanel(v)
  if (v.champion or 0) ~= 0 then
    BBT_Plate({ team = v.champion }, G.CX - G.PLATE_W * G.CHAMP_S / 2, R.CHAMP_Y, G.CHAMP_S, false, true,
      BBT.ROW_CHAMP)
  end
  BBT_S.crests = {}
  BBT_S.retail = { rates = rates, prev = prev, last = last }
  local lit = 0
  for k = 1, #rates do
    if rates[k] > 0 then
      lit = lit + 1
    end
  end
  -- where the engine put the base and the l01 strip (attached to the name node _atc_name_l01: x 363, y 288 expected
  -- in the base's layout px; BBD's plates are placed on those numbers)
  local okb, bx, by = pcall(funcLuaMenuCommand, 4002164178 --[[global pos]], L.base, 0)
  local okl, lx, ly = pcall(funcLuaMenuCommand, 4002164178 --[[global pos]], L.lines[1], 0)
  BBT_Log(string.format("retail bracket: %d path(s) lit, last round played %d, panel round %s; base at %s,%s, l01 strip at %s,%s",
    lit, last, tostring(cur), tostring(okb and bx), tostring(okb and by), tostring(okl and lx), tostring(okl and ly)))
end

-- 2026-10-19: the stadium of the FINAL in a box at the bottom of every bracket page (a tree), from
-- CMND_BBD_TOURN_INFO .final_stadium = { map = "s01g001", id = crc32(map) } (scripts	ournament.lua: drawn once per
-- tournament from config.toml [tournament] final_stadiums); nothing when the field is missing. Its name: the game's
-- map name (CMND_GET_MAP_NAME, as the retail room setting); its picture: the game's room picture of that map
-- (#/menu/220_img/stadium/img_room_<map>.g4tx, sprite img_room_<map>_01: the retail Campaña's stadium picture),
-- loaded on demand (CMND_LOAD_MENU_RES_TEXTURE, asynchronous: the page is drawn again once it is in; a map without
-- a picture: the name only).
-- 1.7.0 (owner 2026-10-21): both lines centred on the box, the box as wide as its longest line + SIDE on each side
-- (MIN_W..MAX_W: MAX_W stays inside the 64-team tree's inner lines); a line wider than the room is scaled down; the
-- picture only once it is in and only when it fits beside the texts (the texts stay centred: the box grows by the
-- picture on both sides).
BBT.STADIUM = { Y = 958, H = 84, MIN_W = 300, MAX_W = 480, SIDE = 28, THUMB_W = 128, THUMB_H = 72, PAD = 8,
  LABEL_S = 0.62, NAME_S = 0.86, CHAR_W = 14.5, TEXT_SIZE = 3549540977 --[[CMND_GET_MENU_TEXT_RECT_SIZE]],
  LOAD_MIN = 10, LOAD_MAX = 600, PICTURE_DIR = "#/menu/220_img/stadium/img_room_" }

-- the width in px of s drawn by BBT_Txt on txt instance i at scale sc (the engine's text width; a per-character
-- estimate if it answers nothing)
function BBT_TextWidth(i, s, sc)
  local P = BBT.STADIUM
  local ok, w = pcall(funcLuaMenuCommand, P.TEXT_SIZE, BBT.L.txt, i, BBT.TXT_ON, s)
  if not ok or type(w) ~= "number" or w <= 0 then
    local n = 0
    for _ in string.gmatch(s, "[^\128-\191]") do
      n = n + 1
    end
    w = n * P.CHAR_W
  end
  return w * sc
end

-- the picture of a map: { path, tex, sprite, st = 0 not asked / 1 loading / 2 in / -1 none }, one per map a session
BBT_S.stadium_pics = BBT_S.stadium_pics or {}
function BBT_StadiumPicture(map)
  local pics = BBT_S.stadium_pics
  local pic = pics[map]
  if pic == nil then
    local path = BBT.STADIUM.PICTURE_DIR .. map .. ".g4tx"
    pic = { path = path, tex = BBT_Crc(path), sprite = BBT_Crc("img_room_" .. map .. "_01"), st = 0, t = 0 }
    pics[map] = pic
  end
  if pic.st == 0 then
    local ok = pcall(funcLuaMenuCommand, 839427544 --[[CMND_LOAD_MENU_RES_TEXTURE]], pic.path)
    pic.st, pic.t = ok and 1 or -1, 0
    BBT_S.stadium_load = ok and map or nil
    BBT_Log("final stadium picture: " .. pic.path .. (ok and " asked" or " not loadable (name only)"))
  end
  return pic
end

-- from Step while a picture loads: once it is in, the page again (the box gets its picture)
function BBT_StadiumLoadStep()
  local map = BBT_S.stadium_load
  local pic = map and BBT_S.stadium_pics[map]
  if not pic or pic.st ~= 1 then
    BBT_S.stadium_load = nil
    return
  end
  pic.t = pic.t + 1
  local ok, busy = pcall(funcLuaCommand, 1506186496 --[[texture still loading?]], pic.tex)
  if not ok or pic.t > BBT.STADIUM.LOAD_MAX then
    pic.st = -1
    BBT_S.stadium_load = nil
    BBT_Log("final stadium picture: never loaded (name only)", pic.path)
    return
  end
  if busy ~= true and pic.t >= BBT.STADIUM.LOAD_MIN then
    pic.st = 2
    BBT_S.stadium_load = nil
    BBT_Log("final stadium picture: in after " .. pic.t .. " frames")
    if BBT_S.open and BBT_S.view and BBT_S.view.kind == "tree" then
      BBT_S.redraw = true
    end
  end
end

function BBT_DrawStadium()
  local info = BBT_INFO or {}
  local okc, fresh = pcall(BBT_Info)
  if okc and type(fresh) == "table" then
    info = fresh
  end
  local fs = info.final_stadium
  if type(fs) ~= "table" or type(fs.map) ~= "string" or fs.map == "" then
    return
  end
  local G, P = BBT.G, BBT.STADIUM
  local id = type(fs.id) == "number" and fs.id or BBT_Crc(fs.map)
  local okn, name = pcall(funcLuaCommand, 3763041341 --[[CMND_GET_MAP_NAME]], id)
  if not okn or type(name) ~= "string" then
    name = ""
  end
  -- the two lines centred on the screen's centre, each scaled down to the room it has
  local room = P.MAX_W - P.SIDE * 2
  local widest = 0
  for _, ln in ipairs({ { BBT_Text("final_stadium"), P.Y - P.H * 0.22, P.LABEL_S },
    { name, P.Y + P.H * 0.18, P.NAME_S } }) do
    local i = BBT_Txt(ln[1], G.CX, ln[2], ln[3])
    if i ~= nil then
      local w = BBT_TextWidth(i, ln[1], ln[3])
      if w > room then
        local sc = ln[3] * room / w
        funcLuaMenuCommand(BBT.C.SCALE, BBT.L.txt, sc, sc, 1, i)
        w = room
      end
      widest = math.max(widest, w)
    end
  end
  local w = math.max(P.MIN_W, widest + P.SIDE * 2)
  local pic = BBT_StadiumPicture(fs.map)
  local with_pic = w + (P.THUMB_W + P.PAD) * 2
  local show_pic = pic.st == 2 and with_pic <= P.MAX_W
  if show_pic then
    w = with_pic
  end
  BBT_Quad(BBT.L.box, BBT.SPR_PANEL, G.CX, P.Y, w, P.H, BBT.WHITE)
  if show_pic then
    BBT_Quad(BBT.L.box, pic.sprite, G.CX - w / 2 + P.PAD + P.THUMB_W / 2, P.Y, P.THUMB_W, P.THUMB_H, BBT.WHITE, nil,
      pic.tex)
  end
  if BBT_S.stadium_logged ~= fs.map .. ":" .. pic.st then
    BBT_S.stadium_logged = fs.map .. ":" .. pic.st
    BBT_Log(string.format("final stadium panel: %s «%s» (picture %s)", fs.map, name,
      pic.st == 2 and "shown" or (pic.st == 1 and "loading" or "none")))
  end
end

-- 1.9.0: the size (px) of the crest standing on a joint of round r: as big as the room allows, BIG_OF of the stub
-- to the next joint (stub px) and the joints' spacing of that round (2^r plate pitches) less BIG_GAP, at most
-- BIG_MAX (64 teams: 46 px on round 1, 62 later; 32: 58; 8: 65)
function BBT_BigCrest(r, pitch, stub)
  local A = BBT.ADV
  return math.max(A.BIG_MIN, math.min(A.BIG_MAX, stub * A.BIG_OF, 2 ^ r * pitch - A.BIG_GAP))
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
  -- 1.9.0: in front of the connectors (549) and the score digits (548), once per instance and opening
  BBT_S.crest_prio = BBT_S.crest_prio or {}
  if not BBT_S.crest_prio[i] then
    BBT_S.crest_prio[i] = true
    pcall(funcLuaMenuCommand, 1491630496 --[[CMND_SET_DRAW_PRIORITY]], L.crest, i, p.CREST_PRIO, true)
  end
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
  -- 2026-10-19: on the retail art the paths of the round just played light up (or go out) along their strips
  if BBT_S.retail then
    return BBT_RetailAnimStart(v)
  end
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
  if an.retail then
    return BBT_RetailAnimApply(an)
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
    if c.star then
      funcLuaMenuCommand(C.VISIBLE, BBT.L.box, c.star, p >= 1)
    end
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

-- 2026-10-19: the retail art's advance: every strip whose rate the last round changed goes from its rate before
-- that round to its rate now (the winners' paths grow to the next node, the losers' go out), eased and staggered
-- as the crests' walk; the champion's plate shows when the final's path reaches the centre
function BBT_RetailAnimStart(v)
  local rt = BBT_S.retail
  if not rt or rt.last == 0 then
    return
  end
  local A = BBT.ADV
  local items = {}
  for k = 1, #rt.rates do
    if rt.prev[k] ~= rt.rates[k] then
      items[#items + 1] = { slot = k, from = rt.prev[k], to = rt.rates[k] }
    end
  end
  if #items == 0 then
    return
  end
  local gap = math.min(A.STAGGER, A.STAGGER_ALL / #items)
  for n, it in ipairs(items) do
    it.delay = (n - 1) * gap
  end
  BBT_S.anim = { t = 0, page = v.page, retail = true, items = items, round = rt.last,
    final = rt.last == BBT.RETAIL.ROUNDS, done_at = (#items - 1) * gap + A.DUR }
  BBT_RetailAnimApply(BBT_S.anim)
  BBT_Log(string.format("bracket advance: round %d, %d path(s) change on the retail art", rt.last, #items))
end

function BBT_RetailAnimApply(an)
  local A = BBT.ADV
  local busy = false
  for _, it in ipairs(an.items) do
    local p = math.max(0, math.min(1, (an.t - it.delay) / A.DUR))
    if p < 1 then
      busy = true
    end
    BBT_RetailRate(it.slot, it.from + (it.to - it.from) * bbt_ease(p))
  end
  if an.final and BBT_S.view and (BBT_S.view.champion or 0) ~= 0 then
    funcLuaMenuCommand(BBT.C.VISIBLE, BBT.L.row_l, BBT.ROW_CHAMP, not busy)
  end
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
        -- 1.9.0: the Victory Road digits on the stadium panel's navy (winner gold, loser dark, a draw white), the
        -- shoot-out's kicks smaller in brackets, extra time marked
        BBT_Quad(BBT.L.box, BBT.SPR_PANEL, bx, y, bw, bh, BBT.WHITE)
        local N = BBT.NUM
        local style = look == "win" and "gold" or (look == "lose" and "dark" or "white")
        local h = bh * N.BOX_FILL
        local parts = BBT_NumParts({}, g or 0, style, h)
        if (r.pa or 0) + (r.pb or 0) > 0 then
          BBT_NumParts(parts, pk or 0, style, h * N.PEN_S, true)
        elseif r.et then
          parts[#parts + 1] = { "bbd_tn_d_et", h * N.PEN_S }
        end
        BBT_Glyphs(parts, bx, y)
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
  -- 1.5.64: parameter: this host no longer shows the group page (the child hides everything and closes itself). The
  -- host's CMND_CLOSE_MENU_OBJECT of the child alone left it open: its tables stayed drawn over the team grid after
  -- leaving the Torneo, and the next team pick froze on the options window (owner 2026-10-14)
  P_CLOSE = @crc:evt_bbd_tn_groups_close@,
  WATCH_STEPS = 30,   -- the watchdog: every this many Steps, a child that exists while no group page is wanted closes
}

-- the child opened once it is wanted and an earlier one has finished closing (Step and BBT_GroupsShow)
function BBT_GroupsStep()
  local S = BBT_S
  if S.gm_want == nil or S.gm_open or not S.open then
    return
  end
  if funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT?]], BBT.GM.MENU) == true then
    S.gm_wait = (S.gm_wait or 0) + 1
    -- 1.5.64: an earlier one still closing (or one whose close did not take): it comes back with this page and host
    if S.gm_wait == 30 then
      pcall(funcLuaCommand, 3363400568 --[[param delete]], BBT.GM.P_CLOSE)
      pcall(funcLuaCommand, 830228314 --[[cross-menu call]], BBT.GM.MENU, "BBG_Revive", S.gm_want, BBT_HOST.menu)
      S.gm_open, S.gm_wait = true, 0
      BBT_Log("groups menu: the earlier one still existed; shown again over", BBT_HOST.name, "page", S.gm_want)
    end
    return
  end
  S.gm_wait = 0
  pcall(funcLuaCommand, 3363400568 --[[param delete]], BBT.GM.P_CLOSE)
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

-- the child asked to close, three ways (1.5.64): the close parameter (read by its Step), the cross-menu call (it hides
-- every piece at once and closes itself) and the engine's close of the menu object
function BBT_GroupsRequestClose(why)
  pcall(funcLuaCommand, 3363400568 --[[param delete]], BBT.GM.P_CLOSE)
  pcall(funcLuaCommand, 3860611758 --[[param set]], BBT.GM.P_CLOSE, 0, 1, 1)
  pcall(funcLuaCommand, 830228314 --[[cross-menu call]], BBT.GM.MENU, "BBG_Close", why)
  pcall(funcLuaCommand, 320421347 --[[CMND_CLOSE_MENU_OBJECT]], BBT.GM.MENU)
end

-- the child closed (another page shown, the overlay closed); also when this host's state lost track of it (a child
-- that exists is always asked to close)
function BBT_GroupsHide()
  local S = BBT_S
  S.gm_want = nil
  local exists = funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT?]], BBT.GM.MENU) == true
  if S.gm_open or exists then
    S.gm_open = false
    S.gm_watch = 0
    BBT_GroupsRequestClose("the overlay left the group page")
    BBT_Log("groups menu closed (overlay open " .. tostring(S.open) .. ", child existed " .. tostring(exists) .. ")")
  end
end

-- 1.5.64 watchdog (Step): the group page is only ever shown in the Torneo overlay's group view; a child that still
-- exists while this host wants none (another page, the overlay closed, the team grid or any other screen on top) is
-- asked to close again, logged once per leftover
function BBT_GroupsWatch()
  local S = BBT_S
  if S.gm_want ~= nil and S.open then
    -- the group page wanted: a child closed from elsewhere (the team grid's own watchdog while it was closing) is
    -- opened again
    S.gm_watch = (S.gm_watch or 0) + 1
    if S.gm_open and S.gm_watch % BBT.GM.WATCH_STEPS == 0
      and funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT?]], BBT.GM.MENU) ~= true then
      S.gm_open = false
      BBT_Log("groups menu: gone while its page is shown; opened again")
    end
    return
  end
  S.gm_watch = (S.gm_watch or 0) + 1
  if S.gm_watch % BBT.GM.WATCH_STEPS ~= 0 then
    return
  end
  if funcLuaMenuCommand(2231168902 --[[CMND_IS_EXIST_MENU_OBJECT?]], BBT.GM.MENU) ~= true then
    S.gm_left = nil
    return
  end
  S.gm_open = false
  BBT_GroupsRequestClose("left over: the overlay shows no group page")
  if not S.gm_left then
    S.gm_left = true
    BBT_Log("groups menu: left over while the overlay is " .. (S.open and "on another page" or "closed") ..
      ": asked to close again")
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
  BBT_S.retail = nil
  pcall(BBT_RetailShow, false)
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
  -- 1.8.0: the Victory Road stadium dimmed under the page (the box pool's first quad, behind everything it draws)
  if BBT_S.stadium_bg and v.kind ~= "groups" then
    BBT_Quad(BBT.L.box, BBT.SPR_DIM, BBT.G.CX, 540, BBT.G.W, 1080, BBT.WHITE)
  end
  -- 2026-10-19: a 16-team knockout on the retail bracket art (BBT_DrawRetail), every other tree on the generic lines
  local retail = v.kind == "tree" and BBT_S.retail_open == true and tonumber(v.rounds) == BBT.RETAIL.ROUNDS
    and type(v.leaves) == "table" and type(v.matches) == "table"
  BBT_S.retail = nil
  pcall(BBT_RetailShow, retail)
  -- 1.8.0: the trophy alone on every other tree (BBT_TrophyPlace)
  BBT_S.trophy = false
  if BBT_S.retail_open then
    BBT_S.trophy = not retail and v.kind == "tree"
    local okt = pcall(BBT_TrophyPlace, BBT_S.trophy)
    BBT_S.trophy = okt and BBT_S.trophy
  end
  local ok, err = pcall(function()
    if retail then
      BBT_DrawRetail(v)
    elseif v.kind == "tree" then
      BBT_DrawTree(v)
    elseif v.kind == "results" then
      BBT_DrawResults(v)
    end
    if v.kind == "tree" then
      BBT_DrawStadium()
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
  -- 1.8.0: the Victory Road stadium (its layout in screen px: at the origin) behind the bracket's pools (549-552; a
  -- lower draw priority draws in front; its own 200 would cover them): 560; the band (195) stays in front, as in retail
  BBT_S.strip = {}
  BBT_S.crest_prio = {}
  BBT_S.stadium_bg = false
  local nst = funcLuaMenuCommand(1175615627 --[[CMND_GET_CREATE_LAYER_NUM?]], BBT.L.stadium)
  if type(nst) == "number" and nst >= 1 then
    bbt_open_layer(BBT.L.stadium, 0)
    funcLuaMenuCommand(BBT.C.SCALE, BBT.L.stadium, 1, 1, 1, 0)
    funcLuaMenuCommand(BBT.C.POS, BBT.L.stadium, 0, 0, 0, 0)
    pcall(funcLuaMenuCommand, 1491630496 --[[CMND_SET_DRAW_PRIORITY]], BBT.L.stadium, 0, G.PRIO_STADIUM, true)
    BBT_S.stadium_bg = true
  end
  -- every instance opened once, hidden until a page draws it (each draw shows what it uses, hides the rest)
  BBT_EachInstance(function(l, i)
    bbt_open_layer(l, i)
    BBT_Hide(l, i)
  end)
  -- 2026-10-19: the retail bracket's layers (this menu only), opened once and hidden until a 16-team tree draws them;
  -- the base's layout is in screen px: at the origin
  BBT_S.retail_open = false
  if BBT_RetailReady() then
    BBT_RetailEach(function(l, i)
      bbt_open_layer(l, i)
      funcLuaMenuCommand(BBT.C.VISIBLE, l, i, false)
    end)
    funcLuaMenuCommand(BBT.C.POS, BBT.RL.base, 0, 0, 0, 0)
    BBT_S.retail_open = true
  end
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
  -- 1.5.64: the view's open / close state in the log (owner 2026-10-14: the group tables left over the team grid)
  BBT_Log("overlay closing on " .. tostring(BBT_HOST.name) .. ": page " .. tostring(BBT_S.page) .. ", group page menu " ..
    (BBT_S.gm_open and "open" or "not open"))
  BBT_S.champ, BBT_S.champ_done, BBT_S.anim = nil, false, nil
  BBT_GroupsHide()   -- 1.5.60: the group stage's own menu
  BBT_EachInstance(function(l, i)
    bbt_close_layer(l, i)
  end)
  bbt_close_layer(BBT.L.bg, 0)
  if BBT_S.stadium_bg then
    bbt_close_layer(BBT.L.stadium, 0)
    BBT_S.stadium_bg = false
  end
  if BBT_S.retail_open then
    BBT_RetailEach(function(l, i)
      bbt_close_layer(l, i)
    end)
    BBT_S.retail_open, BBT_S.retail = false, nil
  end
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
  -- 2026-10-19: the retail bracket's layers (their instances summed: 50 in the menu file)
  local rgot, rwant = 0, 0
  local seen = {}
  BBT_RetailEach(function(l, i)
    rwant = rwant + 1
    if not seen[l] then
      seen[l] = true
      local got = funcLuaMenuCommand(1175615627 --[[CMND_GET_CREATE_LAYER_NUM?]], l)
      rgot = rgot + (type(got) == "number" and got or 0)
    end
  end)
  parts[#parts + 1] = string.format("~retail %d/%d", rgot, rwant)
  if rgot < rwant then
    short = short + 1
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
    -- 1.5.64: no group-stage menu outside the overlay's group page
    local okw, errw = pcall(BBT_GroupsWatch)
    if not okw then
      BBT_Log("groups menu watchdog error", tostring(errw))
    end
    -- 1.5.60: the group stage's own menu, once an earlier one finished closing
    if S.gm_want ~= nil and not S.gm_open then
      local okg, errg = pcall(BBT_GroupsStep)
      if not okg then
        S.gm_want = nil
        BBT_Log("groups menu error", tostring(errg))
      end
    end
    -- 2026-10-19: the final stadium's picture loading (BBT_DrawStadium asked it)
    if S.open and S.stadium_load ~= nil then
      local okp, errp = pcall(BBT_StadiumLoadStep)
      if not okp then
        S.stadium_load = nil
        BBT_Log("final stadium picture error", tostring(errp))
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
