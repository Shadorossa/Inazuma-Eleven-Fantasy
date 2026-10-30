-- ===================================================================================================
-- EVT skill slots v2: "Tabla de habilidades" as an equipment-style screen: 1 special row ("Hipertécnica")
-- + 6 normal hissatsu rows. Appended by research/scripts/ss2_build.py to the decompiled retail
-- equip_menu_select_5.00.21.00 (the left-column/right-panel script of the accessories screen). The result is
-- shipped as the script of the NEW menu evt_skill_slot_menu (common/script/lua/menu/evt_skill_slot_menu.lua.bin),
-- so the real equipment screen is untouched. The functions below REDEFINE retail globals of the same chunk
-- (later definition wins); chunk locals of the retail part (n = charaStHdl, n3 = dock no, n17 = dock type,
-- n4 = member index, n12 = parent menu, n14 = focused layer, n15 = member count, flag6/flag7, t3) are upvalues.
-- Docs: docs/game/skill-slots.md §7.1. Plain Lua 5.2.
--
-- Rows (instances of soccer11_08_equip_list_item), board writes through Character Reforged's board commands:
--   row 0 "Hiper" = board slot 8 (branch 2's 3rd piece, the game's hyperpower/special slot) + this player's team aura
--         slot; never written to the match list.
--   rows 1-6 = match list positions 0-5 (skill_list, what the match uses) = board slots 0-5 (base 0-2 + branch 1).
--   The match list is the source of truth: a row shows skill_list; the board is mirrored best-effort (EVT_SyncBoard).
-- ===================================================================================================

-- ---- tweakables ------------------------------------------------------------------------------------
-- Normal rows 1-4 unlock when the player reaches the level at which he learns his 1st..4th move (his own
-- learn table, command 0xCF25A8AF). This table is only the FALLBACK when the game returns nothing.
-- Rows 5-6 (0 here) are always unlocked. The special row is always unlocked. Unlocked rows take any move.
local EVT_UNLOCK_LEVEL_FALLBACK = {1, 13, 20, 30, 0, 0}
local EVT_ALWAYS_FREE = {false, false, false, false, true, true}   -- per normal row 1..6
-- Special row ("Hipertécnica": fighting spirit, armed, miximax, soul, hyperpower/awakening "wap", mode change =
-- move category 8). Tries 10-13 mapped it to the active branch's 3rd slot (5 or 8), shared with match position 6.
-- Try 18 (user): always branch 1 for the 6 normal rows (board slots 0-5 = match positions 1-6) and the special on
-- board slot 8 (branch 2's special piece) + the team aura slot.
local EVT_HIPER_SLOT = 8                -- board slot of the Hiper row
local EVT_SPECIAL_TEAM_AURA = true      -- also put the special into this player's team aura slot
local EVT_SPECIAL_LABEL = ""            -- prefix of the special row (try 13: none, the row is purple instead)
-- try 17: the special row's base is our own purple sprite (EVT_HIPER_TEX below); tints (tries 13-15) had no effect
local EVT_GUIDE_TEXT = 2021430145 --[[skill_table_guide]]   -- bottom guide line (text id)
local EVT_BUTTON_TEXT = 2135514294   -- bottom button label = menu_text evt_pl_set_btn «Set de jugador» (PL.TX.SET_BTN)
local EVT_DESC_LINE_BYTES = 34      -- info card: description wrapped to 2 lines of at most this many bytes (UTF-8 safe, "…")

-- ---- ids ---------------------------------------------------------------------------------------------
local EVT_ROW_NUM = 7               -- 1 special + 6 normal
local EVT_NORMAL_NUM = 6
local EVT_MENU = 1041963128           -- this menu
local EVT_PICK_MENU = 2897322950        -- the game's hissatsu list with tabs/filters/sort
-- parameter-store handoff with the picker: NUMBERS/BOOLS ONLY (strings are stored as a raw pointer into the
-- setter's lua_State, handler 0xCA6480, and do not survive to the other menu - the try 1-6 string params)
local EVT_KEY_PICK = 790447113          -- param: pick mode 1 normal / 2 special
local EVT_KEY_RESULT = 3854106930      -- param: chosen move id
local EVT_KEY_INV = 331123112            -- param: its invSkill handle
local EVT_KEY_USED = {621880403, 3155719657, 3407824255, 1434177756, 578609226, 3145052656}
local EVT_KEY_DBG_INIT = 1463482560       -- picker debug: mode it saw at OnInit
local EVT_KEY_DBG_ENTER = 1978530279     -- picker debug: layer of the last confirm callback
local EVT_KEY_DBG_CODE = 3864734764       -- picker debug: 3 rejected, 4 chosen, 9 Lua error
local EVT_KEY_DBG_BITS = 3833368827       -- picker debug: hooks seen (1 focus, 2 detail, 4 step, 8 enter, 16 click, 32 OnEnter, 64 OnDecideFocus, 128 other)
local EVT_KEY_OPEN_BOARD = 1881233917   -- param: team dock must open the original board
local L_ROW = 4251697490      -- soccer11_08_equip_list_item (7 instances = 7 rows)
local L_BTN = 503674375       -- cmn03_07_cmn_button_equip ("Mejor equipamiento" -> original board)
local L_BASE = 3560167285     -- team05_01_equip_base (left column; objbin/layout cloned by the builder)
local L_INFO = 3239909435     -- team05_02_equip_info_easy (right info window)
local L_CURSOR = 2296367164   -- cmn05_01_cursor
-- Row base sprite (try 17). The white card of a row is the mesh _item_list_base01, which draws sprite item_list_base01
-- of soccer11_08.g4tx; command 558735651 (layer, textureCrc, spriteCrc, nodeCrc, 0, idx) swaps it, nodeCrc = crc32 of
-- the sprite name the mesh was built with (retail equip_menu_select does the same for the outfit row).
-- Our texture: data/dx11/menu/00_soccer/soccer11/evt_soccer11_08_hiper/evt_item_list_base_hiper01.g4tx, one 568x80
-- BC7 image named like the file (as the save-slot story pictures), a purple recolour of item_list_base01.
local EVT_HIPER_TEX = "#/menu/00_soccer/soccer11/evt_soccer11_08_hiper/evt_item_list_base_hiper01.g4tx"
local EVT_HIPER_TEX_CRC = 2127494112     -- crc32(EVT_HIPER_TEX)
local EVT_HIPER_SPRITE = 3767077459      -- evt_item_list_base_hiper01
local EVT_ROW_TEX = 1676671618           -- #/menu/00_soccer/soccer11/soccer11_08/<LG>/soccer11_08.g4tx (retail)
local EVT_ROW_BASE = 2417687399          -- item_list_base01 (retail white sprite = node of _item_list_base01)
local C = {
  GET_SKILL = 903078840,      -- 0x35D3E3B8 (charaStHdl, slot0..5) -> skill id (save skill_list)
  SET_SKILL = @crc:CMND_SET_SKILL@,     -- 0x8EB59E18 CMND_SET_SKILL (charaStHdl, skill, slot): swaps if already in the list
  REMOVE_SKILL = @crc:CMND_REMOVE_SKILL@,  -- 0xBBB97857 CMND_REMOVE_SKILL (charaStHdl, slot)
  LEARNABLE = 3475351727,     -- 0xCF25A8AF (charaStHdl) -> ok, {skill per slot}, {unlock level per slot}
  CHARA_GET = 1131797651,     -- 0x4375DC93 (charaStHdl, 0 level | 4 chara id)
  SKILL_INFO = @crc:CMND_GET_SOCCER_SKILL_INFO@,    -- CMND_GET_SOCCER_SKILL_INFO (skill, 4 name id | 5 description id | 6 power | 9 category)
  NAME_TEXT = 720417636,      -- 0x2AF0B364 (name id) -> string
  DESC_TEXT = 4113915188,     -- 0xF5355D34 (description id) -> string (as SetupPersonalPlateSkillDetailInfo)
  TEXT = @crc:CMND_SET_MENU_TEXT_STRING@,          -- CMND_SET_MENU_TEXT_STRING (layer, node, string, idx)
  TEXT_ALPHA = @crc:CMND_SET_MENU_TEXT_ALPHA@,    -- CMND_SET_MENU_TEXT_ALPHA (layer, idx, node, alpha)
  MESH_VISIBLE = @crc:CMND_SET_MESH_VISIBLE@,  -- CMND_SET_MESH_VISIBLE (layer, mesh, bool, idx)
  ITEM_ICON = 3508889864,     -- (layer, idx, mesh, texture, itemId): item icon (moves are items, same id)
  FOCUS_IDX = 2603265800,     -- (layer) -> focused instance
  CURSOR_LOC = @crc:CMND_SET_CURSOR_LOCATOR@,     -- CMND_SET_CURSOR_LOCATOR (layer, crc32("cursor"), idx, instanceCount): enables the cursor attach of instance idx, disables the others < count
  SE = @crc:CMND_SND_PLAY_SE@,
  MENU_ACTIVE = 1558704558,   -- (menu, bool) input on/off
  MENU_SUSPEND = 1129326309,  -- (menu) hide while a child menu is open (team dock does this around sub menus)
  MENU_RESUME = 1453710531,   -- (menu)
  LAYER_VISIBLE = @crc:CMND_SET_LAYER_VISIBLE@,
  OPEN_MENU = @crc:CMND_OPEN_MENU_OBJECT@,      -- CMND_OPEN_MENU_OBJECT (menu, group)
  EXIST_MENU = @crc:CMND_IS_EXIST_MENU_OBJECT@,    -- CMND_IS_EXIST_MENU_OBJECT (menu cmd)
  CLOSING_MENU = @crc:CMND_IS_CLOSING_MENU_OBJECT@,  -- CMND_IS_CLOSING_MENU_OBJECT 0x472111B3
  CLOSED_MENU = @crc:CMND_IS_CLOSE_MENU_OBJECT@,   -- CMND_IS_CLOSE_MENU_OBJECT 0x5AB5813A
  CLOSE_MENU = @crc:CMND_CLOSE_MENU_OBJECT@,     -- CMND_CLOSE_MENU_OBJECT
  MSG_OPEN = 2289627655, MSG_BUSY = 898725220, MSG_DONE = 682363669,                  -- general (system) window
  -- ability board (try 3: rows ARE board skill slots)
  BOARD_INV = 632801955,      -- 0x25B7CAA3 (charaStHdl, boardSlot, kind): kind 2 -> overwrite present?; 0/1 -> invSkill handle
  INV_ITEM = 2662166687,      -- 0x9EAD709F (invHdl, 0) -> item (= move) id
  BOARD_PIECES = 1535890305,  -- 0x5B8BD381 (charaId) -> {piece effect index per board skill slot}, {category per slot}
  BOARD_EQUIP = 203046535,    -- 0x0C1A3E87 (charaId, invHdl, pieceEffectIdx): put a move item on that board piece
                              --   (handler 0xC75CD0 -> 0xE7D310 equip + 0xD80B40 piece; prog_common.AddSkillItemAndLearnWithBoard)
  SKILL_POS = 26437624,       -- 0x019367F8 (charaStHdl, skill) -> position in skill_list (>= 6: absent)
  -- team aura slots (retail equip_aura_skill_menu): save teamInfoList.auraSkillSlotInfoList {charaStHdl, skillId} x4
  TEAM_INFO = @crc:CMND_GET_TEAM_SET_INFO@,     -- CMND_GET_TEAM_SET_INFO (dockNo, dockType, 15, slot) -> ok, charaStHdl, skillId
  TEAM_AURA_SET = @crc:CMND_SET_TEAM_SET_INFO@, -- 0x59CAEAD5 (dockNo, dockType, 6, slot, charaStHdl, skillId)
  -- the skill board's writes: Character Reforged's board commands (scripts\board_slots.lua, board slots 0-8)
  EVT_PLACE = @crc:CMND_CHARACTERREFORGED_BOARD_PLACE@,   -- CMND_CHARACTERREFORGED_BOARD_PLACE (charaStHdl, invHdl, boardSlot) -> status, effectiveInv
                            -- (1 = done and verified; opens a closed piece)
  EVT_CLEAR = @crc:CMND_CHARACTERREFORGED_BOARD_CLEAR@,   -- CMND_CHARACTERREFORGED_BOARD_CLEAR (charaStHdl, boardSlot, keepOpen) -> status, effectiveInv
                            -- (native item back; -6 = would close the piece)
  EVT_LOG = @crc:CMND_EVT_LOG@,             -- (...) -> writes to evt_loader\loader.log
  EVT_PIECE = @crc:CMND_CHARACTERREFORGED_BOARD_PIECE@,   -- CMND_CHARACTERREFORGED_BOARD_PIECE (charaStHdl, boardSlot) -> piece (0..254, 255 closed,
                            -- <0 error), effInv, placedInv, baseInv
  -- invSkill handle for a move that is not on this player's board (try 9): the list only gives item ids
  ADD_ITEM = @crc:CMND_ADD_ITEM_ONLY@,      -- 0x711FE46A CMND_ADD_ITEM_ONLY (itemId, count, flag) -> invSkill handle (prog_common.AddSkillItemAndLearnWithBoard)
  DEL_ITEM = @crc:CMND_DELETE_ITEM@,       -- 0x195E1FD9 CMND_DELETE_ITEM (itemId, count): undo the +1 so the stock does not change
  -- menu textures (save-slot menu / kizuna_town_menu_inc): the load is asynchronous
  SPRITE = 558735651,         -- (layer, textureCrc, spriteCrc, nodeCrc, 0, idx)
  LOAD_TEX = @crc:CMND_LOAD_MENU_RES_TEXTURE@,       -- CMND_LOAD_MENU_RES_TEXTURE (path)
  TEX_LOADING = 1506186496,   -- (textureCrc) -> true while still loading
}
local SE_OK, SE_DECIDE, SE_BACK, SE_NG, SE_REMOVE = 3848881948, 4235359837, 202039849, 2086672038, 2339718859
local EVT_TEAM_AURA_SLOTS = 4

-- ---- 2026-09-24: level-locked rows drawn "off", Prime cards with a fixed moveset --------------------------------------
-- Locked row = our evt_item_list_base_lock01 (research/scripts/ss_lock_row_tex.py: item_list_base01 in the retail
-- "disabled list row" navy, loaded like the Hiper base) + the retail lock icon (soccer11_20 icon_lock_passive01, a menu
-- resource of this screen) on the row's left icon node _icon_equip01 + "Nv. N" in the retail grey-out text colour.
-- Prime (chara_param col 41 = 10): all rows are fixed = his learnset 1-6 by level (vr-loader CMND_EVT_PRIME_MOVES,
-- board.prime_fixed_moves); every row carries the lock icon, nothing can be picked or removed.
-- (fields of ONE table: the main chunk of this script is at Lua 5.2's limit of 200 local variables)
local PL = {
  LOCK_TEX = "#/menu/00_soccer/soccer11/evt_soccer11_08_lock/evt_item_list_base_lock01.g4tx",
  LOCK_TEX_CRC = 435411157,       -- crc32(LOCK_TEX)
  LOCK_SPRITE = 3122807489,       -- evt_item_list_base_lock01
  TEX_S11_20 = 4021797290,        -- #/menu/00_soccer/soccer11/soccer11_20/soccer11_20.g4tx
  ICON_LOCK = 1502905245,         -- icon_lock_passive01 (36 x 40 grey lock)
  ICON_EQUIP_NODE = 2346103015,   -- icon_equip01 (texture slot of the mesh _icon_equip01)
  LOCK_COLOR = "[CGRAYOUT04]",    -- font_color GRAYOUT04 (light grey, readable on the navy base)
  PRIME_RARITY = 10,
  PRIME_CMD = @crc:CMND_EVT_PRIME_MOVES@,   -- (charaStHdl, apply) -> isPrime, level, s1, l1 ... s6, l6
  PRIME_GUIDE = 45696706 --[[skill_table_prime_guide]],
  -- 2026-09-27: learnset of the shown player (chara_param slots 1-9, slot 9 = Hiper) from the vr-loader
  -- CMND_VRFW_CHARACTER_LEARNSET (VR-Framework learn-level service, 2.0.5; was CMND_EVT_LEARNSET, now its alias); fallback = the retail learn table 0xCF25A8AF (slots 1-6). A locked row shows
  -- the move it will learn (lock + name + icon); a custom Idol (EVT_IDOL_FRAME of soccer_common, moment_idol_build.py)
  -- keeps its learnset rows fixed (learned or still locked), only its empty learnset slots take a pick.
  LEARNSET_CMD = @crc:CMND_VRFW_CHARACTER_LEARNSET@,      -- crc32("CMND_VRFW_CHARACTER_LEARNSET") (charaStHdl) -> ok, {9 skills}, {9 levels}
  learnset = {hdl = -1},
  idol = {hdl = -1},
  IDOL_GUIDE = 2800973629 --[[skill_table_idol_guide]],
  lock_tex = 0,                   -- 0 not requested, 1 loading, 2 ready
  lock_pending = {},              -- rows waiting for the texture
  prime = {hdl = -1},
  -- move panel polish + clean lock (2026-09-24): research/scripts/ss_parts_tex.py, a MENU_RES of this screen
  PARTS_TEX = 1241611320,   -- crc32("#/menu/102_team/team02/evt_ss_parts/evt_ss_parts.g4tx")
  BAND = {968409197, 2695991767, 3619070273, 1238512866, 1054147700, 2816234958},
  WLV = {[2861188530] = 1188988279, [864228360] = 3755463885, [1149510814] = 2832262235},
  LOCK_LIGHT = 3148165984,   -- on the navy "off" rows and the purple Hiper row
  LOCK_DARK = 4222515565,     -- on white rows (Prime)
  -- ability_list_menu filter / tab parameter keys (bluebg OnInit t3 + 773844157 start tab)
  LIST_KEYS = {1498333934, 3225916244, 3074466754, 690239073, 1579353847, 3341440845, 2552568759, 19679757, 773844157},
}

local evt_co = nil
local evt_back_frames = -1
evt_back_seen = false                     -- (global: no new main-chunk local; the back-key diagnostic of Step)
local evt_hiper_tex = 0          -- purple base texture: 0 not requested, 1 loading, 2 ready
local evt_hiper_pending = false  -- row 0 still waits for it (applied from Step)
local evt_shown = nil               -- try 20: player whose layout/mirror ran last (charaStHdl)
local evt_layout_done = {}       -- try 19: players whose layout the loader checked during this visit

-- Request the purple base texture once; true when it can be used.
local function EVT_HiperTexReady()
  if evt_hiper_tex == 0 then
    funcLuaMenuCommand(C.LOAD_TEX, EVT_HIPER_TEX)
    evt_hiper_tex = 1
  end
  if evt_hiper_tex == 1 and not funcLuaCommand(C.TEX_LOADING, EVT_HIPER_TEX_CRC) then
    evt_hiper_tex = 2
  end
  return evt_hiper_tex == 2
end

function PL.LockTexReady()
  if PL.lock_tex == 0 then
    funcLuaMenuCommand(C.LOAD_TEX, PL.LOCK_TEX)
    PL.lock_tex = 1
  end
  if PL.lock_tex == 1 and not funcLuaCommand(C.TEX_LOADING, PL.LOCK_TEX_CRC) then
    PL.lock_tex = 2
  end
  return PL.lock_tex == 2
end

-- Row base: purple sprite on the special row (0), the retail white one on the others, the navy "off" one on a
-- level-locked row (2026-09-24).
local function EVT_SetRowBase(a1, locked)
  if locked then
    if PL.LockTexReady() then
      funcLuaMenuCommand(C.SPRITE, L_ROW, PL.LOCK_TEX_CRC, PL.LOCK_SPRITE, EVT_ROW_BASE, 0, a1)
      PL.lock_pending[a1] = nil
    else
      PL.lock_pending[a1] = true
    end
    return
  end
  PL.lock_pending[a1] = nil
  if a1 == 0 then
    if EVT_HiperTexReady() then
      funcLuaMenuCommand(C.SPRITE, L_ROW, EVT_HIPER_TEX_CRC, EVT_HIPER_SPRITE, EVT_ROW_BASE, 0, 0)
      evt_hiper_pending = false
    else
      evt_hiper_pending = true
    end
  else
    funcLuaMenuCommand(C.SPRITE, L_ROW, EVT_ROW_TEX, EVT_ROW_BASE, EVT_ROW_BASE, 0, a1)
  end
end

local EVT_RetailOnInit = OnInit
function OnInit()
  EVT_RetailOnInit()
  EVT_HiperTexReady()   -- start loading early; the rows are set up later
  PL.LockTexReady()
end

local function P_Set(key, v)
  VRFW_Param.Clear(key)
  VRFW_Param.Set(key, v)
end

-- ids are unsigned 32-bit; they cross menus as hex text (Lua 5.2 "%d" overflows above 2^31 on Windows)
local function EVT_U32(id)
  return VRFW_Id.u32(id)
end

local function EVT_IsSpecial(skill)
  if skill == nil or skill == 0 then
    return false
  end
  local ok, cat = funcLuaCommand(C.SKILL_INFO, skill, 9)
  return ok and cat == 8
end

-- ---- vr-loader + row mapping ---------------------------------------------------------------------------------
local function EVT_Call(cmd, ...)
  local ok, a, b, c, d = pcall(funcLuaCommand, cmd, ...)
  if not ok then
    return nil
  end
  return a, b, c, d
end

-- 2026-10-14: capability checks of the services an action really uses. A command nobody declares answers a single
-- false; a declared one answers its status or more than one value, so a call with handle 0 changes nothing.
--   custom passive (CMND_CHARACTERREFORGED_SIX_SENSE): the slot; player sets (CMND_CHARACTERREFORGED_PLAYER_SET_GET, Character
--   Reforged's scripts\player_sets.lua): the set store
-- One «loader check» log line per missing service and screen visit; each probe answers once per visit.
-- The skill board is Character Reforged's (2026-10-19, owner): every board write of this screen goes through its board
-- commands (C.EVT_PLACE / EVT_CLEAR / EVT_PIECE). The game rebuilds a player's technique list from his board when a match
-- loads (Technique.BuildSkillListFromBoard) and saves it, so every edit of the list is mirrored on the board
-- (EVT_SyncBoard): a move written to the list alone was dropped wherever the board slot of its list position held
-- something else (an aura, a move already listed).
PL.SERVICE_PROBE = {six_sense = {@crc:CMND_CHARACTERREFORGED_SIX_SENSE@, 0, 0, 0, -1},
  player_sets = {@crc:CMND_CHARACTERREFORGED_PLAYER_SET_GET@, 0, 0}}
PL.service_logged = {}
PL.service_present = {}
function PL.HasService(name)
  if PL.service_present[name] ~= nil then
    return PL.service_present[name]
  end
  local probe = PL.SERVICE_PROBE[name]
  local answer, second = nil, nil
  if probe ~= nil then
    local okp
    okp, answer, second = pcall(funcLuaCommand, table.unpack(probe))
    if not okp then
      answer, second = nil, nil
    end
  end
  local present = type(answer) == "number" or second ~= nil   -- PLAYER_SET_GET(0, 0) answers false, ""
  if not present and not PL.service_logged[name] then
    PL.service_logged[name] = true
    EVT_Call(C.EVT_LOG, "skill_slots", "loader check", name, "service missing")
  end
  PL.service_present[name] = present
  return present
end

-- 2026-10-14 (Character Reforged: the new set is a PROJECTION over the game's own list, docs/refactor/
-- aura-mods-split.md «The 6 + 2 set over the retail data»): rows 1-6 are the list positions that hold a special move
-- (or nothing), in list order; a position holding an aura (keshin, totem, Mix-Max, «Modo cambio»: the aura / mix
-- slots' moves) is skipped and KEPT, hidden; the rows left over take those positions last and show empty (writing one
-- first moves its aura to its slot when that is free: PL.FreeListPos). Nothing is rewritten to show the set (the old
-- PL.AuraSlotCleanup moved auras off rows 1-6 when a player was shown; it is no longer called). PL fields only.
PL.special_of = {}
function PL.ProjPos(row)
  if n == nil or n == 0 then
    return row - 1
  end
  local free, boarded, empty, aura = {}, {}, {}, {}
  for p = 0, EVT_NORMAL_NUM - 1 do
    local id = funcLuaCommand(C.GET_SKILL, n, p)
    id = (id ~= nil) and EVT_U32(id) or 0
    if id == 0 then
      id = PL.BoardTechniqueAt(p)                -- an empty position shows its board cell's technique
      if id ~= 0 then
        boarded[#boarded + 1] = p
      else
        empty[#empty + 1] = p
      end
    elseif PL.IsSpecialCached(id) then
      aura[#aura + 1] = p
    else
      free[#free + 1] = p
    end
  end
  -- 2026-10-15 (owner): the list's techniques, then the positions filled from their board cell (the order of
  -- CharacterReforged.EffectiveSkillSet), then the empty ones, the hidden aura positions last
  for _, p in ipairs(boarded) do
    free[#free + 1] = p
  end
  for _, p in ipairs(empty) do
    free[#free + 1] = p
  end
  for _, p in ipairs(aura) do
    free[#free + 1] = p
  end
  return free[row] or (row - 1)
end
function PL.IsSpecialCached(id)
  local sp = PL.special_of[id]
  if sp == nil then
    sp = EVT_IsSpecial(id) == true
    PL.special_of[id] = sp
  end
  return sp
end
-- the move on board cell `p` (placed item, else native), 0 for none
function PL.BoardMoveAt(p)
  local inv = funcLuaCommand(C.BOARD_INV, n, p, 1)
  if inv == nil or inv == 0 then
    inv = funcLuaCommand(C.BOARD_INV, n, p, 0)
  end
  if inv == nil or inv == 0 then
    return 0
  end
  return EVT_U32(funcLuaCommand(C.INV_ITEM, inv, 0))
end
-- the technique board cell `p` adds to the rows, 0 for none: never an aura, never a move already in the match list or
-- shown by an earlier empty position (the dedupe of CharacterReforged.EffectiveSkillSet)
function PL.BoardTechniqueAt(p)
  local id = PL.BoardMoveAt(p)
  if id == 0 or PL.IsSpecialCached(id) then
    return 0
  end
  local at = funcLuaCommand(C.SKILL_POS, n, id)
  if at ~= nil and at >= 0 and at < EVT_NORMAL_NUM then
    return 0
  end
  for q = 0, p - 1 do
    local listed = funcLuaCommand(C.GET_SKILL, n, q)
    if (listed == nil or listed == 0) and PL.BoardMoveAt(q) == id then
      return 0
    end
  end
  return id
end

-- row -> board skill slot: Hiper = 8, rows 1-6 = the board slot of their list position (the board mirrors the list)
local function EVT_BoardSlot(row)
  if row == 0 then
    return EVT_HIPER_SLOT
  end
  return PL.ProjPos(row)
end

-- row -> position in the match list skill_list (nil = none: the Hiper row is never in the list)
local function EVT_ListPos(row)
  if row == 0 then
    return nil
  end
  return PL.ProjPos(row)
end

-- Move currently effective on a board skill slot and its invSkill handle.
-- Handler 0xC767E0 of 0x25B7CAA3: kind 1 = +0x94 (skillEquipInvInfo: the item placed by the player),
-- kind 0 = +0xC8 (skillEquipInvInfoOverWrite: the slot's base/native item) if set, else +0x94; kind 2 = bool(+0xC8).
-- Save census (try 5): the match list holds +0x94 when it is set, else +0xC8 -> read kind 1 first, then kind 0.
-- (Tries 3-4 read kind 1 only when +0xC8 was set, which returned 0 = "---" for slots whose +0x94 is empty.)
local function EVT_BoardSkill(bslot)
  if n == nil or n == 0 or bslot == nil then
    return 0, 0
  end
  local inv = funcLuaCommand(C.BOARD_INV, n, bslot, 1)
  if inv == nil or inv == 0 then
    inv = funcLuaCommand(C.BOARD_INV, n, bslot, 0)
  end
  if inv == nil or inv == 0 then
    return 0, 0
  end
  return EVT_U32(funcLuaCommand(C.INV_ITEM, inv, 0)), inv
end

local EVT_TeamAuraOf   -- defined below (team aura slot of this player)

local function EVT_ListSkill(pos)
  local id = funcLuaCommand(C.GET_SKILL, n, pos)
  return (id ~= nil) and EVT_U32(id) or 0
end

-- Prime card of the shown player (cached per player). The loader answers with his learnset and writes the fixed
-- match list (apply = 1); without it the rarity alone marks him (rows then show the match list, nothing editable).
function EVT_PrimeInfo()
  if PL.prime.hdl == n then
    return PL.prime
  end
  PL.prime = {hdl = n, on = false}
  if n == nil or n == 0 then
    return PL.prime
  end
  local r = {pcall(funcLuaCommand, PL.PRIME_CMD, n, PL.readonly and 0 or 1)}   -- read-only: no write
  if r[1] and r[2] == true then
    PL.prime.on, PL.prime.level, PL.prime.skill, PL.prime.lv = true, r[3], {}, {}
    for k = 1, EVT_NORMAL_NUM do
      PL.prime.skill[k] = EVT_U32(r[2 + 2 * k] or 0)
      PL.prime.lv[k] = tonumber(r[3 + 2 * k]) or 0
    end
  elseif funcLuaCommand(C.CHARA_GET, n, 12) == PL.PRIME_RARITY then
    PL.prime.on = true
  end
  if PL.prime.on then
    EVT_Call(C.EVT_LOG, "skill_slots", "prime", n, "loader", PL.prime.skill ~= nil, "level", PL.prime.level)
  end
  return PL.prime
end

function EVT_IsPrime()
  return EVT_PrimeInfo().on
end

-- Hiper row: the special on board slot 8, else the one in this player's team aura slot.
-- Rows 1-6: the match list (what the match uses); an empty list position shows the board slot's move.
-- Prime rows 1-6: his fixed learnset move (also while it is still level-locked).
local function EVT_Skill(row)
  if row == 0 then
    local skill = EVT_BoardSkill(EVT_HIPER_SLOT)
    if EVT_IsSpecial(skill) then
      return skill
    end
    local aura = EVT_TeamAuraOf ~= nil and EVT_TeamAuraOf() or 0
    return EVT_IsSpecial(aura) and aura or 0
  end
  local p = EVT_PrimeInfo()
  if p.on and p.skill ~= nil then
    return p.skill[row] or 0
  end
  local skill = EVT_ListSkill(EVT_ListPos(row))
  if skill ~= 0 then
    if EVT_IsSpecial(skill) then
      return 0                                     -- an aura kept hidden on this position (the projection)
    end
    return skill
  end
  -- the board cell's technique: never an aura (retail board), never a duplicate of a listed move
  return PL.BoardTechniqueAt(EVT_BoardSlot(row))
end

-- 2026-09-27: the shown player's learnset (see PL above). skill[k] / lv[k], k = chara_param slot 1-9.
function PL.Learnset()
  if PL.learnset.hdl == n then
    return PL.learnset
  end
  local ls = {hdl = n, skill = {}, lv = {}, loader = false}
  PL.learnset = ls
  if n == nil or n == 0 then
    return ls
  end
  local ok, ids, lvs = EVT_Call(PL.LEARNSET_CMD, n)
  if ok == true and type(ids) == "table" and type(lvs) == "table" then
    ls.loader = true
    for k = 1, 9 do
      ls.skill[k] = EVT_U32(ids[k] or 0)
      ls.lv[k] = tonumber(lvs[k]) or 0
    end
    return ls
  end
  local okr, rids, rlvs = funcLuaCommand(C.LEARNABLE, n)      -- retail / learn_levels plate table: slots 1-6
  if okr and type(rids) == "table" then
    for k = 1, EVT_NORMAL_NUM do
      ls.skill[k] = EVT_U32(rids[k] or 0)
      ls.lv[k] = (type(rlvs) == "table" and tonumber(rlvs[k])) or 0
    end
  end
  return ls
end

-- custom Idol card (moment_idol_build.py): its chara_param id is a key of EVT_IDOL_FRAME (soccer_common data child)
function PL.IsIdol()
  if PL.idol.hdl == n then
    return PL.idol.on
  end
  local on = false
  if n ~= nil and n ~= 0 and type(EVT_IDOL_FRAME) == "table" then
    local param = funcLuaCommand(C.CHARA_GET, n, 4)
    if type(param) == "number" then
      on = EVT_IDOL_FRAME[EVT_U32(param)] ~= nil or EVT_IDOL_FRAME[param] ~= nil
    end
  end
  PL.idol = {hdl = n, on = on}
  return on
end

-- learnset slot of a row: rows 1-6 = slots 1-6, the Hiper row = slot 9
function PL.RowSlot(row)
  if row == 0 then
    return 9
  end
  return EVT_ListPos(row) + 1
end

-- The move a row shows: what it holds (EVT_Skill), else, while level-locked, the move the slot will learn; the
-- Hiper row of an Idol shows its learnset Hiper (slot 9) before the piece is opened / placed.
function PL.RowMove(row)
  local s = EVT_Skill(row)
  if s ~= 0 then
    return s
  end
  local ls = PL.Learnset()
  local m = ls.skill[PL.RowSlot(row)] or 0
  if row == 0 then
    return (PL.IsIdol() and EVT_IsSpecial(m)) and m or 0
  end
  local locked = EVT_IsLocked(row)
  return locked and m or 0
end

-- Idol rule (2026-09-27, user): a row whose learnset slot holds a move (learned or still locked) cannot be edited;
-- the empty learnset slots stay free. Prime cards keep their own (all fixed) rule.
function PL.IdolFixed(row)
  if row == nil or row < 0 or row >= EVT_ROW_NUM or not PL.IsIdol() then
    return false
  end
  local ls = PL.Learnset()
  local m = ls.skill[PL.RowSlot(row)] or 0
  if row == 0 then
    return EVT_IsSpecial(m)
  end
  return m ~= 0
end

-- true when the move is in the match list (save skill_list)
local function EVT_Active(skill)
  if skill == 0 then
    return false
  end
  local pos = funcLuaCommand(C.SKILL_POS, n, skill)
  return pos ~= nil and pos >= 0 and pos < 6
end

local function EVT_Name(skill)
  if skill == nil or skill == 0 then
    return "---"
  end
  local ok, nameId = funcLuaCommand(C.SKILL_INFO, skill, 4)
  if ok and nameId then
    local s = funcLuaCommand(C.NAME_TEXT, nameId)
    if s ~= nil and s ~= "" then
      return s
    end
  end
  return string.format("%08X", skill)
end

-- Level at which a row unlocks; 0 = always free.
function EVT_UnlockLevel(row)
  if row == 0 then
    -- 2026-09-27: an Idol's Hiper (learnset slot 9) unlocks at its chara_param level (Victor: Tótem lobo at 70)
    if PL.IsIdol() then
      local ls = PL.Learnset()
      local m = ls.skill[9] or 0
      if m ~= 0 and EVT_IsSpecial(m) and (ls.lv[9] or 0) > 1 then
        return ls.lv[9]
      end
    end
    return 0
  end
  local slot = EVT_ListPos(row)
  local p = EVT_PrimeInfo()
  if p.on and p.lv ~= nil then
    return (p.lv[row] or 0) > 1 and p.lv[row] or 0   -- Prime: every row by its learn level (rows 5-6 too)
  end
  if EVT_ALWAYS_FREE[slot + 1] then
    return 0
  end
  if n ~= nil and n ~= 0 then
    local ok, ids, lvs = funcLuaCommand(C.LEARNABLE, n)
    if ok and type(lvs) == "table" and type(lvs[slot + 1]) == "number" and lvs[slot + 1] > 0 then
      return lvs[slot + 1]
    end
  end
  return EVT_UNLOCK_LEVEL_FALLBACK[slot + 1] or 0
end

function EVT_IsLocked(row)
  local need = EVT_UnlockLevel(row)
  if need <= 1 then
    return false, need
  end
  local lv = funcLuaCommand(C.CHARA_GET, n, 0) or 0
  return lv < need, need
end

-- ---- retail overrides: 7 rows (row 0 uses the retail "outfit" row skin to stand apart) ----------------------
function CreateEquipTypeTable()
  t = {0, 0, 0, 0, 0, 0, 0}
end
function GetEquipTypeNum()
  return EVT_ROW_NUM
end
function GetEquipType(a1)
  if a1 == nil or a1 < 0 or a1 >= EVT_ROW_NUM then
    return -1
  end
  return 0   -- try 11: the Hiper row uses the same white row as the others (only the "Hiper" prefix marks it)
end
function GetEquipListItemInfo(a1)
  return t3[a1] or t3[0]
end
function GetEquipItemIdByLayerIdx(a1)
  return EVT_Skill(a1)
end
function UpdateEquippedVisibleCheck(a1)
end

-- One row: "N   <move>" (normal) / "Hiper   <move>" (special) + the move's item icon; locked rows dimmed.
function UpdateEquipListItem(a1)
  if a1 == nil or a1 < 0 or a1 >= EVT_ROW_NUM then
    return
  end
  if a1 == 0 then
    funcLuaMenuCommand(C.LAYER_VISIBLE, L_CURSOR, 0, true)
    -- once per shown player (row 0 is drawn first on open / L-R change): his cached data read again; nothing is written
    -- while a player is only shown (the board is mirrored after his own edits)
    if evt_shown ~= n and n ~= nil and n ~= 0 then
      evt_shown = n
      PL.prime = {hdl = -1}             -- re-read the Prime data
      PL.learnset, PL.idol = {hdl = -1}, {hdl = -1}
    end
  end
  local info = GetEquipListItemInfo(GetEquipType(a1))
  local icon_tex = 1875672568 --[[icon_item_dmy01: retail uses it for every row skin, incl. the outfit one]]
  funcLuaMenuCommand(C.MESH_VISIBLE, L_ROW, 3515732558 --[[_icon_equip01]], false, a1)
  funcLuaMenuCommand(C.MESH_VISIBLE, L_ROW, 3830297508 --[[_gtxt_item01]], false, a1)
  local locked, need = EVT_IsLocked(a1)
  local skill = PL.RowMove(a1)          -- 2026-09-27: a locked row shows the move it will learn (name + icon)
  local prime = EVT_IsPrime()
  local text
  if locked then
    -- 2026-09-24: "off" row: navy base, lock icon, "Nv. N" + the move (Prime / learnset) in grey
    text = PL.LOCK_COLOR .. string.format("Nv. %d", need)
    if skill ~= 0 then
      text = text .. "   " .. EVT_Name(skill)
    end
    text = text .. "[C]"
  elseif skill ~= 0 then
    text = EVT_Name(skill)
    if a1 > 0 and not prime and not EVT_Active(skill) then
      -- on the board slot but not in the match list: the name greyed, as the retail lists grey what cannot be used
      -- (2026-10-14, owner: never a word appended to the name)
      text = PL.LOCK_COLOR .. text .. "[C]"
    end
  else
    text = ""                                      -- an empty row: the plate alone (owner 2026-10-14: no «---»)
  end
  if a1 == 0 and EVT_SPECIAL_LABEL ~= "" then
    text = EVT_SPECIAL_LABEL .. "   " .. text
  end
  funcLuaMenuCommand(C.TEXT, L_ROW, info.itemTextName, text, a1)
  funcLuaMenuCommand(C.TEXT_ALPHA, L_ROW, a1, info.itemTextName, 1)
  -- special row: purple base sprite (try 17). Tries 13-15 tinted with 801406373 (mesh names) and 635730757
  -- (item_list_base01_mat_01): no visible effect, so the sprite itself is swapped instead.
  EVT_SetRowBase(a1, locked)
  -- lock icon on the row's left icon node (retail equip-type icon, unused here): level-locked rows, Prime rows and
  -- the fixed learnset rows of an Idol (2026-09-27)
  local lock_icon = locked or prime or PL.IdolFixed(a1)
  if lock_icon then
    -- polish: our clean 48 x 52 lock (the retail icon_lock_passive01 has a white halo and was stretched: "doubled")
    local spr = (locked or a1 == 0) and PL.LOCK_LIGHT or PL.LOCK_DARK
    funcLuaMenuCommand(C.SPRITE, L_ROW, PL.PARTS_TEX, spr, PL.ICON_EQUIP_NODE, 0, a1)
  end
  -- 2026-10-13 (owner): rows 1-6 are MOVE PLATES (PL.RowPlate: layer evt_ss_row_plate on the row, the retail
  -- soccer11_09 plate filled by SetupCharaSkillItem); the row's white base, text, lock icon and right-hand item icon
  -- give way to it. The row keeps its cyan focus frame and touch quad. The old look comes back if the plate fails.
  -- The plate goes FIRST: the row's right-hand move icon (the category ball) is not filled under a plate at all (its
  -- item-icon fill shows the mesh again once the icon has loaded, after any hide: owner, the old icon behind the plate).
  local on = false
  if a1 > 0 and PL.RowPlate ~= nil then
    local inactive = skill ~= 0 and not locked and not prime and not EVT_Active(skill)
    local okp, r = pcall(PL.RowPlate, a1, skill, locked, need, lock_icon and not locked, inactive)
    if not okp then
      pcall(EVT_Call, C.EVT_LOG, "skill_slots", "row plate error", a1, tostring(r))
    end
    on = okp and r == true
    funcLuaMenuCommand(C.MESH_VISIBLE, L_ROW, PL.RP.ROW_BASE, not on, a1)
    funcLuaMenuCommand(2735666188 --[[text visible]], L_ROW, info.itemTextName, not on, a1)
  end
  funcLuaMenuCommand(C.MESH_VISIBLE, L_ROW, 3515732558 --[[_icon_equip01]], lock_icon and not on, a1)
  if skill ~= 0 and not on and not (a1 == 0 and not locked) then
    funcLuaMenuCommand(C.ITEM_ICON, L_ROW, a1, info.itemIconMeshName, icon_tex, skill)
    funcLuaMenuCommand(C.MESH_VISIBLE, L_ROW, info.itemIconMeshName, true, a1)
  else
    funcLuaMenuCommand(C.MESH_VISIBLE, L_ROW, info.itemIconMeshName, false, a1)
  end
end

local function EVT_RefreshRows()
  for i = 0, EVT_ROW_NUM - 1 do
    UpdateEquipListItem(i)
  end
end

-- Cut a UTF-8 string to at most n bytes without splitting a character.
local function EVT_Cut(s, n)
  if #s <= n then
    return s
  end
  local k = n
  while k > 0 do
    local b = string.byte(s, k + 1)
    if b == nil or b < 128 or b >= 192 then
      break
    end
    k = k - 1
  end
  return string.sub(s, 1, k) .. "…"
end

-- The card's parameter box holds 3 short lines in retail ("Potencia +35 / Control +35", built with the text
-- template 2418446954): line 1 = "<area>   Potencia N", lines 2-3 = the description wrapped.
function EVT_SkillInfoText(skill)
  local okp, power = funcLuaCommand(C.SKILL_INFO, skill, 6)
  if okp and type(power) == "number" and power > 0 then
    return PL.Txt(3124093148 --[[skill_table_move_power]], power)
  end
  return ""
end

-- Right info window (the accessory "info easy" window): move icon, name, area/power + short description.
local function EVT_SetupSkillInfo(skill)
  funcLuaMenuCommand(C.ITEM_ICON, L_INFO, 0, 303536660 --[[_icon_item_dmy01]], 1875672568 --[[icon_item_dmy01]], skill)
  funcLuaMenuCommand(C.ITEM_ICON, L_INFO, 0, 2334051246 --[[_icon_item_dmy02]], 4140117058 --[[icon_item_dmy02]], skill)
  funcLuaMenuCommand(C.TEXT, L_INFO, 456522680 --[[_text_item01]], EVT_Name(skill), 0)
  funcLuaMenuCommand(C.TEXT, L_INFO, 3138144965 --[[_text_parameter01]], EVT_SkillInfoText(skill), 0)
  SetVisibleEquipmentNum(L_INFO, 0, false)
  SetVisibleStockNum(L_INFO, 0, false)
  funcLuaMenuCommand(1233047821, L_INFO, 0, 3974820126, false)
  funcLuaMenuCommand(1233047821, L_INFO, 0, 3334923667 --[[num_have01]], false)
  -- special moves: the keshin / miximax / soul "character" (SKILL_INFO 17 = tempAuraCharaId, what the aura detail
  -- window shows with SwapLayerFaceIconTex), drawn like retail item cards that belong to a character
  -- (SetupEquipInfoWindow: 0x20EB2104 on _item_chr_dmy01). Other moves: the item icon only.
  local aura_chara = 0
  if EVT_IsSpecial(skill) then
    local ok, cid = funcLuaCommand(C.SKILL_INFO, skill, 17)
    if ok and cid ~= nil then
      aura_chara = cid
    end
  end
  if aura_chara ~= 0 then
    -- keshin / armour / totem characters have no list face icon: their aura art (PL.AuraPortrait)
    pcall(funcLuaMenuCommand, 4176779611 --[[ResetFaceIcon]], L_INFO, 0, 2052777044 --[[item_chr_dmy01]])
    local okd, drawn = pcall(PL.AuraPortrait, L_INFO, 0, 2787359195 --[[_item_chr_dmy01]], 2052777044, skill)
    aura_chara = (okd and drawn) and aura_chara or 0
  end
  if aura_chara ~= 0 then
    funcLuaMenuCommand(C.MESH_VISIBLE, L_INFO, 2634282032 --[[_item_chr_base01]], true, 0)
    funcLuaMenuCommand(C.MESH_VISIBLE, L_INFO, 2787359195 --[[_item_chr_dmy01]], true, 0)
  else
    funcLuaMenuCommand(C.MESH_VISIBLE, L_INFO, 2634282032 --[[_item_chr_base01]], false, 0)
    funcLuaMenuCommand(C.MESH_VISIBLE, L_INFO, 2787359195 --[[_item_chr_dmy01]], false, 0)
  end
  ClearItemPositionIcon(L_INFO, 0)
end

-- ---- move detail panel (2026-09-24): the ability board's own window --------------------------------------------------
-- Retail layer team02_02_skill_detail_info (blue header: element icon, name, power; category pill; TENSIÓN gauge + cost;
-- description; "IA activada"), filled exactly as ability_learning_board_menu.UpdateDetailWindow does: the retail
-- personal_plate_inc.SetupPersonalPlateSkillDetailInfo (INCLUDE("LUA_PERSONAL_PLATE_INC") is added by ss2_build.py)
-- with SetSkillItemLayerName(nil, team02_02, 0). Level badge = retail team13_26b_open_level_lock (the board's
-- "Nv. N" tab). Both are attached by the builder to two locators of our left-column layout (right column, lower half).
-- Special (category 8) moves keep the accessory card: the board uses 7 other aura windows for them.
local L_DETAIL = 2628045944      -- team02_02_skill_detail_info
local L_DETAIL_LV = 3654556750   -- team13_26b_open_level_lock
local EVT_DETAIL = true          -- false = back to the accessory card for every move
local EVT_DETAIL_LV_TAB = true   -- show the "Nv. N" badge (row unlock level) on rows that unlock above level 1
local EVT_DETAIL_HIDE_GRAPH = false  -- 2026-09-24: the panel sits left of the radar (ss2_build 8b), the stats stay visible
local EVT_DETAIL_LV_NUMS = {2772869257, 4268123864}   -- team13_26b number settings (MenuNumberSettingName)
local EVT_GRAPH_LAYERS = {{2334590304, 1}, {32151736, 1}, {732343773, 7},   -- soccer11_07 radar, its base, 7 numbers
  {3665300474, 1}}                                 -- soccer11_16 rpg attack / defence param (the dark stat box)
local evt_detail_on = false


-- 2026-10-14 (owner: the right page = Character Reforged's player page, graft plate_pages_skill_host): the page has
-- no stat radar and no hexagon panel, so the retail radar (and the rpg stat box) shows only while a panel of this
-- screen draws on it: the set preview's radar pages (layer evt_psp_base up) and Player Training's training view.
-- The page's per-frame body asks the same function (host_skill.lua keep_radar) before it hides the retail radar.
PL.L_SET_PREVIEW_BASE = 2931540226             -- evt_psp_base (graft pset_preview)
function EVT_SkillTableRadarWanted()
  local training = type(PlayerTraining) == "table" and PlayerTraining.TrainingMode or nil
  if type(training) == "table" and training.on == true then
    return true
  end
  local L = PL.L_SET_PREVIEW_BASE
  return funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, L) == true
    and funcLuaMenuCommand(@crc:CMND_IS_LAYER_VISIBLE@, L, 0) == true
end

function EVT_DetailGraphSync()
  -- v9: the Hiper panel spans the page to x 1890 (plate spec), over the stat radar: the radar goes while it shows
  local hide = (EVT_DETAIL_HIDE_GRAPH and evt_detail_on) or PL.hiper_wide == true or not EVT_SkillTableRadarWanted()
  if not EVT_DETAIL_HIDE_GRAPH and PL.graph_hidden ~= true and not hide then
    return
  end
  -- hiding remembers each instance's visibility (CMND_IS_LAYER_VISIBLE) and showing restores it: the stat box
  -- (soccer11_16) is shown by the retail menu only in some modes
  if hide and PL.graph_hidden ~= true then
    PL.graph_prev = {}
    for _, g in ipairs(EVT_GRAPH_LAYERS) do
      for i = 0, g[2] - 1 do
        PL.graph_prev[g[1] * 16 + i] = funcLuaMenuCommand(@crc:CMND_IS_LAYER_VISIBLE@, g[1], i) ~= false
      end
    end
  end
  for _, g in ipairs(EVT_GRAPH_LAYERS) do
    for i = 0, g[2] - 1 do
      local back = PL.graph_prev == nil or PL.graph_prev[g[1] * 16 + i] ~= false
      funcLuaMenuCommand(C.LAYER_VISIBLE, g[1], i, (not hide) and back)
    end
  end
  -- the big grey rounded panel on the right (343.png) = soccer11_05's page base _sixth_base01 (700 x 464 at x 1212,
  -- y 493): 2026-10-14 never shown (the player page's white card replaces it)
  funcLuaMenuCommand(C.MESH_VISIBLE, 2917320188 --[[soccer11_05_equip_status_base]], 2682382918 --[[_sixth_base01]],
    false, 0)
  PL.sixth_hidden = true
  PL.graph_hidden = hide
end

function EVT_DetailHide()
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_DETAIL, 0, false)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_DETAIL_LV, 0, false)
  if PL.DetailHideAll ~= nil then
    pcall(PL.DetailHideAll)                       -- v7: the passive window and the Hiper panel too
  end
  evt_detail_on = false
end

-- "Nv. N" badge: green open lock (_pos_base02) when the player has the level, grey closed lock (_pos_base01) if not.
local function EVT_DetailLevelTab(row)
  if not EVT_DETAIL_LV_TAB or row == nil then
    return false
  end
  local locked, need = EVT_IsLocked(row)
  if need == nil or need <= 1 then
    return false
  end
  funcLuaMenuCommand(2158717427 --[[locator visible]], L_DETAIL_LV, 1517329426 --[[_pos_base01]], locked, 0)
  funcLuaMenuCommand(2158717427 --[[locator visible]], L_DETAIL_LV, 3279539624 --[[_pos_base02]], not locked, 0)
  funcLuaMenuCommand(2158717427 --[[locator visible]], L_DETAIL_LV, 3335603165 --[[_pos_num01]], true, 0)
  for _, num in ipairs(EVT_DETAIL_LV_NUMS) do
    local idx = funcLuaMenuCommand(@crc:CMND_SEARCH_PRIM_INDEX@, L_DETAIL_LV, 0, num)
    if type(idx) == "number" and idx >= 0 then
      funcLuaMenuCommand(3609943765 --[[set number]], L_DETAIL_LV, 0, idx, need)
      funcLuaMenuCommand(1233047821 --[[number visible]], L_DETAIL_LV, 0, num, true)
    end
  end
  return true
end

-- Fill and show the panel for `skill` on `row`; false = not handled (special move / error): caller shows the card.
-- Polish (2026-09-24): after the retail fill, the same choices it made are redone with our sprites (evt_ss_parts):
-- the element band at the panel's aspect (full bleed, not squeezed), the graded band and no element icon before the
-- name. 2026-10-12 (Nacho): no move-type tag either (the coloured «Tiro» / «Ofensiva» / «Defensa» / «Portero»
-- rectangle above the plate: the retail pill _area_base01, its word _text_area01, locator _pos_area01), hidden after
-- every fill (the retail fill and PL.DetailRestore show it again).
PL.TYPE_TAG_MESH, PL.TYPE_TAG_TEXT, PL.TYPE_TAG_POS = 3516146179 --[[_area_base01]], 1899787537 --[[_text_area01]],
  2313134961 --[[_pos_area01]]
function PL.TypeTagOff()
  funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, PL.TYPE_TAG_MESH, false, 0)
  funcLuaMenuCommand(2735666188 --[[text visible]], L_DETAIL, PL.TYPE_TAG_TEXT, false, 0)
  funcLuaMenuCommand(2158717427 --[[locator visible]], L_DETAIL, PL.TYPE_TAG_POS, false, 0)
end

function PL.DetailPolish(skill, pos)
  local ok, kind = funcLuaCommand(C.SKILL_INFO, skill, 7)
  if ok and kind == 5 then
    local ok2, common = funcLuaCommand(800895612, skill)
    if ok2 and common then
      kind = 6
    end
  end
  if ok and PL.BAND[kind] ~= nil then
    funcLuaMenuCommand(C.SPRITE, L_DETAIL, PL.PARTS_TEX, PL.BAND[kind], 243934124 --[[sp_base01]], 0, 0)
  end
  if pos ~= nil then
    local okw, wl = pcall(function()
      return GetPersonalPlateSkillEvoBaseTextureName(GetSkillEvoLevelByCharaStHdl(n, pos))
    end)
    if okw and PL.WLV[wl] ~= nil then
      funcLuaMenuCommand(C.SPRITE, L_DETAIL, PL.PARTS_TEX, PL.WLV[wl], 2861188530 --[[wlv_base01]], 0, 0)
    end
  end
  PL.TypeTagOff()
  funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, 2164615260 --[[_icon_sp_area_dmy01]], false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, 3543352325 --[[_icon_sp_area01_off]], false, 0)
  -- round 14 (Nacho): no description on the move detail (the text and the window's divider line); the window
  -- itself (_sp_win_base01) is already off; type / AT / TENSIÓN / AI / level stay
  funcLuaMenuCommand(2735666188 --[[text visible]], L_DETAIL, 691026122 --[[_text_flavor01]], false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, CALC_CRC("_item_win_line01"), false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, 3303013605 --[[_sp_win_base01]], false, 0)
end

-- 2026-09-24: a passive (custom passive) in the same integrated panel as the moves (v6 fallback, see PL.PassiveDetail):
-- green band, the name on it, the description on the page; the move-only parts are hidden (and shown again by
-- PL.DetailRestore before the next move).
PL.DETAIL_MOVE_POS = {2313134961 --[[_pos_area01]], 923022909 --[[_pos_tension01]], 4081284803 --[[_pos_at01]]}
PL.DETAIL_MOVE_MESH = {563708378 --[[_gtxt_cmd_at01]], 1013569271 --[[_ai_use01]], 3384915402 --[[_wlv_base01]],
  559600405 --[[_icon_sp_sub_dmy01]], 1220252763 --[[_gtxt_longshoot01]], 1252573939 --[[_gtxt_override01]],
  2164615260 --[[_icon_sp_area_dmy01]], 3543352325 --[[_icon_sp_area01_off]], 3303013605 --[[_sp_win_base01]],
  3516146179 --[[_area_base01]]}
PL.DETAIL_MOVE_TEXT = {1899787537 --[[_text_area01]]}
PL.DETAIL_MOVE_PRIM = {2223127589 --[[AT power]], 3424269865 --[[tension cost]]}
function PL.DetailRestore()
  for _, m in ipairs(PL.MOVE_ROW_HIDE_MESH or {}) do      -- round 14: PL.MoveAsRow hid them on the last move
    funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, m, true, 0)
  end
  funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, 3303013605 --[[_sp_win_base01: off, as before]], false, 0)
  for _, pos in ipairs(PL.DETAIL_MOVE_POS) do
    funcLuaMenuCommand(2158717427 --[[locator visible]], L_DETAIL, pos, true, 0)
  end
  for _, t in ipairs(PL.DETAIL_MOVE_TEXT) do
    funcLuaMenuCommand(2735666188 --[[text visible]], L_DETAIL, t, true, 0)
  end
end

-- v7 (2026-09-24, user): the passive detail is the ORIGINAL board's six-sense piece detail (UpdateDetailWindow
-- category 5 -> personal_plate_inc.UpdateSixSenseDetailInfo on team00_26_passive_slot_detail_info: the six-sense
-- hexagon with the passive's own icon, name, build-type icons, team-buff box, description, build plates), drawn by the
-- retail fill on our clone of its layout (ss2_build 8c: on the page, no card frame, band full bleed). Only the band
-- sprite is ours (the retail band at the panel's aspect, evt_ss_bands.g4tx). No move tag, power or tension.
PL.L_PV_DETAIL = 1593383077                      -- team00_26_passive_slot_detail_info
PL.L_PV_BUILD = 1308983228                       -- team00_25_p1_build_name (2 plates, attached by the window)
PL.L_HIPER = 4153824882           -- the Hiper panel (team02_02 clone, ss2_build 8c)
PL.L_HROW = 1127933049                -- the spirit's move row (shared objbin of the plate Hiper page)
PL.BANDS_TEX = 1432188134                        -- crc32("#/menu/102_team/team02/evt_ss_bands/evt_ss_bands.g4tx")
PL.PV_BAND = {[3317336303 --[[sixth_base01]]] = 3897787648,
  [893157544 --[[sixth_base01_blank]]] = 2975610447}
PL.DETAIL_PRIO = {[1593383077 --[[team00_26 passive window]]] = 656, [1308983228 --[[team00_25 build plates]]] = 657,
  [4153824882] = 657, [1127933049] = 658,
  [2651268807] = 656, [395833588] = 656, [3679282495] = 656, [576015315] = 656, [3635526425] = 656, [1305553269] = 656,
  [3131422953] = 656, [2525671790] = 656}
function PL.Open(L, idx)
  idx = idx or 0
  if funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, L)
      and not funcLuaMenuCommand(@crc:CMND_IS_OPEN_LAYER@, L, idx) then
    funcLuaMenuCommand(@crc:CMND_OPEN_LAYER@, L, idx)
  end
end

function PL.DetailHideAll()
  PL.hiper_wide = false
  PL.mx_aura, PL.mx_view = nil, nil               -- the miximax's attached-aura view (R3) ends with the panel
  if PL.SetDetailLayout ~= nil then
    pcall(PL.SetDetailLayout, nil)                -- back to the layout's own positions (passive windows, card)
  end
  local all = {L_DETAIL, L_DETAIL_LV, PL.L_PV_DETAIL, PL.L_HIPER, PL.L_HROW, 2525671790}
  for _, A in pairs(PL.AURA_LAYER or {}) do
    all[#all + 1] = A
  end
  for _, L in ipairs(all) do
    if funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, L) then
      funcLuaMenuCommand(C.LAYER_VISIBLE, L, 0, false)
    end
  end
  for i = 0, 1 do
    funcLuaMenuCommand(C.LAYER_VISIBLE, PL.L_PV_BUILD, i, false)
    funcLuaMenuCommand(C.LAYER_VISIBLE, PL.L_HROW, i, false)
  end
  PL.pool_peg = nil                               -- 2026-10-12: the aura pool gauge (PL.PoolGauge)
  if PL.POOL ~= nil and funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, PL.L_HIPER) then
    funcLuaMenuCommand(C.LAYER_VISIBLE, PL.L_HIPER, PL.POOL.INST, false)
  end
  pcall(EVT_DetailGraphSync)
end

-- 2026-10-07 (Nacho, shots 384 / 385: «arreglar el alto del cuadro blanco y bajar la supertécnica»): the white card
-- (plate_pages' band copy, rect EVT_PPG_HOST.card) ran from y 625 to 955 under ONE technique row, «Tiro largo»
-- (L_DETAIL's sub-type art, 165 px above the row since the move band it sat on is hidden) floated at y ~510 and the
-- aura banner at ~535. Now one compact block lower on the right (screen px, y down): every detail layer hangs on the
-- base locator _pos_evt_detail01, moved 67 px down (row centre 671 -> 738); the sub-type art sits right on the card's
-- top edge, «IA activada» + the «Nv.» badge on one line in the card's bottom, the aura banner directly on the card,
-- and the card sized to what the state shows (move: row + IA line; aura / miximax: the row, + the second aura header
-- when evt_ss_aura2 shows). Re-applied every frame while a state is set (a layer opened later takes it too); nil =
-- the layouts' own positions and the host's own card (passive windows, the accessory card fallback).
PL.LAYOUT_NODE_POS = 2575768773                  -- CMND set node translation (layer, idx, node, axis, value; y up)
PL.LAYOUT_LOCS = {                               -- L_BASE locators: {node, default x, y, compact x, y[, move x, y]}
  {4039391132 --[[_pos_evt_detail01]], 1235, -735, 1235, -838, 1235, -794},
  {4222036771 --[[_pos_evt_detail_lv01]], 1485, -949, 1279, -840, 1279, -796}}
-- 2026-10-13 (owner): in the move view the move row + TENSIÓN and the «IA activada» / «Nv.» line sit 44 px higher
-- (row centre 774 -> 730, info line 778..814: no empty band above the row without a kind label) and the kind label
-- («Tiro de contraataque» + its icon) on the card's top-left edge (top 648, left 993) instead of mid-slot; the
-- locators' move x / y above (aura, miximax, passive, training keep the compact ones). PL.LayoutLoc(i) = where
-- locator i is now (graft combo_partners places the partner faces from it).
-- 2026-10-07 round 3 (Nacho): the Nv. badge as tall as «IA activada» (36 of its 52 px; the layer scaled about its root,
-- the locator = the badge's right end / vertical centre) and right after it (IA box ~1002..1164, gap 10)
PL.LAYOUT_LV_SCALE = 36 / 52
PL.LAYOUT_MOVE_NODES = {                         -- L_DETAIL (evt_team02_02_detail joints, relative to the locator)
  {559600405 --[[_icon_sp_sub_dmy01]], -261, 230, -242, 146},
  {1220252763 --[[_gtxt_longshoot01]], -211, 229, -192, 145},
  {1252573939 --[[_gtxt_override01]], -78, 240, -59, 156},
  {1013569271 --[[_ai_use01]], -248, -196, -233, 16}}
-- 2026-10-07 round 3 (Nacho, shots 412 / 413: «el cuadro blanco debe ser igual de grande para auras, supertécnicas,
-- etc.»; the aura banner sat above the card): ONE card for every state, 985..1920 x 640..880 (1080p), with the same
-- inside: top slot 650..738 (the aura / miximax banner, 88 px; a move's kind label «Tiro largo» centred in it, 670..718;
-- the custom passive's band), the move row 750..798 (centre 774), the info line 822..858 («IA activada», Nv. badge).
-- Every detail layer hangs on _pos_evt_detail01 at y 838 (= row centre 774 + 64); the aura windows / the custom
-- passive window 12 px down by their _pos_base01 so their band (layout y 200) starts at 650.
PL.CARD_ONE = {985, 640, 1920, 880}
PL.LAYOUT_CARD = {move = PL.CARD_ONE, empty = PL.CARD_ONE, aura = PL.CARD_ONE, training = PL.CARD_ONE}
PL.LAYOUT_AURA_DY = -20       -- 2026-10-12 (Nacho: the banner stuck out of the card's top): 8 px lower, 658..746
-- 2026-10-07 round 3, training view (Nacho: «ajusta esa sección de morada y de libertad y valor base al cuadro blanco;
-- en el cuadro morado pon el texto … y mejora la calidad de los iconos»): PL.PanelPlain's L_DETAIL band as the aura
-- banner (930 x 88 in the card's top slot from its left edge), the stat icon at 64 px on its left (was 170 px, an
-- upscaled icon_common sprite: blurry) and the stat name beside it; the two cells (evt_trn_panel locators
-- _atc_trncell00 / 01, screen units) left-aligned right under the banner. Values: {node, default x, y, sx, sy,
-- training x, y, sx, sy} (layout units from the locator, y up; sx / sy nil = no scale change)
PL.LAYOUT_TRN_NODES = {
  {1125548721 --[[_sp_base01]], -275, 200, 525, 128, -250, 188, 930, 88},
  {3384915402 --[[_wlv_base01]], -275, 200, 525, 128, -250, 188, 930, 88},
  {2164615260 --[[_icon_sp_area_dmy01]], 78, 214, 170, 170, -240, 176, 64, 64},
  {1704438437 --[[_text_name01]], -261, 176, 497, 36, -164, 162, 600, 36}}
PL.LAYOUT_TRN_PANEL = 3504298707               -- evt_trn_panel
PL.LAYOUT_TRN_CELLS = {{1535596773 --[[_atc_trncell00]], 1135, -826, 1080, -795},
  {746612851 --[[_atc_trncell01]], 1355, -826, 1250, -795}}
PL.LAYOUT_CARD_TRAINING = true
-- 2026-10-15 (owner: the role picker's panel showed a huge medal past the band and an empty white card): the plain
-- panel (PL.PanelPlain with opts.banner, mode "plain") uses the training view's banner (band 930 x 88 in the card's top
-- slot, the icon 64 px on its left, the name beside it) and the description right under the band, inside the one card
-- (screen 750..866: three lines). {node, default x, y, sx, sy, plain x, y, sx, sy} (layout units, y up)
PL.LAYOUT_PLAIN_FLAVOR = {691026122 --[[_text_flavor01]], -232, -4, 484, 168, -234, 88, 900, 116}
-- 2026-10-15 round 2 (owner: «arregla cómo se ve abajo a la derecha»): the role panel's own compact card, fully on
-- screen. A text node never moves by node translation (its rect stays at the locator + the retail offset: the name
-- 261 left of it, the description 232 left of it), so the locator _pos_evt_detail01 is placed from the card instead and
-- the band / icon meshes are placed back from it (as the training view does): icon PAD from the card's left edge,
-- the name GAP after it. The description box is the retail 484 px one (its font squeezes any longer line to fit), so it
-- is wrapped to that width by PL.WrapText and the card is as tall as four lines.
PL.CARD_PLAIN = {985, 640, 1650, 956}
PL.LAYOUT_CARD.plain = PL.CARD_PLAIN
PL.PLAIN = {pad = 12, icon = 64, gap = 10, name_x = -261, loc_y = 846, band_y = 196, band_h = 88, icon_y = 184,
  inset = 5, wrap_units = 36, quote_line = CALC_CRC("_item_win_line01")}
-- 2026-10-07 round 2 (Nacho: the banners started ~25 px left of the card): every aura window (and the miximax's
-- second header evt_ss_aura2) moved right by its _pos_base01 so the banner's left edge (layout x -275 from the
-- locator at x 1235 = screen 960) is the card's (985); aura2 sits on the banner line in the miximax's aura view
PL.LAYOUT_AURA_DX = 25
PL.LAYOUT_BASE_NODE = 1517329426                 -- _pos_base01
PL.LAYOUT_AURA2_Y = -205                         -- evt_team00_30_aura2's own _pos_base01 y (under the move row)
-- 2026-10-07 round 2 (Nacho: «ajusta también la pasiva personalizada al sitio»): the custom passive's window
-- (PL.L_PV_DETAIL, evt_team00_26_detail: band 128 px at y 200, effect icon at 52, description box 56 .. -144, the
-- build plates' locators at -150) as the same block: the window right 25 / up 40 so its band sits on the card at
-- 690, the description box 80 px tall (two lines next to the icon, not centred in 200 px), the build plates right
-- under it; the card 690 .. 800 (+ 50 when the build plates show)
-- round 3: inside the one card: band 650..778, icon + two text lines 794..874, the build plates right of the text
PL.LAYOUT_PV = {dx = 25, dy = -12, flavor = 691026122 --[[_text_flavor01]], flavor_w = 780, flavor_h = 110,
  flavor_h_compact = 110, builds = {3683526994 --[[_pos_atc_build01]], 1116174568 --[[_pos_atc_build02]]},
  build_x = {-248, -86}, build_y = -150, build_x_compact = {270, 432}, build_y_compact = 80}
-- 2026-10-28: the layer itself (ss2_build.py T26_JOINTS) now has the 88 band, the 80 medal and the effect text under the
-- band centred on the icon row; these values only repeat it for the Step re-apply; the card is 195 high
PL.LAYOUT_CARD.passive_custom = {985, 640, 1920, 835}
PL.LAYOUT_PV.band = 1632359140 --[[_orb_base01]]
PL.LAYOUT_PV.band_w, PL.LAYOUT_PV.band_w_card, PL.LAYOUT_PV.band_h, PL.LAYOUT_PV.band_h_card = 930, 930, 88, 88
PL.LAYOUT_PV.name = 1704438437 --[[_text_name01]]
-- hexagon + passive icon on the band: {node, x, y, size, compact x, y, size} (x, y in the layer's node units)
PL.LAYOUT_PV.medals = {{1605611365 --[[_icon_fs_area_dmy01]], -62, 192, 80, -62, 192, 80},
  {1896097465 --[[_icon_buff_dmy01]], -53, 183, 62, -53, 183, 62}}
PL.LAYOUT_PV.icons = {{2366589118 --[[_passive_sixth_base01]], -248, 96}, {2408672862 --[[_passive_teambuff_icon_dmy01]], -244, 92}}
PL.LAYOUT_PV.icon_dy = 0
PL.layout_mode = nil
PL.LAYOUT_FRAMES = 60                            -- frames the Step hook re-applies it after a change (layers still opening)
PL.layout_frames = 0

-- where locator i of PL.LAYOUT_LOCS is for the current mode: x, y (layout units, y up)
function PL.LayoutLoc(i)
  local l = PL.LAYOUT_LOCS[i]
  if l == nil then
    return nil
  end
  local mode = PL.layout_mode or nil
  if mode == "move" and l[6] ~= nil then
    return l[6], l[7]
  elseif mode ~= nil then
    return l[4], l[5]
  end
  return l[2], l[3]
end

function PL.ApplyDetailLayout()
  local mode = PL.layout_mode or nil
  if funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, L_BASE) then
    for i, l in ipairs(PL.LAYOUT_LOCS) do
      local x, y = PL.LayoutLoc(i)
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_BASE, 0, l[1], 0, x)
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_BASE, 0, l[1], 1, y)
    end
  end
  local mv = mode == "move"
  local tr = mode == "training"
  local PP = PL.PLAIN
  local plx = PL.CARD_PLAIN[1] + PP.pad + PP.icon + PP.gap - PP.name_x      -- locator x that puts the name right of the icon
  if mode == "plain" and PL.LAYOUT_LOCS[1] ~= nil and funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, L_BASE) then
    funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_BASE, 0, PL.LAYOUT_LOCS[1][1], 0, plx)
    funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_BASE, 0, PL.LAYOUT_LOCS[1][1], 1, -PP.loc_y)
  end
  local banner = tr or mode == "plain"            -- the band as the card's banner, the icon 64 px on its left
  if funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, L_DETAIL) then
    for _, j in ipairs(PL.LAYOUT_TRN_NODES) do
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_DETAIL, 0, j[1], 0, banner and j[6] or j[2])
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_DETAIL, 0, j[1], 1, banner and j[7] or j[3])
      funcLuaMenuCommand(2885415772 --[[node scale]], L_DETAIL, 0, j[1], banner and j[8] or j[4], banner and j[9] or j[5])
    end
    local f = PL.LAYOUT_PLAIN_FLAVOR
    funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_DETAIL, 0, f[1], 0, f[2])         -- the description keeps its retail rect
    funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_DETAIL, 0, f[1], 1, f[3])
    funcLuaMenuCommand(2885415772 --[[node scale]], L_DETAIL, 0, f[1], f[4], f[5])
    if mode == "plain" then
      local x0, x1 = PL.CARD_PLAIN[1], PL.CARD_PLAIN[3]
      for _, band in ipairs({1125548721 --[[_sp_base01]], 3384915402 --[[_wlv_base01]]}) do
        funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_DETAIL, 0, band, 0, x0 - plx)
        funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_DETAIL, 0, band, 1, PP.band_y)
        funcLuaMenuCommand(2885415772 --[[node scale]], L_DETAIL, 0, band, x1 - x0 - PP.inset, PP.band_h)
      end
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_DETAIL, 0, 2164615260 --[[_icon_sp_area_dmy01]], 0, x0 + PP.pad - plx)
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_DETAIL, 0, 2164615260, 1, PP.icon_y)
      funcLuaMenuCommand(2885415772 --[[node scale]], L_DETAIL, 0, 2164615260, PP.icon, PP.icon)
      funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, PP.quote_line, false, 0)    -- the retail grey quote bar
    end
  end
  -- 2026-10-07 (Nacho: «quita los cuadros azules»): no navy list column (L_BASE _list_base01) behind the training
  -- stat rows; back when the training view ends (only then: the custom passive list hides it on its own)
  if tr then
    funcLuaMenuCommand(C.MESH_VISIBLE, L_BASE, 785322415 --[[_list_base01]], false, 0)
    PL.trn_column_off = true
  elseif PL.trn_column_off and mode ~= nil then
    funcLuaMenuCommand(C.MESH_VISIBLE, L_BASE, 785322415, true, 0)
    PL.trn_column_off = false
  end
  if funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, PL.LAYOUT_TRN_PANEL) then
    for _, c in ipairs(PL.LAYOUT_TRN_CELLS) do
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, PL.LAYOUT_TRN_PANEL, 0, c[1], 0, tr and c[4] or c[2])
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, PL.LAYOUT_TRN_PANEL, 0, c[1], 1, tr and c[5] or c[3])
    end
  end
  if funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, L_DETAIL_LV) then
    local k = mv and PL.LAYOUT_LV_SCALE or 1
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_LOCAL_SCALE@, L_DETAIL_LV, k, k, 1, 0)
  end
  if funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, L_DETAIL) then
    for _, j in ipairs(PL.LAYOUT_MOVE_NODES) do
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_DETAIL, 0, j[1], 0, mv and j[4] or j[2])
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, L_DETAIL, 0, j[1], 1, mv and j[5] or j[3])
    end
  end
  local au = mode == "aura" or mode == "mx"
  local wins = {PL.L_AURA2}
  for _, A in pairs(PL.AURA_LAYER or {}) do
    wins[#wins + 1] = A
  end
  for _, A in ipairs(wins) do
    if funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, A) then
      local y = 0
      if A == PL.L_AURA2 then
        y = (au and PL.mx_view == "aura") and PL.LAYOUT_AURA_DY or PL.LAYOUT_AURA2_Y
      elseif au then
        y = PL.LAYOUT_AURA_DY
      end
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, A, 0, PL.LAYOUT_BASE_NODE, 0, au and PL.LAYOUT_AURA_DX or 0)
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, A, 0, PL.LAYOUT_BASE_NODE, 1, y)
    end
  end
  -- 2026-10-12: an aura with a PEG / SP pool: the move's cost and the pool gauge side by side (PL.PoolGauge)
  if PL.POOL ~= nil and funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, PL.L_HIPER) then
    local P = PL.POOL
    local pool = au and PL.pool_peg ~= nil
    for _, g in ipairs({{0, pool and P.MOVE_X or P.X, pool and P.K or 1}, {P.INST, P.POOL_X, P.K}}) do
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, PL.L_HIPER, g[1], P.NODE, 0, g[2])
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, PL.L_HIPER, g[1], P.NODE, 1, P.Y)
      funcLuaMenuCommand(2885415772 --[[node scale]], PL.L_HIPER, g[1], P.NODE, g[3], g[3])
    end
  end
  local pv = PL.LAYOUT_PV
  local pc = mode == "passive_custom"
  if funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, PL.L_PV_DETAIL) then
    local P = PL.L_PV_DETAIL
    funcLuaMenuCommand(PL.LAYOUT_NODE_POS, P, 0, PL.LAYOUT_BASE_NODE, 0, pc and pv.dx or 0)
    funcLuaMenuCommand(PL.LAYOUT_NODE_POS, P, 0, PL.LAYOUT_BASE_NODE, 1, pc and pv.dy or 0)
    funcLuaMenuCommand(2885415772 --[[node scale]], P, 0, pv.flavor, pv.flavor_w, pc and pv.flavor_h_compact or pv.flavor_h)
    for k, b in ipairs(pv.builds) do
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, P, 0, b, 0, pc and pv.build_x_compact[k] or pv.build_x[k])
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, P, 0, b, 1, pc and pv.build_y_compact or pv.build_y)
    end
    funcLuaMenuCommand(2885415772 --[[node scale]], P, 0, pv.band, pc and pv.band_w_card or pv.band_w,
      pc and pv.band_h_card or pv.band_h)
    for _, m in ipairs(pv.medals) do
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, P, 0, m[1], 0, pc and m[5] or m[2])
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, P, 0, m[1], 1, pc and m[6] or m[3])
      funcLuaMenuCommand(2885415772 --[[node scale]], P, 0, m[1], pc and m[7] or m[4], pc and m[7] or m[4])
    end
    for _, ic in ipairs(pv.icons) do
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, P, 0, ic[1], 0, ic[2])
      funcLuaMenuCommand(PL.LAYOUT_NODE_POS, P, 0, ic[1], 1, ic[3] + (pc and pv.icon_dy or 0))
    end
  end
  local H = EVT_PPG_HOST
  if type(H) == "table" then
    if PL.card_default == nil and type(H.card) == "table" then
      PL.card_default = H.card
    end
    local key = mode == "mx" and "aura" or mode    -- 2026-10-07 round 2: one view at a time (R3), one row
    H.card = key ~= nil and PL.LAYOUT_CARD[key] or PL.card_default
  end
end

-- mode: "move" | "aura" | "mx" | "empty" | nil
function PL.SetDetailLayout(mode)
  PL.layout_mode = mode
  PL.layout_frames = mode ~= nil and PL.LAYOUT_FRAMES or 0
  PL.ApplyDetailLayout()
end

function PL.PassiveBoard(item, name)
  local L = PL.L_PV_DETAIL
  if item == nil or item == 0 or UpdateSixSenseDetailInfo == nil
      or not funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, L) then
    return false
  end
  PL.DetailHideAll()
  PL.Open(L)
  PL.Open(PL.L_PV_BUILD, 0)
  PL.Open(PL.L_PV_BUILD, 1)
  local info = funcLuaCommand(@crc:CMND_GET_PASSIVE_SKILL_INFO@, 0, item)
  UpdateSixSenseDetailInfo(0, item, info, n)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 738777627, false, 0)   -- the card frame / shadow
  if type(name) == "string" and name ~= "" then   -- the passive's own name, not the slot label
    funcLuaMenuCommand(C.TEXT, L, PL.LAYOUT_PV.name, name, 0)
  end
  local band = PL.PV_BAND[3317336303]
  funcLuaMenuCommand(C.SPRITE, L, PL.BANDS_TEX, band, 3317336303 --[[sixth_base01]], 0, 0)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L, 0, true)
  evt_detail_on = true
  pcall(PL.SetDetailLayout, "passive_custom")    -- 2026-10-07 round 2: the compact block as the moves
  return true
end

function PL.PassiveDetail(name, desc, item)
  local okb, shown = pcall(PL.PassiveBoard, item, name)
  if okb and shown then
    return
  end
  if not okb then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "passive detail (board window) failed", tostring(shown))
  end
  -- fallback (v6): the move panel with the move-only parts hidden
  if not funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, L_DETAIL) then
    error("no detail layer")
  end
  PL.DetailHideAll()
  for _, pos in ipairs(PL.DETAIL_MOVE_POS) do
    funcLuaMenuCommand(2158717427 --[[locator visible]], L_DETAIL, pos, false, 0)
  end
  for _, mesh in ipairs(PL.DETAIL_MOVE_MESH) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, mesh, false, 0)
  end
  for _, t in ipairs(PL.DETAIL_MOVE_TEXT) do
    funcLuaMenuCommand(2735666188 --[[text visible]], L_DETAIL, t, false, 0)
  end
  for _, pr in ipairs(PL.DETAIL_MOVE_PRIM) do
    funcLuaMenuCommand(1233047821 --[[number visible]], L_DETAIL, 0, pr, false)
  end
  for i = 1, 10 do
    funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, CALC_CRC(string.format("_tension_on%02d", i)), false, 0)
  end
  funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, 1125548721 --[[_sp_base01]], true, 0)
  funcLuaMenuCommand(C.SPRITE, L_DETAIL, PL.PARTS_TEX, PL.BAND[2], 243934124 --[[sp_base01]], 0, 0)
  funcLuaMenuCommand(C.TEXT, L_DETAIL, 1704438437 --[[_text_name01]], name, 0)
  funcLuaMenuCommand(C.TEXT, L_DETAIL, 691026122 --[[_text_flavor01]], desc, 0)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_DETAIL, 0, true)
  evt_detail_on = true
end

-- v8 (2026-09-24, user: "no juegues a inventar, usa lo que existe en el juego"): the Hiper panel. Its aura part is the
-- game's own aura detail window, exactly as the original board shows an aura piece (UpdateDetailWindow ->
-- personal_plate_inc.UpdateAuraSkillDetailInfo -> the team00_30_aura_*_detail_info layer of the aura type): the retail
-- band of that aura type and element, the portrait by the retail rule of the type (keshin / totem face icon on
-- _icon_fs_dmy01, miximax partner on _icon_chr_dmy01), the name and the description (page 3); our clone of its layout
-- only removes the card frame and runs the band from the page edge (ss2_build 8d; band = the same retail sprite cut to
-- the panel's aspect, evt_ss_bands.g4tx). Under the band: the spirit's own move as an ATRIBUTOS row + that move's
-- TENSIÓN (evt_ss_hiper_detail, the plate Hiper page's recipe). Never shown: "IA activada", a move-type icon, power.
-- the card rules shared with the personal plate's Hiper page (mode change partner, no move / TENSIÓN for a mode
-- change, PEG look of keshin / armour / totem): research/grafts/plate_hiper_plate/evt_hiper_card.lua (EVT_HC)
-- Keep the shared component constants in a child chunk so the round-trip decompiler
-- can reconstruct the large techniques menu without exhausting its register fallback.
function EVT_HC_Init()
@HIPER_CARD@
end
EVT_HC_Init()
EVT_HC_Init = nil
PL.HIPER_PANEL = true                            -- false = the accessory card as before
PL.AURA_LAYER = {[0] = 2651268807 --[[keshin]], 395833588 --[[keshin armed]], 3679282495 --[[mixi max]],
  576015315 --[[soul / totem]], 3635526425 --[[kizuna trans]], 1305553269 --[[awakening power]], 3131422953 --[[mode change]]}
-- the retail page that holds the description (_pos_page03 / _text_flavor02) for each aura type
PL.AURA_DESC_PAGE = {[0] = 2, 0, 1, 1, 0, 0, 0}
PL.AURA_HIDE_POS = {3407216458 --[[_pos_page01]], 1377611504 --[[_pos_page02]], 3145665477 --[[_pos_page04]],
  3430431571 --[[_pos_page05]], 1307475940 --[[_pos_list01]], 3571920478 --[[_pos_list02]]}
PL.AURA_HIDE_TEXT = {1179414078 --[[_text_fsp01]], 691026122 --[[_text_flavor01]], 1899787537 --[[_text_area01]],
  3542179801 --[[_text_page_title01]], 1244139107 --[[_text_page_title02]], 2739645270 --[[_text_page_title04]],
  3561790400 --[[_text_page_title05]], 777911507 --[[_text_flavor05]], 325360264 --[[_text_scr_btn01]],
  1757105749}
-- 2026-09-25 (in game: "Hiperenergía" over the name, a red blob, a grey box behind the row): every retail node of the
-- other pages / the power line, hidden one by one (the retail fill sets them visible explicitly)
PL.AURA_HIDE_MESH = {3032210235, 206240291, 563708378 --[[_gtxt_cmd_at01]],
  3516146179 --[[_area_base01]], 811580556 --[[_gtxt_armed01]], 1013569271 --[[_ai_use01]], 4122450641,
  2992676399, 508629071, 4147295610, 2150991340,
  2269285990, 2408672862, 869298536, 4217713136,
  658945009, 905124895, 2370796410, 1956062673, 859266817,
  240613041, 380545388, 68880002, 3165086183, 561011038,
  4195885618, 3182975202, 2161668434, 855158082}
-- both portrait slots of an aura window cleared on every show: no face of an earlier row / player / fallback leaks
function PL.FaceReset(A)
  funcLuaMenuCommand(4176779611 --[[clear face icon]], A, 0, 1051570875 --[[icon_fs_dmy01]])
  funcLuaMenuCommand(4176779611 --[[clear face icon]], A, 0, 3237726902 --[[icon_chr_dmy01]])
end

function PL.AuraClean(A)
  for _, p in ipairs(PL.AURA_HIDE_POS) do
    funcLuaMenuCommand(2158717427 --[[locator visible]], A, p, false, 0)
  end
  for _, x in ipairs(PL.AURA_HIDE_TEXT) do
    funcLuaMenuCommand(2735666188 --[[text visible]], A, x, false, 0)
  end
  for _, m in ipairs(PL.AURA_HIDE_MESH) do
    funcLuaMenuCommand(C.MESH_VISIBLE, A, m, false, 0)
  end
  funcLuaMenuCommand(1233047821 --[[number visible]], A, 0, 2223127589, false)
  funcLuaMenuCommand(2158717427, A, 636603611, false, 0)
  funcLuaMenuCommand(C.MESH_VISIBLE, A, 443104220, false, 0)
end
-- the move-panel clone keeps only the TENSIÓN line and the row's locator
PL.HIPER_HIDE_MESH = {3303013605 --[[_sp_win_base01]], 1125548721 --[[_sp_base01]], 3543352325 --[[_icon_sp_area01_off]],
  3384915402 --[[_wlv_base01]], 1013569271 --[[_ai_use01]], 559600405 --[[_icon_sp_sub_dmy01]],
  1220252763 --[[_gtxt_longshoot01]], 1252573939 --[[_gtxt_override01]], 563708378 --[[_gtxt_cmd_at01]],
  2164615260 --[[_icon_sp_area_dmy01]], 3516146179 --[[_area_base01]], 656425078}
PL.HIPER_HIDE_POS = {4081284803 --[[_pos_at01]], 1417578953, 3447183475}
PL.HIPER_HIDE_TEXT = {1704438437 --[[_text_name01]], 691026122 --[[_text_flavor01]]}

function PL.HiperMove(L, skill, team_info)
  local R = PL.L_HROW
  -- shared rule (EVT_HC.AuraMove): the change skill, else the loader's (armed forms); a mode change has none
  local ok, move = EVT_HC.AuraMove(skill)
  if not ok or type(move) ~= "number" or move == 0 or SetupCharaSkillItem == nil
      or not funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, R) then
    funcLuaMenuCommand(C.LAYER_VISIBLE, R, 0, false)
    PL.TensionOff(L)                               -- no move row: no TENSIÓN part at all (as the plate)
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "hiper move row", "none", tostring(ok), tostring(move))
    return
  end
  PL.MoveRow(L, move, team_info, 0, false, nil, EVT_HC.PegInfo(skill))
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "hiper move row", string.format("%08X", EVT_U32(skill)),
    string.format("%08X", EVT_U32(move)))
end

-- a move as an ATRIBUTOS row (evt_ph_move_row) + its TENSIÓN on L (the Hiper panel clone); also used by the miximax
-- the TENSIÓN part completely off: squares and number too (set visible explicitly, they outlive a hidden locator)
function PL.TensionOff(L)
  VRFW_UI.MovePlate.TensionOff(L, 0)             -- the shared gauge (VRFW_UI.MovePlate, 66_ui_plates.lua)
end

-- peg = EVT_HC.PegInfo of the aura (keshin / armour / totem): the gauge in the PEG look, the move's cost in PEG / SP
-- 2026-10-12 (Nacho: a move-rank book on one move showed +1 on every move plate): the retail SetupCharaSkillItem
-- reads the evolution grade at skill_list[inst] = its row INSTANCE; our rows draw any move at instance 0 / k. The fix
-- is the VR-Framework's shared move plate since 2026-10-13 (VRFW_UI.MovePlate.Graded: the move's OWN grade; every
-- screen with a move plate uses it). Returns pcall's ok, err.
function PL.SkillItem(chara, move, inst)
  return VRFW_UI.MovePlate.Graded(chara, move, inst, SetupCharaSkillItem, chara, move or 0, inst, false)
end

function PL.MoveRow(L, move, team_info, idx, no_tension, owner, peg)
  local R = PL.L_HROW
  idx = idx or 0
  if move == nil or move == 0 or SetupCharaSkillItem == nil or type(VRFW_UI) ~= "table"
      or not funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, R) then
    funcLuaMenuCommand(C.LAYER_VISIBLE, R, idx, false)
    PL.TensionOff(L)                               -- no spirit-move row (armours): no TENSIÓN part at all
    return
  end
  -- the shared move plate (VRFW_UI.MovePlate.Fill: the move's own grade, no blank / AI-mark layers, focus frame off),
  -- then back to this screen's own setting (as EVT_DetailShow)
  local o = {page = L, open = PL.Open, restore = {nil, L_DETAIL, 0, nil, nil}}
  local chara = (owner ~= nil and owner ~= 0) and owner or n
  local okf, err = VRFW_UI.MovePlate.Fill(R, idx, chara, move, o)
  if not okf and chara ~= n then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "move row with the partner failed", tostring(err), "retry with the base")
    okf, err = VRFW_UI.MovePlate.Fill(R, idx, n, move, o)
  end
  if not okf then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "hiper move row failed", string.format("%08X", EVT_U32(move)), tostring(err))
    return
  end
  if no_tension then
    PL.TensionOff(L)
    return
  end
  -- the TENSIÓN gauge (the shared one, VRFW_UI.MovePlate.Tension): the move's own cost, squares = cost / team scale
  -- x 10 (the given team's scale, else team 255's: outside a match the global scale); PEG mode (shared rule): the
  -- move's cost in the pool, squares = cost / pool x 10, the PEG look after the locator
  local okc, cost = funcLuaCommand(C.SKILL_INFO, move, 11)
  local o = {teams = table.pack(team_info, 255)}
  if peg ~= nil then
    okc, cost, o.scale = true, peg.cost, peg.pool
  end
  o.look = function(l, i)
    pcall(EVT_HC.PegLook, l, i, peg ~= nil, peg and peg.kind)
  end
  VRFW_UI.MovePlate.Tension(L, 0, (okc and type(cost) == "number") and cost or nil, o)
end

-- the aura part: the retail window of the type, filled by the retail function, then only the surface is changed
function PL.HiperAura(skill, team_info)
  local okt, t = funcLuaCommand(C.SKILL_INFO, skill, 13)
  local A = okt and PL.AURA_LAYER[t] or nil
  if A == nil or UpdateAuraSkillDetailInfo == nil or not funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, A) then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "hiper aura window", "type", tostring(t), "missing")
    return false
  end
  PL.Open(A)
  local page = PL.AURA_DESC_PAGE[t] or 0
  if WarpAuraSkillDetailInfoPageIdx ~= nil then
    local okw, p = pcall(WarpAuraSkillDetailInfoPageIdx, page, t, skill)
    if okw and type(p) == "number" then
      page = p
    end
  end
  pcall(PL.FaceReset, A)
  UpdateAuraSkillDetailInfo(skill, n, nil, team_info, page, true)
  funcLuaMenuCommand(C.MESH_VISIBLE, A, 443104220, false, 0)       -- the card frame / shadow
  funcLuaMenuCommand(C.MESH_VISIBLE, A, 1013569271 --[[_ai_use01]], false, 0)   -- "IA activada": not for auras here
  funcLuaMenuCommand(2158717427 --[[locator visible]], A, 636603611, false, 0)   -- the type + cost line is there
  for _, p in ipairs(PL.AURA_HIDE_POS) do
    funcLuaMenuCommand(2158717427 --[[locator visible]], A, p, false, 0)
  end
  for _, x in ipairs(PL.AURA_HIDE_TEXT) do
    funcLuaMenuCommand(2735666188 --[[text visible]], A, x, false, 0)
  end
  funcLuaMenuCommand(1233047821 --[[number visible]], A, 0, 2223127589, false)
  pcall(PL.AuraClean, A)
  -- round 14 (Nacho): no description page on the aura card (its plate + text)
  funcLuaMenuCommand(2158717427 --[[locator visible]], A, 622567014 --[[_pos_page03]], false, 0)
  funcLuaMenuCommand(2735666188 --[[text visible]], A, 2956552560 --[[_text_flavor02]], false, 0)
  -- v9: the band stays the retail sprite the fill chose (aura type + element), drawn at its own aspect (930 x 88)
  local oke, el = funcLuaCommand(C.SKILL_INFO, skill, 7)
  funcLuaMenuCommand(C.LAYER_VISIBLE, 1921826160 --[[team00_40_change_page_guide]], 0, false)
  funcLuaMenuCommand(C.LAYER_VISIBLE, A, 0, true)
  local okc, cid = funcLuaCommand(C.SKILL_INFO, skill, 17)
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "hiper aura window", string.format("%08X", EVT_U32(skill)), "type", t,
    "element", tostring(el), "page", page, "info17", tostring(okc), tostring(cid))
  return true
end

-- the card rules of the shared component (EVT_HC) on the retail aura window, after the retail fill, so this panel
-- draws what the plate's Hiper page draws (2026-10-04, user: «tiene que verse igual»): the shared band of the aura type
-- + element and the type icon, the name («Modo cambio: <partner>»), a mode change's partner in the
-- miximax portrait quad, the skill's description (as the plate's panel).
function PL.HiperCard(skill)
  local t = EVT_HC.AuraType(skill)
  local A = t ~= nil and PL.AURA_LAYER[t] or nil
  if A == nil then
    return
  end
  local mc = EVT_HC.McGet(n, skill)
  local okn, nameId = funcLuaCommand(C.SKILL_INFO, skill, 4)
  local name = okn and nameId ~= nil and funcLuaCommand(C.NAME_TEXT, nameId) or nil
  -- 2026-10-12 (Nacho): the name only (no «·  PEG 170»): the pool is its own gauge, PL.PoolGauge
  local title = EVT_HC.Title(type(name) == "string" and name or nil, nil, mc)
  EVT_HC.Header(A, skill, title, 0)
  -- round 14 (Nacho): the player page's card rule - its portrait (EVT_HC.Portrait: the partner / the aura's character
  -- on the slot its type uses; the white block was the empty slot) - and no description plate here
  local okp, ep = pcall(EVT_HC.Portrait, A, skill, nil, mc, "skill_panel", 0)
  if not okp then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "portrait failed", tostring(ep))
  end
  local d = ""
  funcLuaMenuCommand(2735666188 --[[text visible]], A, 2956552560 --[[_text_flavor02]], false, 0)
  funcLuaMenuCommand(2158717427 --[[locator visible]], A, 622567014 --[[_pos_page03]], false, 0)
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "hiper card", string.format("%08X", EVT_U32(skill)), tostring(t),
    tostring(title), "partner", tostring(mc ~= nil), "desc", #d)
end

-- 2026-10-12 (Nacho, shot 156: «quita "· PEG 170" del banner; el PEG del aura como barra morada + número, como el
-- de la técnica, a la derecha del PEG de la técnica, justo debajo del retrato»): a keshin / armour / totem shows its
-- pool as a second TENSIÓN group in the PEG (SP) look: instance 1 of the Hiper panel clone (evt_ss_hiper_detail,
-- count 2; attached to the same locator as instance 0) with every part but its TENSIÓN group hidden, all 10 squares
-- lit, the pool as the number. On that line both groups are scaled K: the move's cost moves left (x MOVE_X), the pool
-- sits at the right end, under the banner's portrait (x POOL_X; layout units of _pos_tension01, default X / scale 1,
-- research/scripts/ss2_build.py HIPER_JOINTS). PL.pool_peg (the pool shown) drives PL.ApplyDetailLayout; cleared by
-- PL.DetailHideAll.
PL.POOL = {INST = 1, NODE = 923022909 --[[_pos_tension01]], X = 423, Y = 70, K = 0.75, MOVE_X = 289, POOL_X = 478}

function PL.PoolGauge(L, peg)
  local P = PL.POOL
  local i = P.INST
  PL.pool_peg = nil
  if peg == nil or type(peg.pool) ~= "number" or peg.pool <= 0 then
    funcLuaMenuCommand(C.LAYER_VISIBLE, L, i, false)
    return false
  end
  PL.Open(L, i)
  for _, m in ipairs(PL.HIPER_HIDE_MESH) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L, m, false, i)
  end
  for _, q in ipairs(PL.HIPER_HIDE_POS) do
    funcLuaMenuCommand(2158717427 --[[locator visible]], L, q, false, i)
  end
  for _, x in ipairs(PL.HIPER_HIDE_TEXT) do
    funcLuaMenuCommand(2735666188 --[[text visible]], L, x, false, i)
  end
  funcLuaMenuCommand(2735666188, L, 1899787537 --[[_text_area01]], false, i)
  funcLuaMenuCommand(2158717427, L, 2313134961 --[[_pos_area01]], false, i)
  funcLuaMenuCommand(1233047821 --[[number visible]], L, i, 2223127589 --[[AT power]], false)
  -- the pool as a full gauge (the shared TENSIÓN gauge: every square lit, the pool as the number, the PEG look)
  VRFW_UI.MovePlate.Tension(L, i, peg.pool, {scale = peg.pool, look = function(l, k)
    pcall(EVT_HC.PegLook, l, k, true, peg.kind)
  end})
  funcLuaMenuCommand(C.LAYER_VISIBLE, L, i, true)
  PL.pool_peg = peg
  return true
end

function PL.HiperShow(skill, team_info)
  if skill == PL.MX_FUSION and PL.MxDetail ~= nil then
    local okf, f = pcall(PL.MxGet)
    if okf and f ~= nil then
      return PL.MxDetail(f, team_info)
    end
  end
  local L = PL.L_HIPER
  if not PL.HIPER_PANEL or not funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, L) then
    return false
  end
  PL.DetailHideAll()
  PL.Open(L)
  if not PL.HiperAura(skill, team_info) then
    return false
  end
  for _, m in ipairs(PL.HIPER_HIDE_MESH) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L, m, false, 0)
  end
  for _, p in ipairs(PL.HIPER_HIDE_POS) do
    funcLuaMenuCommand(2158717427 --[[locator visible]], L, p, false, 0)
  end
  for _, x in ipairs(PL.HIPER_HIDE_TEXT) do
    funcLuaMenuCommand(2735666188 --[[text visible]], L, x, false, 0)
  end
  funcLuaMenuCommand(1233047821 --[[number visible]], L, 0, 2223127589 --[[AT power]], false)
  -- Header v3 (as the plate's Hiper page): no type / cost line; the retail aura-type icon in the band's left slot
  -- (drawn by the retail fill) tells the type
  funcLuaMenuCommand(C.TEXT, L, 1899787537 --[[_text_area01]], "", 0)
  funcLuaMenuCommand(2735666188 --[[text visible]], L, 1899787537, false, 0)
  pcall(PL.HiperCard, skill)
  PL.HiperMove(L, skill, team_info)
  local peg = EVT_HC.PegInfo(skill)
  pcall(EVT_HC.PegPool, L, peg)
  local okg, eg = pcall(PL.PoolGauge, L, peg)          -- 2026-10-12: the spirit's PEG / SP pool as a gauge
  if not okg then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "pool gauge failed", tostring(eg))
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, L, 0, true)
  evt_detail_on = true
  PL.hiper_wide = true
  pcall(EVT_DetailGraphSync)
  pcall(PL.SetDetailLayout, "aura")              -- 2026-10-07: banner on a card sized to the row
  return true
end

-- round 14 (Nacho: the move detail in the SUPERTÉCNICAS style): a move shows as the SAME move row the player page
-- and the aura card use (layer evt_ph_move_row: the soccer11_09 plate pill with name / AT, filled by the retail
-- SetupCharaSkillItem, PL.MoveRow) with its TENSIÓN group in the shared style, on the Hiper panel (PL.L_HIPER, whose
-- band / name / description are hidden as for an aura); the retail window (L_DETAIL) keeps only its info pieces:
-- type, «IA activada»; its band, name, AT, TENSIÓN and move-type tag are hidden. PL.MOVE_AS_ROW = false: as before.
PL.MOVE_AS_ROW = true
PL.MOVE_ROW_HIDE_MESH = {1125548721 --[[_sp_base01]], 3384915402 --[[_wlv_base01]], 563708378 --[[_gtxt_cmd_at01]],
  3303013605 --[[_sp_win_base01]]}
function PL.MoveAsRow(skill, team_info)
  local L = PL.L_HIPER
  if not PL.MOVE_AS_ROW or not funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, L) then
    return false
  end
  PL.Open(L)
  for _, m in ipairs(PL.HIPER_HIDE_MESH) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L, m, false, 0)
  end
  for _, q in ipairs(PL.HIPER_HIDE_POS) do
    funcLuaMenuCommand(2158717427 --[[locator visible]], L, q, false, 0)
  end
  for _, x in ipairs(PL.HIPER_HIDE_TEXT) do
    funcLuaMenuCommand(2735666188 --[[text visible]], L, x, false, 0)
  end
  funcLuaMenuCommand(2735666188, L, 1899787537 --[[_text_area01]], false, 0)
  funcLuaMenuCommand(2158717427, L, 2313134961 --[[_pos_area01]], false, 0)
  funcLuaMenuCommand(1233047821 --[[number visible]], L, 0, 2223127589 --[[AT power]], false)
  PL.MoveRow(L, skill, team_info, 0, false, nil, nil)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L, 0, true)
  -- the retail window: only its info pieces
  for _, m in ipairs(PL.MOVE_ROW_HIDE_MESH) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, m, false, 0)
  end
  funcLuaMenuCommand(2735666188, L_DETAIL, 1704438437 --[[_text_name01]], false, 0)
  funcLuaMenuCommand(2158717427, L_DETAIL, 923022909 --[[_pos_tension01]], false, 0)
  funcLuaMenuCommand(2158717427, L_DETAIL, 4081284803 --[[_pos_at01]], false, 0)
  funcLuaMenuCommand(1233047821, L_DETAIL, 0, 2223127589, false)
  funcLuaMenuCommand(1233047821, L_DETAIL, 0, 3424269865 --[[tension cost]], false)
  pcall(EVT_Call, C.EVT_LOG, "skill_slots", "move as row", string.format("%08X", EVT_U32(skill)))
  return true
end

function EVT_DetailShow(skill, row)
  if not EVT_DETAIL or skill == 0 then
    return false
  end
  if not funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, L_DETAIL) then
    return false
  end
  local _, team_info = GetSoccerTeamInfo(0)            -- tension gauge scale (board: GetSoccerTeamInfo(0))
  if EVT_IsSpecial(skill) then                         -- v7: the Hiper has its own panel
    local okh, shown = pcall(PL.HiperShow, skill, team_info)
    if okh and shown then
      return true
    end
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "hiper panel", tostring(okh), tostring(shown))
    return false
  end
  PL.DetailHideAll()
  SetSkillItemLayerName(nil, L_DETAIL, 0, nil, nil)   -- as the board's OnInit
  -- grade: the retail window adds the evolution code / base and the graded power when given the skill_list position
  local pos = funcLuaCommand(C.SKILL_POS, n, skill)
  if type(pos) ~= "number" or pos < 0 or pos >= 6 then
    pos = nil
  end
  pcall(PL.DetailRestore)                         -- a passive may have hidden the move-only parts
  SetupPersonalPlateSkillDetailInfo(skill, n, nil, team_info, pos, true)
  -- 2026-09-24: part of the player panel, not a card on top of it: no window frame / shadow
  funcLuaMenuCommand(C.MESH_VISIBLE, L_DETAIL, 3303013605 --[[_sp_win_base01]], false, 0)
  pcall(PL.DetailPolish, skill, pos)
  local okr, er = pcall(PL.MoveAsRow, skill, team_info)   -- round 14: the shared move row + TENSIÓN
  if not okr then
    pcall(EVT_Call, C.EVT_LOG, "skill_slots", "move as row failed", tostring(er))
  end
  -- the retail fill shows the layer itself at its end (it stays hidden if the move data is missing)
  local lv = EVT_DetailLevelTab(row)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_DETAIL_LV, 0, lv)
  evt_detail_on = true
  pcall(PL.SetDetailLayout, "move")              -- 2026-10-07: label on the card, row + IA / Nv. line in it
  return true
end

function UpdateEquipItemInfo()
  local skill, removable, row = 0, false, nil
  local fixed = false                     -- 2026-09-24: row cannot be edited (level-locked or Prime)
  if n14 ~= L_BTN then
    local ret = funcLuaMenuCommand(C.FOCUS_IDX, L_ROW)
    funcLuaMenuCommand(C.CURSOR_LOC, L_ROW, 3313461902 --[[cursor]], ret, EVT_ROW_NUM + 1)
    row = ret
    local locked = EVT_IsLocked(ret)
    local prime = EVT_IsPrime()
    skill = PL.RowMove(ret)                -- a still-locked move is shown too when it is known (Prime / learnset)
    fixed = locked or prime or PL.IdolFixed(ret)
    removable = skill ~= 0 and not fixed
  end
  local okd, shown = false, false
  if skill ~= 0 then
    okd, shown = pcall(EVT_DetailShow, skill, row)
  end
  if okd and shown then
    SetVisibleEquipInfoWindow(false)
  else
    pcall(EVT_DetailHide)
    if skill ~= 0 then
      SetVisibleEquipInfoWindow(true)
      EVT_SetupSkillInfo(skill)
    else
      SetVisibleEquipInfoWindow(false)
      pcall(PL.SetDetailLayout, "empty")         -- 2026-10-07: an empty row keeps the compact card, not a tall blank one
    end
  end
  if fixed then
    funcLuaMenuCommand(2209673388, n12, 1138543975 --[[mainmenu01_06_base_button_guide]], {}, {}, {})
    funcLuaMenuCommand(452337289, n12, 1138543975 --[[mainmenu01_06_base_button_guide]], {})
  elseif n14 ~= L_BTN then
    PL.guide_redo = function() PL.RowGuide() end   -- Aceptar, Y Restablecer
    PL.guide_redo()
  else
    UpdateEquipButtonGuide(n12, removable)   -- bottom buttons: Aceptar
  end
  if n14 ~= L_BTN and EVT_IsPrime() then
    funcLuaMenuCommand(C.TEXT, 3078308064 --[[mainmenu90_05_content_guide_line01]], 378156699 --[[_text_guide01]], PL.Txt(PL.PRIME_GUIDE), 0)
  elseif n14 ~= L_BTN and PL.IdolFixed(row) then
    funcLuaMenuCommand(C.TEXT, 3078308064 --[[mainmenu90_05_content_guide_line01]], 378156699 --[[_text_guide01]], PL.Txt(PL.IDOL_GUIDE), 0)
  end
  -- 2026-10-14: no retail radar / rpg stat box refill here (the player page shows neither; the set preview and the
  -- training view draw their own values on the radar)
  pcall(EVT_DetailGraphSync)
end

function UpdateEquipCondition(a1, a2)
  EVT_RefreshRows()
  UpdateCharaStatus()
  UpdateEquipItemInfo()
end

-- ---- layer setup -------------------------------------------------------------------------------------------
local EVT_RetailOnSetupLayer = OnSetupLayer
function OnSetupLayer(a1, a2)
  local prio = PL.DETAIL_PRIO ~= nil and PL.DETAIL_PRIO[a1] or nil
  if prio ~= nil then
    -- v7 / v8 detail windows: over the player panel (the move panel's 656), hidden until something is focused
    funcLuaMenuCommand(@crc:CMND_SET_DRAW_PRIORITY@, a1, a2, prio, true)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  end
  if a1 == L_DETAIL or a1 == L_DETAIL_LV then
    -- move detail panel + level badge: the board's priorities (656 / 657), hidden until a move is focused
    funcLuaMenuCommand(@crc:CMND_SET_DRAW_PRIORITY@, a1, a2, a1 == L_DETAIL and 656 or 657, true)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  end
  if a1 == L_BASE then
    -- retail team05_01 branch without the equip01..05 / equipNN_rpg / eye-check trace switches
    funcLuaMenuCommand(@crc:CMND_SET_DRAW_PRIORITY@, a1, a2, 450, true)
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, 4168479935 --[[chara02]], false)
    funcLuaMenuCommand(C.LAYER_VISIBLE, 508919562 --[[team00_02_chara_card]], 0, false)
    funcLuaMenuCommand(3252599449 --[[set list item count]], L_ROW, EVT_ROW_NUM)
    funcLuaMenuCommand(C.MESH_VISIBLE, a1, 2728862193 --[[_gtxt_equipment01 "Equipamiento" label]], false, a2)
    if n15 > 1 then
      funcLuaMenuCommand(C.MESH_VISIBLE, a1, 1821189452 --[[_arrow01_l01]], true, a2)
      funcLuaMenuCommand(C.MESH_VISIBLE, a1, 2050337590 --[[_arrow01_r01]], true, a2)
      local text_get = funcLuaCommand(@crc:CMND_TEXT_GET@, 1406349308)
      funcLuaMenuCommand(C.TEXT, a1, 3853210161 --[[_text_btn01_l]], text_get, a2)
      funcLuaMenuCommand(2333948100, a1, a2, 3853210161 --[[_text_btn01_l]], 1155652271)
      local text_get2 = funcLuaCommand(@crc:CMND_TEXT_GET@, 1681049711)
      funcLuaMenuCommand(C.TEXT, a1, 530870098 --[[_text_btn01_r]], text_get2, a2)
      funcLuaMenuCommand(2333948100, a1, a2, 530870098 --[[_text_btn01_r]], 1155652271)
    end
    if flag7 then
      UpdateEquipButtonGuide(n12, true)
      funcLuaMenuCommand(1432240275, n12, 1138543975 --[[mainmenu01_06_base_button_guide]], false)
    end
    return
  end
  EVT_RetailOnSetupLayer(a1, a2)
  if a1 == L_BTN then
    -- _text_btn01 is the 50x50 key glyph, _text_cmd01 the 400-px label
    funcLuaMenuCommand(C.TEXT, a1, 625330766 --[[_text_cmd01]], PL.Txt(EVT_BUTTON_TEXT), a2)
  end
end

local EVT_RetailOnOpenLayer = OnOpenLayer
function OnOpenLayer(a1, a2)
  EVT_RetailOnOpenLayer(a1, a2)
  if a1 == 3078308064 --[[mainmenu90_05_content_guide_line01]] then
    funcLuaMenuCommand(C.TEXT, a1, 378156699 --[[_text_guide01]], PL.Txt(EVT_GUIDE_TEXT), a2)
  end
end

-- ---- input -------------------------------------------------------------------------------------------------
function OnEnter(a1, a2)
  -- retail stored list-group parameters here; this menu has no list group
end

function OnDecideFocus(a1, a2)
  if evt_co ~= nil then
    return
  end
  if a1 == L_ROW then
    local locked = EVT_IsLocked(a2)
    if locked or EVT_IsPrime() or PL.IdolFixed(a2) then     -- 2026-09-24: Prime = fixed moveset; 2026-09-27: Idol rows
      funcLuaCommand(C.SE, SE_NG)
      return
    end
    evt_co = coroutine.create(function()
      EVT_PickCoroutine(a2)
    end)
  elseif a1 == L_BTN then
    EVT_OpenOriginalBoard()
  end
end

local EVT_RetailOnFunction = OnFunction
function OnFunction(a1, a2)
  if evt_co ~= nil then
    return
  end
  if a1 == 3918588344 then          -- CMD_FUNC1 (retail "best equipment") -> original ability board
    EVT_OpenOriginalBoard()
  elseif a1 == 4109882573 or a1 == 1141890006 then
    -- 4109882573 = CMD_FUNC3 (Y): «Restablecer» (owner 2026-10-19: the only row action on this key)
    -- 1141890006 = CMD_FUNC4 (X): partner picker of a combo move (EVT_CPK.Open; docs/game/mechanics/combo-partners.md)
    local row = funcLuaMenuCommand(C.FOCUS_IDX, L_ROW)
    local ok_row = row ~= nil and row >= 0 and row < EVT_ROW_NUM and n14 ~= L_BTN and not EVT_IsLocked(row)
    if a1 == 1141890006 then
      -- X: Inazuma Fantasy's own partner picker when its block is here; otherwise the key belongs to the declared
      -- X action of graft skill_table_host (Utilities' partner picker), which takes it before this function. Nothing
      -- declared: X does nothing (2026-10-14, owner: no sound, no guide entry)
      local skill = ok_row and PL.RowMove(row) or 0
      if EVT_CPK ~= nil and skill ~= 0 and EVT_CPK.Needs(row, skill) then
        evt_co = coroutine.create(function()
          EVT_CPK.Open(row, skill)
        end)
      end
    elseif ok_row and not EVT_IsPrime() and not PL.IdolFixed(row) then
      evt_co = coroutine.create(function()
        EVT_ResetCoroutine(row)
      end)
    else
      funcLuaCommand(C.SE, SE_NG)
    end
  else
    EVT_RetailOnFunction(a1, a2)    -- L/R: previous/next player (ChangeChara uses the overrides above)
  end
end

local EVT_RetailOnBack = OnBack
function OnBack(a1)
  -- 2026-10-06 (in game: back / Esc did nothing in this screen, nothing logged): every back logs what it does
  local st = evt_co ~= nil and coroutine.status(evt_co) or "none"
  if evt_co ~= nil and st == "dead" then
    evt_co = nil                          -- a finished action must never keep the screen from closing
  end
  pcall(funcLuaCommand, C.EVT_LOG, "skill_slots", "back", tostring(a1), "action", st,
    evt_co ~= nil and "swallowed (an action runs)" or "closing")
  if evt_co ~= nil then
    return
  end
  PL.closeLog = 60                        -- 2026-10-06: the next 60 frames log the close state (Step)
  pcall(funcLuaCommand, C.EVT_LOG, "skill_slots", "back: retail OnBack", "closing before",
    tostring(funcLuaCommand(C.CLOSING_MENU, EVT_MENU)), "closed before", tostring(funcLuaCommand(C.CLOSED_MENU, EVT_MENU)))
  EVT_RetailOnBack(a1)
  funcLuaCommand(C.SE, SE_BACK)
  evt_back_frames = 2   -- close ourselves in Step() if the engine did not (new menus have no native back)
end

local evt_cursor_idx = -1
local EVT_RetailOnChangeFocus = OnChangeFocus
function OnChangeFocus(a1, a2)
  -- retail returns early unless CMND_IS_CTRL_FOCUS_ACTIVE; after the picker that flag can stay off and the cursor
  -- arrow stopped following the focus frame (try 5) -> always update for our two focus layers
  if a1 == L_ROW or a1 == L_BTN then
    n14 = a1
    UpdateEquipItemInfo()
    return
  end
  EVT_RetailOnChangeFocus(a1, a2)
end

function Step()
  if evt_hiper_pending and EVT_HiperTexReady() then   -- purple base finished loading after row 0 was set up
    EVT_SetRowBase(0)
  end
  if next(PL.lock_pending) ~= nil and PL.LockTexReady() then   -- navy "off" base finished loading
    for r in pairs(PL.lock_pending) do
      EVT_SetRowBase(r, true)
    end
  end
  if evt_co == nil and n14 ~= L_BTN then   -- keep the arrow cursor on the focused row
    local i = funcLuaMenuCommand(C.FOCUS_IDX, L_ROW)
    if i ~= nil and i ~= evt_cursor_idx and i >= 0 and i < EVT_ROW_NUM then
      evt_cursor_idx = i
      funcLuaMenuCommand(C.CURSOR_LOC, L_ROW, 3313461902 --[[cursor]], i, EVT_ROW_NUM + 1)
    end
  end
  if evt_co ~= nil then
    local ok, err = coroutine.resume(evt_co)
    if not ok then
      PRINT("evt_skill_slot_menu: " .. tostring(err))
      evt_co = nil
      local text = "ERROR Lua: " .. tostring(err)
      evt_co = coroutine.create(function()   -- (EVT_Message is a local defined further down: inline it)
        funcLuaCommand(C.MSG_OPEN, text, 0, 0, 0, 0, 0, false)
        while funcLuaCommand(C.MSG_BUSY) do
          coroutine.yield()
        end
        while not funcLuaCommand(C.MSG_DONE) do
          coroutine.yield()
        end
        funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
      end)
    elseif coroutine.status(evt_co) == "dead" then
      evt_co = nil
    end
  end
  if evt_back_frames >= 0 then
    evt_back_frames = evt_back_frames - 1
    if evt_back_frames < 0 and not funcLuaCommand(C.CLOSING_MENU, EVT_MENU) and not funcLuaCommand(C.CLOSED_MENU, EVT_MENU) then
      pcall(funcLuaCommand, C.EVT_LOG, "skill_slots", "back: close requested")
      funcLuaCommand(C.CLOSE_MENU, EVT_MENU)
    end
  end
  -- diagnostic (2026-10-06, the close never finishes): for 60 frames after a back, every 5th frame, the close state,
  -- the action coroutine and which of this screen's own layers are still open / loading
  if (PL.closeLog or 0) > 0 then
    PL.closeLog = PL.closeLog - 1
    if PL.closeLog % 5 == 0 then
      local open = {}
      local watch = {L_ROW, L_BTN, L_BASE, L_INFO, L_DETAIL, L_DETAIL_LV, PL.L_PV_DETAIL, PL.L_HIPER, PL.L_HROW,
          PL.L_BTN_ROLE, PL.L_ROLE_OPT, PL.L_SSLIST, PL.L_LISTBG, 2525671790}
      -- the plate_pages host block's added layers too (band, slant, tag, bars, line, chart, numbers)
      if type(EVT_PPG) == "table" and type(EVT_PPG.HOST_LAYERS) == "table" then
        for _, l in ipairs(EVT_PPG.HOST_LAYERS) do
          watch[#watch + 1] = l
        end
      end
      for _, l in ipairs(watch) do
        if l ~= nil and funcLuaMenuCommand(@crc:CMND_IS_EXIST_LAYER@, l) == true and funcLuaMenuCommand(@crc:CMND_IS_OPEN_LAYER@, l, 0) == true then
          open[#open + 1] = string.format("%08X%s", l, funcLuaMenuCommand(@crc:CMND_IS_LOADING_LAYER@, l) == true and "(loading)" or "")
        end
      end
      local okc, cing = pcall(funcLuaCommand, C.CLOSING_MENU, EVT_MENU)
      local okd, cd = pcall(funcLuaCommand, C.CLOSED_MENU, EVT_MENU)
      -- one string (the loader's lua log keeps only the first few values)
      pcall(funcLuaCommand, C.EVT_LOG, string.format("skill_slots close watch %d closing %s closed %s action %s back %s open [%s]",
        PL.closeLog, tostring(cing), tostring(cd), evt_co ~= nil and coroutine.status(evt_co) or "none",
        tostring(evt_back_frames), table.concat(open, " ")))
    end
  end
  -- diagnostic (2026-10-06): the back key seen by this screen while OnBack is not reached (once per press)
  local okk, bk = pcall(PL.Key, PL.K_BACK)
  local down = okk and bk == true
  if down and not evt_back_seen then
    pcall(funcLuaCommand, C.EVT_LOG, "skill_slots", "back key seen", "action",
      evt_co ~= nil and coroutine.status(evt_co) or "none", "back frames", tostring(evt_back_frames),
      "pv open", tostring(evt_pv_open))
  end
  evt_back_seen = down
end

-- ---- actions -----------------------------------------------------------------------------------------------

local function EVT_Message(text)
  if PL.MxUnblack ~= nil then
    PL.MxUnblack()                               -- 2026-10-13: a message never opens under the pre-scene black
  end
  funcLuaCommand(C.MSG_OPEN, text, 0, 0, 0, 0, 0, false)
  while funcLuaCommand(C.MSG_BUSY) do
    coroutine.yield()
  end
  while not funcLuaCommand(C.MSG_DONE) do
    coroutine.yield()
  end
end

function EVT_AfterChange()
  EVT_SyncBoard()
  EVT_RefreshRows()
  UpdateCharaStatus()
  UpdateEquipItemInfo()
end

-- ---- board commit (try 10: vr-loader commands, handle based; try 18: forced layout) ---------------------------
-- status 1 = done and verified by the loader; we also re-read the slot. Other codes: 0 refused by 0xE7D310 (no free
-- copy / move already on another active slot), 2 read-back mismatch, -1 bad args, -2 data not ready, -3 slot
-- closed and no definition piece, -4 exception, -5 no record, -6 CLEAR would close the piece (slot without a native
-- move; try 16 closed Byron's pieces 21/23 that way), -7 no 9-piece board (LAYOUT).
local function EVT_BoardPut(bslot, skill, inv)
  if bslot == nil or inv == nil or inv == 0 then
    return false, "no slot / item"
  end
  local st = EVT_Call(C.EVT_PLACE, n, inv, bslot)
  return st == 1 and EVT_BoardSkill(bslot) == skill, st
end

-- keep_open: a slot without a native move ends open and EMPTY instead of being refused (-6); only used right before
-- a PLACE on the same slot, or for the Hiper slot 8 which must stay open.
local function EVT_BoardClear(bslot, keep_open)
  if bslot == nil then
    return nil
  end
  local st = EVT_Call(C.EVT_CLEAR, n, bslot, keep_open and 1 or 0)
  return st
end

-- make skill_list[slot] == skill (CMND_SET_SKILL swaps with the move's old position when it was in the list)
local function EVT_ListPut(slot, skill)
  if skill == 0 or slot == nil then
    return
  end
  local pos = funcLuaCommand(C.SKILL_POS, n, skill)
  if pos ~= slot then
    funcLuaCommand(C.SET_SKILL, n, skill, slot)
  end
end

local function EVT_Log(...)
  EVT_Call(C.EVT_LOG, "skill_slots", ...)
end

-- Team aura slots of the team dock being edited (save teamInfoList.auraSkillSlotInfoList, 4 x {charaStHdl, skillId}),
-- as the retail aura screen equip_aura_skill_menu reads (CMND_GET_TEAM_SET_INFO(dockNo, dockType, 15, i)) and writes
-- (0x59CAEAD5(dockNo, dockType, 6, i, chara, skill) -> ok, previous index). dockNo/dockType = n3/n17, the values the
-- team dock hands to this screen (params 3357163798 / 4081600465, the same ones it gives equip_menu).
local function EVT_AuraFind()
  local mine, free, mine_skill = -1, -1, 0
  for i = 0, EVT_TEAM_AURA_SLOTS - 1 do
    local ok, ch, sk = funcLuaCommand(C.TEAM_INFO, n3, n17, 15, i)
    if ok then
      if EVT_U32(ch) == EVT_U32(n) and mine < 0 then
        mine, mine_skill = i, EVT_U32(sk)
      elseif (ch == nil or ch == 0) and free < 0 then
        free = i
      end
    end
  end
  return mine, free, mine_skill
end

-- Put `skill` (0 = remove) into this player's team aura slot; returns ok, text (for the Hiper message)
local function EVT_TeamAuraPut(skill)
  if n3 == nil then
    return false, "no team"
  end
  local mine, free = EVT_AuraFind()
  local slot = mine >= 0 and mine or free
  if slot < 0 then
    return skill == 0, "team aura full (4 of 4)"
  end
  local ok, prev
  if skill == 0 then
    ok, prev = funcLuaCommand(C.TEAM_AURA_SET, n3, n17, 6, slot, 0, 0)
  else
    ok, prev = funcLuaCommand(C.TEAM_AURA_SET, n3, n17, 6, slot, n, skill)
  end
  local _, _, now = EVT_AuraFind()
  local good = (skill == 0 and now == 0) or (skill ~= 0 and now == skill)
  return good, string.format("team aura slot %d %s (team %s/%s, game %s)", slot + 1, good and "OK" or "NO",
    tostring(n3), tostring(n17), tostring(ok))
end

local function EVT_Report(text, row)
  EVT_Log("report", row, (string.gsub(text, "\n", " / ")))
end

local function EVT_Snapshot()
  local t = {}
  for b = 0, 8 do
    t[b] = EVT_BoardSkill(b)
  end
  return t
end

-- "cambios: 2 A->B, 5 C->D" for every board slot (1-based) that changed
local function EVT_Diff(before, after)
  local out = {}
  for b = 0, 8 do
    if before[b] ~= after[b] then
      out[#out + 1] = string.format("%d %s->%s", b + 1, EVT_Name(before[b]), EVT_Name(after[b]))
    end
  end
  if #out == 0 then
    return "no change on the board"
  end
  return "board: " .. table.concat(out, ", ")
end

-- Real invSkill handle for `skill`: a handle in `pool` (items just taken off the board), the handle already on one of
-- this player's board slots (swap, restore), else CMND_ADD_ITEM_ONLY(skill, 1) (the story's way; moves stack, one
-- inventory record per move) - the caller removes the extra copy with CMND_DELETE_ITEM right after. The picker
-- already refuses moves without a free copy (codigo 5).
local function EVT_HandleFor(skill, pool)
  if pool ~= nil and pool[skill] ~= nil and pool[skill] ~= 0 then
    return pool[skill], false
  end
  for b = 0, 8 do
    local id, h = EVT_BoardSkill(b)
    if id == skill and h ~= nil and h ~= 0 then
      return h, false
    end
  end
  local h = funcLuaCommand(C.ADD_ITEM, skill, 1, false)
  if h ~= nil and h ~= 0 then
    return h, true
  end
  return 0, false
end

-- Handle for the Hiper slot 8. A special that also sits on a normal slot 0-5 (the game keeps hyperpowers on slot 5
-- for branch-1 players) has no free copy, so 0xE7D310 would refuse it: one extra copy is added and KEPT (the move is
-- then equipped twice, once per branch, as retail boards with both branches open do). Slots 6/7 are freed by the
-- layout, so their handle is reused.
local function EVT_HiperHandle(skill)
  for b = 0, 8 do
    local id, h = EVT_BoardSkill(b)
    if id == skill and h ~= nil and h ~= 0 then
      if b >= 6 then
        return h, false
      end
      local h2 = funcLuaCommand(C.ADD_ITEM, skill, 1, false)
      if h2 ~= nil and h2 ~= 0 then
        return h2, false
      end
      return h, false
    end
  end
  return EVT_HandleFor(skill)
end

EVT_TeamAuraOf = function() return EVT_TeamAuraGet() end
function EVT_TeamAuraGet()
  if n3 == nil then
    return 0
  end
  local _, _, sk = EVT_AuraFind()
  return sk
end

-- The board mirrors the match list: board slot k (0-5) gets skill_list[k] for every unlocked row. Slots to change
-- are cleared first (a move sits on the board only once), then filled (2 passes, so a native move that came back on
-- one slot can be replaced before it is needed on another). A move that cannot be placed stays in the list only (the
-- match rebuilds the list from the board: it is lost there, logged «sync slot … NO»); the slot gets its old move back
-- when possible. Empty list positions take the board move. Called after every edit of the player (equip, reset,
-- remove, a player set loaded).
function EVT_SyncBoard()
  if n == nil or n == 0 or EVT_IsPrime() or PL.readonly then
    return true
  end
  local want, cur, curh, todo = {}, {}, {}, {}
  for k = 0, EVT_NORMAL_NUM - 1 do
    cur[k], curh[k] = EVT_BoardSkill(k)
    if not EVT_IsLocked(k + 1) then
      local l = EVT_ListSkill(k)
      if l ~= 0 then
        want[k] = l
      end
    end
  end
  for k = 0, EVT_NORMAL_NUM - 1 do
    local need = want[k] ~= nil and want[k] ~= cur[k]
    if not need and want[k] == nil and cur[k] ~= 0 and not EVT_IsLocked(k + 1) then
      for j, s in pairs(want) do   -- this slot holds a move another row wants
        if j ~= k and s == cur[k] then
          need = true
        end
      end
    end
    if need then
      todo[#todo + 1] = k
    end
  end
  local all_ok = true
  if #todo > 0 then
    local pool = {}
    for _, k in ipairs(todo) do
      if cur[k] ~= 0 and curh[k] ~= 0 then
        pool[cur[k]] = curh[k]
      end
      EVT_BoardClear(k, true)
    end
    for pass = 1, 2 do
      for _, k in ipairs(todo) do
        local s = want[k]
        if s ~= nil and EVT_BoardSkill(k) ~= s then
          local h, added = EVT_HandleFor(s, pool)
          local ok, st = EVT_BoardPut(k, s, h)
          if added then
            funcLuaCommand(C.DEL_ITEM, s, 1)
          end
          if pass == 2 then
            EVT_Log("sync slot", k, EVT_Name(s), ok and "OK" or "NO", "status", st)
          end
        end
      end
    end
    for _, k in ipairs(todo) do
      local now = EVT_BoardSkill(k)
      if want[k] ~= nil and now ~= want[k] then
        all_ok = false
        if now == 0 and cur[k] ~= 0 then    -- could not place: old move back if it is not on the board elsewhere
          local h, added = EVT_HandleFor(cur[k], pool)
          EVT_BoardPut(k, cur[k], h)
          if added then
            funcLuaCommand(C.DEL_ITEM, cur[k], 1)
          end
        end
      end
    end
  end
  for k = 0, EVT_NORMAL_NUM - 1 do
    if not EVT_IsLocked(k + 1) and EVT_ListSkill(k) == 0 then
      local b = EVT_BoardSkill(k)
      if b ~= 0 and not EVT_Active(b) and not EVT_IsSpecial(b) then
        EVT_ListPut(k, b)
      end
    end
  end
  return all_ok
end

-- Put `skill` on `row`. Normal rows: the match list first (CMND_SET_SKILL; it swaps when the move is already at
-- another position), then the board mirrors it (EVT_SyncBoard). Hiper row: board slot 8 (the loader opens the piece
-- if needed) + the team aura slot, never the match list.
function EVT_Equip(row, skill, inv_hint, cur)
  local before = EVT_Snapshot()
  local msg
  local ok_all
  if row == 0 then
    local ok_board, st = false, "no handle"
    do                                               -- board slot 8 (Character Reforged's board commands)
      local h, added = EVT_HiperHandle(skill)
      local h_item = (h ~= 0) and EVT_U32(funcLuaCommand(C.INV_ITEM, h, 0)) or 0
      if h ~= 0 and h_item == skill then
        ok_board, st = EVT_BoardPut(EVT_HIPER_SLOT, skill, h)
      end
      if added then
        funcLuaCommand(C.DEL_ITEM, skill, 1)        -- undo the extra copy made to obtain the handle
      end
    end
    msg = string.format("%s: board %s (slot %d, handle %X, state %s)", EVT_Name(skill), ok_board and "OK" or "NO",
      EVT_HIPER_SLOT + 1, EVT_U32(h), tostring(st))
    ok_all = ok_board
    if EVT_SPECIAL_TEAM_AURA then
      local okA, txt = EVT_TeamAuraPut(skill)
      msg = msg .. ", " .. txt
      ok_all = ok_all or okA
    end
  else
    local pos = EVT_ListPos(row)
    EVT_ListPut(pos, skill)                          -- swaps inside the list when the move was at another position
    local ok_list = EVT_ListSkill(pos) == skill
    local ok_board = EVT_SyncBoard()
    msg = string.format("%s: list position %d %s, board %s", EVT_Name(skill), pos + 1, ok_list and "OK" or "NO",
      ok_board and "OK" or "unchanged (the list rules)")
    ok_all = ok_list
    if not ok_board then
      EVT_Log("equip row", row, EVT_Name(skill), "board not mirrored")
    end
  end
  msg = msg .. ".\n" .. EVT_Diff(before, EVT_Snapshot())
  if not ok_all then
    EVT_Log("equip failed", row, (string.gsub(msg, "\n", " / ")))
    funcLuaCommand(C.SE, SE_NG)                    -- 2026-09-28: error sound only, details in loader.log
  else
    EVT_Report(msg, row)
  end
end

local function EVT_CurrentWithInv()
  local cur = {inv = {}}
  for r = 0, EVT_ROW_NUM - 1 do
    cur[r] = EVT_Skill(r)
    local b, h = EVT_BoardSkill(EVT_BoardSlot(r))
    cur.inv[r] = (b == cur[r]) and h or 0
  end
  return cur
end

-- Opens the game's hissatsu list (ability_list_menu: tabs / filter / sort) in "pick" mode.
-- Mode S = special row (only category-8 moves accepted), N = normal rows (category-8 moves refused).
-- Moves on other normal rows stay selectable (swap) and are tagged "(ranura N)".
-- Put the focus frame and the arrow cursor back on `row` (0xCE987192 = focused instance of an instanced layer,
-- 0x1246829F = focused index of a list layer; try 11b had only the list one: the arrow moved, the frame stayed on row 0).
function EVT_FocusRow(row)
  if row == nil or row < 0 or row >= EVT_ROW_NUM then
    return
  end
  local before = funcLuaMenuCommand(C.FOCUS_IDX, L_ROW)
  funcLuaMenuCommand(3466097042, L_ROW, row)   -- set the focused instance (focus frame); retail LISTVIEW.SetupInitFocus
  -- try 14 also called 306610847 (list index): the frame then landed on row/2 -> dropped
  EVT_Call(@crc:CMND_EVT_LOG@, "skill_slots", "focus", row, "before", before, "after",
    funcLuaMenuCommand(C.FOCUS_IDX, L_ROW))
  evt_cursor_idx = row
  funcLuaMenuCommand(C.CURSOR_LOC, L_ROW, 3313461902 --[[cursor]], row, EVT_ROW_NUM + 1)
  -- 2026-10-13 (owner's video: after the miximax scene the cursor sat on the Hiper row with an empty detail panel and
  -- Left / Right did nothing): the focus is the row list again, whatever focus event (a button's) came in between;
  -- the caller's UpdateEquipItemInfo / EVT_AfterChange then draws the row's panel
  n14 = L_ROW
  if PL.fs_wait ~= nil then
    PL.fs_wait = PL.FS_WINDOW
  end
end

function EVT_PickCoroutine(row)
  if EVT_IsPrime() then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  local cur = EVT_CurrentWithInv()
  P_Set(EVT_KEY_PICK, row == 0 and 2 or 1)
  for k = 1, EVT_ROW_NUM - 1 do
    P_Set(EVT_KEY_USED[k], (k ~= row and cur[k] ~= 0) and cur[k] or 0)
  end
  for _, key in ipairs({EVT_KEY_RESULT, EVT_KEY_INV, EVT_KEY_DBG_INIT, EVT_KEY_DBG_ENTER, EVT_KEY_DBG_CODE, EVT_KEY_DBG_BITS}) do
    VRFW_Param.Clear(key)
  end
  for _, key in ipairs(PL.LIST_KEYS) do            -- no stale six-sense / board filter tabs (2026-09-24)
    VRFW_Param.Clear(key)
  end
  P_Set(3357163798, n3)                          -- dock number, as the team dock sets it for this list
  -- no SE_OK: the row's own decide sound already plays (it sounded twice)
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_CURSOR, 0, false)
  -- 3466097042 stores the focus the layer gets when it is (re)opened/resumed, not the current one (log try 15:
  -- set after the resume it only took effect at the NEXT resume = the previous edited row). Store it before suspending.
  funcLuaMenuCommand(3466097042, L_ROW, row)
  funcLuaMenuCommand(C.MENU_SUSPEND, EVT_MENU)
  funcLuaCommand(C.OPEN_MENU, EVT_PICK_MENU, EVT_PICK_MENU)
  coroutine.yield()
  while funcLuaMenuCommand(C.EXIST_MENU, EVT_PICK_MENU) do
    coroutine.yield()
  end
  -- 2026-09-30 (Nacho: «Crear miximax» showed this page again, froze, then the bank): with «Crear miximax» picked the
  -- screen stays suspended and PL.MxBankPick opens the partner bank at once (one transition, as from here to the
  -- Hiper picker); the screen resumes when the bank closes (PL.MxResumeDirect on every other way out)
  if PL.MxDirectPick ~= nil and PL.MxDirectPick(row) then
    PL.mx_direct = true
  else
    funcLuaMenuCommand(C.MENU_RESUME, EVT_MENU)
    coroutine.yield()
    EVT_FocusRow(row)                            -- resume puts the focus back on row 0 (Hiper)
  end
  VRFW_Param.Clear(EVT_KEY_PICK)
  for k = 1, EVT_ROW_NUM - 1 do
    VRFW_Param.Clear(EVT_KEY_USED[k])
  end
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_CURSOR, 0, true)
  local function take(key)
    if VRFW_Param.Has(key) then
      local v = VRFW_Param.Get(key)
      VRFW_Param.Clear(key)
      return v
    end
    return nil
  end
  local skill = EVT_U32(take(EVT_KEY_RESULT))
  local inv = EVT_U32(take(EVT_KEY_INV))
  take(EVT_KEY_DBG_INIT)   -- the picker's debug keys: cleared, not read
  take(EVT_KEY_DBG_ENTER)
  take(EVT_KEY_DBG_CODE)
  take(EVT_KEY_DBG_BITS)
  if skill ~= 0 and skill ~= cur[row] then
    if (row == 0) ~= EVT_IsSpecial(skill) then   -- the picker already refuses these
      funcLuaCommand(C.SE, SE_NG)                  -- 2026-09-28: error sound only
      EVT_Log("pick refused", row, EVT_Name(skill), "special row mismatch")
    else
      -- no SE here: the list already played its decide sound on confirm (it sounded twice)
      local ok, err = pcall(EVT_Equip, row, skill, inv, cur)
      if not ok then
        EVT_Log("equip error", row, tostring(err))   -- 2026-09-28: no text on screen, error sound only
        funcLuaCommand(C.SE, SE_NG)
      end
    end
  end
  if PL.mx_direct then                           -- never leave the screen suspended (error / refused paths)
    PL.MxResumeDirect()
  end
  EVT_FocusRow(row)
  EVT_AfterChange()
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
end

-- Y «Eliminar» (2026-10-06, user: Y ALWAYS deletes, it never restores; X «Restablecer» = EVT_ResetCoroutine at the end
-- of this file). CMND_CHARACTERREFORGED_BOARD_CLEAR keepOpen 3 takes the placed item AND the slot's native
-- item off, the piece stays open and EMPTY. Hiper row: board slot 8 + the team aura slot emptied. Normal rows: the
-- board slot and the match position emptied (the native move does not come back). Nothing on the row: error sound.
-- (Before 2026-10-06 keepOpen 1 brought the native move back, so «Eliminar» sometimes restored the default.)
-- (literal 3, no PL field: a new main-chunk constant here would shift the RK index of later table constructors)
function EVT_RestoreCoroutine(row)
  if EVT_IsPrime() then
    funcLuaCommand(C.SE, SE_NG)
    return
  end
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, false)
  if row == 0 then
    local before = EVT_Snapshot()
    local old = EVT_Skill(0)
    local r = EVT_Call(C.EVT_CLEAR, n, EVT_HIPER_SLOT, 3 --[[keepOpen 3: everything off]])
    local okA, txt = EVT_TeamAuraPut(0)
    funcLuaCommand(C.SE, old ~= 0 and SE_REMOVE or SE_NG)
    EVT_Report(string.format("Delete Hiper: %s, slot %d (state %s), %s.\n%s", EVT_Name(old), EVT_HIPER_SLOT + 1,
      tostring(r), txt, EVT_Diff(before, EVT_Snapshot())), 0)
  else
    local before = EVT_Snapshot()
    local bslot, pos = EVT_BoardSlot(row), EVT_ListPos(row)
    local old = EVT_Skill(row)
    local r = EVT_Call(C.EVT_CLEAR, n, bslot, 3 --[[keepOpen 3: everything off]])
    if EVT_ListSkill(pos) ~= 0 then
      funcLuaCommand(C.REMOVE_SKILL, n, pos)       -- the match position emptied too
    end
    local now = EVT_Skill(row)
    funcLuaCommand(C.SE, old ~= 0 and SE_REMOVE or SE_NG)
    EVT_Report(string.format("Delete slot %d: %s -> %s (state %s).\n%s", bslot + 1, EVT_Name(old), EVT_Name(now),
      tostring(r), EVT_Diff(before, EVT_Snapshot())), row)
  end
  EVT_AfterChange()
  funcLuaMenuCommand(C.MENU_ACTIVE, EVT_MENU, true)
end

-- ---- the shared list panel (once the «Pasivas de la rama» window) and the custom passive --------------------------
-- The passive texts of the list panel (PL.List) and of the custom passive: CMND_GET_PASSIVE_SKILL_INFO (3 = stat type,
-- 1 = value), the retail status passive titles ("VALUE" template) and CMND_GET_TEAM_PASSIVE_INFO for team passives.
-- No board piece is read (the «Pasivas de la rama» window, removed 2026-10-12, read Inazuma Fantasy's board).
local EVT_PV = {
  PASSIVE = @crc:CMND_GET_PASSIVE_SKILL_INFO@,        -- CMND_GET_PASSIVE_SKILL_INFO (kind, id[, i])
  TEAM_PASSIVE = @crc:CMND_GET_TEAM_PASSIVE_INFO@,   -- CMND_GET_TEAM_PASSIVE_INFO (id, 0) -> ok, text
  TEXT_VALUE = 910683996,      -- (textId or string, "VALUE", value, ...) -> string
}
local EVT_STAT_TITLE = {[0] = 3905596903, 1084668705, 1047492482, 2352972234, 2604963209, 614355554, 2718198818}

local function EVT_PV_Call(cmd, ...)
  local r = {pcall(funcLuaCommand, cmd, ...)}
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2)
end

-- tries 25-26: the window is a read-only PANEL (clone of the retail team-passive list window soccer11_21, one centred
-- column of 9 retail passive rows, a retail full-screen black background behind; research/scripts/ss2_build.py
-- section 7). Only UNLOCKED entries (base path + branch 1). Stat pieces of the same stat are summed into one row, the
-- same passive twice is one row "xN". The unlock level is the row's right-aligned number node (the retail "locked
-- passive level" number, moved to the right edge in our row clone). Up/Down scroll, Back/Enter close.
local L_PV_PANEL = 2524402806
local L_PV_ROW = 811691761
local L_BLACKBG = 3801549073
local L_BTN_ICON = 3196164535      -- the old «Pasivas de la rama» button: removed 2026-10-12, kept hidden (setting layer)
local L_BTN_SS = 605517988          -- "Pasiva personalizada" button
local EVT_PV_ROWS = 9                              -- panel rows = row-layer instances 0..8
local EVT_BG_COUNT = 2                             -- try 28: 2 stacked cmn02_01_blackbg dims (4 were too black)
local EVT_ROW_ICON_SS, EVT_ROW_ICON_PV = 9, 10     -- row-layer instances drawn as the icons of the two square buttons
local EVT_POS_VISIBLE = 2158717427                 -- (layer, node, bool, idx): show / hide a locator subtree
local EVT_PRIORITY = @crc:CMND_SET_DRAW_PRIORITY@                    -- (layer, idx, prio, bool)
local EVT_PRIM_INDEX, EVT_PRIM_NUM, EVT_PRIM_VISIBLE = @crc:CMND_SEARCH_PRIM_INDEX@, 3609943765, 1233047821
local EVT_NUM_LEVEL = 2330185550                   -- num_passive_lock01 (number node of the row)
local EVT_MENU_CTRL = 1332654303
local EVT_CMD_BACK, EVT_CMD_ENTER, EVT_CMD_UP, EVT_CMD_DOWN = 3011112225, 1981080283, 1197218715, 3259546669
local EVT_TEX_SOCCER11_20 = 4021797290             -- #/menu/00_soccer/soccer11/soccer11_20/soccer11_20.g4tx
local EVT_TEX_ICON_COMMON = 2320109963             -- #/menu/200_icon/15_icon_common/icon_common.g4tx
local EVT_TEX_TEAMBUFF = 2301895383                -- #/menu/200_icon/08_icon_teambuff/<LG>/icon_teambuff.g4tx
local EVT_SS_CATEGORY = 200                        -- ability list category filter of six-sense items (board picker)
local evt_pv_open = false
local evt_icon_frames = 0                          -- try 28: frames left to re-apply the static button icons

-- ---- entries ----------------------------------------------------------------------------------------------------
local function EVT_PV_TeamText(id, eff, count)
  local okE, textId = EVT_PV_Call(@crc:CMND_GET_PASSIVE_EFFECT_INFO@, eff, 0)
  local t
  if okE == true and textId ~= nil then
    t = EVT_PV_Call(720417636, textId)
    t = EVT_PV_Call(@crc:CMND_TEXT_CONVERT@, t, 0, 1140121255, "[CPASSIVE01]") or t
    t = EVT_PV_Call(@crc:CMND_TEXT_CONVERT@, t, 0, 2769827636, "") or t
    local value = EVT_PV_Call(EVT_PV.PASSIVE, 1, id, 0)
    local okc, digits, disp = pcall(MENU_DEF.CalcPassiveEffectNeedDecimalDigitAndDisplayValue, eff, value)
    if okc and disp ~= nil then
      t = EVT_PV_Call(EVT_PV.TEXT_VALUE, t, "VALUE", disp, 0, 2, false, digits) or t
    end
  end
  if type(t) ~= "string" or t == "" then
    t = string.format("%08X", EVT_U32(id))
  end
  t = string.gsub(t, "%s+", " ")
  return t                                         -- try 28: never cut (long texts wrap to 2 lines)
end

-- ---- rows -----------------------------------------------------------------------------------------------------------
local function EVT_Row_Reset(k)
  local L = L_PV_ROW
  for _, pos in ipairs({1559050359 --[[_pos_icon01]], 397052763, 3320080845 --[[_pos_icon02]], 3448691050 --[[_pos_build01]],
                        3453619769 --[[_pos_type01]], 2497436533 --[[_pos_position01]]}) do
    funcLuaMenuCommand(EVT_POS_VISIBLE, L, pos, false, k)
  end
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 2336867556 --[[_build_ef01]], false, k)
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 27565530 --[[_icon_inheritance01]], false, k)
end

local EVT_ALB_ICON_ON = {             -- GetAbilearBoardTeamPassiveIconTexture(eff, true): category -> icon_alb01_teambuffNN_on
  [2] = 3528670446, [3] = 3236336384, [4] = 2019226725, [12] = 3851275484, [27] = 1563536313, [22] = 1469018683,
  [16] = 4013102430, [18] = 4253465264, [11] = 1161485781, [10] = 3639469420, [19] = 1615954441, [21] = 1927556583,
  [29] = 3394783874, [30] = 2453363412, [0] = 713506225, [1] = 271517931, [8] = 2828234638, [9] = 3123101792,
  [17] = 43689733, [20] = 2672664508, [23] = 670169305, [24] = 893671223, [25] = 2381852754, [26] = 3583713284,
  [28] = 1831290721, [37] = 760160603, [6] = 2515748414, [13] = 2269571536, [31] = 136609415, [32] = 2962758114,
  [38] = 3908766132
}
local EVT_TEX_ABILEAR = 3315424508                -- #/menu/200_icon/18_icon_abilearboard/<LG>/icon_abilearboard.g4tx
local EVT_ICON_SIXTH = 487860482                   -- icon_abilear_sixth01 (retail board six-sense piece, icon_common)

-- try 27: a row-layer instance used only as a STATIC icon on top of a square button: no Active anime (set up in
-- OnSetupLayer), no row base / overlays / build band, only the icon node with one sprite.
local function EVT_ButtonIcon(k, tex, sprite)
  local L = L_PV_ROW
  EVT_Row_Reset(k)
  for _, mesh in ipairs({3143733656 --[[_passive_base01]], 2061463723 --[[_passive_base01_ol01]],
                         3822461201 --[[_passive_base01_ol02]], 3877027080, 2336867556 --[[_build_ef01]],
                         2299070650 --[[_icon_teambuff_tgt_dmy01]], 27565530 --[[_icon_inheritance01]],
                         22927936, 97947090, 106573771,
                         2673049201, 3895971012, 918292019,
                         2203859798, 3016059238, 744788874}) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L, mesh, false, k)
  end
  funcLuaMenuCommand(C.TEXT, L, 1868134834 --[[_text_passive01]], "", k)
  -- 2026-09-24: showing _pos_icon01 re-shows ALL its children (the white 48 x 32 dummy _icon_teambuff_tgt_dmy01 and the
  -- grey plate _teambuff_base01 = the "white squares" above the button icons): it was shown AFTER they were hidden.
  -- Now: locator first, then its unwanted meshes off again, then the icon on.
  funcLuaMenuCommand(EVT_POS_VISIBLE, L, 1559050359 --[[_pos_icon01]], true, k)
  for _, mesh in ipairs({3877027080, 2336867556 --[[_build_ef01]], 2299070650 --[[_icon_teambuff_tgt_dmy01]]}) do
    funcLuaMenuCommand(C.MESH_VISIBLE, L, mesh, false, k)
  end
  funcLuaMenuCommand(C.MESH_VISIBLE, L, 3165767436, true, k)
  funcLuaMenuCommand(C.SPRITE, L, tex, sprite, 3234721532 --[[icon_teambuff_dmy01]], 0, k)
end

-- equipped six-sense item -> its board icon (as the original board draws the piece), else the generic six-sense icon
local function EVT_SS_Icon(item)
  if item ~= 0 then
    local eff = EVT_PV_Call(EVT_PV.PASSIVE, 0, item)
    if eff ~= nil then
      local ok, cat = EVT_PV_Call(@crc:CMND_GET_PASSIVE_EFFECT_INFO@, eff, 2, 0)
      local spr = ok and EVT_ALB_ICON_ON[tonumber(cat) or -1] or nil
      if spr ~= nil then
        return EVT_TEX_ABILEAR, spr
      end
    end
  end
  return EVT_TEX_ICON_COMMON, EVT_ICON_SIXTH
end

-- ---- six sense ("Pasiva personalizada") ------------------------------------------------------------------------
-- equipped six sense: invHdl, itemId
local function EVT_SS_Get()
  local st, inv, item = EVT_PV_Call(@crc:CMND_CHARACTERREFORGED_SIX_SENSE@, n, 0, 0, -1)
  if st ~= 1 then
    return 0, 0
  end
  return EVT_U32(inv or 0), EVT_U32(item or 0)
end

-- the custom passive slot: locked while no mod declares its service (CMND_CHARACTERREFORGED_SIX_SENSE, Character
-- Reforged's scripts\board_slots.lua):
-- returns locked, needLevel, pieceIdx (no board piece is read)
local function EVT_SS_Lock()
  return not PL.HasService("six_sense"), 0, nil
end

-- the module Signature Passives (CMND_SIGNATUREPASSIVES_OWN_PASSIVE): the slot is the shown player's own passive and
-- cannot be changed; answers his passive id (0 = none), or nil while the module is off (a command nobody declares
-- answers a single false)
function PL.Signature()
  local ok, passive = pcall(funcLuaCommand, @crc:CMND_SIGNATUREPASSIVES_OWN_PASSIVE@, n)
  if ok and type(passive) == "number" then
    return EVT_U32(passive)
  end
  return nil
end

local function EVT_SS_ButtonRefresh()
  local _, item = EVT_SS_Get()
  item = PL.Signature() or item
  EVT_ButtonIcon(EVT_ROW_ICON_SS, EVT_SS_Icon(item))
  local locked = EVT_SS_Lock()
  funcLuaMenuCommand(C.LAYER_VISIBLE, L_PV_ROW, EVT_ROW_ICON_SS, not evt_pv_open)
  funcLuaMenuCommand(C.TEXT, L_BTN_SS, 950238781 --[[_text_btn01]], "", 0)
  funcLuaMenuCommand(C.TEXT, L_BTN_SS, 625330766 --[[_text_cmd01]], "", 0)
  return locked
end

-- info card while the six-sense button has the focus: equipped item (icon, name, description) or the lock level
local function EVT_SS_Info()
  local signature = PL.Signature()
  if signature ~= nil then                        -- read only: the own passive's detail, or nothing without one
    local shown = false
    if signature ~= 0 and PL.PassiveDetail ~= nil then
      local name = EVT_PV_Call(EVT_PV.PASSIVE, 2, signature)
      shown = pcall(PL.PassiveDetail, type(name) == "string" and name or "", "", signature)
    end
    SetVisibleEquipInfoWindow(false)
    if not shown then
      pcall(EVT_DetailHide)
    end
    funcLuaMenuCommand(C.TEXT, 3078308064 --[[mainmenu90_05_content_guide_line01]], 378156699 --[[_text_guide01]],
      PL.Txt(signature ~= 0 and PL.TX.SIG_GUIDE or PL.TX.SIG_NONE), 0)
    return
  end
  local _, item = EVT_SS_Get()
  local locked, need = EVT_SS_Lock()
  if item ~= 0 and PL.PassiveDetail ~= nil then
    local name = EVT_PV_Call(@crc:CMND_GET_ITEM_PARAM@, item, 0)
    local eff = EVT_PV_Call(EVT_PV.PASSIVE, 0, item)
    local desc = eff ~= nil and EVT_PV_TeamText(item, eff, 1) or ""
    if pcall(PL.PassiveDetail, type(name) == "string" and name or PL.Txt(PL.TX.PASSIVE), desc, item) then
      SetVisibleEquipInfoWindow(false)
      item = -1                                   -- shown in the panel: skip the card below
    end
  end
  if item == -1 then
  elseif item ~= 0 then
    SetVisibleEquipInfoWindow(true)
    funcLuaMenuCommand(C.ITEM_ICON, L_INFO, 0, 303536660 --[[_icon_item_dmy01]], 1875672568 --[[icon_item_dmy01]], item)
    funcLuaMenuCommand(C.ITEM_ICON, L_INFO, 0, 2334051246 --[[_icon_item_dmy02]], 4140117058 --[[icon_item_dmy02]], item)
    local name = EVT_PV_Call(@crc:CMND_GET_ITEM_PARAM@, item, 0)
    funcLuaMenuCommand(C.TEXT, L_INFO, 456522680 --[[_text_item01]], type(name) == "string" and name or PL.Txt(PL.TX.PASSIVE), 0)
    local eff = EVT_PV_Call(EVT_PV.PASSIVE, 0, item)
    local desc = eff ~= nil and EVT_PV_TeamText(item, eff, 1) or ""
    funcLuaMenuCommand(C.TEXT, L_INFO, 3138144965 --[[_text_parameter01]], desc, 0)
    funcLuaMenuCommand(C.MESH_VISIBLE, L_INFO, 2634282032 --[[_item_chr_base01]], false, 0)
    funcLuaMenuCommand(C.MESH_VISIBLE, L_INFO, 2787359195 --[[_item_chr_dmy01]], false, 0)
  else
    SetVisibleEquipInfoWindow(false)
  end
  local guide = PL.Txt(locked and PL.TX.LOADER or (item ~= 0 and PL.TX.SS_BTN_EQUIPPED or PL.TX.SS_BTN_GUIDE))
  funcLuaMenuCommand(C.TEXT, 3078308064 --[[mainmenu90_05_content_guide_line01]], 378156699 --[[_text_guide01]], guide, 0)
end

-- ---- pointer (mouse / VR free cursor; docs/game/ui/mouse-support.md §5, EVT_PointerNew) ---------------------------
-- Our polled lists (PL.List: the passive panel rows; PL.PopList / PL.SSList: the board picker's team08_02 rows; the
-- read-only «Pasivas de la rama» panel) get Lua zones each frame from the rows' global positions (4002164178, y up):
-- PL.PTR_PV = the passive row (soccer11_20 plate _passive_base01: x -414 .. +414, 92 high, centred on the origin),
-- PL.PTR_SS = the team08_02 row (ss2_build: x -98 .. +872, 72 high, centred). Only rows that show an entry get a zone,
-- plus a 40 px band above / below while the list scrolls that way. PL.PtrStep -> act ("pick" = the row under the
-- pointer was clicked, "moved" = hover / wheel / band moved the focus), first, sel, owns (P.Owns(): the Accept now
-- pressed is the pointer's, so the loops do not take CMD_ENTER / CMD_ENTER_CLICK as «choose the focused row»).
--@lib evt_menu_kit.lua#Pointer
PL.PTR_PV = {-414, 828, 92}
PL.PTR_SS = {-98, 970, 72}
function PL.PtrStart()
  PL.ptr = PL.ptr or EVT_PointerNew()
  pcall(PL.ptr.Reset)
  return PL.ptr
end
function PL.PtrZones(P, L, nrows, rect, first, total)
  P.Begin()
  local top, bottom = nil, nil
  for k = 0, nrows - 1 do
    if first + k < total then
      local ok, x, y = pcall(funcLuaMenuCommand, 4002164178, L, k)
      local split = type(PL.ptr_split) == "function" and PL.ptr_split(k) or nil
      if ok and type(x) == "number" and type(y) == "number" and split ~= nil then
        -- 2026-10-13: a split row (two halves of one entry): ids k (left) and k + 0.5 (right), PL.PtrStep
        for h, r in ipairs(split) do
          P.Rect(x + r[1], -y - r[3] / 2, r[2], r[3], h == 1 and k or k + 0.5)
        end
        local rx, ry = x + rect[1], -y - rect[3] / 2
        top = top or {rx, ry}
        bottom = {rx, ry + rect[3]}
      elseif ok and type(x) == "number" and type(y) == "number" then
        local rx, ry = x + rect[1], -y - rect[3] / 2
        P.Rect(rx, ry, rect[2], rect[3], k)
        top = top or {rx, ry}
        bottom = {rx, ry + rect[3]}
      end
    end
  end
  if top ~= nil and first > 0 then
    P.Rect(top[1], top[2] - 40, rect[2], 40, "up", -1)
  end
  if bottom ~= nil and first + nrows < total then
    P.Rect(bottom[1], bottom[2], rect[2], 40, "down", 1)
  end
  return P.Poll()
end
function PL.PtrStep(P, L, nrows, rect, first, sel, total)
  local ok, ev = pcall(PL.PtrZones, P, L, nrows, rect, first, total)
  if not ok or type(ev) ~= "table" then
    return nil, first, sel, false
  end
  local okO, owns = pcall(P.Owns)
  owns = okO and owns == true
  -- a split row's halves (PL.PtrZones): the right half's id is k + 0.5; the half goes to PL.vrm_half
  local function half(id)
    if type(id) == "number" and id % 1 ~= 0 then
      return math.floor(id), 1
    end
    if type(id) == "number" and PL.row_split ~= nil and PL.row_split[id] then
      return id, 0
    end
    return id, nil
  end
  local cid, ch = half(ev.click)
  local hid, hh = half(ev.hot)
  ev.click, ev.hot = cid, hid
  if ch ~= nil and ch ~= PL.vrm_half then
    PL.vrm_half = ch
    PL.ptr_resync = true                          -- PL.PopList redraws (keys of the clicked half) before acting
  end
  if hh ~= nil and hh ~= PL.vrm_half and ch == nil then
    PL.vrm_half = hh
    return "moved", first, first + hid, owns
  end
  if type(ev.click) == "number" and first + ev.click < total then
    return "pick", first, first + ev.click, owns
  end
  local d = ev.wheel or ev.edge
  if d ~= nil then
    local f2 = math.max(0, math.min(first + d, total - nrows))
    if f2 ~= first then
      if type(ev.hot) == "number" and f2 + ev.hot < total then
        sel = f2 + ev.hot
      else
        sel = math.max(f2, math.min(sel, f2 + nrows - 1))
      end
      return "moved", f2, sel, owns
    end
  end
  if ev.changed and type(ev.hot) == "number" and first + ev.hot ~= sel and first + ev.hot < total then
    return "moved", first, first + ev.hot, owns
  end
  return nil, first, sel, owns
end

local function EVT_OpenSixSense()
  if evt_co ~= nil then
    return
  end
  evt_co = coroutine.create(function()
    EVT_SS_PickCoroutine()
  end)
end

-- ---- bottom buttons (tries 24c-26) -----------------------------------------------------------------------------------
-- [ long "Tabla de habilidades original" ][ Pasiva personalizada ][ Pasivas de la rama ] inside the rows' column:
-- three layers (retail button layer with a 404 px skin, two 72 px layers; research/scripts/ss2_build.py section 6).
-- Focus: right/left between them (CMD_FCS_NEXT / CMD_FCS_BACK), up to the rows. The retail OnSetupLayer DISABLES
-- CMD_FCS_NEXT on the button layer (2559269762): re-enabled here. The icons are row-layer instances 9/10 on top.
local EVT_ENABLE_CMD = 2559269762
local EVT_CMD_FCS_NEXT = 2734193315

local EVT_PV_PrevSetupLayer = OnSetupLayer
function OnSetupLayer(a1, a2)
  if a1 == L_BTN_ICON then
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)  -- 2026-10-12 (owner): the «Pasivas de la rama» button is gone
    return
  elseif a1 == L_BTN_SS then
    funcLuaMenuCommand(C.TEXT, a1, 625330766 --[[_text_cmd01]], "", a2)
    funcLuaMenuCommand(C.TEXT, a1, 950238781 --[[_text_btn01]], "", a2)   -- no key glyph (no key is bound)
    funcLuaMenuCommand(@crc:CMND_SET_LAYER_ATTACH_LOCATOR_TRACE@, a1, a2, 3313461902 --[[cursor]], false)
    return
  elseif a1 == L_PV_PANEL then
    funcLuaMenuCommand(EVT_PRIORITY, a1, a2, 900, true)
    for _, pos in ipairs({3448691050, 1839509013, 1437140403, 2946906320,
                          2513278738, 214222504}) do
      funcLuaMenuCommand(EVT_POS_VISIBLE, a1, pos, false, a2)
    end
    funcLuaMenuCommand(C.MESH_VISIBLE, a1, 3926830396, false, a2)
    funcLuaMenuCommand(C.TEXT, a1, 355816102, "", a2)
    funcLuaMenuCommand(C.TEXT, a1, 59628764, "", a2)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  elseif a1 == L_BLACKBG then
    funcLuaMenuCommand(EVT_PRIORITY, a1, a2, 880, true)
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  elseif a1 == L_PV_ROW then
    if a2 == EVT_ROW_ICON_PV then                    -- the removed passive button's icon: never shown
      funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    elseif a2 == EVT_ROW_ICON_SS then                -- static icons: no Active anime (it animates the row band)
      funcLuaMenuCommand(EVT_PRIORITY, a1, a2, 560, true)
      EVT_ButtonIcon(a2, EVT_TEX_ICON_COMMON, EVT_ICON_SIXTH)
      funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, true)       -- EVT_SS_ButtonRefresh sets the equipped icon
    else
      funcLuaMenuCommand(@crc:CMND_PLAY_ANIME_TYPE@, a1, a2, 1286797620 --[[Active]], 0, 753088835 --[[Default]])
      funcLuaMenuCommand(EVT_PRIORITY, a1, a2, 901, true)
      funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    end
    return
  end
  EVT_PV_PrevSetupLayer(a1, a2)
  if a1 == L_BTN then
    funcLuaMenuCommand(EVT_ENABLE_CMD, a1, EVT_CMD_FCS_NEXT, true)       -- right -> the square buttons
  end
end

local EVT_PV_PrevOpenLayer = OnOpenLayer
function OnOpenLayer(a1, a2)
  if a1 == L_BTN_ICON then
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    return
  elseif a1 == L_BTN_SS then
    funcLuaMenuCommand(@crc:CMND_PLAY_ANIME_TYPE@, a1, a2, 2734777837 --[[Focus]], 2, 973515837 --[[button]])
    return
  elseif a1 == L_PV_PANEL or a1 == L_BLACKBG then
    funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, evt_pv_open)
    return
  elseif a1 == L_PV_ROW then
    if a2 < EVT_PV_ROWS then
      funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, evt_pv_open)
    elseif a2 == EVT_ROW_ICON_PV then
      funcLuaMenuCommand(C.LAYER_VISIBLE, a1, a2, false)
    else
      evt_icon_frames = 10                         -- try 28: the open resets mesh visibility; re-apply a few frames
    end
    return
  end
  EVT_PV_PrevOpenLayer(a1, a2)
end

local evt_focus_layer = nil
local EVT_PV_PrevChangeFocus = OnChangeFocus
function OnChangeFocus(a1, a2)
  evt_focus_layer = a1
  if a1 == L_BTN_SS then
    n14 = L_BTN                       -- the screen treats it like the bottom button (no row info, cursor off rows)
    UpdateEquipItemInfo()
    pcall(EVT_SS_Info)
    return
  end
  EVT_PV_PrevChangeFocus(a1, a2)
  if a1 == L_ROW or a1 == L_BTN then
    local guide = (a1 == L_ROW and EVT_IsPrime()) and PL.PRIME_GUIDE or EVT_GUIDE_TEXT   -- 2026-09-24 Prime
    funcLuaMenuCommand(C.TEXT, 3078308064 --[[mainmenu90_05_content_guide_line01]], 378156699 --[[_text_guide01]], PL.Txt(guide), 0)
  end
end

local EVT_PV_PrevDecide = OnDecideFocus
function OnDecideFocus(a1, a2)
  EVT_Call(C.EVT_LOG, "skill_slots", "decide", a1, a2, "row layer", L_ROW, "ss button", L_BTN_SS)   -- 2026-09-24 diag
  if a1 == L_BTN_SS then
    EVT_OpenSixSense()
    return
  end
  EVT_PV_PrevDecide(a1, a2)
end

-- "Eliminar" on the six-sense button takes the item off
local EVT_PV_PrevFunction = OnFunction
function OnFunction(a1, a2)
  if a1 == 4109882573 and evt_focus_layer == L_BTN_SS and evt_co == nil and PL.Signature() == nil then
    local _, item = EVT_SS_Get()
    if item ~= 0 then
      EVT_PV_Call(@crc:CMND_CHARACTERREFORGED_SIX_SENSE@, n, 1, 0, -1)
      funcLuaCommand(C.SE, SE_REMOVE)
      EVT_SS_ButtonRefresh()
      pcall(EVT_SS_Info)
    else
      funcLuaCommand(C.SE, SE_NG)
    end
    return
  end
  EVT_PV_PrevFunction(a1, a2)
end

-- the six-sense icon follows the shown player; try 28: after the icon instances open, their meshes are hidden again
-- for a few frames (the layer open restores the bind-pose visibility: grey _teambuff_base01, white dummy quads)
local evt_ss_shown = nil
local EVT_PV_PrevStep = Step
function Step()
  EVT_PV_PrevStep()
  if n ~= nil and n ~= evt_ss_shown and evt_co == nil then
    evt_ss_shown = n
    evt_icon_frames = math.max(evt_icon_frames, 3)
  end
  if evt_icon_frames > 0 and evt_co == nil and not evt_pv_open then
    evt_icon_frames = evt_icon_frames - 1
    if n ~= nil then
      pcall(EVT_SS_ButtonRefresh)
    end
  end
end
