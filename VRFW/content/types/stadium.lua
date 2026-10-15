-- Computed values of the type `stadium`. Each function gets the [[stadium]] fields (`map`, `picture`, `order`,
-- `unlock_item`) plus `mod`, `key`, `file`. `crc32(text)` is the game's name hash.

local M = {}

-- Default list position: after the game's own stadiums (their positions end at 91).
local DEFAULT_ORDER = 200

local BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

-- A written id: a number (its 32-bit pattern), "0x…" or a decimal, else a name (its crc32).
local function as_id(v)
  if type(v) == "number" then
    return v % 4294967296
  end
  local n = tonumber(v)
  if n then
    return n % 4294967296
  end
  return crc32(v)
end

-- Append the 4 big-endian bytes of a 32-bit number.
local function put_u32(bytes, n)
  n = n % 4294967296
  bytes[#bytes + 1] = math.floor(n / 16777216) % 256
  bytes[#bytes + 1] = math.floor(n / 65536) % 256
  bytes[#bytes + 1] = math.floor(n / 256) % 256
  bytes[#bytes + 1] = n % 256
end

local function base64(bytes)
  local out = {}
  for i = 1, #bytes, 3 do
    local a, b, c = bytes[i], bytes[i + 1], bytes[i + 2]
    local n = a * 65536 + (b or 0) * 256 + (c or 0)
    local s1 = math.floor(n / 262144) % 64
    local s2 = math.floor(n / 4096) % 64
    local s3 = math.floor(n / 64) % 64
    local s4 = n % 64
    out[#out + 1] = BASE64:sub(s1 + 1, s1 + 1) .. BASE64:sub(s2 + 1, s2 + 1)
      .. (b and BASE64:sub(s3 + 1, s3 + 1) or "=") .. (c and BASE64:sub(s4 + 1, s4 + 1) or "=")
  end
  return table.concat(out)
end

-- The list position (a byte: the game sorts the list by it).
function M.order(f)
  local n = f.order or DEFAULT_ORDER
  if n < 0 or n > 255 then
    error(string.format("order = %d: 0-255", n), 0)
  end
  return n
end

-- The unlock condition: 0 = always shown, else the game's condition `GetGlobalItemGetBitFlag(item) == 1`
-- (00 | u32 length | node count | call, hash argument, compared value, ==; docs/game/modes/fichajes.md §4.4).
function M.condition(f)
  if f.unlock_item == nil then
    return 0
  end
  local body = { 5, 0x35 }
  put_u32(body, crc32("GetGlobalItemGetBitFlag"))
  body[#body + 1] = 0
  body[#body + 1] = 10
  body[#body + 1] = 1
  for _, b in ipairs({ 0x28, 0, 6, 2, 0x34 }) do
    body[#body + 1] = b
  end
  put_u32(body, as_id(f.unlock_item))
  body[#body + 1] = 0x32
  put_u32(body, 1)
  body[#body + 1] = 0x78
  local raw = { 0 }
  put_u32(raw, #body)
  for _, b in ipairs(body) do
    raw[#raw + 1] = b
  end
  return { text = base64(raw) }
end

return M
