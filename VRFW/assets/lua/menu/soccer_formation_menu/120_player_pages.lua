-- player pages (VR-Framework base feature): this screen's player plate pages in the
-- order of the registry the mods declare to (VRFW_PlayerPages.Add); the index -> type map, Q/E and the plate's own
-- next / previous page go through it (lua\_all\50_player_pages.lua). No engine call at load time.
if VRFW_PlayerPages ~= nil then
  VRFW_PlayerPages.Attach()
end
