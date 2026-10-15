-- Souls Rework › the totem data: every active mod's content\souls\*.toml (kind SoulsRework.soul/1) checked against this
-- module's schema content\types\soul.toml as the framework's declaration reader does (unknown key, value type, range,
-- `values`, required); an entry that fails is left out with one warning. A later mod's Totem of the same aura, or
-- Skill of the same name, replaces the earlier one. (The level rule is config.toml [levels].)
--   local D = require "lib/data"
--   local data = D.load(warn)   -- { totems = { [aura key] = Totem }, skills = { [name] = Skill },
--                               --   move_kinds = { [kind] = category } }
-- Totem.slots = its 6 parsed slots { skill = Skill, level = n, text = "<skill>:<n>" }.

local M = {}

local PREFIX = "SoulsRework"
local KIND = "SoulsRework.soul/1"
local SCHEMA_FILE = "content/types/soul.toml"
local FOLDER = "content/souls"

local function is_int(v) return type(v) == "number" and v == math.floor(v) end

local function in_range(spec, x)
  return not ((spec.min and x < spec.min) or (spec.max and x > spec.max))
end

local function allowed(spec, x)
  if type(spec.values) ~= "table" then return true end
  for _, w in ipairs(spec.values) do
    if w == x then return true end
  end
  return false
end

-- one value against its key spec: the value to keep, or nil + why
local function check_value(spec, v)
  local t = spec.type
  if t == "int" or t == "number" then
    if type(v) ~= "number" or v ~= v or (t == "int" and not is_int(v)) then return nil, t == "int" and "a whole number" or "a number" end
    if not in_range(spec, v) then return nil, string.format("%s..%s", tostring(spec.min or "-"), tostring(spec.max or "-")) end
    return v
  elseif t == "bool" then
    if type(v) ~= "boolean" then return nil, "true / false" end
    return v
  elseif t == "string" or t == "name" then
    if type(v) ~= "string" then return nil, "a text" end
    if t == "name" and not v:match("^[a-z0-9_]+$") then return nil, "a name (a-z 0-9 _)" end
    if not allowed(spec, v) then return nil, "not one of its values" end
    return v
  elseif t == "ints" or t == "numbers" or t == "strings" then
    if type(v) ~= "table" then return nil, "a list" end
    local out = {}
    for i, x in ipairs(v) do
      if t == "strings" then
        if type(x) ~= "string" or x == "" or not allowed(spec, x) then return nil, string.format("item %d: a text of its values", i) end
      elseif type(x) ~= "number" or (t == "ints" and not is_int(x)) or not in_range(spec, x) then
        return nil, string.format("item %d: a number %s..%s", i, tostring(spec.min or "-"), tostring(spec.max or "-"))
      end
      out[#out + 1] = x
    end
    return out
  end
  return nil, "the schema's type `" .. tostring(t) .. "` is unknown"
end

-- the key specs of each entry type (its table keys)
local function read_schema()
  local t, err = VRFW.files.toml(SCHEMA_FILE)
  if type(t) ~= "table" or t.schema ~= "VRFW.decl_schema/1" or t.kind ~= KIND or type(t.entry) ~= "table" then
    return nil, SCHEMA_FILE .. ": " .. tostring(err or "not the " .. KIND .. " schema")
  end
  local types = {}
  for name, e in pairs(t.entry) do
    if type(e) == "table" then
      local keys = {}
      for k, spec in pairs(e) do
        if type(spec) == "table" then keys[k] = spec end
      end
      types[name] = keys
    end
  end
  return types, t
end

-- one entry checked: the values (defaults filled) or nil + why
local function check_entry(keys, e)
  local v = {}
  for k, x in pairs(e) do
    local spec = keys[k]
    if not spec then return nil, "unknown key `" .. tostring(k) .. "`" end
    local ok, why = check_value(spec, x)
    if ok == nil then return nil, k .. ": " .. why end
    v[k] = ok
  end
  for k, spec in pairs(keys) do
    if v[k] == nil then
      if spec.required then return nil, "`" .. k .. "` is required" end
      v[k] = spec.default
    end
  end
  return v
end

local function parse_slot(text, skills)
  local name, level = text:match("^([a-z0-9_]+):(%d+)$")
  if not name then name, level = text, "1" end
  local s = skills[name]
  if not s then return nil, "skill `" .. name .. "` is not declared" end
  level = tonumber(level)
  local n = math.max(#s.values, #s.units, #s.seconds, 1)
  if level < 1 or level > n then return nil, string.format("%s: level %d (it has %d)", name, level, n) end
  return { skill = s, level = level, text = text }
end

function M.load(warn)
  local out = { totems = {}, skills = {}, move_kinds = {}, count = 0 }
  local types, schema = read_schema()
  if not types then
    warn(schema)
    return out
  end
  for kind, m in pairs(type(schema.move_kinds) == "table" and schema.move_kinds or {}) do
    if type(m) == "table" and type(m.category) == "number" then out.move_kinds[kind] = m.category end
  end
  local ok, files = pcall(VRFW.files.declarations, FOLDER)
  if not ok or type(files) ~= "table" then
    warn(FOLDER .. ": no declarations (" .. tostring(files) .. ")")
    return out
  end
  local totems = {}
  for _, f in ipairs(files) do
    local data = f.data or {}
    local where = string.format("mods/%s/%s", tostring(f.mod), tostring(f.file))
    if data.schema ~= KIND then
      warn(string.format("%s: schema is not %q (file left out)", where, KIND))
    else
      local own = type(data[PREFIX]) == "table" and data[PREFIX] or {}
      for _, name in ipairs({ "Skill", "Totem" }) do
        for i, e in ipairs(type(own[name]) == "table" and own[name] or {}) do
          local v, why = check_entry(types[name] or {}, e)
          if not v then
            warn(string.format("%s: %s #%d left out: %s", where, name, i, why))
          elseif name == "Skill" then
            out.skills[v.name] = v
          else
            v.where = where
            totems[v.aura] = v
          end
        end
      end
    end
  end
  -- the slots need every mod's skills
  for key, t in pairs(totems) do
    local slots, bad = {}, nil
    for i, text in ipairs(t.roulette) do
      local s, why = parse_slot(text, out.skills)
      if not s then bad = string.format("slot %d: %s", i, why) break end
      slots[i] = s
    end
    if bad or #slots == 0 or #t.sp == 0 then
      warn(string.format("%s: Totem %s left out: %s", t.where, key, bad or "no slots / no SP route"))
    else
      t.slots = slots
      out.totems[key] = t
      out.count = out.count + 1
    end
  end
  return out
end

return M
