-- BetterQoL, player plate («Ficha», personal_plate_menu): while the «Álbum de jugadores» page shows the plate on its
-- right half (assets\lua\screens\util_album_menu.lua, a card in the plate's players-universe mode) the plate leaves out
-- the pages that have nothing to show for a card: the sixth sense (vrfw.SixthSense), the team passives
-- (vrfw.TeamPassives) and TRAYECTORIA (BetterQoL.Career). The page dots and the page keys skip them
-- (VRFW_PlayerPages.ShowWhen, docs/framework/player-pages.md; a page no active mod adds is never drawn). The page is
-- recognised by its parameter BetterQoL.album_plate of the game's parameter store (set while it shows the plate).
-- Elsewhere the pages stay. Conditions only; no engine call at load time.
BetterQoL = type(BetterQoL) == "table" and BetterQoL or {}
if BetterQoL.AlbumPages == nil and VRFW_PlayerPages ~= nil and type(VRFW_PlayerPages.ShowWhen) == "function" then
  local A = {
    FLAG = 2398708549,                     -- crc32 of BetterQoL.album_plate (the album page's parameter)
    PARAM_EXISTS = 2947612279,
    PAGES = {"vrfw.SixthSense", "vrfw.TeamPassives", "BetterQoL.Career"},
  }
  BetterQoL.AlbumPages = A

  -- false while the album page shows the plate
  function A.Shown()
    local ok, has = pcall(funcLuaCommand, A.PARAM_EXISTS, A.FLAG)
    return not (ok and has == true)
  end

  for _, name in ipairs(A.PAGES) do
    VRFW_PlayerPages.ShowWhen(name, A.Shown)
  end
end
