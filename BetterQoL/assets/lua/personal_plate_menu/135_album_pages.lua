-- BetterQoL, player plate («Ficha», personal_plate_menu): while the «Álbum de jugadores» page shows the plate on its
-- right half (assets\lua\screens\util_album_menu.lua, a card in the plate's players-universe mode) the plate leaves out
-- the pages that have nothing to show for a card: the sixth sense (vrfw.SixthSense), the team passives
-- (vrfw.TeamPassives) and TRAYECTORIA (BetterQoL.Career). The page dots and the page keys skip them
-- (VRFW_PlayerPages.ShowWhen, docs/framework/player-pages.md; a page no active mod adds is never drawn). The page is
-- recognised by its parameter BetterQoL.album_plate of the game's parameter store (set while it shows the plate).
-- Elsewhere the pages stay. It also puts the album page on the plate model's capture menus (below). Conditions only;
-- no engine call at load time.
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

-- The plate's 3D model (Character Reforged's plate model, EVT_PPM): the album page's own layers and the Caseta's
-- background are 2D layers drawn over the 3D pass, so the menu-camera model is never seen there. While the album page
-- exists the model is built on the plate model's capture layer (its own 2D quad and camera), as on the game's
-- «Personajes disponibles» list: the album menu joins EVT_PPM.CAPTURE_MENUS. No Character Reforged: nothing.
if type(EVT_PPM) == "table" and type(EVT_PPM.CAPTURE_MENUS) == "table" then
  local ALBUM_MENU = 2755094502            -- crc32 of util_album_menu
  local listed = false
  for _, menu in ipairs(EVT_PPM.CAPTURE_MENUS) do
    if menu == ALBUM_MENU then listed = true end
  end
  if not listed then
    EVT_PPM.CAPTURE_MENUS[#EVT_PPM.CAPTURE_MENUS + 1] = ALBUM_MENU
  end
end
