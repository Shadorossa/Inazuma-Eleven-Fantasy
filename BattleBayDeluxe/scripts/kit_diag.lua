-- Kit diagnostic: one log line per match team, the first time a player of that team is dressed in a match.
-- Line: «kit diag: side S (user|cpu) team 0x… declared kit 0x… match uniform 0x… dressed typeId T (alternative bit A,
-- team alternate flag F) rival kit 0x… (declared 0x…)».
-- Sources: the match teams of the last match request (state vr_framework.team_lineup.match_teams: +0 the player's team,
-- +4 the rival), their team_config records (FindTeamConfig, ActiveTeamRecord.uniform), the match team blocks
-- ([[g_gameRoot]+Game.RootMatch]+0x60 + side * 0x1130: +0x1040 uniform, +0x1101 alternate flag; +0x2C29 the user's side)
-- and the look flags of each dressed player (hook VRFW.MatchLook, bit 1 = the alternate model row, typeId 1).

local U = require "lib/util"

local M = {}

local MATCH_TEAMS_KEY = "vr_framework.team_lineup.match_teams"
local TEAM_FIRST, TEAM_STRIDE = 0x60, 0x1130
local TEAM_UNIFORM, TEAM_ALTERNATE, USER_SIDE = 0x1040, 0x1101, 0x2C29
local STAFF_FLAGS = 0x30

local logged = {}

require "VRFW/lib/basics"
local log = VRFW.logger("kit diag")

local function declared_kit(team)
  if not team or team == 0 or not VRFW.is_on("FindTeamConfig") then
    return 0
  end
  local okb, recb = pcall(VRFW.mem.buffer, "bbd_kit_diag_rec", 8)
  local okc, contb = pcall(VRFW.mem.buffer, "bbd_kit_diag_cont", 8)
  local okh, hashb = pcall(VRFW.mem.buffer, "bbd_kit_diag_hash", 4)
  if not (okb and okc and okh) then
    return 0
  end
  U.wr("u64", recb, 0)
  U.wr("u64", contb, 0)
  U.wr("u32", hashb, team)
  if not U.call("FindTeamConfig", recb, contb, hashb) then
    return 0
  end
  local rec = U.rd("ptr", recb) or 0
  return U.u32(U.get(U.struct("ActiveTeamRecord", rec), "uniform") or 0)
end

-- the request's teams by match side: { [side] = team id }
local function teams_by_side(match)
  local ok, block = pcall(VRFW.state.get, MATCH_TEAMS_KEY)
  if not ok or type(block) ~= "number" or block < 0x10000 then
    return {}
  end
  local user = U.rd("u8", match + USER_SIDE) or 0
  if user > 1 then
    return {}
  end
  return { [user] = U.rd("u32", block) or 0, [1 - user] = U.rd("u32", block + 4) or 0 }
end

local function on_look(ev)
  if logged[0] and logged[1] then
    return nil
  end
  local args = ev and ev.args
  local flags, uniform = args and tonumber(args[2]), args and tonumber(args[4])
  if not flags or not uniform or math.floor(flags / 16) % 4 ~= 0 then
    return nil
  end
  local match = U.global("kit_diag_match")
  if not match then
    return nil
  end
  local alt = math.floor(flags / 2) % 2
  local block = {}
  for side = 0, 1 do
    local at = match + TEAM_FIRST + side * TEAM_STRIDE
    block[side] = { uniform = U.u32(U.rd("u32", at + TEAM_UNIFORM) or 0), alternate = U.rd("u8", at + TEAM_ALTERNATE) or 0 }
  end
  uniform = U.u32(uniform)
  local side
  if block[0].uniform ~= block[1].uniform then
    side = (uniform == block[0].uniform and 0) or (uniform == block[1].uniform and 1) or nil
  elseif uniform == block[0].uniform then
    side = (alt == block[0].alternate and 0) or (alt == block[1].alternate and 1) or nil
  end
  if side == nil or logged[side] then
    return nil
  end
  logged[side] = true
  local teams = teams_by_side(match)
  local other = 1 - side
  local user = U.rd("u8", match + USER_SIDE)
  log(string.format("side %d (%s) team %s declared kit %s match uniform %s dressed typeId %d (alternative bit %d, team alternate flag %d) rival kit %s (declared %s)",
    side, user == side and "user" or "cpu", U.hex(teams[side] or 0), U.hex(declared_kit(teams[side])), U.hex(block[side].uniform),
    alt, alt, block[side].alternate, U.hex(block[other].uniform), U.hex(declared_kit(teams[other]))))
  return nil
end

VRFW.on("match_start", function()
  logged = {}
  return nil
end)
VRFW.on("hook:VRFW.MatchLook", on_look)

return M
