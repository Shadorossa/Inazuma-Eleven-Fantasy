-- Utilities, player plate («Ficha», personal_plate_menu): on Battle Bay Deluxe's lineup screen (the «Plantilla»
-- viewer of the Battle Bay grid, the player page on its right half) the page leaves out two pages: the team passives
-- (vrfw.TeamPassives, the page Utilities' passive configuration edits) and TRAYECTORIA (Utilities.Career). Q / E and
-- the page dots skip them (VRFW_PlayerPages.ShowWhen, docs/framework/player-pages.md). That screen is recognised by the
-- parameter BattleBayDeluxe.lineup of the game's parameter store (set by Battle Bay Deluxe while its player page is up)
-- inside the framework context battle_bay. Elsewhere both pages stay.
-- Conditions only; no engine call at load time.
Utilities = type(Utilities) == "table" and Utilities or {}
if Utilities.LineupPages == nil and VRFW_PlayerPages ~= nil and type(VRFW_PlayerPages.ShowWhen) == "function" then
  local L = {
    FLAG = 2100506454,                   -- crc32 of BattleBayDeluxe.lineup (Battle Bay Deluxe's parameter)
    CONTEXT = "battle_bay",              -- the framework context of the Battle Bay's menus
    PARAM_EXISTS = 2947612279,
    MODE_IS = 624411898,                 -- CMND_VRFW_MODE_IS
    PAGES = {"vrfw.TeamPassives", "Utilities.Career"},
  }
  Utilities.LineupPages = L

  -- false while the lineup screen shows this page
  function L.Shown()
    local ok, has = pcall(funcLuaCommand, L.PARAM_EXISTS, L.FLAG)
    if not (ok and has == true) then
      return true
    end
    local okm, inside = pcall(funcLuaCommand, L.MODE_IS, L.CONTEXT)
    return not (okm and inside == true)
  end

  for _, name in ipairs(L.PAGES) do
    VRFW_PlayerPages.ShowWhen(name, L.Shown)
  end
end
