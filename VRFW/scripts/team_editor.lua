-- Team editor: the kit of a team set's team (docs/framework/team-editor.md; content\game\team_editor.toml).
-- | Command | Args | Returns |
-- |---|---|---|
-- | CMND_VRFW_TEAM_SET_KIT | set, team, uniform | ok, the set's uniform now (owned kit item cleared) |

TeamEditor = TeamEditor or {}

require "VRFW/lib/basics"
local info = VRFW.logger("team_editor")

local MAX_SET = 16
local TEAMS = 2

local Id = require "lib/ids"
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
