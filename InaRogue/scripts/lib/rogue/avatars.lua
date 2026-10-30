-- InaRogue › INAROGUE Rogue points and unlockable avatars (docs/game/modes/inarogue-avatars.md). Was
-- avatars.rs / avatars_rt.rs of the DLL's module rogue.
--
-- * The currency is a real item of the INAROGUE save ([rogue.points] item): the balance is its count in the bag. This
--   only decides how many points a run earns and keeps a ledger (pending / earned / given / spent); the menu Lua hands
--   the pending points to the bag and confirms.
-- * Avatars (content\rogue\avatars.toml, research/scripts/rogue_avatars_build.py): a price and an unlock condition (best phase);
--   the catalogue's `default` is always owned. Per slot, blob rogue_avatars.json (the DLL's JSON).

local U = require "lib/rogue/util"
local J = require "lib/rogue/json"
local info, warn, err = U.logger("rogue avatars")

local A = {}

A.SCHEMA, A.SCHEMA_V1, A.BLOB, A.VERSION = "inazuma_fantasy.rogue_avatars/2", "inazuma_fantasy.rogue_avatars/1", "rogue_avatars.json", 1
A.CODE = { OK = 0, ALREADY = 1, LOCKED = 2, WRITE_FAILED = 3, BAD_INDEX = 4, NOT_OWNED = 5, OFF = 6 }

-- ---------------------------------------------------------------------------------------- the points rules

-- points of a won node of `kind` (1 pachanga, 2 11v11, 7 Élite, 3 boss, 8 épico, 9 puerta) in `phase`
function A.for_win(pc, kind, phase)
  if not pc.enabled then return 0 end
  local idx = ({ [1] = 1, [2] = 2, [7] = 3, [3] = 4, [8] = 5, [9] = 6 })[kind]
  if not idx then return 0 end
  local base = pc.win[idx] or 0
  if base == 0 then return 0 end
  local p = math.max(phase, 1)
  local scale = pc.phase_step > 0 and math.floor((p - 1) / pc.phase_step) or 0
  local boss = (kind == 3 or kind == 9) and pc.boss_per_phase * p or 0
  return base + scale + boss
end

-- points of a run that ended (1 abandoned, 2 lost, 3 won) in `phase`
function A.for_run_end(pc, result, phase)
  if not pc.enabled or result == 0 then return 0 end
  local full = pc.run_end_per_phase * phase
  if result == 1 then return math.floor(full * math.min(pc.abandon_pct, 100) / 100) end
  return full
end

-- ---------------------------------------------------------------------------------------- the catalogue

local function builtin_default()
  return { id = "mark_raimon", name = "Mark Evans", team = "Raimon", texture = "#/menu/220_img/evt_rogue/evt_rogue_marker.g4tx",
    prefix = "mk_mark_raimon", unit = 1, ie3_team = 15, kit_palette = 2, body = 21, tier = 0, price = 0, best_phase = 0,
    captain = true }
end

-- the fields of a row: { name, type, required } (the DLL skipped a row with an unknown field or a missing / mistyped one)
local AVATAR_FIELDS = { { "id", "string", true }, { "name", "string", true }, { "team", "string", true },
  { "texture", "string", true }, { "prefix", "string", true }, { "unit", "number", true }, { "ie3_team", "number" },
  { "kit_palette", "number" }, { "body", "number" }, { "tier", "number" }, { "price", "number" }, { "best_phase", "number" },
  { "captain", "boolean" } }
local TEAM_FIELDS = { { "id", "number", true }, { "name", "string", true }, { "tier", "number" }, { "captain", "string", true },
  { "captain_rule", "string" }, { "crest", "boolean" } }
local function known(fields)
  local o = {}
  for _, f in ipairs(fields) do o[f[1]] = true end
  return o
end
local AVATAR_KNOWN, TEAM_KNOWN = known(AVATAR_FIELDS), known(TEAM_FIELDS)

-- a row against its fields: nil = fine, else why (unknown field, missing / wrong type)
local function check_row(r, fields, names)
  if type(r) ~= "table" then return "not a table" end
  for k in pairs(r) do
    if not names[k] then return "unknown field `" .. tostring(k) .. "`" end
  end
  for _, f in ipairs(fields) do
    local v = r[f[1]]
    if v == nil then
      if f[3] then return "missing field `" .. f[1] .. "`" end
    elseif type(v) ~= f[2] then
      return "field `" .. f[1] .. "`: " .. f[2] .. " expected"
    end
  end
  return nil
end

local function assemble(list, default, rows, warns)
  local by_id = {}
  for i, a in ipairs(list) do by_id[a.id] = i - 1 end
  local order, members = {}, {}
  for i, a in ipairs(list) do
    if not members[a.ie3_team] then
      order[#order + 1] = a.ie3_team
      members[a.ie3_team] = {}
    end
    local m = members[a.ie3_team]
    m[#m + 1] = i - 1
  end
  local teams = {}
  if #rows == 0 then
    for _, id in ipairs(order) do
      local m = members[id]
      local cap = m[1]
      for _, i in ipairs(m) do
        if list[i + 1].captain then
          cap = i
          break
        end
      end
      teams[#teams + 1] = { id = id, name = list[cap + 1].team, tier = list[cap + 1].tier, captain = cap, members = m,
        crest = true }
    end
  else
    for _, r in ipairs(rows) do
      local m = members[r.id]
      if not m then
        warns[#warns + 1] = string.format("team %d has no avatar (or is declared twice); skipped", r.id)
      else
        members[r.id] = nil
        local cap = by_id[r.captain]
        if cap == nil or not U.contains(m, cap) then
          warns[#warns + 1] = string.format("team %d: captain `%s` is not one of its avatars; its first avatar used", r.id, r.captain)
          cap = m[1]
        end
        local ord = { cap }
        for _, i in ipairs(m) do
          if i ~= cap then ord[#ord + 1] = i end
        end
        teams[#teams + 1] = { id = r.id, name = r.name, tier = r.tier or 0, captain = cap, members = ord,
          crest = r.crest ~= false }
      end
    end
  end
  return { list = list, default = default, teams = teams, by_id = by_id }
end

local function parse(t)
  if t.schema ~= A.SCHEMA and t.schema ~= A.SCHEMA_V1 then
    return nil, "schema `" .. tostring(t.schema) .. "` (expected `" .. A.SCHEMA .. "`)"
  end
  if type(t.default) ~= "string" then return nil, "missing field `default`" end
  local warns, seen, list = {}, {}, {}
  for n, r in ipairs(type(t.avatar) == "table" and t.avatar or {}) do
    local why = check_row(r, AVATAR_FIELDS, AVATAR_KNOWN)
    if why then
      warns[#warns + 1] = string.format("avatar row %d: %s; skipped", n, why)
    elseif r.id == "" or r.id:find("[^a-z0-9_]") then
      warns[#warns + 1] = string.format("avatar id `%s`: a-z 0-9 _; skipped", r.id)
    elseif r.texture == "" or r.prefix == "" then
      warns[#warns + 1] = string.format("avatar `%s`: texture and prefix are required; skipped", r.id)
    elseif seen[r.id] then
      warns[#warns + 1] = string.format("avatar `%s` declared twice; the first one kept", r.id)
    else
      seen[r.id] = true
      -- the parsed row itself becomes the entry (its optional fields defaulted): no copy of 5000+ rows
      r.ie3_team, r.kit_palette, r.body, r.tier = r.ie3_team or 0, r.kit_palette or 0, r.body or 0, r.tier or 0
      r.price, r.best_phase, r.captain = r.price or 0, r.best_phase or 0, r.captain == true
      list[#list + 1] = r
    end
  end
  local rows = {}
  for n, r in ipairs(type(t.team) == "table" and t.team or {}) do
    local why = check_row(r, TEAM_FIELDS, TEAM_KNOWN)
    if why then warns[#warns + 1] = string.format("team row %d: %s; skipped", n, why) else rows[#rows + 1] = r end
  end
  local default = nil
  for i, a in ipairs(list) do
    if a.id == t.default then default = i - 1 end
  end
  if default == nil then
    local b = builtin_default()
    warns[#warns + 1] = string.format("default `%s` is not an avatar; the built-in default `%s` used", t.default, b.id)
    for i, a in ipairs(list) do
      if a.id == b.id then default = i - 1 end
    end
    if default == nil then
      table.insert(list, 1, b)
      default = 0
    end
  end
  return assemble(list, default, rows, warns), warns
end

local cat = nil

function A.catalogue(acfg)
  if cat then return cat end
  local ok, t = pcall(VRFW.files.toml_cached or VRFW.files.toml, acfg.file)
  if not ok or type(t) ~= "table" then
    warn(acfg.file .. ": " .. tostring(t) .. "; only the default avatar")
  else
    local c, warns = parse(t)
    if not c then
      warn(acfg.file .. ": " .. warns .. "; only the default avatar")
    else
      for _, w in ipairs(warns) do warn(acfg.file .. ": " .. w) end
      cat = c
    end
  end
  if not cat then cat = assemble({ builtin_default() }, 0, {}, {}) end
  info(string.format("%d avatars in %d teams (default %s), enabled %s unlock_all %s", #cat.list, #cat.teams,
    cat.list[cat.default + 1].id, tostring(acfg.enabled), tostring(acfg.unlock_all)))
  return cat
end

function A.avatar(c, i) return c.list[i + 1] end
function A.default_avatar(c) return c.list[c.default + 1] end

-- ---------------------------------------------------------------------------------------- the profile

function A.new_profile(slot)
  return { slot = slot, owned = {}, set = {}, selected = "", points = { pending = 0, earned = 0, given = 0, spent = 0 } }
end

function A.is_owned(c, p, id)
  return A.default_avatar(c).id == id or p.set[id] == true
end

function A.team_owned(c, p, team)
  local n = 0
  for _, i in ipairs(team.members) do
    if A.is_owned(c, p, c.list[i + 1].id) then n = n + 1 end
  end
  return n
end

function A.owned_count(c, p)
  local n = 0
  for _, a in ipairs(c.list) do
    if A.is_owned(c, p, a.id) then n = n + 1 end
  end
  return n
end

-- the avatar in use: the selected one when it is in the catalogue and owned, else the default (0-based index)
function A.current(c, p)
  local i = c.by_id[p.selected]
  if i ~= nil and A.is_owned(c, p, c.list[i + 1].id) then return i end
  return c.default
end

function A.unlock(c, p, id, paid, added)
  if A.is_owned(c, p, id) then return false end
  p.owned[#p.owned + 1] = { id = id, paid = paid, added = added }
  p.set[id] = true
  p.points.spent = p.points.spent + paid
  return true
end

function A.undo_unlock(p, id)
  for i = #p.owned, 1, -1 do
    if p.owned[i].id == id then
      local o = table.remove(p.owned, i)
      p.set[id] = nil
      p.points.spent = math.max(p.points.spent - o.paid, 0)
      return
    end
  end
end

function A.select(c, p, id)
  if not A.is_owned(c, p, id) then return false end
  if A.default_avatar(c).id == id then p.selected = "" else p.selected = id end
  return true
end

function A.earn(p, n)
  p.points.pending = p.points.pending + n
  p.points.earned = p.points.earned + n
end

function A.given(p, n)
  n = math.min(n, p.points.pending)
  p.points.pending = p.points.pending - n
  p.points.given = p.points.given + n
  return p.points.pending
end

function A.to_json(p)
  local owned = {}
  for i, o in ipairs(p.owned) do owned[i] = J.obj({ { "id", o.id }, { "paid", o.paid }, { "added", o.added } }) end
  local pt = p.points
  return J.pretty(J.obj({ { "version", A.VERSION }, { "slot", p.slot }, { "owned", J.arr(owned) }, { "selected", p.selected },
    { "points", J.obj({ { "pending", pt.pending }, { "earned", pt.earned }, { "given", pt.given }, { "spent", pt.spent } }) } }))
end

function A.from_json(j, slot)
  if type(j) ~= "table" or type(j.version) ~= "number" or type(j.slot) ~= "number" then return nil, "missing field" end
  if j.version ~= A.VERSION then return nil, "unknown version " .. tostring(j.version) end
  local p = A.new_profile(slot)
  p.selected = type(j.selected) == "string" and j.selected or ""
  local pt = type(U.val(j.points)) == "table" and j.points or {}
  p.points = { pending = U.int(pt.pending, 0), earned = U.int(pt.earned, 0), given = U.int(pt.given, 0), spent = U.int(pt.spent, 0) }
  local seen = {}
  for _, o in ipairs(type(j.owned) == "table" and j.owned or {}) do
    if type(o) == "table" and type(o.id) == "string" and not seen[o.id] then
      seen[o.id] = true
      p.set[o.id] = true
      p.owned[#p.owned + 1] = { id = o.id, paid = U.int(o.paid, 0), added = U.int(o.added, 0) }
    end
  end
  return p
end

local profile = nil

-- the active slot's profile (a corrupt blob is set aside: a new profile); needs no catalogue, so the points ledger never
-- parses the avatar file
function A.with_profile(slot)
  if profile and profile.slot == slot then return profile end
  local text, why = U.blob_read(A.BLOB, slot)
  local p = nil
  if text == false then
    err(string.format("slot %d: %s unreadable (%s): a new profile for now", slot, A.BLOB, tostring(why)))
  elseif text then
    local j, e = U.json(text)
    if j then p, e = A.from_json(j, slot) end
    if not p then
      local kept = U.blob_aside(A.BLOB, slot)
      err(string.format("slot %d: %s: %s; %s; no usable previous version: new profile", slot, A.BLOB, tostring(e), tostring(kept)))
    end
  end
  p = p or A.new_profile(slot)
  info(string.format("slot %d: %d avatar(s) bought, selected %s, points pending %d (earned %d, spent %d)", slot,
    #p.owned, p.selected ~= "" and p.selected or "the default", p.points.pending, p.points.earned, p.points.spent))
  profile = p
  return p
end

function A.forget()
  profile = nil
end

-- write the profile; false = failed (the caller undoes its change)
function A.commit(p, what)
  local ok, where = U.blob_write(A.BLOB, A.to_json(p), p.slot)
  if ok then
    info(what .. " -> " .. tostring(where))
  else
    err(string.format("cannot write %s (%s): %s", A.BLOB, what, tostring(where)))
  end
  return ok
end

return A
