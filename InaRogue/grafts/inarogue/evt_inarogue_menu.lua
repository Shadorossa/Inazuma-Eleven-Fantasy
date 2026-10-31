-- evt_inarogue_menu (plain Lua 5.2 source, Expanded Victory Tool, INAROGUE phase 1: the mode's first menu).
-- Opened by loading slot 4 from the slot screen, as the root of its own menu scene ([[VRFW.SaveSlot]] root_menu;
-- docs/game/modes/inarogue-own-scene-plan.md). Back = the slot screen (IRM_Leave).
-- Built by research/scripts/inarogue_build.py; every "1579384326" below is replaced by crc32(name).
-- Screen (evt_inarogue_menu_setting, composed from two retail screens, docs/game/inarogue.md §2):
--   Chronicle top menu (chronicle_mode_top_menu):  big picture buttons mainmenu90_11_..._middle x2, small list row
--       mainmenu90_12_list_item_small (1 of 7 used) on the retail locator layout vsroute04_02 (ball decoration)
--   "Guardar" screen (savedata_management_menu):   background, header, cursor, guide line, button guides, and the
--       detail window save01_04 x1 on save01_03 (cloned objbin, single-window locator) = the INAROGUE info panel
-- Items (2026-09-28, docs/game/modes/inarogue.md §14.5): Empezar (big) / Álbum. "Álbum" opens the child menu
-- evt_rogue_album_menu (the sticker book; it replaced "Banco de jugadores"). "Cómo se juega" and "Pruebas (debug)" are
-- gone (the debug probe block evt_inarogue_probes.lua is no longer merged, inarogue_build.build_lua_menu). "Empezar" /
-- "Continuar" opens the route map evt_rogue_map_menu (step 2, research/scripts/rogue_map_build.py, §11); the run
-- lives in the vr-loader (rogue_run_slot<N>.json, CMND_EVT_RL_RUN_*). No team selection yet (map v1).
-- «100 jugadores al azar» (a testing row, §19) was removed on 2026-10-06.
-- §28 (2026-09-30): «Entrar en INAROGUE» enters at once (no window); «Continuar» goes straight to the map; the small row
-- «Nueva partida» under it starts a new run (one window only when a run in progress would be lost); a match node of
-- the map opens the retail Chronicle VS screen (vs_route_town_vs_team_menu + its enemy formation menu, graft
-- rogue_vs) and «Empezar partido» there launches the match through the dock (request 5, rogue_dock).
-- §30 (2026-10-06, arcade redesign): the «Modos de juego» look. One opaque 1920x1080 backdrop quad evt_inarogue_bg
-- (key art + navy + vignette + «INAROGUE» wordmark + the status plate, research/scripts/inarogue_menu_bg_build.py) over
-- the retail background; ONE big centred button (Continuar / Empezar / Entrar en INAROGUE), the run status as two text
-- lines (evt_inarogue_text) under it, the other rows as a 2-column grid of smaller plates below (Nueva partida only with
-- a run). The engine no longer walks the lists: up / down / left / right are CMD_FUNCTION rows of the setting and the
-- Lua moves the focus on the grid (ARC); Accept still decides the lit row (02d8614f7). The «Guardar» detail window
-- (save01_03 / save01_04) is gone.
-- Result for title_menu_2: parameter crc32("evt_inarogue_result") = 0 back (reserved: 1 = start a run).
-- Rule (position-cards.md §4b): no engine call at top level; funcLuaCommand only exists inside callbacks.
INCLUDE("LUA_PROG_BASE")
INCLUDE("LUA_SAVEDATA_MANAGEMENT_MENU_INC")   -- header helpers (soccer top inc) + general window inc
INCLUDE("LUA_MENU_DEF")                       -- MENU_DEF helpers (the probe options list used it; kept for the dock)

-- ---- texts: text rows of text\rows\rogue_screens.toml (9 languages), read with T() ------------------------------
local TXT = {
  HEADER = "INAROGUE",         -- the mode's name, the same in every language
  START = {492306490 --[[InaRogue.menu.start]]},
  CONTINUE = {1540599785 --[[InaRogue.menu.continue]]},
  -- INAROGUE's own save, slot 4 (docs/game/modes/inarogue.md §13)
  ENTER = {995202523 --[[InaRogue.menu.enter]]},
  NO_SLOTS = {1711516725 --[[InaRogue.menu.no_slots]]},
  NO_MAP = {3696567582 --[[InaRogue.menu.no_map]]},
  NO_LOADER_RUN = {1845972093 --[[InaRogue.menu.no_loader_run]]},
  RUN_ERROR = {2930770915 --[[InaRogue.menu.run_error]]},
  GIFT = {2380131675 --[[InaRogue.menu.gift]]},
  ALBUM = {3149478902 --[[InaRogue.menu.album]]},
  NO_ALBUM = {2549086118 --[[InaRogue.menu.no_album]]},
  -- the match loop (§14)
  MATCH_GO = {1809833446 --[[InaRogue.menu.match_go]]},
  MATCH_FAIL = {4085658833 --[[InaRogue.menu.match_fail]]},
  MATCH_WON_ONE = {3804983730 --[[InaRogue.menu.match_won_one]]},
  MATCH_WON = {757897266 --[[InaRogue.menu.match_won]]},
  MATCH_WON_BOSS_ONE = {3470304948 --[[InaRogue.menu.match_won_boss_one]]},
  MATCH_WON_BOSS = {3518222823 --[[InaRogue.menu.match_won_boss]]},
  MATCH_LOST = {904174386 --[[InaRogue.menu.match_lost]]},
  MATCH_AGAIN = {1828774293 --[[InaRogue.menu.match_again]]},
  MATCH_NO_RESULT = {1873319069 --[[InaRogue.menu.match_no_result]]},
  MATCH_DRAW = {89367191 --[[InaRogue.menu.match_draw]]},
  MATCH_ERROR = {2742814232 --[[InaRogue.menu.match_error]]},
}

local MENU = 1301289148
local ALBUM_MENU = 26522013 -- child menu "Álbum" (the sticker book, rogue_album_book_build.py)
local MAP_MENU = 2533083129     -- child menu: the run's route map (rogue_map_build.py)
local RL_VERSION = @crc:CMND_EVT_LOADER_VERSION@
local SL = {CMD = @crc:CMND_EVT_SLOT_ROGUE@, rogue = false, slot = 4, active = 0, ret = 0, has = false, known = false}
local RL_RUN_INFO = @crc:CMND_EVT_RL_RUN_INFO@     -- () -> exists, phase, cols, nodes, edges, cur, curCol, seed, done
local RL_RUN_START = @crc:CMND_EVT_RL_RUN_START@   -- (seed) -> code, seed
local RL_RUN_ABANDON = 1752049649
local RL_STARTER = @crc:CMND_EVT_RL_STARTER_INFO@   -- () -> budget, bestPhase, giftPending, bankCount, squadSize, pickOn
local RL_GIFT = @crc:CMND_EVT_RL_STARTER_GIFT@      -- () -> added (-1 = not pending)
-- §28 «Nueva partida» row and its one window (9 languages: research/scripts/rogue_play_text_build.py; the literal is
-- the fallback)
local RN = {
  LABEL = {1906940879 --[[evt_ir_run_new]]},
  GUIDE = {1671349537 --[[evt_ir_run_new_guide]]},
  ASK = {2732727377 --[[evt_ir_run_new_ask]]},
}
-- §28 the VS preview of a match node: the retail Chronicle VS screen (vs_route_town_vs_team_menu) with its enemy
-- formation menu, in INAROGUE mode (graft rogue_vs reads the node's match from the loader while VS.KEY is set)
local VS = {
  TEAM_MENU = 831645521,       -- vs_route_town_vs_team_menu
  ENEMY_MENU = 747772244,      -- vs_route_town_vs_enemy_formation_menu
  KEY = 1812559885,  -- parameter: node + 1 while the preview is open (both menus read it, INAROGUE clears it)
  KEY_RESULT = 3687153196,   -- parameter: 1 «Empezar partido», 0 back
}
local SAVE = {BUSY = @crc:CMND_EVT_SLOT_BUSY@, AUTO = @crc:CMND_SYSTEM_AUTO_SAVE@, FRAMES = 45, TRIES = 3}
local KEY_MAP_RESULT = 1333012321   -- 0 back, 2 abandoned, 3 a match is reserved (launched here)
-- the match loop (docs/game/modes/inarogue.md §14): the map reserves a match in the run file (stage 3); this menu
-- launches it through the pre-match team dock; after the match slot 4's title forwards straight into INAROGUE, which
-- reads the trigger's flags and resolves the node before the map opens again
local RL_RESUME = @crc:CMND_EVT_RL_RUN_RESUME@     -- () -> stage, node, kind, event, coin, game, diff, stadium, level, rival
local RL_RESULT = @crc:CMND_EVT_RL_RUN_RESULT@     -- (result, gf, ga) -> code, outcome (1 cleared 2 run over 3 again), isBoss, frags, players
local RL_RECORDED = @crc:CMND_INAROGUE_RL_RUN_RECORDED@  -- () -> result, gf, ga recorded at the match's end (0 none)
local RL_NEXT = 1175064779   -- () -> code, phase
-- v2 runs (docs/game/mods/inarogue-loop-v2.md): the end of a won run and the summary of the last run that ended; the
-- texts come from the script, in the game's language
local RL_OUTRO = @crc:CMND_INAROGUE_RL_RUN_OUTRO@     -- (0) -> pending, title, endless question; (1) -> code, phase; (2) -> code, summary
local RL_SUMMARY = @crc:CMND_INAROGUE_RL_RUN_SUMMARY@  -- () -> text ("" = none)
-- the offer of the board (lib/rogue/offers.lua): (0) -> ok, kind, intro, choices, exclusive; (1, i) -> ok, question,
-- param; (2, i) -> code, text, action, param, slot; (3) -> ok, closing text
local RL_OFFER = @crc:CMND_INAROGUE_RL_RUN_OFFER@
local RL_CHARA_NAME = @crc:CMND_GET_CHARA_INFO@   -- (param, 0) -> ok, name
-- the start options of a new run (lib/rogue/ascension.lua): (0) -> open level, levels, challenges, «add challenges?»;
-- (1, lv) -> ok, question (sets it); (2, i) -> ok, question; (3, i) -> ok; (4, week) -> ok, question; (5, week) -> ok;
-- (6) -> ok (cleared)
local RL_OPTIONS = @crc:CMND_INAROGUE_RL_RUN_OPTIONS@
local RL_LAUNCH = @crc:CMND_EVT_RL_RUN_LAUNCH@     -- (op 0 read / 1 set / 2 clear) -> pending
local RL_RESERVE = @crc:CMND_EVT_RL_RUN_RESERVE@   -- () -> code, game, diff, stadium, level, rival (stage 3 in the run file)
local RL_SQUAD = @crc:CMND_EVT_RL_RUN_SQUAD@       -- (slot) -> ok, uid, param, hdl, tier, cost
local RL_SET_HDL = 3245339429   -- (slot, hdl) -> code
local RL_PARTY_COUNT = @crc:CMND_EVT_RL_PARTY_COUNT@   -- (bank 0 normal / 1 story) -> n (-1 = off / not slot 4)
local RL_PARTY_HDL = @crc:CMND_EVT_RL_PARTY_HDL@       -- (bank, i) -> hdl
-- «Sin rol» rule ([rogue] grant_without_role, party_rt.rs): granted players lose the creation-time coach / manager role
local RL_NO_ROLE_ALL = @crc:CMND_EVT_RL_NO_ROLE_ALL@     -- () -> cleared (-1 off / not slot 4)
local RL_ROLE_CARRY = @crc:CMND_EVT_RL_ROLE_CARRY@      -- (old, new) -> role of the new character
local MT = {   -- retail match calls (roguelite-mode.md §1.2) and the INAROGUE flag block (§5, flag_config rows)
  PRE_MATCH = @crc:CMND_SET_PRE_MATCH_SOCCER_GAME_ID@,      -- CMND_SET_PRE_MATCH_SOCCER_GAME_ID (game)
  DIFF_HELPER = 1104380539,    -- 0x41D3827B (difficulty), the retail VS flow calls it before RESERVE
  RESERVE = @crc:CMND_RESERVE_SOCCER@,        -- CMND_RESERVE_SOCCER (game, stadium, difficulty)
  SET_BYTE = @crc:CMND_SET_GLOBAL_BYTE_FLAG@, GET_BYTE = @crc:CMND_GET_GLOBAL_BYTE_FLAG@,
  F_RESULT = 504862522,        -- EVT_IR_RESULT (byte 619): 1 win / 2 lose / 3 draw, written by the evt_rl_* trigger
  F_GF = 3095885530, F_GA = 652469113, F_PROBE = 3345119360,   -- bytes 620 / 621 / 629 (trigger loaded 11, full time 12)
  F_STATE = 3014640977,        -- EVT_IR_STATE (byte 600): 2 = match pending (mirror of the run file)
}
local KEY_RESULT = 3558246415
-- §20 M4: loot (loader CMND_EVT_RL_RUN_LOOT) and the retail item calls; texts = menu_text rows of the 9 languages
-- (research/scripts/rogue_play_text_build.py), the literal is the fallback
local LT = {
  CMD = @crc:CMND_EVT_RL_RUN_LOOT@,   -- (node, salt) -> kind (1 gear, 2 move, 3 formation, 0 none), id, tier, name, owned, total
  SALT_BOSS = 2,
  CAN_ADD = 765340069, ADD = @crc:CMND_ADD_ITEM_ONLY@, ITEM_GET = 3675423478 --[[sysmes_item_get]],
  BOSS = {4139710894 --[[evt_ir_loot_boss]]},
  FORM = {2884409743 --[[evt_rmap_form]]},
  FULL = {421245024 --[[evt_rmap_full]]},
  USE_GEAR = {1745594814 --[[evt_rmap_use_gear]]},
  USE_MOVE = {2356268381 --[[evt_rmap_use_move]]},
}
local boss_loot = nil

-- ---- layers -----------------------------------------------------------------------------------------------------
local L_MID = 4042532538        -- mainmenu90_11_chronicle_top_list_item_middle (2 instances, big picture buttons)
local L_SMALL = 530619243       -- mainmenu90_12_list_item_small (7 instances in the setting, 1 used)
local L_LOC = 234014212         -- vsroute04_02_chronicle_top_locator (retail layout: item locators + ball decoration)
local L_HEADER = 575058101      -- mainmenu90_01_header
local L_GUIDE_LINE = 3078308064 -- mainmenu90_05_content_guide_line01
local L_CURSOR = 2296367164     -- cmn05_01_cursor
local L_BTN_GUIDE = 1138543975  -- mainmenu01_06_base_button_guide
local L_BTN = 9396745           -- mainmenu01_07_button_guide
local L_RET = 2005383485        -- mainmenu01_10_return_arrow_button_guide
local L_BG = 2005381972         -- evt_inarogue_bg (cmn01_10 quad, priority 451): the 1920x1080 arcade backdrop (§30)
local L_TXT = 186549736         -- evt_inarogue_text (centred white text, retail fs_36_w_cc): the tile captions (§30)
-- §30: ONE big row (the main action) and the small rows as a grid (ITEMS is built at OnInit / RefreshItems: «Nueva
-- partida» only with a run in progress). The engine does not walk the lists any more (the arrows are CMD_FUNCTION rows,
-- OnFunction); the Lua moves the focus and keeps the NATIVE focus on the lit row (FOCUS_SET, list switch).
local N_MID, N_SMALL, N_SMALL_LAYER = 1, 3, 7   -- N_SMALL: small rows in use (RefreshItems); the setting has 7
-- «Plantilla de equipo» row: the retail label (1923260944, soccer_top_menu t8[1]: all 9 languages) and our guide line
local TEAM_ROW = {LABEL = 1923260944,
  GUIDE = {2075086938 --[[evt_ir_team_guide]]}}

local C = {
  TEXT = @crc:CMND_SET_MENU_TEXT_STRING@,          -- CMND_SET_MENU_TEXT_STRING (layer, node, string, idx)
  MESH_VISIBLE = @crc:CMND_SET_MESH_VISIBLE@,  -- (layer, mesh, bool, idx)
  LAYER_VISIBLE = @crc:CMND_SET_LAYER_VISIBLE@,  -- (layer, idx, bool)
  SPRITE = 558735651,         -- (layer, textureCrc, spriteCrc, nodeCrc, 0, idx)
  PRIM_INDEX = @crc:CMND_SEARCH_PRIM_INDEX@,    -- (layer, idx, primName) -> prim
  PRIM_VALUE = 3609943765,    -- (layer, idx, prim, value)
  PRIM_VISIBLE = 1233047821,  -- (layer, idx, primName, bool)
  ATTACH_TRACE = @crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@,  -- (layer, idx, label, bool)
  OPEN_LAYER = @crc:CMND_OPEN_LAYER@,
  ANIME = @crc:CMND_PLAY_ANIME_TYPE@,         -- CMND_PLAY_ANIME_TYPE (layer, idx, type, event 0 in / 2 out, set)
  FOCUS_ENABLE = @crc:CMND_SET_ENABLE_CTRL_FOCUS@,  -- (layer, bool)
  FOCUS_ACTIVE = @crc:CMND_IS_CTRL_FOCUS_ACTIVE@,   -- (layer) -> bool
  FOCUS_IDX = 2603265800,     -- (layer) -> focused instance
  FOCUS_SET = 3466097042,     -- (layer, idx)
  FOCUS_MARK = 1778826357,    -- (layer, idx, bool)
  FOCUS_CMD = 2559269762,     -- (layer, cmdCrc, bool): end-of-list shift on/off (retail chronicle / Guardar)
  LIST_NUM = 3252599449,      -- (layer, count)
  CURSOR_LOC = @crc:CMND_SET_CURSOR_LOCATOR@,     -- (layer, crc32("cursor"), idx, count)
  DRAW_PRIORITY = @crc:CMND_SET_DRAW_PRIORITY@, -- CMND_SET_DRAW_PRIORITY (layer, idx, prio, bool)
  GUIDE_SET = 2209673388,     -- button guide (menu, layer, texts, icons, a, b, c)
  GUIDE_CMD = 452337289,      -- button guide commands (menu, layer, cmds)
  SE = @crc:CMND_SND_PLAY_SE@,
  MENU_ACTIVE = 1558704558,   -- (menu, bool)
  CLOSE_MENU = @crc:CMND_CLOSE_MENU_OBJECT@,     -- CMND_CLOSE_MENU_OBJECT
  FADE = 609722083,           -- (1 out / 0 in, seconds)
  FADE_DONE = 2259183189,
  MSG_OPEN = 2289627655, MSG_KIND = 2351835063, MSG_RESULT = 1523741473, MSG_DONE = 682363669,
  MSG_BUSY = 898725220,
  OPEN_MENU = @crc:CMND_OPEN_MENU_OBJECT@,      -- CMND_OPEN_MENU_OBJECT (menu)
  EXIST_MENU = @crc:CMND_IS_EXIST_MENU_OBJECT@,    -- CMND_IS_EXIST_MENU_OBJECT (menu)
  LOG = @crc:CMND_EVT_LOG@,   -- vr-loader log (optional; without the loader the call just fails inside pcall)
}
local CUR = 3313461902          -- crc32("cursor")
local T_ACTIVE, T_FOCUS, T_BUTTON = 1286797620, 2734777837, 973515837   -- anime types Active / Focus, event «button»
local SIGNAL_LABEL = 1946981877 -- middle item attach to cmn01_17_menu_signal_icon (layer not in this screen)
local G_ACCEPT, I_ENTER, K_ENTER = 1847312674 --[[Aceptar]], 2750714971 --[[<CMD_ENTER>]], 1981080283 --[[CMD_ENTER]]
local SE_OK, SE_DECIDE, SE_BACK = 3848881948, 4235359837, 202039849

-- list item sprites (retail chronicle_mode_top_menu t3 table)
local TEX_MID = {tex = 2791184640 --[[#/menu/100_mainmenu/mainmenu90/mainmenu90_11/mainmenu90_11.g4tx]],
                 on = 2456717267 --[[list_icon_dmy_m01_on]], ok = 3791942492, off = 2705476609 --[[list_icon_dmy_m01_off]]}

-- §30 the screen (docs/game/modes/inarogue.md §30; art + mocks: research/scripts/inarogue_menu_bg_build.py, whose GEOM
-- has the same numbers as ARC). §30.5 (07/10): one panel under the key art, every button ours, one slant:
--   1. the main button (Continuar / Empezar / Entrar en INAROGUE) across the row; with a run it shares the row with
--      «Nueva partida» (icon + label, same height)
--   2. the tiles (GRID, data-driven, up to 4): together they span the row; the caption on a band at the tile bottom
--   3. Ayuda («?» + label): right end of the guide-line band
-- Every button is drawn by our quads (evt_inarogue_plate / _ol / _pic / _text, atlas evt_inarogue_menu_ui.g4tx) over an
-- INVISIBLE list instance that keeps the engine's focus and mouse hit area: main = mainmenu90_11 #0, «Nueva partida» =
-- #1, tiles + Ayuda = mainmenu90_12 #0.. (scaled so their _touch_list01 box covers the quad).
-- A new tile (e.g. «Avatares»): a GRID row {id, pic}, its pic in the atlas (the builder's pictures()), its label in
-- ItemText and its action in Dispatch.
local GRID = {
  {id = "album", pic = "album"},
  {id = "team", pic = "team"},
  {id = "shop", pic = "shop"},   -- the INAROGUE shop: opened through the hook EVT_IR_EXTRA.shop (graft rogue_avatars)
}
-- «Tienda» label: menu_text row evt_ir_shop_label (es / en); a hook's own text() wins (Dispatch / ItemText)
local SHOP_LABEL = {3213284501 --[[evt_ir_shop_label]]}
local ITEMS = {}
-- for the grafts that add a tile the pre-§30 way (rogue_avatars: ITEM_DEFS[id] + GRID {id}): a GRID row without
-- `pic` uses the pic named like its id (the atlas has «avatars»)
local ITEM_DEFS = {}
local TEX_SMALL = {tex = 2405639780 --[[#/menu/100_mainmenu/mainmenu90/mainmenu90_12/mainmenu90_12.g4tx]],
                   on = 2880627768 --[[list_icon_dmy_s01_on]], ok = 3688370359, off = 2527308690 --[[list_icon_dmy_s01_off]]}

local ARC = {
  -- §30.5 (07/10) one designed panel: every button is our quad (one slant, glass plates / VR-blue lit plates, glyphs,
  -- labels); the retail list rows are only invisible anchors (focus + mouse hit area). Numbers = the builder's GEOM.
  CX = 960, ROW_W = 1280, GAP = 22, SLANT = 14 * (874 / 524) / 85,
  MAIN_CY = 628, MAIN_H = 124, NEW_W = 250, NEW_BAND = 40,
  TILE_TOP = 714, TILE_H = 186, BAND_H = 50,
  HELP_W = 250, HELP_H = 70, HELP_CY = 949,
  FOCUS_S = 1.04, OL_PAD = 18,
  MAIN_LABEL_S = 1.4, NEW_LABEL_S = 0.74, HELP_LABEL_S = 0.82,
  CAP_S = {1.0, 1.0, 0.9, 0.66},             -- caption text scale by tile count
  MID_ATC_Y = 222, MID_PITCH = 108,          -- vsroute04_02 _list01 / _list02 (y, down)
  SMALL_ATC_Y = 438, SMALL_PITCH = 82,       -- _list03.. (the small rows)
  MID_TOUCH = {346, 918, 88},                -- mainmenu90_11 _touch_list01: centre x, w, h (item units)
  SMALL_TOUCH = {311, 848, 68},              -- mainmenu90_12 _touch_list01
  -- glyph sizes in the atlas (the builder prints them)
  PIC = {main = {192, 176}, new = {128, 128}, album = {152, 172}, team = {178, 152}, help = {224, 224},
         avatars = {192, 176}, shop = {176, 176}},
  UI_TEX = "#/menu/220_img/evt_rogue/evt_inarogue_menu_ui.g4tx",
  SCALE = @crc:CMND_SET_LAYER_LOCAL_SCALE@,          -- CMND_SET_LAYER_LOCAL_SCALE (layer, sx, sy, sz, idx)
  HIT = 855005857,             -- (layer, idx, bool): the mouse hit area of one instance
  BG_TEX = 35359366 --[[#/menu/220_img/evt_rogue/evt_inarogue_menu_bg.g4tx]], BG_SPRITE = 1530475309 --[[evt_ir_menu_bg]],
  BG_W = 2640,                 -- the retail 21:9 canvas (mainmenu90_00 bg01): 16:9 shows its middle 1920
  NODE_QUAD = 1909474081,      -- icon_new01 (the cmn01_10 quad: 36 px, centred on the origin)
  NODE_TEXT = 378156699,       -- _text_guide01
  SE_MOVE = 2500047763,        -- sy0005 (cursor move)
}
local L_PLATE = 3665788704      -- evt_inarogue_plate (quads, 8): the plates
local L_OL = 1442518161         -- evt_inarogue_ol (quad, 1): the lit button's outline
local L_PIC = 3957954465        -- evt_inarogue_pic (quads, 8): the glyphs
local N_QUAD = 8                -- plate / pic instances: main, Nueva partida, up to 4 tiles, Ayuda (+1 spare)
local N_CAP = 8                 -- label instances of evt_inarogue_text (the same buttons)
local FN = {UP = 4057444869 --[[evt_inarogue_up]], DOWN = 745189908 --[[evt_inarogue_down]],
            LEFT = 1257424199 --[[evt_inarogue_left]], RIGHT = 522968431 --[[evt_inarogue_right]]}
local LAYOUT = {
  POS = @crc:CMND_SET_LAYER_LOCAL_POS@,            -- CMND_SET_LAYER_LOCAL_POS (layer, x, y, z, idx)
  MOUSE_MOVED = 3272825600,    -- funcLuaMenuCommand () -> the mouse moved this frame
  frames = 0,
  nat = nil,                   -- {layer, idx}: where the NATIVE focus is (set here on every move)
  busy = false,                -- our own FOCUS_SET is running (its OnChangeFocus is ignored)
  mouse = false,               -- the last move was the mouse (hover) rather than a key
  mem = {},                    -- row (cy) -> id of the button last left in it by up / down (coming back = that one)
  closed = false,              -- Close() ran: the menu is going away
  guard = 0,                   -- frames left in which Back / decide are ignored (just back from a child screen)
}
-- §30.3 «Ayuda»: the guide pages (menu_text rows evt_ir_help_<n>_t / _b of research/mods/InazumaFantasy/text/rows/
-- menu_text.toml, es + en, editable there; the literal is the fallback). One concept per page.
local HELP_LABEL = {520638014 --[[evt_ir_help_label]]}
local HELP = {
  {t = {1950561251 --[[evt_ir_help_1_t]]}, b = {2157414066 --[[evt_ir_help_1_b]]}},
  {t = {1980075450 --[[evt_ir_help_2_t]]}, b = {2194749675 --[[evt_ir_help_2_b]]}},
  {t = {2009589645 --[[evt_ir_help_3_t]]}, b = {2199081692 --[[evt_ir_help_3_b]]}},
  {t = {1921577224 --[[evt_ir_help_4_t]]}, b = {2254193753 --[[evt_ir_help_4_b]]}},
  {t = {1934269247 --[[evt_ir_help_5_t]]}, b = {2275290734 --[[evt_ir_help_5_b]]}},
}

local cur = 0          -- focused item (index into ITEMS, 0-based)
local items_changed = false   -- BuildItems: the item set differs from the last one (plates to switch off)
local SyncNativeFocus   -- below FocusItem
local evt_co = nil
local run = {active = false}

-- ---- helpers --------------------------------------------------------------------------------------------------
--@lib evt_menu_kit.lua#Call

local function Log(...)
  Call(C.LOG, "inarogue", ...)
end

--@lib evt_menu_kit.lua#Int

-- a menu_text row in the game's language (fallback: the Spanish literal); "{1}".. placeholders
local function T(t, ...)
  local s = Call(@crc:CMND_TEXT_GET@, t[1])
  if type(s) ~= "string" or s == "" then
    s = t[2] or ""
  end
  local a = table.pack(...)
  return (s:gsub("{(%d)}", function(k)
    local v = a[tonumber(k)]
    return v == nil and "" or tostring(v)
  end))
end

local function HasRogueLoader()
  local api, mods = Call(RL_VERSION)
  return type(api) == "number" and type(mods) == "number" and math.floor(mods / 32768) % 2 == 1
end

local function ReadRun()
  local s = {active = false, phase = 0, node = 0, puntos = 0, animo = 0, best = 0, runs = 0, loader = false}
  if HasRogueLoader() then
    s.loader = true
    local exists, phase, cols, _, _, _, col, _, done = Call(RL_RUN_INFO)
    if exists == true then
      s.active, s.phase, s.node, s.cols = true, Int(phase), Int(col), Int(cols)
      s.best = Int(phase)
      s.runs = Int(done)
    end
  end
  return s
end

local function ItemText(it)
  if it.id == "new" then
    return T(RN.LABEL)
  elseif it.id == "start" then
    if not SL.rogue then
      return T(TXT.ENTER)
    end
    return T(run.active and TXT.CONTINUE or TXT.START)
  elseif it.id == "team" then
    local s = Call(@crc:CMND_TEXT_GET@, TEAM_ROW.LABEL)
    return type(s) == "string" and s or ""
  elseif it.id == "help" then
    return T(HELP_LABEL)
  elseif it.id == "shop" then
    local x = type(EVT_IR_EXTRA) == "table" and EVT_IR_EXTRA.shop or nil
    if x ~= nil and type(x.text) == "function" then
      return x.text()
    end
    return T(SHOP_LABEL)
  end
  return T(TXT.ALBUM)
end

-- §30.5: the guide line describes the lit button in one short line (menu_text rows evt_ir_desc_*, es + en)
ARC.DESC = {   -- (in ARC: the chunk is near the 200-locals limit)
  continue = {1675776503 --[[evt_ir_desc_continue]]},
  start = {1732709891 --[[evt_ir_desc_start]]},
  enter = {1095670754 --[[evt_ir_desc_enter]]},
  new = {762093054 --[[evt_ir_desc_new]]},
  album = {3248895439 --[[evt_ir_desc_album]]},
  team = {2551530434 --[[evt_ir_desc_team]]},
  shop = {4036995455 --[[evt_ir_desc_shop]]},
  help = {1416804721 --[[evt_ir_desc_help]]},
}
local function ItemGuide(it)
  local key = it.id
  if it.id == "start" then
    key = (not SL.rogue and "enter") or (run.active and "continue") or "start"
  end
  local x = type(EVT_IR_EXTRA) == "table" and EVT_IR_EXTRA[it.id] or nil
  if type(x) == "table" and type(x.desc) == "function" then
    return x.desc()               -- a graft's tile describes itself
  end
  if ARC.DESC[key] ~= nil then
    return T(ARC.DESC[key])
  end
  return ItemText(it)
end

local function ItemOf(layer, idx)
  for k, it in ipairs(ITEMS) do
    if it.layer == layer and it.idx == idx then
      return it, k - 1
    end
  end
  return nil
end

local function LayerCount(layer)
  return layer == L_MID and N_MID or N_SMALL
end

-- §30: the buttons of the moment (pure: no engine call; OnInit and RefreshItems). Keeps `cur` on the same button.
local function BuildItems()
  local keep = ITEMS[cur + 1] ~= nil and ITEMS[cur + 1].id or nil
  local A = ARC
  local x0 = A.CX - A.ROW_W / 2
  local list = {}
  N_MID = 1
  if SL.rogue and run.active then       -- a run would be lost: «Nueva partida» (without a run «Empezar» starts one)
    local mw = A.ROW_W - A.GAP - A.NEW_W
    table.insert(list, {id = "start", kind = "quad", shape = "mainrun", pic = "main", label = true, layer = L_MID,
                        idx = 0, cx = x0 + mw / 2, cy = A.MAIN_CY, w = mw, h = A.MAIN_H, band = 0})
    table.insert(list, {id = "new", kind = "quad", shape = "new", pic = "new", label = true, layer = L_MID, idx = 1,
                        cx = x0 + A.ROW_W - A.NEW_W / 2, cy = A.MAIN_CY, w = A.NEW_W, h = A.MAIN_H, band = A.NEW_BAND})
    N_MID = 2
  else
    table.insert(list, {id = "start", kind = "quad", shape = "main", pic = "main", label = true, layer = L_MID, idx = 0,
                        cx = A.CX, cy = A.MAIN_CY, w = A.ROW_W, h = A.MAIN_H, band = 0})
  end
  local tiles = {}
  for _, g in ipairs(GRID) do
    if g.when == nil or g.when(run) then
      table.insert(tiles, g)
    end
  end
  local n = math.min(#tiles, 4)
  local tw = (A.ROW_W - (n - 1) * A.GAP) / math.max(n, 1)
  for k = 1, n do
    local g = tiles[k]
    table.insert(list, {id = g.id, kind = "quad", shape = "tile" .. n, pic = g.pic or g.id, label = true,
                        cap_s = A.CAP_S[n], layer = L_SMALL, idx = k - 1, cx = x0 + tw / 2 + (k - 1) * (tw + A.GAP),
                        cy = A.TILE_TOP + A.TILE_H / 2, w = tw, h = A.TILE_H, band = A.BAND_H})
  end
  table.insert(list, {id = "help", kind = "quad", shape = "help", pic = "help", label = true, layer = L_SMALL, idx = n,
                      cx = x0 + A.ROW_W - A.HELP_W / 2, cy = A.HELP_CY, w = A.HELP_W, h = A.HELP_H, band = 0})
  local sig_old, sig_new = {}, {}
  for _, it in ipairs(ITEMS) do
    table.insert(sig_old, it.id)
  end
  for _, it in ipairs(list) do
    table.insert(sig_new, it.id)
  end
  items_changed = table.concat(sig_old, ",") ~= table.concat(sig_new, ",")
  ITEMS, N_SMALL, cur = list, n + 1, 0
  for k, it in ipairs(ITEMS) do
    if it.id == keep then
      cur = k - 1
    end
  end
end

-- §30.5: every list instance is an invisible anchor (focus + hit area): no text
local function SetupItem(it)
  funcLuaMenuCommand(C.TEXT, it.layer, 931545948 --[[_text_list01_on]], "", it.idx)
  funcLuaMenuCommand(C.TEXT, it.layer, 3705682548 --[[_text_list01_off]], "", it.idx)
end

-- §30: every anchor scaled so that its _touch_list01 box is the quad button's box. Sent on setup / open and again for the first frames (the rows' open animation may set
-- their own transform first); harmless when repeated.
local function PlaceRows()
  for _, it in ipairs(ITEMS) do
    local t = it.layer == L_MID and ARC.MID_TOUCH or ARC.SMALL_TOUCH
    local sx, sy = it.w / t[2], it.h / t[3]
    local atc = it.layer == L_MID and (ARC.MID_ATC_Y + ARC.MID_PITCH * it.idx)
                or (ARC.SMALL_ATC_Y + ARC.SMALL_PITCH * it.idx)
    local x, y = it.cx - t[1] * sx, atc - it.cy
    funcLuaMenuCommand(LAYOUT.POS, it.layer, x, y, 0, it.idx)
    funcLuaMenuCommand(ARC.SCALE, it.layer, sx, sy, 1, it.idx)
  end
end

-- one sprite of the menu atlas on a 36 px cmn01_10 quad, centred at (cx, cy) screen px (y down), w x h
local function Quad(layer, idx, sprite, cx, cy, w, h)
  funcLuaMenuCommand(C.LAYER_VISIBLE, layer, idx, true)
  funcLuaMenuCommand(ARC.SCALE, layer, w / 36, h / 36, 1, idx)
  funcLuaMenuCommand(C.SPRITE, layer, CRC32(ARC.UI_TEX), CRC32(sprite), ARC.NODE_QUAD, 0, idx)
  funcLuaMenuCommand(LAYOUT.POS, layer, cx, -cy, 0, idx)
end

-- §30.5 placement (the builder's pic_place / label_place): x of the plate's centre line at row y (it leans right
-- going up), the glyph box and the label of an item, the plate scaled by s about its centre
function ARC.ParaX(it, y)
  return it.cx + ARC.SLANT * (it.cy - y)
end

function ARC.PicPlace(it, pw, ph, s)
  local x, y, k
  if it.shape == "main" or it.shape == "mainrun" then
    k = 0.62 * it.h / ph
    y = it.cy
    x = it.cx - it.w / 2 + ARC.SLANT * it.h / 2 + 46 + pw * k / 2
  elseif it.shape == "help" then
    k = 0.66 * it.h / ph
    y = it.cy
    x = it.cx - it.w / 2 + ARC.SLANT * it.h / 2 + 22 + pw * k / 2
  else
    local area = it.h - it.band
    k = math.min(0.66 * area / ph, 0.5 * it.w / pw)
    y = it.cy - it.h / 2 + area / 2 + 2
    x = ARC.ParaX(it, y)
  end
  return it.cx + (x - it.cx) * s, it.cy + (y - it.cy) * s, pw * k * s, ph * k * s
end

function ARC.LabelPlace(it, s)
  local x, y, ts
  if it.shape == "main" or it.shape == "mainrun" then
    x, y, ts = it.cx + 40, it.cy, ARC.MAIN_LABEL_S
  elseif it.shape == "help" then
    x, y, ts = it.cx + 30, it.cy, ARC.HELP_LABEL_S
  else
    y = it.cy + it.h / 2 - it.band / 2
    x = ARC.ParaX(it, y)
    ts = it.shape == "new" and ARC.NEW_LABEL_S or (it.cap_s or 1)
  end
  return it.cx + (x - it.cx) * s, it.cy + (y - it.cy) * s, ts * s
end

-- §30.5: the buttons (plate on / off by the lit one, a little larger when lit; glyph; label; the lit one's glow)
local function DrawButtons()
  local q, c = 0, 0
  local ol = false
  for k, it in ipairs(ITEMS) do
    if it.kind == "quad" and q < N_QUAD then
      local lit = (k - 1 == cur)
      local st = lit and "on" or "off"
      local s = (lit and it.shape ~= "main" and it.shape ~= "mainrun") and ARC.FOCUS_S or 1
      Quad(L_PLATE, q, "evt_ir_plate_" .. it.shape .. "_" .. st, it.cx, it.cy, it.w * s, it.h * s)
      local p = ARC.PIC[it.pic] or {100, 100}
      local px, py, pw, ph = ARC.PicPlace(it, p[1], p[2], s)
      Quad(L_PIC, q, "evt_ir_pic_" .. it.pic .. "_" .. st, px, py, pw, ph)
      if lit then
        local P = ARC.OL_PAD
        Quad(L_OL, 0, "evt_ir_plate_" .. it.shape .. "_ol", it.cx, it.cy, (it.w + 2 * P) * s, (it.h + 2 * P) * s)
        ol = true
      end
      if it.label and c < N_CAP then
        local lx, ly, ts = ARC.LabelPlace(it, s)
        funcLuaMenuCommand(C.LAYER_VISIBLE, L_TXT, c, true)
        funcLuaMenuCommand(C.TEXT, L_TXT, ARC.NODE_TEXT, ItemText(it), c)
        funcLuaMenuCommand(ARC.SCALE, L_TXT, ts, ts, 1, c)
        funcLuaMenuCommand(LAYOUT.POS, L_TXT, lx, -ly, 0, c)
        c = c + 1
      end
      q = q + 1
    end
  end
  for i = q, N_QUAD - 1 do
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_PLATE, i, false)
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_PIC, i, false)
  end
  for i = c, N_CAP - 1 do
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_TXT, i, false)
  end
  if not ol then
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_OL, 0, false)
  end
end

-- the anchors stay invisible with their hit areas on; the unused list instances hidden without one; list counts
local function ApplyRows()
  if items_changed then        -- the same instance may hold another button now: the big row's plates off
    items_changed = false
    funcLuaMenuCommand(C.ANIME, L_MID, 0, T_ACTIVE, 2, T_BUTTON)
    funcLuaMenuCommand(C.ANIME, L_MID, 0, T_FOCUS, 2, T_BUTTON)
    funcLuaMenuCommand(C.FOCUS_MARK, L_MID, 0, false)
    funcLuaMenuCommand(C.ATTACH_TRACE, L_MID, 0, CUR, false)
    LAYOUT.nat = nil
  end
  funcLuaMenuCommand(C.LIST_NUM, L_MID, N_MID)
  funcLuaMenuCommand(C.LIST_NUM, L_SMALL, N_SMALL)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_MID, 0, false)     -- §30.5: the main button is a quad too
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_CURSOR, 0, false)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_MID, 1, false)
  funcLuaMenuCommand(ARC.HIT, L_MID, 0, false)            -- mouse: LAYOUT.PointerStep (zones on the quads)
  funcLuaMenuCommand(ARC.HIT, L_MID, 1, false)
  funcLuaMenuCommand(C.ATTACH_TRACE, L_MID, 1, CUR, false)
  for k = 0, N_SMALL_LAYER - 1 do
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_SMALL, k, false)
    funcLuaMenuCommand(ARC.HIT, L_SMALL, k, false)
    funcLuaMenuCommand(C.ATTACH_TRACE, L_SMALL, k, CUR, false)
  end
  for _, it in ipairs(ITEMS) do
    SetupItem(it)
  end
  PlaceRows()
  DrawButtons()
end

local function UpdateGuideLine()
  local it = ITEMS[cur + 1]
  if it ~= nil then
    funcLuaMenuCommand(C.TEXT, L_GUIDE_LINE, 378156699 --[[_text_guide01]], ItemGuide(it), 0)
  end
end

local function UpdateButtonGuide()
  local z = {0}
  funcLuaMenuCommand(C.GUIDE_SET, MENU, L_BTN_GUIDE, {G_ACCEPT}, {I_ENTER}, z, z, z)
  funcLuaMenuCommand(C.GUIDE_CMD, MENU, L_BTN_GUIDE, {K_ENTER})
end

-- ---- §30 backdrop -----------------------------------------------------------------------------------------------------
-- the 2640x1080 backdrop (21:9 canvas, centred: 16:9 shows x 360..2280) on the 36 px cmn01_10 quad (centred on its origin; layer origin = the screen's top-left, y up)
local function DrawBg()
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_BG, 0, true)
  funcLuaMenuCommand(ARC.SCALE, L_BG, ARC.BG_W / 36, 1080 / 36, 1, 0)
  funcLuaMenuCommand(C.SPRITE, L_BG, ARC.BG_TEX, ARC.BG_SPRITE, ARC.NODE_QUAD, 0, 0)
  funcLuaMenuCommand(LAYOUT.POS, L_BG, 960, -540, 0, 0)
end

-- the run changed under the open menu (abandoned, lost, started from the dock): the big row's label, the buttons, the
-- guide; a new button set gets the native focus back on the lit button
local function RefreshItems()
  local changed
  BuildItems()
  changed = items_changed
  ApplyRows()
  UpdateGuideLine()
  if changed and SyncNativeFocus ~= nil and not LAYOUT.closed then
    SyncNativeFocus()
  end
end

-- ---- windows (same patterns as the save-slot screen) -------------------------------------------------------------
-- yes/no general window: true = yes
--@lib evt_menu_kit.lua#Ask

-- OK-only message
--@lib evt_menu_kit.lua#Message,Close
local KitClose = Close
-- every close of this menu goes through here: Decide then leaves the native focus alone
local function Close(result)
  LAYOUT.closed = true
  KitClose(result)
end

-- ---- child menus (the album evt_rogue_album_menu, like the retail Guardar -> photo_manage_menu) -------------------
-- every layer of this menu that would show through the child (v2 in game: the small rows and this menu's button
-- guide were drawn under the bank's own)
-- (§30: the backdrop quad too: at priority 451 it would cover the child's own background, 450)
local OWN_LAYERS = {{L_HEADER, 0}, {L_LOC, 0}, {L_MID, 0}, {L_MID, 1}, {L_GUIDE_LINE, 0}, {L_CURSOR, 0},
                    {L_BTN_GUIDE, 0}, {L_RET, 0}, {L_BG, 0}, {L_OL, 0}}
for k = 0, N_SMALL_LAYER - 1 do
  table.insert(OWN_LAYERS, {L_SMALL, k})
end
for k = 0, 4 do
  table.insert(OWN_LAYERS, {L_BTN, k})
end
for k = 0, N_CAP - 1 do
  table.insert(OWN_LAYERS, {L_TXT, k})
end
for k = 0, N_QUAD - 1 do
  table.insert(OWN_LAYERS, {L_PLATE, k})
  table.insert(OWN_LAYERS, {L_PIC, k})
end

local function ShowOwnLayers(visible)
  for _, l in ipairs(OWN_LAYERS) do
    funcLuaMenuCommand(C.LAYER_VISIBLE, l[1], l[2], visible)
  end
end
EVT_IR_ShowOwnLayers = ShowOwnLayers   -- probe D (inserted above this function) hides the menu under the retail dock

-- this menu back after a child / the VS preview: its layers, the unused small rows hidden again, the layout
local function RestoreOwnLayers()
  ShowOwnLayers(true)
  ApplyRows()                 -- the anchors invisible again, the quad buttons redrawn
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_CURSOR, 0, false)   -- §30.5: the lit plate + glow is the cursor
end

-- stay_hidden (optional): called when the child closed; true = this menu stays hidden (§28: the map's result 4 goes
-- straight on to the VS preview, with no frame of this menu in between)
local function OpenChild(menu, missing, stay_hidden)
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
  funcLuaCommand(C.OPEN_MENU, menu)
  coroutine.yield()
  coroutine.yield()
  if not funcLuaMenuCommand(C.EXIST_MENU, menu) then
    Log("child menu missing", menu)
    funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
    Message(missing)
    return
  end
  ShowOwnLayers(false)
  while funcLuaMenuCommand(C.EXIST_MENU, menu) do
    coroutine.yield()
  end
  if stay_hidden ~= nil and stay_hidden() then
    return
  end
  run = ReadRun()                            -- the map may have started / abandoned a run
  BuildItems()                               -- §30: «Nueva partida» comes / goes with the run
  RestoreOwnLayers()
  UpdateGuideLine()
  UpdateButtonGuide()
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
  LAYOUT.guard = 12               -- the Back that closed the child must not leave INAROGUE too (Step counts down)
end

-- the album (every card by original team; the owned players with their bank data): the sticker book, §14.5
local function OpenAlbum()
  OpenChild(ALBUM_MENU, T(TXT.NO_ALBUM))
end

-- ---- the save watch (§19; used by the boss loot and the after-match save) ----------------------------------------
-- The save watch of the office (research/grafts/office_look/ofl_buy_1.lua, «save watch»): the engine drops
-- CMND_SYSTEM_AUTO_SAVE while another save job runs, so the request is sent only when CMND_EVT_SLOT_BUSY is false and
-- sent again (up to SAVE.TRIES times) when no save job was seen within SAVE.FRAMES frames. Stepped from Step().
local save_watch = nil

local function SlotBusy()
  local ok, b = pcall(funcLuaCommand, SAVE.BUSY)
  if not ok then
    return nil
  end
  return b == true
end

local function SaveStep()
  local s = save_watch
  if s == nil then
    return
  end
  local busy = SlotBusy()
  if busy == nil then
    save_watch = nil
    return
  end
  if s.sent then
    if busy then
      s.seen = true
    elseif s.seen then
      Log("save done", s.tag, s.tries)
      save_watch = nil
      return
    end
    s.frames = s.frames + 1
    if not s.seen and s.frames >= SAVE.FRAMES then
      if s.tries >= SAVE.TRIES then
        Log("save gave up", s.tag, s.tries)
        save_watch = nil
        return
      end
      s.sent = false
    end
  elseif not busy then
    s.tries = s.tries + 1
    s.sent, s.seen, s.frames = true, false, 0
    funcLuaCommand(SAVE.AUTO)
    Log("save request", s.tag, s.tries)
  end
end

local function RequestSave(tag)
  if SlotBusy() == nil then   -- a loader without CMND_EVT_SLOT_BUSY: the plain request
    Call(SAVE.AUTO)
    Log("save request (no slot busy command)", tag)
    return
  end
  save_watch = {tag = tag, sent = false, seen = false, frames = 0, tries = 0}
  SaveStep()
end

@IR_SQUAD@

@IR_PROGRESS@

@IR_RUN@

-- ---- actions (docs/game/inarogue.md §4 says where each one goes next) --------------------------------------------
-- ---- INAROGUE's own save, slot 4 (docs/game/modes/inarogue.md §13) ------------------------------------------------
-- The loader's slot info: INAROGUE runs only in slot 4, the root of its own menu scene (loaded from the slot screen).
-- Before the reset into the team dock: fade to black here, this menu inactive (the dock fades the black away itself)
function IRM_FadeOut()
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
  funcLuaCommand(C.FADE, 1, 0.2)
  coroutine.yield()
  for _ = 1, 90 do
    if funcLuaCommand(C.FADE_DONE) then
      break
    end
    coroutine.yield()
  end
end

function IRM_ReadSlots()
  local rs, act, ret, has = Call(SL.CMD)
  SL.known = type(rs) == "number"
  SL.slot, SL.active, SL.ret, SL.has = Int(rs), Int(act), Int(ret), has == true
  SL.rogue = SL.known and SL.active == SL.slot
  Log("slots", "rogue slot", SL.slot, "active", SL.active, "return", SL.ret, "rogue has game", SL.has)
end

@IR_WELCOME@

function IRM_FirstEntry()
  local changed = IRM_UnlockProgress()   -- §25: story completed + Chronicle unlocked in slot 4 (only what is not set yet)
  changed = changed + IRM_MarkHelpsSeen()   -- §24: no retail tutorial pages in the INAROGUE save
  DK.Dress(Int(Call(DK.GET_VS)))        -- §21: the generic kit / emblem on a team that has none (new and old saves)
  if not SL.has or changed > 0 then
    -- a brand-new INAROGUE save is written at once (slot 4 exists before anything tries to load it); an entry that
    -- wrote something (story / Chronicle unlock, help pages) is saved too
    Log("slot 4: save", SL.has and "(progress written)" or "(first save of the new INAROGUE game)")
    Call(@crc:CMND_SYSTEM_AUTO_SAVE@)   -- CMND_SYSTEM_AUTO_SAVE
    SL.has = true
  end
  local _, _, gift = Call(RL_STARTER)
  if gift == true then
    IRW.Run()                   -- the welcome gacha: the first-run starters drawn, revealed and summed up
  end
end

-- Back (owner 2026-10-31): the slot screen over this menu (VRFW_Slots.screen). A slot picked there is loaded and the
-- game resets into it; cancel or slot 4 again = INAROGUE stays. The run is already saved per node / stage (its files)
-- and slot 4 by INAROGUE's saves: nothing to restore, the player's slot is a slot of its own.
function IRM_Leave()
  if type(VRFW_Slots) ~= "table" then
    Log("leave: no VRFW_Slots (framework too old)")
    return
  end
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
  Log("leave: the slot screen over INAROGUE")
  local how, why = VRFW_Slots.screen({ shown = function() ShowOwnLayers(false) end,
    log = function(...) Log("leave:", ...) end })
  Log("leave: stays in INAROGUE (" .. tostring(how) .. ")")
  RestoreOwnLayers()
  UpdateGuideLine()
  UpdateButtonGuide()
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
  LAYOUT.guard = 12               -- the Back that closed the slot screen must not open it again (Step counts down)
  if how == false and type(why) == "string" and why ~= "" then
    Message(why)
  end
end

-- §30.3 «Ayuda»: the guide, one retail general window (OK) per page, «n/N» after the page title
local function ShowHelp()
  for i, pg in ipairs(HELP) do
    Message(string.format("[CY]%s[C]   %d/%d\n%s", T(pg.t), i, #HELP, T(pg.b)))
  end
end

local function Dispatch(it)
  Log("decide", it.id, "rogue slot", SL.rogue)
  if not SL.rogue and it.id ~= "help" then
    Log("decide", it.id, "refused: the INAROGUE save is not the loaded game (enter from the slot screen)")
    return
  end
  if it.id == "help" then
    ShowHelp()
  elseif it.id == "shop" then
    -- the shop screen is the Rogue-points graft's (rogue_avatars): it sets EVT_IR_EXTRA.shop = {text = fn, open = fn}
    local x = type(EVT_IR_EXTRA) == "table" and EVT_IR_EXTRA.shop or nil
    if x ~= nil and type(x.open) == "function" then
      x.open()
    else
      Log("shop: no EVT_IR_EXTRA.shop hook (graft rogue_avatars) yet")
    end
  elseif it.id == "new" then
    NewGame()                     -- §28
  elseif it.id == "team" then
    DK.Edit()                     -- §21: the persistent INAROGUE team in the retail «Plantilla de equipo»
  elseif it.id == "start" then
    StartOrContinue()
  elseif it.id == "album" then
    OpenAlbum()
  end
end

local function Decide(k)
  local it = ITEMS[k + 1]
  if it == nil then
    return
  end
  Dispatch(it)
  -- back from a window (Ask «No», Message) or a child menu with this menu still open: MENU_ACTIVE true may leave the
  -- engine's own list focus elsewhere than the lit row (Nacho 06/10: «Nueva partida» -> No -> «Plantilla de equipo»
  -- fired «Nueva partida» again); the native focus goes back to `cur`
  if not LAYOUT.closed then
    SyncNativeFocus()
  end
end

--@lib evt_menu_kit.lua#StartCo

-- focus moved to item k (0-based): retail chronicle SelectListItem / ChangeFocusToNextLayer
local function MoveFocus(k)
  local new = ITEMS[k + 1]
  if new == nil then
    return
  end
  local old = ITEMS[cur + 1]
  if old ~= nil and k ~= cur and old.kind == "main" then   -- §30: only the big row has retail plates / the cursor
    funcLuaMenuCommand(C.ANIME, old.layer, old.idx, T_ACTIVE, 2, T_BUTTON)
    funcLuaMenuCommand(C.FOCUS_MARK, old.layer, old.idx, false)
    funcLuaMenuCommand(C.ANIME, old.layer, old.idx, T_FOCUS, 2, T_BUTTON)
    funcLuaMenuCommand(C.ATTACH_TRACE, old.layer, old.idx, CUR, false)
  end
  if new.kind == "main" then
    funcLuaMenuCommand(C.ANIME, new.layer, new.idx, T_ACTIVE, 0, T_BUTTON)
    funcLuaMenuCommand(C.FOCUS_MARK, new.layer, new.idx, true)
    funcLuaMenuCommand(C.ATTACH_TRACE, new.layer, new.idx, CUR, true)
    funcLuaMenuCommand(C.CURSOR_LOC, new.layer, CUR, new.idx, LayerCount(new.layer))
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_CURSOR, 0, false)
  cur = k
  DrawButtons()               -- the quad buttons show the lit one (plate on + outline)
  UpdateGuideLine()
end

-- ---- engine callbacks -----------------------------------------------------------------------------------------
local dock_after = false   -- reopened by the title after the retail "Plantilla de equipo" (§16)

local function DockAfter()
  local r = DK.Finish()
  Log("after the dock:", tostring(r))
  if r == "closed" then
    return                    -- the dock opens again (this menu is already closed)
  end
  run = ReadRun()
  RefreshItems()                -- §30: main label, grid, status
  if r == "map" then
    funcLuaCommand(C.SE, SE_DECIDE)
    IRM_OpenMap()
  elseif r == "match" then
    IRM_LaunchMatch(true)
  end
end

local match_after = false   -- the run file says a match is reserved (stage 3): the title reopened us after it

function OnInit()
  LAYOUT.frames = 0
  LAYOUT.closed = false
  LAYOUT.mouse = false
  IRM_ReadSlots()
  if SL.rogue then
    -- an older INAROGUE save: players created with a coach / manager role lose it (only that creation role)
    Log("no role: creation roles cleared", tostring(Call(RL_NO_ROLE_ALL)))
  end
  run = SL.rogue and ReadRun() or {active = false}
  ITEMS, cur = {}, 0
  BuildItems()                    -- §30: the main action + the grid of the moment
  items_changed = false
  VRFW_Param.Clear(KEY_RESULT)
  -- the pre-match dock launched the match (byte 606 = 23, §20 M3): its result is read now; otherwise a match launched
  -- earlier (EVT_IR_STATE 2 = in flight) that left the node at stage 3 is resolved too (no result = played again)
  local played = DK.TakePlayed()
  if not played then
    DK.DropStale()
  end
  dock_after = not played and DK.Pending() ~= 0
  match_after = false
  if SL.rogue and run.active and not dock_after then
    local stage = Int(Call(RL_RESUME))
    -- the run file's recorded result also counts: a game reset after the match (the title's way back) drops the
    -- in-memory bytes 606 / EVT_IR_STATE, never the run file
    match_after = stage == 3 and (played or Int(Call(MT.GET_BYTE, MT.F_STATE)) == 2 or Int(Call(RL_RECORDED)) ~= 0)
  end
  Log("open", run.active, "match_after", match_after, "played", played)
end

function OnSetupLayer(a1, a2)
  if a1 == IRW.TILE then          -- the welcome gacha's tiles: shown only by its summary
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, IRW.open == true)
    return
  end
  if a1 == L_HEADER then
    SetupSoccerTopCommonHeaderLayerInfo(a1, 4153539961, 253801632, 3969848060, 1144161661, 3293713115, 253801632, 1152304044, 305955024, 3007971317)
    SwapSoccerTopCommonHeaderMenuModeIconTexture(1566262113 --[[mode_base02, the Chronicle top's plate]])
    UpdateHeader(3586861540)
    funcLuaMenuCommand(C.SPRITE, a1, 3139293835 --[[#/menu/220_img/evt_rogue/evt_rogue_mode.g4tx]], 2610480106 --[[evt_rogue_mode_plate: INAROGUE's phoenix plate]], 3293713115 --[[header node mode_base01]], 0, 0)
    funcLuaMenuCommand(C.TEXT, a1, 1220590795 --[[_text_sub_title02]], TXT.HEADER)
  elseif a1 == L_BG then
    DrawBg()                      -- §30 (the Chronicle ball decoration of the locator stays under it, retail 304)
  elseif a1 == L_TXT or a1 == L_PLATE or a1 == L_PIC or a1 == L_OL then
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    DrawButtons()
  elseif a1 == L_MID or a1 == L_SMALL then
    local n = LayerCount(a1)
    if a2 == 0 then
      funcLuaMenuCommand(C.LIST_NUM, a1, n)
    end
    local it = ItemOf(a1, a2)
    if it == nil or a2 >= n then
      funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
      funcLuaMenuCommand(C.ATTACH_TRACE, a1, a2, CUR, false)
      funcLuaMenuCommand(ARC.HIT, a1, a2, false)   -- mouse: a hidden row keeps no hit area (docs/game/ui/mouse-support.md)
      return 1
    end
    SetupItem(it)
    if it.kind ~= "main" then
      funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)   -- §30: an anchor under a quad button: focus + hit area only
    end
    PlaceRows()                   -- §30: the layout
    if a1 == L_MID then
      funcLuaMenuCommand(C.ATTACH_TRACE, a1, a2, SIGNAL_LABEL, false)
      if a2 == 0 then
        funcLuaMenuCommand(C.FOCUS_ENABLE, a1, true)
        funcLuaMenuCommand(C.FOCUS_MARK, a1, 0, true)
      end
    end
  elseif a1 == L_GUIDE_LINE then
    UpdateGuideLine()
  end
end

function OnOpenLayer(a1, a2)
  if a1 == IRW.TILE then
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, IRW.open == true)
    return
  end
  if a1 == L_MID and a2 == 0 then
    funcLuaMenuCommand(C.OPEN_LAYER, L_CURSOR, 0)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, 0, false)     -- §30.5: the main button's anchor (the quad is the button)
    PlaceRows()
    funcLuaMenuCommand(C.FOCUS_SET, a1, 0)
    LAYOUT.nat = {layer = L_MID, idx = 0}
    MoveFocus(0)
    UpdateButtonGuide()
    if funcLuaCommand(C.FADE_DONE) then
      funcLuaCommand(C.FADE, 0, 0.3)
    end
    if dock_after then
      dock_after = false
      StartCo(DockAfter)          -- back from the retail team dock (§16)
    elseif match_after then
      match_after = false
      StartCo(IRM_AfterMatchBoard)   -- the result of the reserved match, then the map (§14)
    elseif SL.rogue then
      StartCo(IRM_FirstEntry)   -- slot 4: the first-run starters (bank only; no character is created here)
    end
  elseif a1 == L_SMALL or (a1 == L_MID and a2 == 1) then
    funcLuaMenuCommand(C.ANIME, a1, a2, T_ACTIVE, 2, T_BUTTON)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)    -- §30: anchors of quad buttons (or unused) stay invisible
    PlaceRows()
  elseif a1 == L_BG then
    DrawBg()
  elseif a1 == L_TXT or a1 == L_PLATE or a1 == L_PIC or a1 == L_OL then
    DrawButtons()
  elseif a1 == L_GUIDE_LINE then
    UpdateGuideLine()
  end
end

-- switch off every plate of an item (Active, Focus, mark, cursor trace): the retail ChangeFocusToNextLayer set
local function Unlight(it)
  if it == nil then
    return
  end
  funcLuaMenuCommand(C.ANIME, it.layer, it.idx, T_ACTIVE, 2, T_BUTTON)
  funcLuaMenuCommand(C.ANIME, it.layer, it.idx, T_FOCUS, 2, T_BUTTON)
  funcLuaMenuCommand(C.FOCUS_MARK, it.layer, it.idx, false)
  funcLuaMenuCommand(C.ATTACH_TRACE, it.layer, it.idx, CUR, false)
end

-- the native focus goes to item `want` (list switch when needed), then the cursor / plates (MoveFocus)
local function FocusItem(want, engine_lit)
  local target = ITEMS[want + 1]
  local nat = LAYOUT.nat
  if nat == nil or nat.layer ~= target.layer then
    funcLuaMenuCommand(C.FOCUS_ENABLE, target.layer == L_MID and L_SMALL or L_MID, false)
    funcLuaMenuCommand(C.FOCUS_ENABLE, target.layer, true)
  end
  if nat == nil or nat.layer ~= target.layer or nat.idx ~= target.idx then
    LAYOUT.busy = true
    funcLuaMenuCommand(C.FOCUS_SET, target.layer, target.idx)
    LAYOUT.busy = false
  end
  LAYOUT.nat = {layer = target.layer, idx = target.idx}
  if not engine_lit and target.kind == "main" then   -- a redirected step gets the big row's Focus plate here
    funcLuaMenuCommand(C.ANIME, target.layer, target.idx, T_FOCUS, 0, T_BUTTON)
  end
  MoveFocus(want)
end

-- the native focus back on the lit row `cur` (whatever the engine did to it while a window / child had the input)
SyncNativeFocus = function()
  if ITEMS[cur + 1] == nil then
    return
  end
  LAYOUT.nat = nil
  FocusItem(cur, true)
end

-- §30 keys: the arrows are CMD_FUNCTION rows of the setting (evt_inarogue_up / down / left / right), so the engine never
-- walks its lists. Left / right stay in the row (big button <-> «Nueva partida», tile <-> tile), no wrap; up / down go
-- to the nearest row above / below, to the button last left in that row, else the nearest in x (the left one on a
-- tie). The native focus follows (FocusItem: list switch + FOCUS_SET), so one button is lit and Accept decides it.
local function NavTarget(dir)
  local c = ITEMS[cur + 1]
  if c == nil then
    return nil
  end
  local best, bdy, bdx = nil, nil, nil
  for k, it in ipairs(ITEMS) do
    local dy, dx = it.cy - c.cy, it.cx - c.cx
    local ok
    if dir == "left" or dir == "right" then
      ok = math.abs(dy) < 1 and (dir == "left" and dx < -1 or dir == "right" and dx > 1)
    else
      ok = (dir == "up" and dy < -1) or (dir == "down" and dy > 1)
    end
    if ok then
      local ady, adx = math.abs(dy), math.abs(dx)
      if dir == "left" or dir == "right" then
        ady, adx = adx, 0
      end
      if best == nil or ady < bdy - 1 or (math.abs(ady - bdy) <= 1 and adx < bdx) then
        best, bdy, bdx = k - 1, ady, adx
      end
    end
  end
  if best ~= nil and (dir == "up" or dir == "down") then
    local row = ITEMS[best + 1].cy
    local id = LAYOUT.mem[math.floor(row + 0.5)]
    for k, it in ipairs(ITEMS) do
      if it.id == id and math.abs(it.cy - row) < 1 then
        best = k - 1
      end
    end
  end
  return best
end

local function Nav(dir)
  local want = NavTarget(dir)
  if want == nil or want == cur then
    return
  end
  local from = ITEMS[cur + 1]
  if dir == "up" or dir == "down" then
    LAYOUT.mem[math.floor(from.cy + 0.5)] = from.id
  end
  LAYOUT.mouse = false
  if LAYOUT.ptr ~= nil then
    LAYOUT.ptr.KeyStep()          -- the keys own the selection until the pointer really moves again
  end
  funcLuaCommand(C.SE, ARC.SE_MOVE)
  Unlight(from)
  FocusItem(want, false)
end

-- mouse / VR free cursor (evt_menu_kit.lua#Pointer, docs/game/ui/mouse-support.md §5): one zone per button around
-- its plate quad (the same instance and size DrawButtons draws); hover by movement lights the button, a click decides
-- it. Off while a coroutine, a child screen or the welcome summary has the input.
function LAYOUT.PointerStep()
  if evt_co ~= nil or LAYOUT.closed or LAYOUT.guard > 0 or IRW.open then
    LAYOUT.ptr_idle = true
    return
  end
  local P = LAYOUT.ptr
  if P == nil then
    P = EVT_PointerNew()
    LAYOUT.ptr = P
    LAYOUT.ptr_idle = true
  end
  if LAYOUT.ptr_idle then
    LAYOUT.ptr_idle = false
    P.Reset()                     -- a press held from the screen before is no click here
  end
  P.Begin()
  local q = 0
  for k, it in ipairs(ITEMS) do
    if it.kind == "quad" and q < N_QUAD then
      P.Inst(L_PLATE, q, it.w / 2, it.h / 2, k - 1)
      q = q + 1
    end
  end
  local ev = P.Poll()
  local k = ev.click or ev.hover
  if k == nil or ITEMS[k + 1] == nil then
    return
  end
  if k ~= cur then
    LAYOUT.mouse = true
    if ev.click == nil then
      funcLuaCommand(C.SE, ARC.SE_MOVE)
    end
    Unlight(ITEMS[cur + 1])
    FocusItem(k, false)
  end
  if ev.click ~= nil then
    if ITEMS[k + 1].layer == L_SMALL then
      funcLuaCommand(C.SE, SE_OK)
    end
    StartCo(Decide, k)
  end
end

function OnFunction(a1, a2)
  local id = a1
  if a1 ~= FN.UP and a1 ~= FN.DOWN and a1 ~= FN.LEFT and a1 ~= FN.RIGHT then
    id = a2
  end
  local dir = (id == FN.UP and "up") or (id == FN.DOWN and "down") or (id == FN.LEFT and "left")
              or (id == FN.RIGHT and "right") or nil
  if dir == nil then
    return
  end
  if evt_co == nil and not LAYOUT.closed then
    Nav(dir)
  end
  return 1
end

-- the engine moved its focus by itself: the mouse hovering a row (the cursor follows), or anything else while no key
-- moved it (a window closing, MENU_ACTIVE): then the native focus goes back to the lit row
function OnChangeFocus(a1, a2)
  if (a1 ~= L_MID and a1 ~= L_SMALL) or IRW.open then
    return                        -- the welcome summary covers the rows: hovering their hidden anchors redraws nothing
  end
  if LAYOUT.busy or not funcLuaMenuCommand(C.FOCUS_ACTIVE, a1) then
    return
  end
  local ret = funcLuaMenuCommand(C.FOCUS_IDX, a1)
  if type(ret) ~= "number" or ret < 0 or ret >= LayerCount(a1) then
    return
  end
  local _, k = ItemOf(a1, ret)
  if k == nil then
    return
  end
  if funcLuaMenuCommand(LAYOUT.MOUSE_MOVED) == true then
    LAYOUT.mouse = true
  end
  if not LAYOUT.mouse or evt_co ~= nil then
    if k ~= cur then
      Unlight(ITEMS[k + 1])
      LAYOUT.nat = {layer = a1, idx = ret}
      FocusItem(cur, false)
    end
    return
  end
  if k ~= cur then
    Unlight(ITEMS[cur + 1])
  end
  LAYOUT.nat = {layer = a1, idx = ret}
  FocusItem(k, true)
end

function OnDecideFocus(a1, a2)
  if IRW.Input() then           -- the welcome gacha's summary closes
    return
  end
  if evt_co ~= nil or LAYOUT.guard > 0 or (a1 ~= L_MID and a1 ~= L_SMALL) then
    return
  end
  if LAYOUT.ptr ~= nil and LAYOUT.ptr.Owns() then
    return
  end
  local idx = a2
  if type(idx) ~= "number" or idx < 0 or idx >= LayerCount(a1) then
    idx = funcLuaMenuCommand(C.FOCUS_IDX, a1)
  end
  local _, k = ItemOf(a1, idx)
  if k == nil then
    return
  end
  -- keys decide the lit row (cur, the one the guide line describes); only a mouse click decides the row the engine
  -- reports (its native focus can lag behind cur, e.g. after a window: Nacho 06/10, «Plantilla de equipo» fired the
  -- «Nueva partida» row)
  if k ~= cur and not LAYOUT.mouse and ITEMS[cur + 1] ~= nil then
    Log("decide: engine row", k, "-> lit row", cur)
    k = cur
    a1 = ITEMS[cur + 1].layer
  end
  if a1 == L_SMALL then
    funcLuaCommand(C.SE, SE_OK)   -- the middle item plays its own sound (objbin CMenuSoundCmdProperty)
  end
  StartCo(Decide, k)
end

function OnEnter(a1, a2)
  if IRW.Input() then           -- the welcome gacha's summary closes
    return 1
  end
  if a1 == L_BTN or a1 == L_RET then
    return 1
  end
  if a1 == L_MID or a1 == L_SMALL then
    OnDecideFocus(a1, a2)   -- same as the save-slot screen; the coroutine guard ignores the second call
  end
end

function OnBack(a1)
  if IRW.Input() then           -- the welcome gacha's summary closes
    return 1
  end
  if evt_co ~= nil or LAYOUT.guard > 0 then
    return 1
  end
  funcLuaCommand(C.SE, SE_BACK)
  if SL.rogue then
    StartCo(IRM_Leave)            -- the scene's root: Back = the slot screen
    return 1
  end
  Close(0)
  return 1
end

function Step()
  if LAYOUT.guard > 0 then
    LAYOUT.guard = LAYOUT.guard - 1
  end
  if funcLuaMenuCommand(LAYOUT.MOUSE_MOVED) == true then
    LAYOUT.mouse = true          -- a click now decides the row under the pointer (OnDecideFocus)
  end
  if LAYOUT.frames < 60 then     -- §28 / §30: the rows' open animation settles in the first frames
    LAYOUT.frames = LAYOUT.frames + 1
    PlaceRows()
  end
  LAYOUT.PointerStep()
  if save_watch ~= nil then
    pcall(SaveStep)   -- the autosave (boss loot, after a match), retried while a save job runs (section 19)
  end
  if evt_co ~= nil then
    if coroutine.status(evt_co) == "dead" then
      evt_co = nil
    else
      local ok, err = coroutine.resume(evt_co)
      if not ok then
        PRINT("evt_inarogue_menu: " .. tostring(err))
        Log("error", tostring(err))
        evt_co = nil
        funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
      elseif coroutine.status(evt_co) == "dead" then
        evt_co = nil
      end
    end
  end
end
