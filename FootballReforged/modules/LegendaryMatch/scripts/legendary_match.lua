-- Legendary Match › the foul chance of the rival's power charges / power blocks (docs/game/mods/legendary-match.md).
-- Declarations: content\game\legendary_match.toml (hook LegendaryMatch.FoulRate on the game's foul chance). Setting:
-- config.toml [legendary_match] rival_power_action_foul_rate (the game: focusFoulBaseRatePowerAction 0.15).
-- A duel foul of a rival player (not the user's team) whose duel ended in a power charge / power block gets that chance
-- instead of the game's; an immune player (chance 0) stays immune. Your own power actions keep the game's chance.

LegendaryMatch = LegendaryMatch or {}

local function number_setting(t, k, default, low, high)
  local v = tonumber(t and t[k])
  if v == nil or v ~= v then return default end
  if v < low then v = low end
  if v > high then v = high end
  return v
end

local RAW = (VRFW.files and VRFW.files.config and VRFW.files.config("legendary_match")) or {}
local SETTINGS = {
  rival_power_action_foul_rate = number_setting(RAW, "rival_power_action_foul_rate", 0.05, 0, 1),
}
LegendaryMatch.settings = SETTINGS

-- game layout (docs/game/mechanics/cards.md §2.2): the actor table through the framework (VRFW/lib/actors); the match
-- info, the focus manager and the foul request as structs of content\game\legendary_match.toml
local Actors = require "VRFW/lib/actors"
local DUEL_KIND_POWER = 6

-- one field of a [[VRFW.Struct]] of content\game\legendary_match.toml at `at`; nil when not readable
local function struct_field(struct, at, name)
  if not at or at < 0x10000 then return nil end
  local ok, s = pcall(VRFW.mem.struct, struct, at)
  if not ok then return nil end
  local ok_value, v = pcall(function() return s[name] end)
  if ok_value then return v end
  return nil
end

local function game_global(name)
  local ok, p = pcall(VRFW.game[name])
  if ok and type(p) == "number" and p >= 0x10000 then return p end
  return nil
end

local function team_of(handle)
  local a = Actors.of(handle)
  return a and a.team or nil
end

VRFW.on("hook:LegendaryMatch.FoulRate:post", function(ev)
  local duel = game_global("legendary_duel")
  if not duel or struct_field("LegendaryDuel", duel, "result_kind") ~= DUEL_KIND_POWER then return nil end
  local match = game_global("legendary_match_info")
  local user = match and struct_field("LegendaryMatchInfo", match, "user_team")
  if user ~= 0 and user ~= 1 then return nil end
  local offender = struct_field("LegendaryFoulRequest", ev.args[1], "offender")
  local team = team_of(offender)
  if team == nil or team == user then return nil end
  local rate = SETTINGS.rival_power_action_foul_rate
  VRFW.log(string.format("legendary_match: rival power action foul chance 0x%08X: %.3f -> %.3f", offender, ev.ret or 0, rate))
  return { ret = rate }
end)
