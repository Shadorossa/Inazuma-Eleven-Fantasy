-- Skill Duel (a module of Football Reforged; docs/game/mods/skill-duel.md): a plain focus duel is won by reading the
-- side. Settings: config.toml [skill_duel]. The mechanism is the VR-Framework's focus line rule
-- (VRFW.duel.line_rule, docs/framework/focus-line.md):
-- * reach: the defender's hand size and arm length follow the game's DF / AT curve, placed in the band
--   reach_min_m..reach_max_m / hand_scale_min..hand_scale_max and pulled to its middle by stat_weight; the judge and
--   the hands' effect use the same line;
-- * contact: the attacker's path on the defender's body, arm or hand = the defender wins (a stronger attacker slips
--   through with contact_slip_per_point % per point of AT - DF, at most contact_slip_max_percent %); past the hand =
--   the game's result (the attacker wins).
-- The rule is set once, at the first match start (no game call at load); later starts only confirm it.

SkillDuel = SkillDuel or {}
local M = SkillDuel

require "VRFW/lib/basics"
local info = VRFW.logger("skill_duel")

local function number_setting(t, k, default, low, high)
  local v = tonumber(t and t[k])
  if v == nil or v ~= v then return default end
  if low and v < low then v = low end
  if high and v > high then v = high end
  return v
end

local function config(name)
  local t = VRFW.config(name)
  return type(t) == "table" and t or {}
end

local RAW = config("skill_duel")
local SETTINGS = {
  reach = {
    stat_weight = number_setting(RAW, "stat_weight", 0.3, 0, 1),
    reach_min_m = number_setting(RAW, "reach_min_m", 2.0, 0.1, 20),
    reach_max_m = number_setting(RAW, "reach_max_m", 3.4, 0.1, 20),
    hand_scale_min = number_setting(RAW, "hand_scale_min", 1.1, 0.1, 5),
    hand_scale_max = number_setting(RAW, "hand_scale_max", 1.3, 0.1, 5),
  },
  contact = {
    slip_per_point = number_setting(RAW, "contact_slip_per_point", 0.2, 0, 100),
    slip_max_percent = number_setting(RAW, "contact_slip_max_percent", 0, 0, 100),
  },
  log = RAW.log ~= false,
}
if SETTINGS.reach.reach_max_m < SETTINGS.reach.reach_min_m then SETTINGS.reach.reach_max_m = SETTINGS.reach.reach_min_m end
if SETTINGS.reach.hand_scale_max < SETTINGS.reach.hand_scale_min then SETTINGS.reach.hand_scale_max = SETTINGS.reach.hand_scale_min end
M.settings = SETTINGS

local rule_set = false

local function set_rule()
  if rule_set then return end
  if not (VRFW.duel and VRFW.duel.line_rule) then
    info("VRFW.duel.line_rule is missing (VR-Framework too old): the game's duel stays")
    rule_set = true
    return
  end
  local line, why = VRFW.duel.line_rule(SETTINGS)
  rule_set = true
  if line then
    info("focus line rule:", line)
  else
    info("focus line rule refused:", why)
  end
end

VRFW.on("match_start", function()
  set_rule()
  return nil
end)
