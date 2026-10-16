-- evt_rogue_shop_menu (plain Lua 5.2 source, Inazuma Fantasy, INAROGUE «Tienda»): docs/game/modes/inarogue-avatars.md.
-- Opened by evt_inarogue_menu's «Tienda» tile (hook EVT_IR_EXTRA.shop of the rogue_shop graft) as a child menu.
-- A TABBED shop: TABS below lists every tab; only the implemented ones (ready = true) are shown and reachable
-- (Q / E = L1 / R1, Z / C = L2 / R2, or a click on the tab). Tab «Personajes»: a honeycomb of hexagons, one IE3
-- pixel-art avatar per hex (loader module rogue: CMND_EVT_RL_AVATAR_*; catalogue rogue\avatars.toml, the captains of
-- the important teams), breathing (the runner's front idle, g0 dir 4). Two levels (06/10): the CAPTAIN of every IE3
-- team (team hex lit when something of it is owned, gold when all of it, «owned / total» under it;
-- CMND_EVT_RL_AVATAR_TEAM) -> Aceptar opens the team's sub-shop with its whole roster (each in that team's kit) -> Back
-- returns to the teams (cursor and camera kept). Last entry: «Jugadores libres» (green hex), the IE3 units of no team. The avatar atlases (evt_rogue/avatars/evt_rogue_av_NNN.g4tx, native
-- 32 px cells) are loaded on demand. Owned = lit hex, equipped = gold hex + «EN USO»,
-- buyable = dark hex with an orange rim and its price (coin + digits), locked by phase = dark hex, lock + «Fase N».
-- ADAPTIVE: Layout() computes columns / rows from the hex size and the grid area (G = rogue_shop_build.py GEOM), a page
-- = one screen of hexes, the page count from the catalogue; pages sit side by side and the screen switches page at once.
-- Keys move to the neighbouring hex (left / right cross into the next / previous page); the wheel, the edge arrows and
-- the page dots change page; the mouse hovers / clicks (hit test on the instances' global positions, like the route
-- map). Avatars are drawn at 2x the runner's 96 px cell, from the shop's x4 atlases (ShopTex: crisp pixel art). Aceptar on a locked avatar = «¿Desbloquear por N Puntos de rogue?» (taken from the bag of the
-- INAROGUE save: item inarogue.puntos_rogue) and it is equipped; on an owned one = equip (the route-map runner
-- wears it: CMND_EVT_RL_AVATAR_GET). The run's pending points are handed over to the bag when the shop opens
-- (CMND_EVT_RL_POINTS / _GIVEN). Each hex shows its team's crest, faded, behind the sprite (07/10).
-- Top row (07/10, retail look): shop_menu's own tab bar (cmn06_01_list_tab_attach: tab name in the game's font, the
-- device's L1 / R1 glyphs) and shop_menu's currency pill (shop01_04d_token_item_5dig: Rogue points icon + balance). The
-- retail info line at the bottom is hidden; the backdrop is the frame's retail background.
-- Art: evt_rogue_shop.g4tx (research/scripts/rogue_shop_build.py; G = its GEOM), the route map's mode plate, the
-- avatars' own atlases (evt_rogue/avatars/), the crest atlases (evt_rogue/crests/, both loaded here on demand) and the
-- marker atlas (default avatar, shadow).
-- Screen (menus\rogue_shop.toml): the «Guardar» frame + the route map's quad objects as pools + the two retail layers.
-- Rule (position-cards.md §4b): no engine call at top level; funcLuaCommand only exists inside callbacks.
INCLUDE("LUA_PROG_BASE")
INCLUDE("LUA_SAVEDATA_MANAGEMENT_MENU_INC")   -- header helpers (soccer top inc) + general window inc

local TXT = {
  TITLE = "Tienda",
  ASK_UNLOCK = "¿Desbloquear a %s (%s) por %d Puntos de rogue?\nTienes %d. Se equipará al momento.",
  NO_POINTS = "Te faltan Puntos de rogue: %s cuesta %d y tienes %d.\nSe ganan en INAROGUE: partidos, jefes de fase y al terminar cada partida.",
  NO_PHASE = "%s se desbloquea al llegar a la fase %d de INAROGUE.",
  UNLOCKED = "¡%s desbloqueado! Ya eres tú en el mapa de ruta.",
  ERROR = "No se pudo guardar (código %d). Los puntos se han devuelto.\nMira evt_loader\\loader.log.",
  NOT_HERE = "La tienda solo vende dentro de la partida de INAROGUE.",
  NO_ITEM = "No se encuentra el objeto «Puntos de rogue» (mira evt_loader\\loader.log).",
  GOT = "+%d Puntos de rogue de tus partidas.",
  TITLE_TEAM = "Tienda · %s",
}

-- the shop's tabs, in order: `ready` = implemented (only those are shown); `label` = its name on the retail tab bar
local TABS = {
  {id = "chars", label = "Avatares", ready = true, icon = 3373293041 --[[icon_list_tab_datafile05: a bust]],
   icon_off = 2484330717 --[[icon_list_tab_datafile05_off]]},
  {id = "items", label = "Objetos", ready = false},
  {id = "unlocks", label = "Mejoras", ready = false},
}

local MENU = 2441995583           -- crc32("evt_rogue_shop_menu")
local KEY_RESULT = 3345670152     -- crc32("Tienda"): 0 back

local RL = {
  LOG = 3661580131,          -- CMND_EVT_LOG
  LIST = 1398552888,         -- CMND_EVT_RL_AVATAR_LIST (-1) -> count, owned, current, default, enabled
                             --   (i) -> ok, id, name, team, texture, prefix, tier, price, owned, current, available, needPhase, unit
  UNLOCK = 3186193813,       -- CMND_EVT_RL_AVATAR_UNLOCK (i, paid) -> code
  SELECT = 2633969594,       -- CMND_EVT_RL_AVATAR_SELECT (i) -> code
  TEAM = 3547621183,         -- CMND_EVT_RL_AVATAR_TEAM (-1) -> teamCount; (t, -1) -> ok, teamId, name, tier, captainIndex,
                             --   memberCount, ownedCount; (t, j) -> ok, avatarIndex
  POINTS = 622568634,        -- CMND_EVT_RL_POINTS () -> pending, earned, given, spent, itemKey, itemIdGuess, enabled, rogueActive
  GIVEN = 3018215530,        -- CMND_EVT_RL_POINTS_GIVEN (n) -> code, pendingLeft
  REG_FIND = 2175579023,     -- CMND_VRFW_REG_FIND ("item", key) -> id (-1)
  ITEM_NUM = 2011560392,     -- CMND_GET_ITEM_NUM (item, false) -> count
  ADD_ITEM = 1897915498,     -- CMND_ADD_ITEM_ONLY (item, n, window)
  DEL_ITEM = 425598937,      -- CMND_DELETE_ITEM (item, n)
  SAVE = 3673719958,         -- CMND_SYSTEM_AUTO_SAVE
  SAVE_BUSY = 3324595690,    -- CMND_EVT_SLOT_BUSY
}


-- ---- layers ---------------------------------------------------------------------------------------------------------
-- Pools (menus\rogue_shop.toml; counts written by rogue_shop_build.py from GEOM: ONE page's worth since 07/10
-- round 2). A page's item k uses instance k.
local L_ROW = 3455690937        -- save01_02_list_item (1 instance: the input anchor, off screen)
local L_HEADER = 575058101      -- mainmenu90_01_header
local L_GUIDE_LINE = 3078308064 -- mainmenu90_05_content_guide_line01
local L_CURSOR = 2296367164     -- cmn05_01_cursor (hidden: the hex ring is the cursor)
local L_BTN_GUIDE = 1138543975  -- mainmenu01_06_base_button_guide
local L_BTN = 9396745           -- mainmenu01_07_button_guide
local L_RET = 2005383485        -- mainmenu01_10_return_arrow_button_guide
-- the top row is retail (Nacho 07/10: no home-made pills): the shop's tab bar (its tab name in the game's font, the
-- device's L1 / R1 key glyphs at its ends) and the shop's currency pill (item icon + number)
local L_TABBAR = 1887158505     -- cmn06_01_list_tab_attach    x3 (0 section header, 1 / 2 Q / E page glyphs)
local L_PILL = 3286690296       -- shop01_04d_token_item_5dig  x1 (retail currency pill of shop_menu)
local L_TABITEM = 4044286600    -- cmn06_20_list_tab_item      x1 (the section's tab inside the green bar)
local L_HEX = 3418775405        -- evt_rogue_map_plat   x per       (455) hexagons
local L_SHADOW = 846827650      -- evt_rogue_map_emb    x per       (457) shadows
local L_PRICE = 4081246790      -- evt_rogue_map_tag    x per x 8   (458) per hex 0..6: price / lock / badge / the team
                                --        counter, 7: the team's crest (behind the sprite)
local L_UI = 3745054265         -- evt_rogue_map_hint   x3 + dots   (459) 0 cursor ring, 1 / 2 page arrows, 3.. dots
local L_AV = 2771742028         -- evt_rogue_map_runner x per       (460) the avatars
local N_PER_HEX = 8
local CREST_K = N_PER_HEX - 1    -- the crest's instance in a hex's block
local UI_ARROW_L, UI_ARROW_R, UI_DOT0 = 1, 2, 3
-- retail tab bar / currency pill (shop_menu_buy: OnSetupLayer, SetupSlotInfo, UpdateHaveTokenList,
-- LISTVIEW.ChangeListTabLRGaiji)
local TB = {
  TEXT = 3029561990,   -- _text_list_tab01
  BTN_L = 355816102,   -- _text_btn_l01
  BTN_R = 59628764,    -- _text_btn_r01
  BTN = 950238781,     -- _text_btn01
  SORT = 1037529311,   -- _icon_sort01
  BASE = 2452509419,   -- list_tab_base01 (node)
  TEX = 3062127414,    -- #/menu/20_cmn/cmn06/cmn06_01/cmn06_01.g4tx
  SPR = 187106129,     -- list_tab_base02 (shop_menu's plate)
  STYLE = 2896964141,  -- shop_menu's tab text style
  GAIJI_L = 3734986708, GAIJI_R = 613442231,   -- system texts: the L1 / R1 key glyphs of the active device (Z / C)
  -- the page keys: the command tags the text renderer turns into the active device's L2 / R2 glyph (Q / E on the
  -- keyboard; bb_pages' «<L2> Página n/N <R2>» line). Round 3 used system texts 1087561630 / 2667771517: Z / C (L1 / R1)
  KEY_L2 = "<CMD_FUNCL2>", KEY_R2 = "<CMD_FUNCR2>",
  ICON_TEX = 1395458492,  -- #/menu/200_icon/16_icon_list_tab/<LG>/icon_list_tab.g4tx
  ICON_ON = 3229351341, ICON_OFF = 380437824,   -- icon_list_tab_dmy01_on / _off (cmn06_20 nodes)
  ICON_BASE = 4013273506,                        -- _icon_base01 (the tab item's plate)
  PLATE_MESH = 4025857287,                       -- _list_tab_base01 (the plate mesh)
  GLYPH_L = {181, 246}, GLYPH_R = {699, 246},    -- centres of _text_btn_l01 / _r01 (38 px boxes) in the layout
}
local PILL = {
  ICON_TEX = 3352331282,  -- #/menu/200_icon/02_icon_item/icon_item10.g4tx
  ICON = 4269249000,      -- tk_rg000001 (the Rogue points icon, items\rogue_points.toml)
  ICON_NODE = 1162614319, -- icon_token_dmy01
  NUM_PRIM = 112229990,   -- the pill's number primitive
}

local C = {
  TEXT = 1083631230, MESH_VISIBLE = 3405944500, LAYER_VISIBLE = 711242136,
  SPRITE = 558735651,         -- (layer, textureCrc, spriteCrc, nodeCrc, 0, idx)
  LOAD_TEX = 839427544,
  SCALE = 3778714801,
  POS = 1389957207,
  ATTACH_TRACE = 1774843228,
  OPEN_LAYER = 629267548,
  FOCUS_ENABLE = 3518307824, FOCUS_SET = 3466097042, LIST_NUM = 3252599449,
  GUIDE_SET = 2209673388, GUIDE_CMD = 452337289, GUIDE_OPT = 1432240275,
  SE = 1917805374, MENU_ACTIVE = 1558704558, CLOSE_MENU = 320421347,
  FADE = 609722083, FADE_DONE = 2259183189,
  P_SET = 3860611758, P_CLEAR = 3363400568,
  MSG_OPEN = 2289627655, MSG_KIND = 2351835063, MSG_RESULT = 1523741473, MSG_DONE = 682363669, MSG_BUSY = 898725220,
  TEXT_VISIBLE = 1505208242,
  PRIM_COLOR = 855211291,     -- CMND_SET_PRIM_COLOR (layer, idx, meshCrc, r, g, b)
  TEXT_STYLE = 2333948100,    -- (layer, idx, textCrc, styleCrc)
  TEXT_GET = 4074371074,      -- CMND_TEXT_GET (textId) -> string
  PRIM_INDEX = 1927054058,    -- CMND_SEARCH_PRIM_INDEX (layer, idx, primCrc)
  PRIM_NUM = 3609943765,      -- (layer, idx, prim, number): the pill's number
}
-- the mouse (the route map's way, evt_rogue_map_menu.lua MS): hit areas from the same layout (GPOS of the instances)
local MS = {
  CHECK_INPUT = 4265778440, MENU_CTRL = 1332654303, CLICK = 1651523701,
  WHEEL_UP = 1942756954, WHEEL_DOWN = 1623431741,
  MOVED = 3272825600, POINTER = 558229292, GPOS = 4002164178,
  HIT_ARROW = 50, HIT_DOT = 16,
}
local MESH_QUAD = 312193881     -- the cmn01_10 quad's mesh
local NODE_QUAD = 1909474081    -- icon_new01 (the cmn01_10 quad's sprite node)
local CUR = 3313461902          -- crc32("cursor")
local FN = {UP = 2270326752, DOWN = 4144065873, LEFT = 2442729986, RIGHT = 424018863,
            TAB_PREV = 3909110306 --[[evt_shop_tab_prev]], TAB_NEXT = 1372443211 --[[evt_shop_tab_next]],
            PAGE_PREV = 2244387955 --[[evt_shop_page_prev]], PAGE_NEXT = 1024146458 --[[evt_shop_page_next]]}
local G_ACCEPT = 1847312674 --[[Aceptar]]
local I_ENTER = 2750714971 --[[<CMD_ENTER>]]
local K_ENTER = 1981080283
local SE_OK, SE_DECIDE, SE_BACK = 3848881948, 4235359837, 202039849
local SE_NG = SE_BACK
local ROW_MESHES = {3025401186, 486732393, 376662541, 3232607807, 1516082254, 3292070381, 1712955010}
local MODE_ICON_NODE = 3293713115

local TEX_UI = "#/menu/220_img/evt_rogue/evt_rogue_shop.g4tx"
local TEX_MAP = "#/menu/220_img/evt_rogue/evt_rogue_map.g4tx"
local TEX_MARKER = "#/menu/220_img/evt_rogue/evt_rogue_marker.g4tx"
-- rogue_shop_build.py GEOM (screen px, y down). Avatars at SPR_SCALE x the 96 px runner cell = 128 px: the x4 shop
-- atlases 1:1 (crisp). 07/10 round 2 (Nacho: more teams per page): 144 x 166 hexes, 11 + 10 columns x 5 rows = 53
-- per page (was 20); ONE page of instances (the page switch is instant, no slide).
local G = {Q = 36, HEX_W = 144, HEX_H = 166, DX = 150, DY = 127, AREA_X = 90, AREA_Y = 276, AREA_W = 1740,
           AREA_H = 674, PAGE_W = 1920, SPR_SCALE = 4 / 3, FEET = 50, PRICE_Y = 64, DIGIT_W = 15, DIGIT_H = 24,
           COIN = 28, LOCK_W = 24, LOCK_H = 30, FASE_W = 50, FASE_H = 26, BADGE_W = 88, BADGE_H = 30, RING_W = 162,
           RING_H = 186, ARROW_W = 48, ARROW_H = 84, ARROW_X = 40, DOT = 20, DOT_DX = 30, DOT_Y = 985, MAX_DOTS = 24,
           GLYPH_GAP = 46, TAB_DX = 520, TAB_CX = 440, TAB_CY = 194, PILL_X = 1700, PILL_Y = 168, CREST = 118, CREST_DY = -16, CREST_PER = 200,
           SLASH_W = 10, BOX = 96, FOOT = 93, SHADOW_W = 60, SHADOW_H = 20}
-- team crests (rogue_shop_build.py build_crests): every catalogue team has a sprite cr_tNNN (its crest, or the neutral
-- one), in atlas evt_rogue_crest_<tid // CREST_PER>.g4tx (loaded on demand)
local CREST_TEX = "#/menu/220_img/evt_rogue/crests/evt_rogue_crest_%d.g4tx"
-- the shop draws the avatars from their x4 atlases (rogue_avatars_build.py build_shop_atlases, Nacho 07/10: the 32 px
-- cells scaled 6x by the GPU's bilinear filter looked smoothed): only the idle cells, nearest-neighbour x4 (128 px),
-- one evt_rogue/avatars_x4/evt_rogue_avx_NNN.g4tx per evt_rogue/avatars/evt_rogue_av_NNN.g4tx, same sprite names
local function ShopTex(tex)
  local t, n = string.gsub(tex, "/avatars/evt_rogue_av_(%d+)%.g4tx$", "/avatars_x4/evt_rogue_avx_%1.g4tx")
  return n == 1 and t or tex
end
-- the runner's front idle (rogue_map_marker_build.py RN_ANIM idle, g0 direction 4)
local IDLE = {{1, 16}, {2, 2}, {53, 16}, {3, 2}}
local DARK = {0.22, 0.22, 0.28}
local LIGHT = {1, 1, 1}

-- ---- state ----------------------------------------------------------------------------------------------------------
-- Two levels (Nacho 06/10): «teams» = the captain of every team (a team hex shows its captain and «owned / total»);
-- Aceptar opens «members» = that team's whole roster, each buyable / equippable; Back returns to the teams (cursor and
-- camera remembered).
local list = {}        -- the grid's items: avatar records {i, id, name, team, tex, prefix, tier, price, owned, current,
                       -- avail, phase} (+ for a team item: kind = "team", t, tname, nOwned, nTotal; every item:
                       -- tid = its IE3 team, for the crest)
local level = "teams"
local cur_team = nil   -- 0-based team index of the open sub-shop
local cur_tid = 0      -- its IE3 team id
local back = nil       -- {focus, cam} of the team grid
local cache = {}       -- avatar index -> record (CMND_EVT_RL_AVATAR_LIST), cleared after a purchase
local tex_asked = {}   -- avatar atlases already requested (CMND_LOAD_MENU_RES_TEXTURE, on demand)
local pos = {}         -- [1..n] = {x, y}: global centres (page p is p * PAGE_W to the right)
local per, pages = 1, 1
local tabs = {}        -- the shown tabs (TABS with ready)
local tab = 1
local focus = 1
local cam, cam_to = 0, 0
local shown = {}       -- [slot] = item index drawn there (nil = hidden)
local balance = 0
local item_id = nil
local rogue_active = false
local ready = false
-- the input that opened this screen (Accept / click on the INAROGUE menu's «Tienda») must not reach it: Back, decide
-- and clicks are swallowed until the screen is live and 20 frames more (Nacho 07/10: the first open closed by
-- itself, a black blink back to the INAROGUE menu)
local open_guard = 20           -- frames (reset to 20 in OnInit)
-- the same guard after a level change (team grid <-> sub-shop): ONE click / Aceptar reaches the screen twice (the
-- hex's own CMD_ENTER -> OnDecideFocus and the mouse poll), so the second one fell on the sub-shop's first member
-- (Nacho 07/10: opening a team popped «Te faltan Puntos de rogue» at once; one Back right-click left the shop).
-- Round 4: 8 frames were not enough (the click's CMD_ENTER came 70 ms later and decided a member: the menus run
-- faster than 60 Hz), so 30 frames, and the engine's own decide is ignored for CLICK_GUARD frames after a click.
local LEVEL_GUARD = 30
local CLICK_GUARD = 30
local click_guard = 0
local anim = {}        -- [item] = {fi, ft, drawn}
local save_req = nil   -- {frames, sent}
local evt_co = nil
local last_ptr = nil   -- the pointer's last position (hover only when it moves)

local function Log(...)
  pcall(funcLuaCommand, RL.LOG, "rogue_shop", ...)
end

--@lib evt_menu_kit.lua#Call,Int,Hide

local function Place(layer, idx, x, y)
  funcLuaMenuCommand(C.POS, layer, x, -y, 0, idx)
end

local function QuadTex(layer, idx, tex, sprite, x, y, w, h)
  funcLuaMenuCommand(C.LAYER_VISIBLE, layer, idx, true)
  funcLuaMenuCommand(C.SCALE, layer, w / G.Q, h / G.Q, 1, idx)
  funcLuaMenuCommand(C.SPRITE, layer, tex, sprite, NODE_QUAD, 0, idx)
  Place(layer, idx, x, y)
end

local function UI(layer, idx, sprite, x, y, w, h)
  QuadTex(layer, idx, CRC32(TEX_UI), CRC32(sprite), x, y, w, h)
end

local function Tint(layer, idx, c)
  funcLuaMenuCommand(C.PRIM_COLOR, layer, idx, MESH_QUAD, c[1], c[2], c[3])
end

-- ---- data -----------------------------------------------------------------------------------------------------------
local function ReadItemId()
  if item_id ~= nil then
    return item_id
  end
  local _, _, _, _, key, guess = Call(RL.POINTS)
  if type(key) ~= "string" or key == "" then
    return nil
  end
  local id = Call(RL.REG_FIND, "item", key)
  if type(id) == "number" and id > 0 then
    item_id = id
  elseif type(guess) == "number" and guess > 0 then
    item_id = guess
  end
  Log("points item", key, tostring(item_id))
  return item_id
end

local function ReadBalance()
  local id = ReadItemId()
  balance = id ~= nil and Int(Call(RL.ITEM_NUM, id, false)) or 0
  return balance
end

-- ---- the adaptive layout (rogue_shop_build.py grid / layout / neighbour) ----------------------------------------------
local function Layout()
  local cols = math.max(1, math.floor((G.AREA_W - G.HEX_W) / G.DX) + 1)
  local rows = math.max(1, math.floor((G.AREA_H - G.HEX_H) / G.DY) + 1)
  local function RowLen(r)
    return cols > 1 and cols - r % 2 or cols
  end
  per = 0
  for r = 0, rows - 1 do
    per = per + RowLen(r)
  end
  pages = math.max(1, math.ceil(#list / per))
  local used_h = (rows - 1) * G.DY + G.HEX_H
  local y0 = G.AREA_Y + (G.AREA_H - used_h) / 2 + G.HEX_H / 2
  local cx = G.AREA_X + G.AREA_W / 2
  pos = {}
  for i = 1, #list do
    local p, k = math.floor((i - 1) / per), (i - 1) % per
    local r = 0
    while k >= RowLen(r) do
      k = k - RowLen(r)
      r = r + 1
    end
    pos[i] = {p * G.PAGE_W + cx + (k - (RowLen(r) - 1) / 2) * G.DX, y0 + r * G.DY}
  end
  Log("layout", cols, "cols", rows, "rows", per, "per page", pages, "pages")
end

local function PageOf(i)
  return math.floor((i - 1) / per)
end

-- one page of instances: item i of any page uses instance (i - 1) % per
local function SlotOf(i)
  return (i - 1) % per
end

-- keys: left / right = the nearest hex of the same row that way (across pages: the next page's edge); up / down =
-- the nearest hex of the row above / below
local function Neighbour(i, dx, dy)
  local x, y = pos[i][1], pos[i][2]
  local best, bd = nil, nil
  for j = 1, #pos do
    if j ~= i then
      local jx, jy = pos[j][1], pos[j][2]
      local ok = false
      if dx ~= 0 then
        ok = math.abs(jy - y) < 1 and (jx - x) * dx > 0
      else
        ok = (jy - y) * dy > 1 and math.abs(jy - y) < G.DY * 1.5
      end
      if ok then
        local d = math.abs(jx - x)
        if bd == nil or d < bd then
          best, bd = j, d
        end
      end
    end
  end
  return best
end

local function Avatar(i)
  if cache[i] == nil then
    local ok, id, name, team, tex, prefix, tier, price, owned, current, avail, phase = Call(RL.LIST, i)
    if ok ~= true then
      return nil
    end
    cache[i] = {i = i, id = id, name = name, team = team, tex = tex, prefix = prefix, tier = Int(tier),
                price = Int(price), owned = owned == true, current = current == true, avail = avail == true,
                phase = Int(phase)}
  end
  return cache[i]
end

-- the items of the current level
local function ReadList()
  list = {}
  if level == "teams" then
    for t = 0, Int(Call(RL.TEAM, -1)) - 1 do
      local ok, tid, tname, _, cap, n, owned = Call(RL.TEAM, t, -1)
      local a = ok == true and Avatar(Int(cap)) or nil
      if a ~= nil then
        local it = {}
        for k, v in pairs(a) do
          it[k] = v
        end
        it.kind, it.t, it.tname, it.nTotal, it.nOwned = "team", t, tname, Int(n), Int(owned)
        it.tid = Int(tid)
        it.free = it.tid == 0              -- «Jugadores libres» (no IE3 team; rogue_avatars_build.py FREE_TID)
        list[#list + 1] = it
      end
    end
  else
    local _, tid, _, _, _, n = Call(RL.TEAM, cur_team, -1)
    cur_tid = Int(tid)
    for j = 0, Int(n) - 1 do
      local ok, i = Call(RL.TEAM, cur_team, j)
      local a = ok == true and Avatar(Int(i)) or nil
      if a ~= nil then
        list[#list + 1] = a
      end
    end
  end
  Layout()
end

local function RequestSave()
  save_req = {frames = 0, sent = false}
end

-- the points the runs earned and the bag does not hold yet: into the INAROGUE save's bag (slot 4 only)
local function FlushPoints()
  local pending, _, _, _, _, _, _, active = Call(RL.POINTS)
  rogue_active = active == true
  pending = Int(pending)
  if pending <= 0 or not rogue_active then
    return 0
  end
  local id = ReadItemId()
  if id == nil then
    return 0
  end
  local before = Int(Call(RL.ITEM_NUM, id, false))
  Call(RL.ADD_ITEM, id, pending, false)
  local added = math.max(0, Int(Call(RL.ITEM_NUM, id, false)) - before)
  if added > 0 then
    Call(RL.GIVEN, added)
    RequestSave()
  end
  Log("points handed over", added, "of", pending)
  return added
end

-- ---- drawing --------------------------------------------------------------------------------------------------------
local function HexSprite(a)
  if a.kind == "team" and a.free then
    return "sh_hex_free"
  elseif a.kind == "team" then
    return a.nOwned >= a.nTotal and "sh_hex_eq" or a.nOwned > 0 and "sh_hex_lit" or "sh_hex_buy"
  elseif a.current then
    return "sh_hex_eq"
  elseif a.owned then
    return "sh_hex_lit"
  elseif a.avail then
    return "sh_hex_buy"
  end
  return "sh_hex_dark"
end

-- digits of n on instances first..last of a layer, from x (left) on the line y; returns the next free instance
local function Digits(layer, first, last, n, x, y)
  local k = first
  for c in tostring(n):gmatch("%d") do
    if k > last then
      break
    end
    UI(layer, k, "sh_d" .. c, x + G.DIGIT_W / 2, y, G.DIGIT_W, G.DIGIT_H)
    x = x + G.DIGIT_W
    k = k + 1
  end
  return k
end

local function HideSlot(s)
  Hide(L_HEX, s)
  Hide(L_SHADOW, s)
  Hide(L_AV, s)
  for i = s * N_PER_HEX, s * N_PER_HEX + N_PER_HEX - 1 do
    Hide(L_PRICE, i)
  end
  shown[s] = nil
end

local function DrawPrice(s, a, x, y)
  local base = s * N_PER_HEX
  local used = base
  local py = y + G.PRICE_Y
  if a.kind == "team" then        -- «owned / total»
    local w = (#tostring(a.nOwned) + #tostring(a.nTotal)) * G.DIGIT_W + G.SLASH_W
    local x0 = x - w / 2
    used = Digits(L_PRICE, base, base + 2, a.nOwned, x0, py)
    UI(L_PRICE, used, "sh_slash", x0 + #tostring(a.nOwned) * G.DIGIT_W + G.SLASH_W / 2, py, G.SLASH_W, G.DIGIT_H)
    used = Digits(L_PRICE, used + 1, base + CREST_K - 1, a.nTotal,
                  x0 + #tostring(a.nOwned) * G.DIGIT_W + G.SLASH_W, py)
  elseif a.current then
    UI(L_PRICE, base, "sh_badge", x, py, G.BADGE_W, G.BADGE_H)
    used = base + 1
  elseif not a.owned then
    if not a.avail then
      local w = G.LOCK_W + 2 + G.FASE_W + 2 + #tostring(a.phase) * G.DIGIT_W
      local x0 = x - w / 2
      UI(L_PRICE, base, "sh_lock", x0 + G.LOCK_W / 2, py, G.LOCK_W, G.LOCK_H)
      UI(L_PRICE, base + 1, "sh_fase", x0 + G.LOCK_W + 2 + G.FASE_W / 2, py, G.FASE_W, G.FASE_H)
      used = Digits(L_PRICE, base + 2, base + CREST_K - 1, a.phase, x0 + G.LOCK_W + G.FASE_W + 4, py)
    else
      local w = G.COIN + 4 + #tostring(a.price) * G.DIGIT_W
      local x0 = x - w / 2
      UI(L_PRICE, base, "sh_coin", x0 + G.COIN / 2, py, G.COIN, G.COIN)
      used = Digits(L_PRICE, base + 1, base + CREST_K - 1, a.price, x0 + G.COIN + 4, py)
    end
  end
  for i = used, base + CREST_K - 1 do
    Hide(L_PRICE, i)
  end
end

-- the team's crest behind the sprite (Nacho 07/10): faded (the atlas cells are half transparent), darker when the
-- avatar is dark; none for «Jugadores libres»
local CREST_LIT, CREST_DARK = {1, 1, 1}, {0.45, 0.45, 0.52}
local function DrawCrest(s, a, x, y, lit)
  local k = s * N_PER_HEX + CREST_K
  local tid = a.kind == "team" and a.tid or cur_tid
  if tid == nil or tid <= 0 then
    Hide(L_PRICE, k)
    return
  end
  local tex = string.format(CREST_TEX, math.floor(tid / G.CREST_PER))
  if not tex_asked[tex] then
    tex_asked[tex] = true
    funcLuaMenuCommand(C.LOAD_TEX, tex)
  end
  QuadTex(L_PRICE, k, CRC32(tex), CRC32(string.format("cr_t%03d", tid)), x, y + G.CREST_DY, G.CREST, G.CREST)
  Tint(L_PRICE, k, lit and CREST_LIT or CREST_DARK)
end

-- the avatar sprite of item i (its idle cell), at the camera's x
local function DrawSprite(i, force)
  local a, st = list[i], anim[i]
  local s = SlotOf(i)
  if a == nil or st == nil or shown[s] ~= i then
    return
  end
  local cell = IDLE[st.fi][1]
  if not force and cell == st.drawn then
    return
  end
  st.drawn = cell
  local box = G.BOX * G.SPR_SCALE
  local x, y = pos[i][1] - cam, pos[i][2]
  QuadTex(L_AV, s, CRC32(ShopTex(a.tex)), CRC32(string.format("%s_c%02d", a.prefix, cell)), x,
          y + G.FEET - G.FOOT * G.SPR_SCALE + box / 2, box, box)
end

local function DrawItem(i)
  local a = list[i]
  local s = SlotOf(i)
  local x, y = pos[i][1] - cam, pos[i][2]
  shown[s] = i
  anim[i] = anim[i] or {fi = (i * 5) % 4 + 1, ft = (i * 7) % 16}
  UI(L_HEX, s, HexSprite(a), x, y, G.HEX_W, G.HEX_H)
  QuadTex(L_SHADOW, s, CRC32(TEX_MARKER), CRC32("mk_shadow"), x, y + G.FEET, G.SHADOW_W * G.SPR_SCALE,
          G.SHADOW_H * G.SPR_SCALE)
  local lit = a.owned
  if a.kind == "team" then
    lit = a.free or a.nOwned > 0 or a.avail
  end
  Tint(L_AV, s, lit and LIGHT or DARK)
  local stex = ShopTex(a.tex)
  if stex ~= TEX_MARKER and not tex_asked[stex] then         -- the avatar atlases load on demand
    tex_asked[stex] = true
    funcLuaMenuCommand(C.LOAD_TEX, stex)
  end
  DrawCrest(s, a, x, y, lit)
  DrawPrice(s, a, x, y)
  DrawSprite(i, true)
end

local function DrawCursor()
  local p = pos[focus]
  if p == nil then
    Hide(L_UI, 0)
    return
  end
  UI(L_UI, 0, "sh_hex_cur", p[1] - cam, p[2], G.RING_W, G.RING_H)
end

-- every item of the page the camera shows; the other slots hidden
local function DrawGrid()
  local p0 = math.max(0, math.min(pages - 1, math.floor(cam / G.PAGE_W + 0.5)))
  local want = {}
  for i = p0 * per + 1, math.min(#list, (p0 + 1) * per) do
    want[SlotOf(i)] = i
  end
  for s = 0, per - 1 do
    if want[s] ~= nil then
      DrawItem(want[s])
    else
      HideSlot(s)
    end
  end
  DrawCursor()
end

-- the first page of the dot window (more pages than dots: a window of MAX_DOTS around the current page)
local function DotStart()
  return math.max(0, math.min(PageOf(focus) - math.floor(G.MAX_DOTS / 2), pages - G.MAX_DOTS))
end

-- the page key glyph next to the dots: an extra instance of the retail tab bar showing ONLY its L or R key text
-- (plate, tab name and the other key hidden), filled with the L2 / R2 glyph of the active device (Q / E on the
-- keyboard, LISTVIEW.ChangeListTabLRGaiji's second pair). The glyph's text node sits at GLYPH_L / GLYPH_R of the
-- cmn06_01 layout, so the instance goes at the wanted centre minus that offset.
local function DrawGlyph(idx, show, left, x, y)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_TABBAR, idx, show)
  if not show then
    return
  end
  local o = left and TB.GLYPH_L or TB.GLYPH_R
  Place(L_TABBAR, idx, x - o[1], y - o[2])
  funcLuaMenuCommand(C.MESH_VISIBLE, L_TABBAR, TB.PLATE_MESH, false, idx)
  funcLuaMenuCommand(C.MESH_VISIBLE, L_TABBAR, TB.SORT, false, idx)
  funcLuaMenuCommand(C.TEXT_VISIBLE, L_TABBAR, TB.TEXT, false, idx)
  funcLuaMenuCommand(C.TEXT_VISIBLE, L_TABBAR, TB.BTN, false, idx)
  funcLuaMenuCommand(C.TEXT_VISIBLE, L_TABBAR, left and TB.BTN_R or TB.BTN_L, false, idx)
  local node = left and TB.BTN_L or TB.BTN_R
  funcLuaMenuCommand(C.TEXT, L_TABBAR, node, left and TB.KEY_L2 or TB.KEY_R2, idx)
  funcLuaMenuCommand(C.TEXT_VISIBLE, L_TABBAR, node, true, idx)
end

-- one dot per page (Nacho 07/10 round 2: the dots must be the pages), the current one lit, the Q / E glyphs at the
-- ends (L2 / R2 = previous / next page); under the grid since round 4 («ponlos abajo»), above the button guide. More pages than MAX_DOTS (never with the catalogue today): a window.
local function DrawPager()
  local page = PageOf(focus)
  local n = pages > 1 and math.min(pages, G.MAX_DOTS) or 0
  local x0 = 960 - (n - 1) * G.DOT_DX / 2
  local first = DotStart()
  for d = 0, G.MAX_DOTS - 1 do
    if d < n then
      UI(L_UI, UI_DOT0 + d, first + d == page and "sh_dot_on" or "sh_dot_off", x0 + d * G.DOT_DX, G.DOT_Y, G.DOT,
         G.DOT)
    else
      Hide(L_UI, UI_DOT0 + d)
    end
  end
  DrawGlyph(1, n > 0, true, x0 - G.GLYPH_GAP, G.DOT_Y)
  DrawGlyph(2, n > 0, false, x0 + (n - 1) * G.DOT_DX + G.GLYPH_GAP, G.DOT_Y)
  local ay = G.AREA_Y + G.AREA_H / 2
  if pages > 1 and page > 0 then
    UI(L_UI, UI_ARROW_L, "sh_arrow_l", G.ARROW_X, ay, G.ARROW_W, G.ARROW_H)
  else
    Hide(L_UI, UI_ARROW_L)
  end
  if pages > 1 and page < pages - 1 then
    UI(L_UI, UI_ARROW_R, "sh_arrow_r", G.PAGE_W - G.ARROW_X, ay, G.ARROW_W, G.ARROW_H)
  else
    Hide(L_UI, UI_ARROW_R)
  end
end

-- the section header = the retail shop's tab bar (shop_menu's cmn06_01_list_tab_attach, instance 0) where the retail
-- shop has it (Nacho 07/10 round 2: «la sección arriba como tienda normal»): the layer at the screen origin, so its
-- own layout puts the plate at x -78..958, y 156..232 and the section name under it, in shop_menu's text style;
-- centred on the screen (Nacho 07/10: «debería estar centrado»): the layer moves right by TAB_DX = 960 - 440 (the
-- plate's centre in the layout), same height. The L1 / R1 (Z / C) tab keys only with two tabs or more (retail
-- SetupSlotInfo hides them for one).
local placed_log = false
local function DrawTabs()
  local t = tabs[tab]
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_TABBAR, 0, t ~= nil)
  if t == nil then
    return
  end
  Place(L_TABBAR, 0, G.TAB_DX, 0)
  funcLuaMenuCommand(C.TEXT, L_TABBAR, TB.TEXT, t.label, 0)
  -- the section's tab inside the green bar (Nacho 07/10 round 4: «en la parte verde pon la sección»), as retail
  -- SetupSlotInfo + LISTVIEW.SetupTabIcon: cmn06_20_list_tab_item with the tab's icon (on / off sprites), placed on
  -- the plate's centre (TAB_DX + 440, 194; the item's layout is centred on its origin)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_TABITEM, 0, t.icon ~= nil)
  if t.icon ~= nil then
    funcLuaMenuCommand(C.SPRITE, L_TABITEM, TB.ICON_TEX, t.icon, TB.ICON_ON, 0, 0)
    funcLuaMenuCommand(C.SPRITE, L_TABITEM, TB.ICON_TEX, t.icon_off or t.icon, TB.ICON_OFF, 0, 0)
    funcLuaMenuCommand(C.MESH_VISIBLE, L_TABITEM, TB.ICON_BASE, true, 0)
    Place(L_TABITEM, 0, G.TAB_DX + G.TAB_CX, G.TAB_CY)
  end
  local keys = #tabs >= 2
  if keys then
    funcLuaMenuCommand(C.TEXT, L_TABBAR, TB.BTN_L, funcLuaCommand(C.TEXT_GET, TB.GAIJI_L), 0)
    funcLuaMenuCommand(C.TEXT, L_TABBAR, TB.BTN_R, funcLuaCommand(C.TEXT_GET, TB.GAIJI_R), 0)
  end
  funcLuaMenuCommand(C.TEXT_VISIBLE, L_TABBAR, TB.BTN_L, keys, 0)
  funcLuaMenuCommand(C.TEXT_VISIBLE, L_TABBAR, TB.BTN_R, keys, 0)
end

-- the retail currency pill (shop_menu's shop01_04d_token_item_5dig): the Rogue points icon + the balance
local function DrawBalance()
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_PILL, 0, true)
  Place(L_PILL, 0, G.PILL_X, G.PILL_Y)
  local prim = funcLuaMenuCommand(C.PRIM_INDEX, L_PILL, 0, PILL.NUM_PRIM)
  funcLuaMenuCommand(C.PRIM_NUM, L_PILL, 0, prim, math.min(balance, 99999))
  if not placed_log then        -- for calibrating TAB_X / PILL_X in game: where the retail layers ended up
    placed_log = true
    local tx, ty = funcLuaMenuCommand(MS.GPOS, L_TABBAR, 0)
    local px, py = funcLuaMenuCommand(MS.GPOS, L_PILL, 0)
    Log("retail top row: tab bar at", tostring(tx), tostring(ty), "pill at", tostring(px), tostring(py))
  end
end

-- the retail info line stays empty and hidden on this screen (Nacho 07/10)
local function UpdateGuideLine()
  funcLuaMenuCommand(C.TEXT, L_GUIDE_LINE, 378156699 --[[_text_guide01]], "", 0)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_GUIDE_LINE, 0, false)
end

local function UpdateTitle()
  local title = TXT.TITLE
  if level == "members" and list[1] ~= nil then
    title = string.format(TXT.TITLE_TEAM, list[1].team or "")
  end
  funcLuaMenuCommand(C.TEXT, L_HEADER, 1220590795 --[[_text_sub_title02]], title, 0)
  funcLuaMenuCommand(C.SPRITE, L_HEADER, 3139293835 --[[#/menu/220_img/evt_rogue/evt_rogue_mode.g4tx]], 2610480106 --[[evt_rogue_mode_plate: INAROGUE's phoenix plate]], MODE_ICON_NODE, 0, 0)
end

local function UpdateButtonGuide()
  funcLuaMenuCommand(C.GUIDE_SET, MENU, L_BTN_GUIDE, {G_ACCEPT}, {I_ENTER}, {0}, {}, {})
  funcLuaMenuCommand(C.GUIDE_CMD, MENU, L_BTN_GUIDE, {K_ENTER})
  funcLuaMenuCommand(C.GUIDE_OPT, MENU, L_BTN_GUIDE, false)
end

local function DrawAll()
  DrawTabs()
  DrawBalance()
  DrawPager()
  DrawGrid()
  UpdateGuideLine()
end

-- ---- actions --------------------------------------------------------------------------------------------------------
--@lib evt_menu_kit.lua#Ask,Message,Close

local function Equip(a)
  local code = Int(Call(RL.SELECT, a.i))
  Log("select", a.id, "code", code)
  funcLuaCommand(C.SE, code == 0 and SE_DECIDE or SE_NG)
  return code == 0
end

local function Refresh()
  cache = {}
  ReadList()
  ReadBalance()
  DrawAll()
end

-- the team grid <-> a team's sub-shop
local function OpenTeam(it)
  back = {focus = focus, cam = cam_to}
  level, cur_team = "members", it.t
  ReadList()
  focus = 1
  for k, a in ipairs(list) do
    if a.current then
      focus = k
    end
  end
  cam = PageOf(focus) * G.PAGE_W
  cam_to = cam
  anim, shown = {}, {}
  open_guard = LEVEL_GUARD
  funcLuaCommand(C.SE, SE_DECIDE)
  UpdateTitle()
  DrawAll()
  Log("team", it.t, it.tname, #list, "members")
end

local function BackToTeams()
  level, cur_team = "teams", nil
  cache = {}
  ReadList()
  focus = math.min(#list, back ~= nil and back.focus or 1)
  cam = back ~= nil and back.cam or 0
  cam_to = cam
  anim, shown = {}, {}
  open_guard = LEVEL_GUARD
  funcLuaCommand(C.SE, SE_BACK)
  UpdateTitle()
  DrawAll()
end

local function Unlock(a)
  if not rogue_active then
    Message(TXT.NOT_HERE)
    return
  end
  if not a.avail then
    funcLuaCommand(C.SE, SE_NG)
    Message(string.format(TXT.NO_PHASE, a.name, a.phase))
    return
  end
  local id = ReadItemId()
  if id == nil then
    Message(TXT.NO_ITEM)
    return
  end
  ReadBalance()
  if balance < a.price then
    funcLuaCommand(C.SE, SE_NG)
    Message(string.format(TXT.NO_POINTS, a.name, a.price, balance))
    return
  end
  if not Ask(string.format(TXT.ASK_UNLOCK, a.name, a.team, a.price, balance)) then
    return
  end
  local before = balance
  if a.price > 0 then
    Call(RL.DEL_ITEM, id, a.price)
  end
  local after = ReadBalance()
  if before - after ~= a.price then
    Log("delete did not take the price", before, after, a.price)
    if before > after then
      Call(RL.ADD_ITEM, id, before - after, false)
    end
    ReadBalance()
    Message(string.format(TXT.ERROR, -1))
    return
  end
  local code = Int(Call(RL.UNLOCK, a.i, a.price))
  Log("unlock", a.id, "paid", a.price, "code", code)
  if code ~= 0 then
    if a.price > 0 then
      Call(RL.ADD_ITEM, id, a.price, false)  -- refund
    end
    ReadBalance()
    Message(string.format(TXT.ERROR, code))
    return
  end
  Equip(a)
  RequestSave()
  Refresh()
  Message(string.format(TXT.UNLOCKED, a.name))
end

-- every decide is logged (Nacho 07/10 round 2: «me abre el Wilds o equipos que no corresponden»): the item index,
-- its page and instance, and the team / avatar it opens
local function Decide(src)
  local a = list[focus]
  if a == nil or tabs[tab] == nil or tabs[tab].id ~= "chars" then
    return
  end
  if a.kind == "team" then
    Log("decide " .. tostring(src), focus, "page", PageOf(focus), "slot", SlotOf(focus), a.t)
    Log("decide team", a.t, a.tid, a.tname, a.name)
  else
    Log("decide member " .. tostring(src), focus, "page", PageOf(focus), a.id, a.name)
  end
  if a.kind == "team" then
    OpenTeam(a)
    return
  end
  if a.owned then
    if not a.current and Equip(a) then
      RequestSave()
      Refresh()
    end
    return
  end
  Unlock(a)
end

-- focus moves to item i; another page = the grid switches to it at once, the pager follows
local function SetFocus(i, sound)
  if i == nil or i < 1 or i > #list or i == focus then
    return
  end
  local old_page = PageOf(focus)
  focus = i
  if sound then
    funcLuaCommand(C.SE, SE_OK)
  end
  cam_to = PageOf(i) * G.PAGE_W
  if PageOf(i) ~= old_page then
    cam = cam_to                -- one page of instances: the page switches at once
    DrawGrid()
    DrawPager()
  end
  DrawCursor()
  UpdateGuideLine()
end

local function MoveFocus(dx, dy)
  if #list == 0 then
    return
  end
  SetFocus(Neighbour(focus, dx, dy), true)
  Log("cursor", focus, "page", PageOf(focus), "slot", SlotOf(focus))
end

-- page d pages away (wheel, arrows, dots): the cursor keeps its place on the page (clamped to the last item)
local function GoPage(p)
  p = math.max(0, math.min(pages - 1, p))
  if p == PageOf(focus) then
    return
  end
  SetFocus(math.min(#list, p * per + (focus - 1) % per + 1), true)
end

local function SwitchTab(d)
  if #tabs < 2 then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  tab = (tab - 1 + d) % #tabs + 1
  funcLuaCommand(C.SE, SE_OK)
  DrawAll()
end

-- ---- the mouse (hit areas = the instances' global positions, so the same layout) ---------------------------------
local function Pointer()
  local mx, my = funcLuaMenuCommand(MS.POINTER)
  if type(mx) ~= "number" or type(my) ~= "number" then
    return nil
  end
  return mx, -my
end

local function Over(layer, idx, mx, py, w, h)
  local gx, gy = funcLuaMenuCommand(MS.GPOS, layer, idx)
  return type(gx) == "number" and math.abs(mx - gx) <= w and math.abs(py - gy) <= h
end

-- the item under the pointer (inside the hexagon: |dx| <= w/2 and the slanted edges), or nil
local function PointedItem()
  local mx, py = Pointer()
  if mx == nil then
    return nil
  end
  for s, i in pairs(shown) do
    local gx, gy = funcLuaMenuCommand(MS.GPOS, L_HEX, s)
    if type(gx) == "number" then
      local dx, dy = math.abs(mx - gx), math.abs(py - gy)
      if dx <= G.HEX_W / 2 and dy <= G.HEX_H / 2 - dx * (G.HEX_H / 4) / (G.HEX_W / 2) then
        return i
      end
    end
  end
  return nil
end

--@lib evt_menu_kit.lua#StartCo

local function PollMouse()
  if evt_co ~= nil or not ready or open_guard > 0 then
    return
  end
  if Call(MS.CHECK_INPUT, MS.MENU_CTRL, MS.WHEEL_DOWN) == true then
    GoPage(PageOf(focus) + 1)
  elseif Call(MS.CHECK_INPUT, MS.MENU_CTRL, MS.WHEEL_UP) == true then
    GoPage(PageOf(focus) - 1)
  end
  -- hover follows the pointer only when it really moved (Nacho 07/10 round 2: a pointer resting on a hex kept
  -- pulling the focus back to it, so Aceptar after the arrow keys opened the team under the mouse, «Wild»)
  local px, py = Pointer()
  local moved = px ~= nil and last_ptr ~= nil and (math.abs(px - last_ptr[1]) > 2 or math.abs(py - last_ptr[2]) > 2)
  if px ~= nil then
    last_ptr = {px, py}
  end
  if moved and funcLuaMenuCommand(MS.MOVED) == true and cam == cam_to then
    SetFocus(PointedItem(), true)
  end
  if Call(MS.CHECK_INPUT, MS.MENU_CTRL, MS.CLICK) ~= true then
    return
  end
  local mx, py = Pointer()
  if mx == nil then
    return
  end
  if pages > 1 then
    if PageOf(focus) > 0 and Over(L_UI, UI_ARROW_L, mx, py, MS.HIT_ARROW, MS.HIT_ARROW) then
      GoPage(PageOf(focus) - 1)
      return
    elseif PageOf(focus) < pages - 1 and Over(L_UI, UI_ARROW_R, mx, py, MS.HIT_ARROW, MS.HIT_ARROW) then
      GoPage(PageOf(focus) + 1)
      return
    end
    for d = 0, math.min(pages, G.MAX_DOTS) - 1 do
      if Over(L_UI, UI_DOT0 + d, mx, py, MS.HIT_DOT, MS.HIT_DOT) then
        GoPage(DotStart() + d)
        return
      end
    end
  end
  local i = PointedItem()
  if i ~= nil then
    SetFocus(i, false)
    click_guard = CLICK_GUARD
    StartCo(Decide, "click")
  end
end

local function OpenFlow()
  local got = FlushPoints()
  ReadBalance()
  DrawBalance()
  UpdateGuideLine()
  if got > 0 then
    Message(string.format(TXT.GOT, got))
  end
end

-- ---- engine callbacks -----------------------------------------------------------------------------------------------
function OnInit()
  funcLuaCommand(C.P_CLEAR, KEY_RESULT)
  funcLuaMenuCommand(C.LOAD_TEX, TEX_UI)
  funcLuaMenuCommand(C.LOAD_TEX, TEX_MAP)
  funcLuaMenuCommand(C.LOAD_TEX, TEX_MARKER)
  funcLuaMenuCommand(C.LOAD_TEX, "#/menu/200_icon/02_icon_item/icon_item10.g4tx")   -- the pill's icon
  funcLuaMenuCommand(C.LOAD_TEX, "#/menu/200_icon/16_icon_list_tab/<LG>/icon_list_tab.g4tx")   -- the tab icon
  tabs = {}
  for _, t in ipairs(TABS) do
    if t.ready then
      tabs[#tabs + 1] = t
    end
  end
  tab, focus, anim, shown, ready = 1, 1, {}, {}, false
  open_guard = 20
  level, cur_team, back, cache, tex_asked = "teams", nil, nil, {}, {}
  ReadList()
  cam = PageOf(focus) * G.PAGE_W
  cam_to = cam
  Log("open", #list, "avatars, focus", focus, "tabs", #tabs)
end

local function OpenOwnLayers()
  for i = 0, 2 do                 -- 0 the section header, 1 / 2 the Q / E page glyphs
    funcLuaMenuCommand(C.OPEN_LAYER, L_TABBAR, i)
  end
  funcLuaMenuCommand(C.OPEN_LAYER, L_TABITEM, 0)
  funcLuaMenuCommand(C.OPEN_LAYER, L_PILL, 0)
  for i = 0, UI_DOT0 + G.MAX_DOTS - 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_UI, i)
  end
  for s = 0, per - 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_HEX, s)
    funcLuaMenuCommand(C.OPEN_LAYER, L_SHADOW, s)
    funcLuaMenuCommand(C.OPEN_LAYER, L_AV, s)
  end
  for i = 0, per * N_PER_HEX - 1 do
    funcLuaMenuCommand(C.OPEN_LAYER, L_PRICE, i)
  end
end

function OnSetupLayer(a1, a2)
  if a1 == L_HEADER then
    SetupSoccerTopCommonHeaderLayerInfo(a1, 4153539961, 253801632, 3969848060, 1144161661, 3293713115, 253801632, 1152304044, 305955024, 3007971317)
    SwapSoccerTopCommonHeaderMenuModeIconTexture(1566262113 --[[mode_base02, as the INAROGUE menu]])
    UpdateHeader(3586861540)
    UpdateTitle()
    OpenOwnLayers()
  elseif a1 == L_ROW then
    funcLuaMenuCommand(C.TEXT, a1, 931545948 --[[_text_list01_on]], "", a2)
    funcLuaMenuCommand(C.TEXT, a1, 3705682548 --[[_text_list01_off]], "", a2)
    funcLuaMenuCommand(C.TEXT_VISIBLE, a1, 931545948, false, a2)
    funcLuaMenuCommand(C.TEXT_VISIBLE, a1, 3705682548, false, a2)
    for _, m in ipairs(ROW_MESHES) do
      funcLuaMenuCommand(C.MESH_VISIBLE, a1, m, false, a2)
    end
    funcLuaMenuCommand(C.ATTACH_TRACE, a1, a2, CUR, false)
  elseif a1 == L_HEX or a1 == L_SHADOW or a1 == L_AV or a1 == L_PRICE or a1 == L_UI then
    Hide(a1, a2)                -- DrawAll draws what is used when the anchor opens
  elseif a1 == L_TABBAR then    -- as shop_menu_buy OnSetupLayer: its text style and plate, no sort icon / button text
    funcLuaMenuCommand(C.TEXT_STYLE, a1, a2, TB.TEXT, TB.STYLE)
    funcLuaMenuCommand(C.SPRITE, a1, TB.TEX, TB.SPR, TB.BASE, 0, a2)
    funcLuaMenuCommand(C.MESH_VISIBLE, a1, TB.SORT, false, a2)
    funcLuaMenuCommand(C.TEXT_VISIBLE, a1, TB.BTN, false, a2)
    funcLuaMenuCommand(C.ATTACH_TRACE, a1, a2, CUR, false)
    Hide(a1, a2)
  elseif a1 == L_TABITEM then   -- the section's tab (DrawTabs fills it)
    funcLuaMenuCommand(C.ATTACH_TRACE, a1, a2, CUR, false)
    Hide(a1, a2)
  elseif a1 == L_PILL then      -- as shop_menu_buy OnSetupLayer: the token icon on icon_token_dmy01
    funcLuaMenuCommand(C.ATTACH_TRACE, a1, a2, CUR, false)
    funcLuaMenuCommand(C.SPRITE, a1, PILL.ICON_TEX, PILL.ICON, PILL.ICON_NODE, 0, a2)
    Hide(a1, a2)
  elseif a1 == L_GUIDE_LINE then
    UpdateGuideLine()
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
    ReadBalance()
    DrawAll()
    UpdateButtonGuide()
    ready = true
    if funcLuaCommand(C.FADE_DONE) then
      funcLuaCommand(C.FADE, 0, 0.3)
    end
    StartCo(OpenFlow)
  elseif a1 == L_GUIDE_LINE then
    UpdateGuideLine()
  end
end

function OnDecideFocus(a1, a2)
  if evt_co ~= nil or not ready or open_guard > 0 then
    return
  end
  -- the engine's decide (pad A / Enter, and the CMD_ENTER of a clicked hex) always decides OUR cursor (focus): its
  -- a2 is the hex layer's native focus, which stays 0 (round 4: pad A on slot 2 opened Raimon, slot 0). A click is
  -- decided by the mouse poll; its CMD_ENTER arrives after it and is swallowed (click_guard).
  if click_guard > 0 then
    Log("decide ignored (click)", a1, a2)
    return
  end
  StartCo(Decide, "key")
end

function OnFunction(a1, a2)
  if evt_co ~= nil then
    return 1
  end
  local id = a1
  if a1 ~= FN.UP and a1 ~= FN.DOWN and a1 ~= FN.LEFT and a1 ~= FN.RIGHT and a1 ~= FN.TAB_PREV and a1 ~= FN.TAB_NEXT
     and a1 ~= FN.PAGE_PREV and a1 ~= FN.PAGE_NEXT then
    id = a2
  end
  if id == FN.UP then
    MoveFocus(0, -1)
  elseif id == FN.DOWN then
    MoveFocus(0, 1)
  elseif id == FN.LEFT then
    MoveFocus(-1, 0)
  elseif id == FN.RIGHT then
    MoveFocus(1, 0)
  elseif id == FN.TAB_PREV then
    SwitchTab(-1)
  elseif id == FN.TAB_NEXT then
    SwitchTab(1)
  elseif id == FN.PAGE_PREV then         -- L2 / R2 (Q / E): the page keys shown next to the dots
    GoPage(PageOf(focus) - 1)
  elseif id == FN.PAGE_NEXT then
    GoPage(PageOf(focus) + 1)
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
    Log("back ignored", ready, open_guard)
    return 1
  end
  if level == "members" then
    BackToTeams()
    return 1
  end
  funcLuaCommand(C.SE, SE_BACK)
  if save_req ~= nil and not save_req.sent then
    Call(RL.SAVE)                  -- a pending save request goes out before the screen closes
  end
  Close(0)
  return 1
end

local function SaveStep()
  local s = save_req
  if s == nil or s.sent then
    return
  end
  s.frames = s.frames + 1
  local ok, busy = pcall(funcLuaCommand, RL.SAVE_BUSY)
  if ok and busy == true and s.frames < 300 then
    return
  end
  s.sent = true
  Call(RL.SAVE)
  Log("save request")
end

function Step()
  if evt_co ~= nil then
    if coroutine.status(evt_co) == "dead" then
      evt_co = nil
    else
      local ok, err = coroutine.resume(evt_co)
      if not ok then
        PRINT("evt_rogue_shop_menu: " .. tostring(err))
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
  if click_guard > 0 then
    click_guard = click_guard - 1
  end
  PollMouse()
  if evt_co == nil then
    SaveStep()
  end
  if not ready then
    return
  end
  if cam ~= cam_to then        -- a page change not made by SetFocus: switch at once
    cam = cam_to
    DrawGrid()
  end
  for _, i in pairs(shown) do   -- the breathing idle
    local st = anim[i]
    st.ft = st.ft + 1
    if st.ft >= IDLE[st.fi][2] then
      st.ft, st.fi = 0, st.fi % #IDLE + 1
      DrawSprite(i, false)
    end
  end
end
