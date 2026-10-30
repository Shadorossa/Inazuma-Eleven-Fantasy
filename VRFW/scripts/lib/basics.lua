-- The everyday helpers of a mod script: values with a default, the mod's config with a default, a tagged logger.
--   require "VRFW/lib/basics"     -- any mod's scripts, the framework's own included
-- Requiring it sets VRFW.value, VRFW.config and VRFW.logger in that script's VM (and returns them as one table).
--   VRFW.value.num(v, default)    -> v as a number (a number or numeric text; NaN is not a number), else default
--   VRFW.value.int(v, default)    -> num(v) truncated toward zero, else default
--   VRFW.value.bool(v, default)   -> default when v is nil, else v == true
--   VRFW.value.list(v, default)   -> v when it is a table, { v } for one other value, default when v is nil
--   VRFW.config(path, default)    -> the mod's config value at a dotted path (VRFW.files.config); default when the
--                                    value is missing or cannot be read
--   VRFW.logger(tag)              -> info, warn, err: each writes one line "<tag>: ..." through VRFW.log / VRFW.warn /
--                                    VRFW.error
-- VRFW.crc32(text) is built in and already unsigned (0..4294967295); VRFW.ui.crc32 is the same hash.

local floor, ceil = math.floor, math.ceil

local value = {}

function value.num(v, default)
  v = tonumber(v)
  if v == nil or v ~= v then
    return default
  end
  return v
end

function value.int(v, default)
  v = value.num(v, nil)
  if v == nil then
    return default
  end
  if v >= 0 then
    return floor(v)
  end
  return ceil(v)
end

function value.bool(v, default)
  if v == nil then
    return default
  end
  return v == true
end

function value.list(v, default)
  if v == nil then
    return default
  end
  if type(v) ~= "table" then
    return { v }
  end
  return v
end

local function config(path, default)
  local files = VRFW.files
  if type(files) ~= "table" then
    return default
  end
  local ok, v = pcall(files.config, path)
  if ok and v ~= nil then
    return v
  end
  return default
end

local function logger(tag)
  local prefix = tostring(tag) .. ":"
  local function info(...)
    VRFW.log(prefix, ...)
  end
  local function warn(...)
    VRFW.warn(prefix, ...)
  end
  local function err(...)
    VRFW.error(prefix, ...)
  end
  return info, warn, err
end

local M = { value = value, config = config, logger = logger }

if type(VRFW) == "table" then
  for k, f in pairs(M) do
    if rawget(VRFW, k) == nil then
      pcall(rawset, VRFW, k, f)
    end
  end
end

return M
