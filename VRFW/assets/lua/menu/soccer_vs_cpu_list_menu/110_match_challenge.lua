-- match_challenge (VR-Framework service): the free-match list («Competir contra
-- bots» / «Partido libre», soccer_vs_cpu_list_menu) checks a row's match challenge before the match is chosen.
-- * around OnEnter of the opponent list (team05_03_soccer_cpu_opponent_list): after the retail team check, a row whose
--   game has a [[VRFW.MatchChallenge]] (the tab's `Challenge`, or the challenge's `Games`) is refused when the active
--   dock does not meet it: error sound + the message with the conditions (VRFW_MC.Gate); returning 1 keeps the list
--   open (the retail «team not valid» path), so the player can change the dock (L / R menu) and try again.
-- * after OnChangeFocus of a row (mainmenu90_19_vs_cpu_list_item): the guide line shows «Desafío: <title>» for a row
--   with a challenge, the retail line otherwise.
-- Handlers of the framework's host of this script (000_host.lua). No engine call at load time.
if VRFW_Host ~= nil then
  local MCL = {
    LIST = 1107559438,        -- team05_03_soccer_cpu_opponent_list
    ITEM = 1074924810,        -- mainmenu90_19_vs_cpu_list_item
    FOCUS_DATA = 1666448199,  -- (0) -> ok, the focused row's game
    GUIDE = 3078308064,       -- mainmenu90_05_content_guide_line01
    GUIDE_MESH = 378156699,   -- _text_guide01
    GUIDE_RETAIL = 3822200449, -- the retail guide text
    SET_TEXT = 1083631230,    -- CMND_SET_MENU_TEXT_STRING
    TEXT_GET = 4074371074,
    HEAD = 2317620035,        -- vrfw_mc_head «Desafío: %s»
    shown = false,
  }

  local function focused_game()
    local ok, okd, game = pcall(funcLuaMenuCommand, MCL.FOCUS_DATA, 0)
    if ok and okd and type(game) == "number" and game ~= 0 then
      return game
    end
    return nil
  end

  VRFW_Host.on("soccer_vs_cpu_list_menu", "OnEnter", {
    id = "menu_engine.match_challenge", phase = "around",
    fn = function(nxt, a1, a2, ...)
      local r = table.pack(nxt(a1, a2, ...))
      if a1 ~= MCL.LIST or r[1] == 1 or VRFW_MC == nil then
        return table.unpack(r, 1, r.n)
      end
      local game = focused_game()
      if game ~= nil and not VRFW_MC.Gate(game, 0) then
        return 1
      end
      return table.unpack(r, 1, r.n)
    end,
  })

  VRFW_Host.on("soccer_vs_cpu_list_menu", "OnChangeFocus", {
    id = "menu_engine.match_challenge", phase = "after",
    fn = function(r, a1, ...)
      if a1 ~= MCL.ITEM or VRFW_MC == nil then
        return
      end
      local game = focused_game()
      local title = game and VRFW_MC.TitleOf(game)
      if title ~= nil then
        local okf, head = pcall(funcLuaCommand, MCL.TEXT_GET, MCL.HEAD)
        local s = (okf and type(head) == "string" and head ~= "") and string.format(head, title) or title
        funcLuaMenuCommand(MCL.SET_TEXT, MCL.GUIDE, MCL.GUIDE_MESH, s, 0)
        MCL.shown = true
      elseif MCL.shown then
        local okr, s = pcall(funcLuaCommand, MCL.TEXT_GET, MCL.GUIDE_RETAIL)
        funcLuaMenuCommand(MCL.SET_TEXT, MCL.GUIDE, MCL.GUIDE_MESH, okr and s or "", 0)
        MCL.shown = false
      end
    end,
  })
end
