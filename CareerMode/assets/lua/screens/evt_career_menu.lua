-- evt_career_menu (plain Lua 5.2 source): the career hub (docs/game/mods/career-mode-proposal.md §1b, §8). Declared in
-- content\menus\career_menu.toml ([[screen]], served as common/script/lua/menu/evt_career_menu.lua.bin); opened by the
-- mode's title row button (content\menus\title_row.toml) as a child of the title, which takes input back when it closes.
-- Pages:
--   home  no career: «Nueva carrera» / «Salir»; a career: «Continuar» / «Nueva carrera» (asks first) / «Salir»
--   pick  the club pick: the clubs of a career by game on top (L1 / R1), the clubs as a carousel (left / right), the
--         focused club's card below (stars, ATA / MED / DEF, formation, best players); A asks to start
--   hub   a tab bar on top (L1 / R1; the tabs are config.toml [hub] tabs, some only in some phases): Inicio (the next
--         match and its date: A plays it, Y simulates it; today's date, the table around the club, form, club, news
--         with the transfer window), Calendario (a month of the season's days, FIFA style: the club's matches with
--         their rivals and results, the draw, the transfer windows, the breaks, the World Cup; the month's matches
--         listed beside it; arrows: month), Competición (left / right: the competition, its name centred in the
--         header: SuperLiga and leagues as a table (up / down: page); the Fútbol Frontier's knockout; the World Cup:
--         its groups together in a grid, up / down to its knockout once drawn. The knockouts are the framework's
--         bracket screen vrfw_bracket_menu, opened over this one by VRFW_Bracket and drawn from
--         CMND_CAREERMODE_TREE / CMND_CAREERMODE_WC_TREE), Plantilla
--   pots  the draw of the leagues: the pots, a ball at a time (A; Y draws the rest), then A starts the leagues
--   wcsquad  a call-up: the World Cup's (the offered national side's players, Y confirms a full squad and the group
--         stage starts) or the club's (from «Plantilla» with A when the squad is larger than a match takes: the players
--         its matches take, Y keeps a full call-up); A calls one up or leaves him out, B back to the hub
-- The squads are the career's (every player once per career): the hub writes them into the clubs' roster rows
-- (CMND_VRFW_TEAM_ROSTER) before it reads their stats, and puts the data's rows back when the player leaves the mode.
-- The club card's numbers are the game's own stats at the club's level (team member info, field 10), rated by the
-- rules of config.toml [rating]. «Jugar» starts the match with VRFW_MATCH.start (content\friendlies\career.toml): the
-- title comes back after it and opens the hub again. Both clubs play through the slot teams of config.toml [match]
-- (CMND_VRFW_TEAM_STAND_IN) with their match squads (the whole squad, or the call-up / the best when larger), so every signing sits on the bench. Keys: cmd rows of the off-screen anchor row -> OnFunction /
-- OnBack. Data: scripts\career.lua through the commands CMND_CAREERMODE_* (a command that answers nothing while the
-- scripts are busy is asked again next frame). No engine call at load time.
INCLUDE("LUA_PROG_BASE")
INCLUDE("LUA_SAVEDATA_MANAGEMENT_MENU_INC")

local C = {
  LOG = 3661580131, TEXT_GET = 4074371074, LANG = 477234096, SND = 3073642526,
  LAYER_NUM = 1175615627, OPEN_LAYER = 629267548, VISIBLE = 711242136, POS = 1389957207, SCALE = 3778714801,
  SPRITE = 558735651, ALPHA = 4231609516, MESH_VISIBLE = 3405944500, SET_TEXT = 1083631230, LOAD_TEX = 839427544,
  TEX_LOADING = 1506186496, TEXT_STYLE = 2333948100, CTRL = 3518307824, LIST_NUM = 3252599449,
  FOCUS_SET = 3466097042, ATTACH_TRACE = 1774843228, TEAM_INFO = 2151743654,
  TEXT_VISIBLE = 1505208242,
  MEMBER = 34355761,           -- team member info (team, member, field[, stat]): 0 card, 6 level, 7 place, 10 stat
  INPUT = 1558704558,          -- CMND_SET_INPUT_ENABLE_MENU_OBJECT
  CLOSE_MENU = 320421347,      -- CMND_CLOSE_MENU_OBJECT
}
local SND = { MOVE = 2500047763, BUZZER = 2086672038, DECIDE = 766561556, BACK = 202039849 }
local L_ANCHOR = 3455690937        -- save01_02_list_item: the input anchor (1 instance, off screen)
local L_HEADER = 575058101         -- mainmenu90_01_header
local ANCHOR = { TEXTS = { 931545948 --[[_text_list01_on]], 3705682548 --[[_text_list01_off]] }, CURSOR = 3313461902 }
local SUB_TITLE = 1220590795       -- _text_sub_title02 of the header
local QUAD = 1909474081            -- icon_new01: the cmn01_10 quad's sprite slot
local Q = 36                       -- the cmn01_10 quad side
-- the text object (cmn03_01_cmd_back): its text node and the meshes hidden; the box is 768 px wide, centred
local TXT = { NODE = 378327766, MESHES = { 298211823, 2853207670 }, HALF = 384, MID_Y = 144 }
-- the club row (team06_02): plate meshes (off / on / ok / outline), crest, name nodes; retail geometry at scale 1
local TEAM = {
  PLATES = { off = 2022529787, on = 2334302522, ok = 4215821749, ol = 1697431574 },
  TXT_ON = 931545948, TXT_OFF = 3705682548,   -- the crest: VRFW_Team.Emblem
  PLATE_LEFT = 98, CREST_CENTER = 78,   -- the plate starts 98 px left of the origin, the crest is centred 78 px right of it
}
-- retail sprites drawn on the quads
local TABS_TEX = "#/menu/200_icon/16_icon_list_tab/icon_list_tab.g4tx"
local ART = {
  navy = { tex = "#/menu/10_win/win05/win05_43/win05_43.g4tx", sprite = "win_settings_base01" },
  white = { tex = "#/menu/102_team/team00/team00_21b/team00_21b.g4tx", sprite = "item_win_base02" },
  band = { tex = "#/menu/20_cmn/cmn06/cmn06_01/cmn06_01.g4tx", sprite = "list_tab_base01" },
  strip = { tex = "#/menu/20_cmn/cmn06/cmn06_01/cmn06_01.g4tx", sprite = "list_tab_base01_02" },
  row = { tex = "#/menu/51_save/save01/save01_02/save01_02.g4tx", sprite = "list_base_s01_off" },
  row_on = { tex = "#/menu/51_save/save01/save01_02/save01_02.g4tx", sprite = "list_base_s01_on" },
  row_ol = { tex = "#/menu/51_save/save01/save01_02/save01_02.g4tx", sprite = "list_base_s01_ol" },
  row_ok = { tex = "#/menu/51_save/save01/save01_02/save01_02.g4tx", sprite = "list_base_s01_ok" },
  cursor = { tex = "#/menu/20_cmn/cmn05/cmn05_01/cmn05_01.g4tx", sprite = "cur01", w = 128, h = 152 },
  star = { tex = "#/menu/00_soccer/soccer11/soccer11_14/soccer11_14.g4tx", sprite = "icon_star01" },
  arrow = { tex = "#/menu/10_win/win05/win05_28/win05_28.g4tx", sprite = "icon_arrow01_on", w = 28, h = 32 },
  vs = { tex = "#/menu/00_soccer/soccer00/soccer00_31/soccer00_31.g4tx", sprite = "gtxt_vs01", w = 124, h = 76 },
  play = { tex = "#/menu/20_cmn/cmn03/cmn03_02/cmn03_02.g4tx", sprite = "cmd_btn_base01_on" },
}
local STYLE = {
  title = "fs_32_w_lc_2d0_001", title_c = "fs_32_w_cc_2d0_001", item = "fs_32_b_lc_2d0_001",
  item_on = "fs_32_w_lc_2d0_001", body = "fs_28_b_lc_2d0_001", body_c = "fs_28_b_cc_2d0_001",
  body_w = "fs_28_w_cc_2d0_001", dim = "fs_28_k_cc_2d0_001", label = "fs_22_k_cc_2d0_001_nr_sclw",
  label_l = "fs_22_k_lc_2d0_001_nr_sclw", outline = "fs_26_w_lc_2d2_001", outline_c = "fs_26_w_cc_2d2_001",
  big = "fs_32_b_cc_2d0_001",
}
local GLYPH = 0.5
-- the screen (px at 1080p, y down)
local G = {
  LEFT = { x = 60, y = 140, w = 500, h = 880 }, RIGHT = { x = 600, y = 140, w = 1260, h = 880 },
  BAND_H = 64, MENU_Y = 470, MENU_STEP = 84, MENU_W = 440, MENU_H = 72, FOOT_Y = 1034,
  TABS = { x = 60, y = 122, w = 1800, h = 76 },
  PAGE = { x = 60, y = 220, w = 1800, h = 780 },
  CARD = { x = 120, y = 600, w = 1680, h = 390 },
  TABLE_STEP = 32, TABLE_SCALE = 0.42,
}
local COLS = { "played", "won", "drawn", "lost", "goals_for", "goals_against", "diff", "points" }
local COL_X = { 1250, 1330, 1410, 1490, 1570, 1650, 1730, 1810 }
local COL_TEXT = { "ColPlayed", "ColWon", "ColDrawn", "ColLost", "ColFor", "ColAgainst", "ColDiff", "ColPoints" }
local POS_TEXT = { [1] = "PosGK", [2] = "PosFW", [3] = "PosMF", [4] = "PosDF" }
local RATE_PER_STEP = 2            -- clubs whose stats are read in one Step
local APPLY_PER_STEP = 8           -- clubs whose career squads are written in one Step
local SERIES_ICON = "icon_list_tab_series%02d"   -- the tab atlas' series icons, 1 ie1 ... 9 victory_road
-- a knockout of the «Competición» tab: the framework's bracket below the competition header (top = the page's top
-- row), its retail art (draw priorities 197-203) lifted over this screen's background (mainmenu90_00_background, 450)
-- and under the bracket's own pools (546 and up); VIEW = the view command of each knockout
local BRACKET = { VIEW = { frontier = "CMND_CAREERMODE_TREE", worldcup = "CMND_CAREERMODE_WC_TREE" }, TOP = G.PAGE.y,
  LIFT = 300, HEAD_H = 56 }
-- the competition header: the arrows' distance from the centre of the page
local COMPETITION = { ARROW_GAP = 240 }
-- the World Cup's groups together: a grid of small tables (columns = ceil(sqrt(groups)), at least 2)
local GROUPS = { TOP = 84, GAP_X = 30, GAP_Y = 20, HEAD = 46, STEP_MAX = 50, CREST_MAX = 0.55 }

-- state of this opening
local S = {
  ready = false, frame = 0, dirty = true, sent = {}, used = {}, shown = {}, opened = {}, cap = {}, texts = {},
  emb = {}, loaded = {}, names = {}, mode = "loading", sel = 1, state = nil, draw = nil, hub = nil, want = nil,
  pick = { league = 1, sel = 1 }, tab = 1, page = 1, table = nil, dialog = nil, closing = false,
  rate = {}, queue = {}, clubs = {}, club_want = nil, rules = nil, kits = {},
  apply = {}, applied = {}, tindex = 1, tpage = 1, pots = nil, match = false,
}
local L = {}
local MENU = 0

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
  pcall(funcLuaCommand, C.LOG, "CareerMode hub " .. table.concat(p, " "))
end

-- a text of text\rows\career.toml (id "CareerMode.<name>") in the game's language; {1} .. {4} filled from the
-- arguments
local function Tx(name, ...)
  local t = S.texts[name]
  if t == nil then
    local ok, s = pcall(funcLuaCommand, C.TEXT_GET, Crc("CareerMode." .. name))
    t = (ok and type(s) == "string" and s ~= "") and s or name
    S.texts[name] = t
  end
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if v ~= nil then t = t:gsub("{" .. i .. "}", function() return tostring(v) end) end
  end
  return t
end

-- a date of the career's calendar ({ day, y, m, d, wd } from scripts\career.lua): «sáb 29 de agosto de 2026»,
-- «29/08», «Agosto 2026»; "" without a date
local function DateLong(v)
  if type(v) ~= "table" then return "" end
  return Tx("DateLong", Tx("Weekday" .. v.wd), v.d, Tx("Month" .. v.m), v.y)
end

local function DateShort(v)
  if type(v) ~= "table" then return "" end
  return Tx("DateShort", string.format("%02d", v.d), string.format("%02d", v.m))
end

local function MonthTitle(mo)
  return Tx("MonthYear", Tx("Month" .. mo.m), mo.y)
end

local function M(cmd, ...)
  local ok, a, b = pcall(funcLuaMenuCommand, cmd, ...)
  if ok then return a, b end
  return nil
end

-- a game command answering (found, value): the value, nil when not found
local function F(cmd, ...)
  local ok, found, v = pcall(funcLuaCommand, cmd, ...)
  if ok and found then return v end
  return nil
end

local function Snd(s) pcall(funcLuaCommand, C.SND, s) end

local function Lang()
  local ok, l = pcall(funcLuaCommand, C.LANG)
  return ok and l or 1
end

-- a career command: its table, nil when the scripts did not answer (asked again by Step)
local function Call(name, ...)
  local ok, v = pcall(funcLuaCommand, Crc(name), ...)
  if ok and type(v) == "table" then return v end
  return nil
end

-- the team the player leads now (the national side during the World Cup, else his club)
local function Me(h)
  return h and (h.me or h.team) or 0
end

local function LeagueName(i)
  return Tx("LeagueTitle", string.char(64 + i))
end

local function TeamName(team)
  if team == nil or team == 0 then return "" end
  local n = S.names[team]
  if n == nil then
    n = VRFW_Team.Name(team)
    S.names[team] = n
  end
  return n
end

local function Units(s)
  local u = 0
  for ch in tostring(s or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do u = u + ((ch:byte(1) or 0) >= 0xE3 and 2 or 1) end
  return u
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

local function Has(list, v)
  for _, x in ipairs(list or {}) do
    if x == v then return true end
  end
  return false
end

-- ---- the club card's numbers -------------------------------------------------------------------------------------------

-- a club's players from the game: { players = { { card, place, level, rating } }, overall, level } (rating = the
-- mean of the rules' stats at the club's level; overall = the starters' mean)
local function RateTeam(team, rules)
  local n = F(C.TEAM_INFO, team, 8)
  local out = { players = {}, overall = 0, level = 0 }
  if type(n) ~= "number" then return out end
  local sum, cnt, lv_sum = 0, 0, 0
  for i = 0, n - 1 do
    local card = F(C.MEMBER, team, i, 0)
    local place = F(C.MEMBER, team, i, 7)
    if type(card) == "number" and card ~= 0 then
      local total, got = 0, 0
      for _, idx in ipairs(rules.stats) do
        local v = F(C.MEMBER, team, i, 10, idx)
        if type(v) == "number" then
          total, got = total + v, got + 1
        end
      end
      local p = { card = card, place = type(place) == "number" and place or -1, level = F(C.MEMBER, team, i, 6) or 0,
        rating = got > 0 and math.floor(total / got + 0.5) or 0 }
      out.players[#out.players + 1] = p
      if p.place >= 0 and p.place < rules.starter_places then
        sum, cnt, lv_sum = sum + p.rating, cnt + 1, lv_sum + p.level
      end
    end
  end
  if cnt > 0 then
    out.overall = sum / cnt
    out.level = math.floor(lv_sum / cnt + 0.5)
  end
  return out
end

local function Queue(teams)
  for _, t in ipairs(teams) do
    if S.rate[t] == nil and not Has(S.queue, t) then S.queue[#S.queue + 1] = t end
  end
end

-- the clubs waiting for their numbers: a few each Step
local function RateSome()
  if S.rules == nil then return end
  for _ = 1, RATE_PER_STEP do
    local t = table.remove(S.queue, 1)
    if t == nil then return end
    local ok, r = pcall(RateTeam, t, S.rules)
    S.rate[t] = ok and r or { players = {}, overall = 0, level = 0 }
    if not ok then Log("stats of", t, "not read:", tostring(r)) end
    S.dirty = true
  end
end

-- a club's stars by its place among `teams` (all rated); nil while they are not
local function Stars(team, teams)
  local r = S.rules
  local me = S.rate[team]
  if r == nil or me == nil then return nil end
  local better, n = 0, 0
  for _, t in ipairs(teams) do
    local x = S.rate[t]
    if x == nil then return nil end
    n = n + 1
    if x.overall > me.overall then better = better + 1 end
  end
  local pct = n > 1 and (n - 1 - better) / (n - 1) or 1
  local v = r.stars_min + (r.stars_max - r.stars_min) * pct
  return math.floor(v / r.stars_step + 0.5) * r.stars_step
end

-- the players of a club joined with the script's answer (names, main positions, numbers): best first
local function Players(team)
  local rated = S.rate[team]
  local club = S.clubs[team]
  if rated == nil or club == nil then return nil end
  local info = {}
  for _, p in ipairs(club.players or {}) do info[p.card] = p end
  local out = {}
  for _, p in ipairs(rated.players) do
    local k = info[p.card] or {}
    out[#out + 1] = { card = p.card, place = p.place, level = p.level, rating = p.rating, name = k.name or "",
      position = k.position or 0, number = k.number or 0 }
  end
  return out
end

-- ATA / MED / DEF and the formation shape (defence-midfield-attack) of the club's starters
local function Lines(players)
  local r = S.rules
  local acc = { attack = { 0, 0 }, midfield = { 0, 0 }, defence = { 0, 0 } }
  for _, p in ipairs(players) do
    if p.place >= 0 and p.place < r.starter_places then
      for line, a in pairs(acc) do
        if Has(r[line], p.position) then a[1], a[2] = a[1] + p.rating, a[2] + 1 end
      end
    end
  end
  local function mean(a) return a[2] > 0 and math.floor(a[1] / a[2] + 0.5) or 0 end
  return { attack = mean(acc.attack), midfield = mean(acc.midfield), defence = mean(acc.defence),
    shape = acc.defence[2] .. "-" .. acc.midfield[2] .. "-" .. acc.attack[2] }
end

-- the highest player rating among the rated clubs of `teams` (the bars' full length)
local function Scale(teams)
  local best = 1
  for _, t in ipairs(teams) do
    for _, p in ipairs(S.rate[t] and S.rate[t].players or {}) do
      if p.rating > best then best = p.rating end
    end
  end
  return best
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

local function TexReady(tex)
  if S.loaded[tex] == nil then
    pcall(funcLuaMenuCommand, C.LOAD_TEX, tex)
    S.loaded[tex] = true
  end
  local ok, loading = pcall(funcLuaCommand, C.TEX_LOADING, Crc(tex))
  return ok and loading == false
end

-- a retail sprite stretched over x, y, w, h on a quad layer (flip = mirrored left to right)
local function Quad(layer, art, x, y, w, h, alpha, flip)
  if not TexReady(art.tex) then
    S.dirty = true
    return nil
  end
  local i = Slot(layer)
  if i == nil then return nil end
  Show(layer, i)
  Set(layer, i, "sc", C.SCALE, layer, (flip and -w or w) / Q, h / Q, 1, i)
  Set(layer, i, "sp", C.SPRITE, layer, Crc(art.tex), Crc(art.sprite), QUAD, 0, i)
  Set(layer, i, "pos", C.POS, layer, x + w / 2, -(y + h / 2), 0, i)
  Set(layer, i, "a", C.ALPHA, layer, i, 0, alpha or 1)
  return i
end

local function Cursor(x, y, h)
  local w = h * ART.cursor.w / ART.cursor.h
  local bob = math.floor(3 * math.sin(S.frame * 2 * math.pi / 30) + 0.5)
  Quad(L.icon, ART.cursor, x - w + bob, y - h / 2, w, h)
end

-- a text: x = its left edge (align "l") or centre (align "c"), y = its vertical middle
local function Text(layer, s, x, y, style, sc, align)
  if s == nil or s == "" then return nil end
  local i = Slot(layer)
  if i == nil then return nil end
  sc = sc or 1
  Show(layer, i)
  for _, m in ipairs(TXT.MESHES) do Set(layer, i, "m" .. m, C.MESH_VISIBLE, layer, m, false, i) end
  Set(layer, i, "st", C.TEXT_STYLE, layer, i, TXT.NODE, Crc(STYLE[style] or STYLE.body))
  Set(layer, i, "txt", C.SET_TEXT, layer, TXT.NODE, s, i)
  Set(layer, i, "sc", C.SCALE, layer, sc, sc, 1, i)
  local px = align == "c" and x or (x + TXT.HALF * sc)
  Set(layer, i, "pos", C.POS, layer, px, -y - TXT.MID_Y * sc, 0, i)
  return i
end

-- a club row: plate shown in `look` ("off", "focus", or nil = no plate), crest + name; x = the plate's left edge,
-- y = its vertical middle, s = scale; name nil = the club's own name, "" = none; alpha < 1 = dimmed
local function Team(team, x, y, s, look, name, alpha)
  local l = L.team
  local i = Slot(l)
  if i == nil then return nil end
  Show(l, i)
  Set(l, i, "sc", C.SCALE, l, s, s, 1, i)
  Set(l, i, "pos", C.POS, l, x + TEAM.PLATE_LEFT * s, -y, 0, i)
  Set(l, i, "a", C.ALPHA, l, i, 0, alpha or 1)
  Set(l, i, "p.off", C.MESH_VISIBLE, l, TEAM.PLATES.off, look == "off", i)
  Set(l, i, "p.on", C.MESH_VISIBLE, l, TEAM.PLATES.on, look == "focus", i)
  Set(l, i, "p.ok", C.MESH_VISIBLE, l, TEAM.PLATES.ok, false, i)
  Set(l, i, "p.ol", C.MESH_VISIBLE, l, TEAM.PLATES.ol, look == "focus", i)
  local text = name or TeamName(team)
  local white = look == "focus"
  Set(l, i, "t.on", C.SET_TEXT, l, TEAM.TXT_ON, white and text or "", i)
  Set(l, i, "t.off", C.SET_TEXT, l, TEAM.TXT_OFF, white and "" or text, i)
  Set(l, i, "v.on", C.TEXT_VISIBLE, l, TEAM.TXT_ON, white, i)
  Set(l, i, "v.off", C.TEXT_VISIBLE, l, TEAM.TXT_OFF, not white, i)
  VRFW_Team.Emblem(l, i, team, S.emb)
  return i
end

-- a club's crest alone, centred on (cx, cy), crest 68 x s px
local function Crest(team, cx, cy, s, alpha)
  return Team(team, cx - (TEAM.PLATE_LEFT + TEAM.CREST_CENTER) * s, cy, s, nil, "", alpha)
end

-- the kit a player's miniface wears in the colours of `team` (the career club or national side he plays for): that
-- team's uniform as CMND_VRFW_CONTACT_KIT(card, team) derives it from the team data (the keeper shirt for a keeper);
-- asked once per card and team. nil = no kit found: the character's own kit
local KEEPER_SHIRT = 2           -- CMND_VRFW_CONTACT_KIT flags: the keeper shirt
local function Kit(card, team)
  if (team or 0) == 0 then return nil end
  local id = card .. ":" .. team
  local kit = S.kits[id]
  if kit == nil then
    kit = false
    local ok, t = pcall(funcLuaCommand, Crc("CMND_VRFW_CONTACT_KIT"), card, team)
    if ok and type(t) == "table" and type(t.uniform) == "number" and t.uniform ~= 0 then
      kit = { kit = t.uniform, keeper = bit32.band(tonumber(t.flags) or 0, KEEPER_SHIRT) ~= 0, use_args = true }
    end
    S.kits[id] = kit
  end
  return kit or nil
end

-- a player's miniface (VRFW_FaceIcon: the list character card, face + kit) centred on (x, y), px tall, wearing the
-- kit of `team` (nil = his own kit)
local function Face(card, x, y, px, team)
  if (card or 0) == 0 or VRFW_FaceIcon == nil then return end
  local i = Slot(L.face)
  if i == nil then return end
  Show(L.face, i)
  VRFW_FaceIcon.Card(L.face, i, { card = card }, x, y, px, Kit(card, team) or { use_args = true })
end

local function BeginFrame() S.used = {} end

local function EndFrame()
  for k in pairs(S.shown) do
    local layer, i = k:match("^(%d+):(%d+)$")
    layer, i = tonumber(layer), tonumber(i)
    if layer and i and i >= (S.used[layer] or 0) then
      Set(layer, i, "vis", C.VISIBLE, layer, i, false)
      S.shown[k] = nil
      if layer == L.team then
        VRFW_Team.EmblemReset(layer, i, S.emb)
      end
      if layer == L.face and VRFW_FaceIcon ~= nil then
        VRFW_FaceIcon.Forget(layer, i)
      end
    end
  end
end

-- ---- pieces ------------------------------------------------------------------------------------------------------------

local function Panels(right_title)
  local Lp, R = G.LEFT, G.RIGHT
  Quad(L.panel, ART.navy, Lp.x, Lp.y, Lp.w, Lp.h)
  Quad(L.panel, ART.white, R.x, R.y, R.w, R.h)
  Quad(L.panel, ART.band, R.x + 20, R.y + 16, R.w - 40, G.BAND_H)
  Text(L.text, right_title, R.x + 60, R.y + 16 + G.BAND_H / 2, "title")
end

-- a white tile with its title band
local function Tile(x, y, w, h, title)
  Quad(L.panel, ART.white, x, y, w, h)
  Quad(L.panel, ART.band, x + 14, y + 12, w - 28, 54)
  Text(L.text, title, x + 44, y + 39, "title", 0.9)
end

-- the left column's rows (texts), the selected one lit with the cursor
local function MenuRows(items, sel, y0, step, h)
  local x = G.LEFT.x + 30
  for k, it in ipairs(items) do
    local y = y0 + (k - 1) * step
    local on = k == sel
    Quad(L.plate, on and ART.row_on or ART.row, x, y, G.MENU_W, h, it.off and 0.5 or 1)
    if on then
      Quad(L.icon, ART.row_ol, x, y, G.MENU_W, h)
      Cursor(x + 4, y + h / 2, 44)
    end
    Text(L.text, it.text, x + 48, y + h / 2, on and "item_on" or "item", 0.95)
  end
end

local function Footer(keys)
  Text(L.text, table.concat(keys, "      "), G.LEFT.x + 10, G.FOOT_Y, "outline", 0.95)
end

-- five stars from `value` (half steps dimmed), size px each
local function StarsRow(value, x, y, size)
  for k = 1, 5 do
    local a = (value or 0) >= k and 1 or ((value or 0) >= k - 0.5 and 0.55 or 0.18)
    Quad(L.icon, ART.star, x + (k - 1) * (size + 6), y, size, size, a)
  end
end

-- a line's bar: label, track, fill (value / scale), value
local function Bar(label, value, scale, x, y, w)
  Text(L.text, label, x, y, "body", 0.95)
  Quad(L.plate, ART.row, x + 90, y - 12, w, 24)
  if value > 0 then
    Quad(L.plate, ART.row_on, x + 90, y - 12, math.max(24, w * math.min(1, value / math.max(1, scale))), 24)
  end
  Text(L.text, tostring(value), x + 120 + w, y, "body", 1.05)
end

local function Dialog()
  local d = S.dialog
  if d == nil then return end
  local w, h = 960, 360
  local x, y = (1920 - w) / 2, (1080 - h) / 2
  Quad(L.dialog, ART.navy, x, y, w, h)
  Quad(L.dialog, ART.band, x + 20, y + 20, w - 40, 60)
  Text(L.dtext, d.title, x + 60, y + 50, "title")
  for k, line in ipairs(d.lines) do
    Text(L.dtext, line, x + w / 2, y + 120 + (k - 1) * 52, "body_w", 1, "c")
  end
  Text(L.dtext, Tx("KeyYes") .. "      " .. Tx("KeyNo"), x + w / 2, y + h - 50, "body_w", 1, "c")
end

-- ---- home --------------------------------------------------------------------------------------------------------------

local function HomeItems()
  local items = {}
  local st = S.state or {}
  if st.career then items[#items + 1] = { id = "continue", text = Tx("Continue") } end
  items[#items + 1] = { id = "new", text = Tx("NewCareer"), off = st.ok ~= true }
  items[#items + 1] = { id = "exit", text = Tx("Exit") }
  return items
end

local function PhaseName(phase)
  return Tx("Phase_" .. tostring(phase or ""))
end

local function DrawHome()
  local st = S.state or {}
  local Lp, R = G.LEFT, G.RIGHT
  if st.career then
    local c = st.career
    Panels(Tx("YourCareer"))
    Crest(c.team, Lp.x + 90, Lp.y + 86, 1.3)
    Text(L.text, Fit(TeamName(c.team), 300, 32), Lp.x + 160, Lp.y + 64, "title")
    Text(L.text, Tx("SeasonN", c.season), Lp.x + 160, Lp.y + 108, "title", 0.8)
    Crest(c.team, R.x + 170, R.y + 220, 1.8)
    Text(L.text, TeamName(c.team), R.x + 300, R.y + 190, "body", 1.2)
    Text(L.text, Tx("SeasonN", c.season) .. "  ·  " .. PhaseName(c.phase), R.x + 300, R.y + 250, "body")
  else
    Panels(Tx("Title"))
    Text(L.text, Tx("Title"), Lp.x + 40, Lp.y + 80, "title", 1.3)
    Text(L.text, Tx("Season"), Lp.x + 40, Lp.y + 140, "title", 0.8)
    for k, key in ipairs({ "Intro1", "Intro2", "Intro3", "Intro4" }) do
      Text(L.text, Tx(key), R.x + 60, R.y + 150 + (k - 1) * 56, "body")
    end
    if st.ok == false then
      Text(L.text, Tx("NeedsBattleBayDeluxe"), R.x + 60, R.y + 420, "body")
    end
  end
  MenuRows(HomeItems(), S.sel, G.MENU_Y, G.MENU_STEP, G.MENU_H)
  Footer({ Tx("KeyAccept"), Tx("KeyBack") })
end

-- ---- club pick ---------------------------------------------------------------------------------------------------------

local function PickTeams()
  local d = S.draw
  return d and d.leagues and d.leagues[S.pick.league] or {}
end

local function GroupName(i)
  local g = S.draw and S.draw.groups and S.draw.groups[i] or 0
  return Tx("Saga" .. g)
end

-- the focused club: its card's data asked for, its group's numbers queued (the focused club first)
local function PickFocus()
  local teams = PickTeams()
  local team = teams[S.pick.sel]
  if team == nil then return end
  if S.rate[team] == nil and not Has(S.queue, team) then table.insert(S.queue, 1, team) end
  Queue(teams)
  if S.clubs[team] == nil then S.club_want = team end
end

-- the club card under the carousel: stars, lines, formation | best players
local function ClubCard(team, teams, box)
  local x, y, w, h = box.x, box.y, box.w, box.h
  Quad(L.panel, ART.white, x, y, w, h)
  Text(L.text, Tx("Rating"), x + 60, y + 50, "label_l", 1.3)
  local stars = Stars(team, teams)
  StarsRow(stars or 0, x + 60, y + 76, 40)
  local players = Players(team)
  if players ~= nil then
    local ln = Lines(players)
    local scale = Scale(teams)
    Bar(Tx("LineAttack"), ln.attack, scale, x + 60, y + 170, 300)
    Bar(Tx("LineMidfield"), ln.midfield, scale, x + 60, y + 222, 300)
    Bar(Tx("LineDefence"), ln.defence, scale, x + 60, y + 274, 300)
    Text(L.text, Tx("Formation", ln.shape), x + 60, y + 336, "body", 1.05)
    table.sort(players, function(a, b) return a.rating > b.rating end)
    local bx = x + 620
    Text(L.text, Tx("BestPlayers"), bx, y + 50, "label_l", 1.3)
    for k = 1, math.min(S.rules.best_players, #players) do
      local p = players[k]
      local ry = y + 100 + (k - 1) * 56
      Quad(L.plate, ART.row, bx - 10, ry - 24, w - 640, 50)
      Face(p.card, bx + 30, ry, 48, team)
      Text(L.text, Fit(p.name ~= "" and p.name or "-", 520, 28), bx + 70, ry, "body", 0.95)
      Text(L.text, Tx(POS_TEXT[p.position] or "PosMF"), bx + 640, ry, "body_c", 0.95, "c")
      Text(L.text, Tx("LevelShort", p.level), bx + 780, ry, "body_c", 0.9, "c")
      Text(L.text, tostring(p.rating), bx + 920, ry, "big", 1, "c")
    end
  end
end

local function DrawPick()
  local teams = PickTeams()
  local n = #teams
  local cx = 960
  -- the game selector: its series icon and name
  Quad(L.panel, ART.band, cx - 420, 128, 840, 62)
  local g = S.draw.groups and S.draw.groups[S.pick.league] or 0
  if g >= 1 and g <= 9 then
    Quad(L.icon, { tex = TABS_TEX, sprite = string.format(SERIES_ICON, g) }, cx - 250, 134, 72, 48)
  end
  Text(L.text, GroupName(S.pick.league), cx + 30, 159, "title_c", 1.1, "c")
  Quad(L.icon, ART.arrow, cx - 382, 140, 34, 38, 1, true)
  Quad(L.icon, ART.arrow, cx + 348, 140, 34, 38)
  Text(L.text, "L1", cx - 300, 159, "title_c", 0.85, "c")
  Text(L.text, "R1", cx + 300, 159, "title_c", 0.85, "c")
  Text(L.text, Tx("ClubOf", S.pick.sel, n), cx, 214, "outline_c", 0.9, "c")
  -- the carousel: the focused crest big, its neighbours smaller and dimmed
  local team = teams[S.pick.sel]
  if team ~= nil then
    local cy = 360
    for _, side in ipairs({ { -2, 1.4, 0.35, -560 }, { 2, 1.4, 0.35, 560 }, { -1, 2.0, 0.6, -330 }, { 1, 2.0, 0.6, 330 } }) do
      if n > math.abs(side[1]) then
        Crest(teams[(S.pick.sel - 1 + side[1]) % n + 1], cx + side[4], cy, side[2], side[3])
      end
    end
    Crest(team, cx, cy, 3.6)
    Quad(L.icon, ART.arrow, cx - 232, cy - 26, 46, 52, 1, true)
    Quad(L.icon, ART.arrow, cx + 186, cy - 26, 46, 52)
    Text(L.text, Fit(TeamName(team), 1100, 32), cx, 520, "outline_c", 1.6, "c")
    local rated = S.rate[team]
    if rated ~= nil and rated.level > 0 then
      Text(L.text, Tx("Level", rated.level), cx, 568, "outline_c", 1, "c")
    end
    ClubCard(team, teams, G.CARD)
  end
  Footer({ Tx("KeyAccept"), Tx("KeyBack"), Tx("KeyGame"), Tx("KeyClub") })
end

-- ---- hub ---------------------------------------------------------------------------------------------------------------

local function Tabs()
  return S.hub and S.hub.tabs or {}
end

local function TabBar()
  local b = G.TABS
  Quad(L.panel, ART.strip, b.x, b.y, b.w, b.h)
  local tabs = Tabs()
  local left, right = b.x + 210, b.x + b.w - 210
  local tw = (right - left) / math.max(1, #tabs)
  for k, t in ipairs(tabs) do
    local tx = left + (k - 1) * tw
    local on = k == S.tab
    if on then Quad(L.plate, ART.row_on, tx - 6, b.y + 10, tw + 12, b.h - 20) end
    if t.icon ~= "" then
      Quad(L.icon, { tex = TABS_TEX, sprite = t.icon }, tx + 20, b.y + 18, 60, 40, on and 1 or 0.7)
    end
    Text(L.text, Fit(Tx(t.text), tw - 110, 32), tx + 92, b.y + b.h / 2, "title", 0.95)
  end
  Text(L.text, "L1", b.x + 70, b.y + b.h / 2, "title_c", 0.9, "c")
  Text(L.text, "R1", b.x + b.w - 70, b.y + b.h / 2, "title_c", 0.9, "c")
end

-- the competition shown on «Competición»: a table { kind, title, rows, cut, direct, league }, the World Cup
-- { kind = "worldcup", groups, cut, direct, knockout } or the Fútbol Frontier's knockout { kind = "bracket", tree }
local function TableNow()
  local t = S.table or {}
  return t.table or (S.hub and S.hub.competition) or { rows = {} }, t.index or S.tindex
end

local function TableTitle(t)
  if t.kind == "league" then return LeagueName(t.league) end
  if t.kind == "group" then return Tx("GroupTitle", string.char(64 + (t.group or 1))) end
  if t.kind == "worldcup" or t.tree == "worldcup" then return Tx("CompWorldCup") end
  if t.kind == "bracket" then return Tx("CompFrontier") end
  return Tx("SuperLiga")
end

-- the page's header band with the competition's name centred between the two arrows (left / right: the next one);
-- panel = the white page under it too (a table or the groups; a knockout draws only the band)
local function CompetitionHeader(t, panel)
  local P = G.PAGE
  local cx = P.x + P.w / 2
  if panel then Quad(L.panel, ART.white, P.x, P.y, P.w, P.h) end
  Quad(L.panel, ART.band, P.x + 14, P.y + 12, P.w - 28, BRACKET.HEAD_H - 2)
  local many = (S.hub and S.hub.tables or 1) > 1
  if many then Quad(L.icon, ART.arrow, cx - COMPETITION.ARROW_GAP - 30, P.y + 22, 30, 34, 1, true) end
  Text(L.text, Fit(TableTitle(t), 2 * COMPETITION.ARROW_GAP - 40, 30), cx, P.y + 39, "title_c", 0.9, "c")
  if many then Quad(L.icon, ART.arrow, cx + COMPETITION.ARROW_GAP, P.y + 22, 30, 34) end
end

-- a round's name: «SuperLiga · Jornada 3», «Liga · Jornada 12», «Octavos de final»
local function RoundName(label, n, short)
  return Tx(tostring(label) .. (short and "Short" or ""), n)
end

-- a result «2 - 1» (« (p)» after a penalty shoot-out); "" when not played
local function Score(m)
  if m.hg == nil or m.hg < 0 then return "" end
  return m.hg .. " - " .. m.ag .. ((m.pens or 0) ~= 0 and (" " .. Tx("Pens")) or "")
end

local function NextTile(h)
  Tile(60, 220, 1060, 470, Tx("NextMatch"))
  local n = h.next or {}
  local cx = 590
  local days = h.days or {}
  if days.today then Text(L.text, Tx("TodayIs", DateLong(days.today)), 820, 259, "title_c", 0.72, "c") end
  if n.date then Text(L.text, DateLong(n.date), cx, 352, "label", 1.25, "c") end
  if n.kind == "match" then
    Text(L.text, RoundName(n.label, n.n), cx, 310, "big", 1, "c")
    for k, side in ipairs({ { n.home, cx - 300 }, { n.away, cx + 300 } }) do
      Crest(side[1], side[2], 430, 2.2)
      Text(L.text, Fit(TeamName(side[1]), 380, 32), side[2], 530, "big", 1, "c")
      Text(L.text, k == 1 and Tx("Home") or Tx("Away"), side[2], 570, side[1] == Me(h) and "body_c" or "dim", 0.85, "c")
    end
    Quad(L.icon, ART.vs, cx - 70, 390, 140, 140 * ART.vs.h / ART.vs.w)
    Quad(L.plate, ART.play, cx - 400, 605, 380, 66)
    Text(L.text, Tx("PlayKey"), cx - 210, 638, "body_w", 1.1, "c")
    Quad(L.plate, ART.row_on, cx + 20, 605, 380, 66)
    Text(L.text, Tx("SimKey"), cx + 210, 638, "body_w", 1.1, "c")
  elseif n.kind == "round" then
    Text(L.text, RoundName(n.label, n.n), cx, 310, "big", 1, "c")
    Text(L.text, h.out and Tx("OutOfCompetition") or Tx("NoMatchThisRound"), cx, 430, "body_c", 1.05, "c")
    Quad(L.plate, ART.play, cx - 190, 600, 380, 70)
    Text(L.text, Tx("SimRoundKey"), cx, 635, "body_w", 1.1, "c")
  elseif n.kind == "wc_call" then
    Text(L.text, Tx("WorldCupOfferTitle"), cx, 310, "big", 1.1, "c")
    Crest(n.side, cx - 280, 470, 2.0)
    Text(L.text, Tx("WorldCupOffer"), cx - 150, 420, "label_l", 1.2)
    Text(L.text, Fit(TeamName(n.side), 480, 32), cx - 150, 470, "big", 1.1)
    Text(L.text, Tx("WorldCupOffer2", h.worldcup and h.worldcup.squad or 0), cx - 150, 520, "label_l", 1.15)
    Quad(L.plate, ART.play, cx - 190, 600, 380, 70)
    Text(L.text, Tx("WorldCupPickKey"), cx, 635, "body_w", 1.1, "c")
  elseif n.kind == "draw" then
    Text(L.text, Tx("DrawTitle"), cx, 310, "big", 1.1, "c")
    Text(L.text, Tx("DrawLine", h.superliga_place, h.qualify), cx, 420, "body_c", 1, "c")
    Quad(L.plate, ART.play, cx - 190, 600, 380, 70)
    Text(L.text, Tx("DrawKey"), cx, 635, "body_w", 1.1, "c")
  elseif n.kind == "over" then
    Text(L.text, Tx("SeasonOver", h.season), cx, 310, "big", 1.1, "c")
    local why = h.out_reason ~= "" and Tx("Out_" .. h.out_reason, h.superliga_place, h.qualify) or Tx("Reached_" .. h.reached)
    Text(L.text, Fit(why, 960, 28), cx, 380, "body_c", 1, "c")
    if (h.champion or 0) ~= 0 then
      Text(L.text, Tx("Champion"), cx, 440, "label", 1.3, "c")
      Crest(h.champion, cx - 200, 510, 1.4)
      Text(L.text, Fit(TeamName(h.champion), 360, 32), cx - 130, 510, "big", 1)
    end
    Quad(L.plate, ART.play, cx - 190, 600, 380, 70)
    Text(L.text, Tx("NextSeasonKey"), cx, 635, "body_w", 1.1, "c")
  end
end

local function TableTile(h)
  local t = h.table or { rows = {} }
  Tile(1150, 220, 710, 470, TableTitle(t))
  local rows = t.rows or {}
  local me = 1
  for k, r in ipairs(rows) do
    if r.team == Me(h) then me = k end
  end
  local from = math.max(1, math.min(me - 2, #rows - 4))
  Text(L.text, Tx("ColPlayed"), 1580, 300, "label", 1.1, "c")
  Text(L.text, Tx("ColDiff"), 1680, 300, "label", 1.1, "c")
  Text(L.text, Tx("ColPoints"), 1780, 300, "label", 1.1, "c")
  for k = from, math.min(#rows, from + 4) do
    local r = rows[k]
    local y = 350 + (k - from) * 64
    local mine = r.team == Me(h)
    if mine then Quad(L.plate, ART.row_on, 1170, y - 26, 670, 52)
    elseif t.cut and k <= t.cut then Quad(L.plate, ART.row_ok, 1170, y - 26, 670, 52, 0.35) end
    Text(L.text, tostring(k), 1210, y, mine and "body_w" or "body_c", 0.9, "c")
    Crest(r.team, 1260, y, 0.6)
    Text(L.text, Fit(TeamName(r.team), 280, 28), 1292, y, mine and "item_on" or "item", 0.85)
    local diff = (r.goals_for or 0) - (r.goals_against or 0)
    Text(L.text, tostring(r.played or 0), 1580, y, mine and "body_w" or "body_c", 0.9, "c")
    Text(L.text, (diff > 0 and "+" or "") .. diff, 1680, y, mine and "body_w" or "body_c", 0.9, "c")
    Text(L.text, tostring(r.points or 0), 1780, y, mine and "body_w" or "big", 0.9, "c")
  end
end

local function NewsLines(h)
  if h.phase == "superliga" then
    local round = h.next and h.next.n or 1
    return { Tx("NewsSuperLiga1", round, h.rounds), Tx("NewsSuperLiga2", h.qualify, h.clubs) }
  elseif h.phase == "pots" then
    return { Tx("NewsPots1", h.superliga_place), Tx("NewsPots2") }
  elseif h.phase == "league" then
    if h.out then return { Tx("Out_superliga", h.superliga_place, h.qualify) } end
    return { Tx("NewsLeague1", LeagueName(h.league)), Tx("NewsLeague2") }
  elseif h.phase == "frontier" then
    return { Tx("NewsFrontier1"), Tx("Reached_" .. h.reached) }
  elseif h.phase == "worldcup" and h.worldcup then
    local w = h.worldcup
    if w.out then return { Tx("NewsWorldCupOut", TeamName(w.side)) } end
    return { Tx("NewsWorldCup1", TeamName(w.side)), Tx("NewsWorldCup2", w.sides, w.groups, w.knockout) }
  end
  if h.worldcup and (h.worldcup.champion or 0) ~= 0 then
    return { Tx("SeasonOver", h.season), Tx("WorldCupChampion", TeamName(h.worldcup.champion)) }
  end
  return { Tx("SeasonOver", h.season) }
end

-- the transfer window line: open (closes on …) or closed (opens on …); "" when no window is left this season
local function WindowLine(h)
  local w = h.days and h.days.window
  if type(w) ~= "table" then return "" end
  if w.open then return Tx("WindowOpen", DateShort(w.to)) end
  if w.from then return Tx("WindowClosed", DateShort(w.from)) end
  return ""
end

local function DrawHomePhase()
  local h = S.hub
  local teams = {}
  for _, r in ipairs(h.table and h.table.rows or {}) do teams[#teams + 1] = r.team end
  -- the club's stars among its league's clubs (kept while a World Cup group is shown)
  if (h.table or {}).kind == "group" then teams = S.club_teams or teams else S.club_teams = teams end
  NextTile(h)
  TableTile(h)
  -- form
  Tile(60, 720, 560, 250, Tx("Form"))
  local form = h.form or {}
  for k = 1, h.form_matches or 5 do
    local f = form[k]
    local art = f == "W" and ART.row_ok or (f == "L" and ART.row or ART.row_on)
    Quad(L.plate, art, 100 + (k - 1) * 96, 815, 80, 64, f and 1 or 0.35)
    Text(L.text, f and Tx("Form" .. f) or "-", 140 + (k - 1) * 96, 847, "body_w", 1, "c")
  end
  if #form == 0 then Text(L.text, Tx("NoResults"), 100, 925, "label_l", 1.2) end
  -- the club
  Tile(650, 720, 600, 250, Tx("YourClub"))
  Crest(h.team, 750, 860, 1.7)
  Text(L.text, Fit(TeamName(h.team), 380, 32), 840, 830, "body", 1.1)
  StarsRow(Stars(h.team, teams) or 0, 840, 858, 32)
  local rated = S.rate[h.team]
  Text(L.text, Tx("SeasonN", h.season) .. (rated and rated.level > 0 and ("  ·  " .. Tx("Level", rated.level)) or ""), 840, 930, "label_l", 1.2)
  -- news
  Tile(1280, 720, 580, 250, Tx("News"))
  local window = WindowLine(h)
  if window ~= "" then
    local open = h.days.window.open
    Quad(L.plate, open and ART.row_ok or ART.row, 1300, 790, 540, 46, open and 0.85 or 0.6)
    Text(L.text, Fit(window, 500, 28), 1320, 813, "body", 0.9)
  end
  for k, line in ipairs(NewsLines(h)) do
    Text(L.text, Fit(line, 520, 28), 1320, 868 + (k - 1) * 50, k == 1 and "body" or "label_l", k == 1 and 0.9 or 1.15)
  end
end

-- the calendar's month: the one picked (S.month), else the month of the next event (today's when none)
local function CalendarMonth(h)
  local months = h.days and h.days.months or {}
  if #months == 0 then return nil, months end
  if S.month == nil then
    local at = (h.days.next or h.days.today or {}).day or months[1].first
    S.month = 1
    for i, mo in ipairs(months) do
      if at >= mo.first and at < mo.first + mo.days then S.month = i end
    end
  end
  S.month = math.max(1, math.min(#months, S.month))
  return months[S.month], months
end

-- the day ranges of the hub (breaks, windows, the World Cup): whether day z is inside one
local function InSpans(spans, z)
  for _, r in ipairs(spans or {}) do
    if r.from and r.to and z >= r.from.day and z <= r.to.day then return true end
  end
  return false
end

-- a calendar's events by day: the club's matches (hub calendar entries with their date) and the draw
local function EventsByDay(h)
  local out = {}
  for _, m in ipairs(h.calendar or {}) do
    if m.date then out[m.date.day] = m end
  end
  if h.days and h.days.draw then out[h.days.draw.day] = out[h.days.draw.day] or { draw = true, date = h.days.draw } end
  return out
end

local CAL = { X = 100, Y = 340, W = 146, H = 84, STEP_X = 150, STEP_Y = 92, LIST_X = 1190, LIST_W = 640, ROWS = 9,
  LEGEND_Y = 912 }

local function DrawCalendar(h)
  local P = G.PAGE
  Tile(P.x, P.y, P.w, P.h, Tx("TabCalendar"))
  local mo, months = CalendarMonth(h)
  if mo == nil then return end
  Quad(L.icon, ART.arrow, P.x + P.w - 430, P.y + 22, 30, 34, S.month > 1 and 1 or 0.3, true)
  Text(L.text, MonthTitle(mo), P.x + P.w - 250, P.y + 39, "title_c", 0.9, "c")
  Quad(L.icon, ART.arrow, P.x + P.w - 100, P.y + 22, 30, 34, S.month < #months and 1 or 0.3)
  local days = h.days
  local events = EventsByDay(h)
  local today = days.today and days.today.day or -1
  for k = 1, 7 do
    Text(L.text, Tx("Weekday" .. k), CAL.X + (k - 1) * CAL.STEP_X + CAL.W / 2, CAL.Y - 22, "label", 1.1, "c")
  end
  local listed = {}
  for d = 1, mo.days do
    local z = mo.first + d - 1
    local col = (mo.wd - 1 + d - 1) % 7
    local row = math.floor((mo.wd - 1 + d - 1) / 7)
    local x, y = CAL.X + col * CAL.STEP_X, CAL.Y + row * CAL.STEP_Y
    local e = events[z]
    local art, alpha = ART.row, 0.55
    local cup = days.world_cup and InSpans({ days.world_cup }, z)
    if InSpans(days.windows, z) then art, alpha = ART.row_ok, 0.75
    elseif cup then art, alpha = ART.row_on, 0.55
    elseif InSpans(days.breaks, z) then art, alpha = ART.navy, 0.3 end
    if e and not e.draw and e.home ~= 0 then art, alpha = ART.row_on, 1 end
    Quad(L.plate, art, x, y, CAL.W, CAL.H, alpha)
    if z == today then Quad(L.icon, ART.row_ol, x - 4, y - 4, CAL.W + 8, CAL.H + 8) end
    local lit = art == ART.row_on and alpha == 1
    Text(L.text, tostring(d), x + 12, y + 20, lit and "item_on" or "item", 0.7)
    if e and e.draw then
      Text(L.text, Fit(Tx("DrawShort"), CAL.W - 16, 22), x + CAL.W / 2, y + 60, "label", 1, "c")
      listed[#listed + 1] = e
    elseif e and e.home ~= 0 then
      local home = e.home == Me(h)
      Crest(home and e.away or e.home, x + CAL.W - 40, y + 34, 0.5)
      local sc = Score(e)
      Text(L.text, sc ~= "" and (e.hg .. "-" .. e.ag) or (home and Tx("HomeShort") or Tx("AwayShort")), x + 12 + 26,
        y + 62, "body_w", 0.75, "c")
      listed[#listed + 1] = e
    elseif e then
      Text(L.text, Fit(RoundName(e.label, e.n, true), CAL.W - 16, 22), x + CAL.W / 2, y + 60, "label", 0.95, "c")
      listed[#listed + 1] = e
    elseif cup then
      Text(L.text, Fit(Tx("LegendWorldCup"), CAL.W - 16, 22), x + CAL.W / 2, y + 60, "body_w", 0.7, "c")
    end
  end
  -- the legend
  local lx, ly = CAL.X, CAL.LEGEND_Y
  for _, it in ipairs({ { ART.row_on, 1, "LegendMatch" }, { ART.row_ok, 0.75, "LegendWindow" },
    { ART.row_on, 0.55, "LegendWorldCup" }, { ART.navy, 0.3, "LegendBreak" }, { ART.row_ol, 1, "LegendToday" } }) do
    Quad(it[1] == ART.row_ol and L.icon or L.plate, it[1], lx, ly - 14, 40, 28, it[2])
    Text(L.text, Tx(it[3]), lx + 52, ly, "label_l", 1.05)
    lx = lx + 212
  end
  -- the month's events listed
  local X, W = CAL.LIST_X, CAL.LIST_W
  Text(L.text, Tx("MonthEvents", Tx("Month" .. mo.m)), X + 20, CAL.Y - 22, "label_l", 1.1)
  if #listed == 0 then
    Text(L.text, Tx("NoEventsMonth"), X + W / 2, CAL.Y + 60, "dim", 0.9, "c")
  end
  for k, e in ipairs(listed) do
    if k > CAL.ROWS then break end
    local y = CAL.Y + (k - 1) * 66
    local now = e.current
    Quad(L.plate, ART.row, X, y, W, 58)
    if now then Quad(L.icon, ART.row_ol, X, y, W, 58) end
    Text(L.text, Tx("Weekday" .. e.date.wd) .. " " .. e.date.d, X + 16, y + 29, "item", 0.8)
    if e.draw then
      Text(L.text, Fit(Tx("DrawTitle"), W - 160, 28), X + 140, y + 29, "item", 0.8)
    else
      Text(L.text, Fit(RoundName(e.label, e.n, true), 150, 28), X + 120, y + 29, "item", 0.75)
      if e.home ~= 0 then
        local home = e.home == Me(h)
        local rival = home and e.away or e.home
        Crest(rival, X + 300, y + 29, 0.55)
        Text(L.text, Fit(TeamName(rival), 230, 28), X + 330, y + 29, "item", 0.75)
        local sc = Score(e)
        Text(L.text, sc ~= "" and sc or (home and Tx("HomeShort") or Tx("AwayShort")), X + W - 50, y + 29, "big", 0.8,
          "c")
      else
        Text(L.text, Tx("ToBeDrawn"), X + 300, y + 29, "dim", 0.8)
      end
    end
  end
end

local function DrawStandings(h, t)
  local P = G.PAGE
  local rows = t.rows or {}
  CompetitionHeader(t, true)
  local per = h.table_rows or 20
  local pages = math.max(1, math.ceil(#rows / per))
  S.tpage = math.max(1, math.min(pages, S.tpage))
  if pages > 1 then Text(L.text, Tx("Page", S.tpage, pages), P.x + P.w - 720, P.y + 39, "title_c", 0.8, "c") end
  local y0 = P.y + 96
  Text(L.text, Tx("ColTeam"), P.x + 140, y0, "label_l", 1.1)
  for k, key in ipairs(COL_TEXT) do Text(L.text, Tx(key), COL_X[k], y0, "label", 1.1, "c") end
  for i = 1, per do
    local k = (S.tpage - 1) * per + i
    local r = rows[k]
    if r == nil then break end
    local y = y0 + 34 + (i - 1) * G.TABLE_STEP
    local mine = r.team == Me(h)
    if mine then Quad(L.plate, ART.row_on, P.x + 30, y - 16, P.w - 60, 32)
    elseif (t.kind == "league" or t.kind == "group") and k <= (t.direct or 0) then Quad(L.plate, ART.row_ok, P.x + 30, y - 16, P.w - 60, 32, 0.5)
    elseif t.cut and k <= t.cut then Quad(L.plate, ART.row_ok, P.x + 30, y - 16, P.w - 60, 32, 0.22) end
    if t.cut and k == t.cut and k < #rows then
      Quad(L.icon, ART.row_ol, P.x + 30, y + 14, P.w - 60, 4)
      local cut = t.kind == "league" and "CutFrontier" or (t.kind == "group" and "CutGroup" or "CutSuperLiga")
      Text(L.text, Tx(cut), P.x + 860, y + 16, "label", 0.95, "c")
    end
    Text(L.text, tostring(k), P.x + 70, y, mine and "body_w" or "body_c", 0.8, "c")
    Crest(r.team, P.x + 110, y, G.TABLE_SCALE)
    Text(L.text, Fit(TeamName(r.team), COL_X[1] - P.x - 260, 26), P.x + 140, y, mine and "item_on" or "item", 0.8)
    local diff = (r.goals_for or 0) - (r.goals_against or 0)
    local vals = { r.played, r.won, r.drawn, r.lost, r.goals_for, r.goals_against, (diff > 0 and "+" or "") .. diff, r.points }
    for c = 1, #COLS do
      Text(L.text, tostring(vals[c] or 0), COL_X[c], y, mine and "body_w" or (c == #COLS and "big" or "body_c"), 0.8, "c")
    end
  end
end

-- the framework's bracket screen (VRFW_Bracket of its menu _all), nil before it is defined
local function TreeMenu()
  return type(VRFW_Bracket) == "table" and VRFW_Bracket or nil
end

-- the bracket screen closed (another tab, page or dialog, the screen leaving)
local function TreeHide(why)
  if S.tree == nil then return end
  S.tree = nil
  local tm = TreeMenu()
  if tm then tm.Hide(why) end
end

-- the World Cup's groups together: every group a small table in a grid (position, crest, side, played, goal
-- difference, points); `direct` places of each group always go through, the places up to `cut` may
local function DrawGroups(h, t)
  local P = G.PAGE
  CompetitionHeader(t, true)
  local groups = t.groups or {}
  local n = #groups
  if n == 0 then return end
  local cols = math.max(2, math.ceil(math.sqrt(n)))
  local lines = math.ceil(n / cols)
  local cw = (P.w - 60 - (cols - 1) * GROUPS.GAP_X) / cols
  local ch = (P.h - GROUPS.TOP - 20 - (lines - 1) * GROUPS.GAP_Y) / lines
  local most = 1
  for _, g in ipairs(groups) do most = math.max(most, #(g.rows or {})) end
  local step = math.min(GROUPS.STEP_MAX, (ch - GROUPS.HEAD) / most)
  local crest = math.min(GROUPS.CREST_MAX, step / 80)
  for i, g in ipairs(groups) do
    local x = P.x + 30 + ((i - 1) % cols) * (cw + GROUPS.GAP_X)
    local y = P.y + GROUPS.TOP + math.floor((i - 1) / cols) * (ch + GROUPS.GAP_Y)
    local col_played, col_diff, col_points = x + cw - 175, x + cw - 110, x + cw - 45
    local head_y = y + (GROUPS.HEAD - 8) / 2
    Quad(L.plate, ART.row, x, y, cw, GROUPS.HEAD - 8, 0.8)
    Text(L.text, Tx("GroupTitle", string.char(64 + (g.group or i))), x + 20, head_y, "label_l", 1.05)
    Text(L.text, Tx("ColPlayed"), col_played, head_y, "label", 0.95, "c")
    Text(L.text, Tx("ColDiff"), col_diff, head_y, "label", 0.95, "c")
    Text(L.text, Tx("ColPoints"), col_points, head_y, "label", 0.95, "c")
    for k, r in ipairs(g.rows or {}) do
      local ry = y + GROUPS.HEAD + (k - 0.5) * step
      local mine = r.team == Me(h)
      if mine then Quad(L.plate, ART.row_on, x, ry - step / 2 + 2, cw, step - 4)
      elseif k <= (t.direct or 0) then Quad(L.plate, ART.row_ok, x, ry - step / 2 + 2, cw, step - 4, 0.5)
      elseif k <= (t.cut or 0) then Quad(L.plate, ART.row_ok, x, ry - step / 2 + 2, cw, step - 4, 0.22) end
      Text(L.text, tostring(k), x + 40, ry, mine and "body_w" or "body_c", 0.8, "c")
      Crest(r.team, x + 82, ry, crest)
      Text(L.text, Fit(TeamName(r.team), col_played - x - 145, 26), x + 112, ry, mine and "item_on" or "item", 0.8)
      local diff = (r.goals_for or 0) - (r.goals_against or 0)
      Text(L.text, tostring(r.played or 0), col_played, ry, mine and "body_w" or "body_c", 0.8, "c")
      Text(L.text, (diff > 0 and "+" or "") .. diff, col_diff, ry, mine and "body_w" or "body_c", 0.8, "c")
      Text(L.text, tostring(r.points or 0), col_points, ry, mine and "body_w" or "big", 0.8, "c")
    end
  end
end

-- a knockout (the Fútbol Frontier's or the World Cup's): the competition header, the framework's bracket screen
-- below it, opened once (and again for the other knockout or when the hub's data changed)
local function DrawBracket(h, t)
  local tm = TreeMenu()
  local view = BRACKET.VIEW[t.tree or ""]
  if tm == nil or view == nil then
    CompetitionHeader(t, true)
    if not S.tree_missing then
      S.tree_missing = true
      Log("bracket: no bracket screen (VRFW_Bracket " .. tostring(tm ~= nil) .. ", knockout " .. tostring(t.tree) .. ")")
    end
    return
  end
  CompetitionHeader(t)
  S.tree_frame = true
  if S.tree ~= view then
    if S.tree then TreeHide("the other knockout") end
    S.tree = view
    tm.Show(0, { host = MENU, view = Crc(view), top = BRACKET.TOP + BRACKET.HEAD_H, lift = BRACKET.LIFT })
  end
end

-- the World Cup's pages: 1 = its groups, 2 = its knockout (once drawn)
local function WorldCupPages(t)
  return t.knockout and 2 or 1
end

-- the «Competición» tab: the competition shown as a table, a knockout or the World Cup (its groups' grid or its
-- knockout, up / down)
local function DrawCompetition(h)
  local t = TableNow()
  if t.kind == "bracket" then DrawBracket(h, t)
  elseif t.kind == "worldcup" then
    S.tpage = math.max(1, math.min(WorldCupPages(t), S.tpage))
    if S.tpage == 2 then DrawBracket(h, { kind = "worldcup", tree = "worldcup" }) else DrawGroups(h, t) end
  else DrawStandings(h, t) end
  return t
end

local function DrawSquad(h)
  local P = G.PAGE
  Tile(P.x, P.y, P.w, P.h, Tx("TabSquad"))
  local players = Players(h.team)
  if players == nil then return end
  local signed = {}
  for _, p in ipairs(h.squad or {}) do
    if p.signed then signed[p.card] = true end
  end
  table.sort(players, function(a, b)
    local sa, sb = a.place >= 0 and a.place or 99, b.place >= 0 and b.place or 99
    if sa ~= sb then return sa < sb end
    return a.rating > b.rating
  end)
  local y0 = P.y + 96
  Text(L.text, Tx("ColPlayer"), P.x + 190, y0, "label_l", 1.1)
  Text(L.text, Tx("ColPos"), 1000, y0, "label", 1.1, "c")
  Text(L.text, Tx("ColLevel"), 1150, y0, "label", 1.1, "c")
  Text(L.text, Tx("ColRating"), 1300, y0, "label", 1.1, "c")
  Text(L.text, Tx("Starters") .. " · " .. Tx("Bench"), P.x + P.w - 200, y0, "label", 1.1, "c")
  local starters = S.rules.starter_places
  for k, p in ipairs(players) do
    if k > 18 then break end
    local y = y0 + 44 + (k - 1) * 35
    Quad(L.plate, (p.place >= 0 and p.place < starters) and ART.row or ART.row_ol, P.x + 30, y - 16, P.w - 60, 32)
    Text(L.text, tostring(p.number), P.x + 70, y, "body_c", 0.85, "c")
    Face(p.card, P.x + 130, y, 32, h.team)
    Text(L.text, Fit(p.name ~= "" and p.name or "-", 700, 28), P.x + 190, y, "body", 0.85)
    Text(L.text, Tx(POS_TEXT[p.position] or "PosMF"), 1000, y, "body_c", 0.85, "c")
    Text(L.text, tostring(p.level), 1150, y, "body_c", 0.85, "c")
    Text(L.text, tostring(p.rating), 1300, y, "big", 0.85, "c")
    if signed[p.card] then Text(L.text, Tx("Signed"), P.x + P.w - 200, y, "label", 0.95, "c") end
  end
end

local function DrawHub()
  local h = S.hub
  TabBar()
  local tab = Tabs()[S.tab] or {}
  local keys = { Tx("KeyAccept"), Tx("KeyBack"), Tx("KeyTab") }
  if tab.id == "home" then
    DrawHomePhase()
    if h.next and h.next.kind == "match" then keys[#keys + 1] = Tx("KeySim") end
  elseif tab.id == "calendar" then
    DrawCalendar(h)
    keys[#keys + 1] = Tx("KeyMonth")
  elseif tab.id == "competition" then
    local t = DrawCompetition(h)
    if (h.tables or 1) > 1 then keys[#keys + 1] = Tx("KeyCompetition") end
    if t.kind == "worldcup" then
      if WorldCupPages(t) > 1 then keys[#keys + 1] = Tx("KeyWorldCupPage") end
    elseif t.kind ~= "bracket" then keys[#keys + 1] = Tx("KeyPageUpDown") end
  elseif tab.id == "squad" then
    DrawSquad(h)
    if h.callup then keys[#keys + 1] = Tx("KeyCallUp") end
  else
    local P = G.PAGE
    Tile(P.x, P.y, P.w, P.h, Tx(tab.text or ""))
    Text(L.text, Tx("ComingSoon"), P.x + P.w / 2, P.y + P.h / 2, "body_c", 1.1, "c")
  end
  Footer(keys)
end

-- ---- the draw of the leagues -------------------------------------------------------------------------------------------

-- ball k (1-based) = pot ceil(k / leagues), league (k - 1) % leagues + 1
local function PotsTotal(p)
  return #p.pots * #p.leagues
end

local function DrawPots()
  local p = S.pots
  local nl = #p.leagues
  local drawn = p.drawn
  Text(L.text, Tx("DrawTitle"), 960, 150, "outline_c", 1.3, "c")
  -- the pots: 2 rows, each pot a tile with its clubs (drawn ones dimmed)
  local per_row = math.ceil(#p.pots / 2)
  local pw, ph = 250, 150
  for k, pot in ipairs(p.pots) do
    local col, row = (k - 1) % per_row, math.floor((k - 1) / per_row)
    local x, y = 60 + col * (pw + 10), 200 + row * (ph + 14)
    Quad(L.panel, ART.white, x, y, pw, ph)
    Text(L.text, Tx("Pot", k), x + 16, y + 22, "label_l", 1.05)
    for i, t in ipairs(pot) do
      local cx, cy = x + 40 + ((i - 1) % 2) * 120, y + 62 + math.floor((i - 1) / 2) * 52
      local gone = false
      for b = 1, drawn do
        local bp, bl = math.ceil(b / nl), (b - 1) % nl + 1
        if bp == k and p.leagues[bl][k] == t then gone = true end
      end
      Crest(t, cx, cy, 0.62, gone and 0.25 or 1)
    end
  end
  -- the leagues: one column each, its clubs in pot order
  local lw = (1800 - (nl - 1) * 20) / nl
  for l = 1, nl do
    local x, y = 60 + (l - 1) * (lw + 20), 540
    Quad(L.panel, ART.white, x, y, lw, 460)
    Quad(L.panel, ART.band, x + 10, y + 10, lw - 20, 46)
    Text(L.text, LeagueName(l), x + lw / 2, y + 33, "title_c", 0.85, "c")
    for k = 1, #p.pots do
      local b = (k - 1) * nl + l
      local t = p.leagues[l][k]
      local cx, cy = x + 40 + ((k - 1) % 2) * (lw / 2), y + 90 + math.floor((k - 1) / 2) * 52
      if b <= drawn then
        if t == p.team then Quad(L.plate, ART.row_on, cx - 30, cy - 22, lw / 2 - 20, 44, 0.9) end
        Crest(t, cx, cy, 0.55)
        Text(L.text, Fit(TeamName(t), lw / 2 - 90, 22), cx + 30, cy, t == p.team and "item_on" or "item", 0.62)
      else
        Text(L.text, "?", cx, cy, "dim", 0.9, "c")
      end
    end
  end
  -- the ball just drawn: big over the middle
  if drawn > 0 and drawn <= PotsTotal(p) then
    local bp, bl = math.ceil(drawn / nl), (drawn - 1) % nl + 1
    local t = p.leagues[bl][bp]
    if p.flash > 0 then
      Quad(L.icon, ART.navy, 960 - 260, 380, 520, 140, 0.92)
      Crest(t, 960 - 170, 450, 1.4)
      Text(L.text, Fit(TeamName(t), 300, 32), 960 - 100, 430, "outline", 1)
      Text(L.text, LeagueName(bl), 960 - 100, 478, "outline", 0.9)
    end
  end
  local done = drawn >= PotsTotal(p)
  Footer({ done and Tx("KeyStartLeagues") or Tx("KeyDrawBall"), done and Tx("KeyBack") or Tx("KeyDrawAll") })
end

-- the call-up: the players by position (goalkeepers first), the side's own roster before its other versions'
local WC = { PER_COLUMN = 12, COLUMNS = 2, X = 100, Y = 300, STEP = 54, ROW_H = 48, COL_W = 840, COL_GAP = 40 }
local POS_ORDER = { [1] = 1, [4] = 2, [3] = 3, [2] = 4 }

local function WcList()
  local v = S.wc
  if v.sorted == nil then
    local list = {}
    for i, p in ipairs(v.players or {}) do list[i] = { p = p, i = i } end
    table.sort(list, function(a, b)
      local pa, pb = POS_ORDER[a.p.position] or 5, POS_ORDER[b.p.position] or 5
      if pa ~= pb then return pa < pb end
      return a.i < b.i
    end)
    v.sorted = {}
    for i, x in ipairs(list) do v.sorted[i] = x.p end
  end
  return v.sorted
end

local function DrawWcSquad()
  local v = S.wc
  local list = WcList()
  local per = WC.PER_COLUMN * WC.COLUMNS
  local pages = math.max(1, math.ceil(#list / per))
  S.wc_sel = math.max(1, math.min(#list, S.wc_sel or 1))
  local page = math.floor((S.wc_sel - 1) / per)
  Tile(60, 140, 1800, 860, Tx("WorldCupSquadTitle", TeamName(v.side)))
  Crest(v.side, 1780, 179, 0.7)
  local full = v.picked == v.size
  Text(L.text, Tx("WorldCupCount", v.picked, v.size), 100, 236, full and "body" or "big", 1)
  Text(L.text, Tx("WorldCupKeepers", v.goalkeepers, v.keepers), 520, 236, "body", 1)
  if pages > 1 then Text(L.text, Tx("Page", page + 1, pages), 1700, 236, "body_c", 0.9, "c") end
  if S.wc_refused then Text(L.text, Tx("WorldCupNeedFull", v.size, v.keepers), 1000, 236, "dim", 0.9) end
  for k = 1, per do
    local idx = page * per + k
    local p = list[idx]
    if p == nil then break end
    local col, row = math.floor((k - 1) / WC.PER_COLUMN), (k - 1) % WC.PER_COLUMN
    local x, y = WC.X + col * (WC.COL_W + WC.COL_GAP), WC.Y + row * WC.STEP
    local on = idx == S.wc_sel
    Quad(L.plate, p.picked and ART.row_on or ART.row, x, y - WC.ROW_H / 2, WC.COL_W, WC.ROW_H)
    if on then Quad(L.icon, ART.row_ol, x, y - WC.ROW_H / 2, WC.COL_W, WC.ROW_H) end
    local style = p.picked and "item_on" or "item"
    Text(L.text, tostring(p.number or ""), x + 56, y, p.picked and "body_w" or "body_c", 0.8, "c")
    Face(p.card, x + 112, y, 40, v.side)
    Text(L.text, Fit(p.name ~= "" and p.name or "-", 400, 28), x + 150, y, style, 0.8)
    Text(L.text, Tx(POS_TEXT[p.position] or "PosMF"), x + 600, y, p.picked and "body_w" or "body_c", 0.8, "c")
    if p.picked then Text(L.text, Tx("Called"), x + 710, y, "body_w", 0.75, "c") end
    if (p.team or 0) ~= 0 and p.team ~= v.side then Crest(p.team, x + WC.COL_W - 52, y, 0.42) end
  end
  Footer({ Tx("KeyToggle"), Tx("KeyConfirmSquad"), Tx("KeyBack") })
end

local function Draw()
  BeginFrame()
  S.tree_frame = false
  if S.ready then
    if S.mode == "home" then DrawHome()
    elseif S.mode == "pick" and S.draw then DrawPick()
    elseif S.mode == "hub" and S.hub then DrawHub()
    elseif S.mode == "pots" and S.pots then DrawPots()
    elseif S.mode == "wcsquad" and S.wc then DrawWcSquad() end
    Dialog()
  end
  EndFrame()
  if not S.tree_frame or S.dialog then TreeHide("the knockout left") end
end

-- ---- data and flow -----------------------------------------------------------------------------------------------------

-- ask for data until the scripts answer: kind "state" | "draw" | "hub" | "standings" | "start" | "rosters" | "play" |
-- "sim" | "pots" | "advance"
local function Want(kind, arg)
  S.want = { kind = kind, arg = arg, tries = 0 }
end

-- a club's players (names, positions) for its card: asked without holding the keys
local function FetchClub()
  local team = S.club_want
  if team == nil then return end
  local v = Call("CMND_CAREERMODE_CLUB", team, Lang())
  if v == nil then return end
  S.club_want = nil
  S.clubs[team] = v.ok and v or { players = {} }
  S.dirty = true
end

-- the career squads written into the clubs' roster rows, a few clubs a Step (before their stats are read)
local function ApplySome()
  for _ = 1, APPLY_PER_STEP do
    local a = table.remove(S.apply, 1)
    if a == nil then return end
    local ok, done, why = pcall(funcLuaCommand, Crc("CMND_VRFW_TEAM_ROSTER"), a.team, table.unpack(a.rows))
    S.applied[a.team] = true
    if not ok or done ~= true then Log("squad of", a.team, "not written:", tostring(ok and why or done)) end
  end
end

-- the data's roster rows and the slot teams back (the player leaves the mode)
local function RestoreRosters()
  pcall(funcLuaCommand, Crc("CMND_VRFW_TEAM_ROSTER_RESTORE"), 0)
  pcall(funcLuaCommand, Crc("CMND_VRFW_TEAM_STAND_IN_RESTORE"), 0)
  S.applied = {}
end

local function HubEntered(v)
  S.hub, S.mode, S.page, S.table, S.month = v, "hub", 1, nil, nil
  if S.tree then S.tree = false end   -- the bracket drawn again with the new data (any value but a view name)
  S.rules = v.rating or S.rules
  S.tab = math.max(1, math.min(S.tab, #(v.tabs or {})))
  S.tindex, S.tpage = v.table_index or 1, 1
  -- the page of the competition's table that holds the club; the World Cup: its knockout once drawn
  if v.competition and v.competition.kind == "worldcup" and v.competition.knockout then S.tpage = 2 end
  for k, r in ipairs(v.competition and v.competition.rows or {}) do
    if r.team == v.team then S.tpage = math.floor((k - 1) / (v.table_rows or 20)) + 1 end
  end
  S.clubs[v.team] = { players = v.squad or {} }
  local teams = {}
  for _, r in ipairs(v.table and v.table.rows or {}) do teams[#teams + 1] = r.team end
  if S.rate[v.team] == nil then table.insert(S.queue, 1, v.team) end
  Queue(teams)
end

-- slot team `key` stands in for `team` with `cards` (CMND_VRFW_TEAM_STAND_IN) -> the team the match plays: the slot
-- team, else the club itself
local function StandIn(key, team, cards)
  if type(key) ~= "string" or key == "" or type(cards) ~= "table" or #cards == 0 then return team end
  local slot = Crc(key)
  local ok, done, why = pcall(funcLuaCommand, Crc("CMND_VRFW_TEAM_STAND_IN"), slot, team, table.unpack(cards))
  if ok and done == true then return slot end
  Log("stand-in", key, "for", team, "failed:", tostring(ok and why or done))
  return team
end

-- the club's match: VRFW_MATCH.start with both career clubs (content\friendlies\career.toml)
local function StartMatch(v)
  if type(VRFW_MATCH) ~= "table" or type(VRFW_MATCH.start) ~= "function" then
    Snd(SND.BUZZER)
    Log("no match start service in this menu")
    Call("CMND_CAREERMODE_DISARM")
    return
  end
  local game = type(v.game) == "string" and Crc(v.game) or v.game
  local me = v.user or (S.hub and S.hub.team) or 0
  -- both clubs play through the slot teams with their match squads (bench included); a club whose stand-in
  -- fails plays as itself (its own rows)
  local user, rival = StandIn(v.user_team, me, v.user_cards), StandIn(v.rival_team, v.rival, v.rival_cards)
  S.match = true
  local ok, started, why = pcall(VRFW_MATCH.start, { friendly = v.friendly, game = game, difficulty = v.difficulty,
    rival = v.host, overrides = { { "teams.rival.team", rival }, { "teams.user.team", user } }, settle = 0, black = false,
    on_failed = function(reason)
      S.match = false
      Call("CMND_CAREERMODE_DISARM")
      Log("match start failed:", tostring(reason))
    end })
  Log("match", tostring(v.home), "-", tostring(v.away), "start", tostring(ok), tostring(started), tostring(why))
  if not (ok and started) then
    S.match = false
    Snd(SND.BUZZER)
    Call("CMND_CAREERMODE_DISARM")
  end
end

local function Fetch()
  local w = S.want
  if w == nil then return end
  local v
  if w.kind == "state" then v = Call("CMND_CAREERMODE_STATE")
  elseif w.kind == "draw" then v = Call("CMND_CAREERMODE_DRAW")
  elseif w.kind == "hub" then v = Call("CMND_CAREERMODE_HUB", Lang())
  elseif w.kind == "standings" then v = Call("CMND_CAREERMODE_STANDINGS", w.arg)
  elseif w.kind == "start" then v = Call("CMND_CAREERMODE_START", w.arg)
  elseif w.kind == "rosters" then v = Call("CMND_CAREERMODE_ROSTERS")
  elseif w.kind == "play" then v = Call("CMND_CAREERMODE_PLAY")
  elseif w.kind == "sim" then v = Call("CMND_CAREERMODE_SIM")
  elseif w.kind == "pots" then v = Call("CMND_CAREERMODE_POTS")
  elseif w.kind == "advance" then v = Call("CMND_CAREERMODE_ADVANCE")
  elseif w.kind == "clubpool" then v = Call("CMND_CAREERMODE_CLUB_CALLUP", Lang())
  elseif w.kind == "clubpick" then v = Call("CMND_CAREERMODE_CLUB_CALLUP_PICK", w.arg, Lang())
  elseif w.kind == "clubconfirm" then v = Call("CMND_CAREERMODE_CLUB_CALLUP_CONFIRM")
  elseif w.kind == "wcpool" then v = Call("CMND_CAREERMODE_WC_POOL", Lang())
  elseif w.kind == "wcpick" then v = Call("CMND_CAREERMODE_WC_PICK", w.arg, Lang())
  elseif w.kind == "wcconfirm" then v = Call("CMND_CAREERMODE_WC_CONFIRM") end
  if v == nil then
    w.tries = w.tries + 1
    if w.tries == 300 then Log("no answer to", w.kind, "after 300 frames") end
    return
  end
  S.want = nil
  S.dirty = true
  if w.kind == "state" then
    S.state = v
    S.mode, S.sel = "home", 1
    Log("open: clubs", v.clubs, "career", v.career ~= nil, v.why ~= "" and v.why or "")
    -- back from a match of the club: straight to the hub
    if v.career and v.career.fresh then Want("rosters", "hub") end
  elseif w.kind == "draw" then
    if v.ok then
      S.draw, S.mode = v, "pick"
      S.rules = v.rating or S.rules
      S.pick.league = math.min(S.pick.league, #v.leagues)
      S.pick.sel = 1
      S.queue, S.rate, S.clubs = {}, {}, {}
      Want("rosters", "pick")
    else
      Snd(SND.BUZZER)
      Log("club pick refused:", v.why)
      S.mode = "home"
    end
  elseif w.kind == "rosters" then
    RestoreRosters()
    S.apply = {}
    for _, t in ipairs(v.teams or {}) do S.apply[#S.apply + 1] = { team = t.team, rows = t.rows or {} } end
    Log("career squads:", #S.apply, "club(s) to write")
    if w.arg == "pick" then PickFocus() else Want("hub") end
  elseif w.kind == "start" then
    if v.ok then
      Want("rosters", "hub")
      S.rate, S.clubs, S.queue = {}, {}, {}
    else
      Snd(SND.BUZZER)
      Log("start refused:", v.why)
    end
  elseif w.kind == "hub" then
    if v.ok then
      HubEntered(v)
      if v.phase == "pots" and S.after_hub == "pots" then Want("pots") end
      S.after_hub = nil
    else
      Log("hub refused:", v.why)
      S.mode = "home"
    end
  elseif w.kind == "standings" then
    if v.ok then
      S.table, S.tindex, S.tpage = v, v.index, 1
      if v.table and v.table.kind == "worldcup" and v.table.knockout then S.tpage = 2 end
      for k, r in ipairs(v.table and v.table.rows or {}) do
        if r.team == S.hub.team then S.tpage = math.floor((k - 1) / (S.hub.table_rows or 20)) + 1 end
      end
    end
  elseif w.kind == "play" then
    if v.ok then StartMatch(v) else
      Snd(SND.BUZZER)
      Log("play refused:", v.why)
    end
  elseif w.kind == "sim" then
    if v.ok then Want("hub") else Snd(SND.BUZZER) end
  elseif w.kind == "pots" then
    if v.ok then
      S.pots, S.mode = { pots = v.pots, leagues = v.leagues, team = v.team, drawn = 0, flash = 0 }, "pots"
    else
      Snd(SND.BUZZER)
    end
  elseif w.kind == "advance" then
    S.mode = "hub"
    S.tab = 1
    Want("hub")
  elseif w.kind == "wcpool" or w.kind == "wcpick" or w.kind == "clubpool" or w.kind == "clubpick" then
    if v.ok then
      S.wc, S.mode = v, "wcsquad"
      if w.kind == "wcpool" or w.kind == "clubpool" then S.wc_sel, S.wc_refused = 1, false end
    else
      Snd(SND.BUZZER)
      Log("call-up refused:", v.why)
      Want("hub")
    end
  elseif w.kind == "wcconfirm" or w.kind == "clubconfirm" then
    if v.ok then
      S.wc, S.mode = nil, "hub"
      if w.kind == "wcconfirm" then S.tab = 1 end
      Want("hub")
    else
      Snd(SND.BUZZER)
      S.wc_refused = true
      Log("call-up not confirmed:", v.why)
    end
  end
end

-- leave the screen: the data's rosters back unless a match of the career starts
local function Close()
  if S.closing then return end
  S.closing = true
  TreeHide("the screen closes")
  if not S.match then RestoreRosters() end
  M(C.INPUT, MENU, false)
  pcall(funcLuaCommand, C.CLOSE_MENU, MENU)
  Log("closed")
end

local function Accept()
  if S.want ~= nil or S.match then return end
  if S.dialog then
    local d = S.dialog
    S.dialog = nil
    Snd(SND.DECIDE)
    if d.kind == "start" then Want("start", d.team)
    elseif d.kind == "replace" then Want("draw") end
    S.dirty = true
    return
  end
  if S.mode == "home" then
    local it = HomeItems()[S.sel]
    if it == nil then return end
    if it.off then Snd(SND.BUZZER) return end
    Snd(SND.DECIDE)
    if it.id == "continue" then Want("rosters", "hub")
    elseif it.id == "new" then
      if S.state and S.state.career then
        S.dialog = { kind = "replace", title = Tx("NewCareer"), lines = { Tx("ReplaceLine1"), Tx("ReplaceLine2") } }
      else
        Want("draw")
      end
    elseif it.id == "exit" then Close() end
  elseif S.mode == "pick" then
    local team = PickTeams()[S.pick.sel]
    if team == nil then return end
    Snd(SND.DECIDE)
    S.dialog = { kind = "start", team = team, title = Tx("StartTitle"),
      lines = { Tx("StartLine1", TeamName(team)), Tx("StartLine2", S.draw.clubs, S.draw.rounds) } }
  elseif S.mode == "hub" then
    local tab = Tabs()[S.tab] or {}
    local n = S.hub.next or {}
    if tab.id == "squad" and S.hub.callup then
      Snd(SND.DECIDE)
      Want("clubpool")
      S.dirty = true
      return
    end
    if tab.id ~= "home" then Snd(SND.BUZZER) return end
    Snd(SND.DECIDE)
    if n.kind == "match" then Want("play")
    elseif n.kind == "round" then Want("sim")
    elseif n.kind == "draw" then Want("pots")
    elseif n.kind == "wc_call" then Want("wcpool")
    elseif n.kind == "over" then Want("advance") end
  elseif S.mode == "wcsquad" and S.wc then
    local p = WcList()[S.wc_sel or 1]
    if p == nil then return end
    if not p.picked and S.wc.picked >= S.wc.size then Snd(SND.BUZZER) return end
    Snd(SND.DECIDE)
    S.wc_refused = false
    Want(S.wc.kind == "club" and "clubpick" or "wcpick", p.card)
  elseif S.mode == "pots" then
    local p = S.pots
    if p.drawn >= PotsTotal(p) then
      Snd(SND.DECIDE)
      Want("advance")
    else
      Snd(SND.MOVE)
      p.drawn, p.flash = p.drawn + 1, 45
    end
  end
  S.dirty = true
end

-- Y: simulate the club's match (hub) / draw every ball left (the draw of the leagues)
local function Second()
  if S.want ~= nil or S.dialog or S.match then return end
  if S.mode == "hub" and S.hub and (Tabs()[S.tab] or {}).id == "home" and S.hub.next and S.hub.next.kind == "match" then
    Snd(SND.DECIDE)
    Want("sim")
  elseif S.mode == "pots" and S.pots then
    Snd(SND.DECIDE)
    S.pots.drawn, S.pots.flash = PotsTotal(S.pots), 0
  elseif S.mode == "wcsquad" and S.wc then
    Snd(SND.DECIDE)
    Want(S.wc.kind == "club" and "clubconfirm" or "wcconfirm")
  else
    return
  end
  S.dirty = true
end

local function Back()
  if S.want ~= nil or S.match then return end
  Snd(SND.BACK)
  if S.dialog then S.dialog = nil
  elseif S.mode == "pots" then Want("hub")
  elseif S.mode == "wcsquad" then
    S.wc = nil
    Want("hub")
  elseif S.mode == "pick" or S.mode == "hub" then Want("state")
  else Close() end
  S.dirty = true
end

local function Move(dx, dy)
  if S.want ~= nil or S.dialog or S.match then return end
  if S.mode == "home" then
    if dy == 0 then return end
    S.sel = math.max(1, math.min(#HomeItems(), S.sel + dy))
  elseif S.mode == "wcsquad" and S.wc then
    local n = #WcList()
    if n == 0 then return end
    -- up / down: the next row; left / right: the other column
    local step = dy ~= 0 and dy or dx * WC.PER_COLUMN
    S.wc_sel = math.max(1, math.min(n, (S.wc_sel or 1) + step))
  elseif S.mode == "pick" then
    local n = #PickTeams()
    if dx == 0 or n == 0 then return end
    S.pick.sel = (S.pick.sel - 1 + dx) % n + 1
    PickFocus()
  elseif S.mode == "hub" then
    local tab = Tabs()[S.tab] or {}
    if tab.id == "calendar" and (dx ~= 0 or dy ~= 0) then
      local n = #(S.hub.days and S.hub.days.months or {})
      local to = math.max(1, math.min(n, (S.month or 1) + dx + dy))
      if to == S.month then return end
      S.month = to
    elseif tab.id == "competition" and dx ~= 0 then
      if (S.hub.tables or 1) < 2 then return end
      Want("standings", (S.tindex - 1 + dx) % math.max(1, S.hub.tables or 1) + 1)
    elseif tab.id == "competition" and dy ~= 0 then
      S.tpage = S.tpage + dy
    else
      return
    end
  else
    return
  end
  Snd(SND.MOVE)
  S.dirty = true
end

-- L1 / R1: the game on the club pick, the tab on the hub
local function Turn(d)
  if S.want ~= nil or S.dialog or S.match then return end
  if S.mode == "pick" and S.draw then
    local n = #S.draw.leagues
    S.pick.league = (S.pick.league - 1 + d) % n + 1
    S.pick.sel = 1
    S.queue = {}
    PickFocus()
  elseif S.mode == "hub" and S.hub then
    local n = #Tabs()
    if n <= 1 then return end
    S.tab = (S.tab - 1 + d) % n + 1
    S.page, S.month = 1, nil
  else
    return
  end
  Snd(SND.MOVE)
  S.dirty = true
end

-- ---- menu callbacks ----------------------------------------------------------------------------------------------------

local FN = {}

function OnInit()
  MENU = Crc("evt_career_menu")
  L = { panel = Crc("career_panel"), plate = Crc("career_plate"), icon = Crc("career_icon"), team = Crc("career_team"),
    face = Crc("career_face"), text = Crc("career_text"), dialog = Crc("career_dialog"),
    dtext = Crc("career_dialog_text") }
  FN = { [Crc("career_accept")] = Accept, [Crc("career_up")] = function() Move(0, -1) end,
    [Crc("career_down")] = function() Move(0, 1) end, [Crc("career_left")] = function() Move(-1, 0) end,
    [Crc("career_right")] = function() Move(1, 0) end, [Crc("career_prev")] = function() Turn(-1) end,
    [Crc("career_next")] = function() Turn(1) end, [Crc("career_redraw")] = Second }
  S.ready, S.frame, S.dirty, S.mode, S.closing, S.match = false, 0, true, "loading", false, false
  S.sent, S.used, S.shown, S.opened, S.cap, S.texts, S.emb, S.names, S.kits = {}, {}, {}, {}, {}, {}, {}, {}, {}
  S.rate, S.queue, S.clubs, S.club_want, S.tab, S.apply, S.applied = {}, {}, {}, nil, 1, {}, {}
  Want("state")
end

function OnSetupLayer(a1, a2)
  if a1 == L_HEADER then
    if SetupSoccerTopCommonHeaderLayerInfo then
      SetupSoccerTopCommonHeaderLayerInfo(a1, 4153539961, 253801632, 3969848060, 1144161661, 3293713115, 253801632, 1152304044, 305955024, 3007971317)
    end
    if SwapSoccerTopCommonHeaderMenuModeIconTexture then
      SwapSoccerTopCommonHeaderMenuModeIconTexture(Crc("mode_base04"))
    end
    if UpdateHeader then
      UpdateHeader(3586861540)
    end
    M(C.SET_TEXT, a1, SUB_TITLE, Tx("Title"))
  elseif a1 == L_ANCHOR then
    for _, node in ipairs(ANCHOR.TEXTS) do M(C.SET_TEXT, a1, node, "", a2) end
    M(C.ATTACH_TRACE, a1, a2, ANCHOR.CURSOR, false)
  else
    for _, layer in pairs(L) do
      if a1 == layer then
        -- a pool instance: hidden until the screen draws it
        M(C.VISIBLE, a1, a2, false)
        local prefix = a1 .. ":" .. a2 .. ":"
        for k in pairs(S.sent) do
          if string.sub(k, 1, #prefix) == prefix then S.sent[k] = nil end
        end
        if a1 == L.team then VRFW_Team.EmblemForget(a1, a2, S.emb) end
        if a1 == L.face and VRFW_FaceIcon ~= nil then VRFW_FaceIcon.Forget(a1, a2) end
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
  local f = FN[a2] or FN[a1]
  if f == nil then return end
  if not S.closing then f() end
  return 1
end

-- B / Esc / right click: back one page; from the first page the screen closes and the title takes input back
function OnBack(a1)
  if not S.closing then Back() end
  return 1
end

function Step()
  S.frame = S.frame + 1
  if S.closing then return end
  Fetch()
  FetchClub()
  if #S.apply > 0 then ApplySome() else RateSome() end
  if VRFW_FaceIcon ~= nil and VRFW_FaceIcon.Pending() then VRFW_FaceIcon.Settle() end
  -- the bracket screen: opened once an earlier one has closed, none left over
  local tm = TreeMenu()
  if tm then
    local okt, errt = pcall(tm.Step)
    if not okt and not S.tree_error then
      S.tree_error = true
      Log("bracket screen error", tostring(errt))
    end
  end
  if S.pots and S.pots.flash > 0 then
    S.pots.flash = S.pots.flash - 1
    if S.pots.flash == 0 then S.dirty = true end
  end
  if not S.ready then return end
  -- the cursor bobs: one draw a frame while a page shows (only what changed is sent)
  if S.dirty or S.mode ~= "loading" then
    S.dirty = false
    local ok, err = pcall(Draw)
    if not ok then Log("draw error", tostring(err)) end
  end
end
