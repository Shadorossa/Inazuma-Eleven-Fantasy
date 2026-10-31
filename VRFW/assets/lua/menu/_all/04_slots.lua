-- VRFW_Slots: loading a save slot from any menu VM (the slot screen before EMPEZAR, a mode's way out to the slot
-- screen, the title of a slot that opens a root menu). docs/framework/save-slots.md §5.2.
--
--   VRFW_Slots.reserved(k) -> owner | nil, enterable, rootMenu | nil: slot k is a reserved slot of a mod (its mode
--     lets it be entered; rootMenu = the menu loading it opens as its menu scene's root, [[VRFW.SaveSlot]] root_menu)
--   VRFW_Slots.layout(k) -> isPlayerSlot, lockedSlot
--   VRFW_Slots.load(k, spec) -> false, why (nothing changed), or never returns (the game resets into slot k):
--     the write-fenced switch (CMND_VRFW_SLOT_RELOAD), the slot's game loaded (LOAD_HEADER, LOAD_GAME_DATA, APPLY) or a
--     new game for an empty slot, then the reset into the slot's title. A reserved slot with a root menu and a save:
--     the switch committed, the game kept in memory and the reset straight into the root menu (VRFW_Reset.straight);
--     no carry = the slot's title, which forwards (VRFW_Slots.forward).
--     spec = { exists = true | false | nil (asked), close_menu = <menu id> | nil (the title menu that closes before
--              the reset), on_reserved = function(owner, k) | nil, log = function(...) | nil }
--   VRFW_Slots.screen(spec) -> "cancel" | "same" | false, why: the slot screen opened over the caller; a slot picked
--     there is loaded (VRFW_Slots.load: never returns then). The locked slot and a reserved slot whose mode is off
--     count as cancel. spec = { shown = function() | nil (the screen is up), log = function(...) | nil }
--   VRFW_Slots.forward(log) -> nil (the active slot opens no root menu), or VRFW_Reset.straight's answer: the title of
--     a root-menu slot resets straight into the root menu.
--   VRFW_Slots.text(key, k) -> the message of key BUSY / REFUSED / LOAD_FAILED in the game's language (%d = k)
-- Call load / screen / forward from a coroutine (they yield). Defines functions only: no engine call at load time.
VRFW_Slots = VRFW_Slots or {}
do
  local S = VRFW_Slots
  local C = {
    VERSION = VRFW_Cmd.EVT_LOADER_VERSION,      -- () -> api, modules (bit value 2 = the slot service)
    ACTIVE = VRFW_Cmd.VRFW_SLOT_ACTIVE,         -- () -> active slot
    LAYOUT = VRFW_Cmd.VRFW_SLOT_LAYOUT,         -- () -> playerCount, lockedSlot, active, slot1, slot2, ...
    RESERVED = VRFW_Cmd.VRFW_SLOT_RESERVED,     -- (n) -> reserved, ownerModId, enterable, rootMenu
    RELOAD = VRFW_Cmd.VRFW_SLOT_RELOAD,         -- (n) -> bool: map -> slot n, writes fenced until COMMIT / ABORT
    ABORT = VRFW_Cmd.VRFW_SLOT_ABORT,           -- () -> bool: back to the previous slot, fence off
    SLOT_INFO = 1195222835,                     -- (n) -> exists, ...
    COMMIT = 4173545121,                        -- () -> bool: fence off, slot remembered
    BUSY = 1127104486,                          -- () -> bool: a game save / load job is pending
    LOG = VRFW_Cmd.EVT_LOG,
    LOAD_HEADER = 4179471494, IS_SAVE_WORKING = 1979970074, LOAD_GAME_DATA = 2585060058, LOAD_FAILED = 3772572101,
    APPLY = 3660094710, HEADER_CLEAR = 3960538079, RESET_ALL = 1481565076,
    SKIP_PRESS_START = 937976662,               -- (true): the next title opens title_menu_2 at once
    GAME_RESET = VRFW_Cmd.GAME_RESET,
    GET_GFLAG = VRFW_Cmd.GET_GLOBAL_BIT_FLAG, SET_GFLAG = VRFW_Cmd.SET_GLOBAL_BIT_FLAG,
    FLAG_AVATAR_DONE = 2113473044,              -- off: the next title runs the retail first run (avatar, team)
    FADE = 609722083, FADE_DONE = 2259183189, FADE_BUSY = 2736534827, IS_FADE = VRFW_Cmd.BRIGHT_IS_FADE,
    PRE_RESET = 3015544382,                     -- (menu command) the title's BackToTitleTop runs it before closing
    OPEN_MENU = VRFW_Cmd.OPEN_MENU_OBJECT, EXIST_MENU = VRFW_Cmd.IS_EXIST_MENU_OBJECT,
    CLOSE_MENU = VRFW_Cmd.CLOSE_MENU_OBJECT,
    TEXT_GET = VRFW_Cmd.TEXT_GET,
  }
  local SCREEN = 3561559540        -- evt_save_slot_menu
  local SCREEN_RESULT = 2449975398 -- its result: 0 cancel, else the slot
  local MAX_SLOT = 99              -- save engine MAX_SLOT
  local LOCKED_SLOT = 1            -- the layout's locked slot without the layout command
  local WAIT_FRAMES = 3600         -- a save / load job given up after ~60 s
  local FADE_FRAMES = 240          -- every fade wait is bounded (a fade that never reports done must not hang)
  -- texts: the framework's menu_text rows (text\rows\save_slots.toml); the English literal when a row is missing
  local TXT = {
    BUSY = { 511273385 --[[evt_slot_switch_busy]], "The game is saving or loading. Try again in a few seconds." },
    REFUSED = { 909275936 --[[evt_slot_switch_refused]], "Could not switch to Slot %d." },
    LOAD_FAILED = { 3641072355 --[[evt_slot_switch_load_failed]],
      "The data of Slot %d could not be loaded. The current slot is kept." },
  }

  local function Call(cmd, ...)
    local r = table.pack(pcall(funcLuaCommand, cmd, ...))
    if not r[1] then
      return nil
    end
    return table.unpack(r, 2, r.n)
  end

  local function Log(...)
    Call(C.LOG, "save_slots", ...)
  end

  function S.text(key, k)
    local t = TXT[key]
    if t == nil then
      return ""
    end
    local s = Call(C.TEXT_GET, t[1])
    if type(s) ~= "string" or s == "" then
      s = t[2]
    end
    if s:find("%%d") then
      s = string.format(s, math.floor(tonumber(k) or 0))
    end
    return s
  end

  function S.available()
    local api, mods = Call(C.VERSION)
    return type(api) == "number" and api >= 1 and type(mods) == "number" and math.floor(mods / 2) % 2 == 1
  end

  function S.layout(k)
    local t = table.pack(Call(C.LAYOUT))
    if type(t[1]) ~= "number" or t[1] < 1 then
      return k >= 1 and k <= 3, LOCKED_SLOT
    end
    local player = false
    for i = 4, 3 + math.floor(t[1]) do
      if t[i] == k then
        player = true
      end
    end
    return player, type(t[2]) == "number" and math.floor(t[2]) or LOCKED_SLOT
  end

  function S.reserved(k)
    local r, owner, enterable, root = Call(C.RESERVED, k)
    if r ~= true or type(owner) ~= "string" or owner == "" then
      return nil, false, nil
    end
    return owner, enterable == true, (type(root) == "string" and root ~= "") and root or nil
  end

  local function WaitJob()
    local k = 0
    coroutine.yield()
    while funcLuaCommand(C.IS_SAVE_WORKING) do
      k = k + 1
      if k > WAIT_FRAMES then
        return false
      end
      coroutine.yield()
    end
    return true
  end

  local function FadeOut()
    funcLuaCommand(C.FADE, 1, 0.5)
    coroutine.yield()
    local k = 0
    while not funcLuaCommand(C.FADE_DONE) and k < FADE_FRAMES do
      k = k + 1
      coroutine.yield()
    end
    while funcLuaCommand(C.FADE_BUSY) and k < 2 * FADE_FRAMES do
      k = k + 1
      coroutine.yield()
    end
    if k >= FADE_FRAMES then
      Log("fade out: gave up waiting after", k, "frames")
    end
  end

  local function FadeIn()
    funcLuaCommand(C.FADE, 0, 0.3)
    coroutine.yield()
    local k = 0
    while funcLuaCommand(C.IS_FADE) and k < FADE_FRAMES do
      k = k + 1
      coroutine.yield()
    end
  end

  local function Forever()
    while true do
      coroutine.yield()
    end
  end

  function S.load(k, spec)
    spec = spec or {}
    local log = type(spec.log) == "function" and spec.log or Log
    if Call(C.BUSY) == true then
      return false, S.text("BUSY", k)
    end
    local exists = spec.exists
    if exists == nil then
      exists = Call(C.SLOT_INFO, k) == true
    end
    if Call(C.RELOAD, k) ~= true then
      log("reload refused", k)
      return false, S.text("REFUSED", k)
    end
    local owner, _, root = S.reserved(k)
    local reserved = owner ~= nil
    if reserved and type(spec.on_reserved) == "function" then
      local okh, err = pcall(spec.on_reserved, owner, k)
      if not okh then
        log("reserved enter hook of", owner, "failed:", tostring(err))
      end
    end
    -- a save deleted behind its card: the slot is started as a new game instead of loading nothing
    if exists and Call(C.SLOT_INFO, k) ~= true then
      log("slot", k, "has no readable game any more: started as a new game")
      exists = false
    end
    log("switch", k, exists == true, root and ("root menu " .. root) or "title")
    FadeOut()
    if exists then
      funcLuaCommand(C.LOAD_HEADER)
      local ok = WaitJob()
      local started = ok and funcLuaCommand(C.LOAD_GAME_DATA, 1)
      ok = started and WaitJob() and not funcLuaCommand(C.LOAD_FAILED)
      if not ok then
        log("load failed", k)
        Call(C.ABORT)
        funcLuaCommand(C.LOAD_HEADER)       -- the header object may now describe slot k: read ours again
        WaitJob()
        FadeIn()
        return false, S.text("LOAD_FAILED", k)
      end
      funcLuaCommand(C.APPLY)
      if root ~= nil and type(VRFW_Reset) == "table" then
        -- the slot's game is the one in memory: the switch committed (the carry refuses during a switch), then the
        -- reset straight into the root menu; refused = nothing reset, the slot's title below forwards
        log("commit (root menu)", Call(C.COMMIT) == true)
        local how = VRFW_Reset.straight({ menu = root, bgm_stop = true, need_carry = true,
          log = function(text) log("slot", k, "root menu:", text) end })
        log("slot", k, "root menu", root, ":", how)
        if how ~= "refused" then
          Forever()
        end
      end
    else
      -- empty slot = new game (retail «Reiniciar datos» minus SaveHeader / Delete): no header -> InitNewGameData. The
      -- game in memory was just wiped, so nothing of the previous slot can reach slot k: the fence is lifted now (with
      -- SKIP_PRESS_START no title runs the commit before the new game's first autosave)
      funcLuaCommand(C.HEADER_CLEAR)
      funcLuaCommand(C.RESET_ALL)
      log("commit (new game)", Call(C.COMMIT) == true)
      if not reserved then            -- a reserved slot (a mod's mode) never runs the retail first run
        funcLuaCommand(C.SET_GFLAG, C.FLAG_AVATAR_DONE, false)
        log("first run", k, "avatar flag", funcLuaCommand(C.GET_GFLAG, C.FLAG_AVATAR_DONE) == true)
      end
    end
    funcLuaCommand(C.SKIP_PRESS_START, exists == true or reserved)
    log("game reset", k)
    if spec.close_menu ~= nil then
      funcLuaMenuCommand(C.PRE_RESET)
      funcLuaCommand(C.CLOSE_MENU, spec.close_menu, true)
    end
    funcLuaCommand(C.GAME_RESET)
    Forever()
  end

  function S.screen(spec)
    spec = spec or {}
    local log = type(spec.log) == "function" and spec.log or Log
    VRFW_Param.Clear(SCREEN_RESULT)
    funcLuaCommand(C.OPEN_MENU, SCREEN)
    coroutine.yield()
    coroutine.yield()
    if not funcLuaMenuCommand(C.EXIST_MENU, SCREEN) then
      log("slot screen: did not open")
      return false, S.text("REFUSED", 0)
    end
    if type(spec.shown) == "function" then
      pcall(spec.shown)
    end
    while funcLuaMenuCommand(C.EXIST_MENU, SCREEN) do
      coroutine.yield()
    end
    local r = VRFW_Param.Has(SCREEN_RESULT) and VRFW_Param.Get(SCREEN_RESULT) or 0
    VRFW_Param.Clear(SCREEN_RESULT)
    r = math.floor(tonumber(r) or 0)
    local active = Call(C.ACTIVE)
    local player, locked = S.layout(r)
    log("slot screen result", r, "active", tostring(active))
    if r == locked then
      r = 0          -- the locked slot is never continued
    end
    if r == active then
      return "same"
    end
    if r >= 1 and not player then
      local owner, enterable = S.reserved(r)
      if owner == nil or not enterable then
        log("slot screen result", r, "refused: not a reserved slot whose owner's mode is on")
        r = 0
      end
    end
    if r < 1 or r > MAX_SLOT then
      return "cancel"
    end
    return S.load(r, { log = log })
  end

  function S.forward(log)
    log = type(log) == "function" and log or Log
    local active = Call(C.ACTIVE)
    if type(active) ~= "number" then
      return nil
    end
    local owner, enterable, root = S.reserved(active)
    if owner == nil or root == nil or not enterable or type(VRFW_Reset) ~= "table" then
      return nil
    end
    log("title of slot", active, "(" .. owner .. "): straight into its root menu", root)
    return VRFW_Reset.straight({ menu = root, bgm_stop = true, need_carry = true,
      log = function(text) log("slot", active, "root menu:", text) end })
  end
end
