-- InaRogue › INAROGUE: formations as loot (docs/game/modes/inarogue.md §18). Was formations.rs /
-- formations_rt.rs of the DLL's module rogue; table content\rogue\formations.toml (research/scripts/rogue_formations_build.py).
--
-- A new profile owns the picker's 8 retail formations (+ [rogue.formations] start); the 54 loot formations drop from
-- won nodes with a rarity 1-4 rising with the source and the phase. Per profile (slot), blob rogue_formations.json
-- (the DLL's JSON). Only loot ids are stored; every other formation is always owned.

local U = require "lib/rogue/util"
local J = require "lib/rogue/json"
local info, warn, err = U.logger("rogue formations")

local F = {}

F.BLOB, F.VERSION, F.MAX_RARITY = "rogue_formations.json", 1, 4
F.SOURCE = { START = 0, PACHANGA = 1, PARTIDO = 2, ELITE = 3, JEFE = 4, COFRE = 5, DEBUG = 9 }
local SRC = F.SOURCE

local data = nil

function F.data()
  if data then return data end
  data = { basic = {}, loot = {}, by_id = {} }
  local ok, t = pcall(VRFW.files.toml, "content/rogue/formations.toml")
  if not ok or type(t) ~= "table" then
    warn("content/rogue/formations.toml not readable (" .. tostring(t) .. "): every formation is owned")
    return data
  end
  for _, b in ipairs(type(t.basic) == "table" and t.basic or {}) do data.basic[#data.basic + 1] = { id = b.id % U.TWO32, name = b.name } end
  for _, l in ipairs(type(t.loot) == "table" and t.loot or {}) do
    local x = { id = l.id % U.TWO32, row = l.row, rarity = l.rarity, name = l.name }
    data.loot[#data.loot + 1] = x
    data.by_id[x.id] = x
  end
  return data
end

function F.loot(id) return F.data().by_id[id] end
function F.total() local d = F.data() return #d.basic + #d.loot end

-- source of a won node kind (1 pachanga, 2 11v11, 3 boss, 7 élite, 4 Cofre); nil = no drop
function F.source_of_kind(kind)
  if kind == 1 then return SRC.PACHANGA end
  if kind == 2 then return SRC.PARTIDO end
  if kind == 3 then return SRC.JEFE end
  if kind == 7 then return SRC.ELITE end
  if kind == 4 then return SRC.COFRE end
  return nil
end

-- the rule of `source` in `phase`: chance %, min rarity, max rarity (nil = no drop)
function F.rule(fc, source, phase)
  local p = math.max(phase, 1)
  local r = nil
  for _, x in ipairs(fc.drops) do
    if #x == 5 and x[1] == source and x[2] <= p then r = x end
  end
  if not r then return nil end
  local lo = U.clamp(r[4], 1, F.MAX_RARITY)
  local hi = math.max(U.clamp(r[5], 1, F.MAX_RARITY), lo)
  if r[3] <= 0 then return nil end
  return math.min(r[3], 100), lo, hi
end

-- ---------------------------------------------------------------------------------------- the book of a profile

function F.new_book(slot, start, added)
  local b = { slot = slot, owned = {} }
  for _, id in ipairs(start) do F.grant(b, id, SRC.START, 0, added) end
  b.dirty = #b.owned > 0
  return b
end

function F.is_owned(b, id)
  if not F.loot(id) then return true end
  for _, o in ipairs(b.owned) do
    if o.id == id then return true end
  end
  return false
end

function F.owned_count(b) return #F.data().basic + #b.owned end

function F.grant(b, id, source, phase, added)
  if not F.loot(id) then return false end
  for _, o in ipairs(b.owned) do
    if o.id == id then return false end
  end
  b.owned[#b.owned + 1] = { id = id, source = source, phase = phase, added = added }
  b.dirty = true
  return true
end

function F.undo(b, id)
  local o = b.owned[#b.owned]
  if o and o.id == id then
    b.owned[#b.owned] = nil
    return true
  end
  return false
end

function F.to_json(b)
  local owned = {}
  for i, o in ipairs(b.owned) do
    owned[i] = J.obj({ { "id", o.id }, { "source", o.source }, { "phase", o.phase }, { "added", o.added } })
  end
  return J.pretty(J.obj({ { "version", F.VERSION }, { "slot", b.slot }, { "owned", J.arr(owned) } }))
end

function F.from_json(j, slot)
  if type(j) ~= "table" or type(j.version) ~= "number" or type(j.slot) ~= "number" or type(j.owned) ~= "table" then
    return nil, "missing field"
  end
  if j.version ~= F.VERSION then return nil, "unknown version " .. tostring(j.version) end
  local b = { slot = slot, owned = {}, dirty = false }
  for _, o in ipairs(j.owned) do
    if type(o) == "table" and type(o.id) == "number" then
      local id = o.id
      if F.loot(id) and F.is_owned(b, id) == false then
        b.owned[#b.owned + 1] = { id = id, source = U.int(o.source, 0), phase = U.int(o.phase, 0), added = U.int(o.added, 0) }
      end
    end
  end
  return b
end

local book = nil -- the cached book of the active slot

-- the active slot's book (loaded on first use: no blob = a new profile; a corrupt one is set aside, a new profile)
function F.with_book(fc, slot)
  if book and book.slot == slot then return book end
  local text, why = U.blob_read(F.BLOB, slot)
  local b = nil
  if text == false then
    err(string.format("slot %d: %s unreadable (%s); a new profile is used for now", slot, F.BLOB, tostring(why)))
  elseif text then
    local j, e = U.json(text)
    if j then b, e = F.from_json(j, slot) end
    if not b then
      local kept = U.blob_aside(F.BLOB, slot)
      err(string.format("slot %d: %s: %s; %s; no usable previous version: new profile", slot, F.BLOB, tostring(e), tostring(kept)))
      b = F.new_book(slot, fc.start, U.today())
      b.dirty = true
    end
  end
  if not b then b = F.new_book(slot, fc.start, U.today()) end
  info(string.format("slot %d: %d of %d formations owned", slot, F.owned_count(b), F.total()))
  book = b
  return b
end

function F.forget()
  book = nil
end

-- the formation a won node drops (nil = no rule / the chance failed / everything owned)
function F.roll(fc, b, seed, phase, node, source)
  if not fc.enabled or fc.unlock_all then return nil end
  local chance, lo, hi = F.rule(fc, source, phase)
  if not chance then return nil end
  local s = U.xor(U.xor(U.xor(U.xor(seed, U.mul32(phase, 0x9E3779B9)), U.mul32(node, 0x85EBCA6B)), U.mul32(source, 0xC2B2AE35)), 0x0F0A1A70)
  if s == 0 then s = 0x0F0A1A70 end
  s = U.xs(s)
  s = U.xs(s)
  if s % 100 >= chance then return nil end
  local function free(r)
    local o = {}
    for _, l in ipairs(F.data().loot) do
      if l.rarity == r and not F.is_owned(b, l.id) then o[#o + 1] = l end
    end
    return o
  end
  local window, total = {}, 0
  for r = lo, hi do
    if #free(r) > 0 then
      local w = fc.rarity_weights[r] or 0
      window[#window + 1] = { r, w }
      total = total + w
    end
  end
  local rarity
  if total > 0 then
    s = U.xs(s)
    local x = s % total
    rarity = window[1][1]
    for _, w in ipairs(window) do
      if x < w[2] then
        rarity = w[1]
        break
      end
      x = x - w[2]
    end
  elseif #window > 0 then
    rarity = window[1][1]
  else
    for r = hi + 1, F.MAX_RARITY do
      if #free(r) > 0 then
        rarity = r
        break
      end
    end
    if not rarity then
      for r = lo - 1, 1, -1 do
        if #free(r) > 0 then
          rarity = r
          break
        end
      end
    end
    if not rarity then return nil end
  end
  local c = free(rarity)
  s = U.xs(s)
  return c[s % #c + 1]
end

-- a drop for the node just won: formId, name, rarity, ownedCount, total (written at once; rolled back on failure)
function F.grant_for_node(fc, slot, seed, phase, node, kind)
  local src = F.source_of_kind(kind)
  if not src then return nil end
  local b = F.with_book(fc, slot)
  local l = F.roll(fc, b, seed, phase, node, src)
  if not l then return nil end
  if not F.grant(b, l.id, src, phase, U.today()) then return nil end
  local ok, where = U.blob_write(F.BLOB, F.to_json(b), b.slot)
  if not ok then
    err(string.format("cannot write %s: %s; %s not granted", F.BLOB, tostring(where), l.name))
    F.undo(b, l.id)
    return nil
  end
  b.dirty = false
  info(string.format("%s (%d*) won (source %d, phase %d, node %d) -> %s", l.name, l.rarity, src, phase, node, tostring(where)))
  return l.id, l.name, l.rarity, F.owned_count(b), F.total()
end

return F
