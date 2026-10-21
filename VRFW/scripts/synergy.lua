-- Team synergies declared by mods: reads every mod's content/synergies/*.toml (`VRFW.synergy/1`); native side in content/game/synergy.toml, menu patch in assets/lua/synergy/equip_synergy_menu_list/.
-- A declared synergy replaces the condition rows of one game synergy (its key, e.g. «sp04003») with:
--   nexus  characters (variants of one person), one of whom must be in the team, else the synergy is off
--   pool   who may fill the `count` slots (belong teams, series, staff role, gender, characters)
--   rule   "min" (at least `count` pool players) or "exact" (exactly `count`)
-- `slots` (one pool per slot) + `slot_members = true` draws each slot row like the nexus row (team crest, members' minifaces while empty).
-- Counted members are the starters (11, or 5 for the other team kind) and the staff slots (member classes 0x10-0x13 and above 0x1C); `distinct = "person"` (default) counts two versions of one person once.
-- Only that synergy's check answer is rewritten (active byte, taking-part members, one byte per row); its effects stay the game synergy's.
-- Detail panel rows: the nexus (the version in the team, else the first declared), then per slot the filling member or a pool character not in the team (face hidden, hint shown).

Synergy = Synergy or {}

local function info(...) VRFW.log("synergy:", ...) end
local function warn(...) VRFW.warn("synergy:", ...) end

local N_MEMBERS = 0x1D
local MEMBER_BASE, MEMBER_STRIDE, MEMBER_CLASS = 0x80, 0x10, 0x0E
local TEAM_KIND = 0x2CF
local ANS_ACTIVE, ANS_ROWS = 0x7C, 0x74
local MAX_ROWS = 3                       -- the panel's room (SynergyDetail's list) and its largest layout
local KIND_NEXUS, KIND_NEXUS_MISSING, KIND_FILLED, KIND_EMPTY = 1, 2, 3, 4

-- series names: the framework's (VRFW.chara.series_of: chara_base's in_<name> columns + content\defaults\series_names.toml)
local GENDER = { male = 1, female = 2 }
local ROLES = { manager = true, coach = true }

local function u32(v)
  v = tonumber(v) or 0
  if v ~= v then return 0 end
  v = math.floor(v)
  return v % 4294967296
end

local function crc(s) return u32(VRFW.ui.crc32(s)) end

-- "0x…" / decimal / a number → the number, any other text → crc32 of it
local function id_of(v)
  if type(v) == "number" then return u32(v) end
  if type(v) ~= "string" then return nil end
  local h = v:match("^%s*0[xX](%x+)%s*$")
  if h then return tonumber(h, 16) % 4294967296 end
  if v:match("^%s*%d+%s*$") then return tonumber(v) % 4294967296 end
  return crc(v)
end

-- a character: "c11801020" (internal key) / a mod character name / "0x…" → its chara_base id
local function chara_of(v)
  if type(v) == "string" and not v:match("^%s*0[xX]") and not v:match("^%s*%d+%s*$") then
    local ok, id = pcall(VRFW.character, v)
    if ok and type(id) == "number" and id ~= 0 then return u32(id) end
  end
  return id_of(v)
end

local function rd(ty, at)
  if type(at) ~= "number" or at < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, ty, at)
  if ok then return v end
  return nil
end

local function wr(ty, at, v)
  if type(at) ~= "number" or at < 0x10000 then return false end
  return (pcall(VRFW.mem.write, ty, at, v))
end

local function list_of(v)
  if v == nil then return {} end
  if type(v) ~= "table" then return { v } end
  return v
end

-- ---------------------------------------------------------------------------------------------- declarations

local POOLS = {}         -- "<mod>.<name>" -> pool
local DECL = {}          -- synergy id -> declaration
local LIST = {}

local POOL_KEYS = { name = true, teams = true, series = true, role = true, gender = true, charas = true, exclude = true, hint = true }
local SYN_KEYS = { key = true, nexus = true, pool = true, count = true, rule = true, distinct = true, hint = true, placeholder = true,
  slots = true, skip_nexus_team = true, slot_members = true }

local function read_pool(mod, file, p, i)
  local where = string.format("mods/%s/%s: [[VRFW.SynergyPool]] #%d", tostring(mod), tostring(file), i)
  for k in pairs(p) do
    if not POOL_KEYS[k] then return nil, where .. ": unknown key `" .. tostring(k) .. "`" end
  end
  if type(p.name) ~= "string" or not p.name:match("^[a-z0-9_]+$") then return nil, where .. ": name = \"a-z 0-9 _\" is required" end
  local x = { key = tostring(mod) .. "." .. p.name, teams = {}, team_list = {}, series = {}, charas = {}, exclude = {},
    hint = p.hint and id_of(p.hint) or nil }
  for _, t in ipairs(list_of(p.teams)) do
    local id = id_of(t)
    if not id then return nil, where .. " " .. p.name .. ": teams = [ belong team ids ]" end
    if not x.teams[id] then x.team_list[#x.team_list + 1] = id end
    x.teams[id] = true
    x.any_team = true
  end
  for _, s in ipairs(list_of(p.series)) do
    -- the framework's series names (the index answers nil = not a series; not readable now = checked when evaluated)
    local ok, n = pcall(VRFW.chara.series_of, s)
    if ok and n == nil then
      local okn, names = pcall(VRFW.chara.series_names)
      return nil, string.format("%s %s: series %q (%s, or an alias of content\\defaults\\series_names.toml)", where, p.name,
        tostring(s), okn and type(names) == "table" and table.concat(names, " ") or "?")
    end
    x.series[#x.series + 1] = ok and n or s
    x.any_series = true
  end
  if p.role ~= nil then
    if not ROLES[p.role] then return nil, string.format("%s %s: role %q (manager, coach)", where, p.name, tostring(p.role)) end
    x.role = p.role
  end
  if p.gender ~= nil then
    x.gender = GENDER[tostring(p.gender)]
    if not x.gender then return nil, string.format("%s %s: gender %q (male, female)", where, p.name, tostring(p.gender)) end
  end
  for _, c in ipairs(list_of(p.charas)) do
    local id = chara_of(c)
    if id then x.charas[id] = true; x.any_chara = true end
  end
  for _, c in ipairs(list_of(p.exclude)) do
    local id = chara_of(c)
    if id then x.exclude[id] = true end
  end
  if not (x.any_team or x.any_series or x.role or x.gender or x.any_chara) then
    return nil, where .. " " .. p.name .. ": no criterion (teams, series, role, gender, charas): it would take everyone"
  end
  return x
end

local function read_syn(mod, file, s, i)
  local where = string.format("mods/%s/%s: [[VRFW.Synergy]] #%d", tostring(mod), tostring(file), i)
  for k in pairs(s) do
    if not SYN_KEYS[k] then return nil, where .. ": unknown key `" .. tostring(k) .. "`" end
  end
  local id = id_of(s.key)
  if not id then return nil, where .. ": key = \"<the game's synergy key, e.g. sp04003>\" is required" end
  local x = { id = id, key = tostring(s.key), mod = mod, nexus = {}, nexus_list = {}, count = tonumber(s.count) or 0,
    rule = s.rule or "min", distinct = s.distinct or "person", hint = s.hint and id_of(s.hint) or 0 }
  for _, c in ipairs(list_of(s.nexus)) do
    local b = chara_of(c)
    if b and not x.nexus[b] then
      x.nexus[b] = true
      x.nexus_list[#x.nexus_list + 1] = b
    end
  end
  x.has_nexus = #x.nexus_list > 0
  if s.slots ~= nil then
    -- one pool per slot (each slot filled by a different player of its pool), instead of `pool` + `count`
    if s.pool ~= nil or s.count ~= nil then return nil, where .. " " .. x.key .. ": `slots` replaces `pool` + `count`: give one or the other" end
    if type(s.slots) ~= "table" or #s.slots == 0 then return nil, where .. " " .. x.key .. ': slots = [ "<pool>", ... ] (one pool per slot)' end
    x.slot_keys = {}
    for _, n in ipairs(s.slots) do
      if type(n) ~= "string" then return nil, where .. " " .. x.key .. ": slots: pool names (text)" end
      x.slot_keys[#x.slot_keys + 1] = n:find(".", 1, true) and n or (tostring(mod) .. "." .. n)
    end
    if s.skip_nexus_team ~= nil and type(s.skip_nexus_team) ~= "boolean" then return nil, where .. " " .. x.key .. ": skip_nexus_team = true / false" end
    x.skip_nexus_team = s.skip_nexus_team == true
    if s.slot_members ~= nil and type(s.slot_members) ~= "boolean" then return nil, where .. " " .. x.key .. ": slot_members = true / false" end
    x.slot_members = s.slot_members == true
    if x.skip_nexus_team and not x.has_nexus then return nil, where .. " " .. x.key .. ": skip_nexus_team needs a nexus" end
    if x.rule ~= "min" then return nil, string.format("%s %s: rule %q: with `slots` every slot must be filled (rule min)", where, x.key, tostring(x.rule)) end
    x.count = #x.slot_keys - (x.skip_nexus_team and 1 or 0)
    x.pool_key = table.concat(x.slot_keys, " / ")
  elseif s.skip_nexus_team ~= nil then
    return nil, where .. " " .. x.key .. ": skip_nexus_team works with `slots` only"
  elseif s.slot_members ~= nil then
    return nil, where .. " " .. x.key .. ": slot_members works with `slots` only"
  end
  if x.count ~= math.floor(x.count) or x.count < 1 then return nil, where .. " " .. x.key .. ": count = <whole number ≥ 1> is required" end
  if x.count + (x.has_nexus and 1 or 0) > MAX_ROWS then
    return nil, string.format("%s %s: the nexus + count = %d rows: the panel shows %d at most", where, x.key, x.count + (x.has_nexus and 1 or 0), MAX_ROWS)
  end
  if x.rule ~= "min" and x.rule ~= "exact" then return nil, string.format("%s %s: rule %q (min, exact)", where, x.key, tostring(x.rule)) end
  if x.distinct ~= "person" and x.distinct ~= "character" then return nil, string.format("%s %s: distinct %q (person, character)", where, x.key, tostring(x.distinct)) end
  if not x.slot_keys then
    if type(s.pool) ~= "string" then return nil, where .. " " .. x.key .. ": pool = \"<a [[VRFW.SynergyPool]] name>\" is required" end
    x.pool_key = s.pool:find(".", 1, true) and s.pool or (tostring(mod) .. "." .. s.pool)
  end
  x.placeholder = s.placeholder and chara_of(s.placeholder) or nil
  return x
end

local function load_decls()
  local ok, files = pcall(VRFW.files.declarations, "content/synergies")
  if not ok or type(files) ~= "table" then return end
  local syns = {}
  for _, f in ipairs(files) do
    local d = f.data or {}
    if d.schema ~= nil and d.schema ~= "VRFW.synergy/1" then
      warn(string.format("mods/%s/%s: schema %q is not VRFW.synergy/1: file left out", tostring(f.mod), tostring(f.file), tostring(d.schema)))
    else
      local v = type(d.VRFW) == "table" and d.VRFW or {}
      for i, p in ipairs(v.SynergyPool or {}) do
        local x, why = read_pool(f.mod, f.file, p, i)
        if not x then warn(why .. ": left out")
        elseif POOLS[x.key] then warn(x.key .. ": declared twice: the second left out")
        else POOLS[x.key] = x end
      end
      for i, s in ipairs(v.Synergy or {}) do syns[#syns + 1] = { f = f, s = s, i = i } end
    end
  end
  for _, e in ipairs(syns) do
    local x, why = read_syn(e.f.mod, e.f.file, e.s, e.i)
    local miss = nil
    if x then
      for _, k in ipairs(x.slot_keys or { x.pool_key }) do
        if not POOLS[k] then miss = k; break end
      end
    end
    if not x then
      warn(why .. ": left out")
    elseif miss then
      warn(string.format("%s (mods/%s): pool %q is not declared: left out", x.key, tostring(x.mod), miss))
    elseif x.slot_members and (function()
      for _, k in ipairs(x.slot_keys) do
        if #POOLS[k].team_list == 0 then return true end
      end
      return false
    end)() then
      warn(string.format("%s (mods/%s): slot_members needs every slot pool to name its belong team(s) (`teams`): left out", x.key, tostring(x.mod)))
    elseif DECL[x.id] then
      warn(string.format("%s: declared by %s already: %s's left out", x.key, tostring(DECL[x.id].mod), tostring(x.mod)))
    else
      if x.slot_keys then
        x.slots = {}
        for j, k in ipairs(x.slot_keys) do x.slots[j] = POOLS[k] end
      else
        x.pool = POOLS[x.pool_key]
      end
      DECL[x.id] = x
      LIST[#LIST + 1] = x
    end
  end
end

load_decls()

-- ---------------------------------------------------------------------------------------------- character index

local IDX = nil          -- { base_of[param], card[base], role[base] = { manager, coach }, info[base] = { person, gender, series, teams }, ok }

-- The framework's character index (VRFW.chara: chara_param / chara_base / chara_series_config read once natively, by column name); taken at script load, else at the first check.
local function index()
  if IDX then return IDX end
  local t0 = VRFW.now()
  IDX = { card = {}, role = {}, info = {}, order = {} }
  -- a card's character, asked once per card id (the members' cards)
  IDX.base_of = setmetatable({}, { __index = function(t, param)
    local ok, b = pcall(VRFW.chara.base_of, param)
    if ok and type(b) == "number" then
      b = u32(b)
      rawset(t, param, b)
      return b
    end
    return nil
  end })
  local ok, e = pcall(function()
    for _, c in ipairs(VRFW.chara.characters()) do
      local id = u32(c.id)
      IDX.info[id] = {
        person = u32(c.name_text),
        gender = math.floor(c.gender or 0),
        series = math.floor(c.series or 0),
        teams = { u32(c.teams[1] or 0), u32(c.teams[2] or 0), u32(c.teams[3] or 0) },
      }
      if (c.cards or 0) > 0 then IDX.card[id] = true end
      if c.coach or c.manager then IDX.role[id] = { coach = c.coach or nil, manager = c.manager or nil } end
      IDX.order[#IDX.order + 1] = id
    end
  end)
  IDX.ok = ok
  if not ok then warn("character index not readable: " .. tostring(e) .. " (declared synergies stay off)") end
  info(string.format("character index: %d characters, %d staff, taken in %d ms (the framework's, shared)",
    #IDX.order, (function()
      local n = 0
      for _ in pairs(IDX.role) do n = n + 1 end
      return n
    end)(), math.floor(VRFW.now() - t0)))
  return IDX
end

-- The pool's members (chara_base ids in table order), resolved once: the characters listed in `charas` plus those matching the other criteria
-- (teams, series, role, gender), minus `exclude`.
local function pool_members(p)
  if p.members then return p.members end
  index()
  p.members, p.set = {}, {}
  local include = {}
  if p.any_chara then
    local ids = {}
    for b in pairs(p.charas) do ids[#ids + 1] = b end
    include[#include + 1] = { characters = ids }
  end
  if p.any_team or p.any_series or p.role or p.gender then
    include[#include + 1] = { team = p.any_team and p.team_list or nil, series = p.any_series and p.series or nil,
      role = p.role, gender = p.gender and { p.gender } or nil }
  end
  local exclude = {}
  for b in pairs(p.exclude) do exclude[#exclude + 1] = b end
  if #include > 0 then
    local ok, ids = pcall(VRFW.chara.select, { include = include, exclude = #exclude > 0 and { { characters = exclude } } or nil },
      { characters = true })
    if ok and type(ids) == "table" then
      for _, b in ipairs(ids) do
        b = u32(b)
        p.members[#p.members + 1] = b
        p.set[b] = true
      end
    else
      warn(string.format("pool %s: not evaluated (%s): no members", p.key, tostring(ids)))
    end
  end
  info(string.format("pool %s: %d characters", p.key, #p.members))
  return p.members
end

local function person(base, decl)
  if decl.distinct == "character" then return base end
  local c = IDX.info[base]
  return c and c.person or base
end

-- ---------------------------------------------------------------------------------------------- the check

local STATE = {}         -- answer address -> { sid, active, rows = { { kind, base } }, extra, team }
local STATE_N = 0
local LAST = {}          -- synergy id -> the last state line logged (one line per synergy and state, not per redraw)
local logs, ERRS = 0, {}

-- handle -> chara_base (cached: the check runs for every member card the menus draw; a handle keeps its card)
local HBASE, HBASE_N = {}, 0
local function base_of_handle(h)
  local b = HBASE[h]
  if b then return b end
  local ok, rec = pcall(VRFW.chara.record, h)
  if not ok or type(rec) ~= "table" or not rec.param then return nil end
  b = IDX.base_of[u32(rec.param)]
  if b then
    if HBASE_N > 4096 then HBASE, HBASE_N = {}, 0 end
    HBASE[h], HBASE_N = b, HBASE_N + 1
  end
  return b
end

-- the members the game counts: { { i, h, base, staff } } pitch first, then staff; the same list object is returned while the team's member slots are unchanged,
-- so a check whose members did not change reuses its answer (evaluate's memo)
local MEMBERS = {}       -- team address -> { signature, list }
local MEMBERS_N = 0
local function members(team)
  local kind = rd("u8", team + TEAM_KIND)
  if not kind or kind >= 2 then return nil end
  local limit = kind == 0 and 11 or 5
  local handles, classes = {}, {}
  for i = 0, N_MEMBERS - 1 do
    local m = team + MEMBER_BASE + i * MEMBER_STRIDE
    handles[i + 1] = rd("u32", m) or 0
    classes[i + 1] = rd("u8", m + MEMBER_CLASS) or 0xFF
  end
  local signature = kind .. ":" .. table.concat(handles, ",") .. ":" .. table.concat(classes, ",")
  local known = MEMBERS[team]
  if known and known.signature == signature then return known.list end
  local out, unresolved = {}, false
  for i = 0, N_MEMBERS - 1 do
    local h, cls = handles[i + 1], classes[i + 1]
    if h ~= 0 and (cls < limit or cls > 0x0F) and not (cls >= 0x14 and cls <= 0x1C) then
      local b = base_of_handle(h)
      if b then out[#out + 1] = { i = i, h = h, base = b, staff = cls >= 0x10 } else unresolved = true end
    end
  end
  table.sort(out, function(a, b)
    if a.staff ~= b.staff then return not a.staff end
    return a.i < b.i
  end)
  if not known then
    if MEMBERS_N > 32 then MEMBERS, MEMBERS_N = {}, 0 end
    MEMBERS_N = MEMBERS_N + 1
  end
  -- a handle not resolved yet (its card unknown): not kept, read again at the next check
  MEMBERS[team] = (not unresolved) and { signature = signature, list = out } or nil
  return out
end

-- ---------------------------------------------------------------------------------------------- slots

-- the slots in play: every declared slot except those whose pool names a belong team of the nexus (skip_nexus_team); at most the panel's room
local function active_slots(d, nexus_base)
  local out = {}
  local c = IDX.info[nexus_base or 0]
  local nt = c and c.teams or {}
  for _, p in ipairs(d.slots) do
    local skip = false
    if d.skip_nexus_team then
      for _, t in ipairs(nt) do
        if t ~= 0 and p.teams[t] then skip = true end
      end
    end
    if not skip then out[#out + 1] = p end
  end
  local room = MAX_ROWS - (d.has_nexus and 1 or 0)
  while #out > room do table.remove(out) end
  return out
end

-- one person per slot (a matching: a person whose cards fit several slots takes the one that leaves the others fillable; versions of one person count once).
-- Returns the filling card per slot and the unused persons who fit some slot (the «+N»).
local function fill_slots(d, slots, cands)
  local persons, order = {}, {}
  for _, m in ipairs(cands) do
    local k = person(m.base, d)
    local e = persons[k]
    if not e then
      e = { cards = {} }
      persons[k] = e
      order[#order + 1] = k
    end
    e.cards[#e.cards + 1] = m
  end
  local function card_for(k, p)
    for _, m in ipairs(persons[k].cards) do
      if p.set[m.base] then return m end
    end
    return nil
  end
  local owner, got = {}, {}
  local function try(si, seen)
    for _, k in ipairs(order) do
      if not seen[k] and card_for(k, slots[si]) then
        seen[k] = true
        if owner[k] == nil or try(owner[k], seen) then
          owner[k] = si
          got[si] = k
          return true
        end
      end
    end
    return false
  end
  for si = 1, #slots do try(si, {}) end
  local filled, extra = {}, 0
  for si = 1, #slots do filled[si] = got[si] and card_for(got[si], slots[si]) or nil end
  for _, k in ipairs(order) do
    if owner[k] == nil then extra = extra + 1 end
  end
  return filled, extra
end

local function evaluate_slots(d, team)
  local st = { sid = d.id, active = false, rows = {}, extra = 0, team = team ~= 0, marks = {} }
  local ms = (team ~= 0) and members(team) or nil
  local in_team = {}
  for _, m in ipairs(ms or {}) do in_team[m.base] = true end
  local nexus = nil
  if d.has_nexus then
    for _, m in ipairs(ms or {}) do
      if d.nexus[m.base] then nexus = m; break end
    end
    if nexus then
      st.rows[#st.rows + 1] = { kind = KIND_NEXUS, base = nexus.base }
      st.marks[#st.marks + 1] = nexus
    else
      st.rows[#st.rows + 1] = { kind = (team ~= 0) and KIND_NEXUS_MISSING or KIND_NEXUS, base = d.nexus_list[1] }
    end
  end
  local slots = active_slots(d, nexus and nexus.base or d.nexus_list[1])
  for _, p in ipairs(slots) do pool_members(p) end
  local np = nexus and person(nexus.base, d) or nil
  local cands = {}
  for _, m in ipairs(ms or {}) do
    if m ~= nexus and (np == nil or person(m.base, d) ~= np) then
      for _, p in ipairs(slots) do
        if p.set[m.base] then cands[#cands + 1] = m; break end
      end
    end
  end
  local filled, extra = fill_slots(d, slots, cands)
  local shown, all = {}, true
  for si, p in ipairs(slots) do
    local m = filled[si]
    if m then
      st.rows[#st.rows + 1] = { kind = KIND_FILLED, base = m.base, pool = p }
      st.marks[#st.marks + 1] = m
    else
      all = false
      local ph = nil
      for _, b in ipairs(p.members) do
        if not in_team[b] and not d.nexus[b] and not shown[b] then ph = b; break end
      end
      if ph then shown[ph] = true end
      st.rows[#st.rows + 1] = { kind = KIND_EMPTY, base = ph or 0, pool = p }
    end
  end
  st.extra = extra
  st.active = (team ~= 0) and all and (nexus ~= nil or not d.has_nexus)
  return st
end

-- ---------------------------------------------------------------------------------------------- one pool

-- the synergy's state for one team (team = 0: no team, e.g. the shop's panel), computed (evaluate: the memo)
local function evaluate_uncached(d, team)
  if d.slots then return evaluate_slots(d, team) end
  -- pool_members gives the member list; the membership set is the pool's own `set`
  local pool = pool_members(d.pool)
  local pset = d.pool.set
  local st = { sid = d.id, active = false, rows = {}, extra = 0, team = team ~= 0, marks = {} }
  local ms = (team ~= 0) and members(team) or nil
  local in_team = {}
  for _, m in ipairs(ms or {}) do in_team[m.base] = true end
  local nexus = nil
  if d.has_nexus then
    for _, m in ipairs(ms or {}) do
      if d.nexus[m.base] then nexus = m; break end
    end
    if nexus then
      st.rows[#st.rows + 1] = { kind = KIND_NEXUS, base = nexus.base }
      st.marks[#st.marks + 1] = nexus
    else
      st.rows[#st.rows + 1] = { kind = (team ~= 0) and KIND_NEXUS_MISSING or KIND_NEXUS, base = d.nexus_list[1] }
    end
  end
  local used, cand = {}, {}
  if nexus then used[person(nexus.base, d)] = true end
  for _, m in ipairs(ms or {}) do
    if m ~= nexus and pset[m.base] then
      local k = person(m.base, d)
      if not used[k] then
        used[k] = true
        cand[#cand + 1] = m
      end
    end
  end
  local shown = {}
  for k = 1, d.count do
    local m = cand[k]
    if m then
      st.rows[#st.rows + 1] = { kind = KIND_FILLED, base = m.base, pool = d.pool }
      st.marks[#st.marks + 1] = m
    else
      -- an empty slot: a pool character who is not in the team, a different one per slot (the panel draws the row
      -- unchecked; the menu patch hides his face and writes the hint)
      local ph = d.placeholder
      if not ph or in_team[ph] or shown[ph] then
        ph = nil
        for _, b in ipairs(pool) do
          if not in_team[b] and not d.nexus[b] and not shown[b] then ph = b; break end
        end
      end
      if ph then shown[ph] = true end
      st.rows[#st.rows + 1] = { kind = KIND_EMPTY, base = ph or 0, pool = d.pool }
    end
  end
  st.extra = math.max(0, #cand - d.count)
  local enough
  if d.rule == "exact" then enough = (#cand == d.count) else enough = (#cand >= d.count) end
  st.active = (team ~= 0) and enough and (nexus ~= nil or not d.has_nexus)
  return st
end

-- the synergy's state for one team; reused while the team's members list is the same object (no team: depends on the declaration only)
local function evaluate(d, team)
  index()
  local ms = (team ~= 0) and members(team) or false
  local memo = d.memo
  if memo and memo.team == team and memo.members == ms and ms ~= nil then return memo.state end
  local st = evaluate_uncached(d, team)
  d.memo = { team = team, members = ms, state = st }
  return st
end

local function write_answer(out, st)
  for i = 0, N_MEMBERS - 1 do wr("u32", out + 4 * i, 0) end
  for r = 0, 7 do wr("u8", out + ANS_ROWS + r, 0) end
  for _, m in ipairs(st.marks) do wr("u32", out + 4 * m.i, m.h) end
  for r, row in ipairs(st.rows) do
    if r <= 8 and (row.kind == KIND_NEXUS and st.team or row.kind == KIND_FILLED) then wr("u8", out + ANS_ROWS + r - 1, 1) end
  end
  wr("u8", out + ANS_ACTIVE, st.active and 1 or 0)
end

if #LIST > 0 then
  for _, d in ipairs(LIST) do pcall(VRFW.native.table_set, "Synergy.Declared", d.id, 1) end

  VRFW.on("hook:SynergyCheck:post", function(ev)
    local a = ev.args or {}
    local out, sidp, team = a[1], a[2], a[3]
    local d = DECL[rd("u32", sidp) or 0]
    if not d or not out or out < 0x10000 then return nil end
    local t0 = VRFW.now()
    local ok, st = pcall(evaluate, d, (team and team >= 0x10000) and team or 0)
    if not ok then
      local k = d.key .. ": " .. tostring(st)
      if not ERRS[k] and logs < 200 then ERRS[k] = true; logs = logs + 1; warn(k) end
      return nil
    end
    write_answer(out, st)
    if STATE_N > 64 then STATE, STATE_N = {}, 0 end
    if not STATE[out] then STATE_N = STATE_N + 1 end
    STATE[out] = st
    local parts = {}
    for _, r in ipairs(st.rows) do parts[#parts + 1] = string.format("%d:%08X", r.kind, r.base) end
    local line = string.format("%s: %s (%s, rows %s, +%d more)", d.key, st.active and "active" or "off",
      st.team and "team" or "no team", table.concat(parts, " "), st.extra)
    if LAST[d.id] ~= line and logs < 200 then
      LAST[d.id], logs = line, logs + 1
      info(string.format("%s; check %.1f ms", line, VRFW.now() - t0))
    end
    return nil
  end)

  local CUR = nil          -- the panel being drawn: { answer, sid }
  local PANEL = nil        -- the last panel drawn: { sid, state }

  VRFW.on("hook:SynergyDetail", function(ev)
    local a = ev.args or {}
    local sid = rd("u32", a[2]) or 0
    if DECL[sid] and a[3] then
      CUR = { answer = a[3], sid = sid }
      pcall(VRFW.native.table_set, "Synergy.Answers", a[3], 1)
    end
    return nil
  end)

  VRFW.on("hook:SynergyDetail:post", function(ev)
    local a = ev.args or {}
    if a[3] then pcall(VRFW.native.table_set, "Synergy.Answers", a[3], nil) end
    CUR = nil
    return nil
  end)

  VRFW.on("hook:SynergyDetailRows", function(ev)
    local a = ev.args or {}
    local list, answer = a[2], a[3]
    if not CUR or CUR.answer ~= answer then return nil end
    local st = STATE[answer]
    if not st or st.sid ~= CUR.sid then
      local ok, s2 = pcall(evaluate, DECL[CUR.sid], 0)
      if not ok then return nil end
      st = s2
    end
    local ids = rd("ptr", list)
    if not ids or ids < 0x10000 then return nil end
    for r = 1, MAX_ROWS do
      local row = st.rows[r]
      wr("u32", ids + 4 * (r - 1), row and row.base or 0)
    end
    PANEL = { sid = CUR.sid, state = st }
    return nil
  end)

  -- ------------------------------------------------------------------------------------------- the menu's command

  local NAMES = {}         -- language folder -> { [name text id] = name (false: none) }
  local NAME_IDS = nil     -- the name text ids a panel can show (every nexus and pool character), listed once

  local function name_ids()
    if NAME_IDS then return NAME_IDS end
    index()
    local seen, list = {}, {}
    local function add(b)
      local c = IDX.info[b or 0]
      local id = c and c.person
      if id and id ~= 0 and not seen[id] then seen[id] = true; list[#list + 1] = id end
    end
    for _, d in ipairs(LIST) do
      for _, b in ipairs(d.nexus_list or {}) do add(b) end
      if d.placeholder then add(d.placeholder) end
      for _, p in ipairs(d.slots or { d.pool }) do
        for _, b in ipairs(pool_members(p)) do add(b) end
      end
    end
    NAME_IDS = list
    return list
  end

  -- one game text table's rows for these ids in a language (en when that language has no such file): id -> text
  local function text_of_ids(file, lang, ids)
    local ok, rows = pcall(VRFW.files.text_rows, "data/common/text/" .. lang .. "/" .. file, ids)
    if (not ok or type(rows) ~= "table") and lang ~= "en" then
      ok, rows = pcall(VRFW.files.text_rows, "data/common/text/en/" .. file, ids)
    end
    local out = {}
    if ok and type(rows) == "table" then
      for _, id in ipairs(ids) do
        local r = rows[id]
        local v = r and r[0]
        if type(v) == "string" then out[id] = v end
      end
    end
    return out
  end

  local function lang_of(code)
    code = tonumber(code)
    if code and code >= 0 and type(VRFW.files.game_languages) == "function" then
      local ok, t = pcall(VRFW.files.game_languages)
      local l = ok and type(t) == "table" and t[math.floor(code) + 1] or nil
      if type(l) == "string" then return l end
    end
    return "en"
  end

  -- a character's name in that language: the listed ids are read once per language; an id outside the list is read alone
  local function name_of(base, lang)
    local t = NAMES[lang]
    if not t then
      local t0 = VRFW.now()
      local ids = name_ids()
      t = text_of_ids("chara_text.cfg.bin", lang, ids)
      NAMES[lang] = t
      info(string.format("names (%s): %d text ids read in %.1f ms", lang, #ids, VRFW.now() - t0))
    end
    local c = IDX and IDX.info[base]
    if not c then return "" end
    local s = t[c.person]
    if s == nil then
      s = text_of_ids("chara_text.cfg.bin", lang, { c.person })[c.person] or false
      t[c.person] = s
    end
    return s or ""
  end

  -- `[kanji/kana]` furigana markup reduced to the kanji (a team name inside a hint)
  local function no_furigana(s)
    return (s:gsub("%[([^/%]]*)/[^%]]*%]", "%1"))
  end

  -- belong team id -> its crest (item_emblem id of the first era that has one), read once at load
  local EMBLEMS = nil
  local TEAM_TEXT = {}     -- belong team id -> its name text id (team_text), from the same read
  local EMBLEM_COLS = { "team_emblem_id_ie", "team_emblem_id_go", "team_emblem_id_areori", "team_emblem_id_v" }
  local function emblems()
    if EMBLEMS then return EMBLEMS end
    EMBLEMS = {}
    local ok, e = pcall(function()
      for _, r in ipairs(VRFW.table.rows("character/belong_team") or {}) do
        local id = u32(r.belong_team_id or r[1] or 0)
        local text_id = u32(r.team_name_text_id or r.teamNameTextId or 0)
        if id ~= 0 and text_id ~= 0 then TEAM_TEXT[id] = text_id end
        for i, c in ipairs(EMBLEM_COLS) do
          local v = u32(r[c] or r[i + 3] or 0)   -- by the schema's name, else in column order (cols 3-6)
          if v ~= 0 then EMBLEMS[id] = v; break end
        end
      end
    end)
    if not ok then warn("team crests: " .. tostring(e)) end
    return EMBLEMS
  end

  -- the crests of a slot pool's teams, comma-joined (at most MAX_CRESTS, the panel's room)
  local MAX_CRESTS = 6
  local function crests_of(p)
    if not (p and p.team_list) then return "" end
    local m, out, seen = emblems(), {}, {}
    for _, t in ipairs(p.team_list) do
      local e = m[t]
      if e and not seen[e] and #out < MAX_CRESTS then seen[e] = true; out[#out + 1] = string.format("%d", e) end
    end
    return table.concat(out, ",")
  end

  -- a missing nexus (or the other persons beside a present one): every allowed nexus character, one card per person, comma-joined (at most MAX_FACES)
  local MAX_FACES = 3
  local function faces_of(d, skip_base)
    local out, seen = {}, {}
    if skip_base then seen[person(skip_base, d)] = true end
    for _, b in ipairs(d.nexus_list) do
      local k = person(b, d)
      if not seen[k] and #out < MAX_FACES then seen[k] = true; out[#out + 1] = string.format("%d", b) end
    end
    return table.concat(out, ",")
  end

  -- slot_members: the crest of a slot pool's first team (big square) and the pool's members' faces (one card per person; at most MAX_SLOT_FACES)
  local MAX_SLOT_FACES = 11
  local function crest_of(p)
    local t = p and p.team_list and p.team_list[1]
    local e = t and emblems()[t]
    return e and string.format("%d", e) or ""
  end

  local function members_faces(p, d)
    pool_members(p)
    local pick, order = {}, {}
    for _, b in ipairs(p.members) do
      local k = person(b, d)
      local cur = pick[k]
      if cur == nil then
        pick[k] = b
        order[#order + 1] = k
      elseif not IDX.card[cur] and IDX.card[b] then
        pick[k] = b
      end
    end
    local out = {}
    for i = 1, math.min(#order, MAX_SLOT_FACES) do out[i] = string.format("%d", pick[order[i]]) end
    return table.concat(out, ",")
  end

  -- the nexus is one person (every declared nexus character a version of him): the panel draws his face as the icon
  local function single_nexus(d)
    if d.single_nexus == nil then
      local first, one = nil, true
      for _, b in ipairs(d.nexus_list) do
        local k = person(b, d)
        if first == nil then first = k elseif k ~= first then one = false end
      end
      d.single_nexus = one and first ~= nil
    end
    return d.single_nexus
  end

  local TEAM_NAMES = {}    -- language folder -> { [belong team id] = name } (belong_team_config name text -> team_text)

  -- the name of a slot pool's (first) belong team in that language, "" when the pool names no team
  local function team_name(p, lang)
    local t = p and p.team_list and p.team_list[1]
    if not t then return "" end
    local m = TEAM_NAMES[lang]
    if not m then
      m = {}
      local ok, e = pcall(function()
        emblems()
        local ids, seen = {}, {}
        for _, d in ipairs(LIST) do
          for _, sp in ipairs(d.slots or { d.pool }) do
            local text_id = sp.team_list and TEAM_TEXT[sp.team_list[1] or 0]
            if text_id and not seen[text_id] then seen[text_id] = true; ids[#ids + 1] = text_id end
          end
        end
        local texts = text_of_ids("team_text.cfg.bin", lang, ids)
        for _, d in ipairs(LIST) do
          for _, sp in ipairs(d.slots or { d.pool }) do
            local team = sp.team_list and sp.team_list[1]
            local s = team and texts[TEAM_TEXT[team] or 0]
            if s then m[team] = no_furigana(s) end
          end
        end
      end)
      if not ok then warn("team names (" .. lang .. "): " .. tostring(e)) end
      TEAM_NAMES[lang] = m
    end
    return m[t] or ""
  end

  -- a staff pool's series as numbers, comma-joined (the panel draws their icons): the names resolved now when the index was not readable at load
  local function pool_series(p)
    if not (p and p.any_series) then return "" end
    if p.series_text then return p.series_text end
    local out = {}
    for _, s in ipairs(p.series) do
      local n = type(s) == "number" and s or nil
      if not n then
        local ok, v = pcall(VRFW.chara.series_of, s)
        n = ok and tonumber(v) or nil
      end
      if n then out[#out + 1] = string.format("%d", n) end
    end
    p.series_text = table.concat(out, ",")
    return p.series_text
  end

  -- the series icons the game's row draws for a character (its chara_base series flags, lowest first, at most 3; the
  -- panel redraws them beside the crests): the index's `appears`
  local MAX_ROW_SERIES = 3
  local ROW_SERIES = {}    -- chara_base id -> "a,b,c"
  local function row_series(base)
    if not base or base == 0 then return "" end
    local c = ROW_SERIES[base]
    if c then return c end
    local out = {}
    local ok, ch = pcall(VRFW.chara.character, base)
    if ok and type(ch) == "table" and type(ch.appears) == "table" then
      local ks = {}
      for k, on in pairs(ch.appears) do
        if on and tonumber(k) then ks[#ks + 1] = math.floor(tonumber(k)) end
      end
      table.sort(ks)
      for i = 1, math.min(#ks, MAX_ROW_SERIES) do out[i] = string.format("%d", ks[i]) end
    end
    c = table.concat(out, ",")
    ROW_SERIES[base] = c
    return c
  end

  -- CMND_VRFW_SYNERGY_PANEL(item id, language code) -> nil when the last panel drawn is not that declared synergy, else
  --   { active, extra, team, rows = { { kind (1 nexus, 2 nexus missing, 3 filled, 4 empty), name, hint, team_name, crests, faces, role, series } } }
  -- hint: the pool's own hint, else the synergy's; team_name: the hint's «{team}»; crests: item_emblem ids, comma-joined; faces: chara_base ids, comma-joined;
  -- single = 1 on a nexus row when the nexus is one person; role: an empty slot's staff role ("manager" / "coach", "" else);
  -- series: series numbers, comma-joined: an empty staff slot's required series, or a filled row's own (when it shows crests)
  local ANSWER = nil       -- the last answer: { state, lang, answer } (the panel redrawn with the same state)
  function Synergy.CmdPanel(item, code)
    local sid = u32(item)
    if not PANEL or PANEL.sid ~= sid then return nil end
    local d, st = DECL[sid], PANEL.state
    local lang = lang_of(code)
    if ANSWER and ANSWER.state == st and ANSWER.lang == lang then return ANSWER.answer end
    local rows = {}
    for r, row in ipairs(st.rows) do
      local members = d.slot_members and row.pool ~= nil
      rows[r] = { kind = row.kind, name = (row.kind ~= KIND_EMPTY) and name_of(row.base, lang) or "",
        hint = (row.pool and row.pool.hint) or d.hint,
        team_name = (row.kind == KIND_EMPTY) and team_name(row.pool, lang) or "",
        crests = ((row.kind == KIND_EMPTY or row.kind == KIND_FILLED) and not members) and crests_of(row.pool) or "",
        crest = members and crest_of(row.pool) or "",
        faces = (row.kind == KIND_NEXUS_MISSING) and faces_of(d)
          or (row.kind == KIND_NEXUS) and faces_of(d, row.base)
          or (members and row.kind == KIND_EMPTY) and members_faces(row.pool, d) or "",
        single = ((row.kind == KIND_NEXUS or row.kind == KIND_NEXUS_MISSING) and single_nexus(d)) and 1 or 0,
        base = row.base or 0 }
      local x = rows[r]
      local staff = row.kind == KIND_EMPTY and not members and row.pool and row.pool.role or nil
      x.role = staff or ""
      x.series = staff and pool_series(row.pool)
        or (row.kind == KIND_FILLED and x.crests ~= "") and row_series(row.base) or ""
    end
    local answer = { active = st.active and 1 or 0, extra = st.extra, team = st.team and 1 or 0, rows = rows }
    ANSWER = { state = st, lang = lang, answer = answer }
    return answer
  end

  -- the character index and every pool, once, at load; if not readable then, built at the first check
  local tw = VRFW.now()
  index()
  if IDX.ok then
    for _, d in ipairs(LIST) do
      for _, p in ipairs(d.slots or { d.pool }) do pool_members(p) end
    end
    info(string.format("index and pools ready at load in %d ms", math.floor(VRFW.now() - tw)))
    -- one line per declared synergy: its state without a team (proves the declaration evaluates end to end)
    for _, d in ipairs(LIST) do
      local ok, st = pcall(evaluate, d, 0)
      if ok then
        local parts = {}
        for _, r in ipairs(st.rows) do parts[#parts + 1] = string.format("%d:%08X", r.kind, r.base) end
        local sizes = {}
        for _, p in ipairs(d.slots or { d.pool }) do sizes[#sizes + 1] = string.format("%s %d", p.key, #(p.members or {})) end
        info(string.format("%s: ok at load (%s; no-team rows %s)", d.key, table.concat(sizes, ", "), table.concat(parts, " ")))
      else
        warn(string.format("%s: fails at load: %s", d.key, tostring(st)))
      end
    end
  else
    IDX = nil
    info("character index not readable at load: built at the first check")
  end

  if IDX then
    emblems()
    name_ids()
  end

  local names = {}
  for _, d in ipairs(LIST) do
    names[#names + 1] = string.format("%s (%s, %s%d of %s, %s)", d.key, tostring(d.mod), d.has_nexus and "nexus + " or "", d.count,
      d.pool_key, d.slots and ("one per slot" .. (d.skip_nexus_team and ", the nexus's team skipped" or "")
      .. (d.slot_members and ", rows: crest + members" or "")) or d.rule)
  end
  info(string.format("%d synergy(ies): %s; check hook %s, panel hooks %s", #LIST, table.concat(names, "; "),
    VRFW.is_on("SynergyCheck") and "on" or "OFF (not installed)",
    (VRFW.is_on("SynergyDetail") and VRFW.is_on("SynergyDetailRows")) and "on" or "OFF (not installed)"))
end

-- CMND_VRFW_SYNERGY_SHOP_CONDITIONS() -> the shop's synergy panel shows the condition card (config.toml [synergy]
-- shop_conditions, default true)
function Synergy.ShopConditions()
  return VRFW.files.config("synergy.shop_conditions") ~= false
end

-- No mod declares a synergy: the command is still a global and answers nil, so the menu patch leaves every panel as the game draws it.
if #LIST == 0 then
  function Synergy.CmdPanel() return nil end
  info("0 synergies declared (no active mod has content/synergies/*.toml): the game's check and panel unchanged")
end
