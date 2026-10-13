-- Utilities, fast cursor on the Chronicle route map: the prompt «R2 Velocidad del cursor» in the board's bottom guide
-- (graft util_route_map_speed, docs/game/ui/chronicle-route-map-cursor.md). A DECLARATION only: the VR-Framework's
-- footer prompts (VRFW.FooterPrompts, docs/framework/footer-prompts.md) add it to the guide of vs_route_town_menu after
-- the game's entries, while the plugin says the boost is on. Nothing runs at load but the declaration (no engine call).
if VRFW_FooterPrompts ~= nil then
  VRFW_FooterPrompts.Add({
    Name = "Utilities.RouteMapSpeed",
    Menu = "vs_route_town_menu",
    Text = 2807525744,      -- crc32("Utilities.RouteMapSpeedGuide"): «Velocidad del cursor»
    Icon = 3487556099,      -- <CMD_FUNCR2> (pad R2, keyboard E)
    Command = 2704260807,   -- CMD_FUNCR2
    Order = 100,
    When = 2886973540,      -- crc32("CMND_UTIL_ROUTE_MAP_SPEED"): the boost is on (plugin utilities.dll)
  })
end
