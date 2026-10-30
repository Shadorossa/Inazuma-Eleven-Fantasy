-- InaRogue › INAROGUE: the rogue items (docs/game/modes/inarogue-passive-system.md §2.3-2.5, §2.7). Catalogue
-- content/rogue/items.toml (schema InaRogue.rogue_items/1), read once. The run holds them (rogue_run.json `items`,
-- lib/rogue/run.lua): one team inventory of [inventory] max_slots (5). An item is data: rarity, archetypes and effect
-- pieces (lib/rogue/pieces.lua) with values per level; its effects go through the shared effect functions
-- (lib/rogue/effects.lua) at the item's level. Each item counts 1 for every archetype it lists
-- (content/rogue/archetypes.toml), and the team's archetype rank is the number of items of the leading archetype (1-5).

local U = require "lib/rogue/util"
local E = require "lib/rogue/effects"
local P = require "lib/rogue/pieces"
local info, warn = U.logger("rogue items")

local I = {}

I.SCHEMA = "InaRogue.rogue_items/1"
I.FILE = "content/rogue/items.toml"
I.SCOPES = { outside = true, match = true, both = true }
I.KINDS = { passive = true, talent_up = true }
I.TALENT_MAX_LEVEL = 6

local FIELDS = { key = true, kind = true, rarity = true, scope = true, max_level = true, price = true,
  upgrade_cost = true, archetypes = true, sources = true, icon = true, effect = true, unlock = true }

local cat = nil

-- ---------------------------------------------------------------------------------------- archetypes

I.ARCHETYPE_FILE = "content/rogue/archetypes.toml"
I.ARCHETYPE_SCHEMA = "InaRogue.rogue_archetypes/1"
local arch = nil   -- { keys = { key, … } (number = position), by_number = { [n] = { scope, effects = { [rank] = … } } } }

local function archetypes()
  if arch then return arch end
  arch = { keys = {}, by_number = {} }
  local ok, t = pcall(VRFW.files.toml, I.ARCHETYPE_FILE)
  if not ok or type(t) ~= "table" or t.schema ~= I.ARCHETYPE_SCHEMA then
    warn(I.ARCHETYPE_FILE .. ": not readable or schema is not " .. I.ARCHETYPE_SCHEMA .. "; no archetypes")
    return arch
  end
  for k, a in ipairs(type(t.archetype) == "table" and t.archetype or {}) do
    local key = type(a.key) == "string" and a.key or ""
    local scope = a.scope or "match"
    if key == "" or key:find("[^a-z0-9_]") or U.index_of(arch.keys, key) then
      warn(string.format("%s [[archetype]] #%d: key `%s` (a-z 0-9 _, once): left out", I.ARCHETYPE_FILE, k, key))
    elseif not I.SCOPES[scope] then
      warn(string.format("%s [[archetype]] %s: scope `%s` (outside / match / both): left out", I.ARCHETYPE_FILE, key,
        tostring(scope)))
    else
      arch.keys[#arch.keys + 1] = key
      local by_rank = {}
      for rank = 1, 5 do
        local list, warns = E.parse_list(a.effect, rank, "archetype " .. key, 5)
        for _, w in ipairs(warns) do warn(I.ARCHETYPE_FILE .. ": " .. w) end
        by_rank[rank] = list
      end
      arch.by_number[#arch.keys] = { scope = scope, effects = by_rank }
    end
  end
  return arch
end

-- the archetype keys in file order (an archetype's number = its position = the pick_value of
-- content/archetypes/inarogue.toml)
function I.archetype_keys() return archetypes().keys end

-- ---------------------------------------------------------------------------------------- rarities

-- [[rarity]] key, max_level, price, upgrade_cost: the defaults of the items of that rarity; index = list position
local function parse_rarities(list)
  local out, by_key = {}, {}
  for k, r in ipairs(type(list) == "table" and list or {}) do
    local key = type(r) == "table" and type(r.key) == "string" and r.key or ""
    if key == "" or by_key[key] then
      warn(string.format("%s [[rarity]] #%d: key `%s` (once): left out", I.FILE, k, key))
    else
      local d = { key = key, index = #out + 1, max_level = U.clamp(U.int(r.max_level, 1), 1, 9),
        price = math.max(U.int(r.price, 0), 0), upgrade_cost = r.upgrade_cost }
      out[#out + 1] = d
      by_key[key] = d
    end
  end
  return out, by_key
end

-- ---------------------------------------------------------------------------------------- catalogue

local function parse_item(t, where, rarities)
  for k in pairs(t) do
    if not FIELDS[k] then return nil, where .. ": unknown field `" .. tostring(k) .. "`" end
  end
  local key = type(t.key) == "string" and t.key or ""
  if key == "" or key:find("[^a-z0-9_]") then return nil, where .. ": key `" .. key .. "` (a-z 0-9 _)" end
  local kind = t.kind or "passive"
  if not I.KINDS[kind] then return nil, where .. ": kind `" .. tostring(kind) .. "` (passive / talent_up)" end
  local rd = rarities.by_key[t.rarity or "common"]
  if not rd then
    local names = {}
    for _, r in ipairs(rarities.list) do names[#names + 1] = r.key end
    return nil, where .. ": rarity `" .. tostring(t.rarity) .. "` (" .. table.concat(names, " / ") .. ")"
  end
  local scope = t.scope or "match"
  if not I.SCOPES[scope] then return nil, where .. ": scope `" .. tostring(scope) .. "` (outside / match / both)" end
  local max_level = t.max_level == nil and rd.max_level or U.int(t.max_level, 1)
  if max_level < 1 or max_level > 9 then return nil, where .. ": max_level 1-9" end
  local price = t.price == nil and rd.price or U.int(t.price, 0)
  if price < 0 then return nil, where .. ": price >= 0" end
  local upgrade = {}
  local upgrade_cost = t.upgrade_cost
  if upgrade_cost == nil then upgrade_cost = rd.upgrade_cost end
  if type(upgrade_cost) == "table" then
    for i, v in ipairs(upgrade_cost) do upgrade[i] = math.max(U.int(v, 0), 0) end
  elseif type(upgrade_cost) == "number" then
    for i = 1, max_level - 1 do upgrade[i] = math.max(U.int(upgrade_cost, 0), 0) end
  else
    for i = 1, max_level - 1 do upgrade[i] = price * i end
  end
  local keys = I.archetype_keys()
  local archetypes_of = {}
  for _, a in ipairs(type(t.archetypes) == "table" and t.archetypes or {}) do
    local n = U.index_of(keys, a)
    if not n then return nil, where .. ": archetype `" .. tostring(a) .. "` (" .. table.concat(keys, " / ") .. ")" end
    archetypes_of[#archetypes_of + 1] = n
  end
  local sources = {}
  for _, s in ipairs(type(t.sources) == "table" and t.sources or {}) do
    if type(s) == "string" then sources[s] = true end
  end
  local effects = type(t.effect) == "table" and t.effect or {}
  -- the effects parse at every level once, so a bad value is reported at load and not in a match
  local by_level = {}
  for lv = 1, max_level do
    local list, warns = E.parse_list(effects, lv, where, max_level)
    for _, w in ipairs(warns) do warn(I.FILE .. ": " .. w) end
    -- the owner of each effect: its counters live in the owned item (rogue_run.json `counters`)
    for _, e in ipairs(list) do e.item = key end
    by_level[lv] = list
  end
  for _, e in ipairs(by_level[1]) do
    if not P.scope_ok(e.kind, scope) then
      warn(string.format("%s: %s: piece %s acts outside the item's scope `%s`", I.FILE, where, e.kind, scope))
    end
    if e.pending or e.pending_condition or (e.on and e.on.pending) or (e.count and e.count.pending) then
      info(string.format("%s: %s is pending an engine hook (no effect yet)", where, e.kind))
    end
  end
  return { key = key, kind = kind, rarity = rd.index, rarity_key = rd.key, scope = scope, max_level = max_level,
    price = price, upgrade = upgrade, archetypes = archetypes_of, sources = sources,
    icon = type(t.icon) == "string" and t.icon or rarities.icon, effects = by_level,
    matches = P.duration_matches(by_level[1]),
    -- meta unlock of the v2 runs (lib/rogue/meta_store.lua item_open): { runs_won, best_stage, ascension }
    unlock = type(t.unlock) == "table" and t.unlock or nil }
end

function I.catalogue()
  if cat then return cat end
  cat = { list = {}, by_key = {}, max_slots = 5, rarities = {} }
  local ok, t = pcall(VRFW.files.toml, I.FILE)
  if not ok or type(t) ~= "table" then
    warn(I.FILE .. ": " .. tostring(t) .. "; no items")
    return cat
  end
  if t.schema ~= I.SCHEMA then
    warn(I.FILE .. ": schema `" .. tostring(t.schema) .. "` (expected `" .. I.SCHEMA .. "`); no items")
    return cat
  end
  local inv = type(t.inventory) == "table" and t.inventory or {}
  cat.max_slots = U.clamp(U.int(inv.max_slots, 5), 1, 20)
  local defaults = type(t.defaults) == "table" and t.defaults or {}
  local rlist, rby = parse_rarities(t.rarity)
  cat.rarities = rlist
  local rarities = { list = rlist, by_key = rby, icon = type(defaults.icon) == "string" and defaults.icon or "" }
  for k, x in ipairs(type(t.item) == "table" and t.item or {}) do
    local where = string.format("[[item]] #%d %s", k, type(x) == "table" and tostring(x.key or "") or "")
    local it, why = parse_item(type(x) == "table" and x or {}, where, rarities)
    if not it then
      warn(I.FILE .. ": " .. why .. " (left out)")
    elseif cat.by_key[it.key] then
      warn(I.FILE .. ": item `" .. it.key .. "` declared twice (the second left out)")
    else
      cat.list[#cat.list + 1] = it
      cat.by_key[it.key] = it
    end
  end
  info(string.format("%d item(s), %d rarities, %d archetype(s), inventory of %d", #cat.list, #rlist,
    #I.archetype_keys(), cat.max_slots))
  return cat
end

function I.by_key(key)
  return I.catalogue().by_key[key]
end

-- the text key of a rarity's name (text/rows/rogue_items.toml)
function I.rarity_text_key(key)
  return "InaRogue.rogue_rarity_" .. key
end

-- a new owned item: level 1, its match count when one of its pieces lasts N matches
function I.new_owned(d)
  return { key = d.key, level = 1, counter = 0, matches_left = d.matches or 0, counters = {} }
end

-- the effects of an owned item at its level (scope outside / match / both); {} for an unknown item. A piece that
-- lasts N matches is over once the item's matches_left is 0.
function I.effects_of(owned)
  local d = I.by_key(owned.key)
  if not d then return {} end
  local list = d.effects[U.clamp(U.int(owned.level, 1), 1, d.max_level)] or {}
  if (owned.matches_left or 0) > 0 then return list end
  local out = {}
  for _, e in ipairs(list) do
    if e.duration ~= "matches" then out[#out + 1] = e end
  end
  return out
end

-- every effect of the inventory whose scope covers `where` ("match" / "outside")
function I.effects(items, where)
  local out = {}
  for _, o in ipairs(items or {}) do
    local d = I.by_key(o.key)
    if d and (d.scope == "both" or d.scope == where) then
      for _, e in ipairs(I.effects_of(o)) do out[#out + 1] = e end
    end
  end
  return out
end

-- every effect of the inventory whatever its scope (the blocks' triggers and counters)
function I.all_effects(items)
  local out = {}
  for _, o in ipairs(items or {}) do
    for _, e in ipairs(I.effects_of(o)) do out[#out + 1] = e end
  end
  return out
end

-- a match of the run was played: every item counting matches down loses one; true when one changed
function I.match_played(items)
  local changed = false
  for _, o in ipairs(items or {}) do
    if (o.matches_left or 0) > 0 then
      o.matches_left = o.matches_left - 1
      changed = true
      info(string.format("item %s: %d match(es) left", o.key, o.matches_left))
    end
  end
  return changed
end

-- the Rogue points to go from `level` to level + 1; nil at the maximum
function I.upgrade_cost(d, level)
  if level >= d.max_level then return nil end
  return d.upgrade[level] or d.price * level
end

-- the Rogue points a sale gives: half of what the item cost (price and every upgrade paid)
function I.sell_value(d, level)
  local spent = d.price
  for lv = 1, level - 1 do spent = spent + (d.upgrade[lv] or 0) end
  return math.floor(spent / 2)
end

-- the team's archetype from the inventory: leading archetype (its number, 1..n of content/rogue/archetypes.toml), rank
-- (its item count, 1-5), counts [1..n]. Ties: the most item levels among the tied archetypes; still tied = none (the
-- game's own «Libertad»). No item = 0, 0.
function I.archetype(items)
  local counts, levels = {}, {}
  local n = #I.archetype_keys()
  for a = 1, n do counts[a], levels[a] = 0, 0 end
  for _, o in ipairs(items or {}) do
    local d = I.by_key(o.key)
    if d then
      for _, a in ipairs(d.archetypes) do
        counts[a] = counts[a] + 1
        levels[a] = levels[a] + U.int(o.level, 1)
      end
    end
  end
  local best, lead, tied = 0, 0, false
  for a = 1, n do
    local c = counts[a]
    if c > best or (c == best and c > 0 and levels[a] > levels[lead]) then
      best, lead, tied = c, a, false
    elseif c == best and c > 0 and levels[a] == levels[lead] then
      tied = true
    end
  end
  if best == 0 or tied then return 0, 0, counts end
  return lead, math.min(best, 5), counts
end

-- the effects of the inventory's archetype at its rank whose scope covers `where` ("match" / "outside")
function I.archetype_effects(items, where)
  local lead, rank = I.archetype(items)
  local a = lead > 0 and archetypes().by_number[lead] or nil
  if not a or rank < 1 or not (a.scope == "both" or a.scope == where) then return {} end
  return a.effects[rank] or {}
end

return I
