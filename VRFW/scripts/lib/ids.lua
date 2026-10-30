-- The one way to read a game id (a crc, a chara_param, a handle) as a number in a mod script. Game ids are unsigned
-- 32-bit; the engine may hand them over as negative numbers (-1 for 4294967295). The menu side has the same functions
-- (assets\lua\menu\_all\84_ids.lua, VRFW_Id).
--   local Id = require "VRFW/lib/ids"        -- any mod's scripts (the framework's own: require "lib/ids")
--   Id.u32(v)          -> 0..4294967295: a number or numeric text, floored, modulo 2^32; true = 1, false = 0;
--                         nil, NaN, infinities and any other value = 0
--   Id.u32_or(v, none) -> as u32, but `none` (any value, nil included) when v is not a number, numeric text or boolean
--   Id.s32(v)          -> -2147483648..2147483647: u32(v) read as a signed 32-bit number
--   Id.is_none(v)      -> true for nil, -1 and 4294967295 (the engine's «no id»); 0 is an id
--   Id.hex(v)          -> "0x%04X%04X" of u32(v) (e.g. "0xC4DC849A")
-- Requiring it also sets VRFW.id to the same table in that script's VM.
local TWO_32 = 4294967296
local TWO_31 = 2147483648

local function number_of(v)
  local t = type(v)
  if t == "boolean" then
    return v and 1 or 0
  end
  if t ~= "number" and t ~= "string" then
    return nil
  end
  v = tonumber(v)
  if v == nil or v ~= v or v == math.huge or v == -math.huge then
    return nil
  end
  return v
end

local M = {}

function M.u32_or(v, none)
  local n = number_of(v)
  if n == nil then
    return none
  end
  return math.floor(n) % TWO_32
end

function M.u32(v)
  return M.u32_or(v, 0)
end

function M.s32(v)
  local n = M.u32(v)
  if n >= TWO_31 then
    return n - TWO_32
  end
  return n
end

function M.is_none(v)
  if v == nil then
    return true
  end
  local n = number_of(v)
  return n == -1 or n == TWO_32 - 1
end

function M.hex(v)
  local n = M.u32(v)
  return string.format("0x%04X%04X", math.floor(n / 65536), n % 65536)
end

if type(VRFW) == "table" and rawget(VRFW, "id") == nil then
  pcall(rawset, VRFW, "id", M)
end

return M
