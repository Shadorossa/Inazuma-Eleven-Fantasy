-- menu_engine: VRFW_Host, the hook points of the framework's host patches (docs/framework/lua-hosts.md). Defined in every
-- script VM (lua\_all runs after each retail chunk, before every stem folder of every mod root). It only defines tables
-- and functions: no engine call happens here (funcLuaCommand does not exist while a chunk loads).
--
-- A HOST is the one patch that owns a retail script for the framework: it replaces the named global functions of the
-- script (its hook points) with dispatchers, once, and exposes the chunk's locals (H.L) and named lists. Every mod then
-- registers HANDLERS from its own patch file (its own chunk, so no merged file and no locals limit). The hook points
-- are not listed anywhere: a global function of the script becomes one when a mod registers a handler for it.
--
--   VRFW_Host.on("title_menu_2", "OnEnter", { id = "my_mod.button", phase = "around",
--                                             fn = function(nxt, a1, a2) ... return nxt(a1, a2) end })
--   VRFW_Host.on(stem, "Step",   { id = "my_mod.tick", phase = "after", fn = function(r, ...) end })
--   VRFW_Host.on(stem, "OnInit", { id = "my_mod.reset", phase = "before", priority = -10, fn = function(...) end })
--   VRFW_Host.on(stem, "FinalizeMenu", { ..., create = true })   -- hooked even if the script does not define it
--   VRFW_Host.on(stem, "@edit",  { id = "my_mod.rows", fn = function(L, host) table.insert(L.t4, 9) end })
--   VRFW_Host.add(stem, "option_rows", { id = "my_mod.row", value = row })      -- a named list of the host
--
-- Phases: before fn(...) (return VRFW_Host.HALT, ... to return those values at once); around fn(nxt, ...) (call nxt to
-- go on; the first around in the order is the outermost); after fn(r, ...) (r = table.pack of the results; edit r to
-- change them). Order: priority (lower first, default 0), then after / before = { "<mod>.<name>" | "<mod>" } (soft:
-- a missing one is ignored), then registration order. requires = { "<mod>.<name>" } is hard: without it the handler
-- does not run (logged once). Before / after / @edit handlers run in pcall (an error is logged once, the others go
-- on); around handlers are called directly.
--
-- Registering before this file ran (from an `_all` of a lua_early root): VRFW_HOST_Q = VRFW_HOST_Q or {};
-- table.insert(VRFW_HOST_Q, { "on", stem, point, spec }) -- drained here.
local VERSION = 1
local H = VRFW_Host
if type(H) ~= "table" then
  H = type(EVT_Host) == "table" and EVT_Host or {}   -- a 1.x early patch that made the table under the old name
  VRFW_Host = H
end
-- 1.x name (docs/framework/naming.md): the same table under the old name, so mods written for 1.x keep working
EVT_Host = H

-- the retail closures of this VM's chunk(s), before any stem patch replaced them (the locals map reads their upvalues)
H.retail = H.retail or {}
for k, v in next, _ENV do
  if type(v) == "function" and type(k) == "string" and H.retail[k] == nil then
    H.retail[k] = v
  end
end

if (H.version or 0) >= VERSION then
  return          -- a second chunk in the same VM: keep the registry (only the snapshot above was refreshed)
end
H.version = VERSION

local D = EVT_DEBUG
local LOG = 3661580131          -- crc32("CMND_EVT_LOG")
local pack, unpack = table.pack, table.unpack

H.HALT = H.HALT or setmetatable({}, { __tostring = function() return "VRFW_Host.HALT" end })
H.reg = H.reg or {}             -- reg[stem][point] = { entry, ... } (every phase; entries keep their registration seq)
H.hosts = H.hosts or {}         -- hosts[stem] = { stem, points = { [fn name] = point }, lists = {}, map = {}, L, done, listed, egen }
H.ids = H.ids or {}             -- handler id -> true, mod -> true (requires / after / before targets)
H.seq = H.seq or 0
H.gen = H.gen or 0              -- bumped by every registration: the dispatchers rebuild their order lazily
H.notes = H.notes or {}         -- log lines waiting for the engine (written at the first dispatch)
H.noted = H.noted or {}

local PHASES = { before = true, after = true, around = true, edit = true, item = true }
local CALLS = { before = true, after = true, around = true }   -- phases that hook a global function
local hook_point                -- (host, function name, create): defined with the hosts below

local function list_of(v)
  if v == nil then
    return {}
  elseif type(v) == "string" then
    return { v }
  elseif type(v) == "table" then
    return v
  end
  error("VRFW_Host: a list of handler ids or a string expected", 3)
end

-- one log line (once per text per VM); kept until the engine is there
function H.note(stem, text)
  local key = tostring(stem) .. "|" .. text
  if H.noted[key] then
    return
  end
  H.noted[key] = true
  H.notes[#H.notes + 1] = { tostring(stem), text }
  H.flush()
end

function H.flush()
  if #H.notes == 0 or type(funcLuaCommand) ~= "function" then
    return
  end
  local q = H.notes
  H.notes = {}
  for _, n in ipairs(q) do
    pcall(funcLuaCommand, LOG, "evt_host", n[1], n[2])
  end
end

-- ---- registration ---------------------------------------------------------------------------------------------------
local function caller_mod()
  local f = EVT_PATCH and EVT_PATCH.file
  return type(f) == "string" and f:match("^mods/([^/]+)/") or nil
end

-- Register (or replace, same stem + point + id) a handler. Returns the entry.
function H.on(stem, point, spec)
  if type(stem) ~= "string" or type(point) ~= "string" or type(spec) ~= "table" then
    error("VRFW_Host.on(stem, point, spec): strings and a table expected", 2)
  end
  local id = spec.id
  if type(id) ~= "string" or not id:find(".", 1, true) then
    error("VRFW_Host.on: " .. stem .. ":" .. point .. ": spec.id must be \"<mod>.<name>\"", 2)
  end
  local phase = spec.phase or (point == "@edit" and "edit") or "around"
  if not PHASES[phase] then
    error("VRFW_Host.on: " .. id .. ": phase must be before, after or around", 2)
  end
  if phase ~= "item" and type(spec.fn) ~= "function" then
    error("VRFW_Host.on: " .. id .. ": spec.fn must be a function", 2)
  end
  local by = H.reg[stem]
  if by == nil then
    by = {}
    H.reg[stem] = by
  end
  local list = by[point]
  if list == nil then
    list = {}
    by[point] = list
  end
  local e
  for _, x in ipairs(list) do
    if x.id == id and x.phase == phase then
      e = x
      break
    end
  end
  if e == nil then
    H.seq = H.seq + 1
    e = { seq = H.seq }
    list[#list + 1] = e
  end
  e.id, e.phase, e.fn, e.value = id, phase, spec.fn, spec.value
  e.stem, e.point, e.mod = stem, point, id:match("^(.-)%.[^.]*$")
  e.priority = tonumber(spec.priority) or 0
  e.after, e.before, e.requires = list_of(spec.after), list_of(spec.before), list_of(spec.requires)
  e.from = caller_mod()
  e.create = spec.create == true
  H.ids[id], H.ids[e.mod] = true, true
  H.gen = H.gen + 1
  -- registered after the host ran (a mod root after the framework's): hooked now, at this file's place in the chain
  local h = H.hosts[stem]
  if h ~= nil and CALLS[phase] then
    hook_point(h, point, e.create)
  end
  return e
end

-- Remove a handler (every phase of that id on that point).
function H.off(stem, point, id)
  local list = H.reg[stem] and H.reg[stem][point]
  if list == nil then
    return
  end
  for i = #list, 1, -1 do
    if list[i].id == id then
      table.remove(list, i)
    end
  end
  H.gen = H.gen + 1
end

-- An item of a host's named list (see H.items).
function H.add(stem, list, item)
  if type(item) ~= "table" then
    error("VRFW_Host.add(stem, list, item): a table expected", 2)
  end
  local spec = {}
  for k, v in pairs(item) do
    spec[k] = v
  end
  spec.phase = "item"
  return H.on(stem, list, spec)
end

-- A handler id (or a whole mod) is registered somewhere in this VM.
function H.has(ref)
  return H.ids[ref] == true
end

-- ---- order ----------------------------------------------------------------------------------------------------------
local function matches(ref, e)
  return ref == e.id or ref == e.mod
end

-- The entries of one phase in their run order: requires checked, priority, after / before, registration order.
function H.order(stem, point, phase)
  local live = {}
  for _, e in ipairs((H.reg[stem] and H.reg[stem][point]) or {}) do
    if e.phase == phase then
      local ok = true
      for _, r in ipairs(e.requires) do
        if not H.has(r) then
          ok = false
          H.note(stem, e.id .. " (" .. point .. ") does not run: requires " .. r .. ", which is not registered")
        end
      end
      if ok then
        live[#live + 1] = e
      end
    end
  end
  table.sort(live, function(a, b)
    if a.priority ~= b.priority then
      return a.priority < b.priority
    end
    return a.seq < b.seq
  end)
  local n = #live
  if n < 2 then
    return live
  end
  local into, indeg = {}, {}
  for i = 1, n do
    into[i], indeg[i] = {}, 0
  end
  local function edge(a, b)   -- a runs before b
    if not into[a][b] then
      into[a][b] = true
      indeg[b] = indeg[b] + 1
    end
  end
  for i = 1, n do
    local e = live[i]
    for j = 1, n do
      if i ~= j then
        for _, ref in ipairs(e.after) do
          if matches(ref, live[j]) then
            edge(j, i)
          end
        end
        for _, ref in ipairs(e.before) do
          if matches(ref, live[j]) then
            edge(i, j)
          end
        end
      end
    end
  end
  local out, done = {}, {}
  for _ = 1, n do
    local pick
    for i = 1, n do
      if not done[i] and indeg[i] == 0 then
        pick = i
        break
      end
    end
    if pick == nil then
      for i = 1, n do       -- a cycle: the rest in priority order
        if not done[i] then
          pick = i
          H.note(stem, point .. ": after / before cycle around " .. live[i].id .. ": rest in priority order")
          break
        end
      end
      indeg[pick] = 0
    end
    done[pick] = true
    out[#out + 1] = live[pick]
    for j in pairs(into[pick]) do
      indeg[j] = indeg[j] - 1
    end
  end
  return out
end

-- The values of a host's named list in order (item.value, or the item spec when it has none).
function H.items(stem, list)
  local out = {}
  for _, e in ipairs(H.order(stem, list, "item")) do
    out[#out + 1] = e.value ~= nil and e.value or e
  end
  return out
end

-- ---- dispatch -------------------------------------------------------------------------------------------------------
local function failed(stem, e, err)
  H.note(stem, e.id .. " (" .. e.point .. ", " .. e.phase .. ") failed: " .. tostring(err))
end

local function build(h, p)
  local c = { gen = H.gen, before = H.order(h.stem, p.name, "before"), after = H.order(h.stem, p.name, "after") }
  local nxt = function(...)
    local f = p.prev
    if f ~= nil then
      return f(...)
    end
  end
  local around = H.order(h.stem, p.name, "around")
  for i = #around, 1, -1 do
    local fn, inner = around[i].fn, nxt
    nxt = function(...)
      return fn(inner, ...)
    end
  end
  c.entry = nxt
  p.cache = c
  return c
end

-- at the first dispatch of any point of a host (and again only if handlers were registered since): the @edit handlers
-- not run yet, in order; then, once per VM, each named list's apply with its items
local function edit(h)
  h.egen = H.gen
  H.flush()
  for _, e in ipairs(H.order(h.stem, "@edit", "edit")) do
    if not h.done[e] then
      h.done[e] = true
      local ok, err = pcall(e.fn, h.L, h)
      if not ok then
        failed(h.stem, e, err)
      end
    end
  end
  if not h.listed then
    h.listed = true
    for name, ls in pairs(h.lists) do
      if type(ls.apply) == "function" then
        local items = {}
        for _, e in ipairs(H.order(h.stem, name, "item")) do
          items[#items + 1] = { id = e.id, mod = e.mod, value = e.value }
        end
        local ok, err = pcall(ls.apply, items, h.L, h)
        if not ok then
          H.note(h.stem, "list " .. name .. ": apply failed: " .. tostring(err))
        end
      end
    end
  end
  -- handlers on points this host does not hook never run: say so once
  for point, list in pairs(H.reg[h.stem] or {}) do
    local first = list[1]
    if first ~= nil and point ~= "@edit" then
      local p = h.points[point]
      if p == nil and h.lists[point] == nil and CALLS[first.phase] then
        H.note(h.stem, point .. " was never hooked: " .. first.id .. " never runs")
      elseif p ~= nil and p.dispatch == nil then
        H.note(h.stem, point .. " is not defined in this script: " .. first.id .. " never runs")
      end
    end
  end
end

local function make_dispatch(h, p)
  return function(...)
    if h.egen ~= H.gen then
      edit(h)
    end
    local c = p.cache
    if c == nil or c.gen ~= H.gen then
      c = build(h, p)
    end
    local before, after = c.before, c.after
    if before[1] == nil and after[1] == nil then
      return c.entry(...)
    end
    for i = 1, #before do
      local e = before[i]
      local r = pack(pcall(e.fn, ...))
      if not r[1] then
        failed(h.stem, e, r[2])
      elseif r[2] == H.HALT then
        return unpack(r, 3, r.n)
      end
    end
    if after[1] == nil then
      return c.entry(...)
    end
    local r = pack(c.entry(...))
    for i = 1, #after do
      local e = after[i]
      local ok, err = pcall(e.fn, r, ...)
      if not ok then
        failed(h.stem, e, err)
      end
    end
    return unpack(r, 1, r.n)
  end
end

-- `target` is reached from f through upvalues (f is a wrapper some later patch put over the dispatcher)
local function wraps(f, target, depth, seen)
  local dbg = D or EVT_DEBUG
  if type(f) ~= "function" or dbg == nil or depth > 4 or seen[f] then
    return false
  end
  seen[f] = true
  local i = 1
  while true do
    local n, v = dbg.getupvalue(f, i)
    if n == nil then
      return false
    end
    if v == target or (type(v) == "function" and wraps(v, target, depth + 1, seen)) then
      return true
    end
    i = i + 1
  end
end

local function install(h, p)
  local cur = _ENV[p.name]
  if p.dispatch ~= nil and (cur == p.dispatch or (D or EVT_DEBUG) == nil or wraps(cur, p.dispatch, 0, {})) then
    return                      -- already hooked, or a later patch wraps the dispatcher (keep the chain; without
  end                           -- EVT_DEBUG a wrapper cannot be told from a replacement: never hooked twice)
  if type(cur) ~= "function" then
    if not p.create then
      return                    -- not in this script: nothing to hook
    end
    cur = nil
  end
  if p.dispatch ~= nil then
    H.note(h.stem, p.name .. " was replaced after the host hooked it: hooked again over the new function")
  end
  p.prev = cur
  p.dispatch = p.dispatch or make_dispatch(h, p)
  _ENV[p.name] = p.dispatch
end

-- ---- locals of the retail chunk (H.L) -------------------------------------------------------------------------------
-- the closure holding the locals: the retail function, or the one under a wrapper an INCLUDE put on it at chunk time
-- (title_menu_inc wraps OnInit): the first function with exactly `nup` upvalues, searched through upvalues
local function holder(f, nup, dbg, depth, seen)
  if type(f) ~= "function" or depth > 3 or seen[f] then
    return nil
  end
  seen[f] = true
  local n = 0
  while dbg.getupvalue(f, n + 1) ~= nil do
    n = n + 1
  end
  if n == nup then
    return f
  end
  for i = 1, n do
    local _, v = dbg.getupvalue(f, i)
    local r = holder(v, nup, dbg, depth + 1, seen)
    if r ~= nil then
      return r
    end
  end
  return nil
end

local function make_locals(h)
  local found = {}
  local function at(k)
    local m = h.map[k]
    local dbg = D or EVT_DEBUG
    if m == nil or dbg == nil then
      return nil
    end
    local f = found[k]
    if f == nil then
      f = holder(H.retail[m[1]], m[3], dbg, 0, {})
      if f == nil then
        H.note(h.stem, "local " .. tostring(k) .. ": " .. tostring(m[1]) .. " with " .. tostring(m[3]) .. " upvalues not found")
        return nil
      end
      found[k] = f
    end
    return f, m[2], m[4], dbg
  end
  return setmetatable({}, {
    __index = function(_, k)
      local f, i, ty, dbg = at(k)
      if f == nil then
        return nil
      end
      local _, v = dbg.getupvalue(f, i)
      if ty ~= nil and v ~= nil and type(v) ~= ty then
        H.note(h.stem, "local " .. tostring(k) .. " is a " .. type(v) .. ", not a " .. ty .. ": not served")
        return nil
      end
      return v
    end,
    __newindex = function(_, k, v)
      local f, i, _, dbg = at(k)
      if f == nil then
        error("VRFW_Host: " .. h.stem .. ": no local " .. tostring(k) .. " (not in the host's map, or no EVT_DEBUG)", 2)
      end
      dbg.setupvalue(f, i, v)
    end,
  })
end

-- ---- hosts ----------------------------------------------------------------------------------------------------------
local function host_of(stem)
  local h = H.hosts[stem]
  if h == nil then
    h = { stem = stem, points = {}, lists = {}, map = {}, done = {}, listed = false, egen = -1, active = false }
    h.L = make_locals(h)
    H.hosts[stem] = h
  end
  return h
end

-- the script stem of the patch file running now: its folder (EVT_PATCH.file "mods/<id>/<folder>/<file>"), without the
-- version suffix (title_menu_2_7.01.12.00 -> title_menu_2)
local function stem_here()
  local f = EVT_PATCH and EVT_PATCH.file
  local dir = type(f) == "string" and f:match("([^/]+)/[^/]+$") or nil
  if dir == nil then
    return nil
  end
  return (dir:gsub("_%d+%.%d+[%.%d]*$", ""))
end

-- (host, function name, create): replace the global by the point's dispatcher, once the host is active
hook_point = function(h, name, create)
  if not h.active then
    return
  end
  local p = h.points[name]
  if p == nil then
    p = { name = name }
    h.points[name] = p
  end
  p.create = p.create or create or false
  install(h, p)
end

-- A named list of a host (H.add items; docs/framework/lua-hosts.md §4), declared by the mod that consumes it:
-- def = { apply = function(items, L, host) end }, items = { {id, mod, value}, ... } in order; apply runs once per VM
-- at the host's first callback.
function H.list(stem, name, def)
  host_of(stem).lists[name] = def or {}
end

-- Make a script a host: the patch file that calls it (the host patch; `stem` defaults to its folder) is the place in
-- the patch chain where the dispatchers go. Its hook points are not a fixed list: every global function some mod
-- registered a before / around / after handler for (VRFW_Host.on), and every one registered later (hooked at that
-- registration). spec = {
--   locals = { name = { "GlobalFn", upvalue index, upvalue count, "table" | ... } },   -- menu_assemble.py locals <file>
--   functions = { ... },   -- optional: points hooked even with no handler yet (rarely needed)
-- }. Idempotent; several files may extend one host.
function H.host(stem, spec)
  if type(stem) == "table" and spec == nil then
    stem, spec = nil, stem
  end
  stem = stem or stem_here()
  if type(stem) ~= "string" then
    error("VRFW_Host.host: no stem (call it from a patch file of the script's folder, or pass the stem)", 2)
  end
  spec = spec or {}
  local h = host_of(stem)
  for k, v in pairs(spec.locals or {}) do
    h.map[k] = v
  end
  for k, v in pairs(spec.lists or {}) do
    h.lists[k] = v
  end
  h.active = true
  local want = {}
  for point, list in pairs(H.reg[stem] or {}) do
    for _, e in ipairs(list) do
      if CALLS[e.phase] then
        want[point] = want[point] or e.create
      end
    end
  end
  for _, name in ipairs(spec.functions or {}) do
    if want[name] == nil then
      want[name] = false
    end
  end
  for name, create in pairs(want) do
    hook_point(h, name, create)
  end
  return h
end

-- The retail closure of a global (as the chunk defined it, before any patch).
function H.retail_fn(name)
  return H.retail[name]
end

-- A function that calls what is UNDER the host's dispatcher of stem:name (retail, or what the patches that ran before
-- the host made of it), skipping every handler of that point; resolved at call time, so it may be taken at load.
function H.original(stem, name)
  return function(...)
    local h = H.hosts[stem]
    local p = h and h.points[name]
    local f
    if p ~= nil and p.dispatch ~= nil then
      f = p.prev
    else
      f = _ENV[name]
    end
    if f ~= nil then
      return f(...)
    end
  end
end

-- Human-readable order of a host (tests, debug logs): one line per point with handlers.
function H.report(stem)
  local lines = {}
  local h = H.hosts[stem]
  local points = {}
  for point in pairs(H.reg[stem] or {}) do
    points[#points + 1] = point
  end
  table.sort(points)
  for _, point in ipairs(points) do
    local parts = {}
    for _, phase in ipairs({ "before", "around", "after", "edit", "item" }) do
      local ids = {}
      for _, e in ipairs(H.order(stem, point, phase)) do
        ids[#ids + 1] = e.id
      end
      if #ids > 0 then
        parts[#parts + 1] = phase .. " " .. table.concat(ids, ", ")
      end
    end
    local hooked = h and (h.points[point] ~= nil and (h.points[point].dispatch ~= nil and "hooked" or "not defined")
      or (h.lists[point] ~= nil and "list") or (point == "@edit" and "edit")) or "no host"
    lines[#lines + 1] = stem .. ":" .. point .. " [" .. hooked .. "] " .. table.concat(parts, "; ")
  end
  return table.concat(lines, "\n")
end

-- registrations queued by patches that ran before this file (VRFW_HOST_Q, or the 1.x EVT_HOST_Q)
for _, qname in ipairs({ "VRFW_HOST_Q", "EVT_HOST_Q" }) do
  local queue = rawget(_ENV, qname)
  if type(queue) == "table" then
    for _, q in ipairs(queue) do
      if q[1] == "on" then
        H.on(q[2], q[3], q[4])
      elseif q[1] == "add" then
        H.add(q[2], q[3], q[4])
      end
    end
    rawset(_ENV, qname, nil)
  end
end
