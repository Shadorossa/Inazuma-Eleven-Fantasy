-- BattleBayDeluxe bb_tournament, the game-over telop (game_over_menu). A lost or drawn Battle Bay campaign match ends
-- in the game's GameOver telop; a tournament match borrows the campaign's block, so the telop came after every group
-- defeat and after every league match that was not a win. When its telop layer opens, the tournament is asked once
-- (CMND_BBD_TOURN_STILL_IN): a group-stage defeat that leaves the player in the run and EVERY league match (a draw or a
-- defeat is a normal league result) close the menu without showing it; the top menu's sync then records the result and
-- the overlay shows the matchday's results (Enter = the League hub). A defeat that ends the run (or any other game over)
-- keeps the retail telop.
-- BBD 1.55.0 (owner 2026-10-29: a 0-0 league draw left the screen black forever): the close used to run inside the
-- telop layer's own opening (OnOpenLayer), while the menu was still opening; the engine never closed the menu and the
-- retail close had already faded the screen to black. Now the telop is hidden at once and the retail close
-- (CloseMenu_Coroutine, manage coroutine 2, the same one the telop's own button runs) is started from the menu's Step
-- once the menu has run CLOSE_AFTER Steps. If the menu still exists GIVE_UP Steps later, the skip is undone: the screen
-- fades back in and the retail telop opens (its button closes the menu as in retail), so a skipped telop always
-- continues to the next screen.
-- Globals only; nothing runs at chunk load.
BattleBayDeluxe = type(BattleBayDeluxe) == "table" and BattleBayDeluxe or {}
BattleBayDeluxe.TournamentGameOver = { MENU = 2754376147 --[[game_over_menu]], TELOP = 3428917655, CLOSE_AFTER = 6, GIVE_UP = 240,
  state = nil, steps = 0 }

-- the logger (VRFW_Log), made at the first line: the framework's menu files load after the graft blocks
function BBT_OverLog(...)
  BattleBayDeluxe.TournamentGameOver.logger = BattleBayDeluxe.TournamentGameOver.logger or VRFW_Log.New("BattleBayDeluxe.tournament")
  BattleBayDeluxe.TournamentGameOver.logger(...)
end

do
  local open_layer = OnOpenLayer
  function OnOpenLayer(a1, a2, ...)
    if a1 == BattleBayDeluxe.TournamentGameOver.TELOP and BattleBayDeluxe.TournamentGameOver.state == nil then
      local ok, still_in = pcall(funcLuaCommand, @crc:CMND_BBD_TOURN_STILL_IN@)
      if ok and still_in == true then
        BBT_OverLog(
          "game over skipped (a league match, or a group-stage defeat that keeps the player in the run): the menu closes")
        funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, a1, a2 or 0, false)
        BattleBayDeluxe.TournamentGameOver.state, BattleBayDeluxe.TournamentGameOver.steps = "skip", 0
        return
      end
      BattleBayDeluxe.TournamentGameOver.state = "retail"
    end
    return open_layer(a1, a2, ...)
  end

  local step = Step
  function Step(...)
    local O = BattleBayDeluxe.TournamentGameOver
    if O.state == "skip" or O.state == "closing" then
      O.steps = O.steps + 1
      if O.state == "skip" and O.steps >= O.CLOSE_AFTER then
        O.state = "closing"
        RunManageCoroutine(2)
        BBT_OverLog(
          "game over skipped: the retail close started after " .. O.steps .. " Steps")
      elseif O.state == "closing" and O.steps >= O.GIVE_UP then
        -- the menu did not close: the retail telop after all (its button continues)
        O.state = "retail"
        BBT_OverLog(
          "game over skip: the menu did not close in " .. O.GIVE_UP .. " Steps; the retail telop is shown")
        pcall(funcLuaCommand, 609722083 --[[fade black]], 0, 0.3)
        funcLuaMenuCommand(@crc:CMND_SET_LAYER_VISIBLE@, O.TELOP, 0, true)
        RunManageCoroutine(1)
      end
    end
    return step(...)
  end
end
