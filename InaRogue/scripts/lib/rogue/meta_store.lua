-- InaRogue › INAROGUE: the meta progress of the v2 runs (docs/game/mods/inarogue-loop-v2.md §4.5, §7): global blob
-- rogue_meta.json (every INAROGUE game shares it). Runs played / won, the best stage, the highest Ascension unlocked,
-- the challenges completed and the weekly runs' best results. Read by the run start (Ascension choice, relic unlocks)
-- and written at the run end. No stat boosts: only what is open to play.

local U = require "lib/rogue/util"
local J = require "lib/rogue/json"
local Rules = require "lib/rogue/run_rules"
local info, warn = U.logger("rogue meta")

local M = {}

M.BLOB = "rogue_meta.json"
M.VERSION = 1

local store = nil

local function new_store()
  return { runs = 0, runs_won = 0, best_phase = 0, ascension_max = 0, won_at = {}, challenges = {}, weekly = {},
    items_open = {}, records = { best_phase = 0, endless = 0, wins = 0, goals = 0, coins = 0 } }
end

local function from_json(j)
  local s = new_store()
  if type(j) ~= "table" then return s end
  s.runs = math.max(U.int(j.runs, 0), 0)
  s.runs_won = math.max(U.int(j.runs_won, 0), 0)
  s.best_phase = math.max(U.int(j.best_phase, 0), 0)
  s.ascension_max = math.max(U.int(j.ascension_max, 0), 0)
  if type(j.won_at) == "table" then
    for k, v in pairs(j.won_at) do
      local a = tonumber(k)
      if a and type(v) == "number" then s.won_at[a] = math.max(U.int(v, 0), 0) end
    end
  end
  if type(j.challenges) == "table" then
    for k, v in pairs(j.challenges) do
      if type(k) == "string" and type(v) == "number" then s.challenges[k] = math.max(U.int(v, 0), 0) end
    end
  end
  if type(j.records) == "table" then
    for k in pairs(s.records) do s.records[k] = math.max(U.int(j.records[k], 0), 0) end
  end
  if type(j.items_open) == "table" then
    for _, k in ipairs(j.items_open) do
      if type(k) == "string" then s.items_open[k] = true end
    end
  end
  if type(j.weekly) == "table" then
    for k, v in pairs(j.weekly) do
      local w = tonumber(k)
      if w and type(v) == "table" then
        s.weekly[w] = { best_phase = math.max(U.int(v.best_phase, 0), 0), won = U.val(v.won) == true }
      end
    end
  end
  return s
end

local function sorted_pairs(t, conv)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys)
  local o = {}
  for _, k in ipairs(keys) do o[#o + 1] = { conv and conv(k) or k, t[k] } end
  return o
end

local function to_json(s)
  local weekly = {}
  for _, kv in ipairs(sorted_pairs(s.weekly)) do
    weekly[#weekly + 1] = { string.format("%.0f", kv[1]), J.obj({ { "best_phase", kv[2].best_phase }, { "won", kv[2].won } }) }
  end
  return J.pretty(J.obj({
    { "version", M.VERSION }, { "runs", s.runs }, { "runs_won", s.runs_won }, { "best_phase", s.best_phase },
    { "ascension_max", s.ascension_max },
    { "won_at", J.obj(sorted_pairs(s.won_at, function(k) return string.format("%.0f", k) end)) },
    { "challenges", J.obj(sorted_pairs(s.challenges)) }, { "weekly", J.obj(weekly) },
    { "items_open", J.arr(J.sorted_keys(s.items_open)) },
    { "records", J.obj(sorted_pairs(s.records)) },
  }))
end

-- the store (read once per game start; a return to the title keeps it: it is global)
function M.get()
  if store then return store end
  local text, why = U.blob_read(M.BLOB, "global")
  if text == false then
    warn(M.BLOB .. ": " .. tostring(why) .. "; set aside, a new store")
    U.blob_aside(M.BLOB, "global")
    text = nil
  end
  local j = nil
  if type(text) == "string" then
    local err
    j, err = U.json(text)
    if not j then warn(M.BLOB .. ": " .. tostring(err) .. "; a new store") end
  end
  store = from_json(j)
  return store
end

local function save(why)
  local ok, where = U.blob_write(M.BLOB, to_json(M.get()), "global")
  if ok then info(why .. " -> " .. tostring(where)) else warn("cannot write " .. M.BLOB .. ": " .. tostring(where)) end
  return ok
end

-- the highest Ascension level the player may pick (0 = none open yet), capped by the levels declared
function M.ascension_open(levels)
  return U.clamp(M.get().ascension_max, 0, math.max(levels or 0, 0))
end

-- the victory of run `r` (the final boss beaten; idempotent): the next Ascension, the challenges completed, the
-- weekly record. Returns the texts of what changed.
local function apply_victory(s, r, out)
  local A = require "lib/rogue/ascension"
  local asc = math.max(r.ascension or 0, 0)
  s.won_at[asc] = (s.won_at[asc] or 0)
  local next_level = math.min(asc + 1, A.levels())
  if next_level > s.ascension_max then
    s.ascension_max = next_level
    out[#out + 1] = Rules.text("InaRogue.run_meta_ascension_open", next_level)
  end
  for _, k in ipairs(A.completed_challenges(r)) do
    if (s.challenges[k] or 0) == 0 then out[#out + 1] = Rules.text("InaRogue.run_meta_challenge_done", A.challenge_name(k)) end
    s.challenges[k] = (s.challenges[k] or 0) + 1
  end
end

function M.on_victory(r)
  if not r then return end
  local s = M.get()
  local out = {}
  local ok, e = pcall(apply_victory, s, r, out)
  if not ok then warn("victory: " .. tostring(e)) end
  save("run won (endless goes on)")
end

-- run `r` ended with `result` ("won" / "lost" / "abandoned"): the counters, the victory, the weekly record. Returns
-- the summary lines of the meta progress ("" = nothing new).
function M.on_run_end(r, result)
  if not r then return "" end
  local s = M.get()
  local out = {}
  s.runs = s.runs + 1
  if result == "won" then
    s.runs_won = s.runs_won + 1
    local asc = math.max(r.ascension or 0, 0)
    s.won_at[asc] = (s.won_at[asc] or 0) + 1
    local ok, e = pcall(apply_victory, s, r, out)
    if not ok then warn("victory: " .. tostring(e)) end
  end
  if (r.phase or 0) > s.best_phase then s.best_phase = r.phase end
  for _, line in ipairs(M.records_of(r, s)) do out[#out + 1] = line end
  local week = U.int(r.weekly, 0)
  if week ~= 0 then
    local w = s.weekly[week] or { best_phase = 0, won = false }
    local better = (result == "won" and not w.won) or (r.phase or 0) > w.best_phase
    if (r.phase or 0) > w.best_phase then w.best_phase = r.phase end
    if result == "won" then w.won = true end
    s.weekly[week] = w
    if better then out[#out + 1] = Rules.text("InaRogue.run_meta_weekly_record", w.best_phase) end
  end
  for _, key in ipairs(M.newly_open_items()) do
    out[#out + 1] = Rules.text("InaRogue.run_meta_item_open", M.item_name(key))
  end
  save("run end (" .. result .. ")")
  return table.concat(out, "\n")
end

-- ---------------------------------------------------------------------------------------- relic unlocks

-- true when relic `it` (lib/rogue/items.lua catalogue entry) may drop: no `unlock` or its condition met
-- (unlock = { runs_won = n, best_stage = n, ascension = n }, every key given must be met)
function M.item_open(it)
  local u = it and it.unlock
  if type(u) ~= "table" then return true end
  local s = M.get()
  if U.int(u.runs_won, 0) > s.runs_won then return false end
  if U.int(u.best_stage, 0) > s.best_phase then return false end
  if U.int(u.ascension, 0) > s.ascension_max then return false end
  return true
end

function M.item_name(key)
  return Rules.text("InaRogue.rogue_item_" .. key .. "_name")
end

-- the relics with an `unlock` that opened since the last check (remembered in the store)
function M.newly_open_items()
  local s = M.get()
  local o = {}
  for _, it in ipairs(require("lib/rogue/items").catalogue().list) do
    if type(it.unlock) == "table" and not s.items_open[it.key] and M.item_open(it) then
      s.items_open[it.key] = true
      o[#o + 1] = it.key
    end
  end
  return o
end

-- ---------------------------------------------------------------------------------------- records

-- run `r`'s records against the best ever (stored): the lines of the records it beat, then the best ever
function M.records_of(r, s)
  local st = r.stats or {}
  local stages = (r.stages or 0) > 0 and r.stages or Rules.layout(r).stages
  local now = { best_phase = r.phase or 0, endless = r.victory and math.max((r.phase or 0) - 1 - stages, 0) or 0,
    wins = st.wins or 0, goals = st.goals or 0, coins = st.coins_earned or 0 }
  local out = {}
  for _, k in ipairs({ "best_phase", "endless", "wins", "goals", "coins" }) do
    if now[k] > (s.records[k] or 0) then
      s.records[k] = now[k]
      out[#out + 1] = Rules.text("InaRogue.run_record_" .. k, now[k])
    end
  end
  out[#out + 1] = Rules.text("InaRogue.run_records_best", s.records.best_phase, s.records.endless, s.records.wins,
    s.records.goals)
  return out
end

-- the result of the weekly run `week` (nil = never played)
function M.weekly(week) return M.get().weekly[week] end

return M
