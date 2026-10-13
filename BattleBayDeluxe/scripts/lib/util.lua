-- Battle Bay Deluxe: helpers shared by campaign.lua and draft.lua (one VM: draft.lua is required by campaign.lua).
-- Numbers: Lua 5.2 doubles. Hashes are u32 (0 .. 2^32-1); the game's T2B ints come signed (u32() fixes them).
-- The 64-bit seeded generator is SplitMix64 on two 32-bit halves (bit32), the generator bb_chronicle_teams.dll used.

local U = {}

local band, bor, bxor = bit32.band, bit32.bor, bit32.bxor
local lshift, rshift = bit32.lshift, bit32.rshift
local floor = math.floor
local TWO32 = 4294967296
U.TWO32 = TWO32

-- ------------------------------------------------------------------------------------------------ numbers

-- a number as u32 (signed T2B ints, negative Lua numbers from the game's Lua); 0 for anything else
function U.u32(v)
  if type(v) ~= "number" then
    return 0
  end
  return floor(v) % TWO32
end

-- an integer argument of a command (nil = default)
function U.int(v, default)
  if type(v) == "number" then
    return floor(v)
  end
  if v == true then
    return 1
  end
  if v == false then
    return 0
  end
  return default
end

function U.hex(v)
  return string.format("0x%08X", U.u32(v))
end

-- round half away from zero (Rust f32::round)
function U.round(x)
  if x >= 0 then
    return floor(x + 0.5)
  end
  return -floor(-x + 0.5)
end

function U.trim(s)
  return (string.gsub(s or "", "^%s*(.-)%s*$", "%1"))
end

-- ------------------------------------------------------------------------------------------------ CRC-32 (IEEE)

local CRC = {}
for i = 0, 255 do
  local c = i
  for _ = 1, 8 do
    if band(c, 1) ~= 0 then
      c = bxor(rshift(c, 1), 0xEDB88320)
    else
      c = rshift(c, 1)
    end
  end
  CRC[i] = c
end

-- CRC-32 of the bytes of `s` (the game's hash of a key: crc32fast::hash)
function U.crc32(s)
  local c = 0xFFFFFFFF
  for i = 1, #s do
    c = bxor(CRC[band(bxor(c, string.byte(s, i)), 0xFF)], rshift(c, 8))
  end
  return bxor(c, 0xFFFFFFFF)
end

-- ------------------------------------------------------------------------------------------------ SplitMix64

local function add64(ah, al, bh, bl)
  local lo = al + bl
  local carry = 0
  if lo >= TWO32 then
    lo = lo - TWO32
    carry = 1
  end
  return (ah + bh + carry) % TWO32, lo
end

-- (a * b) mod 2^64 on 16-bit limbs (every partial sum stays below 2^53)
local function mul64(ah, al, bh, bl)
  local a0, a1, a2, a3 = al % 65536, floor(al / 65536), ah % 65536, floor(ah / 65536)
  local b0, b1, b2, b3 = bl % 65536, floor(bl / 65536), bh % 65536, floor(bh / 65536)
  local c0 = a0 * b0
  local c1 = a0 * b1 + a1 * b0
  local c2 = a0 * b2 + a1 * b1 + a2 * b0
  local c3 = a0 * b3 + a1 * b2 + a2 * b1 + a3 * b0
  local r0 = c0 % 65536
  c1 = c1 + floor(c0 / 65536)
  local r1 = c1 % 65536
  c2 = c2 + floor(c1 / 65536)
  local r2 = c2 % 65536
  c3 = c3 + floor(c2 / 65536)
  local r3 = c3 % 65536
  return r2 + r3 * 65536, r0 + r1 * 65536
end

-- z ^ (z >> k), 0 < k < 32
local function xorshr(h, l, k)
  local sl = bor(rshift(l, k), lshift(h, 32 - k))
  return bxor(h, rshift(h, k)), bxor(l, sl)
end

local Rng = {}
Rng.__index = Rng

-- a generator seeded with the 64-bit value hi:lo
function U.rng(hi, lo)
  return setmetatable({ h = U.u32(hi), l = U.u32(lo) }, Rng)
end

-- a seed from a Lua number (a config value: exact up to 2^53) as hi, lo
function U.split64(n)
  n = floor(math.max(0, n or 0))
  return floor(n / TWO32) % TWO32, n % TWO32
end

-- the next 64-bit output as hi, lo
function Rng:next()
  self.h, self.l = add64(self.h, self.l, 0x9E3779B9, 0x7F4A7C15)
  local h, l = xorshr(self.h, self.l, 30)
  h, l = mul64(h, l, 0xBF58476D, 0x1CE4E5B9)
  h, l = xorshr(h, l, 27)
  h, l = mul64(h, l, 0x94D049BB, 0x133111EB)
  return xorshr(h, l, 31)
end

-- uniform in 0 .. n-1 (n > 0): the 64-bit output mod n
function Rng:below(n)
  local h, l = self:next()
  return ((h % n) * TWO32 + l) % n
end

-- Fisher-Yates over a 1-based array (the DLL's order: i from the end down to the second element)
function Rng:shuffle(v)
  for i = #v - 1, 1, -1 do
    local j = self:below(i + 1)
    v[i + 1], v[j + 1] = v[j + 1], v[i + 1]
  end
end

-- a run-time seed (config seed 0): the time since the scripts started, an address of this run (ASLR) and a counter
function U.entropy(addr, n)
  local t = U.u32(VRFW.now() * 1000003)
  local ah, al = U.split64(addr or 0)
  return bxor(ah, U.u32(n * 0x9E3779B9)), bxor(al, t)
end

-- ------------------------------------------------------------------------------------------------ guarded game access

-- a typed read; nil when the address is bad (the DLL's guarded read)
function U.rd(ty, p)
  if type(p) ~= "number" or p < 0x10000 then
    return nil
  end
  local ok, v = pcall(VRFW.mem.read, ty, p)
  if ok and type(v) == "number" then
    return v
  end
  return nil
end

-- a non-null pointer read
function U.rdp(p)
  local v = U.rd("ptr", p)
  if v and v >= 0x10000 then
    return v
  end
  return nil
end

-- a typed write; true when written
function U.wr(ty, p, v)
  if type(p) ~= "number" or p < 0x10000 then
    return false
  end
  return (pcall(VRFW.mem.write, ty, p, v))
end

-- a [[VRFW.Struct]] view, nil when the memory is not readable
function U.struct(name, p)
  if type(p) ~= "number" or p < 0x10000 then
    return nil
  end
  local ok, s = pcall(VRFW.mem.struct, name, p)
  if ok then
    return s
  end
  return nil
end

-- a field of a struct view, nil when it cannot be read
function U.get(s, field)
  if not s then
    return nil
  end
  local ok, v = pcall(function()
    return s[field]
  end)
  if ok then
    return v
  end
  return nil
end

-- a [[VRFW.Global]] (nil when not reachable)
function U.global(name)
  local ok, p = pcall(function()
    return VRFW.game[name]()
  end)
  if ok and type(p) == "number" and p >= 0x10000 then
    return p
  end
  return nil
end

-- a game function call: ok, value (false, error text when it is off or raised)
function U.call(name, ...)
  return pcall(VRFW.call, name, ...)
end

-- a boolean / bool-like return value
function U.truthy(v)
  if type(v) == "boolean" then
    return v
  end
  return type(v) == "number" and v % 256 ~= 0
end

-- a value of the mod's merged config.toml (+ the loader's [bb_chronicle_teams] / [mods.bb_chronicle_teams])
function U.config(path, default)
  local ok, v = pcall(VRFW.files.config, path)
  if ok and v ~= nil then
    return v
  end
  return default
end

-- the key of a game table as the game loads it: `<stem>.cfg.bin` when the file list has it, else the newest
-- `<stem>_<version>.cfg.bin` (VRFW.table.raw takes the last match of a glob)
function U.table_key(stem)
  local plain = stem .. ".cfg.bin"
  local ok, k = pcall(VRFW.table.keys, plain)
  if ok and type(k) == "table" and #k > 0 then
    return plain
  end
  return stem .. "_*.cfg.bin"
end

-- stable sort of a 1-based array by key(x) (Lua's table.sort is not stable)
function U.stable_sort(v, key)
  local d = {}
  for i, x in ipairs(v) do
    d[i] = { k = key(x), i = i, x = x }
  end
  table.sort(d, function(a, b)
    if a.k ~= b.k then
      return a.k < b.k
    end
    return a.i < b.i
  end)
  for i, e in ipairs(d) do
    v[i] = e.x
  end
end

return U
