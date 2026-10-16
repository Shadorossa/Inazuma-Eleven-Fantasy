-- EVT inarogue slot enter (if-adaptation-after-e3.md §5): INAROGUE entered from the framework's slot screen (its
-- reserved card, slot 4) -> INAROGUE's «back» returns to the slot screen (CMND_EVT_SLOT_ROGUE_RETURN 0). The framework's
-- title include (graft save_slots) calls EVT_SS_RESERVED_ENTER["<owner>"](slot) when it enters a reserved slot.
VRFW_SS_RESERVED_ENTER = VRFW_SS_RESERVED_ENTER or {}
VRFW_SS_RESERVED_ENTER.inarogue = function(slot)
  pcall(funcLuaCommand, 3463189556 --[[CMND_EVT_SLOT_ROGUE_RETURN]], 0)
end
