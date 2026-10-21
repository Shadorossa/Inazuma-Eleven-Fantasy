-- InaRogue › INAROGUE: the run of one save slot (docs/game/modes/inarogue.md §11): its file, the moves on the
-- route map and the node in progress. Was run.rs of the DLL's module rogue; blob rogue_run.json of the slot, the same
-- JSON (key order of the DLL's struct), so a saved run loads as it was.

local U = require "lib/rogue/util"
local J = require "lib/rogue/json"

local R = {}

R.BLOB, R.VERSION = "rogue_run.json", 1
R.CODE = { OK = 0, NO_RUN = 1, BAD_NODE = 2, NOT_CONNECTED = 3, NOT_CLEARED = 4, WRITE_FAILED = 5, ALREADY = 6, PHASE_OPEN = 7 }
local C = R.CODE
-- stages of the node in progress (audit A19)
R.STAGE = { NONE = 0, ARRIVED = 1, NODE = 2, MATCH = 3 }
local ST = R.STAGE
-- emblematic-rival rule version new boards are drawn with (2 = also the boss tiers)
R.RIVALS_RULE = 2
R.TEAM_SLOTS, R.STARTERS, R.BENCH_END = 20, 11, 16

local function list(v)
  return U.nums(U.val(v))
end

local function strs(v)
  local o = {}
  if type(v) ~= "table" then return o end
  for _, x in ipairs(v) do
    if type(x) == "string" then o[#o + 1] = x end
  end
  return o
end

function R.new(slot, seed)
  return {
    version = R.VERSION, slot = slot, seed = math.max(seed, 1), phase = 1, cur = 0, cleared = { 0 }, path = { 0 },
    phases_done = 0, squad = {}, slots = {}, formation = 0, pending = nil, hdls = {}, won = 0, lost = 0,
    rivals_rule = R.RIVALS_RULE, coach = "", coach_since = 0, coach_items_given = true, beaten = {}, beaten_phase = {},
    items = {}, talents = {},
  }
end

-- the blocks' saved counts of an item: { [name] = number } (lib/rogue/svc_blocks.lua)
local function counters_of(v)
  local o = {}
  if type(v) ~= "table" then return o end
  for k, x in pairs(v) do
    if type(k) == "string" and type(x) == "number" then o[k] = x end
  end
  return o
end

-- the run's rogue items: { { key, level, counter, matches_left, counters } } (lib/rogue/items.lua)
local function items_of(v)
  local o = {}
  if type(v) ~= "table" then return o end
  for _, x in ipairs(v) do
    if type(x) == "table" and type(x.key) == "string" and x.key ~= "" then
      o[#o + 1] = { key = x.key, level = math.max(U.int(x.level, 1), 1), counter = U.int(x.counter, 0),
        matches_left = math.max(U.int(x.matches_left, 0), 0), counters = counters_of(U.val(x.counters)) }
    end
  end
  return o
end

-- the talent levels of the run's players: { [bank uid] = level }
local function talents_of(v)
  local o = {}
  if type(v) ~= "table" then return o end
  for k, x in pairs(v) do
    local uid = tonumber(k)
    if uid and type(x) == "number" then o[uid] = math.max(U.int(x, 1), 1) end
  end
  return o
end

-- a parsed file -> run | nil, why (the DLL's serde rules: the first seven fields are required)
function R.from_json(j, slot)
  if type(j) ~= "table" then return nil, "not an object" end
  for _, k in ipairs({ "version", "slot", "seed", "phase", "cur" }) do
    if type(j[k]) ~= "number" then return nil, "missing field `" .. k .. "`" end
  end
  if type(j.cleared) ~= "table" or type(j.path) ~= "table" then return nil, "missing field `cleared` / `path`" end
  if j.version ~= R.VERSION then return nil, "unknown version " .. tostring(j.version) end
  local p = U.val(j.pending)
  local pending = nil
  if type(p) == "table" then
    pending = { node = U.int(p.node, 0), stage = U.int(p.stage, 0), game = U.int(p.game, 0), diff = U.int(p.diff, 0),
      stadium = U.int(p.stadium, 0), level = U.int(p.level, 0) }
  end
  local items = U.val(j.coach_items_given)
  return {
    version = R.VERSION, slot = slot, seed = j.seed, phase = j.phase, cur = j.cur, cleared = list(j.cleared),
    path = list(j.path), phases_done = U.int(j.phases_done, 0), squad = list(j.squad), slots = list(j.slots),
    formation = U.int(j.formation, 0), pending = pending, hdls = list(j.hdls), won = U.int(j.won, 0),
    lost = U.int(j.lost, 0), rivals_rule = U.int(j.rivals_rule, 0), coach = type(j.coach) == "string" and j.coach or "",
    coach_since = U.int(j.coach_since, 0), coach_items_given = (items == nil) and true or (items == true),
    beaten = strs(j.beaten), beaten_phase = strs(j.beaten_phase), items = items_of(j.items), talents = talents_of(j.talents),
  }
end

function R.to_json(r)
  local items, talents = {}, {}
  for _, o in ipairs(r.items or {}) do
    local names, counters = {}, {}
    for k in pairs(o.counters or {}) do names[#names + 1] = k end
    table.sort(names)
    for _, k in ipairs(names) do counters[#counters + 1] = { k, o.counters[k] } end
    items[#items + 1] = J.obj({ { "key", o.key }, { "level", o.level }, { "counter", o.counter or 0 },
      { "matches_left", o.matches_left or 0 }, { "counters", J.obj(counters) } })
  end
  local uids = {}
  for uid in pairs(r.talents or {}) do uids[#uids + 1] = uid end
  table.sort(uids)
  for _, uid in ipairs(uids) do talents[#talents + 1] = { string.format("%.0f", uid), r.talents[uid] } end
  local pend = nil
  if r.pending then
    local p = r.pending
    pend = J.obj({ { "node", p.node }, { "stage", p.stage }, { "game", p.game }, { "diff", p.diff },
      { "stadium", p.stadium }, { "level", p.level } })
  end
  return J.pretty(J.obj({
    { "version", r.version }, { "slot", r.slot }, { "seed", r.seed }, { "phase", r.phase }, { "cur", r.cur },
    { "cleared", J.arr(r.cleared) }, { "path", J.arr(r.path) }, { "phases_done", r.phases_done },
    { "squad", J.arr(r.squad) }, { "slots", J.arr(r.slots) }, { "formation", r.formation }, { "pending", pend },
    { "hdls", J.arr(r.hdls) }, { "won", r.won }, { "lost", r.lost }, { "rivals_rule", r.rivals_rule },
    { "coach", r.coach }, { "coach_since", r.coach_since }, { "coach_items_given", r.coach_items_given },
    { "beaten", J.arr(r.beaten) }, { "beaten_phase", J.arr(r.beaten_phase) },
    { "items", J.arr(items) }, { "talents", J.obj(talents) },
  }))
end

-- slot `slot`'s run: run | nil (none) | false, why (unreadable / corrupt)
function R.load(slot)
  local text, why = U.blob_read(R.BLOB, slot)
  if text == false then return false, why end
  if text == nil then return nil end
  local j, err = U.json(text)
  if not j then return false, err end
  local r, e2 = R.from_json(j, slot)
  if not r then return false, e2 end
  return r
end

function R.save(r)
  return U.blob_write(R.BLOB, R.to_json(r), r.slot)
end

-- take the run out of use with its backups (an ended run never comes back)
function R.delete(slot)
  return U.blob_aside(R.BLOB, slot)
end

function R.copy(r)
  return U.copy(r)
end

-- ---------------------------------------------------------------------------------------- rules

function R.is_cleared(r, n) return U.contains(r.cleared, n) end

function R.stage(r)
  return r.pending and r.pending.stage or ST.NONE
end

-- a won node's rival (team name and row) joins `beaten`
function R.note_beaten(r, rival, row)
  for _, n in ipairs({ rival, row }) do
    n = U.lower(U.trim(n))
    if n ~= "" and not U.contains(r.beaten, n) then r.beaten[#r.beaten + 1] = n end
  end
end

-- a new run's coach: its board follows the coach from phase 1; its start items are still to give
function R.set_coach(r, id, items)
  r.coach = id
  r.coach_since = 1
  r.coach_items_given = not items
end

-- a run saved before coaches gets `id`: its board in progress stays as it is, no start items
function R.stamp_coach(r, id)
  if r.coach ~= "" or id == "" then return false end
  r.coach = id
  r.coach_since = r.phase + 1
  r.coach_items_given = true
  return true
end

-- move to node `to` of the map `m` (the next column, connected to the cleared current node)
function R.move_to(r, m, to)
  if to < 0 or to >= #m.nodes then return C.BAD_NODE end
  if not R.is_cleared(r, r.cur) then return C.NOT_CLEARED end
  local map = require "lib/rogue/map"
  if not map.connected(m, r.cur, to) then return C.NOT_CONNECTED end
  r.cur = to
  r.path[#r.path + 1] = to
  r.pending = { node = to, stage = ST.ARRIVED, game = 0, diff = 0, stadium = 0, level = 0 }
  return C.OK
end

function R.set_stage(r, s)
  if R.is_cleared(r, r.cur) then return C.ALREADY end
  if not r.pending then r.pending = { node = r.cur, stage = 0, game = 0, diff = 0, stadium = 0, level = 0 } end
  r.pending.node = r.cur
  r.pending.stage = s
  return C.OK
end

function R.clear_current(r)
  if R.is_cleared(r, r.cur) then return C.ALREADY end
  r.cleared[#r.cleared + 1] = r.cur
  r.pending = nil
  return C.OK
end

-- uids of the run's players: the team screen's slots, else the picker's squad
function R.player_uids(r)
  local o = {}
  for _, u in ipairs(r.slots) do
    if u ~= 0 then o[#o + 1] = u end
  end
  if #o > 0 then return o end
  local s = {}
  for i, u in ipairs(r.squad) do s[i] = u end
  return s
end

-- team slot (0-based) of `uid`, nil = not in the team
function R.find_uid(r, uid)
  if uid == 0 then return nil end
  for i, u in ipairs(r.slots) do
    if u == uid then return i - 1 end
  end
  if #r.slots == 0 then
    for i, u in ipairs(r.squad) do
      if u == uid then return i - 1 end
    end
  end
  return nil
end

-- first empty bench slot (11-15), for a Fichaje that joins the team
function R.free_bench_slot(r)
  for s = R.STARTERS, R.BENCH_END - 1 do
    if (r.slots[s + 1] or 0) == 0 then return s end
  end
  return nil
end

function R.set_slot(r, slot, uid)
  for i = #r.slots + 1, R.TEAM_SLOTS do r.slots[i] = 0 end
  if slot < #r.slots then r.slots[slot + 1] = uid end
end

function R.set_hdl(r, slot, hdl)
  if slot < 0 or slot >= R.TEAM_SLOTS then return C.BAD_NODE end
  for i = #r.hdls + 1, R.TEAM_SLOTS do r.hdls[i] = 0 end
  r.hdls[slot + 1] = hdl
  return C.OK
end

-- after the boss is cleared: the next phase's map, starting at its start node
function R.next_phase(r, m)
  if r.cur ~= #m.nodes - 1 or not R.is_cleared(r, r.cur) then return C.PHASE_OPEN end
  r.phase = r.phase + 1
  r.phases_done = r.phases_done + 1
  r.rivals_rule = R.RIVALS_RULE
  r.beaten_phase = {}
  for i, b in ipairs(r.beaten) do r.beaten_phase[i] = b end
  r.cur = 0
  r.cleared = { 0 }
  r.path = { 0 }
  return C.OK
end

return R
