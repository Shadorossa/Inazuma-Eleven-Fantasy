-- Hissatsu Reforged › the critical hit of special moves (docs/game/mods/hissatsu-critical.md). The framework's critical
-- stage (rule engine triggers crit_check / crit, docs/framework/rules.md §3.7) asks once per execution of a move; this
-- script answers the chance, the cap and the multiplier from config.toml [critical]:
--   * a base chance for every special move;
--   * the «Crítico» archetype (the game's team build 0, retail «Brecha»): its four build passives as team-wide bonuses
--     (chance, chance when level or behind, critical power per rank, tension on a critical; the keepers' chance per
--     rank) and its charge: ranks 1..#levels, +1 per rank_up_seconds of match clock without a critical of the team,
--     -rank_down_on_crit on one; each rank multiplies the team's chance (levels) and its keepers' (keeper_levels).
-- Same rules for both teams (user and CPU). Nothing here names a move or a player; nothing calls the game at load.

HissatsuReforged = HissatsuReforged or {}
HissatsuReforged.Critical = HissatsuReforged.Critical or {}
local Critical = HissatsuReforged.Critical

require "VRFW/lib/basics"
local info, warn = VRFW.logger("critical")

local ARCHETYPE_STATE = "vr_framework.archetype.team"   -- + match side: the side's team build (VRFW archetype service)
local RANK_STATE = "HissatsuReforged.critical_rank"     -- + match side: the «Crítico» rank this script keeps

local u32 = require("VRFW/lib/ids").u32

-- a value of this mod's merged config [critical]: a number, or a list of numbers when `default` is a table
local function setting(key, default)
  local ok, v = pcall(VRFW.files.config, "critical." .. key)
  if not ok or v == nil then return default end
  if type(default) == "table" then
    if type(v) ~= "table" then return default end
    local out = {}
    for i, x in ipairs(v) do
      if type(x) ~= "number" then return default end
      out[i] = x
    end
    return #out > 0 and out or default
  end
  if type(v) == "number" then return v end
  return default
end

local config = nil

local function settings()
  if config then return config end
  config = {
    base_chance = setting("base_chance", 0),
    multiplier = setting("multiplier", 1),
    cap = setting("cap", 100),
    archetype_build = setting("archetype_build", -1),
    keeper_move_category = setting("keeper_move_category", -1),
    archetype_chance = setting("archetype_chance", 0),
    archetype_level_or_behind_chance = setting("archetype_level_or_behind_chance", 0),
    power_per_rank = setting("power_per_rank", 0),
    crit_tension = setting("crit_tension", 0),
    keeper_per_rank = setting("keeper_per_rank", 0),
    rank_up_seconds = setting("rank_up_seconds", 0),
    rank_down_on_crit = setting("rank_down_on_crit", 0),
    levels = setting("levels", { 0 }),
    keeper_levels = setting("keeper_levels", {}),
  }
  if config.multiplier < 0 then
    warn("multiplier " .. tostring(config.multiplier) .. " below 0: 1 used")
    config.multiplier = 1
  end
  info(string.format("base %.1f %%, power x%.2f, cap %.1f %%; build %d: +%.1f (+%.1f level or behind), power +%.1f %%/rank, "
    .. "tension %.1f per critical, keepers +%.1f %%/rank; %d ranks (+1 per %ds, -%d per critical)", config.base_chance,
    config.multiplier, config.cap, config.archetype_build, config.archetype_chance, config.archetype_level_or_behind_chance,
    config.power_per_rank, config.crit_tension, config.keeper_per_rank, #config.levels, config.rank_up_seconds,
    config.rank_down_on_crit))
  return config
end

-- ------------------------------------------------------------------------------------------------ moves

local moves = nil   -- [skill id] = skill table category

local function move_category(skill)
  if moves == nil then
    moves = {}
    for _, id in ipairs({ "skill/skill", "skill" }) do
      local ok, rows = pcall(VRFW.table.rows, id)
      if ok and type(rows) == "table" and #rows > 0 then
        for _, r in ipairs(rows) do
          if r.skill_id then moves[u32(r.skill_id)] = tonumber(r.category) or 0 end
        end
        break
      end
    end
  end
  return moves[u32(skill)]
end

-- ------------------------------------------------------------------------------------------------ the team

local function on_archetype(side)
  local ok, v = pcall(VRFW.state.get, ARCHETYPE_STATE .. tostring(side))
  return ok and tonumber(v) == settings().archetype_build
end

local function level_or_behind(ev, side)
  local score = ev.match and ev.match.score
  if not score then return false end
  local own, other = score["team" .. side], score["team" .. (1 - side)]
  if own == nil or other == nil then return false end
  return own <= other
end

-- ------------------------------------------------------------------------------------------------ the charge

local CHARGE = {}   -- [side] = { rank, half, clock }: the rank and the match clock it was last set at

local function clock_of(ev)
  local m = ev.match or VRFW.match() or {}
  return tonumber(m.half), tonumber(m.clock)
end

local function publish(side, rank, why)
  pcall(VRFW.state.set, RANK_STATE .. tostring(side), rank)
  info(string.format("side %d rank %d (%s)", side, rank, why))
end

-- the side's rank now: the last one + the full rank_up_seconds since (the match clock of this half; a new half counts
-- from its start)
local function rank_now(side, ev)
  local c = settings()
  local top = #c.levels
  local half, clock = clock_of(ev)
  local s = CHARGE[side]
  if not s then
    s = { rank = 1, half = half, clock = clock or 0 }
    CHARGE[side] = s
    publish(side, 1, "start")
  end
  if c.rank_up_seconds > 0 and clock then
    -- a new half counts from its start
    if half ~= s.half then s.half, s.clock = half, 0 end
    local up = math.floor(math.max(0, clock - s.clock) / c.rank_up_seconds)
    if up > 0 then
      s.clock = s.clock + up * c.rank_up_seconds
      if s.rank < top then
        s.rank = math.min(top, s.rank + up)
        publish(side, s.rank, "no critical for " .. tostring(up * c.rank_up_seconds) .. " s")
      end
    end
  end
  return s.rank
end

local function on_team_crit(side, ev)
  local c = settings()
  local r = rank_now(side, ev)
  local s = CHARGE[side]
  local half, clock = clock_of(ev)
  s.rank, s.half, s.clock = math.max(1, r - c.rank_down_on_crit), half, clock or 0
  if s.rank ~= r then publish(side, s.rank, "critical hit") end
end

-- ------------------------------------------------------------------------------------------------ the answers

-- the chance of this execution, in percent (before the cap), and the power multiplier of a hit
function Critical.Answer(ev)
  local c = settings()
  local a = ev.actor
  local chance, mult = c.base_chance, c.multiplier
  if a and (a.team == 0 or a.team == 1) and on_archetype(a.team) then
    local rank = rank_now(a.team, ev)
    chance = chance + c.archetype_chance
    if level_or_behind(ev, a.team) then chance = chance + c.archetype_level_or_behind_chance end
    chance = chance * (1 + (c.levels[rank] or 0) / 100)
    if move_category(ev.skill) == c.keeper_move_category then
      chance = chance * (1 + ((c.keeper_levels[rank] or 0) + c.keeper_per_rank * rank) / 100)
    end
    mult = mult * (1 + c.power_per_rank * rank / 100)
  end
  return chance, mult
end

VRFW.on("match_start", function()
  CHARGE = {}
  return nil
end)

VRFW.on("crit_check", function(ev)
  if not ev.actor or not ev.skill or move_category(ev.skill) == nil then return nil end
  local chance, mult = Critical.Answer(ev)
  return { crit_chance = chance, crit_mult = mult, crit_cap = settings().cap }
end)

-- a hit: the log line (the framework logs the roll and the power it multiplies), the «Crítico» charge and its tension
VRFW.on("crit", function(ev)
  local a = ev.actor
  if not a or not ev.skill or move_category(ev.skill) == nil then return nil end
  info(string.format("CRITICAL: move 0x%08X by 0x%08X (team %s)", u32(ev.skill), u32(a.handle), tostring(a.team)))
  if (a.team == 0 or a.team == 1) and on_archetype(a.team) then
    on_team_crit(a.team, ev)
    local units = settings().crit_tension
    if units ~= 0 then return { add_tension = units, tension_team = "actor" } end
  end
  return nil
end)
