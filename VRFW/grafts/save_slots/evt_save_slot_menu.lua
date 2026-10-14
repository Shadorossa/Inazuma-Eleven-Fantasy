-- evt_save_slot_menu (plain Lua 5.2 source): the VR-Framework's save slot screen (graft save_slots, mod vr_framework;
-- declared in the framework's menus\save_slots.toml, served as common/script/lua/menu/evt_save_slot_menu.lua.bin).
-- The slot screen opened by EMPEZAR on the title screen (title_menu_inc, see save_slots_inc_1.lua): 3 player cards per
-- page; the player slots come from the save part's layout (CMND_VRFW_SLOT_LAYOUT, config [save.slots] count), more
-- than 3 = pages (L1 / R1). Moved with the slot service from Inazuma Fantasy to the VR-Framework (2026-10-07); the
-- story-complete start's question (StoryAsk) is part of it since 2026-10-08.
-- Layers come from the "Guardar" screen (savedata_management_menu_setting, cloned by research/scripts/slot_build.py).
-- Extension points for other mods (a Lua patch of this stem, run right after this chunk): VRFW_SS_HOOKS / VRFW_SS_API
-- (see "extension points" below), and the reserved 4th card (a slot a mod reserved; its provider VRFW_SS_RESERVED).
-- v4 = ONE CARD PER SLOT (mockup research/test-mods/save_slots/previews/slots_mockup.png):
--   save01_02_list_item x4              = the 4 title bands (engine list focus, cursor arrow): slot 1, 2, 3, reserved
--   save01_04_savedata_detail_window x4 = the 4 card bodies (layout evt_save01_04_card: chapter strip, team emblem
--                                         and name, level line, 5 rows, hint line) on the cloned save01_03 locators
-- Result for the title menu: parameter crc32("evt_save_slot_result") = 0 cancel, else the slot chosen (confirmed).
-- The locked slot (the vanilla save, slot 1 by default): never returned as a result; only a duplicate source /
-- renameable.
-- Controls (user scheme, save-slots.md "Controls"):
--   A / Accept ......... locked slot: message; slot with data: play; empty: new game (+ the story question)
--   X (CMD_FUNC4) ...... Duplicate: slot 1 -> empty target; empty slot -> source with data; slot with data -> empty
--                        target. Polled with CMND_CHECK_INPUT_CMD (no setting change)
--   Start (CMD_FUNC1) .. rename      Triangle/Y (CMD_FUNC3) .. delete (never the locked slot)
--   L1 / R1 ............ previous / next page of player slots (only with more than 3)
-- Source/target choices use the sub_window list (chained yes/no if it does not open). Every input and decision is
-- logged to evt_loader\loader.log ("slot_menu" lines).
-- Docs: docs/game/save-slots.md §10, docs/game/vr-loader.md §1.3.
-- Load marker: funcLuaCommand is registered only AFTER the chunk ran (position-cards.md §4b), so at load time this
-- normally logs nothing; OnInit logs "slot_menu OnInit" as the first sign that the script loaded.
if funcLuaCommand ~= nil then
  pcall(funcLuaCommand, 3661580131, "slot_menu chunk loaded (early)")
end
EVT_SLOT_MENU_BUILD = "2026-10-08 v4.3"
INCLUDE("LUA_PROG_BASE")
INCLUDE("LUA_SAVEDATA_MANAGEMENT_MENU_INC")   -- UpdateHeader + soccer-top header helpers (+ general window inc)
INCLUDE("LUA_MENU_DEF")                       -- MENU_DEF.OpenSubWindow (options list)

-- ---- vr-loader commands (docs/game/vr-loader.md §1, API 1). Filled by slot_build.py from LOADER_CMDS. -------------
-- Loader absent / module off: the engine does not know the hash and the call returns a single false.
local EVT_LOADER = {
  VERSION = 2217361807,         -- () -> api, modules (bit1 = save_slots)
  GET_SLOT = 4245285902,              -- () -> active slot 1..3
  SLOT_INFO = 1195222835,            -- (n) -> exists, chapter, avgLevel, playSeconds, year, month, day,
                                                   --        hour, minute, victories, maxLevel, storyPhase, gameClear,
                                                   --        leaderCharaId, memberCount
  SLOT_INFO_TEXT = 4119688835,  -- (n) -> playTime "387:15:24", date "24/09/2026 01:26"
  SLOT_INFO_EXT = 1726369109,   -- (n) -> exists, storyMembers, chronicleBattles, chronicleHistory,
                                                   --        playerKinds, matches, chronicleRoute, clearBits, futureCleared
  TEAM = 1213476987,             -- (n) -> ok, teamName, emblem "em050243", teamSet (v4 loader; older: false)
  FLAGS = 2050519205,               -- (n) -> locked, isActive, hasFile
  COPY = 3238931942,                 -- (src, dst) -> ok, code (dst must be empty, 2/3)
  DELETE = 2349165707,             -- (n) -> ok, code (2/3; backed up first)
  NAME_GET = 1190421685,         -- (n) -> name, default (true: the unnamed locked slot, shown with TXT.ORIGINAL)
  NAME_SET = 1574661913,         -- (n, name) -> ok
  LOG = 3661580131,                        -- (...) -> evt_loader\loader.log
  LAYOUT = 2351791086,          -- CMND_VRFW_SLOT_LAYOUT () -> playerCount, lockedSlot, active, slot1, slot2, ...
  STORY_GET = 1176769167,       -- CMND_VRFW_STORY_START_GET (n) -> state (a number while the save part has it)
  STORY_SET = 1561008419,       -- CMND_VRFW_STORY_START_SET (n, 0|1) -> ok
}

-- ---- texts --------------------------------------------------------------------------------------------------
-- menu_text rows of the framework (research/mods/VRFW/text/rows/save_slots.toml, 9 languages), read by
-- LoadTexts() in OnInit (no engine call at chunk load). TXT holds the English fallbacks, used when a row is missing
-- (CMND_TEXT_GET returns nothing). Placeholders are string.format ones, same order in every language.
local TXT = {
  HEADER = "Save Slots",
  HEADER_PAGE = "Save Slots · %d/%d",
  GUIDE = "Choose the slot you want to play with.",
  TAB_SLOT = "Slot %d",
  TAB_LOCKED = "Slot %d · Original",
  NEW_GAME = "New game",
  EMPTY_HINT = "Empty slot",
  HINT_EMPTY = "Accept: new game · X: duplicate here",
  HINT_LOCKED = "Read only · X: duplicate to play",
  NO_TEAM = "No team",
  LEVEL_LINE = "Max Lv. %d · avg. %d",
  T_STORY = "Story",
  T_CHRON = "Chronicle",
  MATCHES = "%d matches",
  T_VIC = "Victories",
  T_TIME = "Total time",
  T_SAVED = "Saved",
  ASK_LOAD = "Load Slot %d?\nAnything not saved in the current slot will be lost.",
  ASK_NEW = "Slot %d is empty.\nStart a new game in this slot?",
  LOCKED_MSG = "Slot 1 (the original save) is locked. Duplicate it into another slot to play with mods.",
  ASK_DUP1 = "Slot 1 (the original save) is locked: it can only be duplicated.\nDuplicate it into another slot?",
  NO_EMPTY_FOR = "There is no empty slot to copy Slot %d into.",
  NO_EMPTY = "There is no empty slot.\nDelete the game of another slot first (Delete).",
  COPIED = "Game duplicated into Slot %d.\nPlay Slot %d now?",
  COPY_FAIL = "The game could not be duplicated (code %d).",
  ASK_DELETE = "Do you really want to delete this saved game? This cannot be undone.",
  DELETED = "The game of Slot %d was deleted.\n(A backup copy was kept.)",
  DELETE_FAIL = "The game could not be deleted (code %d).",
  NEED_LOADER = "This feature needs a newer VR-Framework.",
  KB_GUIDE = "Slot name (max. %d characters)",
  KB_FAILED = "The keyboard could not be opened.\nChoose a name from the list.",
  USE_NAME = "Use «%s» as the slot's name?",
  O_CANCEL = "Cancel",
  O_SLOT = "Slot %d%s",
  O_ASK = "%s?",                         -- fallback (chained yes/no): one question per option
  O_CLEAR_NAME = "(no name)",
  ORIGINAL = "Original save",
  PRESETS = {"Main", "Story", "Chronicle", "Tests", "Second", "New game"},   -- preset names (keyboard unavailable)
  CODE = {   -- reasons of the save engine's result codes (save_engine slots.rs)
    [2] = "the slot is locked",
    [3] = "the target slot is not empty",
    [4] = "the source slot is empty",
    [5] = "the game is saving or loading",
    [6] = "read error",
    [7] = "write error (Steam Cloud quota?)",
    [8] = "the copy does not match when read back",
    [9] = "Steam is not ready",
  },
  STORY_ASK = "Have you already finished the Victory Road story?\n・Story completed (Lv. 50).\n" ..
              "・Story achievements completed.\n・The 15 optional national team players.\nEverything else starts from zero.",
  NAME_SEP = " · ",   -- not a text row: the separator between a band label and the slot's name
}
-- row ids: crc32 of the row id in save_slots.toml
local TXT_ID = {
  HEADER = 2375238204,   -- evt_slot_header
  HEADER_PAGE = 1838932901,   -- evt_slot_header_page
  GUIDE = 1216293053,   -- evt_slot_guide
  TAB_SLOT = 185540618,   -- evt_slot_tab
  TAB_LOCKED = 3849086394,   -- evt_slot_tab_locked
  NEW_GAME = 906752550,   -- evt_slot_new_game
  EMPTY_HINT = 3928412748,   -- evt_slot_empty
  HINT_EMPTY = 4045326116,   -- evt_slot_hint_empty
  HINT_LOCKED = 1245836051,   -- evt_slot_hint_locked
  NO_TEAM = 592386843,   -- evt_slot_no_team
  LEVEL_LINE = 372155780,   -- evt_slot_level_line
  T_STORY = 1773661104,   -- evt_slot_story
  T_CHRON = 303165956,   -- evt_slot_chronicle
  MATCHES = 3318315761,   -- evt_slot_matches
  T_VIC = 44950118,   -- evt_slot_victories
  T_TIME = 2853261180,   -- evt_slot_play_time
  T_SAVED = 2063744173,   -- evt_slot_saved
  ASK_LOAD = 2568773135,   -- evt_slot_ask_load
  ASK_NEW = 400182516,   -- evt_slot_ask_new
  LOCKED_MSG = 3798942196,   -- evt_slot_locked_msg
  ASK_DUP1 = 1155934384,   -- evt_slot_ask_dup_locked
  NO_EMPTY_FOR = 1775499394,   -- evt_slot_no_empty_for
  NO_EMPTY = 1867339360,   -- evt_slot_no_empty
  COPIED = 3108879526,   -- evt_slot_copied
  COPY_FAIL = 2580091485,   -- evt_slot_copy_fail
  ASK_DELETE = 1767041756,   -- evt_slot_ask_delete
  DELETED = 684990840,   -- evt_slot_deleted
  DELETE_FAIL = 389263003,   -- evt_slot_delete_fail
  NEED_LOADER = 886148033,   -- evt_slot_need_update
  KB_GUIDE = 3827548981,   -- evt_slot_kb_guide
  KB_FAILED = 2661621363,   -- evt_slot_kb_failed
  USE_NAME = 549624501,   -- evt_slot_use_name
  O_CANCEL = 3052875663,   -- evt_slot_cancel
  O_SLOT = 3110595149,   -- evt_slot_option
  O_ASK = 1883754692,   -- evt_slot_option_ask
  O_CLEAR_NAME = 4212585362,   -- evt_slot_clear_name
  ORIGINAL = 3468625906,   -- evt_slot_original
  PRESETS = {2264824422, 536292316, 1760566090, 4136931049, 2173943423, 412807109},   -- evt_slot_preset_1..6
  CODE = {[2] = 3364728754, [3] = 3213532964, [4] = 569248391, [5] = 1458125329, [6] = 3487591339, [7] = 3102169917, [8] = 676873900, [9] = 1600091706},   -- evt_slot_code_<n>
  STORY_ASK = 40002370,   -- evt_slot_story_ask
}
-- the layout (OnInit: CMND_VRFW_SLOT_LAYOUT; these are the values without it): the player slots in screen order and
-- the locked one (0 = lock off). 3 cards per page; the page shows PLAYER[page * PER_PAGE + 1 ..].
local LOCKED_SLOT = 1
local PLAYER = {1, 2, 3}
local PER_PAGE = 3
local page, pages = 0, 1
-- ---- the reserved slot card (a framework service; the slot's owner mod provides its content) ---------------------
-- The layout has a 4th card for a save slot a MOD reserved (save engine `vrfw_slots_reserve`;
-- CMND_VRFW_SLOT_RESERVED(n) -> reserved, ownerModId, enterable): the first reserved slot above the player slots
-- whose owner's mode is enterable. Never a normal slot: no duplicate / copy / delete / name; Accept enters it
-- (result = its slot). Its content comes from the owner's provider, registered by the owner's Lua patch of this stem
-- (no engine call at chunk load; every field optional):
--   VRFW_SS_RESERVED["<owner mod id>"] = {
--     row = "...", title = "...",        -- band text, card title (a text field may also be a function(api) -> text,
--     ask = "...",                       --   called when shown: no engine call at chunk load); ask = question before
--                                        --   entering from another slot (default TXT.ASK_LOAD)
--     art = {tex = "#/menu/....g4tx",    -- the owner's texture; sprite names below are in it
--            body_on = "...", body_off = "...", band_on = "...", band_off = "...", icon = "...", icon_off = "...",
--            strip = "...", rows = {"...", "...", "...", "...", "..."}},   -- rows: the 5 row icons
--     fill = function(api) return {line = "...", rows = {{"label", "value"}, {"label", "value"}, {"label"}},
--                                  count = 0, empty = "...", footer = "..."} end,   -- row 3's value = count
--     reset = {button = <text id>, ask = "...", done = "...", fail = "... {1} ...",       -- CMD_FUNC2 on the card
--              run = function(api) return ok, code end},
--     locked = true, locked_msg = "...",  -- (2.0.1) shown LOCKED while the owner's mode is off (not enterable):
--   }                                     --   padlock body, dimmed band, Accept = a message only, no reset
-- A reserved slot whose mode is off has no card, unless its provider says `locked = true` (a mode that exists but is
-- not available yet): then the first such slot gets the card, locked. An enterable reserved slot always wins.
-- Without a provider the card shows the owner's id and the slot's own save (time, date) with the framework's art.
-- Without a reserved slot (the framework alone, or the owner's mode off) OnInit sets CARDS = WINDOWS = 3: row band 3
-- hidden by OnSetupLayer, window 3 never opened / hidden, list focus 3.
local CARDS = 4           -- focusable cards in one row: slot 1, 2, 3, reserved card (OnInit: 3 unless it is on)
local RES_CARD = 3        -- 0-based card index of the reserved card
-- v4 (slot_build.py, mockup research/test-mods/save_slots/previews/slots_mockup*.png): ONE CARD PER SLOT. Card i =
-- list row i (save01_02 clone: the title band, engine list focus, cursor) + detail window i (save01_04 clone
-- evt_save01_04_card: the portrait body). Window i shows SlotAt(i) (the page's slots); window 3 = the reserved card.
local WINDOWS = 4
local RES_WIN = 3
local SLOT_RESERVED = 1380583127 --[[crc32("CMND_VRFW_SLOT_RESERVED")]]   -- (n) -> reserved, owner, enterable
local MAX_SLOT = 99       -- save engine MAX_SLOT
local RES_LAST = 12       -- reserved slots looked at for the card: 2 .. RES_LAST (OnInit: past the last player slot)
local res = nil           -- the card's slot while it is on (OnInit): {slot, owner, p = the owner's provider or {}}
-- the providers, by owner mod id (fresh on every run of this chunk; the owners' patches run after it)
VRFW_SS_RESERVED = {}
-- 1.x name (docs/framework/naming.md): same object
EVT_SS_RESERVED = VRFW_SS_RESERVED
-- our texture (dx11/menu/220_img/evt_slot/evt_slot_base.g4tx, built by slot_build.py from slot_card_art.py)
local ART_PATH = "#/menu/220_img/evt_slot/evt_slot_base.g4tx"
-- v4.1 (in game 2026-09-28): the emblem disc, lock and plus are baked into the body variants (the sprite
-- swaps on the retail face nodes did not show); the row icons are our plates (evt_slot_ri_*) on the texture-slot
-- dummies; the emblem goes on the savedata_ch_img01_dmy texture slot (evt_slot_emblem_generic until / unless the
-- emblem texture is in). Sprite hashes are crc32 of the sprite names (filled in by slot_build.py).
local ART = {
  tex = 1615649530,               -- crc32(ART_PATH)
  card_on = 1068284915, card_off = 2592190197,                          -- slot with data
  locked_on = 1111218565, locked_off = 597355934,        -- slot 1 (+ padlock)
  empty_on = 4088989494, empty_off = 1900252534,            -- empty slot (plus)
  emblem_generic = 1655205665,                                               -- 128x128 fallback
  ri_vic = 595401138, ri_time = 4263260390, ri_saved = 3064834527,
}
-- retail row icons of the "Guardar" list (save01_02.g4tx), used unchanged on the title bands
local RETAIL_ICONS = {
  row_tex = 1253411383, row_on = 3989988929, row_off = 3208381064,   -- save_icon_list_s01_on / _off
}
local ROW_OK = 3292070381      -- _list_base_s01_ok: the row of the slot being played ("current")
local ROW_ALPHA = 4231609516   -- CMND_SET_LAYER_MODEL_ALPHA (layer, idx, 0, alpha): locked / empty cards dimmed
local MENU = 3561559540
local KEY_RESULT = 2449975398

-- layers
local L_ROW = 3455690937        -- save01_02_list_item (4 instances: the title bands)
local L_ROWBASE = 2782306059    -- save01_01_list_attach_base (cloned layout: 4 row locators)
local L_WINBASE = 3903826878    -- save01_03_detail_window_attach_base (cloned layout: 4 window locators)
local L_WIN = 536044352         -- save01_04_savedata_detail_window (4 instances, layout evt_save01_04_card)
local L_HEADER = 575058101      -- mainmenu90_01_header
local L_GUIDE_LINE = 3078308064 -- mainmenu90_05_content_guide_line01
local L_CURSOR = 2296367164     -- cmn05_01_cursor
local L_BTN_GUIDE = 1138543975  -- mainmenu01_06_base_button_guide
local WIN_LABELS = {2244889632, 482811290, 1807756556, 4121213103}   -- attach labels evt_slot_win01..04 (objbin)

local C = {
  TEXT = 1083631230,          -- CMND_SET_MENU_TEXT_STRING (layer, node, string, idx)
  TEXT_GET = 4074371074,      -- CMND_TEXT_GET (text id) -> string
  TEXT_NUM = 1583337767,      -- (string, "NUM", n) -> string (retail "Capítulo <NUM>")
  MESH_VISIBLE = 3405944500,  -- (layer, mesh, bool, idx)
  LAYER_VISIBLE = 711242136,  -- (layer, idx, bool)
  SPRITE = 558735651,         -- (layer, textureCrc, spriteCrc, nodeCrc, 0, idx)
  LOAD_TEX = 839427544,       -- CMND_LOAD_MENU_RES_TEXTURE (path)
  TEX_LOADING = 1506186496,   -- (textureCrc) -> true while still loading (kizuna_town_menu_inc)
  PRIM_INDEX = 1927054058,    -- CMND_SEARCH_PRIM_INDEX (layer, idx, primName) -> prim
  PRIM_VALUE = 3609943765,    -- (layer, idx, prim, value)
  PRIM_VISIBLE = 1233047821,  -- (layer, idx, primName, bool)
  ATTACH_TRACE = 1774843228,  -- CMND_SET_LAYER_ATTACH_LOCATOR_TRACE (layer, idx, label, bool)
  OPEN_LAYER = 629267548,
  ANIME = 3781155141,         -- CMND_PLAY_ANIME_TYPE (layer, idx, type, event 0 in / 2 out, set)
  FOCUS_ENABLE = 3518307824,  -- CMND_SET_ENABLE_CTRL_FOCUS (layer, bool)
  FOCUS_ACTIVE = 102308320,   -- CMND_IS_CTRL_FOCUS_ACTIVE (layer)
  FOCUS_IDX = 2603265800,     -- (layer) -> focused instance
  FOCUS_SET = 3466097042,     -- (layer, idx) set the focused instance (retail OnChangeLayerGroup)
  FOCUS_MARK = 1778826357,    -- (layer, idx, bool) (retail OnChangeFocus)
  LIST_NUM = 3252599449,      -- (layer, count) (retail OnOpenLayer of the list)
  CURSOR_LOC = 381797568,     -- CMND_SET_CURSOR_LOCATOR (layer, crc32("cursor"), idx, instanceCount)
  GUIDE_SET = 2209673388,     -- button guide (menu, layer, texts, icons, a, b, c)
  GUIDE_CMD = 452337289,      -- button guide commands (menu, layer, cmds)
  SE = 1917805374,
  MENU_ACTIVE = 1558704558,   -- (menu, bool)
  CLOSE_MENU = 320421347,     -- CMND_CLOSE_MENU_OBJECT
  FADE = 609722083,           -- (1 out / 0 in, seconds)
  FADE_DONE = 2259183189,
  P_SET = 3860611758, P_CLEAR = 3363400568, P_HAS = 2947612279,   -- parameter store
  MSG_OPEN = 2289627655, MSG_KIND = 2351835063, MSG_RESULT = 1523741473, MSG_DONE = 682363669,
  MSG_BUSY = 898725220,
  MSG_DEFAULT_NO = 3125954271,   -- (true, false) after MSG_KIND(2, 15): retail "Reiniciar datos" confirm [inferred: cursor on No]
  -- game keyboard (GENERAL_WINDOW.WaitAndSwkbWindowCoroutine, general_window_inc_6.00.11.00:36)
  KB_OPEN = 962493425, KB_ACTIVE = 422535539, KB_TEXT = 1487869455, KB_CANCELLED = 1447363287, KB_FORCE_END = 3351189333,
  STR_LEN = 1407583914, STR_SPACES = 2431241294,
  -- generic sub_window list (research/test-mods/skill_slots/evt_skill_slots.lua EVT_Pick, worked in game)
  SUBWIN_TEXT = 2315959435,      -- 0x8A0ABC8B (row 0.., string)
  SUBWIN_POS = 63483614,         -- 0x03C8AEDE (x, y)
  IS_OPEN_MENU = 3693934564,     -- CMND_IS_OPEN_MENU_OBJECT (menu, layer)
  EXIST_MENU = 2231168902,       -- CMND_IS_EXIST_MENU_OBJECT (menu)
}
-- TXT from the text rows (OnInit, first thing: every later text use reads TXT). A row the game does not answer keeps
-- the fallback literal.
local function LoadTexts()
  local function Get(id, fallback)
    local ok, s = pcall(funcLuaCommand, C.TEXT_GET, id)
    if ok and type(s) == "string" and s ~= "" then
      return s
    end
    return fallback
  end
  for k, id in pairs(TXT_ID) do
    if type(id) == "table" then
      for i, sub in pairs(id) do
        TXT[k][i] = Get(sub, TXT[k][i])
      end
    else
      TXT[k] = Get(id, TXT[k])
    end
  end
end

local SUB_WINDOW = 968210065      -- sub_window
local KB_MENU = 1671247147        -- keyboard_input_menu
local PLACEHOLDER_TEXT = 968662090 -- any valid text id; every row is overwritten with SUBWIN_TEXT
-- extra keys on the rows (MENU_CMD_INFO added by slot_build.py): OnFunction receives these ids
local FN_RENAME = 981253811     -- CMD_FUNC1
local FN_DELETE = 3656619642     -- CMD_FUNC3
local FN_DUP = 3393070439           -- CMD_FUNC4 (X): duplicate
local KB_TITLE = 2568160623                 -- retail menu_text «Nombre» (Name)
local KB_MAX = 20
-- button guide: text ids / icon text ids / command key hashes (menu_text.cfg.bin, equip_menu_inc UpdateEquipButtonGuide)
local G_ACCEPT, G_NAME, G_DELETE = 1847312674 --[[Aceptar]], 2568160623 --[[Nombre]], 3961481199 --[[Eliminar]]
local I_ENTER, I_FUNC1, I_FUNC3 = 2750714971 --[[<CMD_ENTER>]], 203473330 --[[<CMD_FUNC1>]], 3794706590 --[[<CMD_FUNC3>]]
local K_ENTER, K_FUNC1, K_FUNC3 = 1981080283 --[[CMD_ENTER]], 637335895 --[[CMD_FUNC1]], 3421673595 --[[CMD_FUNC3]]
-- X: CMD_FUNC4 = pad 15 (Square / Xbox X) and keyboard code 23 ('X') in input_ctrl_3.00.18.00 MENU_CTRL
-- (pad codes: 3 Start, 12 Triangle, 15 Square, 27 confirm, 28 back)
local K_FUNC4, I_FUNC4 = 1435897304 --[[CMD_FUNC4]], 2085238077 --[[<CMD_FUNC4>]]
-- the reserved card's provider `reset` (button text id, texts, run): CMD_FUNC2 (unused by this screen), polled in Step
-- like X
local K_FUNC2, I_FUNC2 = 3170216173 --[[CMD_FUNC2]], 2387151820 --[[<CMD_FUNC2>]]
local G_DUP = 3316700371   -- menu_text row evt_slot_dup_text (text/rows/save_slots.toml; the guide needs a text id)
-- pages (more than 3 player slots): L1 / R1 polled in Step with CMND_CHECK_INPUT_CMD on MENU_CTRL (the IF bank's way);
-- the guide shows the retail «Cambiar página» with the R1 glyph
local K_PAGE_PREV, K_PAGE_NEXT = 3559725168, 2955903379
local G_PAGE, I_R1, K_R1 = 884337385 --[[Cambiar página]], 1596629152 --[[<CMD_FUNCR1>]], 942075773 --[[CMD_FUNCR1]]
local MENU_CTRL, CHECK_INPUT = 1332654303, 4265778440   -- CMND_CHECK_INPUT_CMD(MENU_CTRL, cmd)
local SE_OK, SE_DECIDE, SE_BACK = 3848881948, 4235359837, 202039849

-- card nodes (evt_save01_04_card.g4pkm = save01_04 with the v4.1 geometry; the hashes are the retail node names).
-- Text nodes (styles: slot_build.CARD_TEXT_STYLE): CAT1..5 = row labels, CAT6 = team name, SUB1 = level line,
-- SUB2 / SUB3 = row 1 / 2 values, TITLE = row 4 value, DATE = row 5 value, SUB4 = the hint line at the bottom.
local N = {
  TITLE = 3034079643,          -- _text_save_info_title01: row 4 value, the total play time as text (right-aligned style)
  CAT = {713023922, 3010899976, 3295772830, 1511331133, 756164011, 3021698065},   -- _text_category_title01..06
  SUB = {3220414085, 653971263, 1375600553, 3482937866},                         -- _text_category_sub01..04
  DATE = 1259583259,           -- _text_last_save_time01
  STORY_IMG = 3518571570,      -- _savedata_story_img01_dmy (mesh, 424x64 strip at the top of the body)
  STORY_IMG_NODE = 2597729045, -- savedata_story_img01_dmy (sprite target)
  CH_IMG = 2041544085,         -- _savedata_ch_img01_dmy (v4.1: the team emblem quad, 120x120 on the baked disc)
  CH_IMG_NODE = 799111224,     -- savedata_ch_img01_dmy (texture slot)
  STORY_STAR = 4023127831,     -- _clear_story_star01 (30x30 at the right of the Historia row)
  CH_STARS = {2046236296, 3774760754, 2549708708, 161341959, 2124075665, 3885204267, 2425664445, 2862636, 1999412922},
  -- the retail chapter faces: unused since v4.1 (off screen, hidden)
  FACES = {616408107, 3182753169, 3400779015, 1423397028, 600858674, 3134796168, 3453878558, 1566645391, 711339033, 1252107772},
  PLATFORM = {4063249485, 2766120397, 1037497463, 1255261409, 3568652610},   -- _save_info_platform_dmy01, sub01..04
  PLATFORM_NODES = {3110032234, 2201512143, 439433589, 1832258019, 4082277440},  -- their texture slots (sprite targets)
  MODE_PLATES = {2824491253, 827523407},                                       -- _save_mode_base01/02 (rows 1..2 icons)
  COLONS = {2607508411, 1633965784},
  VICTORY_MESH = {1177874785, 3542215152},   -- _count_v_base02, _gtxt_victory01 (off screen, hidden)
  BASE_NODE = 3786803635,      -- save_info_base01 (the body sprite target)
}
-- number primitives (names from the objbin CMenuCreatePrimitiveComponent; retail UpdateDetailWindow)
-- In-game round 1 (2026-09-27): the retail time prims (24x35 digits + colons) ran into the "Tiempo total" label and
-- the retail victory prims are centred on their locator (they spilled past the card edge). Now the time is TEXT on
-- N.TITLE and the count (victories / fragments) uses the retail "matches played" prim (blue shared digits,
-- right-aligned at its locator, scaled by slot_build.COUNT_SCALE); every other prim stays off screen and hidden.
local P = {
  H = 973998683, M = 1292450509, S = 3556797303,              -- retail total play time (off screen, hidden)
  H2 = 683386293, M2 = 1606194467, S2 = 3333801113,           -- compare copy (hidden)
  MAX = 4178101926, MAX2 = 1610716956,                        -- MAX: row 3 count (victories / fragments); MAX2 hidden
  AVG = 2856230673, AVG2 = 859295403,                         -- retail players (off screen, hidden)
  VIC = 3602710871, VIC_BIG = 1337217261,                     -- retail victories (off screen, hidden)
}
local HIDDEN_PRIMS = {P.H, P.M, P.S, P.H2, P.M2, P.S2, P.MAX2, P.AVG, P.AVG2, P.VIC, P.VIC_BIG}

local info = {}
local names = {unnamed = {}}  -- slot -> name; unnamed[slot] = the loader says it shows the default name
local active = 1
local focus = 0
local evt_co = nil
local has_ext = false   -- loader has FLAGS/COPY/DELETE/NAME_* (else: no duplicate / rename / delete)

-- ---- helpers --------------------------------------------------------------------------------------------------
--@lib evt_menu_kit.lua#Call

-- the reserved card's slot: the first slot above the player slots that a mod reserved and whose mode is enterable
local function IsPlayer(n)
  for _, p in ipairs(PLAYER) do
    if p == n then
      return true
    end
  end
  return false
end

local function FindReserved()
  local locked = nil
  for n = 2, RES_LAST do
    local r, owner, enterable = false, nil, false
    if not IsPlayer(n) then
      r, owner, enterable = Call(SLOT_RESERVED, n)
    end
    if r == true and type(owner) == "string" and owner ~= "" then
      local p = VRFW_SS_RESERVED[owner]
      p = type(p) == "table" and p or {}
      if enterable == true then
        return {slot = n, owner = owner, p = p}
      elseif locked == nil and p.locked == true then
        -- the owner's mode is off but its provider shows the card locked (a mode not available yet)
        locked = {slot = n, owner = owner, p = p, locked = true}
      end
    end
  end
  return locked
end

-- a provider text field: a string, or a function(api) -> string called now (nil when absent or failing)
local function ResText(v)
  if type(v) == "function" then
    local ok, s = pcall(v, VRFW_SS_API)
    v = ok and s or nil
  end
  if v == nil then
    return nil
  end
  return tostring(v)
end

-- texture and sprite crc of the provider's art `key` (nil = the provider names none)
local function ResArt(key)
  local a = res ~= nil and res.p.art or nil
  if type(a) ~= "table" or type(a.tex) ~= "string" or type(a[key]) ~= "string" then
    return nil, nil
  end
  return CRC32(a.tex), CRC32(a[key])
end

--@lib evt_menu_kit.lua#Int

local function Chapter(s)
  local c = Int(s.chapter)
  if c < 1 and Int(s.storyPhase) > 0 then
    c = math.floor(Int(s.storyPhase) / 10000)
  end
  if c < 1 then
    c = 1
  elseif c > 9 then
    c = 9            -- savedata_story_img01..09 are shipped
  end
  return c
end

local function StoryTex(c)
  local path = string.format("#/menu/220_img/savedata_img/savedata_story_img%02d.g4tx", c)
  local name = string.format("savedata_story_img%02d", c)
  return path, name
end

-- team emblem: dx11/menu/200_icon/01_icon_emblem/<em>.g4tx (512x512 texture of the same name; retail
-- team_select_tournament_finalstage loads em110001 this way)
local function EmblemTex(em)
  return "#/menu/200_icon/01_icon_emblem/" .. em .. ".g4tx", em
end

-- the slot card i shows (0-based; nil = no slot there: the last page's free cards); the reserved card = its slot
local function SlotAt(i)
  if i == RES_CARD then
    return res ~= nil and res.slot or nil
  end
  if i < 0 or i >= PER_PAGE then
    return nil
  end
  return PLAYER[page * PER_PAGE + i + 1]
end

-- one string per line (the loader prints at most 8 arguments)
local function Log(...)
  local t = table.pack(...)
  local parts = {}
  for k = 1, t.n do
    parts[k] = tostring(t[k])
  end
  Call(EVT_LOADER.LOG, "slot_menu " .. table.concat(parts, " "))
end

-- " · name" or "" (rows shorten long names)
local function NameSuffix(n, short)
  local nm = names[n]
  if type(nm) ~= "string" or nm == "" then
    return ""
  end
  if short then
    -- the band is 424 px: keep 14 UTF-8 characters
    local out, k = "", 0
    for ch in string.gmatch(nm, "[^\128-\191][\128-\191]*") do
      k = k + 1
      if k > 14 then
        out = out .. "…"
        break
      end
      out = out .. ch
    end
    nm = out
  end
  return TXT.NAME_SEP .. nm
end

-- band label: "Slot N · name" ("Slot 1 · Original" for the unnamed locked slot)
local function TabLabel(n)
  local suffix = NameSuffix(n, true)
  if n == LOCKED_SLOT and (suffix == "" or names.unnamed[n]) then
    return string.format(TXT.TAB_LOCKED, n)
  end
  return string.format(TXT.TAB_SLOT, n) .. suffix
end

local function ReadName(n)
  local nm, default = Call(EVT_LOADER.NAME_GET, n)
  -- the default name is a flag of the loader, never compared as text: the screen draws its own label for it
  names.unnamed[n] = default == true or (n == LOCKED_SLOT and (type(nm) ~= "string" or nm == ""))
  if names.unnamed[n] and n == LOCKED_SLOT then
    names[n] = TXT.ORIGINAL
  elseif type(nm) == "string" then
    names[n] = nm
  else
    names[n] = ""
  end
end

-- "24/09/2026 14:11" -> "24/09/26 14:11" (the date box of v4.1 is 192 px, right of the "Guardado" label)
local function ShortDate(dt)
  local d, m, yy, rest = string.match(dt, "^(%d+)/(%d+)/%d%d(%d%d)%s+(.-)%s*$")
  if d ~= nil then
    return d .. "/" .. m .. "/" .. yy .. " " .. rest
  end
  return dt
end

local function ReadInfo(n)
  local t = {Call(EVT_LOADER.SLOT_INFO, n)}
  local s = {
    exists = t[1] == true, chapter = t[2], avgLevel = t[3], playSeconds = t[4], year = t[5], month = t[6], day = t[7],
    hour = t[8], minute = t[9], victories = t[10], maxLevel = t[11], storyPhase = t[12], gameClear = t[13],
    leader = t[14], members = t[15], playTime = "", date = "", teamName = "", emblem = "",
  }
  if s.exists then
    local e = {Call(EVT_LOADER.SLOT_INFO_EXT, n)}
    s.storyMembers, s.chBattles, s.chHistory, s.playerKinds = Int(e[2]), Int(e[3]), Int(e[4]), Int(e[5])
    s.matches, s.chRoute, s.clearBits = Int(e[6]), Int(e[7]), Int(e[8])
    local pt, dt = Call(EVT_LOADER.SLOT_INFO_TEXT, n)
    if type(pt) == "string" then
      s.playTime = pt
    end
    if type(dt) == "string" and dt ~= "" then
      s.date = ShortDate(dt)
    else
      s.date = string.format("%02d/%02d/%02d %02d:%02d", Int(s.day), Int(s.month), Int(s.year) % 100, Int(s.hour), Int(s.minute))
    end
    -- the team (loader CMND_VRFW_SLOT_TEAM; older loaders: no emblem, the disc shows the chapter star instead)
    local ok, tn, em = Call(EVT_LOADER.TEAM, n)
    if ok == true then
      if type(tn) == "string" then
        s.teamName = tn
      end
      if type(em) == "string" and em:match("^em%d+%a?$") then
        s.emblem = em
      end
    end
    Log("card", n, "team", tostring(tn), "emblem", tostring(em), "time", s.playTime, "date", s.date)
  end
  return s
end

local function SetPrim(idx, name, value, visible)
  local prim = funcLuaMenuCommand(C.PRIM_INDEX, L_WIN, idx, name)
  if prim ~= nil then
    funcLuaMenuCommand(C.PRIM_VALUE, L_WIN, idx, prim, value)
  end
  funcLuaMenuCommand(C.PRIM_VISIBLE, L_WIN, idx, name, visible)
end

local function Mesh(idx, mesh, visible)
  funcLuaMenuCommand(C.MESH_VISIBLE, L_WIN, mesh, visible, idx)
end

local function Text(idx, node, s)
  funcLuaMenuCommand(C.TEXT, L_WIN, node, s, idx)
end

local function Sprite(idx, tex, sprite, node)
  funcLuaMenuCommand(C.SPRITE, L_WIN, tex, sprite, node, 0, idx)
end

-- CMND_LOAD_MENU_RES_TEXTURE is asynchronous: a sprite swap before the texture is in shows nothing. A card drawn
-- while one of its textures is still loading uses a fallback and is drawn again by Step once they are all in.
local wait_tex = {}        -- textureCrc -> true: textures a card is waiting for
local windows_ready = false
local wait_frames = 0
local function TexReady(crc)
  if funcLuaCommand(C.TEX_LOADING, crc) == true then
    if wait_frames < 900 then
      wait_tex[crc] = true
    end
    return false
  end
  return true
end

-- row 4 value: the total play time as text ("387:15:24" from SLOT_INFO_TEXT, else built from the seconds)
local function TimeText(idx, s, visible)
  local t = ""
  if visible then
    t = s.playTime
    if type(t) ~= "string" or t == "" then
      local secs = Int(s.playSeconds)
      t = string.format("%d:%02d:%02d", math.floor(secs / 3600), math.floor(secs / 60) % 60, secs % 60)
    end
  end
  Text(idx, N.TITLE, t)
end

-- row 3 value: victories (slot cards) / the provider's count (reserved card) on the right-aligned count prim
local function CountPrim(idx, v, visible)
  SetPrim(idx, P.MAX, v, visible)
end

-- the row icons. Slot card: rows 1..2 = the retail Story / Chronicle plates (layout defaults), rows 3..5 = our plates
-- (Victorias / Tiempo total / Guardado). Reserved card: the provider's 5 plates (art.rows, in its texture). Our plates
-- go on the texture-slot dummies: rows 3, 4, 5 -> _save_info_platform_dmy01, _sub_dmy01, _sub_dmy02; rows 1, 2 ->
-- _sub_dmy03, _sub_dmy04.
local ROW_ICONS = {
  slot = {false, false, ART.ri_vic, ART.ri_time, ART.ri_saved},
}
local ROW_PLATFORM = {4, 5, 1, 2, 3}
local function RowIcons(idx, kind)
  local set, tex = ROW_ICONS[kind], ART.tex
  if kind == "reserved" then
    set, tex = nil, nil
    local a = res ~= nil and res.p.art or nil
    if type(a) == "table" and type(a.tex) == "string" and type(a.rows) == "table" then
      tex, set = CRC32(a.tex), {}
      for r = 1, 5 do
        set[r] = type(a.rows[r]) == "string" and CRC32(a.rows[r]) or false
      end
    end
  end
  for _, m in ipairs(N.MODE_PLATES) do
    Mesh(idx, m, kind == "slot")
  end
  for r = 1, 5 do
    local p = ROW_PLATFORM[r]
    local sp = set ~= nil and set[r] or false
    if sp then
      Sprite(idx, tex, sp, N.PLATFORM_NODES[p])
    end
    Mesh(idx, N.PLATFORM[p], sp ~= false)
  end
end

-- everything a card can show, off (the fill functions turn on what they use)
local function ClearCard(idx)
  Text(idx, N.TITLE, "")
  for _, node in ipairs(N.CAT) do
    Text(idx, node, "")
  end
  for _, node in ipairs(N.SUB) do
    Text(idx, node, "")
  end
  Text(idx, N.DATE, "")
  for _, m in ipairs(N.CH_STARS) do
    Mesh(idx, m, false)
  end
  for k = 1, #N.FACES do
    Mesh(idx, N.FACES[k], false)
  end
  for _, m in ipairs(N.VICTORY_MESH) do
    Mesh(idx, m, false)
  end
  Mesh(idx, N.STORY_IMG, false)
  Mesh(idx, N.CH_IMG, false)
  Mesh(idx, N.STORY_STAR, false)
  for _, name in ipairs(HIDDEN_PRIMS) do
    SetPrim(idx, name, 0, false)
  end
  CountPrim(idx, 0, false)
  TimeText(idx, nil, false)
  for _, m in ipairs(N.COLONS) do
    Mesh(idx, m, false)
  end
  RowIcons(idx, "none")
end

-- ---- the reserved card (window 3): only while a reserved slot is on (FindReserved) -----------------------------
-- Title + line under it, rows 1..3 = the provider's `fill` (labels / values; row 3's value = `count` on the count
-- prim), rows 4 / 5 = total time and save date of the slot's own save, bottom line = `footer`.
local function FillReservedWindow(idx)
  local s = info[res.slot] or {exists = false}
  local p = res.p
  local d = {}
  if type(p.fill) == "function" then
    local ok, v = pcall(p.fill, VRFW_SS_API)
    if ok and type(v) == "table" then
      d = v
    else
      Log("reserved card", res.owner, "fill error", tostring(v))
    end
  end
  ClearCard(idx)
  local stex, strip = ResArt("strip")
  if stex ~= nil and TexReady(stex) then
    Sprite(idx, stex, strip, N.STORY_IMG_NODE)
    Mesh(idx, N.STORY_IMG, true)
  end
  Text(idx, N.CAT[6], ResText(p.title) or res.owner)
  Text(idx, N.SUB[1], tostring(d.line or ""))
  local rows = type(d.rows) == "table" and d.rows or {}
  for r = 1, 3 do
    local row = rows[r]
    if type(row) == "table" then
      Text(idx, N.CAT[r], tostring(row[1] or ""))
      if r < 3 then
        Text(idx, N.SUB[r + 1], tostring(row[2] or ""))
      end
    end
  end
  if type(d.count) == "number" then
    CountPrim(idx, d.count, true)
  end
  Text(idx, N.CAT[4], TXT.T_TIME)
  TimeText(idx, s, s.exists)
  Text(idx, N.CAT[5], TXT.T_SAVED)
  Text(idx, N.DATE, s.exists and s.date or tostring(d.empty or TXT.EMPTY_HINT))
  if d.footer ~= nil then
    Text(idx, N.SUB[4], tostring(d.footer))
  end
  RowIcons(idx, "reserved")
end

-- ---- a slot card (window 0..2) ------------------------------------------------------------------------------
local function FillWindow(idx)
  if idx == RES_WIN then
    if res ~= nil then
      FillReservedWindow(idx)
    end
    return
  end
  local n = SlotAt(idx)
  ClearCard(idx)
  if n == nil then
    return            -- a free card of the last page
  end
  local s = info[n] or {exists = false}
  if not s.exists then
    -- the dashed circle + plus is in the body (evt_slot_card_empty_*, SetBase)
    Text(idx, N.CAT[6], TXT.NEW_GAME)
    Text(idx, N.SUB[1], TXT.EMPTY_HINT)
    Text(idx, N.SUB[4], has_ext and TXT.HINT_EMPTY or "")
    return
  end
  local ch = Chapter(s)
  local path, name = StoryTex(ch)
  local pc = CRC32(path)
  if TexReady(pc) then
    Sprite(idx, pc, CRC32(name), N.STORY_IMG_NODE)
  end
  Mesh(idx, N.STORY_IMG, TexReady(pc))
  -- the emblem on the baked disc (the texture slot of the old chronicle strip); the generic one until it is in, or
  -- when the loader names no emblem
  local etex, esprite = ART.tex, ART.emblem_generic
  if s.emblem ~= "" then
    local epath, ename = EmblemTex(s.emblem)
    if TexReady(CRC32(epath)) then
      etex, esprite = CRC32(epath), CRC32(ename)
    end
  end
  TexReady(ART.tex)
  Sprite(idx, etex, esprite, N.CH_IMG_NODE)
  Mesh(idx, N.CH_IMG, true)
  local team = s.teamName ~= "" and s.teamName or TXT.NO_TEAM
  Text(idx, N.CAT[6], team)
  Text(idx, N.SUB[1], string.format(TXT.LEVEL_LINE, Int(s.maxLevel), Int(s.avgLevel)))
  local function Num(textId, v)
    return funcLuaCommand(C.TEXT_NUM, funcLuaCommand(C.TEXT_GET, textId), "NUM", v)
  end
  Text(idx, N.CAT[1], TXT.T_STORY)
  Text(idx, N.SUB[2], Num(2849482415, ch))                 -- Capítulo <NUM>
  Mesh(idx, N.STORY_STAR, s.clearBits % 2 == 1)
  Text(idx, N.CAT[2], TXT.T_CHRON)
  Text(idx, N.SUB[3], string.format(TXT.MATCHES, s.chBattles))
  Text(idx, N.CAT[3], TXT.T_VIC)
  CountPrim(idx, Int(s.victories), true)
  Text(idx, N.CAT[4], TXT.T_TIME)
  TimeText(idx, s, true)
  Text(idx, N.CAT[5], TXT.T_SAVED)
  Text(idx, N.DATE, s.date)
  if n == LOCKED_SLOT then
    Text(idx, N.SUB[4], TXT.HINT_LOCKED)
  end
  RowIcons(idx, "slot")
end

-- the body sprite follows the focus (retail: base01 on the focused window, base02 on the others)
local function SetBase(i)
  local on = i == focus
  local n = SlotAt(i)
  local s = info[n or -1] or {exists = false}
  -- body variants (v4.1): the emblem disc / padlock / plus are part of the body sprite; the reserved card: the
  -- provider's body (its texture), else the framework's card body
  local sp
  if i == RES_WIN and res ~= nil and res.locked then
    -- a locked reserved card: the framework's padlock body, dimmed like the locked slot 1
    TexReady(ART.tex)
    Sprite(i, ART.tex, on and ART.locked_on or ART.locked_off, N.BASE_NODE)
    funcLuaMenuCommand(ROW_ALPHA, L_WIN, i, 0, 0.7)
    return
  elseif i == RES_WIN then
    local t, b = ResArt(on and "body_on" or "body_off")
    if t ~= nil then
      TexReady(t)
      Sprite(i, t, b, N.BASE_NODE)
      funcLuaMenuCommand(ROW_ALPHA, L_WIN, i, 0, 1)
      return
    end
    sp = on and ART.card_on or ART.card_off
  elseif n == nil then
    TexReady(ART.tex)
    Sprite(i, ART.tex, ART.empty_off, N.BASE_NODE)
    funcLuaMenuCommand(ROW_ALPHA, L_WIN, i, 0, 0.25)   -- a free card of the last page: faint, no slot
    return
  elseif not s.exists then
    sp = on and ART.empty_on or ART.empty_off
  elseif n == LOCKED_SLOT then
    sp = on and ART.locked_on or ART.locked_off
  else
    sp = on and ART.card_on or ART.card_off
  end
  TexReady(ART.tex)
  Sprite(i, ART.tex, sp, N.BASE_NODE)
  -- locked slot 1 and empty slots: the whole card dimmed (the row band too, see SetupRow)
  local dim = i < PER_PAGE and (n == LOCKED_SLOT or not s.exists)
  funcLuaMenuCommand(ROW_ALPHA, L_WIN, i, 0, dim and 0.7 or 1)
end

local function HighlightWindows()
  for i = 0, WINDOWS - 1 do
    SetBase(i)
  end
end

local function RowText(i)
  if i == RES_CARD then
    return res ~= nil and (ResText(res.p.row) or res.owner) or ""
  end
  local n = SlotAt(i)
  return n ~= nil and TabLabel(n) or ""
end

local function SetupRow(i)
  local t = RowText(i)
  local n = SlotAt(i)
  local s = info[n or -1] or {exists = false}
  -- current slot: the retail "ok" base on its band; the locked slot and empty slots: dimmed; a free card: faint
  funcLuaMenuCommand(C.MESH_VISIBLE, L_ROW, ROW_OK, i < PER_PAGE and n ~= nil and n == active and n ~= LOCKED_SLOT, i)
  local dim = (i < PER_PAGE and (n == LOCKED_SLOT or not s.exists)) or (i == RES_CARD and res ~= nil and res.locked == true)
  funcLuaMenuCommand(ROW_ALPHA, L_ROW, i, 0, (n == nil and i < PER_PAGE) and 0.25 or (dim and 0.7 or 1))
  funcLuaMenuCommand(C.TEXT, L_ROW, 931545948 --[[_text_list01_on]], t, i)
  funcLuaMenuCommand(C.TEXT, L_ROW, 3705682548 --[[_text_list01_off]], t, i)
  if i == RES_CARD then
    -- the reserved band: the provider's bases and icon (its texture); what it does not name stays retail
    local bt, bon = ResArt("band_on")
    local _, boff = ResArt("band_off")
    if bt ~= nil and boff ~= nil then
      TexReady(bt)
      funcLuaMenuCommand(C.SPRITE, L_ROW, bt, bon, 496140502 --[[list_base_s01_on]], 0, i)
      funcLuaMenuCommand(C.SPRITE, L_ROW, bt, boff, 3517400201 --[[list_base_s01_off]], 0, i)
    end
    local it, ion = ResArt("icon")
    local _, ioff = ResArt("icon_off")
    if it ~= nil then
      TexReady(it)
      funcLuaMenuCommand(C.SPRITE, L_ROW, it, ion, 2880627768 --[[list_icon_dmy_s01_on]], 0, i)
      funcLuaMenuCommand(C.SPRITE, L_ROW, it, ion, 3688370359 --[[list_icon_dmy_s01_ok]], 0, i)
      funcLuaMenuCommand(C.SPRITE, L_ROW, it, ioff or ion, 2527308690 --[[list_icon_dmy_s01_off]], 0, i)
      return
    end
  end
  -- retail "Guardar" row icon (save_icon_list_s01) on the icon dummies
  funcLuaMenuCommand(C.SPRITE, L_ROW, RETAIL_ICONS.row_tex, RETAIL_ICONS.row_on, 2880627768 --[[list_icon_dmy_s01_on]], 0, i)
  funcLuaMenuCommand(C.SPRITE, L_ROW, RETAIL_ICONS.row_tex, RETAIL_ICONS.row_on, 3688370359 --[[list_icon_dmy_s01_ok]], 0, i)
  funcLuaMenuCommand(C.SPRITE, L_ROW, RETAIL_ICONS.row_tex, RETAIL_ICONS.row_off, 2527308690 --[[list_icon_dmy_s01_off]], 0, i)
end

-- Accept always; Name on a slot with data; Delete on a slot with a file (never the locked one)
local function CanRename(n)
  return has_ext and n ~= nil and info[n] ~= nil and info[n].exists
end

local function CanDelete(n)
  return has_ext and n ~= nil and n ~= LOCKED_SLOT and info[n] ~= nil and (info[n].exists or info[n].hasFile)
end

local function UpdateButtonGuide()
  local n = SlotAt(focus)
  local texts, icons, cmds, z = {G_ACCEPT}, {I_ENTER}, {K_ENTER}, {0}
  if pages > 1 then
    -- L1 / R1: the pages of player slots (the retail «Cambiar página» guide)
    table.insert(texts, G_PAGE)
    table.insert(icons, I_R1)
    table.insert(cmds, K_R1)
    table.insert(z, 0)
  end
  if focus == RES_CARD then
    local rs = (res ~= nil and not res.locked) and res.p.reset or nil
    if type(rs) == "table" and type(rs.run) == "function" and type(rs.button) == "number" then
      -- the provider's reset key, next to Accept where the other cards show Delete
      table.insert(texts, rs.button)
      table.insert(icons, I_FUNC2)
      table.insert(cmds, K_FUNC2)
      table.insert(z, 0)
    end
    funcLuaMenuCommand(C.GUIDE_SET, MENU, L_BTN_GUIDE, texts, icons, z, z, z)
    funcLuaMenuCommand(C.GUIDE_CMD, MENU, L_BTN_GUIDE, cmds)
    return
  end
  if has_ext then
    table.insert(texts, G_DUP)
    table.insert(icons, I_FUNC4)
    table.insert(cmds, K_FUNC4)
    table.insert(z, 0)
  end
  if CanRename(n) then
    table.insert(texts, G_NAME)
    table.insert(icons, I_FUNC1)
    table.insert(cmds, K_FUNC1)
    table.insert(z, 0)
  end
  if CanDelete(n) then
    table.insert(texts, G_DELETE)
    table.insert(icons, I_FUNC3)
    table.insert(cmds, K_FUNC3)
    table.insert(z, 0)
  end
  funcLuaMenuCommand(C.GUIDE_SET, MENU, L_BTN_GUIDE, texts, icons, z, z, z)
  funcLuaMenuCommand(C.GUIDE_CMD, MENU, L_BTN_GUIDE, cmds)
end

--@lib evt_menu_kit.lua#Close

-- yes/no general window (retail pattern of title_menu_inc "gameend"): true = yes
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
  Log("ask result raw", tostring(r), "yes", r == 0 and "yes" or "no")
  return r == 0
end

-- yes/no with the cursor on "No" (retail savedata_management_menu_reset CheckWindowCoroutine): true = yes
-- Window kind (2, 15) does NOT report through MSG_RESULT: "yes" sets the parameter 1449645767 (retail
-- chara_bank_menu:1119-1127, title_menu_2 OpenRematchConfirmGeneralWin_Coroutine, savedata reset: P_HAS(1449645767)
-- = yes, cleared afterwards). In game 2026-09-24c MSG_RESULT read "no" although the user chose yes.
local P_YES = 1449645767
local function AskDanger(text)
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
  funcLuaCommand(C.P_CLEAR, P_YES)
  funcLuaCommand(C.MSG_OPEN, text, 0, 0, 0, 0, 0, false)
  funcLuaCommand(C.MSG_KIND, 2, 15)
  funcLuaCommand(C.MSG_DEFAULT_NO, true, false)
  while funcLuaCommand(C.MSG_BUSY) do
    coroutine.yield()
  end
  local yes = false
  while not funcLuaCommand(C.MSG_DONE) and not yes do
    yes = funcLuaCommand(C.P_HAS, P_YES) == true
    coroutine.yield()
  end
  if not yes then
    yes = funcLuaCommand(C.P_HAS, P_YES) == true
  end
  local r = funcLuaCommand(C.MSG_RESULT)
  funcLuaCommand(C.P_CLEAR, P_YES)
  while not funcLuaCommand(C.MSG_DONE) do
    coroutine.yield()
  end
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
  Log("ask(danger) raw result", tostring(r), "param yes", yes and "yes" or "no")
  return yes
end

-- OK-only message (retail network_invite_menu_inc pattern)
--@lib evt_menu_kit.lua#Message

local function CodeText(fmt, code)
  local t = string.format(fmt, Int(code))
  if TXT.CODE[Int(code)] ~= nil then
    t = t .. "\n(" .. TXT.CODE[Int(code)] .. ")"
  end
  return t
end

-- ---- extension points --------------------------------------------------------------------------------------
-- Other mods extend this screen with a Lua patch of the stem evt_save_slot_menu (run right after this chunk; e.g.
-- Inazuma Fantasy's INAROGUE card). The patch only registers functions (no engine call at chunk load):
--   if type(VRFW_SS_HOOKS) == "table" and type(VRFW_SS_HOOKS.new_game) == "table" then
--     table.insert(VRFW_SS_HOOKS.new_game, function(n, api) ... end)
--   end
-- VRFW_SS_HOOKS.new_game: function(n, api), run in the screen's coroutine after «Nueva partida» on the empty slot n
--   was confirmed (and after the framework's own story question) and before the screen closes with result n; a hook
--   may ask (api.Ask yields). Errors are logged and the next hook runs.
-- VRFW_SS_API (version 1): the screen's helpers a hook needs: Call(cmd, ...) (protected funcLuaCommand), Log(...)
--   (loader.log, "slot_menu" lines), Ask(text) -> yes, AskDanger(text) -> yes (cursor on No), Message(text), the
--   command ids C.TEXT_GET (text id -> string) / C.TEXT_NUM / C.SE, the sound ids SE.OK / DECIDE / BACK, MENU.
-- Fresh tables on every run of this chunk: the hooks are those of the patches that run after it.
VRFW_SS_HOOKS = {new_game = {}}
EVT_SS_HOOKS = VRFW_SS_HOOKS   -- 1.x name (docs/framework/naming.md): same object
VRFW_SS_API = {
  version = 1,
  Call = Call, Log = Log, Ask = Ask, AskDanger = AskDanger, Message = Message,
  C = {TEXT_GET = C.TEXT_GET, TEXT_NUM = C.TEXT_NUM, SE = C.SE},
  SE = {OK = SE_OK, DECIDE = SE_DECIDE, BACK = SE_BACK},
  MENU = MENU,
}
EVT_SS_API = VRFW_SS_API   -- 1.x name (docs/framework/naming.md): same object

local function RunHooks(name, n)
  local list = VRFW_SS_HOOKS[name]
  if type(list) ~= "table" then
    return
  end
  for k, fn in ipairs(list) do
    if type(fn) == "function" then
      local ok, err = pcall(fn, n, VRFW_SS_API)
      if not ok then
        Log("hook error", name, k, tostring(err))
      end
    end
  end
end

-- the chapter strip and the team emblem of a slot (loaded once each; CMND_LOAD_MENU_RES_TEXTURE is idempotent)
local loaded_tex = {}
local function LoadCardTextures(s)
  if not s.exists then
    return
  end
  local paths = {(StoryTex(Chapter(s)))}
  if s.emblem ~= "" then
    table.insert(paths, (EmblemTex(s.emblem)))
  end
  for _, path in ipairs(paths) do
    if not loaded_tex[path] then
      loaded_tex[path] = true
      funcLuaMenuCommand(C.LOAD_TEX, path)
    end
  end
end

-- the header: the page while there is more than one
local function HeaderText()
  if pages > 1 then
    return string.format(TXT.HEADER_PAGE, page + 1, pages)
  end
  return TXT.HEADER
end

-- read slot n (info, name, file flag)
local function ReadSlot(n)
  info[n] = ReadInfo(n)
  ReadName(n)
  if has_ext then
    local _, _, hasFile = Call(EVT_LOADER.FLAGS, n)
    info[n].hasFile = hasFile == true
  end
end

-- the textures of the cards on the current page
local function LoadPageTextures()
  for i = 0, PER_PAGE - 1 do
    local n = SlotAt(i)
    if n ~= nil and info[n] ~= nil then
      LoadCardTextures(info[n])
    end
  end
end

-- re-read every slot (after duplicate / delete / rename) and redraw rows, windows and the guide
local function Refresh()
  local a = Call(EVT_LOADER.GET_SLOT)
  if type(a) == "number" and a >= 1 and a <= MAX_SLOT then
    active = math.floor(a)
  end
  for _, n in ipairs(PLAYER) do
    ReadSlot(n)
  end
  LoadPageTextures()
  if res ~= nil then
    info[res.slot] = ReadInfo(res.slot)
  end
  for i = 0, CARDS - 1 do
    SetupRow(i)
  end
  for i = 0, WINDOWS - 1 do
    FillWindow(i)
  end
  HighlightWindows()
  UpdateButtonGuide()
  funcLuaMenuCommand(C.TEXT, L_HEADER, 1220590795 --[[_text_sub_title02]], HeaderText())
end

local function EmptyTargets()
  local t = {}
  for _, n in ipairs(PLAYER) do
    if n ~= LOCKED_SLOT and info[n] ~= nil and not info[n].exists then
      table.insert(t, n)
    end
  end
  return t
end

-- ---- options list -------------------------------------------------------------------------------------------
local subwin_result = -1

function EVT_SlotMenu_OnSubWindow(a1)
  subwin_result = type(a1) == "number" and a1 or -1
  Log("subwindow callback", tostring(a1))
  funcLuaCommand(C.CLOSE_MENU, SUB_WINDOW)
end

-- Chained yes/no fallback: first "yes" wins; the last option is "Cancel" (never asked).
local function ChooseByQuestions(options)
  for i = 1, #options - 1 do
    if Ask(string.format(TXT.O_ASK, options[i])) then
      return i
    end
  end
  return 0
end

-- Options list: returns the 1-based option, or 0 (cancel / back / last option "Cancel").
local function Choose(tag, options)
  Log("choose open", tag, #options)
  subwin_result = -1
  local ids = {}
  for i = 1, #options do
    ids[i] = PLACEHOLDER_TEXT
  end
  local opened = false
  if MENU_DEF ~= nil and MENU_DEF.OpenSubWindow ~= nil then
    funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
    MENU_DEF.OpenSubWindow("EVT_SlotMenu_OnSubWindow", "", #ids, ids, 9, 0, {}, 0, false, false, 15)
    for i = 1, #options do
      funcLuaCommand(C.SUBWIN_TEXT, i - 1, options[i])
    end
    for _ = 1, 60 do          -- ~1 s: the list must appear, else fall back to yes/no windows
      if funcLuaCommand(C.IS_OPEN_MENU, SUB_WINDOW, L_CURSOR) then
        opened = true
        break
      end
      coroutine.yield()
    end
    if opened then
      funcLuaCommand(C.SUBWIN_POS, 960, -300)
      while funcLuaMenuCommand(C.EXIST_MENU, SUB_WINDOW) do
        coroutine.yield()
      end
    else
      funcLuaCommand(C.CLOSE_MENU, SUB_WINDOW)
      coroutine.yield()
    end
    funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
  end
  local r
  if opened then
    r = subwin_result >= 0 and subwin_result + 1 or 0
  else
    Log("choose fallback yes/no", tag)
    r = ChooseByQuestions(options)
  end
  if r >= #options then
    r = 0             -- "Cancel"
  end
  Log("choose result", tag, r, r > 0 and options[r] or "cancel")
  return r
end

local function SlotLabel(m)
  return string.format(TXT.O_SLOT, m, NameSuffix(m, false))
end

-- copy src -> dst in the loader; on success offer to play dst. Returns true when the menu was closed.
local function DoCopy(src, dst)
  local ok, code = Call(EVT_LOADER.COPY, src, dst)
  Log("copy", src, dst, ok == true, code)
  if ok ~= true then
    Message(CodeText(TXT.COPY_FAIL, code))
    Refresh()
    return false
  end
  funcLuaCommand(C.SE, SE_DECIDE)
  Refresh()
  if Ask(string.format(TXT.COPIED, dst, dst)) then
    funcLuaCommand(C.SE, SE_DECIDE)
    Log("close after copy", dst)
    Close(dst)
    return true
  end
  return false
end

-- game keyboard (same arguments as GENERAL_WINDOW.WaitAndSwkbWindowCoroutine, which polls 422535539 right after the
-- open call). Returns string / "" (= default name) / nil (cancelled) / false (the keyboard did not open).
local function AskName(initial)
  if funcLuaCommand(C.KB_ACTIVE) then
    Log("keyboard was still active: force end")
    funcLuaCommand(C.KB_FORCE_END, "")
    coroutine.yield()
  end
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, false)
  local opened = false
  for attempt = 1, 2 do
    funcLuaCommand(C.KB_OPEN, 0, initial or "", KB_TITLE, 0, KB_MAX, 0, 0, 0, 0, 0, 0, true, true, 2, string.format(TXT.KB_GUIDE, KB_MAX), 0, false, false)
    local act = funcLuaCommand(C.KB_ACTIVE) == true
    local exists = funcLuaMenuCommand(C.EXIST_MENU, KB_MENU) == true
    Log("keyboard open attempt", attempt, "active", act and "yes" or "no", "menu exists", exists and "yes" or "no")
    if act then
      opened = true
      break
    end
    for _ = 1, 10 do         -- the menu may appear a few frames later
      coroutine.yield()
      if funcLuaCommand(C.KB_ACTIVE) == true then
        opened = true
        break
      end
    end
    if opened then
      break
    end
  end
  if not opened then
    funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
    Log("keyboard did NOT open")
    return false
  end
  local frames, live, changes = 0, "", 0
  while funcLuaCommand(C.KB_ACTIVE) do
    frames = frames + 1
    local t = funcLuaCommand(C.KB_TEXT)      -- live buffer (same getter; no side effects: handler 0xC4F360)
    if type(t) == "string" and t ~= live then
      if t ~= "" then
        live = t
      end
      changes = changes + 1
      if changes <= 8 then
        Log("keyboard live text", t)
      end
    end
    coroutine.yield()
  end
  local text = funcLuaCommand(C.KB_TEXT)
  local rawc = funcLuaCommand(C.KB_CANCELLED)
  local cancelled = rawc == true
  funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
  Log("keyboard closed after frames", frames, "raw cancelled", tostring(rawc), "text [" .. tostring(text) .. "]", "live [" .. live .. "]")
  -- 2026-09-24c: cancelled = true and "" although the user typed a name. Do not trust the flag alone: if a name was
  -- seen while the keyboard was open, offer it.
  if (type(text) ~= "string" or text == "") and live ~= "" then
    if Ask(string.format(TXT.USE_NAME, live)) then
      return live
    end
    return nil
  end
  if cancelled or type(text) ~= "string" then
    return nil
  end
  local len = funcLuaCommand(C.STR_LEN, text)
  if len == 0 or funcLuaCommand(C.STR_SPACES, text) == true then
    return ""    -- empty / spaces only = back to the default name
  end
  return text
end

local function Rename(i)
  local n = SlotAt(i)
  if not CanRename(n) then
    Log("rename refused", n, "has_ext", has_ext and "yes" or "no", "exists", info[n] ~= nil and info[n].exists and "yes" or "no")
    return
  end
  funcLuaCommand(C.SE, SE_OK)
  local cur = names[n]
  if n == LOCKED_SLOT and names.unnamed[n] then
    cur = ""
  end
  local nm = AskName(cur)
  if nm == false then
    -- keyboard unavailable here: preset names from a list
    Message(TXT.KB_FAILED)
    local opts = {}
    for _, v in ipairs(TXT.PRESETS) do
      table.insert(opts, v)
    end
    table.insert(opts, TXT.O_CLEAR_NAME)
    table.insert(opts, TXT.O_CANCEL)
    local k = Choose("preset name", opts)
    if k == 0 then
      return
    end
    nm = k == #opts - 1 and "" or opts[k]
  end
  if nm == nil then
    Log("rename cancelled", n)
    return
  end
  local ok = Call(EVT_LOADER.NAME_SET, n, nm)
  Log("rename", n, ok == true, nm)
  funcLuaCommand(C.SE, SE_DECIDE)
  Refresh()
end

-- the provider's reset on the reserved card (CMD_FUNC2): its question, its run (the owner archives its slot), its
-- answer texts ({1} = the code it returns)
local function ReservedReset()
  local rs = res ~= nil and res.p.reset or nil
  if type(rs) ~= "table" or type(rs.run) ~= "function" then
    return
  end
  funcLuaCommand(C.SE, SE_OK)
  if not AskDanger(ResText(rs.ask) or "") then
    Log("reserved reset: answered No", res.owner)
    return
  end
  local okc, ok, code = pcall(rs.run, VRFW_SS_API)
  Log("reserved reset", res.owner, okc and ok == true, tostring(okc and code or ok))
  Refresh()
  if okc and ok == true then
    funcLuaCommand(C.SE, SE_DECIDE)
    local done = ResText(rs.done)
    if done ~= nil then
      Message(done)
    end
  else
    local fail = ResText(rs.fail)
    if fail ~= nil then
      Message((fail:gsub("{1}", tostring(code))))
    end
  end
end

local function Delete(i)
  local n = SlotAt(i)
  if not CanDelete(n) then
    if n == nil then
      return
    end
    Log("delete refused", n, "has_ext", has_ext and "yes" or "no", "exists", info[n] ~= nil and info[n].exists and "yes" or "no",
        "hasFile", info[n] ~= nil and info[n].hasFile and "yes" or "no")
    return
  end
  funcLuaCommand(C.SE, SE_OK)
  if not AskDanger(TXT.ASK_DELETE) then
    Log("delete: answered No", n)
    return
  end
  local ok, code = Call(EVT_LOADER.DELETE, n)
  Log("delete", n, ok == true, code)
  if ok == true then
    funcLuaCommand(C.SE, SE_DECIDE)
    Refresh()
    Message(string.format(TXT.DELETED, n))
  else
    Message(CodeText(TXT.DELETE_FAIL, code))
    Refresh()
  end
end

local function Play(n)
  if n == active or Ask(string.format(TXT.ASK_LOAD, n)) then
    funcLuaCommand(C.SE, SE_DECIDE)
    Log("close: play", n, "active", active)
    Close(n)
  end
end

-- the story-complete start (save part story_start, docs/framework/save-slots.md §7): yes = the slot's marker turns
-- «pending» and the title applies the post-story state once in that slot (graft story_start). Without it in the save
-- part (CMND_VRFW_STORY_START_GET unknown: not a number) nothing is asked.
local function StoryAsk(n)
  local st = Call(EVT_LOADER.STORY_GET, n)
  if type(st) ~= "number" then
    Log("story question: no story-complete start in the save part: not asked")
    return
  end
  local yes = Ask(TXT.STORY_ASK)
  local ok = Call(EVT_LOADER.STORY_SET, n, yes and 1 or 0)
  Log("story question slot", n, yes and "yes" or "no", "marker", ok == true and "written" or "refused")
end

local function NewGame(n)
  if Ask(string.format(TXT.ASK_NEW, n)) then
    funcLuaCommand(C.SE, SE_DECIDE)
    StoryAsk(n)
    RunHooks("new_game", n)
    Log("close: new game", n)
    Close(n)
  end
end

-- empty slot n: choose the source among the slots with data
local function DuplicateInto(n)
  local sources, opts = {}, {}
  for _, m in ipairs(PLAYER) do
    if m ~= n and info[m] ~= nil and info[m].exists then
      table.insert(sources, m)
      table.insert(opts, SlotLabel(m))
    end
  end
  if #sources == 0 then
    Message(string.format(TXT.ASK_NEW, n))
    return
  end
  table.insert(opts, TXT.O_CANCEL)
  local k = Choose("copy source", opts)
  if k > 0 then
    DoCopy(sources[k], n)
  end
end

-- slot 1: choose the empty target
local function DuplicateFrom(src)
  local targets = EmptyTargets()
  if #targets == 0 then
    Message(TXT.NO_EMPTY)
    return
  end
  local opts = {}
  for _, t in ipairs(targets) do
    table.insert(opts, string.format(TXT.O_SLOT, t, ""))
  end
  table.insert(opts, TXT.O_CANCEL)
  local k = Choose("copy target", opts)
  if k > 0 then
    DoCopy(src, targets[k])
  end
end

local function Decide(i)
  if i == RES_CARD then
    if res == nil then
      return
    end
    Log("decide reserved card", res.slot, res.owner, "active", active, "locked", res.locked == true)
    if res.locked then
      -- the owner's mode is not available: its message only, never entered
      funcLuaCommand(C.SE, SE_BACK)
      local msg = ResText(res.p.locked_msg)
      if msg ~= nil and msg ~= "" then
        Message(msg)
      end
      return
    end
    funcLuaCommand(C.SE, SE_OK)
    if active == res.slot or Ask(ResText(res.p.ask) or string.format(TXT.ASK_LOAD, res.slot)) then
      funcLuaCommand(C.SE, SE_DECIDE)
      Close(res.slot)
    end
    return
  end
  local n = SlotAt(i)
  if n == nil then
    return            -- a free card of the last page
  end
  local s = info[n] or {exists = false}
  Log("decide slot", n, "exists", s.exists and "yes" or "no", "active", active)
  funcLuaCommand(C.SE, SE_OK)
  if n == LOCKED_SLOT then
    if has_ext and Ask(TXT.ASK_DUP1) then
      DuplicateFrom(n)
    elseif not has_ext then
      Message(TXT.LOCKED_MSG)
    end
  elseif s.exists then
    Play(n)
  else
    NewGame(n)
  end
end

-- X: duplicate from / into the focused slot
local function Duplicate(i)
  if i == RES_CARD then
    return            -- a reserved slot is never duplicated
  end
  local n = SlotAt(i)
  if n == nil then
    return
  end
  local s = info[n] or {exists = false}
  Log("duplicate key slot", n, "exists", s.exists and "yes" or "no")
  if not has_ext then
    Message(TXT.NEED_LOADER)
    return
  end
  funcLuaCommand(C.SE, SE_OK)
  if s.exists then
    if #EmptyTargets() == 0 then
      Message(string.format(TXT.NO_EMPTY_FOR, n))
      return
    end
    DuplicateFrom(n)
  else
    DuplicateInto(n)
  end
end

-- move the engine focus to card i (the retail OnChangeFocus sequence)
local function FocusCard(i)
  if i == focus then
    return
  end
  funcLuaMenuCommand(C.FOCUS_SET, L_ROW, i)
  funcLuaMenuCommand(C.FOCUS_MARK, L_ROW, i, true)
  funcLuaMenuCommand(C.ANIME, L_ROW, focus, 2734777837 --[[Focus]], 2, 973515837 --[[button]])
  funcLuaMenuCommand(C.ANIME, L_ROW, i, 2734777837 --[[Focus]], 0, 973515837 --[[button]])
  funcLuaMenuCommand(C.CURSOR_LOC, L_ROW, 3313461902 --[[cursor]], i, CARDS)
  focus = i
end

-- L1 / R1: the previous / next page of player slots (wraps); a focus on a free card of the new page goes to card 0
local function Page(d)
  if pages <= 1 then
    return
  end
  page = (page + d) % pages
  funcLuaCommand(C.SE, SE_OK)
  Log("page", page + 1, "of", pages)
  if focus ~= RES_CARD and SlotAt(focus) == nil then
    FocusCard(0)
  end
  Refresh()
end

--@lib evt_menu_kit.lua#StartCo

-- ---- engine callbacks -----------------------------------------------------------------------------------------
function OnInit()
  LoadTexts()
  Log("OnInit build", EVT_SLOT_MENU_BUILD, "MENU_DEF", MENU_DEF ~= nil and MENU_DEF.OpenSubWindow ~= nil and "yes" or "no")
  local a = Call(EVT_LOADER.GET_SLOT)
  if type(a) == "number" and a >= 1 and a <= MAX_SLOT then
    active = math.floor(a)
  end
  -- the player slots of the layout (config [save.slots] count; reserved slots skipped)
  local lay = {Call(EVT_LOADER.LAYOUT)}
  if type(lay[1]) == "number" and lay[1] >= 1 then
    PLAYER = {}
    for k = 4, 3 + math.floor(lay[1]) do
      if type(lay[k]) == "number" and lay[k] >= 1 then
        table.insert(PLAYER, math.floor(lay[k]))
      end
    end
    if #PLAYER == 0 then
      PLAYER = {1, 2, 3}
    end
    LOCKED_SLOT = type(lay[2]) == "number" and math.floor(lay[2]) or LOCKED_SLOT
  end
  pages = math.max(1, math.ceil(#PLAYER / PER_PAGE))
  RES_LAST = math.max(RES_LAST, PLAYER[#PLAYER] + 4)
  Log("layout: player slots", table.concat(PLAYER, ","), "locked", LOCKED_SLOT, "pages", pages)
  res = FindReserved()
  if res == nil then
    CARDS, WINDOWS = PER_PAGE, PER_PAGE   -- no reserved slot whose owner's mode is on: no reserved card
    Log("reserved card off (no reserved slot with an enterable owner): 3 cards")
  else
    Log("reserved card: slot", res.slot, "owner", res.owner, "provider", next(res.p) ~= nil and "yes" or "no",
        res.locked and "LOCKED (mode off)" or "enterable")
    if type(res.p.art) == "table" and type(res.p.art.tex) == "string" then
      funcLuaMenuCommand(C.LOAD_TEX, res.p.art.tex)
    end
  end
  -- the focus: the active slot's card (its page), else the first player slot that can be played
  local pos = nil
  for k, n in ipairs(PLAYER) do
    if n == active and n ~= LOCKED_SLOT then
      pos = k
    end
  end
  if res ~= nil and active == res.slot and not res.locked then
    page, focus = 0, RES_CARD
  else
    if pos == nil then
      pos = (PLAYER[1] == LOCKED_SLOT and #PLAYER > 1) and 2 or 1
    end
    page, focus = math.floor((pos - 1) / PER_PAGE), (pos - 1) % PER_PAGE
  end
  funcLuaMenuCommand(C.LOAD_TEX, ART_PATH)
  has_ext = type(Call(EVT_LOADER.NAME_GET, PLAYER[1])) == "string"
  for _, n in ipairs(PLAYER) do
    ReadSlot(n)
  end
  LoadPageTextures()
  if res ~= nil then
    info[res.slot] = ReadInfo(res.slot)
  end
  funcLuaCommand(C.P_CLEAR, KEY_RESULT)
end

-- ---- card layout: N cards spread evenly over the screen width ------------------------------------------------------
-- The positions are data: the layout (save_slots.toml: evt_save01_01_slot _list01..04 = the bands' locators,
-- evt_save01_03_slot _atc_save_info* = the windows' locators, the same x per card) already spreads the PER_PAGE
-- player cards: centre(k, n) = gap + CARD_W / 2 + k * (CARD_W + gap), gap = (SCREEN_W - n * CARD_W) / (n + 1); the
-- reserved 4th card's locator is centre(3, 4). The layout carries the bands' click zones (_touch_list01) and the
-- cursor anchor, so with the usual 3 cards nothing moves at run time. Only a count the layout does not spread (the
-- 4-card row while a mod's reserved slot is on) moves card k by centre(k, CARDS) - LayoutCentre(k): band and window of
-- one card by the same delta through the same command (the instance's local position, which the instance's click
-- zone follows: docs/game/ui/mouse-support.md §1.1). Never node writes: the old runtime locator moves (2.2.183 /
-- 2.2.195) failed per card («no effect of the move») and dropped one group back to the retail x while the other kept
-- its move (headers and bodies apart). One log line per pass: bodies x, headers x (left edges), applied / fallback.
local SCREEN_W, CARD_W = 1920, 424
local GPOS = 499270986         -- CMND_GET_MESH_GLOBAL_POSITION (layer, idx, node) -> x, y, z
local LAYER_GET, LAYER_SET = 2834507455, 1389957207   -- layer local position (layer, idx) / (layer, x, y, z, idx)
local N_ROW_EDGE, N_WIN_EDGE = 3025401186, 1215790087 -- _list_base_s01_on / _save_info_base01 (left-edge nodes)
local layout_done, layout_co, rows_open = false, nil, false

local function CardCentre(k, n)
  local gap = (SCREEN_W - n * CARD_W) / (n + 1)
  return gap + CARD_W / 2 + k * (CARD_W + gap)
end

-- the centre the layout data gives card k (save_slots.toml, same formula)
local function LayoutCentre(k)
  if k < PER_PAGE then
    return CardCentre(k, PER_PAGE)
  end
  return CardCentre(k, k + 1)
end

local function Meas(layer, idx, node)
  local ok, x = pcall(funcLuaMenuCommand, GPOS, layer, idx, node)
  if ok and type(x) == "number" then
    return x
  end
  return nil
end

local function WaitFrames(f)
  for _ = 1, f do
    coroutine.yield()
  end
end

-- the left edges of the n bands and windows, once they stopped moving (the open animations); nil = no measure
local function MeasureEdges(n)
  local prev
  for _ = 1, 15 do
    local cur, same = {rows = {}, wins = {}}, prev ~= nil
    for k = 0, n - 1 do
      cur.rows[k], cur.wins[k] = Meas(L_ROW, k, N_ROW_EDGE), Meas(L_WIN, k, N_WIN_EDGE)
      if cur.rows[k] == nil or cur.wins[k] == nil then
        return nil
      end
      if same and (math.abs(cur.rows[k] - prev.rows[k]) > 0.5 or math.abs(cur.wins[k] - prev.wins[k]) > 0.5) then
        same = false
      end
    end
    if same then
      return cur
    end
    prev = cur
    WaitFrames(4)
  end
  return prev
end

local function EdgeList(t, n)
  local s = {}
  for k = 0, n - 1 do
    s[#s + 1] = string.format("%.1f", t[k])
  end
  return table.concat(s, ",")
end

-- why the measured edges are not the wanted ones (nil = all right): every band over its window, at centre(k, n)
local function EdgeError(m, n)
  for k = 0, n - 1 do
    if math.abs(m.rows[k] - m.wins[k]) > 4 then
      return "card " .. k .. " header " .. string.format("%.1f", m.rows[k]) .. " body " .. string.format("%.1f", m.wins[k])
    end
    local want = CardCentre(k, n) - CARD_W / 2
    if math.abs(m.wins[k] - want) > 4 then
      return "card " .. k .. " at " .. string.format("%.1f", m.wins[k]) .. " want " .. string.format("%.1f", want)
    end
  end
  return nil
end

local function LayoutCards()
  local n = math.max(1, math.min(CARDS, WINDOWS))
  local base, moved = {}, false
  for k = 0, n - 1 do
    local dx = CardCentre(k, n) - LayoutCentre(k)
    if math.abs(dx) > 0.5 then
      moved = true
    end
    local okr, rx, ry, rz = pcall(funcLuaMenuCommand, LAYER_GET, L_ROW, k)
    local okw, wx, wy, wz = pcall(funcLuaMenuCommand, LAYER_GET, L_WIN, k)
    base[k] = {
      dx = dx,
      row = {okr and type(rx) == "number" and rx or 0, okr and type(ry) == "number" and ry or 0, okr and type(rz) == "number" and rz or 0},
      win = {okw and type(wx) == "number" and wx or 0, okw and type(wy) == "number" and wy or 0, okw and type(wz) == "number" and wz or 0},
    }
  end
  local function Place(on)
    for k = 0, n - 1 do
      local b = base[k]
      local d = on and b.dx or 0
      pcall(funcLuaMenuCommand, LAYER_SET, L_ROW, b.row[1] + d, b.row[2], b.row[3], k)
      pcall(funcLuaMenuCommand, LAYER_SET, L_WIN, b.win[1] + d, b.win[2], b.win[3], k)
    end
  end
  if moved then
    Place(true)
    WaitFrames(2)
  end
  local m = MeasureEdges(n)
  if m == nil then
    Log("card layout", n, "cards", moved and "moved" or "layout", "no measure")
    return
  end
  local err = EdgeError(m, n)
  local how = moved and "applied (moved)" or "applied (layout)"
  if err ~= nil and moved then
    Place(false)        -- both groups back together: headers stay over their bodies
    WaitFrames(2)
    m = MeasureEdges(n) or m
    how = "fallback to the layout x"
  end
  Log("card layout", n, "cards bodies x", EdgeList(m.wins, n), "headers x", EdgeList(m.rows, n), how, err and ("reason " .. err) or "")
end

-- called from Step: starts the layout once (the windows are up and the list is open), then resumes it
local function StepLayout()
  if layout_done then
    return
  end
  if layout_co == nil then
    if not (windows_ready and rows_open) then
      return
    end
    layout_co = coroutine.create(function()
      WaitFrames(3)
      LayoutCards()
    end)
  end
  local ok, err = coroutine.resume(layout_co)
  if not ok then
    Log("card layout error", tostring(err))
    layout_done = true
  elseif coroutine.status(layout_co) == "dead" then
    layout_done = true
  end
end

function OnSetupLayer(a1, a2)
  if a1 == L_HEADER then
    SetupSoccerTopCommonHeaderLayerInfo(a1, 4153539961, 253801632, 3969848060, 1144161661, 3293713115, 253801632, 1152304044, 305955024, 3007971317)
    SwapSoccerTopCommonHeaderMenuModeIconTexture(758233070 --[[mode_base07]])
    UpdateHeader(3586861540)
    funcLuaMenuCommand(C.TEXT, a1, 1220590795 --[[_text_sub_title02]], HeaderText())
  elseif a1 == L_ROW then
    if a2 >= CARDS then
      funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
      funcLuaMenuCommand(C.ATTACH_TRACE, a1, a2, 3313461902 --[[cursor]], false)
      -- no click zone on a hidden row: it would take the engine focus on hover (docs/game/ui/mouse-support.md §2)
      pcall(funcLuaMenuCommand, 855005857 --[[enable / remove an instance's zone]], a1, a2, false)
      return
    end
    SetupRow(a2)
  elseif a1 == L_WINBASE then
    funcLuaMenuCommand(C.MESH_VISIBLE, a1, 3186689458 --[[_save_arrow_01]], false)
    for i = 1, WINDOWS do
      funcLuaMenuCommand(C.ATTACH_TRACE, a1, 0, WIN_LABELS[i], true)
    end
    for i = 0, WINDOWS - 1 do
      funcLuaMenuCommand(C.OPEN_LAYER, L_WIN, i)
    end
  elseif a1 == L_WIN then
    if a2 < WINDOWS then
      FillWindow(a2)
      SetBase(a2)
      if a2 == WINDOWS - 1 then
        windows_ready = true
      end
    else
      funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)   -- no reserved slot: the reserved card's window
    end
  elseif a1 == L_GUIDE_LINE then
    funcLuaMenuCommand(C.TEXT, a1, 378156699 --[[_text_guide01]], TXT.GUIDE, 0)
  end
end

function OnOpenLayer(a1, a2)
  if a1 == L_ROW and a2 == 0 then
    rows_open = true
    funcLuaMenuCommand(C.OPEN_LAYER, L_CURSOR, 0)
    funcLuaMenuCommand(C.FOCUS_ENABLE, a1, true)
    funcLuaMenuCommand(C.LIST_NUM, a1, CARDS)
    funcLuaMenuCommand(C.FOCUS_SET, a1, focus)
    funcLuaMenuCommand(C.ANIME, a1, focus, 2734777837 --[[Focus]], 0, 973515837 --[[button]])   -- not Active: it slides the row
    funcLuaMenuCommand(C.CURSOR_LOC, a1, 3313461902 --[[cursor]], focus, CARDS)
    UpdateButtonGuide()
    if funcLuaCommand(C.FADE_DONE) then
      funcLuaCommand(C.FADE, 0, 0.3)
    end
  elseif a1 == L_GUIDE_LINE then
    funcLuaMenuCommand(C.TEXT, a1, 378156699 --[[_text_guide01]], TXT.GUIDE, 0)
  end
end

function OnChangeFocus(a1, a2)
  if a1 ~= L_ROW then
    return
  end
  local ret = funcLuaMenuCommand(C.FOCUS_IDX, a1)
  if ret == nil or ret < 0 or ret >= CARDS then
    return
  end
  funcLuaMenuCommand(C.FOCUS_MARK, a1, ret, true)
  if ret ~= focus then
    funcLuaMenuCommand(C.ANIME, a1, focus, 2734777837 --[[Focus]], 2, 973515837 --[[button]])
  end
  funcLuaMenuCommand(C.ANIME, a1, ret, 2734777837 --[[Focus]], 0, 973515837 --[[button]])
  funcLuaMenuCommand(C.CURSOR_LOC, a1, 3313461902 --[[cursor]], ret, CARDS)
  focus = ret
  HighlightWindows()
  UpdateButtonGuide()
end

function OnDecideFocus(a1, a2)
  Log("OnDecideFocus", a1, "slot", type(a2) == "number" and tostring(SlotAt(a2)) or tostring(a2), "busy", evt_co ~= nil and "yes" or "no")
  if a1 == L_ROW and evt_co == nil and a2 ~= nil and a2 >= 0 and a2 < CARDS then
    StartCo(Decide, a2)
  end
end

-- CMD_FUNC1 / CMD_FUNC3 on the rows (MENU_CMD_INFO CMD_FUNCTION ids evt_slot_rename / evt_slot_delete); the button
-- guide sends the same commands when clicked. lua.md: OnFunction(id, layer); both orders are accepted.
function OnFunction(a1, a2)
  Log("OnFunction", tostring(a1), tostring(a2), "slot", tostring(SlotAt(focus)), "busy", evt_co ~= nil and "yes" or "no")
  if evt_co ~= nil then
    return 1
  end
  local id = a1
  if a1 ~= FN_RENAME and a1 ~= FN_DELETE and a1 ~= FN_DUP then
    id = a2
  end
  local i = funcLuaMenuCommand(C.FOCUS_IDX, L_ROW)
  if type(i) ~= "number" or i < 0 or i >= CARDS then
    i = focus
  end
  if i == RES_CARD then
    return 1          -- no name / delete on the reserved card
  end
  if id == FN_DUP then
    Log("key X (CMD_FUNC4) slot", tostring(SlotAt(i)))
    StartCo(Duplicate, i)
    return 1
  elseif id == FN_RENAME then
    StartCo(Rename, i)
    return 1
  elseif id == FN_DELETE then
    StartCo(Delete, i)
    return 1
  end
end

function OnEnter(a1, a2)
  Log("OnEnter", tostring(a1), tostring(a2), "slot", tostring(SlotAt(focus)))
  if a1 == 9396745 --[[mainmenu01_07_button_guide]] or a1 == 2005383485 --[[mainmenu01_10_return_arrow_button_guide]] then
    return 1
  end
  if a1 == L_ROW then
    local i = a2
    if i == nil or i < 0 or i >= CARDS then
      i = funcLuaMenuCommand(C.FOCUS_IDX, L_ROW)
    end
    OnDecideFocus(a1, i)
  end
end

function OnBack(a1)
  Log("OnBack", tostring(a1), "busy", evt_co ~= nil and "yes" or "no")
  if evt_co ~= nil then
    return 1
  end
  funcLuaCommand(C.SE, SE_BACK)
  Close(0)
  return 1
end

-- cards drawn while a texture was still loading: draw everything again once the textures are in (at most ~15 s of
-- waiting; after that the fallbacks stay)
local function RedrawWhenLoaded()
  if not windows_ready or next(wait_tex) == nil then
    return
  end
  wait_frames = wait_frames + 1
  for crc in pairs(wait_tex) do
    if funcLuaCommand(C.TEX_LOADING, crc) ~= true then
      wait_tex[crc] = nil
    end
  end
  if next(wait_tex) == nil or wait_frames >= 900 then
    Log("textures in after frames", wait_frames, "pending", next(wait_tex) ~= nil and "yes" or "no")
    wait_tex = {}
    for i = 0, CARDS - 1 do
      SetupRow(i)
    end
    for i = 0, WINDOWS - 1 do
      FillWindow(i)
    end
    HighlightWindows()
  end
end

local step_frames = 0
function Step()
  step_frames = step_frames + 1
  StepLayout()
  RedrawWhenLoaded()
  -- the provider's reset (CMD_FUNC2) on the reserved card
  if evt_co == nil and focus == RES_CARD and res ~= nil and not res.locked and type(res.p.reset) == "table"
      and funcLuaCommand(CHECK_INPUT, MENU_CTRL, K_FUNC2) == true then
    StartCo(ReservedReset)
  end
  -- the pages of player slots (L1 / R1)
  if evt_co == nil and pages > 1 and windows_ready then
    if funcLuaCommand(CHECK_INPUT, MENU_CTRL, K_PAGE_PREV) == true then
      Page(-1)
    elseif funcLuaCommand(CHECK_INPUT, MENU_CTRL, K_PAGE_NEXT) == true then
      Page(1)
    end
  end
  if evt_co ~= nil then
    if coroutine.status(evt_co) == "dead" then
      evt_co = nil
    else
      local ok, err = coroutine.resume(evt_co)
      if not ok then
        PRINT("evt_save_slot_menu: " .. tostring(err))
        Log("error", tostring(err))
        evt_co = nil
        funcLuaMenuCommand(C.MENU_ACTIVE, MENU, true)
      elseif coroutine.status(evt_co) == "dead" then
        evt_co = nil
      end
    end
  end
end
