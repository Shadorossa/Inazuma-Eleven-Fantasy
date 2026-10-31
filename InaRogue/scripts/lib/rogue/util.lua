-- InaRogue › INAROGUE: shared helpers of the rogue scripts (u32 arithmetic, the seeded generators, logging, the
-- mod config, slots, blobs). Pure Lua over VRFW.*; nothing touches the game at require time.

local U = {}

local band, bxor, lshift, rshift, lrotate = bit32.band, bit32.bxor, bit32.lshift, bit32.rshift, bit32.lrotate
U.TWO32 = 4294967296

-- ---------------------------------------------------------------------------------------- numbers

-- a value as an integer (truncated toward zero; booleans 1 / 0), `def` for anything else
function U.int(v, def)
  if type(v) == "boolean" then return v and 1 or 0 end
  if type(v) == "string" then v = tonumber(v) end
  if type(v) ~= "number" or v ~= v then return def end
  if v >= 0 then return math.floor(v) end
  return math.ceil(v)
end

-- a Lua argument as the u32 the DLL read (`v as i64 as u32`); `def` when not a number
function U.u32(v, def)
  local n = U.int(v, nil)
  if n == nil then return def end
  return n % U.TWO32
end

-- round half away from zero (Rust f32 / f64 `round`)
function U.round(x)
  if x >= 0 then return math.floor(x + 0.5) end
  return -math.floor(-x + 0.5)
end

function U.clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

-- u32 wrapping multiplication (exact: the halves never pass 2^53)
function U.mul32(a, b)
  a, b = a % U.TWO32, b % U.TWO32
  local alo, ahi = a % 65536, math.floor(a / 65536)
  local blo, bhi = b % 65536, math.floor(b / 65536)
  return (alo * blo + ((ahi * blo + alo * bhi) % 65536) * 65536) % U.TWO32
end

U.xor = bxor
U.band = band
U.lshift = lshift
U.rshift = rshift
function U.rotl(x, n) return lrotate(x, n) end

-- one step of the xorshift32 every rogue stream uses (run::xorshift: 0 stays 0); returns the new state = the value
function U.xs(s)
  local x = bxor(s, lshift(s, 13))
  x = bxor(x, rshift(x, 17))
  x = bxor(x, lshift(x, 5))
  return x
end

-- the guarded one of the bank / debug fill (mod.rs xorshift: a 0 state starts at 0x9E3779B9)
function U.xs_guard(s)
  if s == 0 then s = 0x9E3779B9 end
  return U.xs(s)
end

-- a stream object: r:next() = the next u32 (run::xorshift semantics)
function U.stream(seed)
  local o = { s = seed % U.TWO32 }
  function o:next()
    self.s = U.xs(self.s)
    return self.s
  end
  return o
end

-- crc32 of a string (the game's names / Lua hashes)
function U.crc32(s)
  return VRFW.ui.crc32(s) % U.TWO32
end

function U.hex(v) return string.format("0x%08X", (v or 0) % U.TWO32) end

-- the local date as yyyymmdd (0 = unknown)
function U.today()
  local ok, d = pcall(VRFW.ui.today)
  if ok and type(d) == "number" then return d end
  return 0
end

-- ---------------------------------------------------------------------------------------- strings

function U.trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- lower case for names: ASCII and the Spanish letters the team names use (Rust to_lowercase on those)
local LOWER = { ["Á"] = "á", ["É"] = "é", ["Í"] = "í", ["Ó"] = "ó", ["Ú"] = "ú", ["Ñ"] = "ñ", ["Ü"] = "ü",
  ["À"] = "à", ["È"] = "è", ["Ì"] = "ì", ["Ò"] = "ò", ["Ù"] = "ù", ["Ç"] = "ç", ["Ö"] = "ö", ["Ä"] = "ä" }
function U.lower(s)
  s = string.lower(tostring(s or ""))
  return (s:gsub("\195[\128-\159]", function(c) return LOWER[c] or c end))
end

-- case-insensitive ASCII compare (Rust eq_ignore_ascii_case)
function U.eq_ascii(a, b)
  return string.lower(a or "") == string.lower(b or "")
end

function U.starts(s, p) return string.sub(s or "", 1, #p) == p end

-- ---------------------------------------------------------------------------------------- tables

function U.contains(list, v)
  for _, x in ipairs(list) do
    if x == v then return true end
  end
  return false
end

function U.index_of(list, v)
  for i, x in ipairs(list) do
    if x == v then return i end
  end
  return nil
end

function U.copy(t)
  if type(t) ~= "table" then return t end
  local o = {}
  for k, v in pairs(t) do o[k] = U.copy(v) end
  return o
end

-- a JSON / TOML array as a Lua list of numbers (nil / not a list = {})
function U.nums(v)
  local o = {}
  if type(v) ~= "table" then return o end
  for _, x in ipairs(v) do
    if type(x) == "number" then o[#o + 1] = x end
  end
  return o
end

-- ---------------------------------------------------------------------------------------- logging

function U.logger(tag)
  return function(...) VRFW.log(tag .. ":", ...) end, function(...) VRFW.warn(tag .. ":", ...) end,
    function(...) VRFW.error(tag .. ":", ...) end
end

-- ---------------------------------------------------------------------------------------- config

-- a value of the mod's merged config (dotted path); `default` when missing or of another type
function U.cfg(path, default)
  local ok, v = pcall(VRFW.files.config, path)
  if not ok or v == nil then return default end
  if default ~= nil and type(v) ~= type(default) then return default end
  return v
end

-- INAROGUE runs whenever the mod InaRogue is enabled (no module / mode switch since it left Inazuma Fantasy, 2026-10-14)
function U.module_on()
  return true
end

-- ---------------------------------------------------------------------------------------- slots

-- the INAROGUE save's slot ([save_slots] slot of InaRogue's config.toml)
U.ROGUE_SLOT = tonumber(U.cfg("save_slots.slot", 4)) or 4

-- the slot of the game in memory (1 before the slot service is up)
function U.slot()
  local ok, ready = pcall(VRFW.slots.ready)
  if ok and ready then
    local ok2, a = pcall(VRFW.slots.active)
    if ok2 and type(a) == "number" and a ~= 0 then return a end
  end
  return 1
end

-- INAROGUE is the game in memory (its overlay session or the old slot-4 switch)
function U.rogue_active()
  local ok, ready = pcall(VRFW.slots.ready)
  if not ok or not ready then return false end
  local ok2, a = pcall(VRFW.slots.active)
  return ok2 and a == U.ROGUE_SLOT
end

-- ---------------------------------------------------------------------------------------- blobs

-- text of blob `name` (scope: a slot number or "global"): text | nil (none) | false, why (unreadable)
function U.blob_read(name, scope)
  local ok, text, err = pcall(VRFW.save.blob, name, scope)
  if not ok then return false, tostring(text) end
  if text == nil and err then return false, err end
  return text
end

-- write blob `name`: ok, where / why
function U.blob_write(name, text, scope)
  local ok, w, where = pcall(VRFW.save.blob_write, name, text, scope)
  if not ok then return false, tostring(w) end
  return w and true or false, where
end

-- take blob `name` out of use with its backups (moved to .archive\): the note
function U.blob_aside(name, scope)
  local ok, note = pcall(VRFW.save.blob_aside, name, scope)
  if not ok then return tostring(note) end
  return note
end

-- JSON text -> table | nil, why
function U.json(text)
  local ok, v, why = pcall(VRFW.json.decode, text)
  if not ok then return nil, tostring(v) end
  if v == nil then return nil, why or "bad JSON" end
  return v
end

-- a decoded JSON value that is not a table / number / string / bool (the null sentinel) as nil
function U.val(v)
  local t = type(v)
  if t == "table" or t == "number" or t == "string" or t == "boolean" then return v end
  return nil
end

-- ---------------------------------------------------------------------------------------- slot events

-- the save slot events since the last call: the slots whose data may have been archived, copied over or reset (a
-- delete, a new game, a copy target, the framework's reset: the DLL's forget_slot) as a set { [slot] = true }; `all`
-- = more events than the ring keeps (every cache must go). nil = nothing new.
local seen_seq = nil
function U.slot_events()
  local ok, seq = pcall(VRFW.slots.event_seq)
  if not ok or type(seq) ~= "number" then return nil end
  if seen_seq == nil then
    seen_seq = seq
    return nil
  end
  if seq == seen_seq then return nil end
  local hit, any = {}, false
  local from = math.max(seen_seq + 1, seq - 63)
  for n = from, seq do
    local okk, kind, a, b = pcall(VRFW.slots.event, n)
    if okk and kind ~= nil and kind ~= "saved" and kind ~= "switched" then
      if kind == "copied" then
        if type(b) == "number" then hit[b] = true end
      elseif type(a) == "number" then
        hit[a] = true
      end
      any = true
    end
  end
  local all = seq - seen_seq > 64
  seen_seq = seq
  if not any and not all then return nil end
  return hit, all
end

-- ---------------------------------------------------------------------------------------- game memory

function U.rd(ty, at)
  if not at or at < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, ty, at)
  if ok then return v end
  return nil
end

function U.wr(ty, at, v)
  if not at or at < 0x10000 then return false end
  return (pcall(VRFW.mem.write, ty, at, v))
end

function U.global(name)
  local f = VRFW.game and VRFW.game[name]
  if not f then return nil end
  local ok, p = pcall(f)
  if ok and type(p) == "number" and p >= 0x10000 then return p end
  return nil
end

return U
