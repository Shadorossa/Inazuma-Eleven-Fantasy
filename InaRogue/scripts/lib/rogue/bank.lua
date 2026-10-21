-- InaRogue › INAROGUE: the player bank of one save slot (docs/game/modes/inarogue.md §8). Was bank.rs of the
-- DLL's module rogue: blob rogue_bank.json of the slot, the same JSON and rules.
--
-- * One entry per owned roguelite player (`param`), a stable `uid` (never reused in a slot). Players never leave the
--   bank; `undo_add` only rolls back the entry just added when its write failed.
-- * Every bank player is level 5 (design rule 2026-09-24): loading resets older levels.
-- * Debug entries ([rogue] debug_all_players): extra in-memory entries flagged `debug`, never written to the blob.

local U = require "lib/rogue/util"
local J = require "lib/rogue/json"
local growth = require "lib/rogue/growth"

local B = {}

B.BLOB, B.VERSION = "rogue_bank.json", 1
-- a new bank player's level: InaRogue's growth (content\growth\growth.toml StartLevel)
local function start_level() return growth.get().start end
B.CODE = { OK = 0, BAD_ARGS = 1, NOT_ROGUELITE = 2, DUPLICATE = 3, FULL = 4, WRITE_FAILED = 5, NOT_FOUND = 6 }
local C = B.CODE
-- how a player was obtained (album info card «Método»)
B.SOURCE = { UNKNOWN = 0, STARTER = 1, RECRUIT = 2, GACHA = 3, DEBUG = 4, OTHER = 5 }
B.RESULT = { NONE = 0, ABANDONED = 1, LOST = 2, WON = 3 }

local function index(b)
  b.by_uid, b.by_param = {}, {}
  for _, e in ipairs(b.entries) do
    b.by_uid[e.uid] = e
    b.by_param[e.param] = e
  end
end

function B.new(slot)
  local b = { slot = slot, next_uid = 1, entries = {}, best_phase = 0, granted = false,
    runs = { played = 0, won = 0, last = 0, last_phase = 0 } }
  index(b)
  return b
end

function B.len(b) return #b.entries end

-- the entries the blob holds (debug entries left out)
function B.real_len(b) return #b.entries - (b.debug_count or 0) end

-- the uid of a debug entry: derived from the card id, so a run saved with it finds the same player after a restart
local DEBUG_UID_BASE, DEBUG_UID_SPAN = 0x40000000, 0x3FFFFFFF
local function debug_uid(param) return DEBUG_UID_BASE + param % DEBUG_UID_SPAN end

-- add an in-memory debug entry for every param not owned yet (a uid already taken skips its card): the number added
function B.add_debug(b, params)
  local added = 0
  for _, param in ipairs(params) do
    local uid = debug_uid(param)
    if param ~= 0 and not b.by_param[param] and not b.by_uid[uid] then
      local e = { uid = uid, param = param, level = start_level(), runs = 0, added = 0, flags = 0, frags = 0, goals = 0,
        source = B.SOURCE.DEBUG, debug = true }
      b.entries[#b.entries + 1] = e
      b.by_uid[uid] = e
      b.by_param[param] = e
      added = added + 1
    end
  end
  b.debug_count = (b.debug_count or 0) + added
  return added
end

-- parse a decoded file: rows with uid 0 / param 0 / a duplicate uid or param are dropped, next_uid raised
function B.from_json(j, slot)
  if type(j) ~= "table" then return nil, "not an object" end
  for _, k in ipairs({ "version", "slot", "next_uid" }) do
    if type(j[k]) ~= "number" then return nil, "missing field `" .. k .. "`" end
  end
  if type(j.players) ~= "table" then return nil, "missing field `players`" end
  if j.version ~= B.VERSION then return nil, "unknown version " .. tostring(j.version) end
  local b = B.new(slot)
  b.best_phase = U.int(j.best_phase, 0)
  b.granted = U.val(j.granted) == true
  local r = type(U.val(j.runs)) == "table" and j.runs or {}
  b.runs = { played = U.int(r.played, 0), won = U.int(r.won, 0), last = U.int(r.last, 0), last_phase = U.int(r.last_phase, 0) }
  local top = 0
  for _, p in ipairs(j.players) do
    if type(p) == "table" and type(p.uid) == "number" and type(p.param) == "number" then
      local uid, param = p.uid, p.param
      if uid ~= 0 and param ~= 0 and not b.by_uid[uid] and not b.by_param[param] then
        local e = { uid = uid, param = param, level = start_level(), runs = U.int(p.runs, 0), added = U.int(p.added, 0),
          flags = U.int(p.flags, 0), frags = U.int(p.frags, 0), goals = U.int(p.goals, 0), source = U.int(p.source, 0) }
        b.entries[#b.entries + 1] = e
        b.by_uid[uid] = e
        b.by_param[param] = e
        if uid > top then top = uid end
      end
    end
  end
  b.next_uid = math.max(j.next_uid, (top + 1) % U.TWO32, 1)
  return b
end

function B.to_json(b)
  local players = {}
  for _, e in ipairs(b.entries) do
    if not e.debug then
      players[#players + 1] = J.obj({ { "uid", e.uid }, { "param", e.param }, { "level", e.level }, { "runs", e.runs },
        { "added", e.added }, { "flags", e.flags }, { "frags", e.frags }, { "goals", e.goals }, { "source", e.source } })
    end
  end
  return J.pretty(J.obj({
    { "version", B.VERSION }, { "slot", b.slot }, { "next_uid", b.next_uid }, { "best_phase", b.best_phase },
    { "granted", b.granted },
    { "runs", J.obj({ { "played", b.runs.played }, { "won", b.runs.won }, { "last", b.runs.last },
      { "last_phase", b.runs.last_phase } }) },
    { "players", J.arr(players) },
  }))
end

-- slot `slot`'s bank: bank | false, why (a corrupt blob; no blob = an empty bank)
function B.load(slot)
  local text, why = U.blob_read(B.BLOB, slot)
  if text == false then return false, why end
  if text == nil then return B.new(slot) end
  local j, err = U.json(text)
  if not j then return false, err end
  local b, e2 = B.from_json(j, slot)
  if not b then return false, e2 end
  return b
end

function B.save(b)
  return U.blob_write(B.BLOB, B.to_json(b), b.slot)
end

-- add a player (level 5 always); `valid` = a roguelite player. code, uid
function B.add_from(b, param, added, valid, capacity, src)
  if param == 0 then return C.BAD_ARGS end
  if not valid then return C.NOT_ROGUELITE end
  if b.by_param[param] then return C.DUPLICATE end
  if B.real_len(b) >= capacity then return C.FULL end
  local uid = math.max(b.next_uid, 1)
  b.next_uid = math.max((uid + 1) % U.TWO32, 1)
  local e = { uid = uid, param = param, level = start_level(), runs = 0, added = added, flags = 0, frags = 0, goals = 0,
    source = src or 0 }
  b.entries[#b.entries + 1] = e
  b.by_uid[uid] = e
  b.by_param[param] = e
  return C.OK, uid
end

-- roll back the LAST add (its write failed); any other uid is refused
function B.undo_add(b, uid)
  local e = b.entries[#b.entries]
  if not e or e.uid ~= uid then return false end
  b.entries[#b.entries] = nil
  b.by_uid[uid] = nil
  b.by_param[e.param] = nil
  return true
end

function B.add_frags(b, uid, n)
  local e = b.by_uid[uid]
  if not e then return nil end
  e.frags = math.min(e.frags + n, U.TWO32 - 1)
  return e.frags
end

function B.set_frags(b, uid, n)
  local e = b.by_uid[uid]
  if not e then return false end
  e.frags = n
  return true
end

function B.record_run_end(b, result, phase)
  b.runs.played = b.runs.played + 1
  if result == B.RESULT.WON then b.runs.won = b.runs.won + 1 end
  b.runs.last = result
  b.runs.last_phase = phase
end

function B.record_phase(b, phase)
  if phase > b.best_phase then
    b.best_phase = phase
    return true
  end
  return false
end

-- display order of the bank menu: 0 added, 1 tier (high first, then cost), 2 cost (then tier), 3 level (then tier);
-- `info(param)` = tier, cost. Stable (ties keep the bank order). Returns 1-based entry indices.
function B.order(b, sort, info)
  local n = #b.entries
  local idx = {}
  if sort ~= 1 and sort ~= 2 and sort ~= 3 then
    for i = 1, n do idx[i] = i end
    return idx
  end
  -- one number per entry (the native sort compares them: no Lua comparator over thousands of entries)
  local keys = {}
  for i, e in ipairs(b.entries) do
    local t, c = info(e.param)
    t, c = U.clamp(t, 0, 99), U.clamp(c, 0, 999)
    local k
    if sort == 1 then
      k = (99 - t) * 1000 + (999 - c)
    elseif sort == 2 then
      k = (999 - c) * 100 + (99 - t)
    else
      k = (999 - U.clamp(e.level, 0, 999)) * 100 + (99 - t)
    end
    keys[i] = k * 100000 + i
  end
  table.sort(keys)
  for i, k in ipairs(keys) do idx[i] = k % 100000 end
  return idx
end

return B
