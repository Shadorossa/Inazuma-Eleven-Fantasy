-- vrfw_chain_board_menu (plain Lua 5.2 source): the VR-Framework's CHAIN BOARD screen (graft chain_board, mod
-- vr_framework; declared in the framework's menus\chain_board.toml, served as common/script/lua/menu/
-- vrfw_chain_board_menu.lua.bin).
-- The 3DS "Cadenas" board of a [[chain]] with [[chain.tile]]s (team type): a grid of tiles on one or more pages, two
-- pages side by side (panels with their title), links between tiles (straight bars; an arrow between the panels for a
-- link to the next page), the start tile ("Inicio"), match tiles (the rival's crest; S / A / B badge of the best rank),
-- chests (closed / opened). A tile OPENS when a tile linked to it is done (the start is always done); locked tiles show
-- a padlock. Keys / pad: arrows move over every tile (the view follows the cursor's page), Accept decides, X / FUNC2 =
-- help, Back = back. Mouse / free cursor: hover focuses, click decides (evt_menu_kit.lua#Pointer).
--   match (open) .. the question "Play against X (Lv. N)?"; yes = the screen closes with that tile as its result: the
--                   board that opened it launches the match (e.g. a chronicle board using graft route_chains)
--   chest (open) .. opened, marked done, its links open; its declared rewards are given once (VRFW_Chain.Pay: the
--                   retail "item get" window per item; a chest opened before the payout existed pays the next time
--                   its board is shown; bag full: a message, retried later)
--   S chest ....... IE3's "S" chest (kind schest): opens like a chest once every match of its branch is won with S
--   double chest .. (kind dchest) opened without S: its base reward, closed again (drawn as the S
--                   chest); opened again once its branch is all S: the special reward, then open. No reward: disabled
--   locked ........ a message; start: nothing
--   slot .......... a placeholder of a board shaped like an IE3 original (no team yet): the "?" plate, "Coming soon"
--   blocked ....... the 3DS chains' red "prohibited" sign: the card shows its requirements (a win against a team, a
--                   chain completed, the team's level, a player in the club); Accept says them; once they are met and a
--                   tile linked to it is done it opens by itself (VRFW_Chain.Sync when the board is shown: the open
--                   gate sign) and the tiles behind it open
-- Art (the framework ships no other mod's pictures): every plate, icon and the background is a ROLE
-- (VRFW_ScreenArt) a mod declares for the screen "chain_board" (e.g. a chronicle mod's IE3
-- look); a role nobody declares is drawn as a plain tinted shape of the framework's neutral atlas vrfw_plain, an
-- undeclared background keeps the retail menu background.
-- Look (to the original IE3 chain screen):
-- the IE3 background (role background, a full-screen picture replacing the menu background), the board drawn straight on
-- it (no page titles), the pages side by side as ONE continuous board (16:9 fits it: links cross between pages, no ▶◀ arrow; an arrow
-- only towards a page that is not on screen), light-blue plates, an
-- orange "?" plate for a match not open yet, chests on lavender plates (padlocked until they open), square B / A / S
-- badges at the plate's bottom-right, yellow corner brackets as the cursor.
-- The team card: above the board (moved down for it), the focused tile's card in
-- IE3's info panel style: the team's name (large), "Lv. N" (+ its best rank), "Requisito: <match challenge>" / "Requisito:
-- ninguno", the crest on the right; a "?" slot, a chest, the S chest, the start and a match not open yet get their own
-- card. The retail guide line at the bottom is hidden (the card says it all). The help window (X / FUNC2) lists the
-- DECLARED match ranks (VRFW_MatchRank, defaults\match_rank.toml): one line per rank, its badge + its text row.
-- Opened by a mod's screen as a child: parameter crc32("vrfw_chain_board") = the chain index (team type order) before
-- CMND_OPEN_MENU_OBJECT(crc32("vrfw_chain_board_menu")); result: parameter crc32("vrfw_chain_pick") = the match tile
-- (1-based) to play, 0 = back. Data and progress: VRFW_Chain (menu part lua\_all\30_chain.lua).
-- A CHAIN HUB: parameter crc32("vrfw_chain_hub") = the hub node's save slot: the screen
-- opens on the chooser list of the hub's chains (VRFW_Chain.Hub), Accept opens a chain's board, Back returns to the
-- list; a match picked there also answers crc32("vrfw_chain_pick_chain") = its chain index + 1.
-- Art: roles a mod declares (VRFW_ScreenArt, screen "chain_board"; a mod's research/scripts/
-- chain_board_art.py draws them, G = its GEOM), else vrfw_plain shapes; crests: the
-- rival's own emblem texture #/menu/200_icon/01_icon_emblem/<em>_s.g4tx (loaded on demand).
-- Texts: the framework's menu_text rows (text\rows\chain_board.toml), never literals.
-- Rule: no engine call at top level; funcLuaCommand only exists inside callbacks.
INCLUDE("LUA_PROG_BASE")
INCLUDE("LUA_SAVEDATA_MANAGEMENT_MENU_INC")   -- header helpers (soccer top inc) + general window inc

local MENU = 2748171433           -- crc32("vrfw_chain_board_menu")
local KEY_CHAIN = 75385505        -- crc32("vrfw_chain_board"): parameter in, the chain index
local KEY_RESULT = 46591264       -- crc32("vrfw_chain_pick"): parameter out, the match tile (1-based), 0 = back
-- a chain HUB: parameter in crc32("vrfw_chain_hub") = the hub node's save slot (the screen opens
-- on the chooser list of its chains); out crc32("vrfw_chain_pick_chain") = the picked tile's chain index + 1
local KEY_HUB = 659670413
local KEY_PICK_CHAIN = 3161495482

-- texts (menu_text rows of the framework, crc32 of the row id)
local T = {
  HELP_BTN = 3827205774, MATCH = 1512699946,
  RANK = 2512483472, LOCKED = 1092847605,
  START = 3205195936, CHAIN_RANK = 2653903958, CHEST = 3677785752, CHEST_OPEN = 1469045648, ASK = 3261041561,
  CHEST_OPENED = 38741007, LOCKED_MSG = 1210977422, SCHEST = 2867057922, SLOT = 923124444,
  -- chest rewards: vrfw_chain_chest_full (bag full, retried later) / vrfw_chain_chest_player (a player joined)
  CHEST_FULL = 2499750840, CHEST_PLAYER = 922777905,
  -- the team card: vrfw_chain_card_level / _req / _req_none / _unknown / _chest_rule / _schest / _schest_rule
  CARD_LEVEL = 2793446092, CARD_REQ = 594567671, CARD_REQ_NONE = 2976084942, CARD_UNKNOWN = 697218748,
  CARD_CHEST = 3849747250, CARD_SCHEST = 390217589, CARD_SCHEST_RULE = 4095379111,
  CARD_WINS = 3412778781,   -- vrfw_chain_card_wins: the wins against the tile's team
  -- a match tile's rewards box: a rank reward already received (vrfw_chain_reward_got), the kind of a reward without a
  -- name of its own (vrfw_chain_prize_emblem / _kit / _item), a match drop not seen yet (vrfw_chain_drop_unknown) and
  -- the bag-full message of a late rank reward (vrfw_chain_rank_full)
  REWARD_GOT = 3379297442, PRIZE_EMBLEM = 3984245770, PRIZE_KIT = 2896219202, PRIZE_ITEM = 2488379808,
  DROP_UNKNOWN = 1233052892, RANK_FULL = 1667156185,
  -- a double chest: vrfw_chain_card_dchest / vrfw_chain_dchest_rule / _half / _empty; with an A tier:
  -- vrfw_chain_dchest_rule_a / vrfw_chain_dchest_half_a / vrfw_chain_card_achest_rule
  CARD_DCHEST = 160501078, DCHEST_RULE = 979975818, DCHEST_HALF = 2280379239, DCHEST_EMPTY = 4144261363,
  DCHEST_RULE_A = 1178752425, DCHEST_HALF_A = 1932131151, CARD_ACHEST_RULE = 42007469,
  -- a blocked tile: vrfw_chain_card_blocked / _blocked_rule / _blocked_open / _blocked_msg and one row per
  -- requirement kind vrfw_chain_req_win / _chain / _team_level / _player
  CARD_BLOCKED = 1593703163, BLOCKED_RULE = 1769468095, BLOCKED_OPEN = 2346704855, BLOCKED_MSG = 2829757331,
  REQ = {win = 2489642486, chain = 3845247950, team_level = 4057630989, player = 2669710775},
  -- the chain hub's list: vrfw_chain_hub_title / _matches / _open
  HUB_TITLE = 1818676472, HUB_MATCHES = 2420571302, HUB_OPEN = 1175154506,
}

-- ---- layers ---------------------------------------------------------------------------------------------------------
local L_ROW = 3455690937        -- save01_02_list_item (1 instance: the input anchor, off screen)
local L_HEADER = 575058101      -- mainmenu90_01_header
local L_GUIDE_LINE = 3078308064 -- mainmenu90_05_content_guide_line01
local L_CURSOR = 2296367164     -- cmn05_01_cursor (hidden: the ring is the cursor)
local L_BTN_GUIDE = 1138543975  -- mainmenu01_06_base_button_guide
local L_BTN = 9396745           -- mainmenu01_07_button_guide
local L_RET = 2005383485        -- mainmenu01_10_return_arrow_button_guide
local L_BG = 1438174967         -- vrfw_chain_bg     x2    (draw priority 451) page panels
local L_LINE = 1243567693       -- vrfw_chain_line   x120  (453) links
local L_TILE = 3984870335       -- vrfw_chain_tile   x60   (455) tile plates (mouse hit areas)
local L_EMB = 2912079495        -- vrfw_chain_emb    x60   (457) crest / icon
local L_TAG = 1823063107        -- vrfw_chain_tag    x60   (458) rank badge / check
local L_UI = 3078842214         -- vrfw_chain_ui     x12   (459) 0 ring, 1-2 title plates, 3-11 page arrows
local L_TITLE = 1998461325      -- vrfw_chain_title  x6    (save01_02_list_item, 551) the help window's lines
local L_BACK = 4140114828       -- vrfw_chain_back   x1    (450) the declared background (role background, full screen)
local L_RETAIL_BG = 367379312   -- mainmenu90_00_background (450): hidden while a declared background replaces it
local L_HELP = 938197549       -- vrfw_chain_helpwin x1    (460) the help window's panel
local L_CARD = 2367650408       -- vrfw_chain_card   x2    (459) 0 the team card's panel, 1 the rewards box's panel
-- vrfw_chain_cardtxt x9 (save01_02_list_item, 551): 0-2 the team card's lines, 3-4 the rank rewards' names, 5-8 the
-- match drops' names
local L_CARDTXT = 36395481
local TXT_REWARD0, TXT_DROP0 = 3, 5
-- vrfw_chain_icon x21 (461): what sits ON a panel, in its own layer above the panels (drawn in the panel's
-- own layer the crest / the rank badges came out faded): 0 the card's crest / icon, 1-6 the help window's rank badges,
-- 7-11 its row separators; the rewards box: 12-15 the rank rewards' badge + item icon (two per reward), 16 its line,
-- 17-20 the match drops' icons
local L_ICON = 4271885152
local ICON_CREST, ICON_BADGE0, ICON_SEP0, ICON_HELP_END = 0, 1, 7, 12
local ICON_REWARD0, ICON_RULE, ICON_DROP0 = 12, 16, 17
local N = {BG = 2, LINE = 120, TILE = 60, UI = 12, TITLE = 8, HELP = 1, CARD = 2, CARDTXT = 9, ICON = 21, ARROW0 = 3,
           REWARD = 2, DROP = 4}

local C = {
  TEXT = 1083631230, MESH_VISIBLE = 3405944500, LAYER_VISIBLE = 711242136,
  SPRITE = 558735651,         -- (layer, textureCrc, spriteCrc, nodeCrc, 0, idx)
  LOAD_TEX = 839427544,
  TEX_LOADING = 1506186496,   -- (textureCrc) -> true while still loading
  SCALE = 3778714801,
  POS = 1389957207,
  ATTACH_TRACE = 1774843228,
  OPEN_LAYER = 629267548,
  FOCUS_ENABLE = 3518307824, FOCUS_SET = 3466097042, LIST_NUM = 3252599449,
  HIT_ZONE = 855005857,        -- (layer, idx, bool): the instance's engine mouse zone
  HOVER_FOCUS = 2206938151,   -- (layer, idx, bool): CMND_SET_ON_CHANGE_FOCUS_MOUSE
  GUIDE_SET = 2209673388, GUIDE_CMD = 452337289, GUIDE_OPT = 1432240275,
  SE = 1917805374, MENU_ACTIVE = 1558704558, CLOSE_MENU = 320421347,
  FADE = 609722083, FADE_DONE = 2259183189,
  P_SET = 3860611758, P_CLEAR = 3363400568, P_EXISTS = 2947612279, P_GET = 3522198769,
  MSG_OPEN = 2289627655, MSG_KIND = 2351835063, MSG_RESULT = 1523741473, MSG_DONE = 682363669, MSG_BUSY = 898725220,
  TEXT_VISIBLE = 1505208242,
  TEXT_GET = 4074371074,
  PRIM_COLOR = 855211291,     -- CMND_SET_PRIM_COLOR (layer, idx, meshCrc, r, g, b)
  ROTATE = 3476640154,        -- (layer, x, y, z radians, idx): retail SetLayerLocalRotate (kizuna_menu)
  ITEM_ICON = 3508889864,     -- (layer, idx, mesh, slot, item): the item's own icon on a quad (as every game list)
  TEXT_SIZE = 3549540977,     -- CMND_GET_MENU_TEXT_RECT_SIZE (layer, idx, node) -> width, height
  DROP_PREVIEW = 1376251505,  -- CMND_VRFW_DROP_PREVIEW (game, max, difficulty...) -> item ids, the most relevant first
  DROP_LIST_OF = 1446336384,  -- CMND_VRFW_DROP_LIST_OF (game, difficulty, start, count) -> total, then item, percent
  LOG = 3661580131,
}
local MESH_QUAD = 312193881     -- the cmn01_10 quad's mesh
local NODE_QUAD = 1909474081    -- icon_new01 (the cmn01_10 quad's sprite node)
local CUR = 3313461902          -- crc32("cursor")
local FN = {UP = 3555250086, DOWN = 2280944256, LEFT = 3781952979, RIGHT = 3907130610, HELP = 2475474455}
local G_ACCEPT = 1847312674 --[[Accept]]
local I_ENTER, I_FUNC2 = 2750714971 --[[<CMD_ENTER>]], 2387151820 --[[<CMD_FUNC2>]]
local K_ENTER, K_FUNC2 = 1981080283, 3170216173
local SE_OK, SE_DECIDE, SE_BACK = 3848881948, 4235359837, 202039849
local SE_NG = 2086672038 --[[sy0003]]
local ROW_MESHES = {3025401186, 486732393, 376662541, 3232607807, 1516082254, 3292070381, 1712955010}
local TEXT_ON, TEXT_OFF = 931545948 --[[_text_list01_on]], 3705682548 --[[_text_list01_off]]

local ART_SCREEN = "chain_board"   -- VRFW_ScreenArt: the screen whose roles the mods declare
-- a role nobody declares: a shape of the framework's plain atlas (VRFW_ScreenArt.Plain) and its tint (IE3's palette)
local FALLBACK = {
  card = {"square", {0.34, 0.40, 0.63}}, help_panel = {"square", {0.25, 0.31, 0.53}}, line = {"square", {1, 1, 1}},
  ring = {"ring", {1, 0.78, 0.2}}, arrow_l = {"arrow_l", {1, 1, 1}}, arrow_r = {"arrow_r", {1, 1, 1}},
  tile_open = {"square", {0.38, 0.80, 0.90}}, tile_done = {"square", {0.38, 0.84, 0.55}},
  tile_hidden = {"square", {0.90, 0.42, 0.22}}, tile_start = {"square", {0.84, 0.29, 0.29}},
  tile_chest = {"square", {0.45, 0.42, 0.74}}, tile_locked = {"square", {0.60, 0.64, 0.72}},
  icon_chest = {"circle", {0.75, 0.78, 0.85}}, icon_chest_locked = {"circle", {0.45, 0.47, 0.52}},
  icon_chest_open = {"circle", {0.95, 0.95, 0.95}}, icon_schest = {"circle", {1, 0.77, 0}},
  icon_schest_locked = {"circle", {0.55, 0.45, 0.15}}, icon_schest_open = {"circle", {1, 0.9, 0.5}},
  icon_start = {"circle", {0.9, 0.3, 0.3}}, icon_blocked = {"circle", {0.85, 0.15, 0.15}},
  icon_unblocked = {"circle", {0.3, 0.75, 0.4}}, icon_unknown = {"circle", {0.2, 0.22, 0.3}},
  icon_lock = {"circle", {0.6, 0.62, 0.7}}, icon_check = {"circle", {0.3, 0.75, 0.4}},
}
local EMB_DIR = "#/menu/200_icon/01_icon_emblem/"
-- chain_board_art.py GEOM (screen px, y down): keep in sync
-- the board: the pages on screen side by side as one grid centred on CX (a GAP of cells between two pages), cell =
-- min(BOARD_W / columns, GRID_H / rows, CELL_MAX); tile plate = TILE x cell (IE3: 40 px tiles on a ~52 px pitch)
local G = {Q = 36, CX = 960, BOARD_W = 1760, GRID_H = 540, GRID_CY = 680, CELL_MAX = 180, GAP = 0.45, TILE = 0.78,
           ICON = 0.62, CHEST = 0.96, BADGE = 0.3, RING = 1.18, LINE = 12, ARROW = 56,
           HEX_DX = 0.92}       -- a hex board's column pitch in cells (the CS board: 64 px columns, 64 px rows)
-- the team card (chain_board_art.py CARD): panel centre / size, the crest right, text lines (left x, centre y; the
-- name's text scale)
-- (narrower, 1040 -> 900; the requirement on the level's line after a "|", so 2 lines, the second
-- one at LINE_S so "Lv. · rango | Requisito" fits left of the crest)
-- (square corners, a thinner outline, flat like the cells, the crest opaque, the card tighter, a third
-- line with the wins against the team: 860 x 176 drawn 1:1, the crest 144 px, 16 px from the right edge; the first line
-- in the plate's lighter upper band)
-- On a board the card sits left (BOARD_CX) and a match tile's rewards box at its right; the hub's card stays centred.
local CARD = {CX = 960, BOARD_CX = 540, CY = 236, W = 860, H = 176, CREST = 144, CREST_DX = 88, TEXT_DX = 32,
              NAME_Y = 186, NAME_S = 1.35, LINE_S = 0.8, LINE1_Y = 242, LINE2_Y = 284}
-- the rewards box (same height as the card, 20 px right of it): one row of the rank rewards (badge, item icon, name;
-- the names shrink to fit), a thin line, then a 2 x 2 grid of the match's drops. Offsets from the box's top edge.
local BOX = {CX = 1400, W = 820, PAD = 20, ROW_Y = 40, BADGE = 34, ICON = 36, ICON_DX = 42, NAME_DX = 88, GAP = 16,
             NAME_S = 0.68, RULE_Y = 72, RULE = 2, RULE_COLOUR = {0.59, 0.67, 0.82}, DROP_Y = 104, DROP_PITCH = 42,
             DROP_ICON = 32, DROP_NAME_DX = 42, GLYPH_W = 17, PAID_TINT = {0.5, 0.5, 0.5}}
-- the page title's text: the retail list item's text node (save01_02.g4pkm _text_list01_on, left aligned) starts
-- TEXT_DX px right of the item's origin and is centred on it vertically (the item's plate meshes are hidden)
local TEXT_DX = 226
-- link colours of IE3's link pieces: green (both done), blue (both open), pale grey-blue (closed)
local COLOUR = {DONE = {0.38, 0.84, 0.55}, OPEN = {0.32, 0.64, 1}, LOCKED = {0.8, 0.87, 0.93}, WHITE = {1, 1, 1}}

-- ---- state ----------------------------------------------------------------------------------------------------------
local B = nil          -- the board (VRFW_Chain.Board)
local focus = 1        -- focused tile (1-based)
local view = 0         -- first page on screen (0-based)
local cell = 100
local pos = {}         -- tile -> {x, y} for the tiles on screen
local slot_of = {}     -- tile -> pool instance (tile / emb / tag) while on screen
local tex_asked, tex_frames = {}, {}
local tex_wait = false
local ready = false
-- the input that opened this screen (Accept on the board) must not reach it.
local open_guard = 20
local evt_co = nil
local help_open = false
local pay_check = nil  -- the board whose late chest payouts were already looked for (Step)
-- a chain hub: its boards (VRFW_Chain.Hub), the list shown (mode "list") or one of its boards (mode "board")
local HUB = nil
local mode = "board"
local hfocus, htop = 1, 1

local function Log(...)
  pcall(funcLuaCommand, C.LOG, "chain_board", ...)
end

--@lib evt_menu_kit.lua#Call,Int,Hide

--@lib evt_menu_kit.lua#Pointer
local Ptr = EVT_PointerNew()

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

local function Place(layer, idx, x, y)
  funcLuaMenuCommand(C.POS, layer, x, -y, 0, idx)
end

local function QuadTex(layer, idx, texCrc, spriteCrc, x, y, w, h)
  funcLuaMenuCommand(C.LAYER_VISIBLE, layer, idx, true)
  funcLuaMenuCommand(C.SCALE, layer, w / G.Q, h / G.Q, 1, idx)
  funcLuaMenuCommand(C.SPRITE, layer, texCrc, spriteCrc, NODE_QUAD, 0, idx)
  Place(layer, idx, x, y)
end

local function Tint(layer, idx, c)
  funcLuaMenuCommand(C.PRIM_COLOR, layer, idx, MESH_QUAD, c[1], c[2], c[3])
end

-- ---- layout ---------------------------------------------------------------------------------------------------------
local function Pages()
  return math.max(1, #B.pages)
end

local function Shown(p)
  if Pages() == 1 then
    return p == 0 and 1 or nil
  end
  if p == view then
    return 1
  elseif p == view + 1 then
    return 2
  end
  return nil
end

local function OnScreen()
  return Pages() == 1 and 1 or 2
end

-- the left edge of the k-th page on screen (1 / 2)
local function PageLeft(k)
  local n = OnScreen()
  local w = (n * B.cols + (n - 1) * G.GAP) * cell
  return G.CX - w / 2 + (k - 1) * (B.cols + G.GAP) * cell
end

-- a hex board (the 3DS honeycomb): columns HEX_DX cells apart, the 2nd / 4th / … column half a row lower
local function HexLayout()
  cell = math.min(G.BOARD_W / ((B.cols - 1) * G.HEX_DX + 1), G.GRID_H / (B.rows + 0.5), G.CELL_MAX)
  local left = G.CX - (B.cols - 1) * G.HEX_DX * cell / 2
  local n = 0
  for t, tile in ipairs(B.tiles) do
    if Shown(tile.page) ~= nil and n < N.TILE then
      pos[t] = {left + tile.col * G.HEX_DX * cell, G.GRID_CY + (tile.row + (tile.col % 2) * 0.5 - B.rows / 2 + 0.25) * cell}
      slot_of[t] = n
      n = n + 1
    end
  end
end

local function Layout()
  pos, slot_of = {}, {}
  if B.layout == "hex" then
    return HexLayout()
  end
  local ns = OnScreen()
  cell = math.min(G.BOARD_W / (ns * B.cols + (ns - 1) * G.GAP), G.GRID_H / B.rows, G.CELL_MAX)
  local n = 0
  for t, tile in ipairs(B.tiles) do
    local k = Shown(tile.page)
    if k ~= nil and n < N.TILE then
      pos[t] = {PageLeft(k) + (tile.col + 0.5) * cell, G.GRID_CY + (tile.row - (B.rows - 1) / 2) * cell}
      slot_of[t] = n
      n = n + 1
    end
  end
end

-- ---- drawing --------------------------------------------------------------------------------------------------------
-- a texture the screen's res does not load (a crest, a mod's rank badge atlas): asked once; its crc, false while it
-- is still loading (Step redraws when it comes in) or nil when it never came in
local function Atlas(path)
  if path == VRFW_ScreenArt.PLAIN then
    return CRC32(path)            -- in the screen's res
  end
  if tex_frames[path] == -1 then
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

-- a picture by ROLE: the sprite a mod declares for it (VRFW_ScreenArt, its atlas loaded on demand: hidden while it
-- loads, Step redraws), else the role's plain fallback shape, tinted
local function Quad(layer, idx, role, x, y, w, h)
  local a = VRFW_ScreenArt.Role(ART_SCREEN, role)
  if a ~= nil then
    local tc = Atlas(a.atlas)
    if tc then
      QuadTex(layer, idx, tc, a.crc, x, y, w, h)
      return
    elseif tc == false then
      Hide(layer, idx)
      return
    end                           -- the atlas never came in: the fallback
  end
  local f = FALLBACK[role] or {"square", {1, 1, 1}}
  local tc, sc = VRFW_ScreenArt.Plain(f[1])
  QuadTex(layer, idx, tc, sc, x, y, w, h)
  Tint(layer, idx, f[2])
end

-- the background: the declared role "background" over the hidden retail menu background; none (or never loaded): the
-- retail background stays
local function DrawBackground()
  local a = VRFW_ScreenArt.Role(ART_SCREEN, "background")
  local tc = a ~= nil and Atlas(a.atlas) or nil
  if tc then
    QuadTex(L_BACK, 0, tc, a.crc, G.CX, 540, 1920, 1080)
  else
    Hide(L_BACK, 0)
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_RETAIL_BG, 0, a == nil or tc == nil)
end

local function Emblem(tile)
  if tile.emblem == "" then
    return nil
  end
  local tc = Atlas(EMB_DIR .. tile.emblem .. "_s.g4tx")
  if not tc then
    return tc                     -- false: still loading; nil: never came in (the "?" icon)
  end
  return tc, CRC32(tile.emblem .. "_s01")
end

-- a rank's badge (defaults\match_rank.toml Badge of its BadgeAtlas, a mod's own art; the framework declares no rank):
-- hidden when the rank has none or its atlas is not in (yet)
local function RankBadge(layer, idx, rdef, x, y, size)
  local tc = nil
  if rdef ~= nil and rdef.badge ~= "" and rdef.atlas ~= "" then
    tc = Atlas(rdef.atlas)
  end
  if tc then
    QuadTex(layer, idx, tc, CRC32(rdef.badge), x, y, size, size)
  else
    Hide(layer, idx)
  end
end

-- a double chest's icon: disabled = the padlocked chest; open = the open chest; base / A taken ("h" / "a")
-- = the S chest (padlocked until its next tier is earned); not opened yet = the chest (padlocked until reached)
local function DChestIcon(t)
  local st = VRFW_Chain.TileState(B, t)
  if VRFW_Chain.DChestEmpty(B, t) then
    return "icon_chest_locked"
  elseif st == "o" then
    return "icon_chest_open"
  elseif st == "h" or st == "a" then
    return VRFW_Chain.DChestReady(B, t) and "icon_schest" or "icon_schest_locked"
  end
  return VRFW_Chain.Open(B, t) and "icon_chest" or "icon_chest_locked"
end

local function DrawTile(t)
  local tile, p, s = B.tiles[t], pos[t], slot_of[t]
  local x, y = p[1], p[2]
  local ts, ic, bd = cell * G.TILE, cell * G.ICON, cell * G.BADGE
  local open = VRFW_Chain.Open(B, t)
  local st = VRFW_Chain.TileState(B, t)
  local plate, icon
  if tile.kind == "start" then
    plate, icon = "tile_start", "icon_start"
  elseif tile.kind == "slot" then
    plate, icon = "tile_hidden", false   -- a placeholder (no team yet): always the "?" plate
  elseif tile.kind == "blocked" then
    -- the 3DS "prohibited" sign on the chests' lavender plate; opened: the board's open gate
    plate = "tile_chest"
    icon = st ~= "0" and "icon_unblocked" or "icon_blocked"
  elseif tile.kind == "chest" or tile.kind == "schest" then
    -- a chest shows what it is from the start (IE3): on its lavender plate, padlocked until it opens, closed, open
    local pre = tile.kind == "schest" and "icon_schest" or "icon_chest"
    plate = "tile_chest"
    icon = st == "o" and pre .. "_open" or (open and pre or pre .. "_locked")
  elseif tile.kind == "dchest" then
    -- a double chest: the chest; once its base reward is taken ("h") the S chest, padlocked until the branch is all S
    plate = "tile_chest"
    icon = DChestIcon(t)
  elseif not open then
    plate, icon = "tile_hidden", false   -- a match not open yet: the "?" plate, no crest (IE3)
  else
    plate = st ~= "0" and "tile_done" or "tile_open"
  end
  Quad(L_TILE, s, plate, x, y, ts, ts)
  Tint(L_TILE, s, COLOUR.WHITE)   -- a hub's list tints its rows (the same pool)
  if icon == false then
    Hide(L_EMB, s)
  elseif icon == nil then
    local tc, sc = Emblem(tile)
    if tc == false then
      Hide(L_EMB, s)              -- still loading: Step draws it
    elseif tc == nil then
      Quad(L_EMB, s, "icon_unknown", x, y, ic, ic)
    else
      QuadTex(L_EMB, s, tc, sc, x, y, ic, ic)
    end
  else
    local ics = (tile.kind == "chest" or tile.kind == "schest" or tile.kind == "dchest" or tile.kind == "blocked") and ts * G.CHEST or ic   -- chests / signs fill their plate
    Quad(L_EMB, s, icon, x, y, ics, ics)
  end
  -- the best rank's badge (defaults\match_rank.toml Badge / BadgeAtlas: a mod's own ranks bring their art)
  local rid = tile.kind == "match" and VRFW_Chain.RankId(B, t) or nil
  local rdef = rid ~= nil and VRFW_MatchRank ~= nil and VRFW_MatchRank.ById(rid) or nil
  RankBadge(L_TAG, s, rdef, x + ts * 0.33, y + ts * 0.33, bd)
end

local function LinkColour(a, b)
  if VRFW_Chain.Done(B, a) and VRFW_Chain.Done(B, b) then
    return COLOUR.DONE
  elseif VRFW_Chain.Open(B, a) and VRFW_Chain.Open(B, b) then
    return COLOUR.OPEN
  end
  return COLOUR.LOCKED
end

local function Bar(li, x1, x2, y1, y2, c)
  if li >= N.LINE then
    return li
  end
  funcLuaMenuCommand(C.ROTATE, L_LINE, 0, 0, 0, li)   -- a pool bar may have been a diagonal before
  if math.abs(y1 - y2) < 1 then
    Quad(L_LINE, li, "line", (x1 + x2) / 2, y1, math.abs(x2 - x1), G.LINE)
  else
    Quad(L_LINE, li, "line", x1, (y1 + y2) / 2, G.LINE, math.abs(y2 - y1))
  end
  Tint(L_LINE, li, c)
  return li + 1
end

-- a link between two points: a straight bar, or (IE3's diagonal links) one bar rotated along the segment
local function Link(li, ax, ay, bx, by, c)
  if math.abs(ax - bx) >= 1 and math.abs(ay - by) >= 1 then
    if li >= N.LINE then
      return li
    end
    local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
    Quad(L_LINE, li, "line", (ax + bx) / 2, (ay + by) / 2, len, G.LINE)
    -- the layer's local z rotation (radians, y up as the layer positions): retail SetLayerLocalRotate
    funcLuaMenuCommand(C.ROTATE, L_LINE, 0, 0, math.atan2(-(by - ay), bx - ax), li)
    Tint(L_LINE, li, c)
    return li + 1
  end
  return Bar(li, ax, bx, ay, by, c)
end

local function DrawLinks()
  local li, ai = 0, N.ARROW0
  for a, tile in ipairs(B.tiles) do
    for _, b in ipairs(tile.links) do
      if a < b and (pos[a] ~= nil or pos[b] ~= nil) then
        local c = LinkColour(a, b)
        if pos[a] ~= nil and pos[b] ~= nil then
          -- on screen (one page, or the two pages side by side): drawn straight across, no arrow
          li = Link(li, pos[a][1], pos[a][2], pos[b][1], pos[b][2], c)
        else
          -- towards a page not on screen (3+ pages): a bar to the board's edge and an arrow beyond it
          local u, v = a, b
          if pos[u] == nil then
            u, v = b, a
          end
          local right = B.tiles[v].page > B.tiles[u].page
          local k = Shown(B.tiles[u].page)
          local edge = PageLeft(k) + (right and B.cols * cell or 0)
          li = Bar(li, pos[u][1], edge, pos[u][2], pos[u][2], c)
          if ai < N.UI then
            Quad(L_UI, ai, right and "arrow_r" or "arrow_l", edge + (right and 30 or -30), pos[u][2], G.ARROW, G.ARROW)
            ai = ai + 1
          end
        end
      end
    end
  end
  for i = li, N.LINE - 1 do
    Hide(L_LINE, i)
  end
  for i = ai, N.UI - 1 do
    Hide(L_UI, i)
  end
end

local function DrawPanels()
  -- no panels and no page titles (the board sits on the IE3 background, nothing above it)
  for k = 1, N.BG do
    Hide(L_BG, k - 1)
    Hide(L_UI, k)
  end
  if not help_open then
    for i = 0, N.TITLE - 1 do
      Hide(L_TITLE, i)
    end
  end
end

-- ---- the help window: the rank legend, one line per DECLARED rank (VRFW_MatchRank: its Badge left of its Text) ------
-- (opaque badges, a square flat panel as the card's): rows of LINE px, PAD above / below, the badge
-- centred BADGE_X px from the panel's left edge, the text from TEXT_X, a SEP px separator between two rows (the link
-- bar, tinted the plate's rim colour)
local HELP = {CX = 960, CY = 600, W = 860, LINE = 88, PAD = 20, BADGE = 64, BADGE_X = 56, TEXT_X = 642, SEP = 2,
              SEP_COLOUR = {0.192, 0.224, 0.451}}

local function DrawHelp()
  if not help_open then
    Hide(L_HELP, 0)
    for i = ICON_BADGE0, ICON_HELP_END - 1 do
      Hide(L_ICON, i)
    end
    for i = 0, N.TITLE - 1 do
      Hide(L_TITLE, i)
    end
    return
  end
  local list = VRFW_MatchRank ~= nil and VRFW_MatchRank.List() or {}
  local n = math.min(#list, N.TITLE, ICON_SEP0 - ICON_BADGE0)
  local left = HELP.CX - HELP.W / 2
  Quad(L_HELP, 0, "help_panel", HELP.CX, HELP.CY, HELP.W, n * HELP.LINE + 2 * HELP.PAD)
  for i = 1, n do
    local r = list[i]
    local y = HELP.CY + (i - (n + 1) / 2) * HELP.LINE
    RankBadge(L_ICON, ICON_BADGE0 + i - 1, r, left + HELP.BADGE_X, y, HELP.BADGE)
    local si = ICON_SEP0 + i - 2   -- the separator above every row but the first
    if i > 1 and si < ICON_HELP_END then
      Quad(L_ICON, si, "line", HELP.CX, y - HELP.LINE / 2, HELP.W - 32, HELP.SEP)
      Tint(L_ICON, si, HELP.SEP_COLOUR)
    end
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_TITLE, i - 1, true)
    funcLuaMenuCommand(C.TEXT, L_TITLE, TEXT_ON, r.text ~= "" and Text(CRC32(r.text)) or VRFW_MatchRank.Label(r.id), i - 1)
    funcLuaMenuCommand(C.TEXT_VISIBLE, L_TITLE, TEXT_ON, true, i - 1)
    Place(L_TITLE, i - 1, HELP.TEXT_X - TEXT_DX, y)
  end
  for i = ICON_BADGE0 + n, ICON_SEP0 - 1 do
    Hide(L_ICON, i)
  end
  for i = ICON_SEP0 + math.max(0, n - 1), ICON_HELP_END - 1 do
    Hide(L_ICON, i)
  end
  for i = n, N.TITLE - 1 do
    Hide(L_TITLE, i)
  end
end

local function SetHelp(on)
  help_open = on
  DrawHelp()
  Log(on and "help" or "help closed")
end

local function DrawCursor()
  local p = pos[focus]
  if p == nil then
    Hide(L_UI, 0)
    return
  end
  local r = cell * G.TILE * G.RING * 1.08
  Quad(L_UI, 0, "ring", p[1], p[2], r, r)
end

-- the retail guide line (bottom left) stays hidden: the team card says it all
local function HideGuideLine()
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_GUIDE_LINE, 0, false)
end

-- one line of the team card: left edge x, vertical centre y, text scale (nil s = hidden)
local function CardLine(i, s, x, y, scale)
  if s == nil or s == "" then
    Hide(L_CARDTXT, i)
    return
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_CARDTXT, i, true)
  funcLuaMenuCommand(C.SCALE, L_CARDTXT, scale, scale, 1, i)
  funcLuaMenuCommand(C.TEXT, L_CARDTXT, TEXT_ON, s, i)
  funcLuaMenuCommand(C.TEXT_VISIBLE, L_CARDTXT, TEXT_ON, true, i)
  Place(L_CARDTXT, i, x - TEXT_DX * scale, y)
end

-- a blocked tile's requirements as one line: "Win against X · Team level 80 (you have 45)" (menu_text rows per kind)
local function ReqText(tile)
  local parts = {}
  for _, r in ipairs(tile.requires or {}) do
    local row = T.REQ[r.kind]
    if row ~= nil then
      if r.kind == "team_level" then
        parts[#parts + 1] = Fmt(row, tonumber(r.value) or 0, VRFW_Chain.ReqHave(r))
      else
        parts[#parts + 1] = Fmt(row, r.name ~= "" and r.name or tostring(r.value))
      end
    end
  end
  return table.concat(parts, "  ·  ")
end

-- ---- the rewards box of a match tile ---------------------------------------------------------------------------------
-- a rank reward's shown name: the entry's `Text` row, else an emblem / kit by its kind, else the item's name; a reward
-- already received in this save says so
local function RewardName(r)
  local what = r.name
  if (r.text or 0) ~= 0 and Text(r.text) ~= "" then
    what = Text(r.text)                 -- the declared label (`Text`: a menu_text row)
  elseif r.kind == "emblem" then
    what = Text(T.PRIZE_EMBLEM)
  elseif r.kind == "kit" then
    what = Text(T.PRIZE_KIT)
  elseif what == nil or what == "" then
    what = Text(T.PRIZE_ITEM)
  end
  if r.paid then
    what = Fmt(T.REWARD_GOT, what)
  end
  return what
end

-- match tile t's rank rewards in rank order (the lower rank first), at most N.REWARD
local function SortedRewards(t)
  local list = {}
  for k, r in ipairs(VRFW_Chain.RankRewards ~= nil and VRFW_Chain.RankRewards(B, t) or {}) do
    list[#list + 1] = {r = r, k = k, order = VRFW_MatchRank ~= nil and VRFW_MatchRank.Order(r.rank) or 0}
  end
  table.sort(list, function(a, b)
    if a.order ~= b.order then
      return a.order < b.order
    end
    return a.k < b.k
  end)
  local out = {}
  for i = 1, math.min(#list, N.REWARD) do
    out[i] = list[i].r
  end
  return out
end

-- the items a match drops (the game's drop tables after the build): the reward preview groups first
-- (CMND_VRFW_DROP_PREVIEW), then the drop-rate list's order (CMND_VRFW_DROP_LIST_OF), at most N.DROP, kept per game row
local drops_of = {}
local function MatchDrops(tile)
  local game, difficulty = tonumber(tile.game) or 0, tonumber(tile.difficulty) or 0
  local key = game .. ":" .. difficulty
  if drops_of[key] ~= nil then
    return drops_of[key]
  end
  local out, seen = {}, {}
  local function add(id)
    if type(id) == "number" and id ~= 0 and not seen[id] and #out < N.DROP then
      seen[id] = true
      out[#out + 1] = id
    end
  end
  if game ~= 0 then
    local r = table.pack(pcall(funcLuaCommand, C.DROP_PREVIEW, game, N.DROP, difficulty))
    if r[1] then
      for k = 2, r.n do
        add(r[k])
      end
    end
    if #out < N.DROP then
      local q = table.pack(pcall(funcLuaCommand, C.DROP_LIST_OF, game, difficulty, 0, 4 * N.DROP))
      if q[1] then
        for k = 3, q.n, 2 do      -- total, then item, percent per row
          add(q[k])
        end
      end
    end
  end
  drops_of[key] = out
  Log("drops of game", game, "difficulty", difficulty, #out)
  return out
end

-- a box line's width at text scale 1: measured by the game, else estimated from its characters
local function LineWidth(i, s)
  funcLuaMenuCommand(C.SCALE, L_CARDTXT, 1, 1, 1, i)
  local ok, w = pcall(funcLuaMenuCommand, C.TEXT_SIZE, L_CARDTXT, i, TEXT_ON, s)
  if ok and type(w) == "number" and w > 0 then
    return w
  end
  local chars = string.gsub(s, "[\128-\191]", "")
  return #chars * BOX.GLYPH_W
end

-- an item's own game icon on a transparent quad (the "?" icon when the game has none)
local function ItemIcon(idx, item, x, y, size, tint)
  local tc, sc = VRFW_ScreenArt.Plain("blank")
  QuadTex(L_ICON, idx, tc, sc, x, y, size, size)
  local ok, r = pcall(funcLuaMenuCommand, C.ITEM_ICON, L_ICON, idx, MESH_QUAD, NODE_QUAD, item)
  if not ok or r == false then
    Quad(L_ICON, idx, "icon_unknown", x, y, size, size)
    return
  end
  Tint(L_ICON, idx, tint)
end

local function HideRewardsBox()
  Hide(L_CARD, 1)
  for i = ICON_REWARD0, N.ICON - 1 do
    Hide(L_ICON, i)
  end
  for i = TXT_REWARD0, N.CARDTXT - 1 do
    Hide(L_CARDTXT, i)
  end
end

-- match tile t's rewards box centred on cx: the rank rewards in one row (badge, item icon, name; when the names do
-- not fit the row they shrink by one factor), a thin line, then the match's drops in a 2 x 2 grid, each «???» with
-- the "?" icon. Nothing to show: no box.
local function DrawRewardsBox(t, cx)
  local tile = B.tiles[t]
  local rewards, drops = SortedRewards(t), MatchDrops(tile)
  if #rewards == 0 and #drops == 0 then
    HideRewardsBox()
    return
  end
  Quad(L_CARD, 1, "card", cx, CARD.CY, BOX.W, CARD.H)
  local left, top, row_w = cx - BOX.W / 2 + BOX.PAD, CARD.CY - CARD.H / 2, BOX.W - 2 * BOX.PAD
  -- the rank rewards: each in its share of the row, moved right when the name before it is longer than its share
  local n = #rewards
  local names, widths, total = {}, {}, 0
  for i = 1, n do
    names[i] = RewardName(rewards[i])
    widths[i] = LineWidth(TXT_REWARD0 + i - 1, names[i]) * BOX.NAME_S
    total = total + widths[i]
  end
  local room = row_w - n * BOX.NAME_DX - math.max(0, n - 1) * BOX.GAP
  local k = (total > room and total > 0) and room / total or 1
  local x, y = left, top + BOX.ROW_Y
  for i = 1, N.REWARD do
    local r = rewards[i]
    local badge, icon = ICON_REWARD0 + 2 * (i - 1), ICON_REWARD0 + 2 * (i - 1) + 1
    if r == nil then
      Hide(L_ICON, badge)
      Hide(L_ICON, icon)
      CardLine(TXT_REWARD0 + i - 1, nil)
    else
      if k == 1 then
        -- its share's start, unless the rewards from here on would then run past the row's end
        local rest = (n - i) * BOX.GAP
        for j = i, n do
          rest = rest + BOX.NAME_DX + widths[j]
        end
        x = math.max(x, math.min(left + (i - 1) * row_w / n, left + row_w - rest))
      end
      local tint = r.paid and BOX.PAID_TINT or COLOUR.WHITE
      local rdef = VRFW_MatchRank ~= nil and VRFW_MatchRank.ById(r.rank) or nil
      RankBadge(L_ICON, badge, rdef, x + BOX.BADGE / 2, y, BOX.BADGE)
      Tint(L_ICON, badge, tint)
      ItemIcon(icon, r.id, x + BOX.ICON_DX + BOX.ICON / 2, y, BOX.ICON, tint)
      CardLine(TXT_REWARD0 + i - 1, names[i], x + BOX.NAME_DX, y, BOX.NAME_S * k)
      x = x + BOX.NAME_DX + widths[i] * k + BOX.GAP
    end
  end
  -- the line between the two parts, only when both have something
  if n > 0 and #drops > 0 then
    Quad(L_ICON, ICON_RULE, "line", cx, top + BOX.RULE_Y, row_w, BOX.RULE)
    Tint(L_ICON, ICON_RULE, BOX.RULE_COLOUR)
  else
    Hide(L_ICON, ICON_RULE)
  end
  -- the drops: two columns, row by row
  for j = 1, N.DROP do
    if drops[j] == nil then
      Hide(L_ICON, ICON_DROP0 + j - 1)
      CardLine(TXT_DROP0 + j - 1, nil)
    else
      local dx = left + ((j - 1) % 2) * row_w / 2
      local dy = top + BOX.DROP_Y + math.floor((j - 1) / 2) * BOX.DROP_PITCH
      Quad(L_ICON, ICON_DROP0 + j - 1, "icon_unknown", dx + BOX.DROP_ICON / 2, dy, BOX.DROP_ICON, BOX.DROP_ICON)
      CardLine(TXT_DROP0 + j - 1, Text(T.DROP_UNKNOWN), dx + BOX.DROP_NAME_DX, dy, BOX.NAME_S)
    end
  end
end

-- the focused tile's card above the board: panel, up to 3 lines (the first one large), the crest / icon on the right
local function DrawCard()
  local tile = B and B.tiles[focus]
  if tile == nil then
    Hide(L_CARD, 0)
    Hide(L_ICON, ICON_CREST)
    for i = 0, N.CARDTXT - 1 do
      Hide(L_CARDTXT, i)
    end
    HideRewardsBox()
    return
  end
  local cx = CARD.BOARD_CX
  Quad(L_CARD, 0, "card", cx, CARD.CY, CARD.W, CARD.H)
  local open = VRFW_Chain.Open(B, focus)
  local st = VRFW_Chain.TileState(B, focus)
  local lines, icon = {}, "icon_unknown"
  if tile.kind == "match" and open then
    lines = {tile.rival, Fmt(T.CARD_LEVEL, tile.level)}
    local r = VRFW_Chain.RankId(B, focus)
    if r ~= nil then
      lines[2] = lines[2] .. "  ·  " .. Fmt(T.RANK, VRFW_MatchRank.Label(r))
    end
    -- the tile's match challenge ([[VRFW.MatchChallenge]]): on the level's line,
    -- right of it after a "|"
    local mc = VRFW_MC and VRFW_MC.TitleOf(tile.game)
    lines[2] = lines[2] .. "  |  " .. (mc ~= nil and Fmt(T.CARD_REQ, mc) or Text(T.CARD_REQ_NONE))
    -- the save's wins against this team (VRFW_Stats, at least 1 once the tile is won)
    lines[3] = Fmt(T.CARD_WINS, VRFW_Chain.WinsVs(B, focus))
    icon = nil
  elseif tile.kind == "match" then
    lines = {Text(T.CARD_UNKNOWN), Fmt(T.CARD_LEVEL, tile.level), Text(T.LOCKED)}   -- not open yet: the team stays hidden
  elseif tile.kind == "slot" then
    lines = {Text(T.SLOT)}
  elseif tile.kind == "blocked" then
    local status
    if st ~= "0" then
      status = Text(T.BLOCKED_OPEN)
    elseif VRFW_Chain.Unblocked(B, focus) then
      status = Text(T.LOCKED)                      -- met: it opens once a tile joined to it is won
    else
      status = Text(T.BLOCKED_RULE)
    end
    lines = {Text(T.CARD_BLOCKED), Fmt(T.CARD_REQ, ReqText(tile)), status}
    icon = st ~= "0" and "icon_unblocked" or "icon_blocked"
  elseif tile.kind == "schest" then
    lines = {Text(T.CARD_SCHEST), st == "o" and Text(T.CHEST_OPEN) or Text(T.CARD_SCHEST_RULE)}
    icon = st == "o" and "icon_schest_open" or (open and "icon_schest" or "icon_schest_locked")
  elseif tile.kind == "dchest" then
    local status
    if VRFW_Chain.DChestEmpty(B, focus) then
      status = Text(T.DCHEST_EMPTY)
    elseif st == "o" then
      status = Text(T.CHEST_OPEN)
    elseif VRFW_Chain.DChestReady(B, focus) then
      status = Text(T.CARD_CHEST)
    elseif st == "h" or st == "a" then
      status = Text(VRFW_Chain.DChestWaits(B, focus) == "a" and T.DCHEST_HALF_A or T.DCHEST_HALF)
    elseif open then
      -- no base reward: it waits for the A / S
      status = Text(VRFW_Chain.DChestWaits(B, focus) == "a" and T.CARD_ACHEST_RULE or T.CARD_SCHEST_RULE)
    else
      status = Text(T.LOCKED)
    end
    lines = {Text(T.CARD_DCHEST), status}
    if not VRFW_Chain.DChestEmpty(B, focus) and st ~= "o" then
      lines[3] = Text((tile.areward or "") ~= "" and T.DCHEST_RULE_A or T.DCHEST_RULE)
    end
    icon = DChestIcon(focus)
  elseif tile.kind == "chest" then
    lines = {Text(T.CHEST), st == "o" and Text(T.CHEST_OPEN) or Text(open and T.CARD_CHEST or T.LOCKED)}
    icon = st == "o" and "icon_chest_open" or (open and "icon_chest" or "icon_chest_locked")
  else
    lines = {Text(T.START)}
    local avg = VRFW_Chain.Average(B)
    if avg ~= nil then
      lines[2] = Fmt(T.CHAIN_RANK, VRFW_MatchRank.Label(avg))
    end
    icon = "icon_start"
  end
  -- the first line always in the plate's lighter upper band; two lines: the second one centred in the lower part
  local ys = {CARD.NAME_Y, CARD.LINE1_Y, CARD.LINE2_Y}
  if #lines == 2 then
    ys = {CARD.NAME_Y, (CARD.LINE1_Y + CARD.LINE2_Y) / 2}
  end
  local x = cx - CARD.W / 2 + CARD.TEXT_DX
  for i = 0, TXT_REWARD0 - 1 do
    CardLine(i, lines[i + 1], x, ys[i + 1] or CARD.CY, i == 0 and CARD.NAME_S or CARD.LINE_S)
  end
  -- an open match tile: its rank rewards and drops in the box at the card's right
  if tile.kind == "match" and open then
    DrawRewardsBox(focus, BOX.CX)
  else
    HideRewardsBox()
  end
  local ix = cx + CARD.W / 2 - CARD.CREST_DX
  if icon == nil then
    local tc, sc = Emblem(tile)
    if tc == false then
      Hide(L_ICON, ICON_CREST)     -- still loading: Step redraws
    elseif tc == nil then
      Quad(L_ICON, ICON_CREST, "icon_unknown", ix, CARD.CY, CARD.CREST, CARD.CREST)
    else
      QuadTex(L_ICON, ICON_CREST, tc, sc, ix, CARD.CY, CARD.CREST, CARD.CREST)
    end
  else
    Quad(L_ICON, ICON_CREST, icon, ix, CARD.CY, CARD.CREST, CARD.CREST)
  end
end

local function UpdateTitle()
  local title = B and B.title or ""
  if mode == "list" then
    title = Text(T.HUB_TITLE)
  end
  funcLuaMenuCommand(C.TEXT, L_HEADER, 1220590795 --[[_text_sub_title02]], title, 0)
end

local function UpdateButtonGuide()
  if mode == "list" then
    funcLuaMenuCommand(C.GUIDE_SET, MENU, L_BTN_GUIDE, {G_ACCEPT}, {I_ENTER}, {18}, {}, {})
    funcLuaMenuCommand(C.GUIDE_CMD, MENU, L_BTN_GUIDE, {K_ENTER})
  else
    funcLuaMenuCommand(C.GUIDE_SET, MENU, L_BTN_GUIDE, {T.HELP_BTN, G_ACCEPT}, {I_FUNC2, I_ENTER}, {0, 18}, {}, {})
    funcLuaMenuCommand(C.GUIDE_CMD, MENU, L_BTN_GUIDE, {K_FUNC2, K_ENTER})
  end
  funcLuaMenuCommand(C.GUIDE_OPT, MENU, L_BTN_GUIDE, false)
end

-- ---- the chain hub's list ------------------------------------------------------------
-- One row per chain of the hub, ROWS at a time (scrolling): a flat plate (the team card's sprite), the crest of the
-- chain's last match tile (its final rival), "<title>   n / m" (won match tiles / match tiles) and the chain's rank
-- badge once it is complete; the focused row is tinted, its card above the list. Accept opens that chain's board (as a
-- board opened on its own); Back on the board returns here, Back here closes the screen.
local LIST = {CX = 960, TOP = 380, ROW = 86, W = 1040, H = 74, ROWS = 7, CREST = 62, CREST_DX = 52, TEXT_DX = 104,
              BADGE = 48, BADGE_DX = 52}
local LIST_TINT = {FOCUS = {1, 1, 1}, DONE = {0.62, 0.85, 0.66}, PLAIN = {0.72, 0.74, 0.82}}   -- the focused row the brightest

local function ListRows()
  return math.min(LIST.ROWS, N.TITLE, N.TILE)
end

-- the crest of a chain in the list: its last match tile's (the chain's final rival)
local function ChainCrestTile(b)
  for t = #b.tiles, 1, -1 do
    if b.tiles[t].kind == "match" then
      return b.tiles[t]
    end
  end
  return nil
end

local function DrawCrest(layer, idx, tile, x, y, size)
  local tc, sc = nil, nil
  if tile ~= nil then
    tc, sc = Emblem(tile)
  end
  if tc == false then
    Hide(layer, idx)                -- still loading: Step redraws
  elseif tc == nil then
    Quad(layer, idx, "icon_unknown", x, y, size, size)
  else
    QuadTex(layer, idx, tc, sc, x, y, size, size)
  end
end

local function DrawHubCard()
  local b = HUB[hfocus]
  Quad(L_CARD, 0, "card", CARD.CX, CARD.CY, CARD.W, CARD.H)
  local line2 = Fmt(T.HUB_MATCHES, VRFW_Chain.Won(b), b.matches)
  local avg = VRFW_Chain.Average(b)
  if avg ~= nil then
    line2 = Fmt(T.CHAIN_RANK, VRFW_MatchRank.Label(avg))   -- "Cadena superada · Rango: X"
  end
  local lines = {b.title, line2, Text(T.HUB_OPEN)}
  local ys = {CARD.NAME_Y, CARD.LINE1_Y, CARD.LINE2_Y}
  for i = 0, TXT_REWARD0 - 1 do
    CardLine(i, lines[i + 1], CARD.CX - CARD.W / 2 + CARD.TEXT_DX, ys[i + 1], i == 0 and CARD.NAME_S or CARD.LINE_S)
  end
  HideRewardsBox()
  DrawCrest(L_ICON, ICON_CREST, ChainCrestTile(b), CARD.CX + CARD.W / 2 - CARD.CREST_DX, CARD.CY, CARD.CREST)
end

DrawList = function()
  tex_wait = false
  pos, slot_of = {}, {}
  DrawBackground()
  for s = 0, N.TILE - 1 do
    Hide(L_TILE, s)
    Hide(L_EMB, s)
    Hide(L_TAG, s)
  end
  for i = 0, N.LINE - 1 do
    Hide(L_LINE, i)
  end
  for i = 0, N.UI - 1 do
    Hide(L_UI, i)
  end
  for i = 0, N.BG - 1 do
    Hide(L_BG, i)
  end
  Hide(L_HELP, 0)
  for i = ICON_BADGE0, N.ICON - 1 do
    Hide(L_ICON, i)
  end
  local left = LIST.CX - LIST.W / 2
  local rows = ListRows()
  for k = 0, rows - 1 do
    local i = htop + k
    local b = HUB[i]
    if b == nil then
      Hide(L_TITLE, k)
    else
      local y = LIST.TOP + k * LIST.ROW
      Quad(L_TILE, k, "card", LIST.CX, y, LIST.W, LIST.H)
      Tint(L_TILE, k, i == hfocus and LIST_TINT.FOCUS or (VRFW_Chain.Complete(b) and LIST_TINT.DONE or LIST_TINT.PLAIN))
      DrawCrest(L_EMB, k, ChainCrestTile(b), left + LIST.CREST_DX, y, LIST.CREST)
      funcLuaMenuCommand(C.LAYER_VISIBLE, L_TITLE, k, true)
      funcLuaMenuCommand(C.SCALE, L_TITLE, 1, 1, 1, k)
      funcLuaMenuCommand(C.TEXT, L_TITLE, TEXT_ON, b.title .. "   " .. VRFW_Chain.Won(b) .. " / " .. b.matches, k)
      funcLuaMenuCommand(C.TEXT_VISIBLE, L_TITLE, TEXT_ON, true, k)
      Place(L_TITLE, k, left + LIST.TEXT_DX - TEXT_DX, y)
      local avg = VRFW_Chain.Average(b)
      local rdef = avg ~= nil and VRFW_MatchRank ~= nil and VRFW_MatchRank.ById(avg) or nil
      RankBadge(L_TAG, k, rdef, left + LIST.W - LIST.BADGE_DX, y, LIST.BADGE)
      pos[i] = {LIST.CX, y}
    end
  end
  for k = rows, N.TITLE - 1 do
    Hide(L_TITLE, k)
  end
  -- more chains above / below: the board's page arrow, turned up / down
  local ai = N.ARROW0
  if htop > 1 then
    Quad(L_UI, ai, "arrow_r", LIST.CX, LIST.TOP - LIST.ROW * 0.62, G.ARROW, G.ARROW)
    funcLuaMenuCommand(C.ROTATE, L_UI, 0, 0, math.pi / 2, ai)
    ai = ai + 1
  end
  if htop + rows - 1 < #HUB then
    Quad(L_UI, ai, "arrow_r", LIST.CX, LIST.TOP + (rows - 0.38) * LIST.ROW, G.ARROW, G.ARROW)
    funcLuaMenuCommand(C.ROTATE, L_UI, 0, 0, -math.pi / 2, ai)
  end
  HideGuideLine()
  DrawHubCard()
  Ptr.Forget()
end

local function SetHubFocus(i, sound)
  if HUB == nil or i == nil or i < 1 or i > #HUB or i == hfocus then
    return
  end
  hfocus = i
  local rows = ListRows()
  if hfocus < htop then
    htop = hfocus
  elseif hfocus > htop + rows - 1 then
    htop = hfocus - rows + 1
  end
  if sound then
    funcLuaCommand(C.SE, SE_OK)
  end
  DrawList()
end

-- the focus a board opens on: the first open match not won yet, else the start
local function FirstFocus()
  -- blocked tiles whose requirements are met now (a win elsewhere, a level up, a signing) open before drawing
  for _, t in ipairs(VRFW_Chain.Sync(B)) do
    Log("unblocked", B.key, B.tiles[t].id)
  end
  focus = B.start
  for t, tile in ipairs(B.tiles) do
    if tile.kind == "match" and VRFW_Chain.Open(B, t) and not VRFW_Chain.Done(B, t) then
      focus = t
      break
    end
  end
  view = math.max(0, math.min(B.tiles[focus].page, Pages() - 2))
end

local DrawAll   -- defined below (ShowBoard / ShowList call it)

-- a hub: its list <-> one of its boards
local function ShowBoard(b)
  B = b
  mode = "board"
  help_open = false
  FirstFocus()
  for k = 0, N.TITLE - 1 do
    Hide(L_TITLE, k)
  end
  for i = 0, N.UI - 1 do
    funcLuaMenuCommand(C.ROTATE, L_UI, 0, 0, 0, i)   -- the list's turned arrows back straight
  end
  UpdateTitle()
  UpdateButtonGuide()
  DrawAll()
  Log("hub board", B.key, "state", VRFW_Chain.State(B))
end

local function ShowList()
  mode = "list"
  help_open = false
  UpdateTitle()
  UpdateButtonGuide()
  DrawAll()
end

local DrawList

DrawAll = function()
  if mode == "list" then
    return DrawList()
  end
  if B == nil then
    return
  end
  tex_wait = false
  DrawBackground()
  Layout()
  DrawPanels()
  for s = 0, N.TILE - 1 do
    Hide(L_TILE, s)
    Hide(L_EMB, s)
    Hide(L_TAG, s)
  end
  for t in pairs(pos) do
    DrawTile(t)
  end
  DrawLinks()
  DrawCursor()
  HideGuideLine()
  DrawCard()
  DrawHelp()
  Ptr.Forget()
end

-- ---- actions --------------------------------------------------------------------------------------------------------
--@lib evt_menu_kit.lua#Ask,Message,ItemGet,Close

-- chest t's declared rewards (VRFW_Chain.Pay): the retail window per item, a message per player; false = nothing was
-- declared (or already paid)
local function PayChest(t)
  local given, why = VRFW_Chain.Pay(B, t)
  if given == nil then
    if why == "full" then
      funcLuaCommand(C.SE, SE_NG)
      Message(Text(T.CHEST_FULL))
      return true
    end
    return false
  end
  for _, r in ipairs(given) do
    funcLuaCommand(C.SE, SE_DECIDE)
    if r.kind == "item" then
      ItemGet(r.id)
    else
      Message(Text(T.CHEST_PLAYER))
    end
  end
  return #given > 0
end

-- chests opened before their rewards were paid (an older save, a full bag): paid when the board is shown; then the
-- rank rewards of matches won since the board was last shown (VRFW_Chain.News: already given, one window per item)
-- and the ones a full bag held back (VRFW_Chain.RankUnpaid: paid now)
local function PayPending()
  for _, t in ipairs(VRFW_Chain.Unpaid(B)) do
    Log("chest pays late", B.key, B.tiles[t].id)
    PayChest(t)
  end
  if VRFW_Chain.News == nil then
    return
  end
  for _, t in ipairs(VRFW_Chain.RankUnpaid(B)) do
    Log("rank reward pays late", B.key, B.tiles[t].id)
    local given = VRFW_Chain.PayRank(B, t, true)
    if given == nil then
      funcLuaCommand(C.SE, SE_NG)
      Message(Text(T.RANK_FULL))
      break
    end
  end
  local news = VRFW_Chain.News(B)
  VRFW_Chain.ClearNews(B)
  for _, r in ipairs(news) do
    funcLuaCommand(C.SE, SE_DECIDE)
    ItemGet(r.id)
  end
  if #news > 0 then
    DrawCard()
  end
end

local function Decide()
  local tile = B and B.tiles[focus]
  if tile == nil or tile.kind == "start" then
    funcLuaCommand(C.SE, SE_OK)
    return
  end
  if tile.kind == "slot" then
    funcLuaCommand(C.SE, SE_NG)
    Message(Text(T.SLOT))
    return
  end
  if tile.kind == "blocked" then
    if VRFW_Chain.Done(B, focus) then
      funcLuaCommand(C.SE, SE_OK)
      return
    end
    funcLuaCommand(C.SE, SE_NG)
    Log("blocked", tile.id)
    Message(Fmt(T.BLOCKED_MSG, ReqText(tile)))
    return
  end
  if tile.kind == "dchest" and VRFW_Chain.DChestEmpty(B, focus) then
    funcLuaCommand(C.SE, SE_NG)
    Log("dchest disabled", tile.id)
    Message(Text(T.DCHEST_EMPTY))
    return
  end
  if not VRFW_Chain.Open(B, focus) then
    funcLuaCommand(C.SE, SE_NG)
    Log("locked", tile.id)
    Message(Text(tile.kind == "schest" and T.SCHEST or T.LOCKED_MSG))
    return
  end
  if tile.kind == "dchest" then
    local st = VRFW_Chain.TileState(B, focus)
    if st == "o" then
      funcLuaCommand(C.SE, SE_OK)
      return
    end
    if not VRFW_Chain.DChestReady(B, focus) then
      funcLuaCommand(C.SE, SE_NG)
      local waits = VRFW_Chain.DChestWaits(B, focus)
      Log("dchest waits for", waits, tile.id, st)
      if st == "h" or st == "a" then
        Message(Text(waits == "a" and T.DCHEST_HALF_A or T.DCHEST_HALF))
      else
        Message(Text(waits == "a" and T.CARD_ACHEST_RULE or T.SCHEST))
      end
      return
    end
    funcLuaCommand(C.SE, SE_DECIDE)
    VRFW_Chain.OpenChest(B, focus)
    DrawAll()
    if not PayChest(focus) then
      Message(Text(T.CHEST_OPENED))
    end
    return
  end
  if tile.kind == "chest" or tile.kind == "schest" then
    if VRFW_Chain.Done(B, focus) then
      funcLuaCommand(C.SE, SE_OK)
      return
    end
    funcLuaCommand(C.SE, SE_DECIDE)
    VRFW_Chain.OpenChest(B, focus)
    DrawAll()
    if not PayChest(focus) then
      Message(Text(T.CHEST_OPENED))
    end
    return
  end
  -- the tile's match challenge: the active dock must meet it (VRFW_MC)
  local refusal = VRFW_MC and VRFW_MC.Refusal(tile.game, 0)
  if refusal ~= nil then
    funcLuaCommand(C.SE, SE_NG)
    Log("challenge refused", tile.id)
    Message(refusal)
    return
  end
  funcLuaCommand(C.SE, SE_DECIDE)
  if not Ask(Fmt(T.ASK, tile.rival, tile.level)) then
    Log("match declined", tile.id)
    return
  end
  Log("match", B.key, tile.id, "game", tile.game, "difficulty", tile.difficulty, "level", tile.level)
  funcLuaCommand(C.P_CLEAR, KEY_PICK_CHAIN)
  if HUB ~= nil then
    funcLuaCommand(C.P_SET, KEY_PICK_CHAIN, 0, B.i + 1, 1)   -- the opener plays the tile of THIS chain
  end
  Close(focus)
end

local function SetFocus(t, sound)
  if B == nil or t == nil or t < 1 or t > #B.tiles or t == focus then
    return
  end
  focus = t
  if sound then
    funcLuaCommand(C.SE, SE_OK)
  end
  local p = B.tiles[t].page
  if Shown(p) == nil then
    view = p < view and p or math.max(0, p - 1)
    DrawAll()
    return
  end
  DrawCursor()
  DrawCard()
end

-- every tile (open or not) can be visited; left / right along its row first (across pages), up / down by column
local function VX(t)
  local tile = B.tiles[t]
  if B.layout == "hex" then
    return tile.col, tile.row + (tile.col % 2) * 0.5   -- the honeycomb's half rows: right / left steps to the nearest
  end
  return tile.page * (B.cols + 1.5) + tile.col, tile.row
end

local function MoveFocus(dx, dy)
  if B == nil then
    return
  end
  local x, y = VX(focus)
  local best, bd = nil, nil
  for pass = 1, 2 do
    for j = 1, #B.tiles do
      if j ~= focus then
        local jx, jy = VX(j)
        local ok
        if dx ~= 0 then
          ok = (jx - x) * dx > 0 and (pass == 2 or math.abs(jy - y) < 0.01)
        else
          ok = (jy - y) * dy > 0 and (pass == 2 or math.abs(jx - x) < 0.01)
        end
        if ok then
          local d = math.abs(jx - x) + math.abs(jy - y) * (dx ~= 0 and 2 or 1)
          if bd == nil or d < bd then
            best, bd = j, d
          end
        end
      end
    end
    if best ~= nil then
      break
    end
  end
  SetFocus(best, true)
end

--@lib evt_menu_kit.lua#StartCo

local function PollPointer()
  Ptr.Begin()
  local hw = cell * G.TILE / 2
  for t, p in pairs(pos) do
    if mode == "list" then
      Ptr.Box(p[1], p[2], LIST.W / 2, LIST.H / 2, t)
    else
      Ptr.Box(p[1], p[2], hw, hw, t)
    end
  end
  local ev = Ptr.Poll()
  if evt_co ~= nil or not ready or open_guard > 0 then
    return
  end
  if mode == "list" then
    if type(ev.hover) == "number" and ev.hover ~= hfocus then
      SetHubFocus(ev.hover, true)
    end
    if type(ev.click) == "number" then
      SetHubFocus(ev.click, false)
      funcLuaCommand(C.SE, SE_DECIDE)
      ShowBoard(HUB[hfocus])
    end
    return
  end
  if help_open then
    if ev.click ~= nil then
      SetHelp(false)
    end
    return
  end
  if type(ev.hover) == "number" and ev.hover ~= focus then
    SetFocus(ev.hover, true)
  end
  if type(ev.click) == "number" then
    SetFocus(ev.click, false)
    StartCo(Decide)
  end
end

-- ---- engine callbacks -----------------------------------------------------------------------------------------------
function OnInit()
  funcLuaCommand(C.P_CLEAR, KEY_RESULT)
  funcLuaCommand(C.P_CLEAR, KEY_PICK_CHAIN)
  for _, path in ipairs(VRFW_ScreenArt.Atlases(ART_SCREEN)) do
    Atlas(path)                   -- the declared art's atlases, asked now (drawn once in)
  end
  ready = false
  open_guard = 20
  B = nil
  pay_check = nil
  local i = -1
  if funcLuaCommand(C.P_EXISTS, KEY_CHAIN) then
    i = Int(funcLuaCommand(C.P_GET, KEY_CHAIN))
    funcLuaCommand(C.P_CLEAR, KEY_CHAIN)
  end
  HUB, mode, hfocus, htop = nil, "board", 1, 1
  local hub_slot = nil
  if funcLuaCommand(C.P_EXISTS, KEY_HUB) then
    hub_slot = Int(funcLuaCommand(C.P_GET, KEY_HUB))
    funcLuaCommand(C.P_CLEAR, KEY_HUB)
  end
  if VRFW_Chain == nil then
    Log("error", "VRFW_Chain missing (the menu part's lua\\_all\\30_chain.lua did not run in this VM)")
  else
    B = VRFW_Chain.Board(i)
    if hub_slot ~= nil and VRFW_Chain.Hub ~= nil then
      HUB = VRFW_Chain.Hub(hub_slot)
    end
  end
  if HUB ~= nil then
    -- a chain hub: its list first, the focus on its first chain not complete yet
    mode = "list"
    for k, b in ipairs(HUB) do
      if not VRFW_Chain.Complete(b) then
        hfocus = k
        break
      end
    end
    htop = math.max(1, math.min(hfocus, #HUB - ListRows() + 1))
    B = HUB[hfocus]
    Log("open hub", hub_slot, "chains", #HUB, "focus", B.key)
    return
  end
  if B == nil then
    Log("open", "chain", i, "no board: closing")
    return
  end
  FirstFocus()
  Log("open", B.key, "tiles", #B.tiles, "pages", Pages(), "state", VRFW_Chain.State(B), "focus", B.tiles[focus].id, "rank", VRFW_Chain.Average(B))
end

-- the tile plates keep no engine mouse zone: the Lua hit test (Ptr) owns hover and click, so the engine never moves
-- its focus (and plays its focus sound) on a hovered plate
local function DropEngineZone(layer, idx)
  pcall(funcLuaMenuCommand, C.HIT_ZONE, layer, idx, false)
  pcall(funcLuaMenuCommand, C.HOVER_FOCUS, layer, idx, false)
end

local function OpenOwnLayers()
  for i = 0, N.BG - 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_BG, i)
  end
  for i = 0, N.LINE - 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_LINE, i)
  end
  for i = 0, N.TILE - 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_TILE, i)
    DropEngineZone(L_TILE, i)
    funcLuaMenuCommand(C.OPEN_LAYER, L_EMB, i)
    funcLuaMenuCommand(C.OPEN_LAYER, L_TAG, i)
  end
  for i = 0, N.UI - 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_UI, i)
  end
  for i = 0, N.TITLE - 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_TITLE, i)
  end
  funcLuaMenuCommand(C.OPEN_LAYER, L_BACK, 0)
  for i = 0, N.HELP - 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_HELP, i)
  end
  for i = 0, N.CARD - 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_CARD, i)
  end
  for i = 0, N.CARDTXT - 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_CARDTXT, i)
  end
  for i = 0, N.ICON - 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_ICON, i)
  end
end

function OnSetupLayer(a1, a2)
  if a1 == L_HEADER then
    SetupSoccerTopCommonHeaderLayerInfo(a1, 4153539961, 253801632, 3969848060, 1144161661, 3293713115, 253801632, 1152304044, 305955024, 3007971317)
    UpdateHeader(3586861540)
    UpdateTitle()
    OpenOwnLayers()
  elseif a1 == L_ROW or a1 == L_TITLE or a1 == L_CARDTXT then
    -- the list item: no plate, no cursor; the anchor (L_ROW) shows nothing, a help line (L_TITLE) only its text
    funcLuaMenuCommand(C.TEXT, a1, TEXT_ON, "", a2)
    funcLuaMenuCommand(C.TEXT, a1, TEXT_OFF, "", a2)
    funcLuaMenuCommand(C.TEXT_VISIBLE, a1, TEXT_ON, a1 ~= L_ROW, a2)
    funcLuaMenuCommand(C.TEXT_VISIBLE, a1, TEXT_OFF, false, a2)
    for _, m in ipairs(ROW_MESHES) do
      funcLuaMenuCommand(C.MESH_VISIBLE, a1, m, false, a2)
    end
    funcLuaMenuCommand(C.ATTACH_TRACE, a1, a2, CUR, false)
    if a1 ~= L_ROW then
      Hide(a1, a2)
    end
  elseif a1 == L_RETAIL_BG then
    -- hidden when a mod declares the background (role background, DrawBackground); else the retail one stays
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, VRFW_ScreenArt.Role(ART_SCREEN, "background") == nil)
  elseif a1 == L_BG or a1 == L_LINE or a1 == L_TILE or a1 == L_EMB or a1 == L_TAG or a1 == L_UI or a1 == L_BACK or a1 == L_HELP
      or a1 == L_CARD or a1 == L_ICON then
    Hide(a1, a2)                -- DrawAll draws what is used when the anchor opens
    if a1 == L_TILE then
      DropEngineZone(a1, a2)
    end
  elseif a1 == L_GUIDE_LINE then
    HideGuideLine()
  elseif a1 == L_BTN_GUIDE then
    UpdateButtonGuide()
  end
end

function OnOpenLayer(a1, a2)
  if a1 == L_ROW and a2 == 0 then
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_CURSOR, 0, false)
    funcLuaMenuCommand(C.FOCUS_ENABLE, a1, true)
    funcLuaMenuCommand(C.LIST_NUM, a1, 1)
    funcLuaMenuCommand(C.FOCUS_SET, a1, 0)
    funcLuaMenuCommand(C.ATTACH_TRACE, a1, 0, CUR, false)
    funcLuaMenuCommand(C.POS, a1, -4000, 4000, 0, 0)
    if B == nil then
      Close(0)
      return
    end
    DrawAll()
    UpdateButtonGuide()
    Ptr.Reset()
    ready = true
    if funcLuaCommand(C.FADE_DONE) then
      funcLuaCommand(C.FADE, 0, 0.3)
    end
  elseif a1 == L_GUIDE_LINE then
    HideGuideLine()
  end
end

function OnDecideFocus(a1, a2)
  if evt_co ~= nil or not ready or open_guard > 0 or Ptr.Owns() then
    return                      -- a pointer click is the pointer's (PollPointer)
  end
  if help_open then
    funcLuaCommand(C.SE, SE_BACK)
    SetHelp(false)
    return
  end
  if mode == "list" then
    funcLuaCommand(C.SE, SE_DECIDE)
    ShowBoard(HUB[hfocus])
    return
  end
  StartCo(Decide)
end

function OnFunction(a1, a2)
  if evt_co ~= nil or not ready then
    return 1
  end
  local id = a1
  if a1 ~= FN.UP and a1 ~= FN.DOWN and a1 ~= FN.LEFT and a1 ~= FN.RIGHT and a1 ~= FN.HELP then
    id = a2
  end
  if help_open then
    if id == FN.HELP then
      funcLuaCommand(C.SE, SE_BACK)
      SetHelp(false)
    end
    return 1                    -- the help window is open: arrows do nothing
  end
  if mode == "list" then
    local rows = ListRows()
    if id == FN.UP then
      SetHubFocus(hfocus - 1, true)
    elseif id == FN.DOWN then
      SetHubFocus(hfocus + 1, true)
    elseif id == FN.LEFT then
      SetHubFocus(math.max(1, hfocus - rows), true)
    elseif id == FN.RIGHT then
      SetHubFocus(math.min(#HUB, hfocus + rows), true)
    elseif id ~= FN.HELP then
      return
    end
    return 1                    -- no help window on the list
  end
  if id == FN.UP then
    MoveFocus(0, -1)
  elseif id == FN.DOWN then
    MoveFocus(0, 1)
  elseif id == FN.LEFT then
    MoveFocus(-1, 0)
  elseif id == FN.RIGHT then
    MoveFocus(1, 0)
  elseif id == FN.HELP then
    if open_guard <= 0 then
      funcLuaCommand(C.SE, SE_DECIDE)
      SetHelp(true)
    end
  else
    return
  end
  return 1
end

function OnEnter(a1, a2)
  if a1 == L_BTN or a1 == L_RET then
    return 1
  end
  OnDecideFocus(a1, a2)
end

function OnBack(a1)
  if evt_co ~= nil or not ready or open_guard > 0 then
    return 1
  end
  funcLuaCommand(C.SE, SE_BACK)
  if help_open then
    SetHelp(false)
    return 1
  end
  if HUB ~= nil and mode == "board" then
    Log("hub list")
    ShowList()                  -- a hub's board: back to its list
    return 1
  end
  Log("back")
  Close(0)
  return 1
end

function Step()
  if evt_co ~= nil then
    if coroutine.status(evt_co) == "dead" then
      evt_co = nil
    else
      local ok, err = coroutine.resume(evt_co)
      if not ok then
        PRINT("vrfw_chain_board_menu: " .. tostring(err))
        Log("error", tostring(err))
        evt_co = nil
        funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
      elseif coroutine.status(evt_co) == "dead" then
        evt_co = nil
      end
    end
  end
  if ready and open_guard > 0 then
    open_guard = open_guard - 1
  end
  -- crests / rank badge atlases still loading: redraw when they arrive (600 frames at most, then the "?" icon / no
  -- badge)
  -- (tex_frames: frames waited, -1 = never came in, -2 = loaded)
  if ready and tex_wait then
    local changed, still = false, false
    for path, f in pairs(tex_frames) do
      if f >= 0 then
        if funcLuaCommand(C.TEX_LOADING, CRC32(path)) == true then
          if f + 1 > 600 then
            tex_frames[path] = -1
            Log("texture not loaded", path)
            changed = true
          else
            tex_frames[path] = f + 1
            still = true
          end
        else
          tex_frames[path] = -2
          changed = true
        end
      end
    end
    if changed or not still then
      DrawAll()                 -- resets tex_wait; set again while a crest is still loading
    end
  end
  -- chests opened but never paid (VRFW_Chain.Unpaid): paid once the board is up and idle
  if ready and open_guard <= 0 and evt_co == nil and mode == "board" and B ~= nil and pay_check ~= B then
    pay_check = B
    local rank_due = VRFW_Chain.News ~= nil and (#VRFW_Chain.News(B) > 0 or #VRFW_Chain.RankUnpaid(B) > 0)
    if (VRFW_Chain.Unpaid ~= nil and #VRFW_Chain.Unpaid(B) > 0) or rank_due then
      StartCo(PayPending)
    end
  end
  if ready then
    PollPointer()
  end
end
