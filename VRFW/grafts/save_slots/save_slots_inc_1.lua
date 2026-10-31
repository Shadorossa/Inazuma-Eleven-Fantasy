-- ================================================================================================================
-- EVT save slots (appended to title_menu_inc_1.04.32.00 by research/scripts/slot_build.py). The VR-Framework's slot
-- service (graft save_slots, mod vr_framework: a Lua patch of the INCLUDE'd title_menu_inc in its save\lua root).
-- EMPEZAR (title_menu, layer title00_04_gamestart) -> StartItemSelectMenuCoroutine calls VRFW_SS_BeforeGameStart()
-- after the button's OK animation (patch marked EVT above). It opens evt_save_slot_menu and then:
--   cancel ............ back to EMPEZAR
--   active slot ....... returns true: the retail code continues (fade, title_menu_2), nothing is reloaded
--                       (NOT for the locked slot: the menu never returns it and it is treated as cancel)
--   other slot ........ loader switch + reset flow (VRFW_SS_Switch -> VRFW_Slots.load): the title re-enters and opens
--                       the mode row; a reserved slot with a root menu opens that menu straight (no title)
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
  SLOT_INFO = 1195222835,      -- (n) -> exists, chapter, ...
  COMMIT = 4173545121,       -- () -> bool: fence off, slot remembered
  STATE = 3534676964,         -- () -> 0 idle, 1 switching (fenced), -1 error
  LOG = @crc:CMND_EVT_LOG@,                  -- (...) -> true: evt_loader\loader.log
}
local VRFW_SS_MAX_SLOT = 99   -- highest slot number (save engine MAX_SLOT); a slot that is not a player one is a reserved one
-- the owners' entry hooks (title VM): VRFW_SS_RESERVED_ENTER["<owner mod id>"] = function(slot) end
VRFW_SS_RESERVED_ENTER = VRFW_SS_RESERVED_ENTER or EVT_SS_RESERVED_ENTER or {}
EVT_SS_RESERVED_ENTER = VRFW_SS_RESERVED_ENTER   -- 1.x name: same object
local VRFW_SS_MENU = 3561559540
local VRFW_SS_KEY_RESULT = 2449975398
-- texts: the framework's menu_text rows, read when shown (VRFW_Slots.text, lua\_all\04_slots.lua)
function VRFW_SS_Text(key, k)
  if type(VRFW_Slots) ~= "table" then
    return "Could not switch to Slot " .. tostring(k) .. "."
  end
  return VRFW_Slots.text(key, k)
end
-- retail commands
local VRFW_SS_G = {
  MENU_ACTIVE = 1558704558, FOCUS_ENABLE = @crc:CMND_SET_ENABLE_CTRL_FOCUS@, ANIME = @crc:CMND_PLAY_ANIME_TYPE@,
  OPEN_MENU = @crc:CMND_OPEN_MENU_OBJECT@, EXIST_MENU = @crc:CMND_IS_EXIST_MENU_OBJECT@,
  MSG_OPEN = 2289627655, MSG_BUSY = 898725220, MSG_DONE = 682363669,
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

-- the layout (k is a player slot, the locked slot) and the reserved slots: VRFW_Slots (lua\_all\04_slots.lua)
local function VRFW_SS_Layout(k)
  if type(VRFW_Slots) ~= "table" then
    return k >= 1 and k <= 3, 1
  end
  return VRFW_Slots.layout(k)
end

-- slot k is a reserved slot of a mod: its owner (nil = not reserved / no owner), whether its mode lets it be
-- entered, and the menu loading it opens as its menu scene's root (nil = its title)
local function VRFW_SS_Reserved(k)
  if type(VRFW_Slots) ~= "table" then
    return nil, false, nil
  end
  return VRFW_Slots.reserved(k)
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

local function VRFW_SS_Message(text)
  funcLuaCommand(VRFW_SS_G.MSG_OPEN, text, 0, 0, 0, 0, 0, false)
  while funcLuaCommand(VRFW_SS_G.MSG_BUSY) do
    coroutine.yield()
  end
  while not funcLuaCommand(VRFW_SS_G.MSG_DONE) do
    coroutine.yield()
  end
end

-- Switch to slot k (k ~= active): VRFW_Slots.load (lua\_all\04_slots.lua) with this title menu closed before the
-- reset and the reserved slot's owner hook. Returns false + message on failure (nothing changed); on success the game
-- resets (into the slot's title, or straight into a reserved slot's root menu) and this never returns.
function VRFW_SS_Switch(k, exists)
  if type(VRFW_Slots) ~= "table" then
    VRFW_SS_Log("switch", k, "refused: VRFW_Slots missing in this VM")
    return false, VRFW_SS_Text("REFUSED", k)
  end
  return VRFW_Slots.load(k, {
    exists = exists,
    close_menu = n,
    on_reserved = function(owner, slot)
      local hook = VRFW_SS_RESERVED_ENTER[owner]
      if type(hook) == "function" then
        hook(slot)
      end
    end,
    log = VRFW_SS_Log,
  })
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
