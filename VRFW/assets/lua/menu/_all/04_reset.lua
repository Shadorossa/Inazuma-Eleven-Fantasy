-- VRFW_Reset: the game reset into the next state, one function for every caller (the top bar's straight reset, the
-- title's leave over a menu scene, a title row button with `root_menu`). docs/framework/top-bar.md §15.
--
--   VRFW_Reset.straight{ menu = <menu crc32 | name> | nil, vs = true | nil, title_mode = <n> | nil, bgm_stop = true,
--     need_carry = true, log = function(text) end }
--     -> "straight": the new rpg scene loads the kept game and opens the next state (no title);
--        "title": the reset happened, the title runs and reads the slot from its file;
--        "refused": no carry and `need_carry`: nothing was reset.
--   The game is kept in memory (CMND_VRFW_SLOT_CARRY(1)), the next state written as the retail title writes it before
--   its Continue (menu nil and no vs: the one the title already wrote), CMND_GAME_RESET, then
--   CMND_VRFW_MENU_TOPBAR_DIRECT skips the title. Yields while a save job runs: call it from a coroutine.
--   VRFW_Reset.to_title(): the retail reset to the title (no next state, the title opens its main menu at once).
-- Defines functions only: no engine call at load time.
VRFW_Reset = VRFW_Reset or {}
do
  local R = VRFW_Reset
  local C = {
    SAVE_WORKING = 1979970074,   -- a save / load job runs
    CARRY = VRFW_Cmd.VRFW_SLOT_CARRY,             -- CMND_VRFW_SLOT_CARRY (1 keep, 0 drop) -> kept, KiB, play s, players, why
    STRAIGHT = VRFW_Cmd.VRFW_MENU_TOPBAR_DIRECT,  -- CMND_VRFW_MENU_TOPBAR_DIRECT () -> true: no title after the reset
    GAME_RESET = VRFW_Cmd.GAME_RESET,             -- CMND_GAME_RESET
    BGM_STOP = VRFW_Cmd.BGM_STOP,                 -- CMND_BGM_STOP
    NEXT_MENU = 3479138216,      -- (funcLuaMenuCommand) the root menu of the next state
    NO_PRESS_START = 937976662,  -- (true) the next title opens its main menu at once
    VS_NEXT = 419468738, VS_NEXT2 = 1507811093,   -- the VS menu as the next state (the title's SetupNextStateVsMenu)
    TITLE_MODE = 3718253404,     -- the title's mode value
  }

  -- the next state as the retail title writes it before its Continue: a root menu (0 = none) or the VS menu
  function R.next_state(menu, vs, title_mode)
    if type(menu) == "string" then menu = VRFW_Crc32(menu) end
    pcall(funcLuaMenuCommand, C.NEXT_MENU, vs and 0 or (menu or 0))
    pcall(funcLuaCommand, C.NO_PRESS_START, true)
    pcall(funcLuaCommand, C.VS_NEXT, vs == true)
    pcall(funcLuaCommand, C.VS_NEXT2, vs == true)
    if title_mode ~= nil then pcall(funcLuaCommand, C.TITLE_MODE, title_mode) end
  end

  function R.straight(spec)
    spec = spec or {}
    local log = type(spec.log) == "function" and spec.log or function() end
    for _ = 1, 300 do
      local okw, busy = pcall(funcLuaCommand, C.SAVE_WORKING)
      if not (okw and busy == true) then break end
      coroutine.yield()
    end
    local okc, kept, kib, play, players, why = pcall(funcLuaCommand, C.CARRY, 1)
    kept = okc and kept == true
    if kept then
      log("game kept in memory: " .. tostring(kib) .. " KiB, play " .. tostring(play) .. " s, " .. tostring(players) .. " players")
    else
      log("no carry (" .. tostring(okc and why or kept) .. ")")
      if spec.need_carry then return "refused" end
    end
    if spec.bgm_stop then pcall(funcLuaCommand, C.BGM_STOP, 2) end
    if spec.menu ~= nil or spec.vs then
      R.next_state(spec.menu, spec.vs, spec.title_mode)
    elseif not kept then
      pcall(funcLuaCommand, C.NO_PRESS_START, true)
    end
    pcall(funcLuaCommand, C.GAME_RESET)
    if not kept then return "title" end
    local okd, r = pcall(funcLuaCommand, C.STRAIGHT)
    if okd and r == true then
      -- the loader's title-return timing ends here: no title comes after this reset
      pcall(funcLuaCommand, VRFW_Cmd.EVT_RESET_STRAIGHT, tostring(spec.menu or (spec.vs and "the VS menu") or "the next state"))
      log("straight reset: the new rpg scene opens the next state (no title)")
      return "straight"
    end
    pcall(funcLuaCommand, C.CARRY, 0)
    log("straight reset refused (" .. tostring(r) .. "): the title after the reset")
    return "title"
  end

  function R.to_title()
    R.next_state(0, false)
    pcall(funcLuaCommand, C.GAME_RESET)
  end
end
