-- Byte helpers of the team bank pages (Lua 5.2: no string.pack): little-endian u32 <-> 4-byte strings, a byte
-- string <-> an array of u32 words. Offsets are 0-based (as in the docs); word arrays are 1-based Lua arrays.

local B = {}

local band, rshift = bit32.band, bit32.rshift
local byte, char, concat = string.byte, string.char, table.concat

-- 4-byte little-endian string of a u32
function B.le32(v)
  v = band(v or 0, 0xFFFFFFFF)
  return char(band(v, 0xFF), band(rshift(v, 8), 0xFF), band(rshift(v, 16), 0xFF), rshift(v, 24))
end

-- u32 at byte offset `off` (0-based) of `s`; nil past the end
function B.rd32(s, off)
  local a, b, c, d = byte(s, off + 1, off + 4)
  if not d then
    return nil
  end
  return a + b * 0x100 + c * 0x10000 + d * 0x1000000
end

-- byte `k` (0 = lowest) of a u32 word
function B.byte_of(w, k)
  return band(rshift(w, k * 8), 0xFF)
end

-- `n` u32 words read from `s` at byte offset `off` (1-based array)
function B.words(s, off, n)
  local t = {}
  for i = 0, n - 1 do
    local a, b, c, d = byte(s, off + i * 4 + 1, off + i * 4 + 4)
    t[i + 1] = a + b * 0x100 + c * 0x10000 + d * 0x1000000
  end
  return t
end

-- the bytes of words `first..last` (1-based, inclusive; default the whole array)
function B.from_words(w, first, last)
  first, last = first or 1, last or #w
  local p, n = {}, 0
  for i = first, last do
    local v = w[i]
    n = n + 1
    p[n] = char(band(v, 0xFF), band(rshift(v, 8), 0xFF), band(rshift(v, 16), 0xFF), rshift(v, 24))
  end
  return concat(p)
end

-- `s` cut / 0-padded to `n` bytes
function B.pad(s, n)
  if #s >= n then
    return s:sub(1, n)
  end
  return s .. string.rep("\0", n - #s)
end

-- the bytes of `s` before its first 0
function B.cstr(s)
  local z = s:find("\0", 1, true)
  if z then
    return s:sub(1, z - 1)
  end
  return s
end

-- 40 hex digits -> 20 bytes (a bad digit pair = 0, as the Rust sha1_bytes); nil when `hex` is not a string
function B.hex_bytes(hex)
  if type(hex) ~= "string" then
    return nil
  end
  local p = {}
  for i = 0, 19 do
    p[i + 1] = char(tonumber(hex:sub(i * 2 + 1, i * 2 + 2), 16) or 0)
  end
  return concat(p)
end

-- 8 hex digits of a u32
function B.hex32(v)
  return string.format("%08X", band(v or 0, 0xFFFFFFFF))
end

return B
