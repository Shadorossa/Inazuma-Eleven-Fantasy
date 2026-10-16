-- ===== EVT rogue formations BEGIN =====
-- INAROGUE formations as loot (docs/game/modes/inarogue.md §18), team dock screens: the picker greys and refuses the
-- loot formations not won yet; on opening, a locked saved formation goes back to 4-4-2 Diamante. Slot 4 only.
do
@COMMON@
  RF.wrap("OnInit", function(orig)
    return function(...)
      RF.on, RF.idx, RF.tint, RF.focus = nil, {}, {}, nil
      if RF.check() then
        RF.fix()
      end
      return orig(...)
    end
  end)
end
-- ===== EVT rogue formations END =====
