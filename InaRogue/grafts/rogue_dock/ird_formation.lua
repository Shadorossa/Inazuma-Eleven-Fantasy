-- ===== EVT inarogue dock BEGIN =====
-- INAROGUE mode of the retail "Formación" screen (docs/game/modes/inarogue.md §16): in the INAROGUE save (slot 4) it
-- works as retail (cards, swaps, the per-player window, formation, captain), except that the team-switch arrows and
-- L1/R1 are off: the run has one team.
do
@COMMON@
  IRD.wrap("OnInit", function(orig)
    return function(...)
      IRD.check()
      if IRD.on then
        IRD.log("formation: INAROGUE mode, vs set", IRD.set)
      end
      return orig(...)
    end
  end)

  IRD.wrap("OnFunction", function(orig)
    return function(a1, a2, ...)
      if IRD.on and a1 == 2294853123 then
        funcLuaCommand(IRD.SE, IRD.SE_NG)
        return
      end
      return orig(a1, a2, ...)
    end
  end)

  IRD.wrap("SetVisibleTeamDockArrow", function(orig)
    return function(a1, ...)
      if IRD.on then
        return orig(false, ...)
      end
      return orig(a1, ...)
    end
  end)
end
-- ===== EVT inarogue dock END =====
