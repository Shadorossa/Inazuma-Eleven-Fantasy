-- evt_career_menu (plain Lua 5.2 source): the career hub (docs/game/mods/career-mode-proposal.md §1b, §8). Declared in
-- content\menus\career_menu.toml ([[screen]], served as common/script/lua/menu/evt_career_menu.lua.bin); opened by the
-- mode's title row button (content\menus\title_row.toml) as a child of the title, which takes input back when it closes.
-- Pages:
--   home  the save slot's careers (config [careers] slots) as cards: A continues one or starts a new one in an empty
--         card, X deletes one (asks first), B leaves
--   pick  the club pick: the clubs of a career by game on top (L1 / R1), the clubs as a carousel (left / right), the
--         focused club's card below (stars, ATA / MED / DEF, formation, best players); A asks to start
--   hub   a tab bar on top (L1 / R1; the tabs are config.toml [hub] tabs, some only in some phases): Inicio (the next
--         match and its date: A plays it, Y simulates it; the last results; the table around the club with season,
--         level and budget; the news feed: portrait cards, right stick / wheel / a click for the next), Calendario (a month of the season's days, FIFA style:
--         the club's matches with their rivals and results, the draw, the transfer windows, the breaks, the World
--         Cup; the month's matches listed beside it; arrows: month), Competición (left / right: the competition, its name centred in the
--         header: SuperLiga and leagues as a table (up / down: page); the Fútbol Frontier's knockout; the World Cup:
--         its groups together in a grid, up / down to its knockout once drawn. The knockouts are the framework's
--         bracket screen vrfw_bracket_menu, opened over this one by VRFW_Bracket and drawn from
--         CMND_CAREERMODE_TREE / CMND_CAREERMODE_WC_TREE), Plantilla (the game's own team screen
--         soccer_team_dock_menu with the career club, opened in place as soon as the tab is selected: VRFW_TeamEditor
--         in its team page mode, a temporary copy inside a save session undone when the screen closes; its L1 / R1 move
--         to the previous / next tab, B goes back as on any tab; the order, formation, name, crest, kit, coach and
--         tactics left there are kept by the career: CMND_CAREERMODE_CLUB_DOCK / _DOCK_SET / _LOOK_SET; this screen
--         draws only its tab bar while it is up; when it cannot open, the career's own squad list), Convocatoria
--         (squads larger than a match takes: the call-up list), Mercado (the transfer market: L2 / R2 switch the
--         bar's sections Buscar / En venta, left / right «Plantilla» and the section, up / down the row; A offers,
--         accepts an offer or sets a player's status; Y shows the game's player page (personal_plate_menu, its
--         players-universe mode) or refuses an offer; X the filter, the name searched or a counter-offer:
--         CMND_CAREERMODE_MARKET / _BUY / _STATUS / _ANSWER)
--   pots  the draw of the leagues: the pots, a ball at a time (A; Y draws the rest), then A starts the leagues
--   wcsquad  a call-up: the World Cup's (the offered national side's players, Y confirms a full squad and the group
--         stage starts) or the club's (the «Convocatoria» tab: the players its matches take, Y keeps a full call-up);
--         A calls one up or leaves him out, B back to the hub («Plantilla»)
-- The squads are the career's (every player once per career): the hub writes them into the clubs' roster rows
-- (CMND_VRFW_TEAM_ROSTER) before it reads their stats, and puts the data's rows back when the player leaves the mode.
-- The club card's numbers are the game's own stats at the club's level (team member info, field 10), rated by the
-- rules of config.toml [rating]. The screen is the root of its own menu scene (title row `root_menu`: the game kept in
-- memory, reset straight into it); leaving it is the reset to the title (VRFW_Reset.to_title). «Jugar» starts the
-- match with VRFW_MATCH.start (content\friendlies\career.toml): the title comes back after it and opens the hub again. Both clubs play through the slot teams of config.toml [match]
-- (CMND_VRFW_TEAM_STAND_IN) with their match squads (the whole squad, or the call-up / the best when larger), so every signing sits on the bench. Keys: cmd rows of the off-screen anchor row -> OnFunction /
-- OnBack. Data: scripts\career.lua through the commands CMND_CAREERMODE_* (a command that answers nothing while the
-- scripts are busy is asked again next frame). No engine call at load time.
INCLUDE("LUA_PROG_BASE")
INCLUDE("LUA_SAVEDATA_MANAGEMENT_MENU_INC")

local C = {
  LOG = 3661580131, TEXT_GET = 4074371074, ITEM_PARAM = 1883585771, LANG = 477234096, SND = 3073642526,
  LAYER_NUM = 1175615627, OPEN_LAYER = 629267548, VISIBLE = 711242136, POS = 1389957207, SCALE = 3778714801,
  SPRITE = 558735651, ALPHA = 4231609516, MESH_VISIBLE = 3405944500, SET_TEXT = 1083631230, LOAD_TEX = 839427544,
  TEX_LOADING = 1506186496, TEXT_STYLE = 2333948100, CTRL = 3518307824, LIST_NUM = 3252599449,
  FOCUS_SET = 3466097042, ATTACH_TRACE = 1774843228, TEAM_INFO = 2151743654,
  TEXT_VISIBLE = 1505208242,
  IS_VISIBLE = 1262717583,     -- CMND_IS_LAYER_VISIBLE (layer, instance) -> shown
  ROTATE = 3476640154,         -- (layer, x, y, z radians, instance): retail SetLayerLocalRotate
  POINTER = 558229292,         -- () -> the pointer's x, y (screen px, y down)
  POINTER_MOVED = 3272825600,  -- () -> true when the pointer moved this frame (the engine sends no hover to free layers)
  MEMBER = 34355761,           -- team member info (team, member, field[, stat]): 0 card, 6 level, 7 place, 10 stat
  INPUT = 1558704558,          -- CMND_SET_INPUT_ENABLE_MENU_OBJECT
  CLOSE_MENU = 320421347,      -- CMND_CLOSE_MENU_OBJECT
}
-- the menu this screen opens over (its title row button, content\menus\title_row.toml: host title_menu_2): its layers
-- hidden while the screen is up, shown again when it closes or a match starts. The news card's 3D model swaps this
-- screen's normal-pass background for a background-pass copy (VRFW_ModelCard spec.hide / backdrop), and the title's
-- own 2D layers would draw over that copy. Hidden in the title's own VM by the framework's hub yield
-- (CROSS_CALL(menu, "VRFW_HubYield", on, this menu, layers)): the visible instances of LAYERS hidden and exactly
-- those shown again. LAYERS: the title_menu_2 layers that draw (title_menu_2_setting.cfg.bin).
local UNDER = { MENU = 3874253475 --[[title_menu_2]], CROSS_CALL = 830228314, EXISTS = 2231168902,
  LAYERS = table.concat({ "title02_00_title_bg_2", "title02_01_title_logo_2", "title02_03_item_name_2",
    "title02_04_version", "title02_04_version_ps", "title02_06_information_banner", "title02_07_victory_counter",
    "title02_08_explanation_button_guide", "title02_09_flavor_balloon", "title02_09_flavor_balloon_else",
    "title02_09_flavor_balloon_upper", "title02_10_my_team_banner", "title02_11_avatar_banner",
    "title02_12_victory_counter_detail", "title02_21_dlc_buy_btn", "title02_21_sw2_upgrade_pass_btn", "title02_22_dlc_logo",
    "title02_22_dlc_logo_for_balloon", "title02_23_dlc_logo_simple", "title02_24_dlc_logo_simple_balloon",
    "title00_07_item_button", "title00_07_item_button_lower", "title00_07_item_button_upper", "title00_08_copyright",
    "title00_10_inazuma_post", "title00_14_avatar_make", "title00_15_vroad_tournament_info_balloon",
    "vroad01_72_vroad_tournament_notice_button_guide", "info01_03_banner_list_item", "info01_03_title_banner_list_item",
    "cmn01_13_banner_new_icon_middle", "cmn01_13_new_icon_middle", "cmn01_21_avatar_banner_loading_icon",
    "cmn01_21_loading_icon", "cmn01_21_my_team_banner_loading_icon", "cmn05_01_cursor" }, ",") }
local SETTINGS = {}               -- the «Ajustes» tab (its page, defined with the hub)
local CLOSE_WAIT = 120            -- frames the screen waits for the news model's release before it closes
local SND = { MOVE = 2500047763, BUZZER = 2086672038, DECIDE = 766561556, BACK = 202039849 }
local L_ANCHOR = 3455690937        -- save01_02_list_item: the input anchor (1 instance, off screen)
local HEADER = { LAYER = 575058101 --[[mainmenu90_01_header]], SUB_TITLE = 1220590795 --[[_text_sub_title02]] }
local ANCHOR = { TEXTS = { 931545948 --[[_text_list01_on]], 3705682548 --[[_text_list01_off]] }, CURSOR = 3313461902,
  -- _list_icon_dmy_s01_on / off / ok, _list_base_s01_ok / on / off / ol: hidden, the instance fully transparent
  MESHES = { 376662541, 3232607807, 1712955010, 3292070381, 3025401186, 486732393, 1516082254 } }
local QUAD = { SLOT = 1909474081 --[[icon_new01: the cmn01_10 quad's sprite slot]], SIDE = 36 --[[its side]] }
-- the text object (cmn03_01_cmd_back): its text node and the meshes hidden; the node box spans x -384 .. 16 of the
-- object (left edge HALF px left of the origin, centre BOX_CENTRE px left of it; a centred style centres on BOX_CENTRE)
local TXT = { NODE = 378327766, MESHES = { 298211823, 2853207670 }, HALF = 384, BOX_CENTRE = 200, MID_Y = 144 }
-- the club row (team06_02): plate meshes (off / on / ok / outline), check mark, crest, name nodes; retail geometry at scale 1
local TEAM = {
  PLATES = { off = 2022529787, on = 2334302522, ok = 4215821749, ol = 1697431574 },
  CHECK = 2309656400,   -- _icon_check01: the emblem list's check mark, never shown here
  -- _dmy_list01_off / _on, _touch_list01: hidden (scaled up under a big crest they drew a thin white line)
  DUMMIES = { 1568845993, 3944371080, 688754292 },
  TXT_ON = 931545948, TXT_OFF = 3705682548,   -- the crest: VRFW_Team.Emblem
  PLATE_LEFT = 98, CREST_CENTER = 78,   -- the plate starts 98 px left of the origin, the crest is centred 78 px right of it
}
-- retail sprites drawn on the quads
local TABS_TEX = "#/menu/200_icon/16_icon_list_tab/icon_list_tab.g4tx"
local ART = {
  -- the panels: the mod's own cut of the retail panels (content/images/menu/220_img/career_panels.toml): their
  -- gradient and inner shapes, straight edges, no drop shadow; stretched to the box
  navy = { tex = "#/menu/220_img/career_panels/career_panels.g4tx", sprite = "career_panel_navy" },
  white = { tex = "#/menu/220_img/career_panels/career_panels.g4tx", sprite = "career_panel_white" },
  band = { tex = "#/menu/20_cmn/cmn06/cmn06_01/cmn06_01.g4tx", sprite = "list_tab_base01" },
  strip = { tex = "#/menu/20_cmn/cmn06/cmn06_01/cmn06_01.g4tx", sprite = "list_tab_base01_02" },
  row = { tex = "#/menu/51_save/save01/save01_02/save01_02.g4tx", sprite = "list_base_s01_off", tintable = true },
  row_on = { tex = "#/menu/51_save/save01/save01_02/save01_02.g4tx", sprite = "list_base_s01_on" },
  -- the retail tab bar's selected plate (92 x 52; its top edge from TOP_L to TOP_R on row TOP, the bar body's slant):
  -- drawn at the bar's own scale, copies side by side for a wider tab, so its sides lean as the bar's
  tab_on = { tex = "#/menu/20_cmn/cmn06/cmn06_20/cmn06_20.g4tx", sprite = "icon_base01", w = 92, h = 52, TOP = 2,
    TOP_L = 9.9, TOP_R = 91 },
  row_ol = { tex = "#/menu/51_save/save01/save01_02/save01_02.g4tx", sprite = "list_base_s01_ol" },
  cyan = { tex = "#/menu/20_cmn/cmn03/cmn03_02/cmn03_02.g4tx", sprite = "cmd_btn_base01_on" },
  cursor = { tex = "#/menu/20_cmn/cmn05/cmn05_01/cmn05_01.g4tx", sprite = "cur01", w = 128, h = 152 },
  star = { tex = "#/menu/00_soccer/soccer11/soccer11_14/soccer11_14.g4tx", sprite = "icon_star01" },
  arrow = { tex = "#/menu/10_win/win05/win05_28/win05_28.g4tx", sprite = "icon_arrow01_on", w = 28, h = 32 },
  vs = { tex = "#/menu/00_soccer/soccer00/soccer00_31/soccer00_31.g4tx", sprite = "gtxt_vs01", w = 124, h = 76 },
  play = { tex = "#/menu/20_cmn/cmn03/cmn03_02/cmn03_02.g4tx", sprite = "cmd_btn_base01_on" },
  button = { tex = "#/menu/20_cmn/cmn03/cmn03_02/cmn03_02.g4tx", sprite = "cmd_btn_base01_off" },
  fill = { tex = "#/menu/102_team/team00/team00_01/team00_01.g4tx", sprite = "gauge_exp_bar01", tintable = true },
  chevron = { tex = "#/menu/00_soccer/soccer11/soccer11_05/soccer11_05.g4tx", sprite = "arrow01_r", w = 36, h = 44 },
}
-- the colours of the plain sprites (fill, row): CMND_SET_PRIM_COLOR never tints the cmn01_10 quad, so a colour is a
-- flat swatch of the mod's own atlas (content\images\menu\220_img\career_tint.toml, the colours in
-- research/scripts/career_tint_art.py); TINT.<name> = sprite career_tint_<name>
local TINT = setmetatable({}, { __index = function(t, name)
  local v = { tex = "#/menu/220_img/career_tint/career_tint.g4tx", sprite = "career_tint_" .. tostring(name) }
  rawset(t, name, v)
  return v
end })
-- the hub's surfaces (owner 2026-10-31: translucent panels): the white panels and the light row / chip / track plates
-- on the page layers (career_panel, career_plate) are drawn at SURFACE_ALPHA so the hub's background shows through;
-- the accents (select, cut, the result colours) and the dialog layers stay opaque, the texts cannot fade
local SKIN = { SURFACE_ALPHA = 0.78, SURFACE = { career_panel_white = true, career_tint_white = true,
  career_tint_stripe = true, career_tint_window = true, career_tint_chip = true, career_tint_rest = true } }
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
  LEFT = { x = 60 },
  FOOT_Y = 1034,
  TABS = { x = 60, y = 122, w = 1800, h = 76, CAP_INSET = 118, CAP_W = 150,   -- a grey end cap's centre CAP_INSET px
    -- the bar sprite (ART.strip, 1036 x 76): its blue body's top edge from BODY_L to BODY_R, its rows BODY_TOP ..
    -- BODY_BOTTOM; every slanted edge leans SLANT px over the body's height (the retail selected plate's too)
    SPRITE_W = 1036, BODY_L = 122.2, BODY_R = 923.2, BODY_TOP = 14, BODY_BOTTOM = 62, SLANT = 9 },
                                                                                 -- in from the bar's end, CAP_W px wide
  -- over the game's team screen («Plantilla»): the bar slimmer and higher, the screen's list from LIST_TOP and its
  -- pitch FIELD_DY px lower (VRFW_TeamEditor spec.list_top / field_dy)
  -- CHECK: the Step of the team screen at which the log says once whether the bar is shown over it
  -- HEADER_TOP: the team screen's team name bar (crest, name, kit) under the tab bar, its base at this screen y
  -- BENCH_COLUMNS: the bench in two columns of 5 (the squad's 17th-21st players), the pitch FIELD_DX px to the side
  -- (VRFW_TeamEditor spec.bench_columns / field_dx); FIELD_DX centres the coach .. second bench column block on the
  -- screen (the list is hidden). BENCH_DX 0: both columns on their joints (VRFW no longer moves the bench cards)
  -- HIDE_LIST / ICONS: the screen's list off screen, its rows as icon buttons in the panel between TÁCTICAS and the
  -- stadium (VRFW_TeamEditor spec.hide_list / icons: row kind 2 bonds, 7 abilities, 9 hyper commands; sprites of the
  -- hub header atlas mainmenu90_01, w x h px from the sprite's 360 x 248 / 224 x 248)
  TABS_DOCK = { x = 60, y = 84, w = 1800, h = 62, LIST_TOP = 230, FIELD_DY = 64, HEADER_TOP = 192, CHECK = 30,
    -- HEADER_DX: the team name bar (crest .. «Nv.», screen x 699-1905) centred on the same line as the block below
    HEADER_DX = -342,
    BENCH_COLUMNS = 2, FIELD_DX = -280, BENCH_DX = 0, HIDE_LIST = true,
    ICONS = { { row = 2, sprite = "icon_header_commu01", w = 64, h = 44 },
      { row = 7, sprite = "icon_header_v_record01", w = 64, h = 44 },
      { row = 9, sprite = "icon_header_sub_cpu_story01", w = 40, h = 44 } },
    -- the player popup rows left out (VRFW_TeamEditor spec.hide_card_rows): 9 «Pasivas heredadas» (Utilities:
    -- «Configuración de pasivas»), 10 «Eliminar pasiva heredada»
    HIDE_CARD_ROWS = { 9, 10 } },
  PAGE = { x = 60, y = 220, w = 1800, h = 780 },
}
-- the hub's pages under the one tab bar every tab shows (TABS_DOCK, as over the team screen): drawn PAGE_DY px from
-- the coordinates they are laid out in (under the full TABS bar), so the gap under the bar stays as it was
G.PAGE_DY = (G.TABS_DOCK.y + G.TABS_DOCK.h) - (G.TABS.y + G.TABS.h)
local POS_TEXT = { [1] = "PosGK", [2] = "PosFW", [3] = "PosMF", [4] = "PosDF" }
local RATE_PER_STEP = 2            -- clubs whose stats are read in one Step
local APPLY_PER_STEP = 8           -- clubs whose career squads are written in one Step
local SERIES_ICON = "icon_list_tab_series%02d"   -- the tab atlas' series icons, 1 ie1 ... 9 victory_road
-- a knockout of the «Competición» tab: the framework's bracket below the competition header (top = the page's top
-- row), its retail art (draw priorities 197-203) lifted over this screen's background (mainmenu90_00_background, 450)
-- and under the bracket's own pools (546 and up); VIEW = the view command of each knockout
local BRACKET = { VIEW = { frontier = "CMND_CAREERMODE_TREE", worldcup = "CMND_CAREERMODE_WC_TREE" }, TOP = G.PAGE.y,
  LIFT = 300, HEAD_H = 56 }
-- the competition header: the name's width, the L2 / R2 arrows (scale of the chevron, px from the band's ends), the
-- competitions' small chips under the name (px, below the band's middle), the last round's centre (px from the right)
-- Torneos' header: the title NAME_W px at most, the L2 / R2 glyphs (KEY px) KEY_GAP from it, the competitions' dots
local COMPETITION = { NAME_W = 700, KEY = 40, KEY_GAP = 18, DOT = 22, DOT_H = 6, DOT_GAP = 8, DOT_Y = 14,
  ROUND_X = 260 }
-- the World Cup's groups together: a grid of small tables (columns = ceil(sqrt(groups)), at least 2)
local GROUPS = { TOP = 84, GAP_X = 30, GAP_Y = 20, HEAD = 46, STEP_MAX = 50, CREST_MAX = 0.55 }

-- state of this opening
local S = {
  dy = 0,              -- the y shift of what is drawn now (the hub's pages: G.PAGE_DY)
  ready = false, frame = 0, dirty = true, sent = {}, used = {}, shown = {}, opened = {}, cap = {}, texts = {},
  emb = {}, loaded = {}, names = {}, mode = "loading", state = nil, draw = nil, hub = nil, want = nil,
  pick = { league = 1, sel = 1 }, tab = 1, page = 1, table = nil, dialog = nil, closing = false,
  rate = {}, queue = {}, clubs = {}, club_want = nil, rules = nil, kits = {},
  apply = {}, applied = {}, tindex = 1, tpage = 1, pots = nil, match = false,
}
local L = {}
local L_KEYS = 0                   -- career_keys: the tab keys in the tab bar's end caps (2 instances)
local MENU = 0
local TabTo                        -- (tab id): that hub tab selected (defined with the team page flow)

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

-- the menu under this screen hidden (on) / shown again; once per change, logged
function UNDER.Hide(on)
  if (S.under_hidden == true) == on then return end
  S.under_hidden = on
  if on and M(UNDER.EXISTS, UNDER.MENU) ~= true then
    S.under_hidden = false
    return
  end
  pcall(funcLuaCommand, UNDER.CROSS_CALL, UNDER.MENU, "VRFW_HubYield", on, MENU, on and UNDER.LAYERS or "")
  Log("title under the screen", on and "hidden" or "shown")
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

-- a team's name (a clubs file name: hub club_names); a career club whose name another club has too: its series
-- tag after it (hub club_tags)
local function TeamName(team)
  if team == nil or team == 0 then return "" end
  local n = S.names[team]
  if n == nil then
    n = VRFW_Team.Name(team)
    if n ~= "" then S.names[team] = n end
  end
  local h = S.hub
  if h and type(h.club_tags) == "table" and n ~= "" then
    if S.tags_of ~= h then
      S.tags_of, S.tags, S.club_names = h, {}, {}
      for _, it in ipairs(h.club_tags) do S.tags[it.team] = it.tag end
      for _, it in ipairs(type(h.club_names) == "table" and h.club_names or {}) do S.club_names[it.team] = it.name end
    end
    n = S.club_names[team] or n
    local tag = S.tags[team]
    if tag then return n .. " (" .. tag .. ")" end
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
  if r == nil then return nil end
  -- the career's club ratings (the script's rules.clubs: { team, rating }) when they rate every club shown, else the
  -- game's stats of the clubs (RateTeam)
  if r.by_team == nil or r.by ~= r.clubs then
    r.by_team = {}
    for _, p in ipairs(r.clubs or {}) do
      if type(p) == "table" and type(p[2]) == "number" and p[2] > 0 then r.by_team[p[1]] = p[2] end
    end
    r.by = r.clubs
  end
  local value = r.by_team[team] and function(t) return r.by_team[t] end
  for _, t in ipairs(value and teams or {}) do
    if r.by_team[t] == nil then value = nil break end
  end
  if value == nil then
    if S.rate[team] == nil then return nil end
    value = function(t) return S.rate[t] and S.rate[t].overall end
  end
  local me = value(team)
  local rt = r.by_team[team]
  if type(r.stars_by_rating) == "table" and #r.stars_by_rating > 0 and rt then
    local pts, v = r.stars_by_rating, nil
    if rt <= pts[1][1] then v = pts[1][2]
    elseif rt >= pts[#pts][1] then v = pts[#pts][2]
    else
      for i = 2, #pts do
        if rt <= pts[i][1] then
          v = pts[i - 1][2] + (pts[i][2] - pts[i - 1][2]) * (rt - pts[i - 1][1]) / (pts[i][1] - pts[i - 1][1])
          break
        end
      end
    end
    v = math.max(r.stars_min, math.min(r.stars_max, v or r.stars_min))
    return math.floor(v / r.stars_step + 0.5) * r.stars_step
  end
  local better, n = 0, 0
  for _, t in ipairs(teams) do
    local x = value(t)
    if x == nil then return nil end
    n = n + 1
    if x > me then better = better + 1 end
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
  if n >= (S.cap[layer] or 0) then
    -- the layer's pool is too small for this page (its count in content/menus/career_menu.toml): logged once a layer
    S.full = S.full or {}
    if not S.full[layer] then
      S.full[layer] = true
      Log("pool full: layer", layer, "has", S.cap[layer] or 0, "instances; the page asks for more")
    end
    return nil
  end
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

-- a texture's load asked once; waited for at most TEX_WAIT frames (a texture that never loads is logged once and
-- its quads skipped, so the screen does not draw again every frame for it)
local TEX_WAIT = 600
local function TexReady(tex)
  local w = S.loaded[tex]
  if w == nil then
    pcall(funcLuaMenuCommand, C.LOAD_TEX, tex)
    w = S.frame
    S.loaded[tex] = w
  end
  if w == false then return false end
  local ok, loading = pcall(funcLuaCommand, C.TEX_LOADING, Crc(tex))
  if ok and loading == false then return true end
  if S.frame - w > TEX_WAIT then
    S.loaded[tex] = false
    Log("texture never loaded", tex)
  end
  return false
end

-- a retail sprite stretched over x, y, w, h on a quad layer (flip = mirrored left to right, tint = a TINT colour:
-- a plain sprite (fill, row) is drawn as that colour's swatch)
local function Quad(layer, art, x, y, w, h, alpha, flip, tint)
  if tint ~= nil and art.tintable then art = tint end
  if SKIN.SURFACE[art.sprite] and (layer == L.panel or layer == L.plate) then alpha = (alpha or 1) * SKIN.SURFACE_ALPHA end
  local m = art.inset
  if m then
    local kx, ky = w / (m[5] - m[1] - m[3]), h / (m[6] - m[2] - m[4])
    x, y, w, h = x - m[1] * kx, y - m[2] * ky, m[5] * kx, m[6] * ky
  end
  if not TexReady(art.tex) then
    if S.loaded[art.tex] ~= false then S.dirty = true end
    return nil
  end
  local i = Slot(layer)
  if i == nil then return nil end
  Show(layer, i)
  Set(layer, i, "sc", C.SCALE, layer, (flip and -w or w) / QUAD.SIDE, h / QUAD.SIDE, 1, i)
  Set(layer, i, "sp", C.SPRITE, layer, Crc(art.tex), art.sprite_id or Crc(art.sprite), QUAD.SLOT, 0, i)
  Set(layer, i, "pos", C.POS, layer, x + w / 2, -(y + S.dy + h / 2), 0, i)
  Set(layer, i, "a", C.ALPHA, layer, i, 0, alpha or 1)
  if S.turned and S.turned[layer .. ":" .. i] then
    Set(layer, i, "rot", C.ROTATE, layer, 0, 0, 0, i)
    S.turned[layer .. ":" .. i] = nil
  end
  return i
end

-- a checkbox (bs px, its left edge at bx, centred on cy): ticked = filled in `tint` with the white tick, else a white
-- box in a grey frame
function G.CheckBox(layer, bx, cy, bs, ticked, tint)
  if ticked then
    LEVEL.Turned(layer == L.dialog and L.dialog or L.icon, ART.chevron, bx + bs * 0.3, cy - bs * 0.35, bs * 0.4,
      bs * 0.7, -math.pi / 2)
    Quad(layer, ART.fill, bx, cy - bs / 2, bs, bs, 1, nil, tint)
  else
    Quad(layer, ART.fill, bx + 3, cy - bs / 2 + 3, bs - 6, bs - 6, 1, nil, TINT.white)
    Quad(layer, ART.fill, bx, cy - bs / 2, bs, bs, 1, nil, TINT.draw)
  end
end

-- a frame of t px edges around the box x, y, w, h (outside it), in a TINT colour
local function Frame(layer, x, y, w, h, t, tint)
  Quad(layer, ART.fill, x - t, y - t, w + 2 * t, t, 1, nil, tint)
  Quad(layer, ART.fill, x - t, y + h, w + 2 * t, t, 1, nil, tint)
  Quad(layer, ART.fill, x - t, y, t, h, 1, nil, tint)
  Quad(layer, ART.fill, x + w, y, t, h, 1, nil, tint)
end

-- the career levels' drawing (one table: the screen's main chunk is near Lua's 200 locals)
local LEVEL = {}

-- a quad turned around its centre by `rot` radians; an instance a turned quad used is turned back when reused
function LEVEL.Turned(layer, art, x, y, w, h, rot, tint)
  local i = Quad(layer, art, x, y, w, h, 1, false, tint)
  if i == nil then return nil end
  S.turned = S.turned or {}
  local k = layer .. ":" .. i
  if (rot or 0) ~= 0 or S.turned[k] then
    Set(layer, i, "rot", C.ROTATE, layer, 0, 0, rot or 0, i)
    S.turned[k] = (rot or 0) ~= 0 or nil
  end
  return i
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
  local px = align == "c" and (x + TXT.BOX_CENTRE * sc) or (x + TXT.HALF * sc)
  Set(layer, i, "pos", C.POS, layer, px, -(y + S.dy) - TXT.MID_Y * sc, 0, i)
  return i
end

-- the cursor's sideways bob (px) at this frame: one cycle every 30 frames
local function Bob()
  return math.floor(3 * math.sin(S.frame * 2 * math.pi / 30) + 0.5)
end

-- the cursor quad; remembered so Step moves it alone between draws (Bob)
local function Cursor(x, y, h)
  local w = h * ART.cursor.w / ART.cursor.h
  local i = Quad(L.icon, ART.cursor, x - w + Bob(), y - h / 2, w, h)
  if i ~= nil then S.cursor = { i = i, left = x - w, half = w / 2, y = -(y + S.dy) } end
end

-- a hub button: the retail command button (blue; cyan with the cursor when focused), its label centred; kept in
-- S.buttons (screen box + action) for the arrows, the pointer and A
local function Button(label, action, x, y, w, h)
  local k = #S.buttons + 1
  local on = k == S.button
  S.buttons[k] = { x0 = x, y0 = y, x1 = x + w, y1 = y + h, action = action }
  Quad(L.plate, on and ART.play or ART.button, x, y, w, h)
  if on then Cursor(x + 4, y + h / 2, 44) end
  Text(L.text, label, x + w / 2, y + h / 2, "body_w", 1.1, "c")
end

-- the hub button under the pointer (its index), or nil
local function ButtonAt(px, py)
  for k, b in ipairs(S.buttons or {}) do
    if px >= b.x0 and px < b.x1 and py >= b.y0 and py < b.y1 then return k end
  end
  return nil
end

-- the cursor's bob between draws: only its position is sent (the same numbers as Quad's)
local function CursorBob()
  local c = S.cursor
  if c == nil then return end
  Set(L.icon, c.i, "pos", C.POS, L.icon, (c.left + Bob()) + c.half, c.y, 0, c.i)
end

-- a club row: plate shown in `look` ("off", "focus", or nil = no plate), crest + name; x = the plate's left edge,
-- y = its vertical middle, s = scale; name nil = the club's own name, "" = none; alpha < 1 = dimmed
local function Team(team, x, y, s, look, name, alpha)
  local l = L.team
  local i = Slot(l)
  if i == nil then return nil end
  Show(l, i)
  Set(l, i, "sc", C.SCALE, l, s, s, 1, i)
  Set(l, i, "pos", C.POS, l, x + TEAM.PLATE_LEFT * s, -(y + S.dy), 0, i)
  Set(l, i, "a", C.ALPHA, l, i, 0, alpha or 1)
  Set(l, i, "p.off", C.MESH_VISIBLE, l, TEAM.PLATES.off, look == "off", i)
  Set(l, i, "p.on", C.MESH_VISIBLE, l, TEAM.PLATES.on, look == "focus", i)
  Set(l, i, "p.ok", C.MESH_VISIBLE, l, TEAM.PLATES.ok, false, i)
  Set(l, i, "p.ol", C.MESH_VISIBLE, l, TEAM.PLATES.ol, look == "focus", i)
  Set(l, i, "chk", C.MESH_VISIBLE, l, TEAM.CHECK, false, i)
  for k, mesh in ipairs(TEAM.DUMMIES) do Set(l, i, "dmy" .. k, C.MESH_VISIBLE, l, mesh, false, i) end
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

-- the kit a player's miniface wears in the colours of `team` (the career club or national side he plays for): the
-- team's live uniform (TEAM_INFO field 4: the one its squad screen and matches use, mod teams and the career's kit
-- choice included), else its uniform in the team data (CMND_VRFW_CONTACT_KIT(card, team)); the keeper shirt for a
-- keeper. Asked once per card and team. nil = no team (a free player): the plain default kit
-- KEEPER_SHIRT: CMND_VRFW_CONTACT_KIT flags, the keeper shirt; TEAM_UNIFORM: TEAM_INFO field, the team's uniform
local KIT = { KEEPER_SHIRT = 2, TEAM_UNIFORM = 4 }
local function Kit(card, team)
  if (team or 0) == 0 then return nil end
  local id = card .. ":" .. team
  local kit = S.kits[id]
  if kit == nil then
    kit = false
    local ok, t = pcall(funcLuaCommand, Crc("CMND_VRFW_CONTACT_KIT"), card, team)
    if not (ok and type(t) == "table") then t = {} end
    local live = F(C.TEAM_INFO, team, KIT.TEAM_UNIFORM)
    local uniform = (type(live) == "number" and live ~= 0) and live or tonumber(t.uniform) or 0
    if uniform ~= 0 then
      kit = { kit = uniform, keeper = bit32.band(tonumber(t.flags) or 0, KIT.KEEPER_SHIRT) ~= 0, use_args = true }
    else
      Log("kit: none for card", card, "team", team, "source", tostring(t.source))
    end
    S.kits[id] = kit
  end
  return kit or nil
end

-- a player's miniface (VRFW_FaceIcon: the list character card, face + kit) centred on (x, y), px tall, wearing the
-- kit of `team` (nil = his own kit); portrait = the full portrait (its background and gradient, as the player pages)
local function Face(card, x, y, px, team, portrait)
  if (card or 0) == 0 or VRFW_FaceIcon == nil then return end
  local i = Slot(L.face)
  if i == nil then return end
  Show(L.face, i)
  local opts = Kit(card, team) or { use_args = true }
  if portrait then
    local o = { portrait = true }
    for key, v in pairs(opts) do o[key] = v end
    opts = o
  end
  VRFW_FaceIcon.Card(L.face, i, { card = card }, x, y + S.dy, px, opts)
end

local function BeginFrame() S.used, S.cursor, S.buttons, S.zones = {}, nil, {}, {} end

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

-- an amount with the language's thousands separator
local function Thousands(n)
  local s = tostring(math.floor(tonumber(n) or 0))
  local neg = s:sub(1, 1) == "-"
  if neg then s = s:sub(2) end
  local sep = Tx("ThousandsSep")
  local out = s:sub(1, (#s - 1) % 3 + 1)
  for i = (#s - 1) % 3 + 2, #s, 3 do out = out .. sep .. s:sub(i, i + 2) end
  return (neg and "-" or "") .. out
end

-- an amount shortened (every short amount of the mode: lists, news, offers): millions and thousands with M / k, one
-- decimal only when it is not 0, a dot as the decimal mark (1.2M, 2M, 750k); under 1000 the whole number
local function Short(n)
  n = math.floor(tonumber(n) or 0)
  local a = math.abs(n)
  local sign = n < 0 and "-" or ""
  local function one(v, key)
    local tenths = math.floor(v * 10 + 0.5)
    local s = tostring(math.floor(tenths / 10))
    if tenths % 10 ~= 0 then s = s .. "." .. tostring(tenths % 10) end
    return sign .. Tx(key, s)
  end
  if a >= 999950 then return one(a / 1000000, "MoneyMillions") end
  if a >= 1000 then return one(a / 1000, "MoneyThousands") end
  return sign .. tostring(a)
end

-- the mode's currency (config.toml [market] currency_item / currency_atlas, given by the hub): a game item whose
-- icon (its sprite in the item atlas) and name stand for the money; nil when none is set
local function Currency()
  local cur = (S.hub and S.hub.currency) or (S.slots and S.slots.currency)
  if type(cur) ~= "table" or (cur.item or "") == "" then return nil end
  if cur.name == nil then
    local ok, name = pcall(funcLuaCommand, C.ITEM_PARAM, Crc(cur.item), 0)
    cur.name = ok and type(name) == "string" and name or ""
    cur.art = (cur.atlas or "") ~= "" and { tex = cur.atlas, sprite = cur.item } or false
  end
  return cur
end

-- money in a text line: the amount and the currency's name
local function Money(n)
  local cur = Currency()
  return Tx("Money", Thousands(n), cur and cur.name or "")
end

local CURRENCY_GAP = 6   -- px between an amount and the currency icon

-- a white tile with its navy title band: the tab atlas' icon (sprite name, optional), the title, a note on the right
local TILE = { BAND = 52, NOTE_W = 360, DIGIT = 0.58 }   -- DIGIT: a drawn digit's width / the font size
-- money drawn: the amount, then the currency's icon (the text's height) right of it; x = the left edge or, with
-- align "c", the centre of amount and icon together
local function MoneyAt(n, x, y, style, sc, align)
  sc = sc or 1
  local cur = Currency()
  local s = type(n) == "string" and n or Thousands(n)
  if not (cur and cur.art) then return Text(L.text, type(n) == "string" and n or Money(n), x, y, style, sc, align) end
  local size = tonumber((STYLE[style] or STYLE.body):match("^fs_(%d+)")) or 28
  local w = Units(s) * size * TILE.DIGIT * sc
  local icon = math.floor(size * sc * 1.25)
  local left = align == "c" and (x - (w + CURRENCY_GAP + icon) / 2) or x
  Text(L.text, s, align == "c" and (left + w / 2) or left, y, style, sc, align)
  Quad(L.icon, cur.art, left + w + CURRENCY_GAP, y - icon / 2, icon, icon)
end

local function Tile(x, y, w, h, title, icon, note)
  Quad(L.panel, ART.white, x, y, w, h)
  Quad(L.plate, ART.fill, x, y, w, TILE.BAND, 1, nil, TINT.navy)
  local tx = x + 24
  if icon then
    Quad(L.icon, { tex = TABS_TEX, sprite = icon }, x + 14, y + 6, 60, 40)
    tx = x + 84
  end
  Text(L.text, title, tx, y + TILE.BAND / 2, "title", 0.9)
  if note and note ~= "" then
    Text(L.text, Fit(note, TILE.NOTE_W, 26), x + w - 40 - TILE.NOTE_W / 2, y + TILE.BAND / 2, "title_c", 0.72, "c")
  end
end

-- the key line at the screen's foot; each «A: …» / «B: …» / «X: …» / «Y: …» entry is a click zone pressing that key
-- (Click: POINTER.KEY), its box from the line's text widths
G.FOOT = { STYLE_PX = 26, SC = 0.95, GAP = "      ", H = 44 }
local function Footer(keys)
  local FOOT = G.FOOT
  local line = table.concat(keys, FOOT.GAP)
  Text(L.text, line, G.LEFT.x + 10, G.FOOT_Y, "outline", FOOT.SC)
  local unit = FOOT.STYLE_PX * TILE.DIGIT * FOOT.SC
  local x = G.LEFT.x + 10
  for _, k in ipairs(keys) do
    local w = Units(k) * unit
    local key = tostring(k):match("^(%w+)%s*[:\239]")
    if key then
      S.zones[#S.zones + 1] = { x0 = x - 6, y0 = G.FOOT_Y - FOOT.H / 2, x1 = x + w + 6, y1 = G.FOOT_Y + FOOT.H / 2,
        kind = "key", key = key }
    end
    x = x + w + Units(FOOT.GAP) * unit
  end
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
  Quad(L.plate, ART.fill, x + 90, y - 12, w, 24, 1, nil, TINT.stripe)
  if value > 0 then
    Quad(L.icon, ART.fill, x + 90, y - 12, math.max(4, w * math.min(1, value / math.max(1, scale))), 24, 1, nil, TINT.navy)
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
  if d.choice then
    -- two buttons (left / right), the focused one cyan: d.buttons = their texts
    for k, label in ipairs(d.buttons) do
      local bx = x + 90 + (k - 1) * 420
      Quad(L.dialog, k == d.choice and ART.play or ART.button, bx, y + h - 96, 360, 64)
      S.zones[#S.zones + 1] = { x0 = bx, y0 = y + h - 96, x1 = bx + 360, y1 = y + h - 32, kind = "dialog", index = k }
      Text(L.dtext, label, bx + 180, y + h - 64, "body_w", 1.05, "c")
    end
    return
  end
  Text(L.dtext, Tx("KeyYes") .. "      " .. Tx("KeyNo"), x + w / 2, y + h - 50, "body_w", 1, "c")
end

-- ---- home: the save slot's careers ------------------------------------------------------------------------------------

-- the careers page: one card per career of the save slot (CMND_CAREERMODE_SLOTS), the focused one framed in cyan;
-- the cards are hub buttons (S.buttons / S.button: arrows, pointer, A)
-- the panel (x, y, w; its height from the cards), the cards CARD_TOP px under the panel's top, CARD_H px tall,
-- GAP px apart, PAD px in from the panel's sides and bottom; a card's header HEAD px, its focus frame FRAME px
local SLOTS = { x = 60, y = 118, w = 1800, CARD_TOP = 82, CARD_H = 600, GAP = 28, PAD = 30, HEAD = 60, FRAME = 5 }

-- a career's phase line on its card
local function SlotPhase(s)
  if s.phase == "over" then return Tx("SeasonOver", s.season) end
  if s.phase == "pots" then return Tx("DrawTitle") end
  if (s.label or "") ~= "" then return Tx(tostring(s.label), s.n) end
  return Tx("Phase_" .. tostring(s.phase or ""))
end

local function SlotCard(k, slot, x, w)
  local B = SLOTS
  local y, h = B.y + B.CARD_TOP, B.CARD_H
  local cx = x + w / 2
  S.buttons[#S.buttons + 1] = { x0 = x, y0 = y, x1 = x + w, y1 = y + h, action = "slot", slot = k }
  local on = #S.buttons == S.button
  local s = slot.used and slot.summary or nil
  Quad(L.plate, ART.white, x, y, w, h, s and 1 or 0.7)
  if on then Frame(L.icon, x, y, w, h, B.FRAME, TINT.cut) end
  if s == nil then
    Text(L.text, "+", cx, y + 220, "big", 4, "c")
    Text(L.text, Tx("NewCareer"), cx, y + 330, "big", 1.05, "c")
    Text(L.text, Tx("SlotFree", k), cx, y + 374, "label", 1.1, "c")
    return
  end
  Quad(L.plate, ART.fill, x, y, w, B.HEAD, 1, nil, TINT.navy)
  Text(L.text, Tx("CareerN", k), x + 24, y + B.HEAD / 2, "title", 0.85)
  Text(L.text, Tx("SeasonN", s.season or 1), x + w - 100, y + B.HEAD / 2, "title_c", 0.7, "c")
  Crest(s.team, cx, y + 170, 2.6)
  Text(L.text, Fit(TeamName(s.team), w - 40, 32), cx, y + 300, "big", 1, "c")
  Quad(L.icon, ART.cyan, x + 24, y + 330, w - 48, 44)
  Text(L.text, Fit(SlotPhase(s), w - 80, 26), cx, y + 352, "body_w", 0.8, "c")
  local rows = {
    { Tx("SlotPlace"), (s.place or 0) > 0 and Tx("RankShort", s.place, s.points or 0) or "-" },
    { Tx("MarketBudget"), type(s.money) == "number" and s.money or "-" },
    { Tx("SlotLast"), type(s.date) == "table" and DateShort(s.date) .. "/" .. tostring(s.date.y or "") or "-" },
  }
  for i, r in ipairs(rows) do
    local ry = y + 426 + (i - 1) * 52
    if i % 2 == 1 then Quad(L.plate, ART.fill, x + 16, ry - 22, w - 32, 44, 1, nil, TINT.stripe) end
    Text(L.text, r[1], x + 30, ry, "label_l", 1)
    if type(r[2]) == "number" then MoneyAt(r[2], x + w * 0.7, ry, "body_c", 0.8, "c")
    else Text(L.text, Fit(r[2], w / 2 - 20, 26), x + w * 0.7, ry, "body_c", 0.8, "c") end
  end
end

local function DrawHome()
  local B = SLOTS
  local v = S.slots
  local list = v and v.slots or {}
  local used = 0
  for _, s in ipairs(list) do if s.used then used = used + 1 end end
  local ph = B.CARD_TOP + B.CARD_H + B.PAD
  Tile(B.x, B.y, B.w, ph, Tx("YourCareers"), "icon_list_tab_history01",
    v and Tx("CareersNote", v.game_slot or 1, used, #list) or "")
  local n = math.max(1, #list)
  local w = (B.w - 2 * B.PAD - B.GAP * (n - 1)) / n
  for k, slot in ipairs(list) do SlotCard(k, slot, B.x + B.PAD + (k - 1) * (w + B.GAP), w) end
  if S.state and S.state.ok == false then
    Text(L.text, Tx("NeedsBattleBayDeluxe"), B.x + B.w / 2, B.y + ph + 40, "outline_c", 1, "c")
  end
  local b = S.buttons[S.button]
  local s = b and list[b.slot]
  local keys = { s and s.used and Tx("KeyContinue") or Tx("KeyNewCareer") }
  if s and s.used then keys[#keys + 1] = Tx("KeyDelete") end
  keys[#keys + 1] = Tx("KeyExit")
  Footer(keys)
end

local function Tabs()
  return S.hub and S.hub.tabs or {}
end

-- the tab bar's box: the hub's (every tab, the team screen too) is the slim one; the club pick's game bar the full one
local function TabBox()
  return (S.mode == "dock" or S.mode == "hub") and G.TABS_DOCK or G.TABS
end

-- a tab bar in box b: items { { icon, text } } (text nil = icons only, centred), `sel` selected. The selected tab is
-- the retail plate at the bar's own scale (its sides lean as the bar's ends), copies side by side to fill the tab.
-- Each tab is a pointer zone { kind = "tab", index }.
local function TabBar(b, items, sel)
  b = b or TabBox()
  items = items or {}
  local T, P = G.TABS, ART.tab_on
  local z = b.h / T.h                 -- the slim bar's contents scaled with its height
  local sx = b.w / T.SPRITE_W         -- the bar sprite's horizontal scale (its slant on screen: SLANT * sx)
  Quad(L.panel, ART.strip, b.x, b.y, b.w, b.h)
  if #items == 0 then return end
  local top0 = b.x + T.BODY_L * sx
  local tw = (T.BODY_R - T.BODY_L) * sx / #items
  local lean = T.SLANT * sx           -- a slanted edge's shift from the body's top to its bottom
  local y0, y1 = b.y + T.BODY_TOP * z, b.y + T.BODY_BOTTOM * z
  for k, it in ipairs(items) do
    local a = top0 + (k - 1) * tw     -- the tab's top-left corner
    local on = k == sel
    if on then
      local span = (P.TOP_R - P.TOP_L) * sx
      local first, last = a - P.TOP_L * sx, a + tw - P.TOP_R * sx
      local n = math.max(1, math.ceil(tw / span))
      for c = 1, n do
        local x = n == 1 and first or first + (last - first) * (c - 1) / (n - 1)
        Quad(L.plate, P, x, y0 - P.TOP * z, P.w * sx, P.h * z)
      end
    end
    local mid = a - lean / 2          -- the tab's left edge at the bar's middle height
    if it.text ~= nil then
      if (it.icon or "") ~= "" then
        Quad(L.icon, { tex = TABS_TEX, sprite = it.icon }, mid + 20, b.y + (b.h - 40 * z) / 2, 60 * z, 40 * z, on and 1 or 0.7)
      end
      local name = Tx(it.text)
      local room = tw - 30 - 72 * z
      local sc = math.min(0.95 * z, room / math.max(1, Units(name) * 32 * TILE.DIGIT))
      Text(L.text, Fit(name, room, 32 * math.max(sc, 0.7 * z)), mid + 20 + 72 * z, b.y + b.h / 2, "title", math.max(sc, 0.7 * z))
    elseif (it.icon or "") ~= "" then
      local iw = math.min(72 * z, tw - 16)
      Quad(L.icon, { tex = TABS_TEX, sprite = it.icon }, mid + (tw - iw) / 2, b.y + (b.h - iw * 2 / 3) / 2, iw, iw * 2 / 3,
        on and 1 or 0.7)
    end
    S.zones[#S.zones + 1] = { x0 = a - lean, y0 = y0, x1 = a + tw, y1 = y1, kind = "tab", index = k }
  end
end

-- the tab keys in the tab bar's end caps: the bar's centre (as first = last tab centre) and the caps' offset from it
local CAP_SPEC = {
  LeftText = "<CMD_FUNCL1>", RightText = "<CMD_FUNCR1>", Priority = 1004,
  Measure = function()
    local b = TabBox()
    local cx = b.x + b.w / 2
    return cx, cx, -(b.y + b.h / 2)
  end,
  CapOffset = G.TABS.w / 2 - G.TABS.CAP_INSET, CapWidth = G.TABS.CAP_W,
}

-- shown with the hub's tab bar (more than one tab) and the club pick's game bar, hidden on the other pages
local function TabKeys(shown)
  if VRFW_TabBarCaps == nil or L_KEYS == 0 then return end
  CAP_SPEC.Layer = L_KEYS
  local caps = S.caps
  -- the bar moved (the team screen came or went): the prompts are placed again
  local box = TabBox()
  if caps.box ~= box then
    caps.box = box
    if caps.set then caps.pending, caps.tries = true, 0 end
  end
  if shown then
    if not caps.opened then VRFW_TabBarCaps.Open(caps, CAP_SPEC)
    elseif not caps.set and not caps.pending then caps.pending, caps.tries = true, 0 end
  elseif caps.set or caps.pending then
    VRFW_TabBarCaps.Hide(caps, CAP_SPEC)
  end
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

-- the club pick's layout (mock-up C): the hero (the focused club's crest, name, level, stars) left, the panel right
-- (its tabs: «Resumen» = line bars, formation, best players, the pick button; «Plantilla» = the squad), the strip of
-- the shown game's clubs below (the focused one framed, STRIP_N on screen)
local PICK = {
  HERO = { x = 60, y = 250, w = 830, h = 520, CREST_Y = 432, CREST_PX = 300, NAME_Y = 625, LEVEL_Y = 672,
    STARS_Y = 700 },
  EMBLEM_DIR = "#/menu/200_icon/01_icon_emblem/",   -- the crests' 512 px textures: <key>.g4tx, texture <key>
  LIST_CREST = 68,                                   -- the list crest's size at scale 1
  PANEL = { x = 920, y = 250, w = 940, h = 520, TAB_W = 220, TAB_H = 46, PAD = 36 },
  STRIP = { x = 60, y = 795, w = 1800, h = 205, N = 9, STEP = 180, CREST = 1.05, BOX = 128, Y = 905 },
  TABS = { "PanelSummary", "PanelSquad" },
  NAME_Y = 228,
  LINE = 3,
}

-- a flat plate (fill, optional outline) on the plate layer
function PICK.Plate(x, y, w, h, fill, line)
  if line then
    local t = PICK.LINE
    Quad(L.plate, ART.fill, x, y, w, t, 1, nil, line)
    Quad(L.plate, ART.fill, x, y + h - t, w, t, 1, nil, line)
    Quad(L.plate, ART.fill, x, y + t, t, h - 2 * t, 1, nil, line)
    Quad(L.plate, ART.fill, x + w - t, y + t, t, h - 2 * t, 1, nil, line)
  end
  Quad(L.plate, ART.fill, x, y, w, h, 1, nil, fill)
end

-- the hero: the crest big, the club's name, its level, its stars
function PICK.Hero(team, teams)
  local H = PICK.HERO
  Quad(L.panel, ART.navy, H.x, H.y, H.w, H.h)
  local cx = H.x + H.w / 2
  PICK.BigCrest(team, cx, H.CREST_Y, H.CREST_PX)
  Text(L.text, Fit(TeamName(team), H.w - 80, 32), cx, H.NAME_Y, "title_c", 1.5, "c")
  local rated = S.rate[team]
  if rated ~= nil and rated.level > 0 then
    PICK.Plate(cx - 110, H.LEVEL_Y - 20, 220, 40, TINT.select)
    Text(L.text, Tx("Level", rated.level), cx, H.LEVEL_Y, "body_w", 0.9, "c")
  end
  StarsRow(Stars(team, teams) or 0, cx - 112, H.STARS_Y, 40)
end

-- the focused club's crest px wide from its 512 px emblem texture (team info -> emblem id -> its key, asked once per
-- club); the list crest while the key is asked or the texture loads
function PICK.BigCrest(team, cx, cy, px, layer, alpha, no_fallback)
  S.emblem_keys = S.emblem_keys or {}
  local key = S.emblem_keys[team]
  if key == nil then
    local ok, has, id = pcall(funcLuaCommand, C.TEAM_INFO, team, 6, 0)
    key = false
    if ok and has and type(id) == "number" then
      local v = Call("CMND_CAREERMODE_EMBLEM_KEY", id)
      if v == nil then
        -- the scripts are busy: asked again on the next draw
        S.dirty = true
        if not no_fallback then Crest(team, cx, cy, px / PICK.LIST_CREST) end
        return
      end
      key = v.ok and v.key ~= "" and v.key or false
      -- the emblem's colour bucket (content/career/emblem_colours.toml): the news card's gradient
      S.emblem_colours = S.emblem_colours or {}
      S.emblem_colours[team] = v.ok and type(v.colour) == "string" and v.colour ~= "" and v.colour or nil
    end
    S.emblem_keys[team] = key
  end
  if key and Quad(layer or L.icon, { tex = PICK.EMBLEM_DIR .. key .. ".g4tx", sprite = key }, cx - px / 2, cy - px / 2,
    px, px, alpha) then
    return true
  end
  if not no_fallback then Crest(team, cx, cy, px / PICK.LIST_CREST) end
end

-- the panel's tabs (a click picks one, X turns them)
function PICK.Tabs(Pn)
  local sel = S.pick.panel or 1
  for k, key in ipairs(PICK.TABS) do
    local x = Pn.x + Pn.PAD + (k - 1) * (Pn.TAB_W + 12)
    local y = Pn.y + 24
    PICK.Plate(x, y, Pn.TAB_W, Pn.TAB_H, k == sel and TINT.select or TINT.chip, k == sel and TINT.cut or nil)
    Text(L.text, Tx(key), x + Pn.TAB_W / 2, y + Pn.TAB_H / 2, k == sel and "body_w" or "body_c", 0.85, "c")
    S.zones[#S.zones + 1] = { x0 = x, y0 = y, x1 = x + Pn.TAB_W, y1 = y + Pn.TAB_H, kind = "ppanel", index = k }
  end
end

-- «Resumen»: the line bars, the formation, the best players, the pick button
function PICK.Summary(team, teams, Pn, players)
  local x, y = Pn.x + Pn.PAD, Pn.y + 110
  Text(L.text, Tx("Rating"), x, y, "label_l", 1.2)
  if players ~= nil then
    local ln = Lines(players)
    local scale = Scale(teams)
    Bar(Tx("LineAttack"), ln.attack, scale, x, y + 50, 260)
    Bar(Tx("LineMidfield"), ln.midfield, scale, x, y + 100, 260)
    Bar(Tx("LineDefence"), ln.defence, scale, x, y + 150, 260)
    Text(L.text, Tx("Formation", ln.shape), x, y + 215, "body", 1.0)
    local bx = Pn.x + Pn.w / 2 + 20
    local bw = Pn.x + Pn.w - Pn.PAD - bx
    Text(L.text, Tx("BestPlayers"), bx, y, "label_l", 1.2)
    for k = 1, math.min(S.rules.best_players, #players) do
      local p = players[k]
      local ry = y + 52 + (k - 1) * 58
      PICK.Plate(bx, ry - 25, bw, 50, TINT.stripe)
      Face(p.card, bx + 30, ry, 46, team)
      Text(L.text, Fit(p.name ~= "" and p.name or "-", bw - 150, 28), bx + 64, ry, "body", 0.92)
      PICK.Plate(bx + bw - 62, ry - 19, 54, 38, TINT.navy)
      Text(L.text, tostring(p.rating), bx + bw - 35, ry, "body_w", 0.95, "c")
    end
  end
  -- the pick button: A
  local by = Pn.y + Pn.h - 110
  local bw = Pn.w / 2 - Pn.PAD - 10
  Quad(L.plate, ART.play, x, by, bw, 68)
  Text(L.text, Fit(Tx("PickClub", TeamName(team)), bw - 40, 32), x + bw / 2, by + 34, "body_w", 1.1, "c")
  S.zones[#S.zones + 1] = { x0 = x, y0 = by, x1 = x + bw, y1 = by + 68, kind = "fn", name = "career_accept" }
end

-- «Plantilla»: the squad by rating in two columns (miniface, name, position, level, rating)
function PICK.Squad(team, Pn, players)
  if players == nil then return end
  local per = 9
  local cw = (Pn.w - 2 * Pn.PAD - 24) / 2
  for k = 1, math.min(#players, 2 * per) do
    local p = players[k]
    local col, row = math.floor((k - 1) / per), (k - 1) % per
    local x = Pn.x + Pn.PAD + col * (cw + 24)
    local y = Pn.y + 112 + row * 44
    if row % 2 == 0 then PICK.Plate(x, y - 20, cw, 40, TINT.stripe) end
    Face(p.card, x + 24, y, 38, team)
    Text(L.text, Fit(p.name ~= "" and p.name or "-", cw - 230, 26), x + 52, y, "body", 0.8)
    Text(L.text, Tx(POS_TEXT[p.position] or "PosMF"), x + cw - 150, y, "body_c", 0.8, "c")
    Text(L.text, Tx("LevelShort", p.level), x + cw - 90, y, "body_c", 0.75, "c")
    Text(L.text, tostring(p.rating), x + cw - 30, y, "big", 0.85, "c")
  end
end

-- the strip of the shown game's clubs: STRIP.N crests centred on the focused one (framed); a click moves to one
function PICK.Strip(teams)
  local St = PICK.STRIP
  local n = #teams
  Quad(L.panel, ART.navy, St.x, St.y, St.w, St.h)
  Text(L.text, Tx("ClubOf", S.pick.sel, n), St.x + St.w / 2, St.y + 30, "title_c", 0.8, "c")
  local cx = St.x + St.w / 2
  -- all clubs in order when they fit, else a window centred on the focused one (wrapping round)
  local shown = math.min(St.N, n)
  local first = n <= St.N and 1 - S.pick.sel or -math.floor(St.N / 2)
  for k = 0, shown - 1 do
    local d = first + k
    local x = cx + (n <= St.N and (k - (shown - 1) / 2) or d) * St.STEP
    if d == 0 then
      PICK.Plate(x - St.BOX / 2, St.Y - St.BOX / 2, St.BOX, St.BOX, TINT.select, TINT.cut)
    end
    Crest(teams[(S.pick.sel - 1 + d) % n + 1], x, St.Y, St.CREST * (d == 0 and 1.25 or 1), d == 0 and 1 or 0.65)
    if d ~= 0 then
      S.zones[#S.zones + 1] = { x0 = x - St.STEP / 2, y0 = St.Y - St.BOX / 2, x1 = x + St.STEP / 2,
        y1 = St.Y + St.BOX / 2, kind = "move", dx = d, dy = 0 }
    end
  end
  if n > 1 then
    Quad(L.icon, ART.arrow, St.x + 30, St.Y - 26, 46, 52, 1, true)
    Quad(L.icon, ART.arrow, St.x + St.w - 76, St.Y - 26, 46, 52)
    S.zones[#S.zones + 1] = { x0 = St.x + 20, y0 = St.Y - 40, x1 = St.x + 90, y1 = St.Y + 40, kind = "move", dx = -1, dy = 0 }
    S.zones[#S.zones + 1] = { x0 = St.x + St.w - 90, y0 = St.Y - 40, x1 = St.x + St.w - 20, y1 = St.Y + 40, kind = "move",
      dx = 1, dy = 0 }
  end
end

local function DrawPick()
  local teams = PickTeams()
  local n = #teams
  -- the game selector: a tab bar of the games' series icons (L1 / R1 in its end caps, a click picks one), the shown
  -- game's name under it
  local games = {}
  for i = 1, #(S.draw.leagues or {}) do
    local g = S.draw.groups and S.draw.groups[i] or 0
    games[i] = { icon = (g >= 1 and g <= 9) and string.format(SERIES_ICON, g) or "" }
  end
  TabBar(G.TABS, games, S.pick.league)
  Text(L.text, GroupName(S.pick.league), 960, PICK.NAME_Y, "outline_c", 1.05, "c")
  local team = teams[S.pick.sel]
  if team ~= nil then
    PICK.Hero(team, teams)
    local Pn = PICK.PANEL
    Quad(L.panel, ART.white, Pn.x, Pn.y, Pn.w, Pn.h)
    PICK.Tabs(Pn)
    local players = Players(team)
    if players ~= nil then table.sort(players, function(x, y) return x.rating > y.rating end) end
    if (S.pick.panel or 1) == 2 then PICK.Squad(team, Pn, players) else PICK.Summary(team, teams, Pn, players) end
    PICK.Strip(teams)
  end
  Footer({ Tx("KeyAccept"), Tx("KeyBack"), Tx("KeyGame"), Tx("KeyClub"), Tx("KeyPanel") })
end

-- ---- hub ------------------------------------------------------------------------------------------------------------

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

-- the competitions in their L2 / R2 order (CMND_CAREERMODE_COMPETITIONS: { ok, items = { { index, kind, key, league } },
-- default }, asked once per hub data), else the hub's competition list (its order = the standings' index)
function COMPETITION.List()
  local c = S.comps
  if c == nil or c.hub ~= S.hub then
    local v = Call("CMND_CAREERMODE_COMPETITIONS")
    local items = {}
    if v and v.ok and type(v.items) == "table" then
      for _, e in ipairs(v.items) do items[#items + 1] = e end
    else
      for i, e in ipairs(S.hub and S.hub.competition_list or {}) do
        items[#items + 1] = { index = i, kind = e.kind, league = e.league, group = e.group, tree = e.tree }
      end
    end
    c = { hub = S.hub, items = items }
    S.comps = c
  end
  return c.items
end

-- the page's header: a navy band with the shown competition's name in the middle, L2 / R2 arrows at its ends (a click
-- shows the previous / next one), a small chip per competition under the name (the shown one lit; a click shows that
-- one) and the last round played on the right; panel = the white page under it too (the groups; a knockout draws only
-- the band)
local function CompetitionHeader(t, panel)
  local P = G.PAGE
  local C_ = COMPETITION
  local mid = P.y + BRACKET.HEAD_H / 2
  if panel then Quad(L.panel, ART.white, P.x, P.y, P.w, P.h) end
  Quad(L.plate, ART.fill, P.x, P.y, P.w, BRACKET.HEAD_H, 1, nil, TINT.navy)
  local list = C_.List()
  local _, index = TableNow()
  local title = Fit(TableTitle(t), C_.NAME_W, 30)
  local ty = mid - (#list > 1 and 7 or 0)
  Text(L.text, title, P.x + P.w / 2, ty, "title_c", 0.9, "c")
  if #list < 2 then return end
  -- the L2 / R2 glyphs either side of the title (the key prompts pair; a click on one: that way)
  local half = math.min(C_.NAME_W, Units(title) * 32 * 0.9 * TILE.DIGIT) / 2 + C_.KEY_GAP + C_.KEY / 2
  local a, b = P.x + P.w / 2 - half, P.x + P.w / 2 + half
  S.head_prompt = { a = a, b = b, y = ty + S.dy, left = "<CMD_FUNCL2>", right = "<CMD_FUNCR2>" }
  for _, side in ipairs({ { -1, a }, { 1, b } }) do
    S.zones[#S.zones + 1] = { x0 = side[2] - C_.KEY, y0 = P.y, x1 = side[2] + C_.KEY, y1 = P.y + BRACKET.HEAD_H,
      kind = "cstep", d = side[1] }
  end
  local n = #list
  local left = P.x + P.w / 2 - (n * C_.DOT + (n - 1) * C_.DOT_GAP) / 2
  local dy = mid + C_.DOT_Y
  for i, e in ipairs(list) do
    local x = left + (i - 1) * (C_.DOT + C_.DOT_GAP)
    Quad(L.plate, ART.fill, x, dy, C_.DOT, C_.DOT_H, 1, nil, e.index == index and TINT.cut or TINT.rest)
    S.zones[#S.zones + 1] = { x0 = x - C_.DOT_GAP / 2, y0 = dy - 8, x1 = x + C_.DOT + C_.DOT_GAP / 2, y1 = dy + C_.DOT_H + 8,
      kind = "comp", index = e.index }
  end
  local played = 0
  for _, r in ipairs(t.rows or {}) do played = math.max(played, r.played or 0) end
  if played > 0 then
    Text(L.text, Tx("AfterRound", played), P.x + P.w - C_.ROUND_X, mid, "title_c", 0.72, "c")
  end
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

-- a club's place and points in the table of «Inicio»: «4.º · 8 pts»; "" when the club is not in it
local function RankText(h, team)
  for k, r in ipairs(h.table and h.table.rows or {}) do
    if r.team == team then return Tx("RankShort", k, r.points or 0) end
  end
  return ""
end

-- a club's plate: the list bar tinted, the crest at its outer end, the name centred in the rest
local function Plate(team, x, y, w, h, tint, crest_right)
  Quad(L.plate, ART.row, x, y, w, h, 1, nil, tint)
  local crest_x = crest_right and (x + w - 44) or (x + 44)
  Crest(team, crest_x, y + h / 2, 0.62)
  local name_x = crest_right and (x + (w - 88) / 2) or (x + 88 + (w - 88) / 2)
  Text(L.text, Fit(TeamName(team), w - 120, 28), name_x, y + h / 2, "outline_c", 0.95, "c")
end

-- the «Inicio» tiles (px at 1080p): the next match across the top, the table below it on the left, the week, the
-- form and the budget beside the table (the news feed, FEED, on the right)
local HOME = {
  -- «Próximo partido»: the clubs and VS, the days' line (LINE_TL_Y, LINE_X px from the card's sides, LINE_H thick; at
  -- most SLOTS days shown, PAST of them before today; round marks DOT / DOT_TODAY px, each day's label DAY_LABEL_Y px
  -- above its mark, the events' chips EVENT_Y px under it, CHIP_H tall), the
  -- bottom band (BAND_H px: the key prompts centred; texts at BAND_TEXT scale,
  -- key glyphs KEY px with KEY_GAP px to their label, PROMPT_GAP px between the prompts)
  NEXT = { x = 60, y = 222, w = 1320, h = 300, CREST_X = 150, CREST_Y = 116, CREST = 1.3, CREST_HALF = 46, VS_W = 120,
    LINE_Y = 142, NAME_Y = 102, LINE_TL_Y = 200, LINE_X = 90, LINE_H = 6, SLOTS = 8, PAST = 2, DOT = 16,
    DOT_TODAY = 26, DAY_LABEL_Y = 24, EVENT_Y = 26, CHIP_H = 24, BAND_H = 58, BAND_TEXT = 0.8, KEY = 40, KEY_GAP = 10,
    PROMPT_GAP = 34 },
  TABLE = { x = 60, y = 538, w = 690, h = 462, ROWS = 8, STEP = 42, HEAD = 74, FIRST = 116, NAME_W = 320 },
  WEEK = { x = 770, y = 538, w = 610, h = 160, TOP = 60, CELL_H = 92, GAP = 8, CREST = 0.4 },
  -- «Forma»: the chips on the left, the board's objectives in their own column on the right (a heading, then a line each)
  -- (the chips share the width left of the objectives' column: config [hub] form_matches of them, at most CHIP_STEP
  -- apart; OBJ_W: the column's width from the right edge)
  FORM = { x = 770, y = 714, w = 610, h = 140, CHIP_STEP = 46, CHIP_GAP = 5, CHIP_Y = 72, OBJ_W = 250, OBJ_HEAD_Y = 64,
    OBJ_Y = 86, OBJ_STEP = 19, MARK = 12 },
  -- «Presupuesto»: the amount with the currency icon after it, the window's line under it
  BUDGET = { x = 770, y = 870, w = 610, h = 130, MONEY_Y = 80, LINE_Y = 112 },
}

-- the board's objectives (hub / setup `objectives`: { { kind, target, state } }): one line each from (x, y), a mark
-- tinted by its state (met, missed, still open) left of the text
local OBJECTIVE_TINT = { met = TINT.win, missed = TINT.loss, open = TINT.draw }
function HOME.Objectives(list, x, y, step, w, mark, style, sc)
  for k, o in ipairs(type(list) == "table" and list or {}) do
    local ly = y + (k - 1) * step
    local text
    if o.kind == "superliga" then text = Tx("ObjSuperLiga", o.target)
    elseif o.kind == "league" then text = Tx("ObjLeague", o.target)
    else
      text = Tx("ObjFrontier", o.target == "Champion" and Tx("Champion") or Tx("Frontier" .. tostring(o.target) .. "Short"))
    end
    Quad(L.plate, ART.row, x, ly - mark / 2, mark, mark, 1, nil, OBJECTIVE_TINT[o.state] or TINT.draw)
    Text(L.text, Fit(text, w, 22), x + mark + 10, ly, style or "label_l", sc or 1)
  end
end

-- the days from the last event to the match under «Próximo partido» (hub days.stretch: { from, to, now, match_day,
-- days = { dates }, events = { { day, kind } } }): a window of at most SLOTS days on a line across the card (PAST days
-- before today, then the next ones; when the match is further, the last slot is the match day after a «…» break, and
-- the window slides on as the days go by), a round mark per day (the days gone lit, the event days in their colour,
-- today larger on a white ring), each day's weekday and number above its mark (today's in the bold style), the
-- events' names in chips of their colour under their marks; the line lit up to today. While the days are walked the
-- today mark and the lit part slide from the day before (HOME.WalkAt)
HOME.STRETCH_TINT = { window_open = TINT.win, window_close = TINT.loss, draw = TINT.direct, offer = TINT.orange,
  match = TINT.gold }
HOME.STRETCH_TEXT = { window_open = "DayEventWindowOpen", window_close = "DayEventWindowClose", draw = "DayEventDraw",
  offer = "DayEventOffer", match = "DayEventMatch" }

-- a round mark of a TINT colour (its sprite career_dot_<name> in the same atlas as career_tint_<name>)
HOME.DOT_ART = {}
function HOME.Dot(x, y, size, tint)
  local art = HOME.DOT_ART[tint.sprite]
  if art == nil then
    art = { tex = tint.tex, sprite = (tint.sprite:gsub("^career_tint_", "career_dot_")) }
    HOME.DOT_ART[tint.sprite] = art
  end
  Quad(L.icon, art, x - size / 2, y - size / 2, size, size)
end

function HOME.Stretch(st, B)
  local days = st.days or {}
  if #days < 2 or st.now == nil then return end
  local now = st.now.day
  local by_day = {}
  for _, v in ipairs(days) do by_day[v.day] = v end
  local last = days[#days].day
  -- the window's days (false = the break before the match day)
  local start = math.max(days[1].day, now - B.PAST)
  local slots = {}
  if last - start + 1 <= B.SLOTS then
    for d = start, last do slots[#slots + 1] = by_day[d] or false end
  else
    for d = start, start + B.SLOTS - 3 do slots[#slots + 1] = by_day[d] or false end
    slots[#slots + 1] = false
    slots[#slots + 1] = days[#days]
  end
  local x0, x1 = B.x + B.LINE_X, B.x + B.w - B.LINE_X
  local y = B.y + B.LINE_TL_Y
  local step = (x1 - x0) / math.max(1, #slots - 1)
  -- a day's x on the line (a fractional day between two shown days: between their marks)
  local function DayX(day)
    for k, v in ipairs(slots) do
      if v and v.day >= day then
        local prev = slots[k - 1]
        if v.day == day or not prev then return x0 + (k - 1) * step end
        return x0 + (k - 2 + (day - prev.day) / (v.day - prev.day)) * step
      end
    end
    return x1
  end
  local at = HOME.WalkAt(now)
  local tx = DayX(at)
  Quad(L.plate, ART.fill, x0, y - B.LINE_H / 2, x1 - x0, B.LINE_H, 1, nil, TINT.rest)
  if tx > x0 then Quad(L.plate, ART.fill, x0, y - B.LINE_H / 2, tx - x0, B.LINE_H, 1, nil, TINT.cut) end
  local kinds = {}
  for _, e in ipairs(st.events or {}) do kinds[e.day.day] = kinds[e.day.day] or e.kind end
  kinds[last] = "match"
  for k, v in ipairs(slots) do
    local x = x0 + (k - 1) * step
    if not v then
      Text(L.text, "…", x, y - 4, "body_c", 0.9, "c")
    else
      local kind = kinds[v.day]
      local today = v.day == now
      local tint = kind and HOME.STRETCH_TINT[kind] or (v.day <= at and TINT.cut or TINT.rest)
      if not today or at ~= now then HOME.Dot(x, y, B.DOT, tint) end
      Text(L.text, Tx("Weekday" .. v.wd) .. " " .. v.d, x, y - B.DAY_LABEL_Y, today and "body_c" or "label",
        today and 0.7 or 0.85, "c")
      if kind then
        local name = Tx(HOME.STRETCH_TEXT[kind])
        local cw = Units(name) * 28 * GLYPH * 0.6 + 18
        Quad(L.plate, ART.row, x - cw / 2, y + B.EVENT_Y - B.CHIP_H / 2, cw, B.CHIP_H, 1, nil, tint)
        Text(L.text, name, x, y + B.EVENT_Y, "body_w", 0.6, "c")
      end
    end
  end
  -- today: a larger mark on a white ring where the slide is (on its day once the slide is over)
  local kind = kinds[now]
  HOME.Dot(tx, y, B.DOT_TODAY + 6, TINT.white)
  HOME.Dot(tx, y, B.DOT_TODAY, kind and HOME.STRETCH_TINT[kind] or TINT.cut)
end

-- two key prompts on the page: two instances of the change-page plate layer career_prompts, only their key glyphs
-- shown (the engine draws the keys of the device in use): «Próximo partido»'s band (A and Y), Torneos' header (L2 and
-- R2). HOME.prompt / S.head_prompt { a, b, y[, left, right] } (the glyphs' centres, screen px; the keys' glyph
-- tags, A / Y when absent) is set by the draw that shows them, nil hides them
HOME.L_PROMPTS = 0
HOME.PROMPT_SPEC = {
  LeftText = "<CMD_ENTER>", RightText = "<CMD_FUNC3>", Priority = 1004, CapWidth = HOME.NEXT.KEY - 6,
  Measure = function()
    local p = HOME.prompt_at
    if p == nil then return nil end
    return p.mid, p.mid, -p.y
  end,
}
-- the Torneos switch's Y glyph: the pair of its own layer on one spot (both instances the Y glyph)
HOME.L_SWITCH = 0
HOME.SWITCH_SPEC = {
  LeftText = "<CMD_FUNC3>", RightText = "<CMD_FUNC3>", Priority = 1004, CapWidth = 30,   -- the glyph at 36 px
  Measure = function()
    local p = HOME.switch_at
    if p == nil then return nil end
    return p.mid, p.mid, -p.y
  end,
}
function HOME.PromptKeys(p)
  HOME.Glyphs(HOME.PROMPT_SPEC, S.prompts, HOME.L_PROMPTS, "prompt_at", p)
end

-- a glyph pair (p = { a, b: the glyphs' centres x, y, left, right: their texts }) of a 2-instance change-page layer
-- shown at p, nil hides it; `at` names the HOME field its spec's Measure reads
function HOME.Glyphs(spec, st, layer, at, p)
  if VRFW_TabBarCaps == nil or layer == 0 or st == nil then return end
  spec.Layer = layer
  if p then
    local left, right = p.left or "<CMD_ENTER>", p.right or "<CMD_FUNC3>"
    local key = string.format("%d:%d:%d", p.a, p.b, p.y)
    HOME[at] = { mid = (p.a + p.b) / 2, y = p.y }
    spec.CapOffset = (p.b - p.a) / 2
    -- other keys: hidden first (the glyphs are set when the pair is shown again)
    if st.texts ~= left .. right and (st.set or st.pending) then VRFW_TabBarCaps.Hide(st, spec) end
    st.texts, spec.LeftText, spec.RightText = left .. right, left, right
    if not st.opened then VRFW_TabBarCaps.Open(st, spec)
    elseif st.key ~= key or (not st.set and not st.pending) then st.pending, st.tries = true, 0 end
    st.key = key
  elseif st.set or st.pending then
    VRFW_TabBarCaps.Hide(st, spec)
    st.key = nil
  end
end

-- «Próximo partido»'s bottom band (gold on the match day): the A / Y prompts centred in it (A: «Continuar» / «Jugar»,
-- Y: «Ir al partido» / «Simular»); A's prompt is a hub button, Y's a zone for the Y key (the pointer clicks either)
function HOME.Band(st, B)
  local gold = st ~= nil and st.match_day
  local walk = st ~= nil and not st.match_day
  local by = B.y + B.h - B.BAND_H
  local mid = by + B.BAND_H / 2
  local style = gold and "item" or "title"
  Quad(L.plate, ART.fill, B.x, by, B.w, B.BAND_H, 1, nil, gold and TINT.gold or TINT.navy)
  local a_label, y_label = Tx(walk and "DayContinue" or "Play"), Tx(walk and "DayToMatch" or "Simulate")
  local unit = 32 * GLYPH * B.BAND_TEXT
  local a_w, y_w = Units(a_label) * unit, Units(y_label) * unit
  local total = 2 * (B.KEY + B.KEY_GAP) + a_w + y_w + B.PROMPT_GAP
  local a_glyph = B.x + (B.w - total) / 2 + B.KEY / 2
  local a_end = a_glyph + B.KEY / 2 + B.KEY_GAP + a_w
  local y_glyph = a_end + B.PROMPT_GAP + B.KEY / 2
  local right = y_glyph + B.KEY / 2 + B.KEY_GAP + y_w
  Text(L.text, a_label, a_end - a_w, mid, style, B.BAND_TEXT)
  Text(L.text, y_label, right - y_w, mid, style, B.BAND_TEXT)
  S.buttons[#S.buttons + 1] = { x0 = a_glyph - B.KEY / 2 - 6, y0 = by, x1 = a_end + 6, y1 = by + B.BAND_H,
    action = walk and "day" or "play" }
  S.zones[#S.zones + 1] = { x0 = y_glyph - B.KEY / 2 - 6, y0 = by, x1 = right + 6, y1 = by + B.BAND_H, kind = "fn",
    name = "career_redraw" }
  HOME.prompt = { a = a_glyph, b = y_glyph, y = mid + S.dy }
end

-- the next match (or what the season does next) across the top: both clubs' crests at the ends, their names, home /
-- away, place and points between them and VS, the days' line under them and the band with today and the key prompts
function HOME.Next(h)
  local n = h.next or {}
  local B = HOME.NEXT
  local cx = B.x + B.w / 2
  local note = n.kind == "match" and RoundName(n.label, n.n) or DateLong(n.date)
  Tile(B.x, B.y, B.w, B.h, Tx("NextMatch"), "icon_list_tab_battle01", note)
  if n.kind == "match" then
    local st = h.days and h.days.stretch
    local me = Me(h)
    local home = n.home == me
    local rival = home and n.away or n.home
    local vs_half = B.VS_W / 2
    for _, side in ipairs({ { me, -1, home }, { rival, 1, not home } }) do
      local d = side[2]
      local sx = cx + d * (B.w / 2 - B.CREST_X)
      Crest(side[1], sx, B.y + B.CREST_Y, B.CREST)
      -- the name and its line centred between the crest and VS
      local inner, outer = cx + d * vs_half, sx - d * B.CREST_HALF
      local nx, room = (inner + outer) / 2, math.abs(outer - inner) - 20
      Text(L.text, Fit(TeamName(side[1]), room, 32), nx, B.y + B.NAME_Y, "big", 0.95, "c")
      local rank = RankText(h, side[1])
      local line = (side[3] and Tx("Home") or Tx("Away")) .. (rank ~= "" and ("  ·  " .. rank) or "")
      Text(L.text, Fit(line, room, 24), nx, B.y + B.LINE_Y, "body_c", 0.85, "c")
    end
    local vh = B.VS_W * ART.vs.h / ART.vs.w
    Quad(L.icon, ART.vs, cx - vs_half, B.y + B.CREST_Y - vh / 2, B.VS_W, vh)
    if st then HOME.Stretch(st, B) elseif n.date then
      Text(L.text, DateLong(n.date), cx, B.y + B.LINE_TL_Y, "label", 1.1, "c")
    end
    HOME.Band(st, B)
  elseif n.kind == "round" then
    Text(L.text, RoundName(n.label, n.n), cx, B.y + 100, "big", 1, "c")
    Text(L.text, h.out and Tx("OutOfCompetition") or Tx("NoMatchThisRound"), cx, B.y + 150, "body_c", 1.0, "c")
    Button(Tx("SimulateRound"), "next", cx - 190, B.y + 200, 380, 64)
  elseif n.kind == "wc_call" then
    Text(L.text, Tx("WorldCupOfferTitle"), cx, B.y + 92, "big", 1.05, "c")
    Crest(n.side, cx - 420, B.y + 180, 1.4)
    Text(L.text, Tx("WorldCupOffer"), cx - 320, B.y + 140, "label_l", 1.1)
    Text(L.text, Fit(TeamName(n.side), 440, 32), cx - 320, B.y + 180, "big", 1)
    Text(L.text, Tx("WorldCupOffer2", h.worldcup and h.worldcup.squad or 0), cx - 320, B.y + 218, "label_l", 1.05)
    Button(Tx("WorldCupPick"), "next", cx + 200, B.y + 150, 380, 64)
  elseif n.kind == "draw" then
    Text(L.text, Tx("DrawTitle"), cx, B.y + 100, "big", 1.05, "c")
    Text(L.text, Tx("DrawLine", h.superliga_place, h.qualify), cx, B.y + 150, "body_c", 1, "c")
    Button(Tx("DrawShow"), "next", cx - 190, B.y + 200, 380, 64)
  elseif n.kind == "over" then
    Text(L.text, Tx("SeasonOver", h.season), cx, B.y + 92, "big", 1.05, "c")
    local why = h.out_reason ~= "" and Tx("Out_" .. h.out_reason, h.superliga_place, h.qualify) or Tx("Reached_" .. h.reached)
    Text(L.text, Fit(why, 900, 28), cx, B.y + 136, "body_c", 1, "c")
    if (h.champion or 0) ~= 0 then
      Text(L.text, Tx("Champion"), B.x + 60, B.y + 196, "label_l", 1.1)
      Crest(h.champion, B.x + 100, B.y + 248, 0.9)
      Text(L.text, Fit(TeamName(h.champion), 420, 32), B.x + 150, B.y + 248, "big", 0.9)
    end
    Button(Tx("NextSeason"), "next", cx + 200, B.y + 205, 380, 64)
  elseif n.kind == "sacked" then
    -- the board sacked the manager: the career ends here, its pages stay to look at
    Text(L.text, Tx("SackedTitle"), cx, B.y + 100, "big", 1.2, "c")
    Crest(h.team, B.x + 150, B.y + 190, 1.3)
    Text(L.text, Fit(Tx("SackedLine", TeamName(h.team), h.season), 900, 28), cx, B.y + 160, "body_c", 1, "c")
    Text(L.text, Fit(Tx("SackedLine2"), 900, 28), cx, B.y + 205, "label", 1.1, "c")
  end
end

-- the colour of a table place: the SuperLiga's places by the pot they go to in the draw (the scripts' pot_tint),
-- the places that go straight through (leagues, groups), the places that may
local function ZoneTint(t, k, r)
  if t.kind == "superliga" and r and r.pot_tint then return TINT[r.pot_tint] end
  if (t.kind == "league" or t.kind == "group") and k <= (t.direct or 0) then return TINT.direct end
  if t.cut and k <= t.cut then return TINT.cut end
  return nil
end

-- a table row between x0 and x1 centred on y, step px tall: the player's club lit (gold frame), every other row
-- striped, the zone's colour at its left edge, place, crest, name and the columns { { x, value } }
local function TableRow(h, t, k, r, x0, x1, y, step, cols, name_w)
  local mine = r.team == Me(h)
  local top, hh = y - step / 2 + 2, step - 4
  if mine then
    Quad(L.plate, ART.fill, x0, top, x1 - x0, hh, 1, nil, TINT.mine)
    Frame(L.icon, x0, top, x1 - x0, hh, 3, TINT.gold)
  elseif k % 2 == 1 then
    Quad(L.plate, ART.fill, x0, top, x1 - x0, hh, 1, nil, TINT.stripe)
  end
  local zone = ZoneTint(t, k, r)
  if zone then Quad(L.icon, ART.fill, x0, top + 2, 6, hh - 4, 1, nil, zone) end
  Text(L.text, tostring(k), x0 + 30, y, "body_c", 0.8, "c")
  local crest = step * 0.74 / 68
  Crest(r.team, x0 + 70, y, crest)
  Text(L.text, Fit(TeamName(r.team), name_w, 28), x0 + 76 + 34 * crest, y, "item", 0.78)
  for c, col in ipairs(cols) do
    Text(L.text, tostring(col[2](r)), col[1], y, c == #cols and "big" or "body_c", 0.8, "c")
  end
end

-- the table columns' values
local function Diff(r)
  local d = (r.goals_for or 0) - (r.goals_against or 0)
  return (d > 0 and "+" or "") .. d
end
local VALUE = {
  played = function(r) return r.played or 0 end, won = function(r) return r.won or 0 end,
  drawn = function(r) return r.drawn or 0 end, lost = function(r) return r.lost or 0 end, diff = Diff,
  points = function(r) return r.points or 0 end,
}

-- the table of «Inicio» around the club: place, crest, name, played, goal difference, points
function HOME.Table(h)
  local t = h.table or { rows = {} }
  local B = HOME.TABLE
  local rows = t.rows or {}
  local played = 0
  for _, r in ipairs(rows) do played = math.max(played, r.played or 0) end
  Tile(B.x, B.y, B.w, B.h, TableTitle(t), "icon_list_tab_vroad01", played > 0 and Tx("AfterRound", played) or nil)
  local me = 1
  for k, r in ipairs(rows) do
    if r.team == Me(h) then me = k end
  end
  local from = math.max(1, math.min(me - math.floor((B.ROWS - 1) / 2), #rows - B.ROWS + 1))
  local x0, x1 = B.x + 16, B.x + B.w - 16
  local cols = { { x1 - 196, VALUE.played }, { x1 - 110, VALUE.diff }, { x1 - 36, VALUE.points } }
  local head_y = B.y + B.HEAD
  Text(L.text, Tx("ColTeam"), x0 + 70, head_y, "label_l", 1)
  for c, key in ipairs({ "ColPlayed", "ColDiff", "ColPoints" }) do Text(L.text, Tx(key), cols[c][1], head_y, "label", 1, "c") end
  for k = from, math.min(#rows, from + B.ROWS - 1) do
    TableRow(h, t, k, rows[k], x0, x1, B.y + B.FIRST + (k - from) * B.STEP, B.STEP, cols, B.NAME_W)
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

-- the form chips (oldest first) from x, y: size px squares, step px apart
local FORM_TINT = { W = TINT.win, D = TINT.draw, L = TINT.loss }
local function FormChips(h, x, y, size, step)
  local form = h.form or {}
  for k = 1, h.form_matches or 5 do
    local f = form[k]
    Quad(L.plate, ART.row, x + (k - 1) * step, y, size, size, f and 1 or 0.35, nil, FORM_TINT[f] or TINT.draw)
    Text(L.text, f and Tx("Form" .. f) or "-", x + (k - 1) * step + size / 2, y + size / 2, "body_w", size / 50, "c")
  end
  return #form
end


-- ---- «Inicio» › «Noticias»: a vertical feed of portrait cards (one at a time, the next one's edge below it) --------

-- the feed's window (px), one card (about 9:16), the slide's length (frames)
-- the news card (owner pick noticias3_A; no counter): the transfer block centred on top (the crest of the club
-- the player leaves > the crest of the club he joins, the fee under the arrow), the player's 3D model over the card's
-- gradient and the club's crest drawn faint, the tag and date, two title lines and two body lines at the bottom, a
-- thin progress bar under them
local FEED = { x = 1410, y = 222, w = 450, h = 778, CARD_H = 778, SLIDE = 12, SLIDE_UP = 40, SLIDE_SIDE = 60, SHADE = 6,
  FACE = 420,
  GHOST = 380, GHOST_Y = 0.42, GHOST_ALPHA = 0.2, TOP = 56, CREST = 0.85, CREST_DX = 92, TAG_Y = 196, TITLE_Y = 142,
  TITLE = 33, BODY_Y = 70, BODY = 23, BAR_H = 4, BAR_Y = 12, TRANSFER_DOWN = 16,
  BG = "#/menu/220_img/career_news_bg/career_news_bg.g4tx", BG_DEFAULT = "green" }

-- the news card's gradient: the strip of the club's emblem colour (its bucket, asked with the big crest), else green
function FEED.Background(team)
  local bucket = S.emblem_colours and S.emblem_colours[team or 0] or FEED.BG_DEFAULT
  return { tex = FEED.BG, sprite = "career_news_bg_" .. bucket }
end
-- the tag colours of the news kinds (CMND_CAREERMODE_NEWS items' `kind`)
local NEWS_TINT = { transfer = TINT.gold, club = TINT.cut, result = TINT.navy, competition = TINT.direct }

-- a text broken into at most `lines` lines of px wide (size px glyphs): { line, … }
local function Wrap(s, px, size, lines)
  local out, cur = {}, ""
  for word in tostring(s or ""):gmatch("%S+") do
    local try = cur == "" and word or (cur .. " " .. word)
    if Units(try) * size * GLYPH > px and cur ~= "" then
      out[#out + 1] = cur
      cur = word
      if #out == lines then break end
    else
      cur = try
    end
  end
  if #out < lines and cur ~= "" then out[#out + 1] = cur end
  if #out == lines and Units(table.concat(out, " ")) < Units(tostring(s or "")) then
    out[lines] = Fit(out[lines] .. " …", px, size)
  end
  return out
end

-- the news items and the picture's framing: CMND_CAREERMODE_NEWS (career_news: { ok, items = { { id, kind, tag,
-- date, head, body, card, team, from, amount, action, clips } }, picture = { feet, centre, height } }, texts in the
-- game's language); without it, one card per news line of the phase (the transfer window first), the club's crest as
-- its picture
local function NewsItems(h)
  local v = Call("CMND_CAREERMODE_NEWS", Lang())
  if v and v.ok and type(v.items) == "table" and #v.items > 0 then return v.items, v.picture end
  local out = {}
  local window = WindowLine(h)
  if window ~= "" then out[#out + 1] = { kind = "club", tag = Tx("TabMarket"), head = window, team = h.team } end
  for _, line in ipairs(NewsLines(h)) do
    out[#out + 1] = { kind = "competition", tag = Tx("News"), head = line, team = h.team }
  end
  return out
end

-- one card at y (alpha a; shown = the card in place, not the one leaving): the picture (the player's 3D model,
-- without the model service his miniface large, else the club's crest) over the gradient and the faint crest, the
-- bottom shade, the transfer block, the tag and date, the headline and text; a card with an action
-- (Ofertas) is a hub button: framed in cyan when focused
local function NewsCard(it, y, a, shown, dx)
  local F = FEED
  local x, w, h = F.x + (dx or 0), F.w, F.CARD_H
  if not shown then
    -- the card leaving: its background only, fading out (its texts, face and crests go at once: the texts have no
    -- alpha, two cards' texts would stack)
    Quad(L.panel, F.Background(it.team), x, y, w, h, a)
    return
  end
  local model = S.pic ~= nil and (it.card or 0) ~= 0
  local cx = x + w / 2
  if model then
    -- the shown card's player as a 3D model in the card box (VRFW_ModelCard, asked after the draw); the gradient and
    -- the crest in the background pass under the model (a normal-pass quad would cover it); a leaving card: its
    -- model goes, only its texts fade
    if shown then
      local P = S.news.picture or {}
      if (it.team or 0) ~= 0 then
        local drawn = PICK.BigCrest(it.team, cx, F.y + h * F.GHOST_Y, F.GHOST, L.ghost, F.GHOST_ALPHA, true) == true
        local mark = tostring(it.team) .. ":" .. tostring(drawn)
        if F.ghost_logged ~= mark then
          F.ghost_logged = mark
          Log("news ghost crest", it.team, drawn and "drawn" or "not drawn yet", "key",
            tostring(S.emblem_keys and S.emblem_keys[it.team]))
        end
      end
      Quad(L.ground, F.Background(it.team), x, F.y, w, h)
      -- fit: the box is the card's image area (config [news.picture]): under the transfer crests, over the text band
      local top = ((it.from or 0) ~= 0 and (it.team or 0) ~= 0) and (P.top_transfer or 128) or (P.top or 14)
      local side, bottom = P.side or 14, P.bottom or 232
      local box = P.fit and { x = x + side, y = F.y + S.dy + top, w = w - 2 * side, h = h - top - bottom }
        or { x = x, y = F.y + S.dy, w = w, h = h }
      S.pic_want = { card = it.card, team = it.team or 0, clips = it.clips, box = box, fit = P.fit == true,
        static = P.static == true, feet = P.feet, centre = P.centre, height = P.height }
    end
  else
    Quad(L.panel, F.Background(it.team), x, y, w, h, a)
    if (it.card or 0) ~= 0 then
      Face(it.card, cx - 20, y + h * 0.45, F.FACE, it.team)
    elseif (it.team or 0) ~= 0 then
      Crest(it.team, cx, y + h * 0.4, 4, 0.9 * a)
    end
  end
  for k = 1, F.SHADE do
    local sy = y + h * (0.6 + 0.4 * (k - 1) / F.SHADE)
    Quad(L.plate, ART.fill, x, sy, w, h * 0.4 / F.SHADE + 1, a * 0.16 * k, nil, TINT.navy)
  end
  -- the transfer: the club he leaves > the club he joins, the fee under the arrow (it says what the body would: a
  -- transfer card has no body, its tag and title come down to the body's place, TRANSFER_DOWN px lower, a title
  -- line lower again when the title takes one line)
  local transfer = (it.card or 0) ~= 0 and (it.from or 0) ~= 0 and (it.team or 0) ~= 0
  local heads = Wrap(it.head, w - 40, 32, 2)
  local down = transfer and (F.TITLE_Y - F.BODY_Y - F.TITLE + F.TRANSFER_DOWN + (2 - #heads) * F.TITLE) or 0
  if transfer then
    local ty = y + F.TOP
    Crest(it.from, cx - F.CREST_DX, ty, F.CREST, a)
    Crest(it.team, cx + F.CREST_DX, ty, F.CREST, a)
    Text(L.text, Tx("NewsOut"), cx - F.CREST_DX, ty + 46, "outline_c", 0.6, "c")
    Text(L.text, Tx("NewsIn"), cx + F.CREST_DX, ty + 46, "outline_c", 0.6, "c")
    Quad(L.icon, ART.chevron, cx - ART.chevron.w / 2, ty - 26, ART.chevron.w, ART.chevron.h, a)
    if type(it.amount) == "number" and it.amount > 0 then
      MoneyAt(Short(it.amount), cx, ty + 32, "outline_c", 0.65, "c")
    end
  end
  local tag = tostring(it.tag or "")
  local tx = x + 18
  if tag ~= "" then
    local tw = Units(tag) * 24 * GLYPH + 30
    Quad(L.icon, ART.row, tx, y + h - F.TAG_Y + down - 17, tw, 34, a, nil, NEWS_TINT[it.kind] or TINT.gold)
    Text(L.text, tag, tx + tw / 2, y + h - F.TAG_Y + down, "body_w", 0.72, "c")
    tx = tx + tw + 12
  end
  if type(it.date) == "table" then Text(L.text, DateShort(it.date), tx, y + h - F.TAG_Y + down, "outline", 0.7) end
  for k, line in ipairs(heads) do
    Text(L.text, line, x + 18, y + h - F.TITLE_Y + down + (k - 1) * F.TITLE, "outline", 1.12)
  end
  for k, line in ipairs(transfer and {} or Wrap(it.body, w - 40, 22, 2)) do
    Text(L.text, line, x + 18, y + h - F.BODY_Y + (k - 1) * F.BODY, "outline", 0.72)
  end
end

-- the feed: the shown card (on a change the old one fades out while the new one fades in: rising SLIDE_UP px after
-- up / down, sliding SLIDE_SIDE px in from its side after left / right) and the thin progress bar at its bottom (the
-- shown item's share lit)
local function DrawNews(h)
  local n = S.news
  if n == nil then
    local items, picture = NewsItems(h)
    n = { items = items, picture = picture, at = 1, from = nil, t = 0, seen = {} }
    S.news = n
  end
  local F = FEED
  local items = n.items
  if #items == 0 then return end
  local slide = n.from and (1 - n.t / F.SLIDE) or 0   -- 1 = the change just started, 0 = done
  if n.from then NewsCard(items[n.from], F.y, slide, false) end
  local it = items[n.at]
  local side = n.side or 0
  NewsCard(it, F.y + (side == 0 and F.SLIDE_UP * slide or 0), 1 - slide, true, side * F.SLIDE_SIDE * slide)
  if it.action == "offers" then
    S.buttons[#S.buttons + 1] = { x0 = F.x, y0 = F.y, x1 = F.x + F.w, y1 = F.y + F.CARD_H, action = "news_offers" }
    if #S.buttons == S.button then Frame(L.icon, F.x, F.y, F.w, F.CARD_H, 5, TINT.cut) end
  end
  if #items > 1 then
    local bx, bw, by = F.x + 18, F.w - 36, F.y + F.CARD_H - F.BAR_Y
    Quad(L.plate, ART.fill, bx, by, bw, F.BAR_H, 1, nil, TINT.rest)
    Quad(L.plate, ART.fill, bx + (n.at - 1) * bw / #items, by, bw / #items, F.BAR_H, 1, nil, TINT.cut)
  end
end

-- right stick / wheel / the arrows / a click on the feed: the next (d = 1) or the previous (d = -1) item
-- side: -1 / 1 = a left / right step (the new card slides in from that side), nil = up / down (it rises)
local function NewsScroll(d, side)
  local n = S.news
  if n == nil or #n.items < 2 or n.from then return end
  n.from, n.t, n.side = n.at, 0, side
  n.at = (n.at - 1 + d) % #n.items + 1
  Snd(SND.MOVE)
  S.dirty = true
end

-- Step: the slide moves on (a draw per frame while it runs)
local function NewsStep()
  local n = S.news
  if n == nil then return end
  local it = n.items[n.at]
  if it and it.id and not n.seen[it.id] then
    n.seen[it.id] = true
    if not it.seen then Call("CMND_CAREERMODE_NEWS_SEEN", it.id) end
  end
  if n.from == nil then return end
  n.t = n.t + 1
  if n.t >= FEED.SLIDE then n.from = nil end
  S.dirty = true
end

-- the form chips (oldest first) and the board's objectives beside them
function HOME.Form(h)
  local B = HOME.FORM
  Tile(B.x, B.y, B.w, B.h, Tx("Form"), "icon_list_tab_history01")
  local ox = h.board and (B.x + B.w - 24 - B.OBJ_W) or (B.x + B.w)
  local n = math.max(1, h.form_matches or 5)
  local step = math.min(B.CHIP_STEP, (ox - 30 - (B.x + 24)) / n)
  FormChips(h, B.x + 24, B.y + B.CHIP_Y + (B.CHIP_STEP - step) / 2, step - B.CHIP_GAP, step)
  if h.board then
    Quad(L.plate, ART.fill, ox - 16, B.y + TILE.BAND + 10, 2, B.h - TILE.BAND - 20, 1, nil, TINT.stripe)
    Text(L.text, Fit(Tx("BoardTitle"), B.OBJ_W, 22), ox, B.y + B.OBJ_HEAD_Y, "label_l", 0.85)
    HOME.Objectives(h.board, ox, B.y + B.OBJ_Y, B.OBJ_STEP, B.OBJ_W - B.MARK - 10, B.MARK, "label_l", 0.78)
  end
end

-- the budget (with the market on), the transfer window's line and, while it is open, how much of it has gone; the
-- season and the club's level in the band
function HOME.Budget(h)
  local B = HOME.BUDGET
  local rated = S.rate[h.team]
  local note = Tx("SeasonN", h.season) .. (rated and rated.level > 0 and ("  ·  " .. Tx("LevelShort", rated.level)) or "")
  if not h.money then
    Tile(B.x, B.y, B.w, B.h, Tx("YourClub"), nil, note)
    Crest(h.team, B.x + 60, B.y + B.MONEY_Y + 6, 0.9)
    Text(L.text, Fit(TeamName(h.team), B.w - 140, 32), B.x + 110, B.y + B.MONEY_Y + 6, "big", 1)
    return
  end
  Tile(B.x, B.y, B.w, B.h, Tx("Budget"), nil, note)
  -- a left-aligned style: a centred one would start the digits right of x, under the icon
  MoneyAt(h.money, B.x + 24, B.y + B.MONEY_Y, "item", 1.1)
  local line = WindowLine(h)
  if line ~= "" then
    Text(L.text, Fit(line, B.w - 48, 20), B.x + 24, B.y + B.LINE_Y, "label_l", 0.9)
  end
end

local function DrawHomePhase()
  local h = S.hub
  HOME.Next(h)
  HOME.Table(h)
  HOME.Week(h, HOME.WEEK)
  HOME.Form(h)
  HOME.Budget(h)
  DrawNews(h)
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

-- the week around day z (Monday first) inside the season's months: its 7 days { z, d, m, y, wd } (false outside),
-- and day z's own
function HOME.WeekDays(h, z)
  local months = h.days and h.days.months or {}
  local function at(day)
    for _, mo in ipairs(months) do
      if day >= mo.first and day < mo.first + mo.days then
        local d = day - mo.first + 1
        return { z = day, d = d, m = mo.m, y = mo.y, wd = (mo.wd - 1 + d - 1) % 7 + 1 }
      end
    end
    return nil
  end
  local here = at(z)
  if here == nil then return nil, nil end
  local out = {}
  for k = 1, 7 do out[k] = at(z - (here.wd - 1) + k - 1) or false end
  return out, here
end

-- the week of the next event (today's when none) in box B: a card per day (weekday, number, the rival's crest on a
-- match day; the spans' colours as on the calendar, the club's current match lit, today framed)
function HOME.Week(h, B, title)
  local days = h.days or {}
  local anchor = (days.next or days.today or {}).day
  local week, here
  if anchor then week, here = HOME.WeekDays(h, anchor) end
  Tile(B.x, B.y, B.w, B.h, title or Tx("ThisWeek"), "icon_list_tab_history01",
    here and MonthTitle({ m = here.m, y = here.y }) or nil)
  if week == nil then return end
  local events = EventsByDay(h)
  local today = days.today and days.today.day or -1
  local cw = (B.w - 32 - 6 * B.GAP) / 7
  for k, d in ipairs(week) do
    if d then
      local x, y = B.x + 16 + (k - 1) * (cw + B.GAP), B.y + B.TOP
      local e = events[d.z]
      local tint = TINT.white
      if InSpans(days.windows, d.z) then tint = TINT.window
      elseif days.world_cup and InSpans({ days.world_cup }, d.z) then tint = TINT.cup
      elseif InSpans(days.breaks, d.z) then tint = TINT.rest end
      if e and e.current then tint = TINT.mine end
      Quad(L.plate, ART.row, x, y, cw, B.CELL_H, 1, nil, tint)
      Text(L.text, Tx("Weekday" .. d.wd), x + cw / 2, y + 14, "label", 0.85, "c")
      Text(L.text, tostring(d.d), x + cw / 2, y + 40, "big", 0.85, "c")
      if e and e.draw then
        Text(L.text, Fit(Tx("DrawShort"), cw - 8, 20), x + cw / 2, y + B.CELL_H - 20, "label", 0.7, "c")
      elseif e and (e.home or 0) ~= 0 then
        Crest(e.home == Me(h) and e.away or e.home, x + cw / 2, y + B.CELL_H - 22, B.CREST)
      end
      if d.z == today then Frame(L.icon, x, y, cw, B.CELL_H, 3, TINT.gold) end
    end
  end
end

-- the «Fechas» page: the month's grid (days as cards, CELL_H at most, smaller for a sixth week) with its legend, the
-- season's phases line under it; on the right the next match's day, the next milestone, the week and the match after
-- «Fechas» (owner pick fechas3 D): the month across the page (X, Y: the first cell; W wide, at most CELL_H tall, GAP
-- apart, down to BOTTOM; the legend in the title band from LEGEND_X), the selected day's drawer under it (DRAWER: its
-- walk button BUTTON_W x BUTTON_H at its right), the season's line at the bottom (SEASON). DEFAULT_COLOUR: a
-- competition's colour when config [calendar] competition_colours names none
local CAL = { X = 84, Y = 312, W = 243, CELL_H = 74, GAP = 8, BOTTOM = 770, LEGEND_X = 600, LEGEND_STEP = 190,
  CREST_W = 64,       -- a match cell's crest column
  -- a cell: the day's text at DAY_X, DAY_Y (scale DAY_SC); the name + round block at BLOCK_X, its two lines BLOCK_STEP
  -- apart (scale BLOCK_SC), centred MID_DY px under the cell's middle with the result and the crest
  DAY_X = 10, DAY_Y = 14, DAY_SC = 0.52, BLOCK_X = 12, BLOCK_STEP = 20, BLOCK_SC = 0.5, MID_DY = 8,
  PAGE = { x = 60, y = 220, w = 1800, h = 560 },
  DRAWER = { x = 60, y = 794, w = 1800, h = 96, BUTTON_W = 400, BUTTON_H = 60 },
  -- the season's line: lane 1 the competitions (COMP_Y, COMP_H tall; a name that does not fit its bar above it at
  -- ABOVE_Y), lane 2 the transfer windows (WINDOW_Y, WINDOW_H tall, the name after the bar), the progress line at
  -- LINE_Y with today, the months of equal width (names at MONTH_Y); the days gone dimmed (PAST alpha of white)
  SEASON = { x = 60, y = 902, w = 1800, h = 98, ABOVE_Y = 11, COMP_Y = 20, COMP_H = 22, WINDOW_Y = 48, WINDOW_H = 8,
    LINE_Y = 66, LINE_H = 6, MONTH_Y = 86, MIN_W = 12, DOT = 14, PAST = 0.45, LABEL_SC = 0.52, LABEL_PAD = 12 },
  DEFAULT_COLOUR = "navy",
}

-- a round label's competition: superliga, league, frontier, worldcup
function CAL.PhaseOf(label)
  label = tostring(label or "")
  if label:find("SuperLiga", 1, true) then return "superliga" end
  if label:find("League", 1, true) then return "league" end
  if label:find("WorldCup", 1, true) then return "worldcup" end
  return "frontier"
end

-- a competition's colour (hub days.colours = config [calendar] competition_colours: key -> TINT name)
function CAL.Colour(h, key)
  local names = h.days and type(h.days.colours) == "table" and h.days.colours or {}
  return TINT[names[key] or CAL.DEFAULT_COLOUR]
end

function CAL.PhaseName(key, h)
  if key == "superliga" then return Tx("SuperLiga") end
  if key == "window" then return Tx("TabMarket") end
  if key == "league" then return (h.league or 0) > 0 and LeagueName(h.league) or Tx("Phase_league") end
  if key == "worldcup" then return Tx("CompWorldCup") end
  return Tx("CompFrontier")
end

-- the season's line (owner 2026-10-31): its phases (hub days.phases) as bars in their colour in two fixed lanes, the
-- competitions (SuperLiga, leagues, Frontier, World Cup) and under them the transfer windows, thinner; every name
-- whole (inside its bar when it fits, else above it / after it); the days gone dimmed; the months of equal width
-- from the start's month to the end's, the progress line and today
function CAL.Season(h)
  local B = CAL.SEASON
  local days = h.days or {}
  Quad(L.panel, ART.white, B.x, B.y, B.w, B.h)
  local finish = type(days.finish) == "table" and days.finish.day or nil
  local months = {}
  for _, mo in ipairs(days.months or {}) do
    if finish == nil or mo.first <= finish then months[#months + 1] = mo end
  end
  if #months == 0 then return end
  local x0, x1 = B.x + 24, B.x + B.w - 24
  local slice = (x1 - x0) / #months
  local function X(z)
    if z < months[1].first then return x0 end
    for i, mo in ipairs(months) do
      if z < mo.first + mo.days then return x0 + slice * (i - 1 + (z - mo.first) / mo.days) end
    end
    return x1
  end
  local today = CAL.Today(h)
  if today < 0 then today = months[1].first end
  local tx = X(today)
  local above_end, after_end = x0 - 1, x0 - 1   -- the right ends of the names drawn outside their bars
  for _, p in ipairs(days.phases or {}) do
    if type(p.from) == "table" and type(p.to) == "table" then
      local window = p.key == "window"
      local rx = X(p.from.day)
      local rw = math.max(B.MIN_W, X(p.to.day + 1) - rx)
      local ry, rh = B.y + (window and B.WINDOW_Y or B.COMP_Y), window and B.WINDOW_H or B.COMP_H
      local name = CAL.PhaseName(p.key, h)
      local nw = CAL.Width(name, "label", B.LABEL_SC)
      -- the days gone: a white veil over the bar's past part (drawn first: over the bar)
      if tx > rx then Quad(L.icon, ART.fill, rx, ry, math.min(rw, tx - rx), rh, B.PAST, nil, TINT.white) end
      Quad(L.plate, ART.fill, rx, ry, rw, rh, 1, nil, CAL.Colour(h, p.key))
      if not window and nw + B.LABEL_PAD <= rw then
        Text(L.text, name, rx + rw / 2, ry + rh / 2, "body_w", B.LABEL_SC, "c")
      elseif not window then
        -- above the bar, centred on it, kept right of the last name up there and inside the panel
        local lx = math.min(x1 - nw, math.max(above_end + 8, rx + rw / 2 - nw / 2))
        Text(L.text, name, lx + nw / 2, B.y + B.ABOVE_Y, "label", B.LABEL_SC, "c")
        above_end = lx + nw
      else
        -- a window: its name after the bar (before it when the panel ends first)
        local lx = rx + rw + 6
        if lx + nw > x1 then lx = rx - 6 - nw end
        lx = math.max(lx, after_end + 8)
        Text(L.text, name, lx + nw / 2, ry + rh / 2, "label", B.LABEL_SC, "c")
        after_end = lx + nw
      end
    end
  end
  Quad(L.plate, ART.fill, x0, B.y + B.LINE_Y - B.LINE_H / 2, x1 - x0, B.LINE_H, 1, nil, TINT.stripe)
  if tx > x0 then Quad(L.icon, ART.fill, x0, B.y + B.LINE_Y - B.LINE_H / 2, tx - x0, B.LINE_H, 1, nil, TINT.cut) end
  Quad(L.icon, ART.fill, tx - B.DOT / 2, B.y + B.LINE_Y - B.DOT / 2, B.DOT, B.DOT, 1, nil, TINT.gold)
  -- each month's name centred in its own span (the last one stays inside the panel)
  for i, mo in ipairs(months) do
    local mx0, mx1 = x0 + slice * (i - 1), x0 + slice * i
    Quad(L.plate, ART.fill, mx0 - 1, B.y + B.LINE_Y - 7, 2, 14, 1, nil, TINT.navy)
    Text(L.text, Fit(Tx("MonthShort" .. mo.m), mx1 - mx0, 18), (mx0 + mx1) / 2, B.y + B.MONTH_Y, "label",
      mo.first <= today and today < mo.first + mo.days and 0.9 or 0.8, "c")
  end
end

-- the month's grid in the page tile (its arrows: the month; the legend in its band): a cell per day, a match day in
-- its competition's colour with the rival's crest and the round, the transfer windows, the World Cup and the breaks
-- tinted, today framed in gold, the selected day in cyan with the cursor; each cell a pointer zone
function CAL.Cell(h, e, x, y, w, ch, d, z)
  local tint = TINT.white
  local days = h.days
  if e and not e.draw then tint = CAL.Colour(h, CAL.PhaseOf(e.label)) end
  if not (e and not e.draw) then
    if InSpans(days.windows, z) then tint = TINT.window
    elseif days.world_cup and InSpans({ days.world_cup }, z) then tint = TINT.cup
    elseif InSpans(days.breaks, z) then tint = TINT.rest end
  end
  Quad(L.plate, ART.row, x, y, w, ch, 1, nil, tint)
  local match = e and not e.draw and e.home ~= 0
  -- the day at the cell's top-left corner (a left-aligned style)
  Text(L.text, tostring(d), x + CAL.DAY_X, y + CAL.DAY_Y, match and "item_on" or "item", CAL.DAY_SC)
  if e == nil then return end
  if e.draw then
    Quad(L.plate, ART.fill, x + 4, y + ch - 30, w - 8, 26, 1, nil, TINT.navy)
    Text(L.text, Fit(Tx("DrawShort"), w - 24, 20), x + w / 2, y + ch - 17, "body_w", 0.62, "c")
  else
    -- on the left the competition's name with the round («J11») under it, the block centred on the cell's middle
    -- (MID_DY px under it: clear of the day); a match: the result big at the middle right (not played: «L» / «V»,
    -- smaller), the rival's crest at the right
    local mid = y + ch / 2 + CAL.MID_DY
    local room = w - CAL.BLOCK_X - 12
    if match then
      local home = e.home == Me(h)
      local rival = home and e.away or e.home
      local cx = x + w - CAL.CREST_W / 2 - 6
      Crest(rival, cx, mid, math.min(0.6, (ch - 34) / 68))
      local played = Score(e) ~= ""
      local res = played and ((home and e.hg or e.ag) .. "-" .. (home and e.ag or e.hg))
        or Tx(home and "HomeShort" or "AwayShort")
      local sc = played and 0.95 or 0.62
      local left = cx - CAL.CREST_W / 2 - 6 - CAL.Width(res, "title", sc)
      Text(L.text, res, left, mid, "title", sc)
      room = left - 10 - (x + CAL.BLOCK_X)
    end
    local size = 32 * CAL.BLOCK_SC
    Text(L.text, Fit(CAL.PhaseName(CAL.PhaseOf(e.label), h), room, size), x + CAL.BLOCK_X, mid - CAL.BLOCK_STEP / 2,
      "item_on", CAL.BLOCK_SC)
    Text(L.text, Fit(RoundName(e.label, e.n, true), room, size), x + CAL.BLOCK_X, mid + CAL.BLOCK_STEP / 2, "item_on",
      CAL.BLOCK_SC)
  end
end

-- a text's width (px) as drawn in `style` at scale sc (an estimate from its characters)
function CAL.Width(str, style, sc)
  local size = tonumber((STYLE[style] or STYLE.body):match("^fs_(%d+)")) or 28
  return Units(str) * size * TILE.DIGIT * (sc or 1)
end

function CAL.Grid(h)
  local P = CAL.PAGE
  local mo, months = CalendarMonth(h)
  Tile(P.x, P.y, P.w, P.h, mo and MonthTitle(mo) or Tx("TabCalendar"), "icon_list_tab_history01")
  if mo == nil then return end
  Quad(L.icon, ART.arrow, P.x + 410, P.y + 9, 30, 34, S.month > 1 and 1 or 0.3, true)
  Quad(L.icon, ART.arrow, P.x + 460, P.y + 9, 30, 34, S.month < #months and 1 or 0.3)
  S.zones[#S.zones + 1] = { x0 = P.x + 400, y0 = P.y, x1 = P.x + 445, y1 = P.y + 52, kind = "cmonth", index = -1 }
  S.zones[#S.zones + 1] = { x0 = P.x + 450, y0 = P.y, x1 = P.x + 495, y1 = P.y + 52, kind = "cmonth", index = 1 }
  -- the legend in the band: the competitions this season has, the transfer window, today
  local legend, seen = {}, {}
  for _, m in ipairs(h.calendar or {}) do
    local key = CAL.PhaseOf(m.label)
    if not seen[key] then
      seen[key] = true
      legend[#legend + 1] = { CAL.Colour(h, key), CAL.PhaseName(key, h) }
    end
  end
  legend[#legend + 1] = { TINT.window, Tx("LegendWindow") }
  legend[#legend + 1] = { TINT.gold, Tx("LegendToday") }
  local lx = P.x + CAL.LEGEND_X
  for _, it in ipairs(legend) do
    Quad(L.plate, ART.fill, lx - 2, P.y + 14, 24, 24, 1, nil, TINT.white)
    Quad(L.plate, ART.fill, lx, P.y + 16, 20, 20, 1, nil, it[1])
    Text(L.text, Fit(it[2], CAL.LEGEND_STEP - 40, 22), lx + 28, P.y + 26, "item_on", 0.6)
    lx = lx + CAL.LEGEND_STEP
  end
  local events = EventsByDay(h)
  local today = CAL.Today(h)
  local sel = CAL.Cursor(h, mo)
  local weeks = math.ceil((mo.wd - 1 + mo.days) / 7)
  local ch = math.min(CAL.CELL_H, math.floor((CAL.BOTTOM - CAL.Y) / weeks) - CAL.GAP)
  for k = 1, 7 do
    Text(L.text, Tx("Weekday" .. k), CAL.X + (k - 1) * (CAL.W + CAL.GAP) + CAL.W / 2, CAL.Y - 22, "label", 1, "c")
  end
  for d = 1, mo.days do
    local z = mo.first + d - 1
    local col = (mo.wd - 1 + d - 1) % 7
    local row = math.floor((mo.wd - 1 + d - 1) / 7)
    local x, y = CAL.X + col * (CAL.W + CAL.GAP), CAL.Y + row * (ch + CAL.GAP)
    CAL.Cell(h, events[z], x, y, CAL.W, ch, d, z)
    if z == today then
      Frame(L.icon, x, y, CAL.W, ch, 4, TINT.gold)
      Text(L.text, Tx("LegendToday"), x + CAL.W - 40, y + 18, "label", 0.85, "c")
    end
    if z == sel then
      Frame(L.icon, x - 4, y - 4, CAL.W + 8, ch + 8, 4, TINT.cut)
      if z ~= today then Cursor(x + 4, y + ch / 2, 40) end
    end
    S.zones[#S.zones + 1] = { x0 = x, y0 = y, x1 = x + CAL.W, y1 = y + ch, kind = "cday", index = z, hover = true }
  end
end

-- the selected day's drawer: its date, how far it is and what happens on it; a future day the career can walk to
-- has the «Avanzar hasta aquí» button (A, or a click: the walk's question)
function CAL.Drawer(h)
  local B = CAL.DRAWER
  local months = h.days and h.days.months or {}
  local mo = months[S.month or 1]
  local z = S.cday
  Quad(L.panel, ART.navy, B.x, B.y, B.w, B.h)
  if mo == nil or z == nil then return end
  local d = z - mo.first + 1
  local date = { day = z, y = mo.y, m = mo.m, d = d, wd = (mo.wd - 1 + d - 1) % 7 + 1 }
  local today = CAL.Today(h)
  local when
  if z == today then when = Tx("LegendToday")
  elseif z == today + 1 then when = Tx("CalTomorrow")
  elseif z > today then when = Tx("CalInDays", z - today)
  else when = Tx("CalPast") end
  local e = EventsByDay(h)[z]
  local what
  if e and e.draw then what = Tx("DrawTitle")
  elseif e and e.home ~= 0 then
    local home = e.home == Me(h)
    local sc = Score(e)
    what = RoundName(e.label, e.n) .. "  ·  " .. TeamName(home and e.away or e.home) .. "  ·  " ..
      (sc ~= "" and ((home and e.hg or e.ag) .. "-" .. (home and e.ag or e.hg)) or (home and Tx("Home") or Tx("Away")))
  elseif e then what = RoundName(e.label, e.n) end
  for _, r in ipairs(h.days.windows or {}) do
    if r.from and r.from.day == z then what = Tx("DayEventWindowOpen") end
    if r.to and r.to.day == z then what = Tx("DayEventWindowClose") end
  end
  local room = B.w - B.BUTTON_W - 90
  Text(L.text, Fit(DateLong(date) .. "  ·  " .. when, room, 32), B.x + 30, B.y + 30, "title", 0.9)
  -- left-aligned white (body_w is a centred style: drawn at B.x + 30 it ran out of the drawer on the left)
  Text(L.text, Fit(what or Tx("CalNoEvents"), room, 26), B.x + 30, B.y + 68, "item_on", 0.7)
  local st = h.days.stretch
  if z > today and st and not st.match_day then
    local bx, by = B.x + B.w - B.BUTTON_W - 30, B.y + (B.h - B.BUTTON_H) / 2
    Quad(L.plate, ART.cyan, bx, by, B.BUTTON_W, B.BUTTON_H)
    Text(L.text, Fit(Tx("CalWalkHere"), B.BUTTON_W - 30, 30), bx + B.BUTTON_W / 2, by + B.BUTTON_H / 2, "body_w", 1, "c")
    S.zones[#S.zones + 1] = { x0 = bx, y0 = by, x1 = bx + B.BUTTON_W, y1 = by + B.BUTTON_H, kind = "cday", index = z }
  end
end

-- the day the career is at: the days' line's today while there is one, else the hub's today
function CAL.Today(h)
  local st = h.days and h.days.stretch
  if st and st.now then return st.now.day end
  return h.days and h.days.today and h.days.today.day or -1
end

-- the grid's selected day (S.cday): kept inside the shown month (today when it is in it, else the month's first day)
function CAL.Cursor(h, mo)
  local z = S.cday
  if z == nil or z < mo.first or z >= mo.first + mo.days then
    local today = CAL.Today(h)
    z = (today >= mo.first and today < mo.first + mo.days) and today or mo.first
    S.cday = z
  end
  return z
end

-- the selected day moved by `by` days (the arrows: 1 sideways, 7 up / down), the month following it
function CAL.MoveDay(by)
  local months = S.hub.days and S.hub.days.months or {}
  local mo = months[S.month or 1]
  if mo == nil or S.cday == nil then return false end
  local z = S.cday + by
  for i, m in ipairs(months) do
    if z >= m.first and z < m.first + m.days then
      S.cday, S.month = z, i
      return true
    end
  end
  return false
end

-- another month shown (the right stick, the wheel, the title's arrows): the cursor on the same day of it
function CAL.Month(d)
  local months = S.hub.days and S.hub.days.months or {}
  local to = math.max(1, math.min(#months, (S.month or 1) + d))
  if to == S.month or months[to] == nil then return false end
  local day = S.cday and months[S.month or 1] and (S.cday - months[S.month or 1].first) or 0
  S.month = to
  S.cday = months[to].first + math.min(day, months[to].days - 1)
  return true
end

-- A on a day: a future day asks to walk the days up to it (it stops earlier on an event or the match day), today
-- or a day gone says so
function CAL.Pick(h)
  local months = h.days and h.days.months or {}
  local mo = months[S.month or 1]
  local z = S.cday
  if mo == nil or z == nil then Snd(SND.BUZZER) return end
  local st = h.days.stretch
  local today = CAL.Today(h)
  if z <= today then
    Snd(SND.BUZZER)
    S.dialog = { kind = "info", title = Tx("TabCalendar"), lines = { Tx(z == today and "CalDayToday" or "CalDayGone") } }
  elseif st == nil or st.match_day then
    Snd(SND.BUZZER)
    S.dialog = { kind = "info", title = Tx("TabCalendar"), lines = { Tx("CalNoWalk") } }
  else
    Snd(SND.DECIDE)
    local d = z - mo.first + 1
    local date = { day = z, y = mo.y, m = mo.m, d = d, wd = (mo.wd - 1 + d - 1) % 7 + 1 }
    S.dialog = { kind = "walkto", day = z, title = Tx("CalWalkTitle"), choice = 1, buttons = { Tx("Yes"), Tx("No") },
      lines = { Tx("CalWalkAsk", DateLong(date)), Tx("CalWalkStops") } }
  end
  S.dirty = true
end

local function DrawCalendar(h)
  CAL.Grid(h)
  CAL.Drawer(h)
  CAL.Season(h)
end

-- the «Torneos» table: the standings in the left panel as a scrolling list (up / down move the cursor, the wheel too, a
-- click picks a row; the club's row in view first), a scroll bar right of the rows; the right panel: the competition's
-- player stats (CMND_CAREERMODE_STATS), a tab per order (left / right or a click), the best players of the club under
-- them
local STANDINGS = { X0 = 76, X1 = 870, HEAD_Y = 306, ROW_Y = 346, STEP = 44, BOTTOM = 1000, NAME_W = 420,
  BAR_X = 880, BAR_W = 8,
  LEFT = { x = 60, y = 276, w = 840, h = 724 }, RIGHT = { x = 956, y = 276, w = 904, h = 724, PAD = 30 },
  -- the switch between the panels (centred in their gap): the up arrow, the Y glyph, the down arrow, STEP px apart;
  -- the arrows ARROW_W x ARROW_H (the glyph: HOME.SWITCH_SPEC)
  SWITCH = { STEP = 40, ARROW_W = 18, ARROW_H = 22, ZONE = 34 },
  TREE = { TOP = 70, BOTTOM = 56, GAP = 24, BOX_H = 34, LINE = 3 } }
local STANDINGS_COLS = { { "ColPlayed", 576, "played" }, { "ColWon", 626, "won" }, { "ColDrawn", 672, "drawn" },
  { "ColLost", 718, "lost" }, { "ColDiff", 772, "diff" }, { "ColPoints", 830, "points" } }
-- the stats panel: its tabs (title key, CMND_CAREERMODE_STATS order, columns { header key, row field, decimals }), the
-- rows of a page asked (ASK), the rows in view (TOP, scrolled by the right stick / the wheel over the panel), the
-- club's best (CLUB, the scripts' `mine`), the layout (px from the panel)
STANDINGS.STATS = {
  TABS = {
    { "StatGoals", "goals", { { "ColPlayed", "matches" }, { "ColGoals", "goals" } } },
    { "StatRating", "rating", { { "ColPlayed", "matches" }, { "ColRating", "rating", 1 } } },
    { "StatMvp", "mvp", { { "ColPlayed", "matches" }, { "ColMvp", "mvp" } } },
  },
  -- the tabs as text (TAB_SC, TAB_GAP px apart, the chosen one underlined)
  ASK = 50, TOP = 10, CLUB = 3, TAB_Y = 14, TAB_H = 36, TAB_SC = 0.7, TAB_GAP = 40, HEAD_Y = 80, ROW_Y = 118, STEP = 40,
  CLUB_Y = 568,
  COL_W = 92, CREST = 0.42, BAR_W = 8,
}

-- the shown competition's stats in one order, kept per hub data, competition and order (false = none): { rows (by
-- rank, the pages asked so far), asked (page -> true), total, mine (the club's best) }. Only the pages the rows from
-- `first` (TOP of them) need are asked, one call each, when the list is drawn there; the scripts busy: asked again on
-- the next draw
function STANDINGS.Stats(index, sort, first)
  local St = STANDINGS.STATS
  S.stats = (S.stats and S.stats.hub == S.hub) and S.stats or { hub = S.hub }
  local key = tostring(index) .. ":" .. sort
  local v = S.stats[key]
  if v == false then return false end
  if v == nil then
    v = { rows = {}, asked = {}, total = nil, mine = {} }
    S.stats[key] = v
  end
  for _, at in ipairs({ first or 1, (first or 1) + St.TOP - 1 }) do
    local page = math.floor((at - 1) / St.ASK)
    if not v.asked[page] and (v.total == nil or at <= v.total) then
      local r = Call("CMND_CAREERMODE_STATS", index, sort, page * St.ASK + 1, St.ASK, Lang())
      if r == nil then
        S.dirty = true
        return v
      end
      if not (r.ok and type(r.rows) == "table") then
        S.stats[key] = false
        return false
      end
      v.asked[page], v.total, v.mine = true, r.total or #r.rows, type(r.mine) == "table" and r.mine or v.mine
      for k, row in ipairs(r.rows) do v.rows[row.rank or (page * St.ASK + k)] = row end
    end
  end
  return v
end

-- the stats list scrolled by d rows (the right stick, the wheel over the panel) -> true when it moved
function STANDINGS.StatsScroll(d)
  local St = STANDINGS.STATS
  local total = S.stats_total or 0
  local to = math.max(1, math.min(math.max(1, total - St.TOP + 1), (S.stfirst or 1) + d))
  if to == (S.stfirst or 1) then return false end
  S.stfirst = to
  return true
end

-- one stats row at y: rank, the club's crest, the player's name, the tab's values
function STANDINGS.StatRow(r, rank, x, x1, y, cols, mine)
  local St = STANDINGS.STATS
  if mine then Quad(L.plate, ART.fill, x, y - St.STEP / 2 + 2, x1 - x, St.STEP - 4, 1, nil, TINT.mine)
  elseif rank % 2 == 1 then Quad(L.plate, ART.fill, x, y - St.STEP / 2 + 2, x1 - x, St.STEP - 4, 1, nil, TINT.stripe) end
  Text(L.text, tostring(rank), x + 26, y, "body_c", 0.78, "c")
  Crest(r.team, x + 70, y, St.CREST)
  local name_w = x1 - #cols * St.COL_W - (x + 100) - 10
  Text(L.text, Fit(r.name or "", name_w, 26), x + 100, y, "item", 0.74)
  for c, col in ipairs(cols) do
    local v = r[col[2]] or 0
    local s = col[3] and string.format("%." .. col[3] .. "f", tonumber(v) or 0) or tostring(v)
    Text(L.text, s, x1 - (#cols - c + 0.5) * St.COL_W, y, c == #cols and "big" or "body_c", 0.8, "c")
  end
end

-- the right panel: the stat tabs, the competition's best in the tab's order, then the club's best players
function STANDINGS.Side(h, t, rows, B)
  local St = STANDINGS.STATS
  local sx, x1 = B.x + B.PAD, B.x + B.w - B.PAD
  S.stab = math.max(1, math.min(#St.TABS, S.stab or 1))
  local x, ty = sx, B.y + St.TAB_Y
  for i, tab in ipairs(St.TABS) do
    local label = Tx(tab[1])
    local tw = CAL.Width(label, "big", St.TAB_SC)
    local on = i == S.stab
    Text(L.text, label, x + tw / 2, ty + St.TAB_H / 2 - 2, on and "big" or "dim", St.TAB_SC, "c")
    if on then Quad(L.plate, ART.fill, x, ty + St.TAB_H - 4, tw, 4, 1, nil, TINT.cut) end
    S.zones[#S.zones + 1] = { x0 = x - St.TAB_GAP / 2, y0 = ty, x1 = x + tw + St.TAB_GAP / 2, y1 = ty + St.TAB_H,
      kind = "stab", index = i, hover = true }
    x = x + tw + St.TAB_GAP
  end
  local tab = St.TABS[S.stab]
  local _, index = TableNow()
  -- another competition or order: the list from its top
  local key = tostring(index) .. ":" .. tab[2]
  if S.stkey ~= key then S.stkey, S.stfirst = key, 1 end
  local v = t.kind ~= "worldcup" and STANDINGS.Stats(index, tab[2], S.stfirst) or false
  S.stats_total = v and v.total or 0
  if not v or (v.total or 0) == 0 then
    if v and v.total == nil then return end   -- its first page still being asked
    Text(L.text, Tx("StatsNone"), B.x + B.w / 2, B.y + B.h / 2, "label", 1.1, "c")
    return
  end
  S.stfirst = math.max(1, math.min(math.max(1, v.total - St.TOP + 1), S.stfirst))
  local cols = tab[3]
  Text(L.text, Tx("ColPlayer"), sx + 100, B.y + St.HEAD_Y, "label_l", 1)
  for c, col in ipairs(cols) do
    Text(L.text, Tx(col[1]), x1 - (#cols - c + 0.5) * St.COL_W, B.y + St.HEAD_Y, "label", 1, "c")
  end
  local me = Me(h)
  local right = x1 - St.BAR_W - 10      -- the rows' right edge (the scroll bar right of it)
  for i = 1, St.TOP do
    local k = S.stfirst + i - 1
    local r = v.rows[k]
    if r ~= nil then STANDINGS.StatRow(r, r.rank or k, sx, right, B.y + St.ROW_Y + (i - 1) * St.STEP, cols, r.team == me) end
  end
  -- the scroll bar: the rows in view among all of them
  if v.total > St.TOP then
    local top, bh = B.y + St.ROW_Y - St.STEP / 2, St.TOP * St.STEP
    local th = math.max(30, bh * St.TOP / v.total)
    local at = (S.stfirst - 1) / math.max(1, v.total - St.TOP)
    Quad(L.plate, ART.fill, x1 - St.BAR_W, top + (bh - th) * at, St.BAR_W, th, 1, nil, TINT.select)
    Quad(L.plate, ART.fill, x1 - St.BAR_W, top, St.BAR_W, bh, 1, nil, TINT.rest)
  end
  -- the club's best, pinned under the list
  for k, r in ipairs(v.mine or {}) do
    if k > St.CLUB then break end
    if k == 1 then Text(L.text, Tx("StatsBestOfClub"), sx, B.y + St.CLUB_Y, "item", 0.72) end
    STANDINGS.StatRow(r, r.rank or k, sx, right, B.y + St.CLUB_Y + 4 + k * St.STEP, cols, true)
  end
end

-- the switch in the panels' gap, centred: the up arrow, the Y glyph (Y: the focus between the standings and the
-- players), the down arrow (the focused list scrolled); each a click zone «tswitch» (d = -1 / 0 / 1)
function STANDINGS.Switch(Lf, Rt)
  local W = STANDINGS.SWITCH
  local cx, cy = (Lf.x + Lf.w + Rt.x) / 2, Lf.y + Lf.h / 2
  LEVEL.Turned(L.icon, ART.chevron, cx - W.ARROW_W / 2, cy - W.STEP - W.ARROW_H / 2, W.ARROW_W, W.ARROW_H, math.pi / 2)
  LEVEL.Turned(L.icon, ART.chevron, cx - W.ARROW_W / 2, cy + W.STEP - W.ARROW_H / 2, W.ARROW_W, W.ARROW_H, -math.pi / 2)
  HOME.switch = { a = cx, b = cx, y = cy + S.dy }
  for d = -1, 1 do
    local zy = cy + d * W.STEP
    S.zones[#S.zones + 1] = { x0 = cx - W.ZONE / 2, y0 = zy - W.ZONE / 2, x1 = cx + W.ZONE / 2, y1 = zy + W.ZONE / 2,
      kind = "tswitch", d = d }
  end
end

-- the rows in view: the cursor kept inside them (the club's row first, in the middle)
function STANDINGS.View(h, rows, per)
  local n = #rows
  if S.tcur == nil then
    S.tcur = 1
    for k, r in ipairs(rows) do if r.team == Me(h) then S.tcur = k end end
    S.tfirst = S.tcur - math.floor(per / 2)
  end
  S.tcur = math.max(1, math.min(n, S.tcur))
  local first = S.tfirst or 1
  if S.tcur < first then first = S.tcur end
  if S.tcur > first + per - 1 then first = S.tcur - per + 1 end
  S.tfirst = math.max(1, math.min(math.max(1, n - per + 1), first))
  return S.tfirst
end

local function DrawStandings(h, t)
  local rows = t.rows or {}
  CompetitionHeader(t, false)
  local Lf, Rt = STANDINGS.LEFT, STANDINGS.RIGHT
  Quad(L.panel, ART.white, Lf.x, Lf.y, Lf.w, Lf.h)
  Quad(L.panel, ART.white, Rt.x, Rt.y, Rt.w, Rt.h)
  -- the panels' zones first (ZoneAt picks the last drawn: the rows and tabs over them)
  for _, p in ipairs({ { Lf, "table" }, { Rt, "stats" } }) do
    S.zones[#S.zones + 1] = { x0 = p[1].x, y0 = p[1].y, x1 = p[1].x + p[1].w, y1 = p[1].y + p[1].h, kind = "tpanel",
      side = p[2], hover = true }
  end
  local per = math.floor((STANDINGS.BOTTOM - STANDINGS.ROW_Y - STANDINGS.STEP / 2) / STANDINGS.STEP) + 1
  local first = STANDINGS.View(h, rows, per)
  local x0, x1 = STANDINGS.X0, STANDINGS.X1
  local cols = {}
  Text(L.text, Tx("ColTeam"), x0 + 76, STANDINGS.HEAD_Y, "label_l", 1)
  for c, col in ipairs(STANDINGS_COLS) do
    cols[c] = { col[2], VALUE[col[3]] }
    Text(L.text, Tx(col[1]), col[2], STANDINGS.HEAD_Y, "label", 1, "c")
  end
  for i = 1, per do
    local k = first + i - 1
    local r = rows[k]
    if r == nil then break end
    local y = STANDINGS.ROW_Y + (i - 1) * STANDINGS.STEP
    TableRow(h, t, k, r, x0, x1, y, STANDINGS.STEP, cols, STANDINGS.NAME_W)
    if k == S.tcur and S.tfocus ~= "stats" then
      Frame(L.icon, x0, y - STANDINGS.STEP / 2 + 2, x1 - x0, STANDINGS.STEP - 4, 3, TINT.cut)
    end
    S.zones[#S.zones + 1] = { x0 = x0, y0 = y - STANDINGS.STEP / 2, x1 = x1, y1 = y + STANDINGS.STEP / 2, kind = "trow",
      index = k, hover = true }
  end
  -- the scroll bar: the rows in view among all of them
  if #rows > per then
    local top = STANDINGS.ROW_Y - STANDINGS.STEP / 2
    local bh = per * STANDINGS.STEP
    local th = math.max(30, bh * per / #rows)
    local at = (first - 1) / math.max(1, #rows - per)
    Quad(L.plate, ART.fill, STANDINGS.BAR_X, top + (bh - th) * at, STANDINGS.BAR_W, th, 1, nil, TINT.select)
    Quad(L.plate, ART.fill, STANDINGS.BAR_X, top, STANDINGS.BAR_W, bh, 1, nil, TINT.rest)
  end
  STANDINGS.Side(h, t, rows, Rt)
  STANDINGS.Switch(Lf, Rt)
  -- the focused side (Y toggles it): a cyan frame around its panel
  local f = S.tfocus == "stats" and Rt or Lf
  Frame(L.plate, f.x, f.y, f.w, f.h, 3, TINT.cut)
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
      elseif k <= (t.direct or 0) then Quad(L.plate, ART.cyan, x, ry - step / 2 + 2, cw, step - 4, 0.5)
      elseif k <= (t.cut or 0) then Quad(L.plate, ART.cyan, x, ry - step / 2 + 2, cw, step - 4, 0.22) end
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
    tm.Show(0, { host = MENU, view = Crc(view), top = BRACKET.TOP + BRACKET.HEAD_H + G.PAGE_DY, lift = BRACKET.LIFT })
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
  local signed, career = {}, {}
  for _, p in ipairs(h.squad or {}) do
    if p.signed then signed[p.card] = true end
    if p.level then career[p.card] = p end
  end
  -- the lineup's places (0-10 the starters, then the bench; the rest of the squad after them)
  local place = {}
  for _, x in ipairs(h.lineup or {}) do place[x.card] = x.position end
  if next(place) ~= nil then
    for _, p in ipairs(players) do p.place = place[p.card] or -1 end
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
    local cp = career[p.card]
    if cp then LEVEL.Badge(cp.level, cp.form, 1150, y, 30) else Text(L.text, tostring(p.level), 1150, y, "body_c", 0.85, "c") end
    Text(L.text, tostring(p.rating), 1300, y, "big", 0.85, "c")
    local role = p.place < 0 and "" or (p.place < starters and Tx("Starter") or Tx("Bench"))
    if signed[p.card] then role = role == "" and Tx("Signed") or (role .. " · " .. Tx("Signed")) end
    Text(L.text, role, P.x + P.w - 200, y, "label", 0.95, "c")
  end
end

-- a market row's player rating: the game's own stats when his club's numbers are read, else none
local function RatingOf(card, club)
  local r = S.rate[club or 0]
  for _, p in ipairs(r and r.players or {}) do
    if p.card == card then return p.rating end
  end
  return nil
end

-- ---- career levels: the media badge and the form arrow ---------------------------------------------------------------

LEVEL.ARROW = {   -- form -> the arrow's colour and turn (the chevron points right; radians, counter-clockwise)
  [3] = { "form_up", math.pi / 2 }, [2] = { "form_rise", math.pi / 4 }, [1] = { "form_rise", math.pi / 4 },
  [0] = { "form_even", 0 }, [-1] = { "form_dip", -math.pi / 4 }, [-2] = { "form_dip", -math.pi / 4 },
  [-3] = { "form_down", -math.pi / 2 },
}

-- the form arrow centred on cx, cy, `size` px: a coloured square with the white chevron turned to the form
function LEVEL.Arrow(form, cx, cy, size)
  local a = LEVEL.ARROW[math.max(-3, math.min(3, math.floor(tonumber(form) or 0)))]
  Quad(L.plate, ART.fill, cx - size / 2, cy - size / 2, size, size, 1, false, TINT[a[1]])
  local h = size * 0.7
  LEVEL.Turned(L.icon, ART.chevron, cx - h * 0.41, cy - h / 2, h * 0.82, h, a[2])
end

-- the media badge centred on cx, cy (`size` px square, gold / silver / bronze) with the form arrow over its top-right
-- corner, smaller (owner 2026-10-30)
function LEVEL.Badge(level, form, cx, cy, size)
  if level == nil then return end
  local tint = level >= 85 and TINT.level_gold or level >= 75 and TINT.level_silver or TINT.level_bronze
  Quad(L.plate, ART.fill, cx - size / 2, cy - size / 2, size, size, 1, false, tint)
  Text(L.text, tostring(level), cx, cy, "big", size / 46, "c")
  if form ~= nil then LEVEL.Arrow(form, cx + size / 2 - 2, cy - size / 2 + 2, math.max(16, size * 0.42)) end
end

local MARKET_POSITIONS = { 0, 1, 4, 3, 2 }      -- the filter chips: all, GK, DF, MF, FW
-- the market page (px at 1080p, y down; owner pick Mercado7): the bar (the window's line, the sections «Buscar» |
-- «En venta (n)», the budget), «Plantilla» on the left (the club's players with their status, an options menu under
-- the selected one), the section in the middle («Buscar»: the name bar, the search's filters in one row, the list;
-- «En venta»: the offers received), the player card on the right. Plates are flat colour quads (TINT) with 1 px-scaled borders. On one layer a quad drawn later lies under the
-- earlier ones: a row's badge and tag are drawn before its plate, the graph's bars before their box.
local MK = { BAR_Y = 214, BAR_H = 48, ROWS = 14, LINE = 3,
  -- the bar (owner pick Mercado7): the window's text, the sections «Buscar» | «En venta (n)» (L2 / R2, a click), the
  -- budget; SEC_X = the first section's left edge, SEC_GAP = between them
  BAR = { SEC_X = 600, SEC_GAP = 44, TEXT = 0.62, SEC = 0.72 },
  SECTIONS = { "MkSecSearch", "MkSecSale" },
  -- «Plantilla» (offsets from its top): the status filters as text tabs at TAB_Y (TAB_SCALE, smaller when a
  -- language's words are long), the rows from TOP, the options menu under the selected row (OFFERS offer lines at
  -- most, OFFER_H each, then one row OPT_H tall of three BOX px checkboxes); rows that fit down to BOTTOM
  SQ = { x = 60, y = 274, w = 500, h = 730, TAB_Y = 66, TOP = 120, STEP = 40, ROW_H = 36, BOTTOM = 716, OPT_H = 38,
    OPT_PAD = 6, TAB_SCALE = 0.72, BOX = 22, OFFERS = 3, OFFER_H = 26,
    OPT_IN = 8, OPT_GAP = 8, OPT_SC = 0.62 },   -- a status cell: the box OPT_IN px in, its label OPT_GAP px after it
  SQ_FILTERS = { "all", "transfer", "loan", "blocked" },
  SQ_FILTER_TEXT = { all = "MkFilterAll", transfer = "MkFilterTransfer", loan = "MkFilterLoan", blocked = "MkFilterBlocked" },
  -- a status: its tag's text and colour (TINT), also the colour of its option's dot
  STATUS = { transfer = { "MkTagTransfer", "orange" }, loan = { "MkTagLoan", "loan" }, blocked = { "MkTagBlocked", "draw" },
    loaned = { "MkTagLoaned", "cut" } },
  -- the middle panel (offsets from its top): «Buscar» (the name bar and the filter button BUTTON_W px right of it, the
  -- column heads, ROWS rows) or «En venta» (the offers received, SALE_STEP a row)
  TR = { x = 580, y = 274, w = 880, h = 730, BAR_Y = 30, BAR_H = 34, BUTTON_W = 190, HEAD_Y = 78, ROW_Y = 112,
    ROW_STEP = 40, ROW_H = 36, SALE_HEAD_Y = 30, SALE_Y = 72, SALE_STEP = 44 },
  -- the filter panel (X / the filter button; the look of the game's player bank filter): W px wide over the middle
  -- panel, TOP px under its top; HEAD_H its title band, ROW_H a row, the value centred VALUE_X px from its right edge
  -- with the arrows ARROW px either side, BOX the switches' box
  FILT = { W = 700, TOP = 50, PAD = 20, HEAD_H = 64, BOX_H = 64, RESET_H = 44, GAP = 10, LABEL_Y = 16, VALUE_Y = 42,
    CHECK = 24, ARROW = 16 },
  -- the filter panel's club list (A on «Club»): over the middle panel under the search bar, TITLE_H its title, ROW_H a
  -- row (a crest at CREST, the name), HEAD_H a game's header; L / R move PAGE rows
  CLUBS = { TOP = 60, PAD = 16, TITLE_H = 44, ROW_H = 40, HEAD_H = 34, CREST = 0.42, BOTTOM = 20, PAGE = 8 },
  -- the columns, from the panel's left: NAME left edge, POS / CLUB / LEVEL / KIND / UNTIL centres, PRICE / AMOUNT /
  -- RECEIVED right edges; COL.AMOUNT = the amounts' scale (shortened, no currency icon)
  COL = { NAME = 70, POS = 560, CLUB = 630, LEVEL = 720, PRICE = 850, AMOUNT = 0.78 },
  SALE_COL = { NAME = 70, CLUB = 390, KIND = 470, AMOUNT = 640, UNTIL = 730, RECEIVED = 850 },
  -- «Ver jugador» (MK.DrawView): its panel right of the slid list, HEAD_H its band, the model's box MODEL_W px wide (a
  -- face FACE px while it slides), the paged box's title TITLE_H tall between KEY_W px glyph columns with the pages'
  -- dots, a stat / move a line; the description TEXT_LINES lines at most; the slide takes FRAMES frames; a move's name
  -- from the game's move info (field SKILL_NAME_FIELD: its name text)
  VIEW = { x = 960, y = 274, w = 900, h = 730, HEAD_H = 64, PAD = 20, MODEL_W = 340, FACE = 200, TITLE_H = 56, KEY_W = 50,
    DOT = 22, DOT_H = 6, DOT_GAP = 8, DOT_Y = 18, LINE_STEP = 46, MOVE_STEP = 46, TEXT_SC = 0.8, TEXT_STEP = 36,
    TEXT_LINES = 14, STAT_LABEL_W = 170, STAT_VALUE_W = 70, STAT_BAR_H = 14, FRAMES = 12,
    PAGES = { "ViewPageDescription", "ViewPageStats", "ViewPageMoves" },
    SKILL_NAME_FIELD = 4, SKILL_NAME = 720417636 --[[a move's name text id -> its text]] },
  -- the player card (vertical): offsets from its top
  CARD = { x = 1480, y = 274, w = 380, h = 730, PAD = 24, FACE_Y = 120, FACE = 170, NAME_Y = 236, CLUB_Y = 272,
    LEVEL_Y = 322, LEVEL_LABEL_Y = 360, LINE_Y = 384, LINES_Y = 414, LINE_STEP = 34, BUTTON_H = 48, COUNTER_H = 44,
    ICON_DX = 104, ICON = 36, ICON_GAP = 8 },   -- the position / element icons: centred ICON_DX px right of the portrait's centre
  FORM = { STEP = 42, W = 36 },       -- the card's last match scores
  -- the game's text entry for the searched name
  SEARCH = { KEY_MAX = 15, KEYBOARD = 962493425, KEYBOARD_BUSY = 422535539, KEYBOARD_TEXT = 1487869455,
    KEYBOARD_TITLE = 3930276884 },
  -- the filter panel's boxes, row by row («Restablecer» last; «Club» FILTER_WIDE times as wide); the search bar: the
  -- name (srow 1), the button (srow 2)
  FILTER_GRID = { { "club", "position" }, { "level_min", "level_max", "price" }, { "series", "sort" },
    { "free", "affordable" }, { "reset" } },
  FILTER_WIDE = { club = 2 },
  SORTS = { "level", "price", "value", "potential", "form" },
  SORT_TEXT = { level = "SortLevel", price = "SortPrice", value = "SortValue", potential = "SortPotential", form = "SortForm" },
  SCORE_GOOD = 0.25,    -- a match score past ± SCORE_GOOD shows green / red on the card
  -- the transfer talks' window (owner pick negociar v2 / v3): a narrow card over the player card's column, under the
  -- bar, on the dialog layers; HEAD_H its header (the face FACE px, the crest at CREST), the - / + STEP_W px, the
  -- patience bar BAR_H, the buttons; the budget its own panel BOX_H tall, GAP under the card (owner 2026-10-31);
  -- SELL_MAX: the most asked for a player offered for, x the bid
  TALK = { x = 1300, y = 274, w = 560, h = 644, PAD = 28, HEAD_H = 104, FACE = 72, CREST = 0.5, STEP_W = 60,
    BAR_H = 12, BOX_H = 76, GAP = 10, BUTTON_H = 52, SMALL_H = 40, SELL_MAX = 5 } }

-- a text's width (px) as drawn in `style` at scale sc (an estimate from its characters)
function MK.Width(s, style, sc)
  local size = tonumber((STYLE[style] or STYLE.body):match("^fs_(%d+)")) or 28
  return Units(s) * size * TILE.DIGIT * (sc or 1)
end

-- an amount (already written out) and the currency icon after it, ending at x
function MK.AmountRight(s, x, y, style, sc)
  sc = sc or 1
  local cur = Currency()
  local size = tonumber((STYLE[style] or STYLE.body):match("^fs_(%d+)")) or 28
  local icon = (cur and cur.art) and math.floor(size * sc * 1.25) or 0
  local w = MK.Width(s, style, sc)
  local left = x - w - (icon > 0 and (CURRENCY_GAP + icon) or 0)
  Text(L.text, s, left, y, style, sc)
  if icon > 0 then Quad(L.icon, cur.art, left + w + CURRENCY_GAP, y - icon / 2, icon, icon) end
end

function MK.MoneyRight(n, x, y, style, sc) MK.AmountRight(Thousands(n), x, y, style, sc) end

-- an amount for a list column: the mode's short amount (Short)
MK.Short = Short

-- a flat plate (a TINT colour) with a border of another colour LINE px wide (nil = none)
function MK.Plate(x, y, w, h, fill, line)
  if line then
    local t = MK.LINE
    Quad(L.plate, ART.fill, x, y, w, t, 1, nil, line)
    Quad(L.plate, ART.fill, x, y + h - t, w, t, 1, nil, line)
    Quad(L.plate, ART.fill, x, y + t, t, h - 2 * t, 1, nil, line)
    Quad(L.plate, ART.fill, x + w - t, y + t, t, h - 2 * t, 1, nil, line)
  end
  Quad(L.plate, ART.fill, x, y, w, h, 1, nil, fill)
end

-- the list's position in its rows: the scroll bar right of the rows
function MK.Scroll(d, x, top, h)
  local total = d and d.total or 0
  if total <= MK.ROWS then return end
  local th = math.max(30, h * MK.ROWS / total)
  local at = ((d.first or 1) - 1) / math.max(1, total - MK.ROWS)
  Quad(L.plate, ART.fill, x, top + (h - th) * at, 8, th, 1, nil, TINT.select)
  Quad(L.plate, ART.fill, x, top, 8, h, 1, nil, TINT.rest)
  -- a click on the bar: the list there
  S.zones[#S.zones + 1] = { x0 = x - 10, y0 = top, x1 = x + 18, y1 = top + h, kind = "mscroll", top = top, h = h }
end

-- the search's steps and lists (the market's answer: config [market] search_*, the series, the career's clubs)
function MK.Meta()
  return S.mk.meta or { steps = { level = 1, low = 40, high = 99, prices = {} }, series = {}, clubs = {}, groups = {} }
end

-- a series' name (text Series_<name>, else the game's name)
function MK.SeriesName(name)
  local t = Tx("Series_" .. tostring(name))
  if t == nil or t == "" or t:find("Series_", 1, true) then return string.upper(tostring(name)) end
  return t
end

-- the search sent to the scripts: «key=value;…» (CMND_CAREERMODE_MARKET's search)
function MK.SearchText()
  local q, meta, parts = S.mk.q, MK.Meta(), {}
  if q.name ~= "" then parts[#parts + 1] = "name=" .. (q.name:gsub("[;=]", " ")) end
  if q.club ~= 0 then parts[#parts + 1] = "club=" .. string.format("%.0f", q.club) end
  if q.lmin then parts[#parts + 1] = "lmin=" .. q.lmin end
  if q.lmax then parts[#parts + 1] = "lmax=" .. q.lmax end
  if q.price > 0 and meta.steps.prices[q.price] then parts[#parts + 1] = "pmax=" .. string.format("%.0f", meta.steps.prices[q.price]) end
  if q.series > 0 and meta.series[q.series] then parts[#parts + 1] = "series=" .. meta.series[q.series][1] end
  if q.free then parts[#parts + 1] = "free=1" end
  if q.afford then parts[#parts + 1] = "afford=1" end
  return table.concat(parts, ";")
end

-- a search row's label and value (switch = its on / off for the two switches)
function MK.SearchRow(id)
  local k, q, meta = S.mk, S.mk.q, MK.Meta()
  local any = Tx("SearchAny")
  if id == "name" then return Tx("SearchName"), q.name ~= "" and q.name or Tx("SearchNameAny")
  elseif id == "club" then return Tx("SearchClub"), q.club ~= 0 and TeamName(q.club) or Tx("SearchAllClubs")
  elseif id == "position" then
    local pos = MARKET_POSITIONS[k.pos]
    return Tx("SearchPosition"), pos == 0 and Tx("PosAll") or Tx(POS_TEXT[pos])
  elseif id == "level_min" then return Tx("SearchLevelMin"), q.lmin and tostring(q.lmin) or any
  elseif id == "level_max" then return Tx("SearchLevelMax"), q.lmax and tostring(q.lmax) or any
  elseif id == "price" then
    local p = q.price > 0 and meta.steps.prices[q.price] or nil
    return Tx("SearchPrice"), p and MK.Short(p) or any
  elseif id == "series" then
    local sr = q.series > 0 and meta.series[q.series] or nil
    return Tx("SearchSeries"), sr and MK.SeriesName(sr[2]) or Tx("SearchAllSeries")
  elseif id == "free" then return Tx("SearchFree"), nil, q.free
  elseif id == "affordable" then return Tx("SearchAffordable"), nil, q.afford
  elseif id == "sort" then return Tx("SearchSort"), Tx(MK.SORT_TEXT[MK.SORTS[k.sort]])
  elseif id == "reset" then return Tx("MkFilterReset"), nil end
  return "", ""
end

-- a level row stepped: nil (no limit) <-> low .. high (max: nil above high, min: nil below low)
function MK.StepLevel(v, d, is_max)
  local st = MK.Meta().steps
  if v == nil then
    if is_max then return d < 0 and st.high or nil end
    return d > 0 and st.low or nil
  end
  v = v + d * st.level
  if v < st.low then return not is_max and nil or st.low end
  if v > st.high then return is_max and nil or st.high end
  return v
end

-- left / right on a search row (d = -1 / 1): its value changed -> true when it did
function MK.SearchChange(id, d)
  local k, q, meta = S.mk, S.mk.q, MK.Meta()
  if id == "name" then return false
  elseif id == "club" then return false
  elseif id == "position" then k.pos = (k.pos - 1 + d) % #MARKET_POSITIONS + 1
  elseif id == "level_min" then q.lmin = MK.StepLevel(q.lmin, d, false)
  elseif id == "level_max" then q.lmax = MK.StepLevel(q.lmax, d, true)
  elseif id == "price" then q.price = (q.price + d) % (#meta.steps.prices + 1)
  elseif id == "series" then q.series = (q.series + d) % (#meta.series + 1)
  elseif id == "free" then
    q.free = not q.free
    if q.free then q.club = 0 end
  elseif id == "affordable" then q.afford = not q.afford
  elseif id == "sort" then k.sort = (k.sort - 1 + d) % #MK.SORTS + 1 end
  return true
end

-- a search chip lit: its filter set (the order: always)
function MK.ChipOn(id)
  local k, q = S.mk, S.mk.q
  if id == "name" then return q.name ~= ""
  elseif id == "club" then return q.club ~= 0
  elseif id == "position" then return k.pos ~= 1
  elseif id == "level_min" then return q.lmin ~= nil
  elseif id == "level_max" then return q.lmax ~= nil
  elseif id == "price" then return q.price > 0
  elseif id == "series" then return q.series > 0
  elseif id == "free" then return q.free
  elseif id == "affordable" then return q.afford end
  return true
end

-- the filters set (every box but the order and «Restablecer»)
function MK.FilterCount()
  local n = 0
  for _, row in ipairs(MK.FILTER_GRID) do
    for _, id in ipairs(row) do
      if id ~= "sort" and id ~= "reset" and MK.ChipOn(id) then n = n + 1 end
    end
  end
  return n
end

-- the search as the list was asked with (the panel applies on close only when it changed)
function MK.FilterKey() return MK.SearchText() .. "|" .. S.mk.pos .. "|" .. S.mk.sort end

-- the filter panel opened (its first box focused) / closed: the list asked again when a filter changed
function MK.FiltersOpen()
  local k = S.mk
  k.sec, k.focus, k.srow, k.menu = 1, "search", 2, false
  k.fp = { r = 1, c = 1, was = MK.FilterKey() }
  Snd(SND.DECIDE)
  S.dirty = true
end

function MK.FiltersClose()
  local k = S.mk
  if k.fp == nil then return end
  local changed = MK.FilterKey() ~= k.fp.was
  k.fp = nil
  Snd(SND.BACK)
  if changed then MK.Reset() end
  S.dirty = true
end

-- the focused box's filter id
function MK.FilterId()
  local fp = S.mk.fp
  return MK.FILTER_GRID[fp.r][fp.c]
end

-- the box at row r, column c focused (c kept inside the row) -> true when it changed
function MK.FilterFocus(r, c)
  local fp, grid = S.mk.fp, MK.FILTER_GRID
  r = math.max(1, math.min(#grid, r))
  c = math.max(1, math.min(#grid[r], c))
  if r == fp.r and c == fp.c then return false end
  fp.r, fp.c = r, c
  Snd(SND.MOVE)
  S.dirty = true
  return true
end

-- the focused box used (d = -1 / 1 for a stepper): «Restablecer» clears every filter and the order, «Club» opens
-- the club list, a switch flips, a stepper steps
function MK.FilterChange(d)
  local k = S.mk
  local id = MK.FilterId()
  if id == "reset" then
    for _, row in ipairs(MK.FILTER_GRID) do
      for _, f in ipairs(row) do if f ~= "sort" and f ~= "reset" then MK.Clear(f) end end
    end
    k.sort = 1
  elseif id == "club" then
    MK.ClubListOpen()
    return
  elseif not MK.SearchChange(id, d) then
    return
  end
  Snd(SND.MOVE)
  S.dirty = true
end

-- the club list's entries: «Todos», then each game's header and its clubs (the career's order inside a game)
function MK.ClubItems()
  local meta = MK.Meta()
  local items = { { kind = "all" } }
  local groups = meta.groups or {}
  if #groups == 0 then
    for _, t in ipairs(meta.clubs or {}) do items[#items + 1] = { kind = "club", team = t } end
    return items
  end
  for _, g in ipairs(groups) do
    items[#items + 1] = { kind = "head", game = g[1] }
    for _, t in ipairs(g[2] or {}) do items[#items + 1] = { kind = "club", team = t } end
  end
  return items
end

-- the club list opened on the club picked (or «Todos»)
function MK.ClubListOpen()
  local q = S.mk.q
  local items = MK.ClubItems()
  local sel = 1
  for i, it in ipairs(items) do
    if it.kind == "club" and it.team == q.club then sel = i end
  end
  S.mk.fp.list = { items = items, sel = sel, first = 1 }
  Snd(SND.DECIDE)
  S.dirty = true
end

-- the club list's cursor moved d entries (the headers skipped) -> true when it moved
function MK.ClubListMove(d)
  local cl = S.mk.fp.list
  local i, step = cl.sel, d > 0 and 1 or -1
  for _ = 1, math.abs(d) do
    local j = i + step
    while cl.items[j] and cl.items[j].kind == "head" do j = j + step end
    if cl.items[j] == nil then break end
    i = j
  end
  if i == cl.sel then return false end
  cl.sel = i
  Snd(SND.MOVE)
  S.dirty = true
  return true
end

-- the club list's entry i picked: the search's club (a club: not «Solo libres» any more), back to the panel
function MK.ClubPick(i)
  local q, fp = S.mk.q, S.mk.fp
  local it = fp.list.items[i]
  if it == nil or it.kind == "head" then return end
  q.club = it.kind == "club" and it.team or 0
  if q.club ~= 0 then q.free = false end
  fp.list = nil
  Snd(SND.DECIDE)
  S.dirty = true
end

-- every input while the filter panel is open: what = "move" (dx, dy: the arrows, the wheel), "step" (d: L1 / R1,
-- L2 / R2), "accept", "back", "hover" / "click" (the zone under the pointer)
function MK.FilterInput(what, a, b)
  local fp = S.mk.fp
  if fp.list then
    if what == "move" then
      if (b or 0) ~= 0 then MK.ClubListMove(b) end
    elseif what == "step" then
      MK.ClubListMove(a * MK.CLUBS.PAGE)
    elseif what == "accept" then
      MK.ClubPick(fp.list.sel)
    elseif what == "back" then
      fp.list = nil
      Snd(SND.BACK)
      S.dirty = true
    elseif what == "hover" then
      if a and a.kind == "mclub" and a.index ~= fp.list.sel then
        fp.list.sel = a.index
        Snd(SND.MOVE)
        S.dirty = true
      end
    elseif what == "click" then
      if a and a.kind == "mclub" then
        MK.ClubPick(a.index)
      elseif not (a and a.kind == "mclubs") then
        fp.list = nil
        Snd(SND.BACK)
        S.dirty = true
      end
    end
    return
  end
  if what == "move" then
    if (b or 0) ~= 0 then
      MK.FilterFocus((fp.r - 1 + b) % #MK.FILTER_GRID + 1, fp.c)
    elseif (a or 0) ~= 0 then
      MK.FilterFocus(fp.r, fp.c + a)
    end
  elseif what == "step" then
    local id = MK.FilterId()
    if id ~= "club" and id ~= "reset" then MK.FilterChange(a) end
  elseif what == "accept" then
    MK.FilterChange(1)
  elseif what == "back" then
    MK.FiltersClose()
  elseif what == "hover" then
    if a and a.kind == "mfilt" and a.dx == nil then MK.FilterFocus(a.r, a.c) end
  elseif what == "click" then
    -- a box focused (clicked again: used), a stepper's arrow: that way; outside the panel: closed (applied)
    if a == nil or (a.kind ~= "mfilt" and a.kind ~= "mpanel") then MK.FiltersClose() return end
    if a.kind == "mfilt" then
      if a.dx then
        fp.r, fp.c = a.r, a.c
        MK.FilterChange(a.dx)
      elseif not MK.FilterFocus(a.r, a.c) then
        MK.FilterChange(1)
      end
    end
  end
end

-- one box of the filter panel at (x, y), w x h (on the dialog layers): its label over its value (a stepper: arrows
-- either side on the focused box; «Club»: a down arrow, its list on A), a switch: its tick box and label,
-- «Restablecer»: its label
function MK.FilterBox(id, x, y, w, h, on, r, c)
  local F = MK.FILT
  S.zones[#S.zones + 1] = { x0 = x, y0 = y, x1 = x + w, y1 = y + h, kind = "mfilt", r = r, c = c, hover = true }
  local label, value, switch = MK.SearchRow(id)
  if id == "reset" then
    Text(L.dtext, label, x + w / 2, y + h / 2, on and "body_w" or "body_c", 0.78, "c")
  elseif value == nil then
    local bs, bx, cy = F.CHECK, x + 16, y + h / 2
    G.CheckBox(L.dialog, bx, cy, bs, switch, TINT.select)
    Text(L.dtext, Fit(label, w - bs - 40, 20), bx + bs + 12, cy, on and "item_on" or "item", 0.62)
  else
    Text(L.dtext, Fit(label, w - 24, 16), x + 12, y + F.LABEL_Y, on and "item_on" or "label_l", on and 0.5 or 0.85)
    local vy = y + F.VALUE_Y
    if id == "club" then
      Text(L.dtext, Fit(value, w - 60, 22), x + 12, vy, on and "item_on" or "item", 0.66)
      LEVEL.Turned(L.dialog, ART.chevron, x + w - 30, vy - 8, 12, 16, math.pi / 2)
    else
      Text(L.dtext, Fit(value, w - 2 * F.ARROW - 24, 20), x + w / 2, vy, on and "body_w" or "body_c", 0.72, "c")
      if on then
        Text(L.dtext, "<", x + F.ARROW, vy, "body_w", 0.8, "c")
        Text(L.dtext, ">", x + w - F.ARROW, vy, "body_w", 0.8, "c")
        S.zones[#S.zones + 1] = { x0 = x, y0 = y, x1 = x + 2 * F.ARROW, y1 = y + h, kind = "mfilt", r = r, c = c,
          dx = -1 }
        S.zones[#S.zones + 1] = { x0 = x + w - 2 * F.ARROW, y0 = y, x1 = x + w, y1 = y + h, kind = "mfilt", r = r,
          c = c, dx = 1 }
      end
    end
  end
  Quad(L.dialog, ART.fill, x, y, w, h, 1, nil, on and TINT.cut or TINT.stripe)
end

-- the filter panel (owner 2026-10-31, the look of the game's player bank filter): over the middle panel on the dialog
-- layers, a grid of compact labelled boxes (MK.FILTER_GRID, «Club» FILTER_WIDE times as wide), «Restablecer» under
-- them; the arrows move between the boxes, A uses the focused one, L / R step it, B (or X) closes and applies.
-- Hidden while the club list is open (that list takes the middle panel's page layers)
function MK.DrawFilters()
  local k = S.mk
  if k.fp == nil or k.fp.list or S.dialog then return end
  local F, T_, grid = MK.FILT, MK.TR, MK.FILTER_GRID
  local W = F.W
  local X = T_.x + (T_.w - W) / 2
  local Y = T_.y + F.TOP
  local H = F.HEAD_H + 2 * F.PAD + (#grid - 1) * (F.BOX_H + F.GAP) + F.RESET_H
  -- the panel's own zone first (ZoneAt picks the last drawn: the boxes over it)
  S.zones[#S.zones + 1] = { x0 = X, y0 = Y, x1 = X + W, y1 = Y + H, kind = "mpanel" }
  Text(L.dtext, Tx("MkFilterTitle"), X + F.PAD + 10, Y + F.HEAD_H / 2, "title", 0.86)
  local left, inner = X + F.PAD, W - 2 * F.PAD
  local y = Y + F.HEAD_H + F.PAD
  for r, row in ipairs(grid) do
    local h = r == #grid and F.RESET_H or F.BOX_H
    local units = 0
    for _, id in ipairs(row) do units = units + (MK.FILTER_WIDE[id] or 1) end
    local unit = (inner - F.GAP * (#row - 1)) / units
    local x = left
    for c, id in ipairs(row) do
      local w = unit * (MK.FILTER_WIDE[id] or 1)
      MK.FilterBox(id, x, y, w, h, k.fp.r == r and k.fp.c == c, r, c)
      x = x + w + F.GAP
    end
    y = y + h + F.GAP
  end
  -- the title band, the panel (a quad drawn later lies under)
  Quad(L.dialog, ART.navy, X, Y, W, F.HEAD_H)
  Quad(L.dialog, ART.fill, X, Y, W, H, 1, nil, TINT.white)
end

-- the club list (A on «Club»): in the middle panel under the search bar, on the page layers (the list's rows are not
-- drawn under it): «Todos», then each game's header and its clubs, a crest and the name a row; the cursor kept in
-- sight; up / down / the wheel move, A or a click picks, B goes back to the panel
function MK.DrawClubList()
  local k, T_, Cl = S.mk, MK.TR, MK.CLUBS
  local cl = k.fp.list
  local x0, x1 = T_.x + Cl.PAD, T_.x + T_.w - Cl.PAD
  local top, bottom = T_.y + Cl.TOP, T_.y + T_.h - Cl.BOTTOM
  S.zones[#S.zones + 1] = { x0 = T_.x, y0 = T_.y, x1 = T_.x + T_.w, y1 = T_.y + T_.h, kind = "mclubs" }
  Text(L.text, Tx("SearchClub"), x0 + 8, top + Cl.TITLE_H / 2, "item", 0.8)
  top = top + Cl.TITLE_H
  local function height(it) return it.kind == "head" and Cl.HEAD_H or Cl.ROW_H end
  -- the first entry shown: the cursor's entry in sight
  local first = math.max(1, math.min(cl.first or 1, cl.sel))
  local span = 0
  for i = first, cl.sel do span = span + height(cl.items[i]) end
  while span > bottom - top and first < cl.sel do
    span = span - height(cl.items[first])
    first = first + 1
  end
  cl.first = first
  local y = top
  for i = first, #cl.items do
    local it = cl.items[i]
    local h = height(it)
    if y + h > bottom then break end
    if it.kind == "head" then
      Text(L.text, Tx("Saga" .. tostring(it.game)), x0 + 8, y + h / 2 + 2, "label_l", 1.0)
      Quad(L.plate, ART.fill, x0, y + h - 3, x1 - x0, 2, 1, nil, TINT.rest)
    else
      local cy = y + h / 2
      if i == cl.sel then MK.RowMark(x0, x1, cy, h - 4, true) end
      S.zones[#S.zones + 1] = { x0 = x0, y0 = y, x1 = x1, y1 = y + h, kind = "mclub", index = i, hover = true }
      if it.kind == "club" then Crest(it.team, x0 + 34, cy, Cl.CREST) end
      local name = it.kind == "all" and Tx("SearchAllClubs") or TeamName(it.team)
      Text(L.text, Fit(name, x1 - x0 - 120, 22), x0 + 72, cy, "body", 0.78)
      if (it.kind == "all" and k.q.club == 0) or (it.kind == "club" and it.team == k.q.club) then
        HOME.Dot(x1 - 24, cy, 12, TINT.select)
      end
    end
    y = y + h
  end
end

-- a search filter back to «any»
function MK.Clear(id)
  local k, q = S.mk, S.mk.q
  if id == nil or id == "name" then q.name = "" end
  if id == nil or id == "club" then q.club = 0 end
  if id == nil or id == "position" then k.pos = 1 end
  if id == nil or id == "level_min" then q.lmin = nil end
  if id == nil or id == "level_max" then q.lmax = nil end
  if id == nil or id == "price" then q.price = 0 end
  if id == nil or id == "series" then q.series = 0 end
  if id == nil or id == "free" then q.free = false end
  if id == nil or id == "affordable" then q.afford = false end
end

-- the game's text entry for the searched name (retail OpenSearchNameInputWindow): open, then Step reads it back
function MK.Keyboard()
  local Sx = MK.SEARCH
  local ok = pcall(funcLuaCommand, Sx.KEYBOARD, 0, S.mk.q.name, Sx.KEYBOARD_TITLE, 0, Sx.KEY_MAX, 0, 0, 0, 0, 0, 0,
    true, true, 1)
  if not ok then Snd(SND.BUZZER) return end
  S.kb = { at = S.frame }
  S.dirty = true
  M(C.INPUT, MENU, false)
  Log("market search: text entry open")
end

-- Step while the text entry is up: its answer once it closed (an empty / cancelled one clears the name)
function MK.KeyboardStep()
  local Sx = MK.SEARCH
  local okb, busy = pcall(funcLuaCommand, Sx.KEYBOARD_BUSY)
  if okb and busy == true then return end
  S.kb = nil
  M(C.INPUT, MENU, true)
  local okt, text = pcall(funcLuaCommand, Sx.KEYBOARD_TEXT)
  if okt and type(text) == "string" then
    S.mk.q.name = text:gsub("^%s+", ""):gsub("%s+$", "")
    Log("market search: name «" .. S.mk.q.name .. "»")
    MK.Reset()
  end
  S.dirty = true
end

-- «Plantilla»'s rows under its status filter (S.mk.sf: MK.SQ_FILTERS; «Cedibles» also holds the men out on loan),
-- kept until the squad or the filter changes
function MK.SquadRows()
  local k = S.mk
  local sq = k.sq
  if sq == nil then return {} end
  local f = MK.SQ_FILTERS[k.sf] or "all"
  local c = k.sqf
  if c and c.src == sq and c.f == f then return c.rows end
  local rows = {}
  for _, r in ipairs(sq.rows or {}) do
    local st = r.status or "none"
    if f == "all" or st == f or (f == "loan" and st == "loaned") then rows[#rows + 1] = r end
  end
  k.sqf = { src = sq, f = f, rows = rows }
  return rows
end

function MK.SquadRow() return MK.SquadRows()[S.mk.ssel] end

-- «En venta»: every offer received for a player of the club ({ r = his row, o = the offer }), kept until the squad
-- changes
function MK.SaleRows()
  local k = S.mk
  local sq = k.sq
  if sq == nil then return {} end
  if k.sale and k.sale.src == sq then return k.sale.rows end
  local rows = {}
  for _, r in ipairs(sq.rows or {}) do
    for _, o in ipairs(r.offers or {}) do rows[#rows + 1] = { r = r, o = o } end
  end
  k.sale = { src = sq, rows = rows }
  return rows
end

function MK.SaleRow() return MK.SaleRows()[S.mk.osel] end

-- a negotiated offer's state: «Esperando respuesta», «Precio aceptado» (nil: nothing to say)
function MK.OfferState(o)
  if o.kind == "loan" then return nil end
  if o.pending then return Tx("MkWaitingReply") end
  if o.agreed then return Tx("MkPriceAgreed") end
  return nil
end

-- «Negociar» on an offer: a transfer offer whose bidder is not answering, has not agreed and has patience left
function MK.CanNegotiate(o)
  return o ~= nil and o.kind ~= "loan" and not o.pending and not o.agreed and (o.patience or 1) > 0
end

-- the options menu of a player of the club: the three statuses (a man out on loan: none)
function MK.Options(r)
  local out = {}
  if r == nil or r.status == "loaned" then return out end
  for _, st in ipairs({ "transfer", "loan", "blocked" }) do out[#out + 1] = { status = st } end
  return out
end

-- the options menu's height: the offers for him (OFFERS lines at most) over one row of the three status checkboxes
function MK.MenuHeight(r, opts)
  local Q = MK.SQ
  return math.min(Q.OFFERS, #(r and r.offers or {})) * Q.OFFER_H + Q.OPT_H + 2 * Q.OPT_PAD
end

-- the options under the selected player, from `top` (owner 2026-10-31): the offers for him (read only; answered on
-- «En venta»), then one row «☐ Transferible ☐ Cedible ☐ Bloqueado» (a ticked box: his status; the focused one lit;
-- left / right move, A ticks / unticks, one at a time) -> the y under the menu
function MK.DrawOptions(r, opts, x0, top, x1, focused)
  local Q, k = MK.SQ, S.mk
  local bx0, bx1 = x0 + 12, x1 - 12
  local y = top + Q.OPT_PAD
  for i, o in ipairs(r.offers or {}) do
    if i > Q.OFFERS then break end
    local line = Tx(o.kind == "loan" and "MkLoanOfferLine" or "MkOfferLine", TeamName(o.bidder), MK.Short(o.amount))
    Text(L.text, Fit(line, bx1 - bx0 - 24, 18), bx0 + 12, y + Q.OFFER_H / 2, "label_l", 0.9)
    y = y + Q.OFFER_H
  end
  -- three equal cells from the player rows' left edge, one text size for all (the longest label fits its cell),
  -- focused or not; the focused cell framed thin in cyan
  local cy = y + Q.OPT_H / 2
  local cw = (x1 - x0) / #opts
  local bs = Q.BOX
  local room, longest = cw - Q.OPT_IN - bs - Q.OPT_GAP - Q.OPT_IN, 1
  for _, opt in ipairs(opts) do longest = math.max(longest, CAL.Width(Tx(MK.STATUS[opt.status][1]), "body", 1)) end
  local sc = math.min(Q.OPT_SC, room / longest)
  for i, opt in ipairs(opts) do
    local cx = x0 + (i - 1) * cw
    local on = focused and i == k.opt
    local bx = cx + Q.OPT_IN
    -- the box: a ticked one filled with the status' colour and a white tick, else a grey frame
    G.CheckBox(L.plate, bx, cy, bs, r.status == opt.status, TINT[MK.STATUS[opt.status][2]])
    if on then Frame(L.icon, cx + 3, cy - Q.OPT_H / 2 + 3, cw - 6, Q.OPT_H - 6, 2, TINT.cut) end
    S.zones[#S.zones + 1] = { x0 = cx, y0 = cy - Q.OPT_H / 2, x1 = cx + cw, y1 = cy + Q.OPT_H / 2, kind = "mopt",
      index = i, hover = true }
    Text(L.text, Tx(MK.STATUS[opt.status][1]), bx + bs + Q.OPT_GAP, cy, "body", sc)
  end
  local h = MK.MenuHeight(r, opts)
  Quad(L.plate, ART.fill, bx0, top, bx1 - bx0, h, 1, nil, TINT.stripe)
  return top + h + 6
end

-- a white panel with its title (and a grey note at its right) on its first line, no band
function MK.Panel(x, y, w, h, title, note)
  Quad(L.panel, ART.white, x, y, w, h)
  if title then Text(L.text, title, x + 24, y + 32, "item", 0.86) end
  if note then Text(L.text, note, x + w - 24 - MK.Width(note, "label", 1.0), y + 32, "label_l", 1.0) end
end

-- a row's selection: focused, a light plate with the accent on its left edge; else a grey plate
function MK.RowMark(x0, x1, y, h, focused)
  if focused then
    Quad(L.plate, ART.fill, x0, y - h / 2, 5, h, 1, nil, TINT.select)
    Quad(L.plate, ART.fill, x0, y - h / 2, x1 - x0, h, 1, nil, TINT.window)
    Cursor(x0 + 2, y, 32)
  else
    Quad(L.plate, ART.fill, x0, y - h / 2, x1 - x0, h, 1, nil, TINT.stripe)
  end
end

-- «Plantilla»: the status filters as text tabs (the chosen one underlined), the club's players from sfirst
-- (position, name, status, media), the options menu under the selected one while it is open
function MK.DrawSquad()
  local k, Q = S.mk, MK.SQ
  local sq = k.sq
  MK.Panel(Q.x, Q.y, Q.w, Q.h, Tx("TabSquad"),
    sq and string.format("%d / %d", (sq.squad or 0) + (sq.loaned or 0), sq.max_squad or 0) or nil)
  local x0, x1 = Q.x + 14, Q.x + Q.w - 14
  local labels, text_w, gap = {}, 0, 24
  for i, f in ipairs(MK.SQ_FILTERS) do
    labels[i] = Tx(MK.SQ_FILTER_TEXT[f])
    text_w = text_w + MK.Width(labels[i], "body", Q.TAB_SCALE)
  end
  local sc = Q.TAB_SCALE * math.min(1, (x1 - x0 - 10 - gap * (#labels - 1)) / math.max(1, text_w))
  local tx, ty = x0 + 10, Q.y + Q.TAB_Y
  for i, label in ipairs(labels) do
    local w = MK.Width(label, "body", sc)
    local on = i == k.sf
    if on then
      Text(L.text, label, tx, ty, "body", sc)
      Quad(L.plate, ART.fill, tx, ty + 17, w, 3, 1, nil, TINT.select)
    else
      Text(L.text, label, tx, ty, "label_l", sc * 28 / 22)
    end
    S.zones[#S.zones + 1] = { x0 = tx - 8, y0 = ty - 20, x1 = tx + w + 8, y1 = ty + 22, kind = "msf", index = i }
    tx = tx + w + gap
  end
  Quad(L.plate, ART.fill, x0, ty + 26, x1 - x0, 2, 1, nil, TINT.rest)
  local rows = MK.SquadRows()
  if sq ~= nil and #rows == 0 then
    Text(L.text, Tx("MarketEmpty"), Q.x + Q.w / 2, Q.y + Q.h / 2 + 40, "body_c", 0.9, "c")
    return
  end
  local focused = k.focus == "squad"
  local opts = (k.menu and focused) and MK.Options(rows[k.ssel]) or {}
  local menu_h = #opts > 0 and (MK.MenuHeight(rows[k.ssel], opts) + 10) or 0
  local fit = math.max(1, math.floor((Q.BOTTOM - (Q.TOP - Q.STEP / 2) - menu_h) / Q.STEP))
  k.ssel = math.max(1, math.min(k.ssel, math.max(1, #rows)))
  k.sfirst = math.max(1, math.min(k.sfirst or 1, k.ssel))
  if k.ssel > k.sfirst + fit - 1 then k.sfirst = k.ssel - fit + 1 end
  k.sfirst = math.max(1, math.min(k.sfirst, math.max(1, #rows - fit + 1)))
  local y = Q.y + Q.TOP
  for i = k.sfirst, math.min(#rows, k.sfirst + fit - 1) do
    local r = rows[i]
    local sel = i == k.ssel
    if sel then MK.RowMark(x0, x1, y, Q.ROW_H, focused and not k.menu) end
    S.zones[#S.zones + 1] = { x0 = x0, y0 = y - Q.ROW_H / 2, x1 = x1, y1 = y + Q.ROW_H / 2, kind = "msq", index = i,
      hover = true }
    Face(r.card, x0 + 26, y, 34, (r.club or 0) ~= 0 and r.club or nil)
    Text(L.text, Tx(POS_TEXT[r.position] or "PosMF"), x0 + 66, y, "label", 0.95, "c")
    local st = MK.STATUS[r.status or "none"]
    local tag_w = 0
    if st then
      local tag = Tx(st[1])
      tag_w = MK.Width(tag, "label", 0.9) + 22
      local tx2 = x1 - 56 - tag_w
      HOME.Dot(tx2 + 7, y, 12, TINT[st[2]])
      Text(L.text, tag, tx2 + 18, y, "label_l", 0.9)
    end
    Text(L.text, Fit(r.name ~= "" and r.name or "-", x1 - 64 - tag_w - (x0 + 92), 22), x0 + 92, y, "body", 0.78)
    Text(L.text, r.level and tostring(r.level) or "-", x1 - 24, y, "big", 0.78, "c")
    local yc = y
    y = y + Q.STEP
    if sel and #opts > 0 then y = MK.DrawOptions(r, opts, x0, yc + Q.ROW_H / 2 + 4, x1, true) + Q.STEP / 2 end
  end
end

-- «Buscar»: the name bar (A: the game's text entry) and the filter button (X: the filter panel), the column heads,
-- ROWS rows from d.first, the range under them
function MK.DrawList()
  local k, d, T_, C_ = S.mk, S.mk.data, MK.TR, MK.COL
  MK.Panel(T_.x, T_.y, T_.w, T_.h)
  local X = T_.x
  local x0, right = X + 16, X + C_.PRICE
  local search = k.focus == "search"
  local q = k.q
  -- the name bar (A: the game's text entry) and the filter button right of it (X; the count of filters set); hidden
  -- while the game's text entry is up (its own window shows the name; the player bank hides its field too)
  local name_on = search and k.srow == 1
  local by = T_.y + T_.BAR_Y
  if not S.kb then
    local bx = right - T_.BUTTON_W
    local bar_r = bx - 10
    MK.Plate(x0, by - T_.BAR_H / 2, bar_r - x0, T_.BAR_H, name_on and TINT.window or TINT.stripe,
      name_on and TINT.select or nil)
    S.zones[#S.zones + 1] = { x0 = x0, y0 = by - T_.BAR_H / 2, x1 = bar_r, y1 = by + T_.BAR_H / 2, kind = "mbar",
      hover = true }
    local hint = Tx("SearchKeyboardHint")
    local hint_w = MK.Width(hint, "label", 0.9)
    if q.name ~= "" then
      Text(L.text, Fit(q.name, bar_r - x0 - hint_w - 60, 22), x0 + 16, by, "body", 0.78)
    else
      Text(L.text, Fit(Tx("MkSearchBar"), bar_r - x0 - hint_w - 60, 20), x0 + 16, by, "label_l", 1.0)
    end
    Text(L.text, hint, bar_r - 14 - hint_w, by, "label_l", 0.9)
    local set = MK.FilterCount()
    local button_on = search and k.srow == 2
    MK.Plate(bx, by - T_.BAR_H / 2, right - bx, T_.BAR_H, button_on and TINT.cut or (set > 0 and TINT.select or TINT.chip),
      button_on and TINT.navy or nil)
    S.zones[#S.zones + 1] = { x0 = bx, y0 = by - T_.BAR_H / 2, x1 = right, y1 = by + T_.BAR_H / 2, kind = "mfbtn",
      hover = true }
    Text(L.text, Fit(set > 0 and Tx("MkFiltersOn", set) or Tx("MkFilters"), right - bx - 16, 20), bx + (right - bx) / 2,
      by, (button_on or set > 0) and "body_w" or "body_c", 0.7, "c")
  end
  if k.fp and k.fp.list then
    MK.DrawClubList()
    return
  end
  -- the column heads, the rows
  local hy = T_.y + T_.HEAD_Y
  local price_head = Tx("ColPrice")
  Text(L.text, Tx("ColPlayer"), X + C_.NAME, hy, "label_l", 0.95)
  Text(L.text, Tx("ColPos"), X + C_.POS, hy, "label", 0.95, "c")
  Text(L.text, Tx("ColClub"), X + C_.CLUB, hy, "label", 0.95, "c")
  Text(L.text, Tx("MarketLevel"), X + C_.LEVEL, hy, "label", 0.95, "c")
  Text(L.text, price_head, right - 10 - MK.Width(price_head, "label", 0.95), hy, "label_l", 0.95)
  local rows = d and d.rows or {}
  local top = T_.y + T_.ROW_Y
  local list_mid = top + (MK.ROWS - 1) * T_.ROW_STEP / 2
  if k.pricing then
    local pct = math.floor(100 * (k.pricing.done or 0) / math.max(1, k.pricing.total or 1))
    Text(L.text, Tx("MarketPricing", pct), X + T_.w / 2, list_mid, "body_c", 0.9, "c")
  elseif d and #rows == 0 then
    Text(L.text, Tx("MarketEmpty"), X + T_.w / 2, list_mid, "body_c", 0.9, "c")
  end
  local first = d and d.first or 1
  for i, r in ipairs(rows) do
    local y = top + (i - 1) * T_.ROW_STEP
    local sel = first + i - 1 == k.sel
    if sel and k.focus ~= "squad" then MK.RowMark(x0, right, y, T_.ROW_H, k.focus == "list") end
    S.zones[#S.zones + 1] = { x0 = x0, y0 = y - T_.ROW_H / 2, x1 = right, y1 = y + T_.ROW_H / 2, kind = "mrow",
      index = first + i - 1, hover = true }
    Face(r.card, x0 + 30, y, 34, (r.club or 0) ~= 0 and r.club or nil)
    Text(L.text, Fit(r.name ~= "" and r.name or "-", C_.POS - C_.NAME - 50, 22), X + C_.NAME, y, "body", 0.78)
    Text(L.text, Tx(POS_TEXT[r.position] or "PosMF"), X + C_.POS, y, "label", 0.95, "c")
    if (r.club or 0) ~= 0 then
      Crest(r.club, X + C_.CLUB, y, 0.5)
    else
      Text(L.text, Tx(r.national and "MarketOther" or "MarketFree"), X + C_.CLUB, y, "label", 0.9, "c")
    end
    local level = r.level or RatingOf(r.card, r.club)
    Text(L.text, level and tostring(level) or "-", X + C_.LEVEL, y, "big", 0.78, "c")
    local price = MK.Short(r.price)
    Text(L.text, price, right - 10 - MK.Width(price, "item", C_.AMOUNT), y, "item", C_.AMOUNT)
  end
  MK.Scroll(d, right + 8, top - T_.ROW_H / 2, MK.ROWS * T_.ROW_STEP - 4)
  if d and (d.total or 0) > 0 then
    local range = Tx("MarketRange", first, math.min(d.total, first + #rows - 1), Thousands(d.total))
    Text(L.text, range, right - MK.Width(range, "label", 1), T_.y + T_.h - 22, "label_l", 1.0)
  end
end

-- «En venta»: the offers received for the club's players (player, the bidding club, transfer / loan, the amount, the
-- loan's end, the day received), the note that they lapse when the window closes
function MK.DrawSale()
  local k, T_, SC = S.mk, MK.TR, MK.SALE_COL
  MK.Panel(T_.x, T_.y, T_.w, T_.h)
  local X = T_.x
  local x0, right = X + 16, X + T_.w - 16
  local hy = T_.y + T_.SALE_HEAD_Y
  local amount_head, received_head = Tx("MkColAmount"), Tx("MkColReceived")
  Text(L.text, Tx("ColPlayer"), X + SC.NAME, hy, "label_l", 0.95)
  Text(L.text, Tx("ColClub"), X + SC.CLUB, hy, "label", 0.95, "c")
  Text(L.text, Tx("MkColKind"), X + SC.KIND, hy, "label", 0.95, "c")
  Text(L.text, amount_head, X + SC.AMOUNT - MK.Width(amount_head, "label", 0.95), hy, "label_l", 0.95)
  Text(L.text, Tx("MkColUntil"), X + SC.UNTIL, hy, "label", 0.95, "c")
  Text(L.text, received_head, X + SC.RECEIVED - MK.Width(received_head, "label", 0.95), hy, "label_l", 0.95)
  Quad(L.plate, ART.fill, x0, hy + 18, right - x0, 2, 1, nil, TINT.rest)
  Text(L.text, Fit(Tx("MkSaleNote"), T_.w - 40, 20), x0 + 4, T_.y + T_.h - 22, "label_l", 0.95)
  local rows = MK.SaleRows()
  if k.sq ~= nil and #rows == 0 then
    Text(L.text, Tx("MkSaleEmpty"), X + T_.w / 2, T_.y + T_.h / 2, "body_c", 0.9, "c")
    return
  end
  local fit = math.max(1, math.floor((T_.h - T_.SALE_Y - 60) / T_.SALE_STEP) + 1)
  k.osel = math.max(1, math.min(k.osel or 1, math.max(1, #rows)))
  k.ofirst = math.max(1, math.min(k.ofirst or 1, k.osel))
  if k.osel > k.ofirst + fit - 1 then k.ofirst = k.osel - fit + 1 end
  for i = k.ofirst, math.min(#rows, k.ofirst + fit - 1) do
    local r, o = rows[i].r, rows[i].o
    local y = T_.y + T_.SALE_Y + (i - k.ofirst) * T_.SALE_STEP
    -- the kind's chip first: the row's plate is drawn after it, under it
    local loan = o.kind == "loan"
    local kind = Tx(loan and "MkKindLoan" or "MkKindTransfer")
    local cw = MK.Width(kind, "body_w", 0.56) + 20
    Quad(L.plate, ART.fill, X + SC.KIND - cw / 2, y - 13, cw, 26, 1, nil, loan and TINT.loan or TINT.orange)
    Text(L.text, kind, X + SC.KIND, y, "body_w", 0.56, "c")
    if i == k.osel and k.focus ~= "squad" then MK.RowMark(x0, right, y, T_.SALE_STEP - 6, k.focus == "list") end
    S.zones[#S.zones + 1] = { x0 = x0, y0 = y - T_.SALE_STEP / 2, x1 = right, y1 = y + T_.SALE_STEP / 2,
      kind = "msale", index = i, hover = true }
    Face(r.card, x0 + 30, y, 34, (r.club or 0) ~= 0 and r.club or nil)
    local state = MK.OfferState(o)
    local name_y = state and y - 9 or y
    Text(L.text, Fit(r.name ~= "" and r.name or "-", SC.CLUB - SC.NAME - 50, 22), X + SC.NAME, name_y, "body", 0.78)
    if state then Text(L.text, Fit(state, SC.KIND - SC.NAME - 100, 16), X + SC.NAME, y + 11, "label_l", 0.74) end
    Crest(o.bidder, X + SC.CLUB, y, 0.5)
    local amount = MK.Short(o.amount)
    Text(L.text, amount, X + SC.AMOUNT - MK.Width(amount, "item", MK.COL.AMOUNT), y, "item", MK.COL.AMOUNT)
    Text(L.text, (loan and o.back) and DateShort(o.back) or "-", X + SC.UNTIL, y, "body_c", 0.74, "c")
    local day = o.day and DateShort(o.day) or "-"
    Text(L.text, day, X + SC.RECEIVED - MK.Width(day, "label", 1.0), y, "label_l", 1.0)
  end
end

-- a card line: its label on the left, its value (text, or an amount with the currency) on the right
function MK.CardLine(label, value, y, money)
  local Cd = MK.CARD
  local cx, cr = Cd.x + Cd.PAD, Cd.x + Cd.w - Cd.PAD
  local value_w = money and (MK.Width(Thousands(value), "item", 0.74) + CURRENCY_GAP + 30) or (cr - cx) / 2
  Text(L.text, Fit(label, math.max((cr - cx) / 3, cr - cx - value_w - 16), 20), cx, y, "label_l", 1.0)
  if money then
    if value < 0 then   -- not enough money: the amount on a red plate inside the card
      local w = MK.Width(Thousands(value), "item_on", 0.74) + CURRENCY_GAP + 30 + 16
      Quad(L.plate, ART.fill, cr + 8 - w, y - 15, w, 30, 1, nil, TINT.loss)
      MK.MoneyRight(value, cr, y, "item_on", 0.74)
    else
      MK.MoneyRight(value, cr, y, "item", 0.74)
    end
  else
    local t = Fit(value, (cr - cx) / 2, 23)
    Text(L.text, t, cr - MK.Width(t, "item", 0.74), y, "item", 0.74)
  end
end

-- the card of the focused side's player (vertical): face, name, club and position, media, then the
-- side's lines (the club's player: value, his loan; «Buscar»: value, the club's price, the money after it; «En venta»:
-- the offer), the last match scores, the A / Y buttons (X: «Negociar» over them, transfer offers only)
-- the card's position icon over its element icon (VRFW_CharaIcons: the team screen's and the bank's sprites), ICON px
-- each, centred on x, stacked around cy
function MK.CardIcons(card, x, cy)
  if VRFW_CharaIcons == nil then return end
  local s, gap = MK.CARD.ICON, MK.CARD.ICON_GAP
  for k, icon in ipairs({ VRFW_CharaIcons.Position(card) or false, VRFW_CharaIcons.Element(card) or false }) do
    if icon then
      Quad(L.icon, { tex = icon.tex, sprite_id = icon.sprite }, x - s / 2, cy - s - gap / 2 + (k - 1) * (s + gap), s, s)
    end
  end
end

function MK.DrawCard()
  local k, Cd = S.mk, MK.CARD
  MK.Panel(Cd.x, Cd.y, Cd.w, Cd.h)
  local side = k.focus == "squad" and "squad" or (k.sec == 2 and "sale" or "buy")
  local r, o
  if side == "squad" then
    r = MK.SquadRow()
  elseif side == "sale" then
    local s = MK.SaleRow()
    if s then r, o = s.r, s.o end
  elseif k.data and k.data.rows then
    r = k.data.rows[k.sel - (k.data.first or 1) + 1]
  end
  local d = side == "buy" and k.data or k.sq
  if r == nil or d == nil then return end
  local cx, cr, mx = Cd.x + Cd.PAD, Cd.x + Cd.w - Cd.PAD, Cd.x + Cd.w / 2
  local team = (r.club or 0) ~= 0 and r.club or nil
  Face(r.card, mx, Cd.y + Cd.FACE_Y, Cd.FACE, team, true)
  MK.CardIcons(r.card, mx + Cd.ICON_DX, Cd.y + Cd.FACE_Y)
  Text(L.text, Fit(r.name ~= "" and r.name or "-", cr - cx, 30), mx, Cd.y + Cd.NAME_Y, "big", 0.95, "c")
  -- the club, centred (the position is the icon by the portrait)
  local y = Cd.y + Cd.CLUB_Y
  local club = Fit(team and TeamName(team) or Tx(r.national and "MarketOther" or "MarketFree"), cr - cx - 40, 20)
  local cw = MK.Width(club, "label", 1.0) + (team and 32 or 0)
  if team then Crest(team, mx - cw / 2 + 12, y, 0.4) end
  Text(L.text, club, mx - cw / 2 + (team and 32 or 0), y, "label_l", 1.0)
  -- media (and the form arrow at its top right), centred
  y = Cd.y + Cd.LEVEL_Y
  Text(L.text, r.level and tostring(r.level) or "-", mx, y, "big", 1.5, "c")
  if r.level and r.form ~= nil then LEVEL.Arrow(r.form, mx + 48, y - 18, 20) end
  Text(L.text, Tx("MarketLevel"), mx, Cd.y + Cd.LEVEL_LABEL_Y, "label", 0.9, "c")
  Quad(L.plate, ART.fill, cx, Cd.y + Cd.LINE_Y, cr - cx, 2, 1, nil, TINT.rest)
  -- the side's lines
  y = Cd.y + Cd.LINES_Y
  local step = Cd.LINE_STEP
  if side == "sale" then
    MK.CardLine(Tx("MkOfferFrom"), TeamName(o.bidder), y)
    y = y + step
    if o.kind == "loan" then
      MK.CardLine(Tx("MkLoanUntil"), o.back and DateShort(o.back) or "-", y)
      y = y + step
      MK.CardLine(Tx("MkLoanFee"), o.amount or 0, y, true)
    else
      MK.CardLine(Tx("MkColAmount"), o.amount or 0, y, true)
      if o.ask then
        y = y + step
        MK.CardLine(Tx("MkYourAsk"), o.ask, y, true)
      end
    end
    y = y + step
    MK.CardLine(Tx("MarketValue"), r.value or 0, y, true)
    local state = MK.OfferState(o)
    if state then
      y = y + step
      Text(L.text, Fit(state, cr - cx, 20), cx, y, "item", 0.7)
    end
  elseif side == "buy" then
    MK.CardLine(Tx("MarketValue"), r.value or 0, y, true)
    y = y + step
    MK.CardLine(Tx((r.club or 0) ~= 0 and "MarketAsk" or "MarketFee"), r.price or 0, y, true)
    y = y + step
    MK.CardLine(Tx("MarketAfter"), d.money - (r.price or 0), y, true)
  else
    MK.CardLine(Tx("MarketValue"), r.value or 0, y, true)
    if r.status == "loaned" then
      y = y + step
      Text(L.text, Fit(Tx("MkLoanedTo", TeamName(r.borrower), DateShort(r.back)), cr - cx, 20), cx, y, "label_l", 1.0)
    end
  end
  -- the last match scores
  y = y + step + 6
  local Fm = MK.FORM
  Text(L.text, Tx("MarketFormLast"), cx, y, "label_l", 1.0)
  local scores = r.scores or {}
  if #scores == 0 then
    local none = Tx("MarketNoMatches")
    Text(L.text, none, cr - MK.Width(none, "label", 0.9), y, "label_l", 0.9)
  end
  local from = math.max(1, #scores - 4)
  for i = from, #scores do
    local v = scores[i]
    local sx = cr - Fm.W - (#scores - i) * Fm.STEP
    Quad(L.plate, ART.fill, sx, y - 12, Fm.W, 24, 1, nil,
      v >= MK.SCORE_GOOD and TINT.win or (v <= -MK.SCORE_GOOD and TINT.loss or TINT.draw))
    Text(L.text, string.format("%+.1f", v), sx + Fm.W / 2, y, "body_w", 0.46, "c")
  end
  -- a full squad (it signs nobody until it sells; the men out on loan count): white on the loss red
  local size = (d.squad or 0) + (d.loaned or 0)
  if side == "buy" and (d.max_squad or 0) > 0 and size >= d.max_squad then
    y = y + step + 6
    local line = Tx("MarketSquadLine", size, d.max_squad)
    Quad(L.plate, ART.fill, cx - 8, y - 15, MK.Width(line, "item_on", 0.72) + 16, 30, 1, nil, TINT.loss)
    Text(L.text, line, cx, y, "item_on", 0.72)
  end
  -- the buttons (a click = its key: A, Y, X)
  local buttons
  if side == "sale" then
    buttons = { Tx("MkKeyAccept"), Tx("KeyRefuseOffer") }
  else
    buttons = { Tx(side == "squad" and "MkKeyOptions" or "KeyOffer"), Tx("KeyViewPlayer") }
    if side == "squad" and r.status == "loaned" then buttons[1] = nil end
  end
  local keys = { "career_accept", "career_redraw" }
  local bw = (cr - cx - 10) / 2
  local by = Cd.y + Cd.h - Cd.PAD - Cd.BUTTON_H
  for i = 1, 2 do
    local t = buttons[i]
    if t then
      local bx = cx + (i - 1) * (bw + 10)
      Quad(L.plate, ART.play, bx, by, bw, Cd.BUTTON_H)
      S.zones[#S.zones + 1] = { x0 = bx, y0 = by, x1 = bx + bw, y1 = by + Cd.BUTTON_H, kind = "fn", name = keys[i] }
      Text(L.text, Fit(t, bw - 16, 20), bx + bw / 2, by + Cd.BUTTON_H / 2, "body_w", 0.74, "c")
    end
  end
  if side == "sale" and MK.CanNegotiate(o) then
    local yy = by - 10 - Cd.COUNTER_H
    MK.Plate(cx, yy, cr - cx, Cd.COUNTER_H, TINT.chip)
    S.zones[#S.zones + 1] = { x0 = cx, y0 = yy, x1 = cr, y1 = yy + Cd.COUNTER_H, kind = "fn", name = "career_x" }
    Text(L.text, Fit(Tx("MkKeyNegotiate"), cr - cx - 20, 20), mx, yy + Cd.COUNTER_H / 2, "body_c", 0.72, "c")
  end
end

-- the bar: the window's line, the sections «Buscar» | «En venta (n)» (the chosen one underlined; a click picks it),
-- the club's money
function MK.DrawBar()
  local k, B = S.mk, MK.BAR
  local y0 = MK.BAR_Y
  Quad(L.panel, ART.navy, 60, y0, 1800, MK.BAR_H)
  local mid = y0 + MK.BAR_H / 2
  local info = k.sq or k.data
  if info == nil then return end
  local w = info.window or {}
  local status = info.open and Tx("MkClosesOn", DateShort(w.to)) or Tx("MarketClosedOpens", DateShort(w.from))
  Text(L.text, Fit(status, B.SEC_X - 120, 20), 84, mid, "item_on", B.TEXT)
  local x = B.SEC_X
  for i, key in ipairs(MK.SECTIONS) do
    local label = i == 2 and Tx(key, k.sq and #MK.SaleRows() or (info.offers or 0)) or Tx(key)
    local tw = MK.Width(label, "item_on", B.SEC)
    local on = k.sec == i
    Text(L.text, label, x + tw / 2, mid - 2, on and "title_c" or "body_w", on and B.SEC or B.SEC * 0.9 * 32 / 28, "c")
    if on then Quad(L.plate, ART.fill, x, y0 + MK.BAR_H - 7, tw, 4, 1, nil, TINT.cut) end
    S.zones[#S.zones + 1] = { x0 = x - 14, y0 = y0, x1 = x + tw + 14, y1 = y0 + MK.BAR_H, kind = "msec", index = i }
    x = x + tw + B.SEC_GAP
  end
  Text(L.text, Tx("MarketBudget"), 1500, mid, "body_w", 0.7, "c")
  MK.MoneyRight(info.money, 1836, mid, "title", 0.86)
end

local function DrawMarket(h)
  MK.DrawBar()
  local pv = S.mk.pv
  if pv then
    -- «Ver jugador»: the search list slides left over «Plantilla» (a view of a «Plantilla» player keeps it), the
    -- view comes in from the right
    local e = MK.ViewEase()
    if pv.src == "list" then
      local T_ = MK.TR
      local x = T_.x
      T_.x = x - (x - MK.SQ.x) * e
      MK.DrawList()
      T_.x = x
    else
      MK.DrawSquad()
    end
    MK.DrawView((1 - e) * (1920 - MK.VIEW.x))
    return
  end
  MK.DrawSquad()
  if S.mk.sec == 2 then MK.DrawSale() else MK.DrawList() end
  if S.talk and not S.dialog then MK.Panel(MK.CARD.x, MK.CARD.y, MK.CARD.w, MK.CARD.h) else MK.DrawCard() end
end

-- ---- «Ajustes»: the career's file and «Guardar progreso» --------------------------------------------------------------

-- (S.hub fields saved_at, game_slot, career_slot; CMND_CAREERMODE_SAVE writes the career now): the last save, autosave
-- and the file as three tiles on top; the career's card (crest, club, season, competition, matches played, the save
-- button, the file line) and its summary (place, points, squad, budget) below
SETTINGS.BOX = {
  -- the top tiles: the title band and one line centred under it (owner 2026-10-31: compact)
  TOP = { y = 220, h = 108, GAP = 20, LINE_SIZE = 28, CHECK = 30, CHECK_GAP = 12 },
  CARD = { x = 60, y = 348, w = 1170, h = 652, CREST_X = 150, CREST_Y = 200, CREST = 2.0, TEXT_X = 290,
    BUTTON_Y = 380, BUTTON_W = 560, BUTTON_H = 72, NOTE_Y = 500, NOTE_STEP = 40 },
  SUMMARY = { x = 1260, y = 348, w = 600, h = 652, PAD = 24, GAP = 16, TOP = 70 },
}

-- a save time «YYYY-MM-DD hh:mm:ss.mmm» to the minute; its time «hh:mm» and its date «YYYY-MM-DD»
function SETTINGS.Stamp(at)
  return (tostring(at or ""):sub(1, 16))
end
function SETTINGS.Clock(at) return (tostring(at or ""):sub(12, 16)) end
function SETTINGS.Day(at)
  local s = tostring(at or "")
  return Tx("SettingsDateYear", s:sub(9, 10), s:sub(6, 7), s:sub(1, 4))
end

-- a top tile: its title band and one line centred in the rest of the tile
function SETTINGS.Top(x, w, title, line)
  local T_ = SETTINGS.BOX.TOP
  Tile(x, T_.y, w, T_.h, title)
  Text(L.text, Fit(line, w - 40, T_.LINE_SIZE), x + w / 2, T_.y + TILE.BAND + (T_.h - TILE.BAND) / 2, "big",
    T_.LINE_SIZE / 32, "c")
end

-- the autosave tile's checkbox and «Activado» / «Desactivado», centred in the tile under its band: hub button 2
-- (A or a click toggles it; focused: a cyan frame around it)
function SETTINGS.AutoSaveBox(h, x, w)
  local T_ = SETTINGS.BOX.TOP
  local on = h.autosave ~= false
  local label = Tx(on and "AutoSaveOn" or "AutoSaveOff")
  local sc, bs = T_.LINE_SIZE / 32, T_.CHECK
  local total = bs + T_.CHECK_GAP + CAL.Width(label, "item", sc)
  local bx, cy = x + (w - total) / 2, T_.y + TILE.BAND + (T_.h - TILE.BAND) / 2
  G.CheckBox(L.plate, bx, cy, bs, on, TINT.select)
  Text(L.text, label, bx + bs + T_.CHECK_GAP, cy, "item", sc)
  local k = #S.buttons + 1
  S.buttons[k] = { x0 = bx - 12, y0 = cy - bs / 2 - 8, x1 = bx + total + 12, y1 = cy + bs / 2 + 8, action = "autosave" }
  if k == S.button then Frame(L.icon, bx - 12, cy - bs / 2 - 8, total + 24, bs + 16, 2, TINT.cut) end
end

function SETTINGS.Draw(h, tab)
  local Bx = SETTINGS.BOX
  local P = G.PAGE
  local at = type(h.saved_at) == "string" and h.saved_at ~= "" and h.saved_at or nil
  local w = (P.w - 2 * Bx.TOP.GAP) / 3
  SETTINGS.Top(P.x, w, Tx("LastSaved"),
    at and (SETTINGS.Clock(at) .. "  ·  " .. SETTINGS.Day(at)) or Tx("SettingsNotSaved"))
  SETTINGS.Top(P.x + w + Bx.TOP.GAP, w, Tx("AutoSave"), "")
  SETTINGS.Top(P.x + 2 * (w + Bx.TOP.GAP), w, Tx("SaveFile"),
    Tx("SaveSlotN", h.game_slot or 0) .. "  ·  " .. Tx("CareerN", h.career_slot or 1))
  -- the career's card
  local C_ = Bx.CARD
  Tile(C_.x, C_.y, C_.w, C_.h, Tx(tab.text or ""), tab.icon ~= "" and tab.icon or nil)
  Crest(h.team, C_.x + C_.CREST_X, C_.y + C_.CREST_Y, C_.CREST)
  local tx = C_.x + C_.TEXT_X
  Text(L.text, Tx("CareerN", h.career_slot or 1), tx, C_.y + 120, "item", 1.2)
  local t = h.table or {}
  Text(L.text, Fit(TeamName(h.team) .. "  ·  " .. Tx("SeasonN", h.season) .. "  ·  " .. TableTitle(t), C_.w - C_.TEXT_X - 40,
    28), tx, C_.y + 172, "body", 1)
  local played = 0
  for _, m in ipairs(h.calendar or {}) do
    if m.hg ~= nil and m.hg >= 0 then played = played + 1 end
  end
  Text(L.text, Tx("MatchesPlayedLabel"), tx, C_.y + 226, "label_l", 1.05)
  Text(L.text, tostring(played), tx, C_.y + 266, "big", 1.2)
  S.button = math.max(1, math.min(2, S.button or 1))
  Button(Tx("SaveProgress"), "save", C_.x + 40, C_.y + C_.BUTTON_Y, C_.BUTTON_W, C_.BUTTON_H)
  SETTINGS.AutoSaveBox(h, P.x + w + Bx.TOP.GAP, w)
  Text(L.text, Fit(Tx(h.autosave == false and "SettingsAutoSaveOff" or "SettingsAutoSave"), C_.w - 80, 26), C_.x + 40,
    C_.y + C_.NOTE_Y, "label_l", 1)
  Text(L.text, Fit(Tx("SettingsFile", h.game_slot or 0, h.career_slot or 1), C_.w - 80, 26), C_.x + 40,
    C_.y + C_.NOTE_Y + C_.NOTE_STEP, "label_l", 1)
  -- the summary: place and points in the table of «Inicio», the squad, the budget (the season without the market)
  local Sm = Bx.SUMMARY
  Tile(Sm.x, Sm.y, Sm.w, Sm.h, Tx("PanelSummary"))
  local place, points = nil, nil
  for k, r in ipairs(t.rows or {}) do
    if r.team == Me(h) then place, points = k, r.points or 0 end
  end
  local boxes = {
    { place and Tx("PlaceShort", place) or "-", Tx("SlotPlace") },
    { points and tostring(points) or "-", Tx("ColPoints") },
    { tostring(#(h.squad or {})), Tx("TabSquad") },
    { h.money and Thousands(h.money) or tostring(h.season or 1), h.money and Tx("Budget") or Tx("SeasonLabel") },
  }
  local bw = (Sm.w - 2 * Sm.PAD - Sm.GAP) / 2
  local bh = (Sm.h - Sm.TOP - Sm.PAD - Sm.GAP) / 2
  for k, it in ipairs(boxes) do
    local bx = Sm.x + Sm.PAD + ((k - 1) % 2) * (bw + Sm.GAP)
    local by = Sm.y + Sm.TOP + math.floor((k - 1) / 2) * (bh + Sm.GAP)
    Quad(L.plate, ART.fill, bx, by, bw, bh, 1, nil, TINT.stripe)
    Text(L.text, Fit(it[1], bw - 30, 32), bx + bw / 2, by + bh / 2 - 18, "big", 1.4, "c")
    Text(L.text, Fit(it[2], bw - 30, 22), bx + bw / 2, by + bh / 2 + 40, "label", 1, "c")
  end
end

local function DrawHub()
  local h = S.hub
  TabBar(nil, Tabs(), S.tab)
  local tab = Tabs()[S.tab] or {}
  -- the page PAGE_DY px up (under the slim bar); the pointer zones and buttons it adds are moved with it
  local zones, buttons = #S.zones, #S.buttons
  S.dy = G.PAGE_DY
  local keys = {}
  if tab.id == "home" then
    DrawHomePhase()
    if h.next and h.next.kind == "match" then keys[#keys + 1] = Tx("KeySim") end
    if S.news and #S.news.items > 1 then keys[#keys + 1] = Tx("KeyNews") end
  elseif tab.id == "calendar" then
    DrawCalendar(h)
    keys = { Tx("KeyCalDay"), Tx("KeyMonth") }
  elseif tab.id == "competition" then
    local t = DrawCompetition(h)
    if t.kind == "worldcup" then
      if WorldCupPages(t) > 1 then keys[#keys + 1] = Tx("KeyWorldCupPage") end
    elseif t.kind ~= "bracket" then
      keys[#keys + 1] = Tx("KeyStandFocus")
      keys[#keys + 1] = Tx("KeyStatsTab")
    end
  elseif tab.id == "market" then
    DrawMarket(h)
    MK.TalkDraw()
    MK.DrawFilters()
    if S.mk.pv then
      keys = { Tx("MkKeyViewPlayer"), Tx("MkKeyViewPage"), Tx("MkKeyViewBack") }
    elseif S.mk.fp and S.mk.fp.list then
      keys = { Tx("MkKeyClubRow"), Tx("MkKeyClubPick"), Tx("MkKeyClubBack") }
    elseif S.mk.fp then
      keys = { Tx("MkKeyFilterRow"), Tx("MkKeyFilterValue"), Tx("MkKeyFilterStep"), Tx("MkKeyFilterApply") }
    elseif S.talk then
      local sell = S.talk.mode == "sell"
      keys = { Tx(sell and "KeyTalkAsk" or "KeyTalkOffer"), Tx(sell and "KeyTalkTake" or "KeyTalkAccept"),
        Tx("KeyTalkSteps"), Tx("KeyTalkBig"), Tx("KeyTalkLeave") }
    elseif S.mk.focus == "search" then
      keys = { Tx("KeySearchKeyboard"), Tx("MkKeyFilters"), Tx("KeySearchClear"), Tx("KeySearchResults") }
    elseif S.mk.focus == "squad" and S.mk.menu then
      keys = { Tx("KeySearchPick"), Tx("MkKeyClose") }
    elseif S.mk.focus == "squad" then
      keys = { Tx("MkKeyOptions"), Tx("KeyViewPlayer"), Tx("MkKeyFilterX"), Tx("MkKeyToMarket"), Tx("MkKeySections") }
    elseif S.mk.sec == 2 then
      local sale = MK.SaleRow()
      keys = { Tx("MkKeyAccept"), Tx("KeyRefuseOffer") }
      if sale and MK.CanNegotiate(sale.o) then keys[#keys + 1] = Tx("MkKeyNegotiate") end
      keys[#keys + 1] = Tx("MkKeyToSquad")
      keys[#keys + 1] = Tx("MkKeySections")
    else
      keys = { Tx("KeyOffer"), Tx("KeyViewPlayer"), Tx("MkKeyFilters"), Tx("MkKeyToSquad"), Tx("MkKeySections") }
    end
  elseif tab.id == "squad" then
    DrawSquad(h)
    keys[1] = Tx("KeyTeamDock")
  elseif tab.id == "settings" then
    SETTINGS.Draw(h, tab)
    keys[1] = Tx("KeySave")
  else
    local P = G.PAGE
    Tile(P.x, P.y, P.w, P.h, Tx(tab.text or ""))
    Text(L.text, Tx("ComingSoon"), P.x + P.w / 2, P.y + P.h / 2, "body_c", 1.1, "c")
  end
  S.dy = 0
  for k = zones + 1, #S.zones do
    local zn = S.zones[k]
    zn.y0, zn.y1 = zn.y0 + G.PAGE_DY, zn.y1 + G.PAGE_DY
    if zn.top then zn.top = zn.top + G.PAGE_DY end
  end
  for k = buttons + 1, #S.buttons do
    local b = S.buttons[k]
    b.y0, b.y1 = b.y0 + G.PAGE_DY, b.y1 + G.PAGE_DY
  end
  Footer(keys)
end

-- ---- the draw of the leagues -------------------------------------------------------------------------------------------

-- the draw screen's layout (px at 1080p, y down): the pots in rows of PER_ROW boxes (a title band, the clubs' crests
-- in CREST_ROWS rows inside the box), the drawn ball's card under them, the leagues' columns at the bottom (a title
-- band, two slots a row: crest + the club's name, «?» while not drawn). FLASH: the frames the drawn ball's card stays,
-- faded in and out in FADE_STEPS steps of STEP_FRAMES frames each
G.POTS = {
  TITLE_Y = 150, X = 60, W = 1800,
  BOX = { TOP = 184, H = 134, PER_ROW = 7, GAP = 12, ROW_GAP = 10, TITLE_H = 34, PAD = 10, CREST_ROWS = 2,
    CREST_MAX = 0.62, CREST_FILL = 0.85, GONE_ALPHA = 0.25, STRIP_H = 5 },
  CARD = { Y = 474, W = 700, H = 84, CREST = 0.95, NAME_SC = 1.35, CHIP_W = 210, CHIP_H = 50 },
  LEAGUE = { TOP = 570, H = 432, GAP = 20, BAND_H = 46, BAND_PAD = 8, FIRST = 80, STEP = 50, SLOT_H = 44, PAD = 8,
    SLOT_GAP = 8, CREST = 0.44, CREST_PAD = 4, NAME_GAP = 6, NAME_SC = 0.78, FRAME = 2, PER_ROW = 2 },
  CREST_PX = 68, FLASH = 45, FADE_STEPS = 4, STEP_FRAMES = 3,
}

-- ball k (1-based) = pot ceil(k / leagues), league (k - 1) % leagues + 1
local function PotsTotal(p)
  return #p.pots * #p.leagues
end

-- the drawn ball's card alpha at `flash` frames left: faded in, then out, in FADE_STEPS steps
function G.POTS.CardAlpha(flash)
  local P = G.POTS
  if flash <= 0 then return 0 end
  local shown = math.min(1, (math.floor((P.FLASH - flash) / P.STEP_FRAMES) + 1) / P.FADE_STEPS)
  local left = math.min(1, math.ceil(flash / P.STEP_FRAMES) / P.FADE_STEPS)
  return math.min(shown, left)
end

-- the longest form of a club's name that fits px at font size `size`, never cut: the whole name, the name without
-- its first word, its first word, then its longest word that fits; "" when none fits (the crest alone)
function G.POTS.ShortName(name, px, size)
  local units = math.floor(px / (size * GLYPH))
  local function fits(s) return s ~= "" and Units(s) <= units end
  if fits(name) then return name end
  local words = {}
  for w in tostring(name):gmatch("%S+") do words[#words + 1] = w end
  if #words > 1 then
    local rest = table.concat(words, " ", 2)
    if fits(rest) then return rest end
    if fits(words[1]) then return words[1] end
  end
  local best = ""
  for _, w in ipairs(words) do
    if fits(w) and Units(w) > Units(best) then best = w end
  end
  return best
end

-- the box of league l's column
function G.POTS.LeagueBox(l, leagues)
  local P, LG = G.POTS, G.POTS.LEAGUE
  local w = (P.W - (leagues - 1) * LG.GAP) / leagues
  return P.X + (l - 1) * (w + LG.GAP), LG.TOP, w, LG.H
end

-- the slot of pot k's club in a league column (x, y, w of the column) -> its box x, y, w, h
function G.POTS.LeagueSlot(x, y, w, k)
  local LG = G.POTS.LEAGUE
  local sw = (w - 2 * LG.PAD - (LG.PER_ROW - 1) * LG.SLOT_GAP) / LG.PER_ROW
  local col, row = (k - 1) % LG.PER_ROW, math.floor((k - 1) / LG.PER_ROW)
  local cy = y + LG.FIRST + row * LG.STEP
  return x + LG.PAD + col * (sw + LG.SLOT_GAP), cy - LG.SLOT_H / 2, sw, LG.SLOT_H
end

-- a drawn club in its league slot: the crest, its name as far as it fits; the career club framed
function G.POTS.DrawSlot(t, sx, sy, sw, sh, mine)
  local LG = G.POTS.LEAGUE
  local cy = sy + sh / 2
  if mine then Frame(L.plate, sx + LG.FRAME, sy + LG.FRAME, sw - 2 * LG.FRAME, sh - 2 * LG.FRAME, LG.FRAME, TINT.navy) end
  local crest = G.POTS.CREST_PX * LG.CREST
  local name_x = sx + LG.CREST_PAD + crest + LG.NAME_GAP
  local size = (tonumber(STYLE.label_l:match("^fs_(%d+)")) or 22) * LG.NAME_SC
  local name = G.POTS.ShortName(TeamName(t), sx + sw - LG.CREST_PAD - name_x, size)
  if name == "" then
    Crest(t, sx + sw / 2, cy, LG.CREST)
  else
    Crest(t, sx + LG.CREST_PAD + crest / 2, cy, LG.CREST)
    Text(L.text, name, name_x, cy, "label_l", LG.NAME_SC)
  end
end

-- the pots: rows of boxes, each its colour strip, its title and its clubs' crests (drawn ones dimmed) in a grid inside the box
function G.POTS.DrawBoxes(p, gone)
  local P, B = G.POTS, G.POTS.BOX
  local rows = math.max(1, math.ceil(#p.pots / B.PER_ROW))
  local per_row = math.ceil(#p.pots / rows)
  local pw = (P.W - (per_row - 1) * B.GAP) / per_row
  for k, pot in ipairs(p.pots) do
    local col, row = (k - 1) % per_row, math.floor((k - 1) / per_row)
    local x, y = P.X + col * (pw + B.GAP), B.TOP + row * (B.H + B.ROW_GAP)
    Quad(L.panel, ART.white, x, y, pw, B.H)
    -- the pot's colour strip on its top edge (the SuperLiga table's place strips use the same colours)
    if p.tints[k] then Quad(L.plate, ART.fill, x, y, pw, B.STRIP_H, 1, nil, TINT[p.tints[k]]) end
    Text(L.text, Tx("Pot", k), x + B.PAD + 6, y + B.TITLE_H / 2 + 2, "label_l", 1.05)
    local cols = math.max(1, math.ceil(#pot / B.CREST_ROWS))
    local cell_w = (pw - 2 * B.PAD) / cols
    local cell_h = (B.H - B.TITLE_H - B.PAD) / B.CREST_ROWS
    local s = math.min(B.CREST_MAX, B.CREST_FILL * math.min(cell_w, cell_h) / P.CREST_PX)
    for i, t in ipairs(pot) do
      local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
      Crest(t, x + B.PAD + (c + 0.5) * cell_w, y + B.TITLE_H + (r + 0.5) * cell_h, s, gone[t] and B.GONE_ALPHA or 1)
    end
  end
end

-- the drawn ball's card between the pots and the leagues: crest, club name, its league in a navy chip
function G.POTS.DrawCard(t, l, alpha)
  local CARD = G.POTS.CARD
  local x, y = 960 - CARD.W / 2, CARD.Y
  local cy = y + CARD.H / 2
  Quad(L.panel, ART.white, x, y, CARD.W, CARD.H, alpha)
  local crest = G.POTS.CREST_PX * CARD.CREST
  Crest(t, x + 20 + crest / 2, cy, CARD.CREST, alpha)
  local name_x = x + 20 + crest + 16
  local chip_x = x + CARD.W - 20 - CARD.CHIP_W
  local size = (tonumber(STYLE.label_l:match("^fs_(%d+)")) or 22) * CARD.NAME_SC
  local name = G.POTS.ShortName(TeamName(t), chip_x - 16 - name_x, size)
  Text(L.text, name ~= "" and name or Fit(TeamName(t), chip_x - 16 - name_x, size), name_x, cy, "label_l", CARD.NAME_SC)
  Quad(L.plate, ART.fill, chip_x, cy - CARD.CHIP_H / 2, CARD.CHIP_W, CARD.CHIP_H, alpha, nil, TINT.navy)
  Text(L.text, LeagueName(l), chip_x + CARD.CHIP_W / 2, cy, "title_c", 0.8, "c")
end

local function DrawPots()
  local p = S.pots
  local P = G.POTS
  local nl = #p.leagues
  local drawn = p.drawn
  Text(L.text, Tx("DrawTitle"), 960, P.TITLE_Y, "outline_c", 1.3, "c")
  local gone = {}
  for b = 1, math.min(drawn, PotsTotal(p)) do
    local t = p.leagues[(b - 1) % nl + 1][math.ceil(b / nl)]
    if t then gone[t] = true end
  end
  -- the ball just drawn (drawn before the pots: a quad drawn later lies under)
  if drawn > 0 and drawn <= PotsTotal(p) and p.flash > 0 then
    local bp, bl = math.ceil(drawn / nl), (drawn - 1) % nl + 1
    local t = p.leagues[bl][bp]
    if t then P.DrawCard(t, bl, P.CardAlpha(p.flash)) end
  end
  P.DrawBoxes(p, gone)
  -- the leagues: one column each, its clubs in pot order
  local LG = P.LEAGUE
  for l = 1, nl do
    local x, y, w, h = P.LeagueBox(l, nl)
    Quad(L.panel, ART.white, x, y, w, h)
    Quad(L.plate, ART.band, x + LG.BAND_PAD, y + LG.BAND_PAD, w - 2 * LG.BAND_PAD, LG.BAND_H)
    Text(L.text, LeagueName(l), x + w / 2, y + LG.BAND_PAD + LG.BAND_H / 2, "title_c", 0.85, "c")
    for k = 1, #p.pots do
      local sx, sy, sw, sh = P.LeagueSlot(x, y, w, k)
      local t = p.leagues[l][k]
      if (k - 1) * nl + l <= drawn and t then
        P.DrawSlot(t, sx, sy, sw, sh, t == p.team)
      else
        Text(L.text, "?", sx + sw / 2, sy + sh / 2, "dim", 0.9, "c")
      end
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
    S.zones[#S.zones + 1] = { x0 = x, y0 = y - WC.ROW_H / 2, x1 = x + WC.COL_W, y1 = y + WC.ROW_H / 2, kind = "wcrow",
      index = idx, hover = true }
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

-- ---- setup: the new career's options, after the club pick (CMND_CAREERMODE_SETUP) -----------------------------------

-- the rows top to bottom; "start" = the button that starts the career. Rows marked `market` mean nothing without the
-- transfer market: greyed and skipped by the cursor when it is off
local SETUP = {}
SETUP.ROWS = {
  { id = "market", label = "OptMarket" }, { id = "backing", label = "OptBacking", market = true },
  { id = "negotiation", label = "OptNegotiation", market = true }, { id = "activity", label = "OptActivity", market = true },
  { id = "sacking", label = "OptSacking" }, { id = "start" },
}
SETUP.BOX = { x = 60, y = 110, w = 1140, h = 890, ROW_Y = 178, ROW_STEP = 138, ROW_H = 84, VALUE_X = 940,
  VALUE_W = 300, START_Y = 878, START_W = 520, START_H = 72, SIDE = { x = 1230, y = 110, w = 630, h = 890 },
  DESC_Y = 16, DESC_STEP = 26, DESC_SIZE = 28, DESC_SC = 0.8, ARROW_W = 28, ARROW_H = 32 }
-- the retail list plate (save01_02 list_base_s01_off / _on, 312 x 84) cut in three at build
-- (content/images/menu/220_img/career_rows.toml): its two slanted ends drawn at their own size and the plain middle
-- stretched between them, so a long row keeps the plate's sharp ends and an even fill. TOP_L / TOP_R: the body's top
-- edge in the plate (row TOP), BOTTOM: its last row; LEFT_W / RIGHT_X: where the ends are cut
SETUP.PLATE = { W = 312, H = 84, TOP = 8, BOTTOM = 75, TOP_L = 19, TOP_R = 303, LEFT_W = 100, RIGHT_X = 200,
  TEX = "#/menu/220_img/career_rows/career_rows.g4tx" }

-- a row plate (look "off" or "on") whose body's top edge runs from x to x + w at row y
function SETUP.Plate(look, x, y, w)
  local Pl = SETUP.PLATE
  local left = x - Pl.TOP_L                -- the plate's origin for its left end
  local right = x + w - Pl.TOP_R           -- and for its right end
  local top = y - Pl.TOP
  local function art(part) return { tex = Pl.TEX, sprite = "career_row_" .. look .. "_" .. part } end
  Quad(L.plate, art("left"), left, top, Pl.LEFT_W, Pl.H)
  Quad(L.plate, art("middle"), left + Pl.LEFT_W, top, right + Pl.RIGHT_X - left - Pl.LEFT_W, Pl.H)
  Quad(L.plate, art("right"), right + Pl.RIGHT_X, top, Pl.W - Pl.RIGHT_X, Pl.H)
end

function SETUP.RowOn(k)
  local r = SETUP.ROWS[k]
  return r ~= nil and not (r.market and not S.setup.market)
end

function SETUP.Percent(x) return tostring(math.floor((tonumber(x) or 1) * 100 + 0.5)) end

-- a row's value and its description line
function SETUP.Value(id)
  local st, v = S.setup, S.setup.v
  if id == "market" then return Tx(st.market and "Yes" or "No"), Tx(st.market and "DescMarketOn" or "DescMarketOff") end
  if id == "sacking" then return Tx(st.sacking and "Yes" or "No"), Tx(st.sacking and "DescSackingOn" or "DescSackingOff") end
  if id == "negotiation" then
    local p = v.negotiation.presets[st.neg] or {}
    return Tx(p.text or ""), Tx("DescNegotiation", SETUP.Percent(p.ask), SETUP.Percent(p.bid))
  end
  if id == "activity" then
    local p = v.activity.presets[st.act] or {}
    return Tx(p.text or ""), (p.deals or 0) > 0 and Tx("DescActivity", p.deals) or Tx("DescActivityOff")
  end
  return nil, Tx("DescBacking")
end

function SETUP.Backing()
  local steps = S.setup.v.backing.steps or { 0 }
  return steps[S.setup.backing] or 0, #steps
end

function SETUP.Draw()
  local st, v, B = S.setup, S.setup.v, SETUP.BOX
  Tile(B.x, B.y, B.w, B.h, Tx("SetupTitle"), nil, Tx("SetupStep"))
  for k, r in ipairs(SETUP.ROWS) do
    local on = k == st.row
    if r.id == "start" then
      local bx = B.x + (B.w - B.START_W) / 2
      Quad(L.plate, on and ART.play or ART.button, bx, B.START_Y, B.START_W, B.START_H)
      if on then Cursor(bx + 4, B.START_Y + B.START_H / 2, 44) end
      S.zones[#S.zones + 1] = { x0 = bx, y0 = B.START_Y, x1 = bx + B.START_W, y1 = B.START_Y + B.START_H, kind = "srow",
        index = k, hover = true }
      Text(L.text, Tx("SetupStart"), bx + B.START_W / 2, B.START_Y + B.START_H / 2, "body_w", 1.1, "c")
    else
      local y = B.ROW_Y + (k - 1) * B.ROW_STEP
      local Pl = SETUP.PLATE
      local mid = y + (Pl.BOTTOM - Pl.TOP) / 2
      local live = SETUP.RowOn(k)
      SETUP.Plate(on and "on" or "off", B.x + 30, y, B.w - 60)
      if on then Cursor(B.x + 34, mid, 48) end
      if live then
        S.zones[#S.zones + 1] = { x0 = B.x + 20, y0 = y, x1 = B.x + B.w - 30, y1 = y + Pl.BOTTOM - Pl.TOP, kind = "srow",
          index = k, hover = true }
      end
      Text(L.text, Tx(r.label), B.x + 70, mid, live and (on and "item_on" or "item") or "dim", 0.95)
      local desc
      if not live then
        Text(L.text, "-", B.VALUE_X, mid, "dim", 1, "c")
        desc = Tx("DescNoMarket")
      else
        local value
        value, desc = SETUP.Value(r.id)
        local style = on and "body_w" or "big"
        if r.id == "backing" then
          MoneyAt((SETUP.Backing()), B.VALUE_X, mid, style, 0.95, "c")
        else
          Text(L.text, Fit(value, B.VALUE_W - 80, 32), B.VALUE_X, mid, style, 1, "c")
        end
        local ax0, ax1 = B.VALUE_X - B.VALUE_W / 2, B.VALUE_X + B.VALUE_W / 2 - B.ARROW_W
        Quad(L.icon, ART.arrow, ax0, mid - B.ARROW_H / 2, B.ARROW_W, B.ARROW_H, 1, true)
        Quad(L.icon, ART.arrow, ax1, mid - B.ARROW_H / 2, B.ARROW_W, B.ARROW_H)
        S.zones[#S.zones + 1] = { x0 = ax0 - 20, y0 = y, x1 = ax0 + B.ARROW_W + 20, y1 = y + Pl.BOTTOM - Pl.TOP,
          kind = "srow", index = k, dx = -1 }
        S.zones[#S.zones + 1] = { x0 = ax1 - 20, y0 = y, x1 = ax1 + B.ARROW_W + 20, y1 = y + Pl.BOTTOM - Pl.TOP,
          kind = "srow", index = k, dx = 1 }
      end
      -- the description under the plate at the font's own width, two lines at most
      local dy = y + Pl.BOTTOM - Pl.TOP + B.DESC_Y
      for i, line in ipairs(Wrap(desc, B.w - 100, B.DESC_SIZE * B.DESC_SC, 2)) do
        Text(L.text, line, B.x + 50, dy + (i - 1) * B.DESC_STEP, "body", B.DESC_SC)
      end
    end
  end
  -- the club and the starting budget
  local P = B.SIDE
  Tile(P.x, P.y, P.w, P.h, Tx("YourClub"))
  local cx = P.x + P.w / 2
  Crest(st.team, cx, P.y + 190, 2.0)
  Text(L.text, Fit(TeamName(st.team), P.w - 60, 32), cx, P.y + 320, "big", 1.15, "c")
  if (v.rank or 0) > 0 then Text(L.text, Tx("SetupRank", v.rank, v.clubs or 0), cx, P.y + 366, "body_c", 0.9, "c") end
  local y = P.y + 410
  Quad(L.plate, ART.fill, P.x + 30, y, P.w - 60, TILE.BAND, 1, nil, TINT.navy)
  if st.market then
    Text(L.text, Tx("SetupBudget"), P.x + 54, y + TILE.BAND / 2, "title", 0.85)
    local amount = SETUP.Backing()
    local lines = { { Tx("SetupClubBudget"), v.budget or 0 }, { Tx("OptBacking"), amount },
      { Tx("SetupTotal"), (v.budget or 0) + amount } }
    for k, l in ipairs(lines) do
      local ly = y + TILE.BAND + 40 + (k - 1) * 54
      Text(L.text, l[1], P.x + 54, ly, k == #lines and "item" or "body", 0.95)
      MoneyAt(l[2], P.x + P.w - 190, ly, k == #lines and "big" or "body_c", k == #lines and 1.05 or 0.9, "c")
    end
  else
    Text(L.text, Tx("OptMarket"), P.x + 54, y + TILE.BAND / 2, "title", 0.85)
    local lines = Wrap(Tx("SetupNoMarket"), P.w - 100, 28, 3)
    for k, l in ipairs(lines) do Text(L.text, l, P.x + 54, y + TILE.BAND + 40 + (k - 1) * 44, "body", 0.95) end
  end
  -- the board's objectives for the first season (sacking off: asked all the same, never a sacking)
  if v.objectives then
    local oy = P.y + 650
    Quad(L.plate, ART.fill, P.x + 30, oy, P.w - 60, TILE.BAND, 1, nil, TINT.navy)
    Text(L.text, Tx("BoardTitle"), P.x + 54, oy + TILE.BAND / 2, "title", 0.85)
    HOME.Objectives(v.objectives, P.x + 54, oy + TILE.BAND + 36, 50, P.w - 140, 22, "body", 0.95)
  end
  local keys = { Tx("KeySetupStart"), Tx("KeyBack"), Tx("KeySetupChange") }
  if st.market and SETUP.ROWS[st.row].id == "backing" then keys[#keys + 1] = "LB / RB: x" .. tostring(v.backing.jump or 1) end
  Footer(keys)
end

-- left / right on a row (d = -1 / 1, steps = how many): its value changed
function SETUP.Change(d, steps)
  local st, v = S.setup, S.setup.v
  local id = SETUP.ROWS[st.row].id
  if not SETUP.RowOn(st.row) or id == "start" then return false end
  if id == "market" then st.market = not st.market
  elseif id == "sacking" then st.sacking = not st.sacking
  elseif id == "backing" then
    local n = #(v.backing.steps or { 0 })
    local b = math.max(1, math.min(n, st.backing + d * (steps or 1)))
    if b == st.backing then return false end
    st.backing = b
  elseif id == "negotiation" then
    local n = #v.negotiation.presets
    if n == 0 then return false end
    st.neg = (st.neg - 1 + d) % n + 1
  elseif id == "activity" then
    local n = #v.activity.presets
    if n == 0 then return false end
    st.act = (st.act - 1 + d) % n + 1
  end
  return true
end

-- up / down: the next row the cursor may stand on
function SETUP.Move(dy)
  local k = S.setup.row
  repeat k = k + dy until k < 1 or k > #SETUP.ROWS or SETUP.RowOn(k)
  if k < 1 or k > #SETUP.ROWS then return false end
  S.setup.row = k
  return true
end

local function Draw()
  BeginFrame()
  S.pic_want = nil
  HOME.prompt, S.head_prompt, HOME.switch = nil, nil, nil
  S.tree_frame = false
  if S.ready then
    if S.mode == "home" then DrawHome()
    elseif S.mode == "pick" and S.draw then DrawPick()
    elseif S.mode == "setup" and S.setup then SETUP.Draw()
    elseif S.mode == "hub" and S.hub then DrawHub()
    elseif S.mode == "pots" and S.pots then DrawPots()
    elseif S.mode == "wcsquad" and S.wc then DrawWcSquad()
    elseif S.mode == "dock" and S.hub then TabBar(nil, Tabs(), S.tab) end
    Dialog()
    TabKeys(((S.mode == "hub" or S.mode == "dock") and S.hub ~= nil and #Tabs() > 1)
      or (S.mode == "pick" and S.draw ~= nil and #(S.draw.leagues or {}) > 1 and S.dialog == nil))
    HOME.PromptKeys(S.dialog == nil and (HOME.prompt or S.head_prompt) or nil)
    local sw = S.dialog == nil and HOME.switch or nil
    if sw then sw.left, sw.right = "<CMD_FUNC3>", "<CMD_FUNC3>" end
    HOME.Glyphs(HOME.SWITCH_SPEC, S.switch, HOME.L_SWITCH, "switch_at", sw)
  end
  EndFrame()
  -- fewer buttons than the focus: the first one takes it
  if #S.buttons > 0 and S.button > #S.buttons then
    S.button = 1
    S.dirty = true
  end
  if not S.tree_frame or S.dialog then TreeHide("the knockout left") end
  if S.pic then S.pic.Want(not (S.dialog or S.match or S.closing) and S.pic_want or nil) end
end

-- ---- data and flow -----------------------------------------------------------------------------------------------------

-- the team screen of «Equipo» kept between visits (VRFW_TeamEditor spec.keep, config.toml [squads]
-- keep_team_screen): L1 / R1 hide it and the hub's next tab shows in the same frame, the next visit shows it again at
-- once. Requests that only read (KINDS) go on while it is kept; any other one (a match, a day, a save, a market deal,
-- leaving the hub) first releases it (the dock closed, the save session ended), then is sent.
local KEPT = { KINDS = { hub = true, standings = true, market = true, dock = true, dockset = true, lookset = true,
  clubpool = true, clubpick = true } }

-- ask the scripts for data (a kind of REQUEST below) until they answer
local function Want(kind, arg)
  S.want = { kind = kind, arg = arg, tries = 0 }
  if S.kept and not KEPT.KINDS[kind] then KEPT.Release(kind) end
end

-- the kept team screen released (a coroutine resumed by Fetch, or by Step while the screen closes)
function KEPT.Release(why)
  S.kept = false
  if type(VRFW_TeamEditor) ~= "table" or type(VRFW_TeamEditor.Release) ~= "function" then return end
  S.release = coroutine.create(function() return VRFW_TeamEditor.Release("CareerMode: " .. tostring(why)) end)
  Log("team page: the kept team screen released for", tostring(why))
end

-- true while the release still runs
function KEPT.Step()
  local co = S.release
  if co == nil then return false end
  local ok, err = coroutine.resume(co)
  if not ok then Log("team page release error", tostring(err)) end
  if coroutine.status(co) ~= "dead" then return true end
  S.release = nil
  return false
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

-- the career squads written into the clubs' roster rows and each row at its player's career level
-- (CMND_VRFW_TEAM_MEMBER_LEVELS), a few clubs a Step (before their stats are read)
local function ApplySome()
  for _ = 1, APPLY_PER_STEP do
    local a = table.remove(S.apply, 1)
    if a == nil then return end
    if #a.rows > 0 then
      local ok, done, why = pcall(funcLuaCommand, Crc("CMND_VRFW_TEAM_ROSTER"), a.team, table.unpack(a.rows))
      if not ok or done ~= true then Log("squad of", a.team, "not written:", tostring(ok and why or done)) end
    end
    S.applied[a.team] = true
    if #a.levels > 0 then
      local ok, done, why = pcall(funcLuaCommand, Crc("CMND_VRFW_TEAM_MEMBER_LEVELS"), a.team, 0, table.unpack(a.levels))
      if not ok or done ~= true then Log("levels of", a.team, "not written:", tostring(ok and why or done)) end
    end
  end
end

-- the data's roster rows, their levels and the slot teams back (the player leaves the mode); the levels first, while
-- the rows still hold the career's cards
local function RestoreRosters()
  for team in pairs(S.applied or {}) do pcall(funcLuaCommand, Crc("CMND_VRFW_TEAM_MEMBER_LEVELS"), team, 0) end
  pcall(funcLuaCommand, Crc("CMND_VRFW_TEAM_ROSTER_RESTORE"), 0)
  pcall(funcLuaCommand, Crc("CMND_VRFW_TEAM_STAND_IN_RESTORE"), 0)
  S.applied = {}
end

local function HubEntered(v)
  S.hub, S.mode, S.page, S.table, S.month, S.news = v, "hub", 1, nil, nil, nil
  if S.tree then S.tree = false end   -- the bracket drawn again with the new data (any value but a view name)
  S.rules = v.rating or S.rules
  S.tab = math.max(1, math.min(S.tab, #(v.tabs or {})))
  S.tindex, S.tpage, S.tcur = v.table_index or 1, 1, nil
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

-- the screen goes: as its menu scene's root (the title row's root_menu) the scene ends with the reset to the title
local function CloseScreen()
  if S.root and type(VRFW_Reset) == "table" then
    Log("the scene root closes: reset to the title")
    pcall(funcLuaCommand, 609722083 --[[screen fade to black]], 1, 0)
    VRFW_Reset.to_title()
    return
  end
  pcall(funcLuaCommand, C.CLOSE_MENU, MENU)
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
  -- each player at his career level + form (the script's user_levels / rival_levels, in the cards' order)
  for _, side in ipairs({ { user, me, v.user_levels }, { rival, v.rival, v.rival_levels } }) do
    local team, levels = side[1], side[3]
    if team ~= side[2] and type(levels) == "table" and #levels > 0 then
      local okv, done, why = pcall(funcLuaCommand, Crc("CMND_VRFW_TEAM_MEMBER_LEVELS"), team, v.level_base or 0,
        table.unpack(levels))
      if not (okv and done == true) then Log("member levels of", team, "not set:", tostring(okv and why or done)) end
    end
  end
  if user ~= me and (v.user_formation or 0) ~= 0 then
    local okf, done, why = pcall(funcLuaCommand, Crc("CMND_VRFW_TEAM_STAND_IN_FORMATION"), user, v.user_formation)
    if not (okf and done == true) then Log("lineup formation not set:", tostring(okf and why or done)) end
  end
  local look = type(v.user_look) == "table" and v.user_look or nil
  if user ~= me and look and ((look.kit or 0) ~= 0 or (look.emblem or 0) ~= 0 or (look.coach or 0) ~= 0) then
    local okl, done, why = pcall(funcLuaCommand, Crc("CMND_VRFW_TEAM_STAND_IN_LOOK"), user, look.kit or 0,
      look.emblem or 0, look.coach or 0)
    if not (okl and done == true) then Log("club look not set:", tostring(okl and why or done)) end
  end
  S.match = true
  UNDER.Hide(false)
  local ok, started, why = pcall(VRFW_MATCH.start, { friendly = v.friendly, game = game, difficulty = v.difficulty,
    rival = v.host, overrides = { { "teams.rival.team", rival }, { "teams.user.team", user } }, settle = 0, black = false,
    on_failed = function(reason)
      S.match = false
      UNDER.Hide(true)
      Call("CMND_CAREERMODE_DISARM")
      Log("match start failed:", tostring(reason))
    end })
  Log("match", tostring(v.home), "-", tostring(v.away), "start", tostring(ok), tostring(started), tostring(why))
  if not (ok and started) then
    S.match = false
    UNDER.Hide(true)
    Snd(SND.BUZZER)
    Call("CMND_CAREERMODE_DISARM")
  end
end

-- each kind's career command and its arguments: `arg` = the Want argument, `lang` = the game's language last
-- «Continuar» / «Ir al partido» / a day of «Fechas»: the days walked one a step (CMND_CAREERMODE_DAY 1 each, hub
-- day_step_frames apart), the line's today mark sliding to each new day; the walk ends on a stop the script reports
-- (an offer for one of the club's players, the window opening or closing), on the match day, on a day with an event on
-- the line («Continuar», mode 1, and the calendar's, mode 3, up to its target day), on the target day, or when A / B /
-- Y is pressed; then the hub is asked again (the news, the market, the line)
HOME.WALK_STEP = 24      -- frames a day takes when the hub does not say
HOME.SLIDE = 0.66        -- the share of a day's frames the today mark slides in

local function WalkFrames()
  return math.max(1, tonumber(S.hub and S.hub.day_step_frames) or HOME.WALK_STEP)
end

function HOME.WalkStart(mode, target)
  S.walk = { mode = mode, target = target }
  Want("day", 1)
end

-- the walk over: the hub asked again; a walk to a calendar day that reached the match day goes back to «Inicio»
-- (the match is played or simulated from there)
function HOME.WalkEnd()
  local w = S.walk
  S.walk = nil
  local st = S.hub and S.hub.days and S.hub.days.stretch
  if w and w.mode == 3 and st and st.match_day then
    for k, t in ipairs(Tabs()) do
      if t.id == "home" then S.tab, S.page, S.month = k, 1, nil end
    end
  end
  Want("hub")
end

-- a key while walking: the walk ends at the day reached (at once between days, else after the day asked)
function HOME.WalkStop()
  local w = S.walk
  if w == nil then return false end
  w.halt = true
  if S.want == nil then HOME.WalkEnd() end
  return true
end

-- CMND_CAREERMODE_DAY's answer while walking: the line moved to the new day, the next one timed or the walk over
function HOME.WalkDay(v)
  local w = S.walk
  local st = S.hub and S.hub.days and S.hub.days.stretch
  if not v.ok or st == nil or type(v.day) ~= "table" or st.now == nil then
    if not v.ok then Log("day refused:", v.why) end
    HOME.WalkEnd()
    return
  end
  w.from, w.t = st.now.day, S.frame
  st.now, st.match_day = v.day, v.match_day == true
  local event = false
  if w.mode ~= 2 then
    for _, e in ipairs(st.events or {}) do
      if e.day and e.day.day == v.day.day then event = true end
    end
  end
  if v.stop ~= "" then Log("days stopped:", v.stop) end
  w.done = w.halt or v.stop ~= "" or st.match_day or event or (w.target ~= nil and v.day.day >= w.target)
  w.at = S.frame + WalkFrames()
end

-- from Step: the slide redrawn while it runs, the next day asked (or the walk ended) when its time comes
function HOME.WalkStep()
  local w = S.walk
  if w == nil then return end
  if w.at == nil then
    -- the day asked was replaced by another request: the walk ends there
    if S.want == nil then HOME.WalkEnd() end
    return
  end
  if S.frame < w.at then
    if S.frame - w.t <= WalkFrames() * HOME.SLIDE + 1 then S.dirty = true end
    return
  end
  if S.want ~= nil then return end
  w.at = nil
  if w.done or w.halt then HOME.WalkEnd() else Want("day", 1) end
end

-- the line's today position (a day number, fractional while the mark slides from the day before)
function HOME.WalkAt(now)
  local w = S.walk
  if w == nil or w.from == nil or w.t == nil then return now end
  local p = math.min(1, (S.frame - w.t) / (WalkFrames() * HOME.SLIDE))
  p = 1 - (1 - p) * (1 - p)
  return w.from + (now - w.from) * p
end

local REQUEST = {
  state = { cmd = "CMND_CAREERMODE_STATE" }, draw = { cmd = "CMND_CAREERMODE_DRAW" },
  slots = { cmd = "CMND_CAREERMODE_SLOTS" }, use = { cmd = "CMND_CAREERMODE_USE", arg = true },
  abandon = { cmd = "CMND_CAREERMODE_ABANDON", arg = true },
  hub = { cmd = "CMND_CAREERMODE_HUB", lang = true },
  standings = { cmd = "CMND_CAREERMODE_STANDINGS", arg = true }, start = { cmd = "CMND_CAREERMODE_START", args = true },
  setup = { cmd = "CMND_CAREERMODE_SETUP", arg = true },
  rosters = { cmd = "CMND_CAREERMODE_ROSTERS" }, play = { cmd = "CMND_CAREERMODE_PLAY" },
  sim = { cmd = "CMND_CAREERMODE_SIM" }, pots = { cmd = "CMND_CAREERMODE_POTS" },
  day = { cmd = "CMND_CAREERMODE_DAY", arg = true },
  advance = { cmd = "CMND_CAREERMODE_ADVANCE" },
  clubpool = { cmd = "CMND_CAREERMODE_CLUB_CALLUP", lang = true },
  clubpick = { cmd = "CMND_CAREERMODE_CLUB_CALLUP_PICK", arg = true, lang = true },
  clubconfirm = { cmd = "CMND_CAREERMODE_CLUB_CALLUP_CONFIRM" },
  dock = { cmd = "CMND_CAREERMODE_CLUB_DOCK" },
  dockset = { cmd = "CMND_CAREERMODE_CLUB_DOCK_SET", args = true },
  lookset = { cmd = "CMND_CAREERMODE_CLUB_LOOK_SET", args = true },
  market = { cmd = "CMND_CAREERMODE_MARKET", args = true },
  mbuy = { cmd = "CMND_CAREERMODE_MARKET_BUY", arg = true },
  mlist = { cmd = "CMND_CAREERMODE_MARKET_LIST", arg = true },
  msquad = { cmd = "CMND_CAREERMODE_MARKET", args = true },
  mstatus = { cmd = "CMND_CAREERMODE_MARKET_STATUS", args = true },
  manswer = { cmd = "CMND_CAREERMODE_MARKET_ANSWER", args = true },
  mtalk = { cmd = "CMND_CAREERMODE_MARKET_TALK", args = true },
  mcounter = { cmd = "CMND_CAREERMODE_MARKET_COUNTER", args = true },
  wcpool = { cmd = "CMND_CAREERMODE_WC_POOL", lang = true },
  wcpick = { cmd = "CMND_CAREERMODE_WC_PICK", arg = true, lang = true },
  wcconfirm = { cmd = "CMND_CAREERMODE_WC_CONFIRM" },
  save = { cmd = "CMND_CAREERMODE_SAVE" }, autosave = { cmd = "CMND_CAREERMODE_AUTOSAVE", arg = true },
}

-- a call-up list answered (World Cup or club): shown; refused = back to the hub
local function CallUpShown(v, w)
  if v.ok then
    S.wc, S.mode = v, "wcsquad"
    if w.kind == "wcpool" or w.kind == "clubpool" then S.wc_sel, S.wc_refused = 1, false end
  else
    Snd(SND.BUZZER)
    Log("call-up refused:", v.why)
    Want("hub")
  end
end

-- a call-up confirmed: back to the hub; refused = the list stays, marked
local function CallUpConfirmed(v, w)
  if v.ok then
    S.wc, S.mode = nil, "hub"
    if w.kind == "wcconfirm" then S.tab = 1 end
    if w.kind == "clubconfirm" then TabTo("squad") end
    Want("hub")
  else
    Snd(SND.BUZZER)
    S.wc_refused = true
    Log("call-up not confirmed:", v.why)
  end
end

-- ---- the transfer market ----------------------------------------------------------------------------------------------

local function MarketWant()
  local k = S.mk
  Want("market", { Lang(), "buy", MARKET_POSITIONS[k.pos], "all", k.first, MK.SORTS[k.sort], 0, MK.SearchText() })
end

-- «Plantilla»'s rows asked (the market view "listed": every player of the club, his status and offers, the men out
-- on loan); chain = the «Buscar» list asked after them (Want holds one request)
function MK.SquadWant(chain)
  S.mk.chain = chain == true
  Want("msquad", { Lang(), "listed", 0, "all", 1, "price", 0, "" })
end

-- after a market action: both sides asked again
function MK.Refresh()
  MK.SquadWant(true)
end

-- the selected row (k.sel counts from the list's top; the screen holds rows d.first ..)
local function MarketRow()
  local d = S.mk.data
  return d and d.rows and d.rows[S.mk.sel - (d.first or 1) + 1] or nil
end

-- the selection moved to `to` (1 .. total): the window follows it; rows outside it are asked for
function MK.Select(to)
  local k, d = S.mk, S.mk.data
  local total = d and d.total or 0
  if total == 0 then return false end
  to = math.max(1, math.min(total, to))
  if to == k.sel then return false end
  k.sel = to
  local first = k.first
  if to < first then first = to elseif to > first + MK.ROWS - 1 then first = to - MK.ROWS + 1 end
  if first ~= k.first then
    k.first = first
    MarketWant()
  end
  return true
end

-- the list again from its top (a position, filter or order change; «Plantilla» first when not asked yet)
function MK.Reset()
  S.mk.first, S.mk.sel = 1, 1
  if S.mk.sq == nil then MK.SquadWant(true) else MarketWant() end
end

-- a market action answered: refused = its reason in a window; the page asked again
local function MarketDone(v)
  if not v.ok then
    Snd(SND.BUZZER)
    Log("market refused:", v.why)
    S.dialog = { kind = "info", title = Tx("TabMarket"), lines = { Tx(v.text or "MarketRefused") } }
  else
    Snd(SND.DECIDE)
  end
  MK.Refresh()
end

-- ---- «Buscar» / «En venta»: the transfer talks (owner 2026-10-31, mock-up Mercado 2 A) --------------------------------
-- S.talk = { mode "buy" (a club's player: CMND_CAREERMODE_MARKET_TALK) / "sell" (an offer received:
-- CMND_CAREERMODE_MARKET_COUNTER), card, name, club, value, ask, start, last, offer (the amount being set), step, big,
-- patience (0..1), limit / demand / cost (the patience preview, MK.TalkCost), reply, money[, index, first (the
-- offer's)] }

-- a club's player: the talk asked (started when new)
function MK.TalkOpen(r)
  S.talk = { mode = "buy", card = r.card, name = r.name, club = r.club, value = r.value, pending = true }
  Want("mtalk", { r.card, 0 })
end

-- an offer received («Negociar»): the player's ask, from the bid up (or his last ask)
function MK.TalkOpenSell(r)
  local step = r.step or 1000
  S.talk = { mode = "sell", index = r.offer, card = r.card, name = r.name, club = r.bidder, value = r.value,
    ask = r.amount, start = r.amount, first = r.first, last = r.ask or 0, offer = math.max(r.amount + step, r.ask or 0),
    step = step, big = r.big or step * 10, patience = r.patience or 1, limit = r.limit, demand = r.demand,
    cost = S.mk.sq and S.mk.sq.talk_cost or nil, reply = (r.tries or 0) > 0 and "counter" or "open",
    money = S.mk.sq and S.mk.sq.money or 0 }
end

-- the amount kept inside its limits: a buy from one step to the club's ask, a sell from the bid to SELL_MAX x it
function MK.TalkClamp(t)
  local lo, hi = t.step, t.ask
  if t.mode == "sell" then lo, hi = t.ask, t.ask * MK.TALK.SELL_MAX end
  t.offer = math.max(lo or 0, math.min(hi or 0, t.offer or 0))
end

-- left / right (and the window's - / +): one step; L2 / R2: a big one
function MK.TalkStep(d, big)
  local t = S.talk
  if t == nil or t.pending then return end
  local before = t.offer
  t.offer = (t.offer or 0) + d * ((big and t.big or t.step) or 0)
  MK.TalkClamp(t)
  if t.offer == before then Snd(SND.BUZZER) return end
  Snd(SND.MOVE)
  S.dirty = true
end

-- a click on the talk window's bar (zone: its lo / hi amounts, px: the pointer): the amount at that point, in whole
-- steps from lo
function MK.TalkSlide(zn, px)
  local t = S.talk
  if t == nil or t.pending or (t.step or 0) <= 0 then return end
  local share = math.max(0, math.min(1, (px - zn.x0) / math.max(1, zn.x1 - zn.x0)))
  local before = t.offer
  t.offer = zn.lo + math.floor(share * (zn.hi - zn.lo) / t.step + 0.5) * t.step
  MK.TalkClamp(t)
  if t.offer == before then return end
  Snd(SND.MOVE)
  S.dirty = true
end

-- the window's keys: "offer" (A: the offer / the ask sent), "accept" (Y: the club's ask / the bid taken), "leave" (B:
-- the window closed, the talk kept), "minus" / "plus"
function MK.TalkKey(what)
  local t = S.talk
  if t == nil or t.pending then return end
  if what == "minus" or what == "plus" then MK.TalkStep(what == "minus" and -1 or 1, false) return end
  if what == "leave" then
    S.talk = nil
    Snd(SND.BACK)
    S.dirty = true
    return
  end
  if t.reply == "walked" then Snd(SND.BUZZER) return end
  Snd(SND.DECIDE)
  if what == "offer" then
    t.pending = true
    if t.mode == "sell" then Want("mcounter", { t.index, t.offer }) else Want("mtalk", { t.card, t.offer }) end
  elseif t.mode == "sell" then
    S.talk = nil
    Want("manswer", { t.index, 1 })
  else
    S.talk = nil
    Want("mbuy", t.card)
  end
  S.dirty = true
end

-- the talk's answer: a deal closed (a window says so), the club's / bidder's reply, or a refusal (the window stays)
function MK.TalkAnswer(v)
  local t = S.talk
  if t == nil then MK.Refresh() return end
  t.pending = nil
  if not v.ok then
    if t.start == nil then S.talk = nil end
    MarketDone(v)
    return
  end
  local a = v.talk
  if a == nil or a.reply == "accepted" then
    S.talk = nil
    Snd(SND.DECIDE)
    local sold = t.mode == "sell"
    S.dialog = { kind = "info", title = Tx(sold and "TalkSoldTitle" or "TalkDoneTitle"),
      lines = { Tx(sold and "TalkSoldLine" or "TalkDoneLine", t.name, Money(a and a.fee or t.offer)) } }
    MK.Refresh()
    return
  end
  if t.mode == "sell" then
    if a.reply == "pending" then
      S.talk = nil
      Snd(SND.DECIDE)
      S.dialog = { kind = "info", title = Tx("MkAskSentTitle"), lines = { Tx("MkAskSentLine", TeamName(t.club),
        Money(t.offer)), Tx("MkAskSentLine2") } }
      MK.Refresh()
      return
    end
    if a.reply == "walked" then
      S.talk = nil
      Snd(SND.BUZZER)
      S.dialog = { kind = "info", title = Tx("TabMarket"), lines = { Tx("TalkBidderWalked", TeamName(t.club)) } }
      MK.Refresh()
      return
    end
    t.ask, t.reply = a.amount, "counter"
    t.offer = math.max(t.offer, t.ask + t.step)
  else
    for key, x in pairs(a) do t[key] = x end
  end
  MK.TalkClamp(t)
  Snd(a.reply == "walked" and SND.BUZZER or SND.MOVE)
  S.dirty = true
end

-- the talks' cost curve on the screen (the scripts' curve: linear between the points, flat past the ends)
function MK.Curve(points, x)
  if type(points) ~= "table" or #points == 0 then return 0 end
  if x <= points[1][1] then return points[1][2] end
  for i = 2, #points do
    local a, b = points[i - 1], points[i]
    if x <= b[1] then
      local u = (b[1] == a[1]) and 1 or (x - a[1]) / (b[1] - a[1])
      return a[2] + (b[2] - a[2]) * u
    end
  end
  return points[#points][2]
end

-- the patience (share of the start) an amount would cost the other club, as the scripts reckon it (lib/market.lua
-- M.patience_cost): a sell ask over the bidder's most (t.limit): gap = ask / most - 1; a buy offer: gap = the club's
-- floor (t.limit) / offer - 1; x the club's demand
function MK.TalkCost(t, amount)
  local lim = t.limit or 0
  amount = amount or 0
  if lim <= 0 or amount <= 0 then return 0 end
  local gap
  if t.mode == "sell" then
    if amount <= lim then return 0 end
    gap = amount / lim - 1
  else
    gap = lim / amount - 1
  end
  return MK.Curve(t.cost, math.max(0, gap)) * (t.demand or 1)
end

-- a TINT plate on `layer` with rectangular holes ({ x0, y0, x1, y1 }, one row of them sharing y0 / y1) left open: the
-- layers under it show there (the window's face and crest: their layers lie under the dialog's)
function MK.HolePlate(layer, x, y, w, h, tint, holes)
  local hy0, hy1 = holes[1][2], holes[1][4]
  Quad(layer, ART.fill, x, y, w, hy0 - y, 1, nil, tint)
  local xs = x
  for _, o in ipairs(holes) do
    if o[1] > xs then Quad(layer, ART.fill, xs, hy0, o[1] - xs, hy1 - hy0, 1, nil, tint) end
    xs = math.max(xs, o[3])
  end
  if x + w > xs then Quad(layer, ART.fill, xs, hy0, x + w - xs, hy1 - hy0, 1, nil, tint) end
  Quad(layer, ART.fill, x, hy1, w, y + h - hy1, 1, nil, tint)
end

-- the window (owner pick negociar v2 / v3): a narrow white card over the player card's column. Header: name, the
-- other club (its crest and the player's face on the card's own layers, through holes in the plate); the other side's
-- amount; the amount being set with - / +, a slim bar of it; the club's patience as one bar (a lighter part = what
-- this amount would cost; red = it would walk away); one hint line, one line of facts; A (the main action), Y and B.
-- Under the card, its own panel: the budget now +/- the amount = after. On one layer a quad drawn later lies under the earlier ones.
function MK.TalkDraw()
  local t = S.talk
  if t == nil or S.dialog then return end
  local T = MK.TALK
  local X, Y, W, H, P = T.x, T.y, T.w, T.h, T.PAD
  local left, right, mx = X + P, X + W - P, X + W / 2
  local function Q(x, y, qw, qh, tint, a) Quad(L.dialog, ART.fill, x, y, qw, qh, a or 1, nil, tint) end
  local function Tt(str, x, y, style, sc, align) Text(L.dtext, str, x, y, style, sc, align) end
  local function Right(str, x, y, style, sc) Tt(str, x - MK.Width(str, style, sc), y, style, sc) end
  local function Zone(x, y, zw, zh, name)
    S.zones[#S.zones + 1] = { x0 = x, y0 = y, x1 = x + zw, y1 = y + zh, kind = "talk", name = name }
  end
  local sell = t.mode == "sell"
  local who = TeamName(t.club)
  -- the header: the face at the right, the other club's crest left of it (on their layers, under the holes)
  local fx = right - T.FACE / 2
  local cx = fx - T.FACE / 2 - 34
  local hy = Y + T.HEAD_H / 2
  Face(t.card, fx, hy, T.FACE, sell and Me(S.hub) or t.club)
  if (t.club or 0) ~= 0 then Crest(t.club, cx, hy, T.CREST) end
  Tt(Fit(t.name or "", cx - 40 - left, 28), left, hy - 16, "item", 0.86)
  Tt(Fit(who, cx - 40 - left, 20), left, hy + 20, "label_l", 1.0)
  Q(left, Y + T.HEAD_H, W - 2 * P, 2, TINT.rest)
  if t.pending and t.start == nil then
    Tt(Tx("TalkWaiting"), mx, Y + H / 2, "body_c", 0.9, "c")
  else
    -- the other side's amount and its reply
    local head
    if t.reply == "walked" then head = Tx("TalkWalkedHead", who)
    elseif t.reply == "low" then head = Tx("TalkLowHead", who)
    elseif t.reply == "counter" then head = Tx(sell and "TalkBidCounterHead" or "TalkCounterHead", who)
    else head = Tx(sell and "TalkTheyOffer" or "TalkTheyAsk", who) end
    Tt(Fit(head, W - 2 * P, 20), left, Y + 140, "label_l", 1.0)
    Tt(Thousands(t.ask or 0), mx, Y + 186, "big", 1.35, "c")
    -- the amount being set
    Tt(Tx(sell and "TalkYourAsk" or "TalkYourOffer"), mx, Y + 250, "label", 1.0, "c")
    local sy = Y + 268
    Q(left, sy, T.STEP_W, T.STEP_W, TINT.chip)
    Q(right - T.STEP_W, sy, T.STEP_W, T.STEP_W, TINT.chip)
    Zone(left, sy, T.STEP_W, T.STEP_W, "minus")
    Zone(right - T.STEP_W, sy, T.STEP_W, T.STEP_W, "plus")
    Tt("-", left + T.STEP_W / 2, sy + T.STEP_W / 2, "big", 1.2, "c")
    Tt("+", right - T.STEP_W / 2, sy + T.STEP_W / 2, "big", 1.2, "c")
    Tt(Fit(Thousands(t.offer or 0), W - 2 * P - 2 * T.STEP_W - 20, 48), mx, sy + T.STEP_W / 2, "big", 1.6, "c")
    -- its slim bar: a sell ask from the bid to SELL_MAX x it, a buy offer up to the club's ask
    local lo, hi = 0, t.ask or 1
    if sell then lo, hi = t.ask or 0, (t.ask or 0) * T.SELL_MAX end
    local share = math.max(0, math.min(1, ((t.offer or 0) - lo) / math.max(1, hi - lo)))
    local by = Y + 352
    Q(left + (W - 2 * P - 12) * share, by - 6, 12, 18, TINT.select)
    Q(left, by, W - 2 * P, 6, TINT.rest)
    -- a click on the bar: the amount there (MK.TalkSlide)
    S.zones[#S.zones + 1] = { x0 = left, y0 = by - 14, x1 = right, y1 = by + 20, kind = "talk", name = "slider",
      lo = lo, hi = hi }
    Tt(Tx("TalkStepsShort", Thousands(t.step or 0), Thousands(t.big or 0)), mx, Y + 380, "label", 0.9, "c")
    -- the patience: one bar, the part this amount would cost lighter (all of it red: the club would walk away)
    Tt(Tx(sell and "TalkBidderPatience" or "TalkPatience"), left, Y + 420, "label_l", 1.0)
    local p = math.max(0, math.min(1, t.patience or 0))
    local cost = t.reply == "walked" and 0 or MK.TalkCost(t, t.offer)
    local bw, py = W - 2 * P, Y + 440
    if cost >= p and p > 0 then
      Right(Tx("TalkCostWalk"), right, Y + 420, "label_l", 1.0)
      Q(left, py, bw * p, T.BAR_H, TINT.loss)
    else
      if cost > 0 then Right(Tx("TalkCostPreview", math.floor(100 * cost + 0.5)), right, Y + 420, "label_l", 1.0) end
      local keep = p - cost
      if keep > 0 then Q(left, py, bw * keep, T.BAR_H, TINT.select) end
      if cost > 0 then Q(left + bw * keep, py, bw * cost, T.BAR_H, TINT.cut, 0.55) end
    end
    Q(left, py, bw, T.BAR_H, TINT.rest)
    -- one hint, one line of facts
    Tt(Fit(Tx(sell and "TalkSellHint" or "TalkHint"), W - 2 * P, 18), mx, Y + 482, "label", 0.82, "c")
    Tt(Fit(Tx(sell and "TalkSellFactsShort" or "TalkFactsShort", MK.Short(sell and (t.first or t.ask) or t.start),
      MK.Short(t.value)), W - 2 * P, 18), mx, Y + 508, "label", 0.82, "c")
    -- the budget panel under the card: now +/- the amount = after (the amount on the accent; after < 0 on red)
    local boy = Y + H + T.GAP
    Q(X, boy, W, T.BOX_H, TINT.white)
    Tt(Tx("MarketBudget"), left, boy + 22, "label_l", 1.0)
    local cy = boy + 52
    local after = sell and (t.money or 0) + (t.offer or 0) or (t.money or 0) - (t.offer or 0)
    local x = right
    local res = Thousands(after)
    local rw = MK.Width(res, "item", 0.7)
    if after < 0 then
      Q(x - rw - 8, cy - 15, rw + 16, 30, TINT.loss)
      Tt(res, x - rw, cy, "item_on", 0.7)
    else
      Tt(res, x - rw, cy, "item", 0.7)
    end
    x = x - rw - 16
    Right("=", x, cy, "body", 0.7)
    x = x - MK.Width("=", "body", 0.7) - 12
    local amt = Thousands(t.offer or 0)
    local aw = MK.Width(amt, "body_w", 0.62) + 14
    Q(x - aw, cy - 14, aw, 28, TINT.select)
    Tt(amt, x - aw / 2, cy, "body_w", 0.62, "c")
    x = x - aw - 10
    Right(sell and "+" or "-", x, cy, "body", 0.7)
    x = x - MK.Width("+", "body", 0.7) - 10
    Right(Thousands(t.money or 0), x, cy, "body", 0.64)
    -- the buttons: A (the accent), Y and B
    local off = t.reply == "walked"
    local ay = Y + 528
    Tt(Fit(Tx(sell and "TalkAskButton" or "TalkOfferButton", MK.Short(t.offer)), W - 2 * P - 20, 24), mx,
      ay + T.BUTTON_H / 2, "body_w", 0.82, "c")
    Zone(left, ay, W - 2 * P, T.BUTTON_H, "offer")
    Q(left, ay, W - 2 * P, T.BUTTON_H, TINT.cut, off and 0.4 or 1)
    local sw = (W - 2 * P - 12) / 2
    local yy = Y + 592
    Tt(Fit(Tx("TalkAcceptButton", MK.Short(t.ask)), sw - 16, 20), left + sw / 2, yy + T.SMALL_H / 2, "body_c", 0.66, "c")
    Tt(Fit(Tx("TalkLeaveButton"), sw - 16, 20), left + sw + 12 + sw / 2, yy + T.SMALL_H / 2, "body_c", 0.66, "c")
    Zone(left, yy, sw, T.SMALL_H, "accept")
    Zone(left + sw + 12, yy, sw, T.SMALL_H, "leave")
    Q(left, yy, sw, T.SMALL_H, TINT.chip, off and 0.4 or 1)
    Q(left + sw + 12, yy, sw, T.SMALL_H, TINT.chip)
  end
  -- the plate (white, the header's holes open) and its accent line on top
  Q(X, Y, W, 4, TINT.cut)
  local h0, h1 = hy - T.FACE / 2 - 4, hy + T.FACE / 2 + 4
  MK.HolePlate(L.dialog, X, Y, W, H, TINT.white,
    { { cx - 26, h0, cx + 26, h1 }, { fx - T.FACE / 2 - 4, h0, fx + T.FACE / 2 + 4, h1 } })
end

-- the team page: the game's team screen with the career club (VRFW_TeamEditor.Run yields until it closes: run as a
-- coroutine resumed by Step while it lives). v = CMND_CAREERMODE_CLUB_DOCK's answer.
local function DockRun(v)
  local E = VRFW_TeamEditor
  local okl, has, level, formation, kit, emblem, coach = pcall(funcLuaCommand, Crc("CMND_VRFW_TEAM_LOOK"), v.team)
  if not (okl and has == true) then
    Log("team page: the club's record not read:", tostring(okl and level or has))
    level, formation, kit, emblem, coach = 0, 0, 0, 0, 0
  end
  local members = {}
  for i, m in ipairs(v.members or {}) do members[i] = { m[1], m[2], m[3], m[4] } end
  local res, why = E.Run({
    owner = "CareerMode", host = MENU, tab = true, members = members,
    formation = (v.formation or 0) ~= 0 and v.formation or formation, level = math.max(1, tonumber(level) or 1),
    name = (v.name or "") ~= "" and v.name or TeamName(v.team),
    emblem = (v.emblem or 0) ~= 0 and v.emblem or emblem, kit = (v.kit or 0) ~= 0 and v.kit or kit,
    coach = (v.coach or 0) ~= 0 and v.coach or coach, tactics = v.tactics or {}, synergies = {},
    header_top = G.TABS_DOCK.HEADER_TOP, header_dx = G.TABS_DOCK.HEADER_DX, list_top = G.TABS_DOCK.LIST_TOP, field_dy = G.TABS_DOCK.FIELD_DY,
    lock_identity = true, bench_columns = G.TABS_DOCK.BENCH_COLUMNS, field_dx = G.TABS_DOCK.FIELD_DX,
    bench_dx = G.TABS_DOCK.BENCH_DX, hide_card_rows = G.TABS_DOCK.HIDE_CARD_ROWS,
    hide_list = G.TABS_DOCK.HIDE_LIST, icons = G.TABS_DOCK.ICONS,
    -- A on a card: its popup on the team screen, Y: the player page (config.toml [squads] team_screen_card_actions)
    inline_card_actions = v.card_actions == true,
    -- the club's home stadium as the match engine plays it (its team's [home_stadiums]; 0 = none declared)
    stadium = select(2, pcall(funcLuaCommand, VRFW_Cmd.VRFW_TEAM_HOME_STADIUM, v.team or 0)) or 0,
    keep = v.keep == true, leaving = function(d) KEPT.Leaving(d) end,
  })
  if not res or res.own then
    Log("team page:", tostring(why))
    return nil
  end
  local parts = {}
  for _, m in ipairs(res.members or {}) do parts[#parts + 1] = string.format("%.0f:%.0f", m[1], m[2]) end
  local tactics = {}
  for i, id in ipairs(res.tactics or {}) do tactics[i] = string.format("%.0f", id) end
  Log("team page closed:", #parts, "club players placed,", res.foreign or 0, "other, formation", res.formation or 0,
    "direction", res.direction or 0)
  return { order = { res.formation or 0, table.concat(parts, ",") },
    look = { res.name or "", res.emblem or 0, res.kit or 0, res.coach or 0, table.concat(tactics, ",") },
    direction = res.direction or 0, kept = res.kept == true }
end

-- the tab whose id is `id` selected
TabTo = function(id)
  for k, t in ipairs(Tabs()) do
    if t.id == id then S.tab = k end
  end
end

-- a tab just selected: «Plantilla» opens the team screen at once, «Convocatoria» the call-up list
local function TabEntered()
  if S.mode ~= "hub" or S.hub == nil or S.want ~= nil or S.dock ~= nil then return end
  local id = (Tabs()[S.tab] or {}).id
  if id == "squad" and not S.squad_refused and S.hub.phase ~= "worldcup" then
    Want("dock")
  elseif id == "callup" then
    Want("clubpool")
  elseif id == "market" then
    -- both sides asked again (days may have passed: offers, loans, prices)
    S.mk.sq = nil
    MK.Reset()
  end
end

local function DockOpen(v)
  local why
  if not v.ok then why = v.why
  elseif type(VRFW_TeamEditor) ~= "table" then why = "no VRFW_TeamEditor in this menu"
  elseif not (S.kept and VRFW_TeamEditor.Kept and VRFW_TeamEditor.Kept("CareerMode")) then
    local can, no = VRFW_TeamEditor.CanOpen()
    if not can then why = "the editor refused: " .. tostring(no) end
  end
  if why then
    -- the career's own squad list stays on the tab (A tries again)
    S.squad_refused = true
    Log("team page not opened:", why)
    return
  end
  S.mode = "dock"
  S.dirty = true
  S.dock = coroutine.create(function() return DockRun(v) end)
  S.dock_steps = 0
  S.dock_now = true      -- resumed again in this Step (after Fetch): a kept dock shows in the same frame
end

-- L1 / R1 hid the kept team screen: the hub's previous / next tab drawn in the same frame (the order and look are
-- kept after, DockDone asks the hub again)
function KEPT.Leaving(d)
  if d == 0 then return end
  local n = #Tabs()
  S.tab = (S.tab - 1 + d) % math.max(1, n) + 1
  S.page, S.month = 1, nil
  S.mode = "hub"
  S.dock_switched = true
  Snd(SND.MOVE)
  S.dirty = true
end

-- the team screen gone: the hub's previous / next tab (L1 / R1 there), or back (B)
local function DockDone()
  local d = S.dock_after or 0
  S.dock_after = nil
  S.mode = "hub"
  S.dirty = true
  if d == 0 then
    S.dock_switched = nil
    Want("state")
    return
  end
  if not S.dock_switched then
    local n = #Tabs()
    S.tab = (S.tab - 1 + d) % math.max(1, n) + 1
    S.page, S.month = 1, nil
    Snd(SND.MOVE)
  end
  S.dock_switched = nil
  if (Tabs()[S.tab] or {}).id == "callup" then Want("clubpool") else Want("hub") end
end

-- Step: the team screen's coroutine resumed; when it ends, what was left there is kept, then DockDone
local function DockStep()
  local co = S.dock
  if co == nil then return end
  local ok, out = coroutine.resume(co)
  if not ok then Log("team page error", tostring(out)) end
  if coroutine.status(co) ~= "dead" then
    -- once, the team screen up: is the tab bar shown over it (its strip and first label)
    S.dock_steps = S.dock_steps + 1
    if S.dock_steps == G.TABS_DOCK.CHECK then
      local okp, panel = pcall(funcLuaMenuCommand, C.IS_VISIBLE, L.panel, 0)
      local okt, text = pcall(funcLuaMenuCommand, C.IS_VISIBLE, L.text, 0)
      Log("team page: tab bar over the team screen: strip", tostring(okp and panel), "label", tostring(okt and text))
    end
    return
  end
  S.dock = nil
  S.kept = ok and type(out) == "table" and out.kept == true
  if ok and type(out) == "table" then
    S.dock_after, S.dock_look = out.direction, out.look
    Want("dockset", out.order)
  else
    S.squad_refused = true
    S.mode = "hub"
    Want("hub")
  end
  S.dirty = true
end

-- each kind's answer (v = the script's table, w = the request)
local ANSWER = {
  -- «Guardar progreso»: the result in a window, the page's last save time updated
  save = function(v)
    Snd(v.ok and SND.DECIDE or SND.BUZZER)
    if v.ok and S.hub then S.hub.saved_at = v.at end
    if not v.ok then Log("save refused:", v.why) end
    S.dialog = { kind = "info", title = Tx(v.ok and "SaveDone" or "SaveFailed"),
      lines = { v.ok and Tx("SettingsLastSaved", SETTINGS.Stamp(v.at)) or Tx("SaveFailedLine") } }
    S.dirty = true
  end,
  -- the autosave checkbox: the page shows the career's setting
  autosave = function(v)
    if not v.ok then
      Snd(SND.BUZZER)
      Log("autosave refused:", v.why)
    elseif S.hub then
      S.hub.autosave, S.hub.saved_at = v.autosave, v.at
    end
    S.dirty = true
  end,
  state = function(v)
    S.state, S.slots = v, nil
    S.mode = "home"
    Log("open: clubs", v.clubs, "career", v.career ~= nil, v.why ~= "" and v.why or "")
    -- back from a match of the club: straight to the hub; else the save slot's careers
    if v.career and v.career.fresh then Want("rosters", "hub") else Want("slots") end
  end,
  slots = function(v)
    if not v.ok then return end
    if S.slots == nil then S.button = v.active or 1 end
    S.slots = v
  end,
  -- a career picked: continued (it holds one), else a new one in it (the club pick)
  use = function(v)
    if not v.ok then
      Snd(SND.BUZZER)
      Log("career not picked:", v.why)
    elseif v.career then Want("rosters", "hub")
    elseif S.state and S.state.ok then Want("draw")
    else Snd(SND.BUZZER) end
  end,
  abandon = function(v)
    if not v.ok then Snd(SND.BUZZER) end
    Want("slots")
  end,
  draw = function(v)
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
  end,
  rosters = function(v, w)
    RestoreRosters()
    S.apply = {}
    for _, t in ipairs(v.teams or {}) do
      S.apply[#S.apply + 1] = { team = t.team, rows = t.rows or {}, levels = t.levels or {} }
    end
    Log("career squads:", #S.apply, "club(s) to write")
    if w.arg == "pick" then PickFocus() else Want("hub") end
  end,
  setup = function(v, w)
    if v.ok and type(v.backing) == "table" and type(v.negotiation) == "table" and type(v.activity) == "table" then
      S.setup = { v = v, row = 1, team = v.team, market = v.market ~= false, sacking = v.sacking == true,
        backing = math.max(1, math.min(#(v.backing.steps or { 0 }), tonumber(v.backing.default) or 1)),
        neg = tonumber(v.negotiation.default) or 1, act = tonumber(v.activity.default) or 1 }
      S.mode = "setup"
    else
      Snd(SND.BUZZER)
      Log("setup refused:", v.why)
    end
  end,
  start = function(v)
    if v.ok then
      S.setup = nil
      Want("rosters", "hub")
      S.rate, S.clubs, S.queue = {}, {}, {}
    else
      Snd(SND.BUZZER)
      Log("start refused:", v.why)
    end
  end,
  hub = function(v)
    if v.ok then
      HubEntered(v)
      if v.phase == "pots" and S.after_hub == "pots" then Want("pots") end
      S.after_hub = nil
      local tid = (Tabs()[S.tab] or {}).id
      if tid == "squad" or tid == "market" then TabEntered() end
    else
      Log("hub refused:", v.why)
      S.mode = "home"
    end
  end,
  standings = function(v)
    if v.ok then
      S.table, S.tindex, S.tpage, S.tcur = v, v.index, 1, nil
      if v.table and v.table.kind == "worldcup" and v.table.knockout then S.tpage = 2 end
      for k, r in ipairs(v.table and v.table.rows or {}) do
        if r.team == S.hub.team then S.tpage = math.floor((k - 1) / (S.hub.table_rows or 20)) + 1 end
      end
    end
  end,
  play = function(v)
    if v.ok then StartMatch(v) else
      Snd(SND.BUZZER)
      Log("play refused:", v.why)
    end
  end,
  sim = function(v)
    if v.ok then Want("hub") else Snd(SND.BUZZER) end
  end,
  -- a day walked (or up to the match): the hub again; a stop (an offer, the window) is in the news and the line
  day = function(v)
    if S.walk then HOME.WalkDay(v) return end
    if not v.ok then
      Snd(SND.BUZZER)
      Log("day refused:", v.why)
      return
    end
    if v.stop ~= "" then Log("days stopped:", v.stop) end
    Want("hub")
  end,
  pots = function(v)
    if v.ok then
      S.pots, S.mode = { pots = v.pots, leagues = v.leagues, team = v.team, tints = v.pot_tints or {}, drawn = 0,
        flash = 0 }, "pots"
    else
      Snd(SND.BUZZER)
    end
  end,
  advance = function()
    S.mode = "hub"
    S.tab = 1
    Want("hub")
  end,
  wcpool = CallUpShown, wcpick = CallUpShown, clubpool = CallUpShown, clubpick = CallUpShown,
  wcconfirm = CallUpConfirmed, clubconfirm = CallUpConfirmed,
  dock = DockOpen,
  market = function(v)
    if not v.ok then
      Log("market refused:", v.why)
      S.mk.data, S.mk.pricing = nil, nil
      return
    end
    -- the day's prices still being worked out (a batch per call): asked again, the list waits
    if v.pricing then
      S.mk.pricing = v.pricing
      MarketWant()
      return
    end
    S.mk.pricing = nil
    if v.steps then S.mk.meta = { steps = v.steps, series = v.series or {}, clubs = v.clubs or {}, groups = v.club_groups or {} } end
    S.mk.data, S.mk.first = v, v.first or 1
    S.mk.sel = math.max(1, math.min(S.mk.sel, v.total or 1))
    local teams = {}
    for _, r in ipairs(v.rows or {}) do
      if (r.club or 0) ~= 0 then teams[#teams + 1] = r.club end
    end
    Queue(teams)
  end,
  -- «Plantilla»'s rows (and «En venta»'s offers): the selections kept in range
  msquad = function(v)
    local k = S.mk
    if v.ok then
      if v.steps then k.meta = { steps = v.steps, series = v.series or {}, clubs = v.clubs or {}, groups = v.club_groups or {} } end
      k.sq, k.sqf, k.sale = v, nil, nil
      local rows = MK.SquadRows()
      k.ssel = math.max(1, math.min(k.ssel, math.max(1, #rows)))
      k.osel = math.max(1, math.min(k.osel, math.max(1, #MK.SaleRows())))
      if k.menu and #MK.Options(rows[k.ssel]) == 0 then k.menu = false end
      local teams = {}
      for _, r in ipairs(v.rows or {}) do
        if (r.club or 0) ~= 0 then teams[#teams + 1] = r.club end
        for _, o in ipairs(r.offers or {}) do teams[#teams + 1] = o.bidder end
      end
      Queue(teams)
    else
      Log("market squad refused:", v.why)
      k.sq, k.sqf, k.sale = nil, nil, nil
    end
    if k.chain then
      k.chain = false
      MarketWant()
    end
  end,
  mstatus = MarketDone,
  mbuy = MarketDone, mlist = MarketDone, manswer = MarketDone,
  mtalk = function(v) MK.TalkAnswer(v) end, mcounter = function(v) MK.TalkAnswer(v) end,
  dockset = function(v)
    if not v.ok then Log("team page: the order was not kept:", v.why) end
    local look = S.dock_look
    S.dock_look = nil
    if look then Want("lookset", look) else DockDone() end
  end,
  lookset = function(v)
    if not v.ok then Log("team page: the club's look was not kept:", v.why) end
    S.kits = {}      -- the club's kit may have changed: the minifaces asked again with it
    if VRFW_FaceIcon ~= nil then VRFW_FaceIcon.Forget(L.face) end
    DockDone()
  end,
}

-- the pending request, asked again next Step while the scripts are busy (the bridge answers nothing then)
local function Fetch()
  local w = S.want
  if w == nil then return end
  if KEPT.Step() then return end
  local req = REQUEST[w.kind]
  local args, n = {}, 0
  if req.arg then n = n + 1; args[n] = w.arg end
  if req.args then
    for _, a in ipairs(w.arg or {}) do n = n + 1; args[n] = a end
  end
  if req.lang then n = n + 1; args[n] = Lang() end
  local v = Call(req.cmd, table.unpack(args, 1, n))
  if v == nil then
    w.tries = w.tries + 1
    if w.tries == 300 then Log("no answer to", w.kind, "after 300 frames") end
    return
  end
  S.want = nil
  S.dirty = true
  ANSWER[w.kind](v, w)
end

-- leave the screen: the data's rosters back unless a match of the career starts
local function Close()
  if S.closing then return end
  if S.kept then
    -- the kept team screen and its save session go first (Step closes the screen once it is done)
    KEPT.Release("the screen closes")
    S.closing, S.close_after_release = true, true
    M(C.INPUT, MENU, false)
    return
  end
  S.closing = true
  UNDER.Hide(false)
  TreeHide("the screen closes")
  TabKeys(false)
  HOME.PromptKeys(nil)
  if not S.match then RestoreRosters() end
  M(C.INPUT, MENU, false)
  if S.pic then
    -- the news card's model released before the screen goes (Step closes it, at most CLOSE_WAIT frames later)
    S.pic.Hide()
    S.close_at = S.frame
  else
    CloseScreen()
  end
  Log("closed")
end

local function Accept()
  if S.walk then
    if HOME.WalkStop() then Snd(SND.DECIDE) end
    return
  end
  if S.want ~= nil or S.match or S.dock then return end
  if S.dialog then
    local d = S.dialog
    S.dialog = nil
    Snd(SND.DECIDE)
    if d.choice and d.choice ~= 1 then S.dirty = true return end
    if d.kind == "delete" then Want("abandon", d.slot)
    elseif d.kind == "buy" then Want("mbuy", d.card)
    elseif d.kind == "offer" or d.kind == "loanoffer" then Want("manswer", { d.index, 1 })
    elseif d.kind == "save" then Want("save")
    elseif d.kind == "walkto" then HOME.WalkStart(3, d.day) end
    S.dirty = true
    return
  end
  if S.talk then MK.TalkKey("offer") return end
  if S.mode == "home" then
    local b = S.buttons and S.buttons[S.button]
    if b == nil or b.action ~= "slot" then return end
    Snd(SND.DECIDE)
    Want("use", b.slot)
  elseif S.mode == "pick" then
    local team = PickTeams()[S.pick.sel]
    if team == nil then return end
    Snd(SND.DECIDE)
    Want("setup", team)
  elseif S.mode == "setup" and S.setup then
    local st = S.setup
    if SETUP.ROWS[st.row].id ~= "start" then
      if SETUP.Change(1) then Snd(SND.MOVE) S.dirty = true end
      return
    end
    Snd(SND.DECIDE)
    Want("start", { st.team, st.market and 1 or 0, st.backing, st.neg, st.act, st.sacking and 1 or 0 })
  elseif S.mode == "hub" then
    local tab = Tabs()[S.tab] or {}
    local n = S.hub.next or {}
    if tab.id == "market" then MK.Accept() return end
    if tab.id == "squad" then
      if S.hub.phase == "worldcup" then Snd(SND.BUZZER) return end
      Snd(SND.DECIDE)
      S.squad_refused = false
      Want("dock")
      S.dirty = true
      return
    end
    if tab.id == "settings" then
      local sb = S.buttons and S.buttons[S.button]
      if sb and sb.action == "autosave" then
        Snd(SND.DECIDE)
        Want("autosave", S.hub.autosave == false)
        S.dirty = true
        return
      end
      if sb == nil or sb.action ~= "save" then Snd(SND.BUZZER) return end
      Snd(SND.DECIDE)
      local at = S.hub.saved_at
      S.dialog = { kind = "save", title = Tx("SaveProgress"), choice = 1, buttons = { Tx("Yes"), Tx("No") },
        lines = { Tx("SaveAsk"), (type(at) == "string" and at ~= "") and Tx("SettingsLastSaved", SETTINGS.Stamp(at))
          or Tx("SettingsNotSaved") } }
      S.dirty = true
      return
    end
    if tab.id == "calendar" then CAL.Pick(S.hub) return end
    if tab.id ~= "home" then Snd(SND.BUZZER) return end
    local b = S.buttons and S.buttons[S.button]
    Snd(SND.DECIDE)
    if b and b.action == "news_offers" then
      local market
      for k, t in ipairs(Tabs()) do if t.id == "market" then market = k end end
      if market == nil then Snd(SND.BUZZER) return end
      S.mk.sec, S.mk.focus, S.mk.osel, S.mk.ofirst, S.mk.menu, S.mk.sq = 2, "list", 1, 1, false, nil
      S.tab, S.page, S.month = market, 1, nil
      TabEntered()
    elseif b and b.action == "sim" then Want("sim")
    elseif b and (b.action == "day" or b.action == "tomatch") then HOME.WalkStart(b.action == "day" and 1 or 2)
    elseif n.kind == "match" then
      local st = S.hub.days and S.hub.days.stretch
      if tab.id == "home" and st and not st.match_day then HOME.WalkStart(1) else Want("play") end
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
      p.drawn, p.flash = p.drawn + 1, G.POTS.FLASH
    end
  end
  S.dirty = true
end

-- Y: simulate the club's match (hub) / draw every ball left (the draw of the leagues)
local function Second()
  if S.walk then
    if HOME.WalkStop() then Snd(SND.DECIDE) end
    return
  end
  if S.want ~= nil or S.dialog or S.match or S.dock then return end
  if S.talk then MK.TalkKey("accept") return end
  if S.mode == "hub" and S.hub and (Tabs()[S.tab] or {}).id == "market" then MK.Second() return end
  local tab_id = S.mode == "hub" and S.hub and (Tabs()[S.tab] or {}).id
  local kind = tab_id == "competition" and TableNow().kind or nil
  if tab_id == "competition" and kind ~= "bracket" and kind ~= "worldcup" then
    -- Y: the focus between the table and the players' stats
    S.tfocus = S.tfocus == "stats" and "table" or "stats"
    Snd(SND.MOVE)
  elseif tab_id == "home" and S.hub.next and S.hub.next.kind == "match" then
    Snd(SND.DECIDE)
    local st = S.hub.days and S.hub.days.stretch
    if tab_id == "home" and st and not st.match_day then HOME.WalkStart(2) else Want("sim") end
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
  if S.walk then
    if HOME.WalkStop() then Snd(SND.BACK) end
    return
  end
  if S.want ~= nil or S.match or S.dock or S.kb then return end
  if S.talk and not S.dialog then MK.TalkKey("leave") return end
  if S.mk.fp and not S.dialog then MK.FilterInput("back") return end
  if S.mk.pv and not S.dialog then MK.ViewInput("back") return end
  if S.mode == "hub" and not S.dialog and (Tabs()[S.tab] or {}).id == "market"
      and (S.mk.focus == "search" or (S.mk.focus == "squad" and S.mk.menu)) then
    Snd(SND.BACK)
    if S.mk.focus == "search" then S.mk.focus = "list" else S.mk.menu = false end
    S.dirty = true
    return
  end
  Snd(SND.BACK)
  if S.dialog then S.dialog = nil
  elseif S.mode == "pots" then Want("hub")
  elseif S.mode == "wcsquad" then
    if S.wc and S.wc.kind == "club" then TabTo("squad") end
    S.wc = nil
    Want("hub")
  elseif S.mode == "setup" then
    S.setup, S.mode = nil, "pick"
  elseif S.mode == "pick" or S.mode == "hub" then Want("state")
  else Close() end
  S.dirty = true
end

local function Move(dx, dy)
  if S.dialog and S.dialog.choice and dx ~= 0 and S.want == nil then
    S.dialog.choice = math.max(1, math.min(#S.dialog.buttons, S.dialog.choice + dx))
    Snd(SND.MOVE)
    S.dirty = true
    return
  end
  if S.want ~= nil or S.dialog or S.match or S.dock then return end
  if S.talk then
    if dx ~= 0 then MK.TalkStep(dx, false) end
    return
  end
  if S.mode == "home" then
    if dx == 0 then return end
    S.button = math.max(1, math.min(#(S.buttons or {}), S.button + dx))
  elseif S.mode == "wcsquad" and S.wc then
    local n = #WcList()
    if n == 0 then return end
    -- up / down: the next row; left / right: the other column
    local step = dy ~= 0 and dy or dx * WC.PER_COLUMN
    S.wc_sel = math.max(1, math.min(n, (S.wc_sel or 1) + step))
  elseif S.mode == "setup" and S.setup then
    local moved
    if dy ~= 0 then moved = SETUP.Move(dy) else moved = SETUP.Change(dx) end
    if not moved then return end
  elseif S.mode == "pick" then
    local n = #PickTeams()
    if dx == 0 or n == 0 then return end
    S.pick.sel = (S.pick.sel - 1 + dx) % n + 1
    PickFocus()
  elseif S.mode == "hub" and (Tabs()[S.tab] or {}).id == "market" then
    if not MK.Move(dx, dy) then return end
  elseif S.mode == "hub" then
    local tab = Tabs()[S.tab] or {}
    if tab.id == "calendar" and (dx ~= 0 or dy ~= 0) then
      if not CAL.MoveDay(dx + 7 * dy) then return end
    elseif tab.id == "settings" and (dx ~= 0 or dy ~= 0) then
      -- the save button (1) and the autosave checkbox (2)
      S.button = S.button == 1 and 2 or 1
    elseif tab.id == "competition" and dx ~= 0 then
      local n = #STANDINGS.STATS.TABS
      S.stab = ((S.stab or 1) - 1 + dx) % n + 1
    elseif tab.id == "competition" and dy ~= 0 then
      if TableNow().kind == "worldcup" then
        S.tpage = S.tpage + dy
      elseif S.tfocus == "stats" and TableNow().kind ~= "bracket" then
        if not STANDINGS.StatsScroll(dy) then return end
      else
        local to = math.max(1, math.min(#(TableNow().rows or {}), (S.tcur or 1) + dy))
        if to == S.tcur then return end
        S.tcur = to
      end
    elseif tab.id == "home" and (dx ~= 0 or dy ~= 0) then
      -- the arrows: the news (left / right slide sideways, up / down rise)
      NewsScroll(dx ~= 0 and dx or dy, dx ~= 0 and dx or nil)
      return
    else
      return
    end
  else
    return
  end
  Snd(SND.MOVE)
  S.dirty = true
end

-- the pointer over the hub's buttons: the button under it takes the focus (asked only while buttons show)
-- the pointer zone under (px, py): the last one drawn wins (dialogs over the page)
local function ZoneAt(px, py)
  local zs = S.zones or {}
  for k = #zs, 1, -1 do
    local zn = zs[k]
    if px >= zn.x0 and px < zn.x1 and py >= zn.y0 and py < zn.y1 then return zn end
  end
  return nil
end

-- the pointer over the screen: a dialog's button or a hub button under it takes the focus. The engine gives no
-- pointer callback: its position is read once a frame while something can be hovered, a move = a change of it
-- the pointer over a focusable zone (hover = true): its element focused, as the arrows would -> true when it changed.
-- One entry a zone kind; the market's kinds go through MK.Hover / MK.Select / MK.FilterInput
-- POINTER.KEY: the key line's keys (Footer zones "key") -> the function that key runs (filled in OnInit)
local POINTER = { KEY = {} }
POINTER.HOVER = {
  cday = function(zn)
    if S.mode ~= "hub" or S.cday == zn.index then return false end
    S.cday = zn.index
    return true
  end,
  trow = function(zn)
    if S.mode ~= "hub" or (S.tcur == zn.index and S.tfocus ~= "stats") then return false end
    S.tcur, S.tfocus = zn.index, "table"
    return true
  end,
  stab = function()
    if S.mode ~= "hub" or S.tfocus == "stats" then return false end
    S.tfocus = "stats"
    return true
  end,
  tpanel = function(zn)
    if S.mode ~= "hub" or (S.tfocus or "table") == zn.side then return false end
    S.tfocus = zn.side
    return true
  end,
  srow = function(zn)
    local st = S.setup
    if S.mode ~= "setup" or st == nil or st.row == zn.index or not SETUP.RowOn(zn.index) then return false end
    st.row = zn.index
    return true
  end,
  wcrow = function(zn)
    if S.mode ~= "wcsquad" or S.wc_sel == zn.index then return false end
    S.wc_sel = zn.index
    return true
  end,
}

local function PointerHover()
  if S.want ~= nil or S.match then return end
  local dialog = S.dialog and S.dialog.choice
  if not dialog and (S.dialog or (#(S.buttons or {}) == 0 and #(S.zones or {}) == 0)) then return end
  local okp, px, py = pcall(funcLuaMenuCommand, C.POINTER)
  if not (okp and type(px) == "number" and type(py) == "number") then return end
  local last = S.pointer
  S.pointer = { px, py }
  if last == nil or (math.abs(px - last[1]) <= 1 and math.abs(py - last[2]) <= 1) then return end
  if dialog then
    local zn = ZoneAt(px, py)
    if zn and zn.kind == "dialog" and zn.index ~= S.dialog.choice then
      S.dialog.choice = zn.index
      Snd(SND.MOVE)
      S.dirty = true
    end
    return
  end
  local zn = ZoneAt(px, py)
  if S.talk then return end
  if S.mk.fp then
    MK.FilterInput("hover", zn)
    return
  end
  if S.mk.pv then return end
  if zn and zn.hover and POINTER.HOVER[zn.kind] then
    if POINTER.HOVER[zn.kind](zn) then
      Snd(SND.MOVE)
      S.dirty = true
    end
    return
  end
  if zn and zn.hover and (zn.kind == "mbar" or zn.kind == "mfbtn") then
    local row = zn.kind == "mbar" and 1 or 2
    if S.mk.focus ~= "search" or S.mk.srow ~= row then
      S.mk.focus, S.mk.srow, S.mk.menu = "search", row, false
      Snd(SND.MOVE)
      S.dirty = true
    end
    return
  end
  if zn and zn.hover and zn.kind == "mrow" then
    if MK.Select(zn.index) or S.mk.focus ~= "list" then
      S.mk.focus = "list"
      Snd(SND.MOVE)
      S.dirty = true
    end
    return
  end
  if zn and zn.hover and (zn.kind == "msq" or zn.kind == "mopt" or zn.kind == "msale") then
    if MK.Hover(zn) then
      Snd(SND.MOVE)
      S.dirty = true
    end
    return
  end
  local k = ButtonAt(px, py)
  if k ~= nil and k ~= S.button then
    S.button = k
    Snd(SND.MOVE)
    S.dirty = true
  end
end

local Turn
local FN = {}      -- the screen's functions by CMD_FUNCTION argument crc (filled in OnInit)

-- a left click: the hub button under the pointer is pressed (elsewhere nothing happens)
local function Click()
  if S.want ~= nil or S.match then return end
  local okp, px, py = pcall(funcLuaMenuCommand, C.POINTER)
  local zn = okp and type(px) == "number" and type(py) == "number" and ZoneAt(px, py) or nil
  if zn and zn.kind == "key" then                                       -- the key line: as that key
    local f = POINTER.KEY[zn.key]
    if f then f() end
    return
  end
  if S.dialog then
    -- a dialog's button: focused and pressed (A)
    if zn and zn.kind == "dialog" and S.dialog.choice then
      S.dialog.choice = zn.index
      Accept()
    end
    return
  end
  if S.talk then
    -- the talk window's buttons and - / +; elsewhere nothing
    if zn and zn.kind == "talk" and S.want == nil then
      if zn.name == "slider" then MK.TalkSlide(zn, px) else MK.TalkKey(zn.name) end
    end
    return
  end
  if S.mk.fp then
    MK.FilterInput("click", zn)
    return
  end
  if zn and zn.kind == "tab" then
    -- a tab of the hub's bar or a game of the club pick's bar: as L1 / R1 that many times
    local now = S.mode == "pick" and S.pick and S.pick.league or S.tab
    if zn.index ~= now then Turn(zn.index - now) end
    return
  end
  if zn and zn.kind == "move" then Move(zn.dx, zn.dy) return end
  if zn and zn.kind == "cmonth" and S.mode == "hub" then                -- the calendar title's arrows
    if CAL.Month(zn.index) then
      Snd(SND.MOVE)
      S.dirty = true
    end
    return
  end
  if zn and zn.kind == "cday" and S.mode == "hub" and S.dialog == nil then  -- a calendar day: selected, again: A
    if S.cday ~= zn.index then
      S.cday = zn.index
      Snd(SND.MOVE)
      S.dirty = true
    else
      Accept()
    end
    return
  end      -- an arrow, a neighbour crest: as the arrow key
  if zn and zn.kind == "srow" and S.mode == "setup" and S.setup then  -- a row, its arrows, «Empezar carrera»
    local st = S.setup
    if st.row ~= zn.index then
      st.row = zn.index
      Snd(SND.MOVE)
      S.dirty = true
    end
    if zn.dx then
      if SETUP.Change(zn.dx) then
        Snd(SND.MOVE)
        S.dirty = true
      end
    elseif SETUP.ROWS[zn.index].id == "start" then
      Accept()
    end
    return
  end
  if zn and zn.kind == "cstep" and S.mode == "hub" then COMPETITION.Step(zn.d) return end   -- the L2 / R2 arrows
  if zn and (zn.kind == "trow" or zn.kind == "stab") and S.mode == "hub" then  -- a table row, a stats tab
    local field = zn.kind == "trow" and "tcur" or "stab"
    local side = zn.kind == "trow" and "table" or "stats"
    if S[field] ~= zn.index or (S.tfocus or "table") ~= side then
      S[field], S.tfocus = zn.index, side
      Snd(SND.MOVE)
      S.dirty = true
    end
    return
  end
  if zn and zn.kind == "tswitch" and S.mode == "hub" then              -- the Torneos switch: as Y / the arrows
    if zn.d == 0 then Second() else Move(0, zn.d) end
    return
  end
  if zn and zn.kind == "tpanel" and S.mode == "hub" then               -- a Torneos panel: focused
    if POINTER.HOVER.tpanel(zn) then
      Snd(SND.MOVE)
      S.dirty = true
    end
    return
  end
  if zn and zn.kind == "wcrow" and S.mode == "wcsquad" then            -- a Convocatoria row: focused, again: A
    if not POINTER.HOVER.wcrow(zn) then Accept() return end
    Snd(SND.MOVE)
    S.dirty = true
    return
  end
  if zn and zn.kind == "comp" and S.mode == "hub" then                 -- a competition's chip: that one shown
    if zn.index ~= S.tindex then
      Snd(SND.MOVE)
      Want("standings", zn.index)
    end
    return
  end
  if zn and zn.kind == "ppanel" and S.mode == "pick" then             -- a tab of the club pick's panel
    if zn.index ~= (S.pick.panel or 1) then
      S.pick.panel = zn.index
      Snd(SND.MOVE)
      S.dirty = true
    end
    return
  end
  if zn and zn.kind == "fn" then                                       -- a button or chip: as its key
    local f = FN[Crc(zn.name)]
    if f then f() end
    return
  end
  if zn and S.mode == "hub" and (Tabs()[S.tab] or {}).id == "market" then
    MK.Click(zn, py)
    return
  end
  local shown = S.news and S.news.items[S.news.at]
  if okp and type(px) == "number" and type(py) == "number" and S.mode == "hub" and shown
    and shown.action ~= "offers" and (Tabs()[S.tab] or {}).id == "home" and px >= FEED.x and px < FEED.x + FEED.w
    and py >= FEED.y and py < FEED.y + FEED.h then
    -- a click on the card's left half: the previous item, on its right half: the next (sideways)
    local d = px < FEED.x + FEED.w / 2 and -1 or 1
    NewsScroll(d, d)
    return
  end
  if #(S.buttons or {}) == 0 then return end
  local k = okp and type(px) == "number" and type(py) == "number" and ButtonAt(px, py) or nil
  if k == nil then return end
  S.button = k
  Accept()
end

-- L1 / R1: the game on the club pick, the tab on the hub (d tabs on; a click jumps several)
Turn = function(d)
  if S.mk.fp and S.want == nil and not S.dialog then MK.FilterInput("step", d) return end
  if S.want ~= nil or S.dialog or S.match or S.dock or S.talk then return end
  if S.mode == "setup" and S.setup then
    if SETUP.ROWS[S.setup.row].id ~= "backing" or not SETUP.Change(d, S.setup.v.backing.jump or 1) then return end
  elseif S.mode == "pick" and S.draw then
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
    S.squad_refused = false
    S.mk.pv = nil
    Snd(SND.MOVE)
    S.dirty = true
    TabEntered()
    return
  else
    return
  end
  Snd(SND.MOVE)
  S.dirty = true
end

-- X: the draw's club panel tab, a career deleted, the market's X (MK.Third)
local function Third()
  if S.want ~= nil or S.dialog or S.match or S.dock or S.talk then return end
  if S.mode == "pick" and S.draw then
    -- X: the club panel's other tab (Resumen / Plantilla)
    S.pick.panel = (S.pick.panel or 1) % #PICK.TABS + 1
    Snd(SND.MOVE)
    S.dirty = true
    return
  end
  if S.mode == "home" then
    -- X: the focused career deleted after a confirmation («Cancelar» focused first)
    local b = S.buttons and S.buttons[S.button]
    local slot = b and S.slots and S.slots.slots[b.slot]
    if not (slot and slot.used) then return end
    Snd(SND.DECIDE)
    local sum = slot.summary
    S.dialog = { kind = "delete", slot = b.slot, title = Tx("DeleteTitle", b.slot), choice = 2,
      buttons = { Tx("Delete"), Tx("Cancel") },
      lines = { TeamName(sum.team) .. "  ·  " .. Tx("SeasonN", sum.season or 1), Tx("DeleteLine") } }
    S.dirty = true
    return
  end
  if not (S.mode == "hub" and S.hub and (Tabs()[S.tab] or {}).id == "market") then return end
  MK.Third()
end

-- right stick / wheel: the news feed of «Inicio», the lists of the other tabs and screens
local function NewsFeed(d)
  if S.talk and S.want == nil and not S.dialog then MK.TalkStep(-d, false) return end   -- the talks: the amount
  if S.want ~= nil or S.dialog or S.match or S.dock or S.talk then return end
  -- off the hub: the wheel moves the list's cursor (Convocatoria, the setup rows: up / down; the club pick: its clubs)
  if S.mode == "wcsquad" or S.mode == "setup" then Move(0, d) return end
  if S.mode == "pick" then Move(d, 0) return end
  if S.mode ~= "hub" then return end
  local id = (Tabs()[S.tab] or {}).id
  if S.mk.fp then
    MK.FilterInput("move", 0, d)
    return
  end
  if S.mk.pv and id == "market" then
    MK.ViewInput("move", 0, d)
    return
  end
  if id == "market" then
    local moved
    if S.mk.focus == "squad" then
      S.mk.menu = false
      moved = MK.SquadSelect(S.mk.ssel + d * 8)
    elseif S.mk.sec == 2 then
      moved = MK.SaleSelect(S.mk.osel + d * 8)
    else
      moved = MK.Select(S.mk.sel + d * MK.ROWS)
    end
    if moved then
      Snd(SND.MOVE)
      S.dirty = true
    end
    return
  end
  if id == "calendar" then
    if CAL.Month(d) then
      Snd(SND.MOVE)
      S.dirty = true
    end
    return
  end
  if id == "competition" then
    -- over the stats panel (or no pointer there): the stats list scrolls; over the table: the table's cursor
    local okp, px = pcall(funcLuaMenuCommand, C.POINTER)
    local t = TableNow()
    if t and t.kind ~= "bracket" and t.kind ~= "worldcup" and not (okp and type(px) == "number" and px < STANDINGS.RIGHT.x) then
      if STANDINGS.StatsScroll(d) then
        Snd(SND.MOVE)
        S.dirty = true
      end
      return
    end
    Move(0, d)
    return
  end
  if id ~= "home" then return end
  NewsScroll(d)
end

-- L2 / R2 (d = -1 / 1): the previous / next competition shown
function COMPETITION.Step(d)
  local list = COMPETITION.List()
  if #list < 2 then return end
  local _, index = TableNow()
  local at = 1
  for i, e in ipairs(list) do if e.index == index then at = i end end
  local to = list[(at - 1 + d) % #list + 1]
  Snd(SND.MOVE)
  Want("standings", to.index)
end

-- L2 / R2 on the market: the other section of the bar («Buscar» / «En venta»), its list focused (the talks: a big
-- step; «Torneos»: the competition)
function MK.Cycle(what)
  if S.want ~= nil or S.dialog or S.match or S.dock or S.mode ~= "hub" then return end
  if S.talk then MK.TalkStep(what == "sort" and 1 or -1, true) return end
  if S.mk.fp then MK.FilterInput("step", what == "sort" and 1 or -1) return end
  if S.mk.pv then MK.ViewInput("page", what == "sort" and 1 or -1) return end
  if (Tabs()[S.tab] or {}).id == "competition" then COMPETITION.Step(what == "sort" and 1 or -1) return end
  if (Tabs()[S.tab] or {}).id ~= "market" then return end
  MK.Section((S.mk.sec + (what == "sort" and 0 or #MK.SECTIONS - 2)) % #MK.SECTIONS + 1)
end

-- the bar's section `to` shown and its list focused
function MK.Section(to)
  local k = S.mk
  if to == k.sec and k.focus == "list" then return end
  k.sec, k.focus, k.menu = to, "list", false
  Snd(SND.MOVE)
  S.dirty = true
end

-- «Plantilla»'s next status filter
function MK.SquadFilter(to)
  local k = S.mk
  k.sf, k.ssel, k.sfirst, k.menu = to, 1, 1, false
  Snd(SND.MOVE)
  S.dirty = true
end

-- «Plantilla»'s selection moved to `to` (its rows under the filter) -> true when it moved
function MK.SquadSelect(to)
  local n = #MK.SquadRows()
  if n == 0 then return false end
  to = math.max(1, math.min(n, to))
  if to == S.mk.ssel then return false end
  S.mk.ssel = to
  return true
end

-- «En venta»'s selection moved to `to` -> true when it moved
function MK.SaleSelect(to)
  local n = #MK.SaleRows()
  if n == 0 then return false end
  to = math.max(1, math.min(n, to))
  if to == S.mk.osel then return false end
  S.mk.osel = to
  return true
end

-- the offers received: «En venta» shown, its first offer focused
function MK.JumpOffers()
  local k = S.mk
  k.sec, k.focus, k.osel, k.ofirst, k.menu = 2, "list", 1, 1, false
  Snd(#MK.SaleRows() > 0 and SND.DECIDE or SND.BUZZER)
  S.dirty = true
end

-- X on an offer of «En venta»: «Negociar», the window for the player's asking price (a transfer offer not waiting
-- for an answer; a loan offer has none)
function MK.Negotiate()
  local s = MK.SaleRow()
  if s == nil or not MK.CanNegotiate(s.o) then Snd(SND.BUZZER) return end
  Snd(SND.DECIDE)
  local t = { card = s.r.card, name = s.r.name, value = s.r.value }
  for key, v in pairs(s.o) do t[key] = v end
  MK.TalkOpenSell(t)
  S.dirty = true
end

-- A on the market: «Plantilla»: his options open / a status set; the search: the name's text entry, else back to the
-- results; «Buscar»: the talks (a club's player) or the signing (a free one); «En venta»: the offer accepted after a
-- confirmation
function MK.Accept()
  local k = S.mk
  if k.fp then MK.FilterInput("accept") return end
  if k.pv then return end
  if k.focus == "search" then
    if k.srow == 1 then MK.Keyboard() return end
    MK.FiltersOpen()
    return
  end
  if k.focus == "squad" then
    local r = MK.SquadRow()
    local opts = MK.Options(r)
    if #opts == 0 then Snd(SND.BUZZER) return end
    Snd(SND.DECIDE)
    if not k.menu then
      k.menu, k.opt = true, 1
      for i, o in ipairs(opts) do if o.status == r.status then k.opt = i end end
      S.dirty = true
      return
    end
    local opt = opts[k.opt]
    if opt == nil then return end
    k.menu = false
    Want("mstatus", { r.card, opt.status })
    S.dirty = true
    return
  end
  if k.sec == 2 then
    local s = MK.SaleRow()
    if s == nil then Snd(SND.BUZZER) return end
    Snd(SND.DECIDE)
    local r, o = s.r, s.o
    if o.kind == "loan" then
      S.dialog = { kind = "loanoffer", index = o.offer, title = Tx("MkLoanTitle"), choice = 1,
        buttons = { Tx("Yes"), Tx("No") },
        lines = { Tx("MkLoanLine", r.name, TeamName(o.bidder), DateShort(o.back)), Tx("MkLoanLine2", Money(o.amount)) } }
    else
      S.dialog = { kind = "offer", index = o.offer, title = Tx("MkAcceptTitle"), choice = 1,
        buttons = { Tx("Yes"), Tx("No") }, lines = { Tx("MkAcceptLine", r.name, TeamName(o.bidder), Money(o.amount)) } }
    end
    S.dirty = true
    return
  end
  local r = MarketRow()
  if r == nil then Snd(SND.BUZZER) return end
  Snd(SND.DECIDE)
  if (r.club or 0) ~= 0 then
    MK.TalkOpen(r)
  else
    S.dialog = { kind = "buy", card = r.card, title = Tx("KeyOfferTitle"),
      lines = { Tx("BuyLine1", r.name, Money(r.price)), Tx("BuyLine2", Money(S.mk.data.money - r.price)) } }
  end
  S.dirty = true
end

-- ---- «Ver jugador» inside the market (owner 2026-10-31): the list slides left, the player's page on the right -------

-- the page's state: k.pv = { r = the row shown, src = "list" | "squad", page, slide 0..1, dir 1 (opening) / -1
-- (closing), info = the page's data (MK.ViewInfo) }. Opened by Y on a row; B (or Y) slides it back with the same
-- selection
function MK.ViewOpen(r, src)
  local k = S.mk
  if r == nil then Snd(SND.BUZZER) return end
  k.menu = false
  k.pv = { r = r, src = src, page = 1, slide = k.pv and k.pv.slide or 0, dir = 1 }
  k.pv.info = MK.ViewInfo(r)
  Snd(SND.DECIDE)
  S.dirty = true
end

function MK.ViewClose()
  local pv = S.mk.pv
  if pv == nil then return end
  pv.dir = -1
  Snd(SND.BACK)
  S.dirty = true
end

-- Step: the slide moves while it runs (a few frames, then nothing until the next open / close)
function MK.ViewStep()
  local pv = S.mk.pv
  if pv == nil then return end
  if (pv.dir > 0 and pv.slide >= 1) or (pv.dir < 0 and pv.slide <= 0) then
    if pv.dir < 0 then S.mk.pv = nil S.dirty = true end
    return
  end
  pv.slide = math.max(0, math.min(1, pv.slide + pv.dir / MK.VIEW.FRAMES))
  S.dirty = true
end

-- the slide eased (0 .. 1)
function MK.ViewEase()
  local t = S.mk.pv and S.mk.pv.slide or 0
  return t * t * (3 - 2 * t)
end

-- a move's name (the game's move info: its name text)
function MK.MoveName(move)
  if VRFW_Cmd == nil or VRFW_Cmd.GET_SOCCER_SKILL_INFO == nil then return "" end
  local ok, has, text = pcall(funcLuaCommand, VRFW_Cmd.GET_SOCCER_SKILL_INFO, move, MK.VIEW.SKILL_NAME_FIELD)
  if not (ok and has) then return "" end
  local okn, name = pcall(funcLuaCommand, MK.VIEW.SKILL_NAME, text)
  return okn and type(name) == "string" and name or ""
end

-- a player's page data, asked once when the page shows him: his description and his stats at his level
-- (CMND_CAREERMODE_MARKET_PLAYER), his moves (CMND_VRFW_CARD_LEARNSET: the learn list the team pages show, the 9th
-- slot included) with their names
function MK.ViewInfo(r)
  local info = Call("CMND_CAREERMODE_MARKET_PLAYER", r.card, r.level or 1, Lang()) or {}
  info.moves = {}
  local ok, has, moves, levels = pcall(funcLuaCommand, Crc("CMND_VRFW_CARD_LEARNSET"), r.card)
  if ok and has == true and type(moves) == "table" then
    for i, mv in ipairs(moves) do
      if (mv or 0) ~= 0 then
        info.moves[#info.moves + 1] = { name = MK.MoveName(mv), level = type(levels) == "table" and levels[i] or 0 }
      end
    end
  else
    Log("player page: no learn list for card", r.card)
  end
  return info
end

-- the row the page follows: the selected one of its source list
function MK.ViewRow()
  if S.mk.pv.src == "squad" then return MK.SquadRow() end
  return MarketRow()
end

-- up / down while the page is up: the next player of its list shown
function MK.ViewMove(dy)
  local k, pv = S.mk, S.mk.pv
  local moved
  if pv.src == "squad" then moved = MK.SquadSelect(k.ssel + dy) else moved = MK.Select(k.sel + dy) end
  if not moved then return false end
  MK.ViewShow(MK.ViewRow())
  return true
end

-- another player on the page (his data asked again)
function MK.ViewShow(r)
  local pv = S.mk.pv
  if r == nil or r.card == pv.r.card then return end
  pv.r, pv.info = r, MK.ViewInfo(r)
end

-- the page's page `to` shown (L2 / R2, left / right, a click on its dot)
function MK.ViewPage(to)
  local pv = S.mk.pv
  to = (to - 1) % #MK.VIEW.PAGES + 1
  if to == pv.page then return end
  pv.page = to
  Snd(SND.MOVE)
  S.dirty = true
end

-- every input while the page is up: "move" (dx, dy), "page" (d), "back", "click" (zone)
function MK.ViewInput(what, a, b)
  local pv = S.mk.pv
  if pv.dir < 0 then return end
  if what == "move" then
    if (b or 0) ~= 0 then
      if MK.ViewMove(b) then Snd(SND.MOVE) S.dirty = true end
    elseif (a or 0) ~= 0 then
      MK.ViewPage(pv.page + a)
    end
  elseif what == "page" then
    MK.ViewPage(pv.page + a)
  elseif what == "back" then
    MK.ViewClose()
  elseif what == "click" then
    local zn = a
    if zn == nil then return end
    if zn.kind == "vpage" then
      MK.ViewPage(zn.index)
    elseif zn.kind == "vstep" then
      MK.ViewPage(pv.page + zn.d)
    elseif (zn.kind == "mrow" and pv.src == "list" and MK.Select(zn.index))
        or (zn.kind == "msq" and pv.src == "squad" and MK.SquadSelect(zn.index)) then
      MK.ViewShow(MK.ViewRow())
      Snd(SND.MOVE)
      S.dirty = true
    end
  end
end

-- a text cut into lines of at most px (words kept whole; a text without spaces cut by characters)
function MK.Wrap(s, px, style, sc)
  local out, line = {}, ""
  for word in tostring(s or ""):gmatch("%S+") do
    local try = line == "" and word or (line .. " " .. word)
    if line ~= "" and MK.Width(try, style, sc) > px then
      out[#out + 1] = line
      line = word
    else
      line = try
    end
  end
  if line ~= "" then out[#out + 1] = line end
  local cut = {}
  for _, l in ipairs(out) do
    while MK.Width(l, style, sc) > px do
      local head = Fit(l, px, (tonumber((STYLE[style] or STYLE.body):match("^fs_(%d+)")) or 28) * sc)
      head = head:gsub("…$", "")
      if head == "" then break end
      cut[#cut + 1] = head
      l = l:sub(#head + 1)
    end
    cut[#cut + 1] = l
  end
  return cut
end

-- the player's page, dx px right of its place while it slides in (the look of the team pages' player page): the
-- band with the name, element, position and level; his 3D model (VRFW_ModelCard, asked after the draw) in its box;
-- the paged box (the pages' dots between the L2 / R2 glyphs): «Descripción», «Estadísticas» (his stats at his level),
-- «Supertécnicas» (his learn list with the levels)
function MK.DrawView(dx)
  local k, V = S.mk, MK.VIEW
  local pv = k.pv
  local r, info = pv.r, pv.info or {}
  local X, Y, W, H = V.x + dx, V.y, V.w, V.h
  local team = (r.club or 0) ~= 0 and r.club or nil
  -- the panel right of the model's box only (the model is drawn in the 3D pass: a 2D panel would cover it)
  MK.Panel(X + V.PAD + V.MODEL_W, Y, W - V.PAD - V.MODEL_W, H)
  -- the band
  Quad(L.plate, ART.navy, X, Y, W, V.HEAD_H)
  Text(L.text, Fit(r.name ~= "" and r.name or "-", W - 360, 30), X + 24, Y + V.HEAD_H / 2, "title", 0.95)
  local tags = Tx(POS_TEXT[r.position] or "PosMF")
  if (r.element or 0) > 0 then tags = Tx("Element" .. r.element) .. "  ·  " .. tags end
  Text(L.text, tags, X + W - 190, Y + V.HEAD_H / 2, "body_w", 0.8, "c")
  Text(L.text, Tx("LevelShort", r.level or "-"), X + W - 64, Y + V.HEAD_H / 2, "title_c", 0.9, "c")
  -- the model's box on the left
  local bx, by, bw, bh = X + V.PAD, Y + V.HEAD_H + V.PAD, V.MODEL_W, H - V.HEAD_H - 2 * V.PAD
  if dx == 0 and S.pic ~= nil then
    S.pic_want = { card = r.card, team = team or 0, box = { x = bx, y = by + S.dy, w = bw, h = bh }, fit = true,
      static = true }
  else
    Face(r.card, bx + bw / 2, by + bh / 2, V.FACE, team)
  end
  -- the paged box: its title, the pages' dots, the L2 / R2 glyphs either side (a click on a dot or a glyph: that page)
  local ix0, ix1 = bx + bw + V.PAD, X + W - V.PAD
  local ty = by + V.TITLE_H / 2
  Text(L.text, Tx(V.PAGES[pv.page]), (ix0 + ix1) / 2, ty, "body_c", 0.9, "c")
  local n = #V.PAGES
  local dots_w = n * V.DOT + (n - 1) * V.DOT_GAP
  for i = 1, n do
    local x = (ix0 + ix1) / 2 - dots_w / 2 + (i - 1) * (V.DOT + V.DOT_GAP)
    Quad(L.plate, ART.fill, x, ty + V.DOT_Y, V.DOT, V.DOT_H, 1, nil, i == pv.page and TINT.cut or TINT.rest)
    S.zones[#S.zones + 1] = { x0 = x - V.DOT_GAP / 2, y0 = ty + V.DOT_Y - 10, x1 = x + V.DOT + V.DOT_GAP / 2,
      y1 = ty + V.DOT_Y + V.DOT_H + 10, kind = "vpage", index = i }
  end
  local a, b = ix0 + V.KEY_W / 2, ix1 - V.KEY_W / 2
  if dx == 0 then S.head_prompt = { a = a, b = b, y = ty + S.dy, left = "<CMD_FUNCL2>", right = "<CMD_FUNCR2>" } end
  for _, side in ipairs({ { -1, a }, { 1, b } }) do
    S.zones[#S.zones + 1] = { x0 = side[2] - V.KEY_W / 2, y0 = by, x1 = side[2] + V.KEY_W / 2, y1 = by + V.TITLE_H,
      kind = "vstep", d = side[1] }
  end
  Quad(L.plate, ART.fill, ix0, by + V.TITLE_H + 4, ix1 - ix0, 2, 1, nil, TINT.rest)
  local y = by + V.TITLE_H + V.LINE_STEP
  local page = V.PAGES[pv.page]
  if page == "ViewPageDescription" then
    local lines = MK.Wrap(info.description ~= "" and info.description or "-", ix1 - ix0, "body", V.TEXT_SC)
    for i = 1, math.min(#lines, V.TEXT_LINES) do
      Text(L.text, lines[i], ix0, y + (i - 1) * V.TEXT_STEP, "body", V.TEXT_SC)
    end
  elseif page == "ViewPageStats" then
    local stats = type(info.stats) == "table" and info.stats or {}
    if #stats == 0 then Text(L.text, "-", ix0, y, "item", 0.72) end
    -- a stat a row: its name, its bar (out of info.stat_max), its value
    local tx0, tx1 = ix0 + V.STAT_LABEL_W, ix1 - V.STAT_VALUE_W
    for i, st in ipairs(stats) do
      local sy = y + (i - 1) * V.LINE_STEP
      local value = tonumber(st[2]) or 0
      Text(L.text, Fit(Tx("Stat_" .. tostring(st[1])), V.STAT_LABEL_W - 10, 22), ix0, sy, "label_l", 1.0)
      local fill = (tx1 - tx0) * math.max(0, math.min(1, value / math.max(1, info.stat_max or 1)))
      if fill > 0 then Quad(L.icon, ART.fill, tx0, sy - V.STAT_BAR_H / 2, fill, V.STAT_BAR_H, 1, nil, TINT.navy) end
      Quad(L.plate, ART.fill, tx0, sy - V.STAT_BAR_H / 2, tx1 - tx0, V.STAT_BAR_H, 1, nil, TINT.stripe)
      Text(L.text, tostring(value), ix1 - V.STAT_VALUE_W / 2, sy, "big", 0.72, "c")
    end
  else
    if #(info.moves or {}) == 0 then Text(L.text, "-", ix0, y, "item", 0.72) end
    for i, mv in ipairs(info.moves or {}) do
      local ly = y + (i - 1) * V.MOVE_STEP
      Text(L.text, Fit(mv.name ~= "" and mv.name or "-", ix1 - ix0 - 120, 22), ix0, ly, "item", 0.72)
      if (mv.level or 0) > 0 then Text(L.text, Tx("LevelShort", mv.level), ix1 - 50, ly, "label", 1.0, "c") end
    end
  end
end

-- Y on the market: the search: every filter cleared; «En venta»: the offer refused; else the player's page (closed
-- again while up; «Plantilla»'s open options: closed first)
function MK.Second()
  local k = S.mk
  if k.fp then return end
  if k.pv then MK.ViewInput("back") return end
  if k.focus == "search" then
    Snd(SND.DECIDE)
    MK.Clear(nil)
    MK.Reset()
    S.dirty = true
    return
  end
  local r
  if k.focus == "squad" then
    k.menu = false
    r = MK.SquadRow()
  elseif k.sec == 2 then
    local s = MK.SaleRow()
    if s == nil then Snd(SND.BUZZER) return end
    Snd(SND.DECIDE)
    Want("manswer", { s.o.offer, 0 })
    S.dirty = true
    return
  else
    r = MarketRow()
  end
  MK.ViewOpen(r, k.focus == "squad" and "squad" or "list")
  S.dirty = true
end

-- X on the market: «Plantilla»: the next status filter; «En venta»: «Negociar»; «Buscar»: the filter panel (closed
-- again while open)
function MK.Third()
  local k = S.mk
  if k.focus == "squad" then
    MK.SquadFilter(k.sf % #MK.SQ_FILTERS + 1)
    return
  end
  if k.fp then MK.FilterInput("back") return end
  if k.pv then return end
  if k.sec == 2 then MK.Negotiate() return end
  MK.FiltersOpen()
end

-- the arrows on the market -> true when something changed. «Plantilla»: up / down a player (an option while his
-- menu is open), right: the section's list; «Buscar»: up / down a row (up from the first: the search bar), left:
-- «Plantilla»; the search bar: left / right the name / the filter button, down: the list; the filter panel: up / down
-- a row, left / right its value; «En venta»: up / down an offer, left: «Plantilla»
function MK.Move(dx, dy)
  local k = S.mk
  if k.fp then
    MK.FilterInput("move", dx, dy)
    return false
  end
  if k.pv then
    MK.ViewInput("move", dx, dy)
    return false
  end
  if k.focus == "search" then
    if dx ~= 0 then
      local to = math.max(1, math.min(2, k.srow + dx))
      if to == k.srow then return false end
      k.srow = to
      return true
    end
    if dy > 0 then
      k.focus = "list"
      return true
    end
    return false
  end
  if k.focus == "squad" then
    if k.menu then
      local n = #MK.Options(MK.SquadRow())
      if dx == 0 or n == 0 then return false end
      k.opt = (k.opt - 1 + dx) % n + 1
      return true
    end
    if dx > 0 then
      k.focus = "list"
      return true
    end
    if dy ~= 0 then return MK.SquadSelect(k.ssel + dy) end
    return false
  end
  if dx < 0 then
    k.focus = "squad"
    return true
  end
  if k.sec == 2 then return dy ~= 0 and MK.SaleSelect(k.osel + dy) end
  if dy < 0 and k.sel <= 1 then
    k.focus, k.srow = "search", 1
    return true
  end
  if dy ~= 0 and k.data then return MK.Select(k.sel + dy) end
  return false
end

-- the pointer over «Plantilla» or «En venta»: a row selected (focused), an option of the open menu focused -> true
-- when changed
function MK.Hover(zn)
  local k = S.mk
  if zn.kind == "mopt" then
    if k.focus == "squad" and k.menu and zn.index ~= k.opt then
      k.opt = zn.index
      return true
    end
    return false
  end
  if zn.kind == "msale" then
    if k.focus == "list" and zn.index == k.osel then return false end
    k.focus, k.osel = "list", zn.index
    return true
  end
  if k.focus == "squad" and zn.index == k.ssel then return false end
  if zn.index ~= k.ssel then k.menu = false end
  k.focus, k.ssel = "squad", zn.index
  return true
end

-- a click on the market's zones (py: the pointer's y, for the scroll bar)
function MK.Click(zn, py)
  local k = S.mk
  if k.pv then MK.ViewInput("click", zn) return end
  if zn.kind == "mrow" then
    -- the selected row: A; another one: selected
    k.focus = "list"
    if zn.index == k.sel then Accept() elseif MK.Select(zn.index) then Snd(SND.MOVE) S.dirty = true end
  elseif zn.kind == "msale" then
    if k.focus == "list" and zn.index == k.osel then
      Accept()
    else
      k.focus, k.osel = "list", zn.index
      Snd(SND.MOVE)
      S.dirty = true
    end
  elseif zn.kind == "msq" then
    if k.focus == "squad" and zn.index == k.ssel then
      if k.menu then
        k.menu = false
        Snd(SND.BACK)
        S.dirty = true
      else
        Accept()
      end
    else
      k.focus, k.ssel, k.menu = "squad", zn.index, false
      Snd(SND.MOVE)
      S.dirty = true
    end
  elseif zn.kind == "mopt" then
    k.focus, k.opt = "squad", zn.index
    Accept()
  elseif zn.kind == "msf" then
    if zn.index ~= k.sf then MK.SquadFilter(zn.index) end
  elseif zn.kind == "msec" then
    MK.Section(zn.index)
  elseif zn.kind == "mbar" then
    k.sec, k.focus, k.srow, k.menu = 1, "search", 1, false
    MK.Keyboard()
    S.dirty = true
  elseif zn.kind == "mfbtn" then
    MK.FiltersOpen()
  elseif zn.kind == "mscroll" and k.data and (k.data.total or 0) > 0 then
    local at = math.max(0, math.min(1, (py - zn.top) / math.max(1, zn.h)))
    if MK.Select(1 + math.floor(at * (k.data.total - 1) + 0.5)) then Snd(SND.MOVE) S.dirty = true end
  end
end

-- ---- menu callbacks ----------------------------------------------------------------------------------------------------


function OnInit()
  MENU = Crc("evt_career_menu")
  L = { panel = Crc("career_panel"), plate = Crc("career_plate"), icon = Crc("career_icon"), team = Crc("career_team"),
    face = Crc("career_face"), text = Crc("career_text"), dialog = Crc("career_dialog"),
    dtext = Crc("career_dialog_text"), ground = Crc("career_news_ground"), ghost = Crc("career_news_ghost") }
  L_KEYS = Crc("career_keys")
  HOME.L_PROMPTS = Crc("career_prompts")
  HOME.L_SWITCH = Crc("career_switch")
  FN = { [Crc("career_accept")] = Accept, [Crc("career_up")] = function() Move(0, -1) end,
    [Crc("career_down")] = function() Move(0, 1) end, [Crc("career_left")] = function() Move(-1, 0) end,
    [Crc("career_right")] = function() Move(1, 0) end, [Crc("career_prev")] = function() Turn(-1) end,
    [Crc("career_next")] = function() Turn(1) end, [Crc("career_redraw")] = Second, [Crc("career_x")] = Third, [Crc("career_click")] = Click,
    [Crc("career_news_up")] = function() NewsFeed(-1) end, [Crc("career_news_down")] = function() NewsFeed(1) end,
    [Crc("career_l2")] = function() MK.Cycle("filter") end, [Crc("career_r2")] = function() MK.Cycle("sort") end }
  POINTER.KEY.A, POINTER.KEY.B, POINTER.KEY.X, POINTER.KEY.Y = Accept, Back, Third, Second
  S.ready, S.frame, S.dirty, S.mode, S.closing, S.match = false, 0, true, "loading", false, false
  S.sent, S.used, S.shown, S.opened, S.cap, S.texts, S.emb, S.names, S.kits = {}, {}, {}, {}, {}, {}, {}, {}, {}
  S.rate, S.queue, S.clubs, S.club_want, S.tab, S.apply, S.applied = {}, {}, {}, nil, 1, {}, {}
  S.mk = { pos = 1, sort = 1, first = 1, sel = 1, data = nil, focus = "list", srow = 1, cfirst = 2,
    sf = 1, ssel = 1, sfirst = 1, menu = false, opt = 1, sq = nil, sec = 1, osel = 1, ofirst = 1,
    q = { name = "", club = 0, lmin = nil, lmax = nil, price = 0, series = 0, free = false, afford = false } }
  S.caps = VRFW_TabBarCaps ~= nil and VRFW_TabBarCaps.New() or {}
  S.prompts = VRFW_TabBarCaps ~= nil and VRFW_TabBarCaps.New() or {}
  S.switch = VRFW_TabBarCaps ~= nil and VRFW_TabBarCaps.New() or {}
  S.button, S.buttons = 1, {}
  S.pic = type(VRFW_ModelCard) == "table" and VRFW_ModelCard.New({ layer = Crc("career_news_model"),
    backdrop = Crc("career_backdrop"), hide = { Crc("mainmenu90_00_background") }, log = Log }) or nil
  local okr, root = pcall(funcLuaMenuCommand, 2119959601 --[[this menu is the menu scene's root]])
  S.root = okr and root == true
  Log("opened", S.root and "as its menu scene's root" or "over the title")
  -- a scene root fades itself in, as the game's own root menus do (the straight reset into it left the screen black)
  if S.root then
    pcall(funcLuaCommand, 609722083 --[[screen fade]], 0, 0.3)
    Log("scene root: fade in")
  end
  Want("state")
end

function OnSetupLayer(a1, a2)
  if a1 == HEADER.LAYER then
    if SetupSoccerTopCommonHeaderLayerInfo then
      SetupSoccerTopCommonHeaderLayerInfo(a1, 4153539961, 253801632, 3969848060, 1144161661, 3293713115, 253801632, 1152304044, 305955024, 3007971317)
    end
    if SwapSoccerTopCommonHeaderMenuModeIconTexture then
      SwapSoccerTopCommonHeaderMenuModeIconTexture(Crc("mode_base04"))
    end
    if UpdateHeader then
      UpdateHeader(3586861540)
    end
    M(C.SET_TEXT, a1, HEADER.SUB_TITLE, Tx("Title"))
  elseif a1 == L_ANCHOR then
    for _, node in ipairs(ANCHOR.TEXTS) do M(C.SET_TEXT, a1, node, "", a2) end
    for _, mesh in ipairs(ANCHOR.MESHES) do M(C.MESH_VISIBLE, a1, mesh, false, a2) end
    M(C.ALPHA, a1, a2, 0, 0)
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
    for _, mesh in ipairs(ANCHOR.MESHES) do M(C.MESH_VISIBLE, L_ANCHOR, mesh, false, 0) end
    M(C.ALPHA, L_ANCHOR, 0, 0, 0)
    for _, layer in pairs(L) do
      local n = M(C.LAYER_NUM, layer)
      S.cap[layer] = type(n) == "number" and n or 0
    end
    UNDER.Hide(true)
    S.ready = true
    S.dirty = true
    if S.root then Log("scene root: screen ready") end
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
  if S.pic then
    if S.match then S.pic.Want(nil) end
    local okp, errp = pcall(S.pic.Step)
    if not okp and not S.pic_error then
      S.pic_error = true
      Log("model card error", tostring(errp))
    end
  end
  if S.closing then
    if S.close_after_release then
      if KEPT.Step() then return end
      S.close_after_release, S.closing = nil, false
      Close()
      return
    end
    if S.close_at and (S.pic.Released() or S.frame - S.close_at > CLOSE_WAIT) then
      S.close_at = nil
      CloseScreen()
    end
    return
  end
  DockStep()
  MK.ViewStep()
  if S.kb then MK.KeyboardStep() end
  Fetch()
  if S.dock_now then
    S.dock_now = nil
    DockStep()
  end
  FetchClub()
  if #S.apply > 0 then ApplySome() else RateSome() end
  if VRFW_FaceIcon ~= nil and VRFW_FaceIcon.Pending() then VRFW_FaceIcon.Settle() end
  if S.caps.pending then VRFW_TabBarCaps.Step(S.caps, CAP_SPEC) end
  if S.prompts and S.prompts.pending then VRFW_TabBarCaps.Step(S.prompts, HOME.PROMPT_SPEC) end
  if S.switch and S.switch.pending then VRFW_TabBarCaps.Step(S.switch, HOME.SWITCH_SPEC) end
  HOME.WalkStep()
  PointerHover()
  NewsStep()
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
    -- the drawn ball's card: drawn again only when its fade step changes
    local before = G.POTS.CardAlpha(S.pots.flash)
    S.pots.flash = S.pots.flash - 1
    if G.POTS.CardAlpha(S.pots.flash) ~= before then S.dirty = true end
  end
  if not S.ready then return end
  -- a draw when something changed; between draws only the cursor bobs
  if S.dirty then
    S.dirty = false
    local ok, err = pcall(Draw)
    if not ok then Log("draw error", tostring(err)) end
  else
    CursorBob()
  end
end
