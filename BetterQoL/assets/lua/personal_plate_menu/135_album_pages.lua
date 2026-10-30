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
    FIRST_PAGE = 4021990517,               -- crc32 of BetterQoL.album_plate_page: 1 on the first shown page, 0 elsewhere
    PAGES = {"vrfw.SixthSense", "vrfw.TeamPassives", "BetterQoL.Career"},
  }
  BetterQoL.AlbumPages = A

  -- false while the album page shows the plate
  function A.Shown()
    return not VRFW_Param.Has(A.FLAG)
  end

  for _, name in ipairs(A.PAGES) do
    VRFW_PlayerPages.ShowWhen(name, A.Shown)
  end

  -- the page a step lands on, told to the album page (its «No lo tienes» badge shows only on the first page)
  local step = VRFW_PlayerPages.Step
  if type(step) == "function" then
    VRFW_PlayerPages.Step = function(cur, dir, count)
      local nxt = step(cur, dir, count)
      if not A.Shown() then
        local o = VRFW_PlayerPages.Order(count)
        VRFW_Param.Clear(A.FIRST_PAGE)
        VRFW_Param.Set(A.FIRST_PAGE, (o[1] == nil or o[1] == nxt) and 1 or 0)
      end
      return nxt
    end
  end
end

-- The plate's 3D model (Character Reforged's plate model, EVT_PPM) is built on its normal menu-camera layer here, as on
-- every other player page: the album page draws its background in the background pass (util_alb_backdrop) and the
-- opener hides the Caseta's normal-pass background meanwhile, so the model is drawn over the page's background and
-- under its 2D layers, the way the transfer office shows its model over shop01_00_background.
