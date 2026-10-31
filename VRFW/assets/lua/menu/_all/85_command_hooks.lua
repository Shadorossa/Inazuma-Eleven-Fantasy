-- VRFW_Host command hooks: the one wrapper of this VM's funcLuaCommand / funcLuaMenuCommand. A screen that must see,
-- answer or change one engine command registers a handler here instead of replacing the global itself; a screen
-- that needs other answers only around one call uses WithCommands. Definitions only: no engine call at load (the
-- command functions are registered after the chunk; a hook registered at load goes on when the engine stores them).
--   VRFW_Host.Command(id, ...)     -> funcLuaCommand(id, ...) in pcall: its results, nil when it fails
--   VRFW_Host.MenuCommand(id, ...) -> the same with funcLuaMenuCommand
--   VRFW_Host.RealCommand(id, ...) / VRFW_Host.RealMenuCommand(id, ...) -> the command under every handler (the one
--     the first dispatcher of this VM wrapped, the engine's): a handler's own calls of other commands that must not
--     pass through the handlers. Errors are raised as the command raises them.
--   VRFW_Host.HookCommand(id, fn, owner[, opts]) -> true when the dispatcher is in place (false: the command function
--     does not exist yet in this VM, e.g. a call at chunk load; the handler stays registered and the dispatcher goes on
--     the moment the engine stores the command function, through a __newindex of the globals chained onto any
--     earlier one, or at the next HookCommand / WithCommands call; the install line is logged at its first call)
--       id     a command crc, a list of crcs, or "*" (every command)
--       fn     fn(nxt, ...): `...` = the call's arguments exactly as the caller gave them (the command id first).
--              Return nxt(...) to go on (arguments may be changed), or return the handler's own answer.
--              Inside a handler call nxt, never the global function for the same command.
--       owner  "<mod>.<feature>": one handler per owner and id (a second call replaces the first); its install line is
--              logged once per VM only while the framework's config [debug] command_hooks is on
--       opts   { menu = true (hook funcLuaMenuCommand), priority = 0 (lower = called first, outermost) }
--              VRFW_Host.INNERMOST = right over the command, under every other handler
--     A handler error is logged once per owner; the call then goes on as if the handler had called nxt.
--   VRFW_Host.UnhookCommand(owner[, opts]) -> the owner's handlers removed (opts.menu as above)
--   VRFW_Host.WithCommands(overrides, fn, ...) -> the results of fn(...), run with temporary answers:
--       overrides = { [crc] = answer | function(nxt, ...) … , menu = { [crc] = … } (funcLuaMenuCommand) }
--       a plain value is returned as the command's only answer; a function is a handler as above. The answers are
--       removed when fn returns or fails (its error is raised again after that); nested calls: the inner one is outer.
-- One dispatcher per command function per VM. When another script replaced the global after it, the next
-- HookCommand / WithCommands call wraps the new global again; a call that passes through two of our dispatchers runs
-- the handlers once.
VRFW_Host = VRFW_Host or {}
if VRFW_Host.HookCommand == nil then
  local H = VRFW_Host
  local LOG = VRFW_Cmd.EVT_LOG
  local PRIORITY_TEMPORARY = -1000000000
  H.INNERMOST = 1000000000           -- opts.priority of a filter that sits right over the command (called last)
  local pack, unpack = table.pack, table.unpack

  local SLOTS = {}                   -- function name -> slot
  local seq = 0
  local with_depth = 0

  local function slot_of(menu)
    local name = menu and "funcLuaMenuCommand" or "funcLuaCommand"
    local s = SLOTS[name]
    if s == nil then
      s = { name = name, by_id = {}, any = {}, gen = 0, chains = {}, chains_gen = -1, passing = nil, top = nil,
        base = nil, pending = {} }
      SLOTS[name] = s
    end
    return s
  end

  local function log(...)
    local f = _ENV.funcLuaCommand
    if type(f) == "function" then
      pcall(f, LOG, "command_hooks", ...)
    end
  end

  -- the install lines: only while the framework's config [debug] command_hooks is on (read once per VM, at the first
  -- line, when funcLuaCommand exists)
  local trace_on = nil
  local function trace(...)
    if trace_on == nil then
      local f = _ENV.funcLuaCommand
      if type(f) ~= "function" then
        return
      end
      local ok, on = pcall(f, VRFW_Cmd.VRFW_DEBUG_SWITCH, "command_hooks")
      trace_on = ok and (on == true or on == 1)
    end
    if trace_on then
      log(...)
    end
  end

  local function crc_text(c)
    if type(c) ~= "number" then
      return tostring(c)
    end
    c = math.floor(c) % 4294967296
    return string.format("0x%04X%04X", math.floor(c / 65536), c % 65536)
  end

  -- the install lines of handlers registered before the command existed: written at its first call
  local function flush_pending(s)
    if type(_ENV.funcLuaCommand) ~= "function" then
      return
    end
    local lines = s.pending
    s.pending = {}
    for _, line in ipairs(lines) do
      trace(line.owner, "hooks", s.name, line.ids)
    end
  end

  -- the handlers of command c, outermost first (cached per registry generation)
  local function chain_of(s, c)
    if s.chains_gen ~= s.gen then
      s.chains, s.chains_gen = {}, s.gen
    end
    local list = s.chains[c]
    if list ~= nil then
      return list
    end
    list = {}
    for _, h in ipairs(s.by_id[c] or {}) do
      list[#list + 1] = h
    end
    for _, h in ipairs(s.any) do
      list[#list + 1] = h
    end
    table.sort(list, function(a, b)
      if a.priority ~= b.priority then
        return a.priority < b.priority
      end
      return a.seq < b.seq
    end)
    s.chains[c] = list
    return list
  end

  -- a call without a command id (a caller's constant that does not exist): logged once per caller, then the call
  -- goes to the command function as it is
  local last_nil_caller = nil
  local function note_nil_command(s)
    local where = "?"
    if debug and debug.traceback then
      local ok, tb = pcall(debug.traceback, "", 3)
      if ok and type(tb) == "string" then
        local frames = {}
        for line in tb:gmatch("[^\n]+") do
          line = line:gsub("^%s+", "")
          if line ~= "" and line ~= "stack traceback:" then
            frames[#frames + 1] = line
            if #frames == 3 then
              break
            end
          end
        end
        where = table.concat(frames, " <- ")
      end
    end
    if where ~= last_nil_caller then
      last_nil_caller = where
      log(s.name, "called with a nil command id from", where)
    end
  end

  -- handler k of the chain, then the command function under the dispatcher
  local function run(s, list, k, real, ...)
    local h = list[k]
    if h == nil then
      local before = s.passing
      s.passing = (...)
      local r = pack(pcall(real, ...))
      s.passing = before
      if not r[1] then
        error(r[2], 0)
      end
      return unpack(r, 2, r.n)
    end
    local called, results = false, nil
    local function nxt(...)
      called = true
      results = pack(run(s, list, k + 1, real, ...))
      return unpack(results, 1, results.n)
    end
    local r = pack(pcall(h.fn, nxt, ...))
    if r[1] then
      return unpack(r, 2, r.n)
    end
    if called and results == nil then
      error(r[2], 0)                 -- the command under the handler failed: its error goes on
    end
    if not h.failed then
      h.failed = true
      log("handler of", h.owner, "failed on", crc_text((...)), tostring(r[2]))
    end
    if called then
      return unpack(results, 1, results.n)
    end
    return run(s, list, k + 1, real, ...)
  end

  local function install(s)
    local current = _ENV[s.name]
    if type(current) ~= "function" then
      return false
    end
    if current == s.top then
      return true
    end
    local real = current
    if s.base == nil then
      s.base = real                  -- the command under the first dispatcher: what RealCommand calls
    end
    local dispatch
    dispatch = function(...)
      local c = ...
      if s.pending[1] ~= nil then
        flush_pending(s)
      end
      if c == nil then
        note_nil_command(s)
        return real(...)
      end
      if s.passing ~= nil and s.passing == c then
        return real(...)             -- a dispatcher above already ran the handlers of this call
      end
      local list = chain_of(s, c)
      if #list == 0 then
        return real(...)
      end
      return run(s, list, 1, real, ...)
    end
    s.top = dispatch
    _ENV[s.name] = dispatch
    return true
  end

  local function ids_of(id)
    if type(id) == "table" then
      return id
    end
    return { id }
  end

  local function add(s, id, fn, owner, priority)
    seq = seq + 1
    local h = { fn = fn, owner = owner, priority = priority, seq = seq }
    local list
    if id == "*" then
      list = s.any
    else
      list = s.by_id[id]
      if list == nil then
        list = {}
        s.by_id[id] = list
      end
    end
    for i = #list, 1, -1 do
      if list[i].owner == owner then
        table.remove(list, i)
      end
    end
    list[#list + 1] = h
    s.gen = s.gen + 1
  end

  local function remove(s, owner)
    local function drop(list)
      for i = #list, 1, -1 do
        if list[i].owner == owner then
          table.remove(list, i)
        end
      end
    end
    for _, list in pairs(s.by_id) do
      drop(list)
    end
    drop(s.any)
    s.gen = s.gen + 1
  end

  -- the engine registers the command functions after every patch of the script ran: a __newindex of the globals
  -- (chained onto any earlier one) puts the dispatcher on a command function the moment it is stored. Defines a
  -- metamethod only: no engine call. false when the globals' metatable is protected.
  local globals_watched = false
  local function watch_registration()
    if globals_watched then
      return true
    end
    local ok_meta, meta = pcall(getmetatable, _ENV)
    if not ok_meta or (meta ~= nil and type(meta) ~= "table") then
      return false
    end
    if meta == nil then
      meta = {}
      if not pcall(setmetatable, _ENV, meta) then
        return false
      end
    end
    local previous = meta.__newindex
    meta.__newindex = function(globals, key, value)
      if previous == nil then
        rawset(globals, key, value)
      elseif type(previous) == "function" then
        previous(globals, key, value)
      else
        previous[key] = value
      end
      local s = SLOTS[key]
      if s ~= nil and type(rawget(globals, key)) == "function" then
        install(s)
      end
    end
    globals_watched = true
    return true
  end

  local LOGGED = {}

  function H.HookCommand(id, fn, owner, opts)
    opts = opts or {}
    if type(fn) ~= "function" or type(owner) ~= "string" or owner == "" then
      log("HookCommand: a handler function and an owner text are required", tostring(owner))
      return false
    end
    local s = slot_of(opts.menu)
    for _, c in ipairs(ids_of(id)) do
      add(s, c, fn, owner, tonumber(opts.priority) or 0)
    end
    local ok = install(s)
    if not ok then
      watch_registration()
    end
    local key = s.name .. "|" .. owner
    if not LOGGED[key] then
      LOGGED[key] = true
      local list = {}
      for _, c in ipairs(ids_of(id)) do
        list[#list + 1] = crc_text(c)
      end
      if ok then
        trace(owner, "hooks", s.name, table.concat(list, " "))
      else
        s.pending[#s.pending + 1] = { owner = owner, ids = table.concat(list, " ") }
      end
    end
    return ok
  end

  -- the command under the first dispatcher of this VM (the engine's), past every handler; the global when no
  -- dispatcher is in place yet. Errors are raised as the command raises them.
  local NO_HANDLERS = {}
  local function real_call(s, ...)
    local base = s.base
    if base == nil then
      base = _ENV[s.name]
    end
    return run(s, NO_HANDLERS, 1, base, ...)
  end

  function H.RealCommand(...)
    return real_call(slot_of(false), ...)
  end

  function H.RealMenuCommand(...)
    return real_call(slot_of(true), ...)
  end

  function H.UnhookCommand(owner, opts)
    remove(slot_of(opts and opts.menu), owner)
  end

  local function answer_of(v)
    if type(v) == "function" then
      return v
    end
    return function()
      return v
    end
  end

  function H.WithCommands(overrides, fn, ...)
    with_depth = with_depth + 1
    seq = seq + 1
    local owner = "with_commands#" .. seq
    local priority = PRIORITY_TEMPORARY - with_depth
    local used = {}
    for c, v in pairs(overrides or {}) do
      if c ~= "menu" then
        local s = slot_of(false)
        add(s, c, answer_of(v), owner, priority)
        used[s] = true
      end
    end
    if type(overrides) == "table" and type(overrides.menu) == "table" then
      for c, v in pairs(overrides.menu) do
        local s = slot_of(true)
        add(s, c, answer_of(v), owner, priority)
        used[s] = true
      end
    end
    for s in pairs(used) do
      if not install(s) then
        log("WithCommands:", s.name, "does not exist yet: run without the answers")
      end
    end
    local r = pack(pcall(fn, ...))
    for s in pairs(used) do
      remove(s, owner)
    end
    with_depth = with_depth - 1
    if not r[1] then
      error(r[2], 0)
    end
    return unpack(r, 2, r.n)
  end

  function H.Command(id, ...)
    local r = pack(pcall(_ENV.funcLuaCommand, id, ...))
    if not r[1] then
      return nil
    end
    return unpack(r, 2, r.n)
  end

  function H.MenuCommand(id, ...)
    local r = pack(pcall(_ENV.funcLuaMenuCommand, id, ...))
    if not r[1] then
      return nil
    end
    return unpack(r, 2, r.n)
  end
end
