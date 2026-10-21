-- Reads a service's declarations: every active mod's files of one kind (`<folder>\**\*.toml`, schema `<kind>`), each [[VRFW.<Entry>]] checked against
-- content\types\<type>.toml (VRFW.decl_schema/1) and its `when` conditions against the declaring mod's config; an invalid declaration is left out with one warning.
--   local D = require "lib/declarations"
--   local schema = D.schema("card_type")                      -- content\types\card_type.toml (nil, why)
--   for _, d in ipairs(D.load(schema, warn)) do … end         -- { mod, file, entry, index, key, given, v }
-- `d.v` = every key of the entry (defaults filled), `d.given` = keys the file wrote (a later mod overrides only those), `d.key` = "<mod>.<name>" when the entry has a `name`.

local M = {}

local function crc(s)
  local f = VRFW.crc32 or (VRFW.ui and VRFW.ui.crc32)
  return f(s) % 4294967296
end

-- "0x…" / decimal text / a number -> the number; any other text -> its crc32 (a game key name)
function M.id_of(v)
  if type(v) == "number" then
    if v ~= math.floor(v) then return nil end
    return v % 4294967296
  end
  if type(v) ~= "string" or v == "" then return nil end
  local h = v:match("^%s*0[xX](%x+)%s*$")
  if h then return tonumber(h, 16) % 4294967296 end
  if v:match("^%s*%d+%s*$") then return tonumber(v) % 4294967296 end
  return crc(v)
end

-- the schema file of a service type (content\types\<type>.toml of the framework mod)
function M.schema(type_name)
  local t, err = VRFW.files.toml("content/types/" .. type_name .. ".toml")
  if type(t) ~= "table" then
    return nil, "content/types/" .. type_name .. ".toml: " .. tostring(err)
  end
  if t.schema ~= "VRFW.decl_schema/1" or type(t.kind) ~= "string" or type(t.folder) ~= "string" or type(t.entry) ~= "table" then
    return nil, "content/types/" .. type_name .. ".toml: not a VRFW.decl_schema/1 file (kind, folder, [entry.<Name>])"
  end
  return t
end

local function is_int(v) return type(v) == "number" and v == math.floor(v) end

local COND_KEYS = { config = true, default = true, equals = true, ["not"] = true, above = true, below = true }

local function check_when(v)
  local list = v
  if type(v) == "table" and v.config ~= nil then list = { v } end
  if type(list) ~= "table" then return nil, "a condition { config = \"a.b\", default = …, equals / not / above / below = … } or a list of them" end
  for i, c in ipairs(list) do
    if type(c) ~= "table" or type(c.config) ~= "string" or c.config == "" then
      return nil, string.format("condition #%d: config = \"<dotted path of the mod's config>\" is required", i)
    end
    for k in pairs(c) do
      if not COND_KEYS[k] then return nil, string.format("condition #%d: unknown key `%s` (config, default, equals, not, above, below)", i, tostring(k)) end
    end
    if (c.above ~= nil and type(c.above) ~= "number") or (c.below ~= nil and type(c.below) ~= "number") then
      return nil, string.format("condition #%d: above / below take a number", i)
    end
  end
  return list
end

-- one value against its field spec: the value to keep, or nil + why
local function check_value(spec, v)
  local t = spec.type
  if t == "int" then
    if not is_int(v) then return nil, "a whole number" end
    if (spec.min and v < spec.min) or (spec.max and v > spec.max) then
      return nil, string.format("%s..%s", tostring(spec.min or "-"), tostring(spec.max or "-"))
    end
    return v
  elseif t == "number" then
    if type(v) ~= "number" or v ~= v then return nil, "a number" end
    if (spec.min and v < spec.min) or (spec.max and v > spec.max) then
      return nil, string.format("%s..%s", tostring(spec.min or "-"), tostring(spec.max or "-"))
    end
    return v
  elseif t == "bool" then
    if type(v) ~= "boolean" then return nil, "true / false" end
    return v
  elseif t == "string" then
    if type(v) ~= "string" then return nil, "a text" end
    return v
  elseif t == "name" then
    if type(v) ~= "string" or not v:match("^[a-z0-9_]+$") then return nil, "a name (a-z 0-9 _)" end
    return v
  elseif t == "ints" then
    if type(v) ~= "table" then return nil, "a list of whole numbers" end
    local out = {}
    for i, x in ipairs(v) do
      if not is_int(x) or (spec.min and x < spec.min) or (spec.max and x > spec.max) then
        return nil, string.format("item %d: a whole number %s..%s", i, tostring(spec.min or "-"), tostring(spec.max or "-"))
      end
      out[#out + 1] = x
    end
    return out
  elseif t == "numbers" then
    if type(v) ~= "table" then return nil, "a list of numbers" end
    local out = {}
    for i, x in ipairs(v) do
      if type(x) ~= "number" or x ~= x or (spec.min and x < spec.min) or (spec.max and x > spec.max) then
        return nil, string.format("item %d: a number %s..%s", i, tostring(spec.min or "-"), tostring(spec.max or "-"))
      end
      out[#out + 1] = x
    end
    return out
  elseif t == "strings" then
    if type(v) ~= "table" then return nil, "a list of texts" end
    local out = {}
    for i, x in ipairs(v) do
      if type(x) ~= "string" or x == "" then return nil, string.format("item %d: a text", i) end
      out[#out + 1] = x
    end
    return out
  elseif t == "ids" then
    if type(v) ~= "table" then return nil, "a list of names or ids" end
    local out = {}
    for i, x in ipairs(v) do
      local id = M.id_of(x)
      if not id then return nil, string.format("item %d: a name or an id (0x…)", i) end
      out[#out + 1] = id
    end
    return out
  elseif t == "when" then
    return check_when(v)
  end
  return nil, "the schema's type `" .. tostring(t) .. "` is unknown"
end

-- the conditions hold on mod `mod`'s merged config (a missing value = the condition's default)
function M.holds(mod, conds)
  for _, c in ipairs(conds or {}) do
    local ok, v = pcall(VRFW.files.config, c.config, mod)
    if not ok or v == nil then v = c.default end
    if c.equals ~= nil then
      if v ~= c.equals then return false end
    elseif c["not"] ~= nil then
      if v == c["not"] then return false end
    elseif c.above ~= nil or c.below ~= nil then
      local n = tonumber(v)
      if not n then return false end
      if c.above ~= nil and not (n > c.above) then return false end
      if c.below ~= nil and not (n < c.below) then return false end
    elseif v == nil or v == false or v == 0 then
      return false
    end
  end
  return true
end

-- Declarations of the schema's kind in load order, checked; `warn(text)` gets one line per rejected one (unmet `when` = skipped silently, counted in `skipped`).
function M.load(schema, warn)
  local out, skipped = {}, 0
  local ok, files = pcall(VRFW.files.declarations, schema.folder)
  if not ok or type(files) ~= "table" then return out, skipped end
  for _, f in ipairs(files) do
    local data = f.data or {}
    local where = string.format("mods/%s/%s", tostring(f.mod), tostring(f.file))
    if data.schema ~= nil and data.schema ~= schema.kind then
      warn(string.format("%s: schema %q is not %s: file left out", where, tostring(data.schema), schema.kind))
    else
      for k in pairs(data) do
        if k ~= "schema" and k ~= "VRFW" then warn(string.format("%s: unknown key `%s` (only schema and [[VRFW.<entry>]])", where, tostring(k))) end
      end
      local vrfw = type(data.VRFW) == "table" and data.VRFW or {}
      for entry, arr in pairs(vrfw) do
        local spec = schema.entry[entry]
        if not spec then
          warn(string.format("%s: [[VRFW.%s]] is not a declaration of %s: left out", where, tostring(entry), schema.kind))
        elseif type(arr) == "table" then
          for i, raw in ipairs(arr) do
            local w = string.format("%s: [[VRFW.%s]] #%d", where, entry, i)
            local v, given, bad = {}, {}, nil
            for k, x in pairs(raw) do
              local fs = spec[k]
              if type(fs) ~= "table" then
                bad = "unknown key `" .. tostring(k) .. "`"
                break
              end
              local val, why = check_value(fs, x)
              if val == nil then
                bad = string.format("%s: %s", tostring(k), why)
                break
              end
              v[k], given[k] = val, true
            end
            if not bad then
              for k, fs in pairs(spec) do
                if type(fs) == "table" and v[k] == nil then
                  if fs.required then
                    bad = tostring(k) .. " is required"
                    break
                  end
                  v[k] = fs.default
                end
              end
            end
            if bad then
              warn(w .. ": " .. bad .. ": left out")
            elseif v.when and not M.holds(f.mod, v.when) then
              skipped = skipped + 1
            else
              out[#out + 1] = { mod = f.mod, file = f.file, entry = entry, index = i, where = w, v = v, given = given,
                key = v.name and (tostring(f.mod) .. "." .. v.name) or nil }
            end
          end
        end
      end
    end
  end
  -- (the kinds of one file come in no fixed order; each kind keeps load order, file order and declaration order)
  return out, skipped
end

return M
