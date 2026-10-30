-- vrfw_contact_map_menu (plain Lua 5.2 source): the VR-Framework's CONTACT MAP screen (graft contact_map, mod
-- vr_framework; declared in the framework's menus\contact_map.toml, served as common/script/lua/menu/
-- vrfw_contact_map_menu.lua.bin).
-- The IE-style "contacts" / scout map of a [[VRFW.ContactSet]] a mod declares (content\contact_maps\*.toml, served by
-- the framework's script scripts\contact_map.lua through CMND_VRFW_CONTACT_*). Screens of one set:
--   list     the set's maps (rows: title, signed / players); Accept opens one
--   zones    a map's background with its zone pins (a pin = the zone's first player still to sign); Accept: the zone
--   grid     a zone's / section's players: a grid of faces (8 x 3 a page) over the zone's own map when it declares
--            one (GO / CS / Galaxy: the free walk's 3DS area map page); Accept: sign the player
--   network  a Connection Map: the tiles where the original had them, linked as in the original; STRICT order (IE): a
--            tile OPENS when a linked tile is acquired; a player tile is acquired once signed, a gate tile (a player
--            signed elsewhere) once he is in the club, the start and "open" tiles by themselves; a tile not open shows
--            the "?" plate. A network may be declared `Strict = false` (every tile open, no order) and cut into
--            pages (its Zones, each node on one): one page is drawn at a time, LB / RB turn it
--   shop     the items the zone / map's players ask for, for sale (FUNC2 / X "Items")
-- Plate colours as in IE: green = can be signed now, grey = terms not met, red = signed, "?" = not open yet; a red badge
-- on a plate = one of its requirements is not met. The card shows each requirement as an icon with a met / unmet badge
-- (VRFW_Recruit kinds: player, item, team level, players of an element / position in the club, matches won, goals).
-- A player costs the set's recruit currency (e.g. friendship points), an item its item currency (e.g. passion
-- points). Signing: VRFW_Recruit.Recruit (requirements, price, the game's add-character path, autosave). Record per
-- save slot: key "contact.<map key>" of owner "vr_framework" = the signed node numbers ("3,17,40").
-- Opened as a child: parameter crc32("vrfw_contact_set") = crc32 of the set's key ("<mod>.<name>") before
-- CMND_OPEN_MENU_OBJECT(crc32("vrfw_contact_map_menu")). Texts: the framework's menu_text rows
-- (text\rows\contact_map.toml) and the mod's own rows the declarations name; never literals.
-- Rule: no engine call at top level; funcLuaCommand only exists inside callbacks.
INCLUDE("LUA_PROG_BASE")
INCLUDE("LUA_SAVEDATA_MANAGEMENT_MENU_INC")   -- header helpers (soccer top inc) + general window inc
INCLUDE("LUA_SOCCER_COMMON")                  -- the panel's status plate (UpdateCharaStatusPlateInfoByCharaParamId)
INCLUDE("LUA_SOCCER_FORMATION_MENU_INC")      -- a team page's lineup: the team dock's cards (UpdateMemberCharaIconInfoByChrParamId)

local MENU = 1355292071           -- crc32("vrfw_contact_map_menu")
local KEY_SET = 1128821923        -- crc32("vrfw_contact_set"): parameter in, the set
local KEY_RESULT = 1506951015     -- crc32("vrfw_contact_pick"): parameter out (0: nothing to report)
local KEY_PARENT = 2740862541     -- crc32("vrfw_contact_parent"): optional parameter in, the menu under the screen
-- crc32("vrfw_contact_game") (3811836272): optional parameter in, a match: the screen opens straight on its team page
-- (a hub's choice, e.g. the free-match list as the office) and Back on it closes the screen
local OWNER = "vr_framework"

-- texts: menu_text rows crc32("vrfw_cm_<name>") of the framework (text\rows\contact_map.toml)
local T = {
  REQ_SIGN = 2161724870, REQ_GET = 2154068131,   -- vrfw_cm_req_sign "Sign %s" / vrfw_cm_req_get "Get %s"
  SHOP_BTN = 3501672787, COUNT = 3593287085, LEVEL_PRICE = 3823326167, REQ_PLAYER = 14895046, REQ_ITEM = 12384550,
  NO_REQ = 1749383623, STATE_READY = 435451300, STATE_MISSING = 2934530415, STATE_DONE = 525534213,
  STATE_LOCKED = 2100392169, GATE = 4291389286, GATE_DONE = 4040265050, OPEN_TILE = 919875809, START = 3431801920,
  ASK = 940992270, JOINED = 1584734803, NEED_PRICE = 3071106297, NEED_REQS = 2477148030, BANK_FULL = 3014680302,
  OWNED = 1749033698, FAILED = 2500036647, SHOP_ROW = 30181753, SHOP_ASK = 3990525250, SHOP_BOUGHT = 3271124074,
  SHOP_EMPTY = 877398782, BAG_FULL = 2728655910, ZONE_HINT = 1603344950, UNKNOWN = 3326508568,
  -- the special requirements: vrfw_cm_req_team_level / _elem / _wins / _goals, the element / position labels
  REQ_TEAM_LEVEL = 1040602938, REQ_ELEM = 1482667094, REQ_WINS = 3179220225, REQ_GOALS = 4013490541,
  REQ_BEAT = 3395213988,                           -- vrfw_cm_req_beat "Beat %s" (a team page: a match against that team won)
  TEAMS_NONE = 239112625,
  SOLD_AT = 1992691150,                            -- vrfw_cm_sold_at "Signed on: %s" (a team page's ghost)                          -- vrfw_cm_teams_none (a map of team pages with none open yet)
  GO = 2207531302, CLOSE = 1089859595,             -- vrfw_cm_go «Go» / vrfw_cm_close «Close» (a ghost's window buttons)
  GO_HINT = 4001254672,                            -- vrfw_cm_go_hint (a ghost's card: Accept opens his home page)
  REQ_PAY = 2211476719,                           -- vrfw_cm_req_pay "x%d (%d)" (the price, owned; after the spirit's name)
  REQ_TITLE = 53176105,                            -- vrfw_cm_req_title "Requirements" (the requirement card's header)
  REQ_COUNT = 2915326752,                          -- vrfw_cm_req_count "%s / %d" (a plate's have / need, the header's met / all)
  -- a plate's name of a counted requirement (its numbers are the plate's have / need): vrfw_cm_req_*_short
  REQ_SHORT = {team_level = 559733864, element = 3410057724, position = 3410057724, wins = 3355883171,
               goals = 2743560636},
  -- team pages: a player at a level, the harder clears, the trials, «Dimitir» (vrfw_cm_* rows)
  REQ_PLAYER_LEVEL = 4185569193, REQ_BEAT_MORE = 1292820146,
  TRIAL = {1082028622, 3363525476, 2492399005},   -- vrfw_cm_trial_hold / _goals / _steals (by the objective's kind)
  TRIAL_BTN = 3837556680, TRIAL_ASK = 3654396889, TRIAL_FAIL = 3650311168, TRIAL_PASSED = 2195445266,
  RELEASE_BTN = 1399328150, RELEASE_Q = 3291638255, RELEASE_DONE = 3288151915, RELEASE_FAIL = 1442315401,
  RELEASE_BUSY = 474644034,
  ELEM = {2663092405, 129155343, 1890972057, 4006700090, 2580960428}, POS = {889919200, 2885830490, 3674568652, 1164042863},
  VIEW_MARK = 2320547439,                          -- vrfw_reveal_all_mark "VIEW MODE" (config [debug] reveal_all)
  STORY_ONLY = 3991482902,                         -- vrfw_cm_story_only "Signed in story mode" (a StoryOnly node)                               -- vrfw_cm_page "Page %d / %d" (a network's pages)
}
local MARK_ON, MARK_OFF = "[$gaiji_check01_on] ", "[$gaiji_check01_off] "   -- the office's requirement marks

-- ---- layers ---------------------------------------------------------------------------------------------------------
local L_ROW = 3455690937        -- save01_02_list_item (1 instance: the input anchor, off screen)
local L_HEADER = 575058101      -- mainmenu90_01_header
local L_GUIDE_LINE = 3078308064 -- mainmenu90_05_content_guide_line01
local L_CURSOR = 2296367164     -- cmn05_01_cursor (hidden: the ring is the cursor)
local L_BTN_GUIDE = 1138543975  -- mainmenu01_06_base_button_guide
local L_BTN = 9396745           -- mainmenu01_07_button_guide
local L_RET = 2005383485        -- mainmenu01_10_return_arrow_button_guide
local L_RETAIL_BG = 367379312   -- mainmenu90_00_background (DrawBack: shown only when nothing else is the background)
local L_BACK = 707542725        -- vrfw_cm_back    x1   (450) the background a mod declares (art role "background")
local L_ZONEART = 1849226512       -- vrfw_cm_zoneart x1   (451) a zone's own map (GO / CS / Galaxy 3DS area map)
local L_LINE = 2532723460       -- vrfw_cm_line    x210 (453) links
local L_TILE = 829249270        -- vrfw_cm_tile    x200 (455) plates / pins / list rows (mouse hit areas)
local L_FACE = 1123452053       -- vrfw_cm_face    x60  (457) faces
local L_TAG = 1404648045        -- vrfw_cm_tag     x70  (458) check / padlock badges, card borders
local L_UI = 302224576          -- vrfw_cm_ui      x8   (459) 0 ring, 1-2 page arrows
local L_CARD = 1375102753       -- vrfw_cm_card    x1   (459) the old info card (redesign: unused, hidden)
local L_PANEL = 4049183424      -- vrfw_cm_panel   x2   (452, background pass) 0 the player panel's ground, 1 its fade
local L_MODEL = 2220950294      -- vrfw_cm_model   x1   (452) the panel's 3D player model (shop01_01_list_base's)
local L_SHADOW = 858725131      -- mainmenu01_08_chara_3d_shadow (the model's shadow, as the retail shop)
local L_STATUS = 561386529      -- soccer11_04_chara_stasus (the retail shop's status plate): its description box only
-- (the player's header as the green ROW of the team screens, not the shop's two-row block): the
-- team screens' header plate (retail soccer11_04pp_chara_status_info; a mod may patch it to a one-row
-- header + PE everywhere, this screen included) over a slanted, position-coloured band (a soccer11_04 plate showing
-- only its two plate sprites, as the player page's evt_pp_slant)
local L_PPROW = 1844915256      -- soccer11_04_formation_chara_status (team_dock_menu's header plate)
local L_SLANT = 3210151533      -- vrfw_cm_slant (soccer11_04_universe_chara_stasus: the band only)
local L_ICON = 578213417        -- vrfw_cm_icon    x1   (461) the card's face
local L_TITLE = 2025982372      -- vrfw_cm_title   x10  (551) list rows' text
local L_CARDTXT = 1541069194    -- vrfw_cm_cardtxt x4   (551) the card's lines
local L_REQ = 3347854986        -- vrfw_cm_req     x5   (462) the card's row icons (4 requirements + the price's coin)
local L_REQOK = 1997209491      -- vrfw_cm_reqok   x4   (463) their met / unmet badges
-- vrfw_cm_req also holds 7-10 the plates' bar fills; the plate layers are fields of
-- INFO.PLATES (L_PLATE vrfw_cm_reqplate x5 (456): 4 plates + the header's counter chip; L_BAR vrfw_cm_reqbar x4
-- (460): the bar tracks) - the main chunk is at its local limit
local L_BUST = 4140378829      -- vrfw_cm_bust     x162 (457) player busts: the game's miniface + kit
local L_BUSTICON = 2593122072  -- vrfw_cm_busticon x1   (461) the card's player bust
-- pools (tiles vanished while moving on a network): a whole network fits at the widest zoom (IE2:
-- 203 tiles, 213 links, 193 faces); faces / busts have their own counter (only players and gates carry one)
-- the card's player requirements use the last CARD_BUSTS face / bust slots (their miniface with kit)
-- a menu stops setting up its layer instances at ~844; pools totalling ~1200 (256 + 224 x 2 + 208 x 2 + the rest) left the input anchor
-- never opened. Kept under ~730 in all: players' busts (BUST, fixed per player, the last CARD_BUSTS for the card) and
-- gates' faces (FACE, fixed per gate) apart; badges (TAG) as long as they last
-- (cells missing at the sides / corners of a zoomed-out network): plates and links 240 each (gate
-- faces 60, badges 40: same 730 in all); DrawNetwork keeps the widest zoom where everything in view fits them
-- TITLE 20: the list rows' titles (0..9) and their right-aligned counts (10..19)
-- ([debug] reveal_all): the bust pool (92) ran out long before the
-- tile pool (240): at the widest zoom ~170 tiles were in view and only the nearest 88 players got their face, the
-- outer ones a plain plate; the gate faces (60) the same on IE2 (113 gates). Same ~672 instances, moved to the faces
-- (tiles 200, links 210, player busts 162, gate faces 60), and the widest zoom now also fits the faces in view
-- (DrawNetwork: zoom in while the players / gates in view need more busts / faces than the pools hold), so every cell
-- drawn has its face.
local N = {LINE = 210, TILE = 200, FACE = 60, BUST = 162, TAG = 70, UI = 8, TITLE = 20, CARDTXT = 12, REQ = 5,
           CARD_BUSTS = 4, full = false}
-- a player is drawn as the game's own face
-- icon of a character card (team00_01_chara_card_for_list, portrait only, the rest of the card hidden): the native
-- composite (funcLuaMenuCommand 0x20EB2104, icon type 9 = face + kit) of his chara_param, the same miniface + kit bust
-- as the retail player cards. Nothing per character here: the engine finds
-- the face and the kit from the card. Geometry of the card's portrait: its height RH,
-- the offset of its centre from the layer origin (OX, OY).
local BUST = {
  MESH = 2828003679 --[[_icon_chr_dmy_l01]], TEX = 21929195 --[[icon_chr_dmy_l01]], NAME = 170976702 --[[_text_chr01]],
  RH = 156, OX = 59, OY = 11,
  -- (the face cut at the edges, offset): the retail card clips the portrait quad with its mask
  -- (icon_chr_msk_l01, a 118 x 116 window off the quad's centre), so the face showed cut and off-centre. As the
  -- office grid does: the mask node is swapped for the framework's plain mask (VRFW_ScreenArt.Plain("mask"),
  -- vrfw_plain_mask: the whole 156-px quad opaque) and the rarity side colour for its plain blank (transparent), so
  -- the quad (centre OX, OY) is the whole face, scaled to fill the card's inner area exactly (mechanism, not a mod's
  -- art). MASK_TRIES: frames a swap that answers false (atlas not in) is waited for.
  T_MASK = 3073015345 --[[icon_chr_msk_l01]], T_COLOR = 3896534971 --[[icon_chr_color01_l01]],
  MASK_TRIES = 30, tries = {},
  HIDE = {"_icon_chr_base_l01", "_icon_chr_gradation_l01", "_seasonal_frame_l01", "_avatar_frame_l01",
    "_icon_chr_focus_l01", "_icon_chr_position_dmy_l01", "_icon_base_l01", "_icon_chr_type_dmy_l01", "_icon_lock01",
    "_icon_captain01", "_icon_ai_role_dmy01", "_gtxt_lv_l01", "_icon_card01", "_icon_chr_def01_l",
    "_icon_chr_grayout01", "_basara_avatar_l01", "_num_chr_dmy_l01", "_num_chr_dmy_l02", "_gauge_exp_base_l01",
    "_gauge_exp_l01", "_icon_synergy_l01", "_icon_synergy_l02", "_leader_base01", "_gtxt_leader01"},
  HIDE_NODES = {"_pos_base02", "_pos_leader01", "_pos_ai_role01", "_num_chr_l01", "_num_chr_l02", "_pos_gauge_exp_l01"},
  key = {},      -- [layer][idx] = the chara key drawn there (the composite is built once per key)
  chara = {},    -- "layer:idx" -> the chara id of that key (its face, drawn by VRFW_FaceIcon)
}

local C = {
  TEXT = @crc:CMND_SET_MENU_TEXT_STRING@, MESH_VISIBLE = @crc:CMND_SET_MESH_VISIBLE@, LAYER_VISIBLE = @crc:CMND_SET_LAYER_VISIBLE@,
  SPRITE = 558735651, LOAD_TEX = @crc:CMND_LOAD_MENU_RES_TEXTURE@, TEX_LOADING = 1506186496, SCALE = @crc:CMND_SET_LAYER_LOCAL_SCALE@, POS = @crc:CMND_SET_LAYER_LOCAL_POS@,
  ATTACH_TRACE = @crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, OPEN_LAYER = @crc:CMND_OPEN_LAYER@,
  FOCUS_ENABLE = @crc:CMND_SET_ENABLE_CTRL_FOCUS@, FOCUS_SET = 3466097042, LIST_NUM = 3252599449,
  HIT_ZONE = 855005857,        -- (layer, idx, bool): the instance's engine mouse zone
  HOVER_FOCUS = @crc:CMND_SET_ON_CHANGE_FOCUS_MOUSE@,   -- (layer, idx, bool): CMND_SET_ON_CHANGE_FOCUS_MOUSE
  GUIDE_SET = 2209673388, GUIDE_CMD = 452337289, GUIDE_OPT = 1432240275,
  SE = @crc:CMND_SND_PLAY_SE@, MENU_ACTIVE = 1558704558, CLOSE_MENU = @crc:CMND_CLOSE_MENU_OBJECT@,
  FADE = 609722083, FADE_DONE = 2259183189,
  MSG_OPEN = 2289627655, MSG_KIND = 2351835063, MSG_RESULT = 1523741473, MSG_DONE = 682363669, MSG_BUSY = 898725220,
  TEXT_VISIBLE = @crc:CMND_SET_MENU_TEXT_VISIBLE@, TEXT_GET = @crc:CMND_TEXT_GET@,
  PRIM_COLOR = @crc:CMND_SET_PRIM_COLOR@, ROTATE = 3476640154, LOG = @crc:CMND_EVT_LOG@,
  LANG = @crc:CMND_GET_LANGUAGE_CODE@,           -- CMND_GET_LANGUAGE_CODE
  CM_MAPS = @crc:CMND_VRFW_CONTACT_MAPS@,       -- CMND_VRFW_CONTACT_MAPS (set, lang)
  CM_MAP = @crc:CMND_VRFW_CONTACT_MAP@,        -- CMND_VRFW_CONTACT_MAP (map, lang)
  SAVE_GET = @crc:CMND_VRFW_SAVE_GET@,      -- CMND_VRFW_SAVE_GET (owner, key, default)
  SAVE_SET = @crc:CMND_VRFW_SAVE_SET@,      -- CMND_VRFW_SAVE_SET (owner, key, value, commit)
  NODE_VISIBLE = 2158717427,
  NAME_VISIBLE = 2735666188, CHARA_OF_PARAM = 347353059, LAYER_NUM = @crc:CMND_GET_CREATE_LAYER_NUM@, IS_VISIBLE = @crc:CMND_IS_LAYER_VISIBLE@,
  MENU_CALL = 830228314,      -- (menu, "global function", args...): runs a function in another menu's VM
  CHECK_INPUT = @crc:CMND_CHECK_INPUT_CMD@,   -- CMND_CHECK_INPUT_CMD (ctrl, input)
}
local MESH_QUAD = 312193881     -- the cmn01_10 quad's mesh
local NODE_QUAD = 1909474081    -- icon_new01 (the cmn01_10 quad's sprite node)
local CUR = 3313461902          -- crc32("cursor")
local FN = {UP = 1986542592, DOWN = 1528655817, LEFT = 1032132762, RIGHT = 3879601371, SHOP = 3951604560,
            TRIAL = 659959792, RELEASE = 4113029826}   -- vrfw_cm_trial (CMD_FUNC3), vrfw_cm_release (CMD_FUNC4)
local G_ACCEPT = 1847312674 --[[Accept]]
local I_ENTER, I_FUNC2 = 2750714971 --[[<CMD_ENTER>]], 2387151820 --[[<CMD_FUNC2>]]
local K_ENTER, K_FUNC2 = 1981080283, 3170216173
local SE_OK, SE_DECIDE, SE_BACK, SE_NG = 3848881948, 4235359837, 202039849, 2086672038
local ROW_MESHES = {3025401186, 486732393, 376662541, 3232607807, 1516082254, 3292070381, 1712955010}
local TEXT_ON, TEXT_OFF = 931545948 --[[_text_list01_on]], 3705682548 --[[_text_list01_off]]
-- the list item's own plates (the list of maps as the game's menu rows)
local ROW_PLATE = {OFF = 486732393 --[[_list_base_s01_off]], ON = 3025401186 --[[_list_base_s01_on]], used = {},
                   texts = {}}
local TEXT_DX = 226             -- the list item's text node starts this far right of its origin

-- the screen's pictures by ROLE (the framework ships no mod's pictures): a role is the sprite a mod declares (content\screen_art\*.toml, Screen =
-- "contact_map", read through VRFW_ScreenArt in OnInit; a mod declares them), else the FALLBACK below:
-- a shape of the framework's neutral atlas vrfw_plain (white), tinted. The background is the exception: no declared
-- "background" -> no quad (DrawBack: the hub's own background, or the retail menu background without a hub).
local ART_SCREEN = "contact_map"
local FALLBACK = {
  list_row = {"square", {0.30, 0.38, 0.62}},            -- a row of the list of maps / zones / the shelf (tinted on screen)
  cursor = {"ring", {1, 0.86, 0.3}},                    -- the cursor ring
  link = {"square", {1, 1, 1}},                         -- a network link (tinted by its state on screen)
  arrow_left = {"arrow_l", {1, 1, 1}},                  -- the grid's page arrows
  arrow_right = {"arrow_r", {1, 1, 1}},
  tile_hidden = {"square", {0.36, 0.40, 0.50}},         -- a tile not open yet ("?")
  tile_done = {"square", {0.45, 0.70, 1}},              -- an open / acquired small tile
  tile_start = {"square", {1, 0.84, 0.35}},             -- the network's start tile
  player_plate = {"square", {1, 1, 1}},                 -- a player's / gate's card (tinted by its state on screen)
  icon_unknown = {"circle", {0.60, 0.62, 0.70}},        -- a face that is not there
  icon_lock = {"circle", {0.95, 0.72, 0.30}},           -- the padlock badge / card icon
  icon_check = {"circle", {0.40, 0.88, 0.50}},          -- the signed badge / open tile's card icon
  icon_start = {"circle", {1, 0.84, 0.35}},             -- the start tile's card icon
  requirement_level = {"circle", {0.45, 0.70, 1}},      -- the requirement icons (team level, wins, goals, item, player)
  requirement_wins = {"circle", {1, 0.80, 0.30}},
  requirement_goals = {"circle", {0.92, 0.94, 0.96}},
  requirement_item = {"circle", {0.85, 0.60, 0.35}},
  requirement_player = {"circle", {0.60, 0.80, 1}},
  requirement_position_1 = {"circle", {0.96, 0.59, 0.16}},   -- N players of a position: the game's position colours
  requirement_position_2 = {"circle", {0.88, 0.24, 0.24}},   -- (1 GK orange, 2 FW red, 3 MF green, 4 DF blue)
  requirement_position_3 = {"circle", {0.24, 0.67, 0.31}},
  requirement_position_4 = {"circle", {0.24, 0.43, 0.82}},
  badge_met = {"circle", {0.35, 0.85, 0.45}},           -- a requirement met / not met
  badge_unmet = {"circle", {0.92, 0.28, 0.28}},
  badge_new = {"circle", {1, 0.84, 0.20}},             -- a player who can be signed and was not looked at yet («!»)
  card_panel = {"square", {0.13, 0.29, 0.64}},          -- the cost / requirements card (tinted darker on screen)
  requirement_plate_met = {"square", {0.20, 0.50, 0.95}},     -- a requirement line met / not met / unused
  requirement_plate_unmet = {"square", {0.30, 0.36, 0.52}},
  requirement_plate_empty = {"square", {0.16, 0.22, 0.40}},
  requirement_bar_base = {"square", {0.10, 0.12, 0.18}},      -- a line's progress bar: its track and its fill
  requirement_bar_met = {"square", {0.35, 0.85, 0.45}},
  requirement_bar_unmet = {"square", {1, 0.60, 0.15}},
  requirement_counter = {"square", {0.08, 0.13, 0.30}},       -- the header's met / all chip (slanted like the plates)
  -- a team page's card border by state: the colours of the card's own frame mesh (CmPages.CardBorder; the plain
  -- frame is its sprite): in the club green, signable now blue, not yet red
  card_border_signed = {"frame", {0.30, 1, 0.45}},
  card_border_ready = {"frame", {0.25, 0.60, 1}},
  card_border_unmet = {"frame", {1, 0.28, 0.28}},
  panel_ground = {"square", {0.10, 0.16, 0.30}},        -- the player panel's ground (right side)
}
local FALLBACK_ANY = {"square", {1, 1, 1}}
local art = {}                  -- role -> the declared {atlas, sprite, tex, crc} (VRFW_ScreenArt.Get, OnInit)
local plain_tint = {}           -- [layer][idx] = the fallback colour of the plain shape drawn there (Tint multiplies it)
local HUB = {menu = nil, on = false}   -- the menu this screen opened over (HubYield)
local FACE_DIR = "#/menu/200_icon/10_icon_chr/face/"
local COMMON_TEX = "#/menu/200_icon/15_icon_common/icon_common.g4tx"   -- the game's element icons
local ELEM_ICON = {"icon_cmd_type01", "icon_cmd_type02", "icon_cmd_type03", "icon_cmd_type04"}   -- wind forest fire mountain
-- the requirement icons on the card: right of the state line, left of the face; a badge on each icon's corner
local REQ = {X = 1590, DX = 50, Y = 716, SIZE = 40, BADGE = 20}
-- the game's check box (the synergy screen's condition rows, team16_03): the box and its check mark
REQ.CHECK = {TEX = "#/menu/102_team/team16/team16_03/team16_03.g4tx", BOX = 1480816304 --[[icon_check_box01]],
                   MARK = 1651181571 --[[the box's mark]], BOX_IX = 5, MARK_IX = 6, SIZE = 32, MARK_SIZE = 40}
local Q = 36                    -- the cmn01_10 quad's own size
-- the info card (the chain board's card art, taller): panel, the face right, 4 lines
-- redesign: no info box on top. The map uses the screen's left / centre (AREA); the selected
-- player is shown on the RIGHT as in the scouting office: his 3D model (vrfw_cm_model, the retail shop's model
-- component) with the shop's status plate (name, position, level), his lines (level / price, requirements, state) and
-- requirement icons under it, on a panel (vrfw_cm_panel 0) that fades into the map on its left (vrfw_cm_panel 1).
-- Not a player (a list row, a gate, a start tile...): the panel shows the title lines and an icon / face.
local AREA = {X0 = 40, X1 = 1200, Y0 = 110, Y1 = 1010, CX = 620, CY = 560}
-- As the scouting office, the model stands on the right and the
-- retail status plate (name, nickname, element, position, person icon) with its white description box sits at the
-- BOTTOM right (STATUS: the plate layer scaled and moved from its retail place at the top right, x 920-1920 /
-- y 130-500 of its layout, to x 1235-1925 / y 765-1020); the level / price, requirements and state go into a small card
-- right of the model, above the plate (INFO). Nothing of the panel reaches AREA (the map): the ground starts at
-- PANEL.X, its fade lies between AREA.X1 and PANEL.X.
-- the model centred on the plate (the shop's model camera puts it at x ~1367; the plate's centre is
-- x ~1580: the model layer is moved by MODEL_DX); the card above the player, centred on the panel
-- MODEL_X (the model stood left over the panel's edge): metres the 3D model is moved right of the
-- place the shop component builds it at (CMND_GET_CHARA_MODEL_POS -> CMND_SET_CHARA_MODEL_POS, once per build). The
-- layer move (MODEL_DX) and the component's m_startX start rows did not move the model in game (same place in screenshots). Shop camera 2410683622 (eye z 12.5, FOV 20): ~245 px a metre at 1080p; the model stood
-- ~205 px left of the panel's centre (x ~1375 vs ~1580) -> 0.84
-- MODEL_AT (it stood right of the requirement card's centre and from
-- the card's bottom edge down over the name bar): the model's world place, set absolutely (CMND_SET_CHARA_MODEL_POS)
-- after each build. The shop camera 2410683622 looks from (0, 2.25, 12.5) at (0, 1.6, 0), FOV 20
-- the build's place (1, 0.8, 5) is 7.5 m from the eye (~408 px a metre, not
-- the 245 used before: the model went to x ~1705, 125 px right of the card) and a 1.6 m player spans ~650 px there, more
-- than the 505 px between the card's bottom (y 362) and the name bar (y 867). At his feet are at
-- y ~850 and a 1.6 m head at ~385, centred on x 1580 (the card's centre, INFO.CX). MODEL_X stays for the camera-offset
-- fallback (a model position that cannot be read).
local PANEL = {X = 1240, FADE = 40, ICON_X = 1580, ICON_Y = 520, ICON = 160, MODEL = true, MODEL_DX = 213,
               MODEL_X = 0.84, MODEL_AT = {2.12, 0.64, 2.05}}
local STATUS_AT = {S = 0.69, DX = 600, DY = 675}
-- the header row: the shared header row of the framework (VRFW_UI.HeaderRow, 66_ui_plates.lua;
-- one component for every screen) at its placement variant "contact_map" (content/defaults/ui_plates.toml: scale
-- 0.69, the row's top-left at (1250, 867), a few px over the shop plate's description box), the slanted band under it
-- where the player page puts it; the shop plate's description stays where it was (STATUS_AT)
local HEADROW = {TEMP_ADD = @crc:CMND_ADD_TEMP_CHARA@, TEMP_FREE = 1829720801, hdl = nil}
-- the card = the price, the state + exactly 4 requirement lines, one requirement each,
-- unused ones a "________________" placeholder; lines clipped to CLIP characters (the count "have/need" kept)
-- the card above the player, centred on the panel: 4 requirement rows (an icon: the player's
-- miniface with kit / the item's icon / the requirement's drawing; "Sign X", "Get X", unused "________"), then
-- the price with the currency's icon, then the state. Rows: Y; icon at ICON_X, text at TEXT_X.
-- GAP: between a team page's price line parts; CHAR_W: a character's width when the game gives no text measure
local INFO = {CX = 1580, CY = 236, W = 620, H = 252, ICON_X = 1300, TEXT_X = 1330, ICON = 32, GAP = 8, CHAR_W = 19,
              YS = {136, 172, 208, 244, 286, 324}, NAME_S = 0.78, LINE_S = 0.62, CLIP = 40, BLANK = "________",
              TINT = {0.55, 0.6, 0.8}}
-- the requirement card of a player: a header ("Requirements" centred, met / all on a chip at the right), then ALWAYS 4 plates filled from the top (art roles requirement_plate_met / _unmet / _empty): the
-- requirement's icon with its met / unmet badge, its name, a progress bar (requirement_bar_base + _met / _unmet fill)
-- and "have / need" right-aligned; an empty line is a dim plate. The price is the first plate
-- (CmPages.PricePlate); under the plates: the state / story lines (LINE_Y). Every Y is a row centre in screen px
-- (1080p); X / W centre and width. The plate sprite's slanted body spans x 1310..1849 at the top / 1298..1837 at the
-- bottom: the icon (ICON_X, its badge) and the counter (right-aligned at COUNT_R) stay inside it.
INFO.PLATES = {L_PLATE = 857504632, L_BAR = 4149169221, X = 1580, W = 592, H = 34, Y = {165, 203, 241, 279},
               HEAD_Y = 128, LINE_Y = {318, 346}, ICON_X = 1330, ICON = 28, TEXT_X = 1352, TEXT_S = 0.56,
               HEAD_S = 0.64, CLIP = 24, NOTE_CLIP = 40, COUNT_R = 1836, BAR_W = 96, BAR_H = 12, BAR_IN = 2,
               BAR_GAP = 14, CHIP_X = 1805, CHIP_W = 88, CHIP_H = 26, CHIP_IX = 4, FILL_IX = 7, TXT_COUNT = 6,
               TXT_HEAD = 10, TXT_TALLY = 11, TOP = 110, BOTTOM = 306,
               MET = "[CG]", UNMET = "[CR]", RESET = "[C]"}
-- a card is exactly its miniface's box (PLATE = FACE: no blue margin around the face); the pitch
-- (CELL) is kept so the grid stays centred in the same area; the badges sit in the card's bottom-right corner
local GRID = {COLS = 6, ROWS = 4, CELL = 176, TOP = 236, FACE = 0.72, CHECK = 0.35, REQNG = 0.26}
local PIN = {PLATE = 92, FACE = 72, COLS = 4, X0 = 245, DX = 250, Y0 = 250, DY = 200}
-- the network's view (zoom + pan): world -> screen around the camera (cx, cy) at scale S, drawn inside
-- VIEW only (left of the player panel: the map scrolls under it); S from FIT (the whole network) to MAX
-- ONE map per game, drawn virtually (only the tiles in view, the pools bound to them every draw:
-- DrawNetwork); smooth zoom: LT / RT (ZOOM_RATE x a second while held) and the wheel (WHEEL a notch) move the target
-- T, the shown scale S eases to it (EASE seconds, exponential); the right stick pans only (PAN px a frame at full
-- tilt, from DEAD), smooth by its own analog value. CAP: the widest zoom shows about this many tiles (the tile pool).
-- A card is its miniface's box (PLATE0, the one size); the face fills its inner area exactly, FACE_IN of it (the plate's
-- 5-px rim of 96 stays on show; the face was cut, now the whole portrait quad, see BUST)
local NET = {S0 = 1.9, S = 1.9, T = 1.9, PLATE0 = 44, SMALL0 = 26, LINE0 = 8,
             PLATE = 44, SMALL = 26, LINE = 8, FIT = 1, MAX = 3.0, cx = 0, cy = 0, drag = nil,
             WHEEL = 1.25, ZOOM_RATE = 2.2, EASE = 0.12, DT = 1 / 60, PAN = 18, DEAD = 0.2, CAP = 150,
             FACE_IN = 1 - 2 * 5 / 96, START = 1.4, HOLD = 8}
NET.FACE0, NET.FACE = NET.PLATE0 * NET.FACE_IN, NET.PLATE0 * NET.FACE_IN
local VIEW = {X0 = 40, X1 = 1240, Y0 = 110, Y1 = 1010, CX = 640, CY = 560, MARGIN = 70}
-- COUNT_PAD / COUNT_CH (the count right-aligned): its right edge this far in from the row's
-- right end; the width of one of its characters (digits, "/", space at scale 1) to place it from its length
local LIST = {CX = 620, TOP = 200, ROW = 76, W = 1080, H = 60, ROWS = 10, COUNT_PAD = 40, COUNT_CH = 17}
local COLOUR = {READY = {0.55, 0.95, 0.6}, MISSING = {0.72, 0.74, 0.8}, DONE = {1, 0.55, 0.5}, LOCKED = {1, 1, 1},
                GATE = {0.85, 0.8, 1}, WHITE = {1, 1, 1}, LINK_DONE = {0.38, 0.84, 0.55}, LINK_OPEN = {0.32, 0.64, 1},
                LINK_LOCKED = {0.62, 0.68, 0.78}, ROW = {0.72, 0.74, 0.82}, ROW_FOCUS = {1, 1, 1}}

-- ---- state ----------------------------------------------------------------------------------------------------------
local SET = nil         -- the set (CMND_VRFW_CONTACT_MAPS)
local MAP = nil         -- the open map (CMND_VRFW_CONTACT_MAP) + its key
local lang = 0
local mode = "list"     -- list / zones / grid / network / shop
local prev_mode = nil   -- the shop returns here
local focus = {list = 1, zones = 1, grid = 1, network = 1, shop = 1}
local zone = 0          -- the open zone (grid)
local members = {}      -- grid: the node numbers of the open zone
local shelf = {}        -- shop: the items shown
local signed = {}       -- the open map's record: node -> true
local acquired, opened = {}, {}   -- network state
-- TEMPORARY view-everything mode (VRFW config [debug] reveal_all, served as SET.reveal): every tile
-- of a network is drawn open (faces, names, links), the header says "VIEW MODE". View only: `real` keeps the strict
-- order's real open tiles and Recruit refuses any other; prices, requirements and the record are untouched.
local VIEW_ALL = {on = false, real = {}}
local pos = {}          -- item -> {x, y, hw, hh} on screen (hit areas; the cursor's place)
local tex_asked, tex_frames, tex_wait = {}, {}, false
local ready, open_guard, evt_co = false, 20, nil

local function Log(...)
  pcall(funcLuaCommand, C.LOG, "contact_map", ...)
end

-- OPEN TRACE (perf, diagnostics). The log has a 343 ms HITCH ~1 s after the open, once
-- the script's 2.3 s were gone from OnInit: engine work with no Lua call, its cause not in the log. For the first
-- OT.FRAMES frames of the screen, every frame with an event (layer instances set up, by layer; a texture / face that
-- came in; a redraw; the input anchor) and every OT.EVERY frames logs "contact_map open trace f<n> ...", so the next
-- HITCH line falls between two of them and names the frame's work. At most OT.MAX lines per open.
local OT = {f = 0, FRAMES = 150, EVERY = 10, MAX = 40, lines = 0, setup = {}, ev = {}, names = nil}
local function OtNote(what)
  if OT.f <= OT.FRAMES then
    OT.ev[#OT.ev + 1] = what
  end
end

--@lib evt_menu_kit.lua#Call,Int,Hide,Ask,Message,Close,StartCo

--@lib evt_menu_kit.lua#Pointer
local Ptr = EVT_PointerNew()

--@lib evt_menu_kit.lua#CharaModel
local Model = nil       -- the panel's 3D player model (EVT_CharaModelNew on vrfw_cm_model; made in OnInit)

local function Text(id)
  local ok, s = pcall(funcLuaCommand, C.TEXT_GET, id)
  if ok and type(s) == "string" then
    return s
  end
  return ""
end

local function Fmt(id, ...)
  local ok, s = pcall(string.format, Text(id), ...)
  if ok then
    return s
  end
  return Text(id)
end

-- a map's name: its series' name when the map has one (team pages of a Chronicle route), else its title row
-- team pages: series names, «owns any card of the character» answers (a global: the main chunk is at its 200 locals)
CmPages = {series = {}, own = {}, trail = {}}
function CmPages.MapTitle(m)
  local sid = m and Int(m.series) or 0
  if sid ~= 0 then
    if CmPages.series[sid] == nil then
      local ok, okc, s = pcall(funcLuaMenuCommand, @crc:CMND_GET_CHARA_SERIES_INFO@, 1, sid)
      CmPages.series[sid] = (ok and okc and type(s) == "string" and s ~= "") and s or false
    end
    if CmPages.series[sid] then
      return CmPages.series[sid]
    end
  end
  return Text(m and m.title or 0)
end

-- the recruit currency's name: the set's RecruitCurrencyTitle row, else the item's own name (as the game shows it,
-- renamed by any mod)
function CmPages.CurrencyName()
  local s = SET ~= nil and Text(SET.rct) or ""
  if s == "" and SET ~= nil and Int(SET.rc) ~= 0 then
    local ok, name = pcall(funcLuaCommand, @crc:CMND_GET_ITEM_PARAM@ --[[item name (item, 0)]], SET.rc, 0)
    if ok and type(name) == "string" then
      s = name
    end
  end
  return s
end

-- a zone's name: its label (a team page: the team's name) when served, else its title row
function CmPages.ZoneTitle(z)
  if z ~= nil and type(z.label) == "string" and z.label ~= "" then
    return z.label
  end
  return Text(z and z.title or 0)
end

local function Place(layer, idx, x, y)
  funcLuaMenuCommand(C.POS, layer, x, -y, 0, idx)
end

local function SetColour(layer, idx, c)
  funcLuaMenuCommand(C.PRIM_COLOR, layer, idx, MESH_QUAD, c[1], c[2], c[3])
end

-- a sprite on a quad; the sprite command's answer (false: the atlas is not there)
local function QuadTex(layer, idx, texCrc, spriteCrc, x, y, w, h)
  funcLuaMenuCommand(C.LAYER_VISIBLE, layer, idx, true)
  funcLuaMenuCommand(C.SCALE, layer, w / Q, h / Q, 1, idx)
  local ok = funcLuaMenuCommand(C.SPRITE, layer, texCrc, spriteCrc, NODE_QUAD, 0, idx)
  Place(layer, idx, x, y)
  local pt = plain_tint[layer]
  if pt ~= nil and pt[idx] ~= nil then   -- the slot held a tinted plain shape: back to the sprite's own colours
    pt[idx] = nil
    SetColour(layer, idx, COLOUR.WHITE)
  end
  return ok
end

-- a colour on a quad; on a plain fallback shape it is multiplied by the role's own colour (the state stays readable)
local function Tint(layer, idx, c)
  local pt = plain_tint[layer] and plain_tint[layer][idx]
  if pt ~= nil then
    c = {c[1] * pt[1], c[2] * pt[2], c[3] * pt[3]}
  end
  SetColour(layer, idx, c)
end

local function Line(layer, idx, s, x, y, scale)
  if s == nil or s == "" then
    Hide(layer, idx)
    return
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, layer, idx, true)
  funcLuaMenuCommand(C.SCALE, layer, scale or 1, scale or 1, 1, idx)
  funcLuaMenuCommand(C.TEXT, layer, TEXT_ON, s, idx)
  funcLuaMenuCommand(C.TEXT_VISIBLE, layer, TEXT_ON, true, idx)
  Place(layer, idx, x - TEXT_DX * (scale or 1), y)
end

-- a texture loaded on demand: its crc, or false while loading, or nil when it never came in
local function Tex(path)
  if path == nil or path == "" or tex_frames[path] == -1 then
    return nil
  end
  if not tex_asked[path] then
    tex_asked[path] = true
    tex_frames[path] = 0
    funcLuaMenuCommand(C.LOAD_TEX, path)
  end
  local tc = CRC32(path)
  if funcLuaCommand(C.TEX_LOADING, tc) == true then
    tex_wait = true
    return false
  end
  return tc
end

-- the sprite of art role `role` (a mod's declaration, its atlas loaded on demand: hidden while it loads, Step redraws)
-- or, undeclared / not there, the role's plain fallback shape tinted with its colour: never a missing sprite
local function Quad(layer, idx, role, x, y, w, h)
  local a = art[role]
  if a ~= nil then
    local tc = Tex(a.atlas)
    if tc == false then
      Hide(layer, idx)
      return
    end
    if tc ~= nil and QuadTex(layer, idx, tc, a.crc, x, y, w, h) ~= false then
      return
    end
  end
  local f = FALLBACK[role] or FALLBACK_ANY
  local tc, sc = VRFW_ScreenArt.Plain(f[1])
  QuadTex(layer, idx, tc, sc, x, y, w, h)
  plain_tint[layer] = plain_tint[layer] or {}
  plain_tint[layer][idx] = f[2]
  SetColour(layer, idx, f[2])
end

local function BustLayer(layer)
  if layer == L_FACE then
    return L_BUST
  elseif layer == L_ICON then
    return L_BUSTICON
  end
  return nil
end

local function HideBust(layer, idx)
  if layer ~= nil then
    Hide(layer, idx)
  end
end

-- the game's miniface + kit bust of chara_param `card`, centred at (x, y), `size` px high
local function DrawBust(layer, idx, card, x, y, size)
  local s = size / BUST.RH
  funcLuaMenuCommand(C.SCALE, layer, s, s, 1, idx)
  funcLuaMenuCommand(C.POS, layer, x - BUST.OX * s, -y - BUST.OY * s, 0, idx)
  BUST.key[layer] = BUST.key[layer] or {}
  if BUST.key[layer][idx] ~= card then
    for _, m in ipairs(BUST.HIDE) do
      funcLuaMenuCommand(C.MESH_VISIBLE, layer, CRC32(m), false, idx)
    end
    for _, m in ipairs(BUST.HIDE_NODES) do
      funcLuaMenuCommand(C.NODE_VISIBLE, layer, CRC32(m), false, idx)
    end
    funcLuaMenuCommand(C.NAME_VISIBLE, layer, BUST.NAME, false, idx)
    local mask_tex, mask_sprite = VRFW_ScreenArt.Plain("mask")
    local blank_tex, blank_sprite = VRFW_ScreenArt.Plain("blank")
    local okm = funcLuaMenuCommand(C.SPRITE, layer, mask_tex, mask_sprite, BUST.T_MASK, 0, idx)
    funcLuaMenuCommand(C.SPRITE, layer, blank_tex, blank_sprite, BUST.T_COLOR, 0, idx)
    local tk = layer .. ":" .. idx
    if okm == false and (BUST.tries[tk] or 0) < BUST.MASK_TRIES then
      BUST.tries[tk] = (BUST.tries[tk] or 0) + 1   -- the atlas is not in yet: swap again next draw
      funcLuaMenuCommand(C.LAYER_VISIBLE, layer, idx, false)
      return
    end
    BUST.tries[tk] = nil
    local ok, chara = pcall(funcLuaCommand, C.CHARA_OF_PARAM, card)
    if not ok or type(chara) ~= "number" or chara == 0 then
      chara = card
    end
    BUST.key[layer][idx] = card
    BUST.chara[tk] = chara
  end
  -- the face mesh stays hidden while the face loads (VRFW_FaceIcon.Settle in Step)
  VRFW_FaceIcon.Face(layer, idx, BUST.chara[layer .. ":" .. idx], BUST.MESH, BUST.TEX,
    {kit = 0, keeper = false, use_args = true})
  funcLuaMenuCommand(C.LAYER_VISIBLE, layer, idx, true)
end

-- the busts still loading: shown once their face is in (Step)
local function BustStep()
  if VRFW_FaceIcon.Pending() then
    VRFW_FaceIcon.Settle()
    if not VRFW_FaceIcon.Pending() then
      OtNote("face in")
    end
  end
end

local function DrawFace(layer, idx, face, x, y, size)
  local card = 0
  if type(face) == "table" then
    card = Int(face.card)
    face = face.face
  end
  local bl = BustLayer(layer)
  if card ~= 0 and bl ~= nil then
    Hide(layer, idx)
    DrawBust(bl, idx, card, x, y, size)
    return
  end
  HideBust(bl, idx)
  if face == nil or face == "" then
    Quad(layer, idx, "icon_unknown", x, y, size, size)
    return
  end
  local tc = Tex(FACE_DIR .. face .. "_l.g4tx")
  if tc == false then
    Hide(layer, idx)              -- still loading: Step redraws
  elseif tc == nil then
    Quad(layer, idx, "icon_unknown", x, y, size, size)
  else
    QuadTex(layer, idx, tc, CRC32(face .. "_1_l00"), x, y, size, size)
  end
end

-- ---- data -----------------------------------------------------------------------------------------------------------
local function LoadSet(set)
  lang = Int(Call(C.LANG))
  local s = Call(C.CM_MAPS, set, lang)
  if type(s) ~= "table" or type(s.maps) ~= "table" or #s.maps == 0 then
    return nil
  end
  VIEW_ALL.on = s.reveal == true
  return s
end

-- the record: the chara_param ids signed on the map (key "contact.cards.<map>"). It was the node numbers
-- ("contact.<map>"), which a rebuilt map gives to other tiles (a tile two steps from the start looked signed); that
-- old key is not read any more
local function RecordKey()
  return "contact.cards." .. MAP.key
end

local function LoadRecord()
  signed = {}
  local cards = {}
  local v = Call(C.SAVE_GET, OWNER, RecordKey(), "")
  for x in string.gmatch(type(v) == "string" and v or "", "%d+") do
    cards[tonumber(x)] = true
  end
  for i, n in ipairs(MAP.nodes) do
    if n.kind == "player" and cards[Int(n.card)] then
      signed[i] = true
    end
  end
end

local function SaveRecord()
  local t = {}
  for k in pairs(signed) do
    local n = MAP.nodes[k]
    if n ~= nil and Int(n.card) ~= 0 then
      t[#t + 1] = Int(n.card)
    end
  end
  table.sort(t)
  Call(C.SAVE_SET, OWNER, RecordKey(), table.concat(t, ","), 1)
end

-- the cards the set's Exclude took off the map (m.excl) are not counted: an older record may still name one
local function MapSigned(m)
  local v = Call(C.SAVE_GET, OWNER, "contact.cards." .. m.key, "")
  local skip = {}
  for _, c in ipairs(type(m.excl) == "table" and m.excl or {}) do
    skip[Int(c)] = true
  end
  local n = 0
  for x in string.gmatch(type(v) == "string" and v or "", "%d+") do
    if not skip[tonumber(x)] then
      n = n + 1
    end
  end
  return n
end

local function ReqsMet(node)
  return #VRFW_Recruit.Missing(node.reqs) == 0
end

-- a node with `cards` (team pages: every card of the character) counts as signed when any of them is in the club;
-- the answer is kept until the map opens again (CmPages.own)
local function IsSigned(i)
  local n = MAP.nodes[i]
  if signed[i] == true and not (type(n.cards) == "table" and #n.cards > 0) then
    return true
  end
  if n.kind ~= "player" then
    return false
  end
  if type(n.cards) == "table" and #n.cards > 0 then
    if CmPages.own[i] == nil then
      CmPages.own[i] = VRFW_Recruit.OwnedAny(n.cards) > 0
    end
    return CmPages.own[i]
  end
  return VRFW_Recruit.Owned(n.card) > 0
end

-- the strict order (IE's Connection Map): acquired / open per tile, to a fixed point
local function NetState()
  acquired, opened = {}, {}
  local nodes = MAP.nodes
  local changed = true
  local guard = 0
  while changed and guard < #nodes + 2 do
    changed, guard = false, guard + 1
    for i, n in ipairs(nodes) do
      if not opened[i] then
        local o = n.kind == "start" or MAP.strict == false   -- not strict: every tile open
        for _, l in ipairs(n.links) do
          if acquired[l] then
            o = true
            break
          end
        end
        if o then
          opened[i], changed = true, true
        end
      end
      if opened[i] and not acquired[i] then
        local a = false
        if n.kind == "start" or n.kind == "open" then
          a = true
        elseif n.kind == "gate" then
          a = ReqsMet(n)
        else
          a = IsSigned(i)
        end
        if a then
          acquired[i], changed = true, true
        end
      end
    end
  end
  VIEW_ALL.real = opened
  if VIEW_ALL.on then                 -- view everything: every tile drawn open (the real ones stay in VIEW_ALL.real)
    local all = {}
    for i in ipairs(nodes) do
      all[i] = true
    end
    opened = all
  end
end

local function Price(node)
  return node.price or 0
end

local function CanAfford(node)
  return VRFW_Recruit.Wallet(CmPages.PriceOf(node)) >= Price(node)
end

-- a player's state: "done", "ready", "missing", "locked"
local function State(i)
  local n = MAP.nodes[i]
  if MAP.kind == "network" and not opened[i] then
    return "locked"
  end
  if IsSigned(i) then
    return "done"
  end
  if MAP.kind == "network" and VIEW_ALL.on and not VIEW_ALL.real[i] then
    return "missing"                  -- view everything: drawn, never "can be signed now" before its real turn
  end
  if ReqsMet(n) and CanAfford(n) then
    return "ready"
  end
  return "missing"
end

local function ZoneMembers(z)
  local out = {}
  for i, n in ipairs(MAP.nodes) do
    if n.kind == "player" and n.zone == z then
      out[#out + 1] = i
    end
  end
  return out
end

local function ZoneSigned(z)
  local k = 0
  for i, n in ipairs(MAP.nodes) do
    if n.kind == "player" and n.zone == z and IsSigned(i) then
      k = k + 1
    end
  end
  return k
end

local function ItemTitle(id)
  for _, it in ipairs(MAP and MAP.items or {}) do
    if it.item == id then
      return Text(it.title)
    end
  end
  if SET ~= nil and id == SET.ic then
    return Text(SET.ict)
  end
  if SET ~= nil and id == SET.rc then
    return CmPages.CurrencyName()
  end
  return "#" .. tostring(id)
end

local function ReqLines(node)
  local out = {}
  for _, r in ipairs(node.reqs or {}) do
    local have = VRFW_Recruit.Have(r)
    local mark = have >= (r.count or 1) and MARK_ON or MARK_OFF
    local count = "  " .. tostring(math.min(have, r.count or 1)) .. "/" .. tostring(r.count or 1)
    if r.kind == "player" and (r.level or 0) > 1 then
      out[#out + 1] = mark .. Fmt(T.REQ_PLAYER_LEVEL, CmClip((r.name or "") ~= "" and r.name or Text(T.UNKNOWN), INFO.CLIP - 14),
        r.level)
    elseif r.kind == "player" then
      -- the name, cut so the count stays visible
      out[#out + 1] = mark .. CmClip((r.name or "") ~= "" and r.name or Text(T.UNKNOWN), INFO.CLIP - 8) .. count
    elseif r.kind == "item" then
      local title = (r.title ~= nil and r.title ~= 0) and Text(r.title) or ItemTitle(r.id)
      out[#out + 1] = mark .. CmClip(title, INFO.CLIP - 8) .. count
    elseif r.kind == "team_level" then
      out[#out + 1] = mark .. Fmt(T.REQ_TEAM_LEVEL, r.count or 1, have)
    elseif r.kind == "element" then
      out[#out + 1] = mark .. Fmt(T.REQ_ELEM, Text(T.ELEM[r.element] or T.UNKNOWN), r.count or 1, have)
    elseif r.kind == "position" then
      out[#out + 1] = mark .. Fmt(T.REQ_ELEM, Text(T.POS[r.position] or T.UNKNOWN), r.count or 1, have)
    elseif r.kind == "wins" then
      out[#out + 1] = mark .. Fmt(T.REQ_WINS, r.count or 1, have)
    elseif r.kind == "goals" then
      out[#out + 1] = mark .. Fmt(T.REQ_GOALS, r.count or 1, have)
    elseif r.kind == "cleared" then
      out[#out + 1] = mark .. Fmt(T.REQ_BEAT, CmClip((r.name or "") ~= "" and r.name or Text(T.UNKNOWN), INFO.CLIP - 8))
    elseif r.kind == "unlock" then
      out[#out + 1] = mark .. Fmt(T.REQ_BEAT_MORE, CmClip((r.name or "") ~= "" and r.name or Text(T.UNKNOWN), INFO.CLIP - 14))
    elseif r.kind == "trial" then
      out[#out + 1] = mark .. CmPages.TrialText(r)
    end
  end
  return out
end
