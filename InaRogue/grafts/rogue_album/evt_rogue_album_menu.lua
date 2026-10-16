-- evt_rogue_album_menu (plain Lua 5.2 source, Expanded Victory Tool): the INAROGUE ALBUM as a sticker book.
-- Opened by evt_inarogue_menu (row "Álbum") as a child menu. Built by research/scripts/rogue_album_book_build.py:
-- the crc / num placeholders are filled and the geometry table G replaces the GEOM marker line.
-- Design: docs/game/modes/inarogue.md §14.5 (Panini-style book, 2026-09-28).
--   evt_album_book   x1   the open book (procedural art, evt_rogue_album.g4tx)          quads: clones of
--   evt_album_slot   x42  sticker slot frames (missing: number + silhouette; owned: base)  cmn01_10_new_icon,
--   evt_album_plate  x8   section header plates                                          free layers placed by
--   evt_album_emblem x8   team emblem (vsroute_emblem.g4tx) / crest / N★ mark              CMND_SET_LAYER_LOCAL_POS
--   evt_album_text   x60  numbers, header names / counts, page numbers (guide-line clone, text box at the origin)
--   team00_01_chara_card_for_list x43  = the 42 stuck stickers (owned cards only) + the info card's card
--   evt_album_over   x2   0 = page-turn shadow, 1 = selection glow;  evt_album_leaf x1 = the turning leaf
--   evt_album_info_bg x1 / evt_album_info x5 = the info card right of the book (2026-10-06: the book sits on the
--                         left; the card follows the cursor, no Aceptar popup any more). 2026-10-07: drawn as one more
--                         PAGE of the album (paper, frame, bolts on the cloth cover), rounded rectangles only: the
--                         name plate (rarity colour), the card or the «?» card on the left, a column of three emblems
--                         right of it (element icon, position badge, the card's own club crest; «?» while missing)
--   save01_04 window x1   = never shown (its attach base objbin only carries the card / grid locators)
-- Missing cards never get the card command: their face is never loaded (no spoilers).
-- Data: vr-loader module `rogue`, CMND_EVT_RL_ALBUM_INFO op 4 (card), 5 (section jump), 6 (find), 7-10 (the book).
-- Keys (setting rows of the input anchor -> OnFunction): arrows move, Tab (CMD_FUNC2) order, L1/R1 page, L2/R2
-- section; Back = close the menu. Enter does nothing (the info card is always there).
-- Rule (position-cards.md §4b): no engine call at top level; funcLuaCommand only exists inside callbacks.
INCLUDE("LUA_PROG_BASE")
INCLUDE("LUA_SAVEDATA_MANAGEMENT_MENU_INC")   -- header helpers (soccer top inc, soccer_common) + general window inc
INCLUDE("LUA_MENU_DEF")
INCLUDE("LUA_SOCCER_FORMATION_MENU_INC")      -- NameSetting_CharaCardForSoccer (card node names; retail seasonal list)

local G = {BX = 40, BY = 90, BW = 1160, BH = 826, LX = 64, RX = 620, PY = 102, PW = 556, PH = 802, SPINE = 620, ROW0 = 116, ROW_H = 108, ROWS = 7, COLS = 3, SX0 = 58, SDX = 166, SW = 108, SH = 97, SDY = 5, STRIP = 16, CARD_S = 0.7, CARD_W = 154, CARD_H = 116, PLX = 26, PLW = 504, PLH = 60, PLY = 24, EMX = 60, EMS = 76, EMY = 54, HNX = 110, HCX = 438, HTY = 54, PNY = 889, Q = 36, TXT_H = 68, TXT_S_NUM = 0.44, TXT_S_HDR = 0.72, TXT_S_CNT = 0.6, TXT_S_PAGE = 0.46, GLOW_W = 124, GLOW_H = 97, WIN_X = 960, WIN_Y = 530, FLIP_FRAMES = 18, IX = 1240, IY = 90, IW = 640, IH = 826, I_PAD = 64, I_NAME_W = 560, I_NAME_H = 85, I_NAME_Y = 66, I_CARD_X = 194, I_CARD_Y = 248, PANEL_S = 2, I_GX1 = 425, I_GX2 = 545, I_GY1 = 187, I_GY2 = 309, I_BOX_W = 110, I_BOX_H = 110, I_POS_W = 84, I_POS_H = 48, I_ELEM_S = 52, I_CLUB_S = 72, I_UNK_S = 48, I_OL = 3, I_ROW_Y = 452, I_ROW_H = 96, I_R1_W = 172, I_R1_DX = 194, I_ROW2_Y = 572, I_R2_W = 250, I_R2_DX = 136, I_LBL_DY = -24, I_NUM_DY = 16, TXT_S_ITITLE = 0.8, TXT_S_ILBL = 0.5, TXT_S_INUM = 1.2, TXT_S_IVAL = 0.85, TXT_EM = 34.7}

-- ---- texts: menu_text rows (9 languages, rogue_album_book_build.py TEXTS); the Spanish literal is the fallback ------
local TXT = {
  title = {3060551858, "ÁLBUM"},
  guide = {1472524268, "Álbum: {1} / {2} ({3} %)"},
  order_fmt = {3566418499, "Orden: {1}"},
  orders = {{4025622523, "Equipos"}, {2566205293, "Rareza"}, {33324759, "Faltan"},
            {1996181057, "Conseguidas"}, {3902790626, "Recientes"}, {2677599092, "Coste"}},
  sec_tier = {4214316866, "{1} estrellas"},
  sec_date = {1966210994, "Fichados el {1}"},
  sec_cost = {3347668020, "Coste {1}"},
  sec_cont = {954544168, "{1} (sigue)"},
  others = {3744171950, "Otros"},
  number = {1761750796, "Nº {1}"},
  missing = {2515480623, "Sin conseguir"},
  missing_hint = {1959910142, "Todavía no lo tienes: consíguelo en las partidas de INAROGUE."},
  rarity = {1213369886, "Rareza INAROGUE: {1}★"},
  cost = {2423906937, "Coste: {1}"},
  games = {1652098024, "Partidas jugadas: {1}"},
  goals = {1518221046, "Goles marcados: {1}"},
  obtained = {1185439226, "Obtención"},
  source = {2685947691, "Origen"},
  -- how the card was obtained (bank::source 1-5; 0 unknown = «-»)
  src = {{38803732, "Inicial"}, {2606319790, "Fichaje"}, {3965614136, "Sorteo"}, {1916464539, "Prueba"}, {87940365, "Otro"}},
  signed = {3777620123, "Fichado el"},
  collected = {1661473787, "Conseguida"},
  pos = {{4221915126, "Portero"}, {1655447116, "Delantero"}, {363540186, "Centrocampista"},
         {2345646969, "Defensa"}},
  elem = {{876558299, "Viento"}, {2906023521, "Bosque"}, {3660666615, "Fuego"},
          {1146471252, "Montaña"}},
  empty = {4120712477, "No hay cartas en esta vista. Pulsa <CMD_FUNC2> para cambiar el orden."},
  no_loader = {59215208, "El álbum necesita el vr-loader con el módulo «rogue» activado (app: Proyecto > Loader)."},
}
local UNKNOWN = "???"
local DATE_FMT = "%02d/%02d/%04d"
local TEAM_KEY = 1287639194          -- menu_text id of a team name = (team id + TEAM_KEY) mod 2^32
local CMD_TEXT_GET = 4074371074          -- CMND_TEXT_GET (text id) -> string of the game's language

local MENU = 26522013
local KEY_RESULT = 4152609444
local RL = {
  VERSION = 2217361807,
  LOG = 3661580131,
  CHARA = 1144149794,          -- (param) -> tier, cost, inPool, statTotal, card, element, position
  ALBUM = 2615878751,
}
local MOD_ROGUE = 32768
local CMD_CHARA_INFO = 4060384944   -- CMND_GET_CHARA_INFO (paramId, 0) -> ok, name
local CMD_CARD = 2339877830         -- card by chara param id (argument list of victory_road_seasonal_menu UpdateListItem)
local N_ORDERS = 6
-- the «Ordenar» cycle (Nacho, 30/09): «Faltan» (order 2) is no longer offered; Equipos (0) stays the default and the
-- base order. The loader keeps order 2 (op ids unchanged); only this cycle skips it.
local SORT_CYCLE = {0, 1, 3, 4, 5}
local TEAM_ORDERS = {[0] = true, [2] = true, [3] = true}

-- ---- layers -----------------------------------------------------------------------------------------------------
local L_ROW = 3455690937        -- save01_02_list_item (1 instance: the input anchor, off screen)
local L_WINBASE = 3903826878    -- save01_03_detail_window_attach_base (evt_rogue_album_win.objbin)
local L_WIN = 536044352         -- save01_04_savedata_detail_window (never shown)
local L_CARD = 1791816279       -- team00_01_chara_card_for_list (43 instances)
local L_NEW = 3213627091       -- 1 instance: the info card's N★ mark
-- the «N★» mark is engraved into the tier card backgrounds (evt_rogue_card_base_NN, card_rarity_outline_build.py,
-- Nacho 2026-10-07): the front mark layer stays hidden; true = the old front mark
local FRONT_MARK = false
local L_HEADER = 575058101      -- mainmenu90_01_header
local L_GUIDE_LINE = 3078308064 -- mainmenu90_05_content_guide_line01
local L_CURSOR = 2296367164     -- cmn05_01_cursor (hidden: the glow is the cursor)
local L_BTN_GUIDE = 1138543975  -- mainmenu01_06_base_button_guide
local L_BTN = 9396745           -- mainmenu01_07_button_guide
local L_RET = 2005383485        -- mainmenu01_10_return_arrow_button_guide
local L_BOOK = 1136317876
local L_SLOT = 609310434
local L_PLATE = 3972333442
local L_EMBLEM = 2359309093
local L_TEXT = 3017068866
local L_OVER = 1017370076
local L_LEAF = 1321236066
local L_INFO_BG = 1111032447
local L_INFO = 1138116562
local BOOK_LAYERS = {[L_BOOK] = 1, [L_SLOT] = 42, [L_PLATE] = 10, [L_EMBLEM] = 8,
                     [L_TEXT] = 73, [L_OVER] = 2, [L_LEAF] = 1, [L_INFO_BG] = 1, [L_INFO] = 5}
local WIN_LABEL = 3773505316
local CARD_LABEL = 2137633855
local MARK_LABEL = 1312789106
local N_SLOTS = 42
local N_HDR = 8
local PER_PAGE = G.ROWS * G.COLS
local HDR_PER_PAGE = N_HDR / 2
local PANEL = N_SLOTS            -- card instance of the info card
local T_NUM0, T_HDR0, T_PAGE0 = 0, N_SLOTS, N_SLOTS + 2 * N_HDR   -- text instances
local T_INFO0 = T_PAGE0 + 2      -- info card texts (T_INFO0 + I.*)
-- no rarity row (2026-10-06, Nacho: the banner and the N★ mark already show it); 2026-10-07 (Nacho): no «Cartas del
-- equipo» row, position / element / club as emblems (no text), cost + signing date one badge row, games / hint line
local I = {TITLE = 0, COST = 1, COST_N = 2, GAMES = 3, GAMES_N = 4, GOALS = 5, GOALS_N = 6, GOT = 7, GOT_N = 8,
           SRC = 9, SRC_N = 10, NUM = 11, NUM_N = 12}   -- data box labels / values
-- text instances reserved for the info card
local N_INFO_TEXT = 13
local INFO_BANNER, INFO_MISSING, INFO_POS, INFO_ELEM, INFO_CLUB = 0, 1, 2, 3, 4   -- evt_album_info (0 = name banner)
local PLATE_OL_ELEM, PLATE_OL_POS = N_HDR, N_HDR + 1   -- evt_album_plate 8 / 9: the icons' black outlines
local OVER_SHADOW, OVER_GLOW = 0, 1
local CARD_CURSOR = 945715707   -- card objbin cursor labels (retail seasonal turns both off)
local CARD_CURSOR2 = 1967169874
local MARK_SCALE_X, MARK_SCALE_Y = 2.0 * G.PANEL_S, 1.0 * G.PANEL_S

local C = {
  TEXT = 1083631230,          -- CMND_SET_MENU_TEXT_STRING (layer, node, string, idx)
  TEXT_VISIBLE = 1505208242,  -- CMND_SET_MENU_TEXT_VISIBLE (layer, text, visible, idx)
  MESH_VISIBLE = 3405944500,  -- (layer, mesh, bool, idx)
  LAYER_VISIBLE = 711242136,  -- (layer, idx, bool)
  SPRITE = 558735651,         -- (layer, textureCrc, spriteCrc, nodeCrc, 0, idx)
  LOAD_TEX = 839427544,       -- CMND_LOAD_MENU_RES_TEXTURE (path)
  SCALE = 3778714801,         -- CMND_SET_LAYER_LOCAL_SCALE (layer, sx, sy, sz, idx)
  POS = 1389957207,           -- CMND_SET_LAYER_LOCAL_POS (layer, x, y, z, idx); layout units, y up
  PRIM_INDEX = 1927054058,    -- (layer, idx, primName) -> prim
  PRIM_VALUE = 3609943765,    -- (layer, idx, prim, value)
  PRIM_VISIBLE = 1233047821,  -- (layer, idx, primName, bool)
  ATTACH_TRACE = 1774843228,  -- (layer, idx, label, bool)
  OPEN_LAYER = 629267548,
  FOCUS_ENABLE = 3518307824,  -- (layer, bool)
  FOCUS_SET = 3466097042,     -- (layer, idx)
  LIST_NUM = 3252599449,      -- (layer, count)
  GUIDE_SET = 2209673388,     -- button guide (menu, layer, texts, icons, offsets, ?, ?)
  GUIDE_CMD = 452337289,      -- button guide commands (menu, layer, cmds)
  GUIDE_OPT = 1432240275,     -- (menu, layer, false): retail chara_bank_menu after its guide
  SE = 1917805374,
  MENU_ACTIVE = 1558704558,   -- (menu, bool)
  CLOSE_MENU = 320421347,     -- CMND_CLOSE_MENU_OBJECT
  FADE = 609722083,           -- (1 out / 0 in, seconds)
  FADE_DONE = 2259183189,
  P_SET = 3860611758, P_CLEAR = 3363400568,   -- parameter store (numbers only)
  MSG_OPEN = 2289627655, MSG_KIND = 2351835063, MSG_DONE = 682363669, MSG_BUSY = 898725220,
}
local CUR = 3313461902          -- crc32("cursor"): the anchor row's cursor label
local FN = {
  SORT = 3648750759, UP = 121770756, DOWN = 2493572798, LEFT = 4063793645,
  RIGHT = 697327053, PAGE_PREV = 2563649507, PAGE_NEXT = 537114506,
  TEAM_PREV = 3471558466, TEAM_NEXT = 1982226219,
}
-- button guide: retail texts (every language): Ordenar / Cambiar página / Equipo (no Aceptar since 2026-10-06)
local G_SORT, G_PAGE, G_TEAM = 1844975998, 884337385, 2058233886
local I_FUNC2, I_R1, I_R2 = 2387151820, 1596629152, 3487556099
local K_FUNC2, K_R1, K_R2 = 3170216173, 942075773, 2704260807
local SE_OK, SE_BACK = 3848881948, 202039849
local SE_PAGE = 3848881948      -- the cursor sound for the page turn too (no retail page-flip SE is known)

-- textures and sprite nodes
local TEX = "#/menu/220_img/evt_rogue/evt_rogue_album.g4tx"
local TEX_RARITY = "#/menu/220_img/evt_rogue/evt_rogue_rarity.g4tx"
local TEX_EMBLEM = "#/menu/200_icon/01_icon_emblem/vsroute/icon_vsroute_emblem/vsroute_emblem.g4tx"
-- info card emblems (both textures are in the menu's res list): the retail position badges (localised: DC / MC / DF /
-- POR in Spanish) and element icons; enums as RL.CHARA: position 1 GK, 2 FW, 3 MF, 4 DF; element 1 wind .. 4 mountain
local TEX_POS = "#/menu/200_icon/15_icon_common2/<LG>/icon_common2.g4tx"
local TEX_ICON = "#/menu/200_icon/15_icon_common/icon_common.g4tx"
local POS_SPRITE = {"icon_param2_position04", "icon_param2_position01", "icon_param2_position02", "icon_param2_position03"}
local ELEM_SPRITE = {"icon_cmd_type01", "icon_cmd_type02", "icon_cmd_type03", "icon_cmd_type04"}
-- 2026-09-28 (Nacho: every team with its real emblem): a team whose emblem is not on the Chronicle board atlas shows
-- its own small emblem texture dx11/menu/200_icon/01_icon_emblem/<em>_s.g4tx (sprite <em>_s01; op 9 gives
-- crc32("<em>_s01")), loaded on demand with CMND_LOAD_MENU_RES_TEXTURE (asynchronous: the header shows no emblem
-- until the texture is in, then PollEmblems puts it; the save-slot emblems load the same way, tested in game).
-- crc32("<em>_s01") -> "<em>" (written by rogue_album_book_build.py)
local EMB_DIR = "#/menu/200_icon/01_icon_emblem/"
local EMB_S = {
  [26688521] = "em530566", [65659264] = "em581003", [128320762] = "em030061", [218094234] = "em561312",
  [225539302] = "em571049", [326629514] = "em110014", [344009649] = "em111004", [345592107] = "em541038",
  [389904228] = "em111011", [400272445] = "em900014", [427266713] = "em900008", [429902970] = "em551062",
  [439162133] = "em111018", [483070274] = "em050246", [492154047] = "em111032", [518647914] = "em111027",
  [539619807] = "em551097", [540378383] = "em111033", [549187486] = "em110009", [564869362] = "em050247",
  [596236762] = "em111026", [659373221] = "em111019", [702611969] = "em111005", [710762196] = "em111010",
  [716932493] = "em900015", [832566058] = "em561313", [897224516] = "em050201", [914960706] = "em520517",
  [921127552] = "em561339", [986066250] = "em030060", [1049217072] = "em581002", [1063106124] = "em520521",
  [1096617497] = "em530584", [1128171608] = "em541089", [1179632187] = "em561318", [1318408100] = "em010013",
  [1341206717] = "em530598", [1343628783] = "em080014", [1352469940] = "em111012", [1394692449] = "em111007",
  [1403681082] = "em080001", [1405585976] = "em900002", [1423409754] = "em110017", [1497991866] = "em111024",
  [1526060655] = "em111031", [1533766546] = "em050245", [1572660565] = "em571019", [1581233834] = "em551061",
  [1625083109] = "em571018", [1667211034] = "em551060", [1680450314] = "em111025", [1712013858] = "em050244",
  [1737883615] = "em111030", [1773644778] = "em110016", [1830551389] = "em900016", [1845306372] = "em111013",
  [1849784529] = "em111006", [1850910371] = "em591001", [1945462292] = "em010012", [1979404749] = "em530578",
  [1983875578] = "em561310", [2011126852] = "em530665", [2086615866] = "em060220", [2112883799] = "em541056",
  [2166655348] = "em020002", [2310898025] = "em530581", [2322311220] = "em561322", [2350102251] = "em070001",
  [2351043621] = "em030058", [2399671101] = "em541078", [2443773386] = "em111021", [2450872607] = "em111034",
  [2515877570] = "em020044", [2558362308] = "em111017", [2560317853] = "em900012", [2613173777] = "em111002",
  [2620853546] = "em110012", [2629396411] = "em111028", [2668347092] = "em551052", [2706842778] = "em110013",
  [2715373067] = "em111029", [2724960100] = "em551053", [2770185076] = "em111016", [2784718893] = "em900013",
  [2789682424] = "em900006", [2795632545] = "em111003", [2828343154] = "em020045", [2847075817] = "em561346",
  [2853089596] = "em561353", [2860562485] = "em060301", [2898865274] = "em111020", [2901976810] = "em571022",
  [2940533311] = "em571037", [2943709359] = "em111035", [2953559244] = "em530574", [2982755728] = "em581004",
  [3070984580] = "em561323", [3202287242] = "em561315", [3204358043] = "em050238", [3212335356] = "em541070",
  [3220591093] = "em040022", [3308651157] = "em040020", [3356463342] = "em070017", [3437948032] = "em541105",
  [3458071481] = "em530582", [3463941681] = "em561334", [3513894576] = "em111008", [3559628338] = "em050243",
  [3585418191] = "em111037", [3590946586] = "em111022", [3599177099] = "em110018", [3626707759] = "em110004",
  [3684136954] = "em110011", [3696242257] = "em571003", [3697386689] = "em111001", [3699867544] = "em900004",
  [3755866132] = "em111014", [3795253759] = "em080013", [3797617405] = "em900010", [3804090788] = "em111015",
  [3874971210] = "em110010", [3906275967] = "em111036", [3907289327] = "em571034", [3914053506] = "em050242",
  [3948469306] = "em571021", [3949549226] = "em111023", [3957799995] = "em110019", [3960598272] = "em111009",
  [3987655660] = "em561350", [4052403504] = "em541104",
}
local TEX_LOADING = 1506186496  -- (textureCrc) -> true while still loading (kizuna_town_menu_inc)
local NODE_QUAD = 1909474081    -- icon_new01 (the cmn01_10 quad's sprite node)
local NODE_GUIDE = 378156699    -- _text_guide01 (the text clone's node)
local NODE_BASE, NODE_COLOR = 840912853 --[[icon_chr_base01_l01]], 3896534971 --[[icon_chr_color01_l01]]
local CARD_HIDE = {814224422 --[[_icon_lock01]], 2635558741 --[[_icon_card01]], 3098974311 --[[_leader_base01]],
                   3330617040 --[[_gtxt_leader01]], 2815608092 --[[_icon_captain01]], 2942116298 --[[_icon_chr_grayout01]],
                   338392935 --[[_basara_avatar_l01]], 897168128 --[[_icon_synergy_l01]], 2893079226 --[[_icon_synergy_l02]],
                   3203992661 --[[_icon_ai_role_dmy01]], 3345942320 --[[_icon_chr_focus_l01]],
                   -- the cyan / blue outline of the listing cards (2026-09-28: stickers show the card only; the
                   -- tier plate on the base / gradation meshes is the rarity frame and stays)
                   960763094, 2508362790, 775876763,
                   2197319787, 3491095421}
local CARD_FACE = 2828003679 --[[_icon_chr_dmy_l01]]   -- portrait mesh: hidden until its texture has loaded
local CMD_LOADING = 1277042906  -- (layer, idx) -> true while the layer still loads a texture
local CMD_CARD_APPLY = 3810560722
local ROW_MESHES = {3025401186, 486732393, 376662541, 3232607807, 1516082254, 3292070381, 1712955010}  -- anchor row
local CARD_LV_MESHES = {1343488901, 1198450632, 1451641049, 3482261859,
                        1107078292, 3639999790}
local CARD_LV_PRIMS = {"num_chr_l01", "num_chr_s01", "num_chr_l01_q", "num_chr_s01_q", "num_chr_l01_gray",
                       "num_chr_s01_gray", "num_chr_l01_cup", "num_chr_s01_cup", "num_chr_l01_basara", "num_chr_s01_basara"}
local CARD_NAME = 170976702

-- the hidden window's attach-base arrow (save01_03)
local N_ARROW = 3186689458

-- ---- state -------------------------------------------------------------------------------------------------------
local has_loader = false
local order = 0
local book = {pages = 0, sections = 0, count = 0, total = 0, owned = 0}
local spread = 0          -- pages 2*spread (left) and 2*spread + 1 (right)
local sel = -1            -- selected list position (-1 = none)
local rows_cache = {}     -- page -> {row = {kind, sec, first, n, cont}}
local sec_cache = {}      -- section -> info
local card_cache, card_cached = {}, 0
local slot_pos = {}       -- slot 0-41 -> list position on the spread shown
local scene = {quad = {}, text = {}, card = {}}   -- what every free instance / card shows (re-applied on open)
local card_ready = {}
local face_wait = {}
local flip = nil          -- page turn in progress {frame, dir, target, sel}
local glow_t = 0
local ready = false
-- the input that opened this screen (Accept / click on the INAROGUE menu) must not reach it: Back and clicks are
-- swallowed until the screen is live and 20 frames more (Nacho 07/10: a child screen closed itself on its first open)
local open_guard = 20           -- frames (reset to 20 in OnInit)
local closing = false
local emb_asked = {}      -- emblem texture path -> true: CMND_LOAD_MENU_RES_TEXTURE sent
local emb_pending = {}    -- "layer:instance" -> {layer, inst, path, sprite, x, y, w, h, frames}: waiting for its texture

-- ---- helpers --------------------------------------------------------------------------------------------------
--@lib evt_menu_kit.lua#Call

local function Log(...)
  Call(RL.LOG, "rogue_album", ...)
end

--@lib evt_menu_kit.lua#Int

-- pointer (mouse / free cursor): hover = the keys' selection, click = select, wheel / page edges = turn the page
--@lib evt_menu_kit.lua#Pointer
local Ptr = EVT_PointerNew()

-- a menu_text row in the game's language (fallback: the Spanish literal)
local function T(t)
  local s = Call(CMD_TEXT_GET, t[1])
  if type(s) == "string" and s ~= "" then
    return s
  end
  return t[2]
end

-- "{1}".. placeholders
local function F(s, ...)
  local a = table.pack(...)
  return (s:gsub("{(%d)}", function(k)
    local v = a[tonumber(k)]
    return v == nil and "" or tostring(v)
  end))
end

--@lib evt_menu_kit.lua#Pct

local function DateText(a)
  if a > 19000000 then
    return string.format(DATE_FMT, a % 100, math.floor(a / 100) % 100, math.floor(a / 10000))
  end
  return "-"
end

local function Tier(e)
  return math.max(1, math.min(5, e.tier))
end

-- ---- loader reads ------------------------------------------------------------------------------------------------
local function ReadBook()
  rows_cache, sec_cache, card_cache, card_cached = {}, {}, {}, 0
  book = {pages = 0, sections = 0, count = 0, total = 0, owned = 0}
  local api, mods = Call(RL.VERSION)
  has_loader = type(api) == "number" and type(mods) == "number" and math.floor(mods / MOD_ROGUE) % 2 == 1
  if not has_loader then
    return
  end
  local pages, secs, n, total, owned = Call(RL.ALBUM, 7, order)
  book = {pages = math.max(1, Int(pages)), sections = Int(secs), count = Int(n), total = Int(total), owned = Int(owned)}
  local _, total0, owned0 = Call(RL.ALBUM, 0)
  book.total, book.owned = Int(total0), Int(owned0)
end

local function PageRows(p)
  if p < 0 or p >= book.pages or not has_loader then
    return nil
  end
  local r = rows_cache[p]
  if r ~= nil then
    return r
  end
  local v = table.pack(Call(RL.ALBUM, 8, order, p))
  r = {}
  for k = 0, G.ROWS - 1 do
    local b = k * 5
    r[k] = {kind = Int(v[b + 1]), sec = Int(v[b + 2]), first = Int(v[b + 3]), n = Int(v[b + 4]), cont = v[b + 5] == true}
  end
  rows_cache[p] = r
  return r
end

local function TeamName(tid, es)
  if tid == 0 then
    return T(TXT.others)
  end
  local s = Call(CMD_TEXT_GET, (tid + TEAM_KEY) % 4294967296)
  if type(s) == "string" and s ~= "" then
    return s
  end
  return es
end

local function Section(s)
  local c = sec_cache[s]
  if c ~= nil then
    return c
  end
  local ok, key, n, sowned, page, towned, tcount, tid, emblem, name = Call(RL.ALBUM, 9, order, s)
  if ok ~= true then
    return nil
  end
  c = {key = Int(key), count = Int(n), sowned = Int(sowned), page = Int(page), towned = Int(towned),
       tcount = Int(tcount), tid = Int(tid), emblem = Int(emblem), es = type(name) == "string" and name or "?"}
  if TEAM_ORDERS[order] then
    c.title, c.a, c.b = TeamName(c.tid, c.es), c.towned, c.tcount
  elseif order == 1 then
    c.title, c.a, c.b = F(T(TXT.sec_tier), c.key), c.sowned, c.count
  elseif order == 4 then
    c.title, c.a, c.b = F(T(TXT.sec_date), DateText(c.key)), c.count, nil
  else
    c.title, c.a, c.b = F(T(TXT.sec_cost), c.key), c.count, nil
  end
  sec_cache[s] = c
  return c
end

-- list position i of the current order (op 4)
local function Entry(i)
  if i == nil or i < 0 or i >= book.count then
    return nil
  end
  local e = card_cache[i]
  if e ~= nil then
    return e
  end
  local ok, param, owned, tier, uid, team, towned, tcount, cost, runs, added, tname, whatif, number, club, goals, source =
    Call(RL.ALBUM, 4, i, order)
  if ok ~= true then
    return nil
  end
  e = {pos = i, param = param, owned = owned == true, tier = Int(tier), uid = uid, team = Int(team), towned = Int(towned),
       tcount = Int(tcount), cost = Int(cost), runs = Int(runs), added = Int(added),
       tname = type(tname) == "string" and tname or "?", whatif = whatif == true, number = Int(number),
       goals = Int(goals), source = Int(source),   -- INAROGUE goals, how it was obtained (op 4 values 16 / 17)
       club = Int(club),        -- emblem sprite of the card's OWN club (not the album group's team; 0 = generic crest)
       name = UNKNOWN, element = 0, position = 0}
  if e.owned then
    local _, name = Call(CMD_CHARA_INFO, param, 0)
    local _, _, _, _, _, element, position = Call(RL.CHARA, param)
    e.name = type(name) == "string" and name or "?"
    e.element, e.position = Int(element), Int(position)
  end
  if card_cached >= 256 then
    card_cache, card_cached = {}, 0
  end
  card_cache[i] = e
  card_cached = card_cached + 1
  return e
end

local function Current()
  return Entry(sel)
end

-- ---- scene: free quads / texts, applied now and again when their layer opens --------------------------------------
local function ApplyQuad(layer, idx)
  local q = scene.quad[layer] and scene.quad[layer][idx]
  if q == nil then
    funcLuaMenuCommand(C.LAYER_VISIBLE, layer, idx, false)
    funcLuaMenuCommand(C.POS, layer, -4000, 4000, 0, idx)
    return
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, layer, idx, true)
  funcLuaMenuCommand(C.SCALE, layer, q.w / G.Q, q.h / G.Q, 1, idx)
  funcLuaMenuCommand(C.SPRITE, layer, CRC32(q.tex), q.sprite, NODE_QUAD, 0, idx)
  funcLuaMenuCommand(C.POS, layer, q.x, -q.y, 0, idx)
end

local function SetQuad(layer, idx, tex, sprite, x, y, w, h)
  scene.quad[layer] = scene.quad[layer] or {}
  if tex == nil then
    scene.quad[layer][idx] = nil
  else
    scene.quad[layer][idx] = {tex = tex, sprite = type(sprite) == "string" and CRC32(sprite) or sprite, x = x, y = y, w = w, h = h}
  end
  ApplyQuad(layer, idx)
end

local function ApplyText(idx)
  local t = scene.text[idx]
  if t == nil then
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_TEXT, idx, false)
    funcLuaMenuCommand(C.POS, L_TEXT, -4000, 4000, 0, idx)
    return
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_TEXT, idx, true)
  funcLuaMenuCommand(C.TEXT, L_TEXT, NODE_GUIDE, t.s, idx)
  funcLuaMenuCommand(C.SCALE, L_TEXT, t.scale, t.scale, 1, idx)
  funcLuaMenuCommand(C.POS, L_TEXT, t.x, -t.y, 0, idx)
end

-- text instance idx: left edge x, vertical centre y (screen px)
local function SetText(idx, s, x, y, scale)
  scene.text[idx] = s ~= nil and {s = s, x = x, y = y, scale = scale} or nil
  ApplyText(idx)
end

-- ---- cards (owned stickers) ----------------------------------------------------------------------------------------
local function HideCard(idx)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_CARD, idx, false)
  face_wait[idx] = nil
  if idx == PANEL then
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_NEW, 0, false)
  end
end

local function ApplyCard(idx)
  local e = scene.card[idx]
  if e == nil or not e.owned then
    HideCard(idx)
    return
  end
  if not card_ready[idx] then
    return            -- drawn from OnOpenLayer once the card's node names are set
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_CARD, idx, true)
  local s = idx == PANEL and G.PANEL_S or G.CARD_S
  funcLuaMenuCommand(C.SCALE, L_CARD, s, s, 1, idx)
  funcLuaMenuCommand(C.MESH_VISIBLE, L_CARD, CARD_FACE, false, idx)
  -- the exact argument list of the retail seasonal roster cards (players by param id); rarity 4 = 5 stars
  funcLuaMenuCommand(CMD_CARD, L_CARD, idx, e.param, true, false, 0, 0, 5, false, false, 4, 0, false, true, 0, false, true)
  funcLuaMenuCommand(CMD_CARD_APPLY, L_CARD, idx)
  face_wait[idx] = 120
  for _, m in ipairs(CARD_HIDE) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L_CARD, m, false, idx)
  end
  for _, m in ipairs(CARD_LV_MESHES) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L_CARD, m, false, idx)
  end
  for _, prim in ipairs(CARD_LV_PRIMS) do
    funcLuaMenuCommand(C.PRIM_VISIBLE, L_CARD, idx, CRC32(prim), false)
  end
  -- no name on the cards (Nacho, 30/09: it was written over the bottom of the card); the detail shows it
  funcLuaMenuCommand(C.TEXT, L_CARD, CARD_NAME, "", idx)
  funcLuaMenuCommand(C.TEXT_VISIBLE, L_CARD, CARD_NAME, false, idx)
  local t = Tier(e)
  local tex = CRC32(TEX_RARITY)
  funcLuaMenuCommand(C.SPRITE, L_CARD, tex, CRC32(string.format("evt_rogue_card_base_%02d", t)), NODE_BASE, 0, idx)
  funcLuaMenuCommand(C.SPRITE, L_CARD, tex, CRC32(string.format("evt_rogue_card_color_%02d", t)), NODE_COLOR, 0, idx)
  if idx == PANEL and FRONT_MARK then
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_NEW, 0, true)
    funcLuaMenuCommand(C.SCALE, L_NEW, MARK_SCALE_X, MARK_SCALE_Y, 1, 0)
    funcLuaMenuCommand(C.SPRITE, L_NEW, tex, CRC32(string.format("evt_rogue_mark_wide_%02d", t)), NODE_QUAD, 0, 0)
  end
end

local function SetCard(idx, e)
  local old = scene.card[idx]
  scene.card[idx] = e
  if old ~= nil and e ~= nil and old.param == e.param and old.owned == e.owned and old.name == e.name then
    return            -- the same sticker: no new card command (no portrait reload)
  end
  ApplyCard(idx)
end

local function PollFaces()
  for idx, left in pairs(face_wait) do
    if not funcLuaMenuCommand(CMD_LOADING, L_CARD, idx) or left <= 0 then
      funcLuaMenuCommand(C.MESH_VISIBLE, L_CARD, CARD_FACE, true, idx)
      face_wait[idx] = nil
    else
      face_wait[idx] = left - 1
    end
  end
end

-- ---- the book ----------------------------------------------------------------------------------------------------
local function PageX(side)
  return side == 0 and G.LX or G.RX
end

local function SlotXY(k)
  local side = math.floor(k / PER_PAGE)
  local rem = k % PER_PAGE
  local r, c = math.floor(rem / G.COLS), rem % G.COLS
  return PageX(side) + G.SX0 + c * G.SDX, G.ROW0 + r * G.ROW_H + G.SDY
end

local function DrawSlot(k, e)
  local x, y = SlotXY(k)
  if e == nil then
    SetQuad(L_SLOT, k, nil)
    SetText(T_NUM0 + k, nil)
    SetCard(k, nil)
    return
  end
  SetQuad(L_SLOT, k, TEX, e.owned and "evt_album_slot_owned" or "evt_album_slot_missing", x + G.SW / 2, y + G.SH / 2, G.SW, G.SH)
  SetText(T_NUM0 + k, tostring(e.number), x + 6, y + G.STRIP / 2 + 1, G.TXT_S_NUM)
  SetCard(k, e)
end

-- a team emblem on quad `layer` / `inst`: the board atlas sprite, or the team's own texture (loaded on demand, see
-- EMB_S); sprite 0 = the generic crest
local function EmblemQuad(layer, inst, sprite, x, y, w, h)
  local key = layer .. ":" .. inst
  emb_pending[key] = nil
  if sprite == 0 then
    SetQuad(layer, inst, TEX, "evt_album_crest", x, y, w, h)
    return
  end
  local em = EMB_S[sprite]
  if em == nil then
    SetQuad(layer, inst, TEX_EMBLEM, sprite, x, y, w, h)
    return
  end
  local path = EMB_DIR .. em .. "_s.g4tx"
  if not emb_asked[path] then
    emb_asked[path] = true
    funcLuaMenuCommand(C.LOAD_TEX, path)
  end
  if Call(TEX_LOADING, CRC32(path)) == true then
    SetQuad(layer, inst, nil)
    emb_pending[key] = {layer = layer, inst = inst, path = path, sprite = sprite, x = x, y = y, w = w, h = h, frames = 0}
    return
  end
  SetQuad(layer, inst, path, sprite, x, y, w, h)
end

-- Step: put the emblems whose texture came in (a texture that never comes in: the generic crest after 600 frames)
local function PollEmblems()
  for key, q in pairs(emb_pending) do
    q.frames = q.frames + 1
    if Call(TEX_LOADING, CRC32(q.path)) ~= true then
      emb_pending[key] = nil
      SetQuad(q.layer, q.inst, q.path, q.sprite, q.x, q.y, q.w, q.h)
    elseif q.frames > 600 then
      emb_pending[key] = nil
      Log("emblem texture did not load", q.path)
      SetQuad(q.layer, q.inst, TEX, "evt_album_crest", q.x, q.y, q.w, q.h)
    end
  end
end

local function DrawHeader(side, h, row_top, row)
  local px = PageX(side)
  local inst = side * HDR_PER_PAGE + h
  local s = row ~= nil and Section(row.sec) or nil
  emb_pending[L_EMBLEM .. ":" .. inst] = nil
  if s == nil then
    SetQuad(L_PLATE, inst, nil)
    SetQuad(L_EMBLEM, inst, nil)
    SetText(T_HDR0 + 2 * inst, nil)
    SetText(T_HDR0 + 2 * inst + 1, nil)
    return
  end
  SetQuad(L_PLATE, inst, TEX, "evt_album_plate", px + G.PLX + G.PLW / 2, row_top + G.PLY + G.PLH / 2, G.PLW, G.PLH)
  local ex, ey = px + G.EMX, row_top + G.EMY
  if order == 1 then
    SetQuad(L_EMBLEM, inst, TEX_RARITY, string.format("evt_rogue_mark_%02d", math.max(1, math.min(5, s.key))), ex, ey, 76, 48)
  elseif TEAM_ORDERS[order] and s.emblem ~= 0 then
    EmblemQuad(L_EMBLEM, inst, s.emblem, ex, ey, G.EMS, G.EMS)
  else
    SetQuad(L_EMBLEM, inst, TEX, "evt_album_crest", ex, ey, G.EMS, G.EMS)
  end
  local title = s.title     -- no «(sigue)» (2026-09-28): the loader never sends `cont` any more
  SetText(T_HDR0 + 2 * inst, title, px + G.HNX, row_top + G.HTY, G.TXT_S_HDR)
  local count = s.b ~= nil and string.format("%d/%d", s.a, s.b) or tostring(s.a)
  SetText(T_HDR0 + 2 * inst + 1, count, px + G.HCX, row_top + G.HTY, G.TXT_S_CNT)
end

-- one page of the spread (side 0 left, 1 right); page index past the end = a blank page
local function DrawSide(side)
  local p = 2 * spread + side
  local rows = PageRows(p)
  local h = 0
  for r = 0, G.ROWS - 1 do
    local row = rows and rows[r] or nil
    local row_top = G.ROW0 + r * G.ROW_H
    for c = 0, G.COLS - 1 do
      local k = side * PER_PAGE + r * G.COLS + c
      local e = nil
      slot_pos[k] = nil
      if row ~= nil and row.kind == 2 and c < row.n then
        slot_pos[k] = row.first + c
        e = Entry(row.first + c)
      end
      DrawSlot(k, e)
    end
    if row ~= nil and row.kind == 1 and h < HDR_PER_PAGE then
      DrawHeader(side, h, row_top, row)
      h = h + 1
    end
  end
  for k = h, HDR_PER_PAGE - 1 do
    DrawHeader(side, k, 0, nil)
  end
  if rows ~= nil then
    SetText(T_PAGE0 + side, tostring(p + 1), PageX(side) + G.PW / 2 - 8 * #tostring(p + 1) * G.TXT_S_PAGE, G.PNY, G.TXT_S_PAGE)
  else
    SetText(T_PAGE0 + side, nil)
  end
end

local function SlotOf(pos)
  for k = 0, N_SLOTS - 1 do
    if slot_pos[k] == pos then
      return k
    end
  end
  return nil
end

local function ShowGlow()
  local k = SlotOf(sel)
  if k == nil or flip ~= nil then
    SetQuad(L_OVER, OVER_GLOW, nil)
    return
  end
  local x, y = SlotXY(k)          -- the selection frame surrounds the card (below the number tab)
  SetQuad(L_OVER, OVER_GLOW, TEX, "evt_album_glow", x + G.SW / 2, y + G.STRIP + (G.SH - G.STRIP) / 2, G.GLOW_W, G.GLOW_H)
end

local function SectionTitle(pos)
  if pos < 0 then
    return nil
  end
  local p, row = Call(RL.ALBUM, 10, order, pos)
  local rows = PageRows(Int(p))
  if rows == nil then
    return nil
  end
  local rr = rows[Int(row)]
  return rr and Section(rr.sec) or nil
end

local function UpdateGuideLine()
  local t
  if not has_loader then
    t = T(TXT.no_loader)
  else
    -- only «Álbum: N / total (x %)» (Nacho, 30/09): no current team, no order (the headers show both)
    t = F(T(TXT.guide), book.owned, book.total, Pct(book.owned, book.total))
  end
  funcLuaMenuCommand(C.TEXT, L_GUIDE_LINE, NODE_GUIDE, t, 0)
end

local function UpdateButtonGuide()
  local texts, icons, offs, cmds = {G_SORT, G_PAGE}, {I_FUNC2, I_R1}, {0, 0}, {K_FUNC2, K_R1}
  if TEAM_ORDERS[order] then
    texts[#texts + 1], icons[#icons + 1], offs[#offs + 1], cmds[#cmds + 1] = G_TEAM, I_R2, 0, K_R2
  end
  funcLuaMenuCommand(C.GUIDE_SET, MENU, L_BTN_GUIDE, texts, icons, offs, {}, {})
  funcLuaMenuCommand(C.GUIDE_CMD, MENU, L_BTN_GUIDE, cmds)
  funcLuaMenuCommand(C.GUIDE_OPT, MENU, L_BTN_GUIDE, false)
end

-- ---- info card (right of the book): the selected sticker, updated as the cursor moves ----------------------------
-- 2026-10-06: the old Aceptar popup laid out vertically; 2026-10-07 (Nacho, rounds 1-4) it is one more PAGE of the
-- album (evt_album_info: paper, frame lines and bolts on the navy cloth; the emblem boxes and data boxes printed in,
-- rounded rectangles of the page's corner radius). Layers on top: the NAME banner (the retail-style slanted rarity
-- banner evt_rogue_banner_NN, «Nº N  Name» on it), the card (team00_01 instance PANEL at the _atc_evt_album_card
-- locator, left) + its N★ mark, or the «?» card of a missing one; right of the card a 2 x 2 grid (round 5):
-- element icon | position badge (black outlines under them on evt_album_plate 8 / 9), the card's own club crest
-- (op 4 value 15, album_data MEMBER_CLUBS) | the album number box. The banner shows only the name, centred. Data boxes (label on top, value below in a bigger font, centred): row 1
-- Coste / Partidas jugadas / Goles marcados (op 4 value 16), row 2 Obtención (date) / Origen (op 4 value 17).
local function InfoText(i, s, dx, dy, scale)
  SetText(T_INFO0 + i, s, G.IX + dx, G.IY + dy, scale)
end

local function InfoQuad(inst, tex, sprite, dx, dy, w, h)
  if tex == nil then
    SetQuad(L_INFO, inst, nil)
    return
  end
  SetQuad(L_INFO, inst, tex, sprite, G.IX + dx, G.IY + dy, w, h)
end

-- estimated width (px) of `s` at text scale `scale`: the text layer is left-aligned, the data boxes centre their
-- texts (latin ~0.56 em, wide CJK glyphs 1 em; TXT_EM px per scale unit)
local function TextW(s, scale)
  local w = 0
  for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    w = w + (#ch >= 3 and 1.0 or 0.56)
  end
  return w * G.TXT_EM * scale
end

-- centred text instance: (cx, cy) relative to IX / IY
local function InfoTextC(i, s, cx, cy, scale)
  InfoText(i, s, cx - TextW(s, scale) / 2, cy, scale)
end

-- «Coste: {1}» -> «Coste» (the label of a data box: the format without its value and separator)
local function Label(t)
  return (T(t):gsub("%s*[:：]?%s*{1}%s*", ""))
end

-- a data box: label on top, value below (bigger), centred on (cx, cy)
local function Box(il, iv, label, value, cx, cy, vscale)
  InfoTextC(il, label, cx, cy + G.I_LBL_DY, G.TXT_S_ILBL)
  InfoTextC(iv, value, cx, cy + G.I_NUM_DY, vscale)
end

local function FillInfo()
  local e = Current()
  SetQuad(L_INFO_BG, 0, TEX, "evt_album_info", G.IX + G.IW / 2, G.IY + G.IH / 2, G.IW, G.IH)
  for k = 0, N_INFO_TEXT - 1 do
    SetText(T_INFO0 + k, nil)
  end
  -- round 5: 2 x 2 grid right of the card: element | position, club | album number
  local at = {{G.I_GX1, G.I_GY1}, {G.I_GX2, G.I_GY1}, {G.I_GX1, G.I_GY2}}     -- element, position, club
  local ol = 2 * G.I_OL
  SetQuad(L_PLATE, PLATE_OL_ELEM, nil)
  SetQuad(L_PLATE, PLATE_OL_POS, nil)
  local function Unknown(inst, k)
    emb_pending[L_INFO .. ":" .. inst] = nil
    InfoQuad(inst, TEX, "evt_album_unknown", at[k][1], at[k][2], G.I_UNK_S, G.I_UNK_S)
  end
  local function Missing(on)          -- the «?» card at the card's footprint
    if on then
      InfoQuad(INFO_MISSING, TEX, "evt_album_card_missing", G.I_CARD_X, G.I_CARD_Y, G.CARD_W * G.PANEL_S, G.CARD_H * G.PANEL_S)
    else
      InfoQuad(INFO_MISSING, nil)
    end
  end
  local tier = e ~= nil and Tier(e) or 1
  InfoQuad(INFO_BANNER, TEX_RARITY, string.format("evt_rogue_banner_%02d", tier), G.IW / 2, G.I_NAME_Y, G.I_NAME_W, G.I_NAME_H)
  local c = G.IW / 2
  local function Boxes(cost, runs, goals, date, src)
    Box(I.COST, I.COST_N, Label(TXT.cost), cost, c - G.I_R1_DX, G.I_ROW_Y, G.TXT_S_INUM)
    Box(I.GAMES, I.GAMES_N, Label(TXT.games), runs, c, G.I_ROW_Y, G.TXT_S_INUM)
    Box(I.GOALS, I.GOALS_N, Label(TXT.goals), goals, c + G.I_R1_DX, G.I_ROW_Y, G.TXT_S_INUM)
    Box(I.GOT, I.GOT_N, T(TXT.obtained), date, c - G.I_R2_DX, G.I_ROW2_Y, G.TXT_S_IVAL)
    Box(I.SRC, I.SRC_N, T(TXT.source), src, c + G.I_R2_DX, G.I_ROW2_Y, G.TXT_S_IVAL)
  end
  -- the album number (known for missing cards too: the sticker slot shows it)
  Box(I.NUM, I.NUM_N, Label(TXT.number), e ~= nil and tostring(e.number) or "?", G.I_GX2, G.I_GY2, G.TXT_S_INUM)
  if e == nil or not e.owned then
    InfoTextC(I.TITLE, UNKNOWN, G.IW / 2, G.I_NAME_Y, G.TXT_S_ITITLE)
    Missing(true)
    Unknown(INFO_ELEM, 1)
    Unknown(INFO_POS, 2)
    Unknown(INFO_CLUB, 3)
    Boxes("?", "?", "?", "?", "?")
    SetCard(PANEL, nil)
    return
  end
  InfoTextC(I.TITLE, e.name, G.IW / 2, G.I_NAME_Y, G.TXT_S_ITITLE)   -- only the name, centred (round 5)
  local ps, es = POS_SPRITE[e.position], ELEM_SPRITE[e.element]
  if es ~= nil then
    SetQuad(L_PLATE, PLATE_OL_ELEM, TEX, "evt_album_ol_elem", G.IX + at[1][1], G.IY + at[1][2], G.I_ELEM_S + ol, G.I_ELEM_S + ol)
    InfoQuad(INFO_ELEM, TEX_ICON, es, at[1][1], at[1][2], G.I_ELEM_S, G.I_ELEM_S)
  else
    Unknown(INFO_ELEM, 1)
  end
  if ps ~= nil then
    SetQuad(L_PLATE, PLATE_OL_POS, TEX, "evt_album_ol_pos", G.IX + at[2][1], G.IY + at[2][2], G.I_POS_W + ol, G.I_POS_H + ol)
    InfoQuad(INFO_POS, TEX_POS, ps, at[2][1], at[2][2], G.I_POS_W, G.I_POS_H)
  else
    Unknown(INFO_POS, 2)
  end
  EmblemQuad(L_INFO, INFO_CLUB, e.club, G.IX + at[3][1], G.IY + at[3][2], G.I_CLUB_S, G.I_CLUB_S)
  local src = TXT.src[e.source]
  Boxes(tostring(e.cost), tostring(e.runs), tostring(e.goals), DateText(e.added), src ~= nil and T(src) or "-")
  Missing(false)
  SetCard(PANEL, e)
end

local function DrawBook()
  SetQuad(L_BOOK, 0, TEX, "evt_album_book", G.BX + G.BW / 2, G.BY + G.BH / 2, G.BW, G.BH)
  DrawSide(0)
  DrawSide(1)
  ShowGlow()
  UpdateGuideLine()
  FillInfo()
end

-- the spread of list position pos
local function SpreadOf(pos)
  local p = Int((Call(RL.ALBUM, 10, order, pos)))
  return math.max(0, math.floor(p / 2))
end

-- ---- navigation ----------------------------------------------------------------------------------------------------
local function Select(pos, sound)
  if pos == nil or pos < 0 or pos >= book.count then
    return
  end
  sel = pos
  if sound then
    funcLuaCommand(C.SE, SE_OK)
  end
  ShowGlow()
  UpdateGuideLine()
  FillInfo()
end

-- page turn to spread `target` (dir +1 forward / -1 back), then select `pos`
local function TurnTo(target, pos)
  local last = math.max(0, math.floor((book.pages - 1) / 2))
  target = math.max(0, math.min(last, target))
  if target == spread then
    Select(pos, true)
    return
  end
  local dir = target > spread and 1 or -1
  spread = target
  flip = {frame = 0, dir = dir, sel = pos}
  funcLuaCommand(C.SE, SE_PAGE)
  -- the page under the lifting leaf is drawn at once (forward: the new right page; back: the new left page)
  DrawSide(dir > 0 and 1 or 0)
  ShowGlow()
end

local function FlipStep()
  local fl = flip
  fl.frame = fl.frame + 1
  local t = fl.frame / G.FLIP_FRAMES
  if t >= 1 then
    SetQuad(L_LEAF, 0, nil)
    SetQuad(L_OVER, OVER_SHADOW, nil)
    flip = nil
    DrawSide(fl.dir > 0 and 0 or 1)    -- the leaf has landed: the other page shows the new spread too
    sel = -1
    Select(fl.sel, false)
    return
  end
  local f = math.cos(t * math.pi)       -- 1 -> -1: the leaf narrows to the spine, then opens on the other side
  local w = math.max(2, G.PW * math.abs(f))
  local lift = 10 * math.sin(t * math.pi)
  local on_start = f > 0                -- still over the page it left
  local right = (fl.dir > 0) == on_start
  local x = right and (G.SPINE + w / 2) or (G.SPINE - w / 2)
  SetQuad(L_LEAF, 0, TEX, right and "evt_album_leaf_r" or "evt_album_leaf_l", x, G.PY + G.PH / 2, w, G.PH + 2 * lift)
  local sw = 90 * math.sin(t * math.pi)
  if sw > 2 then
    if right then
      SetQuad(L_OVER, OVER_SHADOW, TEX, "evt_album_shadow", G.SPINE + w + sw / 2, G.PY + G.PH / 2, sw, G.PH)
    else
      SetQuad(L_OVER, OVER_SHADOW, TEX, "evt_album_shadow_l", G.SPINE - w - sw / 2, G.PY + G.PH / 2, sw, G.PH)
    end
  else
    SetQuad(L_OVER, OVER_SHADOW, nil)
  end
end

local function FirstOnSpread(s)
  for side = 0, 1 do
    local rows = PageRows(2 * s + side)
    if rows ~= nil then
      for r = 0, G.ROWS - 1 do
        if rows[r].kind == 2 then
          return rows[r].first
        end
      end
    end
  end
  return -1
end

local function MoveBy(delta)
  if book.count == 0 or sel < 0 then
    return
  end
  local new = sel + delta
  if new < 0 or new >= book.count then
    return
  end
  local s = SpreadOf(new)
  if s ~= spread then
    TurnTo(s, new)
  else
    Select(new, true)
  end
end

-- up / down: the same column, previous / next sticker row of the same page
local function MoveVert(dir)
  local k = SlotOf(sel)
  if k == nil then
    return
  end
  local side = math.floor(k / PER_PAGE)
  local r, c = math.floor((k % PER_PAGE) / G.COLS), k % G.COLS
  r = r + dir
  while r >= 0 and r < G.ROWS do
    local best = nil
    for cc = c, 0, -1 do         -- the same column, else the nearest one to its left (short rows)
      local pos = slot_pos[side * PER_PAGE + r * G.COLS + cc]
      if pos ~= nil then
        best = pos
        break
      end
    end
    if best ~= nil then
      Select(best, true)
      return
    end
    r = r + dir
  end
end

local function Page(dir)
  if book.count == 0 then
    return
  end
  local last = math.max(0, math.floor((book.pages - 1) / 2))
  local target = math.max(0, math.min(last, spread + dir))
  if target == spread then
    return
  end
  TurnTo(target, FirstOnSpread(target))
end

local function Group(dir)
  if book.count == 0 or sel < 0 then
    return
  end
  local j = Call(RL.ALBUM, 5, sel, order, dir)
  if type(j) ~= "number" then
    return
  end
  j = math.max(0, math.min(book.count - 1, Int(j)))
  if j == sel then
    return
  end
  TurnTo(SpreadOf(j), j)
end

local function Sort()
  local cur = Current()
  local at = 1
  for k, o in ipairs(SORT_CYCLE) do
    if o == order then
      at = k
    end
  end
  order = SORT_CYCLE[at % #SORT_CYCLE + 1]
  Log("album order", order)
  funcLuaCommand(C.SE, SE_OK)
  ReadBook()
  sel = book.count > 0 and 0 or -1
  if cur ~= nil and book.count > 0 then
    local k = Call(RL.ALBUM, 6, cur.param, order)
    if type(k) == "number" and k >= 0 and k < book.count then
      sel = Int(k)
    end
  end
  spread = sel >= 0 and SpreadOf(sel) or 0
  DrawBook()
  UpdateButtonGuide()
end

-- ---- closing ------------------------------------------------------------------------------------------------------
local function Close(result)
  closing = true
  funcLuaCommand(C.P_CLEAR, KEY_RESULT)
  funcLuaCommand(C.P_SET, KEY_RESULT, 0, result, 1)
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
  funcLuaCommand(C.CLOSE_MENU, MENU)
end

local function OpenBookLayers()
  for layer, n in pairs(BOOK_LAYERS) do
    for i = 0, n - 1 do
      funcLuaMenuCommand(C.OPEN_LAYER, layer, i)
    end
  end
end

-- ---- engine callbacks -----------------------------------------------------------------------------------------
function OnInit()
  funcLuaCommand(C.P_CLEAR, KEY_RESULT)
  funcLuaMenuCommand(C.LOAD_TEX, TEX)
  funcLuaMenuCommand(C.LOAD_TEX, TEX_RARITY)
  funcLuaMenuCommand(C.LOAD_TEX, TEX_EMBLEM)
  funcLuaMenuCommand(C.LOAD_TEX, TEX_POS)
  funcLuaMenuCommand(C.LOAD_TEX, TEX_ICON)
  order, spread, sel, flip = 0, 0, -1, nil
  closing, ready = false, false
  open_guard = 20
  ReadBook()
  if book.count > 0 then
    sel = 0
  end
  Log("open", has_loader, "pages", book.pages, "cards", book.count, "owned", book.owned, "of", book.total)
end

function OnSetupLayer(a1, a2)
  if a1 == L_HEADER then
    SetupSoccerTopCommonHeaderLayerInfo(a1, 4153539961, 253801632, 3969848060, 1144161661, 3293713115, 253801632, 1152304044, 305955024, 3007971317)
    SwapSoccerTopCommonHeaderMenuModeIconTexture(1566262113 --[[mode_base02, as the INAROGUE menu]])
    UpdateHeader(3586861540)
    funcLuaMenuCommand(C.SPRITE, a1, 3139293835 --[[#/menu/220_img/evt_rogue/evt_rogue_mode.g4tx]], 2610480106 --[[evt_rogue_mode_plate: INAROGUE's phoenix plate]], 3293713115 --[[header node mode_base01]], 0, 0)
    funcLuaMenuCommand(C.TEXT, a1, 1220590795 --[[_text_sub_title02]], T(TXT.title))
    OpenBookLayers()
  elseif a1 == L_ROW then
    funcLuaMenuCommand(C.TEXT, a1, 931545948 --[[_text_list01_on]], "", a2)
    funcLuaMenuCommand(C.TEXT, a1, 3705682548 --[[_text_list01_off]], "", a2)
    funcLuaMenuCommand(C.TEXT_VISIBLE, a1, 931545948, false, a2)
    funcLuaMenuCommand(C.TEXT_VISIBLE, a1, 3705682548, false, a2)
    for _, m in ipairs(ROW_MESHES) do
      funcLuaMenuCommand(C.MESH_VISIBLE, a1, m, false, a2)
    end
    funcLuaMenuCommand(C.ATTACH_TRACE, a1, a2, CUR, false)
  elseif a1 == L_WINBASE then
    funcLuaMenuCommand(C.MESH_VISIBLE, a1, N_ARROW, false, 0)
    funcLuaMenuCommand(C.ATTACH_TRACE, a1, 0, WIN_LABEL, true)
    funcLuaMenuCommand(C.ATTACH_TRACE, a1, 0, CARD_LABEL, true)
    funcLuaMenuCommand(C.ATTACH_TRACE, a1, 0, MARK_LABEL, true)
    for k = 1, N_SLOTS do
      funcLuaMenuCommand(C.ATTACH_TRACE, a1, 0, CRC32(string.format("evt_rogue_album_grid%02d", k)), true)
    end
    funcLuaMenuCommand(C.OPEN_LAYER, L_WIN, 0)
    funcLuaMenuCommand(C.OPEN_LAYER, L_NEW, 0)
    for k = 0, N_SLOTS do
      funcLuaMenuCommand(C.OPEN_LAYER, L_CARD, k)
    end
  elseif a1 == L_WIN and a2 == 0 then
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_WIN, 0, false)
  elseif a1 == L_NEW then
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
  elseif a1 == L_CARD then
    if scene.card[a2] == nil then
      funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    end
  elseif a1 == L_TEXT then
    ApplyText(a2)
  elseif BOOK_LAYERS[a1] ~= nil then
    ApplyQuad(a1, a2)
  elseif a1 == L_GUIDE_LINE then
    UpdateGuideLine()
  end
end

function OnOpenLayer(a1, a2)
  if a1 == L_ROW and a2 == 0 then
    funcLuaMenuCommand(C.OPEN_LAYER, L_CURSOR, 0)
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_CURSOR, 0, false)
    funcLuaMenuCommand(C.FOCUS_ENABLE, a1, true)
    funcLuaMenuCommand(C.LIST_NUM, a1, 1)
    funcLuaMenuCommand(C.FOCUS_SET, a1, 0)
    funcLuaMenuCommand(C.ATTACH_TRACE, a1, 0, CUR, false)
    funcLuaMenuCommand(C.POS, a1, -4000, 4000, 0, 0)   -- the anchor never shows (off screen, meshes hidden)
    spread = sel >= 0 and SpreadOf(sel) or 0
    DrawBook()
    UpdateButtonGuide()
    Ptr.Reset()
    ready = true
    if funcLuaCommand(C.FADE_DONE) then
      funcLuaCommand(C.FADE, 0, 0.3)
    end
  elseif a1 == L_CARD then
    NameSetting_CharaCardForSoccer(a1, a2)
    funcLuaMenuCommand(C.ATTACH_TRACE, a1, a2, CARD_CURSOR, false)
    funcLuaMenuCommand(C.ATTACH_TRACE, a1, a2, CARD_CURSOR2, false)
    card_ready[a2] = true
    ApplyCard(a2)
  elseif a1 == L_CURSOR then
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
  elseif a1 == L_TEXT then
    ApplyText(a2)
  elseif BOOK_LAYERS[a1] ~= nil then
    ApplyQuad(a1, a2)
  elseif a1 == L_GUIDE_LINE then
    UpdateGuideLine()
  end
end

function OnChangeFocus(a1, a2)
end

function OnDecideFocus(a1, a2)
end         -- Enter: nothing (the info card follows the cursor; 2026-10-06 the Aceptar popup is gone)

-- MENU_CMD_INFO CMD_FUNCTION ids of the anchor row (rogue_album_book_build.py ROW_FUNCTIONS); OnFunction(id, layer),
-- both argument orders accepted (lua.md)
local FN_SET = {}
for _, v in pairs(FN) do
  FN_SET[v] = true
end

function OnFunction(a1, a2)
  if not ready then
    return 1
  end
  local id = FN_SET[a1] and a1 or a2
  if not FN_SET[id] then
    return
  end
  if flip ~= nil then
    return 1                      -- a page is turning
  end
  if id == FN.UP then
    MoveVert(-1)
  elseif id == FN.DOWN then
    MoveVert(1)
  elseif id == FN.LEFT then
    MoveBy(-1)
  elseif id == FN.RIGHT then
    MoveBy(1)
  elseif id == FN.PAGE_PREV then
    Page(-1)
  elseif id == FN.PAGE_NEXT then
    Page(1)
  elseif id == FN.TEAM_PREV then
    Group(-1)
  elseif id == FN.TEAM_NEXT then
    Group(1)
  elseif id == FN.SORT then
    Sort()
  end
  return 1
end

function OnEnter(a1, a2)
  if a1 == L_BTN or a1 == L_RET then
    return 1
  end
end

function OnBack(a1)
  if not ready or open_guard > 0 then
    return 1                      -- the opening input (see open_guard)
  end
  funcLuaCommand(C.SE, SE_BACK)
  Close(0)
  return 1
end

-- pointer zones from the drawn spread: every filled slot, and the outer page edges (turn the page)
local function PollPointer()
  Ptr.Begin()
  Ptr.Rect(G.BX, G.PY, G.LX + G.SX0 - G.BX - 8, G.PH, "prev")
  local rx = PageX(1) + G.SX0 + (G.COLS - 1) * G.SDX + G.SW + 8
  Ptr.Rect(rx, G.PY, G.BX + G.BW - rx, G.PH, "next")
  for k = 0, N_SLOTS - 1 do
    if slot_pos[k] ~= nil then
      local x, y = SlotXY(k)
      Ptr.Rect(x, y, G.SW, G.SH, k)
    end
  end
  local ev = Ptr.Poll()
  if flip ~= nil or closing or not ready or open_guard > 0 then
    return
  end
  if type(ev.hot) == "number" and ev.changed and slot_pos[ev.hot] ~= nil and slot_pos[ev.hot] ~= sel then
    Select(slot_pos[ev.hot], true)
  end
  if ev.click == "prev" or ev.wheel == -1 then
    Page(-1)
  elseif ev.click == "next" or ev.wheel == 1 then
    Page(1)
  end
end

local step_error_logged = false

local function StepPoll(fn)
  local ok, err = pcall(fn)
  if not ok and not step_error_logged then
    step_error_logged = true
    Log("step error", tostring(err))
  end
end

function Step()
  -- the open guard counts down first: a failing poll must never keep Back swallowed
  if ready and open_guard > 0 then
    open_guard = open_guard - 1
  end
  StepPoll(PollFaces)
  StepPoll(PollEmblems)
  if ready then
    StepPoll(PollPointer)
  end
  if flip ~= nil and not closing then
    FlipStep()
  elseif ready and sel >= 0 then
    glow_t = (glow_t + 1) % 60
    local k = SlotOf(sel)
    if k ~= nil then
      local s = 1 + 0.03 * math.sin(glow_t * math.pi / 30)
      funcLuaMenuCommand(C.SCALE, L_OVER, G.GLOW_W * s / G.Q, G.GLOW_H * s / G.Q, 1, OVER_GLOW)
    end
  end
end
