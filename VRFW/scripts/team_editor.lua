-- Team editor: the kit of a team set's team (docs/framework/team-editor.md; content\game\team_editor.toml).
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_VRFW_TEAM_SET_KIT | set, team, uniform | ok, the set's uniform now (owned kit item cleared) |
-- | CMND_VRFW_TEAM_MEMBER_EXP | chara handle, share 0..1 | ok, the EXP inside his level now (his EXP bar at that share) |

TeamEditor = TeamEditor or {}

require "VRFW/lib/basics"
local info = VRFW.logger("team_editor")

local MAX_SET = 16
local TEAMS = 2

local Id = require "lib/ids"
local ExpTable = require "lib/exp_table"
local function u32(v) return Id.u32_or(v, nil) end

-- the TeamInfo record of (set, team), nil when the party is not there yet
local function team_info(set, team)
  local party = VRFW.game.TeamEditorParty()
  if not party then
    return nil
  end
  local ok, p = pcall(VRFW.call, "Team.SetStruct", party, set, team)
  if not ok or not p or p < 0x10000 then
    return nil
  end
  local ok2, rec = pcall(VRFW.mem.struct, "TeamEditorTeamInfo", p)
  return ok2 and rec or nil
end

function TeamEditor.SetKit(set, team, uniform)
  set, team, uniform = u32(set), u32(team), u32(uniform)
  if not set or not team or not uniform or uniform == 0 or set > MAX_SET or team >= TEAMS then
    return false, 0
  end
  local rec = team_info(set, team)
  if not rec then
    return false, 0
  end
  local okr, before = pcall(function() return rec.Uniform end)
  local ok = pcall(function()
    rec.Uniform = uniform
    rec.UniformItem = 0
  end)
  local okn, now = pcall(function() return rec.Uniform end)
  now = okn and now or 0
  info(string.format("set %d team %d: kit 0x%08X -> 0x%08X (ok %s)", set, team, okr and before or 0, now, tostring(ok)))
  return ok and now == uniform, now
end

-- a character record's EXP inside its current level (VRFW.chara.record(handle).addr + 8)
local RECORD_EXP = 8

-- CMND_VRFW_TEAM_MEMBER_EXP(handle, share): the character's EXP bar filled to `share` of his current level (0..1, below
-- the next level: no level-up): the EXP inside his level = share x the level's EXP (the EXP table x his rarity's rate)
function TeamEditor.MemberExp(handle, share)
  handle, share = u32(handle), tonumber(share)
  if not handle or handle == 0 or share == nil then return false, 0 end
  local ok, rec = pcall(VRFW.chara.record, handle)
  if not ok or type(rec) ~= "table" or not rec.addr or not tonumber(rec.level) then return false, 0 end
  local need = ExpTable.need(rec.level, rec.rarity)
  if not need then return false, 0 end
  local exp = math.max(0, math.min(math.floor(need) - 1, math.floor(need * math.max(0, math.min(1, share)))))
  if not pcall(VRFW.mem.write, "u32", rec.addr + RECORD_EXP, exp) then return false, 0 end
  return true, exp
end
