-- Battle Bay Deluxe, player plate («Ficha», personal_plate_menu): on this mod's lineup screen (the «Plantilla» viewer
-- of the Battle Bay grid, the player page on its right half) the player page leaves out the pages that have nothing to
-- show there: the sixth sense (vrfw.SixthSense, Character Reforged's paged plate), the team passives
-- (vrfw.TeamPassives, the page Utilities' passive configuration edits) and TRAYECTORIA (BetterQoL.Career). Q / E and the
-- page dots skip them (VRFW_PlayerPages.ShowWhen, docs/framework/player-pages.md; a page no active mod adds is never
-- drawn). The screen is recognised by this mod's parameter BattleBayDeluxe.lineup of the game's parameter store (set
-- while its player page is up) inside the framework context battle_bay. Elsewhere the pages stay.
-- Conditions only; no engine call at load time.
BattleBayDeluxe = type(BattleBayDeluxe) == "table" and BattleBayDeluxe or {}
if BattleBayDeluxe.LineupPages == nil and VRFW_PlayerPages ~= nil and type(VRFW_PlayerPages.ShowWhen) == "function" then
  local L = {
    FLAG = 2100506454,                   -- crc32 of BattleBayDeluxe.lineup (this mod's parameter)
    CONTEXT = "battle_bay",              -- the framework context of the Battle Bay's menus
    PARAM_EXISTS = 2947612279,
    MODE_IS = 624411898,                 -- CMND_VRFW_MODE_IS
    PAGES = {"vrfw.SixthSense", "vrfw.TeamPassives", "BetterQoL.Career"},
  }
  BattleBayDeluxe.LineupPages = L

  -- false while the lineup screen shows the player page
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
