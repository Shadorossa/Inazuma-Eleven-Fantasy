-- evt_inarogue_menu (plain Lua 5.2 source, Expanded Victory Tool, INAROGUE phase 1: the mode's first menu).
-- Opened by the 9th button of the mode row (title_menu_2, "Inarogue") as a child menu, like the retail "Guardar".
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

-- ---- texts (Spanish literals; menu_text rows can replace them later) ------------------------------------------
local TXT = {
  HEADER = "INAROGUE",
  START = "Empezar",
  CONTINUE = "Continuar",
  -- INAROGUE's own save, slot 4 (docs/game/modes/inarogue.md §13)
  ENTER = "Entrar en INAROGUE",
  G_ENTER = "INAROGUE tiene una única partida propia (ranura 4), la misma desde cualquier ranura. Nada de tu partida normal entra en ella.",
  ASK_ENTER = "INAROGUE tiene una única partida propia (ranura 4): la misma desde cualquier ranura,\nseparada de tu partida normal. Se cargará la partida de INAROGUE.\n¿Entrar en INAROGUE?",
  ASK_ENTER_NEW = "INAROGUE tiene una única partida propia (ranura 4): la misma desde cualquier ranura,\nseparada de tu partida normal. Todavía no existe: se creará ahora.\n¿Entrar en INAROGUE?",
  NEED_SLOT = "Elige primero tu partida en la pantalla de EMPEZAR (ranura 2 o 3).",
  ASK_LEAVE = "¿Volver a tu partida (ranura %d)?",
  ASK_OPTIONS = "¿Abrir las opciones del juego?",
  ASK_LEAVE_SCREEN = "¿Volver a la selección de ranura?",
  NO_SLOTS = "INAROGUE necesita el vr-loader con las ranuras de guardado activadas.",
  G_START = "Empieza una partida nueva: forma un equipo desde cero y supera fase tras fase.",
  G_CONTINUE = "Continúa la partida en curso desde el último combate.",
  ASK_START = "¿Empezar una partida nueva de INAROGUE?",
  ASK_CONTINUE = "Tienes una partida en curso (fase %d).\n¿Continuarla?",
  ASK_NEW = "¿Abandonar la partida en curso y empezar una nueva?",
  NO_MAP = "El mapa de INAROGUE no está instalado.\nEjecuta research/scripts/rogue_map_build.py --deploy e instala MiMod.",
  NO_LOADER_RUN = "INAROGUE necesita el vr-loader con el módulo \"rogue\" activado\n(app: Proyecto > Loader).",
  RUN_ERROR = "No se pudo crear la partida (código %d).\nMira evt_loader\\loader.log.",
  GIFT = "¡Tu primera partida de INAROGUE!\nRecibes %d jugadores para empezar. Ya están en tu banco.",
  SOON_START = "Próximamente.\nLa primera fase de INAROGUE todavía está en construcción:\nesta versión solo incluye el menú del modo.",
  SOON_CONTINUE = "Próximamente.\nTodavía no se puede continuar una partida.",
  ALBUM = "Álbum",
  G_ALBUM = "Tu colección: todas las cartas del juego por equipo, las que tienes y las que te faltan.",
  NO_ALBUM = "El álbum de INAROGUE no está instalado.\nEjecuta research/scripts/rogue_album_build.py --deploy e instala MiMod.",
  -- the match loop (§14)
  MATCH_GO = "Partido reservado: %s (Nv. %d).\nEl juego carga el partido.",
  MATCH_FAIL = "El juego no aceptó el partido (mira evt_loader\\loader.log).\nLa casilla sigue pendiente.",
  MATCH_WON = "¡VICTORIA!\nCada jugador de tu equipo recibe %d fragmento%s.",
  MATCH_WON_BOSS = "¡Has superado al JEFE de la fase %d!\nCada jugador de tu equipo recibe %d fragmento%s.",
  MATCH_LOST = "DERROTA.\nLa partida de INAROGUE termina en la fase %d.\nTu banco de jugadores no cambia.",
  MATCH_AGAIN = "El partido no terminó con victoria (%s).\nLa casilla sigue pendiente: se juega otra vez.",
  MATCH_NO_RESULT = "sin resultado",
  MATCH_DRAW = "empate",
  MATCH_ERROR = "No se pudo registrar el resultado (código %d).\nMira evt_loader\\loader.log.",
  -- info panel (retail "Guardar" detail window, texts overwritten)
  NONE = "-",
}

local MENU = 1301289148
local ALBUM_MENU = 26522013 -- child menu "Álbum" (the sticker book, rogue_album_book_build.py)
local MAP_MENU = 2533083129     -- child menu: the run's route map (rogue_map_build.py)
local RL_VERSION = 2217361807
local SL = {CMD = 2087918688, rogue = false, slot = 4, active = 0, ret = 0, has = false, known = false}
local RL_RUN_INFO = 3112916915     -- () -> exists, phase, cols, nodes, edges, cur, curCol, seed, done
local RL_RUN_START = 50483520   -- (seed) -> code, seed
local RL_RUN_ABANDON = 1752049649
local RL_STARTER = 3063138160   -- () -> budget, bestPhase, giftPending, bankCount, squadSize, pickOn
local RL_GIFT = 3647369002      -- () -> added (-1 = not pending)
-- §28 «Nueva partida» row and its one window (9 languages: research/scripts/rogue_play_text_build.py; the literal is
-- the fallback)
local RN = {
  LABEL = {1906940879, "Nueva partida"},
  GUIDE = {1671349537, "Empieza una partida nueva desde la fase 1 con tu «Plantilla de equipo»."},
  ASK = {2732727377, "Se perderá la partida en curso (fase {1}).\n¿Empezar una partida nueva?"},
}
-- §28 the VS preview of a match node: the retail Chronicle VS screen (vs_route_town_vs_team_menu) with its enemy
-- formation menu, in INAROGUE mode (graft rogue_vs reads the node's match from the loader while VS.KEY is set)
local VS = {
  TEAM_MENU = 831645521,       -- vs_route_town_vs_team_menu
  ENEMY_MENU = 747772244,      -- vs_route_town_vs_enemy_formation_menu
  KEY = 1812559885,  -- parameter: node + 1 while the preview is open (both menus read it, INAROGUE clears it)
  KEY_RESULT = 3687153196,   -- parameter: 1 «Empezar partido», 0 back
}
local SAVE = {BUSY = 3324595690, AUTO = 3673719958 --[[CMND_SYSTEM_AUTO_SAVE]], FRAMES = 45, TRIES = 3}
local KEY_MAP_RESULT = 1333012321   -- 0 back, 2 abandoned, 3 a match is reserved (launched here)
-- the match loop (docs/game/modes/inarogue.md §14): the map reserves a match in the run file (stage 3); this menu
-- launches it with the retail VS calls and closes with result 8; after the match the title reopens INAROGUE (slot 4),
-- which reads the trigger's flags and resolves the node before the map opens again
local RL_RESUME = 1357403213     -- () -> stage, node, kind, event, coin, game, diff, stadium, level, rival
local RL_RESULT = 591611390     -- (result, gf, ga) -> code, outcome (1 cleared 2 run over 3 again), isBoss, frags, players
local RL_NEXT = 1175064779   -- () -> code, phase
local RL_LAUNCH = 1235145496     -- (op 0 read / 1 set / 2 clear) -> pending
local RL_RESERVE = 4194663851   -- () -> code, game, diff, stadium, level, rival (stage 3 in the run file)
local RL_SQUAD = 1403779880       -- (slot) -> ok, uid, param, hdl, tier, cost
local RL_SET_HDL = 3245339429   -- (slot, hdl) -> code
local RL_PARTY_COUNT = 3644974084   -- (bank 0 normal / 1 story) -> n (-1 = off / not slot 4)
local RL_PARTY_HDL = 2183711168       -- (bank, i) -> hdl
-- «Sin rol» rule ([rogue] grant_without_role, party_rt.rs): granted players lose the creation-time coach / manager role
local RL_NO_ROLE = 3766629437         -- CMND_EVT_RL_NO_ROLE (hdl) -> status (1 cleared, 0 nothing, -1 off / not INAROGUE)
local RL_NO_ROLE_ALL = 1749573420     -- CMND_EVT_RL_NO_ROLE_ALL () -> cleared (-1 off / not slot 4)
local RL_ROLE_CARRY = 4250363233      -- CMND_EVT_RL_ROLE_CARRY (old, new) -> role of the new character
local MT = {   -- retail match calls (roguelite-mode.md §1.2) and the INAROGUE flag block (§5, flag_config rows)
  PRE_MATCH = 3014583614,      -- CMND_SET_PRE_MATCH_SOCCER_GAME_ID (game)
  DIFF_HELPER = 1104380539,    -- 0x41D3827B (difficulty), the retail VS flow calls it before RESERVE
  RESERVE = 1620561217,        -- CMND_RESERVE_SOCCER (game, stadium, difficulty)
  SET_BYTE = 187123515, GET_BYTE = 2769028935,
  F_RESULT = 504862522,        -- EVT_IR_RESULT (byte 619): 1 win / 2 lose / 3 draw, written by the evt_rl_* trigger
  F_GF = 3095885530, F_GA = 652469113, F_PROBE = 3345119360,   -- bytes 620 / 621 / 629 (trigger loaded 11, full time 12)
  F_STATE = 3014640977,        -- EVT_IR_STATE (byte 600): 2 = match pending (mirror of the run file)
}
local P_GET = 3522198769
local KEY_RESULT = 3558246415
-- §20 M4: loot (loader CMND_EVT_RL_RUN_LOOT) and the retail item calls; texts = menu_text rows of the 9 languages
-- (research/scripts/rogue_play_text_build.py), the literal is the fallback
local LT = {
  CMD = 3559964435,   -- (node, salt) -> kind (1 gear, 2 move, 3 formation, 0 none), id, tier, name, owned, total
  SALT_BOSS = 2,
  CAN_ADD = 765340069, ADD = 1897915498 --[[CMND_ADD_ITEM_ONLY]], ITEM_GET = 3675423478 --[[sysmes_item_get]],
  BOSS = {4139710894, "¡El jefe deja un premio!"},
  FORM = {2884409743, "¡Nueva formación: {1}!\nRareza {2} de 4. Ya puedes elegirla en «Formación».\nFormaciones: {3} de {4}."},
  FULL = {421245024, "No cabe en tu inventario: el objeto se queda en el cofre."},
  USE_GEAR = {1745594814, "Equípalo a un jugador en «Plantilla de equipo» (jugador → Equipo)."},
  USE_MOVE = {2356268381, "Colócala a un jugador en «Plantilla de equipo» (jugador → Supertécnicas)."},
}
local boss_loot = nil

-- ---- run state (docs/game/inarogue.md §5). Needs the flag_config rows first: until then OFF and nothing is read.
local FLAGS_ENABLED = false
local F = {
  STATE = 3014640977,           -- byte 600: 0 none, 1 in run, 2 match pending, 3 post-match, 4 run over
  PHASE = 2709635425,           -- byte 605
  NODE = 1662130431,             -- byte 607
  PUNTOS_LO = 4082000058,   -- byte 613
  PUNTOS_HI = 2118189195,   -- byte 614
  ANIMO = 3824003062,           -- byte 615
  BEST_PHASE = 2045827904,   -- byte 624
  RUNS = 2972970979,               -- byte 625
}
local CMD_GET_BYTE_FLAG = 2769028935   -- CMND_GET_GLOBAL_BYTE_FLAG (flagCrc) -> value

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
  GUIDE = {2075086938, "Tu equipo de INAROGUE: formación, titulares, banquillo, equipación y escudo. Se conserva entre partidas."}}

local C = {
  TEXT = 1083631230,          -- CMND_SET_MENU_TEXT_STRING (layer, node, string, idx)
  MESH_VISIBLE = 3405944500,  -- (layer, mesh, bool, idx)
  LAYER_VISIBLE = 711242136,  -- (layer, idx, bool)
  SPRITE = 558735651,         -- (layer, textureCrc, spriteCrc, nodeCrc, 0, idx)
  PRIM_INDEX = 1927054058,    -- (layer, idx, primName) -> prim
  PRIM_VALUE = 3609943765,    -- (layer, idx, prim, value)
  PRIM_VISIBLE = 1233047821,  -- (layer, idx, primName, bool)
  ATTACH_TRACE = 1774843228,  -- (layer, idx, label, bool)
  OPEN_LAYER = 629267548,
  ANIME = 3781155141,         -- CMND_PLAY_ANIME_TYPE (layer, idx, type, event 0 in / 2 out, set)
  FOCUS_ENABLE = 3518307824,  -- (layer, bool)
  FOCUS_ACTIVE = 102308320,   -- (layer) -> bool
  FOCUS_IDX = 2603265800,     -- (layer) -> focused instance
  FOCUS_SET = 3466097042,     -- (layer, idx)
  FOCUS_MARK = 1778826357,    -- (layer, idx, bool)
  FOCUS_CMD = 2559269762,     -- (layer, cmdCrc, bool): end-of-list shift on/off (retail chronicle / Guardar)
  LIST_NUM = 3252599449,      -- (layer, count)
  CURSOR_LOC = 381797568,     -- (layer, crc32("cursor"), idx, count)
  DRAW_PRIORITY = 1491630496, -- CMND_SET_DRAW_PRIORITY (layer, idx, prio, bool)
  GUIDE_SET = 2209673388,     -- button guide (menu, layer, texts, icons, a, b, c)
  GUIDE_CMD = 452337289,      -- button guide commands (menu, layer, cmds)
  SE = 1917805374,
  MENU_ACTIVE = 1558704558,   -- (menu, bool)
  CLOSE_MENU = 320421347,     -- CMND_CLOSE_MENU_OBJECT
  FADE = 609722083,           -- (1 out / 0 in, seconds)
  FADE_DONE = 2259183189,
  P_SET = 3860611758, P_CLEAR = 3363400568,                -- parameter store (numbers only)
  MSG_OPEN = 2289627655, MSG_KIND = 2351835063, MSG_RESULT = 1523741473, MSG_DONE = 682363669,
  MSG_BUSY = 898725220,
  OPEN_MENU = 433545986,      -- CMND_OPEN_MENU_OBJECT (menu)
  EXIST_MENU = 2231168902,    -- CMND_IS_EXIST_MENU_OBJECT (menu)
  LOG = 3661580131,   -- vr-loader log (optional; without the loader the call just fails inside pcall)
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
local SHOP_LABEL = {3213284501 --[[evt_ir_shop_label]], "Tienda"}
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
  SCALE = 3778714801,          -- CMND_SET_LAYER_LOCAL_SCALE (layer, sx, sy, sz, idx)
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
  POS = 1389957207,            -- CMND_SET_LAYER_LOCAL_POS (layer, x, y, z, idx)
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
local HELP_LABEL = {520638014 --[[evt_ir_help_label]], "Ayuda"}
local HELP = {
  {t = {1950561251, "La partida"}, b = {2157414066, "Una partida es una serie de fases; cada fase es un tablero que acaba en un jefe.\nSi pierdes un partido, la partida termina."}},
  {t = {1980075450, "El tablero"}, b = {2194749675, "Avanzas columna a columna: elige una casilla unida a la tuya.\nHay partidos, cofres, tiendas, fichajes y eventos."}},
  {t = {2009589645, "Tu equipo"}, b = {2199081692, "Juegas con tu «Plantilla de equipo»: 11 titulares y hasta 5 suplentes, todos a Nv. 5.\nCada jugador cuesta según su rareza (★); el total no puede pasar del presupuesto."}},
  {t = {1921577224, "Partidos"}, b = {2254193753, "Las casillas de partido son pachangas 5 contra 5 o partidos 11 contra 11.\nGanar despeja la casilla y da fragmentos a tus jugadores; empatar obliga a repetirla."}},
  {t = {1934269247, "Álbum"}, b = {2275290734, "El Álbum reúne a todos los jugadores del modo, por equipo.\nLos que consigues se quedan en tu banco para siempre."}},
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
  local s = Call(4074371074 --[[CMND_TEXT_GET]], t[1])
  if type(s) ~= "string" or s == "" then
    s = t[2]
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
  if not FLAGS_ENABLED then
    return s
  end
  local function B(f)
    return Int(Call(CMD_GET_BYTE_FLAG, f))
  end
  local st = B(F.STATE)
  s.active = st >= 1 and st <= 3
  s.phase, s.node, s.animo = B(F.PHASE), B(F.NODE), B(F.ANIMO)
  s.puntos = B(F.PUNTOS_LO) + 256 * B(F.PUNTOS_HI)
  s.best, s.runs = B(F.BEST_PHASE), B(F.RUNS)
  return s
end

local function ItemText(it)
  if it.id == "new" then
    return T(RN.LABEL)
  elseif it.id == "start" then
    if not SL.rogue then
      return TXT.ENTER
    end
    return run.active and TXT.CONTINUE or TXT.START
  elseif it.id == "team" then
    local s = Call(4074371074 --[[CMND_TEXT_GET]], TEAM_ROW.LABEL)
    return (type(s) == "string" and s ~= "") and s or "Plantilla de equipo"
  elseif it.id == "help" then
    return T(HELP_LABEL)
  elseif it.id == "shop" then
    local x = type(EVT_IR_EXTRA) == "table" and EVT_IR_EXTRA.shop or nil
    if x ~= nil and type(x.text) == "function" then
      return x.text()
    end
    return T(SHOP_LABEL)
  end
  return TXT.ALBUM
end

-- §30.5: the guide line describes the lit button in one short line (menu_text rows evt_ir_desc_*, es + en)
ARC.DESC = {   -- (in ARC: the chunk is near the 200-locals limit)
  continue = {1675776503 --[[evt_ir_desc_continue]], "Vuelve al tablero de la partida en curso."},
  start = {1732709891 --[[evt_ir_desc_start]], "Empieza una partida: fases de tableros que acaban en un jefe."},
  enter = {1095670754 --[[evt_ir_desc_enter]], "Abre la partida de INAROGUE: una sola, aparte de tu partida normal."},
  new = {762093054 --[[evt_ir_desc_new]], "Abandona la partida en curso y empieza otra."},
  album = {3248895439 --[[evt_ir_desc_album]], "Los jugadores del modo, por equipo, y los que ya tienes."},
  team = {2551530434 --[[evt_ir_desc_team]], "Tu equipo de INAROGUE: formación, titulares y equipación."},
  shop = {4036995455 --[[evt_ir_desc_shop]], "Gasta tus Puntos de rogue en avatares desbloqueables."},
  help = {1416804721 --[[evt_ir_desc_help]], "Cómo se juega, página a página."},
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
  funcLuaMenuCommand(ARC.HIT, L_MID, 1, N_MID > 1)
  funcLuaMenuCommand(C.ATTACH_TRACE, L_MID, 1, CUR, false)
  for k = 0, N_SMALL_LAYER - 1 do
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_SMALL, k, false)
    funcLuaMenuCommand(ARC.HIT, L_SMALL, k, k < N_SMALL)   -- mouse: an unused row keeps no hit area (mouse-support.md)
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
-- every way out of this menu (result 0 / 4-9) goes through here: Decide then leaves the native focus alone
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
  OpenChild(ALBUM_MENU, TXT.NO_ALBUM)
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

-- ---- the squad = the retail "Plantilla de equipo" in the INAROGUE save (docs/game/modes/inarogue.md §16) ------------
-- Inserted into evt_inarogue_menu.lua by research/scripts/inarogue_build.py (marker @DOCK@). INAROGUE lives in its own
-- save (slot 4), so the game's own team dock of that save is the run's squad screen (formation, bench, coach,
-- managers, captain, tactics, kit, Ficha, Habilidades, Banco: all retail). The roguelite rules sit on top of it
-- (research/grafts/rogue_dock: only INAROGUE players, points before the run, no team switching) and here:
--   run start: every character of the INAROGUE save except the avatar is deleted (full delete by handle 0x70DBD779:
--       every run starts at Lv 5 and no retail player stays), then every INAROGUE bank player (at most DK.MAX) is
--       created at Lv 5 (CMND_ADD_PARTY, no team set, tag 0x10000000) = the club roster of the retail Banco; a first
--       eleven that fits the points is placed (the user changes it in the dock);
--   the dock opens through the title's own "Mi equipo" request (INAROGUE closes with result 9, the title sends
--       1438851263, title_main reserves soccer_team_dock_menu as in retail); byte flag 606 remembers why (1 run start,
--       2 during the run, 3 before a match) and the dock block adds 10 when it really opened;
--   back from the dock (the title reopens INAROGUE): the VS team is read (positions 0-18 + coach 19) and checked
--       (11 starters, only INAROGUE players, the points before the run). Run start: TEAM_SET per slot + TEAM_COMMIT,
--       the run gets each position (CMND_EVT_RL_RUN_SET_SLOT) and every roster player NOT picked is deleted, so during
--       the run the dock and its Banco hold only the run's players. During the run: the positions are written back.
local DK = {
  DELETE = 1893455737,         -- 0x70DBD779 (hdl): full delete by handle (§12.10 engine facts)
  ADD_PARTY = 1885323816,      -- CMND_ADD_PARTY (AddPartyCore defaults; arg 10 = 16: no team set)
  SET_ATTR = 1525180681, CHECK_ATTR = 29506568,
  GET_VS = 3713813716,         -- CMND_GET_VS_USE_TEAM_SET
  -- the retail SwapChara pair (soccer_formation_menu_inc; docs/game/modes/inarogue.md §26): 1730898405 only CHECKS a
  -- place (nie.exe 0xBEDD50 writes nothing: every earlier DK.PLACE call placed nobody), 193693077 places / moves and
  -- keeps the 11v11 (team 0) and 5v5 (team 1) teams of the dock linked, exactly like the retail «Plantilla 01»
  CHECK = 1730898405,          -- (hdl, set, pos, fromSet, team) -> ok, code
  MOVE = 193693077,            -- (toSet, pos, fromSet, hdl, team); fromSet 16 = from the bank, toSet 16 = to the bank
  POS_IDX = 1721292418,        -- (set, team, posNo) -> ok, member index
  IDX_HDL = 1720957768,        -- (set, team, index, 0) -> ok, handle (index 19 = coach)
  CHARA = 1131797651,          -- (hdl, 4) -> chara_param id
  RL_CHARA = 1144149794,             -- (param) -> tier, cost, inPool, stat, card, element, position (1 GK)
  BANK_COUNT = 2104951661,      -- () -> count, capacity, slot, budget, rosterLimit (nil = DK.MAX)
  BANK_GET = 405423844,          -- (i, sort) -> ok, uid, param, ...
  PICK_STATE = 1488679912,      -- (uid) -> picked, starter cost (fragments applied)
  TEAM_RESET = 1704951671,      -- () -> budget
  TEAM_SET = 864556674,          -- (slot, uid) -> code, spent, budget
  TEAM_INFO = 2095182175,        -- () -> starters, bench, managers, coach, spent, budget, form, ready
  TEAM_COMMIT = 3011761431,    -- (seed) -> code, seed
  SET_SLOT = 1474761521,      -- (slot, uid, hdl) -> code
  GET_BYTE = 2769028935, SET_BYTE = 187123515,
  F_DOCK = 4108793520,  -- byte 606 (the unused "layer" byte of §5): why the dock was opened, +10 once it opened
  R_START = 1, R_RUN = 2, R_MATCH = 3,
  R_PLAYED = 23,               -- byte 606: the pre-match dock reserved the match and closed (rogue_dock, §20 M3)
  R_EDIT = 4,                  -- «Plantilla de equipo» row of the INAROGUE menu outside a run (§21): the team persists
  ORIGIN_MAP = {[3] = true, [5] = true},   -- requests opened from the route map / VS preview (the rest: the menu)
  R_PLAY = 5,                  -- §28: «Empezar partido» in the VS preview: the dock opens black and launches the reserved
                               -- match at once (rogue_dock); a team that cannot play falls back to the pre-match dock
  GET_INFO = 1033065575, SET_INFO = 1506470613,   -- CMND_GET / SET_TEAM_SET_INFO (set, team, field, ...)
  UNIFORM = 1598711521,        -- CMND_EVT_TEAM_UNIFORM (set, team) -> ok, uniformId (away_kit)
  ADD_ITEM = 1897915498,       -- CMND_ADD_ITEM_ONLY (item, n)
  -- the generic look of the INAROGUE team (§21): retail «Equipación estándar» (uni_u119101: item 0x9C3F19FC, uniform
  -- 0x9EDB7BFC) and the retail default club emblem em900001 (ball on a shield, no real team's). Given only when the
  -- team has none (a kit / emblem the user picked in the dock stays)
  KIT_ITEM = 2621380092, KIT_UNIFORM = 2665184252, EMBLEM = 3485768072, NAME = "INAROGUE",
  TT = {   -- texts of the 9 languages (research/scripts/rogue_play_text_build.py); the literal is the fallback
    SAVED = {1221739594, "Equipo guardado: {1} titulares, {2} suplentes. Puntos {3}/{4}.\nEmpezar usará este equipo."},
    FIX = {2464199169, "{1}\nAjústalo en «Plantilla de equipo» antes de empezar."},
    ASK_OPEN = {3589463690, "¿Abrir la «Plantilla de equipo»?"},
  },
  TAG = 268435456,             -- 0x10000000: INAROGUE player
  AVATAR = 4096,               -- attribute 0x1000: the avatar (kept: the field party needs one member)
  LEVEL = 5,
  MAX = 1000,                  -- most bank players created for the run start (the save holds ~5,300)
  T_NO_PARTY = "El vr-loader no puede leer la partida de INAROGUE (CMND_EVT_RL_PARTY_*).\nMira evt_loader\\loader.log.",
  T_NO_PLAYERS = "No se pudo crear ningún jugador del equipo (mira evt_loader\\loader.log).",
  T_DONE = "Equipo listo: %d jugadores creados a Nv. 5 en la plantilla VS %d\n(%d personajes anteriores retirados).",
  T_ROSTER = "Tu banco de INAROGUE (%d jugadores) está en la plantilla del juego, a Nv. 5.\nElige tu equipo en «Plantilla de equipo»: 11 titulares y hasta 5 suplentes,\nentrenador y gerentes. Presupuesto: %d puntos (1★ 1, 2★ 2, 3★ 4, 4★ 6, 5★ 9).\nAtrás en la plantilla = volver a INAROGUE.",
  T_NOT_OPENED = "La «Plantilla de equipo» no se abrió.\nActualiza el vr-loader (Proyecto > Loader) e inténtalo otra vez.",
  T_FEW = "Faltan titulares: %d/11.",
  T_FOREIGN = "Hay %d jugador(es) que no son de INAROGUE en el equipo (el avatar no juega).",
  T_OVER = "Te pasas de puntos: %d/%d.",
  T_BACK = "%s\n¿Volver a la «Plantilla de equipo»?",
  T_ASK_START = "Equipo: %d titulares, %d suplentes, %d gerentes, %s entrenador.\nPuntos %d/%d.\n¿Empezar la partida con este equipo?",
  T_CANCEL = "No se ha empezado ninguna partida. Tu banco no cambia.",
  T_ERROR = "No se pudo guardar el equipo (código %d).\nMira evt_loader\\loader.log.",
  T_READY = "¡Equipo listo! %d jugadores en la partida (%d del banco se quedan fuera).",
  T_ASK_MATCH = "Partido: %s (Nv. %d).\n¿Revisar antes la «Plantilla de equipo»?\n(No = jugar ya.)",
}

local function DK_Byte(v)
  if v == nil then
    return Int(Call(DK.GET_BYTE, DK.F_DOCK))
  end
  Call(DK.SET_BYTE, DK.F_DOCK, v)
  return v
end

-- every owned handle of both lists (normal / story) of the INAROGUE save
local function DK_Handles()
  local out = {}
  for bank = 0, 1 do
    local n = Int(Call(RL_PARTY_COUNT, bank))
    for i = 0, n - 1 do
      local h = Int(Call(RL_PARTY_HDL, bank, i))
      if h ~= 0 then
        table.insert(out, h)
      end
    end
  end
  return out
end

-- the INAROGUE save keeps only the avatar (and `keep[hdl]`)
local function DK_Purge(keep)
  local deleted, kept = 0, 0
  for _, h in ipairs(DK_Handles()) do
    if Call(DK.CHECK_ATTR, h, DK.AVATAR) == true or (keep ~= nil and keep[h]) then
      kept = kept + 1
    else
      Call(DK.DELETE, h)
      deleted = deleted + 1
      if deleted % 20 == 0 then
        coroutine.yield()
      end
    end
  end
  local left = #DK_Handles()
  Log("purge: deleted", deleted, "kept", kept, "owned now", left)
  return deleted
end

local function DK_Create(param)
  local h = Call(DK.ADD_PARTY, param, DK.LEVEL, false, false, 0, 0, false, false, false, 16, 255, 255, 0, false, false, false, 0, false, false)
  if type(h) == "number" and h ~= 0 then
    Call(DK.SET_ATTR, h, DK.TAG, true)
    Call(RL_NO_ROLE, h)                  -- granted players arrive «Sin rol» (no creation-time coach / manager)
    return h
  end
  Log("create", param, "ADD_PARTY FAILED", tostring(h))
  return 0
end

-- handle at position `pos` of team `team` (0 = 11v11, 1 = 5v5) of `set` (19 = the coach, by index); 0 = empty
local function DK_HdlAt(set, team, pos)
  local idx = pos
  if pos ~= 19 then
    local ok, i = Call(DK.POS_IDX, set, team, pos)
    if ok ~= true or type(i) ~= "number" then
      return 0
    end
    idx = i
  end
  local ok2, h = Call(DK.IDX_HDL, set, team, idx, 0)
  return (ok2 == true and type(h) == "number") and h or 0
end

-- The retail place (SwapChara): the check, then the place / move. `from` = 16 (a player in no team of the set: the
-- bank) or `set` (a player of the dock: a move inside it). What the engine does with the OTHER team of the dock (the
-- retail link, docs/game/modes/inarogue.md §26): a player placed from the bank joins both teams (the other one at its
-- lowest free position), one that replaces somebody takes his place in both teams, a move inside the dock only
-- rearranges `team`, and a player in only one team is added to the other one. true = he is at `pos` now.
local function DK_Place(hdl, set, pos, team, from)
  from = from or 16
  local ok, code = Call(DK.CHECK, hdl, set, pos, from, team)
  if ok ~= true then
    Log("place refused by the retail check: hdl", hdl, "set", set, "pos", pos, "team", team, "from", from, "code", tostring(code))
    return false
  end
  Call(DK.MOVE, set, pos, from, hdl, team)
  local got = DK_HdlAt(set, team, pos)
  if got ~= hdl then
    Log("place did not take: hdl", hdl, "set", set, "pos", pos, "team", team, "from", from, "now", got)
    return false
  end
  return true
end

-- positions 0-18 (+ the coach, index 19) of both teams: {[team] = {pos -> hdl}, where = {hdl -> pos}}
local function DK_Teams(set)
  local T = {[0] = {pos = {}, where = {}}, [1] = {pos = {}, where = {}}}
  for team = 0, 1 do
    for pos = 0, 19 do
      local h = DK_HdlAt(set, team, pos)
      if h ~= 0 then
        T[team].pos[pos] = h
        T[team].where[h] = pos
      end
    end
  end
  return T
end

-- first free position of `team` in [a, b] (nil = none)
local function DK_Free(T, team, a, b)
  for p = a, b do
    if T[team].pos[p] == nil then
      return p
    end
  end
  return nil
end

-- The 11v11 and the 5v5 team of the INAROGUE dock are ONE linked roster, as the retail «Plantilla 01»
-- (docs/game/modes/inarogue.md §26). Every INAROGUE edit already goes through the retail place command, which links
-- them; this pass repairs what is left and chooses the five the retail way:
--   1. the same players in both teams: a member of one team only is added to the other one (retail same-set place,
--      at the lowest free position; managers stay managers), a 5v5-only player with no room in the 11v11 goes back to
--      the bank;
--   2. the five (5v5 positions 0-4) is never left with a hole while the 5v5 bench has players. Retail gives a player
--      added to the 11v11 the lowest free 5v5 position but never position 0 (the goalkeeper) of an empty team (nie.exe
--      0xDA1790 swaps with the entry it has just written), so the auto-copy of a dock has no goalkeeper (seen in slot 2
--      set 1 and in the INAROGUE save of 29/09: 5v5 positions 1-11, 0 empty). The goal hole takes the 11v11
--      goalkeeper (from the bench or from the five, whose place is refilled next); the other holes take 5v5 bench
--      players, the 11v11 starters first in 11v11 position order, then the rest by 5v5 position. With the retail add
--      order the five is then the 11v11 goalkeeper + the first four 11v11 outfield players added (11v11 positions 1-4
--      for the automatic eleven). A five the user arranged (no hole) is never changed.
-- -> number of changes
local function DK_Link5(set)
  if type(set) ~= "number" or set < 0 or set >= 16 then
    return 0
  end
  local T = DK_Teams(set)
  local n = 0
  for h, p in pairs(T[0].where) do
    if p ~= 19 and T[1].where[h] == nil then
      local q = p >= 16 and DK_Free(T, 1, 16, 18) or DK_Free(T, 1, 0, 15)
      if q ~= nil and DK_Place(h, set, q, 1, set) then
        T[1].pos[q], T[1].where[h] = h, q
        n = n + 1
        Log("link: 11v11 pos", p, "hdl", h, "-> 5v5 pos", q)
      end
    end
  end
  for h, p in pairs(T[1].where) do
    if p ~= 19 and T[0].where[h] == nil then
      local q = p >= 16 and DK_Free(T, 0, 16, 18) or DK_Free(T, 0, 0, 15)
      if q ~= nil and DK_Place(h, set, q, 0, set) then
        T[0].pos[q], T[0].where[h] = h, q
        Log("link: 5v5 pos", p, "hdl", h, "-> 11v11 pos", q)
      else
        Call(DK.MOVE, 16, p, set, h, 1)
        T[1].pos[p], T[1].where[h] = nil, nil
        Log("link: 5v5-only hdl", h, "has no room in the 11v11: back to the bank")
      end
      n = n + 1
    end
  end
  for hole = 0, 4 do
    if T[1].pos[hole] == nil then
      local best, rank = nil, nil
      for p = 1, 15 do
        local h = T[1].pos[p]
        local p0 = h ~= nil and T[0].where[h] or nil
        -- the goal: the 11v11 goalkeeper, even from the five (his outfield place is then refilled: holes go 0 -> 4)
        if h ~= nil and (p >= 5 or (hole == 0 and p0 == 0)) then
          local r = 1000 + p                                  -- any other 5v5 bench player, by 5v5 position
          if hole == 0 and p0 == 0 then
            r = 0                                             -- the goalkeeper hole: the 11v11 goalkeeper
          elseif p0 ~= nil and p0 >= 1 and p0 <= 10 then
            r = 100 + p0                                      -- an 11v11 starter, in 11v11 position order
          end
          if rank == nil or r < rank then
            best, rank = h, r
          end
        end
      end
      if best ~= nil then
        local from = T[1].where[best]
        if DK_Place(best, set, hole, 1, set) then
          T[1].pos[from], T[1].pos[hole], T[1].where[best] = nil, best, hole
          n = n + 1
          Log("link: 5v5 hole", hole, "<- 5v5 pos", from, "hdl", best, "11v11 pos", tostring(T[0].where[best]))
        end
      end
    end
  end
  if n > 0 then
    Log("link: 11v11 / 5v5 of set", set, "linked,", n, "change(s)")
  end
  return n
end

-- most bank players created in the INAROGUE save: the bank's own limit ([rogue] debug_all_players), else DK.MAX
local function DK_RosterLimit()
  local limit = select(5, Call(DK.BANK_COUNT))
  if type(limit) == "number" and limit > 0 then
    return limit
  end
  return DK.MAX
end

-- chara_param id -> {uid, cost} of the INAROGUE bank
local function DK_BankMap()
  local m, list = {}, {}
  local n = Int(Call(DK.BANK_COUNT))
  for i = 0, n - 1 do
    local ok, uid, param = Call(DK.BANK_GET, i, 0)
    if ok == true and type(param) == "number" then
      local _, cost = Call(DK.PICK_STATE, uid)
      local e = {uid = Int(uid), param = param, cost = Int(cost)}
      m[param] = e
      table.insert(list, e)
    end
    if i % 200 == 199 then
      coroutine.yield()
    end
  end
  return m, list
end

-- the VS team of the INAROGUE save: positions 0-19 -> {hdl, uid, cost} (uid 0 = not an INAROGUE player)
local function DK_ReadTeam(vs, team)
  local map = DK_BankMap()
  local t = {slots = {}, st = 0, be = 0, ma = 0, co = 0, spent = 0, foreign = 0, n = 0}
  for pos = 0, 19 do
    local idx = pos
    if pos ~= 19 then
      local ok, i = Call(DK.POS_IDX, vs, team or 0, pos)
      idx = (ok == true and type(i) == "number") and i or -1
    end
    local h = 0
    if idx >= 0 then
      local ok2, hh = Call(DK.IDX_HDL, vs, team or 0, idx, 0)
      h = (ok2 == true and type(hh) == "number") and hh or 0
    end
    if h ~= 0 then
      local e = map[Call(DK.CHARA, h, 4) or 0]
      t.slots[pos] = {hdl = h, uid = e and e.uid or 0, cost = e and e.cost or 0}
      t.n = t.n + 1
      if e == nil then
        t.foreign = t.foreign + 1
      else
        t.spent = t.spent + e.cost
      end
      if pos <= 10 then
        t.st = t.st + 1
      elseif pos <= 15 then
        t.be = t.be + 1
      elseif pos <= 18 then
        t.ma = t.ma + 1
      else
        t.co = 1
      end
    end
  end
  return t
end

-- a first eleven that fits the points (the user changes it in the dock): the cheapest goalkeeper, then the cheapest
-- players, defenders first, then midfielders, then forwards (positions 1-10 of the formation)
local function DK_AutoFill(made, vs, budget)
  local gk, field = nil, {}
  for _, e in ipairs(made) do
    local pos = select(7, Call(DK.RL_CHARA, e.param))
    e.role = Int(pos)
    if e.role == 1 then
      if gk == nil or e.cost < gk.cost then
        if gk ~= nil then
          table.insert(field, gk)
        end
        gk = e
      else
        table.insert(field, e)
      end
    else
      table.insert(field, e)
    end
  end
  table.sort(field, function(a, b)
    if a.cost ~= b.cost then
      return a.cost < b.cost
    end
    return a.uid < b.uid
  end)
  local spent, pick = 0, {}
  if gk ~= nil and gk.cost <= budget then
    spent = gk.cost
  else
    gk = nil
  end
  for _, e in ipairs(field) do
    if #pick >= (gk and 10 or 11) then
      break
    end
    if spent + e.cost <= budget then
      spent = spent + e.cost
      table.insert(pick, e)
    end
  end
  local order = {[4] = 1, [3] = 2, [2] = 3}   -- DF, MF, FW
  table.sort(pick, function(a, b)
    return (order[a.role] or 4) < (order[b.role] or 4)
  end)
  if gk == nil and #pick > 0 then
    gk = table.remove(pick, 1)
  end
  -- retail place, 11v11 position by position: the engine adds each player to the 5v5 team too (§26)
  local placed = 0
  for pos, e in ipairs(gk and {gk, table.unpack(pick)} or {}) do
    local ok = DK_Place(e.hdl, vs, pos - 1, 0)
    placed = placed + (ok and 1 or 0)
    Log("auto eleven pos", pos - 1, "uid", e.uid, "cost", e.cost, "role", e.role, "placed", tostring(ok))
  end
  Log("auto eleven:", placed, "placed,", spent, "of", budget, "points")
  DK_Link5(vs)
end

-- run start: the INAROGUE save gets the whole INAROGUE bank as its club roster (Lv 5), and a first eleven
function DK.Roster()
  if not SL.rogue then
    return false
  end
  if Int(Call(RL_PARTY_COUNT, 0)) < 0 then
    Log("roster refused: CMND_EVT_RL_PARTY_COUNT unavailable")
    Message(DK.T_NO_PARTY)
    return false
  end
  local deleted = DK_Purge()
  local _, list = DK_BankMap()
  local limit = DK_RosterLimit()
  local made = {}
  for i, e in ipairs(list) do
    if i > limit then
      Log("roster: bank has", #list, "players, only the first", limit, "are created")
      break
    end
    e.hdl = DK_Create(e.param)
    if e.hdl ~= 0 then
      table.insert(made, e)
    end
    if i % 10 == 0 then
      coroutine.yield()
    end
  end
  local vs = Int(Call(DK.GET_VS))
  local budget = Int(Call(RL_STARTER))
  Log("roster: created", #made, "of", #list, "bank players, purged", deleted, "vs set", vs, "budget", budget)
  if #made == 0 then
    Message(DK.T_NO_PLAYERS)
    return false
  end
  DK_AutoFill(made, vs, budget)
  Message(string.format(DK.T_ROSTER, #made, budget))
  return true
end

-- open the retail "Plantilla de equipo" (result 9: the title sends the "Mi equipo" request)
function DK.Open(why)
  DK_Byte(why)
  Log("open the retail team dock, request", why)
  IRM_FadeClose(9)
end

-- () -> the pending request (0 none; 1-5 asked but the dock never opened; 11-15 back from the dock)
function DK.Pending()
  if not SL.rogue then
    return 0
  end
  return DK_Byte()
end

-- need11 = false: during a run the 11 starters are not required here (the pre-match dock checks the starters of the
-- match's own kind: 5 for a pachanga, 11 for a match; a run with a 5-player team could not go back to the map before)
local function DK_Problem(t, budget_on, need11)
  if t.foreign > 0 then
    return string.format(DK.T_FOREIGN, t.foreign)
  elseif need11 ~= false and t.st < 11 then
    return string.format(DK.T_FEW, t.st)
  elseif budget_on and t.spent > t.budget then
    return string.format(DK.T_OVER, t.spent, t.budget)
  end
  return nil
end

-- §21: the generic look of the INAROGUE team (teams 0 and 1 of the VS dock) where it has none: name, emblem, kit
function DK.Dress(vs)
  for team = 0, 1 do
    local okN, name = Call(DK.GET_INFO, vs, team, 6)
    if okN ~= true or type(name) ~= "string" or name == "" then
      Call(DK.SET_INFO, vs, team, 0, DK.NAME)
    end
    local okE, em = Call(DK.GET_INFO, vs, team, 5, 0)
    if okE ~= true or type(em) ~= "number" or em == 0 then
      Call(DK.SET_INFO, vs, team, 1, DK.EMBLEM)
      local _, em2 = Call(DK.GET_INFO, vs, team, 5, 0)
      Log("dress: team", team, "emblem", tostring(em), "->", tostring(em2))
    end
    local okU, uni = Call(DK.UNIFORM, vs, team)
    if okU == true and uni == 0 then
      Call(DK.SET_INFO, vs, team, 5, DK.KIT_ITEM)          -- field 5: kit item id -> owned handle (away-kit.md §1.2)
      local _, u2 = Call(DK.UNIFORM, vs, team)
      if u2 ~= DK.KIT_UNIFORM then
        Call(DK.ADD_ITEM, DK.KIT_ITEM, 1)                  -- not owned yet in the INAROGUE save: give it, set again
        Call(DK.SET_INFO, vs, team, 5, DK.KIT_ITEM)
        _, u2 = Call(DK.UNIFORM, vs, team)
      end
      if u2 ~= DK.KIT_UNIFORM then
        -- the retail path did not take it (28/09 21:15: kit 0 -> 0): the loader writes the generic kit's uniform id
        -- on a kit-less team of the INAROGUE save (away_kit rogue_generic_allowed); the away kit follows the home one
        local okw, u3 = Call(DK.UNIFORM, vs, team, DK.KIT_UNIFORM)
        Log("dress: team", team, "kit written by the loader", tostring(okw), tostring(u3))
        u2 = u3
      end
      Log("dress: team", team, "kit", tostring(uni), "->", tostring(u2))
    end
  end
end

-- §21: the INAROGUE team persists in the INAROGUE save between runs (the VS dock). Outside a run every bank player
-- that has no character yet is created at Lv 5 (the club roster the retail «Banco» lists); characters of the team and
-- of the roster are KEPT; anything that is not an INAROGUE bank player (and not the avatar) is deleted. An empty team
-- gets the automatic first eleven. Then the generic look where missing.
function DK.Prepare()
  if not SL.rogue then
    return false
  end
  if Int(Call(RL_PARTY_COUNT, 0)) < 0 then
    Log("prepare refused: CMND_EVT_RL_PARTY_COUNT unavailable")
    Message(DK.T_NO_PARTY)
    return false
  end
  local map, list = DK_BankMap()
  local have, deleted = {}, 0
  for _, h in ipairs(DK_Handles()) do
    local param = Call(DK.CHARA, h, 4)
    if map[param] ~= nil and have[param] == nil then
      have[param] = h
    elseif Call(DK.CHECK_ATTR, h, DK.AVATAR) ~= true then
      Call(DK.DELETE, h)
      deleted = deleted + 1
    end
  end
  local limit = DK_RosterLimit()
  local made = {}
  for i, e in ipairs(list) do
    if i > limit then
      break
    end
    e.hdl = have[e.param]
    if e.hdl == nil then
      e.hdl = DK_Create(e.param)
      if i % 10 == 0 then
        coroutine.yield()
      end
    end
    if e.hdl ~= 0 then
      table.insert(made, e)
    end
  end
  local vs = Int(Call(DK.GET_VS))
  local t = DK_ReadTeam(vs, 0)
  Log("prepare: roster", #made, "of", #list, "bank players, team", t.n, "members, deleted", deleted, "vs set", vs)
  if #made == 0 then
    Message(DK.T_NO_PLAYERS)
    return false
  end
  if t.n == 0 then
    DK_AutoFill(made, vs, Int(Call(RL_STARTER)))
  else
    DK_Link5(vs)                           -- §26: a team of an earlier build (5v5 without goalkeeper, 5v5-only players)
  end
  DK.Dress(vs)
  return true
end

-- the INAROGUE menu row «Plantilla de equipo» (§21): outside a run, the persistent team; during a run, the run's
function DK.Edit()
  if Call(RL_RUN_INFO) == true then
    if DK.Materialise() then
      DK.Open(DK.R_RUN)
    end
    return
  end
  if DK.Prepare() then
    DK.Open(DK.R_EDIT)
  end
end

-- Lv 5 again (every run starts at Lv 5): each team member is replaced by a new character of the same player with the
-- retail place from the bank onto his 11v11 position. The engine replaces him in BOTH teams at his own entries (retail
-- link, §26), so the 11v11 position and the 5v5 position are both kept. Only then is the old character (levels of an
-- earlier run, now in no team) deleted. If the engine did not take the new one, the old one stays (no player lost).
local function DK_Rebirth(vs, t)
  local done, kept = 0, 0
  for pos = 0, 19 do
    local s = t.slots[pos]
    if s ~= nil then
      local old = s.hdl
      local param = Call(DK.CHARA, old, 4)
      local h = type(param) == "number" and DK_Create(param) or 0
      if h ~= 0 and DK_Place(h, vs, pos, 0) and DK_HdlAt(vs, 0, pos) == h then
        Call(RL_ROLE_CARRY, old, h)        -- the role the user chose in the squad survives the Lv 5 rebirth
        local T = DK_Teams(vs)
        if T[0].where[old] == nil and T[1].where[old] == nil then
          Call(DK.DELETE, old)
        else
          Log("rebirth pos", pos, "old hdl", old, "still in a team after the replace: not deleted")
        end
        s.hdl = h
        done = done + 1
      else
        if h ~= 0 then
          Call(DK.DELETE, h)                 -- the new character is in no team: nothing else refers to it
        end
        kept = kept + 1
        Log("rebirth pos", pos, "param", tostring(param), "not replaced: the old character stays")
      end
    end
    if pos % 4 == 3 then
      coroutine.yield()
    end
  end
  Log("rebirth: team at Lv 5 again,", done, "replaced,", kept, "kept")
end

-- the run starts with team t (read from the VS dock, checked): the loader squad + seed, Lv 5 characters, the run's
-- positions, the roster players not in the team leave the save, the 5v5 five completed, the generic look. true = ok
function DK.StartRun(t, vs)
  Call(DK.TEAM_RESET)
  for pos = 0, 19 do
    local s = t.slots[pos]
    if s ~= nil then
      local c = Int(Call(DK.TEAM_SET, pos, s.uid))
      if c ~= 0 then
        Log("TEAM_SET pos", pos, "uid", s.uid, "code", c)
      end
    end
  end
  local code, seed = Call(DK.TEAM_COMMIT, 0)
  code = Int(code)
  Log("team commit code", code, "seed", tostring(seed))
  if code ~= 0 then
    Message(string.format(DK.T_ERROR, code))
    return false
  end
  DK_Rebirth(vs, t)
  local keep = {}
  for pos = 0, 19 do
    local s = t.slots[pos]
    local c = Int(Call(DK.SET_SLOT, pos, s and s.uid or 0, s and s.hdl or 0))
    if c ~= 0 then
      Log("RUN_SET_SLOT pos", pos, "code", c)
    end
    if s ~= nil then
      keep[s.hdl] = true
    end
  end
  local left = DK_Purge(keep)
  DK_Link5(vs)
  DK.Dress(vs)
  Log(string.format(DK.T_READY, t.n, left))   -- §28: no window; the map opens next
  return true
end

-- Empezar with no run (§21): the persistent team is used as it is when it is valid (11 starters, only INAROGUE
-- players, within the points); otherwise the reason and the dock. true = the run started (the map opens next)
function DK.QuickStart()
  if not DK.Prepare() then
    return false
  end
  local vs = Int(Call(DK.GET_VS))
  local t = DK_ReadTeam(vs, 0)
  t.budget = Int(Call(RL_STARTER))
  local problem = DK_Problem(t, true)
  Log("quick start: starters", t.st, "points", t.spent, "/", t.budget, "problem", tostring(problem))
  if problem ~= nil then
    Message(T(DK.TT.FIX, problem))
    DK.Open(DK.R_START)
    return false
  end
  -- §28 (Nacho, 30/09: «Nueva partida» starts at once): no «¿Empezar con este equipo?» window; the team is edited
  -- beforehand in «Plantilla de equipo». DK.TT.ASK_OPEN stays for the text builder (rogue_play_text_build.py).
  local _ = DK.TT.ASK_OPEN
  return DK.StartRun(t, vs)
end

-- back from the dock. -> "map", "match", "closed" (the dock opens again) or nil (stay in the INAROGUE menu)
function DK.Finish()
  local p = DK.Pending()
  DK_Byte(0)
  if p >= 1 and p <= 5 then
    Log("dock request", p, "but the dock never opened")
    Message(DK.T_NOT_OPENED)
    return nil
  end
  local why = p - 10
  if why < 1 or why > 5 then
    return nil
  end
  local vs = Int(Call(DK.GET_VS))
  DK_Link5(vs)                             -- §26: whatever was edited in the dock, the 5v5 stays the 11v11's roster
  local t = DK_ReadTeam(vs, 0)
  local exists = Call(RL_RUN_INFO) == true
  local start = why == DK.R_START and not exists
  t.budget = Int(Call(RL_STARTER))
  Log("back from the dock: request", why, "run", tostring(exists), "starters", t.st, "bench", t.be, "managers", t.ma,
      "coach", t.co, "points", t.spent, "/", t.budget, "foreign", t.foreign)
  if why == DK.R_EDIT and not exists then
    -- the persistent team was edited (§21): saved with the slot-4 save by the dock's Back; say how it stands
    DK.Dress(vs)
    local problem = DK_Problem(t, true)
    if problem ~= nil then
      if Ask(string.format(DK.T_BACK, T(DK.TT.FIX, problem))) then
        DK.Open(why)
        return "closed"
      end
      return nil
    end
    Message(T(DK.TT.SAVED, t.st, t.be, t.spent, t.budget))
    return nil
  end
  local problem = DK_Problem(t, start, start)
  if problem ~= nil then
    if Ask(string.format(DK.T_BACK, problem)) then
      DK.Open(why)
      return "closed"
    end
    if start then
      Message(DK.T_CANCEL)
    end
    return nil
  end
  if start then
    if not Ask(string.format(DK.T_ASK_START, t.st, t.be, t.ma, t.co == 1 and "con" or "sin", t.spent, t.budget)) then
      if Ask(string.format(DK.T_BACK, "")) then
        DK.Open(why)
        return "closed"
      end
      Message(DK.T_CANCEL)
      return nil
    end
    if not DK.StartRun(t, vs) then
      return nil
    end
    return "map"
  end
  -- the run gets every dock position (rewards and the Fichaje bench slot follow the dock)
  local keep = {}
  for pos = 0, 19 do
    local s = t.slots[pos]
    local c = Int(Call(DK.SET_SLOT, pos, s and s.uid or 0, s and s.hdl or 0))
    if c ~= 0 then
      Log("RUN_SET_SLOT pos", pos, "code", c)
    end
    if s ~= nil then
      keep[s.hdl] = true
    end
  end
  -- §28 (Nacho, 30/09): back to where the dock was opened from. The request byte is the origin: the «Plantilla de
  -- equipo» row of the INAROGUE menu (request 2 during a run) returns to that menu; the pre-match dock of the map /
  -- VS preview (3, 5: being here means «No») returns to the map, where the node is still pending
  return DK.ORIGIN_MAP[why] and "map" or nil
end

-- the pre-match dock reserved the match (byte 606 = 23): true once, then the byte is cleared
function DK.TakePlayed()
  if SL.rogue and DK_Byte() == DK.R_PLAYED then
    DK_Byte(0)
    return true
  end
  return false
end

-- The run's players as real characters of slot 4. Idempotent: slots that already have a handle are skipped, and
-- the purge only runs when the run has no character yet (a run started before §16). Outside slot 4: nothing, true.
function DK.Materialise()
  if not SL.rogue then
    return true
  end
  local first_ok, _, _, first_hdl = Call(RL_SQUAD, 0)
  if first_ok ~= true then
    Log("materialise: the run has no squad (slot 0 empty): nothing to create")
    return true
  end
  if Int(Call(RL_PARTY_COUNT, 0)) < 0 then
    Log("materialise refused: CMND_EVT_RL_PARTY_COUNT unavailable")
    Message(DK.T_NO_PARTY)
    return false
  end
  local deleted = 0
  if Int(first_hdl) == 0 then
    deleted = DK_Purge()
  end
  local vs = Int(Call(DK.GET_VS))
  local made = 0
  for slot = 0, 19 do
    local ok, uid, param, hdl = Call(RL_SQUAD, slot)
    if ok == true and Int(hdl) == 0 and type(param) == "number" and param ~= 0 then
      local h = DK_Create(param)
      if h ~= 0 then
        Call(RL_SET_HDL, slot, h)
        local placed = DK_Place(h, vs, slot, 0)
        Log("create slot", slot, "uid", Int(uid), "param", param, "hdl", h, "placed", tostring(placed))
        made = made + 1
      end
    end
    if slot % 5 == 4 then
      coroutine.yield()
    end
  end
  Log("materialise done: created", made, "purged", deleted, "vs set", vs)
  DK_Link5(vs)
  if made == 0 and Int(first_hdl) == 0 then
    Message(DK.T_NO_PLAYERS)
    return false
  end
  if made > 0 then
    Message(string.format(DK.T_DONE, made, vs, deleted))
  end
  return true
end

-- ---- story completed + Chronicle unlocked in the INAROGUE save (docs/game/save/story-chronicle-flags.md, inarogue.md §25) --
-- Slot 4 always behaves like a save with the story COMPLETED and the whole Chronicle UNLOCKED, whatever slot 1 holds,
-- so story / Chronicle-gated characters, items and data conditions never lock or break in the roguelite. Only
-- variables are written (retail setters; no players, items, trophies, scenes, help pages or «nuevo» notices): bit /
-- byte flags, story matches won, the Chronicle clear / lock bytes, and the story phase 9/80 (loader, slot 4 only).
-- Runs on every INAROGUE open in slot 4 and only writes what is not set yet (reads first: idempotent, cheap once set).
-- Replaces the old read-only copy of slot 1's progress (§13.11): slot 1 is no longer read at all.
local PG = {
  PHASE = 3907974425,     -- (chapter, sub): raise slot 4's current / next / checked-free phase
  SET_BIT = 3258400760, GET_BIT = 941426960, SET_BYTE = 187123515, GET_BYTE = 2769028935,
  SET_GAME_CLEAR = 919659808,           -- CMND_SET_SOCCER_GAME_CLEAR_BIT_FLAG (game, difficulty, true)
  GET_GAME_CLEAR = 989257499,           -- CMND_GET_SOCCER_GAME_CLEAR_FLAG (game, difficulty)
  SET_CLEAR = 1891570685, GET_CLEAR = 4034518619,   -- CMND_{SET,GET}_CHRONICLE_CLEAR_STATUS (sfi[, bool], diff)
  SET_LOCK = 1778321182, GET_LOCK = 3394595467,     -- CMND_{SET,GET}_CHRONICLE_LOCK_STATUS (sfi[, bool], diff)
  DIFFS = {1, 2, 3, 4, 10, 11},         -- bits 1..6 of a Chronicle status byte
}

-- ===== generated by research/scripts/rogue_unlock_build.py: RU_DATA BEGIN (do not edit) =====
-- 706 story flags (+1 off), 29 story byte flags, 10 story matches, phase 9/80; 53 Chronicle flags, 2 Chronicle byte flags, 255 Chronicle status indices (895 clear bits, every lock bit off)
local RU_DATA = {
  VERSION = 1,
  PHASE = {9, 80},
  -- CMND_SET_GLOBAL_BIT_FLAG(crc, true): the story-complete set of story_start (the finished save ∩ story
  -- state) + b0:4, 5, 9; b0:1 (story clear) is the LAST entry
  STORY_BITS = {
    3281496639, 461276674, 692642944, 1413419205, 40220483, 3401334091, 1164984769, 3945312182, 544504851, 2799701693,
    1841093912, 1891233184, 3152363013, 1030835371, 4130184974, 125513179, 3425173118, 3670062379, 295462542, 2533889056,
    1549059973, 526879653, 3560658944, 3104866321, 937728468, 2928028962, 2852868496, 2882091943, 2823679945, 2735843572,
    2731786947, 364813865, 343733278, 372918855, 2135658377, 1024924036, 1800257026, 402137200, 313997045, 432012851,
    2159456137, 4155612959, 1775569596, 3512693059, 1213604089, 1062277231, 2704639436, 3593647450, 1329325280, 943510646,
    2827209191, 393316176, 3898066845, 1758030444, 1716567752, 604776645, 37518284, 688990223, 2940487445, 3004195025,
    187359878, 3715301787, 1642926661, 734632860, 2978503536, 2928227520, 88969118, 170267, 29422380, 59133301,
    38020930, 152592511, 148507208, 3216463522, 3195354261, 3157492428, 3186747643, 3099524734, 3111949385, 3141151248,
    3136831527, 2980316954, 2959502637, 576744987, 597820460, 568638069, 539414594, 627689159, 615230704, 2504218438,
    206178044, 2068657770, 966419766, 1156419955, 3844711369, 2452525919, 284264620, 76539305, 2636679654, 2674800575,
    2662096264, 2615364365, 2585862458, 2556927843, 2577790292, 2465837673, 2470172766, 609649844, 668094682, 638597869,
    593439848, 580732511, 551286790, 555323953, 709219596, 730316603, 920857434, 924926317, 896007988, 883266819,
    837452678, 807987633, 846092264, 866926047, 955284194, 959582421, 2388610111, 2409440776, 2350510694, 2304173283,
    2291437268, 2329030797, 2333104826, 2152471943, 2173597616, 327709830, 306847409, 269263080, 298765023, 344054874,
    356759149, 386205748, 3716211057, 1149874379, 864976989, 2917799422, 3672974696, 1139045586, 2536569296, 996115026,
    1177056791, 957955083, 1148110926, 953898556, 1033126073, 1012279950, 1727713534, 4294148420, 2297737682, 378545265,
    1041274071, 1070792416, 3571059950, 1305697620, 987000258, 881768925, 894227434, 3921290590, 1890809060, 129254514,
    2183237376, 2212750647, 2920963982, 923995700, 1075068578, 3731925761, 2175097710, 2154246489, 2234001372, 2229947883,
    2259481522, 2272172421, 3042507527, 3808582785, 3509861891, 1337398157, 2381362319, 2425626862, 2438351577, 2467361920,
    2463276727, 2543683634, 3941235831, 2522866181, 2484690012, 2514171499, 2659676502, 673728395, 703212988, 732730341,
    711915986, 4277714140, 4240310917, 4252788914, 4164124215, 4193326080, 4223117913, 4092124845, 4202020974, 4033612483,
    4046030675, 4041993572, 1200009614, 1178917817, 1141007840, 1170214871, 1083119954, 1095594853, 1124846908, 1120511755,
    1234559030, 1213696513, 1429413472, 1425110103, 1454885390, 1467326521, 1379579580, 1310437197, 1339671930, 1149600327,
    1162340464, 1478720529, 1516618312, 1596642509, 1592311546, 1445997993, 1408818315, 1371431634, 1350306021, 1528844248,
    1524770287, 3985602821, 3964474162, 3993742699, 4022978396, 3934704089, 3947150318, 3909223863, 3904925568, 3818662077,
    3797828234, 1884832188, 1905929099, 1943836114, 1914634213, 2001856864, 1989378903, 1964463929, 2490757618, 1485813608,
    637027117, 1523124529, 1527472902, 1581544835, 1602625460, 1572905453, 1465814247, 1453123280, 3790715450, 3761491981,
    3799346772, 3820422243, 3875017446, 3879368913, 3850159752, 3837701311, 4024626050, 2459246535, 3995107765, 4081325524,
    4068900835, 2414971814, 4039164346, 4043484045, 4119844671, 3599289917, 1768402421, 1797329836, 1793292699, 1873571614,
    1814608752, 1844105543, 1723242106, 465658431, 1735720013, 3491340455, 3520842384, 2896969429, 3550311625, 2445402820,
    2934603916, 3971356289, 3529449214, 3608152187, 3566525461, 2194570131, 3579229730, 3725259039, 3754466088, 3266056009,
    3278792062, 3240680231, 3236606224, 3315967893, 3295137186, 3324081147, 3435093745, 3447534790, 2047895596, 2077360667,
    2039790658, 2018956917, 2098839792, 2094770887, 2124223646, 2136964777, 1946368404, 912240537, 1223611172, 3324460013,
    3058552674, 1375068773, 275774608, 158649809, 1260936156, 1975604131, 3888599189, 3829630203, 3850497740, 3771660361,
    3775697534, 1417737464, 47862654, 4132548384, 4014644833, 2685077670, 2453498404, 213796778, 65724635, 2739930227,
    2252037039, 2999575076, 111539806, 304038678, 1869133651, 2316027329, 2703660546, 3091048259, 4152111492, 3999727813,
    3696321095, 2995299991, 3489616594, 2099156396, 2491232409, 2054377909, 2647358642, 3939257380, 612806105, 769919027,
    1729647075, 1247196456, 2862414221, 2511838149, 221230585, 1291319194, 2783605550, 3537287646, 1956754026, 2196357763,
    614385975, 72767309, 244538964, 3258539722, 1287018793, 1270423194, 3534769952, 2780266422, 993182579, 454118226,
    607791386, 1718009623, 666828148, 2799844018, 2580109562, 3684028151, 2914942351, 2536034512, 1000185820, 3450674603,
    2494301374, 2377594367, 2356502472, 3473974849, 2993115652, 3444971544, 3432280623, 3254830128, 3225844329, 3246657630,
    3305729260, 3343897269, 3331176578, 3453091775, 3386598570, 3357085341, 3395268804, 3416120051, 4188780657, 2951815159,
    2647096693, 54808827, 442458554, 3233914318, 3238262777, 1986964243, 2007810340, 1978302333, 1519308253, 29977233,
    1948783946, 1902576591, 1889888760, 1927534497, 3423835528, 2071906658, 2059182933, 1931591062, 2021522091, 2042597532,
    1692075261, 1696165578, 1734332563, 1721612964, 2139524069, 1420548134, 3639222058, 3643307293, 2816169270, 3850879803,
    2364933877, 2370580556, 2877055813, 702295139, 1616279631, 1795833714, 3756242934, 3681471300, 562138590, 330821468,
    1173178586, 962123432, 991848689, 877180121, 1066603587, 1045528180, 1008189485, 1037412890, 915008807, 927696656,
    2150030330, 2179248589, 3902108675, 2865357326, 2514649158, 3619558987, 3153631630, 3331288523, 2509954248, 3199700747,
    3284171598, 2488841983, 2518550694, 2547802769, 2625643948, 2638368667, 3743340950, 3761617886, 2724802003, 707728241,
    736983366, 699123487, 678014248, 3057271295, 116450584, 4105768777, 3995527782, 3965735999, 1423717210, 2683942050,
    3121311182, 2185182305, 2665276437, 2670714140, 2640929605, 2628454770, 2581864439, 2552657344, 2590034841, 2611126702,
    2432624275, 2436664484, 642895950, 663992953, 634717216, 605515287, 559446162, 546968229, 584887548, 589219531,
    675447286, 1429566899, 696314817, 1425481604, 887390112, 891688343, 929082318, 352476366, 509484019, 2876635456,
    838706077, 989277720, 2354583749, 3686847860, 2324945454, 2185972093, 1613217476, 1376902214, 331980325, 1092502801,
    4180602750, 3457208824, 821107965, 467423038, 1807137713, 629551700, 3864320415, 1351875702, 3768325602, 2543891928,
    1988916858, 479861632, 4056672246, 2118854759, 2039825496, 756826084, 4194153375, 2757191872, 3162307553, 871201989,
    3932564867, 3548544748, 2968617748, 168516136, 35846019, 456771266, 6572506, 427784347, 1250635606, 2844755454,
    1787810869, 1854009786, 3221570947, 3518457662, 1267488074, 3760197688, 3652005117, 685951914, 1870055154, 3340804244,
    3184279860, 1067048937, 3470145726, 2864141687, 1459354167, 4149937275, 2014171825, 3495670999, 2218884593, 2470078898,
    367703089, 376332383, 1380634337, 1342992568, 1865082705, 1835817224, 3733909295, 3765048049, 3824076447, 2815060001,
    2777470584, 2701241034, 2697183485, 2565668808, 2569967103, 2644765005, 2682607380, 2244300942, 598891322, 3044763852,
    3946564455, 1915919069, 3791569534, 2029491140, 822326032, 4056426724, 1757509982, 533088712, 1784244978, 4082121544,
    2220297182, 2478703836, 2108712432, 372108901, 2619854960, 2500795454, 679243151, 2977250357, 3329363107, 3163872808,
    631082898, 1385873156, 2009599373, 4005649463, 2579917985, 1832644110, 4096966580, 2201325346, 440363007, 2598068885,
    4273606492, 1671615612, 1613103122, 1701385879, 3514959980, 3552884277, 2180084086, 2227070963, 1146507256, 1092180349,
    1024641270, 1062500015, 413992399, 455725473, 1983545611, 1954299730, 1975407973, 1894859744, 1899178455, 1937086350,
    832240603, 840839093, 3349055861, 3268517872, 3810573866, 2049568656, 221175558, 604155564, 663124674, 587925104,
    3316473756, 1873201161, 337983202, 396485260, 317649929, 1556457782, 1585649519, 1598127448, 1510894557, 1251289704,
    1221825585, 1225915910, 1281288323, 2785405682, 2755876011, 2776710812, 634203263, 642381841, 583304355, 267428690,
    2471119525, 2838710041, 3529860669, 3414054780, 810800577, 2131903238, 1711895111, 1294213508, 3550940170, 423114843,
    2296090, 722361049, 1716559895, 3555009642, 1792412, 750283301,
  },
  STORY_BITS_OFF = {1853892128},   -- b0:1806
  -- {byte flag crc, value}: raised to at least this value
  STORY_BYTES = {
    {1256392032, 1}, {1161634938, 4}, {2380114698, 8}, {3384904975, 5}, {2164407096, 6}, {980945591, 4},
    {2287523495, 3}, {3040411415, 3}, {4070081991, 4}, {2047679247, 10}, {3271853078, 5}, {2203201021, 7},
    {3190948941, 5}, {1269998221, 3}, {1368004148, 2}, {1517436753, 3}, {2622462896, 3}, {2807736136, 3},
    {1138741227, 3}, {4116875503, 4}, {4073967644, 3}, {110949391, 3}, {2783657215, 3}, {1615594097, 3},
    {3325757893, 3}, {2995792060, 3}, {3510640006, 3}, {2384320317, 3}, {2432951590, 3},
  },
  -- story matches won (CMND_SET_SOCCER_GAME_CLEAR_BIT_FLAG(game, 1, true))
  GAMES = {3525303964, 3612395545, 3599933998, 1306349005, 3570670711, 3575019072, 3729404285, 830880358, 1759840160, 2950868933},
  -- Chronicle: trigger steps b0:3000-3041, gate keys b0:820/821, future route b0:822, tutorial b0:840,
  -- route trophies b0:3301-3306, b0:3300
  CHRON_BITS = {
    234866870, 2499189004, 1961455689, 1169930310, 762938716, 792673029, 788353330, 733104055, 711994752, 674665433,
    703920622, 581484243, 2512773689, 1747762061, 1460132293, 358305736, 1430349724, 47819309, 1301822698, 1417874859,
    2142133864, 1723166505, 821020847, 874971584, 2467176658, 2462862053, 2425025724, 2259822560, 2272284119, 2234971022,
    2230622649, 2176552764, 2155472139, 2214408549, 2292282968, 2817050217, 2304973935, 1041121413, 1032492267, 1011416796,
    956819545, 952468078, 836729610, 2748938300, 2719683083, 2690493522, 734570447, 1262262111, 211611023, 838648895,
    2212239407, 3200004511, 4179381071,
  },
  CHRON_BYTES = {{3152001072, 4}, {2999705410, 5}},   -- b1:24, b1:26
  -- {statusFlagIndex, clear mask}: bits 1..6 = difficulties 1, 2, 3, 4, 10, 11; every lock bit is cleared
  CHRON = {
    0, 2, 1, 0, 2, 126, 3, 126, 4, 126, 5, 126, 6, 126, 7, 126, 8, 126, 9, 126,
    10, 126, 11, 0, 12, 126, 13, 126, 14, 126, 15, 126, 16, 0, 17, 0, 18, 126, 19, 126,
    20, 0, 21, 126, 22, 0, 23, 126, 24, 0, 25, 126, 26, 126, 27, 0, 28, 126, 29, 126,
    30, 0, 31, 126, 32, 126, 33, 126, 34, 126, 35, 0, 36, 126, 37, 126, 38, 126, 39, 126,
    40, 126, 41, 126, 42, 126, 43, 126, 44, 0, 45, 126, 46, 126, 47, 126, 48, 0, 49, 126,
    50, 126, 51, 126, 52, 0, 53, 0, 54, 126, 55, 0, 56, 126, 57, 0, 58, 0, 59, 126,
    60, 126, 61, 0, 62, 126, 63, 0, 64, 126, 65, 126, 66, 126, 67, 126, 68, 126, 69, 126,
    70, 126, 71, 126, 72, 0, 73, 126, 74, 126, 75, 0, 76, 126, 77, 0, 78, 126, 79, 0,
    80, 0, 81, 126, 82, 0, 83, 126, 84, 0, 85, 126, 86, 0, 87, 126, 88, 0, 89, 126,
    90, 0, 91, 126, 92, 0, 93, 126, 94, 126, 95, 126, 96, 126, 97, 126, 98, 126, 99, 126,
    100, 126, 101, 126, 102, 0, 103, 0, 104, 126, 105, 0, 106, 126, 107, 126, 108, 126, 109, 0,
    110, 126, 111, 126, 112, 126, 113, 0, 114, 126, 115, 0, 116, 126, 117, 126, 118, 0, 119, 126,
    120, 0, 121, 126, 122, 0, 123, 126, 124, 0, 125, 126, 126, 0, 127, 0, 128, 126, 129, 126,
    130, 126, 131, 126, 132, 126, 133, 0, 134, 0, 135, 0, 136, 0, 137, 100, 138, 0, 139, 0,
    140, 126, 141, 126, 142, 126, 143, 126, 144, 126, 145, 0, 146, 0, 147, 126, 148, 126, 149, 126,
    150, 0, 151, 126, 152, 126, 153, 0, 154, 126, 155, 126, 156, 0, 157, 126, 158, 126, 159, 0,
    160, 126, 161, 0, 162, 126, 163, 0, 164, 0, 165, 126, 166, 126, 167, 0, 168, 0, 169, 126,
    170, 126, 171, 126, 172, 0, 173, 126, 174, 126, 175, 0, 176, 126, 177, 126, 178, 126, 179, 0,
    180, 126, 181, 0, 182, 126, 183, 126, 184, 0, 185, 126, 186, 0, 187, 0, 188, 126, 189, 0,
    190, 126, 191, 0, 192, 0, 193, 126, 194, 0, 195, 126, 196, 100, 197, 0, 198, 126, 199, 126,
    200, 126, 201, 126, 202, 126, 203, 126, 204, 126, 205, 126, 206, 0, 207, 126, 208, 126, 209, 0,
    210, 126, 211, 0, 212, 126, 213, 0, 214, 126, 215, 0, 216, 126, 217, 0, 218, 126, 219, 0,
    220, 0, 221, 100, 222, 0, 239, 0, 240, 0, 241, 0, 242, 0, 243, 0, 244, 0, 245, 100,
    246, 0, 247, 0, 248, 100, 249, 0, 250, 0, 251, 100, 252, 100, 253, 0, 254, 100, 255, 0,
    256, 0, 257, 0, 258, 0, 259, 126, 260, 0, 261, 0, 262, 126, 263, 126, 264, 0, 265, 0,
    266, 0, 267, 126, 268, 126, 269, 0, 270, 126,
  },
}
-- ===== generated by research/scripts/rogue_unlock_build.py: RU_DATA END =====

-- §24: no retail tutorial / first-time help page in the INAROGUE save. Every menu help of the game is a row of
-- help_list_config (HELP_LIST_INFO, 269 ids = crc32("hlp_NNNN")); the retail menus open it the first time only when
-- 745587751(id) («seen?») is false, then mark it with 1732256399(id) (kizuna_town_avatar_menu, help_menu). On every
-- INAROGUE open in slot 4 every id not seen yet is marked seen, so no «Comandos de hipertécnicas 1/2» & co. ever
-- opens there (new saves and existing ones). -> how many were marked
local HELP_IDS = {
  714921031, 28411780, 413841093, 1475026946, 1324355907, 1708999296, 2093380545, 4217270030, 3796196943, 843419441,
  727629424, 7597491, 426302706, 3408429071, 945809755, 2646713926, 2946448642, 2226286273, 2645122944, 3538471239,
  3421763590, 3772689349, 4190476932, 2120058443, 1732687626, 3074844276, 2925352757, 2238711030, 2624271799, 3542786928,
  3392246321, 3776758258, 4198584042, 2840920041, 2189012010, 4279130223, 2606931307, 3559066540, 2111394341, 1615798230,
  3814358955, 3173683948, 3949999466, 4067099691, 2958020264, 4161269939, 2141187196, 1719983421, 3487105153, 3036731437,
  2887510380, 2023113888, 2268510895, 2653785070, 3513523497, 3363253352, 1921906004, 1690461028, 3032658458, 2916713307,
  2264191128, 2683298265, 3443014381, 3860162862, 3501094686, 3384100447, 3801617820, 4219675869, 2082158610, 3588317595,
  2978849951, 2828441054, 2210121245, 2594240348, 3438956762, 2880816517, 2195597343, 2859970482, 3845536117, 4230809652,
  3607124983, 3457903286, 1233352313, 1352156984, 2157483590, 3841217346, 4260323843, 2554449200, 1990659539, 3889627929,
  4274795096, 2035560087, 2997810372, 388192871, 1007552932, 315345111, 3894681693, 1569349136, 1874607250, 418537960,
  622147813, 870265387, 717489002, 1364864271, 1783934498, 1934597987, 3603050944, 2613385566, 2851306460, 3870485787,
  1482869920, 1098513889, 32067753, 3336692014, 557826146, 1150381905, 168989601, 319398624, 1703253421, 3757756527,
  268042513, 2401038446, 3645265896, 383856720, 1642463430, 1036805011, 1254839045, 3227346601, 1086035926, 3340995353,
  3728259672, 1212226638, 2968013469, 1255629646, 3116955198, 138655174, 230473544, 346525193, 1128219576, 647097483,
  358999102, 1775270476, 271250107, 1892371213, 3521741271, 1541806286, 1512338169, 1471412015, 1181766973, 1123887503,
  1044953085, 1229948779, 3311744320, 3699246081, 209638783, 1746014331, 3223987141, 3643871876, 1896423738, 3299303287,
  3492539360, 520687782, 101851623, 759132708, 874791781, 2070271394, 1652483299, 3669346026, 422579167, 3720113718,
  154256378, 572297273, 1950758847, 1600873596, 3253225970, 3639834803, 150186445, 300456076, 986041167, 601815566,
  1822387401, 179640212, 330180309, 563627095, 1859768976, 2009261009, 1559212050, 1173651795, 3261898140, 3682053341,
  192380323, 309087458, 960569121, 542781024, 1864087719, 1979746790, 1563286053, 1144449892, 721840477, 2103234267,
  1450286360, 1332391001, 3371348118, 3375422113, 1682440090, 2090771692, 4047442204, 941945123, 1319683694, 1202863882,
  2331271902, 2715365661, 3099721820, 4152596123, 4002981850, 2577373004, 9881334, 3317036057, 3702441304, 2880042446,
  849388660, 1168610530, 3686990145, 2898538967, 2335574249, 2686147370, 3103812203, 4131519660, 4015705581, 1530321303,
  1110304982, 553495125, 198244758, 2452437416, 1474734728, 2441257162, 2006871330, 843580859, 426071672, 8283961,
  1329590782, 1445249215, 2097779580, 1678942781, 3817520882, 4203843507, 714170061, 864710540, 29101326, 1325243337,
  230884487, 653154116, 1073047045, 3094182602, 2708884363, 1903598325, 1752017844, 1781208557, 1773126019, 1115853376,
  1536795393, 349713862, 1128331383, 1515964726, 354050033, 201420464, 1043794994, 3115258109, 2696159676,
}
function IRM_MarkHelpsSeen()
  local n = 0
  for i, id in ipairs(HELP_IDS) do
    if Call(745587751, id) == false then
      Call(1732256399, id)
      n = n + 1
    end
    if i % 60 == 0 then
      coroutine.yield()
    end
  end
  if n > 0 then
    Log("retail help pages marked seen", n, "of", #HELP_IDS)
  end
  return n
end

function IRM_UnlockProgress()
  local D = RU_DATA
  local n = {story = 0, chron = 0, status = 0}
  local function bits(list, key)
    for i, h in ipairs(list) do
      if Call(PG.GET_BIT, h) ~= true then
        Call(PG.SET_BIT, h, true)
        n[key] = n[key] + 1
      end
      if i % 200 == 0 then
        coroutine.yield()
      end
    end
  end
  local function bytes(list, key)
    for _, b in ipairs(list) do
      if Int(Call(PG.GET_BYTE, b[1])) < b[2] then
        Call(PG.SET_BYTE, b[1], b[2])
        n[key] = n[key] + 1
      end
    end
  end
  -- the story: flags (b0:1 story clear last), the ending's own flag off, byte flags, story matches won
  local last = D.STORY_BITS[#D.STORY_BITS]
  local story = {}
  for i = 1, #D.STORY_BITS - 1 do
    story[i] = D.STORY_BITS[i]
  end
  bits(story, "story")
  for _, h in ipairs(D.STORY_BITS_OFF) do
    if Call(PG.GET_BIT, h) == true then
      Call(PG.SET_BIT, h, false)
      n.story = n.story + 1
    end
  end
  bytes(D.STORY_BYTES, "story")
  for _, g in ipairs(D.GAMES) do
    if Call(PG.GET_GAME_CLEAR, g, 1) ~= true then
      Call(PG.SET_GAME_CLEAR, g, 1, true)
      n.story = n.story + 1
    end
  end
  -- the Chronicle: flags, byte flags, every piece cleared at all its difficulties and nothing locked
  bits(D.CHRON_BITS, "chron")
  bytes(D.CHRON_BYTES, "chron")
  coroutine.yield()
  for k = 1, #D.CHRON, 2 do
    local sfi, m = D.CHRON[k], D.CHRON[k + 1]
    for bit = 1, 6 do
      local diff = PG.DIFFS[bit]
      if math.floor(m / 2 ^ bit) % 2 == 1 and Call(PG.GET_CLEAR, sfi, diff) ~= true then
        Call(PG.SET_CLEAR, sfi, true, diff)
        n.status = n.status + 1
      end
      if sfi > 0 and Call(PG.GET_LOCK, sfi, diff) == true then
        Call(PG.SET_LOCK, sfi, false, diff)
        n.status = n.status + 1
      end
    end
    if k % 100 == 99 then
      coroutine.yield()
    end
  end
  -- the story phase 9/80 (loader, slot 4 only, never lowered), then the story-clear flag
  local old, new = Call(PG.PHASE, D.PHASE[1], D.PHASE[2])
  if Call(PG.GET_BIT, last) ~= true then
    Call(PG.SET_BIT, last, true)
    n.story = n.story + 1
  end
  local raised = Int(new) > Int(old)
  local total = n.story + n.chron + n.status + (raised and 1 or 0)
  Log("story complete / Chronicle unlocked (data v" .. tostring(D.VERSION) .. "): written story", n.story, "chronicle flags",
      n.chron, "chronicle status bits", n.status, "phase", Int(old), "->", Int(new), total == 0 and "(all already set)" or "")
  return total
end

-- A new run (§28: no window here; the caller already asked when a run in progress is abandoned): the first-run gift,
-- then the persistent team of «Plantilla de equipo» as it is (DK.QuickStart: the dock only when it cannot play), then
-- the map.
local function NewRun()
  local budget, _, gift, _, size, pick_on = Call(RL_STARTER)
  if pick_on == true then
    -- PokeRogue run start (docs/game/inarogue.md §12): first-run gift, then the starter picker (the bank)
    if gift == true then
      local n = Int(Call(RL_GIFT))
      Log("first-run gift", n)
      if n > 0 then
        Message(string.format(TXT.GIFT, n))
      end
    end
    -- §21: the INAROGUE team persists in the INAROGUE save («Plantilla de equipo» row): the run uses it as it is when
    -- it is valid; otherwise the reason and the retail team dock (§16), where the run starts when the title reopens
    -- INAROGUE with a valid team (DK.Finish)
    if not DK.QuickStart() then
      return
    end
  else
    local code, seed = Call(RL_RUN_START, 0)
    Log("new run code", Int(code), "seed", tostring(seed))
    if Int(code) ~= 0 then
      Message(string.format(TXT.RUN_ERROR, Int(code)))
      return
    end
  end
  -- slot 4: the run's players as real characters of the INAROGUE save (§14 stages 2-3; no-op when they exist)
  if not DK.Materialise() then
    return
  end
  funcLuaCommand(C.SE, SE_DECIDE)
  IRM_OpenMap()
end

-- «Continuar» (§28): the run in progress, straight to its map (no «¿Continuarla?»); with no run the big row reads
-- «Empezar» and starts one at once
local function StartOrContinue()
  if not HasRogueLoader() then
    Message(TXT.NO_LOADER_RUN)
    return
  end
  if Call(RL_RUN_INFO) ~= true then
    Log("start: no run in progress, a new one")
    NewRun()
    return
  end
  if not DK.Materialise() then
    return
  end
  funcLuaCommand(C.SE, SE_DECIDE)
  IRM_OpenMap()
end

-- «Nueva partida» (§28): starts a new run at once; the only window is the one that protects a run in progress
local function NewGame()
  if not HasRogueLoader() then
    Message(TXT.NO_LOADER_RUN)
    return
  end
  local exists, phase = Call(RL_RUN_INFO)
  if exists == true then
    if not Ask(T(RN.ASK, Int(phase))) then
      return
    end
    Log("run abandoned for a new one, code", Int(Call(RL_RUN_ABANDON)))
    run = ReadRun()
    RefreshItems()                -- §30: main label, grid, status
  end
  NewRun()
end

-- the map, and the match it may reserve (result 3): the launch happens here, one level above the map
function IRM_OpenMap()
  while true do
    funcLuaCommand(C.P_CLEAR, KEY_MAP_RESULT)
    OpenChild(MAP_MENU, TXT.NO_MAP, function() return Int(Call(P_GET, KEY_MAP_RESULT)) == 4 end)
    local r = Int(Call(P_GET, KEY_MAP_RESULT))
    funcLuaCommand(C.P_CLEAR, KEY_MAP_RESULT)
    if r == 3 then
      IRM_LaunchMatch()
      return
    elseif r ~= 4 or IRM_VsPreview() ~= "map" then
      return                  -- §28: 4 = a match node: the VS screen, then the match, or ("map") the map again
    end
  end
end

-- §28 the VS preview (Nacho's retail «BATALLA HEROICA» screen): the retail Chronicle VS menus opened as children of
-- INAROGUE, like vs_route_town_menu.OpenVsTeamMenu does (enemy formation first, then the VS team menu). The graft
-- rogue_vs switches them to INAROGUE mode while VS.KEY is set: the run's team (the VS dock; its 5v5 for a pachanga)
-- against the node's rival, an INAROGUE / phase title, «Empezar partido» without the retail second question.
-- «Empezar partido» -> the match is reserved in the run file (stage 3) and the dock launches it (request 5);
-- Back -> "map": IRM_OpenMap shows the map again (the node stays in progress: Aceptar on it opens this screen again).
function IRM_VsPreview()
  local stage, node = Call(RL_RESUME)
  node = Int(node)
  if Int(stage) == 0 then
    Log("vs preview: no node in progress")
    return "map"
  end
  for _, k in ipairs({VS.KEY, VS.KEY_RESULT}) do
    funcLuaCommand(C.P_CLEAR, k)
  end
  funcLuaCommand(C.P_SET, VS.KEY, 0, node + 1, 1)
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
  ShowOwnLayers(false)
  funcLuaCommand(C.OPEN_MENU, VS.ENEMY_MENU)
  funcLuaCommand(C.OPEN_MENU, VS.TEAM_MENU)
  coroutine.yield()
  coroutine.yield()
  local shown = funcLuaMenuCommand(C.EXIST_MENU, VS.TEAM_MENU) == true
  Log("vs preview: node", node, "stage", Int(stage), "open", tostring(shown))
  while funcLuaMenuCommand(C.EXIST_MENU, VS.TEAM_MENU) do
    coroutine.yield()
  end
  if funcLuaMenuCommand(C.EXIST_MENU, VS.ENEMY_MENU) then
    funcLuaCommand(C.CLOSE_MENU, VS.ENEMY_MENU)
  end
  local go = shown and Int(Call(P_GET, VS.KEY_RESULT)) == 1
  for _, k in ipairs({VS.KEY, VS.KEY_RESULT}) do
    funcLuaCommand(C.P_CLEAR, k)
  end
  RestoreOwnLayers()
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
  if not shown then
    -- the VS menus did not open (graft or data missing): the match goes the old way, through the pre-match dock
    Log("vs preview missing: the pre-match dock instead")
    local code = Call(RL_RESERVE)
    if Int(code) == 0 then
      IRM_LaunchMatch()
    else
      Message(string.format(TXT.RUN_ERROR, Int(code)))
    end
    return
  end
  if not go then
    Log("vs preview: back to the map")
    return "map"
  end
  local code, game, diff, stadium, level, rival = Call(RL_RESERVE)
  Log("vs preview: Empezar partido -> reserve code", Int(code), "game", tostring(game), "rival", tostring(rival))
  if Int(code) ~= 0 then
    Message(string.format(TXT.RUN_ERROR, Int(code)))
    return "map"
  end
  funcLuaCommand(C.SE, SE_DECIDE)
  DK.Open(DK.R_PLAY)          -- the dock opens black and starts the match (rogue_dock); see DK.R_PLAY
end

-- CMND_RESERVE_SOCCER for the match the run file holds (stage 3): the retail VS CPU sequence (roguelite-mode.md
-- §1.2). The result flags are zeroed first; the evt_rl_* trigger writes them during the match. This menu closes with
-- result 8 and the title keeps it closed while the engine starts the match (inarogue_title: EVT_IR_AfterMenu).
-- the rival of a random-team node (InaRogue's pool slot rows): its roster, name, crest and kit are written into the slot
-- team right before the match (VR-Framework random team service, docs/framework/random-team.md §4). Nothing to do for
-- any other rival; never at chunk load.
local RL_RIVAL = 4160461699    -- CMND_EVT_RL_RUN_RIVAL (node) -> rule, seed, nodeKey, stage, slot (nil = not a random team)
local RT_BUILD = 806842072    -- CMND_VRFW_RANDOM_TEAM_BUILD (rule, seed, node, stage, slot) -> ok, team, level, members, why
function EVT_IR_BuildRival(node)
  local ok, rule, seed, key, stage, slot = pcall(funcLuaCommand, RL_RIVAL, node)
  if not ok or type(rule) ~= "string" or rule == "" then
    return false
  end
  local ok2, built, team, level, members, why = pcall(funcLuaCommand, RT_BUILD, rule, seed, key, stage, slot)
  Log("random rival", rule, "node", tostring(node), "->", tostring(ok2), tostring(built), tostring(team), tostring(members), tostring(why))
  return ok2 and built == 1
end

function IRM_LaunchMatch(from_dock)
  EVT_IR_BuildRival(-1)
  local stage, node, _, _, _, game, diff, stadium, level, rival = Call(RL_RESUME)
  if Int(stage) ~= 3 or type(game) ~= "number" or game == 0 then
    Log("launch refused: no reserved match (stage", Int(stage), ")")
    Message(TXT.MATCH_FAIL)
    return
  end
  rival = type(rival) == "string" and rival or "?"
  -- slot 4 (§20 M3): the retail "Plantilla de equipo" is the pre-match screen and launches the match itself (its Back
  -- asks «¿Jugar ya?»): the engine only starts a reserved match when the mode's top menu closes, and the dock is the
  -- top menu the title reserved; this menu is only a child of title_menu_2 (the 28/09 log: "match did not start")
  if SL.rogue then
    Log("match", Int(node), "game", game, "rival", rival, "level", Int(level), "-> the pre-match team dock")
    DK.Open(DK.R_MATCH)
    return
  end
  for _, f in ipairs({MT.F_RESULT, MT.F_GF, MT.F_GA, MT.F_PROBE}) do
    Call(MT.SET_BYTE, f, 0)
  end
  Call(MT.SET_BYTE, MT.F_STATE, 2)
  Log("launch match: node", Int(node), "game", game, "diff", Int(diff), "stadium", tostring(stadium), "level", Int(level), "rival", rival)
  if not SL.rogue then
    Message(string.format(TXT.MATCH_GO, rival, Int(level)))
  end
  Call(RL_LAUNCH, 1)
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
  if BrightFadeAllMenu ~= nil then
    pcall(BrightFadeAllMenu, 2721617045 --[[fade_menu_encount]], true)
  end
  Call(MT.PRE_MATCH, game)
  Call(MT.DIFF_HELPER, Int(diff))
  local r = Call(MT.RESERVE, game, Int(stadium), Int(diff))
  Log("RESERVE_SOCCER returned", tostring(r), "- closing INAROGUE (result 8)")
  Close(8)
end

-- §20 M4: a loot roll of the loader -> the INAROGUE save. Gear / moves are game items (retail add + the retail «item
-- get» window, callGetItemDialog); a formation was already granted by the loader (the profile's formation book).
function IRM_GiveLoot(l)
  Log("loot", l.kind, tostring(l.id), l.tier, tostring(l.name))
  if l.kind == 3 then
    Message(T(LT.BOSS))
    Message(T(LT.FORM, tostring(l.name), l.tier, l.owned, l.total))
  elseif (l.kind == 1 or l.kind == 2) and type(l.id) == "number" and l.id ~= 0 then
    Message(T(LT.BOSS))
    if Call(LT.CAN_ADD, l.id, 1) == false then
      Message(T(LT.FULL))
      return
    end
    Call(LT.ADD, l.id, 1)
    RequestSave("boss loot")   -- the item into the INAROGUE save (office save watch, section 19)
    funcLuaCommand(C.SE, SE_OK)
    funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
    funcLuaCommand(C.MSG_OPEN, LT.ITEM_GET, 11, 0, l.id)
    coroutine.yield()
    while funcLuaCommand(C.MSG_BUSY) do
      coroutine.yield()
    end
    while not funcLuaCommand(C.MSG_DONE) do
      coroutine.yield()
    end
    funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
    Message(T(l.kind == 1 and LT.USE_GEAR or LT.USE_MOVE))
  end
end

-- back from a match (the title reopened INAROGUE with the run file at stage 3): the trigger's flags -> the loader
-- resolves the node (win = cleared + fragments; loss = run over; draw / no result = played again), then the map
function IRM_AfterMatch()
  local res, gf, ga, probe = Int(Call(MT.GET_BYTE, MT.F_RESULT)), Int(Call(MT.GET_BYTE, MT.F_GF)),
                             Int(Call(MT.GET_BYTE, MT.F_GA)), Int(Call(MT.GET_BYTE, MT.F_PROBE))
  Call(RL_LAUNCH, 2)
  Call(MT.SET_BYTE, MT.F_STATE, 1)
  local _, _, _, _, _, game, diff, _, level, rival = Call(RL_RESUME)
  Log("after match: game", tostring(game), "diff", Int(diff), "result flag", res, "self>enemy", gf, "enemy>self", ga, "trigger", probe)
  -- fid .. ftot: the formation this win dropped (§18, loot formations; fid 0 = none, older loaders return nothing)
  local code, outcome, boss, frags, players, fid, fname, frar, fown, ftot = Call(RL_RESULT, res, gf, ga)
  code, outcome, frags = Int(code), Int(outcome), Int(frags)
  Log("result -> code", code, "outcome", outcome, "boss", tostring(boss), "frags", frags, "x", Int(players),
      "formation", tostring(fid), tostring(fname))
  for _, f in ipairs({MT.F_RESULT, MT.F_GF, MT.F_GA, MT.F_PROBE}) do
    Call(MT.SET_BYTE, f, 0)
  end
  if SL.rogue then
    -- §28: the INAROGUE save gets the cleared result bytes / byte 606 at once, so a later reload of slot 4 (a match
    -- clears the engine's «loaded» guard) can never replay this result
    RequestSave("after match")
  end
  if code ~= 0 then
    Message(string.format(TXT.MATCH_ERROR, code))
    return
  end
  local exists, phase = Call(RL_RUN_INFO)
  if outcome == 1 then
    if boss == true then
      local done = Int(phase)
      -- §20 M4: the boss also gives a random item of the run's loot table (rolled before the phase changes)
      local lk, lid, ltier, lname, lown, ltot = Call(LT.CMD, -1, LT.SALT_BOSS)
      boss_loot = {kind = Int(lk), id = lid, tier = Int(ltier), name = lname, owned = Int(lown), total = Int(ltot)}
      local c3, p2 = Call(RL_NEXT)
      Log("next phase code", Int(c3), "phase", Int(p2))
      Message(string.format(TXT.MATCH_WON_BOSS, done, frags, frags == 1 and "" or "s"))
    else
      Message(string.format(TXT.MATCH_WON, frags, frags == 1 and "" or "s"))
    end
    if Int(fid) ~= 0 and type(fname) == "string" and fname ~= "" then   -- §18: a loot formation dropped
      Message(T(LT.FORM, fname, Int(frar), Int(fown), Int(ftot)))
    end
    if boss_loot ~= nil then
      IRM_GiveLoot(boss_loot)
      boss_loot = nil
    end
  elseif outcome == 2 then
    Message(string.format(TXT.MATCH_LOST, Int(phase)))
    Call(MT.SET_BYTE, MT.F_STATE, 0)
    run = ReadRun()
    RefreshItems()                -- §30: main label, grid, status
    return
  else
    Message(string.format(TXT.MATCH_AGAIN, res == 3 and TXT.MATCH_DRAW or TXT.MATCH_NO_RESULT))
  end
  run = ReadRun()
  IRM_OpenMap()
end

-- ---- actions (docs/game/inarogue.md §4 says where each one goes next) --------------------------------------------
-- ---- INAROGUE's own save, slot 4 (docs/game/modes/inarogue.md §13) ------------------------------------------------
-- The loader's slot info: in a normal slot INAROGUE only offers to enter slot 4 (result 4: the title switches); in
-- slot 4 Back offers "back to your game" (result 5) or the options (result 6).
-- leaving the menu for a slot switch: fade to black here, so the title under INAROGUE is never seen (the switch keeps
-- the black; the next INAROGUE / title fades in once)
function IRM_FadeClose(result)
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
  funcLuaCommand(C.FADE, 1, 0.2)             -- §28: 0.35 -> 0.2 s (the switch / dock keep the black anyway)
  coroutine.yield()
  for _ = 1, 90 do
    if funcLuaCommand(C.FADE_DONE) then
      break
    end
    coroutine.yield()
  end
  Close(result)
end

function IRM_ReadSlots()
  local rs, act, ret, has = Call(SL.CMD)
  SL.known = type(rs) == "number"
  SL.slot, SL.active, SL.ret, SL.has = Int(rs), Int(act), Int(ret), has == true
  SL.rogue = SL.known and SL.active == SL.slot
  Log("slots", "rogue slot", SL.slot, "active", SL.active, "return", SL.ret, "rogue has game", SL.has)
end

-- ---- the welcome gacha of the first entry (docs/game/modes/inarogue-welcome-gacha.md; owner 2026-10-20) ------------
-- The first-run gift drawn (CMND_INAROGUE_WELCOME_DRAW), a welcome message, InaRogue's gold copy of the retail Players
-- Universe scene (ev74_10091) played over the menus, every player revealed one by one by the retail summon performance
-- (soccer_summon_menu, graft inarogue_welcome), then a summary of the players on this screen (tiles = the retail status
-- plate soccer11_04_formation_chara_status: its backing, the kit-dressed miniface, the name and the stars). Data:
-- content\rogue\welcome_gacha.toml. A global table: no new chunk locals (the 200-local limit).
--@lib evt_menu_kit.lua#Pointer
IRW = {
  DRAW = 45978392,            -- CMND_INAROGUE_WELCOME_DRAW () -> n
  INFO = 3116769088,          -- CMND_INAROGUE_WELCOME_INFO (i) -> ok, param, stars, rarity
  STATE = 459028698,          -- CMND_INAROGUE_WELCOME_STATE (state)
  LAYOUT = 1300599966,        -- CMND_INAROGUE_WELCOME_LAYOUT () -> event, n, geometry, meshes, texts, seconds
  RUN = 3913979361,           -- CMND_INAROGUE_SCENE_RUN (reserved) -> ok, slot / why
  TICK = 1628542059,          -- CMND_INAROGUE_SCENE_TICK () -> phase, seconds
  RESERVE = 822852817,        -- CMND_RESERVE_EVENT (event) -> id, refused
  HIDE_MENU = 1670867360,     -- (1, menu): a menu not drawn (retail full-screen video over menus)
  SHOW_MENU = 3257327861,     -- (menu): drawn again
  FADE_BUSY = 1215256347,     -- CMND_BRIGHT_IS_FADE
  SUMMON_MENU = 369188769,    -- soccer_summon_menu
  CHARA_ID = 347353059,       -- (param) -> chara id
  CHARA_NAME = 523676951,     -- (chara id) -> name
  FACE = 552280324,           -- the face icon (layer, idx, faceOnly, mesh, slot, 0, 0, chara id)
  TEXT_VISIBLE = 1505208242,  -- CMND_SET_MENU_TEXT_VISIBLE (layer, text, visible, idx)
  TILE = 1844915256,          -- soccer11_04_formation_chara_status (11 instances on this screen)
  TILE_FACE = 2531809341,     -- _icon_chr_status_dmy01
  TILE_FACE_SLOT = 3236322704,   -- icon_chr_status_dmy01
  TILE_NAME = 1704438437,     -- _text_name01
  TILE_STARS = 4238277407,    -- _text_name02
  HEADER_TEXT = 1220590795,   -- _text_sub_title02 of the header
  GUIDE_TEXT = 378156699,     -- _text_guide01 of the guide line
  TXT = {
    MSG = {1478993723 --[[evt_ir_welcome_msg]], "¡Bienvenido a INAROGUE!"},
    TITLE = {2373811702 --[[evt_ir_welcome_title]], "¡BIENVENIDO A INAROGUE!"},
    SUB = {1756330568 --[[evt_ir_welcome_sub]], "Tus {1} primeros jugadores ya están en el banco"},
    STAR_ON = {2007460865 --[[evt_ir_star_on]], "★"},
    STAR_OFF = {3380229650 --[[evt_ir_star_off]], "☆"},
  },
  open = false,               -- the summary is on screen (Accept / Back / a click anywhere close it)
  pointer = nil,              -- the summary's pointer (evt_menu_kit.lua#Pointer): a mouse click anywhere closes it
  accepted = false,
  shown = 0,                  -- tiles in use
}

function IRW.WaitFade()
  local k = 0
  while funcLuaCommand(IRW.FADE_BUSY) and k < 120 do
    k = k + 1
    coroutine.yield()
  end
end

-- the gold scene over the menus; the screen stays black after it (the reveal opens under black)
function IRW.Scene(event, max_s)
  if type(event) ~= "number" or event == 0 then
    return
  end
  Call(IRW.STATE, 1)
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
  funcLuaCommand(C.FADE, 1, 0.3)
  IRW.WaitFade()
  local id, refused = Call(IRW.RESERVE, event)
  Log("welcome gacha: scene reserved", tostring(id), tostring(refused))
  if type(id) == "number" and id ~= 0 then
    ShowOwnLayers(false)
    funcLuaMenuCommand(IRW.HIDE_MENU, 1, MENU)
    local ok, why = Call(IRW.RUN, id)
    Log("welcome gacha: scene run", tostring(ok), tostring(why))
    if ok == true then
      funcLuaCommand(C.FADE, 0, 0.3)
      local frames, limit = 0, Int(max_s) * 60
      local phase = "starting"
      while frames < limit do
        phase = Call(IRW.TICK)
        if phase ~= "starting" and phase ~= "running" then
          break
        end
        frames = frames + 1
        coroutine.yield()
      end
      Log("welcome gacha: scene", tostring(phase), "after", frames, "frame(s)")
      funcLuaCommand(C.FADE, 1, 0)
    end
    funcLuaMenuCommand(IRW.SHOW_MENU, MENU)
  end
  Call(IRW.STATE, 0)
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
end

-- the retail summon performance, one player at a time (graft inarogue_welcome runs it in soccer_summon_menu and
-- closes that menu at the end)
function IRW.Reveal(n)
  Call(IRW.STATE, 2)
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
  funcLuaCommand(C.OPEN_MENU, IRW.SUMMON_MENU)
  coroutine.yield()
  coroutine.yield()
  local opened = funcLuaMenuCommand(C.EXIST_MENU, IRW.SUMMON_MENU) == true
  Log("welcome gacha: reveal of", n, "player(s), summon menu open", tostring(opened))
  local frames = 0
  while funcLuaMenuCommand(C.EXIST_MENU, IRW.SUMMON_MENU) == true and frames < 36000 do
    frames = frames + 1
    coroutine.yield()
  end
  if frames >= 36000 then
    Log("welcome gacha: the summon screen was still open after 36000 steps: closed")
    funcLuaCommand(C.CLOSE_MENU, IRW.SUMMON_MENU)
  end
  Call(IRW.STATE, 0)
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
end

-- n stars as text (the glyphs are menu_text rows)
function IRW.Stars(n)
  local on, off = T(IRW.TXT.STAR_ON), T(IRW.TXT.STAR_OFF)
  return string.rep(on, n) .. string.rep(off, 5 - n)
end

-- tile k (0-based) of the summary: player k at its place of the rows (g = the layout's geometry: tile, gap, scale,
-- offset x, offset y, rows n, count per row..., centre y per row...)
function IRW.Tile(k, g, meshes, texts)
  local ok, param, stars = Call(IRW.INFO, k)
  if ok ~= true then
    return false
  end
  local tile, gap, scale, dx, dy, nrows = g[1], g[2], g[3], g[4], g[5], Int(g[6])
  local row, col = 1, k
  while row <= nrows and col >= Int(g[6 + row]) do
    col = col - Int(g[6 + row])
    row = row + 1
  end
  if row > nrows then
    return false
  end
  local count = Int(g[6 + row])
  local x = 960 + (col - (count - 1) / 2) * (tile + gap) + dx
  local y = -Int(g[6 + nrows + row]) + dy
  funcLuaMenuCommand(C.OPEN_LAYER, IRW.TILE, k)
  funcLuaMenuCommand(C.LAYER_VISIBLE, IRW.TILE, k, true)
  funcLuaMenuCommand(LAYOUT.POS, IRW.TILE, x, y, 0, k)
  funcLuaMenuCommand(ARC.SCALE, IRW.TILE, scale, scale, 1, k)
  for _, m in ipairs(meshes) do
    funcLuaMenuCommand(C.MESH_VISIBLE, IRW.TILE, m, false, k)
  end
  for _, t in ipairs(texts) do
    funcLuaMenuCommand(IRW.TEXT_VISIBLE, IRW.TILE, t, false, k)
  end
  local id = Call(IRW.CHARA_ID, param)
  if type(id) == "number" and id ~= 0 then
    funcLuaMenuCommand(IRW.FACE, IRW.TILE, k, false, IRW.TILE_FACE, IRW.TILE_FACE_SLOT, 0, 0, id)
    local name = Call(IRW.CHARA_NAME, id)
    funcLuaMenuCommand(C.TEXT, IRW.TILE, IRW.TILE_NAME, type(name) == "string" and name or "", k)
  end
  funcLuaMenuCommand(C.TEXT, IRW.TILE, IRW.TILE_STARS, IRW.Stars(Int(stars)), k)
  return true
end

-- the summary: the players on this screen until Accept / Back
function IRW.Summary(n, g, meshes, texts)
  if type(g) ~= "table" then
    return
  end
  ShowOwnLayers(false)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_BG, 0, true)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_HEADER, 0, true)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_GUIDE_LINE, 0, true)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_BTN_GUIDE, 0, true)
  funcLuaMenuCommand(C.TEXT, L_HEADER, IRW.HEADER_TEXT, T(IRW.TXT.TITLE))
  funcLuaMenuCommand(C.TEXT, L_GUIDE_LINE, IRW.GUIDE_TEXT, T(IRW.TXT.SUB, n), 0)
  IRW.shown = 0
  IRW.accepted = false
  IRW.open = true                 -- before the tiles open: their OnOpenLayer shows them
  for k = 0, n - 1 do
    if IRW.Tile(k, g, type(meshes) == "table" and meshes or {}, type(texts) == "table" and texts or {}) then
      IRW.shown = k + 1
    end
  end
  Log("welcome gacha: summary of", IRW.shown, "player(s)")
  funcLuaCommand(C.FADE, 0, 0.3)
  IRW.pointer = IRW.pointer or EVT_PointerNew()
  IRW.pointer.Reset()             -- the press that ended the reveal is no click here
  while not IRW.accepted do
    local ev = IRW.pointer.Poll()
    if ev.click ~= nil or ev.miss then
      IRW.accepted = true
    end
    coroutine.yield()
  end
  IRW.open = false
  funcLuaCommand(C.SE, SE_DECIDE)
  for k = 0, IRW.shown - 1 do
    funcLuaMenuCommand(C.LAYER_VISIBLE, IRW.TILE, k, false)
  end
  funcLuaMenuCommand(C.TEXT, L_HEADER, IRW.HEADER_TEXT, TXT.HEADER)
  RestoreOwnLayers()
  UpdateGuideLine()
  SyncNativeFocus()               -- the pointer may have moved the engine focus over the hidden rows meanwhile
end

-- Accept / Back while the summary is open: it closes (true = the input is taken)
function IRW.Input()
  if IRW.open then
    IRW.accepted = true
    return true
  end
  return false
end

-- the whole welcome: draw, message, scene, reveal, summary
-- one log line per step of the welcome (on change only)
function IRW.Step(name)
  if IRW.step ~= name then
    IRW.step = name
    Log("welcome gacha step:", name)
  end
end

function IRW.Steps()
  IRW.Step("draw")
  local n = Int(Call(IRW.DRAW))
  Log("welcome gacha: players drawn", n)
  if n <= 0 then
    return
  end
  IRW.Step("message")
  Message(T(IRW.TXT.MSG, n))
  local event, _, g, meshes, texts, max_s = Call(IRW.LAYOUT)
  IRW.Step("scene")
  IRW.Scene(event, max_s)
  IRW.Step("reveal")
  IRW.Reveal(n)
  IRW.Step("summary")
  IRW.Summary(n, g, meshes, texts)
end

-- the whole welcome: draw, message, scene, reveal, summary. Any error gives the plain menu back (the players are in the
-- bank already: the welcome only shows them).
function IRW.Run()
  local ok, err = pcall(IRW.Steps)
  if not ok then
    Log("welcome gacha: error at step", tostring(IRW.step), "- the plain menu comes back:", tostring(err))
    IRW.open = false
    for k = 0, 10 do
      funcLuaMenuCommand(C.LAYER_VISIBLE, IRW.TILE, k, false)
    end
    Call(IRW.STATE, 0)
    funcLuaMenuCommand(IRW.SHOW_MENU, MENU)
    funcLuaMenuCommand(C.TEXT, L_HEADER, IRW.HEADER_TEXT, TXT.HEADER)
    RestoreOwnLayers()
    UpdateGuideLine()
    funcLuaCommand(C.FADE, 0, 0.3)
    funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
  end
  IRW.Step("done")
  IRW.step = nil
end

function IRM_FirstEntry()
  local changed = IRM_UnlockProgress()   -- §25: story completed + Chronicle unlocked in slot 4 (only what is not set yet)
  changed = changed + IRM_MarkHelpsSeen()   -- §24: no retail tutorial pages in the INAROGUE save
  DK.Dress(Int(Call(DK.GET_VS)))        -- §21: the generic kit / emblem on a team that has none (new and old saves)
  if not SL.has or changed > 0 then
    -- a brand-new INAROGUE save is written at once (slot 4 exists before anything tries to load it); an entry that
    -- wrote something (story / Chronicle unlock, help pages) is saved too
    Log("slot 4: save", SL.has and "(progress written)" or "(first save of the new INAROGUE game)")
    Call(3673719958)   -- CMND_SYSTEM_AUTO_SAVE
    SL.has = true
  end
  local _, _, gift = Call(RL_STARTER)
  if gift == true then
    IRW.Run()                   -- the welcome gacha: the first-run starters drawn, revealed and summed up
  end
end

function IRM_EnterRogue()
  if not SL.known then
    Message(TXT.NO_SLOTS)
    return
  end
  -- §28 (Nacho, 30/09): no «¿Entrar en INAROGUE?» window; the guide line explains the single INAROGUE save
  Log("enter slot", SL.slot, "from", SL.active, "has game", tostring(SL.has))
  funcLuaCommand(C.SE, SE_DECIDE)
  IRM_FadeClose(4)
end

-- In-place entry (docs/game/engine/save-overlay-session.md; Nacho 07/10: «no debería pasarse a la 4ª ranura»): INAROGUE
-- is open in the player's slot without the overlay (the title's seamless entry did not run or was refused): the
-- INAROGUE save is swapped in right here under this open menu (CMND_EVT_RL_SESSION_BEGIN 0): no fade, no close, no
-- slot switch, no GAME_RESET. true = INAROGUE's game is the one in memory now (SL.rogue). Off ([rogue] session_entry =
-- false), no INAROGUE game yet or refused: false, and the caller keeps the old way (IRM_EnterRogue).
function IRM_EnterInPlace()
  local SS = {STATE = 3747521885 --[[CMND_EVT_RL_SESSION_STATE]], BEGIN = 105439923 --[[CMND_EVT_RL_SESSION_BEGIN]],
              SAVE_WORKING = 1979970074 --[[CMND_IS_SAVE_WORKING]]}   -- no new chunk local (the 200-local limit)
  local sopen, _, _, _, _, enabled = Call(SS.STATE)
  if sopen ~= false or enabled ~= true or not SL.known or SL.rogue or not SL.has then
    return false
  end
  local k = 0                     -- BEGIN is refused while a save / load job runs: wait for it (bounded)
  while funcLuaCommand(SS.SAVE_WORKING) and k < 600 do
    k = k + 1
    coroutine.yield()
  end
  local ok, code, kib, ms = Call(SS.BEGIN, 0)
  Log("in-place entry: overlay begin", tostring(ok), code, kib, ms)
  if ok ~= true then
    return false
  end
  IRM_ReadSlots()
  Log("in-place entry: INAROGUE's save is in memory over the player's slot", SL.ret, "- no slot switch", tostring(SL.rogue))
  if not SL.rogue then
    return false
  end
  Call(RL_NO_ROLE_ALL)
  run = ReadRun()
  RefreshItems()
  IRM_FirstEntry()
  return true
end

-- Back in slot 4 (§28, Nacho 30/09): straight back, no «¿Volver a tu partida?» window; the same 0.2 s fade as the way in
function IRM_LeaveRogue()
  -- a seamless session (inarogue-no-game.md §10): the title swaps the normal game back in memory under itself, so
  -- this closes like any child menu (no fade to black); 5 = back to the session's slot, whichever it is
  local sopen, _, _, _, _, _, _, swapped = Call(3747521885 --[[CMND_EVT_RL_SESSION_STATE]])
  if sopen == true and swapped == true then
    Log("leave the session to slot", SL.ret)
    funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
    Close(5)
  elseif SL.ret >= 2 then
    Log("leave slot", SL.slot, "to", SL.ret)
    IRM_FadeClose(5)
  else
    Log("leave slot", SL.slot, "to the slot screen")
    IRM_FadeClose(7)
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
  if not SL.rogue and it.id ~= "help" and IRM_EnterInPlace() then
    Log("decide", it.id, "continues in INAROGUE's save (overlay, no slot switch)")
  end
  if it.id == "help" then
    ShowHelp()
  elseif it.id == "shop" then
    -- the shop screen is the Rogue-points graft's (rogue_avatars): it sets EVT_IR_EXTRA.shop = {text = fn, open = fn}
    local x = type(EVT_IR_EXTRA) == "table" and EVT_IR_EXTRA.shop or nil
    if x ~= nil and type(x.open) == "function" then
      x.open()
    elseif not SL.rogue then
      IRM_EnterRogue()
    else
      Log("shop: no EVT_IR_EXTRA.shop hook (graft rogue_avatars) yet")
    end
  elseif not SL.rogue and (it.id == "start" or it.id == "album" or it.id == "team" or it.id == "new") then
    IRM_EnterRogue()
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
  -- the title's press waits for this sign that the screen really runs (crc32("evt_inarogue_alive"))
  funcLuaCommand(C.P_SET, 3151688232, 0, 1, 1)
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
  funcLuaCommand(C.P_CLEAR, KEY_RESULT)
  -- the pre-match dock launched the match (byte 606 = 23, §20 M3): its result is read now; otherwise a match launched
  -- earlier (EVT_IR_STATE 2 = in flight) that left the node at stage 3 is resolved too (no result = played again)
  local played = DK.TakePlayed()
  dock_after = not played and DK.Pending() ~= 0
  match_after = false
  if SL.rogue and run.active and not dock_after then
    local stage = Int(Call(RL_RESUME))
    match_after = stage == 3 and (played or Int(Call(MT.GET_BYTE, MT.F_STATE)) == 2)
  end
  Log("open", FLAGS_ENABLED, run.active, "match_after", match_after, "played", played)
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
      StartCo(IRM_AfterMatch)   -- the result of the reserved match, then the map (§14)
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
  funcLuaCommand(C.SE, ARC.SE_MOVE)
  Unlight(from)
  FocusItem(want, false)
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
    StartCo(IRM_LeaveRogue)       -- slot 4: the title only hosts INAROGUE
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
