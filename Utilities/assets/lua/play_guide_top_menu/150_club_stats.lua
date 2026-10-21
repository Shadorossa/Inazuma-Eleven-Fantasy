-- Utilities › «Estadísticas del club» (docs/game/ui/club-stats.md): the panel the row of «Caseta del club»
-- (play_guide_top_menu; graft util_club_stats_row) opens over the menu. Top: the club totals (matches, wins / draws /
-- losses, win %, goals for / against, goal difference, clean sheets, biggest win, longest runs). Below: one row per
-- player of the club with a career record (portrait, name, matches, goals, assists, man of the match awards, win % in
-- his matches, signing day), sorted by goals; LEFT / RIGHT (or A) change the sort, UP / DOWN / L1 / R1 / the wheel
-- scroll, B / right click close. The numbers are Utilities' career store (scripts/career.lua, CMND_UTIL_CLUB_STATS /
-- CMND_UTIL_CLUB_STATS_ROW). Drawn on the layers util_cst_* (content/menus/club_stats.toml) with the friends panel's
-- atlas and the game's own list plates and cursor, like the friends panel. Engine calls only from the menu callbacks.
Utilities = type(Utilities) == "table" and Utilities or {}

if UTIL_CST == nil then
  UTIL_CST = {
    CMD = { CLUB = 1541729858 --[[CMND_UTIL_CLUB_STATS]], ROW = 188120611 --[[CMND_UTIL_CLUB_STATS_ROW]] },
    C = {
      LOG = 3661580131, TEXT_GET = 4074371074, LANG = 477234096, SND = 3073642526,
      LAYER_NUM = 1175615627, OPEN_LAYER = 629267548, VISIBLE = 711242136, POS = 1389957207, SCALE = 3778714801,
      SPRITE = 558735651, ALPHA = 4231609516, MESH_VISIBLE = 3405944500, NODE_VISIBLE = 2158717427,
      TEXT_VISIBLE = 2735666188, SET_TEXT = 1083631230, LOAD_TEX = 839427544, TEX_LOADING = 1506186496,
      FACE = 552280324, RESET_FACE = 4176779611, LOADING = 1277042906, CHECK_INPUT = 4265778440,
      TEXT_STYLE = 2333948100, MENU_INPUT = 1558704558 --[[CMND_SET_INPUT_ENABLE_MENU_OBJECT]],
      CTRL_FOCUS = 3518307824,
    },
    MENU = 1281873114,                    -- play_guide_top_menu
    LIST = 530619243,                     -- mainmenu90_12_list_item_small
    HEADER_TYPE = 14, HEADER_ICON = 3275740866 --[[mode_base05]], HEADER_TITLE = 882201751,
    L = { BACK = 668243314, PLATE = 2002941968, ICON = 797867422, FACE = 1326329634, TEXT = 1905390466 },
    QUAD = 1909474081,                    -- icon_new01: the cmn01_10 quad's sprite slot
    Q = 36,                               -- the cmn01_10 quad side
    TXT = { NODE = 378327766 --[[_text_cmd_back01]], MESHES = {298211823, 2853207670}, BOX_LEFT = -384, BOX_MID_Y = 144 },
    CARD = {
      MESH = 2828003679 --[[_icon_chr_dmy_l01]], TEX = 21929195 --[[icon_chr_dmy_l01]], NAME = 170976702 --[[_text_chr01]],
      RH = 156, OX = 59, OY = 11,
      HIDE = {"_icon_chr_base_l01", "_icon_chr_gradation_l01", "_seasonal_frame_l01", "_avatar_frame_l01",
        "_icon_chr_focus_l01", "_icon_chr_position_dmy_l01", "_icon_base_l01", "_icon_chr_type_dmy_l01", "_icon_lock01",
        "_icon_captain01", "_icon_ai_role_dmy01", "_gtxt_lv_l01", "_icon_card01", "_icon_chr_def01_l",
        "_icon_chr_grayout01", "_basara_avatar_l01", "_num_chr_dmy_l01", "_num_chr_dmy_l02", "_gauge_exp_base_l01",
        "_gauge_exp_l01", "_icon_synergy_l01", "_icon_synergy_l02", "_leader_base01", "_gtxt_leader01"},
      HIDE_NODES = {"_pos_base02", "_pos_leader01", "_pos_ai_role01", "_num_chr_l01", "_num_chr_l02", "_pos_gauge_exp_l01"},
    },
    CTRLS = {1332654303 --[[MENU_CTRL]], 2748927068 --[[MENU_CTRL_WITH_ANALOG_MOVE_FOCUS]]},
    KEYS = {up = 1197218715, down = 3259546669, left = 2765147006, right = 2075023265, enter = 1981080283,
            back = 3011112225, l1 = 3966226594, r1 = 942075773, rclick = 3473063670, wup = 1942756954,
            wdown = 1623431741},
    SY_OK = 3848881948, SY_MOVE = 2500047763, SY_ERROR = 2086672038,
    REPEAT_FIRST = 18, REPEAT_EVERY = 5, BOB = 30, GLYPH = 0.5,
    STYLE = {
      title = "fs2_36_w_lc_2d2_001", section = "fs2_26_w_lc_2d2_001_nr", label = "fs_22_k_lc_2d0_001_nr_sclw",
      value = "fs_32_b_lc_2d0_001", name = "fs_28_b_lc_2d0_001", cell = "fs_28_b_lc_2d0_001",
      small = "fs_26_k_lc_2d0_001", guide = "fs_guide01",
    },
    -- the panel (screen px at 1080p, y down): a light sheet over the list, the totals, the player table
    P = { x = 60, width = 1800, top = 108, bottom = 996, head_h = 60, cell_h = 96, cell_gap = 10, section_h = 40,
          columns_h = 34, row_h = 60, rows = 7, foot_h = 52, face = 52 },
    -- the player table's columns: x of the column's centre (the name: its left edge)
    COL = { face = 150, name = 196, matches = 930, goals = 1060, assists = 1190, mvp = 1320, winpct = 1460, signed = 1640 },
    SORTS = { "goals", "matches", "assists", "mvp", "winpct", "signed" },
    SORT_TEXT = { goals = "SortGoals", matches = "SortMatches", assists = "SortAssists", mvp = "SortMvp",
                  winpct = "SortWinPct", signed = "SortSigned" },
    art = "#/menu/220_img/util_friends/util_friends.g4tx", SPRITE = "util_friends_",
    RETAIL = {
      list = { tex = "#/menu/51_save/save01/save01_02/save01_02.g4tx",
               off = "list_base_s01_off", on = "list_base_s01_on", focus = "list_base_s01_ol" },
      cursor = { tex = "#/menu/20_cmn/cmn05/cmn05_01/cmn05_01.g4tx", sprite = "cur01", w = 128, h = 152 },
    },
    open = false, here = false, art_ok = false, frame = 0,
    ok = false, club = nil, rows = {}, sel = 1, top = 1, sort = 1,
    held = {}, sent = {}, used = {}, shown = {}, crcs = {}, texts = {}, loaded = {}, faces = {}, cap = {}, opened = {},
  }
end

local CS = UTIL_CST

local function Log(...)
  local p = {}
  for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end
  pcall(funcLuaCommand, CS.C.LOG, "utilities club_stats " .. table.concat(p, " "))
end

local function Crc(s)
  local c = CS.crcs[s]
  if c == nil and type(CRC32) == "function" then
    c = CRC32(s)
    CS.crcs[s] = c
  end
  return c or 0
end

-- a text of text/rows/club_stats.toml (id "Utilities.ClubStats.<name>"), in the game's language
local function Tx(name)
  local t = CS.texts[name]
  if t == nil then
    local ok, s = pcall(funcLuaCommand, CS.C.TEXT_GET, Crc("Utilities.ClubStats." .. name))
    t = (ok and type(s) == "string" and s ~= "") and s or name
    CS.texts[name] = t
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

-- a day yyyymmdd in the career page's date format (utilities.cs_date: {d} {m} {yy}); 0 / unknown = the «-» text
local function Day(d)
  d = tonumber(d) or 0
  if d <= 0 then return Tx("Unknown") end
  local fmt = CS.texts["@date"]
  if fmt == nil then
    local ok, s = pcall(funcLuaCommand, CS.C.TEXT_GET, Crc("utilities.cs_date"))
    fmt = (ok and type(s) == "string" and s:find("{d}", 1, true)) and s or "{d}/{m}/{yy}"
    CS.texts["@date"] = fmt
  end
  local y, m, dd = math.floor(d / 10000), math.floor(d / 100) % 100, d % 100
  return (fmt:gsub("{d}", string.format("%02d", dd)):gsub("{m}", string.format("%02d", m))
    :gsub("{yy}", string.format("%02d", y % 100)))
end

local function Pct(w, m)
  if (m or 0) <= 0 then return "-" end
  return tostring(math.floor(w * 100 / m + 0.5)) .. "%"
end

-- ------------------------------------------------------------------------------------------------ drawing pools

local function Set(layer, idx, prop, cmd, ...)
  local k = layer .. ":" .. idx .. ":" .. prop
  local a = table.pack(...)
  local sig = {}
  for i = 1, a.n do sig[#sig + 1] = tostring(a[i]) end
  sig = table.concat(sig, ",")
  if CS.sent[k] == sig then return end
  CS.sent[k] = sig
  M(cmd, ...)
end

local function Slot(layer)
  local n = CS.used[layer] or 0
  if n >= (CS.cap[layer] or 0) then return nil end
  CS.used[layer] = n + 1
  if not CS.opened[layer .. ":" .. n] then
    M(CS.C.OPEN_LAYER, layer, n)
    CS.opened[layer .. ":" .. n] = true
  end
  return n
end

local function Show(layer, i)
  Set(layer, i, "vis", CS.C.VISIBLE, layer, i, true)
  CS.shown[layer .. ":" .. i] = true
end

local function Quad(layer, tex, sprite, x, y, w, h, alpha)
  local i = Slot(layer)
  if i == nil then return nil end
  Show(layer, i)
  Set(layer, i, "sc", CS.C.SCALE, layer, w / CS.Q, h / CS.Q, 1, i)
  Set(layer, i, "sp", CS.C.SPRITE, layer, Crc(tex), Crc(sprite), CS.QUAD, 0, i)
  Set(layer, i, "pos", CS.C.POS, layer, x + w / 2, -(y + h / 2), 0, i)
  Set(layer, i, "a", CS.C.ALPHA, layer, i, 0, alpha or 1)
  return i
end

local function Art(layer, name, x, y, w, h, alpha)
  return Quad(layer, CS.art, CS.SPRITE .. name, x, y, w, h, alpha)
end

local function TexReady(tex, wait)
  local st = CS.loaded[tex]
  if st == nil then
    pcall(funcLuaCommand, CS.C.LOAD_TEX, tex)
    st = {ok = 0}
    CS.loaded[tex] = st
  end
  local ok, loading = pcall(funcLuaCommand, CS.C.TEX_LOADING, Crc(tex))
  if ok and loading == false then st.ok = st.ok + 1 else st.ok = 0 end
  return st.ok >= (wait or 1)
end

local FALLBACK = { off = "row", on = "sel", focus = "focus" }
local function Plate(layer, look, x, y, w, h)
  local R = CS.RETAIL.list
  if TexReady(R.tex, 1) then return Quad(layer, R.tex, R[look], x, y, w, h, 1) end
  return Art(layer, FALLBACK[look], x, y, w, h, 1)
end

local function Cursor(x, y, h)
  local R = CS.RETAIL.cursor
  local w = h * R.w / R.h
  local bob = math.floor(3 * math.sin(CS.frame * 2 * math.pi / CS.BOB) + 0.5)
  if TexReady(R.tex, 1) then return Quad(CS.L.ICON, R.tex, R.sprite, x - w + bob, y - h / 2, w, h, 1) end
  return Art(CS.L.ICON, "cursor", x - w + bob, y - h / 2, w, h, 1)
end

-- a text: left edge x, vertical middle y, a style of CS.STYLE, scale (1 = the style's own size)
local function Text(s, x, y, style, sc)
  if s == nil or s == "" then return nil end
  local L, T = CS.L.TEXT, CS.TXT
  local i = Slot(L)
  if i == nil then return nil end
  sc = sc or 1
  Show(L, i)
  for _, m in ipairs(T.MESHES) do Set(L, i, "m" .. m, CS.C.MESH_VISIBLE, L, m, false, i) end
  Set(L, i, "st", CS.C.TEXT_STYLE, L, i, T.NODE, Crc(CS.STYLE[style] or CS.STYLE.cell))
  Set(L, i, "txt", CS.C.SET_TEXT, L, T.NODE, s, i)
  Set(L, i, "sc", CS.C.SCALE, L, sc, sc, 1, i)
  Set(L, i, "pos", CS.C.POS, L, x - T.BOX_LEFT * sc, -y - T.BOX_MID_Y * sc, 0, i)
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
  local w = Units(s) * px * sc * CS.GLYPH
  return Text(s, cx - w / 2, y, style, sc)
end

local function Fit(s, px, size)
  s = tostring(s or "")
  local units = math.floor(px / (size * CS.GLYPH))
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
  local L, K = CS.L.FACE, CS.CARD
  local i = Slot(L)
  if i == nil then return end
  local s = size / K.RH
  Show(L, i)
  Set(L, i, "sc", CS.C.SCALE, L, s, s, 1, i)
  Set(L, i, "pos", CS.C.POS, L, cx - K.OX * s, -cy - K.OY * s, 0, i)
  if CS.faces[i] ~= key then
    for _, m in ipairs(K.HIDE) do M(CS.C.MESH_VISIBLE, L, Crc(m), false, i) end
    for _, m in ipairs(K.HIDE_NODES) do M(CS.C.NODE_VISIBLE, L, Crc(m), false, i) end
    M(CS.C.TEXT_VISIBLE, L, K.NAME, false, i)
    M(CS.C.RESET_FACE, L, i, K.TEX)
    Opt(SetDisableForceCharaInvalidUseTarget)
    M(CS.C.FACE, L, i, false, K.MESH, K.TEX, 0, 0, key, 0, false, true)
    Opt(SetEnableForceCharaInvalidUseTarget)
    CS.faces[i] = key
  end
  M(CS.C.MESH_VISIBLE, L, K.MESH, M(CS.C.LOADING, L, i) ~= true, i)
end

local function BeginFrame() CS.used = {} end

local function EndFrame()
  for k in pairs(CS.shown) do
    local layer, i = k:match("^(%d+):(%d+)$")
    layer, i = tonumber(layer), tonumber(i)
    if layer and i and i >= (CS.used[layer] or 0) then
      Set(layer, i, "vis", CS.C.VISIBLE, layer, i, false)
      CS.shown[k] = nil
      if layer == CS.L.FACE then CS.faces[i] = nil end
    end
  end
end

local function HideAll()
  for _, L in pairs(CS.L) do
    for i = 0, (CS.cap[L] or 0) - 1 do
      M(CS.C.VISIBLE, L, i, false)
      CS.sent[L .. ":" .. i .. ":vis"] = nil
    end
  end
  CS.shown = {}
end

-- ------------------------------------------------------------------------------------------------ input

local function In(input)
  for _, c in ipairs(CS.CTRLS) do
    local ok, r = pcall(funcLuaCommand, CS.C.CHECK_INPUT, c, input)
    if ok and r == true then return true end
  end
  return false
end

local function KeysReset()
  for name, input in pairs(CS.KEYS) do CS.held[name] = In(input) and 1000 or 0 end
end

local function Pressed(name, repeats)
  local now = In(CS.KEYS[name])
  local h = CS.held[name] or 0
  if not now then
    CS.held[name] = 0
    return false
  end
  CS.held[name] = h + 1
  if h == 0 then return true end
  return repeats and h >= CS.REPEAT_FIRST and (h - CS.REPEAT_FIRST) % CS.REPEAT_EVERY == 0
end

local function Snd(s) pcall(funcLuaCommand, CS.C.SND, s) end

-- ------------------------------------------------------------------------------------------------ data

local function SortRows()
  local key = CS.SORTS[CS.sort]
  local function value(r)
    if key == "winpct" then
      return r.matches > 0 and r.wins / r.matches or -1
    end
    return r[key] or 0
  end
  table.sort(CS.rows, function(a, b)
    local va, vb = value(a), value(b)
    if va ~= vb then return va > vb end
    if a.goals ~= b.goals then return a.goals > b.goals end
    if a.matches ~= b.matches then return a.matches > b.matches end
    return a.name < b.name
  end)
end

local function Load()
  CS.rows, CS.club = {}, nil
  local okl, lang = pcall(funcLuaCommand, CS.C.LANG)
  local r = table.pack(pcall(funcLuaCommand, CS.CMD.CLUB, okl and lang or 1))
  CS.ok = r[1] == true and r[2] == true
  if not CS.ok then
    Log("no numbers for this save", tostring(r[2]))
    return
  end
  local v = {}
  for i = 3, r.n do v[#v + 1] = tonumber(r[i]) or 0 end
  CS.club = { players = v[1], since = v[2], matches = v[3], wins = v[4], draws = v[5], losses = v[6], gf = v[7],
    ga = v[8], clean = v[9], best_for = v[10], best_against = v[11], best_day = v[12], win_run = v[13],
    unbeaten_run = v[14], store_since = v[15], today = v[16] }
  for i = 1, CS.club.players do
    local ok, base, name, m, w, d, l, g, a, mvp, signed = pcall(funcLuaCommand, CS.CMD.ROW, i)
    if not ok or base == "" or base == nil then break end
    CS.rows[#CS.rows + 1] = { base = tonumber(base) or 0, name = tostring(name or ""), matches = tonumber(m) or 0,
      wins = tonumber(w) or 0, draws = tonumber(d) or 0, losses = tonumber(l) or 0, goals = tonumber(g) or 0,
      assists = tonumber(a) or 0, mvp = tonumber(mvp) or 0, signed = tonumber(signed) or 0 }
  end
  SortRows()
  Log("opened:", #CS.rows, "player(s),", CS.club.matches, "club match(es) since", CS.club.since)
end

-- ------------------------------------------------------------------------------------------------ drawing

local function DrawTotals(x, y, w)
  local c = CS.club
  local P = CS.P
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
    Plate(CS.L.PLATE, "off", cx, cy, cw, P.cell_h)
    TextC(Fit(Tx(cell[1]), cw - 40, 22), cx + cw / 2, cy + 26, "label", 22)
    TextC(cell[2], cx + cw / 2, cy + 62, "value", 32, 1.15)
  end
  return y + 2 * P.cell_h + P.cell_gap
end

local function DrawRow(r, y, on)
  local P, C = CS.P, CS.COL
  local px, pw = CS.P.x + 40, CS.P.width - 100
  Plate(CS.L.PLATE, "off", px, y - 3, pw, P.row_h + 6)
  if on then
    Plate(CS.L.ICON, "focus", px, y - 3, pw, P.row_h + 6)
    Cursor(px + 8, y + P.row_h / 2, 40)
  end
  local mid = y + P.row_h / 2
  if r.base ~= 0 then Face(r.base, C.face, mid, P.face) end
  Text(Fit(r.name ~= "" and r.name or "-", C.matches - C.name - 90, 28), C.name, mid, "name")
  TextC(tostring(r.matches), C.matches, mid, "cell", 28)
  TextC(tostring(r.goals), C.goals, mid, "cell", 28)
  TextC(tostring(r.assists), C.assists, mid, "cell", 28)
  TextC(tostring(r.mvp), C.mvp, mid, "cell", 28)
  TextC(Pct(r.wins, r.matches), C.winpct, mid, "cell", 28)
  TextC(Day(r.signed), C.signed, mid, "cell", 28)
end

local function DrawScrollbar(x, y0, y1)
  local n, view = #CS.rows, CS.P.rows
  if n <= view then return end
  Art(CS.L.PLATE, "sbar", x, y0, 8, y1 - y0, 1)
  local h = y1 - y0
  local th = math.max(40, math.floor(h * view / n))
  local ty = y0 + math.floor((h - th) * (CS.top - 1) / (n - view) + 0.5)
  Art(CS.L.ICON, "sthumb", x, ty, 8, th, 1)
end

local function Draw()
  BeginFrame()
  if CS.open and CS.art_ok then
    local P, C = CS.P, CS.COL
    local x, w = P.x, P.width
    Art(CS.L.BACK, "panel", x, P.top, w, P.bottom - P.top, 1)
    Art(CS.L.BACK, "edge", x, P.top, 8, P.bottom - P.top, 1)
    -- title band: since when the club totals count
    Art(CS.L.PLATE, "head", x, P.top, w, P.head_h, 1)
    local c = CS.club
    local band
    if not CS.ok or c == nil then
      band = Tx("NoSave")
    elseif c.since > 0 then
      band = Fill(Tx("ClubSince"), Day(c.since))
    else
      band = Tx("ClubNone")
    end
    Text(band, x + 32, P.top + P.head_h / 2 - 2, "title")
    if CS.ok and c ~= nil then
      local y = DrawTotals(x + 40, P.top + P.head_h + 14, w - 80) + 16
      -- the player list's band: how many, the sort
      Art(CS.L.PLATE, "section", x + 30, y, w - 60, P.section_h, 1)
      Text(Fill(Tx("Players"), #CS.rows), x + 90, y + P.section_h / 2 + 1, "section")
      local sort = Fill(Tx("SortBy"), Tx(CS.SORT_TEXT[CS.SORTS[CS.sort]]))
      Text(sort, x + w - 60 - Units(sort) * 26 * CS.GLYPH - 20, y + P.section_h / 2 + 1, "section")
      y = y + P.section_h + 6
      -- column titles
      local cy = y + P.columns_h / 2
      Text(Tx("ColName"), C.name, cy, "label")
      TextC(Tx("ColMatches"), C.matches, cy, "label", 22)
      TextC(Tx("ColGoals"), C.goals, cy, "label", 22)
      TextC(Tx("ColAssists"), C.assists, cy, "label", 22)
      TextC(Tx("ColMvp"), C.mvp, cy, "label", 22)
      TextC(Tx("ColWinPct"), C.winpct, cy, "label", 22)
      TextC(Tx("ColSigned"), C.signed, cy, "label", 22)
      y = y + P.columns_h + 4
      local y0 = y
      if #CS.rows == 0 then
        Text(Tx("NoPlayers"), C.name, y + P.row_h / 2, "small")
      end
      for k = 0, P.rows - 1 do
        local i = CS.top + k
        local r = CS.rows[i]
        if r == nil then break end
        DrawRow(r, y, i == CS.sel)
        y = y + P.row_h + 2
      end
      DrawScrollbar(x + w - 44, y0, y0 + P.rows * (P.row_h + 2))
    end
    -- the button guide band
    Art(CS.L.PLATE, "foot", x, P.bottom - P.foot_h, w, P.foot_h, 1)
    Text(Tx("Keys"), x + 110, P.bottom - P.foot_h / 2 + 2, "guide")
  end
  EndFrame()
end

-- ------------------------------------------------------------------------------------------------ open / close

local function Caps()
  for _, L in pairs(CS.L) do
    local n = M(CS.C.LAYER_NUM, L)
    CS.cap[L] = type(n) == "number" and n or 0
  end
  CS.here = (CS.cap[CS.L.TEXT] or 0) > 0
end

local function Header(text_id_or_string)
  if type(SwapSoccerTopCommonHeaderByHeaderType) ~= "function" then return end
  local s = text_id_or_string
  if type(s) == "number" then
    local ok, t = pcall(funcLuaCommand, CS.C.TEXT_GET, s)
    s = ok and t or nil
  end
  if type(s) == "string" then pcall(SwapSoccerTopCommonHeaderByHeaderType, CS.HEADER_TYPE, s, CS.HEADER_ICON) end
end

local function Open()
  Caps()
  if not CS.here then
    Log("no panel layers in this menu")
    Snd(CS.SY_ERROR)
    return
  end
  CS.sent, CS.faces, CS.shown = {}, {}, {}
  Load()
  CS.open, CS.sel, CS.top = true, 1, 1
  M(CS.C.MENU_INPUT, CS.MENU, false)
  Header(Tx("Row"))
  KeysReset()
  Snd(CS.SY_OK)
end

local function Close()
  CS.open = false
  BeginFrame()
  EndFrame()
  HideAll()
  Header(CS.HEADER_TITLE)
  M(CS.C.CTRL_FOCUS, CS.LIST, true)
  M(CS.C.MENU_INPUT, CS.MENU, true)
  Snd(CS.SY_MOVE)
  Log("closed")
end

Utilities.ClubStats = { Open = Open, Close = Close }

local function Move(d)
  local n = #CS.rows
  if n == 0 then return end
  local s = math.max(1, math.min(n, CS.sel + d))
  if s == CS.sel then return end
  CS.sel = s
  if CS.sel < CS.top then CS.top = CS.sel end
  if CS.sel >= CS.top + CS.P.rows then CS.top = CS.sel - CS.P.rows + 1 end
  Snd(CS.SY_MOVE)
end

local function Resort(d)
  CS.sort = (CS.sort - 1 + d) % #CS.SORTS + 1
  SortRows()
  CS.sel, CS.top = 1, 1
  Snd(CS.SY_MOVE)
end

local function StepOpen()
  CS.frame = CS.frame + 1
  if not CS.art_ok and TexReady(CS.art, 1) then
    CS.art_ok = true
    CS.sent = {}
  end
  if Pressed("back") or Pressed("rclick") then
    Close()
    return
  end
  if Pressed("up", true) then Move(-1)
  elseif Pressed("down", true) then Move(1)
  elseif Pressed("l1", true) or Pressed("wup") then Move(-CS.P.rows)
  elseif Pressed("r1", true) or Pressed("wdown") then Move(CS.P.rows)
  elseif Pressed("left") then Resort(-1)
  elseif Pressed("right") or Pressed("enter") then Resort(1)
  end
  Draw()
end

-- ------------------------------------------------------------------------------------------------ hooks

if UTIL_CST_HOOKED == nil then
  UTIL_CST_HOOKED = true
  local function ours(a1)
    return a1 == CS.L.BACK or a1 == CS.L.PLATE or a1 == CS.L.ICON or a1 == CS.L.FACE or a1 == CS.L.TEXT
  end
  local init = OnInit
  if type(init) == "function" then
    OnInit = function(...)
      CS.open, CS.cap, CS.opened, CS.sent, CS.shown, CS.faces = false, {}, {}, {}, {}, {}
      return init(...)
    end
  end
  -- our layers: no retail setup / open code sees them (hidden until the panel draws them)
  local setup = OnSetupLayer
  if type(setup) == "function" then
    OnSetupLayer = function(a1, a2, ...)
      if ours(a1) then
        pcall(funcLuaMenuCommand, CS.C.VISIBLE, a1, a2, false)
        return
      end
      return setup(a1, a2, ...)
    end
  end
  local open = OnOpenLayer
  if type(open) == "function" then
    OnOpenLayer = function(a1, a2, ...)
      if ours(a1) then
        if not (CS.open and CS.shown[a1 .. ":" .. tostring(a2)]) then
          pcall(funcLuaMenuCommand, CS.C.VISIBLE, a1, a2, false)
        end
        return
      end
      return open(a1, a2, ...)
    end
  end
  -- while the panel is up the list underneath takes no key (the menu's input is off; a stray event is dropped)
  for _, name in ipairs({"OnChangeFocus", "OnEnter", "OnFunction"}) do
    local f = _ENV[name]
    if type(f) == "function" then
      _ENV[name] = function(...)
        if CS.open then return end
        return f(...)
      end
    end
  end
  local step = Step
  Step = function(...)
    if CS.open then
      local ok, err = pcall(StepOpen)
      if not ok then
        Log("step error", tostring(err))
        pcall(Close)
      end
    end
    if type(step) == "function" then return step(...) end
  end
end
