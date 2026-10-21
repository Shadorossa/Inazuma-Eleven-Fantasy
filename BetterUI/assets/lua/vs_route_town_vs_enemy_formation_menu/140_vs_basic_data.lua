-- BetterUI (mod clean_hud, prefix BetterUI), Chronicle VS screen, the rival's half
-- (vs_route_town_vs_enemy_formation_menu): its cards in the view your half's menu chose (assets\lua\_all\
-- vs_basic_data.lua). SwitchNickname (called by your half's menu on X) draws the rival's half again in the new view
-- instead of the retail name form switch; the pill under the pitch («X Apodo» in the game) names the view X switches
-- to («Basic data» / «Preview»). No engine call at load time.
if VRFW_Host ~= nil and BetterUI ~= nil and BetterUI.VsBasicData ~= nil then
  local V = BetterUI.VsBasicData

  VRFW_Host.on("vs_route_town_vs_enemy_formation_menu", "OnInit", {
    id = "clean_hud.vs_basic_data_open", phase = "before",
    fn = function()
      V.last = nil
    end,
  })

  VRFW_Host.on("vs_route_town_vs_enemy_formation_menu", "SetFormation", {
    id = "clean_hud.vs_basic_data_draw", phase = "around",
    fn = function(nxt, ...)
      return V.Draw(nxt, ...)
    end,
  })

  VRFW_Host.on("vs_route_town_vs_enemy_formation_menu", "UpdateNicknameButtonText", {
    id = "clean_hud.vs_basic_data_pill", phase = "around",
    fn = function()
      V.UpdatePill()
    end,
  })

  VRFW_Host.on("vs_route_town_vs_enemy_formation_menu", "SwitchNickname", {
    id = "clean_hud.vs_basic_data_switch", phase = "around",
    fn = function()
      V.UpdatePill()
      V.Redraw()
    end,
  })
end
