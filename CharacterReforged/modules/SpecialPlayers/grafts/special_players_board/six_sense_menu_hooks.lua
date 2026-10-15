-- Special Players › the game's custom passive equip menu (equip_six_sense_menu; graft special_players_board). HOOK file
-- (shipped as is): the slot holds each player's own passive («Pasiva propia») and cannot be changed, so «equip» on a
-- row plays the retail «cannot» sound and changes nothing; every other key is the game's. No retail function is
-- replaced; no engine call at chunk load.
do
  SpecialPlayers_SixSenseMenu = SpecialPlayers_SixSenseMenu or {}
  local Menu = SpecialPlayers_SixSenseMenu
  Menu.EQUIP = 4067673008                             -- OnFunction id of «equip»
  Menu.SOUND = 1917805374                             -- play a system sound
  Menu.SOUND_CANNOT = 2086672038                      -- sy0003, the retail «cannot»

  function Menu.WrapGlobal(name, make)
    Menu.wrappers = Menu.wrappers or {}
    local current = _ENV[name]
    if current == nil or Menu.wrappers[name] == current then
      return
    end
    local wrapper = make(current)
    Menu.wrappers[name] = wrapper
    _ENV[name] = wrapper
  end

  Menu.WrapGlobal("OnFunction", function(previous)
    return function(a1, ...)
      if a1 == Menu.EQUIP then
        pcall(funcLuaCommand, Menu.SOUND, Menu.SOUND_CANNOT)
        return
      end
      return previous(a1, ...)
    end
  end)
end
