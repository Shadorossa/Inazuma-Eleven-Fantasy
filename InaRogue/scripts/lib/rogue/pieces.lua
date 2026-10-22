-- InaRogue › INAROGUE: the effect pieces (docs/game/modes/inarogue-archetypes.md «Regla de implementación»). A piece
-- is one generic, parametrised effect; a rogue item, a coach or an archetype rank is data that lists pieces by name
-- (`kind`) with their parameters and values. The first names (stat_mult, tension_cost_mult, technique_cooldown_mult,
-- wall_reduction_mult, pass_speed_mult) stay aliases of the current ones (P.ALIASES). A piece may carry the blocks of
-- lib/rogue/blocks.lua (conditions `when`, a counter `count`, `per_stack`), attached by lib/rogue/effects.lua. Each piece declares where it acts (scope: outside / match / both), how
-- long (duration: match = every match / matches = N matches of the run), the key of its level-scaled value and its
-- engine status (implemented, or pending with the hook it needs). The run time of the match pieces is
-- lib/rogue/svc_pieces.lua; the stat and economy aggregators are lib/rogue/effects.lua.
--
-- Level scaling (lib/rogue/effects.lua E.at_level): a value is a number (every level), a list (one value per level)
-- or { base = a, max = b } (linear from level 1 to the item's max level).

local U = require "lib/rogue/util"
local B = require "lib/rogue/blocks"

local P = {}

-- the first names of the pieces -> their current names
P.ALIASES = { stat_mult = "stat_multiplier", tension_cost_mult = "tension_cost_multiplier",
  technique_cooldown_mult = "technique_cooldown_multiplier", wall_reduction_mult = "wall_reduction_multiplier",
  pass_speed_mult = "pass_speed_multiplier" }

function P.canonical(kind) return P.ALIASES[kind] or kind end

P.STATS = { "kick", "control", "technique", "pressure", "physical", "intelligence", "agility" }
-- battle values the engine derives from the stats (no native table for them yet)
P.DERIVED_STATS = { focus_at = true, focus_df = true, shot_at = true }

local POSITION = B.POSITION
local ELEMENT = B.ELEMENT

-- a number >= 0 of the effect table, or nil + why
local function number(t, key, kind)
  local v = t[key]
  if type(v) ~= "number" or v ~= v or v < 0 or v == math.huge then
    return nil, kind .. ": `" .. key .. "` must be a number >= 0"
  end
  return v
end

-- the players an effect reaches: team (default), position (GK / DF / MF / FW) or element
local function parse_target(t, kind, allowed)
  local target = t.target or "team"
  if not allowed[target] then
    local names = {}
    for k in pairs(allowed) do names[#names + 1] = k end
    table.sort(names)
    return nil, kind .. ": target `" .. tostring(target) .. "` (" .. table.concat(names, " / ") .. ")"
  end
  if target == "position" then
    local p = POSITION[string.lower(tostring(t.position or ""))]
    if not p then return nil, kind .. ": position = GK / DF / MF / FW" end
    return { kind = "position", v = p }
  elseif target == "element" then
    local e = ELEMENT[U.lower(tostring(t.element or ""))]
    if not e then return nil, kind .. ": element = viento / bosque / fuego / montaña" end
    return { kind = "element", v = e }
  end
  return { kind = "team" }
end

local ALL_TARGETS = { team = true, position = true, element = true }
local TEAM_ONLY = { team = true }

-- ---------------------------------------------------------------------------------------- the pieces

P.LIST = {}

-- stat_multiplier(stat, value): a stat of the reached players × value in the match copy (native table InaRogue.CoachMult)
P.LIST.stat_multiplier = {
  scope = "match", duration = "match", value_key = "value", status = "implemented",
  pending_for = "focus_at / focus_df / shot_at: a per-player bonus table read by the battle bonus getters " ..
    "(Passive.DuelAtBonus / DuelDfBonus / ShotAtBonus, today answered by VRFW's archetype tables only)",
  parse = function(t)
    local target, why = parse_target(t, "stat_multiplier", ALL_TARGETS)
    if not target then return nil, why end
    local v, why2 = number(t, "value", "stat_multiplier")
    if not v then return nil, why2 end
    local word = t.stat or "all"
    if P.DERIVED_STATS[word] then
      return { kind = "stat_multiplier", target = target, derived = word, value = v, pending = true }
    end
    local stat = nil
    if word ~= "all" then
      stat = U.index_of(P.STATS, word)
      if not stat then
        return nil, "stat_multiplier: stat `" .. tostring(word) .. "` (all / " .. table.concat(P.STATS, " / ") ..
          " / focus_at / focus_df / shot_at)"
      end
    end
    return { kind = "stat_multiplier", target = target, stat = stat, value = v }
  end,
}

-- tension_cost_multiplier(action, mult): the tension the user's players pay for that action × mult (rule engine trigger
-- tension_pay:skill). Actions: long_shot (a shot move with the long-shot flag), move (every move).
P.ACTIONS = { long_shot = true, move = true }
P.LIST.tension_cost_multiplier = {
  scope = "match", duration = "match", value_key = "mult", status = "implemented",
  hook = "tension_pay:skill (Stamina.TensionPay; not in the v7.2.1 profile yet)",
  parse = function(t)
    local action = t.action or "move"
    if not P.ACTIONS[action] then return nil, "tension_cost_multiplier: action `" .. tostring(action) .. "` (long_shot / move)" end
    local v, why = number(t, "mult", "tension_cost_multiplier")
    if not v then return nil, why end
    return { kind = "tension_cost_multiplier", action = action, mult = v }
  end,
}

-- technique_cooldown_multiplier(target, mult): the recast time of the user's moves × mult (rule engine trigger recast)
P.LIST.technique_cooldown_multiplier = {
  scope = "match", duration = "match", value_key = "mult", status = "implemented",
  hook = "recast (Technique.MatchSkillInstall; not in the v7.2.1 profile yet)",
  parse = function(t)
    local target, why = parse_target(t, "technique_cooldown_multiplier", TEAM_ONLY)
    if not target then return nil, why end
    local v, why2 = number(t, "mult", "technique_cooldown_multiplier")
    if not v then return nil, why2 end
    return { kind = "technique_cooldown_multiplier", target = target, mult = v }
  end,
}

-- wall_reduction_multiplier(side, mult): the shot AT a wall (a shot-block move) of that side takes away × mult, as the wall
-- move's power × mult (rule engine trigger move_power)
P.SIDES = { rival = true, user = true }
P.LIST.wall_reduction_multiplier = {
  scope = "match", duration = "match", value_key = "mult", status = "implemented",
  hook = "move_power (Technique.Power; not in the v7.2.1 profile yet)",
  parse = function(t)
    local side = t.side or "rival"
    if not P.SIDES[side] then return nil, "wall_reduction_multiplier: side `" .. tostring(side) .. "` (rival / user)" end
    local v, why = number(t, "mult", "wall_reduction_multiplier")
    if not v then return nil, why end
    return { kind = "wall_reduction_multiplier", side = side, mult = v }
  end,
}

-- pass_speed_multiplier(mult): the ball speed of the user's passes × mult
P.LIST.pass_speed_multiplier = {
  scope = "match", duration = "match", value_key = "mult", status = "pending",
  pending_for = "a pass launch hook: the ball speed the engine gives a pass kick (no rule trigger or framework " ..
    "service reads it on either build)",
  parse = function(t)
    local v, why = number(t, "mult", "pass_speed_multiplier")
    if not v then return nil, why end
    return { kind = "pass_speed_multiplier", mult = v, pending = true }
  end,
}

-- technique_grade_override(grade, duration_matches): every move of the user's players plays at the maximum grade for
-- the next N matches of the run (the item's matches_left in rogue_run.json; the mod Hissatsu Level Up's
-- max_grade_states rule over the state key InaRogue.max_grade)
P.GRADES = { max = true }
P.LIST.technique_grade_override = {
  scope = "match", duration = "matches", value_key = "duration_matches", status = "implemented",
  hook = "Hissatsu Level Up's match install (Technique.MatchSkillInstall; not in the v7.2.1 profile yet)",
  parse = function(t)
    local grade = t.grade or "max"
    if not P.GRADES[grade] then return nil, "technique_grade_override: grade `" .. tostring(grade) .. "` (max)" end
    local n = t.duration_matches
    if type(n) ~= "number" or n < 1 or n ~= math.floor(n) then
      return nil, "technique_grade_override: `duration_matches` must be a whole number >= 1"
    end
    return { kind = "technique_grade_override", grade = grade, matches = n }
  end,
}

-- stat_bonus(stat, value): a stat of the reached players + value (flat points) in the match copy (native table
-- InaRogue.CoachAdd, read by the same [[VRFW.MatchStat]] InaRogue.Coach)
P.LIST.stat_bonus = {
  scope = "match", duration = "match", value_key = "value", neutral = 0, status = "implemented",
  parse = function(t)
    local target, why = parse_target(t, "stat_bonus", ALL_TARGETS)
    if not target then return nil, why end
    -- the match-stat formula is unsigned: points are added, never taken away
    local v, why2 = number(t, "value", "stat_bonus")
    if not v then return nil, why2 end
    local word = t.stat or "all"
    if P.DERIVED_STATS[word] then
      return { kind = "stat_bonus", target = target, derived = word, value = v, pending = true }
    end
    local stat = nil
    if word ~= "all" then
      stat = U.index_of(P.STATS, word)
      if not stat then
        return nil, "stat_bonus: stat `" .. tostring(word) .. "` (all / " .. table.concat(P.STATS, " / ") ..
          " / focus_at / focus_df / shot_at)"
      end
    end
    return { kind = "stat_bonus", target = target, stat = stat, value = v }
  end,
}

-- technique_power_multiplier(moves filter, value): the power of the user's moves passing the filter × value (rule
-- engine trigger move_power). Filter keys: category, element, moves, tags, players (lib/rogue/blocks.lua parse_moves).
P.LIST.technique_power_multiplier = {
  scope = "match", duration = "match", value_key = "value", status = "implemented",
  hook = "move_power (Technique.Power; not in the v7.2.1 profile yet)",
  parse = function(t)
    local f, why = B.parse_moves(t, "technique_power_multiplier")
    if not f then return nil, why end
    local v, why2 = number(t, "value", "technique_power_multiplier")
    if not v then return nil, why2 end
    return { kind = "technique_power_multiplier", moves = f, value = v, pending = f.pending and true or nil }
  end,
}

-- technique_free_until_broken(moves filter): the user's moves passing the filter cost no tension until one of them
-- loses its duel in the match (rule engine triggers tension_pay:skill and technique_result:lost)
P.LIST.technique_free_until_broken = {
  scope = "match", duration = "match", value_key = nil, status = "implemented",
  hook = "tension_pay:skill + technique_result (Stamina.TensionPay / Technique.Power; not in the v7.2.1 profile yet)",
  parse = function(t)
    local f, why = B.parse_moves(t, "technique_free_until_broken")
    if not f then return nil, why end
    return { kind = "technique_free_until_broken", moves = f, pending = f.pending and true or nil }
  end,
}

-- shop_cost_multiplier(value): the Rogue points the Shop asks for an item and its upgrades × value
P.LIST.shop_cost_multiplier = {
  scope = "outside", duration = "match", value_key = "value", status = "implemented",
  parse = function(t)
    local v, why = number(t, "value", "shop_cost_multiplier")
    if not v then return nil, why end
    return { kind = "shop_cost_multiplier", value = v }
  end,
}

-- ---------------------------------------------------------------------------------------- lookups

function P.get(kind) return P.LIST[P.canonical(kind)] end

-- one effect table of a piece -> its parsed effect (kind = the piece's current name), or nil + why. With per_stack
-- and no value the value starts at the piece's neutral value (1 for multipliers, 0 for flat ones).
function P.parse(t)
  local kind = P.canonical(t.kind)
  local d = P.LIST[kind]
  if not d then return nil end
  if t.per_stack ~= nil and d.value_key and t[d.value_key] == nil then
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    c[d.value_key] = d.neutral or 1
    t = c
  end
  local e, why = d.parse(t)
  if e then
    e.kind = kind
    e.duration = d.duration
    e.neutral = d.neutral or 1
  end
  return e, why
end

-- does the item scope `where` (outside / match / both) cover the piece's scope?
function P.scope_ok(kind, where)
  local d = P.LIST[P.canonical(kind)]
  if not d or where == "both" then return true end
  return d.scope == where or d.scope == "both"
end

-- the most matches a list of parsed effects lasts (0 = no piece with a match count)
function P.duration_matches(effects)
  local n = 0
  for _, e in ipairs(effects or {}) do
    if e.duration == "matches" and e.matches and e.matches > n then n = e.matches end
  end
  return n
end

return P
