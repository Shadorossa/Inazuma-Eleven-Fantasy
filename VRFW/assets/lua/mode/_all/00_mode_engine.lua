-- mode_engine (VR-Framework): the VRFW_Mode helper, defined in every script VM (lua\_all runs after each retail chunk).
-- It only defines a table: no engine call happens here (funcLuaCommand does not exist while a chunk loads).
-- docs/app/mode-engine.md §7.
--
-- A HOST (the title row, the slot screen, or a mod screen that declares its host with [[host]] in its modes\*.toml)
-- lists the modes declared for it and starts one:
--   local list = VRFW_Mode.entries("my_hub")           -- inside OnInit / OnSetupLayer: {key, name_id, desc_id, icon, ...}
--   VRFW_Mode.start(e.key, "my_hub", focus, {         -- on ENTER of its box
--     before = function() ... end,                    -- e.g. host input off
--     back = function(ret, to, focus) ... end })      -- the mode ended: ret "host" / "title" / host name, focus
--   VRFW_Mode.step()                                    -- every frame, from the host's Step
-- A MODE whose flow is `command` / `lua` ends itself:   VRFW_Mode.finish(key[, cleared])
-- open_menu modes end when their menu closes.
if VRFW_Mode == nil and type(EvtMode) == "table" then
  VRFW_Mode = EvtMode   -- made by a 1.x copy of this file
end
if VRFW_Mode == nil then
  local function crc(s)
    local c = 0xFFFFFFFF
    for i = 1, #s do
      c = bit32.bxor(c, string.byte(s, i))
      for _ = 1, 8 do
        if bit32.band(c, 1) ~= 0 then
          c = bit32.bxor(bit32.rshift(c, 1), 0xEDB88320)
        else
          c = bit32.rshift(c, 1)
        end
      end
    end
    return bit32.bxor(c, 0xFFFFFFFF)
  end

  local H = {}
  for _, n in ipairs({"VERSION", "COUNT", "GET", "ON", "ENTRIES", "ENTRY", "TEXT", "UNLOCKED", "ENTER", "EXIT",
                      "ACTIVE", "RULES", "TEAMS", "REWARDS", "CLEAR"}) do
    H[n] = crc("CMND_EVT_MODE_" .. n)
  end
  local OPEN_MENU = 433545986      -- CMND_OPEN_MENU_OBJECT
  local IS_MENU = 2231168902       -- CMND_IS_EXIST_MENU_OBJECT (funcLuaMenuCommand)
  local LANG = 477234096           -- CMND_GET_LANGUAGE_CODE

  local function call(h, ...)
    local r = table.pack(pcall(funcLuaCommand, h, ...))
    if not r[1] then
      return nil
    end
    return table.unpack(r, 2, r.n)
  end

  -- story_provider: the `story_cleared` clause of [mode.unlock] asks it (a mod that knows whether the loaded story is
  -- cleared sets `VRFW_Mode.story_provider = function() return true / false end`, or the global VRFW_STORY_PROVIDER when
  -- its Lua runs before this file); none = not checked
  VRFW_Mode = { H = H, crc = crc, run = nil, log = {}, story_provider = nil }

  local function note(...)
    if #VRFW_Mode.log < 200 then
      VRFW_Mode.log[#VRFW_Mode.log + 1] = table.concat({...}, " ")
    end
  end

  -- the engine answers (VERSION); without the plugin every query is empty and every mode counts as on
  function VRFW_Mode.ready()
    local v = call(H.VERSION)
    return type(v) == "number"
  end

  function VRFW_Mode.on(key)
    local known, on = call(H.ON, key)
    if known ~= true then
      return true
    end
    return on == true
  end

  function VRFW_Mode.text(key, field)
    local s = call(H.TEXT, key, field or "name", call(LANG) or 3)
    if type(s) ~= "string" or s == "" then
      return field == "description" and "" or key
    end
    return s
  end

  -- the Lua clauses of [mode.unlock] (the Rust ones come with UNLOCKED)
  function VRFW_Mode.story_cleared()
    local p = VRFW_Mode.story_provider or VRFW_STORY_PROVIDER
    if type(p) ~= "function" then
      return true -- no provider: the clause is not checked
    end
    local ok, cleared = pcall(p)
    if not ok or cleared == nil then
      return true
    end
    return cleared == true or cleared == 1
  end

  function VRFW_Mode.unlocked(key)
    local ok, story, lua = call(H.UNLOCKED, key)
    if ok ~= true then
      return ok == nil -- nil = no plugin
    end
    if story == true and not VRFW_Mode.story_cleared() then
      return false
    end
    if type(lua) == "string" and lua ~= "" then
      local f = _G[lua]
      if type(f) ~= "function" or f(key) ~= true then
        return false
      end
    end
    return true
  end

  function VRFW_Mode.entries(host)
    local out = {}
    local n = call(H.ENTRIES, host)
    if type(n) ~= "number" then
      return out
    end
    for i = 0, n - 1 do
      local key, name_id, desc_id, icon, action, arg, unlocked, id = call(H.ENTRY, host, i)
      if type(key) == "string" then
        out[#out + 1] = {key = key, name_id = name_id, desc_id = desc_id, icon = icon, action = action, arg = arg,
                         unlocked = unlocked == true and VRFW_Mode.unlocked(key), id = id}
      end
    end
    return out
  end

  function VRFW_Mode.busy()
    return VRFW_Mode.run ~= nil
  end

  local function finish(run, cleared)
    local ok, ret, to, focus, send = call(H.EXIT, run.key, cleared and 1 or 0)
    if type(send) == "string" and send ~= "" then
      call(crc(send), 0)
    end
    VRFW_Mode.run = nil
    note("exit", run.key, tostring(ret), tostring(to), tostring(focus))
    if run.cb and run.cb.back then
      run.cb.back(ret or "host", to or run.host, focus or run.focus)
    end
    return ok == true
  end

  local function body(run)
    coroutine.yield()
    if run.action == "open_menu" then
      local m = crc(run.arg)
      call(OPEN_MENU, m)
      coroutine.yield()
      while funcLuaMenuCommand(IS_MENU, m) do
        coroutine.yield()
      end
      return finish(run, false)
    elseif run.action == "command" then
      call(crc(run.arg))
    elseif run.action == "lua" then
      local f = _G[run.arg]
      if type(f) == "function" then
        f(run.key, run.host)
      else
        return finish(run, false)
      end
    end
    -- command / lua: the mode calls VRFW_Mode.finish
    while VRFW_Mode.run == run and not run.done do
      coroutine.yield()
    end
    if VRFW_Mode.run == run then
      return finish(run, run.cleared)
    end
  end

  -- start mode `key` from `host` (focus = the host's entry index, given back at the end). Returns true, or false + code
  -- (the ENTER codes of mode_engine; 7 = the session provider refused, 8 = a Lua unlock clause fails).
  function VRFW_Mode.start(key, host, focus, cb)
    if VRFW_Mode.run ~= nil then
      return false, 4
    end
    if not VRFW_Mode.unlocked(key) then
      return false, 8
    end
    local ok, code, action, arg, save, slot, sbegin = call(H.ENTER, key, host, focus or -1)
    if ok ~= true then
      note("refused", key, tostring(code))
      return false, code
    end
    if type(sbegin) == "string" and sbegin ~= "" then
      local sok = call(crc(sbegin), 0)
      if sok ~= true then
        call(H.EXIT, key, 0)
        note("session refused", key)
        return false, 7
      end
    end
    local run = {key = key, host = host, focus = focus or -1, action = action, arg = arg, save = save, slot = slot, cb = cb}
    if cb and cb.before then
      cb.before(run)
    end
    run.co = coroutine.create(body)
    VRFW_Mode.run = run
    note("enter", key, host, tostring(action), tostring(arg), tostring(save))
    coroutine.resume(run.co, run)
    return true, 0
  end

  function VRFW_Mode.finish(key, cleared)
    local run = VRFW_Mode.run
    if run == nil or run.key ~= key then
      return false
    end
    run.done, run.cleared = true, cleared == true
    return true
  end

  function VRFW_Mode.step()
    local run = VRFW_Mode.run
    if run == nil or run.co == nil then
      return
    end
    if coroutine.status(run.co) == "dead" then
      VRFW_Mode.run = nil
      return
    end
    local ok, err = coroutine.resume(run.co)
    if not ok then
      note("error", run.key, tostring(err))
      finish(run, false)
    end
  end

  function VRFW_Mode.rules(key, ctx)
    local id = call(H.RULES, key, ctx or "match")
    return type(id) == "string" and id or ""
  end
end
-- 1.x name (docs/framework/naming.md): the same table under the old name, so mods written for 1.x keep working
EvtMode = VRFW_Mode
