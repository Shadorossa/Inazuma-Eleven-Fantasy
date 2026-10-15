-- Shared game entries: which mods declare a game profile function / site (game/<build>/functions.toml, sites.toml) in their content/game/*.toml,
-- as a hook (`[[VRFW.Hook]]`, a detour) or a function (`[[VRFW.Function]]`), every active mod in load order.
-- An entry is named with `game = "<profile name>"` (VRFW.game/2) or an inline signature whose `rva` (+ `offset`) refers to the reference profile.
-- Hooks of one entry share ONE loader detour; the link installed last runs first (installed mod by mod in load order, file by file, declaration order).
--   local E = require "lib/game_entries"
--   local subs = E.declarers("Passive.ResolveExecCondition")   -- { { mod, file, kind, name, decl }, … } install order
--   local chain = E.run_order(subs)                            -- the hooks, first to run first
--
-- Read once; a mod reload re-runs the scripts.

local M = {}

local function warn(...) VRFW.warn("game_entries:", ...) end

local function u32(v)
  v = tonumber(v)
  if not v or v ~= v then return nil end
  return math.floor(v) % 4294967296
end

-- ---------------------------------------------------------------------------------------------- the profile

local PROFILE = nil      -- name -> { rva, offset, kind = "function" | "site" }
local LABEL = nil

-- The reference profile (the build.toml with no `inherits`) from the framework's own game/ folder.
local function read_profile()
  if PROFILE then return PROFILE end
  PROFILE = {}
  local ok, list = pcall(VRFW.files.declarations, "game")
  if not ok or type(list) ~= "table" then return PROFILE end
  local builds = {}      -- label -> { base = <file name> -> data }
  for _, f in ipairs(list) do
    if f.mod == "vr_framework" and type(f.file) == "string" and type(f.data) == "table" then
      local label, base = f.file:match("([^/\\]+)[/\\]([^/\\]+)%.toml$")
      if label and label:sub(1, 1) ~= "_" then
        builds[label] = builds[label] or {}
        builds[label][base] = f.data
      end
    end
  end
  for label, parts in pairs(builds) do
    local b = parts.build
    if type(b) == "table" and b.inherits == nil and (LABEL == nil or label < LABEL) then LABEL = label end
  end
  if not LABEL then return PROFILE end
  for _, part in ipairs({ { "functions", "function" }, { "sites", "site" } }) do
    local t = builds[LABEL][part[1]]
    for _, e in ipairs(type(t) == "table" and type(t[part[2]]) == "table" and t[part[2]] or {}) do
      if type(e.name) == "string" and not PROFILE[e.name] then
        PROFILE[e.name] = { rva = u32(e.rva), offset = tonumber(e.offset) or 0, kind = part[2] }
      end
    end
  end
  return PROFILE
end

-- The reference profile's label (nil when the framework's game/ folder is unreadable: then only `game =` declarations match).
function M.reference()
  read_profile()
  return LABEL
end

-- ---------------------------------------------------------------------------------------------- declarations

local FILES = nil

local function files()
  if FILES then return FILES end
  FILES = {}
  local ok, list = pcall(VRFW.files.declarations, { "content/game", "features/*/content/game" })
  if not ok or type(list) ~= "table" then
    warn("content/game declarations not readable: " .. tostring(list))
    return FILES
  end
  FILES = list
  return FILES
end

local function matches(entry, name, d)
  if d.game == name then return true end
  if d.game ~= nil or not entry then return false end
  -- an inline signature (VRFW.game/1): the profile entry's address
  local rva = u32(d.rva)
  return rva ~= nil and entry.rva ~= nil and rva + (tonumber(d.offset) or 0) == entry.rva + entry.offset
end

-- Every declaration of the profile entry `name`, in install order: { mod, file, kind = "hook" | "function", name,
-- decl } (`mod` = the mod id).
function M.declarers(name)
  local entry = read_profile()[name]
  local out = {}
  for _, f in ipairs(files()) do
    local v = type(f.data) == "table" and type(f.data.VRFW) == "table" and f.data.VRFW or {}
    for _, kind in ipairs({ { "Function", "function" }, { "Hook", "hook" } }) do
      for _, d in ipairs(type(v[kind[1]]) == "table" and v[kind[1]] or {}) do
        if type(d) == "table" and matches(entry, name, d) then
          out[#out + 1] = { mod = f.mod, file = f.file, kind = kind[2], name = tostring(d.name), decl = d }
        end
      end
    end
  end
  return out
end

-- The hooks of `subs` in the order the detour runs them: a declaration's `order` first (higher runs first, none = 0:
-- the engines' subscribers are 0 too), then the last installed first.
function M.run_order(subs)
  local out = {}
  for i = #subs, 1, -1 do
    if subs[i].kind == "hook" then out[#out + 1] = subs[i] end
  end
  local pos = {}
  for i, s in ipairs(out) do pos[s] = i end
  local function ord(s) return tonumber(type(s.decl) == "table" and s.decl.order or 0) or 0 end
  table.sort(out, function(a, b)
    if ord(a) ~= ord(b) then return ord(a) > ord(b) end
    return pos[a] < pos[b]
  end)
  return out
end

-- The ids a hook's `pre` / `post` answers compare argument N with (`when = { value = "args[N]", equals = x }`, single or list). Sorted, unique.
function M.answered_values(decl, arg)
  local want = "args[" .. tostring(arg or 1) .. "]"
  local seen, out = {}, {}
  local function cond(c)
    if type(c) == "table" and c.value == want and tonumber(c.equals) then
      local n = tonumber(c.equals)
      if not seen[n] then
        seen[n] = true
        out[#out + 1] = n
      end
    end
  end
  for _, a in ipairs(type(decl.answer) == "table" and decl.answer or {}) do
    local w = a.when
    if type(w) == "table" and w.value ~= nil then
      cond(w)
    elseif type(w) == "table" then
      for _, c in ipairs(w) do cond(c) end
    end
  end
  table.sort(out)
  return out
end

-- ---------------------------------------------------------------------------------------------- exported tables

local MANIFESTS = nil

-- The mods that list `name` in their mod.toml [exports] tables, in the order a `*/<name>` answer reads them (last loaded first).
function M.exporters(name)
  if not MANIFESTS then
    local ok, list = pcall(VRFW.files.declarations, "mod.toml")
    MANIFESTS = ok and type(list) == "table" and list or {}
  end
  local out = {}
  for i = #MANIFESTS, 1, -1 do
    local f = MANIFESTS[i]
    local ex = type(f.data) == "table" and f.data.exports or nil
    for _, t in ipairs(type(ex) == "table" and type(ex.tables) == "table" and ex.tables or {}) do
      if t == name then
        out[#out + 1] = f.mod
        break
      end
    end
  end
  return out
end

-- The first key part of every row of mod `mod`'s [[VRFW.Table]] `name` (sorted, unique; {} = rows filled by scripts only).
function M.table_keys(mod, name)
  local seen, out = {}, {}
  for _, f in ipairs(files()) do
    local v = f.mod == mod and type(f.data) == "table" and type(f.data.VRFW) == "table" and f.data.VRFW or {}
    for _, t in ipairs(type(v.Table) == "table" and v.Table or {}) do
      if type(t) == "table" and t.name == name then
        for _, r in ipairs(type(t.rows) == "table" and t.rows or {}) do
          local k = type(r) == "table" and type(r.key) == "table" and tonumber(r.key[1]) or nil
          if k and not seen[k] then
            seen[k] = true
            out[#out + 1] = k
          end
        end
      end
    end
  end
  table.sort(out)
  return out
end

-- "mod.name" of a declaration.
function M.label(s)
  return tostring(s.mod) .. "." .. tostring(s.name)
end

-- One line: the hooks in run order (" > "), then the callers ("called by …"), for the boot log.
function M.describe(name, subs)
  local chain, callers, seen = {}, {}, {}
  for _, s in ipairs(M.run_order(subs)) do chain[#chain + 1] = M.label(s) end
  for _, s in ipairs(subs) do
    if s.kind == "function" and not seen[s.mod] then
      seen[s.mod] = true
      callers[#callers + 1] = tostring(s.mod)
    end
  end
  local hooks = #chain > 0 and (table.concat(chain, " > ") .. " > game") or "not hooked"
  local calls = #callers > 0 and ("; called by " .. table.concat(callers, ", ")) or ""
  return string.format("%s: %s%s", name, hooks, calls)
end

return M
