-- vs_route_town_vs_enemy_formation_menu: the rival's side of the Chronicle VS screen (graft.toml). The retail
-- SetFormation runs as it is, then VRFW_VSF.Apply on the rival's members. A rival without a team row (a1 == 0: the
-- retail placeholder formation, 20 dummy cards) stays retail.
do
@COMMON@
  local vrfw_vsf_set_formation = SetFormation
  function SetFormation(a1, a2, a3, a4, a5, a6, a7, a8, ...)
    local r = table.pack(vrfw_vsf_set_formation(a1, a2, a3, a4, a5, a6, a7, a8, ...))
    if type(a1) == "number" and a1 ~= 0 then
      local used = {}
      local okN, num = funcLuaCommand(2151743654, a1, 8)
      for k = 0, ((okN and type(num) == "number") and num or 0) - 1 do
        local ok, _, p = GetTeamMemberInfo(a1, k, a2, a3)
        if ok and type(p) == "number" and p >= 0 and p <= 19 then
          used[p] = true
        end
      end
      VRFW_VSF.Apply(used, a5, a6, a7, a8, "rival team row")
    end
    return table.unpack(r, 1, r.n)
  end
end
