-- vs_route_town_vs_team_menu: the player's side of the Chronicle VS screen (graft.toml). Two retail drawers:
-- SetFormation (a team row: a Chronicle battle, also a node's forced own team, Cronica.OwnTeam) and
-- SetTeamDockFormation (the VS dock's 11-a-side team). Each one runs as retail, then VRFW_VSF.Apply.
do
@COMMON@
  local vrfw_vsf_set_formation = SetFormation
  function SetFormation(a1, a2, a3, a4, a5, a6, a7, ...)
    local r = table.pack(vrfw_vsf_set_formation(a1, a2, a3, a4, a5, a6, a7, ...))
    if type(a1) == "number" and a1 ~= 0 then
      local used = {}
      local okN, num = funcLuaCommand(2151743654, a1, 8)
      for k = 0, ((okN and type(num) == "number") and num or 0) - 1 do
        local ok, _, p = GetTeamMemberInfo(a1, k, a2, a3, true)
        if ok and type(p) == "number" and p >= 0 and p <= 19 then
          used[p] = true
        end
      end
      VRFW_VSF.Apply(used, a5, a6, a7, VRFW_VSF.LEADER_BLANK, "own team row")
    end
    return table.unpack(r, 1, r.n)
  end

  local vrfw_vsf_dock_formation = SetTeamDockFormation
  function SetTeamDockFormation(a1, a2, a3, a4, ...)
    local r = table.pack(vrfw_vsf_dock_formation(a1, a2, a3, a4, ...))
    local set = funcLuaCommand(@crc:CMND_GET_VS_USE_TEAM_SET@)
    if type(set) == "number" then
      local used = {}
      for i = 0, 28 do
        local okH = funcLuaCommand(1720957768, set, 0, i, 0)
        if okH then
          local okP, p = funcLuaCommand(1720957768, set, 0, i, 1)
          if okP and type(p) == "number" and p >= 0 and p <= 19 and not IsSoccerPosNo_Reserve(p) then
            used[p] = true
          end
        end
      end
      VRFW_VSF.Apply(used, a2, a3, a4, VRFW_VSF.LEADER_BLANK, "own dock")
    end
    return table.unpack(r, 1, r.n)
  end
end
