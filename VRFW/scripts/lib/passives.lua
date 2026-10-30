-- VR-Framework › the passive engine's data: every active mod's blocks (content\passive_blocks\*.toml, kind
-- VRFW.passive_block/1) and passives (content\special_passives\*.toml, kind VRFW.passive/1; the older kinds
-- SignaturePassives.passive_block/1 / special_passive/1 are read too), checked against the framework's block types
-- (content\types\passive_block.toml, passive.toml), names resolved.
--   local L = require "lib/passives"            -- the framework's scripts
--   local L = require "VRFW/lib/passives"       -- any other mod's scripts (a framework library)
--   local data = L.data(warn)                   -- built once per VM; files only, no game call
-- A passive: { key, mod, triggers, stack, resets, conditions, counts, filters, effects, slot, carried_by, worn, grant };
-- `worn` = it has a condition block of an equipment carrier (Wears / WearsSet): every player who meets it carries it;
-- `counts` = its SpiritsOut / Count blocks (role condition, scale count), `filters` = its target filters (Near),
-- `caps` = its [[PassiveCap]] entries ({ key, max }). A block naming a Trait (`trait`, `shooter_trait`) holds it resolved
-- as b.trait / b.shooter_trait.
-- data.tags[<name>] = { name, text, mod }, data.character_tags = { { character, tags, where } } (a later mod's entry of the
-- same character replaces an earlier one), data.caps[<mod>.<name>] = { key, max }.
-- data.spirits = the [[Spirit]] entries ({ aura, aliases, passives }), data.families[<mod>.<name>] = { auras },
-- data.grantable = the passives with grant = true. data.listen["<on>[:<arg>]"] = the passives that trigger or reset
-- on it; data.hooks[<trigger>] = the passives with an effect answered there; data.listen_set / data.hooks_set = the same as
-- sets ([key][passive] = true), for the per-event lookups.

local M = {}

local TWO32 = 4294967296
local BLOCK_KIND = "VRFW.passive_block/1"
local PASSIVE_KIND = "VRFW.passive/1"
-- the kinds these had while the engine was Signature Passives' (files still read under them)
local OLDER_KIND = { ["SignaturePassives.passive_block/1"] = BLOCK_KIND, ["SignaturePassives.special_passive/1"] = PASSIVE_KIND }

local Id = require "VRFW/lib/ids"
local u32 = Id.u32
M.u32 = u32

-- a number, "0x…", decimal text, or a key (its crc32) -> id; nil for nothing usable
function M.id_of(v)
  if type(v) == "number" then return u32(v) end
  if type(v) ~= "string" then return nil end
  local t = v:match("^%s*(.-)%s*$")
  if t == "" then return nil end
  local h = t:match("^0[xX](%x+)$")
  if h then return tonumber(h, 16) % TWO32 end
  if t:match("^%d+$") then return tonumber(t) % TWO32 end
  return u32(VRFW.crc32(t))
end

M.hex = Id.hex

-- ---------------------------------------------------------------------------------------------- schema checks

local function is_int(v) return type(v) == "number" and v == math.floor(v) end

local function allowed(spec, word)
  if type(spec.values) ~= "table" then return true end
  for _, w in ipairs(spec.values) do
    if w == word then return true end
  end
  return false
end

local function in_range(spec, v)
  return not ((spec.min and v < spec.min) or (spec.max and v > spec.max))
end

-- one value against its key spec: the value to keep, or nil + why
local function check_value(spec, v)
  local t = spec.type
  if t == "int" then
    if not is_int(v) then return nil, "a whole number" end
    if not in_range(spec, v) then return nil, string.format("%s..%s", tostring(spec.min or "-"), tostring(spec.max or "-")) end
    return v
  elseif t == "number" then
    if type(v) ~= "number" or v ~= v then return nil, "a number" end
    if not in_range(spec, v) then return nil, string.format("%s..%s", tostring(spec.min or "-"), tostring(spec.max or "-")) end
    return v
  elseif t == "bool" then
    if type(v) ~= "boolean" then return nil, "true / false" end
    return v
  elseif t == "string" or t == "name" then
    if type(v) ~= "string" then return nil, "a text" end
    if t == "name" and not v:match("^[a-z0-9_]+$") then return nil, "a name (a-z 0-9 _)" end
    if v ~= "" and not allowed(spec, v) then return nil, "one of " .. table.concat(spec.values, ", ") end
    return v
  elseif t == "ints" or t == "numbers" or t == "strings" then
    if type(v) ~= "table" then return nil, "a list" end
    local out = {}
    for i, x in ipairs(v) do
      if t == "ints" and (not is_int(x) or not in_range(spec, x)) then
        return nil, string.format("item %d: a whole number %s..%s", i, tostring(spec.min or "-"), tostring(spec.max or "-"))
      end
      if t == "numbers" and (type(x) ~= "number" or x ~= x or not in_range(spec, x)) then
        return nil, string.format("item %d: a number %s..%s", i, tostring(spec.min or "-"), tostring(spec.max or "-"))
      end
      if t == "strings" and (type(x) ~= "string" or x == "" or not allowed(spec, x)) then
        return nil, string.format("item %d: %s", i, spec.values and ("one of " .. table.concat(spec.values, ", ")) or "a text")
      end
      out[#out + 1] = x
    end
    return out
  end
  return nil, "the schema's type `" .. tostring(t) .. "` is unknown"
end

-- the key specs of an entry type (its table keys) and its plain keys (role, text, apply…)
local function split_entry(e)
  local keys, meta = {}, {}
  for k, x in pairs(e) do
    if type(x) == "table" then keys[k] = x else meta[k] = x end
  end
  return keys, meta
end

-- the entry types of the schema of `kind` and the schema file itself (its shared data tables): the framework's
-- content\types\ file of that kind, found through the declarations (so any mod's script reads the same file)
local function read_schema(kind)
  local ok, files = pcall(VRFW.files.declarations, "content/types")
  local t = nil
  for _, f in ipairs((ok and type(files) == "table") and files or {}) do
    local d = f.data
    if type(d) == "table" and d.schema == "VRFW.decl_schema/1" and d.kind == kind and type(d.entry) == "table" then t = d end
  end
  if not t then return nil, "no content\\types\\ schema of kind " .. kind end
  local types = {}
  for name, e in pairs(t.entry) do
    if type(e) == "table" then
      local keys, meta = split_entry(e)
      types[name] = { name = name, keys = keys, meta = meta }
    end
  end
  return types, t
end

-- every entry of `kind` in the active mods' `folder`, checked: { mod, file, type, index, where, v }
local function load_entries(folder, kind, types, warn)
  local out = {}
  local ok, files = pcall(VRFW.files.declarations, folder)
  if not ok or type(files) ~= "table" then return out end
  for _, f in ipairs(files) do
    local data = f.data or {}
    local where = string.format("mods/%s/%s", tostring(f.mod), tostring(f.file))
    if data.schema ~= kind and OLDER_KIND[data.schema] ~= kind then
      warn(string.format("%s: schema is not %q (file left out)", where, kind))
    else
      local PREFIX = tostring(data.schema):match("^([^.]+)")
      local own = type(data[PREFIX]) == "table" and data[PREFIX] or {}
      local names = {}
      for name in pairs(own) do names[#names + 1] = name end
      table.sort(names)
      for _, name in ipairs(names) do
        local ty, arr = types[name], own[name]
        if not ty then
          warn(string.format("%s: [[%s.%s]] is not a type of %s (left out)", where, PREFIX, tostring(name), kind))
        elseif type(arr) == "table" then
          for i, raw in ipairs(arr) do
            local w = string.format("%s: [[%s.%s]] #%d", where, PREFIX, name, i)
            local v, bad = {}, nil
            for k, x in pairs(raw) do
              local spec = ty.keys[k]
              if not spec then
                bad = "unknown key `" .. tostring(k) .. "`"
                break
              end
              local val, why = check_value(spec, x)
              if val == nil then
                bad = string.format("%s: %s", tostring(k), why)
                break
              end
              v[k] = val
            end
            if not bad then
              for k, spec in pairs(ty.keys) do
                if v[k] == nil then
                  if spec.required then
                    bad = tostring(k) .. " is required"
                    break
                  end
                  v[k] = spec.default
                end
              end
            end
            if bad then
              warn(w .. ": " .. bad .. " (left out)")
            else
              out[#out + 1] = { mod = tostring(f.mod), file = tostring(f.file), type = ty, index = i, where = w, v = v }
            end
          end
        end
      end
    end
  end
  return out
end

-- `name` as written by mod `mod`: its own `<name>`, else `<mod>.<name>`
local function lookup(map, mod, name)
  if type(name) ~= "string" then return nil end
  return map[mod .. "." .. name] or map[name]
end

local function add_to(map, key, p)
  map[key] = map[key] or {}
  for _, x in ipairs(map[key]) do
    if x == p then return end
  end
  table.insert(map[key], p)
end

local function event_key(b)
  return b.v.arg ~= "" and (b.v.on .. ":" .. b.v.arg) or b.v.on
end

-- ---------------------------------------------------------------------------------------------- the data

local DATA = nil
-- the events the interpreter makes itself (no behaviour-rule trigger): `carried`, `half_start`, `interval:<seconds>`
local ENGINE_EVENTS = { carried = true, half_start = true, interval = true }
M.ENGINE_EVENTS = ENGINE_EVENTS

-- blocks, passives and character entries of every active mod (built once)
function M.data(warn)
  if DATA then return DATA end
  local d = { blocks = {}, passives = {}, characters = {}, listen = {}, hooks = {}, has_stat = false, move_kinds = {}, positions = {},
    outcomes = {}, levels = {}, spirits = {}, families = {}, grantable = {}, spirit = {}, grant = {}, points = {}, keeper_duel = {},
    has_keeper_shooter = false, has_pool_cost = false, tags = {}, character_tags = {}, caps = {}, listen_set = {}, hooks_set = {},
    unit_moves = {}, genders = {}, has_trait = false, engine_events = {}, has_stamina = false, refresh = {} }
  local block_types, schema_or_err = read_schema(BLOCK_KIND)
  local passive_types, e2 = read_schema(PASSIVE_KIND)
  if not block_types or not passive_types then
    warn(tostring(block_types and e2 or schema_or_err) .. ": no special passive is read")
    DATA = d
    return d
  end
  d.move_kinds = type(schema_or_err.move_kinds) == "table" and schema_or_err.move_kinds or {}
  d.positions = type(schema_or_err.positions) == "table" and schema_or_err.positions or {}
  d.outcomes = type(schema_or_err.outcomes) == "table" and schema_or_err.outcomes or {}
  d.levels = type(schema_or_err.levels) == "table" and type(schema_or_err.levels.from_player_level) == "table" and schema_or_err.levels.from_player_level or {}
  d.points = type(schema_or_err.points) == "table" and schema_or_err.points or {}
  d.keeper_duel = type(schema_or_err.keeper_duel) == "table" and schema_or_err.keeper_duel or {}
  d.unit_moves = type(schema_or_err.unit_moves) == "table" and schema_or_err.unit_moves or {}
  d.genders = type(schema_or_err.genders) == "table" and schema_or_err.genders or {}
  d.refresh = type(schema_or_err.refresh) == "table" and schema_or_err.refresh or {}
  d.spirit = type(e2.spirit) == "table" and e2.spirit or {}
  d.grant = type(e2.grant) == "table" and e2.grant or {}
  for _, e in ipairs(load_entries("content/passive_blocks", BLOCK_KIND, block_types, warn)) do
    local key = e.mod .. "." .. e.v.name
    if d.blocks[key] then warn(e.where .. ": block " .. key .. " declared again (the later one is used)") end
    d.blocks[key] = { key = key, mod = e.mod, type = e.type.name, role = e.type.meta.role, meta = e.type.meta, v = e.v, where = e.where }
  end
  -- the Trait blocks other blocks name (`trait`, `shooter_trait`)
  for _, b in pairs(d.blocks) do
    for _, k in ipairs({ "trait", "shooter_trait" }) do
      local tn = b.v[k]
      if type(tn) == "string" and tn ~= "" then
        local t = lookup(d.blocks, b.mod, tn)
        if t and t.role == "trait" then
          b[k] = t
          d.has_trait = true
        else
          warn(b.where .. ": " .. k .. " `" .. tn .. "` is not a Trait block (the block never holds)")
          b[k] = false
        end
      end
    end
  end
  local chars, spirits, cap_names = {}, {}, {}
  for _, e in ipairs(load_entries("content/special_passives", PASSIVE_KIND, passive_types, warn)) do
    if e.type.name == "Passive" then
      local key = e.mod .. "." .. e.v.name
      local p = { key = key, mod = e.mod, triggers = {}, stack = nil, resets = {}, conditions = {}, counts = {}, filters = {}, effects = {},
        slot = nil, carried_by = {}, grant = e.v.grant == true, where = e.where, caps = {} }
      cap_names[p] = e.v.caps or {}
      for _, bn in ipairs(e.v.blocks) do
        local b = lookup(d.blocks, e.mod, bn)
        local role = b and b.role
        if not b then
          warn(e.where .. ": no block `" .. bn .. "` (left out of the passive)")
        elseif role == "trigger" then
          p.triggers[#p.triggers + 1] = b
        elseif role == "reset" then
          p.resets[#p.resets + 1] = b
        elseif role == "stack" then
          if p.stack then warn(e.where .. ": more than one Stack block (" .. b.key .. " left out)") else p.stack = b end
        elseif role == "condition" and b.meta.scale == "count" then
          p.counts[#p.counts + 1] = b
        elseif role == "condition" and b.meta.filter == "target" then
          p.filters[#p.filters + 1] = b
        elseif role == "trait" then
          warn(e.where .. ": `" .. bn .. "` is a Trait block: name it from a Present / Count / By / Holder block or an effect's `trait` (left out of the passive)")
        elseif role == "condition" then
          p.conditions[#p.conditions + 1] = b
          if b.meta.carrier == "equipment" then p.worn = true end
        elseif b.meta.apply == "own_slot" then
          if p.slot then warn(e.where .. ": more than one GamePassive block (" .. b.key .. " left out)") else p.slot = b end
        else
          p.effects[#p.effects + 1] = b
        end
      end
      for _, k in ipairs(e.v.carried_by or {}) do
        local id = M.id_of(k)
        if id and id ~= 0 then p.carried_by[#p.carried_by + 1] = id end
      end
      if d.passives[key] then warn(e.where .. ": passive " .. key .. " declared again (the later one is used)") end
      d.passives[key] = p
    elseif e.type.name == "Spirit" then
      spirits[#spirits + 1] = e
    elseif e.type.name == "PassiveCap" then
      local key = e.mod .. "." .. e.v.name
      d.caps[key] = { key = key, max = e.v.max_percent }
    elseif e.type.name == "Tag" then
      local before = d.tags[e.v.name]
      d.tags[e.v.name] = { name = e.v.name, text = (e.v.text ~= "" or not before) and e.v.text or before.text, mod = e.mod }
    elseif e.type.name == "CharacterTags" then
      d.character_tags[#d.character_tags + 1] = { character = e.v.character, tags = e.v.tags, where = e.where }
    elseif e.type.name == "SpiritFamily" then
      local key = e.mod .. "." .. e.v.name
      if d.families[key] then warn(e.where .. ": family " .. key .. " declared again (the later one is used)") end
      d.families[key] = { key = key, auras = e.v.auras, where = e.where }
    else
      chars[#chars + 1] = e
    end
  end
  -- the spirit entries: a later mod's entry of the same aura replaces an earlier one
  local by_aura = {}
  for _, e in ipairs(spirits) do
    local list = {}
    for _, pn in ipairs({ e.v.passive, e.v.synergy }) do
      if pn ~= nil and pn ~= "" then
        local p = lookup(d.passives, e.mod, pn)
        if p then list[#list + 1] = p else warn(e.where .. ": no passive `" .. pn .. "` (left out)") end
      end
    end
    local s = { mod = e.mod, where = e.where, aura = e.v.aura, aliases = e.v.aliases or {}, passives = list }
    if by_aura[e.v.aura] then
      d.spirits[by_aura[e.v.aura]] = s
    else
      d.spirits[#d.spirits + 1] = s
      by_aura[e.v.aura] = #d.spirits
    end
  end
  -- the caps each passive names
  for p, names in pairs(cap_names) do
    for _, cn in ipairs(names) do
      local c = lookup(d.caps, p.mod, cn)
      if c then p.caps[#p.caps + 1] = c else warn(p.where .. ": no passive cap `" .. cn .. "` (not capped by it)") end
    end
  end
  -- the tags the characters name must be declared
  for _, e in ipairs(d.character_tags) do
    for _, t in ipairs(e.tags) do
      if not d.tags[t] then warn(e.where .. ": tag `" .. t .. "` is not a [[Tag]] (it still counts for the Trait blocks naming it)") end
    end
  end
  -- one own passive per player: `passive`, or the first of an older `passives` list
  for _, e in ipairs(chars) do
    local list = {}
    local names = e.v.passives or {}
    local pn = (e.v.passive ~= nil and e.v.passive ~= "") and e.v.passive or names[1]
    if (e.v.passive ~= nil and e.v.passive ~= "" and #names > 0) or #names > 1 then
      warn(e.where .. ": a player has one own passive: " .. tostring(pn) .. " is used, the others are left out")
    end
    if pn then
      local p = lookup(d.passives, e.mod, pn)
      if p then list[1] = p else warn(e.where .. ": no passive `" .. pn .. "` (left out)") end
    else
      warn(e.where .. ": no `passive` (left out)")
    end
    if e.v.character == "" and e.v.card == "" then
      warn(e.where .. ": needs `character` or `card` (left out)")
    else
      d.characters[#d.characters + 1] = { mod = e.mod, where = e.where, character = e.v.character, card = e.v.card, passives = list }
    end
  end
  -- the events each passive someone can have listens to (carried_by, or named by a character entry), and the
  -- triggers its effects are answered on
  local live = {}
  for _, e in ipairs(d.characters) do
    for _, p in ipairs(e.passives) do live[p] = true end
  end
  for _, s in ipairs(d.spirits) do
    for _, p in ipairs(s.passives) do live[p] = true end
  end
  d.worn = {}
  for _, p in pairs(d.passives) do
    if #p.carried_by > 0 or p.worn or p.grant then live[p] = true end
    if p.worn then d.worn[#d.worn + 1] = p end
    if p.grant then d.grantable[#d.grantable + 1] = p end
  end
  table.sort(d.worn, function(a, b) return a.key < b.key end)
  table.sort(d.grantable, function(a, b) return a.key < b.key end)
  for p in pairs(live) do
    for _, b in ipairs(p.triggers) do
      add_to(d.listen, event_key(b), p)
      if ENGINE_EVENTS[b.v.on] then d.engine_events[b.v.on] = true end
    end
    for _, b in ipairs(p.resets) do add_to(d.listen, event_key(b), p) end
    for _, b in ipairs(p.effects) do
      if b.meta.apply == "stat" then d.has_stat = true end
      if b.meta.apply == "keeper" and b.v.side ~= "keeper" then d.has_keeper_shooter = true end
      if b.meta.apply == "pool_cost" then d.has_pool_cost = true end
      if b.meta.apply == "stamina_recovery" then d.has_stamina = true end
      for h in tostring(b.meta.hooks or ""):gmatch("[%w_]+") do add_to(d.hooks, h, p) end
    end
  end
  for _, map in ipairs({ d.listen, d.hooks }) do
    for _, list in pairs(map) do
      table.sort(list, function(a, b) return a.key < b.key end)
    end
  end
  for _, pair in ipairs({ { d.listen, d.listen_set }, { d.hooks, d.hooks_set } }) do
    for k, list in pairs(pair[1]) do
      local set = {}
      for _, p in ipairs(list) do set[p] = true end
      pair[2][k] = set
    end
  end
  DATA = d
  return d
end

M.event_key = event_key
M.lookup = lookup

-- ---------------------------------------------------------------------------------------------- characters

-- a character entry's chara_base id (a key / id resolved by the framework)
function M.character_id(value)
  if type(value) == "number" then return u32(value) end
  if type(value) ~= "string" or value == "" then return nil end
  local ok, id = pcall(VRFW.character, value)
  if ok and type(id) == "number" and id ~= 0 then return u32(id) end
  return M.id_of(value)
end

-- [chara_base id] = { card ids }: built once per VM from the character index
local CARDS_BY_BASE = nil

local function cards_of_character(value)
  local base = M.character_id(value)
  if base == nil or base == 0 then return {} end
  if CARDS_BY_BASE == nil then
    local index = {}
    for _, card in ipairs(VRFW.chara.cards()) do
      local b = u32(card.base)
      local list = index[b]
      if list == nil then
        list = {}
        index[b] = list
      end
      list[#list + 1] = u32(card.id)
    end
    CARDS_BY_BASE = index
  end
  local out = {}
  for i, c in ipairs(CARDS_BY_BASE[base] or {}) do out[i] = c end
  return out
end

-- the cards of a character entry ({ character } or { card })
function M.cards_of(e)
  if e.card ~= nil and e.card ~= "" then
    local c = M.id_of(e.card)
    return (c and c ~= 0) and { c } or {}
  end
  return cards_of_character(e.character)
end

return M
