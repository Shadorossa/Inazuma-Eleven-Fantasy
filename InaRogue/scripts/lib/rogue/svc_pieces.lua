-- InaRogue › INAROGUE: the match run time of the effect pieces (lib/rogue/pieces.lua) of the run's rogue items and of
-- the team archetype's rank. stat_multiplier / stat_bonus go through the coach's native tables (svc_meta.coach_sync);
-- the pieces below answer the framework's rule triggers from this script (docs/framework/scripts.md §3.1), only for an
-- INAROGUE match:
--   tension_cost_multiplier        tension_pay:skill  cost_mult for the user's players (long_shot: long-shot moves)
--   technique_cooldown_multiplier  recast             recast_mult for the user's players
--   wall_reduction_multiplier      move_power         power_mult of that side's shot-block moves (the AT a wall takes away)
--   technique_grade_override       state key InaRogue.max_grade = 1 (the mod Hissatsu Level Up's max_grade_states rule)
--   technique_power_multiplier, technique_free_until_broken: move_power / tension_pay:skill through lib/rogue/svc_blocks.lua
-- The active pieces are rebuilt whenever the run is loaded or saved (Core.on_run).

local U = require "lib/rogue/util"
local Core = require "lib/rogue/core"
local E = require "lib/rogue/effects"
local Items = require "lib/rogue/items"
local Blocks = require "lib/rogue/svc_blocks"
local info, warn = U.logger("rogue pieces")

local S = {}

S.KEY_MAX_GRADE = "InaRogue.max_grade"
-- skill_effect_bit_flag bits (docs/framework/technique.md «badges»): long shot (shots), shot block (blocks)
local LONG_SHOT_BIT, SHOT_BLOCK_BIT = 4, 16
-- block moves' key prefix (the game's naming: whs shoot, who dribble, whd block, whk catch)
local BLOCK_PREFIX = "whd"

local active = { tension = {}, cooldown = 1.0, walls = { rival = 1.0, user = 1.0 }, max_grade = false, any = false }
local published = nil

-- ---------------------------------------------------------------------------------------- active pieces

-- the state key InaRogue.max_grade: 1 while the INAROGUE save is in memory and an item's grade override has matches left
local grade_now = nil
function S.publish_grade()
  local grade = (active.max_grade and U.rogue_active()) and 1 or 0
  if grade ~= grade_now then
    pcall(VRFW.state.set, S.KEY_MAX_GRADE, grade)
    grade_now = grade
  end
  return grade
end

local function rebuild(r)
  local effects = r and E.concat(Items.effects(r.items, "match"), Items.archetype_effects(r.items, "match")) or {}
  local a = { tension = {}, cooldown = 1.0, walls = { rival = 1.0, user = 1.0 }, max_grade = false, any = false }
  for _, e in ipairs(effects) do
    if not e.pending and not e.when and not e.count then
      if e.kind == "tension_cost_multiplier" then
        a.tension[#a.tension + 1] = e
        a.any = true
      elseif e.kind == "technique_cooldown_multiplier" then
        a.cooldown = a.cooldown * e.mult
        a.any = true
      elseif e.kind == "wall_reduction_multiplier" then
        a.walls[e.side] = a.walls[e.side] * e.mult
        a.any = true
      elseif e.kind == "technique_grade_override" then
        a.max_grade = true
      end
    end
  end
  active = a
  local grade = S.publish_grade()
  local tension = {}
  for _, e in ipairs(a.tension) do tension[#tension + 1] = string.format("%s x%.3f", e.action, e.mult) end
  local sig = string.format("tension [%s] cooldown x%.3f walls rival x%.3f user x%.3f max grade %d",
    table.concat(tension, ", "), a.cooldown, a.walls.rival, a.walls.user, grade)
  if sig ~= published then
    published = sig
    info(sig)
  end
end

Core.on_run(rebuild)
-- another save in memory: the grade key goes off until the run is read again
Core.on_forget(function() rebuild(nil) end)

-- ---------------------------------------------------------------------------------------- the skill table

local moves = nil   -- { long = { [id] = true }, shot_block = { [id] = true } }

local function move_sets()
  if moves then return moves end
  moves = { long = {}, shot_block = {} }
  local ok, rows = pcall(VRFW.table.rows, "skill/skill")
  if not ok or type(rows) ~= "table" then
    warn("no skill table: tension_cost_multiplier(long_shot) and wall_reduction_multiplier reach no move")
    return moves
  end
  local nl, nb = 0, 0
  for _, r in ipairs(rows) do
    local id, flags = tonumber(r.skill_id or r[1]), tonumber(r.skill_effect_bit_flag or r[10])
    local key = r.skill_id_str or r[2]
    if id and flags then
      id = bit32.band(id, 0xFFFFFFFF)
      if bit32.band(flags, LONG_SHOT_BIT) ~= 0 and not U.starts(key, BLOCK_PREFIX) then
        moves.long[id] = true
        nl = nl + 1
      end
      if bit32.band(flags, SHOT_BLOCK_BIT) ~= 0 and U.starts(key, BLOCK_PREFIX) then
        moves.shot_block[id] = true
        nb = nb + 1
      end
    end
  end
  info(string.format("skill table: %d long-shot move(s), %d shot-block move(s)", nl, nb))
  return moves
end

local function is_move(set, skill)
  return skill ~= nil and move_sets()[set][bit32.band(skill, 0xFFFFFFFF)] == true
end

-- ---------------------------------------------------------------------------------------- handlers

local function live() return active.any and U.rogue_active() end

local function side_of(ev) return ev.actor and ev.actor.side or nil end

local function on_tension_pay(ev)
  if not U.rogue_active() or side_of(ev) ~= "user" then return nil end
  local m = 1.0
  if active.any then
    for _, e in ipairs(active.tension) do
      if e.action == "move" or (e.action == "long_shot" and is_move("long", ev.skill)) then m = m * e.mult end
    end
  end
  m = m * Blocks.tension_mult(ev.actor and ev.actor.handle, ev.skill)
  if m == 1.0 then return nil end
  return { cost_mult = m }
end

local function on_recast(ev)
  if not live() or active.cooldown == 1.0 or side_of(ev) ~= "user" then return nil end
  return { recast_mult = active.cooldown }
end

local function on_move_power(ev)
  if not U.rogue_active() then return nil end
  local side = side_of(ev)
  local m = 1.0
  if active.any and side and is_move("shot_block", ev.skill) then m = active.walls[side] or 1.0 end
  if side == "user" then m = m * Blocks.power_mult(ev.actor and ev.actor.handle, ev.skill) end
  if m == 1.0 then return nil end
  return { power_mult = m }
end

-- the handlers (top level of the entry script only: inarogue.lua calls this while it loads)
function S.register()
  VRFW.on("tension_pay:skill", on_tension_pay)
  VRFW.on("recast", on_recast)
  VRFW.on("move_power", on_move_power)
  -- the INAROGUE run is read again at kick-off, so the pieces follow the run of the save in memory
  VRFW.on("match_start", function()
    if U.rogue_active() and Core.run then pcall(Core.run.run_hdls) end
    S.publish_grade()
    if active.any then move_sets() end
  end)
end

return S
