-- bb_chronicle_teams bb_draft, Campaña grid (enjoy_team_select_menu_campaign; docs/game/modes/estadio-bb.md §14).
-- The first tile of «Equipos principales» is the team evt_bbd_draft (the mod's teams/50_draft.toml). Deciding it
-- (instead of the retail difficulty window) opens the Draft screen, laid out like «Plantilla de equipo» (v4, 2026-10-02, §14.11):
--   * RIGHT: the 16 slots on the 16 cards evt_bb_draft_slot (the formation panel's card objbin), placed by the graft:
--     the 11 field slots by their formation position (keeper at the bottom, forwards at the top) over the whole height
--     of the right half, the bench (5) in a column right of them. Behind them the panel's pitch (the frame
--     vs01_46_enjoy_team_select_formation_frame_left with its lines) moved and stretched to the same area; the panel's
--     own 11 cards are hidden while the screen is open. An empty slot is a normal player card (the slot's placeholder
--     drawn by the retail card command: its position colour, no coach frame) with face, element, position, level,
--     captain, frames and name hidden and the «?» glyph of num_menu01 on the card's centred mesh; bench slots (any
--     position) get the retail grey card base;
--   * LEFT: where the pitch was (the panel's tactics and «TÁCTICAS» hidden for the screen), the 5 candidate cards of
--     the chosen slot (evt_bb_draft_card, drawn larger) in a column; since 1.5.26 they are shown as a «pack opening»
--     instead (BBCR_DRAFT_PK: a darkened screen, a band across it, the 5 dealt face down and turned one by one, then
--     picked on the band; the column layout is only the fallback when the pack fails);
--   * the crest grid, its lock icons and the «Página» line are hidden while the screen is open; while it is open the
--     native panel refresh (UpdateFormation / UpdateTacticsLayer on focus changes) is held so it cannot hide the pitch;
--   * the player moves the cursor over the pitch / bench (arrows) and presses Enter on an empty slot: 5 candidates of
--     that position (any position on the bench, CMND_BBCR_DRAFT_CANDS); Up / Down (or Left / Right) + Enter picks
--     one (CMND_BBCR_DRAFT_PICK: the loader writes him into the Draft team's roster rows). The pick cannot be left
--     (2026-10-02, Nacho): Back plays the retail NG sound and shows «Elige uno de los 5» on the guide line (the loader
--     keeps each slot's 5 once rolled anyway). Slots in any order;
--   * the cards are the formation cards (2026-10-02): the panel's objbin team00_01_chara_card_for_formation_evt (Clean
--     HUD's object), registered with Inazuma Fantasy's position_cards when it runs (EVT_FC_EXTRA) for the dock-card
--     look (no level, no name, shadowless base, colour by position), at the size of the formation screen (FC_SCALE 1.05, the dock's x1.05);
--   * 16 filled: «¿Empezar la campaña con este equipo?» on the guide line (Enter = the retail difficulty window, then
--     the campaign); Back on the pitch: the retail Sí / No window «¿Quieres abandonar el draft?» (No focused).
-- Input: the layer evt_bb_draft_anchor (off screen) holds the control focus: Enter / Back reach OnDecideFocus / OnBack,
-- the arrows OnFunction(evt_bbd_up/down/left/right); the retail cursor is moved onto the selected card.
-- Layer instances live as long as the menu (open / close only change their state): the card name table
-- (NameSetting_CharaCardForSoccer) is written ONCE per instance. The engine's begin command (0xA1D31171) does not
-- reset the entry counters of the instance's CMenuNamingSetting, so a second name setting writes past the new arrays
-- and corrupts the heap (v3: entering the Draft a second time hung in malloc).
-- Leaving the screen puts the panel back (pitch left, tactics), gives the grid back as after the retail difficulty
-- window, then (a few frames later, the Draft layers closed) rebuilds the page like a page turn
-- (CMND_VRFW_BB_PAGE_REFRESH + the 28 emblems redrawn and reloaded) and puts the focus back on the Draft tile. Without
-- the loader's draft the tile does nothing. Globals only; nothing at chunk load.
-- 1.5.42 (owner: «el Draft no funciona en el 1 vs 1»): the same block runs on the free-match grid
-- (enjoy_team_select_menu_offline, BBCR_DRAFT_HOST = "free_match" set by bbd_offline.lua before it; config.toml
-- [draft] modes). There the retail decide of a tile never reaches the Lua: scripts\campaign.lua routes the Draft
-- tile's decide here when no complete draft is on the rows (else the retail decide records the Draft team as 1P /
-- CPU at once). Differences of the free match: the side being chosen (1P left / CPU right) is the side whose panel
-- the native refresh last drew the Draft team on (BBCR_DRAFT.side); while the screen is open every other panel part
-- (the other side's cards, frame, team plate, tactics, the name plates, the ready balloons, the option buttons) and
-- the grid are hidden and put back exactly as they were (CMND_IS_LAYER_VISIBLE, BBCR_DRAFT.stash); the start
-- question is «¿Jugar con este equipo?» and Enter makes the tile's retail decide (CMND_BBD_DRAFT_DECIDE, after the
-- page is rebuilt): the Draft team becomes 1P / CPU and the match is set up as with any team.
BBCR_DRAFT = {
  INFO = @crc:CMND_BBCR_DRAFT_INFO@,
  BEGIN = @crc:CMND_BBCR_DRAFT_BEGIN@,
  SLOTS = @crc:CMND_BBCR_DRAFT_SLOTS@,
  SLOT_INFO = @crc:CMND_BBCR_DRAFT_SLOT@,
  CANDS = @crc:CMND_BBCR_DRAFT_CANDS@,
  PICK = @crc:CMND_BBCR_DRAFT_PICK@,
  ABANDON = @crc:CMND_BBCR_DRAFT_ABANDON@,
  DECIDE = @crc:CMND_BBD_DRAFT_DECIDE@,
  PAGE_SLOT = @crc:CMND_VRFW_BB_PAGE_SLOT@,
  PAGE_REFRESH = @crc:CMND_VRFW_BB_PAGE_REFRESH@,
  LOG = 3661580131 --[[CMND_EVT_LOG]],
  TEAM = @crc:evt_bbd_draft@,
  MENU = 786045682 --[[enjoy_team_select_menu]],
  GRID = 106197494 --[[vs01_43_enjoy_team_select_emblem_icon]],
  ATTACH = 2994917936 --[[vs01_42_enjoy_team_select_emblem_attach_base]],
  LOCK = 892105257 --[[mainmenu90_30_lock_icon]],
  DIFFWIN = 2996147312 --[[win05_11_select_difficulty_win_base]],
  LEFT = 3003299608 --[[team00_01_chara_card_left]],
  RIGHT = 3825623416 --[[team00_01_chara_card_right]],
  -- free match: what the Draft screen hides besides the grid (put back as it was): the other side's panel, the name
  -- plates, the ready balloons, the game option buttons
  FREE_HIDE = {3825623416 --[[team00_01_chara_card_right]], 187604095 --[[vs01_46_enjoy_team_select_formation_frame_right]],
               2708277675 --[[vs01_45_p1_enjoy_team_select_teamInfo]], 909193856 --[[soccer08_12_tactics_cmd_right]],
               4074949471 --[[team00_10_tactics_base_right]], 4211334321 --[[soccer00_40_username_left]],
               1262779231 --[[soccer00_40_username_right]], 66400840 --[[vs01_29_ready_ok_balloon_left]],
               2413676297 --[[vs01_29_ready_ok_balloon_right]], 2313398190 --[[vs01_49_soccer_game_option_list_button]],
               429081730 --[[vs01_21_room_setting_button]]},
  FRAME = 1324325467 --[[vs01_46_enjoy_team_select_formation_frame_left]],
  M_FIELD = 832482535 --[[_formation_field_s01: the frame's pitch]],
  FRAME_NODES = {2654143900 --[[_pos_formation01_cc]], 2278526192 --[[_pos_formation01_ld]],
                 960402397 --[[_pos_formation01_ru]]},
  TEAMINFO = 2945114490 --[[vs01_44_p1_enjoy_team_select_teamInfo]],
  M_TACTICS_LABEL = 1145084495 --[[_gtxt_tactics01: «TÁCTICAS»]],
  TACTICS_BASE = 996660679 --[[team00_10_tactics_base_left]],
  TACTICS_CMD = 2312417854 --[[soccer08_12_tactics_cmd_left]],
  SLOT = @crc:evt_bb_draft_slot@,
  CARD = @crc:evt_bb_draft_card@,
  ANCHOR = @crc:evt_bb_draft_anchor@,
  FN_UP = @crc:evt_bbd_up@,
  FN_DOWN = @crc:evt_bbd_down@,
  FN_LEFT = @crc:evt_bbd_left@,
  FN_RIGHT = @crc:evt_bbd_right@,
  GUIDE = 618184632 --[[mainmenu01_06_base_button_guide_right]],
  GUIDE_TEXT = 378156699 --[[_text_guide01]],
  CURSOR = 2296367164 --[[cmn05_01_cursor]],
  GRID_CURSOR = 3313461902 --[[cursor]],
  CARD_CURSOR = 945715707, CARD_CURSOR2 = 1967169874, -- the card objbin's cursor labels
  EMBLEM_TEX = 618311715 --[[enjoy_list_icon_dmy01]],
  EMBLEM_NODE = 3933090681 --[[_pos_enjoy_list01]],
  -- card meshes (NameSetting_CharaCardForSoccer names, L and S): the season tag / lock the retail panel hides, the
  -- focus frame, what a drafted card shows and an empty one hides, the staff / extra marks an empty card never shows
  -- (coach frame + «ENTRENADOR», AI role, synergy, team dock), the card base and the centred «?» mesh
  M_TAG = {@crc:_icon_card01@, @crc:_icon_card02@, @crc:_icon_lock01@, @crc:_icon_lock02@},
  M_FOCUS = {@crc:_icon_chr_focus_l01@, @crc:_icon_chr_focus_s01@},
  M_FACE = {@crc:_icon_chr_dmy_l01@, @crc:_icon_chr_dmy_s01@, @crc:_icon_chr_type_dmy_l01@, @crc:_icon_chr_type_dmy_s01@,
            @crc:_icon_base_l01@, @crc:_icon_base_s01@, @crc:_icon_chr_position_dmy_l01@, @crc:_icon_chr_position_dmy_s01@,
            @crc:_icon_chr_gradation_l01@, @crc:_icon_chr_gradation_s01@},
  M_EMPTY = {@crc:_num_chr_dmy_l01@, @crc:_num_chr_dmy_l02@, @crc:_num_chr_dmy_s01@, @crc:_num_chr_dmy_s02@,
             @crc:_gtxt_lv_l01@, @crc:_gtxt_lv_s01@, @crc:_icon_captain01@, @crc:_icon_captain02@,
             @crc:_icon_chr_grayout01@, @crc:_icon_chr_grayout01_s@, @crc:_seasonal_frame_l01@, @crc:_seasonal_frame_s01@,
             @crc:_avatar_frame_l01@, @crc:_avatar_frame_s01@, @crc:_basara_avatar_l01@, @crc:_basara_avatar_s01@},
  M_STAFF = {@crc:_leader_base01@, @crc:_leader_base02@, @crc:_gtxt_leader01@, @crc:_gtxt_leader02@,
             @crc:_icon_ai_role_dmy01@, @crc:_icon_ai_role_dmy02@, @crc:_icon_synergy_l01@, @crc:_icon_synergy_l02@,
             @crc:_icon_synergy_s01@, @crc:_icon_synergy_s02@, @crc:_icon_teamdock01@},
  N_STAFF = {@crc:_pos_leader01@, @crc:_pos_leader02@, @crc:_pos_ai_role01@, @crc:_pos_ai_role02@},
  M_BASE = {@crc:_icon_chr_base_l01@, @crc:_icon_chr_base_s01@},
  M_DEF = {@crc:_icon_chr_def01_l@, @crc:_icon_chr_def01_s@},
  -- card size (v5, 2026-10-06): every Draft card is the SMALL formation card (card command bigtype false, as the
  -- panel's bench; the layout constants below are measured for it). The objbin holds both cards (_pos_base01 large,
  -- _pos_base02 small); the native draw only switches the meshes it manages, so a mesh the graft turns on must be the
  -- small one (index SZ of the L / S pairs above) and its large twin is turned off: v4 turned both on (empty card =
  -- the large base + large «?» mesh with the small focus frame inside it; the focused card got the large focus frame
  -- around the small one).
  SZ = 2,
  -- 1.5.52 (owner: the pack's cards as BetterUI's cards of the bank / lists): the 5 candidates (layer evt_bb_draft_card)
  -- are the LARGE formation card (card command bigtype true, the card the bank grid draws: landscape plate, bust
  -- portrait, element bottom left, position bottom right, no name / level); the 16 slots stay small (SZ).
  -- BBCR_DRAFT_Sz(layer) gives the index of the L / S pairs for a layer.
  SZ_CARD = 1,
  -- the «?» (num_menu01_01_q, 60 x 88 px) at native size, centred on the small card: the centred mesh
  -- _icon_chr_def01_s (108 x 99 in team00_01_evt_fc, centred on (0, 0) of _pos_chr02) is resized to the glyph
  -- (node scale = mesh size in px, node translation = its top-left corner); v4 stretched it over the whole mesh
  Q_W = 60, Q_H = 88, Q_SCALE = 1,
  Q_SCALE_L = 1.2, -- the «?» on the large card (_icon_chr_def01_l 156 x 120, centred on (0, 0) of _pos_chr01 too)
  NODE_POS = 2575768773 --[[(layer, idx, node, axis 0/1/2, value): local node translation]],
  NODE_SCALE = 2885415772 --[[(layer, idx, node, sx, sy): local node scale]],
  -- sprite swap 558735651 (layer, texture file, sprite, material texture, 0, idx): retail sprites only
  TEX_CARD = 4225297828 --[[#/menu/102_team/team00/team00_01/<LG>/team00_01.g4tx]],
  TEX_NUM = 1677382518 --[[#/menu/200_icon/100_num/num_menu01.g4tx (MENU_RES of this menu)]],
  SPR_GREY = 1967881488 --[[icon_chr_grayout01_s: the small card's grey (136 x 100; v4 put the large
                           icon_chr_base01_type_gray01, 212 x 132, on the small mesh)]],
  SPR_GREY_L = 2195302709 --[[icon_chr_base01_type_gray01: the large card's grey (212 x 132), the pack's backs]],
  SPR_Q = 3747115962 --[[num_menu01_01_q]],
  SLOT_BASE = {840912853 --[[icon_chr_base01_l01]], 627420056 --[[icon_chr_base01_s01]]},
  SLOT_DEF = {4281540162 --[[icon_chr_def01_l]], 1916474295 --[[icon_chr_def01_s]]},
  T_NAME = @crc:_text_chr01@,
  TXT_POS = {[0] = @crc:evt_bbd_pos_0@, @crc:evt_bbd_pos_1@, @crc:evt_bbd_pos_2@, @crc:evt_bbd_pos_3@, @crc:evt_bbd_pos_4@},
  TXT_SHORT = {@crc:evt_bbd_short_1@, @crc:evt_bbd_short_2@, @crc:evt_bbd_short_3@, @crc:evt_bbd_short_4@},
  TXT_SLOT = @crc:evt_bbd_slot@,
  TXT_PLAYER = @crc:evt_bbd_player@,
  TXT_START = @crc:evt_bbd_start@,
  TXT_START_MATCH = @crc:evt_bbd_start_match@, -- the free match's question
  TXT_QUIT = @crc:evt_bbd_quit@,
  TXT_QUIT_ASK = @crc:evt_bbd_quit_ask@, -- two lines: the question, «Se perderán tus elecciones.»
  TXT_PICK_ONE = @crc:evt_bbd_pick_one@,
  SE_NG = 2086672038 --[[sy0003]],
  QUIT_CLOSE_MAX = 120, -- frames the Sí / No window may take to report closed
  TXT_KEYS = @crc:evt_bbd_keys@,
  TXT_ERROR = @crc:evt_bbd_error@,
  -- layout, menu px (x from the left, y 0 at the top edge and negative downwards; docs/game/modes/estadio-bb.md
  -- §14.11). The pitch: field x -700..700 -> card centre x PITCH_CX +- 0.42 * 700 (856..1444); field y 150 (forwards)
  -- .. 900 (keeper) -> card centre y -190 .. -840: the whole height under the header, the keeper at the bottom.
  -- Small cards at 0.8 (109 x 80): the diamond's 100-unit rows are 87 px apart, its columns 126 px.
  -- Cards at the formation screen's size (FC_SCALE: the dock pitch holder's x1.05, ui-redesign.md 3.4): 143 x 105.
  -- The diamond's columns 150 px apart (PITCH_KX 0.5), its 100-unit rows 85 px.
  FC_SCALE = 1.05,
  PITCH_CX = 1150, PITCH_KX = 0.5, MIRROR = 1, PITCH_TOP = -195, PITCH_BOTTOM = -835, FIELD_TOP = 150,
  FIELD_BOTTOM = 900, SLOT_SCALE = 1.05,
  -- the panel's pitch (frame field x -206..206, y +166..-226 around its attach point (240, -350)) moved by
  -- (FRAME_DX, FRAME_DY) and stretched by (FRAME_SX, FRAME_SY): field x 728..1572, y -130..-890, under the cards
  FRAME_DX = 910, FRAME_DY = -102, FRAME_SX = 2.05, FRAME_SY = 1.94,
  -- bench: a column right of the pitch
  BENCH_X = 1680, BENCH_Y = -260, BENCH_DY = -135,
  BENCH_GREY = true, -- bench slots (any position): the grey card base instead of the placeholder's position colour
  -- candidates: a column on the left, where the pitch was (the same formation card at the same size; the retail
  -- cursor marks the chosen one): screen y 158 .. 862, clear of the header and of the team name bar (y 894)
  CAND_X = 250, CAND_Y = -210, CAND_DY = -150, CARD_SCALE = 1.05, CARD_SCALE_ON = 1.05,
  PRIO = 700,
  ANCHOR_X = -4000, ANCHOR_Y = 4000,
  REFRESH_FRAMES = 8,
  REAPPLY_FRAMES = 30, -- an empty card is re-hidden for this many frames (a late texture load may show a mesh again)
  PROBE_FRAMES = 12, -- the frame's pose is logged this many frames after the screen opened (layout check in the log)
  LEVEL = 40,
  -- state
  mode = nil, tile = -1, sel = 0, csel = 0, k = -1, shown = nil, formation = 0,
  slots = {}, cands = {}, pos = {}, where = {}, ready = {}, slotArgs = {}, opened = false, used = false, bypass = false,
  refresh = nil, reapply = nil, probe = nil, quitCo = nil,
  named = {}, -- card instances whose name table is written (never cleared: the instances live as long as the menu)
  pk = nil, -- the candidates' «pack opening» while it runs / is shown (BBCR_DRAFT_PackStart)
  -- free match (1.5.42): the side being chosen (true = 1P, left), the team each side's panel last showed (native
  -- draws), our own panel calls in progress, the hidden layers to put back, the tile's retail decide pending
  side = true, drawn = {}, ours = false, stash = {}, autoDecide = false,
}

-- the screen runs on the free-match grid (bbd_offline.lua sets BBCR_DRAFT_HOST before this block)
function BBCR_DRAFT_Free()
  return BBCR_DRAFT_HOST == "free_match"
end

-- the candidates' «pack opening» (1.5.26, owner: «estilo muy FIFA»): the screen darkens, a band opens across it, the 5
-- cards (evt_bb_draft_card, drawn larger on the band) are dealt face down (the empty slot's «?» card) and turned one by
-- one, lowest card rarity first (chara_param col 41, CMND_GET_CHARA_INFO 8); a unique best card is turned last after a
-- pause, with a gold glow, a whole-screen flash and its own sound. Then the 5 stay on the band to pick (the chosen one
-- raised); Enter / Back during the animation show all 5 at once. A pick flies the card to its slot and the screen
-- comes back. Layers evt_bbd_pk_quad / _txt (content\menus\bb_draft.toml); timings, darkness, size and sounds from
-- config.toml [draft.pack] (CMND_BBD_DRAFT_PACK; these defaults without it). Frames at 60 a second.
BBCR_DRAFT_PK = {
  CMD = @crc:CMND_BBD_DRAFT_PACK@,
  QUAD = @crc:evt_bbd_pk_quad@,
  TXT = @crc:evt_bbd_pk_txt@,
  -- 1.5.38 (owner in game: a WHITE screen behind the 5, white band, the texts outlined on white):
  -- CMND_SET_PRIM_COLOR never tints the cmn01_10 quad's mesh (as the Torneo's connectors, bb-tournament.md §6.1b), so
  -- the one white sprite tinted per part stayed white. Each part is now a pre-coloured flat sprite of the mod's own
  -- atlas (research/scripts/bbd_pack_art.py, content/images/menu/220_img/bbd_pk.toml), faded with
  -- CMND_SET_LAYER_MODEL_ALPHA (the retail locked-dock fade, the friends panel's quads).
  ART = 1048010258 --[[#/menu/220_img/bbd_pk/bbd_pk.g4tx]],
  MESH_QUAD = 312193881 --[[_icon_new01]],
  NODE_QUAD = 1909474081 --[[icon_new01]],
  TXT_ON = @crc:_text_list01_on@, TXT_OFF = @crc:_text_list01_off@,
  STYLE = 187454762 --[[fs_28_w_cc_2d2_001: centred white, outlined]],
  TXT_TITLE = @crc:evt_bbd_pack_title@, TXT_SKIP = @crc:evt_bbd_pack_skip@, TXT_PICK = @crc:evt_bbd_pack_pick@,
  -- commands (the Torneo's quads: research/grafts/bb_tournament)
  VISIBLE = 711242136, POS = 1389957207, SCALE = 3778714801, SPRITE = 558735651, PRIM_COLOR = 855211291,
  PRIM_ALPHA = 2219773080, TEXT = 1083631230, TEXT_VISIBLE = 1505208242, TEXT_STYLE = 2333948100,
  TEXT_ALPHA = 1126837159, MODEL_ALPHA = 4231609516, PRIO = 1491630496, CHARA_INFO = 4060384944, SE = 1917805374,
  Q = 36, -- the quad's size in px at scale 1
  -- quad instances and their draw priorities (the pitch cards: 700; the 5 cards: CARD_PRIO; the cursor: 999)
  I_DIM = 0, I_BAND = 1, I_EDGE = 2, I_GLOW = 4, I_FLASH = 9, I_SCREEN = 14, N_QUAD = 16, N_TXT = 7,
  CARD_PRIO = 720,
  -- the look: seconds, darkness, size (the defaults of config.toml [draft.pack])
  intro = 0.25, deal = 0.22, deal_stagger = 0.07, flip = 0.22, settle = 0.12, flash = 0.30, gap = 0.45,
  suspense = 0.40, outro = 0.28, dim = 0.72, scale = 1.6, spacing = 330,
  se_open = 3848881948 --[[sy0000]], se_deal = 2629173176 --[[sy0009]], se_reveal = 4235359837 --[[sy0010]],
  se_best = 766561556 --[[sy0080]],
  FPS = 60, CX = 960, CY = 540,
  -- the LARGE card at scale 1 (1.5.52; Clean HUD / BetterUI's team00_01_evt_fc: body _touch_chr01 154 x 116, centred
  -- on the layer's origin; the small card before: 120 x 112, 4 px right / 7 px down)
  CARD_W = 154, CARD_H = 116, CARD_OX = 0, CARD_OY = 0,
  LAND = 106.6 / 154.4, -- a picked large card lands at this fraction of the slot scale (the small card's width)
  -- the cursor arrow (cmn05_01_cursor, its tip at the layer's origin, the arrow left of it) at the focused card's
  -- left edge, CUR_DX px outside it, at the card's height CUR_DY (screen px, y down, at the card's scale)
  CUR_DX = 6, CUR_DY = 0,
  PAUSE = 0.12, -- after the deal, before the first turn
  OVER = 0.12, OVER_BEST = 0.25, -- the turned card's bounce
  SEL_GROW = 1.08, SEL_LIFT = 16, -- the chosen card on the band
  -- the parts' sprites (their colours: bbd_pack_art.py CELLS)
  COL_DIM = @crc:bbd_pk_dim@, COL_BAND = @crc:bbd_pk_band@, BAND_ALPHA = 0.88, COL_EDGE = @crc:bbd_pk_edge@,
  COL_GLOW = @crc:bbd_pk_glow@, GLOW_ALPHA = 0, COL_GOLD = @crc:bbd_pk_gold@, GOLD_ALPHA = 0.65,
  COL_FLASH = @crc:bbd_pk_flash@, COL_SCREEN = @crc:bbd_pk_screen@, SCREEN_ALPHA = 0.55,
  spr = {}, -- the sprite each quad instance has (sent again only on a change; cleared by BBCR_DRAFT_PkPrio)
  loaded = false,
}

-- the Draft card layers get Inazuma Fantasy's formation-card look from its position_cards (soccer_common) when that
-- mod runs, like the panel's own team00_01_chara_card_left / _right (its T01 layer list + this table); without it
-- the table is never read
EVT_FC_EXTRA = EVT_FC_EXTRA or {}
EVT_FC_EXTRA[BBCR_DRAFT.SLOT] = true
EVT_FC_EXTRA[BBCR_DRAFT.CARD] = true

function BBCR_DRAFT_Log(...)
  pcall(funcLuaCommand, BBCR_DRAFT.LOG, "bb_chronicle_teams draft", ...)
end

function BBCR_DRAFT_Text(id, fallback)
  local s = funcLuaCommand(4074371074 --[[CMND_TEXT_GET]], id)
  if type(s) ~= "string" or s == "" then
    return fallback or ""
  end
  return s
end

-- loader state: ok, phase (0 none, 1 picking, 2 complete, 3 campaign), filled, total; ok = false without the loader
function BBCR_DRAFT_Info()
  local ok, team, phase, filled, total = funcLuaCommand(BBCR_DRAFT.INFO)
  if ok ~= true then
    return false, 0, 0, 0
  end
  return true, phase, filled, total
end

function BBCR_DRAFT_TeamName()
  local ok, name = funcLuaCommand(2151743654, BBCR_DRAFT.TEAM, 2)
  if ok and type(name) == "string" and name ~= "" then
    return name
  end
  return "Draft"
end

function BBCR_DRAFT_IsDraftSlot(slot)
  local B = BBCR_DRAFT
  local rec = B.slotArgs[slot]
  local team = rec and rec[1] or nil
  if team == nil then
    local t = funcLuaCommand(B.PAGE_SLOT, slot)
    team = type(t) == "number" and t or 0
  end
  return team == B.TEAM
end

-- the card name table of a Draft card instance, once per instance for the life of the menu (see the header: a second
-- name setting on the same instance corrupts the heap)
function BBCR_DRAFT_Name(layer, i)
  local B = BBCR_DRAFT
  local key = layer .. ":" .. i
  if B.named[key] then
    return
  end
  B.named[key] = true
  NameSetting_CharaCardForSoccer(layer, i)
end

function BBCR_DRAFT_Guide(s)
  funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], BBCR_DRAFT.GUIDE, BBCR_DRAFT.GUIDE_TEXT, s, 0)
  funcLuaMenuCommand(2735666188, BBCR_DRAFT.GUIDE, BBCR_DRAFT.GUIDE_TEXT, true, 0)
end

function BBCR_DRAFT_Filled()
  local n = 0
  for k = 0, #BBCR_DRAFT.slots - 1 do
    if BBCR_DRAFT.slots[k + 1].param ~= 0 then
      n = n + 1
    end
  end
  return n
end

-- the guide line of the current mode
function BBCR_DRAFT_ShowGuide()
  local B = BBCR_DRAFT
  local head = string.format("%s %d/%d  ·  ", BBCR_DRAFT_TeamName(), BBCR_DRAFT_Filled(), #B.slots)
  if B.mode == "pitch" then
    BBCR_DRAFT_Guide(head .. BBCR_DRAFT_Text(B.TXT_SLOT))
  elseif B.mode == "cands" then
    local rec = B.slots[B.k + 1]
    BBCR_DRAFT_Guide(head .. BBCR_DRAFT_Text(B.TXT_POS[rec and rec.pos or 0]) .. ": " .. BBCR_DRAFT_Text(B.TXT_PLAYER))
  elseif B.mode == "start" then
    BBCR_DRAFT_Guide(BBCR_DRAFT_Text(BBCR_DRAFT_Free() and B.TXT_START_MATCH or B.TXT_START) .. "   " .. BBCR_DRAFT_Text(B.TXT_KEYS))
  elseif B.mode == "quit" then
    BBCR_DRAFT_Guide(head .. BBCR_DRAFT_Text(B.TXT_SLOT))
  end
end

-- the 16 slots from the plugin, one command per slot (a command's return values are capped: the 98 values of all 16
-- slots in one call came back cut, 2026-10-08): {slot, pos, x, y, param, ph = placeholder} (pool order). Slot k is drawn on the card
-- evt_bb_draft_slot k; its screen position (also the navigation position): a field slot by its formation position, a
-- bench slot in the column
function BBCR_DRAFT_LoadSlots()
  local B = BBCR_DRAFT
  local r = table.pack(funcLuaCommand(B.SLOTS))
  if r[1] ~= true then
    return false
  end
  B.slots, B.pos, B.where = {}, {}, {}
  local bench = 0
  for k = 0, (r[2] or 0) - 1 do
    local q = table.pack(funcLuaCommand(B.SLOT_INFO, k))
    if q[1] ~= true or type(q[2]) ~= "number" then
      return false
    end
    local rec = {slot = q[2], pos = q[3], x = q[4], y = q[5], param = q[6], ph = q[7]}
    rec.field = rec.pos ~= 0 and rec.slot >= 0 and rec.slot <= 10
    B.slots[k + 1] = rec
    B.where[k] = {B.SLOT, k}
    if rec.field then
      local t = (rec.y - B.FIELD_TOP) / (B.FIELD_BOTTOM - B.FIELD_TOP)
      B.pos[k] = {B.PITCH_CX + B.MIRROR * B.PITCH_KX * rec.x, B.PITCH_TOP + t * (B.PITCH_BOTTOM - B.PITCH_TOP)}
    else
      B.pos[k] = {B.BENCH_X, B.BENCH_Y + bench * B.BENCH_DY}
      bench = bench + 1
    end
  end
  local okf, fm = funcLuaCommand(2151743654, B.TEAM, 3)
  B.formation = (okf and type(fm) == "number") and fm or 0
  return #B.slots > 0
end

-- the meshes of a Draft card the graft switches itself, after any draw: the focus frame off (only the focused card
-- shows it, BBCR_DRAFT_Cursor), the large card's base / centred mesh off (the cards are small, see SZ)
function BBCR_DRAFT_Sz(layer)
  local B = BBCR_DRAFT
  if layer == B.CARD then
    return B.SZ_CARD
  end
  return B.SZ
end

function BBCR_DRAFT_CardMeshes(layer, i)
  local B = BBCR_DRAFT
  local sz = BBCR_DRAFT_Sz(layer)
  for _, m in ipairs(B.M_FOCUS) do
    funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], layer, m, false, i)
  end
  for j = 1, 2 do
    if j ~= sz then
      funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], layer, B.M_BASE[j], false, i)
      funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], layer, B.M_DEF[j], false, i)
    end
  end
end

-- what a drafted / offered card shows: the formation panel's card (not the season card), season tag / lock hidden.
-- Before the draw the small card's face meshes are turned back on (an empty card hid them); the large ones are left
-- to the native draw (it never shows them on a small card).
function BBCR_DRAFT_Filled_Card(layer, i, param)
  local B = BBCR_DRAFT
  local sz = BBCR_DRAFT_Sz(layer)
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], layer, i, true)
  for _, m in ipairs(B.M_DEF) do
    funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], layer, m, false, i)
  end
  for k = sz, #B.M_FACE, 2 do
    funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], layer, B.M_FACE[k], true, i)
  end
  funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], layer, B.M_BASE[sz], true, i)
  funcLuaMenuCommand(2339877830, layer, i, param, sz == 1, false, 0, 0, B.LEVEL, false, false, 4, 0)
  for _, m in ipairs(B.M_TAG) do
    funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], layer, m, false, i)
  end
  BBCR_DRAFT_CardMeshes(layer, i)
end

-- an empty slot: a normal player card (the slot's placeholder drawn by the retail card command sets the card's state:
-- position colour, no coach frame) with everything of the player hidden and the «?» glyph centred at its native size;
-- a bench slot gets the grey card base. Without a placeholder the card is only cleared (grey base). Small card only
-- (SZ): its base and centred mesh on, the large card's off, no focus frame. kind (1.5.75): the formation slot's own
-- position (formation info 6, as the retail formation panels pass it), so the colour is the slot's, never the
-- placeholder player's (owner 2026-10-15: a FW placeholder showed a red card on a midfield place); 0 = the card's own.
function BBCR_DRAFT_Empty_Card(layer, i, ph, grey, kind)
  local B = BBCR_DRAFT
  local sz = BBCR_DRAFT_Sz(layer)
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], layer, i, true)
  if type(ph) == "number" and ph ~= 0 then
    funcLuaMenuCommand(2339877830, layer, i, ph, sz == 1, false, type(kind) == "number" and kind or 0, 0, B.LEVEL, false,
                       false, 4, 0)
  else
    grey = true
  end
  for _, list in ipairs({B.M_FACE, B.M_EMPTY, B.M_TAG, B.M_STAFF}) do
    for _, m in ipairs(list) do
      funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], layer, m, false, i)
    end
  end
  for _, n in ipairs(B.N_STAFF) do
    funcLuaMenuCommand(2158717427 --[[node visible]], layer, n, false, i)
  end
  local j = sz
  if grey then
    funcLuaMenuCommand(558735651, layer, B.TEX_CARD, j == 1 and B.SPR_GREY_L or B.SPR_GREY, B.SLOT_BASE[j], 0, i)
  end
  funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], layer, B.M_BASE[j], true, i)
  local qs = j == 1 and B.Q_SCALE_L or B.Q_SCALE
  local qw, qh = B.Q_W * qs, B.Q_H * qs
  funcLuaMenuCommand(B.NODE_SCALE, layer, i, B.M_DEF[j], qw, qh)
  funcLuaMenuCommand(B.NODE_POS, layer, i, B.M_DEF[j], 0, -qw / 2)
  funcLuaMenuCommand(B.NODE_POS, layer, i, B.M_DEF[j], 1, qh / 2)
  funcLuaMenuCommand(558735651, layer, B.TEX_NUM, B.SPR_Q, B.SLOT_DEF[j], 0, i)
  funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], layer, B.M_DEF[j], true, i)
  BBCR_DRAFT_CardMeshes(layer, i)
  funcLuaMenuCommand(1083631230 --[[CMND_SET_MENU_TEXT_STRING?]], layer, B.T_NAME, "", i)
end

-- the empty look again (a late face / icon load can switch a mesh back on)
function BBCR_DRAFT_Rehide(layer, i)
  for _, m in ipairs(BBCR_DRAFT.M_FACE) do
    funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], layer, m, false, i)
  end
end

function BBCR_DRAFT_DrawSlot(k)
  local B = BBCR_DRAFT
  local rec, w = B.slots[k + 1], B.where[k]
  if rec == nil or w == nil then
    return
  end
  local layer, i = w[1], w[2]
  if not B.ready[layer .. ":" .. i] then
    return
  end
  if rec.param ~= 0 then
    BBCR_DRAFT_Filled_Card(layer, i, rec.param)
  else
    local kind = 0
    if rec.field and B.formation ~= 0 then
      local okk, kk = funcLuaCommand(2649030357 --[[formation info]], 6, B.formation, rec.slot)
      kind = (okk == true and type(kk) == "number") and kk or 0
    end
    BBCR_DRAFT_Empty_Card(layer, i, rec.ph, B.BENCH_GREY and not rec.field, kind)
    B.reapply = B.REAPPLY_FRAMES
  end
  funcLuaMenuCommand(1389957207 --[[CMND_SET_LAYER_LOCAL_POS?]], layer, B.pos[k][1], B.pos[k][2], 0, i)
  funcLuaMenuCommand(3362798188, layer, i, B.SLOT_SCALE, B.SLOT_SCALE)
end

-- the pitch and the bench
function BBCR_DRAFT_DrawPitch()
  for k = 0, #BBCR_DRAFT.slots - 1 do
    BBCR_DRAFT_DrawSlot(k)
  end
end

function BBCR_DRAFT_DrawCand(i)
  local B = BBCR_DRAFT
  local p = B.cands[i + 1]
  if not B.ready[B.CARD .. ":" .. i] or B.pk ~= nil then
    return -- 1.5.26: while a pack is up (or flying out) it draws the 5 cards itself (BBCR_DRAFT_PackRender)
  end
  if p == nil or B.mode ~= "cands" then
    funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], B.CARD, i, false)
    return
  end
  BBCR_DRAFT_Filled_Card(B.CARD, i, p.param)
  local s = i == B.csel and B.CARD_SCALE_ON or B.CARD_SCALE
  funcLuaMenuCommand(1389957207 --[[CMND_SET_LAYER_LOCAL_POS?]], B.CARD, B.CAND_X, B.CAND_Y + i * B.CAND_DY, 0, i)
  funcLuaMenuCommand(3362798188, B.CARD, i, s, s)
end

-- the retail formation focus on the selected card, as soccer_formation_menu_inc does for a small card: the green
-- arrow (cmn05_01_cursor) on the card's small cursor label (CARD_CURSOR2 = _pos_atc_cur02, its left edge) and the
-- card's own focus frame _icon_chr_focus_s01 (team00_01_evt_fc: scaled with the card, so it is exactly the card
-- outline). Every other Draft card has its focus frame off (BBCR_DRAFT_CardMeshes). The pack's large cards
-- (1.5.52): their own large frame _icon_chr_focus_l01, and the arrow placed by BBCR_DRAFT_PkCursor (not attached:
-- the card is drawn scaled on the band and the attach locator did not follow the layer scale, the arrow sat inside
-- the card over the portrait and the position badge).
function BBCR_DRAFT_CursorLabel(layer)
  return BBCR_DRAFT_Sz(layer) == 1 and BBCR_DRAFT.CARD_CURSOR or BBCR_DRAFT.CARD_CURSOR2
end

function BBCR_DRAFT_Cursor()
  local B = BBCR_DRAFT
  if B.shown ~= nil then
    funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], B.shown[1], B.shown[2],
                       BBCR_DRAFT_CursorLabel(B.shown[1]), false)
    for _, m in ipairs(B.M_FOCUS) do
      funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], B.shown[1], m, false, B.shown[2])
    end
    B.shown = nil
  end
  local layer, i, n
  if B.mode == "cands" then
    if BBCR_DRAFT_PackBusy() then
      -- no cursor while the pack's cards are dealt and turned (BBCR_DRAFT_PackDone puts it back)
      funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], B.CURSOR, 0, false)
      return
    end
    layer, i, n = B.CARD, B.csel, 5
  elseif B.mode == "pitch" or B.mode == "start" or B.mode == "quit" then
    local w = B.where[B.sel]
    if w == nil then
      return
    end
    layer, i, n = w[1], w[2], #B.slots
  else
    return
  end
  local sz = BBCR_DRAFT_Sz(layer)
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], B.CURSOR, 0, true)
  if layer == B.CARD and B.pk ~= nil then
    -- the pack's band: the arrow at the focused card's left edge (BBCR_DRAFT_PkCursor, again every frame of the pick)
    B.pk.cur = nil
    BBCR_DRAFT_PkCursor()
  else
    if B.curMoved then
      -- the pack moved the arrow itself: its own offset back to 0 before it is attached again
      funcLuaMenuCommand(1389957207 --[[CMND_SET_LAYER_LOCAL_POS?]], B.CURSOR, 0, 0, 0, 0)
      B.curMoved = false
    end
    local label = BBCR_DRAFT_CursorLabel(layer)
    funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], layer, i, label, true)
    funcLuaMenuCommand(381797568 --[[CMND_SET_CURSOR_LOCATOR?]], layer, label, i, n)
  end
  for j = 1, 2 do
    funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], layer, B.M_FOCUS[j], j == sz, i)
  end
  B.shown = {layer, i}
end

-- the panel while the Draft screen is open: its 11 cards hidden (the slots are the Draft's own cards), the pitch
-- shown, moved and stretched under them, its tactics and «TÁCTICAS» hidden. Also run for every native panel refresh
-- while the screen is open (UpdateFormation wrapper): the native refresh of a focus change would hide the pitch.
function BBCR_DRAFT_PanelHold()
  local B = BBCR_DRAFT
  for i = 0, 10 do
    funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], B.LEFT, i, false)
  end
  funcLuaMenuCommand(1389957207 --[[CMND_SET_LAYER_LOCAL_POS?]], B.FRAME, B.FRAME_DX, B.FRAME_DY, 0, 0)
  funcLuaMenuCommand(3362798188, B.FRAME, 0, B.FRAME_SX, B.FRAME_SY)
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], B.FRAME, 0, true)
  funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], B.FRAME, B.M_FIELD, true, 0)
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], B.TACTICS_BASE, 0, false)
  for i = 0, 2 do
    funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], B.TACTICS_CMD, i, false)
  end
  funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], B.TEAMINFO, B.M_TACTICS_LABEL, false, 0)
end

-- the Draft screen on: crest grid, lock icons, «Página» line hidden, the panel held (BBCR_DRAFT_PanelHold)
-- free match: every visible instance of a layer hidden and remembered (BBCR_DRAFT_Unstash puts them back)
function BBCR_DRAFT_Stash(layer)
  local B = BBCR_DRAFT
  local n = funcLuaMenuCommand(1175615627 --[[CMND_GET_CREATE_LAYER_NUM?]], layer)
  if type(n) ~= "number" or n <= 0 then
    n = 1
  end
  for i = 0, n - 1 do
    if funcLuaMenuCommand(1262717583 --[[CMND_IS_LAYER_VISIBLE]], layer, i) == true then
      funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], layer, i, false)
      B.stash[#B.stash + 1] = {layer, i}
    end
  end
end

function BBCR_DRAFT_Unstash()
  local B = BBCR_DRAFT
  local list = B.stash
  B.stash = {}
  for _, e in ipairs(list) do
    funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], e[1], e[2], true)
  end
end

function BBCR_DRAFT_ScreenOn()
  local B = BBCR_DRAFT
  if BBCR_DRAFT_Free() then
    if #B.stash == 0 then
      BBCR_DRAFT_Stash(B.GRID)
      BBCR_DRAFT_Stash(B.ATTACH)
      BBCR_DRAFT_Stash(B.LOCK)
      for _, layer in ipairs(B.FREE_HIDE) do
        BBCR_DRAFT_Stash(layer)
      end
    end
    funcLuaMenuCommand(3518307824 --[[CMND_SET_ENABLE_CTRL_FOCUS?]], B.GRID, false)
    if VRFW_BBP_Hide ~= nil then
      pcall(VRFW_BBP_Hide)
    end
    BBCR_DRAFT_PanelHold()
    return
  end
  local n = funcLuaMenuCommand(1175615627 --[[CMND_GET_CREATE_LAYER_NUM?]], B.GRID) or 0
  for i = 0, n - 1 do
    funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], B.GRID, i, false)
  end
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], B.ATTACH, 0, false)
  local m = funcLuaMenuCommand(1175615627 --[[CMND_GET_CREATE_LAYER_NUM?]], B.LOCK) or 0
  for i = 0, m - 1 do
    funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], B.LOCK, i, false)
  end
  funcLuaMenuCommand(3518307824 --[[CMND_SET_ENABLE_CTRL_FOCUS?]], B.GRID, false)
  -- the framework's page / category / season line over the grid (graft vrfw_bb_pages): hidden until BBCR_DRAFT_ScreenOff
  if VRFW_BBP_Hide ~= nil then
    pcall(VRFW_BBP_Hide)
  end
  BBCR_DRAFT_PanelHold()
end

-- the panel back as the retail menu has it: pitch on the left at its size, tactics, «TÁCTICAS», the framework's page
-- line (vrfw_bb_pages); its cards come back with the retail UpdateFormation of the tile (BBCR_DRAFT_Panel)
function BBCR_DRAFT_ScreenOff()
  local B = BBCR_DRAFT
  funcLuaMenuCommand(1389957207 --[[CMND_SET_LAYER_LOCAL_POS?]], B.FRAME, 0, 0, 0, 0)
  funcLuaMenuCommand(3362798188, B.FRAME, 0, 1, 1)
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], B.TACTICS_BASE, 0, true)
  for i = 0, 2 do
    funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], B.TACTICS_CMD, i, true)
  end
  funcLuaMenuCommand(3405944500 --[[CMND_SET_MESH_VISIBLE]], B.TEAMINFO, B.M_TACTICS_LABEL, true, 0)
  if BBCR_DRAFT_Free() then
    BBCR_DRAFT_Unstash()
  end
  if EVT_BBP_SetupLine ~= nil then
    pcall(EVT_BBP_SetupLine, 0)
  end
end

-- the frame's pose in the log, once per screen (layout check: where the moved pitch really is)
function BBCR_DRAFT_Probe()
  local B = BBCR_DRAFT
  local parts = {}
  for _, node in ipairs(B.FRAME_NODES) do
    local x, y, z, ok = funcLuaMenuCommand(2373227714 --[[CMND_GET_MESH_POSE?]], B.FRAME, 0, node)
    parts[#parts + 1] = string.format("%s(%s,%s,%s)", tostring(ok), tostring(x), tostring(y), tostring(z))
  end
  local fx, fy = funcLuaMenuCommand(2834507455 --[[CMND_GET_LAYER_LOCAL_POS]], B.FRAME, 0)
  local sx, sy = funcLuaMenuCommand(2834507455 --[[CMND_GET_LAYER_LOCAL_POS]], B.SLOT, 0)
  BBCR_DRAFT_Log("layout probe: frame nodes cc/ld/ru", table.concat(parts, " "), "frame at", tostring(fx), tostring(fy),
              "slot 0 at", tostring(sx), tostring(sy))
end

-- open the Draft layers (once per screen) and give the control focus to the anchor
function BBCR_DRAFT_Open()
  local B = BBCR_DRAFT
  if not B.opened then
    funcLuaMenuCommand(2152386330 --[[CMND_OPEN_LAYER_ARRAY]], B.SLOT)
    funcLuaMenuCommand(2152386330 --[[CMND_OPEN_LAYER_ARRAY]], B.CARD)
    funcLuaMenuCommand(2152386330 --[[CMND_OPEN_LAYER_ARRAY]], BBCR_DRAFT_PK.QUAD)
    funcLuaMenuCommand(2152386330 --[[CMND_OPEN_LAYER_ARRAY]], BBCR_DRAFT_PK.TXT)
    funcLuaMenuCommand(629267548 --[[CMND_OPEN_LAYER]], B.ANCHOR)
    B.opened = true
  end
  funcLuaMenuCommand(3518307824 --[[CMND_SET_ENABLE_CTRL_FOCUS?]], B.ANCHOR, true)
  funcLuaMenuCommand(1778826357, B.ANCHOR, 0, true)
end

-- close the Draft layers (their card textures are released), the panel back, the focus off the anchor
function BBCR_DRAFT_CloseLayers()
  local B = BBCR_DRAFT
  if B.shown ~= nil then
    funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], B.shown[1], B.shown[2], BBCR_DRAFT_CursorLabel(), false)
    B.shown = nil
  end
  pcall(BBCR_DRAFT_PackEnd)
  B.cands = {}
  B.mode = nil
  B.reapply = nil
  B.probe = nil
  funcLuaMenuCommand(3518307824 --[[CMND_SET_ENABLE_CTRL_FOCUS?]], B.ANCHOR, false)
  if B.opened then
    funcLuaMenuCommand(2323943931 --[[CMND_CLOSE_LAYER_ARRAY?]], B.SLOT)
    funcLuaMenuCommand(2323943931 --[[CMND_CLOSE_LAYER_ARRAY?]], B.CARD)
    funcLuaMenuCommand(2323943931 --[[CMND_CLOSE_LAYER_ARRAY?]], BBCR_DRAFT_PK.QUAD)
    funcLuaMenuCommand(2323943931 --[[CMND_CLOSE_LAYER_ARRAY?]], BBCR_DRAFT_PK.TXT)
    funcLuaMenuCommand(1273612389 --[[CMND_CLOSE_LAYER]], B.ANCHOR)
    B.opened = false
  end
  B.ready = {}
  local ok, err = pcall(BBCR_DRAFT_ScreenOff)
  if not ok then
    BBCR_DRAFT_Log("screen off error", tostring(err))
  end
end

-- the grid back (the retail OnCloseEndLayer of the difficulty window: slots, locks, focus, guide) and, a few frames
-- later, the page rebuilt like a page turn with the focus on the Draft tile (BBCR_DRAFT_Refresh)
function BBCR_DRAFT_GridBack()
  local B = BBCR_DRAFT
  funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], B.CURSOR, 0, true)
  if BBCR_DRAFT_Free() then
    -- the grid itself came back with the stash (BBCR_DRAFT_ScreenOff); its focus and the retail guide line
    funcLuaMenuCommand(3518307824 --[[CMND_SET_ENABLE_CTRL_FOCUS?]], B.GRID, true)
    local cur = funcLuaMenuCommand(2603265800, B.GRID)
    if type(cur) == "number" then
      funcLuaMenuCommand(4233535095, B.GRID, cur, true)
    end
    if SetButtonGuideText ~= nil then
      pcall(SetButtonGuideText, -1)
    end
    B.refresh = B.REFRESH_FRAMES
    return
  end
  local ok, err = pcall(OnCloseEndLayer, B.DIFFWIN, 0)
  if not ok then
    BBCR_DRAFT_Log("grid back error", tostring(err))
  end
  B.refresh = B.REFRESH_FRAMES
end

-- tile / panel: the tile the focus goes back to and the panel's redraw (default: the Draft tile, BBCR_DRAFT_PanelBack;
-- the «Plantilla» viewer, bbd_roster.lua, passes the team it showed)
function BBCR_DRAFT_Refresh(tile, panel)
  local B = BBCR_DRAFT
  tile = tile or B.tile
  local page = funcLuaCommand(B.PAGE_REFRESH)
  local redrawn = false
  if type(page) == "number" and EVT_BBP ~= nil and EVT_BBP_Query ~= nil and EVT_BBP_Redraw ~= nil then
    EVT_BBP_Query()
    redrawn = pcall(EVT_BBP_Redraw)
  end
  if not redrawn then
    -- no pages service: the emblems again from the last SetupEmblemIcon arguments of each slot, as vrfw_bb_pages'
    -- EVT_BBP_Redraw does (icon released first, the emblem node shown after: the retail SetupEmblemIcon hides it)
    local args = {}
    for i, rec in pairs(B.slotArgs) do
      args[#args + 1] = {i, rec}
    end
    for _, a in ipairs(args) do
      funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], B.GRID, a[1], a[2][1] ~= 0)
      funcLuaMenuCommand(4176779611 --[[reset icon]], B.GRID, a[1], B.EMBLEM_TEX)
      pcall(SetupEmblemIcon, a[1], a[2][1], a[2][2], a[2][3])
      funcLuaMenuCommand(2158717427 --[[node visible]], B.GRID, B.EMBLEM_NODE, a[2][1] ~= 0, a[1])
    end
  end
  -- focus and cursor on the tile; its panel
  if tile >= 0 then
    local n = funcLuaMenuCommand(1175615627 --[[CMND_GET_CREATE_LAYER_NUM?]], B.GRID) or 0
    funcLuaMenuCommand(3518307824 --[[CMND_SET_ENABLE_CTRL_FOCUS?]], B.GRID, true)
    funcLuaMenuCommand(1778826357, B.GRID, tile, true)
    funcLuaMenuCommand(381797568 --[[CMND_SET_CURSOR_LOCATOR?]], B.GRID, B.GRID_CURSOR, tile, n)
  end
  if panel ~= nil then
    panel()
  else
    BBCR_DRAFT_PanelBack()
  end
  BBCR_DRAFT_Log("grid refreshed", page, redrawn, tile)
end

-- the left panel = the Draft team (the UpdateFormation wrapper: held while the Draft screen is open, else its players
-- only once the draft is complete)
function BBCR_DRAFT_Panel()
  local B = BBCR_DRAFT
  B.ours = true
  pcall(UpdateTeamNameText, B.TEAM, true)
  local ok, err = pcall(UpdateFormation, B.TEAM, true)
  B.ours = false
  if not ok then
    BBCR_DRAFT_Log("panel error", tostring(err))
  end
end

-- the panels after the screen: the Draft team on the side being chosen. Campaña / 1P: the left panel
-- (BBCR_DRAFT_Panel); free match while the CPU is chosen: the left back to the 1P's team, the Draft on the right
function BBCR_DRAFT_PanelBack()
  local B = BBCR_DRAFT
  if not BBCR_DRAFT_Free() or B.side ~= false then
    BBCR_DRAFT_Panel()
    return
  end
  B.ours = true
  local p1 = B.drawn[true]
  if p1 ~= nil and p1 ~= 0 then
    pcall(UpdateTeamNameText, p1, true)
    pcall(UpdateFormation, p1, true)
  end
  pcall(UpdateTeamNameText, B.TEAM, false)
  local ok, err = pcall(UpdateFormation, B.TEAM, false)
  B.ours = false
  if not ok then
    BBCR_DRAFT_Log("panel error (right)", tostring(err))
  end
end

function BBCR_DRAFT_Start(tile)
  local B = BBCR_DRAFT
  local ok, phase = BBCR_DRAFT_Info()
  if not ok then
    BBCR_DRAFT_Log("no loader draft: the Draft tile does nothing")
    return
  end
  B.tile = tile
  B.used = true
  if phase >= 2 and BBCR_DRAFT_Free() then
    -- free match: the retail decide of the tile (scripts\campaign.lua lets it through itself when it sees the draft
    -- complete; this is the fallback): a frame later, outside this decide
    B.autoDecide = true
    B.refresh = 1
    return
  end
  if phase == 2 then
    -- already drafted (back from the difficulty window): straight to the retail flow with that squad
    B.bypass = true
    pcall(OnDecideFocus, B.GRID, tile)
    B.bypass = false
    return
  end
  if phase ~= 1 then
    local okb, total = funcLuaCommand(B.BEGIN)
    if okb ~= true then
      BBCR_DRAFT_Log("begin refused by the loader")
      BBCR_DRAFT_Guide(BBCR_DRAFT_Text(B.TXT_ERROR))
      return
    end
    BBCR_DRAFT_Log("begin", tile, total)
  end
  if not BBCR_DRAFT_LoadSlots() then
    BBCR_DRAFT_Log("no slots from the loader")
    funcLuaCommand(B.ABANDON)
    return
  end
  B.refresh = nil
  B.mode = "pitch"
  B.sel = 0
  B.cands = {}
  BBCR_DRAFT_ScreenOn()
  BBCR_DRAFT_Open()
  BBCR_DRAFT_Panel() -- team name of the Draft team; its pitch is held (UpdateFormation wrapper)
  BBCR_DRAFT_DrawPitch()
  BBCR_DRAFT_Cursor()
  BBCR_DRAFT_ShowGuide()
  B.probe = B.PROBE_FRAMES
  BBCR_DRAFT_Log("screen", #B.slots, "slots, formation", B.formation)
end

-- nearest slot in the direction (dx, dy) (screen, y up) from the selected one
function BBCR_DRAFT_Move(dx, dy)
  local B = BBCR_DRAFT
  if B.mode == "cands" then
    if BBCR_DRAFT_PackBusy() then
      return -- the pack is still being turned (Enter shows all)
    end
    -- the candidates are a row on the pack's band (1.5.26; a column before): Left / Right (Up / Down too) move along it
    local d = (dy ~= 0) and -dy or dx
    if d ~= 0 then
      local n = #B.cands
      local to = math.max(0, math.min(n - 1, B.csel + d))
      if to ~= B.csel then
        local old = B.csel
        B.csel = to
        BBCR_DRAFT_DrawCand(old)
        BBCR_DRAFT_DrawCand(to)
        BBCR_DRAFT_Cursor()
        funcLuaCommand(1917805374, 2500047763 --[[sy0005]])
      end
    end
    return
  end
  if B.mode ~= "pitch" then
    return
  end
  -- first the slots within a ~50 degree cone of the direction, else any slot on that side; nearest along the
  -- direction, a sideways offset counting half
  local from = B.pos[B.sel]
  local best, bestScore = nil, nil
  for pass = 1, 2 do
    for k = 0, #B.slots - 1 do
      if k ~= B.sel then
        local vx, vy = B.pos[k][1] - from[1], B.pos[k][2] - from[2]
        local along = vx * dx + vy * dy
        local across = math.abs(vx * dy - vy * dx)
        if along > 0 and (pass == 2 or across <= along * 1.2) then
          local score = along + 0.5 * across
          if bestScore == nil or score < bestScore then
            best, bestScore = k, score
          end
        end
      end
    end
    if best ~= nil then
      break
    end
  end
  if best ~= nil then
    B.sel = best
    BBCR_DRAFT_Cursor()
    funcLuaCommand(1917805374, 2500047763 --[[sy0005]])
  end
end

function BBCR_DRAFT_NextEmpty(from)
  local B = BBCR_DRAFT
  for d = 0, #B.slots - 1 do
    local k = (from + d) % #B.slots
    if B.slots[k + 1].param == 0 then
      return k
    end
  end
  return from
end

-- Enter
function BBCR_DRAFT_Decide()
  local B = BBCR_DRAFT
  if B.mode == "pitch" then
    if BBCR_DRAFT_Filled() >= #B.slots then
      B.mode = "start"
    elseif B.slots[B.sel + 1].param == 0 then
      local r = table.pack(funcLuaCommand(B.CANDS, B.sel))
      if r[1] ~= true then
        BBCR_DRAFT_Log("no candidates for slot", B.sel)
        return
      end
      B.k = r[2]
      B.cands = {}
      for i = 0, (r[5] or 0) - 1 do
        B.cands[i + 1] = {param = r[6 + 2 * i], pos = r[7 + 2 * i]}
      end
      B.mode = "cands"
      B.csel = 0
      BBCR_DRAFT_PackStart()
    else
      return -- a slot already drafted stays as it is
    end
  elseif B.mode == "cands" then
    if BBCR_DRAFT_PackBusy() then
      BBCR_DRAFT_PackDone(true) -- Enter during the animation: all 5 at once
      BBCR_DRAFT_ShowGuide()
      return
    end
    local ok, done, slot, param = funcLuaCommand(B.PICK, B.k, B.csel)
    if ok ~= true then
      BBCR_DRAFT_Log("pick refused", B.k, B.csel)
      BBCR_DRAFT_Exit(true)
      BBCR_DRAFT_Guide(BBCR_DRAFT_Text(B.TXT_ERROR))
      return
    end
    B.slots[B.k + 1].param = param
    BBCR_DRAFT_DrawSlot(B.k)
    BBCR_DRAFT_PackOutro(B.k, B.csel) -- the card flies to its place, the screen comes back
    B.mode = done and "start" or "pitch"
    for i = 0, 4 do
      BBCR_DRAFT_DrawCand(i)
    end
    B.sel = done and B.k or BBCR_DRAFT_NextEmpty(B.k)
  elseif B.mode == "start" then
    BBCR_DRAFT_Finish()
    return
  elseif B.mode == "quit" then
    return -- the Sí / No window has the input
  end
  funcLuaCommand(1917805374, 4235359837 --[[decide]])
  BBCR_DRAFT_Cursor()
  BBCR_DRAFT_ShowGuide()
end

-- Back
function BBCR_DRAFT_Back()
  local B = BBCR_DRAFT
  if B.mode == "cands" then
    if BBCR_DRAFT_PackBusy() then
      BBCR_DRAFT_PackDone(true) -- Back during the animation: all 5 at once too
      return
    end
    -- the 5 of a slot cannot be left without a pick (no reroll by backing out)
    funcLuaCommand(1917805374, B.SE_NG)
    local rec = B.slots[B.k + 1]
    BBCR_DRAFT_Guide(BBCR_DRAFT_Text(B.TXT_POS[rec and rec.pos or 0]) .. ": " .. BBCR_DRAFT_Text(B.TXT_PICK_ONE, "Elige uno de los 5"))
    BBCR_DRAFT_Log("pick open: back refused", B.k)
    return
  elseif B.mode == "quit" then
    return -- the Sí / No window has the input
  elseif B.mode == "pitch" then
    B.mode = "quit"
    funcLuaCommand(1917805374, 202039849 --[[back]])
    B.quitCo = coroutine.create(BBCR_DRAFT_QuitAsk)
    BBCR_DRAFT_QuitStep()
    return
  elseif B.mode == "start" then
    B.mode = "pitch"
  end
  funcLuaCommand(1917805374, 202039849 --[[back]])
  BBCR_DRAFT_Cursor()
  BBCR_DRAFT_ShowGuide()
end

-- the retail Sí / No window (the class menu's / gameend pattern: 2289627655 + 2351835063(2, 0), the cursor on «No»
-- with 2529383714(1) as retail confirmations do, result 1523741473: 0 = Sí); the menu's input is off meanwhile. Runs
-- in its own coroutine, resumed by Step.
function BBCR_DRAFT_QuitAsk()
  local B = BBCR_DRAFT
  funcLuaMenuCommand(1558704558, B.MENU, false)
  local text = BBCR_DRAFT_Text(B.TXT_QUIT_ASK, "¿Quieres abandonar el draft?")
  funcLuaCommand(2289627655, text, 0, 0, 0, 0, 0, false)
  funcLuaCommand(2351835063, 2, 0)
  funcLuaCommand(2529383714, 1)
  while funcLuaCommand(898725220) == true do
    coroutine.yield()
  end
  local r = funcLuaCommand(1523741473)
  while type(r) ~= "number" or r < 0 do
    coroutine.yield()
    r = funcLuaCommand(1523741473)
  end
  local f = 0
  while funcLuaCommand(682363669) ~= true and f < B.QUIT_CLOSE_MAX do
    f = f + 1
    coroutine.yield()
  end
  funcLuaMenuCommand(1558704558, B.MENU, true)
  return r == 0
end

function BBCR_DRAFT_QuitStep()
  local B = BBCR_DRAFT
  if B.quitCo == nil then
    return
  end
  local ok, yes = coroutine.resume(B.quitCo)
  if ok and coroutine.status(B.quitCo) ~= "dead" then
    return
  end
  B.quitCo = nil
  if not ok then
    BBCR_DRAFT_Log("quit window error", tostring(yes))
    pcall(funcLuaMenuCommand, 1558704558, B.MENU, true)
    yes = false
  end
  if B.mode ~= "quit" then
    return
  end
  if yes == true then
    BBCR_DRAFT_Log("abandoned with", BBCR_DRAFT_Filled(), "picks")
    BBCR_DRAFT_Exit(true)
    return
  end
  B.mode = "pitch"
  BBCR_DRAFT_Cursor()
  BBCR_DRAFT_ShowGuide()
end

-- leave the Draft screen; abandon = the draft is discarded and the grid comes back
function BBCR_DRAFT_Exit(abandon)
  local B = BBCR_DRAFT
  if abandon then
    funcLuaCommand(B.ABANDON)
  end
  BBCR_DRAFT_CloseLayers()
  BBCR_DRAFT_GridBack()
  BBCR_DRAFT_PanelBack()
end

-- 16 drafted and confirmed: the retail flow of the tile (difficulty window -> campaign)
function BBCR_DRAFT_Finish()
  local B = BBCR_DRAFT
  BBCR_DRAFT_CloseLayers()
  if BBCR_DRAFT_Free() then
    -- free match: the grid back, the page rebuilt, then the tile's retail decide (BBCR_DRAFT_Step)
    BBCR_DRAFT_Log("complete: the tile's decide (free match)")
    BBCR_DRAFT_GridBack()
    BBCR_DRAFT_PanelBack()
    B.autoDecide = true
    return
  end
  BBCR_DRAFT_Panel()
  BBCR_DRAFT_Log("complete: difficulty window")
  B.bypass = true
  local ok, err = pcall(OnDecideFocus, B.GRID, B.tile)
  B.bypass = false
  if not ok then
    BBCR_DRAFT_Log("difficulty window error", tostring(err))
  end
end

function BBCR_DRAFT_Step()
  local B = BBCR_DRAFT
  if B.pk ~= nil then
    local ok, err = pcall(BBCR_DRAFT_PackStep)
    if not ok then
      BBCR_DRAFT_Log("pack error", tostring(err))
      pcall(BBCR_DRAFT_PackEnd)
      if B.mode == "cands" then
        for i = 0, 4 do
          pcall(BBCR_DRAFT_DrawCand, i) -- the plain cards back (no pack)
        end
        pcall(BBCR_DRAFT_Cursor)
      end
    end
  end
  if B.quitCo ~= nil then
    BBCR_DRAFT_QuitStep()
  end
  if B.refresh ~= nil then
    B.refresh = B.refresh - 1
    if B.refresh <= 0 then
      B.refresh = nil
      local ok, err = pcall(BBCR_DRAFT_Refresh)
      if not ok then
        BBCR_DRAFT_Log("refresh error", tostring(err))
      end
      if B.autoDecide then
        -- free match: the drafted Draft team decided as 1P / CPU (the retail decide of its tile)
        B.autoDecide = false
        local okd, done = pcall(funcLuaCommand, B.DECIDE, B.tile)
        BBCR_DRAFT_Log("free match decide", tostring(okd), tostring(done), B.tile)
      end
    end
  end
  if B.reapply ~= nil and B.mode ~= nil then
    B.reapply = B.reapply - 1
    for k = 0, #B.slots - 1 do
      local w = B.where[k]
      if w ~= nil and B.slots[k + 1].param == 0 and B.ready[w[1] .. ":" .. w[2]] then
        BBCR_DRAFT_Rehide(w[1], w[2])
      end
    end
    if B.reapply <= 0 then
      B.reapply = nil
    end
  end
  if B.probe ~= nil and B.mode ~= nil then
    B.probe = B.probe - 1
    if B.probe <= 0 then
      B.probe = nil
      local ok, err = pcall(BBCR_DRAFT_Probe)
      if not ok then
        BBCR_DRAFT_Log("probe error", tostring(err))
      end
    end
  end
end

-- ---------------------------------------------------------------- the candidates' «pack opening» (1.5.26)

-- the look from config.toml [draft.pack], once per menu (CMND_BBD_DRAFT_PACK; the table's defaults without it)
function BBCR_DRAFT_PackLook()
  local P = BBCR_DRAFT_PK
  if P.loaded then
    return
  end
  P.loaded = true
  local ok, r = pcall(function()
    return table.pack(funcLuaCommand(P.CMD))
  end)
  if not ok or type(r) ~= "table" or r[1] ~= true then
    BBCR_DRAFT_Log("pack look: defaults (no CMND_BBD_DRAFT_PACK answer)")
    return
  end
  local keys = {"intro", "deal", "deal_stagger", "flip", "settle", "flash", "gap", "suspense", "outro", "dim", "scale",
                "spacing", "se_open", "se_deal", "se_reveal", "se_best"}
  for i, k in ipairs(keys) do
    local v = r[i + 1]
    if type(v) == "number" then
      P[k] = v
    end
  end
  BBCR_DRAFT_Log("pack look", P.intro, P.flip, P.gap, P.dim, P.scale, P.spacing)
end

function BBCR_DRAFT_PkFrames(sec)
  return math.max(1, math.floor(sec * BBCR_DRAFT_PK.FPS + 0.5))
end

local function PkClamp(u)
  if u < 0 then
    return 0
  elseif u > 1 then
    return 1
  end
  return u
end

local function PkOutCubic(u)
  u = 1 - PkClamp(u)
  return 1 - u * u * u
end

local function PkOutBack(u)
  u = PkClamp(u) - 1
  local c = 1.70158
  return 1 + (c + 1) * u * u * u + c * u * u
end

function BBCR_DRAFT_PkSE(id)
  if type(id) == "number" and id ~= 0 then
    pcall(funcLuaCommand, BBCR_DRAFT_PK.SE, id)
  end
end

-- a flat coloured quad of the pack: instance i, centre (x, y) screen px (y down), w x h px, sprite spr (P.COL_*),
-- alpha a
function BBCR_DRAFT_PkQuad(i, x, y, w, h, spr, a)
  local P = BBCR_DRAFT_PK
  if a <= 0.001 or w <= 0.5 or h <= 0.5 then
    funcLuaMenuCommand(P.VISIBLE, P.QUAD, i, false)
    return
  end
  if P.spr[i] ~= spr then
    funcLuaMenuCommand(P.SPRITE, P.QUAD, P.ART, spr, P.NODE_QUAD, 0, i)
    P.spr[i] = spr
  end
  funcLuaMenuCommand(P.VISIBLE, P.QUAD, i, true)
  funcLuaMenuCommand(P.SCALE, P.QUAD, w / P.Q, h / P.Q, 1, i)
  funcLuaMenuCommand(P.POS, P.QUAD, x, -y, 0, i)
  funcLuaMenuCommand(P.MODEL_ALPHA, P.QUAD, i, 0, math.min(1, a))
end

-- a centred, outlined text of the pack: instance i at (x, y), scale s, alpha a ("" or a <= 0 = hidden)
function BBCR_DRAFT_PkText(i, s, x, y, scale, a)
  local P = BBCR_DRAFT_PK
  if s == nil or s == "" or a <= 0.001 then
    funcLuaMenuCommand(P.VISIBLE, P.TXT, i, false)
    return
  end
  local pk = BBCR_DRAFT.pk
  funcLuaMenuCommand(P.VISIBLE, P.TXT, i, true)
  funcLuaMenuCommand(P.POS, P.TXT, x, -y, 0, i)
  funcLuaMenuCommand(P.SCALE, P.TXT, scale, scale, 1, i)
  if pk == nil or pk.texts[i] ~= s then
    funcLuaMenuCommand(P.TEXT_STYLE, P.TXT, i, P.TXT_ON, P.STYLE)
    funcLuaMenuCommand(P.TEXT, P.TXT, P.TXT_ON, s, i)
    funcLuaMenuCommand(P.TEXT, P.TXT, P.TXT_OFF, "", i)
    funcLuaMenuCommand(P.TEXT_VISIBLE, P.TXT, P.TXT_ON, true, i)
    funcLuaMenuCommand(P.TEXT_VISIBLE, P.TXT, P.TXT_OFF, false, i)
    if pk ~= nil then
      pk.texts[i] = s
    end
  end
  funcLuaMenuCommand(P.TEXT_ALPHA, P.TXT, i, P.TXT_ON, a)
end

-- every quad and text of the pack hidden
function BBCR_DRAFT_PkHideAll()
  local P = BBCR_DRAFT_PK
  for i = 0, P.N_QUAD - 1 do
    pcall(funcLuaMenuCommand, P.VISIBLE, P.QUAD, i, false)
  end
  for i = 0, P.N_TXT - 1 do
    pcall(funcLuaMenuCommand, P.VISIBLE, P.TXT, i, false)
  end
end

-- the pack layers' draw priorities (OnSetupLayer / OnOpenLayer): see BBCR_DRAFT_PK
function BBCR_DRAFT_PkPrio(layer, i)
  local P = BBCR_DRAFT_PK
  local prio = 740
  if layer == P.QUAD then
    if i == P.I_DIM then
      prio = 705
    elseif i == P.I_BAND then
      prio = 706
    elseif i < P.I_GLOW then
      prio = 707
    elseif i < P.I_FLASH then
      prio = 712
    elseif i < P.I_SCREEN then
      prio = 726
    else
      prio = 745
    end
    funcLuaMenuCommand(P.SPRITE, layer, P.ART, P.COL_DIM, P.NODE_QUAD, 0, i)
    P.spr[i] = P.COL_DIM
  end
  funcLuaMenuCommand(P.PRIO, layer, i, prio, true)
  funcLuaMenuCommand(P.VISIBLE, layer, i, false)
end

-- the band's geometry for the look's card scale: centre y, height, top
function BBCR_DRAFT_PkBand()
  local P = BBCR_DRAFT_PK
  local h = P.CARD_H * P.scale + 280
  return P.CY, h, P.CY - h / 2
end

-- the place of card i of n on the band (screen px, y down)
function BBCR_DRAFT_PkSpot(i, n)
  local P = BBCR_DRAFT_PK
  return P.CX + (i - (n - 1) / 2) * P.spacing, P.CY
end

-- a candidate card at (x, y) screen px (y down), scale sx x sy
function BBCR_DRAFT_PkCard(i, x, y, sx, sy)
  local B = BBCR_DRAFT
  funcLuaMenuCommand(1389957207 --[[CMND_SET_LAYER_LOCAL_POS?]], B.CARD, x, -y, 0, i)
  funcLuaMenuCommand(3362798188, B.CARD, i, math.max(0.001, sx), math.max(0.001, sy))
end

-- the face of a candidate card: back = the empty slot's «?» card, face = the player, none = hidden
function BBCR_DRAFT_PkFace(c, state)
  local B = BBCR_DRAFT
  local i = c.i
  if c.state == state or not B.ready[B.CARD .. ":" .. i] then
    return
  end
  c.state = state
  if state == "none" then
    funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], B.CARD, i, false)
  elseif state == "back" then
    BBCR_DRAFT_Empty_Card(B.CARD, i, nil, true)
  else
    BBCR_DRAFT_Filled_Card(B.CARD, i, c.param)
  end
  funcLuaMenuCommand(4231609516 --[[CMND_SET_LAYER_MODEL_ALPHA?]], B.CARD, i, 0, 1)
end

-- a new pack for the current candidates (B.cands): rarity order, the best card, the frame plan
function BBCR_DRAFT_PackStart()
  local B, P = BBCR_DRAFT, BBCR_DRAFT_PK
  BBCR_DRAFT_PackLook()
  if B.pk ~= nil then
    BBCR_DRAFT_PackEnd()
  end
  local n = #B.cands
  local pk = {cards = {}, order = {}, f = 0, phase = "anim", texts = {}, best = nil, n = n}
  for i = 0, n - 1 do
    local p = B.cands[i + 1]
    local okr, ok, r = pcall(funcLuaCommand, P.CHARA_INFO, p.param, 8)
    local rar = (okr and ok and type(r) == "number") and r or 0
    local okn, ok2, name = pcall(funcLuaCommand, P.CHARA_INFO, p.param, 0)
    name = (okn and ok2 and type(name) == "string") and name or ""
    pk.cards[i + 1] = {i = i, param = p.param, rarity = rar, name = name, state = nil}
    pk.order[#pk.order + 1] = i + 1
  end
  -- turned lowest rarity first (stable: the offer's order); a unique best card is the last
  table.sort(pk.order, function(a, b)
    local ra, rb = pk.cards[a].rarity, pk.cards[b].rarity
    if ra ~= rb then
      return ra < rb
    end
    return a < b
  end)
  if n >= 2 then
    local last, prev = pk.cards[pk.order[n]], pk.cards[pk.order[n - 1]]
    if last.rarity > prev.rarity then
      pk.best = pk.order[n]
    end
  end
  -- the frame plan
  local F = BBCR_DRAFT_PkFrames
  local intro, deal, stag = F(P.intro), F(P.deal), F(P.deal_stagger)
  local flip, settle, gap = F(P.flip), F(P.settle), F(P.gap)
  pk.intro = intro
  for i = 0, n - 1 do
    pk.cards[i + 1].deal = intro + i * stag
  end
  local t = intro + (n - 1) * stag + deal + F(P.PAUSE)
  for r, k in ipairs(pk.order) do
    if k == pk.best then
      t = t + F(P.suspense)
    end
    pk.cards[k].turn = t
    if r < n then
      t = t + gap
    end
  end
  pk.dealLen, pk.flip, pk.settle, pk.flash = deal, flip, settle, F(P.flash)
  pk.done = t + flip + settle
  -- 1.5.52 (owner): the band's title is the slot's position only («Portero»; «Sobre de jugadores: » removed)
  local rec = B.slots[B.k + 1]
  pk.title = rec ~= nil and BBCR_DRAFT_Text(B.TXT_POS[rec.pos or 0]) or ""
  pk.cur = nil -- where the cursor arrow was put (BBCR_DRAFT_PkCursor)
  B.pk = pk
  for i = 0, P.N_QUAD - 1 do
    pcall(BBCR_DRAFT_PkPrio, P.QUAD, i)
  end
  for i = 0, n - 1 do
    funcLuaMenuCommand(1491630496 --[[CMND_SET_DRAW_PRIORITY]], B.CARD, i, P.CARD_PRIO, true)
    BBCR_DRAFT_PkFace(pk.cards[i + 1], "none")
  end
  for i = n, 4 do
    funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], B.CARD, i, false)
  end
  BBCR_DRAFT_PkSE(P.se_open)
  BBCR_DRAFT_Log("pack", B.k, "cards", n, "best", tostring(pk.best and pk.cards[pk.best].param), "frames", pk.done)
  BBCR_DRAFT_PackRender(false)
end

-- the pack at its frame pk.f; quiet = no sounds (a skip)
function BBCR_DRAFT_PackRender(quiet)
  local B, P = BBCR_DRAFT, BBCR_DRAFT_PK
  local pk = B.pk
  if pk == nil then
    return
  end
  local f, n, S = pk.f, pk.n, P.scale
  local cy, bh, btop = BBCR_DRAFT_PkBand()
  -- the darkness and the band
  local u = PkOutCubic(f / pk.intro)
  BBCR_DRAFT_PkQuad(P.I_DIM, P.CX, P.CY, 2700, 1300, P.COL_DIM, P.dim * u)
  BBCR_DRAFT_PkQuad(P.I_BAND, P.CX, cy, 2700, bh * u, P.COL_BAND, P.BAND_ALPHA * math.min(1, u * 1.5))
  local ew = 2200 * u
  BBCR_DRAFT_PkQuad(P.I_EDGE, P.CX, cy - bh * u / 2, ew, 4, P.COL_EDGE, u)
  BBCR_DRAFT_PkQuad(P.I_EDGE + 1, P.CX, cy + bh * u / 2, ew, 4, P.COL_EDGE, u)
  BBCR_DRAFT_PkText(0, pk.title, P.CX, btop + 46, 1.1, u)
  local screen = 0
  for k = 1, n do
    local c = pk.cards[k]
    local x, y = BBCR_DRAFT_PkSpot(c.i, n)
    local best = k == pk.best
    local want, sx, sy, cx, cyy = "none", S, S, x, y
    local glow, flash = 0, 0
    if f >= c.deal then
      want = "back"
      local d = (f - c.deal) / pk.dealLen
      if d < 1 then
        local e = PkOutCubic(d)
        cx = P.CX + (x - P.CX) * e
        cyy = 1180 + (y - 1180) * e
        local s = S * (0.55 + 0.45 * PkOutBack(d))
        sx, sy = s, s
      elseif f < c.turn and best and f >= c.turn - BBCR_DRAFT_PkFrames(P.suspense) then
        -- the best card throbs while it waits
        local w = 1 + 0.05 * math.sin((f - c.turn) * 0.9)
        sx, sy = S * w, S * w
        glow = 0.5 * PkClamp(1 - (c.turn - f) / BBCR_DRAFT_PkFrames(P.suspense))
      end
      if c.deal == f and not quiet then
        BBCR_DRAFT_PkSE(P.se_deal)
      end
    end
    if f >= c.turn then
      local v = (f - c.turn) / pk.flip
      local over = best and P.OVER_BEST or P.OVER
      if v < 1 then
        local o = v < 0.5 and (1 + 0.12 * v) or (1 + over * (2 * v - 1))
        sx = S * math.abs(math.cos(math.pi * v)) * o
        sy = S * o
        if v >= 0.5 then
          want = "face"
        end
      else
        want = "face"
        local w = (f - c.turn - pk.flip) / pk.settle
        local o = 1 + over * (1 - PkOutCubic(w))
        sx, sy = S * o, S * o
      end
      if want == "face" then
        local tf = f - (c.turn + math.floor(pk.flip / 2))
        flash = 0.9 * (1 - PkClamp(tf / pk.flash)) ^ 2
        glow = PkClamp(tf / 12)
        if best then
          screen = math.max(screen, P.SCREEN_ALPHA * (1 - PkClamp(tf / (pk.flash * 1.5))) ^ 2)
        end
        if c.state ~= "face" and not quiet then
          BBCR_DRAFT_PkSE(best and P.se_best or P.se_reveal)
        end
      end
    end
    if pk.phase == "pick" then
      want, flash, glow = "face", 0, 1
      local on = c.i == B.csel
      local g = on and P.SEL_GROW or 1
      sx, sy, cx, cyy = S * g, S * g, x, y - (on and P.SEL_LIFT or 0)
      if on then
        glow = 1.6
      end
    end
    BBCR_DRAFT_PkFace(c, want)
    c.x, c.y, c.s = cx, cyy, sy
    if want ~= "none" then
      BBCR_DRAFT_PkCard(c.i, cx, cyy, sx, sy)
      if want == "back" then
        BBCR_DRAFT_Rehide(B.CARD, c.i) -- a late face load must not show through the back
      end
    end
    local cw, ch = P.CARD_W * S, P.CARD_H * S
    -- 1.5.52: no tile behind a plain card (BetterUI's cards have none: GLOW_ALPHA 0); the best card keeps its gold glow
    local gcol, ga = P.COL_GLOW, P.GLOW_ALPHA
    if best then
      gcol, ga = P.COL_GOLD, P.GOLD_ALPHA * (0.85 + 0.15 * math.sin(f * 0.15))
    end
    local gx, gy = cx + P.CARD_OX * sy, cyy + P.CARD_OY * sy
    BBCR_DRAFT_PkQuad(P.I_GLOW + c.i, gx, gy, cw * 1.16, ch * 1.16, gcol, math.min(1, ga * glow))
    BBCR_DRAFT_PkQuad(P.I_FLASH + c.i, gx, gy, cw * (1.25 - 0.25 * flash), ch * (1.25 - 0.25 * flash), P.COL_FLASH,
                      flash)
    local na = want == "face" and PkClamp((f - c.turn - pk.flip) / 9) or 0
    if pk.phase == "pick" then
      na = 1
    end
    BBCR_DRAFT_PkText(1 + c.i, c.name, x + P.CARD_OX * S, y + P.CARD_OY * S + ch / 2 + 30, 0.82, na)
  end
  for i = n, 4 do
    BBCR_DRAFT_PkQuad(P.I_GLOW + i, 0, 0, 0, 0, P.COL_GLOW, 0)
    BBCR_DRAFT_PkQuad(P.I_FLASH + i, 0, 0, 0, 0, P.COL_FLASH, 0)
    BBCR_DRAFT_PkText(1 + i, "", 0, 0, 1, 0)
  end
  BBCR_DRAFT_PkQuad(P.I_SCREEN, P.CX, P.CY, 2700, 1300, P.COL_SCREEN, screen)
  -- 1.5.52 (owner): no line under the band while picking («Aceptar: fichar a este jugador» removed); the skip line
  -- stays while the cards are dealt and turned
  local hint = pk.phase ~= "pick" and BBCR_DRAFT_Text(P.TXT_SKIP, "Aceptar: mostrar todos") or ""
  BBCR_DRAFT_PkText(6, hint, P.CX, btop + bh + 44, 0.8, u * 0.85)
  if pk.phase == "pick" then
    BBCR_DRAFT_PkCursor()
  end
end

-- the cursor arrow on the pack's focused card (pick phase): not attached to the card (see BBCR_DRAFT_Cursor), put at
-- the card's left edge, outside the portrait, as the bank's cards have it; sent only when the place changes
function BBCR_DRAFT_PkCursor()
  local B, P = BBCR_DRAFT, BBCR_DRAFT_PK
  local pk = B.pk
  if pk == nil or pk.phase ~= "pick" then
    return
  end
  local c = pk.cards[B.csel + 1]
  if c == nil or c.x == nil then
    return
  end
  local s = c.s or P.scale
  local x = c.x + (P.CARD_OX - P.CARD_W / 2) * s - P.CUR_DX
  local y = c.y + (P.CARD_OY + P.CUR_DY) * s
  local key = math.floor(x + 0.5) .. ":" .. math.floor(y + 0.5)
  if pk.cur == key then
    return
  end
  pk.cur = key
  B.curMoved = true
  funcLuaMenuCommand(1389957207 --[[CMND_SET_LAYER_LOCAL_POS?]], B.CURSOR, x, -y, 0, 0)
end

-- the animation over (its end or a skip): the 5 on the band to pick, the cursor on the chosen one
function BBCR_DRAFT_PackDone(skipped)
  local B = BBCR_DRAFT
  local pk = B.pk
  if pk == nil or pk.phase ~= "anim" then
    return
  end
  pk.f = math.max(pk.f, pk.done)
  pk.phase = "pick"
  BBCR_DRAFT_PackRender(true)
  BBCR_DRAFT_Cursor()
  if skipped then
    BBCR_DRAFT_PkSE(BBCR_DRAFT_PK.se_reveal)
    BBCR_DRAFT_Log("pack skipped")
  end
end

-- a pick: card i flies to the slot k's place on the pitch, the others fade, the screen comes back
function BBCR_DRAFT_PackOutro(k, i)
  local B = BBCR_DRAFT
  local pk = B.pk
  if pk == nil then
    return
  end
  pk.phase = "outro"
  pk.of = 0
  pk.olen = BBCR_DRAFT_PkFrames(BBCR_DRAFT_PK.outro)
  pk.pick = i
  pk.to = B.pos[k]
end

function BBCR_DRAFT_PackOutroRender()
  local B, P = BBCR_DRAFT, BBCR_DRAFT_PK
  local pk = B.pk
  local u = PkClamp(pk.of / pk.olen)
  local e = PkOutCubic(u)
  local a = 1 - e
  local cy, bh, btop = BBCR_DRAFT_PkBand()
  BBCR_DRAFT_PkQuad(P.I_DIM, P.CX, P.CY, 2700, 1300, P.COL_DIM, P.dim * a)
  BBCR_DRAFT_PkQuad(P.I_BAND, P.CX, cy, 2700, bh * a, P.COL_BAND, P.BAND_ALPHA * a)
  BBCR_DRAFT_PkQuad(P.I_EDGE, P.CX, cy - bh * a / 2, 2200 * a, 4, P.COL_EDGE, a)
  BBCR_DRAFT_PkQuad(P.I_EDGE + 1, P.CX, cy + bh * a / 2, 2200 * a, 4, P.COL_EDGE, a)
  BBCR_DRAFT_PkText(0, pk.title, P.CX, btop + 46, 1.1, a)
  BBCR_DRAFT_PkText(6, "", 0, 0, 1, 0)
  BBCR_DRAFT_PkQuad(P.I_SCREEN, 0, 0, 0, 0, P.COL_SCREEN, 0)
  for k = 1, pk.n do
    local c = pk.cards[k]
    local x, y = BBCR_DRAFT_PkSpot(c.i, pk.n)
    BBCR_DRAFT_PkQuad(P.I_FLASH + c.i, 0, 0, 0, 0, P.COL_FLASH, 0)
    BBCR_DRAFT_PkText(1 + c.i, c.name, x + P.CARD_OX * P.scale, y + (P.CARD_OY + P.CARD_H / 2) * P.scale + 30, 0.82, a)
    if c.i == pk.pick and pk.to ~= nil then
      local tx, ty = pk.to[1], -pk.to[2]
      local cx, cyy = x + (tx - x) * e, (y - P.SEL_LIFT) + (ty - (y - P.SEL_LIFT)) * e
      local land = B.SLOT_SCALE * P.LAND -- the large card lands at the small slot card's size
      local s = P.scale * P.SEL_GROW + (land - P.scale * P.SEL_GROW) * e
      BBCR_DRAFT_PkCard(c.i, cx, cyy, s, s)
      BBCR_DRAFT_PkQuad(P.I_GLOW + c.i, cx + P.CARD_OX * s, cyy + P.CARD_OY * s, P.CARD_W * s * 1.16,
                        P.CARD_H * s * 1.16, P.COL_EDGE, 0.5 * a)
    else
      local s = P.scale * (1 - 0.3 * e)
      BBCR_DRAFT_PkCard(c.i, x, y, s, s)
      pcall(funcLuaMenuCommand, 4231609516 --[[CMND_SET_LAYER_MODEL_ALPHA?]], B.CARD, c.i, 0, a)
      BBCR_DRAFT_PkQuad(P.I_GLOW + c.i, 0, 0, 0, 0, P.COL_GLOW, 0)
    end
  end
end

-- the pack gone: its layers hidden, the 5 cards hidden at full alpha
function BBCR_DRAFT_PackEnd()
  local B = BBCR_DRAFT
  local pk = B.pk
  B.pk = nil
  BBCR_DRAFT_PkHideAll()
  if pk ~= nil then
    for k = 1, pk.n do
      local i = pk.cards[k].i
      pcall(funcLuaMenuCommand, 4231609516 --[[CMND_SET_LAYER_MODEL_ALPHA?]], B.CARD, i, 0, 1)
      if B.mode ~= "cands" then
        pcall(funcLuaMenuCommand, 711242136 --[[CMND_SET_LAYER_VISIBLE]], B.CARD, i, false)
      end
    end
  end
end

-- one frame of the pack (Step)
function BBCR_DRAFT_PackStep()
  local B = BBCR_DRAFT
  local pk = B.pk
  if pk == nil then
    return
  end
  if pk.phase == "anim" then
    pk.f = pk.f + 1
    if pk.f >= pk.done then
      BBCR_DRAFT_PackDone(false)
    else
      BBCR_DRAFT_PackRender(false)
    end
  elseif pk.phase == "pick" then
    pk.f = pk.f + 1
    BBCR_DRAFT_PackRender(true) -- the best card's glow keeps breathing
  elseif pk.phase == "outro" then
    pk.of = pk.of + 1
    if pk.of >= pk.olen then
      BBCR_DRAFT_PackEnd()
    else
      BBCR_DRAFT_PackOutroRender()
    end
  end
end

-- the animation runs (input = skip)
function BBCR_DRAFT_PackBusy()
  local pk = BBCR_DRAFT.pk
  return pk ~= nil and pk.phase == "anim"
end

do
  local step = Step
  function Step(...)
    local r = table.pack(step(...))
    BBCR_DRAFT_Step()
    return table.unpack(r, 1, r.n)
  end

  -- the Draft cards: their name table once (as the retail menu does for its own cards in OnSetupLayer), the cursor
  -- labels off (the Draft moves the cursor itself), the draw priority
  local setup = OnSetupLayer
  function OnSetupLayer(a1, a2, ...)
    local r = table.pack(setup(a1, a2, ...))
    if a1 == BBCR_DRAFT.SLOT or a1 == BBCR_DRAFT.CARD then
      local ok, err = pcall(function()
        BBCR_DRAFT_Name(a1, a2)
        funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], a1, a2, BBCR_DRAFT.CARD_CURSOR, false)
        funcLuaMenuCommand(1774843228 --[[CMND_SET_LAYER_ATTACH_LOCATOR_TRACE?]], a1, a2, BBCR_DRAFT.CARD_CURSOR2, false)
        funcLuaMenuCommand(1491630496 --[[CMND_SET_DRAW_PRIORITY]], a1, a2, BBCR_DRAFT.PRIO, true)
      end)
      if not ok then
        BBCR_DRAFT_Log("card setup error", tostring(err))
      end
    elseif a1 == BBCR_DRAFT.ANCHOR then
      pcall(funcLuaMenuCommand, 1389957207 --[[CMND_SET_LAYER_LOCAL_POS?]], a1, BBCR_DRAFT.ANCHOR_X, BBCR_DRAFT.ANCHOR_Y, 0, a2)
    elseif a1 == BBCR_DRAFT_PK.QUAD or a1 == BBCR_DRAFT_PK.TXT then
      pcall(BBCR_DRAFT_PkPrio, a1, a2)
    end
    return table.unpack(r, 1, r.n)
  end

  local open = OnOpenLayer
  function OnOpenLayer(a1, a2, ...)
    local r = table.pack(open(a1, a2, ...))
    if a1 == BBCR_DRAFT.SLOT or a1 == BBCR_DRAFT.CARD then
      local ok, err = pcall(function()
        local B = BBCR_DRAFT
        BBCR_DRAFT_Name(a1, a2) -- only if the setup did not (never twice)
        B.ready[a1 .. ":" .. a2] = true
        if a1 == B.SLOT then
          if B.slots[a2 + 1] ~= nil and B.mode ~= nil then
            BBCR_DRAFT_DrawSlot(a2)
          else
            funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], a1, a2, false)
          end
        else
          BBCR_DRAFT_DrawCand(a2)
        end
        if B.shown == nil or (B.shown[1] == a1 and B.shown[2] == a2) then
          BBCR_DRAFT_Cursor()
        end
      end)
      if not ok then
        BBCR_DRAFT_Log("card open error", tostring(err))
      end
    elseif a1 == BBCR_DRAFT.ANCHOR then
      pcall(funcLuaMenuCommand, 1389957207 --[[CMND_SET_LAYER_LOCAL_POS?]], a1, BBCR_DRAFT.ANCHOR_X, BBCR_DRAFT.ANCHOR_Y, 0, a2)
    elseif (a1 == BBCR_DRAFT_PK.QUAD or a1 == BBCR_DRAFT_PK.TXT) and BBCR_DRAFT.pk == nil then
      pcall(BBCR_DRAFT_PkPrio, a1, a2) -- hidden until a pack opens
    end
    return table.unpack(r, 1, r.n)
  end

  local decide = OnDecideFocus
  function OnDecideFocus(a1, a2, ...)
    if a1 == BBCR_DRAFT.ANCHOR then
      if BBCR_DRAFT.mode ~= nil then
        local ok, err = pcall(BBCR_DRAFT_Decide)
        if not ok then
          BBCR_DRAFT_Log("decide error", tostring(err))
        end
      end
      return
    end
    if a1 == BBCR_DRAFT.GRID and not BBCR_DRAFT.bypass and BBCR_DRAFT.mode == nil then
      local ok, mine = pcall(BBCR_DRAFT_IsDraftSlot, a2)
      if ok and mine then
        local okr, err = pcall(BBCR_DRAFT_Start, a2)
        if not okr then
          BBCR_DRAFT_Log("start error", tostring(err))
          pcall(BBCR_DRAFT_Exit, true)
        end
        return
      end
    end
    return decide(a1, a2, ...)
  end

  local fn = OnFunction
  function OnFunction(a1, a2, ...)
    local B = BBCR_DRAFT
    if B.mode ~= nil and (a1 == B.FN_UP or a1 == B.FN_DOWN or a1 == B.FN_LEFT or a1 == B.FN_RIGHT) then
      local dx = (a1 == B.FN_RIGHT and 1) or (a1 == B.FN_LEFT and -1) or 0
      local dy = (a1 == B.FN_UP and 1) or (a1 == B.FN_DOWN and -1) or 0
      local ok, err = pcall(BBCR_DRAFT_Move, dx, dy)
      if not ok then
        BBCR_DRAFT_Log("move error", tostring(err))
      end
      return 1
    end
    return fn(a1, a2, ...)
  end

  local back = OnBack
  function OnBack(a1, a2, ...)
    if a1 == BBCR_DRAFT.ANCHOR then
      if BBCR_DRAFT.mode ~= nil then
        local ok, err = pcall(BBCR_DRAFT_Back)
        if not ok then
          BBCR_DRAFT_Log("back error", tostring(err))
        end
      end
      return 1
    end
    if a1 == BBCR_DRAFT.GRID and BBCR_DRAFT.mode == nil then
      -- leaving the grid: a draft that never started a campaign is discarded (a running campaign keeps its squad)
      pcall(funcLuaCommand, BBCR_DRAFT.ABANDON)
    end
    return back(a1, a2, ...)
  end

  -- back from the difficulty window after a draft: the page rebuilt too (BBCR_DRAFT_Refresh)
  local closeEnd = OnCloseEndLayer
  if closeEnd ~= nil then -- the free-match script has none
    function OnCloseEndLayer(a1, a2, ...)
      local r = table.pack(closeEnd(a1, a2, ...))
      if a1 == BBCR_DRAFT.DIFFWIN and BBCR_DRAFT.used and BBCR_DRAFT.mode == nil and BBCR_DRAFT.refresh == nil then
        BBCR_DRAFT.refresh = BBCR_DRAFT.REFRESH_FRAMES
      end
      return table.unpack(r, 1, r.n)
    end
  end

  local setupIcon = SetupEmblemIcon
  function SetupEmblemIcon(a1, a2, a3, a4, ...)
    if type(a1) == "number" then
      BBCR_DRAFT.slotArgs[a1] = {a2 or 0, a3, a4}
    end
    return setupIcon(a1, a2, a3, a4, ...)
  end

  -- the panel: while the Draft screen is open it is held (BBCR_DRAFT_PanelHold: no retail redraw, whatever team the
  -- native refresh asks for); otherwise the Draft team shows its players only once the draft is complete (no
  -- placeholder player)
  local formation = UpdateFormation
  function UpdateFormation(a1, a2, ...)
    local B = BBCR_DRAFT
    local free = BBCR_DRAFT_Free()
    if B.mode ~= nil and (a2 ~= false or free) then
      local ok, err = pcall(BBCR_DRAFT_PanelHold)
      if not ok then
        BBCR_DRAFT_Log("panel hold error", tostring(err))
      end
      return
    end
    if free and not B.ours then
      -- the native refresh draws the side being chosen with the tile under the cursor
      B.drawn[a2 ~= false] = a1
      if a1 == B.TEAM then
        B.side = a2 ~= false
      end
    end
    local r = table.pack(formation(a1, a2, ...))
    if a1 == B.TEAM and (a2 ~= false or free) then
      pcall(function()
        local ok, phase = BBCR_DRAFT_Info()
        if not (ok and phase >= 2) then
          local layer = (a2 ~= false) and B.LEFT or B.RIGHT
          for i = 0, 10 do
            funcLuaMenuCommand(711242136 --[[CMND_SET_LAYER_VISIBLE]], layer, i, false)
          end
        end
      end)
    end
    return table.unpack(r, 1, r.n)
  end

  -- the panel's tactics stay hidden while the Draft screen is open
  local tactics = UpdateTacticsLayer
  if tactics ~= nil then
    function UpdateTacticsLayer(a1, a2, ...)
      if BBCR_DRAFT.mode ~= nil and (a2 ~= false or BBCR_DRAFT_Free()) then
        return
      end
      return tactics(a1, a2, ...)
    end
  end
end
