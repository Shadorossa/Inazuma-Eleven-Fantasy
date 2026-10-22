-- util_club_stats_menu (plain Lua 5.2 source): Utilities' «Estadísticas del club» page (docs/game/ui/club-stats.md).
-- Declared in content\menus\club_stats.toml ([[screen]], served as common/script/lua/menu/util_club_stats_menu.lua.bin).
-- Opened from «Caseta del club» (play_guide_top_menu, assets\lua\play_guide_top_menu\150_club_stats.lua) the way that
-- menu opens its «Archivo de escenas»: the Caseta keeps its background, its header (title «Estadísticas del club»),
-- its button guide («Ordenar» on Select) and its return arrow; this page draws over them:
--   * the club totals (2 x 5 cells): matches, wins-draws-losses, win %, goals for / against, difference, clean
--     sheets, biggest win, best runs of wins and without a loss;
--   * «JUGADORES (N)» and the sort column, the column titles, one row per player who played at least one counted
--     match (any squad of the save or the bank): portrait, name, matches, goals, assists, MVP awards, win % in his
--     matches, signing day; 8 rows, a scroll bar;
--   * the content guide line (bottom left): since when the totals count.
-- Keys (cmd rows of the off-screen anchor row -> OnFunction / OnBack): up / down move (with repeat), L1 / R1 a page,
-- Select (Tab) the next sort column, B / Esc / right click close the page (the engine closes it); the wheel scrolls.
-- Numbers: Utilities' career store (scripts/career.lua: CMND_UTIL_CLUB_STATS / CMND_UTIL_CLUB_STATS_ROW), read once
-- when the page opens. No engine call at load time.
INCLUDE("LUA_PROG_BASE")
INCLUDE("LUA_PROG_COMMON")

local CMD = { CLUB = 1541729858 --[[CMND_UTIL_CLUB_STATS]], ROW = 188120611 --[[CMND_UTIL_CLUB_STATS_ROW]] }
local C = {
  LOG = 3661580131, TEXT_GET = 4074371074, LANG = 477234096, SND = 3073642526,
  LAYER_NUM = 1175615627, OPEN_LAYER = 629267548, VISIBLE = 711242136, POS = 1389957207, SCALE = 3778714801,
  SPRITE = 558735651, ALPHA = 4231609516, MESH_VISIBLE = 3405944500, NODE_VISIBLE = 2158717427,
  TEXT_VISIBLE = 2735666188, SET_TEXT = 1083631230, LOAD_TEX = 839427544, TEX_LOADING = 1506186496,
  FACE = 552280324, RESET_FACE = 4176779611, LOADING = 1277042906, CHECK_INPUT = 4265778440,
  TEXT_STYLE = 2333948100, CTRL = 3518307824, LIST_NUM = 3252599449, FOCUS_SET = 3466097042,
  ATTACH_TRACE = 1774843228,
}
local MENU_CTRL = 1332654303
local WHEEL_UP, WHEEL_DOWN = 1942756954 --[[CMD_EVT_WHEEL_UP]], 1623431741 --[[CMD_EVT_WHEEL_DOWN]]
-- the page's layers (content\menus\club_stats.toml)
local L = { BACK = 668243314, PLATE = 2002941968, ICON = 797867422, FACE = 1326329634, TEXT = 1905390466 }
local L_ANCHOR = 3455690937        -- save01_02_list_item: the input anchor (1 instance, off screen)
local L_LINE = 3078308064          -- mainmenu90_05_content_guide_line01
local LINE_TEXT = 378156699        -- _text_guide01
local ANCHOR = {
  TEXTS = { 931545948 --[[_text_list01_on]], 3705682548 --[[_text_list01_off]] },
  CURSOR = 3313461902,             -- the «cursor» locator
}
-- the anchor's functions (cmd rows: crc32 of the names)
local FN = { UP = 145437896, DOWN = 1457898622, PAGE_UP = 2769273999, PAGE_DOWN = 1415594500, SORT = 457090663 }
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
local SY_MOVE, SY_ERROR = 2500047763, 2086672038
local BOB, GLYPH = 30, 0.5
local STYLE = {
  section = "fs2_26_w_lc_2d2_001_nr", label = "fs_22_k_lc_2d0_001_nr_sclw", value = "fs_32_b_lc_2d0_001",
  name = "fs_28_b_lc_2d0_001", cell = "fs_28_b_lc_2d0_001",
  head = "fs2_26_w_lc_2d2_001_nr",   -- on the page's background: outlined white (column titles, the empty list)
}
-- the page (screen px at 1080p, y down): under the Caseta's header (0-145), above its content guide line (913) and
-- button guide (980)
local P = { x = 60, width = 1800, top = 168, cell_h = 92, cell_gap = 10, section_h = 40, columns_h = 32, row_h = 54,
  row_gap = 2, rows = 8, face = 48 }
-- the player table's columns: x of the column's centre (the name: its left edge)
local COL = { face = 140, name = 182, matches = 900, goals = 1040, assists = 1180, mvp = 1320, winpct = 1470, signed = 1660 }
local SORTS = { "goals", "matches", "assists", "mvp", "winpct", "signed" }
local SORT_TEXT = { goals = "SortGoals", matches = "SortMatches", assists = "SortAssists", mvp = "SortMvp",
  winpct = "SortWinPct", signed = "SortSigned" }
local ART, SPRITE = "#/menu/220_img/util_club_stats/util_club_stats.g4tx", "util_club_stats_"
local RETAIL = {
  list = { tex = "#/menu/51_save/save01/save01_02/save01_02.g4tx",
           off = "list_base_s01_off", on = "list_base_s01_on", focus = "list_base_s01_ol" },
  cursor = { tex = "#/menu/20_cmn/cmn05/cmn05_01/cmn05_01.g4tx", sprite = "cur01", w = 128, h = 152 },
}

-- state of this opening
local S = { ready = false, art_ok = false, frame = 0, ok = false, club = nil, rows = {}, sel = 1, top = 1, sort = 1,
  sent = {}, used = {}, shown = {}, texts = {}, loaded = {}, faces = {}, cap = {}, opened = {}, dirty = true }

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
  pcall(funcLuaCommand, C.LOG, "utilities club_stats " .. table.concat(p, " "))
end

-- a text of text/rows/club_stats.toml (id "Utilities.ClubStats.<name>"), in the game's language
local function Tx(name)
  local t = S.texts[name]
  if t == nil then
    local ok, s = pcall(funcLuaCommand, C.TEXT_GET, Crc("Utilities.ClubStats." .. name))
    t = (ok and type(s) == "string" and s ~= "") and s or name
    S.texts[name] = t
  end
  return t
end

local function Fill(s, v)
  return (tostring(s):gsub("{1}", function() return tostring(v) end))
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

-- a day yyyymmdd in the career page's date format (utilities.cs_date: {d} {m} {yy}); 0 / unknown = the «-» text
local function Day(d)
  d = tonumber(d) or 0
  if d <= 0 then return Tx("Unknown") end
  local fmt = S.texts["@date"]
  if fmt == nil then
    local ok, s = pcall(funcLuaCommand, C.TEXT_GET, Crc("utilities.cs_date"))
    fmt = (ok and type(s) == "string" and s:find("{d}", 1, true)) and s or "{d}/{m}/{yy}"
    S.texts["@date"] = fmt
  end
  local y, m, dd = math.floor(d / 10000), math.floor(d / 100) % 100, d % 100
  return (fmt:gsub("{d}", string.format("%02d", dd)):gsub("{m}", string.format("%02d", m))
    :gsub("{yy}", string.format("%02d", y % 100)))
end

local function Pct(w, m)
  if (m or 0) <= 0 then return "-" end
  return tostring(math.floor(w * 100 / m + 0.5)) .. "%"
end

-- ---- drawing pools -----------------------------------------------------------------------------------------------------

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

local function Quad(layer, tex, sprite, x, y, w, h, alpha)
  local i = Slot(layer)
  if i == nil then return nil end
  Show(layer, i)
  Set(layer, i, "sc", C.SCALE, layer, w / Q, h / Q, 1, i)
  Set(layer, i, "sp", C.SPRITE, layer, Crc(tex), Crc(sprite), QUAD, 0, i)
  Set(layer, i, "pos", C.POS, layer, x + w / 2, -(y + h / 2), 0, i)
  Set(layer, i, "a", C.ALPHA, layer, i, 0, alpha or 1)
  return i
end

local function Art(layer, name, x, y, w, h, alpha)
  return Quad(layer, ART, SPRITE .. name, x, y, w, h, alpha)
end

local function TexReady(tex)
  if S.loaded[tex] == nil then
    pcall(funcLuaMenuCommand, C.LOAD_TEX, tex)   -- CMND_LOAD_MENU_RES_TEXTURE is a menu command
    S.loaded[tex] = true
  end
  local ok, loading = pcall(funcLuaCommand, C.TEX_LOADING, Crc(tex))
  return ok and loading == false
end

local FALLBACK = { off = "row", on = "sel", focus = "focus" }
local function Plate(layer, look, x, y, w, h)
  local R = RETAIL.list
  if TexReady(R.tex) then return Quad(layer, R.tex, R[look], x, y, w, h, 1) end
  return Art(layer, FALLBACK[look], x, y, w, h, 1)
end

local function Cursor(x, y, h)
  local R = RETAIL.cursor
  local w = h * R.w / R.h
  local bob = math.floor(3 * math.sin(S.frame * 2 * math.pi / BOB) + 0.5)
  if TexReady(R.tex) then return Quad(L.ICON, R.tex, R.sprite, x - w + bob, y - h / 2, w, h, 1) end
  return Art(L.ICON, "cursor", x - w + bob, y - h / 2, w, h, 1)
end

-- a text: left edge x, vertical middle y, a style of STYLE, scale (1 = the style's own size)
local function Text(s, x, y, style, sc)
  if s == nil or s == "" then return nil end
  local i = Slot(L.TEXT)
  if i == nil then return nil end
  sc = sc or 1
  Show(L.TEXT, i)
  for _, m in ipairs(TXT.MESHES) do Set(L.TEXT, i, "m" .. m, C.MESH_VISIBLE, L.TEXT, m, false, i) end
  Set(L.TEXT, i, "st", C.TEXT_STYLE, L.TEXT, i, TXT.NODE, Crc(STYLE[style] or STYLE.cell))
  Set(L.TEXT, i, "txt", C.SET_TEXT, L.TEXT, TXT.NODE, s, i)
  Set(L.TEXT, i, "sc", C.SCALE, L.TEXT, sc, sc, 1, i)
  Set(L.TEXT, i, "pos", C.POS, L.TEXT, x - TXT.BOX_LEFT * sc, -y - TXT.BOX_MID_Y * sc, 0, i)
  return i
end

local function Units(s)
  local u = 0
  for ch in tostring(s or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do u = u + ((ch:byte(1) or 0) >= 0xE3 and 2 or 1) end
  return u
end

-- a text centred on cx (its width estimated from the glyph size `px` of the style at scale 1)
local function TextC(s, cx, y, style, px, sc)
  sc = sc or 1
  local w = Units(s) * px * sc * GLYPH
  return Text(s, cx - w / 2, y, style, sc)
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

-- the retail list character card, portrait only, centred at (cx, cy), `size` px; key = chara_base
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
  M(C.MESH_VISIBLE, L.FACE, CARD.MESH, M(C.LOADING, L.FACE, i) ~= true, i)
end

local function BeginFrame() S.used = {} end

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

-- ---- data --------------------------------------------------------------------------------------------------------------

local function SortRows()
  local key = SORTS[S.sort]
  local function value(r)
    if key == "winpct" then return r.matches > 0 and r.wins / r.matches or -1 end
    return r[key] or 0
  end
  table.sort(S.rows, function(a, b)
    local va, vb = value(a), value(b)
    if va ~= vb then return va > vb end
    if a.goals ~= b.goals then return a.goals > b.goals end
    if a.matches ~= b.matches then return a.matches > b.matches end
    return a.name < b.name
  end)
end

local function Load()
  S.rows, S.club = {}, nil
  local okl, lang = pcall(funcLuaCommand, C.LANG)
  local r = table.pack(pcall(funcLuaCommand, CMD.CLUB, okl and lang or 1))
  S.ok = r[1] == true and r[2] == true
  if not S.ok then
    Log("no numbers for this save", tostring(r[2]))
    return
  end
  local v = {}
  for i = 3, r.n do v[#v + 1] = tonumber(r[i]) or 0 end
  S.club = { players = v[1], since = v[2], matches = v[3], wins = v[4], draws = v[5], losses = v[6], gf = v[7],
    ga = v[8], clean = v[9], best_for = v[10], best_against = v[11], best_day = v[12], win_run = v[13],
    unbeaten_run = v[14], store_since = v[15], today = v[16] }
  for i = 1, S.club.players do
    local ok, base, name, m, w, d, l, g, a, mvp, signed = pcall(funcLuaCommand, CMD.ROW, i)
    if not ok or base == "" or base == nil then break end
    S.rows[#S.rows + 1] = { base = tonumber(base) or 0, name = tostring(name or ""), matches = tonumber(m) or 0,
      wins = tonumber(w) or 0, draws = tonumber(d) or 0, losses = tonumber(l) or 0, goals = tonumber(g) or 0,
      assists = tonumber(a) or 0, mvp = tonumber(mvp) or 0, signed = tonumber(signed) or 0 }
  end
  SortRows()
  Log("page opened:", #S.rows, "player(s),", S.club.matches, "club match(es) since", S.club.since)
end

-- the content guide line: since when the totals count
local function SinceLine()
  local c = S.club
  if not S.ok or c == nil then return Tx("NoSave") end
  if c.matches <= 0 then return Tx("ClubNone") end
  if c.since > 0 then return Fill(Tx("ClubSince"), Day(c.since)) end
  return Tx("ClubTotals")
end

-- ---- drawing -----------------------------------------------------------------------------------------------------------

local function DrawTotals(x, y, w)
  local c = S.club
  local cells = {
    { "Matches", tostring(c.matches) },
    { "Record", string.format("%d-%d-%d", c.wins, c.draws, c.losses) },
    { "WinPct", Pct(c.wins, c.matches) },
    { "GoalsFor", tostring(c.gf) },
    { "GoalsAgainst", tostring(c.ga) },
    { "GoalDiff", (c.gf - c.ga > 0 and "+" or "") .. tostring(c.gf - c.ga) },
    { "CleanSheets", tostring(c.clean) },
    { "BestWin", c.best_day > 0 and string.format("%d-%d", c.best_for, c.best_against) or "-" },
    { "WinRun", tostring(c.win_run) },
    { "UnbeatenRun", tostring(c.unbeaten_run) },
  }
  local per_row = 5
  local cw = math.floor((w - (per_row - 1) * P.cell_gap) / per_row)
  for i, cell in ipairs(cells) do
    local col, row = (i - 1) % per_row, math.floor((i - 1) / per_row)
    local cx, cy = x + col * (cw + P.cell_gap), y + row * (P.cell_h + P.cell_gap)
    Plate(L.PLATE, "off", cx, cy, cw, P.cell_h)
    TextC(Fit(Tx(cell[1]), cw - 40, 22), cx + cw / 2, cy + 25, "label", 22)
    TextC(cell[2], cx + cw / 2, cy + 60, "value", 32, 1.15)
  end
  return y + 2 * P.cell_h + P.cell_gap
end

local function DrawRow(r, y, on)
  local px, pw = P.x + 20, P.width - 70
  Plate(L.PLATE, "off", px, y, pw, P.row_h)
  if on then
    Plate(L.ICON, "focus", px, y, pw, P.row_h)
    Cursor(px + 8, y + P.row_h / 2, 40)
  end
  local mid = y + P.row_h / 2
  if r.base ~= 0 then Face(r.base, COL.face, mid, P.face) end
  Text(Fit(r.name ~= "" and r.name or "-", COL.matches - COL.name - 90, 28), COL.name, mid, "name")
  TextC(tostring(r.matches), COL.matches, mid, "cell", 28)
  TextC(tostring(r.goals), COL.goals, mid, "cell", 28)
  TextC(tostring(r.assists), COL.assists, mid, "cell", 28)
  TextC(tostring(r.mvp), COL.mvp, mid, "cell", 28)
  TextC(Pct(r.wins, r.matches), COL.winpct, mid, "cell", 28)
  TextC(Day(r.signed), COL.signed, mid, "cell", 28)
end

local function DrawScrollbar(x, y0, y1)
  local n, view = #S.rows, P.rows
  if n <= view then return end
  Art(L.PLATE, "sbar", x, y0, 8, y1 - y0, 1)
  local h = y1 - y0
  local th = math.max(40, math.floor(h * view / n))
  local ty = y0 + math.floor((h - th) * (S.top - 1) / (n - view) + 0.5)
  Art(L.ICON, "sthumb", x, ty, 8, th, 1)
end

local function Draw()
  BeginFrame()
  if S.ready and S.art_ok and S.ok and S.club ~= nil then
    local x, w = P.x, P.width
    local y = DrawTotals(x, P.top, w) + 18
    -- the player list's band: how many, the sort column
    Art(L.PLATE, "section", x, y, w, P.section_h, 1)
    Text(Fill(Tx("Players"), #S.rows), x + 80, y + P.section_h / 2 + 1, "section")
    local sort = Fill(Tx("SortBy"), Tx(SORT_TEXT[SORTS[S.sort]]))
    Text(sort, x + w - 40 - Units(sort) * 26 * GLYPH - 20, y + P.section_h / 2 + 1, "section")
    y = y + P.section_h + 4
    -- column titles
    local cy = y + P.columns_h / 2
    local hs = 0.85
    Text(Tx("ColName"), COL.name, cy, "head", hs)
    TextC(Tx("ColMatches"), COL.matches, cy, "head", 26, hs)
    TextC(Tx("ColGoals"), COL.goals, cy, "head", 26, hs)
    TextC(Tx("ColAssists"), COL.assists, cy, "head", 26, hs)
    TextC(Tx("ColMvp"), COL.mvp, cy, "head", 26, hs)
    TextC(Tx("ColWinPct"), COL.winpct, cy, "head", 26, hs)
    TextC(Tx("ColSigned"), COL.signed, cy, "head", 26, hs)
    y = y + P.columns_h + 2
    local y0 = y
    if #S.rows == 0 then
      Text(Tx("NoPlayers"), COL.name, y + P.row_h / 2, "head")
    end
    for k = 0, P.rows - 1 do
      local r = S.rows[S.top + k]
      if r == nil then break end
      DrawRow(r, y, S.top + k == S.sel)
      y = y + P.row_h + P.row_gap
    end
    DrawScrollbar(x + w - 34, y0, y0 + P.rows * (P.row_h + P.row_gap) - P.row_gap)
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
  if S.sel < S.top then S.top = S.sel end
  if S.sel >= S.top + P.rows then S.top = S.sel - P.rows + 1 end
  Snd(SY_MOVE)
  S.dirty = true
end

local function NextSort()
  if #S.rows == 0 then
    Snd(SY_ERROR)
    return
  end
  S.sort = S.sort % #SORTS + 1
  SortRows()
  S.sel, S.top = 1, 1
  Snd(SY_MOVE)
  S.dirty = true
end

-- ---- menu callbacks ----------------------------------------------------------------------------------------------------

function OnInit()
  S.ready, S.art_ok, S.frame, S.sel, S.top, S.sort, S.dirty = false, false, 0, 1, 1, 1, true
  S.sent, S.used, S.shown, S.faces, S.opened, S.cap, S.texts = {}, {}, {}, {}, {}, {}, {}
  Load()
end

function OnSetupLayer(a1, a2)
  if a1 == L_ANCHOR then
    -- the input anchor: nothing of it shows
    for _, node in ipairs(ANCHOR.TEXTS) do M(C.SET_TEXT, a1, node, "", a2) end
    M(C.ATTACH_TRACE, a1, a2, ANCHOR.CURSOR, false)
  elseif a1 == L_LINE then
    M(C.SET_TEXT, a1, LINE_TEXT, SinceLine())
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
    S.dirty = true
  end
end

function OnFunction(a1, a2)
  local id = a2
  if id ~= FN.UP and id ~= FN.DOWN and id ~= FN.PAGE_UP and id ~= FN.PAGE_DOWN and id ~= FN.SORT then id = a1 end
  if id == FN.UP then Move(-1)
  elseif id == FN.DOWN then Move(1)
  elseif id == FN.PAGE_UP then Move(-P.rows)
  elseif id == FN.PAGE_DOWN then Move(P.rows)
  elseif id == FN.SORT then NextSort()
  else return end
  return 1
end

-- B / Esc / right click: the engine closes the page; the Caseta's opener puts its list back
function OnBack(a1)
  Log("page closed")
end

function Step()
  S.frame = S.frame + 1
  if not S.ready then return end
  if not S.art_ok and TexReady(ART) then
    S.art_ok = true
    S.sent = {}
    S.dirty = true
  end
  -- the wheel has no menu command of its own: read like the game's other mouse pages (docs/game/ui/mouse-support.md)
  if In(WHEEL_UP) then Move(-1) elseif In(WHEEL_DOWN) then Move(1) end
  -- the cursor bobs: one draw a frame while it shows (only what changed is sent)
  if S.dirty or #S.rows > 0 then
    S.dirty = false
    local ok, err = pcall(Draw)
    if not ok then Log("draw error", tostring(err)) end
  end
end
