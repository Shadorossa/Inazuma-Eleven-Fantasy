-- Battle Bay Deluxe: helpers shared by campaign.lua and draft.lua (one VM: draft.lua is required by campaign.lua).
-- Numbers: Lua 5.2 doubles. Hashes are u32 (0 .. 2^32-1); the game's T2B ints come signed (u32() fixes them).
-- The 64-bit seeded generator is the framework's SplitMix64 stream (VRFW.rng.splitmix64), the generator
-- bb_chronicle_teams.dll used.

local Id = require "VRFW/lib/ids"

local U = {}

local band, bxor = bit32.band, bit32.bxor
local rshift = bit32.rshift
local floor = math.floor
local TWO32 = 4294967296
U.TWO32 = TWO32

-- ------------------------------------------------------------------------------------------------ numbers

-- a number as u32 (signed T2B ints, negative Lua numbers from the game's Lua): the framework's Id.u32
U.u32 = Id.u32

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

U.hex = Id.hex

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

-- a generator seeded with the 64-bit value hi:lo: the framework's SplitMix64 stream (VRFW.rng.splitmix64, the one
-- generator API of the framework; bit-exact with the generator bb_chronicle_teams.dll used): g:next() -> hi, lo of the
-- next 64-bit output; g:below(n) -> the output mod n (n > 0); g:shuffle(v) -> Fisher-Yates over a 1-based array (the
-- DLL's order: i from the end down to the second element)
function U.rng(hi, lo)
  return VRFW.rng.splitmix64(U.u32(hi), U.u32(lo))
end

-- a seed from a Lua number (a config value: exact up to 2^53) as hi, lo
function U.split64(n)
  n = floor(math.max(0, n or 0))
  return floor(n / TWO32) % TWO32, n % TWO32
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

-- a value of the mod's merged config.toml (+ the loader's [bb_chronicle_teams] / [mods.bb_chronicle_teams]). The
-- mod's config.toml holds every key the scripts read: a key it lacks answers `default` with one warning per key
local CONFIG_MISSING = {}
function U.config(path, default)
  local ok, v = pcall(VRFW.files.config, path)
  if ok and v ~= nil then
    return v
  end
  if default ~= nil and not CONFIG_MISSING[path] then
    CONFIG_MISSING[path] = true
    VRFW.warn("config: config.toml has no " .. path .. ": the scripts' default " .. tostring(default) .. " is used")
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
