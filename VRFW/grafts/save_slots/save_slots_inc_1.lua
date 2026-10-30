-- ================================================================================================================
-- EVT save slots (appended to title_menu_inc_1.04.32.00 by research/scripts/slot_build.py). The VR-Framework's slot
-- service (graft save_slots, mod vr_framework: a Lua patch of the INCLUDE'd title_menu_inc in its save\lua root).
-- EMPEZAR (title_menu, layer title00_04_gamestart) -> StartItemSelectMenuCoroutine calls VRFW_SS_BeforeGameStart()
-- after the button's OK animation (patch marked EVT above). It opens evt_save_slot_menu and then:
--   cancel ............ back to EMPEZAR
--   active slot ....... returns true: the retail code continues (fade, title_menu_2), nothing is reloaded
--                       (NOT for the locked slot: the menu never returns it and it is treated as cancel)
--   other slot ........ loader switch + reset flow (VRFW_SS_Switch); the title re-enters and opens the mode row
-- The locked slot (slot 1 by default) = the vanilla save, LOCKED while the slot service runs: the title may show it
-- (boot load), but the game can only be continued on another player slot (duplicate it there from the slot screen).
-- The player slots are the save part's layout (CMND_VRFW_SLOT_LAYOUT; config [save.slots] count).
-- Without the slot service (vr_framework.dll's save part off: CMND_EVT_LOADER_VERSION without the save_slots bit)
-- VRFW_SS_BeforeGameStart() returns true at once and EMPEZAR is exactly retail. A reserved slot (a mod's mode owns it:
-- CMND_VRFW_SLOT_RESERVED) is entered only while its owner's mode is enterable; its owner may hook the entry
-- (VRFW_SS_RESERVED_ENTER["<owner>"] = function(slot) ... end, from its own Lua patch of title_menu_inc).
-- This file is included by title_menu AND title_menu_2 (and the platform variants); only globals prefixed VRFW_SS_
-- are added.
-- ================================================================================================================

-- ---- vr-loader commands (API 1). Filled by slot_build.py from LOADER_CMDS. -------------
-- Loader absent / module off: unknown hash -> the call returns a single false.
local VRFW_SS_LOADER = {
  VERSION = @crc:CMND_EVT_LOADER_VERSION@,   -- () -> api (>= 1), modules bitmask (bit1 = value 2 = save_slots: the framework's slot service)
  GET_SLOT = @crc:CMND_VRFW_SLOT_ACTIVE@,        -- () -> active slot
  LAYOUT = @crc:CMND_VRFW_SLOT_LAYOUT@,          -- () -> playerCount, lockedSlot, active, slot1, slot2, ... (CMND_VRFW_SLOT_LAYOUT)
  SLOT_INFO = 1195222835,      -- (n) -> exists, chapter, ...
  RELOAD = @crc:CMND_VRFW_SLOT_RELOAD@,       -- (n) -> bool: name map -> slot n now, writes fenced until COMMIT/ABORT
  COMMIT = 4173545121,       -- () -> bool: fence off, slot remembered
  ABORT = @crc:CMND_VRFW_SLOT_ABORT@,         -- () -> bool: back to the previous slot, fence off
  STATE = 3534676964,         -- () -> 0 idle, 1 switching (fenced), -1 error
  BUSY = 1127104486,           -- () -> bool: a game save/load job is pending
  LOG = @crc:CMND_EVT_LOG@,                  -- (...) -> true: evt_loader\loader.log
  SLOT_RESERVED = @crc:CMND_VRFW_SLOT_RESERVED@, -- (n) -> reserved, ownerModId, enterable (CMND_VRFW_SLOT_RESERVED)
  REARM = 1609225498,         -- NOT in API 1 (proposed): reset the InitTitleState "loaded" guard
                                             -- [[ ]+0x69C8]+ = 0; only used by VRFW_SS_FLOW "reentry"
}
local VRFW_SS_LOCKED_SLOT = 1                 -- the vanilla save: never continued / switched to (VRFW_SS_Layout reads it)
-- "apply":   slot with data = LOAD_HEADER + LOAD_GAME_DATA + APPLY_LOADED_DATA here (frozen API 1 commands only),
--            then CMND_GAME_RESET re-enters the title (retail return-to-title path) and skips EMPEZAR.
-- "reentry": HeaderClear + ResetAllGameData + LOAD_HEADER, then CMND_GAME_RESET; the load itself
--            runs in InitTitleState as at boot. Needs a loader that re-arms the guard (REARM above, or inside RELOAD).
local VRFW_SS_FLOW = "apply"
local VRFW_SS_MAX_SLOT = 99   -- highest slot number (save engine MAX_SLOT); a slot that is not a player one is a reserved one
-- the owners' entry hooks (title VM): VRFW_SS_RESERVED_ENTER["<owner mod id>"] = function(slot) end
VRFW_SS_RESERVED_ENTER = VRFW_SS_RESERVED_ENTER or EVT_SS_RESERVED_ENTER or {}
EVT_SS_RESERVED_ENTER = VRFW_SS_RESERVED_ENTER   -- 1.x name: same object
local VRFW_SS_MENU = 3561559540
local VRFW_SS_KEY_RESULT = 2449975398
local VRFW_SS_WAIT_FRAMES = 3600     -- give up on a save job after ~60 s
-- texts: menu_text rows of the framework (research/mods/VRFW/text/rows/save_slots.toml), read when shown
-- (VRFW_SS_Text); the English literals are the fallback when a row is missing
local VRFW_SS_TXT = {
  BUSY = "The game is saving or loading. Try again in a few seconds.",
  REFUSED = "Could not switch to Slot %d.",
  LOAD_FAILED = "The data of Slot %d could not be loaded. The current slot is kept.",
  ID = {   -- row ids
    BUSY = 511273385,          -- crc32("evt_slot_switch_busy")
    REFUSED = 909275936,       -- crc32("evt_slot_switch_refused")
    LOAD_FAILED = 3641072355,  -- crc32("evt_slot_switch_load_failed")
  },
}
function VRFW_SS_Text(key)
  local ok, s = pcall(funcLuaCommand, @crc:CMND_TEXT_GET@, VRFW_SS_TXT.ID[key])
  if ok and type(s) == "string" and s ~= "" then
    return s
  end
  return VRFW_SS_TXT[key]
end
-- retail commands
local VRFW_SS_G = {
  LOAD_HEADER = 4179471494,       -- 0xF91DAC86
  IS_SAVE_WORKING = 1979970074,   -- 0x7603F21A
  LOAD_GAME_DATA = 2585060058,    -- 0x9A14E2DA (1 = AUTOSAVE)
  LOAD_FAILED = 3772572101,       -- 0xE0DCE1C5 (last save/load failed)
  APPLY = 3660094710,             -- 0xDA289CF6 ApplyLoadedData
  HEADER_CLEAR = 3960538079,      -- 0xEC1103DF
  RESET_ALL = 1481565076,         -- 0x584EE394 ResetAllGameData
  SKIP_PRESS_START = 937976662,   -- 0x37E86356 (true): TitleStart opens title_menu_2 directly on re-entry
  GAME_RESET = @crc:CMND_GAME_RESET@,        -- 0xE8491B82 CMND_GAME_RESET
  GET_GFLAG = @crc:CMND_GET_GLOBAL_BIT_FLAG@,          -- 0x381D0910 CMND_GET_GLOBAL_BIT_FLAG
  SET_GFLAG = @crc:CMND_SET_GLOBAL_BIT_FLAG@,         -- 0xC2373FF8 CMND_SET_GLOBAL_BIT_FLAG
  FLAG_AVATAR_DONE = 2113473044,  -- set by chara_edit_menu when the avatar is created; false -> TitleStart opens
                                  -- title_menu_first_run (avatar, template, opening) instead of the mode menu
  FADE = 609722083,               -- (1 out / 0 in, seconds)
  FADE_DONE = 2259183189,
  FADE_BUSY = 2736534827,
  PRE_RESET = 3015544382,         -- menu command BackToTitleTop runs before closing (meaning unknown)
  OPEN_MENU = @crc:CMND_OPEN_MENU_OBJECT@, EXIST_MENU = @crc:CMND_IS_EXIST_MENU_OBJECT@, CLOSE_MENU = @crc:CMND_CLOSE_MENU_OBJECT@,
  MENU_ACTIVE = 1558704558, FOCUS_ENABLE = @crc:CMND_SET_ENABLE_CTRL_FOCUS@, ANIME = @crc:CMND_PLAY_ANIME_TYPE@,
  MSG_OPEN = 2289627655, MSG_BUSY = 898725220, MSG_DONE = 682363669,
  SE = @crc:CMND_SND_PLAY_SE@,
  OPEN_LAYER = @crc:CMND_OPEN_LAYER@, CLOSE_LAYER = @crc:CMND_CLOSE_LAYER@,
}

local function VRFW_SS_Call(cmd, ...)
  local r = table.pack(pcall(funcLuaCommand, cmd, ...))
  if not r[1] then
    return nil
  end
  return table.unpack(r, 2, r.n)
end

local function VRFW_SS_Log(...)
  VRFW_SS_Call(VRFW_SS_LOADER.LOG, "save_slots", ...)
end

-- loader present, API >= 1, save_slots module enabled
function VRFW_SS_Available()
  local api, mods = VRFW_SS_Call(VRFW_SS_LOADER.VERSION)
  if type(api) ~= "number" or api < 1 or type(mods) ~= "number" then
    return false
  end
  return math.floor(mods / 2) % 2 == 1
end

-- the layout: k is a player slot (true) and the locked slot (0 = lock off); without the command: slots 1..3, slot 1
local function VRFW_SS_Layout(k)
  local t = table.pack(VRFW_SS_Call(VRFW_SS_LOADER.LAYOUT))
  if type(t[1]) ~= "number" or t[1] < 1 then
    return k >= 1 and k <= 3, VRFW_SS_LOCKED_SLOT
  end
  local player = false
  for i = 4, 3 + math.floor(t[1]) do
    if t[i] == k then
      player = true
    end
  end
  return player, type(t[2]) == "number" and math.floor(t[2]) or VRFW_SS_LOCKED_SLOT
end

-- slot k is a reserved slot of a mod: its owner (nil = not reserved / no owner) and whether its mode lets it be entered
-- (the save engine's reservation; the screen's reserved card uses the same rule)
local function VRFW_SS_Reserved(k)
  local r, owner, enterable = VRFW_SS_Call(VRFW_SS_LOADER.SLOT_RESERVED, k)
  if r ~= true or type(owner) ~= "string" or owner == "" then
    return nil, false
  end
  return owner, enterable == true
end

-- After a switch the title is re-entered; the first title menu that runs OnInit lifts the write fence (the loader
-- also lifts it by itself once the slot's data was applied, and the empty-slot path commits directly).
function VRFW_SS_CommitPending()
  if not VRFW_SS_Available() then
    return
  end
  if VRFW_SS_Call(VRFW_SS_LOADER.STATE) == 1 then
    local ok = VRFW_SS_Call(VRFW_SS_LOADER.COMMIT)
    VRFW_SS_Log("commit", ok == true)
  end
end
EVT_SS_CommitPending = VRFW_SS_CommitPending   -- 1.x name: same function

local function VRFW_SS_WaitSaveJob()
  local k = 0
  coroutine.yield()
  while funcLuaCommand(VRFW_SS_G.IS_SAVE_WORKING) do
    k = k + 1
    if k > VRFW_SS_WAIT_FRAMES then
      return false
    end
    coroutine.yield()
  end
  return true
end

local function VRFW_SS_Message(text)
  funcLuaCommand(VRFW_SS_G.MSG_OPEN, text, 0, 0, 0, 0, 0, false)
  while funcLuaCommand(VRFW_SS_G.MSG_BUSY) do
    coroutine.yield()
  end
  while not funcLuaCommand(VRFW_SS_G.MSG_DONE) do
    coroutine.yield()
  end
end

-- Every fade wait is bounded (VRFW_SS_FADE_FRAMES): a switch to a deleted reserved-slot save stopped
-- right after "switch" with the screen black and nothing else (a fade that never reported done); now the switch
-- goes on after the bound and a failure always fades back in.
local VRFW_SS_FADE_FRAMES = 240
local function VRFW_SS_FadeOut()
  funcLuaCommand(VRFW_SS_G.FADE, 1, 0.5)
  coroutine.yield()
  local k = 0
  while not funcLuaCommand(VRFW_SS_G.FADE_DONE) and k < VRFW_SS_FADE_FRAMES do
    k = k + 1
    coroutine.yield()
  end
  while funcLuaCommand(VRFW_SS_G.FADE_BUSY) and k < 2 * VRFW_SS_FADE_FRAMES do
    k = k + 1
    coroutine.yield()
  end
  if k >= VRFW_SS_FADE_FRAMES then
    VRFW_SS_Log("fade out: gave up waiting after", k, "frames")
  end
end

local function VRFW_SS_FadeIn()
  funcLuaCommand(VRFW_SS_G.FADE, 0, 0.3)
  coroutine.yield()
  local k = 0
  while funcLuaCommand(@crc:CMND_BRIGHT_IS_FADE@) and k < VRFW_SS_FADE_FRAMES do
    k = k + 1
    coroutine.yield()
  end
end

-- Switch to slot k (k ~= active). Returns false + message on failure (nothing changed); on success the title
-- scene is reset and this never returns.
function VRFW_SS_Switch(k, exists)
  if VRFW_SS_Call(VRFW_SS_LOADER.BUSY) == true then
    return false, VRFW_SS_Text("BUSY")
  end
  if VRFW_SS_Call(VRFW_SS_LOADER.RELOAD, k) ~= true then
    VRFW_SS_Log("reload refused", k)
    return false, string.format(VRFW_SS_Text("REFUSED"), k)
  end
  local owner = VRFW_SS_Reserved(k)
  local reserved = owner ~= nil
  if reserved then
    -- entered from this screen: the owner's hook (e.g. its "back" returns here)
    local hook = VRFW_SS_RESERVED_ENTER[owner]
    if type(hook) == "function" then
      local okh, err = pcall(hook, k)
      if not okh then VRFW_SS_Log("reserved enter hook of", owner, "failed:", tostring(err)) end
    end
  end
  -- the loader may just have found the slot empty although its card said otherwise (a save deleted behind the card): ask again, so an empty slot is started as a new game instead of loading nothing
  if exists then
    local now = VRFW_SS_Call(VRFW_SS_LOADER.SLOT_INFO, k)
    if now ~= true then
      VRFW_SS_Log("slot", k, "has no readable game any more: started as a new game")
      exists = false
    end
  end
  VRFW_SS_Log("switch", k, exists == true, VRFW_SS_FLOW)
  VRFW_SS_FadeOut()
  if exists and VRFW_SS_FLOW == "apply" then
    funcLuaCommand(VRFW_SS_G.LOAD_HEADER)
    local ok = VRFW_SS_WaitSaveJob()
    local started = ok and funcLuaCommand(VRFW_SS_G.LOAD_GAME_DATA, 1)
    ok = started and VRFW_SS_WaitSaveJob() and not funcLuaCommand(VRFW_SS_G.LOAD_FAILED)
    if not ok then
      VRFW_SS_Log("load failed", k)
      VRFW_SS_Call(VRFW_SS_LOADER.ABORT)
      funcLuaCommand(VRFW_SS_G.LOAD_HEADER)       -- the header object may now describe slot k: read ours again
      VRFW_SS_WaitSaveJob()
      VRFW_SS_FadeIn()
      return false, string.format(VRFW_SS_Text("LOAD_FAILED"), k)
    end
    funcLuaCommand(VRFW_SS_G.APPLY)
  elseif exists then
    -- "reentry": InitTitleState loads slot k when the title is entered again
    VRFW_SS_Call(VRFW_SS_LOADER.REARM)
    funcLuaCommand(VRFW_SS_G.HEADER_CLEAR)
    funcLuaCommand(VRFW_SS_G.RESET_ALL)
    funcLuaCommand(VRFW_SS_G.LOAD_HEADER)
    VRFW_SS_WaitSaveJob()
  else
    -- empty slot = new game (retail "Reiniciar datos" minus SaveHeader/Delete): no header -> InitNewGameData
    funcLuaCommand(VRFW_SS_G.HEADER_CLEAR)
    funcLuaCommand(VRFW_SS_G.RESET_ALL)
    -- The in-memory game was just wiped, so nothing of the previous slot can reach slot k any more. Lift the
    -- write fence now: with SKIP_PRESS_START the title never runs VRFW_SS_CommitPending before the new game's
    -- first autosave, and a fenced FileWriteAsync leaves the game on "Guardando..." forever.
    VRFW_SS_Log("commit (new game)", VRFW_SS_Call(VRFW_SS_LOADER.COMMIT) == true)
    -- First run like a fresh install: TitleStart only picks title_menu_first_run from the press-start title when the
    -- "avatar created" flag is off, so clear it (if the reset did not) and do NOT skip the press-start screen.
    if not reserved then            -- a reserved slot (a mod's mode) never runs the retail first-run flow
      local before = funcLuaCommand(VRFW_SS_G.GET_GFLAG, VRFW_SS_G.FLAG_AVATAR_DONE)
      funcLuaCommand(VRFW_SS_G.SET_GFLAG, VRFW_SS_G.FLAG_AVATAR_DONE, false)
      VRFW_SS_Log("first run", k, "avatar flag", before == true, funcLuaCommand(VRFW_SS_G.GET_GFLAG, VRFW_SS_G.FLAG_AVATAR_DONE) == true)
    end
  end
  funcLuaCommand(VRFW_SS_G.SKIP_PRESS_START, exists == true or reserved)
  VRFW_SS_Log("game reset", k)
  funcLuaMenuCommand(VRFW_SS_G.PRE_RESET)
  funcLuaCommand(VRFW_SS_G.CLOSE_MENU, n, true)
  funcLuaCommand(VRFW_SS_G.GAME_RESET)
  while true do
    coroutine.yield()
  end
end

-- Called by the patched StartItemSelectMenuCoroutine (inside that coroutine) after the EMPEZAR OK animation.
-- true = continue with the retail code; false = stay on EMPEZAR (its focus is already re-enabled).
function VRFW_SS_BeforeGameStart(gamestartLayer)
  if not VRFW_SS_Available() then
    return true
  end
  local active = VRFW_SS_Call(VRFW_SS_LOADER.GET_SLOT)
  if type(active) ~= "number" or active < 1 or active > VRFW_SS_MAX_SLOT then
    return true
  end
  funcLuaMenuCommand(VRFW_SS_G.MENU_ACTIVE, n, false)
  -- Attract/opening timer: title_main_2.00.16 SwitchCaseTitleInputWait adds the frame time to its local counter and
  -- plays the opening when it exceeds n17 while CMND_IS_OPEN_LAYER(title00_04_gamestart) is true; it resets the
  -- counter only on "any key" (not while a sub_window exists) or when that layer is closed. Close the layer while
  -- the slot screen (and its dialogs / keyboard) is up, so the counter stays 0; it is reopened on every way back.
  funcLuaMenuCommand(VRFW_SS_G.CLOSE_LAYER, gamestartLayer)
  local function Reopen()
    funcLuaMenuCommand(VRFW_SS_G.OPEN_LAYER, gamestartLayer)
  end
  VRFW_Param.Clear(VRFW_SS_KEY_RESULT)
  funcLuaCommand(VRFW_SS_G.OPEN_MENU, VRFW_SS_MENU)
  coroutine.yield()
  while funcLuaMenuCommand(VRFW_SS_G.EXIST_MENU, VRFW_SS_MENU) do
    coroutine.yield()
  end
  local r = 0
  if VRFW_Param.Has(VRFW_SS_KEY_RESULT) then
    r = VRFW_Param.Get(VRFW_SS_KEY_RESULT) or 0
  end
  VRFW_Param.Clear(VRFW_SS_KEY_RESULT)
  r = math.floor(tonumber(r) or 0)
  -- the menu may have duplicated into / deleted the active slot: the loader then fell back to slot 1 (locked)
  local a2 = VRFW_SS_Call(VRFW_SS_LOADER.GET_SLOT)
  if type(a2) == "number" and a2 >= 1 and a2 <= VRFW_SS_MAX_SLOT then
    active = a2
  end
  VRFW_SS_Log("slot menu result", r, "active", active)
  local isPlayer, locked = VRFW_SS_Layout(r)
  if r == locked then
    r = 0            -- the locked slot can never be continued or loaded with the mods
  end
  if r == active then
    Reopen()     -- the retail code plays the layer's "Open" out animation next and waits for it
    funcLuaMenuCommand(VRFW_SS_G.MENU_ACTIVE, n, true)
    return true
  end
  if r >= 1 and not isPlayer then
    local owner, enterable = VRFW_SS_Reserved(r)
    if owner == nil or not enterable then
      VRFW_SS_Log("slot menu result", r, "refused: not a reserved slot whose owner's mode is on")
      r = 0
    end
  end
  if r >= 1 and r <= VRFW_SS_MAX_SLOT then
    local exists = VRFW_SS_Call(VRFW_SS_LOADER.SLOT_INFO, r) == true
    local ok, why = VRFW_SS_Switch(r, exists)   -- does not return on success
    if not ok then
      VRFW_SS_Message(why)
    end
  end
  -- cancel / failure: back to EMPEZAR (timer restarts from 0 with the layer)
  Reopen()
  funcLuaMenuCommand(VRFW_SS_G.MENU_ACTIVE, n, true)
  funcLuaMenuCommand(VRFW_SS_G.ANIME, gamestartLayer, 0, 71445658 --[[Open]], 0, 2675529103 --[[start]])
  funcLuaMenuCommand(VRFW_SS_G.FOCUS_ENABLE, gamestartLayer, true)
  return false
end

-- CommitPending must run AFTER the engine registered funcLuaCommand, i.e. not at the top level of this include
-- (INCLUDEs run before registration:; there pcall(nil) made the old top-level call
-- a silent no-op). The menu chunk defines OnInit after its INCLUDEs, so a __newindex on the globals table wraps it:
-- the wrapper runs VRFW_SS_CommitPending (protected) and then the menu's own OnInit. Any previous __newindex is kept.
do
  local mt = getmetatable(_G)
  if mt == nil then
    mt = {}
    setmetatable(_G, mt)
  end
  local prev = mt.__newindex
  mt.__newindex = function(t, k, v)
    if k == "OnInit" and type(v) == "function" then
      local menuInit = v
      v = function(...)
        pcall(VRFW_SS_CommitPending)
        return menuInit(...)
      end
    end
    if prev == nil then
      rawset(t, k, v)
    elseif type(prev) == "function" then
      prev(t, k, v)
    else
      prev[k] = v
    end
  end
end
