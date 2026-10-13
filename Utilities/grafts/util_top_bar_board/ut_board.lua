-- Utilities util_top_bar_board (graft.toml; BetterUI's clean_hud_chronicle_board until 2026-10-12): the top bar step `chronicle_board` lands on the Chronicle board.
Utilities = type(Utilities) == "table" and Utilities or {}
Utilities.TopBar = type(Utilities.TopBar) == "table" and Utilities.TopBar or {}
Utilities.TopBar.Board = {skip = false, co = nil}
Utilities.TopBar.Board.STEP = "chronicle_board"      -- the step name entries declare in `action.path`
Utilities.TopBar.Board.MENU = 3902542018             -- chronicle_mode_top_menu
Utilities.TopBar.Board.BG = 117665605                -- vsroute04_03_chronicle_top_bg (its open starts the caravan / fade-in)

function Utilities.TopBar.Board.Log(...)
  pcall(funcLuaCommand, 3661580131 --[[CMND_EVT_LOG]], "utilities chronicle_board", ...)
end

function Utilities.TopBar.Board.Wanted()
  if type(VRFW_TopBarStep) ~= "function" or not VRFW_TopBarStep(Utilities.TopBar.Board.STEP) then
    return false
  end
  local mode = funcLuaCommand(2769028935 --[[CMND_GET_GLOBAL_BYTE_FLAG]], 3152001072)
  if mode == 0 or mode == 2 then
    Utilities.TopBar.Board.Log("menu shown: chronicle mode byte", tostring(mode))
    return false
  end
  if not funcLuaCommand(941426960 --[[CMND_GET_GLOBAL_BIT_FLAG]], 1169930310) then
    Utilities.TopBar.Board.Log("menu shown: the Chronicle tutorial is not confirmed yet")
    return false
  end
  if funcLuaCommand(2283097588 --[[CMND_GET_TEMP_BIT_FLAG]], 774062760)
      or funcLuaCommand(2283097588 --[[CMND_GET_TEMP_BIT_FLAG]], 3914011134) then
    Utilities.TopBar.Board.Log("menu shown: a Players Universe event is reserved")
    return false
  end
  return true
end

-- the end of the retail UpdateVsRouteTownSceneChange (the board of the route the menu holds), screen kept black
function Utilities.TopBar.Board.Board()
  funcLuaMenuCommand(1558704558, Utilities.TopBar.Board.MENU, false)
  funcLuaCommand(609722083, 1, 0)
  coroutine.yield()
  funcLuaCommand(2565779025, 207055258, 0)
  funcLuaCommand(667984508 --[[CMND_SET_TEMP_BYTE_FLAG]], 2502072435, 0)
  funcLuaCommand(769636339, 1.5)
  funcLuaCommand(320421347 --[[CMND_CLOSE_MENU_OBJECT]], Utilities.TopBar.Board.MENU)
  if not funcLuaCommand(2283097588 --[[CMND_GET_TEMP_BIT_FLAG]], 3914011134) then
    funcLuaMenuCommand(890340801)
  end
  local route = funcLuaMenuCommand(1951539112)
  Utilities.TopBar.Board.Log("board: route", tostring(route))
  funcLuaCommand(2919847010 --[[CMND_RESERVE_VSROUTE?]], route, 0, 0, 1, 2976993266)
end

do
  local init = OnInit
  function OnInit(...)
    Utilities.TopBar.Board.skip, Utilities.TopBar.Board.co = false, nil
    local ok, want = pcall(Utilities.TopBar.Board.Wanted)
    if ok and want then
      Utilities.TopBar.Board.skip = true
      funcLuaCommand(609722083, 1, 0) -- stays black: the menu is never seen
      Utilities.TopBar.Board.Log("top bar step chronicle_board: straight to the board")
    end
    return init(...)
  end
  local open = OnOpenLayer
  function OnOpenLayer(a1, a2, ...)
    if Utilities.TopBar.Board.skip and a1 == Utilities.TopBar.Board.BG then
      Utilities.TopBar.Board.skip = false
      Utilities.TopBar.Board.co = coroutine.create(Utilities.TopBar.Board.Board)
      return
    end
    return open(a1, a2, ...)
  end
  local step = Step
  function Step(...)
    local r = table.pack(step(...))
    if Utilities.TopBar.Board.co ~= nil then
      local ok, err = coroutine.resume(Utilities.TopBar.Board.co)
      if not ok then
        Utilities.TopBar.Board.Log("error", tostring(err))
        funcLuaCommand(609722083, 0, 0.3)
        funcLuaMenuCommand(1558704558, Utilities.TopBar.Board.MENU, true)
      end
      if not ok or coroutine.status(Utilities.TopBar.Board.co) == "dead" then
        Utilities.TopBar.Board.co = nil
      end
    end
    return table.unpack(r, 1, r.n)
  end
end
