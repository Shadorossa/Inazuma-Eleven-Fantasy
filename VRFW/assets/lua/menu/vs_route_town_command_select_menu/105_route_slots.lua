-- route_slots (VR-Framework): the extended route node slots (300 and up) of this
-- Chronicle board script's VM: VRFW_RouteSlots (menu part lua\_all\36_route_slots.lua) wraps funcLuaCommand at OnInit,
-- so the board's own reads of a piece's statusFlagIndex and of the clear / lock status see an extended slot's state
-- (kept in the save service) instead of the shared proxy byte. No engine call at load time.
if VRFW_RouteSlots ~= nil then
  VRFW_RouteSlots.Watch()
end
