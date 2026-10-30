-- level_sync (VR-Framework base feature, docs/framework/level-sync.md §2): the VS screen's «NIVEL DEL EQUIPO» of the
-- user's team shows the level of the match's [[VRFW.LevelSync]] rule (raise: that level; cap: the lower of the team's
-- level and it). Only the number drawn: the match copies, their stats and moves are not touched here.
-- SetupTeamInfoLayer(layer, idx, self) reads the team level with GetSoccerTeamInfo(2, team); for the user's side
-- (self = true) that read answers the synced level. CMND_VRFW_LEVEL_SYNC () -> level, raise (0 = no rule).
-- No engine call at load time.

VRFW_LevelSyncVs = VRFW_LevelSyncVs or {}

do
  local V = VRFW_LevelSyncVs
  local CMD = VRFW_Cmd.VRFW_LEVEL_SYNC     -- crc32("CMND_VRFW_LEVEL_SYNC")
  local LOG = VRFW_Cmd.EVT_LOG     -- crc32("CMND_EVT_LOG")
  local TEAM_LEVEL = 2       -- CMND_GET_SOCCER_TEAM_INFO field: the team level

  local function synced()
    local ok, level, raise = pcall(funcLuaCommand, CMD)
    if ok and type(level) == "number" and level > 0 then
      return level, raise == 1
    end
    return nil
  end

  local retail = SetupTeamInfoLayer
  if type(retail) == "function" and V.wrapped ~= retail then
    SetupTeamInfoLayer = function(a1, a2, a3, ...)
      local level, raise = nil, false
      if a3 == true then
        level, raise = synced()
      end
      local info = GetSoccerTeamInfo
      if level == nil or type(info) ~= "function" then
        return retail(a1, a2, a3, ...)
      end
      GetSoccerTeamInfo = function(field, ...)
        local r = table.pack(info(field, ...))
        if field == TEAM_LEVEL and r[1] ~= false then
          local shown = level
          if not raise and type(r[2]) == "number" and r[2] < level then
            shown = r[2]
          end
          if r[2] ~= shown then
            pcall(funcLuaCommand, LOG, "level_sync", "VS screen team level", tostring(r[2]), "->", shown)
          end
          return true, shown
        end
        return table.unpack(r, 1, r.n)
      end
      local res = table.pack(pcall(retail, a1, a2, a3, ...))
      GetSoccerTeamInfo = info
      if not res[1] then
        error(res[2], 0)
      end
      return table.unpack(res, 2, res.n)
    end
    V.wrapped = SetupTeamInfoLayer
  end
end
