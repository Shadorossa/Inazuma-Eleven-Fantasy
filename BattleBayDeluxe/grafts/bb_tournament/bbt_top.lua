-- BattleBayDeluxe bb_tournament, Battle Bay top menu (bb_stadium_top_menu; docs/game/modes/bb-tournament.md §5-§7).
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
--   * 1.5.18 (owner, 2026-10-12): the Torneo PANEL. The entry (this menu's Torneo row) opens the bracket and, centred
--     over it, the window
--     «Continuar el torneo» (the next match) / «Ver el cuadro» (the bracket stays: L1 / R1 pages, Back closes) /
--     «Nuevo torneo» (Yes / No while one runs, then the team grid); Back closes both and leaves the player where he
--     was. No run: «Nuevo torneo» at once = the team grid. The screen it runs on is BattleBayDeluxe.TournamentHost (layers hidden under the
--     bracket, the lists whose focus it takes, the header, the grid, the way back): this menu by default.
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
--   * 2026-10-19 (owner): a knockout of exactly 16 teams on the Victory Road «決勝トーナメント» art; 1.83.0: the tree page
--     (that art, the generic lines of every other size, the advance, the final stadium's panel) is the framework's
--     bracket screen vrfw_bracket_menu (VRFW_Bracket), a draw-only child menu opened over this host (BBT_TreeShow).
--   * 1.45.0 (owner 2026-10-28): the «Liga» (format 2 of the same run: one round robin of 4 .. 36 teams, once or home
--     and away). Its bracket pages are the standings (CMND_BBD_TOURN_VIEW kind "league", 10 + p, drawn in the group
--     stage's own menu like the group tables: BBT_GroupsShow), its results pages the matchday's matches; the panel's
--     texts are the league's (BBT_RunKey); the run ends after the last matchday (first place = champion, the champion
--     screen as the Torneo's).
-- Globals only (BBT_*); nothing runs at chunk load.
BattleBayDeluxe = type(BattleBayDeluxe) == "table" and BattleBayDeluxe or {}
BattleBayDeluxe.Tournament.ARM = @crc:CMND_BBD_TOURN_ARM@
BattleBayDeluxe.Tournament.DISARM = @crc:CMND_BBD_TOURN_DISARM@
BattleBayDeluxe.Tournament.SYNC = @crc:CMND_BBD_TOURN_SYNC@
BattleBayDeluxe.Tournament.VIEW = @crc:CMND_BBD_TOURN_VIEW@
BattleBayDeluxe.Tournament.ABANDON = @crc:CMND_BBD_TOURN_ABANDON@
BattleBayDeluxe.Tournament.CLOSE = @crc:CMND_BBD_TOURN_CLOSE@
BattleBayDeluxe.Tournament.STEP = @crc:CMND_BBD_TOURN_STEP@
BattleBayDeluxe.Tournament.PREPARE = @crc:CMND_BBD_TOURN_PREPARE@
BattleBayDeluxe.Tournament.UNLOAD = @crc:CMND_BBD_TOURN_UNLOAD@
-- the Torneo's grid = the Campaña's grid variant opened through the 1P row's path: the retail WaitExecOtherMenu of
-- enjoy_team_select_menu sends CMND_OPEN_MENU_OBJECT(786045682, 534870484 offline); BBT_OpenGridAsCampaign swaps that
-- one call to 1455139087 (campaign). The game registers funcLuaCommand AFTER the chunk ran, so a wrapper installed at
-- chunk load is overwritten and never runs (BBD 1.5.6: the Torneo opened the 1v1 grid); the swap is a temporary
-- wrapper put in place around that one WaitExecOtherMenu (the retail chunk looks the global up at every call).
-- 1.33.2 (owner 2026-10-23: «nuevo torneo» left the Battle Bay top menu without input): the retail WaitExecOtherMenu
-- makes this menu inactive and waits, without a bound, until the engine reports it settled (667479479), then opens the
-- grid. The same two steps run here first with a bound (BattleBayDeluxe.Tournament.GRID_WAIT_STEPS Steps of the decide coroutine): past it
-- the menu is made active again, its lists get the focus back, the grid is not opened (false: the caller disarms the
-- run). Each step logged once.
BattleBayDeluxe.Tournament.GRID_WAIT_STEPS = 180
function BBT_TopMenuSettled()
  local menu = BattleBayDeluxe.TournamentHost.menu
  local _, main = coroutine.running()
  funcLuaMenuCommand(1558704558 --[[CMND_SET_MENU_ACTIVE?]], menu, false)
  BBT_Log("grid: " .. tostring(BattleBayDeluxe.TournamentHost.name) .. " made inactive, waiting for it to settle")
  for step = 0, BattleBayDeluxe.Tournament.GRID_WAIT_STEPS do
    local ok, busy = pcall(funcLuaCommand, 667479479 --[[menu still changing?]], menu)
    if not ok or busy ~= true then
      BBT_Log("grid: " .. tostring(BattleBayDeluxe.TournamentHost.name) .. " settled after " .. step .. " Step(s)")
      return true
    end
    if main then
      break
    end
    coroutine.yield()
  end
  funcLuaMenuCommand(1558704558 --[[CMND_SET_MENU_ACTIVE?]], menu, true)
  pcall(BattleBayDeluxe.TournamentHost.refocus)
  BBT_Log("grid: " .. tostring(BattleBayDeluxe.TournamentHost.name) .. " did not settle in " .. BattleBayDeluxe.Tournament.GRID_WAIT_STEPS ..
    " Steps: the grid is not opened, the menu is active again")
  return false
end

function BBT_OpenGridAsCampaign()
  if not BBT_TopMenuSettled() then
    return false
  end
  local cmd = funcLuaCommand
  local swapped = false
  local swap
  swap = function(c, a1, a2, ...)
    if not swapped and c == @crc:CMND_OPEN_MENU_OBJECT@ and a1 == 786045682 and a2 == 534870484 then
      swapped = true
      if funcLuaCommand == swap then
        funcLuaCommand = cmd
      end
      -- as the retail Campaña path (label L332): the online team-select flag cleared before the campaign grid
      cmd(VRFW_Cmd.PARAM_DELETE, 357455239)
      BBT_Log("grid: the Campaña variant for the Torneo")
      return cmd(c, a1, 1455139087 --[[enjoy_team_select_menu_campaign]], ...)
    end
    return cmd(c, a1, a2, ...)
  end
  funcLuaCommand = swap
  local ok, err = pcall(WaitExecOtherMenu, 786045682 --[[enjoy_team_select_menu]], BattleBayDeluxe.Tournament.LIST_MID)
  if funcLuaCommand == swap then
    funcLuaCommand = cmd
  end
  if not swapped then
    BBT_Log("grid: no swap (the 1P path did not open the grid variant)")
  end
  if not ok then
    error(err, 0)
  end
  BBT_Log("grid: the retail opener returned")
  return true
end
BattleBayDeluxe.Tournament.RULE_SELECT = @crc:CMND_VRFW_RULE_ENGINE_SELECT@
BattleBayDeluxe.Tournament.RULE_STATE = @crc:CMND_VRFW_RULE_ENGINE_STATE@
BattleBayDeluxe.Tournament.ROW_CAMPAIGN = 4154438766
BattleBayDeluxe.Tournament.LIST_MID = 716364754 --[[mainmenu90_11_list_item_middle]]
BattleBayDeluxe.Tournament.LIST_SMALL = 530619243 --[[mainmenu90_12_list_item_small]]
BattleBayDeluxe.Tournament.TOP = 85255651 --[[bb_stadium_top_menu]]
BattleBayDeluxe.Tournament.ANCHOR = @crc:evt_bbd_tn_anchor@
BattleBayDeluxe.Tournament.FN_PREV = @crc:evt_bbd_tn_prev@
BattleBayDeluxe.Tournament.FN_NEXT = @crc:evt_bbd_tn_next@
-- the bracket layers (content\menus\bb_tournament.toml; 1.5.15: the whole bracket in one view, built from its size)
BattleBayDeluxe.Tournament.L = {
  bg = @crc:vroad04_01_p1_bg@,
  stadium = @crc:vroad01_00_background@,   -- 1.8.0: the Victory Road stadium (opaque) behind the band
  line = @crc:evt_bbd_tn_line@,    -- connector pieces (a tinted white quad)
  row_l = @crc:evt_bbd_tn_row_l@,  -- a team plate, crest left of the name (left side; results / groups; champion)
  row_r = @crc:evt_bbd_tn_row_r@,  -- the mirrored plate (right side)
  txt = @crc:evt_bbd_tn_txt@,      -- free texts: match scores, group titles, results values
  icon = @crc:evt_bbd_tn_icon@,    -- the champion's crown
}
-- instances of each layer (the menu file's counts: the largest bracket, T.MAX_SIZE = 64 teams)
BattleBayDeluxe.Tournament.L.box = @crc:evt_bbd_tn_box@   -- 1.5.24: a score box at a plate's inner end (between the plates and the texts)
-- 1.5.57 (owner in game 2026-10-13 22:41: the Battle Bay top menu stayed WHITE): the engine sets up at most ~844
-- layer instances in one open menu (docs/game/ui/menu-layer-limits.md §2.1-§2.2); past it the menu never finishes
-- opening (its background never ends opening, the retail FadeIn never runs: the title's white fade stays). 1.5.54
-- had raised this menu to 1440 instances (its own group-table layers, row_l 64, txt 336, box 112); 1.5.57 went back
-- to the bracket's own pools. 1.5.60: the group tables are drawn in their own menu (BBT_GroupsShow), so the texts are
-- the bracket's only (txt 64: 63 scores of a 64-team bracket, 64 goals of a 32-match results page). Budget: retail 26
-- + Utilities 269 + this file 484 = 779 in bb_stadium_top_menu (every pool costs its instances at every opening).
-- 1.8.0: box 36 (the stadium's dim + a results page's 32 score boxes, or on a tree the dim, the player's focus
-- band, the stars at the joints (at most 32), the final stadium's panel and picture: at most 36). 1.9.0: the scores
-- are digit sprites on the connector pool (BattleBayDeluxe.Tournament.NUM): line 256 -> 330 (1.12.0; a 64-team tree: 251 pieces + 62 pairs + the
-- final's 2 digits + shoot-outs; a results page: its digits only), txt 66 -> 4 (the final stadium's two lines, the
-- champion screen's two)
-- 1.83.0: the tree page is drawn by the bracket screen vrfw_bracket_menu (its own pools, the retail 16-team art and
-- the final stadium's panel); this menu keeps the pools of the results pages and the champion screen
BattleBayDeluxe.Tournament.N = { line = 330, row_l = 33, row_r = 32, txt = 4, icon = 1, box = 36 }
-- draw priority of a connector-pool quad by what it draws (the layer's own is the connectors' 549; a score box drawn
-- on it where the menu has no box pool: 552, BattleBayDeluxe.Tournament.SHARE)
BattleBayDeluxe.Tournament.PRIO = { line = 549, box = 552 }
-- 1.5.58: a pool a host menu does not have (BattleBayDeluxe.Tournament.N[k] = 0) drawn on another pool of the same object, at its
-- own draw priority (BattleBayDeluxe.Tournament.PRIO[k]), e.g. { box = "line" }. None here: this menu has every pool
BattleBayDeluxe.Tournament.SHARE = {}
BattleBayDeluxe.Tournament.ROW_CHAMP = 32                 -- row_l instance of the champion's plate
BattleBayDeluxe.Tournament.ART = 2658588602               -- crc32("#/menu/220_img/bbd_tn/bbd_tn.g4tx"): the mod's drawings
-- 1.12.0: the score digits' own atlas (a g4tx holds at most 255 sprites; 1.9.0 had them all in bbd_tn: 275, and the
-- game crashed loading it): crc32("#/menu/220_img/bbd_tn_num/bbd_tn_num.g4tx")
BattleBayDeluxe.Tournament.ART_NUM = 1494349866
BattleBayDeluxe.Tournament.SPR_LINE = @crc:bbd_tn_line@
BattleBayDeluxe.Tournament.SPR_CROWN = @crc:bbd_tn_crown@
-- 1.5.37 (owner in game, 2026-10-13: every connector white, the lost branches too): CMND_SET_PRIM_COLOR never tinted
-- these cmn01_10 quads, so each state is a flat quad of its own colour (research/scripts/bbd_bracket_art.py FLAT),
-- drawn with a white tint
BattleBayDeluxe.Tournament.SPR_STATE = {
  plain = @crc:bbd_tn_line_plain@, lit = @crc:bbd_tn_line_lit@, me = @crc:bbd_tn_line_me@,
  out = @crc:bbd_tn_line_out@, out_me = @crc:bbd_tn_line_out_me@,
  win = @crc:bbd_tn_line_lit@, lose = @crc:bbd_tn_box_lose@, even = @crc:bbd_tn_box_even@,
}
-- 1.8.0 (owner 2026-10-21: the bracket in the Victory Road look; research/scripts/bbd_bracket_art.py): a lit piece is
-- a white core with a halo across its thickness, one sprite per direction (gold; the player's own path cyan); the
-- unlit pieces navy (bbd_tn_line_plain), a lost way dark (out / out_me)
BattleBayDeluxe.Tournament.SPR_HALO = {
  lit = { h = @crc:bbd_tn_lit_h@, v = @crc:bbd_tn_lit_v@ },
  me = { h = @crc:bbd_tn_me_h@, v = @crc:bbd_tn_me_v@ },
}
BattleBayDeluxe.Tournament.SPR_STAR = @crc:bbd_tn_star@      -- the glow at the joint a team waits at (the Victory Road star)
BattleBayDeluxe.Tournament.SPR_FOCUS = @crc:bbd_tn_focus@    -- the player's focus band behind his plate
BattleBayDeluxe.Tournament.SPR_PANEL = @crc:bbd_tn_panel@    -- the final stadium's translucent panel
BattleBayDeluxe.Tournament.SPR_DIM = @crc:bbd_tn_dim@        -- the Victory Road stadium dimmed under a page (one box-pool quad)
-- the team strips in the order of scripts/lib/plate_colors.lua M.names (a plate's .strip = its 1-based index): the
-- list plate's own sprite (list_base_xs01_off of team06_02.g4tx) swapped for the team's strip (CMND 558735651)
BattleBayDeluxe.Tournament.SPR_STRIP = {
  @crc:bbd_tn_strip_red@, @crc:bbd_tn_strip_orange@, @crc:bbd_tn_strip_yellow@, @crc:bbd_tn_strip_green@,
  @crc:bbd_tn_strip_cyan@, @crc:bbd_tn_strip_blue@, @crc:bbd_tn_strip_purple@, @crc:bbd_tn_strip_pink@,
  @crc:bbd_tn_strip_black@, @crc:bbd_tn_strip_silver@,
}
BattleBayDeluxe.Tournament.PLATE_SPRITE = @crc:list_base_xs01_off@
BattleBayDeluxe.Tournament.PLATE_ATLAS = 143680280            -- crc32("#/menu/102_team/team06/team06_02/team06_02.g4tx")
BattleBayDeluxe.Tournament.WHITE = { 1, 1, 1 }
BattleBayDeluxe.Tournament.MESH_QUAD = 312193881 --[[_icon_new01]]
BattleBayDeluxe.Tournament.NODE_QUAD = 1909474081 --[[icon_new01]]
-- 1.9.0 (owner 2026-10-21, on a crop of the Victory Road bracket: «Deberían verse así los resultados»): a played
-- match's result is the two entrants' goals STACKED just past its joint, the upper entrant's over the lower's with the
-- joint's outgoing line between them, the winner's gold and the loser's dark: one connector-pool quad showing a pair
-- sprite bbd_tn_pr_<upper>_<lower>_<winner 1 / 2> (a number of two digits: single digits above / below); a
-- shoot-out: the kicks as smaller digits beside each; the final: the two goals left / right below the centre; the
-- results page: single digits in its boxes (research/scripts/bbd_bracket_art.py draws them; W / H / GAP / PAIR_H =
-- its DIGIT_W / DIGIT_H / PAIR_GAP / PAIR_H). HEIGHT = a digit's height of the plates' pitch (H_MIN .. H_MAX px),
-- SPACE = the gap from the joint (digit units), ADV = a digit's advance in a row, PRIO = in front of the connectors
-- 1.33.0 (owner 2026-10-23): GAP wide enough for the lit line between the two numbers at every digit height; the
-- loser's digits light blue («blue», was a dark navy lost on the panel)
BattleBayDeluxe.Tournament.NUM = { W = 22, H = 29, GAP = 32, PAIR_H = 90, HEIGHT = 0.55, H_MIN = 13, H_MAX = 26, SPACE = 4, ADV = 0.78,
  PEN_S = 0.75, FINAL_S = 1.3, BOX_FILL = 0.72, PRIO = 548 }
-- the plate's four looks (team06_02): off = light (a team), on = blue (the player), ok = cyan (the champion), ol =
-- the focus outline (never shown here)
BattleBayDeluxe.Tournament.PLATE = { off = @crc:_list_base_xs01_off@, on = @crc:_list_base_xs01_on@, ok = @crc:_list_base_xs01_ok@,
  ol = @crc:_list_base_xs01_ol@ }
BattleBayDeluxe.Tournament.MESH_EMBLEM = @crc:_icon_emblem_dmy01@   -- its crest: VRFW_Team.Emblem
BattleBayDeluxe.Tournament.TXT_ON = @crc:_text_list01_on@     -- white (on the blue / cyan plates)
BattleBayDeluxe.Tournament.TXT_OFF = @crc:_text_list01_off@   -- blue (on the light plate)
BattleBayDeluxe.Tournament.STYLE_TXT = 187454762              -- fs_28_w_cc_2d2_001: centred white, outlined (scores, titles)
BattleBayDeluxe.Tournament.C = {
  VISIBLE = @crc:CMND_SET_LAYER_VISIBLE@, POS = @crc:CMND_SET_LAYER_LOCAL_POS@, SCALE = @crc:CMND_SET_LAYER_LOCAL_SCALE@, SPRITE = 558735651, PRIM_COLOR = @crc:CMND_SET_PRIM_COLOR@,
  MESH_VISIBLE = @crc:CMND_SET_MESH_VISIBLE@, TEXT = @crc:CMND_SET_MENU_TEXT_STRING@, TEXT_VISIBLE = @crc:CMND_SET_MENU_TEXT_VISIBLE@, TEXT_STYLE = 2333948100,
}
-- the geometry, screen px (y down) of the 1920 x 1080 menu camera; research/scripts/bbd_bracket_art.py draws the
-- same numbers in its preview. Rows: the plates of one side share the height TOP..BOTTOM (pitch = height / rows),
-- the plate scaled to FILL of the pitch (at most SCALE_MAX); the junction of round r at (CX - xe) * r / R from the
-- plates' edge (+ GAP), so the final meets in the middle (CX) and its stem goes up to the champion's plate.
BattleBayDeluxe.Tournament.G = {
  W = 1920, TOP = 136, BOTTOM = 1004, MARGIN = 34, CX = 960, PLATE_W = 520, PLATE_H = 72, FILL = 0.84,
  SCALE_MAX = 1.0, GAP = 16, Q = 36, LINE = 6, LINE_LIT = 10, CHAMP_Y = 176, CHAMP_S = 0.85, CROWN_W = 72,
  CROWN_H = 54, SCORE_DY = 18, TXT_MIN = 0.62, TXT_MAX = 0.9,
  -- 1.8.0: the trophy's centre on the generic tree (the retail trophy in place of the crown, BBT_TrophyPlace); a
  -- star's size = STAR of the plates' pitch (STAR_MIN .. STAR_MAX px); the focus band = FOCUS_W x FOCUS_H of the plate
  TROPHY_Y = 300, STAR = 1.8, STAR_MIN = 32, STAR_MAX = 64, FOCUS_W = 1.2, FOCUS_H = 1.7,
  -- 1.33.0 (owner 2026-10-23: the 32 / 64-team trees with the 16-team tree's rounded lines): LINE = the retail tree's
  -- thickness (vroad04_01 tournament01), a stub's turn to its joint on a TURN_R corner, its sprite TURN_LEN px of
  -- straight line long (research/scripts/bbd_bracket_art.py TURN_R / TURN_LEN: keep in sync)
  TURN_R = 8, TURN_LEN = 120,
  -- 1.35.0: the retail trophy's cup ends this far below its node (vroad04_02 _vic_trophy01: top 87, 176 tall); the
  -- generic tree's stem stops there
  TROPHY_CUP_BOTTOM = 89,
  COL = { 0.66, 0.78, 0.95 }, COL_LIT = { 1.0, 0.80, 0.24 }, DIM = 0.5,
  -- the Victory Road background (vroad04_01_p1: one translucent navy panel, 2004 x 724 at y 178 below its origin)
  -- stretched to hold the whole bracket: BG_TOP .. BG_BOTTOM
  BG_Y = 178, BG_H = 724, BG_TOP = 100, BG_BOTTOM = 1036,
  -- layer draw priorities (a higher priority draws in front): the stadium (BBT_Open) and its dim under the retail
  -- band (195) and bracket art (196-203); the focus band and the star glows under the connectors (549) and plates (551)
  PRIO_STADIUM = 190, PRIO_DIM = 192, PRIO_BACK = 546,
  -- results (8 matches: two columns of 4, the two plates of a match one above the other); the group tables: their own
  -- menu (BBT_GroupsShow)
  RES_X = 190, RES_TOP = 196, RES_MATCH = 196, RES_ROW = 80, RES_VAL = 56,
}
-- the top menu's own layers hidden under the overlay (the retail lists of WaitExecOtherMenu)
BattleBayDeluxe.Tournament.TOP_LAYERS = {
  766432831 --[[mainmenu90_35_cross_play_guide]],
  1611500684 --[[mainmenu90_06_content_guide_line03]], 1597333599 --[[mainmenu90_25_list_item_locator]],
  716364754 --[[mainmenu90_11_list_item_middle]], 530619243 --[[mainmenu90_12_list_item_small]],
  3687874606 --[[mainmenu90_24_tutorial_button]], 4096284290 --[[mainmenu90_24_02_play_guide_button]],
  429081730 --[[vs01_21_room_setting_button]], 2575749231 --[[vs11_01_next_stage_guide]],
}
-- 1.5.18: the screen the Torneo runs on (the Battle Bay top menu). hide = layers made invisible under the bracket (every instance),
-- close = layers closed / reopened (the retail SwitchLayerOpenOrClose way), lists = control focus taken while the
-- bracket is up, step = the top bar step answered here (nil: none)
BattleBayDeluxe.TournamentHost = {
  name = "bb_stadium_top_menu", menu = 85255651, hide = {}, close = BattleBayDeluxe.Tournament.TOP_LAYERS,
  lists = { 716364754 --[[mainmenu90_11_list_item_middle]], 530619243 --[[mainmenu90_12_list_item_small]] },
  step = "bb_tournament",
  -- the page title in the menu's header (the BB header type 30); «Modos de juego» keeps its own header (1.5.19)
  title = function(t)
    pcall(SwapSoccerTopCommonHeaderByHeaderType, 30, t)
  end,
  header = function()
    pcall(SwapSoccerTopCommonHeaderByHeaderType, 30, funcLuaCommand(@crc:CMND_TEXT_GET@, 3066112094))
  end,
  -- the focus back on the «Campaña» row, the one the overlay was entered from (BBT_FocusCampaignRow)
  refocus = function()
    BBT_FocusCampaignRow()
  end,
  ready = function()
    return funcLuaMenuCommand(@crc:CMND_IS_CTRL_FOCUS_ACTIVE@, BattleBayDeluxe.Tournament.LIST_MID) == true
  end,
  open_grid = function()
    return BBT_OpenGridAsCampaign()
  end,
  -- 1.37.0 (owner 2026-10-23: «quita guía de controles en este menú y en el del cuadro de torneo»): while the overlay
  -- is up the footer shows only the retail «Aceptar» (its Enter), without the other mods' prompts (BetterUI's «Guía de
  -- controles»; the anchor has no row for that key); closed, the menu's own guide again (its prompts included)
  guide = function(open)
    local GUIDE = 1138543975 --[[mainmenu01_06_base_button_guide]]
    if open then
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, GUIDE, 0, true)
      funcLuaMenuCommand(2209673388 --[[guide entries]], BattleBayDeluxe.TournamentHost.menu, GUIDE, { 1847312674 --[[Accept]] },
        { 2750714971 --[[<CMD_ENTER>]] }, { 0 }, { 0 }, { 0 })
      funcLuaMenuCommand(452337289 --[[guide commands]], BattleBayDeluxe.TournamentHost.menu, GUIDE, { 1981080283 --[[CMD_ENTER]] })
    elseif type(UpdateButtonGuide) == "function" then
      UpdateButtonGuide(true)
    end
  end,
  before_match = function() end,
}

-- open / close every instance of the layers (soccer_top_menu has no SwitchLayerOpenOrClose of its own)
function BBT_SwitchLayers(t, open)
  for _, l in ipairs(t or {}) do
    local n = funcLuaMenuCommand(@crc:CMND_GET_CREATE_LAYER_NUM@, l) or 0
    for i = 0, n - 1 do
      if open then
        funcLuaMenuCommand(@crc:CMND_OPEN_LAYER@, l, i)
      else
        funcLuaMenuCommand(@crc:CMND_CLOSE_LAYER@, l, i)
      end
    end
  end
end

function BBT_ShowLayers(t, on)
  for _, l in ipairs(t or {}) do
    local n = funcLuaMenuCommand(@crc:CMND_GET_CREATE_LAYER_NUM@, l) or 0
    for i = 0, n - 1 do
      funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, l, i, on)
    end
  end
end

BattleBayDeluxe.TournamentState = { open = false, view = nil, page = -1, want = false, frames = 0, co = nil, busy = false, step = false,
  sync = false, sync_frames = 0, emb = {}, used = {}, taken = {}, entry = false }

-- ------------------------------------------------------------------------------------------------ the sync

-- the tournament takes the last match's result (the rule engine's STATE) before the retail OnInit reads the block
function BBT_Sync()
  local st = { pcall(funcLuaCommand, BattleBayDeluxe.Tournament.RULE_STATE) }
  local args = {}
  if st[1] == true then
    for i = 2, 9 do
      args[#args + 1] = st[i]
    end
  end
  local r = BBT_Call(BattleBayDeluxe.Tournament.SYNC, table.unpack(args, 1, 8))
  if type(r) ~= "table" then
    return false
  end
  BBT_Log("sync", r.event, r.show)
  if r.show then
    BattleBayDeluxe.TournamentState.want = true
    BattleBayDeluxe.TournamentState.frames = 0
  end
  -- an armed tournament that never started (the grid left without a start) is disarmed here
  local info = BBT_Info()
  if info.armed then
    BBT_Call(BattleBayDeluxe.Tournament.DISARM)
    pcall(funcLuaCommand, BattleBayDeluxe.Tournament.RULE_SELECT, "")
  end
  return true
end
