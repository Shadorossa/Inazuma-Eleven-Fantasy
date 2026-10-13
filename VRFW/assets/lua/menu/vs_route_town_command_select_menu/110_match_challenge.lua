-- match_challenge (VR-Framework service; docs/framework/match-challenge.md): the Chronicle board's command menu
-- (vs_route_town_command_select_menu, a VRFW_Host host of the framework's route_board graft) checks the piece's match
-- challenge before a difficulty row starts the match.
-- around OnEnter of the row list (vsroute01_16_sub_list): after the retail checks (locked difficulty, team not valid),
-- a match row (difficultyType > 0) of a piece whose game has a [[VRFW.MatchChallenge]] (the route node's `Challenge`, or
-- the challenge's `Games`) is refused when the active dock does not meet it: error sound + the message with the
-- conditions; returning 1 keeps the menu open (the retail refusal), so the player can open «Equipo» and try again.
-- The piece's game is VRFW_RBC.L.n4, the rows VRFW_RBC.L.t3 (route_board's rbc_common.lua). A chain «C» piece opens the
-- chain board instead: its tiles are checked there. No engine call at load time.
if VRFW_Host ~= nil then
  local ROWS = 284009563   -- vsroute01_16_sub_list

  VRFW_Host.on("vs_route_town_command_select_menu", "OnEnter", {
    id = "menu_engine.match_challenge", phase = "around",
    fn = function(nxt, a1, a2, ...)
      local r = table.pack(nxt(a1, a2, ...))
      if a1 ~= ROWS or r[1] == 1 or VRFW_MC == nil or VRFW_RBC == nil then
        return table.unpack(r, 1, r.n)
      end
      local ok, rows, game = pcall(function()
        return VRFW_RBC.L.t3, VRFW_RBC.L.n4
      end)
      local row = ok and type(rows) == "table" and type(a2) == "number" and rows[a2 + 1] or nil
      if row ~= nil and (row.difficultyType or 0) > 0 and type(game) == "number" and not VRFW_MC.Gate(game, 0) then
        return 1
      end
      return table.unpack(r, 1, r.n)
    end,
  })
end
