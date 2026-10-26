-- util_album_menu (plain Lua 5.2 source): BetterQoL's «Álbum de jugadores» page (docs/game/ui/album.md).
-- Declared in content\menus\album.toml ([[screen]], served as common/script/lua/menu/util_album_menu.lua.bin).
-- Opened from «Caseta del club» (play_guide_top_menu, assets\lua\play_guide_top_menu\155_album.lua) the way that menu
-- opens its «Archivo de escenas»: the Caseta keeps its background, its header (title «Álbum de jugadores»), its button
-- guide and its return arrow; this page draws the LEFT half over them:
--   * the type row: Y at the left end, «Nombre» / «Juego» right of it;
--   * the group row: LB / RB at the ends, the groups between them (the game's series tab icons, or letter ranges);
--   * the band: type › group, «Tienes X / Y»; two columns of 10 rows (down the first, then the second), each row the
--     game's check box (ticked = the club has the player), his kit miniface and his name; «Página N/M» under them;
-- and opens the game's player plate (personal_plate_menu) on the RIGHT half in its players-universe mode (a card id,
-- a level and a rarity, as the game's pack list chara_pack_probability_list_menu does): the club's best copy of the
-- selected player, else his card at level 1 with the «No lo tienes» badge under it. The plate keeps its own menu
-- inactive in that mode; this page turns its pages (L2 / R2). Its 3D model: Character Reforged's plate model on its
-- capture layer while this page exists (assets/lua/personal_plate_menu/135_album_pages.lua).
-- Keys (cmd rows of the off-screen anchor row -> OnFunction / OnBack): up / down move, left / right the other column
-- of the same row (from the right column a right goes to the next page's left column, from the left column a left to
-- the previous page's right column; the pages wrap), Y the type, LB / RB the group, L2 / R2 the plate's pages,
-- B / Esc / right click close (the engine closes the page; the plate is asked to close here and by the opener).
-- Mouse / free cursor: the zones of the drawn rows, type and group tabs, the group keys and the page arrows (hover
-- selects a row when the pointer moves, a click picks; a click on the selected row = A), the wheel moves.
-- A: the selected player's action of another mod, BetterQoL.AlbumActions (docs/game/ui/album.md §5): the first entry
-- whose On() holds runs Run(row) as a coroutine resumed from Step (it may open the game's message windows); keys and
-- the pointer wait while it runs; when it answers true (the club changed) the album data is read again.
-- Data: BetterQoL's scripts\album.lua (CMND_BETTERQOL_ALBUM_OPEN when the page opens, CMND_BETTERQOL_ALBUM_PAGE on each page /
-- group / type change). Drawing only when something changed; minifaces per page. No engine call at load time.
INCLUDE("LUA_PROG_BASE")
INCLUDE("LUA_PROG_COMMON")

local CMD = { OPEN = 3117903358 --[[CMND_BETTERQOL_ALBUM_OPEN]], PAGE = 162355322 --[[CMND_BETTERQOL_ALBUM_PAGE]] }
local C = {
  LOG = 3661580131, TEXT_GET = 4074371074, LANG = 477234096, SND = 3073642526,
  LAYER_NUM = 1175615627, OPEN_LAYER = 629267548, VISIBLE = 711242136, POS = 1389957207, SCALE = 3778714801,
  SPRITE = 558735651, ALPHA = 4231609516, MESH_VISIBLE = 3405944500, NODE_VISIBLE = 2158717427,
  TEXT_VISIBLE = 2735666188, SET_TEXT = 1083631230, LOAD_TEX = 839427544, TEX_LOADING = 1506186496,
  FACE = 552280324, RESET_FACE = 4176779611, LOADING = 1277042906, CHECK_INPUT = 4265778440,
  TEXT_STYLE = 2333948100, CTRL = 3518307824, LIST_NUM = 3252599449, FOCUS_SET = 3466097042,
  ATTACH_TRACE = 1774843228, CHARA_INFO = 4060384944,
  GET_PRIO = 1018283794 --[[CMND_GET_DRAW_PRIORITY]], SET_PRIO = 1491630496 --[[CMND_SET_DRAW_PRIORITY]],
  PARAM_EXISTS = 2947612279, PARAM_DELETE = 3363400568, PARAM_SET = 3860611758,
  OPEN_MENU = 433545986, CLOSE_MENU = 320421347, IS_MENU = 2231168902, IS_OPEN_MENU = 3693934564,
}
local MENU_CTRL = 1332654303
local WHEEL_UP, WHEEL_DOWN = 1942756954 --[[CMD_EVT_WHEEL_UP]], 1623431741 --[[CMD_EVT_WHEEL_DOWN]]
-- the pointer (mouse and VR's free cursor, docs/game/ui/mouse-support.md §5): position (screen px, y down), the
-- engine's «moved» flag, the mouse's left button
local POINTER = { POS = 558229292, MOVED = 3272825600, LEFT = 218912913 --[[CMD_EVT_MOUSE_LEFT]] }
-- the page's layers (content\menus\album.toml)
local L = { PLATE = 4160871141, ICON = 699561794, FACE = 1228023294, TEXT = 2007890270 }
local L_ANCHOR = 3455690937        -- save01_02_list_item: the input anchor (1 instance, off screen)
local L_LINE = 3078308064          -- mainmenu90_05_content_guide_line01
local LINE_TEXT = 378156699        -- _text_guide01
local ANCHOR = {
  TEXTS = { 931545948 --[[_text_list01_on]], 3705682548 --[[_text_list01_off]] },
  CURSOR = 3313461902,             -- the «cursor» locator
}
-- the anchor's functions (cmd rows: crc32 of the names)
local FN = {
  [3533807059] = "up", [1356451490] = "down", [910277105] = "left", [1029011626] = "right",
  [4230302454] = "type_prev", [1156108959] = "type_next", [3559612738] = "group_prev", [1827076395] = "group_next",
  [2512251038] = "plate_prev", [762343671] = "plate_next", [2674977970] = "accept",
}
local QUAD = 1909474081            -- icon_new01: the cmn01_10 quad's sprite slot
local Q = 36                       -- the cmn01_10 quad side
local TXT = { NODE = 378327766 --[[_text_cmd_back01]], MESHES = {298211823, 2853207670}, BOX_LEFT = -384, BOX_MID_Y = 144 }
local CARD = {
  MESH = 2828003679 --[[_icon_chr_dmy_l01]], TEX = 21929195 --[[icon_chr_dmy_l01]], NAME = 170976702 --[[_text_chr01]],
  RH = 156, OX = 59, OY = 11,
  HIDE = {"_icon_chr_base_l01", "_icon_chr_gradation_l01", "_seasonal_frame_l01", "_avatar_frame_l01",
    "_icon_chr_focus_l01", "_icon_chr_position_dmy_l01", "_icon_base_l01", "_icon_chr_type_dmy_l01", "_icon_lock01",
    "_icon_captain01", "_icon_ai_role_dmy01", "_gtxt_lv_l01", "_icon_card01", "_icon_chr_def01_l",
    "_icon_chr_grayout01", "_basara_avatar_l01", "_num_chr_dmy_l01", "_num_chr_dmy_l02", "_gauge_exp_base_l01",
    "_gauge_exp_l01", "_icon_synergy_l01", "_icon_synergy_l02", "_leader_base01", "_gtxt_leader01"},
  HIDE_NODES = {"_pos_base02", "_pos_leader01", "_pos_ai_role01", "_num_chr_l01", "_num_chr_l02", "_pos_gauge_exp_l01"},
}
-- the player plate the page opens (personal_plate_menu, players-universe mode: personal_plate_menu OnInit)
local PLATE = {
  MENU = 1427722143 --[[personal_plate_menu]], PAGE = 878737202 --[[team11_01_personal_plate]],
  P_PARAM = 3928123478, P_LEVEL = 3894267099, P_RARITY = 571278276,
  FLAG = 2398708549 --[[BetterQoL.album_plate: set while this page shows the plate (assets\lua\personal_plate_menu\135_album_pages.lua)]],
  SET = 1101551215 --[[(param, level, rarity, false): the plate's player]],
  PAGE_PREV = 567813453, PAGE_NEXT = 2019940505, PAGE_UPDATE = 3297841487,
  RARITY_DEFAULT = 4, RARITY_MAX = 7, WAIT = 180,
}
local SY_MOVE, SY_PAGE, SY_ERROR = 2500047763, 2629173176 --[[sy0009]], 2086672038
local GLYPH = 0.5
local STYLE = {
  section = "fs2_26_w_lc_2d2_001_nr", tab = "fs_28_b_lc_2d0_001", name = "fs_28_b_lc_2d0_001",
  head = "fs2_26_w_lc_2d2_001_nr",   -- on the page's background: outlined white (the page counter, the empty list)
}
-- the page (screen px at 1080p, y down): the left half under the Caseta's header (0-145), above its content guide
-- line (913); the plate's half from plate_x; the «No lo tienes» badge under the plate
local P = { x = 60, width = 900, type_y = 168, type_h = 44, tabs_y = 206, tab_h = 58, tab_gap = 4, key_w = 46,
  band_y = 274, band_h = 40, top = 320, cols = 2, rows = 10, row_h = 50, row_gap = 4, col_gap = 14, box = 32,
  mark = 44, face = 50, page_y = 878, badge_x = 1880, badge_y = 912, badge_h = 44 }
P.col_w = math.floor((P.width - P.col_gap) / 2)
local PER_PAGE = P.cols * P.rows
local ART, SPRITE = "#/menu/220_img/util_club_stats/util_club_stats.g4tx", "util_club_stats_"
local RETAIL = {
  list = { tex = "#/menu/51_save/save01/save01_02/save01_02.g4tx",
           off = "list_base_s01_off", focus = "list_base_s01_ol" },
  cursor = { tex = "#/menu/20_cmn/cmn05/cmn05_01/cmn05_01.g4tx", sprite = "cur01", w = 128, h = 152 },
  check = { tex = "#/menu/102_team/team16/team16_03/team16_03.g4tx", box = "icon_check_box01", mark = "icon_list_check01" },
  tabs = { tex = "#/menu/200_icon/16_icon_list_tab/<LG>/icon_list_tab.g4tx", w = 144, h = 96 },
}
local KIND_NAME, KIND_GAME = 1, 2
local WAIT_FRAMES = 300            -- frames a change keeps redrawing while textures / minifaces still load

-- state of this opening
local S = { ready = false, ok = false, kind = KIND_GAME, group = 1, page = 1, pages = 1, sel = 1, data = nil,
  rows = {}, total = 0, owned = 0, sent = {}, used = {}, shown = {}, texts = {}, loaded = {}, faces = {}, cap = {},
  opened = {}, dirty = true, frame = 0, plate = nil, line = nil, zones = {}, ptr = {} }

-- ---- helpers (this menu has its own VM) ------------------------------------------------------------------------------
local CRC_T, CRCS = nil, {}
local function Crc(s)
  local c = CRCS[s]
  if c ~= nil then return c end
  if CRC_T == nil then
    CRC_T = {}
    for i = 0, 255 do
      local v = i
      for _ = 1, 8 do
        if v % 2 == 1 then v = bit32.bxor(bit32.rshift(v, 1), 0xEDB88320) else v = bit32.rshift(v, 1) end
      end
      CRC_T[i] = v
    end
  end
  c = 0xFFFFFFFF
  for i = 1, #s do
    c = bit32.bxor(bit32.rshift(c, 8), CRC_T[bit32.band(bit32.bxor(c, s:byte(i)), 0xFF)])
  end
  c = bit32.bxor(c, 0xFFFFFFFF)
  CRCS[s] = c
  return c
end

local function Log(...)
  local p = {}
  for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
  pcall(funcLuaCommand, C.LOG, "betterqol album " .. table.concat(p, " "))
end

-- a text of text/rows/album.toml (id "BetterQoL.Album.<name>"), in the game's language
local function Tx(name)
  local t = S.texts[name]
  if t == nil then
    local ok, s = pcall(funcLuaCommand, C.TEXT_GET, Crc("BetterQoL.Album." .. name))
    t = (ok and type(s) == "string" and s ~= "") and s or name
    S.texts[name] = t
  end
  return t
end

-- the same, but an empty text stays empty (the name groups: empty = one group with every name)
local function TxRaw(name)
  local ok, s = pcall(funcLuaCommand, C.TEXT_GET, Crc("BetterQoL.Album." .. name))
  return (ok and type(s) == "string") and s or ""
end

local function Fill(s, a, b)
  s = tostring(s):gsub("{1}", function() return tostring(a) end)
  return (s:gsub("{2}", function() return tostring(b) end))
end

local function M(cmd, ...)
  local ok, a, b = pcall(funcLuaMenuCommand, cmd, ...)
  if ok then return a, b end
  return nil
end

local function Snd(s) pcall(funcLuaCommand, C.SND, s) end

local function In(input)
  local ok, r = pcall(funcLuaCommand, C.CHECK_INPUT, MENU_CTRL, input)
  return ok and r == true
end

-- ---- drawing pools (only what changed is sent) ------------------------------------------------------------------------

local function Set(layer, idx, prop, cmd, ...)
  local k = layer .. ":" .. idx .. ":" .. prop
  local a = table.pack(...)
  local sig = {}
  for i = 1, a.n do sig[#sig + 1] = tostring(a[i]) end
  sig = table.concat(sig, ",")
  if S.sent[k] == sig then return end
  S.sent[k] = sig
  M(cmd, ...)
end

local function Slot(layer)
  local n = S.used[layer] or 0
  if n >= (S.cap[layer] or 0) then return nil end
  S.used[layer] = n + 1
  if not S.opened[layer .. ":" .. n] then
    M(C.OPEN_LAYER, layer, n)
    S.opened[layer .. ":" .. n] = true
  end
  return n
end

local function Show(layer, i)
  Set(layer, i, "vis", C.VISIBLE, layer, i, true)
  S.shown[layer .. ":" .. i] = true
end

local function TexReady(tex)
  if S.loaded[tex] == nil then
    pcall(funcLuaMenuCommand, C.LOAD_TEX, tex)   -- CMND_LOAD_MENU_RES_TEXTURE is a menu command
    S.loaded[tex] = true
  end
  local ok, loading = pcall(funcLuaCommand, C.TEX_LOADING, Crc(tex))
  return ok and loading == false
end

-- a pool layer's own draw priority (read once from its first instance, before any is raised)
local function BasePrio(layer)
  S.prio = S.prio or {}
  if S.prio[layer] == nil then
    local p = M(C.GET_PRIO, layer, 0)
    S.prio[layer] = type(p) == "number" and p or false
  end
  return S.prio[layer]
end

-- raise = 1: drawn one priority above the layer's other instances (the tick over its check box: instances of one
-- priority have no fixed order); 0 / nil: the layer's own priority
local function Quad(layer, tex, sprite, x, y, w, h, raise)
  if not TexReady(tex) then
    S.waiting = true
    return nil
  end
  local i = Slot(layer)
  if i == nil then return nil end
  Show(layer, i)
  Set(layer, i, "sc", C.SCALE, layer, w / Q, h / Q, 1, i)
  Set(layer, i, "sp", C.SPRITE, layer, Crc(tex), Crc(sprite), QUAD, 0, i)
  Set(layer, i, "pos", C.POS, layer, x + w / 2, -(y + h / 2), 0, i)
  Set(layer, i, "a", C.ALPHA, layer, i, 0, 1)
  local base = BasePrio(layer)
  if base then Set(layer, i, "prio", C.SET_PRIO, layer, i, base + (raise or 0), true) end
  return i
end

local function Plate(layer, look, x, y, w, h)
  return Quad(layer, RETAIL.list.tex, RETAIL.list[look], x, y, w, h)
end

local function Cursor(x, y, h)
  local R = RETAIL.cursor
  local w = h * R.w / R.h
  return Quad(L.ICON, R.tex, R.sprite, x - w, y - h / 2, w, h)
end

local function Units(s)
  local u = 0
  local plain = tostring(s or ""):gsub("<[%u%d_]+>", "MM")   -- a button tag: about two glyphs wide
  for ch in plain:gmatch("[%z\1-\127\194-\244][\128-\191]*") do u = u + ((ch:byte(1) or 0) >= 0xE3 and 2 or 1) end
  return u
end

-- a text: left edge x, vertical middle y, a style of STYLE, scale (1 = the style's own size)
local function Text(s, x, y, style, sc)
  if s == nil or s == "" then return nil end
  local i = Slot(L.TEXT)
  if i == nil then return nil end
  sc = sc or 1
  Show(L.TEXT, i)
  for _, m in ipairs(TXT.MESHES) do Set(L.TEXT, i, "m" .. m, C.MESH_VISIBLE, L.TEXT, m, false, i) end
  Set(L.TEXT, i, "st", C.TEXT_STYLE, L.TEXT, i, TXT.NODE, Crc(STYLE[style] or STYLE.name))
  Set(L.TEXT, i, "txt", C.SET_TEXT, L.TEXT, TXT.NODE, s, i)
  Set(L.TEXT, i, "sc", C.SCALE, L.TEXT, sc, sc, 1, i)
  Set(L.TEXT, i, "pos", C.POS, L.TEXT, x - TXT.BOX_LEFT * sc, -y - TXT.BOX_MID_Y * sc, 0, i)
  return i
end

-- a text centred on cx (its width estimated from the glyph size `px` of the style at scale 1)
local function TextC(s, cx, y, style, px, sc)
  sc = sc or 1
  return Text(s, cx - Units(s) * px * sc * GLYPH / 2, y, style, sc)
end

local function TextR(s, rx, y, style, px, sc)
  sc = sc or 1
  return Text(s, rx - Units(s) * px * sc * GLYPH, y, style, sc)
end

local function Fit(s, px, size)
  s = tostring(s or "")
  local units = math.floor(px / (size * GLYPH))
  if units <= 1 or Units(s) <= units then return s end
  local out, u = {}, 0
  for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    local w = (ch:byte(1) or 0) >= 0xE3 and 2 or 1
    if u + w > units - 1 then break end
    out[#out + 1] = ch
    u = u + w
  end
  return (table.concat(out):gsub("[%s%p]+$", "")) .. "…"
end

local function Opt(f, ...)
  if type(f) == "function" then pcall(f, ...) end
end

-- the retail list character card, portrait only (face + kit, as the game composes it), centred at (cx, cy)
local function Face(key, cx, cy, size)
  local i = Slot(L.FACE)
  if i == nil then return end
  local s = size / CARD.RH
  Show(L.FACE, i)
  Set(L.FACE, i, "sc", C.SCALE, L.FACE, s, s, 1, i)
  Set(L.FACE, i, "pos", C.POS, L.FACE, cx - CARD.OX * s, -cy - CARD.OY * s, 0, i)
  if S.faces[i] ~= key then
    for _, m in ipairs(CARD.HIDE) do M(C.MESH_VISIBLE, L.FACE, Crc(m), false, i) end
    for _, m in ipairs(CARD.HIDE_NODES) do M(C.NODE_VISIBLE, L.FACE, Crc(m), false, i) end
    M(C.TEXT_VISIBLE, L.FACE, CARD.NAME, false, i)
    M(C.RESET_FACE, L.FACE, i, CARD.TEX)
    Opt(SetDisableForceCharaInvalidUseTarget)
    M(C.FACE, L.FACE, i, false, CARD.MESH, CARD.TEX, 0, 0, key, 0, false, true)
    Opt(SetEnableForceCharaInvalidUseTarget)
    S.faces[i] = key
  end
  local loading = M(C.LOADING, L.FACE, i) == true
  if loading then S.waiting = true end
  M(C.MESH_VISIBLE, L.FACE, CARD.MESH, not loading, i)
end

local function BeginFrame() S.used, S.waiting, S.zones = {}, false, {} end

-- a pointer zone (screen px, top-left + size, y down) of something drawn now: kind + value
local function Zone(x, y, w, h, kind, v)
  S.zones[#S.zones + 1] = { x, y, x + w, y + h, kind = kind, v = v }
end

local function EndFrame()
  for k in pairs(S.shown) do
    local layer, i = k:match("^(%d+):(%d+)$")
    layer, i = tonumber(layer), tonumber(i)
    if layer and i and i >= (S.used[layer] or 0) then
      Set(layer, i, "vis", C.VISIBLE, layer, i, false)
      S.shown[k] = nil
      if layer == L.FACE then S.faces[i] = nil end
    end
  end
end

-- ---- the player plate (the right half) -----------------------------------------------------------------------------

local function ParamSet(k, v)
  if funcLuaCommand(C.PARAM_EXISTS, k) == true then funcLuaCommand(C.PARAM_DELETE, k) end
  funcLuaCommand(C.PARAM_SET, k, 0, v, 1)
end

local function ParamClear(k)
  if funcLuaCommand(C.PARAM_EXISTS, k) == true then funcLuaCommand(C.PARAM_DELETE, k) end
end

local function PlateExists() return M(C.IS_MENU, PLATE.MENU) == true end

local function PlateUp()
  local ok, up = pcall(funcLuaCommand, C.IS_OPEN_MENU, PLATE.MENU, PLATE.PAGE)
  return ok and up == true
end

-- the plate's player of a row: the club's copy (param, level, rarity) or the card at level 1
local function Who(r)
  local rar = r.rarity
  if not r.owned or rar == nil or rar <= 0 then
    local ok, has, v = pcall(funcLuaCommand, C.CHARA_INFO, r.param, 8)
    rar = (ok and has == true and type(v) == "number" and v >= 0 and v <= PLATE.RARITY_MAX) and v or PLATE.RARITY_DEFAULT
  end
  return r.param, r.owned and math.max(1, r.level) or 1, rar
end

local function PlateOpen(r)
  local param, level, rar = Who(r)
  ParamSet(PLATE.P_PARAM, param)
  ParamSet(PLATE.P_LEVEL, level)
  ParamSet(PLATE.P_RARITY, rar)
  ParamSet(PLATE.FLAG, 1)
  pcall(funcLuaCommand, C.OPEN_MENU, PLATE.MENU)
  S.plate = { state = "opening", at = S.frame, seen = false, param = param, pending = nil }
  Log("plate open asked: param", param, "level", level, "rarity", rar)
end

-- the selected row on the plate (once it is up)
local function PlateShow()
  local r = S.rows[S.sel]
  local P_ = S.plate
  if r == nil or P_ == nil then return end
  if P_.state == nil and not PlateExists() then
    PlateOpen(r)
    return
  end
  if P_.state ~= "up" then
    P_.pending = r
    return
  end
  P_.pending = nil
  local param, level, rar = Who(r)
  if P_.param == param and P_.level == level then return end
  M(PLATE.SET, param, level, rar, false)
  P_.param, P_.level = param, level
end

local function PlateStep()
  local P_ = S.plate
  if P_ == nil or P_.state ~= "opening" then
    if P_ ~= nil and P_.state == "up" and P_.pending ~= nil then PlateShow() end
    return
  end
  if PlateExists() then
    P_.seen = true
    if PlateUp() then
      P_.state = "up"
      ParamClear(PLATE.P_PARAM)
      ParamClear(PLATE.P_LEVEL)
      ParamClear(PLATE.P_RARITY)
      Log("plate up")
      if P_.pending ~= nil then PlateShow() end
    end
  elseif P_.seen or S.frame - P_.at > PLATE.WAIT then
    Log("the plate did not open")
    P_.state = "failed"
  end
end

local function PlatePage(d)
  if S.plate == nil or S.plate.state ~= "up" or not PlateUp() then
    Snd(SY_ERROR)
    return
  end
  M(d < 0 and PLATE.PAGE_PREV or PLATE.PAGE_NEXT)
  M(PLATE.PAGE_UPDATE)
end

-- ---- data --------------------------------------------------------------------------------------------------------------

local function Groups() return S.data and S.data.groups and S.data.groups[S.kind] or {} end

-- the content guide line: the selected player's team and game
local function LineText()
  if not S.ok then return Tx("NoSave") end
  local r = S.rows[S.sel]
  if r == nil then return "" end
  return Fill(Tx("Line"), r.team ~= "" and r.team or "-", r.game)
end

local function SetLine()
  local s = LineText()
  if s ~= S.line then
    S.line = s
    M(C.SET_TEXT, L_LINE, LINE_TEXT, s)
  end
end

local function LoadPage()
  S.rows = {}
  local ok, t = pcall(funcLuaCommand, CMD.PAGE, S.kind, S.group, S.page, PER_PAGE)
  if not ok or type(t) ~= "table" then
    S.pages, S.total, S.owned = 1, 0, 0
    return
  end
  S.page, S.pages, S.total, S.owned = t.page or 1, t.pages or 1, t.total or 0, t.owned or 0
  for k, e in ipairs(type(t.rows) == "table" and t.rows or {}) do
    S.rows[k] = { base = tonumber(e[1]) or 0, param = tonumber(e[2]) or 0, name = tostring(e[3] or ""),
      team = tostring(e[4] or ""), game = tostring(e[5] or ""), owned = e[6] == true, level = tonumber(e[7]) or 1,
      rarity = tonumber(e[8]) or 0 }
  end
  S.sel = math.max(1, math.min(#S.rows, S.sel))
  S.dirty = true
  SetLine()
  PlateShow()
end

local function Load()
  local okl, lang = pcall(funcLuaCommand, C.LANG)
  local ok, t = pcall(funcLuaCommand, CMD.OPEN, okl and lang or 1, TxRaw("NameGroups"), Tx("OtherGroup"))
  S.ok = ok and type(t) == "table" and type(t.groups) == "table"
  S.data = S.ok and t or nil
  if not S.ok then
    Log("no album data", tostring(t))
    return
  end
  Log("page opened:", t.total, "player(s),", t.owned, "in the club")
end

-- ---- drawing -----------------------------------------------------------------------------------------------------------

local BLUE_STYLE = "tab"

-- the type row: L2 left, R2 right, the two types spread between them
local function DrawTypes()
  local y, h = P.type_y, P.type_h
  Text(Tx("KeysType"):match("^(<[^>]+>)") or "", P.x, y, "head")
  Zone(P.x, y - h / 2, P.key_w, h, "type_key", 1)
  local x0, x1 = P.x + P.key_w + 6, P.x + P.width
  local names = { Tx("TypeName"), Tx("TypeSeries") }
  local w = (x1 - x0 - 4) / #names
  for k, s in ipairs(names) do
    local x = x0 + (k - 1) * (w + 4)
    Plate(L.PLATE, "off", x, y - h / 2, w, h)
    if k == S.kind then Plate(L.ICON, "focus", x, y - h / 2, w, h) end
    TextC(s, x + w / 2, y + 1, BLUE_STYLE, 28)
    Zone(x, y - h / 2, w, h, "type", k)
  end
end

-- the group row: LB left, RB right, the groups between them (series tab icons, else their labels)
local function DrawGroups()
  local gl = Groups()
  local y, h = P.tabs_y, P.tab_h
  local mid = y + h / 2
  Text(Tx("KeysGroup"):match("^(<[^>]+>)") or "", P.x, mid, "head")
  TextR(Tx("KeysGroup"):match("(<[^>]+>)$") or "", P.x + P.width, mid, "head", 26)
  Zone(P.x, y, P.key_w, h, "group_key", -1)
  Zone(P.x + P.width - P.key_w, y, P.key_w, h, "group_key", 1)
  local n = math.max(1, #gl)
  local tw = (P.width - 2 * P.key_w - (n - 1) * P.tab_gap) / n
  local x = P.x + P.key_w
  for k, g in ipairs(gl) do
    Plate(L.PLATE, "off", x, y, tw, h)
    if k == S.group then Plate(L.ICON, "focus", x, y, tw, h) end
    Zone(x, y, tw, h, "group", k)
    local ty = S.kind == KIND_GAME and tonumber(g[4]) or 0
    local drawn = false
    if ty and ty >= 1 and ty <= 99 then
      local ih = h - 6
      local iw = math.min(tw - 4, ih * RETAIL.tabs.w / RETAIL.tabs.h)
      drawn = Quad(L.ICON, RETAIL.tabs.tex, string.format("icon_list_tab_series%02d%s", ty, k == S.group and "" or "_off"),
        x + (tw - iw) / 2, y + 3, iw, ih) ~= nil
    end
    if not drawn then
      TextC(Fit(tostring(g[1] or ""), tw - 8, 26), x + tw / 2, mid + 1, BLUE_STYLE, 26, 0.95)
    end
    x = x + tw + P.tab_gap
  end
end

-- the band of «Estadísticas del club» (its atlas: cap, stretched middle, cap)
local BAND_CAP = 40
local function Band(x, y, w, h)
  Quad(L.PLATE, ART, SPRITE .. "section_l", x, y, BAND_CAP, h)
  Quad(L.PLATE, ART, SPRITE .. "section_m", x + BAND_CAP, y, w - 2 * BAND_CAP, h)
  Quad(L.PLATE, ART, SPRITE .. "section_r", x + w - BAND_CAP, y, BAND_CAP, h)
end

local function DrawBand()
  local y = P.band_y
  Band(P.x, y, P.width, P.band_h)
  local g = Groups()[S.group]
  local kind = S.kind == KIND_NAME and Tx("TypeName") or Tx("TypeSeries")
  local have = Fill(Tx("Owned"), S.owned, S.total)
  TextR(have, P.x + P.width - 30, y + P.band_h / 2 + 1, "section", 26)
  local room = P.width - 90 - Units(have) * 26 * GLYPH
  Text(Fit(kind .. "  ›  " .. tostring(g and g[1] or ""), room, 26), P.x + 36, y + P.band_h / 2 + 1, "section")
end

local function DrawRow(r, k)
  local col, row = math.floor((k - 1) / P.rows), (k - 1) % P.rows
  local rx = P.x + 14 + col * (P.col_w + P.col_gap)
  local ry = P.top + row * (P.row_h + P.row_gap)
  local rw = P.col_w - 14
  Plate(L.PLATE, "off", rx, ry, rw, P.row_h)
  Zone(rx, ry, rw, P.row_h, "row", k)
  if k == S.sel then
    Plate(L.ICON, "focus", rx, ry, rw, P.row_h)
    Cursor(rx + 6, ry + P.row_h / 2, 38)
  end
  local cy = ry + P.row_h / 2
  local bx = rx + 16
  local K = RETAIL.check
  Quad(L.ICON, K.tex, K.box, bx, cy - P.box / 2, P.box, P.box)
  if r.owned then Quad(L.ICON, K.tex, K.mark, bx - 4, cy - P.mark / 2 - 4, P.mark, P.mark, 1) end
  local fx = bx + P.box + 12
  if r.base ~= 0 then Face(r.base, fx + P.face / 2, cy, P.face) end
  local nx = fx + P.face + 10
  Text(Fit(r.name ~= "" and r.name or "-", rx + rw - 40 - nx, 26), nx, cy + 1, "name", 0.95)
end

local function Draw()
  BeginFrame()
  if S.ready and S.ok then
    DrawTypes()
    DrawGroups()
    DrawBand()
    if #S.rows == 0 then
      Text(Tx("Empty"), P.x + 40, P.top + P.row_h / 2, "head")
    end
    for k, r in ipairs(S.rows) do DrawRow(r, k) end
    local keys = Tx("KeysPage")
    local left, right = keys:match("^(<[^>]+>)"), keys:match("(<[^>]+>)$")
    local line = (left or "") .. "  " .. Fill(Tx("Page"), S.page, S.pages) .. "  " .. (right or "")
    TextC(line, P.x + P.width / 2, P.page_y, "head", 26)
    -- the arrows at both ends of the counter (a button tag is about two glyphs wide)
    local half, key = Units(line) * 26 * GLYPH / 2, 2 * 26 * GLYPH + 8
    Zone(P.x + P.width / 2 - half - 4, P.page_y - 22, key, 44, "page", -1)
    Zone(P.x + P.width / 2 + half - key + 4, P.page_y - 22, key, 44, "page", 1)
    local r = S.rows[S.sel]
    if r ~= nil and not r.owned then
      local s = Tx("NotOwned")
      local w = Units(s) * 28 * GLYPH + 2 * BAND_CAP + 20
      Band(P.badge_x - w, P.badge_y, w, P.badge_h)
      TextC(s, P.badge_x - w / 2, P.badge_y + P.badge_h / 2 + 1, "section", 28)
    end
  elseif S.ready then
    Text(Tx("NoSave"), P.x + 40, P.top, "head")
  end
  EndFrame()
end

-- ---- keys --------------------------------------------------------------------------------------------------------------

local function Move(d)
  local n = #S.rows
  if n == 0 then return end
  local s = math.max(1, math.min(n, S.sel + d))
  if s == S.sel then return end
  S.sel = s
  Snd(SY_MOVE)
  S.dirty = true
  SetLine()
  PlateShow()
end

local function Page(d)
  if S.pages <= 1 then
    Snd(SY_ERROR)
    return
  end
  S.page = (S.page - 1 + d) % S.pages + 1
  Snd(SY_PAGE)
  LoadPage()
end

local function Group(d)
  local n = #Groups()
  if n <= 1 then
    Snd(SY_ERROR)
    return
  end
  S.group = (S.group - 1 + d) % n + 1
  S.page, S.sel = 1, 1
  Snd(SY_PAGE)
  LoadPage()
end

local function Kind(d)
  local n = S.data and #S.data.groups or 0
  if n <= 1 then return end
  S.kind = (S.kind - 1 + d) % n + 1
  S.group, S.page, S.sel = 1, 1, 1
  Snd(SY_PAGE)
  LoadPage()
end

-- left / right: the other column of the same row; past the first / last column the previous / next page, landing in
-- its last / first column on the same row (a shorter column: its last row)
local function Side(d)
  local n = #S.rows
  local col, row = math.floor((S.sel - 1) / P.rows), (S.sel - 1) % P.rows
  local c = col + d
  if n > 0 and c >= 0 and c < P.cols then
    local k = c * P.rows + row + 1
    if k > n and n > c * P.rows then k = n end
    if k <= n then
      S.sel = k
      Snd(SY_MOVE)
      S.dirty = true
      SetLine()
      PlateShow()
      return
    end
  end
  if S.pages <= 1 then
    Snd(SY_ERROR)
    return
  end
  S.sel = (d > 0 and 0 or P.cols - 1) * P.rows + row + 1
  Page(d)
end

local function Select(k)
  if k == S.sel or S.rows[k] == nil then return end
  Move(k - S.sel)
end

local function SetKind(k)
  if k ~= S.kind then Kind(k - S.kind) end
end

local function SetGroup(k)
  if k ~= S.group then Group(k - S.group) end
end

-- the zone under (x, y): the last declared wins
local function PointerAt(x, y)
  for i = #S.zones, 1, -1 do
    local z = S.zones[i]
    if x >= z[1] and x < z[3] and y >= z[2] and y < z[4] then return z end
  end
  return nil
end

-- the pointer, once per Step: a row is selected under it only on a frame the pointer moved (a redraw under a resting
-- pointer never re-selects); a left click picks the zone under it. Returns the row clicked, if any.
local Accept

local function PointerStep()
  local Q_ = S.ptr
  local x, y = M(POINTER.POS)
  if type(x) ~= "number" or type(y) ~= "number" then return nil end
  local moved = M(POINTER.MOVED) == true or (Q_.x ~= nil and (math.abs(x - Q_.x) > 1 or math.abs(y - Q_.y) > 1))
  Q_.x, Q_.y = x, y
  local down = In(POINTER.LEFT)
  local click = down and not Q_.down
  Q_.down = down
  if not moved and not click then return nil end
  local z = PointerAt(x, y)
  if z == nil then return nil end
  if z.kind == "row" then
    local was = S.sel
    Select(z.v)
    if click and was == z.v then Accept(true) end
    return nil
  elseif click then
    if z.kind == "type" then SetKind(z.v)
    elseif z.kind == "type_key" then Kind(z.v)
    elseif z.kind == "group" then SetGroup(z.v)
    elseif z.kind == "group_key" then Group(z.v)
    elseif z.kind == "page" then Page(z.v)
    end
  end
  return nil
end

-- ---- A: another mod's action on the selected player (BetterQoL.AlbumActions) --------------------------------------------

local function Offered(a)
  if type(a) ~= "table" or type(a.On) ~= "function" or type(a.Run) ~= "function" then return false end
  local ok, on = pcall(a.On)
  return ok and on == true
end

Accept = function(by_pointer)
  if S.task ~= nil then return end
  if not by_pointer and In(POINTER.LEFT) then return end      -- a mouse click: the pointer takes it
  local r = S.rows[S.sel]
  local acts = type(BetterQoL) == "table" and BetterQoL.AlbumActions or nil
  if r == nil or type(acts) ~= "table" then return end
  for _, a in ipairs(acts) do
    if Offered(a) then
      local row = { base = r.base, param = r.param, name = r.name, owned = r.owned, level = r.level }
      S.task = coroutine.create(function() return a.Run(row) end)
      Log("action", tostring(a.id), "param", r.param)
      return
    end
  end
end

local function TaskStep()
  if S.task == nil then return end
  local ok, changed = coroutine.resume(S.task)
  if not ok then Log("action error", tostring(changed)) end
  if ok and coroutine.status(S.task) ~= "dead" then return end
  S.task = nil
  S.ptr.down = true                -- a button still held from the windows is no click
  if ok and changed == true then
    Load()
    if S.ok then LoadPage() end
  end
end

local ACT = {
  accept = function() Accept(false) end,
  up = function() Move(-1) end, down = function() Move(1) end,
  left = function() Side(-1) end, right = function() Side(1) end,
  type_prev = function() Kind(-1) end, type_next = function() Kind(1) end,
  group_prev = function() Group(-1) end, group_next = function() Group(1) end,
  plate_prev = function() PlatePage(-1) end, plate_next = function() PlatePage(1) end,
}

-- ---- menu callbacks ----------------------------------------------------------------------------------------------------

function OnInit()
  S.ready, S.ok, S.frame, S.dirty, S.plate, S.line, S.task = false, false, 0, true, nil, nil, nil
  S.kind, S.group, S.page, S.sel, S.rows, S.zones = KIND_GAME, 1, 1, 1, {}, {}
  S.ptr = { down = true }          -- a button held from the Caseta's Accept is no click
  S.sent, S.used, S.shown, S.faces, S.opened, S.cap, S.texts = {}, {}, {}, {}, {}, {}, {}
  S.prio = {}
  Load()
end

function OnSetupLayer(a1, a2)
  if a1 == L_ANCHOR then
    -- the input anchor: nothing of it shows
    for _, node in ipairs(ANCHOR.TEXTS) do M(C.SET_TEXT, a1, node, "", a2) end
    M(C.ATTACH_TRACE, a1, a2, ANCHOR.CURSOR, false)
  elseif a1 == L_LINE then
    S.line = nil
    SetLine()
  else
    for _, layer in pairs(L) do
      if a1 == layer then
        -- a pool instance: hidden until the page draws it
        M(C.VISIBLE, a1, a2, false)
        local prefix = a1 .. ":" .. a2 .. ":"
        for k in pairs(S.sent) do
          if string.sub(k, 1, #prefix) == prefix then S.sent[k] = nil end
        end
        S.dirty = true
      end
    end
  end
end

function OnOpenLayer(a1, a2)
  if a1 == L_ANCHOR and a2 == 0 then
    M(C.CTRL, L_ANCHOR, true)
    M(C.LIST_NUM, L_ANCHOR, 1)
    M(C.FOCUS_SET, L_ANCHOR, 0)
    M(C.ATTACH_TRACE, L_ANCHOR, 0, ANCHOR.CURSOR, false)
    M(C.POS, L_ANCHOR, -4000, 4000, 0, 0)       -- off screen, still holding the focus
    for _, layer in pairs(L) do
      local n = M(C.LAYER_NUM, layer)
      S.cap[layer] = type(n) == "number" and n or 0
    end
    S.ready = true
    if S.ok then
      LoadPage()
      local r = S.rows[S.sel]
      if r ~= nil then PlateOpen(r) end
    end
    S.dirty = true
  end
end

function OnFunction(a1, a2)
  local act = FN[a2] or FN[a1]
  if act == nil or not S.ready or S.task ~= nil then return end
  ACT[act]()
  return 1
end

-- B / Esc / right click: the engine closes the page; the plate is asked to close (the opener waits for it)
function OnBack(a1)
  if PlateExists() then pcall(funcLuaCommand, C.CLOSE_MENU, PLATE.MENU) end
  Log("page closed")
end

function Step()
  S.frame = S.frame + 1
  if not S.ready then return end
  PlateStep()
  if S.task ~= nil then
    TaskStep()
    return
  end
  -- the wheel has no menu command of its own: read like the game's other mouse pages (docs/game/ui/mouse-support.md)
  if In(WHEEL_UP) then Move(-1) elseif In(WHEEL_DOWN) then Move(1) end
  PointerStep()
  -- drawn when something changed, and again while a texture or a miniface of the page is still loading
  if S.dirty then S.wait_until = S.frame + WAIT_FRAMES end
  if S.dirty or (S.waiting and S.frame < (S.wait_until or 0)) then
    S.dirty = false
    local ok, err = pcall(Draw)
    if not ok then Log("draw error", tostring(err)) end
  end
end
