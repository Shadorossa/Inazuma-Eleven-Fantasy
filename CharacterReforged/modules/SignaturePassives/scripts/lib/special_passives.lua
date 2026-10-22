-- Signature Passives › the passives as data: every active mod's blocks (content\passive_blocks\*.toml, kind
-- SignaturePassives.passive_block/1) and passives (content\special_passives\*.toml, kind SignaturePassives.special_passive/1),
-- checked against this mod's block types (content\types\passive_block.toml, special_passive.toml), names resolved,
-- and the own passive slot of each card (GamePassive blocks; the older content\own_passives\*.toml declarations too).
--   local L = require "lib/special_passives"
--   local data = L.data(warn)            -- built once per VM; files only, no game call
--   local slots = L.own_slots(warn)      -- [card id] = { passive, always, mod }
-- A passive: { key, mod, triggers, stack, resets, conditions, effects, slot, carried_by }. data.listen["<on>[:<arg>]"]
-- = the passives that trigger or reset on it; data.hooks[<trigger>] = the passives with an effect answered there.

local M = {}

local TWO32 = 4294967296
local BLOCK_KIND = "SignaturePassives.passive_block/1"
local PASSIVE_KIND = "SignaturePassives.special_passive/1"
local OWN_KIND = "SignaturePassives.own_passives/1"
local PREFIX = "SignaturePassives"

local function u32(v)
  if type(v) ~= "number" then return 0 end
  local n = v >= 0 and math.floor(v) or math.ceil(v)
  return n % TWO32
end
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

function M.hex(v)
  v = u32(v)
  return string.format("0x%04X%04X", math.floor(v / 65536), v % 65536)
end

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

-- the entry types of a schema file and the file itself (its shared data tables)
local function read_schema(file)
  local t, err = VRFW.files.toml(file)
  if type(t) ~= "table" or t.schema ~= "VRFW.decl_schema/1" or type(t.entry) ~= "table" then
    return nil, file .. ": " .. tostring(err or "not a VRFW.decl_schema/1 file")
  end
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
    if data.schema ~= kind then
      warn(string.format("%s: schema is not %q (file left out)", where, kind))
    else
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

-- blocks, passives and character entries of every active mod (built once)
function M.data(warn)
  if DATA then return DATA end
  local d = { blocks = {}, passives = {}, characters = {}, listen = {}, hooks = {}, has_stat = false, move_kinds = {}, positions = {},
    outcomes = {}, levels = {} }
  local block_types, schema_or_err = read_schema("content/types/passive_block.toml")
  local passive_types, e2 = read_schema("content/types/special_passive.toml")
  if not block_types or not passive_types then
    warn(tostring(block_types and e2 or schema_or_err) .. ": no special passive is read")
    DATA = d
    return d
  end
  d.move_kinds = type(schema_or_err.move_kinds) == "table" and schema_or_err.move_kinds or {}
  d.positions = type(schema_or_err.positions) == "table" and schema_or_err.positions or {}
  d.outcomes = type(schema_or_err.outcomes) == "table" and schema_or_err.outcomes or {}
  d.levels = type(schema_or_err.levels) == "table" and type(schema_or_err.levels.from_player_level) == "table" and schema_or_err.levels.from_player_level or {}
  for _, e in ipairs(load_entries("content/passive_blocks", BLOCK_KIND, block_types, warn)) do
    local key = e.mod .. "." .. e.v.name
    if d.blocks[key] then warn(e.where .. ": block " .. key .. " declared again (the later one is used)") end
    d.blocks[key] = { key = key, mod = e.mod, type = e.type.name, role = e.type.meta.role, meta = e.type.meta, v = e.v, where = e.where }
  end
  local chars = {}
  for _, e in ipairs(load_entries("content/special_passives", PASSIVE_KIND, passive_types, warn)) do
    if e.type.name == "Passive" then
      local key = e.mod .. "." .. e.v.name
      local p = { key = key, mod = e.mod, triggers = {}, stack = nil, resets = {}, conditions = {}, effects = {}, slot = nil, carried_by = {}, where = e.where }
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
        elseif role == "condition" then
          p.conditions[#p.conditions + 1] = b
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
    else
      chars[#chars + 1] = e
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
  for _, p in pairs(d.passives) do
    if #p.carried_by > 0 then live[p] = true end
  end
  for p in pairs(live) do
    for _, b in ipairs(p.triggers) do add_to(d.listen, event_key(b), p) end
    for _, b in ipairs(p.resets) do add_to(d.listen, event_key(b), p) end
    for _, b in ipairs(p.effects) do
      if b.meta.apply == "stat" then d.has_stat = true end
      for h in tostring(b.meta.hooks or ""):gmatch("[%w_]+") do add_to(d.hooks, h, p) end
    end
  end
  for _, map in ipairs({ d.listen, d.hooks }) do
    for _, list in pairs(map) do
      table.sort(list, function(a, b) return a.key < b.key end)
    end
  end
  DATA = d
  return d
end

M.event_key = event_key

-- ---------------------------------------------------------------------------------------------- characters

-- a character entry's chara_base id (a key / id resolved by the framework)
function M.character_id(value)
  if type(value) == "number" then return u32(value) end
  if type(value) ~= "string" or value == "" then return nil end
  local ok, id = pcall(VRFW.character, value)
  if ok and type(id) == "number" and id ~= 0 then return u32(id) end
  return M.id_of(value)
end

local function cards_of_character(value)
  local base = M.character_id(value)
  if base == nil or base == 0 then return {} end
  local out = {}
  for _, card in ipairs(VRFW.chara.cards()) do
    if u32(card.base) == base then out[#out + 1] = u32(card.id) end
  end
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

-- ---------------------------------------------------------------------------------------------- own passive slot

-- [card id] = { passive = id, always = bool, mod = id }: the GamePassive block of each character's passives, and the
-- older content\own_passives\*.toml declarations. A later entry for the same card replaces an earlier one.
function M.own_slots(warn, info)
  local map, n_entries = {}, 0
  local function put(cards, passive, always, mod, where)
    if #cards == 0 then
      warn(where .. ": no card found (left out)")
      return
    end
    for _, c in ipairs(cards) do
      local before = map[c]
      if before ~= nil and before.mod ~= mod and info then
        info(string.format("card %s: the own passive of %s replaces the one of %s", M.hex(c), mod, before.mod))
      end
      map[c] = { passive = passive, always = always, mod = mod }
    end
  end
  local ok, files = pcall(VRFW.files.declarations, "content/own_passives")
  for _, f in ipairs((ok and type(files) == "table") and files or {}) do
    local doc = f.data
    local where0 = string.format("mods/%s/%s", tostring(f.mod), tostring(f.file))
    if type(doc) ~= "table" or doc.schema ~= OWN_KIND then
      warn(where0 .. ": schema is not " .. OWN_KIND .. " (file left out)")
    else
      for k, e in ipairs(type(doc.own_passive) == "table" and doc.own_passive or {}) do
        local where = string.format("%s [[own_passive]] #%d", where0, k)
        local passive = M.id_of(e.passive)
        local unlock = e.unlock == nil and "board" or e.unlock
        if unlock ~= "board" and unlock ~= "always" then
          warn(where .. ": unlock must be \"board\" or \"always\" (taken as \"board\")")
          unlock = "board"
        end
        if passive == nil or passive == 0 then
          warn(where .. ": no passive (left out)")
        elseif e.character == nil and e.card == nil then
          warn(where .. ": needs `character` or `card` (left out)")
        else
          n_entries = n_entries + 1
          put(M.cards_of({ character = e.character, card = e.card }), passive, unlock == "always", tostring(f.mod), where)
        end
      end
    end
  end
  for _, e in ipairs(M.data(warn).characters) do
    local slot = nil
    for _, p in ipairs(e.passives) do
      if p.slot then
        if slot then warn(e.where .. ": " .. p.key .. " also has a GamePassive block (his slot holds one: " .. slot.key .. ")") else slot = p.slot end
      end
    end
    if slot then
      local passive = M.id_of(slot.v.passive)
      if passive and passive ~= 0 then
        n_entries = n_entries + 1
        put(M.cards_of(e), passive, slot.v.unlock == "always", e.mod, e.where)
      end
    end
  end
  return map, n_entries
end

return M
