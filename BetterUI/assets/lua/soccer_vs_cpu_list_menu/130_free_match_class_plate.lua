-- BetterUI (mod clean_hud, prefix BetterUI), free match list («Partido libre», soccer_vs_cpu_list_menu): the team
-- banner at the top right shows no class plate («INAZUMA», the sprite the retail UpdateFormation swaps into
-- cpu_icon_class_dmy01 of mainmenu90_34_cpu_team_formation). The «Nv.» level and the class window stay. Visibility
-- only, after the retail draw: every retail argument goes through untouched (the framework's free match rules hide
-- the same mesh, with the level, when a game's PreviewClass is off). No engine call at load time.
if VRFW_Host ~= nil then
  VRFW_Host.on("soccer_vs_cpu_list_menu", "UpdateFormation", {
    id = "clean_hud.free_match_class_plate", phase = "after",
    fn = function(r, a1)
      if a1 ~= nil and a1 ~= 0 then
        pcall(funcLuaMenuCommand, 3405944500 --[[CMND_SET_MESH_VISIBLE]], 1835074715 --[[mainmenu90_34_cpu_team_formation]],
          126765991 --[[_cpu_icon_class_dmy01]], false, 0)
      end
    end,
  })
end
