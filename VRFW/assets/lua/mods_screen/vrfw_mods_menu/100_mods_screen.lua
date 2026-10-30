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
-- Files (run in this order in the same VM): this one (state, data, drawing helpers, header, tabs, the grid, windows,
-- actions, moving, the mouse, the engine callbacks), 110_info_panel.lua (list rows, info panel, «Orden de carga»),
-- 120_record_viewer.lua (a mod's page), 121_modules.lua («Módulos»), 122_news_report.lua («Novedades», «Problemas»,
-- «Conflictos»), 123_settings.lua («Ajustes»), 130_list_pages.lua (list pages), 140_mod_tags.lua (mod tags). The
-- others take the names they share from VRFW_ModsScreen (filled at the end of this file).

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
local Order, ClosePopup, RunExtra, PadDecide

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
-- the mod info block (110_info_panel.lua). L: the layers to draw on, {q = quad layer, l = left text layer, c = centred
-- text layer}
local INFO = {MAIN = {q = "Q1", l = "TL", c = "TC"}, POPUP = {q = "P1", l = "PL", c = "PC"},
              LABEL_W = 196, STEP = 36, DASH = "—"}
-- a mod's page (120_record_viewer.lua … 123_settings.lua): its caches and sizes
local RV = {cache = {}, MAX = 400, ROWS = 13, ORDER = {dependency = 1, error = 2, skipped = 3, warning = 4}}
RV.NEWS_ROWS, RV.MOD_ROWS, RV.FULL_ROWS = 13, 9, 14
RV.MOD_STEP, RV.MOD_HEAD_H = 48, 38     -- «Módulos»: a row's pitch, a category title's height
-- what this file shares with the screen's other files (VRFW_ModsScreen, filled at the end of this file)
local Screen = {}
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
  TEXT = VRFW_Cmd.SET_MENU_TEXT_STRING,          -- CMND_SET_MENU_TEXT_STRING (layer, node, string, idx)
  TEXT_GET = VRFW_Cmd.TEXT_GET,      -- CMND_TEXT_GET (id) -> string
  LANG = VRFW_Cmd.GET_LANGUAGE_CODE,           -- CMND_GET_LANGUAGE_CODE
  MESH_VISIBLE = VRFW_Cmd.SET_MESH_VISIBLE,  -- (layer, mesh, bool, idx)
  PRIM_VISIBLE = 1233047821,  -- (layer, idx, prim, bool)
  LAYER_VISIBLE = VRFW_Cmd.SET_LAYER_VISIBLE,  -- (layer, idx, bool)
  POS = VRFW_Cmd.SET_LAYER_LOCAL_POS,           -- CMND_SET_LAYER_LOCAL_POS (layer, x, y, z, idx); layout units, y up
  SCALE = VRFW_Cmd.SET_LAYER_LOCAL_SCALE,         -- CMND_SET_LAYER_LOCAL_SCALE (layer, sx, sy, sz, idx)
  SPRITE = 558735651,         -- (layer, texture crc, sprite crc, sprite slot crc, 0, idx)
  LOAD_TEX = VRFW_Cmd.LOAD_MENU_RES_TEXTURE,       -- CMND_LOAD_MENU_RES_TEXTURE (path)
  ALPHA = VRFW_Cmd.SET_LAYER_MODEL_ALPHA,         -- CMND_SET_LAYER_MODEL_ALPHA (layer, idx, 0, alpha)
  ATTACH_TRACE = VRFW_Cmd.SET_LAYER_ATTACH_LOCATOR_TRACE,  -- (layer, idx, locator, bool)
  OPEN_LAYER = VRFW_Cmd.OPEN_LAYER,
  ANIME = VRFW_Cmd.PLAY_ANIME_TYPE,         -- CMND_PLAY_ANIME_TYPE (layer, idx, type, 0 in / 2 out, set)
  CTRL = VRFW_Cmd.SET_ENABLE_CTRL_FOCUS,          -- CMND_SET_ENABLE_CTRL_FOCUS (layer, bool)
  FOCUS_SET = 3466097042,     -- (layer, idx)
  LIST_NUM = 3252599449,      -- (layer, count)
  GUIDE_SET = 2209673388,     -- button guide (menu, layer, texts, icons, offsets, {}, {})
  GUIDE_CMD = 452337289,      -- button guide inputs (menu, layer, inputs)
  SE = VRFW_Cmd.SND_PLAY_SE,
  MENU_ACTIVE = 1558704558,   -- (menu, bool)
  CLOSE_MENU = VRFW_Cmd.CLOSE_MENU_OBJECT,     -- CMND_CLOSE_MENU_OBJECT
  FADE = 609722083, FADE_DONE = 2259183189,
  MSG_OPEN = 2289627655, MSG_KIND = 2351835063, MSG_RESULT = 1523741473, MSG_DONE = 682363669, MSG_BUSY = 898725220,
  TEX_LOADING = 1506186496,   -- (texture crc) -> true while still loading (kizuna_town_menu_inc)
  -- the mouse, read here (the engine does not send hover to free layers)
  MOVED = 3272825600,         -- funcLuaMenuCommand () -> the mouse moved this frame
  POINTER = 558229292,        -- funcLuaMenuCommand () -> x, y (screen px, y down)
  CHECK_INPUT = VRFW_Cmd.CHECK_INPUT_CMD, MENU_CTRL = 1332654303, CLICK = 1651523701,  -- CMND_CHECK_INPUT_CMD(MENU_CTRL, CMD_ENTER_CLICK)
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
  COVER_W = 142, COVER_H = 80,    -- a mod's page: its picture (16:9) or its icon (COVER_H square) in the header band
  BAND_H = 112, VTABS_H = 56, FOOT_H = 64,   -- a mod's page: header band, view tabs, shortcut bar
  -- «Módulos»: the module list at the left, the focused module's sheet at the right
  MOD_LIST_W = 760, MOD_PANE_X = 1060, MOD_PANE_W = 590, MOD_PANE_HEAD = 48,
  MOD_VER_W = 150, MOD_NOTES = 3, MOD_CHIPS = 3,   -- the version column, the sheet's points and requirement chips
  SET_VAL_W = 230, SET_HELP_LINES = 6,   -- «Ajustes»: the value box's width, the sheet's help lines
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
local ui = {}               -- see Reset()
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

-- a state table filled again in place (the screen's other files hold the same table)
local function Refill(t, values)
  for k in pairs(t) do
    t[k] = nil
  end
  for k, v in pairs(values) do
    t[k] = v
  end
end

local function Reset()
  Refill(ui, {
    tab = 1,                 -- 1 Instalados, 2 Orden de carga
    zone = "grid",           -- Instalados: "grid" | "bar" (search, filter, sort)
    bar = 1,                 -- 1 search, 2 filter, 3 sort
    sel = 1, top = 0,        -- grid: selected card (1-based in the shown list), first row shown (0-based)
    osel = 1, otop = 1,      -- load order list
    query = "", filter = 1, sort = 1,
    popup = nil,             -- {kind = "mod", id = …, btn = 1}
    page = nil,              -- a list page («¿Quién lo toca?»): {kind = "list", …}
    toast = nil, toast_t = 0,
  })
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
    Refill(cnt, {installed = 0, mods = 0, active = 0, changes = 0, profiles = 1, profile = 0})
    return
  end
  Refill(cnt, {installed = Int(installed), active = Int(active), changes = Int(changes), profiles = math.max(1, Int(np)), profile = Int(p)})
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

-- accent / case folded search key (the framework's folding, VRFW_Text)
local function Fold(s)
  return VRFW_Text.Fold(s)
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

-- ---- a page in the content area (the «¿Quién lo toca?» list, 130_list_pages.lua; the tabs are locked) ---------------------

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
    Screen.DrawPage()
  elseif ui.tab == 1 then
    ClampGrid(Shown())
    DrawGrid()
  else
    Screen.DrawOrder()
  end
  if ui.popup ~= nil then
    Screen.DrawDetails()
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

-- open mod `id`'s page over the one on screen (a requirement chip, a module row) on view `view` («info» when nil);
-- B comes back
function RV.OpenChild(id, view)
  local o = ModById(id)
  if o == nil or ui.popup == nil or o.id == ui.popup.id then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  funcLuaCommand(C.SE, SE_OK)
  ui.popup = {kind = "mod", id = o.id, btn = 1, view = view or "info", top = 0, srow = 1, stop = 0, szone = "rows", mrow = 1,
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
-- full description (in «Módulos»: switch the mod), Y a module's page (in «Módulos») or «Novedades», R3 «¿Quién lo
-- toca?» (in «Conflictos»; in «Módulos»: the focused module's settings)
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
  elseif id == FN.SEARCH and v == "modules" then
    RV.ModuleSettings(m)
  elseif id == FN.PROFILE and v == "modules" then
    StartCo(Toggle)
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
  if id ~= nil and ui.popup ~= nil then
    -- a mod page's module / setting row under the pointer becomes the focused row (the one the keys move on from)
    local p = ui.popup
    local mr = tonumber(string.match(id, "^mrow(%d+)$") or string.match(id, "^mtog(%d+)$") or "")
    local sr = tonumber(string.match(id, "^set(%d+)$") or "")
    if mr ~= nil and mr ~= p.mrow then
      p.mrow, redraw = mr, true
    elseif sr ~= nil and (sr ~= p.srow or p.szone ~= "rows") then
      p.srow, p.szone, redraw = sr, "rows", true
    end
  end
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
  Refill(mouse, {on = false, x = -1, y = -1, logs = 0})
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
    if not Screen.PageKey(id) then
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

-- the names the screen's other files (110_info_panel.lua … 140_mod_tags.lua) take from this one; the state that
-- changes while the screen runs is read through functions
for name, value in pairs({
  BASE = BASE, Badge = Badge, C = C, CE = CE, Call = Call, ClosePopup = ClosePopup, Crc = Crc, Cut = Cut, Draw = Draw,
  DrawPanel = DrawPanel, DrawScrollbar = DrawScrollbar, FN = FN, Fit = Fit, G = G, Hit = Hit, INFO = INFO,
  IconOf = IconOf, Initials = Initials, Int = Int, K = K, KeyOf = KeyOf, Keyboard = Keyboard, Log = Log, M = M,
  ModById = ModById, NameOf = NameOf, OpenDetails = OpenDetails, OrderRows = OrderRows, Quad = Quad,
  RT_SEARCH = RT_SEARCH, RV = RV, SE_MOVE = SE_MOVE, SE_NG = SE_NG, SE_OK = SE_OK, SP = SP, SelectMod = SelectMod,
  Size = Size, StartCo = StartCo, Str = Str, T = T, Text = Text, TextIdKey = TextIdKey, Thumb = Thumb,
  TileOf = TileOf, Toggle = Toggle, Txt = Txt, Units = Units, Warnings = Warnings, Wrap = Wrap, cnt = cnt,
  mouse = mouse, ui = ui,
}) do
  Screen[name] = value
end
function Screen.Mods()
  return mods
end
function Screen.BaseMod()
  return base_mod
end
function Screen.Lang()
  return lang
end
function Screen.SetLang(value)
  lang = value
end
function Screen.TextIds()
  return text_ids
end
VRFW_ModsScreen = Screen
