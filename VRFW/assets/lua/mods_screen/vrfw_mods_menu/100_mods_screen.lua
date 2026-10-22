-- mods_menu (VR-Framework): the «Mods» screen (menu vrfw_mods_menu, opened from the title menu):
-- a mod manager (tabs, a one-column list of mods, search / filter / sort, an info panel and a page per mod, a profile)
-- in the look of the game's menus. Own code; runs in the VM of the stub script (menu/vrfw_mods_menu.lua of the mod)
-- and replaces its callbacks.
--
-- Screen (setting built at boot by the mods_menu plugin from the player's own «Guardar» screen,
-- crates/plugins/mods_menu/src/screen.rs): retail background, header, button guides and return arrow; one retail list
-- row off screen = the INPUT ANCHOR (it holds the engine's focus: every key comes here as OnFunction / OnEnter /
-- OnBack); everything else is drawn here on free layers:
--   vrfw_mm_q0 / _q2 / _q1  quads of the screen's atlas (vrfw_mm_ui.g4tx), back to front: boxes and bars, list plates,
--                           badges / icons / tags (two quads of one layer have no fixed order)
--   vrfw_mm_card            the retail photo frame of the album (kept for other mods' pages; the list does not use it)
--   vrfw_mm_tl / _tc / _tr  texts (left / centre / right)
--   vrfw_mm_pd, _p0, _p1    popup: dim, window, its quads;  vrfw_mm_pl / _pc / _pr: its texts
-- Layout: the title tab («Instalados», top-level mods only) and under it the search box, «Ver», «Orden», «Perfil»; the
-- list of mods (one plate a mod: load number, icon, name, version · size · author, the state tag) in a navy box at the
-- left, in load order by default (switched-on mods by number, then the others); the selected mod's info panel at the
-- right (header bar, icon and fields, description, «Necesita», «Lo necesitan»). Module mods are rows of their parent's
-- page: they load right after their parent and move with it. L1 / R1 set the load order from this list.
-- The screen has no in-game creators; content is edited in an external editor.
-- Keys (pad / keyboard): up / down move (left / right a page); A: switch the mod on / off; Start (Alt): the mod's
-- page (layout A: information, modules, problems, conflicts, settings, what's new); L1 / R1 (Z / C): load order; L2 / R2 (Q / E): tabs; Select (Tab):
-- sort; L3 (B): filter; R3 (N): search; X: profile; Y (V): the key of another framework part (VRFW_MM_EXTRA:
-- «Novedades»); B / Esc / right click: back. Mouse: hover selects, click = the thing under the pointer (a row opens
-- its page, its state tag switches it, tabs, bars, the panel's «Detalles», the page's buttons), the wheel scrolls.
-- Data: the ModLoader's CMND_EVT_MODS_* (module mods); texts and pictures: the plugin's CMND_VRFW_MM_*. Every change is a file in <game>\mods and applies at the next start. No engine call at load time.

-- CRC32 of a name / path. Every drawing hashes the same few hundred strings again (sprite names, textures, the
-- pictures of a list): each is computed once (bit by bit in Lua it costs ~1000 bit32 calls per path)
local Crc
do
  local memo = {}
  local function of(s)
    local crc = 0xFFFFFFFF
    for i = 1, #s do
      crc = bit32.bxor(crc, string.byte(s, i))
      for _ = 1, 8 do
        if bit32.band(crc, 1) ~= 0 then
          crc = bit32.bxor(bit32.rshift(crc, 1), 0xEDB88320)
        else
          crc = bit32.rshift(crc, 1)
        end
      end
    end
    return bit32.bxor(crc, 0xFFFFFFFF)
  end
  Crc = function(s)
    local v = memo[s]
    if v == nil then
      v = of(s)
      memo[s] = v
    end
    return v
  end
end

-- functions used before their definition (locals: nothing of this screen leaks into the menu VM's globals, where
-- the retail includes live)
local Draw, StartCo, SwitchTab, ProfileFlow, SearchFlow, CycleFilter, CycleSort, SelectMod, OpenDetails, Toggle
local Order, ClosePopup, RunExtra, PadDecide, PopupButtons

-- the menu this VM is: our own row, or the row of another mod's «Mods» screen ([screen] serve_registry); set again in
-- OnInit from CMND_VRFW_MM_STATE
local MENU = Crc("vrfw_mods_menu")
-- the base mod (evt_modfmt::BASE_MOD): kept for dependency labels, hidden from the player's mod lists
local BASE = "vr_framework"
local DEBOUNCE = 20              -- frames: one press = one change (the engine can send a late second «decide»)

-- ModLoader (module mods, crates/vr-loader/src/mods/cmds.rs); an old / absent ModLoader: the call fails -> nil
local M = {
  COUNT = Crc("CMND_EVT_MODS_COUNT"),          -- () -> installed, active, skipped, conflicts, dirty, changes, profiles, profile
  GET = Crc("CMND_EVT_MODS_GET"),              -- (i) -> ok, id, name, version, author, priority, enabled, state, lua, files,
                                               --        deltas, applied, pending, pos, size, preview, warnings, level
  GET_TEXT = Crc("CMND_EVT_MODS_GET_TEXT"),    -- (i, what) -> 0 desc / 1 skip reason / 2 requires / 3 conflicts / 7 warnings
                                               --              / 8 tags / 9 date
  SET_ENABLED = Crc("CMND_EVT_MODS_SET_ENABLED"),
  MOVE = Crc("CMND_EVT_MODS_MOVE"),
  PROFILE_NAME = Crc("CMND_EVT_MODS_PROFILE_NAME"),
  PROFILE_SWITCH = Crc("CMND_EVT_MODS_PROFILE_SWITCH"),
  PROFILE_NEW = Crc("CMND_EVT_MODS_PROFILE_NEW"),
  RESCAN = Crc("CMND_EVT_MODS_RESCAN"),
  LOG = Crc("CMND_EVT_LOG"),
  -- the mods_menu plugin (crates/plugins/mods_menu/src/rt.rs)
  TEXT = Crc("CMND_VRFW_MM_TEXT"),              -- (name, language code) -> text
  STATE = Crc("CMND_VRFW_MM_STATE"),            -- () -> title, screen, version, menu (crc32), ...
  THUMB = Crc("CMND_VRFW_MM_THUMB"),            -- (mod id) -> texture path, card sprite, large sprite ("" = none)
  ICON = Crc("CMND_VRFW_MM_ICON"),              -- (mod id) -> texture path, sprite of its mod.toml `icon` ("" = none)
  TEXT_ID = Crc("CMND_VRFW_TEXT_ID"),           -- text_engine: (key) -> id of a new text
  -- the VR-Framework core's report of this start (<data dir>\cache\report.json)
  REPORT_COUNT = Crc("CMND_VRFW_REPORT_COUNT"), -- (mod) -> entries
  REPORT_ROW = Crc("CMND_VRFW_REPORT_ROW"),     -- (i, mod) -> severity, type, code, location, message, mod, key, id, winner, others, category, hint
  REPORT_RELOAD = Crc("CMND_VRFW_REPORT_RELOAD"), -- (mod) -> "type=live|next_load|restart;..."
  -- the conflict explorer of `vrfw who` (vr_core::diagnose::who_in): (id) -> rows, winner; (i) -> mod, load order,
  -- type, file[:line], text, kind (defines | refers | report), wins
  REPORT_WHO = Crc("CMND_VRFW_REPORT_WHO"),
  REPORT_WHO_ROW = Crc("CMND_VRFW_REPORT_WHO_ROW"),
  -- what the audio engine said at boot about a mod (its page): (mod id) -> "<1|0>|<text>" lines
  AU_NOTES = Crc("CMND_VRFW_MM_AU_NOTES"),
  PROVIDES = Crc("CMND_VRFW_MM_PROVIDES"),      -- (mod id) -> its mod.toml `provides`, comma separated ("" = none)
  KEY_ID = Crc("CMND_VRFW_MM_KEY_ID"),          -- (mod name: id, key id or former id) -> key id of that installed mod ("" = none)
  TAG_DEFS = Crc("CMND_VRFW_MM_TAG_DEFS"),      -- () -> how many mod tags the mods declare ([[VRFW.ModTag]])
  TAG_DEF = Crc("CMND_VRFW_MM_TAG_DEF"),        -- (i) -> id, text key
  MOD_TAGS = Crc("CMND_VRFW_MM_MOD_TAGS"),      -- (mod id) -> its tag ids, one per line
  PERMS = Crc("CMND_VRFW_MM_PERMS"),            -- (mod id) -> its native permissions (mod.toml permissions), ", "-joined
  -- (mod id) -> parent ("" = not a module), order, name key, internal modules (option row ids, one per line): the mod
  -- families of mod.toml [module] / [modules]
  MODULE = Crc("CMND_VRFW_MM_MODULE"),
  FOLDER = Crc("CMND_VRFW_MM_FOLDER"),          -- (mod id) -> its folder under mods\, "/"-separated ("" = unknown)
  NOTES = Crc("CMND_VRFW_MM_NOTES"),            -- (mod id, language code) -> title, notes of its changelog summary
}
-- the screen's background: the retail Guardar one (screen.rs BG_LAYER), hidden until the first full drawing shows it
-- with the content (CE.Ready) and asserted again whenever the page changed or a window / keyboard closed (CE.bg_dirty)
local BG = {LAYER = 367379312 --[[mainmenu90_00_background]], on = nil, page = nil}
-- the screen's helpers (a table: the main chunk is near Lua's 200-locals limit)
local CE = {}
-- the game's keyboard (the same calls as the avatar name screen): open (…), busy, typed text, close
local KB = {OPEN = 962493425, BUSY = 422535539, RESULT = 1487869455, CLOSE = 3351189333}
-- the retail keyboard title «Buscar» when this mod's is not in menu_text
local RT_SEARCH = 1354833040

-- retail layers of the frame
local L_BASE = Crc("save01_01_list_attach_base")
local L_ROW = Crc("save01_02_list_item")          -- the input anchor (1 instance, off screen)
local L_HEADER = Crc("mainmenu90_01_header")
local L_CURSOR = Crc("cmn05_01_cursor")
local L_BTN_GUIDE = Crc("mainmenu01_06_base_button_guide")
local L_BTN = Crc("mainmenu01_07_button_guide")
local L_RET = Crc("mainmenu01_10_return_arrow_button_guide")
-- free layers (screen.rs FREE): name -> instances
local FREE = {
  Q0 = {Crc("vrfw_mm_q0"), 80}, CARD = {Crc("vrfw_mm_card"), 16}, Q2 = {Crc("vrfw_mm_q2"), 48}, Q1 = {Crc("vrfw_mm_q1"), 144},
  TL = {Crc("vrfw_mm_tl"), 128}, TC = {Crc("vrfw_mm_tc"), 96}, TR = {Crc("vrfw_mm_tr"), 40},
  PD = {Crc("vrfw_mm_pd"), 1}, P0 = {Crc("vrfw_mm_p0"), 24}, P1 = {Crc("vrfw_mm_p1"), 40},
  PL = {Crc("vrfw_mm_pl"), 40}, PC = {Crc("vrfw_mm_pc"), 28}, PR = {Crc("vrfw_mm_pr"), 8},
}
-- the layers of THIS menu (set up with it, counted by the reveal, hidden by Finish)
local FREE_ORDER = {"Q0", "CARD", "Q2", "Q1", "TL", "TC", "TR", "PD", "P0", "P1", "PL", "PC", "PR"}
local N = {
  ROW_ON = Crc("_text_list01_on"), ROW_OFF = Crc("_text_list01_off"),
  ROW_MESHES = {Crc("_list_icon_dmy_s01_on"), Crc("_list_icon_dmy_s01_off"), Crc("_list_icon_dmy_s01_ok"), Crc("_list_base_s01_ok"),
                Crc("_list_base_s01_on"), Crc("_list_base_s01_off"), Crc("_list_base_s01_ol")},
  BASE_TIME = Crc("_text_time01"), BASE_MESHES = {Crc("_system_line01"), Crc("_comma01"), Crc("_comma02")},
  SUB_TITLE = 1220590795,          -- _text_sub_title02 of the header
  CURSOR = Crc("cursor"), FOCUS = Crc("Focus"), ACTIVE = Crc("Active"), BUTTON = Crc("button"),
  QUAD = Crc("icon_new01"),        -- the cmn01_10 quad's sprite (the name its material uses)
  PHOTO = Crc("img_photo_dmy01"),  -- the photo frame's picture sprite
  PHOTO_RING = Crc("_photo_focus01"), PHOTO_PIN = Crc("_icon_photo_pin01"), PHOTO_FAV = Crc("_icon_photo_favorite01"),
  PHOTO_OK = Crc("_photo_frame_s01_ok"),   -- the album's «chosen» overlay (an opaque cyan plate): always hidden
  TEXT = Crc("_text_guide01"),     -- the text node of the text layers
  BAND = Crc("_vs_top_guide_base01_line01"),   -- the retail band of the text layers (hidden)
}
N.BASE_PRIMS = {1162845628, 3567142029, 3057999962}

-- the screen's atlas (crates/plugins/mods_menu/src/atlas.rs) and its sprites
local ATLAS = Crc("#/menu/vrfw_mods/vrfw_mm_ui.g4tx")
local function SP(name)
  return Crc("vrfw_mm_" .. name)
end
local NTILES = 8

local C = {
  TEXT = 1083631230,          -- CMND_SET_MENU_TEXT_STRING (layer, node, string, idx)
  TEXT_GET = 4074371074,      -- CMND_TEXT_GET (id) -> string
  LANG = 477234096,           -- CMND_GET_LANGUAGE_CODE
  MESH_VISIBLE = 3405944500,  -- (layer, mesh, bool, idx)
  PRIM_VISIBLE = 1233047821,  -- (layer, idx, prim, bool)
  LAYER_VISIBLE = 711242136,  -- (layer, idx, bool)
  POS = 1389957207,           -- CMND_SET_LAYER_LOCAL_POS (layer, x, y, z, idx); layout units, y up
  SCALE = 3778714801,         -- CMND_SET_LAYER_LOCAL_SCALE (layer, sx, sy, sz, idx)
  SPRITE = 558735651,         -- (layer, texture crc, sprite crc, sprite slot crc, 0, idx)
  LOAD_TEX = 839427544,       -- CMND_LOAD_MENU_RES_TEXTURE (path)
  ALPHA = 4231609516,         -- CMND_SET_LAYER_MODEL_ALPHA (layer, idx, 0, alpha)
  ATTACH_TRACE = 1774843228,  -- (layer, idx, locator, bool)
  OPEN_LAYER = 629267548,
  ANIME = 3781155141,         -- CMND_PLAY_ANIME_TYPE (layer, idx, type, 0 in / 2 out, set)
  CTRL = 3518307824,          -- CMND_SET_ENABLE_CTRL_FOCUS (layer, bool)
  FOCUS_SET = 3466097042,     -- (layer, idx)
  LIST_NUM = 3252599449,      -- (layer, count)
  GUIDE_SET = 2209673388,     -- button guide (menu, layer, texts, icons, offsets, {}, {})
  GUIDE_CMD = 452337289,      -- button guide inputs (menu, layer, inputs)
  SE = 1917805374,
  MENU_ACTIVE = 1558704558,   -- (menu, bool)
  CLOSE_MENU = 320421347,     -- CMND_CLOSE_MENU_OBJECT
  FADE = 609722083, FADE_DONE = 2259183189,
  MSG_OPEN = 2289627655, MSG_KIND = 2351835063, MSG_RESULT = 1523741473, MSG_DONE = 682363669, MSG_BUSY = 898725220,
  TEX_LOADING = 1506186496,   -- (texture crc) -> true while still loading (kizuna_town_menu_inc)
  -- the mouse, read here (the engine does not send hover to free layers)
  MOVED = 3272825600,         -- funcLuaMenuCommand () -> the mouse moved this frame
  POINTER = 558229292,        -- funcLuaMenuCommand () -> x, y (screen px, y down)
  CHECK_INPUT = 4265778440, MENU_CTRL = 1332654303, CLICK = 1651523701,  -- CMND_CHECK_INPUT_CMD(MENU_CTRL, CMD_ENTER_CLICK)
  ENTER = 1981080283,         -- CMD_ENTER (A / Enter) for the same poll
  LEFT = 218912913,           -- CMD_EVT_MOUSE_LEFT: the mouse's left button alone (CMD_ENTER_CLICK also fires on Enter / A)
  W_UP = 1942756954, W_DOWN = 1623431741,   -- CMD_EVT_WHEEL_UP / _DOWN
}
local FN = {UP = Crc("vrfw_mm_up"), DOWN = Crc("vrfw_mm_down"), LEFT = Crc("vrfw_mm_left"), RIGHT = Crc("vrfw_mm_right"),
            ORDER_UP = Crc("vrfw_mm_order_up"), ORDER_DOWN = Crc("vrfw_mm_order_down"),
            TAB_PREV = Crc("vrfw_mm_tab_prev"), TAB_NEXT = Crc("vrfw_mm_tab_next"), DETAILS = Crc("vrfw_mm_details"),
            SORT = Crc("vrfw_mm_sort"), FILTER = Crc("vrfw_mm_filter"), SEARCH = Crc("vrfw_mm_search"),
            PROFILE = Crc("vrfw_mm_profile"),
            EXTRA3 = Crc("vrfw_mm_extra3")}   -- FUNC3: a key of another framework part (VRFW_MM_EXTRA below)
local SE_OK, SE_BACK, SE_NG, SE_MOVE = 3848881948 --[[sy0000]], 202039849, 2086672038 --[[sy0003]], 2500047763 --[[sy0005]]
-- button guide icons (retail menu_text ids of the key glyphs) and inputs
local I_ENTER, I_L1, I_R1, I_F4, I_F1 = 2750714971 --[[<CMD_ENTER>]], 3020352056 --[[<CMD_FUNCL1>]], 1596629152 --[[<CMD_FUNCR1>]],
                                        1097287577 --[[<CMD_FUNC4>]], 203473330 --[[<CMD_FUNC1>]]
-- retail texts used when this mod's guide labels are not in menu_text (no text_engine): «ON» / «OFF», «Move»
local RT_ON, RT_OFF, RT_MOVE = 2951736153, 3639139279, 875903600
local G_ACCEPT = 1847312674 --[[«Aceptar»]]
-- key glyphs inside our texts (the game draws them like in its own strings)
local K = {A = "<CMD_ENTER>", B = "<CMD_BACK>", L1 = "<CMD_FUNCL1>", R1 = "<CMD_FUNCR1>", L2 = "<CMD_FUNCL2>",
           R2 = "<CMD_FUNCR2>", START = "<CMD_FUNC1>", SELECT = "<CMD_FUNC2>", Y = "<CMD_FUNC3>", X = "<CMD_FUNC4>",
           L3 = "<CMD_FUNC5>", R3 = "<CMD_FUNC6>", LEFT = "<CMD_LEFT>", RIGHT = "<CMD_RIGHT>"}

-- ---- geometry (screen px, y down) -------------------------------------------------------------------------------------
local G = {
  -- Every y below is laid out for the RETAIL header (mainmenu90_01: blue bar 0-122 px + shadow to 145;
  -- the top row sat half under it). A mod that restyles the header moves the whole screen with the global
  -- VRFW_MM_LAYOUT = {top_dy = n} (read in OnInit, CE.ApplyLayout): e.g. top_dy = -55, the layout of the
  -- short header (bar 67 px). The keys moved are G.SHIFT_Y.
  -- the tab bar (Q, tabs, E) at the top left; under it the search box (the mod count inside) and «Ver», «Orden»,
  -- «Perfil»; the restart notice above the panel, right of the header
  TABBAR_X = 0, TABBAR_W = 990,
  TAB_X = 55, TAB_Y = 137, TAB_W = 270, TAB_H = 50, TAB_STEP = 270,
  TOOLS_Y = 202, TOOLS_H = 42,
  ROW_SEARCH_X = 25, ROW_SEARCH_W = 397, ROW_FILTER_X = 447, ROW_FILTER_W = 172, ROW_SORT_X = 627, ROW_SORT_W = 194,
  PROF_X = 828, PROF_Y = 202, PROF_W = 204, PROF_H = 42,
  NOTICE_X = 1260, NOTICE_Y = 104, NOTICE_W = 620, NOTICE_H = 40,
  -- the list of mods (both tabs, and a list page): one plate a row in a navy box; the box ends above the button
  -- guide whatever the header (BOX_BOTTOM is not moved), so LIST_ROWS is counted in CE.ApplyLayout
  BOX_X = 0, BOX_Y = 260, BOX_W = 1000, BOX_BOTTOM = 1003, BOX_PAD = 15, BOX_R = 14,
  LIST_X = 22, LIST_Y = 275, ROW_W = 950, ROW_H = 46, ROW_STEP = 50, LIST_ROWS = 14,
  COLS = 1,                  -- «Instalados» is one column (ui.sel / ui.top count rows)
  SB_X = 980, SB_W = 6,
  -- the info panel of the selected mod: its header bar (stripes, name, version), the white body under it
  PANEL_X = 1040, PANEL_Y = 151, PANEL_W = 864, PANEL_HEAD = 54, PANEL_BODY_Y = 225, PANEL_BODY_H = 612, PANEL_H = 686,
  PANEL_R = 14,
  WIN_X = 240, WIN_Y = 138, WIN_W = 1440, WIN_H = 832,
  DIM_ALPHA = 0.55,          -- the dim behind a mod's page: the Mods list still shows through
  COVER_W = 256, COVER_H = 144,   -- a mod's page: its cover (16:9) in the header band
  BAND_H = 184, VTABS_H = 56, FOOT_H = 64,   -- a mod's page: header band, view tabs, shortcut bar
  Q = 36,                    -- the cmn01_10 quad side
  TXT_X = 48, TXT_Y = 915, TXT_W = 800, TXT_MID = 949,   -- the text node of the text layers (mainmenu90_05)
  PX = 14.5,                 -- width of one Latin character at text scale 1 (28 px font)
  -- tabs: one list («Instalados», in load order by default, where the load order is also set)
  NTABS = 1,
  -- the top-anchored y keys a header mod's top_dy moves (CE.ApplyLayout); WIN_Y (popups) and TXT_Y stay
  SHIFT_Y = {"TAB_Y", "TOOLS_Y", "PROF_Y", "NOTICE_Y", "BOX_Y", "LIST_Y", "PANEL_Y", "PANEL_BODY_Y"},
}

-- ---- state --------------------------------------------------------------------------------------------------------------
local have = false          -- the ModLoader answers CMND_EVT_MODS_COUNT
local mods = {}             -- visible CMND_EVT_MODS_GET rows, load order (top = highest priority)
local base_mod = nil        -- framework metadata, never a card or load-order row
local cnt = {installed = 0, mods = 0, active = 0, changes = 0, profiles = 1, profile = 0}
local profiles = {}
local ui = nil              -- see Reset()
local changed = false
local co = nil
local frame, last_act = 0, -1000
local lang = nil
local extras = nil
local text_ids = {}
local tex_asked, tex_wait, tex_frames = {}, false, 0
local mouse = {on = false, x = -1, y = -1, logs = 0}
local dirty = false          -- a free layer was set up again by the engine: draw again at the next Step
local decided = false        -- one decide per frame (a click / Enter may reach OnEnter and the poll)
local hits = {}              -- mouse zones of the last drawing: {x0, y0, x1, y1, id, act}
local DEBUG_EVENTS = 60      -- the first input events of each visit go to loader.log («mods_menu», «input», …)
local dbg = 0

local FILTERS = {"all", "on", "off", "warn", "pending"}
local SORTS = {"order", "name", "size", "date"}

local function Reset()
  ui = {
    tab = 1,                 -- 1 Instalados, 2 Orden de carga
    zone = "grid",           -- Instalados: "grid" | "bar" (search, filter, sort)
    bar = 1,                 -- 1 search, 2 filter, 3 sort
    sel = 1, top = 0,        -- grid: selected card (1-based in the shown list), first row shown (0-based)
    osel = 1, otop = 1,      -- load order list
    query = "", filter = 1, sort = 1,
    popup = nil,             -- {kind = "mod", id = …, btn = 1}
    page = nil,              -- a list page («¿Quién lo toca?»): {kind = "list", …}
    toast = nil, toast_t = 0,
  }
end
Reset()

-- ---- helpers ------------------------------------------------------------------------------------------------------------
local function Call(cmd, ...)
  local r = table.pack(pcall(funcLuaCommand, cmd, ...))
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2, r.n)
end

local function Log(...)
  Call(M.LOG, "mods_menu", ...)
end

local function Trace(...)
  if dbg < DEBUG_EVENTS then
    dbg = dbg + 1
    Log("input", ...)
  end
end

local function Int(v)
  return type(v) == "number" and math.floor(v + 0.5) or 0
end

local function Str(v)
  return type(v) == "string" and v or ""
end

-- text `name` of the mod's text.toml in the game's language, {x} filled from vars
local function T(name, vars)
  if lang == nil then
    lang = Call(C.LANG) or 1
  end
  local s = Str(Call(M.TEXT, name, lang))
  if s == "" then
    s = name
  end
  if vars ~= nil then
    s = string.gsub(s, "{(%a+)}", function(k)
      local v = vars[k]
      return v == nil and ("{" .. k .. "}") or tostring(v)
    end)
  end
  return s
end

-- id of a text of this mod in menu_text (button guides need ids): text_engine's id, else crc32("mods_menu.<name>");
-- nil when the game has no such text (then the guide uses a retail text or leaves the entry out)
local function TextIdKey(key)
  if text_ids[key] ~= nil then
    return text_ids[key] or nil
  end
  local id = Call(M.TEXT_ID, key)
  if type(id) ~= "number" or id == 0 then
    id = Crc(key)
  end
  local s = Call(C.TEXT_GET, id)
  if type(s) == "string" and s ~= "" then
    text_ids[key] = id
    return id
  end
  text_ids[key] = false
  return nil
end

local function TextId(name)
  return TextIdKey("mods_menu." .. name)
end

-- Keys other parts of the framework add to this screen: global VRFW_MM_EXTRA, a list of
--   {fn = <CMD_FUNCTION id>, icon = <button guide icon>, cmd = <crc32 of the input>, key = "<part>.<text>",
--    available = function() -> bool, flow = function(menu) -> true | false (false = nothing to show: error sound)}
-- set by the part's own Lua in this VM (the changelog part: FUNC3 «Novedades»). `flow` runs as this screen's
-- coroutine (it may open another menu and wait); the screen's input is its to switch off and on.
local function Extras()
  if extras == nil then
    extras = {}
    if type(VRFW_MM_EXTRA) == "table" then
      for _, e in ipairs(VRFW_MM_EXTRA) do
        local ok, avail = pcall(function() return e.available == nil or e.available() end)
        if type(e) == "table" and type(e.flow) == "function" and ok and avail then
          extras[#extras + 1] = e
        end
      end
    end
  end
  return extras
end

local function ExtraFor(id)
  for _, e in ipairs(Extras()) do
    if e.fn == id then
      return e
    end
  end
  return nil
end

-- UTF-8 characters with width units (1 Latin, 2 CJK); an inline icon tag [$gaiji_...] is one unit-2 piece (never cut)
local function Chars(s)
  local out, i, n = {}, 1, string.len(s)
  while i <= n do
    local g = string.match(s, "^%[%$[%w_]+%]", i)
    if g then
      out[#out + 1] = {ch = g, w = 2}
      i = i + string.len(g)
      goto continue
    end
    local b = string.byte(s, i)
    local len = b >= 0xF0 and 4 or (b >= 0xE0 and 3 or (b >= 0xC0 and 2 or 1))
    out[#out + 1] = {ch = string.sub(s, i, i + len - 1), w = (len >= 3) and 2 or 1}
    i = i + len
    ::continue::
  end
  return out
end

-- width units of a text without its markup ([CN] … [C], <CMD_…> = 2 units)
local function Units(s)
  s = string.gsub(s, "%[C%u*%]", "")
  s = string.gsub(s, "<CMD_[%u%d_]+>", "MM")
  local u = 0
  for _, c in ipairs(Chars(s)) do
    u = u + c.w
  end
  return u
end

local function Cut(s, units)
  -- a text never has more width units than bytes: a short one is returned as it is without splitting it; of a long one
  -- (a talk line, a value of a whole row) only its start is measured and split
  if #s <= units then
    return s
  end
  local head = #s > units * 8 + 64 and string.sub(s, 1, units * 8 + 64) or s
  if head == s or Units(head) <= units + 16 then
    if Units(s) <= units then
      return s
    end
  end
  local out, u = {}, 0
  for _, c in ipairs(Chars(head)) do
    if u + c.w > units - 3 then
      break
    end
    out[#out + 1] = c.ch
    u = u + c.w
  end
  return table.concat(out) .. "..."
end

-- word wrap into at most `maxl` lines of `units`
local function Wrap(s, units, maxl)
  local lines = {}
  for para in string.gmatch(string.gsub(s, "\r", "") .. "\n", "(.-)\n") do
    local line, lu = {}, 0
    local word, wu = {}, 0
    local function flush()
      if wu == 0 then
        return
      end
      if lu > 0 and lu + wu > units then
        lines[#lines + 1] = table.concat(line)
        line, lu = {}, 0
        while #word > 0 and word[1] == " " do
          table.remove(word, 1)
          wu = wu - 1
        end
      end
      for _, ch in ipairs(word) do
        line[#line + 1] = ch
      end
      lu, word, wu = lu + wu, {}, 0
    end
    for _, c in ipairs(Chars(para)) do
      if c.ch == " " then
        flush()
        word, wu = {" "}, 1
      elseif c.w == 2 then
        flush()
        word, wu = {c.ch}, 2
        flush()
      else
        word[#word + 1] = c.ch
        wu = wu + 1
        if wu >= units then
          flush()
        end
      end
    end
    flush()
    lines[#lines + 1] = table.concat(line)
  end
  while #lines > 0 and lines[#lines] == "" do
    lines[#lines] = nil
  end
  if #lines > maxl then
    local last = lines[maxl]
    lines = {table.unpack(lines, 1, maxl)}
    lines[maxl] = Cut(last .. " ...", units)
  end
  return lines
end

-- units that fit `px` pixels at text scale `sc`
local function Fit(px, sc)
  return math.max(4, math.floor(px / (G.PX * (sc or 1))))
end

local function Size(bytes)
  if type(bytes) ~= "number" or bytes <= 0 then
    return ""
  end
  if bytes >= 1048576 then
    return string.format("%.1f MB", bytes / 1048576)
  end
  return string.format("%d KB", math.max(1, math.floor(bytes / 1024 + 0.5)))
end

-- ---- data ---------------------------------------------------------------------------------------------------------------
-- a written mod name (requires, provides, a warning's other mod) -> the key id the rows carry (CMND_VRFW_MM_KEY_ID:
-- the mod.toml id, the key id and the former ids all name the mod); read once per name and listing
local key_names = {}

local function KeyOf(name)
  if name == nil or name == "" then
    return name
  end
  local k = key_names[name]
  if k == nil then
    k = Str(Call(M.KEY_ID, name))
    if k == "" then
      k = name
    end
    key_names[name] = k
  end
  return k
end

local function ReadAll()
  base_mod = nil
  key_names = {}
  mods = {}
  local installed, active, _skipped, _conflicts, _dirty, changes, np, p = Call(M.COUNT)
  have = type(installed) == "number"
  if not have then
    cnt = {installed = 0, mods = 0, active = 0, changes = 0, profiles = 1, profile = 0}
    return
  end
  cnt = {installed = Int(installed), active = Int(active), changes = Int(changes), profiles = math.max(1, Int(np)), profile = Int(p)}
  for i = 0, cnt.installed - 1 do
    local ok, id, name, version, author, _prio, enabled, state, _lua, _files, _deltas, _applied, pending, pos, size, preview,
          nwarn, level = Call(M.GET, i)
    if ok == true then
      local m = {idx = i, id = Str(id), name = Str(name), version = Str(version), author = Str(author),
                 enabled = enabled == true, state = Int(state), pending = pending == true, pos = Int(pos),
                 size = type(size) == "number" and size or 0, preview = preview == true, nwarn = Int(nwarn),
                 level = Int(level)}
      -- the name a player reads: the mod's own text in the screen's language (key `<mod>.mod_name` of its text.toml,
      -- 9 languages; only active mods have their texts merged), else the manifest's `name`
      local nid = TextIdKey(m.id .. ".mod_name")
      local ln = nid ~= nil and Str(Call(C.TEXT_GET, nid)) or ""
      if ln ~= "" then
        m.name = ln
      end
      -- its family: the parent it is a module of, its place and short name there,
      -- and its own internal modules (option rows, keys "<mod>.<id>")
      local par, ord, nkey, internal = Call(M.MODULE, m.id)
      m.parent, m.morder, m.internal = Str(par), Int(ord), {}
      if Str(nkey) ~= "" then
        local kid = TextIdKey(m.id .. "." .. Str(nkey))
        local s = kid ~= nil and Str(Call(C.TEXT_GET, kid)) or ""
        m.mname = s ~= "" and s or nil
      end
      for o in string.gmatch(Str(internal), "[^\n]+") do
        m.internal[#m.internal + 1] = m.id .. "." .. o
      end
      if m.id == BASE then
        if base_mod == nil then base_mod = m end
      else
        m.order = #mods + 1
        mods[#mods + 1] = m
      end
    end
  end
  -- the families: a module mod whose parent is installed lives in the parent's entry (m.family = the parent, the
  -- parent's m.modules = its module mods by order, then name); one whose parent is missing stays a mod of its own
  local byid = {}
  for _, m in ipairs(mods) do
    byid[m.id] = m
    m.modules = {}
  end
  for _, m in ipairs(mods) do
    m.family = m.parent ~= "" and m.parent ~= m.id and byid[m.parent] or nil
    if m.family ~= nil then
      m.family.modules[#m.family.modules + 1] = m
    end
  end
  for _, m in ipairs(mods) do
    table.sort(m.modules, function(a, b)
      if a.morder ~= b.morder then return a.morder < b.morder end
      return string.lower(a.mname or a.name) < string.lower(b.mname or b.name)
    end)
  end
  if base_mod ~= nil and base_mod.enabled then
    if base_mod.state == 0 then cnt.active = math.max(0, cnt.active - 1) end
    for _, m in ipairs(mods) do
      if m.pos > 0 then m.pos = m.pos - 1 end
    end
  end
  -- the counts and load numbers are of top-level mods only: a module mod loads right after its parent (the
  -- ModLoader's load order) and shares its number; cnt.mods = installed top-level mods, cnt.active = numbered ones
  local top_mods, place = 0, 0
  for _, m in ipairs(mods) do
    if m.family == nil then
      top_mods = top_mods + 1
      if m.enabled and m.pos > 0 then
        place = place + 1
        m.pos = place
      else
        m.pos = 0
      end
    end
  end
  for _, m in ipairs(mods) do
    if m.family ~= nil then
      m.pos = (m.enabled and m.pos > 0) and m.family.pos or 0
    end
  end
  cnt.mods, cnt.active = top_mods, place
  profiles = {}
  for k = 0, cnt.profiles - 1 do
    profiles[k + 1] = Str(Call(M.PROFILE_NAME, k))
  end
end

local function Text(m, what)
  m.texts = m.texts or {}
  if m.texts[what] == nil then
    m.texts[what] = Str(Call(M.GET_TEXT, m.idx, what))
  end
  return m.texts[what]
end

local function NameOf(id)
  id = KeyOf(id)
  if id == BASE and base_mod ~= nil then return base_mod.name end
  for _, m in ipairs(mods) do
    if m.id == id then
      return m.name
    end
  end
  return id
end

local function ModById(id)
  id = KeyOf(id)
  if id == BASE then return base_mod end
  for _, m in ipairs(mods) do
    if m.id == id then
      return m
    end
  end
  return nil
end

-- accent / case folded search key
local FOLD = {["á"] = "a", ["à"] = "a", ["â"] = "a", ["ä"] = "a", ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e",
              ["í"] = "i", ["ì"] = "i", ["ï"] = "i", ["ó"] = "o", ["ò"] = "o", ["ô"] = "o", ["ö"] = "o", ["ú"] = "u",
              ["ù"] = "u", ["ü"] = "u", ["ñ"] = "n", ["ç"] = "c", ["Á"] = "a", ["É"] = "e", ["Í"] = "i", ["Ó"] = "o",
              ["Ú"] = "u", ["Ñ"] = "n", ["Ü"] = "u"}
local function Fold(s)
  local out = {}
  for _, c in ipairs(Chars(s)) do
    out[#out + 1] = FOLD[c.ch] or string.lower(c.ch)
  end
  return table.concat(out)
end

-- warnings of a mod in plain words: {red, text}
local function Warnings(m)
  local out = {}
  for line in string.gmatch(Text(m, 7), "[^\n]+") do
    local kind, other, count, wins, detail = string.match(line, "^(%a+)|([^|]*)|(%d+)|(%d)|(.*)$")
    local o = NameOf(other or "")
    if kind == "missing" then
      out[#out + 1] = {true, T("w_missing", {o = o})}
    elseif kind == "disabled" then
      out[#out + 1] = {m.enabled, T("w_disabled", {o = o})}
    elseif kind == "version" then
      local c, v = string.match(detail or "", "^(.-)|(.*)$")
      out[#out + 1] = {true, T("w_version", {o = o, c = c or "", v = v or ""})}
    elseif kind == "incompatible" then
      out[#out + 1] = {m.enabled, T("w_incompat", {o = o})}
    elseif kind == "shared" then
      out[#out + 1] = {false, T(wins == "1" and "w_win" or "w_lose", {n = count, o = o})}
    elseif kind == "duplicate" then
      out[#out + 1] = {true, T("w_dup")}
    end
  end
  return out
end

-- the mods the grid shows: search, filter, sort
local function Shown()
  local q = Fold(ui.query)
  local f = FILTERS[ui.filter]
  local out = {}
  for _, m in ipairs(mods) do
    -- a module mod is a row of its parent's page, not a card
    local ok = m.family == nil
    if ok and q ~= "" then
      local hay = m.name .. " " .. m.id .. " " .. m.author .. " " .. Text(m, 8)
      for _, mm in ipairs(m.modules or {}) do
        hay = hay .. " " .. mm.name .. " " .. mm.id .. " " .. (mm.mname or "")
      end
      ok = string.find(Fold(hay), q, 1, true) ~= nil
    end
    if ok and f == "on" then
      ok = m.enabled
    elseif ok and f == "off" then
      ok = not m.enabled
    elseif ok and f == "warn" then
      ok = m.level > 0 or m.nwarn > 0 or (m.enabled and m.state == 1)
    elseif ok and f == "pending" then
      ok = m.pending
    end
    if ok then
      out[#out + 1] = m
    end
  end
  local s = SORTS[ui.sort]
  if s == "order" then
    -- the load order: the numbered (switched-on) mods by their number, then the others (greyed, no number)
    table.sort(out, function(a, b)
      local pa, pb = a.pos > 0 and a.pos or math.huge, b.pos > 0 and b.pos or math.huge
      if pa ~= pb then return pa < pb end
      return a.order < b.order
    end)
  elseif s == "name" then
    table.sort(out, function(a, b)
      local fa, fb = Fold(a.name), Fold(b.name)
      if fa == fb then return a.order < b.order end
      return fa < fb
    end)
  elseif s == "size" then
    table.sort(out, function(a, b)
      if a.size == b.size then return a.order < b.order end
      return a.size > b.size
    end)
  elseif s == "date" then
    table.sort(out, function(a, b)
      local da, db = Text(a, 9), Text(b, 9)
      if da == db then return a.order < b.order end
      return da > db
    end)
  end
  return out
end

-- the load order list: switched-on mods (top = highest priority), then a header, then the others
local function OrderRows()
  local on, off = {}, {}
  for _, m in ipairs(mods) do
    -- a module mod is not a row of its own: it loads with its parent and moves with it
    if m.family == nil then
      if m.enabled then on[#on + 1] = m else off[#off + 1] = m end
    end
  end
  local rows = {{head = true, first = true, text = T("order_on", {n = #on})}}
  for _, m in ipairs(on) do rows[#rows + 1] = {m = m} end
  rows[#rows + 1] = {head = true, text = T("order_off", {n = #off})}
  for _, m in ipairs(off) do rows[#rows + 1] = {m = m} end
  return rows
end

-- the picture of a mod: (texture crc, card sprite crc, large sprite crc) or nil (placeholder)
local thumbs = {}
local function Thumb(m)
  if thumbs[m.id] == nil then
    local path, card, large = Call(M.THUMB, m.id)
    if type(path) == "string" and path ~= "" then
      thumbs[m.id] = {Crc(path), Crc(card), Crc(large), path}
    elseif m.preview then
      -- a preview.g4tx the ModLoader serves (built by the app): evt_mods/preview/<id>.g4tx, 16:9 sprites _t / _l
      local p = "#/menu/evt_mods/preview/" .. m.id .. ".g4tx"
      thumbs[m.id] = {Crc(p), Crc("evt_mp_" .. m.id .. "_t"), Crc("evt_mp_" .. m.id .. "_l"), p}
    else
      thumbs[m.id] = false
    end
  end
  local t = thumbs[m.id]
  if t and not tex_asked[t[4]] then
    tex_asked[t[4]] = true
    tex_wait, tex_frames = true, 0
    funcLuaMenuCommand(C.LOAD_TEX, t[4])
  end
  return t or nil
end

local function TileOf(id)
  return Crc(id) % NTILES
end

-- the mod's initials for its icon frame: the first letters of its first two words («Character Reforged» -> «CR»),
-- else its first two letters («InaRogue» -> «IN»)
local function Initials(m)
  local s = m.name ~= "" and m.name or m.id
  local words = {}
  for w in string.gmatch(s, "[^%s%-_]+") do
    words[#words + 1] = Chars(w)
  end
  local out = {}
  if #words >= 2 then
    out = {words[1][1].ch, words[2][1].ch}
  elseif #words == 1 then
    out = {words[1][1].ch, words[1][2] and words[1][2].ch or nil}
  end
  local t = string.upper(table.concat(out))
  return t ~= "" and t or "?"
end

-- the icon of a mod's mod.toml (`icon`): (texture crc, sprite crc) or nil (the initials in the grey frame)
local icons = {}
local function IconOf(m)
  if icons[m.id] == nil then
    local path, sprite = Call(M.ICON, m.id)
    icons[m.id] = (type(path) == "string" and path ~= "") and {Crc(path), Crc(Str(sprite)), path} or false
  end
  local t = icons[m.id]
  if t and not tex_asked[t[3]] then
    tex_asked[t[3]] = true
    tex_wait, tex_frames = true, 0
    funcLuaMenuCommand(C.LOAD_TEX, t[3])
  end
  return t or nil
end

-- ---- drawing: free layer instances, set only when something changed -------------------------------------------------------
local used, was, sent = {}, {}, {}

local overflow = 0             -- drawings that found no free instance left (the tests keep it at 0)
local function Slot(key)
  local L = FREE[key]
  if L == nil then
    return nil
  end
  local i = used[key] or 0
  if i >= L[2] then
    overflow = overflow + 1
    return nil
  end
  used[key] = i + 1
  return i
end

-- funcLuaMenuCommand for one instance, skipped when it repeats the last one sent for that property
local function Set(layer, idx, prop, cmd, ...)
  local k = layer .. ":" .. idx .. ":" .. prop
  local args = table.pack(...)
  local sig = {}
  for i = 1, args.n do
    sig[#sig + 1] = tostring(args[i])
  end
  sig = table.concat(sig, ",")
  if sent[k] == sig then
    return
  end
  sent[k] = sig
  funcLuaMenuCommand(cmd, ...)
end

local function Show(key, i)
  local L = FREE[key][1]
  Set(L, i, "vis", C.LAYER_VISIBLE, L, i, true)
end

-- a quad of the atlas (or of a mod's texture): top-left x, y, w x h
local function Quad(key, sprite, x, y, w, h, alpha, tex)
  local i = Slot(key)
  if i == nil then
    return nil
  end
  local L = FREE[key][1]
  Show(key, i)
  Set(L, i, "sc", C.SCALE, L, w / G.Q, h / G.Q, 1, i)
  Set(L, i, "sp", C.SPRITE, L, tex or ATLAS, sprite, N.QUAD, 0, i)
  Set(L, i, "pos", C.POS, L, x + w / 2, -(y + h / 2), 0, i)
  Set(L, i, "a", C.ALPHA, L, i, 0, alpha or 1)
  return i
end

-- a text anchored at x (left / centre / right edge by the layer: TL / TC / TR, PL / PC / PR), vertical middle y
local ALIGN = {TL = 0, TC = 1, TR = 2, PL = 0, PC = 1, PR = 2}
local function Txt(key, s, x, y, sc)
  if s == nil or s == "" then
    return nil
  end
  local i = Slot(key)
  if i == nil then
    return nil
  end
  sc = sc or 1
  local L = FREE[key][1]
  local a = ALIGN[key]
  local ox = a == 0 and G.TXT_X or (a == 1 and (G.TXT_X + G.TXT_W / 2) or (G.TXT_X + G.TXT_W))
  Show(key, i)
  Set(L, i, "band", C.MESH_VISIBLE, L, N.BAND, false, i)
  Set(L, i, "txt", C.TEXT, L, N.TEXT, s, i)
  Set(L, i, "sc", C.SCALE, L, sc, sc, 1, i)
  Set(L, i, "pos", C.POS, L, x - ox * sc, G.TXT_MID * sc - y, 0, i)
  return i
end

local function Hit(x0, y0, w, h, id, act)
  hits[#hits + 1] = {x0, y0, x0 + w, y0 + h, id, act}
end

local function Begin()
  used, hits = {}, {}
end

-- hide what the last drawing used and this one did not
local function Finish()
  for _, key in ipairs(FREE_ORDER) do
    local L = FREE[key][1]
    local n = used[key] or 0
    for i = n, (was[key] or FREE[key][2]) - 1 do
      Set(L, i, "vis", C.LAYER_VISIBLE, L, i, false)
    end
    was[key] = n
  end
end

-- ---- drawing: the parts of the screen --------------------------------------------------------------------------------------
local function ProfileName()
  local name = profiles[cnt.profile + 1] or ""
  if name == "" or name == "Principal" then
    name = T("profile_main")
  end
  return name
end

local function DrawHeader()
  local s = T("header")
  funcLuaMenuCommand(C.TEXT, L_HEADER, N.SUB_TITLE, s)
end

local function TabLabel(k)
  if k == 1 then
    return T("tab_installed", {n = cnt.mods or #mods})
  end
  return T("tab_order", {n = cnt.active})
end

local function DrawTabs()
  -- the navy bar (Q, the tabs, E) at the top left
  Quad("Q0", SP("tabbar"), G.TABBAR_X, G.TAB_Y, G.TABBAR_W, G.TAB_H)
  for k = 1, G.NTABS do
    local x = G.TAB_X + (k - 1) * G.TAB_STEP
    local sel = ui.tab == k
    local hot = mouse.on and mouse.hot == "tab" .. k and not sel
    local locked = ui.page ~= nil and not sel
    if sel or hot then
      Quad("Q2", SP(sel and "tab_sel" or "tab_hot"), x, G.TAB_Y, G.TAB_W, G.TAB_H, locked and 0.45 or 1)
    end
    Txt("TC", (sel and "" or "[CWG]") .. Cut(TabLabel(k), Fit(G.TAB_W - 40, 0.82)) .. (sel and "" or "[C]"), x + G.TAB_W / 2, G.TAB_Y + G.TAB_H / 2, 0.82)
    if ui.page == nil then
      Hit(x + 10, G.TAB_Y, G.TAB_W - 20, G.TAB_H, "tab" .. k, function() SwitchTab(k) end)
    end
  end
  if ui.page == nil and G.NTABS > 1 then
    Txt("TC", K.L2, G.TAB_X - 22, G.TAB_Y + G.TAB_H / 2, 0.8)
    Txt("TC", K.R2, G.TAB_X + G.NTABS * G.TAB_STEP + 28, G.TAB_Y + G.TAB_H / 2, 0.8)
  end
  -- the profile (the last button of the row under the tabs)
  if have then
    local s = T("profile", {p = ProfileName()})
    if cnt.profiles > 1 then
      s = s .. " (" .. (cnt.profile + 1) .. "/" .. cnt.profiles .. ")"
    end
    local pfoc = mouse.hot == "profile" or (ui.tab == 1 and ui.zone == "bar" and ui.bar == 4 and ui.popup == nil and ui.page == nil)
    CE.RowTool(G.PROF_X, {id = "profile", key = K.X, text = s, value = ProfileName(), w = G.PROF_W,
                          act = function() StartCo(ProfileFlow) end}, ui.page == nil, pfoc)
  end
end

local function FilterLabel()
  return T("filter_" .. FILTERS[ui.filter])
end

local function SortLabel()
  return T("sort_" .. SORTS[ui.sort])
end

-- ---- the top row's pieces: ONE search box, ONE tool, used by every tab and every list page: the
-- same places, the count inside the search box -------------------------------------------------------------------------

-- the search box: s = {query, hint (text key), count (nil = none), foc, on, id (hit id), act (click)}
function CE.RowSearch(s)
  local x, y, w, h = G.ROW_SEARCH_X, G.TOOLS_Y, G.ROW_SEARCH_W, G.TOOLS_H
  local cy = y + h / 2
  Quad("Q0", SP(s.foc and "search2_sel" or "search2"), x, y, w, h, s.on and 1 or 0.45)
  local q = (s.query or "") ~= "" and ("[CB]" .. Cut(s.query, 14) .. "[C]") or ("[CWG]" .. T(s.hint) .. "[C]")
  Txt("TL", q, x + 20, cy, 0.72)
  if not s.on then
    return
  end
  Txt("TR", "[CWG]" .. K.R3 .. "[C]", x + w - 12, cy, 0.66)
  if s.count ~= nil then
    -- the count, small, inside the box
    Txt("TR", "[CWG]" .. Cut(s.count, Fit(w / 2 - 30, 0.56)) .. "[C]", x + w - 50, cy, 0.56)
  end
  Hit(x, y, w, h, s.id or "search", s.act)
end

-- a slanted button of the row (Ver / Orden / Perfil) at x: t = {id, key, text («Ver: Todos»), value («Todos»), w, act};
-- live = acts (else drawn off: the row never moves)
function CE.RowTool(x, t, live, foc)
  local y, h, tw = G.TOOLS_Y, G.TOOLS_H, t.w or G.ROW_FILTER_W
  local cy = y + h / 2
  Quad("Q0", SP(foc and "tool2_sel" or "tool2"), x, y, tw, h, live and 1 or 0.45)
  Txt("TL", (live and "" or "[CWG]") .. t.key .. (live and "" or "[C]"), x + 16, cy, 0.68)
  -- «Ver: Todos» when it fits, else the value alone after its key (the key is the control's icon)
  local label = Units(t.text) <= Fit(tw - 64, 0.66) and t.text or t.value
  Txt("TL", (live and "" or "[CWG]") .. Cut(label, Fit(tw - 64, 0.66)) .. (live and "" or "[C]"), x + 50, cy, 0.66)
  if live then
    Hit(x, y, tw, h, t.id, t.act)
  end
end

-- the row under the tabs: search | Ver | Orden (| Perfil, DrawTabs), in the same places on both tabs. «Instalados» uses
-- all three (and shows the count inside the search box); «Orden de carga» shows them off. A list page («¿Quién lo toca?») puts its
-- own search there (CE.DrawPageRow).
local function DrawToolbar(shown)
  if have and cnt.changes > 0 then
    -- the restart notice: above the row, right of the header
    Quad("Q0", SP("notice"), G.NOTICE_X, G.NOTICE_Y, G.NOTICE_W, G.NOTICE_H)
    local s = cnt.changes == 1 and T("band1") or T("band", {n = cnt.changes})
    Txt("TL", "[CB]" .. Cut(s, Fit(G.NOTICE_W - 60, 0.66)) .. "[C]", G.NOTICE_X + 46, G.NOTICE_Y + G.NOTICE_H / 2, 0.66)
  end
  if ui.page ~= nil then
    CE.DrawPageRow(ui.page)
    return
  end
  local tab = ui.tab
  local focus = tab == 1 and ui.zone == "bar"
  CE.RowSearch({on = tab == 1, query = ui.query, hint = "search_hint", foc = (focus and ui.bar == 1) or mouse.hot == "search",
             count = (tab == 1 and have) and T("count_short", {n = #shown, t = cnt.mods or #mods, a = cnt.active}) or nil,
             act = function() StartCo(SearchFlow) end})
  -- Ver / Orden: «Instalados» only (drawn off elsewhere: the row never moves)
  local tools = {{x = G.ROW_FILTER_X, w = G.ROW_FILTER_W, id = "filter", key = K.L3, text = T("filter", {f = FilterLabel()}), value = FilterLabel(), bar = 2, act = function() CycleFilter(1) end},
                 {x = G.ROW_SORT_X, w = G.ROW_SORT_W, id = "sort", key = K.SELECT, text = T("sort", {s = SortLabel()}), value = SortLabel(), bar = 3, act = function() CycleSort(1) end}}
  for _, t in ipairs(tools) do
    local live = tab == 1
    CE.RowTool(t.x, t, live, live and ((focus and ui.bar == t.bar) or mouse.hot == t.id))
  end
end

-- state badge of a mod: sprite, text
local function Badge(m)
  if m.enabled and m.state == 1 then
    return "pill_red", T("badge_skip")
  elseif m.enabled and M.NeedsUpdate ~= nil and M.NeedsUpdate(m.id) then
    -- an unknown game build: some of the mod's code sites were not found
    return "pill_amber", T("badge_update")
  elseif m.pending then
    return "pill_amber", T(m.enabled and "badge_will_on" or "badge_will_off")
  elseif m.enabled then
    return "pill_green", T("badge_on")
  end
  return "pill_grey", T("badge_off")
end

local function DrawScrollbar(total_rows, first, visible, x, y0, h, set)
  if total_rows <= visible then
    return
  end
  Quad("Q2", SP("track"), x, y0, G.SB_W, h)
  local th = math.max(40, h * visible / total_rows)
  local ty = y0 + (h - th) * first / math.max(1, total_rows - visible)
  Quad("Q1", SP("thumb"), x, ty, G.SB_W, th)
  if set ~= nil then
    -- the mouse: a click on the bar jumps there, holding the button drags it (PollMouse: mouse.drag);
    -- set(first row) moves the page
    local n = total_rows - visible
    Hit(x - 10, y0, G.SB_W + 20, h, "sbar", function()
      mouse.drag = {y0 = y0, h = h, th = th, n = n, set = set}
      CE.DragTo(mouse.y)
    end)
  end
end

local function DrawGrid()
  local shown = Shown()
  CE.ListBox()
  if not have or #shown == 0 then
    -- one white plate with the reason, the panel empty
    local title = (not have) and "" or (#mods == 0 and T("empty_title") or T("no_match_title"))
    local desc = (not have) and T("noloader") or (#mods == 0 and T("empty_desc") or T("no_match_desc"))
    Quad("Q2", SP("white"), G.LIST_X, G.LIST_Y, G.ROW_W - 12, 200)
    local y = G.LIST_Y + 44
    if title ~= "" then
      Txt("TL", "[CN]" .. Cut(title, Fit(G.ROW_W - 80, 1.0)) .. "[C]", G.LIST_X + 30, y, 1.0)
      y = y + 46
    end
    for i, l in ipairs(Wrap(desc, Fit(G.ROW_W - 80, 0.78), 3)) do
      Txt("TL", "[CB]" .. l .. "[C]", G.LIST_X + 30, y + (i - 1) * 34, 0.78)
    end
    CE.InfoPanel(nil)
    return shown
  end
  for k = 0, G.LIST_ROWS - 1 do
    local n = ui.top + k + 1
    local m = shown[n]
    if m ~= nil then
      CE.ListRow(k, m, ui.zone == "grid" and n == ui.sel and ui.popup == nil, "card" .. m.id, "btn" .. m.id,
                 function() SelectMod(m.id) OpenDetails() end)
    end
  end
  DrawScrollbar(#shown, ui.top, G.LIST_ROWS, G.SB_X, G.LIST_Y, G.LIST_ROWS * G.ROW_STEP - (G.ROW_STEP - G.ROW_H), function(f)
    ui.top = f
    ui.sel = math.max(ui.top + 1, math.min(ui.sel, ui.top + G.LIST_ROWS))
    ui.zone = "grid"
  end)
  CE.InfoPanel(shown[ui.sel])
  return shown
end

-- right-hand information panel of the list pages: title bar + lines {text, scale}
local function DrawPanel(title, lines)
  CE.PanelFrame()
  Txt("TL", Cut(title, Fit(G.PANEL_W - 160, 1.0)), G.PANEL_X + 96, G.PANEL_Y + G.PANEL_HEAD / 2, 1.0)
  local x, w = G.PANEL_X + 30, G.PANEL_W - 60
  local y = G.PANEL_BODY_Y + 36
  for _, l in ipairs(lines) do
    if l.gap then
      y = y + l.gap
    else
      local sc = l.sc or 0.78
      for _, t in ipairs(Wrap(l.t, Fit(w, sc), l.max or 3)) do
        if y < G.PANEL_BODY_Y + G.PANEL_BODY_H - 24 then
          Txt("TL", (l.c or "[CB]") .. t .. "[C]", x, y, sc)
        end
        y = y + math.floor(34 * sc / 0.78)
      end
    end
  end
end

-- ---- the mod info block: labelled fields, shared by the «Orden de carga» panel and a mod's page --------
-- L: the layers to draw on, {q = quad layer, l = left text layer, c = centred text layer}
local INFO = {MAIN = {q = "Q1", l = "TL", c = "TC"}, POPUP = {q = "P1", l = "PL", c = "PC"},
              LABEL_W = 196, STEP = 36, DASH = "—"}

-- the state in two words and its colour
function INFO.State(m)
  if m.pending then
    return T(m.enabled and "st_pend_on" or "st_pend_off"), "[CY]"
  end
  if m.enabled and m.state == 1 then
    return T("st_skip"), "[CR]"
  end
  return T(m.enabled and "st_on" or "st_off"), m.enabled and "[CB]" or "[CWG]"
end

function INFO.Provides(m)
  if m.provides_text == nil then
    m.provides_text = Str(Call(M.PROVIDES, m.id))
  end
  return m.provides_text
end

function INFO.Value(s)
  return (s ~= nil and s ~= "") and s or INFO.DASH
end

-- «Requiere» in words: a requirement on a part of the framework (any name VR-Framework provides:
-- mod_options, technique_engine, telop_engine…) is a requirement on the framework itself, shown once as «VR-Framework
-- (x.y+)»; another mod by its name (a minimum version as «(1.0+)»: the game font has no «≥»). The ModLoader resolves those names through the framework's `provides` (old
-- manifests keep working).
function INFO.Requires(m)
  local raw = Text(m, 2)
  if raw == "" then
    return ""
  end
  local base, parts = ModById(BASE), {}
  if base ~= nil then
    for item in string.gmatch(INFO.Provides(base), "[^,%s]+") do
      local n = string.match(item, "^([%w_]+)")
      if n ~= nil then
        parts[n] = true
      end
    end
  end
  local function need(op, ver)
    if ver == "" then
      return ""
    end
    if op == "" or op == ">=" then
      return " (" .. ver .. "+)"
    end
    return " (" .. op .. " " .. ver .. ")"
  end
  local fw, fwv, out, seen = false, "", {}, {}
  for req in string.gmatch(raw, "[^,\n]+") do
    local name, op, ver = string.match(req, "^%s*([%w_%.%-]+)%s*([<>=!~]*)%s*([^%s]*)%s*$")
    if name ~= nil then
      local key = KeyOf(name)
      if key == BASE or parts[name] then
        fw = true
        if key == BASE and ver ~= "" then
          fwv = need(op, ver)
        end
      elseif not seen[key] then
        seen[key] = true
        out[#out + 1] = NameOf(name) .. need(op, ver)
      end
    end
  end
  if fw then
    table.insert(out, 1, ((base ~= nil and base.name ~= "") and base.name or "VR-Framework") .. fwv)
  end
  return table.concat(out, ", ")
end

-- The cover of a mod: its picture, else a generated one (the huge grey tile with a letter looked cheap):
-- the colour of its first tag, the tag in small capitals at the top and the mod's name in large type at the bottom.
INFO.TAG_TILE = {framework = 0, interface = 1, interfaz = 1, gameplay = 2, jugabilidad = 2, story = 3, historia = 3,
                 audio = 4, graphics = 5, ["gráficos"] = 5, tools = 6, herramientas = 6}
-- the mod's colour: the tile of its first tag, else one picked by its id
function INFO.Tile(m)
  local tag = string.match(Text(m, 8), "^([^\n]+)") or ""
  return INFO.TAG_TILE[string.lower(tag)] or TileOf(m.id)
end

function INFO.Cover(m, x, y, w, h, L)
  local t = Thumb(m)
  if t ~= nil then
    Quad(L.q, t[3], x, y, w, h, 1, t[1])
    return
  end
  local tag = string.match(Text(m, 8), "^([^\n]+)") or ""
  Quad(L.q, SP("tile" .. INFO.Tile(m)), x, y, w, h)
  local pad = math.floor(w * 0.06)
  if tag ~= "" then
    Txt(L.l, Cut(string.upper(tag), Fit(w - 2 * pad, 0.6)), x + pad, y + pad + 8, 0.6)
  end
  local sc = w >= 360 and 1.25 or 1.0
  local lines = Wrap(m.name ~= "" and m.name or m.id, Fit(w - 2 * pad, sc), 2)
  for i, l in ipairs(lines) do
    Txt(L.l, l, x + pad, y + h - pad - 14 - (#lines - i) * math.floor(38 * sc), sc)
  end
end

-- the mod's native permissions (mod.toml `permissions`: memory, call, patch, command, state, hook), "" = none; asked once per mod
INFO.PERMS = {}
function INFO.Perms(m)
  local p = INFO.PERMS[m.id]
  if p == nil then
    p = Str(Call(M.PERMS, m.id))
    INFO.PERMS[m.id] = p
  end
  return p
end

-- The description a player reads: the mod's own text in the screen's language (key `<mod>.mod_description` of its
-- text.toml, 9 languages), else the manifest's `description`; only its first paragraph (long technical notes belong in
-- the mod's README.md). Returns the text, whether more was left out and the whole text.
function INFO.Description(m)
  local id = TextIdKey(m.id .. ".mod_description")
  local s = id ~= nil and Str(Call(C.TEXT_GET, id)) or ""
  if s == "" then
    s = Text(m, 0)
  end
  s = string.gsub(s, "\r", "")
  local first, rest = string.match(s, "^(.-)\n%s*\n(.*)$")
  if first ~= nil and string.find(rest, "%S") ~= nil then
    return first, true, s
  end
  return s, false, s
end

-- ---- the list and the info panel (both tabs) -----------------------------------------------------------------------------
-- A box with rounded corners from stretched flat quads: the body in three strips, a disc at each corner (all of one
-- opaque colour, so their order on the layer does not show)
function CE.RoundBox(layer, flat, disc, x, y, w, h, r)
  Quad(layer, SP(flat), x + r, y, w - 2 * r, h)
  Quad(layer, SP(flat), x, y + r, r, h - 2 * r)
  Quad(layer, SP(flat), x + w - r, y + r, r, h - 2 * r)
  for _, c in ipairs({{x, y}, {x + w - 2 * r, y}, {x, y + h - 2 * r}, {x + w - 2 * r, y + h - 2 * r}}) do
    Quad(layer, SP(disc), c[1], c[2], 2 * r, 2 * r)
  end
end

-- the navy box of the list (it ends above the button guide)
function CE.ListBox()
  CE.RoundBox("Q0", "navy", "disc_navy", G.BOX_X, G.BOX_Y, G.BOX_W, G.BOX_BOTTOM - G.BOX_Y, G.BOX_R)
end

-- a mod's icon: its mod.toml `icon`, else its initials in the neutral frame; s = side (36 a row, 96 the panel)
function CE.Icon(m, x, y, s)
  local big = s >= 60
  local a = (m.enabled or big) and 1 or 0.75
  local ic = IconOf(m)
  if ic ~= nil then
    Quad("Q1", ic[2], x, y, s, s, a, ic[1])
    return
  end
  Quad("Q1", SP(big and "iconbox_l" or "iconbox"), x, y, s, s, a)
  Txt("TC", "[CWG]" .. Initials(m) .. "[C]", x + s / 2, y + s / 2 - (big and 3 or 1), big and 1.45 or 0.5)
end

-- a group title of the «Orden de carga» list (on / off), its note at the right
function CE.HeadRow(k, text, note)
  local y = G.LIST_Y + k * G.ROW_STEP
  Quad("Q2", SP("row_head"), G.LIST_X, y, G.ROW_W - 12, G.ROW_H)
  Txt("TL", Cut(text, Fit(G.ROW_W / 2, 0.8)), G.LIST_X + 24, y + G.ROW_H / 2, 0.8)
  if note ~= nil then
    Txt("TR", Cut(note, Fit(G.ROW_W / 2 - 60, 0.62)), G.LIST_X + G.ROW_W - 40, y + G.ROW_H / 2, 0.62)
  end
end

-- One mod of the list (visible row k): its plate (dimmed when off; the cyan frame and the green arrow when focused),
-- the load number in its square (none when off), the icon, the name, «version · size · author», the warning / restart
-- marks and the state tag at the right. A click on the row = `open`; a click on the tag switches the mod.
-- `family` = show a module mod as «Parent › Module» («Orden de carga» lists them all).
function CE.ListRow(k, m, focused, row_id, tag_id, open, family)
  local x, y, w, h = G.LIST_X, G.LIST_Y + k * G.ROW_STEP, G.ROW_W, G.ROW_H
  local cy = y + h / 2
  local off = not m.enabled
  Quad("Q2", SP((off and "lplate_off" or "lplate") .. (focused and "_sel" or "")), x, y, w, h)
  if focused then
    Quad("Q1", SP("arrow_g"), x - 20, cy - 14, 18, 28)
  end
  if m.enabled and m.pos > 0 then
    Quad("Q1", SP("numbox"), x + 18, cy - 17, 34, 34)
    Txt("TC", "[CN]" .. m.pos .. "[C]", x + 35, cy, m.pos >= 100 and 0.5 or (m.pos >= 10 and 0.66 or 0.76))
  else
    Quad("Q1", SP("numbox_off"), x + 18, cy - 17, 34, 34)
  end
  CE.Icon(m, x + 70, cy - 17, 34)
  local nm = m.name ~= "" and m.name or m.id
  if family and m.family ~= nil then
    nm = m.family.name .. " › " .. (m.mname or nm)
  end
  local tx, mx = x + w - 150, x + 440
  Txt("TL", (off and "[CWG]" or "[CB]") .. Cut(nm, Fit(mx - x - 134, 0.9)) .. "[C]", x + 122, cy, 0.9)
  -- warnings and the pending restart: small marks left of the tag
  local ix = tx - 34
  if m.level >= 2 or (m.enabled and m.state == 1) then
    Quad("Q1", SP("warn_r"), ix, cy - 14, 28, 28)
    ix = ix - 32
  elseif m.level == 1 or m.nwarn > 0 then
    Quad("Q1", SP("warn_a"), ix, cy - 14, 28, 28)
    ix = ix - 32
  end
  if m.pending then
    Quad("Q1", SP("pend"), ix, cy - 14, 28, 28)
    ix = ix - 32
  end
  local meta = {}
  if m.version ~= "" then meta[#meta + 1] = "v" .. Cut(m.version, 10) end
  local sz = Size(m.size)
  if sz ~= "" then meta[#meta + 1] = sz end
  if m.author ~= "" then meta[#meta + 1] = m.author end
  Txt("TL", "[CWG]" .. Cut(table.concat(meta, "  ·  "), Fit(ix + 20 - mx, 0.62)) .. "[C]", mx, cy + 1, 0.62)
  -- the state tag: green «Activado» / grey «Desactivado»; the other states (restart, not loaded, update) in words
  local bs, bt = Badge(m)
  if bs == "pill_green" or bs == "pill_grey" then
    bt = T(m.enabled and "card_on" or "card_off")
  end
  Quad("Q1", SP(bs), tx, cy - 13, 122, 26, off and 0.9 or 1)
  Txt("TC", Cut(bt, Fit(114, 0.6)), tx + 61, cy, 0.6)
  if mouse.on and mouse.hot == tag_id then
    CE.Focus("Q1", tx, cy - 13, 122, 26, 2)
  end
  Hit(x, y, w, h, row_id, open)
  Hit(tx - 4, cy - 17, 130, 34, tag_id, function() SelectMod(m.id) StartCo(Toggle) end)
end

-- the info panel's frame: the header bar (diagonal stripes, the blue bar to the screen's edge) and the white body
function CE.PanelFrame()
  local x, y, hh = G.PANEL_X, G.PANEL_Y, G.PANEL_HEAD
  Quad("Q0", SP("hstripes"), x, y, 64, hh)
  Quad("Q0", SP("hbar_l"), x + 44, y, 40, hh)
  Quad("Q0", SP("hbar"), x + 84, y, 1920 - (x + 84), hh)
  CE.RoundBox("Q0", "white", "disc_white", x, G.PANEL_BODY_Y, G.PANEL_W, G.PANEL_BODY_H, G.PANEL_R)
end

-- the framework's parts (the names its mod.toml `provides`): a requirement on one is a requirement on the framework
function INFO.BaseParts()
  local parts = {}
  if base_mod ~= nil then
    for item in string.gmatch(INFO.Provides(base_mod), "[^,%s]+") do
      local n = string.match(item, "^([%w_%.%-]+)")
      if n ~= nil then
        parts[n] = true
      end
    end
  end
  return parts
end

-- the installed mod that answers requirement `name`: the mod of that id, else one whose `provides` names it
function INFO.Provider(name)
  local d = ModById(name)
  if d ~= nil then
    return d
  end
  for _, o in ipairs(mods) do
    for item in string.gmatch(INFO.Provides(o), "[^,%s]+") do
      local n = string.match(item, "^([%w_%.%-]+)")
      if n ~= nil and string.lower(n) == string.lower(name) then
        return o
      end
    end
  end
  return nil
end

-- «Necesita»: one row a requirement {label, state, colour; key, mod, name, ok, reason}; a framework part is the
-- framework, once and first; a minimum version as «(1.0+)»; the state: on, off or not installed; `ok` = installed,
-- on and not too old (the ModLoader's «version» warnings), else `reason` says why. Read once per mod (the list is read
-- again after every change).
function INFO.Needs(m)
  if m.needs ~= nil then
    return m.needs
  end
  local old = {}
  for line in string.gmatch(Text(m, 7), "[^\n]+") do
    local kind, other = string.match(line, "^(%a+)|([^|]*)|")
    if kind == "version" and other ~= nil then
      old[other] = true
    end
  end
  local out, seen, parts = {}, {}, INFO.BaseParts()
  for req in string.gmatch(Text(m, 2), "[^,\n]+") do
    local name, op, ver = string.match(req, "^%s*([%w_%.%-]+)%s*([<>=!~]*)%s*([^%s]*)%s*$")
    if name ~= nil then
      local own = KeyOf(name)
      local key = (own == BASE or parts[name]) and BASE or own
      if not seen[key] then
        seen[key] = true
        local d = key == BASE and base_mod or INFO.Provider(name)
        local short = (d ~= nil and d.name ~= "") and d.name or (key == BASE and "VR-Framework" or name)
        local label = short
        if key == own and ver ~= "" then
          label = label .. ((op == "" or op == ">=") and (" (" .. ver .. "+)") or (" (" .. op .. " " .. ver .. ")"))
        end
        local row
        if d == nil then
          row = {label, T("dep_missing"), "[CR]"}
        else
          row = {label, T(d.enabled and "st_on" or "st_off"), d.enabled and "[CG]" or "[CWG]"}
        end
        local too_old = old[name] or old[key] or old[own] or (d ~= nil and old[d.id])
        row.key, row.mod, row.name = key, d, short
        row.ok = d ~= nil and d.enabled and not too_old
        row.reason = (d == nil and T("dep_missing")) or (too_old and T("dep_old")) or ((not d.enabled) and T("st_off")) or ""
        if key == BASE then
          table.insert(out, 1, row)
        else
          out[#out + 1] = row
        end
      end
    end
  end
  m.needs = out
  return out
end

-- «Lo necesitan»: the names of the installed mods whose `requires` names this mod (its id or a name it provides)
function INFO.NeededBy(m)
  if m.needed_by ~= nil then
    return m.needed_by
  end
  local mine = {[m.id] = true}
  for item in string.gmatch(INFO.Provides(m), "[^,%s]+") do
    local n = string.match(item, "^([%w_%.%-]+)")
    if n ~= nil then
      mine[n] = true
    end
  end
  local out = {}
  for _, o in ipairs(mods) do
    if o ~= m then
      for req in string.gmatch(Text(o, 2), "[^,\n]+") do
        local name = string.match(req, "^%s*([%w_%.%-]+)")
        if name ~= nil and (mine[name] or mine[KeyOf(name)]) then
          out[#out + 1] = o.name ~= "" and o.name or o.id
          break
        end
      end
    end
  end
  m.needed_by = out
  return out
end

-- The info panel of mod `m` (nil = the frame alone): the header (initials, name, version), the icon and the sheet
-- (version, size, author, place in the load order, state), the description, «Necesita» (each requirement and its
-- state), «Lo necesitan» (the mods that require it), one warning line when there is one, and the hint of the mod's
-- page («Detalles», a click opens it too).
function CE.InfoPanel(m)
  CE.PanelFrame()
  if m == nil then
    return
  end
  local x, w = G.PANEL_X, G.PANEL_W
  local hc = G.PANEL_Y + G.PANEL_HEAD / 2
  local name = m.name ~= "" and m.name or m.id
  Quad("Q1", SP("night"), x + 92, hc - 17, 46, 34)
  Txt("TC", Initials(m), x + 115, hc, 0.6)
  Txt("TL", Cut(name, Fit(w - 330, 1.12)), x + 152, hc, 1.12)
  if m.version ~= "" then
    Txt("TR", "v" .. Cut(m.version, 12), x + w - 30, hc, 0.78)
  end
  local bx, by, iw = x + 30, G.PANEL_BODY_Y, w - 60
  CE.Icon(m, bx, by + 26, 96)
  local st, sc = INFO.State(m)
  if sc == "[CB]" then
    sc = "[CG]"
  end
  local sheet = {
    {T("f_version"), INFO.Value(m.version ~= "" and ("v" .. m.version) or "")},
    {T("f_size"), INFO.Value(Size(m.size))},
    {T("f_author"), m.author ~= "" and m.author or T("no_author_short")},
    {T("f_load_order"), (m.enabled and m.pos > 0) and T("pos_of", {n = m.pos, t = cnt.active}) or INFO.DASH},
    {T("f_state"), st, sc},
  }
  for i, r in ipairs(sheet) do
    local ry = by + 38 + (i - 1) * 21
    Txt("TL", "[CWG]" .. Cut(r[1], Fit(170, 0.6)) .. "[C]", bx + 120, ry, 0.6)
    Txt("TL", (r[3] or "[CB]") .. Cut(r[2], Fit(iw - 310, 0.62)) .. "[C]", bx + 300, ry, 0.62)
  end
  local y = by + 147
  Quad("Q2", SP("line"), bx, y, iw, 2)
  -- the description (its first paragraph, four lines at most)
  y = y + 23
  Txt("TL", "[CN]" .. T("f_description") .. "[C]", bx, y, 0.66)
  local desc = INFO.Description(m)
  Quad("Q2", SP("paper"), bx, y + 18, iw, 130)
  for i, l in ipairs(Wrap(desc ~= "" and desc or T("no_desc"), Fit(iw - 40, 0.7), 4)) do
    Txt("TL", (desc ~= "" and "[CB]" or "[CWG]") .. l .. "[C]", bx + 18, y + 45 + (i - 1) * 29, 0.7)
  end
  -- «Necesita»: a row a requirement and its state (three rows; more: the last says how many are left)
  y = y + 176
  Txt("TL", "[CN]" .. T("f_needs") .. "[C]", bx, y, 0.66)
  y = y + 20
  local needs = INFO.Needs(m)
  if #needs == 0 then
    Txt("TL", "[CWG]" .. T("needs_none") .. "[C]", bx + 2, y + 16, 0.68)
    y = y + 36
  end
  local MAXN = 3
  for i = 1, math.min(#needs, MAXN) do
    local d = needs[i]
    Quad("Q2", SP("paper2"), bx, y, iw, 32)
    if i == MAXN and #needs > MAXN then
      Txt("TL", "[CWG]" .. T("more_mods", {n = #needs - MAXN + 1}) .. "[C]", bx + 16, y + 16, 0.68)
    else
      Txt("TL", "[CB]" .. Cut(d[1], Fit(iw - 230, 0.7)) .. "[C]", bx + 16, y + 16, 0.7)
      Txt("TR", d[3] .. Cut(d[2], Fit(190, 0.6)) .. "[C]", bx + iw - 12, y + 16, 0.6)
    end
    y = y + 36
  end
  -- «Lo necesitan»: one line with the names
  y = y + 14
  Txt("TL", "[CN]" .. T("f_needed_by") .. "[C]", bx, y, 0.66)
  local users = INFO.NeededBy(m)
  if #users == 0 then
    Txt("TL", "[CWG]" .. T("needed_by_none") .. "[C]", bx, y + 35, 0.7)
  else
    Txt("TL", "[CB]" .. Cut(table.concat(users, "  ·  "), Fit(iw, 0.7)) .. "[C]", bx, y + 35, 0.7)
  end
  -- one warning (not loaded, incompatible, versions, shared files) above the hint, when there is one
  local hint_y = by + G.PANEL_BODY_H - 30
  local warn = nil
  if m.enabled and m.state == 1 then
    warn = {true, T("state_skip", {r = Text(m, 1)})}
  else
    warn = Warnings(m)[1]
  end
  if warn ~= nil and y + 70 < hint_y then
    Quad("Q1", SP(warn[1] and "warn_r" or "warn_a"), bx, y + 70 - 13, 26, 26)
    Txt("TL", (warn[1] and "[CR]" or "[CY]") .. Cut(warn[2], Fit(iw - 40, 0.62)) .. "[C]", bx + 36, y + 70, 0.62)
  end
  -- the mod's page (information, problems, conflicts, settings): Start / Alt, or a click on the hint
  Txt("TR", "[CWG]" .. K.START .. " " .. Cut(T("panel_details"), Fit(300, 0.62)) .. "[C]", x + w - 30, hint_y, 0.62)
  Hit(x + w - 380, hint_y - 18, 360, 36, "pdetails", function()
    if ui.tab == 1 then
      ui.zone = "grid"
    end
    OpenDetails()
  end)
end

local function DrawOrder()
  local rows = OrderRows()
  ui.osel = math.max(1, math.min(ui.osel, #rows))
  if rows[ui.osel].head then
    ui.osel = ui.osel < #rows and ui.osel + 1 or ui.osel - 1
    ui.osel = math.max(1, ui.osel)
  end
  if ui.osel < ui.otop then
    ui.otop = ui.osel
  elseif ui.osel >= ui.otop + G.LIST_ROWS then
    ui.otop = ui.osel - G.LIST_ROWS + 1
  end
  ui.otop = math.max(1, math.min(ui.otop, math.max(1, #rows - G.LIST_ROWS + 1)))
  CE.ListBox()
  for k = 0, G.LIST_ROWS - 1 do
    local n = ui.otop + k
    local r = rows[n]
    if r ~= nil then
      if r.head then
        CE.HeadRow(k, r.text, r.first and T("order_sub") or nil)
      else
        local m = r.m
        CE.ListRow(k, m, n == ui.osel and ui.popup == nil, "orow" .. n, "otag" .. n,
                   function() ui.osel = n SelectMod(m.id) OpenDetails() end, true)
      end
    end
  end
  DrawScrollbar(#rows, ui.otop - 1, G.LIST_ROWS, G.SB_X, G.LIST_Y, G.LIST_ROWS * G.ROW_STEP - (G.ROW_STEP - G.ROW_H), function(f)
    ui.otop = f + 1
    ui.osel = math.max(ui.otop, math.min(ui.osel, ui.otop + G.LIST_ROWS - 1))
  end)
  -- the panel: the selected mod
  local r = rows[ui.osel]
  CE.InfoPanel(r ~= nil and r.m or nil)
end


-- ---- the mod's page (popup, layout A) -----------------------------------------------------------------------------------
-- The window: a header band in the mod's colour (its cover, name and version, «author · updated · size · place», the
-- state pill, «Cerrar»), the row of view tabs (Información · Módulos · Problemas · Conflictos · Ajustes · Novedades),
-- the view's body and one shortcut bar (the view's keys and the main action button) at the bottom. A module's page and
-- a requirement's page open over the page they came from (ui.popup.back): B goes back to it.
-- The VR-Framework report of mod `id` (CMND_VRFW_REPORT_*, the start's report.json): {problems, conflicts, np, nc}.
-- `problems` is what the «Problemas» view lists: the entries grouped by what they mean (why the mod may not load, files left out, rows left out, warnings), each group
-- of one code under a header row in the player's language (text_report.toml `rc_<code>`: what it is and how to fix
-- it); the entries keep the core's English message, by file. `np` = entries (headers not counted). Read once per
-- screen opening. (one table: the main chunk is at Lua's limit of 200 locals)
local RV = {cache = {}, MAX = 400, ROWS = 13, ORDER = {dependency = 1, error = 2, skipped = 3, warning = 4}}
RV.NEWS_ROWS, RV.MOD_ROWS, RV.FULL_ROWS = 13, 9, 14

-- the body of a mod's page: under the header band and the view tabs, above the shortcut bar
function RV.BodyY()
  return G.WIN_Y + G.BAND_H + G.VTABS_H
end

function RV.FootY()
  return G.WIN_Y + G.WIN_H - G.FOOT_H
end

-- «author · updated · size · place in the load order» (a module: «Module of <parent>» first)
function RV.Meta(m)
  local out = {}
  if m.family ~= nil then
    out[#out + 1] = T("module_of", {o = m.family.name})
  end
  out[#out + 1] = m.author ~= "" and m.author or T("no_author_short")
  local d, sz = Text(m, 9), Size(m.size)
  if d ~= "" then
    out[#out + 1] = d
  end
  if sz ~= "" then
    out[#out + 1] = sz
  end
  if m.enabled and m.pos > 0 and m.family == nil then
    out[#out + 1] = T("meta_position", {n = m.pos, t = cnt.active})
  end
  return table.concat(out, "  ·  ")
end

-- The window of mod `m`'s page: the dim, the header band and the white body. Modal: a click outside closes it.
local function PopupWindow(m)
  Hit(0, 0, 1920, 1080, "modal", function()
    local x, y = mouse.x, mouse.y
    if x < G.WIN_X or x >= G.WIN_X + G.WIN_W or y < G.WIN_Y or y >= G.WIN_Y + G.WIN_H then
      ClosePopup()
    end
  end)
  -- the list behind stays visible, dimmed (no opaque cover)
  Quad("PD", SP("dim"), 0, 0, 1920, 1080, G.DIM_ALPHA)
  local x, y, w, h = G.WIN_X, G.WIN_Y, G.WIN_W, G.BAND_H
  Quad("P0", SP("tile" .. INFO.Tile(m)), x, y, w, h)
  Quad("P0", SP("white"), x, y + h, w, G.WIN_H - h)
  -- the cover: the mod's picture (mod.toml `cover`, thumbnail.png, preview.png), else one drawn in its colour, framed
  local cx, cy, cw, ch = x + 28, y + (h - G.COVER_H) / 2, G.COVER_W, G.COVER_H
  INFO.Cover(m, cx, cy, cw, ch, INFO.POPUP)
  if Thumb(m) == nil then
    for _, e in ipairs({{cx - 3, cy - 3, cw + 6, 3}, {cx - 3, cy + ch, cw + 6, 3}, {cx - 3, cy, 3, ch}, {cx + cw, cy, 3, ch}}) do
      Quad("P1", SP("white"), e[1], e[2], e[3], e[4])
    end
  end
  local tx = cx + cw + 32
  local tw = x + w - 300 - tx
  local name = m.name ~= "" and m.name or m.id
  Txt("PL", Cut(name, Fit(tw - 150, 1.3)) .. (m.version ~= "" and ("   v" .. Cut(m.version, 12)) or ""), tx, y + 66, 1.3)
  Txt("PL", Cut(RV.Meta(m), Fit(tw, 0.74)), tx, y + 120, 0.74)
  -- the state pill and «Cerrar» (B, Esc or a click); a page opened over another goes back to it
  local bs, bt = Badge(m)
  local pw = 230
  Quad("P1", SP(bs), x + w - 28 - pw, y + 100, pw, 42)
  Txt("PC", Cut(bt, Fit(pw - 20, 0.66)), x + w - 28 - pw / 2, y + 121, 0.66)
  Txt("PR", K.B .. " " .. T(ui.popup.back ~= nil and "hint_back" or "hint_close"), x + w - 28, y + 40, 0.76)
  Hit(x + w - 240, y, 240, 72, "pclose", function() ClosePopup() end)
end

-- the main action button at the right of the shortcut bar
local function PopupButton(label, filled, sel, act, id)
  local bw, bh = 300, 48
  local bx, by = G.WIN_X + G.WIN_W - 28 - bw, RV.FootY() + (G.FOOT_H - bh) / 2
  Quad("P1", SP((filled and "btn_on" or "btn_off") .. (sel and "_sel" or "")), bx, by, bw, bh)
  Txt("PC", (filled and "" or "[CN]") .. Cut(label, Fit(bw - 24, 0.78)) .. (filled and "" or "[C]"), bx + bw / 2, by + bh / 2, 0.78)
  Hit(bx, by, bw, bh, id, act)
end

-- the page's main action, the one button of the shortcut bar: switch the mod on / off
function PopupButtons(m)
  return {{id = "pb1", label = T(m.enabled and "btn_disable" or "btn_enable"), filled = not m.enabled,
           act = function() StartCo(Toggle) end}}
end

-- the views of mod `m`'s page, in tab order: «Módulos» only for a mod with modules, «Novedades» only for a mod with
-- a changelog summary
function RV.Views(m)
  local v = {"info"}
  if RV.HasModules(m) then
    v[#v + 1] = "modules"
  end
  v[#v + 1] = "problems"
  v[#v + 1] = "conflicts"
  v[#v + 1] = "settings"
  if #RV.Notes(m).notes > 0 then
    v[#v + 1] = "news"
  end
  return v
end

function RV.View()
  return ui.popup ~= nil and ui.popup.view or "info"
end

-- the place of the open view among the page's tabs (0 = no page)
function RV.ViewIndex()
  local p = ui.popup
  local m = p and ModById(p.id)
  if m == nil then
    return 0
  end
  for k, v in ipairs(RV.Views(m)) do
    if v == p.view then
      return k
    end
  end
  return 0
end

-- open view `v` of the page (its scroll and focus from the start)
function RV.Go(v)
  local p = ui.popup
  if p == nil then
    return
  end
  funcLuaCommand(C.SE, SE_MOVE)
  p.view, p.top, p.full, p.srow, p.szone, p.stop = v, 0, nil, 1, "rows", 0
  Draw()
end

-- the changelog summary of mod `m` in the game's language: {title, notes} (read once per page opening)
function RV.Notes(m)
  local ck = "notes:" .. m.id
  local r = RV.cache[ck]
  if r == nil then
    if lang == nil then
      lang = Call(C.LANG) or 1
    end
    local title, notes = Call(M.NOTES, m.id, lang)
    r = {title = Str(title), notes = CE.Lines(Str(notes))}
    RV.cache[ck] = r
  end
  return r
end

-- the shortcuts of the open view, one per entry: «<glyphs> <what it does>»
function RV.Keys(m)
  local p, v, out = ui.popup, RV.View(), {}
  local function add(glyphs, key)
    out[#out + 1] = (glyphs ~= "" and (glyphs .. " ") or "") .. T(key)
  end
  if p.full then
    add("", "sc_scroll")
    add(K.B, "hint_back")
    return out
  end
  if v == "info" then
    add(K.A, "sc_select")
    add(K.X, "sc_description")
  elseif v == "modules" then
    add(K.A, "sc_module_toggle")
    add(K.Y, "sc_module_page")
  elseif v == "settings" then
    add(K.A, "sc_change")
  elseif v == "conflicts" then
    add(K.R3, "sc_who")
  end
  add(K.L2 .. K.R2, "sc_tabs")
  if m.enabled and m.family == nil and m.id ~= BASE then
    add(K.L1 .. K.R1, "sc_order")
  end
  add(K.B, p.back ~= nil and "hint_back" or "hint_close")
  return out
end

-- A presses the main action button in this view (lit)
function RV.ActionFocused(m)
  local p, v = ui.popup, RV.View()
  if p.full or v == "modules" then
    return false
  end
  if v == "info" then
    return RV.InfoTarget(m).kind == "action"
  end
  if v == "settings" then
    return p.szone == "buttons" or #RV.SetRows(m) == 0
  end
  return true
end

-- The shortcut bar: the view's keys in one line (the game draws each key as the pad's or the keyboard's glyph; a
-- toast takes the line for a while) and the main action button
function RV.Footer(m)
  local y = RV.FootY()
  Quad("P0", SP("night"), G.WIN_X, y, G.WIN_W, G.FOOT_H)
  local s = ui.toast or table.concat(RV.Keys(m), "     ")
  Txt("PL", Cut(s, Fit(G.WIN_W - 400, 0.7)), G.WIN_X + 32, y + G.FOOT_H / 2, 0.7)
  local pb = PopupButtons(m)[1]
  local hot = (mouse.on and mouse.hot == pb.id) or (not mouse.on and RV.ActionFocused(m))
  PopupButton(pb.label, pb.filled, hot, pb.act, pb.id)
end

-- One line of chips from x (wrapping into at most `maxrows` rows of width w): {text, sprite, icon, id, act, foc}.
-- The chip on P0, its icon on P1, its text on PL. Returns the y under the last row.
function RV.Chips(items, x, y, w, maxrows)
  local cx, rows = x, 1
  for _, it in ipairs(items) do
    local tw = math.min(w, math.floor(Units(it.text) * G.PX * 0.68) + (it.icon and 64 or 34))
    if cx > x and cx + tw > x + w then
      rows = rows + 1
      if rows > maxrows then
        break
      end
      cx, y = x, y + 50
    end
    Quad("P0", SP(it.sprite), cx, y, tw, 40)
    local t0 = cx + 17
    if it.icon then
      Quad("P1", SP(it.icon), cx + 10, y + 6, 28, 28)
      t0 = cx + 46
    end
    Txt("PL", Cut(it.text, Fit(tw - (t0 - cx) - 10, 0.68)), t0, y + 20, 0.68)
    if it.foc then
      CE.Focus("P1", cx, y, tw, 40, 3)
    end
    if it.act ~= nil then
      Hit(cx, y, tw, 40, it.id, it.act)
    end
    cx = cx + tw + 10
  end
  return y + 50
end

-- «keeper_scenes» -> «Keeper scenes»: the words of an id
function RV.Words(id)
  local s = string.gsub(id, "[_%.%-]+", " ")
  return (string.gsub(s, "^%l", string.upper))
end

-- «Ofrece a otros mods»: what the mod.toml `provides` (the names other mods can require), in words: the text key
-- `<mod>.provides_<name>` of its text rows, else the installed mod of that id, else the name's words
function RV.Offers(m)
  local out = {}
  for item in string.gmatch(INFO.Provides(m), "[^,]+") do
    local name = string.match(item, "^%s*([%w_%.%-]+)")
    if name ~= nil and KeyOf(name) ~= m.id then
      local s = CE.KeyText(m.id .. ".provides_" .. name)
      if s == "" then
        local o = ModById(name)
        s = (o ~= nil and o.name ~= "") and o.name or RV.Words(name)
      end
      out[#out + 1] = s
    end
  end
  return out
end

-- what the pad can focus in «Información», in its order: the chips of the requirements that are installed, «Ver
-- descripción completa», the main action (the first focus)
function RV.InfoTargets(m)
  local out = {}
  for i, d in ipairs(INFO.Needs(m)) do
    if d.mod ~= nil and i <= 5 then
      out[#out + 1] = {kind = "chip", id = d.mod.id}
    end
  end
  out[#out + 1] = {kind = "desc"}
  out[#out + 1] = {kind = "action"}
  return out
end

function RV.InfoTarget(m)
  local t = RV.InfoTargets(m)
  local p = ui.popup
  p.ifoc = math.max(1, math.min(p.ifoc or #t, #t))
  return t[p.ifoc]
end

-- the pad in «Información»: left / up the previous target, right / down the next
function RV.InfoMove(m, d)
  local t = RV.InfoTargets(m)
  local p = ui.popup
  local k = math.max(1, math.min(#t, (p.ifoc or #t) + d))
  funcLuaCommand(C.SE, k ~= p.ifoc and SE_MOVE or SE_NG)
  p.ifoc = k
  Draw()
end

-- «Información»: «Qué hace» (the changelog summary's first points, else the description) at the left with one
-- warning and «Ver descripción completa»; «Necesita» (a chip per requirement: green = met, red = missing / off / too
-- old; A or a click opens that mod's page), «Ofrece a otros mods» and «Etiquetas» at the right
function RV.DrawInfo(m)
  if ui.popup.full then
    RV.DrawFull(m)
    return
  end
  local top, foot = RV.BodyY() + 34, RV.FootY()
  local lx, lw = G.WIN_X + 40, 700
  local rx = G.WIN_X + 800
  local rw = G.WIN_X + G.WIN_W - 40 - rx
  local target = RV.InfoTarget(m)
  local pad = not mouse.on
  Quad("P0", SP("line"), rx - 32, top - 14, 2, foot - top - 10)
  Txt("PL", "[CN]" .. T("what_it_does") .. "[C]", lx, top, 0.86)
  local y, ylim = top + 46, foot - 130
  local notes = RV.Notes(m).notes
  if #notes > 0 then
    for i = 1, math.min(5, #notes) do
      local ls = Wrap(notes[i], Fit(lw - 30, 0.74), 2)
      if y + (#ls - 1) * 30 > ylim then
        break
      end
      for j, l in ipairs(ls) do
        Txt("PL", (j == 1 and "[CN]›[C]  " or "") .. "[CB]" .. l .. "[C]", lx + (j == 1 and 0 or 25), y + (j - 1) * 30, 0.74)
      end
      y = y + #ls * 30 + 10
    end
  else
    local desc = INFO.Description(m)
    for _, l in ipairs(Wrap(desc ~= "" and desc or T("no_desc"), Fit(lw, 0.74), 8)) do
      Txt("PL", (desc ~= "" and "[CB]" or "[CWG]") .. l .. "[C]", lx, y, 0.74)
      y = y + 30
    end
  end
  -- one warning (not loaded, a requirement, shared files) above the button; «Ver descripción completa» lists them all
  local warn = (m.enabled and m.state == 1) and {true, T("state_skip", {r = Text(m, 1)})} or Warnings(m)[1]
  if warn ~= nil then
    local wy = foot - 110
    Quad("P1", SP(warn[1] and "warn_r" or "warn_a"), lx, wy - 14, 28, 28)
    Txt("PL", (warn[1] and "[CR]" or "[CY]") .. Cut(warn[2], Fit(lw - 40, 0.66)) .. "[C]", lx + 38, wy, 0.66)
  end
  local bw, bh, by = 430, 46, foot - 74
  local foc = (mouse.on and mouse.hot == "pfull") or (pad and target.kind == "desc")
  Quad("P1", SP(foc and "btn_off_sel" or "btn_off"), lx, by, bw, bh)
  Txt("PC", "[CN]" .. K.X .. " " .. Cut(T("full_desc"), Fit(bw - 70, 0.72)) .. "[C]", lx + bw / 2, by + bh / 2, 0.72)
  Hit(lx, by, bw, bh, "pfull", function() RV.OpenFull() end)
  -- «Necesita»
  Txt("PL", "[CN]" .. T("f_needs") .. "[C]", rx, top, 0.86)
  y = top + 26
  local needs = INFO.Needs(m)
  if #needs == 0 then
    Txt("PL", "[CWG]" .. T("needs_none") .. "[C]", rx, y + 20, 0.72)
    y = y + 50
  else
    local items = {}
    for i, d in ipairs(needs) do
      if i > 5 then
        break
      end
      local it = {text = d.ok and d[1] or (d[1] .. "  ·  " .. d.reason), sprite = d.ok and "pill_green" or "pill_red",
                  icon = d.ok and "ok" or "no"}
      if d.mod ~= nil then
        local id = d.mod.id
        it.id = "need" .. i
        it.act = function() RV.OpenChild(id) end
        it.foc = (mouse.on and mouse.hot == it.id) or (pad and target.kind == "chip" and target.id == id)
      end
      items[#items + 1] = it
    end
    y = RV.Chips(items, rx, y, rw, 2)
  end
  -- «Ofrece a otros mods»
  y = y + 18
  Txt("PL", "[CN]" .. T("offers") .. "[C]", rx, y, 0.86)
  local offers = RV.Offers(m)
  local ls = Wrap(#offers > 0 and table.concat(offers, "  ·  ") or T("offers_none"), Fit(rw, 0.72), 3)
  for i, l in ipairs(ls) do
    Txt("PL", (#offers > 0 and "[CB]" or "[CWG]") .. l .. "[C]", rx, y + 40 + (i - 1) * 30, 0.72)
  end
  y = y + 40 + #ls * 30 + 10
  -- «Etiquetas»
  Txt("PL", "[CN]" .. T("f_tags") .. "[C]", rx, y, 0.86)
  local tags = {}
  for i, t in ipairs(CE.ModTags(m)) do
    if i > 4 then
      break
    end
    tags[#tags + 1] = {text = t, sprite = "pill_blue"}
  end
  if #tags == 0 then
    Txt("PL", "[CWG]" .. INFO.DASH .. "[C]", rx, y + 40, 0.72)
  else
    RV.Chips(tags, rx, y + 22, rw, 2)
  end
end

-- «Ver descripción completa» (X, or A / a click on the button): the page's body shows the whole description, then the
-- technical details (folder, requirements, incompatibilities, what it provides, native permissions) and every
-- warning; up / down or the wheel scroll (left / right a page), B goes back to «Información»
function RV.OpenFull()
  local p = ui.popup
  if p == nil or p.view ~= "info" then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  funcLuaCommand(C.SE, SE_OK)
  p.full, p.ftop = true, 1
  Draw()
end

-- the mod's folder under the game's mods folder, with «/» (the game's text reads a backslash as an escape: «\n» of
-- «mods\new_animations» was a line break)
function RV.Folder(m)
  local f = Str(Call(M.FOLDER, m.id))
  return "mods/" .. (f ~= "" and f or m.id)
end

-- the lines of the whole description and the technical details (read once per page opening)
function RV.FullLines(m)
  local ck = "full:" .. m.id
  if RV.cache[ck] ~= nil then
    return RV.cache[ck]
  end
  local w = Fit(G.WIN_W - 100, 0.74)
  local out = {}
  local _, _, all = INFO.Description(m)
  for _, l in ipairs(Wrap(all ~= "" and all or T("no_desc"), w, 1000)) do
    out[#out + 1] = l ~= "" and ((all ~= "" and "[CB]" or "[CWG]") .. l .. "[C]") or ""
  end
  out[#out + 1] = ""
  out[#out + 1] = "[CN]" .. T("details_tech") .. "[C]"
  local function field(label, value)
    if value ~= "" then
      for _, l in ipairs(Wrap(label .. ": " .. value, w, 6)) do
        out[#out + 1] = "[CWG]" .. l .. "[C]"
      end
    end
  end
  field(T("f_folder"), RV.Folder(m))
  field(T("f_requires"), INFO.Requires(m))
  field(T("f_conflicts"), (string.gsub(Text(m, 3), "\n", ", ")))
  field(T("f_provides"), INFO.Provides(m))
  field(T("f_permissions"), INFO.Perms(m))
  local ws = {}
  if m.enabled and m.state == 1 then
    ws[#ws + 1] = {true, T("state_skip", {r = Text(m, 1)})}
  end
  for _, x in ipairs(Warnings(m)) do
    ws[#ws + 1] = x
  end
  for l in string.gmatch(Str(Call(M.AU_NOTES, m.id)), "[^\n]+") do
    local wf, tx = string.match(l, "^(%d)|(.*)$")
    if tx ~= nil then
      ws[#ws + 1] = {wf == "1", T("au_note", {t = tx})}
    end
  end
  for _, x in ipairs(ws) do
    for _, l in ipairs(Wrap(x[2], w, 3)) do
      out[#out + 1] = (x[1] and "[CR]" or "[CY]") .. l .. "[C]"
    end
  end
  RV.cache[ck] = out
  return out
end

-- The page control of a paged list, right-aligned at xr on line y: «↑ <left key>  1-9 de 11  <right key> ↓» (the arrow
-- blue when there is a page that way, grey when not; nothing when everything fits). A click on its left half goes a
-- page back, on its right half a page forward (its width estimated: the text layers anchor on the right).
function RV.Pager(xr, y, first, last, total, prev, next)
  if total <= last - first + 1 then
    return
  end
  local back, fwd = first > 1, last < total
  local s = (back and "[CN]↑[C]" or "[CWG]↑[C]") .. " " .. K.LEFT .. "  [CB]" ..
            T("report_rows", {n = first, c = last, t = total}) .. "[C]  " .. K.RIGHT .. " " .. (fwd and "[CN]↓[C]" or "[CWG]↓[C]")
  Txt("PR", s, xr, y, 0.66)
  local w = math.floor(Units(s) * G.PX * 0.66 * 0.82)
  Hit(xr - w, y - 20, w / 2, 40, "pgback", function()
    if back then prev() else funcLuaCommand(C.SE, SE_NG) end
  end)
  Hit(xr - w / 2, y - 20, w / 2, 40, "pgnext", function()
    if fwd then next() else funcLuaCommand(C.SE, SE_NG) end
  end)
end

function RV.DrawFull(m)
  local p = ui.popup
  local lines = RV.FullLines(m)
  local x, top = G.WIN_X + 40, RV.BodyY() + 34
  local y0, vis = top + 50, RV.FULL_ROWS
  p.ftop = math.max(1, math.min(p.ftop or 1, math.max(1, #lines - vis + 1)))
  Txt("PL", "[CN]" .. T("full_desc_title") .. "[C]", x, top, 0.86)
  RV.Pager(G.WIN_X + G.WIN_W - 40, top, p.ftop, math.min(#lines, p.ftop + vis - 1), #lines, function()
    p.ftop = math.max(1, p.ftop - vis)
    funcLuaCommand(C.SE, SE_MOVE)
    Draw()
  end, function()
    p.ftop = p.ftop + vis
    funcLuaCommand(C.SE, SE_MOVE)
    Draw()
  end)
  for i = 0, vis - 1 do
    local l = lines[p.ftop + i]
    if l == nil then
      break
    end
    Txt("PL", l, x, y0 + i * 30, 0.74)
  end
end

-- ---- «Módulos»: one row per module (a module mod of the family, or an internal module = an option row named in
-- [modules] options): its badge (icon or two letters), name, version and Sí / No; a module whose requirement is not
-- met shows it in red next to its state and is greyed (it cannot be switched on). A or a click on Sí / No switches
-- it, Y or a click on the row opens a module mod's own page.

-- the module rows of mod `m`: {mod = module mod} or {opt = option row} (read once per page opening)
function RV.ModuleRows(m)
  local ck = "mrows:" .. m.id
  local r = RV.cache[ck]
  if r == nil then
    r = {}
    for _, o in ipairs(RV.Settings(m.id)) do
      if o.module ~= nil then
        r[#r + 1] = {mod = o.module}
      elseif o.imodule then
        r[#r + 1] = {opt = o}
      end
    end
    RV.cache[ck] = r
  end
  return r
end

function RV.ModuleOn(r)
  if r.mod ~= nil then
    return r.mod.enabled
  end
  local v = RV.Value(r.opt)
  return v ~= nil and v ~= 0
end

function RV.ModulesOn(m)
  local n = 0
  for _, r in ipairs(RV.ModuleRows(m)) do
    if RV.ModuleOn(r) then
      n = n + 1
    end
  end
  return n
end

-- the first requirement of module mod `mm` that is not met (missing, off or too old), by name; nil = all met. Its
-- parent is not counted (switching the module on brings its parent)
function RV.ModuleNeed(mm)
  for _, d in ipairs(INFO.Needs(mm)) do
    if not d.ok and (mm.family == nil or d.key ~= mm.family.id) then
      return d.name
    end
  end
  return nil
end

function RV.DrawModuleRow(m, n, r, x, y, w, h, foc)
  local mm = r.mod
  local name
  if mm ~= nil then
    name = mm.mname or (mm.name ~= "" and mm.name or mm.id)
  else
    name = RV.TextOf(r.opt.label, r.opt.fallback ~= "" and r.opt.fallback or r.opt.key)
  end
  local on = RV.ModuleOn(r)
  local need = mm ~= nil and RV.ModuleNeed(mm) or nil
  local grey = need ~= nil and not on
  local cy = y + h / 2
  Quad("P0", SP(foc and "row_sel" or (grey and "row_off" or "row")), x, y, w, h)
  Hit(x, y, w, h, "mrow" .. n, function()
    ui.popup.mrow = n
    if mm ~= nil then
      RV.OpenChild(mm.id)
    else
      RV.ModuleToggle(m, n)
    end
  end)
  -- the badge: the module's icon, else its two letters
  local ic = mm ~= nil and IconOf(mm) or nil
  if ic ~= nil then
    Quad("P1", ic[2], x + 14, cy - 17, 34, 34, grey and 0.6 or 1, ic[1])
  else
    Quad("P1", SP("iconbox"), x + 14, cy - 17, 34, 34, grey and 0.6 or 1)
    Txt("PC", "[CWG]" .. Initials({name = name, id = name}) .. "[C]", x + 31, cy - 1, 0.5)
  end
  Txt("PL", (grey and "[CWG]" or "[CB]") .. Cut(name, Fit(w * 0.5 - 80, 0.8)) .. "[C]", x + 64, cy, 0.8)
  if mm ~= nil and mm.version ~= "" then
    Txt("PL", "[CWG]v" .. Cut(mm.version, 12) .. "[C]", x + math.floor(w * 0.52), cy, 0.66)
  end
  local pw = 150
  local px = x + w - 16 - pw
  if need ~= nil then
    -- a short red tag right before the state (its width estimated: the text layers anchor on the left)
    local x0 = x + math.floor(w * 0.62)
    local tag = Cut(T("module_needs", {o = need}), Fit(px - 24 - x0, 0.62))
    Txt("PL", "[CR]" .. tag .. "[C]", math.max(x0, px - 18 - math.floor(Units(tag) * G.PX * 0.62 * 0.82)), cy, 0.62)
  end
  local pend = mm ~= nil and mm.pending
  Quad("P1", SP(pend and "pill_amber" or (on and "pill_green" or "pill_grey")), px, cy - 16, pw, 32, grey and 0.7 or 1)
  Txt("PC", T(on and "module_yes" or "module_no"), px + pw / 2, cy, 0.64)
  Hit(px - 4, cy - 20, pw + 8, 40, "mtog" .. n, function()
    ui.popup.mrow = n
    RV.ModuleToggle(m, n)
  end)
end

function RV.DrawModules(m)
  local p = ui.popup
  local rows = RV.ModuleRows(m)
  local x, w = G.WIN_X + 32, G.WIN_W - 64
  local top = RV.BodyY() + 30
  -- «N módulos (K activos) · size + the modules' size»
  local msize = 0
  for _, mm in ipairs(m.modules or {}) do
    msize = msize + (mm.size or 0)
  end
  local head = T("modules_head", {n = #rows, k = RV.ModulesOn(m)}) .. "  ·  " ..
               (msize > 0 and T("modules_size", {s = Size(m.size), z = Size(msize)}) or Size(m.size))
  Txt("PL", "[CB]" .. Cut(head, Fit(w - 200, 0.74)) .. "[C]", x, top, 0.74)
  local vis, y0, step, h = RV.MOD_ROWS, top + 28, 51, 45
  p.mrow = math.max(1, math.min(p.mrow or 1, #rows))
  local mtop = math.max(1, math.min(p.mtop or 1, p.mrow))
  if p.mrow >= mtop + vis then
    mtop = p.mrow - vis + 1
  end
  p.mtop = mtop
  for k = 0, vis - 1 do
    local n = mtop + k
    local r = rows[n]
    if r == nil then
      break
    end
    local foc = (mouse.on and (mouse.hot == "mrow" .. n or mouse.hot == "mtog" .. n)) or (not mouse.on and n == p.mrow)
    RV.DrawModuleRow(m, n, r, x, y0 + k * step, w, h, foc)
  end
  -- the pages of the list above the rows: ↑ / ↓ and the keys that turn them (left / right)
  RV.Pager(x + w, top, mtop, math.min(#rows, mtop + vis - 1), #rows, function()
    p.mtop = math.max(1, mtop - vis)
    p.mrow = p.mtop
    funcLuaCommand(C.SE, SE_MOVE)
    Draw()
  end, function()
    p.mtop = math.min(mtop + vis, #rows - vis + 1)
    p.mrow = p.mtop
    funcLuaCommand(C.SE, SE_MOVE)
    Draw()
  end)
end

-- ---- «Novedades»: the mod's changelog summary (its title and every point), scrolled with up / down
function RV.NewsLines(m)
  local out = {}
  for _, n in ipairs(RV.Notes(m).notes) do
    for i, l in ipairs(Wrap(n, Fit(G.WIN_W - 120, 0.74), 8)) do
      out[#out + 1] = {first = i == 1, text = l}
    end
  end
  return out
end

function RV.DrawNews(m)
  local p = ui.popup
  local r = RV.Notes(m)
  local x, w = G.WIN_X + 40, G.WIN_W - 80
  local y = RV.BodyY() + 34
  Txt("PL", "[CN]" .. Cut(r.title ~= "" and r.title or T("btn_news"), Fit(w - 200, 0.86)) .. "[C]", x, y, 0.86)
  local lines = RV.NewsLines(m)
  if #lines == 0 then
    Txt("PL", "[CWG]" .. T("news_none") .. "[C]", x, y + 50, 0.78)
    return
  end
  p.top = math.max(0, math.min(p.top or 0, #lines - RV.NEWS_ROWS))
  for i = 1, math.min(RV.NEWS_ROWS, #lines - p.top) do
    local l = lines[p.top + i]
    local ly = y + 46 + (i - 1) * 32
    if l.first then
      Txt("PL", "[CN]›[C]", x, ly, 0.74)
    end
    Txt("PL", "[CB]" .. l.text .. "[C]", x + 26, ly, 0.74)
  end
  if #lines > RV.NEWS_ROWS then
    Txt("PR", "[CWG]" .. T("report_rows", {n = p.top + 1, c = math.min(p.top + RV.NEWS_ROWS, #lines), t = #lines}) .. "[C]",
        G.WIN_X + G.WIN_W - 40, y, 0.62)
  end
end

-- the mod has report entries `native_update` (a code site not found on an unknown game build)
function M.NeedsUpdate(id)
  for _, e in ipairs(RV.Of(id).problems) do
    if e.code == "native_update" then
      return true
    end
  end
  return false
end

-- the group of an entry: the core's category (6th extra return of REPORT_ROW), else from the severity (an older core)
function RV.Cat(e)
  if e.cat ~= "" then
    return e.cat
  end
  if e.code == "conflict" then
    return "conflict"
  end
  return e.sev == "error" and "error" or (e.sev == "warn" and "warning" or "info")
end

-- the header of a code's group: its row in the player's language, else the core's English hint, else the code
function RV.Head(e)
  local k = "rc_" .. e.code
  local s = T(k)
  if s ~= k then
    return s
  end
  return e.hint ~= "" and (e.code .. ": " .. e.hint) or e.code
end

function RV.Of(id)
  local r = RV.cache[id]
  if r ~= nil then
    return r
  end
  r = {problems = {}, conflicts = {}, np = 0}
  local items = {}
  local n = math.min(Int(Call(M.REPORT_COUNT, id)), RV.MAX)
  for i = 0, n - 1 do
    local sev, ty, code, loc, msg, _, key, eid, win, others, cat, hint = Call(M.REPORT_ROW, i, id)
    local e = {sev = Str(sev), ty = Str(ty), code = Str(code), loc = Str(loc), msg = Str(msg), key = Str(key), id = Str(eid),
               win = Str(win), others = Str(others), cat = Str(cat), hint = Str(hint)}
    e.cat = RV.Cat(e)
    if e.cat == "conflict" then
      r.conflicts[#r.conflicts + 1] = e
    elseif RV.ORDER[e.cat] ~= nil then
      items[#items + 1] = e
    end
  end
  table.sort(items, function(a, b)
    if a.cat ~= b.cat then
      return RV.ORDER[a.cat] < RV.ORDER[b.cat]
    end
    if a.code ~= b.code then
      return a.code < b.code
    end
    if a.loc ~= b.loc then
      return a.loc < b.loc
    end
    return a.msg < b.msg
  end)
  local last = nil
  for _, e in ipairs(items) do
    if e.cat .. "/" .. e.code ~= last then
      last = e.cat .. "/" .. e.code
      r.problems[#r.problems + 1] = {hdr = true, cat = e.cat, sev = e.sev, text = RV.Head(e)}
    end
    r.problems[#r.problems + 1] = e
  end
  r.np = #items
  table.sort(r.conflicts, function(a, b)
    if a.id ~= b.id then
      return a.id < b.id
    end
    return a.loc < b.loc
  end)
  RV.cache[id] = r
  return r
end

-- «Cambios en caliente: telop en vivo · table al reiniciar» (CMND_VRFW_REPORT_RELOAD, the reload mode of each type
-- the mod has content of); "" when the core gives none
function RV.Reload(id)
  local ck = "reload:" .. id
  if RV.cache[ck] == nil then
    local parts = {}
    for ty, mode in string.gmatch(Str(Call(M.REPORT_RELOAD, id)), "([%w_]+)=([%w_]+)") do
      parts[#parts + 1] = ty .. " " .. T("rl_" .. mode)
    end
    RV.cache[ck] = #parts > 0 and T("rp_reload", {r = table.concat(parts, " · ")}) or ""
  end
  return RV.cache[ck]
end

-- the label of view `v` in the page's tab row: its name and count («Módulos 6/8», «Problemas 3» with the count in red
-- when there are problems)
function RV.Label(m, v, sel, units)
  local name, n, red = "", nil, false
  if v == "info" then
    name = T("page_info")
  elseif v == "modules" then
    name, n = T("tab_modules"), RV.ModulesOn(m) .. "/" .. #RV.ModuleRows(m)
  elseif v == "problems" then
    name, n = T("tab_problems"), RV.Of(m.id).np
    red = n > 0
  elseif v == "conflicts" then
    name, n = T("tab_conflicts"), #RV.Of(m.id).conflicts
  elseif v == "settings" then
    name, n = T("tab_settings"), #RV.SetRows(m)
  else
    name = T("btn_news")
  end
  local base = sel and "" or "[CWG]"
  local out = base .. Cut(name, units - (n ~= nil and 6 or 0)) .. (sel and "" or "[C]")
  if n ~= nil then
    out = out .. " " .. (red and "[CR]" or base) .. tostring(n) .. ((red or not sel) and "[C]" or "")
  end
  return out
end

-- the row of view tabs under the header band (L2 / R2 like the screen's tabs, or a click)
function RV.Tabs(m)
  local views = RV.Views(m)
  local nv = #views
  local y, h = G.WIN_Y + G.BAND_H, G.VTABS_H
  Quad("P0", SP("tabbar"), G.WIN_X, y, G.WIN_W, h)
  local gx = 60
  local step = math.floor((G.WIN_W - 2 * gx) / nv)
  local w = math.min(260, step - 8)
  local cur = RV.View()
  for k, v in ipairs(views) do
    local x = G.WIN_X + gx + (k - 1) * step + (step - w) / 2
    local sel = v == cur
    local hot = mouse.on and mouse.hot == "view" .. k and not sel
    if sel or hot then
      Quad("P1", SP(sel and "tab_sel" or "tab_hot"), x, y + 6, w, h - 12)
    end
    Txt("PC", RV.Label(m, v, sel, Fit(w - 16, 0.7)), x + w / 2, y + h / 2, 0.7)
    Hit(x, y, w, h, "view" .. k, function()
      if RV.View() ~= v then
        RV.Go(v)
      end
    end)
  end
  Txt("PC", K.L2, G.WIN_X + 30, y + h / 2, 0.9)
  Txt("PC", K.R2, G.WIN_X + G.WIN_W - 30, y + h / 2, 0.9)
end

-- «Problemas» / «Conflictos»: one row per entry (file:line, then the message), a header row per kind of problem in
-- the player's language (what it is, how to fix it); a conflict says who wins and the other mods; never an empty page
function RV.Draw(m, which)
  local r = RV.Of(m.id)
  local list = which == 2 and r.problems or r.conflicts
  local px, py = G.WIN_X + 36, RV.BodyY() + 34
  local foot = py + RV.ROWS * 36
  local rl = which == 2 and RV.Reload(m.id) or ""
  if #list == 0 then
    Txt("PL", "[CN]" .. T(which == 2 and "report_no_problems" or "report_no_conflicts") .. "[C]", px, py, 0.8)
    if which == 3 then
      Txt("PL", "[CWG]" .. K.R3 .. " " .. Cut(T("who_hint"), Fit(G.WIN_W - 120, 0.62)) .. "[C]", px, foot, 0.62)
    end
    if rl ~= "" then
      Txt("PL", "[CWG]" .. Cut(rl, Fit(G.WIN_W - 80, 0.62)) .. "[C]", px, foot, 0.62)
    end
    return
  end
  local top = math.max(0, math.min(ui.popup.top or 0, #list - RV.ROWS))
  ui.popup.top = top
  local last = ""
  for i = 1, math.min(RV.ROWS, #list - top) do
    local e = list[top + i]
    local y = py + (i - 1) * 36
    if e.hdr then
      -- the kind of problem, in the player's language
      last = ""
      Txt("PL", (e.sev == "error" and "[CR]" or "[CY]") .. Cut(e.text, Fit(G.WIN_W - 80, 0.66)) .. "[C]", px, y, 0.66)
    else
      local file = string.match(e.loc, "^(.-):%d+$") or e.loc
      local where = file == last and ("   " .. string.sub(e.loc, #file + 1)) or e.loc
      last = file
      local msg = e.msg
      if which == 3 then
        -- who overrode what: the winner and the other mods' claims
        local who = e.win ~= "" and T("rp_winner", {w = e.win}) or ""
        if e.others ~= "" then
          who = who .. (who ~= "" and " · " or "") .. T("rp_others", {o = e.others})
        end
        if who ~= "" then
          msg = msg .. "  (" .. who .. ")"
        end
      end
      if which == 3 and RV.WhoId(e) ~= "" then
        -- a click on a conflict: who touches its id («¿Quién lo toca?», the same explorer as `vrfw who`)
        Hit(px, y - 18, G.WIN_W - 72, 36, "who" .. (top + i), function() RV.OpenWho(RV.WhoId(e)) end)
        if mouse.on and mouse.hot == "who" .. (top + i) then
          Quad("P1", SP("row_sel"), px - 8, y - 18, G.WIN_W - 72, 36, 0.35)
        end
      end
      Quad("P1", SP(e.sev == "error" and "warn_r" or "warn_a"), px, y - 16, 32, 32)
      Txt("PL", "[CN]" .. Cut(where, Fit(520, 0.66)) .. "[C]", px + 44, y, 0.66)
      Txt("PL", (e.sev == "error" and "[CR]" or "[CB]") .. Cut("[" .. e.ty .. "] " .. msg, Fit(G.WIN_W - 680, 0.66)) .. "[C]", px + 580, y, 0.66)
    end
  end
  if #list > RV.ROWS then
    Txt("PR", "[CWG]" .. T("report_rows", {n = top + 1, c = math.min(top + RV.ROWS, #list), t = #list}) .. "[C]", G.WIN_X + G.WIN_W - 40, foot, 0.62)
  end
  if #list >= RV.MAX then
    Txt("PL", "[CWG]" .. T("report_more") .. "[C]", px, foot, 0.62)
  elseif which == 3 then
    Txt("PL", "[CWG]" .. K.R3 .. " " .. Cut(T("who_hint"), Fit(G.WIN_W - 480, 0.62)) .. "[C]", px, foot, 0.62)
  elseif rl ~= "" then
    Txt("PL", "[CWG]" .. Cut(rl, Fit(G.WIN_W - 400, 0.62)) .. "[C]", px, foot, 0.62)
  end
end

-- ---- «¿Quién lo toca?»: the conflict explorer of `vrfw who` in the panel ------------------------------------
-- From «Conflictos»: R3 (the first conflict on the page, else an empty search) or a click on a conflict opens a list
-- page with the id in its search box (the top row, like the other tabs): every mod that touches the id, in load
-- order, one header per mod (its load position; «gana» on the winner), its lines under it (file:line on the right;
-- a line that only refers to the id is grey), then the report's entries about it. The search box takes another id.
-- One function behind it and `vrfw who`: vr_core::diagnose::who_in (CMND_VRFW_REPORT_WHO / _ROW).

-- the id a conflict entry is about ("" = none)
function RV.WhoId(e)
  if e.id ~= nil and e.id ~= "" then
    return e.id
  end
  return e.key or ""
end

function RV.OpenWho(id)
  funcLuaCommand(C.SE, SE_OK)
  StartCo(function() RV.WhoFlow(id) end)
end

-- ---- «Ajustes»: the mod's own settings ---------------------------------------------------
-- The rows a mod declares in its options.toml (mod_options, CMND_EVT_OPT_*), the ones whose key starts with "<mod>.":
-- the same rows, values and storage as Opciones › «Opciones de mods» (one store: <data dir>\mod_options\<mod>.json, or
-- the owner's get / set commands). Only the mods active at this start have rows (the registry is built at boot).
-- (functions of RV: the main chunk is at Lua's limit of 200 locals)
RV.OPT = {ROWS = Crc("CMND_VRFW_OPTION_ROWS"), ROW = Crc("CMND_VRFW_OPTION_ROW"), GET = Crc("CMND_VRFW_OPTION_GET"),
          SET = Crc("CMND_VRFW_OPTION_SET"), STEP = Crc("CMND_VRFW_OPTION_STEP"), TEXT = Crc("CMND_VRFW_OPTION_TEXT")}

-- the settings of mod `id`, read once per page opening (RV.cache is emptied by OpenDetails)
function RV.Settings(id)
  local ck = "settings:" .. id
  local r = RV.cache[ck]
  if r ~= nil then
    return r
  end
  local opts = {}
  local pre = id .. "."
  for i = 1, Int(Call(RV.OPT.ROWS)) do
    local k, kind, storage, label, fallback, get, set = Call(RV.OPT.ROW, i)
    if type(k) == "string" and string.sub(k, 1, #pre) == pre then
      opts[#opts + 1] = {key = k, kind = Str(kind), storage = Str(storage), label = Int(label), fallback = Str(fallback),
                         get = Int(get), set = Int(set)}
    end
  end
  -- the «Modules» first: the module mods of its family (on / off = the mod switched
  -- on / off), then its internal modules (option rows named in [modules] options), then the other settings
  r = {}
  local m = ModById(id)
  if m ~= nil then
    for _, mm in ipairs(m.modules or {}) do
      r[#r + 1] = {module = mm, key = mm.id}
    end
    for _, key in ipairs(m.internal or {}) do
      for k, o in ipairs(opts) do
        if o.key == key then
          o.imodule = true
          r[#r + 1] = table.remove(opts, k)
          break
        end
      end
    end
  end
  for _, o in ipairs(opts) do
    r[#r + 1] = o
  end
  RV.cache[ck] = r
  return r
end

-- the mod has a «Modules» list (module mods of its family or internal modules)
function RV.HasModules(m)
  return #(m.modules or {}) > 0 or #(m.internal or {}) > 0
end

-- a menu_text row in the game's language, else the fallback
function RV.TextOf(id, fallback)
  if id ~= nil and id ~= 0 then
    local s = Call(C.TEXT_GET, id)
    if type(s) == "string" and s ~= "" then
      return s
    end
  end
  return fallback
end

-- (value, changeable): nil for a row with its own Lua behaviour or a value nobody answers
function RV.Value(r)
  if r.module ~= nil then
    return r.module.enabled and 1 or 0, true      -- a module mod: on = switched on
  end
  if r.kind == "lua" or r.storage == "lua" then
    return nil, false
  end
  if r.storage == "command" then
    local v, extra = Call(r.get)
    if type(v) == "number" then
      return v, true
    end
    if type(v) == "boolean" and (v or extra ~= nil) then
      return v and 1 or 0, true
    end
    return nil, false
  end
  local v, dv = Call(RV.OPT.GET, r.key, true)  -- the real value (a child row of a «llave» whose parent is off: greyed)
  if type(v) == "number" then
    return v, true
  end
  if v == false and type(dv) == "number" then
    return dv, false          -- enabled_if not met / parent off: shown greyed, no changes
  end
  return nil, false
end

function RV.Fmt(r, v)
  if r.module ~= nil then
    local k = v == 1 and "module_on" or "module_off"
    return T(r.module.pending and (k .. "_next") or k)
  end
  local id, fb = Call(RV.OPT.TEXT, r.key, v)
  if type(id) ~= "number" then
    return tostring(v)
  end
  local s = RV.TextOf(id, Str(fb))
  return s ~= "" and s or tostring(v)
end

-- the selected row's (or `row`'s) value one step in direction `dir` (±1), stored where the row keeps it
function RV.Change(m, dir, row)
  local r = row or RV.SetRows(m)[ui.popup.srow or 1]
  if r ~= nil and r.module ~= nil then
    return RV.ToggleModule(r.module)
  end
  local v, live = nil, false
  if r ~= nil then
    v, live = RV.Value(r)
  end
  local ok, n = false, nil
  if v ~= nil and live then
    n = Call(RV.OPT.STEP, r.key, v, dir)
    if type(n) == "number" and n ~= v then
      if r.storage == "command" then
        ok = Call(r.set, n) == true
      else
        ok = Call(RV.OPT.SET, r.key, n) == true
      end
    end
  end
  funcLuaCommand(C.SE, ok and SE_MOVE or SE_NG)
  if ok then
    Log("setting", r.key, tostring(n))
  end
  Draw()
end

-- The «Módulos» view as cards: each module (a module mod of the family, or an internal module = an option
-- row named in [modules] options) is a card with its name, a short description and a tick box that shows whether it is
-- on; two cards a line. The mod's own settings follow as rows with their current value in a ◀ ▶ box. The page scrolls
-- by lines. RV.Layout(m) -> lines {kind = "head" | "cards" | "row", h = height, items = {row numbers}, text}
RV.CARD_H, RV.CARD_GAP, RV.HEAD_H, RV.ROW_H = 100, 12, 44, 62

function RV.Layout(m)
  local rows = RV.SetRows(m)
  local lines, pending = {}, nil
  local function flush()
    if pending ~= nil then
      lines[#lines + 1] = {kind = "cards", h = RV.CARD_H + RV.CARD_GAP, items = pending}
      pending = nil
    end
  end
  local nmods = 0
  for n, r in ipairs(rows) do
    if r.module ~= nil or r.imodule then
      nmods = nmods + 1
      if n == 1 then
        lines[#lines + 1] = {kind = "head", h = RV.HEAD_H, text = T("section_modules")}
      end
      pending = pending or {}
      pending[#pending + 1] = n
      if #pending == 2 then
        flush()
      end
    else
      flush()
      if nmods > 0 and n == nmods + 1 then
        lines[#lines + 1] = {kind = "head", h = RV.HEAD_H, text = T("section_settings")}
      end
      lines[#lines + 1] = {kind = "row", h = RV.ROW_H, items = {n}}
    end
  end
  flush()
  return lines
end

-- the line and column of row number n in `lines`
function RV.Where(lines, n)
  for li, l in ipairs(lines) do
    for c, it in ipairs(l.items or {}) do
      if it == n then
        return li, c
      end
    end
  end
  return nil, nil
end

-- the next line with items from line `li` in direction d (±1), or nil
function RV.NextLine(lines, li, d)
  local k = li + d
  while lines[k] ~= nil and lines[k].kind == "head" do
    k = k + d
  end
  return lines[k] ~= nil and k or nil
end

-- A / a click on row n: a module card switches on / off, a setting moves one step
function RV.Activate(m, n)
  local r = RV.SetRows(m)[n]
  if r == nil then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  ui.popup.srow, ui.popup.szone = n, "rows"
  if r.module ~= nil then
    RV.ToggleModule(r.module)
  else
    RV.Change(m, 1)
  end
end

-- The pad in the «Módulos» / «Ajustes» view. Rows zone: up / down move between lines (cards, setting rows; down from
-- the last line goes to the footer buttons), left / right move between the two cards of a line or change a setting's
-- value. Buttons zone: left / right walk the buttons, up goes back to the last line. false = no rows (the keys keep
-- walking the buttons as in the other views).
function RV.SettingsKey(id)
  local m = ModById(ui.popup.id)
  local rows = m and RV.SetRows(m) or {}
  if #rows == 0 then
    return false
  end
  local p = ui.popup
  local lines = RV.Layout(m)
  local function moved(ok)
    funcLuaCommand(C.SE, ok and SE_MOVE or SE_NG)
    Draw()
  end
  if p.szone == "buttons" then
    if id == FN.UP then
      local li = RV.NextLine(lines, #lines + 1, -1)
      p.szone, p.srow = "rows", li and lines[li].items[1] or 1
      moved(true)
    elseif id == FN.LEFT or id == FN.RIGHT then
      local n = #PopupButtons(m)
      local b = math.max(1, math.min(n, (p.btn or 1) + (id == FN.LEFT and -1 or 1)))
      local ok = b ~= p.btn
      p.btn = b
      moved(ok)
    else
      moved(false)
    end
    return true
  end
  local sel = math.max(1, math.min(p.srow or 1, #rows))
  local li, col = RV.Where(lines, sel)
  if li == nil then
    li, col = RV.NextLine(lines, 0, 1), 1
  end
  local line = lines[li]
  if id == FN.UP or id == FN.DOWN then
    local k = RV.NextLine(lines, li, id == FN.UP and -1 or 1)
    if k == nil then
      if id == FN.DOWN and #PopupButtons(m) > 0 then
        p.szone = "buttons"
        p.btn = math.max(1, math.min(#PopupButtons(m), p.btn or 1))
        moved(true)
      else
        moved(false)
      end
      return true
    end
    local its = lines[k].items
    p.srow = its[math.min(col or 1, #its)]
    moved(true)
  elseif line ~= nil and line.kind == "cards" then
    -- left / right between the two cards of the line
    local c = (col or 1) + (id == FN.LEFT and -1 or 1)
    if line.items[c] ~= nil then
      p.srow = line.items[c]
      moved(true)
    else
      moved(false)
    end
  else
    p.srow = sel
    RV.Change(m, id == FN.LEFT and -1 or 1)
  end
  return true
end

-- a module card: plate (focus frame when focused), tick box (green tick = on), name, short description, state
function RV.DrawCard(m, n, r, x, y, w, focused)
  local name, desc, on, s
  if r.module ~= nil then
    local mm = r.module
    name = mm.mname or (mm.name ~= "" and mm.name or mm.id)
    desc = string.match(Text(mm, 0), "^%s*([^\n]*)") or ""
    on = mm.enabled
    s = RV.Fmt(r, on and 1 or 0)
  else
    name = RV.TextOf(r.label, r.fallback ~= "" and r.fallback or r.key)
    desc = T("module_internal")
    local v = RV.Value(r)
    on = v ~= nil and v ~= 0
    s = v ~= nil and T(on and "module_on" or "module_off") or T("set_unknown")
  end
  local h = RV.CARD_H
  Quad("P0", SP((on and "hcard" or "hcard_off") .. (focused and "_sel" or "")), x, y, w, h)
  if on then
    Quad("P1", SP("ok"), x + 22, y + h / 2 - 20, 40, 40)
  else
    Quad("P1", SP(focused and "opt_sel" or "opt"), x + 22, y + h / 2 - 20, 40, 40)
  end
  local tx, tw = x + 82, w - 102
  Txt("PL", "[CB]" .. Cut(name, Fit(tw, 0.82)) .. "[C]", tx, y + 27, 0.82)
  if desc ~= "" then
    Txt("PL", "[CWG]" .. Cut(desc, Fit(tw, 0.6)) .. "[C]", tx, y + 54, 0.6)
  end
  local pend = r.module ~= nil and r.module.pending
  Txt("PL", (pend and "[CY]" or (on and "[CN]" or "[CWG]")) .. Cut(s, Fit(tw, 0.62)) .. "[C]", tx, y + 79, 0.62)
  Hit(x, y, w, h, "set" .. n, function() RV.Activate(m, n) end)
end

-- a setting row: its label and its current value in a ◀ ▶ box (greyed when it cannot change now)
function RV.DrawRow(m, n, r, x, y, w, focused)
  local h = RV.ROW_H - 6
  Quad("P0", SP(focused and "row_sel" or "row"), x, y, w, h)
  local label = RV.TextOf(r.label, r.fallback ~= "" and r.fallback or r.key)
  Txt("PL", "[CB]" .. Cut(label, Fit(w - 400, 0.8)) .. "[C]", x + 28, y + h / 2, 0.8)
  local v, live = RV.Value(r)
  local bx = x + w - 330
  if r.kind == "lua" or r.storage == "lua" then
    Txt("PL", "[CWG]" .. Cut(T("set_lua"), Fit(310, 0.7)) .. "[C]", bx, y + h / 2, 0.7)
  elseif v == nil then
    Txt("PL", "[CWG]" .. T("set_unknown") .. "[C]", bx, y + h / 2, 0.74)
  else
    Quad("P1", SP((focused and live) and "val_sel" or "val"), bx, y + (h - 46) / 2, 300, 46)
    Txt("PL", (live and "[CB]" or "[CWG]") .. Cut(RV.Fmt(r, v), Fit(220, 0.74)) .. "[C]", bx + 40, y + h / 2, 0.74)
  end
  Hit(x, y, w, h, "set" .. n, function() RV.Activate(m, n) end)
end

function RV.DrawSettings(m)
  local rows = RV.SetRows(m)
  local px, py = G.WIN_X + 40, RV.BodyY() + 24
  local w = G.WIN_W - 80
  if #rows == 0 then
    local why = (m.enabled and m.state == 0 and not m.pending) and "set_none" or "set_inactive"
    for i, l in ipairs(Wrap(T(why), Fit(w, 0.8), 3)) do
      Txt("PL", "[CN]" .. l .. "[C]", px, py + 16 + (i - 1) * 34, 0.8)
    end
    return
  end
  local p = ui.popup
  local sel = math.max(1, math.min(p.srow or 1, #rows))
  p.srow = sel
  local lines = RV.Layout(m)
  local bottom = RV.FootY() - 44     -- above the note line and the shortcut bar
  local avail = bottom - py
  -- scroll: the selected line on the page (with its section title when it is right above)
  local sl = RV.Where(lines, sel) or 1
  local top = math.max(1, math.min(p.stop or 1, #lines))
  if sl < top then
    top = sl
  end
  if top > 1 and lines[top - 1].kind == "head" and top - 1 <= sl then
    top = top - 1
  end
  local function fits(a, b)
    local hsum = 0
    for k = a, b do
      hsum = hsum + lines[k].h
    end
    return hsum <= avail
  end
  while top < sl and not fits(top, sl) do
    top = top + 1
  end
  p.stop = top
  local cw = (w - 16) / 2
  local y, first, last = py, nil, nil
  for k = top, #lines do
    local l = lines[k]
    if y + l.h > bottom + RV.CARD_GAP then
      break
    end
    if l.kind == "head" then
      Txt("PL", "[CN]" .. Cut(l.text, Fit(w, 0.8)) .. "[C]", px, y + RV.HEAD_H / 2, 0.8)
    else
      for c, n in ipairs(l.items) do
        first, last = first or n, n
        local foc = (mouse.on and mouse.hot == "set" .. n) or (not mouse.on and p.szone ~= "buttons" and n == sel)
        if l.kind == "cards" then
          RV.DrawCard(m, n, rows[n], px + (c - 1) * (cw + 16), y, cw, foc)
        else
          RV.DrawRow(m, n, rows[n], px, y, w, foc)
        end
      end
    end
    y = y + l.h
  end
  -- more lines above / below: where the page is
  local note = T("set_note")
  if first ~= nil and (first > 1 or last < #rows) then
    note = T("report_rows", {n = first, c = last, t = #rows}) .. "   " .. note
  end
  Txt("PL", "[CWG]" .. Cut(note, Fit(w, 0.62)) .. "[C]", px, bottom + 22, 0.62)
end

-- the «Ajustes» rows of mod `m`: its settings without the modules (those are the «Módulos» view)
function RV.SetRows(m)
  local ck = "setrows:" .. m.id
  local r = RV.cache[ck]
  if r == nil then
    r = {}
    for _, o in ipairs(RV.Settings(m.id)) do
      if o.module == nil and not o.imodule then
        r[#r + 1] = o
      end
    end
    RV.cache[ck] = r
  end
  return r
end

local function DrawDetails()
  local m = ModById(ui.popup.id)
  while m == nil and ui.popup ~= nil do
    -- the mod is gone from the list (a rescan): the page under it, else none
    ui.popup = ui.popup.back
    m = ui.popup and ModById(ui.popup.id)
  end
  if m == nil then
    return
  end
  local known = false
  for _, v in ipairs(RV.Views(m)) do
    known = known or v == ui.popup.view
  end
  if not known then
    ui.popup.view = "info"
  end
  PopupWindow(m)
  RV.Tabs(m)
  local v = ui.popup.view
  if v == "info" then
    RV.DrawInfo(m)
  elseif v == "modules" then
    RV.DrawModules(m)
  elseif v == "settings" then
    RV.DrawSettings(m)
  elseif v == "news" then
    RV.DrawNews(m)
  else
    RV.Draw(m, v == "problems" and 2 or 3)
  end
  RV.Footer(m)
end

-- ---- a page in the content area (the «¿Quién lo toca?» list; the tabs are locked) -------------------------------------------
local DrawPage   -- set below

local function UpdateButtonGuide()
  local texts, icons, offs, cmds = {}, {}, {}, {}
  local function add(text, icon, cmd, off)
    if text ~= nil then
      texts[#texts + 1], icons[#icons + 1], offs[#offs + 1], cmds[#cmds + 1] = text, icon, off or 18, cmd
    end
  end
  local m = nil
  if ui.popup ~= nil then
    m = ModById(ui.popup.id)
  elseif ui.page == nil and ui.tab == 1 and ui.zone == "grid" then
    m = Shown()[ui.sel]
  elseif ui.page == nil and ui.tab == 2 then
    local r = OrderRows()[ui.osel]
    m = r and r.m
  end
  if ui.page ~= nil or (ui.tab == 1 and ui.zone == "bar") then
    -- a list page or the top row: A (a text the game lacks: «Aceptar»)
    add(G_ACCEPT, I_ENTER, Crc("CMD_ENTER"), 0)
  elseif ui.popup ~= nil then
    -- the page's own buttons show their keys (A, Y, L1 / R1): no second copy at the bottom
  elseif have and m ~= nil then
    if m.enabled and m.family == nil and ui.tab == 1 and ui.zone == "grid" then
      texts, icons, offs, cmds = {0, TextId("g_order") or RT_MOVE}, {I_L1, I_R1}, {0, 54}, {Crc("CMD_FUNCL1"), Crc("CMD_FUNCR1")}
    end
    add(TextId("g_toggle") or (m.enabled and RT_OFF or RT_ON), I_ENTER, Crc("CMD_ENTER"))
    if ui.popup == nil then
      add(TextId("g_details"), I_F1, Crc("CMD_FUNC1"))
    end
  end
  if have and ui.page == nil and ui.popup == nil then
    add(TextId("g_profile"), I_F4, Crc("CMD_FUNC4"))
  end
  if ui.page == nil and ui.popup == nil then
    for _, e in ipairs(Extras()) do
      local id = type(e.key) == "string" and TextIdKey(e.key) or nil
      if id ~= nil and type(e.icon) == "number" and type(e.cmd) == "number" then
        add(id, e.icon, e.cmd)
      end
    end
  end
  -- sent only when it changes (it is rebuilt by the engine: a flicker at every key otherwise)
  local sig = table.concat(texts, ",") .. "|" .. table.concat(icons, ",") .. "|" .. table.concat(cmds, ",")
  if sent.guide ~= sig then
    sent.guide = sig
    funcLuaMenuCommand(C.GUIDE_SET, MENU, L_BTN_GUIDE, texts, icons, offs, {}, {})
    funcLuaMenuCommand(C.GUIDE_CMD, MENU, L_BTN_GUIDE, cmds)
  end
end

local function ClampGrid(shown)
  local n = #shown
  if n == 0 then
    ui.sel, ui.top = 1, 0
    return
  end
  ui.sel = math.max(1, math.min(ui.sel, n))
  local row = math.floor((ui.sel - 1) / G.COLS)
  if row < ui.top then
    ui.top = row
  elseif row >= ui.top + G.LIST_ROWS then
    ui.top = row - G.LIST_ROWS + 1
  end
  ui.top = math.max(0, math.min(ui.top, math.max(0, math.ceil(n / G.COLS) - G.LIST_ROWS)))
end

local function DrawToast()
  if ui.toast ~= nil then
    -- under the info panel (the top rows are full)
    local y = G.PANEL_BODY_Y + G.PANEL_BODY_H + 14
    Quad("Q0", SP("night"), G.PANEL_X, y, G.PANEL_W, 44)
    Txt("TC", Cut(ui.toast, Fit(G.PANEL_W - 30, 0.64)), G.PANEL_X + G.PANEL_W / 2, y + 22, 0.64)
  end
end

function Draw()
  if not CE.Ready() then
    return
  end
  Begin()
  DrawHeader()
  DrawTabs()
  DrawToolbar(ui.page == nil and ui.tab == 1 and Shown() or {})
  if ui.page ~= nil then
    DrawPage()
  elseif ui.tab == 1 then
    ClampGrid(Shown())
    DrawGrid()
  else
    DrawOrder()
  end
  if ui.popup ~= nil then
    DrawDetails()
  end
  DrawToast()
  Finish()
  CE.Background()
  UpdateButtonGuide()
end

local function Toast(s)
  ui.toast, ui.toast_t = s, 150
end

-- ---- windows ----------------------------------------------------------------------------------------------------------------
local function Message(text)
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
  funcLuaCommand(C.MSG_OPEN, text, 0, 0, 0, 0, 0, false)
  funcLuaCommand(C.MSG_KIND, 1, 0)
  coroutine.yield()
  while funcLuaCommand(C.MSG_BUSY) do
    coroutine.yield()
  end
  while not funcLuaCommand(C.MSG_DONE) do
    coroutine.yield()
  end
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
  CE.bg_dirty = true       -- a window / keyboard closed: the background again
end

-- yes / no window: true = yes
local function Ask(text)
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
  funcLuaCommand(C.MSG_OPEN, text, 0, 0, 0, 0, 0, false)
  funcLuaCommand(C.MSG_KIND, 2, 0)
  coroutine.yield()
  local r = -1
  while r == nil or r < 0 do
    r = funcLuaCommand(C.MSG_RESULT)
    coroutine.yield()
  end
  while not funcLuaCommand(C.MSG_DONE) do
    coroutine.yield()
  end
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
  CE.bg_dirty = true       -- a window / keyboard closed: the background again
  return r == 0
end

function StartCo(fn)
  if co ~= nil then
    return
  end
  co = coroutine.create(fn)
  local ok, err = coroutine.resume(co)
  if not ok then
    Log("error", tostring(err))
    co = nil
    funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
    CE.bg_dirty = true       -- a window / keyboard closed: the background again
  elseif coroutine.status(co) == "dead" then
    co = nil
  end
end

-- the game's keyboard; nil = nothing typed (B)
local function Keyboard(initial, title_name, fallback_title, max)
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
  if funcLuaCommand(KB.BUSY) then
    funcLuaCommand(KB.CLOSE, "")
  end
  local title = TextId(title_name) or fallback_title
  funcLuaCommand(KB.OPEN, 0, initial or "", title, 0, max, 1, 0, 0, "", 0, 0, true, true, 1, "", 0, false)
  local n = 0
  while not funcLuaCommand(KB.BUSY) and n < 30 do    -- until the keyboard is up
    coroutine.yield()
    n = n + 1
  end
  while funcLuaCommand(KB.BUSY) do
    coroutine.yield()
  end
  local s = funcLuaCommand(KB.RESULT)
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
  CE.bg_dirty = true       -- a window / keyboard closed: the background again
  if type(s) ~= "string" then
    return nil
  end
  return (string.gsub(string.gsub(s, "^%s+", ""), "%s+$", ""))
end

-- ---- actions ------------------------------------------------------------------------------------------------------------------
-- the mod the keys act on: the popup's, the grid's selected card, the load order's row
local function Focused()
  if ui.popup ~= nil then
    return ModById(ui.popup.id)
  end
  if ui.page ~= nil then
    return nil
  end
  if ui.tab == 1 and ui.zone == "grid" then
    return Shown()[ui.sel]
  elseif ui.tab == 2 then
    local r = OrderRows()[ui.osel]
    return r and r.m
  end
  return nil
end

-- keep the selection on mod `id` (grid and load order)
function SelectMod(id)
  local shown = Shown()
  for k, m in ipairs(shown) do
    if m.id == id then
      ui.sel = k
      ui.zone = "grid"
    end
  end
  for k, r in ipairs(OrderRows()) do
    if r.m ~= nil and r.m.id == id then
      ui.osel = k
    end
  end
end

function Toggle()
  local m = Focused()
  if not have or m == nil then
    funcLuaCommand(C.SE, SE_NG)
    if not have then
      Message(T("noloader"))
    end
    return
  end
  local id = m.id
  local active_modules = RV.ActiveModules(m)
  if m.enabled and active_modules > 0 and not Ask(T("confirm_family_off", {n = NameOf(id), c = active_modules})) then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  local ok, msg = RV.SwitchMod(m, not m.enabled)
  if ok ~= true then
    funcLuaCommand(C.SE, SE_NG)
    Message(T("fail"))
    return
  end
  funcLuaCommand(C.SE, SE_OK)
  changed = true
  SelectMod(id)
  Toast(msg)
  Draw()
end

-- the module mods of family parent `m` that are on
function RV.ActiveModules(m)
  local n = 0
  for _, mm in ipairs(m.modules or {}) do
    if mm.enabled then n = n + 1 end
  end
  return n
end

-- Switch mod `m` on / off with its family: a parent switched off takes its module mods with it (the ModLoader
-- remembers which were on and brings exactly those back when the parent is switched on again), a module switched on
-- brings its parent. The ModLoader's own switch does this (evt_modfmt::ModsState::toggled_family); the off and
-- parent rules are repeated here for an older ModLoader. Reads the list again.
-- -> ok, the toast's text
function RV.SwitchMod(m, on)
  local ok = Call(M.SET_ENABLED, m.idx, on and 1 or 0)
  Log("toggle", m.id, on and "ON" or "OFF", "ok", tostring(ok))
  if ok ~= true then
    return false
  end
  local id, nmods, parent = m.id, RV.ActiveModules(m), nil
  if on and m.family ~= nil and not m.family.enabled then
    parent = m.family.id
  end
  ReadAll()
  local now, again = ModById(id), false
  if now ~= nil and not on then
    for _, mm in ipairs(now.modules) do
      if mm.enabled then
        Call(M.SET_ENABLED, mm.idx, 0)
        again = true
      end
    end
  elseif now ~= nil and parent ~= nil then
    local p = ModById(parent)
    if p ~= nil and not p.enabled then
      Call(M.SET_ENABLED, p.idx, 1)
      again = true
    end
  end
  if again then
    ReadAll()
    now = ModById(id)
  end
  local n = NameOf(id)
  local restored = (on and now ~= nil) and RV.ActiveModules(now) or 0
  -- back to how the game started (off -> on): nothing to restart for
  if now ~= nil and not now.pending then
    return true, T("toast_same", {n = n})
  elseif not on and nmods > 0 then
    return true, T("toast_family_off", {n = n, c = nmods})
  elseif parent ~= nil then
    return true, T("toast_parent_on", {n = n, o = NameOf(parent)})
  elseif restored > 0 then
    return true, T("toast_family_on", {n = n, c = restored})
  end
  return true, T(on and "toast_on" or "toast_off", {n = n})
end

-- a «Modules» row of a mod's page: its module mod switched on / off (with the family rules of RV.SwitchMod)
function RV.ToggleModule(mm)
  local ok, msg = RV.SwitchMod(mm, not mm.enabled)
  funcLuaCommand(C.SE, ok and SE_OK or SE_NG)
  if ok then
    changed = true
    RV.cache = {}              -- the page's rows hold the old list's entries: read again
  end
  Toast(ok and msg or T("fail"))
  Draw()
end

function Order(delta)
  -- the load order is edited from the mods list (its rows or a mod's page), not from the top row or a list page
  if ui.page ~= nil or (ui.tab == 1 and ui.zone ~= "grid") then
    funcLuaCommand(C.SE, SE_NG)
    return
  end

  local m = Focused()
  -- a module mod has no place of its own: it moves with its parent
  if not have or m == nil or not m.enabled or m.family ~= nil then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  if SORTS[ui.sort] ~= "order" then
    -- another sort shows the list out of load order: it returns to load order first, the move happens on the next press
    ui.sort = 1
    SelectMod(m.id)
    funcLuaCommand(C.SE, SE_MOVE)
    Toast(T("sort", {s = SortLabel()}))
    Draw()
    return
  end
  if delta < 0 and m.pos <= 1 then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  local ok, moved = Call(M.MOVE, m.idx, delta)
  if ok ~= true or moved ~= true then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  funcLuaCommand(C.SE, SE_MOVE)
  changed = true
  local id = m.id
  ReadAll()
  SelectMod(id)
  local n = ModById(id)
  Toast(T("toast_order", {n = NameOf(id), p = n and n.pos or 0, t = cnt.active}))
  Draw()
end

function OpenDetails()
  local m = Focused()
  if m == nil then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  funcLuaCommand(C.SE, SE_OK)
  RV.cache = {}              -- the report as it is now (read again at every page)
  -- a mod with modules opens on its «Modules» list: the focus starts on the first module, not on the buttons
  local view = RV.HasModules(m) and "modules" or "info"
  ui.popup = {kind = "mod", id = m.id, btn = 1, view = view, top = 0, srow = 1, stop = 0, szone = "rows", mrow = 1}
  Draw()
end

function ClosePopup()
  funcLuaCommand(C.SE, SE_BACK)
  if ui.popup ~= nil and ui.popup.back ~= nil then
    ui.popup = ui.popup.back
    Draw()
    return
  end
  local id = ui.popup and ui.popup.id
  ui.popup = nil
  if id then
    SelectMod(id)
  end
  Draw()
end

-- The mod page's tabs: L2 / R2 move to the previous / next view of RV.Views (the full description closes first)
function RV.Switch(d)
  local p = ui.popup
  local m = p and ModById(p.id)
  if m == nil then
    return
  end
  local views = RV.Views(m)
  local k = 1
  for i, v in ipairs(views) do
    if v == p.view then
      k = i
    end
  end
  RV.Go(views[(k - 1 + d) % #views + 1])
end

-- open mod `id`'s page over the one on screen (a requirement chip, a module row); B comes back
function RV.OpenChild(id)
  local o = ModById(id)
  if o == nil or ui.popup == nil or o.id == ui.popup.id then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  funcLuaCommand(C.SE, SE_OK)
  ui.popup = {kind = "mod", id = o.id, btn = 1, view = "info", top = 0, srow = 1, stop = 0, szone = "rows", mrow = 1,
              back = ui.popup}
  Draw()
end

-- A / a click on module row n: a module mod switched on / off (with the family rules of RV.SwitchMod; one whose
-- requirement is not met is not switched on), an internal module one step
function RV.ModuleToggle(m, n)
  local r = RV.ModuleRows(m)[n]
  if r == nil then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  if r.mod == nil then
    RV.Change(m, 1, r.opt)
    return
  end
  local need = RV.ModuleNeed(r.mod)
  if need ~= nil and not r.mod.enabled then
    funcLuaCommand(C.SE, SE_NG)
    Toast(T("module_needs", {o = need}))
    Draw()
    return
  end
  RV.ToggleModule(r.mod)
end

-- the pad in «Módulos»: up / down a row, left / right a page
function RV.ModulesMove(m, id)
  local p, n = ui.popup, #RV.ModuleRows(m)
  local d = (id == FN.UP and -1) or (id == FN.DOWN and 1) or (id == FN.LEFT and -RV.MOD_ROWS) or RV.MOD_ROWS
  local k = math.max(1, math.min(n, (p.mrow or 1) + d))
  funcLuaCommand(C.SE, k ~= p.mrow and SE_MOVE or SE_NG)
  p.mrow = k
  Draw()
end

-- Y in «Módulos»: the focused module mod's own page
function RV.ModuleOpen(m)
  local r = RV.ModuleRows(m)[ui.popup.mrow or 1]
  if r == nil or r.mod == nil then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  RV.OpenChild(r.mod.id)
end

-- A / Enter on the mod's page: what the view focuses (a requirement chip, «Ver descripción completa», a module, a
-- setting), else the main action (switch the mod)
function RV.Decide()
  local p = ui.popup
  local m = ModById(p.id)
  local v = RV.View()
  if m == nil or p.full then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  if v == "info" then
    local t = RV.InfoTarget(m)
    if t.kind == "chip" then
      RV.OpenChild(t.id)
    elseif t.kind == "desc" then
      RV.OpenFull()
    else
      StartCo(Toggle)
    end
  elseif v == "modules" then
    RV.ModuleToggle(m, p.mrow or 1)
  elseif v == "settings" and #RV.SetRows(m) > 0 and p.szone ~= "buttons" then
    RV.Activate(m, p.srow or 1)
  else
    StartCo(Toggle)
  end
end

-- the keys on the mod's page (OnFunction): L2 / R2 tabs, Start closes, L1 / R1 load order, the arrows by view, X the
-- full description, Y a module's page (in «Módulos») or «Novedades», R3 «¿Quién lo toca?» (in «Conflictos»)
function RV.Key(id)
  local p = ui.popup
  local m = ModById(p.id)
  if m == nil then
    return
  end
  local v = RV.View()
  local arrow = id == FN.UP or id == FN.DOWN or id == FN.LEFT or id == FN.RIGHT
  if id == FN.TAB_PREV or id == FN.TAB_NEXT then
    RV.Switch(id == FN.TAB_PREV and -1 or 1)
  elseif id == FN.DETAILS then
    ClosePopup()
  elseif id == FN.ORDER_UP or id == FN.ORDER_DOWN then
    if frame - last_act >= 4 then
      last_act = frame
      Order(id == FN.ORDER_UP and -1 or 1)
    end
  elseif p.full then
    if arrow then
      local d = (id == FN.UP and -1) or (id == FN.DOWN and 1) or (id == FN.LEFT and -RV.FULL_ROWS) or RV.FULL_ROWS
      local n = #RV.FullLines(m)
      local t = math.max(1, math.min((p.ftop or 1) + d, math.max(1, n - RV.FULL_ROWS + 1)))
      funcLuaCommand(C.SE, t ~= p.ftop and SE_MOVE or SE_NG)
      p.ftop = t
      Draw()
    else
      funcLuaCommand(C.SE, SE_NG)
    end
  elseif arrow and v == "info" then
    RV.InfoMove(m, (id == FN.LEFT or id == FN.UP) and -1 or 1)
  elseif id == FN.PROFILE and v == "info" then
    RV.OpenFull()
  elseif arrow and v == "modules" then
    RV.ModulesMove(m, id)
  elseif id == FN.EXTRA3 and v == "modules" then
    RV.ModuleOpen(m)
  elseif arrow and v == "settings" and RV.SettingsKey(id) then
    -- «Ajustes»: the keys went to the setting rows
  elseif (id == FN.UP or id == FN.DOWN) and (v == "problems" or v == "conflicts" or v == "news") then
    local n, rows = 0, RV.ROWS
    if v == "news" then
      n, rows = #RV.NewsLines(m), RV.NEWS_ROWS
    else
      local r = RV.Of(m.id)
      n = #(v == "problems" and r.problems or r.conflicts)
    end
    local t = math.max(0, math.min((p.top or 0) + (id == FN.UP and -1 or 1), n - rows))
    funcLuaCommand(C.SE, t ~= p.top and SE_MOVE or SE_NG)
    p.top = t
    Draw()
  elseif id == FN.SEARCH and v == "conflicts" then
    -- «Conflictos»: R3 = who touches the first conflict's id on the page (the search box takes another)
    local e = RV.Of(m.id).conflicts[(p.top or 0) + 1]
    RV.OpenWho(e and RV.WhoId(e) or "")
  elseif id == FN.EXTRA3 and v ~= "news" and #RV.Notes(m).notes > 0 then
    RV.Go("news")
  else
    funcLuaCommand(C.SE, SE_NG)
  end
end

function SwitchTab(k)
  if ui.page ~= nil or ui.popup ~= nil then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  k = ((k - 1) % G.NTABS) + 1
  if k == ui.tab then
    return
  end
  funcLuaCommand(C.SE, SE_MOVE)
  ui.tab = k
  if k == 1 then
    ui.zone = "grid"
  end
  Draw()
end

function CycleFilter(d)
  ui.filter = ((ui.filter - 1 + d) % #FILTERS) + 1
  ui.sel, ui.top = 1, 0
  funcLuaCommand(C.SE, SE_MOVE)
  Draw()
end

function CycleSort(d)
  ui.sort = ((ui.sort - 1 + d) % #SORTS) + 1
  ui.sel, ui.top = 1, 0
  funcLuaCommand(C.SE, SE_MOVE)
  Draw()
end

-- R3 / the search bar: type part of a name (empty = no search)
function SearchFlow()
  if ui.tab ~= 1 then
    ui.tab = 1
  end
  local q = Keyboard(ui.query, "kb_search", RT_SEARCH, 24)
  if q ~= nil then
    ui.query = q
    ui.sel, ui.top, ui.zone = 1, 0, "grid"
    Log("search", q, "shown", #Shown())
  end
  Draw()
end

-- FUNC4: next profile; on the last one, offer a new profile with the mods active now (no = back to the first)
function ProfileFlow()
  if not have then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  local k = cnt.profile + 1
  if k >= cnt.profiles then
    funcLuaCommand(C.SE, SE_OK)
    if Ask(T("profile_ask_new")) then
      local ok, nk = Call(M.PROFILE_NEW, T("profile_prefix"))
      if ok ~= true then
        Message(T("fail"))
        return
      end
      changed = true
      ReadAll()
      Draw()
      Message(T("profile_new_done", {p = profiles[Int(nk) + 1] or ""}))
      return
    end
    if cnt.profiles <= 1 then
      return
    end
    k = 0
  end
  if Call(M.PROFILE_SWITCH, k) ~= true then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  funcLuaCommand(C.SE, SE_OK)
  changed = true
  Log("profile", k)
  ReadAll()
  Toast(T("toast_profile", {p = ProfileName()}))
  Draw()
end

function RunExtra(e)
  funcLuaCommand(C.SE, SE_OK)
  StartCo(function()
    if e.flow(MENU) ~= true then
      funcLuaCommand(C.SE, SE_NG)
    end
    funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
    CE.bg_dirty = true       -- a window / keyboard closed: the background again
    Draw()
  end)
end

-- ---- list pages -----------------------------------------------------------------------------------------------------------
-- A page is drawn in the content area and waits for the player: the flow runs as the screen's coroutine and waits for
-- `ui.page.pick` / `ui.page.back` / `ui.page.act`.
local function WaitPage(p)
  p.pick, p.back, p.act = nil, false, nil
  ui.page = p
  Draw()
  while p.pick == nil and not p.back and p.act == nil do
    coroutine.yield()
  end
  return p.pick, p.back, p.act
end

-- a list page: `items` = {{label, sub, off, head}}; opt.search = a function(query) that refills the list (nil = none),
-- opt.preview(item) = the panel's lines for the selected item, opt.info = lines under them. Returns the picked row and
-- its item, or nil (B)
local function ListPage(title, help, items, opt)
  opt = opt or {}
  local p = {kind = "list", title = title, help = help, items = items, sel = opt.sel or 1, top = 1, search = opt.search,
             query = opt.query or "", total = opt.total, preview = opt.preview, zone = "list", info = opt.info}
  opt.p = p
  while true do
    local pick, back, act = WaitPage(p)
    if back then
      return nil
    end
    if act == "search" and p.search ~= nil then
      local q = Keyboard(p.query, "kb_search", RT_SEARCH, 24)
      if q ~= nil then
        p.query = q
        p.items, p.total = p.search(q)
        p.sel, p.top = 1, 1
      end
    elseif pick ~= nil then
      local it = p.items[pick]
      if it ~= nil and not it.off then
        return pick, it
      end
      funcLuaCommand(C.SE, SE_NG)
    end
  end
end

local function DrawList(p)
  local LW = G.ROW_W
  local rows = G.LIST_ROWS
  local y0 = G.LIST_Y              -- its search is in the top row (CE.DrawPageRow)
  p.sel = math.max(1, math.min(p.sel, math.max(1, #p.items)))
  if p.sel < p.top then
    p.top = p.sel
  elseif p.sel >= p.top + rows then
    p.top = p.sel - rows + 1
  end
  p.top = math.max(1, math.min(p.top, math.max(1, #p.items - rows + 1)))
  CE.ListBox()
  if #p.items == 0 then
    Quad("Q2", SP("row_off"), G.LIST_X, y0, LW, G.ROW_H)
    Txt("TL", "[CWG]" .. T("list_empty") .. "[C]", G.LIST_X + 28, y0 + G.ROW_H / 2, 0.85)
  end
  for k = 0, rows - 1 do
    local n = p.top + k
    local it = p.items[n]
    if it ~= nil then
      local y = y0 + k * G.ROW_STEP
      local sel = n == p.sel and p.zone == "list"
      if it.head then
        Quad("Q2", SP("row_head"), G.LIST_X, y, LW, G.ROW_H)
        Txt("TL", Cut(it.label, math.min(64, Fit(LW - 56, 0.8))), G.LIST_X + 28, y + G.ROW_H / 2, 0.8)
      else
        Quad("Q2", SP(sel and "row_sel" or (it.off and "row_off" or "row")), G.LIST_X, y, LW, G.ROW_H)
        if sel then
          CE.Focus("Q1", G.LIST_X, y, LW, G.ROW_H, 3)   -- the cursor of every list
        end
        local lx = G.LIST_X + 28
        Txt("TL", (it.off and "[CWG]" or "[CB]") .. Cut(it.label, math.min(it.sub and 44 or 64, Fit(LW - (lx - G.LIST_X) - (it.sub and 230 or 30), 0.84))) .. "[C]", lx, y + G.ROW_H / 2, 0.84)
        if it.sub ~= nil and it.sub ~= "" then
          Txt("TR", "[CWG]" .. Cut(it.sub, 30) .. "[C]", G.LIST_X + LW - 24, y + G.ROW_H / 2, 0.72)
        end
        Hit(G.LIST_X, y, LW, G.ROW_H, "prow" .. n, function() p.sel = n p.zone = "list" p.pick = n end)
      end
    end
  end
  DrawScrollbar(#p.items, p.top - 1, rows, G.SB_X, y0, rows * G.ROW_STEP - (G.ROW_STEP - G.ROW_H), function(f)
    p.top = f + 1
    p.sel = math.max(p.top, math.min(p.sel, p.top + rows - 1))
  end)
  -- the panel: help + preview of the selected entry
  local lines = {{t = p.help or "", c = "[CWG]", max = 4}, {gap = 10}}
  local it = p.items[p.sel]
  if it ~= nil and p.preview ~= nil then
    for _, l in ipairs(p.preview(it)) do
      lines[#lines + 1] = l
    end
  end
  if p.info ~= nil then
    for _, l in ipairs(p.info) do
      lines[#lines + 1] = l
    end
  end
  DrawPanel(p.title, lines)
end

DrawPage = function()
  DrawList(ui.page)
end

-- «¿Quién lo toca?» (RV.OpenWho): the rows of id `id` for a list page -> items, places, winner
function RV.WhoItems(id)
  local items, places = {}, 0
  if id == nil or id == "" then
    return items, 0, ""
  end
  local n, win = Call(M.REPORT_WHO, id)
  n, win = Int(n), Str(win)
  local last, rep = nil, false
  for i = 0, n - 1 do
    local mid, order, ty, place, text, kind, wins = Call(M.REPORT_WHO_ROW, i)
    mid, kind = Str(mid), Str(kind)
    if kind == "report" and not rep then
      rep, last = true, nil
      items[#items + 1] = {head = true, label = T("who_report")}
    end
    if mid ~= last and kind ~= "report" then
      last = mid
      local m = ModById(mid)
      local name = (m ~= nil and m.name ~= nil and m.name ~= "") and m.name or mid
      local pos = Int(order) > 0 and T("who_order", {n = Int(order)}) or T("who_not_loaded")
      items[#items + 1] = {head = true, label = (mid == win and "[CY]" or "") .. name .. "  ·  " .. pos ..
                           (mid == win and ("  ·  " .. T("rp_winner", {w = name})) or "") .. (mid == win and "[C]" or "")}
    end
    places = places + (kind == "report" and 0 or 1)
    items[#items + 1] = {label = "[" .. Str(ty) .. "] " .. Str(text), sub = Str(place), off = kind == "refers",
                         full = Str(text), place = Str(place), mod = mid, kind = kind, win = wins == true}
  end
  return items, places, win
end

-- the explorer's list page; B returns to the mod page on the view it came from
function RV.WhoFlow(id)
  local saved = ui.popup
  ui.popup = nil
  local opt = {query = id or ""}
  local function fill(q)
    local items, places, win = RV.WhoItems(q)
    local info = {{gap = 10}, {t = q == "" and T("who_empty") or (win ~= "" and T("who_winner", {w = win}) or
                  (places > 0 and T("who_no_winner") or T("who_nobody", {i = q}))), c = "[CN]", max = 3}}
    opt.info = info
    if opt.p ~= nil then
      opt.p.info = info
    end
    return items, places
  end
  local items
  items, opt.total = fill(opt.query)
  opt.search = fill
  opt.preview = function(it)
    if it.head then
      return {}
    end
    return {{t = it.place or "", c = "[CWG]", max = 2}, {t = it.full or "", c = "[CB]", max = 5},
            {t = T("who_kind_" .. (it.kind or "defines")), c = "[CWG]", max = 2}}
  end
  while true do
    local k = ListPage(T("who_title"), T("who_help"), items, opt)
    if k == nil then
      break
    end
    -- a row picked: nothing to do on it; the list stays (its search, its cursor)
    items, opt.query, opt.total, opt.sel = opt.p.items, opt.p.query, opt.p.total, opt.p.sel
  end
  ui.page = nil
  ui.popup = saved
  Draw()
end

-- The header adaptation: G is laid out for the retail header; a mod that restyles the header sets the
-- global VRFW_MM_LAYOUT = {top_dy = n} in a Lua patch of this script (e.g. -55). Applied in OnInit from the retail values, so any order of the patches and any
-- number of visits give the same layout. top_dy is clamped to ±160 px.
function CE.ApplyLayout()
  if G.BASE_Y == nil then
    G.BASE_Y = {}
    for _, k in ipairs(G.SHIFT_Y) do
      G.BASE_Y[k] = G[k]
    end
  end
  local dy = type(VRFW_MM_LAYOUT) == "table" and tonumber(VRFW_MM_LAYOUT.top_dy) or 0
  dy = math.max(-160, math.min(160, dy or 0))
  for _, k in ipairs(G.SHIFT_Y) do
    G[k] = G.BASE_Y[k] + dy
  end
  -- the rows that fit between the list's top and the box's bottom (fixed: the button guide does not move)
  G.LIST_ROWS = math.max(4, math.floor((G.BOX_BOTTOM - G.BOX_PAD - G.LIST_Y + (G.ROW_STEP - G.ROW_H)) / G.ROW_STEP))
  G.TOP_DY = dy
  return dy
end

-- the search of a list page for CE.RowSearch, or nil (none)
function CE.PageSearch(p)
  if p.search == nil then
    return nil
  end
  local id = "psearch"
  return {on = true, query = p.query, hint = "search_hint_list", count = T("list_count", {n = #p.items, t = p.total or #p.items}),
          foc = p.zone == "search" or mouse.hot == id, id = id, act = function() p.act = "search" end}
end

-- the page's own part of the top row: its search box (the count inside), in the place of «Instalados»' search
function CE.DrawPageRow(p)
  local s = CE.PageSearch(p)
  if s ~= nil then
    CE.RowSearch(s)
  end
end

-- ---- the first frame (a grey full-screen frame when the Mods screen opened) ------------------------------------
-- The screen showed its background a frame or more before its content (the free layers are set up after the anchor
-- opened): the clear colour, then a bare background. Nothing of the screen shows until every free layer is set up (or
-- REVEAL_MAX frames passed): the first drawing shows the background and the content together.
CE.REVEAL_MAX = 30
function CE.RevealReset()
  local need = 0
  for _, key in ipairs(FREE_ORDER) do
    need = need + FREE[key][2]
  end
  CE.rv = {need = need, got = {}, n = 0, ready = false, opened = nil, done = false, init = frame, per = {}, stuck = false}
end

-- the anchor layer never opened (the menu built forever, nothing drawn, the title stuck under
-- it): one line with how far the engine got setting up each free layer, so a pool the game cannot build shows
CE.STUCK_FRAMES = 300
function CE.RevealStuck()
  local rv = CE.rv
  if rv.stuck or rv.opened ~= nil or frame - (rv.init or 0) < CE.STUCK_FRAMES then
    return
  end
  rv.stuck = true
  local parts = {}
  for _, key in ipairs(FREE_ORDER) do
    parts[#parts + 1] = key .. " " .. (rv.per[key] or 0) .. "/" .. FREE[key][2]
  end
  Log("reveal", "STUCK: the input anchor never opened", "frames", frame - (rv.init or 0), "free layers set up",
      rv.n .. "/" .. rv.need, table.concat(parts, ", "))
end

-- every free layer set up (or the wait is over): the screen may draw
function CE.Ready()
  local rv = CE.rv
  if rv == nil or rv.ready then
    return true
  end
  if rv.n >= rv.need or (rv.opened ~= nil and frame - rv.opened >= CE.REVEAL_MAX) then
    rv.ready = true
    Log("reveal", "free layers", rv.n .. "/" .. rv.need, "frames", rv.opened and (frame - rv.opened) or -1)
  end
  return rv.ready
end

-- Step: draw once ready (the anchor opened); until then, the «STUCK» line when it never opens
function CE.RevealStep()
  local rv = CE.rv
  if rv == nil or rv.done then
    return
  end
  CE.RevealStuck()
  if not rv.ready and rv.opened ~= nil and CE.Ready() then
    Draw()
  end
  rv.done = rv.ready and rv.opened ~= nil
end

-- the background: the Guardar one on every page, shown with the first full drawing (OnSetupLayer keeps it hidden until
-- then) and asserted again whenever the page changed or a window / keyboard closed (CE.bg_dirty), never hidden
-- afterwards. The title menu stays open under this screen (another menu object): this opaque background covers it.
function CE.Background()
  if BG.on ~= true or BG.page ~= ui.page or CE.bg_dirty then
    BG.on, BG.page, CE.bg_dirty = true, ui.page, false
    funcLuaMenuCommand(C.LAYER_VISIBLE, BG.LAYER, 0, true)
  end
end

-- the cursor of every picker (dropdowns, grids): a cyan frame of four edges around a cell. Edges only, so it never
-- covers the icon / face drawn on the same layer (two quads of one layer have no fixed order)
function CE.Focus(layer, x, y, w, h, t)
  t = t or 5
  Quad(layer, SP("cyan"), x - t, y - t, w + 2 * t, t)
  Quad(layer, SP("cyan"), x - t, y + h, w + 2 * t, t)
  Quad(layer, SP("cyan"), x - t, y, t, h)
  Quad(layer, SP("cyan"), x + w, y, t, h)
end

-- ---- mod tags: the tags the mods declare ([[VRFW.ModTag]] of their mod.toml, CMND_VRFW_MM_TAG_DEFS), read
-- once per opening of the screen (keyed on this opening's text-id cache), their labels from the declaring mod's text
-- rows (menu_text); a mod's tags come from the plugin (derived from its content + [VRFW.Mod] Tags)

-- the lines of a "\n"-joined answer
function CE.Lines(s)
  local out = {}
  for l in string.gmatch(s or "", "[^\n]+") do
    out[#out + 1] = l
  end
  return out
end

-- {defs in order}, {id -> def}; def = {id, text}
function CE.TagDefs()
  if CE.tag_src ~= text_ids then
    CE.tag_src, CE.tag_defs, CE.tag_by = text_ids, {}, {}
    for i = 0, Int(Call(M.TAG_DEFS)) - 1 do
      local id, text = Call(M.TAG_DEF, i)
      if Str(id) ~= "" then
        local t = {id = Str(id), text = Str(text)}
        CE.tag_defs[#CE.tag_defs + 1] = t
        CE.tag_by[t.id] = t
      end
    end
  end
  return CE.tag_defs, CE.tag_by
end

-- a text key of a mod's text rows in the game's language (menu_text), "" when the game has none
function CE.KeyText(key)
  local id = (key or "") ~= "" and TextIdKey(key) or nil
  return id ~= nil and Str(Call(C.TEXT_GET, id)) or ""
end

-- a tag's label in the game's language (its text key in menu_text), else its id
function CE.TagLabel(t)
  if t.label == nil then
    local s = CE.KeyText(t.text)
    t.label = s ~= "" and s or t.id
  end
  return t.label
end

-- «Etiquetas» of a mod: the tags of its mod.toml (`tags`) and its mod tags (CMND_VRFW_MM_MOD_TAGS), in words
function CE.ModTags(m)
  if m.tag_list == nil then
    local out = CE.Lines(Text(m, 8))
    local _, by = CE.TagDefs()
    for _, id in ipairs(CE.Lines(Str(Call(M.MOD_TAGS, m.id)))) do
      if by[id] ~= nil then
        out[#out + 1] = CE.TagLabel(by[id])
      end
    end
    m.tag_list = out
  end
  return m.tag_list
end

-- the scrollbar held by the mouse: its page follows the pointer's y (DrawScrollbar's `set`)
function CE.DragTo(y)
  local d = mouse.drag
  if d == nil or type(y) ~= "number" then
    return
  end
  local f = math.max(0, math.min(1, (y - d.y0 - d.th / 2) / math.max(1, d.h - d.th)))
  d.set(math.floor(f * d.n + 0.5))
  Draw()
end

-- keys inside a list page
local function PageKey(id)
  local p = ui.page
  if (id == FN.UP or id == FN.DOWN) and p.zone == "list" then
    -- rows marked `head` (group titles) are skipped
    local d = id == FN.UP and -1 or 1
    local n = p.sel + d
    while p.items[n] ~= nil and p.items[n].head do
      n = n + d
    end
    if p.items[n] ~= nil then
      p.sel = n
      funcLuaCommand(C.SE, SE_MOVE)
      Draw()
      return true
    end
    if id == FN.DOWN or p.search == nil then
      funcLuaCommand(C.SE, SE_NG)
      return true
    end
  end
  if id == FN.UP then
    if p.zone == "list" and p.sel <= 1 and p.search ~= nil then
      p.zone = "search"
    elseif p.zone == "list" then
      p.sel = math.max(1, p.sel - 1)
    end
  elseif id == FN.DOWN then
    if p.zone == "search" then
      p.zone = "list"
    else
      p.sel = math.min(#p.items, p.sel + 1)
    end
  elseif id == FN.LEFT then
    p.sel = math.max(1, p.sel - G.LIST_ROWS)
  elseif id == FN.RIGHT then
    p.sel = math.min(#p.items, p.sel + G.LIST_ROWS)
  elseif id == FN.SEARCH and p.search ~= nil then
    p.act = "search"
  else
    return false
  end
  funcLuaCommand(C.SE, SE_MOVE)
  Draw()
  return true
end

-- ---- moving -------------------------------------------------------------------------------------------------------------------
local function MoveGrid(dx, dy)
  local shown = Shown()
  local n = #shown
  if ui.zone == "bar" then
    if dy > 0 then
      if n > 0 then
        ui.zone = "grid"
        funcLuaCommand(C.SE, SE_MOVE)
      else
        funcLuaCommand(C.SE, SE_NG)
      end
    elseif dx ~= 0 then
      local b = math.max(1, math.min(4, ui.bar + dx))
      funcLuaCommand(C.SE, b ~= ui.bar and SE_MOVE or SE_NG)
      ui.bar = b
    else
      funcLuaCommand(C.SE, SE_NG)
    end
    Draw()
    return
  end
  if n == 0 then
    if dy < 0 then
      ui.zone = "bar"
      funcLuaCommand(C.SE, SE_MOVE)
      Draw()
    else
      funcLuaCommand(C.SE, SE_NG)
    end
    return
  end
  local s = ui.sel
  if dx ~= 0 then
    s = math.max(1, math.min(n, s + dx * G.LIST_ROWS))
  else
    s = s + dy * G.COLS
  end
  if dy < 0 and s < 1 then
    ui.zone = "bar"
    ui.bar = math.min(3, ((ui.sel - 1) % G.COLS) + 1)
    funcLuaCommand(C.SE, SE_MOVE)
    Draw()
    return
  end
  if dy > 0 and s > n then
    -- the last row: go to the last card if it is on a lower row
    if math.floor((n - 1) / G.COLS) > math.floor((ui.sel - 1) / G.COLS) then
      s = n
    else
      s = ui.sel
    end
  end
  s = math.max(1, math.min(n, s))
  if s == ui.sel then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  funcLuaCommand(C.SE, SE_MOVE)
  ui.sel = s
  Draw()
end

local function MoveOrder(d)
  local rows = OrderRows()
  local s = ui.osel
  repeat
    s = s + d
  until rows[s] == nil or not rows[s].head
  if rows[s] == nil then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  funcLuaCommand(C.SE, SE_MOVE)
  ui.osel = s
  Draw()
end

-- A on a list row: a mod with modules opens its page (the modules first) instead of switching
local function DecideRow()
  local m = Focused()
  if m ~= nil and RV.HasModules(m) then
    OpenDetails()
  else
    StartCo(Toggle)
  end
end

-- A / Enter / a click without the mouse: the selected thing
local function Decide()
  if ui.popup ~= nil then
    RV.Decide()
  elseif ui.tab == 1 then
    if ui.zone == "bar" then
      if ui.bar == 1 then
        StartCo(SearchFlow)
      elseif ui.bar == 2 then
        CycleFilter(1)
      elseif ui.bar == 3 then
        CycleSort(1)
      else
        funcLuaCommand(C.SE, SE_OK)
        StartCo(ProfileFlow)
      end
    else
      DecideRow()
    end
  else
    DecideRow()
  end
end

local function Close()
  Call(Crc("CMND_VRFW_NO_PHOTO"), "mods_menu", 0)   -- the game's photos again outside the Mods panel
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
  funcLuaCommand(C.CLOSE_MENU, MENU)
end

local function CloseFlow()
  if changed then
    ReadAll()
    if cnt.changes > 0 then
      Message(T("restart_msg"))
    end
  end
  Close()
end

-- ---- the mouse (Lua hit test: pointer against the zones of the last drawing) -----------------------------------------------
local function HitAt(x, y)
  for i = #hits, 1, -1 do         -- the last drawn (the popup, a card's button) wins
    local h = hits[i]
    if x >= h[1] and x < h[3] and y >= h[2] and y < h[4] then
      return h
    end
  end
  return nil
end

-- hover: cards / rows follow the pointer; buttons light up
local function Hover(h)
  local id = h and h[5] or nil
  local redraw = id ~= mouse.hot
  mouse.hot = id
  if id ~= nil and ui.popup == nil then
    local cid = string.match(id, "^card(.+)$") or string.match(id, "^btn(.+)$")
    if cid ~= nil and ui.page == nil and ui.tab == 1 then
      local before = ui.sel
      SelectMod(cid)
      redraw = redraw or before ~= ui.sel or ui.zone ~= "grid"
      ui.zone = "grid"
    end
    local on = tonumber(string.match(id, "^orow(%d+)$") or string.match(id, "^otag(%d+)$") or "")
    if on ~= nil and on ~= ui.osel then
      ui.osel, redraw = on, true
    end
    local pr = tonumber(string.match(id, "^prow(%d+)$") or "")
    if pr ~= nil and ui.page ~= nil and ui.page.kind == "list" and pr ~= ui.page.sel then
      ui.page.sel, ui.page.zone, redraw = pr, "list", true
    end
  end
  if redraw then
    Draw()
  end
end

local function Click()
  local h = HitAt(mouse.x, mouse.y)
  if h == nil then
    return false
  end
  Log("click", h[5])
  last_act = frame
  decided = true
  h[6]()
  return true
end

local function PollMouse()
  -- CMD_ENTER of the last frame (mouse.enter): the poll acts on the press, not while A is held
  local enter_now = Call(C.CHECK_INPUT, C.MENU_CTRL, C.ENTER) == true
  local enter_edge = enter_now and not mouse.enter
  mouse.enter = enter_now
  -- a pointer click: the mouse's left button, or Accept / the free cursor's A while the pointer leads
  local click_now = Call(C.CHECK_INPUT, C.MENU_CTRL, C.LEFT) == true or (mouse.on and Call(C.CHECK_INPUT, C.MENU_CTRL, C.CLICK) == true)
  local click_edge = click_now and not mouse.click
  mouse.click = click_now
  local waiting_page = ui.page ~= nil and co ~= nil and ui.page.pick == nil and not ui.page.back and ui.page.act == nil
  -- the pointer moved: the mouse («moved» flag) or VR's free cursor (the stick moves the pointer without that flag)
  local x, y = funcLuaMenuCommand(C.POINTER)
  local moved = false
  if type(x) == "number" and type(y) == "number" then
    moved = funcLuaMenuCommand(C.MOVED) == true
    if not moved and mouse.px ~= nil and (math.abs(x - mouse.px) > 1 or math.abs(y - mouse.py) > 1) then
      moved = true
    end
    mouse.px, mouse.py = x, y
  end
  if co ~= nil and not waiting_page then
    return
  end
  if moved then
    mouse.on, mouse.x, mouse.y = true, x, y
    if mouse.logs < 6 then
      mouse.logs = mouse.logs + 1
      Log("mouse", x, y)
    end
    Hover(HitAt(x, y))
  end
  if mouse.drag ~= nil then
    -- a scrollbar held (DrawScrollbar): it follows the pointer until the button is let go
    if click_now then
      if moved then
        CE.DragTo(y)
      end
      return
    end
    mouse.drag = nil
  end
  if decided or frame - last_act < 4 then
    return
  end
  if click_edge then
    mouse.on = true
    Click()                 -- on no zone: nothing
  elseif enter_edge then
    PadDecide("poll")       -- A / Enter when the anchor gave no callback this frame
  elseif mouse.on and (ui.popup == nil or ui.popup.full or ui.popup.view ~= "info") then
    -- the wheel scrolls what the arrows scroll (lists, the grid, report views); the pointer keeps the lead
    local d = (Call(C.CHECK_INPUT, C.MENU_CTRL, C.W_DOWN) == true and 1) or (Call(C.CHECK_INPUT, C.MENU_CTRL, C.W_UP) == true and -1) or 0
    if d ~= 0 then
      OnFunction(0, d > 0 and FN.DOWN or FN.UP)
      mouse.on = true
    end
  end
end

-- ---- engine callbacks -------------------------------------------------------------------------------------------------------
function OnInit()
  local _, _, _, menu = Call(M.STATE)
  if type(menu) == "number" and menu ~= 0 then
    MENU = menu
  end
  CE.ApplyLayout()          -- the header mod's shift (VRFW_MM_LAYOUT), before anything is drawn
  Call(M.RESCAN)            -- the app may have changed mods\ while the game runs
  Reset()
  changed, co, frame, last_act, lang, text_ids = false, nil, 0, -1000, nil, {}
  sent, used, was, hits = {}, {}, {}, {}
  tex_asked, tex_wait, tex_frames, thumbs, icons = {}, false, 0, {}, {}
  mouse = {on = false, x = -1, y = -1, logs = 0}
  dbg, extras, decided = 0, nil, false
  BG.on, BG.page = nil, nil  -- the background asserted again at the first drawing
  CE.RevealReset()
  -- no game photos anywhere in the Mods panel (D-pad left took pictures; the game's own photo input,
  -- anim engine photo_rt.rs); given back in Close()
  Call(Crc("CMND_VRFW_NO_PHOTO"), "mods_menu", 1)
  ReadAll()
  Log("open", "loader", tostring(have), "installed", cnt.installed, "changes", cnt.changes, "profiles", cnt.profiles, "top_dy", G.TOP_DY)
end

function OnSetupLayer(a1, a2)
  if a1 == L_HEADER then
    if SetupSoccerTopCommonHeaderLayerInfo then
      SetupSoccerTopCommonHeaderLayerInfo(a1, 4153539961, 253801632, 3969848060, 1144161661, 3293713115, 253801632, 1152304044, 305955024, 3007971317)
    end
    if SwapSoccerTopCommonHeaderMenuModeIconTexture then
      SwapSoccerTopCommonHeaderMenuModeIconTexture(758233070 --[[mode_base07]])
    end
    if UpdateHeader then
      UpdateHeader(3586861540)
    end
    DrawHeader()
  elseif a1 == L_BASE then
    -- the retail «total play time» line of the save list: not used
    funcLuaMenuCommand(C.TEXT, a1, N.BASE_TIME, "", a2)
    for _, mesh in ipairs(N.BASE_MESHES) do
      funcLuaMenuCommand(C.MESH_VISIBLE, a1, mesh, false, a2)
    end
    for _, p in ipairs(N.BASE_PRIMS) do
      funcLuaMenuCommand(C.PRIM_VISIBLE, a1, a2, p, false)
    end
  elseif a1 == BG.LAYER then
    -- the Guardar background: hidden until the first full drawing shows it with the content (CE.Ready)
    if BG.on ~= true then
      funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    end
  elseif a1 == L_ROW then
    -- the input anchor: nothing of it shows
    funcLuaMenuCommand(C.TEXT, a1, N.ROW_ON, "", a2)
    funcLuaMenuCommand(C.TEXT, a1, N.ROW_OFF, "", a2)
    for _, mesh in ipairs(N.ROW_MESHES) do
      funcLuaMenuCommand(C.MESH_VISIBLE, a1, mesh, false, a2)
    end
    funcLuaMenuCommand(C.ATTACH_TRACE, a1, a2, N.CURSOR, false)
  else
    -- a free layer instance (set up by the engine, maybe after the first drawing): hidden, its sent state forgotten,
    -- drawn again at the next Step
    for _, key in ipairs(FREE_ORDER) do
      if a1 == FREE[key][1] then
        local prefix = a1 .. ":" .. a2 .. ":"
        if CE.rv ~= nil and not CE.rv.got[prefix] then
          CE.rv.got[prefix] = true
          CE.rv.n = CE.rv.n + 1
          CE.rv.per[key] = (CE.rv.per[key] or 0) + 1
        end
        for k in pairs(sent) do
          if string.sub(k, 1, #prefix) == prefix then
            sent[k] = nil
          end
        end
        funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
        sent[prefix .. "vis"] = a1 .. "," .. a2 .. ",false"
        if key == "CARD" then
          funcLuaMenuCommand(C.ANIME, a1, a2, N.FOCUS, 2, N.BUTTON)
        end
        dirty = true
      end
    end
  end
end

function OnOpenLayer(a1, a2)
  if a1 == L_ROW and a2 == 0 then
    funcLuaMenuCommand(C.OPEN_LAYER, L_CURSOR, 0)
    funcLuaMenuCommand(C.CTRL, L_ROW, true)
    funcLuaMenuCommand(C.LIST_NUM, L_ROW, 1)
    funcLuaMenuCommand(C.FOCUS_SET, L_ROW, 0)
    funcLuaMenuCommand(C.ATTACH_TRACE, L_ROW, 0, N.CURSOR, false)
    funcLuaMenuCommand(C.POS, L_ROW, -4000, 4000, 0, 0)       -- the anchor: off screen, still holding the focus
    -- every free instance starts hidden (a layout may open with its own pose)
    for _, key in ipairs(FREE_ORDER) do
      was[key] = FREE[key][2]
    end
    if CE.rv ~= nil and CE.rv.opened == nil then
      CE.rv.opened = frame
    end
    Draw()
    if funcLuaCommand(C.FADE_DONE) then
      funcLuaCommand(C.FADE, 0, 0.3)
    end
  end
end

-- the anchor holds the focus; nothing moves with it (the mouse is read in Step)
function OnChangeFocus(a1, a2)
  Trace("focus", tostring(a1), tostring(a2))
end

-- A / Enter on the pad or keyboard: the off-screen anchor row gets the retail
-- «Enter» (OnEnter) but in the game no «decide» follows it (not one OnDecideFocus), so any of
-- the three is the press: OnEnter, OnDecideFocus, or the polled CMD_ENTER (Step). One press = one action
-- (`decided` in the frame, DEBOUNCE after it). The pad acts on the SELECTION, never on the pointer.
function PadDecide(src)
  if frame - last_act < DEBOUNCE or decided then
    return false
  end
  local waiting_page = ui.page ~= nil and ui.page.pick == nil and not ui.page.back and ui.page.act == nil
  if co ~= nil and not waiting_page then
    return false
  end
  last_act = frame
  decided = true
  -- a pointer click that also reaches the anchor acts on the pointer, as the polled click would; on no zone it does
  -- nothing (never the selection: the item under the pointer is the only one a click activates)
  if Call(C.CHECK_INPUT, C.MENU_CTRL, C.LEFT) == true or (mouse.on and Call(C.CHECK_INPUT, C.MENU_CTRL, C.CLICK) == true) then
    mouse.on, mouse.click = true, true
    Click()
    return true
  end
  mouse.on = false            -- the keys lead again
  Trace("decide", src)
  if ui.page ~= nil then
    local p = ui.page
    funcLuaCommand(C.SE, SE_OK)
    if p.zone == "search" then
      p.act = "search"
    else
      p.pick = p.sel
    end
    return true
  end
  Decide()
  return true
end
function OnDecideFocus(a1, a2)
  Trace("decide-event", tostring(a1), tostring(a2))
  if a1 == L_ROW then
    PadDecide("decide")
  end
end

function OnFunction(a1, a2)
  Trace("function", tostring(a1), tostring(a2))
  local id = a1
  for _, v in pairs(FN) do
    if a2 == v then
      id = a2
    end
  end
  local waiting_page = ui.page ~= nil and co ~= nil and ui.page.pick == nil and not ui.page.back and ui.page.act == nil
  if co ~= nil and not waiting_page then
    return 1
  end
  mouse.on = false          -- the keys lead again
  if ui.page ~= nil then
    if not PageKey(id) then
      funcLuaCommand(C.SE, SE_NG)
    end
    return 1
  end
  if ui.popup ~= nil then
    RV.Key(id)
    return 1
  end
  if id == FN.UP or id == FN.DOWN or id == FN.LEFT or id == FN.RIGHT then
    local dx = (id == FN.LEFT and -1) or (id == FN.RIGHT and 1) or 0
    local dy = (id == FN.UP and -1) or (id == FN.DOWN and 1) or 0
    if ui.tab == 1 then
      MoveGrid(dx, dy)
    else
      MoveOrder(dy ~= 0 and dy or dx * G.LIST_ROWS)
    end
  elseif id == FN.TAB_PREV or id == FN.TAB_NEXT then
    SwitchTab(ui.tab + (id == FN.TAB_PREV and -1 or 1))
  elseif id == FN.ORDER_UP or id == FN.ORDER_DOWN then
    if frame - last_act >= 4 then
      last_act = frame
      Order(id == FN.ORDER_UP and -1 or 1)
    end
  elseif id == FN.DETAILS then
    OpenDetails()
  elseif id == FN.SORT then
    CycleSort(1)
  elseif id == FN.FILTER then
    CycleFilter(1)
  elseif id == FN.SEARCH then
    funcLuaCommand(C.SE, SE_OK)
    StartCo(SearchFlow)
  elseif id == FN.PROFILE then
    StartCo(ProfileFlow)
  elseif ExtraFor(id) ~= nil then
    RunExtra(ExtraFor(id))
  else
    return
  end
  return 1
end

function OnEnter(a1, a2)
  if a1 == L_BTN or a1 == L_RET then
    return 1
  end
  if a1 == L_ROW then
    PadDecide("enter")      -- the anchor: the press itself (no «decide» follows in the game)
    return 1
  end
end

function OnBack(a1)
  if ui.page ~= nil and co ~= nil then
    funcLuaCommand(C.SE, SE_BACK)
    ui.page.back = true         -- the page's flow goes one step back
    return 1
  end
  if co ~= nil then
    return 1
  end
  if ui.popup ~= nil then
    if ui.popup.full then
      funcLuaCommand(C.SE, SE_BACK)
      ui.popup.full = nil
      Draw()
    else
      ClosePopup()
    end
    return 1
  end
  if ui.tab == 1 and (ui.query ~= "" or ui.filter ~= 1) and ui.zone == "grid" then
    -- B first clears the search and the filter
    funcLuaCommand(C.SE, SE_BACK)
    ui.query, ui.filter, ui.sel, ui.top = "", 1, 1, 0
    Draw()
    return 1
  end
  funcLuaCommand(C.SE, SE_BACK)
  StartCo(CloseFlow)
  return 1
end

function Step()
  frame = frame + 1
  CE.RevealStep()
  if co ~= nil then
    if coroutine.status(co) == "dead" then
      co = nil
    else
      local ok, err = coroutine.resume(co)
      if not ok then
        Log("error", tostring(err))
        co = nil
        ui.page = nil
        funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
        CE.bg_dirty = true       -- a window / keyboard closed: the background again
        Draw()
      elseif coroutine.status(co) == "dead" then
        co = nil
        last_act = frame      -- the A that closed a window / keyboard does not act again on the screen
      end
    end
  end
  if dirty and (co == nil or (ui.page ~= nil and ui.page.pick == nil and not ui.page.back and ui.page.act == nil)) then
    dirty = false
    Draw()
  end
  PollMouse()
  decided = false
  if ui.toast ~= nil then
    ui.toast_t = ui.toast_t - 1
    if ui.toast_t <= 0 then
      ui.toast = nil
      Draw()
    end
  end
  -- the mods' pictures load asynchronously: draw again once they are in
  if tex_wait then
    tex_frames = tex_frames + 1
    if tex_frames % 10 == 0 then
      local busy = false
      for path, st in pairs(tex_asked) do
        -- a picture already in is not asked again (2): after a gallery of hundreds, only the new ones are polled
        if st ~= 2 then
          local loading = funcLuaCommand(C.TEX_LOADING, Crc(path)) == true
          if loading and tex_frames < 600 then
            busy = true
          elseif not loading then
            tex_asked[path] = 2
          end
        end
      end
      if not busy then
        tex_wait = false
        for k in pairs(sent) do    -- the sprite swaps again, now that the textures exist
          if string.sub(k, -3) == ":sp" then
            sent[k] = nil
          end
        end
        Draw()
      end
    end
  end
end

-- for the tests / other mods: the state as drawn
VRFW_MM = {
  Wrap = Wrap, Units = Units, Crc = Crc, Hits = function() return hits end,
  -- the free layers this script draws on: layer crc -> instances (the plugin's setting must have as many)
  Capacity = function()
    local o = {}
    for _, v in pairs(FREE) do o[#o + 1] = {v[1], v[2]} end
    return o
  end,
  -- the page on screen (tests)
  Page = function()
    return ui.page
  end,
  -- the items of the list page (tests)
  PageItems = function()
    return ui.page and ui.page.items or {}
  end,
  State = function()
    local shown = Shown()
    local ids = {}
    for _, m in ipairs(shown) do ids[#ids + 1] = m.id end
    return {tab = ui.tab, zone = ui.zone, bar = ui.bar, sel = ui.sel, top = ui.top, osel = ui.osel,
            query = ui.query, filter = FILTERS[ui.filter], sort = SORTS[ui.sort], shown = ids,
            selected = shown[ui.sel] and shown[ui.sel].id or "", popup = ui.popup and ui.popup.id or "",
            popup_btn = ui.popup and ui.popup.btn or 0,
            popup_view = ui.popup and RV.ViewIndex() or 0, popup_view_key = ui.popup and ui.popup.view or "",
            popup_top = ui.popup and ui.popup.top or 0,
            page = ui.page and ui.page.kind or "", page_sel = ui.page and ui.page.sel or 0, page_zone = ui.page and ui.page.zone or "",
            page_items = ui.page and ui.page.items and #ui.page.items or 0, page_title = ui.page and ui.page.title or "",
            toast = ui.toast or "", overflow = overflow}
  end,
}
