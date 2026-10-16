-- ===== EVT inarogue field BEGIN =====
-- A story field menu (Start = main_menu «MENÚ PRINCIPAL», Select = map_menu, X / M = rpg_area_map_menu) opened in the
-- INAROGUE save (slot 4, docs/game/modes/inarogue.md §21): it only exists on the story field, which must never be
-- reachable there. The menu goes black at once and the game goes back to the title, which reopens INAROGUE.
-- Other slots: retail.
do
@COMMON@
  local init = OnInit
  function OnInit(...)
    local r = table.pack(init and init(...))
    if RF.inRogue() then
      RF.back("story field menu (Start / Select / area map)")
    end
    return table.unpack(r, 1, r.n)
  end
  -- the save of slot 4 before the way back (rfl_common, §28): stepped here, then the reset
  local step = Step
  function Step(...)
    local r = table.pack(step and step(...))
    RF.tick()
    return table.unpack(r, 1, r.n)
  end
end
-- ===== EVT inarogue field END =====
