-- BetterUI (mod clean_hud, prefix BetterUI), Chronicle VS screen, your half (vs_route_town_vs_team_menu): X switches
-- the player cards between «Preview» and «Basic data» (assets\lua\_all\vs_basic_data.lua). The retail X
-- (OnFunction 3702644710: the game's full name / nickname switch, then both halves drawn again) becomes: the view
-- switched, your half drawn again, then the rival's menu told (funcLuaMenuCommand 586982911 = its SwitchNickname,
-- which draws the rival's half and the pill again). The screen opens in «Preview». Your half follows the view when
-- the screen draws it with SetFormation (a Chronicle battle); a team-dock half (SetTeamDockFormation) keeps the
-- compact cards. No engine call at load time.
if VRFW_Host ~= nil and BetterUI ~= nil and BetterUI.VsBasicData ~= nil then
  local V = BetterUI.VsBasicData
  local SWITCH_FUNCTION = 3702644710      -- the X key's CMD_FUNCTION (retail: switch the name form)
  local TELL_RIVAL = 586982911            -- calls SwitchNickname of vs_route_town_vs_enemy_formation_menu

  VRFW_Host.on("vs_route_town_vs_team_menu", "OnInit", {
    id = "clean_hud.vs_basic_data_open", phase = "before",
    fn = function()
      V.last = nil
      V.SetBasic(false)
    end,
  })

  VRFW_Host.on("vs_route_town_vs_team_menu", "SetFormation", {
    id = "clean_hud.vs_basic_data_draw", phase = "around",
    fn = function(nxt, ...)
      return V.Draw(nxt, ...)
    end,
  })

  VRFW_Host.on("vs_route_town_vs_team_menu", "OnFunction", {
    id = "clean_hud.vs_basic_data_switch", phase = "around",
    fn = function(nxt, a1, ...)
      if a1 ~= SWITCH_FUNCTION then
        return nxt(a1, ...)
      end
      V.SetBasic(not V.IsBasic())
      V.Redraw()
      pcall(funcLuaMenuCommand, TELL_RIVAL)
    end,
  })
end
