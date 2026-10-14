-- Player Training › the retail skill board's bean slot (graft player_training_beans). HOOK file (shipped as is: the
-- command and text ids below are numbers, their names in the comments). While the mod's beans hook is on
-- (CMND_PLAYERTRAINING_BEANS_OFF answers true) the bean slot's coroutine shows a retail info window («the training
-- beans have no effect») instead of opening the retail bean menu, then ends the way the retail coroutine ends (the
-- board active again, its notices 7 and 8). Otherwise the retail coroutine runs as before. Definitions and the wrap
-- only at chunk load (no engine call).
do
  PlayerTraining_Beans = PlayerTraining_Beans or {}
  local Beans = PlayerTraining_Beans
  Beans.BEANS_OFF = 936507269                       -- CMND_PLAYERTRAINING_BEANS_OFF () -> true while the beans give nothing
  Beans.TEXT_GET = 4074371074                       -- CMND_TEXT_GET (text id) -> the text in the game's language
  Beans.MESSAGE = 2472634560                        -- menu_text evt_tr_beans_off (text\rows\training.toml)
  Beans.BOARD_MENU = 1810526795                     -- ability_learning_board_menu
  Beans.SET_MENU_ACTIVE = 1558704558                -- (menu, active): the retail coroutine's own switch
  Beans.BOARD_NOTICE = 1340085986                   -- (n): the board's coroutine notices (the bean coroutine ends with 7, 8)
  Beans.NOTICE_SET_DONE = 7
  Beans.NOTICE_EFFECT_DONE = 8
  Beans.PLAY_SOUND = 1917805374
  Beans.SOUND_REFUSED = 2086672038                  -- sy0003 (the retail «cannot» sound)
  Beans.WINDOW_BUSY = 898725220                     -- general window: still opening
  Beans.WINDOW_CLOSED = 682363669                   -- general window: closed
  Beans.WINDOW_WAIT = 600                           -- frames the window may take before it is left alone

  function Beans.Off()
    local ok, off = pcall(funcLuaCommand, Beans.BEANS_OFF)
    return ok and off == true
  end

  function Beans.MessageText()
    local ok, text = pcall(funcLuaCommand, Beans.TEXT_GET, Beans.MESSAGE)
    if ok and type(text) == "string" and text ~= "" then
      return text
    end
    return nil
  end

  -- inside the board's coroutine 7: the info window, then the retail coroutine's ending
  function Beans.ShowNoEffect()
    local text = Beans.MessageText()
    funcLuaMenuCommand(Beans.SET_MENU_ACTIVE, Beans.BOARD_MENU, false)
    if text ~= nil and GENERAL_WINDOW ~= nil and GENERAL_WINDOW.ReserveGeneralWindow ~= nil then
      GENERAL_WINDOW.ReserveGeneralWindow("", "", "", text, 0, 0, 0, 0, 0, false)
      funcLuaCommand(Beans.PLAY_SOUND, Beans.SOUND_REFUSED)
      local frames = 0
      waitFalse(function()
        frames = frames + 1
        return funcLuaCommand(Beans.WINDOW_BUSY) and frames < Beans.WINDOW_WAIT
      end)
      waitTrue(function()
        frames = frames + 1
        return funcLuaCommand(Beans.WINDOW_CLOSED) or frames >= Beans.WINDOW_WAIT
      end)
    else
      funcLuaCommand(Beans.PLAY_SOUND, Beans.SOUND_REFUSED)
    end
    funcLuaMenuCommand(Beans.SET_MENU_ACTIVE, Beans.BOARD_MENU, true)
    funcLuaMenuCommand(Beans.BOARD_NOTICE, Beans.NOTICE_SET_DONE)
    funcLuaMenuCommand(Beans.BOARD_NOTICE, Beans.NOTICE_EFFECT_DONE)
  end

  -- once per VM; the retail OnInit registers the wrapper as coroutine 7 (it reads the global when it runs)
  if not Beans.wrapped and OpenBeansSetMenu_Coroutine ~= nil then
    local previous = OpenBeansSetMenu_Coroutine
    OpenBeansSetMenu_Coroutine = function(...)
      if not Beans.Off() then
        return previous(...)
      end
      return Beans.ShowNoEffect()
    end
    Beans.wrapped = true
  end
end
