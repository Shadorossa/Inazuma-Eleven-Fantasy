-- ===================================================================================================
-- Miximax scene input guard (2026-10-12; owner rule: never switch the menu input controller nor MENU_ACTIVE for this,
-- that froze the shop). While PL.mx_scene_busy (PL.MxScenePlay: from the fade out to the fade in) this screen's own
-- callbacks and Step polls return at once: no row, R3 / LEFT / RIGHT half switch, back or function key acts on the
-- hidden screen (it is resumed between the two events for the miximax look). Wraps the final definitions.
-- ===================================================================================================
PL.MxGuardPrev = {OnEnter = OnEnter, OnDecideFocus = OnDecideFocus, OnBack = OnBack, OnFunction = OnFunction}
function OnEnter(...)
  if PL.mx_scene_busy then
    return
  end
  return PL.MxGuardPrev.OnEnter(...)
end
function OnDecideFocus(...)
  if PL.mx_scene_busy then
    return
  end
  return PL.MxGuardPrev.OnDecideFocus(...)
end
function OnBack(...)
  if PL.mx_scene_busy then
    return
  end
  return PL.MxGuardPrev.OnBack(...)
end
function OnFunction(...)
  if PL.mx_scene_busy then
    return
  end
  return PL.MxGuardPrev.OnFunction(...)
end
PL.MxGuardPrevPollR3 = PL.MxPollR3
function PL.MxPollR3(...)
  -- also while an action runs (evt_co: the move / aura picker or a popup over this screen): its R3 is not this screen's
  if PL.mx_scene_busy or evt_co ~= nil or PL.MxGuardPrevPollR3 == nil then
    return
  end
  return PL.MxGuardPrevPollR3(...)
end
PL.MxGuardPrevHsPollR3 = PL.HsPollR3
function PL.HsPollR3(...)
  if PL.mx_scene_busy or PL.MxGuardPrevHsPollR3 == nil then
    return
  end
  return PL.MxGuardPrevHsPollR3(...)
end
-- ===== Miximax scene input guard END =====
