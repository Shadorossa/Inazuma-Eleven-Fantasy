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

-- game layout: soccer actors, the match info, the focus manager (docs/game/mechanics/cards.md §2.2)
local ACTOR_COUNT, ACTOR_STRIDE, ACTOR_HANDLE, ACTOR_TEAM = 0x3A, 0x570, 0x94, 0xD0
local MATCH_USER_TEAM = 0x2C29
local DUEL_RESULT_KIND, DUEL_KIND_POWER = 0xB08, 6
local REQUEST_OFFENDER = 4

local band = bit32.band

local function read(kind, at)
  if not at or at < 0x10000 then return nil end
  local ok, v = pcall(VRFW.mem.read, kind, at)
  if ok then return v end
  return nil
end

local function game_global(name)
  local ok, p = pcall(VRFW.game[name])
  if ok and type(p) == "number" and p >= 0x10000 then return p end
  return nil
end

local function team_of(handle)
  local index = band(handle or 0, 0xFF)
  local actors = game_global("Match.SoccerActors.ViaSkillUsed")
  if handle == 0 or index >= ACTOR_COUNT or not actors then return nil end
  local actor = actors + index * ACTOR_STRIDE
  if read("u32", actor + ACTOR_HANDLE) ~= handle then return nil end
  return read("u8", actor + ACTOR_TEAM)
end

VRFW.on("hook:LegendaryMatch.FoulRate:post", function(ev)
  local duel = game_global("legendary_duel")
  if not duel or read("u8", duel + DUEL_RESULT_KIND) ~= DUEL_KIND_POWER then return nil end
  local match = game_global("legendary_match_info")
  local user = match and read("u8", match + MATCH_USER_TEAM)
  if user ~= 0 and user ~= 1 then return nil end
  local offender = read("u32", ev.args[1] + REQUEST_OFFENDER)
  local team = team_of(offender)
  if team == nil or team == user then return nil end
  local rate = SETTINGS.rival_power_action_foul_rate
  VRFW.log(string.format("legendary_match: rival power action foul chance 0x%08X: %.3f -> %.3f", offender, ev.ret or 0, rate))
  return { ret = rate }
end)
